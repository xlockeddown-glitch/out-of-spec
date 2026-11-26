extends RefCounted
## Water in dug pits: where it stands, that it lies level and never spills, how a
## channel carries it, and what it does to a rover and a walker.

## Open, dug-able ground: nearly flat, a gentle hillside, and one so steep a pit drains.
const FLAT := Vector2i(-21, 3)
const SLOPE := Vector2i(9, -21)
const STEEP := Vector2i(21, -12)

## How far under the water the ground at a border may be.
const SPILL_M: float = 0.0001

var _none: Dictionary[Vector2i, int] = {}


## Steps for a pit `depth` deep in the middle: each ring out is a step shallower.
func _cone(middle: Vector2i, depth: int, into: Dictionary[Vector2i, int] = {}) -> Dictionary[Vector2i, int]:
	for x: int in range(-depth + 1, depth):
		for z: int in range(-depth + 1, depth):
			into[middle + Vector2i(x, z)] = depth - maxi(absi(x), absi(z))
	return into


## Three steps in the middle and under it all round: shallow, one dig from deep.
func _almost_deep(middle: Vector2i) -> Dictionary[Vector2i, int]:
	var dug: Dictionary[Vector2i, int] = _cone(middle, 4)
	dug[middle] = 3
	return dug


func _wet(dug: Dictionary[Vector2i, int], pieces: Dictionary[Vector2i, int] = {}) -> Dictionary:
	var found: Dictionary = PitWater.work_out(dug, pieces)
	PitWater.use(found, dug)
	return found


## The pits are as full as they will get: the ground water has had its time.
func _flood() -> void:
	GameState.pit_seep.assign(PitWater.work_out(GameState.dug, {})["levels"])


