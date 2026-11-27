extends SceneTree
## Prints the numbers biomes.md section 3 needs for a 160 m and a 240 m land: rover
## and walking times, ground build time, and where the relay is out of sight. It
## changes nothing in play.
## Run: godot --headless --path . --script res://tools/measure_land.gd
## Optional: -- step=4 (meters between uplink points).
## The game's classes are loaded in _run, not named here, because the autoloads
## they use do not exist yet while this script compiles (as in tests/run_tests.gd).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var measure: GDScript = load("res://scripts/world/land_measure.gd") as GDScript
	var step_m: int = 4
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("step="):
			step_m = maxi(int(arg.trim_prefix("step=")), 1)
	var speed: Dictionary = measure.call("rover_speed")
	var walk_mps: float = measure.call("walker_speed")
	print("ROVER top speed %.2f m/s, %.1f m/s2, %.2f s and %.2f m to reach it (law of RoverController._drive, flat ground)" % [
		speed["top_mps"], speed["accel_mps2"], speed["to_top_s"], speed["to_top_m"]])
	print("WALKER speed %.2f m/s (Walker.SPEED_MPS)" % walk_mps)
	print("TRIPS straight line from the farm's middle")
	for trip: Dictionary in measure.call("trips"):
		print("  %-14s %6.1f m  rover %5.1f s  on foot %5.1f s" % [
			trip["name"], trip["m"], measure.call("rover_time_s", trip["m"], speed), measure.call("walk_time_s", trip["m"])])
	var holder := Node3D.new()
	root.add_child(holder)
	var halves: Array[int] = [80, 120]
	for half_m: int in halves:
		var built: Dictionary = measure.call("build_median", holder, half_m)
		print("BUILD %d m: %.0f ms (median of %d), %d points, %d chunks, %d vertices" % [
			half_m * 2, built["ms"], measure.get("BUILD_RUNS"), built["points"], built["chunks"], built["vertices"]])
	holder.free()
	for half_m: int in halves:
		var land: Dictionary = measure.call("physics_land", self, half_m)
		# The physics server takes the ground in on a frame.
		await physics_frame
		await physics_frame
		var spots: Dictionary = measure.call("dead_spots", land["holder"], half_m, step_m)
		print("UPLINK %d m: %d of %d points (every %d m) cannot see the relay = %.1f %%" % [
			half_m * 2, spots["blocked"], spots["tried"], step_m, float(spots["share"]) * 100.0])
		if spots["ring_tried"] > 0:
			print("  outside the old 160 m: %d of %d = %.1f %%" % [
				spots["ring_blocked"], spots["ring_tried"], float(spots["ring_share"]) * 100.0])
		(land["holder"] as Node).free()
	quit()
