extends "res://tests/coop_net.gd"
## The day waits for everyone to be in bed, and only with friends in.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")


func _farm(answer: Callable) -> String:
	var host: Node = _host()
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	var problem: String = answer.call(host, beds, clock)
	beds.free()
	clock.free()
	return _finish(problem)


func test_alone_there_is_no_bed() -> String:
	return _farm(func(_host_side: Node, beds: Node, clock: Node) -> String:
		beds._look()
		if beds.go_to_bed("player_1") == "" or not beds.in_bed.is_empty() or clock.morning_waits:
			return "Alone there must be no one to wait for"
		clock.advance(1.5)
		return "" if clock.get_day_index() == 2 else "Alone the day must go over on its own")


func test_the_day_waits_until_everyone_is_in_bed() -> String:
	return _farm(func(host: Node, beds: Node, clock: Node) -> String:
		_guest(host)
		if not clock.morning_waits or beds.still_up() != ["player_1", "player_2"]:
			return "A friend joined, so the morning must wait for both"
		var passed: Array[float] = [0.0]
		clock.time_advanced.connect(func(days: float) -> void: passed[0] += days)
		clock.advance(1.5)
		clock.advance(0.1)
		clock.skip_to_next_morning()
		if clock.get_day_index() != 1 or clock.format_now() != "DAY 1  05:59" or absf(passed[0] - clock.elapsed_days) > 1e-9:
			return "Time must stop short of 06:00, and drift with it: %s, %s" % [clock.format_now(), passed[0]]
		if not clock.waits_within(0.001):
			return "Bench work must not fit in the stopped clock"
		clock.elapsed_days = 0.5
		if beds.go_to_bed("player_2") != "" or clock.elapsed_days != 0.5:
			return "One in bed must not end the day"
		beds.get_up("player_2")
		beds.go_to_bed("player_1")
		if clock.elapsed_days != 0.5 or beds.go_to_bed("player_2") != "":
			return "Getting up must count"
		if clock.elapsed_days != 1.0 or not beds.in_bed.is_empty() or not clock.morning_waits:
			return "Everyone in bed must end the day, and wake up to one that waits again"
		return "" if beds.go_to_bed("player_9") != "" else "A player who isn't in can't go to bed")


func test_whoever_leaves_is_not_waited_for() -> String:
	return _farm(func(host: Node, beds: Node, clock: Node) -> String:
		var one: Node = _guest(host)
		var two: Node = _guest(host)
		beds.go_to_bed("player_1")
		beds.go_to_bed("player_2")
		two.leave()
		_until(func() -> bool: return host.players.size() == 2)
		if clock.elapsed_days != 1.0:
			return "The last one up left, so the day must end"
		beds.go_to_bed("player_1")
		one.leave()
		_until(func() -> bool: return host.players.size() == 1)
		if clock.elapsed_days != 1.0 or not beds.in_bed.is_empty() or clock.morning_waits:
			return "Alone again: no bed, and the day doesn't wait"
		return "")


func test_doing_something_gets_a_player_up() -> String:
	CoopBeds.in_bed.assign(["player_2", "player_3"])
	var host: Node = _host()
	host.commands.execute("player_2", &"get_up", [])
	var left: Array[String] = CoopBeds.in_bed.duplicate()
	host.commands.execute("player_3", &"no_such_thing", [])
	var after: Array[String] = CoopBeds.in_bed.duplicate()
	host.commands.execute("player_3", &"accept_job", [99])
	var last: Array[String] = CoopBeds.in_bed.duplicate()
	CoopBeds.in_bed.clear()
	return _finish("" if left == ["player_3"] and after == ["player_3"] and last.is_empty() else "Got %s, %s, %s" % [left, after, last])


func test_the_strip_says_who_is_still_up() -> String:
	var both: Array[String] = ["player_1", "player_2"]
	var bed: Array[String] = ["player_1"]
	var text: String = CoopUI.strip_text(both, "player_1", true, false, bed)
	return "" if "1 OF 2 IN BED, STILL UP: PLAYER 2" in text else "Got %s" % text
