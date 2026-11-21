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

enum MoltStage { ACTIVE, PRE_MOLT, MOLTED }

const STEERING_ID: String = "rover_steering_encoder"
const HYGROMETER_ID: String = "hygrometer"
const SPECIES_TABLE: StringName = &"tarantula_species"
const ITEMS_TABLE: StringName = &"items"

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
## Every calibration event, oldest first. Week 3 audits read this, so a
## FAIL can't be erased by calibrating again.
var cal_log: Array[Dictionary] = []
## Instrument id -> most recent record (convenience view of cal_log).
var last_cal_records: Dictionary = {}

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
	GameClock.time_advanced.connect(_on_time_advanced)


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
	var result: Dictionary = sensor.zero()
	var as_found: float = result["as_found"]
	var as_left: float = result["as_left"]
	var record: Dictionary = {
		"instrument_id": instrument_id,
		"unit": sensor.error_unit,
		"mpe": sensor.mpe,
		"as_found": as_found,
		"as_found_band": sensor.band_for(as_found),
		"as_found_in_tolerance": absf(as_found) <= sensor.mpe,
		"as_left": as_left,
		"as_left_band": sensor.band_for(as_left),
		"day": GameClock.get_day_index(),
	}
	cal_log.append(record)
	last_cal_records[instrument_id] = record
	calibration_recorded.emit(record)
	return record


func _on_time_advanced(delta_days: float) -> void:
	steering.advance_days(delta_days)
	hygrometer.advance_days(delta_days)


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
	relay_slotted = true
	silk_changed.emit(optical_silk_spools)
	relay_changed.emit(relay_slotted)
	return true


## Multiplier applied to rover uplink lag (1.0 = no upgrade).
func get_relay_lag_multiplier() -> float:
	if not relay_slotted:
		return 1.0
	var pct: float = DataManager.get_number(ITEMS_TABLE, "optical_silk_spool/relay_lag_reduction_pct", 0.0)
	return clampf(1.0 - pct / 100.0, 0.0, 1.0)


func get_dome_species() -> Dictionary:
	return DataManager.get_record(SPECIES_TABLE, dome_species_id)
