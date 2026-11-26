extends RefCounted
## The lab level (docs/design/quests_levels_story.md section 3, build order step
## 3): the lab's XP, what feeds it, the lab's size, and a save from before it.
## The values are [PLACEHOLDER] in data/skills.json; the tests read them.
## Each test puts the clock back after; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const FM3: String = "field_meter_dc"
const WD1: String = "reference_gauge"
const HB700: String = "pressure_controller"
const JOB: String = "relay_inclinometer"
const GUEST: String = "player_2"
## Section 3.2 of the design.
const DESIGN: Dictionary = { "lab_calibration": 25, "lab_robot_calibration": 10, "buy_standard": 75, "calibrate_standard": 100,
	"lab_job": 0.5, "lab_clean_audit": 250, "lab_certificate": 200, "lab_spool": 25, "lab_robot": 250, "lab_area": 150, "lab_grown": 500 }


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.credibility = 30
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


## What a source gives before the lab's size.
func _xp(source: String, scale: float = 1.0) -> int:
	return roundi(float(DataManager.get_record(&"skills", source, "lab_xp_sources").get("xp", 0)) * scale)


## A large lab with an area for every discipline, so any job can be taken.
func _make_large(gs: GameStateScript) -> void:
	gs.lab_size = gs.lab_sizes().size() - 1
	for discipline: Variant in gs.job_disciplines():
		gs.lab_areas[str(discipline)] = gs.lab_area_spaces_needed("large")


func _take(gs: GameStateScript) -> String:
	gs.job_board.clear()
	for template: Dictionary in gs._job_templates():
		if template["id"] == JOB:
			gs.job_board.append(template.duplicate(true))
	return str(gs.active_jobs[-1]["job_id"]) if gs.accept_job(0) == "" else ""


## A calibration as the log keeps it, for _xp_after_calibration.
func _record(gs: GameStateScript, changes: Dictionary = {}) -> Dictionary:
	var record: Dictionary = { "instrument_id": gs.unit_ids()[0], "standard_id": "", "traceable": true, "days_in_service": 10,
		"previous_interval_days": 5, "performed_by": "player_1", "programmed_by": "", "as_found_in_tolerance": true,
		"on_time": false, "tur": 0.0 }
	record.merge(changes, true)
	return record


func test_data_is_the_designs() -> String:
	return _run(_check_data)


func _check_data(gs: GameStateScript) -> String:
	var sources: Array = DataManager.get_records(&"skills", "lab_xp_sources")
	if sources.size() != DESIGN.size():
		return "The lab's sources: %s" % [sources]
	for source: Dictionary in sources:
		if not DESIGN.has(source.get("id")) or float(source.get("xp", 0)) != float(DESIGN[source["id"]]) or source.has("skill"):
			return "Source %s is not the design's." % [source]
	if DataManager.get_value(&"skills", "lab_level/size_xp", {}) != { "small": 1.0, "medium": 3.0, "large": 8.0 }:
		return "The size multipliers: %s" % [DataManager.get_value(&"skills", "lab_level/size_xp", {})]
	for index: int in gs.lab_sizes().size():
		gs.lab_size = index
		if gs.lab_xp_scale() != [1.0, 3.0, 8.0][index]:
			return "Size %d multiplies by %s." % [index, gs.lab_xp_scale()]
	return ""


func test_instrumentation_is_gone() -> String:
	return _run(_check_gone)


func _check_gone(gs: GameStateScript) -> String:
	if "instrumentation" in gs.skill_ids() or gs.skill_xp("instrumentation") != 0:
		return "Instrumentation is not a skill."
	for list: String in ["xp_sources", "effects", "unlocks"]:
		for record: Dictionary in DataManager.get_records(&"skills", list):
			if record.get("skill") == "instrumentation":
				return "%s still names Instrumentation: %s" % [list, record]
	for frame: Dictionary in DataManager.get_records(&"robots", "frames"):
		if frame.has("instrumentation_level"):
			return "A robot must not ask for Instrumentation: %s" % frame.get("id")
	if not DataManager.get_record(&"skills", "buy_standard", "xp_sources").is_empty() \
			or not DataManager.get_record(&"skills", "calibrate_standard", "xp_sources").is_empty():
		return "Its two sources feed the lab, not a skill."
	gs.buy_standard(FM3)
	return "" if gs.farm_skill_xp.is_empty() and gs.lab_xp == _xp("buy_standard", gs.calibration_xp_scale(FM3)) else "Buying a standard feeds the lab."


