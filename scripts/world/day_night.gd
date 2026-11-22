class_name DayNight
extends DirectionalLight3D
## Drives the farm sun from GameClock: rises at 04:30, peaks at noon, sets at
## 19:30, so the 06:00 start of each game day is already light. Warm at dawn/dusk, dim moonlight at night. Also scales the
## environment's sky and ambient light so nights read as nights.

const CONFIG_TABLE: StringName = &"day_night"
const COLOR_LOW_SUN := Color(1.0, 0.62, 0.38)
const COLOR_HIGH_SUN := Color(1.0, 0.97, 0.92)
const COLOR_MOON := Color(0.55, 0.65, 1.0)

@export var environment_node: WorldEnvironment
@export var day_energy: float = 1.0
@export var night_energy: float = 0.12
@export var min_ambient: float = 0.25

var _dawn_hour: float
var _dusk_hour: float
var _dawn_yaw_deg: float
var _dusk_yaw_deg: float
var _min_elevation_deg: float
var _max_elevation_deg: float


func _ready() -> void:
	_dawn_hour = DataManager.get_number(CONFIG_TABLE, "dawn_hour", NAN)
	_dusk_hour = DataManager.get_number(CONFIG_TABLE, "dusk_hour", NAN)
	_dawn_yaw_deg = DataManager.get_number(CONFIG_TABLE, "dawn_yaw_deg", NAN)
	_dusk_yaw_deg = DataManager.get_number(CONFIG_TABLE, "dusk_yaw_deg", NAN)
	_min_elevation_deg = DataManager.get_number(CONFIG_TABLE, "min_elevation_deg", NAN)
	_max_elevation_deg = DataManager.get_number(CONFIG_TABLE, "max_elevation_deg", NAN)
	for value: float in [_dawn_hour, _dusk_hour, _dawn_yaw_deg, _dusk_yaw_deg,
			_min_elevation_deg, _max_elevation_deg]:
		if not is_finite(value):
			push_error("DayNight: expected numeric settings in data/day_night.json.")
			set_process(false)
			return
	if _dawn_hour < 0.0 or _dawn_hour >= _dusk_hour or _dusk_hour >= GameClock.HOURS_PER_DAY:
		push_error("DayNight: expected dawn before dusk within one wall-clock day.")
		set_process(false)


func _process(_delta: float) -> void:
	var hour: float = GameClock.get_hour()
	var t: float = inverse_lerp(_dawn_hour, _dusk_hour, hour)  # 0 dawn .. 1 dusk
	var daylight: float = clampf(sin(clampf(t, 0.0, 1.0) * PI), 0.0, 1.0)
	var is_day: bool = t > 0.0 and t < 1.0

	var elevation: float = maxf(daylight * _max_elevation_deg, _min_elevation_deg)
	var yaw: float = lerpf(_dawn_yaw_deg, _dusk_yaw_deg, clampf(t, 0.0, 1.0))
	if not is_day:
		# Count from dusk across midnight, then ease toward the next dawn azimuth.
		var night_hours: float = GameClock.HOURS_PER_DAY - (_dusk_hour - _dawn_hour)
		var hours_since_dusk: float = fposmod(hour - _dusk_hour, GameClock.HOURS_PER_DAY)
		var night_progress: float = smoothstep(0.0, 1.0, hours_since_dusk / night_hours)
		var night_arc_deg: float = fposmod(_dawn_yaw_deg - _dusk_yaw_deg, rad_to_deg(TAU))
		yaw = _dusk_yaw_deg + night_arc_deg * night_progress
	rotation_degrees = Vector3(-elevation, yaw, 0.0)

	if is_day:
		light_energy = lerpf(night_energy, day_energy, sqrt(daylight))
		light_color = COLOR_LOW_SUN.lerp(COLOR_HIGH_SUN, clampf(daylight * 2.0, 0.0, 1.0))
	else:
		light_energy = night_energy
		light_color = COLOR_MOON

	if environment_node and environment_node.environment:
		var env: Environment = environment_node.environment
		var level: float = lerpf(min_ambient, 1.0, daylight)
		env.background_energy_multiplier = level
		env.ambient_light_energy = level