func _middle(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M


func _channel(cells: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var pieces: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in cells:
		pieces[cell] = StonePieces.CHANNEL
	return pieces


func test_nothing_is_wet_with_no_digging_and_a_one_step_dimple_stays_dry() -> String:
	var found: Dictionary = _wet(_none)
	if not found["levels"].is_empty() or not found["film"].is_empty() or PitWater.depth_m(_middle(FLAT)) != 0.0:
		return "Undug ground must be dry."
	found = _wet(_cone(FLAT, 1))
	if not found["levels"].is_empty():
		return "A one step dimple must not reach the water: %s" % [found["levels"]]
	found = _wet(_cone(FLAT, 2))
	return "" if found["levels"].is_empty() else "A two step pit is dry, the ground seeps from three: %s" % [found["levels"]]


func test_a_three_step_pit_holds_shallow_water_that_does_not_stop_a_rover() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 3)
	_wet(dug)
	var middle: Vector2 = _middle(FLAT)
	var depth: float = PitWater.depth_m(middle)
	if depth < 0.4 or depth > 0.6:
		return "The middle must hold a shallow depth, not %s m." % depth
	if PitWater.is_deep(middle) or not PitWater.blocks().is_empty() or Terrain.is_deep(middle):
		return "Shallow water must not block."
	if not PitWater.is_wading(middle):
		return "A rover must wade here."
	return "" if PitWater.depth_m(middle + Vector2(40.0, 0.0)) == 0.0 else "Dry land far away must be dry."


func test_a_deep_pit_blocks_and_every_deep_point_is_under_a_block() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	_wet(dug)
	var middle: Vector2 = _middle(FLAT)
	if not PitWater.is_deep(middle) or not Terrain.is_deep(middle) or PitWater.blocks().is_empty():
		return "A four step pit must be deep in the middle."
	if PitWater.depth_m(middle) < Terrain.WASH_BLOCK_M:
		return "A four step pit holds a metre, not %s m." % PitWater.depth_m(middle)
	var deep: int = 0
	for x: int in range(-40, 41):
		for z: int in range(-40, 41):
			var at: Vector2 = middle + Vector2(x, z) * 0.25
			if PitWater.is_deep(at):
				deep += 1
				if PitWater.gap_m(at) > 0.0:
					return "Deep water at %s is not under a block." % at
	return "" if deep > 5 else "Only %d deep points." % deep


## Checks, over a fine sweep of the pit and its surroundings, that water is only in
## wet cells, never floats over the ground, lies at one level per cell, and never
## stands higher than the ground beside it that is not itself under water.
func _lies_level(dug: Dictionary[Vector2i, int], label: String) -> String:
	var found: Dictionary = _wet(dug)
	var levels: Dictionary[Vector2i, float] = found["levels"]
	if levels.is_empty():
		return "%s: no water at all." % label
	var low := Vector2i(100000, 100000)
	var high := Vector2i(-100000, -100000)
	for cell: Vector2i in levels:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	for x: int in range(low.x - 2, high.x + 3):
		for z: int in range(low.y - 2, high.y + 3):
			var cell := Vector2i(x, z)
			for i: int in 8:
				for j: int in 8:
					var at: Vector2 = (Vector2(cell) + Vector2(i + 0.5, j + 0.5) / 8.0) * Terrain.CELL_M
					var depth: float = PitWater.depth_m(at)
					if depth > 0.0 and not levels.has(cell) and not found["film"].has(cell):
						return "%s: water at %s is outside the wet cells." % [label, at]
					if depth > 0.0 and absf(PitWater.level_m(at) - Terrain.height(at, dug) - depth) > 0.0001:
						return "%s: the water at %s does not sit on the ground." % [label, at]
					if depth > 0.0 and levels.has(cell) and not is_equal_approx(PitWater.level_m(at), levels[cell]):
						return "%s: the water's top varies in %s." % [label, cell]
	# The border between a wet cell and a dry one, along its whole length and at its
	# ends: the ground there is the water's rim, and must not be under the level.
	for cell: Vector2i in levels:
		for around: Vector2i in Terrain.neighbors(cell):
			if levels.has(around):
				continue
			if PitWater._ground_m(around, dug) < levels[cell] - 0.0001:
				return "%s: water at %s spills over the lower ground at %s." % [label, cell, around]
			var between: Vector2i = around - cell
			for step: int in range(0, 9):
				var along: float = step / 8.0 * Terrain.CELL_M
				var edge := Vector2(cell * Terrain.CELL_M)
				var at: Vector2
				if between.x != 0 and between.y != 0:
					at = edge + Vector2(Terrain.CELL_M if between.x > 0 else 0.0, Terrain.CELL_M if between.y > 0 else 0.0)
				elif between.x != 0:
					at = edge + Vector2(Terrain.CELL_M if between.x > 0 else 0.0, along)
				else:
					at = edge + Vector2(along, Terrain.CELL_M if between.y > 0 else 0.0)
				if Terrain.height(at, dug) < levels[cell] - SPILL_M:
					return "%s: water at %s spills at the border %s, the ground there is %s m under it." % [
						label, cell, at, levels[cell] - Terrain.height(at, dug)]
	return ""


func test_water_lies_level_and_never_spills_over_a_rim() -> String:
	var problems: PackedStringArray = []
	var wet: int = 0
	for site: Vector2i in [FLAT, SLOPE, Vector2i(-27, -9), Vector2i(-21, -12), Vector2i(-15, -30)]:
		for depth: int in [3, 4]:
			var dug: Dictionary[Vector2i, int] = _cone(site, depth)
			if _wet(dug)["levels"].is_empty():
				continue
			wet += 1
			var problem: String = _lies_level(dug, "%s depth %d" % [site, depth])
			if problem != "":
				problems.append(problem)
	var two: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	_cone(FLAT + Vector2i(6, 1), 4, two)
	var problem: String = _lies_level(two, "two touching pits")
	if problem != "":
		problems.append(problem)
	if wet < 6:
		problems.append("The sweep must meet wet pits, met %d." % wet)
	return "\n".join(problems)


func test_a_pit_on_a_slope_is_wet_only_on_its_low_side() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(SLOPE, 4)
	var found: Dictionary = _wet(dug)
	if found["levels"].is_empty():
		return "A four step pit on a slope must hold some water."
	if not _wet(_cone(STEEP, 4))["levels"].is_empty():
		return "A pit on a steep slope drains out of its low side, so it holds nothing."
	_wet(dug)
	var lowest: Vector2i = SLOPE
	var highest: Vector2i = SLOPE
	for cell: Vector2i in dug:
		if PitWater._ground_m(cell, dug) < PitWater._ground_m(lowest, dug):
			lowest = cell
		if PitWater._natural_m(cell) > PitWater._natural_m(highest):
			highest = cell
	if found["levels"].has(highest) and PitWater.depth_m(_middle(highest)) > 0.0:
		return "The uphill cell %s is above the water, so it is dry." % highest
	return "" if PitWater.depth_m(_middle(lowest)) > 0.0 else "The pit's lowest cell holds the water."


func test_water_depends_only_on_what_is_known() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	_cone(SLOPE, 4, dug)
	var pieces: Dictionary[Vector2i, int] = _channel([FLAT + Vector2i(3, 0), FLAT + Vector2i(4, 0)])
	var before_dug: Dictionary[Vector2i, int] = dug.duplicate()
	var first: Dictionary = PitWater.work_out(dug, pieces)
	var reversed: Dictionary[Vector2i, int] = {}
	var keys: Array[Vector2i] = dug.keys()
	keys.reverse()
	for cell: Vector2i in keys:
		reversed[cell] = dug[cell]
	var second: Dictionary = PitWater.work_out(reversed, pieces)
	if dug != before_dug:
		return "Working out the water must not change the digging."
	return "" if first["levels"] == second["levels"] and first["film"] == second["film"] else "Insertion order changed the water."


func test_filling_a_pit_in_drains_it() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	if _wet(dug)["levels"].is_empty() or PitWater.blocks().is_empty():
		return "A pit of four must hold deep water."
	var shallow: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in dug:
		shallow[cell] = dug[cell] - 1 if dug[cell] > 1 else 1
	var found: Dictionary = _wet(shallow)
	if found["levels"].is_empty() or not PitWater.blocks().is_empty():
		return "One step filled leaves shallow water with no blocks: %s" % [found["levels"]]
	var dry: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in shallow:
		dry[cell] = shallow[cell] - 1 if shallow[cell] > 1 else 1
	if not _wet(dry)["levels"].is_empty():
		return "Two steps filled leaves a pit of two, which is dry."
	for cell: Vector2i in shallow:
		shallow[cell] = 1
	return "" if _wet(shallow)["levels"].is_empty() and PitWater.depth_m(_middle(FLAT)) == 0.0 else "A pit filled to one step must be dry."


func test_a_channel_beside_a_wet_pit_carries_a_film_to_a_lower_dimple() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	var run: Array[Vector2i] = [FLAT + Vector2i(2, 0), FLAT + Vector2i(3, 0), FLAT + Vector2i(4, 0)]
	var found: Dictionary = _wet(dug, _channel(run))
	for cell: Vector2i in run:
		if not found["film"].has(cell):
			return "The channel at %s must carry the film." % cell
		var depth: float = PitWater.depth_m(_middle(cell))
		if not is_equal_approx(depth, PitWater.FILM_M):
			return "The film at %s must be %s m, not %s." % [cell, PitWater.FILM_M, depth]
	if PitWater.is_wading(_middle(run[0])) or PitWater.is_deep(_middle(run[0])):
		return "A film does not slow a rover."
	var unfed: Dictionary = _wet(_none, _channel(run))
	if not unfed["film"].is_empty():
		return "A channel with no pit carries nothing."
	var away: Dictionary = _wet(_cone(FLAT, 4), _channel([FLAT + Vector2i(9, 0), FLAT + Vector2i(10, 0)]))
	return "" if away["film"].is_empty() else "A channel away from the pit must stay dry."


func test_a_one_step_dimple_by_a_fed_channel_fills_only_if_lower() -> String:
	var run: Array[Vector2i] = [FLAT + Vector2i(2, 0), FLAT + Vector2i(3, 0), FLAT + Vector2i(4, 0), FLAT + Vector2i(5, 0)]
	var dimple: Vector2i = FLAT + Vector2i(5, 1)
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	dug[dimple] = 1
	var pieces: Dictionary[Vector2i, int] = _channel(run)
	var found: Dictionary = _wet(dug, pieces)
	var floor_m: float = PitWater._ground_m(dimple, dug)
	var channel_m: float = PitWater._ground_m(run[3], dug)
	if floor_m >= channel_m - PitWater.MIN_DEPTH_M:
		return "The fixture needs a dimple lower than its channel."
	if not found["levels"].has(dimple):
		return "A dimple lower than the channel it touches must fill."
	if found["levels"][dimple] > PitWater._rim_m({ dimple: true }, dug) + 0.0001:
		return "A dimple's water must not stand over its own rim."
	var unfed: Dictionary = _wet(dug, _channel([FLAT + Vector2i(10, 0), FLAT + Vector2i(11, 0)]))
	if unfed["levels"].has(dimple):
		return "An unfed channel fills nothing."
	# Exactly one step: a two step cell by the channel is not a dimple, so it is not filled.
	dug[dimple] = 2
	for around: Vector2i in Terrain.neighbors(dimple):
		dug[around] = maxi(dug.get(around, 0), 1)
	return "" if not _wet(dug, pieces)["levels"].has(dimple) else "Only a one step dimple fills from a channel."


func test_stone_changes_move_the_water() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	var run: Array[Vector2i] = [FLAT + Vector2i(2, 0), FLAT + Vector2i(3, 0)]
	var with: Dictionary = _wet(dug, _channel(run))
	var without: Dictionary = _wet(dug)
	return "" if with["film"].size() == 2 and without["film"].is_empty() else "A channel placed or taken up must start or stop the film."


func test_the_deep_pit_puts_a_rover_clear_and_stops_a_walker() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	_wet(dug)
	var inside: Vector2 = _middle(FLAT)
	var out: Vector2 = Terrain.clear_of_deep(inside)
	if PitWater.gap_m(out) < Terrain.ROVER_REACH_M:
		return "A rover put out of the pit must stand clear of the blocks, not %s m." % PitWater.gap_m(out)
	# A walker is refused deep water by the same test as at the ford.
	return "" if Terrain.is_deep(inside) and not Terrain.is_deep(out) else "Deep pit water must stop walkers and not the ground beside it."


func test_the_view_makes_blocks_on_the_ford_layer_and_clears_when_it_leaves() -> String:
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	PitWater.clear()
	GameState.dug.clear()
	GameState.dug.merge(_cone(FLAT, 4))
	_flood()
	var view := PitWaterView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	var problems: PackedStringArray = []
	var bodies: Array[Node] = view.get_node("Deep").get_children()
	if bodies.is_empty():
		problems.append("A deep pit must have blocks.")
	for body: Node in bodies:
		var solid := body as StaticBody3D
		if solid == null or solid.collision_layer != Ford.LAYER_WORLD or solid.collision_mask != 0:
			problems.append("A block must be a world body that looks at nothing.")
	(Engine.get_main_loop() as SceneTree).root.remove_child(view)
	view.free()
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	if not PitWater.levels().is_empty() or not PitWater.blocks().is_empty():
		problems.append("Leaving the farm must clear the water.")
	return "\n".join(problems)


func test_the_view_redraws_only_what_changed_and_follows_digging_and_filling() -> String:
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	GameState.dug.clear()
	GameState.dug.merge(_almost_deep(FLAT))
	_flood()
	GameState.dug.merge(_cone(SLOPE, 4))
	_flood()
	var view := PitWaterView.new()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(view)
	var problems: PackedStringArray = []
	var told: Array[int] = [0]
	view.changed.connect(func() -> void: told[0] += 1)
	var first: Array = view._stretches.values()
	if first.size() != 2:
		problems.append("Two pits are two stretches, not %d." % first.size())
	view._refresh()
	for water: Variant in first:
		if not is_instance_valid(water) or water.is_queued_for_deletion() or water.get_parent() != view:
			problems.append("Nothing changed, yet a stretch was redrawn.")
	if told[0] != 0:
		problems.append("Nothing changed, yet the view said so.")
	# Deepen the flat pit: its stretch is redrawn, the other one stays.
	var kept: Array = []
	for water: Variant in first:
		kept.append(water)
	GameState.dug[FLAT] = 4
	_flood()
	view._refresh()
	var survivors: int = 0
	for water: Variant in kept:
		if is_instance_valid(water) and not water.is_queued_for_deletion():
			survivors += 1
	if survivors != 1:
		problems.append("Digging one pit must redraw just that pit, %d of two kept." % survivors)
	GameState.dug.clear()
	view._refresh()
	if not view._stretches.is_empty() or not PitWater.levels().is_empty():
		problems.append("Filled in, the water must go.")
	root.remove_child(view)
	view.free()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	return "\n".join(problems)


func test_fill_levels_with_one_level_is_fill() -> String:
	var bowl: Callable = func(at: Vector2) -> float: return at.distance_to(Vector2(2.0, 2.0)) * 0.5
	var area := Rect2(0.0, 0.0, 4.0, 4.0)
	var one := VoxelWater.new()
	one.fill(area, 1.0, bowl)
	var many := VoxelWater.new()
	many.fill_levels(area, func(_at: Vector2) -> float: return 1.0, bowl)
	var problem: String = "" if one.places == many.places and one.colors == many.colors and one.places.size() > 20 else "fill and fill_levels differ."
	var none := VoxelWater.new()
	none.fill_levels(area, func(_at: Vector2) -> float: return -INF, bowl)
	if not none.places.is_empty():
		problem = "No level must be no water."
	one.free()
	many.free()
	none.free()
	return problem


func test_three_hundred_dug_cells_are_worked_out() -> String:
	var dug: Dictionary[Vector2i, int] = {}
	for site: Vector2i in [Vector2i(-21, 3), Vector2i(-27, -9), Vector2i(21, -12), Vector2i(-21, -12), Vector2i(9, -21), Vector2i(-15, -30)]:
		for x: int in range(-3, 4):
			for z: int in range(-3, 4):
				var cell: Vector2i = site + Vector2i(x, z)
				if Terrain.dig_problem(cell, _none) == "":
					dug[cell] = maxi(1, 4 - maxi(absi(x), absi(z)))
	var pieces: Dictionary[Vector2i, int] = _channel([Vector2i(-17, 3), Vector2i(-16, 3), Vector2i(-15, 3)])
	var start: int = Time.get_ticks_msec()
	var found: Dictionary = _wet(dug, pieces)
	var took: int = Time.get_ticks_msec() - start
	# The time is only told: a busy machine says nothing about the code.
	print("pit water: %d dug cells, %d wet, %d blocks, %d ms" % [dug.size(), found["levels"].size(), PitWater.blocks().size(), took])
	if dug.size() < 200 or found["levels"].size() < 20 or PitWater.blocks().is_empty():
		return "The fixture must be a lot of dug ground with water in it: %d dug, %d wet." % [dug.size(), found["levels"].size()]
	return ""


func test_a_four_step_cell_can_still_be_dug_on_flat_wet_ground() -> String:
	var dug: Dictionary[Vector2i, int] = _almost_deep(FLAT)
	var found: Dictionary = _wet(dug)
	if found["levels"].size() != 9 or not PitWater.blocks().is_empty():
		return "Nine cells of three steps are shallow water with no block: %d wet, %d blocks." % [found["levels"].size(), PitWater.blocks().size()]
	var problem: String = Terrain.dig_problem(FLAT, dug)
	if problem != "":
		return "The middle cell must be dug a fourth step, not %s" % problem
	# The rover reaches it from every side, and no point it digs at is deep.
	var middle: Vector2 = _middle(FLAT)
	for way: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if RoverController._touches_pit_water(middle + way * 2.0, -way):
			return "The rover cannot stand 2 m %s of the cell to dig it." % way
		if not RoverController.clear_of_pit_water(middle + way * 2.0, -way, Terrain.HALF_M - 2.2).is_equal_approx(middle + way * 2.0):
			return "The rover standing %s of the cell is moved." % way
	for x: int in range(-8, 9):
		for z: int in range(-8, 9):
			if PitWater.is_deep(middle + Vector2(x, z) * 0.25):
				return "Before the dig there is deep water at %s." % (middle + Vector2(x, z) * 0.25)
	dug[FLAT] = 4
	_wet(dug)
	return "" if PitWater.is_deep(middle) and not PitWater.blocks().is_empty() else "The fourth step must make the middle deep."


func test_a_walker_where_the_ground_turns_deep_is_moved_to_the_nearest_clear_spot() -> String:
	var dug: Dictionary[Vector2i, int] = _almost_deep(FLAT)
	_wet(dug)
	var inside: Vector2 = _middle(FLAT)
	if Walker.clear_of_deep_water(inside) != inside:
		return "A walker wading in shallow water stays where it is."
	dug[FLAT] = 4
	_wet(dug)
	if not Walker._is_stuck(inside):
		return "The fixture must put the walker in deep water."
	var to: Vector2 = Walker.clear_of_deep_water(inside)
	if to == inside or Walker._is_stuck(to) or not Walker._is_free(to):
		return "The walker must be put on free ground, not %s." % to
	var far: float = to.distance_to(inside)
	if far > 4.0:
		return "The walker was thrown %s m." % far
	var k: int = 1
	while k * Walker.FREE_STEP_M < far - 0.01:
		for way: int in Walker.FREE_WAYS:
			var nearer: Vector2 = inside + Vector2.from_angle(TAU * way / Walker.FREE_WAYS) * (k * Walker.FREE_STEP_M)
			if Walker._is_free(nearer):
				return "%s is free and nearer than %s." % [nearer, to]
		k += 1
	# And as the node does it, with the farm told at once.
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	GameState.dug.clear()
	GameState.dug.merge(dug)
	_flood()
	var tree: SceneTree = Engine.get_main_loop()
	var walker := Walker.new()
	tree.root.add_child(walker)
	walker.global_position = Vector3(inside.x, 0.0, inside.y)
	walker.leave_deep_water()
	var now := Vector2(walker.global_position.x, walker.global_position.z)
	var problem: String = "" if now.is_equal_approx(to) and is_equal_approx(walker.global_position.y, Terrain.height(to, dug)) else "The node was put at %s, not %s." % [now, to]
	tree.root.remove_child(walker)
	walker.free()
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	return problem


## The rover digs the cell 2 m ahead of its middle, so its middle may stand from 1 m
## to 3 m from the cell's, and with 1.2 m of nose, the nose may be in the new deep
## water. It must come out the nearest way, from each of the four sides.
func test_a_rover_after_a_dig_comes_out_the_nearest_way_from_all_four_sides() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	_wet(dug)
	var middle: Vector2 = _middle(FLAT)
	var problems: PackedStringArray = []
	for way: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var touching: int = 0
		for d: float in [1.0, 1.5, 2.0, 2.5, 3.0]:
			var at: Vector2 = middle + way * d
			var ahead: Vector2 = -way
			var out: Vector2 = RoverController.clear_of_pit_water(at, ahead, Terrain.HALF_M - 2.2)
			if not RoverController._touches_pit_water(at, ahead):
				if out != at:
					problems.append("%s at %s: clear of the water, yet moved." % [way, d])
				continue
			touching += 1
			if RoverController._touches_pit_water(out, ahead) or not RoverController._stands_clear(out, ahead):
				problems.append("%s at %s: put at %s, which is still in the water." % [way, d, out])
			if out.distance_to(at) > 3.0 or (out - middle).dot(way) <= 0.0:
				problems.append("%s at %s: put at %s, which is far or across the pit." % [way, d, out])
			# Nearest: no nearer place of the same search is clear.
			var k: int = 1
			while k * RoverController.PIT_SEARCH_STEP_M < out.distance_to(at) - 0.01:
				for turn: int in RoverController.PIT_SEARCH_WAYS:
					var nearer: Vector2 = at + Vector2.from_angle(TAU * turn / RoverController.PIT_SEARCH_WAYS) * (k * RoverController.PIT_SEARCH_STEP_M)
					if RoverController._stands_clear(nearer, ahead):
						problems.append("%s at %s: %s is clear and nearer than %s." % [way, d, nearer, out])
				k += 1
		if touching == 0:
			problems.append("%s: a rover 1 m away must have its nose in the water." % way)
	return "
".join(problems)


func test_a_rover_comes_out_around_a_wall_and_stays_on_the_land() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 4)
	_wet(dug)
	var middle: Vector2 = _middle(FLAT)
	var at: Vector2 = middle + Vector2(0.0, 1.0)
	var ahead := Vector2.UP
	var saved: Dictionary[Vector2i, int] = GameState.stone_pieces.duplicate()
	var first: Vector2 = RoverController.clear_of_pit_water(at, ahead, Terrain.HALF_M - 2.2)
	# A wall where it would stand: it must stand somewhere a wall does not reach.
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			GameState.stone_pieces[Terrain.cell_at(first) + Vector2i(x, z)] = StonePieces.WALL
	var second: Vector2 = RoverController.clear_of_pit_water(at, ahead, Terrain.HALF_M - 2.2)
	var problem: String = ""
	if first == at or second == first or not RoverController._stands_clear(second, ahead):
		problem = "A wall at %s must move the spot, not %s." % [first, second]
	var edge: Vector2 = RoverController.clear_of_pit_water(Vector2(-Terrain.HALF_M + 3.0, middle.y), ahead, Terrain.HALF_M - 2.2)
	GameState.stone_pieces.assign(saved)
	if problem == "" and edge != Vector2(-Terrain.HALF_M + 3.0, middle.y):
		problem = "Dry ground is left alone."
	return problem


