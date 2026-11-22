class_name CalBenchUI
extends Control
## Centered bench-calibration overlay (Week 2 board, milestone 3).
## Opening (or switching instrument) freezes the As-Found error. ZERO /
## CALIBRATE zeroes through GameState.calibrate(), shows As-Left, and
## reports pass/fail of the As-Found against MPE.

signal closed

## Instrument id -> display name, in selector order.
const INSTRUMENTS: Dictionary = {
	"hygrometer": "Terrarium Hygrometer",
	"rover_steering_encoder": "Rover Steering Encoder",
}

var _ids: Array[String] = []
var _current_id: String = ""

@onready var _instrument_option: OptionButton = %InstrumentOption
@onready var _found_value: Label = %FoundValue
@onready var _found_band: Label = %FoundBand
@onready var _found_meter: BandMeter = %FoundMeter
@onready var _left_value: Label = %LeftValue
@onready var _left_band: Label = %LeftBand
@onready var _left_meter: BandMeter = %LeftMeter
@onready var _mpe_label: Label = %MpeLabel
@onready var _result_label: Label = %ResultLabel
@onready var _calibrate_button: Button = %CalibrateButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	for id: Variant in INSTRUMENTS:
		_ids.append(id as String)
		_instrument_option.add_item(INSTRUMENTS[id] as String)
	_instrument_option.item_selected.connect(_on_instrument_selected)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"swap_scene"):
		# Don't let Tab yank the player out of the bench mid-calibration.
		get_viewport().set_input_as_handled()


func open(instrument_id: String = "hygrometer") -> void:
	show()
	var index: int = maxi(_ids.find(instrument_id), 0)
	_instrument_option.select(index)
	_on_instrument_selected(index)


func close() -> void:
	hide()
	closed.emit()


func _on_instrument_selected(index: int) -> void:
	_current_id = _ids[index]
	var sensor: DriftingSensor = GameState.get_sensor(_current_id)
	if sensor == null:
		return
	for meter: BandMeter in [_found_meter, _left_meter]:
		meter.mpe = sensor.mpe
		meter.acceptance_ratio = sensor.acceptance_ratio
	_mpe_label.text = "%s   MPE ±%s   ACCEPT ±%s (%d %% of MPE)" % [
		sensor.quantity_name().capitalize(), _unsigned(sensor, sensor.mpe),
		_unsigned(sensor, sensor.mpe * sensor.acceptance_ratio), roundi(sensor.acceptance_ratio * 100.0)]
	_show_as_found(sensor, sensor.error)
	_left_value.text = "--"
	_left_band.text = ""
	_left_meter.show_needle = false
	_calibrate_button.disabled = false
	_result_label.text = _last_record_text(_current_id)


func _on_calibrate_pressed() -> void:
	var record: Dictionary = GameState.calibrate(_current_id)
	if record.is_empty():
		return
	# One calibration per session with this instrument; re-enabled when the
	# player switches instrument or reopens the bench.
	_calibrate_button.disabled = true
	var sensor: DriftingSensor = GameState.get_sensor(_current_id)
	_show_as_found(sensor, record["as_found"] as float)
	var as_left: float = record["as_left"]
	var left_band: int = record["as_left_band"]
	_left_value.text = sensor.format_value(as_left)
	_left_band.text = DriftingSensor.band_label(left_band)
	_left_band.add_theme_color_override("font_color", DriftingSensor.band_color(left_band))
	_left_meter.value = as_left
	_left_meter.show_needle = true
	var passed: bool = record["as_found_in_tolerance"]
	var interval_note: String = "Interval %d d → %d d, due day %d." % [
		record["previous_interval_days"], record["interval_days"], record["due_day"]]
	if passed and record["on_time"] and record["interval_evidence"]:
		_result_label.text = "AS-FOUND IN TOLERANCE, ON TIME: PASS. Interval lengthened. " + interval_note
	elif passed and record["on_time"]:
		_result_label.text = "AS-FOUND IN TOLERANCE: PASS. Too soon after the last calibration to change the interval. " + interval_note
	elif passed:
		_result_label.text = "AS-FOUND IN TOLERANCE, LATE: PASS. Interval unchanged. " + interval_note
	else:
		_result_label.text = "AS-FOUND OUT OF TOLERANCE: FAIL. Interval shortened, logged for audit. " + interval_note
	_result_label.add_theme_color_override(
		"font_color", DriftingSensor.band_color(DriftingSensor.Band.IN_BAND if passed else DriftingSensor.Band.OUT_OF_TOLERANCE))


func _show_as_found(sensor: DriftingSensor, value: float) -> void:
	var band: int = sensor.band_for(value)
	_found_value.text = sensor.format_value(value)
	_found_band.text = DriftingSensor.band_label(band)
	_found_band.add_theme_color_override("font_color", DriftingSensor.band_color(band))
	_found_meter.value = value
	_found_meter.show_needle = true


func _last_record_text(instrument_id: String) -> String:
	_result_label.remove_theme_color_override("font_color")
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	var today: int = GameClock.get_day_index()
	var due: String = ("OVERDUE since day %d" % (sensor.cal_due_day + 1) if sensor.is_overdue(today)
		else "Due day %d (interval %d d)" % [sensor.cal_due_day, sensor.cal_interval_days])
	var record: Dictionary = GameState.last_cal_records.get(instrument_id, {})
	if record.is_empty():
		return "No calibration on record. " + due
	return "Last cal: day %d by %s, as-found %s (%s). %s" % [
		record["day"], record.get("performed_by", "You"), sensor.format_value(record["as_found"] as float),
		"PASS" if record["as_found_in_tolerance"] else "FAIL", due]


func _unsigned(sensor: DriftingSensor, value: float) -> String:
	return sensor.format_value(value).trim_prefix("+")
