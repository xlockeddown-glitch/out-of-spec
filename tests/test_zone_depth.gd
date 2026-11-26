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
	gs.rover_depth = ZoneDepth.DEPTH
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, _at(find["cell"]))


## The middle of a cell of today's layout, whatever map this test process is on.
func _at(cell: Vector2i) -> Vector3:
	return TunnelRock.at_in(_layout(_today())["grid"], cell)


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
	var first: String = gs.take_find(find["id"], _today(), HOST)
	var paid_ore: int = gs.crystal_ore - ore
	var paid_credits: int = gs.credits - credits
	var again: String = gs.take_find(find["id"], _today(), HOST)
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
	wrong.append(gs.take_find(find["id"], _today(), HOST))
	# On the farm.
	gs.player_places[HOST] = ["farm", 0]
	wrong.append(gs.take_find(find["id"], _today(), HOST))
	# Below, but a find that is not there today.
	_below(gs, find)
	wrong.append(gs.take_find("d1_f99", _today(), HOST))
	wrong.append(gs.take_find("", _today(), HOST))
	# The rover is not in the tubes, or not known, or too far.
	gs.rover_zone = ""
	wrong.append(gs.take_find(find["id"], _today(), HOST))
	_below(gs, find)
	gs.rover_transforms.erase(gs.TUNNEL_ROVER)
	wrong.append(gs.take_find(find["id"], _today(), HOST))
	_below(gs, far)
	if _at(far["cell"]).distance_to(_at(find["cell"])) > ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M:
		wrong.append(gs.take_find(find["id"], _today(), HOST))
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
	var home: Variant = commands.execute(HOST, &"take_find", [find["id"], _today()])
	_below(gs, find)
	var took: Variant = commands.execute(HOST, &"take_find", [find["id"], _today()])
	var twice: Variant = commands.execute(HOST, &"take_find", [find["id"], _today()])
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
	var spot: Vector3 = _at(find["cell"])
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M + 0.1, 0.0, 0.0))
	var too_far: String = gs.take_find(find["id"], _today(), HOST)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M - 0.1, 0.0, 0.0))
	var lagging: String = gs.take_find(find["id"], _today(), HOST)
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
	gs.take_find(finds[0]["id"], _today(), HOST)
	_below(gs, finds[2])
	gs.take_find(finds[2]["id"], _today(), HOST)
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
	gs.take_find(finds[0]["id"], _today(), HOST)
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
	host.take_find(find["id"], _today(), HOST)
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


# --- One rover, one depth (review fixes) ------------------------------------------

## HOST with the farm rover in the hub, parked at `at`.
func _hub_rover(gs: GameStateScript, at: Vector3) -> void:
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 0
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)


func test_the_rover_depth_is_saved_and_an_old_save_loads_as_the_hub() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = ZoneDepth.DEPTH
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var problem: String = gs.farm_dict_problem(data)
	gs.free()
	var back: GameStateScript = _state()
	var loaded: String = back.farm_from_dict(data)
	var depth: int = back.rover_depth
	back.free()
	if problem != "" or loaded != "":
		return "A good save was refused: %s %s" % [problem, loaded]
	if depth != ZoneDepth.DEPTH:
		return "Loaded depth %d." % depth
	var old: Dictionary = data.duplicate(true)
	old.erase("rover_depth")
	var later: GameStateScript = _state()
	later.rover_depth = 1
	var old_problem: String = later.farm_from_dict(old)
	var old_depth: int = later.rover_depth
	later.free()
	if old_problem != "":
		return "An old save was refused: " + old_problem
	return "" if old_depth == 0 else "An old save loaded depth %d." % old_depth


func test_a_save_with_a_bad_rover_depth_is_refused() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	var data: Dictionary = gs.farm_to_dict()
	var refused: Array[String] = []
	for bad: Variant in [-1, ZoneDepth.DEPTH + 1, "1", 1.5, null]:
		data["rover_depth"] = bad
		refused.append(gs.farm_dict_problem(data))
	# Below, with the rover somewhere that is not the Lava Tubes.
	data["rover_depth"] = 1
	data["rover_zone"] = ""
	refused.append(gs.farm_dict_problem(data))
	gs.free()
	for i: int in refused.size():
		if refused[i] == "":
			return "Bad rover_depth number %d was accepted." % i
	return ""


