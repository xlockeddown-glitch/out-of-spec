extends RefCounted
## The Flooded Aquifer's depths 2 to 6 (docs/design/zones.md, slice 12): depths 2 and 3
## open, depths 4 to 6 behind the `aquifer_deep` gate (lab level 14, the pump, the lift at
## depth 3), the lifts at 3 and 6, the hazards kept by depth, and the better finds.
## Every number is a [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST := "player_1"
const SEED := 424242
const ZONE: String = "flooded_aquifer"
const DEEP: Array[int] = [4, 5, 6]
const GATE_LEVEL: int = 14


## A farm at lab level `level`, with or without the pump and depth 3's mended lift.
func _state(level: int = GATE_LEVEL, pump: bool = true, lift3: bool = true) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	gs.lab_xp = gs.xp_for_level(level)
	gs.credits = 1000
	gs.crystal_ore = 20
	gs.pump_owned = pump
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


func _all_drained() -> Array:
	return AquiferDepth.storage_ids(AquiferDepth.POOL_IDS)


## The first find of `depth` today that no open seal blocks, with the rover's place for it.
func _free_find(depth: int, day: int) -> Dictionary:
	var data: Dictionary = AquiferDepth.layout(SEED, depth, day)
	for find: Dictionary in data["finds"]:
		if AquiferDepth.seal_problem(data, str(find["id"])) == "":
			return find
	return {}


## A take that went through: "" or the wet-pack line a wading find also answers with.
func _took(reply: String) -> bool:
	return reply == "" or AquiferDepth.is_wet_pack_reply(reply)


# --- The rows and the ranges -----------------------------------------------------------

func test_the_zone_has_six_depths_and_the_gate_row_is_built_at_level_fourteen() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false, false)
	if ZoneDepth.max_depth_of(ZONE) != 6 or ZoneDepth.max_depth_of("lava_tubes") != 6:
		problems.append("max_depth_of: aquifer %d, lava %d." % [ZoneDepth.max_depth_of(ZONE), ZoneDepth.max_depth_of("lava_tubes")])
	if gs.lab_gate_level(AquiferDepth.DEEP_GATE) != GATE_LEVEL:
		problems.append("The gate is at lab level %d." % gs.lab_gate_level(AquiferDepth.DEEP_GATE))
	if ZoneData.zone(&"flooded_aquifer").get("deep_gate", "") != AquiferDepth.DEEP_GATE:
		problems.append("The zone row does not name the deep gate.")
	if AquiferDepth.layout(SEED, 7, 1) != {} or AquiferDepth.layout(SEED, 0, 1) != {}:
		problems.append("A depth outside 1 to 6 has a layout.")
	for depth: int in range(0, 6):
		if not ZoneDepth.has_way_down(depth):
			problems.append("Depth %d has no hatch down." % depth)
	if ZoneDepth.has_way_down(6):
		problems.append("Depth 6 has a hatch down.")
	gs.free()
	return "\n".join(problems)


# --- Depths 2 and 3 are open, 4 to 6 are not --------------------------------------------

func test_depths_two_and_three_are_open_to_a_new_farm() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false, false)
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


func test_depths_four_to_six_need_the_level_the_pump_and_the_lift_and_nothing_is_charged() -> String:
	var problems: Array[String] = []
	var cases: Array = [
		["lab level", _state(GATE_LEVEL - 1, true, true)],
		["pump", _state(GATE_LEVEL, false, true)],
		["lift", _state(GATE_LEVEL, true, false)],
	]
	for entry: Array in cases:
		var gs: GameStateScript = entry[1]
		_rover_at(gs, 3, ZoneDepth.descent_position(3))
		var epoch: int = gs.rover_epoch
		var why: String = gs.change_depth(4)
		if why == "" or gs.rover_depth != 3 or gs.rover_epoch != epoch:
			problems.append("Depth 4 opened without the %s: '%s'." % [entry[0], why])
		elif not str(entry[0]) in why:
			problems.append("The refusal for the %s does not say so: '%s'." % [entry[0], why])
		if gs.credits != 1000 or gs.crystal_ore != 20:
			problems.append("A refusal for the %s charged something." % entry[0])
		gs.free()
	var open: GameStateScript = _state()
	_rover_at(open, 3, ZoneDepth.descent_position(3))
	if open.aquifer_deep_problem() != "" or open.change_depth(4) != "" or open.rover_depth != 4:
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
	if gs.change_depth(7) == "" or gs.rover_depth != 6:
		problems.append("There is a depth 7.")
	gs.free()
	return "\n".join(problems)


