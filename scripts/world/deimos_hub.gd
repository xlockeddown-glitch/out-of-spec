class_name DeimosHub
extends PhobosHub
## The Deimos hub (docs/design/zones.md section 13, step 17, second half): quiet, tidy
## and a little odd, a place hidden on purpose. A smoother, paler, dustier deck than
## Phobos under a black sky with Mars, the parked shuttle, a small cream outpost hab, the
## return-shuttle console, the notice board, one locked smuggler cache and the terraform
## test pod. Kestrel's trade is the cache's story. Walking only, no low gravity yet; every
## shape, colour and line is a [PLACEHOLDER], boxes and drums only, no art files.
##
## The cache and the pod are signs to inspect, nothing more: no crate opens, there is no
## new species, find or quest (later PRs). Booking, the way home, the trip's end and the
## guest following the host are all PhobosHub's, here with `_moon()` as Deimos. The board
## says whether the shuttle window is up, which is the reason a booking can be refused.

## The moon this hub is.
const DEIMOS: String = Shuttle.DEIMOS

## Where the parts stand: name -> position. The console and board keep Phobos' places.
const DEIMOS_SPOTS: Dictionary[String, Vector3] = {
	"Console": Vector3(-6.0, 0.0, 3.0),
	"Board": Vector3(-3.0, 0.0, -8.6),
	"Cache": Vector3(10.0, 0.0, -8.0),
	"Pod": Vector3(16.0, 0.0, -2.5),
}

const CACHE_OPENED_TEXT: String = "The crate is open. Something warm inside."

var cache_click: Inspectable
var pod_click: Inspectable
## The expedition camp's click target (zones step 18): no collision body, layer 8 only.
var camp_click: Clickable
var _cache_padlock: Node3D
var _cache_trim_lock: Node3D
var _cache_lid_shut: Node3D
var _cache_open_group: Node3D
var _cache_day: int = -1


func _moon() -> String:
	return DEIMOS


func _title() -> String:
	return Shuttle.text("deimos_hub_title")


func _spots() -> Dictionary[String, Vector3]:
	return DEIMOS_SPOTS


## The painted board: the short notice only (the window line would go stale on a panel).
func _board_painted() -> String:
	return Shuttle.text("deimos_board_notice")


