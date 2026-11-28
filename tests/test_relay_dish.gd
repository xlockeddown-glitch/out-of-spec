extends RefCounted
## Slice 29: the relay dish and the Gossamer link (lab level 48,
## docs/design/quests_levels_story.md sections 3.4, 5.7, step 9).
## Offered in the morning once lab level 48 is reached. Step a seats a whole
## Orbital Silk-Spinner spool in the relay; step b counts 1 traceable, on-time
## relay_dish_azimuth calibration after the offer; pays once (1000 lab XP, 500 CR).
## Once done, a whole Silk-Spinner spool seated in the relay adds an extra 20 %
## multiplicative lag cut ("Gossamer link: up"), stopping when swapped or damaged
## ("Gossamer link: stuttering"). Every GameState is freed and globals restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const LATE_GUEST: String = "player_3"
const QUEST_ID: String = "gossamer_link"
const GATE_ID: String = "relay_dish"
const SILK_SPINNER: StringName = &"orbital_silk_spinner"
const CURLYHAIR: StringName = &"curlyhair"
const SENTINEL: StringName = &"cobalt_sentinel"
const DISH_ID: String = "relay_dish_azimuth"
const REWARD_XP: int = 1000
const REWARD_CR: int = 500


func _run(body: Callable) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var saved_guest: bool = FarmCommands.guest
	GameClock.elapsed_days = 10.0
	CoopSession.players.clear()
	FarmCommands.guest = false
	var gs: GameStateScript = _farm()
	var out: Variant = body.call(gs)
	gs.free()
	FarmCommands.guest = saved_guest
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(48)
	gs.reset_credibility()
	return gs


func _at_level(gs: GameStateScript, level: int) -> void:
	gs.lab_xp = gs.xp_for_level(level)


