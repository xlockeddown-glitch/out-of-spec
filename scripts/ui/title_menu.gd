extends Control
## Title screen: continue the saved farm, start a new one or join a friend's. The clock is
## stopped here; it runs once a farm opens.

const COLOR_TEXT := Color(0.8, 0.86, 0.82)
const COLOR_BACKGROUND := Color(0.06, 0.07, 0.065)
const FONT_TITLE: int = 72
const FONT_TEXT: int = 22
const BUTTON_SIZE := Vector2(420.0, 56.0)
const NOTE_WIDTH: float = 720.0

## The save checked when the menu opened (SaveGame.check()).
var _save: Dictionary = {}
var _starting: bool = false
var _note: Label
var _main_buttons: VBoxContainer
var _confirm_buttons: VBoxContainer
var _join_buttons: VBoxContainer
var _address: LineEdit
var _join_button: Button


func _ready() -> void:
	# No farm's scene is open here, so a friend's farm is left for good.
	CoopSession.leave()
	GameClock.seconds_per_day = GameClock.DEFAULT_SECONDS_PER_DAY
	GameClock.paused = true
	CoopSession.joined.connect(_on_joined.unbind(1))
	CoopSession.refused.connect(_on_refused)
	CoopSync.farm_ready.connect(_on_farm_ready)
	_save = SaveGame.check()
	_build()
	_show_main()
	var note: String = CoopScenes.take_note()
	if note != "":
		_note.text = note


func _build() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var title := Label.new()
	title.text = "OUT OF SPEC"
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", DriftingSensor.COLOR_IN_BAND)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_note = Label.new()
	_note.custom_minimum_size.x = NOTE_WIDTH
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", FONT_TEXT)
	_note.add_theme_color_override("font_color", COLOR_TEXT)
	column.add_child(_note)
	_main_buttons = _button_box(column)
	if _save.has("data"):
		_button(_main_buttons, "CONTINUE (DAY %d)" % SaveGame.day_of(_save["data"]), _on_continue)
	_button(_main_buttons, "NEW FARM", _on_new_farm)
	_button(_main_buttons, "JOIN A FRIEND", _show_join)
	_button(_main_buttons, "QUIT", get_tree().quit)
	_confirm_buttons = _button_box(column)
	_button(_confirm_buttons, "START A NEW FARM", _start_new)
	_button(_confirm_buttons, "BACK", _show_main)
	_join_buttons = _button_box(column)
	_address = LineEdit.new()
	_address.placeholder_text = "Your friend's IP address"
	_address.custom_minimum_size = BUTTON_SIZE
	_address.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_address.add_theme_font_size_override("font_size", FONT_TEXT)
	_address.text_submitted.connect(_on_join.unbind(1))
	_join_buttons.add_child(_address)
	_button(_join_buttons, "JOIN", _on_join)
	_join_button = _join_buttons.get_child(1) as Button
	_button(_join_buttons, "BACK", _on_join_back)


func _button_box(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(box)
	return box


func _button(parent: Node, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", FONT_TEXT)
	button.pressed.connect(on_pressed)
	parent.add_child(button)


func _show_main() -> void:
	_main_buttons.visible = true
	_confirm_buttons.visible = false
	_join_buttons.visible = false
	_note.text = note_for(_save)
	(_main_buttons.get_child(0) as Button).grab_focus()


## What the menu says about the save; "" when there is nothing to say.
static func note_for(save: Dictionary) -> String:
	var problem: String = save.get("problem", "")
	if problem == "":
		return ""
	if save.has("data"):
		return "The newest save did not load: %s Continue opens the save before it." % problem
	return "The saved farm did not load: %s" % problem


func _on_continue() -> void:
	if _starting:
		return
	_open(SaveGame.continue_farm())


func _on_new_farm() -> void:
	if not SaveGame.exists():
		_start_new()
		return
	_main_buttons.visible = false
	_confirm_buttons.visible = true
	_note.text = "The saved farm will be set aside, and Continue will open the new farm instead."
	(_confirm_buttons.get_child(1) as Button).grab_focus()


func _start_new() -> void:
	if _starting:
		return
	_open(SaveGame.start_new())


func _show_join() -> void:
	_main_buttons.visible = false
	_join_buttons.visible = true
	_note.text = "Your friend opens their farm, presses %s and hosts it. Your own saved farm is not touched." % Controls.key_label(&"open_coop")
	_set_joining(false)
	_address.grab_focus()


func _set_joining(joining: bool) -> void:
	_address.editable = not joining
	_join_button.disabled = joining


func _on_join() -> void:
	if _starting or _join_button.disabled:
		return
	var problem: String = CoopSession.join(_address.text.strip_edges())
	_set_joining(problem == "")
	_note.text = problem if problem != "" else "Asking to join."


func _on_join_back() -> void:
	if _starting:
		return
	CoopSession.leave()
	_show_main()


func _on_joined() -> void:
	_note.text = "Joined. Getting the farm."


func _on_refused(reason: String) -> void:
	CoopSession.leave()
	_set_joining(false)
	_note.text = reason


func _on_farm_ready() -> void:
	_starting = true
	_note.text = "Opening the farm."


func _open(problem: String) -> void:
	if problem != "":
		# Built again: the saved farm may not be what it was.
		for child: Node in get_children():
			remove_child(child)
			child.queue_free()
		_save = SaveGame.check()
		_build()
		_show_main()
		_note.text = problem
		return
	_starting = true
	GameClock.paused = false
	SceneSwitcher.go_to(SaveGame.open_scene)
