class_name ControlsGuideUI
extends Control
## The controls guide: every verb in plain English, grouped, with its key and its
## pad button, read from the InputMap (Controls). F1 opens and closes it, or the
## pad's actions menu (LB + RB, then CONTROLS). It copies the look of the skills view.
## It never opens over another panel (the minigames too), and while it is open no
## key or pad press reaches the farm behind it, and the rover and the walker stand
## still. The pad scrolls it with the D-pad or stick.

const TEAL: Color = SkillsUI.TEAL
const TEXT: Color = SkillsUI.TEXT
const DIM: Color = SkillsUI.DIM
## [PLACEHOLDER] words.
const TITLE: String = "CONTROLS"
const CHORD_LINE: String = "LB + RB together open the actions menu: the verbs that have no button of their own."
## How fast the D-pad, the stick or the arrow keys scroll it, px per second
## (the stick scrolls slower the less it is pushed).
const SCROLL_SPEED: float = 600.0
## [PLACEHOLDER] The groups, in the order shown. Each line is a verb and its action;
## "actions" is a run of actions shown as one line (the buy keys).
const GROUPS: Array[Dictionary] = [
	{ "title": "DRIVING", "lines": [
		{ "verb": "Drive forward", "action": &"rover_forward" },
		{ "verb": "Reverse", "action": &"rover_reverse" },
		{ "verb": "Steer left", "action": &"rover_steer_left" },
		{ "verb": "Steer right", "action": &"rover_steer_right" },
		{ "verb": "Re-zero the steering", "action": &"rover_zero_steering" },
		{ "verb": "Lights low or on (the tunnels)", "action": &"rover_lights" },
		{ "verb": "Swap farm and dome", "action": &"swap_scene" },
		{ "verb": "Use what is in front of you (Bram's bay)", "action": &"interact" },
	] },
	{ "title": "ON FOOT", "lines": [
		{ "verb": "Get out of the rover, or back in", "action": &"get_out_in" },
		{ "verb": "Walk (forward, left, back, right)", "move": [
			&"rover_forward", &"rover_steer_left", &"rover_reverse", &"rover_steer_right"] },
		{ "verb": "Jump (on Phobos and Deimos)", "action": &"rover_till" },
		{ "verb": "Tether on or off (moons: flat steps, no jump)", "action": &"moon_tether" },
	] },
	{ "title": "FARMING", "lines": [
		{ "verb": "Drill, till, plant or harvest", "action": &"rover_till" },
		{ "verb": "Next seed", "action": &"cycle_seed" },
		{ "verb": "Set point down", "action": &"setpoint_down" },
		{ "verb": "Set point up", "action": &"setpoint_up" },
		{ "verb": "Survey for ore", "action": &"survey" },
		{ "verb": "Check against a block", "action": &"check_block" },
		{ "verb": "Build a block stack", "action": &"block_stack" },
	] },
	{ "title": "BUILDING AND STONE", "lines": [
		{ "verb": "Dig the ground in front", "action": &"rover_dig" },
		{ "verb": "Fill the ground in front", "action": &"rover_fill" },
		{ "verb": "Place or take up a stone piece", "action": &"place_stone" },
		{ "verb": "Next stone piece", "action": &"stone_kind" },
	] },
	{ "title": "MENUS", "lines": [
		{ "verb": "Pause", "action": &"open_pause" },
		{ "verb": "Quests", "action": &"open_quests" },
		{ "verb": "Skills", "action": &"open_skills" },
		{ "verb": "Tool roll (what you hold)", "action": &"inventory" },
		{ "verb": "Character and tractor (name, looks, parts)", "action": &"open_picker" },
		{ "verb": "Co-op", "action": &"open_coop" },
		{ "verb": "Robots (at Bram's bay)", "action": &"open_robots" },
		{ "verb": "This guide", "action": &"open_controls" },
		{ "verb": "Pick the button in focus", "action": &"ui_accept" },
		{ "verb": "Close a panel", "action": &"ui_cancel" },
	] },
	{ "title": "SHOPPING", "lines": [
		{ "verb": "Sell the harvest to Lin (at Bram's bay)", "action": &"sell_lin" },
		{ "verb": "Wheel service (at Bram's bay)", "action": &"wheel_service" },
		{ "verb": "Buy Bram's standards 1 to 9 (press twice)", "actions": [
			&"buy_1", &"buy_2", &"buy_3", &"buy_4", &"buy_5", &"buy_6", &"buy_7", &"buy_8", &"buy_9"] },
	] },
]
const VERB_WIDTH: float = 520.0
const KEY_WIDTH: float = 150.0

