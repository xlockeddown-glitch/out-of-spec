extends Node3D
## Composition root for the dome interior: wires clickables to GameState,
## the bench UI, and the scene switcher, and refreshes the status panel.

const DEFAULT_HINT: String = "Click the bench to calibrate  ·  Airlock or Tab: back to farm"
const TOAST_SECONDS: float = 3.0

@onready var _bench: Clickable = %BenchClick
@onready var _airlock: Clickable = %AirlockClick
@onready var _terrarium_click: Clickable = %TerrariumClick
@onready var _spool: Clickable = %SpoolPickup
@onready var _bench_ui: CalBenchUI = %CalBenchUI

@onready var _species_label: Label = %SpeciesLabel
@onready var _hygro_label: Label = %HygroLabel
@onready var _hygro_band_label: Label = %HygroBandLabel
@onready var _molt_label: Label = %MoltLabel
@onready var _molt_bar: ProgressBar = %MoltBar
@onready var _silk_label: Label = %SilkLabel
@onready var _hint_label: Label = %HintLabel

var _toast_left: float = 0.0


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_bench.clicked.connect(_bench_ui.open)
	_airlock.clicked.connect(func() -> void: SceneSwitcher.swap_to(SceneSwitcher.FARM_SCENE))
	_terrarium_click.clicked.connect(_on_terrarium_clicked)
	_spool.clicked.connect(_on_spool_clicked)
	GameState.calibration_recorded.connect(_on_calibration_recorded)

	var species: Dictionary = GameState.get_dome_species()
	_species_label.text = "%s  (%s)" % [species.get("common_name", "Unknown"), species.get("scientific_name", "?")]


func _process(delta: float) -> void:
	_refresh_status()
	if _toast_left > 0.0:
		_toast_left -= delta
	else:
		var hovered: Clickable = Clickable.hovered
		_hint_label.text = hovered.hint if hovered and hovered.hint != "" else DEFAULT_HINT


func _refresh_status() -> void:
	var hygro: DriftingSensor = GameState.hygrometer
	var reading: String = "--"
	var ideal: Variant = GameState.get_dome_species().get("ideal_humidity_pct")
	if typeof(ideal) == TYPE_FLOAT or typeof(ideal) == TYPE_INT:
		reading = "%.1f %%RH" % (float(ideal) + hygro.error)
	_hygro_label.text = "HYGROMETER READS  %s" % reading
	var band: int = hygro.get_band()
	_hygro_band_label.text = DriftingSensor.band_label(band)
	_hygro_band_label.add_theme_color_override("font_color", DriftingSensor.band_color(band))

	_molt_bar.value = GameState.molt_progress
	match GameState.molt_stage:
		GameState.MoltStage.MOLTED:
			_molt_label.text = "MOLTED: optical silk spool ready"
		GameState.MoltStage.PRE_MOLT:
			_molt_label.text = "PRE-MOLT  %d%%" % roundi(GameState.molt_progress * 100.0)
		_:
			_molt_label.text = ("MOLT PAUSED: hygrometer out of tolerance" if GameState.is_molt_paused()
				else "MOLT  %d%%" % roundi(GameState.molt_progress * 100.0))
	_silk_label.text = "SILK SPOOLS %d   RELAY: %s" % [
		GameState.optical_silk_spools, "OPTICAL SILK" if GameState.relay_slotted else "STOCK"]


func _on_terrarium_clicked() -> void:
	var species: Dictionary = GameState.get_dome_species()
	_toast("%s: ideal %s °C / %s %%RH. Keep the hygrometer within MPE to progress the molt." % [
		species.get("common_name", "?"), species.get("ideal_temp_c", "?"), species.get("ideal_humidity_pct", "?")])


func _on_spool_clicked() -> void:
	if GameState.collect_spool():
		_toast("Collected 1 optical silk spool. Install it at the farm relay.")


func _on_calibration_recorded(record: Dictionary) -> void:
	if record.get("instrument_id", "") == GameState.HYGROMETER_ID and not record.get("as_found_in_tolerance", true):
		_toast("Hygrometer back in tolerance. Molt resumes.")


func _toast(text: String) -> void:
	_hint_label.text = text
	_toast_left = TOAST_SECONDS
