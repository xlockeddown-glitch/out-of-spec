class_name SatelliteRelay
extends Node3D
## Fixed uplink endpoint. Rovers raycast to `get_uplink_point()` for LOS.
## Place it low on the horizon so terrain/rocks can actually occlude it.

@export var relay_name: String = "SAT-RELAY 01"
## Dish position used as the ray target. Falls back to this node's origin.
@export var uplink_point: Node3D


func get_uplink_point() -> Vector3:
	return uplink_point.global_position if uplink_point else global_position
