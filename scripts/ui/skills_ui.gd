class_name SkillsUI
extends Control
## The skills view: the lab's level, then each skill's level, XP and what it does. K opens and closes
## it on the farm and in the dome. While the player holds an XP certificate it shows a button that
## opens the picker (XpCertificateUI) over it.

const TEAL: Color = ScopeTheme.TEAL
const TEXT: Color = ScopeTheme.INK
const DIM: Color = ScopeTheme.INK_MUTED

var _rows: VBoxContainer
var _close_button: Button
var _picker: XpCertificateUI
var _glyph: Label


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	theme = ScopeTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = ScopeTheme.SHELL
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	var header := PanelContainer.new()
	header.theme_type_variation = ScopeTheme.HEADER
	var title := Label.new()
	title.text = "SKILLS"
	title.theme_type_variation = ScopeTheme.TITLE
	title.add_theme_font_size_override(&"font_size", 30)
	header.add_child(title)
	column.add_child(header)
	var glass := PanelContainer.new()
	glass.theme_type_variation = ScopeTheme.GLASS
	column.add_child(glass)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	glass.add_child(_rows)
	_close_button = ScopeTheme.button("CLOSE  (%s or %s)" % [Controls.key_label(&"open_skills"), Controls.key_label(&"ui_cancel")], 22)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	_glyph = ScopeTheme.badge(&"ui_cancel")
	_close_button.add_child(_glyph)
	column.add_child(_close_button)
	GameState.skill_xp_changed.connect(_on_xp_changed)
	GameState.lab_xp_changed.connect(_on_xp_changed.bind("", ""))
	GameState.xp_certificates_changed.connect(_on_xp_changed.bind("", ""))
	_picker = XpCertificateUI.new()
	add_child(_picker)
	_picker.visibility_changed.connect(_on_picker_shown_or_hidden)
	hide()


func _process(_delta: float) -> void:
	if visible:
		ScopeTheme.refresh_badge(_glyph)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(&"open_skills")
	if not visible:
		# Not over another panel (the controls guide, a minigame, ...).
		if toggled and not QuestsUI.other_panel_open(get_tree(), self):
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
	if key != null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
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
	_rows.add_child(_skill_card(GameState.lab_text(), GameState.lab_effects_text(), ScopeTheme.TEAL))
	for id: String in GameState.skill_ids():
		_rows.add_child(_skill_card(GameState.skill_text(id), GameState.skill_effects_text(id)))
	var under: Control.FocusMode = Control.FOCUS_NONE if _picker.visible else Control.FOCUS_ALL
	_close_button.focus_mode = under
	var held: int = _picker.spendable().size()
	if held > 0:
		var spend: Button = ScopeTheme.button("SPEND AN XP CERTIFICATE  (%s held)" % SP811.integer(held), 20)
		spend.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		spend.focus_mode = under
		spend.pressed.connect(_picker.open)
		_rows.add_child(spend)


func _skill_card(heading: String, detail: String, edge: Color = ScopeTheme.GLASS_LINE) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = ScopeTheme.CARD
	if edge != ScopeTheme.GLASS_LINE:
		card.add_theme_stylebox_override(&"panel", ScopeTheme.card_box(edge))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	card.add_child(box)
	box.add_child(ScopeTheme.label(heading, TEXT, 20))
	box.add_child(ScopeTheme.label("    " + detail, DIM, 16))
	return card
