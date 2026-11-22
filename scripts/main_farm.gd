extends Node
## Composition root for the farm scene. Wires rover / GameState <-> HUD.
## Holds no gameplay rules of its own. Dispatches and audits come from
## GameState's phone log, so they survive scene swaps.

## Phone-log lines replayed into the HUD when the farm loads.
const LOG_REPLAY_LINES: int = 6

var _had_los: bool = true
var _last_band: int = DriftingSensor.Band.IN_BAND

@onready var _rover: RoverController = %Rover
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _airlock: Clickable = %Airlock
@onready var _bram_bay: BramBay = %BramBay

var _bram_line: String = ""


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.soil_tilled.connect(_on_soil_tilled)
	_rover.till_rejected.connect(_on_till_rejected)
	_hud.zero_steering_pressed.connect(_on_zero_pressed)
	_hud.slot_spool_pressed.connect(_on_slot_spool_pressed)
	_hud.enter_dome_pressed.connect(_go_to_dome)
	_airlock.clicked.connect(_go_to_dome)
	# Bound methods so the autoload drops them when this scene is freed.
	GameState.silk_changed.connect(_on_silk_changed)
	GameState.relay_changed.connect(_on_relay_changed)
	GameState.phone_message.connect(_hud.push_log)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.ore_changed.connect(_on_ore_changed)
	_rover.ore_mined.connect(_on_ore_mined)
	_bram_bay.rover_entered.connect(_on_rover_entered_bay)
	_bram_bay.rover_exited.connect(_hud.hide_bram)
	_hud.trade_pressed.connect(_try_trade)
	_hud.buy_standard_pressed.connect(_try_buy_standard)

	# Replay the persistent phone log first, so fresh SYS lines land on top of it.
	for line: String in GameState.phone_log.slice(-LOG_REPLAY_LINES):
		_hud.push_log(line)
	var relay_name: String = _rover.satellite_relay.relay_name if _rover.satellite_relay else "NO RELAY"
	_hud.configure(relay_name, _rover.steering.mpe, _rover.steering.acceptance_ratio)
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	_hud.set_credits(GameState.credits)
	_hud.set_ore(GameState.crystal_ore)


func _process(_delta: float) -> void:
	_hud.set_clock(GameClock.format_now())


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
	var schedule: String = ("No standard: not a calibration, still due day %d" % record.get("due_day", 0)
		if not record.get("traceable", true)
		else "Next due day %d (%d d)" % [record.get("due_day", 0), record.get("interval_days", 0)])
	_hud.push_log("As-found %s°  As-left %s°  %s" % [
		SP811.signed(record.get("as_found", 0.0)), SP811.signed(record.get("as_left", 0.0)), schedule])


func _on_slot_spool_pressed() -> void:
	if GameState.slot_spool_into_relay():
		_hud.push_log("Optical silk spool installed. Uplink lag × %s." % SP811.number(GameState.get_relay_lag_multiplier(), 2))


func _on_silk_changed(_spools: int) -> void:
	_refresh_relay_hud()


func _on_relay_changed(_slotted: bool) -> void:
	_refresh_relay_hud()
	_rover.broadcast_state()  # lag readout picks up the relay multiplier


func _refresh_relay_hud() -> void:
	_hud.set_relay(GameState.relay_slotted, GameState.optical_silk_spools, GameState.can_slot_spool())


func _on_soil_tilled(cell: Vector3i) -> void:
	_hud.push_log("Tilled cell (%d, %d)" % [cell.x, cell.z])


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_try_trade()
	elif event is InputEventKey and event.pressed and not event.echo and _bram_bay.rover_inside:
		# [1], [2], ... buy Bram's Tier 1 standards in catalog order.
		var index: int = (event as InputEventKey).physical_keycode - KEY_1
		var catalog: Array[String] = GameState.bram_catalog()
		if GameState.tier1_unlocked and index >= 0 and index < catalog.size():
			get_viewport().set_input_as_handled()
			_try_buy_standard(catalog[index])


func _on_ore_mined(_fissure_id: StringName) -> void:
	_hud.push_log("Drilled 1 crystal ore. Carrying %d." % GameState.crystal_ore)


func _on_credits_changed(amount: int) -> void:
	_hud.set_credits(amount)
	if _bram_bay.rover_inside:
		_refresh_bram()


func _on_ore_changed(ore: int) -> void:
	_hud.set_ore(ore)
	if _bram_bay.rover_inside:
		_refresh_bram()


func _on_rover_entered_bay() -> void:
	var cost: int = GameState.treads_ore_cost()
	if GameState.has_wide_treads:
		_bram_line = GameState.bram_line("greetings")
	elif GameState.crystal_ore >= cost:
		_bram_line = "That's %d crystal ore. Treads coming right up, hit trade." % cost
	else:
		_bram_line = "Bring me %d crystal ore and I'll bolt wider treads onto your tractor. Carrying %d." % [cost, GameState.crystal_ore]
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
			offers.append({
				"id": id,
				"text": ("%s: ON THE COLONY" % sensor.short_name.to_upper()) if owned
					else "BUY %s: %s  [%d]" % [sensor.short_name.to_upper(), GameState.standard_price_text(id).to_upper(), i + 1],
				"disabled": owned or GameState.credits < sensor.price_credits or GameState.crystal_ore < sensor.price_ore,
			})
	_hud.show_standards(offers, "" if GameState.tier1_unlocked else "Tier 1 standards: pass one audit clean and Bram will sell them.")


func _try_buy_standard(standard_id: String) -> void:
	if not _bram_bay.rover_inside:
		return
	var problem: String = GameState.buy_standard(standard_id)
	if problem.is_empty():
		_bram_line = "Handle it like it's worth more than your tractor. It nearly is."
	else:
		_hud.push_log("BRAM: " + problem)
	_refresh_bram()


func _try_trade() -> void:
	if not _bram_bay.rover_inside or GameState.has_wide_treads:
		return
	var problem: String = GameState.buy_wide_treads()
	if problem.is_empty():
		_bram_line = "Fresh treads, wide stance. Try not to till a boulder with them."
	else:
		_hud.push_log("BRAM: " + problem)
	_refresh_bram()


func _go_to_dome() -> void:
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)

