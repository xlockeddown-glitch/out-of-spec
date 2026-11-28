class_name VallesHub
extends "res://scripts/basalt_tunnels.gd"
## Valles Marineris' scene (the first far site): the tunnels' scene with the canyon's hub (an
## open floor between two tall layered walls, talus at the wall feet, the way down, a notice
## board) and its depths (rooms and finds). Built in code from primitives (VallesLook); the
## rules are VallesDepth's and the host's. Wind and thin air are told on the HUD; the air is
## GameState's (`cold_since`, read through `cold_of`). A look [PLACEHOLDER]: no art yet.

const SIGN: String = "sign"
## The stem's x range (columns 10 to 12), kept clear of walls and talus.
const STEM_X: Vector2 = Vector2(-7.0, 4.0)

## The air reading last told, in steps of AIR_STEP percent, and whether it was past the warning.
const AIR_STEP: int = 10
var _told_air_step: int = -1
var _told_warn: bool = false
## The wind state last told: -1 nothing yet, else gust (2) or calm (1) plus 10 when sheltered.
var _told_wind: int = -1
var _decor: Node3D


func _zone_id() -> String:
	return VallesDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_decor = Node3D.new()
	_decor.name = "VallesDecor"
	_rover.get_parent().add_child(_decor)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		if _built_depth < VallesDepth.MAX_DEPTH:
			_depth_props.build_hatch(_built_depth)
		GameState.finds_changed.connect(_on_finds_changed)
	else:
		_depth_props.build_hatch()
		_draw_walls()
		_draw_sign()
		_build_hub_decor()


## The canyon's two walls: a banded face along the north and the south edge of the floor [PLACEHOLDER].
func _draw_walls() -> void:
	VallesLook.add_band_wall(_depth_props, Vector3(0.0, 0.0, -18.6), Vector2(66.0, 1.2))
	# The south wall stops short of the stem (x -7 to 4) that the rover drives through.
	VallesLook.add_band_wall(_depth_props, Vector3(-20.0, 0.0, 3.6), Vector2(26.0, 1.2))
	VallesLook.add_band_wall(_depth_props, Vector3(18.5, 0.0, 3.6), Vector2(29.0, 1.2))


## Talus heaps along each wall foot, a core rack and a banded post pair at the way down
## (visual only, zero collision, the open middle stays clear) [PLACEHOLDER].
func _build_hub_decor() -> void:
	var salt: int = 0
	for x: float in [-27.0, -17.0, -6.0, 5.0, 16.0, 27.0]:
		VallesLook.add_talus(_decor, Vector3(x, 0.0, -17.0), 5.0, salt)
		if x + 2.5 < STEM_X.x - 2.0 or x + 2.5 > STEM_X.y + 2.0:  # none in the stem
			VallesLook.add_talus(_decor, Vector3(x + 2.5, 0.0, 2.3), 4.0, salt + 50)
		salt += 3
	var sign_pos: Vector3 = VallesDepth.sign_position()
	for i: int in 3:
		VallesLook.add_core(_decor, Vector3(sign_pos.x + 2.6 + float(i) * 0.5, 0.0, sign_pos.z - 0.6))
	var hatch: Vector3 = VallesDepth.hatch_position()
	for side: float in [-2.2, 2.2]:
		VallesLook.add_banded_post(_decor, Vector3(hatch.x + side, 0.0, hatch.z - 1.6), 1.6)


## The notice board with a salt-white cap and the canyon's notices [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("NOTICE BOARD")
	board.name = "NoticeSign"
	board.position = VallesDepth.sign_position()
	_depth_props.add_child(board)
	VallesLook.add_sign_trim(board)


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	_in_reach = false  # no Sentinel here
	_hub_near = _valles_near() if _rover.away_text() == "" else {}
	_tell_hub()
	_tell_air()
	_tell_wind()


## The way down or the sign at the hub; below, the way further down or the nearest find: or {}.
func _valles_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if _below:
		if _built_depth < VallesDepth.MAX_DEPTH and ZoneDepth.near_descent(at, _built_depth):
			return { "kind": HATCH, "id": "" }
		return _nearest_find()
	if VallesDepth.near_hatch(at):
		return { "kind": HATCH, "id": "" }
	if VallesDepth.near_sign(at):
		return { "kind": SIGN, "id": "" }
	return {}


## The suit's air, told in the log when the player comes in, every AIR_STEP percent, and when
## the pack crosses (or comes back under) the warning.
func _tell_air() -> void:
	var used: float = GameState.cold_of(GameState.local_player_id)
	var step: int = int(used) / AIR_STEP
	var warn: bool = used >= VallesDepth.AIR_WARN
	if step == _told_air_step and warn == _told_warn:
		return
	var first: bool = _told_air_step < 0
	_told_air_step = step
	_told_warn = warn
	if first and used <= 0.0:
		return
	_hud.push_log("THIN AIR: " + VallesDepth.air_text(used))


## The wind state, told when it changes (a gust starts or ends, or the rover enters or leaves shelter).
func _tell_wind() -> void:
	var grid: PackedStringArray = TunnelRock.grid()
	var at: Vector3 = _rover.global_position
	var cell := Vector2i(roundi(at.x / TunnelRock.CELL_M + (ZoneDepth.WIDTH - 1) * 0.5),
			roundi(at.z / TunnelRock.CELL_M + (ZoneDepth.HEIGHT - 1) * 0.5))
	var gust: bool = VallesDepth.gusting(GameState.world_seed, _built_depth, GameClock.elapsed_days)
	var shelter: bool = VallesDepth.sheltered(grid, cell)
	var state: int = (2 if gust else 1) + (10 if shelter else 0)
	if state == _told_wind:
		return
	var first: bool = _told_wind < 0
	_told_wind = state
	if first and not gust:
		return
	_hud.push_log(VallesDepth.wind_text(gust, shelter))


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


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		SIGN:
			for line: String in NoticeBoard.lines(QuestEngine.quests(), GameState.quest_state,
					GameState.player_quest_state.get(GameState.local_player_id, {}), "zone", VallesDepth.ZONE):
				_hud.push_log(line)
		_:
			super._use_hub(target)


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, VallesDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + VallesDepth.reward_text(str(find.get("kind", "")), int(find.get("band", -1))))


func _on_rover_entered_exit() -> void:
	_hud.push_log("WAY UP: press " + Controls.prompt(&"interact") + " to go up." if _below else "CANYON ROAD: press " + Controls.prompt(&"interact") + " to drive out.")


## Takes the rover out onto the canyon road and goes with it.
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
			_hud.push_log("CANYON ROAD: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover_valles", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("CANYON ROAD: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()
