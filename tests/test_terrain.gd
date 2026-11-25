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
	var dug: Dictionary[Vector2i, int] = { Vector2i(0, 0): 1, Vector2i(39, 39): 1 }
	if not is_equal_approx(Terrain.height(Vector2(0.5, 1.0), dug), -Terrain.DIG_STEP_M * 0.5):
		return "Halfway down a side must be half a step down."
	if not is_equal_approx(Terrain.height(Vector2(79.5, 79.0), dug) - Terrain.natural(Vector2i(80, 79)), -Terrain.DIG_STEP_M * 0.5):
		return "The last cell must slope to the land's edge."
	if not is_equal_approx(Terrain.height(Vector2(200.0, 200.0), dug), Terrain.natural(Vector2i(80, 80))):
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
