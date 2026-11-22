extends RefCounted
## Headless checks of the playtest loop in GameState: calibration interval
## adjustment, the one-time audit warning then the fine, and the relay lag
## from a slotted spool. Every expected number is read from the data tables
## (or the sensor's own MPE), so retuning the placeholders never breaks these.
##
## Each test builds its own GameState that is never added to the tree, so
## _ready() (dispatch deck, clock signals) doesn't run and the live autoload
## is never touched. GameClock.elapsed_days is saved and restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DRIFT: StringName = &"sensor_drift_config"


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.steering = DriftingSensor.from_config(gs.STEERING_ID)
	gs.hygrometer = DriftingSensor.from_config(gs.HYGROMETER_ID)
	var initial: int = int(_cfg("initial_days"))
	for sensor: DriftingSensor in [gs.steering, gs.hygrometer]:
		sensor.cal_interval_days = initial
		sensor.cal_due_day = initial
	return gs


func _cfg(key: String) -> float:
	return DataManager.get_number(DRIFT, "calibration_interval/" + key, NAN)


## Puts the clock on the morning of `day` (day 1 starts at elapsed 0).
func _set_day(day: int) -> void:
	GameClock.elapsed_days = float(day - 1)


func test_interval_config_is_present() -> String:
	for key: String in ["initial_days", "min_days", "max_days", "lengthen_days", "shorten_days"]:
		if is_nan(_cfg(key)):
			return "sensor_drift_config is missing calibration_interval/%s." % key
	return ""


func test_failed_as_found_shortens_interval() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var sensor: DriftingSensor = gs.steering
	var initial: int = sensor.cal_interval_days
	_set_day(sensor.cal_due_day)
	sensor.error = sensor.mpe * 2.0  # well outside the MPE
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)
	var expected: int = maxi(int(_cfg("min_days")), initial - int(_cfg("shorten_days")))
	var due_expected: int = GameClock.get_day_index() + expected
	GameClock.elapsed_days = saved
	gs.free()
	if record.get("as_found_in_tolerance", true):
		return "An as-found of 2 × MPE must be recorded out of tolerance: %s" % record
	if record["interval_days"] != expected or record["due_day"] != due_expected:
		return "A failed as-found must shorten %d d to %d d (due day %d), got %d d (due day %d)." % [
			initial, expected, due_expected, record["interval_days"], record["due_day"]]
	return ""


func test_shortening_stops_at_min_days() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var sensor: DriftingSensor = gs.steering
	var min_days: int = int(_cfg("min_days"))
	var day: int = 1
	var record: Dictionary = {}
	# Enough failures to reach the floor from the initial interval and one more.
	var rounds: int = 2 + ceili(float(sensor.cal_interval_days - min_days) / maxf(1.0, _cfg("shorten_days")))
	for i: int in rounds:
		day = sensor.cal_due_day
		_set_day(day)
		sensor.error = sensor.mpe * 2.0
		record = gs.calibrate(gs.STEERING_ID)
	GameClock.elapsed_days = saved
	gs.free()
	if record["interval_days"] != min_days:
		return "Repeated failures must stop at min_days (%d d), got %d d." % [min_days, record["interval_days"]]
	return ""


func test_on_time_pass_lengthens_interval() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var sensor: DriftingSensor = gs.steering
	var initial: int = sensor.cal_interval_days
	_set_day(sensor.cal_due_day)  # due today is still on time
	sensor.error = 0.0
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)
	var expected: int = mini(int(_cfg("max_days")), initial + int(_cfg("lengthen_days")))
	GameClock.elapsed_days = saved
	gs.free()
	if not record["on_time"] or not record["as_found_in_tolerance"]:
		return "A zero-error calibration on its due day must be an on-time pass: %s" % record
	if record["interval_days"] != expected:
		return "An on-time pass must lengthen %d d to %d d, got %d d." % [initial, expected, record["interval_days"]]
	return ""


func test_same_day_recalibration_does_not_lengthen() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var sensor: DriftingSensor = gs.steering
	_set_day(sensor.cal_due_day)
	sensor.error = 0.0
	var first: Dictionary = gs.calibrate(gs.STEERING_ID)
	sensor.error = 0.0
	var second: Dictionary = gs.calibrate(gs.STEERING_ID)
	GameClock.elapsed_days = saved
	gs.free()
	if second["interval_evidence"] or second["interval_days"] != first["interval_days"]:
		return "Re-calibrating the same day must keep %d d, got %d d." % [first["interval_days"], second["interval_days"]]
	return ""


