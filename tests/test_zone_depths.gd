extends RefCounted
## Depths 2 and 3 of the Lava Tubes, the lift and the deepest depth reached
## (docs/design/zones.md section 13, build step 9). Every number is a [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
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


## The farm's rover in the tunnels at `depth`, at `at`, and the host with it.
func _rover_at(gs: GameStateScript, depth: int, at: Vector3) -> void:
	gs.rover_zone = gs.TUNNELS_ZONE
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[HOST] = [gs.TUNNELS_ZONE, depth]


func _rich(gs: GameStateScript) -> void:
	gs.credits = 500
	gs.crystal_ore = 10


# --- Depth 1 is as it was ---------------------------------------------------------

## What depth 1 made before depths 2 and 3 were added, captured from that code: the
## grid's hash and the finds, for a few days of one seed.
const PINNED: Dictionary = {
	0: [1406084613, "d1_f0@7,12:ore,d1_f1@7,8:sample,d1_f2@18,12:mineral,d1_f3@17,12:ore,d1_f4@11,1:mineral,d1_f5@8,3:ore,d1_f6@13,15:mineral"],
	1: [2166700707, "d1_f0@3,11:mineral,d1_f1@4,8:ore,d1_f2@18,12:mineral,d1_f3@19,8:ore,d1_f4@11,5:ore,d1_f5@11,4:mineral,d1_f6@14,17:ore"],
	7: [3188188186, "d1_f0@3,8:mineral,d1_f1@6,12:ore,d1_f2@15,8:ore,d1_f3@17,11:mineral,d1_f4@13,2:ore,d1_f5@12,4:ore,d1_f6@11,17:ore"],
	100: [2216597026, "d1_f0@7,9:ore,d1_f1@8,10:ore,d1_f2@18,8:sample,d1_f3@16,8:sample,d1_f4@13,1:ore,d1_f5@8,2:ore,d1_f6@8,17:ore"],
	365: [2674936356, "d1_f0@8,10:mineral,d1_f1@7,11:mineral,d1_f2@16,8:ore,d1_f3@19,10:mineral,d1_f4@12,1:sample,d1_f5@10,3:mineral,d1_f6@13,15:mineral"],
}


func test_depth_one_makes_exactly_what_it_made_before() -> String:
	for day: int in PINNED:
		var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 1, day)
		var finds: Array[String] = []
		for find: Dictionary in data["finds"]:
			finds.append("%s@%d,%d:%s" % [find["id"], find["cell"].x, find["cell"].y, find["kind"]])
		var want: Array = PINNED[day]
		if "|".join(data["grid"]).hash() != want[0]:
			return "Day %d: depth 1's grid changed." % day
		if ",".join(finds) != want[1]:
			return "Day %d: depth 1's finds changed: %s" % [day, ",".join(finds)]
	return ""


# --- Depths 2 and 3 ---------------------------------------------------------------

func test_the_depths_are_the_same_all_day_and_not_each_other() -> String:
	for day: int in [0, 1, 2, 9, 100, 365]:
		var seen: Dictionary = {}
		for depth: int in range(1, ZoneDepth.MAX_DEPTH + 1):
			var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)
			if data.is_empty() or data["depth"] != depth:
				return "Depth %d made no layout." % depth
			if data != ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day):
				return "Depth %d day %d changed between two calls." % [depth, day]
			seen["|".join(data["grid"])] = true
		if seen.size() != ZoneDepth.MAX_DEPTH:
			return "Day %d: two depths had the same floor." % day
	for depth: int in [2, 3]:
		if ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, 5) == ZoneDepth.layout(SEED + 1, ZoneDepth.ZONE, depth, 5):
			return "Another farm gave depth %d the same day." % depth
		var grids: Dictionary = {}
		for day: int in range(0, 12):
			grids["|".join(ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)["grid"])] = true
		if grids.size() < 10:
			return "Twelve days gave depth %d only %d floors." % [depth, grids.size()]
	return ""


