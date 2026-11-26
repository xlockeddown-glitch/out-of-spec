extends RefCounted
## The first depth (docs/design/zones.md section 13, build step 6): the layout from
## the integer hash, the take-a-find command, the saved finds per day, and the wire.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	return gs


func _today() -> int:
	return GameClock.get_day_index()


func _layout(day: int) -> Dictionary:
	return ZoneDepth.layout(SEED, ZoneDepth.ZONE, ZoneDepth.DEPTH, day)


## HOST below, with the farm's rover at `find`'s cell.
func _below(gs: GameStateScript, find: Dictionary) -> void:
	gs.player_places[HOST] = [ZoneDepth.ZONE, ZoneDepth.DEPTH]
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at(find["cell"]))


func _commander(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


# --- The layout -----------------------------------------------------------------

func test_the_same_day_gives_the_same_layout() -> String:
	for day: int in [0, 1, 7, 365]:
		if _layout(day) != _layout(day):
			return "Day %d changed between two calls." % day
	return ""


func test_a_new_day_or_a_new_farm_changes_the_layout() -> String:
	var grids: Array[String] = []
	for day: int in range(0, 12):
		grids.append("|".join(_layout(day)["grid"]) + str(_layout(day)["finds"]))
	var seen: Dictionary = {}
	for g: String in grids:
		seen[g] = true
	if seen.size() < 10:
		return "Twelve days gave only %d different layouts." % seen.size()
	if _layout(3) == ZoneDepth.layout(SEED + 1, ZoneDepth.ZONE, ZoneDepth.DEPTH, 3):
		return "Another farm seed gave the same day."
	return ""


func test_only_the_lava_tubes_depth_one_has_a_layout() -> String:
	if not ZoneDepth.layout(SEED, "flooded_aquifer", 1, 0).is_empty() or not ZoneDepth.layout(SEED, ZoneDepth.ZONE, 2, 0).is_empty() or not ZoneDepth.layout(SEED, ZoneDepth.ZONE, 0, 0).is_empty():
		return "A layout was made where there is no depth."
	return ""


func test_the_map_is_the_size_of_the_tunnels_and_the_ends_are_floor() -> String:
	for day: int in range(0, 40):
		var data: Dictionary = _layout(day)
		var grid: PackedStringArray = data["grid"]
		if grid.size() != ZoneDepth.HEIGHT:
			return "Day %d is %d rows." % [day, grid.size()]
		for row: String in grid:
			if row.length() != ZoneDepth.WIDTH:
				return "Day %d has a row %d wide." % [day, row.length()]
		var start: Vector2i = ZoneDepth.START_CELL
		if grid[start.y][start.x] != ".":
			return "Day %d: the start is not floor." % day
		# The way up is the exit pad's cell in the tunnels scene, (11, 20).
		if grid[20][11] != ".":
			return "Day %d: the way up is not floor." % day
	return ""


func test_every_find_is_reachable_and_inside_a_room() -> String:
	for day: int in range(0, 60):
		var data: Dictionary = _layout(day)
		var reach: Array[Vector2i] = ZoneDepth.reachable(data["grid"], ZoneDepth.START_CELL)
		var rooms: Array = (data["rooms"] as Array).duplicate()
		rooms.append(ZoneDepth.LANDING)
		var ids: Array[String] = []
		var cells: Array[Vector2i] = []
		for find: Dictionary in data["finds"]:
			var cell: Vector2i = find["cell"]
			if not cell in reach:
				return "Day %d: %s at %s cannot be reached." % [day, find["id"], cell]
			var in_room: bool = false
			for room: Rect2i in rooms:
				if room.has_point(cell):
					in_room = true
			if not in_room:
				return "Day %d: %s at %s is not in a room." % [day, find["id"], cell]
			if cell == ZoneDepth.START_CELL or cell in cells or str(find["id"]) in ids:
				return "Day %d: %s is on the start or doubled." % [day, find["id"]]
			if not str(find["kind"]) in ZoneDepth.REWARDS:
				return "Day %d: %s has a kind with no reward." % [day, find["id"]]
			ids.append(str(find["id"]))
			cells.append(cell)
		if ids.size() != ZoneDepth.PER_ROOM * (data["rooms"] as Array).size() + ZoneDepth.ON_LANDING:
			return "Day %d has %d finds." % [day, ids.size()]
		# All of the floor is joined to the start, so nothing is walled off.
		var floor_count: int = 0
		for row: String in data["grid"]:
			floor_count += row.count(".")
		if reach.size() != floor_count:
			return "Day %d: %d floor cells but %d reached." % [day, floor_count, reach.size()]
	return ""


func test_the_hub_way_down_is_floor_and_the_hash_never_uses_random_numbers() -> String:
	if not TunnelRock.is_floor(ZoneDepth.DESCENT_CELL):
		return "The way down is not floor in the hub."
	var h: int = ZoneDepth.stream(SEED, "lava_tubes", 1, 5)
	if h != ZoneDepth.stream(SEED, "lava_tubes", 1, 5) or h == ZoneDepth.stream(SEED, "lava_tubes", 1, 6):
		return "The stream is not a pure function of its inputs."
	for tag: int in range(0, 50):
		var d: int = ZoneDepth.draw(h, tag, 7)
		if d < 0 or d >= 7:
			return "A draw left its range."
	return ""


# --- Taking a find --------------------------------------------------------------

func test_a_find_in_reach_is_taken_once_and_paid() -> String:
	var gs: GameStateScript = _state()
	var find: Dictionary = (_layout(_today())["finds"] as Array)[0]
	_below(gs, find)
	var ore: int = gs.crystal_ore
	var credits: int = gs.credits
	var first: String = gs.take_find(find["id"], HOST)
	var paid_ore: int = gs.crystal_ore - ore
	var paid_credits: int = gs.credits - credits
	var again: String = gs.take_find(find["id"], HOST)
	var pay: Dictionary = ZoneDepth.reward(str(find["kind"]))
	var kept: Array = ZoneDepth.taken_today(gs.finds_taken, ZoneDepth.ZONE, _today())
	gs.free()
	if first != "":
		return "A find in reach was refused: " + first
	if paid_ore != int(pay.get("crystal_ore", 0)) or paid_credits != int(pay.get("credits", 0)):
		return "Paid %d ore and %d credits for %s." % [paid_ore, paid_credits, pay]
	if again == "":
		return "A find was taken twice."
	return "" if kept == [find["id"]] else "Taken today: %s" % [kept]


func test_the_host_refuses_the_wrong_place_depth_find_or_rover() -> String:
	var gs: GameStateScript = _state()
	var finds: Array = _layout(_today())["finds"]
	var find: Dictionary = finds[0]
	var far: Dictionary = finds[finds.size() - 1]
	var wrong: Array[String] = []
	# Never went down.
	_below(gs, find)
	gs.player_places[HOST] = [ZoneDepth.ZONE, 0]
	wrong.append(gs.take_find(find["id"], HOST))
	# On the farm.
	gs.player_places[HOST] = ["farm", 0]
	wrong.append(gs.take_find(find["id"], HOST))
	# Below, but a find that is not there today.
	_below(gs, find)
	wrong.append(gs.take_find("d1_f99", HOST))
	wrong.append(gs.take_find("", HOST))
	# The rover is not in the tubes, or not known, or too far.
	gs.rover_zone = ""
	wrong.append(gs.take_find(find["id"], HOST))
	_below(gs, find)
	gs.rover_transforms.erase(gs.TUNNEL_ROVER)
	wrong.append(gs.take_find(find["id"], HOST))
	_below(gs, far)
	if TunnelRock.at(far["cell"]).distance_to(TunnelRock.at(find["cell"])) > ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M:
		wrong.append(gs.take_find(find["id"], HOST))
	else:
		wrong.append("skipped")
	var nothing: bool = gs.finds_taken.is_empty() and gs.crystal_ore == 0 and gs.credits == 0
	gs.free()
	for i: int in wrong.size():
		if wrong[i] == "":
			return "Refusal %d was missing." % i
	return "" if nothing else "A refused take still changed the farm."


func test_the_command_runs_for_a_player_below_and_is_on_the_list() -> String:
	if not &"take_find" in CommandsScript.ACTIONS:
		return "take_find is not a command."
	var gs: GameStateScript = _state()
	var commands: Node = _commander(gs)
	var find: Dictionary = (_layout(_today())["finds"] as Array)[1]
	var home: Variant = commands.execute(HOST, &"take_find", [find["id"]])
	_below(gs, find)
	var took: Variant = commands.execute(HOST, &"take_find", [find["id"]])
	var twice: Variant = commands.execute(HOST, &"take_find", [find["id"]])
	commands.free()
	gs.free()
	if home == "":
		return "A player not below took a find."
	if took != "":
		return "The command refused a find in reach: %s" % [took]
	return "" if twice != "" else "The command let a find be taken twice."


func test_the_host_allows_a_little_slack_on_the_reach() -> String:
	var gs: GameStateScript = _state()
	var find: Dictionary = (_layout(_today())["finds"] as Array)[0]
	_below(gs, find)
	var spot: Vector3 = TunnelRock.at(find["cell"])
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M + 0.1, 0.0, 0.0))
	var too_far: String = gs.take_find(find["id"], HOST)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M - 0.1, 0.0, 0.0))
	var lagging: String = gs.take_find(find["id"], HOST)
	gs.free()
	if too_far == "":
		return "A rover just past the slack was accepted."
	return lagging


