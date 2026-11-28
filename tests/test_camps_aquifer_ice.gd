extends "res://tests/coop_net.gd"
## The Aquifer and Ice Caves camps (docs/design/zones.md build step 12 follow-up): the two
## camp cells, the two quests that open them, a night alone and with a guest, the Ice Caves'
## cold rule (a heater, no extra supply), the bed still refused elsewhere, the Lava camp
## unchanged and old saves loading.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")

const AQUIFER: String = "flooded_aquifer"
const ICE: String = "ice_caves"
const LAVA: String = "lava_tubes"
const HOST: String = "player_1"
const GUEST: String = "player_2"
const HOME: Vector3 = Vector3(3.0, 0.0, 3.0)
const DAYS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]


func _state(zone: String) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, HOME)
	gs.zones_unlocked.append(zone)
	gs.credits = 500
	return gs


func _hub(gs: GameStateScript, zone: String, who: Array, at: Vector3, opened: bool = true, supplies: int = 1) -> void:
	for player_id: String in who:
		gs.player_places[player_id] = [zone, 0]
		gs._trip_players[player_id] = true
	gs.rover_zone = zone
	gs.rover_depth = 0
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	if opened and not gs.camps_open.has(zone):
		gs.camps_open.append(zone)
	gs.camp_supplies = supplies


func _camp_farm(zone: String, with_guest: bool, body: Callable) -> String:
	var host: Node = _host()
	if with_guest:
		_guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = 0.5
	var gs: GameStateScript = _state(zone)
	gs.recall_beds = beds
	var out: Variant = body.call(gs, beds, clock)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	beds.free()
	clock.free()
	return _finish(problem)


func _quest(id: String) -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == id:
			return quest
	return {}


func _count(gs: GameStateScript, who: String, key: String) -> int:
	return int(((gs.action_counts.get(who, {}) as Dictionary).get(key, {}) as Dictionary).get("count", 0))


func _grid(zone: String, day: int) -> PackedStringArray:
	return ZoneDepth.grid_for(0, 424242, day, zone)


# --- The cells --------------------------------------------------------------------------

func test_both_cells_are_open_dry_floor_clear_of_the_hub_spots_on_every_day_sampled() -> String:
	var problems: Array[String] = []
	var spots: Dictionary = {
		AQUIFER: [AquiferDepth.HATCH_CELL, AquiferDepth.CRATE_CELL, AquiferDepth.SIGN_CELL, ZoneDepth.DESCENT_CELL, ZoneDepth.HUB_LIFT_CELL],
		ICE: [IceDepth.HATCH_CELL, IceDepth.CRATE_CELL, IceDepth.SIGN_CELL, ZoneDepth.DESCENT_CELL, ZoneDepth.HUB_LIFT_CELL],
	}
	for zone: String in [AQUIFER, ICE]:
		if not Camp.has_camp(zone):
			problems.append("%s has a camp" % zone)
			continue
		var cell: Vector2i = Camp.cell(zone)
		var first: PackedStringArray = _grid(zone, DAYS[0])
		for day: int in DAYS:
			var grid: PackedStringArray = _grid(zone, day)
			if grid != first:
				problems.append("%s: the hub changed on day %d (depth 0 is never reseeded)" % [zone, day])
			if grid[cell.y][cell.x] != ".":
				problems.append("%s: the camp's cell %s is '%s', not dry open floor, on day %d" % [zone, cell, grid[cell.y][cell.x], day])
		for other: Vector2i in spots[zone]:
			if absi(other.x - cell.x) + absi(other.y - cell.y) < 2:
				problems.append("%s: the camp's cell %s is on or beside %s" % [zone, cell, other])
		if Camp.position(zone) == Vector3.ZERO:
			problems.append("%s: the camp has a place" % zone)
	return "\n".join(problems)


