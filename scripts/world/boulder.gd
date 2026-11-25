class_name Boulder
extends StaticBody3D
## A boulder the rover can drill away for good (GameState.boulder_hits). Its node
## name is its id. Once broken it stops neither rovers nor the uplink.

## How near the rover's nose must be [PLACEHOLDER].
const REACH_M: float = 0.7
## How much smaller each hit makes it.
const SHRINK_PER_HIT: float = 0.06

@onready var _shape: CollisionShape3D = $Shape
@onready var _model: Node3D = $Model


func _ready() -> void:
	GameState.boulders_changed.connect(_refresh)
	_refresh()


## True if it stands and the rover's nose, at `nose`, is at its side.
func is_in_reach(nose: Vector3) -> bool:
	if GameState.is_boulder_broken(name):
		return false
	var half: Vector3 = (_shape.shape as BoxShape3D).size / 2.0
	var at: Vector3 = _shape.to_local(nose).abs()
	return Vector2(maxf(at.x - half.x, 0.0), maxf(at.z - half.z, 0.0)).length() <= REACH_M


func _refresh() -> void:
	var broken: bool = GameState.is_boulder_broken(name)
	_model.visible = not broken
	_model.scale = Vector3.ONE * (1.0 - SHRINK_PER_HIT * int(GameState.boulder_hits.get(name, 0)))
	_shape.set_deferred(&"disabled", broken)
