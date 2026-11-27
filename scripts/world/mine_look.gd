class_name MineLook
extends RefCounted
## Shared colours, cached read-only materials, deterministic coordinate hash,
## and primitive-mesh builders for the Abandoned Colony Mine (ColonyMine,
## MineRock). Reuses TunnelLook primitive helpers; static functions only; every
## colour, size, and hash choice is a [PLACEHOLDER].

## Ore-stained rock, old timber, rusted steel, and faded stencil palette [PLACEHOLDER].
const ROCK_TINT := Color(0.96, 0.72, 0.56)
const ROCK_ROUGHNESS: float = 0.96
const ORE_RUST := Color(0.54, 0.24, 0.14)
const ORE_OCHRE := Color(0.68, 0.44, 0.19)
const ORE_DARK := Color(0.32, 0.16, 0.11)
const ARCH_STONE := Color(0.30, 0.18, 0.14)

const TIMBER_OLD := Color(0.34, 0.23, 0.15)
const TIMBER_AGED := Color(0.25, 0.17, 0.12)
const TIMBER_SPLIT := Color(0.45, 0.32, 0.20)

const RAIL_STEEL := Color(0.44, 0.43, 0.44)
const RUST_IRON := Color(0.42, 0.22, 0.13)
const IRON_DARK := Color(0.18, 0.15, 0.14)

const LAMP_GLASS := Color(0.36, 0.34, 0.30)
const LAMP_BRASS := Color(0.52, 0.40, 0.20)

const STENCIL_BOARD := Color(0.29, 0.25, 0.20)
const STENCIL_CREAM := Color(0.76, 0.70, 0.56)
const STENCIL_BAND := Color(0.62, 0.30, 0.16)

const CRATE_BODY := Color(0.42, 0.26, 0.16)
const CRATE_LABEL: Color = ScopeTheme.AMBER

## Timber set, rail track, lamp, and sign proportions, in metres [PLACEHOLDER].
const TIMBER_POST_W: float = 0.26
const TIMBER_FOOT_W: float = 0.42
const TIMBER_FOOT_H: float = 0.14
const TIMBER_CAP_H: float = 0.28
const TIMBER_CAP_D: float = 0.30
const TIMBER_LAGGING_H: float = 0.08

const RAIL_GAUGE_M: float = 0.90
const RAIL_HEIGHT_M: float = 0.045
const RAIL_WIDTH_M: float = 0.06
const SLEEPER_STEP_M: float = 0.75
const SLEEPER_LENGTH_M: float = 1.48
const SLEEPER_HEIGHT_M: float = 0.03
const SLEEPER_WIDTH_M: float = 0.16

const LAMP_DEFAULT_DROP_M: float = 0.45
const SIGN_WIDTH_M: float = 1.65
const SIGN_HEIGHT_M: float = 0.92

## Cached read-only flat-matte materials isolated from TunnelLook's cache.
static var _flat_cache: Dictionary = {}


## Deterministic integer hash from coordinates and salt (no global RNG) [PLACEHOLDER].
static func hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## Cached flat-matte StandardMaterial3D for `color` and `roughness` [PLACEHOLDER].
static func flat_mat(color: Color, roughness: float = TunnelLook.MATTE_ROUGHNESS) -> StandardMaterial3D:
	var key: String = "%s|%.2f" % [color.to_html(false), roughness]
	if _flat_cache.has(key):
		return _flat_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_flat_cache[key] = material
	return material


