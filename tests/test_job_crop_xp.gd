extends RefCounted
## XP for paid jobs and for crops, and the count of what each player did
## (docs/design/quests_levels_story.md sections 2.3 and 5.3, build order step 2).
## The rates are [PLACEHOLDER] in data/skills.json; the tests read them.
## Each test starts the clock at the first morning and puts it back after;
## every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const CELL: Vector3i = Vector3i(1, 0, 2)
const JOB: String = "relay_inclinometer"
const GUEST: String = "player_2"
const FM3: String = "field_meter_dc"


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.credibility = 30
	gs.credits = 1000
	gs.lab_size = gs.lab_sizes().size() - 1
	for discipline: Variant in gs.job_disciplines():
		gs.lab_areas[str(discipline)] = gs.lab_area_spaces_needed("large")
	gs.tilled_cells[CELL] = true
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 0.0
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	gs.free()
	GameClock.elapsed_days = saved
	return out if out is String else "The test stopped early or did not return a String."


func _rate(source: String) -> float:
	return float(DataManager.get_record(&"skills", source, "xp_sources").get("xp", 0))


func _take(gs: GameStateScript) -> String:
	gs.job_board.clear()
	for template: Dictionary in gs._job_templates():
		if template["id"] == JOB:
			gs.job_board.append(template.duplicate(true))
	return str(gs.active_jobs[-1]["job_id"]) if gs.accept_job(0) == "" else ""


## Plants the current seed at CELL and grows it to harvest.
func _grow(gs: GameStateScript, player_id: String = "") -> void:
	gs.plant_crop(CELL, "", gs.OFFSET_CURRENT, player_id)
	for i: int in int(gs.crop(gs.current_seed())["growth_days"]):
		GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
		gs._grow_crops()


func test_sources_are_whole() -> String:
	return _run(_check_sources)


func _check_sources(gs: GameStateScript) -> String:
	var skills: Dictionary = { "job_done": "calibration", "job_clean": "uncertainty", "plant_crop": "field_ops",
		"harvest_in_spec": "field_ops", "sell_crop": "field_ops" }
	for id: String in skills:
		var source: Dictionary = DataManager.get_record(&"skills", id, "xp_sources")
		if source.get("skill") != skills[id] or float(source.get("xp", 0)) <= 0.0:
			return "Source %s must give %s XP: %s" % [id, skills[id], source]
		if bool(source.get("crop", false)) != (skills[id] == "field_ops"):
			return "Only the crop sources are marked crop: %s" % id
	if DataManager.get_record(&"skills", "till", "xp_sources").get("crop", false):
		return "Tilling stays Field Ops when Agronomy arrives."
	# Section 2.3: pay / 2 as Calibration XP, pay / 4 as Uncertainty XP.
	return "" if _rate("job_done") == 0.5 and _rate("job_clean") == 0.25 else "The job rates are the design's."


func test_a_clean_job_gives_both() -> String:
	return _run(_check_clean_job)


func _check_clean_job(gs: GameStateScript) -> String:
	var result: Dictionary = gs.complete_job(_take(gs), GUEST)
	if not result.get("ok", false) or not result["on_time"] or not result["traceable"]:
		return "The job must be done on time and traceable: %s" % [result]
	var pay: int = int(result["pay"])
	if gs.skill_xp("calibration", GUEST) != roundi(pay * _rate("job_done")):
		return "Pay / 2 as Calibration XP, got %d for %d CR." % [gs.skill_xp("calibration", GUEST), pay]
	if gs.skill_xp("uncertainty", GUEST) != roundi(pay * _rate("job_clean")):
		return "Pay / 4 as Uncertainty XP, got %d for %d CR." % [gs.skill_xp("uncertainty", GUEST), pay]
	if gs.skill_xp("calibration") != 0 or gs.skill_xp("uncertainty") != 0:
		return "Only the player who finished it earns."
	if gs.action_count("job_done", GUEST) != 1 or gs.action_xp("job_done", GUEST) != roundi(pay * _rate("job_done")) \
			or gs.action_count("job_clean", GUEST) != 1 or gs.action_count("job_done") != 0:
		return "The job is counted for them: %s" % [gs.action_counts]
	return ""


func test_an_untraceable_job_gives_calibration_only() -> String:
	return _run(_check_untraceable_job)


func _check_untraceable_job(gs: GameStateScript) -> String:
	var job_id: String = _take(gs)
	gs.get_sensor("rotary_table").cal_due_day = GameClock.get_day_index() - 1
	var result: Dictionary = gs.complete_job(job_id)
	if not result.get("ok", false) or result["traceable"] or int(result["pay"]) >= int(result["offered"]):
		return "The job must be untraceable and paid less: %s" % [result]
	if gs.skill_xp("calibration") != roundi(int(result["pay"]) * _rate("job_done")):
		return "Calibration XP is by the credits paid, got %d for %d CR." % [gs.skill_xp("calibration"), result["pay"]]
	if gs.skill_xp("uncertainty") != 0 or gs.action_count("job_clean") != 0:
		return "No Uncertainty XP for untraceable work."
	return ""


