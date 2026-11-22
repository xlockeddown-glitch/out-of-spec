class_name BramBay
extends Area3D
## Bram's scrapyard bay. Reports when the rover parks inside so the farm can
## offer his trade on the phone. Needs collision_mask to include the rover
## layer (2).

signal rover_entered
signal rover_exited

var rover_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is RoverController:
		rover_inside = true
		rover_entered.emit()


func _on_body_exited(body: Node3D) -> void:
	if body is RoverController:
		rover_inside = false
		rover_exited.emit()