func test_a_new_farm_is_lab_level_1() -> String:
	return _run(_check_new)


func _check_new(gs: GameStateScript) -> String:
	if gs.lab_xp != 0 or gs.lab_level() != 1 or gs.lab_phone_text() != "level 1":
		return "A new farm's lab is level 1 with no XP."
	if not gs.lab_text().begins_with("Lab level 1  (0 XP, 50 for level 2)") or not "× 1" in gs.lab_effects_text():
		return "The skills view's lines: %s / %s" % [gs.lab_text(), gs.lab_effects_text()]
	var data: Dictionary = gs.farm_to_dict()
	if data.get("lab_xp") != 0 or data.get("skill_curve") != GameStateScript.SKILL_CURVE or GameStateScript.SKILL_CURVE != 4:
		return "A new save has no lab XP and the newest marker."
	if gs.farm_from_dict(data) != "" or gs.lab_xp != 0 or gs.lab_level() != 1:
		return "A new save loads at lab level 1: %d" % gs.lab_xp
	gs.lab_xp = gs.xp_for_level(gs.max_skill_level()) + 5
	return "" if gs.lab_level() == gs.max_skill_level() and "top level" in gs.lab_text() else "The lab level stops at the top."


func test_calibrations_feed_the_lab() -> String:
	return _run(_check_calibrations)


func _check_calibrations(gs: GameStateScript) -> String:
	var unit: String = gs.unit_ids()[0]
	var record: Dictionary = gs.calibrate(unit)
	if not record.get("traceable", false):
		return "The calibration must be traceable: %s" % [record]
	var each: int = _xp("lab_calibration", gs.calibration_xp_scale(str(record["standard_id"])))
	if each <= 0 or gs.lab_xp != each or gs.action_count("lab_calibration") != 1 or gs.action_xp("lab_calibration") != each:
		return "A traceable calibration by a player gives the lab %d: %d" % [each, gs.lab_xp]
	gs.calibrate(unit)
	if gs.lab_xp != each:
		return "One made too soon gives none."
	GameClock.elapsed_days += ceili(gs.get_sensor(unit).cal_interval_days / 2.0)
	record = gs.calibrate(unit, gs.MANAGER_ID)
	if gs.lab_xp != 2 * each or gs.action_counts.has(gs.MANAGER_ID) or gs.action_count("lab_calibration") != 1:
		return "The manager's work feeds the lab and is counted for no player: %d" % gs.lab_xp
	var before: int = gs.lab_xp
	gs._xp_after_calibration(_record(gs, { "traceable": false }))
	if gs.lab_xp != before:
		return "An untraceable calibration gives none."
	gs._xp_after_calibration(_record(gs, { "programmed_by": GUEST }))
	if gs.lab_xp != before + _xp("lab_robot_calibration") or gs.action_count("lab_robot_calibration", GUEST) != 1:
		return "A robot's calibration gives the lab %d, counted for who programmed it." % _xp("lab_robot_calibration")
	if _xp("lab_robot_calibration") >= _xp("lab_calibration"):
		return "A robot's calibration gives less than a player's."
	# The tier of the standard used multiplies it.
	before = gs.lab_xp
	gs._xp_after_calibration(_record(gs, { "standard_id": HB700 }))
	return "" if gs.calibration_xp_scale(HB700) > 1.0 and gs.lab_xp == before + _xp("lab_calibration", gs.calibration_xp_scale(HB700)) \
		else "A better standard gives more: %d" % (gs.lab_xp - before)


func test_a_standard_feeds_the_lab() -> String:
	return _run(_check_standard)


