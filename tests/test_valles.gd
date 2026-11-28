extends "res://tests/coop_net.gd"
## Valles Marineris (docs/design/zones.md section 11, slice 30): the canyon hub, depths from the
## seed, wind, thin air, the long first drive, the layered-cores quest, the saved fields and
## the co-op sync. Every number is a [PLACEHOLDER].

const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "valles_marineris"
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


## A farm whose rover has driven into the canyon from the road (the host is in it, at the hub).
func _inside(gs: GameStateScript) -> String:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.VALLES_PAD)
	return gs.move_rover_valles(true, HOST)


## Opens Layer by Layer for the farm: the players have reached the canyon and the lab is level 50.
func _open_quest(gs: GameStateScript, who: Array[String]) -> void:
	gs.lab_xp = gs.xp_for_level(50)
	for id: String in who:
		var counts: Dictionary = gs.action_counts.get_or_add(id, {}) as Dictionary
		counts["reached_valles_marineris"] = { "count": 1, "xp": 0 }
	QuestEngine.update(gs, who)


## The host's rover on depth 1 at a find of `data`, the host there.
func _at_find(gs: GameStateScript, data: Dictionary, find: Dictionary) -> void:
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(data["grid"], find["cell"]))
	gs.player_places[HOST] = [ZONE, 1]


# --- The hub and the entrance --------------------------------------------------------

func test_the_hub_scene_loads_and_the_zone_row_points_to_it() -> String:
	var packed: PackedScene = load("res://scenes/valles_marineris.tscn")
	if packed == null or not packed.can_instantiate():
		return "scenes/valles_marineris.tscn does not load."
	if ZoneData.hub_scene(&"valles_marineris") != SceneSwitcher.VALLES_SCENE or not ZoneData.is_playable(&"valles_marineris"):
		return "The zones.json row does not point to the hub scene, or the zone is not playable."
	if SceneSwitcher.scene_for_zone(ZONE) != SceneSwitcher.VALLES_SCENE or not SceneSwitcher.is_zone_scene(SceneSwitcher.VALLES_SCENE):
		return "SceneSwitcher does not map Valles Marineris to its scene."
	if str(ZoneData.zone(&"valles_marineris").get("entrance", "")) != "A long drive east along the canyon road.":
		return "The entrance text is wrong."
	var holder := Node3D.new()
	var wall: Node3D = VallesLook.add_band_wall(holder, Vector3.ZERO, Vector2(6.0, 1.0))
	VallesLook.add_talus(holder, Vector3.ZERO, 4.0)
	var bands: int = wall.get_child_count()
	var talus: bool = holder.get_node_or_null("Talus") != null
	holder.free()
	if bands != VallesLook.BANDS.size() or not talus:
		return "The layered wall or the talus did not build (%d bands, talus %s)." % [bands, talus]
	var seen: Array[Color] = []
	for color: Color in VallesLook.BANDS:
		if color in seen:
			return "Two wall bands share a colour."
		seen.append(color)
	return ""


func test_below_level_fifty_the_road_warns_and_still_lets_you_in() -> String:
	if ZoneData.warning_text(&"valles_marineris", 3) == "" or ZoneData.warning_text(&"valles_marineris", 49) == "":
		return "A lab level under 50 got no warning."
	if ZoneData.warning_text(&"valles_marineris", ZoneData.band(&"valles_marineris").x) != "":
		return "The band's first level is in the band: no warning."
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		var let_in: String = _inside(gs)  # the warning is the screen's; the host does not gate on level
		var ok: bool = let_in == "" and gs.rover_zone == ZONE and gs.rover_lent and gs.rover_depth == 0
		gs.free()
		return "" if ok else "The warned road kept the rover out: '%s'." % let_in)
	return run


