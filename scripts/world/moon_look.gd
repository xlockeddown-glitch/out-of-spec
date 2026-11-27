class_name MoonLook
extends RefCounted
## Shared colours, cached read-only materials, deterministic coordinate hash,
## and primitive-mesh builders for the Phobos and Deimos hubs (PhobosHub,
## DeimosHub), inspired by Ryan's Deimos outpost concept art. Reuses TunnelLook
## builders; static functions only; every colour, size, and hash choice is a
## [PLACEHOLDER].

## Phobos palette: dark grey, cratered, close to Mars [PLACEHOLDER].
const PHOBOS_SKY := Color(0.01, 0.01, 0.02)
const PHOBOS_AMBIENT: Color = ScopeTheme.INK_DIM
const PHOBOS_DECK := Color(0.20, 0.21, 0.23)
const PHOBOS_CRATER := Color(0.11, 0.12, 0.14)
const PHOBOS_RIM := Color(0.27, 0.28, 0.31)
const PHOBOS_BOULDER := Color(0.16, 0.17, 0.19)
const PHOBOS_HULL := Color(0.76, 0.78, 0.81)
const PHOBOS_WING := Color(0.56, 0.59, 0.64)
const PHOBOS_STATION := Color(0.48, 0.51, 0.56)
const PHOBOS_STATION_TRIM := Color(0.32, 0.35, 0.40)
const PHOBOS_MARS: Color = ScopeTheme.TERRA

## Deimos palette: smoother, paler, dustier, quieter [PLACEHOLDER].
const DEIMOS_SKY := Color(0.02, 0.025, 0.04)
const DEIMOS_AMBIENT: Color = ScopeTheme.INK_MUTED
const DEIMOS_DECK := Color(0.36, 0.39, 0.43)
const DEIMOS_DUST := Color(0.54, 0.49, 0.42)
const DEIMOS_DUST_LIGHT := Color(0.62, 0.57, 0.50)
const DEIMOS_CRATER := Color(0.26, 0.28, 0.32)
const DEIMOS_RIM := Color(0.44, 0.42, 0.40)
const DEIMOS_BOULDER: Color = ScopeTheme.GLASS_LINE
const DEIMOS_HULL: Color = ScopeTheme.ENAMEL_TOP
const DEIMOS_WING: Color = ScopeTheme.ENAMEL_INSET
const DEIMOS_HAB_SKIRT: Color = ScopeTheme.TERRA
const DEIMOS_HAB_BODY: Color = ScopeTheme.ENAMEL
const DEIMOS_HAB_ROOF: Color = ScopeTheme.ENAMEL_TOP
const DEIMOS_CACHE := Color(0.58, 0.40, 0.14)
const DEIMOS_MARS := Color(0.78, 0.42, 0.27)

## Shared structural & semantic accents [PLACEHOLDER].
const MARS_BAND: Color = ScopeTheme.TERRA_DARK
const MARS_POLAR: Color = ScopeTheme.ENAMEL_TOP
const PAD_SURFACE: Color = ScopeTheme.SHADOW
const PAD_STRIPE: Color = ScopeTheme.AMBER
const SCREEN_GLOW: Color = ScopeTheme.TEAL
const WINDOW_GLOW: Color = ScopeTheme.AMBER
const DARK_METAL: Color = ScopeTheme.SHADOW
const STEEL: Color = ScopeTheme.INK_DIM
const CREAM: Color = ScopeTheme.ENAMEL_TOP
const BOARD_WOOD: Color = ScopeTheme.CARD_INK_MUTED
const SKIN_PALE: Color = ScopeTheme.ENAMEL
const HATCH_RIM := Color(0.52, 0.42, 0.16)
const COCKPIT_GLASS := Color(0.16, 0.34, 0.38)
const POD_GLASS := Color(0.68, 0.75, 0.78)

## Subtle hub accent lights (at most 2 per hub) [PLACEHOLDER].
const SCONCE_ENERGY: float = 0.75
const SCONCE_RANGE_M: float = 7.5
const CONSOLE_LIGHT_ENERGY: float = 0.45
const CONSOLE_LIGHT_RANGE_M: float = 5.0

