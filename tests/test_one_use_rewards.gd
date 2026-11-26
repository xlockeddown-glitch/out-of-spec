extends RefCounted
## One-use rewards and keepsakes (docs/design/quests_levels_story.md section 9,
## item 10): Bram's discount and the free lab refit are held, used by the action
## they are for on their own, exactly once, on the host; a quest reward grants
## them from data; they are saved and checked; the keepsake shelf reads what is
## held. Fixture quests are put in DataManager's table for one test and taken
## out after; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const FM3: String = "field_meter_dc"
const HM3: String = "multi_source_calibrator"
const GAUGE: String = "reference_gauge"
const OWN_Q: String = "own_q"
const FARM_Q: String = "farm_q"
const RICH: int = 50000


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _quest(id: String, scope: String, rewards: Dictionary, at_least: int = RICH) -> Dictionary:
	return { "id": id, "kind": "story", "giver": "lin", "title": "Test " + id, "scope": scope, "gates": {},
		"steps": [{ "id": "pay", "text": "Do pay.", "check": "stat_at_least", "stat": "credits", "at_least": at_least }], "rewards": rewards }


## Runs `body` with fixture quests in place of the shipped ones.
func _with_quests(fixtures: Array, body: Callable) -> String:
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	var mine: Dictionary = {}
	for quest: Dictionary in fixtures:
		mine[StringName(str(quest["id"]))] = quest
	table["quests"] = mine
	var out: Variant = body.call()
	table["quests"] = shipped
	return out if out is String else "The test stopped early or did not return a String."


# --- Bram's discount ---------------------------------------------------------------

func test_the_discount_is_used_once_by_the_next_standard_bought() -> String:
	var gs: GameStateScript = _state()
	var full: int = gs.standard_price_credits(FM3)
	var problem: String = ""
	if not gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST) or gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != 1:
		problem = "The discount must be held once given."
	var off: int = full * 90 / 100
	if problem == "" and (gs.standard_price_credits(FM3, HOST) != off or not gs.standard_price_text(FM3, HOST).contains("10 % off")):
		problem = "While held, the catalog shows the discounted price: %d, '%s'" % [gs.standard_price_credits(FM3, HOST), gs.standard_price_text(FM3, HOST)]
	if problem == "" and gs.standard_price_credits(FM3, GUEST) != full:
		problem = "Another player, who holds none, sees the full price."
	if problem == "" and gs.buy_standard(FM3, HOST) != "":
		problem = "The purchase must go through: %s" % gs.standard_purchase_problem(FM3, HOST)
	if problem == "" and (gs.credits != 100000 - off or gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != 0 or gs.one_use_held.has(HOST)):
		problem = "It charges the discounted price and the discount is spent: %d, %s" % [gs.credits, gs.one_use_held]
	if problem == "" and _lines(gs, "That one is spent") != 1:
		problem = "The phone says the discount was used, once."
	_done(gs)
	return problem


func test_the_next_standard_after_it_costs_full() -> String:
	var gs: GameStateScript = _state()
	gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	gs.buy_standard(FM3, HOST)
	var after: int = gs.credits
	var price: int = gs.get_sensor(GAUGE).price_credits
	var problem: String = ""
	if gs.standard_discount_pct(GAUGE, HOST) != 0:
		problem = "The discount is gone."
	if problem == "" and gs.buy_standard(GAUGE, HOST) != "":
		problem = "Setup: the second standard must be bought: %s" % gs.standard_purchase_problem(GAUGE, HOST)
	if problem == "" and gs.credits != after - price:
		problem = "The second standard is at the full price, not discounted again: %d" % (after - gs.credits)
	_done(gs)
	return problem