## Old mine timber set: twin posts with iron shoes, overhead cap beam, lagging
## planks, angled knee braces, rusted iron tie-plates, and optional dead hanging
## lamp (visual only, no collision) [PLACEHOLDER].
static func add_timber_set(parent: Node3D, at: Vector3, span_m: float, height_m: float, rot_y_deg: float = 0.0, with_lamp: bool = false) -> Node3D:
	var frame := Node3D.new()
	frame.name = &"TimberSet"
	frame.position = at
	frame.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var half: float = span_m * 0.5
	var wood_mat: Material = flat_mat(TIMBER_OLD)
	var aged_mat: Material = flat_mat(TIMBER_AGED)
	var split_mat: Material = flat_mat(TIMBER_SPLIT)
	var iron_mat: Material = flat_mat(IRON_DARK)
	var rust_mat: Material = flat_mat(RUST_IRON)

	for side: int in [-1, 1]:
		var x: float = half * float(side)
		frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_FOOT_W, TIMBER_FOOT_H, TIMBER_FOOT_W)),
				Vector3(x, TIMBER_FOOT_H * 0.5, 0.0), iron_mat))
		frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_POST_W, height_m, TIMBER_POST_W)),
				Vector3(x, height_m * 0.5, 0.0), wood_mat))
		# Rusted iron collar plates and diagonal knee brace.
		frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_POST_W + 0.06, 0.18, TIMBER_CAP_D + 0.04)),
				Vector3(x, height_m - 0.12, 0.0), rust_mat))
		frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.18, 0.78, 0.18)),
				Vector3(x - 0.34 * float(side), height_m - 0.32, 0.0), aged_mat, Vector3(0.0, 0.0, 42.0 * float(side))))
		frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_POST_W + 0.05, 0.14, TIMBER_POST_W + 0.05)),
				Vector3(x, height_m - 0.62, 0.0), rust_mat))

	# Heavy cap beam + three overhead lagging planks.
	var cap_y: float = height_m + TIMBER_CAP_H * 0.35
	frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(span_m + TIMBER_POST_W * 1.6, TIMBER_CAP_H, TIMBER_CAP_D)),
			Vector3(0.0, cap_y, 0.0), wood_mat))
	for z_off: float in [-0.24, 0.0, 0.24]:
		var plank_mat: Material = split_mat if z_off == 0.0 else aged_mat
		frame.add_child(TunnelLook.part(TunnelLook.box(Vector3(span_m + 0.20, TIMBER_LAGGING_H, 0.16)),
				Vector3(0.0, cap_y + TIMBER_CAP_H * 0.5 + TIMBER_LAGGING_H * 0.5, z_off), plank_mat))

	if with_lamp:
		add_dead_lamp(frame, Vector3(0.0, cap_y - TIMBER_CAP_H * 0.5, 0.0), LAMP_DEFAULT_DROP_M)

	parent.add_child(frame, true)
	return frame


## Short abandoned steel rail track with timber sleepers and rusted tie plates
## flush to the floor (visual only, no collision) [PLACEHOLDER].
static func add_rail_track(parent: Node3D, at: Vector3, length_m: float, rot_y_deg: float = 0.0, broken_end: bool = false) -> Node3D:
	var track := Node3D.new()
	track.name = &"RailTrack"
	track.position = at
	track.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var rail_mat: Material = flat_mat(RAIL_STEEL, 0.65)
	var rust_mat: Material = flat_mat(RUST_IRON)
	var wood_mat: Material = flat_mat(TIMBER_AGED)
	var old_mat: Material = flat_mat(TIMBER_OLD)

	var sleepers: int = maxi(int(floor(length_m / SLEEPER_STEP_M)), 2)
	var start_z: float = -length_m * 0.5 + SLEEPER_STEP_M * 0.5
	for i: int in sleepers:
		var z: float = start_z + float(i) * SLEEPER_STEP_M
		if z > length_m * 0.5:
			break
		var h: int = hash_int(i, roundi(at.x + at.z), 17)
		var yaw: float = float(h % 5 - 2) * 1.4
		if broken_end and i == sleepers - 1:
			yaw = 14.0
		track.add_child(TunnelLook.part(TunnelLook.box(Vector3(SLEEPER_LENGTH_M, SLEEPER_HEIGHT_M, SLEEPER_WIDTH_M)),
				Vector3(0.0, SLEEPER_HEIGHT_M * 0.5, z), wood_mat if i % 2 == 0 else old_mat, Vector3(0.0, yaw, 0.0)))
		for side: float in [-1.0, 1.0]:
			track.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.016, 0.14)),
					Vector3(side * RAIL_GAUGE_M * 0.5, SLEEPER_HEIGHT_M + 0.008, z), rust_mat))

	var rail_len: float = length_m - (0.65 if broken_end else 0.0)
	var rail_z: float = -0.32 if broken_end else 0.0
	var rail_y: float = SLEEPER_HEIGHT_M + RAIL_HEIGHT_M * 0.5
	for side: float in [-1.0, 1.0]:
		var rx: float = side * RAIL_GAUGE_M * 0.5
		track.add_child(TunnelLook.part(TunnelLook.box(Vector3(RAIL_WIDTH_M, RAIL_HEIGHT_M, rail_len)),
				Vector3(rx, rail_y, rail_z), rail_mat))
		track.add_child(TunnelLook.part(TunnelLook.box(Vector3(RAIL_WIDTH_M + 0.03, 0.015, rail_len)),
				Vector3(rx, SLEEPER_HEIGHT_M + 0.01, rail_z), rust_mat))

	if broken_end:
		# One bent rail stub sticking up slightly at the abandoned end.
		track.add_child(TunnelLook.part(TunnelLook.box(Vector3(RAIL_WIDTH_M, RAIL_HEIGHT_M, 0.72)),
				Vector3(RAIL_GAUGE_M * 0.5 + 0.08, rail_y + 0.05, length_m * 0.5 - 0.34), rail_mat, Vector3(-12.0, 16.0, 0.0)))

	parent.add_child(track, true)
	return track


