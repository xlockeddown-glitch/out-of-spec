class_name IceCaves
extends "res://scripts/basalt_tunnels.gd"
## The Polar Ice Caves' scene (zones step 15): the Lava Tubes' scene with the caves' hub (the
## way down, a notice board, the heater crate, pale ice walls) and its one depth (rooms and
## finds, no rockfalls). Built in code from primitives (IceLook); the rules are IceDepth's and
## the host's. The cold is GameState's (`cold_since`); this scene only tells it on the HUD.
## A look [PLACEHOLDER]: no art yet.

const CRATE: String = "crate"
const SIGN: String = "sign"

## The cold reading last told, in steps of COLD_STEP percent, and whether it was past the threshold.
const COLD_STEP: int = 10
var _told_cold_step: int = -1
var _told_drift: bool = false
var _decor: Node3D


func _zone_id() -> String:
	return IceDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_decor = Node3D.new()
	_decor.name = "IceDecor"
	_rover.get_parent().add_child(_decor)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		_build_depth_decor()
		GameState.finds_changed.connect(_on_finds_changed)
	else:
		_depth_props.build_hatch()
		IceLook.add_heater_crate(_depth_props, IceDepth.crate_position())
		_draw_walls()
		_draw_sign()
		_build_hub_decor()


## Hub dressing: hanging icicles along wall tops and the north arch, flush
## floor frost patches, a half-buried frozen probe tucked against the east wall,
## and an ice-core drill rack flat against the north wall (visual only, zero
## collision, rover path clear) [PLACEHOLDER].
func _build_hub_decor() -> void:
	var hatch: Vector3 = IceDepth.hatch_position()
	var sign_pos: Vector3 = IceDepth.sign_position()
	IceLook.add_frost_patch(_decor, Vector3(-1.5, 0.0, 20.5), Vector2(3.2, 2.4), 6.0)
	IceLook.add_frost_patch(_decor, Vector3(-7.5, 0.0, 19.5), Vector2(2.8, 2.2), -12.0)
	IceLook.add_frost_patch(_decor, Vector3(-1.5, 0.0, 14.0), Vector2(2.4, 2.8), 4.0)
	IceLook.add_icicle_cluster(_decor, Vector3(-1.5, 2.85, 10.5), 4.2, 0.85, 0.0)
	IceLook.add_icicle_cluster(_decor, Vector3(hatch.x - 6.9, 2.6, hatch.z + 4.5), 3.6, 0.85, 90.0)
	IceLook.add_icicle_cluster(_decor, Vector3(hatch.x + 6.9, 2.6, hatch.z + 4.5), 3.6, 0.85, -90.0)
	IceLook.add_icicle_cluster(_decor, Vector3(sign_pos.x, 2.2, sign_pos.z + 1.3), 3.8, 0.70, 0.0)
	IceLook.add_frozen_probe(_decor, Vector3(4.6, 0.0, 19.2), -28.0)
	IceLook.add_drill_rack(_decor, Vector3(-6.2, 0.0, 15.4), 0.0)


## Depth 1 dressing: flush frost patches along the landing and trunk, hanging
## icicles along passage walls, a frozen probe tucked against the west landing
## wall, and an ice-core drill rack flat against the east landing wall (visual
## only, zero collision, rover path clear) [PLACEHOLDER].
func _build_depth_decor() -> void:
	IceLook.add_frost_patch(_decor, Vector3(0.0, 0.0, 16.5), Vector2(3.0, 2.2), 8.0)
	IceLook.add_frost_patch(_decor, Vector3(0.0, 0.0, 3.0), Vector2(2.6, 3.0), -6.0)
	IceLook.add_frost_patch(_decor, Vector3(0.0, 0.0, -7.5), Vector2(2.6, 3.0), 10.0)
	IceLook.add_icicle_cluster(_decor, Vector3(-2.6, 2.8, 7.5), 3.2, 0.90, 90.0)
	IceLook.add_icicle_cluster(_decor, Vector3(2.6, 2.8, -1.5), 3.2, 0.90, -90.0)
	IceLook.add_icicle_cluster(_decor, Vector3(0.0, 2.8, -13.5), 3.6, 0.85, 0.0)
	IceLook.add_frozen_probe(_decor, Vector3(-11.4, 0.0, 15.0), 35.0)
	IceLook.add_drill_rack(_decor, Vector3(8.4, 0.0, 16.5), -90.0)


