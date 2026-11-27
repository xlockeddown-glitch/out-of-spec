extends RefCounted
## The ground's shape: the land less what was dug.


func test_the_farm_and_relay_are_level() -> String:
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			if Terrain.is_level(Vector2(x, z)) and Terrain.natural(Vector2i(x, z)) != 0.0:
				return "The ground at (%d, %d) must be level." % [x, z]
	return ""


func test_a_hole_slopes_from_its_edge() -> String:
	var dug: Dictionary[Vector2i, int] = { Vector2i(3, -2): 1 }
	if not is_equal_approx(Terrain.point_height(Vector2i(7, -3), dug), -Terrain.DIG_STEP_M):
		return "The middle of a dug cell must be a step down."
	for x: int in range(5, 10):
		for z: int in range(-5, 0):
			if Vector2i(x, z) != Vector2i(7, -3) and Terrain.point_height(Vector2i(x, z), dug) != 0.0:
				return "Only the middle of a lone hole may sink, not (%d, %d)." % [x, z]
	return ""


func test_a_trench_is_as_deep_as_the_shallower_cell_between() -> String:
	var dug: Dictionary[Vector2i, int] = { Vector2i(0, 0): 2, Vector2i(1, 0): 1 }
	if not is_equal_approx(Terrain.point_height(Vector2i(2, 1), dug), -Terrain.DIG_STEP_M):
		return "Between two dug cells it must be as deep as the shallower."
	if not is_equal_approx(Terrain.point_height(Vector2i(1, 1), dug), -2.0 * Terrain.DIG_STEP_M):
		return "The deeper one must keep its depth."
	return ""


func test_cells_are_two_meters_from_the_middle() -> String:
	if Terrain.cell_at(Vector2(-0.1, 3.9)) != Vector2i(-1, 1) or Terrain.cell_at(Vector2(2.0, 0.0)) != Vector2i(1, 0):
		return "Cells must be 2 m squares from the farm's middle."
	return ""


func test_between_points_the_ground_slopes_evenly() -> String:
	var dug: Dictionary[Vector2i, int] = { Vector2i(0, 0): 1, Vector2i(59, 59): 1 }
	var none: Dictionary[Vector2i, int] = {}
	if not is_equal_approx(Terrain.height(Vector2(0.5, 1.0), dug), -Terrain.DIG_STEP_M * 0.5):
		return "Halfway down a side must be half a step down."
	if not is_equal_approx(Terrain.height(Vector2(119.5, 119.0), dug) - Terrain.height(Vector2(119.5, 119.0), none), -Terrain.DIG_STEP_M * 0.5):
		return "The last cell must slope to the land's edge."
	if not is_equal_approx(Terrain.height(Vector2(200.0, 200.0), dug), Terrain.natural(Vector2i(120, 120))):
		return "Past the edge must be the ground at the edge."
	return ""


func test_the_ground_shows_digging_and_filling() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	ground.show_dug({ Vector2i(-40, -40): 1, Vector2i(0, 0): 2, Vector2i(7, 7): 1 })
	var fail: String = ""
	if not is_equal_approx(ground._heights[ground._index(1, 1)], -2.0 * Terrain.DIG_STEP_M):
		fail = "A dug cell must sink."
	ground.show_dug({ Vector2i(7, 7): 1 })
	if ground._heights[ground._index(1, 1)] != 0.0:
		fail = "A filled cell must rise."
	if not is_equal_approx(ground._shape.map_data[ground._index(15, 15)], -Terrain.DIG_STEP_M):
		fail = "What is driven on must match what is seen."
	ground.free()
	return fail


func _chunk_heights(ground: TerrainGround, cell: Vector2i) -> PackedFloat32Array:
	var chunk: Vector2i = ground._chunk_of(cell * Terrain.CELL_M)
	var mesh: ArrayMesh = ground._chunks[chunk].mesh as ArrayMesh
	var found := PackedFloat32Array()
	for corner: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		found.append(corner.y)
	return found


