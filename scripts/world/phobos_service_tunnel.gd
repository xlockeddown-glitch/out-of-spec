class_name PhobosServiceTunnel
extends Node3D
## Phobos warm service tunnel (part 1 of Phobos content): a short, cramped,
## warm station conduit beneath the Phobos hub hatch with pipe runs, glowing
## thermal vents, grating floor, old station signage, a ladder back up to the
## hub, and a few daily-placed Banded Regolith Runner strays to inspect.
##
## Part 2: clicking a stray asks the host to catch it (FarmCommands catch_stray). A
## caught stray vanishes for everyone, and the first one goes to a tank in the dome as
## station stock. Every number, colour, and hash choice is a [PLACEHOLDER].

const SCENE_PATH: String = "res://scenes/phobos_service_tunnel.tscn"
const TITLE_TEXT: String = "PHOBOS // SERVICE TUNNEL"
const AMBIENT_HINT: String = "Warm station conduit. Click the ladder to climb back up, or inspect a stray."
const LADDER_HINT: String = "Ladder up to Phobos hub"
const STRAY_HINT: String = "Banded Regolith Runner (stray). %s"
const STRAY_CAUGHT_TEXT: String = "Caught. A Banded Regolith Runner. %s. Odalys will want to hear."
const STRAY_LET_GO_TEXT: String = "Caught, and let go: the dome already has its Runner."
const TOO_FAR_TEXT: String = "Move closer."
const SIGN_TEXT: String = "SECTOR 04 // THERMAL CONDUIT"

## Corridor & interaction constants, in metres [PLACEHOLDER].
const HALF_LENGTH_M: float = 14.0
const HALF_WIDTH_M: float = 3.2
const WALL_HEIGHT_M: float = 3.6
const REACH_M: float = 6.5
const ARRIVE_AT := Vector3(-9.5, 0.0, 0.0)
const LADDER_AT := Vector3(-11.8, 0.0, -2.5)
const GRACE_S: float = PhobosHub.GRACE_S
const TOAST_SECONDS: float = PhobosHub.TOAST_SECONDS

## Daily stray placement: 3 spiders chosen deterministically from 7 warm spots [PLACEHOLDER].
const STRAY_COUNT: int = 3
const STRAY_HASH_SALT: int = 407
const STRAY_SCALE: float = 1.85
const STRAY_IDLE_DEG: float = 7.0
const STRAY_IDLE_SPEED: float = 1.8
const STRAY_SPOTS: Array[Vector3] = [
	Vector3(-7.6, 0.06, -2.2),
	Vector3(-4.2, 0.06, -1.9),
	Vector3(-1.8, 0.06, 1.8),
	Vector3(2.8, 0.06, -2.2),
	Vector3(5.6, 0.06, 1.7),
	Vector3(8.4, 0.06, -2.1),
	Vector3(11.2, 0.06, 0.4),
]

var walker: PhobosWalker
var camera: IsoCamera
var ladder_click: Clickable
var stray_clicks: Array[Clickable] = []
var stray_nodes: Array[Node3D] = []
## The spot index (STRAY_SPOTS) of each stray node, in the same order.
var stray_indices: Array[int] = []
var _catching: bool = false

var _hint: Label
var _clock: Label
var _toast_left: float = 0.0
var _idle_t: float = 0.0
var _seen_trip: bool = false
var _since_s: float = 0.0
var _leaving: bool = false
var _asking: bool = false
## Where scene swaps go; only tests set it (the real swap calls SceneSwitcher.go_to).
var change_scene: Callable = Callable()


## Deterministic distinct spot indices in STRAY_SPOTS for `day` (no global RNG) [PLACEHOLDER].
static func stray_indices_for_day(day: int) -> Array[int]:
	var pool: Array[int] = []
	for i: int in STRAY_SPOTS.size():
		pool.append(i)
	var picked: Array[int] = []
	for slot: int in mini(STRAY_COUNT, pool.size()):
		var h: int = MoonLook.hash_int(day, slot, STRAY_HASH_SALT)
		var pick_i: int = h % pool.size()
		picked.append(pool[pick_i])
		pool.remove_at(pick_i)
	return picked


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_build_world()
	_build_walker()
	_build_hud()
	GameState.shuttle_trips_changed.connect(_on_trips_changed)
	GameState.phone_message.connect(_toast)
	_seen_trip = _has_trip()


