class_name OrePocket
extends RefCounted
## Crystal ore buried in the ground, and the bearing a survey reads toward it.
##
## The farm's seed alone says which cells hold a pocket, so every PC agrees and a
## reload re-rolls nothing. A survey's coil turns with the rover's steering until
## the ground answers strongest, and the steering encoder reads the angle
## [ASSUMPTION], so the bearing carries the encoder's true error.

## Pockets on a farm, and the ore in each [PLACEHOLDER].
const COUNT: int = 6
const ORE: int = 2
## New pockets a farm can have grown over its life [PLACEHOLDER].
const MAX_NEW: int = 5000
## Days after a pocket is dug before a new one appears elsewhere [PLACEHOLDER].
const REGROW_DAYS: int = 3
## A new pocket is at least this many cells from the one it replaces.
const MOVE_CELLS: int = 10
## The search for a cell gives up after this many draws, and says NONE.
const MAX_DRAWS: int = 400
## No cell: the farm has no room for a new pocket just now.
const NONE: Vector2i = Vector2i(2147483647, 2147483647)
## How far away a survey feels a pocket [PLACEHOLDER]. At this range 4 degrees,
## the encoder's MPE, is 2.8 m off, or 1.4 cells.
const RANGE_M: float = 40.0
## A bearing can only be read off a sensor in this unit.
const UNIT: String = "degrees"

## The pockets of the last farm asked about.
static var _cells: Array[Vector2i] = []
static var _cells_seed: int = 0


## The cells that hold a pocket on the farm with `world_seed`: the first few drawn
## that can be dug, are not by water and hold no reference block. One stream, as a hash of each cell
## would put them in clumps. Kept for the next call: don't change what it gives.
static func cells(world_seed: int) -> Array[Vector2i]:
	if _cells.is_empty() or _cells_seed != world_seed:
		_cells.clear()
		_cells_seed = world_seed
		@warning_ignore("integer_division")
		var limit: int = Terrain.HALF_M / Terrain.CELL_M
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:ore" % world_seed)
		while _cells.size() < COUNT:
			var cell := Vector2i(rng.randi_range(-limit, limit - 1), rng.randi_range(-limit, limit - 1))
			if Terrain.can_dig(cell) and not Terrain.is_near_water(cell) and not HillDressing.is_at_rock(cell) and not cell in _cells and ReferenceBlock.at(world_seed, cell).is_empty():
				_cells.append(cell)
	return _cells


## Where the pocket that replaces the one dug at `from` appears: drawn from the
## seed, `from` and how many new pockets there are (`extra`), so the same farm
## gives the same draw on every run. A dug cell stays empty, so it is never one
## of `dug`, `found` or the live pockets, and it can be dug, is dry, holds no
## block and has no stone piece (`built`) on it. NONE if no draw fits.
static func replacement(world_seed: int, from: Vector2i, dug: Dictionary, found: Dictionary, extra: Array[Vector2i], built: Dictionary = {}) -> Vector2i:
	@warning_ignore("integer_division")
	var limit: int = Terrain.HALF_M / Terrain.CELL_M
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:ore:%d,%d:%d" % [world_seed, from.x, from.y, extra.size()])
	var originals: Array[Vector2i] = cells(world_seed)
	for _draw: int in MAX_DRAWS:
		var cell := Vector2i(rng.randi_range(-limit, limit - 1), rng.randi_range(-limit, limit - 1))
		if maxi(absi(cell.x - from.x), absi(cell.y - from.y)) < MOVE_CELLS or dug.has(cell) or found.has(cell) or built.has(cell):
			continue
		if cell in originals or cell in extra or not Terrain.can_dig(cell) or Terrain.is_near_water(cell):
			continue
		if not HillDressing.is_at_rock(cell) and ReferenceBlock.at(world_seed, cell).is_empty():
			return cell
	return NONE


## Why `data`'s new pockets and the days their dug ones are waited on can't be a
## farm's, or "". `found` is the pockets dug. Each dug pocket has either grown
## one new pocket or is still waiting, so new plus waiting never passes dug.
static func regrow_problem(new_cells: Variant, pending: Variant, found: Dictionary, world_seed: int) -> String:
	if not new_cells is Array or not pending is Dictionary:
		return "'new_pockets' or 'pocket_pending' has the wrong type."
	var seen: Dictionary = {}
	for cell: Variant in new_cells:
		if not cell is Vector2i or seen.has(cell) or not Terrain.can_dig(cell):
			return "'new_pockets' has a cell that can't be dug, or twice."
		seen[cell] = true
	if seen.size() > MAX_NEW:
		return "'new_pockets' has more pockets than a farm can grow."
	for cell: Vector2i in cells(world_seed):
		if seen.has(cell):
			return "'new_pockets' has a first pocket's cell."
	for cell: Variant in pending:
		if not cell is Vector2i or not found.has(cell) or typeof(pending[cell]) != TYPE_INT or pending[cell] < 0:
			return "'pocket_pending' has a pocket that was not dug, or a bad day."
	if seen.size() + pending.size() > found.size():
		return "'new_pockets' and 'pocket_pending' are more than the pockets dug."
	return ""


## Where a survey at `at` points truly: the middle of the nearest pocket in range
## that is not in `found`, or Vector2.INF. `extra` is the farm's new pockets.
static func nearest(world_seed: int, found: Dictionary[Vector2i, bool], at: Vector2, extra: Array[Vector2i] = []) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_m: float = RANGE_M
	for cell: Vector2i in cells(world_seed) + extra:
		var middle: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M
		if not found.has(cell) and at.distance_to(middle) <= best_m:
			best = middle
			best_m = at.distance_to(middle)
	return best


## Degrees clockwise from north (-Z), seen from above, 0 up to 360.
static func bearing_deg(from: Vector2, to: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(to.x - from.x, from.y - to.y)), 360.0)


## The way a bearing points.
static func way(bearing: float) -> Vector2:
	return Vector2(sin(deg_to_rad(bearing)), -cos(deg_to_rad(bearing)))


## Why `sensor` can't read a bearing, or "".
static func problem(sensor: DriftingSensor) -> String:
	if sensor == null:
		return "There is no steering encoder to read."
	if sensor.error_unit != UNIT or not is_finite(sensor.error):
		return "The steering encoder gives no angle."
	return ""


## What a survey at `at` says: { refused, found } and, if found, { bearing, mpe,
## from [x, z] }, all plain enough for a guest. The bearing is the true one plus the sensor's true error, to its digit.
## Reads the sensor and never writes it. { refused, reason } if it can't be done.
static func survey(sensor: DriftingSensor, world_seed: int, found: Dictionary[Vector2i, bool], at: Vector2, extra: Array[Vector2i] = []) -> Dictionary:
	var why: String = problem(sensor)
	if why != "":
		return { "refused": true, "reason": why }
	var to: Vector2 = nearest(world_seed, found, at, extra)
	if to == Vector2.INF:
		return { "refused": false, "found": false }
	var bearing: float = bearing_deg(at, to) + sensor.error
	if sensor.resolution > 0.0:
		bearing = snappedf(bearing, sensor.resolution)
	return { "refused": false, "found": true, "bearing": fposmod(bearing, 360.0), "mpe": sensor.mpe, "from": [at.x, at.y] }
