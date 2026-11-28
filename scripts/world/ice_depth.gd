class_name IceDepth
extends RefCounted
## The Polar Ice Caves (docs/design/zones.md section 13, build step 15): the hub, depth 1 and
## the cold. Laid out from the same integer hash as the other zones (ZoneDepth.stream) on the
## same 24 by 22 grid of 3 m cells, so the tunnels scene, the rover's hold and the host's checks
## work unchanged. Pure rules and words; the props are the scene's, the cold stamps are
## GameState's (`cold_since`, saved and synced). Every number and name here is a [PLACEHOLDER].
##
## The cold (zones doc section 5): time spent in the caves cools the player's pack. Cold is a
## percentage, 0 to 100, a pure function of the game time since the player came in (or last
## bought a heater). Past COLD_THRESHOLD the instruments drift: steering-encoder and tire-gauge
## wear on a rover driven in the caves is multiplied by DRIFT_MULTIPLIER. Nothing else changes.
## A heater cartridge (the hub crate, credits) resets it; leaving the caves pauses it
## (back within the grace it resumes; later, after a rescue or on a new day it starts from 0).
## Slick ice and white-out are IceSlick. Not built here (later PRs): the lift, depth 2 and below, an Ice camp.

const ZONE: String = "ice_caves"
## One depth below the hub: no lift, no depth 2.
const MAX_DEPTH: int = 1
## The hub's way down, the heater crate and the notice board (all floor in the hub's map).
const HATCH_CELL := Vector2i(8, 16)
const CRATE_CELL := Vector2i(12, 18)
const SIGN_CELL := Vector2i(8, 18)
## The terraform test pod, in the west corner of the hub's big room, clear of the finds, the camp
## and the notice board (feat/test-pod) [PLACEHOLDER].
const POD_CELL := Vector2i(5, 12)
## What inspecting the sealed pod shows [PLACEHOLDER].
const POD_LINE: String = "A sealed terraform trial pod, still warm and wet inside. A panel says one opening a day."
## Cold gained per game hour, in percent [PLACEHOLDER]; a full day is 24 hours.
const COLD_PER_HOUR: float = 10.0
## Past this much cold the instruments drift [PLACEHOLDER].
const COLD_THRESHOLD: float = 50.0
const COLD_MAX: float = 100.0
## Steering and tire wear multiplier on a rover driven in the caves past the threshold [PLACEHOLDER].
const DRIFT_MULTIPLIER: float = 1.5
## A heater cartridge costs this many credits [PLACEHOLDER]; it resets the cold.
const HEATER_COST_CREDITS: int = 40
## Below this much cold the crate won't sell a heater, in percent [PLACEHOLDER].
const HEATER_MIN_COLD: float = 10.0
## Back in the caves within this many game hours of leaving keeps the old cold [PLACEHOLDER];
## later than that, the cold starts again from 0.
const COLD_GRACE_HOURS: float = 1.0
## The rooms (top left), as the Mine has them: west, east, north.
const ROOMS: Array[Rect2i] = [Rect2i(2, 8, 7, 5), Rect2i(15, 8, 7, 5), Rect2i(8, 1, 7, 5)]
const CARVES: Array[Rect2i] = [Rect2i(8, 15, 7, 4), Rect2i(10, 13, 3, 8), Rect2i(11, 6, 2, 8)]
const LANDING := Rect2i(8, 15, 7, 4)
const PER_ROOM: int = 2
const ON_LANDING: int = 1
## What a find is, by kind, and what it pays [PLACEHOLDER].
const KINDS: Array[String] = ["core", "core", "mineral", "mineral", "probe"]
const REWARDS: Dictionary = {
	"core": { "credits": 10 },
	"mineral": { "crystal_ore": 1, "credits": 6 },
	"probe": { "credits": 24 },
}
const NAMES: Dictionary = { "core": "an ice core", "mineral": "a mineral", "probe": "a frozen probe" }


# --- The hub --------------------------------------------------------------------

static func hatch_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, HATCH_CELL)


static func crate_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, CRATE_CELL)


