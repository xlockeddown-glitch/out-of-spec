class_name IceLook
extends RefCounted
## The Polar Ice Caves' look (feat/ice-look): named polar-ice palette constants,
## fresh (uncached) glossy/translucent ice materials, deterministic coordinate
## hash, and primitive-mesh builders for layered ice walls, hanging icicles,
## floor frost patches, a half-buried frozen probe, an ice-core drill rack, and
## a frosted heater crate with a warm glow. Never mutates TunnelLook's cached
## materials. Every colour, size, and hash choice is a [PLACEHOLDER].

## Glacial ice, layered strata, frost, probe, drill rack, and heater palette [PLACEHOLDER].
const ICE_PALE := Color(0.84, 0.92, 0.96)
const ICE_BLUE := Color(0.62, 0.78, 0.88)
const ICE_DEEP := Color(0.38, 0.56, 0.72)
const ICE_DUST := Color(0.72, 0.76, 0.80)
const HEATER_ORANGE := Color(0.90, 0.46, 0.16)
## The layered bands of an ice wall, from the floor up.
const BANDS: Array[Color] = [ICE_DEEP, ICE_BLUE, ICE_PALE, ICE_DUST, ICE_PALE]

const ROCK_TINT := Color(0.76, 0.90, 1.0)
const ROCK_ROUGHNESS: float = 0.28
const ICE_GLOSS_ROUGHNESS: float = 0.18
const ICE_METALLIC: float = 0.08
const ICE_RIM: float = 0.45
const ICE_ALPHA: float = 0.82
const FROST_ALPHA: float = 0.76

const FROST_WHITE := Color(0.90, 0.96, 1.0)
const GLACIER_CYAN := Color(0.46, 0.82, 0.94)
const STRATA_DARK := Color(0.24, 0.38, 0.52)
const STRATA_SILT := Color(0.56, 0.62, 0.68)
const ARCH_ICE := Color(0.34, 0.52, 0.68)
const ARCH_RIB_FROST := Color(0.64, 0.76, 0.86)

const PROBE_HULL := Color(0.78, 0.82, 0.86)
const PROBE_DARK := Color(0.20, 0.25, 0.32)
const PROBE_GOLD := Color(0.78, 0.62, 0.24)
const PROBE_LENS := Color(0.36, 0.86, 0.96)

const DRILL_STEEL := Color(0.42, 0.48, 0.54)
const DRILL_DARK := Color(0.22, 0.26, 0.32)
const DRILL_TUBE := Color(0.82, 0.93, 0.98)

const HEATER_BODY := Color(0.54, 0.62, 0.70)
const HEATER_STEEL := Color(0.30, 0.36, 0.42)
const HEATER_GLOW := Color(1.0, 0.56, 0.20)
const HEATER_LIGHT_ENERGY: float = 0.9
const HEATER_LIGHT_RANGE_M: float = 6.0

## Default prop proportions, in metres [PLACEHOLDER].
const ICICLE_COUNT_DEFAULT: int = 5
const ICICLE_CORNICE_H: float = 0.12
const FROST_SLAB_H: float = 0.025
const DRILL_RACK_W: float = 1.65
const DRILL_RACK_H: float = 1.75


