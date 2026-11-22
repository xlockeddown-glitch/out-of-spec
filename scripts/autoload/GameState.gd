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
signal ore_changed(ore: int)
signal fissures_changed
signal upgrades_changed
## A standard left on, or came back from, the OIRM drop pod (milestone 2).
signal oirm_changed
signal credibility_changed(points: int)
## A crop was planted, grew, or was harvested (income milestone).
signal crops_changed

enum MoltStage { ACTIVE, PRE_MOLT, MOLTED }

const STEERING_ID: String = "rover_steering_encoder"
const HYGROMETER_ID: String = "hygrometer"
const TIRE_ID: String = "rover_tire_pressure"
const THERMOMETER_ID: String = "terrarium_thermometer"
const SPECIES_TABLE: StringName = &"tarantula_species"
const ITEMS_TABLE: StringName = &"items"
const ECONOMY_TABLE: StringName = &"economy"
const DRIFT_TABLE: StringName = &"sensor_drift_config"
const DISPATCH_TABLE: StringName = &"dialogue_dispatches"
const CROPS_TABLE: StringName = &"crops"
const SOIL_PROBE_ID: String = "soil_probe"
## Set-point step for [ and ], as a volumetric fraction (1 %).
const SETPOINT_STEP: float = 0.01
const PHONE_LOG_MAX: int = 40

# --- Playtest tuning (Week 2 board: keep the loop under two minutes) ---------
## Seconds for a full molt while the hygrometer stays within MPE.
## Replace with the species' molt_days on the GameClock once Week 3 lands.
const PLAYTEST_MOLT_SECONDS: float = 20.0
## Pre-molt visual state starts at this progress.
const PRE_MOLT_AT: float = 0.8
## In-game days the shed exuvia stays in the enclosure after the spool is
## taken (Ryan's call: 1, gone the next morning). The spider stays in its
## burrow (hidden) until then, since the two can't share the tank floor.
const EXUVIA_LINGER_DAYS: int = 1
## The dome hygrometer starts out of tolerance ("gold sticker expired at 03:00")
## so the first dome visit has something to calibrate. |error| = MPE * this.
const HYGROMETER_START_ERROR_RATIO: float = 1.12
## Clamp on |error| as a multiple of MPE.
const MAX_ERROR_MPE_MULTIPLE: float = 3.0

## Every instrument in sensor_drift_config/instruments, units and standards,
## in data order: instrument_id -> DriftingSensor. Built by build_registry().
var sensors: Dictionary = {}
## Shortcuts into `sensors` for the scenes that read these two directly.
var steering: DriftingSensor
var hygrometer: DriftingSensor

var dome_species_id: StringName = &"curlyhair"
var molt_progress: float = 0.0
var molt_stage: MoltStage = MoltStage.ACTIVE
## Day index on whose morning the exuvia from the last spool pickup is gone
## (0 = no exuvia lingering).
var exuvia_until_day: int = 0
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
## Instrument id -> true when an untraceable zero was logged since its last
## traceable calibration. The next bench pass then can't lengthen the interval,
## so a remote zero can't hide a FAIL from the interval logic.
var _untraceable_since_cal: Dictionary = {}

# --- OIRM and traceability (milestone 2) ---
## standard_id -> its current OIRM certificate (see _issue_certificate).
var certificates: Dictionary = {}
## Every certificate issued, oldest first, founding stock included.
var certificate_log: Array[Dictionary] = []
## standard_id -> the day it comes back (next audit pod, or courier).
var at_oirm: Dictionary = {}
## Every trip to OIRM: { standard_id, sent_day, return_day, courier }. Used to
## excuse units that fell due while their standard was away.
var oirm_trips: Array[Dictionary] = []
## Unit id -> day a recall made its calibration suspect. A traceable
## recalibration clears it; Vance fines what is left at the audit.
var suspect_units: Dictionary = {}
## Audits in a row with no violations (a grace warning breaks the streak).
var clean_audit_streak: int = 0
## Tier 1 equipment gate: the first audit with zero violations (Q19).
var tier1_unlocked: bool = false
var _next_certificate_number: int = 1
## Standards on the colony: id -> day acquired. Tier 0 from day 0; Tier 1+
## once bought from Bram (milestone 3a).
var owned_standards: Dictionary = {}

## Credits (MegaCorp scrip). Fines come out of this; can go negative.
var credits: int = 0
## Phone messages that should survive scene swaps (dispatches, audits).
var phone_log: Array[String] = []
## One report per audit (see AuditEngine.evaluate).
var audit_log: Array[Dictionary] = []
## instrument_id -> number of audits that fined it (repeat surcharge).
var offence_counts: Dictionary = {}
## True from an audit morning until the pod's scheduled departure.
var drop_pod_present: bool = false
var _drop_pod_departure_at: float = 0.0
## Crystal ore carried by the rover, and fissure id -> day it was mined.
var crystal_ore: int = 0
var mined_fissures: Dictionary = {}
var has_wide_treads: bool = false

## One-time grace: the first audit that would fine you becomes a warning,
## because your manager recalibrated the offenders before Vance got in.
var audit_grace_used: bool = false

var _cal_index_at_last_audit: int = 0
var _dispatch_deck: Array[Dictionary] = []

## Farm persistence across swaps.
var rover_transform: Transform3D = Transform3D.IDENTITY
var has_rover_transform: bool = false
## Vector3i -> true for every tilled soil cell.
var tilled_cells: Dictionary = {}

## Lab credibility (Ryan, 2026-11-22): audits and overdue instruments move it;
## the phone shows its band. See data/economy.json "credibility".
var credibility: int = 0
## Highest band index reached so far, so a band is announced once.
var _best_band: int = 0
## First OIRM contract: "" (not offered), "active" (counting the run),
## "complete" (its standard is for sale) or "fulfilled" (bought).
var contract_state: String = ""
var contract_run: int = 0

## Income milestone (Ryan, 2026-11-22): crops on tilled cells, auto-irrigated
## to a set point as the soil probe reads it, sold to Lin.
## Vector3i -> { crop_id, planted_day, days_grown, setpoint, out_of_band_days }
var plantings: Dictionary = {}
## Harvested crops waiting for Lin: { crop_id, in_spec, out_of_band_days }.
var harvest_bin: Array[Dictionary] = []
## The crop the next planting uses ("" = the first in data/crops.json).
var seed_crop_id: String = ""


func _ready() -> void:
	build_registry()
	# The hygrometer's sticker already expired (due day 0), so it is overdue
	# and out of tolerance until calibrated; everything else starts in date.
	hygrometer.error = hygrometer.mpe * HYGROMETER_START_ERROR_RATIO
	hygrometer.cal_due_day = 0
	GameClock.time_advanced.connect(_on_time_advanced)
	GameClock.day_started.connect(_on_day_started)
	GameClock.day_started.connect(_on_day_started_regrow.unbind(1))
	credits = int(DataManager.get_number(ECONOMY_TABLE, "starting_credits", 0.0))
	reset_credibility()
	_post_morning_dispatch(1)  # day 1 is already under way at boot


func _unhandled_input(event: InputEvent) -> void:
	# Debug builds only: F9 skips to the next 06:00 (sensors drift for the skipped time).
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.physical_keycode == KEY_F9:
		GameClock.skip_to_next_morning()


func _process(delta: float) -> void:
	_tick_molt(delta)


# --- Instruments --------------------------------------------------------------

