class_name PadKeyboard
extends Control
## Reusable Meridiani Scope on-screen keyboard for controller text entry.
## D-pad or left stick moves the highlighted key with edge wrap; A presses the
## key; B deletes (or closes when empty); Start or Done finishes. Mouse clicks
## on keys work as well. Uses ScopeTheme colours only. Every layout, size and
## word below is a [PLACEHOLDER].

signal text_changed(value: String)
signal finished(value: String)
signal cancelled()

const TITLE: String = "ENTER NAME"
const KEY_SHIFT: String = "SHIFT"
const KEY_SPACE: String = "SPACE"
const KEY_BACKSPACE: String = "BACK"
const KEY_DONE: String = "DONE"
const SPACE_LABEL: String = "SPACE"
const BACKSPACE_LABEL: String = "BACKSPACE"
const DONE_LABEL: String = "DONE"
const SHIFT_LABEL: String = "SHIFT"
const CURSOR_MARK: String = "_"

## Key rows in order [PLACEHOLDER].
const KEY_ROWS: Array = [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
	["a", "s", "d", "f", "g", "h", "j", "k", "l"],
	[KEY_SHIFT, "z", "x", "c", "v", "b", "n", "m", "-", "'"],
	[KEY_SPACE, KEY_BACKSPACE, KEY_DONE],
]

## Panel width, in pixels [PLACEHOLDER].
const PANEL_WIDTH: float = 820.0
## Vertical separation between sections, in pixels [PLACEHOLDER].
const SECTION_SEPARATION: int = 10
## Separation between key rows and keys, in pixels [PLACEHOLDER].
const KEY_SEPARATION: int = 6
## Standard key minimum size, in pixels [PLACEHOLDER].
const KEY_SIZE := Vector2(64.0, 48.0)
## Wide action key minimum size, in pixels [PLACEHOLDER].
const ACTION_KEY_SIZE := Vector2(180.0, 48.0)
## Title font size, in pixels [PLACEHOLDER].
const TITLE_FONT_SIZE: int = 24
## Buffer preview font size, in pixels [PLACEHOLDER].
const BUFFER_FONT_SIZE: int = 26
## Counter and prompt font size, in pixels [PLACEHOLDER].
const PROMPT_FONT_SIZE: int = 16
## Key label font size, in pixels [PLACEHOLDER].
const KEY_FONT_SIZE: int = 20
## Highlight border width, in pixels [PLACEHOLDER].
const HIGHLIGHT_BORDER: int = 4
## Key corner radius, in pixels [PLACEHOLDER].
const KEY_RADIUS: int = 8
## Key content margin, in pixels [PLACEHOLDER].
const KEY_MARGIN: int = 6
## Left stick step and rest thresholds (matching dome_interior) [PLACEHOLDER].
const STICK_STEP: float = 0.6
const STICK_REST: float = 0.35

var _buffer: String = ""
var _max_length: int = Loadout.MAX_NAME
var _caps: bool = false
var _row: int = 0
var _col: int = 0
var _stick_held: Vector2i = Vector2i.ZERO

var _buffer_label: Label
var _count_label: Label
var _prompt_label: Label
var _buttons: Array = []
var _normal_style: StyleBoxFlat
var _highlight_style: StyleBoxFlat
var _shift_on_style: StyleBoxFlat