## Deterministic integer hash from coordinates and salt (no global RNG) [PLACEHOLDER].
static func hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## Fresh (uncached) glossy/translucent ice StandardMaterial3D [PLACEHOLDER].
static func ice_mat(color: Color, roughness: float = ICE_GLOSS_ROUGHNESS, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = roughness
	material.metallic = ICE_METALLIC
	material.rim_enabled = true
	material.rim = ICE_RIM
	material.rim_tint = 0.5
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return material


## Fresh (uncached) matte StandardMaterial3D for non-ice hardware [PLACEHOLDER].
static func matte_mat(color: Color, roughness: float = TunnelLook.MATTE_ROUGHNESS) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## Fresh (uncached) emissive StandardMaterial3D [PLACEHOLDER].
static func glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _cone(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


## An ice wall: a stack of glossy layered strata bands, each a little shifted,
## `size` wide and deep and `height` tall in all, standing on the floor at `at`
## (relative to `parent`). Keeps exactly BANDS.size() direct children on
## IceWall (visual only, no collision) [PLACEHOLDER].
static func add_ice_wall(parent: Node3D, at: Vector3, size: Vector2, height: float) -> Node3D:
	var wall := Node3D.new()
	wall.name = "IceWall"
	wall.position = at
	parent.add_child(wall)
	var band_h: float = height / float(BANDS.size())
	for index: int in BANDS.size():
		var shift: float = 0.12 * float(index % 2)
		var w: float = size.x - shift
		var d: float = size.y - shift
		var alpha: float = ICE_ALPHA if index == 1 or index == 2 else 1.0
		var rough: float = 0.42 if BANDS[index] == ICE_DUST else ICE_GLOSS_ROUGHNESS
		var band: MeshInstance3D = TunnelLook.part(
			TunnelLook.box(Vector3(w, band_h, d)),
			Vector3(shift * 0.5, band_h * (float(index) + 0.5), 0.0),
			ice_mat(BANDS[index], rough, alpha)
		)
		# Thin frost seam accent tucked inside each band (child of band, so wall child count stays BANDS.size()).
		if index > 0:
			var seam_col: Color = FROST_WHITE if index % 2 == 0 else GLACIER_CYAN
			band.add_child(TunnelLook.part(
				TunnelLook.box(Vector3(w + 0.05, 0.045, d + 0.05)),
				Vector3(0.0, -band_h * 0.48, 0.0),
				ice_mat(seam_col, 0.24, 0.9)
			))
		if index == BANDS.size() - 1:
			band.add_child(TunnelLook.part(
				TunnelLook.box(Vector3(w + 0.08, 0.07, d + 0.08)),
				Vector3(0.0, band_h * 0.5 + 0.02, 0.0),
				ice_mat(FROST_WHITE, 0.32, 1.0)
			))
		wall.add_child(band)
	return wall


## Hanging icicle cluster anchored at `at` (hanging downward in -Y), with a
## frosted ice cornice and deterministically staggered translucent cones
## (visual only, no collision) [PLACEHOLDER].
static func add_icicle_cluster(parent: Node3D, at: Vector3, width_m: float = 2.2, max_drop_m: float = 0.95, rot_y_deg: float = 0.0) -> Node3D:
	var cluster := Node3D.new()
	cluster.name = &"IcicleCluster"
	cluster.position = at
	cluster.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var cornice_mat: Material = ice_mat(FROST_WHITE, 0.30, 0.92)
	var icicle_mat: Material = ice_mat(ICE_PALE, ICE_GLOSS_ROUGHNESS, ICE_ALPHA)
	var deep_mat: Material = ice_mat(GLACIER_CYAN, ICE_GLOSS_ROUGHNESS, ICE_ALPHA)

	cluster.add_child(TunnelLook.part(
		TunnelLook.box(Vector3(width_m, ICICLE_CORNICE_H, 0.26)),
		Vector3(0.0, -ICICLE_CORNICE_H * 0.5, 0.0),
		cornice_mat
	))

	var count: int = maxi(ICICLE_COUNT_DEFAULT, int(round(width_m / 0.42)))
	var span: float = maxf(width_m - 0.28, 0.4)
	for i: int in count:
		var h: int = hash_int(i + roundi(at.x * 3.0), roundi(at.z * 3.0), 71 + i)
		var frac: float = float(h % 100) / 100.0
		var t: float = float(i) / float(maxi(count - 1, 1)) - 0.5
		var x: float = t * span
		var z_off: float = ((float((h / 7) % 11) / 10.0) - 0.5) * 0.14
		var drop: float = max_drop_m * (0.42 + 0.58 * frac)
		var top_r: float = 0.045 + 0.045 * frac
		var mat: Material = deep_mat if i % 3 == 0 else icicle_mat
		cluster.add_child(TunnelLook.part(
			_cone(top_r, 0.012, drop),
			Vector3(x, -ICICLE_CORNICE_H - drop * 0.5, z_off),
			mat
		))

	parent.add_child(cluster, true)
	return cluster


## A slick cell: one glassy cyan slab, a little under a cell, flush to the floor (visual only,
## no collision) [PLACEHOLDER].
static func add_slick_patch(parent: Node3D, at: Vector3) -> Node3D:
	var patch := Node3D.new()
	patch.name = &"SlickPatch"
	patch.position = at
	patch.add_child(TunnelLook.part(
		TunnelLook.box(Vector3(2.7, 0.03, 2.7)),
		Vector3(0.0, 0.015, 0.0),
		ice_mat(GLACIER_CYAN, 0.06, 0.6)
	))
	parent.add_child(patch, true)
	return patch


## Thin glazed frost & rime patch flush to the floor (visual only, no
## collision, safe for the rover to drive over) [PLACEHOLDER].
static func add_frost_patch(parent: Node3D, at: Vector3, size: Vector2, rot_y_deg: float = 0.0) -> Node3D:
	var patch := Node3D.new()
	patch.name = &"FrostPatch"
	patch.position = at
	patch.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var glaze_mat: Material = ice_mat(ICE_PALE, 0.14, FROST_ALPHA)
	var blue_mat: Material = ice_mat(ICE_BLUE, 0.16, FROST_ALPHA)
	var rime_mat: Material = ice_mat(FROST_WHITE, 0.36, 0.88)

	patch.add_child(TunnelLook.part(
		TunnelLook.box(Vector3(size.x, FROST_SLAB_H, size.y)),
		Vector3(0.0, FROST_SLAB_H * 0.5, 0.0),
		glaze_mat
	))
	patch.add_child(TunnelLook.part(
		TunnelLook.box(Vector3(size.x * 0.72, FROST_SLAB_H * 0.9, size.y * 0.68)),
		Vector3(size.x * 0.08, FROST_SLAB_H * 0.95, -size.y * 0.06),
		blue_mat,
		Vector3(0.0, 14.0, 0.0)
	))
	for i: int in 3:
		var h: int = hash_int(i + roundi(at.x * 2.0), roundi(at.z * 2.0), 103 + i)
		var ox: float = ((float(h % 100) / 100.0) - 0.5) * size.x * 0.65
		var oz: float = ((float((h / 13) % 100) / 100.0) - 0.5) * size.y * 0.65
		var rw: float = 0.28 + 0.22 * (float((h / 29) % 10) / 10.0)
		var rd: float = 0.22 + 0.18 * (float((h / 37) % 10) / 10.0)
		patch.add_child(TunnelLook.part(
			TunnelLook.box(Vector3(rw, 0.018, rd)),
			Vector3(ox, FROST_SLAB_H + 0.009, oz),
			rime_mat,
			Vector3(0.0, float(h % 45), 0.0)
		))

	parent.add_child(patch, true)
	return patch


## Half-buried frozen survey probe encased in a glacial ice mound: tilted
## instrument bus with gold foil trim, frosted cyan sensor lens, bent antenna
## dish, and broken solar fin (visual only, no collision) [PLACEHOLDER].
static func add_frozen_probe(parent: Node3D, at: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var probe := Node3D.new()
	probe.name = &"FrozenProbe"
	probe.position = at
	probe.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var ice_base: Material = ice_mat(ICE_BLUE, 0.20, ICE_ALPHA)
	var ice_pale: Material = ice_mat(ICE_PALE, 0.18, ICE_ALPHA)
	var frost_mat: Material = ice_mat(FROST_WHITE, 0.34, 0.94)
	var hull_mat: Material = matte_mat(PROBE_HULL, 0.65)
	var dark_mat: Material = matte_mat(PROBE_DARK, 0.72)
	var gold_mat: Material = matte_mat(PROBE_GOLD, 0.42)
	var lens_mat: Material = glow_mat(PROBE_LENS, 0.55)

	# Glacial ice drift encasing the lower half of the probe.
	probe.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.45, 0.28, 1.25)), Vector3(0.0, 0.14, 0.0), ice_base))
	probe.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.95, 0.42, 0.88)), Vector3(-0.14, 0.28, 0.06), ice_pale, Vector3(6.0, 18.0, -8.0)))
	probe.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.62, 0.36, 0.56)), Vector3(0.28, 0.22, -0.18), frost_mat, Vector3(-5.0, -22.0, 10.0)))

	# Tilted probe chassis emerging from the ice.
	var body := Node3D.new()
	body.name = &"ProbeBody"
	body.position = Vector3(0.0, 0.46, 0.0)
	body.rotation_degrees = Vector3(-18.0, 12.0, 24.0)
	probe.add_child(body)

	body.add_child(TunnelLook.part(TunnelLook.cylinder(0.32, 0.76), Vector3.ZERO, hull_mat))
	body.add_child(TunnelLook.part(TunnelLook.cylinder(0.35, 0.22), Vector3(0.0, -0.06, 0.0), gold_mat))
	body.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.26, 0.18, 0.14)), Vector3(0.0, 0.12, 0.29), dark_mat))
	body.add_child(TunnelLook.part(TunnelLook.sphere(0.075), Vector3(0.0, 0.12, 0.36), lens_mat))
	# Bent mast & high-gain dish.
	body.add_child(TunnelLook.part(TunnelLook.cylinder(0.03, 0.62), Vector3(-0.08, 0.62, -0.04), dark_mat, Vector3(0.0, 0.0, -14.0)))
	body.add_child(TunnelLook.part(_cone(0.26, 0.06, 0.10), Vector3(-0.16, 0.90, -0.04), hull_mat, Vector3(18.0, 0.0, -24.0)))
	# Half-snapped solar wing stub + frost cap.
	body.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.68, 0.04, 0.30)), Vector3(0.46, 0.06, 0.0), dark_mat, Vector3(0.0, 0.0, -10.0)))
	body.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.42, 0.05, 0.24)), Vector3(0.38, 0.10, 0.02), frost_mat, Vector3(0.0, 0.0, -10.0)))

	parent.add_child(probe, true)
	return probe


