extends "res://tests/coop_net.gd"
## Finding the Cobalt Sentinel by the sump, and the catch cup.

const SENTINEL: String = "cobalt_sentinel"
const NEAR := Vector3(3.0, 0.0, 0.0)


func _out(farm: GameStateScript) -> void:
	farm.rover_in_tunnels = true
	farm.rover_lights = false
	farm.sentinel_out = true
	farm.sentinel_days_unseen = 4
	farm.hygrometer.error = 0.0
	farm.park_rover(farm.TUNNEL_ROVER, Transform3D(Basis.IDENTITY, farm.SENTINEL_AT + NEAR))


func _run(body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	GameClock.elapsed_days = 0.0
	var farm: GameStateScript = GameStateScript.new()
	farm.build_registry()
	farm.hygrometer.max_error = INF
	_out(farm)
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(farm)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	farm.free()
	GameClock.elapsed_days = elapsed
	return problem


func test_it_sits_on_floor_by_the_sump() -> String:
	var at: Vector3 = GameStateScript.SENTINEL_AT
	if not TunnelRock.holds(at) or TunnelRock.ground_m(Vector2(at.x, at.z)) != 0.0:
		return "It must sit on level floor."
	if at.distance_to(TunnelRock.SUMP) > GameStateScript.SENTINEL_SEES_M or not TunnelRock.holds(at + NEAR):
		return "It must be by the sump, with floor for the rover beside it."
	return ""


func test_the_chance_rises_each_morning_until_it_is_met() -> String:
	return _run(func(farm: GameStateScript) -> String:
		farm.sentinel_days_unseen = 0
		for morning: int in 12:
			if not is_equal_approx(farm.sentinel_chance(), minf(1.0, 0.1 * (morning + 1))):
				return "Morning %d has a chance of %f" % [morning, farm.sentinel_chance()]
			farm._roll_sentinel()
		if not farm.sentinel_out or farm.sentinel_days_unseen != farm.SENTINEL_DAYS_MAX:
			return "A certain morning must bring it out, and count."
		farm.watch_sentinel(farm.TUNNEL_ROVER, farm.SENTINEL_AT, 0.0)
		if farm.sentinel_days_unseen != 0 or farm.sentinel_chance() != farm.SENTINEL_CHANCE:
			return "Met, it starts over."
		return "")


func test_the_morning_is_decided_once_by_the_host() -> String:
	return _run(func(farm: GameStateScript) -> String:
		var state: int = farm.rng.state
		FarmCommands.guest = true
		farm._roll_sentinel()
		FarmCommands.guest = false
		if farm.rng.state != state or farm.sentinel_days_unseen != 4:
			return "A guest must not roll."
		farm._on_day_started(2)
		if farm.sentinel_days_unseen != 5:
			return "Each day rolls once."
		farm.catch_species(SENTINEL)
		farm.sentinel_out = false
		for i: int in 20:
			farm._roll_sentinel()
		if farm.sentinel_out or farm.sentinel_days_unseen != 5:
			return "Caught, it must not come out again."
		return "")


func test_a_loaded_farm_gets_the_same_mornings() -> String:
	return _run(func(farm: GameStateScript) -> String:
		farm.sentinel_days_unseen = 0
		var later: GameStateScript = GameStateScript.new()
		later.build_registry()
		var problem: String = later.farm_from_dict(farm.farm_to_dict().duplicate(true))
		if not later.sentinel_out or later.rover_lights:
			problem += " What was saved must be back."
		var mornings: Array = [[], []]
		for i: int in 9:
			for side: int in 2:
				var gs: GameStateScript = [farm, later][side]
				gs._roll_sentinel()
				mornings[side].append(gs.sentinel_out)
		later.free()
		if mornings[0] != mornings[1]:
			problem += " Got %s" % [mornings]
		return problem)


func test_an_old_save_loads_and_bad_ones_do_not() -> String:
	return _run(func(farm: GameStateScript) -> String:
		var saved: Dictionary = farm.farm_to_dict()
		for wrong: Array in [["sentinel_out", 1], ["sentinel_days_unseen", -1], ["sentinel_days_unseen", 99999], ["sentinel_days_unseen", "4"], ["rover_lights", "on"]]:
			var bad: Dictionary = saved.duplicate(true)
			bad[wrong[0]] = wrong[1]
			if farm.farm_dict_problem(bad) == "":
				return "Must be refused: %s" % [wrong]
		var caught: Dictionary = saved.duplicate(true)
		caught["sentinel_out"] = true
		caught["enclosures"] = {String(SENTINEL): {}}
		if not "caught" in farm.farm_dict_problem(caught):
			return "A caught Sentinel can't be out too: %s" % farm.farm_dict_problem(caught)
		for key: String in ["sentinel_out", "sentinel_days_unseen", "rover_lights"]:
			saved.erase(key)
		var problem: String = farm.farm_from_dict(saved)
		if problem != "" or farm.sentinel_out or farm.sentinel_days_unseen != 0 or not farm.rover_lights:
			return "An old save starts with it unseen and the lights on. " + problem
		return "")


func test_lights_speed_and_crowding_scare_it() -> String:
	return _run(func(farm: GameStateScript) -> String:
		var beside: Vector3 = farm.SENTINEL_AT + NEAR
		# Where, how fast, lights, which rover, and whether it stays.
		for case: Array in [[beside, 2.0, false, farm.TUNNEL_ROVER, true], [beside, -2.0, false, farm.TUNNEL_ROVER, true],
				[beside, 5.0, false, farm.TUNNEL_ROVER, false], [beside, -5.0, false, farm.TUNNEL_ROVER, false],
				[beside, 0.0, true, farm.TUNNEL_ROVER, false], [farm.SENTINEL_AT + Vector3(1.0, 0.0, 0.0), 0.5, false, farm.TUNNEL_ROVER, false],
				[farm.SENTINEL_AT + Vector3(9.0, 0.0, 0.0), 8.0, true, farm.TUNNEL_ROVER, true], [beside, 8.0, true, farm.ROVER, true]]:
			_out(farm)
			farm.rover_lights = case[2]
			farm.watch_sentinel(case[3], case[0], case[1])
			if farm.sentinel_out != case[4] or farm.is_caught(SENTINEL):
				return "Wrong for %s" % [case]
		_out(farm)
		if farm.set_rover_lights(true) != "" or farm.sentinel_out:
			return "Turning the lights on beside it scares it."
		return "")


func test_the_cup_works_by_the_truth_not_the_reading() -> String:
	return _run(func(farm: GameStateScript) -> String:
		var start: float = farm.hygrometer.mpe * farm.HYGROMETER_START_ERROR_RATIO
		# Error, reading, caught.
		for case: Array in [[0.0, 80.0, true], [0.0, 85.0, true], [0.0, 74.0, false], [0.0, 86.0, false],
				[start, 80.0, false], [start, 80.0 + start, true], [6.0, 80.0, false], [-6.0, 80.0, false], [6.0, 86.0, true]]:
			_out(farm)
			farm.enclosures.clear()
			farm.hygrometer.error = case[0]
			var answer: String = farm.catch_sentinel(case[1])
			if answer != "" or farm.is_caught(SENTINEL) != case[2] or farm.sentinel_out:
				return "Wrong for %s: %s" % [case, answer]
			if not case[2] and farm.sentinel_days_unseen != 0:
				return "Lost, it only hides until another day."
		return "" if farm.hygrometer.mpe <= farm.CUP_TOLERANCE_PCT else "One in tolerance must do.")


func test_the_cup_is_refused_when_it_should_be() -> String:
	return _run(func(farm: GameStateScript) -> String:
		for reading: float in [NAN, INF, -1.0, 101.0]:
			if farm.catch_sentinel(reading) == "" or not farm.sentinel_out:
				return "A reading of %f must be refused." % reading
		farm.park_rover(farm.TUNNEL_ROVER, Transform3D(Basis.IDENTITY, farm.SENTINEL_AT + Vector3(6.0, 0.0, 0.0)))
		if farm.catch_sentinel(80.0) == "" or not farm.sentinel_out:
			return "Out of reach it must be refused, and nothing lost."
		_out(farm)
		farm.rover_in_tunnels = false
		if farm.catch_sentinel(80.0) == "" or farm.set_rover_lights(true) == "":
			return "The rover must be in the tunnels."
		_out(farm)
		CoopRovers._drivers[farm.TUNNEL_ROVER] = ["player_2", Time.get_ticks_msec() + 100000]
		var other: String = farm.catch_sentinel(80.0, "player_3")
		var lights: String = farm.set_rover_lights(true, "player_3")
		var own: String = farm.catch_sentinel(80.0, "player_2")
		CoopRovers._drivers.erase(farm.TUNNEL_ROVER)
		if other == "" or lights == "" or own != "" or not farm.is_caught(SENTINEL):
			return "Only the driver uses the cup and the lights: %s, %s, %s" % [other, lights, own]
		farm.sentinel_out = true
		if farm.catch_sentinel(80.0) == "":
			return "It is caught once."
		return "")


func test_a_guest_catches_it() -> String:
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	_out(farm)
	var guest: Node = _guest(host)
	var got: Array = _request(guest, &"catch_sentinel", [80.0])
	_until(func() -> bool: return not got.is_empty())
	var problem: String = ""
	if got != [""] or not farm.is_caught(SENTINEL):
		problem = "Got %s" % [got]
	elif not guest.commands.state.enclosures.is_empty():
		problem = "The guest waits to hear of the catch from the host."
	elif guest.commands.state.farm_from_dict(farm.farm_to_dict()) != "" or not guest.commands.state.is_caught(SENTINEL):
		problem = "The guest must hear of the catch."
	return _finish(problem)


func test_every_leg_is_on_the_body_and_the_floor() -> String:
	var rig := TarantulaRig.new()
	Engine.get_main_loop().root.add_child(rig)
	var body: AABB = _box(rig, rig._body)
	var problem: String = "" if rig._legs.size() == 8 else "It has %d legs" % rig._legs.size()
	for hip: Node3D in rig._legs:
		var leg: AABB = _box(rig, hip)
		if not leg.intersects(body):
			problem = "A leg is off the body: %s, %s" % [leg, body]
		if absf(leg.position.y) > 0.01:
			problem = "A foot is off the floor: %s" % leg
	rig.free()
	return problem


func _box(rig: Node3D, part: Node3D) -> AABB:
	var box := AABB()
	for mesh: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
		var here: AABB = (rig.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = here if box.size == Vector3.ZERO else box.merge(here)
	return box
