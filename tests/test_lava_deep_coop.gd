extends "res://tests/coop_net.gd"
## The deep Lava Tubes (depths 4 to 6) in co-op: a guest's commands go through the same
## gate and checks as the host's, and a guest who joins late is told the deep state.
## Real sessions on this machine where a connection matters.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const SyncScript: GDScript = preload("res://scripts/autoload/CoopSync.gd")

const ZONE: String = "lava_tubes"
const SEED: int = 424242


func _today() -> int:
	return GameClock.get_day_index()


## A farm at lab level `level` whose depth 3 lift is mended, as the host's own state.
func _fresh(gs: GameStateScript, level: int = 10, lift3: bool = true) -> void:
	gs.set_world_seed(SEED)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 3.0))
	gs.zones_unlocked.append(ZONE)
	gs.lab_xp = gs.xp_for_level(level)
	gs.credits = 1000
	gs.crystal_ore = 20
	if lift3:
		gs.lifts_repaired = {ZONE: [3]}


func _below(gs: GameStateScript, depth: int, at: Vector3) -> void:
	gs.rover_zone = ZONE
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)


func _commands(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


func _farm_host() -> Array:
	var host: Node = _host()
	var gs: GameStateScript = host.commands.state
	_fresh(gs)
	gs.local_player_id = "player_1"
	var rovers: Node = RoversScript.new()
	rovers.start(host, gs)
	host.player_left.connect(gs.forget_place)
	return [host, gs, rovers]


func _guest_id(host: Node) -> String:
	for who: Variant in host.players:
		if who != host.commands.state.local_player_id:
			return str(who)
	return ""


# --- A guest's commands, checked against the guest's own place ---------------------

func test_a_guest_below_depth_three_is_held_to_the_gate_the_lift_and_their_own_depth() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	_fresh(gs, 9)
	gs.local_player_id = "player_1"
	var commands: Node = _commands(gs)
	var day: int = _today()
	var problems: Array[String] = []
	# The rover is at depth 3's hatch; the guest is with it. The lab level is 9.
	_below(gs, 3, ZoneDepth.descent_position(3))
	gs.player_places["player_1"] = [ZONE, 3]
	gs.player_places["player_2"] = [ZONE, 3]
	gs.player_places["player_3"] = [ZonePresence.FARM, 0]
	if commands.execute("player_2", &"change_depth", [4]) == "" or gs.rover_depth != 3:
		problems.append("A guest took the rover below depth 3 with the gate shut")
	gs.lab_xp = gs.xp_for_level(10)
	if commands.execute("player_3", &"change_depth", [4]) == "" or gs.rover_depth != 3:
		problems.append("A guest on the farm moved the rover")
	if commands.execute("player_2", &"change_depth", [4]) != "" or gs.rover_depth != 4:
		problems.append("A guest could not take the rover down with the gate open")
	# Between the deep depths, the gate is asked again.
	gs.player_places["player_1"] = [ZONE, 4]
	gs.player_places["player_2"] = [ZONE, 4]
	_below(gs, 4, ZoneDepth.descent_position(4))
	gs.lab_xp = gs.xp_for_level(9)
	if commands.execute("player_2", &"change_depth", [5]) == "" or gs.rover_depth != 4:
		problems.append("A guest went from 4 to 5 with the gate shut")
	# Finds: the guest at another depth than the rover takes nothing; at the rover's, with the gate shut, nothing.
	var data: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 4, day)
	var find: Dictionary = data["finds"][0]
	_below(gs, 4, TunnelRock.at_in(data["grid"], find["cell"]))
	gs.player_places["player_2"] = [ZONE, 5]
	gs.lab_xp = gs.xp_for_level(10)
	var credits: int = gs.credits
	if commands.execute("player_2", &"take_find", [str(find["id"]), day]) == "":
		problems.append("A guest at another depth took a deep find")
	gs.player_places["player_2"] = [ZONE, 4]
	gs.lab_xp = gs.xp_for_level(9)
	if commands.execute("player_2", &"take_find", [str(find["id"]), day]) == "" or gs.credits != credits:
		problems.append("A guest took a deep find with the gate shut")
	gs.lab_xp = gs.xp_for_level(10)
	if commands.execute("player_2", &"take_find", [str(find["id"]), day]) != "" or gs.credits <= credits:
		problems.append("A guest could not take a deep find with the gate open")
	if commands.execute("player_2", &"take_find", [str(find["id"]), day]) == "":
		problems.append("A deep find was taken twice")
	commands.free()
	gs.free()
	return "\n".join(problems)