static func sign_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, SIGN_CELL)


static func pod_position() -> Vector3:
	return TunnelRock.at_in(TunnelRock.MAP, POD_CELL)


static func near_pod(at: Vector3) -> bool:
	return _near(pod_position(), at)


static func near_hatch(at: Vector3) -> bool:
	return _near(hatch_position(), at)


static func near_crate(at: Vector3) -> bool:
	return _near(crate_position(), at)


static func near_sign(at: Vector3) -> bool:
	return _near(sign_position(), at)


static func _near(there: Vector3, at: Vector3) -> bool:
	return Vector2(there.x - at.x, there.z - at.z).length() <= ZoneDepth.REACH_M


# --- Depth 1 --------------------------------------------------------------------

## Depth `depth` on `day`: { "depth", "day", "grid", "start", "rooms", "finds" (Array of
## { "id", "kind", "cell", "room" }) }. "room" is -1 for the landing. Only depth 1 exists:
## any other asks for {}. The same seed and day give the same layout.
static func layout(world_seed: int, depth: int, day: int) -> Dictionary:
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
	var used: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL]
	return { "depth": depth, "day": day, "grid": grid, "start": ZoneDepth.START_CELL, "rooms": rooms,
			"finds": _finds(base, grid, rooms, used) }


## The finds: PER_ROOM in each room and ON_LANDING on the landing, never on the start or the
## way up. Ids are "d1_f<number>" in this order; "room" is the room's number, or -1 on the landing.
static func _finds(base: int, grid: PackedStringArray, rooms: Array[Rect2i], used_in: Array[Vector2i]) -> Array:
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


# --- The cold -------------------------------------------------------------------

## The cold, 0 to 100 %, of a player who came into the caves at game-day stamp `since`, at
## game-day stamp `now`. Pure; a stamp in the future is no cold.
static func cold(since: float, now: float) -> float:
	return clampf((now - since) * 24.0 * COLD_PER_HOUR, 0.0, COLD_MAX)


static func is_drifting(cold_percent: float) -> bool:
	return cold_percent >= COLD_THRESHOLD


## What cold does to the wear on a rover's steering encoder and tire gauges: nothing under the
## threshold, DRIFT_MULTIPLIER past it.
static func drift_multiplier(cold_percent: float) -> float:
	return DRIFT_MULTIPLIER if is_drifting(cold_percent) else 1.0


## The HUD line for a cold reading.
static func cold_text(cold_percent: float) -> String:
	if is_drifting(cold_percent):
		return "Cold %d %%: the instruments drift. Steering and tires wear %.1f× as fast. A heater cartridge resets it." % [int(cold_percent), DRIFT_MULTIPLIER]
	return "Cold %d %%." % int(cold_percent)


## Why a farm can't buy a heater cartridge, or "". Pure: GameState passes what it has.
static func heater_problem(place: String, depth: int, credits: int, near_crate_now: bool, cold_now: float = COLD_MAX) -> String:
	if place != ZONE or depth != 0:
		return "Heater cartridges are sold at the crate in the Ice Caves' hub."
	if not near_crate_now:
		return "The rover is too far from the crate."
	if credits < HEATER_COST_CREDITS:
		return "A heater cartridge costs %d credits." % HEATER_COST_CREDITS
	if cold_now < HEATER_MIN_COLD:
		return "You're not cold enough for a heater cartridge yet."
	return ""


## Whether a player who left the caves at `left` and is back at `now` keeps their old cold.
static func within_grace(left: float, now: float) -> bool:
	return now >= left and (now - left) * 24.0 <= COLD_GRACE_HOURS


## Why a saved `cold_since` can't be, or "". Shape only: a player id to a finite stamp.
static func cold_problem(stamps: Variant) -> String:
	if not stamps is Dictionary:
		return "'cold_since' is not a dictionary."
	for who: Variant in stamps:
		var stamp: Variant = stamps[who]
		if not who is String or not (stamp is float or stamp is int) or not is_finite(float(stamp)) or float(stamp) < 0.0:
			return "'cold_since' has an entry that is not a player and a day."
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
