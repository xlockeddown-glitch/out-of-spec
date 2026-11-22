class_name CalBenchUI
extends Control
## Centered bench-calibration overlay (Week 2 board, milestone 3).
## Opening (or switching instrument) freezes the As-Found error. ZERO /
## CALIBRATE runs GameState.calibrate_at_bench(): the unit is compared with
## its standard, the As-Found is judged pass / indeterminate / fail against
## the acceptance limit and MPE, and the bench time passes on the clock.

signal closed

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
@onready var _standard_label: Label = %StandardLabel
@onready var _result_label: Label = %ResultLabel
@onready var _calibrate_button: Button = %CalibrateButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	_ids = GameState.unit_ids()
	for id: String in _ids:
		_instrument_option.add_item(GameState.instrument_name(id, true))
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
	_standard_label.text = _standard_text(_current_id)
	_show_as_found(sensor, sensor.error)
	_left_value.text = "--"
	_left_band.text = ""
	_left_meter.show_needle = false
	_calibrate_button.disabled = false
	_result_label.text = _last_record_text(_current_id)


func _on_calibrate_pressed() -> void:
	var record: Dictionary = GameState.calibrate_at_bench(_current_id)
	if record.is_empty():
		return
	if record.get("refused", false):
		_calibrate_button.disabled = true
		_result_label.text = "REFUSED: " + str(record["reason"])
		_result_label.add_theme_color_override(
			"font_color", DriftingSensor.band_color(DriftingSensor.Band.OUT_OF_TOLERANCE))
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
	var result: String = record["result"]
	var interval_note: String = "Interval %d d → %d d, due day %d. Bench time %d min." % [
		record["previous_interval_days"], record["interval_days"], record["due_day"],
		roundi(record.get("bench_minutes", 0.0))]
	var band: int = DriftingSensor.Band.IN_BAND
	if result == CalUncertainty.FAIL:
		band = DriftingSensor.Band.OUT_OF_TOLERANCE
		_result_label.text = "AS-FOUND OUT OF TOLERANCE: FAIL. Interval shortened, logged for audit. " + interval_note
	elif result == CalUncertainty.INDETERMINATE:
		band = DriftingSensor.Band.GUARDBAND
		_result_label.text = "AS-FOUND INSIDE MPE BUT OUTSIDE THE ACCEPTANCE LIMIT: INDETERMINATE. Counts as a pass; interval unchanged. " + interval_note
	elif record["on_time"] and record["interval_evidence"]:
		_result_label.text = "AS-FOUND WITHIN ACCEPTANCE LIMIT, ON TIME: PASS. Interval lengthened. " + interval_note
	elif record["on_time"]:
		_result_label.text = "AS-FOUND WITHIN ACCEPTANCE LIMIT: PASS. Too soon after the last calibration to change the interval. " + interval_note
	else:
		_result_label.text = "AS-FOUND WITHIN ACCEPTANCE LIMIT, LATE: PASS. Interval unchanged. " + interval_note
	_result_label.add_theme_color_override("font_color", DriftingSensor.band_color(band))


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
	var verdict: String = str(record.get("result", "pass" if record["as_found_in_tolerance"] else "fail")).to_upper()
	if not record.get("traceable", true):
		verdict += ", NO STANDARD"
	return "Last cal: day %d by %s, as-found %s (%s). %s" % [
		record["day"], record.get("performed_by", "You"), sensor.format_value(record["as_found"] as float),
		verdict, due]


## "Standard: Rotary Table   U ±0.0x°   TUR 47:1   Limit ±0.9x°"
func _standard_text(instrument_id: String) -> String:
	var budget: Dictionary = GameState.calibration_budget(instrument_id)
	if budget.is_empty():
		return "No reference standard for this instrument."
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	var tur: float = budget["tur"]
	var tur_note: String = "REFUSED, under %s:1" % SP811.number(CalUncertainty.tur_floor(), 0) if budget["refused"] \
		else ("" if budget["clean"] else "marginal, under %s:1" % SP811.number(CalUncertainty.tur_clean(), 0))
	return "Standard: %s   U ±%s   TUR %s:1%s   Limit ±%s" % [
		GameState.instrument_name(budget["standard_id"], true),
		_unsigned_precise(sensor, budget["expanded_uncertainty"]),
		SP811.number(tur, 1), " (%s)" % tur_note if tur_note != "" else "",
		_unsigned_precise(sensor, budget["acceptance_limit"])]


## Three decimals, one more than the live reading, so small U values don't read as 0.
func _unsigned_precise(sensor: DriftingSensor, value: float) -> String:
	return sensor.format_value(value, 3).trim_prefix("+")


func _unsigned(sensor: DriftingSensor, value: float) -> String:
	return sensor.format_value(value).trim_prefix("+")
