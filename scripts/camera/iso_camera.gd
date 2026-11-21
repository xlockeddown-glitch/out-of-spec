class_name IsoCamera
extends Camera3D
## Fixed-angle follow camera. Default is true isometric
## (pitch = -atan(1/sqrt(2)) = -35.264 deg, yaw = 45 deg), orthographic.

@export var target: Node3D
@export var pitch_deg: float = -35.264
@export var yaw_deg: float = 45.0
@export var distance_m: float = 40.0
@export var use_orthographic: bool = true
## Orthographic view height in metres.
@export var ortho_size_m: float = 22.0
## Higher = snappier follow. 0 = no smoothing.
@export var follow_smoothing: float = 6.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL if use_orthographic else PROJECTION_PERSPECTIVE
	size = ortho_size_m
	rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)
	if target:
		global_position = _desired_position()


func _process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = _desired_position()
	if follow_smoothing <= 0.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))


func _desired_position() -> Vector3:
	# Camera looks down its -Z, so back off along +Z.
	return target.global_position + global_transform.basis.z * distance_m
