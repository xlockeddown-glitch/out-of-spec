extends "res://tests/coop_net.gd"
## The camp-outs (docs/design/zones.md sections 6.2 and 12.4, build step 12): the camp
## spot, the shut camp, supplies bought from the shared wallet, a night at the camp as
## going to bed (alone and with friends), the 02:00 recall leaving a camper be, the saved
## fields, and Orin's Two Sunsets.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")

const ZONE: String = "lava_tubes"
const HOST: String = "player_1"
const GUEST: String = "player_2"
const HOME: Vector3 = Vector3(3.0, 0.0, 3.0)
const FAR: Vector3 = Vector3(100.0, 0.0, 100.0)


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, HOME)
	gs.zones_unlocked.append(ZONE)
	gs.credits = 500
	return gs


## `who` is in the Lava Tubes hub with the farm's rover parked at `at` there.
func _hub(gs: GameStateScript, who: Array, at: Vector3, opened: bool = true, supplies: int = 1) -> void:
	for player_id: String in who:
		gs.player_places[player_id] = [ZONE, 0]
		gs._trip_players[player_id] = true
	gs.rover_zone = ZONE
	gs.rover_depth = 0
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	if opened:
		gs.camps_open.append(ZONE)
	gs.camp_supplies = supplies


func _at(hour: float, body: Callable) -> void:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, hour)
	body.call()
	GameClock.elapsed_days = held


## Runs `body(gs, beds, clock)` on a farm with real beds and a host session, plus a joined
## guest when `with_guest`. Frees everything.
func _camp_farm(with_guest: bool, body: Callable) -> String:
	var host: Node = _host()
	if with_guest:
		_guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = 0.5
	var gs: GameStateScript = _state()
	gs.recall_beds = beds
	var out: Variant = body.call(gs, beds, clock)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	beds.free()
	clock.free()
	return _finish(problem)


# --- The spot ---------------------------------------------------------------------------

func test_the_camp_cell_is_free_floor_in_the_hub() -> String:
	var cell: Vector2i = Camp.cell(ZONE)
	if not TunnelRock.is_floor(cell):
		return "The camp's cell %s is not floor." % [cell]
	var used: Array[Vector2i] = [LavaHub.RACK_CELL, LavaHub.BOARD_CELL, ZoneDepth.DESCENT_CELL, ZoneDepth.HUB_LIFT_CELL, Vector2i(14, 11), Vector2i(14, 12)]
	for spot_id: String in LavaHub.spot_ids():
		used.append(LavaHub.SPOTS[spot_id])
	for other: Vector2i in used:
		if absi(other.x - cell.x) + absi(other.y - cell.y) < 2:
			return "The camp's cell %s is on or beside %s." % [cell, other]
	if Camp.position(ZONE) == Vector3.ZERO or not Camp.has_camp(ZONE) or Camp.has_camp("flooded_aquifer"):
		return "Only the Lava Tubes have a camp this build, and it has a place."
	return ""


func test_the_camp_prop_shows_only_once_the_camp_is_open() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var held: Array[String] = GameState.camps_open.duplicate()
	GameState.camps_open.clear()
	var prop: CampProps = CampProps.new(ZONE)
	tree.root.add_child(prop)
	var problems: Array[String] = []
	if prop.is_shown():
		problems.append("A shut camp shows nothing")
	GameState.camps_open.append(ZONE)
	GameState.camps_changed.emit()
	if not prop.is_shown():
		problems.append("The camp shows once it is open")
	GameState.camps_open.clear()
	GameState.camps_changed.emit()
	if prop.is_shown():
		problems.append("And hides again if it is shut")
	tree.root.remove_child(prop)
	prop.free()
	GameState.camps_open.assign(held)
	return "
".join(problems)


# --- Shut and without supplies ----------------------------------------------------------

func test_sleeping_at_a_shut_camp_is_refused() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
		_hub(gs, [HOST], Camp.position(ZONE), false, 1)
		var why: String = gs.go_to_bed(HOST)
		var problems: Array[String] = []
		if not why.contains("shut"):
			problems.append("A shut camp says so: '%s'" % why)
		if gs.camp_supplies != 1 or clock.elapsed_days != 0.5:
			problems.append("Nothing changed: %d supplies, day at %s" % [gs.camp_supplies, clock.elapsed_days])
		return "\n".join(problems))


