extends RefCounted
## Quests S2 "Warmly, Dispatch" and L2 "Paperwork From Orbit" (build order step
## 12, part 1, of docs/design/quests_levels_story.md), a quest's endings, and
## the mug ring on the dome's bench.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DRIFT: StringName = &"sensor_drift_config"
const HOST: String = "player_1"
const S2: String = "warmly_dispatch"
const L2: String = "paperwork_from_orbit"
const FM3: String = "field_meter_dc"
const OFFER: String = "ODALYS: New quest, Warmly, Dispatch."
const DOME: String = "res://scenes/dome_interior.tscn"


## Runs `body` on a new farm. `fixtures` replace the shipped quests if given.
func _run(body: Callable, fixtures: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	if not fixtures.is_empty():
		var mine: Dictionary = {}
		for quest: Dictionary in fixtures:
			mine[StringName(str(quest["id"]))] = quest
		table["quests"] = mine
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	gs.free()
	table["quests"] = shipped
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _shipped(id: String) -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest["id"]) == id:
			return quest
	return {}


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


## The giver's line for a dialogue path, as the phone shows it.
func _said(giver: String, path: String) -> String:
	return "%s: %s" % [giver, QuestEngine.phone_line(path)]


func _clean_note() -> String:
	return _said("ODALYS", "npcs/odalys/quests/warmly_dispatch_clean")


func _grace_note() -> String:
	return _said("ODALYS", "npcs/odalys/quests/warmly_dispatch_grace")


func _cadence() -> int:
	return int(DataManager.get_number(DRIFT, "audit_schedule/cadence_days", 5.0))


## Every unit in tolerance and in date, so an audit finds nothing.
func _all_in_date(gs: GameStateScript) -> void:
	for id: String in gs.unit_ids() + gs.standard_ids():
		gs.get_sensor(id).error = 0.0
		gs.get_sensor(id).cal_due_day = 100 * _cadence()