## Ice-core drill rack: frosted steel frame on skids holding vertical
## translucent core tubes with layered ice samples and a leaning drill auger
## (visual only, no collision) [PLACEHOLDER].
static func add_drill_rack(parent: Node3D, at: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var rack := Node3D.new()
	rack.name = &"DrillRack"
	rack.position = at
	rack.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var steel_mat: Material = matte_mat(DRILL_STEEL, 0.62)
	var dark_mat: Material = matte_mat(DRILL_DARK, 0.72)
	var frost_mat: Material = ice_mat(FROST_WHITE, 0.32, 0.92)
	var tube_mat: Material = ice_mat(DRILL_TUBE, 0.14, 0.52)
	var core_blue: Material = ice_mat(ICE_BLUE, 0.22, 1.0)
	var core_pale: Material = ice_mat(ICE_PALE, 0.22, 1.0)
	var core_deep: Material = ice_mat(ICE_DEEP, 0.24, 1.0)

	# Skids & base tray.
	for sx: float in [-DRILL_RACK_W * 0.44, DRILL_RACK_W * 0.44]:
		rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.08, 0.78)), Vector3(sx, 0.04, 0.0), dark_mat))
		rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.10, DRILL_RACK_H, 0.10)), Vector3(sx, DRILL_RACK_H * 0.5 + 0.08, -0.18), steel_mat))
	rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(DRILL_RACK_W, 0.08, 0.64)), Vector3(0.0, 0.12, 0.0), steel_mat))
	# Mid & top clamping bars + frost cap.
	rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(DRILL_RACK_W, 0.09, 0.16)), Vector3(0.0, 0.96, -0.14), dark_mat))
	rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(DRILL_RACK_W + 0.08, 0.10, 0.22)), Vector3(0.0, DRILL_RACK_H + 0.08, -0.16), steel_mat))
	rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(DRILL_RACK_W + 0.04, 0.05, 0.20)), Vector3(0.0, DRILL_RACK_H + 0.15, -0.16), frost_mat))

	# Three vertical translucent ice-core sample tubes with layered strata inside.
	var core_mats: Array[Material] = [core_deep, core_blue, core_pale]
	for i: int in 3:
		var tx: float = -0.44 + 0.44 * float(i)
		rack.add_child(TunnelLook.part(TunnelLook.cylinder(0.10, 1.38), Vector3(tx, 0.85, 0.02), tube_mat))
		rack.add_child(TunnelLook.part(TunnelLook.cylinder(0.115, 0.06), Vector3(tx, 0.18, 0.02), dark_mat))
		rack.add_child(TunnelLook.part(TunnelLook.cylinder(0.115, 0.06), Vector3(tx, 1.54, 0.02), dark_mat))
		for seg: int in 3:
			var sm: Material = core_mats[(i + seg) % core_mats.size()]
			rack.add_child(TunnelLook.part(TunnelLook.cylinder(0.072, 0.36), Vector3(tx, 0.42 + 0.40 * float(seg), 0.02), sm))

	# Leaning ice-core drill auger shaft beside the tubes.
	rack.add_child(TunnelLook.part(TunnelLook.cylinder(0.045, 1.52), Vector3(0.68, 0.86, 0.12), steel_mat, Vector3(0.0, 0.0, 8.0)))
	rack.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.32, 0.06, 0.08)), Vector3(0.58, 1.60, 0.12), dark_mat, Vector3(0.0, 0.0, 8.0)))

	parent.add_child(rack, true)
	return rack


