class_name PitWater
extends RefCounted
## Where dug pits hold water, worked out from what is known: the dug steps, the stone
## pieces and the land. Nothing of it is saved or sent, and there is no chance in it,
## so every PC finds the same water.
##
## The ground seeps. A pit three steps deep or more, and every such pit touching it,
## fills to the water table, but never above the lowest ground round it. Two steps
## are dry, three hold half a meter (shallow, a rover wades), and the fourth step
## makes it a meter (deep, which stops a rover). A channel laid next to such a pit
## carries a thin film along its length, and one step dimples it runs into that lie
## lower fill to their own rims.

## A cell this many steps down reaches the water [PLACEHOLDER].
const SEEP_STEPS: int = 3
## The table lies this far under the lowest natural ground in a pit [PLACEHOLDER].
const TABLE_M: float = 1.0
## A channel's film is this deep over the channel's floor [PLACEHOLDER].
const FILM_M: float = 0.08
## A rover wades from this depth, so a film does not slow it [PLACEHOLDER].
const WADE_MIN_M: float = 0.1
## Water this shallow is no water at all.
const MIN_DEPTH_M: float = 0.02 ## [PLACEHOLDER]

## Wet cells and the level of the water in each.
static var _levels: Dictionary[Vector2i, float] = {}
## Cells where a channel carries its film.
static var _film: Dictionary[Vector2i, bool] = {}
static var _dug: Dictionary[Vector2i, int] = {}
## The deep boxes, each a run along x, and the water level at each.
static var _blocks: Array[Rect2] = []
static var _block_levels: Array[float] = []
## Ground at each cell's middle, and the natural ground there, for one working out.
static var _ground_cache: Dictionary[Vector2i, float] = {}
static var _natural_cache: Dictionary[Vector2i, float] = {}
## The ground at whole meters, for one working out of the blocks.
static var _point_cache: Dictionary[Vector2i, float] = {}


## The water for these steps and pieces: { levels: cell -> level, film: cell -> true }.
static func work_out(dug: Dictionary[Vector2i, int], pieces: Dictionary[Vector2i, int]) -> Dictionary:
	var wet: Dictionary[Vector2i, float] = {}
	var seen: Dictionary[Vector2i, bool] = {}
	_ground_cache.clear()
	_natural_cache.clear()
	for cell: Vector2i in dug:
		if _steps(cell, dug) < SEEP_STEPS or seen.has(cell):
			continue
		var body: Dictionary[Vector2i, bool] = _body(cell, dug, seen)
		var low_m: float = INF
		var table_m: float = INF
		for member: Vector2i in body:
			low_m = minf(low_m, _ground_m(member, dug))
			table_m = minf(table_m, _natural_m(member) - TABLE_M)
		var level: float = minf(table_m, _rim_m(body, dug))
		if level > low_m + MIN_DEPTH_M:
			for member: Vector2i in body:
				wet[member] = level
	var filmed: Dictionary[Vector2i, bool] = {}
	var pits: Dictionary[Vector2i, float] = wet.duplicate()
	for net: Array[Vector2i] in _networks(pieces):
		if not _is_fed(net, pits):
			continue
		for cell: Vector2i in net:
			if not pits.has(cell):
				filmed[cell] = true
		for cell: Vector2i in net:
			for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_fill_dimple(cell + side, cell, dug, pits, pieces, wet)
	_ground_cache.clear()
	_natural_cache.clear()
	return { "levels": wet, "film": filmed }


## Takes this work as the farm's water.
static func use(result: Dictionary, dug: Dictionary[Vector2i, int]) -> void:
	_levels.assign(result["levels"])
	_film.assign(result["film"])
	_dug = dug.duplicate()
	_work_out_blocks()


static func clear() -> void:
	_levels.clear()
	_film.clear()
	_dug.clear()
	_blocks.clear()
	_block_levels.clear()


static func levels() -> Dictionary[Vector2i, float]:
	return _levels


static func film() -> Dictionary[Vector2i, bool]:
	return _film


## The water's top at a point, or -INF where there is none. A film rides the ground.
static func level_m(at: Vector2) -> float:
	var cell: Vector2i = Terrain.cell_at(at)
	if _levels.has(cell):
		return _levels[cell]
	if _film.has(cell):
		return Terrain.height(at, _dug) + FILM_M
	return -INF


## How deep the water is at a point; 0 on dry ground.
static func depth_m(at: Vector2) -> float:
	if _levels.is_empty() and _film.is_empty():
		return 0.0
	var top_m: float = level_m(at)
	return maxf(top_m - Terrain.height(at, _dug), 0.0) if top_m > -INF else 0.0


