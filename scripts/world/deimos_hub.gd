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

var cache_click: Inspectable
var pod_click: Inspectable


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
	env.background_color = ScopeTheme.GLASS_DEEP.darkened(0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ScopeTheme.INK_MUTED
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
	# The deck: one flat slab, pale blue-grey, with tan dust drifted in patches.
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
	add_child(_part("DeckPlate", Vector3(0.0, -0.05, 0.0), Vector3(72.0, 0.1, 72.0), ScopeTheme.INK_DIM.lightened(0.1)))
	for dust: Vector3 in [Vector3(-12.0, 0.0, -14.0), Vector3(14.0, 0.0, 10.0), Vector3(-20.0, 0.0, 16.0), Vector3(2.0, 0.0, -24.0), Vector3(22.0, 0.0, -18.0)]:
		add_child(_drum("Dust", Vector3(dust.x, 0.03, dust.z), 5.0, 0.04, ScopeTheme.ENAMEL_LIP.darkened(0.35), 14))
	# A hex lander pad where the shuttle sits, with an amber edge strip.
	add_child(_drum("Pad", Vector3(-14.0, 0.05, 1.0), 8.0, 0.1, ScopeTheme.SHADOW, 6))
	add_child(_drum("PadRim", Vector3(-14.0, 0.02, 1.0), 8.6, 0.06, ScopeTheme.AMBER.darkened(0.3), 6))
	# Mars: a flat-shaded sphere on the horizon, behind the outpost.
	var mars := MeshInstance3D.new()
	mars.name = "Mars"
	var ball := SphereMesh.new()
	ball.radius = 40.0
	ball.height = 80.0
	ball.radial_segments = 24
	ball.rings = 12
	mars.mesh = ball
	var red := _flat(ScopeTheme.TERRA)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mars.material_override = red
	mars.position = Vector3(60.0, 14.0, -95.0)
	add_child(mars)
	# The parked shuttle: boxes, paler than at Phobos.
	add_child(_part("ShuttleBody", Vector3(-14.0, 1.6, 1.0), Vector3(9.0, 3.2, 3.6), ScopeTheme.ENAMEL_TOP, true))
	add_child(_part("ShuttleCockpit", Vector3(-19.2, 1.9, 1.0), Vector3(2.0, 2.0, 2.6), ScopeTheme.TEAL.darkened(0.55), true))
	add_child(_part("ShuttleWingA", Vector3(-13.0, 0.5, -2.6), Vector3(4.0, 0.3, 3.0), ScopeTheme.ENAMEL_INSET, true))
	add_child(_part("ShuttleWingB", Vector3(-13.0, 0.5, 4.6), Vector3(4.0, 0.3, 3.0), ScopeTheme.ENAMEL_INSET, true))
	# The outpost hab: a small cream drum with a terracotta skirt, a door and a dish.
	var hab := Vector3(4.0, 0.0, -15.0)
	add_child(_drum("HabSkirt", hab + Vector3(0.0, 0.7, 0.0), 4.6, 1.4, ScopeTheme.TERRA, 12, true))
	add_child(_drum("HabBody", hab + Vector3(0.0, 2.4, 0.0), 4.4, 2.0, ScopeTheme.ENAMEL, 12, true))
	add_child(_drum("HabRoof", hab + Vector3(0.0, 3.6, 0.0), 3.2, 0.5, ScopeTheme.ENAMEL_TOP, 12))
	add_child(_part("HabDish", hab + Vector3(0.0, 4.3, 0.0), Vector3(1.4, 0.2, 1.4), ScopeTheme.INK_MUTED))
	add_child(_part("HabDoor", hab + Vector3(-1.2, 1.3, 4.3), Vector3(1.0, 2.2, 0.2), ScopeTheme.INK_MUTED))
	add_child(_part("HabPortA", hab + Vector3(1.8, 2.5, 4.0), Vector3(0.8, 0.8, 0.2), ScopeTheme.TEAL.darkened(0.5)))
	console_click = _make_console()
	board_click = _make_board()
	board_click.hint = Shuttle.text("deimos_hint_board")
	cache_click = _make_cache()
	pod_click = _make_pod()
	console_click.clicked.connect(_on_console)
	board_click.clicked.connect(_on_board)
	cache_click.inspected.connect(_toast)
	pod_click.inspected.connect(_toast)


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
func _make_cache() -> Inspectable:
	var at: Vector3 = DEIMOS_SPOTS["Cache"]
	var ochre: Color = ScopeTheme.AMBER.darkened(0.4)
	add_child(_part("CacheSwept", at + Vector3(0.0, 0.02, 0.0), Vector3(4.0, 0.04, 3.0), ScopeTheme.INK_DIM.lightened(0.25)))
	add_child(_part("CrateA", at + Vector3(-0.7, 0.5, 0.0), Vector3(1.2, 1.0, 1.0), ochre, true))
	add_child(_part("CrateB", at + Vector3(0.7, 0.45, 0.2), Vector3(1.0, 0.9, 1.0), ochre.darkened(0.15), true))
	add_child(_part("CrateC", at + Vector3(0.0, 1.4, 0.0), Vector3(1.1, 0.8, 0.9), ochre.lightened(0.1)))
	add_child(_part("CachePadlock", at + Vector3(-0.7, 0.7, 0.55), Vector3(0.22, 0.28, 0.1), ScopeTheme.TEAL))
	var click: Inspectable = get_node("CacheSign") as Inspectable
	_clickable(click, at + Vector3(0.0, 0.9, 0.0), Vector3(3.2, 2.0, 2.4), "")
	return click


## The test pod: a pale capsule box with a fogged window, a warm glow at its foot.
func _make_pod() -> Inspectable:
	var at: Vector3 = DEIMOS_SPOTS["Pod"]
	add_child(_part("PodShell", at + Vector3(0.0, 0.8, 0.0), Vector3(1.6, 1.6, 2.6), ScopeTheme.ENAMEL_TOP, true))
	add_child(_part("PodGlass", at + Vector3(0.0, 1.0, 1.33), Vector3(1.0, 0.7, 0.08), ScopeTheme.INK_MUTED.lightened(0.3)))
	add_child(_part("PodWarmth", at + Vector3(0.0, 0.1, 1.5), Vector3(1.2, 0.1, 0.5), ScopeTheme.AMBER))
	var click: Inspectable = get_node("PodSign") as Inspectable
	_clickable(click, at + Vector3(0.0, 0.9, 0.5), Vector3(2.4, 1.8, 3.4), "")
	return click
