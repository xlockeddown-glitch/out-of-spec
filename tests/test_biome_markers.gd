extends RefCounted
## The biome signs and rover pads (docs/design/biomes.md section 6, step 6): one
## of each at every spoke biome's marker, the farm hub has none, the hover text is
## the sign line, and the land under a pad can not be dug (an old save with digging
## there still loads).


func _built() -> BiomeMarkers:
	var markers := BiomeMarkers.new()
	var none: Dictionary[Vector2i, int] = {}
	markers.build(none)
	return markers


func _cell_at(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))


func test_each_spoke_biome_has_one_sign_and_one_pad_at_its_marker() -> String:
	var markers: BiomeMarkers = _built()
	var spokes: Array[StringName] = BiomeMarkers.spoke_ids()
	if spokes.size() != 5:
		return "Expected 5 spoke biomes, got %d" % spokes.size()
	if markers.get_child_count() != spokes.size() * 2:
		return "Expected %d children, got %d" % [spokes.size() * 2, markers.get_child_count()]
	for id: StringName in spokes:
		var pad: Node3D = markers.get_node_or_null("Pad_%s" % id) as Node3D
		var post: Clickable = markers.get_node_or_null("Sign_%s" % id) as Clickable
		if pad == null or post == null:
			return "%s lacks a pad or a sign" % id
		var at: Vector2 = BiomeData.marker(id)
		if not is_equal_approx(pad.position.x, at.x) or not is_equal_approx(pad.position.z, at.y):
			return "%s's pad is not at its marker" % id
		if absf(post.position.x - at.x) > BiomeData.PAD_HALF_M + 1.5 or absf(post.position.z - at.y) > BiomeData.PAD_HALF_M:
			return "%s's sign is not beside its pad" % id
		if post.hint != BiomeData.sign_text(id) or post.hint.is_empty():
			return "%s's sign hint is '%s'" % [id, post.hint]
	markers.free()
	return ""


func test_the_farm_hub_has_no_sign_or_pad() -> String:
	var markers: BiomeMarkers = _built()
	var found: bool = markers.get_node_or_null("Pad_farm") != null or markers.get_node_or_null("Sign_farm") != null
	markers.free()
	return "The farm has a marker prop" if found else ""


func test_the_pad_and_sign_cells_are_refused_and_every_cell_just_outside_is_not() -> String:
	var none: Dictionary[Vector2i, int] = {}
	var h: float = BiomeData.PAD_HALF_M
	for id: StringName in BiomeMarkers.spoke_ids():
		var at: Vector2 = BiomeData.marker(id)
		var pad_low: Vector2i = _cell_at(at - Vector2(h, h))
		var pad_high: Vector2i = _cell_at(at + Vector2(h, h) - Vector2(0.001, 0.001))
		var sign_at := Vector2(at.x + BiomeMarkers.SIGN_OFFSET_M, at.y)
		var sign_half := Vector2(BiomeMarkers.BOARD_SIZE.x, BiomeMarkers.SIGN_DEPTH_M) * 0.5
		var sign_low: Vector2i = _cell_at(sign_at - sign_half)
		var sign_high: Vector2i = _cell_at(sign_at + sign_half - Vector2(0.001, 0.001))
		var inside: Dictionary[Vector2i, bool] = {}
		for box: Array in [[pad_low, pad_high], [sign_low, sign_high]]:
			for x: int in range((box[0] as Vector2i).x, (box[1] as Vector2i).x + 1):
				for z: int in range((box[0] as Vector2i).y, (box[1] as Vector2i).y + 1):
					inside[Vector2i(x, z)] = true
		if not inside.has(_cell_at(sign_at)):
			return "%s: the sign's own cell is not in the box" % id
		for cell: Vector2i in inside:
			if not BiomeMarkers.is_blocked_cell(cell):
				return "%s: cell %s under the pad or sign is not blocked" % [id, cell]
			if Terrain.dig_problem(cell, none) == "":
				return "%s: cell %s under the pad or sign can be dug" % [id, cell]
		# Every cell touching the blocked ones, on all four sides and the corners.
		for cell: Vector2i in inside:
			for near: Vector2i in Terrain.neighbors(cell):
				if inside.has(near):
					continue
				if BiomeMarkers.is_blocked_cell(near):
					return "%s: the cell %s just outside is blocked" % [id, near]
				if Terrain.dig_problem(near, none) == BiomeMarkers.BLOCKED_TEXT:
					return "%s: the cell %s just outside gets the pad's refusal" % [id, near]
	return ""


