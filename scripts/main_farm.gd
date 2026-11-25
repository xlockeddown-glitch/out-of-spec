extends Node
## Composition root for the farm scene. Wires rover / GameState <-> HUD.
## Holds no gameplay rules of its own. Dispatches and audits come from
## GameState's phone log, so they survive scene swaps.

## Phone-log lines replayed into the HUD when the farm loads.
const LOG_REPLAY_LINES: int = 6
## With the rover in the other scene, these only say where it is.
const ROVER_KEYS: Array[StringName] = [
	&"rover_forward", &"rover_reverse", &"rover_till", &"rover_zero_steering", &"rover_dig", &"rover_fill"]
## A clicked prop's text stays in the hover label this long, like the dome's toast.
const INSPECT_SECONDS: float = 3.0
## Long descriptions stay up longer.
const INSPECT_SECONDS_PER_CHAR: float = 0.04
## The prop whose inspect text also carries the plot's soil readings.
const SOIL_PROBE_PROP: String = "soil_moisture_probe"

## Within this far of the relay mast the Q check reads the dish; elsewhere, the
## rover's own steering encoder [PLACEHOLDER].
const DISH_REACH_M: float = 8.0
const DISH_ID: String = "relay_dish_azimuth"

var _had_los: bool = true
## The blocks this screen has told about.
var _blocks_told: Array[Vector2i] = []
var _pockets_told: Array[Vector2i] = []
## The stone stock last told, and the kind of piece B builds.
var _stone_told: int = 0
var _stone_kind: int = StonePieces.WALL
var _last_band: int = DriftingSensor.Band.IN_BAND

@onready var _rover: RoverController = %Rover
@onready var _survey_line: SurveyLine = $WorldView/WorldViewport/World/SurveyLine
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _airlock: Clickable = %Airlock
@onready var _hover_hint: Label = %HoverHint
@onready var _bram_bay: BramBay = %BramBay
## Ryan, 2026-11-22: "Pad by the airlock". Park here and press E to calibrate
## the tire gauge against the WD-1 without going into the dome.
@onready var _cal_pad: ParkingPad = %FieldCalPad
@onready var _tunnel_pad: ParkingPad = %TunnelPad

