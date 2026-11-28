extends Node
## Who is out of the rover and where they walk. The host says who is out, checks
## where they say they are and tells everyone. Alone it only says whether the
## player is out. Nothing is saved: a loaded farm has everyone in the rover.
## Autoloaded as `CoopWalkers`.
##
## A pose is [x, y, z, yaw, speed in m/s].

## Out and in are this near the rover's middle: what the tunnel pad asks of it.
const REACH_M: float = 6.0
## A pose that changed is sent this often, and one that did not this often
## [PLACEHOLDER].
const MOVING_MS: int = 50
const STILL_MS: int = 1000
## A guest may go this far at once, and this fast after that: above the walker's
## 4 m/s, for a late message [PLACEHOLDER]. At once is past the 16 m a dig that
## floods the spot sends a walker (the rover's PIT_SEARCH_M).
const BURST_M: float = 18.0
const BURST_MPS: float = 5.0
## A guest farther than this from where the host has it goes there. Below
## BURST_M, so the host can always take what is left [PLACEHOLDER].
const SNAP_M: float = 17.0
## No walker is this far above or below the ground [PLACEHOLDER].
const HEIGHT_M: float = 5.0
## A guest silent this long is back in the rover [PLACEHOLDER].
const SILENT_MS: int = 5000
## A returned traveller's screen has this long to load the farm and say a word before
## the silence clock counts: the host's send, the fade and the load come first
## [PLACEHOLDER].
const ARRIVAL_MS: int = 30000
## A guest's own getting out or in holds this long against older word from the
## host [PLACEHOLDER].
const GRACE_MS: int = 1500
const STOPPED_MPS: float = 0.05
const FARTHEST_M: float = 500.0
## What someone on foot may still ask for [ASSUMPTION].
const ON_FOOT: Array[StringName] = [&"get_into_rover", &"get_up", &"book_expedition", &"book_shuttle", &"go_to_bed", &"read_probe", &"report_place", &"set_loadout", &"shuttle_home", &"spend_xp_certificate", &"set_lab_coat_color"]
const REFUSAL: String = "On foot. Get in the rover first."

## Player -> pose.
var out: Dictionary = {}
## True while the host is asked, so nobody leaves the farm meanwhile.
var asking: bool = false
## Only tests set others.
var session: Node
var farm: Node
var rovers: Node

var _own_changed_at: int = -GRACE_MS
## The host's word, or a guest's own pose: when it was last sent, and its hash.
var _sent_at: int = -STILL_MS
var _sent_hash: int = 0
var _was_guest: bool = false
## Host: player -> when last heard from.
var _heard_at: Dictionary = {}
## Host: player -> [meters they may still go, when that was].
var _reach: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start(CoopSession, GameState, CoopRovers)


func start(with_session: Node, with_farm: Node, with_rovers: Node) -> void:
	session = with_session
	farm = with_farm
	rovers = with_rovers
	session.walked.connect(_on_walked)
	session.walkers_told.connect(_on_told)
	session.player_left.connect(_go_in)
	session.joined.connect(forget.unbind(1))
	farm.farm_loaded.connect(forget)
	# The rover is in another scene, and everyone with it [ASSUMPTION].
	farm.rover_place_changed.connect(_on_rover_place)


func _process(_delta: float) -> void:
	tick(Time.get_ticks_msec())


## Five numbers: what the sender must get right, or be dropped.
func is_shape(pose: Variant) -> bool:
	if not pose is Array or pose.size() != 5:
		return false
	for part: Variant in pose:
		if typeof(part) != TYPE_FLOAT:
			return false
	return true


## Numbers that are real and on the map.
func is_pose(pose: Variant) -> bool:
	if not is_shape(pose):
		return false
	for part: float in pose:
		if not is_finite(part) or absf(part) > FARTHEST_M:
			return false
	return true


## Host: a guest's pose that it may say, which is a pose that does not claim to
## go faster than it can. A pose that is not is refused, not the guest.
func is_sane(pose: Array) -> bool:
	return is_pose(pose) and absf(pose[4]) <= BURST_MPS


func spot(pose: Array) -> Vector3:
	return Vector3(pose[0], pose[1], pose[2])


func is_out(player_id: String) -> bool:
	return out.has(player_id)


## This screen's player is out, or about to be.
func on_foot() -> bool:
	return asking or is_out(farm.local_player_id)


## Host: "" or why not.
func get_out(player_id: String, x: float, z: float, now: int = Time.get_ticks_msec()) -> String:
	var rover_id: String = farm.ROVER
	if is_out(player_id):
		return "You are already out."
	if farm.rover_is_away(rover_id) or not farm.rover_transforms.has(rover_id):
		return "The rover is not on the farm."
	if not rovers.driver(rover_id) in ["", player_id]:
		return "Someone else is driving the rover."
	if absf(rovers.speed(rover_id)) >= STOPPED_MPS:
		return "Stop the rover first."
	var at := Vector3(x, 0.0, z)
	if not at.is_finite() or not _on_land(at):
		return "There is no room to get out here."
	at.y = Terrain.height(Vector2(x, z), farm.dug)
	if not _near_rover(at):
		return "The rover is too far away."
	out[player_id] = [at.x, at.y, at.z, 0.0, 0.0]
	_heard_at[player_id] = now
	_reach.erase(player_id)
	return ""


