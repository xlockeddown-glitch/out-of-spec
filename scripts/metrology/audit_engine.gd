class_name AuditEngine
extends RefCounted
## MegaCorp compliance audit (Inspector Vance + AUD-1T). Pure functions: give
## it the instruments and history, get back a report. GameState applies it.
##
## Rules (data/sensor_drift_config.json):
##   - Each instrument is checked as found at audit time against its MPE.
##   - In band or guard band = pass (guard band gets an advisory, no fine).
##   - Overdue (audit day past the instrument's cal due day, including never
##     calibrated) = overdue_credits, whatever the reading.
##   - Out of tolerance = base_credits + credits_per_excess_ratio * (|error| / MPE - 1).
##   - Either one is a violation: add
##     min(repeat_surcharge_credits * prior_offences, max_repeat_surcharge_credits)
##     once, cap the instrument's total at max_fine_credits, round to whole credits.
##   - Suspect (a recall flagged the unit's calibration and it was not redone)
##     = suspect_cal_credits.
##   - Excused (overdue only because the standard it needs was at OIRM when it
##     fell due) = not a violation at that audit. Out of tolerance still is.
##   - AUD-1T tire check (Ryan, 2026-11-22): the rover tires are filled to
##     what the tire gauge reads, so they sit at minus its true error. Past
##     aud1t_tire_limit_kpa = aud1t_tire_credits, a flat petty fine on top of
##     the gauge's own line. No repeat surcharge.
##   - A robot's interlock overridden since the last audit = interlock_override_credits
##     each, flat, on top of the bad sensor's own line. No repeat surcharge.
##   - Repeat offences reset after a fully clean audit (GameState).
##   - Calibration records since the last audit are listed on the report
##     (traceability). They don't change the fine; Week 4 Vance may care.

const CONFIG_TABLE: StringName = &"sensor_drift_config"


## sensors: instrument_id -> DriftingSensor
## prior_offences: instrument_id -> int (earlier audits that fined it)
## cal_records: calibration records since the last audit
## suspect_ids: instrument_id -> recall day, for calibrations a recall made
## suspect that have not been redone
## excused_ids: instrument_id -> true, units whose standard was at OIRM when they fell due
static func evaluate(day: int, sensors: Dictionary, prior_offences: Dictionary, cal_records: Array[Dictionary],
		suspect_ids: Dictionary = {}, excused_ids: Dictionary = {}) -> Dictionary:
	var lines: Array[Dictionary] = []
	var total_fine: int = 0
	var any_violation: bool = false
	for id_key: Variant in sensors:
		var instrument_id: String = id_key
		var sensor: DriftingSensor = sensors[instrument_id]
		# A standard's error only shows at OIRM (section 1.6): Vance checks its
		# certificate is in date, not its reading.
		var is_standard: bool = sensor.role == "standard"
		var ratio: float = 0.0 if is_standard else sensor.get_error_ratio()
		var band: int = DriftingSensor.Band.IN_BAND if is_standard else sensor.get_band()
		var repeats: int = int(prior_offences.get(instrument_id, 0))
		var out_of_tolerance: bool = band == DriftingSensor.Band.OUT_OF_TOLERANCE
		var overdue: bool = sensor.is_overdue(day)
		var excused: bool = overdue and excused_ids.has(instrument_id)
		var suspect: bool = suspect_ids.has(instrument_id)
		var violation: bool = out_of_tolerance or (overdue and not excused) or suspect
		any_violation = any_violation or violation
		var fine: int = fine_for(ratio, out_of_tolerance, overdue and not excused, repeats, suspect) if violation else 0
		total_fine += fine
		lines.append({
			"instrument_id": instrument_id,
			"standard": is_standard,
			# A standard's true error stays hidden until OIRM measures it.
			"as_found": null if is_standard else sensor.error,
			"unit": sensor.error_unit,
			"mpe": sensor.mpe,
			"ratio": ratio,
			"band": band,
			"out_of_tolerance": out_of_tolerance,
			"overdue": overdue,
			"excused": excused,
			"suspect": suspect,
			"due_day": sensor.cal_due_day,
			"violation": violation,
			"prior_offences": repeats,
			"fine": fine,
		})
	return {
		"day": day,
		"lines": lines,
		"total_fine": total_fine,
		# Pass/fail follows the violations, not the fine: a tuned-down fine that
		# rounds to 0 CR must not turn a violation into a pass.
		"passed": not any_violation,
		"cal_records": cal_records.size(),
		"cal_fails_found": cal_records.filter(func(r: Dictionary) -> bool: return not r.get("as_found_in_tolerance", true)).size(),
		"suspect_units": suspect_ids.size(),
	}


## Fine in credits for one instrument with at least one violation.
static func fine_for(error_ratio: float, out_of_tolerance: bool, overdue: bool, prior_offences: int,
		suspect: bool = false) -> int:
	var fine: float = 0.0
	if suspect:
		fine += _cfg("suspect_cal_credits", 75.0)
	if out_of_tolerance:
		fine += _cfg("base_credits", 50.0) + _cfg("credits_per_excess_ratio", 100.0) * maxf(error_ratio - 1.0, 0.0)
	if overdue:
		fine += _cfg("overdue_credits", 50.0)
	fine += minf(_cfg("repeat_surcharge_credits", 25.0) * prior_offences, _cfg("max_repeat_surcharge_credits", 100.0))
	return roundi(minf(fine, _cfg("max_fine_credits", 350.0)))


## AUD-1T reports tire offsets to 0.1 kPa [PLACEHOLDER: game choice].
const TIRE_REPORT_KPA: float = 0.1


## AUD-1T's tire measurement for a tire gauge whose true error is
## gauge_error_kpa. Returns offset_kpa (tires minus set point, as AUD-1T
## reports it to TIRE_REPORT_KPA), limit_kpa, violation and fine. AUD-1T
## judges the value it reports, so the phone line and the fine always agree.
static func tire_check(gauge_error_kpa: float) -> Dictionary:
	# Offset and limit both become whole report steps, rounded half away from
	# zero by magnitude, and limit_kpa is returned rounded, so the phone shows
	# exactly the two numbers AUD-1T compares.
	var steps: int = _report_steps(absf(gauge_error_kpa))
	var limit_steps: int = _report_steps(_cfg("aud1t_tire_limit_kpa", 6.9))
	var violation: bool = steps > limit_steps
	var offset: float = steps * TIRE_REPORT_KPA * (1.0 if gauge_error_kpa < 0.0 else -1.0)
	return {
		"offset_kpa": offset,
		"limit_kpa": limit_steps * TIRE_REPORT_KPA,
		"violation": violation,
		"fine": roundi(_cfg("aud1t_tire_credits", 20.0)) if violation else 0,
	}


## The fine for one robot's overridden interlock.
static func interlock_fine() -> int:
	return roundi(_cfg("interlock_override_credits", 100.0))


## A nonnegative kPa value in whole TIRE_REPORT_KPA steps. The 1e-9 nudge
## keeps decimal half steps such as 0.15 / 0.1 = 1.4999999999999998 rounding up.
static func _report_steps(kpa: float) -> int:
	return roundi(kpa / TIRE_REPORT_KPA + 1e-9)


static func _cfg(key: String, fallback: float) -> float:
	return DataManager.get_number(CONFIG_TABLE, "compliance_fine/" + key, fallback)
