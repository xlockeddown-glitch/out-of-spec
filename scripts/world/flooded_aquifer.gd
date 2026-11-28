class_name FloodedAquifer
extends "res://scripts/basalt_tunnels.gd"
## The Flooded Aquifer's scene (zones step 13): the Lava Tubes' scene with the Aquifer's
## hub (wet rock and a pool, the way up, a notice board sign, the hatch down, the pump's
## crate) and its one depth (rooms, finds, pools). Built in code from primitives; the
## rules are AquiferDepth's and the host's. A look [PLACEHOLDER]: no art yet.

const CRATE: String = "crate"
const SIGN: String = "sign"
const POOL: String = "pool"
const SEAL: String = "seal"

## Each depth below 1 is a little darker [PLACEHOLDER]: the cavern lamps lose this share of
## their energy a level (down to LAMP_FLOOR of it), and every second level below 1 adds one
## more mineral streak (wetter rock). No new lights.
const LAMP_DIM_PER_LEVEL: float = 0.08
const LAMP_FLOOR: float = 0.5

## Pool water & silt material parameters (sourced from AquiferLook) [PLACEHOLDER].
const SHALLOW_ALPHA: float = AquiferLook.WATER_SHALLOW_ALPHA
const DEEP_ALPHA: float = AquiferLook.WATER_DEEP_ALPHA
const SEAL_SHEET_ALPHA: float = AquiferLook.SEAL_SHEET_ALPHA
const SHALLOW_ROUGHNESS: float = AquiferLook.WATER_SHALLOW_ROUGHNESS
const DEEP_ROUGHNESS: float = AquiferLook.WATER_DEEP_ROUGHNESS
const SILT_ROUGHNESS: float = AquiferLook.SILT_ROUGHNESS
const HUB_POOL_LIGHT_ENERGY: float = AquiferLook.HUB_POOL_LIGHT_ENERGY
const HUB_POOL_LIGHT_RANGE_M: float = AquiferLook.HUB_POOL_LIGHT_RANGE_M

## The pools drained and seals shut when this scene was built; changing them updates it.
var _built_drained: Array = []
var _built_shut: Array = []
var _water: Node3D
var _seals: Node3D
var _decor: Node3D


func _zone_id() -> String:
	return AquiferDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	_built_drained = AquiferDepth.drained_today(GameState.pools_drained, _built_day)
	_built_shut = AquiferDepth.shut_today(GameState.valves_shut, _built_day)
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_water = Node3D.new()
	_water.name = "Water"
	_rover.get_parent().add_child(_water)
	_seals = Node3D.new()
	_seals.name = "Seals"
	_rover.get_parent().add_child(_seals)
	_decor = Node3D.new()
	_decor.name = "AquiferDecor"
	_rover.get_parent().add_child(_decor)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		for pool: Dictionary in ZoneDepth.local_layout.get("pools", []):
			_draw_pool(pool, str(pool["id"]))
		_rebuild_seals()
		_build_depth_decor()
		if ZoneDepth.has_way_down(_built_depth):
			_depth_props.build_hatch(_built_depth)
		GameState.finds_changed.connect(_on_finds_changed)
		GameState.pump_changed.connect(_on_aquifer_changed)
	else:
		_depth_props.build_hatch()
		_draw_pool({ "rect": AquiferDepth.HUB_POOL, "depth_m": AquiferDepth.DEEP_M[1], "drained": false }, "")
		_draw_crate()
		_draw_sign()
		_build_hub_decor()
		_rover.get_parent().add_child(CampProps.new(AquiferDepth.ZONE))
	# The lift station: at the hub, and at the depths that have one (3 and 6). Broken until repaired.
	if ZoneDepth.is_lift_depth(_built_depth) or _built_depth == 0:
		_depth_props.build_lift(_built_depth, GameState.is_lift_repaired(AquiferDepth.ZONE, _lift_depth()))
		GameState.lifts_changed.connect(_on_lifts_changed)


## Hub dressing: dripping stalactite clusters, rusted pipe-green drainage runs,
## pale mineral wall streaks (strictly on full-height north and west walls so
## nothing floats over camera cut-away walls), and 1 subtle cavern accent light
## (visual only, zero collision, rover path clear) [PLACEHOLDER].
func _build_hub_decor() -> void:
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-1.5, 3.2, -8.7), 5.2, 0.90, 0.0)
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-11.7, 3.1, -1.5), 4.0, 0.85, 90.0)
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-11.7, 3.1, 18.0), 4.0, 0.85, 90.0)
	AquiferLook.add_pipe_run(_decor, Vector3(-11.7, 0.0, -1.5), 7.2, 1.70, 90.0)
	AquiferLook.add_pipe_run(_decor, Vector3(-1.5, 0.0, -8.7), 6.4, 1.65, 0.0)
	AquiferLook.add_pipe_run(_decor, Vector3(-11.7, 0.0, 18.0), 5.6, 1.55, 90.0)
	AquiferLook.add_mineral_streak(_decor, Vector3(-5.5, 0.0, -8.85), 1.6, 2.5, 0.0)
	AquiferLook.add_mineral_streak(_decor, Vector3(2.5, 0.0, -8.85), 1.6, 2.4, 0.0)
	AquiferLook.add_mineral_streak(_decor, Vector3(-11.85, 0.0, 21.0), 1.5, 2.3, 90.0)
	_add_cavern_light(Vector3(5.5, 2.3, 16.5), "LandingLamp")


