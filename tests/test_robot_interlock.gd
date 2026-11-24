extends RefCounted
## Milestone 5, third slice: the robot interlock, its audit fine and what a
## robot's drifting sensors do to its work.

const JobsTest: GDScript = preload("res://tests/test_robot_jobs.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ROBOT: String = "TR-1"
const PROBE: String = "robot_soil_probe@TR-1"
const GRIP: String = "robot_grip_torque@TR-1"
const TANK: String = "robot_tank_pressure@TR-1"
const ENCODER: String = "robot_joint_encoder@TR-1"
const CELL: Vector3i = Vector3i(2, 0, 2)
const NEXT: Vector3i = Vector3i(3, 0, 2)
const EPS: float = 0.006


## The robot job fixture, with every sensor of the robot exact.
func _run(body: Callable) -> String:
	return JobsTest.new()._run(func(gs: GameStateScript) -> String:
		for id: String in gs.robot_sensor_ids(ROBOT):
			gs.get_sensor(id).error = 0.0
		return body.call(gs))


func _target(gs: GameStateScript) -> float:
	return float(gs.crop("biscuit_reed")["soil_moisture_target"])


func _tick(gs: GameStateScript, elapsed: float) -> void:
	GameClock.elapsed_days = elapsed
	gs._run_robot_cards()


func _is_at(gs: GameStateScript, cell: Vector3i, setpoint: float) -> bool:
	return absf(float(gs.plantings[cell]["setpoint"]) - setpoint) < EPS


func test_interlock_holds_and_arms_itself() -> String:
	return _run(_check_interlock)


func _check_interlock(gs: GameStateScript) -> String:
	var target: float = _target(gs)
	gs.add_robot_card(ROBOT, "clock", 12)
	gs.get_sensor("soil_probe").error = 5.0
	gs.get_sensor(GRIP).error = 4.1
	var logged: int = gs.phone_log.size()
	_tick(gs, 7.2)
	_tick(gs, 7.22)
	if gs.phone_log.size() != logged + 1 \
			or not str(gs.phone_log.back()).contains("TR-1: grip torque out of tolerance. Holding."):
		return "It must say once that it holds: %s" % [gs.phone_log.slice(logged)]
	_tick(gs, 7.25)
	if not _is_at(gs, CELL, target) or not gs.is_robot_holding(ROBOT):
		return "A holding robot does no job."
	if gs.set_interlock_override(ROBOT, false) == "":
		return "An armed interlock can't be armed."
	gs.set_rover_uplink("rover_1", false)
	if gs.set_interlock_override(ROBOT, true) == "":
		return "No line of sight, no override."
	gs.set_rover_uplink("rover_1", true)
	if gs.set_interlock_override(ROBOT, true) != "" or gs.is_robot_holding(ROBOT):
		return "The override must release it."
	_tick(gs, 7.26)
	if not _is_at(gs, CELL, target + 0.05):
		return "An overridden robot does the job it missed."
	gs.get_sensor(GRIP).error = 0.0
	_tick(gs, 7.3)
	if gs.is_interlock_overridden(ROBOT) or gs.is_robot_holding(ROBOT):
		return "Back in tolerance, the interlock arms itself."
	if gs.set_interlock_override(ROBOT, true) == "":
		return "Only a holding robot can be overridden."
	for key: String in ["holding", "override", "override_logged"]:
		var data: Dictionary = gs.farm_to_dict()
		data["robots"][ROBOT][key] = 1
		if gs.farm_dict_problem(data) == "":
			return "A bad %s must be refused." % key
	return ""


func test_override_is_fined_once() -> String:
	return _run(_check_fine)


func _check_fine(gs: GameStateScript) -> String:
	gs.audit_grace_used = true
	for id: String in gs.unit_ids() + gs.standard_ids():
		gs.get_sensor(id).error = 0.0
		gs.get_sensor(id).cal_due_day = 1000
	gs.get_sensor(PROBE).error = 5.0
	gs.set_interlock_override(ROBOT, true)
	# Calibrating before the audit doesn't clear the log.
	gs.get_sensor(PROBE).error = 0.0
	_tick(gs, 7.1)
	var credits: int = gs.credits
	gs._run_audit(10)
	if gs.credits != credits - AuditEngine.interlock_fine() or gs.audit_log.back()["passed"]:
		return "The override alone must cost one fine, took %d." % (credits - gs.credits)
	gs._run_audit(15)
	if not gs.audit_log.back()["passed"]:
		return "It is fined once."
	gs.get_sensor(PROBE).error = 5.0
	gs.set_interlock_override(ROBOT, true)
	gs._run_audit(20)
	if not gs.robots[ROBOT]["override_logged"]:
		return "A standing override stays in the log."
	gs.audit_grace_used = false
	credits = gs.credits
	gs._run_audit(25)
	if gs.credits != credits or gs.robots[ROBOT]["override_logged"] or gs.is_interlock_overridden(ROBOT):
		return "The one-time warning covers it."
	return "" if str(gs.audit_log.back()["waived_names"]).contains("armed Trellis TR-1's interlock") else "The manager must say so: %s" % gs.audit_log.back()["waived_names"]


func test_drift_effects() -> String:
	return _run(_check_effects)


func _check_effects(gs: GameStateScript) -> String:
	var target: float = _target(gs)
	gs.tilled_cells[NEXT] = true
	gs.plant_crop(NEXT, "biscuit_reed")
	gs.plantings[NEXT]["setpoint"] = target
	gs.add_robot_card(ROBOT, "soil")
	# 2 MPE high: a 10 step trim lands 2 steps short.
	gs.get_sensor(TANK).error = 4.0
	gs.set_interlock_override(ROBOT, true)
	gs.plantings[CELL]["setpoint"] = target - 0.1
	_tick(gs, 7.1)
	if not _is_at(gs, CELL, target - 0.02):
		return "A 10 step trim must fall 2 short: %s." % gs.plantings[CELL]["setpoint"]
	for id: String in gs.robot_sensor_ids(ROBOT):
		gs.get_sensor(id).error = 0.0
	gs.plantings[CELL]["setpoint"] = target
	gs.get_sensor(ENCODER).error = 0.99
	_tick(gs, 7.11)
	if gs._robot_plot_offset(ROBOT) != 0:
		return "In tolerance, the water lands where it should."
	gs.get_sensor(ENCODER).error = 1.1
	gs.set_interlock_override(ROBOT, true)
	gs.plantings[CELL]["setpoint"] = target - 0.1
	gs.robot_cards(ROBOT)[0]["last_day"] = 7
	_tick(gs, 7.2)
	if not _is_at(gs, CELL, target - 0.1) or not _is_at(gs, NEXT, target + 0.1):
		return "The water must land on the next plot: %s." % gs.plantings
	_tick(gs, 7.3)
	if not _is_at(gs, NEXT, target + 0.1):
		return "Off by a plot, the soil card runs once a day."
	_tick(gs, 8.2)
	if not _is_at(gs, NEXT, target + 0.2):
		return "It must run again the next day."
	gs.get_sensor(ENCODER).error = -1.1
	return "" if gs._robot_plot_offset(ROBOT) == -1 else "A negative error misses the other way."


func test_use_wears_the_sensors() -> String:
	return _run(_check_wear)


func _check_wear(gs: GameStateScript) -> String:
	gs.add_robot_card(ROBOT, "soil")
	_tick(gs, 7.1)
	if gs.get_sensor(PROBE).error != 0.0:
		return "A check that trims nothing wears nothing."
	var encoder: DriftingSensor = gs.get_sensor(ENCODER)
	encoder.error = 0.999 * encoder._sign
	gs.get_sensor("soil_probe").error = 8.0
	_tick(gs, 7.2)
	if not _is_at(gs, CELL, _target(gs) + 0.08) or gs.get_sensor(GRIP).error != 0.0 or gs.get_sensor(TANK).error == 0.0:
		return "The job wears the encoder, tank and probe, and not the grip."
	return "" if gs.is_robot_holding(ROBOT) and gs.robots[ROBOT]["holding"] else "The job that takes it out of tolerance is its last."
