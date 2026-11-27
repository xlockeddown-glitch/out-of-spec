class_name DomePadPointer
extends Node
## Gamepad selection pointer for dome Clickables. Moves focus between on-screen
## Clickables with the D-pad or left stick, mirrors hover state via
## Clickable.set_hover(), activates via Clickable.activate(), pauses while a
## modal panel is open, and yields back to the mouse on intentional movement.

signal selection_changed(selected: Clickable)

## [PLACEHOLDER] How far the left stick must be pushed to step selection, and
## how far back it must return before it can step again (one step per push).
const STICK_STEP: float = 0.6
const STICK_REST: float = 0.35
## [PLACEHOLDER] Off the pad's direction line, a Clickable counts this many times further away.
const OFF_LINE_COST: float = 2.0
## [PLACEHOLDER] The mouse must move this many pixels in all before it takes the
## hint and hover back from the pad's pick (a bumped desk or drifting sensor must not).
const MOUSE_TAKEOVER_PX: float = 6.0

## The remembered pad selection (kept across panel pause so closing restores it).
var _selected: Clickable = null
## True while a modal panel holds the screen; hover and activation are paused.
var _paused: bool = false
## Which stick directions are currently held (so one push steps once).
var _stick_held: Dictionary[Vector2i, bool] = {}
## Cumulative mouse travel in px since the pad last picked.
var _mouse_travel: float = 0.0

var selected: Clickable:
	get:
		return _selected
	set(value):
		set_selection(value)


func _exit_tree() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.set_hover(false)
	_selected = null
	_paused = false
	_stick_held.clear()


## The selection currently shown and usable, or null when paused or invalid.
func active_selection() -> Clickable:
	if _paused or not is_pick_valid(_selected):
		return null
	return _selected


func is_paused() -> bool:
	return _paused


## Updates the selected Clickable and its hover state only when it changes.
func set_selection(next: Clickable) -> void:
	if next == _selected:
		return
	if _selected != null and is_instance_valid(_selected):
		_selected.set_hover(false)
	_selected = next
	if _selected != null and not _paused and is_pick_valid(_selected):
		_selected.set_hover(true)
	selection_changed.emit(active_selection())


func clear_selection() -> void:
	set_selection(null)


## Reconciles pause state with open modal panels and drops picks that became
## disabled or left the tree. Only touches hover state on actual transitions.
func sync_state() -> void:
	var panel_open: bool = QuestsUI.other_panel_open(get_tree())
	if panel_open:
		if not _stick_held.is_empty():
			# The stick may be let go inside a panel, where this scene sees nothing.
			_stick_held.clear()
		if not _paused:
			_paused = true
			if _selected != null and is_instance_valid(_selected):
				_selected.set_hover(false)
			selection_changed.emit(null)
		return
	if _paused:
		_paused = false
		if _selected != null:
			if is_pick_valid(_selected):
				_selected.set_hover(true)
				selection_changed.emit(_selected)
			else:
				_selected = null
				selection_changed.emit(null)
	elif _selected != null and not is_pick_valid(_selected):
		set_selection(null)


## Every dome Clickable that can be picked right now.
func usable_clickables() -> Array[Clickable]:
	var found: Array[Clickable] = []
	var scope: Node = get_parent()
	if scope == null:
		return found
	for node: Node in scope.find_children("*", "Clickable", true, false):
		var item: Clickable = node as Clickable
		if is_pickable(item):
			found.append(item)
	return found


## Usable now, and on the screen where the player can see it.
func is_pickable(item: Clickable) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	if not (item.enabled and item.is_inside_tree() and item.is_visible_in_tree()):
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return true
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return true
	return not camera.is_position_behind(item.global_position) and viewport.get_visible_rect().has_point(screen_point(item))


func is_pick_valid(item: Clickable = _selected) -> bool:
	return item != null and is_instance_valid(item) and is_pickable(item)