func test_leaving_the_tubes_puts_the_rover_back_in_the_hub_depth() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	gs.rover_zone = ""
	var depth: int = gs.rover_depth
	gs.free()
	return "" if depth == 0 else "The rover kept depth %d outside the Lava Tubes." % depth


func test_rover_depth_goes_to_guests_with_the_rover_zone() -> String:
	var shown: Array = FarmSync.SHOWN_BY.get(&"rover_place_changed", [])
	if not "rover_depth" in shown or not "rover_zone" in shown:
		return "rover_place_changed shows %s." % [shown]
	return ""


func test_the_host_takes_the_rover_down_the_hatch_and_back_up() -> String:
	if not &"change_depth" in CommandsScript.ACTIONS:
		return "change_depth is not a command."
	var gs: GameStateScript = _state()
	_hub_rover(gs, ZoneDepth.descent_position())
	var signals: Array[int] = [0]
	gs.rover_place_changed.connect(func() -> void: signals[0] += 1)
	var down: String = gs.change_depth(1, "")
	var depth_down: int = gs.rover_depth
	var start: Vector3 = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin
	var at_start: bool = start.distance_to(ZoneDepth.start_transform().origin) < 0.01
	# From the start the way up is farther than the reach: refused.
	var early: String = gs.change_depth(0, "")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	var up: String = gs.change_depth(0, "")
	var depth_up: int = gs.rover_depth
	var beside: bool = ZoneDepth.near_descent(gs.parked_rover_transform(gs.TUNNEL_ROVER).origin)
	var emitted: int = signals[0]
	gs.free()
	if down != "":
		return "Down the hatch was refused: " + down
	if depth_down != 1 or not at_start:
		return "Down left depth %d, at the start %s." % [depth_down, at_start]
	if early == "" and not ZoneDepth.near_ascent(ZoneDepth.start_transform().origin):
		return "Up from the start was accepted."
	if up != "":
		return "Up from the way up was refused: " + up
	if depth_up != 0 or not beside:
		return "Up left depth %d, beside the hatch %s." % [depth_up, beside]
	return "" if emitted >= 2 else "The move was not announced (%d)." % emitted


func test_the_host_refuses_a_bad_depth_change() -> String:
	var gs: GameStateScript = _state()
	var refused: Array[String] = []
	# Not in the Lava Tubes.
	gs.rover_zone = ""
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position())
	refused.append(gs.change_depth(1, ""))
	# Too far from the hatch.
	_hub_rover(gs, ZoneDepth.descent_position() + Vector3(60.0, 0.0, 0.0))
	refused.append(gs.change_depth(1, ""))
	# Not known where the rover is.
	_hub_rover(gs, ZoneDepth.descent_position())
	gs.rover_transforms.erase(gs.TUNNEL_ROVER)
	refused.append(gs.change_depth(1, ""))
	# A depth that does not exist, or two steps, or the same one.
	_hub_rover(gs, ZoneDepth.descent_position())
	refused.append(gs.change_depth(2, ""))
	refused.append(gs.change_depth(-1, ""))
	refused.append(gs.change_depth(0, ""))
	# A guest while nobody drives.
	refused.append(gs.change_depth(1, GUEST))
	var depth: int = gs.rover_depth
	gs.free()
	for i: int in refused.size():
		if refused[i] == "":
			return "Refusal %d was missing." % i
	return "" if depth == 0 else "A refused change still moved the rover to depth %d." % depth


func test_change_depth_is_a_checked_command() -> String:
	var gs: GameStateScript = _state()
	var commands: Node = _commander(gs)
	_hub_rover(gs, ZoneDepth.descent_position())
	var good: String = str(commands.problem(&"change_depth", [1]))
	var bad: Array[String] = [str(commands.problem(&"change_depth", [])), str(commands.problem(&"change_depth", ["1"])), str(commands.problem(&"change_depth", [1, 2]))]
	var ran: Variant = commands.execute(HOST, &"change_depth", [1])
	var depth: int = gs.rover_depth
	commands.free()
	gs.free()
	if good != "":
		return "A good call was refused: " + good
	for i: int in bad.size():
		if bad[i] == "":
			return "Bad arguments %d were accepted." % i
	if ran != "":
		return "The command was refused: %s" % [ran]
	return "" if depth == 1 else "The command left depth %d." % depth


