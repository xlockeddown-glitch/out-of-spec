class_name SatelliteRelay
extends Node3D
## Fixed uplink endpoint. Rovers raycast to `get_uplink_point()` for LOS.
## Place it low on the horizon so terrain/rocks can actually occlude it.
## Shows the optical silk upgrade from GameState (brighter beacon, spool in bay).

@export var relay_name: String = "SAT-RELAY 01"
## Dish position used as the ray target. Falls back to this node's origin.
@export var uplink_point: Node3D
@export var beacon: OmniLight3D
## Shown only while a spool is slotted.
@export var spool_visual: Node3D
## Voxel model; its emit_fiber part lights up only while a spool is slotted.
@export var mast_model: ModelSlot
@export var beacon_energy_base: float = 1.0
@export var beacon_energy_upgraded: float = 6.0


func _ready() -> void:
	GameState.relay_changed.connect(_apply_upgrade)
	_apply_upgrade(GameState.relay_slotted)


func get_uplink_point() -> Vector3:
	return uplink_point.global_position if uplink_point else global_position


func _apply_upgrade(slotted: bool) -> void:
	if beacon:
		beacon.light_energy = beacon_energy_upgraded if slotted else beacon_energy_base
	if spool_visual:
		spool_visual.visible = slotted
	if mast_model:
		mast_model.set_part_visible("emit_fiber", slotted)
