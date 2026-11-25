extends "res://tests/coop_net.gd"
## The basalt tunnels: the map, what blocks the beacon, and a rover place kept
## apart from the farm's.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const SwitcherScript: GDScript = preload("res://scripts/autoload/SceneSwitcher.gd")
const FarmScene: PackedScene = preload("res://scenes/main_farm.tscn")
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
		var box := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
		if box == null:
			continue  # the pool's ground
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


func test_the_pads_are_where_the_farm_thinks() -> String:
	var tunnels: Node = TunnelsScene.instantiate()
	var farm: Node = FarmScene.instantiate()
	var problem: String = ""
	if _place(tunnels, "ExitPad") != GameState.TUNNEL_EXIT or _place(farm, "TunnelPad") != GameState.TUNNEL_PAD:
		problem = "The pads must be where GameState says"
	if not TunnelRock.holds(GameState.TUNNEL_EXIT) or not TunnelRock.holds(GameState.TUNNEL_START.origin):
		problem = "The rover must be able to be at the mouth"
	tunnels.free()
	farm.free()
	return problem


func test_the_rover_goes_in_and_comes_out_where_it_went_in() -> String:
	var farm: Node = GameStateScript.new()
	var off_pad := Transform3D(Basis.IDENTITY, farm.TUNNEL_PAD + Vector3(farm.TUNNEL_PAD_REACH_M + 0.1, 0.0, 0.0))
	var mouth := Transform3D(Basis.IDENTITY, farm.TUNNEL_PAD + Vector3(1.0, 0.0, 0.0))
	var shown: Array[int] = [0]
	farm.rover_place_changed.connect(func() -> void: shown[0] += 1)
	var problem: String = ""
	if farm.move_rover(true) == "" or farm.move_rover(false) == "":
		problem = "Only a rover whose place is known goes in, and only one inside comes out"
	farm.park_rover(farm.ROVER, off_pad)
	if farm.move_rover(true) == "" or farm.rover_in_tunnels:
		problem = "It must be on the pad"
	farm.park_rover(farm.ROVER, mouth)
	CoopRovers._drivers[farm.ROVER] = ["player_2", 0]
	var other: String = farm.move_rover(true, "player_1")
	var own: String = farm.move_rover(true, "player_2")
	CoopRovers._drivers.erase(farm.ROVER)
	if other == "" or own != "" or not farm.rover_in_tunnels or shown[0] != 1:
		problem = "Whoever drives takes it in, and nobody else (%s, %s)" % [other, own]
	if farm.parked_rover_transform(farm.TUNNEL_ROVER) != farm.TUNNEL_START or not farm.rover_is_away(farm.ROVER) or farm.rover_here() != farm.TUNNEL_ROVER:
		problem = "It comes in at the mouth and is gone from the farm"
	if farm.move_rover(true) == "":
		problem = "It can't go in twice"
	farm.park_rover(farm.TUNNEL_ROVER, Transform3D(Basis.IDENTITY, Vector3(-19.5, 0.0, -7.5)))
	if farm.move_rover(false) == "":
		problem = "It comes out only from the pad there"
	farm.park_rover(farm.TUNNEL_ROVER, Transform3D(Basis.IDENTITY, farm.TUNNEL_EXIT))
	if farm.move_rover(false) != "" or farm.rover_in_tunnels or farm.parked_rover_transform(farm.ROVER) != mouth or not farm.rover_is_away(farm.TUNNEL_ROVER):
		problem = "It comes out where it went in"
	farm.free()
	return problem


func test_the_rover_is_gone_from_the_scene_it_is_not_in() -> String:
	var held: Array = [GameState.rover_in_tunnels, GameState.rover_transforms.duplicate()]
	GameState.rover_in_tunnels = false
	GameState.rover_transforms.clear()
	var rover := RoverController.new()
	rover.rover_id = GameState.ROVER
	(Engine.get_main_loop() as SceneTree).root.add_child(rover)
	var problem: String = ""
	if rover.away_text() != "" or not rover.visible or not rover.can_process():
		problem = "On the farm it is there"
	var entry := Transform3D(Basis.IDENTITY, GameState.TUNNEL_PAD)
	GameState.park_rover(GameState.ROVER, entry)
	GameState.rover_in_tunnels = true
	GameState.rover_place_changed.emit()
	rover.queue_command(RoverController.Command.DIG)
	rover._park()
	if rover.away_text() != "The rover is in the tunnels. Press E to go there." or rover.visible or rover.can_process() or not rover._commands.is_empty():
		problem = "In the tunnels it is gone from the farm and takes no command"
	if GameState.parked_rover_transform(GameState.ROVER) != entry:
		problem = "One that is gone must not say where it is"
	GameState.rover_in_tunnels = false
	GameState.rover_place_changed.emit()
	if not rover.visible or not rover.can_process() or rover.position.distance_to(entry.origin) > 0.1:
		problem = "It must be back where it went in (%s)" % rover.position
	rover.free()
	GameState.rover_in_tunnels = held[0]
	GameState.rover_transforms = held[1]
	return problem


