extends RefCounted
## The Abandoned Colony Mine (docs/design/zones.md section 14, build step 14): the gate on
## the plateau road, Bram's gate-key quest, depth 1 from the hash, the rockfalls and the
## shoring props, the saved fields and the recall. Every number is a [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "colony_mine"


## Stands in for CoopBeds where a test only needs to know who was put to bed.
class _NoBeds:
	extends RefCounted
	var put_to_bed: Array[String] = []

	func recall_to_bed(player_id: String) -> void:
		put_to_bed.append(player_id)


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


## The rover (and the host) in the Mine at `depth`, at `at`.
func _rover_at(gs: GameStateScript, depth: int, at: Vector3) -> void:
	gs.rover_zone = ZONE
	gs.rover_lent = true
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[HOST] = [ZONE, depth]


## The first find in a room behind a rockfall on `day`: [find id, its place, rockfall id], or [].
func _blocked_find(day: int) -> Array:
	var data: Dictionary = MineDepth.layout(SEED, 1, day)
	for fall: Dictionary in data["rockfalls"]:
		for find: Dictionary in data["finds"]:
			if int(find["room"]) == int(fall["room"]):
				return [str(find["id"]), TunnelRock.at_in(data["grid"], find["cell"]), str(fall["id"])]
	return []


# --- The gate ------------------------------------------------------------------------

func test_the_gate_is_sealed_until_it_is_opened_and_a_sealed_gate_refuses() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.MINE_PAD)
		if gs.mine_gate_open:
			problems.append("A new farm starts with the gate open.")
		var why: String = gs.move_rover_mine(true, HOST)
		if why != MineDepth.GATE_SEALED_TEXT or not why.contains("Bram"):
			problems.append("A sealed gate says it is sealed and names Bram: '%s'" % why)
		if gs.rover_zone != "" or gs.zones_unlocked.has(ZONE):
			problems.append("The sealed gate let the rover in or opened the zone: '%s'." % gs.rover_zone)
		if gs.open_mine_gate() != "" or not gs.mine_gate_open:
			problems.append("open_mine_gate did not open the gate.")
		if gs.open_mine_gate() != "":
			problems.append("Opening the open gate twice was refused.")
		if gs.move_rover_mine(true, HOST) != "":
			problems.append("The open gate refused the rover: '%s'" % gs.move_rover_mine(true, HOST))
		if gs.rover_zone != ZONE or not gs.rover_lent or gs.rover_depth != 0 or not gs.zones_unlocked.has(ZONE):
			problems.append("The rover is not in the Mine, lent, at the hub, with the zone opened: '%s'." % gs.rover_zone)
		if gs.place_of(HOST) != ZONE:
			problems.append("The player is not recorded in the Mine: '%s'." % gs.place_of(HOST))
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, GameState.TUNNEL_EXIT)
		if gs.move_rover(false, HOST) != "":
			problems.append("The way home from the Mine was refused.")
		if gs.rover_zone != "" or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The rover did not come out: '%s'." % gs.rover_zone)
		var far: GameStateScript = _state()
		far.open_mine_gate()
		far.rover_transforms[far.ROVER] = Transform3D(Basis.IDENTITY, GameState.TUNNEL_PAD)
		if far.move_rover_mine(true, HOST) == "":
			problems.append("The Mine's gate took a rover from the tunnel mouth.")
		far.free()
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_open_mine_gate_is_host_only() -> String:
	var held: bool = FarmCommands.guest
	var gs: GameStateScript = _state()
	FarmCommands.guest = true
	var why: String = gs.open_mine_gate()
	FarmCommands.guest = held
	var opened: bool = gs.mine_gate_open
	gs.free()
	return "" if why != "" and not opened else "A guest's farm opened the gate: '%s'." % why


