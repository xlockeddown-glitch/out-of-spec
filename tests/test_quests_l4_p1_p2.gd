extends RefCounted
## Quests L4 "Greenhouse Four", P1 "Bram's Ore Run" and P2 "On the Dot" (build
## order step 12, part 2, of docs/design/quests_levels_story.md): each is offered
## when its gate holds and not before, each step moves on the game's own action
## or log, the pay comes once (the one-use reward to the right holder, the
## keepsake held), and a guest never runs the engine. GameClock.elapsed_days
## and the session's players are put back; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const L4: String = "greenhouse_four"
const P1: String = "brams_ore_run"
const P2: String = "on_the_dot"
const REFIT: String = "free_lab_refit"
const DISCOUNT: String = "bram_discount_10"
const WATCH: String = "pocket_watch"
const FM3: String = "field_meter_dc"
const WD1: String = "reference_gauge"
const FISSURES: Array[StringName] = [&"FissureA", &"FissureB", &"FissureC", &"FissureD", &"FissureE", &"FissureF", &"FissureG"]


var _nodes: Array[Node] = []


## Runs `body` on a new farm that has only the quest `id` (as shipped).
func _run(id: String, body: Callable) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	table["quests"] = { StringName(id): _shipped(id).duplicate(true) }
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	var gs: GameStateScript = _farm()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	gs.free()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	gs.credits = 100
	gs.crystal_ore = 0
	return gs


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


func _said(giver: String, path: String) -> String:
	return "%s: %s" % [giver, QuestEngine.phone_line(path)]


func _entry(gs: GameStateScript, id: String, player: String = "") -> Dictionary:
	if player == "":
		return gs.quest_state.get(id, {})
	return (gs.player_quest_state.get(player, {}) as Dictionary).get(id, {})


func _steps(gs: GameStateScript, id: String, player: String = "") -> Array:
	return _entry(gs, id, player).get("steps_done", [])


func _done(gs: GameStateScript, id: String, player: String = "") -> bool:
	return int(_entry(gs, id, player).get("done", -1)) >= 0


func _morning(gs: GameStateScript, day: int) -> void:
	GameClock.elapsed_days = float(day - 1)
	gs.update_quests()


## A guest's copy of `gs`: it runs no quests.
func _guest_copy(gs: GameStateScript) -> GameStateScript:
	var guest: GameStateScript = _farm()
	var problem: String = guest.farm_from_dict(gs.farm_to_dict())
	if problem != "":
		guest.free()
		return null
	return guest


# --- The data ---------------------------------------------------------------------

func test_the_three_quests_ship_as_designed_and_are_sound() -> String:
	for id: String in [L4, P1, P2]:
		var quest: Dictionary = _shipped(id)
		if quest.is_empty() or QuestEngine.data_problem(quest) != "":
			return "%s must be in the data and sound: %s" % [id, QuestEngine.data_problem(quest)]
		if QuestEngine.phone_line(str(quest["offer_line"])) == "" or QuestEngine.phone_line(str(quest["rewards"]["phone"])) == "":
			return "%s has the giver's words." % id
	var l4: Dictionary = _shipped(L4)
	if l4["giver"] != "bram" or l4["kind"] != "lab" or l4["scope"] != "farm" or int(l4["gates"]["lab_level"]) != 20:
		return "L4 is Bram's lab quest, gated on lab level 20: %s" % [l4]
	var ids: Array = []
	for step: Dictionary in l4["steps"]:
		ids.append(step["id"])
	if ids != ["grow", "move_in", "fit"] or not bool(l4.get("any_order", false)):
		return "L4's steps, in any order (a fit made while the lab builds counts): %s" % [ids]
	if int(l4["rewards"]["lab_xp"]) != 500 or l4["rewards"]["one_use"] != REFIT:
		return "L4 pays 500 lab XP and the free refit: %s" % [l4["rewards"]]
	var p1: Dictionary = _shipped(P1)
	if p1["giver"] != "bram" or p1["kind"] != "personal" or p1["scope"] != "player" or p1["gates"] != { "lab_level": 5.0 }:
		return "P1 is Bram's own quest for each player, at lab level 5 (Tier 1 standards open): %s" % [p1]
	if p1["rewards"]["one_use"] != DISCOUNT or int(p1["rewards"]["quest_points"]) != 1 or int(p1["rewards"]["xp_field_ops"]) <= 0:
		return "P1 pays Field Ops XP, 1 quest point and the discount: %s" % [p1["rewards"]]
	var p2: Dictionary = _shipped(P2)
	if p2["scope"] != "player" or p2["gates"]["skill"]["id"] != "uncertainty" or int(p2["gates"]["skill"]["level"]) != 5:
		return "P2 is each player's own, at Uncertainty 5: %s" % [p2]
	if p2["rewards"]["keepsake"] != WATCH or float(p2["rewards"]["xp_certificate"]) <= 0.0 or p2["rewards"].has("quest_points"):
		return "P2 pays an XP certificate and the pocket watch: %s" % [p2["rewards"]]
	return ""


