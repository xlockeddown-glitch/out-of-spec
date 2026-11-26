class_name PauseUI
extends Control
## Esc on the farm: a small panel with RESUME and SAVE AND QUIT. It does not
## stop the clock (the farm is shared in co-op). It sits first among its
## siblings, so any open panel takes the Esc before it does.

var _note: Label
var _resume_button: Button
var _quit_button: Button


func _ready() -> void:
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
	column.add_child(PlanBoardUI._label("PAUSED", RobotsUI.TEAL, 30))
	column.add_child(PlanBoardUI._label(
		"The clock keeps running. The farm saves each morning and when you quit here or close the window.",
		RobotsUI.DIM, 18))
	_note = PlanBoardUI._label("", RobotsUI.AMBER, 20)
	column.add_child(_note)
	_resume_button = PlanBoardUI._button("RESUME  (Esc)")
	_resume_button.pressed.connect(hide)
	column.add_child(_resume_button)
	_quit_button = PlanBoardUI._button("QUIT" if FarmCommands.guest else "SAVE AND QUIT")
	_quit_button.pressed.connect(_on_quit)
	column.add_child(_quit_button)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		hide()
	else:
		open()


func open() -> void:
	_note.text = ""
	show()
	_resume_button.grab_focus()


## A guest has nothing of its own to save: the host saves.
func _on_quit() -> void:
	if not FarmCommands.guest and SaveGame.farm_open:
		var problem: String = SaveGame.write()
		if problem != "":
			_note.text = "SAVE FAILED: " + problem
			return
	get_tree().quit()
