class_name PhobosDeep
extends Node3D
## Phobos depth 1 ("Station deck 1", docs/design/zones.md section 13, slice 23):
## a small grid of rooms under the Phobos service tunnel, built from boxes (no art
## files, palette constants only), laid out from PhobosDepth.layout(world_seed, day),
## reseeded at 06:00. On foot with PhobosWalker and low gravity.
##
## Dust hazard: each trip down clogs optics (-25 % find pay) until the player uses
## the wipe stop in the room by the hatch. Leaving up the hatch is never blocked.

const SCENE_PATH: String = "res://scenes/phobos_deep.tscn"
const GRACE_S: float = PhobosHub.GRACE_S
const TOAST_SECONDS: float = PhobosHub.TOAST_SECONDS

var walker: PhobosWalker
var camera: IsoCamera
var hatch_up_click: Clickable
var wipe_click: Clickable
var find_clicks: Array[Clickable] = []
var find_nodes: Array[Node3D] = []
var find_ids: Array[String] = []
var find_kinds: Array[String] = []
var layout_data: Dictionary = {}
var dusty: bool = true

var _deck_root: Node3D
var _hint: Label
var _clock: Label
var _toast_left: float = 0.0
var _built_day: int = -1
var _seen_trip: bool = false
var _since_s: float = 0.0
var _leaving: bool = false
var _asking: bool = false
var _busy: bool = false
## Where scene swaps go; only tests set it (the real swap calls SceneSwitcher.go_to).
var change_scene: Callable = Callable()


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_build_environment()
	_build_deck(GameClock.get_day_index())
	_build_walker()
	_build_hud()
	GameState.shuttle_trips_changed.connect(_on_trips_changed)
	GameState.phobos_finds_changed.connect(_show_finds)
	GameState.loadouts_changed.connect(_dress_walker)
	GameState.phone_message.connect(_toast)
	_seen_trip = _has_trip()
	dusty = true
	_toast(PhobosDepth.DUSTY_START_TEXT)
	if _seen_trip:
		_notify_enter_deep.call_deferred()


func _exit_tree() -> void:
	if GameState.shuttle_trips_changed.is_connected(_on_trips_changed):
		GameState.shuttle_trips_changed.disconnect(_on_trips_changed)
	if GameState.phobos_finds_changed.is_connected(_show_finds):
		GameState.phobos_finds_changed.disconnect(_show_finds)
	if GameState.loadouts_changed.is_connected(_dress_walker):
		GameState.loadouts_changed.disconnect(_dress_walker)
	if GameState.phone_message.is_connected(_toast):
		GameState.phone_message.disconnect(_toast)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"swap_scene"):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var day: int = GameClock.get_day_index()
	if day != _built_day:
		_build_deck(day)
		if walker != null:
			walker.position = PhobosDepth.cell_to_world(PhobosDepth.START_CELL)
	var dust_tag: String = "DUSTY" if dusty else "CLEAN"
	_clock.text = "%s   %s CR   %s   [%s]" % [GameClock.format_now(), SP811.integer(GameState.credits), PhobosDepth.TITLE_TEXT, dust_tag]
	if _toast_left > 0.0:
		_toast_left -= delta
	else:
		var hovered: Clickable = Clickable.hovered
		_hint.text = hovered.hint if hovered != null and hovered.hint != "" else PhobosDepth.AMBIENT_HINT + "  " + PhobosWalker.hint_text()
	if not _seen_trip and not _asking:
		_since_s += delta
		if _since_s > GRACE_S:
			_trip_not_seen()


func _notify_enter_deep() -> void:
	if not is_inside_tree():
		return
	await FarmCommands.request(&"enter_phobos_deep")


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

func _build_environment() -> void:
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

	# At most two OmniLight3D lamps on the deck [PLACEHOLDER].
	for i: int in 2:
		var lamp := OmniLight3D.new()
		lamp.name = "DeckLight_%d" % i
		lamp.position = Vector3(0.0, 3.0, 6.0 if i == 0 else -7.5)
		lamp.light_color = MoonLook.TUNNEL_WARM_LIGHT
		lamp.light_energy = MoonLook.TUNNEL_LIGHT_ENERGY
		lamp.omni_range = 24.0
		add_child(lamp)