## Phobos warm service tunnel palette & lights [PLACEHOLDER].
const TUNNEL_SKY := Color(0.03, 0.025, 0.022)
const TUNNEL_AMBIENT := Color(0.28, 0.23, 0.20)
const TUNNEL_WALL := Color(0.22, 0.23, 0.26)
const TUNNEL_GRATE := Color(0.30, 0.32, 0.35)
const TUNNEL_PIPE_WARM: Color = ScopeTheme.TERRA
const TUNNEL_PIPE_STEEL: Color = ScopeTheme.INK_DIM
const TUNNEL_VENT_GLOW: Color = ScopeTheme.AMBER
const TUNNEL_WARM_LIGHT := Color(1.0, 0.78, 0.56)
const TUNNEL_LIGHT_ENERGY: float = 1.15
const TUNNEL_LIGHT_RANGE_M: float = 15.0

static var _unshaded_cache: Dictionary = {}


## Deterministic integer hash from coordinates and moon salt (no global RNG) [PLACEHOLDER].
static func hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## Cached unshaded material for distant sky dressing (Mars) [PLACEHOLDER].
static func unshaded_mat(color: Color) -> StandardMaterial3D:
	if _unshaded_cache.has(color):
		return _unshaded_cache[color] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_unshaded_cache[color] = material
	return material


static func drum_mesh(radius: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return mesh


## Flat-shaded Mars low on the horizon with polar cap and equatorial dust band [PLACEHOLDER].
static func add_mars(parent: Node3D, at: Vector3, radius: float, base_color: Color) -> MeshInstance3D:
	var mars := MeshInstance3D.new()
	mars.name = "Mars"
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 24
	ball.rings = 12
	mars.mesh = ball
	mars.material_override = unshaded_mat(base_color)
	mars.position = at
	parent.add_child(mars)
	# Dark basaltic equatorial belt + pale north polar ice cap [PLACEHOLDER].
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = radius * 1.006
	band_mesh.bottom_radius = radius * 1.006
	band_mesh.height = radius * 0.24
	band_mesh.radial_segments = 24
	mars.add_child(TunnelLook.part(band_mesh, Vector3(0.0, -radius * 0.06, 0.0), unshaded_mat(MARS_BAND), Vector3(8.0, 0.0, -10.0)))
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = radius * 0.26
	cap_mesh.bottom_radius = radius * 0.42
	cap_mesh.height = radius * 0.14
	cap_mesh.radial_segments = 16
	mars.add_child(TunnelLook.part(cap_mesh, Vector3(0.0, radius * 0.90, 0.0), unshaded_mat(MARS_POLAR), Vector3(6.0, 0.0, -8.0)))
	return mars


## Shallow crater basin with a deterministic segmented voxel rim (visual only) [PLACEHOLDER].
static func add_crater(parent: Node3D, at: Vector3, radius: float, floor_col: Color, rim_col: Color, salt: int) -> MeshInstance3D:
	var pit := MeshInstance3D.new()
	pit.name = "Crater"
	pit.mesh = drum_mesh(radius, 0.04, 14)
	pit.material_override = TunnelLook.flat_mat(floor_col)
	pit.position = Vector3(at.x, 0.03, at.z)
	parent.add_child(pit)
	var rim_mat: Material = TunnelLook.flat_mat(rim_col)
	var segs: int = 8
	for i: int in segs:
		var h: int = hash_int(int(at.x) + i, int(at.z), salt + i)
		var angle: float = TAU * float(i) / float(segs) + float(h % 10) * 0.02
		var r: float = radius + 0.18 + float(h % 3) * 0.08
		var bw: float = 0.85 + float((h >> 3) % 4) * 0.22
		var bh: float = 0.12 + float((h >> 6) % 4) * 0.05
		var bd: float = 0.48 + float((h >> 9) % 3) * 0.12
		pit.add_child(TunnelLook.part(TunnelLook.box(Vector3(bw, bh, bd)),
				Vector3(cos(angle) * r, bh * 0.5, sin(angle) * r), rim_mat, Vector3(0.0, -rad_to_deg(angle), 0.0)))
	return pit


## Deterministic perimeter boulders & cracked basalt ridges well outside the walk area (visual only) [PLACEHOLDER].
static func add_outer_rocks(parent: Node3D, moon_salt: int, boulder_col: Color, ridge_col: Color, dusty: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "OuterRocks"
	parent.add_child(group)
	var b_mat: Material = TunnelLook.flat_mat(boulder_col)
	var r_mat: Material = TunnelLook.flat_mat(ridge_col)
	var count: int = 14 if not dusty else 10
	for i: int in count:
		var h: int = hash_int(i * 7, moon_salt, 100 + i)
		var angle: float = TAU * float(i) / float(count) + float(h % 20) * 0.015
		# Past PhobosWalker.EDGE_M (34 m) plus the rock's half-depth, so no one walks through a rock.
		var dist: float = PhobosWalker.EDGE_M + 2.0 + float((h >> 4) % 3) * 0.5
		var px: float = cos(angle) * dist
		var pz: float = sin(angle) * dist
		var w: float = 1.4 + float((h >> 7) % 5) * 0.45
		var d: float = 1.1 + float((h >> 10) % 4) * 0.35
		var ht: float = (0.55 if dusty else 0.85) + float((h >> 13) % 4) * 0.28
		var yaw: float = float(h % 60) - 30.0
		group.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, ht, d)), Vector3(px, ht * 0.5, pz), b_mat, Vector3(0.0, yaw, 0.0)))
		if h % 2 == 0:
			group.add_child(TunnelLook.part(TunnelLook.box(Vector3(w * 0.58, ht * 0.65, d * 0.62)),
					Vector3(px + 0.55, ht * 0.32, pz - 0.35), r_mat, Vector3(4.0, yaw + 18.0, -3.0)))
	return group


