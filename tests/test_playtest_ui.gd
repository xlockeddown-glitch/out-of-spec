extends RefCounted
## Playtest UI fixes: job order, lights row, robots panel placement, pause panel.

const HudScene: PackedScene = preload("res://ui/field_phone_hud.tscn")


func _hud() -> FieldPhoneHUD:
	var hud: FieldPhoneHUD = HudScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	return hud


func test_offers_you_can_accept_come_first_with_their_own_index() -> String:
	var hud: FieldPhoneHUD = _hud()
	var got: Array[int] = []
	hud.accept_job_pressed.connect(func(i: int) -> void: got.append(i))
	var offers: Array[Dictionary] = [
		{ "text": "A", "disabled": true }, { "text": "B", "disabled": false }, { "text": "C", "disabled": true }]
	hud.show_jobs(PackedStringArray(), offers, "")
	var buttons: Array[Button] = []
	for child: Node in hud._jobs_box.get_children():
		buttons.append(child as Button)
	var problem: String = ""
	if buttons.size() != 3 or buttons[0].text != "ACCEPT B" or buttons[1].text != "ACCEPT A" or buttons[2].text != "ACCEPT C":
		problem = "Acceptable offers must come first, then the rest in order."
	else:
		buttons[0].pressed.emit()
		if got != [1]:
			problem = "A sorted button must still accept the board's own offer: %s" % [got]
	hud.free()
	return problem


func test_the_lights_row_says_which_is_set() -> String:
	var hud: FieldPhoneHUD = _hud()
	var problem: String = ""
	var label: Label = hud._lights_label
	if label.visible:
		problem = "The lights row must be hidden outside the tunnels."
	hud.set_lights(false)
	if not label.visible or label.text != "LIGHTS: LOW":
		problem = "Low lights must say LOW."
	hud.set_lights(true)
	if label.text != "LIGHTS: ON":
		problem = "Lights on must say ON."
	hud.free()
	return problem


func test_the_robots_panel_stays_clear_of_the_phone() -> String:
	var robots := RobotsUI.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(robots)
	var center: CenterContainer = robots.get_child(0)
	var ok: bool = is_equal_approx(center.anchor_right, RobotsUI.PHONE_LEFT_ANCHOR)
	robots.free()
	return "" if ok else "The robots panel must end where the phone begins."


func test_the_phone_size_follows_its_one_scale() -> String:
	var hud: FieldPhoneHUD = _hud()
	var title: Label = hud.get_node("Bezel/Screen/Content/Title")
	var problem: String = ""
	if title.get_theme_font_size("font_size") != roundi(26.0 * FieldPhoneHUD.PHONE_SCALE):
		problem = "The title font must be its original size times PHONE_SCALE."
	elif not is_equal_approx(hud.anchor_left, FieldPhoneHUD.LEFT_ANCHOR):
		problem = "The phone must start at LEFT_ANCHOR."
	hud.free()
	for path: String in ["res://scenes/main_farm.tscn", "res://scenes/basalt_tunnels.tscn"]:
		var world: Control = (load(path) as PackedScene).instantiate().get_node("WorldView")
		if not is_equal_approx(world.anchor_right, FieldPhoneHUD.LEFT_ANCHOR):
			problem = "The world view in %s must end where the phone begins." % path
		world.get_parent().free()
	return problem


func test_esc_opens_and_closes_the_pause_panel() -> String:
	var pause := PauseUI.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pause)
	var problem: String = ""
	if pause.visible:
		problem = "The pause panel starts closed."
	pause.open()
	if not pause.visible:
		problem = "open() must show it."
	pause._resume_button.pressed.emit()
	if pause.visible:
		problem = "RESUME must close it."
	pause.free()
	return problem


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func test_an_open_pause_panel_takes_every_key() -> String:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var pause := PauseUI.new()
	root.add_child(pause)
	var problem: String = ""
	pause.open()
	root.get_tree().paused = false
	var seen: bool = false
	# _unhandled_input marks the event handled through the viewport; the call
	# must at least not close the panel on an ordinary key.
	pause._unhandled_input(_key(KEY_H))
	seen = pause.visible
	if not seen:
		problem = "An ordinary key must leave the panel open."
	pause._unhandled_input(_key(KEY_ESCAPE))
	if pause.visible:
		problem = "Esc must close it."
	pause.free()
	root.get_tree().paused = false
	return problem