func _init() -> void:
	name = &"PadKeyboard"


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	theme = ScopeTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal_style = ScopeTheme.box(ScopeTheme.ENAMEL_INSET, ScopeTheme.ENAMEL_LIP, 2, KEY_RADIUS, KEY_MARGIN)
	_highlight_style = ScopeTheme.box(ScopeTheme.GLASS_CARD, ScopeTheme.TEAL, HIGHLIGHT_BORDER, KEY_RADIUS, KEY_MARGIN)
	_shift_on_style = ScopeTheme.box(ScopeTheme.GLASS_CARD, ScopeTheme.AMBER, 3, KEY_RADIUS, KEY_MARGIN)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = ScopeTheme.SHELL
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", SECTION_SEPARATION)
	panel.add_child(column)

	var header := PanelContainer.new()
	header.theme_type_variation = ScopeTheme.HEADER
	var title := Label.new()
	title.text = TITLE
	title.theme_type_variation = ScopeTheme.TITLE
	title.add_theme_font_size_override(&"font_size", TITLE_FONT_SIZE)
	header.add_child(title)
	column.add_child(header)

	var glass := PanelContainer.new()
	glass.theme_type_variation = ScopeTheme.GLASS
	column.add_child(glass)
	var buf_row := HBoxContainer.new()
	glass.add_child(buf_row)
	_buffer_label = PlanBoardUI._label("", ScopeTheme.INK, BUFFER_FONT_SIZE)
	_buffer_label.name = &"BufferLabel"
	_buffer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buf_row.add_child(_buffer_label)
	_count_label = PlanBoardUI._label("", ScopeTheme.INK_MUTED, PROMPT_FONT_SIZE)
	_count_label.name = &"CountLabel"
	buf_row.add_child(_count_label)

	var card := PanelContainer.new()
	card.theme_type_variation = ScopeTheme.PHONE_CARD
	column.add_child(card)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override(&"separation", KEY_SEPARATION)
	card.add_child(rows_box)

	for r: int in KEY_ROWS.size():
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override(&"separation", KEY_SEPARATION)
		rows_box.add_child(hbox)
		var row_buttons: Array[Button] = []
		var tokens: Array = KEY_ROWS[r]
		for c: int in tokens.size():
			var token: String = str(tokens[c])
			var btn := Button.new()
			btn.name = "Key_%d_%d" % [r, c]
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = ACTION_KEY_SIZE if r == KEY_ROWS.size() - 1 else KEY_SIZE
			btn.add_theme_font_size_override(&"font_size", KEY_FONT_SIZE)
			btn.pressed.connect(_on_button_clicked.bind(r, c))
			hbox.add_child(btn)
			row_buttons.append(btn)
		_buttons.append(row_buttons)

	_prompt_label = PlanBoardUI._label("", ScopeTheme.CARD_INK_MUTED, PROMPT_FONT_SIZE)
	_prompt_label.name = &"PromptLabel"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_prompt_label)

	_refresh_visuals()
	hide()


func _process(_delta: float) -> void:
	if visible:
		_refresh_prompts()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return
	var viewport: Viewport = get_viewport()
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X:
			_handle_stick_axis(motion.axis_value, true)
		elif motion.axis == JOY_AXIS_LEFT_Y:
			_handle_stick_axis(motion.axis_value, false)
		viewport.set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_up") or _is_pad_button(event, JOY_BUTTON_DPAD_UP):
		move(-1, 0)
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_down") or _is_pad_button(event, JOY_BUTTON_DPAD_DOWN):
		move(1, 0)
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_left") or _is_pad_button(event, JOY_BUTTON_DPAD_LEFT):
		move(0, -1)
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or _is_pad_button(event, JOY_BUTTON_DPAD_RIGHT):
		move(0, 1)
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") or _is_pad_button(event, JOY_BUTTON_A):
		press_current()
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") or _is_pad_button(event, JOY_BUTTON_B):
		_on_cancel_pressed()
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"open_pause") or _is_pad_button(event, JOY_BUTTON_START):
		finish()
		viewport.set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton:
		viewport.set_input_as_handled()


## Opens the keyboard with `initial` text up to `max_length` characters.
func open(initial: String = "", max_length: int = Loadout.MAX_NAME) -> void:
	_max_length = maxi(max_length, 1)
	_buffer = initial.left(_max_length)
	_caps = false
	_row = 1
	_col = 0
	_stick_held = Vector2i.ZERO
	_refresh_visuals()
	_refresh_prompts()
	show()


## Hides the keyboard without emitting finished or cancelled.
func close() -> void:
	_stick_held = Vector2i.ZERO
	hide()


## Moves the highlighted key by `(dr, dc)` with wrap-around at edges.
func move(dr: int, dc: int) -> void:
	if dr != 0:
		_row = posmod(_row + dr, KEY_ROWS.size())
		var row_len: int = (KEY_ROWS[_row] as Array).size()
		_col = mini(_col, row_len - 1)
	if dc != 0:
		var row_len: int = (KEY_ROWS[_row] as Array).size()
		_col = posmod(_col + dc, row_len)
	_refresh_visuals()


## Presses the currently highlighted key.
func press_current() -> void:
	press_key(current_token())


