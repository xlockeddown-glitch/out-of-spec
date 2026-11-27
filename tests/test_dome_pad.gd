extends RefCounted
## Dome gamepad pointer tests: DomePadPointer navigation, Clickable hover/activate
## parity, panel pause/restore, flicker-free updates, and mouse hover compatibility.

const DOME: PackedScene = preload("res://scenes/dome_interior.tscn")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func _open() -> Node:
	var dome: Node = DOME.instantiate()
	_root().add_child(dome)
	return dome


func _reset_controls() -> void:
	Controls.last_device = Controls.Device.KEY
	Controls.pad_present_override = false
	Controls.settle_text = false
	Controls.reset_shown()


func _close(dome: Node) -> void:
	_root().remove_child(dome)
	dome.free()
	_reset_controls()
	Clickable.hovered = null


func _pointer(dome: Node) -> DomePadPointer:
	return dome.get_node_or_null("DomePadPointer") as DomePadPointer


func _hint(dome: Node) -> Label:
	return dome.get_node("%HintLabel") as Label


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await _frame()


func test_dome_adds_pad_pointer_node() -> String:
	var dome: Node = _open()
	await _frame()
	var found: bool = _pointer(dome) != null
	_close(dome)
	return "" if found else "DomeInterior did not add a DomePadPointer child node"


func test_dpad_and_stick_move_selection_and_sync_clickable_hover() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var pointer: DomePadPointer = _pointer(dome)
	var out: String = ""

	await _send(_button(JOY_BUTTON_DPAD_RIGHT))
	var first: Clickable = pointer.active_selection()
	if first == null:
		out = "D-pad right selected nothing"
	elif Clickable.hovered != first:
		out = "pad selection did not set Clickable.hovered"

	if out == "":
		# Move with left stick (push, return to rest, push the other way).
		await _send(_stick(JOY_AXIS_LEFT_X, -0.9))
		var second: Clickable = pointer.active_selection()
		await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
		if second == first:
			await _send(_stick(JOY_AXIS_LEFT_X, 0.9))
			second = pointer.active_selection()
			await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
		if second == null or second == first:
			out = "left stick did not move selection to another Clickable"
		elif Clickable.hovered != second:
			out = "moving selection did not update Clickable.hovered to the new pick"

	_close(dome)
	return out


func test_accept_activates_through_same_path_as_mouse_click() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var pointer: DomePadPointer = _pointer(dome)
	var target: Clickable = dome.get_node("%TerrariumClick") as Clickable
	var clicks: Array[int] = [0]
	target.clicked.connect(func() -> void: clicks[0] += 1)
	pointer.set_selection(target)
	await _frame()

	# 1. Pad accept (A button).
	await _send(_button(JOY_BUTTON_A))
	var after_pad: int = clicks[0]

	# 2. Direct mouse click event on the same Clickable.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	target._input_event(null, mb, Vector3.ZERO, Vector3.UP, 0)
	var after_mouse: int = clicks[0]

	# 3. Disabled Clickable ignores both activate() and pad accept.
	target.enabled = false
	target.activate()
	await _send(_button(JOY_BUTTON_A))
	var after_disabled: int = clicks[0]

	var out: String = ""
	if after_pad != 1:
		out = "pad accept fired %d times (expected 1)" % after_pad
	elif after_mouse != 2:
		out = "mouse click fired %d times total (expected 2)" % after_mouse
	elif after_disabled != 2:
		out = "disabled Clickable still activated (%d)" % after_disabled

	target.enabled = true
	_close(dome)
	return out


func test_panel_open_pauses_selection_and_close_restores_it() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var pointer: DomePadPointer = _pointer(dome)
	var bench: Clickable = dome.get_node("%BenchClick") as Clickable
	var bench_ui: CalBenchUI = dome.get_node("%CalBenchUI") as CalBenchUI
	var clicks: Array[int] = [0]
	bench.clicked.connect(func() -> void: clicks[0] += 1)
	pointer.set_selection(bench)
	await _frame()

	var out: String = ""
	if pointer.active_selection() != bench or Clickable.hovered != bench:
		out = "precondition failed: bench was not selected and hovered"

	if out == "":
		bench_ui.open()
		await _frame()
		if not pointer.is_paused():
			out = "opening a panel did not pause DomePadPointer"
		elif pointer.active_selection() != null:
			out = "active_selection() was not null while a panel was open"
		elif Clickable.hovered != null:
			out = "opening a panel did not clear Clickable.hovered"

	if out == "":
		# D-pad and accept must be ignored while the panel is open.
		await _send(_button(JOY_BUTTON_DPAD_RIGHT))
		await _send(_button(JOY_BUTTON_DPAD_LEFT))
		if pointer.selected != bench:
			out = "pad input moved the remembered selection behind an open panel"
		elif clicks[0] != 0:
			out = "pad input activated the bench behind an open panel"

	if out == "":
		bench_ui.hide()
		await _frame()
		if pointer.is_paused():
			out = "closing the panel did not resume DomePadPointer"
		elif pointer.active_selection() != bench:
			out = "closing the panel did not restore the previous selection"
		elif Clickable.hovered != bench:
			out = "closing the panel did not restore Clickable.hovered"

	_close(dome)
	return out


func test_mouse_hover_and_click_still_work() -> String:
	var dome: Node = _open()
	await _frame()
	var bench: Clickable = dome.get_node("%BenchClick") as Clickable
	var clicks: Array[int] = [0]
	bench.clicked.connect(func() -> void: clicks[0] += 1)

	bench._mouse_enter()
	await _frame()
	var hovered_ok: bool = Clickable.hovered == bench
	var hint_hovered: String = _hint(dome).text

	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	bench._input_event(null, mb, Vector3.ZERO, Vector3.UP, 0)

	bench._mouse_exit()
	await _frame()
	var cleared_ok: bool = Clickable.hovered == null
	var hint_after: String = _hint(dome).text

	var out: String = ""
	if not hovered_ok:
		out = "mouse enter did not set Clickable.hovered"
	elif bench.hint != "" and hint_hovered != bench.hint:
		out = "mouse hover did not show bench hint (got '%s')" % hint_hovered
	elif clicks[0] != 1:
		out = "mouse click did not emit clicked (%d)" % clicks[0]
	elif not cleared_ok:
		out = "mouse exit did not clear Clickable.hovered"
	elif hint_after == hint_hovered and bench.hint != "":
		out = "hint stayed on hovered item after mouse exit"

	_close(dome)
	return out


func test_steady_selection_does_not_flicker() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var pointer: DomePadPointer = _pointer(dome)
	var bench: Clickable = dome.get_node("%BenchClick") as Clickable
	var emissions: Array[int] = [0]
	pointer.selection_changed.connect(func(_sel: Clickable) -> void: emissions[0] += 1)
	pointer.set_selection(bench)
	await _frame()
	var after_pick: int = emissions[0]
	var steady_hint: String = _hint(dome).text
	var hint_changes: int = 0
	for _i: int in 10:
		await _frame()
		if _hint(dome).text != steady_hint:
			hint_changes += 1

	var out: String = ""
	if after_pick != 1:
		out = "expected 1 selection_changed emission on pick, got %d" % after_pick
	elif emissions[0] != after_pick:
		out = "selection_changed emitted %d extra times on idle frames" % (emissions[0] - after_pick)
	elif hint_changes != 0:
		out = "hint text changed %d times on idle frames" % hint_changes

	_close(dome)
	return out
