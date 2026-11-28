class_name AquiferRock
extends TunnelRock
## The Flooded Aquifer's rock: TunnelRock, following AquiferDepth and styling
## this scene's rock blocks, floor, and arches with a wet dark teal-grey rock
## palette, slick dark floor, and pale mineral streaks via AquiferLook without
## touching TunnelRock's shared look or TunnelLook's material cache [PLACEHOLDER].


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), AquiferDepth.ZONE)


func _ready() -> void:
	super._ready()
	_apply_aquifer_rock_look()


## Overrides this scene's rock blocks and arches with wet dark teal-grey stone,
## slick dark floor blocks, and pale mineral wall streaks deterministically via
## AquiferLook.hash_int() [PLACEHOLDER].
func _apply_aquifer_rock_look() -> void:
	var blocks: MultiMeshInstance3D = get_node_or_null("Blocks") as MultiMeshInstance3D
	if blocks != null and blocks.multimesh != null:
		var mm: MultiMesh = blocks.multimesh
		var box_mesh: BoxMesh = mm.mesh as BoxMesh
		if box_mesh != null and box_mesh.material is StandardMaterial3D:
			var stone := box_mesh.material as StandardMaterial3D
			stone.albedo_color = AquiferLook.ROCK_TINT
			stone.roughness = AquiferLook.ROCK_ROUGHNESS
			stone.metallic = AquiferLook.WET_ROCK_METALLIC
		for i: int in mm.instance_count:
			var origin: Vector3 = mm.get_instance_transform(i).origin
			var base_col: Color = mm.get_instance_color(i)
			var h: int = AquiferLook.hash_int(roundi(origin.x * 2.0), roundi(origin.z * 2.0), roundi(origin.y * 4.0) + 43)
			var frac: float = float(h % 100) / 100.0
			if origin.y > 0.3:
				# Wet dark teal-grey wall stone with pale mineral streaks [PLACEHOLDER].
				var tint: Color
				var weight: float
				if h % 11 == 0:
					tint = AquiferLook.MINERAL_STREAK if (h % 2 == 0) else AquiferLook.MINERAL_CALCITE
					weight = 0.28 + frac * 0.18
				else:
					tint = AquiferLook.WET_ROCK_TEAL if (h % 3 == 0) else (AquiferLook.WET_ROCK_DARK if (h % 3 == 1) else AquiferLook.WET_ROCK_MID)
					weight = 0.42 + frac * 0.24
				mm.set_instance_color(i, base_col.lerp(tint, weight))
			else:
				# Slick dark wet floor with occasional deeper damp puddles [PLACEHOLDER].
				var floor_col: Color = AquiferLook.FLOOR_PUDDLE if (h % 4 == 0) else AquiferLook.FLOOR_SLICK
				mm.set_instance_color(i, base_col.lerp(floor_col, 0.38 + frac * 0.20))

	# Tint arch lintels and overhead ribs (each is a fresh StandardMaterial3D per arch).
	for middle: Vector3 in _lintels:
		var lintel: StandardMaterial3D = _lintels[middle]
		lintel.albedo_color = Color(AquiferLook.ARCH_WET_STONE, lintel.albedo_color.a)
		lintel.roughness = AquiferLook.ROCK_ROUGHNESS
		lintel.metallic = AquiferLook.WET_ROCK_METALLIC
	for middle: Vector3 in _lintel_trims:
		var trim: StandardMaterial3D = _lintel_trims[middle]
		trim.albedo_color = Color(AquiferLook.ARCH_TRIM_TEAL, trim.albedo_color.a)
		trim.roughness = 0.56

	# Tint arch pillars (fresh per-arch material) and swap brass brackets to rusted pipe-green iron.
	var bracket_mat: Material = AquiferLook.flat_mat(AquiferLook.PIPE_GREEN_DARK, 0.62)
	var brass_shared: Material = TunnelLook.flat_mat(TunnelLook.BRASS)
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var bm := mi.mesh as BoxMesh
			if bm != null and bm.material is StandardMaterial3D:
				var mat := bm.material as StandardMaterial3D
				if not mat.emission_enabled and not mat in _lintels.values():
					mat.albedo_color = AquiferLook.ARCH_WET_STONE
					mat.roughness = AquiferLook.ROCK_ROUGHNESS
					mat.metallic = AquiferLook.WET_ROCK_METALLIC
		elif child.name.begins_with("ArchRib"):
			for rib_child: Node in child.get_children():
				if rib_child is MeshInstance3D and (rib_child as MeshInstance3D).material_override == brass_shared:
					(rib_child as MeshInstance3D).material_override = bracket_mat
