extends RefCounted
## data/biomes.json and BiomeData (docs/design/biomes.md section 6, step 3): the
## table is sound, the rule puts every point of the 240 m land in some biome,
## the hub wins in the middle, each marker's pad is clear and near flat, the
## roads out of the farm run through the right biomes, and a broken table is
## refused with a clear line.

const IDS: Array[StringName] = [&"farm", &"lab_quarter", &"badlands", &"basalt_ridge", &"frost_flats", &"landing_field"]


var _file_rows: Array = []


## A deep copy of the file's rows, read from the file once for the whole suite.
func _good_rows() -> Array:
	if _file_rows.is_empty():
		_file_rows = BiomeData.raw_rows()
	return _file_rows.duplicate(true)


## A copy of the rows with one field of one row changed.
func _with(id: String, field: String, value: Variant) -> Array:
	var rows: Array = _good_rows()
	for row: Variant in rows:
		if (row as Dictionary)["id"] == id:
			(row as Dictionary)[field] = value
	return rows


## "" if some problem line holds `want`, else what the lines were.
func _has_line(rows: Array, want: String) -> String:
	var lines: Array[String] = BiomeData.problems(rows)
	for line: String in lines:
		if want in line:
			return ""
	return "Expected a problem with '%s', got %s" % [want, lines]


func test_the_table_parses_and_is_sound() -> String:
	var found: Dictionary = BiomeData.read_file(BiomeData.PATH)
	if not (found["errors"] as Array).is_empty():
		return "; ".join(found["errors"] as Array)
	var count: int = (found["rows"] as Array).size()
	return "" if count == IDS.size() else "Expected %d rows, the file gave %d." % [IDS.size(), count]


func test_the_six_ids_are_the_doc_s_in_order() -> String:
	BiomeData.reload()
	return "" if BiomeData.ids() == IDS else "Ids were %s" % [BiomeData.ids()]


func test_the_readers_answer_from_the_table() -> String:
	if BiomeData.display_name(&"basalt_ridge") != "Basalt Ridge":
		return "display_name is off"
	if BiomeData.band(&"basalt_ridge") != Vector2i(5, 20) or BiomeData.band(&"frost_flats") != Vector2i(18, 35):
		return "A band is not the doc's"
	if BiomeData.band(&"no_such") != Vector2i.ZERO or BiomeData.marker(&"no_such") != Vector2.ZERO:
		return "An unknown id must give the empty answer"
	if BiomeData.tint(&"no_such") != Color.MAGENTA:
		return "An unknown tint must show as magenta"
	for id: StringName in IDS:
		if BiomeData.tint(id) == Color.MAGENTA:
			return "%s has no tint" % id
		if BiomeData.reach(id) <= 0.0:
			return "%s has no reach" % id
	return ""


## The cached rows cannot be changed by a reader, nested lists included.
func test_the_cached_rows_are_read_only() -> String:
	BiomeData.reload()
	var row: Dictionary = BiomeData.biome(&"basalt_ridge")
	if row.is_empty():
		return "The basalt row did not load"
	if not row.is_read_only() or not (row["band"] as Array).is_read_only() or not (row["entrances"] as Array).is_read_only():
		return "A row, its band or its entrances can still be changed"
	if not ((row["entrances"] as Array)[0] as Dictionary).is_read_only():
		return "An entrance can still be changed"
	if not BiomeData.rows().is_read_only():
		return "The list of rows can still be changed"
	return ""


## Even when the file fails, the empty list a reader gets cannot be changed.
func test_the_cache_is_read_only_when_the_load_fails() -> String:
	var found: Dictionary = BiomeData.read_file("res://data/no_such_biomes.json")
	if not (found["rows"] as Array).is_empty():
		return "A failed read gave rows"
	return ""


## reload() makes the next reader read the file again.
func test_reload_reads_the_file_again() -> String:
	BiomeData.reload()
	var first: Array[StringName] = BiomeData.ids()
	BiomeData.reload()
	return "" if BiomeData.ids() == first and not first.is_empty() else "Reload changed or emptied the table"


