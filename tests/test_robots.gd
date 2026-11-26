extends RefCounted
## Milestone 5, first slice: building and commissioning a robot.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const STANDARD: String = "torque_standard"
const SENSORS: Array[String] = ["robot_joint_encoder@TR-1", "robot_grip_torque@TR-1",
	"robot_tank_pressure@TR-1", "robot_soil_probe@TR-1"]


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.optical_silk_spools = 3
	gs._spool_species.assign([&"a", &"b", &"c"])
	gs.tier1_unlocked = true
	_own(gs, STANDARD)
	_own(gs, "rotary_table")
	_own(gs, "reference_gauge")
	_own(gs, "field_meter_dc")
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = saved
	return problem


## Gives the farm a standard with a certificate, in date for a long time.
func _own(gs: GameStateScript, id: String) -> void:
	gs.owned_standards[id] = 0
	gs.get_sensor(id).cal_due_day = 1000
	gs.certificates[id] = { "id": "TEST-" + id, "standard_id": id }
	for other: String in gs.standard_ids():
		gs.get_sensor(other).cal_due_day = 1000


func _xp(source: String) -> int:
	return int(DataManager.get_record(&"skills", source, "xp_sources").get("xp", 0))


func _built(gs: GameStateScript) -> void:
	gs.build_robot("trellis")
	GameClock.elapsed_days = 7.0
	gs._finish_robot_builds(8)


func _calibrate_all(gs: GameStateScript) -> String:
	for id: String in SENSORS:
		var record: Dictionary = gs.calibrate(id)
		if record.get("refused", false) or record.get("result", "") != CalUncertainty.PASS or not record.get("traceable", false):
			return "%s: %s" % [id, record]
	return ""


func test_build_gates() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	if gs.robot_build_problem("none") == "":
		return "An unknown robot can't be built."
	if gs.robot_build_problem("trellis") != "":
		return "Everything is met: " + gs.robot_build_problem("trellis")
	gs.optical_silk_spools = 0
	if gs.robot_build_problem("trellis") == "":
		return "It costs a spool."
	gs.optical_silk_spools = 3
	gs.crystal_ore = 0
	if gs.robot_build_problem("trellis") == "":
		return "It costs ore."
	gs.crystal_ore = 100
	gs.credits = 0
	if gs.robot_build_problem("trellis") == "":
		return "It costs credits."
	gs.credits = 100000
	gs.get_sensor(STANDARD).cal_due_day = 0
	if not "overdue" in gs.robot_build_problem("trellis"):
		return "The TW-6 must be in date."
	gs.get_sensor(STANDARD).cal_due_day = 1000
	gs.at_oirm[STANDARD] = 9
	if not "OIRM" in gs.robot_build_problem("trellis"):
		return "The TW-6 must be home."
	gs.at_oirm.erase(STANDARD)
	gs.owned_standards.erase(STANDARD)
	if gs.robot_build_problem("trellis") == "" or gs.build_robot("trellis") == "" or not gs.robots.is_empty():
		return "The TW-6 must be owned."
	gs.owned_standards[STANDARD] = 0
	gs.owned_standards.erase("reference_gauge")
	if not "Reference Gauge" in gs.robot_build_problem("trellis"):
		return "Every sensor's standard must be owned."
	gs.owned_standards["reference_gauge"] = 0
	_built(gs)
	if not "Robotics" in gs.robot_build_problem("trellis"):
		return "A second robot needs more Robotics."
	gs.farm_skill_xp["robotics"] = gs.xp_for_level(10)
	return gs.robot_build_problem("trellis")


func test_assembly() -> String:
	return _run(_check_assembly)


