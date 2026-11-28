class_name VallesDepth
extends RefCounted
## Valles Marineris, the first far site (docs/design/zones.md section 11, build slice 30): the
## canyon hub, two depths further down the canyon, and the three hazards: wind, thin air and the
## long drive. Laid out from the same integer hash as the other zones (ZoneDepth.stream) on the
## same 24 by 22 grid of 3 m cells, so the tunnels scene, the rover's hold and the host's checks
## work unchanged. Pure rules and words; the props are the scene's, the air stamps are GameState's
## (`cold_since`, saved and synced: the same stamp the Ice Caves' cold uses, read here as air).
## Every number and name here is a [PLACEHOLDER].
##
## Wind: each hour of each depth is gusting or not, a pure function of the seed, the depth and the
## game hour. While it gusts, a rover on open floor drives slower; floor beside a wall (the talus
## at the canyon's foot) is shelter. Thin air: the suit's air drains THIN_AIR_MULT times as fast
## as the base rate; at 100 % the host takes no more finds until the player has been out for
## longer than the grace. The long drive: the first trip costs FIRST_DRIVE_HOURS of game time;
## fast travel after the first visit costs none.

const ZONE: String = "valles_marineris"
## Two depths below the hub [PLACEHOLDER] (a lift is every third depth, so none is built).
const MAX_DEPTH: int = 2
## The hub's way down is the Lava hub's (ZoneDepth.DESCENT_CELL), so the same rover checks work.
const NAMES: Dictionary = { "sediment": "a layered core", "mineral": "a mineral" }

## The wall bands a layered core is cut from, bottom to top (the scene stacks the same bands).
const BAND_NAMES: Array[String] = ["red clay", "pale ash", "rust shale", "grey silt", "ochre sand", "white salt"]

## What a find pays [PLACEHOLDER].
const REWARDS: Dictionary = {
	"sediment": { "credits": 14 },
	"mineral": { "crystal_ore": 1, "credits": 8 },
}
const KINDS: Array[String] = ["sediment", "sediment", "sediment", "mineral"]

## The rooms and passages of each depth (top left): three rooms and the trunk, as the Ice Caves have.
const ROOMS: Dictionary = {
	1: [Rect2i(2, 8, 7, 5), Rect2i(15, 8, 7, 5), Rect2i(8, 1, 7, 5)],
	2: [Rect2i(1, 7, 8, 7), Rect2i(14, 9, 8, 5), Rect2i(9, 1, 6, 6)],
}
const CARVES: Array[Rect2i] = [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 6, 2, 8)]
const LANDING := Rect2i(8, 15, 7, 4)
const PER_ROOM: int = 2
const ON_LANDING: int = 1

## The hub: a canyon floor between two walls. Rows CANYON_TOP to CANYON_BOTTOM are floor; the
## rock above and below is the walls, and the floor's first and last rows (and its end columns)
## are the talus at the walls' feet.
const CANYON_TOP: int = 5
const CANYON_BOTTOM: int = 11
const CANYON_LEFT: int = 1
const CANYON_RIGHT: int = 22

## Wind [PLACEHOLDER]: this share of hours gusts; on open floor a gust slows the rover to this fraction of its speed (30 % slower).
const GUST_PERCENT: int = 35
const GUST_FACTOR: float = 0.7

## Thin air [PLACEHOLDER]: percent of a suit's air used per game hour at the base rate, times THIN_AIR_MULT.
const AIR_PER_HOUR_BASE: float = 8.0
const THIN_AIR_MULT: float = 1.5
const AIR_WARN: float = 75.0
const AIR_MAX: float = 100.0
## Back within this many game hours of leaving keeps the air used so far [PLACEHOLDER].
const AIR_GRACE_HOURS: float = 1.0

## The long drive [PLACEHOLDER]: game hours the first trip takes on top of the usual.
const FIRST_DRIVE_HOURS: float = 2.0

## The quest "Layer by Layer": distinct wall bands per set [PLACEHOLDER 3]; the per-player counters.
const QUEST_BANDS: int = 3
const BAND_MASK: String = "valles_bands"
const NEW_BAND: String = "valles_new_band"

static var _hub: PackedStringArray = PackedStringArray()


# --- The hub --------------------------------------------------------------------

