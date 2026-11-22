class_name DriftingSensor
extends RefCounted
## Error state of one instrument, driven by two sources:
##   - time:  `daily_drift_rate` (units per in-game day), fed by GameState/GameClock
##   - usage: `usage_drift_rate` (units per usage unit, e.g. per metre driven)
## Both push the error in the same direction (`_sign`). Zeroing returns the
## as-found error, leaves a small as-left residual, and re-rolls the direction:
## the root cause is never fixed, so it comes back, maybe the other way.
##
## A reference standard is a DriftingSensor too (`role` "standard"). Zeroing
## against a standard compares to a reference that is itself off by its own
## error, so that error is carried into the unit and stays hidden
## (docs/design/equipment_skills_robots.md section 1.5).
##
## Band uses the guard band from sensor_drift_config.json:
##   |error| / MPE <= acceptance_ratio -> IN_BAND
##   <= 1.0                            -> GUARDBAND
##   > 1.0                             -> OUT_OF_TOLERANCE
##
## Instances live in the GameState autoload so they survive scene swaps.

signal error_changed(error: float, band: int)
signal zeroed(as_found: float, as_left: float)

enum Band { IN_BAND, GUARDBAND, OUT_OF_TOLERANCE }

const CONFIG_TABLE: StringName = &"sensor_drift_config"

var instrument_id: String = ""
var error_unit: String = ""
## "unit" (audited, calibrated at the bench) or "standard" (a Tier 0 reference).
var role: String = "unit"
var display_name: String = ""
var short_name: String = ""
## One digit of the reading, in `error_unit` (0 = not set).
var resolution: float = 0.0
## Id of the standard this unit is calibrated against ("" = none).
var calibrated_by: String = ""
## Game minutes one bench calibration takes.
var bench_minutes: float = 0.0
## Standards only: confidence the spec (`mpe`) is stated at, in percent;
## <= 0 means none stated, so the spec is treated as rectangular.
var spec_confidence_pct: float = 0.0
## Standards only: expanded uncertainty on the standard's certificate, and its k.
var certificate_uncertainty: float = 0.0
var certificate_k: float = 2.0
## Starting calibration interval in days (0 = the global initial interval).
var initial_interval_days: int = 0
## Maximum permissible error, in `error_unit`.
var mpe: float = 1.0
var acceptance_ratio: float = 0.8
var daily_drift_rate: float = 0.0
var usage_drift_rate: float = 0.0
## Max |as-left| residual after zeroing, in `error_unit`.
var as_left_residual: float = 0.0
## Hard clamp on |error| so a neglected instrument stays playable.
var max_error: float = INF
## Calibration interval in days, adjusted on every calibration (GameState).
var cal_interval_days: int = 5
## Last day the current calibration is valid. Overdue from the day after.
var cal_due_day: int = 0
## Day of the last calibration (-1 = never).
var last_cal_day: int = -1

var error: float = 0.0:
	set(value):
		var clamped: float = clampf(value, -max_error, max_error)
		if clamped == error:
			return
		error = clamped
		error_changed.emit(error, get_band())

var _sign: float = 1.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_sign = _random_sign()


## Builds a sensor from instruments/<id> and guardband/green in the config.
## Fields missing from the data keep their defaults (with a warning).
static func from_config(p_instrument_id: String, p_max_error: float = INF) -> DriftingSensor:
	var sensor := DriftingSensor.new()
	sensor.instrument_id = p_instrument_id
	sensor.max_error = p_max_error
	var base: String = "instruments/%s" % p_instrument_id
	if DataManager.get_value(CONFIG_TABLE, base) == null:
		push_warning("DriftingSensor: instrument '%s' not in %s; using defaults." % [p_instrument_id, CONFIG_TABLE])
		return sensor
	sensor.error_unit = str(DataManager.get_value(CONFIG_TABLE, base + "/error_unit", ""))
	sensor.mpe = DataManager.get_number(CONFIG_TABLE, base + "/max_permissible_error", sensor.mpe)
	sensor.daily_drift_rate = DataManager.get_number(CONFIG_TABLE, base + "/daily_drift_rate", 0.0)
	# Optional fields: instruments without usage wear or residual omit them.
	if DataManager.get_value(CONFIG_TABLE, base + "/usage_drift_rate") != null:
		sensor.usage_drift_rate = DataManager.get_number(CONFIG_TABLE, base + "/usage_drift_rate", 0.0)
	if DataManager.get_value(CONFIG_TABLE, base + "/as_left_residual") != null:
		sensor.as_left_residual = DataManager.get_number(CONFIG_TABLE, base + "/as_left_residual", 0.0)
	sensor.role = str(DataManager.get_value(CONFIG_TABLE, base + "/role", sensor.role))
	sensor.display_name = str(DataManager.get_value(CONFIG_TABLE, base + "/display_name", p_instrument_id))
	sensor.short_name = str(DataManager.get_value(CONFIG_TABLE, base + "/short_name", sensor.display_name))
	sensor.resolution = DataManager.get_number(CONFIG_TABLE, base + "/resolution", 0.0)
	sensor.calibrated_by = str(DataManager.get_value(CONFIG_TABLE, base + "/calibrated_by", ""))
	sensor.bench_minutes = DataManager.get_number(CONFIG_TABLE, base + "/bench_minutes", 0.0)
	# null (no stated confidence) leaves 0.0, which means rectangular.
	var confidence: Variant = DataManager.get_value(CONFIG_TABLE, base + "/spec_confidence_pct")
	if typeof(confidence) == TYPE_FLOAT or typeof(confidence) == TYPE_INT:
		sensor.spec_confidence_pct = float(confidence)
	sensor.certificate_uncertainty = DataManager.get_number(CONFIG_TABLE, base + "/certificate_uncertainty", 0.0)
	sensor.certificate_k = DataManager.get_number(CONFIG_TABLE, base + "/certificate_k", 2.0)
	sensor.initial_interval_days = int(DataManager.get_number(CONFIG_TABLE, base + "/initial_interval_days", 0.0))
	sensor.acceptance_ratio = DataManager.get_number(
		CONFIG_TABLE, "guardband/green/max_error_ratio_inclusive", sensor.acceptance_ratio)
	return sensor


