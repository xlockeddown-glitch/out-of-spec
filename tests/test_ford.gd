extends RefCounted
## The wash under the arch: where it is, what it changes, and what it stops.

const FarmScene: PackedScene = preload("res://scenes/main_farm.tscn")
## The ground outside the wash as it was before the wash was cut: every whole meter's
## height in 1/256 m, hashed as 17 * 31 + height each, in order, over the old 160 m
## land (the ring added later has no wash).
const LAND_HASH: int = 93351249

var _none: Dictionary[Vector2i, int] = {}


func _ford() -> Ford:
	var ford := Ford.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(ford)
	return ford


## How many of the ford's blocks on `layers` a segment meets.
func _stops(ford: Ford, from: Vector3, to: Vector3, layers: int) -> int:
	var found: int = 0
	for body: Node in ford.get_children():
		if not body is StaticBody3D or (body as StaticBody3D).collision_layer & layers == 0:
			continue
		var box := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
		var middle: Vector3 = (body as StaticBody3D).position
		if AABB(middle - box.size * 0.5, box.size).intersects_segment(from, to) != null:
			found += 1
	return found


func _ellipse_points() -> Array[Vector2]:
	var found: Array[Vector2] = []
	for i: int in 48:
		var turn: float = i * TAU / 48.0
		for out: float in [Terrain.WASH_REACH, 1.0, 0.5]:
			found.append(Terrain.WASH_AT + Vector2(cos(turn), sin(turn)) * Terrain.WASH_RADII * out)
	return found


func test_the_land_is_the_same_outside_the_wash() -> String:
	var hashed: int = 17
	var changed: int = 0
	for z: int in range(-Terrain.OLD_HALF_M, Terrain.OLD_HALF_M + 1):
		for x: int in range(-Terrain.OLD_HALF_M, Terrain.OLD_HALF_M + 1):
			if Terrain.wash_out(Vector2(x, z)) >= Terrain.WASH_REACH:
				hashed = (hashed * 31 + roundi(Terrain.natural(Vector2i(x, z)) * 256.0)) & 0xffffffff
			elif absf(Terrain.natural(Vector2i(x, z)) - Terrain._land(x, z)) > 1.0 / Terrain.HEIGHT_PARTS:
				changed += 1
	if hashed != LAND_HASH:
		return "The ground outside the wash changed: its hash is %d." % hashed
	return "" if changed > 20 else "The wash must cut the ground, not %d points." % changed


func test_the_wash_is_away_from_everything_in_use() -> String:
	var tunnel := Vector2(GameState.TUNNEL_PAD.x, GameState.TUNNEL_PAD.z)
	for at: Vector2 in _ellipse_points():
		if Terrain.is_level(at) or Terrain.is_level(at + Vector2(3.0, 3.0)) or Terrain.is_level(at - Vector2(3.0, 3.0)):
			return "The wash at %s is on or by level ground." % at
		if at.length() < Terrain.FARM_LEVEL_M + 20.0 or at.distance_to(tunnel) < 30.0 or at.distance_to(Terrain.RELAY) < 100.0:
			return "The wash at %s is too near the farm, the tunnels or the relay." % at
	# Nothing of the scene, the spawn and the pads included, stands in or by it.
	var farm: Node = FarmScene.instantiate()
	var world: Node = farm.get_node("WorldView/WorldViewport/World")
	var problem: String = ""
	for node: Node in world.find_children("*", "Node3D", true, false):
		if node is Camera3D or node is Light3D or node.name in ["Ford", "HillDressing", "Ground", "Rocks"]:
			continue
		var at := Vector2((node as Node3D).position.x, (node as Node3D).position.z)
		if Terrain.wash_out(at) < Terrain.WASH_REACH + 0.5:
			problem = "%s stands at %s, in or by the wash." % [node.name, at]
	farm.free()
	return problem


