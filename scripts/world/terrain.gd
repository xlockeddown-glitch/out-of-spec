class_name Terrain
## The shape of the ground, in meters above the farm's level. The ground is the
## natural land less what was dug, and every PC works it out alike. It has a
## point each meter; digging is by cells of CELL_M, the soil grid's.

## The land is a square this wide, centered on the farm: 240 m, grown from 160 m
## [PLACEHOLDER]. Inside the old 160 m the ground is exactly what it was, so old
## saves keep their places (natural_on); the ring outside is new ground.
const SIZE_M: int = 240
const HALF_M: int = 120
## The old land's size and edge. The old ground, its rim, its rolls and everything
## drawn from a stream over it (ore pockets, plants) are kept at these.
const OLD_SIZE_M: int = 160
const OLD_HALF_M: int = 80
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

## The wash: a pool on the arch hill's top, in front of the mesa arch, cut into the
## land [PLACEHOLDER all of it]. It is an ellipse with its middle and half-widths
## in meters. Inside it the shallows have a flat floor to WASH_FLOOR of the way out,
## rising to a lip above the water; the deep part has its own ellipse and sits
## against the arch. North, by the arch's own ground, the cut fades out.
const WASH_AT := Vector2(63.0, 8.0)
const WASH_RADII := Vector2(6.0, 3.7)
const WASH_FLOOR: float = 0.68
const WASH_DEEP_AT := Vector2(63.0, 7.9)
const WASH_DEEP_RADII := Vector2(4.2, 1.2)
const WASH_DEEP_FLOOR: float = 0.2
## Past the deep ellipse the bed climbs to the lip over this much more of its width.
const WASH_DEEP_BANK: float = 0.6
## The water's level, how far below it the shallows' floor and the deep's floor are,
## and how far above it the lip is [PLACEHOLDER].
const WASH_LEVEL_M: float = 1.7
const WASH_SHELF_M: float = 0.4
const WASH_DEEP_M: float = 1.0
const WASH_LIP_M: float = 0.3
## The cut reaches this far out, in the ellipse's widths, and fades out over the last of it.
const WASH_REACH: float = 1.6
const WASH_FADE: float = 1.2
## North of this the arch stands; the cut fades in over this much more [PLACEHOLDER].
const WASH_ARCH_Z: float = 4.3
const WASH_ARCH_FADE_M: float = 3.4
## Water this deep or more stops a rover [PLACEHOLDER]. Shallower, a rover drives at
## this share of its speed [PLACEHOLDER].
const WASH_BLOCK_M: float = 0.6
const WATER_SPEED: float = 0.7
## No digging this close to the water [PLACEHOLDER].
const WASH_NEAR_M: float = 1.0
## The rover's box is 1.6 by 2.4 m: half its width, and its middle to a corner.
const ROVER_HALF_WIDTH_M: float = 0.8
const ROVER_REACH_M: float = 1.45

## A stone pad levels the ground under it (StonePieces). Pads that touch, corners
## too, are one flat top; no point of it may be this far from the natural ground
## [PLACEHOLDER]. A group that would be is not levelled at all.
const PAD_SHIFT_M: float = 0.75
## Between two points a meter apart the ground may change this much beside a pad:
## the rover slides up 45 degrees, a meter per meter [PLACEHOLDER].
const PAD_STEP_M: float = 0.9

## Where pads level the ground now: point -> its height. Set by use_pads(), from
## the farm's pieces, so every PC has the same.
static var level_points: Dictionary[Vector2i, float] = {}

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
				found[i] = natural_on(Vector2i(x, z), HALF_M)
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
static func _work_out(x: int, z: int, half_m: int = OLD_HALF_M) -> float:
	return roundf(_wash(Vector2(x, z), _land(x, z, half_m)) * HEIGHT_PARTS) / HEIGHT_PARTS


