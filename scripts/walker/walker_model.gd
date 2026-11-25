class_name WalkerModel
extends Node3D
## The Remote Operator on foot, original voxels in code: orange suit, dark boots
## and pack, teal visor [PLACEHOLDER]. Feet at the origin, facing -Z.

const VOXEL_M: float = 0.2
const SUIT := Color("#d9772b")
const DARK := Color("#1d222b")
const VISOR := Color("#38e1c6")
## The two legs swap this often, in meters walked [PLACEHOLDER].
const STEP_M: float = 0.7
const SWING_M: float = 0.2

var speed_mps: float = 0.0

var _legs: Array[MeshInstance3D] = []
var _walked_m: float = 0.0


func _init() -> void:
	# Place and size in voxels: 4 wide, 8 tall, 3 deep.
	for x: float in [-1.0, 1.0]:
		var leg: MeshInstance3D = _box(Vector3(x * 0.75, 1.5, 0.0), Vector3(1.0, 3.0, 1.0), SUIT)
		leg.add_child(_made(Vector3(0.0, -1.0, -0.1), Vector3(1.1, 1.0, 1.3), DARK))
		_legs.append(leg)
		_box(Vector3(x * 1.625, 4.0, 0.0), Vector3(0.75, 2.0, 1.0), SUIT)
	_box(Vector3(0.0, 4.25, 0.0), Vector3(2.5, 2.5, 1.5), SUIT)
	_box(Vector3(0.0, 4.5, 1.25), Vector3(2.0, 2.0, 1.0), DARK)
	_box(Vector3(0.0, 6.75, 0.0), Vector3(2.5, 2.5, 2.5), SUIT)
	_box(Vector3(0.0, 6.75, -1.15), Vector3(2.0, 1.2, 0.5), VISOR)


func _process(delta: float) -> void:
	_walked_m += speed_mps * delta
	step(0.0 if speed_mps < 0.1 else (1.0 if fmod(_walked_m, STEP_M * 2.0) < STEP_M else -1.0))


## 1 or -1 for which leg is in front, 0 to stand.
func step(front: float) -> void:
	_legs[0].position.z = -front * SWING_M
	_legs[1].position.z = front * SWING_M


func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var made: MeshInstance3D = _made(at, size, color)
	add_child(made)
	return made


func _made(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size * VOXEL_M
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	var made := MeshInstance3D.new()
	made.mesh = mesh
	made.position = at * VOXEL_M
	return made
