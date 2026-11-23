class_name CalBenchUI
extends Control
## Centered bench-calibration overlay (Week 2 board, milestone 3).
## Opening (or switching instrument) freezes the As-Found error. ZERO /
## CALIBRATE runs GameState.calibrate_at_bench(): the unit is compared with
## its standard, the As-Found is judged pass / indeterminate / fail against
## the acceptance limit and MPE, and the bench time passes on the clock.
## Standards are listed too (milestone 2): they can be sent to OIRM (drop pod, or
## courier on other days), and calibrated here if the colony has the standard
## that calibrates them. Each instrument shows its traceability chain under the standard line.
## Accepted customer jobs are listed too ("job:" ids): CALIBRATE FOR CUSTOMER
## runs GameState.complete_job() against the best standard for the job.

signal closed

const CALIBRATE_TEXT: String = "ZERO / CALIBRATE"
const JOB_PREFIX: String = "job:"

var _ids: Array[String] = []
var _current_id: String = ""
## Budget and acceptance limit of the selected instrument against its standard.
var _budget: Dictionary = {}
var _limit: float = 0.0
## Standards only: sends the selected one to OIRM.
var _send_button := Button.new()

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
	_rebuild_list()
	_instrument_option.item_selected.connect(_on_instrument_selected)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_send_button.custom_minimum_size = _calibrate_button.custom_minimum_size
	_send_button.size_flags_horizontal = _calibrate_button.size_flags_horizontal
	_send_button.hide()
	_calibrate_button.add_sibling(_send_button)
	_send_button.pressed.connect(_on_send_pressed)
	_close_button.pressed.connect(close)
	GameState.drop_pod_changed.connect(_on_pod_or_oirm_changed.unbind(1))
	GameState.oirm_changed.connect(_on_pod_or_oirm_changed)
	GameState.jobs_changed.connect(_on_jobs_changed)
	GameClock.time_advanced.connect(_on_time_advanced.unbind(1))


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
	_rebuild_list()
	show()
	var index: int = maxi(_ids.find(instrument_id), 0)
	_instrument_option.select(index)
	_on_instrument_selected(index)


## Instruments in service right now: buying a Tier 1 standard from Bram adds
## it and its units without a scene change.
func _rebuild_list() -> void:
	_ids = GameState.unit_ids() + GameState.standard_ids()
	_instrument_option.clear()
	for id: String in _ids:
		_instrument_option.add_item(GameState.instrument_name(id, true))
	for job: Dictionary in GameState.active_jobs:
		_ids.append(JOB_PREFIX + str(job["job_id"]))
		_instrument_option.add_item("%s: %s for %s" % [job["job_id"], job.get("item", "?"), job.get("customer", "?")])


func close() -> void:
	hide()
	closed.emit()


## The pod landing or leaving changes whether a standard can be sent.
func _on_pod_or_oirm_changed() -> void:
	if visible and _is_standard(_current_id):
		_on_instrument_selected(_ids.find(_current_id))


## Jobs accepted, finished, cancelled or gone late: rebuild the list and keep
## the selection. A selected job that is gone shows as no longer active.
func _on_jobs_changed() -> void:
	if not visible:
		return
	_rebuild_list()
	var index: int = _ids.find(_current_id)
	_instrument_option.select(index)
	if _current_id.begins_with(JOB_PREFIX):
		if index >= 0:
			_on_instrument_selected(index)
		else:
			_show_job({})


## A shown job can become impossible as the clock runs (the cancel cutoff
## gets too close): redraw it when its button would change.
func _on_time_advanced() -> void:
	if not visible or not _current_id.begins_with(JOB_PREFIX):
		return
	var job: Dictionary = GameState.active_job(_current_id.trim_prefix(JOB_PREFIX))
	if not job.is_empty() and (GameState.job_bench_problem(job) != "") != _calibrate_button.disabled:
		_show_job(job)


func _is_standard(instrument_id: String) -> bool:
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	return sensor != null and sensor.role == "standard"


