extends Node
## Live simulation state that must survive scene swaps. Autoloaded as `GameState`.
##
## Scenes read from and write to this; they never own sensor/molt/inventory
## state themselves. Ticks in _process, so the dome keeps simulating while
## you're on the farm and vice versa.

signal molt_changed(progress: float, stage: int)
signal silk_changed(spools: int)
signal relay_changed(slotted: bool)
signal calibration_recorded(record: Dictionary)
signal phone_message(text: String)
signal credits_changed(credits: int)
signal audit_completed(report: Dictionary)
signal drop_pod_changed(present: bool)

enum MoltStage { ACTIVE, PRE_MOLT, MOLTED }

const STEERING_ID: String = "rover_steering_encoder"
const HYGROMETER_ID: String = "hygrometer"
const SPECIES_TABLE: StringName = &"tarantula_species"
const ITEMS_TABLE: StringName = &"items"
const ECONOMY_TABLE: StringName = &"economy"
const DRIFT_TABLE: StringName = &"sensor_drift_config"
const DISPATCH_TABLE: StringName = &"dialogue_dispatches"
const PHONE_LOG_MAX: int = 40
const INSTRUMENT_NAMES: Dictionary = {
	"rover_steering_encoder": "Steering",
	"hygrometer": "Hygrometer",
}

# --- Playtest tuning (Week 2 board: keep the loop under two minutes) ---------
## Seconds for a full molt while the hygrometer stays within MPE.
## Replace with the species' molt_days on the GameClock once Week 3 lands.
const PLAYTEST_MOLT_SECONDS: float = 20.0
## Pre-molt visual state starts at this progress.
const PRE_MOLT_AT: float = 0.8
## The dome hygrometer starts out of tolerance ("gold sticker expired at 03:00")
## so the first dome visit has something to calibrate. |error| = MPE * this.
const HYGROMETER_START_ERROR_RATIO: float = 1.12
## Clamp on |error| as a multiple of MPE.
const MAX_ERROR_MPE_MULTIPLE: float = 3.0

var steering: DriftingSensor
var hygrometer: DriftingSensor

var dome_species_id: StringName = &"curlyhair"
var molt_progress: float = 0.0
var molt_stage: MoltStage = MoltStage.ACTIVE
var optical_silk_spools: int = 0
var relay_slotted: bool = false
## Species that spun the spool now in the relay (its lag_reduction_pct stacks).
var slotted_spool_species: StringName = &""
## Species of each spool in inventory, oldest first (parallel to optical_silk_spools).
var _spool_species: Array[StringName] = []
## Every calibration event, oldest first. Week 3 audits read this, so a
## FAIL can't be erased by calibrating again.
var cal_log: Array[Dictionary] = []
## Instrument id -> most recent record (convenience view of cal_log).
var last_cal_records: Dictionary = {}

## Credits (MegaCorp scrip). Fines come out of this; can go negative.
var credits: int = 0
## Phone messages that should survive scene swaps (dispatches, audits).
var phone_log: Array[String] = []
## One report per audit (see AuditEngine.evaluate).
var audit_log: Array[Dictionary] = []
## instrument_id -> number of audits that fined it (repeat surcharge).
var offence_counts: Dictionary = {}
## True from an audit morning until the pod departs that evening.
var drop_pod_present: bool = false
var _drop_pod_day: int = 0

var _cal_index_at_last_audit: int = 0
var _dispatch_deck: Array[Dictionary] = []

## Farm persistence across swaps.
var rover_transform: Transform3D = Transform3D.IDENTITY
var has_rover_transform: bool = false
## Vector3i -> true for every tilled soil cell.
var tilled_cells: Dictionary = {}


func _ready() -> void:
	steering = DriftingSensor.from_config(STEERING_ID)
	steering.max_error = steering.mpe * MAX_ERROR_MPE_MULTIPLE
	hygrometer = DriftingSensor.from_config(HYGROMETER_ID)
	hygrometer.max_error = hygrometer.mpe * MAX_ERROR_MPE_MULTIPLE
	hygrometer.error = hygrometer.mpe * HYGROMETER_START_ERROR_RATIO
	# Starting calibrations: steering is in date; the hygrometer's sticker
	# already expired (due day 0), so it is overdue until calibrated.
	var initial_interval: int = int(_interval_cfg("initial_days", 5.0))
	for sensor: DriftingSensor in [steering, hygrometer]:
		sensor.cal_interval_days = initial_interval
	steering.cal_due_day = initial_interval
	hygrometer.cal_due_day = 0
	GameClock.time_advanced.connect(_on_time_advanced)
	GameClock.day_started.connect(_on_day_started)
	credits = int(DataManager.get_number(ECONOMY_TABLE, "starting_credits", 0.0))
	_post_morning_dispatch(1)  # day 1 is already under way at boot


