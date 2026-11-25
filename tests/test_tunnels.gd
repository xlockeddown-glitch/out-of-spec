extends "res://tests/coop_net.gd"
## The basalt tunnels: the map, what blocks the beacon, and a rover place kept
## apart from the farm's.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const SwitcherScript: GDScript = preload("res://scripts/autoload/SceneSwitcher.gd")
const TunnelsScene: PackedScene = preload("res://scenes/basalt_tunnels.tscn")
const ANTENNA: Vector3 = Vector3(0.22, 1.88, 0.38)


func _rock() -> TunnelRock:
	var rock := TunnelRock.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rock)
	return rock


## The names of the bodies between two points that are on any of `layers`.
func _between(rock: TunnelRock, from: Vector3, to: Vector3, layers: int) -> PackedStringArray:
	var found: PackedStringArray = []
	for body: Node in rock.get_children():
		if not body is StaticBody3D or (body as StaticBody3D).collision_layer & layers == 0:
			continue
		var box: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape
		var middle: Vector3 = (body as StaticBody3D).position
		if AABB(middle - box.size * 0.5, box.size).intersects_segment(from, to) != null:
			found.append(String(body.name).rstrip("0123456789"))
	return found


## Where the scene puts a node of the world.
func _place(scene: Node, node: String) -> Vector3:
	return (scene.get_node("WorldView/WorldViewport/World/" + node) as Node3D).position


func test_all_floor_is_reached_from_the_start() -> String:
	for row: String in TunnelRock.MAP:
		if row.length() != TunnelRock.MAP[0].length():
			return "Every row must be as long as the first"
	var start: Vector2i = TunnelRock.cell_of(GameState.TUNNEL_START.origin)
	if not TunnelRock.is_floor(start):
		return "The rover must start on floor"
	var seen: Dictionary[Vector2i, bool] = { start: true }
	var next: Array[Vector2i] = [start]
	while not next.is_empty():
		var cell: Vector2i = next.pop_back()
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if TunnelRock.is_floor(cell + side) and not seen.has(cell + side):
				seen[cell + side] = true
				next.append(cell + side)
	for y: int in TunnelRock.MAP.size():
		for x: int in TunnelRock.MAP[y].length():
			var edge: bool = x == 0 or y == 0 or x == TunnelRock.MAP[y].length() - 1 or y == TunnelRock.MAP.size() - 1
			if TunnelRock.is_floor(Vector2i(x, y)) and (edge or not seen.has(Vector2i(x, y))):
				return "Floor at %d, %d is open at the edge or can't be reached" % [x, y]
	return ""


func test_nothing_solid_is_on_the_start_the_exit_or_under_an_arch() -> String:
	var rock: TunnelRock = _rock()
	var scene: Node = TunnelsScene.instantiate()
	var problem: String = ""
	var places: Array[Vector3] = [_place(scene, "Rover"), _place(scene, "ExitPad")]
	for y: int in TunnelRock.MAP.size():
		for x: int in TunnelRock.MAP[y].length():
			if TunnelRock.tile(Vector2i(x, y)) in "AB":
				places.append(TunnelRock.at(Vector2i(x, y)))
	for at: Vector3 in places:
		for aside: Vector3 in [Vector3.ZERO, Vector3(1.0, 0.0, 1.0), Vector3(-1.0, 0.0, -1.0)]:
			var found: PackedStringArray = _between(rock, at + aside + Vector3.UP * 0.1, at + aside + Vector3.UP * 1.8, TunnelRock.LAYER_WORLD)
			if not found.is_empty():
				problem = "%s is in the rover's way at %s" % [found, at + aside]
	scene.free()
	rock.free()
	return problem


func test_the_beacon_is_seen_at_the_mouth_and_not_past_the_arch() -> String:
	var rock: TunnelRock = _rock()
	var scene: Node = TunnelsScene.instantiate()
	var dish: Vector3 = _place(scene, "Beacon") + _place(scene, "Beacon/Dish")
	var problem: String = ""
	for at: Vector3 in [_place(scene, "Rover"), _place(scene, "ExitPad"), Vector3(-1.5, 0.0, 16.5)]:
		var found: PackedStringArray = _between(rock, at + ANTENNA, dish, TunnelRock.LAYER_OCCLUDER)
		if not found.is_empty():
			problem = "%s hides the beacon at %s" % [found, at]
	# No rock is in the way here, only the arch.
	var past: Vector3 = Vector3(-2.5, 0.0, 7.5)
	var hit: PackedStringArray = _between(rock, past + ANTENNA, dish, TunnelRock.LAYER_OCCLUDER)
	if hit != PackedStringArray(["Arch"]):
		problem = "Only the arch must hide the beacon at %s, not %s" % [past, hit]
	if _between(rock, TunnelRock.at(Vector2i(19, 5)) + ANTENNA, dish, TunnelRock.LAYER_OCCLUDER).is_empty():
		problem = "The far chamber must not see the beacon"
	scene.free()
	rock.free()
	return problem


