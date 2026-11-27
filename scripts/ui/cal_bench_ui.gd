class_name CalBenchUI
extends Control
## Centered bench-calibration overlay (Week 2 board, milestone 3).
## Opening (or switching instrument) freezes the As-Found error. ZERO /
## CALIBRATE asks for calibrate_at_bench(): the unit is compared with
## its standard, the As-Found is judged pass / indeterminate / fail against
## the acceptance limit and MPE, and the bench time passes on the clock.
## Standards are listed too (milestone 2): they can be sent to OIRM (drop pod, or
## courier on other days), and calibrated here if the colony has the standard
## that calibrates them. Each instrument shows its traceability chain under the standard line.
## Accepted customer jobs are listed too ("job:" ids): CALIBRATE FOR CUSTOMER
## runs GameState.complete_job() against the best standard for the job.
## At a key moment (MinigameScore.is_due) ZERO / CALIBRATE opens the bench game
## first: Set the Zero, or Hold the Reading for a unit whose standard settles
## (MinigameScore.game_for). Its score goes with the command. The CAREFUL switch and the game's
## difficulty are this player's own (MinigameSettings).

signal closed

const CALIBRATE_TEXT: String = "ZERO / CALIBRATE"
const JOB_PREFIX: String = "job:"

const BIG_VALUE_SIZE: int = 52
## [PLACEHOLDER] over 14 characters the number drops to 38.
const LONG_VALUE_CHARS: int = 14
const LONG_VALUE_SIZE: int = 38

var _ids: Array[String] = []
var _current_id: String = ""
## The shown result is from this session's calibration.
var _calibrated: bool = false
## That result's text and colour, and the budget it was done with.
var _finished_text: String = ""
var _finished_color: Color
var _finished_budget: Dictionary = {}
## Counts openings, closings and picks: an answer asked for in an earlier one
## is not shown.
var _visit: int = 0
## Whether the selected instrument had a reference when shown.
var _has_reference: bool = false
## _away_text() as shown.
var _away: String = ""
## Budget and acceptance limit of the selected instrument against its standard.
var _budget: Dictionary = {}
var _limit: float = 0.0
## Standards only: sends the selected one to OIRM.
var _send_button := Button.new()

## After the U and TUR of a record a Hold the Reading score made smaller.
const STEADY_HOLD_NOTE: String = "U and TUR with your steady hold"
const STEADY_HOLD_MARGINAL: String = "%s; without it TUR %s:1, marginal, under %s:1"

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
@onready var _careful_check: CheckButton = %CarefulCheck
@onready var _game_option: OptionButton = %GameOption
@onready var _zero_game: SetTheZero = %ZeroGame
@onready var _hold_game: HoldTheReading = %HoldGame


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	hide()
	_rebuild_list()
	_instrument_option.item_selected.connect(_on_row_picked)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_send_button.custom_minimum_size = _calibrate_button.custom_minimum_size
	_send_button.size_flags_horizontal = _calibrate_button.size_flags_horizontal
	_send_button.hide()
	_calibrate_button.add_sibling(_send_button)
	_send_button.pressed.connect(_on_send_pressed)
	_close_button.pressed.connect(close)
	for mode: int in MinigameSettings.MODE_NAMES:
		_game_option.add_item(MinigameSettings.MODE_NAMES[mode], mode)
	_game_option.item_selected.connect(_on_game_mode_picked)
	_careful_check.toggled.connect(MinigameSettings.set_careful)
	GameState.drop_pod_changed.connect(_on_pod_or_oirm_changed.unbind(1))
	GameState.oirm_changed.connect(_on_pod_or_oirm_changed)
	GameState.jobs_changed.connect(_on_jobs_changed)
	GameState.upgrades_changed.connect(_on_upgrades_changed)
	GameClock.time_advanced.connect(_on_time_advanced.unbind(1))
	GameClock.guest_time_shown.connect(_on_time_advanced)


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
	_visit += 1
	# A game still open from before ends with no score, and nothing is calibrated.
	_zero_game.skip()
	_hold_game.skip()
	_rebuild_list()
	_show_game_choices()
	show()
	var index: int = maxi(_ids.find(instrument_id), 0)
	_instrument_option.select(index)
	_on_instrument_selected(index)
	# So the pad's D-pad and A work without a mouse.
	_instrument_option.grab_focus()


## Instruments in service right now: buying a Tier 1 standard from Bram adds
## it and its units without a scene change.
func _rebuild_list() -> void:
	_ids = GameState.bench_unit_ids() + GameState.standard_ids()
	_instrument_option.clear()
	for id: String in _ids:
		_instrument_option.add_item(GameState.instrument_name(id, true))
	for job: Dictionary in GameState.active_jobs:
		_ids.append(JOB_PREFIX + str(job["job_id"]))
		_instrument_option.add_item("%s: %s for %s" % [job["job_id"], job.get("item", "?"), job.get("customer", "?")])


