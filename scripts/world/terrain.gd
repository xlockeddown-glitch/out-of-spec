class_name Terrain
## The shape of the ground, in meters above the farm's level. The ground is the
## natural land less what was dug, and every PC works it out alike. It has a
## point each meter; digging is by cells of CELL_M, the soil grid's.

## The land is a square this wide, centered on the farm.
const SIZE_M: int = 160
const HALF_M: int = 80
const CELL_M: int = 2
## A dug cell's depth is a whole number of these steps [PLACEHOLDER].
const DIG_STEP_M: float = 0.5
## The deepest a cell can be dug, in steps [PLACEHOLDER].
const MAX_DIG_STEPS: int = 4
## The land is level this far from the middle of the farm (the rim rocks reach
## 32.6 m), from the relay, and from the middle of the road between [PLACEHOLDER].
const FARM_LEVEL_M: float = 33.0
const RELAY_LEVEL_M: float = 10.0
const ROAD_LEVEL_M: float = 5.0
const RELAY := Vector2(-70.0, -70.0)
## The way from the farm to the relay.
const RELAY_WAY := Vector2(-0.70710678, -0.70710678)

## Hills, each x, z, height and how far it reaches, in meters, placed so none is
## between the farm and the relay. 1 in 4 is the steepest [PLACEHOLDER].
const HILLS: Array[Vector4] = [
	Vector4(48, 47, 6, 36), Vector4(47, -45, 6, 35), Vector4(-45, 47, 6, 35),
	Vector4(63, 2, 3.4, 21), Vector4(1, 63, 3.4, 21), Vector4(12, -63, 3.2, 21), Vector4(-63, 12, 3.2, 21),
]
## The land between rolls this much, in squares this wide, this share of it below
## the farm, and blends in over this far [PLACEHOLDER]. The salt picks the lay of
## it: this one keeps every slope under 15 degrees, so a dug side on a hill's side
## can still be driven up.
const ROLL_M: float = 2.2
const ROLL_WIDE_M: int = 26
const ROLL_BELOW: float = 0.6
const ROLL_SALT: int = 12
const BLEND_M: float = 20.0
## The land rises toward its edge: this high, over this far [PLACEHOLDER].
const RIM_M: float = 1.5
const RIM_WIDTH_M: float = 16.0
## A natural height is a whole number of these parts of a meter, so PCs whose
## last digits differ still agree.
const HEIGHT_PARTS: int = 256

## What natural() found before, by point.
static var _natural: PackedFloat32Array = PackedFloat32Array()


## The land before any digging, at a point in whole meters. Past the land's edge,
## the ground at the edge.
static func natural(point: Vector2i) -> float:
	if _natural.is_empty():
		var found := PackedFloat32Array()
		found.resize((SIZE_M + 1) * (SIZE_M + 1))
		var i: int = 0
		for z: int in range(-HALF_M, HALF_M + 1):
			for x: int in range(-HALF_M, HALF_M + 1):
				found[i] = _work_out(x, z)
				i += 1
		_natural = found
	return _natural[(clampi(point.y, -HALF_M, HALF_M) + HALF_M) * (SIZE_M + 1) + clampi(point.x, -HALF_M, HALF_M) + HALF_M]


## True where nothing natural rises or falls: the farm's and the relay's ground
## and the road between.
static func is_level(at: Vector2) -> bool:
	return _from_level(at) <= 0.0


static func _from_level(at: Vector2) -> float:
	var road: Vector2 = RELAY_WAY * clampf(at.dot(RELAY_WAY), 0.0, RELAY.length())
	return minf(minf(at.length() - FARM_LEVEL_M, at.distance_to(RELAY) - RELAY_LEVEL_M), at.distance_to(road) - ROAD_LEVEL_M)


## Only adds, multiplies and roots, which come out alike on every PC.
static func _work_out(x: int, z: int) -> float:
	var at := Vector2(x, z)
	var level_m: float = _from_level(at)
	if level_m <= 0.0:
		return 0.0
	var land_m: float = ROLL_M * (_roll(x, z) - ROLL_BELOW)
	var edge_m: float = HALF_M - maxi(absi(x), absi(z))
	land_m = lerpf(land_m, RIM_M, _ease(1.0 - edge_m / RIM_WIDTH_M)) * _ease(level_m / BLEND_M)
	for hill: Vector4 in HILLS:
		land_m = lerpf(land_m, hill.z, _side(1.0 - at.distance_to(Vector2(hill.x, hill.y)) / hill.w))
	return roundf(land_m * HEIGHT_PARTS) / HEIGHT_PARTS


