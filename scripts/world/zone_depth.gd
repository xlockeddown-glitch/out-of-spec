class_name ZoneDepth
extends RefCounted
## The depth generator (docs/design/zones.md section 13, build steps 6 and 9):
## depths 1 to 3 of the Lava Tubes, each laid out from the integer hash of (farm seed, zone,
## depth, day), so the same day always gives the same tunnels and a new day gives
## new ones. A few hand-made room pieces are chosen and joined by the hash (section
## 3.2), and a handful of finds (ore, minerals, samples) lie in them. Pure rules and
## words; the props are in ZoneDepthProps and the taken finds are GameState's
## (`finds_taken`, saved). Only integer maths is used, never Godot's random numbers,
## so every machine draws the same layout. Every number and name here is a
## [PLACEHOLDER].

## The zone this depth belongs to (data/zones.json).
const ZONE: String = "lava_tubes"
## The first depth below the hub (the one step 6 built).
const DEPTH: int = 1
## The deepest this generator makes [PLACEHOLDER], and how often a lift station comes
## (every third depth: the one at MAX_DEPTH is the lift to the hub).
const MAX_DEPTH: int = 3
const LIFT_EVERY: int = 3
const WIDTH: int = 24
const HEIGHT: int = 22
## The hub cell the way down is in, and the cell the rover starts at below.
## Both are floor. The hub's cells are TunnelRock.MAP's, the depth's the layout's.
const DESCENT_CELL := Vector2i(8, 16)
const START_CELL := Vector2i(11, 18)
## The way down of depths 1 and 2 (a hatch in the two-wide strip above the landing, a
## cell no find or vent is ever in), and the lift stations: the hub's, and depth 3's
## by its entrance. Floor in the hub's MAP and in every layout.
const HATCH_CELL := Vector2i(11, 13)
const HUB_LIFT_CELL := Vector2i(11, 16)
const LIFT_CELL := Vector2i(9, 16)
## The cell of the way up (the exit pad of the tunnels scene).
const UP_CELL := Vector2i(11, 20)
## How near the rover must be to the way down or a find [PLACEHOLDER]. A cell is
## 3 m wide.
const REACH_M: float = 4.0
## Extra metres the host allows on top of REACH_M [PLACEHOLDER]: the reliable take
## command can arrive before the guest's latest (unreliable) rover position does.
const HOST_REACH_SLACK_M: float = 1.5
## The rooms' places (top left cell) and size, and the landing by the way in.
const ROOM_SIZE := Vector2i(7, 5)
const ROOM_SLOTS: Array[Vector2i] = [Vector2i(2, 8), Vector2i(15, 8), Vector2i(8, 1)]
const LANDING := Rect2i(8, 15, 7, 4)
## Where each depth puts its rooms, what it always carves, and the passages whose place
## the hash picks (all [PLACEHOLDER]). A passage is [draw tag, x, y, width, height,
## step x, step y, how many places]: the hash moves it that many steps. Depth 1 is the
## original layout, kept exactly; depths 2 and 3 move the rooms and the trunk about.
const PLANS: Dictionary = {
	1: {
		"slots": [Vector2i(2, 8), Vector2i(15, 8), Vector2i(8, 1)],
		"carves": [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 6, 2, 8)],
		"passages": [[30, 8, 9, 5, 2, 0, 1, 2], [31, 11, 9, 5, 2, 0, 1, 2]],
	},
	2: {
		"slots": [Vector2i(1, 12), Vector2i(16, 13), Vector2i(14, 2)],
		"carves": [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 4, 2, 10)],
		"passages": [[30, 4, 13, 7, 2, 0, 1, 3], [31, 12, 13, 7, 2, 0, 1, 3], [32, 11, 3, 5, 2, 0, 1, 2]],
	},
	3: {
		"slots": [Vector2i(1, 5), Vector2i(16, 5), Vector2i(16, 14)],
		"carves": [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 4, 2, 10)],
		"passages": [[30, 4, 6, 8, 2, 0, 1, 3], [31, 12, 6, 7, 2, 0, 1, 3], [32, 13, 15, 5, 2, 0, 1, 3]],
	},
}
## The hand-made room pieces: # rock, . floor. Each is ROOM_SIZE; the hash picks one
## for each slot and whether it is turned about.
const PIECES: Array = [
	["#.....#", ".......", "..#....", ".......", "#.....#"],
	["..#.#..", ".......", ".##.#..", ".......", "..#...."],
	[".......", ".#####.", ".......", ".#.#.#.", "......."],
	["#.....#", "#.###.#", ".......", "#.###.#", "#....##"],
]
## What a find is, by kind, and what it pays into the shared stock [PLACEHOLDER].
const KINDS: Array[String] = ["ore", "ore", "ore", "ore", "mineral", "mineral", "sample"]
const REWARDS: Dictionary = {
	"ore": { "crystal_ore": 2 },
	"mineral": { "credits": 12 },
	"sample": { "crystal_ore": 1, "credits": 4 },
}
const NAMES: Dictionary = { "ore": "crystal ore", "mineral": "a mineral", "sample": "a rock sample" }
## What repairing a broken lift costs, from the farm's shared wallet and stock
## [PLACEHOLDER]. Taken once: the repair is for good.
const LIFT_COST_CREDITS: int = 100
const LIFT_COST_ORE: int = 2
## Finds in each room, and on the landing.
const PER_ROOM: int = 2
const ON_LANDING: int = 1