func _check_standard(gs: GameStateScript) -> String:
	gs.buy_standard(WD1, GUEST)
	gs.buy_standard(WD1, GUEST)
	var bought: int = _xp("buy_standard", gs.calibration_xp_scale(WD1))
	if gs.lab_xp != bought or gs.action_count("buy_standard", GUEST) != 1:
		return "A standard bought gives the lab %d once: %d" % [bought, gs.lab_xp]
	gs.owned_standards[HB700] = 7
	gs.oirm_calibrate(HB700, 7)
	if gs.lab_xp != bought + _xp("lab_certificate") or gs.action_counts.size() != 1:
		return "A certificate back from OIRM gives the lab %d, counted for no player." % _xp("lab_certificate")
	var before: int = gs.lab_xp
	GameClock.elapsed_days += ceili(gs.get_sensor(WD1).cal_interval_days / 2.0)
	var record: Dictionary = gs.calibrate(WD1)
	if not record.get("traceable", false) or record.get("standard_id") != HB700:
		return "The standard must be calibrated traceably: %s" % [record]
	var scale: float = gs.calibration_xp_scale(HB700)
	return "" if gs.lab_xp == before + _xp("lab_calibration", scale) + _xp("calibrate_standard", scale) \
		else "A standard calibrated on the bench gives both: %d" % (gs.lab_xp - before)


func test_jobs_feed_the_lab_times_its_size() -> String:
	return _run(_check_jobs)


func _check_jobs(gs: GameStateScript) -> String:
	GameClock.elapsed_days = 0.0
	_make_large(gs)
	var result: Dictionary = gs.complete_job(_take(gs), GUEST)
	if not result.get("ok", false) or int(result["pay"]) <= 0:
		return "The job must be done: %s" % [result]
	var gained: int = roundi(int(result["pay"]) * float(DESIGN["lab_job"]) * 8.0)
	if gs.lab_xp != gained or gs.action_xp("lab_job", GUEST) != gained or gs.action_count("lab_job", GUEST) != 1:
		return "Pay / 2, times 8 in a large lab: %d for %d CR" % [gs.lab_xp, result["pay"]]
	if gs.skill_xp("calibration", GUEST) != roundi(int(result["pay"]) * 0.5):
		return "The lab's size multiplies no skill's XP."
	if gs.lab_level() <= 1 or not gs.phone_log.any(func(line: String) -> bool: return line.begins_with("LAB LEVEL UP: level ") and not "farm" in line):
		return "A lab level gained is told on the phone: %s" % [gs.phone_log]
	result = gs.complete_job(_take(gs), gs.MANAGER_ID)
	if not result.get("ok", false) or gs.lab_xp != gained + roundi(int(result["pay"]) * float(DESIGN["lab_job"]) * 8.0):
		return "The manager's job feeds the lab too."
	return "" if not gs.action_counts.has(gs.MANAGER_ID) else "It is counted for no player."


func test_the_size_multiplies_every_source() -> String:
	return _run(_check_size)


func _check_size(gs: GameStateScript) -> String:
	gs.lab_size = 1
	gs._update_clean_audit_gate({ "passed": false })
	if gs.lab_xp != 0:
		return "An audit with fines gives none."
	gs._update_clean_audit_gate({ "passed": true })
	if gs.lab_xp != _xp("lab_clean_audit") * 3 or not gs.action_counts.get("player_1", {}).get("lab_clean_audit", {}).is_empty():
		return "A clean audit in a medium lab gives 250 x 3, counted for no player: %d" % gs.lab_xp
	var before: int = gs.lab_xp
	gs.buy_standard(FM3)
	if gs.lab_xp != before + roundi(DESIGN["buy_standard"] * gs.calibration_xp_scale(FM3) * 3.0):
		return "The size stacks with the standard's tier."
	gs.lab_size = 0
	before = gs.lab_xp
	gs.molt_stage = gs.MoltStage.MOLTED
	if not gs.collect_spool(GUEST) or gs.lab_xp != before + _xp("lab_spool") or gs.action_count("lab_spool", GUEST) != 1:
		return "A spool collected gives the lab %d." % _xp("lab_spool")
	if not gs.slot_spool_into_relay() or gs.lab_xp != before + 2 * _xp("lab_spool"):
		return "A spool slotted gives the lab %d." % _xp("lab_spool")
	return ""


func test_building_feeds_the_lab() -> String:
	return _run(_check_building)


