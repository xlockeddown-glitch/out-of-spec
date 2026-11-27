extends RefCounted
## Xbox controller play: every control is a named InputMap action with its key
## and, unless the actions menu carries it, a pad button; the menu sends the
## same actions the keys do.

## Keyboard-only on purpose: the pad reaches these through the actions menu.
const MENU_ONLY: Array[StringName] = [
	&"place_stone", &"check_block", &"block_stack", &"survey", &"sell_lin", &"wheel_service",
	&"open_robots", &"open_quests", &"open_skills", &"open_coop",
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
		&"open_quests": KEY_O, &"open_skills": KEY_K, &"open_coop": KEY_F7, &"buy_1": KEY_1, &"buy_9": KEY_9}
	var bad: PackedStringArray = []
	for action: StringName in keys:
		var event := InputEventKey.new()
		event.keycode = keys[action]
		event.pressed = true
		if not event.is_action(action):
			bad.append(String(action))
	return "" if bad.is_empty() else "Key no longer does it: %s" % ", ".join(bad)


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
	if menu._rows.get_child_count() != 3:
		problem = "The dome offers quests, skills and co-op only."
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