func test_every_depth_is_joined_up_with_reachable_finds_off_the_start() -> String:
	for depth: int in range(1, ZoneDepth.MAX_DEPTH + 1):
		for day: int in range(0, 365):
			var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)
			var grid: PackedStringArray = data["grid"]
			var reach: Array[Vector2i] = ZoneDepth.reachable(grid, ZoneDepth.START_CELL)
			var floor_count: int = 0
			for row: String in grid:
				floor_count += row.count(".")
			if reach.size() != floor_count:
				return "Depth %d day %d: %d floor cells, %d reached." % [depth, day, floor_count, reach.size()]
			var cells: Array[Vector2i] = []
			var ids: Array[String] = []
			for find: Dictionary in data["finds"]:
				var cell: Vector2i = find["cell"]
				if not cell in reach or cell == ZoneDepth.START_CELL or cell in cells or str(find["id"]) in ids:
					return "Depth %d day %d: %s is unreachable, on the start or doubled." % [depth, day, find["id"]]
				if str(find["id"]) != ZoneDepth.find_id(ids.size(), depth):
					return "Depth %d day %d: %s is not that depth's id." % [depth, day, find["id"]]
				if ZoneDepth.has_way_down(depth) and cell in [ZoneDepth.HATCH_CELL, ZoneDepth.HATCH_CELL + Vector2i(0, 1)]:
					return "Depth %d day %d: a find sits under the hatch." % [depth, day]
				if ZoneDepth.is_lift_depth(depth) and cell in [ZoneDepth.LIFT_CELL, ZoneDepth.LIFT_CELL + Vector2i(0, 1)]:
					return "Depth %d day %d: a find sits under the lift." % [depth, day]
				cells.append(cell)
				ids.append(str(find["id"]))
			if ids.size() != ZoneDepth.find_count(depth):
				return "Depth %d day %d has %d finds." % [depth, day, ids.size()]
			if ZoneDepth.has_way_down(depth) and not ZoneDepth.hatch_cell(depth) in reach:
				return "Depth %d day %d: the way down is not reachable." % [depth, day]
			if ZoneDepth.is_lift_depth(depth) and not ZoneDepth.LIFT_CELL in reach:
				return "Depth %d day %d: the lift is not reachable." % [depth, day]
			if not ZoneDepth.UP_CELL in reach:
				return "Depth %d day %d: the way up is not reachable." % [depth, day]
	return ""


func test_the_finds_are_taken_depth_by_depth() -> String:
	var gs: GameStateScript = _state()
	_rich(gs)
	var problems: Array[String] = []
	var day: int = _today()
	for depth: int in [2, 3]:
		var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)
		var find: Dictionary = data["finds"][0]
		_rover_at(gs, depth, TunnelRock.at_in(data["grid"], find["cell"]))
		var first: String = gs.take_find(find["id"], day, HOST)
		if first != "":
			problems.append("Depth %d: the find was refused: %s" % [depth, first])
		if gs.take_find(find["id"], day, HOST) == "":
			problems.append("Depth %d: the same find was taken twice." % depth)
	var ids: Array = (gs.finds_taken["lava_tubes"] as Dictionary)["ids"]
	if not "d2_f0" in ids or not "d3_f0" in ids or ids.size() != 2:
		problems.append("The two depths' first finds are %s." % [ids])
	# Depth 2's find is not depth 3's, and the other depth's find cannot be taken from here.
	var data3: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 3, day)
	if gs.take_find("d2_f1", day, HOST) == "":
		problems.append("A find of depth 2 was taken from depth 3.")
	if data3["finds"][1]["id"] != "d3_f1":
		problems.append("Depth 3's second find has the wrong id.")
	gs.free()
	return "\n".join(problems)


# --- Moving between the depths ----------------------------------------------------

