extends RefCounted
## Milestone 3a hooks (Ryan, 2026-11-22): the terrarium thermometer feeds the
## molt like the hygrometer, AUD-1T fines out-of-spec rover tires on its own
## phone line, and the tire gauge can be calibrated on the field pad.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FM3: String = "field_meter_dc"
const WD1: String = "reference_gauge"
const DRIFT: StringName = &"sensor_drift_config"


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 10000
	gs.crystal_ore = 10
	gs.tier1_unlocked = true
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	return gs


func _set_day(day: int) -> void:
	GameClock.elapsed_days = float(day - 1)


func test_thermometer_pauses_molt_only_in_service() -> String:
	var gs: GameStateScript = _make_state()
	var thermo: DriftingSensor = gs.get_sensor(gs.THERMOMETER_ID)
	var problem: String = ""
	gs.hygrometer.error = 0.0
	thermo.error = thermo.mpe * 2.0
	if gs.is_molt_paused():
		problem = "Before the FM-3 is owned the thermometer must not hold the molt."
	if problem == "" and gs.buy_standard(FM3) != "":
		problem = "Could not buy the FM-3 for the test."
	thermo.error = thermo.mpe * 2.0  # the purchase doesn't touch the unit, but be sure
	if problem == "" and gs.molt_pause_reason() != "temperature out of range":
		problem = "Thermometer past MPE must pause with 'temperature out of range', got '%s'." % gs.molt_pause_reason()
	gs.hygrometer.error = gs.hygrometer.mpe * 2.0
	if problem == "" and gs.molt_pause_reason() != "temperature and humidity out of range":
		problem = "Both past MPE must name both, got '%s'." % gs.molt_pause_reason()
	thermo.error = thermo.mpe * 0.9
	if problem == "" and gs.molt_pause_reason() != "humidity out of range":
		problem = "Thermometer within MPE must drop out of the reason, got '%s'." % gs.molt_pause_reason()
	gs.hygrometer.error = 0.0
	var before: float = gs.molt_progress
	gs._tick_molt(1.0)
	if problem == "" and (gs.is_molt_paused() or gs.molt_progress <= before):
		problem = "Both within MPE: the molt must advance."
	thermo.error = thermo.mpe * 2.0
	before = gs.molt_progress
	gs._tick_molt(1.0)
	if problem == "" and gs.molt_progress != before:
		problem = "Thermometer past MPE must stop the molt ticking."
	gs.free()
	return problem


func test_tire_check_offset_and_limit() -> String:
	var limit: float = DataManager.get_number(DRIFT, "compliance_fine/aud1t_tire_limit_kpa", NAN)
	if is_nan(limit) or limit <= 0.0:
		return "sensor_drift_config needs a positive compliance_fine/aud1t_tire_limit_kpa."
	var inside: Dictionary = AuditEngine.tire_check(limit * 0.5)
	var outside: Dictionary = AuditEngine.tire_check(-limit * 1.5)
	if not is_equal_approx(inside["offset_kpa"], -limit * 0.5):
		return "Tires filled to a gauge reading high must sit low by the error: %s" % inside
	if inside["violation"] or inside["fine"] != 0:
		return "Inside the limit must not fine: %s" % inside
	if not outside["violation"] or outside["fine"] <= 0 or outside["offset_kpa"] <= 0.0:
		return "A gauge reading low past the limit leaves the tires high and fined: %s" % outside
	return ""


func test_aud1t_tire_line_warns_then_fines() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = int(DataManager.get_number(DRIFT, "audit_schedule/cadence_days", NAN))
	var problem: String = ""
	if gs.buy_standard(WD1) != "":
		problem = "Could not buy the WD-1 for the test."
	for id: String in gs.unit_ids():
		gs.get_sensor(id).error = 0.0
		gs.get_sensor(id).cal_due_day = 4 * cadence
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	var limit: float = DataManager.get_number(DRIFT, "compliance_fine/aud1t_tire_limit_kpa", 6.9)

	_set_day(cadence)
	tire.error = limit * 1.5
	gs._run_audit(cadence)
	var first: Dictionary = gs.audit_log[-1]
	var first_tire: Dictionary = first.get("tire_check", {})

	_set_day(2 * cadence)
	tire.error = limit * 1.5
	tire.cal_due_day = 4 * cadence
	var credits_before: int = gs.credits
	gs._run_audit(2 * cadence)
	var second: Dictionary = gs.audit_log[-1]
	var second_tire: Dictionary = second.get("tire_check", {})
	var line_fines: int = 0
	for line: Dictionary in second["lines"]:
		line_fines += int(line["fine"])
	var phone: String = "\n".join(gs.phone_log)
	var credits_after: int = gs.credits
	GameClock.elapsed_days = saved
	gs.free()

	if problem != "":
		return problem
	if first_tire.is_empty() or not first_tire.get("waived", false) or first["total_fine"] != 0:
		return "The first audit must check the tires and waive them under the one-time warning: %s" % first_tire
	if second_tire.is_empty() or not second_tire["violation"] or second_tire["fine"] <= 0 or second["passed"]:
		return "The second audit must fine the tires: %s" % second_tire
	if second["total_fine"] != line_fines + int(second_tire["fine"]):
		return "Total %d must be Vance's lines %d plus AUD-1T's %d." % [
			second["total_fine"], line_fines, second_tire["fine"]]
	if credits_before - credits_after != int(second["total_fine"]):
		return "Credits must drop by the total fine."
	if not phone.contains("AUD-1T: Rover tires") or not phone.contains("PETTY FINE"):
		return "AUD-1T must post its own tire line on the phone."
	return ""


func test_no_tire_check_before_wd1() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = int(DataManager.get_number(DRIFT, "audit_schedule/cadence_days", 5.0))
	_set_day(cadence)
	gs._run_audit(cadence)
	var report: Dictionary = gs.audit_log[-1]
	GameClock.elapsed_days = saved
	gs.free()
	return "" if not report.has("tire_check") else "Without the WD-1 the tire gauge is out of service; AUD-1T must skip the tires."
