class_name AuditEngine
extends RefCounted
## MegaCorp compliance audit (Inspector Vance + AUD-1T). Pure functions: give
## it the instruments and history, get back a report. GameState applies it.
##
## Rules (data/sensor_drift_config.json):
##   - Each instrument is checked as found at audit time against its MPE.
##   - In band or guard band = pass (guard band gets an advisory, no fine).
##   - Out of tolerance = fined, per instrument:
##       base_credits
##     + credits_per_excess_ratio * (|error| / MPE - 1)
##     + min(repeat_surcharge_credits * prior_offences, max_repeat_surcharge_credits)
##     capped at max_fine_credits, rounded to whole credits.
##   - Calibration records since the last audit are listed on the report
##     (traceability). They don't change the fine; Week 4 Vance may care.

const CONFIG_TABLE: StringName = &"sensor_drift_config"


## sensors: instrument_id -> DriftingSensor
## prior_offences: instrument_id -> int (earlier audits that fined it)
## cal_records: calibration records since the last audit
static func evaluate(day: int, sensors: Dictionary, prior_offences: Dictionary, cal_records: Array[Dictionary]) -> Dictionary:
	var lines: Array[Dictionary] = []
	var total_fine: int = 0
	var any_out_of_tolerance: bool = false
	for id_key: Variant in sensors:
		var instrument_id: String = id_key
		var sensor: DriftingSensor = sensors[instrument_id]
		var ratio: float = sensor.get_error_ratio()
		var band: int = sensor.get_band()
		var repeats: int = int(prior_offences.get(instrument_id, 0))
		var out_of_tolerance: bool = band == DriftingSensor.Band.OUT_OF_TOLERANCE
		any_out_of_tolerance = any_out_of_tolerance or out_of_tolerance
		var fine: int = fine_for(ratio, repeats) if out_of_tolerance else 0
		total_fine += fine
		lines.append({
			"instrument_id": instrument_id,
			"as_found": sensor.error,
			"unit": sensor.error_unit,
			"mpe": sensor.mpe,
			"ratio": ratio,
			"band": band,
			"out_of_tolerance": out_of_tolerance,
			"prior_offences": repeats,
			"fine": fine,
		})
	return {
		"day": day,
		"lines": lines,
		"total_fine": total_fine,
		# Pass/fail follows the band, not the fine: a tuned-down fine that rounds
		# to 0 CR must not turn an out-of-tolerance instrument into a pass.
		"passed": not any_out_of_tolerance,
		"cal_records": cal_records.size(),
		"cal_fails_found": cal_records.filter(func(r: Dictionary) -> bool: return not r.get("as_found_in_tolerance", true)).size(),
	}


## Fine in credits for one out-of-tolerance instrument.
static func fine_for(error_ratio: float, prior_offences: int) -> int:
	var base: float = _cfg("base_credits", 50.0)
	var per_excess: float = _cfg("credits_per_excess_ratio", 100.0)
	var surcharge: float = minf(_cfg("repeat_surcharge_credits", 25.0) * prior_offences,
		_cfg("max_repeat_surcharge_credits", 100.0))
	var fine: float = base + per_excess * maxf(error_ratio - 1.0, 0.0) + surcharge
	return roundi(minf(fine, _cfg("max_fine_credits", 350.0)))


static func _cfg(key: String, fallback: float) -> float:
	return DataManager.get_number(CONFIG_TABLE, "compliance_fine/" + key, fallback)
