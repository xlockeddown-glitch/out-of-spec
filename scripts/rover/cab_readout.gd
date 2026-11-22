class_name CabReadout
extends MeshInstance3D
## Steering-band readout on the tractor's cab dash, just behind the windshield.
## The model leaves this spot empty (state LEDs are game-driven, see
## docs/art/voxel_models.md), so this mesh sits outside the ModelSlot and shows
## over both the greybox and the voxel model. Colored by GameState.steering:
## teal in tolerance, amber in the guard band, red blinking when out of tolerance
## (same rule as the terrarium LED).

const BLINK_HZ: float = 2.5
const EMISSION_ENERGY: float = 3.0

var _mat := StandardMaterial3D.new()
var _time: float = 0.0


func _ready() -> void:
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = EMISSION_ENERGY
	material_override = _mat
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
