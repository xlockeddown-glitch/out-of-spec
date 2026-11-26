extends RefCounted
## Milestone 4: skill XP and levels.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FM3: String = "field_meter_dc"
const WD1: String = "reference_gauge"
const HB700: String = "pressure_controller"


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.0
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func _xp(source: String, scale: float = 1.0) -> int:
	return roundi(DataManager.get_record(&"skills", source, "xp_sources").get("xp", 0) * scale)


## What a lab XP source gives in the small lab these tests have.
func _lab_xp(source: String, scale: float = 1.0) -> int:
	return roundi(DataManager.get_record(&"skills", source, "lab_xp_sources").get("xp", 0) * scale)


func test_data_is_whole() -> String:
	return _run(_check_data)


func _check_data(gs: GameStateScript) -> String:
	if gs.skill_ids() != (["calibration", "uncertainty", "robotics", "husbandry", "field_ops", "agronomy", "earthworks"] as Array[String]):
		return "The seven skills: %s" % [gs.skill_ids()]
	for skill: Dictionary in DataManager.get_records(&"skills", "skills"):
		if skill["scope"] != "player" or gs.is_farm_skill(skill["id"]):
			return "Skill %s is not a player's own." % skill["id"]
	for source: Dictionary in DataManager.get_records(&"skills", "xp_sources"):
		if not source["skill"] in gs.skill_ids():
			return "Source %s names an unknown skill." % source["id"]
	for used: String in ["calibrate_player", "calibrate_found_oot", "calibrate_on_time", "calibrate_clean_tur",
			"clean_audit", "collect_spool", "slot_spool", "mine_fissure", "till", "dig", "find_block"]:
		if _xp(used) <= 0:
			return "No XP for '%s'." % used
	for used: String in ["buy_standard", "calibrate_standard"]:
		if _lab_xp(used) <= 0 or _xp(used) != 0:
			return "'%s' feeds the lab, not a skill." % used
	return ""


func test_level_curve() -> String:
	return _run(_check_curve)


func _check_curve(gs: GameStateScript) -> String:
	if gs.skill_level("calibration") != 1 or gs.skill_level("husbandry") != 1:
		return "Every skill starts at level 1."
	for level: int in range(1, gs.max_skill_level()):
		var needed: int = gs.xp_for_level(level + 1)
		gs.player_skill_xp["player_1"] = { "husbandry": needed - 1 }
		if gs.skill_level("husbandry") != level:
			return "%d XP must still be level %d." % [needed - 1, level]
		gs.player_skill_xp["player_1"]["husbandry"] = needed
		if gs.skill_level("husbandry") != level + 1:
			return "%d XP must be level %d." % [needed, level + 1]
	gs.player_skill_xp["player_1"]["husbandry"] = gs.xp_for_level(gs.max_skill_level()) * 9
	return "" if gs.skill_level("husbandry") == gs.max_skill_level() else "The top level must hold."


func test_level_up_is_announced_once() -> String:
	return _run(_check_level_up)


func _check_level_up(gs: GameStateScript) -> String:
	var seen: Array = []
	gs.skill_leveled.connect(func(player: String, skill: String, level: int) -> void: seen.append([player, skill, level]))
	gs.player_skill_xp["player_2"] = { "agronomy": gs.xp_for_level(2) - _xp("till") }
	gs.till(Vector3i(1, 0, 1), "player_2")
	gs.till(Vector3i(2, 0, 1), "player_2")
	return "" if seen == [["player_2", "agronomy", 2]] else "One level-up: %s" % [seen]


func test_xp_goes_to_the_acting_player() -> String:
	return _run(_check_scope)