func test_change_depth_goes_one_step_at_a_time_by_the_hatch_and_the_way_up() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	_rover_at(gs, 0, ZoneDepth.descent_position(0))
	if gs.change_depth(2) == "" or gs.change_depth(3) == "":
		problems.append("The hub's hatch skipped a depth.")
	if gs.change_depth(1) != "" or gs.rover_depth != 1:
		problems.append("The hub's hatch did not go to depth 1.")
	# Depth 1 arrival is at the start: too far from the hatch.
	if gs.change_depth(2) == "":
		problems.append("A hatch was used from the start, far from it.")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(1))
	if gs.change_depth(2) != "" or gs.rover_depth != 2:
		problems.append("Depth 1's hatch did not go to depth 2.")
	if gs.change_depth(2) == "" or gs.change_depth(1) == "":
		problems.append("The way up was used from the start, far from it.")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	if gs.change_depth(3) == "":
		problems.append("Depth 3 was entered by the way up pad.")
	if gs.change_depth(1) != "" or gs.rover_depth != 1:
		problems.append("Depth 2's way up did not go to depth 1.")
	# Up again lands beside the hatch it came down by.
	var beside: Vector3 = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin
	if beside.distance_to(ZoneDepth.descent_position(1)) > 6.0:
		problems.append("Coming up from depth 2 did not land by depth 1's hatch.")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(1))
	gs.change_depth(2)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(2))
	if gs.change_depth(3) != "" or gs.rover_depth != 3:
		problems.append("Depth 2's hatch did not go to depth 3.")
	if ZoneDepth.has_way_down(3) or gs.change_depth(4) == "":
		problems.append("Depth 3 has a way down.")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	if gs.change_depth(2) != "" or gs.rover_depth != 2:
		problems.append("Depth 3's way up did not go to depth 2.")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	gs.change_depth(1)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	if gs.change_depth(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 1's way up did not go to the hub.")
	gs.free()
	return "\n".join(problems)


func test_a_move_between_depths_takes_the_rover_and_counts_a_new_epoch() -> String:
	var gs: GameStateScript = _state()
	_rover_at(gs, 2, ZoneDepth.descent_position(2))
	var epoch: int = gs.rover_epoch
	if gs.change_depth(3) != "":
		return "The hatch was refused."
	var at: Vector3 = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin
	var problems: Array[String] = []
	if at.distance_to(ZoneDepth.start_transform().origin) > 0.01:
		problems.append("The rover did not arrive at depth 3's entrance.")
	if gs.rover_epoch != epoch + 1:
		problems.append("The move was not a new epoch.")
	# A guest who is not at the rover's depth may not take it down.
	_rover_at(gs, 1, ZoneDepth.descent_position(1))
	gs.player_places[GUEST] = [gs.TUNNELS_ZONE, 2]
	if gs.change_depth(2, GUEST) == "":
		problems.append("A guest at another depth took the rover down.")
	gs.free()
	return "\n".join(problems)


# --- The lift ---------------------------------------------------------------------

func test_the_repair_refuses_where_and_when_it_must() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	_rich(gs)
	var lift: Vector3 = ZoneDepth.lift_position(3)
	for depth: int in [0, 1, 2]:
		_rover_at(gs, depth, lift)
		if gs.repair_lift() == "":
			problems.append("The lift was repaired at depth %d." % depth)
	_rover_at(gs, 3, ZoneDepth.start_transform().origin + Vector3(0.0, 0.0, 40.0))
	if gs.repair_lift() == "":
		problems.append("The lift was repaired from far away.")
	_rover_at(gs, 3, lift)
	gs.player_places[GUEST] = [ZonePresence.DOME, 0]
	if gs.repair_lift(GUEST) == "":
		problems.append("A player not in the tunnels repaired it.")
	gs.credits = ZoneDepth.LIFT_COST_CREDITS - 1
	if gs.repair_lift() == "" or gs.is_lift_repaired("lava_tubes", 3):
		problems.append("Too little credit repaired it.")
	gs.credits = 500
	gs.crystal_ore = ZoneDepth.LIFT_COST_ORE - 1
	if gs.repair_lift() == "" or gs.is_lift_repaired("lava_tubes", 3):
		problems.append("Too little ore repaired it.")
	if gs.credits != 500 or gs.crystal_ore != ZoneDepth.LIFT_COST_ORE - 1:
		problems.append("A refusal took something.")
	gs.free()
	return "\n".join(problems)


func test_the_repair_takes_its_cost_once_and_is_for_good() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	_rich(gs)
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	var told: Array[int] = [0]
	gs.lifts_changed.connect(func() -> void: told[0] += 1)
	var done: String = gs.repair_lift()
	if done != "":
		return "The repair was refused: %s" % done
	if gs.credits != 500 - ZoneDepth.LIFT_COST_CREDITS or gs.crystal_ore != 10 - ZoneDepth.LIFT_COST_ORE:
		problems.append("The cost was wrong: %d CR, %d ore." % [gs.credits, gs.crystal_ore])
	if not gs.is_lift_repaired("lava_tubes", 3) or gs.repaired_lift_depth("lava_tubes") != 3 or told[0] < 1:
		problems.append("The lift is not repaired, or nobody was told.")
	if gs.repair_lift() == "":
		problems.append("A repaired lift was repaired again.")
	if gs.credits != 500 - ZoneDepth.LIFT_COST_CREDITS or gs.crystal_ore != 10 - ZoneDepth.LIFT_COST_ORE:
		problems.append("The cost was taken twice.")
	gs.free()
	return "\n".join(problems)


## The host's rover goes down the three hatches (depth 3 is the deepest) and, after
## the lift is mended, comes up to the hub in it: `deepest_depth` is 3 with the rover
## at depth 0, so a save has to keep it as a field of its own.
func _been_to_three(gs: GameStateScript) -> void:
	_rich(gs)
	gs.local_player_id = HOST
	_rover_at(gs, 0, ZoneDepth.descent_position(0))
	for depth: int in range(0, 3):
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(depth))
		gs.change_depth(depth + 1)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.lift_position(3))
	gs.repair_lift()
	gs.use_lift(0)