func test_fast_travel_is_listed_only_after_the_first_visit() -> String:
	for row: Dictionary in FastTravel.destinations(50, []):
		if row["id"] == ZONE:
			return "Valles Marineris is listed before the first visit."
	for row: Dictionary in FastTravel.destinations(50, [ZONE]):
		if row["id"] == ZONE:
			return ""
	return "Valles Marineris is not listed after the first visit."


func test_the_command_is_on_the_list_and_the_protocol_moved() -> String:
	if not &"move_rover_valles" in FarmCommands.ACTIONS:
		return "move_rover_valles is not a farm command."
	return "" if SessionScript.PROTOCOL == 51 else "The protocol is %d, not 51." % SessionScript.PROTOCOL


# --- The depths ----------------------------------------------------------------------

func test_depths_are_the_same_for_the_same_seed_and_day_and_differ_by_depth_and_day() -> String:
	var a: Dictionary = VallesDepth.layout(SEED, 1, 5)
	var b: Dictionary = VallesDepth.layout(SEED, 1, 5)
	if a.is_empty() or var_to_bytes(a) != var_to_bytes(b):
		return "The same seed, depth and day gave two layouts."
	var by_day: bool = false
	for day: int in [6, 7, 8, 9]:
		by_day = by_day or var_to_bytes(VallesDepth.layout(SEED, 1, day)) != var_to_bytes(a)
	if not by_day:
		return "Four new days gave the same depth 1."
	var deeper: Dictionary = VallesDepth.layout(SEED, 2, 5)
	if deeper.is_empty() or var_to_bytes(deeper["finds"]) == var_to_bytes(a["finds"]):
		return "Depth 2 is empty or has depth 1's finds."
	if not VallesDepth.layout(SEED, 0, 5).is_empty() or ZoneDepth.max_depth_of(ZONE) != VallesDepth.MAX_DEPTH:
		return "Valles has a depth outside 1 to %d." % VallesDepth.MAX_DEPTH
	for find: Dictionary in a["finds"]:
		if not str(find["kind"]) in VallesDepth.KINDS or VallesDepth.reward(str(find["kind"])).is_empty():
			return "A find has no kind or no reward: %s" % [find]
		if str(find["kind"]) == "sediment" and int(find["band"]) not in range(VallesLook.BANDS.size()):
			return "A core has no wall band: %s" % [find]
	if (a["finds"] as Array).size() != VallesDepth.find_count():
		return "Depth 1 has %d finds (want %d)." % [(a["finds"] as Array).size(), VallesDepth.find_count()]
	return ""


