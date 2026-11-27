class_name IceRock
extends TunnelRock
## The Ice Caves' rock: TunnelRock, but it follows the caves' depth (TunnelRock's own
## _enter_tree is not edited, so this replaces it, with no super) and overrides the
## scene's rock, arch, and floor materials for a glossy layered polar-ice look.
## The hub is the Lava hub's grid for now [PLACEHOLDER]; a hub grid of the caves' own
## is a later PR.


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), IceDepth.ZONE)


func _ready() -> void:
	super._ready()
	_apply_ice_rock_look()


## Overrides this scene's rock blocks, arches, and ambient glow with layered
## glacial blue-white ice without touching TunnelRock's shared look or
## TunnelLook's material cache [PLACEHOLDER].
func _apply_ice_rock_look() -> void:
	var blocks: MultiMeshInstance3D = get_node_or_null("Blocks") as MultiMeshInstance3D
	if blocks != null and blocks.multimesh != null:
		var mm: MultiMesh = blocks.multimesh
		var box_mesh: BoxMesh = mm.mesh as BoxMesh
		if box_mesh != null and box_mesh.material is StandardMaterial3D:
			var stone := box_mesh.material as StandardMaterial3D
			stone.albedo_color = IceLook.ROCK_TINT
			stone.roughness = IceLook.ROCK_ROUGHNESS
			stone.metallic = IceLook.ICE_METALLIC
			stone.rim_enabled = true
			stone.rim = IceLook.ICE_RIM
			stone.rim_tint = 0.5
		var strata: Array[Color] = [
			IceLook.ICE_DEEP,
			IceLook.ICE_BLUE,
			IceLook.ICE_PALE,
			IceLook.STRATA_SILT,
			IceLook.GLACIER_CYAN,
		]
		for i: int in mm.instance_count:
			var origin: Vector3 = mm.get_instance_transform(i).origin
			var base_col: Color = mm.get_instance_color(i)
			var h: int = IceLook.hash_int(roundi(origin.x * 2.0), roundi(origin.z * 2.0), roundi(origin.y * 4.0) + 53)
			var frac: float = float(h % 100) / 100.0
			if origin.y > 0.3:
				# Layered polar water-ice and dust strata along the cave walls [PLACEHOLDER].
				var band_idx: int = absi(int(floor(origin.y * 1.45)) + (h % 2)) % strata.size()
				var tint: Color = strata[band_idx]
				var weight: float = 0.45 + frac * 0.25
				mm.set_instance_color(i, base_col.lerp(tint, weight))
			else:
				# Slick pale-blue ice floor with frosted patches [PLACEHOLDER].
				var floor_col: Color = IceLook.FROST_WHITE if (h % 5 == 0) else (IceLook.ICE_PALE if (h % 2 == 0) else IceLook.ICE_BLUE)
				mm.set_instance_color(i, base_col.lerp(floor_col, 0.36 + frac * 0.22))

	# Replace hub magma pool visual with deep glacial cyan ice (no orange lava in the ice caves).
	var magma: MultiMeshInstance3D = get_node_or_null("Magma") as MultiMeshInstance3D
	if magma != null and magma.multimesh != null:
		var magma_mm: MultiMesh = magma.multimesh
		var magma_mesh: BoxMesh = magma_mm.mesh as BoxMesh
		if magma_mesh != null:
			magma_mesh.material = IceLook.glow_mat(IceLook.GLACIER_CYAN, 0.45)
		for i: int in magma_mm.instance_count:
			var c: Color = IceLook.ICE_DEEP if i % 2 == 0 else IceLook.GLACIER_CYAN
			magma_mm.set_instance_color(i, c)

	# Tint arch lintels and overhead ribs (each is a fresh StandardMaterial3D per arch).
	for middle: Vector3 in _lintels:
		var lintel: StandardMaterial3D = _lintels[middle]
		lintel.albedo_color = Color(IceLook.ARCH_ICE, lintel.albedo_color.a)
		lintel.roughness = IceLook.ROCK_ROUGHNESS
		lintel.metallic = IceLook.ICE_METALLIC
		lintel.rim_enabled = true
		lintel.rim = IceLook.ICE_RIM
	for middle: Vector3 in _lintel_trims:
		var trim: StandardMaterial3D = _lintel_trims[middle]
		trim.albedo_color = Color(IceLook.ARCH_RIB_FROST, trim.albedo_color.a)
		trim.roughness = 0.40

	# Tint arch pillars (fresh per-arch material), swap brass brackets to fresh frost, and cool amber lights.
	var frost_bracket: Material = IceLook.ice_mat(IceLook.FROST_WHITE, 0.32)
	var brass_shared: Material = TunnelLook.flat_mat(TunnelLook.BRASS)
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var bm := mi.mesh as BoxMesh
			if bm != null and bm.material is StandardMaterial3D:
				var mat := bm.material as StandardMaterial3D
				if not mat.emission_enabled and not mat in _lintels.values():
					mat.albedo_color = IceLook.ARCH_ICE
					mat.roughness = IceLook.ROCK_ROUGHNESS
					mat.metallic = IceLook.ICE_METALLIC
					mat.rim_enabled = true
					mat.rim = IceLook.ICE_RIM
		elif child.name.begins_with("ArchRib"):
			for rib_child: Node in child.get_children():
				if rib_child is MeshInstance3D and (rib_child as MeshInstance3D).material_override == brass_shared:
					(rib_child as MeshInstance3D).material_override = frost_bracket
		elif child is OmniLight3D:
			var light := child as OmniLight3D
			if light.light_color.is_equal_approx(TunnelRock.AMBER):
				light.light_color = IceLook.GLACIER_CYAN
				light.light_energy = 0.9
