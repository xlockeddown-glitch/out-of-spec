class_name AquiferLook
extends RefCounted
## The Flooded Aquifer's look (feat/aquifer-look): wet dark teal-grey rock
## palette, slick dark floor, pale mineral streaks, pipe-green rusted pumps and
## valves, still tinted water with named alpha constants, deterministic
## coordinate hash, cached read-only materials isolated from TunnelLook, fresh
## unique materials for per-pool water, and primitive-mesh builders (boxes and
## cylinders only). Every colour, size, roughness, alpha, and hash choice is a
## [PLACEHOLDER].

## Wet dark teal-grey rock, slick dark floor, and pale mineral streak palette [PLACEHOLDER].
const ROCK_TINT := Color(0.62, 0.76, 0.74)
const ROCK_ROUGHNESS: float = 0.48
const WET_ROCK_METALLIC: float = 0.06
const WET_ROCK_DARK := Color(0.10, 0.16, 0.18)
const WET_ROCK_MID := Color(0.16, 0.24, 0.26)
const WET_ROCK_TEAL := Color(0.14, 0.27, 0.29)
const ARCH_WET_STONE := Color(0.13, 0.21, 0.23)
const ARCH_TRIM_TEAL := Color(0.20, 0.34, 0.33)

const FLOOR_SLICK := Color(0.12, 0.18, 0.20)
const FLOOR_PUDDLE := Color(0.08, 0.15, 0.18)
const FLOOR_ROUGHNESS: float = 0.34

const MINERAL_STREAK := Color(0.70, 0.78, 0.74)
const MINERAL_CALCITE := Color(0.79, 0.84, 0.79)
const MINERAL_ROUGHNESS: float = 0.78

## Pipe-green rusted pumps, valves, and industrial plumbing palette [PLACEHOLDER].
const PIPE_GREEN := Color(0.22, 0.39, 0.33)
const PIPE_GREEN_DARK := Color(0.15, 0.27, 0.23)
const RUST_OXIDE := Color(0.46, 0.24, 0.15)
const VALVE_WHEEL_RUST := Color(0.58, 0.22, 0.16)
const IRON_DARK := Color(0.13, 0.16, 0.17)
const BRASS_TARNISHED := Color(0.48, 0.42, 0.24)
const HOSE_RUBBER := Color(0.17, 0.20, 0.22)
const GAUGE_FACE := Color(0.78, 0.82, 0.76)
const LABEL_TEAL: Color = ScopeTheme.TEAL
const LABEL_WARN: Color = ScopeTheme.RED

## Still water with faint teal surface tint, alphas, roughness, and damp silt [PLACEHOLDER].
const WATER_SHALLOW := Color(0.18, 0.49, 0.52)
const WATER_DEEP := Color(0.06, 0.20, 0.26)
const WATER_SURFACE_TINT := Color(0.32, 0.64, 0.65)
const WATER_SHALLOW_ALPHA: float = 0.66
const WATER_DEEP_ALPHA: float = 0.86
const SEAL_SHEET_ALPHA: float = 0.44
const WATER_SHALLOW_ROUGHNESS: float = 0.22
const WATER_DEEP_ROUGHNESS: float = 0.16
const WATER_METALLIC: float = 0.08
const SILT_DAMP := Color(0.22, 0.24, 0.23)
const SILT_DARK := Color(0.15, 0.17, 0.17)
const SILT_ROUGHNESS: float = 0.68

## Cavern & pool accent light tuning (at most 2 new lights per scene) [PLACEHOLDER].
const POOL_GLOW_COLOR := Color(0.34, 0.76, 0.74)
const HUB_POOL_LIGHT_ENERGY: float = 0.6
const HUB_POOL_LIGHT_RANGE_M: float = 8.0
const CAVERN_LIGHT_COLOR := Color(0.38, 0.72, 0.70)
const CAVERN_LIGHT_ENERGY: float = 0.55
const CAVERN_LIGHT_RANGE_M: float = 9.0