func _check_building(gs: GameStateScript) -> String:
	gs.reset_lab()
	gs.lab_build = { "kind": "grow", "size": 1, "done_day": 7 }
	gs._finish_lab_build(6)
	if gs.lab_xp != 0:
		return "A lab still being built gives none."
	gs._finish_lab_build(7)
	if gs.lab_size != 1 or gs.lab_xp != _xp("lab_grown") * 3:
		return "A lab grown gives 500, at its new size: %d" % gs.lab_xp
	var before: int = gs.lab_xp
	var discipline: String = str(gs.job_disciplines().keys()[0])
	var spaces: int = gs.lab_space(discipline)
	if gs.fit_lab_area(discipline, GUEST) != "" or gs.lab_xp != before + _xp("lab_area") * 3 or gs.action_count("lab_area", GUEST) != 1:
		return "An area fitted gives 150, counted for who fitted it: %d" % (gs.lab_xp - before)
	# Cleared and fitted again, the same space gives none.
	before = gs.lab_xp
	for i: int in 2:
		if gs.clear_lab_area(discipline) != "":
			return "The space must be cleared: %s" % gs.lab_clear_problem(discipline)
		gs._finish_lab_build(int(gs.lab_build["done_day"]))
		if gs.fit_lab_area(discipline, GUEST) != "" or gs.lab_space(discipline) != spaces + 1:
			return "The space must be fitted again."
		if gs.lab_xp != before or gs.action_count("lab_area", GUEST) != 1:
			return "A space cleared and fitted again gives none: %d" % (gs.lab_xp - before)
	if gs.farm_to_dict().get("lab_areas_paid", {}).get(discipline) != spaces + 1:
		return "What is paid for is saved: %s" % [gs.lab_areas_paid]
	# A save from before the mark: the spaces it has are not paid for again.
	var old: Dictionary = gs.farm_to_dict()
	old.erase("lab_areas_paid")
	gs.lab_areas_paid.clear()
	if gs.farm_from_dict(old) != "" or gs.lab_areas_paid != gs.lab_areas:
		return "An older save's areas are marked as paid: %s" % [gs.lab_areas_paid]
	old["lab_areas_paid"] = { discipline: "two" }
	if gs.farm_dict_problem(old) == "":
		return "A mark that is not a count is refused."
	before = gs.lab_xp
	if gs.fit_lab_area(discipline) != "" or gs.lab_xp != before + _xp("lab_area") * 3:
		return "A space the area never had gives XP: %d" % (gs.lab_xp - before)
	before = gs.lab_xp
	gs.lab_size = 0
	gs.optical_silk_spools = 3
	gs._spool_species.assign([&"a", &"b", &"c"])
	for id: String in gs.all_standard_ids():
		gs.owned_standards[id] = 0
		gs.get_sensor(id).cal_due_day = 1000
		gs.certificates[id] = { "id": "TEST-" + id, "standard_id": id }
	if gs.build_robot("trellis", GUEST) != "":
		return "The robot must be ordered: %s" % gs.robot_build_problem("trellis", GUEST)
	if gs.lab_xp != before:
		return "A robot ordered gives none until it is built."
	GameClock.elapsed_days = 7.0
	gs._finish_robot_builds(8)
	return "" if gs.lab_xp == before + _xp("lab_robot") and gs.action_count("lab_robot", GUEST) == 1 else "A robot built gives the lab 250."


