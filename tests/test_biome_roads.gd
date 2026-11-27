extends RefCounted
## Roads out of the farm (docs/design/biomes.md section 6, step 8): a painted strip
## from the farm's level circle to each biome's pad. Paint only: no height changes,
## and the land hashes (test_hills, test_land_240) stay as they are. No digging or
## stone on a road, but an old save with a dug road cell still loads.

const WITH_ROAD: Array[StringName] = [&"lab_quarter", &"badlands", &"frost_flats", &"landing_field"]


func _cell_at(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))


func _ground() -> TerrainGround:
	var ground := TerrainGround.new()
	ground._ready()
	return ground


func _distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Points along a road, about a metre apart.
func _along(id: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var line: Array[Vector2] = BiomeData.road(id)
	for i: int in range(line.size() - 1):
		var steps: int = ceili(line[i].distance_to(line[i + 1]))
		for k: int in steps + 1:
			out.append(line[i].lerp(line[i + 1], float(k) / steps))
	return out


## A point on the first stretch of a road, and one 5 m to the side of it.
func _on_and_off(id: StringName) -> Array[Vector2i]:
	var line: Array[Vector2] = BiomeData.road(id)
	var mid: Vector2 = line[0].lerp(line[1], 0.5)
	var off: Vector2 = mid + (line[1] - line[0]).orthogonal().normalized() * 5.0
	return [Vector2i(mid.round()), Vector2i(off.round())]


func test_every_spoke_but_the_basalt_ridge_has_a_road_that_runs_farm_to_pad() -> String:
	for id: StringName in WITH_ROAD:
		var line: Array[Vector2] = BiomeData.road(id)
		if line.size() < 2:
			return "%s has no road" % id
		var start_gap: float = absf(line[0].length() - Terrain.FARM_LEVEL_M)
		if start_gap > 2.0:
			return "%s: the road starts %.1f m from the farm's level circle" % [id, start_gap]
		var at: Vector2 = BiomeData.marker(id)
		var end: Vector2 = line[line.size() - 1]
		if maxf(absf(end.x - at.x), absf(end.y - at.y)) > BiomeData.PAD_HALF_M + 0.5:
			return "%s: the road ends at %s, not at its pad %s" % [id, end, at]
	if not BiomeData.road(&"basalt_ridge").is_empty() or not BiomeData.road(&"farm").is_empty():
		return "The farm and the Basalt Ridge (its marker is at the farm's edge) have no road"
	var edge: float = absf(BiomeData.marker(&"basalt_ridge").length() - Terrain.FARM_LEVEL_M)
	return "" if edge <= 2.0 + BiomeData.PAD_HALF_M * 1.5 else "The Basalt Ridge marker is %.1f m from the farm's edge" % edge


func test_roads_keep_off_the_plot_the_props_the_rocks_and_the_fissures() -> String:
	for line: String in BiomeData.problems(BiomeData.raw_rows()):
		if "road" in line:
			return line
	# The same check from the other side: no sample of a road is within the strip of a thing.
	for id: StringName in WITH_ROAD:
		for at: Vector2 in _along(id):
			for spot: Vector4 in BiomeData.spots():
				var dx: float = maxf(absf(at.x - spot.x) - spot.z, 0.0)
				var dz: float = maxf(absf(at.y - spot.y) - spot.w, 0.0)
				if dx * dx + dz * dz < BiomeData.ROAD_HALF_M * BiomeData.ROAD_HALF_M:
					return "%s: the road at %s touches the thing at (%s, %s)" % [id, at, spot.x, spot.y]
			if absf(at.x) < BiomeData.PLOT_HALF_M + BiomeData.ROAD_HALF_M and absf(at.y) < BiomeData.PLOT_HALF_M + BiomeData.ROAD_HALF_M:
				return "%s: the road at %s is on the plot" % [id, at]
	return ""


func test_a_bad_road_is_refused_with_a_line_that_names_it() -> String:
	var cases: Array = [
		["through a fissure", "badlands", [[31, 11], [46, 8], [67, 21]], "road touches the thing at (46.0, 8.0)"],
		["through the plot", "frost_flats", [[0, -33], [0, 0], [0, -76]], "road touches the farm plot"],
		["off the land", "landing_field", [[0, 33], [0, 119]], "road leaves the land"],
		["far from the farm", "frost_flats", [[0, -50], [0, -76]], "road starts"],
		["short of the pad", "frost_flats", [[0, -33], [0, -60]], "not at its pad's edge"],
		["one waypoint", "frost_flats", [[0, -33]], "at least two waypoints"],
		["waypoint not a point", "frost_flats", [[0, -33], [1]], "road waypoint 1 must be [x, z]"],
		["through the pad's sign", "frost_flats", [[0, -33], [8, -78], [2, -78]], "road touches the thing at (2.7"],
	]
	for c: Array in cases:
		var rows: Array = BiomeData.raw_rows()
		for row: Variant in rows:
			if (row as Dictionary)["id"] == c[1]:
				(row as Dictionary)["road"] = c[2]
		var found: bool = false
		for line: String in BiomeData.problems(rows):
			found = found or str(c[3]) in line
		if not found:
			return "%s: no line holding '%s' in %s" % [c[0], c[3], BiomeData.problems(rows)]
	var hub: Array = BiomeData.raw_rows()
	for row: Variant in hub:
		if (row as Dictionary)["id"] == "farm":
			(row as Dictionary)["road"] = [[33, 0], [40, 0]]
	var hub_ok: bool = false
	for line: String in BiomeData.problems(hub):
		hub_ok = hub_ok or "the hub has no road" in line
	return "" if hub_ok else "A road on the farm hub was not refused"


func test_a_row_without_a_road_field_is_refused() -> String:
	var rows: Array = BiomeData.raw_rows()
	(rows[1] as Dictionary).erase("road")
	for line: String in BiomeData.problems(rows):
		if "missing road" in line:
			return ""
	return "A row with no road field passed"


func test_a_road_is_painted_and_ground_off_it_is_not() -> String:
	var ground := _ground()
	var lean: PackedColorArray = ground._biome_lean()
	var fail: String = ""
	for id: StringName in WITH_ROAD:
		var pair: Array[Vector2i] = _on_and_off(id)
		var on: Vector2i = pair[0]
		var off: Vector2i = pair[1]
		if BiomeData.road_gap(Vector2(on)) > BiomeData.ROAD_HALF_M or BiomeData.road_gap(Vector2(off)) < 3.0:
			fail = "%s: the test points %s and %s are not on and off the road" % [id, on, off]
			break
		var plain_on: Color = ground._tint(Terrain.natural(on)) * lean[ground._index(on.x, on.y)]
		var plain_off: Color = ground._tint(Terrain.natural(off)) * lean[ground._index(off.x, off.y)]
		var got_on: Color = ground._tints[ground._index(on.x, on.y)]
		var got_off: Color = ground._tints[ground._index(off.x, off.y)]
		if _distance(got_on, TerrainGround.ROAD_TINT) >= _distance(plain_on, TerrainGround.ROAD_TINT):
			fail = "%s: the ground on the road at %s is no nearer the road colour than plain ground" % [id, on]
			break
		if _distance(got_off, plain_off) > 0.001:
			fail = "%s: ground 5 m off the road at %s was painted" % [id, off]
			break
	ground.free()
	return fail


func test_the_paint_fades_over_a_metre_and_digging_keeps_it() -> String:
	if BiomeData.road_weight(BiomeData.ROAD_HALF_M) != 1.0 or BiomeData.road_weight(BiomeData.ROAD_HALF_M + BiomeData.ROAD_EDGE_M) != 0.0:
		return "The weight is not 1 in the strip and 0 past the soft edge"
	var mid: float = BiomeData.road_weight(BiomeData.ROAD_HALF_M + BiomeData.ROAD_EDGE_M * 0.5)
	if mid <= 0.0 or mid >= 1.0:
		return "The weight in the soft edge is %f" % mid
	var ground := _ground()
	var on: Vector2i = _on_and_off(&"frost_flats")[0]
	var before: Color = ground._tints[ground._index(on.x, on.y)]
	var cell: Vector2i = Terrain.cell_at(Vector2(on) + Vector2(0.5, 0.5))
	ground.show_dug({cell: 1})
	var after: Color = ground._tints[ground._index(on.x, on.y)]
	ground.free()
	return "" if before == after else "Digging changed the road's paint"


func test_the_road_changes_no_height() -> String:
	# The heights are Terrain's alone; the paint only reads them.
	var ground := _ground()
	var on := Vector2i(BiomeData.road(&"badlands")[2].round())
	var natural: float = Terrain.natural(on)
	var shown: float = ground._heights[ground._index(on.x, on.y)]
	ground.free()
	return "" if is_equal_approx(natural, shown) else "A road point stands at %f, the natural ground at %f" % [shown, natural]


func test_a_road_cell_cannot_be_dug_or_built_on_but_old_digging_loads() -> String:
	var none: Dictionary[Vector2i, int] = {}
	var no_rovers: Array[Transform3D] = []
	var pieces: Dictionary[Vector2i, int] = {}
	var tried: int = 0
	for id: StringName in WITH_ROAD:
		for at: Vector2 in _along(id):
			var cell: Vector2i = _cell_at(at)
			if not Terrain.can_dig(cell) or HillDressing.is_at_rock(cell) or BiomeMarkers.is_blocked_cell(cell):
				continue
			tried += 1
			if not BiomeData.is_road_cell(cell):
				return "%s: the cell %s under the road is not a road cell" % [id, cell]
			var why: String = Terrain.dig_problem(cell, none)
			if why != BiomeData.ROAD_TEXT:
				return "%s: digging the road cell %s said '%s'" % [id, cell, why]
			var stone: String = StonePieces.problem(cell, StonePieces.WALL, pieces, no_rovers, none)
			if stone != BiomeData.ROAD_TEXT:
				return "%s: a wall on the road cell %s said '%s'" % [id, cell, stone]
			if Terrain.dug_problem({cell: 1}) != "":
				return "%s: an old dug road cell %s is refused on load: %s" % [id, cell, Terrain.dug_problem({cell: 1})]
			if StonePieces.pieces_problem({cell: StonePieces.WALL}) != "":
				return "%s: an old piece on the road is refused on load" % id
			# A pocket's cell can still be dug, as under a pad.
			if Terrain.dig_problem(cell, none, true) != "":
				return "%s: a pocket on the road can not be dug: %s" % [id, Terrain.dig_problem(cell, none, true)]
	return "" if tried > 20 else "Only %d road cells could be tried" % tried


func test_points_off_a_road_are_not_road() -> String:
	for id: StringName in WITH_ROAD:
		var off: Vector2i = _on_and_off(id)[1]
		if BiomeData.is_road_cell(_cell_at(Vector2(off))):
			return "%s: a cell 5 m off the road is a road cell" % id
		if BiomeData.on_road(Vector2(off)):
			return "%s: a point 5 m off the road is on it" % id
	return ""


func test_digging_a_road_cell_through_the_game_is_refused() -> String:
	var gs: Node = load("res://scripts/autoload/GameState.gd").new()
	gs.build_registry()
	gs.set_world_seed(424242)
	var cell: Vector2i = _cell_at(Vector2(_on_and_off(&"frost_flats")[0]))
	if gs.is_live_pocket(cell):
		gs.free()
		return ""
	var out: String = gs.dig(Vector3i(cell.x, 0, cell.y))
	gs.free()
	return "" if out == BiomeData.ROAD_TEXT else "Digging a road cell through the game said '%s'" % out


func test_the_protocol_is_30() -> String:
	return "" if CoopSession.PROTOCOL == 30 else "The protocol is %d, not 30." % CoopSession.PROTOCOL