## Default prop proportions, in metres [PLACEHOLDER].
const STALACTITE_COUNT_DEFAULT: int = 5
const STALACTITE_CORNICE_H: float = 0.14
const PIPE_RADIUS_M: float = 0.12
const PIPE_FLANGE_RADIUS_M: float = 0.17
const PIPE_BRACKET_STEP_M: float = 2.2
const MINERAL_STREAK_THICKNESS_M: float = 0.035

## Cached read-only materials isolated from TunnelLook's caches.
static var _flat_cache: Dictionary = {}
static var _glow_cache: Dictionary = {}


## Deterministic integer hash from coordinates and salt (no global RNG) [PLACEHOLDER].
static func hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## Cached read-only StandardMaterial3D for `color` and `roughness` [PLACEHOLDER].
static func flat_mat(color: Color, roughness: float = TunnelLook.MATTE_ROUGHNESS) -> StandardMaterial3D:
	var key: String = "%s|%.2f" % [color.to_html(false), roughness]
	if _flat_cache.has(key):
		return _flat_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_flat_cache[key] = material
	return material


## Fresh (uncached) StandardMaterial3D for callers that need per-instance isolation
## (e.g. drained silt slabs) [PLACEHOLDER].
static func flat_mat_unique(color: Color, roughness: float = TunnelLook.MATTE_ROUGHNESS) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## Fresh (uncached) translucent still-water StandardMaterial3D with faint surface
## tint so draining or mutating one pool never leaks into another [PLACEHOLDER].
static func water_mat(color: Color, roughness: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = roughness
	material.metallic = WATER_METALLIC
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## Cached emissive StandardMaterial3D isolated from TunnelLook's cache [PLACEHOLDER].
static func glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var key: String = "%s|%.3f" % [color.to_html(false), energy]
	if _glow_cache.has(key):
		return _glow_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_glow_cache[key] = material
	return material


static func _tapered_cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


## Dripping wet-rock and pale-mineral stalactite cluster anchored at `at`
## (hanging downward in -Y), built from boxes and tapered cylinders (visual only,
## no collision) [PLACEHOLDER].
static func add_stalactite_cluster(parent: Node3D, at: Vector3, width_m: float = 2.8, max_drop_m: float = 0.95, rot_y_deg: float = 0.0) -> Node3D:
	var cluster := Node3D.new()
	cluster.name = &"StalactiteCluster"
	cluster.position = at
	cluster.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var rock_mat: Material = flat_mat(WET_ROCK_MID, ROCK_ROUGHNESS)
	var dark_mat: Material = flat_mat(WET_ROCK_DARK, ROCK_ROUGHNESS)
	var mineral_mat: Material = flat_mat(MINERAL_STREAK, MINERAL_ROUGHNESS)
	var drip_mat: Material = flat_mat(WATER_SURFACE_TINT, WATER_SHALLOW_ROUGHNESS)

	# Wet rock ceiling shelf + mineral crust lip.
	cluster.add_child(TunnelLook.part(
		TunnelLook.box(Vector3(width_m, STALACTITE_CORNICE_H, 0.30)),
		Vector3(0.0, -STALACTITE_CORNICE_H * 0.5, 0.0),
		dark_mat
	))
	cluster.add_child(TunnelLook.part(
		TunnelLook.box(Vector3(width_m * 0.86, 0.04, 0.34)),
		Vector3(0.0, -STALACTITE_CORNICE_H - 0.01, 0.0),
		mineral_mat
	))

	var count: int = maxi(STALACTITE_COUNT_DEFAULT, int(round(width_m / 0.48)))
	var span: float = maxf(width_m - 0.32, 0.4)
	for i: int in count:
		var h: int = hash_int(i + roundi(at.x * 3.0), roundi(at.z * 3.0), 61 + i)
		var frac: float = float(h % 100) / 100.0
		var t: float = float(i) / float(maxi(count - 1, 1)) - 0.5
		var x: float = t * span
		var z_off: float = ((float((h / 7) % 11) / 10.0) - 0.5) * 0.14
		var drop: float = max_drop_m * (0.40 + 0.60 * frac)
		var top_r: float = 0.055 + 0.05 * frac
		var body_mat: Material = mineral_mat if (i % 3 == 0) else rock_mat
		cluster.add_child(TunnelLook.part(
			_tapered_cylinder(top_r, 0.014, drop),
			Vector3(x, -STALACTITE_CORNICE_H - drop * 0.5, z_off),
			body_mat
		))
		if i % 2 == 0:
			# Mineral drip tip at the bottom of alternating stalactites.
			cluster.add_child(TunnelLook.part(
				TunnelLook.cylinder(0.018, 0.08),
				Vector3(x, -STALACTITE_CORNICE_H - drop - 0.03, z_off),
				drip_mat
			))

	parent.add_child(cluster, true)
	return cluster


## Rusted pipe-green drainage pipe run mounted along a tunnel wall: twin
## horizontal pipes, bolted flanges, iron wall brackets, rust collars, and a
## vertical standpipe elbow (visual only, no collision) [PLACEHOLDER].
static func add_pipe_run(parent: Node3D, at: Vector3, length_m: float = 5.4, height_m: float = 1.65, rot_y_deg: float = 0.0) -> Node3D:
	var run := Node3D.new()
	run.name = &"PipeRun"
	run.position = at
	run.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var pipe_mat: Material = flat_mat(PIPE_GREEN, 0.56)
	var dark_pipe_mat: Material = flat_mat(PIPE_GREEN_DARK, 0.62)
	var rust_mat: Material = flat_mat(RUST_OXIDE, 0.84)
	var iron_mat: Material = flat_mat(IRON_DARK, 0.68)
	var brass_mat: Material = flat_mat(BRASS_TARNISHED, 0.52)

	# Upper main drainage pipe & lower return pipe running along local X.
	run.add_child(TunnelLook.part(
		TunnelLook.cylinder(PIPE_RADIUS_M, length_m),
		Vector3(0.0, height_m, 0.0),
		pipe_mat,
		Vector3(0.0, 0.0, 90.0)
	))
	run.add_child(TunnelLook.part(
		TunnelLook.cylinder(PIPE_RADIUS_M * 0.68, length_m),
		Vector3(0.0, height_m - 0.42, 0.04),
		dark_pipe_mat,
		Vector3(0.0, 0.0, 90.0)
	))

	# Vertical drop leg & rusted floor shoe at one end.
	var drop_x: float = -length_m * 0.44
	run.add_child(TunnelLook.part(
		TunnelLook.cylinder(PIPE_RADIUS_M * 0.92, height_m),
		Vector3(drop_x, height_m * 0.5, 0.0),
		pipe_mat
	))
	run.add_child(TunnelLook.part(
		TunnelLook.cylinder(PIPE_FLANGE_RADIUS_M + 0.05, 0.08),
		Vector3(drop_x, 0.04, 0.0),
		rust_mat
	))

	# Mounting brackets, bolted flanges, and oxidized rust collars along the span.
	var brackets: int = maxi(int(floor(length_m / PIPE_BRACKET_STEP_M)) + 1, 2)
	var span: float = maxf(length_m - 0.6, 0.6)
	for i: int in brackets:
		var t: float = float(i) / float(maxi(brackets - 1, 1)) - 0.5
		var bx: float = t * span
		var flange_mat: Material = rust_mat if (i % 2 == 0) else brass_mat
		run.add_child(TunnelLook.part(
			TunnelLook.cylinder(PIPE_FLANGE_RADIUS_M, 0.09),
			Vector3(bx, height_m, 0.0),
			flange_mat,
			Vector3(0.0, 0.0, 90.0)
		))
		run.add_child(TunnelLook.part(
			TunnelLook.box(Vector3(0.10, 0.72, 0.24)),
			Vector3(bx, height_m - 0.20, -0.10),
			iron_mat
		))

	parent.add_child(run, true)
	return run


## Vertical pale mineral seepage streak clinging to a wet rock wall (visual
## only, no collision) [PLACEHOLDER].
static func add_mineral_streak(parent: Node3D, at: Vector3, width_m: float = 1.4, height_m: float = 2.4, rot_y_deg: float = 0.0) -> Node3D:
	var streak := Node3D.new()
	streak.name = &"MineralStreak"
	streak.position = at
	streak.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var pale_mat: Material = flat_mat(MINERAL_STREAK, MINERAL_ROUGHNESS)
	var calcite_mat: Material = flat_mat(MINERAL_CALCITE, MINERAL_ROUGHNESS)

	for i: int in 4:
		var h: int = hash_int(i + roundi(at.x * 2.0), roundi(at.z * 2.0), 149 + i)
		var ox: float = ((float(i) / 3.0) - 0.5) * (width_m * 0.78)
		var sh: float = height_m * (0.48 + 0.45 * (float(h % 100) / 100.0))
		var sw: float = 0.14 + 0.12 * (float((h / 11) % 10) / 10.0)
		var mat: Material = calcite_mat if (i % 2 == 0) else pale_mat
		streak.add_child(TunnelLook.part(
			TunnelLook.box(Vector3(sw, sh, MINERAL_STREAK_THICKNESS_M)),
			Vector3(ox, height_m - sh * 0.5, 0.0),
			mat
		))

	parent.add_child(streak, true)
	return streak


## Stepped wet-stone and pale mineral curbing + bed detail + seepage plates
## around a pool (visual only, no collision) [PLACEHOLDER].
static func add_pool_trim(parent: Node3D, box: Rect2, rect: Rect2i, drained: bool, shallow: bool) -> void:
	_add_pool_rim(parent, box, rect)
	_add_pool_bed_detail(parent, box, rect, drained, shallow)
	_add_pool_seepage(parent, box, rect)


static func _add_pool_rim(parent: Node3D, box: Rect2, rect: Rect2i) -> void:
	var wet_mat: Material = flat_mat(WET_ROCK_TEAL, ROCK_ROUGHNESS)
	var mineral_mat: Material = flat_mat(MINERAL_STREAK, MINERAL_ROUGHNESS)
	var dark_mat: Material = flat_mat(WET_ROCK_DARK, ROCK_ROUGHNESS)
	var step_m: float = 1.15
	var rim_w: float = 0.24
	var idx: int = 0

	var cols: int = maxi(int(round(box.size.x / step_m)), 2)
	var seg_x: float = box.size.x / float(cols)
	for side: float in [-1.0, 1.0]:
		var z: float = box.get_center().y + side * (box.size.y * 0.5 + rim_w * 0.35)
		for i: int in cols:
			var h_val: int = hash_int(rect.position.x + i, rect.position.y + int(side), idx)
			idx += 1
			var x: float = box.position.x + (float(i) + 0.5) * seg_x
			var height: float = 0.07 + float(h_val % 4) * 0.02
			var mat: Material = mineral_mat if (h_val % 4 == 0) else (wet_mat if (h_val % 2 == 0) else dark_mat)
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(seg_x * 0.92, height, rim_w)),
					Vector3(x, height * 0.5, z), mat))

	var rows: int = maxi(int(round(box.size.y / step_m)), 2)
	var seg_z: float = box.size.y / float(rows)
	for side: float in [-1.0, 1.0]:
		var x: float = box.get_center().x + side * (box.size.x * 0.5 + rim_w * 0.35)
		for j: int in rows:
			var h_val: int = hash_int(rect.position.x + int(side), rect.position.y + j, 100 + idx)
			idx += 1
			var z: float = box.position.y + (float(j) + 0.5) * seg_z
			var height: float = 0.07 + float(h_val % 4) * 0.02
			var mat: Material = mineral_mat if (h_val % 4 == 0) else wet_mat
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(rim_w, height, seg_z * 0.92)),
					Vector3(x, height * 0.5, z), mat))


