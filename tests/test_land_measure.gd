extends RefCounted
## The land measuring (LandMeasure) runs and gives sane numbers, on a small land so
## it is fast. The full 160 m and 240 m run is tools/measure_land.gd.

const SMALL_HALF_M: int = 32


func test_rover_speed_is_read() -> String:
	var speed: Dictionary = LandMeasure.rover_speed()
	if float(speed["top_mps"]) <= 0.0 or float(speed["to_top_s"]) <= 0.0:
		return "no speed was measured: %s" % str(speed)
	if LandMeasure.rover_time_s(60.0, speed) <= LandMeasure.rover_time_s(30.0, speed):
		return "a longer drive took no longer"
	# Short of the top speed it is still speeding up, so a short trip is slower than top speed.
	if LandMeasure.rover_time_s(1.0, speed) <= 1.0 / float(speed["top_mps"]):
		return "a 1 m start took no longer than it would at top speed"
	return ""


func test_walking_is_slower_than_the_rover() -> String:
	var speed: Dictionary = LandMeasure.rover_speed()
	if LandMeasure.walk_time_s(100.0) <= LandMeasure.rover_time_s(100.0, speed):
		return "walking 100 m was not slower than driving it"
	return ""


func test_trips_reach_the_places() -> String:
	var trips: Array[Dictionary] = LandMeasure.trips()
	if trips.size() != 6:
		return "expected 6 trips, got %d" % trips.size()
	for trip: Dictionary in trips:
		if float(trip["m"]) <= 0.0:
			return "%s is no distance away" % trip["name"]
	return ""


func test_small_ground_builds() -> String:
	var holder := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(holder)
	var built: Dictionary = LandMeasure.build(holder, SMALL_HALF_M)
	(built["ground"] as Node).free()
	holder.free()
	if float(built["ms"]) <= 0.0:
		return "no build time was measured"
	# 64 m is 4 by 4 chunks of 16 by 16 squares, 6 corners each.
	if built["chunks"] != 16 or built["vertices"] != 16 * 16 * 16 * 6:
		return "wrong mesh count: %s" % str(built)
	if built["points"] != 65 * 65:
		return "wrong point count: %d" % built["points"]
	return ""


func test_bigger_land_keeps_todays_land_exactly() -> String:
	# The 240 m land is today's ground on every point of today's 160 m, rim band included.
	var wrong: int = 0
	var first := Vector2i.ZERO
	for z: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
		for x: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1):
			var at := Vector2i(x, z)
			if Terrain.natural_on(at, 120) != Terrain.natural(at):
				wrong += 1
				first = at
	if wrong > 0:
		return "%d points of today's land differ on a bigger land, e.g. %s" % [wrong, str(first)]
	return ""


func test_bigger_land_joins_the_edge_smoothly() -> String:
	# Past the old edge the ground eases from the edge's height, with no step.
	for at: Vector2i in [Vector2i(81, 0), Vector2i(0, -81), Vector2i(81, 81), Vector2i(-81, 40)]:
		var edge := Vector2i(clampi(at.x, -80, 80), clampi(at.y, -80, 80))
		if absf(Terrain.natural_on(at, 120) - Terrain.natural(edge)) > 0.3:
			return "a step at the old edge, at %s" % str(at)
	return ""


func test_measured_ground_is_on_the_scenes_layer() -> String:
	var layer: int = LandMeasure.ground_layer()
	if layer & LandMeasure.LOS_MASK == 0:
		return "the ground's layer %d is not one the uplink ray meets" % layer
	return ""


func test_uplink_is_stopped_by_a_hill_and_clear_in_the_open() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var land: Dictionary = LandMeasure.physics_land(tree, Terrain.HALF_M)
	# The physics server takes the new bodies in on a frame.
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = (land["holder"] as Node3D).get_world_3d().direct_space_state
	# (72, 72) is behind the hill at (48, 47) from the relay at (-70, -70).
	var behind_hill: bool = LandMeasure.sees_relay(space, Vector2i(72, 72), Terrain.HALF_M)
	var in_open: bool = LandMeasure.sees_relay(space, Vector2i(0, 0), Terrain.HALF_M)
	(land["holder"] as Node).free()
	if behind_hill:
		return "a point behind the hill sees the relay"
	if not in_open:
		return "the farm's middle cannot see the relay"
	return ""


func test_dead_spot_share_is_a_share() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var land: Dictionary = LandMeasure.physics_land(tree, Terrain.HALF_M)
	await tree.physics_frame
	await tree.physics_frame
	var spots: Dictionary = LandMeasure.dead_spots(land["holder"], Terrain.HALF_M, 16)
	(land["holder"] as Node).free()
	if spots["tried"] <= 0:
		return "no points were tried"
	var share: float = spots["share"]
	if share <= 0.0 or share > 1.0:
		return "share %f should be above 0 (the hills shade some) and at most 1" % share
	return ""