func test_sleeping_without_supplies_is_refused_with_a_clear_message() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
		_hub(gs, [HOST], Camp.position(ZONE), true, 0)
		var why: String = gs.go_to_bed(HOST)
		var problems: Array[String] = []
		if not why.contains("No supplies") or not why.contains("30"):
			problems.append("It says what is missing and the price: '%s'" % why)
		if clock.elapsed_days != 0.5:
			problems.append("The day did not end")
		return "\n".join(problems))


func test_sleeping_away_from_the_camp_or_below_is_refused() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
		_hub(gs, [HOST], FAR)
		var problems: Array[String] = []
		var far: String = gs.go_to_bed(HOST)
		if not far.contains("Park the rover"):
			problems.append("A rover far from the camp is refused: '%s'" % far)
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Camp.position(ZONE))
		gs.player_places[HOST] = [ZONE, 2]
		var below: String = gs.go_to_bed(HOST)
		if below == "":
			problems.append("Down a shaft there is no bed")
		gs.player_places[HOST] = [AquiferDepth.ZONE, 0]
		var other: String = gs.go_to_bed(HOST)
		if other == "":
			problems.append("A zone with no camp is no bed: still refused")
		if gs.camp_supplies != 1 or clock.elapsed_days != 0.5:
			problems.append("No supply was used and the day did not end")
		return "\n".join(problems))


func test_a_camp_scene_is_a_bed_only_when_open_at_the_first_depth() -> String:
	var held_open: Array[String] = GameState.camps_open.duplicate()
	var held_depth: int = ZoneDepth.local_depth
	var problems: Array[String] = []
	GameState.camps_open.clear()
	ZoneDepth.local_depth = 0
	if GameState.camp_scene_open(SceneSwitcher.TUNNELS_SCENE):
		problems.append("A shut camp's hub is no bed")
	GameState.camps_open.append(ZONE)
	if not GameState.camp_scene_open(SceneSwitcher.TUNNELS_SCENE):
		problems.append("An open camp's hub may be a bed")
	ZoneDepth.local_depth = 2
	if GameState.camp_scene_open(SceneSwitcher.TUNNELS_SCENE):
		problems.append("A depth is no bed")
	ZoneDepth.local_depth = held_depth
	if GameState.camp_scene_open(SceneSwitcher.DOME_SCENE) or GameState.camp_scene_open(""):
		problems.append("The dome and a menu are no bed")
	GameState.camps_open.assign(held_open)
	if BedsScript.scene_refusal(SceneSwitcher.TUNNELS_SCENE) == "" or BedsScript.scene_refusal(SceneSwitcher.TUNNELS_SCENE, true) != "" or BedsScript.scene_refusal(SceneSwitcher.FARM_SCENE) != "":
		problems.append("scene_refusal: the farm, or an open camp, and nothing else")
	return "\n".join(problems)


# --- Supplies ---------------------------------------------------------------------------

func test_a_buy_charges_the_shared_wallet_once_and_a_short_wallet_is_refused() -> String:
	var gs: GameStateScript = _state()
	_hub(gs, [HOST], Camp.position(ZONE), true, 0)
	var problems: Array[String] = []
	gs.credits = 100
	if gs.buy_camp_supplies(HOST) != "" or gs.credits != 70 or gs.camp_supplies != 1:
		problems.append("One buy: 30 CR and one night (%d CR, %d)" % [gs.credits, gs.camp_supplies])
	gs.credits = 29
	var short: String = gs.buy_camp_supplies(HOST)
	if short == "" or gs.credits != 29 or gs.camp_supplies != 1:
		problems.append("A short wallet is refused and nothing moves: '%s' %d CR, %d" % [short, gs.credits, gs.camp_supplies])
	gs.credits = 500
	gs.buy_camp_supplies(HOST)
	gs.buy_camp_supplies(HOST)
	var full: String = gs.buy_camp_supplies(HOST)
	if gs.camp_supplies != Camp.MAX_SUPPLIES or full == "" or gs.credits != 500 - 2 * Camp.SUPPLY_COST_CREDITS:
		problems.append("The farm holds %d nights and the next buy costs nothing: %d held, %d CR" % [Camp.MAX_SUPPLIES, gs.camp_supplies, gs.credits])
	gs.free()
	return "\n".join(problems)