## Depth 1 dressing: dripping stalactites, rusted pipe-green drainage runs,
## pale mineral streaks (strictly on full-height north and west walls so
## nothing floats over camera cut-away walls), and 2 subtle cavern accent
## lights (visual only, zero collision, rover path clear) [PLACEHOLDER].
func _build_depth_decor() -> void:
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-11.7, 3.1, 17.5), 4.2, 0.88, 90.0)
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-11.7, 3.1, -22.5), 4.0, 0.85, 90.0)
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-1.5, 3.2, -29.7), 5.0, 0.92, 0.0)
	AquiferLook.add_stalactite_cluster(_decor, Vector3(-19.5, 3.1, -8.7), 4.4, 0.85, 0.0)
	AquiferLook.add_stalactite_cluster(_decor, Vector3(19.5, 3.1, -8.7), 4.4, 0.85, 0.0)
	AquiferLook.add_pipe_run(_decor, Vector3(-11.7, 0.0, 18.0), 6.0, 1.65, 90.0)
	AquiferLook.add_pipe_run(_decor, Vector3(-29.7, 0.0, -1.5), 5.4, 1.60, 90.0)
	AquiferLook.add_pipe_run(_decor, Vector3(-19.5, 0.0, -8.7), 5.6, 1.65, 0.0)
	AquiferLook.add_pipe_run(_decor, Vector3(19.5, 0.0, -8.7), 5.6, 1.65, 0.0)
	AquiferLook.add_mineral_streak(_decor, Vector3(-11.85, 0.0, 14.0), 1.5, 2.4, 90.0)
	AquiferLook.add_mineral_streak(_decor, Vector3(-5.0, 0.0, -29.85), 1.8, 2.6, 0.0)
	AquiferLook.add_mineral_streak(_decor, Vector3(2.0, 0.0, -29.85), 1.6, 2.4, 0.0)
	for extra: int in (_built_depth - 1) >> 1:  # wetter rock deeper down
		AquiferLook.add_mineral_streak(_decor, Vector3(-8.0 + 5.0 * extra, 0.0, -29.85), 1.4, 2.3, 0.0)
	_add_cavern_light(Vector3(0.0, 2.4, 3.0), "TrunkLamp")
	_add_cavern_light(Vector3(-1.5, 2.4, -22.5), "NorthChamberLamp")


## How much of the full lamp energy a cavern lamp has at `depth`: all of it at the hub and
## depth 1, less each level below (LAMP_DIM_PER_LEVEL), never under LAMP_FLOOR.
static func lamp_scale(depth: int) -> float:
	return maxf(LAMP_FLOOR, 1.0 - LAMP_DIM_PER_LEVEL * maxi(depth - 1, 0))


func _add_cavern_light(at: Vector3, light_name: String) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = light_name
	lamp.position = at
	lamp.light_color = AquiferLook.CAVERN_LIGHT_COLOR
	lamp.light_energy = AquiferLook.CAVERN_LIGHT_ENERGY * lamp_scale(_built_depth)
	lamp.omni_range = AquiferLook.CAVERN_LIGHT_RANGE_M
	_decor.add_child(lamp)