func advance_days(days: float) -> void:
	if days > 0.0 and daily_drift_rate > 0.0:
		error += _sign * daily_drift_rate * days


func add_usage(amount: float) -> void:
	if amount > 0.0 and usage_drift_rate > 0.0:
		error += _sign * usage_drift_rate * amount


## Zeroes the instrument against a reference whose own true error is
## `reference_error` (0.0 = a perfect reference). Returns the observed values,
## { "as_found": float, "as_left": float }: as-found is error - reference_error.
## After adjustment the true error is reference_error + residual, so a standard
## that is off moves the unit by the same amount without showing it.
func zero(reference_error: float = 0.0) -> Dictionary:
	var as_found: float = error - reference_error
	_sign = _random_sign()
	var residual: float = _rng.randf_range(-as_left_residual, as_left_residual)
	error = reference_error + residual
	var as_left: float = error - reference_error
	zeroed.emit(as_found, as_left)
	return { "as_found": as_found, "as_left": as_left }


func is_overdue(day: int) -> bool:
	return day > cal_due_day


func get_error_ratio() -> float:
	return absf(error) / mpe if mpe > 0.0 else INF


func get_band() -> Band:
	return band_for(error)


## Band for an arbitrary error value against this instrument's MPE.
func band_for(value: float) -> Band:
	var ratio: float = absf(value) / mpe if mpe > 0.0 else INF
	if ratio <= acceptance_ratio:
		return Band.IN_BAND
	if ratio <= 1.0:
		return Band.GUARDBAND
	return Band.OUT_OF_TOLERANCE


## Human-readable signed value in this instrument's unit, per NIST SP 811:
## U+2212 minus, no space before the plane-angle degree, a space before %, and
## no "RH" qualifier on the % symbol (use quantity_name() in the label instead).
## `decimals` < 0 uses the unit's default (2, or 3 for other units).
func format_value(value: float, decimals: int = -1) -> String:
	match error_unit:
		"degrees":
			return SP811.signed(value, decimals if decimals >= 0 else 2) + "°"
		"percentage_points_rh":
			return SP811.signed(value, decimals if decimals >= 0 else 2) + " %"
		_:
			return "%s %s" % [SP811.signed(value, decimals if decimals >= 0 else 3), error_unit]


## The quantity the error is in, for labels ("relative humidity").
func quantity_name() -> String:
	match error_unit:
		"degrees":
			return "angle"
		"percentage_points_rh":
			return "relative humidity"
		_:
			return error_unit


static func band_label(band: int) -> String:
	match band:
		Band.IN_BAND:
			return "IN TOLERANCE"
		Band.GUARDBAND:
			return "GUARD BAND"
		_:
			return "OUT OF TOLERANCE"


## Neon status palette from the Gemini planning thread (ui_color_hex values).
const COLOR_IN_BAND := Color("#38E1C6")
const COLOR_GUARDBAND := Color("#F5A623")
const COLOR_OUT_OF_TOLERANCE := Color("#FF5A5F")


static func band_color(band: int) -> Color:
	match band:
		Band.IN_BAND:
			return COLOR_IN_BAND
		Band.GUARDBAND:
			return COLOR_GUARDBAND
		_:
			return COLOR_OUT_OF_TOLERANCE


func _random_sign() -> float:
	return -1.0 if _rng.randf() < 0.5 else 1.0