func test_a_find_needs_the_rover_at_depth_one() -> String:
	var gs: GameStateScript = _state()
	var find: Dictionary = (_layout(_today())["finds"] as Array)[0]
	_below(gs, find)
	gs.rover_depth = 0
	var up: String = gs.take_find(find["id"], _today(), HOST)
	var nothing: bool = gs.finds_taken.is_empty() and gs.crystal_ore == 0 and gs.credits == 0
	gs.free()
	if up == "":
		return "A find was taken with the rover in the hub."
	return "" if nothing else "A refused take still changed the farm."


func test_a_beacon_needs_the_rover_in_the_hub() -> String:
	var gs: GameStateScript = _state()
	gs.player_places[HOST] = [ZoneDepth.ZONE, 0]
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, LavaHub.spot_position("spot_west"))
	var refused: String = gs.place_beacon("spot_west", HOST)
	gs.free()
	return "" if refused != "" else "A beacon was set down while the rover was below."


func test_yesterdays_layout_never_takes_a_different_find_today() -> String:
	var gs: GameStateScript = _state()
	var today: int = _today()
	var finds: Array = _layout(today)["finds"]
	_below(gs, finds[0])
	# A screen that drew yesterday's floor says d1_f0 of yesterday.
	var stale: String = gs.take_find("d1_f0", today - 1, HOST)
	var nothing: bool = gs.finds_taken.is_empty() and gs.crystal_ore == 0 and gs.credits == 0
	var fresh: String = gs.take_find("d1_f0", today, HOST)
	gs.free()
	# The case is real: some days d1_f0 is another kind of find than the day after.
	var differs: bool = false
	for day: int in range(0, 60):
		var a: Array = _layout(day)["finds"]
		var b: Array = _layout(day + 1)["finds"]
		if str(a[0]["kind"]) != str(b[0]["kind"]):
			differs = true
	if stale == "":
		return "A pickup from yesterday's layout was accepted."
	if not nothing:
		return "A stale pickup still changed the farm."
	if fresh != "":
		return "Today's d1_f0 was refused: " + fresh
	return "" if differs else "The generator never changes d1_f0 from one day to the next."


func test_only_today_is_kept_and_a_future_day_is_dropped() -> String:
	var day: int = _today()
	var future: Dictionary = { "lava_tubes": { "day": day + 1, "ids": ["d1_f0"] } }
	var kept: Dictionary = ZoneDepth.prune(future, day)
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	data["finds_taken"] = future
	var back: GameStateScript = _state()
	var loaded: String = back.farm_from_dict(data)
	var after: Dictionary = back.finds_taken.duplicate()
	gs.free()
	back.free()
	if not kept.is_empty():
		return "A future day was kept by prune: %s" % [kept]
	if loaded != "":
		return "A save with a future record was refused: " + loaded
	return "" if after.is_empty() else "A future record was loaded: %s" % [after]


func test_a_save_names_only_real_zones_and_real_find_ids() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var refused: Array[String] = []
	var bad_records: Array = [
		{ "not_a_zone": { "day": 1, "ids": [] } },
		{ "lava_tubes": { "day": 1, "ids": ["d1_f99"] } },
		{ "lava_tubes": { "day": 1, "ids": ["d2_f0"] } },
		{ "lava_tubes": { "day": 1, "ids": ["d1_f+1"] } },
		{ "lava_tubes": { "day": 1, "ids": ["d1_f-0"] } },
	]
	for bad: Variant in bad_records:
		data["finds_taken"] = bad
		refused.append(gs.farm_dict_problem(data))
	data["finds_taken"] = { "lava_tubes": { "day": 1, "ids": ["d1_f0", "d1_f%d" % (ZoneDepth.find_count(1) - 1)] } }
	var good: String = gs.farm_dict_problem(data)
	gs.free()
	for i: int in refused.size():
		if refused[i] == "":
			return "Bad record number %d was accepted." % i
	return good


