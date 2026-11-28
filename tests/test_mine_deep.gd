extends RefCounted
## The Colony Mine's depths 2 to 6 (docs/design/zones.md, slice 13): depths 2 and 3 open,
## depths 4 to 6 behind the `mine_deep` gate (lab level 24 and the lift at depth 3), the lifts
## at 3 and 6, the rockfalls and the colonist's case kept by depth, and the better finds.
## Every number is a [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST := "player_1"
const SEED := 424242
const ZONE: String = "colony_mine"
const DEEP: Array[int] = [4, 5, 6]
const GATE_LEVEL: int = 24
const ALL_FALLS: Array = ["r0", "r1", "r2"]


## A farm at lab level `level`, with or without depth 3's mended lift.
func _state(level: int = GATE_LEVEL, lift3: bool = true) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	gs.lab_xp = gs.xp_for_level(level)
	gs.credits = 1000
	gs.crystal_ore = 20
	if lift3:
		gs.lifts_repaired = {ZONE: [3]}
	return gs


func _rover_at(gs: GameStateScript, depth: int, at: Vector3) -> void:
	gs.rover_zone = ZONE
	gs.rover_lent = true
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[HOST] = [ZONE, depth]


func _today() -> int:
	return GameClock.get_day_index()


## Every rockfall of `depth` shored today, as the farm stores it.
func _shore_all(gs: GameStateScript, depth: int, day: int) -> void:
	for plain: String in ALL_FALLS:
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, MineDepth.storage_id(depth, plain))


## The first find of `depth` today that is not the colonist's case.
func _plain_find(depth: int, day: int) -> Dictionary:
	for find: Dictionary in MineDepth.layout(SEED, depth, day, ALL_FALLS)["finds"]:
		if str(find["kind"]) != MineDepth.CASE:
			return find
	return {}


# --- The rows and the ranges -----------------------------------------------------------

func test_the_mine_has_six_depths_and_the_gate_row_is_built_at_level_twenty_four() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false)
	if ZoneDepth.max_depth_of(ZONE) != 6 or ZoneDepth.max_depth_of("flooded_aquifer") != 6 or ZoneDepth.max_depth_of("ice_caves") != 1:
		problems.append("max_depth_of: mine %d, aquifer %d, ice %d." % [ZoneDepth.max_depth_of(ZONE), ZoneDepth.max_depth_of("flooded_aquifer"), ZoneDepth.max_depth_of("ice_caves")])
	if gs.lab_gate_level(MineDepth.DEEP_GATE) != GATE_LEVEL:
		problems.append("The gate is at lab level %d." % gs.lab_gate_level(MineDepth.DEEP_GATE))
	if ZoneData.zone(&"colony_mine").get("deep_gate", "") != MineDepth.DEEP_GATE:
		problems.append("The zone row does not name the deep gate.")
	if MineDepth.layout(SEED, 7, 1) != {} or MineDepth.layout(SEED, 0, 1) != {}:
		problems.append("A depth outside 1 to 6 has a layout.")
	for depth: int in range(1, 7):
		if MineDepth.layout(SEED, depth, 3).is_empty():
			problems.append("Depth %d has no layout." % depth)
	for depth: int in range(0, 6):
		if not ZoneDepth.has_way_down(depth):
			problems.append("Depth %d has no hatch down." % depth)
	if ZoneDepth.has_way_down(6):
		problems.append("Depth 6 has a hatch down.")
	if gs.deep_problem(ZONE) == "" or not gs.deep_problem(ZONE).contains("is shut"):
		problems.append("A new farm's deep gate is open: '%s'." % gs.deep_problem(ZONE))
	gs.free()
	return "\n".join(problems)


# --- Depths 2 and 3 are open, 4 to 6 are not --------------------------------------------

func test_depths_two_and_three_are_open_to_a_new_farm() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false)
	_rover_at(gs, 1, ZoneDepth.descent_position(1))
	if gs.change_depth(2) != "" or gs.rover_depth != 2:
		problems.append("Depth 1 to 2 was refused for a new farm.")
	_rover_at(gs, 2, ZoneDepth.descent_position(2))
	if gs.change_depth(3) != "" or gs.rover_depth != 3:
		problems.append("Depth 2 to 3 was refused for a new farm.")
	_rover_at(gs, 3, ZoneDepth.ascent_position())
	if gs.change_depth(2) != "" or gs.rover_depth != 2:
		problems.append("Depth 3 up to 2 failed.")
	gs.free()
	return "\n".join(problems)


func test_depths_four_to_six_need_the_level_and_the_lift_and_nothing_is_charged() -> String:
	var problems: Array[String] = []
	var cases: Array = [
		["lab level", "lab level 24", _state(GATE_LEVEL - 1, true)],
		["lift", "lift at depth 3", _state(GATE_LEVEL, false)],
		["both", "lab level 24", _state(1, false)],
	]
	for entry: Array in cases:
		var gs: GameStateScript = entry[2]
		_rover_at(gs, 3, ZoneDepth.descent_position(3))
		var epoch: int = gs.rover_epoch
		var why: String = gs.change_depth(4)
		if why == "" or gs.rover_depth != 3 or gs.rover_epoch != epoch:
			problems.append("Depth 4 opened without the %s: '%s'." % [entry[0], why])
		elif not why.contains("is shut") or not why.contains(str(entry[1])):
			problems.append("The refusal for the %s does not say so: '%s'." % [entry[0], why])
		if entry[0] == "both" and not why.contains("lift at depth 3"):
			problems.append("With both missing the refusal leaves out the lift: '%s'." % why)
		if gs.credits != 1000 or gs.crystal_ore != 20:
			problems.append("A refusal for the %s charged something." % entry[0])
		gs.free()
	var open: GameStateScript = _state()
	_rover_at(open, 3, ZoneDepth.descent_position(3))
	if open.mine_deep_problem() != "" or open.change_depth(4) != "" or open.rover_depth != 4:
		problems.append("Depth 4 stayed shut with everything met.")
	open.free()
	return "\n".join(problems)