func test_late_pass_keeps_interval() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var sensor: DriftingSensor = gs.steering
	var initial: int = sensor.cal_interval_days
	_set_day(sensor.cal_due_day + 1)  # one day overdue
	sensor.error = 0.0
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)
	GameClock.elapsed_days = saved
	gs.free()
	if record["on_time"] or record["interval_days"] != initial:
		return "A late pass must keep %d d, got on_time=%s, %d d." % [initial, record["on_time"], record["interval_days"]]
	return ""


func test_first_failed_audit_is_a_warning_then_fines() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = int(DataManager.get_number(DRIFT, "audit_schedule/cadence_days", NAN))
	if cadence <= 0:
		gs.free()
		return "sensor_drift_config is missing a positive audit_schedule/cadence_days."
	gs.hygrometer.cal_due_day = 4 * cadence  # keep the hygrometer out of it
	gs.credits = int(DataManager.get_number(&"economy", "starting_credits", 0.0))

	# First audit: steering out of tolerance -> one-time warning, no fine.
	_set_day(cadence)
	gs.steering.error = gs.steering.mpe * 2.0
	var start_credits: int = gs.credits
	gs._run_audit(cadence)
	var first: Dictionary = gs.audit_log[-1]
	var manager_cal: Dictionary = gs.last_cal_records.get(gs.STEERING_ID, {})
	var first_credits: int = gs.credits

	# Second audit: out of tolerance again -> fined, credits drop by the total.
	_set_day(2 * cadence)
	gs.steering.error = gs.steering.mpe * 2.0
	gs.steering.cal_due_day = 4 * cadence  # out of tolerance, not overdue
	gs._run_audit(2 * cadence)
	var second: Dictionary = gs.audit_log[-1]
	var expected_fine: int = 0
	for line: Dictionary in second["lines"]:
		if line["violation"]:
			expected_fine += AuditEngine.fine_for(line["ratio"], line["out_of_tolerance"], line["overdue"],
				int(line["prior_offences"]))
	var second_credits: int = gs.credits
	GameClock.elapsed_days = saved
	gs.free()

	if first["passed"] or not first.get("warning", false) or first["total_fine"] != 0:
		return "The first failed audit must be a fine-free warning: %s" % first
	if first_credits != start_credits:
		return "The warning must not change credits (%d -> %d)." % [start_credits, first_credits]
	if manager_cal.get("performed_by", "") != "Manager":
		return "The manager must calibrate the violating instrument before Vance inspects: %s" % manager_cal
	if second.get("warning", false) or second["total_fine"] <= 0:
		return "The second failed audit must be fined: %s" % second
	if second_credits != first_credits - int(second["total_fine"]):
		return "Credits must drop by the %d CR fine (%d -> %d)." % [second["total_fine"], first_credits, second_credits]
	return ""


func test_relay_lag_follows_spool_and_species_data() -> String:
	var gs: GameStateScript = _make_state()
	var no_relay: float = gs.get_relay_lag_multiplier()
	if no_relay != 1.0:
		gs.free()
		return "An empty relay must leave uplink lag unchanged, got × %s." % no_relay
	var spool_pct: float = DataManager.get_number(&"items", "optical_silk_spool/relay_lag_reduction_pct", NAN)
	if is_nan(spool_pct):
		gs.free()
		return "items is missing optical_silk_spool/relay_lag_reduction_pct."
	var species: Array[Dictionary] = DataManager.get_records(gs.SPECIES_TABLE)
	if species.is_empty():
		gs.free()
		return "tarantula_species has no records."
	for record: Dictionary in species:
		var id: StringName = StringName(str(record.get("id", "")))
		gs.relay_slotted = false
		gs.dome_species_id = id
		gs.molt_stage = GameStateScript.MoltStage.MOLTED
		if not gs.collect_spool():
			gs.free()
			return "A molted enclosure must give a spool (%s)." % id
		gs.dome_species_id = &""  # the spool keeps the species that spun it
		if not gs.slot_spool_into_relay():
			gs.free()
			return "A held spool must slot into an empty relay (%s)." % id
		var raw: Variant = record.get("lag_reduction_pct")
		var species_pct: float = float(raw) if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT else 0.0
		var expected: float = clampf((1.0 - spool_pct / 100.0) * (1.0 - species_pct / 100.0), 0.0, 1.0)
		var got: float = gs.get_relay_lag_multiplier()
		if gs.slotted_spool_species != id or not is_equal_approx(got, expected):
			var actual_species: StringName = gs.slotted_spool_species
			gs.free()
			return "%s spool: expected species %s and lag × %s, got %s and × %s." % [id, id, expected, actual_species, got]
	gs.free()
	return ""
