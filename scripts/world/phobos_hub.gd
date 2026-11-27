class_name PhobosHub
extends Node3D
## The Phobos hub (docs/design/zones.md section 13, step 17, first half): a small
## dark grey cratered deck under a black sky with Mars large on the horizon, the
## parked shuttle, a station module, the return-shuttle console, the notice board and
## a shut service-tunnel hatch. On foot only, and no low-gravity physics yet. Every
## shape, colour and line is a [PLACEHOLDER]; there are no art files, only boxes.
##
## The escapee hook (zones section 10): the board's station log says stock escaped
## into the warm service tunnels, and a shed skin by a torn grille can be inspected.
## There is no new species, no find and no quest yet: that is a later PR.
##
## The way home: the console asks the host for `shuttle_home`; the trip's end, from
## the host's clock, takes the traveller home as well. Both end the trip, and this
## scene sees that (`shuttle_trips_changed`) and opens the farm again.

## How near the walker must be to use the console, the board or the hatch [PLACEHOLDER].
const REACH_M: float = 9.0
## Where the walker arrives, by the shuttle.
const ARRIVE_AT := Vector3(-2.0, 0.0, 7.0)
## A trip not seen this long after the scene opened is taken as gone, so a screen that
## never got it is not stranded [PLACEHOLDER].
const GRACE_S: float = 3.0
const TOAST_SECONDS: float = 4.0
## The moon this hub is.
const MOON: String = Shuttle.PHOBOS

## Where the parts stand: name -> position.
const SPOTS: Dictionary[String, Vector3] = {
	"Console": Vector3(-6.0, 0.0, 3.0),
	"Board": Vector3(-3.0, 0.0, -8.6),
	"HookSign": Vector3(9.5, 0.0, -8.6),
	"Hatch": Vector3(14.0, 0.0, -2.0),
}

var walker: PhobosWalker
var camera: IsoCamera
var console_click: Clickable
var board_click: Clickable
var hatch_click: Clickable
var hook_click: Inspectable

var _hint: Label
var _clock: Label
var _toast_left: float = 0.0
var _seen_trip: bool = false
var _since_s: float = 0.0
var _leaving: bool = false
var _busy: bool = false
var _asking: bool = false
## Where the way home goes; only tests set it (the real swap would change the scene).
var change_scene: Callable = Callable()


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_build_world()
	_build_walker()
	_build_hud()
	GameState.shuttle_trips_changed.connect(_on_trips_changed)
	GameState.phone_message.connect(_toast)
	_seen_trip = _has_trip()


func _process(delta: float) -> void:
	_clock.text = "%s   %s CR   %s" % [GameClock.format_now(), SP811.integer(GameState.credits), Shuttle.text("hub_title")]
	if _toast_left > 0.0:
		_toast_left -= delta
	else:
		var hovered: Clickable = Clickable.hovered
		_hint.text = hovered.hint if hovered != null and hovered.hint != "" else Shuttle.text("hub_low_gravity")
	if not _seen_trip and not _asking:
		_since_s += delta
		if _since_s > GRACE_S:
			_trip_not_seen()


func _has_trip() -> bool:
	return GameState.shuttle_trips.has(GameState.local_player_id)


func _on_trips_changed() -> void:
	if _has_trip():
		_seen_trip = true
	elif _seen_trip:
		_go_home()


## The trip is over (the console, the clock, the 02:00 straggler sweep): the farm opens,
## where the host has put this player beside the landing pad's terminal.
func _go_home() -> void:
	if _leaving:
		return
	_leaving = true
	if change_scene.is_valid():
		change_scene.call(SceneSwitcher.FARM_SCENE)
	else:
		SceneSwitcher.go_to(SceneSwitcher.FARM_SCENE)


## No trip has come for this player in GRACE_S. On the host that is final: the trip is
## theirs and there is none. A guest may only have a late send, so the host is asked
## (report_place for this moon is accepted exactly while the host has them on a trip,
## and changes nothing): "not away" brings them home; any other answer (they are away,
## or the host did not answer) keeps them here for another grace, and the synced trip
## then comes, or the host's word at the next ask does.
func _trip_not_seen() -> void:
	if not FarmCommands.guest:
		_go_home()
		return
	_asking = true
	var problem: Variant = await FarmCommands.request(&"report_place", [MOON, 0])
	_asking = false
	_since_s = 0.0
	if not is_inside_tree() or _has_trip():
		return
	if str(problem) == Shuttle.text("not_away_text"):
		_go_home()


