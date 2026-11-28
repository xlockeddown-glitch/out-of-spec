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
	# The road runs up to z 85 at the sign, inside the field (reach 30 round z 100).
	if BiomeData.biome_at(Vector2(0.0, 78.0)) != LANDING or LandingDressing.clear(Vector4(0.0, 78.0, 2.0, 2.0)):
		return "A slab was allowed on the road inside the field"
	if LandingDressing.clear(Vector4(pad.x + 2.7, pad.y, 0.5, 0.5)):
		return "A part was allowed on the sign"
	# The plot lies 100 m from the field, so only the field rule can refuse it there.
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


func _cells_under(part: Vector4, depth: int) -> Dictionary[Vector2i, int]:
	var dug: Dictionary[Vector2i, int] = {}
	var first: Vector2i = Terrain.cell_at(Vector2(part.x - part.z, part.y - part.w))
	var last: Vector2i = Terrain.cell_at(Vector2(part.x + part.z, part.y + part.w))
	for x: int in range(first.x - 1, last.x + 2):
		for z: int in range(first.y - 1, last.y + 2):
			dug[Vector2i(x, z)] = depth
	return dug


func _top_of(post: MeshInstance3D) -> float:
	return post.position.y + (post.mesh as BoxMesh).size.y * 0.5


func _bottom_of(post: MeshInstance3D) -> float:
	return post.position.y - (post.mesh as BoxMesh).size.y * 0.5


func test_the_slab_follows_digging() -> String:
	var found: Dictionary[String, Vector4] = LandingDressing.parts()
	var dressing: LandingDressing = _dressed()
	var before: float = dressing.slab_top_now()
	var dug: Dictionary[Vector2i, int] = _cells_under(found["slab"], 3)
	dressing.settle(dug)
	var after: float = dressing.slab_top_now()
	var result: String = ""
	if not after < before - 0.5:
		result = "The slab did not follow the digging down (%.2f to %.2f)" % [before, after]
	elif absf(after - LandingDressing.slab_top(dug)) > 0.001:
		result = "The slab's top is not over the highest ground left"
	else:
		# Dug under only one corner's cell, the slab reaches the new low.
		var corner: Dictionary[Vector2i, int] = {Terrain.cell_at(Vector2(found["slab"].x - 3.9, found["slab"].y - 3.9)): 3}
		dressing.settle(corner)
		var slab: MeshInstance3D = dressing.get_node("Slab") as MeshInstance3D
		var low: float = LandingDressing.lowest_under(found["slab"], corner)
		if _bottom_of(slab) > low + 0.001:
			result = "The slab hangs over the dug corner (bottom %.2f, ground %.2f)" % [_bottom_of(slab), low]
		elif absf(dressing.slab_top_now() - LandingDressing.slab_top(corner)) > 0.001:
			result = "A dug corner moved the slab's top"
	_cleanup()
	return result


func test_posts_keep_their_tops_and_reach_the_dug_ground() -> String:
	var found: Dictionary[String, Vector4] = LandingDressing.parts()
	var dressing: LandingDressing = _dressed()
	var west: MeshInstance3D = dressing.get_node("Gantry/Post_west") as MeshInstance3D
	var east: MeshInstance3D = dressing.get_node("Gantry/Post_east") as MeshInstance3D
	var terminal: MeshInstance3D = dressing.get_node("Terminal").get_child(0) as MeshInstance3D
	var top_before: float = _top_of(west)
	var terminal_top: float = _top_of(terminal)
	var dug: Dictionary[Vector2i, int] = _cells_under(found["gantry_west"], 3)
	for cell: Vector2i in _cells_under(found["terminal"], 3):
		dug[cell] = 3
	dressing.settle(dug)
	var result: String = ""
	if absf(_top_of(west) - top_before) > 0.001 or absf(_top_of(east) - top_before) > 0.001:
		result = "A dug post moved the gantry's top (%.2f to %.2f)" % [top_before, _top_of(west)]
	elif _bottom_of(west) > LandingDressing.lowest_under(found["gantry_west"], dug) + 0.001:
		result = "The west post hangs over its dug ground"
	elif _bottom_of(terminal) > LandingDressing.lowest_under(found["terminal"], dug) + 0.001 or _top_of(terminal) < LandingDressing.highest_under(found["terminal"], dug) + 1.0:
		result = "The terminal post hangs or lost its height (top %.2f, was %.2f)" % [_top_of(terminal), terminal_top]
	_cleanup()
	return result


