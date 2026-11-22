class_name SP811
extends RefCounted
## NIST SP 811 (2008) number formatting for player-facing text. Rules summary
## and the check script: docs/sp811.md, tools/check_sp811.py.
##   - Minus sign is U+2212, not a hyphen.
##   - More than four digits on one side of the decimal marker: group in
##     threes with a narrow no-break space (U+202F). Never commas.
##   - Space between number and unit symbol (5 ms, 20 °C, 80 %), except the
##     plane-angle degree (4.00°). Callers add the unit; these helpers only
##     format the number.

const MINUS: String = "−"
const NARROW_NBSP: String = " "


## Always-signed value, e.g. +5.60 or −0.48.
static func signed(value: float, decimals: int = 2) -> String:
	return _group(("%+." + str(decimals) + "f") % _snap(value, decimals)).replace("-", MINUS)


## Unsigned or naturally signed value, e.g. 73.6 or −12.0.
static func number(value: float, decimals: int = 2) -> String:
	return _group(("%." + str(decimals) + "f") % _snap(value, decimals)).replace("-", MINUS)


## Whole number with SP 811 grouping, e.g. 427, 12 000, −1500.
static func integer(value: int) -> String:
	return _group(str(value)).replace("-", MINUS)


## Values that round to zero become exactly 0, so they never print as −0.00.
static func _snap(value: float, decimals: int) -> float:
	var step: float = pow(10.0, -decimals)
	var rounded: float = snappedf(value, step)
	# Compare against half a step, not is_zero_approx(): its fixed 1e-5 epsilon
	# would zero real values at 5+ decimals (−0.000 004 printed as +0.000 000).
	return 0.0 if absf(rounded) < step * 0.5 else rounded


static func _group(text: String) -> String:
	var sign_char: String = ""
	if text.begins_with("+") or text.begins_with("-"):
		sign_char = text.substr(0, 1)
		text = text.substr(1)
	var parts: PackedStringArray = text.split(".")
	var int_part: String = parts[0]
	if int_part.length() > 4:
		var grouped: String = ""
		var count: int = 0
		for i: int in range(int_part.length() - 1, -1, -1):
			if count > 0 and count % 3 == 0:
				grouped = NARROW_NBSP + grouped
			grouped = int_part[i] + grouped
			count += 1
		int_part = grouped
	if parts.size() > 1:
		var frac: String = parts[1]
		if frac.length() > 4:
			var g: String = ""
			for i: int in frac.length():
				if i > 0 and i % 3 == 0:
					g += NARROW_NBSP
				g += frac[i]
			frac = g
		return sign_char + int_part + "." + frac
	return sign_char + int_part
