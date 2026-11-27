extends RefCounted
## The farm notice board (docs/design/biomes.md section 4): the three starter
## jobs from day 1, the board's place and words, the guest's way to it through
## FarmCommands, the one first-morning phone line, and that no quest text names a key.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const IDS: Array[String] = ["first_water", "read_the_probe", "first_calibration"]
const CELL := Vector3i(3, 0, 3)


## A new farm's first morning, with the clock at the start.
func _new_farm() -> GameStateScript:
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs._set_up_farm(77)
	gs.update_quests()
	return gs


func _commander(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


func _done(gs: GameStateScript, id: String) -> bool:
	var entry: Variant = gs.quest_state.get(id)
	return entry is Dictionary and int(entry.get("done", -1)) >= 0


func _starters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("board", "")) == NoticeBoard.FARM:
			out.append(quest)
	return out


# --- The jobs -------------------------------------------------------------------

func test_the_three_starter_jobs_parse() -> String:
	var found: Array[String] = []
	for quest: Dictionary in _starters():
		found.append(str(quest["id"]))
		var problem: String = QuestEngine.data_problem(quest)
		if problem != "":
			return "%s: %s" % [quest["id"], problem]
		if str(quest.get("giver", "")) != "lin" or (quest["steps"] as Array).size() > 2:
			return "%s has the wrong giver or too many steps." % quest["id"]
	found.sort()
	var want: Array[String] = IDS.duplicate()
	want.sort()
	return "" if found == want else "The farm board lists %s" % [found]


func test_the_jobs_are_offered_on_day_one_of_a_new_farm() -> String:
	var gs: GameStateScript = _new_farm()
	var missing: Array[String] = []
	for id: String in IDS:
		if not gs.quest_state.has(id):
			missing.append(id)
	gs.free()
	return "" if missing.is_empty() else "Not offered on day 1: %s" % [missing]


func test_each_step_completes_by_its_check() -> String:
	var gs: GameStateScript = _new_farm()
	var out: String = ""
	if not gs.till(CELL, HOST):
		out = "The test cell would not till."
	gs.update_quests()
	if out == "" and (_done(gs, "first_water") or gs.quest_state["first_water"]["steps_done"] != ["till"]):
		out = "Tilling should finish only the first step of first_water."
	if out == "":
		out = gs.plant_crop(CELL, "", gs.OFFSET_CURRENT, HOST)
	gs.update_quests()
	if out == "" and not _done(gs, "first_water"):
		out = "Till then plant did not finish first_water."
	if out == "":
		gs.read_probe(HOST)
		gs.update_quests()
		if not _done(gs, "read_the_probe"):
			out = "Reading the probe did not finish read_the_probe."
	if out == "":
		gs.cal_log.append({ "instrument_id": "hygrometer", "traceable": true, "day": 1 })
		gs.update_quests()
		if not _done(gs, "first_calibration"):
			out = "A calibration did not finish first_calibration."
	gs.free()
	return out


# --- The board ------------------------------------------------------------------

func test_the_board_is_reached_only_near_it() -> String:
	var near: Vector3 = NoticeBoard.FARM_POSITION + Vector3(0.0, 0.0, 2.0)
	var far: Vector3 = NoticeBoard.FARM_POSITION + Vector3(NoticeBoard.REACH_M + 3.0, 0.0, 0.0)
	if not NoticeBoard.farm_near(near):
		return "The rover beside the board cannot read it."
	return "" if not NoticeBoard.farm_near(far) else "The board can be read from far away."


func test_the_lines_read_not_offered_accepted_and_done() -> String:
	var quests: Array = _starters()
	var none: Array[String] = NoticeBoard.farm_lines(quests, {}, {})
	var open: Dictionary = {}
	for id: String in IDS:
		open[id] = { "steps_done": [], "done": -1 }
	var accepted: Array[String] = NoticeBoard.farm_lines(quests, open, {})
	var finished: Dictionary = { "first_water": { "steps_done": ["till", "plant"], "done": 3 } }
	var some: Array[String] = NoticeBoard.farm_lines(quests, finished, {})
	var water: int = 0
	for index: int in quests.size():
		if str(quests[index]["id"]) == "first_water":
			water = index
	if none.size() != 3 or not "Not offered" in none[0]:
		return "Not offered read %s" % [none]
	if accepted.size() != 3 or not "Accepted. Next: " in accepted[water] or not "Till a cell" in accepted[water]:
		return "Accepted read %s" % [accepted]
	if not "Done" in some[water] or some.size() != 3:
		return "Done read %s" % [some]
	return "" if NoticeBoard.farm_lines([], {}, {}) == ["BOARD: no notices."] else "An empty board read wrongly."


