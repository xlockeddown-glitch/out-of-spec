extends RefCounted
## Xbox controller play: every control is a named InputMap action with its key
## and, unless the actions menu carries it, a pad button; the menu sends the
## same actions the keys do.

## Keyboard-only on purpose: the pad reaches these through the actions menu.
const MENU_ONLY: Array[StringName] = [
	&"place_stone", &"check_block", &"block_stack", &"survey", &"sell_lin", &"wheel_service",
	&"open_robots", &"open_quests", &"open_skills", &"open_coop", &"open_controls",
	&"buy_1", &"buy_2", &"buy_3", &"buy_4", &"buy_5", &"buy_6", &"buy_7", &"buy_8", &"buy_9"]


func _scripts() -> PackedStringArray:
	var found: PackedStringArray = []
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				found.append(dir + "/" + file)
	return found


func _kinds(action: StringName) -> Dictionary:
	var kinds: Dictionary = { "key": false, "pad": false }
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			kinds["key"] = true
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			kinds["pad"] = true
	return kinds


func test_every_action_the_scripts_read_exists_with_a_key() -> String:
	var reads := RegEx.create_from_string("(?:is_action_(?:just_)?(?:pressed|released)|get_axis)\\(&\"(\\w+)\"(?:, &\"(\\w+)\")?")
	var named := RegEx.create_from_string("&\"(rover_(?:forward|reverse|steer_left|steer_right|till|zero_steering|dig|lights|fill)|buy_[1-9]|open_(?:pause|quests|skills|coop|robots)|setpoint_(?:down|up)|interact|swap_scene|get_out_in|place_stone|stone_kind|check_block|block_stack|survey|cycle_seed|sell_lin|wheel_service)\"")
	var wanted: Dictionary = {}
	for path: String in _scripts():
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in reads.search_all(text):
			for i: int in [1, 2]:
				if found.get_string(i) != "":
					wanted[found.get_string(i)] = path
		for found: RegExMatch in named.search_all(text):
			wanted[found.get_string(1)] = path
	var missing: PackedStringArray = []
	for name: String in wanted:
		var action := StringName(name)
		if name.begins_with("ui_"):
			continue
		if not InputMap.has_action(action):
			missing.append("%s (%s)" % [name, wanted[name]])
		elif not _kinds(action)["key"]:
			missing.append("%s has no key" % name)
	return "" if missing.is_empty() else "Not in the InputMap with a key: %s" % ", ".join(missing)


func test_every_action_has_a_pad_button_or_a_menu_entry() -> String:
	var bad: PackedStringArray = []
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or not _kinds(action)["key"]:
			continue
		var pad: bool = _kinds(action)["pad"]
		if pad == MENU_ONLY.has(action):
			bad.append(String(action))
	return "" if bad.is_empty() else "Pad button and menu-only must be one or the other: %s" % ", ".join(bad)


func test_the_menu_entries_are_exactly_the_menu_only_actions() -> String:
	var shown: Array[StringName] = ActionsMenuUI.farm_actions()
	var problem: String = ""
	for action: StringName in shown:
		if not InputMap.has_action(action) or not MENU_ONLY.has(action):
			problem = "%s is in the menu but is not a menu-only action." % action
	for action: StringName in MENU_ONLY:
		if not shown.has(action):
			problem = "%s has no pad button and no menu entry." % action
	for action: StringName in ActionsMenuUI.PANEL_ACTIONS:
		if not shown.has(action):
			problem = "%s is offered in the dome but not on the farm." % action
	return problem


