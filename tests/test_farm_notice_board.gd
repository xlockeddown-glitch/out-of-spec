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


## Runs `body` with the game clock at `elapsed` days, then puts the clock back
## whatever the body returned.
func _at_day(elapsed: float, body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = saved
	return out if out is String else "The test did not return a String."


## A new farm looked at once (the first morning), at the clock as it is.
func _new_farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs._set_up_farm(77)
	gs.update_quests()
	return gs


## Runs `body` on a new farm on day 1, then frees it.
func _run(body: Callable) -> String:
	return _at_day(0.0, func() -> String:
		var gs: GameStateScript = _new_farm()
		var out: Variant = body.call(gs)
		gs.free()
		return out if out is String else "The test did not return a String.")


## A farm that has not been looked at yet, its rover parked at `at`.
func _fresh_with_rover(at: Vector3) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs._set_up_farm(77)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, at)
	return gs


## A farm saved on day 1 (as a plain dictionary).
func _day_one_save() -> Dictionary:
	var first: GameStateScript = GameStateScript.new()
	first._set_up_farm(77)
	var data: Dictionary = bytes_to_var(var_to_bytes(first.farm_to_dict()))
	first.free()
	return data


## Which of the three starter jobs `gs` holds.
func _held(gs: GameStateScript) -> Array[String]:
	var held: Array[String] = []
	for id: String in IDS:
		if gs.quest_state.has(id):
			held.append(id)
	return held


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


func test_a_board_quest_must_be_a_farm_quest_and_not_a_daily_ask() -> String:
	var own: Dictionary = (_starters()[0] as Dictionary).duplicate(true)
	own["scope"] = "player"
	var daily: Dictionary = (_starters()[0] as Dictionary).duplicate(true)
	daily["kind"] = "daily"
	for quest: Dictionary in [own, daily]:
		if not "board" in QuestEngine.data_problem(quest):
			return "A %s quest on the farm board was accepted: '%s'" % [quest["kind"], QuestEngine.data_problem(quest)]
	return ""


func test_the_jobs_are_offered_on_day_one_of_a_new_farm() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var missing: Array[String] = []
		for id: String in IDS:
			if not gs.quest_state.has(id):
				missing.append(id)
		return "" if missing.is_empty() else "Not offered on day 1: %s" % [missing])


func test_day_two_offers_the_jobs_even_with_the_thirsty_probe() -> String:
	return _at_day(1.0, func() -> String:
		var gs: GameStateScript = _new_farm()
		var held: Array[String] = _held(gs)
		var probe: bool = gs.quest_state.has("thirsty_probe")
		gs.free()
		if held != IDS:
			return "Day 2 offered %s" % [held]
		return "" if probe else "The Thirsty Probe was not offered on day 2 beside them.")


func test_day_three_offers_nothing() -> String:
	return _at_day(2.0, func() -> String:
		var gs: GameStateScript = _new_farm()
		var held: Array[String] = _held(gs)
		gs.free()
		return "" if held.is_empty() else "Day 3 offered %s" % [held])


func test_jobs_taken_on_day_one_stay_open_and_finish_on_day_three() -> String:
	return _run(func(gs: GameStateScript) -> String:
		GameClock.elapsed_days = 2.0
		gs.update_quests()
		if _held(gs) != IDS or _done(gs, "first_water"):
			return "The jobs were dropped or finished by day 3: %s" % [_held(gs)]
		gs.till(CELL, HOST)
		gs.plant_crop(CELL, "", gs.OFFSET_CURRENT, HOST)
		gs.update_quests()
		return "" if _done(gs, "first_water") else "A job taken on day 1 would not finish on day 3.")


func test_each_step_completes_by_its_check() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var commands: Node = _commander(gs)
		gs.till(CELL, HOST)
		gs.update_quests()
		if _done(gs, "first_water"):
			commands.free()
			return "Tilling alone finished first_water."
		var planted: String = gs.plant_crop(CELL, "", gs.OFFSET_CURRENT, HOST)
		gs.update_quests()
		if planted != "" or not _done(gs, "first_water"):
			commands.free()
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
	return _at_day(0.0, func() -> String:
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
		return "" if done else "first_water stuck on a fully tilled plot (%s)." % planted)


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


