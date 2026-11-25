class_name PitWaterView
extends Node3D
## Draws PitWater: a VoxelWater for each stretch of wet cells, and the boxes that
## stop a rover in deep water. It works the water out again only when the dug ground
## or the channels are not as they were last time (a boulder, a wall or a pad changes
## neither), once a frame however many changes came, and it only redraws the
## stretches that differ.

## Said when the deep water is not where it was, so a rover in it can be moved.
signal changed

## Each stretch, by what it was drawn from.
var _stretches: Dictionary[int, VoxelWater] = {}
var _deep: Node3D = null
## The deep water the boxes were last built for.
var _built: Array[Rect2] = []
var _built_levels: Array[float] = []
## What the water was last worked out from: the dug steps and the channel cells.
var _seen_dug: Dictionary[Vector2i, int] = {}
var _seen_channels: Dictionary[Vector2i, bool] = {}
var _worked: bool = false
var _asked: bool = false
## How often the water was worked out, and how often a look was put off to the end of
## the frame, for the tests.
var worked_count: int = 0
var queued_count: int = 0


func _ready() -> void:
	_deep = Node3D.new()
	_deep.name = "Deep"
	add_child(_deep)
	GameState.terrain_changed.connect(_ask)
	GameState.stone_changed.connect(_ask)
	# At once, so the water is there before the first physics step of a loaded farm.
	_refresh()


func _exit_tree() -> void:
	PitWater.clear()


## Asks for the water to be looked at again, once, at the end of this frame.
func _ask() -> void:
	if not _asked:
		_asked = true
		queued_count += 1
		_refresh_asked.call_deferred()


func _refresh_asked() -> void:
	_asked = false
	if is_inside_tree():
		_refresh()


## Works the water out again, if what it comes from changed, and draws what is new.
func _refresh() -> void:
	var channels: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in StonePieces.channel_cells(GameState.stone_pieces):
		channels[cell] = true
	if _worked and GameState.dug == _seen_dug and channels == _seen_channels:
		return
	_worked = true
	worked_count += 1
	_seen_dug = GameState.dug.duplicate()
	_seen_channels = channels
	PitWater.use(PitWater.work_out(GameState.dug, GameState.stone_pieces), GameState.dug)
	var keep: Dictionary[int, bool] = {}
	for stretch: Array[Vector2i] in _stretches_of(PitWater.levels(), PitWater.film()):
		var key: int = _signature(stretch)
		keep[key] = true
		if not _stretches.has(key):
			_stretches[key] = _draw(stretch)
	for key: int in _stretches.keys():
		if not keep.has(key):
			remove_child(_stretches[key])
			_stretches[key].queue_free()
			_stretches.erase(key)
	if _built != PitWater.blocks() or _built_levels != PitWater.block_levels():
		_built = PitWater.blocks().duplicate()
		_built_levels = PitWater.block_levels().duplicate()
		_build_blocks()
		changed.emit()


## Wet cells that touch, with the film's.
static func _stretches_of(levels: Dictionary[Vector2i, float], film: Dictionary[Vector2i, bool]) -> Array[Array]:
	var stretches: Array[Array] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var wet: Array[Vector2i] = levels.keys()
	wet.append_array(film.keys())
	for start: Vector2i in wet:
		if seen.has(start):
			continue
		var stretch: Array[Vector2i] = []
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var cell: Vector2i = todo.pop_back()
			stretch.append(cell)
			for next: Vector2i in Terrain.neighbors(cell):
				if not seen.has(next) and (levels.has(next) or film.has(next)):
					seen[next] = true
					todo.append(next)
		stretches.append(stretch)
	return stretches


## What a stretch looks like depends on its cells, their levels, and the digging in
## and round them.
static func _signature(stretch: Array[Vector2i]) -> int:
	var sorted: Array[Vector2i] = stretch.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var parts: Array = []
	var around: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in sorted:
		parts.append(cell)
		parts.append(snappedf(PitWater.levels()[cell], 0.001) if PitWater.levels().has(cell) else -1.0)
		around[cell] = true
		for next: Vector2i in Terrain.neighbors(cell):
			around[next] = true
	var steps: Array[Vector2i] = around.keys()
	steps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for cell: Vector2i in steps:
		parts.append(GameState.dug.get(cell, 0))
	return parts.hash()


func _draw(stretch: Array[Vector2i]) -> VoxelWater:
	var low: Vector2i = stretch[0]
	var high: Vector2i = stretch[0]
	for cell: Vector2i in stretch:
		low = low.min(cell)
		high = high.max(cell)
	var water := VoxelWater.new()
	water.name = "Water_%d_%d" % [low.x, low.y]
	var members: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in stretch:
		members[cell] = true
	# Water that is not of this stretch is drawn by its own, not twice and not stale.
	water.fill_levels(
		Rect2(Vector2(low * Terrain.CELL_M), Vector2(high - low + Vector2i.ONE) * Terrain.CELL_M),
		func(at: Vector2) -> float: return PitWater.level_m(at) if members.has(Terrain.cell_at(at)) else -INF,
		func(at: Vector2) -> float: return Terrain.height(at, GameState.dug)
	)
	add_child(water)
	return water


## One box for each of PitWater's runs, set as the ford's are.
func _build_blocks() -> void:
	for old: Node in _deep.get_children():
		_deep.remove_child(old)
		old.queue_free()
	var height_m: float = Ford.BLOCK_BELOW_M + Ford.BLOCK_ABOVE_M
	for i: int in PitWater.blocks().size():
		var run: Rect2 = PitWater.blocks()[i]
		var shape := BoxShape3D.new()
		shape.size = Vector3(run.size.x, height_m, run.size.y)
		var holder := CollisionShape3D.new()
		holder.shape = shape
		var body := StaticBody3D.new()
		body.name = "Deep"
		body.collision_layer = Ford.LAYER_WORLD
		body.collision_mask = 0
		var middle: Vector2 = run.get_center()
		body.position = Vector3(middle.x, PitWater.block_levels()[i] + (Ford.BLOCK_ABOVE_M - Ford.BLOCK_BELOW_M) * 0.5, middle.y)
		body.add_child(holder)
		_deep.add_child(body, true)
