extends Node
## Rovers with friends in. Whoever drives one moves it on their own PC, so it
## answers as it does alone, and it can be driven while the host is in the dome.
## The host says who drives, checks where they say it is, counts the distance and
## tells everyone. Alone nothing here does anything. Autoloaded as `CoopRovers`.
##
## A pose is [x, y, z, yaw, speed in m/s, whether it sees the relay].

## A driver is done this long after the rover stops, or is last heard from
## [PLACEHOLDER].
const HOLD_MS: int = 500
## A guest drives this long before it needs the host's word that it may [PLACEHOLDER].
const CLAIM_MS: int = 1500
## A moving rover's pose is sent this often, and a still one's this often
## [PLACEHOLDER].
const MOVING_MS: int = 50
const STILL_MS: int = 1000
## A guest's rover may go this far at once, and this fast after that: above the
## rover's 6 m/s, for a late message [PLACEHOLDER].
const REACH_M: float = 15.0
const REACH_MPS: float = 7.5
## No rover is farther out than this [PLACEHOLDER].
const FARTHEST_M: float = 500.0

## Only tests set others.
var session: Node
var farm: Node

## Rover id -> [player, until when]. A guest's holds only itself.
var _drivers: Dictionary = {}
## Guest: rover id -> who the host says drives.
var _told_driver: Dictionary = {}
## Rover id -> [pose, when it came].
var _poses: Dictionary = {}
## Guest: rover id -> when it began to drive.
var _claimed_at: Dictionary = {}
## Rover id -> when its pose was last sent.
var _sent_at: Dictionary = {}
## Host: rover id -> who was last said to drive it.
var _said_driver: Dictionary = {}
## Host: rover id -> [metres a guest may still move it, when that was].
var _reach: Dictionary = {}
## Rover id -> when the farm scene here last had it.
var _here_at: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start(CoopSession, GameState)


func start(with_session: Node, with_farm: Node) -> void:
	session = with_session
	farm = with_farm
	session.rover_driven.connect(_on_driven)
	session.rover_told.connect(_on_told)
	session.player_left.connect(_on_left)
	session.joined.connect(_forget.unbind(1))
	farm.farm_loaded.connect(_forget)


func _process(_delta: float) -> void:
	tick(Time.get_ticks_msec())


func is_pose(pose: Array) -> bool:
	if pose.size() != 6 or typeof(pose[5]) != TYPE_BOOL:
		return false
	for i: int in 5:
		if typeof(pose[i]) != TYPE_FLOAT or not is_finite(pose[i]) or absf(pose[i]) > FARTHEST_M:
			return false
	return true


## There is someone to share a rover with, or a farm that is not ours.
func together() -> bool:
	return _is_guest() or (session.is_hosting() and session.players.size() > 1)


## Who drives, or "".
func driver(rover_id: String) -> String:
	if _drivers.has(rover_id):
		return _drivers[rover_id][0]
	return _told_driver.get(rover_id, "") if _is_guest() else ""


## True if the rover moves here: alone, if this player drives, or on the host if
## nobody does. `wants` is whether this player drives or tries to. Each tick.
func moves_here(rover_id: String, wants: bool, now: int = Time.get_ticks_msec()) -> bool:
	_here_at[rover_id] = now
	if not together():
		return true
	_expire(now)
	var own: String = farm.local_player_id
	if wants and driver(rover_id) in ["", own] and _may_drive(rover_id):
		if not _drivers.has(rover_id):
			_claimed_at[rover_id] = now
		_drivers[rover_id] = [own, now + HOLD_MS]
	if _is_guest():
		return _drivers.has(rover_id)
	return driver(rover_id) in ["", own]


## Where a rover that moves here is now.
func moved(rover_id: String, at: Transform3D, speed_mps: float, has_los: bool, now: int = Time.get_ticks_msec()) -> void:
	if not together():
		return
	var pose: Array = [at.origin.x, at.origin.y, at.origin.z, at.basis.get_euler().y, speed_mps, has_los]
	_poses[rover_id] = [pose, now]
	if _is_guest() and _is_due(rover_id, now, MOVING_MS):
		session.drive(rover_id, pose)


## Where the rover is as last heard, moved on by its speed for `lead_s` at most.
func place(rover_id: String, lead_s: float = 0.0, now: int = Time.get_ticks_msec()) -> Transform3D:
	if not _poses.has(rover_id):
		return farm.parked_rover_transform(rover_id)
	var at: Transform3D = _transform(_poses[rover_id][0])
	at.origin -= at.basis.z * speed(rover_id) * minf((now - _poses[rover_id][1]) / 1000.0, lead_s)
	return at