func test_a_wrong_holder_for_the_one_use_reward_is_refused() -> String:
	var l4: Dictionary = _shipped(L4).duplicate(true)
	l4["rewards"]["one_use"] = DISCOUNT  # a player's reward on the farm's quest
	var p1: Dictionary = _shipped(P1).duplicate(true)
	p1["rewards"]["one_use"] = REFIT  # the farm's reward on a player's quest
	for quest: Dictionary in [l4, p1]:
		if QuestEngine.data_problem(quest) == "":
			return "This quest must be refused: %s" % [quest]
	return ""


# --- L4 ---------------------------------------------------------------------------

## The lab at level 20 with L4 open.
func _open_l4(gs: GameStateScript) -> void:
	gs.give_lab_xp(gs.xp_for_level(20) - gs.lab_xp)
	gs.update_quests()


func test_l4_waits_for_lab_level_20() -> String:
	return _run(L4, func(gs: GameStateScript) -> String:
		gs.give_lab_xp(gs.xp_for_level(19) - gs.lab_xp)
		gs.update_quests()
		if gs.lab_level() != 19 or gs.quest_state.has(L4) or _lines(gs, "New quest, Greenhouse Four.") != 0:
			return "L4 is not offered at lab level %d." % gs.lab_level()
		_open_l4(gs)
		if gs.lab_level() != 20 or not gs.quest_state.has(L4) or _done(gs, L4):
			return "L4 is offered at lab level 20: %s" % [gs.quest_state]
		if _lines(gs, "BRAM: New quest, Greenhouse Four.") != 1 or _lines(gs, QuestEngine.phone_line("npcs/bram/quests/greenhouse_four_offer")) != 1:
			return "The offer names the quest and Bram says his words: %s" % [gs.phone_log]
		gs.update_quests()
		return "" if _lines(gs, "New quest, Greenhouse Four.") == 1 else "It is offered once.")


## Fits one new space for any discipline that can take one. True if it did.
func _fit_one(gs: GameStateScript) -> bool:
	for discipline: String in gs.job_disciplines():
		if gs.lab_fit_problem(discipline) == "" and gs.fit_lab_area(discipline) == "":
			return true
	return false


func test_l4_follows_the_grow_and_pays_the_free_refit_once() -> String:
	return _run(L4, _check_l4)


func _check_l4(gs: GameStateScript) -> String:
	_open_l4(gs)
	# Nothing is done before the grow: money alone is not a step.
	gs.credits = 600
	gs.crystal_ore = 4
	gs.update_quests()
	if not _steps(gs, L4).is_empty() or _lines(gs, "Start the medium lab's grow (600 CR and 4 crystal ore).") != 1:
		return "The first step is the grow, named with its cost: %s %s" % [_entry(gs, L4), gs.phone_log]
	var started: String = gs.start_lab_grow()
	if started != "" or gs.lab_build.is_empty():
		return "The test could not start the grow: %s" % started
	gs.update_quests()
	if _steps(gs, L4) != ["grow"] or gs.lab_size != 0:
		return "A grow under way is the first step, and not moving in: %s" % [_entry(gs, L4)]
	gs._finish_lab_build(int(gs.lab_build.get("done_day", 99999)))
	gs.update_quests()
	if _steps(gs, L4) != ["grow", "move_in"] or gs.one_use_count(REFIT) != 0:
		return "The medium lab ready is the second step, and nothing is paid yet: %s" % [_entry(gs, L4)]
	if not _fit_one(gs):
		return "The test could not fit a new space in the medium lab."
	var credits: int = gs.credits
	var lab_xp: int = gs.lab_xp
	gs.update_quests()
	if gs.lab_size != 1 or not _done(gs, L4) or gs.lab_xp < lab_xp + 500 or gs.credits != credits:
		return "The medium lab ready ends L4, paying 500 lab XP and no credits: size %d, %s" % [gs.lab_size, _entry(gs, L4)]
	if gs.one_use_count(REFIT) != 1 or gs.one_use_held.size() != 1 or not gs.one_use_held.has(gs.FARM_HOLDER):
		return "The free refit is the farm's, once: %s" % [gs.one_use_held]
	if _lines(gs, "QUEST DONE: Greenhouse Four.") != 1 or _lines(gs, _said("BRAM", "npcs/bram/quests/greenhouse_four_done")) != 1 \
			or _lines(gs, QuestEngine.one_use_held_line(REFIT)) != 1:
		return "The phone says it is done, Bram has his word, and the refit is announced: %s" % [gs.phone_log]
	var xp_after: int = gs.lab_xp
	_morning(gs, 5)
	gs.update_quests()
	return "" if gs.one_use_count(REFIT) == 1 and gs.lab_xp == xp_after and _lines(gs, "QUEST DONE: Greenhouse Four.") == 1 else "L4 is paid once."


