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
	gs.build_registry()
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	var problem: String = body.call(gs)
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func _xp(source: String) -> int:
	return int(DataManager.get_record(&"skills", source, "xp_sources").get("xp", 0))


func test_data_is_whole() -> String:
	return _run(_check_data)


func _check_data(gs: GameStateScript) -> String:
	if gs.skill_ids() != (["calibration", "uncertainty", "instrumentation", "robotics", "husbandry", "field_ops"] as Array[String]):
		return "The six skills: %s" % [gs.skill_ids()]
	for skill: Dictionary in DataManager.get_records(&"skills", "skills"):
		if not skill["scope"] in ["player", "farm"]:
			return "Skill %s is neither a player's nor the farm's." % skill["id"]
	for source: Dictionary in DataManager.get_records(&"skills", "xp_sources"):
		if not source["skill"] in gs.skill_ids():
			return "Source %s names an unknown skill." % source["id"]
	for used: String in ["calibrate_player", "calibrate_found_oot", "calibrate_on_time", "calibrate_clean_tur",
			"clean_audit", "buy_standard", "calibrate_standard", "collect_spool", "slot_spool", "mine_fissure", "till"]:
		if _xp(used) <= 0:
			return "No XP for '%s'." % used
	return ""


func test_level_curve() -> String:
	return _run(_check_curve)


func _check_curve(gs: GameStateScript) -> String:
	if gs.skill_level("calibration") != 1 or gs.skill_level("husbandry") != 1:
		return "Every skill starts at level 1."
	for level: int in range(1, gs.max_skill_level()):
		var needed: int = gs.xp_for_level(level + 1)
		gs.farm_skill_xp["husbandry"] = needed - 1
		if gs.skill_level("husbandry") != level:
			return "%d XP must still be level %d." % [needed - 1, level]
		gs.farm_skill_xp["husbandry"] = needed
		if gs.skill_level("husbandry") != level + 1:
			return "%d XP must be level %d." % [needed, level + 1]
	gs.farm_skill_xp["husbandry"] = 1000000
	return "" if gs.skill_level("husbandry") == gs.max_skill_level() else "The top level must hold."


func test_level_up_is_announced_once() -> String:
	return _run(_check_level_up)


func _check_level_up(gs: GameStateScript) -> String:
	var seen: Array = []
	gs.skill_leveled.connect(func(player: String, skill: String, level: int) -> void: seen.append([player, skill, level]))
	gs.player_skill_xp["player_2"] = { "field_ops": gs.xp_for_level(2) - _xp("till") }
	gs.till(Vector3i(1, 0, 1), "player_2")
	gs.till(Vector3i(2, 0, 1), "player_2")
	return "" if seen == [["player_2", "field_ops", 2]] else "One level-up: %s" % [seen]


func test_xp_goes_to_the_player_or_the_farm() -> String:
	return _run(_check_scope)


func _check_scope(gs: GameStateScript) -> String:
	gs.till(Vector3i(1, 0, 1))
	gs.till(Vector3i(1, 0, 1))
	gs.till(Vector3i(2, 0, 1), "player_2")
	gs.till(Vector3i(3, 0, 1), gs.MANAGER_ID)
	if gs.skill_xp("field_ops") != _xp("till") or gs.skill_xp("field_ops", "player_2") != _xp("till"):
		return "Field Ops is each player's own, once per cell."
	if gs.player_skill_xp.has(gs.MANAGER_ID):
		return "The manager earns none."
	gs.molt_stage = gs.MoltStage.MOLTED
	gs.collect_spool("player_2")
	gs.collect_spool("player_2")
	gs.slot_spool_into_relay()
	if gs.skill_xp("husbandry") != _xp("collect_spool") + _xp("slot_spool") or gs.player_skill_xp["player_2"].has("husbandry"):
		return "Husbandry is the farm's: %s" % gs.farm_skill_xp
	return ""


func test_mining_and_buying() -> String:
	return _run(_check_mining)


