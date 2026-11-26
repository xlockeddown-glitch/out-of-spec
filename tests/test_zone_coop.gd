extends "res://tests/coop_net.gd"
## Zones, co-op hardening (docs/design/zones.md section 13, build step 10): players
## in different places and depths at once, a guest who joins late, and a guest who
## drops mid-trip. Real sessions on this machine where a connection matters.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const SyncScript: GDScript = preload("res://scripts/autoload/CoopSync.gd")
const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")

const ZONE: String = "lava_tubes"
const HOME: Vector3 = Vector3(3.0, 0.0, 3.0)
const SEED: int = 424242


## Rovers where a guest is on the farm.
class _TogetherRovers:
	extends "res://scripts/autoload/CoopRovers.gd"

	func together() -> bool:
		return true


func _today() -> int:
	return GameClock.get_day_index()


func _fresh(gs: GameStateScript) -> void:
	gs.set_world_seed(SEED)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, HOME)
	gs.zones_unlocked.append(ZONE)
	gs.credits = 500
	gs.crystal_ore = 10


func _layout() -> Dictionary:
	return ZoneDepth.layout(SEED, ZoneDepth.ZONE, ZoneDepth.DEPTH, _today())


func _find() -> Dictionary:
	return (_layout()["finds"] as Array)[0]


func _find_at() -> Vector3:
	return TunnelRock.at_in(_layout()["grid"], _find()["cell"])


func _commands(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


## A host session in its own state, with the pieces the zone paths lean on, wired as
## CoopScenes wires them: a place is forgotten when its player leaves.
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


# --- A guest drops: the rover is not stranded -----------------------------------

func test_the_last_one_below_dropping_brings_the_lent_rover_home() -> String:
	var all: Array = _farm_host()
	var host: Node = all[0]
	var gs: GameStateScript = all[1]
	var rovers: Node = all[2]
	var guest: Node = _guest(host)
	var gid: String = _guest_id(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = 0.5
	# The host is on the farm, in bed; the guest took the farm's rover down to depth 2
	# and is driving it, and a vent has hurt it.
	gs.rover_in_tunnels = true
	gs.rover_depth = 2
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(2))
	gs.zone_heat_trip = true
	gs.player_places[gs.local_player_id] = [ZonePresence.FARM, 0]
	gs.player_places[gid] = [ZONE, 2]
	rovers._drivers[gs.TUNNEL_ROVER] = [gid, 1 << 60]
	beds.go_to_bed(gs.local_player_id)
	var waited: bool = clock.elapsed_days == 0.5 and gs.rover_zone == ZONE
	guest.leave()
	_until(func() -> bool: return host.players.size() == 1)
	var problems: Array[String] = []
	if not waited:
		problems.append("Set up wrong: the day did not wait for the guest below")
	if gs.rover_zone != "" or gs.rover_in_tunnels or gs.rover_lent:
		problems.append("The rover is still out in the tunnels after the last one below dropped")
	if gs.rover_transforms.has(gs.TUNNEL_ROVER) or not gs.rover_transforms.has(gs.ROVER):
		problems.append("The farm's rover is not parked on the farm")
	if gs.zone_heat_trip:
		problems.append("The heat trip outlived the trip")
	if gs.player_places.has(gid):
		problems.append("The host still holds the dropped guest's place")
	if rovers.driver(gs.TUNNEL_ROVER) != "":
		problems.append("A ghost still holds the drive lease")
	if clock.elapsed_days == 0.5 or not beds.in_bed.is_empty():
		problems.append("The day is still waiting for a guest who is gone")
	beds.free()
	clock.free()
	rovers.free()
	return _finish("\n".join(problems))


func test_the_last_one_below_dropping_lets_the_field_rover_go() -> String:
	var all: Array = _farm_host()
	var host: Node = all[0]
	var gs: GameStateScript = all[1]
	var rovers: Node = all[2]
	var guest: Node = _guest(host)
	var gid: String = _guest_id(host)
	gs.rover_zone = ZONE  # by the console: the field rover, the farm's stays home
	gs.rover_transforms[gs.TUNNEL_ROVER] = gs.TUNNEL_START
	gs.zone_heat_trip = true
	gs.player_places[gs.local_player_id] = [ZonePresence.DOME, 0]
	gs.player_places[gid] = [ZONE, 0]
	rovers._drivers[gs.TUNNEL_ROVER] = [gid, 1 << 60]
	var epoch: int = gs.rover_epoch
	guest.leave()
	_until(func() -> bool: return host.players.size() == 1)
	var problems: Array[String] = []
	if gs.rover_zone != "" or gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("The field rover stayed live with nobody below")
	if gs.zone_heat_trip:
		problems.append("The next trip would start with the old heat trip")
	if gs.rover_epoch == epoch:
		problems.append("The rover going was not counted for the poses in flight")
	if parked_home(gs) != HOME:
		problems.append("The farm's rover moved")
	if rovers.driver(gs.TUNNEL_ROVER) != "":
		problems.append("A ghost still holds the field rover's lease")
	rovers.free()
	return _finish("\n".join(problems))


func parked_home(gs: GameStateScript) -> Vector3:
	return gs.parked_rover_transform(gs.ROVER).origin


func test_a_drop_leaves_the_rover_while_someone_else_is_below_or_it_was_not_below() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	_fresh(gs)
	gs.local_player_id = "player_1"
	gs.rover_in_tunnels = true
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(0))
	gs.zone_heat_trip = true
	gs.player_places["player_1"] = [ZONE, 0]
	gs.player_places["player_2"] = [ZONE, 1]
	gs.player_places["player_3"] = [ZonePresence.DOME, 0]
	gs.forget_place("player_2")  # the host is still below
	var problems: Array[String] = []
	if gs.rover_zone != ZONE or not gs.zone_heat_trip:
		problems.append("A guest dropping took the rover from the host below")
	gs.forget_place("player_3")  # in the dome: never had the rover
	if gs.rover_zone != ZONE:
		problems.append("A guest dropping in the dome took the rover")
	gs.forget_place("player_9")  # nobody the host knew
	if gs.rover_zone != ZONE:
		problems.append("A stranger dropping took the rover")
	gs.free()
	return "\n".join(problems)