## The bug a review found: the lab level and the grow on the same day, before the
## morning offers L4. The money is spent, the quest then asks for none of it, and
## the spaces fitted after the offer need no refit.
func test_l4_offered_after_the_grow_was_bought_needs_no_money_again() -> String:
	return _run(L4, func(gs: GameStateScript) -> String:
		gs.give_lab_xp(gs.xp_for_level(20) - gs.lab_xp)  # no offering look yet
		gs.credits = 600
		gs.crystal_ore = 4
		if gs.start_lab_grow() != "":
			return "The test could not start the grow."
		if gs.credits != 0 or gs.crystal_ore != 0:
			return "The grow costs the 600 CR and 4 ore."
		gs.update_quests()
		if _steps(gs, L4) != ["grow"]:
			return "The grow bought before the offer does the first step: %s" % [_entry(gs, L4)]
		gs._finish_lab_build(int(gs.lab_build.get("done_day", 99999)))
		if not _fit_one(gs):
			return "The test could not fit a new space."
		gs.update_quests()
		if not _done(gs, L4) or gs.one_use_count(REFIT) != 1:
			return "No money and no refit needed: %s" % [_entry(gs, L4)]
		return "")


func test_l4_on_a_farm_that_is_already_medium_says_what_the_fit_needs() -> String:
	return _run(L4, func(gs: GameStateScript) -> String:
		gs.lab_size = 1
		gs.credits = 100000
		gs.crystal_ore = 100
		while _fit_one(gs):
			pass  # every space of the lab is fitted, as on an old save
		if gs.lab_free_spaces() != 0:
			return "The test needs a full lab."
		_open_l4(gs)
		if _steps(gs, L4) != ["grow", "move_in"] or _done(gs, L4):
			return "An already medium lab has done the grow and the move-in, and not the fit: %s" % [_entry(gs, L4)]
		var fit_text: String = str(_shipped(L4)["steps"][2]["text"])
		if not fit_text.contains("never had") or not fit_text.contains("clear"):
			return "The step says a full lab must clear a space: %s" % fit_text
		# Clearing a space and fitting another area is a new space for that area,
		# so the quest can be finished without a bigger lab.
		var cleared: String = ""
		for discipline: String in gs.job_disciplines():
			if gs.lab_space(discipline) > 0 and gs.clear_lab_area(discipline) == "":
				cleared = discipline
				break
		if cleared == "":
			return "The test could not clear a space."
		gs._finish_lab_build(int(gs.lab_build.get("done_day", 99999)))
		var fitted: bool = false
		for discipline: String in gs.job_disciplines():
			if discipline != cleared and gs.lab_fit_problem(discipline) == "" and int(gs.lab_areas_paid.get(discipline, 0)) <= gs.lab_space(discipline):
				fitted = gs.fit_lab_area(discipline) == ""
				if fitted:
					break
		if not fitted:
			return "The test could not fit another area into the cleared space."
		gs.update_quests()
		return "" if _done(gs, L4) else "A moved space is new for the area it goes to: %s" % [_entry(gs, L4)]
	)