func test_the_hub_hatch_and_the_way_up_to_the_hub_still_work() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false, false)
	_rover_at(gs, 0, AquiferDepth.hatch_position())
	if gs.change_depth(1) != "" or gs.rover_depth != 1:
		problems.append("The hub hatch did not go to depth 1.")
	_rover_at(gs, 1, ZoneDepth.ascent_position())
	if gs.change_depth(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 1 did not go up to the hub.")
	else:
		var beside: Vector3 = AquiferDepth.hatch_position() + Vector3(0.0, 0.05, TunnelRock.CELL_M)
		var at: Vector3 = gs.rover_transforms[gs.TUNNEL_ROVER].origin
		if at.distance_to(beside) > 0.5:
			problems.append("The rover came up at %s, not beside the hub's hatch." % at)
	gs.free()
	return "\n".join(problems)


# --- The lifts at 3 and 6 --------------------------------------------------------------

func test_the_lift_at_three_has_its_reach_its_ore_and_is_paid_once() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false, false)
	var cost: Vector2i = ZoneDepth.lift_cost(3)
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
	gs.crystal_ore = cost.y
	if gs.repair_lift() != "" or gs.crystal_ore != 0 or gs.credits != 1000 - cost.x or not gs.is_lift_repaired(ZONE, 3):
		problems.append("The exact ore did not repair it, or the charge is wrong (%d CR, %d ore)." % [1000 - gs.credits, cost.y - gs.crystal_ore])
	if gs.is_lift_repaired("lava_tubes", 3):
		problems.append("Repairing the Aquifer's lift mended the Lava Tubes'.")
	gs.crystal_ore = 20
	var credits: int = gs.credits
	if gs.repair_lift() == "" or gs.credits != credits or gs.crystal_ore != 20:
		problems.append("The lift was repaired, or charged, twice.")
	# Up to the hub and back down by the lift.
	if gs.use_lift(0) != "" or gs.rover_depth != 0:
		problems.append("Depth 3 to the hub failed with the lift mended.")
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(3) != "" or gs.rover_depth != 3:
		problems.append("The hub's lift did not go to depth 3.")
	gs.free()
	return "\n".join(problems)


func test_a_broken_lift_carries_nobody_and_the_lava_lifts_are_not_the_aquifers() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state(1, false, false)
	_rover_at(gs, 3, ZoneDepth.lift_position(3))
	if gs.use_lift(0) == "" or gs.rover_depth != 3:
		problems.append("A broken lift carried the rover.")
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	if gs.use_lift(3) == "" or gs.rover_depth != 0:
		problems.append("The hub's lift ran with nothing repaired.")
	gs.lifts_repaired = {"lava_tubes": [3]}
	if gs.use_lift(3) == "" or gs.rover_depth != 0:
		problems.append("The Lava Tubes' repaired lift ran the Aquifer's.")
	gs.free()
	return "\n".join(problems)


func test_the_lift_at_six_has_its_reach_its_ore_its_gate_and_its_order() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	var cost: Vector2i = ZoneDepth.lift_cost(6)
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
	# The ride to 6 is held by the gate as well.
	_rover_at(gs, 0, ZoneDepth.lift_position(0))
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL - 1)
	if gs.use_lift(6) == "" or gs.rover_depth != 0:
		problems.append("The hub's lift went to 6 with the gate shut.")
	gs.pump_owned = false
	gs.lab_xp = gs.xp_for_level(GATE_LEVEL)
	if gs.use_lift(6) == "" or gs.rover_depth != 0:
		problems.append("The hub's lift went to 6 without the pump.")
	gs.free()
	return "\n".join(problems)


# --- Hazards are kept by depth ----------------------------------------------------------

