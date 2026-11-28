class_name PhobosDepth
extends RefCounted
## Phobos depth 1 ("Station deck 1", docs/design/zones.md section 13, slice 23):
## a small grid of rooms beneath the Phobos service tunnel, laid out from the integer
## hash of (farm seed, "phobos", 1, day), reseeded at 06:00, always reachable on foot
## with PhobosWalker and low gravity. Pure rules, layout, rewards, dust penalty, and
## save validation; the 3D scene is PhobosDeep. Every number, size, and line of text
## is a [PLACEHOLDER].

const ZONE: String = Shuttle.PHOBOS
const DEPTH: int = 1
const MAX_DEPTH: int = 1

## Grid dimensions and cell size in metres [PLACEHOLDER].
## 15 x 13 at 3 m fits well inside PhobosWalker.EDGE_M (34 m): max corner is ~27.6 m.
const WIDTH: int = 15
const HEIGHT: int = 13
const CELL_M: float = 3.0
const WALL_HEIGHT_M: float = 3.6
const REACH_M: float = 6.0

## Fixed south-centre hatch room: ladder up, walker start, and the dust wipe stop [PLACEHOLDER].
const HATCH_ROOM := Rect2i(5, 8, 5, 4)
const HATCH_CELL := Vector2i(7, 10)
const START_CELL := Vector2i(7, 9)
const WIPE_CELL := Vector2i(5, 9)

## Central trunk and three 4 x 4 station rooms joined by hash-shifted passages [PLACEHOLDER].
const TRUNK := Rect2i(6, 5, 3, 4)
const ROOM_SIZE := Vector2i(4, 4)
const ROOM_SLOTS: Array[Vector2i] = [
	Vector2i(1, 3),
	Vector2i(6, 1),
	Vector2i(10, 3),
]

## Hand-made 4 x 4 room pieces: '#' bulkhead wall, '.' floor [PLACEHOLDER].
## Every floor cell is connected to all four edges regardless of horizontal flip.
const PIECES: Array = [
	["....", ".#..", "....", "...."],
	["#...", "....", "....", "...#"],
	["....", "....", "..#.", "...."],
	["....", ".##.", "....", "...."],
]

## Daily finds: 3 to 5 per day, station data and robot parts (credits) [PLACEHOLDER].
const MIN_FINDS: int = 3
const MAX_FINDS: int = 5
const KINDS: Array[String] = ["station_data", "station_data", "station_data", "robot_parts", "robot_parts"]
const REWARDS: Dictionary = {
	"station_data": { "credits": 24 },
	"robot_parts": { "credits": 32 },
}
const NAMES: Dictionary = {
	"station_data": "station data",
	"robot_parts": "robot parts",
}

## Dust hazard: each trip down clogs optics and cuts find pay by 25 % until wiped [PLACEHOLDER].
const DUST_CUT_PCT: int = 25

## UI & HUD lines [PLACEHOLDER].
const TITLE_TEXT: String = "PHOBOS // STATION DECK 1"
const DUSTY_START_TEXT: String = "Dusty: lens and encoder clogged (25 % less find pay). Use the wipe stop by the hatch."
const DUSTY_WIPED_TEXT: String = "Dusty optics wiped. Full find pay restored."
const ALREADY_WIPED_TEXT: String = "Optics already wiped clean."
const WIPE_HINT: String = "Wipe stop: clear Phobos dust from lens and encoder"
const HATCH_UP_HINT: String = "Hatch up to Phobos service tunnel"
const AMBIENT_HINT: String = "Station deck 1. Click a find to collect, the wipe stop to clear dust, or the hatch to climb up."
const TOO_FAR_TEXT: String = "Move closer."


# --- Layout ---------------------------------------------------------------------

## Depth 1 layout for `world_seed` on `day`:
## { "depth", "day", "grid" (PackedStringArray, WIDTH x HEIGHT), "start", "hatch", "wipe",
##   "rooms" (Array[Rect2i]), "finds" (Array of { "id", "kind", "cell" }) }.
## Pure integer hash (ZoneDepth.stream / ZoneDepth.draw), never Godot RNG.
static func layout(world_seed: int, day: int) -> Dictionary:
	var base: int = ZoneDepth.stream(world_seed, ZONE, DEPTH, day)
	var cells: Array = []
	for y: int in HEIGHT:
		var row: Array = []
		row.resize(WIDTH)
		row.fill("#")
		cells.append(row)

	var rooms: Array[Rect2i] = []
	for slot: int in ROOM_SLOTS.size():
		var piece: Array = PIECES[ZoneDepth.draw(base, 10 + slot, PIECES.size())]
		var flipped: bool = ZoneDepth.draw(base, 20 + slot, 2) == 1
		var room := Rect2i(ROOM_SLOTS[slot], ROOM_SIZE)
		rooms.append(room)
		for y: int in ROOM_SIZE.y:
			var line: String = piece[y]
			for x: int in ROOM_SIZE.x:
				var at_x: int = ROOM_SIZE.x - 1 - x if flipped else x
				_put(cells, room.position + Vector2i(x, y), line[at_x])

	_carve(cells, HATCH_ROOM)
	_carve(cells, TRUNK)

	# Hash-shifted passages joining the west and east rooms to the central trunk.
	var west_y: int = 3 + ZoneDepth.draw(base, 30, 3)
	var east_y: int = 3 + ZoneDepth.draw(base, 31, 3)
	_carve(cells, Rect2i(4, west_y, 3, 2))
	_carve(cells, Rect2i(8, east_y, 3, 2))

	_put(cells, HATCH_CELL, ".")
	_put(cells, START_CELL, ".")
	_put(cells, WIPE_CELL, ".")

	var grid := PackedStringArray()
	for row: Array in cells:
		grid.append("".join(row))

	return {
		"depth": DEPTH,
		"day": day,
		"grid": grid,
		"start": START_CELL,
		"hatch": HATCH_CELL,
		"wipe": WIPE_CELL,
		"rooms": rooms,
		"finds": _finds(base, grid, rooms),
	}


