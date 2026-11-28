extends RefCounted
## Tests for CertificateWall (scripts/dome/certificate_wall.gd) and the
## `certificate_wall` lab-gate row in data/skills.json. Every GameState and
## Node3D created here is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DOME: PackedScene = preload("res://scenes/dome_interior.tscn")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	return gs


func _at_level(gs: GameStateScript, level: int) -> void:
	gs.lab_xp = gs.xp_for_level(level)


func _quest_entry(done_day: int, steps: Array = ["step_1"]) -> Dictionary:
	return {
		"accepted": maxi(done_day - 1, 1),
		"steps_done": steps,
		"base": {},
		"shown": {},
		"players": [GameState.local_player_id],
		"done": done_day,
	}


func _audit_report(day: int, passed: bool, warning: bool = false) -> Dictionary:
	return {
		"day": day,
		"lines": [],
		"total_fine": 0 if passed else 50,
		"passed": passed,
		"warning": warning,
		"cal_records": 1,
		"cal_fails_found": 0,
		"suspect_units": 0,
	}


func _clickables_in(node: Node) -> Array[Clickable]:
	var out: Array[Clickable] = []
	for child: Node in node.get_children():
		if child is Clickable:
			out.append(child as Clickable)
		out.append_array(_clickables_in(child))
	return out


func _certificate_nodes(wall: CertificateWall) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child: Node in wall.get_children():
		if child is Node3D and child.is_in_group(CertificateWall.GROUP_ITEM) and child.name.begins_with("Certificate_"):
			out.append(child as Node3D)
	return out


func test_gate_row_reads_built() -> String:
	var row: Dictionary = DataManager.get_record(&"skills", &"certificate_wall", "lab_gates")
	if row.is_empty():
		return "The certificate_wall gate row is missing from data/skills.json."
	if not bool(row.get("built", false)):
		return "The certificate_wall gate row must read built: true."
	var gs: GameStateScript = _state()
	var problem: String = ""
	if gs.lab_gate_level("certificate_wall") != 8:
		problem = "Expected certificate_wall gate level 8, got %d." % gs.lab_gate_level("certificate_wall")
	_at_level(gs, 7)
	if problem == "" and gs.lab_gate_open("certificate_wall"):
		problem = "certificate_wall gate must stay closed at lab level 7."
	_at_level(gs, 8)
	if problem == "" and not gs.lab_gate_open("certificate_wall"):
		problem = "certificate_wall gate must open at lab level 8."
	gs.free()
	return problem


func test_below_level_8_shows_plaque_only_no_certificates() -> String:
	var gs: GameStateScript = _state()
	_at_level(gs, 7)
	gs.audit_log.append(_audit_report(5, true))
	gs.quest_state["first_calibration"] = _quest_entry(3, ["calibrate"])

	var wall := CertificateWall.new()
	wall.set_farm(gs)
	wall.refresh()

	var problem: String = ""
	var frames: Array[Node3D] = _certificate_nodes(wall)
	if not frames.is_empty():
		problem = "Below level 8 there must be no certificate frames, found %d." % frames.size()
	var plaque: Node = wall.get_node_or_null("Plaque")
	if problem == "" and plaque == null:
		problem = "Below level 8 the bare plaque must be shown."
	var clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and clicks.size() != 1:
		problem = "Expected 1 clickable on the bare plaque, found %d." % clicks.size()
	if problem == "" and clicks[0].hint != "Certificate wall: lab level 8":
		problem = "Unexpected plaque hover text: '%s'" % clicks[0].hint
	var heard: Array[String] = []
	wall.inspected.connect(func(text: String) -> void: heard.append(text))
	if problem == "":
		clicks[0].clicked.emit()
		if heard.size() != 1 or heard[0] != "Certificate wall: lab level 8":
			problem = "Clicking the plaque must emit its locked text, got %s." % [heard]
	wall.free()
	gs.free()
	return problem


func test_at_level_8_shows_passed_audits_and_done_lab_quests_only() -> String:
	var gs: GameStateScript = _state()
	_at_level(gs, 8)
	# Passed audit (day 7), failed audit (day 14), grace warning audit (day 21).
	gs.audit_log.append(_audit_report(7, true))
	gs.audit_log.append(_audit_report(14, false))
	gs.audit_log.append(_audit_report(21, true, true))
	# Done lab quest (day 3), open lab quest (undone), closed lab quest (0 steps done).
	gs.quest_state["first_calibration"] = _quest_entry(3, ["calibrate"])
	gs.quest_state["paperwork_from_orbit"] = _quest_entry(-1, [])
	gs.quest_state["every_sticker_counts"] = _quest_entry(4, [])
	# Done story quest (must not appear) and done personal quest (must not appear).
	gs.quest_state["first_water"] = _quest_entry(2, ["plant"])
	gs.player_quest_state[gs.local_player_id] = {
		"missing_blocks": _quest_entry(5, ["find", "check", "stack"]),
	}

	var wall := CertificateWall.new()
	wall.set_farm(gs)
	wall.refresh()

	var problem: String = ""
	var frames: Array[Node3D] = _certificate_nodes(wall)
	if frames.size() != 2:
		problem = "Expected 2 certificate frames (1 done lab quest + 1 passed audit), found %d." % frames.size()
	var shown: Array[Dictionary] = wall.shown_certificates()
	if problem == "" and (shown[0]["title"] != "First Calibration" or int(shown[0]["day"]) != 3):
		problem = "Oldest certificate should be First Calibration (Day 3), got %s." % [shown[0]]
	if problem == "" and (shown[1]["title"] != "Clean Audit" or int(shown[1]["day"]) != 7):
		problem = "Newest certificate should be last: Clean Audit (Day 7), got %s." % [shown[1]]
	var clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and clicks.size() != 2:
		problem = "Expected 2 clickables for 2 certificates, found %d." % clicks.size()
	var heard: Array[String] = []
	wall.inspected.connect(func(text: String) -> void: heard.append(text))
	if problem == "":
		if clicks[0].hint != "First Calibration (Day 3)":
			problem = "Unexpected first certificate hover text: '%s'" % clicks[0].hint
		elif clicks[1].hint != "Clean Audit (Day 7)":
			problem = "Unexpected second certificate hover text: '%s'" % clicks[1].hint
		else:
			clicks[1].clicked.emit()
			if heard.size() != 1 or heard[0] != "Clean Audit (Day 7)":
				problem = "Clicking a certificate must emit its name and day, got %s." % [heard]
	wall.free()
	gs.free()
	return problem