func _cal_row(overrides: Dictionary = {}) -> Dictionary:
	var today: int = GameClock.get_day_index()
	var row: Dictionary = {
		"instrument_id": DISH_ID,
		"unit": "degrees",
		"mpe": 0.45,
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
		"standard_id": "rotary_table",
		"standard_uncertainty": 0.02,
		"tur": 22.5,
		"plain_tur": 22.5,
		"acceptance_limit": 0.43,
		"result": "PASS",
		"traceable": true,
		"bench_minutes": 45,
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


func test_gate_is_built_at_48_and_offered_in_morning_only() -> String:
	return _run(_check_offer_gates)


func _check_offer_gates(gs: GameStateScript) -> String:
	var gate_level: int = gs.lab_gate_level(GATE_ID)
	if gate_level != 48:
		return "relay_dish lab gate must be built at level 48, got %d." % gate_level
	# Below level 48 -> not offered even on a morning look.
	_at_level(gs, gate_level - 1)
	gs.update_quests()
	if gs.quest_state.has(QUEST_ID):
		return "Must not offer gossamer_link below level 48."
	# At level 48, mid-day command look (offers=false) must NOT offer it.
	_at_level(gs, gate_level)
	var none: Array[String] = []
	gs.update_quests(none, false)
	if gs.quest_state.has(QUEST_ID):
		return "Must not offer gossamer_link mid-day after a command."
	# Morning look (offers=true) offers it.
	gs.update_quests()
	if not gs.quest_state.has(QUEST_ID) or QuestEngine.is_done(gs, QUEST_ID):
		return "Morning look at level 48 must offer gossamer_link."
	if not _has_line(gs, "ODALYS: New quest, The Gossamer Link."):
		return "Offer must post Odalys phone line: %s" % [gs.phone_log]
	# Validate data_problem rejects a relay_spool step without species.
	var bad: Dictionary = {
		"id": "bad_relay", "kind": "lab", "giver": "odalys", "title": "Bad", "scope": "farm",
		"steps": [{ "id": "s", "text": "Seat.", "check": "relay_spool" }], "rewards": {},
	}
	if not QuestEngine.data_problem(bad).contains("species"):
		return "relay_spool without species must be rejected by data_problem: '%s'" % QuestEngine.data_problem(bad)
	return ""


func test_level_up_to_48_announces_relay_dish() -> String:
	return _run(_check_level_up_line)


func _check_level_up_line(gs: GameStateScript) -> String:
	var level: int = gs.lab_gate_level(GATE_ID)
	_at_level(gs, level - 1)
	gs.give_lab_xp(gs.xp_for_level(level) - gs.lab_xp)
	var line: String = str(gs.phone_log[-1]) if not gs.phone_log.is_empty() else ""
	if not line.contains("The relay dish"):
		return "Level 48 line should mention The relay dish: '%s'" % line
	return ""


func test_steps_refuse_wrong_spool_and_wrong_cals_and_pay_once() -> String:
	return _run(_check_steps_and_payout)


func _check_steps_and_payout(gs: GameStateScript) -> String:
	# Calibration BEFORE the quest is offered must not count for step b.
	gs.cal_log.append(_cal_row())
	_at_level(gs, 48)
	gs.update_quests()
	if not gs.quest_state.has(QUEST_ID):
		return "Setup: gossamer_link must be offered at level 48."
	var none: Array[String] = []
	# Step a: damaged Silk-Spinner spool must NOT pass.
	gs._add_spool(SILK_SPINNER, true)
	if not gs.slot_spool_into_relay(HOST):
		return "Setup: damaged spool must slot into empty relay."
	gs.update_quests(none, false)
	if "seat_silk" in gs.quest_state[QUEST_ID]["steps_done"]:
		return "Step a must refuse a damaged Orbital Silk-Spinner spool."
	# Step a: another species (Curlyhair) must NOT pass.
	gs._add_spool(CURLYHAIR, false)
	if not gs.slot_spool_into_relay(HOST):
		return "Setup: whole Curlyhair spool must replace damaged spool."
	gs.update_quests(none, false)
	if "seat_silk" in gs.quest_state[QUEST_ID]["steps_done"]:
		return "Step a must refuse a Curlyhair spool."
	# Step a: whole Orbital Silk-Spinner spool swaps in and passes step a.
	gs._add_spool(SILK_SPINNER, false)
	if not gs.can_slot_spool() or not gs.slot_spool_into_relay(HOST):
		return "Whole Orbital Silk-Spinner spool must be allowed to replace Curlyhair while quest is open."
	if gs.slotted_spool_species != SILK_SPINNER or gs.slotted_spool_damaged:
		return "Relay must now hold whole Orbital Silk-Spinner spool."
	gs.update_quests(none, false)
	if not ("seat_silk" in gs.quest_state[QUEST_ID]["steps_done"]):
		return "Step a must complete when whole Orbital Silk-Spinner spool is seated."
	if QuestEngine.is_done(gs, QUEST_ID):
		return "Pre-offer dish calibration must not complete step b."
	# Step b: invalid calibrations must NOT complete step b.
	gs.cal_log.append(_cal_row({ "traceable": false }))
	gs.cal_log.append(_cal_row({ "on_time": false }))
	gs.cal_log.append(_cal_row({ "instrument_id": "soil_probe" }))
	gs.cal_log.append(_cal_row({ "instrument_id": GameStateScript.STEERING_ID }))
	gs.update_quests(none, false)
	if QuestEngine.is_done(gs, QUEST_ID):
		return "Untraceable, late, or wrong-instrument calibrations must not complete step b."
	# Step b: 1 traceable, on-time relay_dish_azimuth calibration completes and pays once.
	var xp_before: int = gs.lab_xp
	var cr_before: int = gs.credits
	gs.cal_log.append(_cal_row())
	gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, QUEST_ID):
		return "Traceable, on-time relay_dish_azimuth calibration must complete gossamer_link."
	if gs.lab_xp != xp_before + REWARD_XP:
		return "Expected +%d lab XP, got +%d." % [REWARD_XP, gs.lab_xp - xp_before]
	if gs.credits != cr_before + REWARD_CR:
		return "Expected +%d CR, got +%d." % [REWARD_CR, gs.credits - cr_before]
	if not gs.quest_points.is_empty():
		return "Lab quest must pay no quest points."
	if not _has_line(gs, "QUEST DONE: The Gossamer Link.") or not _has_line(gs, "Gossamer link is up"):
		return "Completion must post QUEST DONE and Odalys done line: %s" % [gs.phone_log]
	# Extra calibrations and another morning look must pay nothing more.
	var xp_after: int = gs.lab_xp
	var cr_after: int = gs.credits
	var done_lines: int = _lines(gs, "QUEST DONE: The Gossamer Link.")
	gs.cal_log.append(_cal_row())
	gs.update_quests()
	if gs.lab_xp != xp_after or gs.credits != cr_after or _lines(gs, "QUEST DONE: The Gossamer Link.") != done_lines:
		return "Completed quest must pay once and post no second QUEST DONE."
	return ""


