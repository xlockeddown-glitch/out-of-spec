class_name IceSlick
extends RefCounted
## The Ice Caves' slick ice and white-out (docs/design/zones.md, hazard table; step 15 left
## them out). Pure rules and words, no nodes: the scene draws, GameState holds the studs and
## the wear. Every number below is a [PLACEHOLDER].
##
## Slick ice: some depth-1 floor cells are slick, picked from the same integer hash as the
## layout (ZoneDepth.stream, tags 400 and up). Never on the way up, the start, a find or any
## cell touching one of those. A rover driving onto a slick cell slides one more cell the way
## it was going, if that cell is open (floor, not a find, not the start or the way up). The
## target is a pure function of the grid, so host and guests agree on it; the host adds the
## wear. Ice studs (Bram, credits) stop the skid altogether.
##
## White-out: on about one day in three a spell comes down in the caves, for 60 to 120 game
## minutes, between 08:00 and 18:00. A pure function of the world seed and the shared clock,
## so every PC agrees without being told. Fog is the scene's; finds beyond SEE_FINDS_M are
## not drawn. The hatch, the entry, the way up and every other prop are never hidden, and
## the recall (02:00) is far outside any spell.

## Tags of the hash questions (the layout uses 30, 31, 100+ and 200+).
const TAG_SLICK: int = 400
const TAG_SPELL_DAY: int = 500
const TAG_SPELL_START: int = 501
const TAG_SPELL_LENGTH: int = 502
## About one floor cell in this many is slick [PLACEHOLDER].
const SLICK_ONE_IN: int = 7
## A skid wears the steering encoder and tire gauge as this many metres driven [PLACEHOLDER].
const SKID_WEAR_M: float = 6.0
## Ice studs cost this many credits at Bram's bay [PLACEHOLDER].
const STUD_COST_CREDITS: int = 60
## A client's word for where it skidded is held to this slack around the cell middle (metres).
const SKID_REACH_M: float = 2.1
## One day in this many has a white-out [PLACEHOLDER].
const SPELL_ONE_IN: int = 3
## A spell starts this many minutes after 06:00 at the earliest, and at most SPELL_START_SPREAD more.
const SPELL_START_MIN: int = 120
const SPELL_START_SPREAD: int = 481
const SPELL_LENGTH_MIN: int = 60
const SPELL_LENGTH_SPREAD: int = 61
## Finds farther than this from the rover are not shown in a white-out, in metres [PLACEHOLDER].
const SEE_FINDS_M: float = 9.0
## The fog's density in a white-out [PLACEHOLDER].
const FOG_DENSITY: float = 0.06
const STUDS_PRICE_TEXT: String = "Ice studs"

const WORDS: Dictionary = {
	"in": "A white-out is coming down. Finds are hard to see; the hatch and the way out are not.",
	"out": "The white-out has lifted.",
	"skid": "The rover skids on the ice.",
	"studs": "BRAM: Studs are on. The rover grips the ice now.",
}


# --- Slick cells ----------------------------------------------------------------

## Cells a slick patch may not sit on or touch: the start, the way up (and the hub's hatch),
## and every find.
static func protected_cells(layout: Dictionary) -> Array[Vector2i]:
	var keep: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL, IceDepth.HATCH_CELL]
	var start: Variant = layout.get("start", null)
	if start is Vector2i:
		keep.append(start as Vector2i)
	for find: Variant in layout.get("finds", []):
		if find is Dictionary:
			keep.append(find["cell"] as Vector2i)
	return keep


## True if `cell` is one of `keep` or touches one (eight ways).
static func touches(keep: Array[Vector2i], cell: Vector2i) -> bool:
	for held: Vector2i in keep:
		if absi(held.x - cell.x) <= 1 and absi(held.y - cell.y) <= 1:
			return true
	return false


