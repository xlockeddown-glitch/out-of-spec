class_name RoverController
extends CharacterBody3D
## Satellite-uplinked tractor.
##
## Local input is timestamped and pushed through a simulated uplink whose
## latency depends on line of sight (LOS) to a SatelliteRelay. Driving uses a
## kinematic bicycle model whose steering zero is GameState.steering (a
## DriftingSensor): it drifts with distance driven and with in-game time, until
## the operator sends a ZERO_STEERING command (which also rides the uplink).
## A slotted optical silk spool on the relay multiplies the lag down.

signal uplink_changed(has_los: bool, quality: float, lag_s: float)
## band is a DriftingSensor.Band value.
signal drift_changed(drift_deg: float, band: int)
signal steering_zeroed(record: Dictionary)
signal soil_tilled(cell: Vector3i)
signal till_rejected(reason: String)
## Space on a cell that is already tilled: plant, check or harvest it.
## `seed_id` and `offset_steps` are the seed and planting offset selected when
## the command was sent.
signal tilled_cell_used(cell: Vector3i, seed_id: String, offset_steps: int)
signal ore_mined(fissure_id: StringName)
## A boulder was drilled, `hits` times by now.
signal boulder_hit(hits: int)
signal dig_rejected(reason: String)
signal fill_rejected(reason: String)

## Following another player's driving: how fast it closes in, and from how far it
## jumps there instead; and how far ahead of the last word it runs [PLACEHOLDER].
const FOLLOW_PER_S: float = 12.0
const FOLLOW_JUMP_M: float = 4.0
const FOLLOW_LEAD_S: float = 0.15

enum Command { TILL, ZERO_STEERING, DIG, FILL }


## One timestamped control sample travelling up the link.
class UplinkFrame:
	var sent_at: float
	var throttle: float
	var steer: float

	func _init(p_sent_at: float, p_throttle: float, p_steer: float) -> void:
		sent_at = p_sent_at
		throttle = p_throttle
		steer = p_steer


## One-shot command travelling up the link.
class UplinkCommand:
	var sent_at: float
	var command: int
	## Seed selected when a TILL was sent, so switching seeds while the
	## command is in flight doesn't change what gets planted.
	var seed_id: String
	## Planting offset (set point steps) selected when a TILL was sent.
	var offset_steps: int

	func _init(p_sent_at: float, p_command: int, p_seed_id: String = "", p_offset_steps: int = 0) -> void:
		sent_at = p_sent_at
		command = p_command
		seed_id = p_seed_id
		offset_steps = p_offset_steps


## Key of this rover in GameState.rover_transforms.
@export var rover_id: String = "rover_1"

@export_group("Scene Links")
@export var satellite_relay: SatelliteRelay
@export var soil_grid: FarmGrid
## LOS ray origin. Falls back to 2 m above the rover origin if unset.
@export var antenna: Node3D
## Parent of OreFissure nodes. The till/drill action mines a fissure in reach
## before it tries to till soil.
@export var ore_fissures_root: Node3D
## Parent of Boulder nodes. One close in front is drilled before soil is tilled.
@export var boulders_root: Node3D
## What VisualRoot lies on. Always level if unset.
@export var ground: TerrainGround
## Greybox wheels (VisualRoot children named Wheel*) widen with Bram's treads.
@export var wheel_width_m: float = 0.3
@export var wide_wheel_width_m: float = 0.55
## Voxel model swapped in once Bram fits the treads (needs tractor.glb loaded too).
@export_file("*.glb", "*.gltf", "*.tscn") var wide_tread_model_path: String = "res://assets/voxels/tractor_wide.glb"

@export_group("Drive")
@export var max_speed_mps: float = 6.0
@export var reverse_speed_mps: float = 3.0
@export var acceleration_mps2: float = 8.0
@export var braking_mps2: float = 12.0
@export var max_steer_deg: float = 32.0
@export var wheelbase_m: float = 2.2
## Half the width between its wheels, for lying on a slope [PLACEHOLDER].
@export var half_track_m: float = 0.8
## How fast it tips onto a new slope [PLACEHOLDER].
@export var tip_per_s: float = 10.0
## It keeps to ground that falls away this far in a tick [PLACEHOLDER].
@export var ground_snap_m: float = 0.5
## It digs the cell this far ahead of its middle [PLACEHOLDER].
@export var dig_reach_m: float = 2.0
## Half the length of its body, for staying above ground that rises.
@export var half_length_m: float = 1.2

