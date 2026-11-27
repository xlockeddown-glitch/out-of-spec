extends RefCounted
## The Landing Field's pad and terminal (docs/design/biomes.md section 6, step 12): a
## concrete slab with edge lights, a small gantry and a terminal post. Scene dressing
## only: no height changes, no collision. Also the terminal's panel text and
## book_shuttle's new checks (at the terminal, and no more people than are here).
## Every node a test makes is freed.

const LANDING: StringName = &"landing_field"
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"

var _nodes: Array[Node] = []


func _cleanup() -> void:
	for node: Node in _nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()


func _dressed() -> LandingDressing:
	var dressing := LandingDressing.new()
	var none: Dictionary[Vector2i, int] = {}
	dressing.build(none)
	_nodes.append(dressing)
	return dressing


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


func test_every_part_passes_the_rules_and_lies_in_the_landing_field() -> String:
	var found: Dictionary[String, Vector4] = LandingDressing.parts()
	for key: String in found:
		var part: Vector4 = found[key]
		if not LandingDressing.clear(part):
			return "The %s at (%.1f, %.1f) does not pass the clearance rules" % [key, part.x, part.y]
		for corner: Vector2 in [Vector2(part.x - part.z, part.y - part.w), Vector2(part.x + part.z, part.y + part.w)]:
			if BiomeData.biome_at(corner) != LANDING:
				return "The %s has a corner at %s outside the Landing Field" % [key, corner]
	if not LandingDressing.parts_apart():
		return "Two of the parts overlap"
	return ""


func test_no_part_is_on_a_road_the_sign_the_pad_or_an_entrance() -> String:
	var pad: Vector2 = BiomeData.marker(LANDING)
	var found: Dictionary[String, Vector4] = LandingDressing.parts()
	for key: String in found:
		var part: Vector4 = found[key]
		var at := Vector2(part.x, part.y)
		var first: Vector2i = Terrain.cell_at(at - Vector2(part.z, part.w))
		var last: Vector2i = Terrain.cell_at(at + Vector2(part.z, part.w))
		for x: int in range(first.x, last.x + 1):
			for z: int in range(first.y, last.y + 1):
				if BiomeData.is_road_cell(Vector2i(x, z)) or BiomeMarkers.is_blocked_cell(Vector2i(x, z)):
					return "The %s covers the road or a marker at cell (%d, %d)" % [key, x, z]
		if BiomeData.road_gap(at) <= BiomeData.ROAD_HALF_M + maxf(part.z, part.w):
			return "The %s touches the road" % key
		# The marker's pad is 4 m square and its sign stands to its east.
		if absf(at.x - pad.x) < part.z + BiomeData.PAD_HALF_M + 3.5 and absf(at.y - pad.y) < part.w + BiomeData.PAD_HALF_M:
			return "The %s is on the marker pad or its sign" % key
		for id: StringName in BiomeData.ids():
			for zone: StringName in BiomeData.zones(id):
				var way: Variant = BiomeData.entrance_at(id, zone)
				if way is Vector2 and at.distance_to(way as Vector2) < 4.0 + maxf(part.z, part.w):
					return "The %s is at an entrance" % key
	return ""


func test_the_clearance_rules_refuse_the_road_the_sign_the_plot_and_the_edge() -> String:
	var pad: Vector2 = BiomeData.marker(LANDING)
	if LandingDressing.clear(Vector4(0.0, 60.0, 2.0, 2.0)):
		return "A slab was allowed on the road"
	if LandingDressing.clear(Vector4(pad.x + 2.7, pad.y, 0.5, 0.5)):
		return "A part was allowed on the sign"
	if LandingDressing.clear(Vector4(0.0, 0.0, 1.0, 1.0)):
		return "A part was allowed on the plot"
	if LandingDressing.clear(Vector4(0.0, 400.0, 1.0, 1.0)):
		return "A part was allowed off the land"
	return ""


