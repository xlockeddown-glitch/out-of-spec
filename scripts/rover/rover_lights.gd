class_name RoverLights
extends Node3D
## The rover's headlights, on or low as GameState has them.

## [PLACEHOLDER]
const ENERGY: float = 3.0
const RANGE_M: float = 11.0
const ANGLE_DEG: float = 28.0
const COLOR := Color("#f5a623")

@export var model_slot: ModelSlot


func _ready() -> void:
	for x: float in [-0.25, 0.25]:
		var beam := SpotLight3D.new()
		beam.position.x = x
		beam.rotation.x = -0.15
		beam.light_color = COLOR
		beam.light_energy = ENERGY
		beam.spot_range = RANGE_M
		beam.spot_angle = ANGLE_DEG
		add_child(beam)
	GameState.rover_lights_changed.connect(_refresh)
	# The rover swaps its model after this, for wide treads.
	GameState.upgrades_changed.connect(_refresh, CONNECT_DEFERRED)
	_refresh.call_deferred()


func _refresh() -> void:
	visible = GameState.rover_lights
	model_slot.set_part_visible("emit_headlights", visible)
