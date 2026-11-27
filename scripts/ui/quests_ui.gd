class_name QuestsUI
extends Control
## The quests view (docs/design/quests_levels_story.md section 5.5, build step
## 7): the player's open quests, each with its giver, its title and the step to
## do next, then the ones done. O opens and closes it on the farm, in the dome
## and in the tunnels, as K does the skills view, whose look this copies, but
## not while another panel is open. It
## only shows what QuestLog reads from the farm, so a guest sees the host's word.

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
## [PLACEHOLDER] The tag on a quest not seen yet.
const NEW_TAG: String = "NEW"

var _rows: VBoxContainer
var _close_button: Button
## What had the focus when the view opened: it gets it back.
var _focus_before: Control
## The open rows the list showed last.
var _open_rows: Array = []
var _glyph: Label


func _ready() -> void:
	add_to_group(MODAL_GROUP)
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
	title.text = TITLE
	title.theme_type_variation = ScopeTheme.TITLE
	title.add_theme_font_size_override(&"font_size", 30)
	header.add_child(title)
	column.add_child(header)
	var glass := PanelContainer.new()
	glass.theme_type_variation = ScopeTheme.GLASS
	column.add_child(glass)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	glass.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_close_button = Button.new()
	_close_button.text = "CLOSE  (%s or %s)" % [Controls.key_label(&"open_quests"), Controls.key_label(&"ui_cancel")]
	_close_button.add_theme_font_size_override(&"font_size", 22)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	_glyph = ScopeTheme.badge(&"ui_cancel")
	_close_button.add_child(_glyph)
	column.add_child(_close_button)
	GameState.quests_changed.connect(_on_changed)
	# The contract's run is a count the list shows.
	GameState.credibility_changed.connect(_on_changed.unbind(1))
	hide()


func _process(_delta: float) -> void:
	if visible:
		ScopeTheme.refresh_badge(_glyph)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(&"open_quests")
	if not visible:
		# Not over another panel: it has the keys while it is open.
		if toggled and not other_panel_open(get_tree(), self):
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		close()
	# As in SkillsUI: no key press reaches the farm behind the view.
	if key != null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func open() -> void:
	_focus_before = get_viewport().gui_get_focus_owner()
	_refresh()
	show()
	_close_button.grab_focus()


## Hides the view and gives the focus back to what had it before open().
func close() -> void:
	if visible:
		# What the player has now looked at is no longer new.
		QuestSeen.mark_seen(_open_rows)
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
	# A rebuild must not strand a pad: remember which stop had the focus.
	var focused: int = -1
	var stops: Array[Node] = _rows.get_children().filter(func(n: Node) -> bool: return n is Control and (n as Control).focus_mode == Control.FOCUS_ALL)
	var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner != null:
		focused = stops.find(owner)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var lists: Dictionary = QuestLog.of(GameState, GameState.local_player_id)
	var open_rows: Array = lists[QuestLog.OPEN]
	_open_rows = open_rows
	var done_rows: Array = lists[QuestLog.DONE]
	if open_rows.is_empty():
		_rows.add_child(_text(NONE_OPEN, TEXT, 20))
	for row: Dictionary in open_rows:
		_rows.add_child(_card(row))
	# DONE and KEEPSAKES are focus stops too, so a pad or keys can scroll to them.
	if not done_rows.is_empty():
		var done: VBoxContainer = VBoxContainer.new()
		done.add_child(_text(DONE_TITLE, DIM, 20))
		var latest: Dictionary = QuestLog.latest_done(done_rows)
		for row: Dictionary in latest["rows"]:
			done.add_child(_text("    " + QuestLog.title_text(row), DIM, 16))
		if int(latest["more"]) > 0:
			done.add_child(_text("    " + MORE % SP811.integer(int(latest["more"])), DIM, 16))
		_rows.add_child(_stop(done, &"DoneStop"))
	# The keepsakes this player holds, as the shelf in the dome shows them.
	var kept: Array[String] = QuestEngine.keepsakes_of(GameState, GameState.local_player_id)
	if not kept.is_empty():
		var shelf: VBoxContainer = VBoxContainer.new()
		shelf.add_child(_text(KEEPSAKES_TITLE, DIM, 20))
		for id: String in kept:
			shelf.add_child(_text("    " + QuestEngine.keepsake_name(id), DIM, 16))
		_rows.add_child(_stop(shelf, &"KeepsakesStop"))
	var now: Array[Node] = _rows.get_children().filter(func(n: Node) -> bool: return n is Control and (n as Control).focus_mode == Control.FOCUS_ALL)
	# A long list runs past the scroll area, so up from CLOSE (and down from the
	# last stop) are joined by hand: the search by position would not find them.
	if now.is_empty():
		_close_button.focus_neighbor_top = NodePath()
	else:
		var last: Control = now[now.size() - 1] as Control
		_close_button.focus_neighbor_top = _close_button.get_path_to(last)
		last.focus_neighbor_bottom = last.get_path_to(_close_button)
	if focused >= 0:
		if not now.is_empty():
			(now[mini(focused, now.size() - 1)] as Control).grab_focus()
		else:
			_close_button.grab_focus()


## A block of text a pad or the keys can stop on (and so scroll to), with the big ring.
func _stop(content: Control, stop_name: StringName) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.name = stop_name
	holder.theme_type_variation = ScopeTheme.CARD
	holder.focus_mode = Control.FOCUS_ALL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(content)
	_add_ring(holder)
	return holder


func _add_ring(holder: PanelContainer) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override(&"panel", ScopeTheme.focus_box())
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.name = &"FocusRing"
	ring.hide()
	holder.add_child(ring)
	holder.focus_entered.connect(ring.show)
	holder.focus_exited.connect(ring.hide)


func _text(text: String, color: Color, size: int) -> Label:
	return PlanBoardUI._label(text, color, size)


## One open quest as a card on the glass: title, a NEW tag if unseen, the next step.
## It takes the focus (the big teal ring), so a pad can walk the list.
func _card(row: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = ScopeTheme.CARD
	card.focus_mode = Control.FOCUS_ALL
	var fresh: bool = QuestSeen.is_new(row)
	card.set_meta(&"new", fresh)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 12)
	inner.add_child(top)
	var title := _text(QuestLog.title_text(row), TEXT, 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if fresh:
		var tag: PanelContainer = ScopeTheme.chip(NEW_TAG, ScopeTheme.AMBER, ScopeTheme.AMBER, 18)
		tag.name = &"NewTag"
		top.add_child(tag)
	inner.add_child(_text(QuestLog.step_text(row), DIM, 16))
	_add_ring(card)
	return card