## Today's slick cells at `depth` (only the Ice Caves' depth 1 has any), in reading order.
## Picked from the layout's own hash, so the same seed and day always give the same cells.
static func slick_cells(world_seed: int, depth: int, day: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if depth != ZoneDepth.DEPTH:
		return out
	var today: Dictionary = IceDepth.layout(world_seed, depth, day)
	if today.is_empty():
		return out
	var grid: PackedStringArray = today["grid"]
	var keep: Array[Vector2i] = protected_cells(today)
	var base: int = ZoneDepth.stream(world_seed, IceDepth.ZONE, depth, day)
	for y: int in grid.size():
		for x: int in grid[y].length():
			var cell := Vector2i(x, y)
			if grid[y][x] != "." or touches(keep, cell):
				continue
			if ZoneDepth.draw(base, TAG_SLICK + y * ZoneDepth.WIDTH + x, SLICK_ONE_IN) == 0:
				out.append(cell)
	return out


static func is_slick(slick: Array[Vector2i], cell: Vector2i) -> bool:
	return cell in slick


# --- The skid -------------------------------------------------------------------

## The unit step (one of the four sides) from `from` to `to`, or (0, 0) when they are not
## next to each other or are the same.
static func step_between(from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Vector2i = to - from
	if absi(d.x) + absi(d.y) != 1:
		return Vector2i.ZERO
	return d


## True if `dir` is one of the four unit steps.
static func is_side(dir: Vector2i) -> bool:
	return absi(dir.x) + absi(dir.y) == 1


## The cell a rover that rolled onto `cell` going `dir` ends on: one more cell on if it is
## open, else where it is. Never rock, off the map, a find, the start or the way up.
static func skid_target(grid: PackedStringArray, find_cells: Array, cell: Vector2i, dir: Vector2i) -> Vector2i:
	if not is_side(dir):
		return cell
	var next: Vector2i = cell + dir
	if next.y < 0 or next.y >= grid.size() or next.x < 0 or next.x >= grid[next.y].length():
		return cell
	if grid[next.y][next.x] != ".":
		return cell
	if next in find_cells or next == ZoneDepth.START_CELL or next == ZoneDepth.UP_CELL or next == IceDepth.HATCH_CELL:
		return cell
	return next


## Why a skid at `cell` going `dir` can't be taken as asked, or "". `studs` whether the
## farm's rover has them. The host's rule; nearness is its own check (reach_problem).
static func skid_problem(slick: Array[Vector2i], cell: Vector2i, dir: Vector2i, studs: bool, place: String, depth: int, rover_zone: String, rover_depth: int) -> String:
	if place != IceDepth.ZONE or depth != ZoneDepth.DEPTH or rover_zone != IceDepth.ZONE or rover_depth != ZoneDepth.DEPTH:
		return "Slick ice is in the Ice Caves, one level down."
	if not is_side(dir):
		return "The rover can only skid straight on."
	if not is_slick(slick, cell):
		return "That ice is not slick today."
	if studs:
		return "The studs hold."
	return ""


## Why the rover is not at a slick cell, or "": the host's copy of the rover decides.
static func reach_problem(there: Vector3, known: bool, at: Vector3) -> String:
	if not known:
		return "The rover is not in the Ice Caves."
	if Vector2(there.x - at.x, there.z - at.z).length() > SKID_REACH_M:
		return "The rover is not at that ice."
	return ""


## Why the studs can't be bought now, or "". Bram sells them to the farm once.
static func studs_problem(has: bool, credits: int) -> String:
	if has:
		return "The rover already has studs."
	if credits < STUD_COST_CREDITS:
		return "Studs cost %d credits; the farm has %d." % [STUD_COST_CREDITS, credits]
	return ""


## Bram's offer line for the bay.
static func studs_offer_text() -> String:
	return "%s: %d credits" % [STUDS_PRICE_TEXT, STUD_COST_CREDITS]


# --- The white-out --------------------------------------------------------------

## The day's spell as { "start", "end" } in minutes after 06:00, or {} when the day has none.
static func spell_of(world_seed: int, day: int) -> Dictionary:
	var base: int = ZoneDepth.stream(world_seed, IceDepth.ZONE, 0, day)
	if ZoneDepth.draw(base, TAG_SPELL_DAY, SPELL_ONE_IN) != 0:
		return {}
	var start: int = SPELL_START_MIN + ZoneDepth.draw(base, TAG_SPELL_START, SPELL_START_SPREAD)
	var length: int = SPELL_LENGTH_MIN + ZoneDepth.draw(base, TAG_SPELL_LENGTH, SPELL_LENGTH_SPREAD)
	return { "start": start, "end": start + length }


## True if a white-out is down at the clock `elapsed_days` (GameClock.elapsed_days).
static func whiteout_active(world_seed: int, elapsed_days: float) -> bool:
	var minute: int = ZoneHazards.minute_of(elapsed_days)
	var day: int = floori(float(minute) / 1440.0) + 1
	var spell: Dictionary = spell_of(world_seed, day)
	if spell.is_empty():
		return false
	var into: int = minute - (day - 1) * 1440
	return into >= int(spell["start"]) and into < int(spell["end"])


## The clock time (06:00 plus `minutes`) as text, for the log line.
static func clock_text(minutes: int) -> String:
	var at: int = posmod(int(GameClock.DAY_START_HOUR * 60.0) + minutes, 1440)
	return "%02d:%02d" % [floori(at / 60.0), at % 60]


## Whether a prop of `kind` ("find" or anything else) is drawn `distance` metres from the
## rover in a white-out. Only finds fade; the hatch, the entry and the rest never do.
static func shown_in_whiteout(is_find: bool, distance: float) -> bool:
	return not is_find or distance <= SEE_FINDS_M
