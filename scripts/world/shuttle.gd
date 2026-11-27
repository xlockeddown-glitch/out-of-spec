class_name Shuttle
extends RefCounted
## The shuttle's rules (docs/design/zones.md section 8.2): launch windows, the
## fare, the license and why a day trip can't go. Pure rules: the windows are a
## function of the game clock alone, nothing is stored or sent. GameState keeps
## the license and runs the booking; the pad and its terminal come with biomes
## step 12. Every number and word is in data/economy.json ("shuttle")
## [PLACEHOLDER].

const TABLE: StringName = &"economy"
const PATH: String = "shuttle/"
const PHOBOS: String = "phobos"
const DEIMOS: String = "deimos"
const MOONS: Array[String] = [PHOBOS, DEIMOS]
## A window counts as open from its start to just before its end, whatever a
## float did to the clock on the way (in game hours).
const EPSILON_H: float = 0.000001
## The terminal at the landing pad: where it stands (x, z) and how near a player must
## be to use it, in metres [PLACEHOLDER]. A guest's pose lags a little, so the host
## allows HOST_SLACK_M more. LandingDressing builds it there.
const TERMINAL_AT := Vector2(7.5, 100.0)
const REACH_M: float = 5.0
const HOST_SLACK_M: float = 1.5


static func number(key: String, fallback: float) -> float:
	return DataManager.get_number(TABLE, PATH + key, fallback)


static func text(key: String) -> String:
	return str(DataManager.get_value(TABLE, PATH + key, ""))


## What a day trip costs each person, in the shared wallet's credits [PLACEHOLDER].
static func fare() -> int:
	return maxi(int(number("fare_credits", 40.0)), 0)


## The lab level the license's exam is offered at [PLACEHOLDER].
static func license_level() -> int:
	return maxi(int(number("license_level", 20.0)), 1)


## How long a day trip takes, there and back, in game hours [PLACEHOLDER].
static func trip_hours() -> float:
	return maxf(number("trip_hours", 6.0), 0.0)


## The most people on one booking [PLACEHOLDER].
static func party_most() -> int:
	return maxi(int(number("party_most", 4.0)), 1)


## True for a moon the shuttle flies to.
static func is_moon(moon: String) -> bool:
	return moon in MOONS


## The moon's name for a line of text.
static func moon_name(moon: String) -> String:
	return moon.capitalize()


## A moon's cycle in game hours: [period, open for, first opens at]. Counted from
## 06:00 of day 1. Phobos: one window each period. Deimos: open, then shut.
static func cycle(moon: String) -> Array[float]:
	var key: String = moon + "/"
	var open: float = maxf(number(key + "open_hours", 1.0), 0.01)
	var period: float = number(key + "period_hours", 0.0)
	if period <= 0.0:
		period = open + maxf(number(key + "shut_hours", 1.0), 0.0)
	return [maxf(period, open + 0.01), open, number(key + "offset_hours", 0.0)]


## True when the moon is up at `elapsed_days` (GameClock.elapsed_days).
static func is_open(moon: String, elapsed_days: float) -> bool:
	if not is_moon(moon):
		return false
	var c: Array[float] = cycle(moon)
	return fposmod(elapsed_days * 24.0 - c[2] + EPSILON_H, c[0]) < c[1]


## The next window to START after `elapsed_days`, as { "start", "end" } in
## elapsed days; empty for a name that is no moon. While a window is open this is
## the one after it: closes_at() says when the open one ends.
static func next_window(moon: String, elapsed_days: float) -> Dictionary:
	if not is_moon(moon):
		return {}
	var c: Array[float] = cycle(moon)
	var k: int = floori((elapsed_days * 24.0 - c[2] + EPSILON_H) / c[0]) + 1
	var start_h: float = float(k) * c[0] + c[2]
	return { "start": start_h / 24.0, "end": (start_h + c[1]) / 24.0 }


## When the open window ends, in elapsed days; -1.0 when the moon is down.
static func closes_at(moon: String, elapsed_days: float) -> float:
	if not is_open(moon, elapsed_days):
		return -1.0
	var c: Array[float] = cycle(moon)
	var k: int = floori((elapsed_days * 24.0 - c[2] + EPSILON_H) / c[0])
	return (float(k) * c[0] + c[2] + c[1]) / 24.0


## "14:20": the clock time of an elapsed time (the day runs 06:00 to 06:00).
static func clock_text(elapsed_days: float) -> String:
	var minutes: int = floori(fposmod(6.0 * 60.0 + elapsed_days * 24.0 * 60.0 + EPSILON_H * 60.0, 24.0 * 60.0))
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## "3 h 10 min", "40 min", or from a day on "1.5 days" (a span in game hours).
static func span_text(hours: float) -> String:
	if ceili(hours * 60.0 - EPSILON_H * 60.0) >= 24 * 60:
		var days: float = snappedf(hours / 24.0, 0.5)
		var shown: String = str(int(days)) if is_equal_approx(days, roundf(days)) else str(days)
		return "%s day%s" % [shown, "" if is_equal_approx(days, 1.0) else "s"]
	var minutes: int = maxi(ceili(hours * 60.0 - EPSILON_H * 60.0), 1)
	@warning_ignore("integer_division")
	var whole: int = minutes / 60
	if whole == 0:
		return "%d min" % minutes
	if minutes % 60 == 0:
		return "%d h" % whole
	return "%d h %d min" % [whole, minutes % 60]


