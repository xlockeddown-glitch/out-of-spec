extends "res://tests/coop_net.gd"
## One rover, driven by whoever got there first: real connections, this machine only.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const ID: String = "rover_1"
const FAR: int = 100000000

var _made: Array[Node] = []


func _rovers(session: Node) -> Node:
	var rovers: Node = RoversScript.new()
	rovers.start(session, session.commands.state)
	session.commands.state.rover_transforms[ID] = Transform3D.IDENTITY
	_made.append(rovers)
	return rovers


func _end_with(problem: String) -> String:
	for rovers: Node in _made:
		rovers.free()
	_made.clear()
	return _finish(problem)


func _at(x: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))


func _pose(x: float, los: bool = true) -> Array:
	return [x, 0.0, 0.0, 0.0, 0.0, los]


## [host, guest, the host's rovers, the guest's], told once where the rover is.
func _pair() -> Array:
	var host: Node = _host()
	var mine: Node = _rovers(host)
	var guest: Node = _guest(host)
	var theirs: Node = _rovers(guest)
	mine.tick(Time.get_ticks_msec())
	_until(func() -> bool: return theirs._told_driver.has(ID))
	return [host, guest, mine, theirs]


func test_alone_the_rover_moves_here_and_nothing_is_kept() -> String:
	var rovers: Node = _rovers(_session())
	var moves: bool = rovers.moves_here(ID, false) and rovers.moves_here(ID, true)
	rovers.moved(ID, _at(3.0), 1.0, true)
	var kept: bool = not rovers._poses.is_empty() or rovers.driver(ID) != ""
	return _end_with("" if moves and not kept else "Alone, the rover is the player's and nothing is shared")


func test_a_guest_drives_the_host_s_rover() -> String:
	var all: Array = _pair()
	var host: Node = all[0]
	var mine: Node = all[2]
	var theirs: Node = all[3]
	if theirs.moves_here(ID, false) or not mine.moves_here(ID, false):
		return _end_with("A rover nobody drives moves on the host only")
	if not theirs.moves_here(ID, true):
		return _end_with("A guest may drive a rover nobody drives")
	var error: float = host.commands.state.steering.error
	theirs.moved(ID, _at(2.0), 3.0, true)
	if not _until(func() -> bool: return mine.driver(ID) == "player_2"):
		return _end_with("The host must see who drives")
	if host.commands.state.rover_transforms[ID] != _at(2.0) or mine.place(ID) != _at(2.0):
		return _end_with("The host must know where it is, got %s" % host.commands.state.rover_transforms[ID])
	if host.commands.state.steering.error == error:
		return _end_with("Driving must wear the host's steering")
	if mine.moves_here(ID, true):
		return _end_with("The host must not drive it too")
	mine.tick(FAR * 2)
	return _end_with("" if mine.driver(ID) == "" and mine.moves_here(ID, true) else "A driver who is gone quiet is done")


func test_the_first_to_drive_drives() -> String:
	var all: Array = _pair()
	var mine: Node = all[2]
	var theirs: Node = all[3]
	if not mine.moves_here(ID, true):
		return _end_with("The host may drive")
	# Both at once: the guest learns that the host was first.
	theirs.moves_here(ID, true)
	theirs.moved(ID, _at(1.0), 1.0, true)
	mine.moved(ID, _at(-1.0), 1.0, true)
	mine.tick(Time.get_ticks_msec() + RoversScript.MOVING_MS)
	if not _until(func() -> bool: return theirs.driver(ID) == "player_1"):
		return _end_with("The guest must be told, got %s" % theirs.driver(ID))
	if theirs.moves_here(ID, true) or theirs.place(ID) != _at(-1.0) or theirs.speed(ID) != 1.0:
		return _end_with("The guest must follow the host's rover, got %s" % theirs.place(ID))
	if mine.driver(ID) != "player_1":
		return _end_with("The guest must not take it")
	var later: int = Time.get_ticks_msec() + RoversScript.MOVING_MS
	mine.tick(later)
	mine.tick(later + RoversScript.HOLD_MS + 1)
	_until(func() -> bool: return theirs.driver(ID) == "")
	return _end_with("" if theirs.moves_here(ID, true) else "The guest must hear at once that the host stopped")


func test_a_rover_goes_no_farther_than_it_can() -> String:
	var all: Array = _pair()
	var state: Node = all[0].commands.state
	var mine: Node = all[2]
	mine._on_driven("player_2", ID, _pose(14.0), 1000)
	mine._on_driven("player_2", ID, _pose(0.0), 1100)
	if state.rover_transforms[ID] != _at(14.0) or mine.driver(ID) != "":
		return _end_with("Too far must be refused and end the drive")
	mine._on_driven("player_2", ID, _pose(0.0), 3100)
	if state.rover_transforms[ID] != _at(0.0):
		return _end_with("It may go as far as its speed allows")
	mine._on_driven("player_2", "rover_9", _pose(0.0), 9000)
	return _end_with("" if not state.rover_transforms.has("rover_9") else "A guest makes no rovers")


