extends RefCounted
## The Lava Tubes hub (docs/design/zones.md section 13, build step 5): the place
## beacon command, the saved beacons, the Beacon Run check, the board's words,
## and what a guest is shown.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	return gs


## HOST in the tunnels with the farm's rover at `spot_id`, and Beacon Run taken.
func _go(gs: GameStateScript, spot_id: String, taken: bool = true) -> void:
	gs.player_places[HOST] = ["lava_tubes", 0]
	gs.rover_zone = "lava_tubes"
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, LavaHub.spot_position(spot_id))
	if taken and not gs.quest_state.has("beacon_run"):
		gs.quest_state["beacon_run"] = { "accepted": 0, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }


func _beacon_run() -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == "beacon_run":
			return quest
	return {}


# --- Where things stand ---------------------------------------------------------

func test_the_spots_the_rack_and_the_board_are_on_floor() -> String:
	for spot_id: String in LavaHub.spot_ids():
		if not TunnelRock.is_floor(LavaHub.SPOTS[spot_id]):
			return "%s is not a floor cell." % spot_id
	if not TunnelRock.is_floor(LavaHub.RACK_CELL) or not TunnelRock.is_floor(LavaHub.BOARD_CELL):
		return "The rack or the board is not on floor."
	return "" if LavaHub.spot_ids().size() == 3 else "There must be three spots."


func test_nearest_finds_the_closest_thing_and_skips_a_placed_spot() -> String:
	var spot: String = "spot_west"
	var at: Vector3 = LavaHub.spot_position(spot)
	var near: Dictionary = LavaHub.nearest(at, [])
	if near.get("kind") != LavaHub.SPOT or near.get("id") != spot:
		return "At a spot it found %s" % [near]
	if not LavaHub.nearest(at, [spot]).is_empty():
		return "A placed spot was still usable."
	if LavaHub.nearest(LavaHub.rack_position(), []).get("kind") != LavaHub.RACK:
		return "The rack was not found."
	if LavaHub.nearest(LavaHub.board_position(), []).get("kind") != LavaHub.BOARD:
		return "The board was not found."
	return "" if LavaHub.nearest(Vector3(500.0, 0.0, 500.0), []).is_empty() else "Far away found something."


# --- The command ----------------------------------------------------------------

func test_place_problem_rules() -> String:
	if LavaHub.place_problem("spot_west", [], "lava_tubes") != "":
		return "A good place was refused."
	if LavaHub.place_problem("spot_west", [], "farm") == "":
		return "Placing outside the Lava Tubes was allowed."
	if LavaHub.place_problem("nowhere", [], "lava_tubes") == "":
		return "An unknown spot was allowed."
	if LavaHub.place_problem("spot_west", ["spot_west"], "lava_tubes") == "":
		return "A spot taken twice was allowed."
	return ""


func _commander(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


func test_the_command_places_for_a_player_in_the_tubes_only() -> String:
	var gs: GameStateScript = _state()
	var commands: Node = _commander(gs)
	var out: Variant = commands.execute(HOST, &"place_beacon", ["spot_west"])
	var refused_home: bool = out != "" and gs.beacons_placed.is_empty()
	_go(gs, "spot_west")
	var taken: Variant = commands.execute(HOST, &"place_beacon", ["spot_west"])
	var twice: Variant = commands.execute(HOST, &"place_beacon", ["spot_west"])
	var unknown: Variant = commands.execute(HOST, &"place_beacon", ["spot_nope"])
	var guest: Variant = commands.execute(GUEST, &"place_beacon", ["spot_east"])
	var placed: Array[String] = gs.beacons_placed.duplicate()
	commands.free()
	gs.free()
	if not refused_home:
		return "A player outside the tubes placed a beacon: %s" % [out]
	if taken != "" or placed != ["spot_west"]:
		return "A player in the tubes could not place: '%s' %s" % [taken, placed]
	if twice == "" or unknown == "" or guest == "":
		return "Refusals missing: twice '%s', unknown '%s', guest at home '%s'" % [twice, unknown, guest]
	return ""


func test_the_farms_rover_must_be_in_the_tubes_and_near_the_spot() -> String:
	var gs: GameStateScript = _state()
	_go(gs, "spot_west")
	gs.rover_zone = ""
	var home: String = gs.place_beacon("spot_west", HOST)
	gs.rover_zone = "lava_tubes"
	var far: String = ""
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, LavaHub.spot_position("spot_east"))
	far = gs.place_beacon("spot_west", HOST)
	gs.rover_transforms.erase(gs.TUNNEL_ROVER)
	var lost: String = gs.place_beacon("spot_west", HOST)
	var none: bool = gs.beacons_placed.is_empty()
	_go(gs, "spot_west")
	var near: String = gs.place_beacon("spot_west", HOST)
	gs.free()
	if home == "" or far == "" or lost == "" or not none:
		return "Refusals missing: rover home '%s', far '%s', no rover '%s'" % [home, far, lost]
	return near


