extends RefCounted
## The eight ore fissures (docs/design/biomes.md section 6, step 7): out of the
## middle, in the Badlands, clear of the plot, the pad and sign, and the water.
## Their ids are the node names, so an old save's mined_fissures still fits.

const SCENE: String = "res://scenes/main_farm.tscn"


## name -> Vector2 (x, z), read from the scene file's text.
func _scene_fissures() -> Dictionary:
	var named := RegEx.new()
	named.compile(r'\[node name="(Fissure[A-Z])" type="Node3D" parent="[^"]*/Fissures"\]\s*position = Vector3\(([-0-9.]+), [-0-9.]+, ([-0-9.]+)\)')
	var out: Dictionary = {}
	for found: RegExMatch in named.search_all(FileAccess.get_file_as_string(SCENE)):
		out[StringName(found.get_string(1))] = Vector2(float(found.get_string(2)), float(found.get_string(3)))
	return out


## Every cell a point touches, dug one step (a point sits as low as its lowest cell).
func _dug_around(at: Vector2) -> Dictionary[Vector2i, int]:
	var dug: Dictionary[Vector2i, int] = {}
	var middle := Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var cell: Vector2i = middle + Vector2i(dx, dz)
			if Terrain.can_dig(cell) and not Terrain.is_near_water(cell):
				dug[cell] = 1
	return dug


func test_the_scene_has_the_eight_ids_and_no_other() -> String:
	var found: Dictionary = _scene_fissures()
	if found.size() != GameState.FISSURES.size():
		return "Found %d fissures in the scene, expected %d" % [found.size(), GameState.FISSURES.size()]
	for id: StringName in GameState.FISSURES:
		if not found.has(id):
			return "The scene has no %s" % id
	return ""


func test_every_fissure_is_in_the_badlands_off_the_plot_pad_sign_and_water() -> String:
	var plot: float = BiomeData.PLOT_HALF_M + BiomeData.PLOT_CLEAR_M
	var none: Dictionary[Vector2i, int] = {}
	for id: StringName in _scene_fissures():
		var at: Vector2 = _scene_fissures()[id]
		if BiomeData.biome_at(at) != &"badlands":
			return "%s at %s is in %s, not the Badlands" % [id, at, BiomeData.biome_at(at)]
		if absf(at.x) < plot and absf(at.y) < plot:
			return "%s is on the plot" % id
		if at.length() < 30.0:
			return "%s is still within 30 m of the middle" % id
		if Terrain.is_level(at):
			return "%s is on level ground" % id
		if Terrain.is_deep(at):
			return "%s is in deep water" % id
		# The fissure's 2 m reach, a cell each way.
		for dx: int in [-2, 0, 2]:
			for dz: int in [-2, 0, 2]:
				var near: Vector2 = at + Vector2(dx, dz)
				var cell := Vector2i(floori(near.x / Terrain.CELL_M), floori(near.y / Terrain.CELL_M))
				if BiomeMarkers.is_blocked_cell(cell) or Terrain.is_near_water(cell):
					return "%s has a pad, a sign or water within its reach" % id
		if not is_finite(Terrain.height(at, none)):
			return "%s has no ground" % id
	return ""


func test_the_scene_spots_hold_the_fissures_so_the_copy_cannot_drift() -> String:
	var found: Dictionary = _scene_fissures()
	var spots: Array[Vector4] = BiomeData.SCENE_SPOTS
	for id: StringName in found:
		var at: Vector2 = found[id]
		var has: bool = false
		for spot: Vector4 in spots:
			if spot.x == at.x and spot.y == at.y and spot.z == 1.5 and spot.w == 1.5:
				has = true
		if not has:
			return "%s at %s is not in BiomeData.SCENE_SPOTS" % [id, at]
	return ""


func test_the_fissures_are_clear_of_each_other_and_of_every_other_spot() -> String:
	var found: Dictionary = _scene_fissures()
	var ids: Array = found.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			if (found[ids[i]] as Vector2).distance_to(found[ids[j]]) < 5.0:
				return "%s and %s are within 5 m" % [ids[i], ids[j]]
	for id: StringName in ids:
		var at: Vector2 = found[id]
		for spot: Vector4 in BiomeData.spots():
			if spot.z == 1.5 and spot.w == 1.5 and found.values().has(Vector2(spot.x, spot.y)):
				continue
			if absf(at.x - spot.x) < spot.z + 1.5 + 1.0 and absf(at.y - spot.y) < spot.w + 1.5 + 1.0:
				return "%s is on or too near the thing at (%s, %s)" % [id, spot.x, spot.y]
	return ""


func test_a_fissure_sits_on_the_ground_even_over_old_digging() -> String:
	var found: Dictionary = _scene_fissures()
	for id: StringName in found:
		var at := Vector3(found[id].x, 0.0, found[id].y)
		var none: Dictionary[Vector2i, int] = {}
		var dug: Dictionary[Vector2i, int] = _dug_around(found[id])
		var flat: float = OreFissure.ground_y(at, none)
		var lower: float = OreFissure.ground_y(at, dug)
		if not is_equal_approx(flat, Terrain.height(found[id], none)):
			return "%s is not on the natural ground" % id
		if dug.is_empty() or not lower < flat:
			return "%s did not drop onto its dug ground (%s, %s)" % [id, flat, lower]
	return ""


func test_an_old_save_with_mined_fissures_and_digging_at_a_fissure_loads_the_same() -> String:
	var source: Node = load("res://scripts/autoload/GameState.gd").new()
	source.build_registry()
	source.set_world_seed(424242)
	var spot: Vector2 = _scene_fissures()[&"FissureC"]
	var cell := Vector2i(floori(spot.x / Terrain.CELL_M), floori(spot.y / Terrain.CELL_M))
	if not Terrain.can_dig(cell):
		source.free()
		return "FissureC's cell can not be dug, so the test has nothing to check"
	source.mined_fissures[&"FissureA"] = GameClock.get_day_index()
	source.mined_fissures[&"FissureC"] = GameClock.get_day_index()
	source.dug = _dug_around(spot)
	var data: Dictionary = bytes_to_var(var_to_bytes(source.farm_to_dict()))
	var target: Node = load("res://scripts/autoload/GameState.gd").new()
	target.build_registry()
	target.set_world_seed(7)
	var problem: String = target.farm_from_dict(data)
	var open: Array[StringName] = []
	for id: StringName in GameState.FISSURES:
		if target.is_fissure_available(id) != source.is_fissure_available(id):
			problem = "%s is open on one side only" % id
		if target.is_fissure_available(id):
			open.append(id)
	if problem == "" and (open.has(&"FissureA") or open.has(&"FissureC") or open.size() != 6):
		problem = "The open fissures after the load are %s" % [open]
	if problem == "" and target.dug != _dug_around(spot):
		problem = "The digging at the fissure's spot was lost"
	var on_dug: float = OreFissure.ground_y(Vector3(spot.x, 0.0, spot.y), target.dug)
	var none: Dictionary[Vector2i, int] = {}
	if problem == "" and not on_dug < OreFissure.ground_y(Vector3(spot.x, 0.0, spot.y), none):
		problem = "FissureC does not sit on the dug ground"
	source.free()
	target.free()
	return problem