## The frosted heater crate: insulated steel skids, frost-rimmed casing, glowing
## front heater grille, three warm orange heater cartridges on top, a soft warm
## OmniLight3D, and the HEATER CRATE label (visual only, no collision) [PLACEHOLDER].
static func add_heater_crate(parent: Node3D, at: Vector3) -> Node3D:
	var crate := Node3D.new()
	crate.name = "HeaterCrate"
	crate.position = at
	parent.add_child(crate)
	var steel_mat: Material = matte_mat(HEATER_STEEL, 0.65)
	var body_mat: Material = matte_mat(HEATER_BODY, 0.72)
	var frost_mat: Material = ice_mat(FROST_WHITE, 0.32, 0.92)
	var heat_mat: Material = glow_mat(HEATER_ORANGE, 1.35)
	var coil_mat: Material = glow_mat(HEATER_GLOW, 1.65)

	# Skids & insulated crate body.
	for sz: float in [-0.36, 0.36]:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.38, 0.08, 0.16)), Vector3(0.0, 0.04, sz), steel_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.30, 0.68, 0.90)), Vector3(0.0, 0.42, 0.0), body_mat))
	# Corner bumper posts & frost buildup along the top lid edges.
	for sx: float in [-0.62, 0.62]:
		for sz: float in [-0.42, 0.42]:
			crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.11, 0.78, 0.11)), Vector3(sx, 0.44, sz), steel_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.36, 0.07, 0.96)), Vector3(0.0, 0.78, 0.0), frost_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.42, 0.06, 0.24)), Vector3(-0.44, 0.83, -0.28), frost_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 0.05, 0.22)), Vector3(0.46, 0.82, 0.26), frost_mat))

	# Recessed warm heater grille on the front face (+Z) with glowing heating bars.
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.74, 0.34, 0.06)), Vector3(0.0, 0.42, 0.45), steel_mat))
	for row: int in 3:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.62, 0.045, 0.04)), Vector3(0.0, 0.31 + 0.11 * float(row), 0.475), coil_mat))

	# Three glowing orange heater cartridges in top sockets.
	for i: int in 3:
		var cx: float = -0.36 + 0.36 * float(i)
		crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.145, 0.08), Vector3(cx, 0.84, 0.0), steel_mat))
		crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.115, 0.48), Vector3(cx, 1.06, 0.0), heat_mat))
		crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.125, 0.05), Vector3(cx, 1.31, 0.0), steel_mat))

	# Soft warm glow spilling onto nearby ice.
	var light := OmniLight3D.new()
	light.name = &"HeaterGlow"
	light.position = Vector3(0.0, 1.05, 0.55)
	light.light_color = HEATER_GLOW
	light.light_energy = HEATER_LIGHT_ENERGY
	light.omni_range = HEATER_LIGHT_RANGE_M
	crate.add_child(light)

	crate.add_child(TunnelLook.label("HEATER CRATE", Vector3(0.0, 1.72, 0.0), TunnelLook.FROST))
	return crate


