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

var _dug: Dictionary[Vector2i, int] = {}
var _chunks: Dictionary[Vector2i, MeshInstance3D] = {}
var _shape := HeightMapShape3D.new()
## The ground at every point, row by row along z.
var _heights := PackedFloat32Array()
## The natural land's tint at every point, in the same order.
var _tints := PackedColorArray()


func _ready() -> void:
	# The rover looks for the ground under it before the scene shows what was dug.
	_dug = GameState.dug.duplicate()
	_heights.resize((Terrain.SIZE_M + 1) * (Terrain.SIZE_M + 1))
	_tints.resize(_heights.size())
	for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			_heights[_index(x, z)] = Terrain.point_height(Vector2i(x, z), _dug)
			_tints[_index(x, z)] = _tint(Terrain.natural(Vector2i(x, z)))
	_shape.map_width = Terrain.SIZE_M + 1
	_shape.map_depth = Terrain.SIZE_M + 1
	_shape.map_data = _heights
	var collision := CollisionShape3D.new()
	collision.shape = _shape
	add_child(collision)
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M, CHUNK_M):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M, CHUNK_M):
			var chunk := MeshInstance3D.new()
			chunk.material_override = material
			add_child(chunk)
			_chunks[Vector2i(x, z)] = chunk
			_build(Vector2i(x, z))


## Shows this digging (cell -> steps deep) instead of what was shown.
func show_dug(dug: Dictionary[Vector2i, int]) -> void:
	var changed: Array[Vector2i] = []
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
				if absi(x) > Terrain.HALF_M or absi(z) > Terrain.HALF_M:
					continue
				_heights[_index(x, z)] = Terrain.point_height(Vector2i(x, z), _dug)
				# A point on a square's edge is in the squares on both sides.
				for dx: int in 2:
					for dz: int in 2:
						rebuild[_chunk_of(Vector2i(x - dx, z - dz))] = true
	_shape.map_data = _heights
	for chunk: Vector2i in rebuild:
		if _chunks.has(chunk):
			_build(chunk)


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
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	for x: int in range(chunk.x, chunk.x + CHUNK_M):
		for z: int in range(chunk.y, chunk.y + CHUNK_M):
			_add_face(points, normals, [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1)])
			_add_face(points, normals, [Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)])
			for corner: int in [_index(x, z), _index(x + 1, z), _index(x, z + 1), _index(x + 1, z), _index(x + 1, z + 1), _index(x, z + 1)]:
				tints.append(_tints[corner])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_chunks[chunk].mesh = mesh


## Corners run clockwise from above. Each takes the slope of the land around it,
## not of its own face, so a slope is not shaded in zigzags where the squares'
## diagonals alternate.
func _add_face(points: PackedVector3Array, normals: PackedVector3Array, corners: Array[Vector2i]) -> void:
	for corner: Vector2i in corners:
		points.append(_point(corner.x, corner.y))
		normals.append(_normal(corner.x, corner.y))


func _normal(x: int, z: int) -> Vector3:
	var limit: int = Terrain.HALF_M
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
	return (z + Terrain.HALF_M) * (Terrain.SIZE_M + 1) + x + Terrain.HALF_M


func _chunk_of(point: Vector2i) -> Vector2i:
	return Vector2i((Vector2(point) / CHUNK_M).floor()) * CHUNK_M
