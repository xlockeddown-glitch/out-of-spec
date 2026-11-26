extends RefCounted
## Stone pads level the ground under them, and walls follow the slope.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const SEED: int = 424242

var _none: Array[Transform3D] = []
var _no_pieces: Dictionary[Vector2i, int] = {}
var _no_dug: Dictionary[Vector2i, int] = {}


func _make() -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	return gs


func _at(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, 0, cell.y)


func _middle(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M


## Cells on open land where the ground leans: the highest minus the lowest of
## their points is over `at_least` m, steepest first, and a pad can be built.
func _sloped(count: int, at_least: float = 0.3) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var ranges: Dictionary[Vector2i, float] = {}
	for x: int in range(-38, 38):
		for z: int in range(-38, 38):
			var cell := Vector2i(x, z)
			if StonePieces.problem(cell, StonePieces.PAD, _no_pieces, _none) != "":
				continue
			var lean: float = StonePieces.cell_range_m(cell, _no_dug)
			if lean >= at_least:
				ranges[cell] = lean
	var cells: Array = ranges.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return ranges[a] > ranges[b] or (ranges[a] == ranges[b] and a < b))
	for cell: Vector2i in cells:
		if found.size() < count:
			found.append(cell)
	return found


## Two cells side by side on a slope, both fit for a wall and a pad.
func _pair() -> Array[Vector2i]:
	for cell: Vector2i in _sloped(40):
		for next: Vector2i in [cell + Vector2i.RIGHT, cell + Vector2i.DOWN]:
			if StonePieces.problem(next, StonePieces.PAD, _no_pieces, _none) == "" \
					and StonePieces.cell_range_m(next, _no_dug) > 0.2:
				return [cell, next]
	return []


