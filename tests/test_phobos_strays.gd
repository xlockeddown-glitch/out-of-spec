extends "res://tests/coop_net.gd"
## Phobos part 2 (docs/design/zones.md, build step 17): catching a stray in the service tunnel,
## Odalys's Strays quest, and the station-stock marker on the caught Banded Regolith Runner.

const HOST: String = "player_1"
const GUEST: String = "player_2"
const RUNNER: String = "banded_regolith_runner"
const HOUR: float = 1.0 / 24.0


## A farm with the host on Phobos, on a day of its own. Frees it and puts the clock back.
func _on_phobos(body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 4.2
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(606060)
	gs.local_player_id = HOST
	gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = held
	return problem


func _today() -> Array[int]:
	return PhobosServiceTunnel.stray_indices_for_day(GameClock.get_day_index())


func _count(gs: GameStateScript, who: String, key: String) -> int:
	return gs.action_count(key, who)


func _unplaced() -> int:
	var placed: Array[int] = _today()
	for i: int in PhobosServiceTunnel.STRAY_SPOTS.size():
		if not i in placed:
			return i
	return -1


func test_a_catch_adds_one_runner_and_removes_that_stray() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var first: int = _today()[0]
		if gs.is_caught(RUNNER):
			return "The Runner's tank must start empty."
		var why: String = gs.catch_stray(first, day)
		if why != "" or not gs.is_caught(RUNNER) or gs.enclosures.size() != 1:
			return "The catch must add one Runner: '%s'" % why
		if not first in gs.strays_caught_today() or gs.strays_caught_today().size() != 1:
			return "The stray must be marked caught today: %s" % [gs.strays_caught_today()]
		if _count(gs, HOST, "catch_stray") != 1:
			return "The catch must be counted for the host."
		var again: String = gs.catch_stray(first, day)
		if again == "" or gs.strays_caught_today().size() != 1 or _count(gs, HOST, "catch_stray") != 1:
			return "A second catch of the same stray the same day is refused: '%s'" % again
		return "")


func test_another_stray_counts_but_adds_no_second_tank() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var strays: Array[int] = _today()
		if gs.catch_stray(strays[0], day) != "" or gs.catch_stray(strays[1], day) != "":
			return "Two different strays are two catches."
		if gs.enclosures.size() != 1 or gs.strays_caught_today().size() != 2 or _count(gs, HOST, "catch_stray") != 2:
			return "One tank a species, two catches counted: %d tanks" % gs.enclosures.size()
		return "")


func test_a_new_day_brings_the_strays_back() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var first: int = _today()[0]
		gs.catch_stray(first, day)
		GameClock.elapsed_days += 1.0
		var next: int = GameClock.get_day_index()
		if not gs.strays_caught_today().is_empty():
			return "Yesterday's catches are not today's."
		var why: String = gs.catch_stray(PhobosServiceTunnel.stray_indices_for_day(next)[0], next)
		if why != "":
			return "A new day's stray is catchable: '%s'" % why
		if gs.farm_to_dict()["strays_caught"]["day"] != next:
			return "The save keeps only today's catches."
		return "")


func test_a_catch_from_the_wrong_place_day_or_stray_is_refused() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var first: int = _today()[0]
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var far: String = gs.catch_stray(first, day)
		gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
		var deimos: String = gs.catch_stray(first, day)
		gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
		var stale: String = gs.catch_stray(first, day - 1)
		var unplaced: String = gs.catch_stray(_unplaced(), day)
		var below: String = gs.catch_stray(-1, day)
		if far == "" or deimos == "" or stale == "" or unplaced == "" or below == "":
			return "Refused: '%s' '%s' '%s' '%s' '%s'" % [far, deimos, stale, unplaced, below]
		if gs.is_caught(RUNNER) or not gs.strays_caught_today().is_empty() or _count(gs, HOST, "catch_stray") != 0:
			return "A refused catch changes nothing."
		return "")


func test_it_is_a_farm_command_a_moon_player_may_use() -> String:
	if not &"catch_stray" in FarmCommands.ACTIONS or not &"catch_stray" in FarmCommands.ON_A_MOON:
		return "catch_stray must be a command, and one a player on a moon may use."
	if FarmCommands.problem(&"catch_stray", [1, 5]) != "" or FarmCommands.problem(&"catch_stray", []) == "":
		return "catch_stray takes the stray and the day."
	if CoopSession.PROTOCOL != 40:
		return "A new command raises the protocol to 40."
	return ""