func _exit_tree() -> void:
	if GameState.strays_changed.is_connected(_show_strays):
		GameState.strays_changed.disconnect(_show_strays)
	if GameState.loadouts_changed.is_connected(_dress_walker):
		GameState.loadouts_changed.disconnect(_dress_walker)


func _input(event: InputEvent) -> void:
	# Block Tab farm/dome swap while inside the Phobos service tunnel.
	if event.is_action_pressed(&"swap_scene"):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_clock.text = "%s   %s CR   %s" % [GameClock.format_now(), SP811.integer(GameState.credits), TITLE_TEXT]
	_idle_t += delta
	for i: int in stray_nodes.size():
		var spider: Node3D = stray_nodes[i]
		if is_instance_valid(spider):
			var base_yaw: float = float(spider.get_meta(&"base_yaw", 0.0))
			spider.rotation_degrees.y = base_yaw + sin(_idle_t * STRAY_IDLE_SPEED + float(i) * 1.7) * STRAY_IDLE_DEG
	if _toast_left > 0.0:
		_toast_left -= delta
	else:
		var hovered: Clickable = Clickable.hovered
		_hint.text = hovered.hint if hovered != null and hovered.hint != "" else AMBIENT_HINT
	if not _seen_trip and not _asking:
		_since_s += delta
		if _since_s > GRACE_S:
			_trip_not_seen()


func _has_trip() -> bool:
	var trip: Variant = GameState.shuttle_trips.get(GameState.local_player_id)
	return trip is Dictionary and str((trip as Dictionary).get("moon", "")) == Shuttle.PHOBOS


func _on_trips_changed() -> void:
	if _has_trip():
		_seen_trip = true
	elif _seen_trip:
		_go_home()


func _go_home() -> void:
	if _leaving:
		return
	_leaving = true
	_swap_to(SceneSwitcher.FARM_SCENE)


func _trip_not_seen() -> void:
	if not FarmCommands.guest:
		_go_home()
		return
	_asking = true
	var problem: Variant = await FarmCommands.request(&"report_place", [Shuttle.PHOBOS, 0])
	_asking = false
	_since_s = 0.0
	if not is_inside_tree() or _has_trip():
		return
	if str(problem) == Shuttle.text("not_away_text"):
		_go_home()


func _swap_to(path: String) -> void:
	if change_scene.is_valid():
		change_scene.call(path)
	else:
		SceneSwitcher.go_to(path)


# --- Build ----------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = MoonLook.TUNNEL_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = MoonLook.TUNNEL_AMBIENT
	env.ambient_light_energy = 0.85
	var world_env := WorldEnvironment.new()
	world_env.name = "Sky"
	world_env.environment = env
	add_child(world_env)

	# At most two lights in the tunnel: two warm amber conduit lamps [PLACEHOLDER].
	for i: int in 2:
		var lamp := OmniLight3D.new()
		lamp.name = "ConduitLight_%d" % i
		lamp.position = Vector3(-5.5 if i == 0 else 5.5, 2.7, 0.0)
		lamp.light_color = MoonLook.TUNNEL_WARM_LIGHT
		lamp.light_energy = MoonLook.TUNNEL_LIGHT_ENERGY
		lamp.omni_range = MoonLook.TUNNEL_LIGHT_RANGE_M
		add_child(lamp)

	_build_shell()
	_build_pipes_and_vents()
	_build_signage()
	MoonLook.add_service_tunnel_mouth_detail(self, LADDER_AT, WALL_HEIGHT_M)
	ladder_click = _build_ladder()
	ladder_click.clicked.connect(_on_ladder)
	_build_strays(GameClock.get_day_index())


