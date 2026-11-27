extends RefCounted
## The "[E] verb" prompt over the thing in reach: the right key and verb, hidden when
## nothing is in reach or a panel holds the screen, the glyph following the device.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _reset() -> void:
	Controls.last_device = Controls.Device.KEY
	Controls.pad_present_override = false
	Controls.reset_shown()


func _prompt() -> VerbPrompt:
	var prompt := VerbPrompt.new()
	_root().add_child(prompt)
	return prompt


func test_shows_key_and_verb_for_a_target_in_reach() -> String:
	_reset()
	var pad := ParkingPad.new()
	pad.verb = "Calibrate"
	var prompt: VerbPrompt = _prompt()
	var shown: bool = prompt.point_at(Vector2(400.0, 300.0), VerbPrompt.verb_of(pad))
	var text: String = prompt.text
	var visible_now: bool = prompt.visible
	prompt.free()
	pad.free()
	if not shown or not visible_now:
		return "The prompt should show for a target in reach"
	return "" if text == "[E] Calibrate" else "Expected \"[E] Calibrate\", got \"%s\"" % text


func test_clear_hides_it() -> String:
	var prompt: VerbPrompt = _prompt()
	prompt.point_at(Vector2(100.0, 100.0), "Open")
	prompt.clear()
	var hidden: bool = not prompt.visible
	prompt.free()
	return "" if hidden else "clear() should hide the prompt"


func test_hidden_while_a_panel_holds_the_screen() -> String:
	var prompt: VerbPrompt = _prompt()
	var panel := Control.new()
	panel.add_to_group(QuestsUI.MODAL_GROUP)
	_root().add_child(panel)
	var shown: bool = prompt.point_at(Vector2(100.0, 100.0), "Open")
	var hidden: bool = not prompt.visible
	panel.free()
	var back: bool = prompt.point_at(Vector2(100.0, 100.0), "Open")
	prompt.free()
	if shown or not hidden:
		return "An open panel should hide the prompt"
	return "" if back else "The prompt should come back when the panel closes"


func test_glyph_follows_the_device() -> String:
	_reset()
	var prompt: VerbPrompt = _prompt()
	prompt.point_at(Vector2(200.0, 200.0), "Open")
	var on_keys: String = prompt.text
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	prompt.point_at(Vector2(200.0, 200.0), "Open")
	var on_pad: String = prompt.text
	_reset()
	prompt.free()
	if on_keys != "[E] Open":
		return "Keyboard: expected \"[E] Open\", got \"%s\"" % on_keys
	return "" if on_pad == "[A] Open" else "Pad: expected \"[A] Open\", got \"%s\"" % on_pad


func test_other_actions_use_their_own_key() -> String:
	_reset()
	var text: String = VerbPrompt.text_for("Get in rover", &"get_out_in")
	var want: String = "[%s] Get in rover" % Controls.key_label(&"get_out_in")
	return "" if text == want else "Expected \"%s\", got \"%s\"" % [want, text]


func test_fallback_verb_when_the_target_names_none() -> String:
	_reset()
	var click := Clickable.new()
	var pad := ParkingPad.new()
	var plain := Node.new()
	var bad: PackedStringArray = []
	for target: Object in [click, pad, plain, null]:
		if VerbPrompt.verb_of(target) != VerbPrompt.FALLBACK_VERB:
			bad.append(str(target))
	var text: String = VerbPrompt.text_for("")
	click.free()
	pad.free()
	plain.free()
	if not bad.is_empty():
		return "Fallback missing for: %s" % ", ".join(bad)
	return "" if text == "[E] Use" else "Expected \"[E] Use\", got \"%s\"" % text


func test_clickable_verb_is_used() -> String:
	var click := Clickable.new()
	click.verb = "Board shuttle"
	var verb: String = VerbPrompt.verb_of(click)
	click.free()
	return "" if verb == "Board shuttle" else "Got \"%s\"" % verb