func test_a_repaired_lift_and_the_deepest_depth_are_saved_and_checked() -> String:
	var gs: GameStateScript = _state()
	_been_to_three(gs)
	var problems: Array[String] = []
	if gs.rover_depth != 0 or gs.deepest_depth.get("lava_tubes", 0) != 3 or not gs.is_lift_repaired("lava_tubes", 3):
		problems.append("The setup did not leave the rover at the hub with 3 reached and the lift mended.")
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if data.get("deepest_depth", {}) != { "lava_tubes": 3 } or data.get("rover_depth", -1) != 0:
		problems.append("The save did not hold the deepest depth: %s." % [data.get("deepest_depth")])
	var back: GameStateScript = _state()
	var heard: Array[int] = [0]
	back.lifts_changed.connect(func() -> void: heard[0] += 1)
	var loaded: String = back.farm_from_dict(data)
	if loaded != "":
		problems.append("The save was refused: %s" % loaded)
	if not back.is_lift_repaired("lava_tubes", 3) or back.deepest_depth.get("lava_tubes", 0) != 3:
		problems.append("The repair or the deepest depth was lost in the save.")
	if heard[0] != 1:
		problems.append("A load told the lifts %d times, not once at the end." % heard[0])
	# Old saves have neither: the deepest is where the rover was (the hub: none), quietly.
	data.erase("lifts_repaired")
	data.erase("deepest_depth")
	var old: GameStateScript = _state()
	if old.farm_from_dict(data) != "" or old.is_lift_repaired("lava_tubes", 3):
		problems.append("An old save was refused or came with a lift.")
	if not old.deepest_depth.is_empty():
		problems.append("An old save from the hub came with a deepest depth: %s." % [old.deepest_depth])
	data["rover_depth"] = 2
	data["rover_zone"] = "lava_tubes"
	var below: GameStateScript = _state()
	var once: Array[int] = [0]
	below.lifts_changed.connect(func() -> void: once[0] += 1)
	if below.farm_from_dict(data) != "" or below.deepest_depth.get("lava_tubes", 0) != 2:
		problems.append("An old save with the rover at depth 2 did not count depth 2: %s." % [below.deepest_depth])
	if once[0] != 1:
		problems.append("An old save told the lifts %d times, not once at the end." % once[0])
	for bad: Variant in [{ "lava_tubes": [9] }, { "nowhere": [3] }, { "lava_tubes": ["3"] }, [3], { "lava_tubes": [3, 3] }]:
		var junk: Dictionary = gs.farm_to_dict()
		junk["lifts_repaired"] = bad
		if gs.farm_dict_problem(junk) == "":
			problems.append("A bad lifts_repaired was accepted: %s" % [bad])
	for bad: Variant in [{ "lava_tubes": 9 }, { "lava_tubes": -1 }, { "nowhere": 1 }, { "lava_tubes": "2" }, 3]:
		var junk: Dictionary = gs.farm_to_dict()
		junk["deepest_depth"] = bad
		if gs.farm_dict_problem(junk) == "":
			problems.append("A bad deepest_depth was accepted: %s" % [bad])
	if CoopSession.PROTOCOL != 24:
		problems.append("The protocol is %d, not 24." % CoopSession.PROTOCOL)
	gs.free()
	back.free()
	old.free()
	below.free()
	return "\n".join(problems)


