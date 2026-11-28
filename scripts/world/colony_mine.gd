class_name ColonyMine
extends "res://scripts/basalt_tunnels.gd"
## The Abandoned Colony Mine's scene (zones step 14): the Lava Tubes' scene with the Mine's
## hub (the way down, a notice board, the crate that sells shoring props) and its depths 1
## to 6 (rooms, finds, rockfalls, lifts at 3 and 6). Built in code from primitives; the rules are MineDepth's and
## the host's. A look [PLACEHOLDER]: no art yet.

const CRATE: String = "crate"
const SIGN: String = "sign"
const ROCKFALL: String = "rockfall"

## Rockfall and prop look [PLACEHOLDER].
const RUBBLE_SCALE: float = 2.2
const ARCH_SPAN_M: float = 3.0
const ARCH_HEIGHT_M: float = 2.2
## Each depth below 1 is this much darker, to a floor [PLACEHOLDER].
const DIM_PER_LEVEL: float = 0.08
const DIM_FLOOR: float = 0.5

## The rooms shored when this scene was built; shoring one builds it again.
var _built_shored: Array = []
var _rockfalls: Node3D
var _decor: Node3D


func _zone_id() -> String:
	return MineDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	_built_shored = MineDepth.shored_today(GameState.rooms_shored, _built_day, _built_depth)
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_rockfalls = Node3D.new()
	_rockfalls.name = "Rockfalls"
	_rover.get_parent().add_child(_rockfalls)
	_decor = Node3D.new()
	_decor.name = "MineDecor"
	_rover.get_parent().add_child(_decor)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		_build_cases(ZoneDepth.local_layout)
		for fall: Dictionary in ZoneDepth.local_layout.get("rockfalls", []):
			_draw_rockfall(fall)
		_build_depth_decor()
		if ZoneDepth.has_way_down(_built_depth):
			_depth_props.build_hatch(_built_depth)
		GameState.finds_changed.connect(_on_finds_changed)
	else:
		_depth_props.build_hatch()
		_draw_crate()
		_draw_sign()
		_build_hub_decor()
	# The lift station: at the hub, and at the depths that have one (3 and 6). Broken until repaired.
	if ZoneDepth.is_lift_depth(_built_depth) or _built_depth == 0:
		_depth_props.build_lift(_built_depth, GameState.is_lift_repaired(MineDepth.ZONE, _lift_depth()))
		GameState.lifts_changed.connect(_on_lifts_changed)


## Hub dressing: old timber sets along the passages, a short abandoned rail
## track, dead hanging lamps, and a faded colony stencil sign (visual only,
## zero collision, rover path clear) [PLACEHOLDER].
func _build_hub_decor() -> void:
	MineLook.add_timber_set(_decor, Vector3(-1.5, 0.0, 24.8), 7.8, 3.0, 0.0, true)
	MineLook.add_timber_set(_decor, Vector3(-1.5, 0.0, 13.5), 7.8, 3.0, 0.0, true)
	MineLook.add_timber_set(_decor, Vector3(-1.5, 0.0, 7.5), 7.8, 3.0, 0.0, false)
	MineLook.add_timber_set(_decor, Vector3(-4.5, 0.0, 3.0), 5.4, 2.9, 90.0, true)
	MineLook.add_rail_track(_decor, Vector3(-1.5, 0.0, 21.6), 5.0, 0.0, true)  # north of the lift station
	MineLook.add_stencil_sign(_decor, Vector3(2.4, 0.0, 23.4), "COLONY MINE 01", "ORE DRIFT // KEEP CLEAR", -90.0)


