extends Node
## Composition root for the farm scene. Wires rover / GameState <-> HUD.
## Holds no gameplay rules of its own. Dispatches and audits come from
## GameState's phone log, so they survive scene swaps.

## Phone-log lines replayed into the HUD when the farm loads.
const LOG_REPLAY_LINES: int = 6
## A dig key press counts as this screen's own for this long, ms.
const OWN_DIG_MS: int = 3000
## With the rover in the other scene, these only say where it is.
const ROVER_KEYS: Array[StringName] = [
	&"rover_forward", &"rover_reverse", &"rover_till", &"rover_zero_steering", &"rover_dig", &"rover_fill"]
## On foot, these only say so.
const FARM_KEYS: Array[StringName] = [
	&"interact", &"rover_till", &"rover_zero_steering", &"rover_dig", &"rover_fill", &"swap_scene"]
## On foot, these verbs of the rover only say so.
const ON_FOOT_REFUSED: Array[StringName] = [
	&"place_stone", &"block_stack", &"sell_lin", &"stone_kind", &"check_block", &"open_robots", &"survey", &"wheel_service",
	&"buy_1", &"buy_2", &"buy_3", &"buy_4", &"buy_5", &"buy_6", &"buy_7", &"buy_8", &"buy_9"]
## Bram's standards, in catalog order.
const BUY_ACTIONS: Array[StringName] = [
	&"buy_1", &"buy_2", &"buy_3", &"buy_4", &"buy_5", &"buy_6", &"buy_7", &"buy_8", &"buy_9"]
## A clicked prop's text stays in the hover label this long, like the dome's toast.
const INSPECT_SECONDS: float = 3.0
## Long descriptions stay up longer.
const INSPECT_SECONDS_PER_CHAR: float = 0.04
## The prop whose inspect text also carries the plot's soil readings.
const SOIL_PROBE_PROP: String = "soil_moisture_probe"
const CISTERN_PROP: String = "water_cistern"
const WRING_SCENE: PackedScene = preload("res://ui/minigames/wring_the_blocks.tscn")
const SPOOL_SCENE: PackedScene = preload("res://ui/minigames/thread_the_spool.tscn")
const TORQUE_SCENE: PackedScene = preload("res://ui/minigames/torque_to_spec.tscn")

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
var _pieces_told: int = 0
var _stone_kind: int = StonePieces.WALL
var _last_band: int = DriftingSensor.Band.IN_BAND

@onready var _rover: RoverController = %Rover
@onready var _survey_line: SurveyLine = $WorldView/WorldViewport/World/SurveyLine
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _airlock: Clickable = %Airlock
@onready var _hover_hint: Label = %HoverHint
## The "[E] verb" label over what the interact key would use (VerbPrompt).
var _verb_prompt: VerbPrompt
@onready var _world_view: Control = $WorldView as Control
@onready var _world_camera: Camera3D = $WorldView/WorldViewport/World/IsoCamera as Camera3D
@onready var _bram_bay: BramBay = %BramBay
## Ryan, 2026-11-22: "Pad by the airlock". Park here and press E to calibrate
## the tire gauge against the WD-1 without going into the dome.
@onready var _cal_pad: ParkingPad = %FieldCalPad
@onready var _tunnel_pad: ParkingPad = %TunnelPad
## The farm notice board and the pad by it (NoticeBoard), built in _ready.
var _notice_pad: ParkingPad

var _robots_ui: RobotsUI
var _shuttle_ui: ShuttleUI
var _landing: LandingDressing
## Whether Bram's buttons were last drawn for the pad.
var _bram_pad: bool = false
## Wring the Blocks, made the first time J opens it.
var _wring_game: WringTheBlocks
var _spool_game: ThreadTheSpool
var _torque_game: TorqueToSpec
## Sum of the dug depths when last looked at, to tell a dig from a fill.
var _dug_depth: int = 0
## When this screen last pressed dig, so a snapshot or the other player's dig isn't ours.
var _dig_pressed_msec: int = -OWN_DIG_MS
var _walkers: FarmWalkers
var _bram_line: String = ""
## Seconds left showing a clicked prop's text in the hover label.
var _inspect_left: float = 0.0
## Ryan (2026-11-22): buying a standard takes two presses. The first press
## (key or button) arms the offer and shows the price; a second press on the
## same offer buys it. Leaving the bay or pressing another offer re-arms.
var _armed_standard: String = ""
## The zone the tunnel mouth leads to (data/zones.json).
const TUNNELS_ZONE: StringName = &"lava_tubes"

## This player asked to move the rover; the host said yes.
var _moving: bool = false
var _move_granted: bool = false
## The game day the soft-gate warning was shown on at the tunnel mouth (-1: not
## shown); E again that day goes in. Getting out of the rover or leaving the pad
## clears it, and so does a new day.
var _tunnel_warned_day: int = -1


## [PLACEHOLDER] What the interact key does at each spot, for the prompt over it.
const VERB_NOTICE: String = "Read notices"
const VERB_CAL_PAD: String = "Calibrate"
const VERB_TUNNEL: String = "Enter tunnels"
const VERB_TRADE: String = "Trade with Bram"
const VERB_TERMINAL: String = "Open terminal"
const VERB_ROVER: String = "Get in rover"
## [PLACEHOLDER] Height above a spot's ground the prompt floats at, metres.
const VERB_HEIGHT_M: float = 2.2
## [PLACEHOLDER] The hint line at the foot of the world view: its font size (set here only).
const HINT_FONT_SIZE: int = 30
## [PLACEHOLDER] How far up from the bottom of the world view the hint line reaches, px;
## the verb prompt keeps clear of it.
const HINT_CLEAR_PX: float = 90.0


