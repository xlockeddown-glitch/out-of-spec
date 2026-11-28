extends RefCounted
## The deep Lava Tubes, depths 4 to 6 (docs/design/zones.md section 7.2, slice 11): the
## floors, the lab gate, the lift at depth 6, the better finds and the rockfall.
## Every number is a [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST := "player_1"
const SEED := 424242
const DEEP: Array[int] = [4, 5, 6]


## Stands in for CoopBeds where a test only needs to know who was put to bed.
class _NoBeds:
	extends RefCounted
	var put_to_bed: Array[String] = []

	func recall_to_bed(player_id: String) -> void:
		put_to_bed.append(player_id)


func _state(level: int = 10, lift3: bool = true) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	gs.lab_xp = gs.xp_for_level(level)
	gs.credits = 1000
	gs.crystal_ore = 20
	if lift3:
		_rover_at(gs, 3, ZoneDepth.lift_position(3))
		gs.repair_lift()
		gs.credits = 1000
		gs.crystal_ore = 20
	return gs


func _rover_at(gs: GameStateScript, depth: int, at: Vector3) -> void:
	gs.rover_zone = gs.TUNNELS_ZONE
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[HOST] = [gs.TUNNELS_ZONE, depth]


func _floor_count(grid: PackedStringArray) -> int:
	var count: int = 0
	for row: String in grid:
		count += row.count(".")
	return count


# --- Depths 1 to 3 are as they were ----------------------------------------------

## Captured from the code before depths 4 to 6 were added: the grid's hash and the finds.
## (Depth 1 is pinned in test_zone_depths.)
const PINNED: Dictionary = {
	2: {
		0: [44295613, "d2_f0@2,15:mineral,d2_f1@3,16:ore,d2_f2@18,15:ore,d2_f3@22,15:ore,d2_f4@20,6:ore,d2_f5@16,4:ore,d2_f6@13,16:ore"],
		1: [954644405, "d2_f0@2,12:ore,d2_f1@1,14:ore,d2_f2@19,13:ore,d2_f3@17,13:ore,d2_f4@14,5:mineral,d2_f5@15,3:ore,d2_f6@8,17:ore"],
		7: [1357086570, "d2_f0@7,13:ore,d2_f1@2,15:mineral,d2_f2@21,15:ore,d2_f3@20,15:ore,d2_f4@16,2:ore,d2_f5@18,4:sample,d2_f6@12,18:sample"],
		100: [2779748417, "d2_f0@2,12:sample,d2_f1@2,15:ore,d2_f2@21,13:ore,d2_f3@21,17:ore,d2_f4@18,2:mineral,d2_f5@14,2:mineral,d2_f6@10,17:ore"],
		365: [2642215553, "d2_f0@1,14:ore,d2_f1@1,16:mineral,d2_f2@17,17:sample,d2_f3@21,16:sample,d2_f4@14,3:ore,d2_f5@18,5:ore,d2_f6@12,17:ore"],
	},
	3: {
		0: [1523055626, "d3_f0@1,7:ore,d3_f1@5,5:mineral,d3_f2@20,7:mineral,d3_f3@18,5:ore,d3_f4@21,15:sample,d3_f5@18,18:ore,d3_f6@12,18:ore"],
		1: [35559265, "d3_f0@3,8:mineral,d3_f1@6,6:ore,d3_f2@18,7:mineral,d3_f3@17,9:ore,d3_f4@17,18:ore,d3_f5@22,16:ore,d3_f6@14,15:mineral"],
		7: [3477168845, "d3_f0@1,6:ore,d3_f1@2,5:ore,d3_f2@18,9:ore,d3_f3@19,8:mineral,d3_f4@20,15:ore,d3_f5@22,17:ore,d3_f6@12,18:mineral"],
		100: [3278136703, "d3_f0@6,8:ore,d3_f1@3,6:mineral,d3_f2@20,5:ore,d3_f3@18,6:mineral,d3_f4@18,16:mineral,d3_f5@19,14:ore,d3_f6@8,17:sample"],
		365: [1708117879, "d3_f0@4,5:ore,d3_f1@7,6:sample,d3_f2@20,5:ore,d3_f3@19,9:ore,d3_f4@22,15:mineral,d3_f5@19,16:mineral,d3_f6@14,17:ore"],
	},
}


