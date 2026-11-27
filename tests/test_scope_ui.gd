extends RefCounted
## The "Meridiani Scope" look (feat/scope-ui): the shared theme, the bench and the
## quest board that use it, the verdict colours, the pad on both, and the NEW tag
## on the board (a local seen set, never saved to the farm and never sent).

const BENCH: PackedScene = preload("res://ui/cal_bench_ui.tscn")
const SEEN_PATH: String = "user://test_quests_seen.cfg"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func _pad(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await _frame()


func _bench() -> CalBenchUI:
	var bench: CalBenchUI = BENCH.instantiate()
	_root().add_child(bench)
	return bench


func _free(node: Node) -> void:
	_root().remove_child(node)
	node.free()


func _reset() -> void:
	Controls.last_device = Controls.Device.KEY
	Controls.pad_present_override = false
	Controls.reset_shown()


## One open quest put into the farm's quest state; returns [id, the old state].
func _offer_quest() -> Array:
	var saved: Dictionary = GameState.quest_state.duplicate(true)
	var id: String = ""
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("scope", "")) == "farm" and str(quest.get("kind", "")) in ["story", "lab"]:
			id = str(quest["id"])
			break
	GameState.quest_state[id] = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }
	return [id, saved]


func _restore(saved: Dictionary) -> void:
	GameState.quest_state = saved
	DirAccess.remove_absolute(SEEN_PATH)


func _new_tags(ui: QuestsUI) -> int:
	return ui.find_children("NewTag", "", true, false).size()


func test_the_theme_loads_with_a_big_focus_style() -> String:
	var theme: Theme = ScopeTheme.theme()
	if theme == null or theme != ScopeTheme.theme():
		return "The theme is built once and shared."
	var focus: StyleBox = theme.get_stylebox(&"focus", &"Button")
	if not focus is StyleBoxFlat:
		return "A button needs a focus style."
	var flat: StyleBoxFlat = focus
	if flat.border_width_left < 4 or flat.border_color != ScopeTheme.TEAL or flat.shadow_size < 8:
		return "The focus ring must be thick, teal and glow: %d, %s" % [flat.border_width_left, flat.border_color]
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		if not theme.has_stylebox(state, &"Button"):
			return "Button has no %s style." % state
	if not theme.has_stylebox(&"panel", ScopeTheme.SHELL) or not theme.has_stylebox(&"panel", ScopeTheme.GLASS):
		return "The shell and the glass need panel styles."
	if ScopeTheme.OPEN_SECONDS > 0.15:
		return "The open animation is at most 150 ms."
	return ""


func test_the_bench_and_the_quest_board_use_the_theme() -> String:
	var bench: CalBenchUI = _bench()
	var ui := QuestsUI.new()
	_root().add_child(ui)
	var problem: String = ""
	if bench.theme != ScopeTheme.theme() or ui.theme != ScopeTheme.theme():
		problem = "Both panels must carry ScopeTheme."
	elif (bench.get_node("Panel") as Control).theme_type_variation != ScopeTheme.SHELL:
		problem = "The bench panel must be the shell."
	_free(bench)
	_free(ui)
	return problem


func test_the_verdict_colour_is_teal_amber_or_red() -> String:
	var want: Dictionary = {
		DriftingSensor.Band.IN_BAND: ScopeTheme.TEAL,
		DriftingSensor.Band.GUARDBAND: ScopeTheme.AMBER,
		DriftingSensor.Band.OUT_OF_TOLERANCE: ScopeTheme.RED,
	}
	for band: int in want:
		if ScopeTheme.band_color(band) != want[band]:
			return "Band %d is %s, wanted %s" % [band, ScopeTheme.band_color(band), want[band]]
	var bench: CalBenchUI = _bench()
	var label: Label = bench.get_node("%ResultLabel")
	bench._paint_result(ScopeTheme.AMBER)
	var amber: bool = label.get_theme_color(&"font_color") == ScopeTheme.AMBER
	bench._paint_result(ScopeTheme.RED)
	var red: bool = label.get_theme_color(&"font_color") == ScopeTheme.RED
	_free(bench)
	return "" if amber and red else "The result line must take the verdict colour."


