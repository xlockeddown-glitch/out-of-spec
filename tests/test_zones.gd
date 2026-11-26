extends RefCounted
## data/zones.json (docs/design/zones.md section 2, build step 2): every row is
## sound, the bands are the doc's, and the readers answer from the table.

## The doc's bands (section 2); the far sites together span 50 to 99.
const BANDS: Dictionary = {
	&"lava_tubes": Vector2i(5, 20),
	&"flooded_aquifer": Vector2i(8, 24),
	&"colony_mine": Vector2i(12, 30),
	&"ice_caves": Vector2i(18, 35),
	&"phobos": Vector2i(21, 40),
	&"deimos": Vector2i(26, 50),
}


func _raw_rows() -> Array:
	var raw: Variant = DataManager.get_value(ZoneData.TABLE, ZoneData.SECTION, [])
	return raw if raw is Array else []


func test_every_row_is_sound() -> String:
	var problems: Array[String] = ZoneData.problems(_raw_rows())
	return "" if problems.is_empty() else "; ".join(problems)


func test_no_row_is_dropped_by_the_loader() -> String:
	var raw: int = _raw_rows().size()
	if raw == 0:
		return "The table has no rows."
	if ZoneData.ids().size() != raw:
		return "DataManager kept %d of %d rows (a required field is missing)." % [ZoneData.ids().size(), raw]
	return ""


func test_the_checker_catches_bad_rows() -> String:
	var good: Dictionary = (_raw_rows()[0] as Dictionary).duplicate(true)
	var cases: Dictionary = {
		"band reversed": ["band", [9, 3]],
		"band below 1": ["band", [0, 5]],
		"band above 99": ["band", [50, 100]],
		"band wrong size": ["band", [5]],
		"unknown hazard": ["hazards", ["lava_monster"]],
		"unknown find": ["finds", ["gold"]],
		"missing scene": ["hub_scene", "res://scenes/no_such_zone.tscn"],
		"unknown area": ["area", "orbit"],
		"name not a string": ["name", 7],
	}
	for label: String in cases:
		var bad: Dictionary = good.duplicate(true)
		bad[(cases[label] as Array)[0]] = (cases[label] as Array)[1]
		if ZoneData.problems([bad]).is_empty():
			return "The check did not catch: %s." % label
	var no_name: Dictionary = good.duplicate(true)
	no_name.erase("name")
	if ZoneData.problems([no_name]).is_empty():
		return "The check did not catch a missing field."
	if ZoneData.problems([good, good.duplicate(true)]).is_empty():
		return "The check did not catch a duplicate id."
	return ""


func test_bands_match_the_doc() -> String:
	for id: StringName in BANDS:
		if ZoneData.band(id) != BANDS[id]:
			return "%s band is %s, the doc says %s." % [id, ZoneData.band(id), BANDS[id]]
	var far_lo: int = 99
	var far_hi: int = 0
	var far: int = 0
	for row: Dictionary in ZoneData.rows():
		if row["area"] != "far":
			continue
		far += 1
		var b: Vector2i = ZoneData.band_of(row)
		far_lo = mini(far_lo, b.x)
		far_hi = maxi(far_hi, b.y)
	if far == 0 or far_lo != 50 or far_hi != 99:
		return "The far sites should cover 50 to 99, got %d to %d (%d rows)." % [far_lo, far_hi, far]
	return ""


func test_zones_for_level_allows_overlap() -> String:
	if ZoneData.zones_for_level(4) != ([] as Array[StringName]):
		return "Nothing is tuned for level 4: %s" % [ZoneData.zones_for_level(4)]
	if ZoneData.zones_for_level(5) != ([&"lava_tubes"] as Array[StringName]):
		return "Level 5 is the Lava Tubes only: %s" % [ZoneData.zones_for_level(5)]
	var at_22: Array[StringName] = ZoneData.zones_for_level(22)
	for id: StringName in [&"flooded_aquifer", &"colony_mine", &"ice_caves", &"phobos"]:
		if not at_22.has(id):
			return "Level 22 should include %s: %s" % [id, at_22]
	if at_22.has(&"deimos") or at_22.has(&"lava_tubes"):
		return "Deimos starts at 26 and the Lava Tubes end at 20."
	if ZoneData.zones_for_level(99) != ([&"outer_moons"] as Array[StringName]):
		return "Level 99 is the outer moons only: %s" % [ZoneData.zones_for_level(99)]
	if not ZoneData.zones_for_level(0).is_empty() or not ZoneData.zones_for_level(100).is_empty():
		return "Levels outside 1 to 99 have no zone."
	return ""


func test_the_tunnels_row_and_unknown_ids() -> String:
	if ZoneData.hub_scene(&"lava_tubes") != "res://scenes/basalt_tunnels.tscn":
		return "The Lava Tubes hub is the basalt tunnels scene."
	if ZoneData.hub_scene(&"phobos") != "":
		return "Phobos has no scene yet."
	if ZoneData.hub_scene(&"lava_tubes") != SceneSwitcher.TUNNELS_SCENE:
		return "The row and SceneSwitcher disagree about the tunnels scene."
	if ZoneData.has_zone(&"nowhere") or not ZoneData.zone(&"nowhere").is_empty() or ZoneData.band(&"nowhere") != Vector2i.ZERO:
		return "An unknown zone reads as empty."
	return ""
