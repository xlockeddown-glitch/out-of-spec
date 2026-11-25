class_name TarantulaRig
extends Node3D
## The Cobalt Sentinel: Ryan's body and eight of his legs, walking four at a time
## when it moves. It faces -Z, at the size his rig gave it.

const BODY: PackedScene = preload("res://assets/voxels/cobalt_body.glb")
const LEG: PackedScene = preload("res://assets/voxels/cobalt_leg.glb")
const VOXEL_M: float = 0.025
## Where each pair of legs meets the body, and how far it points forward.
const HIP_X_M: float = 0.025
const HIP_Z_M: PackedFloat32Array = [-0.0875, -0.0625, -0.0375, -0.0125]
const REACH_DEG: PackedFloat32Array = [38.0, 12.0, -14.0, -42.0]
## The leg model's hip, in voxels from its middle.
const HIP_VOXELS: float = 3.0
## [PLACEHOLDER]
const SWING_DEG: float = 18.0
const LIFT_DEG: float = 14.0
const BOB_M: float = 0.002
const STEP_RATE: float = 7.5
## Looking around: how far it turns, how fast, and how long it then rests.
const TURN_DEG: float = 25.0
const TURN_DEG_S: float = 20.0
const REST_S := Vector2(2.0, 5.0)

## How fast its legs go, against a walk; 0.0 stands still.
var pace: float = 0.0
## It looks around by itself.
var idles: bool = true

var _legs: Array[Node3D] = []
var _body: Node3D
var _phase: float = 0.0
var _moving: float = 0.0
var _rest_s: float = 2.0
var _turn_to: float = 0.0
var _facing: float = 0.0


func _ready() -> void:
	_facing = rotation.y
	_turn_to = _facing
	_body = _part(BODY)
	add_child(_body)
	for side: int in 2:
		for pair: int in HIP_Z_M.size():
			var hip := Node3D.new()
			hip.position = Vector3(HIP_X_M * (1 if side else -1), 0.0, HIP_Z_M[pair])
			var leg: Node3D = _part(LEG)
			leg.position.x = -HIP_VOXELS * VOXEL_M
			hip.add_child(leg)
			add_child(hip)
			_legs.append(hip)
	_pose()


func _process(delta: float) -> void:
	var going: float = pace
	if idles and pace == 0.0:
		_rest_s -= delta
		if _rest_s <= 0.0:
			_rest_s = randf_range(REST_S.x, REST_S.y)
			_turn_to = _facing + deg_to_rad(randf_range(-TURN_DEG, TURN_DEG))
		if not is_equal_approx(rotation.y, _turn_to):
			rotation.y = move_toward(rotation.y, _turn_to, deg_to_rad(TURN_DEG_S) * delta)
			going = 0.5
	_moving = move_toward(_moving, minf(going * 2.0, 1.0), delta * 4.0)
	_phase = fmod(_phase + delta * STEP_RATE * maxf(going, 0.5), TAU)
	_pose()


func _part(scene: PackedScene) -> Node3D:
	var part := scene.instantiate() as Node3D
	part.scale = Vector3.ONE * VOXEL_M
	return part


## Legs of one group are up while the other's push.
func _pose() -> void:
	_body.position.y = absf(sin(_phase * 2.0)) * BOB_M * _moving
	for i: int in _legs.size():
		var pair: int = i % 4
		var right: bool = i >= 4
		var at: float = _phase + (PI if (pair + int(right)) % 2 == 1 else 0.0)
		var forward: float = deg_to_rad(REACH_DEG[pair] - cos(at) * SWING_DEG * _moving)
		var lift: float = maxf(sin(at), 0.0) * deg_to_rad(LIFT_DEG) * _moving
		_legs[i].rotation = Vector3(0.0, PI + forward if right else -forward, -lift)