func test_a_post_reaches_one_dug_cell_under_its_middle() -> String:
	# One 2 m cell dug under the west post's middle: a post under 1 m wide must
	# still find that low ground, not only its corners' (review round 2).
	var dressing: LandingDressing = _dressed()
	var west: MeshInstance3D = dressing.get_node("Gantry/Post_west") as MeshInstance3D
	var middle := Vector2(-LandingDressing.GANTRY_X_M, LandingDressing.GANTRY_Z_M)
	var dug: Dictionary[Vector2i, int] = {Terrain.cell_at(middle): 3}
	dressing.settle(dug)
	var result: String = ""
	if _bottom_of(west) > Terrain.height(middle, dug) + 0.001:
		result = "The west post's foot %.2f hangs over the dug ground under its middle, %.2f" % [_bottom_of(west), Terrain.height(middle, dug)]
	_cleanup()
	return result


func test_stone_hides_the_parts_and_the_terminal_stops_being_clickable() -> String:
	var found: Dictionary[String, Vector4] = LandingDressing.parts()
	var dressing: LandingDressing = _dressed()
	var slab_cell: Vector2i = Terrain.cell_at(Vector2(found["slab"].x, found["slab"].y))
	var pieces: Dictionary[Vector2i, int] = {slab_cell: 1}
	dressing.cover(pieces)
	var result: String = ""
	if dressing.shown()["slab"] or not dressing.shown()["terminal"]:
		result = "Stone on the slab should hide the slab only"
	var post_cell: Vector2i = Terrain.cell_at(Vector2(found["gantry_east"].x, found["gantry_east"].y))
	var post_only: Dictionary[Vector2i, int] = {post_cell: 1}
	dressing.cover(post_only)
	if result == "" and (not dressing.shown()["slab"] or dressing.shown()["gantry"]):
		result = "Stone on a gantry post's cell should hide the gantry and leave the slab"
	var on_terminal: Dictionary[Vector2i, int] = {Terrain.cell_at(Vector2(found["terminal"].x, found["terminal"].y)): 1}
	Clickable.hovered = dressing.terminal_click
	dressing.cover(on_terminal)
	if result == "" and (dressing.shown()["terminal"] or dressing.terminal_click.enabled or Clickable.hovered == dressing.terminal_click):
		result = "A terminal under stone is still clickable or hovered"
	var empty: Dictionary[Vector2i, int] = {}
	dressing.cover(empty)
	if result == "" and (not dressing.shown()["terminal"] or not dressing.terminal_click.enabled):
		result = "The terminal did not come back after the stone went"
	Clickable.hovered = null
	_cleanup()
	return result