func test_the_pad_layout_is_what_the_table_says() -> String:
	var want: Dictionary = {
		&"interact": JOY_BUTTON_A, &"rover_dig": JOY_BUTTON_X, &"rover_fill": JOY_BUTTON_Y,
		&"setpoint_down": JOY_BUTTON_LEFT_SHOULDER, &"setpoint_up": JOY_BUTTON_RIGHT_SHOULDER,
		&"rover_lights": JOY_BUTTON_DPAD_UP, &"rover_zero_steering": JOY_BUTTON_DPAD_DOWN,
		&"cycle_seed": JOY_BUTTON_DPAD_LEFT, &"stone_kind": JOY_BUTTON_DPAD_RIGHT,
		&"rover_till": JOY_BUTTON_RIGHT_STICK, &"get_out_in": JOY_BUTTON_LEFT_STICK,
		&"open_pause": JOY_BUTTON_START, &"swap_scene": JOY_BUTTON_BACK}
	var bad: PackedStringArray = []
	for action: StringName in want:
		var held: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == want[action]:
				held = true
		if not held:
			bad.append(String(action))
	for action: StringName in [&"rover_steer_left", &"rover_steer_right", &"rover_forward", &"rover_reverse"]:
		var axes: int = 0
		for event: InputEvent in InputMap.action_get_events(action):
			axes += 1 if event is InputEventJoypadMotion else 0
		if axes == 0:
			bad.append(String(action))
	return "" if bad.is_empty() else "Not on the pad as the table says: %s" % ", ".join(bad)


func test_the_actions_keep_the_old_keys() -> String:
	var keys: Dictionary = { &"get_out_in": KEY_F, &"place_stone": KEY_B, &"stone_kind": KEY_N, &"check_block": KEY_Q,
		&"block_stack": KEY_J, &"survey": KEY_V, &"cycle_seed": KEY_C, &"sell_lin": KEY_L, &"wheel_service": KEY_Y,
		&"open_robots": KEY_T, &"setpoint_down": KEY_BRACKETLEFT, &"setpoint_up": KEY_BRACKETRIGHT,
		&"open_quests": KEY_O, &"open_skills": KEY_K, &"open_coop": KEY_F7, &"open_pause": KEY_ESCAPE,
		&"interact": KEY_E, &"swap_scene": KEY_TAB, &"rover_forward": KEY_W, &"rover_reverse": KEY_S,
		&"rover_steer_left": KEY_A, &"rover_steer_right": KEY_D, &"rover_till": KEY_SPACE,
		&"rover_zero_steering": KEY_R, &"rover_dig": KEY_G, &"rover_lights": KEY_L, &"rover_fill": KEY_H }
	for i: int in 9:
		keys[StringName("buy_%d" % (i + 1))] = KEY_1 + i
	var bad: PackedStringArray = []
	for action: StringName in keys:
		# A key press as the OS sends it: both the typed and the physical key set.
		var event := InputEventKey.new()
		event.keycode = keys[action]
		event.physical_keycode = keys[action]
		event.pressed = true
		if not event.is_action(action):
			bad.append(String(action))
	return "" if bad.is_empty() else "Key no longer does it: %s" % ", ".join(bad)


func test_the_movement_axes_are_the_right_ones() -> String:
	# action: [axis, sign]
	var want: Dictionary = { &"rover_steer_left": [JOY_AXIS_LEFT_X, -1.0], &"rover_steer_right": [JOY_AXIS_LEFT_X, 1.0],
		&"rover_forward": [JOY_AXIS_LEFT_Y, -1.0], &"rover_reverse": [JOY_AXIS_LEFT_Y, 1.0] }
	var bad: PackedStringArray = []
	for action: StringName in want:
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			var motion := event as InputEventJoypadMotion
			if motion != null and motion.axis == want[action][0] and signf(motion.axis_value) == want[action][1]:
				found = true
		if not found:
			bad.append("%s stick" % action)
		if absf(InputMap.action_get_deadzone(action) - 0.2) > 0.001:
			bad.append("%s deadzone" % action)
	for pair: Array in [[&"rover_forward", JOY_AXIS_TRIGGER_RIGHT], [&"rover_reverse", JOY_AXIS_TRIGGER_LEFT]]:
		var trigger: bool = false
		for event: InputEvent in InputMap.action_get_events(pair[0]):
			var motion := event as InputEventJoypadMotion
			if motion != null and motion.axis == pair[1] and motion.axis_value > 0.0:
				trigger = true
		if not trigger:
			bad.append("%s trigger" % pair[0])
	return "" if bad.is_empty() else "Movement bindings wrong: %s" % ", ".join(bad)