func test_depths_two_and_three_make_exactly_what_they_made_before() -> String:
	for depth: int in PINNED:
		for day: int in PINNED[depth]:
			var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)
			var finds: Array[String] = []
			for find: Dictionary in data["finds"]:
				finds.append("%s@%d,%d:%s" % [find["id"], find["cell"].x, find["cell"].y, find["kind"]])
			var want: Array = PINNED[depth][day]
			if "|".join(data["grid"]).hash() != want[0]:
				return "Depth %d day %d: the grid changed." % [depth, day]
			if ",".join(finds) != want[1]:
				return "Depth %d day %d: the finds changed: %s" % [depth, day, ",".join(finds)]
	return ""


func test_depths_one_to_three_have_no_rockfall() -> String:
	for depth: int in [1, 2, 3]:
		for day: int in range(0, 20):
			if not (ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day).get("fall", {}) as Dictionary).is_empty():
				return "Depth %d has a rockfall." % depth
	return ""


func test_depth_three_has_a_hatch_now_and_six_is_the_last() -> String:
	var problems: Array[String] = []
	if ZoneDepth.MAX_DEPTH != 6 or ZonePresence.MAX_DEPTH != 6:
		problems.append("The deepest is not 6.")
	if not ZoneDepth.has_way_down(3) or ZoneDepth.has_way_down(6) or not ZoneDepth.is_lift_depth(6):
		problems.append("The hatches or the lift are on the wrong depths.")
	if ZonePresence.place_problem("ice_caves", 4) == "":
		problems.append("Another zone got deeper.")
	return "\n".join(problems)


# --- Depths 4 to 6 ----------------------------------------------------------------

func test_the_deep_floors_differ_by_depth_and_by_day_and_are_all_reachable() -> String:
	for day: int in range(0, 60):
		var seen: Dictionary = {}
		for depth: int in DEEP:
			var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)
			if data.is_empty() or data["depth"] != depth or data != ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day):
				return "Depth %d day %d: no layout or not the same twice." % [depth, day]
			seen["|".join(data["grid"])] = true
			var grid: PackedStringArray = data["grid"]
			var reach: Array[Vector2i] = ZoneDepth.reachable(grid, ZoneDepth.START_CELL)
			if reach.size() != _floor_count(grid):
				return "Depth %d day %d: %d floor cells, %d reached." % [depth, day, _floor_count(grid), reach.size()]
			if not ZoneDepth.UP_CELL in reach or (ZoneDepth.has_way_down(depth) and not ZoneDepth.hatch_cell(depth) in reach):
				return "Depth %d day %d: the way up or down is cut off." % [depth, day]
			if ZoneDepth.is_lift_depth(depth) and not ZoneDepth.LIFT_CELL in reach:
				return "Depth %d day %d: the lift is cut off." % [depth, day]
			var cells: Array[Vector2i] = []
			for find: Dictionary in data["finds"]:
				var cell: Vector2i = find["cell"]
				if not cell in reach or cell == ZoneDepth.START_CELL or cell in cells:
					return "Depth %d day %d: %s is off the floor, on the start or doubled." % [depth, day, find["id"]]
				if cell == ZoneDepth.UP_CELL or (ZoneDepth.has_way_down(depth) and cell in [ZoneDepth.HATCH_CELL, ZoneDepth.HATCH_CELL + Vector2i(0, 1)]) or (ZoneDepth.is_lift_depth(depth) and cell == ZoneDepth.LIFT_CELL):
					return "Depth %d day %d: %s is on a pad." % [depth, day, find["id"]]
				cells.append(cell)
			if data["finds"].size() != ZoneDepth.find_count(depth):
				return "Depth %d day %d: %d finds." % [depth, day, data["finds"].size()]
		if seen.size() != 3:
			return "Day %d: two deep depths had the same floor." % day
	for depth: int in DEEP:
		var days: Dictionary = {}
		for day: int in range(0, 20):
			days["|".join(ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)["grid"])] = true
		if days.size() < 10:
			return "Depth %d changes too little from day to day." % depth
		if ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, 5)["grid"] == ZoneDepth.layout(SEED + 1, ZoneDepth.ZONE, depth, 5)["grid"]:
			return "Another farm got depth %d's day." % depth
	return ""