## Dead hanging mine lamp: iron ceiling hook, drop rod, soot-dark reflector
## hood, tarnished brass cage, and dusty unlit globe (no light, no emission,
## visual only) [PLACEHOLDER].
static func add_dead_lamp(parent: Node3D, at: Vector3, drop_m: float = LAMP_DEFAULT_DROP_M) -> Node3D:
	var lamp := Node3D.new()
	lamp.name = &"DeadLamp"
	lamp.position = at
	var iron_mat: Material = flat_mat(IRON_DARK)
	var rust_mat: Material = flat_mat(RUST_IRON)
	var brass_mat: Material = flat_mat(LAMP_BRASS, 0.7)
	var glass_mat: Material = flat_mat(LAMP_GLASS, 0.6)

	# Ceiling bracket + drop rod.
	lamp.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.05, 0.16)), Vector3(0.0, -0.025, 0.0), rust_mat))
	lamp.add_child(TunnelLook.part(TunnelLook.cylinder(0.025, drop_m), Vector3(0.0, -drop_m * 0.5, 0.0), iron_mat))
	# Reflector shade + brass collar + dead glass globe + bottom guard.
	var hood_y: float = -drop_m
	lamp.add_child(TunnelLook.part(TunnelLook.cylinder(0.24, 0.06), Vector3(0.0, hood_y, 0.0), iron_mat))
	lamp.add_child(TunnelLook.part(TunnelLook.cylinder(0.14, 0.08), Vector3(0.0, hood_y - 0.05, 0.0), brass_mat))
	lamp.add_child(TunnelLook.part(TunnelLook.sphere(0.11), Vector3(0.0, hood_y - 0.16, 0.0), glass_mat))
	lamp.add_child(TunnelLook.part(TunnelLook.cylinder(0.08, 0.04), Vector3(0.0, hood_y - 0.27, 0.0), rust_mat))

	parent.add_child(lamp, true)
	return lamp


## Faded colony stencil sign: weathered steel plate on rusted posts with a
## rust-orange header band and faded cream stencil lettering (visual only,
## no collision) [PLACEHOLDER].
static func add_stencil_sign(parent: Node3D, at: Vector3, title: String = "COLONY MINE 01", subtitle: String = "ORE DRIFT // KEEP CLEAR", rot_y_deg: float = 0.0) -> Node3D:
	var sign_node := Node3D.new()
	sign_node.name = &"StencilSign"
	sign_node.position = at
	sign_node.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var board_mat: Material = flat_mat(STENCIL_BOARD)
	var band_mat: Material = flat_mat(STENCIL_BAND)
	var cream_mat: Material = flat_mat(STENCIL_CREAM)
	var rust_mat: Material = flat_mat(RUST_IRON)
	var iron_mat: Material = flat_mat(IRON_DARK)

	var post_x: float = SIGN_WIDTH_M * 0.42
	for sx: float in [-post_x, post_x]:
		sign_node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.18, 0.08, 0.18)), Vector3(sx, 0.04, 0.0), iron_mat))
		sign_node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.09, 1.85, 0.09)), Vector3(sx, 0.94, 0.0), rust_mat))

	var panel_y: float = 1.42
	sign_node.add_child(TunnelLook.part(TunnelLook.box(Vector3(SIGN_WIDTH_M, SIGN_HEIGHT_M, 0.06)),
			Vector3(0.0, panel_y, 0.04), board_mat))
	sign_node.add_child(TunnelLook.part(TunnelLook.box(Vector3(SIGN_WIDTH_M - 0.08, 0.16, 0.02)),
			Vector3(0.0, panel_y + SIGN_HEIGHT_M * 0.34, 0.075), band_mat))
	sign_node.add_child(TunnelLook.part(TunnelLook.box(Vector3(SIGN_WIDTH_M - 0.14, 0.04, 0.02)),
			Vector3(0.0, panel_y - SIGN_HEIGHT_M * 0.34, 0.075), cream_mat))
	for rx: float in [-SIGN_WIDTH_M * 0.44, SIGN_WIDTH_M * 0.44]:
		for ry: float in [-SIGN_HEIGHT_M * 0.38, SIGN_HEIGHT_M * 0.38]:
			sign_node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.06, 0.06, 0.04)),
					Vector3(rx, panel_y + ry, 0.075), rust_mat))

	var title_lbl := Label3D.new()
	title_lbl.name = &"StencilTitle"
	title_lbl.text = title
	title_lbl.position = Vector3(0.0, panel_y + 0.05, 0.09)
	title_lbl.pixel_size = 0.0065
	title_lbl.font_size = 28
	title_lbl.modulate = STENCIL_CREAM
	sign_node.add_child(title_lbl)

	var sub_lbl := Label3D.new()
	sub_lbl.name = &"StencilSub"
	sub_lbl.text = subtitle
	sub_lbl.position = Vector3(0.0, panel_y - 0.16, 0.09)
	sub_lbl.pixel_size = 0.0052
	sub_lbl.font_size = 22
	sub_lbl.modulate = STENCIL_CREAM.darkened(0.15)
	sign_node.add_child(sub_lbl)

	parent.add_child(sign_node, true)
	return sign_node