static func _add_pool_bed_detail(parent: Node3D, box: Rect2, rect: Rect2i, drained: bool, shallow: bool) -> void:
	var centre: Vector2 = box.get_center()
	if drained:
		var mud_mat: Material = flat_mat(SILT_DARK, SILT_ROUGHNESS)
		var pebble_mat: Material = flat_mat(WET_ROCK_MID, ROCK_ROUGHNESS)
		var mineral_mat: Material = flat_mat(MINERAL_STREAK, MINERAL_ROUGHNESS)
		for i: int in 5:
			var hx: int = hash_int(rect.position.x, rect.position.y, 200 + i * 2)
			var hz: int = hash_int(rect.position.x, rect.position.y, 201 + i * 2)
			var ox: float = (float(hx % 100) / 100.0 - 0.5) * (box.size.x - 1.0)
			var oz: float = (float(hz % 100) / 100.0 - 0.5) * (box.size.y - 1.0)
			var w: float = 0.55 + float(hx % 5) * 0.14
			var d: float = 0.45 + float(hz % 5) * 0.12
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, 0.03, d)),
					Vector3(centre.x + ox, 0.055, centre.y + oz), mud_mat))
			if i < 3:
				var p_mat: Material = mineral_mat if i == 0 else pebble_mat
				parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.08, 0.22)),
						Vector3(centre.x - ox * 0.7, 0.07, centre.y - oz * 0.7), p_mat, Vector3(0.0, float(hx % 45), 0.0)))
	elif shallow:
		var stone_mat: Material = flat_mat(WET_ROCK_TEAL, ROCK_ROUGHNESS)
		var mid_mat: Material = flat_mat(WET_ROCK_MID, ROCK_ROUGHNESS)
		for i: int in 4:
			var hx: int = hash_int(rect.position.x, rect.position.y, 300 + i * 2)
			var hz: int = hash_int(rect.position.x, rect.position.y, 301 + i * 2)
			var ox: float = (float(hx % 100) / 100.0 - 0.5) * (box.size.x - 1.2)
			var oz: float = (float(hz % 100) / 100.0 - 0.5) * (box.size.y - 1.2)
			var mat: Material = stone_mat if (i % 2 == 0) else mid_mat
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.58, 0.03, 0.48)),
					Vector3(centre.x + ox, 0.015, centre.y + oz), mat, Vector3(0.0, float(hx % 30), 0.0)))
	else:
		var liner_w: float = maxf(box.size.x - 0.5, 0.5)
		var liner_d: float = maxf(box.size.y - 0.5, 0.5)
		parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(liner_w, 0.02, liner_d)),
				Vector3(centre.x, 0.008, centre.y), flat_mat(FLOOR_PUDDLE, FLOOR_ROUGHNESS)))
		parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(liner_w * 0.72, 0.015, liner_d * 0.72)),
				Vector3(centre.x, 0.014, centre.y), flat_mat(WATER_DEEP.darkened(0.35), WATER_DEEP_ROUGHNESS)))