func close() -> void:
	_visit += 1
	# A game left open ends with no score, and nothing is calibrated.
	_zero_game.skip()
	_hold_game.skip()
	hide()
	closed.emit()


## The player's own switch and difficulty, as kept. CAREFUL is locked until the
## Calibration level that opens it.
func _show_game_choices() -> void:
	var unlocked: bool = GameState.has_skill_unlock(MinigameScore.CAREFUL_UNLOCK)
	var level: int = int(DataManager.get_record(GameState.SKILLS_TABLE, MinigameScore.CAREFUL_UNLOCK, "unlocks").get("level", 0))
	_careful_check.disabled = not unlocked
	_careful_check.set_pressed_no_signal(unlocked and MinigameSettings.careful())
	_careful_check.text = "CAREFUL" if unlocked else "CAREFUL (Calibration %d)" % level
	_careful_check.tooltip_text = "Play the bench game on every bench calibration: Set the Zero for a smaller as-left residual, or Hold the Reading for a smaller operator uncertainty."
	_game_option.select(_game_option.get_item_index(MinigameSettings.mode()))


func _on_game_mode_picked(index: int) -> void:
	MinigameSettings.set_mode(_game_option.get_item_id(index))


## Whether ZERO / CALIBRATE opens the bench game for the instrument shown.
func _zero_game_due(instrument_id: String) -> bool:
	if MinigameSettings.mode() == MinigameSettings.Mode.OFF or _budget.get("refused", false):
		return false
	return MinigameScore.is_due(GameState, instrument_id, GameState.local_player_id, MinigameSettings.careful())


## The pod landing or leaving changes whether a standard can be sent, and a
## standard away at OIRM what can be calibrated. Otherwise the reading, or a
## finished result, stays as it was.
func _on_pod_or_oirm_changed() -> void:
	var index: int = _ids.find(_current_id)
	if not visible or index < 0:
		return
	if _current_id.begins_with(JOB_PREFIX):
		# The standard it would use may have changed.
		_show_job(GameState.active_job(_current_id.trim_prefix(JOB_PREFIX)))
		return
	var standard: bool = _is_standard(_current_id)
	# With no reference there is no reading to keep.
	if not _calibrated and (_away_text() != _away or (standard and (not _has_reference or not GameState.has_bench_reference(_current_id)))):
		_on_instrument_selected(index)
	elif standard:
		if _calibrated:
			_show_finished()
		_show_send()


## What keeps the selected instrument off the bench, or "".
func _away_text() -> String:
	for id: String in [_current_id, str(GameState.calibration_budget(_current_id).get("standard_id", ""))]:
		if GameState.at_oirm.has(id):
			return "%s %s" % [id, GameState.at_oirm[id]]
	return ""


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


## A bought standard, and the units it puts in service, join the list. The
## selection stays. It is drawn again if its reference or job changes; a
## finished result stays as it was.
func _on_upgrades_changed() -> void:
	if not visible:
		return
	_rebuild_list()
	var index: int = _ids.find(_current_id)
	_instrument_option.select(index)
	if index >= 0 and not _calibrated and (_current_id.begins_with(JOB_PREFIX)
			or _has_reference != GameState.has_bench_reference(_current_id)
			or _budget.get("standard_id", "") != GameState.calibration_budget(_current_id).get("standard_id", "")):
		_on_instrument_selected(index)


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


func _on_row_picked(index: int) -> void:
	_visit += 1
	_on_instrument_selected(index)


