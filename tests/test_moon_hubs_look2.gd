extends RefCounted
## Phobos and Deimos hubs look, second pass (feat/moon-hubs-look2):
## deterministic starfield and dressing builds, pinned unchanged collision /
## Area3D / spot / ARRIVE_AT / REACH_M / click targets, spot and camp-click
## clearance, zero overlap with CampProps footprint, and <= 2 new lights cap.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _open(scene_path: String) -> Node:
	var node: Node = (load(scene_path) as PackedScene).instantiate()
	_root().add_child(node)
	return node


func _drop(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _count_type(node: Node, type_name: String) -> int:
	var total: int = 1 if node.get_class() == type_name else 0
	for child: Node in node.get_children():
		if child.name == "Walker" or child.name == "UI":
			continue
		total += _count_type(child, type_name)
	return total


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, out)


func _snapshot_node(node: Node) -> Array[String]:
	var lines: Array[String] = []
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	for mi: MeshInstance3D in meshes:
		var mat := mi.material_override as StandardMaterial3D
		var col: String = mat.albedo_color.to_html(true) if mat != null else ""
		lines.append("%s|%s|%s" % [
			str(mi.global_position.snapped(Vector3(0.001, 0.001, 0.001))),
			str(mi.global_rotation_degrees.snapped(Vector3(0.01, 0.01, 0.01))),
			col,
		])
	return lines


func _world_xz_rect(mi: MeshInstance3D) -> Rect2:
	var local_aabb: AABB = mi.get_aabb()
	var xf: Transform3D = mi.global_transform
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for i: int in 8:
		var p: Vector3 = xf * local_aabb.get_endpoint(i)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func test_starfield_and_second_pass_props_are_deterministic() -> String:
	var checks: Array[Dictionary] = [
		{
			"scene": SceneSwitcher.PHOBOS_SCENE,
			"stars": MoonLook.STAR_COUNT_PHOBOS,
			"nodes": ["Starfield", "MarsHorizonGlow", "PadEdgeLights", "UtilityProps", "RegolithScatter", "TunnelMouthDetail"],
		},
		{
			"scene": SceneSwitcher.DEIMOS_SCENE,
			"stars": MoonLook.STAR_COUNT_DEIMOS,
			"nodes": ["Starfield", "MarsHorizonGlow", "PadEdgeLights", "UtilityProps", "RegolithScatter", "CampDressing"],
		},
		{
			"scene": PhobosServiceTunnel.SCENE_PATH,
			"stars": -1,
			"nodes": ["TunnelMouthDetail"],
		},
	]
	for entry: Dictionary in checks:
		var scene_path: String = str(entry["scene"])
		var first: Node = _open(scene_path)
		var second: Node = _open(scene_path)
		var problem: String = ""
		var expected_stars: int = int(entry["stars"])
		if expected_stars >= 0:
			var star_node: Node = first.get_node_or_null("Starfield")
			if star_node == null:
				problem = "%s missing Starfield." % scene_path
			elif star_node.get_child_count() != expected_stars:
				problem = "%s Starfield count expected %d, got %d." % [scene_path, expected_stars, star_node.get_child_count()]
		if problem == "":
			for node_name: String in entry["nodes"]:
				var a: Node = first.get_node_or_null(node_name)
				var b: Node = second.get_node_or_null(node_name)
				if a == null or b == null:
					problem = "%s missing second-pass node '%s'." % [scene_path, node_name]
					break
				var snap_a: Array[String] = _snapshot_node(a)
				var snap_b: Array[String] = _snapshot_node(b)
				if snap_a.is_empty():
					problem = "%s node '%s' produced no meshes." % [scene_path, node_name]
					break
				if snap_a != snap_b:
					problem = "%s node '%s' was not deterministic across builds." % [scene_path, node_name]
					break
		_drop(first)
		_drop(second)
		if problem != "":
			return problem
	return ""


