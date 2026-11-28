extends RefCounted
## Flooded Aquifer look (feat/aquifer-look): AquiferLook builders, AquiferRock
## wet dark teal-grey rock styling, deterministic hub & depth 1 builds,
## per-pool unique materials (no shared-material leak), unchanged collision and
## Area3D counts, pool/valve/find positions, <= 2 new lights per scene, palette
## distinctness from MineLook and IceLook, and sibling-zone isolation.

const SEED: int = 424242


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child: Node in node.get_children():
		if _has_collision(child):
			return true
	return false


func _count_type(node: Node, class_str: String) -> int:
	var n: int = 1 if node.get_class() == class_str else 0
	for child: Node in node.get_children():
		n += _count_type(child, class_str)
	return n


func _count_lights(node: Node) -> int:
	var n: int = 1 if node is Light3D else 0
	for child: Node in node.get_children():
		n += _count_lights(child)
	return n


func _count_named_prefix(node: Node, prefix: String) -> int:
	var n: int = 1 if String(node.name).begins_with(prefix) else 0
	for child: Node in node.get_children():
		n += _count_named_prefix(child, prefix)
	return n


func _save_state() -> Dictionary:
	return {
		"rover_zone": GameState.rover_zone,
		"rover_depth": GameState.rover_depth,
		"rover_lent": GameState.rover_lent,
		"world_seed": GameState.world_seed,
		"pools_drained": GameState.pools_drained.duplicate(true),
		"valves_shut": GameState.valves_shut.duplicate(true),
		"finds_taken": GameState.finds_taken.duplicate(true),
		"local_zone": ZoneDepth.local_zone,
		"local_depth": ZoneDepth.local_depth,
		"local_layout": ZoneDepth.local_layout.duplicate(true),
		"arrive_pending": ZoneDepth.arrive_pending,
	}


func _restore_state(saved: Dictionary) -> void:
	GameState.rover_zone = str(saved["rover_zone"])
	GameState.rover_depth = int(saved["rover_depth"])
	GameState.rover_lent = bool(saved["rover_lent"])
	GameState.world_seed = int(saved["world_seed"])
	GameState.pools_drained = (saved["pools_drained"] as Dictionary).duplicate(true)
	GameState.valves_shut = (saved["valves_shut"] as Dictionary).duplicate(true)
	GameState.finds_taken = (saved["finds_taken"] as Dictionary).duplicate(true)
	ZoneDepth.local_zone = str(saved["local_zone"])
	ZoneDepth.local_depth = int(saved["local_depth"])
	ZoneDepth.local_layout = (saved["local_layout"] as Dictionary).duplicate(true)
	ZoneDepth.arrive_pending = bool(saved["arrive_pending"])


func _make_aquifer_shell() -> FloodedAquifer:
	var aq := FloodedAquifer.new()
	aq._water = Node3D.new()
	aq._water.name = "Water"
	aq.add_child(aq._water)
	aq._seals = Node3D.new()
	aq._seals.name = "Seals"
	aq.add_child(aq._seals)
	aq._depth_props = ZoneDepthProps.new()
	aq._depth_props.name = "DepthProps"
	aq.add_child(aq._depth_props)
	aq._decor = Node3D.new()
	aq._decor.name = "AquiferDecor"
	aq.add_child(aq._decor)
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
		elif child is Light3D:
			var l := child as Light3D
			lines.append("%s|L|%s|%s" % [label, str(l.position.snapped(Vector3(0.001, 0.001, 0.001))), l.light_color.to_html(false)])
		else:
			lines.append(label)
			lines.append_array(_snapshot_tree(child))
	return lines


func _snapshot_blocks(rock: Node3D) -> Array[String]:
	var out: Array[String] = []
	var blocks: MultiMeshInstance3D = rock.get_node_or_null("Blocks") as MultiMeshInstance3D
	if blocks == null or blocks.multimesh == null:
		return out
	var mm: MultiMesh = blocks.multimesh
	for i: int in mm.instance_count:
		var p: Vector3 = mm.get_instance_transform(i).origin.snapped(Vector3(0.01, 0.01, 0.01))
		out.append("%s|%s" % [str(p), mm.get_instance_color(i).to_html(false)])
	return out


