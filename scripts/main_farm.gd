extends Node
## Composition root for the farm slice. Wires rover <-> HUD and routes
## dispatch lines. Holds no gameplay rules of its own.

const DISPATCH_TABLE: StringName = &"dialogue_dispatches"
const MORNING_SECTION: String = "morning_dispatches"

var _had_los: bool = true
var _last_drift_status: int = RoverController.DriftStatus.IN_TOLERANCE

@onready var _rover: RoverController = %Rover
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.soil_tilled.connect(_on_soil_tilled)
	_rover.till_rejected.connect(_on_till_rejected)
	_hud.zero_steering_pressed.connect(_on_zero_pressed)

	var relay_name: String = _rover.satellite_relay.relay_name if _rover.satellite_relay else "NO RELAY"
	_hud.configure(relay_name, _rover.tolerance_deg, _rover.acceptance_ratio)
	_rover.broadcast_state()
	_post_random_morning_dispatch()


func _on_uplink_changed(has_los: bool, quality: float, lag_s: float) -> void:
	_hud.set_uplink(has_los, quality, lag_s)
	if _had_los != has_los:
		_hud.push_log("SYS: LOS %s" % ("restored" if has_los else "lost; uplink lag rising"))
	_had_los = has_los


func _on_drift_changed(drift_deg: float, status: int) -> void:
	_hud.set_drift(drift_deg, status)
	if status == RoverController.DriftStatus.OUT_OF_SPEC and _last_drift_status != status:
		_hud.push_log("SYS: steering exceeds MPE ±%.2f°" % _rover.tolerance_deg)
	_last_drift_status = status


func _on_zero_pressed() -> void:
	_rover.queue_command(RoverController.Command.ZERO_STEERING)
	_hud.push_log("> ZERO STEERING sent (%d ms lag)" % roundi(_rover.get_current_lag() * 1000.0))


func _on_steering_zeroed(as_found_deg: float) -> void:
	_hud.push_log("As-found %+.2f°  As-left +0.00°" % as_found_deg)


func _on_soil_tilled(cell: Vector3i) -> void:
	_hud.push_log("Tilled cell (%d, %d)" % [cell.x, cell.z])


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


## Placeholder for the Week 3 day clock: one random morning dispatch at boot.
func _post_random_morning_dispatch() -> void:
	var dispatches: Array[Dictionary] = DataManager.get_records(DISPATCH_TABLE, MORNING_SECTION)
	if dispatches.is_empty():
		return
	var entry: Dictionary = dispatches.pick_random()
	_hud.push_log("[%s] %s" % [entry.get("sender", "?"), entry.get("text", "")])