func test_a_buy_is_refused_while_shut_away_from_the_camp_or_on_the_farm() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	_hub(gs, [HOST], Camp.position(ZONE), false, 0)
	if gs.buy_camp_supplies(HOST) == "" or gs.credits != 500:
		problems.append("A shut camp sells nothing")
	gs.camps_open.append(ZONE)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, FAR)
	if gs.buy_camp_supplies(HOST) == "" or gs.credits != 500:
		problems.append("A rover far away buys nothing")
	gs.player_places[HOST] = [ZonePresence.FARM, 0]
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Camp.position(ZONE))
	if gs.buy_camp_supplies(HOST) == "" or gs.credits != 500 or gs.camp_supplies != 0:
		problems.append("The farm sells no supplies")
	gs.free()
	return "\n".join(problems)


func test_the_buy_is_a_host_run_command_that_runs_below_only() -> String:
	if not &"buy_camp_supplies" in FarmCommands.ACTIONS or not &"buy_camp_supplies" in FarmCommands.BELOW_ONLY:
		return "buy_camp_supplies is a command, and a below-only one"
	return ""


func test_a_night_uses_one_supply_and_counts_for_the_quests() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		_hub(gs, [HOST], Camp.position(ZONE), true, 2)
		var why: String = gs.go_to_bed(HOST)
		var counted: int = int(((gs.action_counts.get(HOST, {}) as Dictionary).get(Camp.NIGHT_COUNT, {}) as Dictionary).get("count", 0))
		var problems: Array[String] = []
		if why != "" or gs.camp_supplies != 1:
			problems.append("A night uses one supply: '%s', %d left" % [why, gs.camp_supplies])
		if counted != 1:
			problems.append("The night is counted once: %d" % counted)
		return "\n".join(problems))


# --- Sleeping at the camp ---------------------------------------------------------------

func test_alone_the_day_ends_with_no_fee_and_nobody_is_moved() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
		_hub(gs, [HOST], Camp.position(ZONE))
		var why: String = gs.go_to_bed(HOST)
		var problems: Array[String] = []
		if why != "" or clock.get_day_index() != 2:
			problems.append("The day ends at once: '%s', %s" % [why, clock.format_now()])
		if gs.credits != 500:
			problems.append("No rescue fee: %d CR of 500" % gs.credits)
		if gs.place_of(HOST) != ZONE or gs.depth_of(HOST) != 0:
			problems.append("The player is not moved: %s at depth %d" % [gs.place_of(HOST), gs.depth_of(HOST)])
		if gs.rover_zone != ZONE or gs.rover_depth != 0 or not gs.rover_in_tunnels:
			problems.append("The rover stays in the hub: '%s', depth %d" % [gs.rover_zone, gs.rover_depth])
		return "\n".join(problems))


func test_a_host_in_a_farm_bed_and_a_guest_at_the_camp_end_the_day() -> String:
	return _camp_farm(true, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		_hub(gs, [GUEST], Camp.position(ZONE))
		var problems: Array[String] = []
		if beds.go_to_bed(HOST) != "" or clock.elapsed_days != 0.5:
			problems.append("The host in bed alone: the day waits")
		var why: String = gs.go_to_bed(GUEST)
		if why != "" or clock.get_day_index() != 2 or clock.elapsed_days != 1.0:
			problems.append("The guest at the camp is the last in bed: the day ends ('%s', %s)" % [why, clock.format_now()])
		if gs.credits != 500 or gs.camp_supplies != 0:
			problems.append("No fee, one supply: %d CR, %d" % [gs.credits, gs.camp_supplies])
		return "\n".join(problems))