## Lander pad markings, corner bollards, and teal approach strips under the shuttle (visual only) [PLACEHOLDER].
static func add_lander_pad(parent: Node3D, at: Vector3, hex_style: bool) -> Node3D:
	var sides: int = 6 if hex_style else 8
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = drum_mesh(8.0, 0.1, sides)
	pad.material_override = TunnelLook.flat_mat(PAD_SURFACE)
	pad.position = Vector3(at.x, 0.05, at.z)
	parent.add_child(pad)

	var rim := MeshInstance3D.new()
	rim.name = "PadRim"
	rim.mesh = drum_mesh(8.6, 0.06, sides)
	rim.material_override = TunnelLook.flat_mat(PAD_STRIPE.darkened(0.3))
	rim.position = Vector3(at.x, 0.02, at.z)
	parent.add_child(rim)

	var detail := Node3D.new()
	detail.name = "PadDetail"
	detail.position = Vector3(at.x, 0.0, at.z)
	parent.add_child(detail)
	var stripe_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var glow_mat: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.55)
	var metal_mat: Material = TunnelLook.flat_mat(STEEL)
	# Crosshair deck markings + edge beacons + tie-down bollards [PLACEHOLDER].
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(9.6, 0.02, 0.24)), Vector3(0.0, 0.11, 0.0), stripe_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.02, 5.4)), Vector3(0.0, 0.11, 0.0), stripe_mat))
	for i: int in sides:
		var a: float = TAU * float(i) / float(sides)
		var bx: float = cos(a) * 7.2
		var bz: float = sin(a) * 7.2
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.32, 0.24, 0.32)), Vector3(bx, 0.20, bz), metal_mat))
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.20, 0.06, 0.20)), Vector3(bx, 0.34, bz), glow_mat))
	return detail


