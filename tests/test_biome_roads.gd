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
		["through the plot", "frost_flats", [[0, -34], [0, 0], [0, -76]], "road touches the farm plot"],
		["off the land", "landing_field", [[0, 33], [119, 119]], "road leaves the land"],
		["far from the farm", "frost_flats", [[0, -50], [0, -76]], "road starts"],
		["short of the pad", "frost_flats", [[0, -34], [0, -60]], "not at its pad's edge"],
		["one waypoint", "frost_flats", [[0, -34]], "at least two waypoints"],
		["waypoint not a point", "frost_flats", [[0, -34], [1]], "road waypoint 1 must be [x, z]"],
		["through the pad's sign", "frost_flats", [[0, -34], [8, -78], [2, -78]], "road touches the thing at (2.7"],
		["through another pad", "badlands", [[31, 11], [28, -17], [67, 21]], "road touches the thing at (28.0, -17.0)"],
		["through another pad's sign", "badlands", [[31, 11], [30.7, -17], [67, 21]], "road touches the thing at (30.7"],
		["over a placed entrance", "badlands", [[31, 11], [50, -24], [67, 21]], "road touches the thing at (50.0, -24.0)"],
		["ending at its pad's middle", "frost_flats", [[0, -34], [0, -78]], "not at its pad's edge"],
		["across its own pad", "frost_flats", [[0, -34], [0, -76], [0, -80]], "road runs over its own pad"],
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


