class_name AquiferDepth
extends RefCounted
## The Flooded Aquifer (docs/design/zones.md section 13, build step 13): its hub and
## its depth 1, laid out from the same integer hash as the Lava Tubes (ZoneDepth.stream),
## on the same 24 by 22 grid of 3 m cells so the tunnels scene, the rover's hold and
## the host's checks work unchanged. Pure rules and words; the props are the scene's,
## the pump and the drained pools are GameState's (`pump_owned`, `pools_drained`, saved).
## Every number and name here is a [PLACEHOLDER].
##
## Water: each pool has a depth from the hash. Deep (PitWater's own stop depth) is a `w`
## cell, which the rover cannot enter and a find cannot be taken across; shallow is
## floor that slows the rover (PitWater's wade depth); a drained pool is dry floor.
## Pressure drop & wet pack: each day one side room has an open seal at its doorway
## (`valves_shut` shuts it for today), and taking a find that could only be reached by
## wading wets the taker's pack (`packs_wet`), spoiling one camp ration once per day.
## Not built here (later PRs): Vance's quests, depth 2 and below, a lift, a camp.

const ZONE: String = "flooded_aquifer"
## One depth below the hub: no lift, no depth 2.
const MAX_DEPTH: int = 1
## The hub's way down, and what the hub's crate and board stand at (all floor in HUB).
const HATCH_CELL := Vector2i(8, 16)
const CRATE_CELL := Vector2i(14, 16)
const SIGN_CELL := Vector2i(8, 18)
## The hub's pool (decoration: deep water in the room north of the landing).
const HUB_POOL := Rect2i(10, 9, 3, 2)
## What a pump costs, from the shared wallet [PLACEHOLDER].
const PUMP_COST_CREDITS: int = 150
## The pump reaches a pool (and a player shuts a valve) this many metres from it [PLACEHOLDER].
const PUMP_REACH_M: float = 4.0
const VALVE_REACH_M: float = PUMP_REACH_M
## One open seal a day at depth 1, and one camp ration spoiled on a player's first wet pack a day [PLACEHOLDER].
const SEALS_PER_DAY: int = 1
const RATIONS_SPOILED: int = 1
## Pool depths the hash picks from, in metres [PLACEHOLDER]. 0.6 and up stops a rover
## (Terrain.WASH_BLOCK_M), 0.1 and up is waded (PitWater.WADE_MIN_M).
const SHALLOW_M: Array[float] = [0.3, 0.5]
const DEEP_M: Array[float] = [0.9, 1.1]
## The rooms (top left), as the Lava Tubes' ROOM_SLOTS, open floor [PLACEHOLDER].
const ROOMS: Array[Rect2i] = [Rect2i(2, 8, 7, 5), Rect2i(15, 8, 7, 5), Rect2i(8, 1, 7, 5)]
const CARVES: Array[Rect2i] = [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 6, 2, 8)]
const LANDING := Rect2i(8, 15, 7, 4)
const PER_ROOM: int = 2
const ON_LANDING: int = 1
## Tells which pool is which: "p0" is across the trunk to the north room and is always
## deep, so something always lies past deep water; "p1" and "p2" are in the west and
## east passages, whose place the hash picks.
const POOL_IDS: Array[String] = ["p0", "p1", "p2"]
## A room's seal id is "s" and its room number (0 west, 1 east, 2 north).
const SEAL_IDS: Array[String] = ["s0", "s1", "s2"]
const SEAL_REFUSAL: String = "Water is hissing from an open seal in that room. Shut the valve first."
const WET_PACK_SPOILED_TEXT: String = "Your pack got wet wading. One camp ration spoiled."
const WET_PACK_TEXT: String = "Your pack got wet wading."
## What a find is, by kind, and what it pays [PLACEHOLDER].
const KINDS: Array[String] = ["water", "water", "brine", "gear", "gear"]
const REWARDS: Dictionary = {
	"water": { "credits": 10 },
	"brine": { "crystal_ore": 1, "credits": 4 },
	"gear": { "credits": 18 },
}
const NAMES: Dictionary = { "water": "a water sample", "brine": "a brine sample", "gear": "drowned gear" }

