extends Node
## Composition root for the farm scene. Wires rover / GameState <-> HUD and
## routes dispatch lines. Holds no gameplay rules of its own.

const DISPATCH_TABLE: StringName = &"dialogue_dispatches"
const MORNING_SECTION: String = "morning_dispatches"

## Only the first farm visit gets a morning dispatch, not every swap back.
static var _posted_boot_dispatch: bool = false

var _had_los: bool = true
var _last_band: int = DriftingSensor.Band.IN_BAND

@onready var _rover: RoverController = %Rover
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _airlock: Clickable = %Airlock


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.soil_tilled.connect(_on_soil_tilled)
	_rover.till_rejected.connect(_on_till_rejected)
	_hud.zero_steering_pressed.connect(_on_zero_pressed)
	_hud.slot_spool_pressed.connect(_on_slot_spool_pressed)
	_hud.enter_dome_pressed.connect(_go_to_dome)
	_airlock.clicked.connect(_go_to_dome)
	# Bound methods so the autoload drops them when this scene is freed.
	GameState.silk_changed.connect(_on_silk_changed)
	GameState.relay_changed.connect(_on_relay_changed)

	var relay_name: String = _rover.satellite_relay.relay_name if _rover.satellite_relay else "NO RELAY"
	_hud.configure(relay_name, _rover.steering.mpe, _rover.steering.acceptance_ratio)
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	if not _posted_boot_dispatch:
		_posted_boot_dispatch = true
		_post_random_morning_dispatch()


func _on_uplink_changed(has_los: bool, quality: float, lag_s: float) -> void:
	_hud.set_uplink(has_los, quality, lag_s)
	if _had_los != has_los:
		_hud.push_log("SYS: LOS %s" % ("restored" if has_los else "lost; uplink lag rising"))
	_had_los = has_los


func _on_drift_changed(drift_deg: float, band: int) -> void:
	_hud.set_drift(drift_deg, band)
	if band == DriftingSensor.Band.OUT_OF_TOLERANCE and _last_band != band:
		_hud.push_log("SYS: steering exceeds MPE ±%.2f°" % _rover.steering.mpe)
	_last_band = band


func _on_zero_pressed() -> void:
	_rover.queue_command(RoverController.Command.ZERO_STEERING)
	_hud.push_log("> ZERO STEERING sent (%d ms lag)" % roundi(_rover.get_current_lag() * 1000.0))


func _on_steering_zeroed(record: Dictionary) -> void:
	_hud.push_log("As-found %+.2f°  As-left %+.2f°" % [record.get("as_found", 0.0), record.get("as_left", 0.0)])


func _on_slot_spool_pressed() -> void:
	if GameState.slot_spool_into_relay():
		_hud.push_log("Optical silk spool installed. Uplink lag x%.2f." % GameState.get_relay_lag_multiplier())


func _on_silk_changed(_spools: int) -> void:
	_refresh_relay_hud()


func _on_relay_changed(_slotted: bool) -> void:
	_refresh_relay_hud()
	_rover.broadcast_state()  # lag readout picks up the relay multiplier


func _refresh_relay_hud() -> void:
	_hud.set_relay(GameState.relay_slotted, GameState.optical_silk_spools, GameState.can_slot_spool())


func _on_soil_tilled(cell: Vector3i) -> void:
	_hud.push_log("Tilled cell (%d, %d)" % [cell.x, cell.z])


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


func _go_to_dome() -> void:
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)


## Placeholder for the Week 3 day clock: one random morning dispatch at boot.
func _post_random_morning_dispatch() -> void:
	var dispatches: Array[Dictionary] = DataManager.get_records(DISPATCH_TABLE, MORNING_SECTION)
	if dispatches.is_empty():
		return
	var entry: Dictionary = dispatches.pick_random()
	_hud.push_log("[%s] %s" % [entry.get("sender", "?"), entry.get("text", "")])
