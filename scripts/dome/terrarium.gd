class_name Terrarium
extends Node3D
## Greybox enclosure visuals, driven entirely by GameState:
##   - status LED follows the hygrometer band (red blinks when out of tolerance)
##   - heat lamp turns harsh amber when out of tolerance
##   - tarantula: Active -> Pre-Molt (dimmed, curled) -> Molted (exuvia + spool)

const LAMP_WARM := Color(1.0, 0.72, 0.42)
const LAMP_HARSH := Color(1.0, 0.45, 0.08)
const BODY_ACTIVE := Color(0.32, 0.22, 0.15)
const BODY_PRE_MOLT := Color(0.16, 0.12, 0.1)
const BLINK_HZ: float = 2.5

@export var status_led: GeometryInstance3D
@export var heat_lamp: OmniLight3D
## Every GeometryInstance3D child of this node gets the shared body material.
@export var tarantula: Node3D
@export var exuvia: Node3D
@export var spool_pickup: Clickable

var _led_mat := StandardMaterial3D.new()
var _body_mat := StandardMaterial3D.new()
var _time: float = 0.0


func _ready() -> void:
	_led_mat.emission_enabled = true
	_led_mat.emission_energy_multiplier = ModelSlot.EMIT_ENERGY
	if status_led:
		status_led.material_override = _led_mat
	if tarantula:
		for child: Node in tarantula.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).material_override = _body_mat
	_apply_molt_visuals()
	GameState.molt_changed.connect(_on_molt_changed)


func _process(delta: float) -> void:
	_time += delta
	var band: int = GameState.hygrometer.get_band()
	var color: Color = DriftingSensor.band_color(band)
	var lit: bool = band != DriftingSensor.Band.OUT_OF_TOLERANCE or fmod(_time * BLINK_HZ, 1.0) < 0.5
	_led_mat.albedo_color = color
	_led_mat.emission = color if lit else Color.BLACK
	if heat_lamp:
		heat_lamp.light_color = LAMP_HARSH if band == DriftingSensor.Band.OUT_OF_TOLERANCE else LAMP_WARM


func _on_molt_changed(_progress: float, _stage: int) -> void:
	_apply_molt_visuals()


func _apply_molt_visuals() -> void:
	var stage: int = GameState.molt_stage
	var pre_molt: bool = stage == GameState.MoltStage.PRE_MOLT
	var molted: bool = stage == GameState.MoltStage.MOLTED
	_body_mat.albedo_color = BODY_PRE_MOLT if pre_molt else BODY_ACTIVE
	if tarantula:
		tarantula.scale = Vector3(1.0, 0.7, 1.0) if pre_molt else Vector3.ONE
	if exuvia:
		exuvia.visible = molted
	if spool_pickup:
		spool_pickup.visible = molted
		spool_pickup.enabled = molted
