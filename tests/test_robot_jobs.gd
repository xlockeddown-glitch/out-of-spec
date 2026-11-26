extends RefCounted
## Milestone 5, second slice: a released robot's job cards (WATER).
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ROBOT: String = "TR-1"
const PROBE: String = "robot_soil_probe@TR-1"
const SENSORS: Array[String] = ["robot_joint_encoder@TR-1", "robot_grip_torque@TR-1",
	"robot_tank_pressure@TR-1", PROBE]
const CELL: Vector3i = Vector3i(2, 0, 2)
const EPS: float = 0.006


## Runs `body` at day 8, 06:00 with a released Trellis, exact soil probes and
## one crop planted on target.
func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.optical_silk_spools = 3
	gs._spool_species.assign([&"a", &"b", &"c"])
	gs.tier1_unlocked = true
	for id: String in ["torque_standard", "rotary_table", "reference_gauge", "field_meter_dc"]:
		gs.owned_standards[id] = 0
		gs.certificates[id] = { "id": "TEST-" + id, "standard_id": id }
	for id: String in gs.standard_ids():
		gs.get_sensor(id).cal_due_day = 1000
	gs.build_robot("trellis")
	GameClock.elapsed_days = 7.0
	gs._finish_robot_builds(8)
	for id: String in SENSORS:
		gs.calibrate(id)
	gs.tilled_cells[CELL] = true
	gs.plant_crop(CELL, "biscuit_reed")
	gs.get_sensor(PROBE).error = 0.0
	gs.get_sensor("soil_probe").error = 0.0
	gs.plantings[CELL]["setpoint"] = _target(gs)
	var problem: String = gs.release_robot(ROBOT)
	(gs.player_skill_xp.get_or_add("player_1", {}) as Dictionary)["robotics"] = 0
	if problem == "":
		problem = body.call(gs)
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func _target(gs: GameStateScript) -> float:
	return float(gs.crop("biscuit_reed")["soil_moisture_target"])


## Moves the clock to `day`.`part` and runs the cards, as a clock tick does.
func _tick(gs: GameStateScript, elapsed: float) -> void:
	GameClock.elapsed_days = elapsed
	gs._run_robot_cards()


func _near(gs: GameStateScript, setpoint: float) -> bool:
	return absf(float(gs.plantings[CELL]["setpoint"]) - setpoint) < EPS


func test_programming_gates() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	if gs.add_robot_card("TR-9", "clock") == "":
		return "An unknown robot takes no card."
	for bad: Array in [["spool", 6, 1], ["clock", 24, 1], ["clock", -1, 1], ["clock", 6, 0]]:
		if gs.add_robot_card(ROBOT, bad[0], bad[1], bad[2]) == "":
			return "A bad card was taken: %s" % [bad]
	gs.set_rover_uplink("rover_1", false)
	if gs.add_robot_card(ROBOT, "clock") == "":
		return "No line of sight, no new card."
	gs.set_rover_uplink("rover_1", true)
	gs.robots[ROBOT]["state"] = "commissioning"
	if gs.add_robot_card(ROBOT, "clock") == "":
		return "An unreleased robot takes no card."
	gs.robots[ROBOT]["state"] = "released"
	if gs.add_robot_card(ROBOT, "clock") != "":
		return "A good card must be taken."
	if gs.add_robot_card(ROBOT, "soil") == "":
		return "Robotics 1 has one slot."
	(gs.player_skill_xp.get_or_add("player_1", {}) as Dictionary)["robotics"] = gs.xp_for_level(2)
	if gs.add_robot_card(ROBOT, "soil") != "" or gs.add_robot_card(ROBOT, "soil") == "":
		return "Robotics 2 has two slots."
	(gs.player_skill_xp.get_or_add("player_1", {}) as Dictionary)["robotics"] = gs.xp_for_level(9)
	if gs.robot_card_slots() != 2:
		return "Levels past the table keep its last count."
	if gs.remove_robot_card(ROBOT, 2) == "" or gs.remove_robot_card(ROBOT, -1) == "":
		return "There is no such card."
	gs.set_rover_uplink("rover_1", false)
	if gs.remove_robot_card(ROBOT, 0) == "":
		return "No line of sight, no removal."
	gs.set_rover_uplink("rover_1", true)
	if gs.remove_robot_card(ROBOT, 0) != "" or gs.robot_cards(ROBOT).size() != 1 \
			or gs.robot_cards(ROBOT)[0]["trigger"] != "soil":
		return "Removing the first leaves the second."
	return ""


func test_clock_card() -> String:
	return _run(_check_clock)


func _check_clock(gs: GameStateScript) -> String:
	var target: float = _target(gs)
	gs.add_robot_card(ROBOT, "clock", 12, 2)
	gs.get_sensor("soil_probe").error = 5.0
	_tick(gs, 7.2)
	var early: bool = not _near(gs, target)
	_tick(gs, 7.25)
	if early or not _near(gs, target + 0.05):
		return "Wrong time: early %s, set point %s." % [early, gs.plantings[CELL]["setpoint"]]
	gs.get_sensor("soil_probe").error = 0.0
	_tick(gs, 8.25)
	if not _near(gs, target + 0.05):
		return "It must wait 2 days."
	_tick(gs, 9.25)
	return "" if _near(gs, target) else "It must run 2 days later."


func test_morning_trim_counts_toward_the_new_day() -> String:
	return _run(_check_morning)


