class_name LabSitter
extends RefCounted
## The lab sitter: a new hire the farm books for one game day (docs/design/zones.md
## section 9). She waters the plants and collects the day's spools by the same
## code the robots and players use, and she never calibrates. Pure rules;
## GameState applies them. Her name, the fee and every word are in
## data/economy.json ("lab_sitter") [PLACEHOLDER].

const TABLE: StringName = &"economy"
const PATH: String = "lab_sitter/"
## A booking is { "day", "days", "paid", "watered", "spools" }: the first day she
## works, how many days in a row, the credits paid for each day (0 for a free
## reward day), the plots she has trimmed so far and the spools she has collected
## so far. An old save's booking has only day, watered and spools, and means one day.
const KEYS: Array[String] = ["day", "days", "paid", "watered", "spools"]
const OLD_KEYS: Array[String] = ["day", "watered", "spools"]
## The most a count may be in a saved booking: far more than a farm has.
const MOST: int = 1000
## Ceilings for a saved booking, fixed so tuning max_days() or the fee never
## makes a saved booking refuse a whole farm's load.
const MOST_DAYS: int = 30
const MOST_PAID: int = 100000


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


## The most days in a row one booking may cover [PLACEHOLDER].
static func max_days() -> int:
	return maxi(int(number("max_days", 3.0)), 1)


## What `days` days cost, all taken at booking. No discount for a longer run [PLACEHOLDER].
static func total_fee(days: int) -> int:
	return fee() * days


## The day she works when booked on `current_day`: always the next one, so the
## booking starts at 06:00 and never changes a day already half gone [ASSUMPTION].
static func booked_day(current_day: int) -> int:
	return current_day + 1


## A new booking of `days` days from `day`, each paid `paid` CR, with nothing done yet.
static func new_booking(day: int, days: int = 1, paid: int = 0) -> Dictionary:
	return { "day": day, "days": days, "paid": paid, "watered": 0, "spools": 0 }


## How many days a booking covers: an old booking has one.
static func day_count(booking: Dictionary) -> int:
	return int(booking.get("days", 1))


## The last day she works.
static func last_day(booking: Dictionary) -> int:
	return int(booking["day"]) + day_count(booking) - 1


## The credits paid for each day (an old booking is not known to have paid any).
static func paid_each(booking: Dictionary) -> int:
	return int(booking.get("paid", 0))


## True when she works on `day`.
static func works_on(booking: Dictionary, day: int) -> bool:
	return is_booked(booking) and day >= int(booking["day"]) and day <= last_day(booking)


## How many of her days have not started on `current_day` (a day starts at its 06:00).
static func future_days(booking: Dictionary, current_day: int) -> int:
	if not is_booked(booking):
		return 0
	return clampi(last_day(booking) - maxi(current_day, int(booking["day"]) - 1), 0, day_count(booking))


## Plain words for the days: "day 4" or "days 4-6".
static func days_text(booking: Dictionary) -> String:
	if day_count(booking) == 1:
		return text("days_one") % SP811.integer(int(booking["day"]))
	return text("days_many") % [SP811.integer(int(booking["day"])), SP811.integer(last_day(booking))]


## The booking after the days not yet started are cancelled on `current_day`:
## empty when none had started, else cut to the days worked.
static func after_cancel(booking: Dictionary, current_day: int) -> Dictionary:
	var kept: int = day_count(booking) - future_days(booking, current_day)
	if kept <= 0:
		return {}
	var result: Dictionary = booking.duplicate()
	result["days"] = kept
	return result


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
	var keys: Array[String] = OLD_KEYS if booking.size() == OLD_KEYS.size() else KEYS
	if booking.size() != keys.size():
		return "'lab_sitter' does not have exactly %s." % ", ".join(KEYS)
	for key: String in keys:
		if not booking.has(key) or typeof(booking[key]) != TYPE_INT:
			return "'lab_sitter' has no whole number '%s'." % key
	if int(booking["day"]) < 1:
		return "'lab_sitter' works on a day before day 1."
	if day_count(booking) < 1 or day_count(booking) > MOST_DAYS:
		return "'lab_sitter' has a number of days out of range."
	if paid_each(booking) < 0 or paid_each(booking) > MOST_PAID:
		return "'lab_sitter' has a payment out of range."
	for key: String in ["watered", "spools"]:
		if int(booking[key]) < 0 or int(booking[key]) > MOST:
			return "'lab_sitter' has a count out of range."
	return ""


## The end-of-day Dispatch line: what she did.
static func report_text(booking: Dictionary) -> String:
	return text("report_text") % [sitter_name(), days_text(booking),
		SP811.integer(int(booking["watered"])), SP811.integer(int(booking["spools"]))]
