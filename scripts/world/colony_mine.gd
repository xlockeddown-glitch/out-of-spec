class_name ColonyMine
extends "res://scripts/basalt_tunnels.gd"
## The Abandoned Colony Mine's scene (zones step 14): the Lava Tubes' scene with the Mine's
## hub (the way down, a notice board, the crate that sells shoring props) and its one depth
## (rooms, finds, rockfalls). Built in code from primitives; the rules are MineDepth's and
## the host's. A look [PLACEHOLDER]: no art yet.

const CRATE: String = "crate"
const SIGN: String = "sign"
const ROCKFALL: String = "rockfall"

## Rockfall and prop look [PLACEHOLDER].
const RUBBLE_SCALE: float = 2.2
const ARCH_SPAN_M: float = 3.0
const ARCH_HEIGHT_M: float = 2.2

## The rooms shored when this scene was built; shoring one builds it again.
var _built_shored: Array = []
var _rockfalls: Node3D


func _zone_id() -> String:
	return MineDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	_built_shored = MineDepth.shored_today(GameState.rooms_shored, _built_day)
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_rockfalls = Node3D.new()
	_rockfalls.name = "Rockfalls"
	_rover.get_parent().add_child(_rockfalls)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		for fall: Dictionary in ZoneDepth.local_layout.get("rockfalls", []):
			_draw_rockfall(fall)
		GameState.finds_changed.connect(_on_finds_changed)
	else:
		_depth_props.build_hatch()
		_draw_crate()
		_draw_sign()


## A rockfall: a rubble pile in the side room's mouth; once shored, a timber support arch
## stands there instead and the room is open [PLACEHOLDER].
func _draw_rockfall(fall: Dictionary) -> void:
	var at: Vector3 = MineDepth.rockfall_position(fall)
	var id: String = str(fall["id"])
	if bool(fall["shored"]):
		TunnelLook.add_support_arch(_rockfalls, at, ARCH_SPAN_M, ARCH_HEIGHT_M)
		_rockfalls.add_child(TunnelLook.label("%s SHORED" % id.to_upper(), at + Vector3(0.0, 2.7, 0.0), TunnelLook.CRYSTAL))
	else:
		TunnelLook.add_rubble_pile(_rockfalls, at, RUBBLE_SCALE)
		_rockfalls.add_child(TunnelLook.label("%s ROCKFALL" % id.to_upper(), at + Vector3(0.0, 1.9, 0.0), TunnelLook.BROKEN_RED))


## The crate that sells shoring props: a timber pallet, a steel-framed crate of props, a
## stack of spare posts and a label [PLACEHOLDER].
func _draw_crate() -> void:
	var crate := Node3D.new()
	crate.name = "PropCrate"
	crate.position = MineDepth.crate_position()
	_depth_props.add_child(crate)
	var dark_mat: Material = TunnelLook.flat_mat(TunnelLook.BASALT_DARK)
	var steel_mat: Material = TunnelLook.flat_mat(TunnelLook.STEEL)
	var body_mat: Material = TunnelLook.flat_mat(TunnelLook.REGOLITH_DARK)
	var wood_mat: Material = TunnelLook.flat_mat(TunnelLook.TIMBER)
	var light_wood_mat: Material = TunnelLook.flat_mat(TunnelLook.TIMBER_LIGHT)

	for z_off: float in [-0.36, 0.36]:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.38, 0.08, 0.16)), Vector3(0.0, 0.04, z_off), dark_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.42, 0.06, 1.04)), Vector3(0.0, 0.11, 0.0), wood_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.16, 0.62, 0.84)), Vector3(0.0, 0.45, 0.0), body_mat))
	for sx: float in [-0.57, 0.57]:
		for sz: float in [-0.41, 0.41]:
			crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.10, 0.70, 0.10)), Vector3(sx, 0.46, sz), steel_mat))
	# Spare posts laid across the top, one of them cross-braced.
	for i: int in 3:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.14, 1.1)), Vector3(-0.36 + 0.36 * float(i), 0.87, 0.0),
				light_wood_mat if i == 1 else wood_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.1, 0.06, 0.12)), Vector3(0.0, 0.97, 0.0), steel_mat))
	crate.add_child(TunnelLook.label("PROP CRATE", Vector3(0.0, 1.55, 0.0), TunnelLook.CRYSTAL))