## A farm that has a calibration that counts, one made too soon, a robot's, an
## untraceable one, two paid jobs and two audits, one of them clean. Returns
## what its logs are worth to the lab, the lab's size not counted.
func _old_farm(gs: GameStateScript) -> int:
	GameClock.elapsed_days = 0.0
	_make_large(gs)
	var worth: int = 0
	for i: int in 2:
		var result: Dictionary = gs.complete_job(_take(gs), GUEST if i == 0 else gs.MANAGER_ID)
		worth += roundi(int(result["pay"]) * float(DESIGN["lab_job"]))
	GameClock.elapsed_days = 6.0
	var unit: String = gs.unit_ids()[0]
	var record: Dictionary = gs.calibrate(unit)
	worth += _xp("lab_calibration", gs.calibration_xp_scale(str(record["standard_id"])))
	gs.calibrate(unit)
	var robots: Dictionary = record.duplicate(true)
	robots["programmed_by"] = GUEST
	gs.cal_log.append(robots)
	worth += _xp("lab_robot_calibration", gs.calibration_xp_scale(str(record["standard_id"])))
	var loose: Dictionary = record.duplicate(true)
	loose["traceable"] = false
	gs.cal_log.append(loose)
	# From before records said if they were traceable: one with a standard is.
	var unmarked: Dictionary = record.duplicate(true)
	unmarked.erase("traceable")
	gs.cal_log.append(unmarked)
	worth += _xp("lab_calibration", gs.calibration_xp_scale(str(record["standard_id"])))
	var bare: Dictionary = unmarked.duplicate(true)
	bare["standard_id"] = ""
	gs.cal_log.append(bare)
	gs.audit_log.append({ "day": 3, "passed": true, "clean": true, "total_fine": 0, "lines": [], "interlocks": [] })
	gs.audit_log.append({ "day": 5, "passed": false, "total_fine": 200, "lines": [], "interlocks": [] })
	# From before reports were marked clean: one that passed was.
	gs.audit_log.append({ "day": 4, "passed": true, "total_fine": 0, "lines": [], "interlocks": [] })
	worth += 2 * _xp("lab_clean_audit")
	return worth


func test_a_save_from_before_the_lab_level_converts() -> String:
	return _run(_check_stage_1)


func _check_stage_1(gs: GameStateScript) -> String:
	var worth: int = _old_farm(gs)
	if str(gs.cal_log[0].get("standard_id", "")) == "" or gs.cal_log.size() != 6 or gs.job_log.size() != 2 or worth <= _xp("lab_clean_audit"):
		return "The farm must have its logs: %d calibrations, %d jobs." % [gs.cal_log.size(), gs.job_log.size()]
	gs.farm_skill_xp = { "instrumentation": 400, "husbandry": 60 }
	var calibration: int = gs.skill_xp("calibration", GUEST)
	var data: Dictionary = gs.farm_to_dict()
	data.erase("lab_xp")
	data["skill_curve"] = 2
	gs.lab_xp = 0
	if gs.farm_from_dict(data) != "":
		return "A save from before the lab level must load: %s" % gs.farm_from_dict(data)
	if gs.lab_xp != 400 + worth:
		return "Instrumentation's 400 one for one, and %d for the logs at the small lab's rate: %d" % [worth, gs.lab_xp]
	if not gs.farm_skill_xp.is_empty() or gs.skill_xp("husbandry") != 60 or gs.skill_xp("husbandry", GUEST) != 60 \
			or gs.skill_xp("calibration", GUEST) != calibration or gs.skill_curve != GameStateScript.SKILL_CURVE:
		return "Instrumentation goes, Husbandry is each player's, and nothing else changes: %s %s" % [gs.farm_skill_xp, gs.player_skill_xp]
	# Saved again it is a new save: nothing is credited twice.
	var again: Dictionary = gs.farm_to_dict()
	if again.get("skill_curve") != GameStateScript.SKILL_CURVE or again.get("lab_xp") != 400 + worth or again["farm_skill_xp"].has("instrumentation"):
		return "It is saved with its lab XP and the newest marker."
	for i: int in 2:
		if gs.farm_from_dict(again) != "" or gs.lab_xp != 400 + worth:
			return "A converted save must not convert again: %d" % gs.lab_xp
		again = gs.farm_to_dict()
	return ""


func test_a_save_from_the_10_level_curve_converts_both_ways() -> String:
	return _run(_check_oldest)


func _check_oldest(gs: GameStateScript) -> String:
	var worth: int = _old_farm(gs)
	var factor: int = int(DataManager.get_number(&"skills", "old_curve/xp_factor", 0.0))
	gs.farm_skill_xp = { "instrumentation": 150, "robotics": 100 }
	var data: Dictionary = gs.farm_to_dict()
	for key: String in ["lab_xp", "skill_curve", "skill_effect_floor", "action_counts"]:
		data.erase(key)
	gs.lab_xp = 0
	if gs.farm_from_dict(data) != "":
		return "The oldest save must load: %s" % gs.farm_from_dict(data)
	if gs.lab_xp != 150 * factor + worth or gs.skill_xp("robotics") != 100 * factor or gs.farm_skill_xp.has("instrumentation"):
		return "Its Instrumentation XP is multiplied by %d, then added to the lab's: %d" % [factor, gs.lab_xp]
	if gs.skill_effect_floor.get("", {}).has("instrumentation"):
		return "No floor is kept for a skill that is gone: %s" % [gs.skill_effect_floor]
	var again: Dictionary = gs.farm_to_dict()
	return "" if gs.farm_from_dict(again) == "" and gs.lab_xp == 150 * factor + worth and gs.skill_xp("robotics") == 100 * factor \
		else "A converted save must not convert again."


