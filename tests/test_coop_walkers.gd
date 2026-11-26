extends "res://tests/coop_net.gd"
## Out of the rover and back: real connections, this machine only.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const WalkersScript: GDScript = preload("res://scripts/autoload/CoopWalkers.gd")
const ID: String = "rover_1"

var _made: Array[Node] = []


func _walkers(session: Node) -> Node:
	var state: Node = session.commands.state
	var rovers: Node = RoversScript.new()
	rovers.start(session, state)
	state.rover_transforms[ID] = Transform3D.IDENTITY
	var walkers: Node = WalkersScript.new()
	walkers.start(session, state, rovers)
	_made.append_array([walkers, rovers])
	return walkers


func _end_with(problem: String) -> String:
	for node: Node in _made:
		node.free()
	_made.clear()
	CoopWalkers.forget()
	return _finish(problem)


## [host, guest, the host's walkers, the guest's].
func _pair() -> Array:
	var host: Node = _host()
	var mine: Node = _walkers(host)
	var guest: Node = _guest(host)
	return [host, guest, mine, _walkers(guest)]


func _pose(x: float, z: float = 0.0) -> Array:
	return [x, 0.0, z, 0.0, 4.0]


func test_out_beside_the_stopped_rover_and_in_from_nearby() -> String:
	var walkers: Node = _walkers(_session())
	if walkers.get_out("p", 30.0, 0.0) == "" or walkers.get_out("p", NAN, 0.0) == "" or walkers.is_out("p"):
		return _end_with("Out must be beside the rover")
	if walkers.get_out("p", 2.0, 0.0) != "" or not walkers.is_out("p") or walkers.get_out("p", 2.0, 0.0) == "":
		return _end_with("Out once")
	walkers.out["p"] = _pose(6.5)
	if walkers.get_in("p") == "" or not walkers.is_out("p"):
		return _end_with("The rover must be within reach")
	walkers.out["p"] = _pose(5.5)
	if walkers.get_in("p") != "" or walkers.is_out("p"):
		return _end_with("In from nearby")
	walkers.get_out(walkers.farm.local_player_id, 2.0, 0.0)
	walkers.went_in()
	walkers.moved(Vector3.ZERO, 0.0, 0.0)
	if walkers.on_foot():
		return _end_with("A walker's last tick must not put its player out again")
	walkers.farm.rover_in_tunnels = true
	return _end_with("" if walkers.get_out("p", 2.0, 0.0) != "" else "Not out of a rover in the tunnels")


func test_not_out_of_a_rover_someone_else_drives() -> String:
	var all: Array = _pair()
	all[2].rovers.moves_here(ID, true)
	if all[2].get_out("player_2", 2.0, 0.0) == "":
		return _end_with("The host drives it")
	all[2].rovers.moved(ID, Transform3D.IDENTITY, 1.0, true)
	return _end_with("" if all[2].get_out("player_1", 2.0, 0.0) != "" else "Stop it first")


func test_each_sees_the_other_walk() -> String:
	var all: Array = _pair()
	var mine: Node = all[2]
	var theirs: Node = all[3]
	if mine.get_out("player_2", 2.0, 0.0) != "" or mine.get_out("player_1", -2.0, 0.0) != "":
		return _end_with("Both may get out")
	theirs.went_out(2.0, 0.0)
	theirs.moved(Vector3(4.0, 0.0, 1.0), 0.5, 4.0)
	if not _until(func() -> bool: return mine.out["player_2"][0] == 4.0):
		return _end_with("The host must see the guest walk")
	mine.moved(Vector3(-3.0, 0.0, 0.0), 0.0, 4.0)
	mine.tick(Time.get_ticks_msec())
	if not _until(func() -> bool: return theirs.is_out("player_1") and theirs.out["player_1"][0] == -3.0):
		return _end_with("The guest must see the host walk")
	return _end_with("" if theirs.out["player_2"][0] == 4.0 else "The guest's own stays where it is")


