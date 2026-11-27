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


func _ready() -> void:
	# The rover looks for the ground under it before the scene shows what was dug.
	assert((2 * half_m) % CHUNK_M == 0, "half_m must make whole chunks")
	_dug = GameState.dug.duplicate()
	_levelled = Terrain.level_points.duplicate()
	_heights.resize((2 * half_m + 1) * (2 * half_m + 1))
	_tints.resize(_heights.size())
	for z: int in range(-half_m, half_m + 1):
		for x: int in range(-half_m, half_m + 1):
			if half_m == Terrain.HALF_M:
				_heights[_index(x, z)] = Terrain.point_height(Vector2i(x, z), _dug)
				_tints[_index(x, z)] = _tint(Terrain.natural(Vector2i(x, z)))
			else:
				var natural_m: float = Terrain.natural_on(Vector2i(x, z), half_m)
				_heights[_index(x, z)] = natural_m
				_tints[_index(x, z)] = _tint(natural_m)
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
	for x: int in range(chunk.x, chunk.x + side):
		for z: int in range(chunk.y, chunk.y + side):
			points.append(_point(x, z))
			normals.append(_normal(x, z))
			tints.append(_tints[_index(x, z)])
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
