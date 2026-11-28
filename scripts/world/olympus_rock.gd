class_name OlympusRock
extends TunnelRock
## The Olympus Mons caves' rock: TunnelRock, but it follows this zone's depth (TunnelRock's own
## _enter_tree is not edited, so this replaces it, with no super) and paints the rock blocks in
## dark basalt and the floor in ash, with the arches and lights to match.


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), OlympusDepth.ZONE)


func _ready() -> void:
	super._ready()
	_apply_olympus_look()


func _apply_olympus_look() -> void:
	var blocks: MultiMeshInstance3D = get_node_or_null("Blocks") as MultiMeshInstance3D
	if blocks != null and blocks.multimesh != null:
		var mm: MultiMesh = blocks.multimesh
		var box_mesh: BoxMesh = mm.mesh as BoxMesh
		if box_mesh != null and box_mesh.material is StandardMaterial3D:
			var stone := box_mesh.material as StandardMaterial3D
			stone.roughness = OlympusLook.ROCK_ROUGHNESS
			stone.metallic = 0.0
		for i: int in mm.instance_count:
			var origin: Vector3 = mm.get_instance_transform(i).origin
			var base_col: Color = mm.get_instance_color(i)
			var h: int = OlympusLook.hash_int(roundi(origin.x * 2.0), roundi(origin.z * 2.0), roundi(origin.y * 4.0) + 83)
			var frac: float = float(h % 100) / 100.0
			if origin.y > 0.3:
				var tone: Color = OlympusLook.BLOCK_TONES[h % OlympusLook.BLOCK_TONES.size()]
				mm.set_instance_color(i, base_col.lerp(tone, 0.55 + frac * 0.25))
			else:
				mm.set_instance_color(i, base_col.lerp(OlympusLook.FLOOR_ASH, 0.4 + frac * 0.2))
	for middle: Vector3 in _lintels:
		var lintel: StandardMaterial3D = _lintels[middle]
		lintel.albedo_color = Color(OlympusLook.BASALT_GREY, lintel.albedo_color.a)
		lintel.roughness = OlympusLook.ROCK_ROUGHNESS
	for middle: Vector3 in _lintel_trims:
		var trim: StandardMaterial3D = _lintel_trims[middle]
		trim.albedo_color = Color(OlympusLook.EMBER_ORANGE, trim.albedo_color.a)
	for child: Node in get_children():
		if child is OmniLight3D:
			var light := child as OmniLight3D
			if light.light_color.is_equal_approx(TunnelRock.AMBER):
				light.light_color = OlympusLook.EMBER_ORANGE
