class_name OlympusHub
extends "res://scripts/basalt_tunnels.gd"
## The Olympus Mons caves' scene (the second far site): the tunnels' scene with a huge lava-tube
## hall (a shaft of skylight, a few huge breakdown blocks, the way down, a notice board) and its
## depths (further along the tube: rooms, finds, a skylight each). Built in code from primitives
## (OlympusLook); the rules are OlympusDepth's and the host's. Heat is told on the HUD; it is
## GameState's (`cold_since`, read through `cold_of`). Below, the phone points back to the skylight
## once the player has left a marker (leave_marker: B, or D-pad right). A look [PLACEHOLDER]: no art yet.

const SIGN: String = "sign"
## Cells of the hall (OlympusDepth.HALL) the huge breakdown blocks stand in, with their sizes in
## metres [PLACEHOLDER]. None is on the stem (columns 10 to 12), the sign or the skylight.
const BLOCKS: Array = [
	[Vector2i(3, 10), Vector3(6.0, 4.5, 4.5)],
	[Vector2i(17, 4), Vector3(7.0, 5.5, 5.0)],
	[Vector2i(20, 10), Vector3(5.0, 4.0, 6.0)],
	[Vector2i(15, 11), Vector3(4.0, 3.0, 3.5)],
]

## The heat reading last told, in steps of HEAT_STEP percent, and whether it was past the warning.
const HEAT_STEP: int = 10
var _told_heat_step: int = -1
var _told_warn: bool = false
var _decor: Node3D
var _beacons: Node3D


func _zone_id() -> String:
	return OlympusDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_decor = Node3D.new()
	_decor.name = "OlympusDecor"
	_rover.get_parent().add_child(_decor)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		if _built_depth < OlympusDepth.MAX_DEPTH:
			_depth_props.build_hatch(_built_depth)
		GameState.finds_changed.connect(_on_finds_changed)
		_beacons = Node3D.new()
		_beacons.name = "MarkerBeacons"
		_rover.get_parent().add_child(_beacons)
		GameState.olympus_changed.connect(_draw_markers)
		_draw_markers()
		var sky: Vector3 = skylight_position()
		OlympusLook.add_skylight(_decor, sky)
	else:
		_depth_props.build_hatch()
		_draw_sign()
		_build_hub_decor()


## Where the skylight is on the screen the rover is on: the hall's, or the depth's own.
func skylight_position() -> Vector3:
	if not _below:
		return OlympusDepth.hub_skylight_position()
	return TunnelRock.at(ZoneDepth.local_layout["skylight"])


## The shaft of light and the huge breakdown blocks (visual only, zero collision, the stem and the
## open middle stay clear) [PLACEHOLDER].
func _build_hub_decor() -> void:
	OlympusLook.add_skylight(_decor, OlympusDepth.hub_skylight_position())
	var grid: PackedStringArray = OlympusDepth.hub_grid()
	var salt: int = 0
	for entry: Array in BLOCKS:
		OlympusLook.add_breakdown_block(_decor, TunnelRock.at_in(grid, entry[0]), entry[1], salt)
		salt += 5
	var hatch: Vector3 = OlympusDepth.hatch_position()
	for side: float in [-2.2, 2.2]:
		OlympusLook.add_pillar(_decor, Vector3(hatch.x + side, 0.0, hatch.z - 1.6), 2.4)


## A small beacon at the marker each player left on this depth today (every marker is shown).
func _draw_markers() -> void:
	if _beacons == null or not is_instance_valid(_beacons):
		return
	for child: Node in _beacons.get_children():
		_beacons.remove_child(child)
		child.queue_free()
	var day: int = GameClock.get_day_index()
	for key: Variant in GameState.olympus_markers:
		var entry: Variant = GameState.olympus_markers[key]
		if not entry is Array or (entry as Array).size() < 3 or int(entry[0]) != day:
			continue
		if not str(key).ends_with(":%d" % _built_depth):
			continue
		OlympusLook.add_marker_beacon(_beacons, TunnelRock.at(Vector2i(int(entry[1]), int(entry[2]))))


