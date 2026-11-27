class_name DigOutline
extends MeshInstance3D
## A line around the cell a dig would act on (the rover's dig_target(), the cell the
## dig command digs). Teal when pressing dig would work, amber when it would be
## refused (the rover's dig_problem(), the host's own rule). Hidden only when no dig
## can be aimed: no rover on the farm's ground, away, or the player out on foot.

enum State { HIDDEN, DIGGABLE, BLOCKED }

## How far above the ground, and how wide [PLACEHOLDER].
const LIFT_M: float = 0.06
const WIDTH_M: float = 0.08

@export var rover: RoverController

var _cell := Vector2i.MAX
var _state: int = State.HIDDEN
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


## What the outline shows for this rover now. Also what the tests ask.
static func state_of(of_rover: RoverController) -> int:
	if of_rover == null or not of_rover.can_aim_dig():
		return State.HIDDEN
	return State.DIGGABLE if of_rover.dig_problem() == "" else State.BLOCKED


static func color_of(state: int) -> Color:
	return ScopeTheme.TEAL if state == State.DIGGABLE else ScopeTheme.AMBER


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = color_of(State.DIGGABLE)
	GameState.terrain_changed.connect(_forget)


func _process(_delta: float) -> void:
	var state: int = state_of(rover)
	visible = state != State.HIDDEN
	if not visible:
		return
	if state != _state:
		_state = state
		_material.albedo_color = color_of(state)
	var cell: Vector2i = rover.dig_target()
	if cell != _cell:
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