var _robots_ui: RobotsUI
var _bram_line: String = ""
## Seconds left showing a clicked prop's text in the hover label.
var _inspect_left: float = 0.0
## Ryan (2026-11-22): buying a standard takes two presses. The first press
## (key or button) arms the offer and shows the price; a second press on the
## same offer buys it. Leaving the bay or pressing another offer re-arms.
var _armed_standard: String = ""
## This player asked to move the rover; the host said yes.
var _moving: bool = false
var _move_granted: bool = false


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.soil_tilled.connect(_on_soil_tilled)
	_rover.till_rejected.connect(_on_till_rejected)
	_rover.dig_rejected.connect(_on_dig_rejected)
	_rover.fill_rejected.connect(_on_fill_rejected)
	GameState.terrain_changed.connect(_show_dug)
	_blocks_told.assign(GameState.found_blocks.keys())
	GameState.blocks_changed.connect(_on_blocks_changed)
	_pockets_told.assign(GameState.found_pockets.keys())
	GameState.pockets_changed.connect(_on_pockets_changed)
	var stone_view := StonePiecesView.new()
	stone_view.name = "StonePieces"
	$WorldView/WorldViewport/World.add_child(stone_view)
	_stone_told = GameState.stone
	GameState.stone_changed.connect(_on_stone_changed)
	_rover.tilled_cell_used.connect(_on_tilled_cell_used)
	_hud.zero_steering_pressed.connect(_on_zero_pressed)
	_hud.slot_spool_pressed.connect(_on_slot_spool_pressed)
	_hud.enter_dome_pressed.connect(_go_to_dome)
	_airlock.clicked.connect(_go_to_dome)
	for prop: Inspectable in get_tree().get_nodes_in_group(Inspectable.GROUP):
		# Not the phone log: it keeps only a few lines, and prop clicks would
		# push dispatches and audits out of it.
		if prop.prop_id == SOIL_PROBE_PROP:
			# Ryan (2026-11-22): "both". The probe also reads out the plot.
			prop.inspected.connect(func(text: String) -> void:
				_show_inspect(text + " " + GameState.soil_probe_text()))
		else:
			prop.inspected.connect(_show_inspect)
	# Bound methods so the autoload drops them when this scene is freed.
	GameState.silk_changed.connect(_on_silk_changed)
	GameState.relay_changed.connect(_on_relay_changed)
	GameState.phone_message.connect(_hud.push_log)
	GameState.skill_leveled.connect(_on_skill_leveled)
	SaveGame.save_failed.connect(_hud.push_log)
	GameState.rover_place_changed.connect(_on_rover_place_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.ore_changed.connect(_on_ore_changed)
	GameState.credibility_changed.connect(_on_credibility_changed)
	_rover.ore_mined.connect(_on_ore_mined)
	_rover.boulder_hit.connect(_on_boulder_hit)
	_bram_bay.rover_entered.connect(_on_rover_entered_bay)
	_bram_bay.rover_exited.connect(_on_rover_exited_bay)
	_cal_pad.rover_entered.connect(_on_rover_entered_cal_pad)
	_tunnel_pad.rover_entered.connect(func() -> void: _hud.push_log("TUNNEL MOUTH: press E to enter."))
	_hud.trade_pressed.connect(_try_trade)
	_hud.buy_standard_pressed.connect(_try_buy_standard)
	_hud.accept_job_pressed.connect(_try_accept_job)
	GameState.jobs_changed.connect(_refresh_jobs_hud)
	# Buying or sending away a standard, or a band change, changes which
	# offers can be accepted.
	GameState.upgrades_changed.connect(_refresh_jobs_hud)
	GameState.oirm_changed.connect(_refresh_jobs_hud)
	GameState.credibility_changed.connect(_refresh_jobs_hud.unbind(1))

	# Replay the persistent phone log first, so fresh SYS lines land on top of it.
	for line: String in GameState.phone_log.slice(-LOG_REPLAY_LINES):
		_hud.push_log(line)
	var relay_name: String = _rover.satellite_relay.relay_name if _rover.satellite_relay else "NO RELAY"
	_hud.configure(relay_name, _rover.steering.mpe, _rover.steering.acceptance_ratio)
	_show_dug()
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	_hud.set_credits(GameState.credits)
	_hud.set_ore(GameState.crystal_ore)
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_text())
	_refresh_jobs_hud()
	_hud.get_parent().add_child(SkillsUI.new())
	_hud.get_parent().add_child(CoopUI.new())
	_say_if_away()
	_robots_ui = RobotsUI.new()
	_hud.get_parent().add_child(_robots_ui)


func _process(delta: float) -> void:
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	if _inspect_left > 0.0:
		_inspect_left -= delta
		return
	var hovered: Clickable = Clickable.hovered
	_hover_hint.text = hovered.hint if hovered else _rover.away_text()


func _show_inspect(text: String) -> void:
	_hover_hint.text = text
	_inspect_left = maxf(INSPECT_SECONDS, text.length() * INSPECT_SECONDS_PER_CHAR)


func _on_uplink_changed(has_los: bool, quality: float, lag_s: float) -> void:
	if _rover.away_text() != "":
		_hud.set_rover_away()
		return
	_hud.set_uplink(has_los, quality, lag_s)
	if _had_los != has_los:
		_hud.push_log("SYS: LOS %s" % ("restored" if has_los else "lost; uplink lag rising"))
	_had_los = has_los


func _on_drift_changed(drift_deg: float, band: int) -> void:
	_hud.set_drift(drift_deg, band)
	if band == DriftingSensor.Band.OUT_OF_TOLERANCE and _last_band != band:
		_hud.push_log("SYS: steering exceeds MPE ±%.2f°" % _rover.steering.mpe)
	_last_band = band


func _on_zero_pressed() -> void:
	if _rover.away_text() != "":
		_say_if_away()
		return
	_rover.queue_command(RoverController.Command.ZERO_STEERING)
	_hud.push_log("> ZERO STEERING sent (%d ms lag)" % roundi(_rover.get_current_lag() * 1000.0))


func _on_steering_zeroed(record: Dictionary) -> void:
	if record.get("refused", false):
		_hud.push_log("ZERO STEERING FAILED: %s" % record["reason"])
		return
	var schedule: String = ("No standard: not a calibration, still due day %d" % record.get("due_day", 0)
		if not record.get("traceable", true)
		else "Next due day %d (%d d)" % [record.get("due_day", 0), record.get("interval_days", 0)])
	_hud.push_log("As-found %s°  As-left %s°  %s" % [
		SP811.signed(record.get("as_found", 0.0)), SP811.signed(record.get("as_left", 0.0)), schedule])