func _unhandled_input(event: InputEvent) -> void:
	# Debug builds only: F9 skips to the next 06:00 (sensors drift for the skipped time).
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.physical_keycode == KEY_F9:
		GameClock.skip_to_next_morning()


func _process(delta: float) -> void:
	_tick_molt(delta)


# --- Instruments --------------------------------------------------------------

func get_sensor(instrument_id: String) -> DriftingSensor:
	match instrument_id:
		STEERING_ID:
			return steering
		HYGROMETER_ID:
			return hygrometer
	return null


## Zeroes an instrument and stores the record. Same path for the bench and the
## phone's remote ZERO STEERING, so every calibration lands in the log.
func calibrate(instrument_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		push_warning("GameState.calibrate: unknown instrument '%s'." % instrument_id)
		return {}
	var today: int = GameClock.get_day_index()
	var on_time: bool = not sensor.is_overdue(today)
	var result: Dictionary = sensor.zero()
	var as_found: float = result["as_found"]
	var as_left: float = result["as_left"]
	var as_found_ok: bool = absf(as_found) <= sensor.mpe
	# Interval adjustment: a failed as-found brings the next calibration
	# sooner; an on-time pass earns a longer interval; a late pass keeps it.
	var previous_interval: int = sensor.cal_interval_days
	if not as_found_ok:
		sensor.cal_interval_days = maxi(int(_interval_cfg("min_days", 2.0)),
			previous_interval - int(_interval_cfg("shorten_days", 2.0)))
	elif on_time:
		sensor.cal_interval_days = mini(int(_interval_cfg("max_days", 15.0)),
			previous_interval + int(_interval_cfg("lengthen_days", 2.0)))
	sensor.cal_due_day = today + sensor.cal_interval_days
	var record: Dictionary = {
		"instrument_id": instrument_id,
		"unit": sensor.error_unit,
		"mpe": sensor.mpe,
		"as_found": as_found,
		"as_found_band": sensor.band_for(as_found),
		"as_found_in_tolerance": as_found_ok,
		"as_left": as_left,
		"as_left_band": sensor.band_for(as_left),
		"day": today,
		"on_time": on_time,
		"previous_interval_days": previous_interval,
		"interval_days": sensor.cal_interval_days,
		"due_day": sensor.cal_due_day,
	}
	cal_log.append(record)
	last_cal_records[instrument_id] = record
	calibration_recorded.emit(record)
	return record


func _on_time_advanced(delta_days: float) -> void:
	steering.advance_days(delta_days)
	hygrometer.advance_days(delta_days)
	# Leaves at the departure hour, or at once if a time skip jumped past that evening.
	if drop_pod_present and (GameClock.get_day_index() != _drop_pod_day
			or GameClock.get_hour() >= _schedule("drop_pod_departs_hour", 18.0)):
		drop_pod_present = false
		drop_pod_changed.emit(false)
		post_phone("AUD-1T: Departing. Please remain compliant in our absence.")


# --- Phone, dispatches, audits ------------------------------------------------

func post_phone(text: String) -> void:
	phone_log.append(text)
	while phone_log.size() > PHONE_LOG_MAX:
		phone_log.remove_at(0)
	phone_message.emit(text)


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)


func _on_day_started(day: int) -> void:
	_post_morning_dispatch(day)
	var cadence: int = int(_schedule("cadence_days", 5.0))
	if cadence > 0 and day % cadence == 0:
		_run_audit(day)


## One morning dispatch per day, no repeats until the whole deck is used.
func _post_morning_dispatch(day: int) -> void:
	if _dispatch_deck.is_empty():
		_dispatch_deck = DataManager.get_records(DISPATCH_TABLE, "morning_dispatches")
		_dispatch_deck.shuffle()
	if _dispatch_deck.is_empty():
		return
	var entry: Dictionary = _dispatch_deck.pop_back()
	post_phone("DAY %d  [%s] %s" % [day, entry.get("sender", "?"), entry.get("text", "")])