func test_beacons_wait_for_the_beacon_run_job() -> String:
	var gs: GameStateScript = _state()
	_go(gs, "spot_west", false)
	var before: String = gs.place_beacon("spot_west", HOST)
	_go(gs, "spot_west")
	var open: String = gs.place_beacon("spot_west", HOST)
	gs.quest_state["beacon_run"]["done"] = 3
	_go(gs, "spot_east")
	var after: String = gs.place_beacon("spot_east", HOST)
	var placed: Array[String] = gs.beacons_placed.duplicate()
	gs.free()
	if before == "" or after == "":
		return "A beacon went down with the job not taken ('%s') or done ('%s')." % [before, after]
	return open if open != "" else ("" if placed == ["spot_west"] else "Placed %s" % [placed])



func test_the_command_checks_its_arguments() -> String:
	var commands: Node = CommandsScript.new()
	var bad: Array = [commands.problem(&"place_beacon", []), commands.problem(&"place_beacon", [3]), commands.problem(&"place_beacon", ["a", "b"])]
	var good: String = commands.problem(&"place_beacon", ["spot_west"])
	commands.free()
	for reason: String in bad:
		if reason == "":
			return "A bad call to place_beacon passed problem()."
	return good


# --- Saving ---------------------------------------------------------------------

func test_placed_beacons_survive_a_save() -> String:
	var gs: GameStateScript = _state()
	_go(gs, "spot_east")
	gs.place_beacon("spot_east", HOST)
	_go(gs, "spot_north")
	gs.place_beacon("spot_north", HOST)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	gs.free()
	var back: GameStateScript = _state()
	var problem: String = back.farm_from_dict(data)
	var got: Array[String] = back.beacons_placed.duplicate()
	back.free()
	if problem != "":
		return problem
	return "" if got == ["spot_east", "spot_north"] else "Loaded %s" % [got]


func test_an_old_save_without_the_key_loads_with_none() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	gs.free()
	data.erase("beacons_placed")
	var back: GameStateScript = _state()
	back.beacons_placed.append("spot_west")
	var problem: String = back.farm_from_dict(data)
	var got: Array[String] = back.beacons_placed.duplicate()
	back.free()
	if problem != "":
		return "An old save was refused: " + problem
	return "" if got.is_empty() else "Loaded %s" % [got]


func test_a_save_with_a_bad_spot_is_refused() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var refused: Array[String] = []
	for bad: Array in [["spot_nope"], ["spot_west", "spot_west"], [4]]:
		data["beacons_placed"] = bad
		refused.append(gs.farm_dict_problem(data))
	gs.free()
	for reason: String in refused:
		if reason == "":
			return "A bad beacons_placed list was accepted."
	return ""


# --- The quest ------------------------------------------------------------------