func _on_instrument_selected(index: int) -> void:
	_current_id = _ids[index]
	_calibrate_button.show()
	_send_button.hide()
	if _current_id.begins_with(JOB_PREFIX):
		_show_job(GameState.active_job(_current_id.trim_prefix(JOB_PREFIX)))
		return
	var sensor: DriftingSensor = GameState.get_sensor(_current_id)
	if sensor == null:
		return
	if sensor.role == "standard":
		_show_send()
		if not GameState.has_bench_reference(_current_id) or GameState.at_oirm.has(_current_id):
			_show_standard(sensor)
			return
	_calibrate_button.text = CALIBRATE_TEXT
	_budget = GameState.calibration_budget(_current_id)
	_limit = _budget.get("acceptance_limit", sensor.mpe)
	for meter: BandMeter in [_found_meter, _left_meter]:
		meter.mpe = sensor.mpe
		meter.acceptance_ratio = _limit / sensor.mpe if sensor.mpe > 0.0 else 1.0
	_mpe_label.text = "%s   MPE ±%s" % [sensor.quantity_title(), _unsigned(sensor, sensor.mpe)]
	_standard_label.text = _reference_text(_current_id)
	# What the bench would read: the unit's error seen through the standard's.
	var standard: DriftingSensor = GameState.get_sensor(_budget.get("standard_id", ""))
	_show_as_found(sensor, sensor.error - (standard.error if standard else 0.0))
	_left_value.text = "--"
	_left_band.text = ""
	_left_meter.show_needle = false
	_calibrate_button.disabled = false
	_result_label.text = _last_record_text(_current_id)
	var standard_id: String = _budget.get("standard_id", "")
	if GameState.at_oirm.has(standard_id):
		_found_value.text = "--"
		_found_band.text = "STANDARD AT OIRM"
		_found_band.remove_theme_color_override("font_color")
		_found_meter.show_needle = false
		_calibrate_button.disabled = true
		_result_label.text = "%s is at OIRM until day %d. %s" % [
			GameState.instrument_name(standard_id, true), GameState.at_oirm[standard_id], _result_label.text]


func _show_send() -> void:
	if GameState.is_relay_disciplined(_current_id):
		return  # it never goes to OIRM
	_send_button.show()
	_send_button.text = ("SEND TO OIRM (%s CR)" % SP811.integer(GameState.oirm_fee()) if GameState.drop_pod_present
		else "SEND BY COURIER (%s CR)" % SP811.integer(GameState.oirm_fee() + GameState.oirm_courier_surcharge()))
	_send_button.disabled = GameState.at_oirm.has(_current_id)


## A standard with no reference on this bench: its error is unknown until OIRM
## measures it. Shows its certificate, chain and the send button only.
func _show_standard(sensor: DriftingSensor) -> void:
	_budget = {}
	_limit = sensor.mpe
	for meter: BandMeter in [_found_meter, _left_meter]:
		meter.mpe = sensor.mpe
		meter.acceptance_ratio = 1.0
		meter.show_needle = false
	_mpe_label.text = "%s   MPE ±%s   (reference standard)" % [
		sensor.quantity_title(), _unsigned_precise(sensor, sensor.mpe)]
	_standard_label.text = _certificate_text(_current_id) + "\n" + _chain_text(_current_id)
	for label: Label in [_found_value, _left_value]:
		label.text = "--"
	_found_band.text = "AT OIRM" if GameState.at_oirm.has(_current_id) else "NO REFERENCE ON SITE"
	_found_band.remove_theme_color_override("font_color")
	_left_band.text = ""
	_calibrate_button.hide()
	_result_label.remove_theme_color_override("font_color")
	var today: int = GameClock.get_day_index()
	if sensor.relay_disciplined:
		var locked: bool = GameState.is_relay_locked(_current_id)
		_found_band.text = "LOCKED" if locked else "HOLDOVER"
		_result_label.text = ("Locked to OIRM time over the relay." if locked
			else "No line of sight to the relay: in holdover. %s" % _due_text(sensor, today))
	elif GameState.at_oirm.has(_current_id):
		_result_label.text = "At OIRM. Back on day %d." % GameState.at_oirm[_current_id]
	elif not GameState.drop_pod_present:
		_result_label.text = "No drop pod today. By courier it is back on day %d (fee + %s CR surcharge), or wait for the day %d pod (fee only). %s" % [
			today + GameState.oirm_courier_days(), SP811.integer(GameState.oirm_courier_surcharge()),
			GameState.next_audit_day(today), _due_text(sensor, today)]
	else:
		_result_label.text = "Drop pod on the pad. While it is away nothing can be calibrated against this standard. %s" % _due_text(sensor, today)