func test_a_rover_below_that_is_not_on_floor_starts_again() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	var far: Vector3 = Vector3(-500.0, 0.0, -500.0)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, far)
	var epoch: int = gs.rover_epoch
	var moved: bool = gs.settle_rover_depth()
	var at: Vector3 = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin
	var bumped: bool = gs.rover_epoch == epoch + 1
	var again: bool = gs.settle_rover_depth()
	gs.rover_depth = 0
	var hub: bool = gs.settle_rover_depth()
	gs.free()
	if not moved or at.distance_to(ZoneDepth.start_transform().origin) > 0.01:
		return "A rover off the floor was not put back at the start."
	if not bumped:
		return "A re-park did not start a new epoch."
	if again:
		return "A rover on the floor was moved."
	return "" if not hub else "The hub was settled as if it were below."


func test_the_morning_leaves_a_rover_on_floor_and_judges_its_whole_body() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	var grid: PackedStringArray = ZoneDepth.grid_for(1, SEED, _today())
	# A rover standing on a floor cell, a long way from the start.
	var spot := Vector3.ZERO
	var edge := Vector3.ZERO
	var have_spot: bool = false
	var have_edge: bool = false
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, grid[y].length() - 1):
			if grid[y][x] != ".":
				continue
			var here: Vector3 = TunnelRock.at_in(grid, Vector2i(x, y))
			if not have_spot and here.distance_to(ZoneDepth.start_transform().origin) > 6.0 and grid[y][x + 1] == "." and grid[y][x - 1] == "." and grid[y + 1][x] == "." and grid[y - 1][x] == ".":
				spot = here
				have_spot = true
			# A floor cell with rock to its right: the middle stays on floor 1.4 m out
			# but a corner of the body is in the rock.
			if not have_edge and grid[y][x + 1] != "." and grid[y][x + 1] != "A" and grid[y][x + 1] != "B":
				edge = here + Vector3(1.4, 0.0, 0.0)
				have_edge = true
	if not have_spot or not have_edge:
		gs.free()
		return "Today's layout has no open cell or no wall (the test needs both)."
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot)
	var epoch: int = gs.rover_epoch
	var left: bool = not gs.settle_rover_depth()
	var same: bool = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin.is_equal_approx(spot) and gs.rover_epoch == epoch
	var middle_on_floor: bool = TunnelRock.holds_in(grid, edge)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, edge)
	var moved: bool = gs.settle_rover_depth()
	gs.free()
	if not left or not same:
		return "The morning moved a rover that was on floor."
	if not middle_on_floor:
		return "The test spot is not on floor in the middle."
	return "" if moved else "A rover with a corner in the rock was left there."


func test_a_rover_someone_drives_is_not_re_parked_until_they_stop() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(-500.0, 0.0, -500.0))
	CoopRovers._drivers[gs.TUNNEL_ROVER] = [GUEST, Time.get_ticks_msec() + 60000]
	var held: bool = not gs.settle_rover_depth()
	var due: bool = gs.settle_due
	var kept: bool = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin.x < -400.0
	CoopRovers._drivers.erase(gs.TUNNEL_ROVER)
	var later: bool = gs.settle_rover_depth()
	var cleared: bool = not gs.settle_due
	gs.free()
	if not held or not due or not kept:
		return "A rover that is driven was re-parked (or the check was not kept)."
	return "" if later and cleared else "The check was not made once the driver stopped."



func test_the_hub_never_takes_a_pose_from_below_or_the_reverse() -> String:
	var depth_one: PackedStringArray = ZoneDepth.grid_for(1, SEED, _today())
	var hub: PackedStringArray = ZoneDepth.grid_for(0, SEED, _today())
	if hub != TunnelRock.MAP:
		return "Depth 0 is not the hub map."
	if depth_one != (_layout(_today())["grid"] as PackedStringArray):
		return "Depth 1 is not today's layout."
	if ZoneDepth.pose_for_depth(1).origin == ZoneDepth.pose_for_depth(0).origin:
		return "The same arrival pose for both depths."
	return ""


# --- Round two of the review ----------------------------------------------------