## Presses a key by its token (e.g. "a", "0", "-", "'", KEY_SHIFT, KEY_SPACE, KEY_BACKSPACE, KEY_DONE).
func press_key(token: String) -> void:
	match token:
		KEY_SHIFT:
			toggle_shift()
		KEY_SPACE:
			_append_char(" ")
		KEY_BACKSPACE:
			backspace()
		KEY_DONE:
			finish()
		_:
			var ch: String = token.to_upper() if _caps else token.to_lower()
			_append_char(ch)


## Toggles uppercase/lowercase for A–Z keys.
func toggle_shift() -> void:
	_caps = not _caps
	_refresh_visuals()


## Deletes the last character from the buffer if non-empty.
func backspace() -> void:
	if _buffer.is_empty():
		return
	_buffer = _buffer.left(_buffer.length() - 1)
	_refresh_visuals()
	text_changed.emit(_buffer)


## Closes the keyboard and emits finished with the current buffer.
func finish() -> void:
	close()
	finished.emit(_buffer)


func text() -> String:
	return _buffer


func cursor() -> Vector2i:
	return Vector2i(_col, _row)


func current_token() -> String:
	return str((KEY_ROWS[_row] as Array)[_col])


func is_shifted() -> bool:
	return _caps


func _on_cancel_pressed() -> void:
	if _buffer.is_empty():
		close()
		cancelled.emit()
	else:
		backspace()


func _on_button_clicked(r: int, c: int) -> void:
	_row = r
	_col = c
	_refresh_visuals()
	press_current()


func _append_char(ch: String) -> void:
	if _buffer.length() >= _max_length:
		return
	_buffer += ch
	_refresh_visuals()
	text_changed.emit(_buffer)


func _handle_stick_axis(value: float, horizontal: bool) -> void:
	var prev: int = _stick_held.x if horizontal else _stick_held.y
	var next: int = prev
	if value >= STICK_STEP:
		next = 1
	elif value <= -STICK_STEP:
		next = -1
	elif absf(value) <= STICK_REST:
		next = 0
	if next != prev:
		if horizontal:
			_stick_held.x = next
			if next != 0:
				move(0, next)
		else:
			_stick_held.y = next
			if next != 0:
				move(next, 0)


static func _is_pad_button(event: InputEvent, button_index: JoyButton) -> bool:
	if not event is InputEventJoypadButton:
		return false
	var pad := event as InputEventJoypadButton
	return pad.pressed and pad.button_index == button_index


func _key_display(token: String) -> String:
	match token:
		KEY_SHIFT:
			return SHIFT_LABEL + (" *" if _caps else "")
		KEY_SPACE:
			return SPACE_LABEL
		KEY_BACKSPACE:
			return BACKSPACE_LABEL
		KEY_DONE:
			return DONE_LABEL
		_:
			return token.to_upper() if _caps else token.to_lower()


func _refresh_visuals() -> void:
	if _buffer_label != null:
		_buffer_label.text = _buffer + CURSOR_MARK
	if _count_label != null:
		_count_label.text = "%d / %d" % [_buffer.length(), _max_length]
	for r: int in _buttons.size():
		var row_buttons: Array = _buttons[r]
		var tokens: Array = KEY_ROWS[r]
		for c: int in row_buttons.size():
			var btn: Button = row_buttons[c] as Button
			var token: String = str(tokens[c])
			btn.text = _key_display(token)
			var selected: bool = (r == _row and c == _col)
			var style: StyleBoxFlat = _highlight_style if selected else (_shift_on_style if token == KEY_SHIFT and _caps else _normal_style)
			for state: StringName in [&"normal", &"hover", &"pressed"]:
				btn.add_theme_stylebox_override(state, style)
			var ink: Color = ScopeTheme.TEAL if selected else (ScopeTheme.AMBER if token == KEY_SHIFT and _caps else ScopeTheme.CARD_INK)
			for cname: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
				btn.add_theme_color_override(cname, ink)


func _refresh_prompts() -> void:
	if _prompt_label == null:
		return
	var press_p: String = Controls.prompt(&"ui_accept")
	var back_p: String = Controls.prompt(&"ui_cancel")
	var done_p: String = Controls.prompt(&"open_pause")
	_prompt_label.text = "%s: Type  ·  %s: Backspace / Close  ·  %s: Done" % [press_p, back_p, done_p]
