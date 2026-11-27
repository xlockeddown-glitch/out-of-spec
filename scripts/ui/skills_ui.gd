class_name SkillsUI
extends Control
## The skills view: the lab's level, then each skill's level, XP and what it does. K opens and closes
## it on the farm and in the dome. While the player holds an XP certificate it shows a button that
## opens the picker (XpCertificateUI) over it.

const TEAL: Color = Color("38E1C6")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)

var _rows: VBoxContainer
var _close_button: Button
var _picker: XpCertificateUI


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
	GameState.lab_xp_changed.connect(_on_xp_changed.bind("", ""))
	GameState.xp_certificates_changed.connect(_on_xp_changed.bind("", ""))
	_picker = XpCertificateUI.new()
	add_child(_picker)
	_picker.visibility_changed.connect(_on_picker_shown_or_hidden)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(&"open_skills")
	if not visible:
		if toggled:
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		# Esc or K steps back in the picker first: from its question, then out.
		if _picker.visible:
			_picker.step_back()
		else:
			hide()
	# No key press reaches the farm or the scene swap behind the view. Driving
	# polls Input, so the rover still answers.
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_picker.hide()
	_refresh()
	show()
	_close_button.grab_focus()


func _on_xp_changed(_player_id: String, _skill_id: String) -> void:
	if visible:
		_refresh()


## While the picker is open the buttons under it take no focus, so no key or
## pad reaches them. When it closes, by Esc or its BACK, focus comes back here.
func _on_picker_shown_or_hidden() -> void:
	_refresh()
	if visible and not _picker.visible:
		_close_button.grab_focus()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(PlanBoardUI._label(GameState.lab_text(), TEXT, 20))
	_rows.add_child(PlanBoardUI._label("    " + GameState.lab_effects_text(), DIM, 16))
	for id: String in GameState.skill_ids():
		_rows.add_child(PlanBoardUI._label(GameState.skill_text(id), TEXT, 20))
		_rows.add_child(PlanBoardUI._label("    " + GameState.skill_effects_text(id), DIM, 16))
	var under: Control.FocusMode = Control.FOCUS_NONE if _picker.visible else Control.FOCUS_ALL
	_close_button.focus_mode = under
	var held: int = _picker.spendable().size()
	if held > 0:
		var spend: Button = PlanBoardUI._button("SPEND AN XP CERTIFICATE  (%s held)" % SP811.integer(held))
		spend.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		spend.focus_mode = under
		spend.pressed.connect(_picker.open)
		_rows.add_child(spend)