func test_the_slab_sits_level_over_its_footprint() -> String:
	var dressing: LandingDressing = _dressed()
	var none: Dictionary[Vector2i, int] = {}
	var slab: Vector4 = LandingDressing.parts()["slab"]
	var top: float = dressing.slab_top_now()
	var result: String = ""
	if absf(top - LandingDressing.slab_top(none)) > 0.001:
		result = "The slab's top %.3f is not where it should be, %.3f" % [top, LandingDressing.slab_top(none)]
	# Ground over the footprint stays at or under the top, and no further under it
	# than the slab is thick, so no edge hangs in the air and none is buried.
	var worst_under: float = 0.0
	for i: int in range(0, 9):
		for j: int in range(0, 9):
			var at := Vector2(slab.x - slab.z + slab.z * 2.0 * float(i) / 8.0, slab.y - slab.w + slab.w * 2.0 * float(j) / 8.0)
			var ground: float = Terrain.height(at, none)
			if result == "" and ground > top + 0.001:
				result = "Ground at %s (%.2f) pokes through the slab top (%.2f)" % [at, ground, top]
			worst_under = maxf(worst_under, top - ground)
	if result == "" and worst_under > LandingDressing.SLAB_THICKNESS_M - 0.05:
		result = "The ground falls %.2f m under the slab top, more than the slab is thick" % worst_under
	_cleanup()
	return result


func test_the_slab_follows_digging_and_hides_under_stone() -> String:
	var slab: Vector4 = LandingDressing.parts()["slab"]
	var dressing: LandingDressing = _dressed()
	var before: float = dressing.slab_top_now()
	var dug: Dictionary[Vector2i, int] = {}
	var centre: Vector2i = Terrain.cell_at(Vector2(slab.x, slab.y))
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			dug[centre + Vector2i(x, z)] = 3
	dressing.settle(dug)
	var after: float = dressing.slab_top_now()
	var result: String = ""
	if absf(after - before) > 0.5:
		result = "The slab jumped %.2f m for a dug middle: it should stay on the highest ground" % (after - before)
	var pieces: Dictionary[Vector2i, int] = {centre: 1}
	dressing.cover(pieces)
	if result == "" and (dressing.shown()["slab"] or not dressing.shown()["terminal"]):
		result = "Stone on the slab should hide the slab only"
	var empty: Dictionary[Vector2i, int] = {}
	dressing.cover(empty)
	if result == "" and not dressing.shown()["slab"]:
		result = "The slab stayed hidden after the stone went"
	_cleanup()
	return result


func test_pad_lights_are_dark_below_lab_20_and_lit_at_20() -> String:
	return _with_state(19, 0, func() -> String:
		var dressing: LandingDressing = _dressed()
		if dressing.is_lit() or dressing.light_count() < 4:
			return "The pad's lights are lit at lab 19, or there are too few (%d)" % dressing.light_count()
		var dark: StandardMaterial3D = (dressing.get_node("EdgeLight_0") as MeshInstance3D).material_override as StandardMaterial3D
		GameState.lab_xp = GameState.xp_for_level(20)
		dressing.refresh()
		var warm: StandardMaterial3D = (dressing.get_node("EdgeLight_0") as MeshInstance3D).material_override as StandardMaterial3D
		if not dressing.is_lit() or dark == null or warm == null or dark == warm or not warm.emission_enabled or dark.emission_enabled:
			return "The pad's lights did not light and glow at lab 20"
		if not dressing.find_children("*", "OmniLight3D", true, false).is_empty():
			return "The pad has a real light"
		return "")


func test_the_terminal_is_a_clickable_on_layer_8() -> String:
	var dressing: LandingDressing = _dressed()
	var click: Clickable = dressing.terminal_click
	var result: String = ""
	var at_it := Vector3(LandingDressing.TERMINAL_AT.x, 1.0, LandingDressing.TERMINAL_AT.y)
	if click == null or click.collision_layer != 8 or click.hint == "":
		result = "The terminal needs a Clickable on layer 8 with a hint"
	elif not LandingDressing.terminal_near(at_it) or LandingDressing.terminal_near(Vector3(0.0, 1.0, 40.0)) or LandingDressing.terminal_near(null):
		result = "terminal_near is wrong at the terminal, far away or with no position"
	_cleanup()
	return result


