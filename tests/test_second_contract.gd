extends RefCounted
## Slice 28: the second OIRM contract (lab level 35, docs/design/quests_levels_story.md
## sections 3.4, 5.7, step 9). Offered in the morning once lab level 35 is reached
## and the first contract is complete (or fulfilled). Counts 8 traceable, on-time
## calibrations by a player's own hand with interval_evidence; pays once (900 lab XP,
## 400 CR). Every GameState is freed and global state is restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const LATE_GUEST: String = "player_3"
const QUEST_ID: String = "second_contract"
const FIRST_ID: String = "first_contract"
const NEED: int = 8
const REWARD_XP: int = 900
const REWARD_CR: int = 400


func _run(body: Callable) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	GameClock.elapsed_days = 10.0
	CoopSession.players.clear()
	var gs: GameStateScript = _farm()
	var out: Variant = body.call(gs)
	gs.free()
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(35)
	gs.reset_credibility()
	return gs


func _at_level(gs: GameStateScript, level: int) -> void:
	gs.lab_xp = gs.xp_for_level(level)


func _cal_row(overrides: Dictionary = {}) -> Dictionary:
	var today: int = GameClock.get_day_index()
	var row: Dictionary = {
		"instrument_id": "soil_probe",
		"unit": "%",
		"mpe": 3.0,
		"as_found": 0.1,
		"as_found_band": "PASS",
		"as_found_in_tolerance": true,
		"as_left": 0.0,
		"as_left_band": "PASS",
		"day": today,
		"performed_by": HOST,
		"programmed_by": "",
		"on_time": true,
		"days_in_service": 5,
		"interval_evidence": true,
		"previous_interval_days": 5,
		"interval_days": 7,
		"due_day": today + 7,
		"standard_id": "gravimetric_kit",
		"standard_uncertainty": 0.2,
		"tur": 15.0,
		"plain_tur": 15.0,
		"acceptance_limit": 2.8,
		"result": "PASS",
		"traceable": true,
		"bench_minutes": 30,
		"standard_overdue": false,
		"standard_problem": "",
		"standard_certificate": "FND-0001",
		"suspect": false,
	}
	row.merge(overrides, true)
	return row


func _has_line(gs: GameStateScript, part: String) -> bool:
	return _lines(gs, part) > 0


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _open_row(gs: GameStateScript, player_id: String, quest_id: String) -> Dictionary:
	var lists: Dictionary = QuestLog.of(gs, player_id)
	for row: Dictionary in lists[QuestLog.OPEN]:
		if str(row.get("id", "")) == quest_id:
			return row
	return {}


func test_gate_is_built_at_level_35_and_not_offered_below_or_before_first() -> String:
	return _run(_check_offer_gates)


func _check_offer_gates(gs: GameStateScript) -> String:
	var gate_level: int = gs.lab_gate_level(QUEST_ID)
	if gate_level != 35:
		return "second_contract lab gate must be built at level 35, got %d." % gate_level
	# Below level 35 with first contract complete -> not offered.
	_at_level(gs, gate_level - 1)
	gs.contract_state = "complete"
	gs.update_quests()
	if gs.quest_state.has(QUEST_ID):
		return "Must not offer second_contract below level 35."
	# At level 35 with first contract not complete (empty or active) -> not offered.
	_at_level(gs, gate_level)
	gs.contract_state = ""
	gs.update_quests()
	if gs.quest_state.has(QUEST_ID):
		return "Must not offer second_contract before first contract exists."
	gs.contract_state = "active"
	gs.update_quests()
	if gs.quest_state.has(QUEST_ID):
		return "Must not offer second_contract while first contract is still active."
	# At level 35 with first contract complete: a command look (offers=false) must NOT offer it.
	gs.contract_state = "complete"
	var none: Array[String] = []
	gs.update_quests(none, false)
	if gs.quest_state.has(QUEST_ID):
		return "Must not offer second_contract mid-day after a command."
	# Morning look (offers=true) offers it.
	gs.update_quests()
	if not gs.quest_state.has(QUEST_ID) or QuestEngine.is_done(gs, QUEST_ID):
		return "Morning look at level 35 with first contract complete must offer second_contract."
	if not _has_line(gs, "OIRM: New quest, The Second Contract."):
		return "Offer must post OIRM phone line: %s" % [gs.phone_log]
	# Fulfilled also qualifies on a fresh farm.
	var other: GameStateScript = _farm()
	_at_level(other, gate_level)
	other.contract_state = "fulfilled"
	other.update_quests()
	var offered_fulfilled: bool = other.quest_state.has(QUEST_ID) and not QuestEngine.is_done(other, QUEST_ID)
	other.free()
	return "" if offered_fulfilled else "Fulfilled first contract must also unlock second_contract."


