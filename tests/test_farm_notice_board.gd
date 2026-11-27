extends RefCounted
## The farm notice board (docs/design/biomes.md section 4): the three starter
## jobs on a young farm, the board's place, reach and words, the guest's way to
## it through FarmCommands, the one first-morning phone line, and that no quest
## text names a key.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const IDS: Array[String] = ["first_water", "read_the_probe", "first_calibration"]
const CELL := Vector3i(3, 0, 3)


## A new farm's first morning, with the clock at the start. Callers put the clock back.
func _new_farm() -> GameStateScript:
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs._set_up_farm(77)
	gs.update_quests()
	return gs


## Runs `body` on a new farm, then frees it and puts the clock back.
func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _new_farm()
	var out: Variant = body.call(gs)
	gs.free()
	GameClock.elapsed_days = saved
	return out if out is String else "The test did not return a String."


## A farm that has not been looked at yet, its rover parked at `at`, day 1.
func _fresh_with_rover(at: Vector3) -> GameStateScript:
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs._set_up_farm(77)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, at)
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
		if str((quest["offer"] as Dictionary).get("when", "")) != "day_at_most":
			return "%s is not offered to a young farm only." % quest["id"]
	found.sort()
	var want: Array[String] = IDS.duplicate()
	want.sort()
	return "" if found == want else "The farm board lists %s" % [found]


func test_the_jobs_are_offered_on_day_one_of_a_new_farm() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var missing: Array[String] = []
		for id: String in IDS:
			if not gs.quest_state.has(id):
				missing.append(id)
		return "" if missing.is_empty() else "Not offered on day 1: %s" % [missing])


func test_each_step_completes_by_its_check() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var commands: Node = _commander(gs)
		gs.till(CELL, HOST)
		gs.update_quests()
		if _done(gs, "first_water"):
			return "Tilling alone finished first_water."
		var planted: String = gs.plant_crop(CELL, "", gs.OFFSET_CURRENT, HOST)
		gs.update_quests()
		if planted != "" or not _done(gs, "first_water"):
			return "Till then plant did not finish first_water: %s" % planted
		# A guest on foot reads the probe through the command.
		CoopWalkers.out[GUEST] = []
		var read: Variant = commands.execute(GUEST, &"read_probe", [])
		CoopWalkers.out.erase(GUEST)
		commands.free()
		gs.update_quests()
		if read != "" or not _done(gs, "read_the_probe"):
			return "A read of the probe on foot did not finish read_the_probe: '%s'" % [read]
		gs.cal_log.append({ "instrument_id": "hygrometer", "traceable": true, "day": 1, "performed_by": HOST })
		gs.update_quests()
		return "" if _done(gs, "first_calibration") else "A bench calibration did not finish first_calibration.")


func test_first_water_finishes_on_a_fully_tilled_plot() -> String:
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs._set_up_farm(77)
	for x: int in range(GameStateScript.PLOT.position.x, GameStateScript.PLOT.end.x):
		for z: int in range(GameStateScript.PLOT.position.y, GameStateScript.PLOT.end.y):
			gs.tilled_cells[Vector3i(x, 0, z)] = true
	gs.update_quests()
	var planted: String = gs.plant_crop(CELL, "", gs.OFFSET_CURRENT, HOST)
	gs.update_quests()
	var done: bool = _done(gs, "first_water")
	gs.free()
	GameClock.elapsed_days = 0.0
	return "" if done else "first_water stuck on a fully tilled plot (%s)." % planted


func test_zero_steering_and_the_grace_row_are_not_a_calibration() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var before: int = gs.cal_log.size()
		gs.zero_steering(HOST)
		gs.update_quests()
		if gs.cal_log.size() == before or _done(gs, "first_calibration"):
			return "Zero steering (an untraceable row) counted as a calibration."
		gs.cal_log.append({ "instrument_id": "hygrometer", "traceable": true, "day": 1, "performed_by": GameStateScript.MANAGER_ID })
		gs.update_quests()
		if _done(gs, "first_calibration"):
			return "The Manager's grace calibration counted."
		gs.cal_log.append({ "instrument_id": "hygrometer", "traceable": true, "day": 1, "performed_by": GUEST })
		gs.update_quests()
		return "" if _done(gs, "first_calibration") else "A real bench calibration by a player did not count.")