static func _add_pool_seepage(parent: Node3D, box: Rect2, rect: Rect2i) -> void:
	var slick_mat: Material = flat_mat(FLOOR_PUDDLE, FLOOR_ROUGHNESS)
	var mineral_mat: Material = flat_mat(MINERAL_STREAK, MINERAL_ROUGHNESS)
	var centre: Vector2 = box.get_center()
	for i: int in 6:
		var h: int = hash_int(rect.position.x, rect.position.y, 400 + i)
		var edge: int = i % 4
		var t: float = (float((h >> 3) % 80) / 100.0) - 0.4
		var out: float = 0.34 + float(h % 4) * 0.11
		var px: float = centre.x
		var pz: float = centre.y
		if edge == 0:
			px += t * box.size.x
			pz -= box.size.y * 0.5 + out
		elif edge == 1:
			px += t * box.size.x
			pz += box.size.y * 0.5 + out
		elif edge == 2:
			px -= box.size.x * 0.5 + out
			pz += t * box.size.y
		else:
			px += box.size.x * 0.5 + out
			pz += t * box.size.y
		var w: float = 0.44 + float((h >> 6) % 4) * 0.14
		var d: float = 0.36 + float((h >> 9) % 4) * 0.12
		var mat: Material = mineral_mat if (i % 3 == 0) else slick_mat
		parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, 0.022, d)),
				Vector3(px, 0.012, pz), mat, Vector3(0.0, float(h % 35) - 17.0, 0.0)))


