extends RefCounted
## Lava Tubes rock walls look (feat/tunnel-walls-look): deterministic cell look,
## unchanged collision and holds(), near-camera fade on arch lintels and timber
## ribs, and clean node teardown.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _make_rock() -> TunnelRock:
	var rock := TunnelRock.new()
	_root().add_child(rock)
	return rock


func test_tunnel_blocks_are_deterministic_across_builds() -> String:
	var first: TunnelRock = _make_rock()
	var second: TunnelRock = _make_rock()
	var mm1: MultiMesh = (first.get_node("Blocks") as MultiMeshInstance3D).multimesh
	var mm2: MultiMesh = (second.get_node("Blocks") as MultiMeshInstance3D).multimesh
	var problem: String = ""
	if mm1.instance_count != mm2.instance_count or mm1.instance_count == 0:
		problem = "Block counts must match and be non-zero: %d vs %d" % [mm1.instance_count, mm2.instance_count]
	else:
		for i: int in mm1.instance_count:
			if not mm1.get_instance_transform(i).is_equal_approx(mm2.get_instance_transform(i)):
				problem = "Block transform %d differed across builds." % i
				break
			if not mm1.get_instance_color(i).is_equal_approx(mm2.get_instance_color(i)):
				problem = "Block color %d differed across builds." % i
				break
	_free(first)
	_free(second)
	return problem


func test_collision_and_holds_are_unchanged_for_sample_cells() -> String:
	var rock: TunnelRock = _make_rock()
	var problem: String = ""
	var start: Vector3 = GameState.TUNNEL_START.origin
	if not TunnelRock.holds(start) or not TunnelRock.holds(GameState.TUNNEL_EXIT):
		problem = "Start and exit must remain driveable floor."
	elif TunnelRock.holds(TunnelRock.at(Vector2i(0, 0))):
		problem = "Outer rock corner (0, 0) must not hold the rover."
	elif not TunnelRock.in_deep(TunnelRock.SUMP):
		problem = "SUMP centre must remain deep water."
	else:
		var rock_bodies: int = 0
		var arch_bodies: int = 0
		for child: Node in rock.get_children():
			if child is StaticBody3D:
				var body := child as StaticBody3D
				if body.name.begins_with("Rock") and body.collision_layer == (TunnelRock.LAYER_WORLD | TunnelRock.LAYER_OCCLUDER):
					rock_bodies += 1
				elif body.name.begins_with("Arch") and body.collision_layer == TunnelRock.LAYER_OCCLUDER:
					arch_bodies += 1
		if rock_bodies == 0 or arch_bodies == 0:
			problem = "Expected Rock and Arch colliders, got %d and %d." % [rock_bodies, arch_bodies]
	_free(rock)
	return problem


func test_near_camera_fade_lowers_alpha_on_lintels_and_ribs() -> String:
	var rock: TunnelRock = _make_rock()
	var dummy := Node3D.new()
	_root().add_child(dummy)
	rock.rover = dummy
	var problem: String = ""
	if rock._lintels.is_empty():
		problem = "TunnelRock must have at least one arch lintel to fade."
	else:
		var middle: Vector3 = rock._lintels.keys()[0]
		var lintel: StandardMaterial3D = rock._lintels[middle]
		var trim: StandardMaterial3D = rock._lintel_trims.get(middle)
		dummy.global_position = middle
		for _step: int in 10:
			rock._process(0.1)
		if lintel.albedo_color.a > TunnelRock.FADE_ALPHA + 0.05:
			problem = "Lintel did not fade near rover: alpha=%f" % lintel.albedo_color.a
		elif trim == null or trim.albedo_color.a > TunnelRock.FADE_ALPHA + 0.05:
			problem = "Arch timber rib did not fade with lintel."
		else:
			dummy.global_position = middle + Vector3(50.0, 0.0, 0.0)
			for _step: int in 10:
				rock._process(0.1)
			if lintel.albedo_color.a < 0.95 or trim.albedo_color.a < 0.95:
				problem = "Lintel/rib did not restore alpha when rover moved away."
	_free(dummy)
	_free(rock)
	return problem
