class_name FloodedAquifer
extends "res://scripts/basalt_tunnels.gd"
## The Flooded Aquifer's scene (zones step 13): the Lava Tubes' scene with the Aquifer's
## hub (wet rock and a pool, the way up, a notice board sign, the hatch down, the pump's
## crate) and its one depth (rooms, finds, pools). Built in code from primitives; the
## rules are AquiferDepth's and the host's. A look [PLACEHOLDER]: no art yet.

const CRATE: String = "crate"
const SIGN: String = "sign"
const POOL: String = "pool"

## The pools drained when this scene was built; the pump changing them builds it again.
var _built_drained: Array = []
var _water: Node3D


func _zone_id() -> String:
	return AquiferDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	_built_drained = AquiferDepth.drained_today(GameState.pools_drained, _built_day)
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_water = Node3D.new()
	_water.name = "Water"
	_rover.get_parent().add_child(_water)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		for pool: Dictionary in ZoneDepth.local_layout.get("pools", []):
			_draw_pool(pool, str(pool["id"]))
		GameState.finds_changed.connect(_on_finds_changed)
	else:
		_depth_props.build_hatch()
		_draw_pool({ "rect": AquiferDepth.HUB_POOL, "depth_m": AquiferDepth.DEEP_M[1], "drained": false }, "")
		_draw_crate()
		_draw_sign()


## A pool: a slab of water (lighter where it is shallow, dark where it is deep), or the
## mud it leaves when drained. Pure looks.
func _draw_pool(pool: Dictionary, pool_id: String) -> void:
	var box: Rect2 = AquiferDepth.pool_metres(pool)
	var drained: bool = bool(pool["drained"])
	var material: StandardMaterial3D = LavaHubProps._flat(ScopeTheme.TERRA_DARK.lerp(ScopeTheme.GLASS_DEEP, 0.5)) if drained \
			else LavaHubProps._flat(ScopeTheme.TEAL.lerp(ScopeTheme.GLASS_DEEP, 0.35 if AquiferDepth.is_shallow(pool) else 0.75))
	if not drained:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.8
	var slab: MeshInstance3D = LavaHubProps._part(LavaHubProps._box(Vector3(box.size.x, 0.05, box.size.y)),
			Vector3(box.get_center().x, 0.03, box.get_center().y), material)
	slab.name = "Pool_" + pool_id
	_water.add_child(slab)
	if pool_id != "":
		var text: String = "%s %s" % [pool_id.to_upper(), "DRAINED" if drained else ("WADE" if AquiferDepth.is_shallow(pool) else "DEEP")]
		_water.add_child(LavaHubProps._label(text, Vector3(box.get_center().x, 1.3, box.get_center().y)))


## The crate that sells the pump: a box with an amber band and a sign.
func _draw_crate() -> void:
	var crate := Node3D.new()
	crate.name = "PumpCrate"
	crate.position = AquiferDepth.crate_position()
	_depth_props.add_child(crate)
	crate.add_child(LavaHubProps._part(LavaHubProps._box(Vector3(1.2, 0.9, 0.9)), Vector3(0.0, 0.45, 0.0), LavaHubProps._flat(ScopeTheme.TERRA)))
	crate.add_child(LavaHubProps._part(LavaHubProps._box(Vector3(1.25, 0.12, 0.95)), Vector3(0.0, 0.6, 0.0), LavaHubProps._glow(ScopeTheme.AMBER, 0.6)))
	crate.add_child(LavaHubProps._label("PUMP CRATE", Vector3(0.0, 1.6, 0.0)))


