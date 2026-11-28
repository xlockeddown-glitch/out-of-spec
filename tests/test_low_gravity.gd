extends RefCounted
## Low gravity on Phobos and Deimos (zones sections 2 and 13, step 17): each moon's pull, pace,
## hop and jump, a jump that goes farther than the farm's, little steering in the air,
## the tether's flat steps and full steering, the deck's edge and walls holding, and the
## three moon scenes still building. Nothing is saved or bought, so there is no save test:
## the tether is a toggle that lives while the game runs. Every node is freed.

const MASK: int = 1


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_each_moons_numbers_are_as_set_and_deimos_is_slower() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	var p: String = Shuttle.PHOBOS
	var d: String = Shuttle.DEIMOS
	if not is_equal_approx(MoonGravity.fall_mps2(p), 1.6) or not is_equal_approx(MoonGravity.fall_mps2(d), 2.0):
		problems.append("Gravity is 1.6 and 2.0.")
	if MoonGravity.fall_mps2(d) <= MoonGravity.fall_mps2(p) or MoonGravity.fall_mps2(d) >= Walker.FALL_MPS2:
		problems.append("Deimos pulls a little more than Phobos, and both far less than the farm.")
	if MoonGravity.speed_mps(d) >= MoonGravity.speed_mps(p):
		problems.append("Deimos walks slower than Phobos.")
	if not is_equal_approx(MoonGravity.speed_mps(p), Walker.SPEED_MPS):
		problems.append("Phobos walks at the farm's pace.")
	if not is_equal_approx(MoonGravity.hop_m(p), 0.12) or not is_equal_approx(MoonGravity.jump_mps(p), 2.0):
		problems.append("Phobos hop and jump numbers.")
	if not is_equal_approx(MoonGravity.hop_m(d), 0.14) or not is_equal_approx(MoonGravity.jump_mps(d), 2.2):
		problems.append("Deimos hop and jump numbers.")
	if MoonGravity.hop_s(d) <= MoonGravity.hop_s(p):
		problems.append("Deimos hops more slowly.")
	if MoonGravity.fall_mps2("farm") != Walker.FALL_MPS2 or MoonGravity.hop_m("farm") != 0.0 or MoonGravity.jump_mps("farm") != 0.0:
		problems.append("A place that is not a moon has the farm's pull, no hop and no jump.")
	if Walker.FALL_MPS2 != 9.8 or Walker.SPEED_MPS != 4.0:
		problems.append("The farm's walker is unchanged.")
	return "\n".join(problems)


func test_the_hop_is_small_never_below_the_deck_and_flat_on_a_tether() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	for moon: String in [Shuttle.PHOBOS, Shuttle.DEIMOS]:
		var top: float = 0.0
		for i: int in 101:
			var at: float = MoonGravity.hop_s(moon) * float(i) / 100.0
			var lift: float = MoonGravity.hop_offset_m(moon, at, false)
			top = maxf(top, lift)
			if lift < 0.0 or lift > MoonGravity.hop_m(moon) + 0.0001:
				problems.append("%s: lift %f out of range." % [moon, lift])
			if MoonGravity.hop_offset_m(moon, at, true) != 0.0:
				problems.append("%s: a tether has flat steps." % moon)
		if top < MoonGravity.hop_m(moon) * 0.95 or top > 0.2:
			problems.append("%s: the hop tops out at %f, a gentle height." % [moon, top])
	if MoonGravity.hop_offset_m("farm", 0.1, false) != 0.0:
		problems.append("The farm does not hop.")
	return "\n".join(problems)


func test_a_moon_jump_goes_farther_than_the_same_jump_on_the_farm() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	for moon: String in [Shuttle.PHOBOS, Shuttle.DEIMOS]:
		var speed: float = MoonGravity.speed_mps(moon)
		var jump: float = MoonGravity.jump_mps(moon)
		var here: float = MoonGravity.jump_range_m(MoonGravity.fall_mps2(moon), jump, speed)
		var farm: float = MoonGravity.jump_range_m(Walker.FALL_MPS2, jump, speed)
		if here < farm * 4.0:
			problems.append("%s: a jump goes %f m, the farm's %f m." % [moon, here, farm])
		if here < 6.0:
			problems.append("%s: a jump should carry well past a step, not %f m." % [moon, here])
	return "\n".join(problems)


