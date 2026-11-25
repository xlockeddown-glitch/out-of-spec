extends RefCounted


func test_a_message_is_split_into_sender_and_text() -> String:
	var expected: Dictionary[String, PackedStringArray] = {
		"> ZERO STEERING sent (450 ms lag)": ["YOU", "SENT", "ZERO STEERING sent (450 ms lag)"],
		"DAY 3  07:10  [VANCE] Papers, please.": ["DISPATCH", "VANCE  DAY 3  07:10", "Papers, please."],
		"LIN: Press L to sell.": ["LIN", "LIN", "Press L to sell."],
		"FIELD CAL PAD: stop the rover on the pad first.": ["", "", "FIELD CAL PAD: stop the rover on the pad first."],
		"AUDIT passed": ["AUDIT", "", "AUDIT passed"],
		"Drilled 1 crystal ore.": ["", "", "Drilled 1 crystal ore."],
	}
	for line: String in expected:
		if FieldPhoneHUD.message_parts(line) != expected[line]:
			return "%s became %s." % [line, FieldPhoneHUD.message_parts(line)]
	return ""


func test_the_needle_stays_on_the_dial() -> String:
	var gauge := PhoneGauge.new()
	gauge.set_limits(4.0, 0.8)
	var angles: Array[float] = [gauge.angle_of(0.0), gauge.angle_of(6.0), gauge.angle_of(-60.0), gauge.angle_of(3.0)]
	gauge.free()
	if angles[0] != 0.0 or not is_equal_approx(angles[1], PhoneGauge.SWEEP) or not is_equal_approx(angles[2], -PhoneGauge.SWEEP):
		return "The dial's middle or ends are wrong: %s." % [angles]
	return "" if is_equal_approx(angles[3], PhoneGauge.SWEEP * 0.5) else "Half way isn't half way."