@export_group("Uplink")
@export var lag_clear_s: float = 0.05
@export var lag_occluded_s: float = 0.45
## Link quality (0..1) while occluded. Clear LOS = 1.0.
@export_range(0.0, 1.0) var occluded_link_quality: float = 0.25
## Quality change per second. Lag is derived from quality, so this also sets
## how fast lag ramps between clear and occluded. Set very high to snap.
@export var link_slew_per_s: float = 3.0
@export_flags_3d_physics var los_collision_mask: int = 4

## Steering zero error (lives in GameState). Use queue_command() to zero it.
var steering: DriftingSensor
var steering_drift_deg: float:
	get:
		return steering.error if steering else 0.0
var link_quality: float = 1.0
var has_line_of_sight: bool = true

var _uplink_clock: float = 0.0
var _speed_mps: float = 0.0
var _applied_throttle: float = 0.0
var _applied_steer: float = 0.0
var _frames: Array[UplinkFrame] = []
var _commands: Array[UplinkCommand] = []
## Seeds selected at each till key press since the last physics tick, so a C
## pressed before the tick can't change them and no press is lost.
## Each entry is {"seed": String, "offset": int}.
var _till_presses: Array[Dictionary] = []
## Where the scene puts this rover, for a farm that has not parked it yet.
var _start_transform: Transform3D
## Another player drives, or on a guest nobody does: it shows where it is told.
var _following: bool = false
var _visual: Node3D
var _tip := Quaternion.IDENTITY
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	steering = GameState.steering
	# Bound methods (not lambdas) so Godot drops these connections when the
	# rover is freed on a scene swap; the sensor outlives us.
	steering.error_changed.connect(_on_steering_error_changed)
	GameState.upgrades_changed.connect(_apply_upgrades)
	SaveGame.saving.connect(_park)
	GameState.farm_loaded.connect(_unpark)
	GameState.rover_place_changed.connect(_show_place)
	_apply_upgrades()
	floor_snap_length = ground_snap_m
	_visual = get_node_or_null("VisualRoot") as Node3D
	_start_transform = global_transform
	_show_place()
	if satellite_relay == null:
		push_warning("%s: no SatelliteRelay linked; uplink will read as occluded." % name)
	# The tunnels have no soil and no ground to dig.
	if soil_grid == null and ground != null:
		push_warning("%s: no FarmGrid linked; tilling disabled." % name)


func _exit_tree() -> void:
	_park()


func _unpark() -> void:
	global_transform = CoopRovers.place(rover_id) if CoopRovers.together() and CoopRovers.has_place(rover_id) else GameState.parked_rover_transform(rover_id, _start_transform)
	_put_back_on_land()


## A farm saved before the hills may have it parked inside one, or off the land.
## In the tunnels, one in the rock is back at the mouth.
func _put_back_on_land() -> void:
	if rover_id == GameState.TUNNEL_ROVER and not TunnelRock.holds(global_position):
		global_transform = GameState.TUNNEL_START
	if ground == null:
		return
	var edge_m: float = Terrain.HALF_M - wheelbase_m
	global_position.x = clampf(global_position.x, -edge_m, edge_m)
	global_position.z = clampf(global_position.z, -edge_m, edge_m)
	# Or where a rock now stands.
	var clear: Vector2 = HillDressing.clear_of_rocks(Vector2(global_position.x, global_position.z))
	global_position.x = clear.x
	global_position.z = clear.y
	var ground_m: float = ground.height_at(global_position)
	# Resting on level ground it may be a hair under.
	if global_position.y < ground_m - 0.1:
		# Above its uphill corners; it drops the rest of the way.
		global_position.y = ground_m + ground_snap_m


func _park() -> void:
	# Whoever drives says where it is.
	if _following or GameState.rover_is_away(rover_id):
		return
	FarmCommands.rover_parked(rover_id, global_transform)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"rover_till", false):
		_till_presses.append({"seed": GameState.current_seed(), "offset": GameState.planting_offset_steps})