func test_the_rules_alone_judge_a_take() -> String:
	var finds: Array = _layout(0)["finds"]
	var id: String = str(finds[0]["id"])
	if ZoneDepth.take_problem(id, finds, [], "lava_tubes", 1) != "":
		return "A good take was refused."
	for refused: Array in [[id, [], "lava_tubes", 0], [id, [], "farm", 1], [id, [id], "lava_tubes", 1], ["nope", [], "lava_tubes", 1]]:
		if ZoneDepth.take_problem(refused[0], finds, refused[1], refused[2], refused[3]) == "":
			return "%s was accepted." % [refused]
	if not ZoneDepth.near_descent(ZoneDepth.descent_position()) or ZoneDepth.near_descent(Vector3(500.0, 0.0, 500.0)):
		return "near_descent is wrong."
	return ""


func test_beacons_stay_in_the_hub() -> String:
	var gs: GameStateScript = _state()
	gs.player_places[HOST] = [ZoneDepth.ZONE, ZoneDepth.DEPTH]
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, LavaHub.spot_position("spot_west"))
	var refused: String = gs.place_beacon("spot_west", HOST)
	gs.free()
	return "" if refused != "" else "A beacon was set down below the hub."


# --- Saving ---------------------------------------------------------------------

func test_taken_finds_survive_a_save() -> String:
	var gs: GameStateScript = _state()
	var finds: Array = _layout(_today())["finds"]
	_below(gs, finds[0])
	gs.take_find(finds[0]["id"], HOST)
	_below(gs, finds[2])
	gs.take_find(finds[2]["id"], HOST)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var problem: String = gs.farm_dict_problem(data)
	gs.free()
	var back: GameStateScript = _state()
	var loaded: String = back.farm_from_dict(data)
	var got: Array = ZoneDepth.taken_today(back.finds_taken, ZoneDepth.ZONE, _today())
	back.free()
	if problem != "" or loaded != "":
		return "A good save was refused: %s %s" % [problem, loaded]
	return "" if got == [finds[0]["id"], finds[2]["id"]] else "Loaded %s" % [got]


