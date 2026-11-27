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
## The lab sitter's line and button (zones section 9, build step 11).
var _sitter_label: Label
var _sitter_button: Button
var _close_button: Button
var _focus_before: Control
## The zone whose warning was shown, so the next press on it goes.
var _warned: String = ""
var _going: bool = false
## True while a booking waits for the host.
var _booking: bool = false
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
	column.add_child(PlanBoardUI._label(LabSitter.text("title"), TEAL, 20))
	var sitter := HBoxContainer.new()
	_sitter_label = PlanBoardUI._label("", TEXT, 18)
	_sitter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sitter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sitter.add_child(_sitter_label)
	_sitter_button = PlanBoardUI._button(LabSitter.text("book"))
	_sitter_button.pressed.connect(_on_book_sitter)
	sitter.add_child(_sitter_button)
	column.add_child(sitter)
	_status = PlanBoardUI._label("", TEXT, 18)
	column.add_child(_status)
	_close_button = PlanBoardUI._button("%s  (Esc)" % FastTravel.text("close"))
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	GameState.rover_place_changed.connect(_on_place_changed)
	GameState.lab_sitter_changed.connect(_on_sitter_changed)
	GameState.one_use_changed.connect(_refresh_sitter)
	GameClock.day_started.connect(_on_day_started)
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
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func open() -> void:
	if QuestsUI.other_panel_open(get_tree(), self):
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	_warned = ""
	_status.text = ""
	_refresh()
	_refresh_sitter()
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
	if _going or _booking:
		return
	var id: String = str(place["id"])
	var warning: String = str(place["warning"])
	if warning != "" and _warned != id and not TunnelRecall.closed(GameClock.elapsed_days):
		_warned = id
		_status.text = "%s %s" % [warning, FastTravel.text("warn_again")]
		return
	_going = true
	FastTravel.pending = true
	_refresh_sitter()
	var problem: String = await FarmCommands.request(&"fast_travel", [id])
	if not is_inside_tree():
		FastTravel.pending = false
		return
	if problem != "":
		_going = false
		FastTravel.pending = false
		_status.text = problem
		_refresh_sitter()
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
	_refresh_sitter()
	if GameState.rover_zone != id:
		_status.text = FastTravel.text("no_zone")
		return
	close()
	SceneSwitcher.go_to(SceneSwitcher.TUNNELS_SCENE)


## Her booking changed (here or from a teammate): an old refusal is stale.
func _on_sitter_changed() -> void:
	_status.text = ""
	_refresh_sitter()


## A new day moves "tomorrow", so the row is told again.
func _on_day_started(_day: int) -> void:
	_refresh_sitter()


## The day a booking made now would cover, as this screen shows it.
func _sitter_day() -> int:
	return LabSitter.booked_day(GameClock.get_day_index())


## What the sitter's line says: she is booked for a day, or what a day of her
## costs (nothing, if the farm holds the free day).
func _refresh_sitter() -> void:
	if not is_instance_valid(_sitter_label):
		return
	var booked: bool = LabSitter.is_booked(GameState.lab_sitter)
	if booked:
		_sitter_label.text = LabSitter.text("row_booked") % [LabSitter.sitter_name(), SP811.integer(int(GameState.lab_sitter["day"]))]
	else:
		var free: bool = GameState.one_use_count(GameState.ONE_USE_SITTER, GameState.local_player_id) > 0
		var price: String = LabSitter.text("free_text") if free else LabSitter.text("fee_text") % SP811.integer(LabSitter.fee())
		_sitter_label.text = LabSitter.text("offer_text") % [LabSitter.sitter_name(), SP811.integer(_sitter_day()), price]
	_sitter_button.disabled = booked or _booking or _going
	if _sitter_button.disabled and _sitter_button.has_focus():
		_close_button.grab_focus()


## The host books her for the day the row showed; a refusal is shown as it came.
func _on_book_sitter() -> void:
	if _booking or _going:
		return
	_booking = true
	_refresh_sitter()
	var problem: String = await FarmCommands.request(&"book_lab_sitter", [_sitter_day()])
	_booking = false
	if not is_inside_tree():
		return
	_warned = ""
	_status.text = problem
	_refresh_sitter()