func test_level_up_to_35_announces_second_contract() -> String:
	return _run(_check_level_up_line)


func _check_level_up_line(gs: GameStateScript) -> String:
	var level: int = gs.lab_gate_level(QUEST_ID)
	_at_level(gs, level - 1)
	gs.give_lab_xp(gs.xp_for_level(level) - gs.lab_xp)
	var line: String = str(gs.phone_log[-1]) if not gs.phone_log.is_empty() else ""
	if not line.contains("The second OIRM contract"):
		return "Level 35 line should mention the second OIRM contract: '%s'" % line
	return ""


func test_progress_counts_only_valid_work_and_pays_once() -> String:
	return _run(_check_progress_and_payout)


func _check_progress_and_payout(gs: GameStateScript) -> String:
	# Two valid calibrations BEFORE the quest is offered must not count.
	gs.cal_log.append(_cal_row())
	gs.cal_log.append(_cal_row())
	_at_level(gs, 35)
	gs.contract_state = "complete"
	gs.update_quests()
	if not gs.quest_state.has(QUEST_ID):
		return "Setup: second_contract must be offered."
	var row: Dictionary = _open_row(gs, HOST, QUEST_ID)
	if row.is_empty() or int(row["have"]) != 0 or int(row["need"]) != NEED:
		return "QuestLog must start at 0 of %d, got %s." % [NEED, row]
	# Invalid calibrations must NOT advance the count.
	gs.cal_log.append(_cal_row({ "on_time": false }))
	gs.cal_log.append(_cal_row({ "traceable": false }))
	gs.cal_log.append(_cal_row({ "performed_by": GameStateScript.MANAGER_ID }))
	gs.cal_log.append(_cal_row({ "programmed_by": HOST, "performed_by": "R-1" }))
	gs.cal_log.append(_cal_row({ "interval_evidence": false }))
	var none: Array[String] = []
	gs.update_quests(none, false)
	row = _open_row(gs, HOST, QUEST_ID)
	if int(row["have"]) != 0:
		return "Late, untraceable, manager, robot, or same-day repeat calibrations must not count: %s" % [row]
	# 3 valid calibrations -> QuestLog shows "3 of 8" and phone posts progress.
	for _i: int in 3:
		gs.cal_log.append(_cal_row())
		gs.update_quests(none, false)
	row = _open_row(gs, HOST, QUEST_ID)
	if int(row["have"]) != 3 or int(row["need"]) != NEED or not QuestLog.step_text(row).ends_with("3 of 8"):
		return "QuestLog must show '3 of 8', got '%s'." % QuestLog.step_text(row)
	if not _has_line(gs, "QUEST The Second Contract: 3 of 8."):
		return "Phone must post progress count '3 of 8': %s" % [gs.phone_log]
	# Finish the remaining 5 valid calibrations -> completes at 8 and pays once.
	var xp_before: int = gs.lab_xp
	var cr_before: int = gs.credits
	for _i: int in NEED - 3:
		gs.cal_log.append(_cal_row())
		gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, QUEST_ID):
		return "Quest must complete at %d valid calibrations." % NEED
	if gs.lab_xp != xp_before + REWARD_XP:
		return "Expected +%d lab XP, got +%d." % [REWARD_XP, gs.lab_xp - xp_before]
	if gs.credits != cr_before + REWARD_CR:
		return "Expected +%d CR, got +%d." % [REWARD_CR, gs.credits - cr_before]
	if not gs.quest_points.is_empty():
		return "Lab quest must pay no quest points."
	if not _has_line(gs, "QUEST DONE: The Second Contract.") or not _has_line(gs, "OIRM: [PLACEHOLDER] Eight traceable"):
		return "Completion must post QUEST DONE and OIRM done line: %s" % [gs.phone_log]
	# Extra calibrations and another morning update must pay nothing more.
	var xp_after: int = gs.lab_xp
	var cr_after: int = gs.credits
	var done_lines: int = _lines(gs, "QUEST DONE: The Second Contract.")
	for _i: int in NEED:
		gs.cal_log.append(_cal_row())
	gs.update_quests()
	if gs.lab_xp != xp_after or gs.credits != cr_after or _lines(gs, "QUEST DONE: The Second Contract.") != done_lines:
		return "Second completion must pay nothing and post no second QUEST DONE."
	return ""


