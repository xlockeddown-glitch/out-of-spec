extends RefCounted
## The controls guide and the Controls helper: labels come from the InputMap, the
## guide lists every action, F1 opens and closes it, and the prompts follow the device.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DomeScript: GDScript = preload("res://scripts/dome/dome_interior.gd")
const HudScene: PackedScene = preload("res://ui/field_phone_hud.tscn")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _pad_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


## Puts the helper back as it was.
func _reset() -> void:
	Controls.last_device = Controls.Device.KEY
	Controls.pad_present_override = false
	Controls.hint_told = false


func test_labels_match_the_input_map() -> String:
	var want: Dictionary = {
		"interact": ["E", "A"], "rover_dig": ["G", "X"], "open_pause": ["Esc", "Start"],
		"setpoint_up": ["]", "RB"], "setpoint_down": ["[", "LB"], "swap_scene": ["Tab", "View"],
		"open_controls": ["F1", ""], "buy_1": ["1", ""], "ui_accept": ["Space", "A"],
	}
	var bad: PackedStringArray = []
	for name: String in want:
		var got_key: String = Controls.key_label(StringName(name))
		var got_pad: String = Controls.pad_label(StringName(name))
		if got_key != want[name][0] or got_pad != want[name][1]:
			bad.append("%s: key %s pad %s" % [name, got_key, got_pad])
	return "" if bad.is_empty() else "Labels off: %s" % ", ".join(bad)


func test_stick_and_trigger_axes_are_named() -> String:
	var want: Dictionary = {
		"rover_steer_left": "LS left", "rover_steer_right": "LS right",
		"rover_forward": "LS up / RT", "rover_reverse": "LS down / LT",
	}
	var bad: PackedStringArray = []
	for action: String in want:
		var got: String = Controls.pad_label(StringName(action))
		if got != want[action]:
			bad.append("%s reads \"%s\", not \"%s\"" % [action, got, want[action]])
	return "" if bad.is_empty() else "Axes: %s" % "; ".join(bad)


func test_the_game_says_space_for_accept_and_keeps_the_other_keys() -> String:
	var all: String = Controls.key_labels(&"ui_accept")
	if not all.begins_with("Space") or not "Enter" in all:
		return "ui_accept must list Space first and still know Enter: %s" % all
	var digit := InputEventKey.new()
	digit.physical_keycode = KEY_1
	if Controls._key_name(digit) != "1":
		return "A digit stays a digit, not %s" % Controls._key_name(digit)
	return ""


func test_an_unknown_action_has_no_label() -> String:
	if Controls.key_label(&"no_such_action") != "" or Controls.pad_label(&"no_such_action") != "":
		return "An action that does not exist must give no label"
	return ""


func test_the_guide_lists_only_real_actions() -> String:
	var missing: PackedStringArray = []
	for action: StringName in ControlsGuideUI.listed_actions():
		if not InputMap.has_action(action):
			missing.append(String(action))
	return "" if missing.is_empty() else "Not in the InputMap: %s" % ", ".join(missing)


func test_the_guide_lists_every_action() -> String:
	var listed: Array[StringName] = ControlsGuideUI.listed_actions()
	var absent: PackedStringArray = []
	for action: StringName in InputMap.get_actions():
		var name: String = String(action)
		# The engine's own ui_ actions are the guide's only if it names them.
		if name.begins_with("ui_") and not name in ["ui_accept", "ui_cancel"]:
			continue
		if not listed.has(action):
			absent.append(name)
	return "" if absent.is_empty() else "The guide leaves out: %s" % ", ".join(absent)


