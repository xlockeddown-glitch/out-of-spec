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


## `open_count` open and `done_count` done farm quests put into the farm's quest state;
## returns [the first id, the old state]. The seen file starts clean.
func _offer_quests(open_count: int = 1, done_count: int = 0) -> Array:
	QuestSeen.path = SEEN_PATH
	QuestSeen.reset()
	DirAccess.remove_absolute(SEEN_PATH)
	var saved: Dictionary = GameState.quest_state.duplicate(true)
	var ids: Array[String] = []
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("scope", "")) == "farm" and str(quest.get("kind", "")) in ["story", "lab"]:
			ids.append(str(quest["id"]))
	for i: int in open_count + done_count:
		GameState.quest_state[ids[i]] = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": (-1 if i < open_count else 3) }
	return [ids[0], saved]


func _restore(saved: Dictionary, saved_path: String) -> void:
	GameState.quest_state = saved
	DirAccess.remove_absolute(SEEN_PATH)
	QuestSeen.path = saved_path
	QuestSeen.reset()


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
	if (bench.get_node("Panel") as Control).theme != ScopeTheme.theme() or ui.theme != ScopeTheme.theme():
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


func _chain_texts(bench: CalBenchUI) -> PackedStringArray:
	var texts: PackedStringArray = []
	for child: Node in bench.get_node("%ChainRow").get_children():
		texts.append(ScopeTheme.chip_text(child as Control))
	return texts


## The first standard, with no reference on this bench (its calibrator not owned).
func _unreferenced_standard() -> String:
	var id: String = GameState.standard_ids()[0]
	var sensor: DriftingSensor = GameState.get_sensor(id)
	GameState.owned_standards.erase(sensor.calibrated_by)
	return id


func test_the_chain_shows_as_chips() -> String:
	var bench: CalBenchUI = _bench()
	bench.open(GameState.STEERING_ID)
	var texts: PackedStringArray = _chain_texts(bench)
	var problem: String = ""
	if texts.size() < 2 or not texts[0].begins_with("Chain"):
		problem = "The chain is chips led by a Chain chip: %s" % [texts]
	_free(bench)
	return problem


## M1: a standard with no reference shows its own chain, opened straight on it or
## picked after another instrument.
func test_a_standard_with_no_reference_shows_its_own_chain() -> String:
	var owned: Dictionary = GameState.owned_standards.duplicate()
	var id: String = _unreferenced_standard()
	var bench: CalBenchUI = _bench()
	bench.open(id)
	var direct: PackedStringArray = _chain_texts(bench)
	bench.open(GameState.STEERING_ID)
	var steering: PackedStringArray = _chain_texts(bench)
	bench._on_instrument_selected(bench._ids.find(id))
	var picked: PackedStringArray = _chain_texts(bench)
	var problem: String = ""
	if direct.is_empty() or not direct[0].begins_with("Chain"):
		problem = "Opened on the standard, the chain shows: %s" % [direct]
	elif picked != direct or picked == steering:
		problem = "Picked after the steering encoder, the chain is the standard's own: %s vs %s" % [picked, steering]
	_free(bench)
	GameState.owned_standards = owned
	return problem


