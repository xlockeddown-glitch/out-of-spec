class_name VallesRock
extends TunnelRock
## Valles Marineris' rock: TunnelRock, but it follows the canyon's depth (TunnelRock's own
## _enter_tree is not edited, so this replaces it, with no super) and paints the rock blocks
## in the canyon wall's bands by height, the floor in dust, and the arches and lights to match.


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), VallesDepth.ZONE)


func _ready() -> void:
	super._ready()
	_apply_valles_look()


func _apply_valles_look() -> void:
	var blocks: MultiMeshInstance3D = get_node_or_null("Blocks") as MultiMeshInstance3D
	if blocks != null and blocks.multimesh != null:
		var mm: MultiMesh = blocks.multimesh
		var box_mesh: BoxMesh = mm.mesh as BoxMesh
		if box_mesh != null and box_mesh.material is StandardMaterial3D:
			var stone := box_mesh.material as StandardMaterial3D
			stone.roughness = VallesLook.ROCK_ROUGHNESS
			stone.metallic = 0.0
		var band_h: float = VallesLook.WALL_HEIGHT_M / float(VallesLook.BANDS.size())
		for i: int in mm.instance_count:
			var origin: Vector3 = mm.get_instance_transform(i).origin
			var base_col: Color = mm.get_instance_color(i)
			var h: int = VallesLook.hash_int(roundi(origin.x * 2.0), roundi(origin.z * 2.0), roundi(origin.y * 4.0) + 59)
			var frac: float = float(h % 100) / 100.0
			if origin.y > 0.3:
				# The wall's bands, by height: the same colours as the cores [PLACEHOLDER].
				var band: int = clampi(int(floor(origin.y / band_h)), 0, VallesLook.BANDS.size() - 1)
				mm.set_instance_color(i, base_col.lerp(VallesLook.band_color(band), 0.5 + frac * 0.25))
			else:
				mm.set_instance_color(i, base_col.lerp(VallesLook.FLOOR_DUST, 0.35 + frac * 0.2))
	for middle: Vector3 in _lintels:
		var lintel: StandardMaterial3D = _lintels[middle]
		lintel.albedo_color = Color(VallesLook.SHALE_RUST, lintel.albedo_color.a)
		lintel.roughness = VallesLook.ROCK_ROUGHNESS
	for middle: Vector3 in _lintel_trims:
		var trim: StandardMaterial3D = _lintel_trims[middle]
		trim.albedo_color = Color(VallesLook.SAND_OCHRE, trim.albedo_color.a)
	for child: Node in get_children():
		if child is OmniLight3D:
			var light := child as OmniLight3D
			if light.light_color.is_equal_approx(TunnelRock.AMBER):
				light.light_color = VallesLook.SAND_OCHRE
