extends RefCounted
## Colony Mine look (feat/mine-look): MineLook builders, Mine scene hub and
## depth 1 visual dressing and rock tinting, Lava Tubes isolation, zero added
## collision on decorations, and clean teardown with restored GameState.

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


func _count_type(node: Node, script_type: String) -> int:
	var n: int = 1 if node.get_class() == script_type else 0
	for child: Node in node.get_children():
		n += _count_type(child, script_type)
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
		"rooms_shored": GameState.rooms_shored.duplicate(true),
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
	GameState.rooms_shored = (saved["rooms_shored"] as Dictionary).duplicate(true)
	ZoneDepth.local_zone = str(saved["local_zone"])
	ZoneDepth.local_depth = int(saved["local_depth"])
	ZoneDepth.local_layout = (saved["local_layout"] as Dictionary).duplicate(true)
	ZoneDepth.arrive_pending = bool(saved["arrive_pending"])


func test_mine_look_builders_create_visual_nodes_without_collision() -> String:
	var host := Node3D.new()
	var timber: Node3D = MineLook.add_timber_set(host, Vector3.ZERO, 5.4, 2.9, 0.0, true)
	var rail: Node3D = MineLook.add_rail_track(host, Vector3(0.0, 0.0, 2.0), 6.0, 0.0, true)
	var lamp: Node3D = MineLook.add_dead_lamp(host, Vector3(0.0, 2.8, 0.0))
	var sign_node: Node3D = MineLook.add_stencil_sign(host, Vector3(2.0, 0.0, 0.0))
	var rubble: Node3D = MineLook.add_mine_rubble(host, Vector3(-2.0, 0.0, 0.0), 1.5)
	var arch: Node3D = MineLook.add_shored_arch(host, Vector3(-4.0, 0.0, 0.0), 3.0, 2.2)
	var crate: Node3D = MineLook.build_prop_crate(Vector3(4.0, 0.0, 0.0))
	host.add_child(crate)

	var problem: String = ""
	if _count_type(timber, "MeshInstance3D") < 10 or _count_named_prefix(timber, "DeadLamp") != 1:
		problem = "TimberSet missing expected meshes or hanging dead lamp."
	elif _count_type(rail, "MeshInstance3D") < 10:
		problem = "RailTrack missing expected sleepers/rails."
	elif _count_type(lamp, "MeshInstance3D") < 5 or _count_type(lamp, "OmniLight3D") != 0:
		problem = "DeadLamp must have meshes and zero OmniLight3D nodes."
	elif _count_type(sign_node, "MeshInstance3D") < 6 or _count_type(sign_node, "Label3D") < 2:
		problem = "StencilSign missing backing meshes or stencil labels."
	elif _count_type(rubble, "MeshInstance3D") < 8:
		problem = "Mine rubble missing expected boulders/timbers."
	elif _count_type(arch, "MeshInstance3D") < 10:
		problem = "Shored arch missing expected timber posts/beams."
	elif crate.name != "PropCrate" or _count_type(crate, "MeshInstance3D") < 12 or _count_type(crate, "Label3D") != 1:
		problem = "PropCrate missing expected name, meshes, or label."
	elif _has_collision(host):
		problem = "MineLook visual builders must never add collision bodies."

	_free(host)
	return problem


