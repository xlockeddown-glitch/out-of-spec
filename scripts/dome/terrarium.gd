class_name Terrarium
extends Node3D
## Greybox enclosure visuals, driven entirely by GameState:
##   - status LED follows the hygrometer band (red blinks when out of tolerance)
##   - heat lamp turns harsh amber when out of tolerance
##   - tarantula: Active -> Pre-Molt (dimmed and squashed, greybox or voxel model)
##     -> Molted (exuvia + spool; the spider itself is hidden)
##     -> the exuvia stays GameState.EXUVIA_LINGER_DAYS after pickup, and the
##        spider stays hidden (in its burrow) until it goes

const LAMP_WARM := Color(1.0, 0.72, 0.42)
const LAMP_HARSH := Color(1.0, 0.45, 0.08)
const BODY_ACTIVE := Color(0.32, 0.22, 0.15)
const BODY_PRE_MOLT := Color(0.16, 0.12, 0.1)
const BLINK_HZ: float = 2.5

@export var status_led: GeometryInstance3D
@export var heat_lamp: OmniLight3D
## Every GeometryInstance3D child of this node gets the shared body material;
## the voxel model's meshes get the pre-molt dim overlay instead.
@export var tarantula: Node3D
@export var exuvia: Node3D
@export var spool_pickup: Clickable

var _led_mat := StandardMaterial3D.new()
var _body_mat := StandardMaterial3D.new()
## Dims the voxel spider in pre-molt by the same per-channel ratio the greybox
## body goes through (BODY_PRE_MOLT / BODY_ACTIVE, taken in linear light because
## the multiply blend works on linear values), so both read equally dim.
var _dim_mat := StandardMaterial3D.new()
var _time: float = 0.0


func _ready() -> void:
	_led_mat.emission_enabled = true
	_dim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dim_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	var active_lin := BODY_ACTIVE.srgb_to_linear()
	var pre_molt_lin := BODY_PRE_MOLT.srgb_to_linear()
	_dim_mat.albedo_color = Color(pre_molt_lin.r / active_lin.r,
		pre_molt_lin.g / active_lin.g, pre_molt_lin.b / active_lin.b).linear_to_srgb()
	_led_mat.emission_energy_multiplier = ModelSlot.EMIT_ENERGY
	if status_led:
		status_led.material_override = _led_mat
	if tarantula:
		for child: Node in tarantula.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).material_override = _body_mat
	_apply_molt_visuals()
	GameState.molt_changed.connect(_on_molt_changed)
	GameClock.day_started.connect(_on_day_started)


func _process(delta: float) -> void:
	_time += delta
	var band: int = GameState.hygrometer.get_observed_band()
	var color: Color = DriftingSensor.band_color(band)
	var lit: bool = band != DriftingSensor.Band.OUT_OF_TOLERANCE or fmod(_time * BLINK_HZ, 1.0) < 0.5
	_led_mat.albedo_color = color
	_led_mat.emission = color if lit else Color.BLACK
	if heat_lamp:
		var climate_bad: bool = GameState.hygrometer.get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE
		heat_lamp.light_color = LAMP_HARSH if climate_bad else LAMP_WARM


func _on_molt_changed(_progress: float, _stage: int) -> void:
	_apply_molt_visuals()


func _on_day_started(_day: int) -> void:
	_apply_molt_visuals()  # a lingering exuvia goes in the morning


func _apply_molt_visuals() -> void:
	var stage: int = GameState.molt_stage
	var pre_molt: bool = stage == GameState.MoltStage.PRE_MOLT
	var molted: bool = stage == GameState.MoltStage.MOLTED
	var husk: bool = GameState.is_exuvia_visible()
	_body_mat.albedo_color = BODY_PRE_MOLT if pre_molt else BODY_ACTIVE
	if tarantula:
		tarantula.scale = Vector3(1.0, 0.7, 1.0) if pre_molt else Vector3.ONE
		tarantula.visible = not husk
		# The voxel model's meshes (MeshInstance3D); the greybox CSG parts use _body_mat.
		for node: Node in tarantula.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_overlay = _dim_mat if pre_molt else null
	if exuvia:
		exuvia.visible = husk
	if spool_pickup:
		spool_pickup.visible = molted
		spool_pickup.enabled = molted
