extends Node3D
## Composition root for the dome interior: wires clickables to GameState,
## the bench UI, and the scene switcher, and refreshes the status panel.

## Built when shown, so it names the key or button in use.
## On the pad it is shorter, so it stays on one line (the keyboard's is 118 characters).
static func default_hint() -> String:
	if Controls.shown_pad():
		return "D-pad, %s: pick and use  ·  %s  ·  %s  ·  %s: back to farm" % [
			Controls.prompt(&"interact"), Controls.prompt(&"open_skills"), Controls.prompt(&"open_coop"), Controls.prompt(&"swap_scene")]
	return "Click the bench to calibrate  ·  Plan board: grow the lab  ·  %s: skills  ·  %s: co-op  ·  Airlock or %s: back to farm" % [
		Controls.prompt(&"open_skills"), Controls.prompt(&"open_coop"), Controls.prompt(&"swap_scene")]
const TOAST_SECONDS: float = 3.0
## Long messages (dispatches, audit lines) stay up longer.
const TOAST_SECONDS_PER_CHAR: float = 0.04

@onready var _bench: Clickable = %BenchClick
@onready var _airlock: Clickable = %AirlockClick
@onready var _terrarium_click: Clickable = %TerrariumClick
@onready var _spool: Clickable = %SpoolPickup
@onready var _sentinel_tank: Terrarium = %SentinelTank
@onready var _sentinel_click: Clickable = %SentinelClick
@onready var _bench_ui: CalBenchUI = %CalBenchUI
@onready var _plan_board: Clickable = %PlanBoardClick
@onready var _plan_board_ui: PlanBoardUI = %PlanBoardUI

@onready var _kestrel: Node3D = %Kestrel
@onready var _kestrel_click: Clickable = %KestrelClick
@onready var _kestrel_ui: KestrelUI = %KestrelUI
## The coffee ring on the bench (quest S2): there once the audit's one-time
## warning has been used. It says only that a mug stood here: the warning can
## come from a fault the bench has no part in.
@onready var _mug_ring: Node3D = %MugRing
@onready var _mug_ring_click: Inspectable = %MugRingInspect

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
## The "[E] verb" label over the clickable the pad has picked.
var _verb_prompt: VerbPrompt

var _toast_left: float = 0.0
## Frame the last toast was shown; another the same frame is added under it.
var _toast_frame: int = -1
## True while the audit summary is showing; phone lines don't replace it.
var _holding_audit: bool = false
## Pad selection pointer for dome Clickables.
var _pad_pointer: DomePadPointer
## The clickable the pad has picked; delegates to DomePadPointer.
var _pad_pick: Clickable:
	get:
		return _pad_pointer.selected if _pad_pointer != null else null
	set(value):
		if _pad_pointer != null:
			_pad_pointer.selected = value
## The toast's own text (the pick is named under it).
var _toast_text: String = ""
## The default line and the "use" words, built for the settled device.
var _hint_pad: bool = false
var _default_text: String = ""
var _use_text: String = ""


