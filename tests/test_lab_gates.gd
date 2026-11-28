extends RefCounted
## The lab-level gates (docs/design/quests_levels_story.md section 3.4, build
## step 9): the table in data/skills.json is in rising order with every story
## beat at or below level 60 and prints about how many hours each row takes;
## a gate shuts a thing with its reason in plain words, opens at its level, and
## a save from before the gates keeps what it had. The levels are
## [PLACEHOLDER]; the tests read them. Every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FM3: String = "field_meter_dc"
const WD1: String = "reference_gauge"
const TW6: String = "torque_standard"
const HB700: String = "pressure_controller"
## The hour budget of section 3.2.1 [PLACEHOLDER]: lab level by hours of farm
## play. Past the last one the hours go on at the rate of the last stretch.
const BUDGET: Array = [[1, 0.0], [20, 5.0], [40, 20.0], [60, 50.0]]


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	return gs


func _at_level(gs: GameStateScript, level: int) -> void:
	gs.lab_xp = gs.xp_for_level(level)


func _gates() -> Array:
	return DataManager.get_records(&"skills", "lab_gates")


## About how many hours of play it takes to reach `level`: the budget's hours,
## on a straight line against the log of the XP between its levels, since the
## curve grows by the same share a level.
func _hours(gs: GameStateScript, level: int) -> float:
	var logs: Array[float] = []
	for point: Array in BUDGET:
		logs.append(log(float(gs.xp_for_level(int(point[0]))) + 50.0))
	var at: float = log(float(gs.xp_for_level(level)) + 50.0)
	var last: int = BUDGET.size() - 1
	var stretch: int = last
	for i: int in range(1, BUDGET.size()):
		if at <= logs[i]:
			stretch = i
			break
	var from: Array = BUDGET[stretch - 1]
	var to: Array = BUDGET[stretch]
	var share: float = (at - logs[stretch - 1]) / (logs[stretch] - logs[stretch - 1])
	return float(from[1]) + share * (float(to[1]) - float(from[1]))


func test_the_table_rises_and_every_beat_is_at_or_below_60() -> String:
	var gs: GameStateScript = _state()
	var problem: String = ""
	var level: int = 0
	var seen: Dictionary = {}
	for row: Dictionary in _gates():
		var id: String = str(row["id"])
		if seen.has(id):
			problem = "Gate '%s' is twice in the table." % id
		seen[id] = true
		if int(row["level"]) < level:
			problem = "Gate '%s' (level %d) is below the one before it (%d)." % [id, int(row["level"]), level]
		if int(row["level"]) < 1 or int(row["level"]) > gs.max_skill_level():
			problem = "Gate '%s' is not on the curve." % id
		level = int(row["level"])
		if row.get("beat", false) and level > 60:
			problem = "The story beat '%s' is at level %d: no beat sits above 60." % [id, level]
		if row.has("quest") and not DataManager.has_record(&"quests", StringName(str(row["quest"])), "quests"):
			problem = "Gate '%s' names a quest that is not there." % id
	# Daily asks are gated in data/quests.json: it must say the same level.
	var asks: int = 0
	for quest: Dictionary in DataManager.get_records(&"quests", "quests"):
		if quest.get("kind", "") == "daily":
			asks += 1
			if int(quest.get("gates", {}).get("lab_level", 0)) != int(DataManager.get_record(&"skills", &"daily_asks", "lab_gates")["level"]):
				problem = "Daily ask '%s' is gated at a different lab level than the table's." % quest.get("id", "")
	if problem == "" and asks == 0:
		problem = "There are no daily asks to check."
	gs.free()
	return problem


