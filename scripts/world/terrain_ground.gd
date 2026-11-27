class_name TerrainGround
extends StaticBody3D
## Terrain as something to see and drive on. It has a mesh for each square of
## land, so a dig rebuilds only what it touched.

const CHUNK_M: int = 16
## What the ground's color is times on the highest land and in the lowest, so
## hills read from above. Level ground keeps its color [PLACEHOLDER].
const HIGH_TINT := Color(1.0, 0.82, 0.6)
const LOW_TINT := Color(0.7, 0.8, 0.8)
const HIGH_M: float = 6.0
const LOW_M: float = -1.0
## How far the real ground leans toward its biome's ground_tint, 0 (none) to 1 (all)
## [PLACEHOLDER]. It multiplies the height tint, so hills still read and a white
## ground_tint (the farm) changes nothing.
const BIOME_STRENGTH: float = 0.5
## The biome colour is looked up every BIOME_STEP_M metres and averaged over the
## neighbouring BIOME_BLUR cells each way, then smoothed between, so a biome edge
## fades over about 2 * (BIOME_BLUR + 1) * BIOME_STEP_M metres [PLACEHOLDER].
const BIOME_STEP_M: int = 4
const BIOME_BLUR: int = 1
## A road's paint (BiomeData road lines): the tint leans this far toward ROAD_TINT
## inside the strip, 0 to 1, fading over BiomeData.ROAD_EDGE_M [PLACEHOLDER]. A
## vertex colour is 8 bits, 0 to 1, and multiplies the ground's dark base, so the
## road can not be brighter than white: it is a dusty warm trail, paler than the
## dark grounds (the Basalt Ridge) and warmer than the pale ones.
const ROAD_TINT := Color(1.0, 0.72, 0.5)
const ROAD_STRENGTH: float = 0.6

@export var material: Material
## How far the land reaches from its middle. Only LandMeasure sets it, before the
## ground is added, to build a bigger land than play has: 2 * half_m must be a
## multiple of CHUNK_M, and show_dug (digging) is for play's size only.
var half_m: int = Terrain.HALF_M

var _dug: Dictionary[Vector2i, int] = {}
## The pads' level points shown (Terrain.level_points).
var _levelled: Dictionary[Vector2i, float] = {}
var _chunks: Dictionary[Vector2i, MeshInstance3D] = {}
var _shape := HeightMapShape3D.new()
## The ground at every point, row by row along z.
var _heights := PackedFloat32Array()
## The natural land's tint at every point, in the same order.
var _tints := PackedColorArray()
## One chunk's triangles by index, built on first use and shared.
static var _faces := PackedInt32Array()
## Debug overlay (F8, debug builds): the ground coloured by biome instead of by height
## [PLACEHOLDER: replaces the height tint; multiplying would keep the hills visible
## but muddy the colours]. Off every launch, never saved or sent.
var _biome_view: bool = false
## Each point's biome colour, worked out on the first show and kept.
var _biome_tints := PackedColorArray()
var _biome_note: CanvasLayer


func _ready() -> void:
	# The rover looks for the ground under it before the scene shows what was dug.
	assert((2 * half_m) % CHUNK_M == 0, "half_m must make whole chunks")
	_dug = GameState.dug.duplicate()
	_levelled = Terrain.level_points.duplicate()
	_heights.resize((2 * half_m + 1) * (2 * half_m + 1))
	_tints.resize(_heights.size())
	var lean := PackedColorArray()
	if half_m == Terrain.HALF_M:
		lean = _biome_lean()
	for z: int in range(-half_m, half_m + 1):
		for x: int in range(-half_m, half_m + 1):
			if half_m == Terrain.HALF_M:
				_heights[_index(x, z)] = Terrain.point_height(Vector2i(x, z), _dug)
				_tints[_index(x, z)] = _tint(Terrain.natural(Vector2i(x, z))) * lean[_index(x, z)]
			else:
				var natural_m: float = Terrain.natural_on(Vector2i(x, z), half_m)
				_heights[_index(x, z)] = natural_m
				_tints[_index(x, z)] = _tint(natural_m)
	if half_m == Terrain.HALF_M:
		_paint_roads()
	_shape.map_width = 2 * half_m + 1
	_shape.map_depth = 2 * half_m + 1
	_shape.map_data = _heights
	var collision := CollisionShape3D.new()
	collision.shape = _shape
	add_child(collision)
	for x: int in range(-half_m, half_m, CHUNK_M):
		for z: int in range(-half_m, half_m, CHUNK_M):
			var chunk := MeshInstance3D.new()
			chunk.material_override = material
			add_child(chunk)
			_chunks[Vector2i(x, z)] = chunk
			_build(Vector2i(x, z))