func test_the_gate_holds_among_the_deep_depths_and_the_way_up_is_never_shut() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL - 1)
	# Each move is parked where its own reach check passes, so only the gate can refuse it.
	for move: Array in [[5, 6, ZoneDepth.descent_position(5)], [5, 4, ZoneDepth.ascent_position()], [4, 5, ZoneDepth.descent_position(4)], [6, 5, ZoneDepth.ascent_position()]]:
		_rover_at(gs, int(move[0]), move[2])
		var epoch: int = gs.rover_epoch
		var why: String = gs.change_depth(int(move[1]))
		if not why.contains("is shut") or gs.rover_depth != int(move[0]) or gs.rover_epoch != epoch:
			problems.append("Depth %d to %d did not stop at the gate: '%s'." % [move[0], move[1], why])
	_rover_at(gs, 4, ZoneDepth.ascent_position())
	if gs.change_depth(3) != "" or gs.rover_depth != 3:
		problems.append("The rover could not leave the deep with the gate shut.")
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL)
	_rover_at(gs, 4, ZoneDepth.descent_position(4))
	if gs.change_depth(5) != "" or gs.rover_depth != 5:
		problems.append("Depth 4 to 5 failed with the gate open.")
	_rover_at(gs, 5, ZoneDepth.descent_position(5))
	if gs.change_depth(6) != "" or gs.rover_depth != 6:
		problems.append("Depth 5 to 6 failed with the gate open.")
	_rover_at(gs, 6, ZoneDepth.ascent_position())
	if gs.change_depth(5) != "" or gs.rover_depth != 5:
		problems.append("Depth 6 up to 5 failed with the gate open.")
	_rover_at(gs, 6, ZoneDepth.descent_position(6))
	if gs.change_depth(7) == "" or gs.rover_depth != 6:
		problems.append("There is a depth 7.")
	gs.free()
	return "\n".join(problems)


func test_the_hub_hatch_and_the_way_up_to_the_hub_still_work() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false)
	_rover_at(gs, 0, MineDepth.hatch_position())
	if gs.change_depth(1) != "" or gs.rover_depth != 1:
		problems.append("The hub hatch did not go to depth 1.")
	_rover_at(gs, 1, ZoneDepth.ascent_position())
	if gs.change_depth(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 1 did not go up to the hub.")
	gs.free()
	return "\n".join(problems)


# --- The lifts at 3 and 6 --------------------------------------------------------------

func test_the_lift_at_three_has_its_reach_its_ore_and_is_paid_once() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false)
	var cost: Vector2i = ZoneDepth.lift_cost(3)
	if cost != Vector2i(100, 2):
		problems.append("The lift at 3 costs %s, not 100 CR and 2 ore." % cost)
	_rover_at(gs, 2, ZoneDepth.lift_position(3))
	if gs.repair_lift() == "" or gs.is_lift_repaired(ZONE, 3):
		problems.append("Depth 2 repaired depth 3's lift.")
	_rover_at(gs, 3, ZoneDepth.start_transform().origin)
	if gs.repair_lift() == "" or gs.credits != 1000 or gs.is_lift_repaired(ZONE, 3):
		problems.append("The lift was repaired from the start, away from it.")
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	gs.crystal_ore = cost.y - 1
	if gs.repair_lift() == "" or gs.crystal_ore != cost.y - 1 or gs.credits != 1000 or gs.is_lift_repaired(ZONE, 3):
		problems.append("One ore short repaired it or took something.")
	gs.crystal_ore = 20
	gs.credits = cost.x - 1
	if gs.repair_lift() == "" or gs.credits != cost.x - 1 or gs.crystal_ore != 20 or gs.is_lift_repaired(ZONE, 3):
		problems.append("One credit short repaired depth 3's lift or took something.")
	gs.credits = 1000
	gs.crystal_ore = cost.y
	if gs.repair_lift() != "" or gs.crystal_ore != 0 or gs.credits != 1000 - cost.x or not gs.is_lift_repaired(ZONE, 3):
		problems.append("The exact ore did not repair it, or the charge is wrong (%d CR, %d ore)." % [1000 - gs.credits, cost.y - gs.crystal_ore])
	if gs.is_lift_repaired("lava_tubes", 3) or gs.is_lift_repaired("flooded_aquifer", 3):
		problems.append("Repairing the Mine's lift mended another zone's.")
	gs.crystal_ore = 20
	var credits: int = gs.credits
	if gs.repair_lift() == "" or gs.credits != credits or gs.crystal_ore != 20:
		problems.append("The lift was repaired, or charged, twice.")
	if gs.use_lift(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 3 to the hub failed with the lift mended.")
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(3) != "" or gs.rover_depth != 3:
		problems.append("The hub's lift did not go to depth 3.")
	gs.free()
	return "\n".join(problems)


func test_a_broken_lift_carries_nobody_and_other_zones_lifts_are_not_the_mines() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false)
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	if gs.use_lift(0) == "" or gs.rover_depth != 3:
		problems.append("A broken lift carried the rover.")
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(3) == "" or gs.rover_depth != 0:
		problems.append("The hub's lift ran with nothing repaired.")
	gs.lifts_repaired = {"lava_tubes": [3], "flooded_aquifer": [3]}
	if gs.use_lift(3) == "" or gs.rover_depth != 0:
		problems.append("Another zone's repaired lift ran the Mine's.")
	gs.free()
	return "\n".join(problems)


func test_the_lift_at_six_has_its_reach_its_ore_its_gate_and_its_order() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	var cost: Vector2i = ZoneDepth.lift_cost(6)
	if cost != Vector2i(200, 4):
		problems.append("The lift at 6 costs %s, not 200 CR and 4 ore." % cost)
	gs.crystal_ore = 20
	_rover_at(gs, 5, ZoneDepth.lift_position(6))
	if gs.repair_lift() == "" or gs.is_lift_repaired(ZONE, 6):
		problems.append("Depth 5 repaired depth 6's lift.")
	_rover_at(gs, 6, ZoneDepth.start_transform().origin)
	if gs.repair_lift() == "" or gs.credits != 1000 or gs.is_lift_repaired(ZONE, 6):
		problems.append("The lift at 6 was repaired from the start, away from it.")
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL - 1)
	var shut: String = gs.repair_lift()
	if shut == "" or not "lab level" in shut or gs.is_lift_repaired(ZONE, 6) or gs.credits != 1000 or gs.crystal_ore != 20:
		problems.append("The lift at 6 was repaired with the gate shut: '%s'." % shut)
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL)
	gs.crystal_ore = cost.y - 1
	if gs.repair_lift() == "" or gs.crystal_ore != cost.y - 1 or gs.credits != 1000 or gs.is_lift_repaired(ZONE, 6):
		problems.append("One ore short repaired depth 6's lift or took something.")
	gs.crystal_ore = 20
	gs.credits = cost.x - 1
	if gs.repair_lift() == "" or gs.credits != cost.x - 1 or gs.crystal_ore != 20 or gs.is_lift_repaired(ZONE, 6):
		problems.append("One credit short repaired depth 6's lift or took something.")
	gs.credits = 1000
	gs.crystal_ore = cost.y
	if gs.repair_lift() != "" or gs.crystal_ore != 0 or gs.credits != 1000 - cost.x or not gs.is_lift_repaired(ZONE, 6):
		problems.append("The exact ore did not repair the lift at 6, or the charge is wrong.")
	gs.crystal_ore = 20
	var credits: int = gs.credits
	if gs.repair_lift() == "" or gs.credits != credits:
		problems.append("The lift at 6 was charged twice.")
	if cost.x <= ZoneDepth.lift_cost(3).x or cost.y <= ZoneDepth.lift_cost(3).y:
		problems.append("The lift at 6 costs no more than the one at 3.")
	# 6 needs 3: with depth 3's lift broken the ride to 6 is refused.
	gs.lifts_repaired = {ZONE: [6]}
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(6) == "" or gs.rover_depth != 0:
		problems.append("The lift went to 6 with depth 3's lift broken.")
	gs.lifts_repaired = {ZONE: [3, 6]}
	if gs.use_lift(6) != "" or gs.rover_depth != 6:
		problems.append("The hub's lift did not go to 6 with everything met.")
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	if gs.use_lift(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 6 up to the hub failed.")
	# The ride down is held by the gate as well.
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL - 1)
	var held: String = gs.use_lift(6)
	if held == "" or gs.rover_depth != 0 or not held.contains("is shut"):
		problems.append("The hub's lift went to 6 with the gate shut: '%s'." % held)
	gs.free()
	return "\n".join(problems)