## The morning of the first audit day, as the game runs it.
func _first_audit_morning(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(_cadence() - 1)
	gs._on_day_started(_cadence())


# --- The data -------------------------------------------------------------------

func test_s2_and_l2_ship_as_the_design_has_them() -> String:
	var s2: Dictionary = _shipped(S2)
	var l2: Dictionary = _shipped(L2)
	if s2.is_empty() or l2.is_empty():
		return "S2 and L2 must ship."
	if QuestEngine.data_problem(s2) != "" or QuestEngine.data_problem(l2) != "":
		return "The data: %s %s" % [QuestEngine.data_problem(s2), QuestEngine.data_problem(l2)]
	if s2["kind"] != "story" or s2["giver"] != "odalys" or not (s2["gates"] as Dictionary).is_empty() \
			or int(s2["rewards"].get("quest_points", 0)) != 1 or int(s2["rewards"].get("lab_xp", 0)) <= 0:
		return "S2: a story quest from Odalys, no gate, 1 quest point and lab XP."
	var ids: Array = []
	for ending: Dictionary in s2["endings"]:
		ids.append(ending["id"])
	if ids != ["grace", "clean"]:
		return "S2 has two endings, the warning looked at first: %s" % [ids]
	if l2["kind"] != "lab" or l2["giver"] != "oirm" or int((l2["gates"] as Dictionary).get("lab_level", 0)) != 12 \
			or (l2["gates"] as Dictionary).size() != 1:
		return "L2: a lab quest from OIRM, gated on lab level 12: %s" % [l2["gates"]]
	if int(l2["rewards"].get("lab_xp", 0)) != 300 or int(l2["rewards"].get("credits", 0)) != 100 \
			or int(l2["rewards"].get("quest_points", 0)) != 0:
		return "L2 pays 300 lab XP and 100 CR, and no quest point."
	var steps: Array = []
	for step: Dictionary in l2["steps"]:
		steps.append(step["id"])
	return "" if steps == ["account", "send", "certificate"] else "L2's steps: %s" % [steps]


## Odalys signs her closing notes as the morning dispatches do, for BNH. The
## offer is not signed: the phone puts the step's text after it.
func test_odalys_signs_warmly_dispatch() -> String:
	var lines: Variant = DataManager.get_value(&"dialogue_dispatches", "npcs/odalys/quests")
	if not lines is Dictionary or (lines as Dictionary).size() < 3:
		return "Odalys has an offer and a note for each ending."
	for key: Variant in lines:
		var text: String = str(lines[key])
		if text.to_lower().contains("omnispec"):
			return "%s must not name OmniSpec." % key
		# Her daily ask's lines (tests/test_quests_d2.gd) are not these notes.
		if str(key).begins_with("warmly_dispatch_") and text.ends_with(" Warmly, Dispatch.") == (str(key) == "warmly_dispatch_offer"):
			return "%s: the closing notes end ' Warmly, Dispatch.' and the offer does not." % key
		# The warning can come from a fault the bench has no part in.
		if text.to_lower().contains("overnight") or text.to_lower().contains("ran your bench"):
			return "%s must not say the bench was used overnight." % key
	for quest: Dictionary in [_shipped(S2), _shipped(L2)]:
		var paths: Array = [str(quest.get("offer_line", "")), str(quest.get("rewards", {}).get("phone", ""))]
		for ending: Variant in quest.get("endings", []):
			paths.append(str(ending["phone"]))
		for path: String in paths:
			if path != "" and QuestEngine.phone_line(path) == path:
				return "%s is a path with no text at it." % path
	return "" if _clean_note() != _grace_note() else "The two endings need different notes."


# --- S2 -------------------------------------------------------------------------

func test_s2_is_offered_at_the_start_with_odalys_note() -> String:
	return _run(_check_s2_offer)


func _check_s2_offer(gs: GameStateScript) -> String:
	gs.update_quests()
	if not gs.quest_state.has(S2) or QuestEngine.is_done(gs, S2):
		return "A new farm is offered S2: %s" % [gs.quest_state]
	var offer: String = "%s %s Have your first audit on file." % [OFFER, QuestEngine.phone_line("npcs/odalys/quests/warmly_dispatch_offer")]
	if _lines(gs, offer) != 1:
		return "The offer is Odalys's note and the step: %s" % [gs.phone_log]
	# No audit, no ending: a day with no audit leaves it open.
	gs._on_day_started(2)
	return "" if not QuestEngine.is_done(gs, S2) and _lines(gs, OFFER) == 1 else "S2 waits for the audit and is offered once."


func test_s2_ends_clean_after_a_clean_first_audit() -> String:
	return _run(_check_s2_clean)


func _check_s2_clean(gs: GameStateScript) -> String:
	gs.update_quests()
	_all_in_date(gs)
	_first_audit_morning(gs)
	if gs.audit_log.size() != 1 or gs.audit_grace_used or gs.clean_audit_streak != 1:
		return "The test needs a clean first audit: %s" % [gs.audit_log]
	if not QuestEngine.is_done(gs, S2) or _lines(gs, _clean_note()) != 1 or _lines(gs, _grace_note()) != 0:
		return "A clean first audit is ending A, with its note: %s" % [gs.phone_log]
	if _lines(gs, "QUEST DONE: Warmly, Dispatch. Reward: 100 lab XP, 1 quest point.") != 1:
		return "Finishing is a phone line: %s" % [gs.phone_log]
	return "" if gs.quest_points.get(HOST, {}).get(S2, 0) == 1 else "S2 pays 1 quest point: %s" % [gs.quest_points]


func test_s2_ends_with_the_warning_and_the_manager_at_the_bench() -> String:
	return _run(_check_s2_grace)


func _check_s2_grace(gs: GameStateScript) -> String:
	gs.update_quests()
	_all_in_date(gs)
	gs.steering.error = gs.steering.mpe * 2.0
	_first_audit_morning(gs)
	if gs.audit_log.size() != 1 or not gs.audit_grace_used:
		return "The test needs a first audit that used the one-time warning: %s" % [gs.audit_log]
	if not QuestEngine.is_done(gs, S2) or _lines(gs, _grace_note()) != 1 or _lines(gs, _clean_note()) != 0:
		return "A first audit with the warning is ending B, with its note: %s" % [gs.phone_log]
	if not _grace_note().contains("mug"):
		return "Odalys's note names the mug."
	return "" if gs.quest_points.get(HOST, {}).get(S2, 0) == 1 else "Ending B pays the same point: %s" % [gs.quest_points]


## Both endings pay the same, once, and the quest stays done through a save.
func test_s2_pays_the_same_for_both_endings_and_once() -> String:
	return _run(_check_s2_pay, [_shipped(S2)])


func _check_s2_pay(gs: GameStateScript) -> String:
	gs.update_quests()
	var before: int = gs.lab_xp
	gs.audit_log.append({ "day": 5, "passed": false, "warning": true })
	gs.audit_grace_used = true
	gs.update_quests()
	if gs.lab_xp != before + 100 or gs.quest_points != { HOST: { S2: 1 } } or _lines(gs, _grace_note()) != 1:
		return "Ending B pays 100 lab XP and 1 point: %d %s" % [gs.lab_xp - before, gs.quest_points]
	# A clean audit later changes nothing: the quest is done.
	gs.audit_log.append({ "day": 10, "passed": true, "clean": true })
	gs.clean_audit_streak = 1
	gs.update_quests()
	if gs.lab_xp != before + 100 or _lines(gs, "QUEST DONE") != 1 or _lines(gs, _clean_note()) != 0:
		return "S2 is paid once."
	var again: GameStateScript = GameStateScript.new()
	again.build_registry()
	var problem: String = again.farm_from_dict(gs.farm_to_dict())
	again.update_quests()
	var out: String = "" if problem == "" and again.lab_xp == gs.lab_xp and again.quest_state == gs.quest_state \
		and _lines(again, "QUEST DONE") <= 1 else "A loaded farm is not paid again: %s" % problem
	again.free()
	return out


## A farm from before the quest, with audits on file, is done at once.
func test_s2_on_an_old_farm_is_done_with_the_ending_it_had() -> String:
	return _run(_check_s2_old, [_shipped(S2)])


func _check_s2_old(gs: GameStateScript) -> String:
	gs.audit_log.append({ "day": 5, "passed": true, "clean": true })
	gs.audit_log.append({ "day": 10, "passed": true, "clean": true })
	gs.clean_audit_streak = 2
	gs.update_quests()
	if not QuestEngine.is_done(gs, S2) or _lines(gs, _clean_note()) != 1 or _lines(gs, "New quest") != 0:
		return "An old farm with clean audits is done, with ending A: %s" % [gs.phone_log]
	return ""


# --- Endings --------------------------------------------------------------------

func _ending_quest(endings: Variant, phone: String = "") -> Dictionary:
	var quest: Dictionary = { "id": "fork", "kind": "story", "giver": "lin", "title": "Fork", "scope": "farm", "gates": {},
		"steps": [{ "id": "pay", "text": "Have 1 CR.", "check": "stat_at_least", "stat": "credits" }],
		"rewards": {}, "endings": endings }
	if phone != "":
		quest["rewards"]["phone"] = phone
	return quest


func test_the_first_ending_that_holds_gives_the_line() -> String:
	var endings: Array = [
		{ "id": "ore", "when": "stat_at_least", "stat": "crystal_ore", "at_least": 3, "phone": "Ore." },
		{ "id": "tier", "when": "flag", "flag": "tier1_unlocked", "phone": "Tier." },
	]
	for case: Array in [[3, true, "LIN: Ore."], [0, true, "LIN: Tier."], [0, false, "LIN: Neither."]]:
		var want: String = case[2]
		var problem: String = _run(func(gs: GameStateScript) -> String:
			gs.crystal_ore = case[0]
			gs.tier1_unlocked = case[1]
			gs.credits = 5
			gs.update_quests()
			var said: int = _lines(gs, "LIN: Ore.") + _lines(gs, "LIN: Tier.") + _lines(gs, "LIN: Neither.")
			return "" if _lines(gs, want) == 1 and said == 1 else "Wanted only '%s': %s" % [want, gs.phone_log],
			[_ending_quest(endings, "Neither.")])
		if problem != "":
			return problem
	return ""


func test_bad_endings_are_refused() -> String:
	var good: Dictionary = { "id": "a", "when": "flag", "flag": "tier1_unlocked", "phone": "A." }
	if QuestEngine.data_problem(_ending_quest([good])) != "":
		return "A good ending is not a problem: %s" % QuestEngine.data_problem(_ending_quest([good]))
	for when: String in ["always", "day_at_least", "stat_at_least", "count", "counter", "level"]:
		if QuestEngine.data_problem(_ending_quest([{ "id": "a", "when": when, "phone": "A." }])) != "":
			return "'%s' is a check an ending may have." % when
	var bad: Array = [[], "grace", [3], [good, good], [{ "id": "a", "phone": "A." }],
		[{ "id": "a", "when": "flag", "flag": "tier1_unlocked" }], [{ "when": "always", "phone": "A." }],
		# A check no build has, a `when` that is not text, and no words.
		[{ "id": "a", "when": "flagg", "flag": "tier1_unlocked", "phone": "A." }],
		[{ "id": "a", "when": "", "phone": "A." }],
		[{ "id": "a", "when": 3, "phone": "A." }], [{ "id": "a", "when": ["flag"], "phone": "A." }],
		[{ "id": "a", "when": "always", "phone": "" }], [{ "id": "a", "when": "always", "phone": 3 }]]
	for endings: Variant in bad:
		if QuestEngine.data_problem(_ending_quest(endings)) == "":
			return "These endings must be refused: %s" % [endings]
	return ""


## An ending is picked before the quest pays, so the reward is not in its check.
func test_an_ending_is_picked_before_the_quest_pays() -> String:
	var quest: Dictionary = _ending_quest([
		{ "id": "rich", "when": "stat_at_least", "stat": "credits", "at_least": 50, "phone": "Rich." }], "Poor.")
	quest["rewards"]["credits"] = 100
	return _run(func(gs: GameStateScript) -> String:
		gs.credits = 5
		gs.update_quests()
		if gs.credits != 105 or not QuestEngine.is_done(gs, "fork"):
			return "The test needs the quest paid: %d CR" % gs.credits
		return "" if _lines(gs, "LIN: Poor.") == 1 and _lines(gs, "LIN: Rich.") == 0 else "The reward's 100 CR must not pick the ending: %s" % [gs.phone_log],
		[quest])


# --- L2 -------------------------------------------------------------------------

func test_l2_waits_for_lab_level_12_and_follows_the_trip() -> String:
	return _run(_check_l2, [_shipped(L2)])


func _check_l2(gs: GameStateScript) -> String:
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	gs.give_lab_xp(gs.xp_for_level(11) - gs.lab_xp)
	gs.update_quests()
	if gs.lab_level() != 11 or gs.quest_state.has(L2):
		return "L2 is not offered at lab level %d." % gs.lab_level()
	gs.give_lab_xp(gs.xp_for_level(12) - gs.lab_xp)
	gs.update_quests()
	if gs.lab_level() != 12 or not gs.quest_state.has(L2) or QuestEngine.is_done(gs, L2):
		return "L2 is offered at lab level 12: %s" % [gs.quest_state]
	if _lines(gs, "OIRM: New quest, Paperwork From Orbit.") != 1 or _lines(gs, "Open an OIRM account.") != 1:
		return "The offer names the first step: %s" % [gs.phone_log]
	# A founding standard's trip opens no account, so no step moves.
	gs.send_to_oirm("rotary_table")
	gs.update_quests()
	if not (gs.quest_state[L2]["steps_done"] as Array).is_empty():
		return "A founding standard's trip must not do L2's steps: %s" % [gs.quest_state[L2]]
	# Sending a bought standard opens the account and is the trip, in one look.
	gs.buy_standard(FM3)
	gs.send_to_oirm(FM3)
	if not gs.has_oirm_account():
		return "The test could not buy and send the FM-3."
	gs.update_quests()
	if gs.quest_state[L2]["steps_done"] != ["account", "send"] or QuestEngine.is_done(gs, L2):
		return "Sending a bought standard does the first two steps: %s" % [gs.quest_state[L2]]
	if _lines(gs, "Get its certificate back.") != 1:
		return "The phone names the last step: %s" % [gs.phone_log]
	gs.oirm_calibrate(FM3, 10)
	var credits: int = gs.credits
	var lab_xp: int = gs.lab_xp
	gs.update_quests()
	if not QuestEngine.is_done(gs, L2) or gs.credits != credits + 100 or gs.lab_xp != lab_xp + 300:
		return "The certificate back pays 100 CR and 300 lab XP: %d CR, %d XP" % [gs.credits - credits, gs.lab_xp - lab_xp]
	if _lines(gs, "QUEST DONE: Paperwork From Orbit. Reward: 100 CR, 300 lab XP.") != 1 \
			or _lines(gs, _said("OIRM", "npcs/oirm/quests/paperwork_from_orbit_done")) != 1:
		return "Finishing is a phone line and OIRM's line: %s" % [gs.phone_log]
	if not gs.quest_points.is_empty():
		return "A lab quest pays no quest points."
	gs.update_quests()
	return "" if gs.credits == credits + 100 and _lines(gs, "QUEST DONE") == 1 else "L2 is paid once."


## A maker's certificate and the founding stock's are not OIRM's paperwork.
func test_l2_counts_only_oirm_certificates() -> String:
	return _run(_check_l2_certificates, [_shipped(L2)])


func _check_l2_certificates(gs: GameStateScript) -> String:
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	gs.give_lab_xp(gs.xp_for_level(12))
	gs.buy_standard(FM3)
	gs.send_to_oirm(FM3)
	gs.update_quests()
	if gs.quest_state.get(L2, {}).get("steps_done", []) != ["account", "send"]:
		return "The first two steps: %s" % [gs.quest_state]
	for cert: Dictionary in gs.certificate_log:
		if cert.get("issuer", "") == "OIRM" and not cert.get("founding", false):
			return "The test needs a farm with no certificate from an OIRM trip yet: %s" % [cert]
	gs.certificate_log.append({ "id": "FM-0001", "standard_id": FM3, "issuer": "Maker", "founding": false })
	gs.certificate_log.append({ "id": "OIRM-0001", "standard_id": "rotary_table", "issuer": "OIRM", "founding": true })
	gs.update_quests()
	if QuestEngine.is_done(gs, L2):
		return "A maker's certificate and a founding one must not finish L2."
	gs.oirm_calibrate(FM3, 10)
	gs.update_quests()
	return "" if QuestEngine.is_done(gs, L2) else "OIRM's certificate finishes L2."


## A founding standard's earlier trip to OIRM comes back with a certificate that
## is not a founding one. It must not pay L2 while the bought standard is away.
func test_l2_is_not_paid_by_a_founding_standards_earlier_return() -> String:
	return _run(_check_l2_earlier_return, [_shipped(L2)])


func _check_l2_earlier_return(gs: GameStateScript) -> String:
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	gs.give_lab_xp(gs.xp_for_level(12))
	gs.update_quests()
	if not gs.quest_state.has(L2):
		return "The test needs L2 offered."
	if not gs.send_to_oirm("rotary_table").get("ok", false):
		return "The test could not send the rotary table."
	var cert: Dictionary = gs.oirm_calibrate("rotary_table", 3)
	if cert.get("issuer", "") != "OIRM" or cert.get("founding", true):
		return "The test needs the return to be an OIRM certificate that is not founding: %s" % [cert]
	gs.update_quests()
	if not (gs.quest_state[L2]["steps_done"] as Array).is_empty():
		return "A founding standard's trip and return do none of L2's steps: %s" % [gs.quest_state[L2]]
	gs.buy_standard(FM3)
	if not gs.send_to_oirm(FM3).get("ok", false):
		return "The test could not buy and send the FM-3."
	var credits: int = gs.credits
	gs.update_quests()
	if gs.quest_state[L2]["steps_done"] != ["account", "send"] or QuestEngine.is_done(gs, L2) or gs.credits != credits:
		return "L2 must wait while the FM-3 is away: %s" % [gs.quest_state[L2]]
	gs.update_quests()
	if QuestEngine.is_done(gs, L2):
		return "A second look must not pay it either."
	gs.oirm_calibrate(FM3, 10)
	gs.update_quests()
	return "" if QuestEngine.is_done(gs, L2) and gs.credits == credits + 100 else "The FM-3's certificate pays L2: %s" % [gs.quest_state[L2]]


## An account and a certificate from before lab level 12 do the first two steps
## when the quest is offered, and no more: the certificate must come after.
func test_l2_on_a_farm_with_an_account_already_needs_a_new_trip() -> String:
	return _run(_check_l2_old, [_shipped(L2)])


func _check_l2_old(gs: GameStateScript) -> String:
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	gs.buy_standard(FM3)
	gs.send_to_oirm(FM3)
	gs.oirm_calibrate(FM3, 10)
	gs.update_quests()
	if gs.quest_state.has(L2):
		return "Below lab level 12 the quest is not there, whatever was sent."
	gs.give_lab_xp(gs.xp_for_level(12))
	var credits: int = gs.credits
	gs.update_quests()
	if QuestEngine.is_done(gs, L2) or gs.credits != credits or gs.quest_state.get(L2, {}).get("steps_done", []) != ["account", "send"]:
		return "An old account and certificate do two steps and do not pay: %s" % [gs.quest_state]
	if _lines(gs, "Get its certificate back.") != 1:
		return "The phone names the step that is left: %s" % [gs.phone_log]
	if not gs.send_to_oirm(FM3).get("ok", false):
		return "The test could not send the FM-3 again."
	credits = gs.credits
	gs.update_quests()
	if QuestEngine.is_done(gs, L2):
		return "Sending is not the certificate."
	gs.oirm_calibrate(FM3, 20)
	gs.update_quests()
	return "" if QuestEngine.is_done(gs, L2) and gs.credits == credits + 100 else "A new certificate pays L2: %s" % [gs.quest_state]


# --- Saving ---------------------------------------------------------------------

## Every shipped quest, with S2 and L2 part done, through the farm's save.
func test_the_shipped_quests_mid_quest_go_through_a_save() -> String:
	return _run(_check_save_mid_quest)


func _check_save_mid_quest(gs: GameStateScript) -> String:
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	gs.give_lab_xp(gs.xp_for_level(12))
	gs.update_quests()
	gs.buy_standard(FM3)
	gs.send_to_oirm(FM3)
	gs.update_quests()
	for quest: Dictionary in QuestEngine.quests():
		if QuestEngine.data_problem(quest) != "":
			return "A shipped quest has a problem: %s" % quest["id"]
	if not gs.quest_state.has(S2) or QuestEngine.is_done(gs, S2) or QuestEngine.is_done(gs, L2) \
			or gs.quest_state.get(L2, {}).get("steps_done", []) != ["account", "send"]:
		return "The test needs S2 and L2 open: %s" % [gs.quest_state]
	# As the save file holds it (SaveGame.to_bytes).
	var saved: Variant = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var again: GameStateScript = GameStateScript.new()
	again.build_registry()
	var problem: String = again.farm_from_dict(saved) if saved is Dictionary else "The farm is not a dictionary."
	var out: String = ""
	if problem != "":
		out = "The farm did not load: %s" % problem
	elif again.quest_state != gs.quest_state or again.player_quest_state != gs.player_quest_state or again.quest_points != gs.quest_points:
		out = "The quests changed in the save: %s / %s" % [gs.quest_state, again.quest_state]
	else:
		# A look at the loaded farm offers, ticks and pays nothing.
		var lines: int = again.phone_log.size()
		again.update_quests()
		if again.quest_state != gs.quest_state or again.phone_log.size() != lines or again.credits != gs.credits or again.lab_xp != gs.lab_xp:
			out = "A look at the loaded farm changed its quests: %s" % [again.phone_log.slice(lines)]
		else:
			# And the last step is still counted from the send.
			again.oirm_calibrate(FM3, 10)
			again.update_quests()
			if not QuestEngine.is_done(again, L2) or again.credits != gs.credits + 100:
				out = "The loaded farm's L2 is paid by the certificate: %s" % [again.quest_state.get(L2)]
	again.free()
	return out


# --- The mug ring ---------------------------------------------------------------

func test_the_mug_ring_has_its_text_and_its_model() -> String:
	if Inspectable.display_name("mug_ring") != "Mug Ring" or not Inspectable.inspect_text("mug_ring").contains("coffee") \
			or Inspectable.inspect_text("mug_ring").contains("overnight"):
		return "The mug ring's inspect text: %s" % Inspectable.inspect_text("mug_ring")
	return "" if ResourceLoader.exists("res://assets/voxels/mug_ring.glb") else "assets/voxels/mug_ring.glb is missing."


## On the dome's bench, hidden and not clickable until the warning is used.
func test_the_mug_ring_shows_only_after_the_warning() -> String:
	var was: bool = GameState.audit_grace_used
	var dome: Node = (load(DOME) as PackedScene).instantiate()
	var ring: Node3D = dome.get_node_or_null("%MugRing")
	var click: Inspectable = dome.get_node_or_null("%MugRingInspect")
	var problem: String = ""
	if ring == null or click == null:
		problem = "The dome has no mug ring."
	elif ring.visible or click.enabled or click.prop_id != "mug_ring":
		problem = "The mug ring starts hidden and not clickable."
	else:
		dome._mug_ring = ring
		dome._mug_ring_click = click
		for used: bool in [true, false]:
			GameState.audit_grace_used = used
			dome._show_mug_ring()
			if ring.visible != used or click.enabled != used:
				problem = "With the warning %s the ring must be %s." % ["used" if used else "unused", "there" if used else "gone"]
	GameState.audit_grace_used = was
	dome.free()
	return problem
