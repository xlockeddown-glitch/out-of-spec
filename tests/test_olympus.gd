extends "res://tests/coop_net.gd"
## Olympus Mons caves (docs/design/zones.md section 11, slice 31): the lava-tube hub, depths from
## the seed, heat on the shared exposure clock, the marker and the way back, the long first drive,
## the Three Veins quest, the saved fields and the co-op sync. Every number is a [PLACEHOLDER].

const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "olympus_caves"
const HOUR: float = 1.0 / 24.0


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	return gs


## Runs `body` with the global clock at `elapsed` days and restores it.
func _at(elapsed: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


## A farm whose rover has driven up the climb track (the host is in it, at the hub).
func _inside(gs: GameStateScript) -> String:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.OLYMPUS_PAD)
	return gs.move_rover_olympus(true, HOST)


## Opens Three Veins for the farm: the players have reached the caves and the lab is level 55.
func _open_quest(gs: GameStateScript, who: Array[String]) -> void:
	gs.lab_xp = gs.xp_for_level(55)
	for id: String in who:
		var counts: Dictionary = gs.action_counts.get_or_add(id, {}) as Dictionary
		counts["reached_olympus_caves"] = { "count": 1, "xp": 0 }
	QuestEngine.update(gs, who)


## The host's rover on depth 1 at a find of `data`, the host there.
func _at_find(gs: GameStateScript, data: Dictionary, find: Dictionary) -> void:
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(data["grid"], find["cell"]))
	gs.player_places[HOST] = [ZONE, 1]


# --- The hub and the entrance --------------------------------------------------------

func test_the_hub_scene_loads_and_the_zone_row_points_to_it() -> String:
	var packed: PackedScene = load("res://scenes/olympus_caves.tscn")
	if packed == null or not packed.can_instantiate():
		return "scenes/olympus_caves.tscn does not load."
	if ZoneData.hub_scene(&"olympus_caves") != SceneSwitcher.OLYMPUS_SCENE or not ZoneData.is_playable(&"olympus_caves"):
		return "The zones.json row does not point to the hub scene, or the zone is not playable."
	if SceneSwitcher.scene_for_zone(ZONE) != SceneSwitcher.OLYMPUS_SCENE or not SceneSwitcher.is_zone_scene(SceneSwitcher.OLYMPUS_SCENE):
		return "SceneSwitcher does not map the Olympus Mons caves to its scene."
	if str(ZoneData.zone(&"olympus_caves").get("entrance", "")) != "A long climb up the shield volcano's flank to a collapsed skylight.":
		return "The entrance text is wrong."
	var holder := Node3D.new()
	var shaft: Node3D = OlympusLook.add_skylight(holder, Vector3.ZERO)
	var block: Node3D = OlympusLook.add_breakdown_block(holder, Vector3(5.0, 0.0, 0.0), Vector3(4.0, 3.0, 3.0))
	var lamp: bool = shaft.get_node_or_null("SkylightLamp") != null
	var blocks: int = block.get_child_count()  # two slabs and the solid body
	var solid: bool = block.get_node_or_null("BlockBody") is StaticBody3D
	holder.free()
	if not lamp or blocks != 3 or not solid:
		return "The skylight or the breakdown block did not build (lamp %s, %d slabs)." % [lamp, blocks]
	return ""


func test_below_level_fifty_five_the_climb_warns_and_still_lets_you_in() -> String:
	if ZoneData.warning_text(&"olympus_caves", 3) == "" or ZoneData.warning_text(&"olympus_caves", 54) == "":
		return "A lab level under 55 got no warning."
	if ZoneData.band(&"olympus_caves").x != 55 or ZoneData.warning_text(&"olympus_caves", 55) != "":
		return "The band does not start at 55."
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		var let_in: String = _inside(gs)
		var ok: bool = let_in == "" and gs.rover_zone == ZONE and gs.rover_lent and gs.rover_depth == 0
		gs.free()
		return "" if ok else "The warned climb kept the rover out: '%s'." % let_in)
	return run


