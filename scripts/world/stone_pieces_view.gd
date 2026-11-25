class_name StonePiecesView
extends Node3D
## Draws GameState.stone_pieces as boxes that follow the ground: one mesh for each
## piece, and a wall also stops rovers (layer 1) but not the uplink (layer 3).

const STONE := Color("#807a73")
const STONE_DARK := Color("#6b665f")
const BASALT := Color("#232832")
const BASALT_FLOOR := Color("#495261")
## How thick a pad's slabs are, and how high a channel's lips stand [PLACEHOLDER].
const SLAB_M: float = 0.16
const LIP_M: float = 0.3
const LIP_WIDTH_M: float = 0.22

var _pieces: Dictionary[Vector2i, Node3D] = {}
var _shown: Dictionary[Vector2i, int] = {}
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.95
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	GameState.stone_changed.connect(_refresh)
	GameState.terrain_changed.connect(_rebuild)
	_rebuild()


## Draws what changed.
func _refresh() -> void:
	for cell: Vector2i in _pieces.keys():
		if GameState.stone_pieces.get(cell, -1) != _shown.get(cell, -1) or _next_to_channel_change(cell):
			_remove(cell)
	for cell: Vector2i in GameState.stone_pieces:
		if not _pieces.has(cell):
			_add(cell)
	_shown = GameState.stone_pieces.duplicate()


## A channel's lips depend on its neighbors.
func _next_to_channel_change(cell: Vector2i) -> bool:
	if GameState.stone_pieces.get(cell, -1) != StonePieces.CHANNEL:
		return false
	for around: Vector2i in Terrain.neighbors(cell):
		if (GameState.stone_pieces.get(around, -1) == StonePieces.CHANNEL) != (_shown.get(around, -1) == StonePieces.CHANNEL):
			return true
	return false


## Everything again, as the ground under it moved.
func _rebuild() -> void:
	for cell: Vector2i in _pieces.keys():
		_remove(cell)
	_refresh()


func _remove(cell: Vector2i) -> void:
	_pieces[cell].queue_free()
	_pieces.erase(cell)


func _add(cell: Vector2i) -> void:
	var kind: int = GameState.stone_pieces[cell]
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%s_%d_%d" % [StonePieces.kind_name(kind), cell.x, cell.y]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var node: Node3D = mesh_instance
	match kind:
		StonePieces.WALL:
			_wall(tool, cell)
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var box: AABB = StonePieces.wall_box(cell, GameState.dug)
			var shape := CollisionShape3D.new()
			var size := BoxShape3D.new()
			size.size = box.size
			shape.shape = size
			shape.position = box.get_center()
			body.add_child(shape)
			body.add_child(mesh_instance)
			node = body
			body.name = mesh_instance.name
			mesh_instance.name = "Mesh"
		StonePieces.PAD:
			_slabs(tool, cell, 0.03, STONE, STONE_DARK)
		StonePieces.CHANNEL:
			_slabs(tool, cell, -0.02, BASALT, BASALT)
			_lips(tool, cell)
	mesh_instance.mesh = tool.commit()
	mesh_instance.material_override = _material
	_pieces[cell] = node
	add_child(node)


func _ground(point: Vector2i) -> float:
	return Terrain.point_height(point, GameState.dug)


## A tint that differs a little from cell to cell, so a row of them is not flat.
func _tint(color: Color, cell: Vector2i, spread: float = 0.07) -> Color:
	var hash: int = ((cell.x * 73856093) ^ (cell.y * 19349663)) & 0xff
	return color.lightened((hash / 255.0 - 0.5) * spread * 2.0)


func _wall(tool: SurfaceTool, cell: Vector2i) -> void:
	var box: AABB = StonePieces.wall_box(cell, GameState.dug)
	var middle := Vector2(box.get_center().x, box.get_center().z)
	var top: float = box.end.y
	var base_top: float = top - StonePieces.WALL_M * 0.55
	var width: float = box.size.x
	_box(tool, Transform3D(Basis.IDENTITY, Vector3(middle.x, (box.position.y + base_top) / 2.0, middle.y)),
			Vector3(width, base_top - box.position.y, width), _tint(STONE_DARK, cell))
	_box(tool, Transform3D(Basis.IDENTITY, Vector3(middle.x, (base_top + top - 0.12) / 2.0, middle.y)),
			Vector3(width * 0.84, top - 0.12 - base_top, width * 0.84), _tint(STONE, cell))
	_box(tool, Transform3D(Basis.IDENTITY, Vector3(middle.x, top - 0.06, middle.y)),
			Vector3(width * 0.92, 0.12, width * 0.92), _tint(STONE, cell, 0.12))