func test_a_rover_in_the_rock_comes_back_at_the_mouth() -> String:
	var held: Array = [GameState.rover_in_tunnels, GameState.rover_transforms.duplicate()]
	GameState.rover_in_tunnels = true
	GameState.rover_transforms = { GameState.TUNNEL_ROVER: Transform3D(Basis.IDENTITY, Vector3(400.0, 0.0, 0.0)) }
	var rover := RoverController.new()
	rover.rover_id = GameState.TUNNEL_ROVER
	(Engine.get_main_loop() as SceneTree).root.add_child(rover)
	var at: Vector3 = rover.position
	rover.free()
	GameState.rover_in_tunnels = held[0]
	GameState.rover_transforms = held[1]
	return "" if at == GameState.TUNNEL_START.origin else "It is at %s" % at


func test_older_saves_have_the_rover_on_the_farm() -> String:
	var farm: Node = GameStateScript.new()
	farm.build_registry()
	farm.rover_in_tunnels = true
	var saved: Dictionary = farm.farm_to_dict()
	var problem: String = ""
	var later: Node = GameStateScript.new()
	later.build_registry()
	if later.farm_from_dict(saved) != "" or not later.rover_in_tunnels:
		problem = "The place must be saved"
	saved.erase("rover_in_tunnels")
	if later.farm_from_dict(saved) != "" or later.rover_in_tunnels:
		problem = "A save without one has it on the farm"
	for wrong: Variant in ["tunnels", 1, null]:
		saved["rover_in_tunnels"] = wrong
		if later.farm_dict_problem(saved) == "":
			problem = "%s is no place" % wrong
	farm.free()
	later.free()
	return problem


func test_continue_opens_the_tunnels_only_if_left_there_with_the_rover() -> String:
	var held: Dictionary = SaveGame.snapshot()
	var held_open: bool = SaveGame.farm_open
	var path: String = "user://test_tunnels.save"
	var inside := Transform3D(Basis.IDENTITY, Vector3(-19.5, 0.0, -7.5))
	var farm: String = SceneSwitcher.FARM_SCENE
	var tunnels: String = SceneSwitcher.TUNNELS_SCENE
	var problem: String = ""
	# The saved scene, whether the rover is inside, and the scene that opens.
	for case: Array in [[tunnels, true, tunnels], [farm, true, farm], [SceneSwitcher.DOME_SCENE, true, farm], ["res://no.tscn", true, farm],
			[3, true, farm], [null, true, farm], [tunnels, false, farm], [farm, false, farm]]:
		GameState.rover_in_tunnels = case[1]
		GameState.park_rover(GameState.TUNNEL_ROVER, inside)
		var data: Dictionary = SaveGame.snapshot()
		data["scene"] = case[0]
		if case[0] == null:
			data.erase("scene")  # an older save
		SaveGame._write_data(data, path)
		if SaveGame.continue_farm(path) != "" or SaveGame.open_scene != case[2]:
			problem = "%s opened %s" % [case, SaveGame.open_scene]
		if GameState.rover_in_tunnels != (case[2] == tunnels) or GameState.parked_rover_transform(GameState.TUNNEL_ROVER) != inside:
			problem = "%s: the rover must be in the scene that opens, where it was parked" % [case]
	DirAccess.remove_absolute(path)
	SaveGame.restore(held)
	SaveGame.farm_open = held_open
	return problem