func test_a_guest_pc_forgets_a_dropped_friend_and_leaves_the_rover_to_the_host() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	_fresh(gs)
	gs.rover_in_tunnels = true
	gs.player_places["player_2"] = [ZONE, 1]
	FarmCommands.guest = true
	gs.forget_place("player_2")
	FarmCommands.guest = false
	var kept: bool = gs.rover_zone == ZONE
	var gone: bool = not gs.player_places.has("player_2")
	gs.free()
	if not gone:
		return "The friend's place was not forgotten on a guest PC"
	return "" if kept else "A guest PC moved the host's rover"


# --- A guest joins late ---------------------------------------------------------

## Runs `body` with a host that already has zone state and a guest who joins it
## afterwards, over a real connection with the farm sent as it is. Puts the clock back.
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


func test_a_late_guest_is_told_the_zone_state() -> String:
	var find: Dictionary = _find()
	var setup: Callable = func(gs: GameStateScript) -> void:
		gs.finds_taken = ZoneDepth.with_taken({}, ZoneDepth.ZONE, _today(), str(find["id"]))
		gs.lifts_repaired = { ZONE: [3] }
		gs.deepest_depth = { ZONE: 3 }
		gs.beacons_placed = ["spot_west"]
		gs.rover_in_tunnels = true
		gs.rover_depth = 2
		gs.rover_epoch = 5
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position(2))
		gs.player_places["player_1"] = [ZONE, 2]
	return _join_late(setup, func(host: Node, guest: Node) -> String:
		var theirs: GameStateScript = guest.commands.state
		var problems: Array[String] = []
		if ZoneDepth.taken_today(theirs.finds_taken, ZoneDepth.ZONE, _today()) != [str(find["id"])]:
			problems.append("The newcomer was not told the finds already taken (%s)" % [theirs.finds_taken])
		if not theirs.is_lift_repaired(ZONE, 3):
			problems.append("The newcomer was not told the lift is repaired")
		if theirs.deepest_depth.get(ZONE, 0) != 3:
			problems.append("The newcomer was not told the deepest depth")
		if theirs.beacons_placed != ["spot_west"]:
			problems.append("The newcomer was not told the beacons")
		if theirs.rover_zone != ZONE or theirs.rover_depth != 2 or not theirs.rover_lent:
			problems.append("The newcomer was not told where the rover is (%s, %d, lent %s)" % [theirs.rover_zone, theirs.rover_depth, theirs.rover_lent])
		if theirs.rover_epoch != 5:
			problems.append("The newcomer's pose epoch differs, so no pose of the rover would be taken")
		if theirs.place_of("player_1") != ZONE or theirs.depth_of("player_1") != 2:
			problems.append("The newcomer was not told where the host is")
		if theirs.zone_heat_trip:
			problems.append("The newcomer was handed the host's heat trip")
		return "
".join(problems))


func test_a_late_guest_joins_a_field_rover_trip() -> String:
	var setup: Callable = func(gs: GameStateScript) -> void:
		gs.rover_zone = ZONE
		gs.rover_transforms[gs.TUNNEL_ROVER] = gs.TUNNEL_START
		gs.player_places["player_1"] = [ZONE, 0]
	return _join_late(setup, func(_host: Node, guest: Node) -> String:
		var theirs: GameStateScript = guest.commands.state
		if theirs.rover_zone != ZONE or theirs.rover_lent:
			return "The newcomer was told the field rover is the farm's (%s, lent %s)" % [theirs.rover_zone, theirs.rover_lent]
		if not theirs.rover_transforms.has(theirs.TUNNEL_ROVER):
			return "The newcomer was not told where the field rover is"
		return "")


func test_a_late_guest_cannot_take_a_find_already_taken_or_from_the_wrong_depth() -> String:
	var all: Array = _farm_host()
	var host: Node = all[0]
	var gs: GameStateScript = all[1]
	var rovers: Node = all[2]
	var find: Dictionary = _find()
	gs.finds_taken = ZoneDepth.with_taken({}, ZoneDepth.ZONE, _today(), str(find["id"]))
	gs.rover_zone = ZONE
	gs.rover_depth = ZoneDepth.DEPTH
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, _find_at())
	var guest: Node = _guest(host)
	var gid: String = _guest_id(host)
	gs.player_places[gid] = [ZONE, ZoneDepth.DEPTH]
	var asked: Array = _request(guest, &"take_find", [str(find["id"]), _today()])
	_until(func() -> bool: return not asked.is_empty())
	var problems: Array[String] = []
	if asked.is_empty() or asked[0] == "":
		problems.append("A find the farm already took was taken again by the newcomer (%s)" % [asked])
	if gs.crystal_ore != 10 or gs.credits != 500:
		problems.append("The refused find still paid")
	# A control: the next find, with the rover on it, is the newcomer's to take.
	var next: Dictionary = (_layout()["finds"] as Array)[1]
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(_layout()["grid"], next["cell"]))
	var control: Array = _request(guest, &"take_find", [str(next["id"]), _today()])
	_until(func() -> bool: return not control.is_empty())
	if control.is_empty() or control[0] != "":
		problems.append("The newcomer could not take a find that was free (%s)" % [control])
	rovers.free()
	return _finish("\n".join(problems))


