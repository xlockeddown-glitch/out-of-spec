class_name MineDepth
extends RefCounted
## The Abandoned Colony Mine (docs/design/zones.md section 13, build step 14): its hub and
## its depths 1 to 6, laid out from the same integer hash as the other zones (ZoneDepth.stream),
## on the same 24 by 22 grid of 3 m cells so the tunnels scene, the rover's hold and the
## host's checks work unchanged. Pure rules and words; the props are the scene's, the shoring
## props and the shored rooms are GameState's (`mine_props`, `rooms_shored`, saved).
## Every number and name here is a [PLACEHOLDER].
##
## The collapse (zones doc section 5): each day the hash drops a rockfall across the way
## into one or two of the three side rooms. A find in a blocked room cannot be taken that
## day, whatever the rover does. Shoring the room (a prop, bought at the hub's crate for
## crystal ore) clears it until 06:00. Depths 2 to 6 (feat/mine-deep) use the same rooms and
## the same hazard, stored by depth (storage_id): shoring depth 2 leaves depth 5 buried.
## Not built here (later PRs): bad air, old charges, Old Props' lift step, a Mine camp.

const ZONE: String = "colony_mine"
## Six depths below the hub, as the Lava Tubes and the Aquifer [PLACEHOLDER]: lifts at 3 and 6,
## and 4 to 6 behind the `mine_deep` gate (GameState.mine_deep_problem).
const MAX_DEPTH: int = 6
## The gate row of data/skills.json that holds the lab level for the deep depths.
const DEEP_GATE: String = "mine_deep"
## The hub's way down, the crate and the notice board (all floor in the hub's map).
const HATCH_CELL := Vector2i(8, 16)
const CRATE_CELL := Vector2i(12, 18)
const SIGN_CELL := Vector2i(8, 18)
## What a shoring prop costs, in shared crystal ore, and how many props a purchase is [PLACEHOLDER].
const GATE_SEALED_TEXT: String = "The gate is sealed. Bram has the key: ask him about the old mine."
const PROP_COST_ORE: int = 2
const PROPS_PER_BUY: int = 1
## One room shored takes this many props [PLACEHOLDER].
const PROPS_PER_ROOM: int = 1
## The most props a farm holds; a save with more is refused, so a purchase stops here [PLACEHOLDER].
const MAX_PROPS: int = 9999
## The rover shores a room from this far from its rockfall, in metres [PLACEHOLDER].
const SHORE_REACH_M: float = 4.0
## The rooms (top left), as the Aquifer's and the Lava Tubes' ROOM_SLOTS: west, east, north.
const ROOMS: Array[Rect2i] = [Rect2i(2, 8, 7, 5), Rect2i(15, 8, 7, 5), Rect2i(8, 1, 7, 5)]
const CARVES: Array[Rect2i] = [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 6, 2, 8)]
const LANDING := Rect2i(8, 15, 7, 4)
const PER_ROOM: int = 2
const ON_LANDING: int = 1
## A room's rockfall id is "r" and its room number (0 west, 1 east, 2 north).
const ROCKFALL_IDS: Array[String] = ["r0", "r1", "r2"]
## At least this many rooms are blocked each day, and at most this many [PLACEHOLDER].
const MIN_BLOCKED: int = 1
const MAX_BLOCKED: int = 2
## From this depth down a day always blocks two rooms, and on the last depth all three
## [PLACEHOLDER]. Depths 1 to 3 keep the one-or-two rule.
const TWO_BLOCKED_FROM: int = 4
const ALL_BLOCKED_AT: int = 6
## What shoring a rockfall and opening a colonist's case count under in GameState.action_counts.
const SHORE_COUNT: String = "shore_room"
const CASE_COUNT: String = "open_colonist_case"
## A colonist's case: at most one a day in a side room, on 1 day in CASE_ODDS [PLACEHOLDER].
const CASE: String = "colonist_case"
const CASE_ODDS: int = 2
const CASE_DAY_TAG: int = 400
const CASE_SLOT_TAG: int = 401
## What a colonist's case pays when the farm has found every reference block [PLACEHOLDER].
const CASE_FALLBACK_CREDITS: int = 15
## What a find is, by kind, and what it pays [PLACEHOLDER].
const KINDS: Array[String] = ["ore", "ore", "ore", "mineral", "scrap", "scrap"]
const REWARDS: Dictionary = {
	"ore": { "crystal_ore": 1, "credits": 6 },
	"mineral": { "credits": 14 },
	"scrap": { "credits": 9 },
}
## What a find pays more for each level below depth 1, by kind [PLACEHOLDER]; ore also adds one
## crystal ore for every second level.
const CREDITS_PER_LEVEL: Dictionary = { "ore": 3, "mineral": 6, "scrap": 4 }
const NAMES: Dictionary = {
	"ore": "stained ore",
	"mineral": "a mineral",
	"scrap": "colony scrap",
	"colonist_case": "a colonist's case",
}

