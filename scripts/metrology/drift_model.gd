class_name DriftModel
extends RefCounted
## Error state of one instrument, driven by two sources:
##   - time:  `daily_drift_rate` (units per in-game day), fed by GameClock
##   - usage: `usage_drift_rate` (units per usage unit, e.g. per metre driven)
## Both push the error in the same direction (`_sign`). Zeroing records the
## as-found error, resets to 0, and re-rolls the direction: the root cause is
## never fixed, so it comes back, maybe the other way.
##
## Status uses the guard band from sensor_drift_config.json:
##   |error| / MPE <= acceptance_ratio -> IN_TOLERANCE
##   <= 1.0                            -> GUARD_BAND
##   > 1.0                             -> OUT_OF_SPEC

signal error_changed(error: float, status: int)
signal zeroed(as_found: float)

enum Status { IN_TOLERANCE, GUARD_BAND, OUT_OF_SPEC }

const CONFIG_TABLE: StringName = &"sensor_drift_config"

var instrument_id: String = ""
var error_unit: String = ""
## Maximum permissible error, in `error_unit`.
var mpe: float = 1.0
var acceptance_ratio: float = 0.8
var daily_drift_rate: float = 0.0
var usage_drift_rate: float = 0.0
## Hard clamp on |error| so a neglected instrument stays playable.
var max_error: float = INF

var error: float = 0.0:
	set(value):
		var clamped: float = clampf(value, -max_error, max_error)
		if clamped == error:
			return
		error = clamped
		error_changed.emit(error, get_status())

var _sign: float = 1.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_sign = _random_sign()


## Builds a model from instruments/<id> and guardband/green in the config.
## Fields missing from the data keep their defaults (with a warning).
static func from_config(p_instrument_id: String, p_max_error: float = INF) -> DriftModel:
	var model := DriftModel.new()
	model.instrument_id = p_instrument_id
	model.max_error = p_max_error
	var base: String = "instruments/%s" % p_instrument_id
	if DataManager.get_value(CONFIG_TABLE, base) == null:
		push_warning("DriftModel: instrument '%s' not in %s; using defaults." % [p_instrument_id, CONFIG_TABLE])
		return model
	model.error_unit = str(DataManager.get_value(CONFIG_TABLE, base + "/error_unit", ""))
	model.mpe = DataManager.get_number(CONFIG_TABLE, base + "/max_permissible_error", model.mpe)
	model.daily_drift_rate = DataManager.get_number(CONFIG_TABLE, base + "/daily_drift_rate", 0.0)
	# usage_drift_rate is optional; instruments without usage wear omit it.
	if DataManager.get_value(CONFIG_TABLE, base + "/usage_drift_rate") != null:
		model.usage_drift_rate = DataManager.get_number(CONFIG_TABLE, base + "/usage_drift_rate", 0.0)
	model.acceptance_ratio = DataManager.get_number(
		CONFIG_TABLE, "guardband/green/max_error_ratio_inclusive", model.acceptance_ratio)
	return model


func advance_days(days: float) -> void:
	if days > 0.0 and daily_drift_rate > 0.0:
		error += _sign * daily_drift_rate * days


func add_usage(amount: float) -> void:
	if amount > 0.0 and usage_drift_rate > 0.0:
		error += _sign * usage_drift_rate * amount


## Resets to zero and returns the as-found error.
func zero() -> float:
	var as_found: float = error
	_sign = _random_sign()
	error = 0.0
	zeroed.emit(as_found)
	return as_found


func get_error_ratio() -> float:
	return absf(error) / mpe if mpe > 0.0 else INF


func get_status() -> Status:
	var ratio: float = get_error_ratio()
	if ratio <= acceptance_ratio:
		return Status.IN_TOLERANCE
	if ratio <= 1.0:
		return Status.GUARD_BAND
	return Status.OUT_OF_SPEC


func _random_sign() -> float:
	return -1.0 if _rng.randf() < 0.5 else 1.0