func test_lag_cut_applies_only_when_done_and_whole_silk_spinner_seated() -> String:
	return _run(_check_lag_cut)


func _check_lag_cut(gs: GameStateScript) -> String:
	# Before quest is done: existing relay lag numbers are completely unchanged.
	if not is_equal_approx(gs.get_relay_lag_multiplier(), 1.0):
		return "Stock relay lag must be 1.0."
	gs._add_spool(CURLYHAIR, false)
	gs.slot_spool_into_relay(HOST)
	if not is_equal_approx(gs.get_relay_lag_multiplier(), 0.38):
		return "Curlyhair relay lag before quest must stay 0.38, got %s." % gs.get_relay_lag_multiplier()
	gs._add_spool(SENTINEL, false)
	gs.slot_spool_into_relay(HOST)
	if not is_equal_approx(gs.get_relay_lag_multiplier(), 0.30):
		return "Cobalt Sentinel relay lag before quest must stay 0.30, got %s." % gs.get_relay_lag_multiplier()
	# Whole Silk-Spinner seated BEFORE quest is done: base 60 % cut * species 30 % cut = 0.28,
	# already lower than whole Cobalt Sentinel (0.30), with no extra 20 % yet.
	var sentinel_mult: float = gs.get_relay_lag_multiplier()
	gs.relay_slotted = false
	gs._spool_species.clear()
	gs._spool_damaged.clear()
	gs.optical_silk_spools = 0
	gs._add_spool(SILK_SPINNER, false)
	gs.slot_spool_into_relay(HOST)
	var spinner_before: float = gs.get_relay_lag_multiplier()
	if not is_equal_approx(spinner_before, 0.28):
		return "Whole Silk-Spinner before quest done must be 0.28, got %s." % spinner_before
	if not (spinner_before < sentinel_mult):
		return "Whole Silk-Spinner without link (%s) must still beat Cobalt Sentinel (%s)." % [spinner_before, sentinel_mult]
	if gs.gossamer_link_up() or gs.gossamer_status_text() != "":
		return "Before quest done, gossamer_link_up must be false and status empty."
	# Offer and complete the quest.
	_at_level(gs, 48)
	gs.update_quests()
	gs.cal_log.append(_cal_row())
	var none: Array[String] = []
	gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, QUEST_ID):
		return "Setup: quest must complete."
	# Now done AND whole Silk-Spinner seated -> 0.28 * 0.80 = 0.224 (< Cobalt Sentinel 0.30).
	if not gs.gossamer_link_up() or gs.gossamer_status_text() != "Gossamer link: up":
		return "Link must be up after completion: '%s'" % gs.gossamer_status_text()
	var spinner_after: float = gs.get_relay_lag_multiplier()
	if not is_equal_approx(spinner_after, 0.224) or not (spinner_after < sentinel_mult):
		return "Expected 0.224 (< %s) with Gossamer link up, got %s." % [sentinel_mult, spinner_after]
	# Cobalt Sentinel (0.30) in stock must NOT replace whole Silk-Spinner (0.224).
	gs._add_spool(SENTINEL, false)
	if gs.can_slot_spool():
		return "Cobalt Sentinel (0.30) must not replace whole Silk-Spinner (0.224) after completion."
	# Damage the seated Silk-Spinner -> link stutters, base damaged cut * species cut (0.70 * 0.70 = 0.49).
	gs.slotted_spool_damaged = true
	if gs.gossamer_link_up() or gs.gossamer_status_text() != "Gossamer link: stuttering":
		return "Damaged Silk-Spinner must make link stutter: '%s'" % gs.gossamer_status_text()
	if not is_equal_approx(gs.get_relay_lag_multiplier(), 0.49):
		return "Damaged Silk-Spinner must be 0.49 (no extra cut), got %s." % gs.get_relay_lag_multiplier()
	# Whole Cobalt Sentinel in stock replaces the damaged Silk-Spinner -> link still stutters, 0.30.
	if not gs.can_slot_spool() or not gs.slot_spool_into_relay(HOST):
		return "Setup: whole Cobalt Sentinel must replace a damaged Silk-Spinner."
	if gs.gossamer_link_up() or gs.gossamer_status_text() != "Gossamer link: stuttering":
		return "Swapping to another species must make link stutter: '%s'" % gs.gossamer_status_text()
	if not is_equal_approx(gs.get_relay_lag_multiplier(), 0.30):
		return "Swapped Cobalt Sentinel must stay 0.30 (no extra cut), got %s." % gs.get_relay_lag_multiplier()
	# Whole Silk-Spinner (0.224) in stock replaces whole Cobalt Sentinel (0.30) -> link up again (0.224).
	gs._add_spool(SILK_SPINNER, false)
	if not gs.can_slot_spool() or not gs.slot_spool_into_relay(HOST):
		return "Whole Silk-Spinner (0.224) in stock must replace Cobalt Sentinel (0.30) to restore Gossamer link."
	if not gs.gossamer_link_up() or not is_equal_approx(gs.get_relay_lag_multiplier(), 0.224):
		return "Re-seating whole Silk-Spinner must restore 0.224 lag multiplier, got %s." % gs.get_relay_lag_multiplier()
	return ""


