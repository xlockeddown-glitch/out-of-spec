class_name PlanBoardUI
extends Control
## The dome plan board (upgradeable lab, Ryan, 2026-11-22): grow the lab to
## the next size (credits + crystal ore, a few days), fit a free space out for
## a discipline, or clear a space to change the layout (a cost and downtime).
## Each discipline's spaces are how many of its jobs fit at once; the
## biggest jobs need a large area. Built in code; numbers come from
## data/economy.json ([PLACEHOLDER]).

signal closed

const TEAL: Color = Color("38E1C6")
const AMBER: Color = Color("F5A623")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)

var _size_label: Label
var _build_label: Label
var _grow_button: Button
var _areas_box: VBoxContainer
var _result_label: Label


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()
	GameState.lab_changed.connect(_on_lab_changed)
	GameState.one_use_changed.connect(_on_lab_changed)
	GameState.jobs_changed.connect(_on_lab_changed)
	GameState.credits_changed.connect(_refresh_if_open.unbind(1))
	GameState.ore_changed.connect(_refresh_if_open.unbind(1))
	GameState.lab_xp_changed.connect(_refresh_if_open)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"swap_scene"):
		get_viewport().set_input_as_handled()


func open() -> void:
	_result_label.text = ""
	_refresh()
	show()
	# Keyboard and gamepad players start on the first button they can use.
	var first: Button = _first_usable_button()
	if first != null:
		first.grab_focus()


func _first_usable_button() -> Button:
	if not _grow_button.disabled:
		return _grow_button
	for row: Node in _areas_box.get_children():
		for child: Node in row.get_children():
			if child is Button and not (child as Button).disabled:
				return child as Button
	return null


func close() -> void:
	hide()
	closed.emit()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	panel.add_theme_stylebox_override(&"panel", _panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)

	column.add_child(_label("DOME PLAN BOARD", TEAL, 30))
	_size_label = _label("", TEXT, 22)
	column.add_child(_size_label)
	_build_label = _label("", AMBER, 20)
	column.add_child(_build_label)
	_grow_button = _button("")
	_grow_button.pressed.connect(_on_grow_pressed)
	column.add_child(_grow_button)
	column.add_child(_label("AREAS: each space takes one job at a time. The biggest jobs need a large area.", DIM, 18))
	_areas_box = VBoxContainer.new()
	_areas_box.add_theme_constant_override(&"separation", 6)
	column.add_child(_areas_box)
	_result_label = _label("", AMBER, 20)
	column.add_child(_result_label)
	var close_button: Button = _button("CLOSE  (%s)" % Controls.key_label(&"ui_cancel"))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(close)
	column.add_child(close_button)


## The layout or the jobs changed (a build finished, a job ended, or the
## player acted): an old answer
## on the board no longer holds. The player's own action sets its answer
## right after this.
func _on_lab_changed() -> void:
	if _result_label != null:
		_result_label.text = ""
	_refresh_if_open()


func _refresh_if_open() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var spaces: int = GameState.lab_spaces()
	var free_spaces: int = GameState.lab_free_spaces()
	_size_label.text = "%s: %s space%s, %s free.   You have %s CR and %s crystal ore." % [
		GameState.lab_size_name(), SP811.integer(spaces), "" if spaces == 1 else "s", SP811.integer(free_spaces),
		SP811.integer(GameState.credits), SP811.integer(GameState.crystal_ore)]
	_build_label.text = GameState.lab_build_text()
	_build_label.visible = _build_label.text != ""
	var next: Dictionary = GameState.lab_next_size()
	if next.is_empty():
		_grow_button.text = "The lab is at its largest."
		_grow_button.disabled = true
	elif not GameState.lab_build.is_empty():
		_grow_button.text = "One build at a time: wait for this one to finish."
		_grow_button.disabled = true
	elif GameState.lab_gate_note(GameState.lab_size_gate_id(next)) != "":
		_grow_button.text = "GROW TO %s: %s" % [str(next.get("name", "?")).to_upper(),
			GameState.lab_gate_note(GameState.lab_size_gate_id(next))]
		_grow_button.disabled = true
	else:
		var days: int = int(next.get("build_days", 1))
		_grow_button.text = "GROW TO %s: %s spaces  (%s, %s day%s)" % [str(next.get("name", "?")).to_upper(),
			SP811.integer(int(next.get("areas", 0))),
			GameState.lab_cost_text(int(next.get("credits", 0)), int(next.get("ore", 0))),
			SP811.integer(days), "" if days == 1 else "s"]
		_grow_button.disabled = false
	# The rows are rebuilt, so the button that had keyboard focus gets it back.
	var focus_key: String = ""
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and focused.has_meta(&"focus_key"):
		focus_key = str(focused.get_meta(&"focus_key"))
	for child: Node in _areas_box.get_children():
		_areas_box.remove_child(child)
		child.queue_free()
	var disciplines: Array = GameState.job_disciplines().keys()
	disciplines.sort()
	for discipline: Variant in disciplines:
		_areas_box.add_child(_area_row(str(discipline)))
	if focus_key != "":
		for row: Node in _areas_box.get_children():
			for button: Node in row.get_children():
				if button.has_meta(&"focus_key") and str(button.get_meta(&"focus_key")) == focus_key:
					(button as Control).grab_focus()


func _area_row(discipline: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var spaces: int = GameState.lab_space(discipline)
	var text: String = "%s: no area" % discipline
	if spaces > 0:
		var busy: int = GameState.jobs_in_progress(discipline)
		text = "%s: %s area, %s space%s, %s job%s in progress" % [discipline,
			GameState.lab_area_size(spaces).to_upper(), SP811.integer(spaces), "" if spaces == 1 else "s",
			SP811.integer(busy), "" if busy == 1 else "s"]
	var name_label: Label = _label(text, TEXT if spaces > 0 else DIM, 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var fit: Button = _button("FIT OUT ONE MORE" if spaces > 0 else "FIT OUT")
	fit.tooltip_text = "Give a free space to %s (free of charge)." % discipline
	fit.set_meta(&"focus_key", "fit:" + discipline)
	fit.pressed.connect(_on_fit_pressed.bind(discipline))
	row.add_child(fit)
	var clear: Button = _button("CLEAR ONE")
	clear.tooltip_text = "Clear one %s space to fit out again: %s." % [discipline, GameState.lab_refit_text()]
	clear.disabled = spaces <= 0
	clear.set_meta(&"focus_key", "clear:" + discipline)
	clear.pressed.connect(_on_clear_pressed.bind(discipline))
	row.add_child(clear)
	return row


func _on_grow_pressed() -> void:
	_show_result(await FarmCommands.request(&"start_lab_grow"), "Building started. Your areas keep working meanwhile.")


func _on_fit_pressed(discipline: String) -> void:
	_show_result(await FarmCommands.request(&"fit_lab_area", [discipline]), "The %s area has one more space." % discipline)


func _on_clear_pressed(discipline: String) -> void:
	var cost: String = GameState.lab_refit_text()  # before a free refit is used up
	_show_result(await FarmCommands.request(&"clear_lab_area", [discipline]), "Clearing one %s space: %s." % [discipline, cost])


func _show_result(problem: String, done_text: String) -> void:
	_result_label.text = problem if problem != "" else done_text
	_result_label.add_theme_color_override(&"font_color", AMBER if problem != "" else TEAL)
	_refresh()


static func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", font_size)
	return label


static func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 20)
	return button


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.065, 0.98)
	style.border_color = Color(0.3, 0.45, 0.33, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(30)
	return style