## The notice, then the shuttle window as it stands now, read fresh each time the board
## is clicked: a shut window is said here.
func _board_text() -> String:
	return "%s %s" % [Shuttle.text("deimos_board_notice"),
		Shuttle.text("deimos_board_window") % Shuttle.window_line(DEIMOS, GameClock.elapsed_days)]


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = MoonLook.DEIMOS_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = MoonLook.DEIMOS_AMBIENT
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.name = "Sky"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, -25.0, 0.0)
	sun.light_energy = 1.0
	add_child(sun)
	# The deck: one flat slab, smoother pale blue-grey, with tan dust drifts and subtle craters.
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
	add_child(_part("DeckPlate", Vector3(0.0, -0.05, 0.0), Vector3(72.0, 0.1, 72.0), MoonLook.DEIMOS_DECK))
	var dust_spots: Array[Vector3] = [Vector3(-12.0, 0.0, -14.0), Vector3(14.0, 0.0, 10.0), Vector3(-20.0, 0.0, 16.0), Vector3(2.0, 0.0, -24.0), Vector3(22.0, 0.0, -18.0)]
	for i: int in dust_spots.size():
		var dust: Vector3 = dust_spots[i]
		add_child(_drum("Dust", Vector3(dust.x, 0.03, dust.z), 5.0, 0.04, MoonLook.DEIMOS_DUST if i % 2 == 0 else MoonLook.DEIMOS_DUST_LIGHT, 14))
	MoonLook.add_crater(self, Vector3(18.0, 0.0, 14.0), 3.4, MoonLook.DEIMOS_CRATER, MoonLook.DEIMOS_RIM, 201)
	MoonLook.add_crater(self, Vector3(-24.0, 0.0, -18.0), 3.8, MoonLook.DEIMOS_CRATER, MoonLook.DEIMOS_RIM, 202)
	MoonLook.add_outer_rocks(self, 202, MoonLook.DEIMOS_BOULDER, MoonLook.DEIMOS_RIM, true)
	# A hex lander pad where the shuttle sits, with amber markings and approach beacons.
	MoonLook.add_lander_pad(self, Vector3(-14.0, 0.0, 1.0), true)
	MoonLook.add_pad_edge_lights(self, Vector3(-14.0, 0.0, 1.0), true)
	# Mars: a flat-shaded sphere on the horizon, behind the outpost, with sky stars and faint horizon glow.
	MoonLook.add_starfield(self, MoonLook.STAR_SEED_DEIMOS, MoonLook.STAR_COUNT_DEIMOS)
	MoonLook.add_mars_horizon_glow(self, Vector3(60.0, 14.0, -95.0), 40.0, MoonLook.MARS_GLOW_DEIMOS, MoonLook.MARS_GLOW_ALPHA_DEIMOS)
	MoonLook.add_mars(self, Vector3(60.0, 14.0, -95.0), 40.0, MoonLook.DEIMOS_MARS)
	# The parked shuttle: solid collision boxes, paler than at Phobos, plus visual details.
	add_child(_part("ShuttleBody", Vector3(-14.0, 1.6, 1.0), Vector3(9.0, 3.2, 3.6), MoonLook.DEIMOS_HULL, true))
	add_child(_part("ShuttleCockpit", Vector3(-19.2, 1.9, 1.0), Vector3(2.0, 2.0, 2.6), MoonLook.COCKPIT_GLASS, true))
	add_child(_part("ShuttleWingA", Vector3(-13.0, 0.5, -2.6), Vector3(4.0, 0.3, 3.0), MoonLook.DEIMOS_WING, true))
	add_child(_part("ShuttleWingB", Vector3(-13.0, 0.5, 4.6), Vector3(4.0, 0.3, 3.0), MoonLook.DEIMOS_WING, true))
	MoonLook.add_shuttle_detail(self, MoonLook.DEIMOS_HULL, MoonLook.DEIMOS_WING)
	# The outpost hab: a small cream drum with a terracotta skirt, structural ribs, a door and a dish.
	var hab := Vector3(4.0, 0.0, -15.0)
	add_child(_drum("HabSkirt", hab + Vector3(0.0, 0.7, 0.0), 4.6, 1.4, MoonLook.DEIMOS_HAB_SKIRT, 12, true))
	add_child(_drum("HabBody", hab + Vector3(0.0, 2.4, 0.0), 4.4, 2.0, MoonLook.DEIMOS_HAB_BODY, 12, true))
	add_child(_drum("HabRoof", hab + Vector3(0.0, 3.6, 0.0), 3.2, 0.5, MoonLook.DEIMOS_HAB_ROOF, 12))
	add_child(_part("HabDish", hab + Vector3(0.0, 4.3, 0.0), Vector3(1.4, 0.2, 1.4), MoonLook.DEIMOS_AMBIENT))
	add_child(_part("HabDoor", hab + Vector3(-1.2, 1.3, 4.3), Vector3(1.0, 2.2, 0.2), MoonLook.DEIMOS_AMBIENT))
	add_child(_part("HabPortA", hab + Vector3(1.8, 2.5, 4.0), Vector3(0.8, 0.8, 0.2), MoonLook.COCKPIT_GLASS))
	MoonLook.add_deimos_hab_detail(self, hab)
	MoonLook.add_utility_props(self, true)
	var camp_at: Vector3 = Camp.position(DEIMOS)
	var clear_spots: Array[Vector3] = [ARRIVE_AT, camp_at, camp_at + Vector3(-1.8, 0.0, -1.6), camp_at + Vector3(1.8, 0.0, 1.6)]
	for spot: Vector3 in DEIMOS_SPOTS.values():
		clear_spots.append(spot)
	MoonLook.add_regolith_scatter(
		self,
		MoonLook.SCATTER_SEED_DEIMOS,
		MoonLook.SCATTER_DRIFTS_DEIMOS,
		MoonLook.SCATTER_ROCKS_DEIMOS,
		MoonLook.DRIFT_DEIMOS,
		MoonLook.DRIFT_DEIMOS_LIGHT,
		MoonLook.DEIMOS_BOULDER,
		MoonLook.DEIMOS_RIM,
		clear_spots,
		true
	)
	MoonLook.add_deimos_camp_dressing(self, camp_at)
	console_click = _make_console()
	board_click = _make_board()
	board_click.hint = Shuttle.text("deimos_hint_board")
	cache_click = _make_cache()
	pod_click = _make_pod()
	console_click.clicked.connect(_on_console)
	board_click.clicked.connect(_on_board)
	cache_click.clicked.connect(_on_cache)
	pod_click.inspected.connect(_toast)
	GameState.deimos_cache_changed.connect(_refresh_cache)
	_refresh_cache()
	# The expedition camp (Camp.MOON_SPOTS): the camp props show once a quest opens it.
	add_child(CampProps.new(DEIMOS))
	camp_click = _clickable(Clickable.new(), Camp.position(DEIMOS) + Vector3(0.0, 0.6, 0.0), Vector3(4.0, 1.4, 3.0), "")
	camp_click.name = "CampClick"
	camp_click.clicked.connect(_on_camp)
	GameState.camps_changed.connect(_refresh_camp_hint)
	_refresh_camp_hint()