func test_an_old_farm_is_never_given_the_jobs() -> String:
	GameClock.elapsed_days = 0.0
	var first: GameStateScript = GameStateScript.new()
	first._set_up_farm(77)
	var data: Dictionary = bytes_to_var(var_to_bytes(first.farm_to_dict()))
	first.free()
	GameClock.elapsed_days = 4.0
	var loaded: GameStateScript = GameStateScript.new()
	var problem: String = loaded.farm_from_dict(data)
	loaded.update_quests()
	var taken: Array[String] = []
	for id: String in IDS:
		if loaded.quest_state.has(id):
			taken.append(id)
	loaded.free()
	# Day 2 with The Thirsty Probe already under way closes the offer too.
	GameClock.elapsed_days = 1.0
	var second: GameStateScript = GameStateScript.new()
	second.farm_from_dict(data)
	second.quest_state["thirsty_probe"] = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }
	second.update_quests()
	var under_way: bool = second.quest_state.has("first_water")
	second.free()
	GameClock.elapsed_days = 0.0
	if problem != "":
		return problem
	if not taken.is_empty():
		return "A day-5 save was given %s." % [taken]
	return "" if not under_way else "The jobs were offered with The Thirsty Probe under way."


# --- The board ------------------------------------------------------------------

func test_the_pad_and_the_reach_cover_the_ground_in_front_of_the_board() -> String:
	var half := Vector2(NoticeBoard.PAD_SIZE.x, NoticeBoard.PAD_SIZE.z) / 2.0
	var farm_side: Vector3 = NoticeBoard.FARM_POSITION + Vector3(0.0, 0.0, -3.0)
	if absf(farm_side.z - NoticeBoard.FARM_POSITION.z) > half.y:
		return "The pad does not reach the farm side of the board."
	if half.length() > NoticeBoard.REACH_M:
		return "A rover in a corner of the pad is out of the host's reach."
	var far: Vector3 = NoticeBoard.FARM_POSITION + Vector3(20.0, 0.0, 0.0)
	return "" if NoticeBoard.farm_near(farm_side) and not NoticeBoard.farm_near(far) else "farm_near is wrong."


func test_the_host_reads_the_board_only_in_reach_on_the_farm() -> String:
	var front: Vector3 = NoticeBoard.FARM_POSITION + Vector3(0.0, 0.0, -3.0)
	var gs: GameStateScript = _fresh_with_rover(front)
	var near: String = gs.read_farm_board(HOST)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	var far: String = gs.read_farm_board(HOST)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, front)
	gs.player_places[GUEST] = [ZonePresence.DOME, 0]
	var dome: String = gs.read_farm_board(GUEST)
	gs.player_places[GUEST] = ["lava_tubes", 0]
	var tubes: String = gs.read_farm_board(GUEST)
	gs.player_places.erase(GUEST)
	gs.rover_in_tunnels = true
	var away: String = gs.read_farm_board(HOST)
	gs.free()
	GameClock.elapsed_days = 0.0
	if not near.begins_with("BOARD:"):
		return "In reach it read '%s'" % near
	var which: Array[String] = ["far", "dome", "tubes", "away"]
	var all: Array[String] = [far, dome, tubes, away]
	for index: int in all.size():
		var refused: String = all[index]
		if refused == "" or refused.begins_with("BOARD:"):
			return "The %s read answered '%s'" % [which[index], refused.left(40)]
	return ""


func test_using_the_board_mid_day_offers_only_the_starter_jobs() -> String:
	var gs: GameStateScript = _fresh_with_rover(NoticeBoard.FARM_POSITION)
	if not gs.quest_state.is_empty():
		gs.free()
		return "A farm that was not looked at has quests."
	gs.read_farm_board(HOST)
	var keys: Array = gs.quest_state.keys()
	keys.sort()
	var want: Array = IDS.duplicate()
	want.sort()
	gs.free()
	GameClock.elapsed_days = 0.0
	return "" if keys == want else "The board offered %s" % [keys]


