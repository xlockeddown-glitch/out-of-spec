extends RefCounted
## The controls guide and the Controls helper: labels come from the InputMap, the
## guide lists every action, F1 opens and closes it, and the prompts follow the device.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DomeScript: GDScript = preload("res://scripts/dome/dome_interior.gd")


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
		"open_controls": ["F1", ""], "buy_1": ["1", ""],
	}
	var bad: PackedStringArray = []
	for name: String in want:
		var got_key: String = Controls.key_label(StringName(name))
		var got_pad: String = Controls.pad_label(StringName(name))
		if got_key != want[name][0] or got_pad != want[name][1]:
			bad.append("%s: key %s pad %s" % [name, got_key, got_pad])
	return "" if bad.is_empty() else "Labels off: %s" % ", ".join(bad)


func test_stick_and_trigger_axes_are_named() -> String:
	var steer: String = Controls.pad_label(&"rover_steer_left")
	var gas: String = Controls.pad_label(&"rover_forward")
	var brake: String = Controls.pad_label(&"rover_reverse")
	if not "LS" in steer or not "RT" in gas or not "LT" in brake:
		return "Axes read %s, %s, %s" % [steer, gas, brake]
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
	var spot := RegEx.create_from_string("[Pp]ress [A-Z0-9]\\b|\\[(?:E|Y|R|Tab|Space)\\]|\\((?:Esc|K|O|T|F7)\\)")
	var found: PackedStringArray = []
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var n: int = 0
			for line: String in FileAccess.get_file_as_string(dir + "/" + file).split("\n"):
				n += 1
				if line.strip_edges().begins_with("#"):
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
