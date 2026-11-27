extends RefCounted
## Flooded Aquifer look (feat/aquifer-look): deterministic pool & prop visuals,
## per-pool unique materials (no shared-material leak when draining), preserved
## named nodes, unchanged collision/holds, and clean node teardown.

const SEED: int = 424242


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _make_aquifer_shell() -> FloodedAquifer:
	var aq := FloodedAquifer.new()
	aq._water = Node3D.new()
	aq._water.name = "Water"
	aq.add_child(aq._water)
	aq._depth_props = ZoneDepthProps.new()
	aq._depth_props.name = "DepthProps"
	aq.add_child(aq._depth_props)
	return aq


func _snapshot_tree(node: Node) -> Array[String]:
	var lines: Array[String] = []
	for child: Node in node.get_children():
		var label: String = "" if child.name.begins_with("@") else String(child.name)
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			var col: String = mat.albedo_color.to_html(true) if mat != null else ""
			lines.append("%s|%s|%s|%s" % [label, str(mi.position.snapped(Vector3(0.001, 0.001, 0.001))),
					str(mi.rotation_degrees.snapped(Vector3(0.01, 0.01, 0.01))), col])
		else:
			lines.append(label)
			lines.append_array(_snapshot_tree(child))
	return lines


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if _has_collision(child):
			return true
	return false


func test_pool_look_is_deterministic_for_same_seed_and_pool() -> String:
	var layout_data: Dictionary = AquiferDepth.layout(SEED, 1, 5)
	var first: FloodedAquifer = _make_aquifer_shell()
	var second: FloodedAquifer = _make_aquifer_shell()
	for pool: Dictionary in layout_data["pools"]:
		first._draw_pool(pool, str(pool["id"]))
		second._draw_pool(pool, str(pool["id"]))
	var snap_a: Array[String] = _snapshot_tree(first._water)
	var snap_b: Array[String] = _snapshot_tree(second._water)
	var problem: String = ""
	if snap_a.is_empty():
		problem = "Aquifer pool build produced no meshes."
	elif snap_a != snap_b:
		problem = "Pool look differed across identical builds (%d vs %d entries)." % [snap_a.size(), snap_b.size()]
	_free(first)
	_free(second)
	return problem


func test_draining_one_pool_never_changes_other_pools_or_shared_materials() -> String:
	var full_layout: Dictionary = AquiferDepth.layout(SEED, 1, 5)
	var drained_layout: Dictionary = AquiferDepth.layout(SEED, 1, 5, ["p0"])
	var full_aq: FloodedAquifer = _make_aquifer_shell()
	var drained_aq: FloodedAquifer = _make_aquifer_shell()
	for pool: Dictionary in full_layout["pools"]:
		full_aq._draw_pool(pool, str(pool["id"]))
	for pool: Dictionary in drained_layout["pools"]:
		drained_aq._draw_pool(pool, str(pool["id"]))

	var problem: String = ""
	var p0: MeshInstance3D = full_aq._water.get_node_or_null("Pool_p0") as MeshInstance3D
	var p1: MeshInstance3D = full_aq._water.get_node_or_null("Pool_p1") as MeshInstance3D
	var p2: MeshInstance3D = full_aq._water.get_node_or_null("Pool_p2") as MeshInstance3D
	if p0 == null or p1 == null or p2 == null:
		problem = "Missing Pool_p0, Pool_p1, or Pool_p2."
	else:
		var m0: StandardMaterial3D = p0.material_override as StandardMaterial3D
		var m1: StandardMaterial3D = p1.material_override as StandardMaterial3D
		var m2: StandardMaterial3D = p2.material_override as StandardMaterial3D
		var shared_deep: StandardMaterial3D = TunnelLook.flat_mat(TunnelLook.WATER_DEEP)
		var shared_shallow: StandardMaterial3D = TunnelLook.flat_mat(TunnelLook.WATER_SHALLOW)
		var shared_silt: StandardMaterial3D = TunnelLook.flat_mat(TunnelLook.SILT)
		if m0 == m1 or m1 == m2 or m0 == m2:
			problem = "Pools must never share a material instance."
		elif m0 == shared_deep or m0 == shared_shallow or m0 == shared_silt \
				or m1 == shared_deep or m1 == shared_shallow or m1 == shared_silt:
			problem = "A pool used TunnelLook's shared cached material."
		else:
			var m1_before_col: Color = m1.albedo_color
			var m1_before_tr: BaseMaterial3D.Transparency = m1.transparency
			var deep_before_col: Color = shared_deep.albedo_color
			var deep_before_tr: BaseMaterial3D.Transparency = shared_deep.transparency
			# Mutate p0's material in place to ensure no leak to p1 or TunnelLook cache.
			m0.albedo_color = TunnelLook.SILT
			m0.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			if not m1.albedo_color.is_equal_approx(m1_before_col) or m1.transparency != m1_before_tr:
				problem = "Mutating Pool_p0's material leaked into Pool_p1."
			elif not shared_deep.albedo_color.is_equal_approx(deep_before_col) or shared_deep.transparency != deep_before_tr:
				problem = "Mutating Pool_p0's material leaked into TunnelLook's shared cache."
			else:
				var dp0: StandardMaterial3D = (drained_aq._water.get_node("Pool_p0") as MeshInstance3D).material_override as StandardMaterial3D
				var dp1: StandardMaterial3D = (drained_aq._water.get_node("Pool_p1") as MeshInstance3D).material_override as StandardMaterial3D
				if dp0.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or not dp0.albedo_color.is_equal_approx(TunnelLook.SILT):
					problem = "Drained Pool_p0 must use opaque damp silt."
				elif not dp1.albedo_color.is_equal_approx(m1_before_col) or dp1.transparency != m1_before_tr:
					problem = "Draining p0 altered Pool_p1's material."

	_free(full_aq)
	_free(drained_aq)
	return problem


