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

## Second-pass look constants: starfield, Mars horizon glow, pad edge lights,
## station/hab cables & crates, regolith scatter, Deimos camp perimeter, and
## Phobos service tunnel mouth dressing [PLACEHOLDER].
const STAR_WHITE: Color = ScopeTheme.INK
const STAR_WARM: Color = ScopeTheme.ENAMEL_TOP
const STAR_COOL: Color = ScopeTheme.INK_MUTED
const STAR_COUNT_PHOBOS: int = 84
const STAR_COUNT_DEIMOS: int = 96
const STAR_SEED_PHOBOS: int = 4101
const STAR_SEED_DEIMOS: int = 4202
const STAR_RADIUS_MIN_M: float = 98.0
const STAR_RADIUS_MAX_M: float = 128.0
const STAR_SIZE_MIN_M: float = 0.24
const STAR_SIZE_MAX_M: float = 0.52

const MARS_GLOW_PHOBOS := Color(0.42, 0.17, 0.11)
const MARS_GLOW_DEIMOS := Color(0.32, 0.16, 0.12)
const MARS_GLOW_ALPHA_PHOBOS: float = 0.22
const MARS_GLOW_ALPHA_DEIMOS: float = 0.16
const MARS_HALO_SCALES: Array[float] = [1.08, 1.18, 1.30]
const MARS_HALO_ALPHA_WEIGHTS: Array[float] = [0.85, 0.45, 0.20]

const PAD_EDGE_LIGHT_ENERGY: float = 0.85
const PAD_EDGE_AMBER: Color = ScopeTheme.AMBER
const PAD_EDGE_TEAL: Color = ScopeTheme.TEAL

const CABLE_SHEATH: Color = ScopeTheme.SHADOW
const CABLE_STRIPE: Color = ScopeTheme.AMBER
const CRATE_PHOBOS := Color(0.30, 0.33, 0.38)
const CRATE_PHOBOS_TRIM: Color = ScopeTheme.TERRA_DARK
const CRATE_DEIMOS: Color = ScopeTheme.ENAMEL_INSET
const CRATE_DEIMOS_TRIM: Color = ScopeTheme.TERRA

const DRIFT_PHOBOS := Color(0.17, 0.18, 0.20)
const DRIFT_PHOBOS_LIGHT := Color(0.24, 0.25, 0.28)
const DRIFT_DEIMOS := Color(0.49, 0.45, 0.39)
const DRIFT_DEIMOS_LIGHT := Color(0.58, 0.53, 0.46)
const SCATTER_SEED_PHOBOS: int = 5101
const SCATTER_SEED_DEIMOS: int = 5202
const SCATTER_DRIFTS_PHOBOS: int = 12
const SCATTER_ROCKS_PHOBOS: int = 18
const SCATTER_DRIFTS_DEIMOS: int = 14
const SCATTER_ROCKS_DEIMOS: int = 12
const SCATTER_MIN_RADIUS_M: float = 7.5
const SCATTER_MAX_RADIUS_M: float = 31.5
const SPOT_CLEARANCE_M: float = 4.2

const CAMP_PATCH_COLOR := Color(0.47, 0.42, 0.36)
const CAMP_PATCH_RIM := Color(0.56, 0.50, 0.43)
const CAMP_STAKE_COLOR: Color = ScopeTheme.INK_DIM
const CAMP_WINDBREAK_FRAME: Color = ScopeTheme.SHADOW
const CAMP_WINDBREAK_PANEL: Color = ScopeTheme.ENAMEL_LIP
const CAMP_WINDBREAK_STRIPE: Color = ScopeTheme.TERRA

const MOUTH_CAUTION: Color = ScopeTheme.AMBER
const MOUTH_VENT_GLOW: Color = ScopeTheme.AMBER
const MOUTH_PIPE_WARM: Color = ScopeTheme.TERRA

static var _unshaded_cache: Dictionary = {}
static var _unshaded_alpha_cache: Dictionary = {}


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