## Whether the local player was in bed when the hint was last worded.
var _hint_asleep: bool = false


## The hint is worded again when the camp opens or shuts (camps_changed) and when the local
## player's bed changes (watched here, as CoopBeds has no signal for it): no data lookup
## on the frames between.
func _process(delta: float) -> void:
	if CoopBeds.in_bed.has(GameState.local_player_id) != _hint_asleep:
		_refresh_camp_hint()
	if GameClock.get_day_index() != _cache_day:
		_refresh_cache()
	super(delta)


## The camp's hover hint: said only once the camp is open (while it is shut the spot is
## bare floor), and "get up" while the local player is in bed.
func _refresh_camp_hint() -> void:
	if camp_click == null:
		return
	_hint_asleep = CoopBeds.in_bed.has(GameState.local_player_id)
	if not GameState.camps_open.has(DEIMOS):
		camp_click.hint = Shuttle.text("camp_shut_hint")
	else:
		camp_click.hint = Shuttle.text("camp_hint_up" if _hint_asleep else "camp_hint")


## A click on the camp: turn in for the night, or get up. The host cannot know where a
## moon walker stands, so the walker's reach is checked here, as the console's is. The
## host decides the rest (an expedition, an open camp, a night's supplies).
func _on_camp() -> void:
	if _busy or not GameState.camps_open.has(DEIMOS):
		return
	if not Camp.near(DEIMOS, walker.global_position):
		_toast(Shuttle.text("camp_far_text"))
		return
	var asleep: bool = CoopBeds.in_bed.has(GameState.local_player_id)
	_busy = true
	var problem: String = await FarmCommands.request(&"get_up" if asleep else &"go_to_bed", [])
	_busy = false
	if is_inside_tree():
		_toast(problem if problem != "" else Shuttle.text("camp_up_text" if asleep else "camp_in_text"))


## A cylinder drum of `radius` and `height` (`sides` round; solid stops the walker).
func _drum(part_name: String, at: Vector3, radius: float, height: float, colour: Color, sides: int, solid: bool = false) -> Node3D:
	var drum := MeshInstance3D.new()
	drum.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	drum.mesh = mesh
	drum.material_override = _flat(colour)
	drum.position = at
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var hull := CylinderShape3D.new()
		hull.radius = radius
		hull.height = height
		shape.shape = hull
		body.add_child(shape)
		drum.add_child(body)
	return drum