func test_zones_and_entrances_are_lists() -> String:
	if str(BiomeData.zones(&"basalt_ridge")) != str([&"lava_tubes", &"colony_mine"]):
		return "Basalt Ridge holds %s" % [BiomeData.zones(&"basalt_ridge")]
	if str(BiomeData.zones(&"landing_field")) != str([&"phobos", &"deimos"]):
		return "Landing Field holds %s" % [BiomeData.zones(&"landing_field")]
	if not BiomeData.zones(&"farm").is_empty() or not BiomeData.zones(&"no_such").is_empty():
		return "The farm and an unknown id hold no zone"
	if BiomeData.entrance_at(&"basalt_ridge", &"colony_mine") == null or BiomeData.entrance_at(&"frost_flats", &"ice_caves") != null:
		return "A placed entrance must answer a point, an unplaced one null"
	if BiomeData.entrance_at(&"basalt_ridge", &"phobos") != null:
		return "A zone that is not there must answer null"
	return ""


## The bands are the zones doc's: every zone behind an entrance starts inside
## its biome's band.
func test_bands_match_the_zones_they_hold() -> String:
	for id: StringName in IDS:
		var b: Vector2i = BiomeData.band(id)
		for zone: StringName in BiomeData.zones(id):
			var start: int = ZoneData.band(zone).x
			if start < b.x or start > b.y:
				return "%s (band %s) holds %s, which starts at level %d" % [id, b, zone, start]
	return ""


func test_every_zone_is_held_by_exactly_one_biome() -> String:
	var held: Dictionary = {}
	for id: StringName in IDS:
		for zone: StringName in BiomeData.zones(id):
			if held.has(zone):
				return "%s is held by %s and %s" % [zone, held[zone], id]
			held[zone] = id
	return ""


func test_the_farm_hub_wins_in_the_middle() -> String:
	var farm_points: Array[Vector2] = [
		Vector2.ZERO, Vector2(11, 11), Vector2(-11, -11), Vector2(8, 14), Vector2(13.5, 15), Vector2(-3, 14),
		Vector2(16, -2), Vector2(1.5, 17.5), Vector2(0, 2), Vector2(23, 0), Vector2(0, -23),
	]
	for p: Vector2 in farm_points:
		if BiomeData.biome_at(p) != BiomeData.FARM:
			return "%s should be the farm, not %s" % [p, BiomeData.biome_at(p)]
	return ""


func test_each_biome_holds_its_own_centre_and_marker() -> String:
	for id: StringName in IDS:
		var at: StringName = BiomeData.biome_at(BiomeData.centre(id))
		if at != id:
			return "%s's centre falls in %s" % [id, at]
		at = BiomeData.biome_at(BiomeData.marker(id))
		if at != id:
			return "%s's marker falls in %s" % [id, at]
	return ""


func test_existing_places_stay_in_their_biomes() -> String:
	var want: Dictionary = {
		Vector2(20.5, -19): &"basalt_ridge", Vector2(20.5, -15.5): &"basalt_ridge",
		Vector2(-70, -70): &"lab_quarter",
		Vector2(63, 8): &"badlands", Vector2(63, 2): &"badlands",
	}
	for p: Vector2 in want:
		if BiomeData.biome_at(p) != want[p]:
			return "%s should be %s, it is %s" % [p, want[p], BiomeData.biome_at(p)]
	if BiomeData.entrance_at(&"badlands", &"flooded_aquifer") == null:
		return "The Aquifer sinkhole must be the Badlands' entrance (Question 12)"
	if BiomeData.entrance_at(&"basalt_ridge", &"lava_tubes") != Vector2(20.5, -19):
		return "The tunnel mouth must be the Basalt Ridge's lava_tubes entrance"
	return ""


## The relay road runs from the farm to the relay at x = z, and a rover driving
## it is in the farm and then the Lab Quarter, with no other biome between.
func test_the_relay_road_is_farm_then_lab_quarter() -> String:
	var length: float = Terrain.RELAY.length()
	var left_farm: bool = false
	var t: float = 0.0
	while t <= length:
		var id: StringName = BiomeData.biome_at(Terrain.RELAY_WAY * t)
		if id == BiomeData.FARM:
			if left_farm:
				return "The road is the farm again at %.0f m" % t
		elif id == &"lab_quarter":
			left_farm = true
		else:
			return "The relay road is %s at %.0f m, not farm or lab_quarter" % [id, t]
		t += 0.5
	return "" if left_farm else "The road never leaves the farm"