func test_a_guest_drives_the_rover_only_where_it_is() -> String:
	var host: Node = _host()
	var mine: Node = RoversScript.new()
	mine.start(host, host.commands.state)
	var guest: Node = _guest(host)
	var theirs: Node = RoversScript.new()
	theirs.start(guest, guest.commands.state)
	var id: String = GameState.TUNNEL_ROVER
	for farm: Node in [host.commands.state, guest.commands.state]:
		farm.park_rover(GameState.ROVER, Transform3D(Basis.IDENTITY, GameState.TUNNEL_PAD))
		farm.park_rover(id, GameState.TUNNEL_START)
	theirs._told_driver[id] = ""
	var early: bool = theirs.moves_here(id, true)
	var asked: Array = _request(guest, &"move_rover", [true])
	_until(func() -> bool: return not asked.is_empty())
	var went: bool = asked == [""] and host.commands.state.rover_in_tunnels
	# In the game the farm's own sync brings the guest the host's farm.
	guest.commands.state.rover_in_tunnels = true
	guest.commands.state.rover_place_changed.emit()
	mine.tick(Time.get_ticks_msec() + 100000)
	var told: bool = _until(func() -> bool: return theirs._told_driver.has(id))
	var drives: bool = theirs.moves_here(id, true) and not theirs._told_driver.has(GameState.ROVER)
	var to := Transform3D(Basis.IDENTITY, GameState.TUNNEL_START.origin + Vector3(0.0, 0.0, -2.0))
	theirs.moved(id, to, 3.0, true)
	var followed: bool = _until(func() -> bool: return mine.place(id).is_equal_approx(to) and mine.driver(id) == "player_2")
	# A guest's word is not enough for the rover on the farm, or for one in the rock.
	mine._on_driven("player_2", GameState.ROVER, [GameState.TUNNEL_PAD.x - 2.0, 0.0, GameState.TUNNEL_PAD.z, 0.0, 1.0, true])
	var forged: bool = mine.driver(GameState.ROVER) != "" or mine.place(GameState.ROVER).origin != GameState.TUNNEL_PAD
	var rock: Vector3 = to.origin + Vector3(0.0, 0.0, 13.0)
	mine._on_driven("player_2", id, [rock.x, rock.y, rock.z, 0.0, 1.0, true])
	forged = forged or TunnelRock.holds(rock) or not mine.place(id).is_equal_approx(to)
	mine.free()
	theirs.free()
	return _finish("" if not early and went and told and drives and followed and not forged
		else "early %s, went %s %s, told %s, drives %s, followed %s, forged %s" % [early, went, asked, told, drives, followed, forged])


func test_pieces_cover_no_path_and_hide_no_floor() -> String:
	var rock: TunnelRock = _rock()
	var scene: Node = TunnelsScene.instantiate()
	var found: PackedStringArray = []
	var problem: String = ""
	for y: int in TunnelRock.MAP.size():
		for x: int in TunnelRock.MAP[y].length():
			var cell := Vector2i(x, y)
			var kind: String = TunnelRock.tile(cell)
			if not TunnelRock.PIECES.has(kind):
				continue
			found.append(kind)
			var at: Vector3 = TunnelRock.at(cell)
			var size: Vector3 = TunnelRock.PIECES[kind][1]
			if maxf(size.x, size.z) > TunnelRock.CELL_M or TunnelRock.holds(at):
				problem = "%s must fill its cell and no more" % kind
			if _between(rock, at + Vector3(-3.0, 0.5, 0.0), at + Vector3(3.0, 0.5, 0.0), TunnelRock.LAYER_WORLD).has("Piece") == false:
				problem = "%s must stop the rover" % kind
			# At the antenna's height. The sump is lower.
			if _between(rock, at + Vector3(-3.0, 1.88, 0.0), at + Vector3(3.0, 1.88, 0.0), TunnelRock.LAYER_OCCLUDER).has("Piece") == (kind == "S"):
				problem = "%s must stop the signal, or be the low sump" % kind
			# The camera looks toward -x and -z, so this is what it hides.
			for behind: Vector2i in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1)]:
				if TunnelRock.is_floor(cell + behind):
					problem = "%s hides floor" % kind
			for node: String in ["Beacon", "ExitPad", "Rover"]:
				if at.distance_to(_place(scene, node)) < 5.0:
					problem = "%s is at the %s" % [kind, node]
	found.sort()
	if found != PackedStringArray(["G", "S", "V", "W"]):
		problem = "Each piece must stand once, not %s" % [found]
	scene.free()
	rock.free()
	return problem