func test_named_nodes_exist_and_collision_is_unchanged() -> String:
	var aq: FloodedAquifer = _make_aquifer_shell()
	aq._depth_props.build_hatch()
	aq._draw_pool({ "rect": AquiferDepth.HUB_POOL, "depth_m": AquiferDepth.DEEP_M[1], "drained": false }, "")
	aq._draw_crate()
	aq._draw_sign()

	var problem: String = ""
	var hub_pool: Node = aq._water.get_node_or_null("Pool_")
	var hub_trim: Node = aq._water.get_node_or_null("PoolTrim_")
	var crate: Node3D = aq._depth_props.get_node_or_null("PumpCrate") as Node3D
	var sign_node: Node3D = aq._depth_props.get_node_or_null("NoticeSign") as Node3D
	var hatch: Node3D = aq._depth_props.get_node_or_null("Hatch") as Node3D
	if hub_pool == null or hub_trim == null:
		problem = "Hub pool slab or rim trim is missing."
	elif crate == null or crate.position != AquiferDepth.crate_position() or crate.get_child_count() < 8:
		problem = "PumpCrate missing, moved, or not restyled."
	elif sign_node == null or sign_node.position != AquiferDepth.sign_position() or sign_node.get_child_count() < 8:
		problem = "NoticeSign missing, moved, or not restyled."
	elif hatch == null:
		problem = "Hub Hatch is missing."
	elif _has_collision(aq._water) or _has_collision(aq._depth_props):
		problem = "Aquifer visual props must not add collision bodies."
	else:
		var hub: PackedStringArray = AquiferDepth.hub_grid()
		var depth_full: Dictionary = AquiferDepth.layout(SEED, 1, 5)
		var depth_dry: Dictionary = AquiferDepth.layout(SEED, 1, 5, ["p0"])
		var p0_cell: Vector2i = (AquiferDepth.pool_in(depth_full, "p0")["rect"] as Rect2i).position
		if not TunnelRock.holds_in(hub, AquiferDepth.crate_position()) \
				or not TunnelRock.holds_in(hub, AquiferDepth.sign_position()) \
				or TunnelRock.holds_in(hub, TunnelRock.at_in(hub, AquiferDepth.HUB_POOL.position)):
			problem = "Hub collision/holds changed for crate, sign, or hub pool."
		elif TunnelRock.holds_in(depth_full["grid"], TunnelRock.at_in(depth_full["grid"], p0_cell)) \
				or not TunnelRock.holds_in(depth_dry["grid"], TunnelRock.at_in(depth_dry["grid"], p0_cell)):
			problem = "Depth 1 collision/holds changed for deep vs drained pool p0."

	_free(aq)
	return problem
