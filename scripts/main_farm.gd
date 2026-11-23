extends Node
## Composition root for the farm scene. Wires rover / GameState <-> HUD.
## Holds no gameplay rules of its own. Dispatches and audits come from
## GameState's phone log, so they survive scene swaps.

## Phone-log lines replayed into the HUD when the farm loads.
const LOG_REPLAY_LINES: int = 6
## A clicked prop's text stays in the hover label this long, like the dome's toast.
const INSPECT_SECONDS: float = 3.0
## Long descriptions stay up longer.
const INSPECT_SECONDS_PER_CHAR: float = 0.04
## The prop whose inspect text also carries the plot's soil readings.
const SOIL_PROBE_PROP: String = "soil_moisture_probe"

var _had_los: bool = true
var _last_band: int = DriftingSensor.Band.IN_BAND

@onready var _rover: RoverController = %Rover
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _airlock: Clickable = %Airlock
@onready var _hover_hint: Label = %HoverHint
@onready var _bram_bay: BramBay = %BramBay
## Ryan, 2026-11-22: "Pad by the airlock". Park here and press E to calibrate
## the tire gauge against the WD-1 without going into the dome.
@onready var _cal_pad: ParkingPad = %FieldCalPad

var _bram_line: String = ""
## Seconds left showing a clicked prop's text in the hover label.
var _inspect_left: float = 0.0
## Ryan (2026-11-22): buying a standard takes two presses. The first press
## (key or button) arms the offer and shows the price; a second press on the
## same offer buys it. Leaving the bay or pressing another offer re-arms.
var _armed_standard: String = ""


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.soil_tilled.connect(_on_soil_tilled)
	_rover.till_rejected.connect(_on_till_rejected)
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
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.ore_changed.connect(_on_ore_changed)
	GameState.credibility_changed.connect(_on_credibility_changed)
	_rover.ore_mined.connect(_on_ore_mined)
	_bram_bay.rover_entered.connect(_on_rover_entered_bay)
	_bram_bay.rover_exited.connect(_on_rover_exited_bay)
	_cal_pad.rover_entered.connect(_on_rover_entered_cal_pad)
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
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	_hud.set_credits(GameState.credits)
	_hud.set_ore(GameState.crystal_ore)
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_text())
	_refresh_jobs_hud()


func _process(delta: float) -> void:
	_hud.set_clock(GameClock.format_now())
	if _inspect_left > 0.0:
		_inspect_left -= delta
		return
	var hovered: Clickable = Clickable.hovered
	_hover_hint.text = hovered.hint if hovered else ""


func _show_inspect(text: String) -> void:
	_hover_hint.text = text
	_inspect_left = maxf(INSPECT_SECONDS, text.length() * INSPECT_SECONDS_PER_CHAR)


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
	_hud.push_log("Tilled cell (%s, %s). Space again plants %s (%s CR seed); C changes the seed, [ and ] its starting set point." % [
		SP811.integer(cell.x), SP811.integer(cell.z), GameState.crop_name(GameState.current_seed()),
		SP811.integer(GameState.seed_cost(GameState.current_seed()))])