## The natural ground at a point if the land were `half_m` out from the middle.
## Inside the old land (OLD_HALF_M) it is the old ground exactly, rim and all.
## Outside, it eases from the height at the old edge (the nearest point of the old
## land) to the same function with its rim at the new edge, over the way between
## the two edges, a smoothstep [PLACEHOLDER: 40 m at 240 m]. natural() is this at
## HALF_M. It keeps no cache; LandMeasure uses it for other sizes.
static func natural_on(point: Vector2i, half_m: int) -> float:
	var out_m: int = maxi(absi(point.x), absi(point.y))
	if out_m <= OLD_HALF_M:
		return _work_out(point.x, point.y)
	var edge := Vector2i(clampi(point.x, -OLD_HALF_M, OLD_HALF_M), clampi(point.y, -OLD_HALF_M, OLD_HALF_M))
	var along: float = float(out_m - OLD_HALF_M) / float(maxi(half_m - OLD_HALF_M, 1))
	var eased: float = lerpf(_work_out(edge.x, edge.y), _work_out(point.x, point.y, half_m), _ease(along))
	return roundf(eased * HEIGHT_PARTS) / HEIGHT_PARTS


## The land without the wash.
static func _land(x: int, z: int, half_m: int = OLD_HALF_M) -> float:
	var at := Vector2(x, z)
	var level_m: float = _from_level(at)
	if level_m <= 0.0:
		return 0.0
	var land_m: float = ROLL_M * (_roll(x, z) - ROLL_BELOW)
	var edge_m: float = half_m - maxi(absi(x), absi(z))
	land_m = lerpf(land_m, RIM_M, _ease(1.0 - edge_m / RIM_WIDTH_M)) * _ease(level_m / BLEND_M)
	for hill: Vector4 in HILLS:
		land_m = lerpf(land_m, hill.z, _side(1.0 - at.distance_to(Vector2(hill.x, hill.y)) / hill.w))
	return land_m


## How far out from the middle of an ellipse a point is: 1 at its edge.
static func _out(at: Vector2, middle: Vector2, radii: Vector2) -> float:
	return ((at - middle) / radii).length()


## How far out in the wash a point is, 1 at the water's ellipse.
static func wash_out(at: Vector2) -> float:
	return _out(at, WASH_AT, WASH_RADII)


## The land with the wash cut into it.
static func _wash(at: Vector2, land_m: float) -> float:
	var out: float = wash_out(at)
	if out >= WASH_REACH:
		return land_m
	var level_m: float = WASH_LEVEL_M
	var shelf: float = clampf(inverse_lerp(WASH_FLOOR, 1.0, out), 0.0, 3.0)
	var shallow_m: float = lerpf(level_m - WASH_SHELF_M, level_m + WASH_LIP_M, shelf)
	var deep: float = maxf(inverse_lerp(WASH_DEEP_FLOOR, 1.0, _out(at, WASH_DEEP_AT, WASH_DEEP_RADII)), 0.0)
	var deep_m: float = lerpf(level_m - WASH_DEEP_M, level_m - WASH_SHELF_M, minf(deep, 1.0))
	deep_m = lerpf(deep_m, level_m + WASH_LIP_M, clampf((deep - 1.0) / WASH_DEEP_BANK, 0.0, 1.0))
	var cut_m: float = minf(land_m, minf(shallow_m, deep_m))
	var share: float = clampf(inverse_lerp(WASH_ARCH_Z, WASH_ARCH_Z + WASH_ARCH_FADE_M, at.y), 0.0, 1.0)
	share *= 1.0 - _ease(inverse_lerp(WASH_FADE, WASH_REACH, out))
	return lerpf(land_m, cut_m, share)


## The water's depth at a point: nothing but in the wash, where it is the
## level less the natural ground.
static func water_depth_m(at: Vector2) -> float:
	if wash_out(at) >= 1.0:
		return 0.0
	var none: Dictionary[Vector2i, int] = {}
	return maxf(WASH_LEVEL_M - height(at, none), 0.0)


## Whether water here stops a rover or a walker: the wash's, or a dug pit's.
static func is_deep(at: Vector2) -> bool:
	return water_depth_m(at) >= WASH_BLOCK_M or PitWater.is_deep(at)


## `at`, or a place south of it, away from the arch, where a rover turned any way is
## clear of the deep, if one at `at` would stand in it whichever way it was turned.
static func clear_of_deep(at: Vector2) -> Vector2:
	if _gap_m(at) >= ROVER_HALF_WIDTH_M - 0.05:
		return at
	var out: Vector2 = at
	while _gap_m(out) < ROVER_REACH_M + 0.1 and out.y < HALF_M:
		out.y += 0.25
	return out


