extends RefCounted


func test_minus_is_unicode() -> String:
	var minus: String = String.chr(0x2212)
	if SP811.signed(-0.48) != minus + "0.48" or SP811.integer(-1500) != minus + "1500":
		return "Expected U+2212 before negative signed and integer values."
	return ""


func test_rounded_zero_has_no_minus() -> String:
	if SP811.signed(-0.001) != "+0.00" or SP811.number(-0.001) != "0.00":
		return "A negative value that rounds to zero must not retain the minus."
	return ""


func test_groups_digits_with_narrow_no_break_spaces() -> String:
	var separator: String = String.chr(0x202F)
	if SP811.integer(1234567) != "1" + separator + "234" + separator + "567":
		return "Expected U+202F between groups of three integer digits."
	if SP811.integer(9999) != "9999":
		return "Four integer digits must remain ungrouped."
	if SP811.number(12.345678, 6) != "12.345" + separator + "678":
		return "Expected U+202F between groups of three fractional digits."
	return ""


func test_small_nonzero_negative_survives_at_requested_precision() -> String:
	var expected: String = String.chr(0x2212) + "0.000" + String.chr(0x202F) + "004"
	var actual: String = SP811.signed(-0.000004, 6)
	return "" if actual == expected else "Expected %s, got %s." % [expected, actual]
