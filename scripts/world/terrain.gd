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
## The land is level this far from the middle of the farm, and from the relay
## [PLACEHOLDER].
const FARM_LEVEL_M: float = 30.0
const RELAY_LEVEL_M: float = 10.0
const RELAY := Vector2(-70.0, -70.0)


## The land before any digging, at a point in whole meters. Level until hills.
static func natural(_point: Vector2i) -> float:
	return 0.0


## True where nothing natural rises or falls: the farm's and the relay's ground.
static func is_level(at: Vector2) -> bool:
	return at.length() <= FARM_LEVEL_M or at.distance_to(RELAY) <= RELAY_LEVEL_M


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
