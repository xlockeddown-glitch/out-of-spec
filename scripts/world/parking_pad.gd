class_name ParkingPad
extends Area3D
## A spot the rover parks on (Bram's bay, the field calibration pad). Reports
## when the rover is inside so the farm can offer what the spot does. Needs
## collision_mask to include the rover layer (2).

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