func test_a_rover_and_a_walker_already_where_it_turns_deep_are_freed_by_the_view() -> String:
	var tree: SceneTree = Engine.get_main_loop()
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	var ground := TerrainGround.new()
	tree.root.add_child(ground)
	var rover := RoverController.new()
	rover.ground = ground
	tree.root.add_child(rover)
	var walker := Walker.new()
	tree.root.add_child(walker)
	GameState.dug.clear()
	GameState.dug.merge(_almost_deep(FLAT))
	_flood()
	var view := PitWaterView.new()
	tree.root.add_child(view)
	view.changed.connect(rover.leave_deep_water)
	view.changed.connect(walker.leave_deep_water)
	var middle: Vector2 = _middle(FLAT)
	var rover_at := Vector3(middle.x, Terrain.height(middle, GameState.dug), middle.y + 1.0)
	rover.global_position = rover_at
	rover.global_rotation = Vector3.ZERO
	walker.global_position = Vector3(middle.x, Terrain.height(middle, GameState.dug), middle.y)
	var problems: PackedStringArray = []
	if not rover.global_position.is_equal_approx(rover_at) or not PitWater.blocks().is_empty():
		problems.append("Shallow water must leave them alone.")
	GameState.dug[FLAT] = 4
	_flood()
	view._refresh()
	var rover_now := Vector2(rover.global_position.x, rover.global_position.z)
	var walker_now := Vector2(walker.global_position.x, walker.global_position.z)
	if PitWater.blocks().is_empty():
		problems.append("The dig must make deep water.")
	if rover_now.is_equal_approx(Vector2(rover_at.x, rover_at.z)):
		problems.append("The rover, its nose in the new deep water, was not moved.")
	if RoverController._touches_pit_water(rover_now, Vector2(-rover.global_basis.z.x, -rover.global_basis.z.z)):
		problems.append("The rover is still in the water at %s." % rover_now)
	if Walker._is_stuck(walker_now) or walker_now.is_equal_approx(middle):
		problems.append("The walker is still in the water at %s." % walker_now)
	tree.root.remove_child(view)
	view.free()
	tree.root.remove_child(walker)
	walker.free()
	tree.root.remove_child(rover)
	rover.free()
	tree.root.remove_child(ground)
	ground.free()
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	return "\n".join(problems)