## Prints the hours; asserts they rise with the level and meet the budget.
func test_the_hours_to_each_gate() -> String:
	var gs: GameStateScript = _state()
	var before: float = -1.0
	var problem: String = ""
	print("Lab-level gates: about how many hours of play to reach each (budget: 20 at 5 h, 40 at 20 h, 60 at 50 h) [PLACEHOLDER]")
	for row: Dictionary in _gates():
		var level: int = int(row["level"])
		var hours: float = _hours(gs, level)
		var built: String = "" if row.get("built", true) else " (not built)"
		print("  level %2d  %5.1f h  %s%s%s" % [level, hours, str(row.get("opens", row["id"])), " [beat]" if row.get("beat", false) else "", built])
		if hours + 0.0001 < before:
			problem = "Gate '%s' takes fewer hours than the one before it." % row["id"]
		before = hours
	for point: Array in BUDGET:
		if absf(_hours(gs, int(point[0])) - float(point[1])) > 0.01:
			problem = "The model must meet its own budget at level %d." % int(point[0])
	# What the hour asks of the lab: lab XP an hour in each stretch, and how many
	# traceable calibrations of the tier a lab of that size has that is.
	var stretches: Array = [[1, 20, 0, 1.0], [20, 40, 1, 3.0], [40, 60, 3, 8.0]]
	for stretch: Array in stretches:
		var from: int = int(stretch[0])
		var to: int = int(stretch[1])
		var per_hour: float = float(gs.xp_for_level(to) - gs.xp_for_level(from)) / (_hours(gs, to) - _hours(gs, from))
		var tier: float = float(DataManager.get_value(&"skills", "calibration_tier_xp", [1.0])[int(stretch[2])])
		var one: float = float(DataManager.get_record(&"skills", &"lab_calibration", "lab_xp_sources")["xp"]) * tier * float(stretch[3])
		print("  levels %d to %d: %s lab XP an hour, about %d traceable calibrations an hour at one calibration's %s lab XP" % [
			from, to, SP811.integer(roundi(per_hour)), roundi(per_hour / one), SP811.integer(roundi(one))])
	gs.free()
	return problem


func test_a_new_farm_waits_for_the_tier_1_level() -> String:
	var gs: GameStateScript = _state()
	var fm: DriftingSensor = gs.get_sensor(FM3)
	var level: int = gs.lab_gate_level("tier1")
	var problem: String = ""
	if level < 2 or gs.lab_level() >= level:
		problem = "The test needs a lab short of the Tier 1 level."
	var reason: String = gs.tier_problem(FM3)
	if problem == "" and (reason != "Tier 1 equipment needs lab level %d (the lab is level %d)." % [level, gs.lab_level()]):
		problem = "Bram's reason says the level and where the lab is: '%s'" % reason
	if problem == "" and (gs.buy_standard(FM3) == "" or gs.owned_standards.has(FM3)):
		problem = "Bram must not sell Tier 1 below its lab level."
	if problem == "" and gs.tier_lab_note(FM3) != "needs lab level %d" % level:
		problem = "The list says why in few words: '%s'" % gs.tier_lab_note(FM3)
	_at_level(gs, level)
	if problem == "" and gs.buy_standard(FM3) != "":
		problem = "At the level Bram must sell: %s" % gs.standard_purchase_problem(FM3)
	if problem == "" and gs.credits != 100000 - fm.price_credits:
		problem = "The purchase charges as it did."
	gs.free()
	return problem


func test_the_level_and_the_old_condition_both_hold() -> String:
	var gs: GameStateScript = _state()
	_at_level(gs, 99)
	gs.tier1_unlocked = false
	var problem: String = ""
	if not gs.tier_problem(FM3).contains("clean audit"):
		problem = "A high lab level does not open Tier 1 without the audit: '%s'" % gs.tier_problem(FM3)
	gs.tier1_unlocked = true
	if problem == "" and not gs.tier_problem(TW6).contains("OIRM account"):
		problem = "A high lab level does not open Tier 2 without an account: '%s'" % gs.tier_problem(TW6)
	if problem == "" and gs.tier_lab_note(TW6) != "":
		problem = "A tier shut by its old condition shows no level note."
	gs.free()
	return problem


func test_oirm_account_waits_for_its_level() -> String:
	var gs: GameStateScript = _state()
	_at_level(gs, gs.lab_gate_level("tier1"))
	var problem: String = ""
	if gs.buy_standard(FM3) != "":
		problem = "Setup: the FM-3 must be bought."
	var level: int = gs.lab_gate_level("oirm_account")
	var sent: Dictionary = gs.send_to_oirm(FM3)
	if problem == "" and (sent.get("ok", false) or not str(sent.get("reason", "")).contains("lab level %d" % level)):
		problem = "The first trip waits for the account's level and says so: %s" % [sent]
	_at_level(gs, level)
	if problem == "" and not gs.send_to_oirm(FM3).get("ok", false):
		problem = "At the level the trip goes."
	gs.free()
	return problem


