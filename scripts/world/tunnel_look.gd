class_name TunnelLook
extends RefCounted
## Shared colours, cached materials, and primitive-mesh builders for Lava Tubes
## hub and depth props (LavaHubProps, ZoneDepthProps), inspired by Ryan's tunnel
## concept art (support-beam arch, cave-in rubble, packed regolith, basalt, ice
## seam, ore vein). Uses ScopeTheme colours only; every colour and size below is
## a [PLACEHOLDER].

## Palette derived from ScopeTheme (no raw hex literals) [PLACEHOLDER].
const BASALT_DARK: Color = ScopeTheme.SHADOW
const BASALT_MID: Color = ScopeTheme.GLASS_LINE
const STEEL: Color = ScopeTheme.INK_DIM
const TIMBER: Color = ScopeTheme.CARD_INK_MUTED
const TIMBER_LIGHT: Color = ScopeTheme.ENAMEL_LIP
const BRASS: Color = ScopeTheme.AMBER
const REGOLITH: Color = ScopeTheme.TERRA
const REGOLITH_DARK: Color = ScopeTheme.TERRA_DARK
const ICE: Color = ScopeTheme.INK
const CREAM: Color = ScopeTheme.ENAMEL_TOP
const CRYSTAL: Color = ScopeTheme.TEAL
const BROKEN_RED: Color = ScopeTheme.RED

## Shared material defaults [PLACEHOLDER].
const MATTE_ROUGHNESS: float = 0.9
const LABEL_PIXEL_SIZE: float = 0.01
const LABEL_FONT_SIZE: int = 32
## Support-beam arch default proportions, in metres [PLACEHOLDER].
const ARCH_POST_W: float = 0.24
const ARCH_FOOT_W: float = 0.44
const ARCH_FOOT_H: float = 0.14
const ARCH_LINTEL_H: float = 0.28
const ARCH_LINTEL_D: float = 0.30
const ARCH_BRACE_SIZE: float = 0.22
const ARCH_GUSSET_SIZE := Vector3(0.30, 0.24, 0.34)

## Cached shared materials so props allocate no per-frame or duplicate materials.
static var _flat_cache: Dictionary = {}
static var _glow_cache: Dictionary = {}


static func quartz_base_color() -> Color:
	return CRYSTAL.darkened(0.45)


static func vent_hot_color() -> Color:
	return REGOLITH.lightened(0.15)


## Cached flat-matte StandardMaterial3D for `color`.
static func flat_mat(color: Color) -> StandardMaterial3D:
	if _flat_cache.has(color):
		return _flat_cache[color] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = MATTE_ROUGHNESS
	_flat_cache[color] = material
	return material