func test_the_sign_stands_on_the_ground_with_a_collider_on_the_interactable_layer() -> String:
	var markers: BiomeMarkers = _built()
	var none: Dictionary[Vector2i, int] = {}
	for id: StringName in BiomeMarkers.spoke_ids():
		var post: Clickable = markers.get_node("Sign_%s" % id) as Clickable
		if post.collision_layer != 8 or post.collision_mask != 0:
			return "%s: the sign's layer is %d" % [id, post.collision_layer]
		var shapes: int = 0
		for child: Node in post.get_children():
			if child is CollisionShape3D:
				shapes += 1
		if shapes != 1:
			return "%s: the sign has %d colliders" % [id, shapes]
		var ground: float = Terrain.height(Vector2(post.position.x, post.position.z), none)
		if not is_equal_approx(post.position.y, ground):
			return "%s: the sign is at y %f, the ground %f" % [id, post.position.y, ground]
	markers.free()
	return ""


func test_a_stone_piece_cannot_be_built_on_a_pad_but_an_old_save_with_one_loads() -> String:
	var none: Dictionary[Vector2i, int] = {}
	var no_rovers: Array[Transform3D] = []
	var pieces: Dictionary[Vector2i, int] = {}
	for id: StringName in BiomeMarkers.spoke_ids():
		var cell: Vector2i = _cell_at(BiomeData.marker(id))
		if not Terrain.can_dig(cell):
			continue
		var why: String = StonePieces.problem(cell, StonePieces.WALL, pieces, no_rovers, none)
		if why != BiomeMarkers.BLOCKED_TEXT:
			return "%s: a wall on the pad says '%s'" % [id, why]
		var old: Dictionary = {cell: StonePieces.WALL}
		if StonePieces.pieces_problem(old) != "":
			return "%s: an old piece on the pad is refused: %s" % [id, StonePieces.pieces_problem(old)]
	return ""


func test_digging_a_pad_through_the_game_refuses_but_a_pocket_digs_once() -> String:
	var gs: Node = load("res://scripts/autoload/GameState.gd").new()
	gs.build_registry()
	gs.set_world_seed(424242)
	var pocket := Vector3i(33, 0, 9)
	if not gs.is_live_pocket(Vector2i(33, 9)):
		return "Seed 424242 has no pocket at (33, 9)"
	var out: String = gs.dig(pocket)
	if out != "" or gs.dug.get(Vector2i(33, 9), 0) != 1:
		return "The pocket under the pad did not dig once: '%s'" % out
	if gs.dig(pocket) != BiomeMarkers.BLOCKED_TEXT:
		return "A second dig on the pocket's cell was not refused"
	if gs.fill(pocket) != "" or gs.dig(pocket) != BiomeMarkers.BLOCKED_TEXT:
		return "After a fill the cell was dug again"
	var plain: String = gs.dig(Vector3i(34, 0, 10))
	gs.free()
	return "" if plain == BiomeMarkers.BLOCKED_TEXT else "An ordinary pad cell said '%s'" % plain


func test_an_old_save_with_digging_under_a_pad_still_loads() -> String:
	for id: StringName in BiomeMarkers.spoke_ids():
		var cell: Vector2i = _cell_at(BiomeData.marker(id))
		if not Terrain.can_dig(cell):
			continue
		var dug: Dictionary = {cell: 1}
		var problem: String = Terrain.dug_problem(dug)
		if problem != "":
			return "%s: a dug cell under the pad is refused on load: %s" % [id, problem]
	return ""