## Mixes the road colour into the tint of every point within a road's strip and its
## soft edge. Only the points near each road line are visited. Paint only: no height.
func _paint_roads() -> void:
	var weights: Dictionary[int, float] = {}
	var reach: float = BiomeData.ROAD_HALF_M + BiomeData.ROAD_EDGE_M
	for id: StringName in BiomeData.ids():
		var line: Array[Vector2] = BiomeData.road(id)
		for i: int in range(line.size() - 1):
			var low: Vector2 = line[i].min(line[i + 1]) - Vector2(reach, reach)
			var high: Vector2 = line[i].max(line[i + 1]) + Vector2(reach, reach)
			for z: int in range(maxi(floori(low.y), -half_m), mini(ceili(high.y), half_m) + 1):
				for x: int in range(maxi(floori(low.x), -half_m), mini(ceili(high.x), half_m) + 1):
					var weight: float = BiomeData.road_weight(BiomeData.segment_gap(Vector2(x, z), line[i], line[i + 1]))
					var index: int = _index(x, z)
					if weight > weights.get(index, 0.0):
						weights[index] = weight
	for index: int in weights:
		_tints[index] = _tints[index].lerp(ROAD_TINT, ROAD_STRENGTH * weights[index])


## Paints the ground by biome (true) or restores its own tints (false), a debug view.
## Heights, collision and digging are untouched. Only play's size has biomes.
func show_biomes(on: bool) -> void:
	if on == _biome_view or half_m != Terrain.HALF_M:
		return
	_biome_view = on
	if on and _biome_tints.is_empty():
		_biome_tints.resize(_tints.size())
		var by_id: Dictionary[StringName, Color] = {}
		for z: int in range(-half_m, half_m + 1):
			for x: int in range(-half_m, half_m + 1):
				var id: StringName = BiomeData.biome_at(Vector2(x, z))
				if not by_id.has(id):
					by_id[id] = BiomeData.tint(id)
				_biome_tints[_index(x, z)] = by_id[id]
	for chunk: Vector2i in _chunks:
		_build(chunk)
	if on and _biome_note == null:
		_biome_note = CanvasLayer.new()
		var label := Label.new()
		label.text = "Biome map (F8)"
		label.position = Vector2(8, 8)
		_biome_note.add_child(label)
		add_child(_biome_note)
	if _biome_note != null:
		_biome_note.visible = on


func is_showing_biomes() -> bool:
	return _biome_view


## Shows this digging (cell -> steps deep) and the pads' level ground (Terrain)
## instead of what was shown.
func show_dug(dug: Dictionary[Vector2i, int]) -> void:
	var changed: Array[Vector2i] = []
	# A pad's cell has all its points changed; its edge's are in the cell too.
	for point: Vector2i in _levelled:
		if Terrain.level_points.get(point, INF) != _levelled[point]:
			changed.append(_cell_of_point(point))
	for point: Vector2i in Terrain.level_points:
		if not _levelled.has(point):
			changed.append(_cell_of_point(point))
	_levelled = Terrain.level_points.duplicate()
	for cell: Vector2i in dug:
		if _dug.get(cell, 0) != dug[cell]:
			changed.append(cell)
	for cell: Vector2i in _dug:
		if not dug.has(cell):
			changed.append(cell)
	if changed.is_empty():
		return
	_dug = dug.duplicate()
	var rebuild: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in changed:
		var corner: Vector2i = cell * Terrain.CELL_M
		for x: int in range(corner.x, corner.x + Terrain.CELL_M + 1):
			for z: int in range(corner.y, corner.y + Terrain.CELL_M + 1):
				if absi(x) > half_m or absi(z) > half_m:
					continue
				_heights[_index(x, z)] = Terrain.point_height(Vector2i(x, z), _dug)
				# A point's height also sets its neighbors' normals, and a point on a
				# square's edge is in the squares on both sides.
				for dx: int in range(-2, 2):
					for dz: int in range(-2, 2):
						rebuild[_chunk_of(Vector2i(x + dx, z + dz))] = true
	_shape.map_data = _heights
	for chunk: Vector2i in rebuild:
		if _chunks.has(chunk):
			_build(chunk)


## A cell whose corners include `point`, for rebuilding around it.
func _cell_of_point(point: Vector2i) -> Vector2i:
	return Terrain.cell_at(Vector2(point) + Vector2(0.5, 0.5))


func height_at(at: Vector3) -> float:
	return Terrain.height(Vector2(at.x, at.z), _dug)


## The highest ground under a body at `at`.
func highest_under(at: Transform3D, half_length_m: float, half_width_m: float) -> float:
	var highest_m: float = -INF
	for x: int in range(-2, 3):
		for z: int in range(-2, 3):
			highest_m = maxf(highest_m, height_at(at * Vector3(half_width_m * x * 0.5, 0.0, half_length_m * z * 0.5)))
	return highest_m


## How a body at `at` facing `forward` lies on the ground under its wheels.
func lie_at(at: Vector3, forward: Vector3, half_length_m: float, half_width_m: float) -> Basis:
	var ahead := Vector3(forward.x, 0.0, forward.z).normalized()
	var right: Vector3 = ahead.cross(Vector3.UP)
	var along: Vector3 = ahead * half_length_m * 2.0
	along.y = height_at(at + ahead * half_length_m) - height_at(at - ahead * half_length_m)
	var across: Vector3 = right * half_width_m * 2.0
	across.y = height_at(at + right * half_width_m) - height_at(at - right * half_width_m)
	var up: Vector3 = across.cross(along).normalized()
	var back: Vector3 = -along.normalized()
	return Basis(up.cross(back), up, back)


