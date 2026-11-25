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


## Where a survey at `at` points truly: the middle of the nearest pocket in range
## that is not in `found`, or Vector2.INF.
static func nearest(world_seed: int, found: Dictionary[Vector2i, bool], at: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_m: float = RANGE_M
	for cell: Vector2i in cells(world_seed):
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
static func survey(sensor: DriftingSensor, world_seed: int, found: Dictionary[Vector2i, bool], at: Vector2) -> Dictionary:
	var why: String = problem(sensor)
	if why != "":
		return { "refused": true, "reason": why }
	var to: Vector2 = nearest(world_seed, found, at)
	if to == Vector2.INF:
		return { "refused": false, "found": false }
	var bearing: float = bearing_deg(at, to) + sensor.error
	if sensor.resolution > 0.0:
		bearing = snappedf(bearing, sensor.resolution)
	return { "refused": false, "found": true, "bearing": fposmod(bearing, 360.0), "mpe": sensor.mpe, "from": [at.x, at.y] }