func test_fast_travel_is_listed_only_after_the_first_visit() -> String:
	for row: Dictionary in FastTravel.destinations(55, []):
		if row["id"] == ZONE:
			return "The Olympus Mons caves are listed before the first visit."
	for row: Dictionary in FastTravel.destinations(55, [ZONE]):
		if row["id"] == ZONE:
			return ""
	return "The Olympus Mons caves are not listed after the first visit."


func test_the_commands_are_on_the_list_and_the_protocol_moved() -> String:
	if not &"move_rover_olympus" in FarmCommands.ACTIONS or not &"place_marker" in FarmCommands.ACTIONS:
		return "move_rover_olympus or place_marker is not a farm command."
	return "" if SessionScript.PROTOCOL == 53 else "The protocol is %d, not 53." % SessionScript.PROTOCOL


# --- The depths ----------------------------------------------------------------------

func test_depths_are_the_same_for_the_same_seed_and_day_and_differ_by_depth_and_day() -> String:
	var a: Dictionary = OlympusDepth.layout(SEED, 1, 5)
	var b: Dictionary = OlympusDepth.layout(SEED, 1, 5)
	if a.is_empty() or var_to_bytes(a) != var_to_bytes(b):
		return "The same seed, depth and day gave two layouts."
	var by_day: bool = false
	for day: int in [6, 7, 8, 9]:
		by_day = by_day or var_to_bytes(OlympusDepth.layout(SEED, 1, day)) != var_to_bytes(a)
	if not by_day:
		return "Four new days gave the same depth 1."
	var deeper: Dictionary = OlympusDepth.layout(SEED, 2, 5)
	if deeper.is_empty() or var_to_bytes(deeper["finds"]) == var_to_bytes(a["finds"]):
		return "Depth 2 is empty or has depth 1's finds."
	if not OlympusDepth.layout(SEED, 0, 5).is_empty() or ZoneDepth.max_depth_of(ZONE) != OlympusDepth.MAX_DEPTH:
		return "The caves have a depth outside 1 to %d." % OlympusDepth.MAX_DEPTH
	for find: Dictionary in a["finds"]:
		if not str(find["kind"]) in OlympusDepth.KINDS or OlympusDepth.reward(str(find["kind"])).is_empty():
			return "A find has no kind or no reward: %s" % [find]
		if str(find["kind"]) == "mineral" and int(find["vein"]) not in range(OlympusDepth.VEIN_NAMES.size()):
			return "A mineral find has no vein kind: %s" % [find]
	if (a["finds"] as Array).size() != OlympusDepth.find_count():
		return "Depth 1 has %d finds (want %d)." % [(a["finds"] as Array).size(), OlympusDepth.find_count()]
	return ""


func test_every_find_the_skylight_and_the_start_are_reachable_every_day() -> String:
	for day: int in range(1, 61):
		for depth: int in range(1, OlympusDepth.MAX_DEPTH + 1):
			var today: Dictionary = OlympusDepth.layout(SEED, depth, day)
			var reach: Array[Vector2i] = ZoneDepth.reachable(today["grid"], ZoneDepth.START_CELL)
			if not today["skylight"] in reach:
				return "Day %d depth %d: the skylight is cut off." % [day, depth]
			if not (today["start"] as Vector2i) in reach:
				return "Day %d depth %d: the start is not on its own floor." % [day, depth]
			for find: Dictionary in today["finds"]:
				if not find["cell"] in reach:
					return "Day %d depth %d: find %s at %s is cut off." % [day, depth, find["id"], find["cell"]]
			var floor_cells: int = 0
			for line: String in today["grid"]:
				floor_cells += line.count(".")
			if reach.size() != floor_cells:
				return "Day %d depth %d: only %d of %d floor cells reach the start (a room is sealed)." % [day, depth, reach.size(), floor_cells]
	return ""


