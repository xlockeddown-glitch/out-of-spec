class_name FarmWalkers
extends Node3D
## Everyone on foot on the farm, as CoopWalkers has them.

## Where to get out, from the rover's middle: left, right, behind, in front.
const SPOTS: Array[Vector3] = [Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, 2.6), Vector3(0, 0, -2.6)]
## The spot is tried this far above the ground, for a slope.
const LIFT_M: float = 0.35
## A friend's walker catches up at this rate, and beyond this far goes at once [PLACEHOLDER].
const SMOOTH_PER_S: float = 12.0
const JUMP_M: float = 4.0
## Farther than this from where it was, this screen's own was moved by the host.
const MOVED_M: float = 0.5

var rover: RoverController
var camera: IsoCamera

var _own: Walker
## Player -> model.
var _friends: Dictionary[String, WalkerModel] = {}


func _exit_tree() -> void:
	# Whoever leaves the farm is in the rover.
	CoopWalkers.out.erase(GameState.local_player_id)


func _physics_process(_delta: float) -> void:
	var own: String = GameState.local_player_id
	if not CoopWalkers.is_out(own):
		if _own != null:
			_own.queue_free()
			_own = null
			camera.target = rover
		return
	var at: Vector3 = CoopWalkers.spot(CoopWalkers.out[own])
	if _own == null:
		_own = Walker.new()
		_own.name = "Walker"
		_own.camera = camera
		_own.position = at
		_own.rotation.y = rover.global_rotation.y
		add_child(_own)
		camera.target = _own
	elif _own.global_position.distance_to(at) > MOVED_M:
		_own.global_position = at
		_own.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	for player_id: String in _friends.keys():
		if not CoopWalkers.is_out(player_id):
			_friends[player_id].queue_free()
			_friends.erase(player_id)
	for player_id: String in CoopWalkers.out:
		if player_id != GameState.local_player_id:
			_show_friend(player_id, CoopWalkers.out[player_id], delta)


func _show_friend(player_id: String, pose: Array, delta: float) -> void:
	var at: Vector3 = CoopWalkers.spot(pose)
	var share: float = 1.0 - exp(-SMOOTH_PER_S * delta)
	if not _friends.has(player_id):
		_friends[player_id] = WalkerModel.new()
		add_child(_friends[player_id])
		share = 1.0
	var model: WalkerModel = _friends[player_id]
	if model.position.distance_to(at) > JUMP_M:
		share = 1.0
	model.position = model.position.lerp(at, share)
	model.rotation.y = lerp_angle(model.rotation.y, pose[3], share)
	model.speed_mps = pose[4]


## Clear ground beside the rover, or not finite if there is none.
func clear_spot() -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var middle: Vector3 = rover.global_position
	for offset: Vector3 in SPOTS:
		var at: Vector3 = middle + offset.rotated(Vector3.UP, rover.global_rotation.y)
		if maxf(absf(at.x), absf(at.z)) > Terrain.HALF_M - Walker.RADIUS_M:
			continue
		at.y = Terrain.height(Vector2(at.x, at.z), GameState.dug)
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = Walker.capsule()
		shape.collision_mask = Walker.MASK
		shape.transform.origin = at + Vector3.UP * (Walker.TALL_M / 2.0 + LIFT_M)
		var way := PhysicsRayQueryParameters3D.create(
			middle + Vector3.UP, at + Vector3.UP, 1, [rover.get_rid()])
		if space.intersect_shape(shape, 1).is_empty() and space.intersect_ray(way).is_empty():
			return at
	return Vector3.INF


func hint() -> String:
	if _own == null or rover.away_text() != "":
		return ""
	var far_m: float = _own.global_position.distance_to(rover.global_position)
	if far_m <= CoopWalkers.REACH_M:
		return "F: get in the rover"
	return "On foot. The rover is %d m away." % ceili(far_m)
