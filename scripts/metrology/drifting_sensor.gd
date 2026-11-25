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

## Carries the TRUE error and band. Display code should read observed_error
## and get_observed_band() instead (Ryan, 2026-11-22).
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
## Standards only: 0 = owned from the start; 1+ = bought from Bram (section 1.7).
var tier: int = 0
## Units only: this unit's error per unit of its standard's error, when the two
## measure different quantities (FM-3 volts into thermometer degrees Celsius).
var standard_sensitivity: float = 1.0
## Decimals readings show at least (-1 = the unit's default).
var display_decimals: int = -1
## Standards only: Bram's price, and who makes it (prefix for its certificates).
var price_credits: int = 0
var price_ore: int = 0
var maker: String = ""
## Who sells it: "bram" or "kestrel"; "" = not sold (or only by contract).
var seller: String = ""
var certificate_prefix: String = ""
## Standards only: locked to OIRM time through the orbital relay (the Rb-2D).
var relay_disciplined: bool = false
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

## The reference's own error at the last zero: what the instrument was set
## to read as zero. 0.0 after a zero against a perfect reference (or none).
var reference_offset: float = 0.0
## What the player's displays show: the error as the last reference saw it.
## A standard that was off when this unit was zeroed hides that much error.
var observed_error: float:
	get:
		return error - reference_offset

var _sign: float = 1.0
var _rng := RandomNumberGenerator.new()


## Until reseed() runs, the sign comes from an unseeded generator. Sensors in
## GameState.sensors are always reseeded from the world seed; one built
## elsewhere is not deterministic until reseed() is called.
func _init() -> void:
	_sign = _random_sign()


## Restarts this sensor's randomness (drift direction, as-left residuals)
## from `p_seed`. GameState derives it from the world seed.
func reseed(p_seed: int) -> void:
	_rng.seed = p_seed
	_sign = _random_sign()


## Where an instrument's data is. A robot's sensor ("robot_soil_probe@TR-1")
## shares its model's entry.
static func config_path(p_instrument_id: String) -> String:
	if "@" in p_instrument_id:
		return "robot_sensors/%s" % p_instrument_id.get_slice("@", 0)
	return "instruments/%s" % p_instrument_id


## A new, never calibrated instrument: a random error up to `ratio` of the MPE
## either way, from this sensor's own generator.
func start_uncalibrated(ratio: float) -> void:
	error = _rng.randf_range(-ratio, ratio) * mpe
	cal_due_day = 0
	last_cal_day = -1


## Builds a sensor from instruments/<id> and guardband/green in the config.
## Fields missing from the data keep their defaults (with a warning).
static func from_config(p_instrument_id: String, p_max_error: float = INF) -> DriftingSensor:
	var sensor := DriftingSensor.new()
	sensor.instrument_id = p_instrument_id
	sensor.max_error = p_max_error
	var base: String = config_path(p_instrument_id)
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
	sensor.tier = int(DataManager.get_number(CONFIG_TABLE, base + "/tier", 0.0))
	sensor.standard_sensitivity = DataManager.get_number(CONFIG_TABLE, base + "/standard_sensitivity", 1.0)
	sensor.display_decimals = int(DataManager.get_number(CONFIG_TABLE, base + "/display_decimals", -1.0))
	sensor.price_credits = int(DataManager.get_number(CONFIG_TABLE, base + "/price_credits", 0.0))
	sensor.price_ore = int(DataManager.get_number(CONFIG_TABLE, base + "/price_ore", 0.0))
	sensor.seller = str(DataManager.get_value(CONFIG_TABLE, base + "/seller", ""))
	sensor.relay_disciplined = DataManager.get_value(CONFIG_TABLE, base + "/relay_disciplined", false) == true
	sensor.maker = str(DataManager.get_value(CONFIG_TABLE, base + "/maker", ""))
	sensor.certificate_prefix = str(DataManager.get_value(CONFIG_TABLE, base + "/certificate_prefix", ""))
	sensor.acceptance_ratio = DataManager.get_number(
		CONFIG_TABLE, "guardband/green/max_error_ratio_inclusive", sensor.acceptance_ratio)
	return sensor


## The sensor's live state as plain data (JSON-safe), for host save and for
## sending a farm to a joining player. It includes what purchases change on a
## sensor (the standard a take-over moves it to, the wide treads' drift rate).
## Everything else comes from the config, so restore onto a sensor built by
## from_config() with the same id.
## The generator state is a string: JSON numbers can't hold all 64 bits.
## Write it with JSON.stringify(..., full_precision = true); floats can still
## change in the last few bits.
func to_dict() -> Dictionary:
	return {
		"instrument_id": instrument_id,
		"error": error,
		"reference_offset": reference_offset,
		"cal_interval_days": cal_interval_days,
		"cal_due_day": cal_due_day,
		"last_cal_day": last_cal_day,
		"calibrated_by": calibrated_by,
		"usage_drift_rate": usage_drift_rate,
		"sign": _sign,
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
	}


