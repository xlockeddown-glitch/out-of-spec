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
## Not built here (later PRs): the pressure drop, the wet pack spoiling a ration,
## Vance's quests.

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
## The pump reaches a pool this many metres from its edge [PLACEHOLDER].
const PUMP_REACH_M: float = 4.0
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

## Depth `depth` on `day`, with the pools in `drained` (ids) dry: { "depth", "day",
## "grid" (the water as it is: `w` where a deep pool still stands), "start", "rooms",
## "finds" (Array of { "id", "kind", "cell" }), "pools" (Array of { "id", "rect"
## (Rect2i), "depth_m", "drained" }) }. Only depth 1 exists: any other asks for {}.
static func layout(world_seed: int, depth: int, day: int, drained: Array = []) -> Dictionary:
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
	var dry: PackedStringArray = _join(cells)
	var rooms: Array[Rect2i] = ROOMS.duplicate()
	var out: Dictionary = { "depth": depth, "day": day, "grid": dry, "start": ZoneDepth.START_CELL, "rooms": rooms,
			"finds": _finds(base, dry, rooms, pools), "pools": pools }
	# The water, as it stands: a deep pool that is not drained is `w`.
	for pool: Dictionary in pools:
		if is_deep(pool) and not bool(pool["drained"]):
			var rect: Rect2i = pool["rect"]
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					cells[y][x] = "w"
	out["grid"] = _join(cells)
	return out


## Today's depth: the pools the farm has drained today (GameState.pools_drained) are dry.
static func layout_today(world_seed: int, depth: int, day: int) -> Dictionary:
	return layout(world_seed, depth, day, drained_today(GameState.pools_drained, day))


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


## The finds: PER_ROOM in each room and ON_LANDING on the landing, never on a pool, the
## start or the way up. Ids are "d1_f<number>" in this order (as the Lava Tubes' are).
static func _finds(base: int, grid: PackedStringArray, rooms: Array[Rect2i], pools: Array) -> Array:
	var finds: Array = []
	var used: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL]
	for pool: Dictionary in pools:
		var rect: Rect2i = pool["rect"]
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				used.append(Vector2i(x, y))
	var places: Array = []
	for room: Rect2i in rooms:
		places.append([room, PER_ROOM])
	places.append([LANDING, ON_LANDING])
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
			finds.append({ "id": ZoneDepth.find_id(index, 1), "kind": KINDS[ZoneDepth.draw(base, 200 + index, KINDS.size())], "cell": cell })
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
