extends RefCounted
## Phobos warm service tunnel (feat/phobos-service-tunnel): hatch transition on
## Phobos only, Deimos hatch stays sealed, ladder return to hub at hatch,
## daily deterministic Banded Regolith Runner strays, read-only stray inspect,
## deterministic build, <= 2 lights, and trip-end return home. Every node is freed
## and GameState / GameClock are restored.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _open(scene_path: String) -> Node:
	var node: Node = (load(scene_path) as PackedScene).instantiate()
	_root().add_child(node)
	return node


func _drop(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _snapshot_meshes(node: Node) -> Array[String]:
	var lines: Array[String] = []
	for child: Node in node.get_children():
		if child.name == "Walker" or child.name == "UI" or child.name == "IsoCamera":
			continue
		var label: String = "" if child.name.begins_with("@") else String(child.name)
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			var col: String = mat.albedo_color.to_html(true) if mat != null else ""
			lines.append("%s|%s|%s|%s" % [label, str(mi.position.snapped(Vector3(0.001, 0.001, 0.001))),
					str(mi.rotation_degrees.snapped(Vector3(0.01, 0.01, 0.01))), col])
		else:
			lines.append(label)
		lines.append_array(_snapshot_meshes(child))
	return lines


func _count_type(node: Node, type_name: String) -> int:
	var total: int = 1 if node.get_class() == type_name else 0
	for child: Node in node.get_children():
		if child.name == "Walker" or child.name == "UI":
			continue
		total += _count_type(child, type_name)
	return total


func test_phobos_hatch_opens_tunnel_in_reach_and_refuses_out_of_reach() -> String:
	PhobosHub.arrive_at_hatch = false
	var hub: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE) as PhobosHub
	var seen: Array[String] = []
	hub.change_scene = func(path: String) -> void: seen.append(path)
	var problem: String = ""
	# Out of reach from ARRIVE_AT (-2, 0, 7) to Hatch (14, 0, -2).
	hub._on_hatch()
	if not seen.is_empty():
		problem = "Phobos hatch opened while out of reach: %s" % [seen]
	elif hub._hint.text != Shuttle.text("hub_too_far"):
		problem = "Expected out-of-reach toast, got '%s'." % hub._hint.text
	else:
		hub.walker.position = PhobosHub.SPOTS["Hatch"]
		hub._on_hatch()
		if seen != [PhobosServiceTunnel.SCENE_PATH]:
			problem = "Phobos hatch in reach must open service tunnel, got %s" % [seen]
	_drop(hub)
	return problem


func test_deimos_hatch_remains_sealed() -> String:
	var deimos: DeimosHub = _open(SceneSwitcher.DEIMOS_SCENE) as DeimosHub
	var seen: Array[String] = []
	deimos.change_scene = func(path: String) -> void: seen.append(path)
	deimos._on_hatch()
	var problem: String = ""
	if not seen.is_empty():
		problem = "Deimos hatch must stay sealed, got %s" % [seen]
	elif deimos._hint.text != Shuttle.text("hub_hatch_text"):
		problem = "Deimos hatch toast changed: '%s'" % deimos._hint.text
	_drop(deimos)
	return problem


func test_ladder_returns_to_phobos_hub_at_hatch() -> String:
	PhobosHub.arrive_at_hatch = false
	var tunnel: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
	var seen: Array[String] = []
	tunnel.change_scene = func(path: String) -> void: seen.append(path)
	var problem: String = ""
	# Out of reach at east end.
	tunnel.walker.position = Vector3(12.0, 0.0, 0.0)
	tunnel._on_ladder()
	if not seen.is_empty():
		problem = "Ladder worked from across the tunnel: %s" % [seen]
	else:
		tunnel.walker.position = PhobosServiceTunnel.ARRIVE_AT
		tunnel._on_ladder()
		if seen != [SceneSwitcher.PHOBOS_SCENE]:
			problem = "Ladder in reach must return to Phobos hub, got %s" % [seen]
		elif not PhobosHub.arrive_at_hatch:
			problem = "Ladder must flag PhobosHub.arrive_at_hatch."
	_drop(tunnel)
	if problem == "":
		var hub: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE) as PhobosHub
		var expected: Vector3 = PhobosHub.SPOTS["Hatch"] + PhobosHub.HATCH_ARRIVE_OFFSET
		if not hub.walker.position.is_equal_approx(expected) or PhobosHub.arrive_at_hatch:
			problem = "Returning via ladder should place walker at hatch (%s), got %s." % [expected, hub.walker.position]
		_drop(hub)
	PhobosHub.arrive_at_hatch = false
	return problem