func test_air_steering_is_limited_and_a_tether_steers_fully() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	var speed: float = MoonGravity.speed_mps(Shuttle.PHOBOS)
	var run := Vector3(0.0, 0.0, -speed)
	var back := Vector3(0.0, 0.0, 1.0)
	# One second of holding the opposite way barely slows the run.
	var v: Vector3 = run
	for i: int in 60:
		v = MoonGravity.air_velocity(v, back, speed, 1.0 / 60.0, false)
	if v.z >= 0.0:
		problems.append("A second of reverse still leaves the run going on, but z is %f." % v.z)
	if absf(v.z - (run.z + MoonGravity.AIR_STEER_MPS2)) > 0.01:
		problems.append("Steering is %f m/s per second at most, got z %f." % [MoonGravity.AIR_STEER_MPS2, v.z])
	var tied: Vector3 = MoonGravity.air_velocity(run, back, speed, 1.0 / 60.0, true)
	if not tied.is_equal_approx(back * speed):
		problems.append("On a tether the air steering is full: %s." % str(tied))
	var coast: Vector3 = MoonGravity.air_velocity(run, Vector3.ZERO, speed, 1.0 / 60.0, false)
	if coast.z > run.z + 0.03:
		problems.append("With no keys the run is kept: %f." % coast.z)
	return "\n".join(problems)


## A holder with a deck (and, when `wall_z` is not 0, a wall across z) the walker stands on.
func _stage(wall_z: float) -> Node3D:
	var holder := Node3D.new()
	var deck := StaticBody3D.new()
	deck.collision_layer = MASK
	var slab := BoxShape3D.new()
	slab.size = Vector3(200.0, 1.0, 200.0)
	var slab_shape := CollisionShape3D.new()
	slab_shape.shape = slab
	slab_shape.position.y = -0.5
	deck.add_child(slab_shape)
	holder.add_child(deck)
	if wall_z != 0.0:
		var wall := StaticBody3D.new()
		wall.collision_layer = MASK
		var box := BoxShape3D.new()
		box.size = Vector3(20.0, 6.0, 1.0)
		var box_shape := CollisionShape3D.new()
		box_shape.shape = box
		box_shape.position = Vector3(0.0, 3.0, wall_z)
		wall.add_child(box_shape)
		holder.add_child(wall)
	_tree().root.add_child(holder)
	return holder


func _walker(holder: Node3D, moon: String, tether: bool, at: Vector3 = Vector3.ZERO) -> PhobosWalker:
	var walker := PhobosWalker.new()
	walker.moon = moon
	PhobosWalker.tethered = tether
	holder.add_child(walker)
	walker.position = at
	walker.set_physics_process(false)
	return walker


func _settle(walker: PhobosWalker) -> void:
	for i: int in 4:
		walker.walk(Vector3.ZERO, 1.0 / 60.0)
		await _tree().physics_frame


## Runs `heading` with a jump on the first tick until it lands; returns how far along -z
## it got.
func _jump_run(walker: PhobosWalker, heading: Vector3, ticks: int) -> float:
	await _settle(walker)
	var start_z: float = walker.global_position.z
	var airborne: bool = false
	for i: int in ticks:
		walker.walk(heading, 1.0 / 60.0, i == 0)
		await _tree().physics_frame
		if not walker.is_on_floor():
			airborne = true
		elif airborne:
			break
	return start_z - walker.global_position.z


func test_a_jump_on_a_moon_lands_past_a_step_and_a_tether_gives_no_jump() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	var go := Vector3(0.0, 0.0, -1.0)
	for moon: String in [Shuttle.PHOBOS, Shuttle.DEIMOS]:
		var holder: Node3D = _stage(0.0)
		var walker: PhobosWalker = _walker(holder, moon, false)
		await _tree().physics_frame
		var far: float = await _jump_run(walker, go, 400)
		var want: float = MoonGravity.jump_range_m(MoonGravity.fall_mps2(moon), MoonGravity.jump_mps(moon), MoonGravity.speed_mps(moon))
		if far < want * 0.8 or far > want * 1.2:
			problems.append("%s: the run-and-jump went %f m, expected about %f." % [moon, far, want])
		holder.free()
		holder = _stage(0.0)
		walker = _walker(holder, moon, true)
		await _tree().physics_frame
		var flat: float = await _jump_run(walker, go, 30)
		if walker.global_position.y > 0.05 or flat > MoonGravity.speed_mps(moon) * 0.6:
			problems.append("%s: on a tether a jump goes nowhere (%f m, y %f)." % [moon, flat, walker.global_position.y])
		if walker.model.position.y != 0.0:
			problems.append("%s: on a tether the model does not hop." % moon)
		holder.free()
	PhobosWalker.tethered = false
	return "\n".join(problems)