func _ready() -> void:
	_build_notice_board()
	_setup_hint_and_prompt()
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.soil_tilled.connect(_on_soil_tilled)
	_rover.till_rejected.connect(_on_till_rejected)
	_rover.dig_rejected.connect(_on_dig_rejected)
	_rover.fill_rejected.connect(_on_fill_rejected)
	GameState.terrain_changed.connect(_show_dug)
	GameState.terrain_changed.connect(_say_dug)
	_dug_depth = _total_dug()
	_blocks_told.assign(GameState.found_blocks.keys())
	GameState.blocks_changed.connect(_on_blocks_changed)
	_pockets_told.assign(GameState.found_pockets.keys())
	GameState.pockets_changed.connect(_on_pockets_changed)
	var pit_water := PitWaterView.new()
	pit_water.name = "PitWater"
	pit_water.changed.connect(_rover.leave_deep_water)
	$WorldView/WorldViewport/World.add_child(pit_water)
	$WorldView/WorldViewport/World.add_child(BiomeMarkers.new())
	$WorldView/WorldViewport/World.add_child(RoadLamps.new())
	$WorldView/WorldViewport/World.add_child(BasaltDressing.new())
	$WorldView/WorldViewport/World.add_child(FrostDressing.new())
	var landing := LandingDressing.new()
	$WorldView/WorldViewport/World.add_child(landing)
	var stone_view := StonePiecesView.new()
	stone_view.name = "StonePieces"
	$WorldView/WorldViewport/World.add_child(stone_view)
	_stone_told = GameState.stone
	_pieces_told = GameState.stone_pieces.size()
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
			prop.inspected.connect(_read_probe)
		elif prop.prop_id == CISTERN_PROP:
			prop.inspected.connect(func(text: String) -> void:
				_show_inspect(text + " " + GameState.cistern_text()))
		else:
			prop.inspected.connect(_show_inspect)
	# Bound methods so the autoload drops them when this scene is freed.
	GameState.silk_changed.connect(_on_silk_changed)
	GameState.relay_changed.connect(_on_relay_changed)
	GameState.phone_message.connect(_hud.push_log)
	GameState.skill_leveled.connect(_on_skill_leveled)
	SaveGame.save_failed.connect(_hud.push_log)
	SaveGame.saved.connect(_hud.push_log.bind("Saved."))
	GameState.rover_place_changed.connect(_on_rover_place_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.one_use_changed.connect(_on_one_use_changed)
	GameState.ore_changed.connect(_on_ore_changed)
	GameState.credibility_changed.connect(_on_credibility_changed)
	GameState.lab_xp_changed.connect(_on_credibility_changed.bind(0))
	GameState.lifts_changed.connect(_on_credibility_changed.bind(0))
	_rover.ore_mined.connect(_on_ore_mined)
	_rover.boulder_hit.connect(_on_boulder_hit)
	_bram_bay.rover_entered.connect(_on_rover_entered_bay)
	_bram_bay.rover_exited.connect(_on_rover_exited_bay)
	_cal_pad.rover_entered.connect(_on_rover_entered_cal_pad)
	_tunnel_pad.rover_entered.connect(func() -> void: _hud.push_log("TUNNEL MOUTH: press " + Controls.prompt(&"interact") + " to enter."))
	_tunnel_pad.rover_exited.connect(func() -> void: _tunnel_warned_day = -1)
	_notice_pad.rover_entered.connect(func() -> void: _hud.push_log("FARM NOTICE BOARD: press " + Controls.prompt(&"interact") + " to read it."))
	_hud.trade_pressed.connect(_try_trade)
	_hud.wheel_service_pressed.connect(_try_wheel_service)
	GameState.wheels_changed.connect(_on_wheels_changed)
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
	# Once per game run, and not saved: a line that points to the controls guide.
	Controls.tell_once(_hud)
	var relay_name: String = _rover.satellite_relay.relay_name if _rover.satellite_relay else "NO RELAY"
	_hud.configure(relay_name, _rover.steering.mpe, _rover.steering.acceptance_ratio)
	_walkers = FarmWalkers.new()
	_walkers.rover = _rover
	_walkers.camera = $WorldView/WorldViewport/World/IsoCamera
	$WorldView/WorldViewport/World.add_child(_walkers)
	pit_water.changed.connect(_walkers.leave_deep_water)
	_show_dug()
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	_hud.set_credits(GameState.credits)
	_hud.set_ore(GameState.crystal_ore)
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_phone_text(), GameState.lab_phone_text())
	_hud.set_gauge_set(GaugeSet.text(GameState.gauge_pieces()))
	_refresh_jobs_hud()
	var pause := PauseUI.new()
	_hud.get_parent().add_child(pause)
	_hud.get_parent().move_child(pause, 0)
	_hud.get_parent().add_child(SkillsUI.new())
	_hud.get_parent().add_child(ControlsGuideUI.new())
	_hud.get_parent().add_child(QuestsUI.new())
	_hud.get_parent().add_child(CoopUI.new())
	_hud.get_parent().add_child(ActionsMenuUI.new(ActionsMenuUI.farm_actions()))
	_say_if_away()
	_shuttle_ui = ShuttleUI.new()
	_hud.get_parent().add_child(_shuttle_ui)
	_landing = landing
	landing.terminal_click.clicked.connect(_open_shuttle_terminal)
	landing.terminal_click.verb = VERB_TERMINAL
	_robots_ui = RobotsUI.new()
	_hud.get_parent().add_child(_robots_ui)