## How far a point is from deep water, the ford's or a pit's.
static func _gap_m(at: Vector2) -> float:
	return minf(Ford.gap_m(at), PitWater.gap_m(at))


## Whether a cell is in or by the water, so it can't be dug [ASSUMPTION].
static func is_near_water(cell: Vector2i) -> bool:
	var reach: Vector2 = WASH_RADII + Vector2.ONE * WASH_NEAR_M
	var low: Vector2 = Vector2(cell * CELL_M)
	if low.x > WASH_AT.x + reach.x or low.x + CELL_M < WASH_AT.x - reach.x or low.y > WASH_AT.y + reach.y or low.y + CELL_M < WASH_AT.y - reach.y:
		return false
	for x: int in CELL_M + 1:
		for z: int in CELL_M + 1:
			if _out(Vector2(cell * CELL_M + Vector2i(x, z)), WASH_AT, WASH_RADII + Vector2.ONE * WASH_NEAR_M) < 1.0:
				return true
	return false


## 0 to 1, from a value at each corner of wide squares.
static func _roll(x: int, z: int) -> float:
	# Counted from past the old land's corner, so whole division rounds down and the
	# old squares are the same. The new land's corner is only 120 m out, still past it.
	@warning_ignore("integer_division")
	var col: int = (x + OLD_SIZE_M) / ROLL_WIDE_M
	@warning_ignore("integer_division")
	var row: int = (z + OLD_SIZE_M) / ROLL_WIDE_M
	var tx: float = _ease(float((x + OLD_SIZE_M) % ROLL_WIDE_M) / ROLL_WIDE_M)
	var tz: float = _ease(float((z + OLD_SIZE_M) % ROLL_WIDE_M) / ROLL_WIDE_M)
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


## Whether a cell is in the old land, the one every old farm's buried blocks and
## pockets were drawn over (the new ring has none, for now).
static func in_old_land(cell: Vector2i) -> bool:
	@warning_ignore("integer_division")
	var edge: int = OLD_HALF_M / CELL_M - 1
	return cell.x >= -edge and cell.y >= -edge and cell.x < edge and cell.y < edge


## Whether a cell may be dug at all: not on level ground, nor at the land's edge.
static func can_dig(cell: Vector2i) -> bool:
	@warning_ignore("integer_division")
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
	# Not in can_dig, so a save with older digging here still loads.
	if not can_dig(cell) or HillDressing.is_at_rock(cell):
		return "This ground can't be dug."
	if is_near_water(cell):
		return "Too near the water to dig."
	var steps: int = dug.get(cell, 0)
	if steps >= MAX_DIG_STEPS:
		return "This is as deep as it can be dug."
	for neighbor: Vector2i in neighbors(cell):
		if _dug_steps(neighbor, dug) < steps:
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
## hole's sides slope. A pad's level (level_points) is the ground under it.
static func point_height(point: Vector2i, dug: Dictionary[Vector2i, int]) -> float:
	if not level_points.is_empty() and level_points.has(point):
		return level_points[point]
	return dug_height(point, dug)


## point_height without the pads: the natural ground less the digging.
static func dug_height(point: Vector2i, dug: Dictionary[Vector2i, int]) -> float:
	var ground_m: float = natural(point)
	if dug.is_empty():
		return ground_m
	var first: Vector2i = cell_at(Vector2(point) - Vector2(0.5, 0.5))
	var last: Vector2i = cell_at(Vector2(point) + Vector2(0.5, 0.5))
	var steps: int = _dug_steps(first, dug)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			steps = mini(steps, _dug_steps(Vector2i(x, z), dug))
	return ground_m - steps * DIG_STEP_M


## The pads in groups: pads that touch, corners too, are one group.
static func pad_groups(pads: Array[Vector2i]) -> Array[Array]:
	var groups: Array[Array] = []
	var is_pad: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in pads:
		is_pad[cell] = true
	var seen: Dictionary[Vector2i, bool] = {}
	for start: Vector2i in pads:
		if seen.has(start):
			continue
		var group: Array[Vector2i] = [start]
		seen[start] = true
		var next: int = 0
		while next < group.size():
			for around: Vector2i in neighbors(group[next]):
				if is_pad.has(around) and not seen.has(around):
					seen[around] = true
					group.append(around)
			next += 1
		groups.append(group)
	return groups


