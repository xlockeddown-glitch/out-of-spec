extends RefCounted
## The soft-gate warning (docs/design/zones.md section 7.1, build step 3) and the
## zone rows of lab_gates (section 7.2): a player under a band's start is told,
## in plain words, and is never walled; zone rows gate nothing yet.


func test_under_the_band_the_tunnels_warn() -> String:
	var text: String = ZoneData.warning_text(&"lava_tubes", 3)
	for part: String in ["Recommended lab level 5", "You are level 3", "Go anyway?"]:
		if not text.contains(part):
			return "The warning lacks '%s': %s" % [part, text]
	if not text.contains(ZoneData.WARNING_SOFT):
		return "The tunnels have no hard gate yet, so the soft line: %s" % text
	return ""


func test_at_or_above_the_band_start_there_is_no_warning() -> String:
	for level: int in [5, 6, 20, 60, 99]:
		if ZoneData.warning_text(&"lava_tubes", level) != "":
			return "Level %d needs no warning." % level
	if ZoneData.warning_text(&"lava_tubes", 4) == "":
		return "Level 4 is under the band."
	if ZoneData.warning_text(&"nowhere", 1) != "":
		return "An unknown zone has no warning."
	return ""


func test_a_hard_gate_deeper_down_is_named() -> String:
	var row: Dictionary = { "band": [12, 30] }
	var plain: String = ZoneData.warning_for(row, 6)
	var hard: String = ZoneData.warning_for(row, 6, 18)
	if not plain.contains("Recommended lab level 12") or plain.contains("Deeper"):
		return "Without a gate the line is soft: %s" % plain
	if not hard.contains("Deeper levels need a lab level of 18") or hard.contains(ZoneData.WARNING_SOFT):
		return "With a gate the line names it: %s" % hard
	if ZoneData.warning_for(row, 12, 18) != "" or ZoneData.warning_for({}, 1) != "":
		return "No warning at the start, or without a band."
	return ""


func test_the_warning_is_not_a_wall() -> String:
	# A new lab (level 1, under the band) can still drive the rover in: only the
	# warning speaks, and move_rover never refuses over a level.
	var gs: GameState = preload("res://scripts/autoload/GameState.gd").new()
	gs.build_registry()
	var problem: String = ""
	if gs.lab_level() >= ZoneData.band(&"lava_tubes").x:
		problem = "Setup: a new lab is under the Lava Tubes band."
	elif ZoneData.warning_text(&"lava_tubes", gs.lab_level()) == "":
		problem = "A new lab is warned."
	else:
		gs.park_rover(gs.ROVER, Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD + Vector3(1.0, 0.0, 0.0)))
		var said: String = gs.move_rover(true)
		if said.contains("lab level") or (said != "" and said != TunnelRecall.text("closed_text")):
			problem = "The tunnels refused a low lab: %s" % said
		elif said == "" and not gs.rover_in_tunnels:
			problem = "The rover did not go in."
	if problem == "":
		for id: String in ["lava_tubes_warning", "aquifer_hub", "colony_mine_hub", "ice_caves_hub", "deimos_hub"]:
			if gs.lab_gate_level(id) != 0 or not gs.lab_gate_open(id):
				problem = "The hub row %s must gate nothing (hubs are never hard-gated)." % id
	gs.free()
	return problem


func test_a_deep_gate_must_name_a_row() -> String:
	var good: Dictionary = (ZoneData.rows()[0] as Dictionary).duplicate(true)
	good["deep_gate"] = "lava_tubes_deep"
	if not ZoneData.problems([good]).is_empty():
		return "A real row is fine: %s" % [ZoneData.problems([good])]
	good["deep_gate"] = "no_such_row"
	if ZoneData.problems([good]).is_empty():
		return "A deep_gate that is no row must be caught."
	return ""


func test_the_zone_rows_are_in_order_and_gate_nothing() -> String:
	var wanted: Dictionary = {
		"lava_tubes_warning": 5, "aquifer_hub": 8, "lava_tubes_deep": 10, "colony_mine_hub": 12,
		"aquifer_deep": 14, "ice_caves_hub": 18, "shuttle_license": 20, "mine_deep": 24,
		"deimos_hub": 26, "expedition_permit": 30, "ice_caves_cores": 35, "phobos_deep": 40,
		"deimos_deep": 45,
	}
	var seen: int = 0
	var gs: GameState = preload("res://scripts/autoload/GameState.gd").new()
	gs.build_registry()
	var problem: String = ""
	for row: Dictionary in DataManager.get_records(&"skills", "lab_gates"):
		var id: String = str(row["id"])
		if not wanted.has(id):
			continue
		seen += 1
		if int(row["level"]) != int(wanted[id]):
			problem = "%s is at level %d, the doc says %d." % [id, int(row["level"]), int(wanted[id])]
		elif id == "expedition_permit":
			# Built by zones step 18: it gates the expedition booking.
			if not row.get("built", false) or row.get("beat", false):
				problem = "expedition_permit must be built and no beat."
		elif id == "lava_tubes_deep":
			# Built by zones step 11: it gates depth 4 and below of the Lava Tubes.
			if not row.get("built", false) or row.get("beat", false) or gs.lab_gate_level(id) != 10:
				problem = "lava_tubes_deep must be built, level 10 and no beat."
		elif row.get("built", true) or row.get("beat", false):
			problem = "%s must be built:false and no beat." % id
		elif gs.lab_gate_level(id) != 0 or not gs.lab_gate_open(id):
			problem = "%s gates something." % id
	gs.free()
	if problem == "" and seen != wanted.size():
		problem = "%d of %d zone rows are in the table." % [seen, wanted.size()]
	return problem