func test_storage_ids_are_plain_at_depth_one_and_qualified_below() -> String:
	var problems: Array[String] = []
	if AquiferDepth.storage_id(1, "p0") != "p0" or AquiferDepth.storage_id(0, "p0") != "p0":
		problems.append("Depth 1's storage id changed from the plain id.")
	if AquiferDepth.storage_id(2, "p0") != "d2_p0" or AquiferDepth.storage_id(6, "s1") != "d6_s1":
		problems.append("A deeper storage id is not d<depth>_<id>.")
	var seen: Dictionary = {}
	for depth: int in range(1, 7):
		for plain: String in AquiferDepth.POOL_IDS:
			seen[AquiferDepth.storage_id(depth, plain)] = true
	if seen.size() != 18:
		problems.append("Two depths share a storage id (%d of 18)." % seen.size())
	return "\n".join(problems)


func test_a_pool_pumped_on_depth_two_leaves_the_other_depths_wet() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state()
	var data2: Dictionary = AquiferDepth.layout(SEED, 2, day)
	var centre2: Vector2 = AquiferDepth.pool_metres(AquiferDepth.pool_in(data2, "p0")).get_center()
	_rover_at(gs, 2, Vector3(centre2.x, 0.0, centre2.y))
	if gs.use_pump("p0", day, HOST) != "":
		problems.append("The pump was refused at depth 2.")
	var held: Array = AquiferDepth.drained_today(gs.pools_drained, day)
	if held != ["d2_p0"]:
		problems.append("Depth 2's pool is stored as %s." % [held])
	for depth: int in range(1, 7):
		var layout: Dictionary = AquiferDepth.layout(SEED, depth, day, held)
		var pool: Dictionary = AquiferDepth.pool_in(layout, "p0")
		if bool(pool["drained"]) != (depth == 2):
			problems.append("Depth %d's p0 is drained = %s after pumping depth 2." % [depth, pool["drained"]])
	# The same pool id at depth 5 can still be pumped, and does not undo depth 2's.
	var data5: Dictionary = AquiferDepth.layout(SEED, 5, day)
	var centre5: Vector2 = AquiferDepth.pool_metres(AquiferDepth.pool_in(data5, "p0")).get_center()
	_rover_at(gs, 5, Vector3(centre5.x, 0.0, centre5.y))
	if gs.use_pump("p0", day, HOST) != "":
		problems.append("Depth 5's p0 was refused after depth 2's was pumped.")
	if gs.use_pump("p0", day, HOST) == "":
		problems.append("Depth 5's p0 was pumped twice.")
	held = AquiferDepth.drained_today(gs.pools_drained, day)
	if not "d2_p0" in held or not "d5_p0" in held or held.size() != 2:
		problems.append("The record is %s." % [held])
	gs.free()
	return "\n".join(problems)


func test_a_valve_shut_on_depth_two_leaves_the_other_depths_open() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state()
	var data: Dictionary = AquiferDepth.layout(SEED, 2, day)
	var seal: Dictionary = data["seals"][0]
	_rover_at(gs, 2, AquiferDepth.seal_position(seal))
	if gs.shut_valve(str(seal["id"]), day, HOST) != "":
		problems.append("The valve was refused at depth 2.")
	var held: Array = AquiferDepth.shut_today(gs.valves_shut, day)
	if held != [AquiferDepth.storage_id(2, str(seal["id"]))]:
		problems.append("The shut valve is stored as %s." % [held])
	if not bool(AquiferDepth.layout(SEED, 2, day, [], held)["seals"][0]["shut"]):
		problems.append("Depth 2's seal is not shut.")
	for depth: int in [1, 3, 4, 5, 6]:
		for other: Dictionary in AquiferDepth.layout(SEED, depth, day, [], held)["seals"]:
			if bool(other["shut"]):
				problems.append("Depth %d's seal is shut by depth 2's valve." % depth)
	gs.free()
	return "\n".join(problems)