## The depth the one shared rover is at, and its layout, as this screen builds the
## tunnels. Not saved and not sent: GameState.rover_depth is the truth (saved, and
## sent to guests), and the tunnels scene copies it when it is built (follow).
## Every screen in the tunnels shows the rover's depth.
static var local_depth: int = 0
static var local_layout: Dictionary = {}
## Where the rover starts in the scene built after the rover changed depth.
static var arrive_at: Transform3D = Transform3D.IDENTITY
static var arrive_pending: bool = false


# --- The hash -------------------------------------------------------------------

## One integer into the running hash. 32 bits, so every step stays far inside the
## 64 an integer holds, the same on every machine.
static func mix(h: int, value: int) -> int:
	h = (h ^ (value & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = (h * 0x45D9F3B) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	h = (h * 0x45D9F3B) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFFFF


## A whole integer (a seed may be bigger than 32 bits, or negative) into the hash.
static func fold(h: int, value: int) -> int:
	return mix(mix(h, value & 0xFFFFFFFF), (value >> 32) & 0xFFFFFFFF)


## The hash of a depth on a day: the one number the whole layout comes from.
static func stream(world_seed: int, zone: String, depth: int, day: int) -> int:
	var h: int = fold(0x1F123BB5, world_seed)
	for byte: int in zone.to_utf8_buffer():
		h = mix(h, byte)
	return fold(fold(h, depth), day)


## A number in 0 to `count` - 1 for the question `tag` of this stream.
static func draw(base: int, tag: int, count: int) -> int:
	return mix(base, tag) % maxi(count, 1)


# --- The layout -----------------------------------------------------------------

## Depth `depth` of `zone` on `day` for this farm: { "depth", "day", "grid"
## (PackedStringArray, 24 by 22, # rock . floor, laid out like TunnelRock.MAP),
## "start" (a cell), "rooms" (Array of Rect2i), "finds" (Array of { "id", "kind",
## "cell" }) }. Only the Lava Tubes' depths 1 to MAX_DEPTH exist: any other asks for {}.
static func layout(world_seed: int, zone: String, depth: int, day: int) -> Dictionary:
	if zone != ZONE or depth < DEPTH or depth > MAX_DEPTH:
		return {}
	var plan: Dictionary = PLANS[depth]
	var base: int = stream(world_seed, zone, depth, day)
	var cells: Array = []
	for y: int in HEIGHT:
		var row: Array = []
		row.resize(WIDTH)
		row.fill("#")
		cells.append(row)
	var rooms: Array[Rect2i] = []
	var slots: Array = plan["slots"]
	for slot: int in slots.size():
		var piece: Array = PIECES[draw(base, 10 + slot, PIECES.size())]
		var turned: bool = draw(base, 20 + slot, 2) == 1
		var room := Rect2i(slots[slot], ROOM_SIZE)
		rooms.append(room)
		for y: int in ROOM_SIZE.y:
			var line: String = piece[y]
			for x: int in ROOM_SIZE.x:
				var at_x: int = ROOM_SIZE.x - 1 - x if turned else x
				_put(cells, room.position + Vector2i(x, y), line[at_x])
	# The landing, the way in below it, then a trunk up between the rooms.
	for area: Rect2i in plan["carves"]:
		_carve(cells, area)
	# The rooms are joined to the trunk by passages whose place the hash picks.
	for passage: Array in plan["passages"]:
		var step: int = draw(base, int(passage[0]), int(passage[7]))
		_carve(cells, Rect2i(int(passage[1]) + int(passage[5]) * step, int(passage[2]) + int(passage[6]) * step, int(passage[3]), int(passage[4])))
	var grid := PackedStringArray()
	for row: Array in cells:
		grid.append("".join(row))
	var out: Dictionary = { "depth": depth, "day": day, "grid": grid, "start": START_CELL, "rooms": rooms, "finds": [] }
	out["finds"] = _finds(base, grid, rooms, depth)
	return out


static func _put(cells: Array, cell: Vector2i, tile: String) -> void:
	if cell.y >= 0 and cell.y < HEIGHT and cell.x >= 0 and cell.x < WIDTH:
		cells[cell.y][cell.x] = tile


static func _carve(cells: Array, area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			_put(cells, Vector2i(x, y), ".")


static func _floor_cells(grid: PackedStringArray, area: Rect2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if grid[y][x] == ".":
				found.append(Vector2i(x, y))
	return found


## The finds: PER_ROOM in each room and ON_LANDING on the landing, never on the
## start, never two on one cell. Ids are "d<depth>_f<number>" in this order.
static func _finds(base: int, grid: PackedStringArray, rooms: Array[Rect2i], depth: int) -> Array:
	var finds: Array = []
	var used: Array[Vector2i] = [START_CELL]
	# Nor on a way down or a lift, nor the cell a rover comes out at beside one.
	for cell: Vector2i in _kept_clear(depth):
		used.append(cell)
	var places: Array = []
	for room: Rect2i in rooms:
		places.append([room, PER_ROOM])
	places.append([LANDING, ON_LANDING])
	for area: Array in places:
		var options: Array[Vector2i] = _floor_cells(grid, area[0])
		for pick: int in int(area[1]):
			var free: Array[Vector2i] = []
			for option: Vector2i in options:
				if not option in used:
					free.append(option)
			if free.is_empty():
				break
			var index: int = finds.size()
			var cell: Vector2i = free[draw(base, 100 + index, free.size())]
			used.append(cell)
			finds.append({ "id": find_id(index, depth), "kind": KINDS[draw(base, 200 + index, KINDS.size())], "cell": cell })
	return finds


static func find_id(index: int, depth: int = DEPTH) -> String:
	return "d%d_f%d" % [depth, index]


## The find with this id in a layout, or {}.
static func find_in(layout_data: Dictionary, find_id_text: String) -> Dictionary:
	for find: Variant in layout_data.get("finds", []):
		if find is Dictionary and str(find.get("id", "")) == find_id_text:
			return find
	return {}


## The same layout for the day this screen is in, kept while its player is below.
static func local_for(world_seed: int, day: int) -> Dictionary:
	if local_depth < DEPTH or local_depth > MAX_DEPTH:
		return {}
	if local_layout.is_empty() or int(local_layout.get("day", -1)) != day or int(local_layout.get("depth", -1)) != local_depth:
		local_layout = layout(world_seed, ZONE, local_depth, day)
	return local_layout


## Takes the rover's depth for this screen: today's layout of it, or the hub.
static func follow(depth: int, world_seed: int, day: int) -> void:
	set_local(depth, layout(world_seed, ZONE, depth, day) if depth > 0 else {})


## The map the rover is held to at `depth` on `day`: the hub's, or the layout's.
static func grid_for(depth: int, world_seed: int, day: int) -> PackedStringArray:
	if depth > 0:
		var data: Dictionary = layout(world_seed, ZONE, depth, day)
		if not data.is_empty():
			return data["grid"]
	return TunnelRock.MAP


## How many finds a depth has (every day the same).
static func find_count(depth: int) -> int:
	return PER_ROOM * ROOM_SLOTS.size() + ON_LANDING if depth >= DEPTH and depth <= MAX_DEPTH else 0


## True if a scene built for `built_depth` on `built_day` no longer shows the rover's
## depth, or (below) the day the finds were drawn for.
static func needs_rebuild(built_depth: int, built_day: int, depth: int, day: int) -> bool:
	return depth != built_depth or (built_depth > 0 and built_day != day)


## Where the rover starts when it goes down, and where it comes out by the hatch.
static func start_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, TunnelRock.at_in(_blank(), START_CELL) + Vector3(0.0, 0.05, 0.0))


## Where the rover comes out by the way down of `depth` (0 is the hub): one cell south
## of the hatch, so it is not on it.
static func hatch_exit_transform(depth: int = 0) -> Transform3D:
	return Transform3D(Basis.IDENTITY, descent_position(depth) + Vector3(0.0, 0.05, TunnelRock.CELL_M))


## A grid of the depth's size, for places that only need its measures.
static func _blank() -> PackedStringArray:
	var out := PackedStringArray()
	for row in HEIGHT:
		out.append(".".repeat(WIDTH))
	return out


## Where the way up is (the exit pad's cell below).
static func ascent_position() -> Vector3:
	return TunnelRock.at_in(_blank(), UP_CELL)


## Where the rover is put when it comes to `depth`: the start below, beside the hatch
## in the hub.
static func pose_for_depth(depth: int) -> Transform3D:
	return start_transform() if depth > 0 else hatch_exit_transform()


## Where a rebuilt scene starts its rover: `known` (the pose the host parked or told,
## or null) if it lies inside `depth`'s rock, else where the depth starts it.
static func rebuild_pose(known: Variant, depth: int, world_seed: int, day: int) -> Transform3D:
	if known is Transform3D and TunnelRock.holds_in(grid_for(depth, world_seed, day), (known as Transform3D).origin):
		return known
	return pose_for_depth(depth)


## True if a rover at `at` is within reach of the way up.
static func near_ascent(at: Vector3) -> bool:
	var there: Vector3 = TunnelRock.at_in(_blank(), UP_CELL)
	return Vector2(there.x - at.x, there.z - at.z).length() <= REACH_M


## Goes below (or back): the layout the scene is built from, or nothing at depth 0.
static func set_local(depth: int, layout_data: Dictionary) -> void:
	local_depth = depth
	local_layout = layout_data if depth > 0 else {}


## Every floor cell can be reached from the start: the rule the tests hold the
## generator to.
static func reachable(grid: PackedStringArray, from: Vector2i) -> Array[Vector2i]:
	var seen: Array[Vector2i] = []
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		if cell in seen or cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].length() \
				or grid[cell.y][cell.x] != ".":
			continue
		seen.append(cell)
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(cell + side)
	return seen


# --- The way down and the finds -------------------------------------------------

## The cell of the way down at `depth` (0 is the hub's).
static func hatch_cell(depth: int) -> Vector2i:
	return DESCENT_CELL if depth <= 0 else HATCH_CELL


## True if `depth` (0 is the hub) has a way down: every depth but the deepest.
static func has_way_down(depth: int) -> bool:
	return depth >= 0 and depth < MAX_DEPTH


static func descent_position(depth: int = 0) -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP if depth <= 0 else _blank(), hatch_cell(depth))


## True if a rover at `at` is within reach of the way down at `depth` (0 is the hub).
static func near_descent(at: Vector3, depth: int = 0) -> bool:
	var there: Vector3 = descent_position(depth)
	return Vector2(there.x - at.x, there.z - at.z).length() <= REACH_M


# --- The lift -------------------------------------------------------------------

## True if `depth` has a lift station: every LIFT_EVERY-th depth.
static func is_lift_depth(depth: int) -> bool:
	return depth >= DEPTH and depth <= MAX_DEPTH and depth % LIFT_EVERY == 0


static func repair_cost_text() -> String:
	return "The repair costs %d credits and %d crystal ore." % [LIFT_COST_CREDITS, LIFT_COST_ORE]


## The depths with a lift station, shallowest first.
static func lift_depths() -> Array[int]:
	var out: Array[int] = []
	for depth: int in range(DEPTH, MAX_DEPTH + 1):
		if is_lift_depth(depth):
			out.append(depth)
	return out


## Where the lift station is at `depth` (0 is the hub's).
static func lift_position(depth: int) -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP if depth <= 0 else _blank(), HUB_LIFT_CELL if depth <= 0 else LIFT_CELL)


