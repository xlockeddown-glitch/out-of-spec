extends "res://tests/coop_net.gd"
## The recall: a player in the basalt tunnels late at night is warned at 00:00 and
## carried out at 02:00 (docs/design/zones.md section 6.1). The cost, the clock
## rule, the rover, the finds and the all-in-bed day's end.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")

const WARN_LINE: String = "Recall in 2 hours"


func _state(credits: int, ore: int) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = credits
	gs.crystal_ore = ore
	return gs


## Runs `body` with the global clock at hour `hour` of day 1 and restores it.
func _at(hour: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, hour)
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


func _warnings(gs: GameStateScript) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(WARN_LINE):
			count += 1
	return count


func test_the_cost_is_fifty_credits_and_a_third_of_the_ore() -> String:
	var bill: Dictionary = TunnelRecall.cost(500, 9)
	if bill != { "credits": 50, "ore": 3, "waived": 0 }:
		return "50 CR and 3 of 9 ore: %s" % bill
	return ""


func test_ore_rounds_down_so_a_little_ore_costs_nothing() -> String:
	var lost: Array = []
	for ore: int in [0, 1, 2, 3, 5, 6, 10]:
		lost.append(TunnelRecall.cost(500, ore)["ore"])
	if lost != [0, 0, 0, 1, 1, 2, 3]:
		return "Ore lost for 0 1 2 3 5 6 10 carried: %s" % [lost]
	if TunnelRecall.cost(500, -4)["ore"] != 0:
		return "Negative ore must cost nothing"
	return ""


func test_a_short_wallet_pays_what_there_is_and_never_goes_below_zero() -> String:
	var short: Dictionary = TunnelRecall.cost(20, 0)
	var empty: Dictionary = TunnelRecall.cost(0, 6)
	var below: Dictionary = TunnelRecall.cost(-5, 0)
	if short != { "credits": 20, "ore": 0, "waived": 30 }:
		return "20 CR in the wallet pays 20 and waives 30: %s" % short
	if empty != { "credits": 0, "ore": 2, "waived": 50 }:
		return "An empty wallet pays nothing, the ore is still a third: %s" % empty
	if below["credits"] != 0 or below["waived"] != 50:
		return "A wallet below 0 pays nothing: %s" % below
	if TunnelRecall.cost(50, 0)["waived"] != 0 or TunnelRecall.cost(49, 0)["waived"] != 1:
		return "Exactly the fee waives nothing, one short waives 1"
	return ""


func test_the_numbers_are_data() -> String:
	for key: String in ["warn_hour", "rescue_hour", "fee_credits", "ore_share", "warn_text", "rescue_text", "cost_text", "cost_waived_text"]:
		if DataManager.get_value(&"economy", "tunnel_recall/" + key) == null:
			return "economy.json tunnel_recall must have %s" % key
	if not TunnelRecall.text("warn_text").contains(WARN_LINE) or not TunnelRecall.text("warn_text").contains("Odalys"):
		return "The warning must be Odalys's, two hours out"
	return ""


func test_the_clock_warns_at_midnight_and_rescues_at_two() -> String:
	var steps: Array = []
	for hour: float in [23.9, 0.0, 1.0, 1.99, 2.0, 5.0]:
		steps.append(TunnelRecall.phase(TunnelRecall.at_hour(1, hour), 0, 0))
	if steps != ["", "warn", "warn", "warn", "rescue", "rescue"]:
		return "Phases at 23:54 00:00 01:00 01:59 02:00 05:00: %s" % [steps]
	if TunnelRecall.phase(TunnelRecall.at_hour(1, 1.0), 1, 0) != "":
		return "Once warned, no second warning that day"
	if TunnelRecall.phase(TunnelRecall.at_hour(1, 3.0), 1, 1) != "":
		return "Once rescued, no second rescue that day"
	if TunnelRecall.phase(TunnelRecall.at_hour(1, 3.0), 0, 0) != "rescue":
		return "A farm that loads in the tunnels after 02:00 is rescued then"
	if TunnelRecall.phase(TunnelRecall.at_hour(2, 1.0), 1, 1) != "warn":
		return "The next day has its own warning"
	if TunnelRecall.phase(1.0, 1, 1) != "" or TunnelRecall.phase(0.5, 0, 0) != "":
		return "Daytime and 06:00 are quiet"
	return ""


