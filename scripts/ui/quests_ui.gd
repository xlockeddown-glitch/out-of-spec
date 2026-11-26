class_name QuestsUI
extends Control
## The quests view (docs/design/quests_levels_story.md section 5.5, build step
## 7): the player's open quests, each with its giver, its title and the step to
## do next, then the ones done. O opens and closes it on the farm, in the dome
## and in the tunnels, as K does the skills view, whose look this copies. It
## only shows what QuestLog reads from the farm, so a guest sees the host's word.

## Q was Ryan's pick, but on the farm Q is the check with a block.
const KEY: Key = KEY_O
const TEAL: Color = SkillsUI.TEAL
const TEXT: Color = SkillsUI.TEXT
const DIM: Color = SkillsUI.DIM
## [PLACEHOLDER] words.
const TITLE: String = "QUESTS"
const NONE_OPEN: String = "No open quests. A new one comes with the morning."
const DONE_TITLE: String = "DONE"

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
	column.add_child(PlanBoardUI._label(TITLE, TEAL, 30))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	column.add_child(_rows)
	_close_button = PlanBoardUI._button("CLOSE  (O or Esc)")
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	column.add_child(_close_button)
	GameState.quests_changed.connect(_on_changed)
	# The contract's run is a count the list shows.
	GameState.credibility_changed.connect(_on_changed.unbind(1))
	hide()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = key != null and key.pressed and not key.echo and key.keycode == KEY
	if not visible:
		# Not over the skills view: it has the keys while it is open.
		if toggled and not _skills_open():
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		hide()
	# As in SkillsUI: no key press reaches the farm behind the view.
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	show()
	_close_button.grab_focus()


func _skills_open() -> bool:
	if get_parent() == null:
		return false
	for other: Node in get_parent().get_children():
		if other is SkillsUI and (other as SkillsUI).visible:
			return true
	return false


func _on_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var lists: Dictionary = QuestLog.of(GameState, GameState.local_player_id)
	var open_rows: Array = lists[QuestLog.OPEN]
	var done_rows: Array = lists[QuestLog.DONE]
	if open_rows.is_empty():
		_rows.add_child(PlanBoardUI._label(NONE_OPEN, TEXT, 20))
	for row: Dictionary in open_rows:
		_rows.add_child(PlanBoardUI._label(QuestLog.title_text(row), TEXT, 20))
		_rows.add_child(PlanBoardUI._label("    " + QuestLog.step_text(row), DIM, 16))
	if not done_rows.is_empty():
		_rows.add_child(PlanBoardUI._label(DONE_TITLE, DIM, 20))
	for row: Dictionary in done_rows:
		_rows.add_child(PlanBoardUI._label("    " + QuestLog.title_text(row), DIM, 16))
