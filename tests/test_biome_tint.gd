extends RefCounted
## The ground's normal look leans toward its biome (biomes.md section 6, step 5).
## Heights never change, so the land hashes (test_hills, test_land_240) stay frozen.

## The most a neighbouring pair of points (1 m apart) may differ in any channel of the
## biome multiplier: no hard line at a biome edge [PLACEHOLDER].
const STEP_MAX: float = 0.08


func _ground() -> TerrainGround:
	var ground := TerrainGround.new()
	ground._ready()
	return ground


func _distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _spokes() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in BiomeData.ids():
		if BiomeData.biome(id).get("role") != "hub":
			out.append(id)
	return out


func test_deep_in_each_biome_the_tint_leans_to_its_colour() -> String:
	var ground := _ground()
	var fail: String = ""
	for id: StringName in _spokes():
		var at := Vector2i(BiomeData.centre(id).round())
		if BiomeData.biome_at(Vector2(at)) != id:
			fail = "The centre of %s is not in it." % id
			break
		var plain: Color = ground._tint(Terrain.natural(at))
		var got: Color = ground._tints[ground._index(at.x, at.y)]
		if _distance(got, BiomeData.ground_tint(id)) >= _distance(plain, BiomeData.ground_tint(id)):
			fail = "The ground at the centre of %s is no nearer its colour than the height tint." % id
			break
	ground.free()
	return fail


func test_the_farm_centre_looks_as_it_did() -> String:
	var ground := _ground()
	var fail: String = ""
	for at: Vector2i in [Vector2i(0, 0), Vector2i(6, -5), Vector2i(-10, 8)]:
		if ground._tints[ground._index(at.x, at.y)] != ground._tint(Terrain.natural(at)):
			fail = "The farm tint at %s changed." % at
	ground.free()
	return fail


func test_no_hard_step_across_a_biome_edge() -> String:
	var ground := _ground()
	var lean: PackedColorArray = ground._biome_lean()
	var fail: String = ""
	for id: StringName in _spokes():
		var centre: Vector2 = BiomeData.centre(id)
		var crossed: bool = false
		var last_id: StringName = &""
		var last: Color
		# From the farm out past the biome's centre, a metre at a time.
		var steps: int = int(centre.length() * 1.5)
		for i: int in steps + 1:
			var at := Vector2i((centre.normalized() * i).round())
			if absi(at.x) > Terrain.HALF_M or absi(at.y) > Terrain.HALF_M:
				break
			var here: Color = lean[ground._index(at.x, at.y)]
			var here_id: StringName = BiomeData.biome_at(Vector2(at))
			if last_id != &"" and here_id != last_id:
				crossed = true
			if last_id != &"" and maxf(absf(here.r - last.r), maxf(absf(here.g - last.g), absf(here.b - last.b))) > STEP_MAX:
				fail = "A hard step on the way to %s at %s." % [id, at]
			last_id = here_id
			last = here
		if not crossed:
			fail = "The line to %s crossed no biome edge." % id
		if fail != "":
			break
	ground.free()
	return fail


func test_the_overlay_stays_pure_and_off_returns_the_new_tints() -> String:
	var ground := _ground()
	var at := Vector2i(BiomeData.centre(&"basalt_ridge").round())
	var before: Color = ground._tints[ground._index(at.x, at.y)]
	ground.show_biomes(true)
	var fail: String = ""
	var chunk: Vector2i = ground._chunk_of(at)
	var colours: PackedColorArray = (ground._chunks[chunk].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var shown: Color = colours[(at.x - chunk.x) * (TerrainGround.CHUNK_M + 1) + (at.y - chunk.y)]
	if _distance(shown, BiomeData.tint(&"basalt_ridge")) > 0.02:
		fail = "The overlay is not the pure biome colour."
	ground.show_biomes(false)
	if ground._tints[ground._index(at.x, at.y)] != before:
		fail = "The normal tint did not come back."
	colours = (ground._chunks[chunk].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	shown = colours[(at.x - chunk.x) * (TerrainGround.CHUNK_M + 1) + (at.y - chunk.y)]
	if _distance(shown, before) > 0.02:
		fail = "The redrawn ground is not the normal tint."
	ground.free()
	return fail


func test_digging_keeps_the_biome_tint() -> String:
	var ground := _ground()
	var cell := Vector2i(10, 10)
	var point: Vector2i = cell * Terrain.CELL_M + Vector2i(1, 1)
	ground.show_dug({ cell: 1 })
	var chunk: Vector2i = ground._chunk_of(point)
	var colours: PackedColorArray = (ground._chunks[chunk].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var shown: Color = colours[(point.x - chunk.x) * (TerrainGround.CHUNK_M + 1) + (point.y - chunk.y)]
	var fail: String = ""
	if _distance(shown, ground._tints[ground._index(point.x, point.y)]) > 0.02:
		fail = "A dug chunk lost its tint."
	ground.free()
	return fail


func test_the_ground_shader_still_tells_the_dark_and_brown_biomes_apart() -> String:
	var base := Color(0.42, 0.5, 0.3)
	var basalt: Color = Color.WHITE.lerp(BiomeData.ground_tint(&"basalt_ridge"), TerrainGround.BIOME_STRENGTH) * base
	var badlands: Color = Color.WHITE.lerp(BiomeData.ground_tint(&"badlands"), TerrainGround.BIOME_STRENGTH) * base
	if basalt.get_luminance() > badlands.get_luminance() * 0.75:
		return "Basalt is not clearly darker than the Badlands on screen."
	if badlands.r <= badlands.g:
		return "The Badlands is not warm on screen."
	return ""