# --- Build ----------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.33, 0.36)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.name = "Sky"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	# The deck: one flat slab to stand on, with shallow darker craters on it.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Deck"
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(90.0, 1.0, 90.0)
	floor_shape.shape = slab
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	add_child(_part("DeckPlate", Vector3(0.0, -0.05, 0.0), Vector3(72.0, 0.1, 72.0), Color(0.2, 0.2, 0.22)))
	for crater: Vector3 in [Vector3(-14.0, 0.0, -16.0), Vector3(18.0, 0.0, 12.0), Vector3(-22.0, 0.0, 14.0), Vector3(6.0, 0.0, -24.0)]:
		var pit := MeshInstance3D.new()
		pit.name = "Crater"
		var disc := CylinderMesh.new()
		disc.top_radius = 4.0
		disc.bottom_radius = 4.0
		disc.height = 0.04
		pit.mesh = disc
		pit.material_override = _flat(Color(0.12, 0.12, 0.14))
		pit.position = Vector3(crater.x, 0.03, crater.z)
		add_child(pit)
	# Mars: a big flat-shaded sphere low on the horizon, behind the station.
	var mars := MeshInstance3D.new()
	mars.name = "Mars"
	var ball := SphereMesh.new()
	ball.radius = 60.0
	ball.height = 120.0
	ball.radial_segments = 24
	ball.rings = 12
	mars.mesh = ball
	var red := _flat(Color(0.72, 0.34, 0.2))
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mars.material_override = red
	mars.position = Vector3(-75.0, 12.0, -90.0)
	add_child(mars)
	# The parked shuttle: boxes.
	add_child(_part("ShuttleBody", Vector3(-14.0, 1.6, 1.0), Vector3(9.0, 3.2, 3.6), Color(0.78, 0.78, 0.8), true))
	add_child(_part("ShuttleCockpit", Vector3(-19.2, 1.9, 1.0), Vector3(2.0, 2.0, 2.6), Color(0.25, 0.4, 0.5), true))
	add_child(_part("ShuttleWingA", Vector3(-13.0, 0.5, -2.6), Vector3(4.0, 0.3, 3.0), Color(0.6, 0.6, 0.64), true))
	add_child(_part("ShuttleWingB", Vector3(-13.0, 0.5, 4.6), Vector3(4.0, 0.3, 3.0), Color(0.6, 0.6, 0.64), true))
	# The station module and its door.
	add_child(_part("Station", Vector3(2.0, 2.2, -14.0), Vector3(22.0, 4.4, 7.0), Color(0.52, 0.54, 0.58), true))
	add_child(_part("StationDoor", Vector3(2.0, 1.4, -10.45), Vector3(2.2, 2.8, 0.2), Color(0.18, 0.2, 0.24)))
	add_child(_part("StationDome", Vector3(8.0, 4.8, -14.0), Vector3(4.0, 1.2, 4.0), Color(0.62, 0.64, 0.68), true))
	console_click = _make_console()
	board_click = _make_board()
	hook_click = _make_hook_sign()
	hatch_click = _make_hatch()
	console_click.clicked.connect(_on_console)
	board_click.clicked.connect(_on_board)
	hatch_click.clicked.connect(_on_hatch)
	hook_click.inspected.connect(_toast)


func _build_walker() -> void:
	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	camera.ortho_size_m = 24.0
	add_child(camera)
	walker = PhobosWalker.new()
	walker.name = "Walker"
	walker.camera = camera
	add_child(walker)
	walker.position = ARRIVE_AT
	walker.model.set_suit(WalkerModel.suit_for(GameState.local_player_id, CoopSession.players))
	camera.target = walker
	camera.current = true


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_clock = Label.new()
	_clock.name = "ClockLabel"
	_clock.position = Vector2(16.0, 12.0)
	_clock.add_theme_font_size_override(&"font_size", 22)
	ui.add_child(_clock)
	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -64.0
	_hint.offset_left = 16.0
	_hint.add_theme_font_size_override(&"font_size", 20)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_hint)
	ui.add_child(SkillsUI.new())
	ui.add_child(ToolRollUI.new())
	ui.add_child(PickerUI.new())
	ui.add_child(ControlsGuideUI.new())
	ui.add_child(QuestsUI.new())
	ui.add_child(CoopUI.new())
	ui.add_child(ActionsMenuUI.new(ActionsMenuUI.PANEL_ACTIONS))


## A coloured box. `solid` also stops the walker (layer 1).
func _part(part_name: String, at: Vector3, size: Vector3, colour: Color, solid: bool = false) -> Node3D:
	var box := MeshInstance3D.new()
	box.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = _flat(colour)
	box.position = at
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var hull := BoxShape3D.new()
		hull.size = size
		shape.shape = hull
		body.add_child(shape)
		box.add_child(body)
	return box


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


## A click target: layer 8, no mask, a box of `size` at `at`.
func _clickable(click: Clickable, at: Vector3, size: Vector3, hint_text: String) -> Clickable:
	click.collision_layer = 8
	click.collision_mask = 0
	if hint_text != "":
		click.hint = hint_text
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	click.add_child(shape)
	click.position = at
	if click.get_parent() == null:
		add_child(click)
	return click