func test_a_standard_that_is_not_brams_does_not_use_it() -> String:
	var gs: GameStateScript = _state()
	gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	var problem: String = ""
	if gs.standard_discount_pct(HM3, HOST) != 0 or gs.standard_price_credits(HM3, HOST) != gs.standard_price_credits(HM3):
		problem = "Kestrel's stock takes no discount."
	if problem == "" and gs.standard_purchase_problem(HM3, HOST) != "Bram doesn't stock that.":
		problem = "Setup: the Multi-Source Calibrator is not Bram's stock."
	if problem == "" and gs.standard_discount_pct(FM3, HOST) != 10:
		problem = "Bram's own stock does take it."
	_done(gs)
	return problem


func test_a_refused_purchase_keeps_the_discount() -> String:
	var gs: GameStateScript = _state()
	gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	gs.credits = 0
	var problem: String = ""
	if gs.buy_standard(FM3, HOST) == "" or gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != 1:
		problem = "A purchase that cannot be paid keeps the discount."
	_done(gs)
	return problem


func test_the_discount_does_not_open_a_gate() -> String:
	var gs: GameStateScript = _state()
	gs.lab_gates_kept = []
	gs.lab_xp = 0
	gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	var reason: String = gs.tier_problem(FM3)
	var problem: String = ""
	if reason == "":
		problem = "The test needs a lab short of the Tier 1 level."
	if problem == "" and (gs.buy_standard(FM3, HOST) != reason or gs.owned_standards.has(FM3) or gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != 1):
		problem = "A discount does not open a gate and is not spent by a refusal."
	_done(gs)
	return problem


func test_the_discount_is_a_players_own() -> String:
	var gs: GameStateScript = _state()
	gs.give_one_use(gs.ONE_USE_DISCOUNT, GUEST)
	var problem: String = ""
	if gs.standard_discount_pct(FM3, HOST) != 0 or gs.standard_discount_pct(FM3, GUEST) != 10:
		problem = "Only the player who holds it gets it."
	if problem == "" and gs.buy_standard(FM3, HOST) != "":
		problem = "Setup: the host buys."
	if problem == "" and gs.one_use_count(gs.ONE_USE_DISCOUNT, GUEST) != 1:
		problem = "The host's purchase does not spend the guest's discount."
	_done(gs)
	return problem


# --- The free refit ----------------------------------------------------------------

func test_the_free_refit_is_used_once_by_clearing_a_lab_area() -> String:
	var gs: GameStateScript = _state()
	var discipline: String = str(gs.job_disciplines().keys()[0])
	var problem: String = ""
	var full: Vector2i = gs._lab_refit_cost()
	if full == Vector2i.ZERO:
		problem = "The test needs a refit that costs something."
	if problem == "" and (not gs.give_one_use(gs.ONE_USE_REFIT, gs.FARM_HOLDER) or gs.one_use_count(gs.ONE_USE_REFIT) != 1):
		problem = "The refit must be held by the farm."
	if problem == "" and (gs._lab_refit_cost() != Vector2i.ZERO or not gs.lab_refit_text().contains("free")):
		problem = "While held, the refit costs nothing and says so: '%s'" % gs.lab_refit_text()
	var credits: int = gs.credits
	var ore: int = gs.crystal_ore
	if problem == "" and gs.clear_lab_area(discipline) != "":
		problem = "The area must be cleared: %s" % gs.lab_clear_problem(discipline)
	if problem == "" and (gs.credits != credits or gs.crystal_ore != ore or gs.one_use_count(gs.ONE_USE_REFIT) != 0 or gs.one_use_held.has(gs.FARM_HOLDER)):
		problem = "It cost nothing and is spent: %d, %d, %s" % [gs.credits, gs.crystal_ore, gs.one_use_held]
	if problem == "" and _lines(gs, "The refit was free") != 1:
		problem = "The phone says the refit was free, once."
	if problem == "":
		gs._finish_lab_build(int(gs.lab_build["done_day"]))
		if gs.fit_lab_area(discipline) != "" or gs._lab_refit_cost() != full:
			problem = "Setup: the area is fitted again and the next refit costs money."
	if problem == "":
		credits = gs.credits
		if gs.clear_lab_area(discipline) != "" or gs.credits != credits - full.x:
			problem = "The next refit is paid for: %d" % (credits - gs.credits)
	_done(gs)
	return problem