## Depth dressing (every depth below the hub): timber sets along the main north-south trunk, a short
## abandoned rail track, dead hanging lamps, and a faded stencil sign tucked
## against the landing wall (visual only, zero collision) [PLACEHOLDER].
func _build_depth_decor() -> void:
	# Nothing stands on the hatch (x -1.5, z 7.5, a 1.4 m disc): the first set is beyond it.
	MineLook.add_timber_set(_decor, Vector3(0.0, 0.0, 10.5), 5.4, 2.9, 0.0, true)
	MineLook.add_timber_set(_decor, Vector3(0.0, 0.0, -1.5), 5.4, 2.9, 0.0, false)
	MineLook.add_timber_set(_decor, Vector3(0.0, 0.0, -10.5), 5.4, 2.9, 0.0, true)
	MineLook.add_rail_track(_decor, Vector3(0.0, 0.0, -2.0), 14.0, 0.0, true)
	MineLook.add_stencil_sign(_decor, Vector3(9.6, 0.0, 13.5), "LEVEL %02d DRIFT" % _built_depth, "SHORE BEFORE ENTRY", -90.0)
	_darken_decor()


## A little darker each depth [PLACEHOLDER]: a dark slab laid over the floor decor would be
## new art, so the decor is dimmed through the material's own albedo, and no light is added
## (the Mine has none). Only the decor is dimmed, not the rock or the labels. Depth 1 is as it was.
func _darken_decor() -> void:
	var keep: float = depth_dim(_built_depth)
	if keep >= 1.0:
		return
	for node: Node in _decor.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.material_override is StandardMaterial3D:
			var dimmed: StandardMaterial3D = (mesh.material_override as StandardMaterial3D).duplicate()
			dimmed.albedo_color = dimmed.albedo_color.darkened(1.0 - keep)
			mesh.material_override = dimmed


## How much of depth 1's brightness a depth keeps: 8 % less a level, to a floor of 50 %
## [PLACEHOLDER] (as the Aquifer's lamps).
static func depth_dim(depth: int) -> float:
	return maxf(DIM_FLOOR, 1.0 - DIM_PER_LEVEL * maxi(depth - 1, 0))


## A rockfall: an ore-stained rubble pile in the side room's mouth; once shored,
## a wedged mine timber arch stands there instead and the room is open [PLACEHOLDER].
func _draw_rockfall(fall: Dictionary) -> void:
	var at: Vector3 = MineDepth.rockfall_position(fall)
	var id: String = str(fall["id"])
	if bool(fall["shored"]):
		MineLook.add_shored_arch(_rockfalls, at, ARCH_SPAN_M, ARCH_HEIGHT_M)
		_rockfalls.add_child(TunnelLook.label("%s SHORED" % id.to_upper(), at + Vector3(0.0, 2.7, 0.0), TunnelLook.CRYSTAL))
	else:
		MineLook.add_mine_rubble(_rockfalls, at, RUBBLE_SCALE)
		_rockfalls.add_child(TunnelLook.label("%s ROCKFALL" % id.to_upper(), at + Vector3(0.0, 1.9, 0.0), TunnelLook.BROKEN_RED))


## The crate that sells shoring props: a weathered timber pallet, rust-strapped
## mine crate, spare shoring posts and wedges, and a label [PLACEHOLDER].
func _draw_crate() -> void:
	_depth_props.add_child(MineLook.build_prop_crate(MineDepth.crate_position()))


## Replaces the default find marker on any colonist's case with a small latched
## crate built from primitives (visual only, no collision) [PLACEHOLDER].
func _build_cases(layout_data: Dictionary) -> void:
	for find: Dictionary in layout_data.get("finds", []):
		if str(find.get("kind", "")) != MineDepth.CASE:
			continue
		var node: Node3D = _depth_props.find_node(str(find.get("id", "")))
		if node == null:
			continue
		for child: Node in node.get_children():
			node.remove_child(child)
			child.free()
		_draw_colonist_case(node)


