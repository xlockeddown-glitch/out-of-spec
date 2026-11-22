class_name CabReadout
extends MeshInstance3D
## Steering-band readout on the tractor's cab roof, at its front-right corner, where
## the gameplay camera sees it at every rover heading. State LEDs are game-driven
## (see docs/art/voxel_models.md), so this mesh sits outside the ModelSlot and
## moves to the roof that is showing: the voxel roof or the greybox cab roof. Colored by GameState.steering:
## teal in tolerance, amber in the guard band, red blinking when out of tolerance
## (same rule as the terrarium LED).

const BLINK_HZ: float = 2.5
## Measured, not from a spec: in sunlight on the farm (Filmic tonemap) 0.5 renders
## teal, amber and red within about 20 RGB of the palette hex. ModelSlot.EMIT_ENERGY
## (1.2) washes teal to #5EFFF2 and amber to yellow #FFDD3B, because the lit
## albedo adds to the glow here. Night (emission only, no sunlit albedo) is not measured.
const EMISSION_ENERGY: float = 0.5

## The rover's ModelSlot. Picks which roof the readout sits on.
@export var model_slot: ModelSlot
## Rover-local center on the voxel tractor roof (1.5 m top). Placement choice,
## not from a spec: checked visible from the iso camera at all 8 headings.
@export var model_position: Vector3 = Vector3(0.3, 1.55, -0.2)
## Rover-local center on the greybox cab roof (1.65 m top), used without a model.
@export var greybox_position: Vector3 = Vector3(0.4, 1.7, 0.1)

var _mat := StandardMaterial3D.new()
var _time: float = 0.0


func _ready() -> void:
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = EMISSION_ENERGY
	material_override = _mat
	position = model_position if model_slot != null and model_slot.has_model() else greybox_position
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_refresh()


func _refresh() -> void:
	var band: int = GameState.steering.get_band() if GameState.steering else DriftingSensor.Band.IN_BAND
	var color: Color = DriftingSensor.band_color(band)
	var lit: bool = band != DriftingSensor.Band.OUT_OF_TOLERANCE or fmod(_time * BLINK_HZ, 1.0) < 0.5
	_mat.albedo_color = color
	_mat.emission = color if lit else Color.BLACK
