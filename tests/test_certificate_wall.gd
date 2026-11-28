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


func _quest_entry(done_day: int, steps: Array = ["step_1"], accepted_day: int = -1) -> Dictionary:
	return {
		"accepted": accepted_day if accepted_day >= 0 else maxi(done_day - 1, 1),
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
	# Passed audit (day 7), failed audit (day 14), real grace-warning audit (passed: false, warning: true, day 21).
	gs.audit_log.append(_audit_report(7, true))
	gs.audit_log.append(_audit_report(14, false))
	gs.audit_log.append(_audit_report(21, false, true))
	# Malformed audit_log rows (unvalidated keys from saves / sync) must not crash or qualify.
	gs.audit_log.append({"day": 22, "passed": null, "warning": "bad"})
	gs.audit_log.append({"day": 23, "passed": "yes", "warning": null})
	gs.audit_log.append({"day": 24, "passed": 1, "warning": false})
	# Done lab quest (day 3), migrated done lab quest without closed_when and empty steps_done (day 4),
	# open lab quest (undone), and a real closed_when quest (first_contract: done == accepted, steps_done empty).
	gs.quest_state["first_calibration"] = _quest_entry(3, ["calibrate"])
	gs.quest_state["every_sticker_counts"] = _quest_entry(4, [], 3)
	gs.quest_state["paperwork_from_orbit"] = _quest_entry(-1, [])
	gs.quest_state["first_contract"] = _quest_entry(4, [], 4)
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
	if frames.size() != 3:
		problem = "Expected 3 certificate frames (2 done lab quests + 1 passed audit), found %d." % frames.size()
	var shown: Array[Dictionary] = wall.shown_certificates()
	if problem == "" and (shown[0]["title"] != "First Calibration" or int(shown[0]["day"]) != 3):
		problem = "Oldest certificate should be First Calibration (Day 3), got %s." % [shown[0]]
	if problem == "" and (shown[1]["title"] != "Every Sticker Counts" or int(shown[1]["day"]) != 4):
		problem = "Second certificate should be Every Sticker Counts (Day 4), got %s." % [shown[1]]
	if problem == "" and (shown[2]["title"] != "Clean Audit" or int(shown[2]["day"]) != 7):
		problem = "Newest certificate should be last: Clean Audit (Day 7), got %s." % [shown[2]]
	var clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and clicks.size() != 3:
		problem = "Expected 3 clickables for 3 certificates, found %d." % clicks.size()
	var heard: Array[String] = []
	wall.inspected.connect(func(text: String) -> void: heard.append(text))
	if problem == "":
		if clicks[0].hint != "First Calibration (Day 3)":
			problem = "Unexpected first certificate hover text: '%s'" % clicks[0].hint
		elif clicks[2].hint != "Clean Audit (Day 7)":
			problem = "Unexpected third certificate hover text: '%s'" % clicks[2].hint
		else:
			clicks[2].clicked.emit()
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

	var host := Node3D.new()
	var pad_pointer := DomePadPointer.new()
	pad_pointer.name = "DomePadPointer"
	host.add_child(pad_pointer)
	var wall := CertificateWall.new()
	wall.set_farm(gs)
	host.add_child(wall)
	_root().add_child(host)

	var problem: String = ""
	if not _certificate_nodes(wall).is_empty():
		problem = "Should start locked below level 8."

	# Hover the locked plaque via set_hover(true), then unlock via lab_xp_changed.
	var plaque_clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and not plaque_clicks.is_empty():
		plaque_clicks[0].set_hover(true)
	_at_level(gs, 8)
	gs.lab_xp_changed.emit()
	if problem == "" and Clickable.hovered != null:
		problem = "Rebuilding the wall must clear a hovered Clickable before freeing it."
	if problem == "" and Input.get_current_cursor_shape() != Input.CURSOR_ARROW:
		problem = "Rebuilding a hovered Clickable must reset the cursor to CURSOR_ARROW."
	if problem == "" and wall.get_node_or_null("Board") == null:
		problem = "Reaching level 8 must rebuild the wall with its backing board."

	# Select the unlocked empty plaque via DomePadPointer, then complete a lab quest.
	var empty_clicks: Array[Clickable] = _clickables_in(wall)
	if problem == "" and not empty_clicks.is_empty():
		pad_pointer.set_selection(empty_clicks[0])
	gs.quest_state["first_calibration"] = _quest_entry(6, ["calibrate"])
	gs.quests_changed.emit()
	if problem == "" and pad_pointer.selected != null:
		problem = "Rebuilding the wall must clear DomePadPointer selection pointing at a freed child."
	if problem == "" and Clickable.hovered != null:
		problem = "Clearing DomePadPointer selection on rebuild must also clear Clickable.hovered."
	if problem == "" and Input.get_current_cursor_shape() != Input.CURSOR_ARROW:
		problem = "Clearing DomePadPointer selection on rebuild must reset cursor to CURSOR_ARROW."
	var frames: Array[Node3D] = _certificate_nodes(wall)
	if problem == "" and frames.size() != 1:
		problem = "Completing a lab quest must rebuild the wall with 1 frame, found %d." % frames.size()
	if problem == "" and wall.shown_certificates()[0]["title"] != "First Calibration":
		problem = "Expected First Calibration on the wall, got %s." % [wall.shown_certificates()]

	# Rebuild on audit_completed(report).
	var audit_rep: Dictionary = _audit_report(9, true)
	gs.audit_log.append(audit_rep)
	gs.audit_completed.emit(audit_rep)
	if problem == "" and _certificate_nodes(wall).size() != 2:
		problem = "audit_completed must rebuild the wall with 2 frames, found %d." % _certificate_nodes(wall).size()
	if problem == "" and wall.shown_certificates()[-1]["title"] != "Clean Audit":
		problem = "Expected Clean Audit after audit_completed, got %s." % [wall.shown_certificates()]

	# Rebuild on farm_loaded.
	gs.audit_log.append(_audit_report(12, true))
	gs.farm_loaded.emit()
	if problem == "" and _certificate_nodes(wall).size() != 3:
		problem = "farm_loaded must rebuild the wall with 3 frames, found %d." % _certificate_nodes(wall).size()
	if problem == "" and int(wall.shown_certificates()[-1]["day"]) != 12:
		problem = "Expected Day 12 audit after farm_loaded, got %s." % [wall.shown_certificates()[-1]]

	_root().remove_child(host)
	host.free()
	Clickable.hovered = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	gs.free()
	return problem


## Inner surface X (in meters) of dome_room.glb's inward vault ribs at height `y_m`,
## from tools/voxgen/build_models.py dome_room() (scale 0.2, rib a_i = 33.5, b_i = 26.0).
static func _vault_rib_inner_x(y_m: float) -> float:
	const VOXEL: float = 0.2
	const RIB_A_IN: float = 33.5
	const RIB_B_IN: float = 26.0
	var vy: int = maxi(0, int(floor(y_m / VOXEL)))
	var py: float = float(vy) + 0.5
	if py >= RIB_B_IN:
		return 0.0
	var x_lim: float = RIB_A_IN * sqrt(1.0 - pow(py / RIB_B_IN, 2.0))
	var x_solid: int = int(floor(x_lim - 0.5)) + 1
	return float(x_solid) * VOXEL


static func _aabb_from_corners(corners: Array[Vector3]) -> AABB:
	var box := AABB(corners[0], Vector3.ZERO)
	for p: Vector3 in corners.slice(1):
		box = box.expand(p)
	return box


func test_dome_scene_wires_certificate_wall() -> String:
	var prev_picking: bool = _root().physics_object_picking
	var dome: Node = DOME.instantiate()
	_root().add_child(dome)
	var wall: CertificateWall = dome.get_node_or_null("CertificateWall") as CertificateWall
	var shelf: KeepsakeShelf = dome.get_node_or_null("KeepsakeShelf") as KeepsakeShelf
	var cam: Camera3D = dome.get_node_or_null("Camera3D") as Camera3D
	var problem: String = ""
	if wall == null:
		problem = "dome_interior.tscn must include a CertificateWall node."
	elif not wall.inspected.is_connected(Callable(dome, "_toast")):
		problem = "DomeInterior must connect CertificateWall.inspected to _toast."
	elif shelf != null and wall.position.distance_to(shelf.position) < 2.0:
		problem = "CertificateWall must be clear of KeepsakeShelf."

	# Pin placement against dome_room.glb vault inner surface (build_models.py) and camera view.
	if problem == "":
		var half_x: float = CertificateWall.BOARD_SIZE.x / 2.0
		var half_y: float = CertificateWall.BOARD_SIZE.y / 2.0
		var half_z: float = CertificateWall.BOARD_SIZE.z / 2.0
		var front_z: float = half_z + CertificateWall.FRAME_SIZE.z + 0.02
		var corners: Array[Vector3] = []
		for lx: float in [-half_x, half_x]:
			for ly: float in [-half_y - 0.12, half_y]:
				for lz: float in [-half_z, front_z]:
					corners.append(wall.global_transform * Vector3(lx, ly, lz))
		var visible_rect: Rect2 = _root().get_visible_rect()
		for p: Vector3 in corners:
			var inner_x: float = _vault_rib_inner_x(p.y)
			if p.y < 0.0:
				problem = "CertificateWall corner %s dips below the floor." % [p]
				break
			if p.z <= -3.7:
				problem = "CertificateWall corner %s is inside or behind the dome back wall." % [p]
				break
			if absf(p.x) >= inner_x - 0.1:
				problem = "CertificateWall corner %s is inside/too close to the dome vault rib (inner X = %.2f m)." % [p, inner_x]
				break
			if cam != null and (cam.is_position_behind(p) or not visible_rect.has_point(cam.unproject_position(p))):
				problem = "CertificateWall corner %s is outside the dome camera view." % [p]
				break

		# Pin clearance against right-side props (PlanBoard, EnvChamberCartModel, RightBench, RefMeterModel).
		if problem == "":
			var wall_aabb: AABB = _aabb_from_corners(corners)
			var prop_boxes: Array[Dictionary] = []
			var plan_board: Node3D = dome.get_node_or_null("PlanBoard") as Node3D
			if plan_board != null:
				prop_boxes.append({"name": "PlanBoard", "box": AABB(plan_board.global_position - Vector3(1.15, 0.65, 0.2), Vector3(2.3, 1.3, 0.4))})
			var cart: Node3D = dome.get_node_or_null("EnvChamberCartModel") as Node3D
			if cart != null:
				prop_boxes.append({"name": "EnvChamberCartModel", "box": AABB(cart.global_position - Vector3(0.7, 0.0, 0.5), Vector3(1.4, 1.65, 1.0))})
			var bench: Node3D = dome.get_node_or_null("RightBench") as Node3D
			if bench != null:
				prop_boxes.append({"name": "RightBench", "box": AABB(bench.global_position - Vector3(1.0, 0.45, 0.7), Vector3(2.0, 0.9, 1.4))})
			for prop: Dictionary in prop_boxes:
				if wall_aabb.intersects(prop["box"] as AABB):
					problem = "CertificateWall overlaps %s." % prop["name"]
					break
			# Ensure camera line-of-sight to wall corners is not occluded by EnvChamberCartModel.
			if problem == "" and cam != null and cart != null:
				var cart_box := AABB(cart.global_position - Vector3(0.7, 0.0, 0.5), Vector3(1.4, 1.65, 1.0))
				for p: Vector3 in corners:
					if cart_box.intersects_segment(cam.global_position, p) != null:
						problem = "EnvChamberCartModel occludes CertificateWall corner %s from Camera3D." % [p]
						break

	_root().remove_child(dome)
	dome.free()
	_root().physics_object_picking = prev_picking
	Clickable.hovered = null
	return problem