func test_the_rockfall_never_cuts_off_the_way_up_the_hatch_or_a_find() -> String:
	var nofall: int = 0
	for seed_value: int in range(1, 41):
		for day: int in range(0, 30):
			for depth: int in DEEP:
				var data: Dictionary = ZoneDepth.layout(seed_value * 7919, ZoneDepth.ZONE, depth, day)
				var fall: Dictionary = data["fall"]
				if fall.is_empty():
					nofall += 1
					continue
				var grid: PackedStringArray = data["grid"]
				var cells: Array = fall["cells"]
				if cells.is_empty() or fall["beside"] is not Vector2i:
					return "Depth %d: the rockfall has no cells or no side." % depth
				for cell: Vector2i in cells:
					if grid[cell.y][cell.x] != "#":
						return "Depth %d day %d: a rockfall cell is floor." % [depth, day]
					if cell in [ZoneDepth.START_CELL, ZoneDepth.UP_CELL, ZoneDepth.HATCH_CELL, ZoneDepth.LIFT_CELL]:
						return "Depth %d day %d: the rockfall is on a pad." % [depth, day]
				var reach: Array[Vector2i] = ZoneDepth.reachable(grid, ZoneDepth.START_CELL)
				if reach.size() != _floor_count(grid):
					return "Depth %d day %d seed %d: the rockfall cut floor off." % [depth, day, seed_value]
				if not ZoneDepth.UP_CELL in reach:
					return "Depth %d: the way up is cut off." % depth
				if ZoneDepth.has_way_down(depth) and not ZoneDepth.hatch_cell(depth) in reach:
					return "Depth %d: the hatch is cut off." % depth
				for find: Dictionary in data["finds"]:
					if not find["cell"] in reach:
						return "Depth %d day %d seed %d: a find is cut off." % [depth, day, seed_value]
	if nofall > 0:
		return "%d floors had no rockfall." % nofall
	return ""


# --- The gate ---------------------------------------------------------------------

func test_the_gate_refuses_below_level_ten_and_with_the_lift_broken() -> String:
	var problems: Array[String] = []
	# Level 9, lift mended: refused, says the lab level, nothing moves.
	var gs: GameStateScript = _state(9, true)
	_rover_at(gs, 3, ZoneDepth.descent_position(3))
	var epoch: int = gs.rover_epoch
	var why: String = gs.change_depth(4)
	if why == "" or gs.rover_depth != 3 or gs.rover_epoch != epoch or not "lab level" in why:
		problems.append("Level 9 went down or the refusal was unclear: %s" % why)
	if "lift" in why:
		problems.append("The lift is mended but the refusal blames it: %s" % why)
	gs.free()
	# Level 10, lift broken.
	gs = _state(10, false)
	_rover_at(gs, 3, ZoneDepth.descent_position(3))
	epoch = gs.rover_epoch
	why = gs.change_depth(4)
	if why == "" or gs.rover_depth != 3 or gs.rover_epoch != epoch or not "lift at depth 3" in why:
		problems.append("A broken depth 3 lift let the rover down: %s" % why)
	if "lab level" in why:
		problems.append("Level 10 is enough but the refusal blames the lab: %s" % why)
	gs.free()
	# Neither.
	gs = _state(1, false)
	_rover_at(gs, 3, ZoneDepth.descent_position(3))
	why = gs.change_depth(4)
	if not "lab level" in why or not "lift" in why or gs.rover_depth != 3:
		problems.append("Missing both did not say both: %s" % why)
	gs.free()
	# Both.
	gs = _state(10, true)
	_rover_at(gs, 3, ZoneDepth.descent_position(3))
	why = gs.change_depth(4)
	if why != "" or gs.rover_depth != 4 or gs.deepest_depth.get("lava_tubes", 0) != 4:
		problems.append("Level 10 with the lift did not go down: %s" % why)
	gs.free()
	return "\n".join(problems)


func test_the_lift_obeys_the_gate_and_depths_one_to_three_never_ask() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.repair_lift()
	gs.lab_xp = gs.xp_for_level(9)
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	var why: String = gs.use_lift(6)
	if why == "" or gs.rover_depth != 0 or not "lab level" in why:
		problems.append("The hub's lift went to 6 below level 10: %s" % why)
	gs.lab_xp = gs.xp_for_level(10)
	if gs.use_lift(6) != "" or gs.rover_depth != 6:
		problems.append("The hub's lift did not go to 6 at level 10.")
	gs.free()
	gs = _state(1, false)
	_rover_at(gs, 2, ZoneDepth.descent_position(2))
	if gs.change_depth(3) != "" or gs.rover_depth != 3:
		problems.append("Depth 3 asked for the gate.")
	gs.free()
	return "\n".join(problems)