func test_the_pump_and_the_valve_are_refused_deep_down_with_the_gate_shut() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	for depth: int in DEEP:
		var data: Dictionary = AquiferDepth.layout(SEED, depth, day)
		var centre: Vector2 = AquiferDepth.pool_metres(AquiferDepth.pool_in(data, "p0")).get_center()
		var seal: Dictionary = data["seals"][0]
		for broken: String in ["lab", "pump", "lift", "none"]:
			var gs: GameStateScript = _state(GATE_LEVEL - 1 if broken == "lab" else GATE_LEVEL, broken != "pump", broken != "lift")
			var shut: bool = broken != "none"
			_rover_at(gs, depth, Vector3(centre.x, 0.0, centre.y))
			var pumped: String = gs.use_pump("p0", day, HOST)
			_rover_at(gs, depth, AquiferDepth.seal_position(seal))
			var valved: String = gs.shut_valve(str(seal["id"]), day, HOST)
			if shut:
				if pumped == "" or not "is shut" in pumped:
					problems.append("Depth %d: the pump was not refused with %s missing (%s)." % [depth, broken, pumped])
				if valved == "" or not "is shut" in valved:
					problems.append("Depth %d: the valve was not refused with %s missing (%s)." % [depth, broken, valved])
				if not AquiferDepth.drained_today(gs.pools_drained, day).is_empty() or not AquiferDepth.shut_today(gs.valves_shut, day).is_empty():
					problems.append("Depth %d: a refused pump or valve was recorded with %s missing." % [depth, broken])
			else:
				if pumped != "" or valved != "":
					problems.append("Depth %d: the pump or the valve was refused with the gate open (%s, %s)." % [depth, pumped, valved])
				if AquiferDepth.drained_today(gs.pools_drained, day) != [AquiferDepth.storage_id(depth, "p0")]:
					problems.append("Depth %d: the open pump is stored as %s." % [depth, AquiferDepth.drained_today(gs.pools_drained, day)])
			gs.free()
	return "
".join(problems.slice(0, 4))


func test_the_seal_is_one_a_day_at_every_depth() -> String:
	for depth: int in range(1, 7):
		for day: int in range(1, 20):
			var seals: Array = AquiferDepth.layout(SEED, depth, day)["seals"]
			if seals.size() != AquiferDepth.SEALS_PER_DAY:
				return "Depth %d day %d has %d open seals." % [depth, day, seals.size()]
	return ""


func test_the_pack_gets_wet_once_a_day_whatever_the_depth() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	gs.camp_supplies = 3
	gs.pools_drained = {}
	# Look over the next days for one with a find reached by wading at both depths 2 and 3.
	var day: int = _today()
	var wet: Array = []
	for offset: int in 200:
		wet.clear()
		for depth: int in [2, 3]:
			var data: Dictionary = AquiferDepth.layout(SEED, depth, day + offset)
			for find: Dictionary in data["finds"]:
				if AquiferDepth.seal_problem(data, str(find["id"])) == "" 						and AquiferDepth.wades_to(data, data["start"], find["cell"]):
					wet.append([depth, find, data])
					break
		if wet.size() == 2:
			day += offset
			break
	if wet.size() != 2:
		gs.free()
		return "No day in 200 had a wading find at both depth 2 and 3 to test with."
	var saved_day: float = GameClock.elapsed_days
	GameClock.elapsed_days = float(day - 1)
	for index: int in 2:
		var entry: Array = wet[index]
		var data: Dictionary = entry[2]
		var find: Dictionary = entry[1]
		_rover_at(gs, entry[0], TunnelRock.at_in(data["grid"], find["cell"]))
		var reply: String = gs.take_find(str(find["id"]), day, HOST)
		if index == 0 and reply != AquiferDepth.wet_pack_reply(true):
			problems.append("The first wading find did not wet the pack: '%s'." % reply)
		if index == 1 and reply != "":
			problems.append("The second wading find, at another depth, wet the pack again: '%s'." % reply)
	if gs.camp_supplies != 2:
		problems.append("%d rations are left; one should have spoiled." % gs.camp_supplies)
	GameClock.elapsed_days = saved_day
	gs.free()
	return "
".join(problems)


# --- Saves ------------------------------------------------------------------------------

## True if a fresh farm takes `data` (and frees itself).
func _loads(data: Dictionary) -> bool:
	var fresh: GameStateScript = _state(1, false, false)
	var ok: bool = fresh.farm_from_dict(data) == ""
	fresh.free()
	return ok