func test_an_old_save_without_finds_loads_with_none() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	gs.free()
	data.erase("finds_taken")
	var back: GameStateScript = _state()
	back.finds_taken = { "lava_tubes": { "day": _today(), "ids": ["d1_f0"] } }
	var problem: String = back.farm_from_dict(data)
	var got: Dictionary = back.finds_taken.duplicate()
	back.free()
	if problem != "":
		return "An old save was refused: " + problem
	return "" if got.is_empty() else "Loaded %s" % [got]


func test_a_save_with_bad_finds_is_refused() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var refused: Array[String] = []
	for bad: Variant in [[], "x", { "": { "day": 1, "ids": [] } }, { "lava_tubes": 4 }, { "lava_tubes": { "day": "1", "ids": [] } }, { "lava_tubes": { "day": -1, "ids": [] } }, { "lava_tubes": { "day": 1, "ids": "d1_f0" } }, { "lava_tubes": { "day": 1, "ids": [4] } }, { "lava_tubes": { "day": 1, "ids": ["d1_f0", "d1_f0"] } }, { "lava_tubes": { "day": 1, "ids": ["rm -rf"] } }]:
		data["finds_taken"] = bad
		refused.append(gs.farm_dict_problem(data))
	gs.free()
	for i: int in refused.size():
		if refused[i] == "":
			return "Bad finds_taken number %d was accepted." % i
	return ""


