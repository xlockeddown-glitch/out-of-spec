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
