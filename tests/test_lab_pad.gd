extends RefCounted
## The lab with a pad: the bottom line stays calm when the device keeps changing,
## and a pad can pick and use things without the mouse.

const DOME: PackedScene = preload("res://scenes/dome_interior.tscn")
const DomeScript: GDScript = preload("res://scripts/dome/dome_interior.gd")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


## The settle is on (the game has it on; the test runner turns it off).
func _settle_on() -> void:
	Controls.settle_text = true
	Controls.reset_shown()


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
## event. On main the bottom line changed every frame (59 changes in 60 frames).
func test_repro_device_flip_every_frame_keeps_the_line_calm() -> String:
	_settle_on()
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
	if changes > 0:
		out = "the bottom line changed %d times in 60 frames" % changes
	elif owners.size() > 1:
		out = "the focus owner moved: %s" % str(owners.keys())
	_close(dome)
	return out


## The settle itself, on a clock the test owns: a flip that goes on for 3 s never
## changes the shown device; a device that then holds 600 ms changes it once.
func test_shown_pad_ignores_a_lasting_flip_then_follows_a_settled_device() -> String:
	_settle_on()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.KEY
	var now: int = 1000
	var last: bool = Controls.shown_pad(now)
	var changes: int = 0
	for i: int in 180:
		now += 17
		Controls.last_device = Controls.Device.PAD if i % 2 == 0 else Controls.Device.KEY
		var shown: bool = Controls.shown_pad(now)
		if shown != last:
			changes += 1
			last = shown
	var out: String = ""
	if changes != 0:
		out = "the shown device changed %d times in a 3 s flip" % changes
	Controls.last_device = Controls.Device.PAD
	if out == "" and Controls.shown_pad(now):
		out = "the shown device changed at once"
	if out == "" and Controls.shown_pad(now + 599):
		out = "the shown device changed at 599 ms"
	if out == "" and not Controls.shown_pad(now + 600):
		out = "the shown device did not follow a device held for 600 ms"
	_reset_controls()
	return out


func test_a_settled_device_still_changes_the_wording() -> String:
	_settle_on()
	var dome: Node = _open()
	await _frame()
	var before: String = _hint(dome).text
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	await (Engine.get_main_loop() as SceneTree).create_timer(0.7).timeout
	var after: String = _hint(dome).text
	_close(dome)
	return "" if after != before and after.contains("View") else "the line did not take the pad wording: %s" % after


func test_the_pad_line_is_not_longer_than_the_keyboard_line() -> String:
	var keys: String = DomeScript.default_hint()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var pad: String = DomeScript.default_hint()
	_reset_controls()
	return "" if pad.length() <= keys.length() and pad.contains("View") else "pad line (%d) vs keys (%d): %s" % [pad.length(), keys.length(), pad]


## Every direction from every usable clickable, followed to the end.
func _reach(dome: Node) -> Array[Clickable]:
	var usable: Array[Clickable] = dome.call("usable_clickables")
	var reached: Array[Clickable] = []
	if usable.is_empty():
		return reached
	dome.set("_pad_pick", null)
	dome.call("pad_step", Vector2.RIGHT)
	var start: Clickable = dome.get("_pad_pick") as Clickable
	var queue: Array[Clickable] = [start]
	reached.append(start)
	while not queue.is_empty():
		var at: Clickable = queue.pop_front()
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			dome.set("_pad_pick", at)
			dome.call("pad_step", direction)
			var next: Clickable = dome.get("_pad_pick") as Clickable
			if next != null and not next in reached:
				reached.append(next)
				queue.append(next)
	return reached


func test_every_usable_clickable_is_reachable_and_a_disabled_one_is_skipped() -> String:
	var dome: Node = _open()
	await _frame()
	var usable: Array[Clickable] = dome.call("usable_clickables")
	var board: Clickable = dome.get_node("%PlanBoardClick") as Clickable
	var out: String = ""
	if usable.size() < 4 or not board in usable:
		out = "expected several usable clickables with the plan board among them, found %d" % usable.size()
	if out == "":
		var reached: Array[Clickable] = _reach(dome)
		for item: Clickable in usable:
			if not item in reached:
				out = "the pad cannot reach %s" % item.name
				break
	if out == "":
		board.enabled = false
		var reached_without: Array[Clickable] = _reach(dome)
		var expected: int = usable.size() - 1
		if board in reached_without:
			out = "the disabled plan board was picked"
		elif reached_without.size() != expected:
			out = "with one disabled the pad reached %d of %d" % [reached_without.size(), expected]
		for item: Clickable in reached_without:
			if not item.enabled:
				out = "stepped onto a disabled clickable: %s" % item.name
	_close(dome)
	return out