func test_the_warning_comes_once_to_a_player_in_the_tunnels() -> String:
	var gs: GameStateScript = _state(500, 4)
	gs.recall_in_tunnels = func() -> bool: return true
	var problem: String = _at(0.5, func() -> String:
		gs._tick_recall()
		gs._tick_recall()
		return "")
	problem += _at(1.5, func() -> String:
		gs._tick_recall()
		return "")
	var warned: int = _warnings(gs)
	var rescued: int = gs._recall_rescued_day
	gs.free()
	if problem != "" or warned != 1 or rescued != 0:
		return "One warning, no rescue yet (%d warnings, rescued day %d)" % [warned, rescued]
	return ""


func test_two_oclock_marks_the_rescue_and_it_is_not_repeated() -> String:
	var gs: GameStateScript = _state(500, 4)
	gs.recall_in_tunnels = func() -> bool: return true
	var problem: String = _at(2.0, func() -> String:
		gs._tick_recall()
		gs._tick_recall()
		return "")
	var day: int = gs._recall_rescued_day
	gs.free()
	return problem if problem != "" else ("" if day == 1 else "The rescue is marked for day 1, got %d" % day)


func test_a_player_on_the_farm_or_in_the_dome_is_left_alone() -> String:
	var gs: GameStateScript = _state(500, 4)
	gs.recall_in_tunnels = func() -> bool: return false
	var problem: String = _at(0.5, func() -> String:
		gs._tick_recall()
		return "")
	problem += _at(2.5, func() -> String:
		gs._tick_recall()
		return "")
	var untouched: bool = _warnings(gs) == 0 and gs._recall_rescued_day == 0 and gs.credits == 500 and gs.crystal_ore == 4 and gs._rescue_notes.is_empty()
	gs.free()
	return problem if problem != "" else ("" if untouched else "Not in the tunnels: no warning, no rescue, no bill")


func test_a_guests_copy_never_runs_the_rule() -> String:
	var gs: GameStateScript = _state(500, 4)
	gs.recall_in_tunnels = func() -> bool: return true
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	var problem: String = _at(2.5, func() -> String:
		gs._tick_recall()
		return "")
	FarmCommands.guest = held
	var quiet: bool = _warnings(gs) == 0 and gs._recall_rescued_day == 0
	gs.free()
	return problem if problem != "" else ("" if quiet else "A guest must wait for the host: the rule is the host's")


func test_a_rescue_takes_the_fee_and_a_third_of_the_ore_and_keeps_the_finds() -> String:
	var gs: GameStateScript = _state(200, 7)
	gs.found_blocks[Vector2i(3, 4)] = true
	gs.sentinel_out = true
	gs.rover_in_tunnels = true
	var drift_before: Dictionary = gs.sensors_to_dict()
	var bill: Dictionary = gs.rescue_from_tunnels("player_1")
	var problem: String = ""
	if bill != { "credits": 50, "ore": 2, "waived": 0 } or gs.credits != 150 or gs.crystal_ore != 5:
		problem = "200 CR and 7 ore: 150 CR and 5 ore left, got %d CR, %d ore, %s" % [gs.credits, gs.crystal_ore, bill]
	elif not gs.found_blocks.get(Vector2i(3, 4), false) or not gs.sentinel_out:
		problem = "Finds that are not ore are kept"
	elif gs.sensors_to_dict() != drift_before:
		problem = "No extra drift for a rescue"
	elif gs._rescue_notes.size() != 1 or not gs._rescue_notes[0].contains("50 CR") or not gs._rescue_notes[0].contains("2 crystal ore"):
		problem = "The morning line says what it cost: %s" % [gs._rescue_notes]
	gs.free()
	return problem


func test_a_rescue_with_a_short_wallet_says_so() -> String:
	var gs: GameStateScript = _state(20, 0)
	gs.rescue_from_tunnels()
	var problem: String = ""
	if gs.credits != 0:
		problem = "The wallet pays what there is: %d" % gs.credits
	elif gs._rescue_notes.size() != 1 or not gs._rescue_notes[0].contains("waived"):
		problem = "The line says the rest was waived: %s" % [gs._rescue_notes]
	gs.free()
	return problem