func pick_point(item: Clickable) -> Vector3:
	for child: Node in item.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return item.global_position


func screen_point(item: Clickable) -> Vector2:
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	return camera.unproject_position(pick_point(item)) if camera != null else Vector2.ZERO


## Moves selection to the usable Clickable nearest in `direction` (screen space)
## from the current selection, or nearest to the screen centre when nothing is picked.
func step(direction: Vector2) -> void:
	var usable: Array[Clickable] = usable_clickables()
	if usable.is_empty():
		clear_selection()
		return
	var viewport: Viewport = get_viewport()
	var from: Vector2 = viewport.get_visible_rect().size / 2.0 if viewport != null else Vector2.ZERO
	var valid: bool = is_pick_valid(_selected)
	if valid:
		from = screen_point(_selected)
	var best: Clickable = null
	var best_cost: float = INF
	for item: Clickable in usable:
		if item == _selected:
			continue
		var offset: Vector2 = screen_point(item) - from
		var along: float = offset.dot(direction)
		if valid and along <= 1.0:
			continue
		var cost: float = maxf(along, 0.0) + absf(offset.cross(direction)) * OFF_LINE_COST
		if not valid:
			cost = offset.length()
		if cost < best_cost:
			best_cost = cost
			best = item
	if best != null:
		set_selection(best)
		_mouse_travel = 0.0


## Mouse movement past MOUSE_TAKEOVER_PX hands hover and hints back to the mouse.
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_travel += (event as InputEventMouseMotion).relative.length()
		if _mouse_travel >= MOUSE_TAKEOVER_PX:
			clear_selection()


## Handles D-pad / left-stick navigation and accept while no modal panel is open.
func handle_unhandled_input(event: InputEvent) -> void:
	if QuestsUI.other_panel_open(get_tree()):
		return
	var direction: Vector2i = Vector2i.ZERO
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed:
			match button.button_index:
				JOY_BUTTON_DPAD_UP:
					direction = Vector2i.UP
				JOY_BUTTON_DPAD_DOWN:
					direction = Vector2i.DOWN
				JOY_BUTTON_DPAD_LEFT:
					direction = Vector2i.LEFT
				JOY_BUTTON_DPAD_RIGHT:
					direction = Vector2i.RIGHT
	elif event is InputEventJoypadMotion:
		direction = stick_direction(event as InputEventJoypadMotion)
	if direction != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		step(Vector2(direction))
	elif (event.is_action_pressed(&"interact", false) or event.is_action_pressed(&"ui_accept", false)) and not _paused and is_pick_valid(_selected):
		get_viewport().set_input_as_handled()
		_selected.activate()


## One step for each push of the left stick (it must come back to rest to step again).
func stick_direction(motion: InputEventJoypadMotion) -> Vector2i:
	var along: Vector2i = Vector2i.ZERO
	if motion.axis == JOY_AXIS_LEFT_X:
		along = Vector2i.RIGHT if motion.axis_value > 0.0 else Vector2i.LEFT
	elif motion.axis == JOY_AXIS_LEFT_Y:
		along = Vector2i.DOWN if motion.axis_value > 0.0 else Vector2i.UP
	else:
		return Vector2i.ZERO
	var strength: float = absf(motion.axis_value)
	if strength < STICK_REST:
		for key: Vector2i in [along, -along]:
			_stick_held[key] = false
		return Vector2i.ZERO
	if strength >= STICK_STEP and not _stick_held.get(along, false):
		# A push to a corner crosses both axes: only the first one steps.
		var other_axis_held: bool = false
		for key: Vector2i in _stick_held:
			if _stick_held[key] and (key.x == 0) != (along.x == 0):
				other_axis_held = true
		_stick_held[along] = true
		# A flick straight across skips the rest event, so the way back is free again.
		_stick_held[-along] = false
		return Vector2i.ZERO if other_axis_held else along
	return Vector2i.ZERO