## The hint line is centred, bigger and in Scope ink; the verb prompt floats over the target.
func _setup_hint_and_prompt() -> void:
	_hover_hint.add_theme_color_override(&"font_color", ScopeTheme.INK)
	_hover_hint.add_theme_color_override(&"font_outline_color", ScopeTheme.SHADOW)
	_hover_hint.add_theme_font_size_override(&"font_size", HINT_FONT_SIZE)
	_cal_pad.verb = VERB_CAL_PAD
	_tunnel_pad.verb = VERB_TUNNEL
	_bram_bay.verb = VERB_TRADE
	_notice_pad.verb = VERB_NOTICE
	_verb_prompt = VerbPrompt.new()
	_verb_prompt.floor_px = HINT_CLEAR_PX
	_hover_hint.get_parent().add_child(_verb_prompt)


## What the interact key would do for the local player now, as {at, verb, action}
## (at = where in the world to mark), or {} when nothing is in reach. The order is
## the one _unhandled_input answers in, so the prompt never promises another verb.
func verb_target() -> Dictionary:
	if _terminal_in_reach():
		return {"at": _landing.terminal_click.global_position, "verb": VerbPrompt.verb_of(_landing.terminal_click), "action": &"interact"}
	if CoopWalkers.on_foot():
		if _walkers != null and _walkers.rover_in_reach():
			return {"at": _rover.global_position, "verb": VERB_ROVER, "action": &"get_out_in"}
		return {}
	if GameState.rover_is_away(_rover.rover_id):
		return {}
	# Each spot only when pressing the key there would do its verb (not be refused).
	var pad: ParkingPad = null
	if _notice_pad.rover_inside:
		pad = _notice_pad
	elif _cal_pad.rover_inside:
		pad = _cal_pad if _rover.is_stopped() and not GameState.field_cal_ready().is_empty() else null
	elif _tunnel_pad.rover_inside:
		pad = _tunnel_pad if _tunnel_open() else null
	elif _bram_bay.rover_inside:
		pad = _bram_bay if not GameState.has_wide_treads else null
	if pad == null:
		return {}
	return {"at": pad.global_position, "verb": VerbPrompt.verb_of(pad), "action": &"interact"}


## True when the tunnel mouth would take the rover: open, and no one else drives.
func _tunnel_open() -> bool:
	return not _moving and not TunnelRecall.closed(GameClock.elapsed_days) 			and CoopRovers.driver(GameState.rover_here()) in ["", GameState.local_player_id]


## Puts the verb prompt over the target, or hides it.
func _update_verb_prompt() -> void:
	var camera: Camera3D = _world_camera
	var view: Control = _world_view
	var target: Dictionary = verb_target()
	if target.is_empty() or camera == null:
		_verb_prompt.clear()
		return
	var at: Vector3 = (target["at"] as Vector3) + Vector3(0.0, VERB_HEIGHT_M, 0.0)
	if camera.is_position_behind(at):
		_verb_prompt.clear()
		return
	_verb_prompt.limit = view.size
	_verb_prompt.point_at(view.position + camera.unproject_position(at), String(target["verb"]), target["action"] as StringName)


func _process(delta: float) -> void:
	# After every node's _process (the camera moves in its own), so the label is
	# placed with this frame's view.
	_update_verb_prompt.call_deferred()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	# Bram's number tags follow the device in use.
	if _bram_bay.rover_inside and Controls.shown_pad() != _bram_pad:
		_refresh_bram()
	if _inspect_left > 0.0:
		_inspect_left -= delta
		return
	var hovered: Clickable = Clickable.hovered
	if hovered:
		_hover_hint.text = hovered.hint
		return
	var lines: PackedStringArray = []
	for line: String in [_rover.away_text(), _walkers.hint(), _terminal_prompt()]:
		if line != "":
			lines.append(line)
	_hover_hint.text = "  ·  ".join(lines)


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
	if _refuse_on_foot():
		return
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


## Seats a spool in the relay. While an open quest step carries Thread the
## Spool for this player (quests design section 7.4), the game is played first.
## The host seats the same spool whatever the score: a skip, the game switched
## off and a poor try all send the same seat. The host refuses a seat for a
## player on foot or with no spool to seat, and both are checked here before
## the game opens. Unlike a block stack, it seats a spool with the rover away
## or moving, so the plain seat asks for neither.
func _on_slot_spool_pressed() -> void:
	if _refuse_on_foot():
		return
	if _spool_game != null and _spool_game.is_playing():
		return
	var arguments: Array = []
	var seat: String = ""
	var due: bool = QuestEngine.has_minigame_step(GameState, MinigameScore.THREAD_THE_SPOOL, "", GameState.local_player_id)
	if due and GameState.can_slot_spool() and MinigameSettings.mode() != MinigameSettings.Mode.OFF:
		# The game takes the rover's controls for its 8 s: a rover that is here
		# and rolling is stopped first, as for Wring the Blocks.
		if _rover.away_text() == "" and not _rover.is_stopped():
			_hud.push_log("SILK SPOOL: stop the rover first.")
			return
		if _spool_game == null:
			_spool_game = SPOOL_SCENE.instantiate()
			_hud.get_parent().add_child(_spool_game)
		var was_blocked: bool = RoverController.input_blocked
		RoverController.input_blocked = true
		# The clock is in the seed: the next spool does not sway the same way.
		var motion_seed: int = hash([GameState.optical_silk_spools, Time.get_ticks_usec()])
		var share: float = MinigameScore.sweet_share(GameState, GameState.local_player_id, MinigameScore.THREAD_SKILL)
		_spool_game.play(share, MinigameSettings.mode(), motion_seed, "The relay's slot")
		var score: int = await _spool_game.finished
		RoverController.input_blocked = was_blocked
		if not is_inside_tree():
			return
		if score >= 0:
			# With no game played nothing more is sent: the seat is as it always was.
			arguments = [score]
			seat = " " + MinigameScore.seat_text(score)
	var replaced: bool = GameState.relay_slotted
	if await FarmCommands.request(&"slot_spool_into_relay", arguments) and is_inside_tree():
		if FarmCommands.guest:
			# The relay itself may not have reached this copy yet.
			_hud.push_log("Silk spool installed.%s" % seat)
			return
		_hud.push_log("%s installed%s. Uplink lag × %s.%s" % [
			"Damaged silk spool" if GameState.slotted_spool_damaged else "Optical silk spool",
			", the old one taken out" if replaced else "", SP811.number(GameState.get_relay_lag_multiplier(), 2), seat])