func test_the_keys_match_the_pause_and_buy_layout_rules() -> String:
	# Buys stay on the physical key (AZERTY needs no shift); pause is typed Esc like ui_cancel.
	var bad: PackedStringArray = []
	for i: int in 9:
		var action := StringName("buy_%d" % (i + 1))
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == 0:
				bad.append(String(action))
	for event: InputEvent in InputMap.action_get_events(&"open_pause"):
		if event is InputEventKey and (event as InputEventKey).keycode == 0:
			bad.append("open_pause")
	return "" if bad.is_empty() else "Wrong kind of key: %s" % ", ".join(bad)


func test_the_coop_strip_does_not_count_as_a_panel() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var coop := CoopUI.new()
	tree.root.add_child(coop)
	var problem: String = ""
	if QuestsUI.other_panel_open(tree):
		problem = "The closed co-op panel must not count as a panel."
	coop.open()
	if not QuestsUI.other_panel_open(tree):
		problem = "The open co-op panel must count."
	coop.free()
	return problem


func test_a_panel_keeps_the_stick_and_the_rover_buttons() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var holder := Control.new()
	holder.add_to_group(QuestsUI.MODAL_GROUP)
	tree.root.add_child(holder)
	var rover := RoverController.new()
	tree.root.add_child(rover)
	var problem: String = ""
	if not rover._panel_open():
		problem = "An open panel must hold the rover's till and zero-steering buttons."
	holder.hide()
	if rover._panel_open():
		problem = "With no panel open they must work."
	rover.free()
	holder.free()
	return problem


func test_the_chord_must_be_quick_and_a_single_shoulder_does_not_open() -> String:
	var sent: Array[StringName] = []
	var menu: ActionsMenuUI = _menu(ActionsMenuUI.farm_actions(), sent)
	var problem: String = ""
	menu._input(_shoulder(JOY_BUTTON_LEFT_SHOULDER, true))
	var token: int = ActionsMenuUI.chord_token
	# A slow second shoulder is two taps, not a chord.
	menu._lb_msec = Time.get_ticks_msec() - 600
	menu._input(_shoulder(JOY_BUTTON_RIGHT_SHOULDER, true))
	if menu.visible:
		problem = "A slow second shoulder must not open the menu."
	if ActionsMenuUI.chord_token != token:
		problem = "A shoulder press alone must not cancel a waiting set-point nudge (rapid taps each nudge)."
	if ActionsMenuUI.NUDGE_WAIT_S <= ActionsMenuUI.CHORD_GRACE_S:
		problem = "A nudge must wait longer than the chord window."
	# Let go of both and tap them together again.
	menu._input(_shoulder(JOY_BUTTON_LEFT_SHOULDER, false))
	menu._input(_shoulder(JOY_BUTTON_RIGHT_SHOULDER, false))
	menu._input(_shoulder(JOY_BUTTON_LEFT_SHOULDER, true))
	menu._input(_shoulder(JOY_BUTTON_RIGHT_SHOULDER, true))
	if not menu.visible:
		problem = "A quick chord must open the menu."
	elif ActionsMenuUI.chord_token == token:
		problem = "Opening the menu must cancel a waiting set-point nudge."
	menu.free()
	RoverController.input_blocked = false
	return problem


func test_the_bench_takes_focus_on_open() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var bench: CalBenchUI = (load("res://ui/cal_bench_ui.tscn") as PackedScene).instantiate()
	tree.root.add_child(bench)
	bench.open()
	var owner: Control = bench.get_viewport().gui_get_focus_owner()
	var problem: String = "" if owner != null else "The bench must open with a focused control."
	bench.free()
	return problem


func test_the_menu_pad_defaults_exist() -> String:
	var bad: PackedStringArray = []
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		if not _kinds(action)["pad"]:
			bad.append(String(action))
	return "" if bad.is_empty() else "No pad event: %s" % ", ".join(bad)