## (Re)builds `sensors` from sensor_drift_config/instruments. Each sensor
## starts in date with its own initial interval (standards) or the global one.
## Called from _ready(); tests call it on a GameState that is not in the tree.
func build_registry() -> void:
	sensors.clear()
	var table: Variant = DataManager.get_value(DRIFT_TABLE, "instruments", {})
	if typeof(table) != TYPE_DICTIONARY:
		push_error("GameState: %s/instruments is not an object." % DRIFT_TABLE)
		return
	var initial_interval: int = int(_interval_cfg("initial_days", 5.0))
	owned_standards.clear()
	for key: Variant in table:
		var id: String = str(key)
		if id.begins_with("_"):
			continue
		var sensor: DriftingSensor = DriftingSensor.from_config(id)
		sensor.max_error = sensor.mpe * MAX_ERROR_MPE_MULTIPLE
		sensor.cal_interval_days = sensor.initial_interval_days if sensor.initial_interval_days > 0 else initial_interval
		sensor.cal_due_day = sensor.cal_interval_days
		sensors[id] = sensor
		if sensor.role == "standard" and sensor.tier <= 0:
			owned_standards[id] = 0
	steering = sensors.get(STEERING_ID)
	hygrometer = sensors.get(HYGROMETER_ID)
	_issue_founding_certificates()
	if steering == null or hygrometer == null:
		push_error("GameState: %s needs %s and %s." % [DRIFT_TABLE, STEERING_ID, HYGROMETER_ID])


func get_sensor(instrument_id: String) -> DriftingSensor:
	return sensors.get(instrument_id)


## Ids of the instruments Vance audits and the bench calibrates, in data order:
## the units in service, whose standard is on the colony.
func unit_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_unit_ids():
		if is_in_service(id):
			ids.append(id)
	return ids


## Ids of the reference standards on the colony, in data order.
func standard_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_standard_ids():
		if owned_standards.has(id):
			ids.append(id)
	return ids


## Every unit in the data, in service or not.
func all_unit_ids() -> Array[String]:
	return _ids_with_role("unit")


## Every standard in the data, owned or not (Bram's catalog included).
func all_standard_ids() -> Array[String]:
	return _ids_with_role("standard")


## A unit is in service once the standard it is calibrated against is on the
## colony; a standard once it is owned. Out-of-service instruments don't drift.
func is_in_service(instrument_id: String) -> bool:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return false
	if sensor.role == "standard":
		return owned_standards.has(instrument_id)
	return sensor.calibrated_by != "" and owned_standards.has(sensor.calibrated_by)


func _ids_with_role(role: String) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in sensors:
		if (sensors[id] as DriftingSensor).role == role:
			ids.append(str(id))
	return ids


## Short name for phone lines ("Steering"), or the full bench name.
func instrument_name(instrument_id: String, full: bool = false) -> String:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return instrument_id
	return sensor.display_name if full else sensor.short_name


## Uncertainty budget for calibrating `instrument_id` against its standard
## right now (see CalUncertainty.budget). Empty if it has no standard.
func calibration_budget(instrument_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null or sensor.calibrated_by == "":
		return {}
	var standard: DriftingSensor = get_sensor(sensor.calibrated_by)
	if standard == null:
		push_warning("GameState: %s names unknown standard '%s'." % [instrument_id, sensor.calibrated_by])
		return {}
	return CalUncertainty.budget(sensor, standard)


## Zeroes an instrument and stores the record. Same path for the bench, the
## manager's grace calibration and the phone's remote ZERO STEERING, so every
## calibration lands in the log.
##
## With `use_standard` the unit is compared against its standard: the record
## gets the standard, U, TUR, acceptance limit and a pass / indeterminate /
## fail result, and the standard's hidden error is carried into the unit. A
## TUR under the floor refuses the calibration: nothing changes and the
## returned dictionary has "refused": true and a "reason". Without a standard
## (the remote zero) the result is plain pass / fail against the MPE, and the
## zero is untraceable: it adjusts the unit but is not a calibration, so the
## interval, due day and last calibration day stay as they were.
## `bench_minutes` is copied onto the record (0 off the bench).
func calibrate(instrument_id: String, performed_by: String = "You", use_standard: bool = true,
		bench_minutes: float = 0.0) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		push_warning("GameState.calibrate: unknown instrument '%s'." % instrument_id)
		return {}
	if use_standard and sensor.role == "unit" and not is_in_service(instrument_id):
		return {
			"instrument_id": instrument_id,
			"refused": true,
			"standard_id": sensor.calibrated_by,
			"tur": 0.0,
			"reason": ("%s has no standard on the colony yet." % instrument_name(instrument_id, true)
				if sensor.calibrated_by == "" else "The %s is not on the colony yet." % instrument_name(sensor.calibrated_by, true)),
		}
	var budget: Dictionary = calibration_budget(instrument_id) if use_standard else {}
	if budget.get("refused", false):
		return {
			"instrument_id": instrument_id,
			"refused": true,
			"standard_id": budget["standard_id"],
			"tur": budget["tur"],
			"reason": "TUR %s:1 is under the %s:1 floor. The standard is not good enough for this instrument." % [
				SP811.number(budget["tur"], 1), SP811.number(CalUncertainty.tur_floor(), 0)],
		}
	if not budget.is_empty() and at_oirm.has(budget["standard_id"]):
		return {
			"instrument_id": instrument_id,
			"refused": true,
			"standard_id": budget["standard_id"],
			"tur": budget["tur"],
			"reason": "%s is at OIRM until day %d." % [
				instrument_name(budget["standard_id"], true), at_oirm[budget["standard_id"]]],
		}
	var standard: DriftingSensor = get_sensor(budget["standard_id"]) if not budget.is_empty() else null
	var today: int = GameClock.get_day_index()
	var on_time: bool = not sensor.is_overdue(today)
	# Without a standard the unit is zeroed against its own idea of zero, which
	# still carries the offset from its last bench calibration: the as-found is
	# the observed error and a bad standard stays hidden (Ryan, 2026-11-22).
	# A standard of another quantity carries its error through the chain's
	# sensitivity (FM-3 volts into thermometer degrees Celsius, section 1.5).
	var zeroed: Dictionary = sensor.zero(standard.error * sensor.standard_sensitivity if standard else sensor.reference_offset)
	var as_found: float = zeroed["as_found"]
	var as_left: float = zeroed["as_left"]
	var as_found_ok: bool = absf(as_found) <= sensor.mpe
	var limit: float = budget.get("acceptance_limit", sensor.mpe)
	var result: String = CalUncertainty.classify(as_found, sensor.mpe, limit)
	# Interval adjustment: a failed as-found brings the next calibration
	# sooner; an on-time pass earns a longer interval; a late pass keeps it.
	# An indeterminate result counts as an on-time pass that does not lengthen.
	# A pass only counts as interval evidence if the instrument has run at
	# least half its interval since the last calibration, so re-calibrating
	# the same day can't farm longer intervals or erase a shortened one.
	# A link in the chain needs a standard that was in date that day (section 1.7);
	# with an overdue standard the zero adjusts the unit but is not a calibration.
	var standard_overdue: bool = standard.is_overdue(today) if standard else false
	var traceable: bool = standard != null and not standard_overdue
	var previous_interval: int = sensor.cal_interval_days
	var days_in_service: int = today - sensor.last_cal_day if sensor.last_cal_day >= 0 else previous_interval
	var enough_service: bool = days_in_service >= ceili(previous_interval / 2.0)
	if not traceable:
		_untraceable_since_cal[instrument_id] = true
	elif _untraceable_since_cal.has(instrument_id):
		enough_service = false
		_untraceable_since_cal.erase(instrument_id)
	if traceable:
		suspect_units.erase(instrument_id)  # redone after a recall
		if result == CalUncertainty.FAIL:
			sensor.cal_interval_days = maxi(int(_interval_cfg("min_days", 2.0)),
				previous_interval - int(_interval_cfg("shorten_days", 2.0)))
		elif result == CalUncertainty.PASS and on_time and enough_service:
			sensor.cal_interval_days = mini(int(_interval_cfg("max_days", 15.0)),
				previous_interval + int(_interval_cfg("lengthen_days", 2.0)))
		sensor.cal_due_day = today + sensor.cal_interval_days
		sensor.last_cal_day = today
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
		"performed_by": performed_by,
		"on_time": on_time,
		"days_in_service": days_in_service,
		"interval_evidence": enough_service,
		"previous_interval_days": previous_interval,
		"interval_days": sensor.cal_interval_days,
		"due_day": sensor.cal_due_day,
		# "" and null when no standard was used (the remote zero).
		"standard_id": budget.get("standard_id", ""),
		"standard_uncertainty": budget.get("expanded_uncertainty"),
		"tur": budget.get("tur"),
		"acceptance_limit": limit,
		"result": result,
		"traceable": traceable,
		"bench_minutes": bench_minutes,
		"standard_overdue": standard_overdue,
		"standard_certificate": certificates.get(standard.instrument_id, {}).get("id", "") if standard else "",
		# Set by recall() if the standard is later found out of tolerance and
		# correcting for its error changes this result.
		"suspect": false,
	}
	cal_log.append(record)
	last_cal_records[instrument_id] = record
	calibration_recorded.emit(record)
	_credibility_after_calibration(record)
	return record