func test_a_stretch_draws_only_its_own_cells_even_with_other_water_in_its_box() -> String:
	# A U of three step cells with a pit of its own in the arms: the box of the U has
	# water in it that is not the U's.
	var dug: Dictionary[Vector2i, int] = {}
	var around: Rect2i = Rect2i(FLAT + Vector2i(-2, -2), Vector2i(9, 9))
	for x: int in range(around.position.x, around.end.x):
		for z: int in range(around.position.y, around.end.y):
			var edge: int = mini(mini(x - around.position.x, around.end.x - 1 - x), mini(z - around.position.y, around.end.y - 1 - z))
			dug[Vector2i(x, z)] = mini(edge + 1, 2)
	var u: Array[Vector2i] = []
	for i: int in 5:
		u.append(FLAT + Vector2i(0, i))
		u.append(FLAT + Vector2i(4, i))
		u.append(FLAT + Vector2i(i, 4))
	var own: Vector2i = FLAT + Vector2i(2, 1)
	for cell: Vector2i in u:
		dug[cell] = 3
	dug[own] = 3
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	GameState.dug.clear()
	GameState.dug.merge(dug)
	_flood()
	var view := PitWaterView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	var problems: PackedStringArray = []
	var stretches: Array[Array] = PitWaterView._stretches_of(PitWater.levels(), PitWater.film())
	if stretches.size() != 2:
		problems.append("The U and the pit in it are two stretches, not %d." % stretches.size())
	for stretch: Array in stretches:
		var typed: Array[Vector2i] = []
		typed.assign(stretch)
		var water: VoxelWater = view._stretches.get(PitWaterView._signature(typed))
		if water == null or water.places.is_empty():
			problems.append("A stretch has no water.")
			continue
		for place: Transform3D in water.places:
			if not typed.has(Terrain.cell_at(Vector2(place.origin.x, place.origin.z))):
				problems.append("A stretch draws water at %s that is not in its cells." % place.origin)
				break
	(Engine.get_main_loop() as SceneTree).root.remove_child(view)
	view.free()
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	return "\n".join(problems)