func _build_shell() -> void:
	# Collision: only the tunnel's own floor and 4 enclosing walls (layer 1).
	_add_collider("TunnelFloor", Vector3(0.0, -0.5, 0.0), Vector3(HALF_LENGTH_M * 2.0 + 2.0, 1.0, HALF_WIDTH_M * 2.0 + 1.6))
	_add_collider("WallNorth", Vector3(0.0, WALL_HEIGHT_M * 0.5, -HALF_WIDTH_M - 0.4), Vector3(HALF_LENGTH_M * 2.0 + 1.0, WALL_HEIGHT_M, 0.8))
	_add_collider("WallSouth", Vector3(0.0, WALL_HEIGHT_M * 0.5, HALF_WIDTH_M + 0.4), Vector3(HALF_LENGTH_M * 2.0 + 1.0, WALL_HEIGHT_M, 0.8))
	_add_collider("WallWest", Vector3(-HALF_LENGTH_M - 0.4, WALL_HEIGHT_M * 0.5, 0.0), Vector3(0.8, WALL_HEIGHT_M, HALF_WIDTH_M * 2.0 + 1.2))
	_add_collider("WallEast", Vector3(HALF_LENGTH_M + 0.4, WALL_HEIGHT_M * 0.5, 0.0), Vector3(0.8, WALL_HEIGHT_M, HALF_WIDTH_M * 2.0 + 1.2))

	var shell := Node3D.new()
	shell.name = "TunnelShell"
	add_child(shell)
	var dark_mat: Material = TunnelLook.flat_mat(TunnelLook.BASALT_DARK)
	var wall_mat: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_WALL)
	var grate_mat: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_GRATE)
	var steel_mat: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_PIPE_STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(MoonLook.PAD_STRIPE)

	# Sub-floor + central grating walkway & cross slats [PLACEHOLDER].
	shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(HALF_LENGTH_M * 2.0, 0.10, HALF_WIDTH_M * 2.0)), Vector3(0.0, -0.05, 0.0), dark_mat))
	shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(HALF_LENGTH_M * 2.0 - 0.8, 0.04, 3.6)), Vector3(0.0, 0.02, 0.0), grate_mat))
	for i: int in 14:
		var x: float = -13.0 + float(i) * 2.0
		shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.05, 3.7)), Vector3(x, 0.025, 0.0), steel_mat))

	# North, West, East full walls; South wall low cutaway curb for clear isometric view.
	shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(HALF_LENGTH_M * 2.0, WALL_HEIGHT_M, 0.30)), Vector3(0.0, WALL_HEIGHT_M * 0.5, -HALF_WIDTH_M - 0.15), wall_mat))
	shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.30, WALL_HEIGHT_M, HALF_WIDTH_M * 2.0)), Vector3(-HALF_LENGTH_M - 0.15, WALL_HEIGHT_M * 0.5, 0.0), wall_mat))
	shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.30, WALL_HEIGHT_M, HALF_WIDTH_M * 2.0)), Vector3(HALF_LENGTH_M + 0.15, WALL_HEIGHT_M * 0.5, 0.0), wall_mat))
	shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(HALF_LENGTH_M * 2.0, 0.55, 0.28)), Vector3(0.0, 0.275, HALF_WIDTH_M + 0.14), wall_mat))

	# Structural steel ribs along the north wall with brass brackets.
	for x: float in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.28, WALL_HEIGHT_M, 0.36)), Vector3(x, WALL_HEIGHT_M * 0.5, -HALF_WIDTH_M + 0.05), steel_mat))
		shell.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.34, 0.18, 0.42)), Vector3(x, WALL_HEIGHT_M - 0.35, -HALF_WIDTH_M + 0.08), brass_mat))