func test_swap_rule_is_stable_and_never_loops() -> String:
	return _run(_check_swap_stability)


func _check_swap_stability(gs: GameStateScript) -> String:
	# 1. Quest not offered: Silk-Spinner (0.28) beats Curlyhair (0.38) in one swap, then stable.
	gs._add_spool(CURLYHAIR, false)
	if not gs.slot_spool_into_relay(HOST):
		return "Setup: Curlyhair must slot into empty relay."
	gs._add_spool(SILK_SPINNER, false)
	var swaps_before: int = 0
	while gs.can_slot_spool() and swaps_before < 4:
		gs.slot_spool_into_relay(HOST)
		swaps_before += 1
	if swaps_before != 1 or gs.can_slot_spool():
		return "Before quest offered, Silk-Spinner (0.28) must replace Curlyhair (0.38) once then stop, got %d swaps." % swaps_before
	if gs.slotted_spool_species != SILK_SPINNER:
		return "Before quest offered, single swap must seat Silk-Spinner, got %s." % gs.slotted_spool_species
	# 2. Quest offered, seat_silk pending with Cobalt Sentinel seated: Silk-Spinner replaces Sentinel once and stops.
	gs.slotted_spool_species = SENTINEL
	gs.slotted_spool_damaged = false
	gs._spool_species.clear()
	gs._spool_damaged.clear()
	gs.optical_silk_spools = 0
	gs._add_spool(SILK_SPINNER, false)
	_at_level(gs, 48)
	gs.update_quests()
	var swaps_open: int = 0
	while gs.can_slot_spool() and swaps_open < 4:
		gs.slot_spool_into_relay(HOST)
		swaps_open += 1
	if swaps_open != 1 or gs.can_slot_spool():
		return "With quest open, Silk-Spinner must replace Sentinel once then stop, got %d swaps." % swaps_open
	var none: Array[String] = []
	gs.update_quests(none, false)
	if not ("seat_silk" in gs.quest_state[QUEST_ID]["steps_done"]):
		return "Setup: seat_silk must be done after seating whole Silk-Spinner."
	# 3. Complete the quest: Silk-Spinner (0.224) stays seated; Sentinel (0.30) in stock does not swap back.
	gs.cal_log.append(_cal_row())
	gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, QUEST_ID):
		return "Setup: quest must complete."
	if gs.slotted_spool_species != SILK_SPINNER or not gs.gossamer_link_up():
		return "After quest done, Silk-Spinner must stay seated with link up."
	if gs.can_slot_spool():
		return "After quest done, Cobalt Sentinel in stock must not replace seated Silk-Spinner."
	return ""