static var _hub: PackedStringArray = PackedStringArray()


# --- The hub --------------------------------------------------------------------

## The hub's map: the landing and stem (the same cells as the Lava Tubes' hub, so the
## way up and the start are the same), and a room above with its pool.
static func hub_grid() -> PackedStringArray:
	if _hub.is_empty():
		var cells: Array = _blank_cells()
		for area: Rect2i in [LANDING, Rect2i(10, 13, 3, 8), Rect2i(8, 8, 7, 5)]:
			_carve(cells, area)
		for y: int in range(HUB_POOL.position.y, HUB_POOL.end.y):
			for x: int in range(HUB_POOL.position.x, HUB_POOL.end.x):
				cells[y][x] = "w"
		_hub = _join(cells)
	return _hub


static func hatch_position() -> Vector3:
	return TunnelRock.at_in(hub_grid(), HATCH_CELL)


static func crate_position() -> Vector3:
	return TunnelRock.at_in(hub_grid(), CRATE_CELL)


static func sign_position() -> Vector3:
	return TunnelRock.at_in(hub_grid(), SIGN_CELL)


static func near_hatch(at: Vector3) -> bool:
	return _near(hatch_position(), at)


static func near_crate(at: Vector3) -> bool:
	return _near(crate_position(), at)


static func near_sign(at: Vector3) -> bool:
	return _near(sign_position(), at)


static func _near(there: Vector3, at: Vector3) -> bool:
	return Vector2(there.x - at.x, there.z - at.z).length() <= ZoneDepth.REACH_M


# --- Depth 1 --------------------------------------------------------------------

## Depth `depth` on `day`, with the pools in `drained` (ids) dry and the seals in `shut`
## (ids) closed: { "depth", "day", "grid" (the water as it is: `w` where a deep pool still
## stands), "start", "rooms", "finds" (Array of { "id", "kind", "cell", "room" }),
## "pools" (Array of { "id", "rect" (Rect2i), "depth_m", "drained" }), "seals" (Array of
## { "id", "room", "cell", "shut" }) }. Only depth 1 exists: any other asks for {}.
static func layout(world_seed: int, depth: int, day: int, drained: Array = [], shut: Array = []) -> Dictionary:
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
	var rects: Array[Rect2i] = [Rect2i(11, 6, 2, 2), Rect2i(9, west_y, 2, 2), Rect2i(13, east_y, 2, 2)]
	var pools: Array = []
	for index: int in rects.size():
		var metres: float = DEEP_M[ZoneDepth.draw(base, 40, DEEP_M.size())] if index == 0 \
				else (DEEP_M + SHALLOW_M)[ZoneDepth.draw(base, 40 + index, DEEP_M.size() + SHALLOW_M.size())]
		pools.append({ "id": POOL_IDS[index], "rect": rects[index], "depth_m": metres, "drained": POOL_IDS[index] in drained })
	var mouths: Array[Vector2i] = [Vector2i(8, west_y), Vector2i(15, east_y), Vector2i(11, 5)]
	var open_room: int = seal_room(base)
	var seals: Array = [{ "id": SEAL_IDS[open_room], "room": open_room, "cell": mouths[open_room], "shut": SEAL_IDS[open_room] in shut }]
	var dry: PackedStringArray = _join(cells)
	var rooms: Array[Rect2i] = ROOMS.duplicate()
	var out: Dictionary = { "depth": depth, "day": day, "grid": dry, "start": ZoneDepth.START_CELL, "rooms": rooms,
			"finds": _finds(base, dry, rooms, pools, seals), "pools": pools, "seals": seals }
	# The water, as it stands: a deep pool that is not drained is `w`.
	for pool: Dictionary in pools:
		if is_deep(pool) and not bool(pool["drained"]):
			var rect: Rect2i = pool["rect"]
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					cells[y][x] = "w"
	out["grid"] = _join(cells)
	return out


## Today's depth: the pools drained today (GameState.pools_drained) are dry and the seals
## shut today (GameState.valves_shut) are closed.
static func layout_today(world_seed: int, depth: int, day: int) -> Dictionary:
	return layout(world_seed, depth, day, drained_today(GameState.pools_drained, day), shut_today(GameState.valves_shut, day))