func test_a_guest_repairs_the_lift_at_six_and_rides_it() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	_fresh(gs, 10)
	gs.local_player_id = "player_1"
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	_below(gs, 6, ZoneDepth.lift_position(6))
	gs.player_places["player_1"] = [ZONE, 6]
	gs.player_places["player_2"] = [ZONE, 5]
	gs.player_places["player_3"] = [ZonePresence.DOME, 0]
	var credits: int = gs.credits
	for who: String in ["player_2", "player_3"]:
		if commands.execute(who, &"repair_lift", []) == "" or gs.is_lift_repaired(ZONE, 6) or gs.credits != credits:
			problems.append("%s repaired the lift at 6 from where they are not" % who)
	gs.player_places["player_2"] = [ZONE, 6]
	if commands.execute("player_2", &"use_lift", [0]) == "" or gs.rover_depth != 6:
		problems.append("A broken lift carried the rover")
	if commands.execute("player_2", &"repair_lift", []) != "" or not gs.is_lift_repaired(ZONE, 6):
		problems.append("A guest at depth 6 could not repair the lift")
	var cost: Vector2i = ZoneDepth.lift_cost(6)
	if gs.credits != credits - cost.x or gs.crystal_ore != 20 - cost.y:
		problems.append("The repair cost %d CR and %d ore" % [credits - gs.credits, 20 - gs.crystal_ore])
	if commands.execute("player_2", &"repair_lift", []) == "" or gs.credits != credits - cost.x:
		problems.append("The repair was charged twice")
	if commands.execute("player_2", &"use_lift", [0]) != "" or gs.rover_depth != 0:
		problems.append("The mended lift did not go up")
	gs.player_places["player_2"] = [ZONE, 0]
	gs.player_places["player_1"] = [ZONE, 0]
	_below(gs, 0, ZoneDepth.lift_position(0))
	gs.lab_xp = gs.xp_for_level(9)
	if commands.execute("player_2", &"use_lift", [6]) == "" or gs.rover_depth != 0:
		problems.append("The hub's lift went to 6 with the gate shut")
	gs.lab_xp = gs.xp_for_level(10)
	if commands.execute("player_2", &"use_lift", [6]) != "" or gs.rover_depth != 6:
		problems.append("The hub's lift did not go to 6 with the gate open")
	commands.free()
	gs.free()
	return "\n".join(problems)


## Over a real connection: the guest's own request, answered by the host.
func test_a_guest_over_the_wire_cannot_take_the_rover_deep_with_the_gate_shut() -> String:
	var all: Array = _farm_host()
	var host: Node = all[0]
	var gs: GameStateScript = all[1]
	var rovers: Node = all[2]
	var guest: Node = _guest(host)
	var gid: String = _guest_id(host)
	gs.lab_xp = gs.xp_for_level(9)
	_below(gs, 3, ZoneDepth.descent_position(3))
	gs.player_places["player_1"] = [ZONE, 3]
	gs.player_places[gid] = [ZONE, 3]
	var shut: Array = _request(guest, &"change_depth", [4])
	_until(func() -> bool: return not shut.is_empty())
	var problems: Array[String] = []
	if shut.is_empty() or shut[0] == "" or gs.rover_depth != 3:
		problems.append("A guest over the wire went down with the gate shut (%s)" % [shut])
	gs.lab_xp = gs.xp_for_level(10)
	var open: Array = _request(guest, &"change_depth", [4])
	_until(func() -> bool: return not open.is_empty())
	if open.is_empty() or open[0] != "" or gs.rover_depth != 4:
		problems.append("A guest over the wire could not go down with the gate open (%s)" % [open])
	rovers.free()
	return _finish("\n".join(problems))


# --- A guest joins late ---------------------------------------------------------

func _join_late(setup: Callable, body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var ready: Array[bool] = [false]
	var host: Node = _host()
	var gs: GameStateScript = host.commands.state
	_fresh(gs)
	gs.local_player_id = "player_1"
	var host_sync: Node = SyncScript.new()
	host_sync.start(host, gs)
	setup.call(gs)
	FarmCommands.guest = true  # host and guest share this process
	var guest: Node = _session()
	var guest_sync: Node = SyncScript.new()
	guest_sync.start(guest, guest.commands.state)
	guest_sync.farm_ready.connect(func() -> void: ready[0] = true)
	guest.join(LOCAL, host.port())
	var problem: String = "The farm did not come to the newcomer"
	if _until(func() -> bool: return ready[0]):
		problem = body.call(host, guest)
	problem = _finish(problem)
	host_sync.free()
	guest_sync.free()
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	return problem


func test_a_late_guest_is_told_the_deep_state() -> String:
	var setup: Callable = func(gs: GameStateScript) -> void:
		gs.lifts_repaired = {ZONE: [3, 6]}
		gs.deepest_depth = {ZONE: 6}
		gs.rover_in_tunnels = true
		gs.rover_depth = 6
		gs.rover_epoch = 3
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.lift_position(6))
		gs.player_places["player_1"] = [ZONE, 6]
	return _join_late(setup, func(_host: Node, guest: Node) -> String:
		var theirs: GameStateScript = guest.commands.state
		var problems: Array[String] = []
		if not theirs.is_lift_repaired(ZONE, 3) or not theirs.is_lift_repaired(ZONE, 6):
			problems.append("The newcomer was not told both lifts are repaired (%s)" % [theirs.lifts_repaired])
		if theirs.deepest_depth.get(ZONE, 0) != 6:
			problems.append("The newcomer was not told the deepest depth is 6")
		if theirs.rover_zone != ZONE or theirs.rover_depth != 6:
			problems.append("The newcomer was not told the rover is at depth 6 (%s, %d)" % [theirs.rover_zone, theirs.rover_depth])
		if theirs.place_of("player_1") != ZONE or theirs.depth_of("player_1") != 6:
			problems.append("The newcomer was not told the host is at depth 6")
		if theirs.lab_gate_open(ZoneDepth.DEEP_GATE) != true or theirs.lava_deep_problem() != "":
			problems.append("The newcomer's gate is not the host's (%s)" % theirs.lava_deep_problem())
		return "\n".join(problems))
