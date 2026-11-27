class_name LandMeasure
extends RefCounted
## Numbers for sizing the land (docs/design/biomes.md section 3): how fast the rover
## and the walker cover it, what it costs to build the ground, and where the relay
## cannot be seen. It changes nothing in play. tools/measure_land.gd prints it all.

## The land sizes compared: today's, and the one Ryan chose [PLACEHOLDER].
const SIZES_M: Array[int] = [160, 240]
## Straight-line trips from the middle of the farm, in meters. The airlock and the
## tunnel mouth are where scenes/main_farm.tscn puts them; the relay is Terrain.RELAY.
const AIRLOCK := Vector2(8.0, 14.0)
const TUNNEL_MOUTH := Vector2(20.5, -19.0)
## Distances out from the middle for a new biome's marker; 115 m is the edge of a
## 240 m land.
const OUT_M: Array[float] = [60.0, 100.0, 115.0]
## The relay's dish and the rover's antenna, from the scene: the dish is 2, 15.5, 2
## from the relay's foot; the antenna is 1.88 m over the rover's origin.
const DISH_OFFSET := Vector3(2.0, 15.5, 2.0)
const ANTENNA_M: float = 1.88
## The uplink's ray meets the ground and the rocks on this layer
## (RoverController.los_collision_mask).
const LOS_MASK: int = 4
## The scene node whose collision layer the measured ground copies.
const SCENE_PATH := "res://scenes/main_farm.tscn"
const GROUND_NODE := "Ground"
## How many times a build is timed; the middle one is kept.
const BUILD_RUNS: int = 3


## The rover's speed on flat ground, from RoverController's own numbers and the law
## its _drive applies each physics tick (a move_toward). Not a full physics run, which
## would need the whole farm scene.
static func rover_speed() -> Dictionary:
	var rover := RoverController.new()
	var top_mps: float = rover.max_speed_mps
	var accel_mps2: float = rover.acceleration_mps2
	rover.free()
	var step_s: float = 1.0 / float(Engine.physics_ticks_per_second)
	var speed_mps: float = 0.0
	var time_s: float = 0.0
	var run_m: float = 0.0
	while speed_mps < top_mps:
		speed_mps = move_toward(speed_mps, top_mps, accel_mps2 * step_s)
		time_s += step_s
		run_m += speed_mps * step_s
	return {"top_mps": top_mps, "accel_mps2": accel_mps2, "to_top_s": time_s, "to_top_m": run_m}


## Seconds for the rover to drive `distance_m` in a straight line from rest on flat
## ground: it speeds up, then holds its top speed.
static func rover_time_s(distance_m: float, speed: Dictionary) -> float:
	var to_top_m: float = speed["to_top_m"]
	if distance_m <= to_top_m:
		# Still speeding up: distance is half of acceleration times time squared.
		return sqrt(2.0 * distance_m / float(speed["accel_mps2"]))
	return float(speed["to_top_s"]) + (distance_m - to_top_m) / float(speed["top_mps"])


## The walker's speed in m/s.
static func walker_speed() -> float:
	return Walker.SPEED_MPS


## Seconds to walk `distance_m` in a straight line. The walker holds its speed at once.
static func walk_time_s(distance_m: float) -> float:
	return distance_m / Walker.SPEED_MPS


## The trips of biomes.md section 3.1, from the middle of the farm: name, meters.
static func trips() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"name": "Dome airlock", "m": AIRLOCK.length()},
		{"name": "Tunnel mouth", "m": TUNNEL_MOUTH.length()},
		{"name": "Relay", "m": Terrain.RELAY.length()},
	]
	for out_m: float in OUT_M:
		list.append({"name": "%d m out" % int(out_m), "m": out_m})
	return list


## The collision layer scenes/main_farm.tscn gives its Ground (world and
## signal_occluder), read from the scene so the uplink ray meets the ground as in play.
static func ground_layer() -> int:
	var state: SceneState = (load(SCENE_PATH) as PackedScene).get_state()
	for i: int in state.get_node_count():
		if state.get_node_name(i) != GROUND_NODE:
			continue
		for j: int in state.get_node_property_count(i):
			if state.get_node_property_name(i, j) == &"collision_layer":
				return int(state.get_node_property_value(i, j))
	push_error("LandMeasure: no collision_layer on %s in %s" % [GROUND_NODE, SCENE_PATH])
	return 0