func test_every_action_the_scripts_use_is_in_the_guide() -> String:
	var reads := RegEx.create_from_string("(?:is_action_(?:just_)?(?:pressed|released)|get_axis)\\(&\"(\\w+)\"(?:, &\"(\\w+)\")?")
	var listed: Array[StringName] = ControlsGuideUI.listed_actions()
	var absent: PackedStringArray = []
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			for found: RegExMatch in reads.search_all(FileAccess.get_file_as_string(dir + "/" + file)):
				for i: int in [1, 2]:
					var name: String = found.get_string(i)
					if name != "" and not name.begins_with("ui_") and not listed.has(StringName(name)) and not name in absent:
						absent.append(name)
	return "" if absent.is_empty() else "Used in scripts but not in the guide: %s" % ", ".join(absent)


func test_every_group_has_a_title_and_lines() -> String:
	var titles: PackedStringArray = []
	for group: Dictionary in ControlsGuideUI.GROUPS:
		if (group["lines"] as Array).is_empty():
			return "%s has no lines" % group["title"]
		titles.append(group["title"])
	for want: String in ["DRIVING", "ON FOOT", "FARMING", "BUILDING AND STONE", "MENUS", "SHOPPING"]:
		if not want in titles:
			return "No %s group" % want
	return ""


## On foot the walker moves and the player gets in or out. Interact is refused there.
func test_on_foot_lists_walking_not_interact() -> String:
	for group: Dictionary in ControlsGuideUI.GROUPS:
		var actions: Array[StringName] = []
		for line: Dictionary in group["lines"]:
			if line.has("move"):
				actions.append(&"walk")
			elif line.has("action"):
				actions.append(line["action"])
		if group["title"] == "ON FOOT":
			if not actions.has(&"walk") or actions.has(&"interact"):
				return "ON FOOT must list walking and not interact: %s" % [actions]
		if group["title"] == "DRIVING" and not actions.has(&"interact"):
			return "Interact (the bay, the pads) belongs under DRIVING"
	return ""


func test_prompt_switches_with_the_last_device() -> String:
	_reset()
	Controls.pad_present_override = true
	var problem: String = ""
	Controls.note_event(_key(KEY_E))
	if Controls.prompt(&"interact") != "E":
		problem = "On the keyboard it must say E, not %s" % Controls.prompt(&"interact")
	Controls.note_event(_pad_button(JOY_BUTTON_X))
	if problem == "" and Controls.prompt(&"interact") != "A":
		problem = "On the pad it must say A, not %s" % Controls.prompt(&"interact")
	if problem == "" and Controls.prompt(&"sell_lin") != "LB + RB > SELL TO LIN":
		problem = "A menu-only verb points to the menu, not %s" % Controls.prompt(&"sell_lin")
	Controls.note_event(_key(KEY_W))
	if problem == "" and Controls.prompt(&"interact") != "E":
		problem = "Back on the keyboard it must say E again"
	_reset()
	return problem


func test_a_small_stick_nudge_does_not_switch_to_the_pad() -> String:
	_reset()
	Controls.pad_present_override = true
	var nudge := InputEventJoypadMotion.new()
	nudge.axis = JOY_AXIS_LEFT_X
	nudge.axis_value = 0.2
	Controls.note_event(nudge)
	var stayed: bool = Controls.last_device == Controls.Device.KEY
	nudge.axis_value = 0.9
	Controls.note_event(nudge)
	var moved: bool = Controls.last_device == Controls.Device.PAD
	_reset()
	return "" if stayed and moved else "A light nudge is drift; a hard push is the pad"


func test_with_no_pad_the_prompt_is_always_the_key() -> String:
	_reset()
	Controls.last_device = Controls.Device.PAD
	var got: String = Controls.prompt(&"interact")
	_reset()
	return "" if got == "E" else "No pad is plugged in, so the prompt must be the key, not %s" % got


