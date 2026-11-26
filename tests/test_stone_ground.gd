extends RefCounted
## Stone pads level the ground under them, and walls follow the slope. A group of
## pads is levelled only if the whole group can be; otherwise it follows the ground.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const SEED: int = 424242
const NOWHERE: Vector2i = Vector2i(9999, 9999)

var _none: Array[Transform3D] = []
var _no_pieces: Dictionary[Vector2i, int] = {}
var _no_dug: Dictionary[Vector2i, int] = {}
var _no_walkers: Array[Vector2] = []


func _make() -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	return gs


func _at(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, 0, cell.y)


func _middle(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M


## What the tests change in the game's own farm, to be put back.
func _keep() -> Dictionary:
	return {
		"pieces": GameState.stone_pieces.duplicate(),
		"dug": GameState.dug.duplicate(),
		"levels": Terrain.level_points.duplicate(),
		"stone": GameState.stone,
		"seep": GameState.pit_seep.duplicate(),
		"tunnels": GameState.rover_in_tunnels,
		"rovers": GameState.rover_transforms.duplicate(),
	}


func _restore(kept: Dictionary) -> void:
	GameState.stone_pieces.assign(kept["pieces"])
	GameState.dug.assign(kept["dug"])
	GameState.stone = kept["stone"]
	Terrain.level_points = kept["levels"]
	GameState.pit_seep.assign(kept["seep"])
	GameState.rover_in_tunnels = kept["tunnels"]
	GameState.rover_transforms = kept["rovers"]
	CoopWalkers.out.erase("test_walker")


## The game's farm holds just these pieces, the ground levelled as the loader does.
func _hold(pieces: Dictionary[Vector2i, int]) -> void:
	GameState.stone_pieces.assign(pieces)
	GameState._level_pads()


## Cells on open land where the ground leans: the highest minus the lowest of
## their points is over `at_least` m, steepest first, and a pad can be built.
func _sloped(count: int, at_least: float = 0.3) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var ranges: Dictionary[Vector2i, float] = {}
	for x: int in range(-38, 38):
		for z: int in range(-38, 38):
			var cell := Vector2i(x, z)
			if StonePieces.problem(cell, StonePieces.PAD, _no_pieces, _none, _no_dug) != "":
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
			if StonePieces.problem(next, StonePieces.PAD, _no_pieces, _none, _no_dug) == "" \
					and StonePieces.cell_range_m(next, _no_dug) > 0.2:
				return [cell, next]
	return []


## A strip of cells up the steepest hill that goes over the limit as one group
## `extra` cells after it first does: [] if the hill has none. With extra = 0 the
## strip without its last cell can be levelled and the whole strip can't.
func _strip(extra: int) -> Array[Vector2i]:
	for start: Vector2i in _sloped(30):
		for way: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var line: Array[Vector2i] = []
			var built: Dictionary[Vector2i, int] = {}
			var over: int = -1
			for i: int in 30:
				var next: Vector2i = start + way * i
				if not Terrain.can_dig(next):
					break
				line.append(next)
				var why: String = Terrain.group_unlevelled(line, _no_dug)
				if over < 0 and why == "":
					# Every pad before the limit must be buildable one by one.
					if StonePieces.problem(next, StonePieces.PAD, built, _none, _no_dug) != "":
						break
					built[next] = StonePieces.PAD
				elif over < 0 and why == "too steep":
					over = i
				elif over < 0:
					break
				if over >= 0 and i == over + extra:
					return line
	return []


## A cell on a slope at least 4 cells from every one of `from`, or NOWHERE.
func _apart(from: Array[Vector2i]) -> Vector2i:
	for cell: Vector2i in _sloped(80):
		var far: bool = true
		for used: Vector2i in from:
			if maxi(absi(cell.x - used.x), absi(cell.y - used.y)) < 4:
				far = false
		if far:
			return cell
	return NOWHERE


## A cell by the water on open land, or NOWHERE.
func _wet() -> Vector2i:
	for x: int in range(20, 40):
		for z: int in range(-6, 14):
			var near := Vector2i(x, z)
			if Terrain.is_near_water(near) and Terrain.can_dig(near):
				return near
	return NOWHERE


func _points(cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for x: int in Terrain.CELL_M + 1:
		for z: int in Terrain.CELL_M + 1:
			points.append(cell * Terrain.CELL_M + Vector2i(x, z))
	return points


func _pads(cells: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var pieces: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in cells:
		pieces[cell] = StonePieces.PAD
	return pieces


func test_a_pad_levels_the_ground_under_it() -> String:
	var cells: Array[Vector2i] = _sloped(1)
	if cells.is_empty():
		return "No sloped cell to build on."
	var cell: Vector2i = cells[0]
	var problems: PackedStringArray = []
	var levels: Dictionary[Vector2i, float] = Terrain.pad_levels([cell], _no_dug)
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
	var kept: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
	Terrain.use_pads([cell], _no_dug)
	var level_m: float = levels[first]
	for spot: Vector2 in [_middle(cell), _middle(cell) + Vector2(0.9, -0.7), _middle(cell) + Vector2(-0.8, 0.95)]:
		if not is_equal_approx(Terrain.height(spot, _no_dug), level_m):
			problems.append("The ground at %s is %s, not the pad's %s." % [spot, Terrain.height(spot, _no_dug), level_m])
	var outside: Vector2i = cell * Terrain.CELL_M + Vector2i(-1, 1)
	if not is_equal_approx(Terrain.point_height(outside, _no_dug), Terrain.natural(outside)):
		problems.append("The ground beside the pad must stay as it was.")
	Terrain.use_pads([], _no_dug)
	if not is_equal_approx(Terrain.point_height(first, _no_dug), Terrain.natural(first)):
		problems.append("The ground must come back with no pad.")
	Terrain.level_points = kept
	return "\n".join(problems)


func test_pads_that_touch_are_one_flat_top() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var levels: Dictionary[Vector2i, float] = Terrain.pad_levels([pair[0], pair[1]], _no_dug)
	var seen: Dictionary[float, bool] = {}
	for point: Vector2i in levels:
		seen[levels[point]] = true
	if seen.size() != 1:
		problems.append("Two pads side by side must share a level: %s" % [seen.keys()])
	if levels.size() != 15:
		problems.append("Two pads side by side level 15 points: %d" % levels.size())
	var apart: Dictionary[Vector2i, float] = Terrain.pad_levels([pair[0], pair[0] + (pair[1] - pair[0]) * 2], _no_dug)
	if apart.size() != 18:
		problems.append("Pads a cell apart share no points: %d" % apart.size())
	# The same pads in another order are the same ground.
	if Terrain.pad_levels([pair[1], pair[0]], _no_dug) != levels:
		problems.append("The level must not depend on the order the pads were built.")
	return "\n".join(problems)


func test_a_group_is_levelled_only_if_all_of_it_can_be() -> String:
	var strip: Array[Vector2i] = _strip(0)
	if strip.size() < 3:
		return "No strip of cells up a hill that goes over the limit."
	var problems: PackedStringArray = []
	var fits: Array[Vector2i] = strip.slice(0, strip.size() - 1)
	if Terrain.group_unlevelled(fits, _no_dug) != "" or Terrain.pad_levels(fits, _no_dug).is_empty():
		problems.append("The strip without its last pad can be levelled.")
	# Over the limit anywhere, the whole group follows the ground.
	if not Terrain.pad_levels(strip, _no_dug).is_empty():
		problems.append("A group over the limit must not be levelled at all.")
	# And it does not stop a group elsewhere being levelled.
	var other: Vector2i = _apart(strip)
	if other == NOWHERE:
		problems.append("No second slope to try.")
	else:
		var both: Array[Vector2i] = strip.duplicate()
		both.append(other)
		var levels: Dictionary[Vector2i, float] = Terrain.pad_levels(both, _no_dug)
		if levels.size() != 9 or not levels.has(other * Terrain.CELL_M):
			problems.append("The pad apart from the strip must still be levelled: %d points." % levels.size())
	# A pad on dug ground, as an old save may hold, spoils its group and only that.
	var dug_cell: Vector2i = strip[0]
	var dug: Dictionary[Vector2i, int] = {dug_cell: 1}
	if Terrain.group_unlevelled([dug_cell], dug) != "on dug ground" or not Terrain.pad_levels([dug_cell], dug).is_empty():
		problems.append("A pad on a dug cell must not be levelled.")
	if Terrain.group_unlevelled([strip[0], strip[1]], dug) == "" or not Terrain.pad_levels([strip[0], strip[1]], dug).is_empty():
		problems.append("A group with a pad on dug ground must not be levelled.")
	if Terrain.pad_levels([strip[0], strip[2]], dug).size() != 9:
		problems.append("A pad apart from the one on dug ground is still levelled.")
	# A pad by the water.
	var wet: Vector2i = _wet()
	if wet == NOWHERE:
		problems.append("No cell by the water to try.")
	elif Terrain.group_unlevelled([wet], _no_dug) != "by the water" or not Terrain.pad_levels([wet], _no_dug).is_empty():
		problems.append("A pad by the water must not be levelled.")
	var kept: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
	Terrain.use_pads(strip, _no_dug)
	for point: Vector2i in Terrain.group_points(strip):
		if not is_equal_approx(Terrain.point_height(point, _no_dug), Terrain.natural(point)):
			problems.append("An unlevelled group's ground at %s must be the natural ground." % point)
			break
	Terrain.level_points = kept
	return "\n".join(problems)


func test_building_and_taking_up_a_pad_moves_the_ground_and_says_so() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var kept: Dictionary = _keep()
	_hold({})
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
	_restore(kept)
	return "\n".join(problems)


func test_a_pad_is_refused_on_dug_ground_over_the_limit_or_by_water() -> String:
	var strip: Array[Vector2i] = _strip(0)
	if strip.size() < 3:
		return "No strip of cells up a hill that goes over the limit."
	var problems: PackedStringArray = []
	var cell: Vector2i = strip[0]
	var dug: Dictionary[Vector2i, int] = {cell: 1}
	if StonePieces.problem(cell, StonePieces.PAD, _no_pieces, _none, dug) != "Fill it in first.":
		problems.append("A pad on dug ground must be refused.")
	if StonePieces.problem(cell, StonePieces.PAD, {cell: StonePieces.WALL}, _none, _no_dug) != "Something is built here.":
		problems.append("A pad on a piece must be refused.")
	# A strip of pads up the hill goes over the limit sooner or later: the pad that
	# takes it over is refused, the ones before were built.
	var fits: Array[Vector2i] = strip.slice(0, strip.size() - 1)
	var line: Dictionary[Vector2i, int] = _pads(fits)
	var refused: String = StonePieces.problem(strip.back(), StonePieces.PAD, line, _none, _no_dug)
	if refused != "Too steep to level.":
		problems.append("The pad that takes a strip over the limit must be refused for steepness: '%s'" % refused)
	var end: Vector2i = fits.back()
	var rest: Dictionary[Vector2i, int] = line.duplicate()
	rest.erase(end)
	if StonePieces.problem(end, StonePieces.PAD, rest, _none, _no_dug) != "":
		problems.append("The last pad that fits must be built: %s" % StonePieces.problem(end, StonePieces.PAD, rest, _none, _no_dug))
	# The steep group stops only that group: a pad elsewhere is built.
	var other: Vector2i = _apart(strip)
	if other == NOWHERE:
		problems.append("No second slope to try.")
	elif StonePieces.problem(other, StonePieces.PAD, line, _none, _no_dug) != "":
		problems.append("A pad apart from the steep strip must be built: %s" % StonePieces.problem(other, StonePieces.PAD, line, _none, _no_dug))
	# A pad beside one that can't be levelled (a save from before the rules).
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		problems.append("No two cells side by side on a slope.")
	else:
		var old: Dictionary[Vector2i, int] = {pair[0]: StonePieces.PAD}
		var old_dug: Dictionary[Vector2i, int] = {pair[0]: 1}
		if StonePieces.problem(pair[1], StonePieces.PAD, old, _none, old_dug) != "Next to a pad that can't be levelled.":
			problems.append("A pad beside a pad on dug ground must be refused.")
		if StonePieces.problem(pair[1], StonePieces.WALL, old, _none, old_dug) != "":
			problems.append("A wall beside a pad on dug ground must still be built.")
	var wet: Vector2i = _wet()
	if wet == NOWHERE:
		problems.append("No cell by the water to try.")
	else:
		for kind: int in [StonePieces.PAD, StonePieces.WALL]:
			if StonePieces.problem(wet, kind, _no_pieces, _none, _no_dug) == "":
				problems.append("A %s by the water at %s was built." % [StonePieces.kind_name(kind), wet])
	if StonePieces.problem(Vector2i.ZERO, StonePieces.PAD, _no_pieces, _none, _no_dug) == "":
		problems.append("A pad on the level farm was built.")
	return "\n".join(problems)


func test_a_pad_is_refused_where_something_stands_or_would_be_moved_too_far() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var old: Dictionary[Vector2i, int] = {pair[0]: StonePieces.PAD}
	# A rover or a player on foot on the new cell, or on a pad it would join.
	for stands: Vector2i in pair:
		var pose := Transform3D(Basis.IDENTITY, Vector3(_middle(stands).x, 0.0, _middle(stands).y))
		var rovers: Array[Transform3D] = [pose]
		var walkers: Array[Vector2] = [_middle(stands)]
		var rover_says: String = StonePieces.problem(pair[1], StonePieces.PAD, old, rovers, _no_dug)
		if rover_says != "The rover is in the way. Back it up.":
			problems.append("A rover on %s must stop a pad at %s: '%s'" % [stands, pair[1], rover_says])
		var walker_says: String = StonePieces.problem(pair[1], StonePieces.PAD, old, _none, _no_dug, walkers)
		if walker_says != "Someone is standing there.":
			problems.append("A player on %s must stop a pad at %s: '%s'" % [stands, pair[1], walker_says])
	if StonePieces.problem(pair[1], StonePieces.PAD, old, _none, _no_dug, _no_walkers) != "":
		problems.append("With nobody there the pad is built.")
	# The game asks where the players on foot are.
	var kept: Dictionary = _keep()
	_hold({})
	GameState.stone = 10
	GameState.place_stone(_at(pair[0]), StonePieces.PAD)
	CoopWalkers.out["test_walker"] = [_middle(pair[0]).x, 0.0, _middle(pair[0]).y, 0.0, 0.0]
	var shape: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
	if GameState.place_stone(_at(pair[1]), StonePieces.PAD) != "Someone is standing there.":
		problems.append("The game must refuse a pad beside the one a player stands on.")
	if GameState.stone_pieces.has(pair[1]) or Terrain.level_points != shape:
		problems.append("A refused pad must change nothing.")
	CoopWalkers.out.erase("test_walker")
	if GameState.place_stone(_at(pair[1]), StonePieces.PAD) != "":
		problems.append("With the player gone the pad is built.")
	# A pad that would move the pad it joins by more than the limit is refused,
	# wherever the farm's hills let that happen at all.
	for first: Vector2i in _sloped(60):
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var group: Array[Vector2i] = [first, first + step]
			if Terrain.group_unlevelled(group, _no_dug) != "":
				continue
			var alone: Dictionary[Vector2i, float] = Terrain.pad_levels([first], _no_dug)
			var joined: Dictionary[Vector2i, float] = Terrain.pad_levels(group, _no_dug)
			var shift: float = absf(joined[first * Terrain.CELL_M] - alone[first * Terrain.CELL_M])
			var verdict: String = StonePieces.problem(first + step, StonePieces.PAD, {first: StonePieces.PAD}, _none, _no_dug)
			if shift > Terrain.PAD_SHIFT_M and verdict != "That would move the pad beside it too far.":
				problems.append("A pad that moves the pad at %s by %s must be refused: '%s'" % [first, shift, verdict])
			if shift <= Terrain.PAD_SHIFT_M and verdict == "That would move the pad beside it too far.":
				problems.append("A pad that moves the pad at %s by only %s was refused." % [first, shift])
	_restore(kept)
	return "\n".join(problems)


func test_a_pad_joining_another_levels_both_and_the_game_tells() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var kept: Dictionary = _keep()
	_hold({})
	var told: Array[int] = [0]
	var tell: Callable = func() -> void: told[0] += 1
	GameState.terrain_changed.connect(tell)
	GameState.stone = 20
	if GameState.place_stone(_at(pair[0]), StonePieces.PAD) != "":
		problems.append("The first pad was refused.")
	var alone: float = Terrain.level_points.get(pair[0] * Terrain.CELL_M, INF)
	if GameState.place_stone(_at(pair[1]), StonePieces.PAD) != "":
		problems.append("The pad beside it was refused.")
	var joined: float = Terrain.level_points.get(pair[0] * Terrain.CELL_M, INF)
	var want: Dictionary[Vector2i, float] = Terrain.pad_levels(StonePieces.pad_cells(GameState.stone_pieces), GameState.dug)
	if Terrain.level_points != want or want.size() != 15:
		problems.append("Two pads must be one flat top of 15 points: %d" % Terrain.level_points.size())
	if alone == INF or absf(joined - alone) > Terrain.PAD_SHIFT_M:
		problems.append("The first pad may move at most the limit: %s to %s" % [alone, joined])
	if told[0] != 2:
		problems.append("Each pad must tell the terrain changed: %d" % told[0])
	GameState.terrain_changed.disconnect(tell)
	_restore(kept)
	return "\n".join(problems)


func test_taking_up_a_pad_may_leave_a_group_unlevelled_and_lifts_what_stands_on_it() -> String:
	var strip: Array[Vector2i] = _strip(3)
	if strip.size() < 6:
		return "No strip of cells up a hill that goes well over the limit."
	var problems: PackedStringArray = []
	var kept: Dictionary = _keep()
	_hold(_pads(strip))
	if not Terrain.level_points.is_empty():
		problems.append("A strip over the limit (an old save's) must not be levelled.")
	var told: Array[int] = [0]
	var tell: Callable = func() -> void: told[0] += 1
	GameState.terrain_changed.connect(tell)
	# Take up the first: what is left is still over the limit, so nothing moves.
	if GameState.place_stone(_at(strip[0]), StonePieces.TAKE_UP) != "":
		problems.append("Taking up a pad of a steep group was refused.")
	var rest: Array[Vector2i] = StonePieces.pad_cells(GameState.stone_pieces)
	if Terrain.group_unlevelled(rest, GameState.dug) != "too steep":
		problems.append("The test needs what is left to be over the limit.")
	elif not Terrain.level_points.is_empty() or told[0] != 0:
		problems.append("A group still over the limit stays unlevelled and nothing is told: %d" % told[0])
	# Someone stands low on a pad of the group; taking up from the far end brings
	# the group under the limit, the ground is raised and they are lifted with it.
	var spot: Vector2 = _middle(strip[1])
	GameState.rover_transforms["test_rover"] = Transform3D(Basis.IDENTITY, Vector3(spot.x, -50.0, spot.y))
	CoopWalkers.out["test_walker"] = [spot.x, -50.0, spot.y, 0.0, 0.0]
	var i: int = strip.size() - 1
	while i > 1 and Terrain.level_points.is_empty():
		GameState.place_stone(_at(strip[i]), StonePieces.TAKE_UP)
		i -= 1
	if Terrain.level_points.is_empty():
		problems.append("Taking up the far pads must bring the group under the limit.")
	elif told[0] != 1:
		problems.append("The ground rising must be told once: %d" % told[0])
	var ground: float = Terrain.height(spot, GameState.dug)
	var pose: Transform3D = GameState.rover_transforms["test_rover"]
	if pose.origin.y < ground - 0.0001:
		problems.append("A rover on the pads must be lifted to the ground: %s under %s" % [pose.origin.y, ground])
	var walker: Array = CoopWalkers.out["test_walker"]
	if walker[1] < ground - 0.0001:
		problems.append("A player on the pads must be lifted to the ground: %s under %s" % [walker[1], ground])
	if Terrain.level_points != Terrain.pad_levels(StonePieces.pad_cells(GameState.stone_pieces), GameState.dug):
		problems.append("The ground must be what the pads left make.")
	GameState.terrain_changed.disconnect(tell)
	_restore(kept)
	return "\n".join(problems)


func test_digging_beside_a_pad_is_refused_when_the_side_is_too_steep() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var kept: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
	var dug: Dictionary[Vector2i, int] = {}
	Terrain.use_pads([], _no_dug)
	if StonePieces.dig_beside_pad_problem(pair[1], dug) != "":
		problems.append("With no pads digging is never held up by one.")
	Terrain.use_pads([pair[0]], _no_dug)
	var refused_at: int = 0
	for depth: int in range(1, 7):
		dug[pair[1]] = depth
		if StonePieces.dig_beside_pad_problem(pair[1], dug) == "Too steep beside the pad.":
			refused_at = depth
			break
	if refused_at == 0:
		problems.append("A pit dug deeper and deeper beside a pad must end up too steep to climb out of.")
	# A cell far from the pad is not held up by it.
	var far: Vector2i = _apart([pair[0]])
	if far != NOWHERE and StonePieces.dig_beside_pad_problem(far, {far: 5}) != "":
		problems.append("Digging away from the pads must not be held up by them.")
	Terrain.level_points = kept
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


func test_a_wall_beside_a_pad_is_checked_against_the_levelled_ground() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var kept: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
	Terrain.use_pads([], _no_dug)
	var natural_range: float = StonePieces.cell_range_m(pair[1], _no_dug)
	var natural_box: AABB = StonePieces.wall_box(pair[1], _no_dug)
	Terrain.use_pads([pair[0]], _no_dug)
	var level_m: float = Terrain.level_points[pair[0] * Terrain.CELL_M]
	var shares: bool = false
	var low: float = INF
	var high: float = -INF
	for point: Vector2i in _points(pair[1]):
		shares = shares or Terrain.level_points.has(point)
		low = minf(low, Terrain.point_height(point, _no_dug))
		high = maxf(high, Terrain.point_height(point, _no_dug))
	var range_m: float = StonePieces.cell_range_m(pair[1], _no_dug)
	var box: AABB = StonePieces.wall_box(pair[1], _no_dug)
	if not shares:
		problems.append("The wall's cell shares no point with the pad.")
	if not is_equal_approx(range_m, high - low):
		problems.append("The wall's steepness must be read off the levelled ground: %s vs %s" % [range_m, high - low])
	if is_equal_approx(range_m, natural_range) and is_equal_approx(box.position.y, natural_box.position.y):
		problems.append("The pad beside the wall must change what the wall stands on.")
	if box.position.y + 0.15 > level_m + 0.0001:
		problems.append("The wall's base must reach down to the pad's level: %s vs %s" % [box.position.y + 0.15, level_m])
	var verdict: String = StonePieces.problem(pair[1], StonePieces.WALL, {pair[0]: StonePieces.PAD}, _none, _no_dug)
	if (verdict == "Too steep for a wall.") != (range_m > StonePieces.WALL_RANGE_M):
		problems.append("A wall's refusal must follow the levelled ground: '%s' at a range of %s" % [verdict, range_m])
	Terrain.level_points = kept
	return "\n".join(problems)


func test_the_ground_shows_a_pad_coming_and_going() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var kept: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
	Terrain.use_pads([], _no_dug)
	var ground := TerrainGround.new()
	ground._ready()
	var corner: Vector2i = pair[0] * Terrain.CELL_M
	var index: int = ground._index(corner.x, corner.y)
	var natural_m: float = Terrain.natural(corner)
	if not is_equal_approx(ground._heights[index], natural_m):
		problems.append("The ground must start natural.")
	Terrain.use_pads([pair[0]], _no_dug)
	var level_m: float = Terrain.level_points[corner]
	ground.show_dug(_no_dug)
	for point: Vector2i in _points(pair[0]):
		var at: int = ground._index(point.x, point.y)
		if not is_equal_approx(ground._heights[at], level_m) or not is_equal_approx(ground._shape.map_data[at], level_m):
			problems.append("The ground and what is driven on must be the pad's at %s: %s, %s" % [point, ground._heights[at], ground._shape.map_data[at]])
			break
	# A second pad: the first one's points move too.
	Terrain.use_pads([pair[0], pair[1]], _no_dug)
	ground.show_dug(_no_dug)
	for point: Vector2i in _points(pair[1]):
		var at: int = ground._index(point.x, point.y)
		if not is_equal_approx(ground._shape.map_data[at], Terrain.level_points[point]):
			problems.append("Joining pads must show the new level at %s." % point)
			break
	if not is_equal_approx(ground._heights[index], Terrain.level_points[corner]):
		problems.append("The first pad's ground must move when another joins it.")
	Terrain.use_pads([], _no_dug)
	ground.show_dug(_no_dug)
	if not is_equal_approx(ground._heights[index], natural_m) or not is_equal_approx(ground._shape.map_data[index], natural_m):
		problems.append("Taking the pads up must give the ground back.")
	ground.free()
	Terrain.level_points = kept
	return "\n".join(problems)


func test_a_host_a_guest_and_a_save_have_the_same_level_ground() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var host: Node = _make()
	host.stone = 20
	for cell: Vector2i in pair:
		if host.place_stone(_at(cell), StonePieces.PAD) != "":
			problems.append("The host could not build a pad at %s." % cell)
	var want: Dictionary[Vector2i, float] = Terrain.pad_levels(StonePieces.pad_cells(host.stone_pieces), host.dug)
	if want.size() != 15:
		problems.append("Two pads must level 15 points: %d" % want.size())
	var data: Dictionary = host.farm_to_dict()
	var guest: Node = _make()
	if guest.farm_from_dict(data) != "":
		problems.append("The guest could not take the farm.")
	if guest.stone_pieces != host.stone_pieces or guest.stone_pieces.size() != 2:
		problems.append("A guest's pieces must be the host's.")
	var saved: Dictionary = SaveGame.from_bytes(SaveGame.to_bytes({ "clock": FarmSync.clock(), "farm": data }), "test")
	var loaded: Node = _make()
	if saved.has("problem") or loaded.farm_from_dict(saved["data"]["farm"]) != "":
		problems.append("A saved farm with pads must load: %s" % saved.get("problem", ""))
	elif loaded.stone_pieces != host.stone_pieces:
		problems.append("A loaded farm's pieces must be the saved ones.")
	# The game's own farm turns the pieces into ground on loading.
	var kept: Dictionary = _keep()
	var whole: Dictionary = GameState.farm_to_dict()
	_hold({})
	if GameState.farm_from_dict(data) != "" or Terrain.level_points != want:
		problems.append("Loading a farm must level the ground under its pads: %d points." % Terrain.level_points.size())
	var plain: Dictionary = host.farm_to_dict()
	plain["stone_pieces"] = {}
	if GameState.farm_from_dict(plain) != "" or not Terrain.level_points.is_empty():
		problems.append("Loading a farm with no pads must give the ground back.")
	GameState.farm_from_dict(whole)
	_restore(kept)
	host.free()
	guest.free()
	loaded.free()
	return "\n".join(problems)


func test_a_save_with_pads_that_cannot_be_levelled_loads_and_follows_the_ground() -> String:
	var strip: Array[Vector2i] = _strip(0)
	if strip.size() < 3:
		return "No strip of cells up a hill that goes over the limit."
	var problems: PackedStringArray = []
	var on_dug: Vector2i = _apart(strip)
	var wet: Vector2i = _wet()
	if on_dug == NOWHERE or wet == NOWHERE:
		return "No cell to put an old save's pad on."
	var old: Dictionary[Vector2i, int] = _pads(strip)
	old[on_dug] = StonePieces.PAD
	old[wet] = StonePieces.PAD
	var host: Node = _make()
	host.stone_pieces.assign(old)
	host.dug[on_dug] = 1
	var data: Dictionary = host.farm_to_dict()
	var loaded: Node = _make()
	if loaded.farm_from_dict(data) != "" or loaded.stone_pieces != host.stone_pieces:
		problems.append("A save with pads on dug ground, by the water and in a strip over the limit must load.")
	var saved: Dictionary = SaveGame.from_bytes(SaveGame.to_bytes({ "clock": FarmSync.clock(), "farm": data }), "test")
	if saved.has("problem") or loaded.farm_from_dict(saved["data"]["farm"]) != "":
		problems.append("The same farm, saved and read, must load: %s" % saved.get("problem", ""))
	var kept: Dictionary = _keep()
	var whole: Dictionary = GameState.farm_to_dict()
	_hold({})
	if GameState.farm_from_dict(data) != "":
		problems.append("The game's own farm must load it.")
	var dug: Dictionary[Vector2i, int] = GameState.dug
	if not Terrain.level_points.is_empty():
		problems.append("No group of this farm can be levelled, so none is: %d points." % Terrain.level_points.size())
	for point: Vector2i in Terrain.group_points(strip):
		if not is_equal_approx(Terrain.point_height(point, dug), Terrain.dug_height(point, dug)):
			problems.append("The strip must follow the natural ground at %s." % point)
			break
	# Another pad, a fair way off, is levelled as it always was.
	var used: Array[Vector2i] = strip.duplicate()
	used.append(on_dug)
	used.append(wet)
	var apart: Vector2i = _apart(used)
	if apart != NOWHERE:
		GameState.stone = 10
		var built: String = GameState.place_stone(_at(apart), StonePieces.PAD)
		if built != "" or Terrain.level_points.size() != 9:
			problems.append("A new pad away from them must be built and levelled: '%s', %d points." % [built, Terrain.level_points.size()])
	GameState.farm_from_dict(whole)
	_restore(kept)
	host.free()
	loaded.free()
	return "\n".join(problems)


func test_a_guest_is_told_when_a_pad_changes_the_ground() -> String:
	var pair: Array[Vector2i] = _pair()
	if pair.is_empty():
		return "No two cells side by side on a slope."
	var problems: PackedStringArray = []
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var host: Node = _make()
	var guest: Node = _make()
	var told: Array[int] = [0]
	var tell: Callable = func() -> void: told[0] += 1
	guest.terrain_changed.connect(tell)
	var before: PackedByteArray = FarmSync.capture(host)
	host.stone = 20
	host.place_stone(_at(pair[0]), StonePieces.WALL)
	var walled: PackedByteArray = FarmSync.capture(host)
	host.place_stone(_at(pair[1]), StonePieces.PAD)
	var padded: PackedByteArray = FarmSync.capture(host)
	host.place_stone(_at(pair[1]), StonePieces.TAKE_UP)
	var gone: PackedByteArray = FarmSync.capture(host)
	FarmCommands.guest = true
	var steps: Array = [["nothing built", before, 0], ["a wall", walled, 0], ["a pad", padded, 1], ["the same pad again", padded, 0], ["a pad taken up", gone, 1]]
	var seen: int = 0
	for step: Array in steps:
		var said: String = FarmSync.update(step[1], guest)
		seen += step[2]
		if said != "" or told[0] != seen:
			problems.append("A guest taking %s must be told %d times in all: %d (%s)" % [step[0], seen, told[0], said])
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	host.free()
	guest.free()
	return "\n".join(problems)


func test_a_pad_change_leaves_the_tunnels_alone() -> String:
	var strip: Array[Vector2i] = _strip(3)
	if strip.size() < 6:
		return "No strip of cells up a hill that goes well over the limit."
	var problems: PackedStringArray = []
	var kept: Dictionary = _keep()
	_hold(_pads(strip))
	var spot: Vector2 = _middle(strip[1])
	var low := Transform3D(Basis.IDENTITY, Vector3(spot.x, -50.0, spot.y))
	# On the farm: the rover that is in the tunnels keeps its tunnel pose.
	GameState.rover_in_tunnels = false
	GameState.rover_transforms[GameState.TUNNEL_ROVER] = low
	GameState.rover_transforms[GameState.ROVER] = low
	var i: int = strip.size() - 1
	while i > 1 and Terrain.level_points.is_empty():
		GameState.place_stone(_at(strip[i]), StonePieces.TAKE_UP)
		i -= 1
	if Terrain.level_points.is_empty():
		problems.append("Taking up the far pads must bring the group under the limit.")
	if GameState.rover_transforms[GameState.TUNNEL_ROVER] != low:
		problems.append("A pad change must not move a rover that is in the tunnels.")
	if GameState.rover_transforms[GameState.ROVER].origin.y < Terrain.height(spot, GameState.dug) - 0.0001:
		problems.append("The farm rover on the pads must still be lifted.")
	# In the tunnels: the players' poses are not the farm's either.
	_hold(_pads(strip))
	GameState.rover_in_tunnels = true
	GameState.rover_transforms[GameState.ROVER] = low
	CoopWalkers.out["test_walker"] = [spot.x, -50.0, spot.y, 0.0, 0.0]
	i = strip.size() - 1
	while i > 1 and Terrain.level_points.is_empty():
		GameState.place_stone(_at(strip[i]), StonePieces.TAKE_UP)
		i -= 1
	if GameState.rover_transforms[GameState.ROVER] != low:
		problems.append("A pad change must not move the farm rover left behind while in the tunnels.")
	if CoopWalkers.out["test_walker"][1] != -50.0:
		problems.append("A pad change must not move a player while the rover is in the tunnels.")
	CoopWalkers.out.erase("test_walker")
	_restore(kept)
	return "
".join(problems)


func test_a_pad_whose_edge_is_too_steep_is_refused_at_placement() -> String:
	var problems: PackedStringArray = []
	var found: bool = false
	var kept: Dictionary = _keep()
	for start: Vector2i in _sloped(60):
		for way: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var built: Dictionary[Vector2i, int] = {}
			var line: Array[Vector2i] = []
			for i: int in 10:
				var next: Vector2i = start + way * i
				if not Terrain.can_dig(next):
					break
				var why: String = StonePieces.problem(next, StonePieces.PAD, built, _none, _no_dug)
				if why == "Too steep at its edge to climb." and not found:
					found = true
					line.append(next)
					var levels: Dictionary[Vector2i, float] = Terrain.pad_levels(line, _no_dug)
					if Terrain.group_unlevelled(line, _no_dug) != "" 							or Terrain.max_step_m(Terrain.group_points(line), levels, _no_dug) <= Terrain.PAD_STEP_M:
						problems.append("The refusal needs a levelled group whose edge steps over the limit.")
					# The game refuses it too and changes nothing.
					_hold(built)
					var before: Dictionary[Vector2i, float] = Terrain.level_points.duplicate()
					GameState.stone = 20
					if GameState.place_stone(_at(next), StonePieces.PAD) != why or GameState.stone != 20 							or GameState.stone_pieces.has(next) or Terrain.level_points != before:
						problems.append("The game must refuse the pad at %s and change nothing." % next)
					_restore(kept)
				if why != "":
					break
				built[next] = StonePieces.PAD
				line.append(next)
	if not found:
		problems.append("No pad on this farm's hills has an edge too steep to climb.")
	return "
".join(problems)


func test_a_pad_change_settles_the_pit_water_again() -> String:
	var kept: Dictionary = _keep()
	var problems: PackedStringArray = []
	var pit: Vector2i = NOWHERE
	var pad: Vector2i = NOWHERE
	for cell: Vector2i in _sloped(60):
		if pit != NOWHERE or StonePieces.problem(cell, StonePieces.PAD, _no_pieces, _none, _no_dug) != "":
			continue
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step * 3
			if pit == NOWHERE and Terrain.can_dig(next) and not Terrain.is_near_water(next):
				pit = next
				pad = cell
	if pit == NOWHERE:
		return "No pit beside a pad to try."
	_hold({})
	GameState.dug.assign({pit: PitWater.SEEP_STEPS})
	# The pit stands a little off the pad (its side would be too steep to climb next
	# to it). Its water as it stood before: above what the ground now holds, as
	# it is when the ground round a pit moves down.
	var stale: Dictionary[Vector2i, float] = PitWater.seep({}, GameState.dug, 100.0)
	for cell: Vector2i in stale:
		stale[cell] += 5.0
	GameState.pit_seep.assign(stale)
	GameState.stone = 10
	if GameState.place_stone(_at(pad), StonePieces.PAD) != "":
		problems.append("The pad beside the pit was refused.")
	var want: Dictionary[Vector2i, float] = PitWater.seep(stale, GameState.dug, 0.0)
	if want == stale:
		problems.append("The test needs water that settles lower.")
	if GameState.pit_seep != want:
		problems.append("A pad change must settle the pit water again: %s, not %s" % [GameState.pit_seep, want])
	GameState.pit_seep.assign(stale)
	GameState.place_stone(_at(pad), StonePieces.TAKE_UP)
	if GameState.pit_seep != want:
		problems.append("Taking a pad up must settle the pit water again.")
	_restore(kept)
	return "
".join(problems)