func test_a_reward_goes_to_its_own_kind_of_holder() -> String:
	var gs: GameStateScript = _state()
	var problem: String = ""
	if gs.give_one_use(gs.ONE_USE_REFIT, HOST) or gs.give_one_use(gs.ONE_USE_DISCOUNT, gs.FARM_HOLDER):
		problem = "A reward of a player is not the farm's, nor the other way."
	if problem == "" and (gs.give_one_use("not_a_reward", HOST) or gs.give_one_use(gs.ONE_USE_DISCOUNT, "")):
		problem = "A reward the data lacks, or a holder with no name, gives nothing."
	for i: int in gs.MOST_ONE_USE:
		gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	if problem == "" and (gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST) or gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != gs.MOST_ONE_USE):
		problem = "A holder keeps no more than the most."
	_done(gs)
	return problem


# --- From quest reward data ----------------------------------------------------------

func test_a_quest_reward_grants_them() -> String:
	var own: Dictionary = _quest(OWN_Q, "player", { "one_use": "bram_discount_10" })
	return _with_quests([own, _quest(FARM_Q, "farm", { "one_use": "free_lab_refit" })], func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = RICH
		for quest: Dictionary in QuestEngine.quests():
			var why: String = QuestEngine.data_problem(quest)
			if why != "":
				_done(gs)
				return "The fixture is good data: %s" % why
		gs.update_quests([HOST] as Array[String])
		var problem: String = ""
		if gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != 1 or gs.one_use_count(gs.ONE_USE_REFIT) != 1:
			problem = "Both are held once paid: %s" % gs.one_use_held
		if problem == "" and (_lines(gs, "Ten percent off") != 1 or _lines(gs, "costs nothing") != 1):
			problem = "The phone says each was given."
		gs.update_quests([HOST] as Array[String])
		if problem == "" and (gs.one_use_count(gs.ONE_USE_DISCOUNT, HOST) != 1 or gs.one_use_count(gs.ONE_USE_REFIT) != 1):
			problem = "A quest done pays once."
		if problem == "" and not QuestEngine.reward_text(own).contains("discount"):
			problem = "The reward is named where rewards are listed."
		_done(gs)
		return problem)


func test_data_rejects_a_bad_one_use_reward() -> String:
	var good: Dictionary = _quest(OWN_Q, "player", { "one_use": "bram_discount_10" })
	if QuestEngine.data_problem(good) != "":
		return "A good one-use reward is accepted: %s" % QuestEngine.data_problem(good)
	var bad: Array = [
		_quest(OWN_Q, "player", { "one_use": "nope" }),
		_quest(OWN_Q, "player", { "one_use": 3 }),
		_quest(OWN_Q, "farm", { "one_use": "bram_discount_10" }),
		_quest(FARM_Q, "player", { "one_use": "free_lab_refit" }),
		_quest(OWN_Q, "player", { "one_use": "" }),
	]
	var daily: Dictionary = _quest(OWN_Q, "player", { "one_use": "bram_discount_10" })
	daily["kind"] = "daily"
	bad.append(daily)
	for quest: Dictionary in bad:
		if QuestEngine.data_problem(quest) == "":
			return "A bad one-use reward must be refused: %s" % [quest]
	return ""


func test_shipped_data_has_both_rewards_and_the_pocket_watch() -> String:
	for id: String in ["bram_discount_10", "free_lab_refit"]:
		if not QuestEngine.has_one_use(id) or QuestEngine.one_use_name(id) == "" or QuestEngine.one_use_held_line(id) == "" or QuestEngine.one_use_used_line(id) == "":
			return "The data has %s with its name and two lines." % id
	if not QuestEngine.one_use_of_farm("free_lab_refit") or QuestEngine.one_use_of_farm("bram_discount_10") or QuestEngine.one_use_pct("bram_discount_10") != 10:
		return "The refit is the farm's; the discount is a player's, 10 percent."
	if QuestEngine.keepsake_name("pocket_watch") == "" or QuestEngine.keepsake_text("pocket_watch") == "" or QuestEngine.keepsake_name("felt_lined_case") == "":
		return "The data has the pocket watch and the case, each with a name and a text."
	return ""