func _check_mining(gs: GameStateScript) -> String:
	gs.mine_fissure(&"a_fissure")
	gs.mine_fissure(&"a_fissure")
	if gs.skill_xp("field_ops") != _xp("mine_fissure"):
		return "A fissure gives XP once while it is mined out."
	gs.buy_standard(FM3)
	gs.buy_standard(FM3)
	return "" if gs.skill_xp("instrumentation") == _xp("buy_standard") else "Buying a standard gives XP once."


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
	var clean: int = _xp("calibrate_clean_tur") if record["tur"] >= CalUncertainty.tur_clean() else 0
	var found: int = _xp("calibrate_player") + _xp("calibrate_found_oot")
	if gs.skill_xp("calibration") != found or gs.skill_xp("uncertainty") != clean:
		return "A late find: %s" % gs.player_skill_xp
	gs.calibrate(gs.TIRE_ID)
	if gs.skill_xp("calibration") != found:
		return "Too soon gives none."
	GameClock.elapsed_days += tire.cal_interval_days
	tire.error = 0.0
	gs.calibrate(gs.TIRE_ID, "player_2")
	if gs.skill_xp("calibration", "player_2") != _xp("calibrate_player") \
			or gs.skill_xp("uncertainty", "player_2") != _xp("calibrate_on_time") + clean:
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
	if gs.skill_xp("instrumentation") != _xp("buy_standard"):
		return "Too soon after it was bought."
	GameClock.elapsed_days += ceili(gs.get_sensor(WD1).cal_interval_days / 2.0)
	gs.calibrate(WD1)
	return "" if gs.skill_xp("instrumentation") == _xp("buy_standard") + _xp("calibrate_standard") else "A standard on the bench: %s" % gs.farm_skill_xp


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
	gs.buy_standard(FM3)
	var data: Dictionary = gs.farm_to_dict()
	gs.player_skill_xp.clear()
	gs.farm_skill_xp.clear()
	if gs.farm_from_dict(data) != "" or gs.skill_xp("field_ops", "player_2") != _xp("till") or gs.skill_xp("instrumentation") != _xp("buy_standard"):
		return "XP must survive a save."
	data.erase("player_skill_xp")
	data.erase("farm_skill_xp")
	return "" if gs.farm_from_dict(data) == "" and gs.skill_xp("instrumentation") == 0 else "An older save starts at no XP."


func test_xp_is_announced_and_keyed_by_player() -> String:
	return _run(_check_announced)


func _check_announced(gs: GameStateScript) -> String:
	var seen: Array = []
	gs.skill_xp_changed.connect(func(player: String, skill: String) -> void: seen.append([player, skill]))
	gs.local_player_id = "player_2"
	gs.till(Vector3i(1, 0, 1))
	gs.buy_standard(FM3)
	if seen != [["player_2", "field_ops"], ["", "instrumentation"]]:
		return "Each gain must be announced: %s" % [seen]
	var data: Dictionary = gs.farm_to_dict()
	gs.local_player_id = "player_1"
	if gs.farm_from_dict(data) != "" or gs.local_player_id != "player_1" or gs.skill_xp("field_ops") != 0:
		return "A save must not change who plays here, or whose XP it is."
	return "" if gs.skill_xp("field_ops", "player_2") == _xp("till") else "The saved player's XP must stay theirs."


func test_late_but_in_tolerance() -> String:
	return _run(_check_late)


func _check_late(gs: GameStateScript) -> String:
	gs.buy_standard(WD1)
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	tire.last_cal_day = -1
	tire.cal_due_day = 0
	tire.error = 0.0
	var record: Dictionary = gs.calibrate(gs.TIRE_ID)
	var clean: int = _xp("calibrate_clean_tur") if record["tur"] >= CalUncertainty.tur_clean() else 0
	if gs.skill_xp("calibration") != _xp("calibrate_player") or gs.skill_xp("uncertainty") != clean:
		return "Late, and in tolerance: no find, not on time: %s" % gs.player_skill_xp
	return ""