## Host: puts a player on foot at `at`, as the shuttle's return does (the pad, not the
## rover's side). The caller has judged the place.
func stand(player_id: String, at: Vector3, now: int = Time.get_ticks_msec()) -> void:
	out[player_id] = [at.x, at.y, at.z, 0.0, 0.0]
	_heard_at[player_id] = now
	_reach.erase(player_id)


## Host: a player's first word on the farm after a return: the silence clock starts now.
func heard(player_id: String, now: int = Time.get_ticks_msec()) -> void:
	if is_out(player_id) and _heard_at.get(player_id, 0) > now:
		_heard_at[player_id] = now


## Host: "" or why not.
func get_in(player_id: String) -> String:
	if is_out(player_id) and not _near_rover(spot(out[player_id])):
		return "The rover is too far away."
	_go_in(player_id)
	return ""


## Guest: the host said yes.
func went_out(x: float, z: float) -> void:
	_own_changed_at = Time.get_ticks_msec()
	out[farm.local_player_id] = [x, Terrain.height(Vector2(x, z), farm.dug), z, 0.0, 0.0]


func went_in() -> void:
	_own_changed_at = Time.get_ticks_msec()
	out.erase(farm.local_player_id)


## Where this screen's walker is now. Each tick.
func moved(at: Vector3, yaw: float, speed_mps: float, now: int = Time.get_ticks_msec()) -> void:
	# The walker has a tick left after its player got in.
	if not is_out(farm.local_player_id):
		return
	var pose: Array = [at.x, at.y, at.z, yaw, speed_mps]
	out[farm.local_player_id] = pose
	if _is_guest() and _is_due(pose, now):
		session.walk(pose)


## Host: says who is out and where.
func tick(now: int) -> void:
	var guest: bool = _is_guest()
	if _was_guest and not guest:
		forget()  # left the host's farm
	_was_guest = guest
	if guest:
		return
	for player_id: String in out.keys():
		if player_id == farm.local_player_id:
			continue
		if not player_id in session.players or now - _heard_at.get(player_id, 0) > SILENT_MS:
			_go_in(player_id)
	if session.is_hosting() and session.players.size() > 1 and _is_due(out, now):
		session.tell_walkers(out)


## A field rover starting or going leaves those on foot at the farm where they are.
func _on_rover_place() -> void:
	var only: Variant = farm.get("rover_place_scope")
	if not (only is String and only != ""):
		forget()


func forget() -> void:
	out.clear()
	_heard_at.clear()
	_reach.clear()
	asking = false
	_own_changed_at = -GRACE_MS


## Host: a guest says where it walks.
func _on_walked(player_id: String, pose: Array, now: int = Time.get_ticks_msec()) -> void:
	if not is_out(player_id) or _is_guest():
		return
	_heard_at[player_id] = now
	if not is_sane(pose):
		_refuse(player_id, "a walker at %s" % [pose], now)
		return
	var to: Vector3 = spot(pose)
	var reach: Array = _reach.get(player_id, [BURST_M, now])
	var left: float = minf(BURST_M, reach[0] + (now - reach[1]) * BURST_MPS / 1000.0)
	var distance: float = spot(out[player_id]).distance_to(to)
	if distance > left:
		_refuse(player_id, "a walker %.1f m away, %.1f m allowed" % [distance, left], now)
		return
	if not _on_land(to) or absf(to.y - Terrain.height(Vector2(to.x, to.z), farm.dug)) > HEIGHT_M:
		_refuse(player_id, "a walker off the ground at %s" % [to], now)
		return
	_reach[player_id] = [left - distance, now]
	out[player_id] = pose


## Host: keeps the guest where it was (so everyone else sees it there), logs it
## now and then, and tells the guest at the next tick. The guest's own screen
## only snaps back once it is more than SNAP_M from that place.
func _refuse(player_id: String, what: String, now: int) -> void:
	session.note_refusal(player_id, "refused " + what, now)
	_sent_at = -STILL_MS


## Guest: the host says who is out and where.
func _on_told(poses: Dictionary, now: int = Time.get_ticks_msec()) -> void:
	if not _is_guest():
		return
	var own: String = farm.local_player_id
	var mine: Array = out.get(own, [])
	out = poses.duplicate()
	var told: bool = poses.has(own)
	if told != mine.is_empty():
		# Both say the same. The host may not have taken where this walker went.
		if told and spot(mine).distance_to(spot(poses[own])) <= SNAP_M:
			out[own] = mine
	elif asking or now - _own_changed_at <= GRACE_MS:
		out.erase(own)
		if not mine.is_empty():
			out[own] = mine


func _go_in(player_id: String) -> void:
	out.erase(player_id)
	_heard_at.erase(player_id)
	_reach.erase(player_id)


func _near_rover(at: Vector3) -> bool:
	return rovers.place(farm.ROVER).origin.distance_to(at) <= REACH_M


func _on_land(at: Vector3) -> bool:
	return maxf(absf(at.x), absf(at.z)) <= Terrain.HALF_M and not Terrain.is_deep(Vector2(at.x, at.z))


## True if `what` changed and MOVING_MS went by, or STILL_MS did.
func _is_due(what: Variant, now: int) -> bool:
	if now - _sent_at < (STILL_MS if hash(what) == _sent_hash else MOVING_MS):
		return false
	_sent_at = now
	_sent_hash = hash(what)
	return true


func _is_guest() -> bool:
	return session._farm_commands().guest