func _build_deck(day: int) -> void:
	if _deck_root != null and is_instance_valid(_deck_root):
		_deck_root.get_parent().remove_child(_deck_root)
		_deck_root.free()
	find_clicks.clear()
	find_nodes.clear()
	find_ids.clear()
	find_kinds.clear()

	_built_day = day
	layout_data = PhobosDepth.layout(GameState.world_seed, day)
	var grid: PackedStringArray = layout_data["grid"]

	_deck_root = Node3D.new()
	_deck_root.name = "StationDeck1"
	add_child(_deck_root)

	# One flat floor collider covering the whole deck (layer 1).
	var floor_body := StaticBody3D.new()
	floor_body.name = "DeckFloor"
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(float(PhobosDepth.WIDTH) * PhobosDepth.CELL_M + 2.0, 1.0, float(PhobosDepth.HEIGHT) * PhobosDepth.CELL_M + 2.0)
	floor_shape.shape = floor_box
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	_deck_root.add_child(floor_body)

	var floor_mat: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_GRATE)
	var wall_mat: Material = TunnelLook.flat_mat(MoonLook.TUNNEL_WALL)
	var trim_mat: Material = TunnelLook.flat_mat(MoonLook.PHOBOS_STATION_TRIM)
	var cell_m: float = PhobosDepth.CELL_M
	var wall_h: float = PhobosDepth.WALL_HEIGHT_M

	for y: int in PhobosDepth.HEIGHT:
		var line: String = grid[y]
		for x: int in PhobosDepth.WIDTH:
			var cell := Vector2i(x, y)
			var at: Vector3 = PhobosDepth.cell_to_world(cell)
			if line[x] == ".":
				_deck_root.add_child(TunnelLook.part(TunnelLook.box(Vector3(cell_m, 0.10, cell_m)), at + Vector3(0.0, -0.05, 0.0), floor_mat))
			elif _touches_floor(grid, cell):
				# Bulkhead wall box with solid collider so the walker stays in the rooms.
				# South-most wall rows use lower cutaway height for clear isometric view.
				var h: float = 0.75 if y >= PhobosDepth.HEIGHT - 1 else wall_h
				var wall := TunnelLook.part(TunnelLook.box(Vector3(cell_m, h, cell_m)), at + Vector3(0.0, h * 0.5, 0.0), wall_mat)
				_deck_root.add_child(wall)
				if h >= wall_h:
					_deck_root.add_child(TunnelLook.part(TunnelLook.box(Vector3(cell_m + 0.04, 0.14, cell_m + 0.04)), at + Vector3(0.0, h - 0.12, 0.0), trim_mat))
				var body := StaticBody3D.new()
				body.collision_layer = 1
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(cell_m, wall_h, cell_m)
				shape.shape = box
				body.position = at + Vector3(0.0, wall_h * 0.5, 0.0)
				body.add_child(shape)
				_deck_root.add_child(body)

	hatch_up_click = _build_hatch_up(PhobosDepth.cell_to_world(PhobosDepth.HATCH_CELL))
	hatch_up_click.clicked.connect(_on_hatch_up)
	wipe_click = _build_wipe_stop(PhobosDepth.cell_to_world(PhobosDepth.WIPE_CELL))
	wipe_click.clicked.connect(_on_wipe_stop)
	_build_finds(day)


func _touches_floor(grid: PackedStringArray, cell: Vector2i) -> bool:
	for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = cell + side
		if n.y >= 0 and n.y < PhobosDepth.HEIGHT and n.x >= 0 and n.x < PhobosDepth.WIDTH and grid[n.y][n.x] == ".":
			return true
	return false


func _build_hatch_up(at: Vector3) -> Clickable:
	var root := Node3D.new()
	root.name = "HatchUpProp"
	root.position = at
	_deck_root.add_child(root)
	var rim_mat: Material = TunnelLook.flat_mat(MoonLook.HATCH_RIM)
	var dark_mat: Material = TunnelLook.flat_mat(MoonLook.DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(MoonLook.STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(MoonLook.PAD_STRIPE)
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.0, 0.10, 2.0)), Vector3(0.0, 0.05, 0.0), rim_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.5, 0.06, 1.5)), Vector3(0.0, 0.11, 0.0), dark_mat))
	for sx: float in [-0.34, 0.34]:
		root.add_child(TunnelLook.part(TunnelLook.cylinder(0.04, 2.8), Vector3(sx, 1.4, -0.5), steel_mat))
	for i: int in 6:
		root.add_child(TunnelLook.part(TunnelLook.cylinder(0.025, 0.68), Vector3(0.0, 0.35 + float(i) * 0.42, -0.5), brass_mat, Vector3(0.0, 0.0, 90.0)))
	root.add_child(TunnelLook.label("UP TO TUNNEL", Vector3(0.0, 2.2, 0.0), MoonLook.SCREEN_GLOW))

	var click := Clickable.new()
	click.name = "HatchUp"
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = PhobosDepth.HATCH_UP_HINT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.6, 2.2)
	shape.shape = box
	click.add_child(shape)
	click.position = at + Vector3(0.0, 1.2, 0.0)
	_deck_root.add_child(click)
	return click


func _build_wipe_stop(at: Vector3) -> Clickable:
	var root := Node3D.new()
	root.name = "WipeStopProp"
	root.position = at
	_deck_root.add_child(root)
	var base_mat: Material = TunnelLook.flat_mat(MoonLook.PHOBOS_STATION)
	var trim_mat: Material = TunnelLook.flat_mat(MoonLook.PAD_STRIPE)
	var glow_mat: Material = TunnelLook.glow_mat(MoonLook.SCREEN_GLOW, 0.85)
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.2, 1.1, 0.8)), Vector3(0.0, 0.55, 0.0), base_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.26, 0.10, 0.86)), Vector3(0.0, 1.12, 0.0), trim_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.7, 0.35, 0.08)), Vector3(0.0, 0.85, 0.42), glow_mat))
	root.add_child(TunnelLook.label("WIPE STOP", Vector3(0.0, 1.65, 0.0), MoonLook.SCREEN_GLOW))

	var click := Clickable.new()
	click.name = "WipeStop"
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = PhobosDepth.WIPE_HINT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 1.2)
	shape.shape = box
	click.add_child(shape)
	click.position = at + Vector3(0.0, 0.8, 0.0)
	_deck_root.add_child(click)
	return click