func test_the_job_board_waits_for_its_level() -> String:
	var gs: GameStateScript = _state()
	gs.reset_credibility()
	gs.credibility = 30
	var level: int = gs.lab_gate_level("job_board")
	var problem: String = ""
	var job: Dictionary = { "job_id": "x", "min_band": "Trusted" }
	if not gs.job_accept_problem(job).contains("lab level %d" % level):
		problem = "A job says the board needs its level: '%s'" % gs.job_accept_problem(job)
	if problem == "" and not gs.job_board_note().contains("lab level %d" % level):
		problem = "The board's note says why it is empty: '%s'" % gs.job_board_note()
	_at_level(gs, level)
	if problem == "" and gs.job_accept_problem(job).contains("lab level"):
		problem = "At the level the board is open: '%s'" % gs.job_accept_problem(job)
	gs.free()
	return problem


func test_the_lab_grows_at_its_levels() -> String:
	var gs: GameStateScript = _state()
	var problem: String = ""
	for size: int in range(1, gs.lab_sizes().size()):
		gs.lab_size = size - 1
		var gate: String = "%s_lab" % gs.lab_sizes()[size].get("id", "")
		var level: int = gs.lab_gate_level(gate)
		gs.lab_xp = 0
		if not gs.lab_grow_problem().contains("lab level %d" % level):
			problem = "Growing to %s needs lab level %d and says so: '%s'" % [gate, level, gs.lab_grow_problem()]
		_at_level(gs, level)
		if problem == "" and gs.lab_grow_problem().contains("lab level"):
			problem = "At level %d the lab can grow to %s." % [level, gate]
	gs.free()
	return problem


func test_the_contract_discount_opens_no_tier() -> String:
	var gs: GameStateScript = _state()
	gs.contract_state = "complete"
	_at_level(gs, gs.lab_gate_level("tier3") - 1)
	var problem: String = ""
	if gs.tier_problem(HB700) == "" or gs.buy_standard(HB700) == "":
		problem = "The contract's HB-700 must wait for Tier 3."
	if problem == "" and not HB700 in gs.bram_catalog():
		problem = "Bram still lists it, shut, so the discount is held."
	gs.free()
	return problem


func test_a_new_game_keeps_no_gate_open() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var problem: String = ""
	if not data.has("lab_gates_kept") or not (data["lab_gates_kept"] as Array).is_empty():
		problem = "A new farm keeps nothing open."
	if problem == "" and gs.lab_gate_open("tier1"):
		problem = "Tier 1 is shut at lab level 1."
	gs.free()
	return problem


func test_a_save_from_before_the_gates_keeps_what_it_had() -> String:
	var gs: GameStateScript = _state()
	GameClock.elapsed_days = 6.0
	var problem: String = ""
	# The save of that time: Tier 1 open and owned, a medium lab, no key.
	gs.lab_gates_kept.clear()
	gs.owned_standards[FM3] = 0
	gs.lab_size = 1
	var old: Dictionary = gs.farm_to_dict()
	old.erase("lab_gates_kept")
	var loaded: GameStateScript = _state()
	var read: String = loaded.farm_from_dict(old)
	if read != "":
		problem = "An old save loads: %s" % read
	for gate: String in ["tier1", "medium_lab"]:
		if problem == "" and not loaded.lab_gate_open(gate):
			problem = "The old farm keeps '%s' open." % gate
	for gate: String in ["tier2", "job_board", "tier3"]:
		if problem == "" and loaded.lab_gate_open(gate):
			problem = "The old farm had not '%s' open, so it waits." % gate
	if problem == "" and loaded.lab_level() != gs.lab_level():
		problem = "Keeping a gate gives no XP."
	# It is stored, so a second save and load keeps the same.
	var again: GameStateScript = _state()
	if problem == "" and (again.farm_from_dict(loaded.farm_to_dict()) != "" or again.lab_gates_kept != loaded.lab_gates_kept):
		problem = "The kept gates save and load: %s" % [again.lab_gates_kept]
	again.free()
	loaded.free()
	gs.free()
	return problem


func test_a_kept_gate_survives_a_low_level_and_is_checked() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	data["lab_gates_kept"] = ["tier1", "tier1"]
	var problem: String = ""
	if gs.farm_dict_problem(data) == "":
		problem = "A gate kept twice is refused."
	data["lab_gates_kept"] = ["tier1"]
	if problem == "" and gs.farm_dict_problem(data) != "":
		problem = "One kept gate is fine: %s" % gs.farm_dict_problem(data)
	if problem == "" and (gs.farm_from_dict(data) != "" or gs.tier_problem(FM3) != ""):
		problem = "A kept Tier 1 sells at lab level 1."
	gs.free()
	return problem