func test_an_old_save_with_depth_one_ids_and_no_deep_keys_loads() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state(1, true, false)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	for key: String in ["lifts_repaired", "deepest_depth", "pools_drained", "valves_shut", "packs_wet"]:
		data.erase(key)
	if not _loads(data):
		problems.append("A save with none of the per-depth keys was refused.")
	data["pools_drained"] = { ZONE: { "day": day, "ids": ["p0"] } }
	data["valves_shut"] = { ZONE: { "day": day, "ids": ["s1"] } }
	data["deepest_depth"] = { ZONE: 1 }
	var old: GameStateScript = _state(1, false, false)
	if old.farm_from_dict(data) != "":
		problems.append("A save with depth 1's plain ids was refused.")
	if AquiferDepth.drained_today(old.pools_drained, day) != ["p0"]:
		problems.append("Depth 1's pool did not load: %s." % [old.pools_drained])
	if AquiferDepth.shut_today(old.valves_shut, day) != ["s1"]:
		problems.append("Depth 1's valve did not load: %s." % [old.valves_shut])
	if not bool(AquiferDepth.pool_in(AquiferDepth.layout(SEED, 1, day, AquiferDepth.drained_today(old.pools_drained, day)), "p0")["drained"]):
		problems.append("Depth 1's p0 is not drained after loading.")
	old.free()
	# New ids load, and ones that are no depth's do not.
	data["pools_drained"] = { ZONE: { "day": day, "ids": ["p0", "d3_p1", "d6_p2"] } }
	data["valves_shut"] = { ZONE: { "day": day, "ids": ["s1", "d3_s1", "d6_s2"] } }
	data["deepest_depth"] = { ZONE: 6 }
	if not _loads(data):
		problems.append("A save with deep pool and valve ids was refused.")
	data["valves_shut"] = {}
	for bad: String in ["d7_p0", "d1_p0", "d2_p9", "p9"]:
		data["pools_drained"] = { ZONE: { "day": day, "ids": [bad] } }
		if _loads(data):
			problems.append("A save with the pool id '%s' was accepted." % bad)
	data["pools_drained"] = {}
	for bad: String in ["d7_s0", "d1_s0", "d2_s9", "s9"]:
		data["valves_shut"] = { ZONE: { "day": day, "ids": [bad] } }
		if _loads(data):
			problems.append("A save with the valve id '%s' was accepted." % bad)
	data["valves_shut"] = {}
	data["deepest_depth"] = { ZONE: 7 }
	if _loads(data):
		problems.append("A save with the Aquifer's deepest depth at 7 was accepted.")
	data["deepest_depth"] = { ZONE: 6 }
	data["lifts_repaired"] = { ZONE: [3, 6] }
	if not _loads(data):
		problems.append("A save with lifts at 3 and 6 was refused.")
	data["lifts_repaired"] = { ZONE: [2] }
	if _loads(data):
		problems.append("A save with a lift at depth 2 was accepted.")
	gs.free()
	return "
".join(problems)


func test_a_deep_rover_loaded_with_the_gate_shut_is_put_back_at_depth_three() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	_rover_at(gs, 6, ZoneDepth.lift_position(6))
	gs.deepest_depth[ZONE] = 6
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if data.get("rover_depth", 0) != 6 or data.get("rover_zone", "") != ZONE:
		problems.append("The save did not hold the rover at depth 6.")
	# Each missing piece of the gate puts the rover back at depth 3's start.
	var edits: Array = [
		["the lab level", func(d: Dictionary) -> void: d["lab_xp"] = 0],
		["the pump", func(d: Dictionary) -> void: d["pump_owned"] = false],
		["the lift at 3", func(d: Dictionary) -> void: d["lifts_repaired"] = {}],
	]
	for entry: Array in edits:
		var shut: Dictionary = data.duplicate(true)
		(entry[1] as Callable).call(shut)
		var low: GameStateScript = _state(1, false, false)
		if low.farm_from_dict(shut) != "":
			problems.append("The save without %s was refused." % entry[0])
		elif low.rover_depth != 3 or low.rover_zone != ZONE:
			problems.append("Without %s the rover was left at depth %d (%s)." % [entry[0], low.rover_depth, low.rover_zone])
		else:
			var at: Vector3 = low.rover_transforms[low.TUNNEL_ROVER].origin
			if at.distance_to(ZoneDepth.start_transform().origin) > 0.5:
				problems.append("Without %s the rover was not at depth 3's start (%s)." % [entry[0], at])
		if low.aquifer_deep_problem() == "":
			problems.append("The gate opened by loading without %s." % entry[0])
		low.free()
	var kept: GameStateScript = _state(1, false, false)
	if kept.farm_from_dict(data) != "" or kept.rover_depth != 6 or kept.rover_zone != ZONE:
		problems.append("The rover was moved though the gate is open (depth %d)." % kept.rover_depth)
	kept.free()
	# A rover at depth 3 or shallower is never moved.
	var shallow: Dictionary = data.duplicate(true)
	shallow["rover_depth"] = 3
	shallow["lab_xp"] = 0
	var stay: GameStateScript = _state(1, false, false)
	if stay.farm_from_dict(shallow) != "" or stay.rover_depth != 3:
		problems.append("A rover at depth 3 was moved.")
	stay.free()
	gs.free()
	return "\n".join(problems)