## Not the AABB model of the ford suite: the engine's own ray and capsule.
func test_the_engine_stops_a_body_at_deep_pit_water_and_not_at_shallow() -> String:
	var tree: SceneTree = Engine.get_main_loop()
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	var problems: PackedStringArray = []
	var middle: Vector2 = _middle(FLAT)
	var view := PitWaterView.new()
	GameState.dug.clear()
	GameState.dug.merge(_cone(FLAT, 4))
	_flood()
	tree.root.add_child(view)
	var level_m: float = PitWater.level_m(middle)
	var space: PhysicsDirectSpaceState3D = tree.root.world_3d.direct_space_state
	# A frame is not run here, so the bodies may not be in the space yet.
	var from := Vector3(middle.x - 6.0, level_m + 0.3, middle.y)
	var across := PhysicsRayQueryParameters3D.create(from, from + Vector3(12.0, 0.0, 0.0), Ford.LAYER_WORLD)
	var hit: Dictionary = space.intersect_ray(across)
	if hit.is_empty() or absf(hit["position"].x - (middle.x - 1.0)) > 1.6:
		problems.append("A ray across the deep water must meet it, met %s." % [hit])
	var capsule := PhysicsShapeQueryParameters3D.new()
	capsule.shape = Walker.capsule()
	capsule.transform = Transform3D(Basis.IDENTITY, Vector3(middle.x - 6.0, level_m + 0.9, middle.y))
	capsule.motion = Vector3(12.0, 0.0, 0.0)
	capsule.collision_mask = Walker.MASK
	var safe: PackedFloat32Array = space.cast_motion(capsule)
	if safe.is_empty() or safe[0] >= 0.99:
		problems.append("A walker's capsule must be stopped by the deep water, cast gave %s." % [safe])
	elif absf(middle.x - 6.0 + 12.0 * safe[0] - (middle.x - 1.0)) > 1.6:
		problems.append("The walker was stopped %s m along, not at the pit." % (12.0 * safe[0]))
	# The ground beside is not a wall.
	var beside: Vector3 = from + Vector3(0.0, 0.0, 9.0)
	var along := PhysicsRayQueryParameters3D.create(beside, beside + Vector3(12.0, 0.0, 0.0), Ford.LAYER_WORLD)
	if not space.intersect_ray(along).is_empty():
		problems.append("A ray well beside the pit must meet nothing.")
	tree.root.remove_child(view)
	view.free()
	# Shallow: three steps in the middle, no block, the capsule goes through.
	GameState.dug.clear()
	GameState.dug.merge(_almost_deep(FLAT))
	_flood()
	var shallow := PitWaterView.new()
	tree.root.add_child(shallow)
	if not space.cast_motion(capsule).is_empty() and space.cast_motion(capsule)[0] < 0.99:
		problems.append("Shallow water must not stop a walker.")
	tree.root.remove_child(shallow)
	shallow.free()
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	return "\n".join(problems)