## A customer's job: what it needs, when it is due, what it pays.
func _show_job(job: Dictionary) -> void:
	_budget = {}
	for meter: BandMeter in [_found_meter, _left_meter]:
		meter.show_needle = false
	for label: Label in [_found_value, _left_value]:
		label.text = "--"
	_found_band.text = "CUSTOMER JOB"
	_found_band.remove_theme_color_override("font_color")
	_left_band.text = ""
	_result_label.remove_theme_color_override("font_color")
	if job.is_empty():
		_mpe_label.text = "This job is no longer active."
		_standard_label.text = ""
		_result_label.text = ""
		_calibrate_button.disabled = true
		return
	_mpe_label.text = "%s: %s (%s)" % [job.get("customer", "?"), job.get("item", "?"), job.get("discipline", "?")]
	var standard_id: String = GameState.job_bench_standard(job)
	_standard_label.text = ("Standard: %s" % GameState.instrument_name(standard_id, true) if standard_id != ""
		else "No standard on the bench for this job.")
	_calibrate_button.text = "CALIBRATE FOR CUSTOMER (%s min)" % SP811.integer(roundi(GameState.job_minutes(job)))
	var problem: String = GameState.job_bench_problem(job)
	_calibrate_button.disabled = problem != ""
	var today: int = GameClock.get_day_index()
	_result_label.text = problem if problem != "" else "%s. Pays %s CR on time and traceable; late or with an overdue standard it pays less and costs credibility." % [
		GameState.active_job_text(job), SP811.integer(int(job.get("pay", 0)))]
	var trouble: String = GameState.standard_problem(standard_id) if standard_id != "" else ""
	if trouble != "":
		_result_label.text += " The standard is %s: this job would not be traceable." % trouble.to_upper()


func _due_text(sensor: DriftingSensor, today: int) -> String:
	if sensor.role == "standard" and not GameState.certificates.has(_current_id):
		return "Work done with it is not traceable until OIRM has certified it."
	return ("OVERDUE since day %d." % (sensor.cal_due_day + 1) if sensor.is_overdue(today)
		else "Due day %d." % sensor.cal_due_day)


## "Certificate OIRM-0003, day 10: as-found +0.012° (in tolerance), U ±0.020° (k = 2)"
func _certificate_text(instrument_id: String) -> String:
	var cert: Dictionary = GameState.certificates.get(instrument_id, {})
	if cert.is_empty():
		return "No certificate."
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	var found: String = (("founding stock, no as-found on file" if cert.get("founding", false)
			else "new from %s, no as-found on file" % cert.get("issuer", "the maker")) if cert["as_found"] == null
		else "as-found %s (%s)" % [sensor.format_value(float(cert["as_found"]), maxi(3, sensor.display_decimals)),
			"in tolerance" if cert["as_found_in_tolerance"] else "OUT OF TOLERANCE"])
	return "Certificate %s, day %d: %s, U ±%s (k = %s)" % [
		cert["id"], cert["day"], found, _unsigned_precise(sensor, cert["expanded_uncertainty"]),
		SP811.number(cert["k"], 0)]


func _chain_text(instrument_id: String) -> String:
	var chain: Dictionary = GameState.traceability_chain(instrument_id)
	return ("Chain: " if chain["traceable"] else "Chain BROKEN: ") + str(chain["text"])


func _on_calibrate_pressed() -> void:
	if _current_id.begins_with(JOB_PREFIX):
		var result: Dictionary = GameState.complete_job(_current_id.trim_prefix(JOB_PREFIX))
		_calibrate_button.disabled = true
		var clean: bool = result.get("ok", false) and result["on_time"] and result["traceable"]
		_result_label.text = GameState.job_result_text(result) if result.get("ok", false) else "REFUSED: " + str(result["reason"])
		_result_label.add_theme_color_override("font_color", DriftingSensor.band_color(
			DriftingSensor.Band.IN_BAND if clean else DriftingSensor.Band.GUARDBAND if result.get("ok", false)
			else DriftingSensor.Band.OUT_OF_TOLERANCE))
		if result.get("ok", false):
			# Done: keep the pay and credibility shown, not "no longer active".
			_current_id = ""
		return
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
	var left_band: int = _bench_band(sensor, as_left)
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
	if record.get("standard_overdue", false):
		band = DriftingSensor.Band.GUARDBAND
		_result_label.text = "STANDARD OVERDUE: unit adjusted, NOT TRACEABLE. Not a calibration; still due day %d. Send the standard to OIRM." % record["due_day"]
	elif record.get("standard_problem", "") != "":
		band = DriftingSensor.Band.GUARDBAND
		_result_label.text = "STANDARD %s: unit adjusted, NOT TRACEABLE. Not a calibration; still due day %d." % [
			str(record["standard_problem"]).to_upper(), record["due_day"]]
	elif sensor.role == "standard":
		band = (DriftingSensor.Band.OUT_OF_TOLERANCE if result == CalUncertainty.FAIL
			else DriftingSensor.Band.GUARDBAND if result == CalUncertainty.INDETERMINATE else DriftingSensor.Band.IN_BAND)
		_result_label.text = "AS-FOUND: %s. In-house certificate %s.%s Due day %d. Bench time %d min." % [
			result.to_upper(), record.get("certificate", "?"),
			" Work done with it is recalled; see the phone." if result == CalUncertainty.FAIL else "",
			record["due_day"], roundi(record.get("bench_minutes", 0.0))]
	elif result == CalUncertainty.FAIL:
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
	_standard_label.text = _reference_text(_current_id)