## Restores what to_dict() wrote. Keys that are missing keep their current
## values. A dictionary for another instrument, or with any value of the wrong
## type, is refused whole: nothing changes and it returns false.
func apply_dict(data: Dictionary) -> bool:
	if str(data.get("instrument_id", instrument_id)) != instrument_id:
		push_warning("DriftingSensor: state for '%s' can't load into '%s'." % [data.get("instrument_id"), instrument_id])
		return false
	for key: String in ["error", "reference_offset", "cal_interval_days", "cal_due_day", "last_cal_day",
			"usage_drift_rate", "sign"]:
		if data.has(key) and not typeof(data[key]) in [TYPE_FLOAT, TYPE_INT]:
			push_warning("DriftingSensor: %s state has a bad '%s'; not loaded." % [instrument_id, key])
			return false
	for key: String in ["rng_seed", "rng_state"]:
		if data.has(key) and not (typeof(data[key]) == TYPE_STRING and (data[key] as String).is_valid_int()):
			push_warning("DriftingSensor: %s state has a bad '%s'; not loaded." % [instrument_id, key])
			return false
	if data.has("calibrated_by") and typeof(data["calibrated_by"]) != TYPE_STRING:
		push_warning("DriftingSensor: %s state has a bad 'calibrated_by'; not loaded." % instrument_id)
		return false
	# Setting the seed resets the generator, so the state goes in after it.
	if data.has("rng_seed"):
		_rng.seed = str(data["rng_seed"]).to_int()
	if data.has("rng_state"):
		_rng.state = str(data["rng_state"]).to_int()
	if data.has("sign"):
		_sign = -1.0 if float(data["sign"]) < 0.0 else 1.0
	cal_interval_days = int(data.get("cal_interval_days", cal_interval_days))
	cal_due_day = int(data.get("cal_due_day", cal_due_day))
	last_cal_day = int(data.get("last_cal_day", last_cal_day))
	# A save from before the instrument had a standard keeps the one in the data.
	if data.get("calibrated_by", "") != "":
		calibrated_by = data["calibrated_by"]
	usage_drift_rate = float(data.get("usage_drift_rate", usage_drift_rate))
	# Set before error so error_changed listeners read the restored observed value.
	var offset_before: float = reference_offset
	reference_offset = float(data.get("reference_offset", reference_offset))
	var before: float = error
	error = float(data.get("error", error))
	if error == before and reference_offset != offset_before:
		# The setter skips unchanged values, but the observed error moved.
		error_changed.emit(error, get_band())
	return true


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
## `residual_scale` shrinks the as-left residual (the Calibration skill).
func zero(reference_error: float = 0.0, residual_scale: float = 1.0) -> Dictionary:
	var as_found: float = error - reference_error
	_sign = _random_sign()
	var residual: float = _rng.randf_range(-as_left_residual, as_left_residual) * residual_scale
	# Set before error so error_changed listeners read the new observed value.
	reference_offset = reference_error
	var before: float = error
	error = reference_error + residual
	if error == before:
		# The setter skips unchanged values, but the observed error may have moved.
		error_changed.emit(error, get_band())
	var as_left: float = error - reference_error
	zeroed.emit(as_found, as_left)
	return { "as_found": as_found, "as_left": as_left }


func is_overdue(day: int) -> bool:
	return day > cal_due_day


## The one overdue wording: the first day it is late (the day after the due day),
## never "day 0".
static func overdue_text(due_day: int) -> String:
	return "OVERDUE since day %d" % (due_day + 1)


func get_error_ratio() -> float:
	return absf(error) / mpe if mpe > 0.0 else INF


func get_band() -> Band:
	return band_for(error)


## Band of the observed error, for displays. Audits and physics use get_band().
func get_observed_band() -> Band:
	return band_for(observed_error)


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
## A humidity error is a difference of two readings, so it is in "percentage
## points" rather than "%".
## `decimals` < 0 uses the unit's default (2, or 3 for other units);
## `display_decimals` from the data sets the default; a caller asking for
## more precision (uncertainties) still gets at least that many.
## Celsius takes a space ("0.30 °C"); fractional frequency shows as "× 10⁻⁶".
func format_value(value: float, decimals: int = -1) -> String:
	var places: int
	if decimals >= 0:
		places = maxi(decimals, display_decimals)
	elif display_decimals >= 0:
		places = display_decimals
	else:
		places = 3 if _is_plain_unit() else 2
	var number: String = SP811.signed(value, places)
	match error_unit:
		"degrees":
			return number + "°"
		"percentage_points_rh":
			# A difference of two relative humidities, not a share of the reading.
			return number + " percentage points"
		"percentage_points_vwc":
			return number + " %"
		"degC":
			return number + " °C"
		"fractional_e6":
			return number + " × 10⁻⁶"
		_:
			return "%s %s" % [number, error_unit]


## The quantity the error is in, for labels ("relative humidity").
func quantity_name() -> String:
	match error_unit:
		"degrees":
			return "angle"
		"percentage_points_rh":
			return "relative humidity"
		"percentage_points_vwc":
			return "soil moisture"
		"kPa":
			return "pressure"
		"degC":
			return "temperature"
		"V":
			return "DC voltage"
		"N·m":
			return "torque"
		"fractional_e6":
			return "fractional frequency"
		_:
			return error_unit


## quantity_name() in title case for headings; acronyms stay ("DC Voltage").
func quantity_title() -> String:
	var words: PackedStringArray = quantity_name().split(" ")
	for i: int in words.size():
		if words[i] != words[i].to_upper():
			words[i] = words[i].substr(0, 1).to_upper() + words[i].substr(1)
	return " ".join(words)


func _is_plain_unit() -> bool:
	return not error_unit in ["degrees", "percentage_points_rh", "percentage_points_vwc", "degC", "fractional_e6"]


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