## A pool: still translucent tinted water (brighter shallow vs dark deep) or
## damp silt when drained, framed by wet-stone & pale mineral curbing and
## seepage plates. Pure looks; each pool gets its own unique surface material
## so draining or mutating one pool never leaks into another pool or shared caches.
func _draw_pool(pool: Dictionary, pool_id: String) -> void:
	var box: Rect2 = AquiferDepth.pool_metres(pool)
	var rect: Rect2i = pool["rect"]
	var drained: bool = bool(pool["drained"])
	var shallow: bool = AquiferDepth.is_shallow(pool)
	var centre: Vector2 = box.get_center()

	var material: StandardMaterial3D
	if drained:
		material = AquiferLook.flat_mat_unique(AquiferLook.SILT_DAMP, SILT_ROUGHNESS)
	elif shallow:
		material = AquiferLook.water_mat(AquiferLook.WATER_SHALLOW, SHALLOW_ROUGHNESS, SHALLOW_ALPHA)
	else:
		material = AquiferLook.water_mat(AquiferLook.WATER_DEEP, DEEP_ROUGHNESS, DEEP_ALPHA)

	var slab: MeshInstance3D = TunnelLook.part(TunnelLook.box(Vector3(box.size.x, 0.05, box.size.y)),
			Vector3(centre.x, 0.03, centre.y), material)
	slab.name = "Pool_" + pool_id
	_water.add_child(slab)

	var trim := Node3D.new()
	trim.name = "PoolTrim_" + pool_id
	_water.add_child(trim)
	AquiferLook.add_pool_trim(trim, box, rect, drained, shallow)

	if pool_id == "":
		var glow := OmniLight3D.new()
		glow.name = "PoolGlow"
		glow.position = Vector3(centre.x, 1.4, centre.y)
		glow.light_color = AquiferLook.POOL_GLOW_COLOR
		glow.light_energy = HUB_POOL_LIGHT_ENERGY
		glow.omni_range = HUB_POOL_LIGHT_RANGE_M
		trim.add_child(glow)
	else:
		var text: String = "%s %s" % [pool_id.to_upper(), "DRAINED" if drained else ("WADE" if shallow else "DEEP")]
		_water.add_child(TunnelLook.label(text, Vector3(centre.x, 1.3, centre.y), AquiferLook.LABEL_TEAL))


## The crate that sells the pump: pipe-green rusted housing, iron skids,
## tarnished brass collar, coiled rubber hose, pressure gauge, and label [PLACEHOLDER].
func _draw_crate() -> void:
	_depth_props.add_child(AquiferLook.build_pump_crate(AquiferDepth.crate_position()))


## The notice board sign: matches the Lava hub's notice board with pipe-green
## cap trim, mineral crust, and rusted iron footplates. Vance's notice is for later [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("Vance: [later]")
	board.name = "NoticeSign"
	board.position = AquiferDepth.sign_position()
	_depth_props.add_child(board)
	AquiferLook.add_sign_trim(board)


## Draws an open seal at depth 1: a rusted pipe-green standpipe and valve wheel
## at the doorway, a thin water jet from the stub, and a shallow sheet of water
## on that room's floor. Draws nothing once the seal is shut; visual primitives
## only, no colliders [PLACEHOLDER].
func _draw_seal(seal: Dictionary) -> void:
	if bool(seal.get("shut", false)) or _seals == null:
		return
	var id: String = str(seal["id"])
	var room_index: int = int(seal["room"])
	var at: Vector3 = AquiferDepth.seal_position(seal)
	var room_box: Rect2 = AquiferDepth.room_metres(room_index).grow(-0.35)
	var room_centre: Vector2 = room_box.get_center()

	var root := Node3D.new()
	root.name = "Seal_" + id
	_seals.add_child(root)

	# Shallow sheet of still water across the open-seal room's floor.
	var sheet_mat: StandardMaterial3D = AquiferLook.water_mat(AquiferLook.WATER_SHALLOW, SHALLOW_ROUGHNESS, SEAL_SHEET_ALPHA)
	var sheet: MeshInstance3D = TunnelLook.part(TunnelLook.box(Vector3(room_box.size.x, 0.025, room_box.size.y)),
			Vector3(room_centre.x, 0.015, room_centre.y), sheet_mat)
	sheet.name = "SealSheet_" + id
	root.add_child(sheet)

	root.add_child(AquiferLook.build_seal_valve(at, id, room_centre))


## Updates the local seal flags from `GameState.valves_shut` and redraws open seals.
func _rebuild_seals() -> void:
	if _seals == null:
		return
	for child: Node in _seals.get_children():
		_seals.remove_child(child)
		child.free()
	var shut: Array = AquiferDepth.shut_today(GameState.valves_shut, _built_day)
	_built_shut = shut
	for seal: Variant in ZoneDepth.local_layout.get("seals", []):
		if seal is Dictionary:
			seal["shut"] = AquiferDepth.storage_id(_built_depth, str(seal["id"])) in shut
			if not bool(seal["shut"]):
				_draw_seal(seal)
	_told_hub = ""


func _on_aquifer_changed() -> void:
	if _below and is_inside_tree():
		var now: Array = AquiferDepth.shut_today(GameState.valves_shut, _built_day)
		if now.size() != _built_shut.size() or now.any(func(id: Variant) -> bool: return not id in _built_shut):
			_rebuild_seals()


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	_in_reach = false  # no Sentinel here
	_hub_near = _aquifer_near() if _rover.away_text() == "" else {}
	_tell_hub()