func test_shallow_water_is_driven_and_deep_water_is_not() -> String:
	var rock: TunnelRock = _rock()
	var sump := Vector2(TunnelRock.SUMP.x, TunnelRock.SUMP.z)
	var problem: String = ""
	if TunnelRock.holds(TunnelRock.SUMP) or TunnelRock.ground_m(sump) != TunnelRock.DEEP_GROUND_M:
		problem = "The middle is deep"
	if not _between(rock, TunnelRock.SUMP + Vector3(-4.0, 0.2, 0.0), TunnelRock.SUMP + Vector3(4.0, 0.2, 0.0), TunnelRock.LAYER_WORLD).has("Low"):
		problem = "Deep water must stop the rover"
	# From level ground south and east of it up to where the rover's nose meets the deep.
	for way: Vector2 in [Vector2.DOWN, Vector2.RIGHT]:
		var lowest_m: float = 0.0
		var last_m: float = 0.0
		for i: int in 14:
			var place: Vector2 = sump + way * (6.0 - i * 0.25)
			var ground_m: float = TunnelRock.ground_m(place)
			if i == 0 and ground_m != 0.0:
				problem = "The shore must be level"
			if last_m - ground_m > 0.25 * tan(deg_to_rad(30.0)):
				problem = "Too steep to drive at %s" % place
			last_m = ground_m
			lowest_m = minf(lowest_m, ground_m)
			var at := Vector3(place.x, ground_m, place.y)
			var found: PackedStringArray = _between(rock, at + Vector3.UP * 0.1, at + Vector3.UP * 1.8, TunnelRock.LAYER_WORLD)
			if not TunnelRock.holds(at) or not found.is_empty():
				problem = "The rover can't be in the shallows at %s (%s)" % [at, found]
		if lowest_m >= TunnelRock.WATER_M or lowest_m <= TunnelRock.DEEP_GROUND_M:
			problem = "The shelf must be under shallow water"
	# The floor's own boxes must not fill the hollow.
	for place: Vector2 in [sump + Vector2(0.0, 3.0), sump]:
		if _between(rock, Vector3(place.x, -0.05, place.y), Vector3(place.x, -0.95, place.y), TunnelRock.LAYER_WORLD).has("Floor"):
			problem = "The floor covers the pool"
	var hollow: HeightMapShape3D = (rock.get_node("Hollow").get_child(0) as CollisionShape3D).shape
	if not is_equal_approx(hollow.get_min_height(), TunnelRock.DEEP_GROUND_M) or hollow.get_max_height() != 0.0:
		problem = "The ground must go from level to deep"
	for z: int in hollow.map_depth:
		for x: int in hollow.map_width:
			var at := Vector2(rock.get_node("Hollow").position.x, rock.get_node("Hollow").position.z) + Vector2(x - (hollow.map_width - 1) * 0.5, z - (hollow.map_depth - 1) * 0.5)
			if not is_equal_approx(hollow.map_data[z * hollow.map_width + x], TunnelRock.ground_m(at)):
				problem = "The ground to stand on is not the ground at %s" % at
	if not TunnelRock.in_deep(TunnelRock.SUMP + Vector3(2.0, 0.0, 0.0)) or TunnelRock.in_deep(TunnelRock.SUMP + Vector3(0.0, 0.0, 2.5)):
		problem = "Only a rover over the deep's edge is in it"
	rock.free()
	return problem


func test_water_is_where_the_ground_is_lower_and_darker_where_deeper() -> String:
	var tints: Array[Color] = []
	for i: int in 17:
		var tint: Color = VoxelWater.tint(i * 0.1)
		if not tint in tints:
			tints.append(tint)
	if tints.size() != VoxelWater.TINT_STEPS + 1 or tints[0] != VoxelWater.SHALLOW or tints[-1] != VoxelWater.DEEP:
		return "The tint must go from shallow to deep in steps, not %s" % [tints]
	var water := VoxelWater.new()
	# Half a meter of dry ground, then half a meter that is 0.3 m under water.
	water.fill(Rect2(0.0, 0.0, 1.0, 0.25), -0.1, func(place: Vector2) -> float: return 0.0 if place.x < 0.5 else -0.4)
	var problem: String = ""
	if water.places.size() != 2 or water.multimesh.instance_count != 2:
		problem = "Only the low ground has water, not %d columns" % water.places.size()
	elif not is_equal_approx(water.places[0].basis.y.length(), 0.3) or not is_equal_approx(water.places[0].origin.y, -0.25):
		problem = "A column goes from the ground to the level"
	elif water.colors[0].a != 1.0 or water.colors[1].a != 0.0:
		problem = "Only the column at the shore is foam"
	water.free()
	return problem
