extends RefCounted
## Milestone 1 calibration core: the uncertainty budget, TUR, RSS acceptance
## limit, pass / indeterminate / fail, the standard's hidden error carried into
## the unit, the 2:1 refusal, bench time and the sensor registry.
## Expected numbers come from the formulas or the data tables, so retuning the
## placeholders doesn't break these. GameClock.elapsed_days is saved and restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DRIFT: StringName = &"sensor_drift_config"
const EPS: float = 1.0e-9


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	return gs


func _set_day(day: int) -> void:
	GameClock.elapsed_days = float(day - 1)


func test_spec_and_resolution_conversions() -> String:
	if absf(CalUncertainty.spec_to_standard(1.0, 95.0) - 0.5) > EPS:
		return "A spec stated at 95 %% must divide by 2, got %s." % CalUncertainty.spec_to_standard(1.0, 95.0)
	if absf(CalUncertainty.spec_to_standard(1.0, 0.0) - 1.0 / sqrt(3.0)) > EPS:
		return "A spec with no stated confidence must be rectangular (÷ √3)."
	if absf(CalUncertainty.resolution_to_standard(0.1) - 0.1 / 2.0 / sqrt(3.0)) > EPS:
		return "Resolution must be half a digit, rectangular."
	return ""


func test_acceptance_limit_at_four_to_one() -> String:
	# Worked value from the design doc: at 4:1, A = √(1 − 1/16) × MPE ≈ 0.968 × MPE.
	var limit: float = CalUncertainty.acceptance_limit(1.0, 0.25)
	if absf(limit - sqrt(15.0 / 16.0)) > EPS:
		return "A at 4:1 must be √(15/16) × MPE, got %s." % limit
	if CalUncertainty.acceptance_limit(1.0, 2.0) != 0.0:
		return "A must floor at 0 when U > MPE."
	return ""


func test_classify_boundaries() -> String:
	for sign_value: float in [-1.0, 1.0]:
		if CalUncertainty.classify(sign_value * 0.9, 1.0, 0.9) != CalUncertainty.PASS:
			return "|x| = A must pass."
		if CalUncertainty.classify(sign_value * 0.95, 1.0, 0.9) != CalUncertainty.INDETERMINATE:
			return "A < |x| <= MPE must be indeterminate."
		if CalUncertainty.classify(sign_value * 1.0, 1.0, 0.9) != CalUncertainty.INDETERMINATE:
			return "|x| = MPE must still be indeterminate."
		if CalUncertainty.classify(sign_value * 1.01, 1.0, 0.9) != CalUncertainty.FAIL:
			return "|x| > MPE must fail."
	return ""


func test_budget_matches_the_formula() -> String:
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.steering
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	var budget: Dictionary = gs.calibration_budget(gs.STEERING_ID)
	gs.free()
	if standard == null:
		return "Steering names no known standard (%s)." % unit.calibrated_by
	var u_spec: float = CalUncertainty.spec_to_standard(standard.mpe, standard.spec_confidence_pct)
	var u_cert: float = standard.certificate_uncertainty / standard.certificate_k
	var u_res: float = CalUncertainty.resolution_to_standard(unit.resolution)
	var expanded: float = CalUncertainty.coverage_factor() * sqrt(u_spec * u_spec + u_cert * u_cert + u_res * u_res)
	if absf(budget["expanded_uncertainty"] - expanded) > EPS:
		return "U must be k × RSS of the terms: expected %s, got %s." % [expanded, budget["expanded_uncertainty"]]
	if absf(budget["tur"] - unit.mpe / expanded) > EPS:
		return "TUR must be MPE / U."
	if absf(budget["acceptance_limit"] - sqrt(unit.mpe * unit.mpe - expanded * expanded)) > EPS:
		return "A must be √(MPE² − U²)."
	return ""


func test_every_unit_has_a_standard_above_the_floor() -> String:
	var gs: GameStateScript = _make_state()
	var problems: PackedStringArray = []
	for id: String in gs.unit_ids():
		var budget: Dictionary = gs.calibration_budget(id)
		if budget.is_empty():
			problems.append("%s has no standard" % id)
		elif budget["refused"]:
			problems.append("%s TUR %s is under the floor" % [id, budget["tur"]])
	gs.free()
	return "" if problems.is_empty() else "Starting data must let the bench calibrate every unit: " + ", ".join(problems)


