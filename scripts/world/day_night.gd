class_name DayNight
extends DirectionalLight3D
## Drives the farm sun from GameClock: rises at 04:30, peaks at noon, sets at
## 19:30, so the 06:00 start of each game day is already light. Warm at dawn/dusk, dim moonlight at night. Also scales the
## environment's sky and ambient light so nights read as nights.

const DAWN_HOUR: float = 4.5
const DUSK_HOUR: float = 19.5
const COLOR_LOW_SUN := Color(1.0, 0.62, 0.38)
const COLOR_HIGH_SUN := Color(1.0, 0.97, 0.92)
const COLOR_MOON := Color(0.55, 0.65, 1.0)

@export var environment_node: WorldEnvironment
@export var max_elevation_deg: float = 62.0
@export var day_energy: float = 1.0
@export var night_energy: float = 0.12
@export var min_ambient: float = 0.25


func _process(_delta: float) -> void:
	var hour: float = GameClock.get_hour()
	var t: float = inverse_lerp(DAWN_HOUR, DUSK_HOUR, hour)  # 0 dawn .. 1 dusk
	var daylight: float = clampf(sin(clampf(t, 0.0, 1.0) * PI), 0.0, 1.0)
	var is_day: bool = t > 0.0 and t < 1.0

	var elevation: float = maxf(daylight * max_elevation_deg, 10.0)
	var yaw: float = lerpf(-120.0, 60.0, clampf(t, 0.0, 1.0))
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