func test_stray_spots_are_deterministic_per_day_and_change_across_days() -> String:
	var day5_a: Array[int] = PhobosServiceTunnel.stray_indices_for_day(5)
	var day5_b: Array[int] = PhobosServiceTunnel.stray_indices_for_day(5)
	if day5_a.size() != PhobosServiceTunnel.STRAY_COUNT:
		return "Expected %d strays, got %d." % [PhobosServiceTunnel.STRAY_COUNT, day5_a.size()]
	if day5_a != day5_b:
		return "Stray spots differed for the same day: %s vs %s" % [day5_a, day5_b]
	var unique: Dictionary = {}
	for idx: int in day5_a:
		unique[idx] = true
	if unique.size() != day5_a.size():
		return "Stray spots for a day must be distinct: %s" % [day5_a]
	var changed: int = 0
	for day: int in range(1, 11):
		if PhobosServiceTunnel.stray_indices_for_day(day) != PhobosServiceTunnel.stray_indices_for_day(day + 1):
			changed += 1
	if changed < 6:
		return "Stray spots changed on only %d of 10 days." % changed
	return ""


func test_clicking_stray_toasts_and_changes_no_game_state() -> String:
	var held_clock: float = GameClock.elapsed_days
	GameClock.elapsed_days = 4.2
	var tunnel: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
	var before: PackedByteArray = var_to_bytes(GameState.farm_to_dict())
	var problem: String = ""
	if tunnel.stray_nodes.is_empty():
		problem = "Service tunnel built no stray spiders."
	else:
		var spot: Vector3 = tunnel.stray_nodes[0].position
		tunnel.walker.position = spot
		tunnel._on_stray_clicked(spot)
		var after: PackedByteArray = var_to_bytes(GameState.farm_to_dict())
		if tunnel._hint.text != PhobosServiceTunnel.STRAY_INSPECT_TEXT:
			problem = "Unexpected stray inspect line: '%s'" % tunnel._hint.text
		elif before != after:
			problem = "Clicking a stray must not change GameState."
	_drop(tunnel)
	GameClock.elapsed_days = held_clock
	return problem


func test_tunnel_builds_deterministically_respects_lights_and_follows_trip_end() -> String:
	var held_clock: float = GameClock.elapsed_days
	var held_trips: Dictionary = GameState.shuttle_trips.duplicate(true)
	GameClock.elapsed_days = 4.2
	GameState.shuttle_trips[GameState.local_player_id] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
	var first: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
	var second: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
	var snap_a: Array[String] = _snapshot_meshes(first)
	var snap_b: Array[String] = _snapshot_meshes(second)
	var lights: int = _count_type(first, "OmniLight3D")
	var bodies: int = _count_type(first, "StaticBody3D")
	var problem: String = ""
	if snap_a.is_empty() or snap_a != snap_b:
		problem = "Service tunnel did not build identically across runs."
	elif lights > 2:
		problem = "Service tunnel has %d lights (max 2)." % lights
	elif bodies != 5:
		problem = "Service tunnel expected 5 StaticBody3D colliders (floor + 4 walls), got %d." % bodies
	else:
		var seen: Array[String] = []
		first.change_scene = func(path: String) -> void: seen.append(path)
		GameState.shuttle_trips.erase(GameState.local_player_id)
		first._on_trips_changed()
		if seen != [SceneSwitcher.FARM_SCENE]:
			problem = "Ending the shuttle trip from inside the tunnel must return to the farm, got %s" % [seen]
	_drop(first)
	_drop(second)
	GameState.shuttle_trips = held_trips
	GameClock.elapsed_days = held_clock
	return problem