func _check_assembly(gs: GameStateScript) -> String:
	if gs.build_robot("trellis") != "" or gs.credits >= 100000 or gs.crystal_ore >= 100:
		return "Ordering must pay."
	if gs.optical_silk_spools != 2 or gs._spool_species != [&"b", &"c"]:
		return "The oldest spool goes in."
	if gs.robot_build_problem("trellis") == "" or gs.robot_release_problem("TR-1") == "":
		return "One build at a time, and none is released while assembling."
	gs._finish_robot_builds(7)
	if gs.get_sensor(SENSORS[0]) != null:
		return "Not ready on the order day."
	gs._finish_robot_builds(8)
	if gs.robot_sensor_ids("TR-1") != SENSORS:
		return "Sensors: %s" % [gs.robot_sensor_ids("TR-1")]
	for id: String in SENSORS:
		var sensor: DriftingSensor = gs.get_sensor(id)
		if sensor == null or sensor.mpe <= 0.0 or absf(sensor.error) > 0.5 * sensor.mpe or sensor.last_cal_day != -1:
			return "%s must start uncalibrated, within half its MPE." % id
		if not sensor.display_name.begins_with("TR-1 ") or not gs.calibration_budget(id)["tur"] >= 4.0:
			return "%s: name or TUR is wrong." % id
		if not id in gs.bench_unit_ids() or id in gs.unit_ids() or not gs.is_commissioning(id):
			return "%s is on the bench but not audited." % id
	return "" if gs.skill_xp("robotics") == 250 else "Building gives Robotics 250."


func test_release() -> String:
	return _run(_check_release)


func _check_release(gs: GameStateScript) -> String:
	_built(gs)
	if not "not calibrated" in gs.release_robot("TR-1") or gs.release_robot("none") == "":
		return "It can't be released uncalibrated."
	gs.contract_state = "active"
	var robotics: int = gs.skill_xp("robotics")
	var calibration: int = gs.skill_xp("calibration")
	var problem: String = _calibrate_all(gs)
	if problem != "":
		return problem
	if gs.contract_run != 0:
		return "Commissioning isn't part of the contract run."
	# Each sensor gives the two robot sources, times its standard's tier scale.
	var each: int = 0
	for id: String in SENSORS:
		each += roundi(_xp("calibrate_robot") * gs.calibration_xp_scale(gs.last_cal_records[id]["standard_id"]))
	if _xp("calibrate_robot") != _xp("calibrate_robot_player") or _xp("calibrate_robot_player") >= _xp("calibrate_player"):
		return "A robot sensor gives the bench less than a unit does."
	if gs.skill_xp("robotics") != robotics + each:
		return "Each robot sensor gives the calibrate_robot XP: %d" % (gs.skill_xp("robotics") - robotics)
	if gs.skill_xp("calibration") != calibration + each:
		return "A robot sensor gives calibrate_robot_player in place of calibrate_player."
	gs.suspect_units[SENSORS[0]] = 6
	if not "suspect" in gs.robot_release_problem("TR-1"):
		return "A suspect sensor holds it back."
	gs.suspect_units.clear()
	gs.last_cal_records[SENSORS[1]]["result"] = CalUncertainty.FAIL
	if gs.robot_release_problem("TR-1") == "":
		return "A failing sensor holds it back."
	gs.last_cal_records[SENSORS[1]]["result"] = CalUncertainty.PASS
	gs.last_cal_records[SENSORS[2]]["traceable"] = false
	if gs.robot_release_problem("TR-1") == "":
		return "An untraceable calibration holds it back."
	gs.last_cal_records[SENSORS[2]]["traceable"] = true
	GameClock.elapsed_days = 40.0
	if not "overdue" in gs.robot_release_problem("TR-1"):
		return "An overdue sensor holds it back."
	GameClock.elapsed_days = 7.0
	if gs.release_robot("TR-1") != "" or gs.release_robot("TR-1") == "":
		return "Ready: it releases once."
	for id: String in SENSORS:
		if not id in gs.unit_ids():
			return "%s is audited after release." % id
	return "" if gs.skill_xp("robotics") == robotics + each + _xp("commission_robot") else "Releasing gives the commission_robot XP."


func test_unreleased_sensors_are_not_audited() -> String:
	return _run(_check_audit)


func _check_audit(gs: GameStateScript) -> String:
	_built(gs)
	GameClock.elapsed_days = 10.0
	gs.suspect_units[SENSORS[0]] = 7
	gs._run_audit(10)
	for line: Dictionary in gs.audit_log.back()["lines"]:
		if "@" in str(line["instrument_id"]):
			return "Audited before release."
	if gs.audit_log.back().get("suspect_units", 0) != 0:
		return "A suspect sensor of an unreleased robot isn't fined."
	gs.credibility = 80
	var before: int = gs.credibility
	gs._charge_overdue_credibility(10)
	var charged: int = before - gs.credibility
	gs.robots["TR-1"]["state"] = "released"
	before = gs.credibility
	gs._charge_overdue_credibility(10)
	return "" if before - gs.credibility > charged else "Only a released robot's overdue sensors cost credibility."