func test_pinned_collisions_areas_spots_arrive_and_click_targets_unchanged() -> String:
	var problem: String = ""
	var phobos: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE) as PhobosHub
	if _count_type(phobos, "StaticBody3D") != 8:
		problem = "PhobosHub StaticBody3D count changed: expected 8, got %d." % _count_type(phobos, "StaticBody3D")
	elif _count_type(phobos, "Area3D") != 4:
		problem = "PhobosHub Area3D count changed: expected 4, got %d." % _count_type(phobos, "Area3D")
	elif _count_type(phobos, "CollisionShape3D") != 12:
		problem = "PhobosHub CollisionShape3D count changed: expected 12, got %d." % _count_type(phobos, "CollisionShape3D")
	elif PhobosHub.ARRIVE_AT != Vector3(-2.0, 0.0, 7.0) or not is_equal_approx(PhobosHub.REACH_M, 9.0):
		problem = "PhobosHub ARRIVE_AT or REACH_M changed."
	elif phobos._spots() != {
		"Console": Vector3(-6.0, 0.0, 3.0),
		"Board": Vector3(-3.0, 0.0, -8.6),
		"HookSign": Vector3(9.5, 0.0, -8.6),
		"Hatch": Vector3(14.0, 0.0, -2.0),
	}:
		problem = "PhobosHub _spots() changed."
	else:
		for click_name: String in ["Console", "Board", "HookSign", "Hatch"]:
			var click := phobos.get_node_or_null(click_name) as Area3D
			if click == null or click.collision_layer != 8:
				problem = "PhobosHub click target '%s' missing or wrong layer." % click_name
				break
		if problem == "":
			for decor_name: String in ["Starfield", "MarsHorizonGlow", "PadEdgeLights", "UtilityProps", "RegolithScatter", "TunnelMouthDetail"]:
				var decor: Node = phobos.get_node(decor_name)
				if _count_type(decor, "StaticBody3D") != 0 or _count_type(decor, "CollisionShape3D") != 0 or _count_type(decor, "Area3D") != 0:
					problem = "PhobosHub '%s' must have zero collision/Area3D." % decor_name
					break
	_drop(phobos)
	if problem != "":
		return problem

	var deimos: DeimosHub = _open(SceneSwitcher.DEIMOS_SCENE) as DeimosHub
	if _count_type(deimos, "StaticBody3D") != 11:
		problem = "DeimosHub StaticBody3D count changed: expected 11, got %d." % _count_type(deimos, "StaticBody3D")
	elif _count_type(deimos, "Area3D") != 5:
		problem = "DeimosHub Area3D count changed: expected 5, got %d." % _count_type(deimos, "Area3D")
	elif _count_type(deimos, "CollisionShape3D") != 16:
		problem = "DeimosHub CollisionShape3D count changed: expected 16, got %d." % _count_type(deimos, "CollisionShape3D")
	elif DeimosHub.ARRIVE_AT != Vector3(-2.0, 0.0, 7.0) or not is_equal_approx(DeimosHub.REACH_M, 9.0):
		problem = "DeimosHub ARRIVE_AT or REACH_M changed."
	elif deimos._spots() != {
		"Console": Vector3(-6.0, 0.0, 3.0),
		"Board": Vector3(-3.0, 0.0, -8.6),
		"Cache": Vector3(10.0, 0.0, -8.0),
		"Pod": Vector3(16.0, 0.0, -2.5),
	}:
		problem = "DeimosHub _spots() changed."
	else:
		for click_name: String in ["Console", "Board", "CacheSign", "PodSign", "CampClick"]:
			var click := deimos.get_node_or_null(click_name) as Area3D
			if click == null or click.collision_layer != 8:
				problem = "DeimosHub click target '%s' missing or wrong layer." % click_name
				break
		if problem == "":
			for decor_name: String in ["Starfield", "MarsHorizonGlow", "PadEdgeLights", "UtilityProps", "RegolithScatter", "CampDressing"]:
				var decor: Node = deimos.get_node(decor_name)
				if _count_type(decor, "StaticBody3D") != 0 or _count_type(decor, "CollisionShape3D") != 0 or _count_type(decor, "Area3D") != 0:
					problem = "DeimosHub '%s' must have zero collision/Area3D." % decor_name
					break
	_drop(deimos)
	if problem != "":
		return problem

	var tunnel: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
	if _count_type(tunnel, "StaticBody3D") != 5:
		problem = "PhobosServiceTunnel StaticBody3D count changed: expected 5, got %d." % _count_type(tunnel, "StaticBody3D")
	elif _count_type(tunnel, "Area3D") != 5:
		problem = "PhobosServiceTunnel Area3D count changed: expected 5, got %d." % _count_type(tunnel, "Area3D")
	elif PhobosServiceTunnel.ARRIVE_AT != Vector3(-9.5, 0.0, 0.0) or PhobosServiceTunnel.LADDER_AT != Vector3(-11.8, 0.0, -2.5):
		problem = "PhobosServiceTunnel ARRIVE_AT or LADDER_AT changed."
	elif not is_equal_approx(PhobosServiceTunnel.REACH_M, 6.5):
		problem = "PhobosServiceTunnel REACH_M changed."
	elif _count_type(tunnel.get_node("TunnelMouthDetail"), "StaticBody3D") != 0 or _count_type(tunnel.get_node("TunnelMouthDetail"), "Area3D") != 0:
		problem = "PhobosServiceTunnel TunnelMouthDetail must have zero collision/Area3D."
	_drop(tunnel)
	return problem


