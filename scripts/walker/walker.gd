class_name Walker
extends CharacterBody3D
## This screen's player on foot. The world and the rover stop it; it stops nobody.

## [PLACEHOLDER]
const SPEED_MPS: float = 4.0
const RADIUS_M: float = 0.3
const TALL_M: float = 1.6
const CLIMB_DEG: float = 50.0
const SNAP_M: float = 0.4
const FALL_MPS2: float = 9.8
## The ground and the rocks, and the rover.
const MASK: int = 1 | 2
## Under the ground by this much, it is put back on it.
const UNDER_M: float = 0.3
## Deep water's blocks are this near its body, and it is freed [ASSUMPTION].
const INSIDE_M: float = RADIUS_M - 0.05
## Freed, it stands this far from the blocks, and the search steps this far, to this far.
const FREE_M: float = RADIUS_M + 0.1
const FREE_STEP_M: float = 0.25
const FREE_SEARCH_M: float = 16.0
const FREE_WAYS: int = 24

var camera: Camera3D
var model := WalkerModel.new()


func _init() -> void:
	collision_layer = 0
	collision_mask = MASK
	floor_max_angle = deg_to_rad(CLIMB_DEG)
	floor_snap_length = SNAP_M
	var shape := CollisionShape3D.new()
	shape.shape = capsule()
	shape.position.y = TALL_M / 2.0
	add_child(shape)
	add_child(model)


static func capsule() -> CapsuleShape3D:
	var made := CapsuleShape3D.new()
	made.radius = RADIUS_M
	made.height = TALL_M
	return made


## W is up the screen, whatever way the camera looks. `keys` is right and down.
static func heading(keys: Vector2, view: Basis) -> Vector3:
	var right := Vector3(view.x.x, 0.0, view.x.z).normalized()
	var back := Vector3(view.z.x, 0.0, view.z.z).normalized()
	return (right * keys.x + back * keys.y).limit_length()


func _physics_process(delta: float) -> void:
	var keys := Vector2.ZERO if RoverController.input_blocked else Vector2(
		Input.get_axis(&"rover_steer_left", &"rover_steer_right"),
		Input.get_axis(&"rover_forward", &"rover_reverse"))
	walk(heading(keys, camera.global_basis), delta)
	CoopWalkers.moved(global_position, rotation.y, model.speed_mps)


## Out of water that has just turned deep under it, after a dig or a stone: to the
## nearest place, any way round, that is dry enough and clear of the blocks.
func leave_deep_water() -> void:
	var here := Vector2(global_position.x, global_position.z)
	var to: Vector2 = clear_of_deep_water(here)
	if to == here:
		return
	global_position = Vector3(to.x, Terrain.height(to, GameState.dug), to.y)
	velocity = Vector3.ZERO
	# Said at once, or the farm takes this screen's walker back to where it was.
	CoopWalkers.moved(global_position, rotation.y, 0.0)


## `at`, if it is neither in deep water nor inside a block; else the nearest place
## that is on the land, clear of deep water, rocks and walls. With none, `at`.
static func clear_of_deep_water(at: Vector2) -> Vector2:
	if not _is_stuck(at):
		return at
	var radius: float = FREE_STEP_M
	while radius <= FREE_SEARCH_M:
		var best: Vector2 = at
		var best_gap: float = -1.0
		for way: int in FREE_WAYS:
			var spot: Vector2 = at + Vector2.from_angle(TAU * way / FREE_WAYS) * radius
			if _is_free(spot) and minf(PitWater.gap_m(spot), Ford.gap_m(spot)) > best_gap:
				best = spot
				best_gap = minf(PitWater.gap_m(spot), Ford.gap_m(spot))
		if best_gap >= 0.0:
			return best
		radius += FREE_STEP_M
	return at


static func _is_stuck(at: Vector2) -> bool:
	return Terrain.is_deep(at) or minf(PitWater.gap_m(at), Ford.gap_m(at)) < INSIDE_M


static func _is_free(at: Vector2) -> bool:
	var edge_m: float = Terrain.HALF_M - RADIUS_M
	if maxf(absf(at.x), absf(at.y)) > edge_m or Terrain.is_deep(at):
		return false
	if minf(PitWater.gap_m(at), Ford.gap_m(at)) < FREE_M or HillDressing.clear_of_rocks(at) != at:
		return false
	var middle: Vector2i = Terrain.cell_at(at)
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			if GameState.stone_pieces.get(middle + Vector2i(x, z), -1) == StonePieces.WALL:
				return false
	return true


func walk(to: Vector3, delta: float) -> void:
	var fall: float = 0.0 if is_on_floor() else velocity.y - FALL_MPS2 * delta
	var speed_mps: float = SPEED_MPS
	# Wading, as the rover does.
	var here := Vector2(global_position.x, global_position.z)
	if Terrain.water_depth_m(here) > 0.0 or PitWater.is_wading(here):
		speed_mps *= Terrain.WATER_SPEED
	velocity = to * speed_mps + Vector3.UP * fall
	if to != Vector3.ZERO:
		rotation.y = atan2(-to.x, -to.z)
	var before: Vector3 = global_position
	move_and_slide()
	# The host refuses deep water by its exact edge; the blocks are coarser.
	if Terrain.is_deep(Vector2(global_position.x, global_position.z)) and not Terrain.is_deep(Vector2(before.x, before.z)):
		global_position = Vector3(before.x, global_position.y, before.z)
	var edge_m: float = Terrain.HALF_M - RADIUS_M
	global_position.x = clampf(global_position.x, -edge_m, edge_m)
	global_position.z = clampf(global_position.z, -edge_m, edge_m)
	var ground_m: float = Terrain.height(Vector2(global_position.x, global_position.z), GameState.dug)
	if global_position.y < ground_m - UNDER_M:
		global_position.y = ground_m
		velocity.y = 0.0
	var speed: Vector3 = get_real_velocity()
	model.speed_mps = Vector2(speed.x, speed.z).length()
