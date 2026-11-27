extends RefCounted
## Gating hints (docs/design/biomes.md section 6, step 9): BiomeData.is_open at the
## boundary levels and audits, road lamps lit or dark to match, no lamp where one
## must not stand, and the sign's next-step line while a biome is closed.


var _nodes: Array[Node] = []


func _built() -> RoadLamps:
	var lamps := RoadLamps.new()
	var none: Dictionary[Vector2i, int] = {}
	lamps.build(none)
	_nodes.append(lamps)
	return lamps


func _signs() -> BiomeMarkers:
	var markers := BiomeMarkers.new()
	var none: Dictionary[Vector2i, int] = {}
	markers.build(none)
	_nodes.append(markers)
	return markers


## Runs `body` with the lab at `level` and `audits` audits on the log, then puts both back.
func _with_state(level: int, audits: int, body: Callable) -> String:
	var xp: int = GameState.lab_xp
	var kept: Array[Dictionary] = GameState.audit_log.duplicate()
	GameState.lab_xp = GameState.xp_for_level(level)
	GameState.audit_log.clear()
	for i: int in audits:
		GameState.audit_log.append({})
	var result: String = body.call()
	GameState.lab_xp = xp
	GameState.audit_log.assign(kept)
	_cleanup()
	return result


## Frees every node the test made, in the tree or not.
func _cleanup() -> void:
	for node: Node in _nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()


## Puts `node` in the tree's root so its _ready runs and its signals connect.
func _live(node: Node) -> void:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_nodes.append(node)


func test_is_open_at_each_boundary() -> String:
	var cases: Array = [
		[&"farm", 1, 0, true],
		[&"lab_quarter", 99, 0, false], [&"lab_quarter", 1, 1, true],
		[&"badlands", 1, 0, true],
		[&"basalt_ridge", 4, 9, false], [&"basalt_ridge", 5, 0, true],
		[&"frost_flats", 17, 9, false], [&"frost_flats", 18, 0, true],
		[&"landing_field", 19, 9, false], [&"landing_field", 20, 0, true],
		[&"nowhere", 99, 9, false],
	]
	for c: Array in cases:
		if BiomeData.is_open(c[0], c[1], c[2]) != c[3]:
			return "%s at lab %d, %d audits: expected %s" % [c[0], c[1], c[2], c[3]]
	return ""


func test_the_table_opens_are_checked() -> String:
	var rows: Array = BiomeData.raw_rows()
	for bad: Variant in [{"lab_level": 0}, {"lab_level": 100}, {"audits": 0}, {"lab_level": 2.5}, {"moon": 1}]:
		var copy: Array = rows.duplicate(true)
		for row: Variant in copy:
			if (row as Dictionary)["id"] == "basalt_ridge":
				(row as Dictionary)["opens"] = bad
		if BiomeData.problems(copy).is_empty():
			return "opens %s was accepted" % [bad]
	var hub: Array = rows.duplicate(true)
	for row: Variant in hub:
		if (row as Dictionary)["id"] == "farm":
			(row as Dictionary)["opens"] = {"lab_level": 3}
	if BiomeData.problems(hub).is_empty():
		return "a hub that opens at level 3 was accepted"
	var missing: Array = rows.duplicate(true)
	(missing[1] as Dictionary).erase("opens")
	if BiomeData.problems(missing).is_empty():
		return "a row without opens was accepted"
	return ""


func test_lamps_are_lit_to_match_the_state() -> String:
	return _with_state(1, 0, func() -> String:
		var lamps: RoadLamps = _built()
		if lamps.is_lit(&"basalt_ridge") or lamps.is_lit(&"lab_quarter") or lamps.is_lit(&"frost_flats"):
			return "Closed biomes are lit at lab 1 with no audit"
		if not lamps.is_lit(&"badlands"):
			return "The Badlands is dark at lab 1"
		var dark: StandardMaterial3D = (lamps.get_node("Lamp_basalt_ridge_0/Head") as MeshInstance3D).material_override as StandardMaterial3D
		var warm: StandardMaterial3D = (lamps.get_node("Lamp_badlands_0/Head") as MeshInstance3D).material_override as StandardMaterial3D
		if dark == null or warm == null or dark == warm or not warm.emission_enabled or dark.emission_enabled:
			return "A lit head must glow and a dark one must not"
		return "")