# --- Finds ------------------------------------------------------------------------------

func test_a_deeper_find_always_pays_more_than_the_same_kind_above_it() -> String:
	var problems: Array[String] = []
	for kind: String in AquiferDepth.KINDS_DEEP:
		var last: int = -1
		for depth: int in range(1, 7):
			var pay: Dictionary = AquiferDepth.reward(kind, depth)
			var total: int = int(pay.get("credits", 0)) + int(pay.get("crystal_ore", 0)) * 50
			if total <= last:
				problems.append("A %s at depth %d pays %d, no more than the depth above." % [kind, depth, total])
			last = total
	for kind: String in AquiferDepth.KINDS:
		if AquiferDepth.reward(kind, 1) != AquiferDepth.REWARDS[kind] or AquiferDepth.reward(kind) != AquiferDepth.REWARDS[kind]:
			problems.append("A %s at depth 1 pays other than it did." % kind)
	if AquiferDepth.reward("case", 4).get("crystal_ore", 0) < 2:
		problems.append("The sealed case pays less than 2 ore.")
	for depth: int in [1, 2, 3]:
		for find: Dictionary in AquiferDepth.layout(SEED, depth, 3)["finds"]:
			if find["kind"] == "case":
				problems.append("A case lies at depth %d." % depth)
	var cases: int = 0
	for day: int in range(1, 30):
		for depth: int in DEEP:
			for find: Dictionary in AquiferDepth.layout(SEED, depth, day)["finds"]:
				if find["kind"] == "case":
					cases += 1
	if cases == 0:
		problems.append("No sealed case in the deep depths over 29 days.")
	return "\n".join(problems)


