extends RefCounted
## Water in dug pits: where it stands, that it lies level and never spills, how a
## channel carries it, and what it does to a rover and a walker.

## Open, dug-able ground: nearly flat, a gentle hillside, and one so steep a pit drains.
const FLAT := Vector2i(-21, 3)
const SLOPE := Vector2i(9, -21)
const STEEP := Vector2i(21, -12)

var _none: Dictionary[Vector2i, int] = {}


## Steps for a pit `depth` deep in the middle: each ring out is a step shallower.
func _cone(middle: Vector2i, depth: int, into: Dictionary[Vector2i, int] = {}) -> Dictionary[Vector2i, int]:
	for x: int in range(-depth + 1, depth):
		for z: int in range(-depth + 1, depth):
			into[middle + Vector2i(x, z)] = depth - maxi(absi(x), absi(z))
	return into


func _wet(dug: Dictionary[Vector2i, int], pieces: Dictionary[Vector2i, int] = {}) -> Dictionary:
	var found: Dictionary = PitWater.work_out(dug, pieces)
	PitWater.use(found, dug)
	return found


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
	return "" if found["levels"].is_empty() else "A one step dimple must not reach the water: %s" % [found["levels"]]


func test_a_two_step_pit_holds_shallow_water_that_does_not_stop_a_rover() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 2)
	_wet(dug)
	var middle: Vector2 = _middle(FLAT)
	var depth: float = PitWater.depth_m(middle)
	if depth < 0.2 or depth > 0.7:
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
	var deep: int = 0
	for x: int in range(-40, 41):
		for z: int in range(-40, 41):
			var at: Vector2 = middle + Vector2(x, z) * 0.25
			if PitWater.is_deep(at):
				deep += 1
				if PitWater.gap_m(at) > 0.0:
					return "Deep water at %s is not under a block." % at
	return "" if deep > 20 else "Only %d deep points." % deep


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
	for cell: Vector2i in levels:
		for around: Vector2i in Terrain.neighbors(cell):
			if levels.has(around):
				continue
			if PitWater._ground_m(around, dug) < levels[cell] - 0.0001:
				return "%s: water at %s spills over the lower ground at %s." % [label, cell, around]
	return ""


func test_water_lies_level_and_never_spills_over_a_rim() -> String:
	var problems: PackedStringArray = []
	var wet: int = 0
	for site: Vector2i in [FLAT, SLOPE, Vector2i(-27, -9), Vector2i(-21, -12), Vector2i(-15, -30)]:
		for depth: int in [2, 3, 4]:
			var dug: Dictionary[Vector2i, int] = _cone(site, depth)
			if _wet(dug)["levels"].is_empty():
				continue
			wet += 1
			var problem: String = _lies_level(dug, "%s depth %d" % [site, depth])
			if problem != "":
				problems.append(problem)
	var two: Dictionary[Vector2i, int] = _cone(FLAT, 3)
	_cone(FLAT + Vector2i(5, 1), 3, two)
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
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 3)
	_cone(SLOPE, 3, dug)
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
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 3)
	if _wet(dug)["levels"].is_empty() or PitWater.blocks().is_empty():
		return "A pit of three must hold deep water."
	var shallow: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in dug:
		shallow[cell] = dug[cell] - 1 if dug[cell] > 1 else 1
	var found: Dictionary = _wet(shallow)
	if found["levels"].is_empty() or not PitWater.blocks().is_empty():
		return "One step filled leaves shallow water with no blocks: %s" % [found["levels"]]
	for cell: Vector2i in shallow:
		shallow[cell] = 1
	return "" if _wet(shallow)["levels"].is_empty() and PitWater.depth_m(_middle(FLAT)) == 0.0 else "A pit filled to one step must be dry."


func test_a_channel_beside_a_wet_pit_carries_a_film_to_a_lower_dimple() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 3)
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
	var away: Dictionary = _wet(_cone(FLAT, 3), _channel([FLAT + Vector2i(9, 0), FLAT + Vector2i(10, 0)]))
	return "" if away["film"].is_empty() else "A channel away from the pit must stay dry."


func test_a_one_step_dimple_by_a_fed_channel_fills_only_if_lower() -> String:
	var run: Array[Vector2i] = [FLAT + Vector2i(2, 0), FLAT + Vector2i(3, 0), FLAT + Vector2i(4, 0), FLAT + Vector2i(5, 0)]
	var dimple: Vector2i = FLAT + Vector2i(5, 1)
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 3)
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
	return "" if not unfed["levels"].has(dimple) else "An unfed channel fills nothing."


func test_stone_changes_move_the_water() -> String:
	var dug: Dictionary[Vector2i, int] = _cone(FLAT, 3)
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
	if not PitWater.levels().is_empty() or not PitWater.blocks().is_empty():
		problems.append("Leaving the farm must clear the water.")
	return "\n".join(problems)


func test_the_view_redraws_only_what_changed_and_follows_digging_and_filling() -> String:
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	GameState.dug.clear()
	GameState.dug.merge(_cone(FLAT, 3))
	GameState.dug.merge(_cone(SLOPE, 4))
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
	# Deepen the slope pit: its stretch is redrawn, the other one stays.
	var kept: Array = []
	for water: Variant in first:
		kept.append(water)
	GameState.dug[SLOPE + Vector2i(1, 0)] = 4
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


func test_three_hundred_dug_cells_are_worked_out_quickly() -> String:
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
	print("pit water: %d dug cells, %d wet, %d blocks, %d ms" % [dug.size(), found["levels"].size(), PitWater.blocks().size(), took])
	return "" if took < 400 else "Working out the water took %d ms." % took


## Last by name: the water is static, so other suites must not meet this one's.
func test_zz_leaves_no_water_behind() -> String:
	PitWater.clear()
	return "" if PitWater.levels().is_empty() and PitWater.gap_m(Vector2.ZERO) == INF else "Clearing must leave no water."