## 0 to 1, from a value at each corner of wide squares.
static func _roll(x: int, z: int) -> float:
	# Counted from past the land's corner, so whole division rounds down.
	@warning_ignore("integer_division")
	var col: int = (x + SIZE_M) / ROLL_WIDE_M
	@warning_ignore("integer_division")
	var row: int = (z + SIZE_M) / ROLL_WIDE_M
	var tx: float = _ease(float((x + SIZE_M) % ROLL_WIDE_M) / ROLL_WIDE_M)
	var tz: float = _ease(float((z + SIZE_M) % ROLL_WIDE_M) / ROLL_WIDE_M)
	var near: float = lerpf(_corner(col, row), _corner(col + 1, row), tx)
	var far: float = lerpf(_corner(col, row + 1), _corner(col + 1, row + 1), tx)
	return lerpf(near, far, tz)


static func _corner(col: int, row: int) -> float:
	var mixed: int = ((col * 73856093) ^ (row * 19349663) ^ (ROLL_SALT * 83492791)) & 0xffffffff
	mixed = ((mixed ^ (mixed >> 15)) * 668265263) & 0xffffffff
	mixed = ((mixed ^ (mixed >> 13)) * 374761393) & 0xffffffff
	return ((mixed ^ (mixed >> 16)) & 0xff) / 255.0


## A hill's side, 0 at its foot to 1 at its top: straight, with round ends.
static func _side(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.2:
		return 3.125 * t * t
	if t > 0.8:
		return 1.0 - 3.125 * (1.0 - t) * (1.0 - t)
	return 1.25 * (t - 0.1)


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func cell_at(at: Vector2) -> Vector2i:
	return Vector2i((at / CELL_M).floor())


## Whether a cell may be dug at all: not on level ground, nor at the land's edge.
static func can_dig(cell: Vector2i) -> bool:
	var edge: int = HALF_M / CELL_M - 1
	if cell.x < -edge or cell.y < -edge or cell.x >= edge or cell.y >= edge:
		return false
	for x: int in CELL_M + 1:
		for z: int in CELL_M + 1:
			if is_level(Vector2(cell * CELL_M + Vector2i(x, z))):
				return false
	return true


## Why a cell can't be dug one step deeper, or "". It is at most one step deeper
## than any of its neighbors, so a rover can always drive out.
static func dig_problem(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> String:
	if not can_dig(cell):
		return "This ground can't be dug."
	var steps: int = dug.get(cell, 0)
	if steps >= MAX_DIG_STEPS:
		return "This is as deep as it can be dug."
	for neighbor: Vector2i in neighbors(cell):
		if dug.get(neighbor, 0) < steps:
			return "Dig around it first."
	return ""


## Why a cell can't be filled one step, or "".
static func fill_problem(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> String:
	var steps: int = dug.get(cell, 0)
	if steps <= 0:
		return "There is nothing to fill here."
	for neighbor: Vector2i in neighbors(cell):
		if dug.get(neighbor, 0) > steps:
			return "Fill around it first."
	return ""


## Why this can't be a farm's digging, or "". It may hold anything.
static func dug_problem(dug: Dictionary) -> String:
	for cell: Variant in dug:
		if not cell is Vector2i or not dug[cell] is int:
			return "has an entry that is not a dug cell."
		if not can_dig(cell) or dug[cell] < 1 or dug[cell] > MAX_DIG_STEPS:
			return "has a cell that can't be dug like that."
	for cell: Vector2i in dug:
		for neighbor: Vector2i in neighbors(cell):
			if dug.get(neighbor, 0) < dug[cell] - 1:
				return "has a side that is too steep."
	return ""


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var around: Array[Vector2i] = []
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			if x != 0 or z != 0:
				around.append(cell + Vector2i(x, z))
	return around


## The ground at a point in whole meters. `dug` is cell -> steps deep. Points
## between cells are as deep as the shallowest of those that meet there, so a
## hole's sides slope.
static func point_height(point: Vector2i, dug: Dictionary[Vector2i, int]) -> float:
	var ground_m: float = natural(point)
	if dug.is_empty():
		return ground_m
	var first: Vector2i = cell_at(Vector2(point) - Vector2(0.5, 0.5))
	var last: Vector2i = cell_at(Vector2(point) + Vector2(0.5, 0.5))
	var steps: int = dug.get(first, 0)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			steps = mini(steps, dug.get(Vector2i(x, z), 0))
	return ground_m - steps * DIG_STEP_M


## The ground anywhere on the land; past its edge, the ground at the edge.
static func height(at: Vector2, dug: Dictionary[Vector2i, int]) -> float:
	var inside: Vector2 = at.clampf(-HALF_M, HALF_M)
	var low: Vector2i = Vector2i(inside.floor()).mini(HALF_M - 1)
	var t: Vector2 = inside - Vector2(low)
	var near: float = lerpf(point_height(low, dug), point_height(low + Vector2i(1, 0), dug), t.x)
	var far: float = lerpf(point_height(low + Vector2i(0, 1), dug), point_height(low + Vector2i.ONE, dug), t.x)
	return lerpf(near, far, t.y)
