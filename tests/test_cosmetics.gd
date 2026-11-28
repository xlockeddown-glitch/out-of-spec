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
	gs._sync_robot_sensors(gs.robots)
	for sid: String in gs.robot_sensor_ids(id):
		var s: DriftingSensor = gs.get_sensor(sid)
		if s != null:
			s.zero(0.0)
			s.cal_due_day = 1000


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
	var saved_days: float = GameClock.elapsed_days
	GameClock.elapsed_days = 10.0
	var gs: GameStateScript = _make_gs()
	_set_lab_level(gs, 91)
	# Real audit below 99 (keep all units fresh so it passes cleanly).
	for uid: String in gs.unit_ids():
		gs.get_sensor(uid).cal_due_day = 100
		gs.get_sensor(uid).zero(0.0)
	for sid: String in gs.standard_ids():
		gs.get_sensor(sid).cal_due_day = 100
		gs.get_sensor(sid).zero(0.0)
	gs._run_audit(10)
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
	# Lab quest finished before 99 has no gold_border; lab quest finished at 99 gets gold_border.
	var lab_quests: Array[Dictionary] = QuestEngine.quests().filter(func(q: Dictionary) -> bool:
		return str(q.get("kind", "")) == "lab" and str(q.get("scope", QuestEngine.SCOPE_FARM)) == QuestEngine.SCOPE_FARM \
			and QuestEngine.data_problem(q) == "")
	if problem == "" and lab_quests.size() < 2:
		problem = "Expected at least 2 farm lab quests in data."
	if problem == "":
		var q_pre: Dictionary = lab_quests[0]
		var q_pre_id: String = str(q_pre["id"])
		var pre_entry: Dictionary = { "accepted": 10, "steps_done": [], "base": {}, "shown": {}, "players": ["player_1"], "done": -1 }
		for step: Variant in q_pre["steps"]:
			(pre_entry["steps_done"] as Array).append(str(step.get("id", "")))
		gs.quest_state[q_pre_id] = pre_entry
		QuestEngine._finish(gs, q_pre, pre_entry, ["player_1"])
		if bool(pre_entry.get("gold_border", false)):
			problem = "Lab quest finished before lab 99 must not get gold_border."
	# Real audit and lab quest at 99 both get gold_border without manual injection.
	_set_lab_level(gs, 99)
	GameClock.elapsed_days = 20.0
	gs._run_audit(20)
	if problem == "" and not bool(gs.audit_log[1].get("gold_border", false)):
		problem = "Real _run_audit at lab 99 must stamp gold_border."
	if problem == "":
		var q_post: Dictionary = lab_quests[1]
		var q_post_id: String = str(q_post["id"])
		var post_entry: Dictionary = { "accepted": 20, "steps_done": [], "base": {}, "shown": {}, "players": ["player_1"], "done": -1 }
		for step: Variant in q_post["steps"]:
			(post_entry["steps_done"] as Array).append(str(step.get("id", "")))
		gs.quest_state[q_post_id] = post_entry
		QuestEngine._finish(gs, q_post, post_entry, ["player_1"])
		if not bool(post_entry.get("gold_border", false)):
			problem = "Lab quest finished at lab 99 must stamp gold_border."
	wall.refresh()
	var old_cert: Node = wall.get_node_or_null("Certificate_audit_10_0")
	var new_cert: Node = wall.get_node_or_null("Certificate_audit_20_1")
	var old_quest_cert: Node = wall.get_node_or_null("Certificate_quest_" + str(lab_quests[0]["id"])) if lab_quests.size() >= 2 else null
	var new_quest_cert: Node = wall.get_node_or_null("Certificate_quest_" + str(lab_quests[1]["id"])) if lab_quests.size() >= 2 else null
	if problem == "" and (old_cert == null or new_cert == null or old_quest_cert == null or new_quest_cert == null):
		problem = "Both audit and lab-quest certificates must appear on the wall."
	if problem == "":
		var old_mat: StandardMaterial3D = (old_cert.get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
		var new_mat: StandardMaterial3D = (new_cert.get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
		var old_q_mat: StandardMaterial3D = (old_quest_cert.get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
		var new_q_mat: StandardMaterial3D = (new_quest_cert.get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
		if old_mat.albedo_color != ScopeTheme.TERRA_DARK:
			problem = "Pre-99 audit certificate must keep standard frame color."
		elif new_mat.albedo_color != ScopeTheme.GOLD:
			problem = "Post-99 audit certificate must use ScopeTheme.GOLD frame color."
		elif old_q_mat.albedo_color != ScopeTheme.TERRA_DARK:
			problem = "Pre-99 lab-quest certificate must keep standard frame color."
		elif new_q_mat.albedo_color != ScopeTheme.GOLD:
			problem = "Post-99 lab-quest certificate must use ScopeTheme.GOLD frame color."
	wall.free()
	gs.free()
	GameClock.elapsed_days = saved_days
	return problem


func test_gold_border_only_on_certificates_after_99_and_odalys_mug_once() -> String:
	var saved_days: float = GameClock.elapsed_days
	var saved_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	GameClock.elapsed_days = 10.0
	var gs: GameStateScript = _make_gs()
	_own_standard(gs, "reference_gauge")
	_set_lab_level(gs, 98)
	var credits_before: int = gs.credits
	var cert_pre: Dictionary = gs._issue_certificate("reference_gauge", 10, 0.0, 0.0, false, gs.IN_HOUSE, "IH")
	var problem: String = ""
	if bool(cert_pre.get("gold_border", false)):
		problem = "In-house certificate issued at lab 98 must not have gold_border."
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
	# At lab 99: IN_HOUSE gets gold_border; OIRM and maker/Bram certificates do NOT.
	var cert_inhouse: Dictionary = gs._issue_certificate("reference_gauge", 11, 0.0, 0.0, false, gs.IN_HOUSE, "IH")
	if problem == "" and not bool(cert_inhouse.get("gold_border", false)):
		problem = "In-house certificate issued at lab 99 must have gold_border."
	var cert_oirm: Dictionary = gs.oirm_calibrate("reference_gauge", 11)
	if problem == "" and bool(cert_oirm.get("gold_border", false)):
		problem = "OIRM certificate at lab 99 must NOT have gold_border."
	var buy_err: String = gs.buy_standard("field_meter_dc", "player_1")
	var cert_maker: Dictionary = gs.certificates.get("field_meter_dc", {})
	if problem == "" and (buy_err != "" or bool(cert_maker.get("gold_border", false))):
		problem = "Maker/Bram certificate at lab 99 must NOT have gold_border (err='%s')." % buy_err
	# Verify bench mug prop visibility AND MugRingInspect overlap disabling/restoration in DomeInterior.
	var saved_mug: bool = GameState.odalys_mug_sent
	var saved_grace: bool = GameState.audit_grace_used
	GameState.audit_grace_used = true
	GameState.odalys_mug_sent = false
	var dome: Node3D = DOME.instantiate() as Node3D
	(Engine.get_main_loop() as SceneTree).root.add_child(dome)
	var mug_node: Node3D = dome.get_node_or_null("OdalysMug") as Node3D
	var ring_click: Area3D = dome.get_node_or_null("MugRing/MugRingInspect") as Area3D
	if problem == "" and (mug_node == null or mug_node.visible):
		problem = "OdalysMug prop must exist and be hidden before mug arrives."
	if problem == "" and (ring_click == null or not ring_click.monitorable or not ring_click.input_ray_pickable or ring_click.collision_layer != 8):
		problem = "MugRingInspect must be active when audit_grace_used is true and mug is not sent."
	GameState.odalys_mug_sent = true
	dome._show_mug_ring()
	if problem == "" and (mug_node == null or not mug_node.visible):
		problem = "OdalysMug prop must be visible once mug arrives."
	if problem == "" and (ring_click.visible or ring_click.monitorable or ring_click.input_ray_pickable or ring_click.collision_layer != 0):
		problem = "MugRingInspect must be disabled/hidden when odalys_mug_sent is true."
	# Reloading an older save where odalys_mug_sent is false restores MugRingInspect.
	GameState.odalys_mug_sent = false
	dome._show_mug_ring()
	if problem == "" and (not ring_click.visible or not ring_click.monitorable or not ring_click.input_ray_pickable or ring_click.collision_layer != 8):
		problem = "MugRingInspect must be restored when odalys_mug_sent returns to false."
	dome.get_parent().remove_child(dome)
	dome.free()
	GameState.odalys_mug_sent = saved_mug
	GameState.audit_grace_used = saved_grace
	gs.free()
	FarmCommands.guest = saved_guest
	GameClock.elapsed_days = saved_days
	return problem


func test_personal_cosmetics_lab_coat_initials_and_99_title() -> String:
	var saved_days: float = GameClock.elapsed_days
	GameClock.elapsed_days = 10.0
	var gs: GameStateScript = _make_gs()
	_own_standard(gs, "pressure_controller")
	_own_standard(gs, "reference_gauge")
	_add_robot(gs, "TR-1")
	var problem: String = ""
	# Lab coat color: refused at 49, allowed at 50, open-front on WalkerModel, preserved by set_loadout, reset by "".
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
	var coat_root: Node3D = walker.get_node_or_null("LabCoatColor") as Node3D
	if problem == "":
		var back_p: MeshInstance3D = coat_root.get_node_or_null("BackPanel") as MeshInstance3D if coat_root != null else null
		var left_p: MeshInstance3D = coat_root.get_node_or_null("LeftPanel") as MeshInstance3D if coat_root != null else null
		var right_p: MeshInstance3D = coat_root.get_node_or_null("RightPanel") as MeshInstance3D if coat_root != null else null
		if back_p == null or left_p == null or right_p == null:
			problem = "WalkerModel LabCoatColor must have BackPanel, LeftPanel, and RightPanel."
		elif (left_p.mesh.material as StandardMaterial3D).albedo_color != ScopeTheme.TEAL:
			problem = "WalkerModel coat panels must use ScopeTheme.TEAL."
		else:
			var left_inner: float = left_p.position.x + (left_p.mesh as BoxMesh).size.x * 0.5
			var right_inner: float = right_p.position.x - (right_p.mesh as BoxMesh).size.x * 0.5
			if right_inner - left_inner < WalkerModel.VOXEL_M - 0.001:
				problem = "Open-front lab coat must leave at least 1 voxel chest stripe visible."
	# Reset coat color with "".
	if problem == "" and gs.set_lab_coat_color("", "player_1") != "":
		problem = "set_lab_coat_color('') must succeed to reset coat."
	if problem == "" and gs.lab_coat_color("player_1") != "":
		problem = "Lab coat color must reset to ''."
	walker.set_coat_color("")
	if problem == "" and walker.get_node_or_null("LabCoatColor") != null:
		problem = "Clearing coat color must remove LabCoatColor node."
	walker.free()
	# Calibration 75 initials: only for the calibrating player at Calibration 75+ (not robot, not Manager).
	_set_skill_level(gs, "calibration", 74, "player_1")
	var rec_74: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_1", true)
	if problem == "" and str(rec_74.get("cal_initials", "")) != "":
		problem = "Initials must not appear at Calibration 74."
	_set_skill_level(gs, "calibration", 75, "player_1")
	var rec_75: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_1", true)
	if problem == "" and str(rec_75.get("cal_initials", "")) != "AL":
		problem = "Expected initials 'AL' for Ada Lovelace at Calibration 75, got '%s'." % str(rec_75.get("cal_initials", ""))
	var rec_mgr: Dictionary = gs.calibrate(gs.HYGROMETER_ID, gs.MANAGER_ID, true)
	if problem == "" and str(rec_mgr.get("cal_initials", "")) != "":
		problem = "Manager calibration must not get cal_initials."
	var rec_bot: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_1", true, 0.0, "TR-1")
	if problem == "" and str(rec_bot.get("cal_initials", "")) != "":
		problem = "Robot-programmed calibration must not get cal_initials."
	# Player 2 at Calibration 1 gets NO initials.
	var rec_p2: Dictionary = gs.calibrate(gs.HYGROMETER_ID, "player_2", true)
	if problem == "" and str(rec_p2.get("cal_initials", "")) != "":
		problem = "Player 2 below Calibration 75 must not get initials."
	# Any skill 99: title on in-house certificates ("<Skill> 99"), non-Calibration skill works, no title on robot cal.
	var rec_std_pre: Dictionary = gs.calibrate("reference_gauge", "player_1", true)
	var cert_std_pre: Dictionary = gs.certificates.get("reference_gauge", {})
	if problem == "" and (rec_std_pre.get("refused", false) or str(cert_std_pre.get("cert_title", "")) != ""):
		problem = "Certificate title must not appear below level 99."
	_set_skill_level(gs, "agronomy", 99, "player_1")
	var rec_std_agro: Dictionary = gs.calibrate("reference_gauge", "player_1", true)
	var cert_std_agro: Dictionary = gs.certificates.get("reference_gauge", {})
	if problem == "" and (rec_std_agro.get("refused", false) or str(cert_std_agro.get("cert_title", "")) != "Agronomy 99"):
		problem = "Expected non-Calibration 99 title 'Agronomy 99', got '%s'." % str(cert_std_agro.get("cert_title", ""))
	# Robot calibration of a standard must NOT get cert_title even when programmer is 99.
	var rec_std_bot: Dictionary = gs.calibrate("reference_gauge", "player_1", true, 0.0, "TR-1")
	var cert_std_bot: Dictionary = gs.certificates.get("reference_gauge", {})
	if problem == "" and (rec_std_bot.get("refused", false) or str(cert_std_bot.get("cert_title", "")) != ""):
		problem = "Robot calibration must not stamp cert_title, got '%s'." % str(cert_std_bot.get("cert_title", ""))
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
	# Guest total-level title computed from guest's skills in CoopUI.players_text.
	_set_skill_level(gs, "agronomy", 99, "player_2")
	_set_skill_level(gs, "uncertainty", 50, "player_2")  # 99 + 50 + 5*1 = 154 -> Technician
	var coop_guest: String = CoopUI.players_text(["player_1", "player_2"], "player_1", {}, false, gs)
	if problem == "" and not "TECHNICIAN" in coop_guest:
		problem = "CoopUI.players_text must show guest's TECHNICIAN title, got '%s'." % coop_guest
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
	var host_sync: Node = _sync(host)
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
		# Live guest sync of coat color (no late join).
		if problem == "":
			if not _until(func() -> bool: return first.commands.state.lab_coat_color(first_id) == "amber"):
				problem = "Live guest must receive updated coat_color without late join."
		# Guest calibrating at Calibration 75 via bench command gets their own initials.
		if problem == "":
			host_gs.set_loadout("Grace Hopper", Loadout.encode(Loadout.default_parts()), first_id)
			_set_skill_level(host_gs, "calibration", 75, first_id)
			var cal_res: Array = _request(first, &"calibrate_at_bench", [host_gs.HYGROMETER_ID])
			_until(func() -> bool: return not cal_res.is_empty())
			if host_gs.cal_log.is_empty() or str(host_gs.cal_log[-1].get("cal_initials", "")) != "GH":
				problem = "Guest calibrating at 75 via bench command must get their own initials 'GH'."
		# Host crosses to lab 99 -> live guest receives odalys_mug_sent without late join.
		if problem == "":
			FarmCommands.guest = false
			host_gs.give_lab_xp(host_gs.xp_for_level(99) - host_gs.lab_xp)
			host_sync.tick(Time.get_ticks_msec() + SyncScript.FARM_MS)
			FarmCommands.guest = true
			if not _until(func() -> bool: return first.commands.state.odalys_mug_sent):
				problem = "Live guest must receive odalys_mug_sent without late join."
		# Late joiner receives robot paint/nameplate, lab coat color, and mug state.
		if problem == "":
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


func test_nameplate_sanitization_bidi_c1_del_and_non_string() -> String:
	# Strips bidi overrides/isolates, C1 controls, DEL, C0, "[" and caps at MAX_NAMEPLATE.
	var dirty: String = "\u202E\u200F\u2066\u0085\u009F\u007F[Bot-7\u202A\uFEFF"
	var cleaned: String = Cosmetics.clean_nameplate(dirty)
	if cleaned != "Bot-7":
		return "Expected 'Bot-7' after stripping bidi/C1/DEL/[, got '%s'." % cleaned
	for bad: Variant in [123, null, [], {}, true]:
		if Cosmetics.clean_nameplate(bad) != "":
			return "Non-String nameplate argument %s must return ''." % [bad]
	return ""


func test_load_validation_rejects_bad_cosmetic_fields() -> String:
	var saved_days: float = GameClock.elapsed_days
	GameClock.elapsed_days = 12.0
	var gs: GameStateScript = _make_gs()
	_add_robot(gs, "TR-1")
	_set_lab_level(gs, 99)
	gs.set_robot_cosmetic("TR-1", "teal", "Bolt")
	gs.audit_log.append({ "day": 10, "lines": [], "total_fine": 0, "passed": true, "warning": false, "phone_count": 0, "gold_border": true })
	_own_standard(gs, "reference_gauge")
	gs.calibrate(gs.HYGROMETER_ID, "player_1", true)
	var base: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var cases: Array = []
	# 1. Non-bool gold_border in audit_log
	var d_audit: Dictionary = base.duplicate(true)
	(d_audit["audit_log"][0] as Dictionary)["gold_border"] = "yes"
	cases.append(["non-bool audit gold_border", d_audit])
	# 2. Non-bool gold_border in certificate_log
	var d_cert_gold: Dictionary = base.duplicate(true)
	(d_cert_gold["certificate_log"][0] as Dictionary)["gold_border"] = 1
	cases.append(["non-bool certificate gold_border", d_cert_gold])
	# 3. Non-String cal_initials in cal_log
	var d_cal_init: Dictionary = base.duplicate(true)
	(d_cal_init["cal_log"][0] as Dictionary)["cal_initials"] = 42
	cases.append(["non-String cal_log cal_initials", d_cal_init])
	# 4. Non-String cal_initials in certificate_log
	var d_cert_init: Dictionary = base.duplicate(true)
	(d_cert_init["certificate_log"][0] as Dictionary)["cal_initials"] = false
	cases.append(["non-String certificate cal_initials", d_cert_init])
	# 5. Non-String cert_title in certificate_log
	var d_cert_title: Dictionary = base.duplicate(true)
	(d_cert_title["certificate_log"][0] as Dictionary)["cert_title"] = 99
	cases.append(["non-String certificate cert_title", d_cert_title])
	# 6. Non-bool gold_border in quest_state
	var d_quest_gold: Dictionary = base.duplicate(true)
	d_quest_gold["quest_state"]["q_test"] = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": 2, "gold_border": "gold" }
	cases.append(["non-bool quest_state gold_border", d_quest_gold])
	# 7. Unknown robot paint id
	var d_paint: Dictionary = base.duplicate(true)
	(d_paint["robots"]["TR-1"] as Dictionary)["paint"] = "chartreuse"
	cases.append(["unknown robot paint", d_paint])
	# 8. Robot nameplate with bidi/control chars
	var d_plate_bidi: Dictionary = base.duplicate(true)
	(d_plate_bidi["robots"]["TR-1"] as Dictionary)["nameplate"] = "Bot\u202E1"
	cases.append(["bidi robot nameplate", d_plate_bidi])
	# 9. Robot nameplate too long
	var d_plate_long: Dictionary = base.duplicate(true)
	(d_plate_long["robots"]["TR-1"] as Dictionary)["nameplate"] = "1234567890123"
	cases.append(["overlong robot nameplate", d_plate_long])
	# 10. Non-String robot nameplate
	var d_plate_type: Dictionary = base.duplicate(true)
	(d_plate_type["robots"]["TR-1"] as Dictionary)["nameplate"] = 777
	cases.append(["non-String robot nameplate", d_plate_type])
	var problem: String = ""
	for pair: Array in cases:
		var loader: GameStateScript = _make_gs()
		var err: String = loader.farm_from_dict(pair[1])
		loader.free()
		if err == "":
			problem = "farm_from_dict must refuse %s." % pair[0]
			break
	gs.free()
	GameClock.elapsed_days = saved_days
	return problem


func test_mug_old_save_arrives_next_morning_not_resent_and_never_on_guest() -> String:
	var saved_days: float = GameClock.elapsed_days
	var saved_guest: bool = FarmCommands.guest
	FarmCommands.guest = false
	GameClock.elapsed_days = 15.0
	# Old save already at lab 99 without odalys_mug_sent.
	var gs: GameStateScript = _make_gs()
	_set_lab_level(gs, 99)
	var old_data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	old_data.erase("odalys_mug_sent")
	var loaded: GameStateScript = _make_gs()
	var problem: String = loaded.farm_from_dict(old_data)
	if problem == "" and loaded.odalys_mug_sent:
		problem = "Old save at 99 without flag must load with odalys_mug_sent == false."
	# Next morning delivers the mug once.
	GameClock.elapsed_days = 16.0
	loaded._on_day_started(16)
	var count_1: int = loaded.phone_log.filter(func(l: String) -> bool: return "Warmly, Dispatch." in l and "mug" in l).size()
	if problem == "" and (not loaded.odalys_mug_sent or count_1 != 1):
		problem = "Old save at 99 must receive Odalys's mug on the next morning (sent=%s, count=%d)." % [loaded.odalys_mug_sent, count_1]
	# Save and reload at 99: advancing another morning must NOT re-send it.
	var reloaded_data: Dictionary = bytes_to_var(var_to_bytes(loaded.farm_to_dict()))
	var reloaded: GameStateScript = _make_gs()
	if problem == "":
		problem = reloaded.farm_from_dict(reloaded_data)
	GameClock.elapsed_days = 17.0
	reloaded._on_day_started(17)
	var count_2: int = reloaded.phone_log.filter(func(l: String) -> bool: return "Warmly, Dispatch." in l and "mug" in l).size()
	if problem == "" and count_2 != 1:
		problem = "Reloaded save at 99 must not re-send Odalys's mug (count=%d)." % count_2
	# Never sent on a guest.
	var guest_gs: GameStateScript = _make_gs()
	_set_lab_level(guest_gs, 99)
	FarmCommands.guest = true
	guest_gs._deliver_odalys_mug_if_due()
	if problem == "" and guest_gs.odalys_mug_sent:
		problem = "Odalys's mug must never be sent on a guest."
	FarmCommands.guest = saved_guest
	gs.free()
	loaded.free()
	reloaded.free()
	guest_gs.free()
	GameClock.elapsed_days = saved_days
	return problem


func test_ui_hides_cosmetics_below_level_and_robots_ui_pad_keyboard() -> String:
	var saved_lab_xp: int = GameState.lab_xp
	var saved_robots: Dictionary = GameState.robots.duplicate(true)
	var saved_skill_xp: Dictionary = GameState.player_skill_xp.duplicate(true)
	var saved_loadouts: Dictionary = GameState.player_loadouts.duplicate(true)
	var saved_blocked: bool = RoverController.input_blocked
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var problem: String = ""
	# RobotsUI hides paint/nameplate below lab 85, shows at 85, and hooks up PadKeyboard + live paint lookup.
	GameState.robots["TR-TEST"] = {
		"frame": "trellis", "name": "Trellis TR-TEST", "state": "released",
		"done_day": 1, "ordered_by": GameState.local_player_id,
	}
	GameState._sync_robot_sensors(GameState.robots)
	for sid: String in GameState.robot_sensor_ids("TR-TEST"):
		var s: DriftingSensor = GameState.get_sensor(sid)
		if s != null:
			s.zero(0.0)
			s.cal_due_day = 1000
	GameState.lab_xp = GameState.xp_for_level(84)
	var robots_ui := RobotsUI.new()
	root.add_child(robots_ui)
	robots_ui.open()
	var has_cosmetic_84: bool = robots_ui.find_children("*", "LineEdit", true, false).size() > 0
	if has_cosmetic_84:
		problem = "RobotsUI must hide paint/nameplate row below lab level 85."
	GameState.lab_xp = GameState.xp_for_level(85)
	robots_ui._refresh()
	var fields: Array[Node] = robots_ui.find_children("*", "LineEdit", true, false)
	if problem == "" and fields.is_empty():
		problem = "RobotsUI must show nameplate LineEdit at lab level 85."
	if problem == "":
		var field: LineEdit = fields[0] as LineEdit
		robots_ui.open_nameplate_keyboard("TR-TEST", field)
		if robots_ui._keyboard == null or not robots_ui._keyboard.visible:
			problem = "RobotsUI must open PadKeyboard for robot nameplate."
		else:
			robots_ui._keyboard.close()
			robots_ui._keyboard.finished.emit("Bolt-42")
			if field.text != "Bolt-42":
				problem = "PadKeyboard finish must update nameplate LineEdit, got '%s'." % field.text
		# Mutate robot paint in state after row was built; _on_nameplate_pressed must read live paint, not stale "".
		GameState.robots["TR-TEST"]["paint"] = "teal"
		robots_ui._on_nameplate_pressed("TR-TEST", field)
		if problem == "" and (GameState.robot_paint("TR-TEST") != "teal" or GameState.robot_display_name("TR-TEST") != "Bolt-42"):
			problem = "RobotsUI nameplate save must preserve live robot paint and apply nameplate (paint='%s', name='%s')." % [
				GameState.robot_paint("TR-TEST"), GameState.robot_display_name("TR-TEST")]
	robots_ui.get_parent().remove_child(robots_ui)
	robots_ui.free()
	# PickerUI hides coat row below skill 50 and shows it at skill 50.
	var pid: String = GameState.local_player_id
	GameState.player_skill_xp[pid] = { "agronomy": GameState.xp_for_level(49) }
	var picker := PickerUI.new()
	root.add_child(picker)
	picker.open()
	var coat_row: Control = picker.find_child("Row_coat_color", true, false) as Control
	if problem == "" and (coat_row == null or coat_row.visible):
		problem = "PickerUI must hide coat row below skill level 50."
	GameState.player_skill_xp[pid] = { "agronomy": GameState.xp_for_level(50) }
	picker.open()
	if problem == "" and not coat_row.visible:
		problem = "PickerUI must show coat row at skill level 50."
	picker.close()
	picker.get_parent().remove_child(picker)
	picker.free()
	GameState.lab_xp = saved_lab_xp
	GameState.robots = saved_robots
	GameState._sync_robot_sensors(GameState.robots)
	GameState.player_skill_xp = saved_skill_xp
	GameState.player_loadouts = saved_loadouts
	RoverController.input_blocked = saved_blocked
	return problem