func test_a_lab_xp_change_relights_without_a_reload() -> String:
	return _with_state(1, 0, func() -> String:
		var lamps: RoadLamps = _built()
		GameState.lab_xp = GameState.xp_for_level(5)
		lamps.refresh()
		if not lamps.is_lit(&"basalt_ridge") or lamps.is_lit(&"frost_flats"):
			return "Lab 5 should light the Basalt Ridge only"
		GameState.lab_xp = GameState.xp_for_level(20)
		lamps.refresh()
		if not lamps.is_lit(&"landing_field") or not lamps.is_lit(&"frost_flats"):
			return "Lab 20 should light the Frost Flats and the Landing Field"
		GameState.audit_log.append({})
		lamps.refresh()
		if not lamps.is_lit(&"lab_quarter"):
			return "The first audit should light the Lab Quarter"
		return "")


func test_a_fresh_scene_matches_the_state() -> String:
	return _with_state(18, 1, func() -> String:
		var lamps: RoadLamps = _built()
		for id: StringName in RoadLamps.lamp_ids():
			if lamps.is_lit(id) != BiomeData.is_open(id, 18, 1):
				return "%s is lit %s in a fresh scene" % [id, lamps.is_lit(id)]
		if lamps.is_lit(&"landing_field"):
			return "The Landing Field is lit at lab 18"
		return "")


func test_no_lamp_stands_where_it_must_not() -> String:
	for id: StringName in RoadLamps.lamp_ids():
		var list: Array[Vector2] = RoadLamps.spots(id)
		if list.size() < 2:
			return "%s has %d lamps, need 2" % [id, list.size()]
		for at: Vector2 in list:
			var cell := Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))
			if BiomeData.is_road_cell(cell) or BiomeData.on_road(at):
				return "%s lamp at %s is on its road" % [id, at]
			if BiomeMarkers.is_blocked_cell(cell):
				return "%s lamp at %s is on a pad or sign" % [id, at]
			for box: Vector4 in BiomeData.spots():
				if absf(at.x - box.x) < box.z and absf(at.y - box.y) < box.w:
					return "%s lamp at %s is inside the thing at %s" % [id, at, box]
			if absf(at.x) < BiomeData.PLOT_HALF_M and absf(at.y) < BiomeData.PLOT_HALF_M:
				return "%s lamp at %s is on the plot" % [id, at]
	return ""


func test_lamps_sit_on_the_ground_as_dug_leaves_it() -> String:
	var lamps: RoadLamps = _built()
	var problem: String = _settle_problem(lamps)
	_cleanup()
	return problem


func _settle_problem(lamps: RoadLamps) -> String:
	var post: Node3D = lamps.get_node("Lamp_badlands_0") as Node3D
	var at := Vector2(post.position.x, post.position.z)
	var none: Dictionary[Vector2i, int] = {}
	if not is_equal_approx(post.position.y, Terrain.height(at, none)):
		return "The lamp is off the ground"
	var cell := Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))
	var dug: Dictionary[Vector2i, int] = {cell: 1}
	lamps.settle(dug)
	if not is_equal_approx(post.position.y, Terrain.height(at, dug)):
		return "The lamp did not follow the digging"
	return ""


func test_the_sign_names_the_next_step_while_closed() -> String:
	return _with_state(1, 0, func() -> String:
		var markers: BiomeMarkers = _signs()
		var basalt: String = (markers.get_node("Sign_basalt_ridge") as Clickable).hint
		if not basalt.ends_with("\nLights up at lab level 5.") or not basalt.begins_with(BiomeData.sign_text(&"basalt_ridge")):
			return "Basalt sign: %s" % basalt
		var lab: String = (markers.get_node("Sign_lab_quarter") as Clickable).hint
		var day: int = GameState.next_audit_day(GameClock.get_day_index())
		if not lab.ends_with("\nNext: the auditor comes on morning %d." % day):
			return "Lab Quarter sign: %s" % lab
		if (markers.get_node("Sign_badlands") as Clickable).hint != BiomeData.sign_text(&"badlands"):
			return "The open Badlands sign has an extra line"
		GameState.lab_xp = GameState.xp_for_level(5)
		GameState.audit_log.append({})
		markers.refresh_hints()
		for id: StringName in [&"basalt_ridge", &"lab_quarter"]:
			if (markers.get_node("Sign_%s" % id) as Clickable).hint != BiomeData.sign_text(id):
				return "%s kept its next-step line once open" % id
		if not (markers.get_node("Sign_frost_flats") as Clickable).hint.ends_with("Lights up at lab level 18."):
			return "Frost Flats lost its line"
		return "")


func test_the_next_step_text_by_hand() -> String:
	if BiomeData.next_step_text(&"lab_quarter", 1, 0, 10) != "Next: the auditor comes on morning 10.":
		return BiomeData.next_step_text(&"lab_quarter", 1, 0, 10)
	if BiomeData.next_step_text(&"farm", 1, 0, 10) != "" or BiomeData.next_step_text(&"nowhere", 1, 0, 10) != "":
		return "The farm and an unknown id need no line"
	return ""