func _on_instrument_selected(index: int) -> void:
	_current_id = _ids[index]
	_calibrated = false
	_away = _away_text()
	_has_reference = GameState.has_bench_reference(_current_id)
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
	_standard_label.text = _reference_text(_current_id, _budget)
	# What the bench would read: the unit's error seen through the standard's.
	var standard: DriftingSensor = GameState.get_sensor(_budget.get("standard_id", ""))
	_show_as_found(sensor, sensor.error - (standard.error if standard else 0.0))
	_left_value.text = "--"
	_fit(_left_value)
	_left_band.text = ""
	_left_meter.show_needle = false
	_calibrate_button.disabled = false
	_result_label.text = _last_record_text(_current_id)
	var standard_id: String = _budget.get("standard_id", "")
	if GameState.at_oirm.has(standard_id):
		_found_value.text = "--"
		_fit(_found_value)
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
		_fit(label)
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
		_fit(label)
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
	return (DriftingSensor.overdue_text(sensor.cal_due_day) + "." if sensor.is_overdue(today)
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
	var id: String = _current_id
	var visit: int = _visit
	if _current_id.begins_with(JOB_PREFIX):
		var result: Dictionary = await FarmCommands.request(&"complete_job", [id.trim_prefix(JOB_PREFIX)])
		# The host's answer may come after another row was chosen.
		if _visit != visit:
			return
		if result.get("no_answer", false):
			_show_refusal("", result)
			return
		if not result["ok"]:
			_show_refusal("REFUSED: ", result)
			return
		_calibrate_button.disabled = true
		_result_label.text = GameState.job_result_text(result)
		_result_label.add_theme_color_override("font_color", DriftingSensor.band_color(
			DriftingSensor.Band.IN_BAND if result["on_time"] and result["traceable"] else DriftingSensor.Band.GUARDBAND))
		# Done: keep the pay and credibility shown, not "no longer active".
		_current_id = ""
		return
	var arguments: Array = [id]
	if _zero_game_due(id):
		_calibrate_button.disabled = true
		# The clock is in the seed: opening the bench again is not the same sweep.
		var motion_seed: int = hash([id, GameState.cal_log.size(), Time.get_ticks_usec()])
		var score: int = MinigameScore.SKIPPED
		if MinigameScore.game_for(GameState, id) == MinigameScore.HOLD_THE_READING:
			var slowing: float = MinigameScore.sweet_share(GameState, GameState.local_player_id, MinigameScore.HOLD_SKILL)
			_hold_game.play(slowing, MinigameSettings.mode(), motion_seed, GameState.instrument_name(id, true))
			score = await _hold_game.finished
		else:
			var share: float = MinigameScore.sweet_share(GameState, GameState.local_player_id)
			_zero_game.play(share, MinigameSettings.mode(), motion_seed, GameState.instrument_name(id, true))
			score = await _zero_game.finished
		# Closed with the game open: nothing is calibrated.
		if _visit != visit:
			return
		_calibrate_button.disabled = false
		# A skip sends no score: the command as it always was.
		if score != MinigameScore.SKIPPED:
			arguments.append(score)
	var record: Dictionary = await FarmCommands.request(&"calibrate_at_bench", arguments)
	if record.is_empty() or _visit != visit:
		return
	if record.get("no_answer", false):
		_show_refusal("", record)
		return
	if record.get("refused", false):
		_show_refusal("REFUSED: ", record)
		return
	# One calibration per session with this instrument; re-enabled when the
	# player switches instrument or reopens the bench.
	_calibrated = true
	_calibrate_button.disabled = true
	var sensor: DriftingSensor = GameState.get_sensor(_current_id)
	# Judged as the host did, with the standard it used.
	_limit = record["acceptance_limit"]
	for meter: BandMeter in [_found_meter, _left_meter]:
		meter.acceptance_ratio = _limit / sensor.mpe if sensor.mpe > 0.0 else 1.0
	_show_as_found(sensor, record["as_found"] as float)
	var as_left: float = record["as_left"]
	var left_band: int = _bench_band(sensor, as_left)
	_left_value.text = sensor.format_value(as_left)
	_fit(_left_value)
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
	# The score the host counted. If one was sent and the host counted none (the
	# kind was no longer new by the time it arrived), that is said too.
	var zero_text: String = MinigameScore.result_text(int(record.get(MinigameScore.RECORD_KEY, MinigameScore.SKIPPED)),
		MinigameScore.game_for(GameState, id))
	if zero_text == "" and arguments.size() > 1:
		zero_text = MinigameScore.NOT_COUNTED_TEXT
	if zero_text != "":
		_result_label.text += " " + zero_text
	_finished_text = _result_label.text
	_finished_color = DriftingSensor.band_color(band)
	_finished_budget = _recorded_budget(record)
	_show_finished()


## The budget the host recorded. Its terms are not recorded: they stay only if
## the shown budget came to the same U. A counted Hold the Reading score made
## the recorded U smaller by the operator's term alone: then the shown terms
## stay if they come to the recorded U with that term at the score's factor.
func _recorded_budget(record: Dictionary) -> Dictionary:
	if record["standard_id"] == "":
		return {}
	var budget: Dictionary = {
		"standard_id": record["standard_id"],
		"expanded_uncertainty": record["standard_uncertainty"],
		"tur": record["tur"],
		"acceptance_limit": record["acceptance_limit"],
		"refused": false,
		# "Marginal" is judged on the plain TUR, as the XP is; a steady hold's
		# smaller U is labelled as that (_standard_text).
		"clean": float(record.get("plain_tur", record["tur"])) >= CalUncertainty.tur_clean(),
		"steady_hold": float(record["tur"]) > float(record.get("plain_tur", record["tur"])),
		"plain_tur": float(record.get("plain_tur", record["tur"])),
	}
	var shown: Dictionary = _budget
	var score: int = int(record.get(MinigameScore.RECORD_KEY, MinigameScore.SKIPPED))
	if MinigameScore.is_graded(score) and shown.get("standard_id", "") == budget["standard_id"] \
			and MinigameScore.game_for(GameState, str(record.get("instrument_id", ""))) == MinigameScore.HOLD_THE_READING:
		var unit: DriftingSensor = GameState.get_sensor(str(record.get("instrument_id", "")))
		var standard: DriftingSensor = GameState.get_sensor(str(budget["standard_id"]))
		if unit != null and standard != null:
			shown = CalUncertainty.budget(unit, standard,
				float(shown.get("u_op", 0.0)) * MinigameScore.operator_factor(score), float(shown.get("u_robot", 0.0)))
	if shown.get("standard_id", "") == budget["standard_id"] \
			and is_equal_approx(shown["expanded_uncertainty"], budget["expanded_uncertainty"]):
		budget.merge(shown)
	return budget


## A finished result, with a trip to OIRM and the certificate as they are now.
func _show_finished() -> void:
	_result_label.text = _finished_text
	_result_label.add_theme_color_override("font_color", _finished_color)
	if GameState.at_oirm.has(_current_id):
		_result_label.text += " Sent to OIRM, back on day %d." % GameState.at_oirm[_current_id]
	_standard_label.text = _reference_text(_current_id, _finished_budget)


func _on_send_pressed() -> void:
	var visit: int = _visit
	var sent: Dictionary = await FarmCommands.request(&"send_to_oirm", [_current_id])
	if _visit != visit:
		return
	if sent["ok"] and _calibrated:
		_show_finished()
		# A guest's count of what is away may lag.
		_send_button.disabled = true
		return
	if sent["ok"]:
		_on_instrument_selected(_ids.find(_current_id))
		return
	_show_refusal("NOT SENT: ", sent)


## A refusal is no finding: amber, and the button stays for another try.
func _show_refusal(prefix: String, answer: Dictionary) -> void:
	_result_label.text = prefix + str(answer["reason"])
	_result_label.add_theme_color_override("font_color", DriftingSensor.band_color(DriftingSensor.Band.GUARDBAND))


func _show_as_found(sensor: DriftingSensor, value: float) -> void:
	var band: int = _bench_band(sensor, value)
	_found_value.text = sensor.format_value(value)
	_fit(_found_value)
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
	var due: String = (DriftingSensor.overdue_text(sensor.cal_due_day) if sensor.is_overdue(today)
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
func _reference_text(instrument_id: String, budget: Dictionary) -> String:
	var text: String = _standard_text(instrument_id, budget) + "\n" + _chain_text(instrument_id)
	if GameState.has_skill_unlock("budget_view"):
		text += _budget_text(instrument_id, budget)
	return _certificate_text(instrument_id) + "\n" + text if _is_standard(instrument_id) else text


## The terms of U, once the Uncertainty skill shows them. "" if not known.
func _budget_text(instrument_id: String, budget: Dictionary) -> String:
	if not budget.has("u_spec"):
		return ""
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	return "\nStandard uncertainties, k = %s for U:\nspec %s, certificate %s, resolution %s, operator %s" % [
		SP811.number(budget["k"], 0), _unsigned_precise(sensor, budget["u_spec"]), _unsigned_precise(sensor, budget["u_cert"]),
		_unsigned_precise(sensor, budget["u_res"]), _unsigned_precise(sensor, budget["u_op"])]


## "Standard: Pavonis Indexworks PX-1 Rotary Table   U ±0.0x°   TUR 47:1   Limit ±0.9x°"
func _standard_text(instrument_id: String, budget: Dictionary) -> String:
	if budget.is_empty():
		return "No reference standard for this instrument."
	var sensor: DriftingSensor = GameState.get_sensor(instrument_id)
	var tur: float = budget["tur"]
	var tur_note: String = "REFUSED, under %s:1" % SP811.number(CalUncertainty.tur_floor(), 0) if budget["refused"] \
		else ("" if budget["clean"] else "marginal, under %s:1" % SP811.number(CalUncertainty.tur_clean(), 0))
	# A counted Hold the Reading score: the U and TUR are the steady-hold
	# figures, and say so. The limit (and the verdict) are the plain budget's,
	# and "marginal" is said of the plain TUR, which is then shown too.
	if budget.get("steady_hold", false):
		tur_note = STEADY_HOLD_NOTE if tur_note == "" else STEADY_HOLD_MARGINAL % [
			STEADY_HOLD_NOTE, SP811.number(budget.get("plain_tur", tur), 1), SP811.number(CalUncertainty.tur_clean(), 0)]
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


## A long unit, like percentage points, gets a smaller size so the number fits its panel.
func _fit(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", LONG_VALUE_SIZE if label.text.length() > LONG_VALUE_CHARS else BIG_VALUE_SIZE)
