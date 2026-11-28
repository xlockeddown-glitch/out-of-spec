extends RefCounted
## The Flooded Aquifer (docs/design/zones.md section 14, build step 13): its entrance,
## depth 1 from the hash, the water, the pump and the rescue. Every number is a
## [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "flooded_aquifer"


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


func _today() -> int:
	return GameClock.get_day_index()


## The rover (and the host) in the Aquifer at `depth`, at `at`.
func _rover_at(gs: GameStateScript, depth: int, at: Vector3) -> void:
	gs.rover_zone = ZONE
	gs.rover_lent = true
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[HOST] = [ZONE, depth]


func _all_pools() -> Array:
	return AquiferDepth.POOL_IDS.duplicate()


# --- Depth 1 from the hash ---------------------------------------------------------

func test_depth_one_is_the_same_for_the_same_seed_and_day_and_new_the_next_day() -> String:
	var a: Dictionary = AquiferDepth.layout(SEED, 1, 5)
	var b: Dictionary = AquiferDepth.layout(SEED, 1, 5)
	if "|".join(a["grid"]) != "|".join(b["grid"]) or var_to_str(a["finds"]) != var_to_str(b["finds"]) or var_to_str(a["pools"]) != var_to_str(b["pools"]):
		return "The same seed and day made two different floors."
	var changed: int = 0
	for day: int in range(5, 15):
		var next: Dictionary = AquiferDepth.layout(SEED, 1, day + 1)
		var here: Dictionary = AquiferDepth.layout(SEED, 1, day)
		if var_to_str(next["finds"]) != var_to_str(here["finds"]) or var_to_str(next["pools"]) != var_to_str(here["pools"]):
			changed += 1
	if changed < 9:
		return "The floor changed on only %d of 10 days." % changed
	if AquiferDepth.layout(SEED + 1, 1, 5)["finds"] == a["finds"] and AquiferDepth.layout(SEED + 2, 1, 5)["finds"] == a["finds"]:
		return "Another seed made the same floor."
	if not AquiferDepth.layout(SEED, 0, 5).is_empty() or not AquiferDepth.layout(SEED, 7, 5).is_empty():
		return "Depths 1 to 6 exist: there is no depth 0 floor and no depth 7."
	if a["finds"].size() != AquiferDepth.find_count():
		return "The floor has %d finds, not %d." % [a["finds"].size(), AquiferDepth.find_count()]
	return ""


func test_the_finds_and_pools_are_what_the_zone_says() -> String:
	for day: int in range(1, 40):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		for find: Dictionary in data["finds"]:
			if not str(find["kind"]) in AquiferDepth.KINDS:
				return "Day %d: a find of kind %s." % [day, find["kind"]]
		for pool: Dictionary in data["pools"]:
			var shallow: bool = AquiferDepth.is_shallow(pool)
			var deep: bool = AquiferDepth.is_deep(pool)
			if shallow == deep:
				return "Day %d: pool %s is %s m: shallow and deep are exclusive." % [day, pool["id"], pool["depth_m"]]
			if deep != (float(pool["depth_m"]) >= Terrain.WASH_BLOCK_M):
				return "Deep is the PitWater threshold."
	return ""


func test_the_way_up_and_every_find_are_reached_with_the_pools_drained() -> String:
	var problems: Array[String] = []
	for day: int in range(1, 60):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day, _all_pools())
		var seen: Array[Vector2i] = ZoneDepth.reachable(data["grid"], ZoneDepth.START_CELL)
		if not ZoneDepth.UP_CELL in seen:
			problems.append("Day %d: the way up is cut off with the pools drained." % day)
		for find: Dictionary in data["finds"]:
			if not find["cell"] in seen:
				problems.append("Day %d: %s is out of reach with the pools drained." % [day, find["id"]])
		var full: Dictionary = AquiferDepth.layout(SEED, 1, day)
		if not ZoneDepth.UP_CELL in ZoneDepth.reachable(full["grid"], ZoneDepth.START_CELL):
			problems.append("Day %d: the way up is cut off with the pools full." % day)
	return "\n".join(problems.slice(0, 6))


func test_at_least_one_find_waits_past_deep_water() -> String:
	for day: int in range(1, 40):
		var full: Dictionary = AquiferDepth.layout(SEED, 1, day)
		var seen: Array[Vector2i] = ZoneDepth.reachable(full["grid"], ZoneDepth.START_CELL)
		var cut: int = 0
		for find: Dictionary in full["finds"]:
			if not find["cell"] in seen:
				cut += 1
		if cut == 0:
			return "Day %d: every find can be reached through the water." % day
	return ""


