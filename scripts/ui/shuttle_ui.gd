class_name ShuttleUI
extends Control
## The landing pad terminal's panel (biomes.md section 6 step 12): one launch
## window line for each moon, the fare, whether the farm holds the shuttle license
## and a Book button for each moon. A press sends `book_shuttle` for one person and
## shows the reason it came back with. Until the moons have a hub (zones step 17)
## that reason is always "no hub yet". It looks like FastTravelUI. Esc closes it.

const TEAL: Color = SkillsUI.TEAL
const TEXT: Color = SkillsUI.TEXT
const DIM: Color = SkillsUI.DIM
## People on a booking made here [PLACEHOLDER].
const PARTY: int = 1

var _lines: VBoxContainer
var _status: Label
var _close_button: Button
var _focus_before: Control
var _busy: bool = false


## The panel's lines for a farm at `elapsed_days`: a window line for each moon, the
## fare, then the license line. Tests and the panel both use this.
static func lines(elapsed_days: float, licensed: bool) -> Array[String]:
	var out: Array[String] = []
	for moon: String in Shuttle.MOONS:
		out.append(Shuttle.window_line(moon, elapsed_days))
	out.append(Shuttle.text("terminal_fare") % SP811.integer(Shuttle.fare()))
	out.append(Shuttle.text("terminal_licensed") if licensed else Shuttle.text("terminal_unlicensed"))
	return out


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
	column.add_child(PlanBoardUI._label(Shuttle.text("terminal_title"), TEAL, 30))
	column.add_child(PlanBoardUI._label(Shuttle.text("terminal_hint"), DIM, 18))
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override(&"separation", 6)
	column.add_child(_lines)
	var books := HBoxContainer.new()
	books.name = "Books"
	books.add_theme_constant_override(&"separation", 12)
	for moon: String in Shuttle.MOONS:
		var book: Button = PlanBoardUI._button(Shuttle.text("terminal_book") % Shuttle.moon_name(moon))
		book.name = "Book_" + moon
		book.pressed.connect(_on_book.bind(moon))
		books.add_child(book)
	column.add_child(books)
	_status = PlanBoardUI._label("", TEXT, 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_close_button = PlanBoardUI._button("%s  (%s)" % [Shuttle.text("terminal_close"), Controls.key_label(&"ui_cancel")])
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	hide()


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


func _refresh() -> void:
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line: String in lines(GameClock.elapsed_days, GameState.shuttle_licensed):
		var label: Label = PlanBoardUI._label(line, TEXT, 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lines.add_child(label)


## Asks the host for a seat; the reason it refuses with is shown as it came.
func _on_book(moon: String) -> void:
	if _busy:
		return
	_busy = true
	var problem: String = await FarmCommands.request(&"book_shuttle", [moon, PARTY])
	_busy = false
	if not is_inside_tree():
		return
	_status.text = problem
	_refresh()