## The way to the tunnel mouth, straight from the farm, is the farm and then the
## Basalt Ridge. (The land has no built tunnel road; this is the line a rover
## would drive.)
func test_the_way_to_the_tunnel_mouth_is_farm_then_basalt() -> String:
	var mouth: Vector2 = BiomeData.entrance_at(&"basalt_ridge", &"lava_tubes")
	var left_farm: bool = false
	var t: float = 0.0
	while t <= 1.0:
		var id: StringName = BiomeData.biome_at(mouth * t)
		if id == BiomeData.FARM:
			if left_farm:
				return "The way is the farm again at %.2f of the way" % t
		elif id == &"basalt_ridge":
			left_farm = true
		else:
			return "The way to the mouth is %s at %.2f of the way" % [id, t]
		t += 0.01
	return "" if left_farm else "The way never leaves the farm"


## Every point of the 240 m land, every 2 m and the four corners, has an answer
## that is a row of the table.
func test_every_point_of_the_land_maps_to_some_id() -> String:
	var seen: Dictionary = {}
	var step: int = 2
	var half: int = Terrain.HALF_M
	for x: int in range(-half, half + 1, step):
		for z: int in range(-half, half + 1, step):
			var id: StringName = BiomeData.biome_at(Vector2(x, z))
			if not BiomeData.has_biome(id):
				return "(%d, %d) maps to '%s', which is no biome" % [x, z, id]
			seen[id] = int(seen.get(id, 0)) + 1
	for id: StringName in IDS:
		if not seen.has(id):
			return "No point of the land is %s" % id
	# The Badlands is the open land, so it must be the biggest share.
	for id: StringName in IDS:
		if id != &"badlands" and int(seen[id]) >= int(seen[&"badlands"]):
			return "%s covers more of the land than the Badlands" % id
	return ""


func test_a_point_two_reaches_cover_goes_to_the_nearer_centre() -> String:
	var table: Array = [
		{"id": "hub", "role": "hub", "centre": [0, 0], "reach_m": 5},
		{"id": "a", "role": "spoke", "centre": [30, 0], "reach_m": 20},
		{"id": "b", "role": "spoke", "centre": [50, 0], "reach_m": 20},
		{"id": "rest", "role": "open", "centre": [0, 50], "reach_m": 5},
	]
	var cases: Dictionary = {
		Vector2(2, 0): &"hub", Vector2(39, 0): &"a", Vector2(41, 0): &"b",
		Vector2(0, -90): &"rest", Vector2(30, 21): &"rest",
	}
	for p: Vector2 in cases:
		if BiomeData.at_in(table, p) != cases[p]:
			return "%s gave %s, not %s" % [p, BiomeData.at_in(table, p), cases[p]]
	return ""


# --- Markers and their pads -----------------------------------------------------

## Each marker's 4 by 4 m pad keeps off the plot, every built thing and rock, the
## relay road and every other marker, and its ground varies under the limit.
func test_every_marker_pad_is_clear_and_near_flat() -> String:
	for id: StringName in IDS:
		var lines: Array[String] = BiomeData.pad_problems(String(id), "marker", BiomeData.marker(id))
		if not lines.is_empty():
			return "; ".join(lines)
		if BiomeData.pad_spread_m(BiomeData.marker(id)) > BiomeData.PAD_SPREAD_MAX_M:
			return "%s's pad is not near flat" % id
	return ""


func test_the_spot_list_holds_the_real_rocks_and_props() -> String:
	var spots: Array[Vector4] = BiomeData.spots()
	if spots.size() < BiomeData.SCENE_SPOTS.size() + HillDressing.ROCKS.size():
		return "The spot list is missing the rocks"
	var needed: Array[Vector2] = [Vector2(-9, -17), Vector2(-17, -10), Vector2(45, -33), Vector2(-1, -25), Vector2(1.5, 17.5)]
	for want: Vector2 in needed:
		var found: bool = false
		for spot: Vector4 in spots:
			if absf(spot.x - want.x) < 0.5 and absf(spot.y - want.y) < 0.5:
				found = true
		if not found:
			return "No spot near %s" % want
	return ""