## Whether a rover wades here, as it does in the ford, for any water it would notice.
static func is_wading(at: Vector2) -> bool:
	return depth_m(at) >= WADE_MIN_M


## Whether water here stops a rover: as deep as the ford's is when it does.
static func is_deep(at: Vector2) -> bool:
	return depth_m(at) >= Terrain.WASH_BLOCK_M


## The boxes that stop a rover: runs along x, merged. `block_levels` has each one's
## water level.
static func blocks() -> Array[Rect2]:
	return _blocks


static func block_levels() -> Array[float]:
	return _block_levels


## How far a point is from the deep blocks; 0 inside one, and INF with none.
static func gap_m(at: Vector2) -> float:
	var gap: float = INF
	for block: Rect2 in _blocks:
		gap = minf(gap, at.distance_to(at.clamp(block.position, block.end)))
	return gap


## Whether any of these blocks touches a box of `half` (across, along) at `at`, its
## front toward `ahead`.
static func box_hits(boxes: Array[Rect2], at: Vector2, ahead: Vector2, half: Vector2) -> bool:
	var along: Vector2 = ahead.normalized()
	var across := Vector2(-along.y, along.x)
	var reach := Vector2(
		half.y * absf(along.x) + half.x * absf(across.x), half.y * absf(along.y) + half.x * absf(across.y)
	)
	for block: Rect2 in boxes:
		var gap: Vector2 = at - block.get_center()
		var block_half: Vector2 = block.size * 0.5
		if absf(gap.x) > block_half.x + reach.x or absf(gap.y) > block_half.y + reach.y:
			continue
		if absf(gap.dot(along)) > block_half.x * absf(along.x) + block_half.y * absf(along.y) + half.y:
			continue
		if absf(gap.dot(across)) > block_half.x * absf(across.x) + block_half.y * absf(across.y) + half.x:
			continue
		return true
	return false


# --- Working it out ----------------------------------------------------------