func _physics_process(delta: float) -> void:
	_uplink_clock += delta
	_update_line_of_sight(delta)
	var throttle: float = Input.get_axis(&"rover_reverse", &"rover_forward")
	var moves: bool = CoopRovers.moves_here(rover_id, throttle != 0.0 or (not _following and not is_stopped()))
	if moves == _following:
		_set_following(not moves)
	_sample_local_input(throttle if moves else 0.0)
	_deliver_uplink()
	if moves:
		_drive(delta)
		CoopRovers.moved(rover_id, global_transform, _speed_mps, has_line_of_sight)
		FarmCommands.rover_at(rover_id, global_position, _speed_mps)
	else:
		_follow(delta)
	_lie_on_ground(delta)


# --- Public API -------------------------------------------------------------

## Queue a one-shot command. It executes after the current uplink lag. A TILL
## carries `seed_id` and `offset_steps`, or the current ones if no seed is given.
func queue_command(command: Command, seed_id: String = "", offset_steps: int = 0) -> void:
	if GameState.rover_is_away(rover_id):
		return
	if command == Command.TILL and seed_id == "":
		seed_id = GameState.current_seed()
		offset_steps = GameState.planting_offset_steps
	_commands.append(UplinkCommand.new(_uplink_clock, command, seed_id, offset_steps))


func get_current_lag() -> float:
	var t: float = inverse_lerp(occluded_link_quality, 1.0, link_quality)
	var base_lag: float = lerpf(lag_occluded_s, lag_clear_s, clampf(t, 0.0, 1.0))
	return base_lag * GameState.get_relay_lag_multiplier()


## Observed band, for the HUD (Ryan, 2026-11-22: displays show what the bench
## last measured, so a bad standard can fool the player).
func get_drift_band() -> DriftingSensor.Band:
	return steering.get_observed_band()


## True once the rover has braked to a standstill (the field cal pad needs it).
func is_stopped() -> bool:
	return absf(_speed_mps) < 0.05


## "" if the rover is in this scene, or where it is.
func away_text() -> String:
	if not GameState.rover_is_away(rover_id):
		return ""
	return "The rover is %s. Press E to go there." % ("in the tunnels" if GameState.rover_in_tunnels else "on the farm")


## The one rover is on the farm or in the tunnels. In the other scene it is gone.
func _show_place() -> void:
	var away: bool = GameState.rover_is_away(rover_id)
	visible = not away
	process_mode = Node.PROCESS_MODE_DISABLED if away else Node.PROCESS_MODE_INHERIT
	# Nothing sent before counts after.
	_frames.clear()
	_commands.clear()
	_till_presses.clear()
	_applied_throttle = 0.0
	_applied_steer = 0.0
	_speed_mps = 0.0
	velocity = Vector3.ZERO
	if not away:
		_unpark()
	broadcast_state()


## Re-emit current state, e.g. right after a HUD connects.
func broadcast_state() -> void:
	uplink_changed.emit(has_line_of_sight, link_quality, get_current_lag())
	drift_changed.emit(steering.observed_error, get_drift_band())


# --- Uplink -----------------------------------------------------------------

func _update_line_of_sight(delta: float) -> void:
	var los: bool = _raycast_to_relay()
	if satellite_relay != null:
		FarmCommands.rover_uplink(rover_id, los)
	var target_quality: float = 1.0 if los else occluded_link_quality
	var new_quality: float = move_toward(link_quality, target_quality, link_slew_per_s * delta)
	if los == has_line_of_sight and is_equal_approx(new_quality, link_quality):
		return
	has_line_of_sight = los
	link_quality = new_quality
	uplink_changed.emit(has_line_of_sight, link_quality, get_current_lag())