## Visual detail around the parked shuttle's solid hull boxes (zero collision) [PLACEHOLDER].
static func add_shuttle_detail(parent: Node3D, hull_col: Color, wing_col: Color) -> Node3D:
	var detail := Node3D.new()
	detail.name = "ShuttleDetail"
	parent.add_child(detail)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var trim_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var hull_mat: Material = TunnelLook.flat_mat(hull_col)
	var wing_mat: Material = TunnelLook.flat_mat(wing_col)
	var glow_mat: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.6)

	# Dorsal spine & comms fin on top of ShuttleBody (-14, 1.6, 1, size 9 x 3.2 x 3.6).
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(7.4, 0.42, 1.35)), Vector3(-13.6, 3.40, 1.0), wing_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.8, 0.72, 0.28)), Vector3(-10.4, 3.82, 1.0), hull_mat))
	# Twin rear thruster bells & glowing core rings at x = -9.4.
	for z_off: float in [0.1, 1.9]:
		detail.add_child(TunnelLook.part(TunnelLook.cylinder(0.68, 0.7), Vector3(-9.25, 1.55, z_off), steel_mat, Vector3(0.0, 0.0, 90.0)))
		detail.add_child(TunnelLook.part(TunnelLook.cylinder(0.48, 0.16), Vector3(-8.88, 1.55, z_off), dark_mat, Vector3(0.0, 0.0, 90.0)))
	# Cockpit visor glare strip & nose bumper.
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.65, 2.25)), Vector3(-20.22, 2.15, 1.0), glow_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.55, 0.55, 2.75)), Vector3(-20.25, 1.05, 1.0), dark_mat))
	# Amber wingtip hazard bands + landing gear struts.
	for wz: float in [-3.95, 5.95]:
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(3.85, 0.34, 0.32)), Vector3(-13.0, 0.52, wz), trim_mat))
	for sx: float in [-16.6, -11.4]:
		for sz: float in [-0.7, 2.7]:
			detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.42, 0.22, 0.56)), Vector3(sx, 0.18, sz), dark_mat))
	return detail


## Structural ribs, lit viewports, airlock frame, rooftop comms, and door sconce for Phobos Station [PLACEHOLDER].
static func add_phobos_station_detail(parent: Node3D) -> Node3D:
	var detail := Node3D.new()
	detail.name = "StationDetail"
	parent.add_child(detail)
	var trim_mat: Material = TunnelLook.flat_mat(PHOBOS_STATION_TRIM)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var win_mat: Material = TunnelLook.glow_mat(WINDOW_GLOW, 0.65)
	var teal_mat: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.55)

	# Vertical hull ribs along the 22 m Station front/back (-9..+13 in X).
	for x: float in [-8.2, -4.4, -0.6, 4.6, 8.4, 12.2]:
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 4.55, 7.28)), Vector3(x, 2.28, -14.0), trim_mat))
	# Lit amber viewport windows on the front facade (z = -10.46).
	for wx: float in [-6.3, -2.5, 6.5, 10.3]:
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.55, 0.92, 0.14)), Vector3(wx, 2.65, -10.46), dark_mat))
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.32, 0.68, 0.18)), Vector3(wx, 2.65, -10.44), win_mat))
	# Airlock doorway frame & warm porch sconce over StationDoor (2, 1.4, -10.45).
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.85, 0.34, 0.65)), Vector3(2.0, 2.95, -10.28), trim_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.85, 0.14, 0.16)), Vector3(2.0, 2.86, -9.96), win_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.6, 0.10, 0.85)), Vector3(2.0, 0.05, -10.15), dark_mat))
	# Comms mast & beacon on top of StationDome (8, 4.8, -14).
	detail.add_child(TunnelLook.part(TunnelLook.cylinder(0.14, 2.1), Vector3(8.0, 6.45, -14.0), trim_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.6, 0.14, 0.14)), Vector3(8.0, 7.1, -14.0), brass_mat))
	detail.add_child(TunnelLook.part(TunnelLook.sphere(0.20), Vector3(8.0, 7.55, -14.0), teal_mat))

	var sconce := OmniLight3D.new()
	sconce.name = "StationSconce"
	sconce.position = Vector3(2.0, 2.8, -9.5)
	sconce.light_color = WINDOW_GLOW
	sconce.light_energy = SCONCE_ENERGY
	sconce.omni_range = SCONCE_RANGE_M
	detail.add_child(sconce)
	return detail