## Restyled PumpCrate: dark iron pallet skids, pipe-green rusted pump housing,
## rusted iron corner posts, tarnished brass collar, coiled rubber hose,
## pressure gauge, and PUMP CRATE label (visual only, no collision) [PLACEHOLDER].
static func build_pump_crate(at: Vector3) -> Node3D:
	var crate := Node3D.new()
	crate.name = "PumpCrate"
	crate.position = at
	var iron_mat: Material = flat_mat(IRON_DARK, 0.68)
	var pipe_mat: Material = flat_mat(PIPE_GREEN, 0.56)
	var pipe_dark_mat: Material = flat_mat(PIPE_GREEN_DARK, 0.64)
	var rust_mat: Material = flat_mat(RUST_OXIDE, 0.84)
	var brass_mat: Material = flat_mat(BRASS_TARNISHED, 0.52)
	var hose_mat: Material = flat_mat(HOSE_RUBBER, 0.72)
	var gauge_mat: Material = flat_mat(GAUGE_FACE, 0.55)
	var needle_mat: Material = flat_mat(VALVE_WHEEL_RUST, 0.65)

	# Pallet runners & deck.
	for z_off: float in [-0.36, 0.36]:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.38, 0.08, 0.16)), Vector3(0.0, 0.04, z_off), iron_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.42, 0.06, 1.04)), Vector3(0.0, 0.11, 0.0), pipe_dark_mat))

	# Pipe-green pump housing + rusted iron corner posts + tarnished brass trim band.
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.16, 0.78, 0.84)), Vector3(0.0, 0.53, 0.0), pipe_mat))
	for sx: float in [-0.57, 0.57]:
		for sz: float in [-0.41, 0.41]:
			crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.10, 0.84, 0.10)), Vector3(sx, 0.54, sz), rust_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.26, 0.10, 0.94)), Vector3(0.0, 0.62, 0.0), glow_mat(BRASS_TARNISHED, 0.45)))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.22, 0.08, 0.90)), Vector3(0.0, 0.96, 0.0), pipe_dark_mat))

	# Coiled rubber pump hose with tarnished brass coupling.
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.28, 0.08), Vector3(-0.22, 1.04, 0.0), hose_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.24, 0.08), Vector3(-0.22, 1.11, 0.0), hose_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.12, 0.16), Vector3(-0.22, 1.08, 0.0), iron_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.06, 0.18), Vector3(0.04, 1.08, 0.16), brass_mat, Vector3(0.0, 0.0, 90.0)))

	# Pressure gauge on brass stem.
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.04, 0.22), Vector3(0.34, 1.10, 0.18), brass_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.13, 0.06), Vector3(0.34, 1.24, 0.18), brass_mat, Vector3(90.0, 0.0, 0.0)))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.10, 0.07), Vector3(0.34, 1.24, 0.18), gauge_mat, Vector3(90.0, 0.0, 0.0)))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.03, 0.09, 0.08)), Vector3(0.35, 1.26, 0.18), needle_mat, Vector3(0.0, 0.0, -28.0)))

	crate.add_child(TunnelLook.label("PUMP CRATE", Vector3(0.0, 1.65, 0.0), LABEL_TEAL))
	return crate