func _on_silk_changed(_spools: int) -> void:
	_refresh_relay_hud()


func _on_relay_changed(_slotted: bool) -> void:
	_refresh_relay_hud()
	_rover.broadcast_state()  # lag readout picks up the relay multiplier


func _refresh_relay_hud() -> void:
	_hud.set_relay(GameState.relay_slotted, GameState.slotted_spool_damaged, GameState.spool_count_text(), GameState.can_slot_spool())


func _on_soil_tilled(cell: Vector3i) -> void:
	_hud.push_log("Tilled cell (%s, %s). %s again plants %s (%s CR seed); %s changes the seed, %s and %s its starting set point." % [
		SP811.integer(cell.x), SP811.integer(cell.z), Controls.prompt(&"rover_till"), GameState.crop_name(GameState.current_seed()),
		SP811.integer(GameState.seed_cost(GameState.current_seed())), Controls.prompt(&"cycle_seed"),
		Controls.prompt(&"setpoint_down"), Controls.prompt(&"setpoint_up")])


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
		_hud.push_log(GameState.crop_status_text(cell) + ". %s and %s move the set point." % [Controls.prompt(&"setpoint_down"), Controls.prompt(&"setpoint_up")])
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
	_hud.push_log("DIG FAILED: %s" % reason + (" Dig on the hills outside." if reason == RoverController.ROCK_REFUSAL else ""))


func _on_fill_rejected(reason: String) -> void:
	_hud.push_log("FILL FAILED: %s" % reason)


const GAUGE_KIND_TEXT: Dictionary = {
	GaugeSet.NEW: "a new size for the set",
	GaugeSet.BETTER: "it improves the set",
	GaugeSet.DUPLICATE: "a duplicate, kept as a spare",
}


## More new blocks than this at once are summed up in one log line.
const BLOCKS_TOLD_ONE_BY_ONE: int = 3


func _on_blocks_changed() -> void:
	var fresh: Array[Vector2i] = []
	for cell: Vector2i in GameState.found_blocks:
		if not cell in _blocks_told:
			fresh.append(cell)
	if fresh.size() > BLOCKS_TOLD_ONE_BY_ONE:
		# A farm that arrived all at once (a load or a join): one line, not a
		# line and three set placements per block.
		_hud.push_log("%d REFERENCE BLOCKS ON RECORD." % fresh.size())
		_blocks_told.append_array(fresh)
		fresh.clear()
	for cell: Vector2i in fresh:
		var block: Dictionary = ReferenceBlock.at(GameState.world_seed, cell)
		if not block.is_empty():
			var kind: StringName = GaugeSet.finding(GameState.world_seed, _blocks_told, block)
			_hud.push_log("FOUND A REFERENCE BLOCK: %s° angle, ±%s° (k = %s). %s checks a sensor with it." % [
				SP811.number(block["certified"], 0), SP811.number(block["u"], 2), SP811.number(block["k"], 0), Controls.prompt(&"check_block")])
			var told: Array = []
			told.assign(_blocks_told)
			told.append(cell)
			var took: int = GaugeSet.size_taken(GameState.world_seed, told, cell)
			_hud.push_log("GAUGE BLOCK %s in, grade %s: %s." % [SP811.number(GaugeSet.size_in(took), 4),
					GaugeSet.GRADES[block["grade"]], GAUGE_KIND_TEXT[kind]])
		_blocks_told.append(cell)
	_hud.set_gauge_set(GaugeSet.text(GameState.gauge_pieces()))


func _on_pockets_changed() -> void:
	for cell: Vector2i in GameState.found_pockets:
		if not cell in _pockets_told:
			_pockets_told.append(cell)
			_hud.push_log("FOUND AN ORE POCKET: +%s crystal ore" % SP811.integer(OrePocket.ORE))


func _on_stone_changed() -> void:
	# Taking a piece up has its own line.
	if GameState.stone > _stone_told and GameState.stone_pieces.size() >= _pieces_told:
		_hud.push_log("STONE +%d%s" % [GameState.stone - _stone_told,
				"" if FarmCommands.guest else " (%d)" % GameState.stone])
	_stone_told = GameState.stone
	_pieces_told = GameState.stone_pieces.size()


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
	var problem: String = await FarmCommands.request(&"place_stone", [Vector3i(at.x, 0, at.y), StonePieces.TAKE_UP if taking else _stone_kind])
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