## The cache: ochre crates in a tidy stack with a small padlock, on a swept square.
## Has a shut look (padlock + flush lid) and an opened look (propped lid, warm liner,
## unlatched padlock on the deck); zero extra colliders, palette constants only.
func _make_cache() -> Inspectable:
	var at: Vector3 = DEIMOS_SPOTS["Cache"]
	var ochre: Color = MoonLook.DEIMOS_CACHE
	add_child(_part("CacheSwept", at + Vector3(0.0, 0.02, 0.0), Vector3(4.0, 0.04, 3.0), MoonLook.DEIMOS_DUST_LIGHT))
	add_child(_part("CrateA", at + Vector3(-0.7, 0.5, 0.0), Vector3(1.2, 1.0, 1.0), ochre, true))
	add_child(_part("CrateB", at + Vector3(0.7, 0.45, 0.2), Vector3(1.0, 0.9, 1.0), ochre.darkened(0.15), true))
	add_child(_part("CrateC", at + Vector3(0.65, 0.4, -0.85), Vector3(1.1, 0.8, 0.9), ochre.lightened(0.1)))
	_cache_padlock = _part("CachePadlock", at + Vector3(-0.7, 0.7, 0.55), Vector3(0.22, 0.28, 0.1), MoonLook.SCREEN_GLOW)
	add_child(_cache_padlock)
	_cache_lid_shut = _part("CacheLidShut", at + Vector3(-0.7, 1.04, 0.0), Vector3(1.26, 0.08, 1.06), ochre.lightened(0.1))
	add_child(_cache_lid_shut)
	_cache_open_group = Node3D.new()
	_cache_open_group.name = "CacheOpened"
	var lid_open: Node3D = _part("CacheLidOpen", at + Vector3(-0.7, 1.48, -0.82), Vector3(1.26, 0.08, 1.06), ochre.lightened(0.1))
	lid_open.rotation_degrees = Vector3(58.0, 0.0, 0.0)
	_cache_open_group.add_child(lid_open)
	_cache_open_group.add_child(_part("CacheWarmLiner", at + Vector3(-0.7, 0.98, 0.0), Vector3(1.06, 0.08, 0.86), MoonLook.WINDOW_GLOW))
	_cache_open_group.add_child(_part("CacheLatchOpen", at + Vector3(-0.9, 0.09, 0.85), Vector3(0.22, 0.1, 0.28), MoonLook.DARK_METAL))
	_cache_open_group.visible = false
	add_child(_cache_open_group)
	var trim: Node3D = MoonLook.add_cache_detail(self, at)
	for child: Node in trim.get_children():
		var part: Node3D = child as Node3D
		if part == null:
			continue
		if part.position.y > 1.5:
			part.position = Vector3(0.65, 0.72, -0.85)
		elif part.position.z > 0.4:
			_cache_trim_lock = part
	var click: Inspectable = get_node("CacheSign") as Inspectable
	_clickable(click, at + Vector3(0.0, 0.9, 0.0), Vector3(3.2, 2.0, 2.4), "")
	return click


## Updates the cache's shut/opened look and hover hint for today's state and label.
func _refresh_cache() -> void:
	var day: int = GameClock.get_day_index()
	_cache_day = day
	var opened: bool = GameState.deimos_cache_opened_today()
	if _cache_padlock != null:
		_cache_padlock.visible = not opened
	if _cache_trim_lock != null:
		_cache_trim_lock.visible = not opened
	if _cache_lid_shut != null:
		_cache_lid_shut.visible = not opened
	if _cache_open_group != null:
		_cache_open_group.visible = opened
	if cache_click == null:
		return
	var mislabeled: bool = GameState.is_deimos_cache_mislabeled(day)
	if opened:
		cache_click.hint = "Smuggler Cache (wrong label, opened today)" if mislabeled else "Smuggler Cache (opened today)"
	elif mislabeled:
		cache_click.hint = "Smuggler Cache — label says 'DRILL SPARES' (wrong label)"
	else:
		cache_click.hint = "Smuggler Cache"


## Clicking the smuggler cache asks the host to open it (open_cache). On a wrong-label
## day the refusal or notice notes the mislabeled stencil; opening still works.
func _on_cache() -> void:
	if _busy or not _near("Cache"):
		return
	var mislabeled: bool = GameState.is_deimos_cache_mislabeled()
	_busy = true
	var reply: String = await FarmCommands.request(&"open_cache", [])
	_busy = false
	if not is_inside_tree():
		return
	_refresh_cache()
	if reply != "":
		_toast(("Wrong label (marked 'DRILL SPARES'). " + reply) if mislabeled else reply)
	elif GameState.deimos_cache_opened_today():
		_toast(CACHE_OPENED_TEXT)


## The test pod: a pale capsule box with a fogged window, a warm glow at its foot.
func _make_pod() -> Inspectable:
	var at: Vector3 = DEIMOS_SPOTS["Pod"]
	add_child(_part("PodShell", at + Vector3(0.0, 0.8, 0.0), Vector3(1.6, 1.6, 2.6), MoonLook.CREAM, true))
	add_child(_part("PodGlass", at + Vector3(0.0, 1.0, 1.33), Vector3(1.0, 0.7, 0.08), MoonLook.POD_GLASS))
	add_child(_part("PodWarmth", at + Vector3(0.0, 0.1, 1.5), Vector3(1.2, 0.1, 0.5), MoonLook.WINDOW_GLOW))
	MoonLook.add_pod_detail(self, at)
	var click: Inspectable = get_node("PodSign") as Inspectable
	_clickable(click, at + Vector3(0.0, 0.9, 0.5), Vector3(2.4, 1.8, 3.4), "")
	return click
