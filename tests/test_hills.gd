extends RefCounted
## The natural land: hills a rover can climb, that leave the farm and its uplink be.

const STEEPEST_DEG: float = 15.0
const ANTENNA_M: float = 2.0
const HASH: int = 1162163701

var _none: Dictionary[Vector2i, int] = {}


func _at(x: int, z: int) -> float:
	return Terrain.natural(Vector2i(x, z))


func test_every_triangle_of_the_land_is_gentle() -> String:
	var steepest: float = tan(deg_to_rad(STEEPEST_DEG))
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M):
			# The wash's banks are steeper; test_ford keeps them drivable.
			if Terrain.wash_out(Vector2(x + 0.5, z + 0.5)) < Terrain.WASH_REACH + 0.3:
				continue
			# Either way a square is cut in two, a triangle has one side along x and one along z.
			for x_side: float in [_at(x + 1, z) - _at(x, z), _at(x + 1, z + 1) - _at(x, z + 1)]:
				for z_side: float in [_at(x, z + 1) - _at(x, z), _at(x + 1, z + 1) - _at(x + 1, z)]:
					if Vector2(x_side, z_side).length() > steepest:
						return "The land at (%d, %d) is too steep." % [x, z]
	return ""


func test_there_are_hills_and_valleys_within_bounds() -> String:
	var highest: float = 0.0
	var lowest: float = 0.0
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			highest = maxf(highest, _at(x, z))
			lowest = minf(lowest, _at(x, z))
	if highest < 5.0 or highest > 6.0:
		return "The highest hill is %.2f m, not about 6 m." % highest
	if lowest > -0.5 or lowest < -1.5:
		return "The lowest valley is %.2f m, not a shallow one." % lowest
	return ""


func test_the_same_land_on_every_pc() -> String:
	# Hashing every height catches any change; saves and co-op count on none.
	var hashed: int = 17
	for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			var parts: float = _at(x, z) * Terrain.HEIGHT_PARTS
			if parts != roundf(parts):
				return "The height at (%d, %d) is not a whole number of parts." % [x, z]
			if absf(Terrain._work_out(x, z) - _at(x, z)) > 0.0:
				return "What was kept for (%d, %d) is not what it works out to." % [x, z]
			hashed = (hashed * 31 + int(parts)) & 0xffffffff
	return "" if hashed == HASH else "The land changed: its hash is %d." % hashed


func test_the_road_to_the_relay_is_level() -> String:
	var dish: Vector3 = _dish()
	for i: int in 71:
		for aside: int in range(-3, 4):
			var at := Vector2i(-i + aside, -i - aside)
			if not Terrain.is_level(Vector2(at)) or Terrain.natural(at) != 0.0:
				return "The road is not level at %s." % at
			if _hidden(Vector3(at.x, ANTENNA_M, at.y), dish):
				return "The land hides the relay from the road at %s." % at
	return "" if not Terrain.is_level(Vector2(-60, -40)) else "The road must not be all the land."


func test_the_farm_sees_the_relay() -> String:
	var dish: Vector3 = _dish()
	for x: int in range(-33, 34):
		for z: int in range(-33, 34):
			if Vector2(x, z).length() <= Terrain.FARM_LEVEL_M and _hidden(Vector3(x, ANTENNA_M, z), dish):
				return "The land hides the relay from (%d, %d)." % [x, z]
	# Behind the far hill it must not be seen.
	for x: int in range(34, 80):
		var ground_m: float = Terrain.height(Vector2(x, x), _none)
		if _hidden(Vector3(x, ground_m + ANTENNA_M, x), dish):
			return ""
	return "No hill hides the relay."


func _dish() -> Vector3:
	var scene: Node = (load("res://scenes/main_farm.tscn") as PackedScene).instantiate()
	var relay: SatelliteRelay = scene.find_child("SatelliteRelay")
	var dish: Vector3 = relay.position + relay.uplink_point.position
	scene.free()
	return dish