## Restyled mine cave-in rubble pile: rust-red and ochre ore-stained boulders,
## dark ironstone scree, shattered mine timber beams, and bent rail/iron scrap
## (visual only, no collision) [PLACEHOLDER].
static func add_mine_rubble(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> Node3D:
	var pile := Node3D.new()
	pile.name = &"RubblePile"
	pile.position = at
	pile.scale = Vector3.ONE * scale_factor
	var rust_mat: Material = flat_mat(ORE_RUST)
	var ochre_mat: Material = flat_mat(ORE_OCHRE)
	var dark_mat: Material = flat_mat(ORE_DARK)
	var wood_mat: Material = flat_mat(TIMBER_OLD)
	var split_mat: Material = flat_mat(TIMBER_SPLIT)
	var iron_mat: Material = flat_mat(RUST_IRON)
	var rail_mat: Material = flat_mat(RAIL_STEEL, 0.65)

	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.16, 0.18, 1.00)), Vector3(0.0, 0.09, 0.0), dark_mat))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.76, 0.22, 0.68)), Vector3(0.12, 0.18, 0.06), rust_mat))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.48, 0.44, 0.44)), Vector3(-0.18, 0.28, -0.08), rust_mat, Vector3(6.0, 18.0, -5.0)))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.40, 0.34, 0.38)), Vector3(0.26, 0.22, 0.14), ochre_mat, Vector3(-8.0, -24.0, 6.0)))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.34, 0.30, 0.30)), Vector3(0.02, 0.46, -0.02), dark_mat, Vector3(12.0, 32.0, 4.0)))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.20, 0.22)), Vector3(-0.34, 0.18, 0.22), ochre_mat, Vector3(-5.0, 14.0, 10.0)))
	# Splintered old timber set beams & bent mine rail chunk.
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.78, 0.16)), Vector3(-0.28, 0.36, 0.18), wood_mat, Vector3(16.0, 20.0, 34.0)))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.56, 0.14)), Vector3(0.32, 0.28, -0.18), split_mat, Vector3(-14.0, -15.0, -28.0)))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.08, 0.06, 0.68)), Vector3(0.16, 0.30, 0.20), rail_mat, Vector3(18.0, 28.0, -16.0)))
	pile.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.08, 0.12)), Vector3(-0.08, 0.32, 0.26), iron_mat, Vector3(10.0, -20.0, 12.0)))
	parent.add_child(pile, true)
	return pile


## Restyled shored-room support arch: heavy freshly-wedged mine timber set with
## iron foot shoes, double cap beam, overhead lagging, diagonal knee struts, and
## rusted/amber iron gusset plates (visual only, no collision) [PLACEHOLDER].
static func add_shored_arch(parent: Node3D, at: Vector3, span_m: float, height_m: float, rot_y_deg: float = 0.0) -> Node3D:
	var arch := Node3D.new()
	arch.name = &"SupportArch"
	arch.position = at
	arch.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var half: float = span_m * 0.5
	var wood_mat: Material = flat_mat(TIMBER_OLD)
	var fresh_mat: Material = flat_mat(TIMBER_SPLIT)
	var iron_mat: Material = flat_mat(IRON_DARK)
	var rust_mat: Material = flat_mat(RUST_IRON)
	var wedge_mat: Material = flat_mat(ORE_OCHRE)

	for side: int in [-1, 1]:
		var x: float = half * float(side)
		arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_FOOT_W, TIMBER_FOOT_H, TIMBER_FOOT_W)),
				Vector3(x, TIMBER_FOOT_H * 0.5, 0.0), iron_mat))
		arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_POST_W, height_m, TIMBER_POST_W)),
				Vector3(x, height_m * 0.5, 0.0), wood_mat))
		# Wedged iron collar & fresh-cut diagonal timber knee brace.
		arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(TIMBER_POST_W + 0.08, 0.20, TIMBER_CAP_D + 0.06)),
				Vector3(x, height_m - 0.14, 0.0), rust_mat))
		arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.20, 0.72, 0.20)),
				Vector3(x - 0.30 * float(side), height_m - 0.30, 0.0), fresh_mat, Vector3(0.0, 0.0, 42.0 * float(side))))
		arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.18, 0.12, 0.26)),
				Vector3(x, height_m + TIMBER_CAP_H * 0.85, 0.0), wedge_mat))

	# Double timber cap beam & overhead lagging planks.
	var cap_y: float = height_m + TIMBER_CAP_H * 0.35
	arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(span_m + TIMBER_POST_W * 1.5, TIMBER_CAP_H, TIMBER_CAP_D)),
			Vector3(0.0, cap_y, 0.0), fresh_mat))
	for z_off: float in [-0.22, 0.22]:
		arch.add_child(TunnelLook.part(TunnelLook.box(Vector3(span_m + 0.15, TIMBER_LAGGING_H, 0.14)),
				Vector3(0.0, cap_y + TIMBER_CAP_H * 0.5 + TIMBER_LAGGING_H * 0.5, z_off), wood_mat))

	parent.add_child(arch, true)
	return arch


