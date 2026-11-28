class_name OlympusDepth
extends RefCounted
## Olympus Mons caves, the second far site (docs/design/zones.md section 11, build slice 31): a
## huge lava tube hall under a collapsed skylight, two depths further along the tube, and three
## hazards: heat, scale (getting lost) and the long climb. Laid out from the same integer hash as the
## other zones (ZoneDepth.stream) on the same 24 by 22 grid of 3 m cells, so the tunnels scene, the
## rover's hold and the host's checks work unchanged. Pure rules and words; the props are the
## scene's, the heat stamps are GameState's (`cold_since`, the exposure clock the Ice Caves' cold and
## Valles' thin air use too: ZoneExposure), the markers are `olympus_markers`. Every number and name
## here is a [PLACEHOLDER].
##
## Heat: the suit's cooling drains HEAT_PER_HOUR percent per game hour; at 100 % the host takes no
## more finds until the player has been out for longer than the grace. Scale: away from the skylight
## the tube is dark and the halls look alike; a player who has left a marker on a depth gets a "back
## to skylight" heading on the field phone there, and no one else does. The long climb: the first
## trip costs FIRST_DRIVE_HOURS of game time; fast travel after the first visit costs none.

const ZONE: String = "olympus_caves"
## Two depths below the hub [PLACEHOLDER].
const MAX_DEPTH: int = 2
const NAMES: Dictionary = { "mineral": "a mineral vein sample", "ore": "a chunk of ore" }

## The vein kinds a mineral sample is cut from [PLACEHOLDER].
const VEIN_NAMES: Array[String] = ["hematite", "pyrite", "galena", "quartz", "native copper", "olivine"]

## What a find pays [PLACEHOLDER].
const REWARDS: Dictionary = {
	"mineral": { "crystal_ore": 1, "credits": 10 },
	"ore": { "crystal_ore": 2, "credits": 4 },
}
const KINDS: Array[String] = ["mineral", "mineral", "ore"]

## The halls of each depth [PLACEHOLDER]: two huge halls and the trunk, mostly empty.
const ROOMS: Dictionary = {
	1: [Rect2i(1, 3, 9, 6), Rect2i(14, 8, 9, 6)],
	2: [Rect2i(2, 8, 9, 6), Rect2i(14, 2, 8, 7)],
}
const CARVES: Array[Rect2i] = [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 6, 2, 8)]
const LANDING := Rect2i(8, 15, 7, 4)
const PER_ROOM: int = 2

## The hub: one huge hall, the stem and the landing.
const HALL := Rect2i(1, 2, 22, 11)
## The notice board in the hall's west end, and where the skylight's shaft of light falls [PLACEHOLDER].
const SIGN_CELL := Vector2i(3, 6)
const HUB_SKYLIGHT_CELL := Vector2i(6, 4)

## Heat [PLACEHOLDER]: percent of the suit's cooling used per game hour.
const HEAT_PER_HOUR: float = 10.0
const HEAT_WARN: float = 70.0
const HEAT_MAX: float = 100.0
## Back within this many game hours of leaving keeps the heat taken so far [PLACEHOLDER].
const HEAT_GRACE_HOURS: float = 0.75

## The long climb [PLACEHOLDER]: game hours the first trip takes on top of the usual.
const FIRST_DRIVE_HOURS: float = 3.0

## The quest "Three Veins": distinct vein kinds to bring [PLACEHOLDER 3]; the per-player counters.
const QUEST_VEINS: int = 3
const QUEST_ID: String = "three_veins"
const VEIN_MASK: String = "olympus_veins"
const NEW_VEIN: String = "olympus_new_vein"

static var _hub: PackedStringArray = PackedStringArray()


# --- The hub --------------------------------------------------------------------

static func hub_grid() -> PackedStringArray:
	if _hub.is_empty():
		var cells: Array = _blank_cells()
		_carve(cells, HALL)
		_carve(cells, Rect2i(10, HALL.end.y - 1, 3, 9))
		_carve(cells, LANDING)
		_hub = _join(cells)
	return _hub


static func hatch_position() -> Vector3:
	return ZoneDepth.descent_position(0)