func _hidden(from: Vector3, to: Vector3) -> bool:
	var step: Vector3 = (to - from) / ceilf(from.distance_to(to))
	for i: int in int(ceilf(from.distance_to(to))):
		var at: Vector3 = from + step * i
		if Terrain.height(Vector2(at.x, at.z), _none) > at.y:
			return true
	return false


func test_nothing_in_the_scene_floats_or_is_buried() -> String:
	var scene: Node = (load("res://scenes/main_farm.tscn") as PackedScene).instantiate()
	var problem: String = _not_on_level(scene.find_child("World"), Transform3D.IDENTITY)
	scene.free()
	return problem


func _not_on_level(of: Node, under: Transform3D) -> String:
	var here: Transform3D = under * (of as Node3D).transform if of is Node3D else under
	# The plateau rim's rocks are the widest near the edge, 1 m each way.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if not Terrain.is_level(Vector2(here.origin.x, here.origin.z) + corner):
			return "%s stands on a hill." % of.name
	for child: Node in of.get_children():
		var problem: String = _not_on_level(child, here)
		if problem != "":
			return problem
	return ""


func test_level_ground_keeps_its_color() -> String:
	var ground := TerrainGround.new()
	ground._ready()
	var problem: String = ""
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			if Terrain.is_level(Vector2(x, z)) and ground._tints[ground._index(x, z)] != Color.WHITE:
				problem = "Level ground is tinted at (%d, %d)." % [x, z]
	if ground._tints[ground._index(48, 47)].is_equal_approx(Color.WHITE):
		problem = "A hill must not look like level ground."
	ground.free()
	return problem


func test_a_rover_saved_inside_a_hill_comes_back_on_it() -> String:
	var tree: SceneTree = Engine.get_main_loop()
	# Leaving the tree parks it.
	var parked: Dictionary = GameState.rover_transforms.duplicate()
	var ground := TerrainGround.new()
	tree.root.add_child(ground)
	var rover := RoverController.new()
	rover.ground = ground
	tree.root.add_child(rover)
	var problem: String = ""
	rover.global_position = Vector3(48, 0.05, 47)
	rover._put_back_on_land()
	if rover.global_position.y < 6.0:
		problem = "It must come back on top of the hill."
	rover.global_position = Vector3(300, -900, 0)
	rover._put_back_on_land()
	if rover.global_position.x > Terrain.HALF_M or rover.global_position.y < Terrain.height(Vector2(79, 0), _none):
		problem = "It must come back onto the land."
	rover.global_position = Vector3(3, 0.0, 2)
	rover._put_back_on_land()
	if rover.global_position != Vector3(3, 0, 2):
		problem = "On the farm it must stay where it was."
	rover.global_position = Vector3(48, 6.3, 47)
	rover._put_back_on_land()
	if not is_equal_approx(rover.global_position.y, 6.3):
		problem = "On the hill it must stay where it was."
	rover.free()
	ground.free()
	GameState.rover_transforms.assign(parked)
	return problem


func test_a_rover_parked_in_a_pit_stays_there_on_load() -> String:
	var tree: SceneTree = Engine.get_main_loop()
	var parked: Dictionary = GameState.rover_transforms.duplicate()
	var dug: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	for x: int in range(23, 26):
		for z: int in range(22, 25):
			GameState.dug[Vector2i(x, z)] = 2
	var at := Vector3(49, Terrain.height(Vector2(49, 47), GameState.dug), 47)
	var ground := TerrainGround.new()
	tree.root.add_child(ground)
	var rover := RoverController.new()
	rover.ground = ground
	tree.root.add_child(rover)
	rover.global_position = at
	rover._put_back_on_land()
	var problem: String = "" if is_equal_approx(rover.global_position.y, at.y) else "It was put on top of the pit."
	GameState.rover_transforms[rover.rover_id] = Transform3D(Basis.IDENTITY, at + Vector3.DOWN * 0.05)
	rover._set_following(false)
	if problem == "" and (rover.global_position.x != at.x or rover.global_position.y < at.y):
		problem = "Taken over, it must be above the ground."
	rover.free()
	ground.free()
	GameState.dug.assign(dug)
	GameState.rover_transforms.assign(parked)
	return problem