func test_a_kept_score_reads_the_not_rule_as_the_count_does() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var step: Dictionary = { "id": "cal", "check": "count", "log": "cal_log", "minigame": "set_the_zero",
			"where": { "instrument_id": "hygrometer", "traceable": true, "not_performed_by": GameStateScript.MANAGER_ID } }
		gs.cal_log.append({ "instrument_id": "hygrometer", "traceable": true, "day": 1, "performed_by": GUEST })
		var played: Dictionary = { "minigame": "set_the_zero", "player_id": GUEST, "instrument_id": "hygrometer", "score": 90 }
		var entry: Dictionary = {}
		QuestEngine._keep_score(gs, entry, step, played, "")
		return "" if int((entry.get("scores", {}) as Dictionary).get("cal", 0)) == 90 else "A score with a not_ where key was not kept.")


func test_an_old_farm_is_never_given_the_jobs() -> String:
	var data: Dictionary = _day_one_save_at_start()
	var late: String = _at_day(4.0, func() -> String:
		var loaded: GameStateScript = GameStateScript.new()
		var problem: String = loaded.farm_from_dict(data)
		loaded.update_quests()
		var taken: Array[String] = _held(loaded)
		loaded.free()
		if problem != "":
			return problem
		return "" if taken.is_empty() else "A day-5 save was given %s." % [taken])
	if late != "":
		return late
	# Day 2 with The Thirsty Probe already under way closes the offer too.
	return _at_day(1.0, func() -> String:
		var second: GameStateScript = GameStateScript.new()
		second.farm_from_dict(data)
		second.quest_state["thirsty_probe"] = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }
		second.update_quests()
		var under_way: bool = second.quest_state.has("first_water")
		second.free()
		return "" if not under_way else "The jobs were offered with The Thirsty Probe under way.")


func _day_one_save_at_start() -> Dictionary:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 0.0
	var data: Dictionary = _day_one_save()
	GameClock.elapsed_days = saved
	return data


# --- The board ------------------------------------------------------------------

func test_the_pad_and_the_reach_cover_the_rover_at_the_pad_and_the_host_slack() -> String:
	var half := Vector2(NoticeBoard.PAD_SIZE.x, NoticeBoard.PAD_SIZE.z) / 2.0
	if half.length() + NoticeBoard.ROVER_HALF_DIAGONAL_M > NoticeBoard.REACH_M:
		return "A rover touching a corner of the pad is outside REACH_M."
	var limit: float = NoticeBoard.REACH_M + NoticeBoard.HOST_REACH_SLACK_M
	var inside: Vector3 = NoticeBoard.FARM_POSITION + Vector3(0.0, 0.0, -(limit - 0.05))
	var outside: Vector3 = NoticeBoard.FARM_POSITION + Vector3(0.0, 0.0, -(limit + 0.05))
	if not NoticeBoard.farm_near(inside) or NoticeBoard.farm_near(outside):
		return "The host's reach is not REACH_M plus the slack."
	var farm_side: Vector3 = NoticeBoard.FARM_POSITION + Vector3(0.0, 0.0, -3.0)
	return "" if absf(farm_side.z - NoticeBoard.FARM_POSITION.z) <= half.y else "The pad does not reach the farm side of the board."


func test_the_host_reads_the_board_only_in_reach_on_the_farm() -> String:
	return _at_day(0.0, func() -> String:
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
		if not near.begins_with("BOARD:"):
			return "In reach it read '%s'" % near
		var which: Array[String] = ["far", "dome", "tubes", "away"]
		var all: Array[String] = [far, dome, tubes, away]
		for index: int in all.size():
			if all[index] == "" or all[index].begins_with("BOARD:"):
				return "The %s read answered '%s'" % [which[index], all[index].left(40)]
		return "")


func test_using_the_board_mid_day_offers_only_the_starter_jobs() -> String:
	return _at_day(0.0, func() -> String:
		var gs: GameStateScript = _fresh_with_rover(NoticeBoard.FARM_POSITION)
		var empty: bool = gs.quest_state.is_empty()
		gs.read_farm_board(HOST)
		var keys: Array = gs.quest_state.keys()
		keys.sort()
		var want: Array = IDS.duplicate()
		want.sort()
		gs.free()
		if not empty:
			return "A farm that was not looked at has quests."
		return "" if keys == want else "The board offered %s" % [keys])