## [PLACEHOLDER] What the interact key does at the dome's main clickables (others read "Use").
const VERB_BENCH: String = "Calibrate"
const VERB_AIRLOCK: String = "Go outside"
const VERB_PLAN_BOARD: String = "Plan the lab"
const VERB_SPOOL: String = "Pick up"


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_bench.verb = VERB_BENCH
	_airlock.verb = VERB_AIRLOCK
	_plan_board.verb = VERB_PLAN_BOARD
	_spool.verb = VERB_SPOOL
	_sentinel_tank.spool_pickup.verb = VERB_SPOOL
	_verb_prompt = VerbPrompt.new()
	$UI.add_child(_verb_prompt)
	_pad_pointer = DomePadPointer.new()
	_pad_pointer.name = "DomePadPointer"
	add_child(_pad_pointer)
	_bench.clicked.connect(_bench_ui.open)
	_plan_board.clicked.connect(_plan_board_ui.open)
	_kestrel_click.clicked.connect(_kestrel_ui.open)
	$UI.add_child(SkillsUI.new())
	$UI.add_child(ToolRollUI.new())
	$UI.add_child(PickerUI.new())
	$UI.add_child(ControlsGuideUI.new())
	$UI.add_child(QuestsUI.new())
	$UI.add_child(CoopUI.new())
	$UI.add_child(ActionsMenuUI.new(ActionsMenuUI.PANEL_ACTIONS))
	var travel_ui := FastTravelUI.new()
	$UI.add_child(travel_ui)
	var console := FastTravelConsole.new()
	console.position = Vector3(-5.6, 0, -2.4)
	add_child(console)
	console.clicked.connect(travel_ui.open)
	_airlock.clicked.connect(func() -> void:
		if not FastTravel.pending:
			SceneSwitcher.swap_to(SceneSwitcher.exit_path()))
	_terrarium_click.clicked.connect(_on_terrarium_clicked)
	_spool.clicked.connect(_on_spool_clicked)
	_sentinel_click.clicked.connect(_on_sentinel_clicked)
	_sentinel_tank.spool_pickup.clicked.connect(_on_sentinel_spool_clicked)
	GameState.enclosures_changed.connect(_refresh_sentinel_hint)
	_refresh_sentinel_hint()
	for prop: Inspectable in get_tree().get_nodes_in_group(Inspectable.GROUP):
		prop.inspected.connect(_toast)
	($KeepsakeShelf as KeepsakeShelf).inspected.connect(_toast)
	($CertificateWall as CertificateWall).inspected.connect(_toast)
	GameState.calibration_recorded.connect(_on_calibration_recorded)
	GameState.phone_message.connect(_on_phone_message)
	GameState.skill_leveled.connect(_on_skill_leveled)
	SaveGame.save_failed.connect(_toast)
	# An audit posts several phone lines in one frame; this fires after them,
	# so the toast ends on a summary that names the failing instruments.
	GameState.audit_completed.connect(_on_audit_completed)

	var species: Dictionary = GameState.get_dome_species()
	_species_label.text = "%s  (%s)" % [_field(species, "common_name", "Unknown"), _field(species, "scientific_name", "Unclassified")]
	_show_mug_ring()


## The mug ring is on the bench, and can be inspected, once the audit's one-time
## warning has been used. A guest sees the host's farm, so the host's ring.
func _show_mug_ring() -> void:
	_mug_ring.visible = GameState.audit_grace_used
	if _mug_ring_click.enabled != _mug_ring.visible:
		_mug_ring_click.enabled = _mug_ring.visible
		if Clickable.hovered == _mug_ring_click:
			Clickable.hovered = null


func _process(delta: float) -> void:
	_refresh_status()
	_kestrel.visible = GameState.kestrel_present()
	if _kestrel_click.enabled != _kestrel.visible:
		_kestrel_click.enabled = _kestrel.visible
		if Clickable.hovered == _kestrel_click:
			Clickable.hovered = null
	_show_mug_ring()
	_pad_pointer.sync_state()
	_refresh_prompts()
	_update_verb_prompt()
	var active_pick: Clickable = _pad_pointer.active_selection()
	var picked: bool = active_pick != null
	var pick_line: String = "%s  ·  %s" % [_name_of(active_pick), _use_text] if picked else ""
	var next_hint: String
	if _toast_left > 0.0:
		_toast_left -= delta
		# What A would use is always on screen, under the toast.
		next_hint = _toast_text + ("\n" + pick_line if picked else "")
	else:
		_holding_audit = false
		var shown: Clickable = Clickable.hovered
		if picked:
			next_hint = pick_line
		elif shown == null:
			next_hint = _default_text
		else:
			next_hint = shown.hint if shown.hint != "" else _default_text
	if _hint_label.text != next_hint:
		_hint_label.text = next_hint