func _check_morning(gs: GameStateScript) -> String:
	gs.add_robot_card(ROBOT, "clock")
	# The plot probe is exact and the robot's is not: the trim does the harm.
	gs.plantings[CELL]["crop_id"] = "dust_turnip"
	gs.plantings[CELL]["setpoint"] = 0.25
	gs.get_sensor(PROBE).error = 9.0
	gs.set_interlock_override(ROBOT, true)
	GameClock.elapsed_days = 8.0
	gs._on_time_advanced(0.0)
	if absf(float(gs.plantings[CELL]["setpoint"]) - 0.25) > EPS:
		return "At 06:00 the old day closes first."
	gs._on_day_started(9)
	if float(gs.plantings[CELL]["setpoint"]) > 0.2:
		return "The 06:00 card must run that morning."
	return "" if gs.plantings[CELL]["days_grown"] == 1 else "The old day's growth was lost."


func test_soil_card_and_rewards() -> String:
	return _run(_check_soil)


func _check_soil(gs: GameStateScript) -> String:
	var target: float = _target(gs)
	gs.add_robot_card(ROBOT, "soil")
	var xp: int = gs.skill_xp("robotics")
	var posts: int = gs.phone_log.size()
	_tick(gs, 7.1)
	gs.get_sensor("soil_probe").error = 4.0
	_tick(gs, 7.2)
	if not _near(gs, target) or gs.skill_xp("robotics") != xp or gs.phone_log.size() != posts:
		return "On target and within a quarter of the band it does nothing and earns nothing."
	gs.get_sensor("soil_probe").error = 8.0
	gs.set_rover_uplink("rover_1", false)
	_tick(gs, 7.3)
	if not _near(gs, target + 0.08) or absf(gs.soil_moisture(CELL) - target) > EPS:
		return "It must trim the drift out, with no line of sight too."
	if gs.skill_xp("robotics") != xp + int(DataManager.get_record(&"skills", "robot_job", "xp_sources")["xp"]) or not gs.phone_log.any(func(t: String) -> bool: return t.contains("1 plot by")):
		return "A job that trims earns the robot_job XP and is reported."
	_tick(gs, 7.4)
	return "" if gs.skill_xp("robotics") == xp + int(DataManager.get_record(&"skills", "robot_job", "xp_sources")["xp"]) else "Once trimmed, it stops."


func test_drifted_robot_probe_trims_wrongly() -> String:
	return _run(_check_drifted)


func _check_drifted(gs: GameStateScript) -> String:
	gs.add_robot_card(ROBOT, "soil")
	gs.get_sensor(PROBE).error = 8.0
	gs.set_interlock_override(ROBOT, true)
	_tick(gs, 7.1)
	if absf(gs.soil_moisture(CELL) - (_target(gs) - 0.08)) > EPS:
		return "A probe reading 8 % high must dry the soil by 8 %."
	return ""


func test_ready_crops_and_order() -> String:
	return _run(_check_ready)


func _check_ready(gs: GameStateScript) -> String:
	(gs.player_skill_xp.get_or_add("player_1", {}) as Dictionary)["robotics"] = gs.xp_for_level(2)
	gs.add_robot_card(ROBOT, "soil")
	gs.add_robot_card(ROBOT, "clock", 12)
	gs.get_sensor("soil_probe").error = 8.0
	gs.plantings[CELL]["days_grown"] = 99
	_tick(gs, 7.1)
	if not _near(gs, _target(gs)):
		return "A ready crop is left alone."
	gs.plantings[CELL]["days_grown"] = 0
	var last_day: int = gs.robot_cards(ROBOT)[1]["last_day"]
	_tick(gs, 7.5)
	if gs.robot_cards(ROBOT)[1]["last_day"] != last_day:
		return "Only the first due card runs in a tick."
	_tick(gs, 7.5)
	return "" if gs.robot_cards(ROBOT)[1]["last_day"] == last_day + 1 else "The second card's turn comes next tick."


func test_cards_run_on_the_clock_and_load() -> String:
	return _run(_check_load)


func _check_load(gs: GameStateScript) -> String:
	gs.add_robot_card(ROBOT, "clock", 7)
	var data: Dictionary = gs.farm_to_dict()
	for change: Array in [["job", "spin"], ["trigger", "x"], ["hour", 24], ["hour", 1.0], ["every_days", 0], ["last_day", 1.0], ["added_by", 1]]:
		var bad: Dictionary = data.duplicate(true)
		bad["robots"][ROBOT]["cards"][0][change[0]] = change[1]
		if gs.farm_dict_problem(bad) == "":
			return "A bad %s must be refused." % change[0]
	for cards: Variant in [3, [3], [{}]]:
		var bad: Dictionary = data.duplicate(true)
		bad["robots"][ROBOT]["cards"] = cards
		if gs.farm_dict_problem(bad) == "":
			return "Bad cards must be refused: %s" % [cards]
	var held: Array = gs.robot_cards(ROBOT).duplicate(true)
	gs.remove_robot_card(ROBOT, 0)
	if gs.farm_from_dict(data) != "" or gs.robot_cards(ROBOT) != held:
		return "Cards must load."
	gs.get_sensor("soil_probe").error = 8.0
	GameClock.elapsed_days = 7.0 + 1.0 / 24.0
	gs._on_time_advanced(0.0)
	if _near(gs, _target(gs)):
		return "A clock tick must run the cards."
	data["robots"][ROBOT].erase("cards")
	if gs.farm_from_dict(data) != "" or not gs.robot_cards(ROBOT).is_empty():
		return "A robot saved before cards has none."
	return ""