## J: wrings a stack of gauge blocks to a length (Wring the Blocks, quests
## design section 7.1). The host builds it whatever the score: a skip, the
## game switched off and a poor try all send the same build.
func _build_block_stack() -> void:
	if _wring_game != null and _wring_game.is_playing():
		return
	if _rover.away_text() != "":
		_say_if_away()
		return
	if not _rover.is_stopped():
		_hud.push_log("BLOCK STACK: stop the rover first.")
		return
	var stack: Dictionary = GameState.block_stack_target(GameState.local_player_id)
	if stack.is_empty():
		_hud.push_log("BLOCK STACK: a stack takes two gauge blocks. Dig for more.")
		return
	var score: int = MinigameScore.SKIPPED
	if MinigameSettings.mode() != MinigameSettings.Mode.OFF:
		if _wring_game == null:
			_wring_game = WRING_SCENE.instantiate()
			_hud.get_parent().add_child(_wring_game)
		var was_blocked: bool = RoverController.input_blocked
		RoverController.input_blocked = true
		# The clock is in the seed: the same length again is not the same slide.
		var motion_seed: int = hash([int(stack["target"]), Time.get_ticks_usec()])
		var share: float = MinigameScore.sweet_share(GameState, GameState.local_player_id, MinigameScore.WRING_SKILL)
		_wring_game.play(share, MinigameSettings.mode(), motion_seed, stack, "Orin's length: %s" % GaugeStack.length_text(int(stack["target"])))
		score = await _wring_game.finished
		RoverController.input_blocked = was_blocked
		if not is_inside_tree():
			return
	# The length played goes with the score: the host builds today's, and counts
	# no score earned on another (the day can turn at 06:00 mid-game).
	var record: Dictionary = await FarmCommands.request(&"build_block_stack", [int(stack["target"]), score])
	if record.is_empty() or not is_inside_tree():
		return
	if record.get("refused", false):
		_hud.push_log("BLOCK STACK REFUSED: %s" % str(record["reason"]))
		return
	if record.get("changed", false):
		_hud.push_log("BLOCK STACK: the length asked for changed while you worked. %s was built from %s blocks, and the try is not graded." % [
			GaugeStack.length_text(int(record["target"])), SP811.integer((record["sizes"] as Array).size())])
		return
	var graded: String = MinigameScore.grade_text(WringTheBlocks.GAME_NAME, int(record["score"]))
	if graded == "" and score >= 0:
		# No open ask of Orin's carries the game: the host kept no score.
		graded = MinigameScore.grade_text(WringTheBlocks.GAME_NAME, score) + " Practice: nothing is kept."
	_hud.push_log("BLOCK STACK: %s from %s blocks.%s" % [
		GaugeStack.length_text(int(record["target"])), SP811.integer((record["sizes"] as Array).size()),
		"" if graded == "" else " " + graded])


## Digging that finds nothing used to be silent. Blocks and ore pockets are
## announced by their own lines, which follow this one.
func _say_dug() -> void:
	var total: int = _total_dug()
	var own: bool = Time.get_ticks_msec() - _dig_pressed_msec < OWN_DIG_MS
	if total > _dug_depth and own:
		_dig_pressed_msec = -OWN_DIG_MS
		_hud.push_log("Dug. " + Controls.prompt(&"rover_fill") + " fills it again.")
	_dug_depth = total


func _total_dug() -> int:
	var total: int = 0
	for depth: int in GameState.dug.values():
		total += depth
	return total


func _show_dug() -> void:
	_rover.ground.show_dug(GameState.dug)
	_rover.keep_above_ground()
	if _walkers != null:
		_walkers.keep_above_ground()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"rover_dig") and not RoverController.input_blocked and not (is_inside_tree() and get_tree().paused):
		_dig_pressed_msec = Time.get_ticks_msec()


## A line for someone within reach of the shuttle terminal who is not pointing at it
## (a controller has no pointer): the key that opens it.
func _terminal_prompt() -> String:
	if not _terminal_in_reach():
		return ""
	return "Shuttle terminal: press %s." % Controls.prompt(&"interact")


## True when the terminal stands clear (not under stone) and the local player is within reach of it.
func _terminal_in_reach() -> bool:
	return (_shuttle_ui != null and _landing != null and _landing.terminal_click != null and _landing.terminal_click.enabled
			and Shuttle.terminal_near(GameState.standing_at(GameState.local_player_id)))


## Opens the shuttle terminal's panel, or says to walk up to it.
func _open_shuttle_terminal() -> void:
	if _terminal_in_reach():
		_shuttle_ui.open()
	else:
		_hud.push_log("SHUTTLE TERMINAL: " + Shuttle.text("far_text"))