func _on_slot_spool_pressed() -> void:
	var replaced: bool = GameState.relay_slotted
	if await FarmCommands.request(&"slot_spool_into_relay") and is_inside_tree():
		if FarmCommands.guest:
			# The relay itself may not have reached this copy yet.
			_hud.push_log("Silk spool installed.")
			return
		_hud.push_log("%s installed%s. Uplink lag × %s." % [
			"Damaged silk spool" if GameState.slotted_spool_damaged else "Optical silk spool",
			", the old one taken out" if replaced else "", SP811.number(GameState.get_relay_lag_multiplier(), 2)])


func _on_silk_changed(_spools: int) -> void:
	_refresh_relay_hud()


func _on_relay_changed(_slotted: bool) -> void:
	_refresh_relay_hud()
	_rover.broadcast_state()  # lag readout picks up the relay multiplier


func _refresh_relay_hud() -> void:
	_hud.set_relay(GameState.relay_slotted, GameState.slotted_spool_damaged, GameState.spool_count_text(), GameState.can_slot_spool())


func _on_soil_tilled(cell: Vector3i) -> void:
	_hud.push_log("Tilled cell (%s, %s). Space again plants %s (%s CR seed); C changes the seed, [ and ] its starting set point." % [
		SP811.integer(cell.x), SP811.integer(cell.z), GameState.crop_name(GameState.current_seed()),
		SP811.integer(GameState.seed_cost(GameState.current_seed()))])


## Space on tilled soil: harvest a ready crop, report a growing one, or plant.
func _on_tilled_cell_used(cell: Vector3i, seed_id: String, offset_steps: int) -> void:
	if GameState.is_crop_ready(cell):
		var entry: Dictionary = await FarmCommands.request(&"harvest_crop", [cell])
		if not is_inside_tree():
			return
		if not entry.has("crop_id"):
			_hud.push_log("HARVEST FAILED: %s" % entry.get("reason", "Nothing is ready here."))
			return
		var grade: String = ("in spec" if entry["in_spec"]
			else "OFF SPEC: the soil left its moisture band on %s days" % SP811.integer(entry["out_of_band_days"]))
		# A guest's copy of the bin may lag the host's.
		_hud.push_log("HARVESTED %s, %s.%s" % [GameState.crop_name(entry["crop_id"]), grade, "" if FarmCommands.guest
			else " Bin: %s crops for Lin at Bram's bay." % SP811.integer(GameState.harvest_bin.size())])
	elif GameState.plantings.has(cell):
		_hud.push_log(GameState.crop_status_text(cell) + ". [ and ] move the set point.")
	else:
		var problem: String = await FarmCommands.request(&"plant_crop", [cell, seed_id, offset_steps])
		if not is_inside_tree():
			return
		if problem.is_empty():
			# A guest may hear back before the planting reaches it.
			_hud.push_log("PLANTED " + (GameState.crop_status_text(cell) if GameState.plantings.has(cell)
				else GameState.crop_name(seed_id)))
		else:
			_hud.push_log("PLANT FAILED: " + problem)


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


func _on_dig_rejected(reason: String) -> void:
	_hud.push_log("DIG FAILED: %s" % reason)


func _on_fill_rejected(reason: String) -> void:
	_hud.push_log("FILL FAILED: %s" % reason)


func _on_blocks_changed() -> void:
	for cell: Vector2i in GameState.found_blocks:
		if not cell in _blocks_told:
			_blocks_told.append(cell)
			var block: Dictionary = ReferenceBlock.at(GameState.world_seed, cell)
			if not block.is_empty():
				_hud.push_log("FOUND A REFERENCE BLOCK: %s° angle, ±%s° (k = %s). Q checks a sensor with it." % [
					SP811.number(block["certified"], 0), SP811.number(block["u"], 2), SP811.number(block["k"], 0)])


func _on_pockets_changed() -> void:
	for cell: Vector2i in GameState.found_pockets:
		if not cell in _pockets_told:
			_pockets_told.append(cell)
			_hud.push_log("FOUND AN ORE POCKET: +%s crystal ore" % SP811.integer(OrePocket.ORE))


func _on_stone_changed() -> void:
	if GameState.stone > _stone_told:
		_hud.push_log("STONE +%d%s" % [GameState.stone - _stone_told,
				"" if FarmCommands.guest else " (%d)" % GameState.stone])
	_stone_told = GameState.stone