func _build_pipes_and_vents() -> void:
	var fixtures := Node3D.new()
	fixtures.name = "PipesAndVents"
	add_child(fixtures)
	var warm_pipe: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_PIPE_WARM)
	var steel_pipe: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_PIPE_STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(MoonLook.PAD_STRIPE)
	var dark_mat: Material = TunnelLook.flat_mat(MoonLook.DARK_METAL)
	var vent_glow: Material = TunnelLook.glow_mat(MoonLook.TUNNEL_VENT_GLOW, 0.9)

	# Overhead & mid-wall insulated conduit pipes along the north bulkhead [PLACEHOLDER].
	fixtures.add_child(TunnelLook.part(TunnelLook.cylinder(0.18, HALF_LENGTH_M * 2.0 - 0.6), Vector3(0.0, 2.55, -HALF_WIDTH_M + 0.32), warm_pipe, Vector3(0.0, 0.0, 90.0)))
	fixtures.add_child(TunnelLook.part(TunnelLook.cylinder(0.13, HALF_LENGTH_M * 2.0 - 0.6), Vector3(0.0, 2.10, -HALF_WIDTH_M + 0.28), steel_pipe, Vector3(0.0, 0.0, 90.0)))
	for x: float in [-10.0, -4.0, 2.0, 8.0]:
		fixtures.add_child(TunnelLook.part(TunnelLook.cylinder(0.23, 0.14), Vector3(x, 2.55, -HALF_WIDTH_M + 0.32), brass_mat, Vector3(0.0, 0.0, 90.0)))

	# Four warm glowing thermal vents along the north bulkhead.
	for vx: float in [-7.6, -2.2, 3.0, 8.4]:
		fixtures.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.5, 0.9, 0.14)), Vector3(vx, 0.72, -HALF_WIDTH_M + 0.06), dark_mat))
		fixtures.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.22, 0.62, 0.08)), Vector3(vx, 0.72, -HALF_WIDTH_M + 0.11), vent_glow))
		for sy: float in [0.54, 0.72, 0.90]:
			fixtures.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.36, 0.06, 0.06)), Vector3(vx, sy, -HALF_WIDTH_M + 0.16), steel_pipe))


func _build_signage() -> void:
	var sign_root := Node3D.new()
	sign_root.name = "StationSign"
	sign_root.position = Vector3(0.0, 1.85, -HALF_WIDTH_M + 0.08)
	add_child(sign_root)
	sign_root.add_child(TunnelLook.part(TunnelLook.box(Vector3(3.8, 0.62, 0.08)), Vector3.ZERO, TunnelLook.flat_mat(MoonLook.DARK_METAL)))
	sign_root.add_child(TunnelLook.part(TunnelLook.box(Vector3(3.88, 0.08, 0.10)), Vector3(0.0, 0.32, 0.0), TunnelLook.flat_mat(MoonLook.PAD_STRIPE)))
	var lbl := Label3D.new()
	lbl.text = SIGN_TEXT
	lbl.pixel_size = 0.008
	lbl.font_size = 28
	lbl.modulate = MoonLook.CREAM
	lbl.position = Vector3(0.0, 0.0, 0.07)
	sign_root.add_child(lbl)


func _build_ladder() -> Clickable:
	var root := Node3D.new()
	root.name = "LadderProp"
	root.position = LADDER_AT
	add_child(root)
	var steel_mat: Material = TunnelLook.flat_mat(MoonLook.STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(MoonLook.PAD_STRIPE)
	var dark_mat: Material = TunnelLook.flat_mat(MoonLook.DARK_METAL)

	# Hatch pad + twin steel rails + brass rungs + ceiling collar.
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.5, 0.08, 1.2)), Vector3(0.0, 0.04, 0.35), dark_mat))
	for sx: float in [-0.36, 0.36]:
		root.add_child(TunnelLook.part(TunnelLook.cylinder(0.045, WALL_HEIGHT_M), Vector3(sx, WALL_HEIGHT_M * 0.5, 0.0), steel_mat))
	for i: int in 8:
		var ry: float = 0.38 + float(i) * 0.42
		root.add_child(TunnelLook.part(TunnelLook.cylinder(0.03, 0.72), Vector3(0.0, ry, 0.0), brass_mat, Vector3(0.0, 0.0, 90.0)))
	root.add_child(TunnelLook.label("UP TO HUB", Vector3(0.0, 2.3, 0.4), MoonLook.SCREEN_GLOW))

	var click := Clickable.new()
	click.name = "Ladder"
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = LADDER_HINT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 3.0, 1.2)
	shape.shape = box
	click.add_child(shape)
	click.position = LADDER_AT + Vector3(0.0, 1.5, 0.25)
	add_child(click)
	return click