func _unhandled_input(event: InputEvent) -> void:
	# Debug builds only: F8 paints the ground by biome (biomes.md section 6, step 4).
	# Caught here, outside the world viewport, and handed to the ground.
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		_rover.ground.show_biomes(not _rover.ground.is_showing_biomes())
		return
	var away: bool = _rover.away_text() != ""
	if event.is_action_pressed(&"get_out_in"):
		get_viewport().set_input_as_handled()
		_get_out_or_in()
	elif event.is_action_pressed(&"interact") and _terminal_in_reach():
		# At the landing pad's terminal, on foot or in the rover: the same key as the
		# dome's console, handled before the on-foot refusal below.
		get_viewport().set_input_as_handled()
		_open_shuttle_terminal()
	elif CoopWalkers.on_foot():
		if (FARM_KEYS.any(func(key: StringName) -> bool: return event.is_action_pressed(key))
				or ON_FOOT_REFUSED.any(func(key: StringName) -> bool: return event.is_action_pressed(key))):
			get_viewport().set_input_as_handled()
			_refuse_on_foot()
	elif away and event.is_action_pressed(&"interact"):
		# The rover is already in the tunnels: joining it is no new trip, so no
		# soft-gate warning here (it was given, or skipped, when it went in).
		# Shut after the rescue hour all the same: the dome's door says no then too.
		get_viewport().set_input_as_handled()
		if TunnelRecall.closed(GameClock.elapsed_days):
			_hud.push_log("TUNNEL MOUTH: " + TunnelRecall.text("closed_text"))
		else:
			SceneSwitcher.swap_to(SceneSwitcher.TUNNELS_SCENE)
	elif away and not event is InputEventJoypadMotion and ROVER_KEYS.any(func(key: StringName) -> bool: return event.is_action_pressed(key)):
		get_viewport().set_input_as_handled()
		_say_if_away()
	elif event.is_action_pressed(&"interact") and _notice_pad.rover_inside:
		get_viewport().set_input_as_handled()
		_read_notice_board()
	elif event.is_action_pressed(&"interact") and _cal_pad.rover_inside:
		get_viewport().set_input_as_handled()
		_try_field_cal()
	elif event.is_action_pressed(&"interact") and _tunnel_pad.rover_inside:
		get_viewport().set_input_as_handled()
		_enter_tunnels()
	elif event.is_action_pressed(&"interact") and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_try_trade()
	elif event.is_action_pressed(&"sell_lin") and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_sell_to_lin()
	elif event.is_action_pressed(&"wheel_service") and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_try_wheel_service()
	elif event.is_action_pressed(&"open_robots") and _bram_bay.rover_inside and not QuestsUI.other_panel_open(get_tree(), _robots_ui):
		get_viewport().set_input_as_handled()
		_robots_ui.open()
	elif event.is_action_pressed(&"rover_dig"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.DIG)
	elif event.is_action_pressed(&"rover_fill"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.FILL)
	elif event.is_action_pressed(&"place_stone"):
		get_viewport().set_input_as_handled()
		_place_stone()
	elif event.is_action_pressed(&"stone_kind"):
		get_viewport().set_input_as_handled()
		_cycle_stone_kind()
	elif event.is_action_pressed(&"check_block"):
		get_viewport().set_input_as_handled()
		_check_with_block()
	elif event.is_action_pressed(&"block_stack"):
		get_viewport().set_input_as_handled()
		_build_block_stack()
	elif event.is_action_pressed(&"survey"):
		get_viewport().set_input_as_handled()
		_survey()
	elif event.is_action_pressed(&"cycle_seed"):
		get_viewport().set_input_as_handled()
		var seed: String = GameState.cycle_seed()
		_hud.push_log("SEED: %s, %s CR, %s days, soil moisture target %s %%" % [
			GameState.crop_name(seed), SP811.integer(GameState.seed_cost(seed)),
			SP811.integer(int(GameState.crop(seed).get("growth_days", 0))),
			SP811.number(float(GameState.crop(seed).get("soil_moisture_target", 0.0)) * 100.0, 0)])
	elif not away and _setpoint_step(event) != 0:
		get_viewport().set_input_as_handled()
		if event is InputEventJoypadButton:
			_pad_setpoint(_setpoint_step(event))
		else:
			_step_setpoint(_setpoint_step(event))
	elif _bram_bay.rover_inside and _buy_index(event) >= 0:
		# [1], [2], ... buy Bram's Tier 1 standards in catalog order.
		var index: int = _buy_index(event)
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


## LB and RB together open the actions menu, so a shoulder press waits a moment
## and gives way if the menu opened.
func _pad_setpoint(step: int) -> void:
	var token: int = ActionsMenuUI.chord_token
	await get_tree().create_timer(ActionsMenuUI.NUDGE_WAIT_S).timeout
	# Overtaken by the menu, or the situation changed.
	if (is_inside_tree() and token == ActionsMenuUI.chord_token and not QuestsUI.other_panel_open(get_tree())
			and not CoopWalkers.on_foot() and _rover.away_text() == ""):
		_step_setpoint(step)


func _step_setpoint(step: int) -> void:
	var cell: Vector3i = _rover.cell_under()
	if GameState.plantings.has(cell):
		_adjust_setpoint(cell, step)
	else:
		GameState.adjust_planting_offset(step)
		_hud.push_log(GameState.planting_offset_text())


## -1 for set point down ([ or LB), 1 for up (] or RB), else 0.
func _setpoint_step(event: InputEvent) -> int:
	if event.is_action_pressed(&"setpoint_down") or _is_key(event, KEY_BRACKETLEFT):
		return -1
	if event.is_action_pressed(&"setpoint_up") or _is_key(event, KEY_BRACKETRIGHT):
		return 1
	return 0


## Which of Bram's standards a press buys: 0 for [1], and so on; -1 for no buy press.
func _buy_index(event: InputEvent) -> int:
	for i: int in BUY_ACTIONS.size():
		if event.is_action_pressed(BUY_ACTIONS[i]):
			return i
	return -1


## Only for the brackets: on German QWERTZ they are AltGr+8 and AltGr+9, which
## the keys' own actions don't see.
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
	if _refuse_on_foot():
		return
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
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_phone_text(), GameState.lab_phone_text())
	if _bram_bay.rover_inside:
		_refresh_bram()


func _on_skill_leveled(player_id: String, skill_id: String, _level: int) -> void:
	if player_id == "" or player_id == GameState.local_player_id:
		_hud.push_log("SKILL UP: %s. %s shows skills." % [GameState.skill_text(skill_id), Controls.prompt(&"open_skills")])