func test_the_board_on_an_old_save_accepts_nothing_and_hides_the_jobs() -> String:
	var data: Dictionary = _day_one_save_at_start()
	return _at_day(4.0, func() -> String:
		var gs: GameStateScript = GameStateScript.new()
		var problem: String = gs.farm_from_dict(data)
		gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, NoticeBoard.FARM_POSITION)
		var answer: String = gs.read_farm_board(HOST)
		var taken: Array[String] = _held(gs)
		gs.free()
		if problem != "":
			return problem
		if not taken.is_empty():
			return "The board on a day-5 save accepted %s" % [taken]
		if not answer.begins_with("BOARD:") or "Not offered" in answer:
			return "The old farm's board read '%s'" % answer
		return "")


func test_the_lines_read_not_offered_accepted_and_done() -> String:
	return _at_day(0.0, func() -> String:
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
		return "" if NoticeBoard.farm_lines([], {}, {}) == ["BOARD: no notices."] else "An empty board read wrongly.")


func test_a_job_that_can_never_be_offered_is_not_listed() -> String:
	var quests: Array = _starters()
	var late: String = _at_day(4.0, func() -> String:
		var lines: Array[String] = NoticeBoard.farm_lines(quests, {}, {})
		return "" if lines == ["BOARD: no notices."] else "A day-5 board read %s" % [lines])
	if late != "":
		return late
	return _at_day(0.0, func() -> String:
		var lines: Array[String] = NoticeBoard.farm_lines(quests, { "thirsty_probe": { "steps_done": [], "done": -1 } }, {})
		return "" if lines == ["BOARD: no notices."] else "A board with The Thirsty Probe under way read %s" % [lines])


# --- A guest --------------------------------------------------------------------

func test_a_guests_interact_goes_through_farm_commands() -> String:
	for action: StringName in [&"read_farm_board", &"read_probe"]:
		if not action in CommandsScript.ACTIONS:
			return "%s is not a FarmCommands action." % action
	return _at_day(0.0, func() -> String:
		var gs: GameStateScript = _fresh_with_rover(NoticeBoard.FARM_POSITION)
		var commands: Node = _commander(gs)
		var bad: Array[String] = [commands.problem(&"read_farm_board", [1]), commands.problem(&"read_probe", ["x"])]
		var good: Array[String] = [commands.problem(&"read_farm_board", []), commands.problem(&"read_probe", [])]
		var answer: Variant = commands.execute(GUEST, &"read_farm_board", [])
		var held: Array[String] = _held(gs)
		var probe: Variant = commands.execute(GUEST, &"read_probe", [])
		var counts: Dictionary = gs.action_counts.get(GUEST, {})
		var tally: Variant = counts.get(GameStateScript.READ_PROBE_COUNT, {})
		var count: int = int((tally as Dictionary).get("count", 0)) if tally is Dictionary else int(tally)
		gs.player_places[GUEST] = [ZonePresence.DOME, 0]
		var dome: Variant = commands.execute(GUEST, &"read_farm_board", [])
		var dome_probe: Variant = commands.execute(GUEST, &"read_probe", [])
		commands.free()
		gs.free()
		if "" in bad or good != ["", ""]:
			return "Arguments were checked wrongly: bad %s, good %s" % [bad, good]
		if not answer is String or not answer.begins_with("BOARD:") or "refus" in answer or held != IDS:
			return "The guest's board read gave '%s' and the farm holds %s." % [answer, held]
		if probe != "" or count != 1:
			return "The guest's probe read gave '%s' and counted %d." % [probe, count]
		return "" if dome is String and dome != "" and not dome.begins_with("BOARD:") and dome_probe is String and dome_probe != "" \
			else "A guest in the dome was not refused: '%s' '%s'" % [dome, dome_probe])


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
	return _at_day(0.0, func() -> String:
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
			"The line showed %d, %d (after a load) and %d (new_farm) times." % [once, after_load, through_new])


func test_an_old_save_gets_no_extra_line() -> String:
	return _at_day(0.0, func() -> String:
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
		if problem != "":
			return problem
		return "" if seen == 0 else "A loaded save was given the line.")


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
