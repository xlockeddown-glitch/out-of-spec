extends RefCounted
## The hills' plants and rocks: where they may stand, and what digging does to them.

const ANTENNA_M: float = 2.0
const ROVER_M: float = 1.6
## Every plant's place in whole centimeters (moved when the arch grew and when the terrace rows came, so shrubs keep clear).
const HASH: int = 1516813843

var _none: Dictionary[Vector2i, int] = {}


func _footprint(middle: Vector2, half: Vector2) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			found.append(middle + Vector2(x, z) * half)
	return found


func test_plants_stand_on_the_hills_only() -> String:
	var count: Dictionary[HillDressing.Plant, int] = {HillDressing.Plant.SHRUB: 0, HillDressing.Plant.POPPY: 0}
	for placed: HillDressing.Placed in HillDressing.plants():
		count[placed.plant] += 1
		var at := Vector2(placed.at.x, placed.at.z)
		for corner: Vector2 in _footprint(at, Vector2.ONE * placed.half_m()):
			if absf(corner.x) > Terrain.HALF_M or absf(corner.y) > Terrain.HALF_M:
				return "The plant at %s is over the land's edge." % at
			if Terrain.height(corner, _none) < placed.at.y:
				return "The plant at %s floats." % at
			for rock: Vector2i in HillDressing.ROCKS:
				var gap: Vector2 = (corner - Vector2(rock)).abs() - HillDressing.rock_half_m(rock)
				if maxf(gap.x, gap.y) < 0.0:
					return "The plant at %s is in a rock." % at
		if placed.at.y < Terrain.height(at, _none) - 0.5:
			return "The plant at %s is buried." % at
		for side: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			if Terrain.is_level(at + side * 2.0):
				return "The plant at %s is on or beside level ground." % at
		if not placed.place().basis.y.normalized().is_equal_approx(Vector3.UP):
			return "The plant at %s leans." % at
	if count[HillDressing.Plant.SHRUB] < 100 or count[HillDressing.Plant.POPPY] < 100:
		return "There are too few plants: %s." % count
	return "" if count[HillDressing.Plant.SHRUB] + count[HillDressing.Plant.POPPY] < 1000 else "There are too many plants: %s." % count


func test_the_same_plants_on_every_pc() -> String:
	var hashed: int = 17
	for placed: HillDressing.Placed in HillDressing.plants():
		for part: float in [placed.at.x, placed.at.z, placed.size]:
			hashed = (hashed * 31 + roundi(part * 100.0)) & 0xffffffff
		hashed = (hashed * 31 + placed.plant * 4 + placed.quarter_turns) & 0xffffffff
	return "" if hashed == HASH else "The plants changed: their hash is %d." % hashed


func test_rocks_stand_clear_on_high_ground() -> String:
	for rock: Vector2i in HillDressing.ROCKS:
		var at := Vector2(rock)
		var half: Vector2 = HillDressing.rock_half_m(rock)
		if Terrain.height(at, _none) < HillDressing.ROCK_MIN_HEIGHT_M:
			return "The rock at %s is not on high ground." % rock
		# A rover passes between it and level ground or another rock.
		for corner: Vector2 in _footprint(at, half + Vector2.ONE * ROVER_M * 2.0):
			if Terrain.is_level(corner):
				return "The rock at %s is too near level ground." % rock
		var touches: bool = false
		for other: Vector2i in HillDressing.ROCKS:
			var gap: Vector2 = Vector2(rock - other).abs() - half - HillDressing.rock_half_m(other)
			if other != rock and maxf(gap.x, gap.y) < -0.001:
				return "The rocks at %s and %s overlap." % [rock, other]
			# The terrace pieces of a row touch (below), with no gap to be caught in.
			var in_row: bool = HillDressing.ROCK_TURNS.has(rock) and HillDressing.ROCK_TURNS.has(other) and Vector2(rock).distance_to(Vector2(other)) <= 4.0
			touches = touches or (other != rock and is_zero_approx(maxf(gap.x, gap.y)))
			if other != rock and not in_row and maxf(gap.x, gap.y) < ROVER_M * 2.0:
				return "A rover can't pass between the rocks at %s and %s." % [rock, other]
		if HillDressing.ROCK_TURNS.has(rock) and not touches:
			return "The terrace piece at %s stands apart from its row." % rock
		var buried_m: float = Terrain.height(at, _none) - HillDressing.lowest_under(at, half, _none)
		if buried_m > 0.6:
			return "The rock at %s is buried by %.2f m." % [rock, buried_m]
	return ""