static func _put(cells: Array, cell: Vector2i, tile: String) -> void:
	if cell.y >= 0 and cell.y < HEIGHT and cell.x >= 0 and cell.x < WIDTH:
		cells[cell.y][cell.x] = tile


static func _carve(cells: Array, area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			_put(cells, Vector2i(x, y), ".")


## 3 to 5 finds placed deterministically across the three station rooms (never on the
## start, hatch, or wipe cells, and never two on one cell).
static func _finds(base: int, grid: PackedStringArray, rooms: Array[Rect2i]) -> Array:
	var count: int = MIN_FINDS + ZoneDepth.draw(base, 90, MAX_FINDS - MIN_FINDS + 1)
	var used: Array[Vector2i] = [START_CELL, HATCH_CELL, WIPE_CELL]
	var finds: Array = []
	for index: int in count:
		var room_idx: int = (index + ZoneDepth.draw(base, 95, rooms.size())) % rooms.size()
		var options: Array[Vector2i] = ZoneDepth.floor_cells(grid, rooms[room_idx])
		var free: Array[Vector2i] = []
		for option: Vector2i in options:
			if not option in used:
				free.append(option)
		if free.is_empty():
			continue
		var cell: Vector2i = free[ZoneDepth.draw(base, 100 + index, free.size())]
		used.append(cell)
		var kind: String = KINDS[ZoneDepth.draw(base, 200 + index, KINDS.size())]
		finds.append({ "id": find_id(index), "kind": kind, "cell": cell })
	return finds


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) - float(WIDTH - 1) * 0.5) * CELL_M,
		0.0,
		(float(cell.y) - float(HEIGHT - 1) * 0.5) * CELL_M
	)


static func find_id(index: int) -> String:
	return "d%d_f%d" % [DEPTH, index]


static func find_in(layout_data: Dictionary, find_id_text: String) -> Dictionary:
	for find: Variant in layout_data.get("finds", []):
		if find is Dictionary and str(find.get("id", "")) == find_id_text:
			return find
	return {}


static func is_valid_find_id(text: String) -> bool:
	for index: int in MAX_FINDS:
		if text == find_id(index):
			return true
	return false


# --- Rewards & dust -------------------------------------------------------------

## Integer credit payout after optional dust penalty (25 % cut while dusty, floor 1).
static func apply_dust(credits: int, dusty: bool) -> int:
	if not dusty or credits <= 0:
		return credits
	return maxi(credits - int(credits * DUST_CUT_PCT / 100), 1)


static func reward_credits(kind: String, dusty: bool = false) -> int:
	var base: int = int((REWARDS.get(kind, {}) as Dictionary).get("credits", 0))
	return apply_dust(base, dusty)


static func reward_text(kind: String, dusty: bool = false) -> String:
	var pay: int = reward_credits(kind, dusty)
	var label: String = str(NAMES.get(kind, kind))
	if dusty:
		return "Took %s: %d credits (dusty, %d %% cut)." % [label, pay, DUST_CUT_PCT]
	return "Took %s: %d credits." % [label, pay]


# --- Taken finds, pruned to today -----------------------------------------------

static func prune(taken: Dictionary, day: int) -> Dictionary:
	if taken.is_empty() or int(taken.get("day", -1)) != day or not taken.get("ids") is Array:
		return {}
	return taken.duplicate(true)


static func taken_today(taken: Dictionary, day: int) -> Array[String]:
	var clean: Dictionary = prune(taken, day)
	var out: Array[String] = []
	for entry: Variant in clean.get("ids", []):
		if entry is String:
			out.append(entry)
	return out


static func with_taken(taken: Dictionary, day: int, find_id_text: String) -> Dictionary:
	var ids: Array[String] = taken_today(taken, day)
	if not find_id_text in ids:
		ids.append(find_id_text)
	return { "day": day, "ids": ids }


## Why a saved `phobos_finds_taken` cannot load, or "". Shape only: past days drop on load.
static func taken_problem(taken: Variant) -> String:
	if not taken is Dictionary:
		return "'phobos_finds_taken' must be a dictionary."
	var dict: Dictionary = taken as Dictionary
	if dict.is_empty():
		return ""
	var day: Variant = dict.get("day")
	var ids: Variant = dict.get("ids")
	if dict.size() != 2 or not day is int or day < 0 or not ids is Array:
		return "'phobos_finds_taken' is not a day and its taken finds."
	var seen: Array[String] = []
	for id: Variant in ids:
		if not id is String or not is_valid_find_id(id) or id in seen:
			return "'phobos_finds_taken' holds a find id that is not valid or is repeated."
		seen.append(id)
	return ""