## The hub's map: the canyon floor, and the Lava hub's landing and stem below it so the way up,
## the start and the way down are the same cells.
static func hub_grid() -> PackedStringArray:
	if _hub.is_empty():
		var cells: Array = _blank_cells()
		_carve(cells, Rect2i(CANYON_LEFT, CANYON_TOP, CANYON_RIGHT - CANYON_LEFT + 1, CANYON_BOTTOM - CANYON_TOP + 1))
		_carve(cells, Rect2i(10, CANYON_BOTTOM, 3, 10))
		_carve(cells, LANDING)
		_hub = _join(cells)
	return _hub


static func hatch_position() -> Vector3:
	return ZoneDepth.descent_position(0)


static func near_hatch(at: Vector3) -> bool:
	return ZoneDepth.near_descent(at, 0)


## The notice board at the canyon's west end, on the floor.
const SIGN_CELL := Vector2i(3, 8)


static func sign_position() -> Vector3:
	return TunnelRock.at_in(hub_grid(), SIGN_CELL)


static func near_sign(at: Vector3) -> bool:
	var there: Vector3 = sign_position()
	return Vector2(there.x - at.x, there.z - at.z).length() <= ZoneDepth.REACH_M


# --- The depths -----------------------------------------------------------------

## Depth `depth` on `day`: { "depth", "day", "grid", "start", "rooms", "finds" (Array of
## { "id", "kind", "cell", "room", "band" }) }. "room" is -1 for the landing; "band" is the wall
## band a layered core is cut from (-1 for a mineral). The same seed and day give the same layout.
static func layout(world_seed: int, depth: int, day: int) -> Dictionary:
	if depth < 1 or depth > MAX_DEPTH:
		return {}
	var base: int = ZoneDepth.stream(world_seed, ZONE, depth, day)
	var cells: Array = _blank_cells()
	var rooms: Array[Rect2i] = []
	for room: Rect2i in ROOMS[depth]:
		rooms.append(room)
		_carve(cells, room)
	for area: Rect2i in CARVES:
		_carve(cells, area)
	# The passages join the west and east rooms to the trunk; the hash moves each a row.
	var west_y: int = 9 + ZoneDepth.draw(base, 30, 2)
	var east_y: int = 9 + ZoneDepth.draw(base, 31, 2)
	_carve(cells, Rect2i(8, west_y, 5, 2))
	_carve(cells, Rect2i(11, east_y, 5, 2))
	var grid: PackedStringArray = _join(cells)
	var used: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL, ZoneDepth.HATCH_CELL]
	return { "depth": depth, "day": day, "grid": grid, "start": ZoneDepth.START_CELL, "rooms": rooms,
			"finds": _finds(base, depth, grid, rooms, used) }


## The finds: PER_ROOM in each room and ON_LANDING on the landing, never on the start, the way up
## or the hatch. Ids are "d<depth>_f<number>"; "room" is the room's number, or -1 on the landing.
static func _finds(base: int, depth: int, grid: PackedStringArray, rooms: Array[Rect2i], used_in: Array[Vector2i]) -> Array:
	var finds: Array = []
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
			var kind: String = KINDS[ZoneDepth.draw(base, 200 + index, KINDS.size())]
			finds.append({ "id": ZoneDepth.find_id(index, depth), "kind": kind, "cell": cell, "room": int(area[2]),
					"band": ZoneDepth.draw(base, 300 + index, BAND_NAMES.size()) if kind == "sediment" else -1 })
	return finds


static func find_count() -> int:
	return PER_ROOM * 3 + ON_LANDING


## What a find pays: { "crystal_ore": n, "credits": n }, only what it has.
static func reward(kind: String) -> Dictionary:
	return (REWARDS.get(kind, {}) as Dictionary).duplicate()


static func reward_text(kind: String, band: int = -1) -> String:
	var parts: PackedStringArray = []
	var pay: Dictionary = reward(kind)
	if pay.has("crystal_ore"):
		parts.append("%d crystal ore" % int(pay["crystal_ore"]))
	if pay.has("credits"):
		parts.append("%d credits" % int(pay["credits"]))
	var what: String = NAMES.get(kind, kind)
	if kind == "sediment" and band >= 0 and band < BAND_NAMES.size():
		what = "a layered core from the %s band" % BAND_NAMES[band]
	return "Took %s: %s." % [what, " and ".join(parts)]


