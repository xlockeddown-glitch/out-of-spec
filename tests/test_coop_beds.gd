extends "res://tests/coop_net.gd"
## The day waits for everyone to be in bed, and only with friends in.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")


func _farm(answer: Callable) -> String:
	var host: Node = _host()
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = answer.call(host, beds, clock)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	beds.free()
	clock.free()
	return _finish(problem)


func test_alone_going_to_bed_ends_the_day() -> String:
	return _farm(func(_host_side: Node, beds: Node, clock: Node) -> String:
		beds._look()
		clock.elapsed_days = 0.5
		if clock.morning_waits or beds.go_to_bed("player_1") != "":
			return "Alone, going to bed must be allowed and not wait"
		if clock.get_day_index() != 2 or clock.elapsed_days != 1.0 or not beds.in_bed.is_empty():
			return "Alone, going to bed must go straight to the next morning: %s" % clock.format_now()
		if beds.go_to_bed("player_9") == "":
			return "A player who isn't on the farm can't go to bed"
		clock.elapsed_days = 1.5
		clock.advance(1.0)
		return "" if clock.get_day_index() == 3 else "Alone the day must still go over on its own")


func test_with_no_session_going_to_bed_ends_the_day() -> String:
	var host: Node = _host()
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	host.players.clear()
	beds.start(host, clock)
	var answer: String = beds.go_to_bed("player_1")
	var day: int = clock.get_day_index()
	beds.free()
	clock.free()
	var problem: String = "" if answer == "" and day == 2 else "No session: bed must end the day (%s, day %d)" % [answer, day]
	return _finish(problem)


func test_host_with_a_guest_still_waits_for_both() -> String:
	return _farm(func(host: Node, beds: Node, clock: Node) -> String:
		_guest(host)
		clock.elapsed_days = 0.5
		if beds.go_to_bed("player_1") != "" or clock.elapsed_days != 0.5:
			return "With a guest, one in bed must not end the day"
		if beds.go_to_bed("player_2") != "" or clock.elapsed_days != 1.0:
			return "Both in bed must end the day"
		return "")


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
		if clock.elapsed_days != 2.0 or not beds.in_bed.is_empty() or clock.morning_waits:
			return "The host was in bed and the last friend left, so the day must end: %s" % clock.format_now()
		return "")


func test_a_leaving_friend_with_the_host_up_does_not_end_the_day() -> String:
	return _farm(func(host: Node, beds: Node, clock: Node) -> String:
		var one: Node = _guest(host)
		beds.go_to_bed("player_2")
		one.leave()
		_until(func() -> bool: return host.players.size() == 1)
		if clock.elapsed_days != 0.0 or not beds.in_bed.is_empty() or clock.morning_waits:
			return "Only the friend was in bed: no day ends, and nothing waits"
		return "")


func test_a_double_click_alone_sleeps_one_day() -> String:
	return _farm(func(_host_side: Node, beds: Node, clock: Node) -> String:
		beds._look()
		if beds.go_to_bed("player_1") != "" or beds.go_to_bed("player_1") == "" or clock.get_day_index() != 2:
			return "A repeat request right after must be refused: day %d" % clock.get_day_index()
		beds.cooldown_ms = 0
		if beds.go_to_bed("player_1") != "" or clock.get_day_index() != 3:
			return "After the cooldown, bed works again"
		return "")


func test_someone_joining_holds_a_solo_bed() -> String:
	return _farm(func(host: Node, beds: Node, clock: Node) -> String:
		host._links[7] = { "player": "" }
		if not beds.joining() or beds.go_to_bed("player_1") == "" or clock.elapsed_days != 0.0:
			return "While someone is joining, bed must not skip the day"
		host._links[7]["gone"] = true
		return "" if beds.go_to_bed("player_1") == "" else "A dropped joiner must not block bed")


func test_beds_are_on_the_farm_only() -> String:
	for path: String in [SceneSwitcher.DOME_SCENE, SceneSwitcher.TUNNELS_SCENE, SceneSwitcher.TITLE_SCENE, ""]:
		if BedsScript.scene_refusal(path) == "":
			return "No bed at '%s'" % path
	return "" if BedsScript.scene_refusal(SceneSwitcher.FARM_SCENE) == "" else "The farm has the bed"


func test_game_state_refuses_the_local_player_off_the_farm() -> String:
	var held: bool = SaveGame.farm_open
	SaveGame.farm_open = false
	var day: float = GameClock.elapsed_days
	var why: String = GameState.go_to_bed()
	SaveGame.farm_open = held
	return "" if why != "" and GameClock.elapsed_days == day else "Bed with no farm open must be refused"


func test_no_bed_while_paused_or_with_no_farm_open() -> String:
	return _farm(func(_host_side: Node, beds: Node, clock: Node) -> String:
		var held: bool = SaveGame.farm_open
		SaveGame.farm_open = false
		var closed: String = beds.here_refusal()
		SaveGame.farm_open = true
		clock.paused = true
		var paused: String = beds.here_refusal()
		clock.paused = false
		SaveGame.farm_open = held
		return "" if closed != "" and paused != "" else "No farm open or paused must refuse")


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