## Cached translucent unshaded material for faint sky/horizon glow [PLACEHOLDER].
static func unshaded_alpha_mat(
	color: Color,
	alpha: float,
	cull_mode: BaseMaterial3D.CullMode = BaseMaterial3D.CULL_BACK
) -> StandardMaterial3D:
	var key: String = "%s|%.3f|%d" % [color.to_html(false), alpha, int(cull_mode)]
	if _unshaded_alpha_cache.has(key):
		return _unshaded_alpha_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = false
	material.cull_mode = cull_mode
	_unshaded_alpha_cache[key] = material
	return material


## Deterministic unshaded starfield built from a local seeded RNG (zero collision, zero lights) [PLACEHOLDER].
static func add_starfield(parent: Node3D, seed_value: int, count: int) -> Node3D:
	var sky := Node3D.new()
	sky.name = "Starfield"
	parent.add_child(sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var white_mat: Material = unshaded_mat(STAR_WHITE)
	var warm_mat: Material = unshaded_mat(STAR_WARM)
	var cool_mat: Material = unshaded_mat(STAR_COOL)
	for i: int in count:
		var theta: float = rng.randf_range(0.0, TAU)
		var elev: float = rng.randf_range(0.14, 1.38)
		var dist: float = rng.randf_range(STAR_RADIUS_MIN_M, STAR_RADIUS_MAX_M)
		var size_m: float = rng.randf_range(STAR_SIZE_MIN_M, STAR_SIZE_MAX_M)
		var pick: int = rng.randi() % 5
		var mat: Material = warm_mat if pick == 0 else (cool_mat if pick == 1 else white_mat)
		var pos := Vector3(cos(elev) * cos(theta) * dist, sin(elev) * dist, cos(elev) * sin(theta) * dist)
		sky.add_child(TunnelLook.part(TunnelLook.box(Vector3(size_m, size_m, size_m)), pos, mat))
	return sky


## Faint translucent unshaded Mars rim halo built from nested CULL_FRONT shells
## so opaque Mars hides the middle and only a soft stepped rim shows (zero
## collision, zero lights; no flat horizon box) [PLACEHOLDER].
static func add_mars_horizon_glow(parent: Node3D, mars_at: Vector3, mars_radius: float, glow_col: Color, alpha: float) -> Node3D:
	var group := Node3D.new()
	group.name = "MarsHorizonGlow"
	parent.add_child(group)
	for i: int in MARS_HALO_SCALES.size():
		var shell_radius: float = mars_radius * MARS_HALO_SCALES[i]
		var halo_mesh := SphereMesh.new()
		halo_mesh.radius = shell_radius
		halo_mesh.height = shell_radius * 2.0
		halo_mesh.radial_segments = 24
		halo_mesh.rings = 12
		var shell_mat: Material = unshaded_alpha_mat(
			glow_col,
			alpha * MARS_HALO_ALPHA_WEIGHTS[i],
			BaseMaterial3D.CULL_FRONT
		)
		group.add_child(TunnelLook.part(halo_mesh, mars_at, shell_mat))
	return group


## Small emissive pad edge lights around the lander pad rim (zero collision, no OmniLight3D) [PLACEHOLDER].
static func add_pad_edge_lights(parent: Node3D, at: Vector3, hex_style: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "PadEdgeLights"
	group.position = Vector3(at.x, 0.0, at.z)
	parent.add_child(group)
	var sides: int = 6 if hex_style else 8
	var housing_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var amber_glow: Material = TunnelLook.glow_mat(PAD_EDGE_AMBER, PAD_EDGE_LIGHT_ENERGY)
	var teal_glow: Material = TunnelLook.glow_mat(PAD_EDGE_TEAL, PAD_EDGE_LIGHT_ENERGY)
	for i: int in sides:
		var a: float = TAU * (float(i) + 0.5) / float(sides)
		var r: float = 7.95
		var px: float = cos(a) * r
		var pz: float = sin(a) * r
		var rot := Vector3(0.0, -rad_to_deg(a) + 90.0, 0.0)
		var glow_mat: Material = amber_glow if i % 2 == 0 else teal_glow
		group.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.42, 0.08, 0.22)), Vector3(px, 0.09, pz), housing_mat, rot))
		group.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.30, 0.05, 0.12)), Vector3(px, 0.145, pz), glow_mat, rot))
	return group