func test_a_guests_click_goes_through_the_host() -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 4.2
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.player_places[GUEST] = [Shuttle.PHOBOS, 0]
	var guest: Node = _guest(host)
	var day: int = GameClock.get_day_index()
	var first: int = _today()[0]
	var problem: String = ""
	var got: Array = _request(guest, &"catch_stray", [first, day])
	_until(func() -> bool: return not got.is_empty())
	if got != [""] or not farm.is_caught(RUNNER) or first not in farm.strays_caught_today():
		problem = "The host must make the catch: %s" % [got]
	elif not guest.commands.state.enclosures.is_empty() or not guest.commands.state.strays_caught_today().is_empty():
		problem = "The guest's click changes nothing here until the host says."
	elif _count(farm, GUEST, "catch_stray") != 1:
		problem = "The catch is the guest's."
	else:
		var heard: String = guest.commands.state.farm_from_dict(farm.farm_to_dict())
		if heard != "" or not first in guest.commands.state.strays_caught_today() or not guest.commands.state.is_caught(RUNNER):
			problem = "The guest must hear of the catch: '%s'" % heard
	if problem == "":
		var again: Array = _request(guest, &"catch_stray", [first, day])
		_until(func() -> bool: return not again.is_empty())
		if again.is_empty() or again == [""]:
			problem = "The same stray is gone for the guest too: %s" % [again]
		else:
			farm.player_places[GUEST] = [ZonePresence.FARM, 0]
			var other: Array = _request(guest, &"catch_stray", [_today()[1], day])
			_until(func() -> bool: return not other.is_empty())
			if other.is_empty() or other == [""]:
				problem = "A guest not on Phobos is refused: %s" % [other]
	GameClock.elapsed_days = held
	return _finish(problem)


func test_the_first_catch_is_marked_station_stock_and_it_says_so() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		gs.catch_stray(_today()[0], GameClock.get_day_index())
		if gs.enclosure_origins.get(RUNNER, "") != GameStateScript.STATION_ORIGIN:
			return "The Runner carries the station marker: %s" % [gs.enclosure_origins]
		var line: String = gs.enclosure_text(RUNNER)
		if not line.ends_with(GameStateScript.STATION_LINE) or line.begins_with("."):
			return "The enclosure line says it is station stock: '%s'" % line
		return "")


func test_the_marker_and_the_catches_survive_a_save() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var first: int = _today()[0]
		gs.catch_stray(first, GameClock.get_day_index())
		var saved: Dictionary = gs.farm_to_dict()
		var other: GameStateScript = GameStateScript.new()
		other.build_registry()
		var why: String = other.farm_from_dict(saved)
		var problem: String = ""
		if why != "":
			problem = "The save must load: '%s'" % why
		elif other.enclosure_origins != gs.enclosure_origins or other.strays_caught_today() != [first]:
			problem = "The marker and the caught set must round-trip: %s, %s" % [other.enclosure_origins, other.strays_caught_today()]
		elif not other.enclosure_text(RUNNER).ends_with(GameStateScript.STATION_LINE):
			problem = "The loaded Runner still says it is station stock."
		else:
			var bad: Dictionary = saved.duplicate(true)
			bad["enclosure_origins"] = { "cobalt_sentinel": GameStateScript.STATION_ORIGIN }
			var wrong: Dictionary = saved.duplicate(true)
			wrong["enclosure_origins"] = { RUNNER: "somewhere" }
			var lost: Dictionary = saved.duplicate(true)
			lost["strays_caught"] = { "day": 3, "ids": [99] }
			if other.farm_dict_problem(bad) == "" or other.farm_dict_problem(wrong) == "" or other.farm_dict_problem(lost) == "":
				problem = "A marker with no tank, an unknown origin or a stray that is not one must not load."
		other.free()
		return problem)


func test_an_old_save_without_them_loads() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var old: Dictionary = gs.farm_to_dict()
		old.erase("enclosure_origins")
		old.erase("strays_caught")
		var other: GameStateScript = GameStateScript.new()
		other.build_registry()
		var why: String = other.farm_from_dict(old)
		var problem: String = ""
		if why != "":
			problem = "An old save must load: '%s'" % why
		elif not other.enclosure_origins.is_empty() or not other.strays_caught_today().is_empty():
			problem = "An old save has no origins and no caught strays."
		other.free()
		return problem)


func test_another_days_catches_are_not_saved() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		gs.strays_caught = { "day": GameClock.get_day_index() - 1, "ids": [0] }
		if not (gs.farm_to_dict()["strays_caught"] as Dictionary).is_empty():
			return "Yesterday's catches are dropped from the save."
		return "")