func test_a_dig_redraws_the_chunk_in_the_old_land_and_the_ring() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	for cell: Vector2i in [Vector2i(10, 10), Vector2i(-39, 5), Vector2i(50, 50), Vector2i(-58, 20), Vector2i(20, 58)]:
		var before: PackedFloat32Array = _chunk_heights(ground, cell)
		ground.show_dug({ cell: 1 })
		if _chunk_heights(ground, cell) == before:
			ground.free()
			return "Digging %s did not redraw its chunk." % cell
		ground.show_dug({})
		if _chunk_heights(ground, cell) != before:
			ground.free()
			return "Filling %s did not redraw its chunk." % cell
	ground.free()
	return ""


func test_a_body_lies_level_on_level_ground_and_tips_into_a_hole() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	var level: Basis = ground.lie_at(Vector3(5, 0, 5), Vector3.FORWARD, 1.1, 0.8)
	ground.show_dug({ Vector2i(0, 0): 1 })
	# Nose over the hole's middle, tail on its rim.
	var nose_down: Basis = ground.lie_at(Vector3(1, 0, 2.1), Vector3.FORWARD, 1.1, 0.8)
	# Its right wheels, at +x, over the hole.
	var rolled: Basis = ground.lie_at(Vector3(0.2, 0, 1), Vector3.FORWARD, 1.1, 0.8)
	ground.free()
	if not level.is_equal_approx(Basis.IDENTITY):
		return "Level ground must not tilt it."
	if nose_down.z.y <= 0.1 or not nose_down.is_conformal() or not is_equal_approx(nose_down.determinant(), 1.0):
		return "Its nose must tip down into the hole."
	if rolled.x.y >= -0.1:
		return "It must roll toward the hole."
	return ""


func test_digging_keeps_to_one_step_between_neighbors() -> String:
	var dug: Dictionary[Vector2i, int] = {}
	var cell := Vector2i(20, 20)
	if Terrain.dig_problem(cell, dug) != "":
		return "Open ground must be dug."
	dug[cell] = 1
	for neighbor: Vector2i in Terrain.neighbors(cell):
		if Terrain.dig_problem(cell, dug) == "":
			return "Each of the eight neighbors must count."
		dug[neighbor] = 1
	if dug.size() != 9 or Terrain.dig_problem(cell, dug) != "":
		return "With its neighbors dug it must go deeper."
	for at: Vector2i in dug:
		dug[at] = Terrain.MAX_DIG_STEPS
	if Terrain.dig_problem(cell, dug) == "":
		return "There must be a deepest depth."
	return ""


func test_digging_keeps_off_the_edge_and_level_ground() -> String:
	for cell: Vector2i in [Vector2i(-60, 20), Vector2i(59, 20), Vector2i(20, -60), Vector2i(20, 59), Vector2i(20, 1000),
			Vector2i(0, 0), Vector2i(14, 0), Vector2i(16, 0), Vector2i(-17, 0), Vector2i(0, 14), Vector2i(-35, -35), Vector2i(-31, -35)]:
		if Terrain.dig_problem(cell, {}) == "" or Terrain.dug_problem({ cell: 1 }) == "":
			return "%s must not be dug." % cell
	for cell: Vector2i in [Vector2i(-59, 20), Vector2i(58, 38), Vector2i(17, 0), Vector2i(0, -18), Vector2i(-29, -35)]:
		if Terrain.dig_problem(cell, {}) != "":
			return "%s must be dug." % cell
	return ""


func test_the_most_digging_there_can_be_never_sinks_level_ground() -> String:
	var deep: Dictionary[Vector2i, int] = {}
	for x: int in range(-60, 60):
		for z: int in range(-60, 60):
			if Terrain.can_dig(Vector2i(x, z)):
				deep[Vector2i(x, z)] = 1
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			var point := Vector2i(x, z)
			if Terrain.is_level(Vector2(point)) and Terrain.point_height(point, deep) != Terrain.natural(point):
				return "%s sank." % point
	return ""