# --- The water ---------------------------------------------------------------------

func test_deep_water_stops_the_rover_and_a_drained_pool_does_not() -> String:
	var full: Dictionary = AquiferDepth.layout(SEED, 1, 3)
	var dry: Dictionary = AquiferDepth.layout(SEED, 1, 3, _all_pools())
	var deep: Dictionary = AquiferDepth.pool_in(full, "p0")
	if not AquiferDepth.is_deep(deep):
		return "Pool p0 is always a deep pool."
	var cell: Vector2i = (deep["rect"] as Rect2i).position
	if full["grid"][cell.y][cell.x] != "w" or dry["grid"][cell.y][cell.x] != ".":
		return "A deep pool is water (w) until it is pumped dry."
	# The rover's own rule (the host's hold): deep water does not hold it, drained floor does.
	var middle: Vector3 = TunnelRock.at_in(full["grid"], cell)
	if TunnelRock.holds_in(full["grid"], middle) or not TunnelRock.holds_in(dry["grid"], middle):
		return "Deep water must stop the rover and a drained pool must hold it."
	var stand: int = 0
	for pool: Dictionary in full["pools"]:
		var rect: Rect2i = pool["rect"]
		var tile: String = full["grid"][rect.position.y][rect.position.x]
		if AquiferDepth.is_deep(pool) and tile != "w":
			return "Deep pool %s is not water." % pool["id"]
		if AquiferDepth.is_shallow(pool) and tile == "w":
			return "A shallow pool must be wadable, not a wall."
		if AquiferDepth.is_shallow(pool):
			stand += 1
	return ""


func test_shallow_water_slows_the_rover_only_where_it_stands() -> String:
	var held_zone: String = ZoneDepth.local_zone
	var held_layout: Dictionary = ZoneDepth.local_layout
	var problems: Array[String] = []
	for day: int in range(1, 60):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		for pool: Dictionary in data["pools"]:
			if not AquiferDepth.is_shallow(pool):
				continue
			ZoneDepth.local_zone = ZONE
			ZoneDepth.local_layout = data
			var box: Rect2 = AquiferDepth.pool_metres(pool)
			if not AquiferDepth.wading_at(box.get_center()):
				problems.append("Day %d: no wading in a shallow pool." % day)
			if AquiferDepth.wading_at(box.end + Vector2(9.0, 9.0)):
				problems.append("Day %d: wading far from the pool." % day)
			var drained: Dictionary = AquiferDepth.layout(SEED, 1, day, [pool["id"]])
			ZoneDepth.local_layout = drained
			if AquiferDepth.wading_at(box.get_center()):
				problems.append("Day %d: wading in a drained pool." % day)
			ZoneDepth.local_zone = ZoneDepth.ZONE
			if AquiferDepth.wading_at(box.get_center()):
				problems.append("Day %d: the Lava Tubes' screen waded." % day)
			ZoneDepth.local_zone = held_zone
			ZoneDepth.local_layout = held_layout
			return "\n".join(problems)
	ZoneDepth.local_zone = held_zone
	ZoneDepth.local_layout = held_layout
	return "No shallow pool in 59 days."


## A day with a find the rover can reach from the middle of the deep pool p0 (4.0 m
## and the host's slack): the host's water rule decides it, as the rover can't be there.
func _find_beside_p0() -> Array:
	for day: int in range(1, 3000):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		var centre: Vector2 = AquiferDepth.pool_metres(AquiferDepth.pool_in(data, "p0")).get_center()
		for find: Dictionary in data["finds"]:
			var at: Vector3 = TunnelRock.at_in(data["grid"], find["cell"])
			if Vector2(at.x, at.z).distance_to(centre) <= ZoneDepth.REACH_M + ZoneDepth.HOST_REACH_SLACK_M - 0.2:
				return [day, find["id"], centre]
	return []