## Space on tilled soil: harvest a ready crop, report a growing one, or plant.
func _on_tilled_cell_used(cell: Vector3i, seed_id: String, offset_steps: int) -> void:
	if GameState.is_crop_ready(cell):
		var entry: Dictionary = GameState.harvest_crop(cell)
		var grade: String = ("in spec" if entry["in_spec"]
			else "OFF SPEC: the soil left its moisture band on %s days" % SP811.integer(entry["out_of_band_days"]))
		_hud.push_log("HARVESTED %s, %s. Bin: %s crops for Lin at Bram's bay." % [
			GameState.crop_name(entry["crop_id"]), grade, SP811.integer(GameState.harvest_bin.size())])
	elif GameState.plantings.has(cell):
		_hud.push_log(GameState.crop_status_text(cell) + ". [ and ] move the set point.")
	else:
		var problem: String = GameState.plant_crop(cell, seed_id, offset_steps)
		if problem.is_empty():
			_hud.push_log("PLANTED " + GameState.crop_status_text(cell))
		else:
			_hud.push_log("PLANT FAILED: " + problem)


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and _cal_pad.rover_inside:
		get_viewport().set_input_as_handled()
		_try_field_cal()
	elif event.is_action_pressed(&"interact") and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_try_trade()
	elif _is_key(event, KEY_L) and _bram_bay.rover_inside:
		get_viewport().set_input_as_handled()
		_sell_to_lin()
	elif _is_key(event, KEY_C):
		get_viewport().set_input_as_handled()
		var seed: String = GameState.cycle_seed()
		_hud.push_log("SEED: %s, %s CR, %s days, soil moisture target %s %%" % [
			GameState.crop_name(seed), SP811.integer(GameState.seed_cost(seed)),
			SP811.integer(int(GameState.crop(seed).get("growth_days", 0))),
			SP811.number(float(GameState.crop(seed).get("soil_moisture_target", 0.0)) * 100.0, 0)])
	elif _is_key(event, KEY_BRACKETLEFT) or _is_key(event, KEY_BRACKETRIGHT):
		var cell: Vector3i = _rover.cell_under()
		var step: int = -1 if _is_key(event, KEY_BRACKETLEFT) else 1
		get_viewport().set_input_as_handled()
		if GameState.plantings.has(cell):
			GameState.adjust_setpoint(cell, step)
			_hud.push_log(GameState.crop_status_text(cell))
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


func _is_key(event: InputEvent, keycode: Key) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	# The key's label, or the character it typed: on German QWERTZ, [ and ]
	# are AltGr+8 and AltGr+9, whose keycode stays 8 and 9.
	return key.keycode == keycode or (key.unicode > 0
		and String.chr(key.unicode).to_upper().unicode_at(0) == keycode)


func _sell_to_lin() -> void:
	if GameState.harvest_bin.is_empty():
		_hud.push_log("LIN: Nothing in your bin. Bring me crops, and keep that spider away from my stall.")
		return
	GameState.sell_harvest_to_lin()


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
	var problem: String = GameState.accept_job(index)
	if problem != "":
		_hud.push_log("JOB NOT ACCEPTED: " + problem)


func _on_ore_mined(_fissure_id: StringName) -> void:
	_hud.push_log("Drilled 1 crystal ore. Carrying %d." % GameState.crystal_ore)


func _on_credibility_changed(_points: int) -> void:
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_text())
	if _bram_bay.rover_inside:
		_refresh_bram()


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
		_field_cal_one(id)


func _field_cal_one(id: String) -> void:
	var sensor: DriftingSensor = GameState.get_sensor(id)
	var record: Dictionary = GameState.calibrate_at_bench(id)
	if record.is_empty():
		return
	var label: String = GameState.instrument_name(id).to_upper()
	if record.get("refused", false):
		_hud.push_log("FIELD CAL %s REFUSED: %s" % [label, str(record["reason"])])
		return
	var verdict: String = ("NOT TRACEABLE (standard overdue)" if record.get("standard_overdue", false)
		else str(record["result"]).to_upper())
	_hud.push_log("FIELD CAL %s %s  As-found %s  As-left %s  Due day %d  (%d min)" % [
		label, verdict, sensor.format_value(record["as_found"]), sensor.format_value(record["as_left"]),
		record["due_day"], roundi(record.get("bench_minutes", 0.0))])


func _on_rover_exited_bay() -> void:
	_armed_standard = ""
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
		problem = GameState.buy_standard(standard_id)
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
	var problem: String = GameState.buy_wide_treads()
	if problem.is_empty():
		_bram_line = "Fresh treads, wide stance. Try not to till a boulder with them."
	else:
		_bram_line = problem
		_hud.push_log("BRAM: " + problem)
	_refresh_bram()


func _go_to_dome() -> void:
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)