func test_cap_and_plus_n_more() -> String:
	var gs: GameStateScript = _state()
	_at_level(gs, 8)
	var total: int = CertificateWall.MAX_SHOWN + 3
	for d: int in range(1, total + 1):
		gs.audit_log.append(_audit_report(d, true))

	var wall := CertificateWall.new()
	wall.set_farm(gs)
	wall.refresh()

	var problem: String = ""
	var frames: Array[Node3D] = _certificate_nodes(wall)
	if frames.size() != CertificateWall.MAX_SHOWN:
		problem = "Expected %d capped frames, found %d." % [CertificateWall.MAX_SHOWN, frames.size()]
	if problem == "" and wall.hidden_count() != 3:
		problem = "Expected hidden_count() == 3, got %d." % wall.hidden_count()
	var shown: Array[Dictionary] = wall.shown_certificates()
	if problem == "" and (int(shown[0]["day"]) != 4 or int(shown[-1]["day"]) != total):
		problem = "Expected newest %d shown (days 4..%d), got days %d..%d." % [
			CertificateWall.MAX_SHOWN, total, int(shown[0]["day"]), int(shown[-1]["day"])]
	var clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and (clicks.is_empty() or not clicks[-1].hint.contains("+3 more")):
		problem = "Hover text over cap must include '+3 more': '%s'" % (clicks[-1].hint if not clicks.is_empty() else "")
	var more_node: Node = wall.get_node_or_null("More")
	if problem == "" and (not (more_node is Label3D) or (more_node as Label3D).text != "+3 more"):
		problem = "Overflow Label3D must read '+3 more'."
	wall.free()
	gs.free()
	return problem


func test_rebuilds_when_quest_is_done_and_clears_hover() -> String:
	var gs: GameStateScript = _state()
	_at_level(gs, 7)

	var wall := CertificateWall.new()
	wall.set_farm(gs)
	_root().add_child(wall)

	var problem: String = ""
	if not _certificate_nodes(wall).is_empty():
		problem = "Should start locked below level 8."

	# Hover the locked plaque, then unlock via lab_xp_changed.
	var plaque_clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and not plaque_clicks.is_empty():
		Clickable.hovered = plaque_clicks[0]
	_at_level(gs, 8)
	gs.lab_xp_changed.emit()
	if problem == "" and Clickable.hovered != null:
		problem = "Rebuilding the wall must clear a hovered Clickable before freeing it."
	if problem == "" and wall.get_node_or_null("Board") == null:
		problem = "Reaching level 8 must rebuild the wall with its backing board."

	# Complete a lab quest and emit quests_changed.
	gs.quest_state["first_calibration"] = _quest_entry(6, ["calibrate"])
	gs.quests_changed.emit()
	var frames: Array[Node3D] = _certificate_nodes(wall)
	if problem == "" and frames.size() != 1:
		problem = "Completing a lab quest must rebuild the wall with 1 frame, found %d." % frames.size()
	if problem == "" and wall.shown_certificates()[0]["title"] != "First Calibration":
		problem = "Expected First Calibration on the wall, got %s." % [wall.shown_certificates()]

	_root().remove_child(wall)
	wall.free()
	Clickable.hovered = null
	gs.free()
	return problem


func test_dome_scene_wires_certificate_wall() -> String:
	var dome: Node = DOME.instantiate()
	_root().add_child(dome)
	var wall: CertificateWall = dome.get_node_or_null("CertificateWall") as CertificateWall
	var shelf: KeepsakeShelf = dome.get_node_or_null("KeepsakeShelf") as KeepsakeShelf
	var problem: String = ""
	if wall == null:
		problem = "dome_interior.tscn must include a CertificateWall node."
	elif shelf != null and wall.position.distance_to(shelf.position) < 2.0:
		problem = "CertificateWall must be clear of KeepsakeShelf."
	elif not wall.inspected.is_connected(Callable(dome, "_toast")):
		problem = "DomeInterior must connect CertificateWall.inspected to _toast."
	_root().remove_child(dome)
	dome.free()
	Clickable.hovered = null
	return problem