func test_the_host_refuses_a_find_across_deep_water_and_a_drained_pool_lets_it_through() -> String:
	var spot: Array = _find_beside_p0()
	if spot.is_empty():
		return "No day in 3000 puts a find within reach of pool p0."
	var day: int = spot[0]
	var centre: Vector2 = spot[2]
	var problems: Array[String] = []
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 1, Vector3(centre.x, 0.0, centre.y))
		var refused: String = gs.take_find(spot[1], day, HOST)
		if refused == "" or not refused.contains("water"):
			problems.append("A find across deep water was taken or refused for another reason: '%s'." % refused)
		if ZoneDepth.taken_today(gs.finds_taken, ZONE, day).size() != 0:
			problems.append("A refused find was recorded.")
		gs.pools_drained = ZoneDepth.with_taken(gs.pools_drained, ZONE, day, "p0")
		var allowed: String = gs.take_find(spot[1], day, HOST)
		if allowed != "":
			problems.append("The drained pool still blocked the find: '%s'." % allowed)
		if not spot[1] in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("The find was not recorded as taken in the Aquifer.")
		if gs.take_find(spot[1], day, HOST) == "":
			problems.append("A find was taken twice.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_a_find_pays_the_aquifers_reward_and_the_lava_tubes_finds_are_not_taken_here() -> String:
	var spot: Array = _find_beside_p0()
	if spot.is_empty():
		return "No day puts a find within reach of pool p0."
	var day: int = spot[0]
	var centre: Vector2 = spot[2]
	var out: String = ""
	_at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 1, Vector3(centre.x, 0.0, centre.y))
		gs.pools_drained = ZoneDepth.with_taken(gs.pools_drained, ZONE, day, "p0")
		var find: Dictionary = ZoneDepth.find_in(AquiferDepth.layout(SEED, 1, day, ["p0"]), spot[1])
		var pay: Dictionary = AquiferDepth.reward(str(find["kind"]))
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		if gs.take_find(spot[1], day, HOST) != "":
			out = "The find was refused."
		elif gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			out = "The reward is not the Aquifer's: %s" % [pay]
		elif gs.finds_taken.has("lava_tubes"):
			out = "A find of the Aquifer was written under the Lava Tubes."
		gs.free()
		return "")
	return out


# --- The pump ----------------------------------------------------------------------

func _at_crate(gs: GameStateScript) -> void:
	_rover_at(gs, 0, AquiferDepth.crate_position())