# --- The lift at depth 6 ----------------------------------------------------------

func test_the_lift_at_six_is_broken_until_repaired_and_costs_once() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	if gs.use_lift(0) == "" or gs.rover_depth != 6:
		problems.append("A broken lift at depth 6 moved the rover.")
	var cost: Vector2i = ZoneDepth.lift_cost(6)
	if cost != Vector2i(200, 4) or ZoneDepth.lift_cost(3) != Vector2i(ZoneDepth.LIFT_COST_CREDITS, ZoneDepth.LIFT_COST_ORE):
		problems.append("The costs are %s and %s." % [cost, ZoneDepth.lift_cost(3)])
	gs.credits = cost.x - 1
	if gs.repair_lift() == "" or gs.is_lift_repaired("lava_tubes", 6) or gs.credits != cost.x - 1:
		problems.append("Too little credit repaired it, or a refusal took something.")
	gs.credits = 1000
	var ore: int = gs.crystal_ore
	if gs.repair_lift() != "":
		return "The repair was refused."
	if gs.credits != 1000 - cost.x or gs.crystal_ore != ore - cost.y or not gs.is_lift_repaired("lava_tubes", 6):
		problems.append("Wrong charge: %d CR, %d ore." % [gs.credits, gs.crystal_ore])
	if gs.repair_lift() == "" or gs.credits != 1000 - cost.x:
		problems.append("The repair charged twice.")
	if gs.use_lift(0) != "" or gs.rover_depth != 0:
		problems.append("The lift did not go up to the hub.")
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(6) != "" or gs.rover_depth != 6 or gs.deepest_depth.get("lava_tubes", 0) != 6:
		problems.append("The hub's lift did not go down to 6.")
	if gs.credits != 1000 - cost.x:
		problems.append("A ride cost something.")
	gs.free()
	return "\n".join(problems)


# --- The finds --------------------------------------------------------------------

func test_deep_finds_pay_more_and_more_the_deeper() -> String:
	var problems: Array[String] = []
	for kind: String in ["ore", "mineral", "sample"]:
		var last_ore: int = int(ZoneDepth.reward(kind, 3).get("crystal_ore", 0))
		var last_cr: int = int(ZoneDepth.reward(kind, 3).get("credits", 0))
		if ZoneDepth.reward(kind, 3) != ZoneDepth.reward(kind):
			problems.append("Depth 3 pays differently.")
		for depth: int in DEEP:
			var pay: Dictionary = ZoneDepth.reward(kind, depth)
			var ore: int = int(pay.get("crystal_ore", 0))
			var cr: int = int(pay.get("credits", 0))
			if ore < last_ore or cr < last_cr or (ore == last_ore and cr == last_cr):
				problems.append("%s at depth %d does not pay more than the depth above." % [kind, depth])
			last_ore = ore
			last_cr = cr
	if ZoneDepth.reward("sample", 4).get("crystal_ore", 0) != 2 or ZoneDepth.reward("sample", 6).get("crystal_ore", 0) != 3:
		problems.append("The sample's ore is %s and %s." % [ZoneDepth.reward("sample", 4), ZoneDepth.reward("sample", 6)])
	var gs: GameStateScript = _state(10, true)
	var day: int = GameClock.get_day_index()
	var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 5, day)
	var find: Dictionary = data["finds"][0]
	_rover_at(gs, 5, TunnelRock.at_in(data["grid"], find["cell"]))
	var before_cr: int = gs.credits
	var before_ore: int = gs.crystal_ore
	var done: String = gs.take_find(find["id"], day, HOST)
	var pay5: Dictionary = ZoneDepth.reward(str(find["kind"]), 5)
	if done != "" or gs.credits - before_cr != int(pay5.get("credits", 0)) or gs.crystal_ore - before_ore != int(pay5.get("crystal_ore", 0)):
		problems.append("take_find paid wrong at depth 5: %s" % done)
	gs.free()
	return "\n".join(problems)