func test_the_arch_stands_dry_and_the_wash_is_beside_it() -> String:
	var arch := Vector2i(63, 3)
	var half: Vector2 = HillDressing.rock_half_m(arch)
	for x: int in range(-4, 5):
		for z: int in range(-4, 5):
			var at: Vector2 = Vector2(arch) + half * Vector2(x, z) / 4.0
			if Terrain.water_depth_m(at) > 0.0:
				return "The arch's foot at %s is wet." % at
			if absf(Terrain.natural(Vector2i(at.round())) - Terrain._land(roundi(at.x), roundi(at.y))) > 1.0 / Terrain.HEIGHT_PARTS:
				return "The ground under the arch at %s moved." % at
	for rock: Vector2i in HillDressing.ROCKS:
		var rock_half: Vector2 = HillDressing.rock_half_m(rock)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			if Terrain.water_depth_m(Vector2(rock) + corner * rock_half) > 0.0:
				return "The rock at %s stands in water." % rock
	var water_z: float = Terrain.WASH_AT.y - Terrain.WASH_RADII.y
	return "" if water_z - (arch.y + half.y) < 2.5 else "The wash is not by the arch."


func test_the_water_is_deep_in_the_middle_and_held_by_the_ground() -> String:
	var middle: float = Terrain.water_depth_m(Terrain.WASH_DEEP_AT)
	if not Terrain.is_deep(Terrain.WASH_DEEP_AT) or middle < 0.8 or middle > 1.2:
		return "The middle must be deep, not %s m." % middle
	var shallow: int = 0
	var deep: int = 0
	for x: int in range(-14, 15):
		for z: int in range(-10, 11):
			var at: Vector2 = Terrain.WASH_AT + Vector2(x, z) * 0.5
			var depth: float = Terrain.water_depth_m(at)
			if depth > 0.0 and Terrain.wash_out(at) >= 1.0:
				return "Water at %s is outside its ellipse." % at
			if depth > 0.0 and Terrain.height(at, _none) >= Terrain.WASH_LEVEL_M:
				return "Water is above the ground at %s." % at
			if Terrain.is_deep(at):
				deep += 1
			elif depth > 0.0:
				shallow += 1
	# No spill: the ground just outside the ellipse is above the water, but for the
	# north side, where the arch's hill stands.
	for at: Vector2 in _ellipse_points():
		var out: float = Terrain.wash_out(at)
		if out >= 1.0 and out < 1.1 and at.y > Terrain.WASH_AT.y - 1.0 and Terrain.height(at, _none) < Terrain.WASH_LEVEL_M:
			return "The rim at %s is under the water's level." % at
	return "" if shallow > 60 and deep > 15 else "There is %d shallow and %d deep." % [shallow, deep]


func test_water_is_drawn_where_the_ground_is_wet() -> String:
	var ford: Ford = _ford()
	var water: VoxelWater = ford.get_node("Water")
	var problem: String = ""
	if water.places.size() < 100:
		problem = "Only %d water columns." % water.places.size()
	for place: Transform3D in water.places:
		var at := Vector2(place.origin.x, place.origin.z)
		if Terrain.wash_out(at) > 1.0:
			problem = "A column at %s is outside the wash." % at
		if place.origin.y + place.basis.y.length() * 0.5 > Terrain.WASH_LEVEL_M + 0.01:
			problem = "A column at %s is over the water's level." % at
	ford.free()
	return problem


func test_deep_water_stops_a_rover_and_shallow_water_does_not() -> String:
	var ford: Ford = _ford()
	var problem: String = ""
	var wheel_m: float = 0.3
	# Straight across the deep middle, and at the height of a wheel.
	var from := Vector3(Terrain.WASH_DEEP_AT.x - 6.0, Terrain.WASH_LEVEL_M - 0.5, Terrain.WASH_DEEP_AT.y)
	if _stops(ford, from, from + Vector3(12.0, 0.0, 0.0), Ford.LAYER_WORLD) == 0:
		problem = "Deep water must stop the rover"
	# The signal's line is not stopped: the blocks are only on the world's layer.
	for body: Node in ford.get_children():
		if body is StaticBody3D and (body as StaticBody3D).collision_layer != Ford.LAYER_WORLD:
			problem = "A block is on layer %d" % (body as StaticBody3D).collision_layer
	# Every place of the deep is blocked at a wheel's height; no place of the shallows is.
	for x: int in range(-16, 17):
		for z: int in range(-12, 13):
			var at: Vector2 = Terrain.WASH_AT + Vector2(x, z) * 0.25
			var ground_m: float = Terrain.height(at, _none)
			var top := Vector3(at.x, ground_m + wheel_m + 0.01, at.y)
			var blocked: int = _stops(ford, top - Vector3.UP * 0.01, top, Ford.LAYER_WORLD)
			if Terrain.is_deep(at) and blocked == 0:
				problem = "Deep water at %s doesn't stop the rover." % at
			elif Terrain.water_depth_m(at) < Terrain.WASH_BLOCK_M - 0.35 and blocked > 0:
				problem = "Shallow water at %s stops the rover." % at
	ford.free()
	return problem