func test_finds_pay_the_depths_rate_once_each_from_depth_two_to_six() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	var gs: GameStateScript = _state()
	for depth: int in range(1, 7):
		var find: Dictionary = _free_find(depth, day)
		if find.is_empty():
			problems.append("Depth %d has no find without a seal on it today." % depth)
			continue
		var data: Dictionary = AquiferDepth.layout(SEED, depth, day)
		_rover_at(gs, depth, TunnelRock.at_in(data["grid"], find["cell"]))
		var pay: Dictionary = AquiferDepth.reward(str(find["kind"]), depth)
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		var why: String = gs.take_find(str(find["id"]), day, HOST)
		if gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			problems.append("Depth %d's %s paid %d CR and %d ore, not %s (%s)." % [depth, find["kind"], gs.credits - credits, gs.crystal_ore - ore, pay, why])
		credits = gs.credits
		if gs.take_find(str(find["id"]), day, HOST) == "" or gs.credits != credits:
			problems.append("Depth %d's find was taken twice." % depth)
		if not str(find["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("Depth %d's find is not recorded under the Aquifer." % depth)
	if gs.finds_taken.has("lava_tubes"):
		problems.append("An Aquifer find was recorded under the Lava Tubes.")
	gs.free()
	return "\n".join(problems)


func test_a_deep_find_does_not_pay_with_the_gate_shut() -> String:
	var problems: Array[String] = []
	var day: int = _today()
	for broken: String in ["lab", "pump", "lift"]:
		var gs: GameStateScript = _state(GATE_LEVEL - 1 if broken == "lab" else GATE_LEVEL, broken != "pump", broken != "lift")
		var find: Dictionary = _free_find(4, day)
		var data: Dictionary = AquiferDepth.layout(SEED, 4, day)
		_rover_at(gs, 4, TunnelRock.at_in(data["grid"], find["cell"]))
		if gs.take_find(str(find["id"]), day, HOST) == "" or gs.credits != 1000 or gs.crystal_ore != 20:
			problems.append("A deep find paid with %s missing." % broken)
		if not ZoneDepth.taken_today(gs.finds_taken, ZONE, day).is_empty():
			problems.append("A refused deep find was recorded with %s missing." % broken)
		gs.free()
	# Depth 3 is not behind the gate.
	var gs3: GameStateScript = _state(1, false, false)
	var find3: Dictionary = _free_find(3, day)
	var data3: Dictionary = AquiferDepth.layout(SEED, 3, day)
	_rover_at(gs3, 3, TunnelRock.at_in(data3["grid"], find3["cell"]))
	if not _took(gs3.take_find(str(find3["id"]), day, HOST)):
		problems.append("Depth 3's find was refused for a new farm.")
	gs3.free()
	return "\n".join(problems)


# --- The layouts -----------------------------------------------------------------------

## The whole of depth 1's layout (grid, finds with cells and kinds, pools, seals) for three seeds
## on four days, as `str(layout).hash()`. The values were taken from origin/main's
## aquifer_depth.gd before this slice, and match the new code's output: depth 1 is unchanged.
const DEPTH_ONE_HASHES: Dictionary = {
	"424242 1": 968252876, "424242 7": 2667721792, "424242 100": 1341184961, "424242 333": 2501604597,
	"1 1": 3030292956, "1 7": 7265224, "1 100": 2700237243, "1 333": 3313434451,
	"99 1": 1136317712, "99 7": 2123255002, "99 100": 2438048273, "99 333": 2706317371,
}


func test_depth_one_is_as_it_was() -> String:
	var problems: Array[String] = []
	for key: String in DEPTH_ONE_HASHES:
		var parts: PackedStringArray = key.split(" ")
		var data: Dictionary = AquiferDepth.layout(int(parts[0]), 1, int(parts[1]))
		if str(data).hash() != int(DEPTH_ONE_HASHES[key]):
			problems.append("Depth 1's layout for seed %s day %s is not the one main made." % [parts[0], parts[1]])
	for day: int in [1, 7, 100]:
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		for index: int in data["finds"].size():
			if data["finds"][index]["id"] != ZoneDepth.find_id(index, 1):
				problems.append("Depth 1's find ids changed.")
			if not data["finds"][index]["kind"] in AquiferDepth.KINDS:
				problems.append("Depth 1 holds a find of kind %s." % data["finds"][index]["kind"])
		for pool: Dictionary in data["pools"]:
			if not pool["depth_m"] in AquiferDepth.DEEP_M and not pool["depth_m"] in AquiferDepth.SHALLOW_M:
				problems.append("Depth 1 has a pool %s m deep." % pool["depth_m"])
	if AquiferDepth.pool_choices(1).size() != AquiferDepth.DEEP_M.size() + AquiferDepth.SHALLOW_M.size():
		problems.append("Depth 1's pool choices changed.")
	return "
".join(problems.slice(0, 4))


func test_water_is_deeper_and_more_common_going_down() -> String:
	var problems: Array[String] = []
	var last_share: float = -1.0
	var last_deepest: float = 0.0
	for depth: int in range(1, 7):
		var choices: Array[float] = AquiferDepth.pool_choices(depth)
		var deep: int = 0
		var deepest: float = 0.0
		for metres: float in choices:
			if metres >= AquiferDepth.DEEP_M[0]:
				deep += 1
			deepest = maxf(deepest, metres)
		var share: float = float(deep) / float(choices.size())
		if share < last_share or (depth > 1 and share <= last_share):
			problems.append("Depth %d's deep share %.2f is not above the depth before (%.2f)." % [depth, share, last_share])
		if depth > 1 and deepest <= last_deepest:
			problems.append("Depth %d's deepest pool is no deeper than the depth above." % depth)
		last_share = share
		last_deepest = deepest
	return "\n".join(problems)


func test_every_layout_at_every_depth_is_reached_with_the_pools_pumped() -> String:
	var problems: Array[String] = []
	var checked: int = 0
	for seed_value: int in range(1, 25):
		for day: int in range(0, 25):
			for depth: int in range(1, 7):
				var data: Dictionary = AquiferDepth.layout(seed_value * 104729, depth, day, _all_drained())
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
				if data["finds"].size() != AquiferDepth.find_count():
					problems.append("%s: %d finds, not %d." % [where, data["finds"].size(), AquiferDepth.find_count()])
				if problems.size() > 6:
					return "\n".join(problems)
	if checked != 24 * 25 * 6:
		problems.append("Checked %d layouts." % checked)
	return "\n".join(problems)


func test_each_depth_is_its_own_daily_floor() -> String:
	var problems: Array[String] = []
	var grids: Dictionary = {}
	for depth: int in range(1, 7):
		var a: Dictionary = AquiferDepth.layout(SEED, depth, 5)
		var b: Dictionary = AquiferDepth.layout(SEED, depth, 5)
		if a["finds"] != b["finds"] or a["grid"] != b["grid"]:
			problems.append("Depth %d is not the same for the same seed and day." % depth)
		grids[str(a["finds"])] = true
	if grids.size() < 5:
		problems.append("The depths share their finds (%d distinct of 6)." % grids.size())
	return "\n".join(problems)


# --- The look ---------------------------------------------------------------------------

func _lights(node: Node) -> int:
	var n: int = 1 if node is Light3D else 0
	for child: Node in node.get_children():
		n += _lights(child)
	return n


## The scene built at `depth` of today: { "lights": its lights outside the rock, "trunk": the
## energy of its TrunkLamp }.
func _scene_at(depth: int) -> Dictionary:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	GameState.rover_zone = ZONE
	GameState.rover_depth = depth
	GameState.rover_transforms.erase(GameState.TUNNEL_ROVER)
	var scene: Node = (load("res://scenes/flooded_aquifer.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var rock: Node = scene.get_node("WorldView/WorldViewport/World/Rock")
	var trunk: Light3D = scene.find_child("TrunkLamp", true, false) as Light3D
	var out: Dictionary = { "lights": _lights(scene) - _lights(rock), "trunk": trunk.light_energy if trunk != null else -1.0 }
	root.remove_child(scene)
	scene.free()
	return out


func test_each_depth_is_a_little_darker_with_no_new_lights() -> String:
	var problems: Array[String] = []
	if FloodedAquifer.lamp_scale(0) != 1.0 or FloodedAquifer.lamp_scale(1) != 1.0:
		problems.append("The hub or depth 1 lamp is dimmed.")
	var last: float = 1.0
	for depth: int in range(2, 7):
		var scale: float = FloodedAquifer.lamp_scale(depth)
		if scale >= last and last > FloodedAquifer.LAMP_FLOOR:
			problems.append("Depth %d is no darker than the depth above (%.2f)." % [depth, scale])
		if scale < FloodedAquifer.LAMP_FLOOR:
			problems.append("Depth %d is darker than the floor (%.2f)." % [depth, scale])
		last = scale
	# The built scenes: the same lights at every depth, a dimmer trunk lamp below.
	var saved_zone: String = GameState.rover_zone
	var saved_depth: int = GameState.rover_depth
	var saved_transforms: Dictionary = GameState.rover_transforms.duplicate(true)
	var saved_seed: int = GameState.world_seed
	var saved_lent: bool = GameState.rover_lent
	var saved_local: Array = [ZoneDepth.local_zone, ZoneDepth.local_depth, ZoneDepth.local_layout.duplicate(true), ZoneDepth.arrive_at, ZoneDepth.arrive_pending]
	GameState.world_seed = SEED
	GameState.rover_lent = true
	var one: Dictionary = _scene_at(1)
	var previous: float = float(one["trunk"])
	if previous <= 0.0:
		problems.append("Depth 1 has no TrunkLamp.")
	for depth: int in [2, 4, 6]:
		var built: Dictionary = _scene_at(depth)
		if int(built["lights"]) != int(one["lights"]):
			problems.append("Depth %d has %d lights outside the rock, depth 1 has %d." % [depth, built["lights"], one["lights"]])
		if float(built["trunk"]) >= previous:
			problems.append("Depth %d's trunk lamp (%.2f) is no dimmer than the one above (%.2f)." % [depth, built["trunk"], previous])
		previous = float(built["trunk"])
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
	return "
".join(problems)


# --- Nothing new on the wire ------------------------------------------------------------

func test_the_protocol_did_not_move_for_depths_two_to_six() -> String:
	if CoopSession.PROTOCOL != 46:
		return "PROTOCOL is %d; depths 2 to 6 add no command or synced field, so it stays at the current 46." % CoopSession.PROTOCOL
	return ""
