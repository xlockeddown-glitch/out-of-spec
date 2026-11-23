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
	if not is_equal_approx(inside["offset_kpa"], -roundi(limit * 0.5 / AuditEngine.TIRE_REPORT_KPA) * AuditEngine.TIRE_REPORT_KPA):
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
	var phone: Array[String] = gs.phone_log.duplicate()
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
	var tire_index: int = -1
	var verdict_index: int = -1
	for i: int in phone.size():
		if phone[i].begins_with("AUD-1T: Rover tires"):
			tire_index = i
		elif phone[i].begins_with("TOTAL FINE"):
			verdict_index = i
	var tire_line: String = phone[tire_index] if tire_index >= 0 else ""
	if not tire_line.contains("below set point") or not tire_line.ends_with("PETTY FINE %d CR" % int(second_tire["fine"])):
		return "AUD-1T's own line must name the offset and the fine, got '%s'." % tire_line
	if verdict_index - tire_index != 1:
		return "AUD-1T's line must post just before the verdict so the phone keeps it."
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


func test_tire_limit_edge_and_compliant_line() -> String:
	var limit: float = DataManager.get_number(DRIFT, "compliance_fine/aud1t_tire_limit_kpa", NAN)
	var gs: GameStateScript = _make_state()
	var at_limit: Dictionary = AuditEngine.tire_check(-limit)
	var rounds_to_limit: Dictionary = AuditEngine.tire_check(-(limit + 0.004))
	var just_over: Dictionary = AuditEngine.tire_check(-(limit + 0.06))
	var at_line: String = gs._tire_check_line(at_limit)
	var over_line: String = gs._tire_check_line(just_over)
	var tie_lines: Array[String] = [gs._tire_check_line(AuditEngine.tire_check(limit + 0.05)),
		gs._tire_check_line(AuditEngine.tire_check(-(limit + 0.05)))]
	gs.free()
	if at_limit["violation"] or at_limit["fine"] != 0:
		return "Exactly at the limit must be compliant: %s" % at_limit
	if not at_line.ends_with(". Compliant."):
		return "A compliant check must say so, got '%s'." % at_line
	for sign: float in [1.0, -1.0]:
		for extra: float in [0.04, 0.0501, 0.06]:
			var check: Dictionary = AuditEngine.tire_check(sign * (limit + extra))
			if check["violation"] != (extra > 0.05) or not is_equal_approx(absf(check["offset_kpa"]),
					snappedf(limit, 0.1) + (0.1 if extra > 0.05 else 0.0)):
				return "Gauge error %s kPa must round the same way in both directions: %s" % [sign * (limit + extra), check]
	for sign: float in [1.0, -1.0]:
		for tie: Array in [[0.05, 0.1], [0.15, 0.2], [0.25, 0.3]]:
			var check: Dictionary = AuditEngine.tire_check(sign * float(tie[0]))
			if not is_equal_approx(check["offset_kpa"], -sign * float(tie[1])):
				return "A %s kPa half step must round away from zero: %s" % [sign * float(tie[0]), check]
		var at_tie: Dictionary = AuditEngine.tire_check(sign * (limit + 0.05))
		var tie_line: String = tie_lines[0 if sign > 0.0 else 1]
		var reads_past: bool = tie_line.contains("%s kPa" % SP811.number(limit + 0.1, 1))
		if not at_tie["violation"] or not reads_past or not tie_line.contains("(limit %s kPa)" % SP811.number(limit, 1)):
			return "At the half step past the limit, the line must read past the limit and fine: '%s'" % tie_line
	if rounds_to_limit["violation"]:
		return "An offset AUD-1T reports as the limit must be compliant: %s" % rounds_to_limit
	if not just_over["violation"]:
		return "An offset reported 0.1 kPa past the limit must be a violation: %s" % just_over
	if not over_line.contains("%s kPa above set point" % SP811.number(limit + 0.1, 1)):
		return "A fined offset must read past the limit, got '%s'." % over_line
	return ""


## Ryan (2026-11-22): "both". The field pad also calibrates the steering
## encoder on the encoder jig, against the PX-1 rotary table the colony starts
## with; the tire gauge joins once the WD-1 is bought.
func test_field_pad_calibrates_steering_and_then_tires() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var offered: Array[String] = gs.field_cal_ready()
	if offered != [gs.STEERING_ID]:
		problem = "Before the WD-1 the pad must offer only steering, got %s." % [offered]
	if problem == "" and gs.buy_standard(WD1) != "":
		problem = "Could not buy the WD-1 for the test."
	offered = gs.field_cal_ready()
	if problem == "" and offered != [gs.TIRE_ID, gs.STEERING_ID]:
		problem = "With the WD-1 the pad must offer the tire gauge then steering, got %s." % [offered]
	var record: Dictionary = gs.calibrate_at_bench(gs.STEERING_ID)
	if problem == "" and (record.is_empty() or record.get("refused", false)):
		problem = "Steering calibration on the pad was refused: %s" % [record]
	gs.free()
	return problem
