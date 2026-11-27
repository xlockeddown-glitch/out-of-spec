extends RefCounted
## The F8 debug overlay (biomes.md section 6, step 4): the ground coloured by biome.
## Heights never change, so the land hashes (test_hills, test_land_240) stay frozen.


## The colour the rebuilt chunk mesh gives the point (x, z).
func _mesh_colour(ground: TerrainGround, x: int, z: int) -> Color:
	var chunk: Vector2i = ground._chunk_of(Vector2i(x, z))
	var mesh: ArrayMesh = ground._chunks[chunk].mesh as ArrayMesh
	var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	return colours[(x - chunk.x) * (TerrainGround.CHUNK_M + 1) + (z - chunk.y)]


func _chunk_heights(ground: TerrainGround, point: Vector2i) -> PackedFloat32Array:
	var chunk: Vector2i = ground._chunk_of(point)
	var mesh: ArrayMesh = ground._chunks[chunk].mesh as ArrayMesh
	var found := PackedFloat32Array()
	for corner: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		found.append(corner.y)
	return found


## One point in each biome: its marker, which BiomeData says it owns.
func _samples() -> Dictionary[StringName, Vector2i]:
	var samples: Dictionary[StringName, Vector2i] = {}
	for id: StringName in BiomeData.ids():
		samples[id] = Vector2i(BiomeData.marker(id).round())
	return samples


func test_paint_is_off_until_asked() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	var fail: String = "" if not ground.is_showing_biomes() else "The paint must start off."
	ground.free()
	return fail


func test_paint_on_colours_each_biome() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	ground.show_biomes(true)
	var fail: String = ""
	for id: StringName in _samples():
		var at: Vector2i = _samples()[id]
		if BiomeData.biome_at(Vector2(at)) != id:
			fail = "The marker of %s is not in %s." % [id, id]
		elif _mesh_colour(ground, at.x, at.y) != BiomeData.tint(id):
			fail = "The ground at the %s marker is not its colour." % id
	ground.free()
	return fail


func test_paint_off_restores_the_tints_exactly() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	var before := PackedColorArray()
	for at: Vector2i in _samples().values():
		before.append(_mesh_colour(ground, at.x, at.y))
	ground.show_biomes(true)
	ground.show_biomes(false)
	var fail: String = ""
	var i: int = 0
	for at: Vector2i in _samples().values():
		# The mesh keeps colours in 8 bits, so compare to a step of 1/255.
		if _mesh_colour(ground, at.x, at.y) != before[i] or not _near(before[i], ground._tints[ground._index(at.x, at.y)]):
			fail = "The tint at %s did not come back." % at
		i += 1
	ground.free()
	return fail


func test_digging_with_the_paint_on_redraws_painted_and_the_heights_match() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	ground.show_biomes(true)
	var cell := Vector2i(10, 10)
	var point: Vector2i = cell * Terrain.CELL_M + Vector2i(1, 1)
	var before: PackedFloat32Array = _chunk_heights(ground, point)
	ground.show_dug({ cell: 1 })
	var fail: String = ""
	if _chunk_heights(ground, point) == before:
		fail = "Digging did not redraw the chunk."
	elif not is_equal_approx(ground._heights[ground._index(point.x, point.y)], Terrain.point_height(point, { cell: 1 })):
		fail = "The dug height is not the land's."
	elif _mesh_colour(ground, point.x, point.y) != BiomeData.tint(BiomeData.biome_at(Vector2(point))):
		fail = "The redrawn chunk lost its paint."
	ground.free()
	return fail


func test_the_paint_does_not_move_the_ground() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	var before: PackedFloat32Array = ground._heights.duplicate()
	ground.show_biomes(true)
	ground.show_biomes(false)
	var fail: String = "" if ground._heights == before else "The paint moved the heights."
	ground.free()
	return fail


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.005 and absf(a.g - b.g) < 0.005 and absf(a.b - b.b) < 0.005