func test_the_aquifer_camp_is_clear_of_the_pool() -> String:
	var cell: Vector2i = Camp.cell(AQUIFER)
	if AquiferDepth.HUB_POOL.grow(1).has_point(cell):
		return "The Aquifer camp %s is at the pool's edge %s" % [cell, AquiferDepth.HUB_POOL]
	var grid: PackedStringArray = AquiferDepth.hub_grid()
	if grid[cell.y][cell.x] == "w":
		return "The Aquifer camp is in the water"
	return ""


func test_the_lava_tubes_camp_is_unchanged() -> String:
	var problems: Array[String] = []
	if Camp.cell(LAVA) != Vector2i(16, 12):
		problems.append("The Lava Tubes camp stays at (16, 12): %s" % [Camp.cell(LAVA)])
	if Camp.night_key(LAVA) != Camp.NIGHT_COUNT:
		problems.append("A Lava night still counts camp_night (Two Sunsets reads it)")
	if Camp.cold_problem(LAVA, 100.0) != "" or Camp.cold_problem(AQUIFER, 100.0) != "":
		problems.append("Only the Ice Caves have a cold rule")
	if Camp.night_key(ICE) == Camp.NIGHT_COUNT or Camp.night_key(AQUIFER) == Camp.NIGHT_COUNT:
		problems.append("The new camps do not count for Two Sunsets")
	if Camp.night_key(ICE) == Camp.night_key(AQUIFER):
		problems.append("Each camp counts its own nights")
	return "\n".join(problems)


# --- The quests -------------------------------------------------------------------------

func test_both_quests_are_clean_data_and_carry_their_camp_and_zone() -> String:
	var problems: Array[String] = []
	var wanted: Dictionary = { "the_sump_sample": AQUIFER, "a_night_on_the_ice": ICE }
	for id: String in wanted:
		var quest: Dictionary = _quest(id)
		if quest.is_empty():
			problems.append("%s is shipped" % id)
			continue
		if QuestEngine.data_problem(quest) != "":
			problems.append("%s has a data problem: %s" % [id, QuestEngine.data_problem(quest)])
		if str(quest.get("camp", "")) != wanted[id] or str(quest.get("zone", "")) != wanted[id]:
			problems.append("%s carries camp and zone %s" % [id, wanted[id]])
	var sump: Dictionary = _quest("the_sump_sample")
	if sump.is_empty():
		return "\n".join(problems)
	var odd: Dictionary = sump.duplicate(true)
	odd["camp"] = "colony_mine"
	if QuestEngine.data_problem(odd) == "":
		problems.append("A camp in a zone with none is a data problem")
	if str(sump.get("giver", "")) != "vance" or str(sump.get("scope", "")) != "farm":
		problems.append("The Sump Sample is Vance's, for the farm")
	return "\n".join(problems)


func test_the_quests_wait_for_a_visit_and_then_open_both_camps() -> String:
	var gs: GameStateScript = _state(AQUIFER)
	gs.lab_xp = gs.xp_for_level(12)
	var problems: Array[String] = []
	QuestEngine.update(gs, [HOST] as Array[String])
	if gs.camps_open.has(AQUIFER) or gs.camps_open.has(ICE):
		problems.append("Neither quest is taken before its zone is visited: %s" % [gs.camps_open])
	gs.action_counts[HOST] = {
		"reached_flooded_aquifer": { "count": 1, "xp": 0 },
		"reached_ice_caves": { "count": 1, "xp": 0 },
	}
	QuestEngine.update(gs, [HOST] as Array[String])
	if not gs.camps_open.has(AQUIFER) or not gs.camps_open.has(ICE):
		problems.append("Visiting both zones opens both camps: %s" % [gs.camps_open])
	var states: Dictionary = gs.player_quest_state.get(HOST, {})
	for zone: String in [AQUIFER, ICE]:
		var lines: Array = NoticeBoard.lines(QuestEngine.quests(), gs.quest_state, states, "zone", zone)
		if lines.is_empty():
			problems.append("%s' board lists its quest" % zone)
	gs.free()
	return "\n".join(problems)