## Which side room (0 west, 1 east, 2 north) has today's open seal [PLACEHOLDER].
static func seal_room(base: int) -> int:
	return ZoneDepth.draw(base, 300, ROOMS.size())


static func is_deep(pool: Dictionary) -> bool:
	return float(pool["depth_m"]) >= Terrain.WASH_BLOCK_M


static func is_shallow(pool: Dictionary) -> bool:
	return float(pool["depth_m"]) >= PitWater.WADE_MIN_M and not is_deep(pool)


## The pool with this id in a layout, or {}.
static func pool_in(layout_data: Dictionary, pool_id: String) -> Dictionary:
	for pool: Variant in layout_data.get("pools", []):
		if pool is Dictionary and str(pool["id"]) == pool_id:
			return pool
	return {}


## True where a rover at `at` wades through a shallow pool that is not drained (this
## screen's layout): the rover drives slower there.
static func wading_at(at: Vector2) -> bool:
	if ZoneDepth.local_zone != ZONE:
		return false
	for pool: Variant in ZoneDepth.local_layout.get("pools", []):
		if pool is Dictionary and is_shallow(pool) and not bool(pool["drained"]) and pool_metres(pool).has_point(at):
			return true
	return false


## A pool's footprint in metres on the map the scene uses.
static func pool_metres(pool: Dictionary) -> Rect2:
	var rect: Rect2i = pool["rect"]
	var low: Vector3 = TunnelRock.at_in(ZoneDepth._blank(), rect.position)
	return Rect2(low.x - TunnelRock.CELL_M * 0.5, low.z - TunnelRock.CELL_M * 0.5, rect.size.x * TunnelRock.CELL_M, rect.size.y * TunnelRock.CELL_M)


## How far a place is from the pool's edge, in metres (0 inside).
static func pool_gap_m(pool: Dictionary, at: Vector3) -> float:
	var box: Rect2 = pool_metres(pool)
	var near := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.z, box.position.y, box.end.y))
	return near.distance_to(Vector2(at.x, at.z))


## The finds: PER_ROOM in each room and ON_LANDING on the landing, never on a pool, an
## open seal's valve cell, the start or the way up. Ids are "d1_f<number>" in this order
## (as the Lava Tubes' are); "room" is 0..2 for the side rooms, or -1 on the landing.
static func _finds(base: int, grid: PackedStringArray, rooms: Array[Rect2i], pools: Array, seals: Array = []) -> Array:
	var finds: Array = []
	var used: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL]
	for pool: Dictionary in pools:
		var rect: Rect2i = pool["rect"]
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				used.append(Vector2i(x, y))
	for seal: Dictionary in seals:
		used.append(seal["cell"])
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
			finds.append({ "id": ZoneDepth.find_id(index, 1), "kind": KINDS[ZoneDepth.draw(base, 200 + index, KINDS.size())],
					"cell": cell, "room": int(area[2]) })
	return finds


static func find_count() -> int:
	return PER_ROOM * ROOMS.size() + ON_LANDING


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


## The cell of a place on `grid` (the same map as TunnelRock.at_in, whatever scene is up).
static func cell_in(grid: PackedStringArray, place: Vector3) -> Vector2i:
	return Vector2i(roundi(place.x / TunnelRock.CELL_M + (grid[0].length() - 1) * 0.5), roundi(place.z / TunnelRock.CELL_M + (grid.size() - 1) * 0.5))


## Why the rover can't take `find_cell`'s find from `from_cell` on `grid` (the water as it
## stands), or "": deep water between them stops a find being taken, as it stops the
## rover. The Lava Tubes have no such rule.
static func water_problem(grid: PackedStringArray, from_cell: Vector2i, find_cell: Vector2i) -> String:
	if find_cell in ZoneDepth.reachable(grid, from_cell):
		return ""
	return "Deep water is in the way. Drain it with the pump, or find another way round."


# --- The pump -------------------------------------------------------------------