func _colours_at(ground: TerrainGround, at: Vector2i) -> Color:
	var chunk: Vector2i = ground._chunk_of(at)
	var colours: PackedColorArray = (ground._chunks[chunk].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	return colours[(at.x - chunk.x) * (TerrainGround.CHUNK_M + 1) + (at.y - chunk.y)]



func test_the_paint_fades_over_a_metre_and_digging_keeps_it() -> String:
	if BiomeData.road_weight(BiomeData.ROAD_HALF_M) != 1.0 or BiomeData.road_weight(BiomeData.ROAD_HALF_M + BiomeData.ROAD_EDGE_M) != 0.0:
		return "The weight is not 1 in the strip and 0 past the soft edge"
	var mid: float = BiomeData.road_weight(BiomeData.ROAD_HALF_M + BiomeData.ROAD_EDGE_M * 0.5)
	if mid <= 0.0 or mid >= 1.0:
		return "The weight in the soft edge is %f" % mid
	var ground := _ground()
	var lean: PackedColorArray = ground._biome_lean()
	var fail: String = ""
	# A point 2 m off the frost road (x = 0) is in the soft edge: part paint.
	var soft := Vector2i(2, -50)
	var plain: Color = ground._tint(Terrain.natural(soft)) * lean[ground._index(soft.x, soft.y)]
	var want: Color = plain.lerp(TerrainGround.ROAD_TINT, TerrainGround.ROAD_STRENGTH * BiomeData.road_weight(2.0))
	var got: Color = ground._tints[ground._index(soft.x, soft.y)]
	if _distance(got, want) > 0.005 or _distance(got, plain) < 0.01:
		fail = "The soft edge at %s is %s, wanted about %s (plain %s)" % [soft, got, want, plain]
	# The redrawn chunk keeps the paint, in the mesh's own colours.
	var on: Vector2i = _on_and_off(&"frost_flats")[0]
	var before: Color = ground._tints[ground._index(on.x, on.y)]
	ground.show_dug({Terrain.cell_at(Vector2(on) + Vector2(0.5, 0.5)): 1})
	var after: Color = ground._tints[ground._index(on.x, on.y)]
	var shown: Color = _colours_at(ground, on)
	var plain_on: Color = ground._tint(Terrain.natural(on)) * lean[ground._index(on.x, on.y)]
	if fail == "" and before != after:
		fail = "Digging changed the road's paint"
	if fail == "" and (_distance(shown, after) > 0.02 or _distance(shown, plain_on) < 0.03):
		fail = "The redrawn chunk at %s shows %s, not the road paint %s" % [on, shown, after]
	ground.free()
	return fail


## The shader multiplies a vertex colour by this base, so it is what the eye sees.
const SHADER_BASE := Color(0.42, 0.5, 0.3)
const MIN_SEPARATION: float = 0.06


func test_a_road_shows_against_the_ground_of_its_own_biome_flat_and_on_a_hill() -> String:
	var ground := _ground()
	var lean: PackedColorArray = ground._biome_lean()
	var fail: String = ""
	for id: StringName in WITH_ROAD:
		var on: Vector2i = _on_and_off(id)[0]
		var leaned: Color = lean[ground._index(on.x, on.y)]
		for height: float in [0.0, 3.0]:
			var plain: Color = ground._tint(height) * leaned
			var road: Color = plain.lerp(TerrainGround.ROAD_TINT, TerrainGround.ROAD_STRENGTH)
			var seen: float = absf((plain.r - road.r) * SHADER_BASE.r) + absf((plain.g - road.g) * SHADER_BASE.g) + absf((plain.b - road.b) * SHADER_BASE.b)
			if seen < MIN_SEPARATION:
				fail = "%s: a road on ground %.0f m high differs from its ground by only %.3f after the shader" % [id, height, seen]
	ground.free()
	return fail


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


## A road cell that is not an ore pocket and can be dug: on the frost road.
func _plain_road_cell() -> Vector3i:
	for at: Vector2 in _along(&"frost_flats"):
		var cell: Vector2i = _cell_at(at)
		if Terrain.can_dig(cell) and BiomeData.is_road_cell(cell) and not BiomeMarkers.is_blocked_cell(cell) and not HillDressing.is_at_rock(cell):
			return Vector3i(cell.x, 0, cell.y)
	return Vector3i.ZERO


func _state() -> Node:
	var gs: Node = load("res://scripts/autoload/GameState.gd").new()
	gs.build_registry()
	gs.set_world_seed(424242)
	return gs



func test_digging_a_road_cell_through_the_game_is_refused() -> String:
	var gs: Node = _state()
	var cell: Vector3i = _plain_road_cell()
	var bad: String = ""
	if cell == Vector3i.ZERO or gs.is_live_pocket(Vector2i(cell.x, cell.z)):
		bad = "No plain road cell to test"
	else:
		var out: String = gs.dig(cell)
		if out != BiomeData.ROAD_TEXT:
			bad = "Digging a road cell through the game said '%s'" % out
	gs.free()
	return bad


func test_the_host_refuses_a_road_dig_and_a_road_wall() -> String:
	var gs: Node = _state()
	var commands: Node = load("res://scripts/autoload/FarmCommands.gd").new()
	commands.state = gs
	var cell: Vector3i = _plain_road_cell()
	var bad: String = ""
	var dug: Variant = commands.execute("player_1", &"dig", [cell])
	if dug != BiomeData.ROAD_TEXT:
		bad = "The host's road dig answered %s" % [dug]
	var wall: Variant = commands.execute("player_1", &"place_stone", [cell, StonePieces.WALL])
	if bad == "" and wall != BiomeData.ROAD_TEXT:
		bad = "The host's road wall answered %s" % [wall]
	commands.free()
	gs.free()
	return bad


func test_an_ore_pocket_on_a_road_digs_once_then_fills() -> String:
	var gs: Node = _state()
	var cell: Vector3i = _plain_road_cell()
	var at := Vector2i(cell.x, cell.z)
	gs.new_pockets.append(at)
	var bad: String = ""
	if gs.dig(cell) != "" or gs.dug.get(at, 0) != 1:
		bad = "The pocket on the road did not dig once"
	elif gs.dig(cell) != BiomeData.ROAD_TEXT:
		bad = "A second dig on the road pocket was not refused"
	elif gs.fill(cell) != "":
		bad = "The road pocket's cell could not be filled"
	gs.free()
	return bad


func test_an_old_save_with_digging_and_stone_on_a_road_loads_and_can_be_put_right() -> String:
	var gs: Node = _state()
	var cells: Array[Vector2i] = []
	for at: Vector2 in _along(&"landing_field"):
		var cell: Vector2i = _cell_at(at)
		if Terrain.can_dig(cell) and BiomeData.is_road_cell(cell) and not BiomeMarkers.is_blocked_cell(cell) and not HillDressing.is_at_rock(cell) and not cells.has(cell):
			cells.append(cell)
		if cells.size() == 8:
			break
	if cells.size() < 8:
		gs.free()
		return "Only %d road cells found" % cells.size()
	gs.dug[cells[0]] = 1
	gs.stone_pieces[cells[7]] = StonePieces.WALL
	gs.stone = 0
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var other: Node = _state()
	var bad: String = other.farm_from_dict(data)
	if bad == "" and (not other.dug.has(cells[0]) or not other.stone_pieces.has(cells[7])):
		bad = "The old digging or stone on the road did not load"
	if bad == "" and other.fill(Vector3i(cells[0].x, 0, cells[0].y)) != "":
		bad = "An old dug road cell could not be filled"
	if bad == "" and other.place_stone(Vector3i(cells[7].x, 0, cells[7].y), StonePieces.TAKE_UP) != "":
		bad = "An old stone piece on the road could not be taken up"
	other.free()
	gs.free()
	return bad


func test_the_protocol_is_36() -> String:
	return "" if CoopSession.PROTOCOL == 36 else "The protocol is %d, not 36." % CoopSession.PROTOCOL