func test_the_quests_read_the_counters_the_game_keeps() -> String:
	var problems: Array[String] = []
	if GameStateScript.AQUIFER_FIND_COUNT != "take_aquifer_find":
		problems.append("The Aquifer find counter has the name the quest reads")
	var text: String = JSON.stringify(_quest("the_sump_sample"))
	if not text.contains("camp_night_flooded_aquifer") or not text.contains(GameStateScript.AQUIFER_FIND_COUNT) or not text.contains("reached_flooded_aquifer"):
		problems.append("The Sump Sample reads its night, its find and its visit")
	if not JSON.stringify(_quest("a_night_on_the_ice")).contains("camp_night_ice_caves"):
		problems.append("The Ice night quest reads its camp's night")
	return "\n".join(problems)


func test_the_sump_sample_needs_a_night_and_a_find() -> String:
	return _camp_farm(AQUIFER, false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		gs.lab_xp = gs.xp_for_level(12)
		gs.action_counts[HOST] = { "reached_flooded_aquifer": { "count": 1, "xp": 0 } }
		var problems: Array[String] = []
		QuestEngine.update(gs, [HOST] as Array[String])
		if not gs.camps_open.has(AQUIFER):
			problems.append("Taking the quest opens the Aquifer camp: %s" % [gs.camps_open])
		_hub(gs, AQUIFER, [HOST], Camp.position(AQUIFER), false, 1)
		if gs.go_to_bed(HOST) != "":
			problems.append("The night at the Aquifer camp")
		QuestEngine.update(gs, [HOST] as Array[String])
		if QuestEngine.is_done(gs, "the_sump_sample", HOST):
			problems.append("A night alone is not enough: it also wants a find")
		(gs.action_counts[HOST] as Dictionary)[GameStateScript.AQUIFER_FIND_COUNT] = { "count": 1, "xp": 0 }
		QuestEngine.update(gs, [HOST] as Array[String])
		if not QuestEngine.is_done(gs, "the_sump_sample", HOST):
			problems.append("A night and a find complete it (any order)")
		if _count(gs, HOST, Camp.NIGHT_COUNT) != 0:
			problems.append("An Aquifer night does not count for Two Sunsets")
		return "\n".join(problems))


func test_the_ice_night_quest_opens_its_camp_and_one_warm_night_completes_it() -> String:
	return _camp_farm(ICE, false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		gs.lab_xp = gs.xp_for_level(12)
		gs.action_counts[HOST] = { "reached_ice_caves": { "count": 1, "xp": 0 } }
		var problems: Array[String] = []
		QuestEngine.update(gs, [HOST] as Array[String])
		if not gs.camps_open.has(ICE):
			problems.append("Taking the quest opens the Ice Caves camp: %s" % [gs.camps_open])
		_hub(gs, ICE, [HOST], Camp.position(ICE), false, 1)
		gs.cold_since[HOST] = GameClock.elapsed_days
		if gs.go_to_bed(HOST) != "":
			problems.append("A warm night at the Ice Caves camp")
		QuestEngine.update(gs, [HOST] as Array[String])
		if not QuestEngine.is_done(gs, "a_night_on_the_ice", HOST):
			problems.append("One night completes it")
		return "\n".join(problems))


# --- A night -----------------------------------------------------------------------------

func test_alone_the_day_ends_at_either_camp_with_no_fee() -> String:
	var problems: Array[String] = []
	for zone: String in [AQUIFER, ICE]:
		var problem: String = _camp_farm(zone, false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
			_hub(gs, zone, [HOST], Camp.position(zone))
			gs.cold_since[HOST] = GameClock.elapsed_days
			var why: String = gs.go_to_bed(HOST)
			var out: Array[String] = []
			if why != "" or clock.get_day_index() != 2:
				out.append("The day ends at once: '%s', %s" % [why, clock.format_now()])
			if gs.credits != 500 or gs.camp_supplies != 0:
				out.append("No fee, one supply: %d CR, %d left" % [gs.credits, gs.camp_supplies])
			if gs.place_of(HOST) != zone or gs.depth_of(HOST) != 0:
				out.append("Nobody is moved: %s, depth %d" % [gs.place_of(HOST), gs.depth_of(HOST)])
			if _count(gs, HOST, Camp.night_key(zone)) != 1:
				out.append("The night is counted once under %s" % Camp.night_key(zone))
			return "\n".join(out))
		if problem != "":
			problems.append("%s: %s" % [zone, problem])
	return "\n".join(problems)