func test_the_repair_at_six_needs_depth_three_first() -> String:
	var gs: GameStateScript = _state(GATE_LEVEL, false)
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	var why: String = gs.repair_lift()
	var problems: Array[String] = []
	if why == "" or gs.is_lift_repaired(ZONE, 6) or gs.credits != 1000 or gs.crystal_ore != 20:
		problems.append("The lift at 6 was repaired, or charged, with depth 3's lift broken: '%s'." % why)
	elif not why.contains("lift at depth 3"):
		problems.append("The refusal does not name depth 3's lift: '%s'." % why)
	gs.free()
	return "\n".join(problems)


# --- The gate holds every host action at a deep depth -----------------------------------

func test_a_deep_find_does_not_pay_with_the_gate_shut() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	for broken: String in ["lab", "lift"]:
		for depth: int in DEEP:
			var gs: GameStateScript = _state(GATE_LEVEL - 1 if broken == "lab" else GATE_LEVEL, broken != "lift")
			_shore_all(gs, depth, day)
			var find: Dictionary = _plain_find(depth, day)
			var data: Dictionary = MineDepth.layout(SEED, depth, day, ALL_FALLS)
			_rover_at(gs, depth, TunnelRock.at_in(data["grid"], find["cell"]))
			var why: String = gs.take_find(str(find["id"]), day, HOST)
			if why == "" or not why.contains("is shut") or gs.credits != 1000 or gs.crystal_ore != 20:
				problems.append("A find at depth %d paid with %s missing: '%s'." % [depth, broken, why])
			if not ZoneDepth.taken_today(gs.finds_taken, ZONE, day).is_empty():
				problems.append("A refused find at depth %d was recorded with %s missing." % [depth, broken])
			gs.free()
	# Depth 3 is not behind the gate.
	var gs3: GameStateScript = _state(1, false)
	_shore_all(gs3, 3, day)
	var find3: Dictionary = _plain_find(3, day)
	var data3: Dictionary = MineDepth.layout(SEED, 3, day, ALL_FALLS)
	_rover_at(gs3, 3, TunnelRock.at_in(data3["grid"], find3["cell"]))
	if gs3.take_find(str(find3["id"]), day, HOST) != "":
		problems.append("Depth 3's find was refused for a new farm.")
	gs3.free()
	return "\n".join(problems)


func test_shoring_is_refused_deep_down_with_the_gate_shut_and_costs_nothing() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	for depth: int in DEEP:
		var data: Dictionary = MineDepth.layout(SEED, depth, day)
		var fall: Dictionary = data["rockfalls"][0]
		for broken: String in ["lab", "lift", "none"]:
			var gs: GameStateScript = _state(GATE_LEVEL - 1 if broken == "lab" else GATE_LEVEL, broken != "lift")
			gs.mine_props = 4
			_rover_at(gs, depth, MineDepth.rockfall_position(fall))
			var why: String = gs.shore_room(str(fall["id"]), day, HOST)
			if broken != "none":
				if why == "" or not why.contains("is shut"):
					problems.append("Depth %d: shoring was not refused with %s missing ('%s')." % [depth, broken, why])
				if gs.mine_props != 4 or not gs.rooms_shored.is_empty():
					problems.append("Depth %d: a refused shoring cost or stored something with %s missing." % [depth, broken])
			else:
				if why != "" or gs.mine_props != 4 - MineDepth.PROPS_PER_ROOM:
					problems.append("Depth %d: shoring was refused with the gate open ('%s', %d props)." % [depth, why, gs.mine_props])
				if MineDepth.shored_today(gs.rooms_shored, day, depth) != [str(fall["id"])]:
					problems.append("Depth %d: the shored room is stored as %s." % [depth, ZoneDepth.taken_today(gs.rooms_shored, ZONE, day)])
			gs.free()
	return "\n".join(problems)


# --- Hazards are kept by depth ----------------------------------------------------------

func test_storage_ids_are_plain_at_depth_one_and_qualified_below() -> String:
	var problems: Array[String] = []
	if MineDepth.storage_id(1, "r0") != "r0" or MineDepth.storage_id(0, "r0") != "r0":
		problems.append("Depth 1's storage id changed from the plain id.")
	if MineDepth.storage_id(2, "r0") != "d2_r0" or MineDepth.storage_id(6, "r1") != "d6_r1":
		problems.append("A deeper storage id is not d<depth>_<id>.")
	var seen: Dictionary = {}
	for depth: int in range(1, 7):
		for plain: String in MineDepth.ROCKFALL_IDS:
			seen[MineDepth.storage_id(depth, plain)] = true
	if seen.size() != 18:
		problems.append("Two depths share a storage id (%d of 18)." % seen.size())
	return "\n".join(problems)