func test_no_rover_can_drive_onto_the_blocks() -> String:
	# A rover rests on the highest ground under its box, and its box reaches 1.45 m.
	var top_m: float = Terrain.WASH_LEVEL_M + Ford.BLOCK_ABOVE_M
	for x: int in range(54 * 4, 72 * 4):
		for z: int in range(2 * 4, 16 * 4):
			var at: Vector2 = Vector2(x, z) * 0.25
			if Ford.gap_m(at) < Terrain.ROVER_REACH_M * 2.0 and Terrain.height(at, _none) > top_m - 1.0:
				return "The ground at %s is over the blocks." % at
	return ""


func test_the_ford_and_the_drawn_blocks_agree() -> String:
	var ford: Ford = _ford()
	var area_m2: float = 0.0
	for body: Node in ford.get_children():
		if body is StaticBody3D:
			var box := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
			area_m2 += box.size.x * box.size.z
	ford.free()
	var listed: float = Ford.blocks().size() * Ford.BLOCK_M * Ford.BLOCK_M
	return "" if absf(area_m2 - listed) < 0.01 else "%s m2 of blocks, %s listed." % [area_m2, listed]


func test_a_line_across_the_ford_is_all_shallow_and_gentle() -> String:
	# From dry ground on the west to dry ground on the east, by the shallows, with
	# room for the rover's width all the way.
	var z: float = 9.8
	var last: float = Terrain.height(Vector2(54.0, z), _none)
	var wet: int = 0
	var x: float = 54.0
	while x <= 72.0:
		var at := Vector2(x, z)
		var ground_m: float = Terrain.height(at, _none)
		if Terrain.is_deep(at):
			return "Deep water on the ford at %s." % at
		if Ford.gap_m(at) < Terrain.ROVER_HALF_WIDTH_M + 0.1:
			return "The deep stops a rover at %s." % at
		if absf(ground_m - last) > 0.25 * tan(deg_to_rad(30.0)):
			return "The ford is too steep at %s." % at
		if Terrain.water_depth_m(at) > 0.0:
			wet += 1
		last = ground_m
		x += 0.25
	return "" if wet > 20 else "The ford has water for only %d steps." % wet


func test_the_wash_banks_are_climbable() -> String:
	var steepest: float = tan(deg_to_rad(40.0))
	for x: int in range(48, 80):
		for z: int in range(0, 20):
			var a: float = Terrain.natural(Vector2i(x, z))
			var rise := Vector2(Terrain.natural(Vector2i(x + 1, z)) - a, Terrain.natural(Vector2i(x, z + 1)) - a)
			var back := Vector2(Terrain.natural(Vector2i(x + 1, z + 1)) - Terrain.natural(Vector2i(x, z + 1)), Terrain.natural(Vector2i(x + 1, z + 1)) - Terrain.natural(Vector2i(x + 1, z)))
			if maxf(rise.length(), back.length()) > steepest:
				return "The ground at (%d, %d) is steeper than 40 degrees." % [x, z]
	return ""


