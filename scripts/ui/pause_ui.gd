class_name PauseUI
extends Control
## Esc on the farm: a small panel with RESUME and SAVE AND QUIT. With no other
## player connected it really pauses the game and says PAUSED. With others
## connected the farm is shared and runs on, so it says MENU. It sits first
## among its siblings so an open panel takes the Esc before it does, and it
## moves to the front while open so the HUD can't be clicked through it.

var _title: Label
var _text: Label
var _note: Label
var _resume_button: Button
var _quit_button: Button
## True after the first press of QUIT that warned the guests.
var _armed: bool = false
## Writes the farm: returns "" or why not. Replaceable in tests.
var saver: Callable
## Ends the game. Replaceable in tests.
var quitter: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not saver.is_valid():
		saver = SaveGame.write
	if not quitter.is_valid():
		quitter = func() -> void: get_tree().quit()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	_title = PlanBoardUI._label("PAUSED", RobotsUI.TEAL, 30)
	column.add_child(_title)
	_text = PlanBoardUI._label("", RobotsUI.DIM, 18)
	column.add_child(_text)
	_note = PlanBoardUI._label("", RobotsUI.AMBER, 20)
	column.add_child(_note)
	_resume_button = PlanBoardUI._button("RESUME  (Esc)")
	_resume_button.pressed.connect(close)
	column.add_child(_resume_button)
	_quit_button = PlanBoardUI._button("SAVE AND QUIT")
	_quit_button.pressed.connect(_on_quit)
	column.add_child(_quit_button)
	CoopSession.player_joined.connect(_on_players_changed.unbind(1))
	CoopSession.player_left.connect(_on_players_changed.unbind(1))
	CoopSession.lost.connect(_on_lost)
	hide()


func _exit_tree() -> void:
	RoverController.input_blocked = false
	if get_tree() != null and visible:
		get_tree().paused = false


## Only this player is here: nobody to keep the farm running for.
static func is_alone() -> bool:
	return not CoopSession.is_guest() and CoopSession.players.size() <= 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()
	elif visible and (event is InputEventKey or event is InputEventJoypadButton):
		# No key reaches the farm behind the panel.
		get_viewport().set_input_as_handled()


func open() -> void:
	_armed = false
	_note.text = ""
	var alone: bool = is_alone()
	_apply(alone)
	_text.text = _body(alone)
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	show()
	_resume_button.grab_focus()


## The link dropped: nothing is left to keep running for, so the menu closes.
func _on_lost() -> void:
	if visible:
		close()


func _on_players_changed() -> void:
	if visible:
		# The guests it warned about may be other ones now.
		_armed = false
		_note.text = ""
		_apply(is_alone())
		_text.text = _body(is_alone())


## Pauses the game and says PAUSED when alone; otherwise MENU, and the game runs
## on with this screen's driving keys blocked.
func _apply(alone: bool) -> void:
	_title.text = "PAUSED" if alone else "MENU"
	if is_inside_tree():
		get_tree().paused = alone
	RoverController.input_blocked = is_inside_tree() and not alone


func _body(alone: bool) -> String:
	if FarmCommands.guest:
		_quit_button.text = "QUIT"
		return "The farm runs on and is saved on the host's computer."
	_quit_button.text = "SAVE AND QUIT"
	var lead: String = "The game is paused. " if alone else "The farm runs on. "
	return lead + "It saves each morning and when you quit here or close the window."


func close() -> void:
	RoverController.input_blocked = false
	if is_inside_tree():
		get_tree().paused = false
	hide()
	if get_parent() != null:
		get_parent().move_child(self, 0)


func _on_quit() -> void:
	if FarmCommands.guest:
		quitter.call()
		return
	if CoopSession.players.size() > 1 and not _armed:
		_armed = true
		_note.text = "Guests will be dropped. Press again to save and quit."
		return
	if SaveGame.farm_open:
		var problem: String = saver.call()
		if problem != "":
			_note.text = "SAVE FAILED: " + problem
			return
	quitter.call()
