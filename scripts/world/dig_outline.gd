class_name DigOutline
extends MeshInstance3D
## A teal line around the cell a standing rover would dig or fill.

const COLOR := Color("#38e1c6")
## How far above the ground, and how wide [PLACEHOLDER].
const LIFT_M: float = 0.06
const WIDTH_M: float = 0.08

@export var rover: RoverController

var _cell := Vector2i.MAX
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = COLOR
	GameState.terrain_changed.connect(_forget)


func _process(_delta: float) -> void:
	var cell: Vector2i = rover.dig_cell()
	visible = rover.is_stopped() and Terrain.can_dig(cell) and not HillDressing.is_at_rock(cell)
	if visible and cell != _cell:
		_cell = cell
		_draw()


func _forget() -> void:
	_cell = Vector2i.MAX


## Follows the ground, which has a point each meter.
func _draw() -> void:
	var size: int = Terrain.CELL_M
	var corners: Array[Vector2i] = [Vector2i.ZERO, Vector2i(size, 0), Vector2i(size, size), Vector2i(0, size)]
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for side: int in 4:
		var along: Vector2i = (corners[(side + 1) % 4] - corners[side]) / size
		var inward: Vector2 = Vector2(-along.y, along.x) * WIDTH_M
		for step: int in size:
			var from := Vector2(_cell * size + corners[side] + along * step)
			var to: Vector2 = from + Vector2(along)
			for point: Vector2 in [from, to, from + inward, to, to + inward, from + inward]:
				_mesh.surface_add_vertex(Vector3(point.x, Terrain.height(point, GameState.dug) + LIFT_M, point.y))
	_mesh.surface_end()