## N: the next kind of piece for B to build.
func _cycle_stone_kind() -> void:
	_stone_kind = StonePieces.next_kind(_stone_kind)
	_hud.push_log("STONE PIECE: %s (%d stone)" % [StonePieces.kind_name(_stone_kind), StonePieces.cost(_stone_kind)])


## B: builds the chosen piece on the cell in front of the stopped rover, or takes
## up the piece there.
func _place_stone() -> void:
	if _rover.away_text() != "":
		_say_if_away()
		return
	if not _rover.is_stopped():
		_hud.push_log("STONE: stop the rover first.")
		return
	var at: Vector2i = _rover.dig_cell()
	var taking: bool = GameState.stone_pieces.has(at)
	var kind: int = GameState.stone_pieces.get(at, _stone_kind)
	var problem: String = await FarmCommands.request(&"place_stone", [Vector3i(at.x, 0, at.y), _stone_kind])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("STONE REFUSED: %s" % problem)
	elif taking:
		_hud.push_log("TOOK UP A %s: +%d stone%s" % [StonePieces.kind_name(kind).to_upper(), StonePieces.cost(kind),
				"" if FarmCommands.guest else ", %d left" % GameState.stone])
	else:
		_hud.push_log("BUILT A %s: %d stone spent%s" % [StonePieces.kind_name(kind).to_upper(), StonePieces.cost(kind),
				"" if FarmCommands.guest else ", %d left" % GameState.stone])


## V: a survey from the standing rover reads a bearing to the nearest ore pocket.
func _survey() -> void:
	if _rover.away_text() != "":
		_say_if_away()
		return
	if not _rover.is_stopped():
		_hud.push_log("ORE SURVEY: stop the rover first.")
		return
	var record: Dictionary = await FarmCommands.request(&"survey_ore")
	if record.is_empty() or not is_inside_tree():
		return
	if not record.get("no_answer", false):
		_survey_line.forget()
	if record.get("refused", false):
		_hud.push_log("ORE SURVEY REFUSED: %s" % str(record["reason"]))
	elif not record["found"]:
		_hud.push_log("ORE SURVEY: no ore pocket within %s m" % SP811.number(OrePocket.RANGE_M, 0))
	else:
		_survey_line.show_bearing(Vector2(record["from"][0], record["from"][1]), record["bearing"])
		_hud.push_log("ORE SURVEY: %s° clockwise from north, up-right (±%s° if steering is in MPE)" % [
			SP811.number(record["bearing"], 1), SP811.number(record["mpe"], 1)])


## Q: puts the dish (at the relay) or the rover's steering encoder against a block.
func _check_with_block() -> void:
	if _rover.away_text() != "":
		_say_if_away()
		return
	if not _rover.is_stopped():
		_hud.push_log("BLOCK CHECK: stop the rover first.")
		return
	var at := Vector2(_rover.global_position.x, _rover.global_position.z)
	var id: String = DISH_ID if at.distance_to(Terrain.RELAY) <= DISH_REACH_M else GameState.STEERING_ID
	var record: Dictionary = await FarmCommands.request(&"check_with_block", [id])
	if record.is_empty() or not is_inside_tree():
		return
	if record.get("refused", false):
		_hud.push_log("BLOCK CHECK REFUSED: %s" % str(record["reason"]))
		return
	var sensor: DriftingSensor = GameState.get_sensor(id)
	var places: int = roundi(-log(maxf(sensor.resolution, 0.01)) / log(10.0))
	var verdict: String = {
		ReferenceBlock.VERDICT_WITHIN: "WITHIN MPE",
		ReferenceBlock.VERDICT_OUTSIDE: "OUTSIDE MPE",
	}.get(record["verdict"], "CAN'T TELL IF WITHIN MPE")
	_hud.push_log("BLOCK CHECK %s  Block %s°  Reads %s°  Error (%s ± %s)°  %s (MPE ±%s°)" % [
		GameState.instrument_name(id).to_upper(), SP811.number(record["certified"], 0),
		SP811.number(record["reading"], places), SP811.signed(record["error"], 2),
		SP811.number(record["error_u"], 2), verdict, SP811.number(record["mpe"], 2)])


func _show_dug() -> void:
	_rover.ground.show_dug(GameState.dug)
	_rover.keep_above_ground()


