class_name DeimosDepth
extends RefCounted
## Deimos depth 1 ("Deep stores", docs/design/zones.md section 13, slice 24):
## a small grid of store rooms under the Deimos hub, laid out from the integer hash of
## (farm seed, "deimos", 1, day), reseeded at 06:00, always reachable on foot with
## PhobosWalker and Deimos low gravity. Pure rules, layout, crates (locked + mislabelled),
## rewards, dust penalty, and save validation; the 3D scene is DeimosDeep. Every number,
## size, and line of text is a [PLACEHOLDER].

const ZONE: String = Shuttle.DEIMOS
const DEPTH: int = 1
const MAX_DEPTH: int = 1

## Grid dimensions and cell size in metres [PLACEHOLDER].
## 15 x 12 at 3 m fits well inside PhobosWalker.EDGE_M (34 m): max corner is ~26.7 m.
const WIDTH: int = 15
const HEIGHT: int = 12
const CELL_M: float = 3.0
const WALL_HEIGHT_M: float = 3.2
const REACH_M: float = 6.0

## Fixed south-centre hatch room: ladder up, walker start, and dust wipe stop [PLACEHOLDER].
const HATCH_ROOM := Rect2i(5, 8, 5, 3)
const HATCH_CELL := Vector2i(7, 10)
const START_CELL := Vector2i(7, 9)
const WIPE_CELL := Vector2i(5, 9)

## Central trunk and three 4 x 3 store rooms joined by hash-shifted passages [PLACEHOLDER].
const TRUNK := Rect2i(6, 4, 3, 5)
const ROOM_SIZE := Vector2i(4, 3)
const ROOM_SLOTS: Array[Vector2i] = [
	Vector2i(1, 3),
	Vector2i(5, 1),
	Vector2i(10, 3),
]

## Hand-made 4 x 3 store-bay pieces: '#' bulkhead wall, '.' floor [PLACEHOLDER].
## Every floor cell is 4-connected to the room perimeter regardless of horizontal flip.
const PIECES: Array = [
	["....", ".#..", "...."],
	["....", "..#.", "...."],
	["#...", "....", "...#"],
	["...#", "....", "#..."],
]

## Daily crates: 2 to 4 per day, lost standards and station stock (credits) [PLACEHOLDER].
const MIN_CRATES: int = 2
const MAX_CRATES: int = 4
const KINDS: Array[String] = ["lost_standard", "lost_standard", "station_stock", "station_stock", "station_stock"]
const REWARDS: Dictionary = {
	"lost_standard": { "credits": 32 },
	"station_stock": { "credits": 24 },
}
const NAMES: Dictionary = {
	"lost_standard": "lost standard",
	"station_stock": "station stock",
}
## Locked crates carry an extra payout when opened with Kestrel's proof [PLACEHOLDER].
const LOCKED_BONUS_CREDITS: int = 12
## Wrong labels: on 1 day in MISLABEL_MOD, one crate is mislabelled and pays MISLABELED_PAY_PCT %
## of its labelled value, revealed only once opened [PLACEHOLDER].
const MISLABEL_MOD: int = 2
const MISLABELED_PAY_PCT: int = 50

## Dust hazard: "as Phobos, slower" — 15 % less crate pay until wiped [PLACEHOLDER].
const DUST_CUT_PCT: int = 15

## UI & HUD lines [PLACEHOLDER].
const TITLE_TEXT: String = "DEIMOS // DEEP STORES"
const HUB_HATCH_HINT: String = "Hatch down to Deimos deep stores"
const HATCH_UP_HINT: String = "Hatch up to Deimos hub"
const WIPE_HINT: String = "Wipe stop: clear Deimos dust from lens and encoder"
const DUSTY_START_TEXT: String = "Dusty: fine Deimos dust on optics (15 % less crate pay). Use the wipe stop by the hatch."
const DUSTY_WIPED_TEXT: String = "Dusty optics wiped. Full crate pay restored."
const ALREADY_WIPED_TEXT: String = "Optics already wiped clean."
const LOCKED_REFUSAL_TEXT: String = "Locked crate. Needs Kestrel's proof."
const AMBIENT_HINT: String = "Deep stores. Click a crate to open, the wipe stop to clear dust, or the hatch to climb up."
const TOO_FAR_TEXT: String = "Move closer."


# --- Layout ---------------------------------------------------------------------

## Depth 1 layout for `world_seed` on `day`:
## { "depth", "day", "grid" (PackedStringArray, WIDTH x HEIGHT), "start", "hatch", "wipe",
##   "rooms" (Array[Rect2i]), "crates" (Array of { "id", "kind", "cell", "locked", "mislabeled" }) }.
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

	# Hash-shifted passages joining the three store rooms to the central trunk.
	var west_y: int = 3 + ZoneDepth.draw(base, 30, 2)
	var east_y: int = 3 + ZoneDepth.draw(base, 31, 2)
	var north_x: int = 6 + ZoneDepth.draw(base, 32, 2)
	_carve(cells, Rect2i(4, west_y, 3, 2))
	_carve(cells, Rect2i(8, east_y, 3, 2))
	_carve(cells, Rect2i(north_x, 3, 2, 2))

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
		"crates": _crates(base, grid, rooms),
	}


static func _put(cells: Array, cell: Vector2i, tile: String) -> void:
	if cell.y >= 0 and cell.y < HEIGHT and cell.x >= 0 and cell.x < WIDTH:
		cells[cell.y][cell.x] = tile


