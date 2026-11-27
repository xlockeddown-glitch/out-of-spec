class_name MineRock
extends TunnelRock
## The Colony Mine's rock: TunnelRock, but it follows the Mine's depth. TunnelRock's own
## _enter_tree only knows the Lava Tubes and the Aquifer, and it is not edited here, so
## this replaces it (no super: that would follow the Lava Tubes). The hub is the Lava
## hub's grid for now [PLACEHOLDER]; a hub grid of the Mine's own is a later PR.


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), MineDepth.ZONE)


func _ready() -> void:
	super._ready()
	_apply_mine_rock_look()


## Tints this scene's rock blocks and arches with rust-red and ochre ore stains
## without touching TunnelRock's shared look or TunnelLook's material cache [PLACEHOLDER].
func _apply_mine_rock_look() -> void:
	var blocks: MultiMeshInstance3D = get_node_or_null("Blocks") as MultiMeshInstance3D
	if blocks != null and blocks.multimesh != null:
		var mm: MultiMesh = blocks.multimesh
		var box_mesh: BoxMesh = mm.mesh as BoxMesh
		if box_mesh != null and box_mesh.material is StandardMaterial3D:
			var stone := box_mesh.material as StandardMaterial3D
			stone.albedo_color = MineLook.ROCK_TINT
			stone.roughness = MineLook.ROCK_ROUGHNESS
		for i: int in mm.instance_count:
			var origin: Vector3 = mm.get_instance_transform(i).origin
			var base_col: Color = mm.get_instance_color(i)
			var h: int = MineLook.hash_int(roundi(origin.x * 2.0), roundi(origin.z * 2.0), roundi(origin.y * 4.0) + 31)
			var frac: float = float(h % 100) / 100.0
			if origin.y > 0.3:
				# Rust-red and ochre ore-stained wall bands [PLACEHOLDER].
				var stain: Color = MineLook.ORE_OCHRE if (h % 5 == 0) else MineLook.ORE_RUST
				var weight: float = 0.22 + frac * 0.24
				mm.set_instance_color(i, base_col.lerp(stain, weight))
			else:
				# Packed iron-oxide mine dust across floor cells [PLACEHOLDER].
				var dust: Color = MineLook.ORE_DARK if (h % 3 == 0) else MineLook.ORE_RUST
				mm.set_instance_color(i, base_col.lerp(dust, 0.14 + frac * 0.12))

	# Tint arch lintels and timber ribs (each is a fresh StandardMaterial3D per arch).
	for middle: Vector3 in _lintels:
		var lintel: StandardMaterial3D = _lintels[middle]
		lintel.albedo_color = Color(MineLook.ARCH_STONE, lintel.albedo_color.a)
	for middle: Vector3 in _lintel_trims:
		var trim: StandardMaterial3D = _lintel_trims[middle]
		trim.albedo_color = Color(MineLook.TIMBER_OLD, trim.albedo_color.a)

	# Tint arch pillars (fresh per-arch material) and replace brass rib brackets with rusted iron.
	var rust_mat: Material = MineLook.flat_mat(MineLook.RUST_IRON)
	var brass_shared: Material = TunnelLook.flat_mat(TunnelLook.BRASS)
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var bm := mi.mesh as BoxMesh
			if bm != null and bm.material is StandardMaterial3D:
				var mat := bm.material as StandardMaterial3D
				if not mat.emission_enabled and not mat in _lintels.values():
					mat.albedo_color = MineLook.ARCH_STONE
		elif child.name.begins_with("ArchRib"):
			for rib_child: Node in child.get_children():
				if rib_child is MeshInstance3D and (rib_child as MeshInstance3D).material_override == brass_shared:
					(rib_child as MeshInstance3D).material_override = rust_mat