## The short phone or terminal line for a moon at `elapsed_days`:
## "Phobos: next window 14:20, in 3 h 10 min." or "Deimos: up for 1 more day."
static func window_line(moon: String, elapsed_days: float) -> String:
	if not is_moon(moon):
		return text("no_moon_text")
	var up: bool = is_open(moon, elapsed_days)
	var start: float = float(next_window(moon, elapsed_days)["start"])
	if moon == PHOBOS:
		if up:
			var end: float = closes_at(moon, elapsed_days)
			return text("phobos_open_text") % [clock_text(end), span_text((end - elapsed_days) * 24.0)]
		return text("phobos_next_text") % [clock_text(start), span_text((start - elapsed_days) * 24.0)]
	if up:
		return text("deimos_open_text") % span_text((closes_at(moon, elapsed_days) - elapsed_days) * 24.0)
	return text("deimos_next_text") % [span_text((start - elapsed_days) * 24.0), SP811.integer(floori(start) + 1), clock_text(start)]


## "" or why the farm can't use the shuttle yet: the license is the farm's.
## Without it, the lab level says whether Vance's exam is open or still ahead.
static func license_problem(lab_level: int, licensed: bool) -> String:
	if licensed:
		return ""
	if lab_level < license_level():
		return text("not_yet_text") % [SP811.integer(lab_level), SP811.integer(license_level())]
	return text("exam_first_text")


## "" or why a day trip to `moon` for `people` can't go at `elapsed_days`. The
## reasons come in this order: not a moon or a bad party, no license, the moon
## down, the wallet short (fare for each person), the trip running past the 02:00
## recall, and the moon having no hub to land at (`hub_ready`).
static func trip_problem(moon: String, lab_level: int, licensed: bool, credits: int, people: int, elapsed_days: float, hub_ready: bool) -> String:
	if not is_moon(moon):
		return text("no_moon_text")
	if people < 1 or people > party_most():
		return text("bad_party_text") % SP811.integer(party_most())
	var license: String = license_problem(lab_level, licensed)
	if license != "":
		return license
	if not is_open(moon, elapsed_days):
		return text("moon_down_text") % window_line(moon, elapsed_days)
	if credits < fare() * people:
		return text("short_text") % [moon_name(moon), SP811.integer(fare() * people), SP811.integer(fare()), SP811.integer(people), SP811.integer(credits)]
	var day: int = floori(elapsed_days) + 1
	var recall: float = TunnelRecall.at_hour(day, number("recall_hour", 2.0))
	if elapsed_days + trip_hours() / 24.0 > recall + EPSILON_H / 24.0:
		return text("recall_text") % [moon_name(moon), SP811.integer(roundi(trip_hours())), clock_text(recall)]
	if not hub_ready:
		return text("no_hub_text") % moon_name(moon)
	return ""


## "" or why the shuttle's numbers in the data can't be used.
static func data_problem() -> String:
	for key: String in ["fare_credits", "license_level", "trip_hours", "recall_hour", "party_most"]:
		if typeof(DataManager.get_value(TABLE, PATH + key)) not in [TYPE_INT, TYPE_FLOAT]:
			return "shuttle '%s' is not a number." % key
	if fare() < 1 or fare() > 1000:
		return "the fare is out of range."
	if trip_hours() <= 0.0 or trip_hours() >= 24.0:
		return "a day trip must take under a day."
	for moon: String in MOONS:
		for key: String in ["open_hours", "offset_hours"]:
			if typeof(DataManager.get_value(TABLE, PATH + moon + "/" + key)) not in [TYPE_INT, TYPE_FLOAT]:
				return "%s '%s' is not a number." % [moon, key]
		var open: float = number(moon + "/open_hours", 0.0)
		var period: float = number(moon + "/period_hours", 0.0)
		if period <= 0.0:
			if typeof(DataManager.get_value(TABLE, PATH + moon + "/shut_hours")) not in [TYPE_INT, TYPE_FLOAT]:
				return "%s has neither a period nor a shut time." % moon
			period = open + number(moon + "/shut_hours", 0.0)
		if open <= 0.0 or period <= open or number(moon + "/offset_hours", 0.0) < 0.0:
			return "%s has a window that is not sane." % moon
	return ""


## True if a player at `where` (the farm's x, y, z; null when unknown) is near enough
## to the terminal. `slack` is what the host allows beyond REACH_M for a late pose.
static func terminal_near(where: Variant, slack: float = 0.0) -> bool:
	if not where is Vector3:
		return false
	var at: Vector3 = where
	return Vector2(TERMINAL_AT.x - at.x, TERMINAL_AT.y - at.z).length() <= REACH_M + slack