func _build_finds(day: int) -> void:
	var group := Node3D.new()
	group.name = "Finds"
	_deck_root.add_child(group)
	var data_mat: Material = TunnelLook.flat_mat(MoonLook.PHOBOS_STATION)
	var screen_mat: Material = TunnelLook.glow_mat(MoonLook.SCREEN_GLOW, 0.9)
	var crate_mat: Material = TunnelLook.flat_mat(MoonLook.CRATE_PHOBOS)
	var trim_mat: Material = TunnelLook.flat_mat(MoonLook.PAD_STRIPE)

	for find: Dictionary in layout_data.get("finds", []):
		var fid: String = str(find["id"])
		var kind: String = str(find["kind"])
		var at: Vector3 = PhobosDepth.cell_to_world(find["cell"])

		var prop := Node3D.new()
		prop.name = "Find_%s" % fid
		prop.position = at
		if kind == "station_data":
			prop.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.95, 0.85, 0.65)), Vector3(0.0, 0.425, 0.0), data_mat))
			prop.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.68, 0.34, 0.08)), Vector3(0.0, 0.62, 0.34), screen_mat))
		else:
			prop.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.95, 0.62, 0.85)), Vector3(0.0, 0.31, 0.0), crate_mat))
			prop.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.0, 0.10, 0.90)), Vector3(0.0, 0.64, 0.0), trim_mat))
		group.add_child(prop)

		var click := Clickable.new()
		click.name = "FindClick_%s" % fid
		click.collision_layer = 8
		click.collision_mask = 0
		click.hint = "Take %s" % str(PhobosDepth.NAMES.get(kind, kind))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 1.1, 1.2)
		shape.shape = box
		click.add_child(shape)
		click.position = at + Vector3(0.0, 0.55, 0.0)
		click.clicked.connect(_on_find_clicked.bind(at, fid, kind, day))
		group.add_child(click)

		find_nodes.append(prop)
		find_clicks.append(click)
		find_ids.append(fid)
		find_kinds.append(kind)
	_show_finds()


func _build_walker() -> void:
	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	camera.ortho_size_m = 20.0
	add_child(camera)
	walker = PhobosWalker.new()
	walker.name = "Walker"
	walker.moon = Shuttle.PHOBOS
	walker.camera = camera
	add_child(walker)
	walker.position = PhobosDepth.cell_to_world(PhobosDepth.START_CELL)
	_dress_walker()
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
	_hint.offset_top = -96.0
	_hint.offset_left = 16.0
	_hint.add_theme_font_size_override(&"font_size", 20)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_hint)


# --- Use ------------------------------------------------------------------------

func _near(at: Vector3) -> bool:
	if Vector2(walker.global_position.x - at.x, walker.global_position.z - at.z).length() <= PhobosDepth.REACH_M:
		return true
	_toast(PhobosDepth.TOO_FAR_TEXT)
	return false


## Leaving is never blocked by dust.
func _on_hatch_up() -> void:
	if _leaving or not _near(PhobosDepth.cell_to_world(PhobosDepth.HATCH_CELL)):
		return
	_leaving = true
	PhobosServiceTunnel.arrive_at_deep_hatch = true
	_swap_to(PhobosServiceTunnel.SCENE_PATH)


func _on_wipe_stop() -> void:
	if _busy or not _near(PhobosDepth.cell_to_world(PhobosDepth.WIPE_CELL)):
		return
	if not dusty:
		_toast(PhobosDepth.ALREADY_WIPED_TEXT)
		return
	_busy = true
	var problem: Variant = await FarmCommands.request(&"wipe_phobos_dust")
	_busy = false
	if not is_inside_tree():
		return
	if str(problem) != "":
		_toast(str(problem))
	else:
		dusty = false
		_toast(PhobosDepth.DUSTY_WIPED_TEXT)


func _on_find_clicked(at: Vector3, find_id: String, kind: String, layout_day: int) -> void:
	if _busy or not _near(at):
		return
	_busy = true
	var was_dusty: bool = dusty
	var problem: Variant = await FarmCommands.request(&"take_phobos_find", [find_id, layout_day])
	_busy = false
	if not is_inside_tree():
		return
	if str(problem) != "":
		_toast(str(problem))
	else:
		_toast(PhobosDepth.reward_text(kind, was_dusty))


func _show_finds() -> void:
	var taken: Array[String] = GameState.phobos_finds_taken_today()
	for i: int in find_nodes.size():
		var gone: bool = find_ids[i] in taken
		find_nodes[i].visible = not gone
		find_clicks[i].visible = not gone
		find_clicks[i].enabled = not gone
		find_clicks[i].collision_layer = 0 if gone else 8


func _toast(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_toast_left = maxf(TOAST_SECONDS, text.length() * 0.04)