## Cable runs and cargo crates tucked beside the station (Phobos) or hab (Deimos),
## clear of every walkable spot and click target (zero collision, zero lights) [PLACEHOLDER].
static func add_utility_props(parent: Node3D, is_deimos: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "UtilityProps"
	parent.add_child(group)
	var cable_mat: Material = TunnelLook.flat_mat(CABLE_SHEATH)
	var stripe_mat: Material = TunnelLook.flat_mat(CABLE_STRIPE)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var crate_mat: Material = TunnelLook.flat_mat(CRATE_DEIMOS if is_deimos else CRATE_PHOBOS)
	var trim_mat: Material = TunnelLook.flat_mat(CRATE_DEIMOS_TRIM if is_deimos else CRATE_PHOBOS_TRIM)
	if not is_deimos:
		# Flat cable trunks along Phobos Station's front base (clear of StationDoor, Board, HookSign).
		_add_cable_run(group, Vector3(-4.2, 0.0, -10.22), 8.2, 0.0, cable_mat, stripe_mat)
		_add_cable_run(group, Vector3(5.9, 0.0, -10.22), 4.0, 0.0, cable_mat, stripe_mat)
		_add_cable_run(group, Vector3(-9.5, 0.0, -8.3), 4.8, 90.0, cable_mat, stripe_mat)
		# Cargo crate stack beside Station's west flank and compact crate on the east flank.
		_add_crate_stack(group, Vector3(-9.9, 0.0, -11.6), crate_mat, trim_mat, steel_mat, 10.0)
		_add_crate_single(group, Vector3(13.8, 0.0, -12.8), Vector3(1.05, 0.72, 0.85), crate_mat, trim_mat, -14.0)
	else:
		# Flat cable run along Deimos Hab's west flank (clear of Board, Cache, Pod, Camp).
		_add_cable_run(group, Vector3(-1.8, 0.0, -15.2), 3.4, 90.0, cable_mat, stripe_mat)
		_add_cable_run(group, Vector3(9.6, 0.0, -14.0), 2.4, 90.0, cable_mat, stripe_mat)
		# Outpost supply crates tucked on the west and east flanks of the Hab drum.
		_add_crate_stack(group, Vector3(-1.5, 0.0, -16.8), crate_mat, trim_mat, steel_mat, -12.0)
		_add_crate_single(group, Vector3(9.7, 0.0, -15.6), Vector3(1.0, 0.68, 0.82), crate_mat, trim_mat, 16.0)
	return group


static func _add_cable_run(parent: Node3D, at: Vector3, length_m: float, yaw_deg: float, sheath_mat: Material, stripe_mat: Material) -> void:
	var run := Node3D.new()
	run.position = at
	run.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(run)
	run.add_child(TunnelLook.part(TunnelLook.box(Vector3(length_m, 0.05, 0.22)), Vector3(0.0, 0.025, 0.0), sheath_mat))
	run.add_child(TunnelLook.part(TunnelLook.box(Vector3(length_m - 0.16, 0.03, 0.07)), Vector3(0.0, 0.055, -0.04), sheath_mat))
	var ties: int = maxi(int(floor(length_m / 1.8)), 2)
	for i: int in ties:
		var t: float = float(i) / float(maxi(ties - 1, 1)) - 0.5
		run.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.065, 0.26)), Vector3(t * (length_m - 0.5), 0.035, 0.0), stripe_mat))


static func _add_crate_stack(parent: Node3D, at: Vector3, body_mat: Material, trim_mat: Material, steel_mat: Material, yaw_deg: float) -> void:
	var stack := Node3D.new()
	stack.position = at
	stack.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(stack)
	_add_crate_single(stack, Vector3(0.0, 0.0, 0.0), Vector3(1.15, 0.78, 0.90), body_mat, trim_mat, 0.0)
	_add_crate_single(stack, Vector3(0.06, 0.78, -0.04), Vector3(0.84, 0.56, 0.68), body_mat, steel_mat, 14.0)