func _points(cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for x: int in Terrain.CELL_M + 1:
		for z: int in Terrain.CELL_M + 1:
			points.append(cell * Terrain.CELL_M + Vector2i(x, z))
	return points


func test_a_pad_levels_the_ground_under_it() -> String:
	var cell: Vector2i = _sloped(1)[0]
	var problems: PackedStringArray = []
	var levels: Dictionary[Vector2i, float] = Terrain.pad_levels([cell])
	var first: Vector2i = _points(cell)[0]
	var moved: bool = false
	var total: float = 0.0
	for point: Vector2i in _points(cell):
		total += Terrain.natural(point)
		if not levels.has(point) or not is_equal_approx(levels[point], levels[first]):
			problems.append("Point %s is not at the pad's level." % point)
		elif not is_equal_approx(levels[point], Terrain.natural(point)):
			moved = true
	if not moved:
		problems.append("The pad's cell at %s was already level; the test needs a slope." % cell)
	if absf(levels[first] - total / 9.0) > 1.0 / Terrain.HEIGHT_PARTS:
		problems.append("The level must be the mean of the natural ground: %s, not %s" % [levels[first], total / 9.0])
	if levels.size() != 9:
		problems.append("A pad levels its own 9 points and no more: %d" % levels.size())
	Terrain.use_pads([cell])
	var level_m: float = levels[first]
	for spot: Vector2 in [_middle(cell), _middle(cell) + Vector2(0.9, -0.7), _middle(cell) + Vector2(-0.8, 0.95)]:
		if not is_equal_approx(Terrain.height(spot, _no_dug), level_m):
			problems.append("The ground at %s is %s, not the pad's %s." % [spot, Terrain.height(spot, _no_dug), level_m])
	var outside: Vector2i = cell * Terrain.CELL_M + Vector2i(-1, 1)
	if not is_equal_approx(Terrain.point_height(outside, _no_dug), Terrain.natural(outside)):
		problems.append("The ground beside the pad must stay as it was.")
	Terrain.use_pads([])
	if not is_equal_approx(Terrain.point_height(first, _no_dug), Terrain.natural(first)):
		problems.append("The ground must come back with no pad.")
	return "\n".join(problems)


func test_pads_that_touch_are_one_flat_top() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var levels: Dictionary[Vector2i, float] = Terrain.pad_levels([pair[0], pair[1]])
	var seen: Dictionary[float, bool] = {}
	for point: Vector2i in levels:
		seen[levels[point]] = true
	if seen.size() != 1:
		problems.append("Two pads side by side must share a level: %s" % [seen.keys()])
	if levels.size() != 15:
		problems.append("Two pads side by side level 15 points: %d" % levels.size())
	var apart: Dictionary[Vector2i, float] = Terrain.pad_levels([pair[0], pair[0] + (pair[1] - pair[0]) * 2])
	if apart.size() != 18:
		problems.append("Pads a cell apart share no points: %d" % apart.size())
	# The same pads in another order are the same ground.
	if Terrain.pad_levels([pair[1], pair[0]]) != levels:
		problems.append("The level must not depend on the order the pads were built.")
	return "\n".join(problems)


func test_building_and_taking_up_a_pad_moves_the_ground_and_says_so() -> String:
	var pair: Array[Vector2i] = _pair()
	var problems: PackedStringArray = []
	var kept_stone: int = GameState.stone
	var told: Array[int] = [0]
	var tell: Callable = func() -> void: told[0] += 1
	GameState.terrain_changed.connect(tell)
	GameState.stone = 10
	var before: float = Terrain.point_height(pair[0] * Terrain.CELL_M, GameState.dug)
	var problem: String = GameState.place_stone(_at(pair[0]), StonePieces.PAD)
	if problem != "":
		problems.append("Building a pad on a slope was refused: %s" % problem)
	var level_m: float = Terrain.level_points.get(pair[0] * Terrain.CELL_M, INF)
	if level_m == INF or not is_equal_approx(Terrain.height(_middle(pair[0]), GameState.dug), level_m):
		problems.append("The autoload's ground must be level under the pad.")
	if told[0] != 1:
		problems.append("Building a pad must tell the terrain changed once: %d" % told[0])
	# A wall does not move the ground.
	GameState.place_stone(_at(pair[1]), StonePieces.WALL)
	if told[0] != 1:
		problems.append("A wall must not tell the terrain changed.")
	GameState.place_stone(_at(pair[1]), StonePieces.TAKE_UP)
	GameState.place_stone(_at(pair[0]), StonePieces.TAKE_UP)
	if told[0] != 2:
		problems.append("Taking a pad up must tell the terrain changed: %d" % told[0])
	if not Terrain.level_points.is_empty() or not is_equal_approx(Terrain.point_height(pair[0] * Terrain.CELL_M, GameState.dug), before):
		problems.append("Taking the pad up must give the ground back.")
	GameState.terrain_changed.disconnect(tell)
	GameState.stone = kept_stone
	GameState.stone_pieces.clear()
	Terrain.use_pads([])
	return "\n".join(problems)


func test_a_pad_is_refused_on_dug_ground_over_the_limit_or_by_water() -> String:
	var cell: Vector2i = _sloped(1)[0]
	var problems: PackedStringArray = []
	var dug: Dictionary[Vector2i, int] = {cell: 1}
	if StonePieces.problem(cell, StonePieces.PAD, _no_pieces, _none, dug) != "Fill it in first.":
		problems.append("A pad on dug ground must be refused.")
	if StonePieces.problem(cell, StonePieces.PAD, {cell: StonePieces.WALL}, _none) != "Something is built here.":
		problems.append("A pad on a piece must be refused.")
	# A strip of pads down the steepest hill rises over the limit sooner or later.
	var refused: String = ""
	var line: Dictionary[Vector2i, int] = {}
	var run_x: float = absf(Terrain.natural(cell * 2 + Vector2i(2, 0)) - Terrain.natural(cell * 2))
	var run_z: float = absf(Terrain.natural(cell * 2 + Vector2i(0, 2)) - Terrain.natural(cell * 2))
	var way: Vector2i = Vector2i.RIGHT if run_x > run_z else Vector2i.DOWN
	for i: int in 14:
		var next: Vector2i = cell + way * i
		refused = StonePieces.problem(next, StonePieces.PAD, line, _none)
		if refused != "":
			break
		line[next] = StonePieces.PAD
	if refused != "Too steep to level.":
		problems.append("A long strip of pads on a slope must be refused for steepness: '%s' after %d" % [refused, line.size()])
	elif line.is_empty():
		problems.append("A single pad on a slope must still be built.")
	elif Terrain.pad_shift_m(Terrain.pad_levels(StonePieces.pad_cells(line))) > Terrain.PAD_SHIFT_M:
		problems.append("Pads that were built came to be over the limit.")
	var wet: Vector2i = Vector2i.ZERO
	var found: bool = false
	for x: int in range(20, 40):
		for z: int in range(-6, 14):
			var near := Vector2i(x, z)
			if not found and Terrain.is_near_water(near) and Terrain.can_dig(near):
				wet = near
				found = true
	if not found:
		problems.append("No cell by the water to try.")
	else:
		for kind: int in [StonePieces.PAD, StonePieces.WALL]:
			if StonePieces.problem(wet, kind, _no_pieces, _none) == "":
				problems.append("A %s by the water at %s was built." % [StonePieces.kind_name(kind), wet])
	if StonePieces.problem(Vector2i.ZERO, StonePieces.PAD, _no_pieces, _none) == "":
		problems.append("A pad on the level farm was built.")
	return "\n".join(problems)


func test_a_wall_on_a_slope_is_built_and_its_base_follows_the_ground() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var lows: Array[float] = []
	for cell: Vector2i in pair:
		var problem: String = StonePieces.problem(cell, StonePieces.WALL, _no_pieces, _none, _no_dug)
		if problem != "":
			problems.append("A wall at %s on a slope was refused: %s" % [cell, problem])
		var box: AABB = StonePieces.wall_box(cell, _no_dug)
		var lowest: float = INF
		for point: Vector2i in _points(cell):
			lowest = minf(lowest, Terrain.point_height(point, _no_dug))
		if not is_equal_approx(box.position.y + 0.15, lowest):
			problems.append("A wall's base must reach the lowest ground under it: %s vs %s" % [box.position.y + 0.15, lowest])
		if not is_equal_approx(box.end.y, Terrain.height(_middle(cell), _no_dug) + StonePieces.WALL_M):
			problems.append("A wall's top must stand %s m over its own middle." % StonePieces.WALL_M)
		lows.append(box.position.y)
	if is_equal_approx(lows[0], lows[1]):
		problems.append("Two walls on a slope must stand at their own heights, not at one.")
	if StonePieces.problem(pair[0], StonePieces.WALL, _no_pieces, _none, {pair[0]: 4}) != "Too steep for a wall.":
		problems.append("A wall on a sheer drop must be refused.")
	return "\n".join(problems)


func test_a_wall_beside_a_pad_stands_down_to_the_pad() -> String:
	var pair: Array[Vector2i] = _pair()
	var problems: PackedStringArray = []
	Terrain.use_pads([pair[0]])
	var level_m: float = Terrain.level_points[pair[0] * Terrain.CELL_M]
	var box: AABB = StonePieces.wall_box(pair[1], _no_dug)
	var shares: bool = false
	for point: Vector2i in _points(pair[1]):
		shares = shares or Terrain.level_points.has(point)
	if not shares:
		problems.append("The wall's cell shares no point with the pad.")
	elif box.position.y + 0.15 > level_m + 0.0001:
		problems.append("The wall's base must reach down to the pad's level: %s vs %s" % [box.position.y + 0.15, level_m])
	Terrain.use_pads([])
	return "\n".join(problems)


func test_a_host_a_guest_and_a_save_have_the_same_level_ground() -> String:
	var pair: Array[Vector2i] = _pair()
	var problems: PackedStringArray = []
	var host: Node = _make()
	host.stone = 20
	for cell: Vector2i in pair:
		if host.place_stone(_at(cell), StonePieces.PAD) != "":
			problems.append("The host could not build a pad at %s." % cell)
	var want: Dictionary[Vector2i, float] = Terrain.pad_levels(StonePieces.pad_cells(host.stone_pieces))
	var data: Dictionary = host.farm_to_dict()
	var guest: Node = _make()
	if guest.farm_from_dict(data) != "":
		problems.append("The guest could not take the farm.")
	if Terrain.pad_levels(StonePieces.pad_cells(guest.stone_pieces)) != want:
		problems.append("A guest's ground must be the host's.")
	var saved: Dictionary = SaveGame.from_bytes(SaveGame.to_bytes({ "clock": FarmSync.clock(), "farm": data }), "test")
	var loaded: Node = _make()
	if saved.has("problem") or loaded.farm_from_dict(saved["data"]["farm"]) != "":
		problems.append("A saved farm with pads must load: %s" % saved.get("problem", ""))
	elif Terrain.pad_levels(StonePieces.pad_cells(loaded.stone_pieces)) != want:
		problems.append("A loaded farm's ground must be the saved one's.")
	# The game's own farm turns it into ground on loading and when a guest is told.
	var keep: Dictionary = GameState.farm_to_dict()
	if GameState.farm_from_dict(data) != "" or Terrain.level_points != want:
		problems.append("Loading a farm must level the ground under its pads.")
	if GameState.farm_from_dict(keep) != "" or not Terrain.level_points.is_empty():
		problems.append("Loading a farm with no pads must give the ground back.")
	Terrain.use_pads([])
	host.free()
	guest.free()
	loaded.free()
	return "\n".join(problems)