func test_a_guest_at_either_camp_counts_in_bed_and_ends_the_day() -> String:
	var problems: Array[String] = []
	for zone: String in [AQUIFER, ICE]:
		var problem: String = _camp_farm(zone, true, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
			_hub(gs, zone, [GUEST], Camp.position(zone))
			gs.cold_since[GUEST] = GameClock.elapsed_days
			var out: Array[String] = []
			if beds.go_to_bed(HOST) != "" or clock.elapsed_days != 0.5:
				out.append("The host in bed alone: the day waits")
			var why: String = gs.go_to_bed(GUEST)
			if why != "" or clock.get_day_index() != 2:
				out.append("The guest at the camp is last in bed: the day ends ('%s', %s)" % [why, clock.format_now()])
			if gs.credits != 500:
				out.append("No fee: %d CR" % gs.credits)
			return "\n".join(out))
		if problem != "":
			problems.append("%s: %s" % [zone, problem])
	return "\n".join(problems)


func test_bed_elsewhere_in_those_zones_is_still_refused() -> String:
	var problems: Array[String] = []
	for zone: String in [AQUIFER, ICE]:
		var problem: String = _camp_farm(zone, false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
			var out: Array[String] = []
			var camp_at: Vector3 = Camp.position(zone)
			_hub(gs, zone, [HOST], Vector3(camp_at.x + 30.0, 0.0, camp_at.z + 30.0))
			gs.cold_since[HOST] = GameClock.elapsed_days
			if gs.go_to_bed(HOST) == "":
				out.append("Away from the camp in the hub: refused")
			_hub(gs, zone, [HOST], camp_at)
			gs.player_places[HOST] = [zone, 1]
			if gs.go_to_bed(HOST) == "":
				out.append("Below the hub: refused")
			gs.player_places[HOST] = [zone, 0]
			gs.camps_open.clear()
			if gs.go_to_bed(HOST) == "":
				out.append("At a shut camp: refused")
			if clock.get_day_index() != 1:
				out.append("None of those ended the day")
			return "\n".join(out))
		if problem != "":
			problems.append("%s: %s" % [zone, problem])
	return "\n".join(problems)


# --- The cold ----------------------------------------------------------------------------

func test_a_cold_pack_is_refused_a_night_at_the_ice_camp_and_not_stranded() -> String:
	return _camp_farm(ICE, false, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		_hub(gs, ICE, [HOST], Camp.position(ICE), true, 2)
		var now: float = GameClock.elapsed_days
		gs.cold_since[HOST] = now - 1.0
		var problems: Array[String] = []
		var why: String = gs.go_to_bed(HOST)
		if why == "" or not why.contains("heater"):
			problems.append("A cold pack is refused and told to buy a heater: '%s'" % why)
		if gs.camp_supplies != 2 or _count(gs, HOST, Camp.night_key(ICE)) != 0 or clock.get_day_index() != 1:
			problems.append("A refusal costs no supply and counts no night")
		if HOST in beds.in_bed:
			problems.append("A refused player is not in bed, so the 02:00 recall still carries them out")
		gs.cold_since[HOST] = now - (IceDepth.COLD_THRESHOLD - 10.0) / IceDepth.COLD_PER_HOUR / 24.0
		if gs.go_to_bed(HOST) != "":
			problems.append("A pack warmed to under the threshold may sleep")
		return "\n".join(problems))