func _run_audit(day: int) -> void:
	var since: Array[Dictionary] = []
	since.assign(cal_log.slice(_cal_index_at_last_audit))
	_cal_index_at_last_audit = cal_log.size()
	var sensors: Dictionary = { STEERING_ID: steering, HYGROMETER_ID: hygrometer }
	var report: Dictionary = AuditEngine.evaluate(day, sensors, offence_counts, since)

	drop_pod_present = true
	_drop_pod_day = day
	drop_pod_changed.emit(true)
	post_phone("AUDIT DAY %d: Inspector Vance and AUD-1T have landed." % day)
	for line: Dictionary in report["lines"]:
		var sensor: DriftingSensor = get_sensor(line["instrument_id"])
		# Three decimals so 1.004 x MPE doesn't read as "1.00 ... OUT OF TOLERANCE".
		var label: String = "%s %s (%.3f x MPE) %s" % [
			INSTRUMENT_NAMES.get(line["instrument_id"], line["instrument_id"]),
			sensor.format_value(line["as_found"]), line["ratio"], DriftingSensor.band_label(line["band"])]
		if line["overdue"]:
			label += ", OVERDUE (due day %d)" % line["due_day"]
		if line["violation"]:
			offence_counts[line["instrument_id"]] = int(offence_counts.get(line["instrument_id"], 0)) + 1
			label += ": FINE %d CR" % line["fine"]
		post_phone(label)
	post_phone("Traceability: %d calibration record(s) since last audit, %d found out of tolerance." % [
		report["cal_records"], report["cal_fails_found"]])
	if report["passed"]:
		# A fully clean audit wipes the repeat-offence history.
		offence_counts.clear()
		post_phone("VANCE: Compliant. Repeat-offence record cleared. Disappointing, frankly.")
	else:
		add_credits(-int(report["total_fine"]))
		var fines: Array[Dictionary] = DataManager.get_records(DISPATCH_TABLE, "audit_fines")
		var footer: String = fines.pick_random().get("snarky_footer", "") if not fines.is_empty() else ""
		post_phone("TOTAL FINE %d CR. Balance %d CR. %s" % [report["total_fine"], credits, footer])
	audit_log.append(report)
	audit_completed.emit(report)


func _interval_cfg(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "calibration_interval/" + key, fallback)


func _schedule(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "audit_schedule/" + key, fallback)


# --- Molt & silk ----------------------------------------------------------------

## Molt only advances while the hygrometer is within MPE (green or amber).
func is_molt_paused() -> bool:
	return hygrometer.get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE


func is_spool_ready() -> bool:
	return molt_stage == MoltStage.MOLTED


func _tick_molt(delta: float) -> void:
	if molt_stage == MoltStage.MOLTED or is_molt_paused():
		return
	molt_progress = minf(1.0, molt_progress + delta / PLAYTEST_MOLT_SECONDS)
	if molt_progress >= 1.0:
		molt_stage = MoltStage.MOLTED
	elif molt_progress >= PRE_MOLT_AT:
		molt_stage = MoltStage.PRE_MOLT
	else:
		molt_stage = MoltStage.ACTIVE
	molt_changed.emit(molt_progress, molt_stage)


## Picks up the spool from a molted enclosure and starts the next molt cycle.
func collect_spool() -> bool:
	if not is_spool_ready():
		return false
	optical_silk_spools += 1
	_spool_species.append(dome_species_id)
	molt_progress = 0.0
	molt_stage = MoltStage.ACTIVE
	silk_changed.emit(optical_silk_spools)
	molt_changed.emit(molt_progress, molt_stage)
	return true


# --- Relay ----------------------------------------------------------------------

func can_slot_spool() -> bool:
	return optical_silk_spools > 0 and not relay_slotted


func slot_spool_into_relay() -> bool:
	if not can_slot_spool():
		return false
	optical_silk_spools -= 1
	slotted_spool_species = _spool_species.pop_front() if not _spool_species.is_empty() else dome_species_id
	relay_slotted = true
	silk_changed.emit(optical_silk_spools)
	relay_changed.emit(relay_slotted)
	return true


## Multiplier applied to rover uplink lag (1.0 = no upgrade). The spool's base
## cut and the spinning species' lag_reduction_pct stack multiplicatively:
## (1 - spool%) * (1 - species%). Curlyhair: 0.40 * 0.95 = 0.38.
func get_relay_lag_multiplier() -> float:
	if not relay_slotted:
		return 1.0
	var spool_pct: float = DataManager.get_number(ITEMS_TABLE, "optical_silk_spool/relay_lag_reduction_pct", 0.0)
	var species_pct: float = 0.0
	var raw: Variant = DataManager.get_record(SPECIES_TABLE, slotted_spool_species).get("lag_reduction_pct")
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:  # null for undesigned morphs
		species_pct = float(raw)
	return clampf((1.0 - spool_pct / 100.0) * (1.0 - species_pct / 100.0), 0.0, 1.0)


func get_dome_species() -> Dictionary:
	return DataManager.get_record(SPECIES_TABLE, dome_species_id)