func test_filling_keeps_to_one_step_between_neighbors() -> String:
	var cell := Vector2i(20, 20)
	if Terrain.fill_problem(cell, {}) == "":
		return "Only dug ground may be filled."
	for neighbor: Vector2i in Terrain.neighbors(cell):
		if Terrain.fill_problem(cell, { cell: 1, neighbor: 1 }) != "":
			return "A step must be filled."
		if Terrain.fill_problem(cell, { cell: 1, neighbor: 2 }) == "":
			return "Filling must not leave a neighbor two steps deeper."
	return ""


func test_any_digging_the_rules_allow_loads() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var dug: Dictionary[Vector2i, int] = {}
	var filled: int = 0
	var deepest: int = 0
	for i: int in 4000:
		var cell := Vector2i(rng.randi_range(18, 24), rng.randi_range(18, 24))
		if rng.randf() < 0.7:
			if Terrain.dig_problem(cell, dug) == "":
				dug[cell] = dug.get(cell, 0) + 1
				deepest = maxi(deepest, dug[cell])
		elif Terrain.fill_problem(cell, dug) == "":
			filled += 1
			dug[cell] -= 1
			if dug[cell] == 0:
				dug.erase(cell)
		if Terrain.dug_problem(dug) != "":
			return "After dig or fill %d the digging %s" % [i, Terrain.dug_problem(dug)]
	if filled < 100 or deepest < 3:
		return "It must fill (%d) and go deep (%d)." % [filled, deepest]
	return ""


func test_bad_digging_is_refused() -> String:
	var cell := Vector2i(20, 20)
	for bad: Dictionary in [{ cell: 0 }, { cell: -1 }, { cell: 2 }, { cell: 1.0 }, { cell: "1" }, { cell: true }, { "here": 1 },
			{ Vector3i(20, 0, 20): 1 }, { Vector2(20, 20): 1 }, { cell: 99 }, { Vector2i(99, 99): 1 }]:
		if Terrain.dug_problem(bad) == "":
			return "%s must be refused." % bad
	return ""


func test_the_highest_ground_under_a_rover_is_found() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	var dug: Dictionary[Vector2i, int] = { Vector2i(20, 20): 1, Vector2i(20, 21): 1, Vector2i(20, 22): 1 }
	ground.show_dug(dug)
	var found := PackedFloat32Array()
	var problem: String = ""
	# In the trench along z, and across it.
	for turn: float in [0.0, PI * 0.5]:
		var at := Transform3D(Basis(Vector3.UP, turn), Vector3(41, 0, 43))
		var highest_m: float = -INF
		for x: int in range(-8, 9):
			for z: int in range(-12, 13):
				highest_m = maxf(highest_m, ground.height_at(at * Vector3(x * 0.1, 0, z * 0.1)))
		found.append(ground.highest_under(at, 1.2, 0.8))
		if absf(found[-1] - highest_m) > 0.1:
			problem = "Found %s, not %s." % [found[-1], highest_m]
	ground.free()
	if problem == "" and found[1] <= found[0]:
		return "Across the trench it must reach the rim."
	return problem


func test_dug_hills_can_be_driven_everywhere() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dug: Dictionary[Vector2i, int] = {}
	for i: int in 60000:
		var cell := Vector2i(rng.randi_range(-59, 58), rng.randi_range(-59, 58))
		if Terrain.dig_problem(cell, dug) == "":
			dug[cell] = dug.get(cell, 0) + 1
	# Rovers climb 45 degrees, a rise of 1 in 1.
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M):
			var a: float = Terrain.point_height(Vector2i(x, z), dug)
			var b: float = Terrain.point_height(Vector2i(x + 1, z), dug)
			var c: float = Terrain.point_height(Vector2i(x, z + 1), dug)
			var d: float = Terrain.point_height(Vector2i(x + 1, z + 1), dug)
			for rise: Vector2 in [Vector2(b - a, c - a), Vector2(d - c, d - b), Vector2(b - a, d - b), Vector2(d - c, c - a)]:
				if rise.length() >= 0.98:
					return "%s, %s rises %s." % [x, z, rise.length()]
	return ""