static var _block_cells: Array[Vector2i] = []
static var _block_cells_seed: int = 0
static var _block_cells_ready: bool = false


# --- The hub --------------------------------------------------------------------

static func hatch_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, HATCH_CELL)


static func crate_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, CRATE_CELL)


static func sign_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, SIGN_CELL)


static func near_hatch(at: Vector3) -> bool:
	return _near(hatch_position(), at)


static func near_crate(at: Vector3) -> bool:
	return _near(crate_position(), at)


static func near_sign(at: Vector3) -> bool:
	return _near(sign_position(), at)


static func _near(there: Vector3, at: Vector3) -> bool:
	return Vector2(there.x - at.x, there.z - at.z).length() <= ZoneDepth.REACH_M


# --- The depths --------------------------------------------------------------------

## Depth `depth` on `day`, with the rooms in `shored` (rockfall ids) cleared: { "depth",
## "day", "grid", "start", "rooms", "finds" (Array of { "id", "kind", "cell", "room" }),
## "rockfalls" (Array of { "id", "room", "cell", "shored" }) }. "room" is -1 for the
## landing. `shored` holds plain rockfall ids ("r0"; see shored_today). Only depths 1 to
## MAX_DEPTH exist: any other asks for {}.
static func layout(world_seed: int, depth: int, day: int, shored: Array = []) -> Dictionary:
	if depth < 1 or depth > MAX_DEPTH:
		return {}
	var base: int = ZoneDepth.stream(world_seed, ZONE, depth, day)
	var cells: Array = _blank_cells()
	for room: Rect2i in ROOMS:
		_carve(cells, room)
	for area: Rect2i in CARVES:
		_carve(cells, area)
	# The passages join the west and east rooms to the trunk; the hash moves each a row.
	var west_y: int = 9 + ZoneDepth.draw(base, 30, 2)
	var east_y: int = 9 + ZoneDepth.draw(base, 31, 2)
	_carve(cells, Rect2i(8, west_y, 5, 2))
	_carve(cells, Rect2i(11, east_y, 5, 2))
	var grid: PackedStringArray = _join(cells)
	var rooms: Array[Rect2i] = ROOMS.duplicate()
	# Where each room's way in is: its edge next to the passage (north: the trunk's top).
	var mouths: Array[Vector2i] = [Vector2i(8, west_y), Vector2i(15, east_y), Vector2i(11, 5)]
	var rockfalls: Array = []
	for room: int in blocked_rooms(base, depth):
		rockfalls.append({ "id": ROCKFALL_IDS[room], "room": room, "cell": mouths[room], "shored": ROCKFALL_IDS[room] in shored })
	var used: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL]
	if depth >= 2:  # below depth 1 (which is as it was) no find sits on the hatch or the lift or beside them
		used.append_array(ZoneDepth._kept_clear(depth))
	for fall: Dictionary in rockfalls:
		used.append(fall["cell"])
	return { "depth": depth, "day": day, "grid": grid, "start": ZoneDepth.START_CELL, "rooms": rooms,
			"finds": _finds(base, grid, rooms, used, depth), "rockfalls": rockfalls }


