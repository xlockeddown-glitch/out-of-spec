class_name PitWater
extends RefCounted
## Where dug pits hold water, worked out from what is known: the dug steps, the stone
## pieces and the land. Nothing of it is saved or sent, and there is no chance in it,
## so every PC finds the same water.
##
## The ground seeps. A pit two steps deep or more, and every such pit touching it,
## fills to the water table, but never above the lowest ground round it. A channel
## laid next to such a pit carries a thin film along its length, and one step
## dimples it runs into that lie lower fill to their own rims.

## A cell this many steps down reaches the water [PLACEHOLDER].
const SEEP_STEPS: int = 2
## The table lies this far under the lowest natural ground in a pit [PLACEHOLDER].
const TABLE_M: float = 0.5
## A channel's film is this deep over the channel's floor [PLACEHOLDER].
const FILM_M: float = 0.08
## A rover wades from this depth, so a film does not slow it [PLACEHOLDER].
const WADE_MIN_M: float = 0.1
## Water this shallow is no water at all.
const MIN_DEPTH_M: float = 0.02

## Wet cells and the level of the water in each.
static var _levels: Dictionary[Vector2i, float] = {}
## Cells where a channel carries its film.
static var _film: Dictionary[Vector2i, bool] = {}
static var _dug: Dictionary[Vector2i, int] = {}
## The deep boxes, each a run along x, and the water level at each.
static var _blocks: Array[Rect2] = []
static var _block_levels: Array[float] = []


## The water for these steps and pieces: { levels: cell -> level, film: cell -> true }.
static func work_out(dug: Dictionary[Vector2i, int], pieces: Dictionary[Vector2i, int]) -> Dictionary:
	var levels: Dictionary[Vector2i, float] = {}
	var seen: Dictionary[Vector2i, bool] = {}
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
				levels[member] = level
	var film: Dictionary[Vector2i, bool] = {}
	var pits: Dictionary[Vector2i, float] = levels.duplicate()
	for net: Array[Vector2i] in _networks(pieces):
		if not _is_fed(net, pits):
			continue
		for cell: Vector2i in net:
			if not pits.has(cell):
				film[cell] = true
		for cell: Vector2i in net:
			for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_fill_dimple(cell + side, cell, dug, pits, pieces, levels)
	return { "levels": levels, "film": film }


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


# --- Working it out ----------------------------------------------------------

## A cell's steps, but nothing by the ford, as in the ground.
static func _steps(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> int:
	var steps: int = dug.get(cell, 0)
	return 0 if steps > 0 and Terrain.is_near_water(cell) else steps


static func _middle(cell: Vector2i) -> Vector2:
	return Vector2(cell * Terrain.CELL_M) + Vector2.ONE * (Terrain.CELL_M * 0.5)


## The ground at a cell's middle, which is the cell's own depth.
static func _ground_m(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> float:
	return Terrain.height(_middle(cell), dug)


static func _natural_m(cell: Vector2i) -> float:
	var none: Dictionary[Vector2i, int] = {}
	return Terrain.height(_middle(cell), none)


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


## A one step dimple beside a fed channel, lower than the channel, fills to its own
## rim, which the channel's own ground is part of.
static func _fill_dimple(
	cell: Vector2i, from: Vector2i, dug: Dictionary[Vector2i, int], pits: Dictionary[Vector2i, float],
	pieces: Dictionary[Vector2i, int], levels: Dictionary[Vector2i, float]
) -> void:
	if _steps(cell, dug) < 1 or pits.has(cell) or levels.has(cell) or pieces.get(cell, -1) == StonePieces.CHANNEL:
		return
	var floor_m: float = _ground_m(cell, dug)
	if floor_m >= _ground_m(from, dug) - MIN_DEPTH_M:
		return
	var alone: Dictionary[Vector2i, bool] = { cell: true }
	var level: float = _rim_m(alone, dug)
	if level > floor_m + MIN_DEPTH_M:
		levels[cell] = level


## The deep blocks, as the ford's: a block stands where its middle or a corner is deep.
static func _work_out_blocks() -> void:
	_blocks.clear()
	_block_levels.clear()
	var step: float = Ford.BLOCK_M
	var per_cell: int = roundi(Terrain.CELL_M / step)
	var found: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in _levels:
		if _levels[cell] - _lowest_point_m(cell) < Terrain.WASH_BLOCK_M:
			continue
		for i: int in per_cell:
			for j: int in per_cell:
				var block: Vector2i = cell * per_cell + Vector2i(i, j)
				var top_m: float = -INF
				for dx: float in [0.0, 0.5, 1.0]:
					for dz: float in [0.0, 0.5, 1.0]:
						var at: Vector2 = (Vector2(block) + Vector2(dx, dz)) * step
						if is_deep(at):
							top_m = maxf(top_m, level_m(at))
				if top_m > -INF:
					found[block] = top_m
	var order: Array[Vector2i] = found.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var i: int = 0
	while i < order.size():
		var first: Vector2i = order[i]
		var run: int = 1
		while i + run < order.size() and order[i + run] == first + Vector2i(run, 0) and is_equal_approx(found[order[i + run]], found[first]):
			run += 1
		_blocks.append(Rect2(Vector2(first) * step, Vector2(run * step, step)))
		_block_levels.append(found[first])
		i += run


static func _lowest_point_m(cell: Vector2i) -> float:
	var low: float = INF
	for x: int in Terrain.CELL_M + 1:
		for z: int in Terrain.CELL_M + 1:
			low = minf(low, Terrain.point_height(cell * Terrain.CELL_M + Vector2i(x, z), _dug))
	return low
