class_name DropPod
extends Node3D
## MegaCorp drop-pod. Present while GameState.drop_pod_present (audit mornings
## until the scheduled departure). Lands from the sky, AUD-1T hovers beside it, lifts off when
## the audit is over. Visual only; the audit itself runs in GameState.

const DROP_HEIGHT: float = 40.0
const LAND_SECONDS: float = 1.4
const BOB_HEIGHT: float = 0.15
const BOB_HZ: float = 0.6

@export var drone: Node3D

var _rest_position: Vector3
var _drone_rest: Vector3
var _time: float = 0.0
var _tween: Tween


func _ready() -> void:
	_rest_position = position
	if drone:
		_drone_rest = drone.position
	GameState.drop_pod_changed.connect(_on_drop_pod_changed)
	# Entering the farm mid-audit: already parked, no landing animation.
	visible = GameState.drop_pod_present


func _process(delta: float) -> void:
	if not visible or drone == null:
		return
	_time += delta
	drone.position = _drone_rest + Vector3.UP * sin(_time * TAU * BOB_HZ) * BOB_HEIGHT


func _on_drop_pod_changed(present: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	if present:
		position = _rest_position + Vector3.UP * DROP_HEIGHT
		visible = true
		_tween.set_ease(Tween.EASE_OUT).tween_property(self, "position", _rest_position, LAND_SECONDS)
	else:
		_tween.set_ease(Tween.EASE_IN).tween_property(self, "position", _rest_position + Vector3.UP * DROP_HEIGHT, LAND_SECONDS)
		_tween.tween_callback(hide)