func test_a_guest_the_host_never_answers_stops() -> String:
	var all: Array = _pair()
	var theirs: Node = all[3]
	theirs.moves_here(ID, true, 1000)
	theirs._on_told(ID, "", _pose(5.0), 1400)
	if not theirs.moves_here(ID, true, 1400):
		return _end_with("An old word must not stop a guest who just began")
	theirs._on_told(ID, "", _pose(5.0), 2501)
	return _end_with("" if theirs.driver(ID) == "" and theirs.place(ID) == _at(5.0) else "The host's word must win")


func test_the_relay_is_seen_from_a_guest_s_rover_only_if_the_host_has_none_here() -> String:
	var all: Array = _pair()
	var state: Node = all[0].commands.state
	var mine: Node = all[2]
	mine._on_driven("player_2", ID, _pose(1.0, false), 5000)
	if state.rover_uplinks.get(ID) != false:
		return _end_with("With the host in the dome the driver says")
	mine.moves_here(ID, false, 5100)
	mine._on_driven("player_2", ID, _pose(1.0, true), 5200)
	return _end_with("" if state.rover_uplinks[ID] == false else "The host's own rover looks for itself")


func test_leaving_frees_the_rover() -> String:
	var all: Array = _pair()
	var guest: Node = all[1]
	var mine: Node = all[2]
	mine._on_driven("player_2", ID, _pose(1.0), FAR)
	guest.leave()
	_until(func() -> bool: return all[0].players.size() == 1)
	return _end_with("" if not mine._drivers.has(ID) else "A player who left drives nothing")


func test_bad_poses_end_the_connection() -> String:
	# Not a pose at all. Numbers that are not real or not here are only refused.
	var bad: Array = [[], [0.0, 0.0, 0.0, 0.0, 0.0], [0, 0.0, 0.0, 0.0, 0.0, true], [0.0, 0.0, 0.0, 0.0, 0.0, 1]]
	for pose: Array in bad:
		var host: Node = _host()
		_rovers(host)
		var peer: ENetMultiplayerPeer = _stranger(host, true)
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		peer.put_packet(var_to_bytes([SessionScript.DRIVE, ID, pose]))
		if not _until(func() -> bool: return host.players.size() == 1):
			return _end_with("%s must end the connection" % [pose])
		_end_with("")
	return ""


func test_only_poses_come_unreliably_and_not_too_many() -> String:
	for sent: Array in [[false, 1, [SessionScript.COMMAND, 1, "till", []]], [true, 1, [SessionScript.DRIVE, ID, _pose(0.0)]],
			[false, 160, [SessionScript.DRIVE, ID, _pose(0.0)]]]:
		var host: Node = _host()
		_rovers(host)
		var peer: ENetMultiplayerPeer = _stranger(host, true)
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if sent[0] else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		for i: int in sent[1]:
			peer.put_packet(var_to_bytes(sent[2]))
		if not _until(func() -> bool: return host.players.size() == 1):
			return _end_with("%s must end the connection" % [sent])
		_end_with("")
	return ""


func test_driving_spends_none_of_the_commands_rate() -> String:
	var all: Array = _pair()
	var host: Node = all[0]
	var guest: Node = all[1]
	for i: int in 60:
		guest.drive(ID, _pose(0.0))
	var answer: Array = _request(guest, &"till", [Vector3i(0, 0, 0)])
	_until(func() -> bool: return not answer.is_empty())
	return _end_with("" if host.players.size() == 2 and not answer.is_empty() else "60 poses at once must not drop a guest")


func test_a_friend_who_comes_later_is_told_where_it_is_now() -> String:
	var all: Array = _pair()
	var host: Node = all[0]
	var guest: Node = all[1]
	var mine: Node = all[2]
	mine.moves_here(ID, true)
	mine.moved(ID, _at(5.0), 0.0, true)
	guest.leave()
	if not _until(func() -> bool: return host.players.size() == 1):
		return _end_with("The guest must be gone")
	mine.tick(FAR)
	host.commands.state.rover_transforms[ID] = _at(40.0)
	var late: Node = _guest(host)
	var theirs: Node = _rovers(late)
	# The farm scene has it, but has not said where yet.
	mine.moves_here(ID, false, FAR)
	mine.tick(FAR)
	if mine._poses.has(ID):
		return _end_with("The farm's place must wait for the scene's own")
	mine.moved(ID, _at(42.0), 0.0, true, FAR)
	mine.tick(FAR)
	_until(func() -> bool: return theirs._told_driver.has(ID))
	return _end_with("" if theirs.place(ID) == _at(42.0) else "Told %s" % theirs.place(ID))