## Today's depth: the rooms the farm has shored today (GameState.rooms_shored) are clear.
static func layout_today(world_seed: int, depth: int, day: int) -> Dictionary:
	return layout(world_seed, depth, day, shored_today(GameState.rooms_shored, day, depth))


## Which rooms (numbers, in order) the rockfall blocks on the day this stream is for
## [PLACEHOLDER rule]: one room, or two, from the hash at depths 1 to 3; always two from
## depth 4 (TWO_BLOCKED_FROM); all three at the last depth (ALL_BLOCKED_AT). The draws and
## their tags are the same at every depth, so depth 1 is as it was.
static func blocked_rooms(base: int, depth: int = 1) -> Array[int]:
	var first: int = ZoneDepth.draw(base, 301, ROOMS.size())
	var out: Array[int] = [first]
	var second: int = (first + 1 + ZoneDepth.draw(base, 302, ROOMS.size() - 1)) % ROOMS.size()
	if depth >= TWO_BLOCKED_FROM or MIN_BLOCKED + ZoneDepth.draw(base, 300, MAX_BLOCKED - MIN_BLOCKED + 1) >= 2:
		out.append(second)
		if depth >= ALL_BLOCKED_AT:
			out.append(ROOMS.size() * (ROOMS.size() - 1) / 2 - first - second)
	out.sort()
	return out


## The finds: PER_ROOM in each room and ON_LANDING on the landing, never on the start,
## the way up or a rockfall. Ids are "d<depth>_f<number>" in this order (as the other zones'
## are); "room" is the room's number, or -1 on the landing. On case days (has_case), one
## side-room find becomes a colonist's case so a rockfall can bury it.
static func _finds(base: int, grid: PackedStringArray, rooms: Array[Rect2i], used_in: Array[Vector2i], depth: int = 1) -> Array:
	var finds: Array = []
	var room_slots: Array[int] = []
	var used: Array[Vector2i] = used_in.duplicate()
	var places: Array = []
	for index: int in rooms.size():
		places.append([rooms[index], PER_ROOM, index])
	places.append([LANDING, ON_LANDING, -1])
	for area: Array in places:
		var options: Array[Vector2i] = ZoneDepth._floor_cells(grid, area[0])
		for pick: int in int(area[1]):
			var free: Array[Vector2i] = []
			for option: Vector2i in options:
				if not option in used:
					free.append(option)
			if free.is_empty():
				break
			var index: int = finds.size()
			var cell: Vector2i = free[ZoneDepth.draw(base, 100 + index, free.size())]
			used.append(cell)
			var room: int = int(area[2])
			if room >= 0:
				room_slots.append(index)
			finds.append({ "id": ZoneDepth.find_id(index, depth), "kind": KINDS[ZoneDepth.draw(base, 200 + index, KINDS.size())],
					"cell": cell, "room": room })
	if not room_slots.is_empty() and has_case(base):
		var chosen: int = room_slots[ZoneDepth.draw(base, CASE_SLOT_TAG, room_slots.size())]
		(finds[chosen] as Dictionary)["kind"] = CASE
	return finds


## True on days whose stream places a colonist's case in one of the side rooms [PLACEHOLDER].
static func has_case(base: int) -> bool:
	return ZoneDepth.draw(base, CASE_DAY_TAG, CASE_ODDS) == 0


static func find_count() -> int:
	return PER_ROOM * ROOMS.size() + ON_LANDING


## What a find pays: { "crystal_ore": n, "credits": n }, only what it has. It pays more
## for each level below depth 1 (CREDITS_PER_LEVEL), so a deeper find is always worth more.
static func reward(kind: String, depth: int = 1) -> Dictionary:
	var pay: Dictionary = (REWARDS.get(kind, {}) as Dictionary).duplicate()
	var levels: int = maxi(depth - 1, 0)
	if levels > 0 and pay.has("credits"):
		pay["credits"] = int(pay["credits"]) + int(CREDITS_PER_LEVEL.get(kind, 0)) * levels
	if levels > 1 and kind == "ore":
		pay["crystal_ore"] = int(pay.get("crystal_ore", 0)) + (levels >> 1)
	return pay