func _unhandled_input(event: InputEvent) -> void:
	var away: bool = _rover.away_text() != ""
	if away and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		SceneSwitcher.swap_to(SceneSwitcher.TUNNELS_SCENE)
	elif away and ROVER_KEYS.any(func(key: StringName) -> bool: return event.is_action_pressed(key)):
		get_viewport().set_input_as_handled()
		_say_if_away()
	elif event.is_action_pressed(&"interact") and _cal_pad.rover_inside:
		get_viewport().set_input_as_handled()
		_try_field_cal()
	elif event.is_action_pressed(&"interact") and _tunnel_pad.rover_inside:
		get_viewport().set_input_as_handled()
		_enter_tunnels()
	elif event.is_action_pressed(&"interact") and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_try_trade()
	elif _is_key(event, KEY_L) and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_sell_to_lin()
	elif _is_key(event, KEY_T) and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_robots_ui.open()
	elif event.is_action_pressed(&"rover_dig"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.DIG)
	elif event.is_action_pressed(&"rover_fill"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.FILL)
	elif _is_key(event, KEY_B):
		get_viewport().set_input_as_handled()
		_place_stone()
	elif _is_key(event, KEY_N):
		get_viewport().set_input_as_handled()
		_cycle_stone_kind()
	elif _is_key(event, KEY_Q):
		get_viewport().set_input_as_handled()
		_check_with_block()
	elif _is_key(event, KEY_V):
		get_viewport().set_input_as_handled()
		_survey()
	elif _is_key(event, KEY_C):
		get_viewport().set_input_as_handled()
		var seed: String = GameState.cycle_seed()
		_hud.push_log("SEED: %s, %s CR, %s days, soil moisture target %s %%" % [
			GameState.crop_name(seed), SP811.integer(GameState.seed_cost(seed)),
			SP811.integer(int(GameState.crop(seed).get("growth_days", 0))),
			SP811.number(float(GameState.crop(seed).get("soil_moisture_target", 0.0)) * 100.0, 0)])
	elif not away and (_is_key(event, KEY_BRACKETLEFT) or _is_key(event, KEY_BRACKETRIGHT)):
		var cell: Vector3i = _rover.cell_under()
		var step: int = -1 if _is_key(event, KEY_BRACKETLEFT) else 1
		get_viewport().set_input_as_handled()
		if GameState.plantings.has(cell):
			_adjust_setpoint(cell, step)
		else:
			GameState.adjust_planting_offset(step)
			_hud.push_log(GameState.planting_offset_text())
	elif event is InputEventKey and event.pressed and not event.echo and _bram_bay.rover_inside:
		# [1], [2], ... buy Bram's Tier 1 standards in catalog order.
		var index: int = (event as InputEventKey).physical_keycode - KEY_1
		var catalog: Array[String] = GameState.bram_catalog()
		if GameState.tier1_unlocked and index >= 0 and index < catalog.size():
			get_viewport().set_input_as_handled()
			_try_buy_standard(catalog[index])


func _adjust_setpoint(cell: Vector3i, step: int) -> void:
	var setpoint: float = await FarmCommands.request(&"adjust_setpoint", [cell, step])
	if not is_inside_tree():
		return
	if setpoint < 0.0:
		_hud.push_log("SET POINT NOT MOVED.")
	elif FarmCommands.guest:
		# The crop itself may not have reached this copy yet.
		_hud.push_log("Irrigation set point %s %%" % SP811.number(setpoint * 100.0, 0))
	else:
		_hud.push_log(GameState.crop_status_text(cell))


func _is_key(event: InputEvent, keycode: Key) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	# The key's label, or the character it typed: on German QWERTZ, [ and ]
	# are AltGr+8 and AltGr+9, whose keycode stays 8 and 9.
	return key.keycode == keycode or (key.unicode > 0
		and String.chr(key.unicode).to_upper().unicode_at(0) == keycode)


func _sell_to_lin() -> void:
	# A guest's copy of the bin may lag: the host says whether it is empty.
	if not FarmCommands.guest and GameState.harvest_bin.is_empty():
		_hud.push_log("LIN: Nothing in your bin. Bring me crops, and keep that spider away from my stall.")
		return
	var paid: int = await FarmCommands.request(&"sell_harvest_to_lin")
	if FarmCommands.guest and paid <= 0 and is_inside_tree():
		# 0 is also the answer when the host can't be reached.
		_hud.push_log("NOTHING SOLD.")