func test_the_walker_never_passes_the_deck_edge_or_a_wall() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	var holder: Node3D = _stage(0.0)
	var walker: PhobosWalker = _walker(holder, Shuttle.PHOBOS, false, Vector3(PhobosWalker.EDGE_M - 3.0, 0.0, 0.0))
	await _tree().physics_frame
	await _settle(walker)
	var worst: float = 0.0
	for i: int in 400:
		walker.walk(Vector3.RIGHT, 1.0 / 60.0, i == 0)
		await _tree().physics_frame
		worst = maxf(worst, Vector2(walker.global_position.x, walker.global_position.z).length())
	if worst > PhobosWalker.EDGE_M + 0.001:
		problems.append("The walker went %f m out; the edge is %f." % [worst, PhobosWalker.EDGE_M])
	holder.free()
	# A wall 8 m ahead (its face at z = -7.5): a jump aimed at it never gets inside it.
	holder = _stage(-8.0)
	walker = _walker(holder, Shuttle.PHOBOS, false)
	await _tree().physics_frame
	await _settle(walker)
	var deepest: float = 0.0
	for i: int in 400:
		walker.walk(Vector3(0.0, 0.0, -1.0), 1.0 / 60.0, i == 0)
		await _tree().physics_frame
		deepest = maxf(deepest, -walker.global_position.z)
	if deepest > 7.5 - Walker.RADIUS_M + 0.05:
		problems.append("The walker reached z -%f into a wall whose face is at 7.5." % deepest)
	holder.free()
	PhobosWalker.tethered = false
	return "\n".join(problems)


func test_the_moon_scenes_still_build_and_their_walkers_know_their_moon() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	var scenes: Dictionary = {SceneSwitcher.PHOBOS_SCENE: Shuttle.PHOBOS, SceneSwitcher.DEIMOS_SCENE: Shuttle.DEIMOS}
	for path: String in scenes:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			problems.append("%s does not load." % path)
			continue
		var hub: PhobosHub = scene.instantiate() as PhobosHub
		_tree().root.add_child(hub)
		if hub.walker == null or hub.walker.moon != scenes[path]:
			problems.append("%s: the walker's moon is wrong." % path)
		_tree().root.remove_child(hub)
		hub.free()
	var tunnel_scene: PackedScene = load(PhobosServiceTunnel.SCENE_PATH) as PackedScene
	if tunnel_scene == null:
		problems.append("The service tunnel does not load.")
	else:
		var tunnel: Node = tunnel_scene.instantiate()
		_tree().root.add_child(tunnel)
		var found: PhobosWalker = tunnel.get("walker") as PhobosWalker
		if found == null or found.moon != Shuttle.PHOBOS:
			problems.append("The tunnel's walker stands on Phobos.")
		_tree().root.remove_child(tunnel)
		tunnel.free()
	return "\n".join(problems)


func test_the_hint_names_the_jump_the_tether_and_its_state() -> String:
	var problems: Array[String] = []
	PhobosWalker.tethered = false
	var off: String = PhobosWalker.hint_text()
	PhobosWalker.tethered = true
	var on: String = PhobosWalker.hint_text()
	PhobosWalker.tethered = false
	if not off.contains(Controls.prompt(&"rover_till")) or not off.contains(Controls.prompt(&"moon_tether")):
		problems.append("The hint names the jump and tether keys.")
	if off.contains("%s") or on.contains("%s"):
		problems.append("The hint has no format slot left over.")
	if off == on or not off.contains("off,") or not on.contains("on,"):
		problems.append("The hint tells whether the tether is on.")
	if not InputMap.has_action(&"moon_tether"):
		problems.append("The tether action is in the InputMap.")
	return "\n".join(problems)


func test_an_open_panel_stops_the_jump_and_the_tether_toggle() -> String:
	PhobosWalker.tethered = false
	var problems: Array[String] = []
	var holder: Node3D = _stage(0.0)
	var walker: PhobosWalker = _walker(holder, Shuttle.PHOBOS, false)
	var camera := Camera3D.new()
	holder.add_child(camera)
	walker.camera = camera
	await _tree().physics_frame
	await _settle(walker)
	var panel := Control.new()
	panel.add_to_group(QuestsUI.MODAL_GROUP)
	_tree().root.add_child(panel)
	Input.action_press(&"rover_till")
	walker._physics_process(1.0 / 60.0)
	Input.action_release(&"rover_till")
	if walker.velocity.y > 0.1:
		problems.append("A jump started behind an open panel.")
	var toggle := InputEventAction.new()
	toggle.action = &"moon_tether"
	toggle.pressed = true
	walker._unhandled_input(toggle)
	if PhobosWalker.tethered:
		problems.append("The tether toggled behind an open panel.")
	panel.free()
	walker.set_tether(false)
	walker._unhandled_input(toggle)
	if not PhobosWalker.tethered:
		problems.append("With no panel open the toggle works.")
	PhobosWalker.tethered = false
	holder.free()
	return "
".join(problems)
