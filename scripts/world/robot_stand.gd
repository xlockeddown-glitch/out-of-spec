class_name RobotStand
extends Node3D
## Displays the farm's utility robots beside Bram's bay as primitive meshes
## with their paint color (Cosmetics.robot_paint_color, ScopeTheme constants
## only) and nameplate (Label3D). Read-only view of GameState.robots.

## [PLACEHOLDER] Primitive dimensions and spacing (meters).
const BODY_SIZE: Vector3 = Vector3(0.65, 0.55, 0.80)
const MAST_SIZE: Vector3 = Vector3(0.18, 0.45, 0.18)
const LED_SIZE: Vector3 = Vector3(0.10, 0.08, 0.10)
const STEP_X: float = 1.25
const GROUP_ROBOT: StringName = &"robot_stand_unit"

## Optional injected farm state for tests; defaults to GameState.
var _farm: Node = null


func _ready() -> void:
	var farm: Node = _state()
	farm.robots_changed.connect(refresh)
	farm.farm_loaded.connect(refresh)
	refresh()


func set_farm(farm: Node) -> void:
	_farm = farm


func _state() -> Node:
	return _farm if _farm != null else GameState


## Rebuilds the robot meshes and nameplates from the farm's current robots.
func refresh() -> void:
	for child: Node in get_children():
		if child.is_in_group(GROUP_ROBOT):
			remove_child(child)
			child.queue_free()
	var farm: Node = _state()
	var ids: Array = farm.robots.keys()
	ids.sort()
	for i: int in ids.size():
		var robot_id: String = str(ids[i])
		var robot: Dictionary = farm.robots[robot_id]
		var unit := Node3D.new()
		unit.name = "Robot_" + robot_id
		unit.position = Vector3(float(i) * STEP_X, 0.0, 0.0)
		unit.add_to_group(GROUP_ROBOT)

		var body := MeshInstance3D.new()
		body.name = "Body"
		var body_box := BoxMesh.new()
		body_box.size = BODY_SIZE
		body.mesh = body_box
		body.position = Vector3(0.0, BODY_SIZE.y / 2.0, 0.0)
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Cosmetics.robot_paint_color(farm.robot_paint(robot_id))
		body_mat.roughness = 0.65
		body.material_override = body_mat
		unit.add_child(body)

		var mast := MeshInstance3D.new()
		mast.name = "Mast"
		var mast_box := BoxMesh.new()
		mast_box.size = MAST_SIZE
		mast.mesh = mast_box
		mast.position = Vector3(0.0, BODY_SIZE.y + MAST_SIZE.y / 2.0, 0.0)
		var mast_mat := StandardMaterial3D.new()
		mast_mat.albedo_color = ScopeTheme.SHADOW
		mast_mat.roughness = 0.8
		mast.material_override = mast_mat
		unit.add_child(mast)

		var led := MeshInstance3D.new()
		led.name = "Led"
		var led_box := BoxMesh.new()
		led_box.size = LED_SIZE
		led.mesh = led_box
		led.position = Vector3(0.0, BODY_SIZE.y + MAST_SIZE.y + LED_SIZE.y / 2.0, 0.0)
		var led_mat := StandardMaterial3D.new()
		led_mat.albedo_color = ScopeTheme.TEAL if str(robot.get("state", "")) == "released" else ScopeTheme.AMBER
		led_mat.roughness = 0.4
		led.material_override = led_mat
		unit.add_child(led)

		var plate := Label3D.new()
		plate.name = "Nameplate"
		plate.text = farm.robot_display_name(robot_id)
		plate.pixel_size = 0.004
		plate.font_size = 28
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.modulate = ScopeTheme.INK
		plate.position = Vector3(0.0, BODY_SIZE.y + MAST_SIZE.y + 0.30, 0.0)
		unit.add_child(plate)

		add_child(unit)