func test_every_move_of_the_rover_is_a_new_epoch_that_guests_are_sent() -> String:
	var shown: Array = FarmSync.SHOWN_BY.get(&"rover_place_changed", [])
	if not "rover_epoch" in shown:
		return "rover_epoch is not sent with rover_depth: %s" % [shown]
	var gs: GameStateScript = _state()
	_hub_rover(gs, ZoneDepth.descent_position())
	var start: int = gs.rover_epoch
	gs.change_depth(1, "")
	var down: int = gs.rover_epoch
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	gs.change_depth(0, "")
	var up: int = gs.rover_epoch
	gs.change_depth(0, "")  # refused: nothing moves, no new epoch
	var refused: int = gs.rover_epoch
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var problem: String = gs.farm_dict_problem(data)
	data["rover_epoch"] = -1
	var bad: String = gs.farm_dict_problem(data)
	gs.free()
	var back: GameStateScript = _state()
	back.farm_from_dict(bytes_to_var(var_to_bytes(_state_dict(up))))
	var loaded: int = back.rover_epoch
	back.free()
	if down != start + 1 or up != start + 2 or refused != up:
		return "Epochs %d, %d, %d, %d." % [start, down, up, refused]
	if problem != "" or bad == "":
		return "The epoch check is wrong: '%s' / '%s'" % [problem, bad]
	return "" if loaded == up else "A saved epoch loaded as %d." % loaded


func _state_dict(epoch: int) -> Dictionary:
	var gs: GameStateScript = _state()
	gs.rover_epoch = epoch
	var data: Dictionary = gs.farm_to_dict()
	gs.free()
	return data


func test_a_pose_wire_may_carry_an_epoch_and_only_an_integer() -> String:
	var plain: Array = [1.0, 0.0, 2.0, 0.0, 0.0, true]
	if not CoopRovers.is_shape(plain) or not CoopRovers.is_shape(plain + [3]):
		return "A pose with or without an epoch was refused."
	if CoopRovers.is_shape(plain + ["3"]) or CoopRovers.is_shape(plain + [3, 4]) or CoopRovers.is_shape(plain + [3.0]):
		return "A pose with a bad epoch was accepted."
	return ""


func test_a_rebuild_is_due_whenever_the_scene_is_at_another_depth_or_day() -> String:
	var day: int = _today()
	if ZoneDepth.needs_rebuild(0, day, 0, day) or ZoneDepth.needs_rebuild(1, day, 1, day):
		return "A scene that matches was rebuilt."
	if not ZoneDepth.needs_rebuild(0, day, 1, day) or not ZoneDepth.needs_rebuild(1, day, 0, day):
		return "A scene at another depth was kept (a missed signal would stay missed)."
	if not ZoneDepth.needs_rebuild(1, day - 1, 1, day):
		return "A scene below drawn for yesterday was kept."
	return "" if not ZoneDepth.needs_rebuild(0, day - 1, 0, day) else "The hub was rebuilt for a new day."


func test_a_player_with_the_rover_may_use_the_pad_after_the_lease_ends() -> String:
	var gs: GameStateScript = _state()
	_hub_rover(gs, ZoneDepth.descent_position())
	# Nobody drives. The guest is in the tunnels at the rover's depth.
	gs.player_places[GUEST] = [ZoneDepth.ZONE, 0]
	var near: String = gs.change_depth(1, GUEST)
	# Below, still at the hub depth in presence, so no.
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	var stale: String = gs.change_depth(0, GUEST)
	var depth: int = gs.rover_depth
	# A guest in the dome, or on the farm, is not.
	gs.player_places[GUEST] = ["farm", 0]
	var farm: String = gs.change_depth(0, GUEST)
	# In the tunnels, at the rover's depth, but too far from the pad: the reach still holds.
	gs.player_places[GUEST] = [ZoneDepth.ZONE, 1]
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.start_transform().origin)
	var far: String = gs.change_depth(0, GUEST)
	gs.free()
	if near != "":
		return "A guest with the rover was refused: " + near
	if depth != 1 or stale == "":
		return "A guest at another depth than the rover was let through (depth %d)." % depth
	if farm == "":
		return "A guest on the farm took the rover up."
	return "" if far != "" or ZoneDepth.near_ascent(ZoneDepth.start_transform().origin) else "The reach check was skipped."