static func _add_crate_single(parent: Node3D, at: Vector3, size: Vector3, body_mat: Material, trim_mat: Material, yaw_deg: float) -> void:
	var crate := Node3D.new()
	crate.position = at
	crate.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(crate)
	crate.add_child(TunnelLook.part(TunnelLook.box(size), Vector3(0.0, size.y * 0.5, 0.0), body_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(size.x + 0.06, 0.08, size.z + 0.06)), Vector3(0.0, size.y * 0.78, 0.0), trim_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(size.x + 0.04, 0.08, size.z + 0.04)), Vector3(0.0, 0.06, 0.0), trim_mat))


## Deterministic regolith drifts and small rocks scattered clear of every walkable
## spot, arrival point, pad, station/hab, and camp (zero collision, zero lights) [PLACEHOLDER].
static func add_regolith_scatter(
	parent: Node3D,
	seed_value: int,
	drift_count: int,
	rock_count: int,
	drift_col: Color,
	drift_light_col: Color,
	rock_col: Color,
	rim_col: Color,
	keep_clear: Array[Vector3],
	is_deimos: bool,
	clearance_m: float = SPOT_CLEARANCE_M
) -> Node3D:
	var group := Node3D.new()
	group.name = "RegolithScatter"
	parent.add_child(group)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var drift_mat: Material = TunnelLook.flat_mat(drift_col)
	var drift_light_mat: Material = TunnelLook.flat_mat(drift_light_col)
	var rock_mat: Material = TunnelLook.flat_mat(rock_col)
	var rim_mat: Material = TunnelLook.flat_mat(rim_col)

	var placed_drifts: int = 0
	for _attempt: int in drift_count * 12:
		if placed_drifts >= drift_count:
			break
		var pos: Vector3 = _pick_scatter_pos(rng)
		if not _is_scatter_clear(pos, keep_clear, is_deimos, clearance_m):
			continue
		var w: float = rng.randf_range(1.5, 3.0)
		var d: float = rng.randf_range(0.95, 1.85)
		var h: float = rng.randf_range(0.04, 0.07)
		var yaw: float = rng.randf_range(-180.0, 180.0)
		var mat_a: Material = drift_mat if placed_drifts % 2 == 0 else drift_light_mat
		var mat_b: Material = drift_light_mat if placed_drifts % 2 == 0 else drift_mat
		group.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, h, d)), Vector3(pos.x, h * 0.5, pos.z), mat_a, Vector3(0.0, yaw, 0.0)))
		group.add_child(TunnelLook.part(TunnelLook.box(Vector3(w * 0.54, h * 0.75, d * 0.56)),
				Vector3(pos.x + 0.14, h * 0.95, pos.z - 0.10), mat_b, Vector3(0.0, yaw + 16.0, 0.0)))
		placed_drifts += 1

	var placed_rocks: int = 0
	for _attempt: int in rock_count * 12:
		if placed_rocks >= rock_count:
			break
		var pos: Vector3 = _pick_scatter_pos(rng)
		if not _is_scatter_clear(pos, keep_clear, is_deimos, clearance_m):
			continue
		var w: float = rng.randf_range(0.28, 0.62)
		var h: float = rng.randf_range(0.16, 0.38)
		var d: float = rng.randf_range(0.24, 0.54)
		var yaw: float = rng.randf_range(-180.0, 180.0)
		var mat: Material = rock_mat if placed_rocks % 3 != 0 else rim_mat
		group.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, h, d)), Vector3(pos.x, h * 0.5, pos.z), mat, Vector3(0.0, yaw, 0.0)))
		if placed_rocks % 2 == 0:
			group.add_child(TunnelLook.part(TunnelLook.box(Vector3(w * 0.52, h * 0.58, d * 0.50)),
					Vector3(pos.x + w * 0.45, h * 0.28, pos.z - d * 0.25), rim_mat, Vector3(4.0, yaw + 24.0, -3.0)))
		placed_rocks += 1
	return group