## S1: the red edge of a failing unit is not left on the cards of a standard.
func test_a_failing_unit_leaves_no_edge_on_a_standard_card() -> String:
	var owned: Dictionary = GameState.owned_standards.duplicate()
	var id: String = _unreferenced_standard()
	var steering: DriftingSensor = GameState.steering
	var error: float = steering.error
	steering.error = steering.mpe * 3.0
	var bench: CalBenchUI = _bench()
	bench.open(GameState.STEERING_ID)
	var found: PanelContainer = bench.get_node("%FoundCol")
	var edge: Color = (found.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color
	var problem: String = ""
	if edge == ScopeTheme.GLASS_LINE:
		problem = "The test needs a failing unit with a coloured edge."
	else:
		bench._on_instrument_selected(bench._ids.find(id))
		for card: PanelContainer in [found, bench.get_node("%LeftCol")]:
			if (card.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color != ScopeTheme.GLASS_LINE:
				problem = "A standard with no reference leaves a stale edge on %s." % card.name
	_free(bench)
	steering.error = error
	GameState.owned_standards = owned
	return problem


func _focus_after(button: JoyButton) -> Control:
	await _send(_pad(button))
	return _root().gui_get_focus_owner()


func test_the_bench_pad_walks_to_close_and_b_closes() -> String:
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var bench: CalBenchUI = _bench()
	bench.open(GameState.STEERING_ID)
	await _frame()
	var calibrate: Button = bench.get_node("%CalibrateButton")
	var close_button: Button = bench.get_node("%CloseButton")
	var problem: String = ""
	if _root().gui_get_focus_owner() == null:
		problem = "The bench opens with a focus."
	else:
		calibrate.grab_focus()
		var owner: Control = await _focus_after(JOY_BUTTON_DPAD_RIGHT)
		if owner != close_button:
			problem = "Right from CALIBRATE must reach CLOSE, not %s." % owner
		elif not (close_button.get_node("PadGlyph") as Label).visible:
			problem = "The close button shows its pad glyph on a pad."
	if problem == "":
		await _send(_pad(JOY_BUTTON_B))
		if bench.visible:
			problem = "B must close the bench."
	_free(bench)
	_reset()
	return problem


## The same walk on a standard with no reference: CALIBRATE is hidden, SEND is shown.
func test_the_bench_pad_walks_from_send_to_close() -> String:
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var owned: Dictionary = GameState.owned_standards.duplicate()
	var id: String = _unreferenced_standard()
	var bench: CalBenchUI = _bench()
	bench.open(id)
	await _frame()
	var send: Button = bench._send_button
	var problem: String = ""
	if bench.get_node("%CalibrateButton").visible or not send.visible or send.disabled:
		problem = "The test needs SEND shown and CALIBRATE hidden."
	else:
		send.grab_focus()
		var owner: Control = await _focus_after(JOY_BUTTON_DPAD_RIGHT)
		if owner != bench.get_node("%CloseButton"):
			problem = "Right from SEND must reach CLOSE, not %s." % owner
		else:
			owner = await _focus_after(JOY_BUTTON_DPAD_LEFT)
			if owner != send:
				problem = "Left from CLOSE must come back to SEND, not %s." % owner
	_free(bench)
	GameState.owned_standards = owned
	_reset()
	return problem


func test_the_quest_list_takes_the_pad_and_b_closes() -> String:
	var saved_path: String = QuestSeen.path
	var offered: Array = _offer_quests()
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
	_restore(offered[1], saved_path)
	return problem


## M3: the done list is a focus stop, so a pad or the keys can scroll to it.
func test_the_done_list_can_be_reached_by_the_pad() -> String:
	var saved_path: String = QuestSeen.path
	var offered: Array = _offer_quests(1, 1)
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var ui := QuestsUI.new()
	_root().add_child(ui)
	ui.open()
	await _frame()
	var problem: String = ""
	var done: Control = ui.find_child("DoneStop", true, false)
	if done == null or done.focus_mode != Control.FOCUS_ALL:
		problem = "The done list must be a focus stop."
	else:
		var owner: Control = await _focus_after(JOY_BUTTON_DPAD_UP)
		if owner != done:
			problem = "Up from CLOSE must reach the done list, not %s." % owner
		elif not done.get_node("FocusRing").visible:
			problem = "The done list shows the big ring when focused."
		else:
			owner = await _focus_after(JOY_BUTTON_DPAD_UP)
			if owner == null or owner == done or owner == ui._close_button:
				problem = "Up again must reach the open quest card, not %s." % owner
	_free(ui)
	_reset()
	_restore(offered[1], saved_path)
	return problem


## S3: a rebuild of the list (a quest ticked while the board is open) keeps a focus.
func test_a_rebuild_of_the_quest_list_keeps_the_pad_focus() -> String:
	var saved_path: String = QuestSeen.path
	var offered: Array = _offer_quests(2)
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	var ui := QuestsUI.new()
	_root().add_child(ui)
	ui.open()
	await _frame()
	await _send(_pad(JOY_BUTTON_DPAD_UP))
	var before: Control = _root().gui_get_focus_owner()
	var problem: String = ""
	if before == null or before == ui._close_button:
		problem = "The test needs a card focused first."
	else:
		ui._refresh()
		var after: Control = _root().gui_get_focus_owner()
		if after == null or after == before or not after is PanelContainer or not ui.is_ancestor_of(after):
			problem = "After a rebuild a new card holds the focus: %s" % after
	_free(ui)
	_reset()
	_restore(offered[1], saved_path)
	return problem


func test_a_new_quest_wears_a_new_tag_until_seen_and_nothing_is_saved_to_the_farm() -> String:
	var saved_path: String = QuestSeen.path
	var offered: Array = _offer_quests()
	var before_state: Dictionary = GameState.quest_state.duplicate(true)
	var problem: String = ""
	var ui := QuestsUI.new()
	_root().add_child(ui)
	ui.open()
	var open_count: int = (QuestLog.of(GameState, GameState.local_player_id)[QuestLog.OPEN] as Array).size()
	if str(offered[0]) == "" or open_count < 1 or _new_tags(ui) != open_count:
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
	_restore(offered[1], saved_path)
	return problem


## M2: a daily ask is new again each day it is asked. The day comes from the clock, so
## nothing is added to the save.
func test_a_daily_ask_is_new_again_on_another_day() -> String:
	var saved_path: String = QuestSeen.path
	var saved_days: float = GameClock.elapsed_days
	QuestSeen.path = SEEN_PATH
	QuestSeen.reset()
	DirAccess.remove_absolute(SEEN_PATH)
	var row: Dictionary = { "id": "daily_lin_reeds", "kind": QuestEngine.KIND_DAILY, "day": -1 }
	GameClock.elapsed_days = 2.0
	var problem: String = ""
	if not QuestSeen.is_new(row):
		problem = "A daily ask not seen is new."
	else:
		QuestSeen.mark_seen([row])
		if QuestSeen.is_new(row):
			problem = "The same day's ask is not new once seen."
		else:
			GameClock.elapsed_days = 8.0
			if not QuestSeen.is_new(row):
				problem = "Lin's ask on another day is new again."
	GameClock.elapsed_days = saved_days
	_restore(GameState.quest_state, saved_path)
	return problem