func test_continuing_a_save_keeps_the_depth_and_only_leaving_the_tubes_resets_it() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	gs.rover_zone = ZoneDepth.ZONE
	var same_zone: int = gs.rover_depth
	gs.rover_zone = ""
	gs.rover_zone = ""
	var left: int = gs.rover_depth
	var data: Dictionary = bytes_to_var(var_to_bytes(_below_dict()))
	gs.free()
	# A farm already running (the rover on the farm) loads a save made below.
	var running: GameStateScript = _state()
	running.rover_zone = ""
	var problem: String = running.farm_from_dict(data)
	var loaded_zone: String = running.rover_zone
	var loaded_depth: int = running.rover_depth
	# And one that is in the tubes at depth 1 already loads it again.
	var again: String = running.farm_from_dict(data)
	var again_depth: int = running.rover_depth
	running.free()
	if same_zone != 1:
		return "Setting the same zone reset the depth."
	if left != 0:
		return "Leaving the tubes kept depth %d." % left
	if problem != "" or again != "":
		return "A save made below was refused: %s %s" % [problem, again]
	return "" if loaded_zone == ZoneDepth.ZONE and loaded_depth == 1 and again_depth == 1 else "Loaded %s at depth %d (then %d)." % [loaded_zone, loaded_depth, again_depth]


func _below_dict() -> Dictionary:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = ZoneDepth.start_transform()
	var data: Dictionary = gs.farm_to_dict()
	gs.free()
	return data


func test_only_the_canonical_find_ids_pass_a_save() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var refused: Array[String] = []
	for alias: String in ["d01_f00", "d1_f00", "d01_f0", "d1_f01", "D1_f0", "d1_F0", "d1_f 0", " d1_f0", "d1_f0 ", "d1_f1.0", "d1_f1e0", "d0001_f2"]:
		data["finds_taken"] = { "lava_tubes": { "day": 1, "ids": [alias] } }
		refused.append(gs.farm_dict_problem(data))
	var allowed: Array[String] = []
	for index: int in ZoneDepth.find_count(1):
		data["finds_taken"] = { "lava_tubes": { "day": 1, "ids": [ZoneDepth.find_id(index)] } }
		allowed.append(gs.farm_dict_problem(data))
	gs.free()
	for i: int in refused.size():
		if refused[i] == "":
			return "Alias number %d was accepted." % i
	for i: int in allowed.size():
		if allowed[i] != "":
			return "Find %d was refused: %s" % [i, allowed[i]]
	return ""


# --- Round three of the review ----------------------------------------------------

func test_the_footprint_check_sees_rock_between_its_corners() -> String:
	# GPT's case: seed 424242, the rover at (-11.4, 0.05, -2.4) turned 45 degrees, with
	# its middle and four corners on floor but rock under its side on some day's layout.
	# Over many days and turns: wherever a dense sweep of the body finds rock the check
	# must say so, and there must be cases where the five old points all miss it.
	var half: Vector2 = TunnelRock.ROVER_HALF_M
	var corners: Array[Vector2] = [Vector2.ZERO, half, -half, Vector2(half.x, -half.y), Vector2(-half.x, half.y)]
	var gaps: int = 0
	var missed: int = 0
	for day: int in range(1, 61):
		var grid: PackedStringArray = ZoneDepth.grid_for(1, SEED, day)
		for degrees: int in [0, 15, 30, 45, 60, 75, 90]:
			var at := Transform3D(Basis(Vector3.UP, deg_to_rad(float(degrees))), Vector3(-11.4, 0.05, -2.4))
			var five: bool = true
			for corner: Vector2 in corners:
				five = five and TunnelRock.holds_in(grid, at.origin + at.basis * Vector3(corner.x, 0.0, corner.y))
			var dense: bool = true
			for i: int in range(-9, 10):
				for j: int in range(-15, 16):
					var local := Vector3(i * 0.1, 0.0, j * 0.1)
					dense = dense and TunnelRock.holds_in(grid, at.origin + at.basis * local)
			var held: bool = TunnelRock.holds_body_in(grid, at)
			if five and not dense:
				gaps += 1
			if held and not dense:
				missed += 1
			if dense and not held and not five:
				return "Day %d, %d degrees: the check saw rock the sweep did not." % [day, degrees]
	# GPT's exact case: seed 424242, day 9.
	var day9: PackedStringArray = ZoneDepth.grid_for(1, SEED, 9)
	var turned := Transform3D(Basis(Vector3.UP, deg_to_rad(45.0)), Vector3(-11.4, 0.05, -2.4))
	if TunnelRock.holds_body_in(day9, turned):
		return "Day 9: the rover with rock under its side was called on floor."
	if gaps == 0:
		return "No day and turn shows the gap between the five old points (the test needs one)."
	return "" if missed == 0 else "%d rovers with rock under them were called on floor." % missed