## The notice board sign: a post and a board. Vance's notice is for later.
func _draw_sign() -> void:
	var board := Node3D.new()
	board.name = "NoticeSign"
	board.position = AquiferDepth.sign_position()
	_depth_props.add_child(board)
	board.add_child(LavaHubProps._part(LavaHubProps._box(Vector3(0.12, 1.6, 0.12)), Vector3(0.0, 0.8, 0.0), LavaHubProps._flat(ScopeTheme.INK_DIM)))
	board.add_child(LavaHubProps._part(LavaHubProps._box(Vector3(1.4, 0.7, 0.08)), Vector3(0.0, 1.6, 0.0), LavaHubProps._flat(ScopeTheme.ENAMEL)))
	board.add_child(LavaHubProps._label("Vance: [later]", Vector3(0.0, 2.3, 0.0)))


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	_in_reach = false  # no Sentinel here
	_hub_near = _aquifer_near() if _rover.away_text() == "" else {}
	_tell_hub()


## The way down, the crate or the sign at the hub; below, the nearest find, else the
## nearest pool still full: or {}.
func _aquifer_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if not _below:
		if AquiferDepth.near_hatch(at):
			return { "kind": HATCH, "id": "" }
		if AquiferDepth.near_crate(at):
			return { "kind": CRATE, "id": "" }
		if AquiferDepth.near_sign(at):
			return { "kind": SIGN, "id": "" }
		return {}
	var found: Dictionary = _nearest_find()
	if not found.is_empty():
		return found
	for pool: Dictionary in ZoneDepth.local_layout.get("pools", []):
		if not bool(pool["drained"]) and AquiferDepth.pool_gap_m(pool, at) <= AquiferDepth.PUMP_REACH_M:
			return { "kind": POOL, "id": str(pool["id"]) }
	return {}


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
			_hud.push_log("PUMP CRATE: %s. Press %s to %s." % [
				"the farm has the pump" if GameState.pump_owned else "a pump costs %d credits" % AquiferDepth.PUMP_COST_CREDITS,
				Controls.prompt(&"interact"), "check it" if GameState.pump_owned else "buy it"])
		SIGN:
			_hud.push_log("NOTICE SIGN: press " + Controls.prompt(&"interact") + " to read it.")
		POOL:
			_hud.push_log("POOL: press " + Controls.prompt(&"interact") + " to pump it dry for today.")


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		CRATE:
			_use_crate()
		SIGN:
			_hud.push_log("NOTICE SIGN: Vance: [later]")
		POOL:
			_use_pump(str(target["id"]))
		_:
			super._use_hub(target)


func _use_crate() -> void:
	if GameState.pump_owned:
		_hud.push_log("PUMP CRATE: the farm has the pump already. Use it at a pool.")
		return
	var problem: String = await FarmCommands.request(&"buy_pump", [])
	if not is_inside_tree():
		return
	_told_hub = ""
	_hud.push_log("PUMP CRATE: " + (problem if problem != "" else "the farm bought a pump for %d credits." % AquiferDepth.PUMP_COST_CREDITS))


func _use_pump(pool_id: String) -> void:
	var problem: String = await FarmCommands.request(&"use_pump", [pool_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	_hud.push_log("PUMP: " + (problem if problem != "" else "%s drained for today." % pool_id.to_upper()))


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, AquiferDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + AquiferDepth.reward_text(str(find.get("kind", ""))))


## The pump drained a pool (here or by a friend), so this depth is built again with the
## rover where it is.
func _resync_depth() -> void:
	super._resync_depth()
	if _below and not SceneSwitcher.is_busy() and GameState.rover_zone == AquiferDepth.ZONE and _rover.away_text() == "" and not _moving:
		var now: Array = AquiferDepth.drained_today(GameState.pools_drained, _built_day)
		if now.size() != _built_drained.size() or now.any(func(id: Variant) -> bool: return not id in _built_drained):
			_moving = true
			ZoneDepth.arrive_at = _rover.global_transform
			ZoneDepth.arrive_pending = true
			SceneSwitcher.swap_to(SceneSwitcher.AQUIFER_SCENE)


func _on_rover_entered_exit() -> void:
	_hud.push_log("WAY UP: press " + Controls.prompt(&"interact") + " to go up." if _below else "SINKHOLE: press " + Controls.prompt(&"interact") + " to climb out.")


## Takes the rover up the sinkhole and goes with it.
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
			_hud.push_log("SINKHOLE: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover_aquifer", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("SINKHOLE: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()