func test_the_first_launch_line_follows_the_device_and_is_told_once() -> String:
	_reset()
	var problem: String = ""
	if Controls.hint_text() != "Press F1 for the controls.":
		problem = "Keyboard only: %s" % Controls.hint_text()
	Controls.pad_present_override = true
	if problem == "" and not ("F1" in Controls.hint_text() and "LB + RB > CONTROLS" in Controls.hint_text()):
		problem = "A pad is plugged in: %s" % Controls.hint_text()
	Controls.last_device = Controls.Device.PAD
	if problem == "" and "F1" in Controls.hint_text():
		problem = "On the pad the line must not name the key: %s" % Controls.hint_text()
	_reset()
	var lines: Array[String] = []
	var phone := _FakePhone.new(lines)
	Controls.tell_once(phone)
	Controls.tell_once(phone)
	_reset()
	if problem == "" and lines.size() != 1:
		problem = "The line is told once per run, not %d times" % lines.size()
	return problem


func test_rewritten_prompts_use_the_helper() -> String:
	_reset()
	var both: Array[String] = ["player_1", "player_2"]
	var coop: String = CoopUI.strip_text(both, "player_1", true, false)
	var hint: String = DomeScript.default_hint()
	var problem: String = ""
	if not ("(%s)" % Controls.prompt(&"open_coop")) in coop:
		problem = "The co-op strip must name the helper's key: %s" % coop
	elif not Controls.prompt(&"swap_scene") in hint or not Controls.prompt(&"open_skills") in hint:
		problem = "The dome hint must name the helper's keys: %s" % hint
	# On the pad the same lines name the pad way.
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	if problem == "" and not ("(%s)" % Controls.prompt(&"open_coop")) in CoopUI.strip_text(both, "player_1", true, false):
		problem = "On the pad the co-op strip must change"
	if problem == "" and not "LB + RB" in DomeScript.default_hint():
		problem = "On the pad the dome hint must name the menu"
	_reset()
	return problem


func test_stored_text_names_no_key() -> String:
	var hint: String = GameStateScript.SENTINEL_HINT
	for bad: String in ["(L)", "(K)", "press E", "Press E"]:
		if bad in hint:
			return "Text that is saved and sent must not name a key: %s" % hint
	return ""


func test_no_script_hard_codes_a_key_in_a_prompt() -> String:
	# A key named inside a string: "press X", "X does", "X: ...", "[%d]", "[ and ]", Space.
	var spot := RegEx.create_from_string("[Pp]ress [A-Z0-9]\\b|\\[(?:E|Y|R|Tab|Space|%d)\\]|\\((?:Esc|K|O|T|F7)\\)"
		+ "|\"[A-Z]: |[^\\w%][A-Z0-9] (?:does|checks|fills|shows|gets|changes|moves|again|plants|digs|opens|closes)\\b"
		+ "|\\[ and \\]|\\bSpace\\b")
	var found: PackedStringArray = []
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			if file == "controls.gd":
				continue
			var n: int = 0
			for line: String in FileAccess.get_file_as_string(dir + "/" + file).split("\n"):
				n += 1
				if line.strip_edges().begins_with("#") or "A picks, B closes." in line:
					continue
				if spot.search(line) != null and "\"" in line:
					found.append("%s/%s:%d" % [dir, file, n])
	return "" if found.is_empty() else "Hard-coded key in a prompt: %s" % ", ".join(found)


func _guide() -> ControlsGuideUI:
	var guide := ControlsGuideUI.new()
	_root().add_child(guide)
	return guide


func test_f1_opens_the_guide_and_f1_or_cancel_closes_it() -> String:
	var guide: ControlsGuideUI = _guide()
	guide._unhandled_input(_key(KEY_F1))
	var problem: String = ""
	if not guide.visible:
		problem = "F1 must open the guide"
	elif not guide._close_button.has_focus():
		problem = "The guide must hold the focus so a pad can reach it"
	if problem == "":
		guide._unhandled_input(_key(KEY_F1))
		if guide.visible:
			problem = "F1 must close it again"
	if problem == "":
		guide._unhandled_input(_key(KEY_F1))
		var cancel := InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = true
		guide._unhandled_input(cancel)
		if guide.visible:
			problem = "ui_cancel must close it"
	_root().remove_child(guide)
	guide.free()
	return problem


