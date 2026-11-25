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