func _on_credits_changed(amount: int) -> void:
	_hud.set_credits(amount)
	if _bram_bay.rover_inside:
		_refresh_bram()


## Bram's price shows the discount while one is held.
func _on_one_use_changed() -> void:
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
	var line: String = "FIELD CAL PAD: press " + Controls.prompt(&"interact") + " to calibrate %s." % " and ".join(names)
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
		_hud.push_log("LIN: %s crops in your bin, %s CR for the lot. Press %s to sell." % [
			SP811.integer(GameState.harvest_bin.size()), SP811.integer(GameState.harvest_bin_value()), Controls.prompt(&"sell_lin")])
	if GameState.owned_standards.has("torque_standard") or not GameState.robots.is_empty():
		_hud.push_log("BRAM: robots are built here. Press " + Controls.prompt(&"open_robots") + ".")
	if GameState.wheels_due():
		_hud.push_log("BRAM: wheel nuts are due a re-torque. Press " + Controls.prompt(&"wheel_service") + ".")
	_refresh_bram()


## The number key's tag on one of Bram's buttons: "  [3]" on the keyboard, nothing
## on a pad (its buttons would grow, and the actions menu lists the buys).
func _buy_tag(index: int) -> String:
	if Controls.shown_pad():
		return ""
	return "  [%s]" % Controls.key_label(ActionsMenuUI.BUY_ACTIONS[index])


func _refresh_bram() -> void:
	_bram_pad = Controls.shown_pad()
	_hud.show_bram(_bram_line, GameState.treads_ore_cost(), GameState.crystal_ore, GameState.has_wide_treads)
	_hud.show_wheel_service(GameState.wheel_service_text(), GameState.wheels_due())
	var offers: Array[Dictionary] = []
	if GameState.tier1_unlocked:
		var catalog: Array[String] = GameState.bram_catalog()
		for i: int in catalog.size():
			var id: String = catalog[i]
			var sensor: DriftingSensor = GameState.get_sensor(id)
			var owned: bool = GameState.owned_standards.has(id)
			var verb: String = "CONFIRM: BUY" if id == _armed_standard else "BUY"
			# Shut by its tier (a lab level, or what the tier has always asked):
			# the line says so, and the number key gives Bram's full reason.
			var gate: String = "" if owned else GameState.tier_lab_note(id)
			if gate == "" and not owned and GameState.tier_problem(id) != "":
				gate = "not open yet"
			var text: String = "%s %s: %s%s" % [verb, sensor.short_name.to_upper(), GameState.standard_price_text(id).to_upper(), _buy_tag(i)]
			if owned:
				text = "%s: ON THE COLONY" % sensor.short_name.to_upper()
			elif gate != "":
				text = "%s: %s%s" % [sensor.short_name.to_upper(), gate.to_upper(), _buy_tag(i)]
			offers.append({
				"id": id,
				"text": text,
				"disabled": owned or gate != "" or GameState.credits < GameState.standard_price_credits(id) or GameState.crystal_ore < sensor.price_ore,
			})
	_hud.show_standards(offers, "" if GameState.tier1_unlocked else "Tier 1 standards: pass one audit clean and Bram will sell them.")


func _try_buy_standard(standard_id: String) -> void:
	if _refuse_on_foot():
		return
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
	if _refuse_on_foot():
		return
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


## Bram re-torques the wheel nuts: one press, and only when they are due. While
## this player has an open quest step that carries Torque to Spec, the player
## does the five nuts first; the service is the same whatever the score.
func _try_wheel_service() -> void:
	if _refuse_on_foot():
		return
	if not _bram_bay.rover_inside:
		return
	if _torque_game != null and _torque_game.is_playing():
		return
	_armed_standard = ""
	var arguments: Array = []
	var torque: String = ""
	var due: bool = QuestEngine.has_minigame_step(GameState, MinigameScore.TORQUE_TO_SPEC, "", GameState.local_player_id)
	if due and GameState.wheels_due() and not GameState.rover_lent and MinigameSettings.mode() != MinigameSettings.Mode.OFF:
		# The game takes the rover's controls: a rover that is rolling through
		# the bay is stopped first, as for Thread the Spool.
		if _rover.away_text() == "" and not _rover.is_stopped():
			_bram_line = "Stop the rover first."
			_hud.push_log("BRAM: Stop the rover first.")
			_refresh_bram()
			return
		if _torque_game == null:
			_torque_game = TORQUE_SCENE.instantiate()
			_hud.get_parent().add_child(_torque_game)
		var was_blocked: bool = RoverController.input_blocked
		RoverController.input_blocked = true
		# The clock is in the seed: the next service's nuts do not click the same.
		var motion_seed: int = hash([roundi(GameState.wheel_meters), Time.get_ticks_usec()])
		var share: float = MinigameScore.sweet_share(GameState, GameState.local_player_id)
		_torque_game.play(share, MinigameSettings.mode(), motion_seed, "The rover's wheel nuts")
		var score: int = await _torque_game.finished
		RoverController.input_blocked = was_blocked
		if not is_inside_tree():
			return
		# The rover's controls were held, but the game may have run a long while
		# and the rover may have left by another way: Bram services only a rover
		# that is still in his bay, so nothing is sent.
		if not _bram_bay.rover_inside:
			_hud.push_log("BRAM: The rover left the bay. Nothing was serviced.")
			_refresh_bram()
			return
		if score >= 0:
			# With no game played nothing more is sent: the service is as it always was.
			arguments = [score]
			torque = " " + MinigameScore.service_text(score)
	var problem: String = await FarmCommands.request(&"service_wheels", arguments)
	if not is_inside_tree():
		return
	if problem.is_empty() and torque != "":
		_hud.push_log("WHEEL NUTS:%s" % torque)
	if not _bram_bay.rover_inside:
		return
	if problem.is_empty():
		_bram_line = "Five nuts, star order, each to the click. You're good for another %s m." % SP811.integer(roundi(GameState.wheel_service_due_m()))
	else:
		_bram_line = problem
		_hud.push_log("BRAM: " + problem)
	_refresh_bram()