## Structural ribs, warm glowing portholes, airlock awning, dish mast, and porch light for Deimos Hab [PLACEHOLDER].
static func add_deimos_hab_detail(parent: Node3D, hab: Vector3) -> Node3D:
	var detail := Node3D.new()
	detail.name = "HabDetail"
	detail.position = hab
	parent.add_child(detail)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var win_mat: Material = TunnelLook.glow_mat(WINDOW_GLOW, 0.7)
	var teal_mat: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.55)

	# Six external vertical ribs hugging the circular hab drum.
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + 0.25
		detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.28, 3.45, 0.36)),
				Vector3(cos(a) * 4.52, 1.72, sin(a) * 4.52), steel_mat, Vector3(0.0, -rad_to_deg(a), 0.0)))
	# Brass band between terracotta skirt and cream body.
	detail.add_child(TunnelLook.part(drum_mesh(4.64, 0.14, 12), Vector3(0.0, 1.42, 0.0), brass_mat))
	# Airlock doorway awning + step + warm porthole glow.
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.65, 0.22, 0.72)), Vector3(-1.2, 2.52, 4.45), steel_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.55, 0.10, 0.80)), Vector3(-1.2, 0.05, 4.65), dark_mat))
	detail.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.62, 0.62, 0.12)), Vector3(1.8, 2.5, 4.10), win_mat))
	# Rooftop dish mast & telemetry tip above HabDish (0, 4.3, 0).
	detail.add_child(TunnelLook.part(TunnelLook.cylinder(0.10, 1.15), Vector3(0.0, 4.95, 0.0), steel_mat))
	detail.add_child(TunnelLook.part(TunnelLook.sphere(0.16), Vector3(0.0, 5.58, 0.0), teal_mat))

	var sconce := OmniLight3D.new()
	sconce.name = "HabSconce"
	sconce.position = Vector3(-1.2, 2.4, 5.1)
	sconce.light_color = WINDOW_GLOW
	sconce.light_energy = SCONCE_ENERGY
	sconce.omni_range = SCONCE_RANGE_M
	detail.add_child(sconce)
	return detail


## Adds sloped bezel, glowing teal display core, brass handles, antenna, and soft light to ConsoleDesk [PLACEHOLDER].
static func add_console_detail(root: Node3D) -> void:
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var glow_mat: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.65)

	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.56, 0.12, 0.88)), Vector3(0.0, 0.06, 0.0), dark_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.36, 0.82, 0.10)), Vector3(0.0, 1.30, -0.14), steel_mat, Vector3(-12.0, 0.0, 0.0)))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.10, 0.56, 0.04)), Vector3(0.0, 1.30, -0.065), glow_mat, Vector3(-12.0, 0.0, 0.0)))
	# Brass side rails & small keypad deck.
	for sx: float in [-0.74, 0.74]:
		root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.08, 0.36, 0.42)), Vector3(sx, 0.88, 0.05), brass_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.86, 0.06, 0.24)), Vector3(0.0, 1.03, 0.16), dark_mat, Vector3(12.0, 0.0, 0.0)))
	# Compact uplink antenna mast.
	root.add_child(TunnelLook.part(TunnelLook.cylinder(0.03, 0.85), Vector3(0.62, 1.42, -0.22), steel_mat))
	root.add_child(TunnelLook.part(TunnelLook.sphere(0.07), Vector3(0.62, 1.88, -0.22), glow_mat))

	var light := OmniLight3D.new()
	light.name = "ConsoleGlow"
	light.position = Vector3(0.0, 1.45, 0.45)
	light.light_color = SCREEN_GLOW
	light.light_energy = CONSOLE_LIGHT_ENERGY
	light.omni_range = CONSOLE_LIGHT_RANGE_M
	root.add_child(light)


## Adds twin steel posts, footplates, header cap, brass brackets, and pinned notes around BoardPanel [PLACEHOLDER].
static func add_board_detail(parent: Node3D, at: Vector3) -> Node3D:
	var trim := Node3D.new()
	trim.name = "BoardTrim"
	trim.position = at
	parent.add_child(trim)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var wood_mat: Material = TunnelLook.flat_mat(BOARD_WOOD)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var cream_mat: Material = TunnelLook.flat_mat(CREAM)

	for sx: float in [-1.42, 1.42]:
		trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.32, 0.12, 0.32)), Vector3(sx, 0.06, 0.0), dark_mat))
		trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 2.55, 0.14)), Vector3(sx, 1.32, 0.0), steel_mat))
		trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.20, 0.16, 0.20)), Vector3(sx, 2.52, 0.0), brass_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(3.26, 0.14, 0.26)), Vector3(0.0, 2.58, 0.0), wood_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.42, 0.28, 0.03)), Vector3(-1.12, 1.05, 0.08), cream_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.06, 0.06, 0.04)), Vector3(-1.12, 1.16, 0.09), brass_mat))
	return trim