func test_the_dressing_has_no_collision_but_the_clickable() -> String:
	var dressing: LandingDressing = _dressed()
	var result: String = ""
	for node: Node in dressing.find_children("*", "CollisionObject3D", true, false):
		if node != dressing.terminal_click:
			result = "%s collides; the pad and gantry are scenery" % node.name
	_cleanup()
	return result


# --- The terminal's panel text -----------------------------------------------------

func test_the_panel_lines_show_both_moons_and_the_license_in_both_states() -> String:
	var problems: Array[String] = []
	var day: float = 0.5
	for licensed: bool in [false, true]:
		var text: String = "\n".join(ShuttleUI.lines(day, licensed))
		for moon: String in Shuttle.MOONS:
			if not text.contains(Shuttle.window_line(moon, day)):
				problems.append("No window line for %s (licensed %s)" % [moon, licensed])
		if not text.contains(SP811.integer(Shuttle.fare())):
			problems.append("The fare is missing")
		var want: String = Shuttle.text("terminal_licensed") if licensed else "Pass Vance's exam at the bench to get a license."
		if not text.contains(want):
			problems.append("The license line '%s' is missing (licensed %s)" % [want, licensed])
	return "\n".join(problems)


func test_the_panel_has_a_book_button_for_each_moon() -> String:
	var ui := ShuttleUI.new()
	_nodes.append(ui)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(ui)
	var problems: Array[String] = []
	for moon: String in Shuttle.MOONS:
		if ui.find_child("Book_" + moon, true, false) == null:
			problems.append("No Book button for %s" % moon)
	if ui.visible:
		problems.append("The panel starts hidden")
	_cleanup()
	return "\n".join(problems)


# --- book_shuttle: where and how many ----------------------------------------------

func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(515151)
	gs.local_player_id = HOST
	gs.credits = 500
	gs.shuttle_licensed = true
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 3.0 / 24.0
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


func test_a_guest_far_from_the_terminal_is_told_to_walk_there() -> String:
	var gs: GameStateScript = _state()
	var commands: Node = CommandsScript.new()
	commands.state = gs
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 30.0))
	var told: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.PHOBOS, 1])
	var charged: int = 500 - gs.credits
	commands.free()
	_done(gs)
	if told != Shuttle.text("far_text") or charged != 0:
		return "A far guest got '%s' and paid %d CR" % [told, charged]
	return ""


func test_more_people_than_are_present_is_refused() -> String:
	var gs: GameStateScript = _state()
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(LandingDressing.TERMINAL_AT.x, 0.5, LandingDressing.TERMINAL_AT.y))
	var here: int = gs.players_present().size()
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, here + 1)
	var charged: int = 500 - gs.credits
	_done(gs)
	if told != Shuttle.text("crowd_text") % SP811.integer(here) or charged != 0:
		return "A party of %d for %d here got '%s' and paid %d CR" % [here + 1, here, told, charged]
	return ""


func test_a_guest_at_the_terminal_gets_the_hub_refusal_and_pays_nothing() -> String:
	var gs: GameStateScript = _state()
	var commands: Node = CommandsScript.new()
	commands.state = gs
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(LandingDressing.TERMINAL_AT.x, 0.5, LandingDressing.TERMINAL_AT.y))
	var told: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.PHOBOS, 1])
	var charged: int = 500 - gs.credits
	commands.free()
	_done(gs)
	if told != Shuttle.text("no_hub_text") % "Phobos" or charged != 0:
		return "A guest at the terminal got '%s' and paid %d CR" % [told, charged]
	return ""


func test_book_shuttle_is_a_command_a_walker_may_send() -> String:
	if not &"book_shuttle" in CoopWalkers.ON_FOOT:
		return "book_shuttle must be allowed on foot"
	return ""