## A cell's steps, but nothing by the ford, as in the ground.
static func _steps(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> int:
	var steps: int = dug.get(cell, 0)
	return 0 if steps > 0 and Terrain.is_near_water(cell) else steps


## A cell's middle is a whole meter, so the ground there is a point of the ground.
static func _middle_point(cell: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return cell * Terrain.CELL_M + Vector2i.ONE * (Terrain.CELL_M / 2)


## The ground at a cell's middle, which is the cell's own depth.
static func _ground_m(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> float:
	if not _ground_cache.has(cell):
		_ground_cache[cell] = Terrain.point_height(_middle_point(cell), dug)
	return _ground_cache[cell]


static func _natural_m(cell: Vector2i) -> float:
	if not _natural_cache.has(cell):
		_natural_cache[cell] = Terrain.natural(_middle_point(cell))
	return _natural_cache[cell]


## The cells touching `cell`, and the cells touching those, all dug SEEP_STEPS or more.
static func _body(start: Vector2i, dug: Dictionary[Vector2i, int], seen: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var body: Dictionary[Vector2i, bool] = {}
	var todo: Array[Vector2i] = [start]
	seen[start] = true
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		body[cell] = true
		for next: Vector2i in Terrain.neighbors(cell):
			if not seen.has(next) and _steps(next, dug) >= SEEP_STEPS:
				seen[next] = true
				todo.append(next)
	return body


## The lowest ground, at a cell's middle, among the cells touching `cells` but not in them.
static func _rim_m(cells: Dictionary[Vector2i, bool], dug: Dictionary[Vector2i, int]) -> float:
	var rim: float = INF
	for cell: Vector2i in cells:
		for next: Vector2i in Terrain.neighbors(cell):
			if not cells.has(next):
				rim = minf(rim, _ground_m(next, dug))
	return rim


## Channel cells joined side to side.
static func _networks(pieces: Dictionary[Vector2i, int]) -> Array[Array]:
	var nets: Array[Array] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for start: Vector2i in StonePieces.channel_cells(pieces):
		if seen.has(start):
			continue
		var net: Array[Vector2i] = []
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var cell: Vector2i = todo.pop_back()
			net.append(cell)
			for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + side
				if not seen.has(next) and pieces.get(next, -1) == StonePieces.CHANNEL:
					seen[next] = true
					todo.append(next)
		nets.append(net)
	return nets


## Whether a channel runs in or beside a wet pit.
static func _is_fed(net: Array[Vector2i], pits: Dictionary[Vector2i, float]) -> bool:
	for cell: Vector2i in net:
		if pits.has(cell):
			return true
		for next: Vector2i in Terrain.neighbors(cell):
			if pits.has(next):
				return true
	return false


## A one step dimple (exactly one step: a deeper one is a pit's business) beside a
## fed channel, lower than the channel, fills to its own rim, which the channel's own
## ground is part of.
static func _fill_dimple(
	cell: Vector2i, from: Vector2i, dug: Dictionary[Vector2i, int], pits: Dictionary[Vector2i, float],
	pieces: Dictionary[Vector2i, int], wet: Dictionary[Vector2i, float]
) -> void:
	if _steps(cell, dug) != 1 or pits.has(cell) or wet.has(cell) or pieces.get(cell, -1) == StonePieces.CHANNEL:
		return
	var floor_m: float = _ground_m(cell, dug)
	if floor_m >= _ground_m(from, dug) - MIN_DEPTH_M:
		return
	var alone: Dictionary[Vector2i, bool] = { cell: true }
	var level: float = _rim_m(alone, dug)
	if level > floor_m + MIN_DEPTH_M:
		wet[cell] = level


## The deep blocks, as the ford's: a block stands where its middle or a corner is deep.
## Depth is found once for each point of a quarter meter lattice, as a block's
## corners, middle and sides are shared with the blocks beside it.
static func _work_out_blocks() -> void:
	_blocks.clear()
	_block_levels.clear()
	_point_cache.clear()
	var step: float = Ford.BLOCK_M
	var per_cell: int = roundi(Terrain.CELL_M / step)
	var tops: Dictionary[Vector2i, float] = {}
	var found: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in _levels:
		if _levels[cell] - _lowest_point_m(cell) < Terrain.WASH_BLOCK_M:
			continue
		for bx: int in per_cell:
			for bz: int in per_cell:
				var block: Vector2i = cell * per_cell + Vector2i(bx, bz)
				var top_m: float = -INF
				for dx: int in 3:
					for dz: int in 3:
						top_m = maxf(top_m, _deep_top_m(block * 2 + Vector2i(dx, dz), tops))
				if top_m > -INF:
					found[block] = top_m
	_point_cache.clear()
	var order: Array[Vector2i] = found.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var at_run: int = 0
	while at_run < order.size():
		var first: Vector2i = order[at_run]
		var run: int = 1
		while at_run + run < order.size() and order[at_run + run] == first + Vector2i(run, 0) and is_equal_approx(found[order[at_run + run]], found[first]):
			run += 1
		_blocks.append(Rect2(Vector2(first) * step, Vector2(run * step, step)))
		_block_levels.append(found[first])
		at_run += run


## The water's top at a point of the quarter meter lattice if it is deep there, else
## -INF. The ground is as Terrain.height finds it, from points found once.
static func _deep_top_m(lattice: Vector2i, tops: Dictionary[Vector2i, float]) -> float:
	if tops.has(lattice):
		return tops[lattice]
	var at: Vector2 = Vector2(lattice) * (Ford.BLOCK_M * 0.5)
	var top_m: float = level_m(at)
	var found: float = -INF
	if top_m > -INF and top_m - _height_m(at) >= Terrain.WASH_BLOCK_M:
		found = top_m
	tops[lattice] = found
	return found


## Terrain.height at a point, from ground found once for each whole meter.
static func _height_m(at: Vector2) -> float:
	var inside: Vector2 = at.clampf(-Terrain.HALF_M, Terrain.HALF_M)
	var low: Vector2i = Vector2i(inside.floor()).mini(Terrain.HALF_M - 1)
	var t: Vector2 = inside - Vector2(low)
	var near: float = lerpf(_point_m(low), _point_m(low + Vector2i(1, 0)), t.x)
	var far: float = lerpf(_point_m(low + Vector2i(0, 1)), _point_m(low + Vector2i.ONE), t.x)
	return lerpf(near, far, t.y)


static func _point_m(point: Vector2i) -> float:
	if not _point_cache.has(point):
		_point_cache[point] = Terrain.point_height(point, _dug)
	return _point_cache[point]


static func _lowest_point_m(cell: Vector2i) -> float:
	var low: float = INF
	for x: int in Terrain.CELL_M + 1:
		for z: int in Terrain.CELL_M + 1:
			low = minf(low, _point_m(cell * Terrain.CELL_M + Vector2i(x, z)))
	return low