func test_bad_walking_is_not_taken() -> String:
	var all: Array = _pair()
	var mine: Node = all[2]
	mine._on_walked("player_2", _pose(3.0), 1000)
	if mine.is_out("player_2"):
		return _end_with("Who is in the rover does not walk")
	mine.get_out("player_2", 2.0, 0.0, 1000)
	mine._on_walked("player_2", _pose(25.0), 1000)
	mine._on_walked("player_2", [3.0, 9.0, 0.0, 0.0, 4.0], 1000)
	mine._on_walked("player_2", _pose(-Terrain.HALF_M - 1.0), 900000)
	if mine.out["player_2"][0] != 2.0:
		return _end_with("Too far, too high and off the land are refused")
	mine._on_walked("player_2", _pose(13.0), 1000)
	mine._on_walked("player_2", _pose(2.0), 1400)
	if mine.out["player_2"][0] != 13.0:
		return _end_with("No faster than it can walk")
	mine._on_walked("player_2", _pose(2.0), 4000)
	if mine.out["player_2"][0] != 2.0:
		return _end_with("Its speed lets it go on")
	mine.out["player_2"] = [63.0, 1.0, 12.0, 0.0, 0.0]
	mine._on_walked("player_2", [Terrain.WASH_DEEP_AT.x, 1.0, Terrain.WASH_DEEP_AT.y, 0.0, 4.0], 900000)
	if mine.out["player_2"][2] != 12.0:
		return _end_with("Not into deep water")
	for bad: Variant in [[], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4, 5], [NAN, 0.0, 0.0, 0.0, 0.0], [9e9, 0.0, 0.0, 0.0, 0.0], "x"]:
		if mine.is_pose(bad):
			return _end_with("Not a pose: %s" % [bad])
	all[1]._put(1, var_to_bytes([SessionScript.WALK, [1]]), false)
	return _end_with("" if _until(func() -> bool: return all[0].players.size() == 1) else "A bad message must drop its sender")


func test_a_guest_who_goes_is_in_the_rover() -> String:
	var all: Array = _pair()
	var mine: Node = all[2]
	mine.get_out("player_2", 2.0, 0.0, 1000)
	mine.tick(1000 + WalkersScript.SILENT_MS)
	if not mine.is_out("player_2"):
		return _end_with("Not yet silent too long")
	mine.tick(1001 + WalkersScript.SILENT_MS)
	if mine.is_out("player_2"):
		return _end_with("Silent too long is in the rover")
	mine.get_out("player_2", 2.0, 0.0)
	all[3].went_out(2.0, 0.0)
	all[3].out["player_1"] = _pose(1.0)
	all[3].tick(0)
	all[1].leave()
	all[3].tick(0)
	if not all[3].out.is_empty():
		return _end_with("A guest who left must not keep the host's walkers")
	return _end_with("" if _until(func() -> bool: return not mine.is_out("player_2")) else "Who leaves is in the rover")


func test_a_rover_that_goes_away_takes_everyone() -> String:
	var walkers: Node = _walkers(_session())
	walkers.get_out("p", 2.0, 0.0)
	walkers.farm.rover_place_changed.emit()
	if walkers.is_out("p"):
		return _end_with("Nobody is left on the farm")
	walkers.get_out("p", 2.0, 0.0)
	walkers.farm.farm_loaded.emit()
	return _end_with("" if not walkers.is_out("p") else "A loaded farm has everyone in the rover")


func test_older_word_does_not_undo_the_guest_s_own() -> String:
	var all: Array = _pair()
	var theirs: Node = all[3]
	theirs.went_out(2.0, 0.0)
	var now: int = Time.get_ticks_msec()
	theirs._on_told({}, now)
	if not theirs.is_out("player_2"):
		return _end_with("Just got out")
	theirs._on_told({"player_2": _pose(20.0)}, now)
	if theirs.out["player_2"][0] != 20.0:
		return _end_with("The host says where, if far off")
	theirs._on_told({}, now + 5000)
	if theirs.is_out("player_2"):
		return _end_with("The host's word wins later")
	theirs.went_in()
	theirs._on_told({"player_2": _pose(2.0)}, Time.get_ticks_msec())
	return _end_with("" if not theirs.is_out("player_2") else "Just got in")


func test_on_foot_only_a_few_things_are_done() -> String:
	var all: Array = _pair()
	all[2].get_out("player_2", 2.0, 0.0)
	CoopWalkers.out["player_2"] = _pose(2.0)
	var got: Array = _request(all[1], &"accept_job", [0])
	_until(func() -> bool: return not got.is_empty())
	if got != [WalkersScript.REFUSAL]:
		return _end_with("The host must refuse farm work, got %s" % [got])
	var commands: Node = all[0].commands
	if commands.execute("player_1", &"accept_job", [0]) == WalkersScript.REFUSAL:
		return _end_with("Who is in the rover works")
	CoopWalkers.out.clear()
	return _end_with("" if commands.execute("player_2", &"accept_job", [0]) != WalkersScript.REFUSAL else "Back in, they work")


func test_a_walker_cannot_drive() -> String:
	var all: Array = _pair()
	CoopWalkers.out["player_2"] = _pose(2.0)
	all[2].rovers._on_driven("player_2", ID, [1.0, 0.0, 0.0, 0.0, 0.0, true], 5000)
	if all[2].rovers.driver(ID) != "":
		return _end_with("On foot, nobody drives")
	CoopWalkers.out.clear()
	all[2].rovers._on_driven("player_2", ID, [1.0, 0.0, 0.0, 0.0, 0.0, true], 5000)
	return _end_with("" if all[2].rovers.driver(ID) == "player_2" else "In the rover, they drive")