func test_new_props_keep_clear_of_spots_and_camp_footprint() -> String:
	var problem: String = ""
	var phobos: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE) as PhobosHub
	var p_spots: Array[Vector3] = [PhobosHub.ARRIVE_AT, PhobosHub.SPOTS["Hatch"] + PhobosHub.HATCH_ARRIVE_OFFSET]
	for spot: Vector3 in phobos._spots().values():
		p_spots.append(spot)
	var p_scatter: Array[MeshInstance3D] = []
	_collect_meshes(phobos.get_node("RegolithScatter"), p_scatter)
	for mi: MeshInstance3D in p_scatter:
		for spot: Vector3 in p_spots:
			if Vector2(mi.global_position.x - spot.x, mi.global_position.z - spot.z).length() < MoonLook.SPOT_CLEARANCE_M - 0.6:
				problem = "PhobosHub scatter mesh %s is too close to spot %s." % [mi.global_position, spot]
				break
		if problem != "":
			break
	if problem == "":
		var hatch_at: Vector3 = PhobosHub.SPOTS["Hatch"]
		var hatch_click_rect := Rect2(hatch_at.x - 1.3, hatch_at.z - 1.3, 2.6, 2.6)
		var hatch_arrive: Vector3 = hatch_at + PhobosHub.HATCH_ARRIVE_OFFSET
		var mouth_meshes: Array[MeshInstance3D] = []
		_collect_meshes(phobos.get_node("TunnelMouthDetail"), mouth_meshes)
		for mi: MeshInstance3D in mouth_meshes:
			var rect: Rect2 = _world_xz_rect(mi)
			if rect.intersects(hatch_click_rect):
				problem = "PhobosHub TunnelMouthDetail mesh %s overlaps Hatch click box." % mi.global_position
				break
			if Vector2(mi.global_position.x - hatch_arrive.x, mi.global_position.z - hatch_arrive.z).length() < 1.8:
				problem = "PhobosHub TunnelMouthDetail mesh %s is too close to ladder arrival spot." % mi.global_position
				break
	_drop(phobos)
	if problem != "":
		return problem

	var deimos: DeimosHub = _open(SceneSwitcher.DEIMOS_SCENE) as DeimosHub
	var camp_at: Vector3 = Camp.position(DeimosHub.DEIMOS)
	var d_spots: Array[Vector3] = [DeimosHub.ARRIVE_AT, camp_at]
	for spot: Vector3 in deimos._spots().values():
		d_spots.append(spot)
	var d_scatter: Array[MeshInstance3D] = []
	_collect_meshes(deimos.get_node("RegolithScatter"), d_scatter)
	for mi: MeshInstance3D in d_scatter:
		for spot: Vector3 in d_spots:
			if Vector2(mi.global_position.x - spot.x, mi.global_position.z - spot.z).length() < MoonLook.SPOT_CLEARANCE_M - 0.6:
				problem = "DeimosHub scatter mesh %s is too close to spot %s." % [mi.global_position, spot]
				break
		if problem != "":
			break
	if problem == "":
		# Collect CampProps footprints and CampClick XZ box.
		var camp_spot: Node = deimos.get_node("Camp/CampSpot")
		var camp_prop_meshes: Array[MeshInstance3D] = []
		_collect_meshes(camp_spot, camp_prop_meshes)
		var camp_click_rect := Rect2(camp_at.x - 2.0, camp_at.z - 1.5, 4.0, 3.0)
		var perimeter_meshes: Array[MeshInstance3D] = []
		_collect_meshes(deimos.get_node("CampDressing/CampPerimeter"), perimeter_meshes)
		if perimeter_meshes.is_empty():
			problem = "DeimosHub CampPerimeter has no meshes."
		for mi: MeshInstance3D in perimeter_meshes:
			var r: Rect2 = _world_xz_rect(mi)
			if r.intersects(camp_click_rect):
				problem = "DeimosHub CampPerimeter mesh at %s overlaps CampClick." % mi.global_position
				break
			for prop_mi: MeshInstance3D in camp_prop_meshes:
				if r.intersects(_world_xz_rect(prop_mi)):
					problem = "DeimosHub CampPerimeter mesh at %s overlaps CampProps mesh at %s." % [mi.global_position, prop_mi.global_position]
					break
			if problem != "":
				break
		if problem == "":
			var patch_meshes: Array[MeshInstance3D] = []
			_collect_meshes(deimos.get_node("CampDressing/CampDustPatch"), patch_meshes)
			if patch_meshes.is_empty():
				problem = "DeimosHub CampDustPatch has no meshes."
			for mi: MeshInstance3D in patch_meshes:
				if mi.global_position.y > 0.03:
					problem = "DeimosHub CampDustPatch mesh should sit flush on deck, got y=%.3f." % mi.global_position.y
					break
	_drop(deimos)
	return problem


