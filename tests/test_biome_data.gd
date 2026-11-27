extends RefCounted
## data/biomes.json and BiomeData (docs/design/biomes.md section 6, step 3): the
## table is sound, the rule puts every point of the 240 m land in some biome,
## the hub wins in the middle, and a broken table is refused with a clear line.

const IDS: Array[StringName] = [&"farm", &"lab_quarter", &"badlands", &"basalt_ridge", &"frost_flats", &"landing_field"]
const SPOKES: Array[StringName] = [&"lab_quarter", &"basalt_ridge", &"frost_flats", &"landing_field"]


func _good_rows() -> Array:
	return BiomeData.raw_rows().duplicate(true)


## A copy of the rows with one field of one row changed.
func _with(id: String, field: String, value: Variant) -> Array:
	var rows: Array = _good_rows()
	for row: Variant in rows:
		if (row as Dictionary)["id"] == id:
			(row as Dictionary)[field] = value
	return rows


func test_the_table_parses_and_is_sound() -> String:
	var raw: Array = BiomeData.raw_rows()
	if raw.size() != IDS.size():
		return "Expected %d rows, the file gave %d." % [IDS.size(), raw.size()]
	var problems: Array[String] = BiomeData.problems(raw)
	return "" if problems.is_empty() else "; ".join(problems)


func test_the_six_ids_are_the_doc_s_in_order() -> String:
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


## The bands are the zones doc's: the zone behind each entrance is tuned for the
## biome's level, and every biome's band holds its zone's start.
func test_bands_match_the_zones_they_hold() -> String:
	for id: StringName in IDS:
		var zone: StringName = BiomeData.zone_entrance(id)
		if zone == &"":
			continue
		var b: Vector2i = BiomeData.band(id)
		var start: int = ZoneData.band(zone).x
		if start < b.x or start > b.y:
			return "%s (band %s) holds %s, which starts at level %d" % [id, b, zone, start]
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
	var mouth := Vector2(20.5, -19)
	var pad := Vector2(20.5, -15.5)
	var want: Dictionary = {
		mouth: &"basalt_ridge", pad: &"farm" if false else &"basalt_ridge",
		Vector2(-70, -70): &"lab_quarter",
		Vector2(63, 8): &"badlands", Vector2(63, 2): &"badlands",
	}
	for p: Vector2 in want:
		if BiomeData.biome_at(p) != want[p]:
			return "%s should be %s, it is %s" % [p, want[p], BiomeData.biome_at(p)]
	var sinkhole: Variant = BiomeData.entrance_at(&"badlands")
	if not sinkhole is Vector2 or BiomeData.zone_entrance(&"badlands") != &"flooded_aquifer":
		return "The Aquifer sinkhole must be the Badlands' entrance (Question 12)"
	if BiomeData.zone_entrance(&"basalt_ridge") != &"lava_tubes" or BiomeData.entrance_at(&"basalt_ridge") != mouth:
		return "The tunnel mouth must be the Basalt Ridge's entrance"
	return ""


## Every point of the 240 m land, every 2 m and the four corners, has an answer
## that is a row of the table.
func test_every_point_of_the_land_maps_to_some_id() -> String:
	var seen: Dictionary = {}
	var step: int = 2
	var half: int = int(BiomeData.LAND_HALF_M)
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


func test_markers_keep_off_the_plot_and_the_known_props() -> String:
	for id: StringName in IDS:
		var m: Vector2 = BiomeData.marker(id)
		if absf(m.x) < BiomeData.PLOT_HALF_M and absf(m.y) < BiomeData.PLOT_HALF_M:
			return "%s's marker is on the plot" % id
		for spot: Vector3 in BiomeData.KNOWN_SPOTS:
			if m.distance_to(Vector2(spot.x, spot.y)) < spot.z:
				return "%s's marker is on a known spot %s" % [id, spot]
	return ""


## The plot constant here is the game's.
func test_the_plot_size_matches_the_game() -> String:
	var plot: Rect2i = GameState.PLOT
	var half: float = float(plot.size.x) * 0.5 * 2.0
	if plot.position.x != -plot.size.x / 2 or half != BiomeData.PLOT_HALF_M or plot.size.y != plot.size.x:
		return "BiomeData.PLOT_HALF_M (%s) no longer matches GameState.PLOT %s" % [BiomeData.PLOT_HALF_M, plot]
	return ""


# --- Broken tables --------------------------------------------------------------

func test_the_checker_catches_bad_rows() -> String:
	var cases: Dictionary = {
		"duplicate id": ["lab_quarter", "id", "basalt_ridge"],
		"centre off the land": ["frost_flats", "centre", [0, -130]],
		"marker too near the edge": ["landing_field", "marker", [0, 118]],
		"marker on the plot": ["farm", "marker", [4, 4]],
		"marker on a known prop": ["basalt_ridge", "marker", [21, -18]],
		"marker not a point": ["lab_quarter", "marker", [1]],
		"reach zero": ["badlands", "reach_m", 0],
		"reach negative": ["basalt_ridge", "reach_m", -5],
		"band reversed": ["frost_flats", "band", [30, 10]],
		"band below 1": ["farm", "band", [0, 5]],
		"band above 99": ["landing_field", "band", [20, 120]],
		"band fractional": ["lab_quarter", "band", [1.5, 20]],
		"bad tint": ["badlands", "tint", "rust"],
		"empty sign": ["frost_flats", "sign", " "],
		"unknown zone": ["basalt_ridge", "zone_entrance", "moon_base"],
		"entrance with no zone": ["lab_quarter", "entrance_at", [-50, -30]],
		"unknown role": ["lab_quarter", "role", "wedge"],
		"marker in another biome": ["lab_quarter", "marker", [0, 40]],
		"bearing far off": ["frost_flats", "bearing_deg", 180],
		"reach field wrong type": ["farm", "reach_m", "wide"],
	}
	for label: String in cases:
		var c: Array = cases[label]
		var bad: Array = _with(c[0], c[1], c[2])
		if BiomeData.problems(bad).is_empty():
			return "The check did not catch: %s." % label
	return ""


func test_a_missing_hub_or_open_row_is_refused() -> String:
	var without_hub: Array = _good_rows().filter(func(r: Dictionary) -> bool: return r["id"] != "farm")
	var without_open: Array = _good_rows().filter(func(r: Dictionary) -> bool: return r["id"] != "badlands")
	if BiomeData.problems(without_hub).is_empty() or BiomeData.problems(without_open).is_empty():
		return "A table with no hub or no open biome must be refused"
	return ""


func test_a_missing_field_and_a_non_object_are_refused() -> String:
	var rows: Array = _good_rows()
	(rows[1] as Dictionary).erase("sign")
	var lines: Array[String] = BiomeData.problems(rows)
	if lines.is_empty() or not "lab_quarter: missing sign" in lines:
		return "A row with no sign must say so, got %s" % [lines]
	if BiomeData.problems([7]).is_empty():
		return "A row that is not an object must be refused"
	return ""


func test_the_messages_name_the_row_and_the_fault() -> String:
	var lines: Array[String] = BiomeData.problems(_with("frost_flats", "centre", [0, -130]))
	if lines.size() != 1 or not lines[0].begins_with("frost_flats: centre") or not "240 m land" in lines[0]:
		return "Unclear message: %s" % [lines]
	lines = BiomeData.problems(_with("badlands", "reach_m", 0))
	if lines.is_empty() or lines[0] != "badlands: reach_m must be above 0":
		return "Unclear message: %s" % [lines]
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