func test_pause_stops_the_game_only_when_alone() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	tree.root.add_child(pause)
	var problem: String = ""
	pause.open()
	if not PauseUI.is_alone() or not tree.paused or pause._title.text != "PAUSED":
		problem = "Alone, it must pause and say PAUSED."
	pause.close()
	if tree.paused:
		problem = "RESUME must unpause."
	CoopSession.players = ["player_1", "player_2"]
	pause.open()
	if tree.paused or pause._title.text != "MENU":
		problem = "With a guest it must run on and say MENU."
	pause.close()
	CoopSession.players = []
	pause.free()
	tree.paused = false
	return problem


func test_quit_warns_guests_then_reports_a_failed_save() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	var quits: Array[int] = []
	pause.quitter = func() -> void: quits.append(1)
	pause.saver = func() -> String: return "Disk full."
	tree.root.add_child(pause)
	var farm_open: bool = SaveGame.farm_open
	SaveGame.farm_open = true
	var problem: String = ""
	CoopSession.players = ["player_1", "player_2"]
	pause.open()
	pause._on_quit()
	if not quits.is_empty() or not pause._note.text.contains("dropped"):
		problem = "The first press must only warn."
	pause._on_quit()
	if not quits.is_empty() or pause._note.text != "SAVE FAILED: Disk full.":
		problem = "A failed save must say so and not quit: %s" % pause._note.text
	CoopSession.players = []
	SaveGame.farm_open = farm_open
	pause.close()
	pause.free()
	tree.paused = false
	return problem


func test_the_menu_blocks_driving_keys_only_while_the_game_runs_on() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	tree.root.add_child(pause)
	var problem: String = ""
	pause.open()
	if RoverController.input_blocked:
		problem = "Alone the tree is paused; nothing to block."
	pause.close()
	CoopSession.players = ["player_1", "player_2"]
	pause.open()
	if not RoverController.input_blocked:
		problem = "With a guest, the menu must block driving keys."
	pause.close()
	if RoverController.input_blocked:
		problem = "Closing must clear the block."
	CoopSession.players = []
	pause.free()
	tree.paused = false
	return problem


func test_the_menu_follows_players_joining_and_leaving() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	tree.root.add_child(pause)
	var problem: String = ""
	pause.open()
	CoopSession.players = ["player_1", "player_2"]
	CoopSession.player_joined.emit("player_2")
	if tree.paused or pause._title.text != "MENU" or not RoverController.input_blocked:
		problem = "A guest joining must unpause and block driving keys."
	CoopSession.players = ["player_1"]
	CoopSession.player_left.emit("player_2")
	if not tree.paused or pause._title.text != "PAUSED" or RoverController.input_blocked:
		problem = "The guest leaving must pause again."
	pause.close()
	CoopSession.players = []
	pause.free()
	tree.paused = false
	return problem


func test_a_blocked_rover_takes_no_till_press() -> String:
	var rover: RoverController = RoverController.new()
	var event := InputEventAction.new()
	event.action = &"rover_till"
	event.pressed = true
	RoverController.input_blocked = true
	rover._input(event)
	var blocked: bool = rover._till_presses.is_empty()
	RoverController.input_blocked = false
	rover.free()
	return "" if blocked else "A till press must not count while the menu blocks keys."


func test_the_menu_closes_when_the_link_is_lost_and_rearms_on_a_new_guest() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	tree.root.add_child(pause)
	var problem: String = ""
	CoopSession.players = ["player_1", "player_2"]
	pause.open()
	pause._on_quit()
	CoopSession.player_left.emit("player_2")
	if pause._armed or pause._note.text != "":
		problem = "The guest warning must reset when the guests change."
	CoopSession.lost.emit()
	if pause.visible or RoverController.input_blocked or tree.paused:
		problem = "A lost link must close the menu and clear the block."
	CoopSession.players = []
	pause.free()
	tree.paused = false
	return problem


func test_zero_steering_and_the_dig_stamp_are_gated() -> String:
	var rover: RoverController = RoverController.new()
	rover.rover_id = &"test_rover"
	Input.action_press(&"rover_zero_steering")
	RoverController.input_blocked = true
	rover._sample_local_input(0.0)
	var blocked_ok: bool = rover._commands.is_empty()
	var scene: Node = (load("res://scenes/main_farm.tscn") as PackedScene).instantiate()
	var event := InputEventAction.new()
	event.action = &"rover_dig"
	event.pressed = true
	scene._input(event)
	var stamp_ok: bool = scene._dig_pressed_msec < 0
	RoverController.input_blocked = false
	scene._input(event)
	var stamp_set: bool = scene._dig_pressed_msec >= 0
	Input.action_release(&"rover_zero_steering")
	scene.free()
	rover.free()
	if not blocked_ok:
		return "Zero steering must not queue while the menu blocks keys."
	if not stamp_ok:
		return "A dig press while blocked must not count as ours."
	return "" if stamp_set else "An ordinary dig press must be stamped."