func _build_strays(day: int) -> void:
	var group := Node3D.new()
	group.name = "Strays"
	add_child(group)
	var indices: Array[int] = stray_indices_for_day(day)
	for i: int in indices.size():
		var spot: Vector3 = STRAY_SPOTS[indices[i]]
		var yaw: float = float(MoonLook.hash_int(day, indices[i], STRAY_HASH_SALT + 50) % 360)
		var spider: Node3D = RareSpiderLook.build(RareSpiderLook.BANDED_ID)
		spider.name = "Stray_%d" % i
		spider.position = spot
		spider.scale = Vector3.ONE * STRAY_SCALE
		spider.rotation_degrees.y = yaw
		spider.set_meta(&"base_yaw", yaw)
		group.add_child(spider)
		stray_nodes.append(spider)
		stray_indices.append(indices[i])

		var click := Clickable.new()
		click.name = "StrayClick_%d" % i
		click.collision_layer = 8
		click.collision_mask = 0
		click.hint = STRAY_HINT % GameState.STATION_LINE
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 0.7, 0.9)
		shape.shape = box
		click.add_child(shape)
		click.position = spot + Vector3(0.0, 0.3, 0.0)
		click.clicked.connect(_on_stray_clicked.bind(spot, indices[i], day))
		group.add_child(click)
		stray_clicks.append(click)
	GameState.strays_changed.connect(_show_strays)
	_show_strays()


func _add_collider(body_name: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child(body)


func _build_walker() -> void:
	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	camera.ortho_size_m = 16.0
	add_child(camera)
	walker = PhobosWalker.new()
	walker.name = "Walker"
	walker.camera = camera
	add_child(walker)
	walker.position = ARRIVE_AT
	_dress_walker()
	GameState.loadouts_changed.connect(_dress_walker)
	camera.target = walker
	camera.current = true


func _dress_walker() -> void:
	if walker == null or walker.model == null:
		return
	walker.model.set_suit(WalkerModel.suit_for(GameState.local_player_id, CoopSession.players))
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


# --- Use ------------------------------------------------------------------------

func _near(at: Vector3) -> bool:
	if Vector2(walker.global_position.x - at.x, walker.global_position.z - at.z).length() <= REACH_M:
		return true
	_toast(TOO_FAR_TEXT)
	return false


func _on_ladder() -> void:
	if _leaving or not _near(LADDER_AT):
		return
	_leaving = true
	PhobosHub.arrive_at_hatch = true
	_swap_to(SceneSwitcher.PHOBOS_SCENE)


func _on_stray_clicked(at: Vector3, stray_index: int, layout_day: int) -> void:
	if not _near(at) or _catching:
		return
	# The host decides (a guest's click only asks); this screen changes when it says so.
	_catching = true
	var had_runner: bool = GameState.is_caught(GameState.RUNNER)
	var problem: Variant = await FarmCommands.request(&"catch_stray", [stray_index, layout_day])
	_catching = false
	if not is_inside_tree():
		return
	if str(problem) != "":
		_toast(str(problem))
	elif had_runner:
		_toast(STRAY_LET_GO_TEXT)
	else:
		_toast(STRAY_CAUGHT_TEXT % GameState.STATION_LINE)


## A stray caught today is gone from this screen, whoever caught it.
func _show_strays() -> void:
	var caught: Array[int] = GameState.strays_caught_today()
	for i: int in stray_nodes.size():
		var gone: bool = stray_indices[i] in caught
		stray_nodes[i].visible = not gone
		stray_clicks[i].visible = not gone
		stray_clicks[i].enabled = not gone  # also clears its hover hint
		stray_clicks[i].collision_layer = 0 if gone else 8


func _toast(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_toast_left = maxf(TOAST_SECONDS, text.length() * 0.04)