func test_a_find_is_taken_host_run_once_a_day_and_only_by_a_player_in_the_zone() -> String:
	var problems: Array[String] = []
	var day: int = 6
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		day = GameClock.get_day_index()
		var data: Dictionary = OlympusDepth.layout(SEED, 1, day)
		var find: Dictionary = (data["finds"] as Array)[0]
		_at_find(gs, data, find)
		var pay: Dictionary = OlympusDepth.reward(str(find["kind"]))
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		if gs.take_find(str(find["id"]), day, HOST) == "":
			problems.append("A player at the farm took a find in the caves.")
		gs.player_places[HOST] = [ZONE, 1]
		var why: String = gs.take_find(str(find["id"]), day, HOST)
		if why != "":
			problems.append("A find was refused: '%s'" % why)
		if gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			problems.append("The reward is not the caves': %s" % [pay])
		if not str(find["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("The find was not recorded under the Olympus Mons caves.")
		if gs.take_find(str(find["id"]), day, HOST) == "":
			problems.append("A find was taken twice in a day.")
		if gs.take_find(str(find["id"]), day - 1, HOST) == "":
			problems.append("Yesterday's floor was accepted.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_a_guest_cannot_take_a_find_as_another_player() -> String:
	var held_clock: float = GameClock.elapsed_days
	var held_guest: bool = FarmCommands.guest
	GameClock.elapsed_days = 5.25
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.rover_zone = ZONE
	farm.rover_lent = true
	farm.player_places[HOST] = [ZONE, 1]
	farm.player_places[GUEST] = [ZonePresence.FARM, 0]
	var guest: Node = _guest(host)
	var day: int = GameClock.get_day_index()
	var data: Dictionary = OlympusDepth.layout(farm.world_seed, 1, day)
	var find: Dictionary = (data["finds"] as Array)[0]
	farm.rover_depth = 1
	farm.rover_transforms[farm.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(data["grid"], find["cell"]))
	var id: String = str(find["id"])
	var credits: int = farm.credits
	var problem: String = ""
	var off: Array = _request(guest, &"take_find", [id, day])
	_until(func() -> bool: return not off.is_empty())
	var spoof: Array = _request(guest, &"take_find", [id, day, HOST])
	_until(func() -> bool: return not spoof.is_empty())
	if off == [""] or spoof == [""] or farm.credits != credits or id in ZoneDepth.taken_today(farm.finds_taken, ZONE, day):
		problem = "A guest off the zone, or spoofing the host's id, took a find: %s %s" % [off, spoof]
	GameClock.elapsed_days = held_clock
	FarmCommands.guest = held_guest
	return _finish(problem)


# --- Heat ----------------------------------------------------------------------------

func test_heat_drains_warns_and_runs_out() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if gs.cold_of(HOST) != 0.0:
			problems.append("Heat is used on a farm with nobody in the caves.")
		if _inside(gs) != "":
			return "The rover did not go in."
		if not gs.cold_since.has(HOST):
			return "Driving in did not stamp the heat."
		var start: float = float(gs.cold_since[HOST])
		GameClock.elapsed_days = start + 2.0 * HOUR
		if not is_equal_approx(gs.cold_of(HOST), 2.0 * OlympusDepth.HEAT_PER_HOUR):
			problems.append("Heat does not drain at %f an hour: %f." % [OlympusDepth.HEAT_PER_HOUR, gs.cold_of(HOST)])
		if OlympusDepth.heat_text(gs.cold_of(HOST)) == OlympusDepth.heat_text(OlympusDepth.HEAT_WARN + 1.0):
			problems.append("The warning line is the plain line.")
		GameClock.elapsed_days = start + (OlympusDepth.HEAT_WARN / OlympusDepth.HEAT_PER_HOUR + 0.1) * HOUR
		if gs.cold_of(HOST) < OlympusDepth.HEAT_WARN or OlympusDepth.heat_is_out(gs.cold_of(HOST)):
			problems.append("The warning level is wrong.")
		GameClock.elapsed_days = start + 40.0 * HOUR
		if gs.cold_of(HOST) != OlympusDepth.HEAT_MAX or not OlympusDepth.heat_is_out(gs.cold_of(HOST)):
			problems.append("The heat does not stop at %f." % OlympusDepth.HEAT_MAX)
		if OlympusDepth.heat_used(5.0, 4.0) != 0.0:
			problems.append("A stamp in the future uses heat.")
		var data: Dictionary = OlympusDepth.layout(SEED, 1, GameClock.get_day_index())
		var find: Dictionary = (data["finds"] as Array)[0]
		_at_find(gs, data, find)
		if gs.take_find(str(find["id"]), GameClock.get_day_index(), HOST) != OlympusDepth.heat_out_reply():
			problems.append("A find was taken with the cooling spent.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_heat_grace_is_the_zones_own_and_never_carries_between_zones() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	var rate: float = OlympusDepth.HEAT_PER_HOUR
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		var start: float = float(gs.cold_since[HOST])
		GameClock.elapsed_days = start + 3.0 * HOUR
		gs._set_place(HOST, ZonePresence.FARM, 0)
		if gs.cold_since.has(HOST):
			problems.append("The heat stamp stayed outside the caves.")
		GameClock.elapsed_days = start + 3.5 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if not is_equal_approx(gs.cold_of(HOST), 3.0 * rate):
			problems.append("A return within the grace did not keep the 3 h of heat: %f." % gs.cold_of(HOST))
		GameClock.elapsed_days = start + 5.0 * HOUR
		gs._set_place(HOST, ZonePresence.FARM, 0)
		GameClock.elapsed_days = start + 7.0 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if gs.cold_of(HOST) != 0.0:
			problems.append("A return after the grace kept the heat.")
		for other: String in [IceDepth.ZONE, VallesDepth.ZONE]:
			# Another zone, then Olympus within the grace of leaving it: nothing carries over.
			GameClock.elapsed_days += 2.0 * HOUR
			gs._set_place(HOST, other, 0)
			GameClock.elapsed_days += 2.0 * HOUR
			gs._set_place(HOST, ZonePresence.FARM, 0)
			GameClock.elapsed_days += 0.25 * HOUR
			gs._set_place(HOST, ZONE, 0)
			if gs.cold_of(HOST) != 0.0:
				problems.append("Time in %s carried into the Olympus Mons caves: %f." % [other, gs.cold_of(HOST)])
			# And the other way round.
			GameClock.elapsed_days += 2.0 * HOUR
			gs._set_place(HOST, ZonePresence.FARM, 0)
			GameClock.elapsed_days += 0.25 * HOUR
			gs._set_place(HOST, other, 0)
			if gs.cold_of(HOST) != 0.0:
				problems.append("Time in the Olympus Mons caves carried into %s: %f." % [other, gs.cold_of(HOST)])
			GameClock.elapsed_days += 2.0 * HOUR
			gs._set_place(HOST, ZonePresence.FARM, 0)
		# Straight from one to the other: a new stamp.
		GameClock.elapsed_days += 6.0 * HOUR
		gs._set_place(HOST, IceDepth.ZONE, 0)
		GameClock.elapsed_days += 2.0 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if gs.cold_of(HOST) != 0.0:
			problems.append("A direct move between zones kept the stamp.")
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


# --- Markers and the way back ----------------------------------------------------------

func test_the_back_to_skylight_heading_shows_only_after_a_marker() -> String:
	var problems: Array[String] = []
	var from := Vector3(0.0, 0.0, 30.0)
	var to := Vector3(0.0, 0.0, 0.0)
	if OlympusHub.phone_line(true, false, from, to, "usual") != "usual":
		problems.append("The heading showed without a marker.")
	if OlympusHub.phone_line(false, true, from, to, "usual") != "usual":
		problems.append("The hall under the skylight got a heading.")
	var told: String = OlympusHub.phone_line(true, true, from, to, "usual")
	if not told.begins_with("BACK TO SKYLIGHT:") or not "north" in told or not "30 m" in told:
		problems.append("The heading is wrong: '%s'." % told)
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		var day: int = GameClock.get_day_index()
		gs.rover_depth = 1
		gs.player_places[HOST] = [ZONE, 1]
		if OlympusDepth.has_marker(gs.olympus_markers, HOST, 1, day):
			problems.append("A marker exists before one is left.")
		var heard: Array[int] = [0]
		gs.olympus_changed.connect(func() -> void: heard[0] += 1)
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		if gs.place_marker(HOST) == "":
			problems.append("A player off the zone left a marker.")
		gs.player_places[HOST] = [ZONE, 1]
		var why: String = gs.place_marker(HOST)
		if why != "":
			problems.append("The marker was refused: '%s'." % why)
		if not OlympusDepth.has_marker(gs.olympus_markers, HOST, 1, day) or heard[0] != 1:
			problems.append("The marker was not recorded or not announced.")
		if gs.place_marker(HOST) != OlympusDepth.marker_refused_reply():
			problems.append("A second marker on the same depth was accepted.")
		if OlympusDepth.has_marker(gs.olympus_markers, GUEST, 1, day):
			problems.append("The marker is another player's.")
		gs.rover_depth = 0
		gs.player_places[HOST] = [ZONE, 0]
		if gs.place_marker(HOST) == "":
			problems.append("A marker was left in the hall.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- The long drive ------------------------------------------------------------------

func test_the_first_climb_costs_time_and_a_later_one_and_fast_travel_do_not() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	var run: String = _at(3.25, func() -> String:
		var gs: GameStateScript = _state()
		var before: float = GameClock.elapsed_days
		if _inside(gs) != "":
			return "The rover did not go in."
		var spent: float = GameClock.elapsed_days - before
		if spent < OlympusDepth.drive_hours(false) * HOUR - 0.0001:
			problems.append("The first climb cost %f days, not %f hours." % [spent, OlympusDepth.drive_hours(false)])
		if not gs.zones_unlocked.has(ZONE):
			problems.append("The first visit did not open fast travel.")
		gs.rover_zone = ""
		gs.rover_lent = false
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var again_at: float = GameClock.elapsed_days
		if _inside(gs) != "":
			return "The second climb did not go in."
		if GameClock.elapsed_days != again_at:
			problems.append("A later climb cost time.")
		if OlympusDepth.drive_hours(true) != 0.0 or OlympusDepth.drive_hours(false) <= 0.0:
			problems.append("drive_hours is not the first-trip cost.")
		gs.rover_zone = ""
		gs.rover_lent = false
		gs.player_places[HOST] = [ZonePresence.DOME, 0]
		var travel_at: float = GameClock.elapsed_days
		var travelled: String = gs.fast_travel(ZONE, HOST)
		if travelled != "":
			problems.append("Fast travel was refused: %s" % travelled)
		if GameClock.elapsed_days != travel_at:
			problems.append("Fast travel cost time.")
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


func test_a_first_climb_that_would_end_after_the_closing_hour_is_refused() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	var one_before_close: float = TunnelRecall.at_hour(4, 2.0) - HOUR
	var run: String = _at(one_before_close, func() -> String:
		var gs: GameStateScript = _state()
		var before: float = GameClock.elapsed_days
		var refused: String = _inside(gs)
		if refused != OlympusDepth.drive_too_late_text():
			problems.append("A first climb an hour before closing was not refused: %s" % refused)
		if GameClock.elapsed_days != before or gs.zones_unlocked.has(ZONE) or gs.rover_lent:
			problems.append("The refused climb still moved the clock, the unlock or the rover.")
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


# --- The quest -----------------------------------------------------------------------

func test_three_veins_counts_only_new_veins_completes_at_three_and_pays_once() -> String:
	var problems: Array[String] = []
	var quest: Dictionary = {}
	for entry: Dictionary in QuestEngine.quests():
		if str(entry.get("id", "")) == OlympusDepth.QUEST_ID:
			quest = entry
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "Three Veins is missing or has a data problem."
	var gs: GameStateScript = _state()
	_open_quest(gs, [HOST] as Array[String])
	if not gs.quest_state.has(OlympusDepth.QUEST_ID):
		problems.append("The quest did not open.")
	var fresh: Callable = func() -> int:
		return int(((gs.action_counts[HOST] as Dictionary).get(OlympusDepth.NEW_VEIN, { "count": 0 }) as Dictionary)["count"])
	gs._note_olympus_vein(HOST, 2)
	gs._note_olympus_vein(HOST, 2)
	gs._note_olympus_vein(HOST, 2)
	if fresh.call() != 1:
		problems.append("Three samples of one vein counted %d, not 1." % fresh.call())
	gs._note_olympus_vein(HOST, 4)
	QuestEngine.update(gs, [HOST] as Array[String])
	if QuestEngine.is_done(gs, OlympusDepth.QUEST_ID, HOST):
		problems.append("Two veins completed the quest.")
	gs._note_olympus_vein(HOST, 0)
	QuestEngine.update(gs, [HOST] as Array[String])
	if not QuestEngine.is_done(gs, OlympusDepth.QUEST_ID, HOST):
		problems.append("Three veins did not complete the quest.")
	var xp: int = gs.lab_xp
	QuestEngine.update(gs, [HOST] as Array[String])
	if gs.lab_xp != xp:
		problems.append("The quest paid twice.")
	gs.free()
	return "\n".join(problems)


func test_three_veins_counts_distinct_veins_across_all_players() -> String:
	var problems: Array[String] = []
	var both: Array[String] = [HOST, GUEST]
	var gs: GameStateScript = _state()
	_open_quest(gs, both)
	gs._note_olympus_vein(HOST, 2)
	gs._note_olympus_vein(GUEST, 2)  # the same vein, by someone else: not new
	gs._note_olympus_vein(GUEST, 2)
	QuestEngine.update(gs, both)
	if QuestEngine.is_done(gs, OlympusDepth.QUEST_ID):
		problems.append("Two players on one vein completed the quest.")
	gs._note_olympus_vein(GUEST, 4)
	QuestEngine.update(gs, both)
	if QuestEngine.is_done(gs, OlympusDepth.QUEST_ID):
		problems.append("Two distinct veins completed the quest.")
	gs._note_olympus_vein(HOST, 0)
	QuestEngine.update(gs, both)
	if not QuestEngine.is_done(gs, OlympusDepth.QUEST_ID):
		problems.append("Three distinct veins between two players did not complete the quest.")
	gs.free()
	return "\n".join(problems)


func test_veins_taken_before_the_quest_opens_do_not_count_or_block() -> String:
	var problems: Array[String] = []
	var who: Array[String] = [HOST]
	var gs: GameStateScript = _state()
	gs._note_olympus_vein(HOST, 2)
	gs._note_olympus_vein(HOST, 2)
	gs._note_olympus_vein(HOST, 0)
	if (gs.action_counts.get(HOST, {}) as Dictionary).has(OlympusDepth.NEW_VEIN):
		problems.append("Veins before the quest opened were counted.")
	_open_quest(gs, who)
	gs._note_olympus_vein(HOST, 2)
	gs._note_olympus_vein(HOST, 2)
	QuestEngine.update(gs, who)
	if QuestEngine.is_done(gs, OlympusDepth.QUEST_ID):
		problems.append("Early veins shifted the count: veins 2, 2, 0 completed the quest.")
	gs._note_olympus_vein(HOST, 0)
	gs._note_olympus_vein(HOST, 5)
	QuestEngine.update(gs, who)
	if not QuestEngine.is_done(gs, OlympusDepth.QUEST_ID):
		problems.append("Three veins taken after it opened did not complete it.")
	gs.free()
	return "\n".join(problems)


func test_a_mineral_find_counts_its_vein_for_the_player_who_took_it() -> String:
	var problems: Array[String] = []
	var day: int = 7
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		day = GameClock.get_day_index()
		var data: Dictionary = OlympusDepth.layout(SEED, 1, day)
		var sample: Dictionary = {}
		for find: Dictionary in data["finds"]:
			if str(find["kind"]) == "mineral":
				sample = find
				break
		if sample.is_empty():
			return "Depth 1 has no mineral vein sample today."
		_at_find(gs, data, sample)
		_open_quest(gs, [HOST] as Array[String])
		var why: String = gs.take_find(str(sample["id"]), day, HOST)
		if why != "":
			return "The sample was refused: '%s'." % why
		var counts: Dictionary = gs.action_counts.get(HOST, {})
		if int((counts.get(OlympusDepth.NEW_VEIN, { "count": 0 }) as Dictionary)["count"]) != 1:
			problems.append("A mineral sample did not count its vein: %s" % [counts])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Save and co-op ------------------------------------------------------------------

func test_the_fields_round_trip_sync_to_a_guest_and_a_late_joiner_and_an_old_save_loads() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var day: int = 6
	var run: String = _at(float(day - 1), func() -> String:
		var host: GameStateScript = _state()
		if _inside(host) != "":
			return "The rover did not go in."
		day = GameClock.get_day_index()
		var data: Dictionary = OlympusDepth.layout(SEED, 1, day)
		var find: Dictionary = (data["finds"] as Array)[0]
		_at_find(host, data, find)
		host.cold_since[HOST] = GameClock.elapsed_days
		if host.take_find(str(find["id"]), day, HOST) != "":
			return "The find was refused."
		if host.place_marker(HOST) != "":
			return "The marker was refused."
		var saved: Dictionary = bytes_to_var(var_to_bytes(host.farm_to_dict()))
		var back: GameStateScript = _state()
		if back.farm_from_dict(saved) != "":
			problems.append("The save did not load.")
		if not str(find["id"]) in ZoneDepth.taken_today(back.finds_taken, ZONE, day):
			problems.append("The taken find was not saved.")
		if not back.zones_unlocked.has(ZONE):
			problems.append("The fast-travel unlock was not saved.")
		if not OlympusDepth.has_marker(back.olympus_markers, HOST, 1, day):
			problems.append("The marker was not saved.")
		# Yesterday's markers are pruned from a load.
		var stale: Dictionary = saved.duplicate(true)
		stale["olympus_markers"] = { "%s:1" % HOST: [day - 1, 3, 3] }
		var later: GameStateScript = _state()
		if later.farm_from_dict(stale) != "" or not later.olympus_markers.is_empty():
			problems.append("A stale marker survived the load.")
		later.free()
		var broken: Dictionary = saved.duplicate(true)
		broken["olympus_markers"] = "nonsense"
		var bad: GameStateScript = _state()
		if bad.farm_from_dict(broken) == "":
			problems.append("A save with broken markers loaded.")
		bad.free()
		# Old saves load: no Olympus anything.
		var old: Dictionary = host.farm_to_dict()
		old.erase("zones_unlocked")
		old.erase("finds_taken")
		old.erase("olympus_markers")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or not ZoneDepth.taken_today(fresh.finds_taken, ZONE, day).is_empty() or not fresh.olympus_markers.is_empty():
			problems.append("A save with no Olympus state did not load clean.")
		fresh.free()
		var in_tube: Dictionary = host.farm_to_dict()
		in_tube["rover_zone"] = ZONE
		var there: GameStateScript = _state()
		if there.farm_from_dict(in_tube) != "" or there.rover_zone != ZONE:
			problems.append("A save with the rover in the caves did not load.")
		there.free()
		# A guest joining sees the taken find and the marker; an update tells it of the next.
		var guest: GameStateScript = _state()
		FarmCommands.guest = true
		guest.local_player_id = GUEST
		if FarmSync.join(FarmSync.capture(host), guest) != "":
			problems.append("The join was refused.")
		if not str(find["id"]) in ZoneDepth.taken_today(guest.finds_taken, ZONE, day):
			problems.append("A joining guest does not see the taken find.")
		if not OlympusDepth.has_marker(guest.olympus_markers, HOST, 1, day):
			problems.append("A joining guest does not see the marker.")
		FarmCommands.guest = false
		var next: Dictionary = (data["finds"] as Array)[1]
		_at_find(host, data, next)
		host.take_find(str(next["id"]), day, HOST)
		var deeper: Dictionary = OlympusDepth.layout(SEED, 2, day)
		host.rover_depth = 2
		host.player_places[HOST] = [ZONE, 2]
		host.rover_transforms[host.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(deeper["grid"], deeper["start"]))
		var heard: Array[int] = [0, 0]
		guest.finds_changed.connect(func() -> void: heard[0] += 1)
		guest.olympus_changed.connect(func() -> void: heard[1] += 1)
		if host.place_marker(HOST) != "":
			problems.append("The depth 2 marker was refused.")
		FarmCommands.guest = true
		if FarmSync.update(FarmSync.capture(host), guest) != "":
			problems.append("The update was refused.")
		FarmCommands.guest = false
		if not str(next["id"]) in ZoneDepth.taken_today(guest.finds_taken, ZONE, day) or heard[0] < 1:
			problems.append("The guest was not told of the next find (told %d)." % heard[0])
		if not OlympusDepth.has_marker(guest.olympus_markers, HOST, 2, day) or heard[1] < 1:
			problems.append("The guest was not told of the next marker (told %d)." % heard[1])
		host.free()
		back.free()
		guest.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)