## Builds the real ground (TerrainGround) for a land reaching `half_m` from its
## middle, under `parent`, and says how long the height grid and the meshes took.
## The caller frees the ground. A land bigger than Terrain.HALF_M uses the same
## height function with its rim at the new edge (Terrain.natural_on).
static func build(parent: Node, half_m: int) -> Dictionary:
	# Cold, as at the farm's start, not the grid an earlier build left.
	Terrain._natural = PackedFloat32Array()
	var ground := TerrainGround.new()
	ground.half_m = half_m
	ground.collision_layer = ground_layer()
	var started_us: int = Time.get_ticks_usec()
	parent.add_child(ground)
	var built_ms: float = float(Time.get_ticks_usec() - started_us) / 1000.0
	var chunks: int = 0
	var vertices: int = 0
	for child: Node in ground.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			chunks += 1
			vertices += (child as MeshInstance3D).mesh.surface_get_array_len(0)
	return {"ground": ground, "ms": built_ms, "chunks": chunks, "vertices": vertices, "points": (2 * half_m + 1) * (2 * half_m + 1)}


## build() BUILD_RUNS times; the run with the middle time, its ground freed.
static func build_median(parent: Node, half_m: int) -> Dictionary:
	var runs: Array[Dictionary] = []
	for i: int in BUILD_RUNS:
		var run: Dictionary = build(parent, half_m)
		(run["ground"] as Node).free()
		run.erase("ground")
		runs.append(run)
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) < float(b["ms"]))
	@warning_ignore("integer_division")
	return runs[BUILD_RUNS / 2]


## The natural ground at a whole-meter point of a land reaching `half_m`.
static func ground_m(point: Vector2i, half_m: int) -> float:
	return Terrain.natural(point) if half_m == Terrain.HALF_M else Terrain.natural_on(point, half_m)


## Whether the relay's dish can be seen from a rover at `point`, by the game's own
## check (RoverController._raycast_to_relay): a ray from the antenna to the dish that
## the ground or a rock may stop. `space` must hold the ground and the rocks.
static func sees_relay(space: PhysicsDirectSpaceState3D, point: Vector2i, half_m: int) -> bool:
	var from := Vector3(point.x, ground_m(point, half_m) + ANTENNA_M, point.y)
	var dish: Vector3 = Vector3(Terrain.RELAY.x, 0.0, Terrain.RELAY.y) + DISH_OFFSET
	var query := PhysicsRayQueryParameters3D.create(from, dish, LOS_MASK)
	return space.intersect_ray(query).is_empty()


## A land's ground and rocks in the physics world, under a new node on the tree.
## The caller frees the node.
static func physics_land(tree: SceneTree, half_m: int) -> Dictionary:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var ground: Dictionary = build(holder, half_m)
	holder.add_child(HillDressing.new())
	return {"holder": holder, "build_ms": ground["ms"]}


## Tries a point every `step_m` over a land made by physics_land: `blocked` of the
## `tried` cannot see the relay, `share` is that part of them (0 to 1), and the
## `ring` numbers are the same for the points outside today's land. Boulders (the
## scene's four loose rocks) are not in it.
static func dead_spots(holder: Node3D, half_m: int, step_m: int) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
	var tried: int = 0
	var blocked: int = 0
	var ring_tried: int = 0
	var ring_blocked: int = 0
	for z: int in range(-half_m, half_m + 1, step_m):
		for x: int in range(-half_m, half_m + 1, step_m):
			var blind: bool = not sees_relay(space, Vector2i(x, z), half_m)
			tried += 1
			blocked += 1 if blind else 0
			if maxi(absi(x), absi(z)) > Terrain.OLD_HALF_M:
				ring_tried += 1
				ring_blocked += 1 if blind else 0
	return {
		"tried": tried, "blocked": blocked, "share": float(blocked) / float(maxi(tried, 1)),
		"ring_tried": ring_tried, "ring_blocked": ring_blocked,
		"ring_share": float(ring_blocked) / float(maxi(ring_tried, 1)),
	}