## The 2 m rule is relaxed: a terrace row stands out at the plateau's edge.
func test_a_terrace_row_reaches_the_plateau_edge_and_every_rock_is_on_the_map() -> String:
	var at_edge: Array[Vector2i] = []
	for rock: Vector2i in HillDressing.ROCKS:
		var half: Vector2 = HillDressing.rock_half_m(rock)
		# The rocks stand on the old land, as the plateau edge is the old edge.
		var spare := Vector2(Terrain.OLD_HALF_M - absf(rock.x) - half.x, Terrain.OLD_HALF_M - absf(rock.y) - half.y)
		if minf(spare.x, spare.y) < 0.0:
			return "The rock at %s hangs off the map." % rock
		if HillDressing.ROCK_TURNS.has(rock) and minf(spare.x, spare.y) <= 2.5:
			at_edge.append(rock)
	# The whole new row (three pieces, touching) stands within 2.5 m of the edge.
	for rock: Vector2i in [Vector2i(77, 45), Vector2i(77, 47), Vector2i(77, 49)]:
		if not rock in at_edge:
			return "The piece at %s is not at the plateau edge." % rock
	return ""


## The steepest step between whole-meter neighbors before the 2 m rule was relaxed.
const STEEPEST_BEFORE_M: float = 0.7618
## The hills are no steeper (the steepest step between neighbors stays as it was).
func test_hills_are_no_steeper_than_before() -> String:
	var steepest: float = 0.0
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M):
			var here: float = Terrain.height(Vector2(x, z), _none)
			steepest = maxf(steepest, maxf(absf(Terrain.height(Vector2(x + 1, z), _none) - here), absf(Terrain.height(Vector2(x, z + 1), _none) - here)))
	return "" if steepest <= STEEPEST_BEFORE_M + 0.0001 else "The steepest step is %.4f m per meter." % steepest


## From level ground every line to the relay's dish misses every rock.
func test_rocks_hide_the_relay_from_no_level_ground() -> String:
	var scene: Node = (load("res://scenes/main_farm.tscn") as PackedScene).instantiate()
	var relay: SatelliteRelay = scene.find_child("SatelliteRelay")
	var dish: Vector3 = relay.position + relay.uplink_point.position
	scene.free()
	var boxes: Array[AABB] = []
	for rock: Vector2i in HillDressing.ROCKS:
		var size: Vector3 = HillDressing.ROCK_SIZE_M[HillDressing.ROCKS[rock]]
		var half: Vector2 = HillDressing.rock_half_m(rock)
		boxes.append(AABB(Vector3(rock.x - half.x, Terrain.height(Vector2(rock), _none) - 1.0, rock.y - half.y), Vector3(half.x * 2.0, size.y + 1.0, half.y * 2.0)))
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			if Terrain.is_level(Vector2(x, z)):
				for box: AABB in boxes:
					if box.intersects_segment(Vector3(x, ANTENNA_M, z), dish):
						return "A rock hides the relay from (%d, %d)." % [x, z]
	return ""


## The camera looks along (-1, -1, -1), so a rock hides what is behind it.
func test_rocks_hide_no_level_ground_from_the_camera() -> String:
	for rock: Vector2i in HillDressing.ROCKS:
		var half: Vector2 = HillDressing.rock_half_m(rock)
		var top_m: float = HillDressing.lowest_under(Vector2(rock), half, _none)
		top_m += HillDressing.ROCK_SIZE_M[HillDressing.ROCKS[rock]].y
		for corner: Vector2 in _footprint(Vector2(rock), half):
			if Terrain.is_level(corner - Vector2.ONE * top_m):
				return "The rock at %s hides level ground." % rock
	return ""