## Rebuilds the prompt wording when the settled device (Controls.shown_pad, which
## a flipping device cannot change) differs from the one the words are for.
func _refresh_prompts() -> void:
	var pad: bool = Controls.shown_pad()
	if _default_text != "" and pad == _hint_pad:
		return
	_hint_pad = pad
	_default_text = default_hint()
	_use_text = "%s to use" % Controls.prompt(&"interact")


## The "[A] verb" label over the clickable the pad has picked (the mouse clicks, so
## it has no key to show); hidden when nothing is picked or a panel is open.
func _update_verb_prompt() -> void:
	# sync_state() has just cleared an invalid pick or paused for an open panel.
	var active_pick: Clickable = _pad_pointer.active_selection()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if active_pick == null or camera == null or (active_pick == _airlock and FastTravel.pending):
		_verb_prompt.clear()
		return
	_verb_prompt.point_at(camera.unproject_position(_pad_pointer.pick_point(active_pick)), VerbPrompt.verb_of(active_pick))


func _name_of(item: Clickable) -> String:
	return item.hint if item.hint != "" else String(item.name)


# --- Pad selection (delegated to DomePadPointer) -----------------------------

## Every clickable that can be used now.
func usable_clickables() -> Array[Clickable]:
	return _pad_pointer.usable_clickables()


## The usable clickable nearest in `direction` (screen space) from the pick, or
## from the middle of the screen when nothing is picked yet.
func pad_step(direction: Vector2) -> void:
	_pad_pointer.step(direction)


func _input(event: InputEvent) -> void:
	_pad_pointer.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_pad_pointer.handle_unhandled_input(event)


func _stick_direction(motion: InputEventJoypadMotion) -> Vector2i:
	return _pad_pointer.stick_direction(motion)


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
	_molt_label.text = GameState.molt_text()
	_silk_label.text = "SILK SPOOLS %s   RELAY: %s" % [GameState.spool_count_text(),
		"STOCK" if not GameState.relay_slotted else "DAMAGED SILK" if GameState.slotted_spool_damaged else "OPTICAL SILK"]


## Writes "<TITLE>  <ideal + observed error>" and its band and due day. The
## display shows what the instrument reads; the molt goes by the true error.
func _show_reading(sensor: DriftingSensor, ideal: Variant, unit: String, title: String,
		value_label: Label, band_label: Label) -> void:
	var reading: String = "--"
	if typeof(ideal) == TYPE_FLOAT or typeof(ideal) == TYPE_INT:
		reading = SP811.number(float(ideal) + sensor.observed_error, 1) + unit
	value_label.text = "%s  %s" % [title, reading]
	var band: int = sensor.get_observed_band()
	var due_text: String = ("CAL " + DriftingSensor.overdue_text(sensor.cal_due_day) if sensor.is_overdue(GameClock.get_day_index())
		else "cal due day %d" % sensor.cal_due_day)
	band_label.text = "%s  ·  %s" % [DriftingSensor.band_label(band), due_text]
	band_label.add_theme_color_override("font_color", DriftingSensor.band_color(band))


func _on_skill_leveled(player_id: String, skill_id: String, _level: int) -> void:
	if not _holding_audit and (player_id == "" or player_id == GameState.local_player_id):
		_toast("SKILL UP: %s. %s shows skills." % [GameState.skill_text(skill_id), Controls.prompt(&"open_skills")])


func _on_terrarium_clicked() -> void:
	var species: Dictionary = GameState.get_dome_species()
	var which: String = ("the thermometer and hygrometer" if GameState.is_in_service(GameState.THERMOMETER_ID)
		else "the hygrometer")
	_toast("%s: ideal %s °C, relative humidity %s %%. Keep %s within MPE to progress the molt." % [
		_field(species, "common_name", "?"), _field(species, "ideal_temp_c", "?"), _field(species, "ideal_humidity_pct", "?"), which])


