class_name SurveyLine
extends MeshInstance3D
## A teal line on the ground along the last survey's reading, for a while. Only
## on this screen.

const COLOR := Color("#38e1c6")
## How far above the ground (clear of the soil tiles), how wide, and how long it stays [PLACEHOLDER].
const LIFT_M: float = 0.16
const WIDTH_M: float = 0.16
const SHOWN_S: float = 20.0
const STEP_M: float = 0.5

var _from: Vector2
var _way: Vector2
var _left_s: float = 0.0
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	mesh = _mesh
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = COLOR
	GameState.terrain_changed.connect(_draw)


func _process(delta: float) -> void:
	_left_s -= delta
	visible = _left_s > 0.0


## Shows the whole range, so its length tells nothing.
func show_bearing(from: Vector2, bearing: float) -> void:
	_from = from
	_way = OrePocket.way(bearing)
	_left_s = SHOWN_S
	_draw()


func forget() -> void:
	_left_s = 0.0


func _draw() -> void:
	if _left_s <= 0.0:
		return
	var side: Vector2 = _way.orthogonal() * WIDTH_M * 0.5
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
	for step: int in roundi(OrePocket.RANGE_M / STEP_M) + 1:
		var middle: Vector2 = _from + _way * STEP_M * step
		for point: Vector2 in [middle - side, middle + side]:
			_mesh.surface_add_vertex(Vector3(point.x, Terrain.height(point, GameState.dug) + LIFT_M, point.y))
	_mesh.surface_end()