func test_nothing_under_or_beside_a_rock_is_dug() -> String:
	for rock: Vector2i in HillDressing.ROCKS:
		var half: Vector2 = HillDressing.rock_half_m(rock)
		var dug: Dictionary[Vector2i, int] = {}
		for corner: Vector2 in _footprint(Vector2(rock), half + Vector2.ONE * 0.4):
			if Terrain.dig_problem(Terrain.cell_at(corner), _none) == "":
				return "The ground at %s beside a rock can be dug." % corner
		# All around dug as it may be, it still stands on undug ground.
		for x: int in range(-4, 5):
			for z: int in range(-4, 5):
				var cell: Vector2i = Terrain.cell_at(Vector2(rock)) + Vector2i(x, z)
				if Terrain.dig_problem(cell, _none) == "":
					dug[cell] = 1
		if dug.is_empty():
			return "The ground around a rock can be dug."
		if HillDressing.lowest_under(Vector2(rock), half, dug) != HillDressing.lowest_under(Vector2(rock), half, _none):
			return "Digging moves the rock at %s." % rock
	# A save from before the rocks may have dug there.
	var under: Vector2i = Terrain.cell_at(Vector2(HillDressing.ROCKS.keys()[0] as Vector2i))
	var older: Dictionary[Vector2i, int] = {under: 1}
	return Terrain.dug_problem(older)


func test_a_plant_is_gone_while_the_ground_under_it_is_dug() -> String:
	var dug: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	GameState.dug.clear()
	var tree: SceneTree = Engine.get_main_loop()
	var dressing := HillDressing.new()
	tree.root.add_child(dressing)
	var all: int = _shown(dressing)
	var problem: String = ""
	if all != HillDressing.plants().size():
		problem = "With nothing dug every plant must show."
	for placed: HillDressing.Placed in HillDressing.plants():
		var at := Vector2(placed.at.x, placed.at.z)
		for corner: Vector2 in _footprint(at, Vector2.ONE * placed.half_m()):
			var pit: Dictionary[Vector2i, int] = {Terrain.cell_at(corner): 1}
			if problem == "" and HillDressing.stands(placed, pit):
				problem = "A plant must not stand on dug ground."
		var apart: Dictionary[Vector2i, int] = {Terrain.cell_at(at) + Vector2i(2, 0): 1}
		if problem == "" and not HillDressing.stands(placed, apart):
			problem = "Digging elsewhere must leave a plant be."
	var first: HillDressing.Placed = HillDressing.plants()[0]
	GameState.dug[Terrain.cell_at(Vector2(first.at.x, first.at.z))] = 1
	GameState.terrain_changed.emit()
	if problem == "" and _shown(dressing) >= all:
		problem = "Dug ground must hide its plants."
	# As on load, or when a guest joins.
	var later := HillDressing.new()
	tree.root.add_child(later)
	if problem == "" and _shown(later) != _shown(dressing):
		problem = "A new scene must hide the same plants."
	GameState.dug.clear()
	GameState.terrain_changed.emit()
	if problem == "" and _shown(dressing) != all:
		problem = "Filled ground must have its plants back."
	dressing.free()
	later.free()
	GameState.dug.assign(dug)
	GameState.terrain_changed.emit()
	return problem


func _shown(dressing: HillDressing) -> int:
	var count: int = 0
	for drawing: Node in dressing.find_children("*", "MultiMeshInstance3D", true, false):
		count += (drawing as MultiMeshInstance3D).multimesh.visible_instance_count
	return count


func test_rocks_block_rovers_and_the_uplink_as_boulders_do() -> String:
	var dressing := HillDressing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(dressing)
	var problem: String = ""
	var bodies: Array[Node] = dressing.find_children("*", "CollisionObject3D", true, false)
	if bodies.size() != HillDressing.ROCKS.size():
		problem = "Each rock, and no plant, must have collision."
	for body: StaticBody3D in bodies:
		# The world's and the uplink's.
		if body.collision_layer != 5:
			problem = "Rocks must block rovers and the uplink."
		# What is seen and what is hit must agree.
		var shape: CollisionShape3D = body.find_children("*", "CollisionShape3D", true, false)[0]
		var seen := AABB()
		for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			var part: AABB = mesh.global_transform * mesh.get_aabb()
			seen = part if seen.size == Vector3.ZERO else seen.merge(part)
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var hit := AABB(shape.global_position - size / 2.0, size)
		if not seen.position.is_equal_approx(hit.position) or not seen.size.is_equal_approx(hit.size):
			problem = "A rock is seen at %s but hit at %s." % [seen, hit]
	dressing.free()
	return problem