func test_a_pick_that_becomes_disabled_is_dropped_and_not_used() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var bench: Clickable = dome.get_node("%BenchClick") as Clickable
	var clicks: Array[int] = [0]
	bench.clicked.connect(func() -> void: clicks[0] += 1)
	dome.set("_pad_pick", bench)
	await _frame()
	bench.enabled = false
	await _send(_button(JOY_BUTTON_A))
	await _frame()
	var out: String = ""
	if clicks[0] != 0:
		out = "A used a pick that was disabled"
	elif dome.get("_pad_pick") != null:
		out = "the disabled pick was kept"
	elif _hint(dome).text != String(dome.get("_default_text")):
		out = "the line did not fall back to the default: %s" % _hint(dome).text
	bench.enabled = true
	await _frame()
	if out == "" and dome.get("_pad_pick") != null:
		out = "the old pick came back when it was enabled again"
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


func test_a_fast_flick_across_and_back_steps_every_time() -> String:
	var dome: Node = _open()
	await _frame()
	var out: String = ""
	var steps: Array = []
	for value: float in [0.9, -0.9, 0.9]:
		steps.append(dome.call("_stick_direction", _stick(JOY_AXIS_LEFT_X, value)))
	if steps != [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.RIGHT]:
		out = "a flick across and back gave %s" % str(steps)
	_close(dome)
	return out


func test_a_stick_let_go_inside_a_panel_does_not_block_the_next_push() -> String:
	var dome: Node = _open()
	await _frame()
	var out: String = ""
	if dome.call("_stick_direction", _stick(JOY_AXIS_LEFT_X, 0.9)) != Vector2i.RIGHT:
		out = "the first push did not step"
	var bench_ui: CalBenchUI = dome.get_node("%CalBenchUI") as CalBenchUI
	bench_ui.open()
	await _frame()
	await _frame()
	# The stick comes back to rest while the panel is open: the lab sees nothing.
	bench_ui.hide()
	await _frame()
	if out == "" and dome.call("_stick_direction", _stick(JOY_AXIS_LEFT_X, 0.9)) != Vector2i.RIGHT:
		out = "the push after the panel did not step"
	_close(dome)
	return out


func test_a_diagonal_push_steps_once() -> String:
	var dome: Node = _open()
	await _frame()
	var x: Vector2i = dome.call("_stick_direction", _stick(JOY_AXIS_LEFT_X, 0.7))
	var y: Vector2i = dome.call("_stick_direction", _stick(JOY_AXIS_LEFT_Y, 0.7))
	_close(dome)
	return "" if x != Vector2i.ZERO and y == Vector2i.ZERO else "a diagonal push gave %s then %s" % [x, y]


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
	await _send(_button(JOY_BUTTON_A))
	var out: String = ""
	if not named:
		out = "the hint does not name the pick: %s" % said
	elif clicks[0] != 100:
		out = "interact did not click only the pick (%d)" % clicks[0]
	_close(dome)
	return out


func test_a_toast_does_not_hide_the_pick() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	dome.set("_pad_pick", dome.get_node("%AirlockClick"))
	dome.call("_toast", "A passing message")
	await _frame()
	var said: String = _hint(dome).text
	_close(dome)
	return "" if said.contains("A passing message") and said.contains("to use") else "a toast hid the pick: %s" % said


func test_mouse_motion_hands_the_hint_back_but_a_pixel_of_drift_does_not() -> String:
	var dome: Node = _open()
	await _frame()
	dome.set("_pad_pick", dome.get_node("%BenchClick"))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(1, 0)
	motion.position = Vector2(100, 100)
	dome.call("_input", motion)
	var drifted: bool = dome.get("_pad_pick") == null
	motion.relative = Vector2(8, 0)
	dome.call("_input", motion)
	var cleared: bool = dome.get("_pad_pick") == null
	_close(dome)
	if drifted:
		return "a pixel of mouse drift dropped the pick"
	return "" if cleared else "mouse motion left the pad's pick in place"


## Pad events (no D-pad, which picks) through the loaded dome leave the bottom
## line and the focus alone.
func test_pad_events_through_input_leave_the_lab_still() -> String:
	var dome: Node = _open()
	await _frame()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	await _frame()
	var hint: Label = _hint(dome)
	var before: String = hint.text
	var owners: Dictionary = {}
	for i: int in 30:
		for event: InputEvent in [_stick(JOY_AXIS_RIGHT_X, 0.8), _stick(JOY_AXIS_RIGHT_Y, -0.8),
				_stick(JOY_AXIS_TRIGGER_LEFT, 1.0), _stick(JOY_AXIS_TRIGGER_RIGHT, 1.0),
				_button(JOY_BUTTON_X), _button(JOY_BUTTON_Y)]:
			Input.parse_input_event(event)
		await _frame()
		owners[str(_root().gui_get_focus_owner())] = true
		if hint.text != before:
			break
	var out: String = ""
	if hint.text != before:
		out = "the line moved: %s" % hint.text
	elif owners.size() > 1 or _root().gui_get_focus_owner() != null:
		out = "the focus owner moved: %s" % str(owners.keys())
	_close(dome)
	return out


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