func test_a_rover_in_deep_water_is_put_out_of_it() -> String:
	for x: int in range(-24, 25):
		for z: int in range(-16, 17):
			var at: Vector2 = Terrain.WASH_AT + Vector2(x, z) * 0.25
			var out: Vector2 = Terrain.clear_of_deep(at)
			if out == at:
				if Terrain.is_deep(at):
					return "A rover at %s stays in the deep." % at
				continue
			if out.distance_to(at) > 6.0:
				return "A rover at %s goes to %s." % [at, out]
			# Its whole box is clear, whichever way it is turned.
			for turn: int in 12:
				for corner: Vector2 in [Vector2(0.8, 1.2), Vector2(-0.8, 1.2), Vector2(0.8, 0.0), Vector2(0.0, 1.2)]:
					if Ford.gap_m(out + corner.rotated(turn * TAU / 12.0)) <= 0.0:
						return "A rover at %s is put in the deep at %s." % [at, out]
	var dry := Vector2(40.0, 40.0)
	return "" if Terrain.clear_of_deep(dry) == dry else "A rover on dry ground must stay."


func test_the_water_can_not_be_dug_in_or_beside() -> String:
	var why: String = Terrain.dig_problem(Terrain.cell_at(Terrain.WASH_AT), _none)
	if why != "Too near the water to dig." or Terrain.dig_problem(Terrain.cell_at(Terrain.WASH_DEEP_AT), _none) != why:
		return "Digging the water says \"%s\"." % why
	for at: Vector2 in _ellipse_points():
		if Terrain.wash_out(at) < 1.0 and Terrain.dig_problem(Terrain.cell_at(at), _none) == "":
			return "Digging at %s must be refused." % at
		if Terrain.wash_out(at) < 0.9 and Terrain.dig_problem(Terrain.cell_at(at), _none) != why:
			return "Digging the water at %s must say why." % at
	var beside: Vector2i = Terrain.cell_at(Terrain.WASH_AT + Vector2(Terrain.WASH_RADII.x + 0.5, 0.0))
	if Terrain.dig_problem(beside, _none) != why:
		return "The cell beside the water must be refused."
	var far: Vector2i = Terrain.cell_at(Terrain.WASH_AT - Vector2(0.0, Terrain.WASH_RADII.y + 5.0))
	if Terrain.dig_problem(far, _none) != "":
		return "Digging far from the water says \"%s\"." % Terrain.dig_problem(far, _none)
	return ""


func test_an_older_save_with_digging_in_the_wash_loads_and_leaves_the_bed() -> String:
	var dug: Dictionary[Vector2i, int] = {}
	for x: int in range(52, 76, 2):
		for z: int in range(0, 20, 2):
			var cell: Vector2i = Terrain.cell_at(Vector2(x, z))
			if Terrain.is_near_water(cell):
				dug[cell] = 1
	if dug.size() < 8:
		return "The save must have digging by the water, not %d cells." % dug.size()
	if Terrain.dug_problem(dug) != "":
		return "The save must still load: %s" % Terrain.dug_problem(dug)
	for x: int in range(48, 80):
		for z: int in range(0, 24):
			if Terrain.point_height(Vector2i(x, z), dug) != Terrain.natural(Vector2i(x, z)):
				return "The bed at (%d, %d) changed with the digging." % [x, z]
	# And it is driven: nowhere steeper than a rover climbs.
	for x: int in range(48, 80):
		for z: int in range(0, 24):
			var a: float = Terrain.point_height(Vector2i(x, z), dug)
			var rise := Vector2(Terrain.point_height(Vector2i(x + 1, z), dug) - a, Terrain.point_height(Vector2i(x, z + 1), dug) - a)
			if rise.length() >= 1.0:
				return "(%d, %d) rises %s." % [x, z, rise.length()]
	return ""


func test_nothing_grows_in_or_by_the_water() -> String:
	for placed: HillDressing.Placed in HillDressing.plants():
		if Terrain.wash_out(Vector2(placed.at.x, placed.at.z)) < Terrain.WASH_REACH:
			return "The plant at %s is by the water." % placed.at
	return ""


func test_a_rover_wades_modestly_slower() -> String:
	if Terrain.WATER_SPEED >= 1.0 or Terrain.WATER_SPEED < 0.3:
		return "Wading must be modestly slower, not %s." % Terrain.WATER_SPEED
	var shallow := Vector2(60.0, 9.0)
	if Terrain.water_depth_m(shallow) <= 0.0 or Terrain.is_deep(shallow):
		return "The place to wade is not shallow water."
	return ""
