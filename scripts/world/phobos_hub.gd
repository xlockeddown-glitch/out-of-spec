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
## Offset from the hatch when climbing back up from the service tunnel [PLACEHOLDER].
const HATCH_ARRIVE_OFFSET := Vector3(-2.0, 0.0, 0.0)
## Set by PhobosServiceTunnel when climbing back up the ladder.
static var arrive_at_hatch: bool = false
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
	_clock.text = "%s   %s CR   %s" % [GameClock.format_now(), SP811.integer(GameState.credits), _title()]
	if _toast_left > 0.0:
		_toast_left -= delta
	else:
		var hovered: Clickable = Clickable.hovered
		_hint.text = hovered.hint if hovered != null and hovered.hint != "" else Shuttle.text("hub_low_gravity")
	if not _seen_trip and not _asking:
		_since_s += delta
		if _since_s > GRACE_S:
			_trip_not_seen()


## What differs between the moons' hubs: which moon, the title line, where the parts stand
## and what the board says. DeimosHub overrides these (and _build_world).
func _moon() -> String:
	return MOON


func _title() -> String:
	return Shuttle.text("hub_title")


func _spots() -> Dictionary[String, Vector3]:
	return SPOTS


func _board_text() -> String:
	return Shuttle.text("hub_board_log")


## What the board panel shows, painted once: short and unchanging. The toast says
## `_board_text()`, which may carry things that change (a shuttle window).
func _board_painted() -> String:
	return _board_text()


## True while the host has this player on a trip to THIS moon.
func _has_trip() -> bool:
	var trip: Variant = GameState.shuttle_trips.get(GameState.local_player_id)
	return trip is Dictionary and str((trip as Dictionary).get("moon", "")) == _moon()


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
	var problem: Variant = await FarmCommands.request(&"report_place", [_moon(), 0])
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
	env.background_color = MoonLook.PHOBOS_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = MoonLook.PHOBOS_AMBIENT
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
	# The deck: one flat slab to stand on, with shallow cratered basins and outer ridges.
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
	add_child(_part("DeckPlate", Vector3(0.0, -0.05, 0.0), Vector3(72.0, 0.1, 72.0), MoonLook.PHOBOS_DECK))
	var crater_spots: Array[Vector3] = [Vector3(-14.0, 0.0, -16.0), Vector3(18.0, 0.0, 12.0), Vector3(-22.0, 0.0, 14.0), Vector3(6.0, 0.0, -24.0)]
	for i: int in crater_spots.size():
		MoonLook.add_crater(self, crater_spots[i], 4.0, MoonLook.PHOBOS_CRATER, MoonLook.PHOBOS_RIM, 11 + i)
	MoonLook.add_outer_rocks(self, 101, MoonLook.PHOBOS_BOULDER, MoonLook.PHOBOS_RIM, false)
	MoonLook.add_lander_pad(self, Vector3(-14.0, 0.0, 1.0), false)
	# Mars: a big flat-shaded sphere low on the horizon, behind the station.
	MoonLook.add_mars(self, Vector3(-75.0, 12.0, -90.0), 60.0, MoonLook.PHOBOS_MARS)
	# The parked shuttle: solid collision boxes + visual details.
	add_child(_part("ShuttleBody", Vector3(-14.0, 1.6, 1.0), Vector3(9.0, 3.2, 3.6), MoonLook.PHOBOS_HULL, true))
	add_child(_part("ShuttleCockpit", Vector3(-19.2, 1.9, 1.0), Vector3(2.0, 2.0, 2.6), MoonLook.COCKPIT_GLASS, true))
	add_child(_part("ShuttleWingA", Vector3(-13.0, 0.5, -2.6), Vector3(4.0, 0.3, 3.0), MoonLook.PHOBOS_WING, true))
	add_child(_part("ShuttleWingB", Vector3(-13.0, 0.5, 4.6), Vector3(4.0, 0.3, 3.0), MoonLook.PHOBOS_WING, true))
	MoonLook.add_shuttle_detail(self, MoonLook.PHOBOS_HULL, MoonLook.PHOBOS_WING)
	# The station module, its door, and visual facade dressing.
	add_child(_part("Station", Vector3(2.0, 2.2, -14.0), Vector3(22.0, 4.4, 7.0), MoonLook.PHOBOS_STATION, true))
	add_child(_part("StationDoor", Vector3(2.0, 1.4, -10.45), Vector3(2.2, 2.8, 0.2), MoonLook.DARK_METAL))
	add_child(_part("StationDome", Vector3(8.0, 4.8, -14.0), Vector3(4.0, 1.2, 4.0), MoonLook.PHOBOS_WING, true))
	MoonLook.add_phobos_station_detail(self)
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
	if arrive_at_hatch:
		arrive_at_hatch = false
		walker.position = SPOTS["Hatch"] + HATCH_ARRIVE_OFFSET
	else:
		walker.position = ARRIVE_AT
	walker.model.set_suit(WalkerModel.suit_for(GameState.local_player_id, CoopSession.players))
	_dress_walker()
	GameState.loadouts_changed.connect(_dress_walker)
	camera.target = walker
	camera.current = true


