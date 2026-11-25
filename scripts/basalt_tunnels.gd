extends Node
## Composition root for the basalt tunnels. Wires rover / GameState <-> HUD,
## like the farm's. Holds no gameplay rules of its own.

## Phone-log lines replayed into the HUD when the tunnels load.
const LOG_REPLAY_LINES: int = 6

var _had_los: bool = true
var _last_band: int = DriftingSensor.Band.IN_BAND

@onready var _rover: RoverController = %Rover
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _exit_pad: ParkingPad = %ExitPad


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.till_rejected.connect(_on_till_rejected)
	_rover.dig_rejected.connect(_on_dig_rejected)
	_rover.fill_rejected.connect(_on_fill_rejected)
	_exit_pad.rover_entered.connect(_on_rover_entered_exit)
	_hud.zero_steering_pressed.connect(_on_zero_pressed)
	_hud.slot_spool_pressed.connect(_on_slot_spool_pressed)
	_hud.enter_dome_pressed.connect(_go_to_dome)
	_hud.accept_job_pressed.connect(_try_accept_job)
	# Bound methods so the autoloads drop them when this scene is freed.
	GameState.silk_changed.connect(_on_silk_changed)
	GameState.relay_changed.connect(_on_relay_changed)
	GameState.phone_message.connect(_hud.push_log)
	GameState.skill_leveled.connect(_on_skill_leveled)
	SaveGame.save_failed.connect(_hud.push_log)
	GameState.credits_changed.connect(_hud.set_credits)
	GameState.ore_changed.connect(_hud.set_ore)
	GameState.credibility_changed.connect(_on_credibility_changed)
	GameState.jobs_changed.connect(_refresh_jobs_hud)
	GameState.upgrades_changed.connect(_refresh_jobs_hud)
	GameState.oirm_changed.connect(_refresh_jobs_hud)

	for line: String in GameState.phone_log.slice(-LOG_REPLAY_LINES):
		_hud.push_log(line)
	_hud.configure(_rover.satellite_relay.relay_name, _rover.steering.mpe, _rover.steering.acceptance_ratio)
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	_hud.set_credits(GameState.credits)
	_hud.set_ore(GameState.crystal_ore)
	_on_credibility_changed(0)
	_hud.get_parent().add_child(SkillsUI.new())
	_hud.get_parent().add_child(CoopUI.new())


func _process(_delta: float) -> void:
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and _exit_pad.rover_inside:
		get_viewport().set_input_as_handled()
		SceneSwitcher.swap_to(SceneSwitcher.FARM_SCENE)
	elif event.is_action_pressed(&"rover_dig"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.DIG)
	elif event.is_action_pressed(&"rover_fill"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.FILL)


func _on_rover_entered_exit() -> void:
	_hud.push_log("TUNNEL MOUTH: press E to leave.")


func _on_uplink_changed(has_los: bool, quality: float, lag_s: float) -> void:
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
			_hud.push_log("Silk spool installed.")
			return
		_hud.push_log("%s installed%s. Uplink lag × %s." % [
			"Damaged silk spool" if GameState.slotted_spool_damaged else "Optical silk spool",
			", the old one taken out" if replaced else "", SP811.number(GameState.get_relay_lag_multiplier(), 2)])


func _on_silk_changed(_spools: int) -> void:
	_refresh_relay_hud()


func _on_relay_changed(_slotted: bool) -> void:
	_refresh_relay_hud()
	_rover.broadcast_state()


func _refresh_relay_hud() -> void:
	_hud.set_relay(GameState.relay_slotted, GameState.slotted_spool_damaged, GameState.spool_count_text(), GameState.can_slot_spool())


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


func _on_dig_rejected(reason: String) -> void:
	_hud.push_log("DIG FAILED: %s" % reason)


func _on_fill_rejected(reason: String) -> void:
	_hud.push_log("FILL FAILED: %s" % reason)


func _on_credibility_changed(_points: int) -> void:
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_text())
	_refresh_jobs_hud()


func _on_skill_leveled(player_id: String, skill_id: String, _level: int) -> void:
	if player_id == "" or player_id == GameState.local_player_id:
		_hud.push_log("SKILL UP: %s. K shows skills." % GameState.skill_text(skill_id))


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


func _go_to_dome() -> void:
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)