func _menu(actions: Array[StringName], sent: Array[StringName]) -> ActionsMenuUI:
	var menu := ActionsMenuUI.new(actions)
	menu.sender = func(action: StringName) -> void: sent.append(action)
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu


func _shoulder(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func test_the_menu_opens_on_both_shoulders_and_sends_the_pick() -> String:
	var sent: Array[StringName] = []
	var menu: ActionsMenuUI = _menu(ActionsMenuUI.farm_actions(), sent)
	var problem: String = ""
	menu._input(_shoulder(JOY_BUTTON_LEFT_SHOULDER, true))
	if menu.visible:
		problem = "One shoulder must not open it."
	menu._input(_shoulder(JOY_BUTTON_RIGHT_SHOULDER, true))
	if not menu.visible or not RoverController.input_blocked:
		problem = "LB and RB together must open it and hold the rover."
	elif menu._rows.get_child_count() != ActionsMenuUI.ENTRIES.size() or not (menu._rows.get_child(0) as Button).has_focus():
		problem = "It must list every entry and focus the first."
	else:
		(menu._rows.get_child(3) as Button).pressed.emit()
		if menu.visible or RoverController.input_blocked or sent != [&"survey"]:
			problem = "A pick must close it, free the rover and send its action: %s" % [sent]
	menu.free()
	RoverController.input_blocked = false
	return problem


func test_the_dome_menu_has_only_the_panels_and_b_closes_it() -> String:
	var sent: Array[StringName] = []
	var menu: ActionsMenuUI = _menu(ActionsMenuUI.PANEL_ACTIONS, sent)
	menu.open()
	var problem: String = ""
	if menu._rows.get_child_count() != ActionsMenuUI.PANEL_ACTIONS.size():
		problem = "The dome offers the panels only: quests, skills, co-op and controls."
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._unhandled_input(cancel)
	if menu.visible or RoverController.input_blocked:
		problem = "B must close it."
	menu.free()
	RoverController.input_blocked = false
	return problem


func test_start_opens_the_pause_panel_and_b_does_not() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	tree.root.add_child(pause)
	var problem: String = ""
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	pause._unhandled_input(cancel)
	if pause.visible:
		problem = "B alone must not open the pause panel."
	var start := InputEventAction.new()
	start.action = &"open_pause"
	start.pressed = true
	pause._unhandled_input(start)
	if not pause.visible:
		problem = "Start must open it."
	pause._unhandled_input(cancel)
	if pause.visible:
		problem = "B must close it."
	pause.free()
	tree.paused = false
	RoverController.input_blocked = false
	return problem


func test_start_does_not_open_pause_over_a_panel_and_close_restores_the_block() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	tree.root.add_child(pause)
	var holder := Control.new()
	holder.add_to_group(QuestsUI.MODAL_GROUP)
	tree.root.add_child(holder)
	var start := InputEventAction.new()
	start.action = &"open_pause"
	start.pressed = true
	var problem: String = ""
	pause._unhandled_input(start)
	if pause.visible:
		problem = "Start must not open pause over another panel."
	holder.free()
	RoverController.input_blocked = true
	pause._unhandled_input(start)
	pause.close()
	if not RoverController.input_blocked:
		problem = "Closing pause must put back the block it found."
	pause.free()
	tree.paused = false
	RoverController.input_blocked = false
	return problem


func test_a_running_minigame_consumes_back_and_l3() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var problem: String = ""
	var scenes: Array[String] = ["wring_the_blocks", "thread_the_spool", "torque_to_spec"]
	for name: String in scenes:
		var game: Control = (load("res://ui/minigames/%s.tscn" % name) as PackedScene).instantiate()
		tree.root.add_child(game)
		game._stage = 1
		game.set_process(false)
		for index: int in [JOY_BUTTON_BACK, JOY_BUTTON_LEFT_STICK]:
			tree.root.set_input_as_handled()
			var press := InputEventJoypadButton.new()
			press.button_index = index
			press.pressed = true
			game._unhandled_input(press)
			if not tree.root.is_input_handled():
				problem = "%s must consume pad button %d while running." % [name, index]
		game.free()
	return problem
