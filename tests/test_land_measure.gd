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


func test_bigger_land_keeps_the_middle() -> String:
	# The 240 m measuring land is the same ground inside the farm's level circle.
	for at: Vector2i in [Vector2i(0, 0), Vector2i(20, -10), Vector2i(-30, 30)]:
		if LandMeasure.ground_m(at, 120) != Terrain.natural(at):
			return "ground at %s differs on a bigger land" % str(at)
	return ""


func test_dead_spot_share_is_a_share() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var land: Dictionary = LandMeasure.physics_land(tree, SMALL_HALF_M)
	var spots: Dictionary = LandMeasure.dead_spots(land["holder"], SMALL_HALF_M, 8)
	(land["holder"] as Node).free()
	if spots["tried"] <= 0:
		return "no points were tried"
	var share: float = spots["share"]
	if share < 0.0 or share > 1.0:
		return "share %f is not in 0 to 1" % share
	return ""