func test_a_guest_is_told_the_lifts_and_the_deepest_depth() -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var host: GameStateScript = _state()
	var guest: GameStateScript = _state()
	var problems: Array[String] = []
	host.local_player_id = HOST
	_rich(host)
	_rover_at(host, 0, ZoneDepth.descent_position(0))
	for depth: int in range(0, 3):
		host.rover_transforms[host.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(depth))
		host.change_depth(depth + 1)
	FarmCommands.guest = true
	guest.local_player_id = GUEST
	var joined: String = FarmSync.join(FarmSync.capture(host), guest)
	if joined != "":
		problems.append("The join was refused: %s" % joined)
	if guest.deepest_depth.get("lava_tubes", 0) != 3 or guest.is_lift_repaired("lava_tubes", 3):
		problems.append("A joining guest did not get the deepest depth (3) with the lift still broken.")
	host.rover_transforms[host.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.lift_position(3))
	if host.repair_lift() != "":
		problems.append("The host could not repair the lift.")
	var heard: Array[int] = [0]
	guest.lifts_changed.connect(func() -> void: heard[0] += 1)
	var updated: String = FarmSync.update(FarmSync.capture(host), guest)
	if updated != "":
		problems.append("The update was refused: %s" % updated)
	if not guest.is_lift_repaired("lava_tubes", 3) or guest.repaired_lift_depth("lava_tubes") != 3:
		problems.append("The guest was not told the lift is repaired.")
	if heard[0] < 1:
		problems.append("The guest's screens were not told (lifts_changed).")
	if host.use_lift(0) != "":
		problems.append("The host could not ride up.")
	FarmSync.update(FarmSync.capture(host), guest)
	if guest.deepest_depth.get("lava_tubes", 0) != 3 or guest.rover_depth != 0:
		problems.append("The guest lost the deepest depth when the rover went up.")
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	host.free()
	guest.free()
	return "\n".join(problems)


func _commands_for(gs: GameStateScript) -> Node:
	var commands: Node = preload("res://scripts/autoload/FarmCommands.gd").new()
	commands.state = gs
	return commands


func test_the_lift_commands_run_for_the_host_and_for_a_guest() -> String:
	var gs: GameStateScript = _state()
	gs.local_player_id = HOST
	_rich(gs)
	var commands: Node = _commands_for(gs)
	var problems: Array[String] = []
	# The host repairs it, as the host.
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	if commands.execute(HOST, &"repair_lift", []) != "" or not gs.is_lift_repaired("lava_tubes", 3):
		problems.append("The host could not repair the lift through the commands.")
	if commands.execute(HOST, &"use_lift", [0]) != "" or gs.rover_depth != 0:
		problems.append("The host could not ride up through the commands.")
	# A fresh farm: a guest at a depth with no lift is refused; at the lift's depth, not.
	var fresh: GameStateScript = _state()
	fresh.local_player_id = HOST
	_rich(fresh)
	var theirs: Node = _commands_for(fresh)
	_rover_at(fresh, 3, ZoneDepth.lift_position(3))
	fresh.player_places[GUEST] = [fresh.TUNNELS_ZONE, 1]
	if theirs.execute(GUEST, &"repair_lift", []) == "" or fresh.is_lift_repaired("lava_tubes", 3):
		problems.append("A guest at depth 1 repaired the lift at depth 3.")
	fresh.player_places[GUEST] = ["farm", 0]
	if theirs.execute(GUEST, &"repair_lift", []) == "" or fresh.is_lift_repaired("lava_tubes", 3):
		problems.append("A guest on the farm repaired the lift.")
	fresh.player_places[GUEST] = [fresh.TUNNELS_ZONE, 3]
	if theirs.execute(GUEST, &"repair_lift", []) != "" or not fresh.is_lift_repaired("lava_tubes", 3):
		problems.append("A guest at depth 3 could not repair the lift.")
	if fresh.credits != 500 - ZoneDepth.LIFT_COST_CREDITS:
		problems.append("The guest's repair was not paid from the farm's wallet.")
	# A guest at another depth cannot ride it; one at the lift's depth can.
	fresh.player_places[GUEST] = [fresh.TUNNELS_ZONE, 1]
	if theirs.execute(GUEST, &"use_lift", [0]) == "" or fresh.rover_depth != 3:
		problems.append("A guest at depth 1 rode the lift at depth 3.")
	fresh.player_places[GUEST] = [fresh.TUNNELS_ZONE, 3]
	if theirs.execute(GUEST, &"use_lift", [0]) != "" or fresh.rover_depth != 0:
		problems.append("A guest at depth 3 could not ride up.")
	# A stale request: the rover is at the hub now, so a screen that still means
	# "up to the hub" (0) is refused, not bounced back down; "down to 3" goes.
	fresh.player_places[GUEST] = [fresh.TUNNELS_ZONE, 0]
	if theirs.execute(GUEST, &"use_lift", [0]) == "" or fresh.rover_depth != 0:
		problems.append("A raced request bounced the rover back down.")
	if theirs.execute(GUEST, &"use_lift", [3]) != "" or fresh.rover_depth != 3:
		problems.append("The right request (down to 3) was refused.")
	# And the other way: the rover is at depth 3, so a stale "down to 3" is refused.
	if theirs.execute(HOST, &"use_lift", [3]) == "" or fresh.rover_depth != 3:
		problems.append("A stale request to go down bounced the rover back up.")
	commands.free()
	theirs.free()
	gs.free()
	fresh.free()
	return "\n".join(problems)