# --- Saves ---------------------------------------------------------------------------

func test_they_are_saved_and_checked() -> String:
	var gs: GameStateScript = _state()
	gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	gs.give_one_use(gs.ONE_USE_DISCOUNT, HOST)
	gs.give_one_use(gs.ONE_USE_REFIT, gs.FARM_HOLDER)
	var saved: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
	var back: GameStateScript = _state()
	var problem: String = ""
	if back.farm_dict_problem(saved) != "" or back.farm_from_dict(saved) != "":
		problem = "A farm that holds them loads: %s" % back.farm_dict_problem(saved)
	if problem == "" and (back.one_use_count(back.ONE_USE_DISCOUNT, HOST) != 2 or back.one_use_count(back.ONE_USE_REFIT) != 1):
		problem = "It holds what it held: %s" % back.one_use_held
	var bad: Array = [
		{ "": { "bram_discount_10": 1 } }, { HOST: 3 }, { HOST: { "bram_discount_10": 0 } }, { HOST: { "bram_discount_10": 10 } },
		{ HOST: { "bram_discount_10": "1" } }, { HOST: { "nope": 1 } }, { HOST: { "free_lab_refit": 1 } },
		{ "_farm": { "bram_discount_10": 1 } }, { 4: { "bram_discount_10": 1 } },
	]
	for held: Dictionary in bad:
		var farm: Dictionary = str_to_var(var_to_str(saved))
		farm["one_use_held"] = held
		if problem == "" and back.farm_dict_problem(farm) == "":
			problem = "A farm that holds %s must not load." % [held]
	back.free()
	_done(gs)
	return problem


func test_a_farm_from_before_holds_none() -> String:
	var gs: GameStateScript = _state()
	var old: Dictionary = gs.farm_to_dict()
	old.erase("one_use_held")
	var problem: String = ""
	if gs.farm_dict_problem(old) != "" or gs.farm_from_dict(old) != "" or not gs.one_use_held.is_empty():
		problem = "A save from before holds none and loads."
	_done(gs)
	return problem


# --- The keepsake shelf ----------------------------------------------------------------

func test_the_keepsakes_held_follow_the_quests_done() -> String:
	var k1: Dictionary = _quest("k1", "player", { "keepsake": "pocket_watch" })
	var k2: Dictionary = _quest("k2", "player", { "keepsake": "felt_lined_case" }, RICH * 2)
	return _with_quests([k1, k2], func() -> String:
		var gs: GameStateScript = _state()
		var problem: String = ""
		if QuestEngine.keepsakes_of(gs, HOST) != []:
			problem = "A new farm holds no keepsake."
		gs.credits = RICH
		gs.update_quests([HOST] as Array[String])
		var held: Array[String] = QuestEngine.keepsakes_of(gs, HOST)
		if problem == "" and held != ["pocket_watch"]:
			problem = "One quest done, one keepsake: %s" % [held]
		gs.credits = RICH * 2
		gs.update_quests([HOST] as Array[String])
		held = QuestEngine.keepsakes_of(gs, HOST)
		if problem == "" and held != ["pocket_watch", "felt_lined_case"]:
			problem = "Two quests done, two keepsakes: %s" % [held]
		if problem == "" and not KeepsakeShelf._text_of("pocket_watch").begins_with("Pocket watch: "):
			problem = "A keepsake reads its name, then its text: '%s'" % KeepsakeShelf._text_of("pocket_watch")
		_done(gs)
		return problem)
