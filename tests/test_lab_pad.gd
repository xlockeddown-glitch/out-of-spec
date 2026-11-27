extends RefCounted
## The lab with a pad: the bottom line stays calm when the device keeps changing,
## and a pad can pick and use things without the mouse.

const DOME: PackedScene = preload("res://scenes/dome_interior.tscn")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func _open() -> Node:
	var dome: Node = DOME.instantiate()
	_root().add_child(dome)
	return dome


func _close(dome: Node) -> void:
	_root().remove_child(dome)
	dome.free()
	Controls.last_device = Controls.Device.KEY
	Controls.pad_present_override = false
	Clickable.hovered = null


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
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


func _hint(dome: Node) -> Label:
	return dome.get_node("%HintLabel")


## A pad that also sends key presses (Steam Input) flips the last device every
## event. On main the bottom line changed every frame (60 changes in 60 frames).
func test_repro_device_flip_every_frame_keeps_the_line_calm() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	var hint: Label = _hint(dome)
	var changes: int = 0
	var last: String = hint.text
	var owners: Dictionary = {}
	for i: int in 60:
		Controls.note_event(_key(KEY_E) if i % 2 == 0 else _button(JOY_BUTTON_X))
		await _frame()
		if hint.text != last:
			changes += 1
			last = hint.text
		owners[str(_root().gui_get_focus_owner())] = true
	var out: String = ""
	if changes > 1:
		out = "the bottom line changed %d times in 60 frames" % changes
	elif owners.size() > 1:
		out = "the focus owner moved: %s" % str(owners.keys())
	_close(dome)
	return out


func test_a_settled_device_still_changes_the_wording() -> String:
	var dome: Node = _open()
	await _frame()
	var before: String = _hint(dome).text
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	dome.set("_hint_msec", -1000000)  # the last change was long ago
	await _frame()
	var after: String = _hint(dome).text
	_close(dome)
	return "" if after != before and after.contains("View") else "the line did not take the pad wording: %s" % after


## Names of the clickables, in the order the pad steps to them from the first pick.
func _walk(dome: Node, direction: JoyButton, count: int) -> Array[Clickable]:
	var seen: Array[Clickable] = []
	for i: int in count:
		await _send(_button(direction))
		seen.append(dome.get("_pad_pick") as Clickable)
	return seen


func test_pad_steps_through_enabled_clickables_and_skips_disabled() -> String:
	var dome: Node = _open()
	await _frame()
	var usable: Array[Clickable] = dome.call("usable_clickables")
	if usable.size() < 4:
		_close(dome)
		return "expected several usable clickables, found %d" % usable.size()
	var off: Clickable = dome.get_node("%PlanBoardClick") as Clickable
	off.enabled = false
	var seen: Array[Clickable] = await _walk(dome, JOY_BUTTON_DPAD_RIGHT, 12)
	seen.append_array(await _walk(dome, JOY_BUTTON_DPAD_LEFT, 12))
	var out: String = ""
	var distinct: Dictionary = {}
	for item: Clickable in seen:
		if item == null:
			out = "a step left nothing picked"
		elif not item.enabled:
			out = "stepped onto a disabled clickable: %s" % item.name
		distinct[item] = true
	if out == "" and distinct.size() < 3:
		out = "stepping reached only %d clickables" % distinct.size()
	if out == "" and distinct.has(off):
		out = "the disabled plan board was picked"
	_close(dome)
	return out


func test_the_stick_steps_once_per_push() -> String:
	var dome: Node = _open()
	await _frame()
	dome.call("_unhandled_input", _stick(JOY_AXIS_LEFT_X, 0.9))
	var first: Clickable = dome.get("_pad_pick") as Clickable
	dome.call("_unhandled_input", _stick(JOY_AXIS_LEFT_X, 0.95))
	dome.call("_unhandled_input", _stick(JOY_AXIS_LEFT_X, 0.9))
	var held: Clickable = dome.get("_pad_pick") as Clickable
	dome.call("_unhandled_input", _stick(JOY_AXIS_LEFT_X, 0.0))
	dome.call("_unhandled_input", _stick(JOY_AXIS_LEFT_X, 0.9))
	var second: Clickable = dome.get("_pad_pick") as Clickable
	var out: String = ""
	if first == null:
		out = "the stick picked nothing"
	elif held != first:
		out = "holding the stick kept stepping"
	elif second == first:
		out = "a second push did not step"
	_close(dome)
	return out


func test_interact_clicks_the_pick_and_the_hint_names_it() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var airlock: Clickable = dome.get_node("%AirlockClick") as Clickable
	var clicks: Array[int] = [0]
	var other: Clickable = dome.get_node("%BenchClick") as Clickable
	airlock.clicked.connect(func() -> void: clicks[0] += 1)
	other.clicked.connect(func() -> void: clicks[0] += 100)
	dome.set("_pad_pick", other)
	await _frame()
	var said: String = _hint(dome).text
	var named: bool = said.contains("to use") and said.contains(other.hint if other.hint != "" else String(other.name))
	var event := _button(JOY_BUTTON_A)
	await _send(event)
	var out: String = ""
	if not named:
		out = "the hint does not name the pick: %s" % said
	elif clicks[0] != 100:
		out = "interact did not click only the pick (%d)" % clicks[0]
	_close(dome)
	return out


func test_mouse_motion_hands_the_hint_back() -> String:
	var dome: Node = _open()
	await _frame()
	dome.set("_pad_pick", dome.get_node("%BenchClick"))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(4, 0)
	motion.position = Vector2(100, 100)
	dome.call("_input", motion)
	var cleared: bool = dome.get("_pad_pick") == null
	_close(dome)
	return "" if cleared else "mouse motion left the pad's pick in place"


func test_bench_opened_from_the_lab_takes_the_pad() -> String:
	var dome: Node = _open()
	await _frame()
	var bench_ui: CalBenchUI = dome.get_node("%CalBenchUI") as CalBenchUI
	bench_ui.open()
	await _frame()
	var out: String = ""
	var focus: Control = _root().gui_get_focus_owner()
	if focus == null or not bench_ui.is_ancestor_of(focus):
		out = "the bench did not take focus for the pad"
	var before: Clickable = dome.get("_pad_pick") as Clickable
	await _send(_button(JOY_BUTTON_DPAD_RIGHT))
	if out == "" and dome.get("_pad_pick") != before:
		out = "the lab stepped its pick behind the open bench"
	await _send(_button(JOY_BUTTON_B))
	if out == "" and bench_ui.visible:
		out = "B did not close the bench"
	_close(dome)
	return out