func test_colony_mine_scene_builds_with_mine_look_in_hub_and_depth_one() -> String:
	var saved: Dictionary = _save_state()
	var problem: String = ""
	var packed: PackedScene = load("res://scenes/colony_mine.tscn") as PackedScene

	# 1. Hub (depth 0)
	GameState.world_seed = SEED
	GameState.rover_zone = MineDepth.ZONE
	GameState.rover_depth = 0
	GameState.rover_lent = true
	var hub: ColonyMine = packed.instantiate() as ColonyMine
	_root().add_child(hub)
	var hub_world: Node3D = hub.get_node("WorldView/WorldViewport/World") as Node3D
	var hub_rock: MineRock = hub_world.get_node("Rock") as MineRock
	var hub_blocks: MultiMeshInstance3D = hub_rock.get_node("Blocks") as MultiMeshInstance3D
	var hub_mat: StandardMaterial3D = (hub_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
	var hub_decor: Node3D = hub_world.get_node_or_null("MineDecor") as Node3D
	var hub_crate: Node3D = hub._depth_props.get_node_or_null("PropCrate") as Node3D
	var hub_sign: Node3D = hub._depth_props.get_node_or_null("NoticeSign") as Node3D
	var hub_hatch: Node3D = hub._depth_props.get_node_or_null("Hatch") as Node3D

	if not hub_mat.albedo_color.is_equal_approx(MineLook.ROCK_TINT):
		problem = "Hub MineRock was not tinted with MineLook.ROCK_TINT: %s" % [hub_mat.albedo_color]
	elif hub_decor == null or _count_named_prefix(hub_decor, "TimberSet") < 3 \
			or _count_named_prefix(hub_decor, "RailTrack") < 1 \
			or _count_named_prefix(hub_decor, "DeadLamp") < 1 \
			or _count_named_prefix(hub_decor, "StencilSign") < 1:
		problem = "Hub MineDecor missing timber sets, rail track, dead lamp, or stencil sign."
	elif _has_collision(hub_decor):
		problem = "Hub MineDecor added collision bodies."
	elif hub_crate == null or hub_crate.position != MineDepth.crate_position():
		problem = "Hub PropCrate missing or moved."
	elif hub_sign == null or hub_sign.position != MineDepth.sign_position():
		problem = "Hub NoticeSign missing or moved."
	elif hub_hatch == null:
		problem = "Hub Hatch missing."
	_free(hub)

	# 2. Depth 1 (with one shored room and at least one unshored rockfall if available)
	if problem == "":
		var day: int = GameClock.get_day_index()
		var layout: Dictionary = MineDepth.layout(SEED, 1, day)
		var first_id: String = str((layout["rockfalls"][0] as Dictionary)["id"])
		GameState.rooms_shored = ZoneDepth.with_taken({}, MineDepth.ZONE, day, first_id)
		GameState.rover_depth = 1
		var depth_scene: ColonyMine = packed.instantiate() as ColonyMine
		_root().add_child(depth_scene)
		var d_world: Node3D = depth_scene.get_node("WorldView/WorldViewport/World") as Node3D
		var d_rock: MineRock = d_world.get_node("Rock") as MineRock
		var d_blocks: MultiMeshInstance3D = d_rock.get_node("Blocks") as MultiMeshInstance3D
		var d_mat: StandardMaterial3D = (d_blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
		var d_decor: Node3D = d_world.get_node_or_null("MineDecor") as Node3D
		var d_falls: Node3D = d_world.get_node_or_null("Rockfalls") as Node3D

		if not d_mat.albedo_color.is_equal_approx(MineLook.ROCK_TINT):
			problem = "Depth 1 MineRock was not tinted with MineLook.ROCK_TINT."
		elif d_decor == null or _count_named_prefix(d_decor, "TimberSet") < 2 \
				or _count_named_prefix(d_decor, "RailTrack") < 1 \
				or _count_named_prefix(d_decor, "StencilSign") < 1:
			problem = "Depth 1 MineDecor missing timber sets, rail track, or stencil sign."
		elif _has_collision(d_decor) or _has_collision(d_falls):
			problem = "Depth 1 MineDecor or Rockfalls added collision bodies."
		elif _count_named_prefix(d_falls, "SupportArch") < 1:
			problem = "Depth 1 shored room did not build a SupportArch."
		_free(depth_scene)

	_restore_state(saved)
	return problem


func test_lava_tubes_does_not_get_mine_look() -> String:
	var saved: Dictionary = _save_state()
	var brass_before: Color = TunnelLook.flat_mat(TunnelLook.BRASS).albedo_color
	GameState.world_seed = SEED
	GameState.rover_zone = ZoneDepth.ZONE
	GameState.rover_depth = 0
	GameState.rover_lent = true

	var packed: PackedScene = load("res://scenes/basalt_tunnels.tscn") as PackedScene
	var tubes: Node = packed.instantiate()
	_root().add_child(tubes)
	var world: Node3D = tubes.get_node("WorldView/WorldViewport/World") as Node3D
	var rock: TunnelRock = world.get_node("Rock") as TunnelRock
	var blocks: MultiMeshInstance3D = rock.get_node("Blocks") as MultiMeshInstance3D
	var mat: StandardMaterial3D = (blocks.multimesh.mesh as BoxMesh).material as StandardMaterial3D
	var mine_decor: Node = world.get_node_or_null("MineDecor")

	var problem: String = ""
	if rock is MineRock:
		problem = "Lava Tubes Rock must not be a MineRock."
	elif not mat.albedo_color.is_equal_approx(Color.WHITE):
		problem = "Lava Tubes rock material was tinted: %s" % [mat.albedo_color]
	elif mine_decor != null:
		problem = "Lava Tubes scene must not have MineDecor."
	elif not TunnelLook.flat_mat(TunnelLook.BRASS).albedo_color.is_equal_approx(brass_before):
		problem = "TunnelLook shared brass material was mutated."

	_free(tubes)
	_restore_state(saved)
	return problem