var _scroll: ScrollContainer
var _rows: VBoxContainer
var _close_button: Button
## What had the focus when the guide opened: it gets it back.
var _focus_before: Control
## The rover's input block as it was when the guide opened: it goes back to that.
var _blocked_before: bool = false
var _scroll_carry: float = 0.0


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label(TITLE, TEAL, 30))
	column.add_child(PlanBoardUI._label(CHORD_LINE, DIM, 18))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 460)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(_rows)
	_close_button = PlanBoardUI._button("CLOSE  (%s or %s)" % [Controls.key_label(Controls.CONTROLS_ACTION), Controls.key_label(&"ui_cancel")])
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	hide()


## The D-pad, the stick and the arrow keys scroll it smoothly while held.
func _process(delta: float) -> void:
	if not visible:
		return
	var axis: float = Input.get_axis(&"ui_up", &"ui_down")
	if is_zero_approx(axis):
		_scroll_carry = 0.0
		return
	# Keep the part of a pixel that int() would drop, so a light push still moves.
	_scroll_carry += axis * SCROLL_SPEED * delta
	var whole: int = int(_scroll_carry)
	_scroll_carry -= float(whole)
	_scroll.scroll_vertical += whole


## Taken before the button's focus moves: up and down only scroll.
func _input(event: InputEvent) -> void:
	if visible and (event.is_action(&"ui_down") or event.is_action(&"ui_up")):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(Controls.CONTROLS_ACTION)
	if not visible:
		# Not over another panel: it has the keys while it is open.
		if toggled and not QuestsUI.other_panel_open(get_tree(), self):
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	# As in SkillsUI: no key or pad press reaches the farm behind the view.
	elif key != null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func open() -> void:
	# Opening again while open must not save our own block as the old state.
	if not visible:
		_blocked_before = RoverController.input_blocked
		_focus_before = get_viewport().gui_get_focus_owner()
	RoverController.input_blocked = true
	_scroll_carry = 0.0
	_refresh()
	show()
	_scroll.scroll_vertical = 0
	_close_button.grab_focus()


## Hides the view and gives the focus back to what had it before open().
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


## If the guide is torn down while open, the rover gets its controls back.
func _exit_tree() -> void:
	if visible:
		RoverController.input_blocked = _blocked_before


## Every action the guide lists.
static func listed_actions() -> Array[StringName]:
	var all: Array[StringName] = []
	for group: Dictionary in GROUPS:
		for line: Dictionary in group["lines"]:
			if line.has("actions"):
				all.append_array(line["actions"])
			elif line.has("move"):
				all.append_array(line["move"])
			else:
				all.append(line["action"])
	return all


## The key text of a line: a run of actions shows its first and last ("1 to 9").
static func key_text(line: Dictionary) -> String:
	if line.has("actions"):
		var run: Array = line["actions"]
		return "%s to %s" % [Controls.key_label(run[0]), Controls.key_label(run[run.size() - 1])]
	if line.has("move"):
		var keys: PackedStringArray = []
		for action: StringName in line["move"]:
			keys.append(Controls.key_label(action))
		return " ".join(keys)
	return Controls.key_labels(line["action"])


## The pad text of a line: "menu" for the verbs the actions menu carries.
static func pad_text(line: Dictionary) -> String:
	if line.has("move"):
		return "LS"
	var action: StringName = line["actions"][0] if line.has("actions") else line["action"]
	var pad: String = Controls.pad_label(action)
	return pad if pad != "" else "menu"


func _refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(_line("", "KEY", "PAD", DIM, 16))
	for group: Dictionary in GROUPS:
		_rows.add_child(PlanBoardUI._label(group["title"], TEAL, 20))
		for entry: Dictionary in group["lines"]:
			_rows.add_child(_line(entry["verb"], key_text(entry), pad_text(entry), TEXT, 18))


func _line(verb: String, key: String, pad: String, color: Color, size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var words: Label = PlanBoardUI._label("    " + verb if verb != "" else "", color, size)
	words.custom_minimum_size.x = VERB_WIDTH
	row.add_child(words)
	var keys: Label = PlanBoardUI._label(key, color, size)
	keys.custom_minimum_size.x = KEY_WIDTH
	row.add_child(keys)
	var pads: Label = PlanBoardUI._label(pad, color, size)
	pads.custom_minimum_size.x = KEY_WIDTH
	pads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pads)
	return row