func test_a_rover_saved_where_a_rock_stands_comes_back_beside_it() -> String:
	for rock: Vector2i in HillDressing.ROCKS:
		var half: Vector2 = HillDressing.rock_half_m(rock)
		var starts: Array[Vector2] = []
		starts.assign(_footprint(Vector2(rock), half))
		for x: int in range(-9, 10):
			for z: int in range(-9, 10):
				starts.append(Vector2(rock) + Vector2(x, z) / 9.0 * half)
		for at: Vector2 in starts:
			var away: Vector2 = HillDressing.clear_of_rocks(at)
			var gap: Vector2 = (away - Vector2(rock)).abs() - half
			if maxf(gap.x, gap.y) < ROVER_M / 2.0:
				return "At %s a rover comes back inside the rock at %s." % [at, rock]
			for other: Vector2i in HillDressing.ROCKS:
				gap = (away - Vector2(other)).abs() - HillDressing.rock_half_m(other)
				if away != at and gap.max(Vector2.ZERO).length() < HillDressing.ROVER_CLEAR_M - 0.02:
					return "At %s a rover comes back against the rock at %s." % [at, other]
			if HillDressing.clear_of_rocks(away) != away:
				return "Beside a rock a rover must stay where it was."
		# Its long side against a corner.
		var corner: Vector2 = Vector2(rock) + half + Vector2.ONE.normalized() * ROVER_M / 2.0
		if not HillDressing.ROCK_TURNS.has(rock) and HillDressing.clear_of_rocks(corner) != corner:
			return "A rover resting diagonally at a corner must stay where it was."
	var parked: Dictionary = GameState.rover_transforms.duplicate()
	var tree: SceneTree = Engine.get_main_loop()
	var ground := TerrainGround.new()
	tree.root.add_child(ground)
	var rover := RoverController.new()
	rover.ground = ground
	tree.root.add_child(rover)
	var first: Vector2i = HillDressing.ROCKS.keys()[0]
	rover.global_position = Vector3(first.x, Terrain.height(Vector2(first), _none), first.y)
	rover._put_back_on_land()
	var landed := Vector2(rover.global_position.x, rover.global_position.z)
	var problem: String = ""
	if landed.distance_to(Vector2(first)) < ROVER_M:
		problem = "It is still in the rock."
	elif rover.global_position.y < Terrain.height(landed, _none) - 0.1:
		problem = "It is under the ground beside the rock."
	rover.free()
	ground.free()
	GameState.rover_transforms.assign(parked)
	return problem


func test_shrubs_differ_in_shape_tint_and_size_and_repeat_exactly() -> String:
	var first: Array[HillDressing.Placed] = HillDressing.plants()
	var again: Array[HillDressing.Placed] = HillDressing.plants()
	var loose: int = 0
	var shrubs: int = 0
	var tints: Dictionary[Color, bool] = {}
	var heights: Dictionary[int, bool] = {}
	for i: int in first.size():
		if first[i].tint() != again[i].tint() or first[i].stretch() != again[i].stretch() or first[i].is_loose() != again[i].is_loose():
			return "Shrub %d looks different on a second run." % i
		if first[i].plant != HillDressing.Plant.SHRUB:
			if first[i].tint() != Color.WHITE or first[i].stretch() != Vector3.ONE or first[i].is_loose():
				return "Only shrubs may vary."
			continue
		shrubs += 1
		loose += 1 if first[i].is_loose() else 0
		tints[first[i].tint()] = true
		heights[int(first[i].stretch().y * 100.0)] = true
		if first[i].stretch().x > 1.0:
			return "A shrub is wider than the room the hills gave it."
	if loose * 5 < shrubs or loose * 5 > shrubs * 3:
		return "%d of %d shrubs are loose; the mix is off." % [loose, shrubs]
	if tints.size() < 4 or heights.size() < 8:
		return "Shrubs barely vary: %d tints, %d heights." % [tints.size(), heights.size()]
	return ""


func test_the_arch_is_drawn_larger_and_its_box_matches() -> String:
	var kind: HillDressing.Rock = HillDressing.Rock.ARCH
	var pack := Vector3(2.8, 2.4, 2.0)
	var want: Vector3 = pack * HillDressing.ROCK_SCALE[kind]
	if not HillDressing.ROCK_SIZE_M[kind].is_equal_approx(want):
		return "The arch's box %s does not match its drawn size %s." % [HillDressing.ROCK_SIZE_M[kind], want]
	return ""