func _on_wheels_changed() -> void:
	if _bram_bay.rover_inside:
		_refresh_bram()


func _go_to_dome() -> void:
	if _refuse_on_foot():
		return
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)


## F: out of the stopped rover, or back in from nearby.
func _get_out_or_in() -> void:
	_tunnel_warned_day = -1
	if CoopWalkers.asking:
		return
	if CoopWalkers.on_foot():
		CoopWalkers.asking = true
		var refused: String = await FarmCommands.request(&"get_into_rover")
		CoopWalkers.asking = false
		if refused == "":
			CoopWalkers.went_in()
		elif is_inside_tree():
			_hud.push_log("ON FOOT: " + refused)
		return
	if _rover.away_text() != "":
		_say_if_away()
		return
	if not _rover.is_stopped():
		_hud.push_log("ROVER: Stop the rover first.")
		return
	var at: Vector3 = _walkers.clear_spot()
	if not at.is_finite():
		_hud.push_log("ROVER: There is no room to get out here.")
		return
	CoopWalkers.asking = true
	var problem: String = await FarmCommands.request(&"get_out_of_rover", [at.x, at.z])
	CoopWalkers.asking = false
	if problem == "" and is_inside_tree():
		CoopWalkers.went_out(at.x, at.z)
		_robots_ui.hide()
		_hud.push_log("On foot. " + Controls.prompt(&"get_out_in") + " gets back in the rover.")
	elif is_inside_tree():
		_hud.push_log("ROVER: " + problem)


## Farm work is done from the rover. True, and says so, if the player is out.
func _refuse_on_foot() -> bool:
	if CoopWalkers.on_foot():
		_hud.push_log(CoopWalkers.REFUSAL)
	return CoopWalkers.on_foot()


## Says where the rover is if it is not here.
func _say_if_away() -> void:
	if _rover.away_text() != "":
		_hud.push_log(_rover.away_text())


## Takes the rover in and goes with it.
func _enter_tunnels() -> void:
	if _moving:
		return
	# Soft gate (zones doc section 7.1): under the band's start, say so and wait
	# for a second E. Not a wall. A guest's copy has the same lab level, so it is
	# asked on its own screen before the command goes to the host.
	# Skipped when the host will refuse anyway (the mouth is closed after the
	# rescue hour, or someone else drives): the player then sees only that refusal.
	var refused: bool = TunnelRecall.closed(GameClock.elapsed_days) or not CoopRovers.driver(GameState.rover_here()) in ["", GameState.local_player_id]
	var warning: String = "" if refused else ZoneData.warning_text(TUNNELS_ZONE, GameState.lab_level())
	if warning != "" and _tunnel_warned_day != int(GameClock.elapsed_days):
		_tunnel_warned_day = int(GameClock.elapsed_days)
		_hud.push_log("TUNNEL MOUTH: %s Press %s again to go in, or drive off the pad to stay." % [warning, Controls.prompt(&"interact")])
		return
	_tunnel_warned_day = -1
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


## Puts the farm notice board (a lava hub board's look, NoticeBoard.FARM_POSITION)
## in the world with a pad by it: park the rover there and press interact.
func _build_notice_board() -> void:
	var world: Node3D = $WorldView/WorldViewport/World
	var board: Node3D = LavaHubProps.board_node("FARM NOTICE BOARD")
	board.position = NoticeBoard.FARM_POSITION
	world.add_child(board)
	_notice_pad = ParkingPad.new()
	_notice_pad.name = "NoticeBoardPad"
	_notice_pad.collision_layer = 0
	_notice_pad.collision_mask = 2
	_notice_pad.position = NoticeBoard.FARM_POSITION
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = NoticeBoard.PAD_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 0.0)
	_notice_pad.add_child(shape)
	world.add_child(_notice_pad)


## The soil probe was clicked: its text and the plot's readout, and the read is
## counted (FarmCommands read_probe) for the Read the Probe starter job. A refusal
## is shown too.
func _read_probe(text: String) -> void:
	_show_inspect(text + " " + GameState.soil_probe_text())
	var refused: Variant = await FarmCommands.request(&"read_probe")
	if is_inside_tree() and refused is String and refused != "":
		_hud.push_log(refused)


## Interact at the farm notice board: the host takes any starter job offered (a
## guest asks for it) and the board's lines go to the phone log. A refusal is one
## plain line (the host's answer begins with "BOARD:" when it was allowed). A
## guest reads its own copy of the quests, which the host keeps up to date; with
## none yet, what the host answered.
func _read_notice_board() -> void:
	var answer: String = str(await FarmCommands.request(&"read_farm_board"))
	if not is_inside_tree():
		return
	if not answer.begins_with("BOARD:"):
		_hud.push_log(answer)
		return
	var own: Variant = GameState.player_quest_state.get(GameState.local_player_id, {})
	var lines: Array[String] = NoticeBoard.farm_lines(QuestEngine.quests(), GameState.quest_state, own if own is Dictionary else {}, true)
	if FarmCommands.guest and GameState.quest_state.is_empty():
		lines.assign(answer.split("\n"))
	for line: String in lines:
		_hud.push_log(line)
