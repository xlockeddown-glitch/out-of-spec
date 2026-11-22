extends RefCounted


func test_pass_and_fail_follow_band() -> String:
	var sensor: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	sensor.cal_due_day = 5
	var sensors: Dictionary = {sensor.instrument_id: sensor}
	for error: float in [3.2, 4.0]:
		sensor.error = error
		var report: Dictionary = AuditEngine.evaluate(5, sensors, {sensor.instrument_id: 2}, [])
		if not report["passed"] or report["total_fine"] != 0:
			return "Green and guard-band readings must pass without a fine: %s" % report
	sensor.error = 4.4
	var failed: Dictionary = AuditEngine.evaluate(5, sensors, {}, [])
	if failed["passed"] or failed["total_fine"] != 60:
		return "An out-of-tolerance reading must fail and cost 60 CR: %s" % failed
	return ""


func test_fine_is_capped_after_surcharges() -> String:
	var fine: int = AuditEngine.fine_for(3.0, true, true, 3)
	return "" if fine == 350 else "Expected the 350 CR instrument cap, got %d." % fine


func test_overdue_fine_applies_in_band() -> String:
	var sensor: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	sensor.cal_due_day = 5
	var report: Dictionary = AuditEngine.evaluate(6, {sensor.instrument_id: sensor}, {}, [])
	if report["passed"] or report["total_fine"] != 50:
		return "An overdue in-band instrument must fail and cost 50 CR: %s" % report
	return ""


func test_repeat_surcharge_is_added_once_and_capped() -> String:
	var twice: int = AuditEngine.fine_for(1.5, true, true, 2)
	if twice != 200:
		return "Expected 100 CR for error, 50 CR overdue and one 50 CR repeat surcharge, got %d." % twice
	var many: int = AuditEngine.fine_for(0.0, false, true, 20)
	return "" if many == 150 else "Expected 50 CR overdue plus a capped 100 CR repeat surcharge, got %d." % many