func test_a_guest_runs_no_l4() -> String:
	return _run(L4, func(gs: GameStateScript) -> String:
		_open_l4(gs)
		var guest: GameStateScript = _guest_copy(gs)
		if guest == null or not guest.quest_state.has(L4):
			return "The guest has the host's L4."
		FarmCommands.guest = true
		guest.credits = 600
		guest.crystal_ore = 4
		guest.update_quests()
		var out: String = ""
		if not _steps(guest, L4).is_empty() or not guest.one_use_held.is_empty():
			out = "A guest never moves L4 or pays it: %s" % [guest.quest_state]
		FarmCommands.guest = false
		guest.free()
		return out)


# --- P1 ---------------------------------------------------------------------------

## Lab level 5, where Tier 1 standards open and P1's discount can be used.
func _lab5(gs: GameStateScript) -> void:
	gs.give_lab_xp(gs.xp_for_level(5) - gs.lab_xp)


func test_p1_waits_for_lab_level_5() -> String:
	return _run(P1, func(gs: GameStateScript) -> String:
		gs.give_lab_xp(gs.xp_for_level(4) - gs.lab_xp)
		gs.update_quests()
		if not (gs.player_quest_state.get(HOST, {}) as Dictionary).is_empty() or _lines(gs, "New quest, Bram's Ore Run.") != 0:
			return "P1 is not offered below lab level 5."
		_lab5(gs)
		gs.update_quests()
		return "" if (gs.player_quest_state.get(HOST, {}) as Dictionary).has(P1) else "P1 is offered at lab level 5.")


func test_p1_is_offered_with_its_words() -> String:
	return _run(P1, func(gs: GameStateScript) -> String:
		_lab5(gs)
		gs.update_quests()
		if not (gs.player_quest_state.get(HOST, {}) as Dictionary).has(P1) or _done(gs, P1, HOST):
			return "P1 has no gate: it is offered at the start: %s" % [gs.player_quest_state]
		if _lines(gs, "BRAM: New quest, Bram's Ore Run.") != 1 or _lines(gs, QuestEngine.phone_line("npcs/bram/quests/brams_ore_run_offer")) != 1 \
				or _lines(gs, "Mine five fissures yourself.") != 1:
			return "The offer names the step and Bram says his words: %s" % [gs.phone_log]
		_morning(gs, 2)
		return "" if _lines(gs, "New quest, Bram's Ore Run.") == 1 else "It is offered once.")


func test_p1_counts_the_players_own_fissures_from_the_offer() -> String:
	return _run(P1, func(gs: GameStateScript) -> String:
		# One mined before Bram asks does not count.
		gs.mine_fissure(FISSURES[6], HOST)
		_lab5(gs)
		gs.update_quests()
		for index: int in 4:
			gs.mine_fissure(FISSURES[index], HOST)
		gs.update_quests()
		if not _steps(gs, P1, HOST).is_empty():
			return "Four since the offer is four of five: %s" % [_entry(gs, P1, HOST)]
		# Another player's fissure is theirs.
		gs.mine_fissure(FISSURES[4], "player_2")
		gs.update_quests()
		if not _steps(gs, P1, HOST).is_empty():
			return "A friend's fissure does not count for the host."
		gs.mine_fissure(FISSURES[5], HOST)
		gs.update_quests()
		if _steps(gs, P1, HOST) != ["mine"] or not _done(gs, P1, HOST):
			return "The fifth of their own does the step and ends it: %s" % [_entry(gs, P1, HOST)]
		return "")