func test_a_past_day_is_dropped_on_save_and_load() -> String:
	var day: int = _today()
	var old: Dictionary = { "lava_tubes": { "day": day - 1, "ids": ["d1_f0", "d1_f1"] } }
	var pruned: Dictionary = ZoneDepth.prune(old, day)
	var kept: Dictionary = ZoneDepth.prune({ "lava_tubes": { "day": day, "ids": ["d1_f0"] } }, day)
	var added: Dictionary = ZoneDepth.with_taken(old, "lava_tubes", day, "d1_f3")
	if not pruned.is_empty() or kept.size() != 1:
		return "prune kept %s and dropped %s" % [kept, pruned]
	if ZoneDepth.taken_today(old, "lava_tubes", day) != [] or ZoneDepth.taken_today(added, "lava_tubes", day) != ["d1_f3"]:
		return "A past day counted as today."
	var gs: GameStateScript = _state()
	gs.finds_taken = old.duplicate(true)
	var saved: Dictionary = gs.farm_to_dict()
	var back: GameStateScript = _state()
	back.farm_from_dict(bytes_to_var(var_to_bytes(saved)))
	var loaded: Dictionary = back.finds_taken.duplicate()
	gs.free()
	back.free()
	if (saved["finds_taken"] as Dictionary).size() != 0:
		return "A past day was saved: %s" % [saved["finds_taken"]]
	return "" if loaded.is_empty() else "A past day was loaded: %s" % [loaded]


func test_the_finds_are_back_on_a_new_day() -> String:
	var gs: GameStateScript = _state()
	var finds: Array = _layout(_today())["finds"]
	_below(gs, finds[0])
	gs.take_find(finds[0]["id"], HOST)
	var tomorrow: Array = ZoneDepth.taken_today(gs.finds_taken, ZoneDepth.ZONE, _today() + 1)
	gs.free()
	return "" if tomorrow.is_empty() else "Today's finds were still taken tomorrow."


# --- A guest and the wire -------------------------------------------------------

func test_a_guest_is_shown_the_taken_finds() -> String:
	if not FarmSync.SHOWN_BY.has(&"finds_changed") or not "finds_taken" in FarmSync.SHOWN_BY[&"finds_changed"]:
		return "FarmSync does not show finds_taken on finds_changed."
	var host: GameStateScript = _state()
	var find: Dictionary = (_layout(_today())["finds"] as Array)[0]
	_below(host, find)
	host.take_find(find["id"], HOST)
	var data: Dictionary = bytes_to_var(var_to_bytes(host.farm_to_dict()))
	host.free()
	var guest: GameStateScript = _state()
	var seen: Array[int] = [0]
	guest.finds_changed.connect(func() -> void: seen[0] += 1)
	var problem: String = guest.farm_from_dict(data)
	var got: Array = ZoneDepth.taken_today(guest.finds_taken, ZoneDepth.ZONE, _today())
	guest.free()
	if problem != "":
		return problem
	return "" if got == [find["id"]] else "The guest has %s" % [got]


func test_the_protocol_moved_with_the_take_command_and_field() -> String:
	return "" if CoopSession.PROTOCOL >= 19 else "take_find and finds_taken are new on the wire: PROTOCOL must be 19 or more."


func test_presence_reports_depth_one_and_no_deeper() -> String:
	if ZonePresence.MAX_DEPTH != 1:
		return "MAX_DEPTH is %d." % ZonePresence.MAX_DEPTH
	if ZonePresence.place_problem("lava_tubes", 1) != "" or ZonePresence.place_problem("lava_tubes", 2) == "":
		return "Depth 1 should be accepted and depth 2 refused."
	if ZonePresence.place_problem("farm", 1) == "":
		return "A depth on the farm was accepted."
	var was: int = ZoneDepth.local_depth
	var was_layout: Dictionary = ZoneDepth.local_layout
	ZoneDepth.set_local(0, {})
	var hub: Array = ZonePresence.for_scene(SceneSwitcher.TUNNELS_SCENE)
	ZoneDepth.set_local(1, _layout(0))
	var below: Array = ZonePresence.for_scene(SceneSwitcher.TUNNELS_SCENE)
	var farm: Array = ZonePresence.for_scene(SceneSwitcher.FARM_SCENE)
	ZoneDepth.set_local(was, was_layout)
	if hub != ["lava_tubes", 0]:
		return "The hub reported %s" % [hub]
	if below != ["lava_tubes", 1]:
		return "Below reported %s" % [below]
	return "" if farm[1] == 0 else "The farm reported depth %s" % [farm]