func test_a_guest_at_the_camp_with_the_host_still_up_waits() -> String:
	return _camp_farm(true, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		_hub(gs, [GUEST], Camp.position(ZONE))
		var why: String = gs.go_to_bed(GUEST)
		var problems: Array[String] = []
		if why != "" or clock.elapsed_days != 0.5:
			problems.append("The day waits for the host: '%s', %s" % [why, clock.format_now()])
		if beds.in_bed != [GUEST] or not gs.is_camping(GUEST):
			problems.append("The guest counts as in bed and as camping: %s" % [beds.in_bed])
		if gs.go_to_bed(GUEST) != "":
			problems.append("A second ask is not refused or charged")
		if gs.camp_supplies != 0:
			problems.append("Exactly one supply used: %d left" % gs.camp_supplies)
		gs.get_up(GUEST)
		if gs.is_camping(GUEST):
			problems.append("Getting up ends the camping")
		return "\n".join(problems))


# --- The 02:00 recall -------------------------------------------------------------------

func test_a_camper_is_not_warned_or_rescued_but_a_neighbour_in_the_zone_is() -> String:
	return _camp_farm(true, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		var told: Array = []
		gs.recall_told = func(player_id: String, step: String) -> void: told.append([player_id, step])
		gs.recall_in_tunnels = func() -> bool: return true  # the host is below too
		_hub(gs, [HOST, GUEST], Camp.position(ZONE))
		_at(12.0, func() -> void: gs.move_rover(true, HOST))
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Camp.position(ZONE))
		gs.player_places[HOST] = [ZONE, 0]
		var asleep: String = gs.go_to_bed(GUEST)
		_at(0.5, func() -> void: gs._tick_recall())
		var problems: Array[String] = []
		if asleep != "":
			problems.append("The guest went to bed at the camp: '%s'" % asleep)
		var warned_guest: bool = told.any(func(entry: Array) -> bool: return entry[0] == GUEST)
		if warned_guest:
			problems.append("The camper is not warned at 00:00: %s" % [told])
		_at(2.0, func() -> void: gs._tick_recall())
		if told.any(func(entry: Array) -> bool: return entry[0] == GUEST and entry[1] == TunnelRecall.RESCUE):
			problems.append("The camper is not rescued at 02:00: %s" % [told])
		if gs.credits != 450:
			problems.append("Only the host pays the fee: %d CR of 500" % gs.credits)
		if gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The host in the zone is carried out")
		if gs.place_of(GUEST) != ZONE or gs.depth_of(GUEST) != 0 or gs.rover_zone != ZONE:
			problems.append("The camper stays at the camp with the rover: %s, rover '%s'" % [gs.place_of(GUEST), gs.rover_zone])
		if clock.get_day_index() != 2:
			problems.append("Both in bed: the day ended (%s)" % clock.format_now())
		return "\n".join(problems))


func test_a_camper_who_gets_up_is_the_recalls_again() -> String:
	return _camp_farm(true, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		gs.recall_in_tunnels = func() -> bool: return false
		_hub(gs, [GUEST], Camp.position(ZONE))
		gs.go_to_bed(GUEST)
		var asleep: bool = gs.is_camping(GUEST)
		gs.get_up(GUEST)
		var told: Array = []
		gs.recall_told = func(player_id: String, step: String) -> void: told.append([player_id, step])
		_at(0.5, func() -> void: gs._tick_recall())
		var problems: Array[String] = []
		if not asleep:
			problems.append("The guest was camping")
		if told.size() != 1 or told[0][0] != GUEST:
			problems.append("Up again, the guest is warned: %s" % [told])
		return "\n".join(problems))


func test_a_new_day_clears_the_campers() -> String:
	var gs: GameStateScript = _state()
	gs._campers[GUEST] = true
	gs._on_day_started(2)
	var problem: String = "" if gs._campers.is_empty() else "The night is over: nobody is a camper"
	gs.free()
	return problem


func test_the_camps_own_buy_does_not_wake_the_camper() -> String:
	if not &"buy_camp_supplies" in FarmCommands.NO_WAKE:
		return "The camp's own buy is a command that leaves a sleeper in bed"
	return ""