## The terraform test pod: a sealed, heated trial pod left under the ice. A steel skid, a pale
## hull with rounded ends, a clear port with a warm glow behind it, and frost along the top
## [PLACEHOLDER]. Primitives only, no collision.
static func add_test_pod(parent: Node3D, at: Vector3) -> Node3D:
	var pod := Node3D.new()
	pod.name = "TestPod"
	pod.position = at
	parent.add_child(pod)
	var steel_mat: Material = matte_mat(HEATER_STEEL, 0.65)
	var hull_mat: Material = matte_mat(HEATER_BODY, 0.55)
	var frost_mat: Material = ice_mat(FROST_WHITE, 0.32, 0.92)
	var port_mat: Material = ice_mat(GLACIER_CYAN, 0.10, 0.55)
	var warm_mat: Material = glow_mat(HEATER_GLOW, 1.2)
	for sz: float in [-0.5, 0.5]:
		pod.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.0, 0.10, 0.20)), Vector3(0.0, 0.05, sz), steel_mat))
	pod.add_child(TunnelLook.part(TunnelLook.cylinder(0.62, 1.7), Vector3(0.0, 0.78, 0.0), hull_mat, Vector3(0.0, 0.0, 90.0)))
	for sx: float in [-0.85, 0.85]:
		pod.add_child(TunnelLook.part(TunnelLook.sphere(0.62), Vector3(sx, 0.78, 0.0), hull_mat))
	pod.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.5, 0.06, 0.40)), Vector3(0.0, 1.38, 0.0), frost_mat))
	pod.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.62, 0.36, 0.06)), Vector3(0.0, 0.84, 0.58), steel_mat))
	pod.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.50, 0.24, 0.05)), Vector3(0.0, 0.84, 0.62), port_mat))
	pod.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.40, 0.14, 0.04)), Vector3(0.0, 0.84, 0.55), warm_mat))
	var light := OmniLight3D.new()
	light.name = &"PodGlow"
	light.position = Vector3(0.0, 0.9, 0.9)
	light.light_color = HEATER_GLOW
	light.light_energy = HEATER_LIGHT_ENERGY
	light.omni_range = HEATER_LIGHT_RANGE_M
	pod.add_child(light)
	pod.add_child(TunnelLook.label("TEST POD", Vector3(0.0, 1.8, 0.0), TunnelLook.FROST))
	return pod


## Adds a frosted ice cap and glazed frost footplates to NoticeSign without
## altering its base structure, position, or label [PLACEHOLDER].
static func add_sign_trim(board: Node3D) -> void:
	var frost_mat: Material = ice_mat(FROST_WHITE, 0.30, 0.94)
	var ice_foot: Material = ice_mat(ICE_BLUE, 0.20, 0.88)
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.14, 0.07, 0.26)), Vector3(0.0, 1.75, 0.0), frost_mat))
	for x: float in [-0.82, 0.82]:
		board.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 0.05, 0.36)), Vector3(x, 0.025, 0.0), ice_foot))