func test_the_keys_follow_the_camera() -> String:
	for yaw_deg: float in [45.0, 135.0, 225.0, 315.0]:
		var view := Basis.from_euler(Vector3(deg_to_rad(-35.0), deg_to_rad(yaw_deg), 0.0))
		var up: Vector3 = Walker.heading(Vector2(0.0, -1.0), view)
		var flat := Vector3(-view.z.x, 0.0, -view.z.z).normalized()
		if not up.is_equal_approx(flat) or not Walker.heading(Vector2(1.0, 0.0), view).is_equal_approx(view.x):
			return "W must go up the screen and D right at %s°" % yaw_deg
		if not is_equal_approx(Walker.heading(Vector2(1.0, 1.0), view).length(), 1.0):
			return "Two keys are no faster than one"
	return ""


func test_a_guest_takes_no_bad_word_of_walkers() -> String:
	var crowd: Dictionary = {}
	for i: int in CoopSession.MAX_PLAYERS + 1:
		crowd["player_%d" % i] = _pose(1.0)
	for bad: Dictionary in [crowd, { 7: _pose(1.0) }, { "player_1": [NAN, 0.0, 0.0, 0.0, 0.0] }, { "player_1": [1.0] }]:
		var pair: Array = _pair()
		var told: Array = []
		pair[1].walkers_told.connect(func(poses: Dictionary) -> void: told.append(poses))
		pair[0].tell_walkers(bad)
		if not _until(func() -> bool: return _got(pair[1], "lost")) or not told.is_empty():
			return _end_with("The guest must leave a host that sends this: %s" % [bad])
		_end_with("")
	return _end_with("")


func test_a_walker_that_is_not_real_or_too_fast_is_refused_and_the_guest_stays() -> String:
	var all: Array = _pair()
	var mine: Node = all[2]
	mine.get_out("player_2", 2.0, 0.0, 1000)
	for bad: Array in [[NAN, 0.0, 0.0, 0.0, 4.0], [INF, 0.0, 0.0, 0.0, 4.0], [0.0, 0.0, NAN, 0.0, 4.0], [0.0, 0.0, 0.0, 0.0, NAN],
			[Terrain.HALF_M + 5.0, 0.0, 0.0, 0.0, 4.0], [9e9, 0.0, 0.0, 0.0, 4.0], [3.0, 0.0, 0.0, 0.0, 40.0], [30.0, 0.0, 0.0, 0.0, 4.0]]:
		mine._on_walked("player_2", bad, 1000)
		if mine.out["player_2"][0] != 2.0:
			return _end_with("%s must be refused" % [bad])
	# One refused packet does not end the connection.
	all[1]._put(1, var_to_bytes([SessionScript.WALK, [NAN, 0.0, 0.0, 0.0, 0.0]]), false)
	var polls: Array = [0]
	_until(func() -> bool:
		polls[0] += 1
		return polls[0] > 100 or all[0].players.size() < 2)
	return _end_with("" if all[0].players.size() == 2 else "A refused pose must not drop its sender")


func test_walking_at_speed_is_taken_and_so_are_the_jumps_the_game_makes() -> String:
	var all: Array = _pair()
	var mine: Node = all[2]
	mine.get_out("player_2", 2.0, 0.0, 1000)
	# 4 m/s, a pose every 50 ms, for ten seconds.
	for i: int in 200:
		mine._on_walked("player_2", _pose(2.0 + 0.2 * (i + 1)), 1000 + 50 * (i + 1))
	if absf(mine.out["player_2"][0] - 42.0) > 0.001:
		return _end_with("Walking must be taken: %s" % [mine.out["player_2"]])
	# A dig floods its place: the walker is put 16 m off at once.
	mine._on_walked("player_2", _pose(58.0), 12000)
	if mine.out["player_2"][0] != 58.0:
		return _end_with("The pit rescue must be taken")
	# Getting out is anywhere beside the rover, however far the last walk was.
	mine._go_in("player_2")
	mine.farm.rover_transforms[ID] = Transform3D(Basis.IDENTITY, Vector3(-40.0, 0.0, 0.0))
	if mine.get_out("player_2", -38.0, 0.0, 13000) != "":
		return _end_with("Out beside a rover that is elsewhere")
	mine._on_walked("player_2", _pose(-37.0), 13100)
	if mine.out["player_2"][0] != -37.0:
		return _end_with("A walk from there must be taken")
	# The rover goes into the tunnels: everyone is in, and starts again.
	mine.farm.rover_place_changed.emit()
	return _end_with("" if not mine.is_out("player_2") and mine._reach.is_empty() else "A new place starts again")