func test_the_crew_brings_the_rover_home() -> String:
	var gs: GameStateScript = _state(100, 0)
	gs.rover_in_tunnels = true
	gs.rover_transforms[GameStateScript.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(30.0, 0.0, 12.0))
	gs.rover_transforms[GameStateScript.ROVER] = Transform3D(Basis.IDENTITY, GameStateScript.TUNNEL_PAD)
	var moved: Array[int] = [0]
	gs.rover_place_changed.connect(func() -> void: moved[0] += 1)
	gs.rescue_from_tunnels()
	var problem: String = ""
	if gs.rover_in_tunnels or moved[0] != 1:
		problem = "The rover must come home, telling everyone once (%s, %d)" % [gs.rover_in_tunnels, moved[0]]
	elif gs.parked_rover_transform(GameStateScript.ROVER).origin.distance_to(GameStateScript.TUNNEL_PAD) > 0.01:
		problem = "The rover is on the farm pad"
	elif gs.rover_transforms.has(GameStateScript.TUNNEL_ROVER):
		problem = "Nothing is left of it in the tunnels"
	# Recorded far from the pad, it still comes to the pad.
	gs.rover_in_tunnels = true
	gs.rover_transforms[GameStateScript.ROVER] = Transform3D(Basis.IDENTITY, Vector3(-40.0, 0.0, 40.0))
	gs.bring_rover_home()
	if problem == "" and gs.parked_rover_transform(GameStateScript.ROVER).origin.distance_to(GameStateScript.TUNNEL_PAD) > 0.01:
		problem = "A rover recorded far from the pad is put on it"
	gs.free()
	return problem


func test_a_rover_already_home_is_not_announced_again() -> String:
	var gs: GameStateScript = _state(100, 0)
	var moved: Array[int] = [0]
	gs.rover_place_changed.connect(func() -> void: moved[0] += 1)
	gs.bring_rover_home()
	gs.free()
	return "" if moved[0] == 0 else "A rover on the farm needs no word"


func test_the_morning_says_what_the_rescue_cost() -> String:
	var gs: GameStateScript = _state(200, 6)
	var held: float = GameClock.elapsed_days
	gs.rescue_from_tunnels()
	GameClock.elapsed_days = 1.0
	var before: int = gs.phone_log.size()
	gs._on_day_started(2)
	GameClock.elapsed_days = held
	var lines: String = "\n".join(gs.phone_log.slice(before))
	var said: bool = lines.contains("Recovery fee: 50 CR") and lines.contains("2 crystal ore")
	var cleared: bool = gs._rescue_notes.is_empty()
	gs.free()
	return "" if said and cleared else "The morning must say the fee once: %s" % lines


func test_a_rescued_player_counts_as_in_bed_with_friends() -> String:
	var host: Node = _host()
	_guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	var day_before: int = clock.get_day_index()
	beds.recall_to_bed("player_1")
	var problem: String = ""
	if not "player_1" in beds.in_bed or clock.get_day_index() != day_before:
		problem = "The rescued player is in bed and the day still waits for the friend"
	else:
		beds.go_to_bed("player_2")
		if clock.get_day_index() != day_before + 1 or clock.elapsed_days != 1.0:
			problem = "The friend in bed ends the day for both: %s" % clock.format_now()
	beds.free()
	clock.free()
	return _finish(problem)


func test_a_rescued_player_does_not_end_the_day_while_a_friend_is_up() -> String:
	var host: Node = _host()
	_guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	beds.recall_to_bed("player_1")
	beds.recall_to_bed("player_1")
	var problem: String = ""
	if beds.in_bed.count("player_1") != 1 or beds.still_up() != ["player_2"]:
		problem = "In bed once, the friend still up: %s, %s" % [beds.in_bed, beds.still_up()]
	elif clock.elapsed_days != TunnelRecall.at_hour(1, 2.0):
		problem = "Nothing moves the clock while a friend is up"
	beds.free()
	clock.free()
	return _finish(problem)


func test_alone_the_recall_ends_the_day_like_bed() -> String:
	var host: Node = _host()
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	beds.recall_to_bed("player_1")
	var day: int = clock.get_day_index()
	var at: float = clock.elapsed_days
	beds.free()
	clock.free()
	return _finish("" if day == 2 and at == 1.0 else "Alone, a rescue wakes you at 06:00 on day 2: %d, %s" % [day, at])


func test_a_guests_copy_cannot_put_anyone_to_bed_by_recall() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(guest, clock)
	clock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	beds.recall_to_bed("player_2")
	var problem: String = "" if beds.in_bed.is_empty() and clock.elapsed_days == TunnelRecall.at_hour(1, 2.0) else "Only the host's farm rescues"
	beds.free()
	clock.free()
	return _finish(problem)
