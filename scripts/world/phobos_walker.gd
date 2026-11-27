class_name PhobosWalker
extends CharacterBody3D
## This screen's player on foot at the Phobos hub: a flat deck, so no terrain, no
## water and no rover. It is not sent to the farm's walkers: nobody on the farm sees
## it (the farm shows only those on the farm). Walking only, with the farm's
## on-foot speed; no low gravity yet [PLACEHOLDER].

const SPEED_MPS: float = Walker.SPEED_MPS
## The deck's edge, from its middle [PLACEHOLDER].
const EDGE_M: float = 34.0
const FALL_MPS2: float = 9.8

var camera: Camera3D
var model := WalkerModel.new()


func _init() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = Walker.capsule()
	shape.position.y = Walker.TALL_M / 2.0
	add_child(shape)
	add_child(model)


func _physics_process(delta: float) -> void:
	var keys := Vector2.ZERO
	if camera != null and not (RoverController.input_blocked or RoverController.panel_has_stick(get_tree())):
		keys = Vector2(Input.get_axis(&"rover_steer_left", &"rover_steer_right"),
			Input.get_axis(&"rover_forward", &"rover_reverse"))
	walk(Walker.heading(keys, camera.global_basis) if camera != null else Vector3.ZERO, delta)


func walk(to: Vector3, delta: float) -> void:
	var fall: float = 0.0 if is_on_floor() else velocity.y - FALL_MPS2 * delta
	velocity = to * SPEED_MPS + Vector3.UP * fall
	if to != Vector3.ZERO:
		rotation.y = atan2(-to.x, -to.z)
	move_and_slide()
	var flat := Vector2(global_position.x, global_position.z).limit_length(EDGE_M)
	global_position = Vector3(flat.x, maxf(global_position.y, 0.0), flat.y)
	var real: Vector3 = get_real_velocity()
	model.speed_mps = Vector2(real.x, real.z).length()