## The pad check refuses the old farm marker (-12, -18), a pad on the plot, a pad
## on a hill, and a pad on the relay road.
func test_the_pad_check_refuses_known_bad_places() -> String:
	var bad: Array = [
		["RockB", Vector2(-12, -18), "farm: marker pad is on or too near the thing at (-9.0, -17.0)"],
		["the plot", Vector2(4, 4), "farm: marker is on the farm plot"],
		["the relay road", Vector2(-20, -20), "farm: marker pad is 0.0 m from the relay road, inside its 5 m level strip"],
		["the Basalt hill", Vector2(44, -40), "farm: marker pad ground varies by"],
		["the Badlands hill", Vector2(58, 24), "farm: marker pad ground varies by"],
	]
	for c: Array in bad:
		var lines: Array[String] = BiomeData.pad_problems("farm", "marker", c[1] as Vector2)
		var found: bool = false
		for line: String in lines:
			found = found or (c[2] as String) in line
		if not found:
			return "A pad on %s: expected '%s', got %s" % [c[0], c[2], lines]
		if "hill" in (c[0] as String) and lines.size() != 1:
			return "A pad on %s should fail on the ground alone, got %s" % [c[0], lines]
	return ""


func test_the_old_marker_is_refused_with_its_reason() -> String:
	var lines: Array[String] = BiomeData.pad_problems("farm", "marker", Vector2(-12, -18))
	for line: String in lines:
		if "(-9.0, -17.0)" in line and "farm: marker pad is on or too near the thing" in line:
			return ""
	return "RockB was not named: %s" % [lines]


## The plot constant here is the game's.
func test_the_plot_size_matches_the_game() -> String:
	var plot: Rect2i = GameState.PLOT
	var half: float = float(plot.size.x) * 0.5 * 2.0
	if plot.position.x != -plot.size.x / 2 or half != BiomeData.PLOT_HALF_M or plot.size.y != plot.size.x:
		return "BiomeData.PLOT_HALF_M (%s) no longer matches GameState.PLOT %s" % [BiomeData.PLOT_HALF_M, plot]
	return ""


func test_markers_keep_the_plot_margin() -> String:
	var limit: float = BiomeData.PLOT_HALF_M + BiomeData.PLOT_CLEAR_M
	for id: StringName in IDS:
		var m: Vector2 = BiomeData.marker(id)
		if absf(m.x) < limit and absf(m.y) < limit:
			return "%s's marker is within %s m of the farm's middle" % [id, limit]
	return ""


# --- Broken tables --------------------------------------------------------------