func test_a_guest_arrives_where_the_host_parked_the_rover() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	# By the lift up at the hub, and by a hatch up at depth 1 or 2: the host's own
	# parked pose is inside the rock, so a guest (with no told pose) takes it.
	for case: Array in [[0, ZoneDepth.lift_exit_transform(0)], [1, ZoneDepth.hatch_exit_transform(1)], [2, ZoneDepth.hatch_exit_transform(2)]]:
		var depth: int = case[0]
		var parked: Transform3D = case[1]
		var got: Transform3D = ZoneDepth.rebuild_pose(parked, depth, SEED, day)
		if got.origin.distance_to(parked.origin) > 0.01:
			problems.append("Depth %d: the parked pose was not used." % depth)
		if got.origin.distance_to(ZoneDepth.rebuild_pose(null, depth, SEED, day).origin) < 0.5:
			problems.append("Depth %d: the parked pose is no different from the start." % depth)
	return "\n".join(problems)


func test_the_lift_is_broken_until_repaired_then_goes_both_ways_free() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	_rich(gs)
	# Before: the hub's lift will not move, nor will depth 3's.
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(3) == "" or gs.rover_depth != 0:
		problems.append("The broken hub lift moved the rover.")
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	if gs.use_lift(0) == "" or gs.rover_depth != 3:
		problems.append("The broken lift at depth 3 moved the rover.")
	_rover_at(gs, 2, ZoneDepth.lift_position(3))
	if gs.use_lift(0) == "":
		problems.append("A lift was used at depth 2.")
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	gs.repair_lift()
	var money: int = gs.credits
	var ore: int = gs.crystal_ore
	# Up to the hub, beside the hub's lift.
	if gs.use_lift(0) != "" or gs.rover_depth != 0:
		problems.append("The repaired lift did not go up to the hub.")
	if gs.parked_rover_transform(gs.TUNNEL_ROVER).origin.distance_to(ZoneDepth.lift_exit_transform(0).origin) > 0.01:
		problems.append("The rover did not come out by the hub's lift.")
	# Far from the hub's lift it will not ride.
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.lift_position(0) + Vector3(0.0, 0.0, 60.0))
	if gs.use_lift(3) == "" or gs.rover_depth != 0:
		problems.append("The hub's lift was used from far away.")
	# And down: straight to depth 3's entrance, the rover with the player.
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.lift_position(0))
	if gs.use_lift(3) != "" or gs.rover_depth != 3:
		problems.append("The hub's lift did not go down to depth 3.")
	if gs.parked_rover_transform(gs.TUNNEL_ROVER).origin.distance_to(ZoneDepth.start_transform().origin) > 0.01:
		problems.append("The rover did not come out at depth 3's entrance.")
	if gs.credits != money or gs.crystal_ore != ore:
		problems.append("A ride cost something.")
	if gs.deepest_depth.get("lava_tubes", 0) != 3:
		problems.append("The deepest depth was not 3.")
	gs.free()
	return "\n".join(problems)