func test_the_pump_is_bought_once_from_the_shared_wallet() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = 500
		_at_crate(gs)
		var heard: Array[int] = [0]
		gs.pump_changed.connect(func() -> void: heard[0] += 1)
		if gs.buy_pump(HOST) != "":
			problems.append("The pump was refused with 500 CR at the crate.")
		if gs.credits != 500 - AquiferDepth.PUMP_COST_CREDITS or not gs.pump_owned or heard[0] != 1:
			problems.append("Buying must charge %d CR once and tell the screens: %d CR, owned %s, told %d." % [AquiferDepth.PUMP_COST_CREDITS, gs.credits, gs.pump_owned, heard[0]])
		var before: int = gs.credits
		if gs.buy_pump(HOST) == "" or gs.credits != before:
			problems.append("A second pump was sold.")
		gs.free()
		var poor: GameStateScript = _state()
		poor.credits = AquiferDepth.PUMP_COST_CREDITS - 1
		_at_crate(poor)
		if poor.buy_pump(HOST) == "" or poor.pump_owned or poor.credits != AquiferDepth.PUMP_COST_CREDITS - 1:
			problems.append("A short wallet bought the pump.")
		poor.free()
		var far: GameStateScript = _state()
		far.credits = 500
		_rover_at(far, 0, AquiferDepth.crate_position() + Vector3(30.0, 0.0, 0.0))
		if far.buy_pump(HOST) == "" or far.pump_owned:
			problems.append("The pump was bought from across the hub.")
		far.free()
		var below: GameStateScript = _state()
		below.credits = 500
		_rover_at(below, 1, AquiferDepth.crate_position())
		if below.buy_pump(HOST) == "":
			problems.append("The pump was bought below the hub.")
		below.free()
		var elsewhere: GameStateScript = _state()
		elsewhere.credits = 500
		if elsewhere.buy_pump(HOST) == "":
			problems.append("The pump was bought with the rover on the farm.")
		elsewhere.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_pumping_drains_that_pool_for_today_only() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		var centre: Vector2 = AquiferDepth.pool_metres(AquiferDepth.pool_in(data, "p0")).get_center()
		_rover_at(gs, 1, Vector3(centre.x, 0.0, centre.y))
		if gs.use_pump("p0", day, HOST) == "":
			problems.append("The farm drained a pool without a pump.")
		gs.pump_owned = true
		if gs.use_pump("p0", day - 1, HOST) == "":
			problems.append("A pump on yesterday's floor worked.")
		if gs.use_pump("p9", day, HOST) == "":
			problems.append("A pool that is not there was pumped.")
		var heard: Array[int] = [0]
		gs.pump_changed.connect(func() -> void: heard[0] += 1)
		if gs.use_pump("p0", day, HOST) != "":
			problems.append("The pump was refused at p0.")
		if AquiferDepth.drained_today(gs.pools_drained, day) != ["p0"] or heard[0] != 1:
			problems.append("p0 is not drained: %s, told %d." % [AquiferDepth.drained_today(gs.pools_drained, day), heard[0]])
		if gs.use_pump("p0", day, HOST) == "":
			problems.append("A drained pool was pumped again.")
		if not AquiferDepth.drained_today(gs.pools_drained, day + 1).is_empty():
			problems.append("The pool is still drained tomorrow.")
		# Only that pool: p1 stays as it was.
		if "p1" in AquiferDepth.drained_today(gs.pools_drained, day):
			problems.append("Another pool was drained too.")
		# The pump needs the rover near the pool and below the hub.
		var far: GameStateScript = _state()
		far.pump_owned = true
		_rover_at(far, 1, Vector3(centre.x + 40.0, 0.0, centre.y))
		if far.use_pump("p0", day, HOST) == "":
			problems.append("A pool was pumped from far away.")
		far.free()
		var hub: GameStateScript = _state()
		hub.pump_owned = true
		_rover_at(hub, 0, Vector3(centre.x, 0.0, centre.y))
		if hub.use_pump("p0", day, HOST) == "":
			problems.append("The hub's rover pumped a depth 1 pool.")
		hub.free()
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_a_guest_sees_the_pump_and_the_drained_pools() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var held_guest: bool = FarmCommands.guest
	var run: String = _at(float(day - 1), func() -> String:
		var host: GameStateScript = _state()
		var guest: GameStateScript = _state()
		host.pump_owned = true
		host.pools_drained = ZoneDepth.with_taken(host.pools_drained, ZONE, day, "p2")
		FarmCommands.guest = true
		guest.local_player_id = GUEST
		var joined: String = FarmSync.join(FarmSync.capture(host), guest)
		if joined != "":
			problems.append("The join was refused: %s" % joined)
		if not guest.pump_owned or AquiferDepth.drained_today(guest.pools_drained, day) != ["p2"]:
			problems.append("A joining guest does not see the pump and the drained pool.")
		FarmCommands.guest = false
		host.pools_drained = ZoneDepth.with_taken(host.pools_drained, ZONE, day, "p0")
		var heard: Array[int] = [0]
		guest.pump_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var updated: String = FarmSync.update(FarmSync.capture(host), guest)
		FarmCommands.guest = false
		if updated != "":
			problems.append("The update was refused: %s" % updated)
		if AquiferDepth.drained_today(guest.pools_drained, day).size() != 2 or heard[0] < 1:
			problems.append("The guest was not told a pool was drained (told %d)." % heard[0])
		host.free()
		guest.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


func test_the_pump_and_drained_pools_are_saved_and_checked() -> String:
	var problems: Array[String] = []
	var day: int = 4
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		gs.pump_owned = true
		gs.pools_drained = ZoneDepth.with_taken(gs.pools_drained, ZONE, day, "p1")
		var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var back: GameStateScript = _state()
		if back.farm_from_dict(data) != "":
			problems.append("The saved farm was refused.")
		if not back.pump_owned or AquiferDepth.drained_today(back.pools_drained, day) != ["p1"]:
			problems.append("The pump and the drained pool did not survive a save.")
		# Yesterday's drained pools are not carried into tomorrow's save.
		var later: Dictionary = bytes_to_var(var_to_bytes(data))
		(later["pools_drained"][ZONE] as Dictionary)["day"] = day - 2
		var past: GameStateScript = _state()
		if past.farm_from_dict(later) != "" or not past.pools_drained.is_empty():
			problems.append("A past day's drained pools were kept: %s" % [past.pools_drained])
		past.free()
		# Bad data is refused.
		for bad: Variant in [3, { "lava_tubes": { "day": day, "ids": ["p0"] } }, { ZONE: { "day": day, "ids": ["p0", "p0"] } },
				{ ZONE: { "day": day, "ids": ["p7"] } }, { ZONE: { "day": -1, "ids": [] } }, { ZONE: { "ids": [] } }]:
			var junk: Dictionary = gs.farm_to_dict()
			junk["pools_drained"] = bad
			if gs.farm_dict_problem(junk) == "":
				problems.append("A bad pools_drained was accepted: %s" % [bad])
		var junk_owned: Dictionary = gs.farm_to_dict()
		junk_owned["pump_owned"] = "yes"
		if gs.farm_dict_problem(junk_owned) == "":
			problems.append("A bad pump_owned was accepted.")
		# An old save has neither: no pump, nothing drained.
		var old: Dictionary = gs.farm_to_dict()
		old.erase("pump_owned")
		old.erase("pools_drained")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or fresh.pump_owned or not fresh.pools_drained.is_empty():
			problems.append("A save from before the Aquifer did not load as no pump.")
		fresh.free()
		gs.free()
		back.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_pump_commands_are_on_the_list_and_the_protocol_moved() -> String:
	for action: StringName in [&"buy_pump", &"use_pump", &"move_rover_aquifer"]:
		if not action in FarmCommands.ACTIONS:
			return "%s is not a command." % action
	if CoopSession.PROTOCOL != 47:
		return "The protocol is %d, not 47." % CoopSession.PROTOCOL
	var gs: GameStateScript = _state()
	gs.credits = 500
	_at_crate(gs)
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var bought: Variant = ""
	_at(10.5, func() -> String:
		bought = commands.execute(HOST, &"buy_pump", [])
		return "")
	var wrong: Variant = commands.execute(HOST, &"use_pump", [3, "x"])
	commands.free()
	var owned: bool = gs.pump_owned
	gs.free()
	if bought != "" or not owned:
		return "The commander refused the pump: %s" % [bought]
	return "" if wrong != "" else "A number for a pool id was accepted."


# --- The entrance ------------------------------------------------------------------

func test_under_lab_level_eight_the_sinkhole_warns() -> String:
	if ZoneData.warning_text(&"flooded_aquifer", 3) == "":
		return "Lab level 3 got no warning at the sinkhole."
	if ZoneData.warning_text(&"flooded_aquifer", 7) == "":
		return "Lab level 7 got no warning at the sinkhole."
	if ZoneData.warning_text(&"flooded_aquifer", 8) != "":
		return "Lab level 8 is in the band: no warning."
	return ""


func test_the_sinkhole_takes_the_rover_in_and_is_saved() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.AQUIFER_PAD)
		var tunnels_pad: GameStateScript = _state()
		tunnels_pad.rover_transforms[tunnels_pad.ROVER] = Transform3D(Basis.IDENTITY, GameState.TUNNEL_PAD)
		if tunnels_pad.move_rover_aquifer(true, HOST) == "":
			problems.append("The Aquifer's sinkhole took a rover from the tunnel mouth.")
		tunnels_pad.free()
		if gs.move_rover_aquifer(true, HOST) != "":
			problems.append("The rover was refused at the sinkhole.")
		if gs.rover_zone != ZONE or not gs.rover_lent or gs.rover_depth != 0 or not gs.zones_unlocked.has(ZONE):
			problems.append("The rover is not in the Aquifer, lent, at the hub, with the zone opened: %s" % gs.rover_zone)
		if gs.place_of(HOST) != ZONE:
			problems.append("The player is not recorded in the Aquifer: %s" % gs.place_of(HOST))
		var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		if data["rover_zone"] != ZONE:
			problems.append("rover_zone is not saved: %s" % data["rover_zone"])
		var back: GameStateScript = _state()
		if back.farm_from_dict(data) != "" or back.rover_zone != ZONE or not back.zones_unlocked.has(ZONE):
			problems.append("The saved farm did not come back in the Aquifer.")
		back.free()
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, GameState.TUNNEL_EXIT)
		if gs.move_rover(false, HOST) != "":
			problems.append("The way home from the Aquifer was refused: %s" % gs.move_rover(false, HOST))
		if gs.rover_zone != "" or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The rover did not come out: %s" % gs.rover_zone)
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_aquifer_is_a_fast_travel_choice_once_it_has_been_visited() -> String:
	var before: Array[Dictionary] = FastTravel.destinations(8, [])
	var after: Array[Dictionary] = FastTravel.destinations(8, [ZONE])
	for row: Dictionary in before:
		if row["id"] == ZONE:
			return "The Aquifer is listed before the first visit."
	for row: Dictionary in after:
		if row["id"] == ZONE:
			return ""
	return "The Aquifer is not listed after the first visit."