func test_the_guide_does_not_open_over_another_panel() -> String:
	var guide: ControlsGuideUI = _guide()
	var other := Control.new()
	other.add_to_group(QuestsUI.MODAL_GROUP)
	_root().add_child(other)
	guide._unhandled_input(_key(KEY_F1))
	var opened: bool = guide.visible
	_root().remove_child(other)
	other.free()
	_root().remove_child(guide)
	guide.free()
	return "The guide opened over another panel" if opened else ""


func test_the_actions_menu_can_open_the_guide() -> String:
	for entry: Dictionary in ActionsMenuUI.ENTRIES:
		if entry["action"] == Controls.CONTROLS_ACTION:
			return "" if ActionsMenuUI.PANEL_ACTIONS.has(Controls.CONTROLS_ACTION) else "The dome menu must offer the guide too"
	return "The actions menu has no entry for the guide"


## A phone that only keeps what it is told.
class _FakePhone extends RefCounted:
	var lines: Array[String]

	func _init(into: Array[String]) -> void:
		lines = into

	func push_log(text: String) -> void:
		lines.append(text)


## An open guide stops the rover and the walker (they poll the stick), and the
## block goes back to what it was.
func test_the_guide_holds_the_rover_and_gives_it_back() -> String:
	var guide: ControlsGuideUI = _guide()
	var problem: String = ""
	RoverController.input_blocked = false
	guide.open()
	if not RoverController.input_blocked:
		problem = "An open guide must block the rover"
	guide.close()
	if problem == "" and RoverController.input_blocked:
		problem = "Closing must unblock it"
	RoverController.input_blocked = true
	guide.open()
	guide.close()
	if problem == "" and not RoverController.input_blocked:
		problem = "A block that was already there must stay"
	RoverController.input_blocked = false
	guide.open()
	_root().remove_child(guide)
	guide.free()
	if problem == "" and RoverController.input_blocked:
		problem = "Tearing the guide down while open must unblock the rover"
	RoverController.input_blocked = false
	return problem


func test_the_guide_closes_on_the_open_action_too() -> String:
	var guide: ControlsGuideUI = _guide()
	guide.open()
	var problem: String = ""
	var close := InputEventAction.new()
	close.action = Controls.CONTROLS_ACTION
	close.pressed = true
	guide._unhandled_input(close)
	if guide.visible:
		problem = "The open_controls action must close it"
	_root().remove_child(guide)
	guide.free()
	RoverController.input_blocked = false
	return problem


## F7 and K must not open on top of the guide.
func test_co_op_and_skills_stay_shut_over_the_guide() -> String:
	var guide: ControlsGuideUI = _guide()
	guide.open()
	var coop := CoopUI.new()
	_root().add_child(coop)
	var skills := SkillsUI.new()
	_root().add_child(skills)
	coop._unhandled_input(_key(KEY_F7))
	skills._unhandled_input(_key(KEY_K))
	var problem: String = ""
	if coop._panel.visible:
		problem = "F7 opened the co-op panel over the guide"
	elif skills.visible:
		problem = "K opened the skills view over the guide"
	guide.close()
	coop._unhandled_input(_key(KEY_F7))
	if problem == "" and not coop._panel.visible:
		problem = "With the guide shut, F7 must open the co-op panel"
	for node: Node in [coop, skills, guide]:
		_root().remove_child(node)
		node.free()
	RoverController.input_blocked = false
	return problem