func test_a_pose_that_is_not_real_is_refused_and_the_guest_stays() -> String:
	var all: Array = _pair()
	var state: Node = all[0].commands.state
	var mine: Node = all[2]
	mine._on_driven("player_2", ID, _pose(1.0), 1000)
	for bad: Array in [[NAN, 0.0, 0.0, 0.0, 0.0, true], [INF, 0.0, 0.0, 0.0, 0.0, true], [501.0, 0.0, 0.0, 0.0, 0.0, true],
			[0.0, 0.0, 0.0, 0.0, 9.0, true], [Terrain.HALF_M + 20.0, 0.0, 0.0, 0.0, 0.0, true]]:
		mine._on_driven("player_2", ID, bad, 1000)
		if state.rover_transforms[ID] != _at(1.0):
			return _end_with("%s must be refused" % [bad])
	# Near the edge, the distance allowed is not what refuses it: the edge is.
	state.park_rover(ID, _at(Terrain.HALF_M - 1.0))
	mine._reach.erase(ID)
	mine._poses.erase(ID)
	mine._on_driven("player_2", ID, _pose(Terrain.HALF_M + 3.0), 5000)
	if state.rover_transforms[ID] != _at(Terrain.HALF_M - 1.0):
		return _end_with("A rover 3 m past the edge must be refused")
	mine._on_driven("player_2", ID, _pose(Terrain.HALF_M + 1.0), 5100)
	if state.rover_transforms[ID] != _at(Terrain.HALF_M + 1.0):
		return _end_with("A rover 1 m past the edge is still on the land")
	if mine.is_sane([0.0, 0.0, 0.0, 0.0, 7.6, true]) or not mine.is_sane([0.0, 0.0, 0.0, 0.0, 6.0, true]):
		return _end_with("A rover goes 6 m/s and no more than 7.5")
	# One packet of nonsense does not end the connection.
	all[1]._put(1, var_to_bytes([SessionScript.DRIVE, ID, [NAN, 0.0, 0.0, 0.0, 0.0, true]]), false)
	var polls: Array = [0]
	_until(func() -> bool:
		polls[0] += 1
		return polls[0] > 100 or all[0].players.size() < 2)
	return _end_with("" if all[0].players.size() == 2 else "A refused pose must not drop its sender")


func test_walking_speed_is_accepted_and_a_rover_jump_after_a_dig_or_the_tunnel_too() -> String:
	var all: Array = _pair()
	var state: Node = all[0].commands.state
	var mine: Node = all[2]
	# A rover at its own top speed, 50 ms apart.
	for i: int in 20:
		mine._on_driven("player_2", ID, _pose(0.3 * (i + 1)), 1000 + 50 * i)
	if state.rover_transforms[ID] != _at(6.0):
		return _end_with("Driving at 6 m/s must be taken")
	# A dig floods its place and it is put up to 16 m away.
	mine._on_driven("player_2", ID, _pose(22.0), 2000)
	if state.rover_transforms[ID] != _at(22.0):
		return _end_with("The pit rescue (16 m) must be taken")
	# Into the tunnels, out again somewhere else: the host says where, and who knows it.
	state.rover_transforms[ID] = _at(-40.0)
	state.rover_place_changed.emit()
	mine._on_driven("player_2", ID, _pose(-39.0), 2100)
	return _end_with("" if state.rover_transforms[ID] == _at(-39.0) else "The rover must go on from its new place")


## The steepest ground a rover drives is about 45 degrees (the dug pit's corner is 44,
## the pad's edge 42, the rover's own floor limit 45): one metre up per metre along.
func test_the_fastest_loadout_climbs_the_steepest_real_grade_without_being_refused() -> String:
	var all: Array = _pair()
	var state: Node = all[0].commands.state
	var mine: Node = all[2]
	var speed: float = 6.0 * Loadout.MAX_SPEED_FACTOR
	var step_m: float = speed * 0.05
	if not mine.is_sane([0.0, 0.0, 0.0, 0.0, speed, true]):
		return _end_with("The fastest loadout's speed must pass is_sane")
	if Vector2(step_m, step_m).length() / 0.05 <= mine.REACH_MPS:
		return _end_with("The 3D speed on this grade is meant to be past the budget, or this test proves nothing")
	# 30 s straight up a 45 degree grade, a pose every 50 ms.
	for i: int in 600:
		var x: float = step_m * (i + 1)
		mine._on_driven("player_2", ID, [x, x, 0.0, 0.0, speed, true], 1000 + 50 * i)
		if state.rover_transforms[ID].origin != Vector3(x, x, 0.0):
			return _end_with("The climb was refused at pose %d" % i)
	# And back down it.
	for i: int in 600:
		var x: float = step_m * 600 - step_m * (i + 1)
		mine._on_driven("player_2", ID, [x, x, 0.0, 0.0, speed, true], 31000 + 50 * i)
		if state.rover_transforms[ID].origin != Vector3(x, x, 0.0):
			return _end_with("The descent was refused at pose %d" % i)
	# A rise with no run to explain it is still a jump.
	mine._on_driven("player_2", ID, [0.0, 17.0, 0.0, 0.0, 0.0, true], 62000)
	mine._on_driven("player_2", ID, [0.0, 34.0, 0.0, 0.0, 0.0, true], 62050)
	return _end_with("" if state.rover_transforms[ID].origin.y < 30.0 else "A rise without a run must still be charged")
