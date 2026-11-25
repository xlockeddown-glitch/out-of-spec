class_name WildSentinel
extends Node3D
## The wild Cobalt Sentinel by the sump, there while GameState has it out. Scared,
## it runs for the rock.

const SIZE: float = 4.0  # [PLACEHOLDER] so it reads from the farm camera
const FACING: float = PI * 0.75
const BOLT_MPS: float = 6.0  # [PLACEHOLDER]
const BOLT_S: float = 1.2  # [PLACEHOLDER] into the north wall

@onready var _rig := TarantulaRig.new()
var _bolt_s: float = 0.0


func _ready() -> void:
	_rig.scale = Vector3.ONE * SIZE
	_rig.rotation.y = FACING
	add_child(_rig)
	GameState.sentinel_changed.connect(_refresh)
	position = GameState.SENTINEL_AT
	visible = GameState.sentinel_out


func _process(delta: float) -> void:
	if _bolt_s <= 0.0:
		return
	_bolt_s -= delta
	position.z -= BOLT_MPS * delta
	if _bolt_s <= 0.0:
		visible = false


func _refresh() -> void:
	var out: bool = GameState.sentinel_out
	if not out and (_bolt_s > 0.0 or not visible):
		return
	if out:
		position = GameState.SENTINEL_AT
	_bolt_s = 0.0 if out else BOLT_S
	visible = out or not GameState.is_caught(GameState.SENTINEL)
	_rig.idles = out
	_rig.pace = 0.0 if out else 2.5
	_rig.rotation.y = FACING if out else 0.0
