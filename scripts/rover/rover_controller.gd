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
## `seed_id` is the seed selected when the command was sent.
signal tilled_cell_used(cell: Vector3i, seed_id: String)
signal ore_mined(fissure_id: StringName)

enum Command { TILL, ZERO_STEERING }


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

	func _init(p_sent_at: float, p_command: int, p_seed_id: String = "") -> void:
		sent_at = p_sent_at
		command = p_command
		seed_id = p_seed_id


@export_group("Scene Links")
@export var satellite_relay: SatelliteRelay
@export var soil_grid: FarmGrid
## LOS ray origin. Falls back to 2 m above the rover origin if unset.
@export var antenna: Node3D
## Parent of OreFissure nodes. The till/drill action mines a fissure in reach
## before it tries to till soil.
@export var ore_fissures_root: Node3D
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
var _till_presses: Array[String] = []
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	steering = GameState.steering
	# Bound methods (not lambdas) so Godot drops these connections when the
	# rover is freed on a scene swap; the sensor outlives us.
	steering.error_changed.connect(_on_steering_error_changed)
	GameState.upgrades_changed.connect(_apply_upgrades)
	_apply_upgrades()
	if GameState.has_rover_transform:
		global_transform = GameState.rover_transform
	if satellite_relay == null:
		push_warning("%s: no SatelliteRelay linked; uplink will read as occluded." % name)
	if soil_grid == null:
		push_warning("%s: no FarmGrid linked; tilling disabled." % name)


func _exit_tree() -> void:
	GameState.rover_transform = global_transform
	GameState.has_rover_transform = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"rover_till", false):
		_till_presses.append(GameState.current_seed())


func _physics_process(delta: float) -> void:
	_uplink_clock += delta
	_update_line_of_sight(delta)
	_sample_local_input()
	_deliver_uplink()
	_drive(delta)


# --- Public API -------------------------------------------------------------

## Queue a one-shot command. It executes after the current uplink lag. A TILL
## carries `seed_id`, or the current seed if none is given.
func queue_command(command: Command, seed_id: String = "") -> void:
	if command == Command.TILL and seed_id == "":
		seed_id = GameState.current_seed()
	_commands.append(UplinkCommand.new(_uplink_clock, command, seed_id))


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


## Re-emit current state, e.g. right after a HUD connects.
func broadcast_state() -> void:
	uplink_changed.emit(has_line_of_sight, link_quality, get_current_lag())
	drift_changed.emit(steering.observed_error, get_drift_band())


# --- Uplink -----------------------------------------------------------------

func _update_line_of_sight(delta: float) -> void:
	var los: bool = _raycast_to_relay()
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


func _sample_local_input() -> void:
	var throttle: float = Input.get_axis(&"rover_reverse", &"rover_forward")
	# +steer = left = +yaw about Y.
	var steer: float = Input.get_axis(&"rover_steer_right", &"rover_steer_left")
	_frames.append(UplinkFrame.new(_uplink_clock, throttle, steer))
	for seed_id: String in _till_presses:
		queue_command(Command.TILL, seed_id)
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
			_till_under_rover(cmd.seed_id)
		Command.ZERO_STEERING:
			_zero_steering()


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
	steering.add_usage(driven)
	GameState.add_tire_usage(driven)


func _zero_steering() -> void:
	# Same calibration path as the bench, so the record lands in GameState.
	# A remote zero has no standard: untraceable, judged against the MPE only.
	steering_zeroed.emit(GameState.calibrate(GameState.STEERING_ID, "You", false))


func _on_steering_error_changed(_error: float, _band: int) -> void:
	# The HUD gets the observed error; the steering pull keeps the true one.
	drift_changed.emit(steering.observed_error, get_drift_band())


# --- Tilling ----------------------------------------------------------------

func _till_under_rover(seed_id: String) -> void:
	if _try_mine():
		return
	if soil_grid == null:
		till_rejected.emit("No soil grid linked.")
		return
	var cell: Vector3i = soil_grid.world_to_cell(global_position)
	match soil_grid.till_cell(cell):
		FarmGrid.TillResult.TILLED:
			soil_tilled.emit(cell)
		FarmGrid.TillResult.ALREADY_TILLED:
			tilled_cell_used.emit(cell, seed_id)
		FarmGrid.TillResult.NOT_SOIL:
			till_rejected.emit("No soil under tractor.")


## The soil cell under the rover (y = 0), or (0, -1, 0) without a grid.
func cell_under() -> Vector3i:
	if soil_grid == null:
		return Vector3i(0, -1, 0)
	return soil_grid.world_to_cell(global_position)


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
	if nearest and GameState.mine_fissure(nearest.fissure_id):
		ore_mined.emit(nearest.fissure_id)
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