func test_a_room_shored_on_depth_two_leaves_the_other_depths_buried() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state()
	gs.mine_props = 6
	var data2: Dictionary = MineDepth.layout(SEED, 2, day)
	var fall2: Dictionary = data2["rockfalls"][0]
	_rover_at(gs, 2, MineDepth.rockfall_position(fall2))
	if gs.shore_room(str(fall2["id"]), day, HOST) != "":
		problems.append("Shoring was refused at depth 2.")
	var held: Array = ZoneDepth.taken_today(gs.rooms_shored, ZONE, day)
	if held != [MineDepth.storage_id(2, str(fall2["id"]))]:
		problems.append("Depth 2's room is stored as %s." % [held])
	for depth: int in range(1, 7):
		var shored: Array = MineDepth.shored_today(gs.rooms_shored, day, depth)
		var layout: Dictionary = MineDepth.layout(SEED, depth, day, shored)
		for fall: Dictionary in layout["rockfalls"]:
			var expect: bool = depth == 2 and str(fall["id"]) == str(fall2["id"])
			if bool(fall["shored"]) != expect:
				problems.append("Depth %d's %s is shored = %s after shoring depth 2." % [depth, fall["id"], fall["shored"]])
	# The same id at depth 5 can still be shored, and does not undo depth 2's.
	var data5: Dictionary = MineDepth.layout(SEED, 5, day)
	var fall5: Dictionary = data5["rockfalls"][0]
	_rover_at(gs, 5, MineDepth.rockfall_position(fall5))
	if gs.shore_room(str(fall5["id"]), day, HOST) != "":
		problems.append("Depth 5's room was refused after depth 2's was shored.")
	if gs.shore_room(str(fall5["id"]), day, HOST) == "":
		problems.append("Depth 5's room was shored twice.")
	held = ZoneDepth.taken_today(gs.rooms_shored, ZONE, day)
	if held.size() != 2 or not MineDepth.storage_id(2, str(fall2["id"])) in held or not MineDepth.storage_id(5, str(fall5["id"])) in held:
		problems.append("The record is %s." % [held])
	if gs.mine_props != 4:
		problems.append("%d props are left after two rooms, not 4." % gs.mine_props)
	gs.free()
	return "\n".join(problems)


func test_the_colonists_case_is_its_own_find_at_each_depth() -> String:
	var problems: Array[String] = []
	var both: int = 0
	var differs: bool = false
	var cases: Dictionary = {}
	for day: int in range(1, 80):
		var ids: Array[String] = []
		for depth: int in range(1, 7):
			for find: Dictionary in MineDepth.layout(SEED, depth, day)["finds"]:
				if str(find["kind"]) == MineDepth.CASE:
					ids.append(str(find["id"]))
					if int(find["room"]) < 0:
						problems.append("Depth %d day %d has a case on the landing." % [depth, day])
		if ids.size() > 1:
			both += 1
		for id: String in ids:
			cases[id] = true
		var one: bool = MineDepth.has_case(ZoneDepth.stream(SEED, ZONE, 1, day))
		var two: bool = MineDepth.has_case(ZoneDepth.stream(SEED, ZONE, 2, day))
		if one != two:
			differs = true
	if not differs:
		problems.append("Depth 1 and depth 2 have a case on the very same days.")
	if both == 0 or cases.size() < 6:
		problems.append("Cases are too rare to tell apart: %d days with two, %d ids." % [both, cases.size()])
	# Taking depth 2's case leaves depth 1's on the floor.
	var pick: int = -1
	for day: int in range(1, 200):
		if MineDepth.has_case(ZoneDepth.stream(SEED, ZONE, 1, day)) and MineDepth.has_case(ZoneDepth.stream(SEED, ZONE, 2, day)):
			pick = day
			break
	if pick < 0:
		problems.append("No day in 200 has a case at both depths 1 and 2.")
		return "\n".join(problems)
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = float(pick - 1)
	var gs: GameStateScript = _state()
	var day_now: int = _today()
	_shore_all(gs, 1, day_now)
	_shore_all(gs, 2, day_now)
	var taken: Array[String] = []
	for depth: int in [2, 1]:
		var data: Dictionary = MineDepth.layout(SEED, depth, day_now, ALL_FALLS)
		var case_find: Dictionary = {}
		for find: Dictionary in data["finds"]:
			if str(find["kind"]) == MineDepth.CASE:
				case_find = find
		if case_find.is_empty():
			problems.append("Depth %d has no case on day %d." % [depth, day_now])
			continue
		_rover_at(gs, depth, TunnelRock.at_in(data["grid"], case_find["cell"]))
		var reply: String = gs.take_find(str(case_find["id"]), day_now, HOST)
		if reply != "" and not MineDepth.is_case_fallback_reply(reply):
			problems.append("Depth %d's case said '%s'." % [depth, reply])
		if gs.take_find(str(case_find["id"]), day_now, HOST) == "":
			problems.append("Depth %d's case was taken twice." % depth)
		taken.append(str(case_find["id"]))
		var held: Array = ZoneDepth.taken_today(gs.finds_taken, ZONE, day_now)
		if depth == 2 and (not taken[0] in held or held.size() != 1):
			problems.append("Taking depth 2's case recorded %s." % [held])
	if taken.size() == 2 and (taken[0] == taken[1] or ZoneDepth.taken_today(gs.finds_taken, ZONE, day_now).size() != 2):
		problems.append("The two cases are not two finds: %s." % [taken])
	GameClock.elapsed_days = saved
	gs.free()
	return "\n".join(problems)


# --- Saves ------------------------------------------------------------------------------

## True if a fresh farm takes `data` (and frees itself).
func _loads(data: Dictionary) -> bool:
	var fresh: GameStateScript = _state(1, false)
	var ok: bool = fresh.farm_from_dict(data) == ""
	fresh.free()
	return ok