func test_old_save_past_48_gets_offer_next_morning_and_guest_sees_progress() -> String:
	return _run(_check_save_and_coop)


func _check_save_and_coop(gs: GameStateScript) -> String:
	# Old save past level 48 without gossamer_link in quest_state.
	_at_level(gs, 50)
	gs.cal_log.append(_cal_row())
	var saved: Dictionary = gs.farm_to_dict()
	var loaded: GameStateScript = _farm()
	var problem: String = loaded.farm_from_dict(saved)
	if problem != "":
		loaded.free()
		return "Old save past 48 must load cleanly: %s" % problem
	if loaded.quest_state.has(QUEST_ID):
		loaded.free()
		return "Loaded save should not already have gossamer_link before morning."
	# Next morning offers gossamer_link.
	loaded.update_quests()
	if not loaded.quest_state.has(QUEST_ID) or QuestEngine.is_done(loaded, QUEST_ID):
		loaded.free()
		return "Old save past 48 must get gossamer_link on next morning."
	# Host completes step a (seats whole Silk-Spinner); guest syncs and sees step b open.
	loaded._add_spool(SILK_SPINNER, false)
	loaded.slot_spool_into_relay(HOST)
	var none: Array[String] = []
	loaded.update_quests(none, false)
	var guest: GameStateScript = _farm()
	FarmCommands.guest = true
	var read_guest: String = guest.farm_from_dict(loaded.farm_to_dict())
	guest.local_player_id = GUEST
	var guest_row: Dictionary = _open_row(guest, GUEST, QUEST_ID)
	# Guest calling update_quests() must be a no-op.
	guest.cal_log.append(_cal_row())
	guest.update_quests()
	var guest_still_open: bool = not QuestEngine.is_done(guest, QUEST_ID)
	FarmCommands.guest = false
	guest.free()
	if read_guest != "" or guest_row.is_empty() or not str(guest_row.get("step", "")).contains("relay dish azimuth"):
		loaded.free()
		return "Guest must see step b open via quest_state: %s (%s)" % [read_guest, guest_row]
	if not guest_still_open:
		loaded.free()
		return "Guest must never complete quests locally."
	# Host completes step b; late joiner connects and sees link up and 0.224 lag multiplier.
	loaded.cal_log.append(_cal_row())
	loaded.update_quests(none, false)
	var late: GameStateScript = _farm()
	FarmCommands.guest = true
	var read_late: String = late.farm_from_dict(loaded.farm_to_dict())
	late.local_player_id = LATE_GUEST
	var late_ok: bool = read_late == "" and QuestEngine.is_done(late, QUEST_ID) \
		and late.gossamer_link_up() and late.gossamer_status_text() == "Gossamer link: up" \
		and is_equal_approx(late.get_relay_lag_multiplier(), 0.224)
	FarmCommands.guest = false
	late.free()
	loaded.free()
	return "" if late_ok else "Late joiner must see gossamer_link done, link up, and 0.224 lag multiplier."
