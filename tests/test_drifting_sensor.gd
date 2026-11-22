extends RefCounted


func test_guard_band_and_mpe_boundaries() -> String:
	var sensor: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	# Steering MPE is 4.0°. Its 80 % acceptance limit is 3.2°.
	for direction: float in [-1.0, 1.0]:
		if sensor.band_for(direction * 3.20) != DriftingSensor.Band.IN_BAND:
			return "The 80 percent acceptance limit must be in band."
		if sensor.band_for(direction * 3.21) != DriftingSensor.Band.GUARDBAND:
			return "Just beyond 80 percent must be in the guard band."
		if sensor.band_for(direction * 4.00) != DriftingSensor.Band.GUARDBAND:
			return "The MPE itself must still be in the guard band."
		if sensor.band_for(direction * 4.01) != DriftingSensor.Band.OUT_OF_TOLERANCE:
			return "Just beyond the MPE must be out of tolerance."
	return ""


func test_zero_reports_as_found_and_as_left() -> String:
	var sensor: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	sensor.error = -4.25
	var reading: Dictionary = sensor.zero()
	if reading.get("as_found") != -4.25:
		return "Expected the original signed error as found: %s" % reading
	if reading.get("as_left") != sensor.error:
		return "Expected the applied residual as left: %s" % reading
	# The random residual is valid on either side of zero. Allow float rounding at the endpoints.
	if absf(sensor.error) > 0.2 and not is_equal_approx(absf(sensor.error), 0.2):
		return "As-left residual exceeded the configured bound: %s" % sensor.error
	return ""


func test_overdue_starts_after_due_day() -> String:
	var sensor: DriftingSensor = DriftingSensor.new()
	if not sensor.is_overdue(1):
		return "A fresh sensor with due day zero must be overdue on day one."
	sensor.cal_due_day = 5
	if sensor.is_overdue(4) or sensor.is_overdue(5) or not sensor.is_overdue(6):
		return "Day five is still valid; day six is overdue."
	return ""