static func _carve(cells: Array, area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			_put(cells, Vector2i(x, y), ".")


## 2 to 4 crates placed deterministically across the three store rooms (never on the
## start, hatch, or wipe cells, and never two on one cell). Every day has at least one
## locked crate and at least one unlocked crate; on 1 day in MISLABEL_MOD one crate is
## mislabelled.
static func _crates(base: int, grid: PackedStringArray, rooms: Array[Rect2i]) -> Array:
	var count: int = MIN_CRATES + ZoneDepth.draw(base, 90, MAX_CRATES - MIN_CRATES + 1)
	var used: Array[Vector2i] = [START_CELL, HATCH_CELL, WIPE_CELL]
	var crates: Array = []
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
		crates.append({
			"id": crate_id(index),
			"kind": kind,
			"cell": cell,
			"locked": false,
			"mislabeled": false,
		})
	if crates.is_empty():
		return crates
	var locked_first: int = ZoneDepth.draw(base, 300, crates.size())
	crates[locked_first]["locked"] = true
	if crates.size() >= 3 and ZoneDepth.draw(base, 301, 2) == 1:
		var locked_second: int = (locked_first + 1 + ZoneDepth.draw(base, 302, crates.size() - 1)) % crates.size()
		crates[locked_second]["locked"] = true
	if ZoneDepth.draw(base, 400, MISLABEL_MOD) == 0:
		var wrong_idx: int = ZoneDepth.draw(base, 401, crates.size())
		crates[wrong_idx]["mislabeled"] = true
	return crates


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) - float(WIDTH - 1) * 0.5) * CELL_M,
		0.0,
		(float(cell.y) - float(HEIGHT - 1) * 0.5) * CELL_M
	)


static func crate_id(index: int) -> String:
	return "d%d_c%d" % [DEPTH, index]


static func crate_in(layout_data: Dictionary, crate_id_text: String) -> Dictionary:
	for crate: Variant in layout_data.get("crates", []):
		if crate is Dictionary and str(crate.get("id", "")) == crate_id_text:
			return crate
	return {}


static func is_valid_crate_id(text: String) -> bool:
	for index: int in MAX_CRATES:
		if text == crate_id(index):
			return true
	return false


# --- Rewards, wrong labels & dust -----------------------------------------------

## Integer credit payout after optional dust penalty (15 % cut while dusty, floor 1).
static func apply_dust(credits: int, dusty: bool) -> int:
	if not dusty or credits <= 0:
		return credits
	return maxi(credits - int(credits * DUST_CUT_PCT / 100), 1)


static func base_credits(kind: String, locked: bool = false) -> int:
	var pay: int = int((REWARDS.get(kind, {}) as Dictionary).get("credits", 0))
	if pay <= 0:
		return 0
	return pay + (LOCKED_BONUS_CREDITS if locked else 0)


static func reward_credits(kind: String, locked: bool = false, mislabeled: bool = false, dusty: bool = false) -> int:
	var pay: int = base_credits(kind, locked)
	if pay <= 0:
		return 0
	if mislabeled:
		pay = maxi(int(pay * MISLABELED_PAY_PCT / 100), 1)
	return apply_dust(pay, dusty)


static func crate_hint(kind: String, locked: bool) -> String:
	var label: String = str(NAMES.get(kind, kind))
	if locked:
		return "Open locked crate (%s)" % label
	return "Open crate (%s)" % label


static func reward_text(kind: String, locked: bool = false, mislabeled: bool = false, dusty: bool = false) -> String:
	var pay: int = reward_credits(kind, locked, mislabeled, dusty)
	var label: String = str(NAMES.get(kind, kind))
	if mislabeled and dusty:
		return "Wrong label! Crate held scrap instead of %s: %d credits (dusty, %d %% cut)." % [label, pay, DUST_CUT_PCT]
	if mislabeled:
		return "Wrong label! Crate held scrap instead of %s: %d credits." % [label, pay]
	if dusty:
		return "Opened %s: %d credits (dusty, %d %% cut)." % [label, pay, DUST_CUT_PCT]
	return "Opened %s: %d credits." % [label, pay]


# --- Opened crates, pruned to today ---------------------------------------------

static func prune(opened: Dictionary, day: int) -> Dictionary:
	if opened.is_empty() or int(opened.get("day", -1)) != day or not opened.get("ids") is Array:
		return {}
	return opened.duplicate(true)


static func opened_today(opened: Dictionary, day: int) -> Array[String]:
	var clean: Dictionary = prune(opened, day)
	var out: Array[String] = []
	for entry: Variant in clean.get("ids", []):
		if entry is String:
			out.append(entry)
	return out


static func with_opened(opened: Dictionary, day: int, crate_id_text: String) -> Dictionary:
	var ids: Array[String] = opened_today(opened, day)
	if not crate_id_text in ids:
		ids.append(crate_id_text)
	return { "day": day, "ids": ids }


## Why a saved `deimos_crates_opened` cannot load, or "". Shape only: past days drop on load.
static func opened_problem(opened: Variant) -> String:
	if not opened is Dictionary:
		return "'deimos_crates_opened' must be a dictionary."
	var dict: Dictionary = opened as Dictionary
	if dict.is_empty():
		return ""
	var day: Variant = dict.get("day")
	var ids: Variant = dict.get("ids")
	if dict.size() != 2 or not day is int or day < 0 or not ids is Array:
		return "'deimos_crates_opened' is not a day and its opened crates."
	var seen: Array[String] = []
	for id: Variant in ids:
		if not id is String or not is_valid_crate_id(id) or id in seen:
			return "'deimos_crates_opened' holds a crate id that is not valid or is repeated."
		seen.append(id)
	return ""