func test_getting_up_and_lying_down_again_the_same_night_costs_and_counts_nothing_more() -> String:
	return _camp_farm(true, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		gs.recall_in_tunnels = func() -> bool: return false
		_hub(gs, [GUEST], Camp.position(ZONE), true, 2)
		var problems: Array[String] = []
		if gs.go_to_bed(GUEST) != "":
			problems.append("The first night")
		gs.get_up(GUEST)
		if gs.is_camping(GUEST):
			problems.append("Up, the guest is not camping")
		var why: String = gs.go_to_bed(GUEST)
		var counted: int = int(((gs.action_counts.get(GUEST, {}) as Dictionary).get(Camp.NIGHT_COUNT, {}) as Dictionary).get("count", 0))
		if why != "" or gs.camp_supplies != 1:
			problems.append("Back to bed costs nothing more: '%s', %d left" % [why, gs.camp_supplies])
		if counted != 1:
			problems.append("One night is counted once: %d" % counted)
		if not gs.is_camping(GUEST):
			problems.append("Back in bed, the guest is camping again")
		# Away from the camp the second lie-down is still refused.
		gs.get_up(GUEST)
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, FAR)
		if gs.go_to_bed(GUEST) == "":
			problems.append("A paid camper far from the camp is still refused")
		return "
".join(problems))


func test_a_refused_bed_gives_back_the_supply_and_the_night() -> String:
	return _camp_farm(false, func(gs: GameStateScript, beds: Node, _clock: Node) -> String:
		_hub(gs, [HOST], Camp.position(ZONE), true, 2)
		beds._last_solo_msec = Time.get_ticks_msec()  # the solo cooldown refuses
		var why: String = gs.go_to_bed(HOST)
		var counted: int = int(((gs.action_counts.get(HOST, {}) as Dictionary).get(Camp.NIGHT_COUNT, {}) as Dictionary).get("count", 0))
		var problems: Array[String] = []
		if why == "":
			problems.append("The cooldown refuses the bed")
		if gs.camp_supplies != 2 or gs._campers.has(HOST) or counted != 0:
			problems.append("Nothing is spent or counted: %d supplies, camper %s, %d nights" % [gs.camp_supplies, gs._campers.has(HOST), counted])
		return "
".join(problems))


func test_after_a_camp_night_the_depth_reseeds_and_the_lab_drifts() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		_hub(gs, [HOST], Camp.position(ZONE))
		gs.go_to_bed(HOST)
		var drifted: bool = false
		var before: Dictionary = {}
		for id: Variant in gs.sensors:
			before[id] = (gs.sensors[id] as DriftingSensor).error
		gs._on_time_advanced(1.0)
		for id: Variant in gs.sensors:
			if not is_equal_approx((gs.sensors[id] as DriftingSensor).error, float(before[id])):
				drifted = true
		gs.rover_depth = 2
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, FAR)
		var epoch: int = gs.rover_epoch
		gs._on_day_started(2)
		var problems: Array[String] = []
		if not drifted:
			problems.append("The lab's instruments drift through a camp night")
		if gs.rover_epoch == epoch:
			problems.append("06:00 reseeds the depth the rover stands on")
		return "
".join(problems))


# --- Save and the wire ------------------------------------------------------------------

func test_the_camp_and_its_supplies_are_saved_and_an_old_save_loads() -> String:
	var gs: GameStateScript = _state()
	gs.camps_open.append(ZONE)
	gs.camp_supplies = 2
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var back: GameStateScript = _state()
	var problems: Array[String] = []
	if back.farm_from_dict(data) != "" or not back.camps_open.has(ZONE) or back.camp_supplies != 2:
		problems.append("A save keeps the open camp and the supplies: %s, %d" % [back.camps_open, back.camp_supplies])
	var old: Dictionary = data.duplicate(true)
	old.erase("camps_open")
	old.erase("camp_supplies")
	var past: GameStateScript = _state()
	if past.farm_from_dict(old) != "" or not past.camps_open.is_empty() or past.camp_supplies != 0:
		problems.append("An old save has a shut camp and no supplies")
	var bad: Dictionary = data.duplicate(true)
	bad["camps_open"] = ["nowhere"]
	var refused_zone: GameStateScript = _state()
	if refused_zone.farm_from_dict(bad) == "":
		problems.append("A camp in a zone with none is refused")
	bad = data.duplicate(true)
	bad["camp_supplies"] = 99
	var refused_supplies: GameStateScript = _state()
	if refused_supplies.farm_from_dict(bad) == "":
		problems.append("Too many supplies is refused")
	refused_zone.free()
	refused_supplies.free()
	gs.free()
	back.free()
	past.free()
	return "\n".join(problems)