func test_registry_holds_units_and_standards() -> String:
	var gs: GameStateScript = _make_state()
	var units: Array[String] = gs.unit_ids()
	var standards: Array[String] = gs.standard_ids()
	gs.free()
	for id: String in [GameStateScript.STEERING_ID, GameStateScript.HYGROMETER_ID, "relay_dish_azimuth"]:
		if not units.has(id):
			return "Units must include %s: %s" % [id, units]
	for id: String in ["rotary_table", "humidity_generator"]:
		if not standards.has(id):
			return "Standards must include %s: %s" % [id, standards]
	for id: String in standards:
		if units.has(id):
			return "%s cannot be both a unit and a standard." % id
	return ""


func test_audit_skips_standards() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = int(DataManager.get_number(DRIFT, "audit_schedule/cadence_days", 5.0))
	_set_day(cadence)
	for id: String in gs.standard_ids():
		gs.get_sensor(id).error = gs.get_sensor(id).mpe * 2.0  # would be fined if audited
	gs._run_audit(cadence)
	var report: Dictionary = gs.audit_log[-1]
	var standards: Array[String] = gs.standard_ids()
	GameClock.elapsed_days = saved
	gs.free()
	for line: Dictionary in report["lines"]:
		if standards.has(line["instrument_id"]):
			return "Standards are not audited until milestone 2: %s" % line
	return ""


func test_standard_error_carries_into_the_unit() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.steering
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	_set_day(unit.cal_due_day)
	standard.error = standard.mpe * 0.5
	unit.error = unit.mpe * 0.25
	var expected_found: float = unit.error - standard.error
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)
	var true_after: float = unit.error
	GameClock.elapsed_days = saved
	gs.free()
	if absf(record["as_found"] - expected_found) > EPS:
		return "Observed as-found must be e_unit − e_standard (%s), got %s." % [expected_found, record["as_found"]]
	if absf(true_after - (standard.error + record["as_left"])) > EPS:
		return "After adjustment the unit's true error must be e_standard + residual."
	if record["standard_id"] != standard.instrument_id or not record["traceable"]:
		return "A bench record must name its standard and be traceable: %s" % record
	return ""


func test_low_tur_refuses_and_changes_nothing() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.steering
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	_set_day(unit.cal_due_day)
	# A certificate as wide as the unit's MPE puts the TUR near 1:1.
	standard.certificate_uncertainty = unit.mpe * standard.certificate_k
	unit.error = unit.mpe * 2.0
	var before_error: float = unit.error
	var before_due: int = unit.cal_due_day
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)
	var log_size: int = gs.cal_log.size()
	GameClock.elapsed_days = saved
	gs.free()
	if not record.get("refused", false):
		return "A TUR under the floor must refuse: %s" % record
	if record["tur"] >= CalUncertainty.tur_floor():
		return "The test setup must push the TUR under the floor, got %s." % record["tur"]
	if unit.error != before_error or unit.cal_due_day != before_due or log_size != 0:
		return "A refused calibration must not adjust, reschedule or log anything."
	return ""


func test_indeterminate_counts_as_pass_without_lengthening() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.hygrometer  # its TUR leaves a visible band between A and MPE
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	var budget: Dictionary = gs.calibration_budget(gs.HYGROMETER_ID)
	var limit: float = budget["acceptance_limit"]
	var initial: int = unit.cal_interval_days
	_set_day(unit.cal_due_day)  # on time, with a full interval in service
	standard.error = 0.0
	unit.error = (limit + unit.mpe) / 2.0
	var record: Dictionary = gs.calibrate(gs.HYGROMETER_ID)
	GameClock.elapsed_days = saved
	gs.free()
	if record["result"] != CalUncertainty.INDETERMINATE:
		return "As-found between A (%s) and MPE (%s) must be indeterminate: %s" % [limit, unit.mpe, record["result"]]
	if not record["as_found_in_tolerance"]:
		return "An indeterminate result is still inside the MPE."
	if record["interval_days"] != initial:
		return "Indeterminate must keep the %d d interval, got %d d." % [initial, record["interval_days"]]
	return ""