## Restyled hub PropCrate: weathered timber pallet, ochre-brown plank crate
## bound in rusted iron straps, faded stencil front plate, stacked shoring
## timbers and wedges on top, and label (visual only, no collision) [PLACEHOLDER].
static func build_prop_crate(at: Vector3) -> Node3D:
	var crate := Node3D.new()
	crate.name = "PropCrate"
	crate.position = at
	var iron_mat: Material = flat_mat(IRON_DARK)
	var rust_mat: Material = flat_mat(RUST_IRON)
	var body_mat: Material = flat_mat(CRATE_BODY)
	var wood_mat: Material = flat_mat(TIMBER_OLD)
	var aged_mat: Material = flat_mat(TIMBER_AGED)
	var split_mat: Material = flat_mat(TIMBER_SPLIT)
	var stencil_mat: Material = flat_mat(STENCIL_CREAM)
	var wedge_mat: Material = flat_mat(ORE_OCHRE)

	# Heavy pallet runners & deck planks.
	for z_off: float in [-0.36, 0.36]:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.40, 0.08, 0.16)), Vector3(0.0, 0.04, z_off), iron_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.44, 0.06, 1.06)), Vector3(0.0, 0.11, 0.0), aged_mat))

	# Planked crate box + rusted iron corner posts & mid strap + faded stencil badge.
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.18, 0.64, 0.86)), Vector3(0.0, 0.46, 0.0), body_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.22, 0.08, 0.90)), Vector3(0.0, 0.46, 0.0), rust_mat))
	for sx: float in [-0.58, 0.58]:
		for sz: float in [-0.42, 0.42]:
			crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.11, 0.72, 0.11)), Vector3(sx, 0.47, sz), rust_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.56, 0.22, 0.03)), Vector3(0.0, 0.52, 0.44), flat_mat(STENCIL_BOARD)))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.42, 0.06, 0.04)), Vector3(0.0, 0.55, 0.445), stencil_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.30, 0.04, 0.04)), Vector3(-0.04, 0.46, 0.445), stencil_mat))

	# Spare shoring posts and timber wedges strapped across the top.
	for i: int in 3:
		var post_mat: Material = split_mat if i == 1 else wood_mat
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.15, 0.15, 1.16)),
				Vector3(-0.36 + 0.36 * float(i), 0.88, 0.0), post_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.14, 0.05, 0.12)), Vector3(0.0, 0.98, 0.0), rust_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.22, 0.10, 0.18)), Vector3(0.34, 1.00, 0.28), wedge_mat, Vector3(0.0, 18.0, 0.0)))

	crate.add_child(TunnelLook.label("PROP CRATE", Vector3(0.0, 1.55, 0.0), CRATE_LABEL))
	return crate


## Adds weathered mine timber cap and rusted iron footplates to NoticeSign
## without altering its base structure or label [PLACEHOLDER].
static func add_sign_trim(board: Node3D) -> void:
	var rust_mat: Material = flat_mat(RUST_IRON)
	var wood_mat: Material = flat_mat(TIMBER_OLD)
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.14, 0.05, 0.24)), Vector3(0.0, 1.74, 0.0), wood_mat))
	for x: float in [-0.82, 0.82]:
		board.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.34, 0.04, 0.34)), Vector3(x, 0.02, 0.0), rust_mat))