func test_the_chain_shows_as_chips() -> String:
	var bench: CalBenchUI = _bench()
	bench.open(GameState.STEERING_ID)
	var texts: PackedStringArray = []
	for child: Node in bench.get_node("%ChainRow").get_children():
		texts.append(ScopeTheme.chip_text(child as Control))
	var problem: String = ""
	if texts.size() < 2 or not texts[0].begins_with("Chain"):
		problem = "The chain is chips led by a Chain chip: %s" % [texts]
	_free(bench)
	return problem


func test_the_bench_buttons_take_the_pad_and_b_closes() -> String:
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var bench: CalBenchUI = _bench()
	bench.open(GameState.STEERING_ID)
	await _frame()
	var reached: Dictionary = {}
	var problem: String = ""
	if _root().gui_get_focus_owner() == null:
		problem = "The bench opens with a focus."
	else:
		reached[_root().gui_get_focus_owner()] = true
		for button: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT]:
			await _send(_pad(button))
			if _root().gui_get_focus_owner() != null:
				reached[_root().gui_get_focus_owner()] = true
		var close_button: Button = bench.get_node("%CloseButton")
		if reached.size() < 3 or not reached.has(bench.get_node("%CalibrateButton")) or close_button.focus_mode != Control.FOCUS_ALL:
			problem = "Focus moves must reach CALIBRATE (and CLOSE can focus): %s" % [reached.keys().map(func(c: Control) -> String: return str(c.name))]
		var glyph: Label = close_button.get_node("PadGlyph")
		if problem == "" and (not glyph.visible or glyph.text == ""):
			problem = "The close button shows its pad glyph on a pad."
	if problem == "":
		await _send(_pad(JOY_BUTTON_B))
		if bench.visible:
			problem = "B must close the bench."
	_free(bench)
	_reset()
	return problem


func test_the_quest_list_takes_the_pad_and_b_closes() -> String:
	var saved_path: String = QuestSeen.path
	QuestSeen.path = SEEN_PATH
	DirAccess.remove_absolute(SEEN_PATH)
	var offered: Array = _offer_quest()
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var ui := QuestsUI.new()
	_root().add_child(ui)
	ui.open()
	await _frame()
	var problem: String = ""
	await _send(_pad(JOY_BUTTON_DPAD_UP))
	var owner: Control = _root().gui_get_focus_owner()
	if owner == null or owner == ui._close_button or not owner is PanelContainer:
		problem = "Up from CLOSE must land on a quest card: %s" % owner
	elif not owner.get_node("FocusRing").visible:
		problem = "The focused card shows the big ring."
	if problem == "":
		await _send(_pad(JOY_BUTTON_B))
		if ui.visible:
			problem = "B must close the quest board."
	_free(ui)
	_reset()
	_restore(offered[1])
	QuestSeen.path = saved_path
	return problem


func test_a_new_quest_wears_a_new_tag_until_seen_and_nothing_is_saved_to_the_farm() -> String:
	var saved_path: String = QuestSeen.path
	QuestSeen.path = SEEN_PATH
	DirAccess.remove_absolute(SEEN_PATH)
	var offered: Array = _offer_quest()
	var before_state: Dictionary = GameState.quest_state.duplicate(true)
	var problem: String = ""
	var ui := QuestsUI.new()
	_root().add_child(ui)
	ui.open()
	var open_count: int = (QuestLog.of(GameState, GameState.local_player_id)[QuestLog.OPEN] as Array).size()
	if open_count < 1 or _new_tags(ui) != open_count:
		problem = "Every unseen open quest shows a NEW tag: %d of %d" % [_new_tags(ui), open_count]
	else:
		ui.close()
		ui.open()
		if _new_tags(ui) != 0:
			problem = "After it was seen the tag is gone: %d" % _new_tags(ui)
		elif GameState.quest_state != before_state:
			problem = "Seeing a quest must not change the farm's state."
		elif not FileAccess.file_exists(SEEN_PATH):
			problem = "The seen set is kept on this PC."
		elif not FileAccess.get_file_as_string(SEEN_PATH).contains(str(offered[0])):
			problem = "The seen file holds the quest key."
	_free(ui)
	_restore(offered[1])
	QuestSeen.path = saved_path
	return problem