# --- Players in different places at once ----------------------------------------

func test_each_zone_command_is_checked_against_the_sender_s_own_place() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	_fresh(gs)
	gs.local_player_id = "player_1"
	var commands: Node = _commands(gs)
	var find: Dictionary = _find()
	var day: int = _today()
	# The farm's rover is at depth 1 by a find. The host and player_4 are there;
	# player_2 is on the farm, player_3 is at depth 2, player_5 is in the dome.
	gs.rover_in_tunnels = true
	gs.rover_depth = ZoneDepth.DEPTH
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, _find_at())
	gs.player_places["player_1"] = [ZONE, ZoneDepth.DEPTH]
	gs.player_places["player_2"] = [ZonePresence.FARM, 0]
	gs.player_places["player_3"] = [ZONE, 2]
	gs.player_places["player_4"] = [ZONE, ZoneDepth.DEPTH]
	gs.player_places["player_5"] = [ZonePresence.DOME, 0]
	var problems: Array[String] = []
	for who: String in ["player_2", "player_3", "player_5"]:
		if commands.execute(who, &"take_find", [str(find["id"]), day]) == "":
			problems.append("%s took a find from where they are not" % who)
	if commands.execute("player_3", &"change_depth", [1]) == "" or gs.rover_depth != ZoneDepth.DEPTH:
		problems.append("A guest at another depth moved the rover")
	if commands.execute("player_2", &"change_depth", [0]) == "" or gs.rover_depth != ZoneDepth.DEPTH:
		problems.append("A guest on the farm moved the rover")
	for who: String in ["player_2", "player_3", "player_4"]:
		if commands.execute(who, &"place_beacon", ["spot_west"]) == "":
			problems.append("%s set a beacon below the hub" % who)
	for who: String in ["player_2", "player_3", "player_4"]:
		if commands.execute(who, &"leave_zone", []) == "":
			problems.append("%s left the zone from below the hub, or from where they are not" % who)
	for who: String in ["player_2", "player_4"]:
		if commands.execute(who, &"fast_travel", [ZONE]) == "":
			problems.append("%s used the console from outside the dome" % who)
	if gs.finds_taken != {} or gs.beacons_placed != [] or gs.rover_depth != ZoneDepth.DEPTH:
		problems.append("A refused command changed the farm")
	# player_4 is where the rover is: the find is theirs.
	if commands.execute("player_4", &"take_find", [str(find["id"]), day]) != "":
		problems.append("A guest at the rover's depth could not take a find")
	commands.free()
	gs.free()
	return "\n".join(problems)