static func reward_text(kind: String, depth: int = 1) -> String:
	if kind == CASE:
		return "Took %s: a reference block." % NAMES.get(kind, kind)
	var parts: PackedStringArray = []
	var pay: Dictionary = reward(kind, depth)
	if pay.has("crystal_ore"):
		parts.append("%d crystal ore" % int(pay["crystal_ore"]))
	if pay.has("credits"):
		parts.append("%d credits" % int(pay["credits"]))
	return "Took %s: %s." % [NAMES.get(kind, kind), " and ".join(parts)]


static func case_fallback_reply() -> String:
	return "Took a colonist's case: every reference block on the farm is found already, so you keep %d credits." % CASE_FALLBACK_CREDITS


static func is_case_fallback_reply(text: String) -> bool:
	return text == case_fallback_reply()


## Every farm cell holding a buried reference block for `world_seed`, in sorted (x, y) order.
static func block_cells(world_seed: int) -> Array[Vector2i]:
	if not _block_cells_ready or _block_cells_seed != world_seed:
		_block_cells.clear()
		_block_cells_seed = world_seed
		_block_cells_ready = true
		@warning_ignore("integer_division")
		var edge: int = Terrain.OLD_HALF_M / Terrain.CELL_M - 1
		for x: int in range(-edge, edge):
			for y: int in range(-edge, edge):
				var cell := Vector2i(x, y)
				if not ReferenceBlock.at(world_seed, cell).is_empty():
					_block_cells.append(cell)
	return _block_cells


## The first farm cell holding a reference block not yet in `found`, or null when all are found.
static func next_block_cell(world_seed: int, found: Dictionary) -> Variant:
	for cell: Vector2i in block_cells(world_seed):
		if not found.has(cell):
			return cell
	return null


## The hub notice board's lines for the Colony Mine's quests (`zone`: `colony_mine`).
static func board_lines(quests: Array, farm_state: Dictionary, own_state: Dictionary) -> Array[String]:
	return NoticeBoard.lines(quests, farm_state, own_state, "zone", ZONE)


# --- The collapse ---------------------------------------------------------------

## The rockfall with this id in a layout, or {}.
static func rockfall_in(layout_data: Dictionary, rockfall_id: String) -> Dictionary:
	for fall: Variant in layout_data.get("rockfalls", []):
		if fall is Dictionary and str(fall["id"]) == rockfall_id:
			return fall
	return {}


## Why a find can't be taken for the rock on it, or "": its room is behind a rockfall
## that has not been shored. A find on the landing is never blocked.
static func blocked_problem(layout_data: Dictionary, find_id_text: String) -> String:
	var find: Dictionary = ZoneDepth.find_in(layout_data, find_id_text)
	if find.is_empty():
		return ""
	for fall: Variant in layout_data.get("rockfalls", []):
		if fall is Dictionary and int(fall["room"]) == int(find.get("room", -1)) and not bool(fall["shored"]):
			return "A rockfall has buried that room today. It needs shoring first."
	return ""


## A rockfall's place in metres on the map the scene uses.
static func rockfall_position(fall: Dictionary) -> Vector3:
	return TunnelRock.at_in(ZoneDepth._blank(), fall["cell"])


## Why the farm can't buy shoring props, or "". Pure: GameState passes what it has.
static func buy_problem(place: String, depth: int, ore: int, near_crate_now: bool, held: int = 0) -> String:
	if place != ZONE or depth != 0:
		return "Shoring props are sold at the crate in the Colony Mine's hub."
	if not near_crate_now:
		return "The rover is too far from the crate."
	if held + PROPS_PER_BUY > MAX_PROPS:
		return "The farm holds as many shoring props as it can."
	if ore < PROP_COST_ORE:
		return "A shoring prop costs %d crystal ore." % PROP_COST_ORE
	return ""