func test_a_late_job_gives_calibration_only() -> String:
	return _run(_check_late_job)


func _check_late_job(gs: GameStateScript) -> String:
	var job_id: String = _take(gs)
	GameClock.elapsed_days = float(gs.active_job(job_id)["due_day"]) + 0.25
	var result: Dictionary = gs.complete_job(job_id)
	if not result.get("ok", false) or result["on_time"] or not result["traceable"]:
		return "The job must be late and traceable: %s" % [result]
	if gs.skill_xp("calibration") != roundi(int(result["pay"]) * _rate("job_done")) or gs.skill_xp("uncertainty") != 0:
		return "A late job gives Calibration XP by its cut pay and no Uncertainty XP."
	return ""


func test_the_manager_earns_none() -> String:
	return _run(_check_manager)


func _check_manager(gs: GameStateScript) -> String:
	var result: Dictionary = gs.complete_job(_take(gs), gs.MANAGER_ID)
	if not result.get("ok", false):
		return "The job must be done: %s" % [result]
	return "" if gs.player_skill_xp.is_empty() and gs.action_counts.is_empty() else "A hired manager's job gives no one XP."


func test_crops_give_field_ops() -> String:
	return _run(_check_crops)


func _check_crops(gs: GameStateScript) -> String:
	var price: int = int(gs.crop(gs.current_seed())["base_sell_credits"])
	_grow(gs)
	var planted: int = roundi(_rate("plant_crop"))
	if gs.skill_xp("field_ops") != planted or gs.action_count("plant_crop") != 1:
		return "Planting gives Field Ops XP, got %d." % gs.skill_xp("field_ops")
	var entry: Dictionary = gs.harvest_crop(CELL)
	var harvested: int = roundi(price * _rate("harvest_in_spec"))
	if not entry.get("in_spec", false) or gs.skill_xp("field_ops") != planted + harvested:
		return "An in-spec harvest gives XP by its price, got %d." % gs.skill_xp("field_ops")
	if gs.sell_harvest_to_lin() != price:
		return "Lin must pay the base price."
	var sold: int = roundi(price * _rate("sell_crop"))
	if gs.skill_xp("field_ops") != planted + harvested + sold or gs.action_xp("sell_crop") != sold:
		return "A sale gives XP by its price, got %d." % gs.skill_xp("field_ops")
	if gs.sell_harvest_to_lin() != 0 or gs.action_count("sell_crop") != 1:
		return "An empty bin is no sale."
	if gs.plant_crop(Vector3i(9, 0, 9)) == "" or gs.action_count("plant_crop") != 1:
		return "A planting that fails is not counted."
	return "" if gs.crop_xp() == planted + harvested + sold else "All of it is crop XP: %d" % gs.crop_xp()


func test_an_off_spec_harvest_gives_none() -> String:
	return _run(_check_off_spec)


func _check_off_spec(gs: GameStateScript) -> String:
	gs.seed_crop_id = "lensberry"
	gs.get_sensor(gs.SOIL_PROBE_ID).error = float(gs.crop("lensberry")["tolerance_band"]) * 100.0 + 1.0
	_grow(gs)
	var entry: Dictionary = gs.harvest_crop(CELL)
	if entry.is_empty() or entry["in_spec"]:
		return "The crop must be off spec: %s" % [entry]
	if gs.action_count("harvest_in_spec") != 0:
		return "An off-spec harvest gives no XP."
	gs.sell_harvest_to_lin()
	return "" if gs.action_xp("sell_crop") == roundi(gs.crop_sale_price(entry) * _rate("sell_crop")) else "Its sale gives XP by the lower price."


func test_the_count_is_each_player_s_and_tells_crops_apart() -> String:
	return _run(_check_count)


func _check_count(gs: GameStateScript) -> String:
	gs.till(Vector3i(3, 0, 3))
	gs.till(Vector3i(4, 0, 3), GUEST)
	gs.till(Vector3i(5, 0, 3), GUEST)
	_grow(gs, GUEST)
	gs.harvest_crop(CELL, GUEST)
	gs.sell_harvest_to_lin()
	var till: int = roundi(_rate("till"))
	if gs.action_count("till") != 1 or gs.action_count("till", GUEST) != 2 or gs.action_xp("till", GUEST) != 2 * till:
		return "Each player's tilling is counted: %s" % [gs.action_counts]
	if gs.crop_xp(GUEST) != gs.skill_xp("field_ops", GUEST) - 2 * till or gs.crop_xp(GUEST) <= 0:
		return "Crop XP is what Field Ops had from crops, not from tilling: %d" % gs.crop_xp(GUEST)
	if gs.crop_xp() != gs.action_xp("sell_crop") or gs.crop_xp() != gs.skill_xp("field_ops") - till:
		return "The seller's sale is theirs."
	gs.credits = 100000
	gs.tier1_unlocked = true
	gs.crystal_ore = 100
	var lab_before: int = gs.lab_xp
	var refusal: String = gs.buy_standard(FM3)
	if refusal != "":
		return "The standard must be bought: %s" % refusal
	if gs.action_count("buy_standard") != 1 or gs.action_xp("buy_standard") != gs.lab_xp - lab_before or gs.lab_xp == lab_before:
		return "The lab's XP is counted for the player who did the work."
	gs._award_xp("slot_spool")
	if gs.action_count("slot_spool") != 1 or gs.action_xp("slot_spool") != gs.skill_xp("husbandry"):
		return "A farm skill's XP is counted for the player who did it."
	return "" if gs.action_count("no_such_source") == 0 and gs.action_xp("till", "player_9") == 0 else "Nothing done reads as 0."