## True if a rover at `at` is within reach of the lift at `depth` (0 is the hub's).
static func near_lift(at: Vector3, depth: int) -> bool:
	var there: Vector3 = lift_position(depth)
	return Vector2(there.x - at.x, there.z - at.z).length() <= REACH_M


## Where the rover comes out of the lift at `depth`: one cell south of the hub's lift,
## or the start (the entrance) at a depth.
static func lift_exit_transform(depth: int) -> Transform3D:
	if depth <= 0:
		return Transform3D(Basis.IDENTITY, lift_position(0) + Vector3(0.0, 0.05, TunnelRock.CELL_M))
	return start_transform()


## Where the rover is put on a move to `to_depth`: the start (entrance) going down by
## hatch or lift, and beside the hatch or the lift it comes up by.
static func arrival_pose(to_depth: int, going_down: bool, by_lift: bool) -> Transform3D:
	if going_down:
		return start_transform()
	if by_lift:
		return lift_exit_transform(to_depth)
	return hatch_exit_transform(to_depth)


## Cells no find is put on at `depth`: the way down or the lift and the cell beside it.
static func _kept_clear(depth: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if has_way_down(depth):
		out.append(HATCH_CELL)
		out.append(HATCH_CELL + Vector2i(0, 1))
	if is_lift_depth(depth):
		out.append(LIFT_CELL)
		out.append(LIFT_CELL + Vector2i(0, 1))
	return out


## Why a player in `place` at `depth` can't take `find_id` from `finds` (today's),
## given the ids already `taken` today, or "". The one rule for the host's command;
## nearness is its own check (reach_problem).
static func take_problem(find_id_text: String, finds: Array, taken: Array, place: String, depth: int) -> String:
	if place != ZONE or depth < DEPTH or depth > MAX_DEPTH:
		return "Finds lie in the Lava Tubes, below the hub."
	var known: bool = false
	for find: Variant in finds:
		if find is Dictionary and str(find.get("id", "")) == find_id_text:
			known = true
	if not known:
		return "There is no '%s' here today." % find_id_text
	if find_id_text in taken:
		return "That has been taken already."
	return ""


## Why the farm's rover can't take a find at `there`, or "". `zone` is
## GameState.rover_zone, `known` whether the host has the tunnel rover's place, and
## `at` that place. The host's copy of the rover decides, not the player's word.
static func reach_problem(there: Vector3, zone: String, known: bool, at: Vector3) -> String:
	if zone != ZONE or not known:
		return "The rover is not in the Lava Tubes."
	if Vector2(there.x - at.x, there.z - at.z).length() > REACH_M + HOST_REACH_SLACK_M:
		return "The rover is too far from that."
	return ""


## What a find pays: { "crystal_ore": n, "credits": n }, only what it has.
static func reward(kind: String) -> Dictionary:
	return (REWARDS.get(kind, {}) as Dictionary).duplicate()


static func reward_text(kind: String) -> String:
	var parts: PackedStringArray = []
	var pay: Dictionary = reward(kind)
	if pay.has("crystal_ore"):
		parts.append("%d crystal ore" % int(pay["crystal_ore"]))
	if pay.has("credits"):
		parts.append("%d credits" % int(pay["credits"]))
	return "Took %s: %s." % [NAMES.get(kind, kind), " and ".join(parts)]


# --- Taken finds, per zone per day ----------------------------------------------

## The ids taken in `zone` on `day`: a record of any other day is no longer true.
static func taken_today(taken: Dictionary, zone: String, day: int) -> Array:
	var entry: Variant = taken.get(zone)
	if entry is Dictionary and int(entry.get("day", -1)) == day and entry.get("ids") is Array:
		return (entry["ids"] as Array).duplicate()
	return []


## The record with `find_id_text` added to `zone` on `day`; records of past days
## are dropped as it goes. A copy.
static func with_taken(taken: Dictionary, zone: String, day: int, find_id_text: String) -> Dictionary:
	var out: Dictionary = prune(taken, day)
	var ids: Array = taken_today(out, zone, day)
	if not find_id_text in ids:
		ids.append(find_id_text)
	out[zone] = { "day": day, "ids": ids }
	return out


## The record with only today's entries: a past day is over, and a day that has not
## come is not believed. A copy.
static func prune(taken: Dictionary, day: int) -> Dictionary:
	var out: Dictionary = {}
	for zone: Variant in taken:
		var entry: Variant = taken[zone]
		if entry is Dictionary and int(entry.get("day", -1)) == day:
			out[zone] = (entry as Dictionary).duplicate(true)
	return out


## Why a saved `finds_taken` can't be, or "". Shape only: a record of a past day is
## dropped on load, not refused.
static func taken_problem(taken: Variant) -> String:
	if not taken is Dictionary:
		return "'finds_taken' is not a dictionary."
	for zone: Variant in taken:
		var entry: Variant = taken[zone]
		if not zone is String or not StringName(zone) in ZoneData.ids() or not entry is Dictionary:
			return "'finds_taken' has an entry that is not a known zone's record."
		var day: Variant = entry.get("day")
		if not day is int or day < 0:
			return "'finds_taken' has a day that is not a day."
		var ids: Variant = entry.get("ids")
		if not ids is Array:
			return "'finds_taken' has ids that are not a list."
		var seen: Array[String] = []
		for id: Variant in ids:
			if not id is String or not _is_find_id(id):
				return "'finds_taken' has an id that is not a find's."
			if id in seen:
				return "'finds_taken' has an id twice."
			seen.append(id)
	return ""


static func _is_find_id(text: String) -> bool:
	# Only the canonical spelling: d01_f00 or d1_f+1 are not ids.
	for depth: int in range(DEPTH, MAX_DEPTH + 1):
		for index: int in find_count(depth):
			if text == find_id(index, depth):
				return true
	return false


# --- The saved lifts and deepest depths ------------------------------------------

## Why a saved `lifts_repaired` can't be, or "": zone id -> Array of depths that have
## a lift, each once.
static func lifts_problem(lifts: Variant) -> String:
	if not lifts is Dictionary:
		return "'lifts_repaired' is not a dictionary."
	for zone: Variant in lifts:
		var depths: Variant = lifts[zone]
		if not zone is String or not StringName(zone) in ZoneData.ids() or not depths is Array:
			return "'lifts_repaired' has an entry that is not a known zone's list."
		var seen: Array[int] = []
		for depth: Variant in depths:
			if not depth is int or not is_lift_depth(depth):
				return "'lifts_repaired' has a depth with no lift."
			if depth in seen:
				return "'lifts_repaired' has a depth twice."
			seen.append(depth)
	return ""


## Why a saved `deepest_depth` can't be, or "": zone id -> a depth from 1 to MAX_DEPTH.
static func deepest_problem(deepest: Variant) -> String:
	if not deepest is Dictionary:
		return "'deepest_depth' is not a dictionary."
	for zone: Variant in deepest:
		var depth: Variant = deepest[zone]
		if not zone is String or not StringName(zone) in ZoneData.ids():
			return "'deepest_depth' has an entry that is not a known zone's."
		if not depth is int or depth < DEPTH or depth > MAX_DEPTH:
			return "'deepest_depth' has a depth out of range."
	return ""


## The phone line for the deepest depth reached in `zone`, or "" before any.
static func deepest_text(deepest: Dictionary, zone: String) -> String:
	var depth: int = int(deepest.get(zone, 0))
	return "" if depth <= 0 else "Deepest: Lava Tubes, depth %d" % depth
