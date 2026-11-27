class_name ActionsMenuUI
extends Control
## The pad's actions menu: the verbs that have a key but no button of their own
## (place a stone, check with a block, survey, the bay, quests, skills, co-op).
## LB and RB pressed together open it. D-pad or stick moves, A picks, B closes.
## A pick sends the same named action the key sends, so it does exactly what the
## key does, refusals included. Keyboard players don't need it.

## [PLACEHOLDER] Opened by LB and RB together (pad buttons 9 and 10).
const CHORD_TEXT: String = "LB + RB"
## A lone shoulder press waits this long for the other, s.
const CHORD_GRACE_S: float = 0.12
const TEAL: Color = SkillsUI.TEAL
const TEXT: Color = SkillsUI.TEXT
const DIM: Color = SkillsUI.DIM
## [PLACEHOLDER] words. In the order they are shown.
const ENTRIES: Array[Dictionary] = [
	{ "action": &"place_stone", "label": "PLACE A STONE" },
	{ "action": &"check_block", "label": "CHECK WITH A BLOCK" },
	{ "action": &"block_stack", "label": "BUILD A BLOCK STACK" },
	{ "action": &"survey", "label": "SURVEY" },
	{ "action": &"sell_lin", "label": "SELL TO LIN (at Bram's bay)" },
	{ "action": &"wheel_service", "label": "WHEEL SERVICE (at Bram's bay)" },
	{ "action": &"open_robots", "label": "ROBOTS (at Bram's bay)" },
	{ "action": &"open_quests", "label": "QUESTS" },
	{ "action": &"open_skills", "label": "SKILLS" },
	{ "action": &"open_coop", "label": "CO-OP" },
]
## Bram's standards: one entry for each in his catalog, at the bay.
const BUY_ACTIONS: Array[StringName] = [
	&"buy_1", &"buy_2", &"buy_3", &"buy_4", &"buy_5", &"buy_6", &"buy_7", &"buy_8", &"buy_9"]
## What the dome and the tunnels have: no farm verbs there.
const PANEL_ACTIONS: Array[StringName] = [&"open_quests", &"open_skills", &"open_coop"]

## The actions this scene offers.
var offered: Array[StringName] = []
## Sends one action. Replaceable in tests.
var sender: Callable
var _rows: VBoxContainer
var _close_button: Button
var _focus_before: Control
var _blocked_before: bool = false
var _lb_held: bool = false
var _rb_held: bool = false


func _init(actions: Array[StringName] = []) -> void:
	offered = actions


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	if not sender.is_valid():
		sender = _send
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label("ACTIONS", TEAL, 30))
	column.add_child(PlanBoardUI._label("A picks, B closes.", DIM, 18))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	column.add_child(_rows)
	_close_button = PlanBoardUI._button("CLOSE  (B)")
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	hide()


func _exit_tree() -> void:
	if visible:
		RoverController.input_blocked = _blocked_before


## Everything the farm offers: the entries, then Bram's standards.
static func farm_actions() -> Array[StringName]:
	var all: Array[StringName] = []
	for entry: Dictionary in ENTRIES:
		all.append(entry["action"])
	all.append_array(BUY_ACTIONS)
	return all


## The action each row sends: the entries this scene offers, then Bram's standards.
func rows() -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		if offered.has(entry["action"]):
			made.append(entry)
	if offered.has(&"buy_1") and GameState.tier1_unlocked:
		var catalog: Array[String] = GameState.bram_catalog()
		for i: int in mini(catalog.size(), BUY_ACTIONS.size()):
			made.append({ "action": BUY_ACTIONS[i],
				"label": "BUY %s (at Bram's bay)" % GameState.instrument_name(catalog[i], true) })
	return made


## Opens on LB and RB held together; keeps count of the two.
func _input(event: InputEvent) -> void:
	var pad := event as InputEventJoypadButton
	if pad == null:
		return
	var down: bool = pad.pressed
	if pad.button_index == JOY_BUTTON_LEFT_SHOULDER:
		_lb_held = down
	elif pad.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		_rb_held = down
	else:
		return
	if down and _lb_held and _rb_held and not visible and not QuestsUI.other_panel_open(get_tree(), self):
		get_viewport().set_input_as_handled()
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
	# No key or pad press reaches the farm behind the menu.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_focus_before = get_viewport().gui_get_focus_owner()
	_blocked_before = RoverController.input_blocked
	# The stick moves the menu's focus, not the rover.
	RoverController.input_blocked = true
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var first: Button = null
	for row: Dictionary in rows():
		var button: Button = PlanBoardUI._button(row["label"])
		button.set_meta(&"action", row["action"])
		button.pressed.connect(_pick.bind(row["action"]))
		_rows.add_child(button)
		if first == null:
			first = button
	show()
	(first if first != null else _close_button).grab_focus()


func close() -> void:
	if visible:
		RoverController.input_blocked = _blocked_before
	hide()
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_inside_tree() and before.is_visible_in_tree():
		before.grab_focus()
	elif _close_button.has_focus():
		_close_button.release_focus()


func _pick(action: StringName) -> void:
	close()
	sender.call(action)


## Sends a press and a release of the action, as the key would, one frame on.
func _send(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.call_deferred(&"parse_input_event", event)