## Every point under a group of pad cells, edges too.
static func group_points(group: Array) -> Dictionary[Vector2i, bool]:
	var points: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in group:
		for x: int in CELL_M + 1:
			for z: int in CELL_M + 1:
				points[cell * CELL_M + Vector2i(x, z)] = true
	return points


## The level a group would be flat at: the mean of the natural ground under all of
## it, to a 1/HEIGHT_PARTS of a meter. Natural heights are whole parts of that, so
## the sum is exact and the order of the points does not matter.
static func group_level_m(points: Dictionary[Vector2i, bool]) -> float:
	var total: float = 0.0
	for point: Vector2i in points:
		total += natural(point)
	return roundf(total / points.size() * HEIGHT_PARTS) / HEIGHT_PARTS


## Why a group of pads is not levelled, or "": a pad on dug ground or by the water
## (a save from before the rules) or a level that would be over PAD_SHIFT_M from
## the natural ground anywhere. Such a group follows the ground as it is.
static func group_unlevelled(group: Array, dug: Dictionary[Vector2i, int]) -> String:
	for cell: Vector2i in group:
		if dug.get(cell, 0) > 0:
			return "on dug ground"
		if is_near_water(cell):
			return "by the water"
	var points: Dictionary[Vector2i, bool] = group_points(group)
	var level_m: float = group_level_m(points)
	for point: Vector2i in points:
		if absf(level_m - natural(point)) > PAD_SHIFT_M:
			return "too steep"
	return ""


## The height of every point under the pads that are levelled: each group that
## qualifies (group_unlevelled) is flat at its group_level_m. Only the pads and the
## digging decide it, so it can be worked out again from a save, and a group that
## does not qualify never makes the rest fail.
static func pad_levels(pads: Array[Vector2i], dug: Dictionary[Vector2i, int]) -> Dictionary[Vector2i, float]:
	var levels: Dictionary[Vector2i, float] = {}
	for group: Array in pad_groups(pads):
		if group_unlevelled(group, dug) != "":
			continue
		var points: Dictionary[Vector2i, bool] = group_points(group)
		var level_m: float = group_level_m(points)
		for point: Vector2i in points:
			levels[point] = level_m
	return levels


## The most a level point is from the natural ground.
static func pad_shift_m(levels: Dictionary[Vector2i, float]) -> float:
	var shift_m: float = 0.0
	for point: Vector2i in levels:
		shift_m = maxf(shift_m, absf(levels[point] - natural(point)))
	return shift_m


## The most the ground changes between two points a meter apart, east-west or
## north-south, where one of them is in `points`: `levels` are the pad points, the
## rest as dug. PAD_STEP_M is the most a rover can climb.
static func max_step_m(points: Dictionary[Vector2i, bool], levels: Dictionary[Vector2i, float], dug: Dictionary[Vector2i, int]) -> float:
	var steepest_m: float = 0.0
	for point: Vector2i in points:
		var here_m: float = levels.get(point, dug_height(point, dug))
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + side
			if absi(next.x) > HALF_M or absi(next.y) > HALF_M:
				continue
			steepest_m = maxf(steepest_m, absf(here_m - levels.get(next, dug_height(next, dug))))
	return steepest_m


## Levels the ground under these pad cells from now on.
static func use_pads(pads: Array[Vector2i], dug: Dictionary[Vector2i, int]) -> void:
	level_points = pad_levels(pads, dug)


## A cell's digging. The water's bed is fixed, so an older save's digging in or by
## the water doesn't count.
static func _dug_steps(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> int:
	var steps: int = dug.get(cell, 0)
	return 0 if steps > 0 and is_near_water(cell) else steps


## The ground anywhere on the land; past its edge, the ground at the edge.
static func height(at: Vector2, dug: Dictionary[Vector2i, int]) -> float:
	var inside: Vector2 = at.clampf(-HALF_M, HALF_M)
	var low: Vector2i = Vector2i(inside.floor()).mini(HALF_M - 1)
	var t: Vector2 = inside - Vector2(low)
	var near: float = lerpf(point_height(low, dug), point_height(low + Vector2i(1, 0), dug), t.x)
	var far: float = lerpf(point_height(low + Vector2i(0, 1), dug), point_height(low + Vector2i.ONE, dug), t.x)
	return lerpf(near, far, t.y)