func test_the_live_dressing_follows_its_signals() -> String:
	var found: Dictionary[String, Vector4] = LandingDressing.parts()
	var xp: int = GameState.lab_xp
	var saved_dug: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	var saved_stone: Dictionary[Vector2i, int] = GameState.stone_pieces.duplicate()
	GameState.lab_xp = GameState.xp_for_level(19)
	var dressing := LandingDressing.new()
	_nodes.append(dressing)
	(Engine.get_main_loop() as SceneTree).root.add_child(dressing)
	var result: String = ""
	var dark: bool = not dressing.is_lit()
	GameState.lab_xp = GameState.xp_for_level(20)
	GameState.lab_xp_changed.emit()
	var lit: bool = dressing.is_lit()
	var before: float = dressing.slab_top_now()
	GameState.dug = _cells_under(found["slab"], 3)
	GameState.terrain_changed.emit()
	var dropped: float = dressing.slab_top_now()
	GameState.dug = saved_dug
	GameState.terrain_changed.emit()
	var back: float = dressing.slab_top_now()
	GameState.stone_pieces = {Terrain.cell_at(Vector2(found["slab"].x, found["slab"].y)): 1}
	GameState.stone_changed.emit()
	var hidden: bool = not dressing.shown()["slab"]
	GameState.stone_pieces = saved_stone
	GameState.stone_changed.emit()
	var shown_again: bool = dressing.shown()["slab"]
	GameState.lab_xp = xp
	if not dark or not lit:
		result = "The lights did not follow lab_xp_changed (dark %s, lit %s)" % [dark, lit]
	elif not dropped < before - 0.5 or not is_equal_approx(back, before):
		result = "The slab did not follow terrain_changed (%.2f, %.2f, %.2f)" % [before, dropped, back]
	elif not hidden or not shown_again:
		result = "The slab did not follow stone_changed"
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
	var at_it := Vector3(Shuttle.TERMINAL_AT.x, 1.0, Shuttle.TERMINAL_AT.y)
	if click == null or click.collision_layer != 8 or click.hint == "":
		result = "The terminal needs a Clickable on layer 8 with a hint"
	elif not Shuttle.terminal_near(at_it) or Shuttle.terminal_near(Vector3(0.0, 1.0, 40.0)) or Shuttle.terminal_near(null):
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


func test_the_panel_opens_shows_the_refusal_follows_the_license_and_closes() -> String:
	var ui := ShuttleUI.new()
	_nodes.append(ui)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(ui)
	var problems: Array[String] = []
	var licensed: bool = GameState.shuttle_licensed
	GameState.shuttle_licensed = false
	ui.open()
	if not ui.visible:
		problems.append("open() did not show the panel")
	if not _all_text(ui).contains(Shuttle.text("terminal_unlicensed")):
		problems.append("The unlicensed line is missing")
	GameState.shuttle_licensed = true
	GameState.shuttle_license_changed.emit()
	if not _all_text(ui).contains(Shuttle.text("terminal_licensed")):
		problems.append("The open panel kept a stale license line")
	ui.close()
	if ui.visible:
		problems.append("close() did not hide the panel")
	GameState.shuttle_licensed = licensed
	_cleanup()
	return "\n".join(problems)


func _all_text(node: Node) -> String:
	var text: String = ""
	for label: Node in node.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


## A booking pressed in the panel shows what the host answered (the host here is
## this process: far from the terminal the answer is the walk reason).
func test_a_booking_in_the_panel_shows_the_reason() -> String:
	var ui := ShuttleUI.new()
	_nodes.append(ui)
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.open()
	var status: Label = ui.find_child("Status", true, false) as Label
	await ui._on_book(Shuttle.PHOBOS)
	var shown: String = status.text
	_cleanup()
	if shown == "":
		return "A refused booking showed no reason in the panel"
	return ""


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
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	var here: int = gs.players_present().size()
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, here + 1)
	var charged: int = 500 - gs.credits
	_done(gs)
	if told != Shuttle.text("crowd_text") % SP811.integer(here) or charged != 0:
		return "A party of %d for %d here got '%s' and paid %d CR" % [here + 1, here, told, charged]
	return ""


func test_a_guest_at_the_terminal_books_deimos_and_pays_one_fare() -> String:
	var gs: GameStateScript = _state()
	var commands: Node = CommandsScript.new()
	commands.state = gs
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	CoopWalkers.stand(HOST, Vector3(0.0, 0.0, 30.0))  # the host is off at the farm, not in the party
	var told: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.DEIMOS, 1])
	var charged: int = 500 - gs.credits
	CoopWalkers.out.erase(HOST)
	commands.free()
	_done(gs)
	if told != "" or charged != Shuttle.fare():
		return "A guest at the terminal books Deimos and pays one fare: got '%s' and paid %d CR" % [told, charged]
	return ""