## The pad's actions menu (LB + RB) opens the guide, end to end.
func test_the_actions_menu_opens_the_guide_end_to_end() -> String:
	var guide: ControlsGuideUI = _guide()
	var menu := ActionsMenuUI.new(ActionsMenuUI.PANEL_ACTIONS)
	menu.sender = func(action: StringName) -> void:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		guide._unhandled_input(event)
	_root().add_child(menu)
	menu.open()
	var problem: String = "The menu has no CONTROLS button"
	for row: Node in menu._rows.get_children():
		if row is Button and (row as Button).text.begins_with("CONTROLS"):
			(row as Button).pressed.emit()
			problem = ""
			break
	if problem == "" and (menu.visible or not guide.visible):
		problem = "Picking CONTROLS must close the menu and open the guide"
	elif problem == "" and not RoverController.input_blocked:
		problem = "The open guide must hold the rover"
	guide.close()
	if problem == "" and RoverController.input_blocked:
		problem = "Closing the guide must free the rover"
	for node: Node in [menu, guide]:
		_root().remove_child(node)
		node.free()
	RoverController.input_blocked = false
	return problem


## The watcher sees a pad press even when a scene would eat it, and stays last.
func test_the_observer_sees_events_first_and_stays_last() -> String:
	_reset()
	var watcher: Controls.Observer = Controls.install_observer(Engine.get_main_loop() as SceneTree)
	var problem: String = ""
	if watcher.process_mode != Node.PROCESS_MODE_ALWAYS:
		problem = "It must run while the game is paused"
	Controls.pad_present_override = true
	watcher._input(_pad_button(JOY_BUTTON_A))
	if problem == "" and Controls.last_device != Controls.Device.PAD:
		problem = "A pad button must flip the device"
	var late := Node.new()
	_root().add_child(late)
	watcher.keep_last()
	if problem == "" and _root().get_child(_root().get_child_count() - 1) != watcher:
		problem = "The watcher must be the last child of the root"
	if problem == "" and Controls.install_observer(Engine.get_main_loop() as SceneTree) != watcher:
		problem = "Installing twice must not add a second watcher"
	_root().remove_child(late)
	late.free()
	_reset()
	return problem


func _hud() -> FieldPhoneHUD:
	var hud: FieldPhoneHUD = HudScene.instantiate()
	_root().add_child(hud)
	return hud


## The phone's key text follows the device in use, including Bram's two buttons,
## and goes back to keys when the pad is unplugged. No label grows on the pad.
func test_the_phone_follows_the_device_and_the_unplugging() -> String:
	_reset()
	var hud: FieldPhoneHUD = _hud()
	hud.show_bram("hello", 5, 9, false)
	hud.show_wheel_service("Wheel nuts due", true)
	hud._process(0.0)
	var keys: Array[String] = [Controls.key_label(&"rover_zero_steering"), Controls.key_label(&"interact"),
		Controls.key_label(&"wheel_service")]
	var problem: String = ""
	if not ("[%s]" % keys[0]) in hud._zero_button.text or not ("[%s]" % keys[1]) in hud._trade_button.text \
			or not ("[%s]" % keys[2]) in hud._wheels_button.text:
		problem = "On the keyboard: %s | %s | %s" % [hud._zero_button.text, hud._trade_button.text, hud._wheels_button.text]
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	hud._process(0.0)
	var pad_texts: Array[String] = [hud._zero_button.text, hud._dome_button.text, hud._trade_button.text, hud._wheels_button.text]
	if problem == "":
		for text: String in pad_texts:
			var open: int = text.rfind("[")
			if open < 0 or text.length() - open > 8:
				problem = "A pad label must stay short: %s" % text
		if ("[%s]" % keys[1]) in hud._trade_button.text or ("[%s]" % keys[2]) in hud._wheels_button.text:
			problem = "On the pad the keys must go: %s" % [pad_texts]
		elif not "[A]" in hud._trade_button.text:
			problem = "The trade button must show the pad button: %s" % hud._trade_button.text
	# The pad is unplugged: the keys come back with no new key press.
	Controls.pad_present_override = false
	hud._process(0.0)
	if problem == "" and not (("[%s]" % keys[1]) in hud._trade_button.text and ("[%s]" % keys[0]) in hud._zero_button.text):
		problem = "Unplugging must bring the keys back: %s | %s" % [hud._trade_button.text, hud._zero_button.text]
	_root().remove_child(hud)
	hud.free()
	_reset()
	return problem