## Why the rover can't shore `rockfall_id` today, or "".
static func shore_problem(layout_data: Dictionary, rockfall_id: String, shored: Array, props: int, at: Vector3) -> String:
	var fall: Dictionary = rockfall_in(layout_data, rockfall_id)
	if fall.is_empty():
		return "There is no rockfall '%s' here today." % rockfall_id
	if rockfall_id in shored or bool(fall["shored"]):
		return "That room is shored already."
	if props < PROPS_PER_ROOM:
		return "The farm has no shoring props. The crate in the hub sells them."
	var there: Vector3 = rockfall_position(fall)
	if Vector2(there.x - at.x, there.z - at.z).length() > SHORE_REACH_M + ZoneDepth.HOST_REACH_SLACK_M:
		return "The rover is too far from that rockfall."
	return ""


## How a rockfall id is stored in `rooms_shored`: plain at depth 1 (old saves read as before),
## "d<depth>_<id>" below, so shoring depth 2 leaves depth 5 buried.
static func storage_id(depth: int, plain: String) -> String:
	return plain if depth <= 1 else "d%d_%s" % [depth, plain]


## Every id a saved `rooms_shored` may hold for `plain_ids`.
static func storage_ids(plain_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for depth: int in range(1, MAX_DEPTH + 1):
		for plain: String in plain_ids:
			out.append(storage_id(depth, plain))
	return out


## The plain rockfall ids shored at `depth` on `day` (a record of another day is no longer
## true; another depth's ids are not this depth's).
static func shored_today(shored: Dictionary, day: int, depth: int = 1) -> Array:
	var out: Array = []
	for plain: String in ROCKFALL_IDS:
		if storage_id(depth, plain) in ZoneDepth.taken_today(shored, ZONE, day):
			out.append(plain)
	return out


## Why a saved `rooms_shored` can't be, or "". Shape only: a past day is dropped on load.
static func shored_problem(shored: Variant) -> String:
	if not shored is Dictionary:
		return "'rooms_shored' is not a dictionary."
	for zone: Variant in shored:
		var entry: Variant = shored[zone]
		if not zone is String or zone != ZONE or not entry is Dictionary:
			return "'rooms_shored' has an entry that is not the Mine's record."
		var day: Variant = entry.get("day")
		if not day is int or day < 0:
			return "'rooms_shored' has a day that is not a day."
		var ids: Variant = entry.get("ids")
		if not ids is Array:
			return "'rooms_shored' has ids that are not a list."
		var seen: Array[String] = []
		for id: Variant in ids:
			if not id is String or not id in storage_ids(ROCKFALL_IDS) or id in seen:
				return "'rooms_shored' has an id that is not a rockfall's, or has it twice."
			seen.append(id)
	return ""


## True if the rockfall in reach should be offered instead of `find_id`: the find's room is
## still buried, so the find cannot be taken yet.
static func prefer_rockfall(layout_data: Dictionary, find_id: String, fall_in_reach: bool) -> bool:
	return fall_in_reach and blocked_problem(layout_data, find_id) != ""


## Why a saved `mine_props` can't be, or "".
static func props_problem(props: Variant) -> String:
	if not props is int or props < 0 or props > MAX_PROPS:
		return "'mine_props' is not a number of props."
	return ""


# --- Cells ----------------------------------------------------------------------

static func _blank_cells() -> Array:
	var cells: Array = []
	for y: int in ZoneDepth.HEIGHT:
		var row: Array = []
		row.resize(ZoneDepth.WIDTH)
		row.fill("#")
		cells.append(row)
	return cells


static func _carve(cells: Array, area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if y >= 0 and y < ZoneDepth.HEIGHT and x >= 0 and x < ZoneDepth.WIDTH:
				cells[y][x] = "."


static func _join(cells: Array) -> PackedStringArray:
	var grid := PackedStringArray()
	for row: Array in cells:
		grid.append("".join(row))
	return grid