## Louver bars, bent grille frame, and curled molt segments for Phobos's escapee hook [PLACEHOLDER].
static func add_hook_detail(parent: Node3D, at: Vector3) -> Node3D:
	var trim := Node3D.new()
	trim.name = "HookTrim"
	trim.position = at
	parent.add_child(trim)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var skin_mat: Material = TunnelLook.flat_mat(SKIN_PALE)
	# Frame border + louver slats.
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.74, 0.10, 0.14)), Vector3(0.0, 1.22, 0.02), steel_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.74, 0.10, 0.14)), Vector3(0.0, 0.18, 0.02), steel_mat))
	for ly: float in [0.42, 0.66, 0.90]:
		trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.52, 0.05, 0.06)), Vector3(-0.04, ly, 0.06), steel_mat))
	# Curled pale molt legs beside ShedSkin (0.9, 0.3, 0.35).
	for i: int in 4:
		var lx: float = 0.68 + float(i) * 0.15
		trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.06, 0.06, 0.36)),
				Vector3(lx, 0.14, 0.42), skin_mat, Vector3(14.0, float(i * 12 - 18), 0.0)))
	return trim


## Heavy bolted collar, cross-rib wheel, and corner hazard plates for Phobos's sealed hatch [PLACEHOLDER].
static func add_hatch_detail(parent: Node3D, at: Vector3) -> Node3D:
	var trim := Node3D.new()
	trim.name = "HatchTrim"
	trim.position = at
	parent.add_child(trim)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)

	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.85, 0.06, 0.16)), Vector3(0.0, 0.19, 0.0), steel_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.06, 1.85)), Vector3(0.0, 0.19, 0.0), steel_mat))
	trim.add_child(TunnelLook.part(TunnelLook.cylinder(0.32, 0.08), Vector3(0.0, 0.24, 0.0), brass_mat))
	for sx: float in [-1.08, 1.08]:
		for sz: float in [-1.08, 1.08]:
			trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.14, 0.24)), Vector3(sx, 0.09, sz), dark_mat))
	return trim


## Crate straps, corner cleats, and glowing teal padlock shackle for Deimos's smuggler cache [PLACEHOLDER].
static func add_cache_detail(parent: Node3D, at: Vector3) -> Node3D:
	var trim := Node3D.new()
	trim.name = "CacheTrim"
	trim.position = at
	parent.add_child(trim)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var lock_glow: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.65)

	# Steel reinforcement bands on CrateA (-0.7, 0.5, 0) & CrateB (0.7, 0.45, 0.2).
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.26, 0.10, 1.06)), Vector3(-0.7, 0.88, 0.0), steel_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.06, 0.10, 1.06)), Vector3(0.7, 0.80, 0.2), steel_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.16, 0.08, 0.96)), Vector3(0.0, 1.72, 0.0), brass_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.12, 0.14)), Vector3(-0.7, 0.88, 0.54), lock_glow))
	return trim


## Thermal ribs, brass window bezel, heater bar glow, and roof beacon for Deimos's test pod [PLACEHOLDER].
static func add_pod_detail(parent: Node3D, at: Vector3) -> Node3D:
	var trim := Node3D.new()
	trim.name = "PodTrim"
	trim.position = at
	parent.add_child(trim)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var brass_mat: Material = TunnelLook.flat_mat(PAD_STRIPE)
	var warm_glow: Material = TunnelLook.glow_mat(WINDOW_GLOW, 0.75)
	var teal_glow: Material = TunnelLook.glow_mat(SCREEN_GLOW, 0.6)

	# Top cap & side thermal ribs around PodShell (0, 0.8, 0, size 1.6 x 1.6 x 2.6).
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.36, 0.20, 2.36)), Vector3(0.0, 1.70, 0.0), steel_mat))
	for sz: float in [-0.75, 0.0, 0.75]:
		trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.74, 1.38, 0.14)), Vector3(0.0, 0.80, sz), steel_mat))
	# Brass bezel around PodGlass + glowing heater bar at PodWarmth + roof beacon.
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.16, 0.84, 0.06)), Vector3(0.0, 1.0, 1.30), brass_mat))
	trim.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.04, 0.08, 0.24)), Vector3(0.0, 0.16, 1.50), warm_glow))
	trim.add_child(TunnelLook.part(TunnelLook.sphere(0.11), Vector3(0.0, 1.88, -0.65), teal_glow))
	return trim