func test_the_cold_rule_is_the_ice_caves_alone_and_has_a_clear_edge() -> String:
	var problems: Array[String] = []
	if Camp.cold_problem(ICE, IceDepth.COLD_THRESHOLD) == "":
		problems.append("At the threshold the Ice camp is refused")
	if Camp.cold_problem(ICE, IceDepth.COLD_THRESHOLD - 0.1) != "":
		problems.append("Under the threshold it is allowed")
	if Camp.cold_problem(ICE, 100.0).contains("%d"):
		problems.append("The refusal is filled in")
	return "\n".join(problems)


func test_an_ice_camper_wakes_warm() -> String:
	var gs: GameStateScript = _state(ICE)
	gs.player_places[HOST] = [ICE, 0]
	gs.player_places[GUEST] = [ICE, 0]
	var long_ago: float = GameClock.elapsed_days - 1.0
	gs.cold_since[HOST] = long_ago
	gs.cold_since[GUEST] = long_ago
	gs._campers[HOST] = true
	gs._warm_ice_campers()
	var problems: Array[String] = []
	if float(gs.cold_since[HOST]) <= long_ago:
		problems.append("The camper wakes warm")
	if float(gs.cold_since[GUEST]) != long_ago:
		problems.append("A neighbour who did not camp stays cold")
	gs.free()
	return "\n".join(problems)


# --- Saves ------------------------------------------------------------------------------

func test_the_new_camps_save_and_an_old_save_loads() -> String:
	var gs: GameStateScript = _state(ICE)
	gs.camps_open.append(AQUIFER)
	gs.camps_open.append(ICE)
	gs.camp_supplies = 2
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var back: GameStateScript = _state(ICE)
	var problems: Array[String] = []
	if back.farm_from_dict(data) != "" or not back.camps_open.has(AQUIFER) or not back.camps_open.has(ICE):
		problems.append("A save keeps both open camps: %s" % [back.camps_open])
	var old: Dictionary = data.duplicate(true)
	old.erase("camps_open")
	old.erase("camp_supplies")
	var past: GameStateScript = _state(ICE)
	if past.farm_from_dict(old) != "" or not past.camps_open.is_empty():
		problems.append("An old save has shut camps")
	gs.free()
	back.free()
	past.free()
	return "\n".join(problems)


func test_the_protocol_is_46_after_phobos_deep() -> String:
	return "" if CoopSession.PROTOCOL == 46 else "The camps added no command; Phobos deep took 46, not %d" % CoopSession.PROTOCOL


# --- The counters and a whole run -------------------------------------------------------

func _at_noon(body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 12.0)
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


## Takes the first Aquifer find the host's rule lets through, with the rover at depth 1.
## Returns the reply of the last try ("" for a taken find) and `found` says whether one was tried.
func _take_one(gs: GameStateScript) -> String:
	var day: int = GameClock.get_day_index()
	var data: Dictionary = AquiferDepth.layout(424242, 1, day)
	var reply: String = "no find"
	gs.rover_zone = AQUIFER
	gs.rover_lent = true
	gs.rover_depth = 1
	gs.player_places[HOST] = [AQUIFER, 1]
	for find: Dictionary in data["finds"]:
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(data["grid"], find["cell"]))
		reply = gs.take_find(str(find["id"]), day, HOST)
		if not ZoneDepth.taken_today(gs.finds_taken, AQUIFER, day).is_empty():
			return ""  # taken (a wet pack's reply is still a taken find)
	return reply


func test_driving_to_the_aquifer_counts_the_visit_once() -> String:
	var gs: GameStateScript = _state(AQUIFER)
	var problems: Array[String] = []
	_at_noon(func() -> String:
		gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.AQUIFER_PAD)
		var why: String = gs.move_rover_aquifer(true, HOST)
		if why != "":
			problems.append("Driving in was refused: '%s'" % why)
		if _count(gs, HOST, "reached_flooded_aquifer") != 1:
			problems.append("One drive counts one visit: %d" % _count(gs, HOST, "reached_flooded_aquifer"))
		return "")
	gs.free()
	return "