## Pale layered ice along the hub's west and east edges and behind the board [PLACEHOLDER].
func _draw_walls() -> void:
	var hatch: Vector3 = IceDepth.hatch_position()
	for side: float in [-1.0, 1.0]:
		IceLook.add_ice_wall(_depth_props, Vector3(hatch.x + side * 7.5, 0.0, hatch.z + 4.5), Vector2(1.4, 5.0), 2.6)
	IceLook.add_ice_wall(_depth_props, IceDepth.sign_position() + Vector3(0.0, 0.0, 1.8), Vector2(5.0, 1.0), 2.2)


## The notice board: the Lava hub's with frosted ice trim and Vance's notice for later [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("Vance: [later]")
	board.name = "NoticeSign"
	board.position = IceDepth.sign_position()
	_depth_props.add_child(board)
	IceLook.add_sign_trim(board)


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	_in_reach = false  # no Sentinel here
	_hub_near = _ice_near() if _rover.away_text() == "" else {}
	_tell_hub()
	_tell_cold()


## The way down, the crate or the sign at the hub; below, the nearest find: or {}.
func _ice_near() -> Dictionary:
	if _below:
		return _nearest_find()
	var at: Vector3 = _rover.global_position
	if IceDepth.near_hatch(at):
		return { "kind": HATCH, "id": "" }
	if IceDepth.near_crate(at):
		return { "kind": CRATE, "id": "" }
	if IceDepth.near_sign(at):
		return { "kind": SIGN, "id": "" }
	return {}


## The HUD has no status line, so the cold is told in the log: when the player comes in, every
## COLD_STEP percent, and when the pack crosses (or comes back under) the drift threshold.
func _tell_cold() -> void:
	var cold: float = GameState.cold_of(GameState.local_player_id)
	var step: int = int(cold) / COLD_STEP
	var drifting: bool = IceDepth.is_drifting(cold)
	if step == _told_cold_step and drifting == _told_drift:
		return
	var first: bool = _told_cold_step < 0
	_told_cold_step = step
	_told_drift = drifting
	if first and cold <= 0.0:
		return
	_hud.push_log(IceDepth.cold_text(cold))


func _tell_hub() -> void:
	var key: String = "%s:%s" % [_hub_near.get("kind", ""), _hub_near.get("id", "")] if not _hub_near.is_empty() else ""
	if key == _told_hub:
		return
	_told_hub = key
	match _hub_near.get("kind", ""):
		HATCH:
			_hud.push_log("WAY DOWN: press " + Controls.prompt(&"interact") + " to go down.")
		FIND:
			_hud.push_log("FIND: press " + Controls.prompt(&"interact") + " to take it.")
		CRATE:
			_hud.push_log("HEATER CRATE: a heater cartridge costs %d credits and resets the cold. Press %s to buy one." % [
				IceDepth.HEATER_COST_CREDITS, Controls.prompt(&"interact")])
		SIGN:
			_hud.push_log("NOTICE SIGN: press " + Controls.prompt(&"interact") + " to read it.")


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		CRATE:
			_use_crate()
		SIGN:
			_hud.push_log("NOTICE SIGN: Vance: [later]")
		_:
			super._use_hub(target)


func _use_crate() -> void:
	var problem: String = await FarmCommands.request(&"buy_heater", [])
	if not is_inside_tree():
		return
	_told_hub = ""
	_told_cold_step = -1
	_hud.push_log("HEATER CRATE: " + (problem if problem != "" else "a heater cartridge warms the pack back up (%d credits)." % IceDepth.HEATER_COST_CREDITS))


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, IceDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + IceDepth.reward_text(str(find.get("kind", ""))))


func _on_rover_entered_exit() -> void:
	_hud.push_log("WAY UP: press " + Controls.prompt(&"interact") + " to go up." if _below else "ICE RAMP: press " + Controls.prompt(&"interact") + " to drive out.")


## Takes the rover out of the ramp and goes with it.
func _leave_tunnels() -> void:
	if _moving:
		return
	_moving = true
	if not GameState.rover_lent:
		# A field rover (the dome console's): the way home is the dome.
		var left: String = await FarmCommands.request(&"leave_zone")
		if not is_inside_tree():
			return
		if left != "":
			_moving = false
			_hud.push_log("ICE RAMP: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover_ice", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("ICE RAMP: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()
