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

enum MoltStage { ACTIVE, PRE_MOLT, MOLTED }

const STEERING_ID: String = "rover_steering_encoder"
const HYGROMETER_ID: String = "hygrometer"
const SPECIES_TABLE: StringName = &"tarantula_species"
const ITEMS_TABLE: StringName = &"items"
const ECONOMY_TABLE: StringName = &"economy"
const DRIFT_TABLE: StringName = &"sensor_drift_config"
const DISPATCH_TABLE: StringName = &"dialogue_dispatches"
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
## standard_id -> the audit day it comes back on the drop pod.
var at_oirm: Dictionary = {}
## Unit id -> day a recall made its calibration suspect. A traceable
## recalibration clears it; Vance fines what is left at the audit.
var suspect_units: Dictionary = {}
## Audits in a row with no violations (a grace warning breaks the streak).
var clean_audit_streak: int = 0
## Tier 1 equipment gate: the first audit with zero violations (Q19).
var tier1_unlocked: bool = false
var _next_certificate_number: int = 1

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
	for key: Variant in table:
		var id: String = str(key)
		if id.begins_with("_"):
			continue
		var sensor: DriftingSensor = DriftingSensor.from_config(id)
		sensor.max_error = sensor.mpe * MAX_ERROR_MPE_MULTIPLE
		sensor.cal_interval_days = sensor.initial_interval_days if sensor.initial_interval_days > 0 else initial_interval
		sensor.cal_due_day = sensor.cal_interval_days
		sensors[id] = sensor
	steering = sensors.get(STEERING_ID)
	hygrometer = sensors.get(HYGROMETER_ID)
	_issue_founding_certificates()
	if steering == null or hygrometer == null:
		push_error("GameState: %s needs %s and %s." % [DRIFT_TABLE, STEERING_ID, HYGROMETER_ID])


func get_sensor(instrument_id: String) -> DriftingSensor:
	return sensors.get(instrument_id)


## Ids of the instruments Vance audits and the bench calibrates, in data order.
func unit_ids() -> Array[String]:
	return _ids_with_role("unit")


## Ids of the reference standards, in data order.
func standard_ids() -> Array[String]:
	return _ids_with_role("standard")


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
			"reason": "%s is at OIRM until the day %d drop pod." % [
				instrument_name(budget["standard_id"], true), at_oirm[budget["standard_id"]]],
		}
	var standard: DriftingSensor = get_sensor(budget["standard_id"]) if not budget.is_empty() else null
	var today: int = GameClock.get_day_index()
	var on_time: bool = not sensor.is_overdue(today)
	# Without a standard the unit is zeroed against its own idea of zero, which
	# still carries the offset from its last bench calibration: the as-found is
	# the observed error and a bad standard stays hidden (Ryan, 2026-11-22).
	var zeroed: Dictionary = sensor.zero(standard.error if standard else sensor.reference_offset)
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
	var report: Dictionary = AuditEngine.evaluate(day, audited, offence_counts, since, fineable_suspects)

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
	if report.get("warning", false):
		post_phone("MANAGER: Caught %s before Vance got in and recalibrated. One-time favor. Don't make it a habit." % report["waived_names"])
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
	audit_log.append(report)
	audit_completed.emit(report)


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
			names.append(instrument_name(line["instrument_id"]).to_lower())
	report["total_fine"] = 0
	report["warning"] = true
	report["waived_names"] = " and the ".join(names).insert(0, "the ")


# --- OIRM, certificates, recall (milestone 2) -------------------------------------

## Tier 0 standards start with a certificate from the colony's founding stock
## (section 1.7 [ASSUMPTION]): issued day 0, due at the end of the first interval.
func _issue_founding_certificates() -> void:
	certificates.clear()
	certificate_log.clear()
	at_oirm.clear()
	suspect_units.clear()
	_next_certificate_number = 1
	for id: String in standard_ids():
		sensors[id].last_cal_day = 0
		_issue_certificate(id, 0, null, null, true)


## Records a new OIRM certificate for `standard_id` from its current due day.
## as_found / as_left are null on a founding certificate (no measurement on file).
func _issue_certificate(standard_id: String, day: int, as_found: Variant, as_left: Variant, founding: bool) -> Dictionary:
	var sensor: DriftingSensor = sensors[standard_id]
	var cert: Dictionary = {
		"id": "OIRM-%04d" % _next_certificate_number,
		"standard_id": standard_id,
		"issuer": "OIRM",
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


## Puts a standard on the drop pod to OIRM. Needs the pod on the ground and
## the fee. Returns { "ok": bool, "reason": String, "return_day": int }.
func send_to_oirm(standard_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null or sensor.role != "standard":
		return { "ok": false, "reason": "Only reference standards go to OIRM." }
	if at_oirm.has(standard_id):
		return { "ok": false, "reason": "Already at OIRM until the day %d drop pod." % at_oirm[standard_id] }
	if not drop_pod_present:
		return { "ok": false, "reason": "No drop pod on the pad. It lands on audit mornings." }
	var fee: int = oirm_fee()
	if credits < fee:
		return { "ok": false, "reason": "OIRM charges %s CR; balance %s CR." % [SP811.integer(fee), SP811.integer(credits)] }
	add_credits(-fee)
	var return_day: int = next_audit_day(GameClock.get_day_index())
	at_oirm[standard_id] = return_day
	post_phone("OIRM: %s loaded on the drop pod. Fee %s CR. Back on the day %d pod; nothing can be calibrated against it until then." % [
		instrument_name(standard_id, true), SP811.integer(fee), return_day])
	oirm_changed.emit()
	return { "ok": true, "reason": "", "return_day": return_day }


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
		var corrected: float = float(record["as_found"]) + standard_error
		var rejudged: String = CalUncertainty.classify(corrected, record["mpe"], record["acceptance_limit"])
		if rejudged == record["result"]:
			continue
		record["suspect"] = true
		record["suspect_result"] = rejudged
		record["recalled_by"] = standard_id
		flagged.append(record)
		var instrument: DriftingSensor = get_sensor(record["instrument_id"])
		if instrument and instrument.role == "standard":
			flagged.append_array(recall(record["instrument_id"], standard_error, int(record["day"])))
		elif _last_traceable_record(record["instrument_id"]) == record:
			# A later good calibration already superseded an older suspect one.
			suspect_units[record["instrument_id"]] = today
	return flagged


## Traceability of an instrument's readings right now (section 1.7), for the
## bench and the audit. { "traceable": bool, "text": String }; text reads like
## "Steering encoder <- Rotary table (OIRM-0001, day 3) <- OIRM" or says where it breaks.
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
			return { "traceable": false, "text": "%s: no OIRM certificate" % name }
		if sensor.is_overdue(today):
			return { "traceable": false, "text": "%s ← %s lapsed (due day %d)" % [name, cert["id"], cert["due_day"]] }
		return { "traceable": true, "text": "%s ← %s (due day %d) ← OIRM" % [name, cert["id"], cert["due_day"]] }
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

## Molt only advances while the hygrometer is within MPE (green or amber).
func is_molt_paused() -> bool:
	return hygrometer.get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE


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