func _label(text: String, at: Vector3, size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = 0.01
	label.font_size = size
	label.modulate = colour
	label.position = at
	label.width = 400.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_console() -> Clickable:
	var at: Vector3 = SPOTS["Console"]
	var root := Node3D.new()
	root.name = "ConsoleDesk"
	root.position = at
	root.add_child(_part("Desk", Vector3(0.0, 0.5, 0.0), Vector3(1.4, 1.0, 0.7), Color(0.3, 0.32, 0.36), true))
	var screen: Node3D = _part("Screen", Vector3(0.0, 1.3, -0.1), Vector3(1.2, 0.7, 0.06), Color(0.1, 0.4, 0.38))
	screen.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	root.add_child(screen)
	root.add_child(_label("RETURN SHUTTLE", Vector3(0.0, 1.3, -0.05), 40, Color(0.22, 0.88, 0.78)))
	add_child(root)
	var click: Clickable = _clickable(Clickable.new(), at + Vector3(0.0, 0.9, 0.0), Vector3(1.5, 1.8, 0.9), Shuttle.text("hub_hint_console"))
	click.name = "Console"
	return click


func _make_board() -> Clickable:
	var at: Vector3 = SPOTS["Board"]
	add_child(_part("BoardPanel", at + Vector3(0.0, 1.6, 0.0), Vector3(3.0, 1.8, 0.12), Color(0.25, 0.2, 0.14)))
	add_child(_label(Shuttle.text("hub_board_log"), at + Vector3(0.0, 1.6, 0.1), 24, Color(0.95, 0.9, 0.75)))
	var click: Clickable = _clickable(Clickable.new(), at + Vector3(0.0, 1.5, 0.0), Vector3(3.2, 2.2, 0.8), Shuttle.text("hub_hint_board"))
	click.name = "Board"
	return click


func _make_hook_sign() -> Inspectable:
	var at: Vector3 = SPOTS["HookSign"]
	# A torn mesh grille low on the station wall, a pale shed skin caught in it.
	add_child(_part("Grille", at + Vector3(0.0, 0.7, 0.0), Vector3(1.6, 1.0, 0.1), Color(0.14, 0.14, 0.16)))
	add_child(_part("GrilleTear", at + Vector3(0.2, 0.55, 0.08), Vector3(0.7, 0.6, 0.05), Color(0.02, 0.02, 0.03)))
	add_child(_part("ShedSkin", at + Vector3(0.9, 0.3, 0.35), Vector3(0.6, 0.18, 0.3), Color(0.93, 0.88, 0.7)))
	# The sign is placed in the scene file (its prop_id is data/props.json's); this
	# gives it a shape and a place.
	var click: Inspectable = get_node("HookSign") as Inspectable
	_clickable(click, at + Vector3(0.4, 0.6, 0.2), Vector3(2.2, 1.4, 0.9), "")
	return click


func _make_hatch() -> Clickable:
	var at: Vector3 = SPOTS["Hatch"]
	add_child(_part("HatchPlate", at + Vector3(0.0, 0.06, 0.0), Vector3(2.4, 0.12, 2.4), Color(0.45, 0.4, 0.1)))
	add_child(_part("HatchLid", at + Vector3(0.0, 0.14, 0.0), Vector3(2.0, 0.06, 2.0), Color(0.16, 0.16, 0.18)))
	var click: Clickable = _clickable(Clickable.new(), at + Vector3(0.0, 0.3, 0.0), Vector3(2.6, 0.8, 2.6), Shuttle.text("hub_hint_hatch"))
	click.name = "Hatch"
	return click


# --- Use ------------------------------------------------------------------------

## The metres from the walker to a part, flat.
func distance_to(part_name: String) -> float:
	var at: Vector3 = SPOTS[part_name]
	return Vector2(walker.global_position.x - at.x, walker.global_position.z - at.z).length()


func _near(part_name: String) -> bool:
	if distance_to(part_name) <= REACH_M:
		return true
	_toast(Shuttle.text("hub_too_far"))
	return false


func _on_console() -> void:
	if _busy or not _near("Console"):
		return
	_busy = true
	var problem: String = await FarmCommands.request(&"shuttle_home")
	_busy = false
	if problem != "" and is_inside_tree():
		_toast(problem)


func _on_board() -> void:
	if _near("Board"):
		_toast(Shuttle.text("hub_board_log"))


func _on_hatch() -> void:
	if _near("Hatch"):
		_toast(Shuttle.text("hub_hatch_text"))


func _toast(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_toast_left = maxf(TOAST_SECONDS, text.length() * 0.04)