func _on_send_pressed() -> void:
	var sent: Dictionary = GameState.send_to_oirm(_current_id)
	if sent["ok"]:
		_on_instrument_selected(_ids.find(_current_id))
		return
	_result_label.text = "NOT SENT: " + str(sent["reason"])
	_result_label.add_theme_color_override(
		"font_color", DriftingSensor.band_color(DriftingSensor.Band.OUT_OF_TOLERANCE))


func _show_as_found(sensor: DriftingSensor, value: float) -> void:
	var band: int = _bench_band(sensor, value)
	_found_value.text = sensor.format_value(value)
	_found_band.text = DriftingSensor.band_label(band)
	_found_band.add_theme_color_override("font_color", DriftingSensor.band_color(band))
	_found_meter.value = value
	_found_meter.show_needle = true


## Bench colours follow the RSS acceptance limit, not the HUD's fixed ratio.
func _bench_band(sensor: DriftingSensor, value: float) -> int:
	match CalUncertainty.classify(value, sensor.mpe, _limit):
		CalUncertainty.PASS:
			return DriftingSensor.Band.IN_BAND
		CalUncertainty.INDETERMINATE:
			return DriftingSensor.Band.GUARDBAND
	return DriftingSensor.Band.OUT_OF_TOLERANCE


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
	if record.get("suspect", false):
		verdict += ", SUSPECT (recalled)"
	elif record.get("standard_overdue", false):
		verdict += ", STANDARD OVERDUE: NOT TRACEABLE"
	elif record.get("standard_problem", "") != "":
		verdict += ", STANDARD %s: NOT TRACEABLE" % str(record["standard_problem"]).to_upper()
	elif not record.get("traceable", true):
		verdict += ", NO STANDARD"
	return "Last cal: day %d by %s, as-found %s (%s). %s" % [
		record["day"], GameState.performer_name(record.get("performed_by", "")), sensor.format_value(record["as_found"] as float),
		verdict, due]


## The standard used and the chain; for a standard its own certificate first.
func _reference_text(instrument_id: String) -> String:
	var text: String = _standard_text(instrument_id) + "\n" + _chain_text(instrument_id)
	if GameState.has_skill_unlock("budget_view"):
		text += _budget_text(instrument_id)
	return _certificate_text(instrument_id) + "\n" + text if _is_standard(instrument_id) else text


## The terms of U, once the Uncertainty skill shows them. "" with no standard.
func _budget_text(instrument_id: String) -> String:
	var budget: Dictionary = GameState.calibration_budget(instrument_id)
	if budget.is_empty():
		return ""
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	return "\nStandard uncertainties, k = %s for U:\nspec %s, certificate %s, resolution %s, operator %s" % [
		SP811.number(budget["k"], 0), _unsigned_precise(sensor, budget["u_spec"]), _unsigned_precise(sensor, budget["u_cert"]),
		_unsigned_precise(sensor, budget["u_res"]), _unsigned_precise(sensor, budget["u_op"])]


## "Standard: Pavonis Indexworks PX-1 Rotary Table   U ±0.0x°   TUR 47:1   Limit ±0.9x°"
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


## Three decimals or more, so small U values don't read as 0.
func _unsigned_precise(sensor: DriftingSensor, value: float) -> String:
	return sensor.format_value(value, maxi(3, sensor.display_decimals)).trim_prefix("+")


func _unsigned(sensor: DriftingSensor, value: float) -> String:
	return sensor.format_value(value).trim_prefix("+")
