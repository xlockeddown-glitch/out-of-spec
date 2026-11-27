class_name LabSitter
extends RefCounted
## The lab sitter: a new hire the farm books for one game day (docs/design/zones.md
## section 9). She waters the plants and collects the day's spools by the same
## code the robots and players use, and she never calibrates. Pure rules;
## GameState applies them. Her name, the fee and every word are in
## data/economy.json ("lab_sitter") [PLACEHOLDER].

const TABLE: StringName = &"economy"
const PATH: String = "lab_sitter/"
## A booking is { "day", "watered", "spools" }: the day she works, the plots she
## has trimmed so far and the spools she has collected so far.
const KEYS: Array[String] = ["day", "watered", "spools"]
## The most a count may be in a saved booking: far more than a farm has.
const MOST: int = 1000


static func number(key: String, fallback: float) -> float:
	return DataManager.get_number(TABLE, PATH + key, fallback)


static func text(key: String) -> String:
	return str(DataManager.get_value(TABLE, PATH + key, ""))


## Her plain name [PLACEHOLDER].
static func sitter_name() -> String:
	return text("name")


## What a day of her costs, in the shared wallet's credits [PLACEHOLDER].
static func fee() -> int:
	return maxi(int(number("fee_credits", 40.0)), 0)


## The day she works when booked on `current_day`: always the next one, so the
## booking starts at 06:00 and never changes a day already half gone [ASSUMPTION].
static func booked_day(current_day: int) -> int:
	return current_day + 1


## A new booking for `day`, with nothing done yet.
static func new_booking(day: int) -> Dictionary:
	return { "day": day, "watered": 0, "spools": 0 }


## True when there is a booking.
static func is_booked(booking: Dictionary) -> bool:
	return not booking.is_empty()


## The set point steps that bring a plot's probe reading (percent) to its
## crop's target (a fraction), as far as the set point can still move. The
## same sum a robot's WATER card does, with the sitter reading the probe.
static func trim_steps(target: float, reading_pct: float, setpoint: float, step: float) -> int:
	var steps: int = roundi((target * 100.0 - reading_pct) / 100.0 / step)
	return clampi(steps, -roundi(setpoint / step), roundi((1.0 - setpoint) / step))


## "" or why a saved booking can't be loaded.
static func booking_problem(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return "'lab_sitter' is not a dictionary."
	var booking: Dictionary = value
	if booking.is_empty():
		return ""
	if booking.size() != KEYS.size():
		return "'lab_sitter' does not have exactly %s." % ", ".join(KEYS)
	for key: String in KEYS:
		if not booking.has(key) or typeof(booking[key]) != TYPE_INT:
			return "'lab_sitter' has no whole number '%s'." % key
	if int(booking["day"]) < 1:
		return "'lab_sitter' works on a day before day 1."
	for key: String in ["watered", "spools"]:
		if int(booking[key]) < 0 or int(booking[key]) > MOST:
			return "'lab_sitter' has a count out of range."
	return ""


## The end-of-day Dispatch line: what she did.
static func report_text(booking: Dictionary) -> String:
	return text("report_text") % [sitter_name(), SP811.integer(int(booking["day"])),
		SP811.integer(int(booking["watered"])), SP811.integer(int(booking["spools"]))]
