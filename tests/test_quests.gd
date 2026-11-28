extends RefCounted
## The quest engine (docs/design/quests_levels_story.md section 5, build order
## step 5): offering by a quest's own gates, steps, each plain reward, paying
## once, quest points per player, and the save. The two shipped quests are read
## from data/quests.json; the rest use fixture quests put in DataManager's table
## for one test and taken out after. Every GameState is freed and the clock,
## the session's players and FarmCommands.guest are put back.
##
## gs.update_quests() is the offering look (each morning, and when a farm is
## started or opened). A command's look offers nothing: see
## test_a_command_moves_a_quest_and_offers_none.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const L1: String = "every_sticker_counts"
const L3: String = "first_contract"
const CELL: Vector3i = Vector3i(3, 0, 3)
const NEVER: int = 1000000


## Runs `body` on a new farm. `fixtures` replace the shipped quests if given.
func _run(body: Callable, fixtures: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	if not fixtures.is_empty():
		var mine: Dictionary = {}
		for quest: Dictionary in fixtures:
			mine[StringName(str(quest["id"]))] = quest
		table["quests"] = mine
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	var gs: GameStateScript = _farm()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	gs.free()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


## The shipped quests with these ids, for a test that is about only them.
func _shipped(ids: Array) -> Array:
	var out: Array = []
	for quest: Dictionary in QuestEngine.quests():
		if str(quest["id"]) in ids:
			out.append(quest)
	return out


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	return gs


func _quest(id: String, steps: Array, rewards: Dictionary = {}, gates: Dictionary = {}, more: Dictionary = {}) -> Dictionary:
	var quest: Dictionary = { "id": id, "kind": "story", "giver": "lin", "title": "Test " + id, "scope": "farm",
		"gates": gates, "steps": steps, "rewards": rewards }
	quest.merge(more, true)
	return quest


func _step(id: String, check: String, more: Dictionary = {}) -> Dictionary:
	var step: Dictionary = { "id": id, "text": "Do %s." % id, "check": check }
	step.merge(more, true)
	return step


func _credits_step(at_least: int = 1) -> Dictionary:
	return _step("pay", "stat_at_least", { "stat": "credits", "at_least": at_least })


func _has_line(gs: GameStateScript, part: String) -> bool:
	return _lines(gs, part) > 0


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _is_done(gs: GameStateScript, id: String) -> bool:
	return QuestEngine.is_done(gs, id)


# --- The shipped quests ---------------------------------------------------------

func test_shipped_quests_are_readable() -> String:
	var known: Array[String] = ["stat_at_least", "flag", "band_at_least", "owns_standard", "lab_size", "count", "state_is", "level", "counter", "quest_job", "found_blocks", "plot_untilled", "fissures_open", "beacons_placed", "relay_spool", "master_audit_passed", "silk_stock"]
	var ids: Array[String] = []
	for quest: Dictionary in QuestEngine.quests():
		ids.append(str(quest["id"]))
		if not str(quest["kind"]) in ["story", "lab", "personal", "daily"]:
			return "%s has a kind the design does not have." % quest["id"]
		if str(quest["kind"]) in ["lab", "daily"] and int(quest.get("rewards", {}).get("quest_points", 0)) != 0:
			return "%s: lab and daily quests pay no quest points (section 5.6)." % quest["id"]
		# No steps, a step that is no dictionary, or two steps with one id.
		if QuestEngine.data_problem(quest) != "":
			return "%s: %s" % [quest["id"], QuestEngine.data_problem(quest)]
		var closed: Dictionary = quest.get("closed_when", {})
		if not closed.is_empty() and not str(closed.get("when", "")) in known:
			return "%s has a closed_when this build can't read." % quest["id"]
		for step: Dictionary in quest["steps"]:
			if str(step.get("id", "")) == "" or str(step.get("text", "")) == "" or not str(step.get("check", "")) in known:
				return "%s has a step with no id, no text or a check this build can't read." % quest["id"]
		for line: String in [str(quest.get("rewards", {}).get("phone", "")), str(quest.get("offer_line", ""))]:
			if line.contains("/") and QuestEngine.phone_line(line) == line:
				return "%s's phone line or offer line is a path with no text at it." % quest["id"]
	return "" if L1 in ids and L3 in ids else "L1 and L3 must ship: %s" % [ids]


func test_l1_is_offered_at_once_and_paid_by_a_clean_audit() -> String:
	return _run(_check_l1, _shipped([L1, L3]))


func _check_l1(gs: GameStateScript) -> String:
	gs.update_quests()
	if not gs.quest_state.has(L1) or _is_done(gs, L1) or gs.quest_state.has(L3):
		return "A new farm is offered L1 and not L3: %s" % [gs.quest_state]
	if not _has_line(gs, "VANCE: New quest, Every Sticker Counts. Pass an audit with no findings."):
		return "The offer must be a phone line: %s" % [gs.phone_log]
	gs.update_quests()
	if _lines(gs, "New quest") != 1:
		return "A quest is offered once."
	# A failed audit does nothing; a clean one finishes it.
	gs._update_clean_audit_gate({ "passed": false })
	gs.update_quests()
	if _is_done(gs, L1):
		return "A failed audit must not finish L1."
	gs._update_clean_audit_gate({ "passed": true })
	# A large lab multiplies the feeds, not a quest's lump (section 3.2.1).
	gs.lab_size = gs.lab_sizes().size() - 1
	var before: int = gs.lab_xp
	gs.update_quests()
	if not _is_done(gs, L1) or gs.lab_xp != before + 250:
		return "L1 pays 250 lab XP as written: %d" % (gs.lab_xp - before)
	if not _has_line(gs, "QUEST DONE: Every Sticker Counts. Reward: 250 lab XP.") or not _has_line(gs, "VANCE: One audit with nothing to write down."):
		return "Finishing is a phone line and Vance's line: %s" % [gs.phone_log]
	if gs.quest_state[L1]["players"] != [HOST] or not gs.quest_points.is_empty():
		return "The host took part, and a lab quest pays no points."
	gs._update_clean_audit_gate({ "passed": true })
	before = gs.lab_xp
	gs.update_quests()
	return "" if gs.lab_xp == before and _lines(gs, "QUEST DONE") == 1 else "L1 is paid once."


func test_l3_follows_the_contract() -> String:
	return _run(_check_l3)


func _check_l3(gs: GameStateScript) -> String:
	gs.update_quests()
	gs.contract_state = "active"
	gs.contract_run = 3
	gs.update_quests()
	if not gs.quest_state.has(L3) or _is_done(gs, L3) or not _has_line(gs, "OIRM: New quest, The First Contract."):
		return "L3 is offered when the contract is: %s" % [gs.quest_state]
	var step: Dictionary = DataManager.get_record(&"quests", L3, "quests")["steps"][0]
	var present: Array[String] = [HOST]
	var needed: int = gs.contract_run_needed()
	if QuestEngine.step_progress(gs, step, gs.quest_state[L3], present) != [3, needed]:
		return "L3's step shows the contract's run."
	var lines: int = gs.phone_log.size()
	gs.contract_run = 4
	gs.update_quests()
	if gs.phone_log.size() != lines:
		return "The contract has its own count line; the quest adds none."
	gs.contract_state = "complete"
	var before: int = gs.lab_xp
	gs.update_quests()
	if not _is_done(gs, L3) or gs.lab_xp != before + 400:
		return "L3 pays 400 lab XP when the contract is complete."
	if not _has_line(gs, "QUEST DONE: The First Contract. Reward: 400 lab XP.") or not _has_line(gs, "OIRM: Contract on file."):
		return "Finishing is a phone line and OIRM's line: %s" % [gs.phone_log]
	if QuestEngine.step_progress(gs, step, gs.quest_state[L3], present) != [needed, needed]:
		return "A finished run shows as all of it."
	gs.contract_state = "fulfilled"
	gs.update_quests()
	return "" if gs.lab_xp == before + 400 else "Buying the standard pays nothing more."


## Bought at full price (from Kestrel) before the lab was Trusted: the contract
## is then never offered, so L3 can never be. It is closed with nothing paid.
func test_l3_is_closed_unpaid_when_its_standard_was_bought_first() -> String:
	# L1 and L3 only: S3 is offered at credibility 20, with lines of its own.
	return _run(_check_l3_closed, _shipped([L1, L3]))


func _check_l3_closed(gs: GameStateScript) -> String:
	gs.update_quests()
	var standard: String = gs.contract_standard_id()
	gs.owned_standards[standard] = GameClock.get_day_index()
	gs.change_credibility(40 - gs.credibility)
	if gs.credibility_band() != "Trusted" or gs.contract_state != "":
		return "A Trusted lab that owns the standard is offered no contract: '%s'" % gs.contract_state
	# A command's look closes nothing; the morning's does.
	var none: Array[String] = []
	gs.update_quests(none, false)
	if gs.quest_state.has(L3):
		return "A quest is closed on an offering look."
	var before: int = gs.lab_xp
	var lines: int = gs.phone_log.size()
	gs.update_quests()
	if not _is_done(gs, L3) or gs.lab_xp != before or gs.phone_log.size() != lines:
		return "L3 is done, with nothing paid or said: %s" % [gs.phone_log.slice(lines)]
	gs.update_quests()
	if gs.lab_xp != before or gs.farm_dict_problem(gs.farm_to_dict()) != "":
		return "A closed quest stays closed, and saves."
	# The usual way round is not closed: the contract came first.
	var other: GameStateScript = _farm()
	other.contract_state = "fulfilled"
	other.owned_standards[standard] = 1
	before = other.lab_xp
	other.update_quests()
	var paid: int = other.lab_xp - before
	other.free()
	return "" if paid == 400 else "A contract that was run pays L3, standard owned or not: %d" % paid


## A save from before quests that already did both shows them done, is paid
## once [ASSUMPTION], and is not paid again when it is saved and loaded.
func test_an_old_save_is_done_and_paid_once() -> String:
	return _run(_check_old_save, _shipped([L1, L3]))


func _check_old_save(gs: GameStateScript) -> String:
	gs.tier1_unlocked = true
	gs.contract_state = "fulfilled"
	var old: Dictionary = gs.farm_to_dict()
	old.erase("quest_state")
	old.erase("quest_points")
	var problem: String = gs.farm_from_dict(old)
	if problem != "" or not gs.quest_state.is_empty() or not gs.quest_points.is_empty():
		return "A save with no quests loads with none: %s" % problem
	var before: int = gs.lab_xp
	gs.update_quests()
	if not _is_done(gs, L1) or not _is_done(gs, L3) or gs.lab_xp != before + 650:
		return "Both are done and paid: %d" % (gs.lab_xp - before)
	if _has_line(gs, "New quest"):
		return "A quest that is already done is not offered first."
	var again: GameStateScript = _farm()
	problem = again.farm_from_dict(gs.farm_to_dict())
	again.update_quests()
	var out: String = "" if problem == "" and again.lab_xp == before + 650 and again.quest_state == gs.quest_state \
		and _lines(again, "QUEST DONE") == 2 else "A loaded farm is not paid again: %s" % problem
	again.free()
	return out


# --- Gates and offers -----------------------------------------------------------

func test_a_quest_is_offered_only_when_its_gates_hold() -> String:
	var wait: Array = [_credits_step(NEVER)]
	var quests: Array = [
		# Listed first, opened by the one after it in the same look.
		_quest("after", wait, {}, { "quest_done": "first" }),
		_quest("first", [_credits_step(1)]),
		_quest("lab", wait, {}, { "lab_level": 2 }),
		_quest("band", wait, {}, { "band": "Trusted" }),
		_quest("skill", wait, {}, { "skill": { "id": "calibration", "level": 2 } }),
		_quest("total", wait, {}, { "total_level": 9 }),
		_quest("points", wait, {}, { "quest_points": 1 }),
		_quest("both", wait, {}, { "lab_level": 2, "quest_done": ["first", "never"] }),
		_quest("unknown", wait, {}, { "moon_phase": 3 }),
		_quest("day", wait, {}, {}, { "offer": { "when": "day_at_least", "day": 3 } }),
		_quest("event", wait, {}, {}, { "offer": { "when": "owns_standard", "standard_id": "reference_gauge" } }),
		_quest("own", [_credits_step(1)], {}, {}, { "scope": "player" }),
	]
	return _run(_check_gates, quests)


func _offered(gs: GameStateScript) -> Array:
	var ids: Array = gs.quest_state.keys()
	ids.sort()
	return ids


func _check_gates(gs: GameStateScript) -> String:
	gs.credits = 0
	gs.credibility = 0
	gs.update_quests()
	if _offered(gs) != ["first"]:
		return "Only the quest with no gates is offered yet: %s" % [_offered(gs)]
	gs.credits = 5
	gs.update_quests()
	if _offered(gs) != ["after", "first"] or not _is_done(gs, "first"):
		return "A finished quest opens the one gated on it, in one look: %s" % [_offered(gs)]
	gs.give_lab_xp(gs.xp_for_level(2))
	gs.update_quests()
	if _offered(gs) != ["after", "first", "lab"]:
		return "The lab level gate: %s" % [_offered(gs)]
	gs.credibility = 30
	gs.update_quests()
	if not gs.quest_state.has("band"):
		return "The band gate: %s" % [_offered(gs)]
	# The best of those on the farm counts: a guest's level opens it for the farm.
	gs.give_skill_xp("calibration", gs.xp_for_level(2), GUEST)
	gs.update_quests()
	if gs.quest_state.has("skill") or gs.quest_state.has("total"):
		return "A player who is away opens nothing."
	var both: Array[String] = [HOST, GUEST]
	gs.update_quests(both)
	if not gs.quest_state.has("skill") or gs.quest_state.has("total"):
		return "The skill gate reads the best player present: %s" % [_offered(gs)]
	if QuestEngine.total_level(gs, GUEST) != gs.skill_ids().size() + 1:
		return "Total level is the levels added up."
	gs.give_skill_xp("agronomy", gs.xp_for_level(3), GUEST)
	gs.update_quests(both)
	if not gs.quest_state.has("total") or gs.quest_state.has("points"):
		return "The total level gate: %s" % [_offered(gs)]
	gs.quest_points[GUEST] = { "somewhere": 1 }
	gs.update_quests(both)
	if not gs.quest_state.has("points"):
		return "The quest points gate reads the best player present."
	# Day 2, then day 3.
	GameClock.elapsed_days = 1.0
	gs.update_quests(both)
	if gs.quest_state.has("day") or gs.quest_state.has("event"):
		return "An offer waits for its day or its event."
	GameClock.elapsed_days = 2.0
	gs.owned_standards["reference_gauge"] = true
	gs.update_quests(both)
	if not gs.quest_state.has("day") or not gs.quest_state.has("event") or int(gs.quest_state["day"]["accepted"]) != 3:
		return "An offer by day and by event: %s" % [_offered(gs)]
	for never: String in ["both", "unknown", "own"]:
		if gs.quest_state.has(never):
			return "'%s' must stay shut: every gate must hold, an unknown gate is shut, and a player's own quest waits." % never
	return ""


# --- Steps and checks -----------------------------------------------------------

func test_each_check_reads_the_farm() -> String:
	return _run(_check_checks)


func _value(gs: GameStateScript, check: String, more: Dictionary) -> int:
	var present: Array[String] = [HOST]
	return QuestEngine.check_value(gs, _step("s", check, more), present)


func _check_checks(gs: GameStateScript) -> String:
	gs.credits = 42
	gs.stone = 7
	if _value(gs, "stat_at_least", { "stat": "credits" }) != 42 or _value(gs, "stat_at_least", { "stat": "stone" }) != 7 \
			or _value(gs, "stat_at_least", { "stat": "rng" }) != 0:
		return "stat_at_least reads the listed stats only."
	if _value(gs, "flag", { "flag": "traceable_lab" }) != 0 or _value(gs, "flag", { "flag": "oirm_account" }) != 0:
		return "flag reads false."
	gs.traceable_lab = true
	if _value(gs, "flag", { "flag": "traceable_lab" }) != 1 or _value(gs, "flag", { "flag": "credits" }) != 0:
		return "flag reads the listed flags only."
	gs.credibility = 0
	if _value(gs, "band_at_least", { "band": "Trusted" }) != 0 or _value(gs, "band_at_least", { "band": "No such band" }) != 0:
		return "band_at_least is not met at Provisional."
	gs.credibility = 60
	if _value(gs, "band_at_least", { "band": "Trusted" }) != 1:
		return "band_at_least is met at a higher band."
	if _value(gs, "owns_standard", { "standard_id": "reference_gauge" }) != 0:
		return "owns_standard reads none."
	gs.owned_standards["reference_gauge"] = true
	gs.lab_size = 1
	if _value(gs, "owns_standard", { "standard_id": "reference_gauge" }) != 1 or _value(gs, "lab_size", {}) != 1:
		return "owns_standard and lab_size."
	var cals: int = gs.cal_log.size()
	var audits: int = gs.audit_log.size()
	gs.cal_log.append({ "instrument_id": "quest_probe", "traceable": true, "day": 902 })
	gs.cal_log.append({ "instrument_id": "quest_probe", "traceable": false, "day": 902 })
	gs.cal_log.append({ "instrument_id": "quest_other", "traceable": true, "day": 903 })
	gs.audit_log.append({ "passed": true, "clean": true, "quest": "yes" })
	if _value(gs, "count", { "log": "cal_log", "where": { "instrument_id": "quest_probe", "traceable": true } }) != 1 \
			or _value(gs, "count", { "log": "cal_log", "where": { "day": 902.0 } }) != 2 \
			or _value(gs, "count", { "log": "cal_log", "where": {} }) != cals + 3 \
			or _value(gs, "count", { "log": "audit_log", "where": { "quest": "yes" } }) != 1 \
			or _value(gs, "count", { "log": "audit_log", "where": {} }) != audits + 1 \
			or _value(gs, "count", { "log": "certificates", "where": {} }) != gs.certificate_log.size() \
			or _value(gs, "count", { "log": "phone_log", "where": {} }) != 0:
		return "count reads the rows of a listed log that match."
	gs.contract_state = "active"
	if _value(gs, "state_is", { "state": "contract_state", "is": "active" }) != 1 \
			or _value(gs, "state_is", { "state": "contract_state", "is": ["complete", "fulfilled"] }) != 0 \
			or _value(gs, "state_is", { "state": "credits", "is": "42" }) != 0:
		return "state_is reads the contract's state."
	gs.give_skill_xp("agronomy", gs.xp_for_level(4), HOST)
	gs.give_lab_xp(gs.xp_for_level(3))
	if _value(gs, "level", { "skill": "agronomy" }) != 4 or _value(gs, "level", { "skill": "lab" }) != 3 \
			or _value(gs, "level", { "skill": "total" }) != gs.skill_ids().size() + 3:
		return "level reads a skill, the lab and the total."
	if not gs.till(CELL, HOST) or not gs.till(CELL + Vector3i(1, 0, 0), GUEST):
		return "The test's cells must till."
	if _value(gs, "counter", { "counter": "till" }) != 2 or _value(gs, "counter", { "counter": "nothing" }) != 0:
		return "counter adds up every player's count for a farm's quest."
	return "" if _value(gs, "minigame", { "minigame": "set_the_zero" }) == 0 else "A check not built yet waits."


func test_steps_go_in_order_and_count_from_acceptance() -> String:
	var steps: Array = [
		_step("till", "counter", { "counter": "till", "at_least": 2 }),
		_step("ever", "counter", { "counter": "till", "at_least": 3, "ever": true }),
		_credits_step(500),
	]
	var any: Array = [_credits_step(500), _step("gauge", "owns_standard", { "standard_id": "reference_gauge" })]
	return _run(_check_steps, [_quest("ordered", steps), _quest("loose", any, {}, {}, { "any_order": true })])


func _check_steps(gs: GameStateScript) -> String:
	gs.credits = 0
	# Tilled before the quest was accepted: counts only for the `ever` step.
	gs.till(CELL, HOST)
	gs.update_quests()
	var entry: Dictionary = gs.quest_state.get("ordered", {})
	if entry.get("base") != { "till": 1, "ever": 1 } or not _has_line(gs, "LIN: New quest, Test ordered. Do till."):
		return "Accepting keeps what the counting checks read: %s" % [entry]
	gs.credits = 500
	gs.update_quests()
	if not (entry["steps_done"] as Array).is_empty():
		return "A later step waits for the ones before it."
	if gs.quest_state["loose"]["steps_done"] != ["pay"]:
		return "With any_order a later step can be done first."
	gs.owned_standards["reference_gauge"] = true
	gs.till(CELL + Vector3i(1, 0, 0), HOST)
	gs.update_quests()
	if not _is_done(gs, "loose") or not (entry["steps_done"] as Array).is_empty() or _lines(gs, "QUEST Test ordered: 1 of 2. Do till.") != 1:
		return "A count that grew is one phone line: %s" % [gs.phone_log]
	gs.update_quests()
	if _lines(gs, "1 of 2") != 1:
		return "The same count is not said twice."
	gs.till(CELL + Vector3i(2, 0, 0), HOST)
	gs.update_quests()
	# Two tilled since acceptance, three ever, and the credits: all three fall.
	if not _is_done(gs, "ordered") or entry["steps_done"] != ["till", "ever", "pay"] or int(entry["done"]) != GameClock.get_day_index():
		return "The steps fall in order once each holds: %s" % [entry]
	return ""


func test_a_step_done_names_the_next() -> String:
	return _run(_check_next, [_quest("two", [_credits_step(10), _step("gauge", "owns_standard", { "standard_id": "reference_gauge" })])])


func _check_next(gs: GameStateScript) -> String:
	gs.credits = 0
	gs.update_quests()
	gs.credits = 10
	gs.update_quests()
	return "" if _has_line(gs, "QUEST Test two: step done. Next: Do gauge.") and not _is_done(gs, "two") else "A step done names the next: %s" % [gs.phone_log]


## Wrong data is left alone, not run.
func test_a_quest_with_bad_steps_is_left_alone() -> String:
	var twice: Array = [_credits_step(1), _credits_step(2)]
	var quests: Array = [
		_quest("empty", []),
		_quest("no_list", [], {}, {}, { "steps": "pay" }),
		_quest("no_step", [_credits_step(1), "pay"]),
		_quest("twice", twice),
		_quest("no_id", [_step("", "flag", { "flag": "tier1_unlocked" })]),
		_quest("bad_gates", [_credits_step(1)], {}, {}, { "gates": [] }),
		_quest("good", [_credits_step(1)]),
	]
	return _run(_check_bad_data, quests)


func _check_bad_data(gs: GameStateScript) -> String:
	for quest: Dictionary in QuestEngine.quests():
		if (QuestEngine.data_problem(quest) == "") != (str(quest["id"]) == "good"):
			return "'%s' is read wrongly: '%s'" % [quest["id"], QuestEngine.data_problem(quest)]
	gs.credits = 5
	gs.update_quests()
	return "" if gs.quest_state.keys() == ["good"] and _is_done(gs, "good") else "Only the good quest runs: %s" % [gs.quest_state]


# --- The real entry points --------------------------------------------------------

## FarmCommands.execute is what a host's own command runs. Its look moves and
## pays a quest that is already on, and offers nothing: the offer waits for the
## morning, so it never lands on what the command said.
func test_a_command_moves_a_quest_and_offers_none() -> String:
	var tilling: Dictionary = _quest("tilling", [_step("till", "counter", { "counter": "till" })], { "credits": 5 })
	var later: Dictionary = _quest("later", [_credits_step(NEVER)], {}, { "quest_done": "tilling" })
	return _run(_check_command, [tilling, later])


func _check_command(gs: GameStateScript) -> String:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var problem: String = _command_problem(gs, commands)
	commands.free()
	return problem


func _command_problem(gs: GameStateScript, commands: Node) -> String:
	gs.credits = 0
	if commands.execute(HOST, &"till", [CELL]) != true:
		return "The host's tilling must be taken."
	if not gs.quest_state.is_empty() or _has_line(gs, "New quest"):
		return "A command offers no quest: %s" % [gs.phone_log]
	# The morning offers it. What was tilled before does not count.
	gs._on_day_started(2)
	if _offered(gs) != ["tilling"] or _lines(gs, "LIN: New quest, Test tilling. Do till.") != 1:
		return "The morning offers the quest: %s" % [gs.phone_log]
	if commands.execute(HOST, &"till", [CELL + Vector3i(1, 0, 0)]) != true:
		return "The second cell must till."
	if not _is_done(gs, "tilling") or gs.credits != 5 or not _has_line(gs, "QUEST DONE: Test tilling. Reward: 5 CR."):
		return "The host's command finishes and pays the quest: %s" % [gs.phone_log]
	if gs.quest_state.has("later"):
		return "The quest it opens waits for the morning."
	gs._on_day_started(3)
	return "" if gs.quest_state.has("later") else "The next morning offers the quest it opened."


## The morning (_on_day_started) offers L1 and, after a clean audit, pays it.
func test_the_morning_offers_and_pays_l1() -> String:
	return _run(_check_morning)


func _check_morning(gs: GameStateScript) -> String:
	# A morning with no audit (the cadence's day is not 2 or 3).
	gs._on_day_started(2)
	if not gs.quest_state.has(L1) or _is_done(gs, L1) or _lines(gs, "VANCE: New quest, Every Sticker Counts.") != 1:
		return "The morning offers L1: %s" % [gs.phone_log]
	gs._update_clean_audit_gate({ "passed": true })
	var before: int = gs.lab_xp
	gs._on_day_started(3)
	if not _is_done(gs, L1) or gs.lab_xp != before + 250 or _lines(gs, "QUEST DONE: Every Sticker Counts.") != 1:
		return "The morning after a clean audit pays L1: %d" % (gs.lab_xp - before)
	gs._on_day_started(4)
	return "" if gs.lab_xp == before + 250 and _lines(gs, "New quest, Every Sticker Counts") == 1 else "L1 is offered and paid once."


# --- Rewards --------------------------------------------------------------------

func test_each_reward_is_paid_once() -> String:
	var rewards: Dictionary = { "credits": 1500, "lab_xp": 60, "xp_calibration": 30, "xp_certificate": 200, "xp_nothing": 5,
		"quest_points": 1, "phone": "Good work." }
	return _run(_check_rewards, [_quest("paid", [_credits_step(100)], rewards)])


func _check_rewards(gs: GameStateScript) -> String:
	gs.credits = 0
	gs.lab_size = gs.lab_sizes().size() - 1
	gs.update_quests()
	var lab: int = gs.lab_xp
	var skill: int = gs.skill_xp("calibration", HOST)
	gs.credits = 100
	gs.update_quests()
	if not _is_done(gs, "paid") or gs.credits != 1600 or gs.lab_xp != lab + 60 or gs.skill_xp("calibration", HOST) != skill + 30:
		return "Credits, lab XP and skill XP are paid as written: %d CR, %d lab XP, %d XP" % [gs.credits, gs.lab_xp, gs.skill_xp("calibration", HOST)]
	if gs.quest_point_total() != 1 or gs.quest_points != { HOST: { "paid": 1 } }:
		return "The quest point is the player's: %s" % [gs.quest_points]
	if gs.action_counts.has(HOST):
		return "A quest's lump is not counted as an action."
	var said: String = "QUEST DONE: Test paid. Reward: %s CR, 60 lab XP, 30 Calibration XP, 1 quest point, an XP certificate (200 XP)." % SP811.integer(1500)
	if not _has_line(gs, said) or not _has_line(gs, "LIN: Good work."):
		return "The reward is said on the phone: %s" % [gs.phone_log]
	# A second look, more credits, and a save and load: nothing more.
	gs.credits = 5000
	gs.update_quests()
	var again: GameStateScript = _farm()
	var problem: String = again.farm_from_dict(gs.farm_to_dict())
	again.update_quests()
	var out: String = ""
	if problem != "" or again.credits != 5000 or again.lab_xp != lab + 60 or again.skill_xp("calibration", HOST) != skill + 30 \
			or again.quest_point_total(HOST) != 1 or _lines(again, "QUEST DONE") != 1:
		out = "A finished quest is never paid again: %s" % problem
	again.free()
	return out


## A skill the whole farm shares is paid once, however many took part. No
## shipped skill is the farm's, so one is put in the table for this test.
func test_a_farm_skill_reward_is_paid_once() -> String:
	var skills: Dictionary = DataManager._records[&"skills"]["skills"]
	skills[&"shared"] = { "id": "shared", "display_name": "Shared", "scope": "farm" }
	var out: String = _run(_check_farm_skill, [_quest("farm_paid", [_credits_step(10)], { "xp_shared": 40, "xp_agronomy": 20 })])
	skills.erase(&"shared")
	return out


func _check_farm_skill(gs: GameStateScript) -> String:
	if not gs.is_farm_skill("shared") or gs.is_farm_skill("agronomy"):
		return "The test needs one farm skill and one personal skill."
	gs.credits = 0
	var both: Array[String] = [HOST, GUEST]
	gs.update_quests(both)
	gs.credits = 10
	gs.update_quests(both)
	if not _is_done(gs, "farm_paid") or gs.quest_state["farm_paid"]["players"] != [HOST, GUEST]:
		return "Both took part: %s" % [gs.quest_state]
	if gs.skill_xp("shared") != 40 or gs.farm_skill_xp.get("shared") != 40:
		return "A farm skill is paid once for the quest: %d" % gs.skill_xp("shared")
	return "" if gs.skill_xp("agronomy", HOST) == 20 and gs.skill_xp("agronomy", GUEST) == 20 else "A personal skill is paid to each."


# --- Co-op ----------------------------------------------------------------------

func test_everyone_who_took_part_gets_the_point_once() -> String:
	var story: Dictionary = _quest("story", [_step("till", "counter", { "counter": "till" }), _credits_step(NEVER)],
		{ "quest_points": 1, "xp_agronomy": 40 })
	var alone: Dictionary = _quest("alone", [_credits_step(NEVER)], { "quest_points": 2 }, { "quest_done": "story" })
	return _run(_check_coop, [story, alone])


func _check_coop(gs: GameStateScript) -> String:
	gs.credits = 0
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var problem: String = _coop_problem(gs, commands)
	commands.free()
	return problem


func _coop_problem(gs: GameStateScript, commands: Node) -> String:
	var third: String = "player_3"
	CoopSession.players.assign([HOST, GUEST])
	gs.update_quests()
	# The host runs the guest's command, and the quests look again after it.
	if commands.execute(GUEST, &"till", [CELL]) != true:
		return "The guest's tilling must be taken."
	var entry: Dictionary = gs.quest_state["story"]
	if entry["steps_done"] != ["till"] or entry["players"] != [HOST, GUEST]:
		return "A guest's command moves the farm's quest, and both were there: %s" % [entry]
	# The guest leaves and another comes for the last step.
	CoopSession.players.assign([HOST, third])
	var before: int = gs.skill_xp("agronomy", GUEST)
	gs.credits = NEVER
	gs.update_quests()
	if not _is_done(gs, "story") or not _is_done(gs, "alone"):
		return "Both quests are done."
	if gs.quest_point_total(HOST) != 3 or gs.quest_point_total(GUEST) != 1 or gs.quest_point_total(third) != 3:
		return "Each who was there for a step gets that quest's points once: %s" % [gs.quest_points]
	if gs.skill_xp("agronomy", GUEST) != before + 40 or gs.skill_xp("agronomy", third) != 40:
		return "Skill XP goes to each player who took part."
	gs.update_quests()
	if gs.quest_points[HOST] != { "story": 1, "alone": 2 }:
		return "Points are kept by quest, so none is held twice: %s" % [gs.quest_points]
	# A guest's copy is the host's: it shows the points and never runs the quests.
	var copy: GameStateScript = _farm()
	FarmCommands.guest = true
	var problem: String = copy.farm_from_dict(gs.farm_to_dict())
	copy.local_player_id = GUEST
	var paid: int = copy.quest_point_total()
	copy.quest_state.clear()
	copy.update_quests()
	var ran: bool = not copy.quest_state.is_empty()
	FarmCommands.guest = false
	copy.free()
	if problem != "" or paid != 1 or ran:
		return "A guest sees their points and runs no quests: %s" % problem
	# A guest the farm forgets loses their points with their skills, until step 8.
	gs.guest_ids["hash"] = GUEST
	var here: Array[String] = [HOST]
	gs._forget_a_guest(here)
	return "" if not gs.quest_points.has(GUEST) and gs.quest_points.has(third) else "A forgotten guest's points go."


## A forgotten guest leaves the quests: no place on them, no points when one is
## finished later, and the count they helped reach does not go back.
func test_a_forgotten_guest_leaves_the_quests() -> String:
	var steps: Array = [_step("till", "counter", { "counter": "till", "at_least": 4 })]
	return _run(_check_forgotten, [_quest("count", steps, { "quest_points": 1, "xp_agronomy": 10 })])


func _check_forgotten(gs: GameStateScript) -> String:
	var both: Array[String] = [HOST, GUEST]
	var here: Array[String] = [HOST]
	var step: Dictionary = QuestEngine.quests()[0]["steps"][0]
	gs.guest_ids["hash"] = GUEST
	gs.update_quests(both)
	gs.till(CELL, HOST)
	gs.till(CELL + Vector3i(1, 0, 0), GUEST)
	gs.till(CELL + Vector3i(2, 0, 0), GUEST)
	gs.update_quests(both)
	var entry: Dictionary = gs.quest_state["count"]
	if entry["shown"] != { "till": 3 } or not _has_line(gs, "QUEST Test count: 3 of 4."):
		return "Three are tilled between them: %s" % [entry]
	# As an older save may have it: someone this farm no longer knows.
	(entry["players"] as Array).assign([HOST, GUEST, "player_9"])
	gs._forget_a_guest(here)
	if gs.action_counts.has(GUEST) or entry["players"] != [HOST, "player_9"]:
		return "A forgotten guest is taken off the quests: %s" % [entry["players"]]
	gs.update_quests(here)
	if QuestEngine.step_progress(gs, step, entry, here) != [3, 4] or _lines(gs, "of 4") != 1:
		return "A count does not go back when a guest's actions leave: %s" % [QuestEngine.step_progress(gs, step, entry, here)]
	gs.till(CELL + Vector3i(0, 0, 1), HOST)
	gs.update_quests(here)
	if _is_done(gs, "count") or entry["shown"] != { "till": 3 }:
		return "The host's two do not pass the three already reached."
	gs.till(CELL + Vector3i(1, 0, 1), HOST)
	gs.till(CELL + Vector3i(2, 0, 1), HOST)
	gs.update_quests(here)
	if not _is_done(gs, "count"):
		return "Four of the host's own finish it: %s" % [gs.action_counts]
	if gs.quest_points != { HOST: { "count": 1 } } or gs.player_skill_xp.has("player_9") or gs.player_skill_xp.has(GUEST):
		return "Only a player the farm knows is paid: %s" % [gs.quest_points]
	return ""


# --- The save -------------------------------------------------------------------

func test_quests_are_saved_and_checked() -> String:
	return _run(_check_save, [_quest("kept", [_step("till", "counter", { "counter": "till", "at_least": 3 })], { "quest_points": 1 })])


func _check_save(gs: GameStateScript) -> String:
	gs.till(CELL, HOST)
	gs.update_quests()
	gs.till(CELL + Vector3i(1, 0, 0), HOST)
	gs.update_quests()
	if gs.quest_state["kept"]["base"] != { "till": 1 } or gs.quest_state["kept"]["shown"] != { "till": 1 }:
		return "The quest must be part done before it is saved: %s" % [gs.quest_state]
	gs.quest_points[GUEST] = { "kept": 1 }
	# A quest this build's data does not have is kept as it is.
	gs.quest_state["gone"] = { "accepted": 1, "steps_done": ["a"], "base": {}, "shown": {}, "players": [HOST], "done": 2 }
	var good: Dictionary = gs.farm_to_dict()
	# As a save file and a guest's copy carry it.
	var read: Variant = bytes_to_var(var_to_bytes(good))
	if not read is Dictionary or read["quest_state"] != gs.quest_state or read["quest_points"] != gs.quest_points:
		return "Quests go to the save's bytes and back exactly."
	var loaded: GameStateScript = _farm()
	var problem: String = loaded.farm_from_dict(read)
	var same: bool = loaded.quest_state == gs.quest_state and loaded.quest_points == gs.quest_points
	loaded.update_quests()
	same = same and loaded.quest_state == gs.quest_state and loaded.quest_state.has("gone")
	loaded.free()
	if problem != "" or not same:
		return "A loaded farm has the same quests: %s" % problem
	for bad: Variant in _bad_states():
		var data: Dictionary = good.duplicate(true)
		data["quest_state"] = bad
		if gs.farm_dict_problem(data) == "":
			return "A bad quest_state must be refused: %s" % [bad]
	for bad: Variant in [[], { "": {} }, { 3: {} }, { HOST: [] }, { HOST: { "kept": "1" } }, { HOST: { "kept": -1 } }, { HOST: { "kept": 1.5 } }, { HOST: { 2: 1 } }]:
		var data: Dictionary = good.duplicate(true)
		data["quest_points"] = bad
		if gs.farm_dict_problem(data) == "":
			return "Bad quest_points must be refused: %s" % [bad]
	return "" if gs.farm_dict_problem(good) == "" else "The good farm must pass."


func _bad_states() -> Array:
	var good: Dictionary = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }
	var out: Array = [[], { "": good }, { 5: good }, { "q": [] }, { "q": {} }]
	for change: Array in [["accepted", -1], ["accepted", 1.0], ["done", -2], ["done", "no"], ["steps_done", {}], ["steps_done", [1]],
			["steps_done", ["a", "a"]], ["players", [""]], ["players", "player_1"], ["base", []], ["base", { "a": -1 }],
			["base", { "a": 1.5 }], ["shown", { 1: 1 }], ["shown", { "a": NAN }]]:
		var entry: Dictionary = good.duplicate(true)
		entry[change[0]] = change[1]
		out.append({ "q": entry })
	var short: Dictionary = good.duplicate(true)
	short.erase("shown")
	out.append({ "q": short })
	var long: Dictionary = good.duplicate(true)
	long["extra"] = 1
	out.append({ "q": long })
	return out
