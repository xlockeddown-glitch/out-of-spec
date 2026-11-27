extends RefCounted
## Phobos and Deimos hubs look (feat/moon-hubs-look): deterministic builds,
## preserved named nodes, zero new collision bodies, unchanged _spots(),
## light-budget cap (<= 2 new lights per hub), distinct Phobos vs Deimos
## palette constants, and clean node teardown.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _open(scene_path: String) -> PhobosHub:
	var hub: PhobosHub = (load(scene_path) as PackedScene).instantiate() as PhobosHub
	_root().add_child(hub)
	return hub


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


func test_phobos_and_deimos_hubs_build_deterministically() -> String:
	var problem: String = ""
	for path: String in [SceneSwitcher.PHOBOS_SCENE, SceneSwitcher.DEIMOS_SCENE]:
		var first: PhobosHub = _open(path)
		var second: PhobosHub = _open(path)
		var snap_a: Array[String] = _snapshot_meshes(first)
		var snap_b: Array[String] = _snapshot_meshes(second)
		if snap_a.is_empty():
			problem = "%s produced no meshes." % path
		elif snap_a != snap_b:
			problem = "%s differed across identical builds (%d vs %d entries)." % [path, snap_a.size(), snap_b.size()]
		_drop(first)
		_drop(second)
		if problem != "":
			break
	return problem


func test_named_nodes_exist_on_both_hubs() -> String:
	var problem: String = ""
	var phobos: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE)
	var phobos_names: Array[String] = [
		"Sky", "Sun", "Deck", "DeckPlate", "Crater", "OuterRocks", "Pad", "PadRim", "Mars",
		"ShuttleBody", "ShuttleCockpit", "ShuttleWingA", "ShuttleWingB", "ShuttleDetail",
		"Station", "StationDoor", "StationDome", "StationDetail",
		"ConsoleDesk", "ConsoleDesk/Desk", "ConsoleDesk/Screen", "Console",
		"BoardPanel", "BoardTrim", "Board", "Grille", "GrilleTear", "ShedSkin", "HookSign",
		"HatchPlate", "HatchLid", "Hatch",
	]
	for node_path: String in phobos_names:
		if phobos.get_node_or_null(node_path) == null:
			problem = "PhobosHub is missing node '%s'." % node_path
			break
	_drop(phobos)
	if problem != "":
		return problem

	var deimos: PhobosHub = _open(SceneSwitcher.DEIMOS_SCENE)
	var deimos_names: Array[String] = [
		"Sky", "Sun", "Deck", "DeckPlate", "Dust", "Crater", "OuterRocks", "Pad", "PadRim", "Mars",
		"ShuttleBody", "ShuttleCockpit", "ShuttleWingA", "ShuttleWingB", "ShuttleDetail",
		"HabSkirt", "HabBody", "HabRoof", "HabDish", "HabDoor", "HabPortA", "HabDetail",
		"ConsoleDesk", "ConsoleDesk/Desk", "ConsoleDesk/Screen", "Console",
		"BoardPanel", "BoardTrim", "Board",
		"CacheSwept", "CrateA", "CrateB", "CrateC", "CachePadlock", "CacheSign",
		"PodShell", "PodGlass", "PodWarmth", "PodSign",
	]
	for node_path: String in deimos_names:
		if deimos.get_node_or_null(node_path) == null:
			problem = "DeimosHub is missing node '%s'." % node_path
			break
	_drop(deimos)
	return problem


func test_collision_counts_lights_and_spots_are_unchanged() -> String:
	var problem: String = ""
	var phobos: PhobosHub = _open(SceneSwitcher.PHOBOS_SCENE)
	var p_static: int = _count_type(phobos, "StaticBody3D")
	var p_area: int = _count_type(phobos, "Area3D")
	var p_lights: int = _count_type(phobos, "OmniLight3D")
	if p_static != 8:
		problem = "PhobosHub StaticBody3D count changed: expected 8, got %d." % p_static
	elif p_area != 4:
		problem = "PhobosHub Area3D count changed: expected 4, got %d." % p_area
	elif p_lights > 2:
		problem = "PhobosHub added too many lights: %d (max 2)." % p_lights
	elif phobos._spots() != {
		"Console": Vector3(-6.0, 0.0, 3.0),
		"Board": Vector3(-3.0, 0.0, -8.6),
		"HookSign": Vector3(9.5, 0.0, -8.6),
		"Hatch": Vector3(14.0, 0.0, -2.0),
	}:
		problem = "PhobosHub _spots() changed."
	_drop(phobos)
	if problem != "":
		return problem

	var deimos: PhobosHub = _open(SceneSwitcher.DEIMOS_SCENE)
	var d_static: int = _count_type(deimos, "StaticBody3D")
	var d_area: int = _count_type(deimos, "Area3D")
	var d_lights: int = _count_type(deimos, "OmniLight3D")
	if d_static != 11:
		problem = "DeimosHub StaticBody3D count changed: expected 11, got %d." % d_static
	elif d_area != 4:
		problem = "DeimosHub Area3D count changed: expected 4, got %d." % d_area
	elif d_lights > 2:
		problem = "DeimosHub added too many lights: %d (max 2)." % d_lights
	elif deimos._spots() != {
		"Console": Vector3(-6.0, 0.0, 3.0),
		"Board": Vector3(-3.0, 0.0, -8.6),
		"Cache": Vector3(10.0, 0.0, -8.0),
		"Pod": Vector3(16.0, 0.0, -2.5),
	}:
		problem = "DeimosHub _spots() changed."
	_drop(deimos)
	return problem


func test_phobos_and_deimos_differ_in_look_constants() -> String:
	if MoonLook.PHOBOS_DECK == MoonLook.DEIMOS_DECK:
		return "Phobos and Deimos deck colours must differ."
	if MoonLook.PHOBOS_CRATER == MoonLook.DEIMOS_CRATER:
		return "Phobos and Deimos crater colours must differ."
	if MoonLook.PHOBOS_HULL == MoonLook.DEIMOS_HULL:
		return "Phobos and Deimos shuttle hull colours must differ."
	if MoonLook.PHOBOS_SKY == MoonLook.DEIMOS_SKY:
		return "Phobos and Deimos sky colours must differ."
	return ""