static func near_hatch(at: Vector3) -> bool:
	return ZoneDepth.near_descent(at, 0)


static func sign_position() -> Vector3:
	return TunnelRock.at_in(hub_grid(), SIGN_CELL)


static func near_sign(at: Vector3) -> bool:
	var there: Vector3 = sign_position()
	return Vector2(there.x - at.x, there.z - at.z).length() <= ZoneDepth.REACH_M


static func hub_skylight_position() -> Vector3:
	return TunnelRock.at_in(hub_grid(), HUB_SKYLIGHT_CELL)


# --- The depths -----------------------------------------------------------------

## Depth `depth` on `day`: { "depth", "day", "grid", "start", "rooms", "skylight" (the cell a shaft
## of light falls at), "finds" (Array of { "id", "kind", "cell", "room", "vein" }) }. "vein" is the
## vein kind a mineral sample is cut from (-1 for ore). The same seed and day give the same layout.
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
	var west_y: int = 9 + ZoneDepth.draw(base, 30, 2)
	var east_y: int = 9 + ZoneDepth.draw(base, 31, 2)
	_carve(cells, Rect2i(8, west_y, 5, 2))
	_carve(cells, Rect2i(11, east_y, 5, 2))
	var grid: PackedStringArray = _join(cells)
	var used: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL, ZoneDepth.HATCH_CELL]
	var finds: Array = _finds(base, depth, grid, rooms, used)
	return { "depth": depth, "day": day, "grid": grid, "start": ZoneDepth.START_CELL, "rooms": rooms,
			"skylight": _skylight(base, grid, rooms, finds), "finds": finds }


## The cell of the skylight: a floor cell of one of the halls that holds no find.
static func _skylight(base: int, grid: PackedStringArray, rooms: Array[Rect2i], finds: Array) -> Vector2i:
	var room: Rect2i = rooms[ZoneDepth.draw(base, 400, rooms.size())]
	var taken: Array[Vector2i] = []
	for find: Dictionary in finds:
		taken.append(find["cell"])
	var free: Array[Vector2i] = []
	for option: Vector2i in ZoneDepth._floor_cells(grid, room):
		if not option in taken:
			free.append(option)
	return free[ZoneDepth.draw(base, 401, free.size())]


static func _finds(base: int, depth: int, grid: PackedStringArray, rooms: Array[Rect2i], used_in: Array[Vector2i]) -> Array:
	var finds: Array = []
	var used: Array[Vector2i] = used_in.duplicate()
	for index_room: int in rooms.size():
		var options: Array[Vector2i] = ZoneDepth._floor_cells(grid, rooms[index_room])
		for pick: int in PER_ROOM:
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
			finds.append({ "id": ZoneDepth.find_id(index, depth), "kind": kind, "cell": cell, "room": index_room,
					"vein": ZoneDepth.draw(base, 300 + index, VEIN_NAMES.size()) if kind == "mineral" else -1 })
	return finds


static func find_count() -> int:
	return PER_ROOM * 2


## What a find pays: { "crystal_ore": n, "credits": n }, only what it has.
static func reward(kind: String) -> Dictionary:
	return (REWARDS.get(kind, {}) as Dictionary).duplicate()


static func reward_text(kind: String, vein: int = -1) -> String:
	var parts: PackedStringArray = []
	var pay: Dictionary = reward(kind)
	if pay.has("crystal_ore"):
		parts.append("%d crystal ore" % int(pay["crystal_ore"]))
	if pay.has("credits"):
		parts.append("%d credits" % int(pay["credits"]))
	var what: String = NAMES.get(kind, kind)
	if kind == "mineral" and vein >= 0 and vein < VEIN_NAMES.size():
		what = "a sample from a %s vein" % VEIN_NAMES[vein]
	return "Took %s: %s." % [what, " and ".join(parts)]


## True if a find with a vein kind (a mineral vein sample) is `kind`.
static func is_vein(kind: String) -> bool:
	return kind == "mineral"


# --- Heat -----------------------------------------------------------------------