func _build(chunk: Vector2i) -> void:
	# One vertex for each point, shared by the faces around it: a point's slope and
	# tint do not depend on the face, so it looks as before with a sixth of the vertices.
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var side: int = CHUNK_M + 1
	var shown: PackedColorArray = _biome_tints if _biome_view else _tints
	for x: int in range(chunk.x, chunk.x + side):
		for z: int in range(chunk.y, chunk.y + side):
			points.append(_point(x, z))
			normals.append(_normal(x, z))
			tints.append(shown[_index(x, z)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	arrays[Mesh.ARRAY_INDEX] = _chunk_indices()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_chunks[chunk].mesh = mesh


## The triangles of one chunk by its shared points, the same for every chunk, built
## once. Corners run clockwise from above.
func _chunk_indices() -> PackedInt32Array:
	if _faces.is_empty():
		var side: int = CHUNK_M + 1
		for x: int in CHUNK_M:
			for z: int in CHUNK_M:
				var here: int = x * side + z
				_faces.append_array([here, here + side, here + 1, here + side, here + side + 1, here + 1])
	return _faces


func _normal(x: int, z: int) -> Vector3:
	var limit: int = half_m
	var west: float = _heights[_index(maxi(x - 1, -limit), z)]
	var east: float = _heights[_index(mini(x + 1, limit), z)]
	var north: float = _heights[_index(x, maxi(z - 1, -limit))]
	var south: float = _heights[_index(x, mini(z + 1, limit))]
	var run_x: float = float(mini(x + 1, limit) - maxi(x - 1, -limit))
	var run_z: float = float(mini(z + 1, limit) - maxi(z - 1, -limit))
	return Vector3((west - east) / run_x, 1.0, (north - south) / run_z).normalized()


## Each point's biome multiplier for the normal look: the biome ground colours on a
## coarse grid, blurred, then bilinear between. Same data on every machine.
func _biome_lean() -> PackedColorArray:
	var n: int = (2 * half_m) / BIOME_STEP_M + 1
	var by_id: Dictionary[StringName, Color] = {}
	var coarse := PackedColorArray()
	coarse.resize(n * n)
	for j: int in n:
		for i: int in n:
			var id: StringName = BiomeData.biome_at(Vector2(i * BIOME_STEP_M - half_m, j * BIOME_STEP_M - half_m))
			if not by_id.has(id):
				by_id[id] = Color.WHITE.lerp(BiomeData.ground_tint(id), BIOME_STRENGTH)
			coarse[j * n + i] = by_id[id]
	var soft := PackedColorArray()
	soft.resize(n * n)
	for j: int in n:
		for i: int in n:
			var sum := Color(0, 0, 0, 0)
			var count: int = 0
			for dj: int in range(maxi(j - BIOME_BLUR, 0), mini(j + BIOME_BLUR, n - 1) + 1):
				for di: int in range(maxi(i - BIOME_BLUR, 0), mini(i + BIOME_BLUR, n - 1) + 1):
					sum += coarse[dj * n + di]
					count += 1
			soft[j * n + i] = sum / float(count)
	var lean := PackedColorArray()
	lean.resize(_heights.size())
	for z: int in range(-half_m, half_m + 1):
		var fz: float = float(z + half_m) / BIOME_STEP_M
		var j0: int = mini(int(fz), n - 2)
		var tz: float = fz - j0
		for x: int in range(-half_m, half_m + 1):
			var fx: float = float(x + half_m) / BIOME_STEP_M
			var i0: int = mini(int(fx), n - 2)
			var tx: float = fx - i0
			var top: Color = soft[j0 * n + i0].lerp(soft[j0 * n + i0 + 1], tx)
			var bottom: Color = soft[(j0 + 1) * n + i0].lerp(soft[(j0 + 1) * n + i0 + 1], tx)
			lean[_index(x, z)] = top.lerp(bottom, tz)
	return lean


func _tint(natural_m: float) -> Color:
	if natural_m >= 0.0:
		return Color.WHITE.lerp(HIGH_TINT, minf(natural_m / HIGH_M, 1.0))
	return Color.WHITE.lerp(LOW_TINT, minf(natural_m / LOW_M, 1.0))


func _point(x: int, z: int) -> Vector3:
	return Vector3(x, _heights[_index(x, z)], z)


func _index(x: int, z: int) -> int:
	return (z + half_m) * (2 * half_m + 1) + x + half_m


func _chunk_of(point: Vector2i) -> Vector2i:
	# Chunks start at the land's corner, which is not a multiple of CHUNK_M for every size.
	var origin := Vector2i(-half_m, -half_m)
	return Vector2i((Vector2(point - origin) / CHUNK_M).floor()) * CHUNK_M + origin