## Why the farm can't buy the pump, or "". Pure: GameState passes what it has.
static func buy_problem(place: String, depth: int, owned: bool, credits: int, near_crate_now: bool) -> String:
	if place != ZONE or depth != 0:
		return "The pump is sold at the crate in the Flooded Aquifer's hub."
	if owned:
		return "The farm has a pump already."
	if not near_crate_now:
		return "The rover is too far from the crate."
	if credits < PUMP_COST_CREDITS:
		return "A pump costs %d credits." % PUMP_COST_CREDITS
	return ""


## Why the rover can't pump `pool_id` today, or "".
static func pump_problem(layout_data: Dictionary, pool_id: String, drained: Array, owned: bool, at: Vector3) -> String:
	if not owned:
		return "The farm has no pump. The crate in the hub sells one."
	var pool: Dictionary = pool_in(layout_data, pool_id)
	if pool.is_empty():
		return "There is no pool '%s' here today." % pool_id
	if pool_id in drained:
		return "That pool is drained already."
	if pool_gap_m(pool, at) > PUMP_REACH_M + ZoneDepth.HOST_REACH_SLACK_M:
		return "The rover is too far from that pool."
	return ""


## The pool ids drained in the zone on `day` (a record of another day is no longer true).
static func drained_today(drained: Dictionary, day: int) -> Array:
	return ZoneDepth.taken_today(drained, ZONE, day)


## Why a saved `pools_drained` can't be, or "". Shape only: a past day is dropped on load.
static func drained_problem(drained: Variant) -> String:
	if not drained is Dictionary:
		return "'pools_drained' is not a dictionary."
	for zone: Variant in drained:
		var entry: Variant = drained[zone]
		if not zone is String or zone != ZONE or not entry is Dictionary:
			return "'pools_drained' has an entry that is not the Aquifer's record."
		var day: Variant = entry.get("day")
		if not day is int or day < 0:
			return "'pools_drained' has a day that is not a day."
		var ids: Variant = entry.get("ids")
		if not ids is Array:
			return "'pools_drained' has ids that are not a list."
		var seen: Array[String] = []
		for id: Variant in ids:
			if not id is String or not id in POOL_IDS or id in seen:
				return "'pools_drained' has an id that is not a pool's, or has it twice."
			seen.append(id)
	return ""


# --- Pressure drop (the open seal) and wet pack ---------------------------------

## The seal with this id in a layout, or {}.
static func seal_in(layout_data: Dictionary, seal_id: String) -> Dictionary:
	for seal: Variant in layout_data.get("seals", []):
		if seal is Dictionary and str(seal["id"]) == seal_id:
			return seal
	return {}


## A seal's valve place in metres on the map the scene uses.
static func seal_position(seal: Dictionary) -> Vector3:
	return TunnelRock.at_in(ZoneDepth._blank(), seal["cell"])


## A side room's footprint in metres on the map the scene uses.
static func room_metres(room_index: int) -> Rect2:
	var rect: Rect2i = ROOMS[room_index]
	var low: Vector3 = TunnelRock.at_in(ZoneDepth._blank(), rect.position)
	return Rect2(low.x - TunnelRock.CELL_M * 0.5, low.z - TunnelRock.CELL_M * 0.5, rect.size.x * TunnelRock.CELL_M, rect.size.y * TunnelRock.CELL_M)


static func _room_of(cell: Vector2i) -> int:
	for index: int in ROOMS.size():
		if ROOMS[index].has_point(cell):
			return index
	return -1


## Why a find can't be taken for an open seal in its room, or "". A find on the landing
## is never in a side room.
static func seal_problem(layout_data: Dictionary, find_id_text: String) -> String:
	var find: Dictionary = ZoneDepth.find_in(layout_data, find_id_text)
	if find.is_empty():
		return ""
	var room: int = int(find["room"]) if find.has("room") else _room_of(find["cell"])
	if room < 0:
		return ""
	for seal: Variant in layout_data.get("seals", []):
		if seal is Dictionary and int(seal["room"]) == room and not bool(seal.get("shut", false)):
			return SEAL_REFUSAL
	return ""