func test_aquifer_look_builders_create_visual_nodes_without_collision() -> String:
	var host := Node3D.new()
	var stalactites: Node3D = AquiferLook.add_stalactite_cluster(host, Vector3(0.0, 3.0, 0.0), 3.0, 0.9)
	var pipes: Node3D = AquiferLook.add_pipe_run(host, Vector3(2.0, 0.0, 0.0), 5.0, 1.6)
	var streak: Node3D = AquiferLook.add_mineral_streak(host, Vector3(-2.0, 0.0, 0.0), 1.4, 2.4)
	var crate: Node3D = AquiferLook.build_pump_crate(Vector3(4.0, 0.0, 0.0))
	host.add_child(crate)
	var valve: Node3D = AquiferLook.build_seal_valve(Vector3(-4.0, 0.0, 0.0), "s0", Vector2(-6.0, 0.0))
	host.add_child(valve)

	var flat_a: StandardMaterial3D = AquiferLook.flat_mat(AquiferLook.PIPE_GREEN)
	var flat_b: StandardMaterial3D = AquiferLook.flat_mat(AquiferLook.PIPE_GREEN)
	var water_a: StandardMaterial3D = AquiferLook.water_mat(AquiferLook.WATER_SHALLOW, AquiferLook.WATER_SHALLOW_ROUGHNESS, AquiferLook.WATER_SHALLOW_ALPHA)
	var water_b: StandardMaterial3D = AquiferLook.water_mat(AquiferLook.WATER_SHALLOW, AquiferLook.WATER_SHALLOW_ROUGHNESS, AquiferLook.WATER_SHALLOW_ALPHA)

	var problem: String = ""
	if _count_type(stalactites, "MeshInstance3D") < 7:
		problem = "StalactiteCluster missing cornice, cones, or drip tips."
	elif _count_type(pipes, "MeshInstance3D") < 8:
		problem = "PipeRun missing pipes, flanges, or brackets."
	elif _count_type(streak, "MeshInstance3D") < 4:
		problem = "MineralStreak missing pale mineral strips."
	elif crate.name != "PumpCrate" or _count_type(crate, "MeshInstance3D") < 12 or _count_type(crate, "Label3D") != 1:
		problem = "PumpCrate missing expected name, meshes, or label."
	elif valve.name != "Valve_s0" or valve.get_node_or_null("ValveWheel") == null or valve.get_node_or_null("WaterJet") == null:
		problem = "Seal valve missing Valve_s0, ValveWheel, or WaterJet."
	elif flat_a != flat_b:
		problem = "AquiferLook.flat_mat must cache read-only materials."
	elif water_a == water_b:
		problem = "AquiferLook.water_mat must return fresh unique materials."
	elif _has_collision(host):
		problem = "AquiferLook visual builders must never add collision bodies."

	_free(host)
	return problem