func test_prompt_stays_inside_its_limit_on_every_side() -> String:
	var prompt: VerbPrompt = _prompt()
	prompt.limit = Vector2(800.0, 600.0)
	prompt.floor_px = 90.0
	var bad: PackedStringArray = []
	for point: Vector2 in [Vector2(5000.0, -300.0), Vector2(-5000.0, 5000.0), Vector2(400.0, 300.0)]:
		prompt.point_at(point, "Open")
		var p: Vector2 = prompt.position
		var right: float = p.x + prompt.size.x
		var bottom: float = p.y + prompt.size.y
		if p.x < VerbPrompt.EDGE_PX - 0.01 or p.y < VerbPrompt.EDGE_PX - 0.01 \
				or right > 800.0 - VerbPrompt.EDGE_PX + 0.01 or bottom > 600.0 - 90.0 + 0.01:
			bad.append("%s -> %s" % [point, p])
	prompt.free()
	return "" if bad.is_empty() else "Outside the limit: %s" % ", ".join(bad)


func test_a_paused_game_hides_it() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var prompt: VerbPrompt = _prompt()
	prompt.point_at(Vector2(100.0, 100.0), "Open")
	tree.paused = true
	prompt._process(0.0)
	var hidden: bool = not prompt.visible
	var held: bool = prompt.point_at(Vector2(100.0, 100.0), "Open")
	tree.paused = false
	var mode_ok: bool = prompt.process_mode == Node.PROCESS_MODE_ALWAYS
	prompt.free()
	if not hidden or held:
		return "A paused game should hide the prompt"
	return "" if mode_ok else "The prompt must keep running while paused"


# --- The farm's pick: verb_target() ---------------------------------------------------

## A farm scene, not in the tree, with the pads and rover _ready would wire, and the
## autoload state verb_target reads, saved for _restore().
func _farm() -> Array:
	var farm: Node = (load("res://scenes/main_farm.tscn") as PackedScene).instantiate()
	farm.set(&"_rover", farm.find_child("Rover", true, false))
	farm.set(&"_cal_pad", farm.find_child("FieldCalPad", true, false))
	farm.set(&"_tunnel_pad", farm.find_child("TunnelPad", true, false))
	farm.set(&"_bram_bay", farm.find_child("BramBay", true, false))
	var notice := ParkingPad.new()
	notice.verb = "Read notices"
	farm.set(&"_notice_pad", notice)
	(farm.get(&"_cal_pad") as ParkingPad).verb = "Calibrate"
	(farm.get(&"_tunnel_pad") as ParkingPad).verb = "Enter tunnels"
	(farm.get(&"_bram_bay") as ParkingPad).verb = "Trade with Bram"
	var saved: Dictionary = {
		"treads": GameState.has_wide_treads, "standards": GameState.owned_standards.duplicate(),
		"zone": GameState.rover_zone, "lent": GameState.rover_lent, "out": CoopWalkers.out.duplicate(),
		"pose": GameState.rover_transforms.get(GameState.ROVER), "days": GameClock.elapsed_days,
	}
	GameState.has_wide_treads = false
	GameState.rover_zone = ""
	GameState.rover_lent = false
	CoopWalkers.out.clear()
	GameClock.elapsed_days = 0.1
	_stock_standards()
	return [farm, notice, saved]


func _restore(data: Array) -> void:
	var saved: Dictionary = data[2]
	GameState.has_wide_treads = saved["treads"]
	GameState.owned_standards = saved["standards"]
	GameState.rover_zone = saved["zone"]
	GameState.rover_lent = saved["lent"]
	CoopWalkers.out = saved["out"]
	GameClock.elapsed_days = saved["days"]
	if saved["pose"] == null:
		GameState.rover_transforms.erase(GameState.ROVER)
	else:
		GameState.rover_transforms[GameState.ROVER] = saved["pose"]
	(data[1] as Node).free()
	(data[0] as Node).free()


## Puts the standards the field pad calibrates against in service.
func _stock_standards() -> void:
	for id: String in GameState.FIELD_CAL_IDS:
		var sensor: DriftingSensor = GameState.get_sensor(id)
		if sensor != null and sensor.calibrated_by != "":
			GameState.owned_standards[sensor.calibrated_by] = 0


func _verb_with(pads: Array) -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	for name: String in pads:
		(farm.get(name) as ParkingPad).rover_inside = true
	var got: Dictionary = farm.verb_target()
	var text: String = "" if got.is_empty() else String(got["verb"])
	_restore(data)
	return text


