extends RefCounted
## Polar Ice Caves look (feat/ice-look): IceLook builders, Ice Caves scene hub
## and depth 1 visual dressing and glacial rock override, Lava Tubes and Colony
## Mine isolation, zero added collision on decorations, fresh materials, and
## clean teardown with restored GameState.

const SEED: int = 424242


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
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
		"cold_since": GameState.cold_since.duplicate(true),
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
	GameState.cold_since = (saved["cold_since"] as Dictionary).duplicate(true)
	ZoneDepth.local_zone = str(saved["local_zone"])
	ZoneDepth.local_depth = int(saved["local_depth"])
	ZoneDepth.local_layout = (saved["local_layout"] as Dictionary).duplicate(true)
	ZoneDepth.arrive_pending = bool(saved["arrive_pending"])


func test_ice_look_builders_create_visual_nodes_without_collision() -> String:
	var host := Node3D.new()
	var wall: Node3D = IceLook.add_ice_wall(host, Vector3.ZERO, Vector2(2.4, 1.0), 2.5)
	var icicles: Node3D = IceLook.add_icicle_cluster(host, Vector3(0.0, 2.8, 0.0), 2.6, 0.9)
	var frost: Node3D = IceLook.add_frost_patch(host, Vector3(2.0, 0.0, 0.0), Vector2(2.6, 2.0))
	var probe: Node3D = IceLook.add_frozen_probe(host, Vector3(-2.5, 0.0, 0.0))
	var rack: Node3D = IceLook.add_drill_rack(host, Vector3(0.0, 0.0, -3.0))
	var crate: Node3D = IceLook.add_heater_crate(host, Vector3(4.0, 0.0, 0.0))
	var mat_a: StandardMaterial3D = IceLook.ice_mat(IceLook.ICE_PALE)
	var mat_b: StandardMaterial3D = IceLook.ice_mat(IceLook.ICE_PALE)

	var problem: String = ""
	if wall.name != "IceWall" or wall.get_child_count() != IceLook.BANDS.size():
		problem = "IceWall missing name or BANDS.size() direct children (%d)." % wall.get_child_count()
	elif _count_type(icicles, "MeshInstance3D") < 6:
		problem = "IcicleCluster missing cornice or icicle cones."
	elif _count_type(frost, "MeshInstance3D") < 5:
		problem = "FrostPatch missing glazed slabs or rime ridges."
	elif _count_type(probe, "MeshInstance3D") < 10:
		problem = "FrozenProbe missing ice mound or probe parts."
	elif _count_type(rack, "MeshInstance3D") < 16:
		problem = "DrillRack missing frame, core tubes, or auger."
	elif crate.name != "HeaterCrate" or _count_type(crate, "MeshInstance3D") < 14 \
			or _count_type(crate, "OmniLight3D") != 1 or _count_type(crate, "Label3D") != 1:
		problem = "HeaterCrate missing expected name, meshes, warm light, or label."
	elif mat_a == mat_b:
		problem = "IceLook.ice_mat must return fresh uncached materials."
	elif _has_collision(host):
		problem = "IceLook visual builders must never add collision bodies."

	_free(host)
	return problem