func test_under_lab_level_twelve_the_gate_warns_and_still_lets_you_in() -> String:
	if ZoneData.warning_text(&"colony_mine", 3) == "" or ZoneData.warning_text(&"colony_mine", 11) == "":
		return "A lab level under 12 got no warning at the gate."
	if ZoneData.warning_text(&"colony_mine", 12) != "":
		return "Lab level 12 is in the band: no warning."
	var gs: GameStateScript = _state()
	gs.open_mine_gate()
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.MINE_PAD)
	var let_in: String = gs.move_rover_mine(true, HOST)  # the warning is the screen's; the host does not gate on level
	var zone: String = gs.rover_zone
	gs.free()
	return "" if let_in == "" and zone == ZONE else "The warned gate kept the rover out: '%s' '%s'." % [let_in, zone]


func test_the_mine_is_a_fast_travel_choice_once_it_has_been_visited() -> String:
	for row: Dictionary in FastTravel.destinations(12, []):
		if row["id"] == ZONE:
			return "The Mine is listed before the first visit."
	for row: Dictionary in FastTravel.destinations(12, [ZONE]):
		if row["id"] == ZONE:
			return ""
	return "The Mine is not listed after the first visit."


# --- Bram's gate-key quest -----------------------------------------------------------

func test_the_gate_key_quest_is_clean_and_opens_the_gate_when_done() -> String:
	var quest: Dictionary = {}
	for entry: Dictionary in QuestEngine.quests():
		if str(entry.get("id", "")) == "the_gate_key":
			quest = entry
	if quest.is_empty():
		return "The gate-key quest is not in the data."
	if QuestEngine.data_problem(quest) != "":
		return "The quest is not clean: %s" % QuestEngine.data_problem(quest)
	var odd: Dictionary = quest.duplicate(true)
	(odd["rewards"] as Dictionary)["mine_gate"] = "yes"
	if QuestEngine.data_problem(odd) == "":
		return "A mine_gate reward that is not true was accepted."
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		gs.lab_xp = gs.xp_for_level(10)
		QuestEngine.update(gs, [HOST] as Array[String])
		if gs.mine_gate_open:
			problems.append("Taking the quest opened the gate before the work was done.")
		gs.mine_fissure(&"FissureA", HOST)
		gs.mine_fissure(&"FissureB", HOST)
		QuestEngine.update(gs, [HOST] as Array[String])
		if not QuestEngine.is_done(gs, "the_gate_key", HOST):
			problems.append("Two fissures did not finish the quest.")
		if not gs.mine_gate_open:
			problems.append("Finishing the quest did not open the gate.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Depth 1 from the hash -----------------------------------------------------------

func test_depth_one_is_the_same_for_the_same_seed_and_day_and_new_the_next_day() -> String:
	var a: Dictionary = MineDepth.layout(SEED, 1, 5)
	var b: Dictionary = MineDepth.layout(SEED, 1, 5)
	if "|".join(a["grid"]) != "|".join(b["grid"]) or var_to_str(a["finds"]) != var_to_str(b["finds"]) or var_to_str(a["rockfalls"]) != var_to_str(b["rockfalls"]):
		return "The same seed and day made two different floors."
	var changed: int = 0
	for day: int in range(5, 15):
		var here: Dictionary = MineDepth.layout(SEED, 1, day)
		var next: Dictionary = MineDepth.layout(SEED, 1, day + 1)
		if var_to_str(next["finds"]) != var_to_str(here["finds"]) or var_to_str(next["rockfalls"]) != var_to_str(here["rockfalls"]):
			changed += 1
	if changed < 9:
		return "The floor changed on only %d of 10 days." % changed
	if not MineDepth.layout(SEED, 0, 5).is_empty() or not MineDepth.layout(SEED, 7, 5).is_empty():
		return "Depths 1 to 6 exist: there is no depth 0 floor and no depth 7."
	if a["finds"].size() != MineDepth.find_count():
		return "The floor has %d finds, not %d." % [a["finds"].size(), MineDepth.find_count()]
	for day: int in range(1, 60):
		var data: Dictionary = MineDepth.layout(SEED, 1, day)
		var falls: int = (data["rockfalls"] as Array).size()
		if falls < MineDepth.MIN_BLOCKED or falls > MineDepth.MAX_BLOCKED:
			return "Day %d has %d rockfalls." % [day, falls]
		var seen: Array[Vector2i] = ZoneDepth.reachable(data["grid"], ZoneDepth.START_CELL)
		for find: Dictionary in data["finds"]:
			if not find["cell"] in seen:
				return "Day %d: %s cannot be reached." % [day, find["id"]]
		if not ZoneDepth.UP_CELL in seen:
			return "Day %d: the way up is cut off." % day
	return ""


func test_a_find_is_taken_host_run_and_once() -> String:
	var problems: Array[String] = []
	var day: int = 6
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var data: Dictionary = MineDepth.layout(SEED, 1, day)
		var open: Dictionary = {}
		for find: Dictionary in data["finds"]:
			var blocked: bool = false
			for fall: Dictionary in data["rockfalls"]:
				blocked = blocked or int(fall["room"]) == int(find["room"])
			if not blocked:
				open = find
				break
		if open.is_empty():
			return "No open find on day %d." % day
		var at: Vector3 = TunnelRock.at_in(data["grid"], open["cell"])
		_rover_at(gs, 1, at)
		var pay: Dictionary = MineDepth.reward(str(open["kind"]))
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		var why: String = gs.take_find(str(open["id"]), day, HOST)
		if why != "":
			problems.append("An open find was refused: '%s'" % why)
		if gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			problems.append("The reward is not the Mine's: %s" % [pay])
		if not str(open["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("The find was not recorded under the Mine.")
		if gs.finds_taken.has("lava_tubes"):
			problems.append("A Mine find was written under the Lava Tubes.")
		if gs.take_find(str(open["id"]), day, HOST) == "":
			problems.append("A find was taken twice.")
		if gs.take_find(str(open["id"]), day - 1, HOST) == "":
			problems.append("Yesterday's floor was accepted.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- The collapse --------------------------------------------------------------------

func test_a_blocked_rooms_find_is_refused_until_the_room_is_shored() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var spot: Array = _blocked_find(day)
	if spot.is_empty():
		return "Day %d has no find behind a rockfall." % day
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var at: Vector3 = spot[1]
		_rover_at(gs, 1, at)
		var refused: String = gs.take_find(spot[0], day, HOST)
		if refused == "" or not refused.contains("rockfall"):
			problems.append("A find behind a rockfall was taken or refused for another reason: '%s'." % refused)
		if ZoneDepth.taken_today(gs.finds_taken, ZONE, day).size() != 0:
			problems.append("A refused find was recorded.")
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, spot[2])
		var allowed: String = gs.take_find(spot[0], day, HOST)
		if allowed != "":
			problems.append("The shored room still blocked the find: '%s'." % allowed)
		if not spot[0] in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("The find was not recorded as taken.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_shoring_needs_props_spends_one_and_clears_the_room_for_today() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var spot: Array = _blocked_find(day)
	if spot.is_empty():
		return "Day %d has no rockfall." % day
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var data: Dictionary = MineDepth.layout(SEED, 1, day)
		var fall: Dictionary = MineDepth.rockfall_in(data, spot[2])
		var there: Vector3 = MineDepth.rockfall_position(fall)
		_rover_at(gs, 1, there)
		var heard: Array[int] = [0]
		gs.mine_changed.connect(func() -> void: heard[0] += 1)
		var none: String = gs.shore_room(spot[2], day, HOST)
		if none == "" or not none.contains("no shoring props"):
			problems.append("Shoring without props said '%s'." % none)
		gs.mine_props = 2
		if gs.shore_room(spot[2], day - 1, HOST) == "":
			problems.append("Shoring on yesterday's floor worked.")
		if gs.shore_room("r9", day, HOST) == "":
			problems.append("A rockfall that is not there was shored.")
		var far: GameStateScript = _state()
		far.mine_props = 2
		_rover_at(far, 1, there + Vector3(30.0, 0.0, 0.0))
		var out_of_reach: String = far.shore_room(spot[2], day, HOST)
		if out_of_reach == "" or not out_of_reach.contains("too far") or far.mine_props != 2:
			problems.append("Shoring from far away said '%s' with %d props." % [out_of_reach, far.mine_props])
		far.free()
		var hub: GameStateScript = _state()
		hub.mine_props = 2
		_rover_at(hub, 0, there)
		if hub.shore_room(spot[2], day, HOST) == "":
			problems.append("The hub's rover shored a rockfall below.")
		hub.free()
		if gs.shore_room(spot[2], day, HOST) != "":
			problems.append("Shoring was refused with props, at the rockfall.")
		if gs.mine_props != 1 or MineDepth.shored_today(gs.rooms_shored, day) != [spot[2]] or heard[0] != 1:
			problems.append("Shoring must spend one prop once and tell the screens: %d props, %s, told %d." % [gs.mine_props, MineDepth.shored_today(gs.rooms_shored, day), heard[0]])
		var again: String = gs.shore_room(spot[2], day, HOST)
		if again == "" or not again.contains("already") or gs.mine_props != 1:
			problems.append("A room shored already said '%s' (%d props)." % [again, gs.mine_props])
		var cleared: Dictionary = MineDepth.layout(SEED, 1, day, MineDepth.shored_today(gs.rooms_shored, day))
		if not bool(MineDepth.rockfall_in(cleared, spot[2])["shored"]) or MineDepth.blocked_problem(cleared, spot[0]) != "":
			problems.append("A shored rockfall still blocks its room.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_shoring_resets_at_six_in_the_morning() -> String:
	var gs: GameStateScript = _state()
	var day: int = 4
	gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, "r0")
	var kept: bool = MineDepth.shored_today(gs.rooms_shored, day) == ["r0"]
	var gone: bool = MineDepth.shored_today(gs.rooms_shored, day + 1).is_empty()
	var next: Dictionary = MineDepth.layout(SEED, 1, day + 1, MineDepth.shored_today(gs.rooms_shored, day + 1))
	var still: bool = false
	for fall: Dictionary in next["rockfalls"]:
		still = still or bool(fall["shored"])
	# A save across the night forgets the old day.
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = float(day)
	var data: Dictionary = gs.farm_to_dict()
	GameClock.elapsed_days = held
	gs.free()
	if not kept or not gone or still:
		return "Shoring did not end with the day: kept %s, gone %s, still shored %s." % [kept, gone, still]
	return "" if (data["rooms_shored"] as Dictionary).is_empty() else "A past day's shoring was saved: %s" % [data["rooms_shored"]]


# --- The crate -----------------------------------------------------------------------

func test_the_crate_sells_props_for_ore_once_and_refuses_when_short() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 0, MineDepth.crate_position())
		var short: String = gs.buy_mine_props(HOST)
		if short == "" or not short.contains("crystal ore") or gs.mine_props != 0:
			problems.append("A farm with no ore bought a prop: '%s'." % short)
		gs.crystal_ore = MineDepth.PROP_COST_ORE + 1
		var heard: Array[int] = [0]
		gs.mine_changed.connect(func() -> void: heard[0] += 1)
		if gs.buy_mine_props(HOST) != "":
			problems.append("A prop was refused with the ore for it.")
		if gs.crystal_ore != 1 or gs.mine_props != MineDepth.PROPS_PER_BUY or heard[0] != 1:
			problems.append("Buying must charge %d ore once: %d ore, %d props, told %d." % [MineDepth.PROP_COST_ORE, gs.crystal_ore, gs.mine_props, heard[0]])
		if gs.buy_mine_props(HOST) == "" or gs.crystal_ore != 1 or gs.mine_props != MineDepth.PROPS_PER_BUY:
			problems.append("A second prop was sold for the ore that was left.")
		_rover_at(gs, 0, MineDepth.crate_position() + Vector3(30.0, 0.0, 0.0))
		gs.crystal_ore = 10
		if gs.buy_mine_props(HOST) == "" or gs.crystal_ore != 10:
			problems.append("A prop was bought from across the hub.")
		_rover_at(gs, 1, MineDepth.crate_position())
		if gs.buy_mine_props(HOST) == "" or gs.crystal_ore != 10:
			problems.append("A prop was bought below the hub.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_mine_commands_are_on_the_list_and_run_through_the_commander() -> String:
	for action: StringName in [&"buy_mine_props", &"shore_room", &"move_rover_mine"]:
		if not action in FarmCommands.ACTIONS:
			return "%s is not a command." % action
	if CoopSession.PROTOCOL != 42:
		return "The protocol is %d, not 42." % CoopSession.PROTOCOL
	var gs: GameStateScript = _state()
	gs.crystal_ore = 5
	_rover_at(gs, 0, MineDepth.crate_position())
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var bought: Variant = ""
	_at(10.5, func() -> String:
		bought = commands.execute(HOST, &"buy_mine_props", [])
		return "")
	var wrong: Variant = commands.execute(HOST, &"shore_room", [3, "x"])
	commands.free()
	var props: int = gs.mine_props
	gs.free()
	if bought != "" or props != 1:
		return "The commander refused the prop: %s" % [bought]
	return "" if wrong != "" else "A number for a rockfall id was accepted."


# --- Save and co-op ------------------------------------------------------------------

func test_the_new_fields_round_trip_and_an_old_save_loads() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		gs.mine_gate_open = true
		gs.mine_props = 3
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, "r1")
		var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var back: GameStateScript = _state()
		if back.farm_from_dict(data) != "":
			problems.append("The saved farm was refused.")
		if not back.mine_gate_open or back.mine_props != 3 or MineDepth.shored_today(back.rooms_shored, day) != ["r1"]:
			problems.append("The gate, the props and the shored room did not survive a save.")
		for bad: Variant in [3, { "lava_tubes": { "day": day, "ids": ["r0"] } }, { ZONE: { "day": day, "ids": ["r0", "r0"] } },
				{ ZONE: { "day": day, "ids": ["r7"] } }, { ZONE: { "day": -1, "ids": [] } }]:
			var junk: Dictionary = gs.farm_to_dict()
			junk["rooms_shored"] = bad
			if gs.farm_dict_problem(junk) == "":
				problems.append("A bad rooms_shored was accepted: %s" % [bad])
		var junk_props: Dictionary = gs.farm_to_dict()
		junk_props["mine_props"] = -1
		if gs.farm_dict_problem(junk_props) == "":
			problems.append("A negative prop count was accepted.")
		var junk_gate: Dictionary = gs.farm_to_dict()
		junk_gate["mine_gate_open"] = "yes"
		if gs.farm_dict_problem(junk_gate) == "":
			problems.append("A bad mine_gate_open was accepted.")
		var old: Dictionary = gs.farm_to_dict()
		old.erase("mine_gate_open")
		old.erase("mine_props")
		old.erase("rooms_shored")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or fresh.mine_gate_open or fresh.mine_props != 0 or not fresh.rooms_shored.is_empty():
			problems.append("A save from before the Mine did not load as sealed, no props, nothing shored.")
		fresh.free()
		var in_mine: Dictionary = gs.farm_to_dict()
		in_mine["rover_zone"] = ZONE
		var there: GameStateScript = _state()
		if there.farm_from_dict(in_mine) != "" or there.rover_zone != ZONE:
			problems.append("A save with the rover in the Mine did not load.")
		there.free()
		gs.free()
		back.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_a_guest_sees_the_gate_the_props_and_the_shored_rooms() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var held_guest: bool = FarmCommands.guest
	var run: String = _at(float(day - 1), func() -> String:
		var host: GameStateScript = _state()
		var guest: GameStateScript = _state()
		host.mine_gate_open = true
		host.mine_props = 2
		host.rooms_shored = ZoneDepth.with_taken(host.rooms_shored, ZONE, day, "r2")
		FarmCommands.guest = true
		guest.local_player_id = GUEST
		var joined: String = FarmSync.join(FarmSync.capture(host), guest)
		if joined != "":
			problems.append("The join was refused: %s" % joined)
		if not guest.mine_gate_open or guest.mine_props != 2 or MineDepth.shored_today(guest.rooms_shored, day) != ["r2"]:
			problems.append("A joining guest does not see the gate, the props and the shored room.")
		FarmCommands.guest = false
		host.mine_props = 1
		host.rooms_shored = ZoneDepth.with_taken(host.rooms_shored, ZONE, day, "r0")
		var heard: Array[int] = [0]
		guest.mine_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var updated: String = FarmSync.update(FarmSync.capture(host), guest)
		FarmCommands.guest = false
		if updated != "":
			problems.append("The update was refused: %s" % updated)
		if guest.mine_props != 1 or MineDepth.shored_today(guest.rooms_shored, day).size() != 2 or heard[0] < 1:
			problems.append("The guest was not told (props %d, told %d)." % [guest.mine_props, heard[0]])
		host.free()
		guest.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


func test_zone_presence_accepts_depths_up_to_six_in_the_mine() -> String:
	for depth: int in [0, 1]:
		if ZonePresence.place_problem(ZONE, depth) != "":
			return "Depth %d in the Mine was refused: %s" % [depth, ZonePresence.place_problem(ZONE, depth)]
	if ZonePresence.place_problem(ZONE, 7) == "":
		return "Depth 7 in the Mine was accepted: there is none."
	return ""


# --- The hatch and the recall --------------------------------------------------------

func test_the_hatch_takes_the_rover_down_and_back_up_and_the_lava_lift_is_refused() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 0, MineDepth.hatch_position())
		var why: String = gs.change_depth(1, HOST)
		if why != "" or gs.rover_depth != 1:
			problems.append("The hatch must take the rover down: '%s', depth %d." % [why, gs.rover_depth])
		gs.player_places[HOST] = [ZONE, 1]
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
		if gs.change_depth(2, HOST) == "" or gs.rover_depth != 1:
			problems.append("The way up must not be a way down: depth 2 is reached from the hatch only.")
		why = gs.change_depth(0, HOST)
		if why != "" or gs.rover_depth != 0:
			problems.append("The way up must bring the rover back: '%s', depth %d." % [why, gs.rover_depth])
		gs.free()
		var lift: GameStateScript = _state()
		_rover_at(lift, 0, MineDepth.hatch_position())
		for depth: int in ZoneDepth.lift_depths():
			lift.lifts_repaired[lift.TUNNELS_ZONE] = [depth]
			if lift.use_lift(depth, HOST) == "" or lift.rover_depth != 0:
				problems.append("The Lava Tubes' lift ran from the Mine.")
				break
		lift.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_two_oclock_rescue_brings_a_player_home_from_the_mine() -> String:
	var problems: Array[String] = []
	var run: String = _at(TunnelRecall.at_hour(1, 2.0), func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = 500
		gs.crystal_ore = 4
		gs.recall_beds = _NoBeds.new()
		gs.recall_in_tunnels = func() -> bool: return true
		_rover_at(gs, 1, Vector3(0.0, 0.0, 0.0))
		gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(40.0, 0.0, 40.0))
		gs._tick_recall()
		if gs._recall_rescued_day != 1:
			problems.append("The 02:00 rescue did not run in the Mine (rescued day %d)." % gs._recall_rescued_day)
		if gs.credits != 450:
			problems.append("The rescue costs 50 CR as in the tunnels: %d CR left." % gs.credits)
		if gs.rover_zone != "" or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The player and the rover are not home: zone '%s'." % gs.rover_zone)
		var home: Vector3 = (gs.rover_transforms[gs.ROVER] as Transform3D).origin
		if home.distance_to(GameState.MINE_PAD) > GameState.TUNNEL_PAD_REACH_M:
			problems.append("The rover came home to %s, not the gate." % [home])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_midnight_warning_covers_the_mine_once() -> String:
	var gs: GameStateScript = _state()
	_rover_at(gs, 0, MineDepth.hatch_position())
	gs.recall_in_tunnels = func() -> bool: return true
	_at(TunnelRecall.at_hour(1, 0.5), func() -> String:
		gs._tick_recall()
		gs._tick_recall()
		return "")
	var warned: int = 0
	for line: String in gs.phone_log:
		if line.contains("Recall in 2 hours"):
			warned += 1
	var rescued: int = gs._recall_rescued_day
	gs.free()
	return "" if warned == 1 and rescued == 0 else "One warning, no rescue yet: %d warnings, rescued day %d." % [warned, rescued]


# --- Review fixes --------------------------------------------------------------------

func test_the_gate_trigger_lies_wholly_inside_the_hosts_pad_reach() -> String:
	var centre: Vector3 = GameState.MINE_PAD + GameState.MINE_TRIGGER_OFFSET
	var half: Vector3 = GameState.MINE_TRIGGER_SIZE * 0.5
	for sx: float in [-1.0, 0.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			var at: Vector3 = centre + Vector3(sx * half.x, 0.0, sz * half.z)
			if at.distance_to(GameState.MINE_PAD) > GameState.TUNNEL_PAD_REACH_M:
				return "A rover at %s is in the trigger but %.1f m from the pad." % [at, at.distance_to(GameState.MINE_PAD)]
			var gs: GameStateScript = _state()
			gs.open_mine_gate()
			gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, at)
			var why: String = gs.move_rover_mine(true, HOST)
			gs.free()
			if why != "":
				return "A rover at %s in the trigger was refused: '%s'" % [at, why]
	return ""


func test_a_blocked_rooms_find_gives_way_to_the_rockfall_prompt() -> String:
	var day: int = 4
	var spot: Array = _blocked_find(day)
	if spot.is_empty():
		return "Day %d has no blocked find." % day
	var data: Dictionary = MineDepth.layout(SEED, 1, day)
	if not MineDepth.prefer_rockfall(data, spot[0], true):
		return "A find in a buried room hid the shore prompt."
	if MineDepth.prefer_rockfall(data, spot[0], false):
		return "With no rockfall in reach the find should still show."
	var shored: Dictionary = MineDepth.layout(SEED, 1, day, [spot[2]])
	if MineDepth.prefer_rockfall(shored, spot[0], true):
		return "A find in a shored room should show, not the rockfall."
	return ""


func test_buying_props_stops_at_the_cap_the_save_check_enforces() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 0, MineDepth.crate_position())
		gs.crystal_ore = 100
		gs.mine_props = MineDepth.MAX_PROPS
		if gs.buy_mine_props(HOST) == "" or gs.mine_props != MineDepth.MAX_PROPS or gs.crystal_ore != 100:
			problems.append("A prop was sold past the cap (%d props, %d ore)." % [gs.mine_props, gs.crystal_ore])
		gs.mine_props = MineDepth.MAX_PROPS - 1
		if gs.buy_mine_props(HOST) != "" or gs.mine_props != MineDepth.MAX_PROPS:
			problems.append("The last prop under the cap was refused.")
		if gs.farm_dict_problem(gs.farm_to_dict()) != "":
			problems.append("A farm at the cap cannot be saved.")
		gs.free()
		return "")
	return run if run != "" else "
".join(problems)