## Each bad row gives a line holding the expected words.
func test_the_checker_catches_bad_rows() -> String:
	var cases: Array = [
		["duplicate id", "lab_quarter", "id", "basalt_ridge", "basalt_ridge: duplicate id"],
		["blank id", "lab_quarter", "id", "  ", "empty id"],
		["blank name", "lab_quarter", "name", "  ", "lab_quarter: empty name"],
		["centre off the land", "frost_flats", "centre", [0, -130], "frost_flats: centre (0.0, -130.0) is outside the 240 m land"],
		["marker too near the edge", "landing_field", "marker", [0, 118], "4 m edge margin"],
		["marker on the plot", "farm", "marker", [4, 4], "farm: marker is on the farm plot"],
		["marker on a prop", "basalt_ridge", "marker", [21, -18], "basalt_ridge: marker pad is on or too near the thing"],
		["marker on a hill", "badlands", "marker", [58, 24], "badlands: marker pad ground varies by"],
		["marker on the road", "lab_quarter", "marker", [-30, -30], "lab_quarter: marker pad is 0.0 m from the relay road"],
		["marker not a point", "lab_quarter", "marker", [1], "lab_quarter: marker must be [x, z]"],
		["reach zero", "badlands", "reach_m", 0, "badlands: reach_m must be above 0"],
		["reach negative", "basalt_ridge", "reach_m", -5, "basalt_ridge: reach_m must be above 0"],
		["band reversed", "frost_flats", "band", [30, 10], "frost_flats: band 30 to 10"],
		["band below 1", "farm", "band", [0, 5], "farm: band 0 to 5"],
		["band above 99", "landing_field", "band", [20, 120], "landing_field: band 20 to 120"],
		["band fractional", "lab_quarter", "band", [1.5, 20], "lab_quarter: band edges must be whole levels"],
		["bad tint", "badlands", "tint", "rust", "badlands: tint rust is not a colour"],
		["bad ground tint", "badlands", "ground_tint", "rust", "badlands: ground_tint rust is not a colour"],
		["empty sign", "frost_flats", "sign", " ", "frost_flats: empty sign"],
		["unknown zone", "basalt_ridge", "entrances", [{"zone": "moon_base", "at": [28, -30]}], "basalt_ridge: entrance 0 zone moon_base is not a zones.json id"],
		["entrance without at", "lab_quarter", "entrances", [{"zone": "ice_caves"}], "lab_quarter: entrance 0 must be {zone, at}"],
		["entrance claimed twice", "frost_flats", "entrances", [{"zone": "lava_tubes", "at": null}], "frost_flats: zone lava_tubes is also an entrance of basalt_ridge"],
		["marker on its entrance", "badlands", "entrances", [{"zone": "flooded_aquifer", "at": [69, 22]}], "badlands: marker is on the flooded_aquifer entrance of badlands"],
		["entrance in another biome", "badlands", "entrances", [{"zone": "flooded_aquifer", "at": [0, 0]}], "badlands: its flooded_aquifer entrance falls in farm"],
		["unknown role", "lab_quarter", "role", "wedge", "lab_quarter: unknown role wedge"],
		["marker in another biome", "lab_quarter", "marker", [0, 40], "lab_quarter: its marker falls in"],
		["bearing far off", "frost_flats", "bearing_deg", 180, "frost_flats: bearing_deg 180"],
		["bearing 360", "frost_flats", "bearing_deg", 360, "frost_flats: bearing_deg 360 must be from 0 up to 360"],
		["bearing negative", "frost_flats", "bearing_deg", -5, "frost_flats: bearing_deg -5 must be from 0 up to 360"],
		["bearing on the hub", "farm", "bearing_deg", 90, "farm: the hub has no bearing_deg"],
		["reach wrong type", "farm", "reach_m", "wide", "farm: reach_m has the wrong type"],
	]
	for c: Array in cases:
		var failed: String = _has_line(_with(c[1], c[2], c[3]), c[4])
		if failed != "":
			return "%s: %s" % [c[0], failed]
	return ""


## A marker on any biome's entrance is refused, not only its own.
func test_a_marker_on_another_biomes_entrance_is_refused() -> String:
	return _has_line(_with("lab_quarter", "marker", [20, -20]), "marker is on the lava_tubes entrance of basalt_ridge")


func test_a_marker_on_another_marker_is_refused() -> String:
	var rows: Array = _with("lab_quarter", "marker", [-41, -29])
	for row: Variant in rows:
		if (row as Dictionary)["id"] == "frost_flats":
			(row as Dictionary)["marker"] = [-41, -29]
	return _has_line(rows, "marker is on the marker of")


func test_a_missing_hub_or_open_row_is_refused_alone() -> String:
	var without_hub: Array = _good_rows().filter(func(r: Dictionary) -> bool: return r["id"] != "farm")
	var without_open: Array = _good_rows().filter(func(r: Dictionary) -> bool: return r["id"] != "badlands")
	var failed: String = _has_line(without_hub, "the table needs exactly one hub row, not 0")
	if failed == "":
		failed = _has_line(without_open, "the table needs exactly one open row, not 0")
	return failed


## A bad hub row gives its own fault and not also "needs exactly one hub".
func test_a_bad_hub_reports_only_its_own_fault() -> String:
	var lines: Array[String] = BiomeData.problems(_with("farm", "reach_m", 0))
	if lines.size() != 1 or lines[0] != "farm: reach_m must be above 0":
		return "Expected only the reach fault, got %s" % [lines]
	lines = BiomeData.problems(_with("badlands", "reach_m", "wide"))
	for line: String in lines:
		if "exactly one" in line:
			return "A bad open row also said: %s" % line
	return ""


func test_a_missing_field_and_a_non_object_are_refused() -> String:
	var rows: Array = _good_rows()
	(rows[1] as Dictionary).erase("sign")
	var lines: Array[String] = BiomeData.problems(rows)
	if not "lab_quarter: missing sign" in lines:
		return "A row with no sign must say so, got %s" % [lines]
	if not "row 0 is not an object" in BiomeData.problems([7]):
		return "A row that is not an object must be refused"
	return ""