func test_a_find_is_taken_host_run_once_a_day_and_only_by_a_player_in_the_zone() -> String:
	var problems: Array[String] = []
	var day: int = 6
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		var data: Dictionary = VallesDepth.layout(SEED, 1, day)
		var find: Dictionary = (data["finds"] as Array)[0]
		_at_find(gs, data, find)
		var pay: Dictionary = VallesDepth.reward(str(find["kind"]))
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		if gs.take_find(str(find["id"]), day, HOST) == "":
			problems.append("A player at the farm took a find in the canyon.")
		gs.player_places[HOST] = [ZONE, 1]
		var why: String = gs.take_find(str(find["id"]), day, HOST)
		if why != "":
			problems.append("A find was refused: '%s'" % why)
		if gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			problems.append("The reward is not Valles': %s" % [pay])
		if not str(find["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("The find was not recorded under Valles Marineris.")
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
	var data: Dictionary = VallesDepth.layout(farm.world_seed, 1, day)
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


# --- Wind ----------------------------------------------------------------------------

func test_wind_slows_only_the_open_floor_while_gusting() -> String:
	var grid: PackedStringArray = VallesDepth.hub_grid()
	var open := Vector2i(11, 8)  # mid-canyon, no wall within a cell
	var foot := Vector2i(11, VallesDepth.CANYON_TOP)  # at the north wall's foot
	if VallesDepth.sheltered(grid, open) or not VallesDepth.sheltered(grid, foot):
		return "The open floor is sheltered, or the wall foot is not."
	var gust_at: float = -1.0
	var calm_at: float = -1.0
	for hour: int in 400:
		var t: float = (float(hour) + 0.5) * HOUR
		if VallesDepth.gusting(SEED, 0, t):
			gust_at = t if gust_at < 0.0 else gust_at
		else:
			calm_at = t if calm_at < 0.0 else calm_at
	if gust_at < 0.0 or calm_at < 0.0:
		return "No gust and no calm in 400 hours."
	if not is_equal_approx(VallesDepth.wind_factor(SEED, 0, gust_at, grid, open), VallesDepth.GUST_FACTOR):
		return "A gust does not slow the open floor."
	if VallesDepth.wind_factor(SEED, 0, gust_at, grid, foot) != 1.0:
		return "A gust slows the sheltered wall foot."
	if VallesDepth.wind_factor(SEED, 0, calm_at, grid, open) != 1.0:
		return "Calm air slows the open floor."
	if VallesDepth.gusting(SEED, 0, 3.4) != VallesDepth.gusting(SEED, 0, 3.4):
		return "The wind is not a pure function."
	if VallesDepth.wind_text(true, false) == VallesDepth.wind_text(true, true) or VallesDepth.wind_text(false, false) == "":
		return "The phone lines for the wind are not distinct."
	return ""


# --- Thin air ------------------------------------------------------------------------

func test_thin_air_drains_faster_than_the_base_rate_and_runs_out() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if gs.cold_of(HOST) != 0.0:
			problems.append("Air is used on a farm with nobody in the canyon.")
		if _inside(gs) != "":
			return "The rover did not go in."
		if not gs.cold_since.has(HOST):
			return "Driving in did not stamp the air."
		var start: float = float(gs.cold_since[HOST])  # stamped on entry, after the first drive moved the clock
		if not is_equal_approx(start, GameClock.elapsed_days):
			problems.append("The entry stamp is not the time of arrival.")
		GameClock.elapsed_days = start + 2.0 * HOUR
		var two: float = gs.cold_of(HOST)
		if not is_equal_approx(two, 2.0 * VallesDepth.AIR_PER_HOUR_BASE * VallesDepth.THIN_AIR_MULT):
			problems.append("The air does not drain at %.1f times the base rate: %f." % [VallesDepth.THIN_AIR_MULT, two])
		if not two > 2.0 * VallesDepth.AIR_PER_HOUR_BASE:
			problems.append("The thin air is no faster than the base rate.")
		GameClock.elapsed_days = start + 40.0 * HOUR
		if gs.cold_of(HOST) != VallesDepth.AIR_MAX or not VallesDepth.air_is_out(gs.cold_of(HOST)):
			problems.append("The air does not stop at %f." % VallesDepth.AIR_MAX)
		if VallesDepth.air_used(5.0, 4.0) != 0.0:
			problems.append("A stamp in the future uses air.")
		# With the air gone, the host takes no find.
		var data: Dictionary = VallesDepth.layout(SEED, 1, GameClock.get_day_index())
		var find: Dictionary = (data["finds"] as Array)[0]
		_at_find(gs, data, find)
		if gs.take_find(str(find["id"]), GameClock.get_day_index(), HOST) != VallesDepth.air_out_reply():
			problems.append("A find was taken with the suit out of air.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_thin_air_grace_is_the_zones_own_and_never_carries_between_zones() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	var rate: float = VallesDepth.AIR_PER_HOUR_BASE * VallesDepth.THIN_AIR_MULT
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		var start: float = float(gs.cold_since[HOST])
		# Out for half an hour: the air picks up where it was.
		GameClock.elapsed_days = start + 3.0 * HOUR
		gs._set_place(HOST, ZonePresence.FARM, 0)
		if gs.cold_since.has(HOST):
			problems.append("The air stamp stayed outside the canyon.")
		GameClock.elapsed_days = start + 3.5 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if not is_equal_approx(gs.cold_of(HOST), 3.0 * rate):
			problems.append("A return within the grace did not keep the 3 h of air: %f." % gs.cold_of(HOST))
		# Out past the grace: a fresh suit.
		GameClock.elapsed_days = start + 5.0 * HOUR
		gs._set_place(HOST, ZonePresence.FARM, 0)
		GameClock.elapsed_days = start + 7.0 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if gs.cold_of(HOST) != 0.0:
			problems.append("A return after the grace kept the air.")
		# Ice, then the canyon within the grace of leaving Ice: nothing carries over.
		GameClock.elapsed_days = start + 9.0 * HOUR
		gs._set_place(HOST, IceDepth.ZONE, 0)
		GameClock.elapsed_days = start + 11.0 * HOUR
		gs._set_place(HOST, ZonePresence.FARM, 0)
		GameClock.elapsed_days = start + 11.5 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if gs.cold_of(HOST) != 0.0:
			problems.append("Time in the Ice Caves carried into the canyon: %f." % gs.cold_of(HOST))
		# And the other way round.
		GameClock.elapsed_days = start + 13.5 * HOUR
		gs._set_place(HOST, ZonePresence.FARM, 0)
		GameClock.elapsed_days = start + 14.0 * HOUR
		gs._set_place(HOST, IceDepth.ZONE, 0)
		if gs.cold_of(HOST) != 0.0:
			problems.append("Time in the canyon carried into the Ice Caves: %f." % gs.cold_of(HOST))
		# Straight from one to the other (no farm between): a new stamp.
		GameClock.elapsed_days = start + 16.0 * HOUR
		gs._set_place(HOST, ZONE, 0)
		if gs.cold_of(HOST) != 0.0:
			problems.append("A direct move between zones kept the stamp.")
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


# --- The long drive ------------------------------------------------------------------

func test_the_first_drive_costs_time_and_a_later_one_and_fast_travel_do_not() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	var run: String = _at(3.25, func() -> String:
		var gs: GameStateScript = _state()
		var before: float = GameClock.elapsed_days
		if _inside(gs) != "":
			return "The rover did not go in."
		var spent: float = GameClock.elapsed_days - before
		if spent < VallesDepth.drive_hours(false) * HOUR - 0.0001:
			problems.append("The first drive cost %f days, not %f hours." % [spent, VallesDepth.drive_hours(false)])
		if not gs.zones_unlocked.has(ZONE):
			problems.append("The first visit did not open fast travel.")
		gs.rover_zone = ""
		gs.rover_lent = false
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var again_at: float = GameClock.elapsed_days
		if _inside(gs) != "":
			return "The second drive did not go in."
		if GameClock.elapsed_days != again_at:
			problems.append("A later drive cost time.")
		if VallesDepth.drive_hours(true) != 0.0 or VallesDepth.drive_hours(false) <= 0.0:
			problems.append("drive_hours is not the first-trip cost.")
		# Fast travel from the dome is free.
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


func test_a_first_drive_that_would_end_after_the_closing_hour_is_refused() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	var one_before_close: float = TunnelRecall.at_hour(4, 2.0) - HOUR
	var run: String = _at(one_before_close, func() -> String:
		var gs: GameStateScript = _state()
		var before: float = GameClock.elapsed_days
		var refused: String = _inside(gs)
		if refused != VallesDepth.drive_too_late_text():
			problems.append("A first drive an hour before closing was not refused: %s" % refused)
		if GameClock.elapsed_days != before or gs.zones_unlocked.has(ZONE) or gs.rover_lent:
			problems.append("The refused drive still moved the clock, the unlock or the rover.")
		# Closed outright: the existing closing message, for a drive and for fast travel.
		GameClock.elapsed_days = TunnelRecall.at_hour(4, 2.0) + HOUR
		if _inside(gs) != TunnelRecall.text("closed_text"):
			problems.append("The mouth was open after the closing hour.")
		gs.zones_unlocked.append(ZONE)
		gs.player_places[HOST] = [ZonePresence.DOME, 0]
		if gs.fast_travel(ZONE, HOST) != TunnelRecall.text("closed_text"):
			problems.append("Fast travel was open after the closing hour.")
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


# --- The quest -----------------------------------------------------------------------

func test_layer_by_layer_counts_only_new_bands_completes_at_three_and_pays_once() -> String:
	var problems: Array[String] = []
	var quest: Dictionary = {}
	for entry: Dictionary in QuestEngine.quests():
		if str(entry.get("id", "")) == "layer_by_layer":
			quest = entry
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "Layer by Layer is missing or has a data problem."
	var gs: GameStateScript = _state()
	_open_quest(gs, [HOST] as Array[String])
	if not gs.quest_state.has("layer_by_layer"):
		problems.append("The quest did not open.")
	var fresh: Callable = func() -> int:
		return int(((gs.action_counts[HOST] as Dictionary).get(VallesDepth.NEW_BAND, { "count": 0 }) as Dictionary)["count"])
	gs._note_valles_band(HOST, 2)
	gs._note_valles_band(HOST, 2)  # the same band again: not new
	gs._note_valles_band(HOST, 2)
	if fresh.call() != 1:
		problems.append("Three cores of one band counted %d, not 1." % fresh.call())
	gs._note_valles_band(HOST, 4)
	QuestEngine.update(gs, [HOST] as Array[String])
	if QuestEngine.is_done(gs, "layer_by_layer", HOST):
		problems.append("Two bands completed the quest.")
	gs._note_valles_band(HOST, 0)
	QuestEngine.update(gs, [HOST] as Array[String])
	if not QuestEngine.is_done(gs, "layer_by_layer", HOST):
		problems.append("Three bands did not complete the quest.")
	var xp: int = gs.lab_xp
	QuestEngine.update(gs, [HOST] as Array[String])
	if gs.lab_xp != xp:
		problems.append("The quest paid twice.")
	gs.free()
	return "\n".join(problems)


func test_layer_by_layer_counts_distinct_bands_across_all_players() -> String:
	var problems: Array[String] = []
	var both: Array[String] = [HOST, GUEST]
	var gs: GameStateScript = _state()
	_open_quest(gs, both)
	gs._note_valles_band(HOST, 2)
	gs._note_valles_band(GUEST, 2)  # the same band, by someone else: not new
	gs._note_valles_band(GUEST, 2)
	QuestEngine.update(gs, both)
	if QuestEngine.is_done(gs, "layer_by_layer"):
		problems.append("Two players coring one band completed the quest.")
	gs._note_valles_band(GUEST, 4)
	QuestEngine.update(gs, both)
	if QuestEngine.is_done(gs, "layer_by_layer"):
		problems.append("Two distinct bands completed the quest.")
	gs._note_valles_band(HOST, 0)
	QuestEngine.update(gs, both)
	if not QuestEngine.is_done(gs, "layer_by_layer"):
		problems.append("Three distinct bands between two players did not complete the quest.")
	gs.free()
	return "\n".join(problems)


func test_cores_taken_before_the_quest_opens_do_not_count_or_block() -> String:
	var problems: Array[String] = []
	var who: Array[String] = [HOST]
	var gs: GameStateScript = _state()
	gs._note_valles_band(HOST, 2)  # before the quest: leaves no mark
	gs._note_valles_band(HOST, 2)
	gs._note_valles_band(HOST, 0)
	if (gs.action_counts.get(HOST, {}) as Dictionary).has(VallesDepth.NEW_BAND):
		problems.append("Cores before the quest opened were counted.")
	_open_quest(gs, who)
	gs._note_valles_band(HOST, 2)  # the same band as before: it still counts, once
	gs._note_valles_band(HOST, 2)
	QuestEngine.update(gs, who)
	if QuestEngine.is_done(gs, "layer_by_layer"):
		problems.append("Early cores shifted the count: bands 2, 2, 0 completed the quest.")
	gs._note_valles_band(HOST, 0)
	gs._note_valles_band(HOST, 5)
	QuestEngine.update(gs, who)
	if not QuestEngine.is_done(gs, "layer_by_layer"):
		problems.append("Three bands cored after it opened did not complete it.")
	gs.free()
	return "\n".join(problems)


func test_a_sediment_find_counts_its_band_for_the_player_who_took_it() -> String:
	var problems: Array[String] = []
	var day: int = 7
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		day = GameClock.get_day_index()
		var data: Dictionary = VallesDepth.layout(SEED, 1, day)
		var core: Dictionary = {}
		for find: Dictionary in data["finds"]:
			if str(find["kind"]) == "sediment":
				core = find
				break
		if core.is_empty():
			return "Depth 1 has no sediment core today."
		_at_find(gs, data, core)
		_open_quest(gs, [HOST] as Array[String])
		var why: String = gs.take_find(str(core["id"]), day, HOST)
		if why != "":
			return "The core was refused: '%s'." % why
		var counts: Dictionary = gs.action_counts.get(HOST, {})
		if int((counts.get(VallesDepth.NEW_BAND, { "count": 0 }) as Dictionary)["count"]) != 1:
			problems.append("A sediment core did not count its band: %s" % [counts])
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
		var data: Dictionary = VallesDepth.layout(SEED, 1, day)
		var find: Dictionary = (data["finds"] as Array)[0]
		_at_find(host, data, find)
		host.cold_since[HOST] = GameClock.elapsed_days
		if host.take_find(str(find["id"]), day, HOST) != "":
			return "The find was refused."
		var saved: Dictionary = bytes_to_var(var_to_bytes(host.farm_to_dict()))
		var back: GameStateScript = _state()
		if back.farm_from_dict(saved) != "":
			problems.append("The save did not load.")
		if not str(find["id"]) in ZoneDepth.taken_today(back.finds_taken, ZONE, day):
			problems.append("The taken find was not saved.")
		if not back.zones_unlocked.has(ZONE):
			problems.append("The fast-travel unlock was not saved.")
		# Old saves load: no Valles anything.
		var old: Dictionary = host.farm_to_dict()
		old.erase("zones_unlocked")
		old.erase("finds_taken")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or not ZoneDepth.taken_today(fresh.finds_taken, ZONE, day).is_empty():
			problems.append("A save with no Valles state did not load clean.")
		fresh.free()
		var in_canyon: Dictionary = host.farm_to_dict()
		in_canyon["rover_zone"] = ZONE
		var there: GameStateScript = _state()
		if there.farm_from_dict(in_canyon) != "" or there.rover_zone != ZONE:
			problems.append("A save with the rover in the canyon did not load.")
		there.free()
		# A guest joining sees the taken find; an update tells it of the next.
		var guest: GameStateScript = _state()
		FarmCommands.guest = true
		guest.local_player_id = GUEST
		if FarmSync.join(FarmSync.capture(host), guest) != "":
			problems.append("The join was refused.")
		if not str(find["id"]) in ZoneDepth.taken_today(guest.finds_taken, ZONE, day):
			problems.append("A joining guest does not see the taken find.")
		FarmCommands.guest = false
		var next: Dictionary = (data["finds"] as Array)[1]
		_at_find(host, data, next)
		host.take_find(str(next["id"]), day, HOST)
		var heard: Array[int] = [0]
		guest.finds_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		if FarmSync.update(FarmSync.capture(host), guest) != "":
			problems.append("The update was refused.")
		FarmCommands.guest = false
		if not str(next["id"]) in ZoneDepth.taken_today(guest.finds_taken, ZONE, day) or heard[0] < 1:
			problems.append("The guest was not told of the next find (told %d)." % heard[0])
		host.free()
		back.free()
		guest.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)