func _check_scope(gs: GameStateScript) -> String:
	gs.till(Vector3i(1, 0, 1))
	gs.till(Vector3i(1, 0, 1))
	gs.till(Vector3i(2, 0, 1), "player_2")
	gs.till(Vector3i(3, 0, 1), gs.MANAGER_ID)
	if gs.skill_xp("agronomy") != _xp("till") or gs.skill_xp("agronomy", "player_2") != _xp("till") or gs.skill_xp("field_ops") != 0:
		return "Tilling gives Agronomy, each player's own, once per cell."
	if gs.player_skill_xp.has(gs.MANAGER_ID):
		return "The manager earns none."
	gs.molt_stage = gs.MoltStage.MOLTED
	gs.collect_spool("player_2")
	gs.collect_spool("player_2")
	gs.slot_spool_into_relay()
	if gs.skill_xp("husbandry", "player_2") != _xp("collect_spool") or gs.skill_xp("husbandry") != _xp("slot_spool") or not gs.farm_skill_xp.is_empty():
		return "Husbandry is whoever did the work's: %s" % gs.player_skill_xp
	return ""


func test_mining_and_buying() -> String:
	return _run(_check_mining)


func _check_mining(gs: GameStateScript) -> String:
	gs.mine_fissure(&"FissureA")
	gs.mine_fissure(&"FissureA")
	if gs.skill_xp("field_ops") != _xp("mine_fissure"):
		return "A fissure gives XP once while it is mined out."
	gs.buy_standard(FM3)
	gs.buy_standard(FM3)
	return "" if gs.lab_xp == _lab_xp("buy_standard", gs.calibration_xp_scale(FM3)) and gs.lab_xp > 0 else "Buying a standard gives the lab XP once."


func test_calibration_xp() -> String:
	return _run(_check_calibration)


func _check_calibration(gs: GameStateScript) -> String:
	gs.buy_standard(WD1)
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	tire.last_cal_day = -1
	tire.cal_due_day = 0
	tire.error = tire.mpe * 2.0
	var record: Dictionary = gs.calibrate(gs.TIRE_ID)
	if not record.get("traceable", false):
		return "Setup: the WD-1 must calibrate the tire gauge traceably: %s" % record
	# The WD-1 is Tier 1, so every source here is worth its tier scale more.
	var tier: float = gs.calibration_xp_scale(WD1)
	if tier <= 1.0:
		return "Setup: a Tier 1 standard must scale the XP up."
	var clean: int = _xp("calibrate_clean_tur", tier) if record["tur"] >= CalUncertainty.tur_clean() else 0
	var found: int = _xp("calibrate_player", tier) + _xp("calibrate_found_oot", tier)
	if gs.skill_xp("calibration") != found or gs.skill_xp("uncertainty") != clean:
		return "A late find: %s" % gs.player_skill_xp
	gs.calibrate(gs.TIRE_ID)
	if gs.skill_xp("calibration") != found:
		return "Too soon gives none."
	GameClock.elapsed_days += tire.cal_interval_days
	tire.error = 0.0
	gs.calibrate(gs.TIRE_ID, "player_2")
	if gs.skill_xp("calibration", "player_2") != _xp("calibrate_player", tier) \
			or gs.skill_xp("uncertainty", "player_2") != _xp("calibrate_on_time", tier) + clean:
		return "An on-time pass: %s" % gs.player_skill_xp
	GameClock.elapsed_days += tire.cal_interval_days
	gs.calibrate(gs.TIRE_ID, gs.MANAGER_ID)
	GameClock.elapsed_days += tire.cal_interval_days
	gs.calibrate(gs.TIRE_ID, "player_3", false)
	gs.certificates.erase(WD1)
	gs.calibrate(gs.TIRE_ID, "player_3")
	if gs.player_skill_xp.keys() != ["player_1", "player_2"]:
		return "Untraceable work, the remote zero and the manager earn none: %s" % gs.player_skill_xp
	return ""


func test_standard_on_the_bench() -> String:
	return _run(_check_standard)