## Four slabs a meter wide, each tilted to the ground under it. `lift` moves them
## along their own up.
func _slabs(tool: SurfaceTool, cell: Vector2i, lift: float, color: Color, other: Color) -> void:
	var origin: Vector2i = cell * Terrain.CELL_M
	for x: int in 2:
		for z: int in 2:
			var h00: float = _ground(origin + Vector2i(x, z))
			var h10: float = _ground(origin + Vector2i(x + 1, z))
			var h01: float = _ground(origin + Vector2i(x, z + 1))
			var h11: float = _ground(origin + Vector2i(x + 1, z + 1))
			var along_x := Vector3(1.0, ((h10 + h11) - (h00 + h01)) / 2.0, 0.0).normalized()
			var along_z := Vector3(0.0, ((h01 + h11) - (h00 + h10)) / 2.0, 1.0).normalized()
			var up: Vector3 = along_z.cross(along_x).normalized()
			var middle := Vector3(origin.x + x + 0.5, (h00 + h10 + h01 + h11) / 4.0, origin.y + z + 0.5)
			_box(tool, Transform3D(Basis(along_x, up, along_z), middle + up * (lift - SLAB_M / 2.0 + SLAB_M * 0.5)),
					Vector3(0.98, SLAB_M, 0.98), _tint(color if (x + z) % 2 == 0 else other, cell))


## A channel's lips: along each side whose neighbor is no channel.
func _lips(tool: SurfaceTool, cell: Vector2i) -> void:
	var origin: Vector2i = cell * Terrain.CELL_M
	var size: int = Terrain.CELL_M
	for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if GameState.stone_pieces.get(cell + side, -1) == StonePieces.CHANNEL:
			continue
		# The side's line of points, from one corner to the other.
		var along := Vector2i(absi(side.y), absi(side.x))
		var start: Vector2i = origin + Vector2i(size if side.x > 0 else 0, size if side.y > 0 else 0)
		var inward := Vector2(-side)
		for step: int in size:
			var from: Vector2i = start + along * step
			var to: Vector2i = from + along
			var a := Vector3(from.x, _ground(from), from.y)
			var b := Vector3(to.x, _ground(to), to.y)
			var x_axis: Vector3 = (b - a).normalized()
			var z_axis: Vector3 = x_axis.cross(Vector3.UP).normalized()
			if Vector2(z_axis.x, z_axis.z).dot(inward) < 0.0:
				z_axis = -z_axis
			var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
			var at: Vector3 = (a + b) / 2.0 + Vector3(inward.x, 0.0, inward.y) * LIP_WIDTH_M / 2.0
			_box(tool, Transform3D(Basis(x_axis, y_axis, z_axis), at + y_axis * (LIP_M - 0.1) / 2.0),
					Vector3((b - a).length() + 0.02, LIP_M + 0.1, LIP_WIDTH_M), _tint(BASALT_FLOOR, cell))


## Adds a box's six faces, placed by `at`. Drawn from both sides, so a face's
## winding doesn't matter.
func _box(tool: SurfaceTool, at: Transform3D, size: Vector3, color: Color) -> void:
	var half: Vector3 = size / 2.0
	var c: Array[Vector3] = []
	for i: int in 8:
		c.append(at * Vector3(half.x * (1 if i & 1 else -1), half.y * (1 if i & 2 else -1), half.z * (1 if i & 4 else -1)))
	# Each face as corner indices, counterclockwise from outside; Godot wants clockwise.
	for face: Array in [[1, 3, 7, 5], [0, 4, 6, 2], [2, 6, 7, 3], [0, 1, 5, 4], [4, 5, 7, 6], [0, 2, 3, 1]]:
		var normal: Vector3 = ((c[face[0]] + c[face[2]]) / 2.0 - at.origin).normalized()
		for corner: int in [0, 2, 1, 0, 3, 2]:
			tool.set_color(color)
			tool.set_normal(normal)
			tool.add_vertex(c[face[corner]])