func test_remote_zero_is_untraceable() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	_set_day(gs.steering.cal_due_day)
	gs.steering.error = gs.steering.mpe * 0.5
	var before_interval: int = gs.steering.cal_interval_days
	var before_due: int = gs.steering.cal_due_day
	var before_last: int = gs.steering.last_cal_day
	var record: Dictionary = gs.calibrate(gs.STEERING_ID, "You", false)
	var after_error: float = gs.steering.error
	var schedule_kept: bool = (gs.steering.cal_interval_days == before_interval
		and gs.steering.cal_due_day == before_due and gs.steering.last_cal_day == before_last)
	GameClock.elapsed_days = saved
	gs.free()
	if record["traceable"] or record["standard_id"] != "" or record["tur"] != null:
		return "A zero without a standard must be untraceable with no TUR: %s" % record
	if record["acceptance_limit"] != record["mpe"]:
		return "Without a standard the acceptance limit is the MPE."
	if not schedule_kept:
		return "An untraceable zero must not change the interval, due day or last calibration day."
	if absf(after_error) > absf(record["as_found"]):
		return "An untraceable zero must still adjust the unit."
	return ""


func test_negative_as_found_with_opposite_standard_error() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.hygrometer
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	_set_day(unit.cal_due_day)
	standard.error = standard.mpe * 0.5
	unit.error = -unit.mpe * 1.2  # observed −1.2 × MPE − e_s: a clear fail on the negative side
	var record: Dictionary = gs.calibrate(gs.HYGROMETER_ID)
	var true_after: float = unit.error
	GameClock.elapsed_days = saved
	gs.free()
	if absf(record["as_found"] - (-unit.mpe * 1.2 - standard.error)) > EPS:
		return "Observed as-found must be e_unit − e_standard on the negative side, got %s." % record["as_found"]
	if record["result"] != CalUncertainty.FAIL:
		return "A negative as-found beyond −MPE must fail, got %s." % record["result"]
	if absf(true_after - (standard.error + record["as_left"])) > EPS:
		return "After adjustment the unit's true error must be e_standard + residual."
	return ""


func test_bench_refusal_takes_no_time() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.steering
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	_set_day(unit.cal_due_day)
	standard.certificate_uncertainty = unit.mpe * standard.certificate_k
	var start: float = GameClock.elapsed_days
	var before_last: int = unit.last_cal_day
	var record: Dictionary = gs.calibrate_at_bench(gs.STEERING_ID)
	var elapsed: float = GameClock.elapsed_days - start
	var last_after: int = unit.last_cal_day
	GameClock.elapsed_days = saved
	gs.free()
	if not record.get("refused", false):
		return "The setup must refuse: %s" % record
	if elapsed != 0.0 or last_after != before_last:
		return "A refused bench calibration must take no time and record nothing."
	return ""


func test_bench_time_advances_the_clock() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.steering
	_set_day(unit.cal_due_day)
	var start: float = GameClock.elapsed_days
	var record: Dictionary = gs.calibrate_at_bench(gs.STEERING_ID)
	var elapsed: float = GameClock.elapsed_days - start
	GameClock.elapsed_days = saved
	gs.free()
	if unit.bench_minutes <= 0.0:
		return "Steering must have bench_minutes in the data."
	if absf(elapsed - unit.bench_minutes / 1440.0) > 1.0e-6:
		return "Bench calibration must advance the clock %s min, advanced %s d." % [unit.bench_minutes, elapsed]
	if record.get("bench_minutes", -1.0) != unit.bench_minutes:
		return "The record must carry bench_minutes: %s" % record
	return ""


func test_remote_zero_blocks_the_next_bench_lengthening() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.steering
	var standard: DriftingSensor = gs.get_sensor(unit.calibrated_by)
	var initial: int = unit.cal_interval_days
	_set_day(unit.cal_due_day)
	standard.error = 0.0
	unit.error = unit.mpe * 2.0
	gs.calibrate(gs.STEERING_ID, "You", false)  # remote zero hides the FAIL
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)  # on-time bench pass
	GameClock.elapsed_days = saved
	gs.free()
	if record["result"] == CalUncertainty.FAIL:
		return "The setup must give a bench pass after the zero."
	if record["interval_days"] > initial:
		return "A bench pass right after an untraceable zero must not lengthen the interval."
	return ""