func test_beacon_run_data_is_clean() -> String:
	var quest: Dictionary = _beacon_run()
	if quest.is_empty():
		return "beacon_run is not in data/quests.json."
	var reason: String = QuestEngine.data_problem(quest)
	if reason != "":
		return reason
	if quest.get("zone") != "lava_tubes" or quest.get("giver") != "orin":
		return "beacon_run must be Orin's, in the lava_tubes zone."
	return ""


func test_beacon_run_data_problems() -> String:
	var more: Dictionary = _beacon_run().duplicate(true)
	more["steps"][0]["at_least"] = LavaHub.SPOTS.size() + 1
	var zone: Dictionary = _beacon_run().duplicate(true)
	zone["zone"] = "no_such_zone"
	if QuestEngine.data_problem(more) == "":
		return "A step wanting more beacons than spots was accepted."
	if QuestEngine.data_problem(zone) == "":
		return "A quest in an unknown zone was accepted."
	return ""


func test_the_check_counts_placed_beacons() -> String:
	var gs: GameStateScript = _state()
	var step: Dictionary = (_beacon_run()["steps"] as Array)[0]
	var present: Array[String] = [HOST]
	var entry: Dictionary = { "steps_done": [], "base": {} }
	var counts: Array[int] = [QuestEngine.step_count(gs, step, entry, present)]
	gs.player_places[HOST] = ["lava_tubes", 0]
	for spot_id: String in LavaHub.spot_ids():
		_go(gs, spot_id)
		gs.place_beacon(spot_id, HOST)
		counts.append(QuestEngine.step_count(gs, step, entry, present))
	gs.free()
	return "" if counts == [0, 1, 2, 3] else "Counts were %s" % [counts]


func test_the_quest_is_done_when_the_third_is_placed() -> String:
	var gs: GameStateScript = _state()
	var present: Array[String] = [HOST]
	var quest: Dictionary = _beacon_run()
	var step: Dictionary = (quest["steps"] as Array)[0]
	gs.player_places[HOST] = ["lava_tubes", 0]
	_go(gs, "spot_west")
	gs.place_beacon("spot_west", HOST)
	_go(gs, "spot_east")
	gs.place_beacon("spot_east", HOST)
	var two: int = QuestEngine.step_progress(gs, step, { "steps_done": [], "base": {} }, present)[0]
	_go(gs, "spot_north")
	gs.place_beacon("spot_north", HOST)
	var three: Array[int] = QuestEngine.step_progress(gs, step, { "steps_done": [], "base": {} }, present)
	gs.free()
	return "" if two == 2 and three == [3, 3] else "Progress %d then %s" % [two, three]


# --- The board ------------------------------------------------------------------

func test_the_board_reads_not_offered_accepted_and_done() -> String:
	var quests: Array = [_beacon_run()]
	var none: Array[String] = LavaHub.board_lines(quests, {}, {}, 0)
	var open: Dictionary = { "beacon_run": { "steps_done": [], "done": -1 } }
	var accepted: Array[String] = LavaHub.board_lines(quests, open, {}, 2)
	var done: Dictionary = { "beacon_run": { "steps_done": ["place"], "done": 4 } }
	var finished: Array[String] = LavaHub.board_lines(quests, done, {}, 3)
	var empty: Array[String] = LavaHub.board_lines([], {}, {}, 0)
	if none.size() != 1 or not "Not offered" in none[0] or not "Beacon Run" in none[0]:
		return "Not offered read %s" % [none]
	if accepted.size() != 1 or not "Accepted" in accepted[0] or not "2 of 3" in accepted[0]:
		return "Accepted read %s" % [accepted]
	if finished.size() != 1 or not "Done" in finished[0]:
		return "Done read %s" % [finished]
	return "" if empty == ["BOARD: no notices."] else "No quests read %s" % [empty]


# --- A guest --------------------------------------------------------------------