func test_a_row_without_an_id_is_named_by_its_place() -> String:
	var rows: Array = _good_rows()
	(rows[2] as Dictionary).erase("id")
	var lines: Array[String] = BiomeData.problems(rows)
	return "" if "row 2: missing id" in lines else "Expected 'row 2: missing id', got %s" % [lines]


func test_the_messages_name_the_row_and_the_fault() -> String:
	var lines: Array[String] = BiomeData.problems(_with("frost_flats", "centre", [0, -130]))
	if lines.is_empty() or not lines[0].begins_with("frost_flats: centre") or not "240 m land" in lines[0]:
		return "Unclear message: %s" % [lines]
	lines = BiomeData.problems(_with("landing_field", "marker", [0, 118]))
	if lines.is_empty() or not "outside the 240 m land's 4 m edge margin" in lines[0]:
		return "The edge message must give the 4 m margin: %s" % [lines]
	return ""


# --- Loading --------------------------------------------------------------------

func test_a_missing_file_is_reported_with_its_name() -> String:
	var found: Dictionary = BiomeData.read_file("res://data/no_such_biomes.json")
	var errors: Array = found["errors"]
	if errors.size() != 1 or not "no_such_biomes.json: file not found" in str(errors[0]) or not (found["rows"] as Array).is_empty():
		return "Unclear: %s" % [errors]
	return ""


func test_a_parse_error_is_reported_with_its_line() -> String:
	var path: String = "user://biomes_bad_parse.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\n  \"biomes\": [\n    {oops}\n  ]\n}\n")
	file.close()
	var errors: Array = BiomeData.read_file(path)["errors"]
	DirAccess.remove_absolute(path)
	if errors.size() != 1 or not str(errors[0]).begins_with("user://biomes_bad_parse.json: line ") or not "Expected key" in str(errors[0]):
		return "Unclear: %s" % [errors]
	return ""


func test_a_file_without_a_biomes_list_is_reported() -> String:
	var path: String = "user://biomes_no_key.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"other\": []}\n")
	file.close()
	var found: Dictionary = BiomeData.read_file(path)
	DirAccess.remove_absolute(path)
	var errors: Array = found["errors"]
	if errors.size() != 1 or not "biomes_no_key.json: no \"biomes\" list" in str(errors[0]):
		return "Unclear: %s" % [errors]
	return ""


## A table that fails the check is not kept: no rows, one error line per fault.
func test_a_table_that_fails_the_check_gives_no_rows() -> String:
	var path: String = "user://biomes_bad_table.json"
	var rows: Array = _with("farm", "reach_m", 0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"biomes": rows}))
	file.close()
	var found: Dictionary = BiomeData.read_file(path)
	DirAccess.remove_absolute(path)
	var errors: Array = found["errors"]
	if not (found["rows"] as Array).is_empty() or errors.size() != 1 or not "biomes_bad_table.json: farm: reach_m must be above 0" in str(errors[0]):
		return "Unclear: %s" % [errors]
	return ""


# --- No key in the sign text ----------------------------------------------------

## The same scan as test_controls_guide's hard-coded-key check, over the signs.
func test_the_sign_texts_name_no_key() -> String:
	var spot := RegEx.create_from_string("[Pp]ress [A-Z0-9]\\b|\\[(?:E|Y|R|Tab|Space|%d)\\]|\\((?:Esc|K|O|T|F7)\\)"
		+ "|\"[A-Z]: |[^\\w%][A-Z0-9] (?:does|checks|fills|shows|gets|changes|moves|again|plants|digs|opens|closes)\\b"
		+ "|\\[ and \\]|\\bSpace\\b")
	var loose := RegEx.create_from_string("[Pp]ress |\\bF1\\b|\\bF7\\b|\\bEsc\\b|\\bTab\\b|\\bClick\\b")
	for id: StringName in IDS:
		var text: String = BiomeData.sign_text(id)
		if text.is_empty():
			return "%s has no sign text" % id
		if spot.search(text) != null or loose.search(text) != null:
			return "%s's sign names a key: '%s'" % [id, text]
		if not text.begins_with(BiomeData.display_name(id) + ":"):
			return "%s's sign must open with its name: '%s'" % [id, text]
	return ""