## The walker wears the parts this player picked (the picker opens here too).
func _dress_walker() -> void:
	walker.model.set_loadout(GameState.loadout_of()["parts"])


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
	return TunnelLook.flat_mat(colour)


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
	var at: Vector3 = _spots()["Console"]
	var root := Node3D.new()
	root.name = "ConsoleDesk"
	root.position = at
	root.add_child(_part("Desk", Vector3(0.0, 0.5, 0.0), Vector3(1.4, 1.0, 0.7), MoonLook.PHOBOS_STATION_TRIM, true))
	var screen: Node3D = _part("Screen", Vector3(0.0, 1.3, -0.1), Vector3(1.2, 0.7, 0.06), MoonLook.COCKPIT_GLASS)
	screen.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	root.add_child(screen)
	MoonLook.add_console_detail(root)
	root.add_child(_label("RETURN SHUTTLE", Vector3(0.0, 1.3, -0.02), 40, MoonLook.SCREEN_GLOW))
	add_child(root)
	var click: Clickable = _clickable(Clickable.new(), at + Vector3(0.0, 0.9, 0.0), Vector3(1.5, 1.8, 0.9), Shuttle.text("hub_hint_console"))
	click.name = "Console"
	return click


func _make_board() -> Clickable:
	var at: Vector3 = _spots()["Board"]
	add_child(_part("BoardPanel", at + Vector3(0.0, 1.6, 0.0), Vector3(3.0, 1.8, 0.12), MoonLook.BOARD_WOOD))
	MoonLook.add_board_detail(self, at)
	add_child(_label(_board_painted(), at + Vector3(0.0, 1.6, 0.1), 24, MoonLook.CREAM))
	var click: Clickable = _clickable(Clickable.new(), at + Vector3(0.0, 1.5, 0.0), Vector3(3.2, 2.2, 0.8), Shuttle.text("hub_hint_board"))
	click.name = "Board"
	return click


func _make_hook_sign() -> Inspectable:
	var at: Vector3 = SPOTS["HookSign"]
	# A torn mesh grille low on the station wall, a pale shed skin caught in it.
	add_child(_part("Grille", at + Vector3(0.0, 0.7, 0.0), Vector3(1.6, 1.0, 0.1), MoonLook.PHOBOS_BOULDER))
	add_child(_part("GrilleTear", at + Vector3(0.2, 0.55, 0.08), Vector3(0.7, 0.6, 0.05), MoonLook.DARK_METAL))
	add_child(_part("ShedSkin", at + Vector3(0.9, 0.3, 0.35), Vector3(0.6, 0.18, 0.3), MoonLook.SKIN_PALE))
	MoonLook.add_hook_detail(self, at)
	# The sign is placed in the scene file (its prop_id is data/props.json's); this
	# gives it a shape and a place.
	var click: Inspectable = get_node("HookSign") as Inspectable
	_clickable(click, at + Vector3(0.4, 0.6, 0.2), Vector3(2.2, 1.4, 0.9), "")
	return click


func _make_hatch() -> Clickable:
	var at: Vector3 = SPOTS["Hatch"]
	add_child(_part("HatchPlate", at + Vector3(0.0, 0.06, 0.0), Vector3(2.4, 0.12, 2.4), MoonLook.HATCH_RIM))
	add_child(_part("HatchLid", at + Vector3(0.0, 0.14, 0.0), Vector3(2.0, 0.06, 2.0), MoonLook.PHOBOS_BOULDER))
	MoonLook.add_hatch_detail(self, at)
	var click: Clickable = _clickable(Clickable.new(), at + Vector3(0.0, 0.3, 0.0), Vector3(2.6, 0.8, 2.6), Shuttle.text("hub_hint_hatch"))
	click.name = "Hatch"
	return click


# --- Use ------------------------------------------------------------------------

## The metres from the walker to a part, flat.
func distance_to(part_name: String) -> float:
	var at: Vector3 = _spots()[part_name]
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
		_toast(_board_text())


func _on_hatch() -> void:
	if _moon() != MOON:
		_toast(Shuttle.text("hub_hatch_text"))
		return
	if not _near("Hatch") or _leaving:
		return
	_leaving = true
	if change_scene.is_valid():
		change_scene.call(PhobosServiceTunnel.SCENE_PATH)
	else:
		SceneSwitcher.go_to(PhobosServiceTunnel.SCENE_PATH)


func _toast(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_toast_left = maxf(TOAST_SECONDS, text.length() * 0.04)