func test_a_save_made_below_keeps_the_depth_through_continue() -> String:
	var held: Dictionary = SaveGame.snapshot()
	var held_open: bool = SaveGame.farm_open
	var path: String = "user://test_zone_depth_continue.save"
	GameState.rover_zone = ZoneDepth.ZONE
	GameState.rover_depth = 1
	GameState.rover_transforms[GameState.TUNNEL_ROVER] = ZoneDepth.start_transform()
	var problem: String = ""
	# The player is in the tunnels, on the farm, or in the dome when it is saved.
	for scene: String in [SceneSwitcher.TUNNELS_SCENE, SceneSwitcher.FARM_SCENE, SceneSwitcher.DOME_SCENE]:
		GameState.rover_zone = ZoneDepth.ZONE
		GameState.rover_depth = 1
		var data: Dictionary = SaveGame.snapshot()
		data["scene"] = scene
		SaveGame._write_data(data, path)
		GameState.rover_zone = ""  # a farm already running somewhere else
		if SaveGame.continue_farm(path) != "":
			problem = "%s: the save was refused" % scene
		elif GameState.rover_depth != 1 or GameState.rover_zone != ZoneDepth.ZONE:
			problem = "%s: Continue left the rover at %s depth %d" % [scene, GameState.rover_zone, GameState.rover_depth]
	DirAccess.remove_absolute(path)
	SaveGame.restore(held)
	SaveGame.farm_open = held_open
	return problem


# --- Round four of the review -----------------------------------------------------

func test_a_pose_off_the_map_is_not_on_floor() -> String:
	var grid: PackedStringArray = ZoneDepth.grid_for(1, SEED, _today())
	for x: float in [1e10, -1e10, 9.0e18, INF, -INF, NAN]:
		for z: float in [22.5, 1e10, NAN]:
			if TunnelRock.holds_body_in(grid, Transform3D(Basis.IDENTITY, Vector3(x, 0.05, z))):
				return "A pose at (%s, %s) was called on floor." % [x, z]
	return "" if TunnelRock.holds_body_in(grid, ZoneDepth.start_transform()) else "The start is no longer on floor."


func test_the_sentinel_is_not_watched_from_below() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.sentinel_out = true
	gs.rover_lights = false
	gs.rover_depth = 1
	gs.watch_sentinel(gs.TUNNEL_ROVER, gs.SENTINEL_AT + Vector3(gs.SENTINEL_SEES_M * 0.95, 0.0, 0.0), 0.0)
	var below: bool = gs.sentinel_sighted
	gs.rover_depth = 0
	gs.watch_sentinel(gs.TUNNEL_ROVER, gs.SENTINEL_AT + Vector3(gs.SENTINEL_SEES_M * 0.95, 0.0, 0.0), 0.0)
	var hub: bool = gs.sentinel_sighted
	gs.free()
	if below:
		return "The Sentinel saw a rover at depth 1 by hub coordinates."
	return "" if hub else "The Sentinel is no longer watched in the hub."


func test_the_farms_ground_does_not_lift_the_tunnel_rover() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZoneDepth.ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, -50.0, 0.0))
	gs._lift_to_ground()
	var y: float = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin.y
	gs.free()
	return "" if is_equal_approx(y, -50.0) else "The farm's ground lifted the tunnel rover to %f." % y