func test_the_quest_is_offered_after_reaching_a_moon_and_pays_the_first_catch_once() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST, GUEST]
		QuestEngine.update(gs, present)
		if (gs.player_quest_state.get(HOST, {}) as Dictionary).has("strays"):
			return "Not offered before a player has reached Phobos."
		for who: String in present:
			gs.action_counts[who] = { "reached_phobos": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, present)
		for who: String in present:
			if not (gs.player_quest_state.get(who, {}) as Dictionary).has("strays"):
				return "Offered to %s once they have reached Phobos." % who
		if QuestEngine.is_done(gs, "strays", HOST):
			return "Not done before a catch."
		var day: int = GameClock.get_day_index()
		var strays: Array[int] = _today()
		var xp_before: int = gs.skill_xp("husbandry", HOST)
		gs.player_places[GUEST] = [Shuttle.PHOBOS, 0]
		if gs.catch_stray(strays[0], day, HOST) != "":
			return "The host's catch."
		QuestEngine.update(gs, present)
		if not QuestEngine.is_done(gs, "strays", HOST):
			return "The first catch completes it for the one who made it."
		if QuestEngine.is_done(gs, "strays", GUEST):
			return "A catch is the catcher's: the other player's quest stays open."
		var paid: int = gs.skill_xp("husbandry", HOST) - xp_before
		if paid <= 0:
			return "The quest pays Husbandry XP."
		if gs.catch_stray(strays[1], day, HOST) != "":
			return "The host's second catch."
		QuestEngine.update(gs, present)
		if gs.skill_xp("husbandry", HOST) - xp_before != paid:
			return "It is paid once."
		if gs.catch_stray(strays[2], day, GUEST) != "":
			return "The guest's catch."
		QuestEngine.update(gs, present)
		if not QuestEngine.is_done(gs, "strays", GUEST):
			return "The guest's own first catch completes theirs."
		return "")


func test_arriving_on_a_moon_is_counted_with_no_xp() -> String:
	var held: float = GameClock.elapsed_days
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(606060)
	gs.local_player_id = HOST
	gs.credits = 500
	gs.shuttle_licensed = true
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	GameClock.elapsed_days = 3.0 * HOUR
	var why: String = gs.book_shuttle(Shuttle.DEIMOS, 1)
	var problem: String = ""
	var xp_kept: int = gs.action_xp("reached_deimos", HOST)
	if why != "" or _count(gs, HOST, "reached_deimos") != 1 or xp_kept != 0:
		problem = "A booked trip counts as reaching the moon: '%s', %d" % [why, _count(gs, HOST, "reached_deimos")]
	gs.free()
	GameClock.elapsed_days = held
	return problem


func test_the_strays_quest_is_in_the_data_and_clean() -> String:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == "strays":
			if str(quest.get("giver", "")) != "odalys" or str(quest.get("kind", "")) != "personal" or str(quest.get("scope", "")) != "player":
				return "Strays is Odalys's personal quest, one for each player."
			var problem: String = QuestEngine.data_problem(quest)
			return "" if problem == "" else "Strays is not clean: %s" % problem
	return "Strays is not in data/quests.json."


func test_a_runner_with_no_dome_tank_neither_molts_nor_gives_silk() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		gs.catch_stray(_today()[0], GameClock.get_day_index())
		gs._tick_enclosures(500.0)
		if float(gs.enclosures[RUNNER]["molt_progress"]) != 0.0:
			return "The Runner has no dome tank yet, so it must not molt."
		gs.enclosures[RUNNER] = { "molt_progress": 1.0, "molt_stage": int(GameStateScript.MoltStage.MOLTED), "exuvia_until_day": 0 }
		var spools: float = gs.optical_silk_spools
		gs.lab_sitter = LabSitter.new_booking(GameClock.get_day_index())
		gs._sitter_tend()
		if gs.is_enclosure_spool_ready(RUNNER) or gs.collect_enclosure_spool(RUNNER, HOST) or gs.optical_silk_spools != spools:
			return "Nothing may collect silk from a tank nobody can see."
		return "")


func test_a_guest_cannot_decide_a_catch_and_a_later_catch_is_let_go() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		FarmCommands.guest = true
		var why: String = gs.catch_stray(_today()[0], GameClock.get_day_index())
		FarmCommands.guest = false
		if why == "" or not gs.strays_caught.is_empty() or _count(gs, HOST, "catch_stray") != 0:
			return "A guest's own game must not make a catch: '%s'" % why
		return "")


func test_a_guest_is_told_of_a_catch_by_the_sync() -> String:
	return _on_phobos(func(host: GameStateScript) -> String:
		host.catch_stray(_today()[0], GameClock.get_day_index())
		var guest: GameStateScript = GameStateScript.new()
		guest.build_registry()
		var heard: Array[int] = [0]
		guest.strays_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var updated: String = FarmSync.update(FarmSync.capture(host), guest)
		FarmCommands.guest = false
		var problem: String = ""
		if updated != "" or heard[0] < 1 or guest.strays_caught_today() != host.strays_caught_today():
			problem = "FarmSync must re-emit strays_changed on a guest: '%s', told %d" % [updated, heard[0]]
		guest.free()
		return problem)