func test_a_save_with_no_logs_starts_at_level_1() -> String:
	return _run(_check_empty)


func _check_empty(gs: GameStateScript) -> String:
	var data: Dictionary = gs.farm_to_dict()
	data.erase("lab_xp")
	data["skill_curve"] = 2
	gs.lab_xp = 99
	return "" if gs.farm_from_dict(data) == "" and gs.lab_xp == 0 and gs.lab_level() == 1 else "Nothing done, nothing credited: %d" % gs.lab_xp


func test_a_guest_file_with_instrumentation_loads() -> String:
	return _run(_check_guest_file)


func _check_guest_file(gs: GameStateScript) -> String:
	var key: String = "0".repeat(32)
	var got: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"calibration":60,"instrumentation":900},"curve":%d}' % [
		key, ProfileScript.CURVE]).to_utf8_buffer())
	if got != { "key": key, "skills": { "calibration": 60 } }.merged(ProfileScript.no_record()):
		return "A guest file with Instrumentation loads without it: %s" % [got]
	var factor: int = int(DataManager.get_number(&"skills", "old_curve/xp_factor", 0.0))
	got = ProfileScript._parse(('{"key":"%s","skills":{"instrumentation":900,"field_ops":7}}' % key).to_utf8_buffer())
	if got != { "key": key, "skills": { "field_ops": 7 * factor } }.merged(ProfileScript.no_record()):
		return "One from the 10-level curve too: %s" % [got]
	# A host is not moved by a guest who sends it anyway.
	var players: Array[String] = ["player_1"]
	var id: String = gs.let_in_guest(key, { "calibration": 60, "instrumentation": 900 }, players)
	return "" if gs.player_skill_xp.get(id) == { "calibration": 60 } and gs.lab_xp == 0 and gs.farm_skill_xp.is_empty() \
		else "A guest brings their own skills only: %s" % [gs.player_skill_xp]


func test_the_lab_level_reaches_a_guest() -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var was_guest: bool = FarmCommands.guest
	var problem: String = _run(_check_sync)
	FarmCommands.guest = was_guest
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	return problem


func _check_sync(host: GameStateScript) -> String:
	if not ["lab_xp"] in FarmSync.SHOWN_BY.values():
		return "The lab's XP must have its signal."
	var guest: GameStateScript = GameStateScript.new()
	guest.build_registry()
	var heard: Array = [0]
	guest.lab_xp_changed.connect(func() -> void: heard[0] += 1)
	host._update_clean_audit_gate({ "passed": true })
	FarmCommands.guest = true
	var problem: String = FarmSync.join(FarmSync.capture(host), guest)
	if problem == "" and (guest.lab_xp != host.lab_xp or guest.lab_xp != _xp("lab_clean_audit") or guest.lab_level() != host.lab_level()):
		problem = "A guest who joins has the host's lab level: %d" % guest.lab_xp
	heard[0] = 0
	FarmCommands.guest = false
	host.buy_standard(FM3)
	var bytes: PackedByteArray = FarmSync.capture(host)
	FarmCommands.guest = true
	if problem == "":
		problem = FarmSync.update(bytes, guest)
	if problem == "" and (guest.lab_xp != host.lab_xp or heard[0] != 1):
		problem = "An update brings the lab's XP and says so once: %d, told %d times" % [guest.lab_xp, heard[0]]
	if problem == "":
		problem = FarmSync.update(bytes, guest)
	if problem == "" and heard[0] != 1:
		problem = "Nothing new, nothing said."
	if problem == "" and guest.farm_to_dict()["lab_xp"] != host.farm_to_dict()["lab_xp"]:
		problem = "The guest's copy holds the host's lab XP."
	FarmCommands.guest = false
	guest.free()
	return problem