static func _pick_scatter_pos(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var dist: float = rng.randf_range(SCATTER_MIN_RADIUS_M, SCATTER_MAX_RADIUS_M)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


static func _is_scatter_clear(pos: Vector3, keep_clear: Array[Vector3], is_deimos: bool, clearance_m: float) -> bool:
	# Keep off the lander pad and shuttle footprint (-14, 0, 1).
	if Vector2(pos.x + 14.0, pos.z - 1.0).length() < 10.2:
		return false
	# Keep clear of Station (Phobos) or Hab (Deimos) and their utility flanks.
	if not is_deimos:
		if pos.x >= -12.0 and pos.x <= 15.6 and pos.z >= -19.2 and pos.z <= -9.0:
			return false
	else:
		if Vector2(pos.x - 4.0, pos.z + 15.0).length() < 7.6:
			return false
	for spot: Vector3 in keep_clear:
		if Vector2(pos.x - spot.x, pos.z - spot.z).length() < clearance_m:
			return false
	return true


## Deimos expedition camp ground patch, perimeter stakes, and low windbreak around
## `camp_at`, placed outside CampProps and CampClick footprints (zero collision, zero lights) [PLACEHOLDER].
static func add_deimos_camp_dressing(parent: Node3D, camp_at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "CampDressing"
	root.position = camp_at
	parent.add_child(root)

	# Flush dust-ground patch sitting flat on the deck beneath the camp area.
	var patch := Node3D.new()
	patch.name = "CampDustPatch"
	root.add_child(patch)
	patch.add_child(TunnelLook.part(drum_mesh(3.6, 0.014, 12), Vector3(0.0, 0.007, 0.0), TunnelLook.flat_mat(CAMP_PATCH_COLOR)))
	patch.add_child(TunnelLook.part(drum_mesh(2.9, 0.012, 12), Vector3(0.1, 0.011, -0.05), TunnelLook.flat_mat(CAMP_PATCH_RIM)))

	# Corner stakes and L-shaped low windbreak strictly outside CampProps & CampClick (|x| <= 2.2, |z| <= 1.5).
	var perimeter := Node3D.new()
	perimeter.name = "CampPerimeter"
	root.add_child(perimeter)
	var stake_mat: Material = TunnelLook.flat_mat(CAMP_STAKE_COLOR)
	var frame_mat: Material = TunnelLook.flat_mat(CAMP_WINDBREAK_FRAME)
	var panel_mat: Material = TunnelLook.flat_mat(CAMP_WINDBREAK_PANEL)
	var stripe_mat: Material = TunnelLook.flat_mat(CAMP_WINDBREAK_STRIPE)

	for corner: Vector3 in [
		Vector3(-2.65, 0.0, -2.05),
		Vector3(2.75, 0.0, -2.05),
		Vector3(-2.65, 0.0, 2.05),
		Vector3(2.75, 0.0, 2.05),
	]:
		perimeter.add_child(TunnelLook.part(TunnelLook.cylinder(0.04, 0.48), corner + Vector3(0.0, 0.24, 0.0), stake_mat))
		perimeter.add_child(TunnelLook.part(TunnelLook.cylinder(0.06, 0.05), corner + Vector3(0.0, 0.44, 0.0), stripe_mat))

	# North low windbreak wall at z = -2.25, x in [-2.3, 1.9].
	perimeter.add_child(TunnelLook.part(TunnelLook.box(Vector3(4.2, 0.68, 0.12)), Vector3(-0.2, 0.40, -2.25), panel_mat))
	perimeter.add_child(TunnelLook.part(TunnelLook.box(Vector3(4.26, 0.09, 0.14)), Vector3(-0.2, 0.56, -2.25), stripe_mat))
	for px: float in [-2.25, -0.2, 1.85]:
		perimeter.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.10, 0.80, 0.16)), Vector3(px, 0.40, -2.25), frame_mat))

	# West low windbreak wing at x = -2.55, z in [-2.25, -0.25].
	perimeter.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.12, 0.62, 2.0)), Vector3(-2.55, 0.37, -1.25), panel_mat))
	perimeter.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.08, 2.04)), Vector3(-2.55, 0.52, -1.25), stripe_mat))
	for pz: float in [-2.20, -0.30]:
		perimeter.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.74, 0.10)), Vector3(-2.55, 0.37, pz), frame_mat))
	return root