# --- The recall and the save ------------------------------------------------------

func test_the_two_a_m_recall_from_depth_five_brings_the_player_home() -> String:
	var gs: GameStateScript = _state(10, true)
	_rover_at(gs, 5, ZoneDepth.start_transform().origin)
	gs.credits = 200
	gs.crystal_ore = 9
	gs.rover_in_tunnels = true
	gs._ore_at_entry = 3
	gs.recall_in_tunnels = func() -> bool: return true
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	gs._tick_recall()
	GameClock.elapsed_days = held
	var problems: Array[String] = []
	if gs.credits != 150 or gs.crystal_ore != 7:
		problems.append("The bill was %d CR, %d ore: not as from depth 1." % [gs.credits, gs.crystal_ore])
	if gs.rover_in_tunnels or gs.rover_zone != "" or gs.rover_depth != 0 or beds.put_to_bed != [HOST]:
		problems.append("The rover or the player was not brought home.")
	gs.free()
	return "\n".join(problems)


func test_a_deep_save_round_trips_and_an_old_save_loads() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.repair_lift()
	gs.deepest_depth["lava_tubes"] = 6
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var back: GameStateScript = _state(1, false)
	if back.farm_from_dict(data) != "" or not back.is_lift_repaired("lava_tubes", 6) or back.deepest_depth.get("lava_tubes", 0) != 6:
		problems.append("A save at depth 6 did not come back.")
	data.erase("lifts_repaired")
	data.erase("deepest_depth")
	data["rover_depth"] = 0
	data["rover_zone"] = ""
	var old: GameStateScript = _state(1, false)
	if old.farm_from_dict(data) != "" or old.is_lift_repaired("lava_tubes", 6) or old.lava_deep_problem() == "":
		problems.append("An old save was refused or let in below depth 3.")
	if CoopSession.PROTOCOL != 42:
		problems.append("The protocol is %d, not 42." % CoopSession.PROTOCOL)
	gs.free()
	back.free()
	old.free()
	return "\n".join(problems)


# --- Review fixes: the limits, the gate in every direction, the loaded rover -------

func test_each_zone_has_its_own_most_depth_and_the_moons_have_none() -> String:
	var problems: Array[String] = []
	var limits: Dictionary = {"lava_tubes": 6, "flooded_aquifer": 6, "colony_mine": 6, "ice_caves": 1, "phobos": 0, "deimos": 0}
	for zone: String in limits:
		var most: int = limits[zone]
		if ZoneDepth.max_depth_of(zone) != most:
			problems.append("%s: max_depth_of is %d, not %d." % [zone, ZoneDepth.max_depth_of(zone), most])
		if ZonePresence.place_problem(zone, most) != "" or ZonePresence.place_problem(zone, most + 1) == "":
			problems.append("%s: the place rule is wrong at %d and %d." % [zone, most, most + 1])
		if most >= 1 and ZoneDepth.deepest_problem({zone: most}) != "":
			problems.append("%s: its own deepest is refused." % zone)
		if ZoneDepth.deepest_problem({zone: most + 1}) == "":
			problems.append("%s: a deepest past its most was let in." % zone)
	# Finds: depth 4's and 6's ids belong to the Lava Tubes alone.
	if ZoneDepth.taken_problem({"lava_tubes": {"day": 1, "ids": ["d6_f0"]}}) != "":
		problems.append("The Lava Tubes' depth 6 find was refused.")
	if ZoneDepth.taken_problem({"flooded_aquifer": {"day": 1, "ids": ["d6_f0"]}}) != "":
		problems.append("The Aquifer's depth 6 find was refused.")
	if ZoneDepth.taken_problem({"flooded_aquifer": {"day": 1, "ids": ["d7_f0"]}}) == "":
		problems.append("The Aquifer took a find id from depth 7.")
	for zone: String in ["ice_caves"]:
		if ZoneDepth.taken_problem({zone: {"day": 1, "ids": ["d4_f0"]}}) == "":
			problems.append("%s took a find id from depth 4." % zone)
	# Lifts: 6 needs 3, in either order; no lift is deeper than the zone.
	if ZoneDepth.lifts_problem({"lava_tubes": [6]}) == "":
		problems.append("A lift at 6 with no lift at 3 was let in.")
	if ZoneDepth.lifts_problem({"lava_tubes": [3, 6]}) != "" or ZoneDepth.lifts_problem({"lava_tubes": [6, 3]}) != "":
		problems.append("Lifts 3 and 6 were refused.")
	if ZoneDepth.lifts_problem({"flooded_aquifer": [6]}) == "" or ZoneDepth.lifts_problem({"phobos": [3]}) == "":
		problems.append("A lift past a zone's depths was let in.")
	return "\n".join(problems)