func test_book_shuttle_is_a_command_a_walker_may_send() -> String:
	if not &"book_shuttle" in CoopWalkers.ON_FOOT:
		return "book_shuttle must be allowed on foot"
	return ""


# --- A walker's own position counts, not the rover's ---------------------------------

func _walk_to(player_id: String, at: Vector3) -> void:
	CoopWalkers.out[player_id] = [at.x, at.y, at.z, 0.0, 0.0]


func _rover_at(gs: GameStateScript, at: Vector3) -> void:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, at)


func test_a_walker_at_the_terminal_may_book_with_the_rover_far_away() -> String:
	var gs: GameStateScript = _state()
	_rover_at(gs, Vector3(0.0, 0.5, 20.0))
	_walk_to(GUEST, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	var stand: Variant = gs.standing_at(GUEST)
	var told: String = gs.book_shuttle(Shuttle.DEIMOS, 1, GUEST)
	var rover_rider: String = gs.book_shuttle(Shuttle.DEIMOS, 1, HOST)
	CoopWalkers.out.erase(GUEST)
	var charged: int = 500 - gs.credits
	_done(gs)
	if not stand is Vector3 or not Shuttle.terminal_near(stand):
		return "A walker's position is not where they walk to"
	if told != "" or charged != Shuttle.fare():
		return "A walker at the terminal books Deimos, one fare: got '%s' and paid %d CR" % [told, charged]
	if rover_rider != Shuttle.text("far_text"):
		return "The one in the far rover got '%s', not the walk reason" % rover_rider
	return ""


func test_a_walker_far_from_the_terminal_is_refused_with_the_rover_beside_it() -> String:
	var gs: GameStateScript = _state()
	_rover_at(gs, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	_walk_to(GUEST, Vector3(0.0, 0.5, 20.0))
	var told: String = gs.book_shuttle(Shuttle.DEIMOS, 1, GUEST)
	var charged: int = 500 - gs.credits
	var rider: String = gs.book_shuttle(Shuttle.DEIMOS, 1, HOST)
	CoopWalkers.out.erase(GUEST)
	_done(gs)
	if told != Shuttle.text("far_text") or charged != 0:
		return "A far walker got '%s' (%d CR) with the rover at the terminal" % [told, charged]
	if rider != "":
		return "The one in the rover at the terminal books Deimos: got '%s'" % rider
	return ""


func test_the_host_allows_a_little_more_than_the_reach_and_no_more() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var edge: float = Shuttle.REACH_M + Shuttle.HOST_SLACK_M
	for case: Array in [[Shuttle.REACH_M, true, false], [Shuttle.REACH_M + 0.01, false, true], [edge, false, true], [edge + 0.01, false, false]]:
		var apart: float = case[0]
		_walk_to(GUEST, Vector3(Shuttle.TERMINAL_AT.x - apart, 0.5, Shuttle.TERMINAL_AT.y))
		var near: bool = Shuttle.terminal_near(gs.standing_at(GUEST))
		var booked_past: bool = gs.book_shuttle(Shuttle.PHOBOS, 1, GUEST) != Shuttle.text("far_text")
		if booked_past != (case[1] or case[2]):
			problems.append("%.2f m: the host's answer is wrong (allowed %s)" % [apart, booked_past])
		if near != case[1]:
			problems.append("%.2f m: terminal_near is wrong (%s)" % [apart, near])
		gs.shuttle_trips.erase(GUEST)  # a booking that went through is over: back on the farm
		gs.player_places.erase(GUEST)
	CoopWalkers.out.erase(GUEST)
	_done(gs)
	return "\n".join(problems)