func test_live_lamps_follow_the_signals_with_no_manual_refresh() -> String:
	return _with_state(1, 0, func() -> String:
		var lamps := RoadLamps.new()
		_live(lamps)
		if lamps.is_lit(&"basalt_ridge") or lamps.is_lit(&"lab_quarter"):
			return "Closed lamps are lit after _ready"
		GameState.lab_xp = GameState.xp_for_level(5)
		GameState.lab_xp_changed.emit()
		if not lamps.is_lit(&"basalt_ridge"):
			return "lab_xp_changed did not light the Basalt Ridge"
		GameState.audit_log.append({})
		GameState.audit_completed.emit({})
		if not lamps.is_lit(&"lab_quarter"):
			return "audit_completed did not light the Lab Quarter"
		GameState.lab_xp = GameState.xp_for_level(1)
		GameState.audit_log.clear()
		GameState.farm_loaded.emit()
		if lamps.is_lit(&"basalt_ridge") or lamps.is_lit(&"lab_quarter"):
			return "farm_loaded did not relight from the loaded state"
		var post: Node3D = lamps.get_node("Lamp_badlands_0") as Node3D
		var at := Vector2(post.position.x, post.position.z)
		var before: float = post.position.y
		var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
		var dug: Dictionary[Vector2i, int] = {}
		var middle := Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var cell: Vector2i = middle + Vector2i(dx, dz)
				if Terrain.can_dig(cell) and not Terrain.is_near_water(cell):
					dug[cell] = 1
		GameState.dug = dug
		GameState.terrain_changed.emit()
		var dropped: float = post.position.y
		GameState.dug = saved
		GameState.terrain_changed.emit()
		if not dropped < before:
			return "terrain_changed did not lower the lamp (%s, %s)" % [before, dropped]
		if not is_equal_approx(post.position.y, before):
			return "terrain_changed did not raise the lamp back"
		return "")


func test_live_signs_follow_the_signals_with_no_manual_refresh() -> String:
	var days: float = GameClock.elapsed_days
	var result: String = _with_state(1, 0, func() -> String:
		GameClock.elapsed_days = 0.0
		var markers := BiomeMarkers.new()
		_live(markers)
		var basalt := markers.get_node("Sign_basalt_ridge") as Clickable
		var lab := markers.get_node("Sign_lab_quarter") as Clickable
		if not basalt.hint.ends_with("Lights up at lab level 5."):
			return "Basalt sign after _ready: %s" % basalt.hint
		GameState.lab_xp = GameState.xp_for_level(5)
		GameState.lab_xp_changed.emit()
		if basalt.hint != BiomeData.sign_text(&"basalt_ridge"):
			return "lab_xp_changed did not clear the Basalt sign line"
		if not lab.hint.ends_with("morning 5."):
			return "Lab Quarter sign: %s" % lab.hint
		# Emitting day_started would also run the game's own audit, so check the hookup.
		if not GameClock.day_started.is_connected(markers._on_day_started):
			return "The signs do not listen to day_started"
		GameClock.elapsed_days = 4.0
		GameClock.guest_time_shown.emit()
		if not lab.hint.ends_with("morning 10."):
			return "guest_time_shown did not move the audit morning: %s" % lab.hint
		GameClock.elapsed_days = 0.0
		GameClock.guest_time_shown.emit()
		if not lab.hint.ends_with("morning 5."):
			return "guest_time_shown did not refresh the sign: %s" % lab.hint
		GameState.audit_log.append({})
		GameState.audit_completed.emit({})
		if lab.hint != BiomeData.sign_text(&"lab_quarter"):
			return "audit_completed did not clear the Lab Quarter line"
		GameState.audit_log.clear()
		GameState.farm_loaded.emit()
		if not lab.hint.ends_with("morning 5."):
			return "farm_loaded did not refresh the sign"
		return "")
	GameClock.elapsed_days = days
	return result


func test_the_helpers_survive_odd_inputs() -> String:
	if not BiomeData.is_open(&"farm", 1, -1) or not BiomeData.is_open(&"farm", -1, -1):
		return "The farm must always be open"
	if BiomeData.next_step_text(&"farm", -1, 0, 5) != "":
		return "The farm needs no line"
	if BiomeData.next_step_text(&"lab_quarter", -1, 0, 5) != "Next: the auditor comes on morning 5.":
		return BiomeData.next_step_text(&"lab_quarter", -1, 0, 5)
	if not RoadLamps.spots(&"nowhere").is_empty() or not RoadLamps.spots(&"farm").is_empty():
		return "Lamps for an id that is not a spoke"
	return ""