func test_light_budget_and_pad_edge_lights_have_no_omnilights() -> String:
	var problem: String = ""
	var phobos: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE) as PhobosHub
	var p_lights: int = _count_type(phobos, "OmniLight3D")
	if p_lights > 2:
		problem = "PhobosHub exceeded light budget: %d OmniLight3Ds (max 2)." % p_lights
	else:
		for decor_name: String in ["Starfield", "MarsHorizonGlow", "PadEdgeLights", "UtilityProps", "RegolithScatter", "TunnelMouthDetail"]:
			if _count_type(phobos.get_node(decor_name), "OmniLight3D") != 0:
				problem = "PhobosHub '%s' must not add OmniLight3Ds." % decor_name
				break
		if problem == "":
			var pad_meshes: Array[MeshInstance3D] = []
			_collect_meshes(phobos.get_node("PadEdgeLights"), pad_meshes)
			var emissive_count: int = 0
			for mi: MeshInstance3D in pad_meshes:
				var mat := mi.material_override as StandardMaterial3D
				if mat != null and mat.emission_enabled:
					emissive_count += 1
			if emissive_count != 8:
				problem = "PhobosHub PadEdgeLights expected 8 emissive boxes, got %d." % emissive_count
	_drop(phobos)
	if problem != "":
		return problem

	var deimos: DeimosHub = _open(SceneSwitcher.DEIMOS_SCENE) as DeimosHub
	var d_lights: int = _count_type(deimos, "OmniLight3D")
	if d_lights > 3:
		problem = "DeimosHub exceeded light budget: %d OmniLight3Ds (max 3 with camp lantern)." % d_lights
	else:
		for decor_name: String in ["Starfield", "MarsHorizonGlow", "PadEdgeLights", "UtilityProps", "RegolithScatter", "CampDressing"]:
			if _count_type(deimos.get_node(decor_name), "OmniLight3D") != 0:
				problem = "DeimosHub '%s' must not add OmniLight3Ds." % decor_name
				break
		if problem == "":
			var pad_meshes: Array[MeshInstance3D] = []
			_collect_meshes(deimos.get_node("PadEdgeLights"), pad_meshes)
			var emissive_count: int = 0
			for mi: MeshInstance3D in pad_meshes:
				var mat := mi.material_override as StandardMaterial3D
				if mat != null and mat.emission_enabled:
					emissive_count += 1
			if emissive_count != 6:
				problem = "DeimosHub PadEdgeLights expected 6 emissive boxes, got %d." % emissive_count
	_drop(deimos)
	if problem != "":
		return problem

	var tunnel: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
	if _count_type(tunnel, "OmniLight3D") > 2:
		problem = "PhobosServiceTunnel exceeded light budget: %d OmniLight3Ds (max 2)." % _count_type(tunnel, "OmniLight3D")
	elif _count_type(tunnel.get_node("TunnelMouthDetail"), "OmniLight3D") != 0:
		problem = "PhobosServiceTunnel TunnelMouthDetail must not add OmniLight3Ds."
	_drop(tunnel)
	return problem