## Builds an open-seal valve standpipe, rusted valve wheel, tarnished brass
## nozzle, translucent water jet (`WaterJet`), and label (visual only, no
## collision) [PLACEHOLDER].
static func build_seal_valve(at: Vector3, seal_id: String, room_centre: Vector2) -> Node3D:
	var valve := Node3D.new()
	valve.name = "Valve_" + seal_id
	valve.position = at

	var iron_mat: Material = flat_mat(IRON_DARK, 0.68)
	var pipe_mat: Material = flat_mat(PIPE_GREEN, 0.56)
	var rust_mat: Material = flat_mat(RUST_OXIDE, 0.84)
	var brass_mat: Material = flat_mat(BRASS_TARNISHED, 0.52)
	var wheel_mat: Material = flat_mat(VALVE_WHEEL_RUST, 0.68)
	var splash_mat: Material = flat_mat(WATER_SURFACE_TINT, WATER_SHALLOW_ROUGHNESS)

	valve.add_child(TunnelLook.part(TunnelLook.cylinder(0.24, 0.08), Vector3(0.0, 0.04, 0.0), iron_mat))
	valve.add_child(TunnelLook.part(TunnelLook.cylinder(0.11, 0.72), Vector3(0.0, 0.40, 0.0), pipe_mat))
	valve.add_child(TunnelLook.part(TunnelLook.cylinder(0.155, 0.10), Vector3(0.0, 0.24, 0.0), rust_mat))
	valve.add_child(TunnelLook.part(TunnelLook.cylinder(0.15, 0.10), Vector3(0.0, 0.62, 0.0), brass_mat))
	valve.add_child(TunnelLook.part(TunnelLook.cylinder(0.04, 0.16), Vector3(0.0, 0.80, 0.0), brass_mat))

	# Small rusted valve wheel: central hub, crossed spokes, and rim segments.
	var wheel := Node3D.new()
	wheel.name = "ValveWheel"
	wheel.position = Vector3(0.0, 0.88, 0.0)
	wheel.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	valve.add_child(wheel)
	wheel.add_child(TunnelLook.part(TunnelLook.cylinder(0.07, 0.06), Vector3.ZERO, brass_mat))
	wheel.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.44, 0.04, 0.04)), Vector3.ZERO, wheel_mat))
	wheel.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.04, 0.04, 0.44)), Vector3.ZERO, wheel_mat))
	for off: float in [-0.21, 0.21]:
		wheel.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.26, 0.045, 0.05)), Vector3(0.0, 0.0, off), wheel_mat))
		wheel.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.05, 0.045, 0.26)), Vector3(off, 0.0, 0.0), wheel_mat))

	# Side nozzle and thin translucent water jet spraying toward the room's interior.
	var inward := Vector2(room_centre.x - at.x, room_centre.y - at.z).normalized()
	if inward.length_squared() < 0.01:
		inward = Vector2(0.0, -1.0)
	var yaw_deg: float = rad_to_deg(atan2(inward.x, inward.y))
	var spray := Node3D.new()
	spray.name = "WaterJet"
	spray.position = Vector3(0.0, 0.48, 0.0)
	spray.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	valve.add_child(spray)
	spray.add_child(TunnelLook.part(TunnelLook.cylinder(0.065, 0.24), Vector3(0.0, 0.0, 0.14), brass_mat, Vector3(90.0, 0.0, 0.0)))
	var jet_mat: StandardMaterial3D = water_mat(WATER_SURFACE_TINT, WATER_SHALLOW_ROUGHNESS, WATER_SHALLOW_ALPHA)
	spray.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.09, 0.07, 1.25)), Vector3(0.0, -0.14, 0.82), jet_mat, Vector3(14.0, 0.0, 0.0)))
	spray.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.28, 0.03, 0.34)), Vector3(0.0, -0.44, 1.42), splash_mat))

	valve.add_child(TunnelLook.label("%s OPEN SEAL" % seal_id.to_upper(), Vector3(0.0, 1.55, 0.0), LABEL_WARN))
	return valve


## Adds pipe-green cap trim, mineral crust, and rusted iron footplates to
## NoticeSign without altering its base structure, position, or label [PLACEHOLDER].
static func add_sign_trim(board: Node3D) -> void:
	var pipe_mat: Material = flat_mat(PIPE_GREEN_DARK, 0.62)
	var rust_mat: Material = flat_mat(RUST_OXIDE, 0.84)
	var mineral_mat: Material = flat_mat(MINERAL_STREAK, MINERAL_ROUGHNESS)
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.08, 0.05, 0.20)), Vector3(0.0, 1.74, 0.0), pipe_mat))
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.42, 0.025, 0.22)), Vector3(-0.18, 1.77, 0.0), mineral_mat))
	for x: float in [-0.82, 0.82]:
		board.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.34, 0.035, 0.34)), Vector3(x, 0.02, 0.0), rust_mat))