func test_drift_and_stable_seed() -> String:
	return _run(_check_drift)


func _check_drift(gs: GameStateScript) -> String:
	_built(gs)
	var before: float = gs.get_sensor(SENSORS[0]).error
	gs._on_time_advanced(1.0)
	if gs.get_sensor(SENSORS[0]).error == before:
		return "A robot's sensors drift."
	gs._put_units_in_service(STANDARD)
	return "" if gs.get_sensor(SENSORS[1]).last_cal_day == -1 else "Buying a standard must not put a robot's sensors in service."


func test_save_round_trip() -> String:
	return _run(_check_save)


func _check_save(gs: GameStateScript) -> String:
	_built(gs)
	var error: float = gs.get_sensor(SENSORS[3]).error
	var held: DriftingSensor = gs.get_sensor(SENSORS[3])
	var data: Dictionary = gs.farm_to_dict()
	var other: GameStateScript = GameStateScript.new()
	other.build_registry()
	var old: Dictionary = other.farm_to_dict()
	old.erase("robots")
	var problem: String = _check_loads(gs, other, data, old, held, error)
	other.free()
	return problem


func _check_loads(gs: GameStateScript, other: GameStateScript, data: Dictionary, old: Dictionary,
		held: DriftingSensor, error: float) -> String:
	var problem: String = other.farm_from_dict(data)
	if problem != "":
		return problem
	if other.robots != gs.robots or other.get_sensor(SENSORS[3]).error != error \
			or other.get_sensor(SENSORS[3]).display_name != held.display_name:
		return "Robots and their sensors must load."
	other.get_sensor(SENSORS[3]).advance_days(1.0)
	held.advance_days(1.0)
	if other.get_sensor(SENSORS[3]).error != held.error:
		return "A loaded sensor must drift like the saved one."
	if gs.farm_from_dict(data) != "" or gs.get_sensor(SENSORS[3]) != held or held.error != error:
		return "A sensor the farm already has is restored in place."
	for change: Array in [["state", "flying"], ["state", 1], ["done_day", 1.5], ["frame", null], ["frame", "no_such_frame"], ["name", 3], ["ordered_by", 3]]:
		var bad: Dictionary = data.duplicate(true)
		bad["robots"]["TR-1"][change[0]] = change[1]
		if gs.farm_dict_problem(bad) == "":
			return "A bad %s must be refused." % change[0]
	for bad_robots: Dictionary in [{ "TR-1": 3 }, { 4: data["robots"]["TR-1"] }]:
		var bad: Dictionary = data.duplicate(true)
		bad["robots"] = bad_robots
		if gs.farm_dict_problem(bad) == "":
			return "Bad robots must be refused."
	var broken: Dictionary = data.duplicate(true)
	broken["sensors"][SENSORS[0]]["error"] = "x"
	if other.farm_dict_problem(broken) == "":
		return "A bad robot sensor must be refused."
	if other.farm_from_dict(old) != "" or not other.robots.is_empty() or other.get_sensor(SENSORS[0]) != null:
		return "A save without robots has none."
	# And a farm with no robots checks an incoming robot's sensors too.
	return "A bad robot sensor must be refused." if other.farm_dict_problem(broken) == "" else ""


func test_new_robot_keeps_existing_ids() -> String:
	return _run(_check_ids)


func _check_ids(gs: GameStateScript) -> String:
	_built(gs)
	gs.robots["TR-2"] = gs.robots["TR-1"]
	gs.robots.erase("TR-1")
	gs.farm_skill_xp["robotics"] = 1000000.0
	var problem: String = gs.build_robot("trellis")
	if problem != "":
		return problem
	return "" if gs.robots.size() == 2 and gs.robots["TR-2"]["state"] == "commissioning" else "A new robot must not replace one."
