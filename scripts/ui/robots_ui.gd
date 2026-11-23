class_name RobotsUI
extends Control
## Robots at Bram's bay: order one, see what its sensors still need, release it.
## The order button is pressed twice.

const TEAL: Color = Color("38E1C6")
const AMBER: Color = Color("F5A623")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)

var _funds: Label
var _rows: VBoxContainer
var _result: Label
var _close_button: Button
## The frame whose order button has been pressed once.
var _armed_id: String = ""


func _ready() -> void:
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
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label("ROBOTS", TEAL, 30))
	column.add_child(PlanBoardUI._label("A new robot's sensors are uncalibrated. Each needs a traceable, passing calibration at the bench before the robot is released.", DIM, 18))
	_funds = PlanBoardUI._label("", TEXT, 20)
	column.add_child(_funds)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_rows)
	_result = PlanBoardUI._label("", AMBER, 20)
	column.add_child(_result)
	_close_button = PlanBoardUI._button("CLOSE  (Esc)")
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	column.add_child(_close_button)
	GameState.robots_changed.connect(_on_robots_changed)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		hide()
	# No key press reaches the farm or the scene swap behind the view.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_armed_id = ""
	_result.text = ""
	_refresh()
	show()
	_focus_row("")


func _on_robots_changed() -> void:
	if visible:
		_refresh()
		_focus_row("")


func _refresh() -> void:
	_funds.text = "You have %s CR, %s crystal ore and %s silk." % [SP811.integer(GameState.credits),
		SP811.integer(GameState.crystal_ore), SP811.integer(GameState.optical_silk_spools)]
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for frame: Dictionary in DataManager.get_records(&"robots", "frames"):
		_rows.add_child(_order_row(frame))
	for id: Variant in GameState.robots:
		_add_robot_rows(str(id))


func _order_row(frame: Dictionary) -> Button:
	var id: String = frame["id"]
	var button: Button = PlanBoardUI._button("")
	button.set_meta(&"row", id)
	var text: String = "%s, %s" % [frame["display_name"], GameState.robot_cost_text(id)]
	button.text = ("PRESS AGAIN TO BUILD: %s" if id == _armed_id else "BUILD %s") % text
	button.pressed.connect(_on_order_pressed.bind(id))
	return button


func _add_robot_rows(id: String) -> void:
	var robot: Dictionary = GameState.robots[id]
	match robot["state"]:
		"assembling":
			_rows.add_child(PlanBoardUI._label("%s: assembling, ready the morning of day %s" % [
				robot["name"], SP811.integer(robot["done_day"])], TEXT, 20))
		"released":
			_rows.add_child(PlanBoardUI._label("%s: released" % robot["name"], TEAL, 20))
			_add_card_rows(id)
		_:
			_rows.add_child(PlanBoardUI._label("%s: commissioning" % robot["name"], AMBER, 20))
			for sensor_id: String in GameState.robot_sensor_ids(id):
				var problem: String = GameState.robot_sensor_problem(sensor_id)
				_rows.add_child(PlanBoardUI._label("    %s: %s" % [GameState.instrument_name(sensor_id, true),
					"ready" if problem == "" else problem], DIM if problem == "" else AMBER, 18))
			var release: Button = PlanBoardUI._button("RELEASE %s" % robot["name"])
			release.set_meta(&"row", id)
			release.pressed.connect(_on_release_pressed.bind(id))
			_rows.add_child(release)


## A released robot's job cards, top to bottom, then the cards it can be given.
func _add_card_rows(id: String) -> void:
	var cards: Array = GameState.robot_cards(id)
	for i: int in cards.size():
		_add_card_button("REMOVE CARD %s: %s" % [SP811.integer(i + 1), GameState.robot_card_text(cards[i])],
			"%s remove %d" % [id, i], GameState.remove_robot_card.bind(id, i), "Card removed.")
	if cards.size() >= GameState.robot_card_slots():
		return
	_add_card_button("ADD CARD: WATER all plots at 06:00 every day", id + " clock",
		GameState.add_robot_card.bind(id, "clock"), "Card added.")
	_add_card_button("ADD CARD: WATER all plots when the soil reads off target", id + " soil",
		GameState.add_robot_card.bind(id, "soil"), "Card added.")


func _add_card_button(text: String, row: String, action: Callable, done: String) -> void:
	var button: Button = PlanBoardUI._button(text)
	button.set_meta(&"row", row)
	button.pressed.connect(_on_card_pressed.bind(row, action, done))
	_rows.add_child(button)


func _on_card_pressed(row: String, action: Callable, done: String) -> void:
	_armed_id = ""
	_show_result(action.call(), done)
	_refresh()
	_focus_row(row)


func _on_order_pressed(id: String) -> void:
	var problem: String = GameState.robot_build_problem(id)
	if problem == "" and _armed_id != id:
		_armed_id = id
		_result.text = ""
	else:
		_armed_id = ""
		if problem == "":
			problem = GameState.build_robot(id)
		_show_result(problem, "Ordered.")
	_refresh()
	_focus_row(id)


func _on_release_pressed(id: String) -> void:
	_armed_id = ""
	_show_result(GameState.release_robot(id), "Released.")
	_refresh()
	_focus_row(id)


func _show_result(problem: String, done: String) -> void:
	_result.text = problem if problem != "" else done
	_result.add_theme_color_override(&"font_color", AMBER if problem != "" else TEAL)


## Keyboard and gamepad focus: the row for `id`, else the first one.
func _focus_row(id: String) -> void:
	var target: Button = _close_button
	for child: Node in _rows.get_children():
		var row := child as Button
		if row == null:
			continue
		if row.get_meta(&"row") == id:
			target = row
			break
		if target == _close_button:
			target = row
	target.grab_focus()