func has_place(rover_id: String) -> bool:
	return _poses.has(rover_id) or farm.rover_transforms.has(rover_id)


func speed(rover_id: String) -> float:
	return _poses[rover_id][0][4] if _poses.has(rover_id) and driver(rover_id) != "" else 0.0


## Host: says where the rovers are.
func tick(now: int) -> void:
	_expire(now)
	if not together():
		# Where it was with friends in isn't where it is when the next one joins.
		for known: Dictionary in [_drivers, _poses, _sent_at, _said_driver, _reach]:
			known.clear()
	if not session.is_hosting() or session.players.size() < 2:
		return
	for rover_id: String in farm.rover_transforms:
		if not _poses.has(rover_id):
			# A rover in the scene here says where it is itself; the farm may lag it.
			if now - _here_at.get(rover_id, -STILL_MS) < STILL_MS:
				continue
			_poses[rover_id] = [_pose(farm.rover_transforms[rover_id]), now]
		var who: String = driver(rover_id)
		# At once, so that someone else may drive.
		if _said_driver.get(rover_id, "") != who:
			_sent_at.erase(rover_id)
		if _is_due(rover_id, now, STILL_MS if who == "" else MOVING_MS):
			_said_driver[rover_id] = who
			session.tell_rover(rover_id, who, _poses[rover_id][0])


## Host: a guest says where the rover it drives is.
func _on_driven(player_id: String, rover_id: String, pose: Array, now: int = Time.get_ticks_msec()) -> void:
	_expire(now)
	if not farm.rover_transforms.has(rover_id) or not driver(rover_id) in ["", player_id] or not together():
		return
	var to: Transform3D = _transform(pose)
	var from: Transform3D = place(rover_id)
	var reach: Array = _reach.get(rover_id, [REACH_M, now])
	var left: float = minf(REACH_M, reach[0] + (now - reach[1]) * REACH_MPS / 1000.0)
	var distance: float = from.origin.distance_to(to.origin)
	if distance > left:
		# It is told where the rover is, and drives on from there.
		_drivers.erase(rover_id)
		_sent_at.erase(rover_id)
		return
	_reach[rover_id] = [left - distance, now]
	_drivers[rover_id] = [player_id, now + HOLD_MS]
	_poses[rover_id] = [pose, now]
	farm.add_rover_usage(Vector2(to.origin.x - from.origin.x, to.origin.z - from.origin.z).length(), player_id)
	farm.park_rover(rover_id, to)
	# A rover in the host's own scene looks for the relay itself.
	if now - _here_at.get(rover_id, -STILL_MS) >= STILL_MS:
		farm.set_rover_uplink(rover_id, pose[5])


## Guest: the host says who drives and where the rover is.
func _on_told(rover_id: String, driver_id: String, pose: Array, now: int = Time.get_ticks_msec()) -> void:
	if not farm.rover_transforms.has(rover_id):
		return
	_told_driver[rover_id] = driver_id
	var own: String = farm.local_player_id
	if _drivers.has(rover_id) and driver_id != own and (driver_id != "" or now - _claimed_at.get(rover_id, 0) > CLAIM_MS):
		_drivers.erase(rover_id)
	if not _drivers.has(rover_id):
		_poses[rover_id] = [pose, now]


func _on_left(player_id: String) -> void:
	for rover_id: String in _drivers.keys():
		if _drivers[rover_id][0] == player_id:
			_drivers.erase(rover_id)


func _expire(now: int) -> void:
	for rover_id: String in _drivers.keys():
		if now > _drivers[rover_id][1]:
			_drivers.erase(rover_id)


func _forget() -> void:
	for known: Dictionary in [_drivers, _told_driver, _poses, _claimed_at, _sent_at, _said_driver, _reach, _here_at]:
		known.clear()


func _may_drive(rover_id: String) -> bool:
	return session.is_hosting() or (session.is_guest() and _told_driver.has(rover_id))


func _is_due(rover_id: String, now: int, every_ms: int) -> bool:
	if _sent_at.has(rover_id) and now - _sent_at[rover_id] < every_ms:
		return false
	_sent_at[rover_id] = now
	return true


func _is_guest() -> bool:
	return session._farm_commands().guest


static func _pose(at: Transform3D) -> Array:
	return [at.origin.x, at.origin.y, at.origin.z, at.basis.get_euler().y, 0.0, true]


static func _transform(pose: Array) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, pose[3]), Vector3(pose[0], pose[1], pose[2]))