func _on_spool_clicked() -> void:
	if await FarmCommands.request(&"collect_spool"):
		_toast("Collected 1 optical silk spool. Install it at the farm relay.")


func _refresh_sentinel_hint() -> void:
	var id: String = _sentinel_tank.species_id
	_sentinel_click.hint = "Inspect " + _sentinel_name() if GameState.is_caught(id) else "Empty tank"


func _sentinel_name() -> String:
	return _field(DataManager.get_record(GameState.SPECIES_TABLE, StringName(_sentinel_tank.species_id)), "common_name", "?")


## The tank's humidity is as the dome's one hygrometer shows it.
func _on_sentinel_clicked() -> void:
	var id: String = _sentinel_tank.species_id
	if not GameState.is_caught(id):
		_toast("Empty tank, ready for a rare tarantula.")
		return
	var species: Dictionary = DataManager.get_record(GameState.SPECIES_TABLE, StringName(id))
	var reading: float = GameState.enclosure_humidity_reading(id)
	_toast("%s: ideal relative humidity (%s ± %s) %%, now %s. %s." % [_sentinel_name(),
		_field(species, "ideal_humidity_pct", "?"), _field(species, "humidity_tolerance_pct", "?"),
		"not set" if is_nan(reading) else SP811.number(reading, 1) + " %", GameState.enclosure_text(id)])


func _on_sentinel_spool_clicked() -> void:
	if await FarmCommands.request(&"collect_enclosure_spool", [_sentinel_tank.species_id]):
		_toast("Collected 1 optical silk spool, %s. Install it at the farm relay." % _sentinel_name())


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


func _on_phone_message(text: String) -> void:
	if _holding_audit:
		if Engine.get_process_frames() == _toast_frame:
			# A cancellation the same morning stacks under the audit summary.
			if not text.begins_with("JOB BOARD:"):
				_toast(text)
			return
		# Later messages (the player acting) replace it as usual.
		_holding_audit = false
		_toast_left = 0.0
	# The board line comes last each morning; a cancellation or dispatch just
	# shown matters more. It is on the phone log either way.
	if text.begins_with("JOB BOARD:") and _toast_left > 0.0:
		return
	_toast(text)


func _on_audit_completed(report: Dictionary) -> void:
	_show_audit(report)
	_holding_audit = true


func _show_audit(report: Dictionary) -> void:
	if report.get("warning", false):
		_toast_fresh("AUDIT DAY %d: WARNING ONLY. Your manager %s before Vance got in. One time only." % [
			report.get("day", 0), report.get("waived_names", "")])
		return
	if report.get("passed", true):
		_toast_fresh("AUDIT DAY %d: PASS. Vance is disappointed." % report.get("day", 0))
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
	for finding: Dictionary in report.get("interlocks", []):
		failing.append("%s (interlock overridden)" % GameState.robots.get(finding["robot_id"], {}).get("name", finding["robot_id"]))
	_toast_fresh("AUDIT DAY %d: FINE %s CR. %s. Details on the phone log." % [
		report.get("day", 0), SP811.integer(int(report.get("total_fine", 0))), ", ".join(failing)])


## The audit summary replaces the morning's phone lines shown in the same
## frame (they are on the phone log); later lines stack under it.
func _toast_fresh(text: String) -> void:
	_toast_left = 0.0
	_toast(text)


func _toast(text: String) -> void:
	# Two messages in one frame (a dawn cancellation, then the bench result
	# after the same time jump) both stay on screen.
	var frame: int = Engine.get_process_frames()
	if frame == _toast_frame and _toast_left > 0.0:
		_toast_text += "\n" + text
	else:
		_toast_text = text
	_hint_label.text = _toast_text
	_toast_frame = frame
	_toast_left = maxf(TOAST_SECONDS, _toast_text.length() * TOAST_SECONDS_PER_CHAR)