func _draw_colonist_case(node: Node3D) -> void:
	node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.84, 0.10, 0.64)), Vector3(0.0, 0.05, 0.0), MineLook.flat_mat(MineLook.ORE_DARK)))
	node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.68, 0.28, 0.48)), Vector3(0.0, 0.24, 0.0), MineLook.flat_mat(MineLook.CRATE_BODY)))
	node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.72, 0.07, 0.52)), Vector3(0.0, 0.415, 0.0), MineLook.flat_mat(MineLook.TIMBER_SPLIT)))
	for x_off: float in [-0.24, 0.24]:
		node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.06, 0.36, 0.54)), Vector3(x_off, 0.25, 0.0), MineLook.flat_mat(MineLook.RUST_IRON)))
	var latch: MeshInstance3D = TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.12, 0.04)), Vector3(0.0, 0.36, 0.27), MineLook.flat_mat(MineLook.LAMP_BRASS, 0.65))
	latch.name = &"CaseLatch"
	node.add_child(latch)
	node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.06, 0.08, 0.05)), Vector3(0.0, 0.34, 0.29), TunnelLook.glow_mat(TunnelLook.BRASS, 0.85)))
	node.add_child(TunnelLook.label(MineDepth.NAMES[MineDepth.CASE], Vector3(0.0, 1.5, 0.0), MineLook.CRATE_LABEL))


## The notice board: the Lava hub's with mine-weathered trim and Bram's Mine notices [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("NOTICE BOARD")
	board.name = "NoticeSign"
	board.position = MineDepth.sign_position()
	_depth_props.add_child(board)
	MineLook.add_sign_trim(board)


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
		if ZoneDepth.near_lift(at, 0):
			return _station_near()
		if MineDepth.near_crate(at):
			return { "kind": CRATE, "id": "" }
		if MineDepth.near_sign(at):
			return { "kind": SIGN, "id": "" }
		return {}
	if ZoneDepth.has_way_down(_built_depth) and ZoneDepth.near_descent(at, _built_depth):
		return { "kind": HATCH, "id": "" }
	var found: Dictionary = _nearest_find()
	var fall_near: Dictionary = _rockfall_near(at)
	# A find in a buried room cannot be taken yet: the rockfall in reach is the better prompt.
	if not found.is_empty() and not MineDepth.prefer_rockfall(ZoneDepth.local_layout, str(found.get("id", "")), not fall_near.is_empty()):
		return found  # a find beside the lift wins over the lift
	if ZoneDepth.is_lift_depth(_built_depth) and ZoneDepth.near_lift(at, _built_depth):
		return _station_near()
	return fall_near


## The nearest rockfall still standing within shoring reach of `at`, or {}.
func _rockfall_near(at: Vector3) -> Dictionary:
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
			var shut: String = GameState.deep_problem(MineDepth.ZONE) if ZoneDepth.is_deep(_built_depth + 1) else ""
			_hud.push_log("WAY DOWN: press " + Controls.prompt(&"interact") + " to go down." if shut == "" else "WAY DOWN: " + shut)
		LIFT:
			_hud.push_log(_lift_prompt())
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
			for line: String in MineDepth.board_lines(QuestEngine.quests(), GameState.quest_state,
					GameState.player_quest_state.get(GameState.local_player_id, {})):
				_hud.push_log(line)
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
	var reply: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if reply != "" and not MineDepth.is_case_fallback_reply(reply):
		_hud.push_log("FIND: " + reply)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + (reply if reply != "" else MineDepth.reward_text(str(find.get("kind", "")), _built_depth)))


## A room was shored (here or by a friend): the rockfalls are redrawn in place, so the
## scene (and a co-op driver's rover, and the HUD's lines) stays as it is.
func _resync_depth() -> void:
	super._resync_depth()
	if _below and not SceneSwitcher.is_busy() and GameState.rover_zone == MineDepth.ZONE and _rover.away_text() == "" and not _moving:
		var now: Array = MineDepth.shored_today(GameState.rooms_shored, _built_day, _built_depth)
		if now.size() != _built_shored.size() or now.any(func(id: Variant) -> bool: return not id in _built_shored):
			_rebuild_rockfalls(now)


## Draws this depth's rockfalls again from `shored` (the ids shored today), and marks them
## in the local layout so the prompts see the same.
func _rebuild_rockfalls(shored: Array) -> void:
	_built_shored = shored
	for child: Node in _rockfalls.get_children():
		_rockfalls.remove_child(child)
		child.free()
	for fall: Variant in ZoneDepth.local_layout.get("rockfalls", []):
		if fall is Dictionary:
			fall["shored"] = str(fall["id"]) in shored
			_draw_rockfall(fall)
	_told_hub = ""


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
