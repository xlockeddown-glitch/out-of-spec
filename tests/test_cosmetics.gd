extends "res://tests/coop_net.gd"
## Slice 35: late-level cosmetics and titles (docs/design/quests_levels_story.md
## §3.4 rows 85/92/99, §4.2 rows 50/75/99, §4.3 total-level milestones).
## Restores every global it changes and frees every GameState and Node it creates.

const SyncScript: GDScript = preload("res://scripts/autoload/CoopSync.gd")
const DOME: PackedScene = preload("res://scenes/dome_interior.tscn")

var _syncs: Array[Node] = []
var _events: Array = []


func _make_gs() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 100000
	gs.crystal_ore = 50
	gs.optical_silk_spools = 3
	gs._spool_species.assign([&"a", &"b", &"c"])
	gs.tier1_unlocked = true
	return gs


func _set_lab_level(gs: GameStateScript, level: int) -> void:
	gs.lab_xp = gs.xp_for_level(level)


func _set_skill_level(gs: GameStateScript, skill_id: String, level: int, player_id: String = "") -> void:
	var pid: String = gs.local_player_id if player_id == "" else player_id
	if not gs.player_skill_xp.has(pid):
		gs.player_skill_xp[pid] = {}
	gs.player_skill_xp[pid][skill_id] = gs.xp_for_level(level)


func _add_robot(gs: GameStateScript, id: String = "TR-1") -> void:
	gs.robots[id] = {
		"frame": "trellis",
		"name": "Trellis " + id,
		"state": "released",
		"done_day": 1,
		"ordered_by": gs.local_player_id,
	}


func _own_standard(gs: GameStateScript, id: String) -> void:
	gs.owned_standards[id] = 0
	gs.get_sensor(id).cal_due_day = 1000
	gs._issue_certificate(id, 0, null, null, true)


func test_gates_read_built_and_protocol_is_51() -> String:
	var problem: String = ""
	if CoopSession.PROTOCOL != 51:
		return "Expected CoopSession.PROTOCOL == 51, got %d." % CoopSession.PROTOCOL
	for pair: Array in [[&"robot_paint", 85], [&"halfway_plaque", 92], [&"gold_border", 99]]:
		var row: Dictionary = DataManager.get_record(&"skills", pair[0], "lab_gates")
		if row.is_empty() or not bool(row.get("built", false)) or int(row.get("level", 0)) != int(pair[1]):
			return "Gate %s must be built: true at level %d, got %s." % [pair[0], pair[1], row]
	var gs: GameStateScript = _make_gs()
	for pair: Array in [["robot_paint", 85], ["halfway_plaque", 92], ["gold_border", 99]]:
		_set_lab_level(gs, int(pair[1]) - 1)
		if gs.lab_gate_open(str(pair[0])):
			problem = "Gate %s must stay closed at level %d." % [pair[0], int(pair[1]) - 1]
			break
		_set_lab_level(gs, int(pair[1]))
		if not gs.lab_gate_open(str(pair[0])):
			problem = "Gate %s must open at level %d." % [pair[0], int(pair[1])]
			break
	gs.free()
	return problem


func test_robot_paint_and_nameplate_gate_sanitize_and_stand() -> String:
	var gs: GameStateScript = _make_gs()
	_add_robot(gs, "TR-1")
	_set_lab_level(gs, 84)
	var problem: String = ""
	if gs.set_robot_cosmetic("TR-1", "teal", "Sparky") == "":
		problem = "Robot paint/nameplate must be refused below lab level 85."
	if problem == "" and (gs.robot_paint("TR-1") != "" or gs.robot_display_name("TR-1") != "Trellis TR-1"):
		problem = "Refused call must leave robot unchanged."
	_set_lab_level(gs, 85)
	if problem == "" and gs.set_robot_cosmetic("TR-1", "neon_pink", "Sparky") == "":
		problem = "Unknown paint color must be refused."
	if problem == "" and gs.set_robot_cosmetic("NO-SUCH", "teal", "Sparky") == "":
		problem = "Unknown robot id must be refused."
	# Sanitization and 12-char cap: strips control chars, "[", zero-width, and caps at 12.
	var dirty: String = "  \u0007[Alpha\u200BBetaGammaDelta  "
	if problem == "" and gs.set_robot_cosmetic("TR-1", "teal", dirty) != "":
		problem = "Valid paint and nameplate at lab 85 must succeed."
	var expected_plate: String = "AlphaBetaGam"
	if problem == "" and gs.robot_display_name("TR-1") != expected_plate:
		problem = "Expected sanitized/capped nameplate '%s', got '%s'." % [expected_plate, gs.robot_display_name("TR-1")]
	if problem == "" and gs.robot_paint("TR-1") != "teal":
		problem = "Expected robot paint 'teal', got '%s'." % gs.robot_paint("TR-1")
	# RobotStand renders paint color (ScopeTheme constant) and Label3D nameplate.
	var stand := RobotStand.new()
	stand.set_farm(gs)
	stand.refresh()
	var unit: Node = stand.get_node_or_null("Robot_TR-1")
	if problem == "" and unit == null:
		problem = "RobotStand must render Robot_TR-1."
	if problem == "":
		var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
		var plate: Label3D = unit.get_node_or_null("Nameplate") as Label3D
		if body == null or (body.material_override as StandardMaterial3D).albedo_color != ScopeTheme.TEAL:
			problem = "Robot mesh must use ScopeTheme.TEAL for teal paint."
		elif plate == null or plate.text != expected_plate:
			problem = "Robot Label3D must show '%s', got '%s'." % [expected_plate, plate.text if plate != null else "null"]
	stand.free()
	gs.free()
	return problem