func _refresh_jobs_hud() -> void:
	var active: PackedStringArray = []
	for job: Dictionary in GameState.active_jobs:
		active.append(GameState.active_job_text(job))
	var offers: Array[Dictionary] = []
	for job: Dictionary in GameState.job_board:
		var problem: String = GameState.job_accept_problem(job)
		offers.append({ "text": GameState.job_offer_text(job) + (" (%s)" % problem if problem != "" else ""),
			"disabled": problem != "", "tooltip": problem })
	_hud.show_jobs(active, offers, GameState.job_board_note())


func _try_accept_job(index: int) -> void:
	var problem: String = await FarmCommands.request(&"accept_job", [index])
	if is_inside_tree() and problem != "":
		_hud.push_log("JOB NOT ACCEPTED: " + problem)


func _on_ore_mined(_fissure_id: StringName) -> void:
	_hud.push_log("Drilled 1 crystal ore." + ("" if FarmCommands.guest else " Carrying %d." % GameState.crystal_ore))


func _on_boulder_hit(hits: int) -> void:
	if hits < GameState.BOULDER_HITS:
		_hud.push_log("Boulder: %d of %d hits." % [hits, GameState.BOULDER_HITS])
	else:
		_hud.push_log("Boulder broken.")


func _on_credibility_changed(_points: int) -> void:
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_text())
	if _bram_bay.rover_inside:
		_refresh_bram()


func _on_skill_leveled(player_id: String, skill_id: String, _level: int) -> void:
	if player_id == "" or player_id == GameState.local_player_id:
		_hud.push_log("SKILL UP: %s. K shows skills." % GameState.skill_text(skill_id))


func _on_credits_changed(amount: int) -> void:
	_hud.set_credits(amount)
	if _bram_bay.rover_inside:
		_refresh_bram()


func _on_ore_changed(ore: int) -> void:
	_hud.set_ore(ore)
	if _bram_bay.rover_inside:
		_refresh_bram()


const NO_FIELD_STANDARD: String = "FIELD CAL PAD: no reference standard on the colony for the pad's instruments."


func _on_rover_entered_cal_pad() -> void:
	var offered: Array[String] = GameState.field_cal_ready()
	if offered.is_empty():
		_hud.push_log(NO_FIELD_STANDARD)
		return
	var names: PackedStringArray = []
	for id: String in offered:
		names.append(GameState.instrument_name(id).to_lower())
	var line: String = "FIELD CAL PAD: press E to calibrate %s." % " and ".join(names)
	if not GameState.is_in_service(GameState.TIRE_ID):
		line += " The tire gauge needs the WD-1 reference gauge. Bram sells it."
	_hud.push_log(line)


func _try_field_cal() -> void:
	if not _rover.is_stopped():
		_hud.push_log("FIELD CAL PAD: stop the rover on the pad first.")
		return
	var offered: Array[String] = GameState.field_cal_ready()
	if offered.is_empty():
		_hud.push_log(NO_FIELD_STANDARD)
		return
	for id: String in offered:
		# It may have driven off while the host answered.
		if not _cal_pad.rover_inside or not _rover.is_stopped():
			_hud.push_log("FIELD CAL PAD: stop the rover on the pad first.")
			return
		await _field_cal_one(id)
		if not is_inside_tree():
			return


func _field_cal_one(id: String) -> void:
	var sensor: DriftingSensor = GameState.get_sensor(id)
	var record: Dictionary = await FarmCommands.request(&"calibrate_at_bench", [id])
	if record.is_empty() or not is_inside_tree():
		return
	var label: String = GameState.instrument_name(id).to_upper()
	if record.get("refused", false):
		_hud.push_log("FIELD CAL %s REFUSED: %s" % [label, str(record["reason"])])
		return
	var verdict: String = ("NOT TRACEABLE (standard %s)" % record["standard_problem"] if record.get("standard_problem", "") != ""
		else str(record["result"]).to_upper())
	_hud.push_log("FIELD CAL %s %s  As-found %s  As-left %s  Due day %d  (%d min)" % [
		label, verdict, sensor.format_value(record["as_found"]), sensor.format_value(record["as_left"]),
		record["due_day"], roundi(record.get("bench_minutes", 0.0))])


func _on_rover_exited_bay() -> void:
	_armed_standard = ""
	_robots_ui.hide()
	_hud.hide_bram()