func test_interact_accepts_the_jobs_and_names_no_key() -> String:
	var gs: GameStateScript = _new_farm()
	gs.quest_state.clear()
	var text: String = gs.read_farm_board(HOST)
	var all_in: bool = true
	for id: String in IDS:
		all_in = all_in and gs.quest_state.has(id)
	gs.free()
	if not all_in:
		return "The board's interact left a job unaccepted."
	if text.count("BOARD:") != 3 or "[" in text:
		return "The host's board answer read: %s" % text
	return ""


# --- A guest --------------------------------------------------------------------

func test_a_guests_interact_goes_through_farm_commands() -> String:
	for action: StringName in [&"read_farm_board", &"read_probe"]:
		if not action in CommandsScript.ACTIONS:
			return "%s is not a FarmCommands action." % action
	var gs: GameStateScript = _new_farm()
	var commands: Node = _commander(gs)
	var bad: String = commands.problem(&"read_farm_board", [])
	var answer: Variant = commands.execute(GUEST, &"read_farm_board", [])
	commands.free()
	gs.free()
	if bad != "":
		return "read_farm_board was refused: %s" % bad
	return "" if answer is String and "BOARD:" in answer else "The guest got %s" % [answer]


func test_quest_state_reaches_a_guest_the_existing_way() -> String:
	return "" if FarmSync.SHOWN_BY.has(&"quests_changed") and "quest_state" in FarmSync.SHOWN_BY[&"quests_changed"] \
		else "FarmSync does not show quest_state on quests_changed."


# --- The first morning ----------------------------------------------------------

func _times(gs: GameStateScript) -> int:
	return gs.phone_log.count(GameStateScript.FARM_BOARD_LINE)


func test_the_first_morning_line_shows_once() -> String:
	var gs: GameStateScript = _new_farm()
	var once: int = _times(gs)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var loaded: GameStateScript = GameStateScript.new()
	var problem: String = loaded.farm_from_dict(data)
	var after_load: int = _times(loaded)
	var fresh: GameStateScript = GameStateScript.new()
	fresh.new_farm()
	var through_new: int = _times(fresh)
	gs.free()
	loaded.free()
	fresh.free()
	if problem != "":
		return problem
	return "" if once == 1 and after_load == 1 and through_new == 1 else \
		"The line showed %d, %d (after a load) and %d (new_farm) times." % [once, after_load, through_new]


func test_an_old_save_gets_no_extra_line() -> String:
	var gs: GameStateScript = _new_farm()
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	gs.free()
	var kept: Array = []
	for line: Variant in data["phone_log"]:
		if line != GameStateScript.FARM_BOARD_LINE:
			kept.append(line)
	data["phone_log"] = kept
	var loaded: GameStateScript = GameStateScript.new()
	var problem: String = loaded.farm_from_dict(data)
	var seen: int = _times(loaded)
	loaded.free()
	if problem != "":
		return problem
	return "" if seen == 0 else "A loaded save was given the line."


# --- No key in saved or sent text -----------------------------------------------

func test_the_jobs_name_no_key() -> String:
	var spot := RegEx.create_from_string("[Pp]ress |\\[[A-Za-z0-9]{1,5}\\]|\\((?:E|Y|R|Q|Esc|K|O|T|F\\d)\\)|\\bSpace\\b")
	var texts: Array[String] = []
	for quest: Dictionary in _starters():
		texts.append(str(quest.get("title", "")))
		texts.append(str(quest.get("offer_line", "")))
		for step: Variant in quest["steps"]:
			texts.append(str((step as Dictionary).get("text", "")))
	var file: FileAccess = FileAccess.open("res://data/dialogue_dispatches.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		return "The dialogue file did not parse."
	var lin_quests: Variant = ((parsed["npcs"] as Dictionary)["lin"] as Dictionary)["quests"]
	for key: String in lin_quests:
		for id: String in IDS:
			if key.begins_with(id):
				texts.append(str(lin_quests[key]))
	texts.append(GameStateScript.FARM_BOARD_LINE)
	for text: String in texts:
		if text == "" or spot.search(text) != null:
			return "A job's text is empty or names a key: '%s'" % text
	return ""
