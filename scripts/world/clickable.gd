class_name Clickable
extends Area3D
## Mouse-clickable 3D object. Needs a CollisionShape3D child and
## `physics_object_picking = true` on the viewport that renders it.
## Lives on physics layer 4 ("interactable") so it never blocks rover
## movement or the satellite LOS ray.

signal clicked

## Shown by scenes that display a hover hint.
@export var hint: String = ""
@export var enabled: bool = true:
	set(value):
		enabled = value
		input_ray_pickable = value
		if not value:
			_set_hover_cursor(false)

static var hovered: Clickable = null


func _mouse_enter() -> void:
	if enabled:
		hovered = self
		_set_hover_cursor(true)


func _mouse_exit() -> void:
	if hovered == self:
		hovered = null
	_set_hover_cursor(false)


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not enabled:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


func _exit_tree() -> void:
	if hovered == self:
		hovered = null
		_set_hover_cursor(false)


func _set_hover_cursor(on: bool) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