## True if a find with a wall band (a layered core) is `kind`.
static func is_core(kind: String) -> bool:
	return kind == "sediment"


# --- Wind -----------------------------------------------------------------------

## Whether the wind gusts on `depth` (0 is the hub) in the game hour `elapsed_days` is in. Pure.
static func gusting(world_seed: int, depth: int, elapsed_days: float) -> bool:
	var hour: int = floori(maxf(elapsed_days, 0.0) * 24.0)
	return ZoneDepth.draw(ZoneDepth.stream(world_seed, ZONE, depth, hour), 7, 100) < GUST_PERCENT


## True where a floor cell is sheltered: a wall within a cell of it (the talus at the walls' feet).
static func sheltered(grid: PackedStringArray, cell: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if (dx != 0 or dy != 0) and _is_rock(grid, cell + Vector2i(dx, dy)):
				return true
	return false


static func _is_rock(grid: PackedStringArray, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].length():
		return true
	return grid[cell.y][cell.x] == "#"


## The drive factor of a rover at `cell` of `grid` at `depth`: GUST_FACTOR on open floor in a
## gust, else 1. Pure.
static func wind_factor(world_seed: int, depth: int, elapsed_days: float, grid: PackedStringArray, cell: Vector2i) -> float:
	if gusting(world_seed, depth, elapsed_days) and not sheltered(grid, cell):
		return GUST_FACTOR
	return 1.0


## The rover's hook (rover_controller): 1 off Valles, else the factor for this screen's map. `at` is
## the rover's place in metres on the floor plane.
static func wind_factor_at(at: Vector2) -> float:
	if ZoneDepth.local_zone != ZONE:
		return 1.0
	var cell := Vector2i(roundi(at.x / TunnelRock.CELL_M + (ZoneDepth.WIDTH - 1) * 0.5),
			roundi(at.y / TunnelRock.CELL_M + (ZoneDepth.HEIGHT - 1) * 0.5))
	return wind_factor(GameState.world_seed, ZoneDepth.local_depth, GameClock.elapsed_days, TunnelRock.grid(), cell)


## The phone line for the wind.
static func wind_text(is_gusting: bool, is_sheltered: bool) -> String:
	if not is_gusting:
		return "WIND: calm."
	if is_sheltered:
		return "WIND: gusting, but the talus gives shelter here."
	return "WIND: gusting. The open floor is %d %% slower; the talus at the wall feet is out of it." % roundi((1.0 - GUST_FACTOR) * 100.0)


# --- Thin air -------------------------------------------------------------------

## The suit's air used, 0 to 100 %, of a player who came in at game-day stamp `since`, at `now`.
## Drains THIN_AIR_MULT times the base rate. Pure; a stamp in the future is nothing used.
static func air_used(since: float, now: float) -> float:
	return clampf((now - since) * 24.0 * AIR_PER_HOUR_BASE * THIN_AIR_MULT, 0.0, AIR_MAX)


static func air_is_out(used: float) -> bool:
	return used >= AIR_MAX


static func air_text(used: float) -> String:
	if air_is_out(used):
		return "Air %d %% used: the suit is out of air. Go out to the farm and come back." % int(used)
	if used >= AIR_WARN:
		return "Air %d %% used: the thin air is draining the suit %.1f times as fast. Head back soon." % [int(used), THIN_AIR_MULT]
	return "Air %d %% used." % int(used)


static func air_out_reply() -> String:
	return "The suit is out of air. Go out to the farm and come back."


## Whether a player who left at `left` and is back at `now` keeps the air they had used.
static func within_grace(left: float, now: float) -> bool:
	return now >= left and (now - left) * 24.0 <= AIR_GRACE_HOURS


# --- The long drive -------------------------------------------------------------

## The game hours the trip into Valles costs on top of the usual: FIRST_DRIVE_HOURS before the
## first visit has opened it (zones_unlocked), none after: fast travel and later drives are free.
static func drive_hours(visited: bool) -> float:
	return 0.0 if visited else FIRST_DRIVE_HOURS


static func first_drive_text() -> String:
	return "The first drive down the canyon road takes %d hours." % roundi(FIRST_DRIVE_HOURS)


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
