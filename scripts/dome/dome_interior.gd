extends Node3D
## Composition root for the dome interior: wires clickables to GameState,
## the bench UI, and the scene switcher, and refreshes the status panel.

const DEFAULT_HINT: String = "Click the bench to calibrate  ·  Airlock or Tab: back to farm"
const TOAST_SECONDS: float = 3.0
## Long messages (dispatches, audit lines) stay up longer.
const TOAST_SECONDS_PER_CHAR: float = 0.04

@onready var _bench: Clickable = %BenchClick
@onready var _airlock: Clickable = %AirlockClick
@onready var _terrarium_click: Clickable = %TerrariumClick
@onready var _spool: Clickable = %SpoolPickup
@onready var _bench_ui: CalBenchUI = %CalBenchUI

@onready var _clock_label: Label = %ClockLabel
@onready var _species_label: Label = %SpeciesLabel
@onready var _hygro_label: Label = %HygroLabel
@onready var _hygro_band_label: Label = %HygroBandLabel
@onready var _temp_label: Label = %TempLabel
@onready var _temp_band_label: Label = %TempBandLabel
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
	GameState.phone_message.connect(_toast)
	# An audit posts several phone lines in one frame; this fires after them,
	# so the toast ends on a summary that names the failing instruments.
	GameState.audit_completed.connect(_on_audit_completed)

	var species: Dictionary = GameState.get_dome_species()
	_species_label.text = "%s  (%s)" % [_field(species, "common_name", "Unknown"), _field(species, "scientific_name", "Unclassified")]


func _process(delta: float) -> void:
	_refresh_status()
	if _toast_left > 0.0:
		_toast_left -= delta
	else:
		var hovered: Clickable = Clickable.hovered
		_hint_label.text = hovered.hint if hovered and hovered.hint != "" else DEFAULT_HINT


func _refresh_status() -> void:
	_clock_label.text = "%s   %s CR" % [GameClock.format_now(), SP811.integer(GameState.credits)]
	var species: Dictionary = GameState.get_dome_species()
	_show_reading(GameState.hygrometer, species.get("ideal_humidity_pct"), " %",
		"RELATIVE HUMIDITY", _hygro_label, _hygro_band_label)
	# The thermometer reads once the FM-3 is on the colony to calibrate it.
	var thermo_on: bool = GameState.is_in_service(GameState.THERMOMETER_ID)
	_temp_label.visible = thermo_on
	_temp_band_label.visible = thermo_on
	if thermo_on:
		_show_reading(GameState.get_sensor(GameState.THERMOMETER_ID), species.get("ideal_temp_c"), " °C",
			"TEMPERATURE", _temp_label, _temp_band_label)

	_molt_bar.value = GameState.molt_progress
	match GameState.molt_stage:
		GameState.MoltStage.MOLTED:
			_molt_label.text = "MOLTED: optical silk spool ready"
		_:
			var stage: String = "PRE-MOLT" if GameState.molt_stage == GameState.MoltStage.PRE_MOLT else "MOLT"
			_molt_label.text = (stage + " PAUSED: " + GameState.molt_pause_reason() if GameState.is_molt_paused()
				else "%s  %d %%" % [stage, roundi(GameState.molt_progress * 100.0)])
	_silk_label.text = "SILK SPOOLS %d   RELAY: %s" % [
		GameState.optical_silk_spools, "OPTICAL SILK" if GameState.relay_slotted else "STOCK"]


## Writes "<TITLE>  <ideal + observed error>" and its band and due day. The
## display shows what the instrument reads; the molt goes by the true error.
func _show_reading(sensor: DriftingSensor, ideal: Variant, unit: String, title: String,
		value_label: Label, band_label: Label) -> void:
	var reading: String = "--"
	if typeof(ideal) == TYPE_FLOAT or typeof(ideal) == TYPE_INT:
		reading = SP811.number(float(ideal) + sensor.observed_error, 1) + unit
	value_label.text = "%s  %s" % [title, reading]
	var band: int = sensor.get_observed_band()
	var due_text: String = ("CAL OVERDUE (due day %d)" % sensor.cal_due_day if sensor.is_overdue(GameClock.get_day_index())
		else "cal due day %d" % sensor.cal_due_day)
	band_label.text = "%s  ·  %s" % [DriftingSensor.band_label(band), due_text]
	band_label.add_theme_color_override("font_color", DriftingSensor.band_color(band))


func _on_terrarium_clicked() -> void:
	var species: Dictionary = GameState.get_dome_species()
	var which: String = ("the thermometer and hygrometer" if GameState.is_in_service(GameState.THERMOMETER_ID)
		else "the hygrometer")
	_toast("%s: ideal %s °C, relative humidity %s %%. Keep %s within MPE to progress the molt." % [
		_field(species, "common_name", "?"), _field(species, "ideal_temp_c", "?"), _field(species, "ideal_humidity_pct", "?"), which])


func _on_spool_clicked() -> void:
	if GameState.collect_spool():
		_toast("Collected 1 optical silk spool. Install it at the farm relay.")


func _on_calibration_recorded(record: Dictionary) -> void:
	var id: String = record.get("instrument_id", "")
	if (id == GameState.HYGROMETER_ID or id == GameState.THERMOMETER_ID) 			and not record.get("as_found_in_tolerance", true):
		var what: String = "Hygrometer" if id == GameState.HYGROMETER_ID else "Thermometer"
		_toast("%s back in tolerance. %s" % [what,
			"Molt resumes." if not GameState.is_molt_paused()
			else "Molt still paused: " + GameState.molt_pause_reason() + "."])


## Dictionary.get() only falls back when the key is missing; alien morphs carry
## explicit JSON nulls for undefined values, so treat null as missing too.
static func _field(record: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = record.get(key)
	return fallback if value == null else str(value)


func _on_audit_completed(report: Dictionary) -> void:
	if report.get("warning", false):
		_toast("AUDIT DAY %d: WARNING ONLY. Your manager %s before Vance got in. One time only." % [
			report.get("day", 0), report.get("waived_names", "")])
		return
	if report.get("passed", true):
		_toast("AUDIT DAY %d: PASS. Vance is disappointed." % report.get("day", 0))
		return
	var failing: PackedStringArray = []
	for line: Dictionary in report.get("lines", []):
		if line.get("violation", false):
			var name_text: String = GameState.instrument_name(line["instrument_id"])
			var why: PackedStringArray = []
			if line.get("out_of_tolerance", false):
				why.append("out of tolerance")
			if line.get("overdue", false):
				why.append("overdue")
			if line.get("suspect", false):
				why.append("suspect calibration")
			failing.append("%s (%s)" % [name_text, ", ".join(why)])
	if report.get("tire_check", {}).get("violation", false):
		failing.append("rover tires (AUD-1T)")
	_toast("AUDIT DAY %d: FINE %s CR. %s. Details on the phone log." % [
		report.get("day", 0), SP811.integer(int(report.get("total_fine", 0))), ", ".join(failing)])


func _toast(text: String) -> void:
	_hint_label.text = text
	_toast_left = maxf(TOAST_SECONDS, text.length() * TOAST_SECONDS_PER_CHAR)