## Emissive StandardMaterial3D for `color` and `energy`. Pass `shared = false`
## when a caller animates emission_energy_multiplier per instance (e.g. vents).
static func glow_mat(color: Color, energy: float, shared: bool = true) -> StandardMaterial3D:
	var key: String = "%s|%.3f" % [color.to_html(false), energy]
	if shared and _glow_cache.has(key):
		return _glow_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if shared:
		_glow_cache[key] = material
	return material


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func part(mesh: Mesh, at: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rot_deg
	node.material_override = material
	return node


static func label(text: String, at: Vector3, color: Color = CRYSTAL) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = at
	node.pixel_size = LABEL_PIXEL_SIZE
	node.font_size = LABEL_FONT_SIZE
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.modulate = color
	return node


## Builds a chunky steel-post, timber-lintel, stepped knee-brace and brass-gusset
## tunnel support arch (visual only, no collision) [PLACEHOLDER].
static func add_support_arch(parent: Node3D, at: Vector3, span_m: float, height_m: float, rot_y_deg: float = 0.0) -> Node3D:
	var arch := Node3D.new()
	arch.name = &"SupportArch"
	arch.position = at
	arch.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var half: float = span_m * 0.5
	var post_mat: Material = flat_mat(BASALT_MID)
	var foot_mat: Material = flat_mat(BASALT_DARK)
	var wood_mat: Material = flat_mat(TIMBER)
	var brass_mat: Material = flat_mat(BRASS)

	for side: int in [-1, 1]:
		var x: float = half * side
		arch.add_child(part(box(Vector3(ARCH_FOOT_W, ARCH_FOOT_H, ARCH_FOOT_W)), Vector3(x, ARCH_FOOT_H * 0.5, 0.0), foot_mat))
		arch.add_child(part(box(Vector3(ARCH_POST_W, height_m, ARCH_POST_W)), Vector3(x, height_m * 0.5, 0.0), post_mat))
		# Brass upper & knee gussets + stepped diagonal timber brace.
		arch.add_child(part(box(ARCH_GUSSET_SIZE), Vector3(x, height_m - 0.14, 0.0), brass_mat))
		arch.add_child(part(box(Vector3(ARCH_BRACE_SIZE, ARCH_BRACE_SIZE, ARCH_BRACE_SIZE)), Vector3(x - 0.24 * side, height_m - 0.36, 0.0), wood_mat))
		arch.add_child(part(box(Vector3(ARCH_BRACE_SIZE, ARCH_BRACE_SIZE, ARCH_BRACE_SIZE)), Vector3(x - 0.44 * side, height_m - 0.18, 0.0), wood_mat))
		arch.add_child(part(box(Vector3(ARCH_GUSSET_SIZE.x * 0.85, ARCH_GUSSET_SIZE.y * 0.75, ARCH_GUSSET_SIZE.z * 0.9)), Vector3(x, height_m - 0.56, 0.0), brass_mat))

	arch.add_child(part(box(Vector3(span_m + ARCH_POST_W * 1.4, ARCH_LINTEL_H, ARCH_LINTEL_D)), Vector3(0.0, height_m + ARCH_LINTEL_H * 0.35, 0.0), wood_mat))
	parent.add_child(arch)
	return arch


## Builds a compact cave-in rubble pile (basalt boulders, packed regolith scree,
## splintered timber chunk, and a bent brass bracket; visual only) [PLACEHOLDER].
static func add_rubble_pile(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> Node3D:
	var pile := Node3D.new()
	pile.name = &"RubblePile"
	pile.position = at
	pile.scale = Vector3.ONE * scale_factor
	var rock_dark: Material = flat_mat(BASALT_DARK)
	var rock_mid: Material = flat_mat(BASALT_MID)
	var scree: Material = flat_mat(REGOLITH_DARK)
	var dust: Material = flat_mat(REGOLITH)
	var wood: Material = flat_mat(TIMBER)
	var brass: Material = flat_mat(BRASS)

	pile.add_child(part(box(Vector3(1.1, 0.18, 0.95)), Vector3(0.0, 0.09, 0.0), scree))
	pile.add_child(part(box(Vector3(0.72, 0.22, 0.65)), Vector3(0.12, 0.18, 0.06), dust))
	pile.add_child(part(box(Vector3(0.46, 0.44, 0.42)), Vector3(-0.18, 0.28, -0.08), rock_mid, Vector3(6.0, 18.0, -5.0)))
	pile.add_child(part(box(Vector3(0.38, 0.34, 0.36)), Vector3(0.26, 0.22, 0.14), rock_dark, Vector3(-8.0, -24.0, 6.0)))
	pile.add_child(part(box(Vector3(0.32, 0.28, 0.30)), Vector3(0.02, 0.44, -0.02), rock_mid, Vector3(12.0, 32.0, 4.0)))
	pile.add_child(part(box(Vector3(0.16, 0.72, 0.16)), Vector3(-0.28, 0.34, 0.18), wood, Vector3(16.0, 20.0, 34.0)))
	pile.add_child(part(box(Vector3(0.14, 0.54, 0.14)), Vector3(0.32, 0.28, -0.18), wood, Vector3(-14.0, -15.0, -28.0)))
	pile.add_child(part(box(Vector3(0.24, 0.08, 0.12)), Vector3(0.14, 0.30, 0.22), brass, Vector3(10.0, 25.0, -14.0)))
	parent.add_child(pile)
	return pile