func test_the_gate_holds_in_every_direction_among_the_deep_depths() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	_rover_at(gs, 5, ZoneDepth.descent_position(5))
	gs.lab_xp = gs.xp_for_level(9)
	for target: int in [4, 6]:
		var epoch: int = gs.rover_epoch
		var why: String = gs.change_depth(target)
		if why == "" or gs.rover_depth != 5 or gs.rover_epoch != epoch:
			problems.append("Depth 5 to %d went with the gate shut: %s" % [target, why])
	# Going up out of depth 4 to 3 stays open: the way home is never shut.
	_rover_at(gs, 4, ZoneDepth.ascent_position())
	var up: String = gs.change_depth(3)
	if up != "" or gs.rover_depth != 3:
		problems.append("The rover could not leave the deep with the gate shut: %s" % up)
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	var credits: int = gs.credits
	var why_lift: String = gs.repair_lift()
	if why_lift == "" or not "lab level" in why_lift or gs.is_lift_repaired("lava_tubes", 6) or gs.credits != credits:
		problems.append("The depth 6 lift was repaired with the gate shut: %s" % why_lift)
	# Finds below 3 do not pay with the gate shut.
	var day: int = GameClock.get_day_index()
	var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 4, day)
	var find: Dictionary = data["finds"][0]
	_rover_at(gs, 4, TunnelRock.at_in(data["grid"], find["cell"]))
	credits = gs.credits
	var ore: int = gs.crystal_ore
	if gs.take_find(find["id"], day, HOST) == "" or gs.credits != credits or gs.crystal_ore != ore:
		problems.append("A deep find paid with the gate shut.")
	gs.lab_xp = gs.xp_for_level(10)
	if gs.take_find(find["id"], day, HOST) != "":
		problems.append("The find was refused with the gate open.")
	gs.free()
	return "\n".join(problems)


func test_the_lift_at_six_has_its_reach_its_ore_and_its_order() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	var cost: Vector2i = ZoneDepth.lift_cost(6)
	# Away from depth 6: refused. Away from the lift: refused, nothing taken.
	_rover_at(gs, 5, ZoneDepth.lift_position(6))
	if gs.repair_lift() == "" and gs.is_lift_repaired("lava_tubes", 6):
		problems.append("Depth 5 repaired depth 6's lift.")
	_rover_at(gs, 6, ZoneDepth.start_transform().origin)
	var credits: int = gs.credits
	if gs.repair_lift() == "" or gs.is_lift_repaired("lava_tubes", 6) or gs.credits != credits:
		problems.append("The lift was repaired from the start, away from it.")
	# Ore: one short is refused and takes nothing.
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.crystal_ore = cost.y - 1
	if gs.repair_lift() == "" or gs.crystal_ore != cost.y - 1 or gs.credits != credits or gs.is_lift_repaired("lava_tubes", 6):
		problems.append("One ore short repaired it or took something.")
	gs.crystal_ore = cost.y
	if gs.repair_lift() != "" or gs.crystal_ore != 0 or gs.credits != credits - cost.x:
		problems.append("The exact ore did not repair it, or the charge is wrong.")
	# The ride to 6 is refused while 3's lift is broken.
	gs.lifts_repaired = {"lava_tubes": [6]}
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(6) == "" or gs.rover_depth != 0:
		problems.append("The lift went to 6 with depth 3's lift broken.")
	# From 6 up to the hub works once both are repaired; the layout keeps the lift reachable.
	gs.lifts_repaired = {"lava_tubes": [3, 6]}
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	if gs.use_lift(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 6 to the hub failed with both lifts repaired.")
	for day: int in range(0, 40):
		var grid: PackedStringArray = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 6, day)["grid"]
		if not ZoneDepth.LIFT_CELL in ZoneDepth.reachable(grid, ZoneDepth.START_CELL):
			problems.append("Day %d: the lift at 6 is cut off." % day)
			break
	gs.free()
	return "\n".join(problems)


