class_name ZoneHazards
extends RefCounted
## The hazard system (docs/design/zones.md sections 5 and 13, build step 8), with its
## one hazard: heat near a vent in the Lava Tubes, depth 1. Pure rules and words, no
## scene state. Where the vents are comes from the same integer hash as the depth
## (ZoneDepth.stream), never Godot's random numbers, so every machine draws the same
## vents; whether a vent is hot is a pure function of the game clock, so nothing of it
## is stored or sent (section 12.2: "a vent cycle: pure function of the clock").
##
## The rule of section 5: a small cost you can see coming, and always a way out. A vent
## is never a wall: the rover can always drive through it. Entering a vent cell in its
## hot half costs the trip: the instruments that ride the rover wear faster until the
## trip ends (GameState.zone_heat_trip). The way out is to wait for the cool half, or
## to go round (vents sit in the two-wide trunk, and never so that the other lane of it
## is shut). The 20 game minutes of section 5 are NOT built: see the decision log.
## Every number and word here is a [PLACEHOLDER].

const ZONE: String = ZoneDepth.ZONE
const DEPTH: int = ZoneDepth.DEPTH

## A vent's cycle in game minutes: hot for HOT_MINUTES, then cool for COOL_MINUTES,
## from a phase the hash gives each vent [PLACEHOLDER]. A game minute is half a
## second of play, so this is 20 s hot and 30 s cool.
const HOT_MINUTES: int = 40
const COOL_MINUTES: int = 60
const PERIOD: int = HOT_MINUTES + COOL_MINUTES
## The vent glows half-bright for this many minutes before it goes hot [PLACEHOLDER].
const WARN_MINUTES: int = 10
## How many vents a day, and how far apart in rows (so one lane of the trunk is
## always clear) [PLACEHOLDER].
const MIN_VENTS: int = 1
const MAX_VENTS: int = 2
const MIN_ROW_GAP: int = 2
## Vents lie in the trunk's two-wide stretch: these cells of the depth's grid.
const TRUNK := Rect2i(11, 7, 2, 6)
## How near the rover's middle must be to a vent's middle to be in it, and the host's
## slack on top (the reliable command can arrive before the rover's latest position)
## [PLACEHOLDER]. A cell is 3 m wide.
const ENTRY_M: float = 2.1
## What a heat trip multiplies: the metres of driving that wear the rover's own
## instruments (the steering encoder and the tire gauge) [PLACEHOLDER].
const DRIFT_MULTIPLIER: float = 2.0

const WORDS: Dictionary = {
	"hot": "VENT: hot. It cools in %d min. Wait, or go round.",
	"warm": "VENT: cool, but it heats in %d min. Pass now.",
	"cool": "VENT: cool for %d min. Pass now.",
	"struck": "HEAT: the vent's blast reached the pack. The rover's instruments drift ×2 until this trip is over. The lab checks them as found.",
}


# --- Where the vents are ---------------------------------------------------------

## The vents of `zone` at `depth` on `day` for this farm: Array of { "id", "cell"
## (Vector2i of the depth's grid), "phase" (minutes into the cycle at minute 0) }.
## Only the Lava Tubes' depth 1 has any: anything else asks for [].
static func vents_for(world_seed: int, zone: String, depth: int, day: int) -> Array:
	if depth != DEPTH:
		return []  # vents stay on depth 1 [PLACEHOLDER]: depths 2 and 3 have none
	var layout: Dictionary = ZoneDepth.layout(world_seed, zone, depth, day)
	if layout.is_empty():
		return []
	var base: int = ZoneDepth.stream(world_seed, zone, depth, day)
	var grid: PackedStringArray = layout["grid"]
	var kept_clear: Array = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL]
	for find: Variant in layout["finds"]:
		kept_clear.append((find as Dictionary)["cell"])
	var count: int = MIN_VENTS + ZoneDepth.draw(base, 300, MAX_VENTS - MIN_VENTS + 1)
	var out: Array = []
	var cells: Array = []
	for index: int in count:
		var options: Array = []
		for y: int in range(TRUNK.position.y, TRUNK.end.y):
			for x: int in range(TRUNK.position.x, TRUNK.end.x):
				var cell := Vector2i(x, y)
				if grid[y][x] == "." and not cell in kept_clear and _row_gap_ok(cell, cells) \
						and leaves_a_way(grid, cells + [cell]):
					options.append(cell)
		if options.is_empty():
			break
		var chosen: Vector2i = options[ZoneDepth.draw(base, 310 + index, options.size())]
		cells.append(chosen)
		out.append({ "id": vent_id(index), "cell": chosen, "phase": ZoneDepth.draw(base, 320 + index, PERIOD) })
	return out


static func vent_id(index: int) -> String:
	return "v%d" % index