func test_old_saves_with_the_lava_tubes_still_work() -> String:
	var gs: GameStateScript = _state()
	var old: Dictionary = gs.farm_to_dict()
	old.erase("rover_zone")
	old.erase("rover_lent")
	old["rover_in_tunnels"] = true
	var back: GameStateScript = _state()
	var problem: String = back.farm_from_dict(old)
	var zone: String = back.rover_zone
	gs.free()
	back.free()
	if problem != "" or zone != "lava_tubes":
		return "A save from before zones: '%s', zone '%s'." % [problem, zone]
	var tubes: GameStateScript = _state()
	var data: Dictionary = tubes.farm_to_dict()
	data["rover_zone"] = "lava_tubes"
	var again: GameStateScript = _state()
	var loaded: String = again.farm_from_dict(data)
	var kept: String = again.rover_zone
	tubes.free()
	again.free()
	return "" if loaded == "" and kept == "lava_tubes" else "A Lava Tubes save did not load: '%s' '%s'." % [loaded, kept]


# --- The rescue ---------------------------------------------------------------------

func test_the_two_oclock_rescue_brings_a_player_home_from_the_aquifer() -> String:
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
			problems.append("The 02:00 rescue did not run in the Aquifer (rescued day %d)." % gs._recall_rescued_day)
		if gs.credits != 450:
			problems.append("The rescue costs 50 CR as in the tunnels: %d CR left." % gs.credits)
		if gs.rover_zone != "" or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The player and the rover are not home: zone '%s'." % gs.rover_zone)
		var home: Vector3 = (gs.rover_transforms[gs.ROVER] as Transform3D).origin
		if home.distance_to(GameState.AQUIFER_PAD) > GameState.TUNNEL_PAD_REACH_M:
			problems.append("The rover came home to %s, not the sinkhole." % [home])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_midnight_warning_covers_the_aquifer_once() -> String:
	var gs: GameStateScript = _state()
	_rover_at(gs, 0, AquiferDepth.hatch_position())
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


