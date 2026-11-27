class_name Clickable
extends Area3D
## Mouse-clickable 3D object. Needs a CollisionShape3D child and
## `physics_object_picking = true` on the viewport that renders it.
## Lives on physics layer 4 ("interactable") so it never blocks rover
## movement or the satellite LOS ray.

signal clicked

## Shown by scenes that display a hover hint.
@export var hint: String = ""
## What the interact key does here, for the "[E] verb" prompt over it. Empty reads "Use".
@export var verb: String = ""
@export var enabled: bool = true:
	set(value):
		enabled = value
		input_ray_pickable = value
		if not value:
			set_hover(false)

static var hovered: Clickable = null


## Sets or clears this Clickable as the hovered target. Both mouse hover
## and pad selection go through here.
func set_hover(on: bool) -> void:
	if on:
		if not enabled:
			return
		hovered = self
		_set_hover_cursor(true)
	else:
		if hovered == self:
			hovered = null
		if hovered == null:
			_set_hover_cursor(false)


## Activates this Clickable as if clicked. Both mouse clicks and pad accept
## go through here.
func activate() -> void:
	if enabled:
		clicked.emit()


func _mouse_enter() -> void:
	set_hover(true)


func _mouse_exit() -> void:
	set_hover(false)


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not enabled:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		activate()


func _exit_tree() -> void:
	if hovered == self:
		set_hover(false)


func _set_hover_cursor(on: bool) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