## Surface dressing at Phobos's service tunnel mouth (around Hatch, clear of the
## west ladder arrival spot and Hatch click box; zero collision, zero lights) [PLACEHOLDER].
static func add_tunnel_mouth_dressing(parent: Node3D, hatch_at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "TunnelMouthDetail"
	root.position = hatch_at
	parent.add_child(root)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var caution_mat: Material = TunnelLook.flat_mat(MOUTH_CAUTION)
	var warm_pipe_mat: Material = TunnelLook.flat_mat(MOUTH_PIPE_WARM)
	var glow_mat: Material = TunnelLook.glow_mat(MOUTH_VENT_GLOW, 0.7)

	# Flush caution threshold bars along the north and east collar edges.
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.6, 0.03, 0.16)), Vector3(0.0, 0.02, -1.48), caution_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.03, 2.6)), Vector3(1.48, 0.02, 0.0), caution_mat))
	# Low corner bollards on the east side of the hatch.
	for bz: float in [-1.45, 1.45]:
		root.add_child(TunnelLook.part(TunnelLook.cylinder(0.09, 0.58), Vector3(1.68, 0.29, bz), dark_mat))
		root.add_child(TunnelLook.part(TunnelLook.cylinder(0.10, 0.10), Vector3(1.68, 0.50, bz), caution_mat))
	# Compact warm-conduit vent stack & insulated pipe elbow on the north-east corner.
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.68, 0.92, 0.56)), Vector3(1.85, 0.46, -1.15), steel_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.46, 0.34, 0.08)), Vector3(1.85, 0.56, -0.84), glow_mat))
	root.add_child(TunnelLook.part(TunnelLook.cylinder(0.11, 0.72), Vector3(1.85, 0.36, -1.68), warm_pipe_mat))
	root.add_child(TunnelLook.part(TunnelLook.cylinder(0.11, 0.52), Vector3(1.85, 0.68, -1.42), warm_pipe_mat, Vector3(90.0, 0.0, 0.0)))
	# Short flat conduit cable heading north toward the station east flank.
	_add_cable_run(root, Vector3(1.85, 0.0, -3.1), 2.8, 90.0, dark_mat, caution_mat)
	return root


## Look-only dressing at the top/ladder mouth inside PhobosServiceTunnel
## (zero collision, zero lights) [PLACEHOLDER].
static func add_service_tunnel_mouth_detail(parent: Node3D, ladder_at: Vector3, wall_height_m: float) -> Node3D:
	var root := Node3D.new()
	root.name = "TunnelMouthDetail"
	root.position = ladder_at
	parent.add_child(root)
	var dark_mat: Material = TunnelLook.flat_mat(DARK_METAL)
	var steel_mat: Material = TunnelLook.flat_mat(STEEL)
	var caution_mat: Material = TunnelLook.flat_mat(MOUTH_CAUTION)
	var warm_pipe_mat: Material = TunnelLook.flat_mat(MOUTH_PIPE_WARM)
	var beacon_glow: Material = TunnelLook.glow_mat(MOUTH_VENT_GLOW, 0.8)

	# Overhead hatch shaft coaming collar & amber status box above the ladder.
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.65, 0.22, 1.35)), Vector3(0.0, wall_height_m - 0.11, 0.20), dark_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.72, 0.08, 1.42)), Vector3(0.0, wall_height_m - 0.24, 0.20), caution_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.14, 0.12)), Vector3(0.66, wall_height_m - 0.42, -0.42), beacon_glow))
	# Caution floor rim + compact tool box & conduit riser tucked west of the ladder.
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.62, 0.03, 0.12)), Vector3(0.0, 0.02, 1.02), caution_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.64, 0.46, 0.50)), Vector3(-1.45, 0.23, 0.15), steel_mat))
	root.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.68, 0.07, 0.54)), Vector3(-1.45, 0.46, 0.15), caution_mat))
	root.add_child(TunnelLook.part(TunnelLook.cylinder(0.09, wall_height_m - 0.4), Vector3(-1.15, (wall_height_m - 0.4) * 0.5, -0.45), warm_pipe_mat))
	return root