func test_p1_pays_once_with_the_discount_to_the_player_alone() -> String:
	return _run(P1, func(gs: GameStateScript) -> String:
		_lab5(gs)
		gs.update_quests()
		var ore: int = gs.crystal_ore
		for index: int in 5:
			gs.mine_fissure(FISSURES[index], HOST)
		if gs.crystal_ore <= ore:
			return "The ore goes to the shared wallet."
		var xp: int = gs.skill_xp("field_ops", HOST)
		var credits: int = gs.credits
		gs.update_quests()
		var paid: int = int(_shipped(P1)["rewards"]["xp_field_ops"])
		if not _done(gs, P1, HOST) or gs.skill_xp("field_ops", HOST) < xp + paid or gs.quest_point_total(HOST) != 1 or gs.credits != credits:
			return "P1 pays %d Field Ops XP and 1 point, no credits: %d, %d." % [paid, gs.skill_xp("field_ops", HOST) - xp, gs.quest_point_total(HOST)]
		if gs.one_use_count(DISCOUNT, HOST) != 1 or gs.one_use_count(DISCOUNT, "player_2") != 0 or gs.one_use_held.size() != 1 or gs.one_use_held.has(gs.FARM_HOLDER):
			return "The discount is the host's, once: %s" % [gs.one_use_held]
		if _lines(gs, "QUEST DONE: Bram's Ore Run.") != 1 or _lines(gs, _said("BRAM", "npcs/bram/quests/brams_ore_run_done")) != 1 \
				or _lines(gs, QuestEngine.one_use_held_line(DISCOUNT)) != 1:
			return "Done, Bram's word and the held line, once each: %s" % [gs.phone_log]
		if not QuestEngine.keepsakes_of(gs, HOST).is_empty():
			return "P1 gives no keepsake."
		# More mining, a morning, and a look: nothing is paid again.
		gs.mine_fissure(FISSURES[5], HOST)
		_morning(gs, 5)
		return "" if gs.quest_point_total(HOST) == 1 and gs.one_use_count(DISCOUNT, HOST) == 1 and _lines(gs, "QUEST DONE: Bram's Ore Run.") == 1 \
				else "P1 is paid once.")


func test_each_player_has_their_own_p1_and_a_guest_runs_none() -> String:
	return _run(P1, func(host: GameStateScript) -> String:
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		_lab5(host)
		host.update_quests()
		if not (host.player_quest_state.get(id, {}) as Dictionary).has(P1) or not (host.player_quest_state.get(HOST, {}) as Dictionary).has(P1):
			return "Each player is offered P1: %s" % [host.player_quest_state]
		# Through the real command path, which hands the guest's id to the mining.
		var commands: Node = CommandsScript.new()
		commands.state = host
		_nodes.append(commands)
		var host_xp: int = host.skill_xp("field_ops", HOST)
		var guest_xp: int = host.skill_xp("field_ops", id)
		for index: int in 5:
			var result: Variant = commands.execute(id, &"mine_fissure", [FISSURES[index]])
			if result is Dictionary and result.get("refused", false):
				return "The guest's mining was refused: %s" % [result]
		host.update_quests()
		if host.skill_xp("field_ops", HOST) != host_xp or host.skill_xp("field_ops", id) < guest_xp + int(_shipped(P1)["rewards"]["xp_field_ops"]):
			return "The guest, not the host, gets the Field Ops XP: host %d, guest %d." % [host.skill_xp("field_ops", HOST) - host_xp, host.skill_xp("field_ops", id) - guest_xp]
		if not _done(host, P1, id) or _done(host, P1, HOST) or host.one_use_count(DISCOUNT, id) != 1 or host.one_use_count(DISCOUNT, HOST) != 0:
			return "The guest's five are the guest's, and so is the discount: %s %s" % [host.player_quest_state, host.one_use_held]
		# A guest's copy runs nothing: the host's mining does not move it.
		var guest: GameStateScript = _guest_copy(host)
		if guest == null:
			return "The guest's copy of the farm must load."
		FarmCommands.guest = true
		for index: int in 5:
			guest.mine_fissure(FISSURES[index], HOST)
		guest.update_quests()
		var out: String = ""
		if _done(guest, P1, HOST) or guest.one_use_count(DISCOUNT, HOST) != 0:
			out = "A guest never runs the quests: %s" % [guest.player_quest_state]
		FarmCommands.guest = false
		guest.free()
		return out)


# --- P2 ---------------------------------------------------------------------------

func test_p2_waits_for_uncertainty_5() -> String:
	return _run(P2, func(gs: GameStateScript) -> String:
		gs.player_skill_xp[HOST] = { "uncertainty": gs.xp_for_level(5) - 1 }
		gs.update_quests()
		if gs.skill_level("uncertainty", HOST) != 4 or not _entry(gs, P2, HOST).is_empty() or _lines(gs, "New quest, On the Dot.") != 0:
			return "Uncertainty 4 is not offered P2."
		gs.player_skill_xp[HOST] = { "uncertainty": gs.xp_for_level(5) }
		_morning(gs, 2)
		if _entry(gs, P2, HOST).is_empty() or _done(gs, P2, HOST):
			return "Uncertainty 5 is offered P2: %s" % [gs.player_quest_state]
		if _lines(gs, "VANCE: New quest, On the Dot.") != 1 or _lines(gs, QuestEngine.phone_line("npcs/vance/quests/on_the_dot_offer")) != 1:
			return "The offer names the quest and Vance says his words: %s" % [gs.phone_log]
		_morning(gs, 3)
		return "" if _lines(gs, "New quest, On the Dot.") == 1 else "It is offered once.")