func test_builds_are_deterministic_for_hub_and_depth_one() -> String:
	var saved: Dictionary = _save_state()
	var problem: String = ""
	var packed: PackedScene = load("res://scenes/flooded_aquifer.tscn") as PackedScene
	GameState.world_seed = SEED
	GameState.rover_zone = AquiferDepth.ZONE
	GameState.rover_lent = true
	GameState.pools_drained = {}
	GameState.valves_shut = {}
	GameState.finds_taken = {}

	for depth: int in [0, 1]:
		GameState.rover_depth = depth
		var a: FloodedAquifer = packed.instantiate() as FloodedAquifer
		_root().add_child(a)
		var a_world: Node3D = a.get_node("WorldView/WorldViewport/World") as Node3D
		var snap_a_water: Array[String] = _snapshot_tree(a._water)
		var snap_a_seals: Array[String] = _snapshot_tree(a._seals)
		var snap_a_decor: Array[String] = _snapshot_tree(a._decor)
		var snap_a_props: Array[String] = _snapshot_tree(a._depth_props)
		var snap_a_blocks: Array[String] = _snapshot_blocks(a_world.get_node("Rock") as Node3D)
		_free(a)

		var b: FloodedAquifer = packed.instantiate() as FloodedAquifer
		_root().add_child(b)
		var b_world: Node3D = b.get_node("WorldView/WorldViewport/World") as Node3D
		var snap_b_water: Array[String] = _snapshot_tree(b._water)
		var snap_b_seals: Array[String] = _snapshot_tree(b._seals)
		var snap_b_decor: Array[String] = _snapshot_tree(b._decor)
		var snap_b_props: Array[String] = _snapshot_tree(b._depth_props)
		var snap_b_blocks: Array[String] = _snapshot_blocks(b_world.get_node("Rock") as Node3D)
		_free(b)

		if snap_a_decor.is_empty() or snap_a_blocks.is_empty():
			problem = "Depth %d produced empty decor or rock blocks." % depth
			break
		if snap_a_water != snap_b_water or snap_a_seals != snap_b_seals \
				or snap_a_decor != snap_b_decor or snap_a_props != snap_b_props \
				or snap_a_blocks != snap_b_blocks:
			problem = "Depth %d build was not deterministic across identical runs." % depth
			break

	_restore_state(saved)
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
		var shared_deep: StandardMaterial3D = AquiferLook.flat_mat(AquiferLook.WATER_DEEP)
		var shared_shallow: StandardMaterial3D = AquiferLook.flat_mat(AquiferLook.WATER_SHALLOW)
		var shared_silt: StandardMaterial3D = AquiferLook.flat_mat(AquiferLook.SILT_DAMP)
		var tunnel_deep: StandardMaterial3D = TunnelLook.flat_mat(TunnelLook.WATER_DEEP)
		if m0 == m1 or m1 == m2 or m0 == m2:
			problem = "Pools must never share a material instance."
		elif m0 == shared_deep or m0 == shared_shallow or m0 == shared_silt or m0 == tunnel_deep \
				or m1 == shared_deep or m1 == shared_shallow or m1 == shared_silt or m1 == tunnel_deep:
			problem = "A pool used a shared cached material."
		else:
			var m1_before_col: Color = m1.albedo_color
			var m1_before_tr: BaseMaterial3D.Transparency = m1.transparency
			var deep_before_col: Color = shared_deep.albedo_color
			var deep_before_tr: BaseMaterial3D.Transparency = shared_deep.transparency
			m0.albedo_color = AquiferLook.SILT_DAMP
			m0.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			if not m1.albedo_color.is_equal_approx(m1_before_col) or m1.transparency != m1_before_tr:
				problem = "Mutating Pool_p0's material leaked into Pool_p1."
			elif not shared_deep.albedo_color.is_equal_approx(deep_before_col) or shared_deep.transparency != deep_before_tr:
				problem = "Mutating Pool_p0's material leaked into AquiferLook's shared cache."
			else:
				var dp0: StandardMaterial3D = (drained_aq._water.get_node("Pool_p0") as MeshInstance3D).material_override as StandardMaterial3D
				var dp1: StandardMaterial3D = (drained_aq._water.get_node("Pool_p1") as MeshInstance3D).material_override as StandardMaterial3D
				if dp0.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or not dp0.albedo_color.is_equal_approx(AquiferLook.SILT_DAMP):
					problem = "Drained Pool_p0 must use opaque damp silt."
				elif not dp1.albedo_color.is_equal_approx(m1_before_col) or dp1.transparency != m1_before_tr:
					problem = "Draining p0 altered Pool_p1's material."

	_free(full_aq)
	_free(drained_aq)
	return problem