func test_zone_presence_accepts_depths_to_six_in_the_aquifer() -> String:
	for depth: int in [0, 1, 2, 3, 4, 5, 6]:
		if ZonePresence.place_problem(ZONE, depth) != "":
			return "Depth %d in the Aquifer was refused: %s" % [depth, ZonePresence.place_problem(ZONE, depth)]
	if ZonePresence.place_problem(ZONE, 7) == "":
		return "Depth 7 in the Aquifer was accepted: there is none."
	return ""


# --- The hatch and the lift ---------------------------------------------------------

func test_the_hatch_takes_the_rover_down_and_back_up() -> String:
	var problems: Array[String] = []
	var run: String = _at(10.5, func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 0, AquiferDepth.hatch_position())
		var why: String = gs.change_depth(1, HOST)
		if why != "" or gs.rover_depth != 1:
			problems.append("The hatch must take the rover down: '%s', depth %d." % [why, gs.rover_depth])
		gs.player_places[HOST] = [ZONE, 1]
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.ascent_position())
		if gs.change_depth(2, HOST) == "" or gs.rover_depth != 1:
			problems.append("Depth 2 is down the trunk hatch, not from the way up.")
		why = gs.change_depth(0, HOST)
		if why != "" or gs.rover_depth != 0:
			problems.append("The way up must bring the rover back: '%s', depth %d." % [why, gs.rover_depth])
		var back: Vector3 = (gs.rover_transforms[gs.TUNNEL_ROVER] as Transform3D).origin
		if Vector2(back.x - AquiferDepth.hatch_position().x, back.z - AquiferDepth.hatch_position().z).length() > TunnelRock.CELL_M * 1.5:
			problems.append("The rover must come up beside the hatch.")
		gs.free()
		var far: GameStateScript = _state()
		_rover_at(far, 0, AquiferDepth.hatch_position() + Vector3(30.0, 0.0, 0.0))
		if far.change_depth(1, HOST) == "" or far.rover_depth != 0:
			problems.append("The hatch worked from across the hub.")
		far.free()
		return "")
	return run if run != "" else "
".join(problems)


func test_the_lava_lift_is_refused_in_the_aquifer() -> String:
	var gs: GameStateScript = _state()
	_rover_at(gs, 0, AquiferDepth.hatch_position())
	for depth: int in ZoneDepth.lift_depths():
		gs.lifts_repaired[gs.TUNNELS_ZONE] = [depth]
		if gs.use_lift(depth, HOST) == "" or gs.rover_depth != 0:
			gs.free()
			return "The Lava Tubes' lift must not run from the Aquifer."
	gs.free()
	return ""