func test_halfway_plaque_and_gold_border_on_wall() -> String:
	var gs: GameStateScript = _make_gs()
	_set_lab_level(gs, 91)
	gs.audit_log.append({ "day": 10, "lines": [], "total_fine": 0, "passed": true, "warning": false, "phone_count": 0 })
	var wall := CertificateWall.new()
	wall.set_farm(gs)
	wall.refresh()
	var problem: String = ""
	if wall.get_node_or_null("HalfwayPlaque") != null:
		problem = "HalfwayPlaque must be hidden at lab level 91."
	_set_lab_level(gs, 92)
	wall.refresh()
	var plaque: Node = wall.get_node_or_null("HalfwayPlaque")
	if problem == "" and plaque == null:
		problem = "HalfwayPlaque must appear at lab level 92."
	if problem == "":
		var lbl: Label3D = plaque.get_node_or_null("Label") as Label3D
		if lbl == null or lbl.text != "HALFWAY THERE":
			problem = "HalfwayPlaque Label3D must read 'HALFWAY THERE'."
	# Audit earned before 99 has no gold border; audit earned at 99 has gold border.
	_set_lab_level(gs, 99)
	gs.audit_log.append({ "day": 20, "lines": [], "total_fine": 0, "passed": true, "warning": false, "phone_count": 1, "gold_border": true })
	wall.refresh()
	var old_cert: Node = wall.get_node_or_null("Certificate_audit_10_0")
	var new_cert: Node = wall.get_node_or_null("Certificate_audit_20_1")
	if problem == "" and (old_cert == null or new_cert == null):
		problem = "Both audit certificates must appear on the wall."
	if problem == "":
		var old_mat: StandardMaterial3D = (old_cert.get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
		var new_mat: StandardMaterial3D = (new_cert.get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
		if old_mat.albedo_color != ScopeTheme.TERRA_DARK:
			problem = "Pre-99 certificate must keep standard frame color."
		elif new_mat.albedo_color != ScopeTheme.GOLD:
			problem = "Post-99 certificate must use ScopeTheme.GOLD frame color."
	wall.free()
	gs.free()
	return problem


func test_gold_border_only_on_certificates_after_99_and_odalys_mug_once() -> String:
	var saved_days: float = GameClock.elapsed_days
	GameClock.elapsed_days = 10.0
	var gs: GameStateScript = _make_gs()
	_own_standard(gs, "reference_gauge")
	_own_standard(gs, "field_meter_dc")
	_set_lab_level(gs, 98)
	var credits_before: int = gs.credits
	var cert_pre: Dictionary = gs._issue_certificate("reference_gauge", 10, 0.0, 0.0, false)
	var problem: String = ""
	if bool(cert_pre.get("gold_border", false)):
		problem = "Certificate issued at lab 98 must not have gold_border."
	if problem == "" and gs.odalys_mug_sent:
		problem = "Odalys's mug must not be sent below lab 99."
	# Cross to lab 99 via give_lab_xp -> mug arrives once, pays nothing.
	var needed: int = gs.xp_for_level(99) - gs.lab_xp
	gs.give_lab_xp(needed)
	var mug_lines: int = gs.phone_log.filter(func(l: String) -> bool: return "Warmly, Dispatch." in l and "mug" in l).size()
	if problem == "" and (not gs.odalys_mug_sent or mug_lines != 1):
		problem = "Odalys's mug must arrive once at lab 99 (sent=%s, lines=%d)." % [gs.odalys_mug_sent, mug_lines]
	if problem == "" and gs.credits != credits_before:
		problem = "Odalys's mug must pay nothing (credits %d -> %d)." % [credits_before, gs.credits]
	# Extra XP and a new morning must NOT send the mug a second time.
	gs.give_lab_xp(1000)
	gs._deliver_odalys_mug_if_due()
	var mug_lines_after: int = gs.phone_log.filter(func(l: String) -> bool: return "Warmly, Dispatch." in l and "mug" in l).size()
	if problem == "" and mug_lines_after != 1:
		problem = "Odalys's mug must only arrive once, got %d lines." % mug_lines_after
	var cert_post: Dictionary = gs._issue_certificate("reference_gauge", 11, 0.0, 0.0, false)
	if problem == "" and not bool(cert_post.get("gold_border", false)):
		problem = "Certificate issued at lab 99 must have gold_border."
	# Verify bench mug prop visibility in DomeInterior.
	var saved_mug: bool = GameState.odalys_mug_sent
	GameState.odalys_mug_sent = false
	var dome: Node3D = DOME.instantiate() as Node3D
	(Engine.get_main_loop() as SceneTree).root.add_child(dome)
	var mug_node: Node3D = dome.get_node_or_null("OdalysMug") as Node3D
	if problem == "" and (mug_node == null or mug_node.visible):
		problem = "OdalysMug prop must exist and be hidden before mug arrives."
	GameState.odalys_mug_sent = true
	dome._show_mug_ring()
	if problem == "" and (mug_node == null or not mug_node.visible):
		problem = "OdalysMug prop must be visible once mug arrives."
	dome.get_parent().remove_child(dome)
	dome.free()
	GameState.odalys_mug_sent = saved_mug
	gs.free()
	GameClock.elapsed_days = saved_days
	return problem


func test_personal_cosmetics_lab_coat_initials_and_99_title() -> String:
	var saved_days: float = GameClock.elapsed_days
	GameClock.elapsed_days = 10.0
	var gs: GameStateScript = _make_gs()
	_own_standard(gs, "pressure_controller")
	_own_standard(gs, "reference_gauge")
	var problem: String = ""
	# Lab coat color: refused at 49, allowed at 50, shown on WalkerModel, preserved by set_loadout.
	_set_skill_level(gs, "agronomy", 49, "player_1")
	if gs.set_lab_coat_color("teal", "player_1") == "":
		problem = "Lab coat color must be refused below skill level 50."
	_set_skill_level(gs, "agronomy", 50, "player_1")
	if problem == "" and gs.set_lab_coat_color("invalid", "player_1") == "":
		problem = "Unknown lab coat color must be refused."
	if problem == "" and gs.set_lab_coat_color("teal", "player_1") != "":
		problem = "Lab coat color must succeed at skill level 50."
	if problem == "" and gs.set_loadout("Ada Lovelace", Loadout.encode(Loadout.default_parts()), "player_1") != "":
		problem = "set_loadout must succeed."
	if problem == "" and gs.lab_coat_color("player_1") != "teal":
		problem = "set_loadout must preserve lab coat color."
	var walker := WalkerModel.new()
	walker.set_coat_color(gs.lab_coat_color("player_1"))
	var coat_mesh: MeshInstance3D = walker.get_node_or_null("LabCoatColor") as MeshInstance3D
	if problem == "" and (coat_mesh == null or (coat_mesh.mesh.material as StandardMaterial3D).albedo_color != ScopeTheme.TEAL):
		problem = "WalkerModel must show ScopeTheme.TEAL for teal lab coat."
	walker.free()
	# Calibration 75 initials: only for the calibrating player at Calibration 75+.
	_set_skill_level(gs, "calibration", 74, "player_1")
	var rec_74: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_1", true)
	if problem == "" and str(rec_74.get("cal_initials", "")) != "":
		problem = "Initials must not appear at Calibration 74."
	_set_skill_level(gs, "calibration", 75, "player_1")
	var rec_75: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_1", true)
	if problem == "" and str(rec_75.get("cal_initials", "")) != "AL":
		problem = "Expected initials 'AL' for Ada Lovelace at Calibration 75, got '%s'." % str(rec_75.get("cal_initials", ""))
	# Player 2 at Calibration 1 gets NO initials.
	var rec_p2: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_2", true)
	if problem == "" and str(rec_p2.get("cal_initials", "")) != "":
		problem = "Player 2 below Calibration 75 must not get initials."
	# Any skill 99: title on in-house certificates ("<Skill> 99").
	var rec_std_pre: Dictionary = gs.calibrate("reference_gauge", "player_1", true)
	var cert_std_pre: Dictionary = gs.certificates.get("reference_gauge", {})
	if problem == "" and (rec_std_pre.get("refused", false) or str(cert_std_pre.get("cert_title", "")) != ""):
		problem = "Certificate title must not appear below level 99."
	_set_skill_level(gs, "calibration", 99, "player_1")
	var rec_std_99: Dictionary = gs.calibrate("reference_gauge", "player_1", true)
	var cert_std_99: Dictionary = gs.certificates.get("reference_gauge", {})
	if problem == "" and (rec_std_99.get("refused", false) or str(cert_std_99.get("cert_title", "")) != "Calibration 99"):
		problem = "Expected certificate title 'Calibration 99', got '%s'." % str(cert_std_99.get("cert_title", ""))
	if problem == "" and str(cert_std_99.get("cal_initials", "")) != "AL":
		problem = "In-house certificate at Calibration 75+ must carry initials 'AL'."
	gs.free()
	GameClock.elapsed_days = saved_days
	return problem


func test_total_level_milestone_titles() -> String:
	var cases: Array = [
		[7, ""],
		[49, ""],
		[50, "Apprentice"],
		[149, "Apprentice"],
		[150, "Technician"],
		[299, "Technician"],
		[300, "Metrologist"],
		[499, "Metrologist"],
		[500, "Principal"],
		[692, "Principal"],
		[693, "In Spec"],
	]
	for pair: Array in cases:
		var got: String = Cosmetics.total_level_title(int(pair[0]))
		if got != str(pair[1]):
			return "At total level %d expected '%s', got '%s'." % [int(pair[0]), pair[1], got]
	var gs: GameStateScript = _make_gs()
	gs.set_loadout("Quill", Loadout.encode(Loadout.default_parts()), "player_1")
	# 7 skills at level 1 -> total 7 -> no title.
	var problem: String = ""
	if "Apprentice" in SkillsUI.total_level_text(gs, "player_1"):
		problem = "No title should show at total level 7."
	_set_skill_level(gs, "calibration", 44, "player_1")  # 44 + 6*1 = 50 -> Apprentice
	if problem == "" and not "Apprentice" in SkillsUI.total_level_text(gs, "player_1"):
		problem = "SKILLS view must show Apprentice at total 50."
	if problem == "" and Cosmetics.name_tag_text(gs, "player_1") != "Quill · Apprentice":
		problem = "Name tag must show 'Quill · Apprentice', got '%s'." % Cosmetics.name_tag_text(gs, "player_1")
	var coop_text: String = CoopUI.players_text(["player_1"], "player_1", {}, false, gs)
	if problem == "" and not "APPRENTICE" in coop_text:
		problem = "CoopUI.players_text must show APPRENTICE, got '%s'." % coop_text
	gs.free()
	return problem


func test_save_load_and_old_save_defaults() -> String:
	var saved_days: float = GameClock.elapsed_days
	GameClock.elapsed_days = 12.0
	var gs: GameStateScript = _make_gs()
	_add_robot(gs, "TR-1")
	_set_lab_level(gs, 99)
	gs._deliver_odalys_mug_if_due()
	gs.set_robot_cosmetic("TR-1", "amber", "Bolt-9")
	_set_skill_level(gs, "uncertainty", 50, "player_1")
	gs.set_lab_coat_color("terra", "player_1")
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var loaded: GameStateScript = _make_gs()
	var problem: String = loaded.farm_from_dict(data)
	if problem == "" and (loaded.robot_paint("TR-1") != "amber" or loaded.robot_display_name("TR-1") != "Bolt-9"):
		problem = "Robot paint/nameplate must round-trip through save/load."
	if problem == "" and loaded.lab_coat_color("player_1") != "terra":
		problem = "Lab coat color must round-trip through save/load."
	if problem == "" and not loaded.odalys_mug_sent:
		problem = "odalys_mug_sent must round-trip through save/load."
	# Old save missing all new fields loads cleanly with defaults.
	var old_data: Dictionary = data.duplicate(true)
	old_data.erase("odalys_mug_sent")
	(old_data["robots"]["TR-1"] as Dictionary).erase("paint")
	(old_data["robots"]["TR-1"] as Dictionary).erase("nameplate")
	(old_data["player_loadouts"]["player_1"] as Dictionary).erase("coat_color")
	var old_loaded: GameStateScript = _make_gs()
	if problem == "":
		problem = old_loaded.farm_from_dict(old_data)
	if problem == "" and (old_loaded.odalys_mug_sent or old_loaded.robot_paint("TR-1") != "" or old_loaded.lab_coat_color("player_1") != ""):
		problem = "Old save without cosmetic fields must default to none/false."
	gs.free()
	loaded.free()
	old_loaded.free()
	GameClock.elapsed_days = saved_days
	return problem


func _sync(session: Node) -> Node:
	var sync: Node = SyncScript.new()
	sync.start(session, session.commands.state)
	sync.farm_ready.connect(func() -> void: _events.append("ready"))
	_syncs.append(sync)
	return sync


func _forged(session: Node, action: StringName, arguments: Array) -> Array:
	var got: Array = []
	var ask: Callable = func() -> void: got.append(await session._ask(action, arguments))
	ask.call()
	return got


func test_coop_guest_sync_spoof_refusal_and_late_joiner() -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	_events.clear()
	GameClock.elapsed_days = 5.0
	var host: Node = _host()
	var host_gs: Node = host.commands.state
	_add_robot(host_gs, "TR-1")
	_set_lab_level(host_gs, 85)
	_sync(host)
	FarmCommands.guest = true
	var first: Node = _session()
	_sync(first)
	first.join(LOCAL, host.port())
	var problem: String = "First guest must get the farm."
	if _until(func() -> bool: return _events.count("ready") == 1):
		problem = ""
		var first_id: String = first.commands.state.local_player_id
		# Spoofing another player via extra player_id argument must be refused.
		var spoof_robot: Array = _forged(first, &"set_robot_cosmetic", ["TR-1", "teal", "Spoof", "player_1"])
		_until(func() -> bool: return not spoof_robot.is_empty())
		if spoof_robot.is_empty() or spoof_robot[0] == "":
			problem = "Host must refuse spoofed set_robot_cosmetic with extra player_id."
		var spoof_coat: Array = _forged(first, &"set_lab_coat_color", ["amber", "player_1"])
		_until(func() -> bool: return not spoof_coat.is_empty())
		if problem == "" and (spoof_coat.is_empty() or spoof_coat[0] == ""):
			problem = "Host must refuse spoofed set_lab_coat_color with extra player_id."
		# Legitimate guest robot paint/nameplate and lab coat color sync to host and late joiner.
		if problem == "":
			var ok_robot: Array = _request(first, &"set_robot_cosmetic", ["TR-1", "terra", "Rusty"])
			_until(func() -> bool: return not ok_robot.is_empty())
			if ok_robot != [""]:
				problem = "Host must accept valid set_robot_cosmetic, got %s." % [ok_robot]
		if problem == "":
			_set_skill_level(host_gs, "calibration", 50, first_id)
			var ok_coat: Array = _request(first, &"set_lab_coat_color", ["amber"])
			_until(func() -> bool: return not ok_coat.is_empty())
			if ok_coat != [""]:
				problem = "Host must accept valid set_lab_coat_color, got %s." % [ok_coat]
		# Late joiner receives robot paint/nameplate, lab coat color, and mug state.
		if problem == "":
			host_gs.give_lab_xp(host_gs.xp_for_level(99) - host_gs.lab_xp)
			var late: Node = _session()
			_sync(late)
			late.join(LOCAL, host.port())
			if not _until(func() -> bool: return _events.count("ready") == 2):
				problem = "Late joiner must receive the farm."
			else:
				var late_gs: Node = late.commands.state
				if late_gs.robot_paint("TR-1") != "terra" or late_gs.robot_display_name("TR-1") != "Rusty":
					problem = "Late joiner must see robot paint/nameplate."
				elif late_gs.lab_coat_color(first_id) != "amber":
					problem = "Late joiner must see guest's lab coat color."
				elif not late_gs.odalys_mug_sent:
					problem = "Late joiner must see odalys_mug_sent."
	problem = _finish(problem)
	for sync: Node in _syncs:
		sync.free()
	_syncs.clear()
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	return problem