## The way down, the crate or the sign at the hub; below, the nearest find (unless its
## room's open seal is also in reach), else the open seal, else the nearest full pool.
func _aquifer_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if not _below:
		if AquiferDepth.near_hatch(at):
			return { "kind": HATCH, "id": "" }
		if ZoneDepth.near_lift(at, 0):
			return _station_near()
		if AquiferDepth.near_crate(at):
			return { "kind": CRATE, "id": "" }
		if AquiferDepth.near_sign(at):
			return { "kind": SIGN, "id": "" }
		return _camp_near()
	if ZoneDepth.has_way_down(_built_depth) and ZoneDepth.near_descent(at, _built_depth):
		return { "kind": HATCH, "id": "" }
	var found: Dictionary = _nearest_find()
	var seal_near: Dictionary = _seal_near(at)
	if not found.is_empty() and not AquiferDepth.prefer_seal(ZoneDepth.local_layout, str(found.get("id", "")), not seal_near.is_empty()):
		return found  # a find beside the lift wins over the lift, as in the Lava scene
	if ZoneDepth.is_lift_depth(_built_depth) and ZoneDepth.near_lift(at, _built_depth):
		return _station_near()
	if not seal_near.is_empty():
		return seal_near
	for pool: Dictionary in ZoneDepth.local_layout.get("pools", []):
		if not bool(pool["drained"]) and AquiferDepth.pool_gap_m(pool, at) <= AquiferDepth.PUMP_REACH_M:
			return { "kind": POOL, "id": str(pool["id"]) }
	return {}


## The open seal within valve reach of `at`, or {}.
func _seal_near(at: Vector3) -> Dictionary:
	for seal: Dictionary in ZoneDepth.local_layout.get("seals", []):
		if not bool(seal.get("shut", false)):
			var there: Vector3 = AquiferDepth.seal_position(seal)
			if Vector2(there.x - at.x, there.z - at.z).length() <= AquiferDepth.VALVE_REACH_M:
				return { "kind": SEAL, "id": str(seal["id"]) }
	return {}


func _tell_hub() -> void:
	var key: String = "%s:%s" % [_hub_near.get("kind", ""), _hub_near.get("id", "")] if not _hub_near.is_empty() else ""
	if key == _told_hub:
		return
	_told_hub = key
	match _hub_near.get("kind", ""):
		HATCH:
			var shut: String = GameState.deep_problem(AquiferDepth.ZONE) if ZoneDepth.is_deep(_built_depth + 1) else ""
			_hud.push_log("WAY DOWN: press " + Controls.prompt(&"interact") + " to go down." if shut == "" else "WAY DOWN: " + shut)
		LIFT:
			_hud.push_log(_lift_prompt())
		FIND:
			_hud.push_log("FIND: press " + Controls.prompt(&"interact") + " to take it.")
		CRATE:
			_hud.push_log("PUMP CRATE: %s. Press %s to %s." % [
				"the farm has the pump" if GameState.pump_owned else "a pump costs %d credits" % AquiferDepth.PUMP_COST_CREDITS,
				Controls.prompt(&"interact"), "check it" if GameState.pump_owned else "buy it"])
		SIGN:
			_hud.push_log("NOTICE SIGN: press " + Controls.prompt(&"interact") + " to read it.")
		CAMP:
			_tell_camp()
		POOL:
			_hud.push_log("POOL: press " + Controls.prompt(&"interact") + " to pump it dry for today.")
		SEAL:
			_hud.push_log("OPEN SEAL: press " + Controls.prompt(&"interact") + " to shut the valve.")


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		CRATE:
			_use_crate()
		SIGN:
			for line: String in NoticeBoard.lines(QuestEngine.quests(), GameState.quest_state,
					GameState.player_quest_state.get(GameState.local_player_id, {}), "zone", AquiferDepth.ZONE):
				_hud.push_log(line)
		POOL:
			_use_pump(str(target["id"]))
		SEAL:
			_use_valve(str(target["id"]))
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


func _use_valve(seal_id: String) -> void:
	var problem: String = await FarmCommands.request(&"shut_valve", [seal_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	_told_hub = ""
	_hud.push_log("VALVE: " + (problem if problem != "" else "%s shut for today." % seal_id.to_upper()))


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, AquiferDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var reply: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if reply != "" and not AquiferDepth.is_wet_pack_reply(reply):
		_hud.push_log("FIND: " + reply)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + AquiferDepth.reward_text(str(find.get("kind", "")), _built_depth))
	if reply != "":
		_hud.push_log("WET PACK: " + reply)


## The pump drained a pool (here or by a friend), so this depth is built again with the
## rover where it is; a shut valve redraws the seals in place.
func _resync_depth() -> void:
	super._resync_depth()
	if _below and not SceneSwitcher.is_busy() and GameState.rover_zone == AquiferDepth.ZONE and _rover.away_text() == "" and not _moving:
		var now_shut: Array = AquiferDepth.shut_today(GameState.valves_shut, _built_day)
		if now_shut.size() != _built_shut.size() or now_shut.any(func(id: Variant) -> bool: return not id in _built_shut):
			_rebuild_seals()
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