## The notice board with an ember cap and the tube's notices [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("NOTICE BOARD")
	board.name = "NoticeSign"
	board.position = OlympusDepth.sign_position()
	_depth_props.add_child(board)
	OlympusLook.add_sign_trim(board)


## The phone's line: the way back to the skylight if the player has left a marker on this depth
## today (`from` is the rover, `to` the skylight), else the usual line `usual`. The hall under the
## skylight (depth 0) has no heading.
static func phone_line(below: bool, marked: bool, from: Vector3, to: Vector3, usual: String) -> String:
	if below and marked:
		return OlympusDepth.heading_text(from, to)
	return usual


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	var usual: String = GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else ""
	var marked: bool = _below and OlympusDepth.has_marker(GameState.olympus_markers, GameState.local_player_id, _built_depth, GameClock.get_day_index())
	_hud.set_molt(phone_line(_below, marked, _rover.global_position, skylight_position() if _below else Vector3.ZERO, usual))
	_in_reach = false  # no Sentinel here
	_hub_near = _olympus_near() if _rover.away_text() == "" else {}
	_tell_hub()
	_tell_heat()


## The way down or the sign at the hub; below, the way further down or the nearest find: or {}.
func _olympus_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if _below:
		if _built_depth < OlympusDepth.MAX_DEPTH and ZoneDepth.near_descent(at, _built_depth):
			return { "kind": HATCH, "id": "" }
		return _nearest_find()
	if OlympusDepth.near_hatch(at):
		return { "kind": HATCH, "id": "" }
	if OlympusDepth.near_sign(at):
		return { "kind": SIGN, "id": "" }
	return {}


## The suit's cooling, told in the log when the player comes in, every HEAT_STEP percent, and when
## the pack crosses (or comes back under) the warning.
func _tell_heat() -> void:
	var used: float = GameState.cold_of(GameState.local_player_id)
	var step: int = int(used) / HEAT_STEP
	var warn: bool = used >= OlympusDepth.HEAT_WARN
	if step == _told_heat_step and warn == _told_warn:
		return
	var first: bool = _told_heat_step < 0
	_told_heat_step = step
	_told_warn = warn
	if first and used <= 0.0:
		return
	_hud.push_log("HEAT: " + OlympusDepth.heat_text(used))


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
		SIGN:
			_hud.push_log("NOTICE SIGN: press " + Controls.prompt(&"interact") + " to read it.")


func _unhandled_input(event: InputEvent) -> void:
	if _below and event.is_action_pressed(&"leave_marker") and _rover.away_text() == "":
		get_viewport().set_input_as_handled()
		_place_marker()
		return
	super._unhandled_input(event)


## Leaves a marker where the rover stands (the host decides; one per player per depth per day).
func _place_marker() -> void:
	var problem: String = await FarmCommands.request(&"place_marker")
	if not is_inside_tree():
		return
	_hud.push_log("MARKER: " + (OlympusDepth.marker_reply(_built_depth) if problem == "" else problem))


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		SIGN:
			for line: String in NoticeBoard.lines(QuestEngine.quests(), GameState.quest_state,
					GameState.player_quest_state.get(GameState.local_player_id, {}), "zone", OlympusDepth.ZONE):
				_hud.push_log(line)
		_:
			super._use_hub(target)


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, OlympusDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + OlympusDepth.reward_text(str(find.get("kind", "")), int(find.get("vein", -1))))


func _on_rover_entered_exit() -> void:
	var marker: String = " Press " + Controls.prompt(&"leave_marker") + " to leave a marker." if _below else ""
	_hud.push_log(("WAY UP: press " + Controls.prompt(&"interact") + " to go up." + marker) if _below else "CLIMB TRACK: press " + Controls.prompt(&"interact") + " to drive down to the farm.")


## Takes the rover out onto the climb track and goes with it.
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
			_hud.push_log("CLIMB TRACK: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover_olympus", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("CLIMB TRACK: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()