func _check_standard(gs: GameStateScript) -> String:
	gs.buy_standard(WD1)
	gs.owned_standards[HB700] = 7
	gs.oirm_calibrate(HB700, 7)
	gs.calibrate(WD1)
	var bought: int = _lab_xp("buy_standard", gs.calibration_xp_scale(WD1))
	if bought <= 0 or gs.lab_xp != bought + _lab_xp("lab_certificate"):
		return "Too soon after it was bought: %d" % gs.lab_xp
	GameClock.elapsed_days += ceili(gs.get_sensor(WD1).cal_interval_days / 2.0)
	gs.calibrate(WD1)
	# The HB-700 it is checked against sets the scale.
	var scale: float = gs.calibration_xp_scale(HB700)
	return "" if gs.lab_xp == bought + _lab_xp("lab_certificate") + _lab_xp("lab_calibration", scale) + _lab_xp("calibrate_standard", scale) \
		else "A standard on the bench: %d" % gs.lab_xp


func test_clean_audit() -> String:
	return _run(_check_audit)


func _check_audit(gs: GameStateScript) -> String:
	gs.player_skill_xp["player_2"] = {}
	gs._update_clean_audit_gate({ "passed": false })
	gs._update_clean_audit_gate({ "passed": true })
	for player: String in ["player_1", "player_2"]:
		if gs.skill_xp("uncertainty", player) != _xp("clean_audit"):
			return "A clean audit gives every player XP; a fined one gives none."
	return ""


func test_xp_survives_a_save() -> String:
	return _run(_check_save)


func _check_save(gs: GameStateScript) -> String:
	gs.till(Vector3i(1, 0, 1), "player_2")
	gs._award_xp("slot_spool")
	var data: Dictionary = gs.farm_to_dict()
	gs.player_skill_xp.clear()
	gs.farm_skill_xp.clear()
	if gs.farm_from_dict(data) != "" or gs.skill_xp("agronomy", "player_2") != _xp("till") or gs.skill_xp("husbandry") != _xp("slot_spool"):
		return "XP must survive a save."
	data.erase("player_skill_xp")
	data.erase("farm_skill_xp")
	return "" if gs.farm_from_dict(data) == "" and gs.skill_xp("husbandry") == 0 else "An older save starts at no XP."


func test_xp_is_announced_and_keyed_by_player() -> String:
	return _run(_check_announced)


func _check_announced(gs: GameStateScript) -> String:
	var seen: Array = []
	gs.skill_xp_changed.connect(func(player: String, skill: String) -> void: seen.append([player, skill]))
	gs.local_player_id = "player_2"
	gs.till(Vector3i(1, 0, 1))
	gs._award_xp("slot_spool")
	if seen != [["player_2", "agronomy"], ["player_2", "husbandry"]]:
		return "Each gain must be announced: %s" % [seen]
	var data: Dictionary = gs.farm_to_dict()
	gs.local_player_id = "player_1"
	if gs.farm_from_dict(data) != "" or gs.local_player_id != "player_1" or gs.skill_xp("agronomy") != 0:
		return "A save must not change who plays here, or whose XP it is."
	return "" if gs.skill_xp("agronomy", "player_2") == _xp("till") else "The saved player's XP must stay theirs."


func test_late_but_in_tolerance() -> String:
	return _run(_check_late)


func _check_late(gs: GameStateScript) -> String:
	gs.buy_standard(WD1)
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	tire.last_cal_day = -1
	tire.cal_due_day = 0
	tire.error = 0.0
	var record: Dictionary = gs.calibrate(gs.TIRE_ID)
	var tier: float = gs.calibration_xp_scale(WD1)
	var clean: int = _xp("calibrate_clean_tur", tier) if record["tur"] >= CalUncertainty.tur_clean() else 0
	if gs.skill_xp("calibration") != _xp("calibrate_player", tier) or gs.skill_xp("uncertainty") != clean:
		return "Late, and in tolerance: no find, not on time: %s" % gs.player_skill_xp
	return ""