func test_the_lines_read_not_offered_accepted_and_done() -> String:
	var quests: Array = _starters()
	var none: Array[String] = NoticeBoard.farm_lines(quests, {}, {})
	var open: Dictionary = {}
	for id: String in IDS:
		open[id] = { "steps_done": [], "done": -1 }
	var accepted: Array[String] = NoticeBoard.farm_lines(quests, open, {})
	var shown: Array[String] = NoticeBoard.farm_lines(quests, open, {}, true)
	var finished: Dictionary = { "first_water": { "steps_done": ["plant"], "done": 3 } }
	var some: Array[String] = NoticeBoard.farm_lines(quests, finished, {})
	var water: int = 0
	for index: int in quests.size():
		if str(quests[index]["id"]) == "first_water":
			water = index
	if none.size() != 3 or not "Not offered" in none[0]:
		return "Not offered read %s" % [none]
	if accepted.size() != 3 or not "Accepted. Next: " in accepted[water] or not "Till a cell" in accepted[water]:
		return "Accepted read %s" % [accepted]
	if "[" in accepted[water] or shown[water].length() <= accepted[water].length() or not " [" in shown[water]:
		return "The display path read %s" % [shown]
	if not "Done" in some[water] or some.size() != 3:
		return "Done read %s" % [some]
	return "" if NoticeBoard.farm_lines([], {}, {}) == ["BOARD: no notices."] else "An empty board read wrongly."


# --- A guest --------------------------------------------------------------------

func test_a_guests_interact_goes_through_farm_commands() -> String:
	for action: StringName in [&"read_farm_board", &"read_probe"]:
		if not action in CommandsScript.ACTIONS:
			return "%s is not a FarmCommands action." % action
	var gs: GameStateScript = _fresh_with_rover(NoticeBoard.FARM_POSITION)
	var commands: Node = _commander(gs)
	var bad: Array[String] = [commands.problem(&"read_farm_board", [1]), commands.problem(&"read_probe", ["x"])]
	var good: Array[String] = [commands.problem(&"read_farm_board", []), commands.problem(&"read_probe", [])]
	var answer: Variant = commands.execute(GUEST, &"read_farm_board", [])
	var probe: Variant = commands.execute(GUEST, &"read_probe", [])
	var counts: Dictionary = gs.action_counts.get(GUEST, {})
	var count: int = int((counts.get(GameStateScript.READ_PROBE_COUNT, {}) as Dictionary).get("count", 0)) if counts.get(GameStateScript.READ_PROBE_COUNT) is Dictionary else int(counts.get(GameStateScript.READ_PROBE_COUNT, 0))
	gs.player_places[GUEST] = [ZonePresence.DOME, 0]
	var dome: Variant = commands.execute(GUEST, &"read_farm_board", [])
	var dome_probe: Variant = commands.execute(GUEST, &"read_probe", [])
	commands.free()
	gs.free()
	GameClock.elapsed_days = 0.0
	if "" in bad or good != ["", ""]:
		return "Arguments were checked wrongly: bad %s, good %s" % [bad, good]
	if not answer is String or not "BOARD:" in answer or probe != "" or count != 1:
		return "The guest got '%s', '%s' and counted %d." % [answer, probe, count]
	return "" if dome is String and dome != "" and not dome.begins_with("BOARD:") and dome_probe is String and dome_probe != "" \
		else "A guest in the dome was not refused: '%s' '%s'" % [dome, dome_probe]


func test_a_guest_may_read_the_probe_on_foot() -> String:
	return "" if &"read_probe" in CoopWalkers.ON_FOOT and not &"read_farm_board" in CoopWalkers.ON_FOOT \
		else "read_probe is a look, the board is a rover action."


func test_quest_state_reaches_a_guest_the_existing_way() -> String:
	return "" if FarmSync.SHOWN_BY.has(&"quests_changed") and "quest_state" in FarmSync.SHOWN_BY[&"quests_changed"] \
		else "FarmSync does not show quest_state on quests_changed."


func test_the_protocol_was_raised_for_the_new_commands() -> String:
	return "" if CoopSession.PROTOCOL >= 26 else "PROTOCOL is still %d." % CoopSession.PROTOCOL


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
	GameClock.elapsed_days = 0.0
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
	loaded.update_quests()
	var seen: int = _times(loaded)
	loaded.free()
	GameClock.elapsed_days = 0.0
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