func _on_rover_entered_bay() -> void:
	_armed_standard = ""
	var cost: int = GameState.treads_ore_cost()
	if GameState.has_wide_treads:
		_bram_line = GameState.bram_line("greetings")
	elif GameState.crystal_ore >= cost:
		_bram_line = "That's %d crystal ore. Treads coming right up, hit trade." % cost
	else:
		_bram_line = "Bring me %d crystal ore and I'll bolt wider treads onto your tractor. Carrying %d." % [cost, GameState.crystal_ore]
	if not GameState.harvest_bin.is_empty():
		_hud.push_log("LIN: %s crops in your bin, %s CR for the lot. Press L to sell." % [
			SP811.integer(GameState.harvest_bin.size()), SP811.integer(GameState.harvest_bin_value())])
	if GameState.owned_standards.has("torque_standard") or not GameState.robots.is_empty():
		_hud.push_log("BRAM: robots are built here. Press T.")
	_refresh_bram()


func _refresh_bram() -> void:
	_hud.show_bram(_bram_line, GameState.treads_ore_cost(), GameState.crystal_ore, GameState.has_wide_treads)
	var offers: Array[Dictionary] = []
	if GameState.tier1_unlocked:
		var catalog: Array[String] = GameState.bram_catalog()
		for i: int in catalog.size():
			var id: String = catalog[i]
			var sensor: DriftingSensor = GameState.get_sensor(id)
			var owned: bool = GameState.owned_standards.has(id)
			var verb: String = "CONFIRM: BUY" if id == _armed_standard else "BUY"
			offers.append({
				"id": id,
				"text": ("%s: ON THE COLONY" % sensor.short_name.to_upper()) if owned
					else "%s %s: %s  [%d]" % [verb, sensor.short_name.to_upper(), GameState.standard_price_text(id).to_upper(), i + 1],
				"disabled": owned or GameState.credits < GameState.standard_price_credits(id) or GameState.crystal_ore < sensor.price_ore,
			})
	_hud.show_standards(offers, "" if GameState.tier1_unlocked else "Tier 1 standards: pass one audit clean and Bram will sell them.")


func _try_buy_standard(standard_id: String) -> void:
	if not _bram_bay.rover_inside:
		return
	var problem: String = GameState.standard_purchase_problem(standard_id)
	if problem.is_empty() and _armed_standard != standard_id:
		# First press: show the price and wait for a second press.
		_armed_standard = standard_id
		_bram_line = "The %s is %s. Press again to buy it." % [
			GameState.get_sensor(standard_id).short_name, GameState.standard_price_text(standard_id)]
		_refresh_bram()
		return
	_armed_standard = ""
	if problem.is_empty():
		problem = await FarmCommands.request(&"buy_standard", [standard_id])
		if not is_inside_tree() or not _bram_bay.rover_inside:
			return
	if problem.is_empty():
		_bram_line = "Handle it like it's worth more than your tractor. It nearly is."
	else:
		# Replace any "press again" prompt so it can't outlive the armed offer.
		_bram_line = problem
		_hud.push_log("BRAM: " + problem)
	_refresh_bram()


func _try_trade() -> void:
	if not _bram_bay.rover_inside or GameState.has_wide_treads:
		return
	_armed_standard = ""
	var problem: String = await FarmCommands.request(&"buy_wide_treads")
	if not is_inside_tree() or not _bram_bay.rover_inside:
		return
	if problem.is_empty():
		_bram_line = "Fresh treads, wide stance. Try not to till a boulder with them."
	else:
		_bram_line = problem
		_hud.push_log("BRAM: " + problem)
	_refresh_bram()


func _go_to_dome() -> void:
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)


## Says where the rover is if it is not here.
func _say_if_away() -> void:
	if _rover.away_text() != "":
		_hud.push_log(_rover.away_text())


## Takes the rover in and goes with it.
func _enter_tunnels() -> void:
	if _moving:
		return
	_moving = true
	var problem: String = await FarmCommands.request(&"move_rover", [true])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("TUNNEL MOUTH: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()


## A guest's copy of the farm may come after the host's yes.
func _on_rover_place_changed() -> void:
	if _move_granted and _rover.away_text() != "":
		_move_granted = false
		SceneSwitcher.go_to(SceneSwitcher.TUNNELS_SCENE)
	elif not _moving:
		_say_if_away()