func test_the_guest_is_shown_the_camp_and_the_supplies() -> String:
	if FarmSync.SHOWN_BY.get(&"camps_changed", []) != ["camps_open", "camp_supplies"]:
		return "A guest sees both through the farm sync"
	return ""


func test_a_guest_who_drops_while_camped_is_forgotten() -> String:
	var gs: GameStateScript = _state()
	_hub(gs, [GUEST], Camp.position(ZONE))
	gs._campers[GUEST] = true
	gs.forget_place(GUEST)
	var problem: String = "" if not gs._campers.has(GUEST) and not gs.is_camping(GUEST) else "A guest who left is no camper"
	gs.free()
	return problem


func test_the_protocol_is_38() -> String:
	return "" if CoopSession.PROTOCOL == 40 else "PROTOCOL is %d, not 40." % CoopSession.PROTOCOL


# --- The quest --------------------------------------------------------------------------

func _two_sunsets() -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == "two_sunsets":
			return quest
	return {}


func test_two_sunsets_data_is_clean_and_names_a_real_camp() -> String:
	var quest: Dictionary = _two_sunsets()
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "Two Sunsets is shipped and has no problem: '%s'" % QuestEngine.data_problem(quest)
	var odd: Dictionary = quest.duplicate(true)
	odd["camp"] = "flooded_aquifer"
	if QuestEngine.data_problem(odd) == "":
		return "A camp in a zone with none is a data problem"
	return ""


func test_taking_two_sunsets_opens_the_camp_and_one_night_completes_it() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		gs.lab_xp = gs.xp_for_level(5)
		var problems: Array[String] = []
		QuestEngine.update(gs, [HOST] as Array[String])
		if not gs.camps_open.has(ZONE) or not (gs.player_quest_state.get(HOST, {}) as Dictionary).has("two_sunsets"):
			problems.append("Taking the quest opens the camp: %s" % [gs.camps_open])
		if QuestEngine.is_done(gs, "two_sunsets", HOST):
			problems.append("Not done before a night")
		_hub(gs, [HOST], Camp.position(ZONE), false, 1)  # its camp is open already
		if gs.go_to_bed(HOST) != "":
			problems.append("The night at the camp")
		QuestEngine.update(gs, [HOST] as Array[String])
		if not QuestEngine.is_done(gs, "two_sunsets", HOST):
			problems.append("One night completes it")
		return "\n".join(problems))


func test_a_held_camp_quest_opens_its_camp_on_a_later_look() -> String:
	return _camp_farm(false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		gs.lab_xp = gs.xp_for_level(5)
		QuestEngine.update(gs, [HOST] as Array[String])
		gs.camps_open.clear()  # a loaded or merged farm that holds the quest but not the camp
		QuestEngine.update(gs, [HOST] as Array[String])
		return "" if gs.camps_open.has(ZONE) else "A held, unfinished camp quest opens its camp")


func test_a_camp_stays_shut_for_a_farm_that_took_no_quest() -> String:
	var gs: GameStateScript = _state()
	QuestEngine.update(gs, [HOST] as Array[String])  # lab level 1: the gate is shut
	var problem: String = "" if gs.camps_open.is_empty() else "Nothing opens the camp before the quest is taken"
	gs.free()
	return problem


func test_open_camp_is_host_run_and_checks_the_zone() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	if gs.open_camp("flooded_aquifer") == "" or not gs.camps_open.is_empty():
		problems.append("A zone with no camp opens nothing")
	if gs.open_camp(ZONE) != "" or gs.open_camp(ZONE) != "" or gs.camps_open != [ZONE]:
		problems.append("Opening twice holds the zone once: %s" % [gs.camps_open])
	gs.free()
	return "\n".join(problems)