## One calibration of the tire gauge by `player`, on the day it is due (on time).
func _on_time(gs: GameStateScript, player: String) -> bool:
	var tire: Variant = gs.get_sensor(gs.TIRE_ID)
	tire.error = 0.0
	GameClock.elapsed_days = float(tire.cal_due_day - 1)  # the day number is the elapsed day plus one
	var record: Variant = gs.calibrate(gs.TIRE_ID, player)
	return record is Dictionary and bool(record.get("on_time", false))


## A late one: well past its due day.
func _late(gs: GameStateScript, player: String) -> bool:
	var tire: Variant = gs.get_sensor(gs.TIRE_ID)
	tire.error = 0.0
	GameClock.elapsed_days = float(tire.cal_due_day + 2)
	var record: Variant = gs.calibrate(gs.TIRE_ID, player)
	return record is Dictionary and not bool(record.get("on_time", false))


func _p2_farm(gs: GameStateScript) -> void:
	gs.tier1_unlocked = true
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.get_sensor(gs.TIRE_ID).max_error = INF
	gs.buy_standard(WD1)
	var wd1: DriftingSensor = gs.get_sensor(WD1)
	wd1.max_error = INF
	wd1.cal_due_day = 100000  # the standard stays in date for the whole test
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	tire.last_cal_day = 0
	tire.cal_due_day = tire.cal_interval_days  # the first one is due when it is made
	gs.player_skill_xp[HOST] = { "uncertainty": gs.xp_for_level(5) }
	gs.update_quests()


func test_p2_counts_on_time_calibrations_and_a_late_one_does_not_add() -> String:
	return _run(P2, func(gs: GameStateScript) -> String:
		_p2_farm(gs)
		if _entry(gs, P2, HOST).is_empty():
			return "The test could not offer P2."
		for count: int in 3:
			if not _on_time(gs, HOST):
				return "The test could not calibrate on time (%d)." % count
			gs.update_quests()
		if not _steps(gs, P2, HOST).is_empty():
			return "Three on time is not five: %s" % [_entry(gs, P2, HOST)]
		if not _late(gs, HOST):
			return "The test could not calibrate late."
		gs.update_quests()
		if not _steps(gs, P2, HOST).is_empty():
			return "A late one does not add."
		# Another player's on-time calibration is theirs.
		_on_time(gs, "player_2")
		gs.update_quests()
		if not _steps(gs, P2, HOST).is_empty():
			return "A friend's calibration does not count for the host."
		for count: int in 2:
			_on_time(gs, HOST)
			gs.update_quests()
			if count == 0 and _done(gs, P2, HOST):
				return "Four on time is not five."
		return "" if _done(gs, P2, HOST) and _steps(gs, P2, HOST) == ["on_time"] else "The fifth on time ends P2: %s" % [_entry(gs, P2, HOST)])


func test_p2_pays_the_certificate_and_the_watch_once() -> String:
	return _run(P2, func(gs: GameStateScript) -> String:
		_p2_farm(gs)
		for count: int in 5:
			_on_time(gs, HOST)
		var credits: int = gs.credits
		if not gs.held_xp_certificates(HOST).is_empty() or not QuestEngine.keepsakes_of(gs, HOST).is_empty():
			return "Nothing is paid before the quest is looked at."
		gs.update_quests()
		var paid: int = int(_shipped(P2)["rewards"]["xp_certificate"])
		var held: Dictionary = gs.held_xp_certificates(HOST)
		if not _done(gs, P2, HOST) or held.size() != 1 or int(held.values()[0]) != paid or not gs.held_xp_certificates("player_2").is_empty():
			return "P2 gives the host one %d XP certificate: %s" % [paid, held]
		if QuestEngine.keepsakes_of(gs, HOST) != [WATCH] or gs.quest_point_total(HOST) != 0 or gs.credits != credits or not gs.one_use_held.is_empty():
			return "The watch is held, with no points, credits or one-use reward."
		if _lines(gs, "QUEST DONE: On the Dot.") != 1 or _lines(gs, _said("VANCE", "npcs/vance/quests/on_the_dot_done")) != 1:
			return "Done, and Vance's word, once: %s" % [gs.phone_log]
		_on_time(gs, HOST)
		gs.update_quests()
		_morning(gs, 20)
		return "" if gs.held_xp_certificates(HOST).size() == 1 and QuestEngine.keepsakes_of(gs, HOST) == [WATCH] and _lines(gs, "QUEST DONE: On the Dot.") == 1 \
				else "P2 is paid once.")