".join(problems)


func test_fast_travelling_to_the_aquifer_counts_the_visit_once() -> String:
	var gs: GameStateScript = _state(AQUIFER)
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	var problems: Array[String] = []
	_at_noon(func() -> String:
		var why: String = gs.fast_travel(AQUIFER, HOST)
		if why != "":
			problems.append("The console refused: '%s'" % why)
		if _count(gs, HOST, "reached_flooded_aquifer") != 1:
			problems.append("One trip counts one visit: %d" % _count(gs, HOST, "reached_flooded_aquifer"))
		return "")
	gs.free()
	return "
".join(problems)


func test_an_aquifer_take_counts_a_find_and_a_refused_take_counts_none() -> String:
	var gs: GameStateScript = _state(AQUIFER)
	var problems: Array[String] = []
	_at_noon(func() -> String:
		var day: int = GameClock.get_day_index()
		gs.rover_zone = AQUIFER
		gs.rover_lent = true
		gs.rover_depth = 1
		gs.player_places[HOST] = [AQUIFER, 1]
		if gs.take_find("d1_f0", day + 1, HOST) == "":
			problems.append("Yesterday's floor is refused")
		if _count(gs, HOST, GameStateScript.AQUIFER_FIND_COUNT) != 0:
			problems.append("A refused take counts none")
		if _take_one(gs) != "":
			problems.append("No Aquifer find could be taken today")
		elif _count(gs, HOST, GameStateScript.AQUIFER_FIND_COUNT) != 1:
			problems.append("A taken find counts one: %d" % _count(gs, HOST, GameStateScript.AQUIFER_FIND_COUNT))
		return "")
	gs.free()
	return "
".join(problems)


func test_the_sump_sample_runs_from_the_visit_to_the_end() -> String:
	return _camp_farm(AQUIFER, false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		var problems: Array[String] = []
		gs.lab_xp = gs.xp_for_level(12)
		_at_noon(func() -> String:
			QuestEngine.update(gs, [HOST] as Array[String])
			if gs.quest_state.has("the_sump_sample") or gs.camps_open.has(AQUIFER):
				problems.append("Not offered before a visit")
			gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.AQUIFER_PAD)
			if gs.move_rover_aquifer(true, HOST) != "":
				problems.append("Driving in")
			QuestEngine.update(gs, [HOST] as Array[String])
			if not gs.camps_open.has(AQUIFER):
				problems.append("The visit offers the quest and opens the camp")
			if _take_one(gs) != "":
				problems.append("A find was taken")
			_hub(gs, AQUIFER, [HOST], Camp.position(AQUIFER), true, 1)
			if gs.go_to_bed(HOST) != "":
				problems.append("The night at the camp")
			QuestEngine.update(gs, [HOST] as Array[String])
			if not QuestEngine.is_done(gs, "the_sump_sample", HOST):
				problems.append("A visit, a find and a night finish the quest")
			return "")
		return "
".join(problems))


func test_a_camper_who_paid_tonight_is_not_asked_for_the_heater_again() -> String:
	return _camp_farm(ICE, true, func(gs: GameStateScript, beds: Node, _clock: Node) -> String:
		_hub(gs, ICE, [HOST], Camp.position(ICE), true, 2)
		var now: float = GameClock.elapsed_days
		gs.cold_since[HOST] = now
		var problems: Array[String] = []
		if gs.go_to_bed(HOST) != "":
			problems.append("The first night, warm")
		beds.get_up(HOST)
		gs.cold_since[HOST] = now - 1.0
		if gs.go_to_bed(HOST) != "":
			problems.append("Lying down again after paying is not refused for cold")
		if gs.camp_supplies != 1 or _count(gs, HOST, Camp.night_key(ICE)) != 1:
			problems.append("No second supply and no second night: %d left, %d counted" % [gs.camp_supplies, _count(gs, HOST, Camp.night_key(ICE))])
		return "
".join(problems))