func test_mars_halo_culls_front_faces_and_has_no_wide_box() -> String:
	var back_mat: StandardMaterial3D = MoonLook.unshaded_alpha_mat(MoonLook.MARS_GLOW_PHOBOS, 0.2, BaseMaterial3D.CULL_BACK)
	var front_mat: StandardMaterial3D = MoonLook.unshaded_alpha_mat(MoonLook.MARS_GLOW_PHOBOS, 0.2, BaseMaterial3D.CULL_FRONT)
	var front_mat_again: StandardMaterial3D = MoonLook.unshaded_alpha_mat(MoonLook.MARS_GLOW_PHOBOS, 0.2, BaseMaterial3D.CULL_FRONT)
	if back_mat == front_mat:
		return "unshaded_alpha_mat cache must separate CULL_BACK and CULL_FRONT."
	if front_mat != front_mat_again:
		return "unshaded_alpha_mat must return the cached material for identical args."

	var problem: String = ""
	for scene_path: String in [SceneSwitcher.PHOBOS_SCENE, SceneSwitcher.DEIMOS_SCENE]:
		var hub: Node = _open(scene_path)
		var glow: Node = hub.get_node_or_null("MarsHorizonGlow")
		if glow == null:
			problem = "%s missing MarsHorizonGlow." % scene_path
		else:
			var meshes: Array[MeshInstance3D] = []
			_collect_meshes(glow, meshes)
			if meshes.size() != MoonLook.MARS_HALO_SCALES.size():
				problem = "%s MarsHorizonGlow expected %d halo shells, got %d." % [scene_path, MoonLook.MARS_HALO_SCALES.size(), meshes.size()]
			var prev_radius: float = 0.0
			var prev_alpha: float = 2.0
			for mi: MeshInstance3D in meshes:
				if problem != "":
					break
				if mi.mesh is BoxMesh:
					var b := mi.mesh as BoxMesh
					if maxf(b.size.x, b.size.z) > 20.0:
						problem = "%s MarsHorizonGlow has a box wider than 20 m: %s." % [scene_path, b.size]
						break
				var mat := mi.material_override as StandardMaterial3D
				if mat == null:
					problem = "%s MarsHorizonGlow mesh missing StandardMaterial3D." % scene_path
					break
				if mat.cull_mode != BaseMaterial3D.CULL_FRONT:
					problem = "%s MarsHorizonGlow shell must use CULL_FRONT." % scene_path
					break
				if mat.no_depth_test:
					problem = "%s MarsHorizonGlow shell must keep depth test enabled." % scene_path
					break
				if mat.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_DISABLED:
					problem = "%s MarsHorizonGlow shell must disable depth draw." % scene_path
					break
				if mi.mesh is SphereMesh:
					var r: float = (mi.mesh as SphereMesh).radius
					if r <= prev_radius:
						problem = "%s MarsHorizonGlow shell radii must increase." % scene_path
						break
					prev_radius = r
					if mat.albedo_color.a >= prev_alpha:
						problem = "%s MarsHorizonGlow shell alphas must fall from inner to outer." % scene_path
						break
					prev_alpha = mat.albedo_color.a
		_drop(hub)
		if problem != "":
			return problem
	return ""
