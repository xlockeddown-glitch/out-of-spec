class_name KestrelUI
extends Control
## Kestrel's case of reference standards at the dome airlock. They come with no
## certificate. A buy button is pressed twice. Closes when the flare ends.

const TEAL: Color = Color("38E1C6")
const AMBER: Color = Color("F5A623")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)

var _funds: Label
var _rows: VBoxContainer
var _result: Label
var _close_button: Button
## The standard whose buy button has been pressed once.
var _armed_id: String = ""


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label("KESTREL", TEAL, 30))
	column.add_child(PlanBoardUI._label("No certificates. Work done with one of these is not traceable until OIRM has certified it, and it is overdue from tomorrow until you send it.", DIM, 18))
	_funds = PlanBoardUI._label("", TEXT, 20)
	column.add_child(_funds)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	column.add_child(_rows)
	_result = PlanBoardUI._label("", AMBER, 20)
	column.add_child(_result)
	_close_button = PlanBoardUI._button("CLOSE  (Esc)")
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	column.add_child(_close_button)
	hide()
	GameState.credits_changed.connect(_on_farm_changed.unbind(1))
	GameState.ore_changed.connect(_on_farm_changed.unbind(1))
	GameState.upgrades_changed.connect(_on_farm_changed)
	GameState.lab_xp_changed.connect(_on_farm_changed)


func _process(_delta: float) -> void:
	if visible and not GameState.kestrel_present():
		hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
	elif event.is_action_pressed(&"swap_scene"):
		get_viewport().set_input_as_handled()


func open() -> void:
	if not GameState.kestrel_present():
		return
	_armed_id = ""
	_result.text = ""
	_refresh()
	show()
	_focus_row("")


## The other player may spend or buy while this is open.
func _on_farm_changed() -> void:
	if not visible:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var row: String = str(focused.get_meta(&"standard", "")) if focused != null else ""
	var on_close: bool = focused == _close_button
	_refresh()
	if on_close:
		_close_button.grab_focus()
	else:
		_focus_row(row)


func _refresh() -> void:
	_funds.text = "You have %s CR and %s crystal ore." % [
		SP811.integer(GameState.credits), SP811.integer(GameState.crystal_ore)]
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for id: String in GameState.kestrel_catalog():
		_rows.add_child(_row(id))


func _row(id: String) -> Button:
	var button: Button = PlanBoardUI._button("")
	button.set_meta(&"standard", id)
	button.disabled = GameState.owned_standards.has(id)
	var what: String = GameState.instrument_name(id)
	if button.disabled:
		button.text = "%s: on the colony" % what
	elif GameState.tier_lab_note(id) != "":
		# Pressing it still gives the full reason.
		button.text = "%s: %s" % [what, GameState.tier_lab_note(id)]
	elif id == _armed_id:
		button.text = "PRESS AGAIN TO BUY: %s, %s, NO CERTIFICATE" % [what, GameState.standard_price_text(id)]
	else:
		button.text = "BUY %s  (%s)" % [what, GameState.standard_price_text(id)]
	button.pressed.connect(_on_buy_pressed.bind(id))
	return button


func _on_buy_pressed(id: String) -> void:
	var problem: String = GameState.kestrel_purchase_problem(id)
	if problem == "" and _armed_id != id:
		_armed_id = id
		_result.text = ""
	else:
		_armed_id = ""
		if problem == "":
			problem = await FarmCommands.request(&"buy_from_kestrel", [id])
		_result.text = problem if problem != "" else "Bought. Send it to OIRM at the bench for its first certificate."
		_result.add_theme_color_override(&"font_color", AMBER if problem != "" else TEAL)
	_refresh()
	_focus_row(id)


## Keyboard and gamepad focus: the row for `id`, else the first usable one.
func _focus_row(id: String) -> void:
	var target: Button = _close_button
	for child: Node in _rows.get_children():
		var row := child as Button
		if row.disabled:
			continue
		if row.get_meta(&"standard") == id:
			target = row
			break
		if target == _close_button:
			target = row
	target.grab_focus()