func test_an_old_save_with_plain_ids_loads_and_bad_ids_are_refused() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state(1, false)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	for key: String in ["lifts_repaired", "deepest_depth", "rooms_shored"]:
		data.erase(key)
	if not _loads(data):
		problems.append("A save with none of the per-depth keys was refused.")
	data["rooms_shored"] = { ZONE: { "day": day, "ids": ["r0", "r2"] } }
	data["deepest_depth"] = { ZONE: 1 }
	var old: GameStateScript = _state(1, false)
	if old.farm_from_dict(data) != "":
		problems.append("A save with depth 1's plain ids was refused.")
	if MineDepth.shored_today(old.rooms_shored, day, 1) != ["r0", "r2"]:
		problems.append("Depth 1's rooms did not load: %s." % [old.rooms_shored])
	if not MineDepth.shored_today(old.rooms_shored, day, 2).is_empty():
		problems.append("Depth 1's plain ids shored depth 2.")
	old.free()
	data["rooms_shored"] = { ZONE: { "day": day, "ids": ["r0", "d3_r1", "d6_r2"] } }
	data["deepest_depth"] = { ZONE: 6 }
	if not _loads(data):
		problems.append("A save with deep room ids was refused.")
	for bad: String in ["d7_r0", "d1_r0", "d2_r9", "r9", "d0_r0"]:
		data["rooms_shored"] = { ZONE: { "day": day, "ids": [bad] } }
		if _loads(data):
			problems.append("A save with the room id '%s' was accepted." % bad)
	data["rooms_shored"] = { ZONE: { "day": day, "ids": ["d2_r0", "d2_r0"] } }
	if _loads(data):
		problems.append("A save with a room twice was accepted.")
	data["rooms_shored"] = {}
	data["deepest_depth"] = { ZONE: 7 }
	if _loads(data):
		problems.append("A save with the Mine's deepest depth at 7 was accepted.")
	data["deepest_depth"] = { ZONE: 6 }
	data["lifts_repaired"] = { ZONE: [3, 6] }
	if not _loads(data):
		problems.append("A save with lifts at 3 and 6 was refused.")
	data["lifts_repaired"] = { ZONE: [2] }
	if _loads(data):
		problems.append("A save with a lift at depth 2 was accepted.")
	gs.free()
	return "\n".join(problems)


func test_a_deep_rover_loaded_with_the_gate_shut_is_put_back_at_depth_three() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.deepest_depth[ZONE] = 6
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if data.get("rover_depth", 0) != 6 or data.get("rover_zone", "") != ZONE:
		problems.append("The save did not hold the rover at depth 6.")
	var edits: Array = [
		["the lab level", func(d: Dictionary) -> void: d["lab_xp"] = 0],
		["the lift at 3", func(d: Dictionary) -> void: d["lifts_repaired"] = {}],
	]
	for entry: Array in edits:
		var shut: Dictionary = data.duplicate(true)
		(entry[1] as Callable).call(shut)
		var low: GameStateScript = _state(1, false)
		if low.farm_from_dict(shut) != "":
			problems.append("The save without %s was refused." % entry[0])
		elif low.rover_depth != 3 or low.rover_zone != ZONE:
			problems.append("Without %s the rover was left at depth %d (%s)." % [entry[0], low.rover_depth, low.rover_zone])
		else:
			var at: Vector3 = low.rover_transforms[low.TUNNEL_ROVER].origin
			if at.distance_to(ZoneDepth.start_transform().origin) > 0.5:
				problems.append("Without %s the rover was not at depth 3's start (%s)." % [entry[0], at])
		if low.mine_deep_problem() == "":
			problems.append("The gate opened by loading without %s." % entry[0])
		low.free()
	var kept: GameStateScript = _state(1, false)
	if kept.farm_from_dict(data) != "" or kept.rover_depth != 6 or kept.rover_zone != ZONE:
		problems.append("The rover was moved though the gate is open (depth %d)." % kept.rover_depth)
	kept.free()
	var shallow: Dictionary = data.duplicate(true)
	shallow["rover_depth"] = 3
	shallow["lab_xp"] = 0
	var stay: GameStateScript = _state(1, false)
	if stay.farm_from_dict(shallow) != "" or stay.rover_depth != 3:
		problems.append("A rover at depth 3 was moved.")
	stay.free()
	gs.free()
	return "\n".join(problems)


# --- Finds ------------------------------------------------------------------------------

func test_a_deeper_find_always_pays_more_than_the_same_kind_above_it() -> String:
	var problems: Array[String] = []
	for kind: String in ["ore", "mineral", "scrap"]:
		var last: int = -1
		for depth: int in range(1, 7):
			var pay: Dictionary = MineDepth.reward(kind, depth)
			var total: int = int(pay.get("credits", 0)) + int(pay.get("crystal_ore", 0)) * 50
			if total <= last:
				problems.append("A %s at depth %d pays %d, no more than the depth above." % [kind, depth, total])
			last = total
		if MineDepth.reward(kind, 1) != MineDepth.REWARDS[kind] or MineDepth.reward(kind) != MineDepth.REWARDS[kind]:
			problems.append("A %s at depth 1 pays other than it did." % kind)
	if MineDepth.reward(MineDepth.CASE, 5) != MineDepth.reward(MineDepth.CASE, 1):
		problems.append("The colonist's case pays by depth: it stays a gauge-block find.")
	if MineDepth.reward_text("ore", 6) == MineDepth.reward_text("ore", 1):
		problems.append("The find's text does not follow the depth.")
	return "\n".join(problems)