func test_a_guest_is_shown_the_hosts_beacons() -> String:
	if not FarmSync.SHOWN_BY.has(&"beacons_changed") or not "beacons_placed" in FarmSync.SHOWN_BY[&"beacons_changed"]:
		return "FarmSync does not show beacons_placed on beacons_changed."
	var host: GameStateScript = _state()
	_go(host, "spot_north")
	host.place_beacon("spot_north", HOST)
	var data: Dictionary = bytes_to_var(var_to_bytes(host.farm_to_dict()))
	host.free()
	var guest: GameStateScript = _state()
	var seen: Array[int] = [0]
	guest.beacons_changed.connect(func() -> void: seen[0] += 1)
	var problem: String = guest.farm_from_dict(data)
	var got: Array[String] = guest.beacons_placed.duplicate()
	guest.free()
	if problem != "":
		return problem
	return "" if got == ["spot_north"] else "The guest has %s" % [got]


func test_a_save_with_the_beacon_step_done_but_too_few_beacons_is_refused() -> String:
	var gs: GameStateScript = _state()
	_go(gs, "spot_west")
	gs.place_beacon("spot_west", HOST)
	gs.quest_state["beacon_run"]["steps_done"] = ["place"]
	var short: String = gs.farm_dict_problem(gs.farm_to_dict())
	for spot_id: String in ["spot_east", "spot_north"]:
		_go(gs, spot_id)
		gs.place_beacon(spot_id, HOST)
	var enough: String = gs.farm_dict_problem(gs.farm_to_dict())
	gs.free()
	if short == "":
		return "A step done with one beacon placed was accepted."
	return enough


func test_the_protocol_moved_with_the_beacon_command_and_field() -> String:
	return "" if CoopSession.PROTOCOL >= 19 else "finds and beacons are new on the wire: PROTOCOL must be 19 or more."


func test_the_host_allows_a_little_slack_on_the_reach() -> String:
	var gs: GameStateScript = _state()
	_go(gs, "spot_west")
	var spot: Vector3 = LavaHub.spot_position("spot_west")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(LavaHub.REACH_M + LavaHub.HOST_REACH_SLACK_M + 0.1, 0.0, 0.0))
	var too_far: String = gs.place_beacon("spot_west", HOST)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(LavaHub.REACH_M + LavaHub.HOST_REACH_SLACK_M - 0.1, 0.0, 0.0))
	var lagging: String = gs.place_beacon("spot_west", HOST)
	gs.free()
	if too_far == "":
		return "A rover just past the slack was accepted."
	return lagging


func test_a_save_with_the_run_done_but_a_spot_empty_is_refused() -> String:
	var gs: GameStateScript = _state()
	_go(gs, "spot_west")
	gs.place_beacon("spot_west", HOST)
	gs.quest_state["beacon_run"]["done"] = 3
	var short: String = gs.farm_dict_problem(gs.farm_to_dict())
	gs.quest_state["beacon_run"]["done"] = -1
	for spot_id: String in ["spot_east", "spot_north"]:
		_go(gs, spot_id)
		gs.place_beacon(spot_id, HOST)
	gs.quest_state["beacon_run"]["done"] = 3
	var full: String = gs.farm_dict_problem(gs.farm_to_dict())
	gs.free()
	if short == "":
		return "A finished Beacon Run with one beacon down was accepted."
	return full


func test_a_done_that_is_not_a_number_is_left_to_the_quest_check() -> String:
	var quests: Array = [{ "id": LavaHub.QUEST, "steps": [] }]
	for bad: Variant in [{}, [], "3", null]:
		if LavaHub.steps_problem(quests, { LavaHub.QUEST: { "done": bad } }, 0) != "":
			return "steps_problem judged a 'done' of %s instead of leaving it." % str(bad)
	return ""


func test_only_spots_leaves_out_the_rack_and_the_board() -> String:
	var at: Vector3 = LavaHub.rack_position()
	if LavaHub.nearest(at, [], true).get("kind") == LavaHub.RACK:
		return "The rack was found when only spots were asked for."
	var spot: Dictionary = LavaHub.nearest(LavaHub.spot_position("spot_north"), [], true)
	return "" if spot.get("id") == "spot_north" else "The north spot was not found: %s" % [spot]
