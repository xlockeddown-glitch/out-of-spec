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


func test_cells_under_a_pad_are_refused_and_the_next_ones_are_not() -> String:
	var none: Dictionary[Vector2i, int] = {}
	var h: float = BiomeData.PAD_HALF_M
	for id: StringName in BiomeMarkers.spoke_ids():
		var at: Vector2 = BiomeData.marker(id)
		for corner: Vector2 in [Vector2(-h, -h), Vector2(h - 0.01, -h), Vector2(-h, h - 0.01), Vector2(h - 0.01, h - 0.01), Vector2.ZERO]:
			var cell: Vector2i = _cell_at(at + corner)
			if not BiomeMarkers.is_blocked_cell(cell):
				return "%s: pad cell %s is not blocked" % [id, cell]
			if Terrain.dig_problem(cell, none) == "":
				return "%s: pad cell %s can be dug" % [id, cell]
		for beside: Vector2 in [Vector2(-h - 2.01, 0.0), Vector2(0.0, -h - 2.01), Vector2(0.0, h + 2.01)]:
			var cell: Vector2i = _cell_at(at + beside)
			if BiomeMarkers.is_blocked_cell(cell):
				return "%s: the cell %s beside the pad is blocked" % [id, cell]
			if Terrain.dig_problem(cell, none) == BiomeMarkers.BLOCKED_TEXT:
				return "%s: the cell %s beside the pad gets the pad's refusal" % [id, cell]
	return ""


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