func test_ice_caves_scene_builds_with_ice_look_in_hub_and_depth_one() -> String:
	var saved: Dictionary = _save_state()
	var problem: String = ""
	var packed: PackedScene = load("res://scenes/ice_caves.tscn") as PackedScene

	# 1. Hub (depth 0)
	GameState.world_seed = SEED
	GameState.rover_zone = IceDepth.ZONE
	GameState.rover_depth = 0
	GameState.rover_lent = true
	var hub: IceCaves = packed.instantiate() as IceCaves
	_root().add_child(hub)
	var hub_world: Node3D = hub.get_node("WorldView/WorldViewport/World") as Node3D
	var hub_rock: IceRock = hub_world.get_node("Rock") as IceRock
	var hub_blocks: MultiMeshInstance3D = hub_rock.get_node("Blocks") as MultiMeshInstance3D
	var hub_mat: StandardMaterial3D = (hub_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
	var hub_decor: Node3D = hub_world.get_node_or_null("IceDecor") as Node3D
	var hub_crate: Node3D = hub._depth_props.get_node_or_null("HeaterCrate") as Node3D
	var hub_sign: Node3D = hub._depth_props.get_node_or_null("NoticeSign") as Node3D
	var hub_hatch: Node3D = hub._depth_props.get_node_or_null("Hatch") as Node3D

	if not hub_mat.albedo_color.is_equal_approx(IceLook.ROCK_TINT) \
			or not is_equal_approx(hub_mat.roughness, IceLook.ROCK_ROUGHNESS):
		problem = "Hub IceRock material was not styled with IceLook (%s, rough %.2f)." % [hub_mat.albedo_color, hub_mat.roughness]
	elif hub_decor == null or _count_named_prefix(hub_decor, "IcicleCluster") < 2 \
			or _count_named_prefix(hub_decor, "FrostPatch") < 2 \
			or _count_named_prefix(hub_decor, "FrozenProbe") != 1 \
			or _count_named_prefix(hub_decor, "DrillRack") != 1:
		problem = "Hub IceDecor missing icicles, frost patches, frozen probe, or drill rack."
	elif _has_collision(hub_decor):
		problem = "Hub IceDecor added collision bodies."
	elif hub_crate == null or hub_crate.position != IceDepth.crate_position() \
			or _count_type(hub_crate, "OmniLight3D") != 1:
		problem = "Hub HeaterCrate missing, moved, or without warm light."
	elif hub_sign == null or hub_sign.position != IceDepth.sign_position():
		problem = "Hub NoticeSign missing or moved."
	elif hub_hatch == null:
		problem = "Hub Hatch missing."
	_free(hub)

	# 2. Depth 1
	if problem == "":
		GameState.rover_depth = 1
		var depth_scene: IceCaves = packed.instantiate() as IceCaves
		_root().add_child(depth_scene)
		var d_world: Node3D = depth_scene.get_node("WorldView/WorldViewport/World") as Node3D
		var d_rock: IceRock = d_world.get_node("Rock") as IceRock
		var d_blocks: MultiMeshInstance3D = d_rock.get_node("Blocks") as MultiMeshInstance3D
		var d_mat: StandardMaterial3D = (d_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
		var d_decor: Node3D = d_world.get_node_or_null("IceDecor") as Node3D

		if not d_mat.albedo_color.is_equal_approx(IceLook.ROCK_TINT):
			problem = "Depth 1 IceRock was not styled with IceLook.ROCK_TINT."
		elif d_decor == null or _count_named_prefix(d_decor, "IcicleCluster") < 2 \
				or _count_named_prefix(d_decor, "FrostPatch") < 2 \
				or _count_named_prefix(d_decor, "FrozenProbe") != 1 \
				or _count_named_prefix(d_decor, "DrillRack") != 1:
			problem = "Depth 1 IceDecor missing icicles, frost patches, frozen probe, or drill rack."
		elif _has_collision(d_decor):
			problem = "Depth 1 IceDecor added collision bodies."
		elif _count_named_prefix(depth_scene._depth_props, "Find_") != IceDepth.find_count():
			problem = "Depth 1 finds count changed."
		_free(depth_scene)

	_restore_state(saved)
	return problem


func test_lava_tubes_and_colony_mine_do_not_get_ice_look() -> String:
	var saved: Dictionary = _save_state()
	var brass_before: Color = TunnelLook.flat_mat(TunnelLook.BRASS).albedo_color
	var steel_before: Color = TunnelLook.flat_mat(TunnelLook.STEEL).albedo_color
	var problem: String = ""

	# 1. Lava Tubes
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
	if t_rock is IceRock:
		problem = "Lava Tubes Rock must not be an IceRock."
	elif not t_mat.albedo_color.is_equal_approx(Color.WHITE):
		problem = "Lava Tubes rock material was tinted: %s" % [t_mat.albedo_color]
	elif t_world.get_node_or_null("IceDecor") != null:
		problem = "Lava Tubes scene must not have IceDecor."
	_free(tubes)

	# 2. Colony Mine
	if problem == "":
		GameState.rover_zone = MineDepth.ZONE
		GameState.rover_depth = 0
		var mine_packed: PackedScene = load("res://scenes/colony_mine.tscn") as PackedScene
		var mine: Node = mine_packed.instantiate()
		_root().add_child(mine)
		var m_world: Node3D = mine.get_node("WorldView/WorldViewport/World") as Node3D
		var m_rock: TunnelRock = m_world.get_node("Rock") as TunnelRock
		var m_blocks: MultiMeshInstance3D = m_rock.get_node("Blocks") as MultiMeshInstance3D
		var m_mat: StandardMaterial3D = (m_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
		if m_rock is IceRock or not (m_rock is MineRock):
			problem = "Colony Mine Rock must remain MineRock."
		elif not m_mat.albedo_color.is_equal_approx(MineLook.ROCK_TINT):
			problem = "Colony Mine rock material was altered: %s" % [m_mat.albedo_color]
		elif m_world.get_node_or_null("IceDecor") != null:
			problem = "Colony Mine scene must not have IceDecor."
		_free(mine)

	if problem == "":
		if not TunnelLook.flat_mat(TunnelLook.BRASS).albedo_color.is_equal_approx(brass_before) \
				or not TunnelLook.flat_mat(TunnelLook.STEEL).albedo_color.is_equal_approx(steel_before):
			problem = "TunnelLook shared materials were mutated."

	_restore_state(saved)
	return problem