func test_the_level_up_line_names_what_opens() -> String:
	var gs: GameStateScript = _state()
	var level: int = gs.lab_gate_level("tier1")
	_at_level(gs, level - 1)
	gs.give_lab_xp(gs.xp_for_level(level) - gs.lab_xp)
	var problem: String = ""
	var line: String = str(gs.phone_log[-1]) if not gs.phone_log.is_empty() else ""
	if not line.contains("Tier 1 standards"):
		problem = "The level-up line says what opens: '%s'" % line
	gs.free()
	return problem


func test_the_provisional_way_through_pays_toward_the_level() -> String:
	var gs: GameStateScript = _state()
	var level: int = gs.lab_gate_level("first_contract")
	var quest: String = str(DataManager.get_record(&"skills", &"first_contract", "lab_gates")["quest"])
	var problem: String = ""
	var share: float = DataManager.get_number(&"skills", "lab_level/provisional_gap_share", 0.0)
	var want: int = roundi((gs.xp_for_level(level) - gs.lab_xp) * share)
	if want <= 0 or gs.provisional_lab_xp(quest) != want:
		problem = "Below the level the quest lifts the lab by the share of the gap: %d vs %d" % [gs.provisional_lab_xp(quest), want]
	_at_level(gs, level)
	if problem == "" and gs.provisional_lab_xp(quest) != 0:
		problem = "At the level it pays nothing extra."
	gs.free()
	return problem


## A farm of the day before the gates, with an OIRM-certified Tier 2 standard and
## the sign-off but no Tier 3 bought, written as a save without the key.
func _old_tier_3_ready_save() -> Dictionary:
	var gs: GameStateScript = _state()
	GameClock.elapsed_days = 6.0
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # the setup buys past the gates
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	gs.buy_standard(FM3)
	gs.send_to_oirm(FM3)
	gs.traceable_lab = true
	gs.buy_standard(TW6)
	gs.oirm_calibrate(TW6, 7)
	var old: Dictionary = gs.farm_to_dict()
	old.erase("lab_gates_kept")
	var open: bool = gs.tier_problem(HB700) == ""
	gs.free()
	return old if open else {}


func test_an_old_save_with_a_certified_tier_2_keeps_tier_3() -> String:
	var saved: float = GameClock.elapsed_days
	var old: Dictionary = _old_tier_3_ready_save()
	var problem: String = ""
	if old.is_empty():
		problem = "The setup must open Tier 3 by its old condition."
	# A boot load: nothing was loaded before, the logs are read as it loads.
	var loaded: GameStateScript = _state()
	if problem == "" and loaded.farm_from_dict(old) != "":
		problem = "The old save loads."
	for gate: String in ["tier2", "tier3"]:
		if problem == "" and not loaded.lab_gate_open(gate):
			problem = "The old farm keeps '%s' open: %s" % [gate, loaded.lab_gates_kept]
	loaded.free()
	GameClock.elapsed_days = saved
	return problem


func test_loading_one_save_then_another_carries_nothing_over() -> String:
	var saved: float = GameClock.elapsed_days
	var a: Dictionary = _old_tier_3_ready_save()
	var fresh: GameStateScript = _state()
	var b: Dictionary = fresh.farm_to_dict()
	b.erase("lab_gates_kept")
	fresh.free()
	var gs: GameStateScript = _state()
	var problem: String = ""
	if gs.farm_from_dict(a) != "" or not gs.lab_gate_open("tier3"):
		problem = "Save A keeps Tier 3 open: %s" % [gs.lab_gates_kept]
	if problem == "" and gs.farm_from_dict(b) != "":
		problem = "Save B loads."
	for gate: String in ["tier2", "tier3", "oirm_account"]:
		if problem == "" and gs.lab_gate_open(gate):
			problem = "Save B had not '%s' open, and A's state is not B's: %s" % [gate, gs.lab_gates_kept]
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_an_old_save_keeps_the_next_lab_and_the_first_trip() -> String:
	var gs: GameStateScript = _state()
	gs.owned_standards[FM3] = 0
	gs.lab_size = 0
	gs.contract_state = "active"
	var old: Dictionary = gs.farm_to_dict()
	old.erase("lab_gates_kept")
	var loaded: GameStateScript = _state()
	var problem: String = ""
	if loaded.farm_from_dict(old) != "":
		problem = "The old save loads."
	# Growing took credits and ore and nothing else; so did the first trip.
	for gate: String in ["medium_lab", "oirm_account", "tier1"]:
		if problem == "" and not loaded.lab_gate_open(gate):
			problem = "The old farm keeps '%s' open: %s" % [gate, loaded.lab_gates_kept]
	if problem == "" and loaded.lab_gate_open("large_lab"):
		problem = "Only the next size was open, not the one after."
	if problem == "" and not loaded.KEPT_CONTRACT_SALE in loaded.lab_gates_kept:
		problem = "An active contract keeps its sale: %s" % [loaded.lab_gates_kept]
	loaded.free()
	gs.free()
	return problem