func test_the_view_works_out_the_water_only_when_the_digging_or_channels_change_and_once_a_frame() -> String:
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	var saved_pieces: Dictionary[Vector2i, int] = GameState.stone_pieces.duplicate()
	GameState.dug.clear()
	GameState.dug.merge(_almost_deep(FLAT))
	_flood()
	var view := PitWaterView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	var problems: PackedStringArray = []
	if view.worked_count != 1 or PitWater.levels().is_empty():
		problems.append("Loading works the water out at once, once: %d." % view.worked_count)
	var levels: Dictionary[Vector2i, float] = PitWater.levels()
	# A boulder, a wall and a pad change nothing the water is made of.
	for piece: int in [StonePieces.WALL, StonePieces.PAD]:
		GameState.stone_pieces[FLAT + Vector2i(12, 12)] = piece
		GameState.stone_changed.emit()
		view._refresh_asked()
		if view.worked_count != 1 or not is_same(PitWater.levels(), levels):
			problems.append("Piece %d is no change to the water, yet it was worked out again." % piece)
	GameState.terrain_changed.emit()
	view._refresh_asked()
	if view.worked_count != 1:
		problems.append("Nothing was dug, yet the water was worked out again.")
	# A dig is a change, and several changes in a frame are one look.
	GameState.dug[FLAT] = 4
	_flood()
	var before: int = view.queued_count
	for i: int in 5:
		GameState.terrain_changed.emit()
		GameState.stone_changed.emit()
	if view.queued_count - before != 1:
		problems.append("Ten signals in a frame are one deferred look, not %d." % (view.queued_count - before))
	view._refresh_asked()
	if view.worked_count != 2 or PitWater.blocks().is_empty():
		problems.append("A dig must work the water out, once: %d." % view.worked_count)
	# A channel is a change.
	GameState.stone_pieces[FLAT + Vector2i(2, 0)] = StonePieces.CHANNEL
	GameState.stone_changed.emit()
	view._refresh_asked()
	if view.worked_count != 3 or PitWater.film().is_empty():
		problems.append("A channel must work the water out and carry a film: %d." % view.worked_count)
	(Engine.get_main_loop() as SceneTree).root.remove_child(view)
	view.free()
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	GameState.stone_pieces.assign(saved_pieces)
	return "\n".join(problems)


## Last by name: the water is static, so other suites must not meet this one's.
func test_zz_leaves_no_water_behind() -> String:
	PitWater.clear()
	return "" if PitWater.levels().is_empty() and PitWater.gap_m(Vector2.ZERO) == INF else "Clearing must leave no water."