func test_a_guest_runs_no_p2() -> String:
	return _run(P2, func(host: GameStateScript) -> String:
		_p2_farm(host)
		for count: int in 5:
			_on_time(host, HOST)
		var guest: GameStateScript = _guest_copy(host)
		if guest == null:
			return "The guest's copy of the farm must load."
		FarmCommands.guest = true
		guest.update_quests()
		var out: String = ""
		if _done(guest, P2, HOST) or not QuestEngine.keepsakes_of(guest, HOST).is_empty() or not guest.held_xp_certificates(HOST).is_empty():
			out = "A guest runs no quests, so nothing is paid on its copy: %s" % [guest.player_quest_state]
		FarmCommands.guest = false
		guest.free()
		return out)


# --- Old saves and guests who bring a quest -----------------------------------------

func test_p1_with_counters_already_past_five_does_not_finish_at_once() -> String:
	return _run(P1, func(gs: GameStateScript) -> String:
		gs.action_counts[HOST] = { "mine_fissure": { "count": 9, "xp": 0 } }
		_lab5(gs)
		gs.update_quests()
		if not (gs.player_quest_state.get(HOST, {}) as Dictionary).has(P1) or _done(gs, P1, HOST) or gs.one_use_count(DISCOUNT, HOST) != 0:
			return "An old save's nine fissures are not Bram's five: %s" % [gs.player_quest_state]
		return "")


func test_p2_with_counters_already_past_five_does_not_finish_at_once() -> String:
	return _run(P2, func(gs: GameStateScript) -> String:
		gs.action_counts[HOST] = { "calibrate_on_time": { "count": 9, "xp": 0 } }
		gs.player_skill_xp[HOST] = { "uncertainty": gs.xp_for_level(5) }
		gs.update_quests()
		if _entry(gs, P2, HOST).is_empty() or _done(gs, P2, HOST) or not QuestEngine.keepsakes_of(gs, HOST).is_empty():
			return "An old save's nine on-time calibrations are not Vance's five: %s" % [gs.player_quest_state]
		return "")


## A record a guest brings, as CoopProfile writes it.
func _brought(entries: Dictionary) -> Dictionary:
	var record: Dictionary = ProfileScript.no_record()
	record["quests"] = entries
	return record


func test_a_guest_bringing_a_done_p1_gets_no_discount() -> String:
	return _run(P1, func(host: GameStateScript) -> String:
		_lab5(host)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], _brought({ P1: { "done": true } }))
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		if not _done(host, P1, id) or host.one_use_count(DISCOUNT, id) != 0 or host.quest_point_total(id) != 0:
			return "A quest done elsewhere pays nothing here: %s %s" % [host.player_quest_state, host.one_use_held]
		return "")


func test_a_guest_bringing_four_of_five_gets_one_discount_when_done_here() -> String:
	return _run(P1, func(host: GameStateScript) -> String:
		_lab5(host)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], _brought({ P1: { "counts": { "mine": 4 } } }))
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		if _done(host, P1, id) or host.one_use_count(DISCOUNT, id) != 0:
			return "Four of five is not done: %s" % [host.player_quest_state]
		host.mine_fissure(FISSURES[0], id)
		host.update_quests()
		if not _done(host, P1, id) or host.one_use_count(DISCOUNT, id) != 1:
			return "The fifth, with four brought, finishes it with one discount: %s %s" % [host.player_quest_state, host.one_use_held]
		# Coming again with the same record, or a later look, gives no second.
		host.update_quests()
		host.let_in_guest(KEY, {}, [HOST] as Array[String], _brought({ P1: { "done": true } }))
		host.update_quests()
		return "" if host.one_use_count(DISCOUNT, id) == 1 else "One discount only: %d." % host.one_use_count(DISCOUNT, id))