## Why the rover can't shut `seal_id` today, or "".
static func valve_problem(layout_data: Dictionary, seal_id: String, shut: Array, at: Vector3) -> String:
	var seal: Dictionary = seal_in(layout_data, seal_id)
	if seal.is_empty():
		return "There is no open seal '%s' here today." % seal_id
	if seal_id in shut or bool(seal.get("shut", false)):
		return "That valve is shut already."
	var there: Vector3 = seal_position(seal)
	if Vector2(there.x - at.x, there.z - at.z).length() > VALVE_REACH_M + ZoneDepth.HOST_REACH_SLACK_M:
		return "The rover is too far from that valve."
	return ""


## The seal ids shut in the zone on `day` (a record of another day is no longer true).
static func shut_today(shut: Dictionary, day: int) -> Array:
	return ZoneDepth.taken_today(shut, ZONE, day)


## Why a saved `valves_shut` can't be, or "". Shape only: a past day is dropped on load.
static func shut_problem(shut: Variant) -> String:
	if not shut is Dictionary:
		return "'valves_shut' is not a dictionary."
	for zone: Variant in shut:
		var entry: Variant = shut[zone]
		if not zone is String or zone != ZONE or not entry is Dictionary:
			return "'valves_shut' has an entry that is not the Aquifer's record."
		var day: Variant = entry.get("day")
		if not day is int or day < 0:
			return "'valves_shut' has a day that is not a day."
		var ids: Variant = entry.get("ids")
		if not ids is Array:
			return "'valves_shut' has ids that are not a list."
		var seen: Array[String] = []
		for id: Variant in ids:
			if not id is String or not id in SEAL_IDS or id in seen:
				return "'valves_shut' has an id that is not a seal's, or has it twice."
			seen.append(id)
	return ""


## True if the open seal in reach should be offered instead of `find_id`: the find's room
## still has an open seal, so the find cannot be taken yet.
static func prefer_seal(layout_data: Dictionary, find_id: String, seal_in_reach: bool) -> bool:
	return seal_in_reach and seal_problem(layout_data, find_id) != ""


## True when `find_cell` is reachable from `from_cell` on `layout_data`'s grid as it
## stands, and is not reachable when today's undrained shallow pool cells count as walls.
static func wades_to(layout_data: Dictionary, from_cell: Vector2i, find_cell: Vector2i) -> bool:
	var grid: PackedStringArray = layout_data.get("grid", PackedStringArray())
	if grid.is_empty() or not find_cell in ZoneDepth.reachable(grid, from_cell):
		return false
	var dry_grid: PackedStringArray = _without_shallow_pools(grid, layout_data.get("pools", []))
	return not find_cell in ZoneDepth.reachable(dry_grid, from_cell)


static func _without_shallow_pools(grid: PackedStringArray, pools: Array) -> PackedStringArray:
	var cells: Array = []
	for y: int in grid.size():
		var row: Array = []
		row.resize(grid[y].length())
		for x: int in grid[y].length():
			row[x] = grid[y][x]
		cells.append(row)
	for pool: Variant in pools:
		if pool is Dictionary and is_shallow(pool) and not bool(pool.get("drained", false)):
			var rect: Rect2i = pool["rect"]
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					if y >= 0 and y < cells.size() and x >= 0 and x < (cells[y] as Array).size():
						cells[y][x] = "w"
	return _join(cells)


static func wet_pack_reply(spoiled: bool) -> String:
	return WET_PACK_SPOILED_TEXT if spoiled else WET_PACK_TEXT


static func is_wet_pack_reply(text: String) -> bool:
	return text == WET_PACK_SPOILED_TEXT or text == WET_PACK_TEXT


## Keeps only today's wet-pack entries (player id -> day). A copy.
static func prune_packs_wet(wet: Dictionary, day: int) -> Dictionary:
	var out: Dictionary = {}
	for who: Variant in wet:
		if who is String and who != "" and wet[who] is int and int(wet[who]) == day:
			out[who] = day
	return out


## Why a saved `packs_wet` can't be, or "". Shape only: a past day is dropped on load.
static func packs_wet_problem(wet: Variant) -> String:
	if not wet is Dictionary:
		return "'packs_wet' is not a dictionary."
	for who: Variant in wet:
		var day: Variant = wet[who]
		if not who is String or who == "" or not day is int or day < 0:
			return "'packs_wet' has an entry that is not a player and a day."
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
