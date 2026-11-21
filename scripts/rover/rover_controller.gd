class_name RoverController
extends CharacterBody3D
## Satellite-uplinked tractor.
##
## Local input is timestamped and pushed through a simulated uplink whose
## latency depends on line of sight (LOS) to a SatelliteRelay. Driving uses a
## kinematic bicycle model whose steering zero is a DriftModel: it drifts with
## distance driven and with in-game time, until the operator sends a
## ZERO_STEERING command (which also rides the uplink).

signal uplink_changed(has_los: bool, quality: float, lag_s: float)
## status is a DriftModel.Status value.
signal drift_changed(drift_deg: float, status: int)
signal steering_zeroed(as_found_deg: float)
signal soil_tilled(cell: Vector3i)
signal till_rejected(reason: String)

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

	func _init(p_sent_at: float, p_command: int) -> void:
		sent_at = p_sent_at
		command = p_command


@export_group("Scene Links")
@export var satellite_relay: SatelliteRelay
@export var soil_grid: FarmGrid
## LOS ray origin. Falls back to 2 m above the rover origin if unset.
@export var antenna: Node3D

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

@export_group("Steering Drift")
## Key under "instruments" in data/sensor_drift_config.json. Supplies MPE,
## daily_drift_rate (deg/day) and usage_drift_rate (deg/metre).
@export var drift_instrument_id: String = "rover_steering_encoder"
## Clamp so a neglected rover still drives.
@export var max_drift_deg: float = 12.0

## Steering zero error. Read-only from outside; use queue_command() to zero it.
var steering: DriftModel
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
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	steering = DriftModel.from_config(drift_instrument_id, max_drift_deg)
	steering.error_changed.connect(func(error: float, status: int) -> void: drift_changed.emit(error, status))
	steering.zeroed.connect(func(as_found: float) -> void: steering_zeroed.emit(as_found))
	GameClock.time_advanced.connect(steering.advance_days)
	if satellite_relay == null:
		push_warning("%s: no SatelliteRelay linked; uplink will read as occluded." % name)
	if soil_grid == null:
		push_warning("%s: no FarmGrid linked; tilling disabled." % name)


func _exit_tree() -> void:
	# GameClock outlives this scene; don't leave it holding our DriftModel.
	if steering and GameClock.time_advanced.is_connected(steering.advance_days):
		GameClock.time_advanced.disconnect(steering.advance_days)


func _physics_process(delta: float) -> void:
	_uplink_clock += delta
	_update_line_of_sight(delta)
	_sample_local_input()
	_deliver_uplink()
	_drive(delta)


# --- Public API -------------------------------------------------------------

## Queue a one-shot command. It executes after the current uplink lag.
func queue_command(command: Command) -> void:
	_commands.append(UplinkCommand.new(_uplink_clock, command))


func get_current_lag() -> float:
	var t: float = inverse_lerp(occluded_link_quality, 1.0, link_quality)
	return lerpf(lag_occluded_s, lag_clear_s, clampf(t, 0.0, 1.0))


func get_drift_status() -> DriftModel.Status:
	return steering.get_status()


## Re-emit current state, e.g. right after a HUD connects.
func broadcast_state() -> void:
	uplink_changed.emit(has_line_of_sight, link_quality, get_current_lag())
	drift_changed.emit(steering_drift_deg, get_drift_status())


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
	if Input.is_action_just_pressed(&"rover_till"):
		queue_command(Command.TILL)
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
		_execute(cmd.command)


func _execute(command: int) -> void:
	match command:
		Command.TILL:
			_till_under_rover()
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
	steering.add_usage(Vector2(global_position.x - before.x, global_position.z - before.z).length())


func _zero_steering() -> void:
	# DriftModel emits zeroed + error_changed, which re-emit as rover signals.
	steering.zero()


# --- Tilling ----------------------------------------------------------------

func _till_under_rover() -> void:
	if soil_grid == null:
		till_rejected.emit("No soil grid linked.")
		return
	var cell: Vector3i = soil_grid.world_to_cell(global_position)
	match soil_grid.till_cell(cell):
		FarmGrid.TillResult.TILLED:
			soil_tilled.emit(cell)
		FarmGrid.TillResult.ALREADY_TILLED:
			till_rejected.emit("Cell (%d, %d) already tilled." % [cell.x, cell.z])
		FarmGrid.TillResult.NOT_SOIL:
			till_rejected.emit("No soil under tractor.")