## The player's bench calibration: calibrate() against the standard, then the
## bench time passes on the game clock (instruments keep drifting meanwhile).
## The record gains "bench_minutes". A refused calibration takes no time.
func calibrate_at_bench(instrument_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return {}
	var minutes: float = sensor.bench_minutes
	var record: Dictionary = calibrate(instrument_id, "You", true, minutes)
	if record.is_empty() or record.get("refused", false):
		return record
	if minutes > 0.0:
		GameClock.advance(minutes / 1440.0)
	return record


func _on_time_advanced(delta_days: float) -> void:
	for id: Variant in sensors:
		if is_in_service(str(id)):
			(sensors[id] as DriftingSensor).advance_days(delta_days)
	if drop_pod_present and GameClock.elapsed_days >= _drop_pod_departure_at:
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
	# Courier returns land in the morning, before an audit that day.
	_receive_oirm_returns(day)
	_charge_overdue_credibility(day)
	_grow_crops()
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
	# Standards on this pod come back (and are certified) before Vance inspects.
	# _on_day_started already did this in play; keep it for direct calls (tests).
	_receive_oirm_returns(day)
	# Units and standards; a standard away at OIRM is not here to inspect.
	var audited: Dictionary = {}
	for id: String in unit_ids() + standard_ids():
		if not at_oirm.has(id):
			audited[id] = sensors[id]
	# A recall found on this pod gives the player until the next audit to redo it.
	var fineable_suspects: Dictionary = {}
	for id: Variant in suspect_units:
		if int(suspect_units[id]) < day:
			fineable_suspects[id] = suspect_units[id]
	var excused: Dictionary = _excused_units(day)
	var report: Dictionary = AuditEngine.evaluate(day, audited, offence_counts, since, fineable_suspects, excused)
	# AUD-1T measures the rover tires once the WD-1 has the tire gauge in service.
	if is_in_service(TIRE_ID):
		var tire: Dictionary = AuditEngine.tire_check(get_sensor(TIRE_ID).error)
		report["tire_check"] = tire
		if tire["violation"]:
			report["passed"] = false
			report["total_fine"] = int(report["total_fine"]) + int(tire["fine"])

	if not report["passed"] and not audit_grace_used:
		_apply_audit_grace(report)

	var departure_hour: float = _schedule("drop_pod_departs_hour", 18.0)
	_drop_pod_departure_at = GameClock.elapsed_at_hour(day, departure_hour)
	# A 06:00 departure means the end of the audit day, not the moment it starts.
	if _drop_pod_departure_at - float(day - 1) < 1.0e-6:
		_drop_pod_departure_at += 1.0
	post_phone("AUDIT DAY %d: Inspector Vance and AUD-1T have landed." % day)
	# A time skip can run the audit after its departure deadline has passed.
	if GameClock.elapsed_days < _drop_pod_departure_at:
		drop_pod_present = true
		drop_pod_changed.emit(true)
	else:
		post_phone("AUD-1T: Departing. Please remain compliant in our absence.")
	for line: Dictionary in report["lines"]:
		var sensor: DriftingSensor = get_sensor(line["instrument_id"])
		# Three decimals so 1.004 x MPE doesn't read as "1.00 ... OUT OF TOLERANCE".
		var label: String = ("%s certificate %s" % [instrument_name(line["instrument_id"]),
				certificates.get(line["instrument_id"], {}).get("id", "missing")]
			if line.get("standard", false)
			else "%s %s (%s × MPE) %s" % [
				instrument_name(line["instrument_id"]),
				sensor.format_value(line["as_found"]), SP811.number(line["ratio"], 3), DriftingSensor.band_label(line["band"])])
		if line["overdue"]:
			label += ", OVERDUE (due day %d)" % line["due_day"]
		if line.get("excused", false):
			label += ", EXCUSED (its standard was at OIRM when it fell due; calibrate before the day %d audit)" % excused[line["instrument_id"]]
		if line.get("suspect", false):
			label += ", SUSPECT CAL (recalled, not redone)"
		if line.get("waived", false):
			label += ": WAIVED (one-time warning)"
		elif line["violation"]:
			offence_counts[line["instrument_id"]] = int(offence_counts.get(line["instrument_id"], 0)) + 1
			label += ": FINE %s CR" % SP811.integer(line["fine"])
		post_phone(label)
	post_phone("Traceability: %d calibration record(s) since last audit, %d found out of tolerance." % [
		report["cal_records"], report["cal_fails_found"]])
	for id: String in unit_ids():
		var chain: Dictionary = traceability_chain(id)
		post_phone(("Chain: %s" if chain["traceable"] else "Chain BROKEN: %s") % chain["text"])
	# Last before the verdict, so the HUD's short log still shows it.
	if report.has("tire_check"):
		post_phone(_tire_check_line(report["tire_check"]))
	if report.get("warning", false):
		post_phone("MANAGER: Caught it before Vance got in: %s. One-time favor. Don't make it a habit." % report["waived_names"])
		post_phone("VANCE: Warning issued. Next time it's a fine.")
	elif report["passed"]:
		# A fully clean audit wipes the repeat-offence history.
		offence_counts.clear()
		post_phone("VANCE: Compliant. Repeat-offence record cleared. Disappointing, frankly.")
	else:
		add_credits(-int(report["total_fine"]))
		var fines: Array[Dictionary] = DataManager.get_records(DISPATCH_TABLE, "audit_fines")
		var footer: String = fines.pick_random().get("snarky_footer", "") if not fines.is_empty() else ""
		post_phone("TOTAL FINE %s CR. Balance %s CR. %s" % [SP811.integer(report["total_fine"]), SP811.integer(credits), footer])
	_update_clean_audit_gate(report)
	_credibility_after_audit(report)
	audit_log.append(report)
	audit_completed.emit(report)


## "AUD-1T: Rover tires 7.2 kPa below set point (limit 6.9 kPa). PETTY FINE 20 CR"
func _tire_check_line(tire: Dictionary) -> String:
	var offset: float = tire["offset_kpa"]
	var where: String = ("at set point" if is_zero_approx(offset)
		else "%s kPa %s set point" % [SP811.number(absf(offset), 1), "below" if offset < 0.0 else "above"])
	var text: String = "AUD-1T: Rover tires %s (limit %s kPa)" % [where, SP811.number(tire["limit_kpa"], 1)]
	if tire.get("waived", false):
		return text + ". WAIVED (one-time warning)"
	if tire["violation"]:
		return text + ". PETTY FINE %s CR" % SP811.integer(tire["fine"])
	return text + ". Compliant."


## Tier 1 needs one audit with zero violations; a grace warning is not clean
## (Q19). The streak is kept for the Tier 3 gate (milestone 3).
func _update_clean_audit_gate(report: Dictionary) -> void:
	if not report["passed"]:
		clean_audit_streak = 0
		return
	clean_audit_streak += 1
	report["clean"] = true
	if not tier1_unlocked:
		tier1_unlocked = true
		post_phone("VANCE: First clean audit on file. Tier 1 equipment is cleared for purchase.")


## Turns this audit's fines into a one-time warning. The manager calibrates
## each violating instrument (logged as theirs) before Vance inspects. Not a
## clean audit, so repeat-offence counts are neither raised nor cleared.
func _apply_audit_grace(report: Dictionary) -> void:
	audit_grace_used = true
	var names: PackedStringArray = []
	var excused: PackedStringArray = []
	for line: Dictionary in report["lines"]:
		if line["violation"]:
			# The manager uses the bench standard; if the TUR refuses, they zero it
			# without one (untraceable) rather than claim a calibration that didn't happen.
			# Standards are only calibrated at OIRM, so theirs are waived as they are.
			if get_sensor(line["instrument_id"]).role != "standard" \
					and calibrate(line["instrument_id"], "Manager").get("refused", false):
				calibrate(line["instrument_id"], "Manager", false)
			line["fine"] = 0
			line["waived"] = true
			if get_sensor(line["instrument_id"]).role == "standard":
				excused.append(_mid_sentence(instrument_name(line["instrument_id"])))
			else:
				names.append(_mid_sentence(instrument_name(line["instrument_id"])))
	var tire: Dictionary = report.get("tire_check", {})
	var tires_topped: bool = tire.get("violation", false)
	if tires_topped:
		tire["fine"] = 0
		tire["waived"] = true
	report["total_fine"] = 0
	report["warning"] = true
	# "recalibrated the steering encoder and talked Vance out of the lapsed certificate on the PX-1 rotary table"
	var done: PackedStringArray = []
	if not names.is_empty():
		done.append("recalibrated the " + " and the ".join(names))
	if not excused.is_empty():
		done.append("talked Vance out of the lapsed certificate on the " + " and the ".join(excused))
	if tires_topped:
		done.append("reset the rover tires")
	report["waived_names"] = " and ".join(done)


## A short name for use mid-sentence: "Steering" -> "steering", but a model
## designator such as "PX-1 rotary table" keeps its capitals.
static func _mid_sentence(name: String) -> String:
	var first: String = name.get_slice(" ", 0)
	if first.length() > 1 and first.substr(1) == first.substr(1).to_lower() 			and first.substr(1).to_upper() != first.substr(1).to_lower():
		return first.to_lower() + name.substr(first.length())
	return name

# --- OIRM, certificates, recall (milestone 2) -------------------------------------

## Tier 0 standards start with a certificate from the colony's founding stock
## (section 1.7 [ASSUMPTION]): issued day 0, due at the end of the first interval.
func _issue_founding_certificates() -> void:
	certificates.clear()
	certificate_log.clear()
	at_oirm.clear()
	oirm_trips.clear()
	suspect_units.clear()
	_next_certificate_number = 1
	for id: String in standard_ids():
		sensors[id].last_cal_day = 0
		_issue_certificate(id, 0, null, null, true)


## Records a new certificate for `standard_id` from its current due day: OIRM's,
## or with `issuer` / `prefix` a maker's certificate traceable to OIRM.
## as_found / as_left are null when no measurement is on file (founding stock,
## or the as-found of a new instrument).
func _issue_certificate(standard_id: String, day: int, as_found: Variant, as_left: Variant, founding: bool,
		issuer: String = "OIRM", prefix: String = "OIRM") -> Dictionary:
	var sensor: DriftingSensor = sensors[standard_id]
	var cert: Dictionary = {
		"id": "%s-%04d" % [prefix, _next_certificate_number],
		"standard_id": standard_id,
		"issuer": issuer,
		"day": day,
		"due_day": sensor.cal_due_day,
		"as_found": as_found,
		"as_left": as_left,
		"as_found_in_tolerance": as_found == null or absf(float(as_found)) <= sensor.mpe,
		"expanded_uncertainty": sensor.certificate_uncertainty,
		"k": sensor.certificate_k,
		"founding": founding,
	}
	_next_certificate_number += 1
	certificates[standard_id] = cert
	certificate_log.append(cert)
	return cert


## The next audit day after `day` (when the drop pod is back).
func next_audit_day(day: int) -> int:
	var cadence: int = maxi(int(_schedule("cadence_days", 5.0)), 1)
	return (day / cadence + 1) * cadence


func oirm_fee() -> int:
	return int(DataManager.get_number(DRIFT_TABLE, "oirm/fee_credits", 150.0))


func oirm_courier_surcharge() -> int:
	return int(DataManager.get_number(DRIFT_TABLE, "oirm/courier_surcharge_credits", 150.0))


func oirm_courier_days() -> int:
	return maxi(int(DataManager.get_number(DRIFT_TABLE, "oirm/courier_return_days", 7.0)), 1)


## Units overdue at this audit only because the standard they need was at OIRM
## when they fell due (Ryan, 2026-11-22). Excused at the first audit where they
## are overdue, and at any audit while the standard is still away or only came
## back that morning (a courier trip is longer than the audit cadence). After
## that they need a traceable calibration by the next audit.
## Returns instrument_id -> the audit day by which it must be calibrated.
func _excused_units(day: int) -> Dictionary:
	var excused: Dictionary = {}
	var cadence: int = maxi(int(_schedule("cadence_days", 5.0)), 1)
	for id: String in unit_ids():
		var sensor: DriftingSensor = sensors[id]
		var due: int = sensor.cal_due_day
		if not sensor.is_overdue(day):
			continue
		for i: int in oirm_trips.size():
			var trip: Dictionary = oirm_trips[i]
			var back: int = _trip_back(i, day)
			# Due after it left (the player could calibrate on the send day) and before it came back.
			if trip["standard_id"] == sensor.calibrated_by and int(trip["sent_day"]) < due and due < back \
					and (due >= day - cadence or back >= day):
				excused[id] = next_audit_day(maxi(day, back))
				break
	return excused


## The day trip `index` brought its standard back; for the trip still open
## (the standard's latest, while it is away) at least `day`, as it is late.
func _trip_back(index: int, day: int) -> int:
	var trip: Dictionary = oirm_trips[index]
	var back: int = int(trip["return_day"])
	if _trip_is_open(index):
		back = maxi(back, day)
	return back


func _trip_is_open(index: int) -> bool:
	var standard_id: String = oirm_trips[index]["standard_id"]
	if not at_oirm.has(standard_id):
		return false
	for later: int in range(index + 1, oirm_trips.size()):
		if oirm_trips[later]["standard_id"] == standard_id:
			return false
	return true


## Sends a standard to OIRM. With the drop pod on the pad it rides the pod
## for the fee and comes back on the next audit pod. On any other day it goes
## by courier for the fee plus a surcharge and comes back a fixed number of
## days later. Returns { "ok", "reason", "return_day", "courier", "fee" }.
func send_to_oirm(standard_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null or sensor.role != "standard":
		return { "ok": false, "reason": "Only reference standards go to OIRM." }
	if not owned_standards.has(standard_id):
		return { "ok": false, "reason": "The %s is not on the colony." % instrument_name(standard_id, true) }
	if at_oirm.has(standard_id):
		return { "ok": false, "reason": "Already at OIRM until day %d." % at_oirm[standard_id] }
	# No pod on the pad: it goes by courier for a surcharge (Ryan, 2026-11-22).
	var courier: bool = not drop_pod_present
	var fee: int = oirm_fee() + (oirm_courier_surcharge() if courier else 0)
	if credits < fee:
		return { "ok": false, "reason": "OIRM charges %s CR; balance %s CR." % [SP811.integer(fee), SP811.integer(credits)] }
	add_credits(-fee)
	var today: int = GameClock.get_day_index()
	var return_day: int = today + oirm_courier_days() if courier else next_audit_day(today)
	at_oirm[standard_id] = return_day
	oirm_trips.append({ "standard_id": standard_id, "sent_day": today, "return_day": return_day, "courier": courier })
	if courier:
		post_phone("OIRM: %s collected by courier. Fee %s CR (%s CR + %s CR courier). Back on day %d; nothing can be calibrated against it until then." % [
			instrument_name(standard_id, true), SP811.integer(fee), SP811.integer(oirm_fee()),
			SP811.integer(oirm_courier_surcharge()), return_day])
	else:
		post_phone("OIRM: %s loaded on the drop pod. Fee %s CR. Back on the day %d pod; nothing can be calibrated against it until then." % [
			instrument_name(standard_id, true), SP811.integer(fee), return_day])
	oirm_changed.emit()
	return { "ok": true, "reason": "", "return_day": return_day, "courier": courier, "fee": fee }


func _receive_oirm_returns(day: int) -> void:
	for id: Variant in at_oirm.keys():
		if int(at_oirm[id]) <= day:
			oirm_calibrate(str(id), day)


## OIRM's calibration of a returned standard: measured against a perfect
## reference, adjusted, and certified. Its interval is unchanged
## [ASSUMPTION]. An out-of-tolerance as-found starts a recall.
func oirm_calibrate(standard_id: String, day: int) -> Dictionary:
	var sensor: DriftingSensor = sensors[standard_id]
	at_oirm.erase(standard_id)
	var previous: Dictionary = certificates.get(standard_id, {})
	var zeroed: Dictionary = sensor.zero(0.0)
	sensor.cal_due_day = day + sensor.cal_interval_days
	sensor.last_cal_day = day
	# Close the trip on the day it actually came back, in case it was late.
	for i: int in range(oirm_trips.size() - 1, -1, -1):
		if oirm_trips[i]["standard_id"] == standard_id:
			oirm_trips[i]["return_day"] = day
			break
	var cert: Dictionary = _issue_certificate(standard_id, day, zeroed["as_found"], zeroed["as_left"], false)
	post_phone("OIRM: %s returned with certificate %s. As-found %s (%s). Due day %d." % [
		instrument_name(standard_id, true), cert["id"], sensor.format_value(zeroed["as_found"], 3),
		"in tolerance" if cert["as_found_in_tolerance"] else "OUT OF TOLERANCE", cert["due_day"]])
	if not cert["as_found_in_tolerance"]:
		var flagged: Array[Dictionary] = recall(standard_id, zeroed["as_found"], int(previous.get("day", 0)))
		var names: PackedStringArray = []
		for record: Dictionary in flagged:
			names.append("%s (day %d)" % [instrument_name(record["instrument_id"]), record["day"]])
		post_phone("RECALL: %d calibration(s) made with it are suspect%s. Redo them before the next audit." % [
			flagged.size(), (": " + ", ".join(names)) if not names.is_empty() else ""])
	oirm_changed.emit()
	return cert


## Reverse traceability (section 1.6). `standard_error` is the standard's as-found
## error. Every traceable calibration made with it from `since_day` on is
## re-judged with its as-found corrected by that error; it becomes suspect
## only if the result changes (impact threshold). A suspect calibration of
## another standard cascades to that standard's own calibrations. Returns
## the records flagged, cascade included.
func recall(standard_id: String, standard_error: float, since_day: int) -> Array[Dictionary]:
	var flagged: Array[Dictionary] = []
	var today: int = GameClock.get_day_index()
	for record: Dictionary in cal_log:
		if record.get("standard_id", "") != standard_id or record.get("suspect", false):
			continue
		if int(record["day"]) < since_day or not record.get("traceable", false):
			continue
		# The standard's error in the unit's own quantity (section 1.5).
		var instrument: DriftingSensor = get_sensor(record["instrument_id"])
		var carried: float = standard_error * (instrument.standard_sensitivity if instrument else 1.0)
		var corrected: float = float(record["as_found"]) + carried
		var rejudged: String = CalUncertainty.classify(corrected, record["mpe"], record["acceptance_limit"])
		if rejudged == record["result"]:
			# A standard still passing can carry an error that a unit with a
			# large sensitivity downstream cannot absorb: keep cascading.
			if instrument and instrument.role == "standard":
				flagged.append_array(recall(record["instrument_id"], carried, int(record["day"])))
			continue
		record["suspect"] = true
		record["suspect_result"] = rejudged
		record["recalled_by"] = standard_id
		flagged.append(record)
		if instrument and instrument.role == "standard":
			flagged.append_array(recall(record["instrument_id"], carried, int(record["day"])))
		elif is_same(_last_traceable_record(record["instrument_id"]), record):
			# A later good calibration already superseded an older suspect one.
			suspect_units[record["instrument_id"]] = today
	return flagged


## Traceability of an instrument's readings right now (section 1.7), for the
## bench and the audit. { "traceable": bool, "text": String }; text reads like
## "Steering <- PX-1 rotary table (OIRM-0001, day 3) <- OIRM" or says where it breaks.
func traceability_chain(instrument_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return { "traceable": false, "text": "%s: unknown instrument" % instrument_id }
	var today: int = GameClock.get_day_index()
	var name: String = instrument_name(instrument_id)
	if sensor.role == "standard":
		if at_oirm.has(instrument_id):
			return { "traceable": false, "text": "%s: at OIRM until day %d" % [name, at_oirm[instrument_id]] }
		var cert: Dictionary = certificates.get(instrument_id, {})
		if cert.is_empty():
			return { "traceable": false, "text": "%s: no certificate" % name }
		if sensor.is_overdue(today):
			return { "traceable": false, "text": "%s ← %s lapsed (due day %d)" % [name, cert["id"], cert["due_day"]] }
		# A maker's certificate traces through the maker's own lab to OIRM.
		var via: String = "" if str(cert.get("issuer", "OIRM")) == "OIRM" else " ← " + str(cert["issuer"])
		return { "traceable": true, "text": "%s ← %s (due day %d)%s ← OIRM" % [name, cert["id"], cert["due_day"], via] }
	var record: Dictionary = _last_traceable_record(instrument_id)
	if record.is_empty():
		return { "traceable": false, "text": "%s: no traceable calibration on record" % name }
	var standard_name: String = instrument_name(record["standard_id"])
	var link: String = "%s ← %s (%s, day %d)" % [name, standard_name, record.get("standard_certificate", "?"), record["day"]]
	if suspect_units.has(instrument_id):
		return { "traceable": false, "text": "%s: SUSPECT, recalled day %d" % [link, suspect_units[instrument_id]] }
	if _untraceable_since_cal.has(instrument_id):
		return { "traceable": false, "text": "%s: adjusted since without a traceable standard" % link }
	if sensor.is_overdue(today):
		return { "traceable": false, "text": "%s: calibration lapsed (due day %d)" % [link, sensor.cal_due_day] }
	return { "traceable": true, "text": link + " ← OIRM" }


func _last_traceable_record(instrument_id: String) -> Dictionary:
	for i: int in range(cal_log.size() - 1, -1, -1):
		var record: Dictionary = cal_log[i]
		if record["instrument_id"] == instrument_id and record.get("traceable", false):
			return record
	return {}


# --- Ore and Bram ----------------------------------------------------------------

## A mined fissure regrows `fissure_regrow_days` mornings later.
func is_fissure_available(fissure_id: StringName) -> bool:
	if not mined_fissures.has(fissure_id):
		return true
	var regrow: int = int(DataManager.get_number(ITEMS_TABLE, "crystal_ore/fissure_regrow_days", 1.0))
	return GameClock.get_day_index() >= int(mined_fissures[fissure_id]) + regrow


func mine_fissure(fissure_id: StringName) -> bool:
	if not is_fissure_available(fissure_id):
		return false
	mined_fissures[fissure_id] = GameClock.get_day_index()
	crystal_ore += 1
	ore_changed.emit(crystal_ore)
	fissures_changed.emit()
	return true


func treads_ore_cost() -> int:
	return int(DataManager.get_number(ITEMS_TABLE, "wide_treads/ore_cost", 6.0))


## Bram's trade. Returns "" on success, or the reason it can't happen.
func buy_wide_treads() -> String:
	if has_wide_treads:
		return "Already running wide treads."
	var cost: int = treads_ore_cost()
	if crystal_ore < cost:
		return "Needs %d crystal ore; carrying %d." % [cost, crystal_ore]
	crystal_ore -= cost
	has_wide_treads = true
	var mult: float = DataManager.get_number(ITEMS_TABLE, "wide_treads/usage_drift_multiplier", 0.5)
	steering.usage_drift_rate *= mult
	ore_changed.emit(crystal_ore)
	upgrades_changed.emit()
	post_phone("BRAM: Treads are on. Steering drift per meter is down %d %%. Don't till any boulders." % roundi((1.0 - mult) * 100.0))
	return ""


## Meters driven also wear the tire gauge, once it is in service.
func add_tire_usage(meters: float) -> void:
	if is_in_service(TIRE_ID):
		get_sensor(TIRE_ID).add_usage(meters)


## Tier 1 standards Bram stocks, in data order (owned ones included).
func bram_catalog() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_standard_ids():
		if (sensors[id] as DriftingSensor).tier == 1 or _is_contract_stock(id):
			ids.append(id)
	return ids


## The contract standard Bram can sell once the contract is complete (and
## keeps listing as on the colony after it is bought).
func _is_contract_stock(standard_id: String) -> bool:
	return standard_id == contract_standard_id() and contract_state in ["complete", "fulfilled"]


## Bram's price in credits, after the contract discount once it applies.
func standard_price_credits(standard_id: String) -> int:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null:
		return 0
	if _is_contract_stock(standard_id):
		return _discounted(sensor.price_credits)
	return sensor.price_credits


func _discounted(price: int) -> int:
	return price * (100 - contract_discount_pct()) / 100


## "250 CR + 2 crystal ore" for a standard's price.
func standard_price_text(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null:
		return ""
	return "%s CR + %d crystal ore" % [SP811.integer(standard_price_credits(standard_id)), sensor.price_ore]


## Why Bram can't sell this standard right now, or "" if he can.
func standard_purchase_problem(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null or sensor.role != "standard" or not (sensor.tier == 1 or _is_contract_stock(standard_id)):
		return "Bram doesn't stock that."
	if owned_standards.has(standard_id):
		return "The %s is already on the colony." % sensor.short_name
	if not tier1_unlocked:
		return "Tier 1 equipment needs a clean audit on file first."
	if credits < standard_price_credits(standard_id) or crystal_ore < sensor.price_ore:
		return "Costs %s; you have %s CR and %d crystal ore." % [
			standard_price_text(standard_id), SP811.integer(credits), crystal_ore]
	return ""


## Buys a Tier 1 standard from Bram (section 1.7). Returns "" on success, or
## the reason it can't happen. It arrives with a maker's certificate traceable
## to OIRM, valid for its first interval, and puts the units it calibrates in
## service (due one interval from today, with no calibration on record yet).
func buy_standard(standard_id: String) -> String:
	var problem: String = standard_purchase_problem(standard_id)
	if problem != "":
		return problem
	var sensor: DriftingSensor = get_sensor(standard_id)
	add_credits(-standard_price_credits(standard_id))
	crystal_ore -= sensor.price_ore
	ore_changed.emit(crystal_ore)
	var today: int = GameClock.get_day_index()
	owned_standards[standard_id] = today
	# New from the maker: adjusted against their own OIRM-traceable reference.
	var zeroed: Dictionary = sensor.zero(0.0)
	sensor.cal_interval_days = sensor.initial_interval_days if sensor.initial_interval_days > 0 \
		else int(_interval_cfg("initial_days", 5.0))
	sensor.cal_due_day = today + sensor.cal_interval_days
	sensor.last_cal_day = today
	var prefix: String = sensor.certificate_prefix if sensor.certificate_prefix != "" else "MKR"
	var issuer: String = sensor.maker if sensor.maker != "" else "the maker"
	var cert: Dictionary = _issue_certificate(standard_id, today, null, zeroed["as_left"], false, issuer, prefix)
	var units: PackedStringArray = []
	# A unit this standard takes over was already in service: it moves to the
	# new standard but keeps its due day.
	var taken: Array[String] = []
	var takes_over: Variant = DataManager.get_value(DRIFT_TABLE, "instruments/%s/takes_over" % standard_id, [])
	if typeof(takes_over) == TYPE_ARRAY:
		for unit_id: Variant in takes_over:
			var unit: DriftingSensor = get_sensor(str(unit_id))
			if unit != null and unit.role == "unit" and unit.calibrated_by != standard_id:
				var was_in_service: bool = is_in_service(str(unit_id))
				unit.calibrated_by = standard_id
				if was_in_service:
					taken.append(str(unit_id))
	for id: String in all_unit_ids():
		var unit: DriftingSensor = sensors[id]
		if unit.calibrated_by != standard_id or id in taken:
			continue
		unit.cal_due_day = today + unit.cal_interval_days
		# Put in service today: the first calibration is not interval evidence.
		unit.last_cal_day = today
		units.append(_mid_sentence(unit.short_name))
	var text: String = "BRAM: One %s, still in the crate. Certificate %s from %s, good to day %d." % [
		sensor.short_name, cert["id"], issuer, cert["due_day"]]
	if not units.is_empty():
		text += " Calibrate the %s against it before Vance's next visit." % " and the ".join(units)
	if not taken.is_empty():
		var taken_names: PackedStringArray = []
		for id: String in taken:
			taken_names.append(_mid_sentence(instrument_name(id)))
		text += " The %s now calibrates against it." % " and the ".join(taken_names)
	post_phone(text)
	if standard_id == contract_standard_id() and contract_state == "complete":
		contract_state = "fulfilled"
		credibility_changed.emit(credibility)
	upgrades_changed.emit()
	oirm_changed.emit()
	return ""


func bram_line(section: String) -> String:
	var lines: Variant = DataManager.get_value(DISPATCH_TABLE, "npcs/bram/" + section)
	if typeof(lines) != TYPE_ARRAY or (lines as Array).is_empty():
		return ""
	return str((lines as Array).pick_random())


func _on_day_started_regrow() -> void:
	fissures_changed.emit()


func _interval_cfg(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "calibration_interval/" + key, fallback)


func _schedule(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "audit_schedule/" + key, fallback)


# --- Molt & silk ----------------------------------------------------------------

## Molt only advances while the hygrometer is within MPE (green or amber),
## and, once the FM-3 puts it in service, the terrarium thermometer too
## (Ryan, 2026-11-22: "Like humidity"). Both use the true error, not the display.
func is_molt_paused() -> bool:
	return not molt_pause_causes().is_empty()


## The quantities holding the molt back, in display order: "temperature",
## "relative humidity". Empty while the molt can advance.
func molt_pause_causes() -> PackedStringArray:
	var causes: PackedStringArray = []
	if is_in_service(THERMOMETER_ID) 			and get_sensor(THERMOMETER_ID).get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE:
		causes.append("temperature")
	if hygrometer.get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE:
		causes.append("humidity")
	return causes


## "temperature and humidity out of range", or "" while the molt can advance.
func molt_pause_reason() -> String:
	var causes: PackedStringArray = molt_pause_causes()
	return "" if causes.is_empty() else " and ".join(causes) + " out of range"


func is_spool_ready() -> bool:
	return molt_stage == MoltStage.MOLTED


## The exuvia shows while molted and for EXUVIA_LINGER_DAYS after the spool is
## taken (it goes at the start of the day after that).
func is_exuvia_visible() -> bool:
	return molt_stage == MoltStage.MOLTED or GameClock.get_day_index() < exuvia_until_day


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
	exuvia_until_day = GameClock.get_day_index() + EXUVIA_LINGER_DAYS
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


# --- Credibility and contracts (Ryan, 2026-11-22) -------------------------------

func _cred_number(key: String, fallback: float) -> float:
	return DataManager.get_number(ECONOMY_TABLE, "credibility/" + key, fallback)


func _cred_bands() -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	var raw: Variant = DataManager.get_value(ECONOMY_TABLE, "credibility/bands", [])
	if typeof(raw) == TYPE_ARRAY:
		for band: Variant in raw:
			if typeof(band) == TYPE_DICTIONARY:
				bands.append(band)
	if bands.is_empty():
		bands.append({ "name": "Provisional", "min_points": 0 })
	return bands


## Starting credibility, with no contract.
func reset_credibility() -> void:
	credibility = int(_cred_number("start_points", 10.0))
	_best_band = credibility_band_index()
	contract_state = ""
	contract_run = 0


func credibility_band_index(points: int = -1) -> int:
	if points < 0:
		points = credibility
	var bands: Array[Dictionary] = _cred_bands()
	var index: int = 0
	for i: int in bands.size():
		if points >= int(bands[i].get("min_points", 0)):
			index = i
	return index


func credibility_band() -> String:
	return str(_cred_bands()[credibility_band_index()].get("name", ""))


## "TRUSTED, 40 % to ACCREDITED", or just the band at the top.
func credibility_text() -> String:
	var bands: Array[Dictionary] = _cred_bands()
	var index: int = credibility_band_index()
	var text: String = str(bands[index].get("name", "")).to_upper()
	if index + 1 < bands.size():
		var low: int = int(bands[index].get("min_points", 0))
		var high: int = int(bands[index + 1].get("min_points", 0))
		var pct: int = clampi(floori(100.0 * (credibility - low) / maxf(high - low, 1.0)), 0, 99)
		text += ", %d %% to %s" % [pct, str(bands[index + 1].get("name", "")).to_upper()]
	return text


## Moves credibility by `points` (kept between 0 and the maximum), announces a
## new best band, and offers the first contract once its band is reached.
func change_credibility(points: int) -> void:
	if points == 0:
		return
	credibility = clampi(credibility + points, 0, int(_cred_number("max_points", 100.0)))
	credibility_changed.emit(credibility)
	var index: int = credibility_band_index()
	if index > _best_band:
		_best_band = index
		post_phone("OIRM: Lab credibility raised to %s." % credibility_band().to_upper())
	if contract_state == "" and index >= _contract_offer_band_index():
		_offer_first_contract()


func _credibility_after_audit(report: Dictionary) -> void:
	if report.get("warning", false):
		change_credibility(int(_cred_number("warning_audit_points", -5.0)))
	elif report["passed"]:
		change_credibility(int(_cred_number("clean_audit_points", 10.0)))
	else:
		change_credibility(int(_cred_number("failed_audit_points", -10.0)))


## Each morning, every instrument on the colony that is overdue costs a
## little: units in service and standards here (not at OIRM), except units
## excused because their standard was away when they fell due.
func _charge_overdue_credibility(day: int) -> void:
	var count: int = 0
	for id: String in unit_ids() + standard_ids():
		if at_oirm.has(id) or _excused_until_audit(id, day):
			continue
		if (sensors[id] as DriftingSensor).is_overdue(day):
			count += 1
	change_credibility(count * int(_cred_number("overdue_points_per_instrument_day", -1.0)))


## True while a unit that fell due with its standard away at OIRM is still
## within the grace Vance gives at audit (_excused_units): until the latest
## deadline any audit would grant it, so the daily charge starts only after
## the audit that would fail it.
func _excused_until_audit(unit_id: String, day: int) -> bool:
	var sensor: DriftingSensor = sensors[unit_id]
	if sensor.role != "unit":
		return false
	var due: int = sensor.cal_due_day
	var cadence: int = maxi(int(_schedule("cadence_days", 5.0)), 1)
	for i: int in oirm_trips.size():
		var trip: Dictionary = oirm_trips[i]
		if trip["standard_id"] != sensor.calibrated_by:
			continue
		if int(trip["sent_day"]) >= due:
			continue
		if _trip_is_open(i):
			return true  # still away, so Vance still excuses it
		var back: int = int(trip["return_day"])
		if due >= back:
			continue
		# Every audit after it fell due that excuses it, as _excused_units does.
		var deadline: int = -1
		var audit: int = next_audit_day(due)
		while audit <= maxi(due + cadence, back):
			deadline = maxi(deadline, next_audit_day(maxi(audit, back)))
			audit += cadence
		if day <= deadline:
			return true
	return false


## Using an overdue standard costs more. The contract counts a run of on-time,
## traceable calibrations by the player; a late or untraceable one restarts it.
func _credibility_after_calibration(record: Dictionary) -> void:
	if record.get("standard_overdue", false):
		change_credibility(int(_cred_number("overdue_standard_used_points", -5.0)))
	if contract_state != "active" or record.get("performed_by", "") == "Manager":
		return
	var needed: int = contract_run_needed()
	var good: bool = record.get("on_time", false) and record.get("traceable", false)
	# A repeat before the unit has run half its interval since its last
	# traceable calibration neither counts nor breaks the run. (Unlike
	# interval_evidence, an untraceable adjustment in between doesn't block it.)
	var interval: int = int(record.get("previous_interval_days", 0))
	if good and int(record.get("days_in_service", 0)) < ceili(interval / 2.0):
		return
	if good:
		contract_run += 1
		if contract_run >= needed:
			contract_state = "complete"
			var standard: String = contract_standard_id()
			post_phone("OIRM CONTRACT complete: %d on-time calibrations in a row. Bram can sell you the %s for %s (%d %% off)." % [
				needed, instrument_name(standard), standard_price_text(standard), contract_discount_pct()])
			upgrades_changed.emit()
		else:
			post_phone("OIRM CONTRACT: %d of %d on-time calibrations in a row." % [contract_run, needed])
		credibility_changed.emit(credibility)
	elif contract_run > 0:
		contract_run = 0
		post_phone("OIRM CONTRACT: run restarted (%s). 0 of %d." % [
			"late calibration" if not record.get("on_time", false) else "not traceable", needed])
		credibility_changed.emit(credibility)


## The open contract objective for the phone, "" when there is none.
func contract_text() -> String:
	match contract_state:
		"active":
			var standard: String = contract_standard_id()
			return "OIRM CONTRACT: %d of %d in a row, on time, traceable\nA unit counts again once half its interval has passed\nReward: %s for %s" % [
				contract_run, contract_run_needed(),
				_model_name(standard), _contract_price_text(standard)]
		"complete":
			return "OIRM CONTRACT DONE: %s at Bram's" % _model_name(contract_standard_id())
	return ""


## The model part of a short name, e.g. "HB-700" from "HB-700 pressure controller".
func _model_name(instrument_id: String) -> String:
	return get_sensor(instrument_id).short_name.get_slice(" ", 0)


## The contract price, e.g. "800 CR + 4 crystal ore", even before it is earned.
func _contract_price_text(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	return "%s CR + %d crystal ore" % [SP811.integer(_discounted(sensor.price_credits)), sensor.price_ore]


func contract_standard_id() -> String:
	return str(DataManager.get_value(ECONOMY_TABLE, "credibility/first_contract/standard_id", ""))


func contract_run_needed() -> int:
	return maxi(int(_cred_number("first_contract/on_time_calibrations", 5.0)), 1)


func contract_discount_pct() -> int:
	return clampi(int(_cred_number("first_contract/discount_pct", 50.0)), 0, 100)


func _contract_offer_band_index() -> int:
	var band_name: String = str(DataManager.get_value(ECONOMY_TABLE, "credibility/first_contract/offer_band", ""))
	var bands: Array[Dictionary] = _cred_bands()
	for i: int in bands.size():
		if str(bands[i].get("name", "")) == band_name:
			return i
	return bands.size()  # unknown band: never offered


func _offer_first_contract() -> void:
	var standard: String = contract_standard_id()
	var sensor: DriftingSensor = get_sensor(standard)
	if sensor == null:
		return
	contract_state = "active"
	contract_run = 0
	credibility_changed.emit(credibility)
	post_phone("OIRM CONTRACT offered: make %d calibrations in a row on time and traceable, and Bram will sell you the %s for %s CR + %d crystal ore (%d %% off). Calibrating a unit again before it has run half its interval doesn't count." % [
		contract_run_needed(), instrument_name(standard), SP811.integer(_discounted(sensor.price_credits)),
		sensor.price_ore, contract_discount_pct()])


# --- Crops and Lin (income milestone) ----------------------------------------

## Crop ids in data order.
func crop_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: StringName in DataManager.get_ids(CROPS_TABLE):
		ids.append(str(id))
	return ids


func crop(crop_id: String) -> Dictionary:
	return DataManager.get_record(CROPS_TABLE, StringName(crop_id))


func current_seed() -> String:
	var ids: Array[String] = crop_ids()
	if ids.is_empty():
		return ""
	return seed_crop_id if ids.has(seed_crop_id) else ids[0]


## Switches the next planting to the following crop; returns its id.
func cycle_seed() -> String:
	var ids: Array[String] = crop_ids()
	if ids.is_empty():
		return ""
	seed_crop_id = ids[(ids.find(current_seed()) + 1) % ids.size()]
	return seed_crop_id


func seed_cost(crop_id: String) -> int:
	var pct: float = DataManager.get_number(ECONOMY_TABLE, "crops/seed_cost_pct", 0.0)
	return roundi(float(crop(crop_id).get("base_sell_credits", 0)) * pct / 100.0)


func crop_name(crop_id: String) -> String:
	return str(crop(crop_id).get("name", crop_id))


## Plants the current seed on a tilled, empty cell. Returns "" or the reason not.
func plant_crop(cell: Vector3i) -> String:
	var crop_id: String = current_seed()
	if crop_id == "":
		return "No crops in the data."
	if not tilled_cells.has(cell):
		return "Till the soil first."
	if plantings.has(cell):
		return "Something is already growing here."
	var cost: int = seed_cost(crop_id)
	if credits < cost:
		return "%s seed costs %s CR; you have %s CR." % [crop_name(crop_id), SP811.integer(cost), SP811.integer(credits)]
	add_credits(-cost)
	plantings[cell] = {
		"crop_id": crop_id,
		"planted_day": GameClock.get_day_index(),
		"days_grown": 0,
		"setpoint": float(crop(crop_id).get("soil_moisture_target", 0.0)),
		"out_of_band_days": 0,
	}
	crops_changed.emit()
	return ""


func is_crop_ready(cell: Vector3i) -> bool:
	if not plantings.has(cell):
		return false
	var planting: Dictionary = plantings[cell]
	return int(planting["days_grown"]) >= int(crop(planting["crop_id"]).get("growth_days", 1))


## The soil's true volumetric water content (fraction): irrigation holds the
## probe's reading at the set point, so the soil sits at set point minus the
## probe's error.
func soil_moisture(cell: Vector3i) -> float:
	var planting: Dictionary = plantings.get(cell, {})
	if planting.is_empty():
		return 0.0
	var probe: DriftingSensor = get_sensor(SOIL_PROBE_ID)
	var error_fraction: float = probe.error / 100.0 if probe != null else 0.0
	return clampf(float(planting["setpoint"]) - error_fraction, 0.0, 1.0)


func is_soil_in_band(cell: Vector3i) -> bool:
	var planting: Dictionary = plantings.get(cell, {})
	if planting.is_empty():
		return false
	var spec: Dictionary = crop(planting["crop_id"])
	var target: float = float(spec.get("soil_moisture_target", 0.0))
	return absf(soil_moisture(cell) - target) <= float(spec.get("tolerance_band", 0.0))


## Each morning: crops still growing note a day out of their moisture band,
## then grow one day.
func _grow_crops() -> void:
	if plantings.is_empty():
		return
	for cell: Variant in plantings:
		if is_crop_ready(cell):
			continue
		var planting: Dictionary = plantings[cell]
		if not is_soil_in_band(cell):
			planting["out_of_band_days"] = int(planting["out_of_band_days"]) + 1
		planting["days_grown"] = int(planting["days_grown"]) + 1
	crops_changed.emit()


## Moves a cell's irrigation set point by `steps` × 1 %. Returns the new set
## point, or -1.0 with nothing planted.
func adjust_setpoint(cell: Vector3i, steps: int) -> float:
	if not plantings.has(cell):
		return -1.0
	var planting: Dictionary = plantings[cell]
	planting["setpoint"] = clampf(snappedf(float(planting["setpoint"]) + steps * SETPOINT_STEP, SETPOINT_STEP), 0.0, 1.0)
	crops_changed.emit()
	return planting["setpoint"]


## Harvests a ready crop into the bin. Returns the bin entry, or {} if not ready.
func harvest_crop(cell: Vector3i) -> Dictionary:
	if not is_crop_ready(cell):
		return {}
	var planting: Dictionary = plantings[cell]
	var entry: Dictionary = {
		"crop_id": planting["crop_id"],
		"in_spec": int(planting["out_of_band_days"]) == 0,
		"out_of_band_days": int(planting["out_of_band_days"]),
	}
	plantings.erase(cell)
	harvest_bin.append(entry)
	crops_changed.emit()
	return entry


## What Lin pays for one bin entry: base price in spec, less the crop's
## out-of-spec penalty if its soil left the band on any growing day.
func crop_sale_price(entry: Dictionary) -> int:
	var spec: Dictionary = crop(entry.get("crop_id", ""))
	var base: int = int(spec.get("base_sell_credits", 0))
	if entry.get("in_spec", false):
		return base
	return roundi(base * (1.0 - float(spec.get("out_of_spec_penalty_pct", 0)) / 100.0))


func harvest_bin_value() -> int:
	var total: int = 0
	for entry: Dictionary in harvest_bin:
		total += crop_sale_price(entry)
	return total


## Lin buys the whole bin. Returns the credits paid (0 if the bin was empty).
func sell_harvest_to_lin() -> int:
	if harvest_bin.is_empty():
		return 0
	var total: int = harvest_bin_value()
	var count: int = harvest_bin.size()
	var off_spec: int = 0
	for entry: Dictionary in harvest_bin:
		if not entry.get("in_spec", false):
			off_spec += 1
	harvest_bin.clear()
	add_credits(total)
	crops_changed.emit()
	var note: String = ("" if off_spec == 0
		else " %d off spec, paid at the reduced price." % off_spec)
	post_phone("LIN: Bought %d crops for %s CR.%s" % [count, SP811.integer(total), note])
	return total


## One line on the crop in `cell`, for the phone.
func crop_status_text(cell: Vector3i) -> String:
	var planting: Dictionary = plantings.get(cell, {})
	if planting.is_empty():
		return ""
	var spec: Dictionary = crop(planting["crop_id"])
	var stage: String = ("ready to harvest" if is_crop_ready(cell)
		else "day %d of %d" % [int(planting["days_grown"]), int(spec.get("growth_days", 1))])
	return "%s, %s. Irrigation set point %s %%, target %s %%" % [
		crop_name(planting["crop_id"]), stage,
		SP811.number(float(planting["setpoint"]) * 100.0, 0),
		SP811.number(float(spec.get("soil_moisture_target", 0.0)) * 100.0, 0)]