func test_the_count_is_saved() -> String:
	return _run(_check_saved)


func _check_saved(gs: GameStateScript) -> String:
	gs.till(Vector3i(3, 0, 3), GUEST)
	_grow(gs)
	var counts: Dictionary = gs.action_counts.duplicate(true)
	var data: Dictionary = gs.farm_to_dict()
	gs.action_counts.clear()
	if gs.farm_from_dict(data) != "" or gs.action_counts != counts or gs.action_count("till", GUEST) != 1:
		return "The count must survive a save: %s" % [gs.action_counts]
	# The save file's text and back, as a load and a co-op guest get it.
	var read: Dictionary = SaveGame.from_bytes(SaveGame.to_bytes({ "clock": FarmSync.clock(), "farm": data }), "test")
	gs.action_counts.clear()
	if read.has("problem") or gs.farm_from_dict(read["data"]["farm"]) != "" or gs.action_counts != counts:
		return "The count must survive the file: %s" % [gs.action_counts]
	data.erase("action_counts")
	if gs.farm_from_dict(data) != "" or not gs.action_counts.is_empty() or gs.crop_xp() != 0:
		return "An older save starts with nothing counted."
	return "" if gs.skill_xp("field_ops") == roundi(_rate("plant_crop")) else "An older save keeps its XP."


func test_a_bad_count_is_refused() -> String:
	return _run(_check_bad)


func _check_bad(gs: GameStateScript) -> String:
	gs.till(Vector3i(3, 0, 3))
	var good: Dictionary = gs.farm_to_dict()
	for counts: Variant in [{ 2: {} }, { "player_1": 5 }, { "player_1": { 3: { "count": 1, "xp": 1 } } }, { "player_1": { "till": 1 } },
			{ "player_1": { "till": { "count": 1 } } }, { "player_1": { "till": { "count": 1.5, "xp": 1 } } },
			{ "player_1": { "till": { "count": -1, "xp": 1 } } }, { "player_1": { "till": { "count": 1, "xp": -1 } } },
			{ "player_1": { "till": { "count": 1, "xp": "many" } } }, { "player_1": { "till": { "count": 1, "xp": 1, "more": 1 } } }]:
		var bad: Dictionary = good.duplicate(true)
		bad["action_counts"] = counts
		if gs.farm_dict_problem(bad) == "":
			return "This count must be refused: %s" % [counts]
	return "" if gs.farm_dict_problem(good) == "" else "A real count must pass: %s" % gs.farm_dict_problem(good)


func test_a_forgotten_guest_s_count_goes() -> String:
	return _run(_check_forgotten)


func _check_forgotten(gs: GameStateScript) -> String:
	var players: Array[String] = ["player_1"]
	var first: String = gs.let_in_guest("%032x" % 0, {}, players)
	gs.till(Vector3i(3, 0, 3), first)
	if gs.action_count("till", first) != 1:
		return "The guest's tilling must be counted."
	for i: int in range(1, gs.MAX_KNOWN_GUESTS + 1):
		gs.let_in_guest("%032x" % i, {}, players)
	return "" if not gs.action_counts.has(first) and not first in gs.guest_ids.values() else "A forgotten guest's count must go: %s" % [gs.action_counts.keys()]


## A guest's crop work, run by the host as FarmCommands does, is the guest's.
func test_the_host_names_the_guest() -> String:
	return _run(_check_commands)


func _check_commands(gs: GameStateScript) -> String:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var problem: String = ""
	for action: StringName in [&"plant_crop", &"harvest_crop", &"sell_harvest_to_lin", &"complete_job"]:
		if commands._player_index(action) < 0:
			problem = "%s must take the acting player." % action
	if problem == "" and commands.problem(&"plant_crop", [CELL, "", gs.OFFSET_CURRENT]) + commands.problem(&"harvest_crop", [CELL]) \
			+ commands.problem(&"sell_harvest_to_lin", []) != "":
		problem = "The screens' calls must still be taken."
	# A real run: the host executes a guest's sale and the guest is credited.
	if problem == "":
		_grow(gs)
		gs.harvest_crop(CELL)
		var paid: Variant = commands.execute(GUEST, &"sell_harvest_to_lin", [])
		if not paid is int or paid <= 0 or gs.action_count("sell_crop", GUEST) != 1 or gs.action_count("sell_crop") != 0:
			problem = "A guest's sale run by the host must count for the guest: %s" % [paid]
	commands.free()
	return problem