## The cooling used, 0 to 100 %, of a player who came in at game-day stamp `since`, at `now`.
## Pure; a stamp in the future is nothing used.
static func heat_used(since: float, now: float) -> float:
	return clampf((now - since) * 24.0 * HEAT_PER_HOUR, 0.0, HEAT_MAX)


static func heat_is_out(used: float) -> bool:
	return used >= HEAT_MAX


static func heat_text(used: float) -> String:
	if heat_is_out(used):
		return "Heat %d %% used: the suit's cooling is spent. Go out to the farm and come back." % int(used)
	if used >= HEAT_WARN:
		return "Heat %d %% used: the tube is hot and the cooling is running down. Head back soon." % int(used)
	return "Heat %d %% used." % int(used)


static func heat_out_reply() -> String:
	return "The suit's cooling is spent. Go out to the farm and come back."


## Whether a player who left at `left` and is back at `now` keeps the heat they had taken.
static func within_grace(left: float, now: float) -> bool:
	return now >= left and (now - left) * 24.0 <= HEAT_GRACE_HOURS


# --- The long climb -------------------------------------------------------------

static func drive_hours(visited: bool) -> float:
	return 0.0 if visited else FIRST_DRIVE_HOURS


static func drive_too_late_text() -> String:
	return "It is too late to start the long climb up the shield volcano. Try again in the morning."


static func first_drive_text() -> String:
	return "The first climb up the volcano's flank takes %d hours." % roundi(FIRST_DRIVE_HOURS)


# --- Markers and the way back ----------------------------------------------------

## A player's marker on a depth: key "<player>:<depth>", value [day, cell x, cell y]. One per
## player per depth, and only today's: the tube is laid out again every day.
static func marker_key(player_id: String, depth: int) -> String:
	return "%s:%d" % [player_id, depth]


static func prune_markers(markers: Dictionary, day: int) -> Dictionary:
	var kept: Dictionary = {}
	for key: Variant in markers:
		var entry: Variant = markers[key]
		if entry is Array and (entry as Array).size() == 3 and int((entry as Array)[0]) == day:
			kept[key] = (entry as Array).duplicate()
	return kept


static func has_marker(markers: Dictionary, player_id: String, depth: int, day: int) -> bool:
	var entry: Variant = markers.get(marker_key(player_id, depth))
	return entry is Array and (entry as Array).size() == 3 and int((entry as Array)[0]) == day


static func with_marker(markers: Dictionary, player_id: String, depth: int, day: int, cell: Vector2i) -> Dictionary:
	var next: Dictionary = prune_markers(markers, day)
	next[marker_key(player_id, depth)] = [day, cell.x, cell.y]
	return next


## "" if `markers` could be a saved set, else why not.
static func markers_problem(markers: Variant) -> String:
	if not markers is Dictionary:
		return "'olympus_markers' must be a dictionary."
	for key: Variant in markers:
		var entry: Variant = (markers as Dictionary)[key]
		if not key is String or not ":" in (key as String) or not entry is Array or (entry as Array).size() != 3:
			return "'olympus_markers' has an entry that is not a player's marker."
		for part: Variant in entry:
			if not part is int and not part is float:
				return "'olympus_markers' has a marker that is not numbers."
		if int((entry as Array)[0]) < 0:
			return "'olympus_markers' has a marker from before day 0."
	return ""


static func marker_reply(depth: int) -> String:
	return "Marker left on depth %d. The phone will point you back to the skylight here." % depth


static func marker_refused_reply() -> String:
	return "You already left a marker on this depth today."


## The eight points of the compass; north is up the screen (towards -z).
const COMPASS: Array[String] = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


## The phone's line: which way and how far the skylight is from `from`, in metres on the floor.
static func heading_text(from: Vector3, to: Vector3) -> String:
	var dx: float = to.x - from.x
	var dz: float = to.z - from.z
	var metres: int = roundi(Vector2(dx, dz).length())
	if metres <= 3:
		return "BACK TO SKYLIGHT: you are under it."
	var angle: float = fposmod(rad_to_deg(atan2(dx, -dz)), 360.0)
	var point: int = int(roundf(angle / 45.0)) % 8
	return "BACK TO SKYLIGHT: %s, %d m." % [COMPASS[point], metres]


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