static func _row_gap_ok(cell: Vector2i, others: Array) -> bool:
	for other: Vector2i in others:
		if absi(other.y - cell.y) < MIN_ROW_GAP:
			return false
	return true


## True if every floor cell that is not a vent can be reached from the start without
## crossing a vent: the way round that always exists. (A vent does not block; this is
## the cool way, for a rover that will not pay.)
static func leaves_a_way(grid: PackedStringArray, vent_cells: Array) -> bool:
	var open: PackedStringArray = PackedStringArray()
	for y: int in grid.size():
		var line: String = grid[y]
		for cell: Vector2i in vent_cells:
			if cell.y == y:
				line = line.substr(0, cell.x) + "#" + line.substr(cell.x + 1)
		open.append(line)
	var floor_cells: int = 0
	for line: String in open:
		floor_cells += line.count(".")
	return ZoneDepth.reachable(open, ZoneDepth.START_CELL).size() == floor_cells


## The vent with this id in a day's vents, or {}.
static func vent_in(vents: Array, id: String) -> Dictionary:
	for vent: Variant in vents:
		if vent is Dictionary and str(vent.get("id", "")) == id:
			return vent
	return {}


## The vent in this cell, or {}.
static func vent_at(vents: Array, cell: Vector2i) -> Dictionary:
	for vent: Variant in vents:
		if vent is Dictionary and vent.get("cell") == cell:
			return vent
	return {}


## The cell of the depth's grid a position (the rover's middle) is in.
static func cell_of(place: Vector3) -> Vector2i:
	return Vector2i(roundi(place.x / TunnelRock.CELL_M + (ZoneDepth.WIDTH - 1) * 0.5),
			roundi(place.z / TunnelRock.CELL_M + (ZoneDepth.HEIGHT - 1) * 0.5))


# --- The cycle: a pure function of the clock -------------------------------------

## The whole game minute the clock (days, as GameClock.elapsed_days) is in.
static func minute_of(elapsed_days: float) -> int:
	return floori(elapsed_days * 1440.0 + 0.001)


## Minutes into the vent's cycle: below HOT_MINUTES it is hot.
static func cycle_minute(vent: Dictionary, elapsed_days: float) -> int:
	return posmod(minute_of(elapsed_days) + int(vent.get("phase", 0)), PERIOD)


static func is_hot(vent: Dictionary, elapsed_days: float) -> bool:
	return cycle_minute(vent, elapsed_days) < HOT_MINUTES


## Minutes until the vent changes: until it cools while hot, until it heats while cool
## (at least 1).
static func minutes_left(vent: Dictionary, elapsed_days: float) -> int:
	var at: int = cycle_minute(vent, elapsed_days)
	return HOT_MINUTES - at if at < HOT_MINUTES else PERIOD - at


## How bright the vent glows, 0 to 1: full while hot, half just before it heats, low
## while cool. What the prop shows.
static func glow(vent: Dictionary, elapsed_days: float) -> float:
	if is_hot(vent, elapsed_days):
		return 1.0
	return 0.45 if minutes_left(vent, elapsed_days) <= WARN_MINUTES else 0.08


## The line the phone shows by a vent.
static func hint(vent: Dictionary, elapsed_days: float) -> String:
	var left: int = minutes_left(vent, elapsed_days)
	if is_hot(vent, elapsed_days):
		return WORDS["hot"] % left
	return (WORDS["warm"] if left <= WARN_MINUTES else WORDS["cool"]) % left


# --- The rules the host holds a heat command to ----------------------------------

## Why a player in `place` at `depth`, with the rover at `rover_depth`, can't be struck
## by `vent_id_text` among today's `vents` at the clock `elapsed_days`, or "". The one
## rule for the host's command; nearness is its own check (reach_problem).
static func entry_problem(vent_id_text: String, vents: Array, elapsed_days: float, place: String, depth: int, rover_depth: int) -> String:
	if place != ZONE or depth != DEPTH or rover_depth != DEPTH:
		return "Vents are in the Lava Tubes, one level down."
	var vent: Dictionary = vent_in(vents, vent_id_text)
	if vent.is_empty():
		return "There is no vent '%s' here today." % vent_id_text
	if not is_hot(vent, elapsed_days):
		return "That vent is cool."
	return ""


## Why the rover can't be in a vent's cell, or "". `zone` is GameState.rover_zone,
## `known` whether the host has the tunnel rover's place, `at` that place and `there`
## the vent cell's middle. The host's copy of the rover decides, not the player's word.
static func reach_problem(there: Vector3, zone: String, known: bool, at: Vector3) -> String:
	if zone != ZONE or not known:
		return "The rover is not in the Lava Tubes."
	if Vector2(there.x - at.x, there.z - at.z).length() > ENTRY_M + ZoneDepth.HOST_REACH_SLACK_M:
		return "The rover is not at that vent."
	return ""