func test_the_lift_ride_checks_the_driver_like_a_hatch() -> String:
	var gs: GameStateScript = _state()
	_rich(gs)
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	gs.repair_lift()
	gs.player_places[GUEST] = [gs.TUNNELS_ZONE, 1]
	var refused: String = gs.use_lift(0, GUEST)
	var stays: bool = gs.rover_depth == 3
	gs.free()
	return "" if refused != "" and stays else "A guest at another depth rode the lift."


# --- The deepest depth, the morning, the rescue -----------------------------------

func test_the_deepest_depth_only_grows() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	if ZoneDepth.deepest_text(gs.deepest_depth, "lava_tubes") != "":
		problems.append("A phone line before any depth.")
	_rover_at(gs, 0, ZoneDepth.descent_position(0))
	gs.change_depth(1)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(1))
	gs.change_depth(2)
	if gs.deepest_depth.get("lava_tubes", 0) != 2 or ZoneDepth.deepest_text(gs.deepest_depth, "lava_tubes") != "Deepest: Lava Tubes, depth 2":
		problems.append("Deepest is %s." % [gs.deepest_depth])
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
	gs.change_depth(1)
	if gs.deepest_depth.get("lava_tubes", 0) != 2:
		problems.append("Coming up lowered the deepest depth.")
	if not "Deepest" in gs.contract_phone_text():
		problems.append("The phone's line is missing.")
	gs.free()
	return "\n".join(problems)


func test_at_six_a_rover_below_in_depth_three_is_rebuilt_on_the_new_floor() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var day: int = _today()
	if not ZoneDepth.needs_rebuild(3, day - 1, 3, day) or ZoneDepth.needs_rebuild(3, day, 3, day) or not ZoneDepth.needs_rebuild(2, day, 3, day):
		problems.append("The rebuild rule is wrong for depth 3.")
	_rover_at(gs, 3, Vector3(900.0, 0.0, 900.0))  # in the rock of today's floor
	var epoch: int = gs.rover_epoch
	if not gs.settle_rover_depth(false) or gs.rover_epoch != epoch + 1:
		problems.append("A rover in the rock at depth 3 was not re-parked.")
	if gs.parked_rover_transform(gs.TUNNEL_ROVER).origin.distance_to(ZoneDepth.start_transform().origin) > 0.01:
		problems.append("It was not put at the start.")
	if gs.settle_rover_depth(false):
		problems.append("A rover on floor was moved.")
	if ZoneDepth.grid_for(3, SEED, day) != ZoneDepth.layout(SEED, ZoneDepth.ZONE, 3, day)["grid"]:
		problems.append("The grid the morning checks is not depth 3's.")
	gs.free()
	return "\n".join(problems)


func test_the_two_a_m_rescue_works_from_depth_three() -> String:
	var gs: GameStateScript = _state()
	_rich(gs)
	_rover_at(gs, 3, ZoneDepth.start_transform().origin)
	gs.rover_in_tunnels = true
	var bill: Dictionary = gs.rescue_from_tunnels(HOST)
	var problems: Array[String] = []
	if bill.is_empty():
		problems.append("No bill.")
	if gs.rover_zone != "" or gs.rover_depth != 0 or gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("The rover was left in the tunnels: %s depth %d." % [gs.rover_zone, gs.rover_depth])
	if gs.place_of(HOST) == gs.TUNNELS_ZONE:
		problems.append("The rescued player is still in the tunnels.")
	gs.free()
	return "\n".join(problems)


func test_vents_stay_on_depth_one() -> String:
	for depth: int in [2, 3]:
		if not ZoneHazards.vents_for(SEED, ZoneDepth.ZONE, depth, 3).is_empty():
			return "Depth %d has vents." % depth
	return ""