func test_old_save_past_35_gets_offer_next_morning_without_double_pay() -> String:
	return _run(_check_old_save)


func _check_old_save(gs: GameStateScript) -> String:
	# Simulate an older save past level 35 where first_contract is already done
	# and second_contract did not exist yet in quest_state.
	_at_level(gs, 37)
	gs.contract_state = "fulfilled"
	gs.quest_state[FIRST_ID] = {
		"accepted": 5, "steps_done": ["run"], "base": {}, "shown": {}, "players": [HOST], "done": 6,
	}
	gs.cal_log.append(_cal_row())
	var saved: Dictionary = gs.farm_to_dict()
	var loaded: GameStateScript = _farm()
	var problem: String = loaded.farm_from_dict(saved)
	if problem != "":
		loaded.free()
		return "Old save must load cleanly: %s" % problem
	if loaded.quest_state.has(QUEST_ID):
		loaded.free()
		return "Loaded save should not already have second_contract before morning."
	var xp_before: int = loaded.lab_xp
	var cr_before: int = loaded.credits
	# Next morning offers second_contract and does NOT re-pay first_contract.
	loaded.update_quests()
	var ok: bool = loaded.quest_state.has(QUEST_ID) and not QuestEngine.is_done(loaded, QUEST_ID) \
		and loaded.lab_xp == xp_before and loaded.credits == cr_before
	var row: Dictionary = _open_row(loaded, HOST, QUEST_ID)
	ok = ok and int(row.get("have", -1)) == 0 and int(row.get("need", -1)) == NEED
	loaded.free()
	return "" if ok else "Old save past 35 must get second_contract next morning at 0 of %d with no double pay." % NEED


func test_guest_and_late_joiner_see_progress_and_do_not_run_engine() -> String:
	return _run(_check_coop_sync)


func _check_coop_sync(gs: GameStateScript) -> String:
	_at_level(gs, 35)
	gs.contract_state = "complete"
	gs.update_quests()
	var none: Array[String] = []
	for _i: int in 3:
		gs.cal_log.append(_cal_row())
		gs.update_quests(none, false)
	# Guest syncs at 3 of 8.
	var guest: GameStateScript = _farm()
	FarmCommands.guest = true
	var read_guest: String = guest.farm_from_dict(gs.farm_to_dict())
	guest.local_player_id = GUEST
	var guest_row: Dictionary = _open_row(guest, GUEST, QUEST_ID)
	# Guest calling update_quests() must be a no-op.
	guest.cal_log.append(_cal_row())
	guest.update_quests()
	var guest_after: Dictionary = _open_row(guest, GUEST, QUEST_ID)
	FarmCommands.guest = false
	guest.free()
	if read_guest != "" or int(guest_row.get("have", -1)) != 3 or int(guest_row.get("need", -1)) != NEED:
		return "Guest must see 3 of %d via quest_state: %s (%s)" % [NEED, read_guest, guest_row]
	if int(guest_after.get("have", -1)) != 3:
		return "Guest must never advance quests locally."
	# Host advances to 5 of 8; late joiner connects and sees 5 of 8.
	for _i: int in 2:
		gs.cal_log.append(_cal_row())
		gs.update_quests(none, false)
	var late: GameStateScript = _farm()
	FarmCommands.guest = true
	var read_late: String = late.farm_from_dict(gs.farm_to_dict())
	late.local_player_id = LATE_GUEST
	var late_row: Dictionary = _open_row(late, LATE_GUEST, QUEST_ID)
	FarmCommands.guest = false
	late.free()
	if read_late != "" or int(late_row.get("have", -1)) != 5 or int(late_row.get("need", -1)) != NEED:
		return "Late joiner must see 5 of %d via quest_state: %s (%s)" % [NEED, read_late, late_row]
	return ""
