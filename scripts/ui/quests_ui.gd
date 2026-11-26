class_name QuestsUI
extends Control
## The quests view (docs/design/quests_levels_story.md section 5.5, build step
## 7): the player's open quests, each with its giver, its title and the step to
## do next, then the ones done. O opens and closes it on the farm, in the dome
## and in the tunnels, as K does the skills view, whose look this copies, but
## not while another panel is open. It
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
const KEEPSAKES_TITLE: String = "KEEPSAKES"
## Every panel that takes the whole screen joins this group when it is made.
const MODAL_GROUP: StringName = &"modal_panel"
const MORE: String = "+%s more"

var _rows: VBoxContainer
var _close_button: Button
## What had the focus when the view opened: it gets it back.
var _focus_before: Control


func _ready() -> void:
	add_to_group(MODAL_GROUP)
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
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	GameState.quests_changed.connect(_on_changed)
	# The contract's run is a count the list shows.
	GameState.credibility_changed.connect(_on_changed.unbind(1))
	hide()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = key != null and key.pressed and not key.echo and key.keycode == KEY
	if not visible:
		# Not over another panel: it has the keys while it is open.
		if toggled and not other_panel_open(get_tree(), self):
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		close()
	# As in SkillsUI: no key press reaches the farm behind the view.
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_focus_before = get_viewport().gui_get_focus_owner()
	_refresh()
	show()
	_close_button.grab_focus()


## Hides the view and gives the focus back to what had it before open().
func close() -> void:
	hide()
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_inside_tree() and before.is_visible_in_tree():
		before.grab_focus()
	elif _close_button.has_focus():
		_close_button.release_focus()


## Whether a panel that takes the screen is open: any node of MODAL_GROUP shown
## in the tree. `except` (this view) is not looked at.
static func other_panel_open(tree: SceneTree, except: Node = null) -> bool:
	for node: Node in tree.get_nodes_in_group(MODAL_GROUP):
		if node != except and node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
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
	var latest: Dictionary = QuestLog.latest_done(done_rows)
	for row: Dictionary in latest["rows"]:
		_rows.add_child(PlanBoardUI._label("    " + QuestLog.title_text(row), DIM, 16))
	if int(latest["more"]) > 0:
		_rows.add_child(PlanBoardUI._label("    " + MORE % SP811.integer(int(latest["more"])), DIM, 16))
	# The keepsakes this player holds, as the shelf in the dome shows them.
	var kept: Array[String] = QuestEngine.keepsakes_of(GameState, GameState.local_player_id)
	if not kept.is_empty():
		_rows.add_child(PlanBoardUI._label(KEEPSAKES_TITLE, DIM, 20))
	for id: String in kept:
		_rows.add_child(PlanBoardUI._label("    " + QuestEngine.keepsake_name(id), DIM, 16))
