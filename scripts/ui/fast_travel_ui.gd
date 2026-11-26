class_name FastTravelUI
extends Control
## The dome console's panel (docs/design/zones.md section 8.1, build step 7):
## the zones a player can go to, each with a button. It looks like QuestsUI. The
## soft gate (section 7.1) is one more press: a place the lab level is under says
## why, and the second press goes. The command is the host's (`fast_travel`); the
## screen then changes to the zone's scene. Esc closes it.

const TEAL: Color = SkillsUI.TEAL
const TEXT: Color = SkillsUI.TEXT
const DIM: Color = SkillsUI.DIM
## How long a guest waits for the host's farm to show the new place.
const WAIT_S: float = 3.0

var _rows: VBoxContainer
var _status: Label
var _close_button: Button
var _focus_before: Control
## The zone whose warning was shown, so the next press on it goes.
var _warned: String = ""
var _going: bool = false
## The destinations the rows were built from, so a rover update that changes none
## of them leaves the rows (and the button with focus) alone.
var _shown: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label(FastTravel.text("title"), TEAL, 30))
	column.add_child(PlanBoardUI._label(FastTravel.text("hint"), DIM, 18))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	column.add_child(_rows)
	_status = PlanBoardUI._label("", TEXT, 18)
	column.add_child(_status)
	_close_button = PlanBoardUI._button("%s  (Esc)" % FastTravel.text("close"))
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	GameState.rover_place_changed.connect(_on_place_changed)
	hide()


## The unlock list may arrive while the panel is open (a teammate's first visit).
## Only a change in what can be chosen rebuilds the rows; a teammate's depth change
## does not take focus off a button.
func _on_place_changed() -> void:
	if visible and not _going and _places() != _shown:
		_refresh()


func _places() -> Array[Dictionary]:
	return FastTravel.destinations(GameState.lab_level(), GameState.zones_unlocked)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	if QuestsUI.other_panel_open(get_tree(), self):
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	_warned = ""
	_status.text = ""
	_refresh()
	show()
	_close_button.grab_focus()


func close() -> void:
	hide()
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_inside_tree() and before.is_visible_in_tree():
		before.grab_focus()
	elif _close_button.has_focus():
		_close_button.release_focus()


## Builds the rows again. A button that had focus keeps it: the one in the same row,
## or the last row if there are fewer now (the close button when there are none).
func _refresh() -> void:
	var focused: int = -1
	var owner_now: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for i: int in _rows.get_child_count():
		if owner_now != null and _rows.get_child(i).is_ancestor_of(owner_now):
			focused = i
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_shown = _places()
	if _shown.is_empty():
		_rows.add_child(PlanBoardUI._label(FastTravel.text("none"), DIM, 20))
		if focused >= 0:
			_close_button.grab_focus()
		return
	var buttons: Array[Button] = []
	for place: Dictionary in _shown:
		var row := HBoxContainer.new()
		var name_label: Label = PlanBoardUI._label(str(place["name"]), TEXT, 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var go: Button = PlanBoardUI._button(FastTravel.text("go"))
		go.pressed.connect(_on_go.bind(place))
		row.add_child(go)
		_rows.add_child(row)
		buttons.append(go)
	if focused >= 0:
		buttons[mini(focused, buttons.size() - 1)].grab_focus()


func _on_go(place: Dictionary) -> void:
	if _going:
		return
	var id: String = str(place["id"])
	var warning: String = str(place["warning"])
	if warning != "" and _warned != id and not TunnelRecall.closed(GameClock.elapsed_days):
		_warned = id
		_status.text = "%s %s" % [warning, FastTravel.text("warn_again")]
		return
	_going = true
	FastTravel.pending = true
	var problem: String = await FarmCommands.request(&"fast_travel", [id])
	if not is_inside_tree():
		FastTravel.pending = false
		return
	if problem != "":
		_going = false
		FastTravel.pending = false
		_status.text = problem
		return
	# A guest's copy of the farm may come after the host's yes.
	var waited: float = 0.0
	while GameState.rover_zone != id and waited < WAIT_S:
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree():
			FastTravel.pending = false
			return
		waited += 0.1
	_going = false
	FastTravel.pending = false
	if GameState.rover_zone != id:
		_status.text = FastTravel.text("no_zone")
		return
	close()
	SceneSwitcher.go_to(SceneSwitcher.TUNNELS_SCENE)