func _raycast_to_relay() -> bool:
	if satellite_relay == null:
		return false
	var from: Vector3 = antenna.global_position if antenna else global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(
		from, satellite_relay.get_uplink_point(), los_collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _sample_local_input(throttle: float) -> void:
	# +steer = left = +yaw about Y.
	var steer: float = Input.get_axis(&"rover_steer_right", &"rover_steer_left")
	_frames.append(UplinkFrame.new(_uplink_clock, throttle, steer))
	for press: Dictionary in _till_presses:
		queue_command(Command.TILL, str(press["seed"]), int(press["offset"]))
	_till_presses.clear()
	if Input.is_action_just_pressed(&"rover_zero_steering"):
		queue_command(Command.ZERO_STEERING)


## Releases everything sent at or before (now - lag). If lag shrinks, several
## frames arrive at once and the newest wins; if lag grows, the rover holds the
## last command it received. Same as a real buffered link.
func _deliver_uplink() -> void:
	var arrival_cutoff: float = _uplink_clock - get_current_lag()
	while not _frames.is_empty() and _frames[0].sent_at <= arrival_cutoff:
		var frame: UplinkFrame = _frames.pop_front()
		_applied_throttle = frame.throttle
		_applied_steer = frame.steer
	while not _commands.is_empty() and _commands[0].sent_at <= arrival_cutoff:
		var cmd: UplinkCommand = _commands.pop_front()
		_execute(cmd)


func _execute(cmd: UplinkCommand) -> void:
	match cmd.command:
		Command.TILL:
			_till_under_rover(cmd.seed_id, cmd.offset_steps)
		Command.ZERO_STEERING:
			_zero_steering()
		Command.DIG:
			_change_ground(true)
		Command.FILL:
			_change_ground(false)


# --- Drive & drift ----------------------------------------------------------

func _drive(delta: float) -> void:
	var top_speed: float = max_speed_mps if _applied_throttle >= 0.0 else reverse_speed_mps
	var target_speed: float = _applied_throttle * top_speed
	var rate: float = acceleration_mps2 if absf(target_speed) > absf(_speed_mps) else braking_mps2
	_speed_mps = move_toward(_speed_mps, target_speed, rate * delta)

	if absf(_speed_mps) > 0.01:
		# Kinematic bicycle model: yaw rate = v / L * tan(steer angle).
		# Drift is an offset on the steering zero, so a hands-off rover curves.
		var steer_rad: float = deg_to_rad(_applied_steer * max_steer_deg + steering_drift_deg)
		rotate_y(_speed_mps / wheelbase_m * tan(steer_rad) * delta)

	var forward: Vector3 = -global_transform.basis.z
	velocity.x = forward.x * _speed_mps
	velocity.z = forward.z * _speed_mps
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	var before: Vector3 = global_position
	move_and_slide()
	# Horizontal displacement actually achieved; pushing into a rock adds no drift.
	var driven: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	FarmCommands.rover_drove(driven)


func _set_following(following: bool) -> void:
	_following = following
	# No key pressed before counts after. Commands on their way still arrive.
	_frames.clear()
	_applied_throttle = 0.0
	_applied_steer = 0.0
	_speed_mps = 0.0
	velocity = Vector3.ZERO
	# The host goes on from the very place, a guest from where it shows it.
	if not following and not FarmCommands.guest:
		global_transform = CoopRovers.place(rover_id)
	if not following:
		# The ground may have risen while it was shown.
		keep_above_ground()
		_put_back_on_land()


func _follow(delta: float) -> void:
	_speed_mps = CoopRovers.speed(rover_id)
	if not CoopRovers.has_place(rover_id):
		return
	var to: Transform3D = CoopRovers.place(rover_id, FOLLOW_LEAD_S)
	if global_position.distance_to(to.origin) > FOLLOW_JUMP_M:
		global_transform = to
	else:
		global_transform = global_transform.interpolate_with(to, 1.0 - exp(-FOLLOW_PER_S * delta))


## Only what is seen lies on a slope. The body stays upright, so its heading is
## its yaw, and it rests on its highest corner, so what is seen sits lower.
func _lie_on_ground(delta: float) -> void:
	if ground == null or _visual == null:
		return
	var lies: Basis = ground.lie_at(global_position, -global_basis.z, wheelbase_m * 0.5, half_track_m)
	var share: float = 1.0 - exp(-tip_per_s * delta)
	_tip = _tip.slerp((global_basis.inverse() * lies).get_rotation_quaternion(), share)
	_visual.basis = Basis(_tip)
	var highest_m: float = ground.height_at(global_position)
	var middle_m: float = highest_m
	for side: float in [-half_track_m, half_track_m]:
		for end: float in [-wheelbase_m * 0.5, wheelbase_m * 0.5]:
			highest_m = maxf(highest_m, ground.height_at(to_global(Vector3(side, 0.0, end))))
	# Another player's rover is told its height late, so it is seen on the ground.
	var sits_m: float = middle_m - (global_position.y if _following else highest_m)
	_visual.position.y = lerpf(_visual.position.y, sits_m, share)


## Lifts it out of ground that rose under it. To ground that sank it falls.
func keep_above_ground() -> void:
	if ground != null:
		global_position.y = maxf(global_position.y, ground.highest_under(global_transform, half_length_m, half_track_m))


func _zero_steering() -> void:
	var record: Dictionary = await FarmCommands.request(&"zero_steering")
	if is_inside_tree():
		steering_zeroed.emit(record)


func _on_steering_error_changed(_error: float, _band: int) -> void:
	# The HUD gets the observed error; the steering pull keeps the true one.
	drift_changed.emit(steering.observed_error, get_drift_band())


# --- Tilling ----------------------------------------------------------------

func _till_under_rover(seed_id: String, offset_steps: int) -> void:
	if await _try_mine() or not is_inside_tree():
		return
	if await _try_boulder() or not is_inside_tree():
		return
	if soil_grid == null:
		till_rejected.emit("This is rock, not soil.")
		return
	var cell: Vector3i = soil_grid.world_to_cell(global_position)
	var result: FarmGrid.TillResult = await soil_grid.till_cell(cell)
	if not is_inside_tree():
		return
	match result:
		FarmGrid.TillResult.TILLED:
			soil_tilled.emit(cell)
		FarmGrid.TillResult.ALREADY_TILLED:
			tilled_cell_used.emit(cell, seed_id, offset_steps)
		FarmGrid.TillResult.NOT_SOIL:
			till_rejected.emit("No soil under tractor.")
		FarmGrid.TillResult.REFUSED:
			till_rejected.emit("The host did not till it.")


## The cell of Terrain it digs: the one in front of it.
func dig_cell() -> Vector2i:
	var at: Vector3 = to_global(Vector3.FORWARD * dig_reach_m)
	return Terrain.cell_at(Vector2(at.x, at.z))


## Digs or fills in front of it. It must stand, so that the cell outlined is the
## cell dug [ASSUMPTION].
func _change_ground(deeper: bool) -> void:
	var rejected: Signal = dig_rejected if deeper else fill_rejected
	if ground == null:
		rejected.emit("This rock can't be dug." if deeper else "There is nothing to fill here.")
		return
	if not is_stopped():
		rejected.emit("Stop the rover first.")
		return
	var cell := Vector3i(dig_cell().x, 0, dig_cell().y)
	var problem: String
	if deeper:
		problem = await FarmCommands.request(&"dig", [cell])
	else:
		problem = await FarmCommands.request(&"fill", [cell])
	if problem != "" and is_inside_tree():
		rejected.emit(problem)


## The soil cell under the rover (y = 0), or (0, -1, 0) without a grid.
func cell_under() -> Vector3i:
	if soil_grid == null:
		return Vector3i(0, -1, 0)
	return soil_grid.world_to_cell(global_position)


## True if a fissure in reach was tried, so the ground is not tilled.
func _try_mine() -> bool:
	if ore_fissures_root == null:
		return false
	var nearest: OreFissure = null
	var best: float = INF
	for child: Node in ore_fissures_root.get_children():
		var fissure := child as OreFissure
		if fissure and fissure.is_available() and fissure.is_in_reach(global_position):
			var d: float = fissure.global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				nearest = fissure
	if nearest == null:
		return false
	var id: StringName = nearest.fissure_id
	var mined: bool = await FarmCommands.request(&"mine_fissure", [id])
	if not is_inside_tree():
		return true
	if mined:
		ore_mined.emit(id)
	else:
		till_rejected.emit("The fissure was not drilled.")
	return true


## True if a boulder close in front was tried, so the ground is not tilled.
func _try_boulder() -> bool:
	if boulders_root == null:
		return false
	for child: Node in boulders_root.get_children():
		var boulder := child as Boulder
		if boulder == null or not boulder.is_in_reach(to_global(Vector3.FORWARD * half_length_m)):
			continue
		var hits: int = await FarmCommands.request(&"hit_boulder", [boulder.name])
		if is_inside_tree():
			if hits > 0:
				boulder_hit.emit(hits)
			else:
				till_rejected.emit("The boulder was not drilled.")
		return true
	return false


func _apply_upgrades() -> void:
	var width: float = wide_wheel_width_m if GameState.has_wide_treads else wheel_width_m
	var visual: Node = get_node_or_null("VisualRoot")
	if visual == null:
		return
	var slot := visual as ModelSlot
	if GameState.has_wide_treads and slot and slot.has_model() and slot.model_path != wide_tread_model_path:
		slot.swap_model(wide_tread_model_path)
	for child: Node in visual.get_children():
		if child is CSGCylinder3D and child.name.begins_with("Wheel"):
			(child as CSGCylinder3D).height = width