func test_collision_area_positions_and_light_budget_unchanged_in_hub_and_depth_one() -> String:
	var saved: Dictionary = _save_state()
	var problem: String = ""
	var packed: PackedScene = load("res://scenes/flooded_aquifer.tscn") as PackedScene
	var day: int = GameClock.get_day_index()
	GameState.world_seed = SEED
	GameState.rover_zone = AquiferDepth.ZONE
	GameState.rover_lent = true
	GameState.pools_drained = {}
	GameState.valves_shut = {}
	GameState.finds_taken = {}

	# 1. Hub (depth 0)
	GameState.rover_depth = 0
	var hub: FloodedAquifer = packed.instantiate() as FloodedAquifer
	_root().add_child(hub)
	var hub_world: Node3D = hub.get_node("WorldView/WorldViewport/World") as Node3D
	var hub_rock: AquiferRock = hub_world.get_node("Rock") as AquiferRock
	var hub_blocks: MultiMeshInstance3D = hub_rock.get_node("Blocks") as MultiMeshInstance3D
	var hub_mat: StandardMaterial3D = (hub_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
	var hub_pool: MeshInstance3D = hub._water.get_node_or_null("Pool_") as MeshInstance3D
	var hub_crate: Node3D = hub._depth_props.get_node_or_null("PumpCrate") as Node3D
	var hub_sign: Node3D = hub._depth_props.get_node_or_null("NoticeSign") as Node3D
	var hub_hatch: Node3D = hub._depth_props.get_node_or_null("Hatch") as Node3D
	var hub_box: Rect2 = AquiferDepth.pool_metres({ "rect": AquiferDepth.HUB_POOL })
	var hub_expected_centre: Vector2 = hub_box.get_center()
	var hub_added_lights: int = _count_lights(hub._water) + _count_lights(hub._decor) + _count_lights(hub._seals) + _count_lights(hub._depth_props)

	# Baseline TunnelRock collider count on the exact same hub grid.
	var base_hub_rock := TunnelRock.new()
	_root().add_child(base_hub_rock)
	var expected_hub_shapes: int = _count_type(base_hub_rock, "CollisionShape3D")
	_free(base_hub_rock)

	if not hub_mat.albedo_color.is_equal_approx(AquiferLook.ROCK_TINT) \
			or not is_equal_approx(hub_mat.roughness, AquiferLook.ROCK_ROUGHNESS):
		problem = "Hub AquiferRock material not styled with AquiferLook."
	elif _count_type(hub_world, "Area3D") != 1:
		problem = "Hub Area3D count changed (expected 1 ExitPad, got %d)." % _count_type(hub_world, "Area3D")
	elif _count_type(hub_rock, "CollisionShape3D") != expected_hub_shapes:
		problem = "Hub Rock CollisionShape3D count changed (%d vs %d)." % [_count_type(hub_rock, "CollisionShape3D"), expected_hub_shapes]
	elif _has_collision(hub._decor) or _has_collision(hub._water) or _has_collision(hub._seals) or _has_collision(hub._depth_props):
		problem = "Hub visual nodes added collision bodies or shapes."
	elif hub_added_lights > 2:
		problem = "Hub added %d lights (max 2 allowed)." % hub_added_lights
	elif _count_named_prefix(hub._decor, "StalactiteCluster") < 2 or _count_named_prefix(hub._decor, "PipeRun") < 2:
		problem = "Hub AquiferDecor missing stalactite clusters or pipe runs."
	elif hub_pool == null or not Vector2(hub_pool.position.x, hub_pool.position.z).is_equal_approx(hub_expected_centre):
		problem = "Hub pool missing or moved."
	elif hub_crate == null or hub_crate.position != AquiferDepth.crate_position():
		problem = "Hub PumpCrate missing or moved."
	elif hub_sign == null or hub_sign.position != AquiferDepth.sign_position():
		problem = "Hub NoticeSign missing or moved."
	elif hub_hatch == null or hub_hatch.position != AquiferDepth.hatch_position():
		problem = "Hub Hatch missing or moved."
	_free(hub)

	# 2. Depth 1
	if problem == "":
		GameState.rover_depth = 1
		var depth_scene: FloodedAquifer = packed.instantiate() as FloodedAquifer
		_root().add_child(depth_scene)
		var d_world: Node3D = depth_scene.get_node("WorldView/WorldViewport/World") as Node3D
		var d_rock: AquiferRock = d_world.get_node("Rock") as AquiferRock
		var d_blocks: MultiMeshInstance3D = d_rock.get_node("Blocks") as MultiMeshInstance3D
		var d_mat: StandardMaterial3D = (d_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
		var d_added_lights: int = _count_lights(depth_scene._water) + _count_lights(depth_scene._decor) + _count_lights(depth_scene._seals) + _count_lights(depth_scene._depth_props)
		var layout: Dictionary = AquiferDepth.layout(SEED, 1, day)

		var base_d_rock := TunnelRock.new()
		_root().add_child(base_d_rock)
		var expected_d_shapes: int = _count_type(base_d_rock, "CollisionShape3D")
		_free(base_d_rock)

		if not d_mat.albedo_color.is_equal_approx(AquiferLook.ROCK_TINT):
			problem = "Depth 1 AquiferRock material not styled with AquiferLook.ROCK_TINT."
		elif _count_type(d_world, "Area3D") != 1:
			problem = "Depth 1 Area3D count changed (expected 1 ExitPad, got %d)." % _count_type(d_world, "Area3D")
		elif _count_type(d_rock, "CollisionShape3D") != expected_d_shapes:
			problem = "Depth 1 Rock CollisionShape3D count changed (%d vs %d)." % [_count_type(d_rock, "CollisionShape3D"), expected_d_shapes]
		elif _has_collision(depth_scene._decor) or _has_collision(depth_scene._water) \
				or _has_collision(depth_scene._seals) or _has_collision(depth_scene._depth_props):
			problem = "Depth 1 visual nodes added collision bodies or shapes."
		elif d_added_lights > 2:
			problem = "Depth 1 added %d lights (max 2 allowed)." % d_added_lights
		elif _count_named_prefix(depth_scene._decor, "StalactiteCluster") < 2 or _count_named_prefix(depth_scene._decor, "PipeRun") < 2:
			problem = "Depth 1 AquiferDecor missing stalactite clusters or pipe runs."

		if problem == "":
			# Verify every pool position & size unchanged.
			for pool: Dictionary in layout["pools"]:
				var pid: String = str(pool["id"])
				var slab: MeshInstance3D = depth_scene._water.get_node_or_null("Pool_" + pid) as MeshInstance3D
				var pbox: Rect2 = AquiferDepth.pool_metres(pool)
				var pmid: Vector2 = pbox.get_center()
				var bm: BoxMesh = slab.mesh as BoxMesh if slab != null else null
				if slab == null or bm == null \
						or not Vector2(slab.position.x, slab.position.z).is_equal_approx(pmid) \
						or not Vector2(bm.size.x, bm.size.z).is_equal_approx(pbox.size):
					problem = "Depth 1 pool %s position or size changed." % pid
					break

		if problem == "":
			# Verify every open seal valve position unchanged.
			for seal: Dictionary in layout["seals"]:
				var sid: String = str(seal["id"])
				var valve: Node3D = depth_scene._seals.find_child("Valve_" + sid, true, false) as Node3D
				if valve == null or not valve.position.is_equal_approx(AquiferDepth.seal_position(seal)):
					problem = "Depth 1 valve %s missing or moved." % sid
					break

		if problem == "":
			# Verify every find spot count and position unchanged.
			var finds: Array = layout["finds"]
			if _count_named_prefix(depth_scene._depth_props, "Find_") != finds.size():
				problem = "Depth 1 find count changed."
			else:
				for find: Dictionary in finds:
					var fid: String = str(find["id"])
					var fnode: Node3D = depth_scene._depth_props.find_node(fid)
					var expected_pos: Vector3 = TunnelRock.at_in(layout["grid"], find["cell"])
					if fnode == null or not fnode.position.is_equal_approx(expected_pos):
						problem = "Depth 1 find %s missing or moved." % fid
						break

		_free(depth_scene)

	_restore_state(saved)
	return problem


func test_aquifer_palette_is_distinct_from_mine_and_ice() -> String:
	var aq_rock := Vector3(AquiferLook.ROCK_TINT.r, AquiferLook.ROCK_TINT.g, AquiferLook.ROCK_TINT.b)
	var mine_rock := Vector3(MineLook.ROCK_TINT.r, MineLook.ROCK_TINT.g, MineLook.ROCK_TINT.b)
	var ice_rock := Vector3(IceLook.ROCK_TINT.r, IceLook.ROCK_TINT.g, IceLook.ROCK_TINT.b)

	if aq_rock.distance_to(mine_rock) < 0.25:
		return "Aquifer ROCK_TINT is too close to MineLook.ROCK_TINT."
	if aq_rock.distance_to(ice_rock) < 0.20:
		return "Aquifer ROCK_TINT is too close to IceLook.ROCK_TINT."
	if absf(AquiferLook.ROCK_ROUGHNESS - MineLook.ROCK_ROUGHNESS) < 0.20:
		return "Aquifer ROCK_ROUGHNESS is too close to MineLook.ROCK_ROUGHNESS."
	if absf(AquiferLook.ROCK_ROUGHNESS - IceLook.ROCK_ROUGHNESS) < 0.10:
		return "Aquifer ROCK_ROUGHNESS is too close to IceLook.ROCK_ROUGHNESS."
	if AquiferLook.WET_ROCK_TEAL.is_equal_approx(MineLook.ORE_RUST) \
			or AquiferLook.WET_ROCK_TEAL.is_equal_approx(IceLook.ICE_BLUE) \
			or AquiferLook.PIPE_GREEN.is_equal_approx(MineLook.TIMBER_OLD) \
			or AquiferLook.PIPE_GREEN.is_equal_approx(IceLook.ICE_DEEP):
		return "Aquifer primary palette colours collide with MineLook or IceLook."
	return ""


func test_sibling_zones_do_not_get_aquifer_look() -> String:
	var saved: Dictionary = _save_state()
	var brass_before: Color = TunnelLook.flat_mat(TunnelLook.BRASS).albedo_color
	var problem: String = ""

	GameState.world_seed = SEED
	GameState.rover_zone = ZoneDepth.ZONE
	GameState.rover_depth = 0
	GameState.rover_lent = true
	var tubes_packed: PackedScene = load("res://scenes/basalt_tunnels.tscn") as PackedScene
	var tubes: Node = tubes_packed.instantiate()
	_root().add_child(tubes)
	var t_world: Node3D = tubes.get_node("WorldView/WorldViewport/World") as Node3D
	var t_rock: TunnelRock = t_world.get_node("Rock") as TunnelRock
	var t_blocks: MultiMeshInstance3D = t_rock.get_node("Blocks") as MultiMeshInstance3D
	var t_mat: StandardMaterial3D = (t_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
	if t_rock is AquiferRock:
		problem = "Lava Tubes Rock must not be an AquiferRock."
	elif not t_mat.albedo_color.is_equal_approx(Color.WHITE):
		problem = "Lava Tubes rock material was tinted: %s" % [t_mat.albedo_color]
	elif t_world.get_node_or_null("AquiferDecor") != null:
		problem = "Lava Tubes scene must not have AquiferDecor."
	elif not TunnelLook.flat_mat(TunnelLook.BRASS).albedo_color.is_equal_approx(brass_before):
		problem = "TunnelLook shared brass material was mutated."
	_free(tubes)

	_restore_state(saved)
	return problem