func test_every_gate_id_the_game_uses_is_a_row() -> String:
	var gs: GameStateScript = _state()
	var have: Array[String] = gs.all_lab_gate_ids()
	var used: Array[String] = ["oirm_account", "job_board", "accredited_jobs", "robot_1", "certificate_wall"]
	for id: String in gs.all_standard_ids():
		var tier: int = (gs.sensors[id] as DriftingSensor).tier
		if tier >= 1:
			used.append("tier%d" % tier)
	for size: Dictionary in gs.lab_sizes().slice(1):
		used.append(gs.lab_size_gate_id(size))
	for job: Dictionary in DataManager.get_records(&"robots", "jobs"):
		if job.has("lab_gate"):
			used.append(str(job["lab_gate"]))
	for band: Dictionary in gs._cred_bands():
		used.append(gs.job_gate_id(str(band.get("name", ""))))
	for count: int in [0, 1, 2, 5, 9]:
		gs.robots.clear()
		for n: int in count:
			gs.robots["R-%d" % n] = {}
		used.append(gs.robot_gate_id())
	gs.robots.clear()
	var problem: String = ""
	for id: String in used:
		if problem == "" and not id in have:
			problem = "The game asks for the gate '%s' and the table has no row." % id
	# The contract sale is no row: it keeps what a save had, and nothing asks it.
	if problem == "" and gs.KEPT_CONTRACT_SALE in have:
		problem = "The contract sale is not a table row."
	var data: Dictionary = gs.farm_to_dict()
	data["lab_gates_kept"] = [gs.KEPT_CONTRACT_SALE]
	if problem == "" and gs.farm_dict_problem(data) != "":
		problem = "A kept contract sale saves: %s" % gs.farm_dict_problem(data)
	var quest: Dictionary = DataManager.get_record(&"quests", &"paperwork_from_orbit", "quests")
	if problem == "" and int(quest.get("gates", {}).get("lab_level", -1)) != gs.lab_gate_level("oirm_account"):
		problem = "The quest and the gate name different levels for the OIRM account."
	gs.free()
	return problem


func test_a_gated_job_stays_off_the_board_until_its_level() -> String:
	var gs: GameStateScript = _state()
	gs.credibility = 9999
	gs.refresh_job_board(1)
	var problem: String = ""
	if not gs.job_board.is_empty():
		problem = "The board stays empty below the board's level."
	_at_level(gs, gs.lab_gate_level("job_board"))
	gs.refresh_job_board(2)
	if problem == "" and gs.job_board.is_empty():
		problem = "The board fills at its level."
	for job: Dictionary in gs.job_board:
		if problem == "" and not gs.lab_gate_open(gs.job_gate_id(str(job.get("min_band", "")))):
			problem = "A job of a shut gate is on the board: %s" % job.get("min_band", "")
	gs.free()
	return problem


func test_a_guest_sees_the_same_gates_as_the_host() -> String:
	var host: GameStateScript = _state()
	var problem: String = ""
	var guest: GameStateScript = _state()
	for level: int in [1, 20, 45]:
		_at_level(host, level)
		var data: Dictionary = host.farm_to_dict()
		FarmCommands.guest = true
		var read: String = guest.farm_from_dict(data)
		FarmCommands.guest = false
		if read != "":
			problem = "The guest loads the host's farm: %s" % read
		for id: String in host.all_lab_gate_ids():
			if problem == "" and host.lab_gate_problem(id, "X") != guest.lab_gate_problem(id, "X"):
				problem = "At level %d the guest reads '%s' as '%s', the host as '%s'." % [level, id, guest.lab_gate_problem(id, "X"), host.lab_gate_problem(id, "X")]
		for id: String in [FM3, TW6, HB700]:
			if problem == "" and host.tier_problem(id) != guest.tier_problem(id):
				problem = "At level %d the guest reads %s differently." % [level, id]
	guest.free()
	host.free()
	return problem