func test_the_rockfall_pile_is_on_the_start_side_and_the_finds_keep_off_it() -> String:
	var seen: int = 0
	for seed_value: int in range(1, 31):
		for day: int in range(0, 25):
			for depth: int in DEEP:
				var data: Dictionary = ZoneDepth.layout(seed_value * 104729, ZoneDepth.ZONE, depth, day)
				var fall: Dictionary = data["fall"]
				if fall.is_empty():
					continue
				seen += 1
				var beside: Vector2i = fall["beside"]
				var grid: PackedStringArray = data["grid"]
				if grid[beside.y][beside.x] != ".":
					return "Depth %d day %d: the pile's side is not floor." % [depth, day]
				if not beside in ZoneDepth.reachable(grid, ZoneDepth.START_CELL):
					return "Depth %d day %d: the pile's side is not reached from the start." % [depth, day]
				for find: Dictionary in data["finds"]:
					if find["cell"] == beside:
						return "Depth %d day %d: a find sits on the pile's side." % [depth, day]
	if seen == 0:
		return "No rockfall was drawn at all."
	return ""


func test_a_deep_rover_loaded_with_the_gate_shut_is_put_back_at_depth_three() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.deepest_depth["lava_tubes"] = 6
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if data.get("rover_depth", 0) != 6 or data.get("rover_zone", "") != "lava_tubes":
		problems.append("The save did not hold the rover at depth 6.")
	# The same farm, loaded where the lab level is not enough.
	var low_data: Dictionary = data.duplicate(true)
	low_data["lab_xp"] = 0
	var low: GameStateScript = _state(1, false)
	if low.farm_from_dict(low_data) != "":
		problems.append("The low-level deep save was refused.")
	if low.rover_depth != 3 or low.rover_zone != "lava_tubes":
		problems.append("The rover was left at depth %d (%s)." % [low.rover_depth, low.rover_zone])
	if low.lava_deep_problem() == "":
		problems.append("The gate opened by loading.")
	# With the gate open the rover stays where the save had it.
	var kept: GameStateScript = _state(10, true)
	if kept.farm_from_dict(data) != "" or kept.rover_depth != 6:
		problems.append("The rover was moved though the gate is open (depth %d)." % kept.rover_depth)
	gs.free()
	low.free()
	kept.free()
	return "\n".join(problems)


func test_deep_finds_pay_once_at_depths_four_and_six() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(10, true)
	var day: int = GameClock.get_day_index()
	for depth: int in [4, 6]:
		var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, depth, day)
		var find: Dictionary = data["finds"][1]
		_rover_at(gs, depth, TunnelRock.at_in(data["grid"], find["cell"]))
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		var pay: Dictionary = ZoneDepth.reward(str(find["kind"]), depth)
		if gs.take_find(find["id"], day, HOST) != "" or gs.credits - credits != int(pay.get("credits", 0)) or gs.crystal_ore - ore != int(pay.get("crystal_ore", 0)):
			problems.append("Depth %d paid wrong." % depth)
		credits = gs.credits
		if gs.take_find(find["id"], day, HOST) == "" or gs.credits != credits:
			problems.append("Depth %d paid twice." % depth)
	gs.free()
	return "\n".join(problems)


func test_depth_five_always_has_a_rockfall_and_never_cuts_off_the_floor() -> String:
	for seed_value: int in range(1, 201):
		for day: int in range(0, 12):
			var data: Dictionary = ZoneDepth.layout(seed_value * 7919 + 13, ZoneDepth.ZONE, 5, day)
			var fall: Dictionary = data["fall"]
			if fall.is_empty() or (fall["cells"] as Array).is_empty():
				return "Depth 5 seed %d day %d: no rockfall." % [seed_value, day]
			var grid: PackedStringArray = data["grid"]
			var reach: Array[Vector2i] = ZoneDepth.reachable(grid, ZoneDepth.START_CELL)
			if not ZoneDepth.UP_CELL in reach or not ZoneDepth.hatch_cell(5) in reach:
				return "Depth 5 seed %d day %d: the way up or down is cut off." % [seed_value, day]
			for find: Dictionary in data["finds"]:
				if not find["cell"] in reach:
					return "Depth 5 seed %d day %d: a find is cut off." % [seed_value, day]
	return ""