func test_finds_pay_the_depths_rate_once_each_from_depth_one_to_six() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state()
	var seen: int = 0
	for depth: int in range(1, 7):
		_shore_all(gs, depth, day)
		var find: Dictionary = _plain_find(depth, day)
		if find.is_empty():
			problems.append("Depth %d has no find that is not a case today." % depth)
			continue
		var data: Dictionary = MineDepth.layout(SEED, depth, day, ALL_FALLS)
		_rover_at(gs, depth, TunnelRock.at_in(data["grid"], find["cell"]))
		var pay: Dictionary = MineDepth.reward(str(find["kind"]), depth)
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		var why: String = gs.take_find(str(find["id"]), day, HOST)
		if why != "" or gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			problems.append("Depth %d's %s paid %d CR and %d ore, not %s ('%s')." % [depth, find["kind"], gs.credits - credits, gs.crystal_ore - ore, pay, why])
		credits = gs.credits
		ore = gs.crystal_ore
		if gs.take_find(str(find["id"]), day, HOST) == "" or gs.credits != credits or gs.crystal_ore != ore:
			problems.append("Depth %d's find was taken twice." % depth)
		if not str(find["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("Depth %d's find is not recorded under the Mine." % depth)
		seen += 1
	if seen != 6:
		problems.append("Only %d of 6 depths were checked." % seen)
	if gs.finds_taken.has("lava_tubes") or gs.finds_taken.has("flooded_aquifer"):
		problems.append("A Mine find was recorded under another zone.")
	gs.free()
	return "\n".join(problems)


func test_a_find_in_a_buried_room_waits_for_the_shoring_at_its_own_depth() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state()
	for depth: int in [2, 5]:
		var data: Dictionary = MineDepth.layout(SEED, depth, day)
		var fall: Dictionary = data["rockfalls"][0]
		var buried: Dictionary = {}
		for find: Dictionary in data["finds"]:
			if int(find["room"]) == int(fall["room"]):
				buried = find
		_rover_at(gs, depth, TunnelRock.at_in(data["grid"], buried["cell"]))
		var credits: int = gs.credits
		var why: String = gs.take_find(str(buried["id"]), day, HOST)
		if why == "" or not why.contains("rockfall") or gs.credits != credits:
			problems.append("Depth %d's buried find was taken or said '%s'." % [depth, why])
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, MineDepth.storage_id(1, str(fall["id"])))
		if gs.take_find(str(buried["id"]), day, HOST) == "":
			problems.append("Shoring depth 1's %s opened depth %d's room." % [fall["id"], depth])
			break
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, MineDepth.storage_id(depth, str(fall["id"])))
		var first: String = gs.take_find(str(buried["id"]), day, HOST)
		if first != "" and not MineDepth.is_case_fallback_reply(first):
			problems.append("Depth %d's find was refused ('%s') after its own room was shored." % [depth, first])
		if not str(buried["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("Depth %d's find was not taken after its own room was shored." % depth)
	gs.free()
	return "\n".join(problems)


# --- The layouts -----------------------------------------------------------------------

## Depth 1's layout (grid, finds with cells and kinds, rockfalls) for six seeds on five days,
## unshored and with every room shored, as `str(layout).hash()`: [seed, day, hash, hash shored].
## The values were taken from origin/main's mine_depth.gd before this slice, and match the new
## code's output: depth 1 is byte for byte unchanged.
const DEPTH_ONE_HASHES: Array = [
	[1, 0, 1479704548, 1221545806], [1, 1, 189572228, 2406237358], [1, 2, 4182135993, 2808243107],
	[1, 5, 3438579288, 2635280578], [1, 11, 2041030194, 3764540135], [1, 40, 3580146511, 166965348],
	[7, 0, 2432048792, 1727246594], [7, 1, 2720167872, 4175571637], [7, 2, 1409679798, 1876178080],
	[7, 5, 16562245, 2604530543], [7, 11, 3555834384, 296379141], [7, 40, 2257512347, 2058378565],
	[424242, 0, 639149432, 3926327266], [424242, 1, 3787853854, 300779784], [424242, 2, 180253110, 4098604523],
	[424242, 5, 387610730, 3844587039], [424242, 11, 2096487559, 797672337], [424242, 40, 935914410, 1579946388],
	[2026, 0, 1815949741, 2456214274], [2026, 1, 377990064, 980983973], [2026, 2, 791038065, 4117113158],
	[2026, 5, 2729611443, 2223599944], [2026, 11, 1337731632, 434131706], [2026, 40, 3416478653, 1243044071],
	[99991, 0, 139072932, 2145098777], [99991, 1, 630164661, 3721786634], [99991, 2, 1834567640, 2717079501],
	[99991, 5, 3930702919, 1443403697], [99991, 11, 2123707666, 1684637127], [99991, 40, 3304182291, 288753320],
]


func test_depth_one_is_as_it_was() -> String:
	var problems: Array[String] = []
	for pin: Array in DEPTH_ONE_HASHES:
		var plain: Dictionary = MineDepth.layout(int(pin[0]), 1, int(pin[1]), [])
		var shored: Dictionary = MineDepth.layout(int(pin[0]), 1, int(pin[1]), ALL_FALLS)
		if str(plain).hash() != int(pin[2]) or str(shored).hash() != int(pin[3]):
			problems.append("Depth 1's layout for seed %d day %d is not the one main made." % [pin[0], pin[1]])
	if DEPTH_ONE_HASHES.size() != 30:
		problems.append("The pins were edited: %d of 30." % DEPTH_ONE_HASHES.size())
	return "\n".join(problems.slice(0, 4))


func test_rockfalls_grow_going_down_and_depth_one_keeps_its_rule() -> String:
	var problems: Array[String] = []
	var ones: int = 0
	var twos: int = 0
	for seed_value: int in range(1, 13):
		for day: int in range(0, 30):
			for depth: int in range(1, 7):
				var falls: Array = MineDepth.layout(seed_value * 7919, depth, day)["rockfalls"]
				var count: int = falls.size()
				var ids: Dictionary = {}
				for fall: Dictionary in falls:
					ids[fall["id"]] = true
				if ids.size() != count:
					problems.append("Seed %d depth %d day %d repeats a rockfall." % [seed_value, depth, day])
				if depth <= 3:
					if count < 1 or count > 2:
						problems.append("Seed %d depth %d day %d has %d rockfalls." % [seed_value, depth, day, count])
					if depth == 2:
						ones += 1 if count == 1 else 0
						twos += 1 if count == 2 else 0
				elif depth < 6 and count != 2:
					problems.append("Seed %d depth %d day %d has %d rockfalls, not 2." % [seed_value, depth, day, count])
				elif depth == 6 and count != 3:
					problems.append("Seed %d depth 6 day %d has %d rockfalls, not 3." % [seed_value, day, count])
		if problems.size() > 4:
			break
	if ones == 0 or twos == 0:
		problems.append("Depth 2 never varies between one and two rockfalls (%d, %d)." % [ones, twos])
	return "\n".join(problems.slice(0, 5))


func test_every_layout_at_every_depth_is_reached_from_the_start() -> String:
	var problems: Array[String] = []
	var checked: int = 0
	for seed_value: int in range(1, 25):
		for day: int in range(0, 25):
			for depth: int in range(1, 7):
				var data: Dictionary = MineDepth.layout(seed_value * 104729, depth, day, ALL_FALLS)
				var seen: Array[Vector2i] = ZoneDepth.reachable(data["grid"], ZoneDepth.START_CELL)
				checked += 1
				var where: String = "Seed %d depth %d day %d" % [seed_value, depth, day]
				if not ZoneDepth.UP_CELL in seen:
					problems.append("%s: the way up is cut off." % where)
				if ZoneDepth.has_way_down(depth) and not ZoneDepth.HATCH_CELL in seen:
					problems.append("%s: the hatch down is cut off." % where)
				if ZoneDepth.is_lift_depth(depth) and not ZoneDepth.LIFT_CELL in seen:
					problems.append("%s: the lift is cut off." % where)
				for find: Dictionary in data["finds"]:
					if not find["cell"] in seen:
						problems.append("%s: %s is out of reach." % [where, find["id"]])
					if find["cell"] in ZoneDepth._kept_clear(depth):
						problems.append("%s: %s sits on the hatch or the lift." % [where, find["id"]])
				for fall: Dictionary in data["rockfalls"]:
					if not fall["cell"] in seen:
						problems.append("%s: rockfall %s is out of reach." % [where, fall["id"]])
					for find: Dictionary in data["finds"]:
						if find["cell"] == fall["cell"]:
							problems.append("%s: %s sits on a rockfall." % [where, find["id"]])
				if data["finds"].size() != MineDepth.find_count():
					problems.append("%s: %d finds, not %d." % [where, data["finds"].size(), MineDepth.find_count()])
				if problems.size() > 6:
					return "\n".join(problems)
	if checked != 24 * 25 * 6:
		problems.append("Checked %d layouts." % checked)
	return "\n".join(problems)


func test_each_depth_is_its_own_daily_floor() -> String:
	var problems: Array[String] = []
	var floors: Dictionary = {}
	for depth: int in range(1, 7):
		var a: Dictionary = MineDepth.layout(SEED, depth, 5)
		var b: Dictionary = MineDepth.layout(SEED, depth, 5)
		if a != b:
			problems.append("Depth %d is not the same for the same seed and day." % depth)
		if MineDepth.layout(SEED, depth, 6) == a:
			problems.append("Depth %d is the same on two days." % depth)
		floors[str(a["finds"])] = true
	if floors.size() < 5:
		problems.append("The depths share their finds (%d distinct of 6)." % floors.size())
	return "\n".join(problems)


# --- The look ---------------------------------------------------------------------------

func _lights(node: Node) -> int:
	var n: int = 1 if node is Light3D else 0
	for child: Node in node.get_children():
		n += _lights(child)
	return n


## The scene built at `depth` of today: { "lights": its lights outside the rock, "bright": the
## summed albedo brightness of the decor's materials, "meshes": how many it summed }.
func _scene_at(depth: int) -> Dictionary:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	GameState.rover_zone = ZONE
	GameState.rover_depth = depth
	GameState.rover_transforms.erase(GameState.TUNNEL_ROVER)
	var scene: Node = (load("res://scenes/colony_mine.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var rock: Node = scene.get_node("WorldView/WorldViewport/World/Rock")
	var bright: float = 0.0
	var meshes: int = 0
	var decor: Node = scene.get("_decor") as Node
	var clashes: int = 0
	var spots: Array[Rect2] = []  # the hatch's disc and the lift's deck, as squares on the floor
	var hatch: Vector3 = ZoneDepth.descent_position(depth)
	spots.append(Rect2(hatch.x - 1.3, hatch.z - 1.3, 2.6, 2.6))
	if depth == 0 or ZoneDepth.is_lift_depth(depth):
		var lift: Vector3 = ZoneDepth.lift_position(depth)
		spots.append(Rect2(lift.x - 1.2, lift.z - 1.2, 2.4, 2.4))
	if decor != null:
		for node: Node in decor.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
			for spot: Rect2 in spots:
				if spot.intersects(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)):
					clashes += 1
			var material: Variant = (node as MeshInstance3D).material_override
			if material is StandardMaterial3D:
				bright += (material as StandardMaterial3D).albedo_color.v
				meshes += 1
	var out: Dictionary = { "lights": _lights(scene) - _lights(rock), "bright": bright, "meshes": meshes, "clashes": clashes }
	root.remove_child(scene)
	scene.free()
	return out


func test_each_depth_is_a_little_darker_with_no_new_lights() -> String:
	var problems: Array[String] = []
	if ColonyMine.depth_dim(0) != 1.0 or ColonyMine.depth_dim(1) != 1.0:
		problems.append("The hub or depth 1 is dimmed.")
	var last: float = 1.0
	for depth: int in range(2, 7):
		var keep: float = ColonyMine.depth_dim(depth)
		if keep >= last and last > ColonyMine.DIM_FLOOR:
			problems.append("Depth %d is no darker than the depth above (%.2f)." % [depth, keep])
		if keep < ColonyMine.DIM_FLOOR:
			problems.append("Depth %d is darker than the floor (%.2f)." % [depth, keep])
		last = keep
	var saved_zone: String = GameState.rover_zone
	var saved_depth: int = GameState.rover_depth
	var saved_transforms: Dictionary = GameState.rover_transforms.duplicate(true)
	var saved_seed: int = GameState.world_seed
	var saved_lent: bool = GameState.rover_lent
	var saved_local: Array = [ZoneDepth.local_zone, ZoneDepth.local_depth, ZoneDepth.local_layout.duplicate(true), ZoneDepth.arrive_at, ZoneDepth.arrive_pending]
	GameState.world_seed = SEED
	GameState.rover_lent = true
	for depth: int in [0, 1, 2, 3, 6]:
		var dressed: Dictionary = _scene_at(depth)
		if int(dressed["clashes"]) != 0:
			problems.append("Depth %d's decor stands on the hatch or the lift (%d pieces)." % [depth, dressed["clashes"]])
	var one: Dictionary = _scene_at(1)
	var previous: float = float(one["bright"])
	if int(one["meshes"]) == 0 or previous <= 0.0:
		problems.append("Depth 1's decor has no material to dim (%d)." % int(one["meshes"]))
	for depth: int in [2, 4, 6]:
		var built: Dictionary = _scene_at(depth)
		if int(built["lights"]) != int(one["lights"]):
			problems.append("Depth %d has %d lights outside the rock, depth 1 has %d." % [depth, built["lights"], one["lights"]])
		if int(built["meshes"]) == 0 or float(built["bright"]) >= previous:
			problems.append("Depth %d's decor (%.2f) is no darker than the one above (%.2f)." % [depth, built["bright"], previous])
		previous = float(built["bright"])
	GameState.rover_zone = saved_zone
	GameState.rover_depth = saved_depth
	GameState.rover_transforms = saved_transforms
	GameState.world_seed = saved_seed
	GameState.rover_lent = saved_lent
	ZoneDepth.local_zone = str(saved_local[0])
	ZoneDepth.local_depth = int(saved_local[1])
	ZoneDepth.local_layout = saved_local[2]
	ZoneDepth.arrive_at = saved_local[3]
	ZoneDepth.arrive_pending = bool(saved_local[4])
	return "\n".join(problems)


func test_shoring_a_room_redraws_the_rockfalls_in_place() -> String:
	var problems: Array[String] = []
	var saved_zone: String = GameState.rover_zone
	var saved_depth: int = GameState.rover_depth
	var saved_transforms: Dictionary = GameState.rover_transforms.duplicate(true)
	var saved_seed: int = GameState.world_seed
	var saved_lent: bool = GameState.rover_lent
	var saved_shored: Dictionary = GameState.rooms_shored.duplicate(true)
	var saved_local: Array = [ZoneDepth.local_zone, ZoneDepth.local_depth, ZoneDepth.local_layout.duplicate(true), ZoneDepth.arrive_at, ZoneDepth.arrive_pending]
	GameState.world_seed = SEED
	GameState.rover_lent = true
	GameState.rooms_shored = {}
	GameState.rover_zone = ZONE
	GameState.rover_depth = 4
	GameState.rover_transforms.erase(GameState.TUNNEL_ROVER)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var scene: Node = (load("res://scenes/colony_mine.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var fallen: Node = scene.get("_rockfalls") as Node
	var day: int = GameClock.get_day_index()
	var falls: Array = MineDepth.layout(SEED, 4, day)["rockfalls"]
	var before: Array = []
	for child: Node in fallen.get_children():
		before.append(child)
	GameState.rooms_shored = ZoneDepth.with_taken(GameState.rooms_shored, ZONE, day, MineDepth.storage_id(4, str(falls[0]["id"])))
	scene.call("_resync_depth")
	if SceneSwitcher.is_busy():
		problems.append("Shoring a room swapped the scene.")
	if not scene.is_inside_tree() or scene.get("_rockfalls") != fallen:
		problems.append("The scene was rebuilt, not updated.")
	var labels: PackedStringArray = []
	for node: Node in fallen.find_children("*", "Label3D", true, false):
		labels.append((node as Label3D).text)
	if not ("%s SHORED" % str(falls[0]["id"]).to_upper()) in labels:
		problems.append("The shored room has no shored label (%s)." % [labels])
	if labels.size() != falls.size():
		problems.append("%d rockfall labels for %d rockfalls." % [labels.size(), falls.size()])
	for fall: Dictionary in ZoneDepth.local_layout.get("rockfalls", []):
		if bool(fall["shored"]) != (str(fall["id"]) == str(falls[0]["id"])):
			problems.append("The local layout has %s shored = %s." % [fall["id"], fall["shored"]])
	root.remove_child(scene)
	scene.free()
	GameState.rover_zone = saved_zone
	GameState.rover_depth = saved_depth
	GameState.rover_transforms = saved_transforms
	GameState.world_seed = saved_seed
	GameState.rover_lent = saved_lent
	GameState.rooms_shored = saved_shored
	ZoneDepth.local_zone = str(saved_local[0])
	ZoneDepth.local_depth = int(saved_local[1])
	ZoneDepth.local_layout = saved_local[2]
	ZoneDepth.arrive_at = saved_local[3]
	ZoneDepth.arrive_pending = bool(saved_local[4])
	return "
".join(problems)


# --- The other zones are as they were ---------------------------------------------------

func test_the_lava_tubes_and_the_aquifer_keep_their_own_gates() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(GATE_LEVEL, true)
	if gs.deep_problem("lava_tubes") == "" or gs.deep_problem("flooded_aquifer") == "":
		problems.append("The Mine's lift or level opened another zone's gate.")
	if gs.deep_problem("ice_caves") != "" or gs.deep_problem("farm") != "":
		problems.append("A zone with no deep depths has a gate.")
	if gs.mine_deep_problem() != "":
		problems.append("The Mine's gate stayed shut with everything met.")
	gs.free()
	return "\n".join(problems)


# --- Nothing new on the wire ------------------------------------------------------------

func test_the_protocol_did_not_move_for_depths_two_to_six() -> String:
	# 42 when the Mine landed; the Ice Caves slice the Ice Caves slice then moved it, and later slices again.
	if not CoopSession.PROTOCOL in [42, 43, 44, 45, 46, 47, 48, 50]:
		return "PROTOCOL is %d; depths 2 to 6 add no command or synced field, so it stays where the other slices put it." % CoopSession.PROTOCOL
	return ""


# --- Review fixes: the phone's deepest lines, the held rover, the decor ------------------

func test_the_phone_names_each_zone_the_rover_has_been_below_in() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	if "Deepest" in gs.contract_phone_text():
		problems.append("A deepest line before any depth.")
	gs.deepest_depth = {ZONE: 5}
	if ZoneDepth.deepest_text(gs.deepest_depth, ZONE) != "Deepest: Abandoned Colony Mine, depth 5":
		problems.append("The Mine's line is '%s'." % ZoneDepth.deepest_text(gs.deepest_depth, ZONE))
	if not "Abandoned Colony Mine, depth 5" in gs.contract_phone_text() or "Lava Tubes" in gs.contract_phone_text():
		problems.append("The phone says '%s'." % gs.contract_phone_text())
	gs.deepest_depth = {ZONE: 5, "lava_tubes": 2}
	var text: String = gs.contract_phone_text()
	if not "Lava Tubes, depth 2" in text or not "Colony Mine, depth 5" in text:
		problems.append("Two zones, but the phone says '%s'." % text)
	gs.free()
	return "
".join(problems)


func test_a_held_rover_always_has_a_pose_even_under_a_drive_lease() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(GATE_LEVEL - 1, false)
	gs.rover_zone = ZONE
	gs.rover_depth = 5
	gs.rover_transforms.erase(gs.TUNNEL_ROVER)
	gs._hold_deep_rover()
	if gs.rover_depth != 3:
		problems.append("The held rover is at depth %d, not 3." % gs.rover_depth)
	if not gs.rover_transforms.has(gs.TUNNEL_ROVER) or (gs.rover_transforms[gs.TUNNEL_ROVER] as Transform3D).origin != ZoneDepth.start_transform().origin:
		problems.append("The held rover has no pose at depth 3's start.")
	gs.free()
	return "
".join(problems)


func test_an_old_save_deep_with_the_gate_shut_records_no_depth_past_three() -> String:
	var problems: Array[String] = []
	var source: GameStateScript = _state(GATE_LEVEL - 1, false)
	source.rover_zone = ZONE
	source.rover_depth = 5
	var data: Dictionary = source.farm_to_dict()
	data.erase("deepest_depth")
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	var why: String = gs.farm_from_dict(data)
	if why != "":
		problems.append("The old save was refused: %s" % why)
	if gs.rover_depth != 3:
		problems.append("The rover loaded at depth %d, not 3." % gs.rover_depth)
	if int(gs.deepest_depth.get(ZONE, 0)) > 3:
		problems.append("The deepest depth was backfilled as %d past a shut gate." % int(gs.deepest_depth.get(ZONE, 0)))
	if not gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("The loaded, held rover has no pose.")
	gs.free()
	source.free()
	return "
".join(problems)