func test_the_scene_is_the_rover_the_farm_knows() -> String:
	var scene: Node = TunnelsScene.instantiate()
	var rover: RoverController = scene.get_node("WorldView/WorldViewport/World/Rover")
	var problem: String = ""
	if rover.rover_id != GameState.TUNNEL_ROVER or not rover.transform.is_equal_approx(GameState.TUNNEL_START):
		problem = "The rover in the scene must be TUNNEL_ROVER at TUNNEL_START"
	if rover.los_collision_mask & TunnelRock.LAYER_OCCLUDER == 0 or rover.collision_mask & TunnelRock.LAYER_WORLD == 0:
		problem = "Rock must stop the rover and its signal"
	scene.free()
	return problem


func test_neither_place_is_taken_for_the_other() -> String:
	var farm: Node = GameStateScript.new()
	farm.build_registry()
	var outside := Transform3D(Basis.IDENTITY, Vector3(20.5, 0.0, -15.5))
	var inside := Transform3D(Basis.IDENTITY, Vector3(-19.5, 0.0, -7.5))
	farm.park_rover("rover_1", outside)
	farm.park_rover(farm.TUNNEL_ROVER, inside)
	var saved: Dictionary = farm.farm_to_dict()
	var later: Node = GameStateScript.new()
	later.build_registry()
	var problem: String = later.farm_dict_problem(saved)
	if problem == "":
		later.farm_from_dict(saved)
		if later.parked_rover_transform("rover_1") != outside or later.parked_rover_transform(farm.TUNNEL_ROVER) != inside:
			problem = "Each place must come back as it was"
	farm.free()
	later.free()
	return problem


func test_a_rover_in_the_tunnels_says_nothing_of_the_relay() -> String:
	var farm: Node = GameStateScript.new()
	farm.set_rover_uplink("rover_1", true)
	farm.set_rover_uplink(farm.TUNNEL_ROVER, false)
	var same: bool = farm.rover_uplinks == { "rover_1": true }
	farm.free()
	return "" if same else "The beacon isn't the relay"


func test_rock_is_not_tilled_dug_or_filled() -> String:
	var rover := RoverController.new()
	rover.rover_id = "test_rover"
	var said: Array[String] = []
	for refused: Signal in [rover.till_rejected, rover.dig_rejected, rover.fill_rejected]:
		refused.connect(func(why: String) -> void: said.append(why))
	(Engine.get_main_loop() as SceneTree).root.add_child(rover)
	rover._till_under_rover("", 0)
	rover._change_ground(true)
	rover._change_ground(false)
	rover.free()
	var want: Array[String] = ["This is rock, not soil.", "This rock can't be dug.", "There is nothing to fill here."]
	return "" if said == want else "Said %s" % [said]


func test_the_airlock_leads_back_to_where_the_dome_was_entered() -> String:
	var switcher: Node = SwitcherScript.new()
	var problem: String = ""
	switcher._note_outside(SwitcherScript.TUNNELS_SCENE)
	switcher._note_outside(SwitcherScript.DOME_SCENE)
	if switcher.outside != SwitcherScript.TUNNELS_SCENE:
		problem = "From the tunnels it must lead to the tunnels"
	# A farm left in the tunnels must not send the next one there.
	switcher._note_outside(SwitcherScript.FARM_SCENE)
	switcher._note_outside(SwitcherScript.DOME_SCENE)
	if switcher.outside != SwitcherScript.FARM_SCENE:
		problem = "From the farm it must lead to the farm"
	switcher.free()
	return problem


func test_a_guest_may_drive_in_the_tunnels_first() -> String:
	var host: Node = _host()
	var mine: Node = RoversScript.new()
	mine.start(host, host.commands.state)
	var guest: Node = _guest(host)
	var theirs: Node = RoversScript.new()
	theirs.start(guest, guest.commands.state)
	var id: String = GameState.TUNNEL_ROVER
	mine.tick(Time.get_ticks_msec())
	var known: bool = host.commands.state.parked_rover_transform(id) == GameState.TUNNEL_START
	# In the game the farm's own sync brings the guest what the host parked.
	guest.commands.state.park_rover(id, GameState.TUNNEL_START)
	mine.tick(Time.get_ticks_msec() + 100000)
	var told: bool = _until(func() -> bool: return theirs._told_driver.has(id))
	var drives: bool = theirs.moves_here(id, true)
	var to := Transform3D(Basis.IDENTITY, GameState.TUNNEL_START.origin + Vector3(0.0, 0.0, -2.0))
	theirs.moved(id, to, 3.0, true)
	var followed: bool = _until(func() -> bool: return mine.place(id).is_equal_approx(to) and mine.driver(id) == "player_2")
	mine.free()
	theirs.free()
	return _finish("" if known and told and drives and followed else "known %s, told %s, drives %s, followed %s" % [known, told, drives, followed])
