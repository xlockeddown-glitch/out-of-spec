class_name SkillsUI
extends Control
## The skills view: each skill's level, XP and what it does. K opens and closes
## it on the farm and in the dome.

const TEAL: Color = Color("38E1C6")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)

var _rows: VBoxContainer
var _close_button: Button


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
	column.add_child(PlanBoardUI._label("SKILLS", TEAL, 30))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	column.add_child(_rows)
	_close_button = PlanBoardUI._button("CLOSE  (K or Esc)")
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	column.add_child(_close_button)
	GameState.skill_xp_changed.connect(_on_xp_changed)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = key != null and key.pressed and not key.echo and key.keycode == KEY_K
	if not visible:
		if toggled:
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		hide()
	# No key press reaches the farm or the scene swap behind the view. Driving
	# polls Input, so the rover still answers.
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	show()
	_close_button.grab_focus()


func _on_xp_changed(_player_id: String, _skill_id: String) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for id: String in GameState.skill_ids():
		_rows.add_child(PlanBoardUI._label(GameState.skill_text(id), TEXT, 20))
		_rows.add_child(PlanBoardUI._label("    " + GameState.skill_effects_text(id), DIM, 16))