func test_a_guest_at_depth_two_rides_the_lift_only_from_depth_two() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	_fresh(gs)
	gs.local_player_id = "player_1"
	var commands: Node = _commands(gs)
	gs.rover_in_tunnels = true
	gs.rover_depth = 3
	gs.lifts_repaired = { ZONE: [3] }
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.lift_position(3))
	gs.player_places["player_1"] = [ZonePresence.FARM, 0]
	gs.player_places["player_2"] = [ZONE, 2]
	gs.player_places["player_3"] = [ZONE, 3]
	var problems: Array[String] = []
	if commands.execute("player_2", &"use_lift", [0]) == "" or gs.rover_depth != 3:
		problems.append("A guest at depth 2 rode the depth 3 lift")
	if commands.execute("player_3", &"use_lift", [0]) != "" or gs.rover_depth != 0:
		problems.append("A guest at depth 3 could not ride up")
	commands.free()
	gs.free()
	return "\n".join(problems)


# --- The host's word on the rover is the newest word ----------------------------

func test_a_find_is_reached_from_the_pose_a_guest_drove_to_not_the_parked_one() -> String:
	var session: Node = _session()
	var gs: GameStateScript = session.commands.state
	_fresh(gs)
	var rovers: Node = _TogetherRovers.new()
	rovers.start(session, gs)
	gs.rovers_node = rovers
	var find: Dictionary = _find()
	var at: Vector3 = _find_at()
	gs.rover_zone = ZONE
	gs.rover_depth = ZoneDepth.DEPTH
	gs.player_places["player_2"] = [ZONE, ZoneDepth.DEPTH]
	# The kept pose is far from the find; the guest, driving, has told the host it is on it.
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at + Vector3(40.0, 0.0, 0.0))
	rovers._poses[gs.TUNNEL_ROVER] = [[at.x, at.y, at.z, 0.0, 0.0, true], 0]
	var problems: Array[String] = []
	var took: String = gs.take_find(str(find["id"]), _today(), "player_2")
	if took != "":
		problems.append("A find under the rover the guest drove there was refused (%s)" % took)
	# And the other way: the kept pose is on the next find, the told pose is far away.
	var other: Dictionary = (_layout()["finds"] as Array)[1]
	var there: Vector3 = TunnelRock.at_in(_layout()["grid"], other["cell"])
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, there)
	rovers._poses[gs.TUNNEL_ROVER] = [[there.x + 40.0, there.y, there.z, 0.0, 0.0, true], 0]
	if gs.take_find(str(other["id"]), _today(), "player_2") == "":
		problems.append("A find was taken from a rover the guest had driven away from it")
	rovers.free()
	return _finish("\n".join(problems))


func test_a_beacon_is_set_from_the_pose_a_guest_drove_to_not_the_parked_one() -> String:
	var session: Node = _session()
	var gs: GameStateScript = session.commands.state
	_fresh(gs)
	var rovers: Node = _TogetherRovers.new()
	rovers.start(session, gs)
	gs.rovers_node = rovers
	gs.quest_state["beacon_run"] = { "accepted": 0, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }
	var spot: Vector3 = LavaHub.spot_position("spot_west")
	gs.rover_zone = ZONE
	gs.player_places["player_2"] = [ZONE, 0]
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(40.0, 0.0, 0.0))
	rovers._poses[gs.TUNNEL_ROVER] = [[spot.x, spot.y, spot.z, 0.0, 0.0, true], 0]
	var problems: Array[String] = []
	var set_down: String = gs.place_beacon("spot_west", "player_2")
	if set_down != "" or gs.beacons_placed != ["spot_west"]:
		problems.append("A beacon beside the rover the guest drove there was refused (%s)" % set_down)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, LavaHub.spot_position("spot_east"))
	var far: Vector3 = LavaHub.spot_position("spot_east") + Vector3(40.0, 0.0, 0.0)
	rovers._poses[gs.TUNNEL_ROVER] = [[far.x, far.y, far.z, 0.0, 0.0, true], 0]
	if gs.place_beacon("spot_east", "player_2") == "":
		problems.append("A beacon was set from a rover the guest had driven away from it")
	rovers.free()
	return _finish("\n".join(problems))
