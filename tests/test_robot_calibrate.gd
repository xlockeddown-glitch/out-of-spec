extends RefCounted
## Milestone 5: the robots' CALIBRATE card, u_robot and the recall of what a bad
## robot calibrated.

const JobsTest: GDScript = preload("res://tests/test_robot_jobs.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ROBOT: String = "TR-1"
const GRIP: String = "robot_grip_torque@TR-1"
const ENCODER: String = "robot_joint_encoder@TR-1"
const TARGET: String = "rover_tire_pressure"
const OTHER: String = "rover_steering_encoder"


## The robot job fixture with an exact robot and the CALIBRATE skills.
func _run(body: Callable) -> String:
	return JobsTest.new()._run(func(gs: GameStateScript) -> String:
		for id: String in gs.robot_sensor_ids(ROBOT):
			gs.get_sensor(id).error = 0.0
		gs.farm_skill_xp["robotics"] = gs.xp_for_level(4)
		gs.player_skill_xp[gs.local_player_id] = { "calibration": gs.xp_for_level(3) }
		for id: String in gs.unit_ids():
			gs.get_sensor(id).cal_due_day = 1000
		return body.call(gs))


func _tick(gs: GameStateScript, elapsed: float) -> void:
	GameClock.elapsed_days = elapsed
	gs._run_robot_cards()


func test_gates() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	if gs.add_robot_calibrate_card(ROBOT, ENCODER) == "" or ENCODER in gs.robot_calibrate_targets(ROBOT):
		return "A robot never calibrates itself."
	if gs.add_robot_calibrate_card(ROBOT, "reference_gauge") == "" or gs.add_robot_calibrate_card(ROBOT, "nothing") == "":
		return "Only units are targets."
	if gs.add_robot_calibrate_card(ROBOT, TARGET, "soil") == "" or gs.add_robot_card(ROBOT, "due") == "":
		return "Each job has its own triggers."
	if gs.robot_calibrate_targets(ROBOT).is_empty():
		return "There must be something to calibrate."
	gs.farm_skill_xp["robotics"] = gs.xp_for_level(4) - 1
	if not gs.add_robot_calibrate_card(ROBOT, TARGET).contains("Robotics level 4"):
		return "It needs Robotics 4: %s %d" % [gs.robot_job_gate(gs.JOB_CALIBRATE), gs.skill_level("robotics")]
	gs.farm_skill_xp["robotics"] = gs.xp_for_level(4)
	gs.player_skill_xp[gs.local_player_id]["calibration"] = gs.xp_for_level(3) - 1
	if not gs.add_robot_calibrate_card(ROBOT, TARGET).contains("Calibration level 3"):
		return "It needs Calibration 3."
	gs.player_skill_xp[gs.local_player_id]["calibration"] = gs.xp_for_level(3)
	var sensor: DriftingSensor = gs.get_sensor(TARGET)
	var mpe: float = sensor.mpe
	sensor.mpe = float(gs.calibration_budget(TARGET)["u_res"])
	if not gs.add_robot_calibrate_card(ROBOT, TARGET).contains("under 4:1"):
		return "It needs 4:1 with the robot's term."
	# Every unit in service is either offered or listed with its reason.
	var gaps: Dictionary = gs.robot_calibrate_gaps(ROBOT)
	var listed: Array = gs.robot_calibrate_targets(ROBOT)
	for reason: String in gaps:
		listed = listed + gaps[reason]
		if TARGET in gaps[reason] and not reason.contains("under 4:1"):
			return "Wrong reason: %s" % gaps
	listed.sort()
	var units: Array = gs.bench_unit_ids()
	units.sort()
	if listed != units or not gaps["A robot never calibrates itself."].has(ENCODER):
		return "Each unit once, with its reason: %s" % gaps
	sensor.mpe = mpe
	gs.set_rover_uplink("rover_1", false)
	if gs.add_robot_calibrate_card(ROBOT, TARGET) == "":
		return "No line of sight, no card."
	gs.set_rover_uplink("rover_1", true)
	if gs.add_robot_calibrate_card(ROBOT, TARGET) != "" or gs.add_robot_calibrate_card(ROBOT, OTHER) != "" \
			or gs.add_robot_calibrate_card(ROBOT, OTHER) == "":
		return "Two slots, two cards."
	if not gs.robot_card_text(gs.robot_cards(ROBOT)[0]).begins_with("CALIBRATE "):
		return "The card must say its job."
	var data: Dictionary = gs.farm_to_dict()
	if gs.farm_dict_problem(data) != "":
		return "The card must save: %s" % gs.farm_dict_problem(data)
	data["robots"][ROBOT]["cards"][0].erase("target")
	return "" if gs.farm_dict_problem(data) != "" else "A card with no target must be refused."


func test_due_card() -> String:
	return _run(_check_due)


func _check_due(gs: GameStateScript) -> String:
	gs.add_robot_calibrate_card(ROBOT, TARGET)
	var sensor: DriftingSensor = gs.get_sensor(TARGET)
	sensor.cal_due_day = GameClock.get_day_index() + 2
	var count: int = gs.cal_log.size()
	_tick(gs, 7.01)
	if gs.cal_log.size() != count:
		return "It waits until a day before."
	var human: Dictionary = gs.calibration_budget(TARGET)
	var robotic: Dictionary = gs.calibration_budget(TARGET, "", true)
	if absf(robotic["u_robot"] - 0.1 * sensor.mpe / sqrt(3.0)) > 1e-6 or robotic["tur"] >= human["tur"] or human["u_robot"] != 0.0:
		return "A robot's work has a lower TUR."
	# 2 MPE off: 0.2 MPE of the unit's goes in, whatever its interlock says.
	gs.get_sensor(GRIP).error = -8.0
	gs.set_interlock_override(ROBOT, true)
	sensor.error = 0.0
	sensor.cal_due_day = GameClock.get_day_index() + 1
	gs.get_sensor(sensor.calibrated_by).error = 0.0
	var xp: int = gs.skill_xp("calibration")
	var robotics: int = gs.skill_xp("robotics")
	var now: float = GameClock.elapsed_days
	_tick(gs, now + 0.01)
	if gs.cal_log.size() != count + 1 or GameClock.elapsed_days != now + 0.01:
		return "It must run once, with no bench time: %s" % [gs.phone_log.slice(-2)]
	var record: Dictionary = gs.cal_log.back()
	if record["performed_by"] != ROBOT or record["programmed_by"] != gs.local_player_id or not record["traceable"] \
			or absf(record["tur"] - robotic["tur"]) > 1e-6:
		return "The record must be the robot's: %s" % [record]
	if absf(record["as_found"] - 0.2 * sensor.mpe) > 1e-4:
		return "The robot's error must go into the reading: %s" % record["as_found"]
	if gs.skill_xp("calibration") != xp or gs.skill_xp("robotics") != robotics + 1 or gs.player_skill_xp.has(ROBOT):
		return "It earns the robot_job XP alone."
	if gs.get_sensor(ENCODER).error == 0.0:
		return "It wears the joint encoder."
	_tick(gs, now + 0.02)
	return "" if gs.cal_log.size() == count + 1 else "Once a day is enough."


func test_refusals_are_reported_once() -> String:
	return _run(_check_refusals)


func _check_refusals(gs: GameStateScript) -> String:
	gs.add_robot_calibrate_card(ROBOT, TARGET, "clock", 12)
	var standard: String = gs.get_sensor(TARGET).calibrated_by
	gs.get_sensor(standard).cal_due_day = 1
	var count: int = gs.cal_log.size()
	var credibility: int = gs.credibility
	var posts: int = gs.phone_log.size()
	_tick(gs, 7.26)
	_tick(gs, 7.3)
	if gs.cal_log.size() != count or gs.credibility != credibility or gs.phone_log.size() != posts + 1 \
			or not str(gs.phone_log.back()).contains("overdue"):
		return "An overdue standard is refused, and said once: %s" % [gs.phone_log.slice(posts)]
	gs.get_sensor(standard).cal_due_day = 1000
	_tick(gs, 8.26)
	if gs.cal_log.size() != count + 1:
		return "The next day it tries again."
	# Redoing it the next day runs, but earns no XP.
	gs.robots[ROBOT]["cards"][0]["every_days"] = 1
	var robotics: int = gs.skill_xp("robotics")
	_tick(gs, 9.26)
	if gs.cal_log.size() != count + 2:
		return "A daily card runs daily: %s" % [gs.phone_log.slice(-2)]
	return "" if gs.skill_xp("robotics") == robotics else "A repeat can't be farmed for XP."


func test_recall() -> String:
	return _run(_check_recall)


func _check_recall(gs: GameStateScript) -> String:
	for id: String in [TARGET, OTHER]:
		gs.calibrate(id, "", true, 0.0, ROBOT)
	gs.calibrate(OTHER)  # redone by hand
	gs.get_sensor(ENCODER).error = 0.0
	gs.calibrate(ENCODER)
	if not gs.suspect_units.is_empty():
		return "A passing sensor recalls nothing."
	gs.get_sensor(GRIP).error = 6.0
	gs.calibrate(GRIP)
	if gs.suspect_units.keys() != [TARGET]:
		return "Only the one not redone is suspect now: %s" % gs.suspect_units
	var flagged: int = gs.cal_log.filter(func(r: Dictionary) -> bool: return r["suspect"]).size()
	if flagged != 2 or not str(gs.phone_log.back()).contains("RECALL: 2 "):
		return "Both records are flagged, %d were: %s" % [flagged, gs.phone_log.back()]
	gs.calibrate(TARGET)
	if not gs.suspect_units.is_empty():
		return "Redone, it is good again."
	# Since the last good one: the first two must not be found again.
	gs.calibrate(TARGET, "", true, 0.0, ROBOT)
	gs.get_sensor(GRIP).error = 0.0
	gs.calibrate(GRIP)
	gs.get_sensor(GRIP).error = 6.0
	gs.calibrate(GRIP)
	return "" if gs.suspect_units.is_empty() else "Work before the last good calibration stands."