func test_pads_answer_in_the_order_interact_does() -> String:
	var bad: PackedStringArray = []
	var cases: Array = [
		[["_notice_pad", "_cal_pad", "_tunnel_pad", "_bram_bay"], "Read notices"],
		[["_cal_pad", "_tunnel_pad", "_bram_bay"], "Calibrate"],
		[["_tunnel_pad", "_bram_bay"], "Enter tunnels"],
		[["_bram_bay"], "Trade with Bram"],
		[[], ""],
	]
	for item: Array in cases:
		var got: String = _verb_with(item[0])
		if got != item[1]:
			bad.append("%s gave \"%s\", wanted \"%s\"" % [item[0], got, item[1]])
	return "" if bad.is_empty() else "; ".join(bad)


func test_bram_says_nothing_once_the_treads_are_bought() -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	(farm.get(&"_bram_bay") as ParkingPad).rover_inside = true
	var before: Dictionary = farm.verb_target()
	GameState.has_wide_treads = true
	var after: Dictionary = farm.verb_target()
	_restore(data)
	if before.is_empty():
		return "Bram should offer a trade before the treads are bought"
	return "" if after.is_empty() else "Bram should be silent after the treads"


func test_cal_pad_needs_a_standard_to_offer() -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	(farm.get(&"_cal_pad") as ParkingPad).rover_inside = true
	var some: Dictionary = farm.verb_target()
	GameState.owned_standards.clear()
	var none: Dictionary = farm.verb_target()
	_restore(data)
	if some.is_empty():
		return "With a standard the cal pad should offer Calibrate"
	return "" if none.is_empty() else "No standard: the cal pad should offer nothing"


func test_cal_pad_is_silent_while_the_rover_rolls() -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	(farm.get(&"_cal_pad") as ParkingPad).rover_inside = true
	(farm.get(&"_rover") as RoverController)._speed_mps = 3.0
	var rolling: Dictionary = farm.verb_target()
	_restore(data)
	return "" if rolling.is_empty() else "The cal pad should say nothing while the rover rolls"


func test_tunnel_mouth_is_silent_after_the_rescue_hour() -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	(farm.get(&"_tunnel_pad") as ParkingPad).rover_inside = true
	var open_now: Dictionary = farm.verb_target()
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 3.0)
	var closed_now: bool = TunnelRecall.closed(GameClock.elapsed_days)
	var late: Dictionary = farm.verb_target()
	_restore(data)
	if open_now.is_empty():
		return "An open tunnel mouth should offer Enter tunnels"
	if not closed_now:
		return "Test setup: 03:00 should be past the rescue hour"
	return "" if late.is_empty() else "A closed tunnel mouth should say nothing"


func test_an_away_rover_has_no_pad_prompt() -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	(farm.get(&"_notice_pad") as ParkingPad).rover_inside = true
	var home: Dictionary = farm.verb_target()
	GameState.rover_zone = "lava_tubes"
	GameState.rover_lent = true
	var away: Dictionary = farm.verb_target()
	_restore(data)
	if home.is_empty():
		return "Test setup: the notice pad should answer with the rover home"
	return "" if away.is_empty() else "An away rover should leave no prompt"


func test_on_foot_has_no_pad_prompt_and_the_terminal_comes_first() -> String:
	var data: Array = _farm()
	var farm: Node = data[0]
	(farm.get(&"_notice_pad") as ParkingPad).rover_inside = true
	GameState.rover_transforms[GameState.ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 20.0))
	CoopWalkers.out[GameState.local_player_id] = [0.0, 0.5, 60.0, 0.0, 0.0]
	var far: Dictionary = farm.verb_target()
	var landing := LandingDressing.new()
	landing.terminal_click = Clickable.new()
	landing.terminal_click.verb = "Open terminal"
	farm.set(&"_landing", landing)
	farm.set(&"_shuttle_ui", ShuttleUI.new())
	CoopWalkers.out[GameState.local_player_id] = [Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y, 0.0, 0.0]
	var near: Dictionary = farm.verb_target()
	var ui: Node = farm.get(&"_shuttle_ui")
	farm.set(&"_shuttle_ui", null)
	farm.set(&"_landing", null)
	ui.free()
	landing.terminal_click.free()
	landing.free()
	_restore(data)
	if not far.is_empty():
		return "On foot away from the rover and terminal there should be no prompt, got %s" % far
	if near.is_empty() or near["verb"] != "Open terminal":
		return "At the terminal the prompt should be Open terminal, got %s" % near
	return ""
