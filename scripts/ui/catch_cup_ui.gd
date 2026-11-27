class_name CatchCupUI
extends Control
## The catch cup over the Cobalt Sentinel: its humidity is set by what the
## hygrometer shows, and closing it is the one try.

signal closed(reading_pct: float)

const TEAL: Color = Color("38E1C6")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)
## Where the cup starts and what one press does, in percent. [PLACEHOLDER]
const START_PCT: float = 55.0
const MIST_PCT: float = 5.0
const VENT_PCT: float = 2.0

var reading_pct: float = START_PCT

var _ideal: Label
var _reading: Label
var _band: Label
var _mist: Button


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label("CATCH CUP", TEAL, 30))
	_ideal = PlanBoardUI._label("", TEXT, 20)
	_reading = PlanBoardUI._label("", TEXT, 28)
	_band = PlanBoardUI._label("", DIM, 18)
	for label: Label in [_ideal, _reading, _band]:
		column.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	column.add_child(row)
	_mist = _add(row, "MIST", _change.bind(MIST_PCT))
	_add(row, "VENT", _change.bind(-VENT_PCT))
	_add(row, "CLOSE THE CUP", _on_close)
	_add(row, "LEAVE  (Esc)", hide)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		hide()
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func open() -> void:
	reading_pct = START_PCT
	_refresh()
	show()
	_mist.grab_focus()


func _add(row: HBoxContainer, text: String, pressed: Callable) -> Button:
	var button: Button = PlanBoardUI._button(text)
	button.pressed.connect(pressed)
	row.add_child(button)
	return button


func _change(by_pct: float) -> void:
	reading_pct = clampf(reading_pct + by_pct, 0.0, 100.0)
	_refresh()


func _on_close() -> void:
	hide()
	closed.emit(reading_pct)


## Only what the instrument shows; what the air really is comes out at the catch.
func _refresh() -> void:
	var sensor: DriftingSensor = GameState.hygrometer
	var species: Dictionary = DataManager.get_record(GameState.SPECIES_TABLE, GameState.SENTINEL)
	_ideal.text = "Ideal relative humidity (%s ± %s) %%" % [
		SP811.number(float(species["ideal_humidity_pct"]), 0), SP811.number(GameState.CUP_TOLERANCE_PCT, 0)]
	_reading.text = "Hygrometer reads %s %%" % SP811.number(reading_pct, 0)
	var band: int = sensor.get_observed_band()
	_band.text = "%s  ·  %s" % [DriftingSensor.band_label(band),
		"CAL " + DriftingSensor.overdue_text(sensor.cal_due_day) if sensor.is_overdue(GameClock.get_day_index())
		else "cal due day %d" % sensor.cal_due_day]
	_band.add_theme_color_override(&"font_color", DriftingSensor.band_color(band))
