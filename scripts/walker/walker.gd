class_name Walker
extends CharacterBody3D
## This screen's player on foot. The world and the rover stop it; it stops nobody.

## [PLACEHOLDER]
const SPEED_MPS: float = 4.0
const RADIUS_M: float = 0.3
const TALL_M: float = 1.6
const CLIMB_DEG: float = 50.0
const SNAP_M: float = 0.4
const FALL_MPS2: float = 9.8
## The ground and the rocks, and the rover.
const MASK: int = 1 | 2
## Under the ground by this much, it is put back on it.
const UNDER_M: float = 0.3

var camera: Camera3D
var model := WalkerModel.new()


func _init() -> void:
	collision_layer = 0
	collision_mask = MASK
	floor_max_angle = deg_to_rad(CLIMB_DEG)
	floor_snap_length = SNAP_M
	var shape := CollisionShape3D.new()
	shape.shape = capsule()
	shape.position.y = TALL_M / 2.0
	add_child(shape)
	add_child(model)


static func capsule() -> CapsuleShape3D:
	var made := CapsuleShape3D.new()
	made.radius = RADIUS_M
	made.height = TALL_M
	return made


## W is up the screen, whatever way the camera looks. `keys` is right and down.
static func heading(keys: Vector2, view: Basis) -> Vector3:
	var right := Vector3(view.x.x, 0.0, view.x.z).normalized()
	var back := Vector3(view.z.x, 0.0, view.z.z).normalized()
	return (right * keys.x + back * keys.y).limit_length()


func _physics_process(delta: float) -> void:
	var keys := Vector2(
		Input.get_axis(&"rover_steer_left", &"rover_steer_right"),
		Input.get_axis(&"rover_forward", &"rover_reverse"))
	walk(heading(keys, camera.global_basis), delta)
	CoopWalkers.moved(global_position, rotation.y, model.speed_mps)


func walk(to: Vector3, delta: float) -> void:
	var fall: float = 0.0 if is_on_floor() else velocity.y - FALL_MPS2 * delta
	var speed_mps: float = SPEED_MPS
	# Wading, as the rover does.
	if Terrain.water_depth_m(Vector2(global_position.x, global_position.z)) > 0.0:
		speed_mps *= Terrain.WATER_SPEED
	velocity = to * speed_mps + Vector3.UP * fall
	if to != Vector3.ZERO:
		rotation.y = atan2(-to.x, -to.z)
	move_and_slide()
	var edge_m: float = Terrain.HALF_M - RADIUS_M
	global_position.x = clampf(global_position.x, -edge_m, edge_m)
	global_position.z = clampf(global_position.z, -edge_m, edge_m)
	var ground_m: float = Terrain.height(Vector2(global_position.x, global_position.z), GameState.dug)
	if global_position.y < ground_m - UNDER_M:
		global_position.y = ground_m
		velocity.y = 0.0
	var speed: Vector3 = get_real_velocity()
	model.speed_mps = Vector2(speed.x, speed.z).length()