## The notice board: the Lava hub's, with Bram's notice for later [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("Bram: [later]")
	board.name = "NoticeSign"
	board.position = MineDepth.sign_position()
	_depth_props.add_child(board)


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	_in_reach = false  # no Sentinel here
	_hub_near = _mine_near() if _rover.away_text() == "" else {}
	_tell_hub()


## The way down, the crate or the sign at the hub; below, the nearest find, else the
## nearest rockfall still standing: or {}.
func _mine_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if not _below:
		if MineDepth.near_hatch(at):
			return { "kind": HATCH, "id": "" }
		if MineDepth.near_crate(at):
			return { "kind": CRATE, "id": "" }
		if MineDepth.near_sign(at):
			return { "kind": SIGN, "id": "" }
		return {}
	var found: Dictionary = _nearest_find()
	if not found.is_empty():
		return found
	for fall: Dictionary in ZoneDepth.local_layout.get("rockfalls", []):
		if not bool(fall["shored"]):
			var there: Vector3 = MineDepth.rockfall_position(fall)
			if Vector2(there.x - at.x, there.z - at.z).length() <= MineDepth.SHORE_REACH_M:
				return { "kind": ROCKFALL, "id": str(fall["id"]) }
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
			_hud.push_log("PROP CRATE: a shoring prop costs %d crystal ore (the farm has %d props). Press %s to buy one." % [
				MineDepth.PROP_COST_ORE, GameState.mine_props, Controls.prompt(&"interact")])
		SIGN:
			_hud.push_log("NOTICE SIGN: press " + Controls.prompt(&"interact") + " to read it.")
		ROCKFALL:
			_hud.push_log("ROCKFALL: press %s to shore it for today (the farm has %d props)." % [Controls.prompt(&"interact"), GameState.mine_props])


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		CRATE:
			_use_crate()
		SIGN:
			_hud.push_log("NOTICE SIGN: Bram: [later]")
		ROCKFALL:
			_use_shore(str(target["id"]))
		_:
			super._use_hub(target)


func _use_crate() -> void:
	var problem: String = await FarmCommands.request(&"buy_mine_props", [])
	if not is_inside_tree():
		return
	_told_hub = ""
	_hud.push_log("PROP CRATE: " + (problem if problem != "" else "the farm bought a shoring prop for %d crystal ore." % MineDepth.PROP_COST_ORE))


func _use_shore(rockfall_id: String) -> void:
	var problem: String = await FarmCommands.request(&"shore_room", [rockfall_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	_told_hub = ""
	_hud.push_log("ROCKFALL: " + (problem if problem != "" else "%s shored for today." % rockfall_id.to_upper()))


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, MineDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + MineDepth.reward_text(str(find.get("kind", ""))))


## A room was shored (here or by a friend), so this depth is built again with the rover
## where it is.
func _resync_depth() -> void:
	super._resync_depth()
	if _below and not SceneSwitcher.is_busy() and GameState.rover_zone == MineDepth.ZONE and _rover.away_text() == "" and not _moving:
		var now: Array = MineDepth.shored_today(GameState.rooms_shored, _built_day)
		if now.size() != _built_shored.size() or now.any(func(id: Variant) -> bool: return not id in _built_shored):
			_moving = true
			ZoneDepth.arrive_at = _rover.global_transform
			ZoneDepth.arrive_pending = true
			SceneSwitcher.swap_to(SceneSwitcher.MINE_SCENE)


func _on_rover_entered_exit() -> void:
	_hud.push_log("WAY UP: press " + Controls.prompt(&"interact") + " to go up." if _below else "MINE GATE: press " + Controls.prompt(&"interact") + " to drive out.")


## Takes the rover out of the gate and goes with it.
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
			_hud.push_log("MINE GATE: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover_mine", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("MINE GATE: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()
