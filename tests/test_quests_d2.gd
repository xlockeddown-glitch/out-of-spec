extends RefCounted
## Daily asks, D2 (build order step 14 of docs/design/quests_levels_story.md): one
## small ask a day for each player from lab level 3, picked by the farm's seed,
## the day and the player, paid once, and gone the next morning with no penalty.
## GameClock, SaveGame.farm_open and the guest flag are put back; every node is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const FILE: String = "user://test_quests_d2_player.json"
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const LIN: String = "daily_lin_reeds"
const BRAM: String = "daily_bram_ore"
const ODALYS: String = "daily_odalys_block"
const ORIN: String = "daily_orin_row"
const ASKS: Array[String] = [LIN, BRAM, ODALYS, ORIN]
const ASK: String = "Today's ask:"
const DONE: String = "QUEST DONE:"
const CERTIFICATE: int = 25
const SEED: int = 77

var _nodes: Array[Node] = []


## A session that is someone's guest, for a profile to ask.
class Away extends Node:
	func is_guest() -> bool:
		return true


## Runs `body` on a new farm at lab level 3, on day 1. `fixtures` replace the
## shipped quests: the four shipped asks alone unless others are given.
func _run(body: Callable, fixtures: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	var mine: Dictionary = {}
	for quest: Dictionary in (fixtures if not fixtures.is_empty() else _only(ASKS)):
		mine[StringName(str(quest["id"]))] = quest
	table["quests"] = mine
	GameClock.elapsed_days = 0.0
	_clear()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(_farm())
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	_clear()
	FarmCommands.guest = false
	table["quests"] = shipped
	GameClock.elapsed_days = saved_day
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	return out if out is String else "The test stopped early or did not return a String."


func _clear() -> void:
	for ending: String in ["", ".tmp", ".unreadable"]:
		if FileAccess.file_exists(FILE + ending):
			DirAccess.remove_absolute(FILE + ending)


## A farm at lab level 3.
func _farm(level: int = 3) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.reset_credibility()
	gs.lab_xp = gs.xp_for_level(level)
	_nodes.append(gs)
	return gs


func _shipped(id: String) -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest["id"]) == id:
			return quest
	return {}


## The shipped asks of `ids`, as data/quests.json has them.
func _only(ids: Array[String]) -> Array:
	var out: Array = []
	for id: String in ids:
		out.append(_shipped(id).duplicate(true))
	return out


func _lines(gs: Node, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


## The ids of the daily asks `player` holds, of any day.
func _held(gs: Node, player: String = HOST) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in (gs.player_quest_state.get(player, {}) as Dictionary):
		if str(id) in ASKS:
			out.append(str(id))
	return out


func _entry(gs: Node, id: String, player: String = HOST) -> Dictionary:
	return (gs.player_quest_state.get(player, {}) as Dictionary).get(id, {})


## The morning of `day` (1 is the first): the clock, then the morning's look.
func _morning(gs: Node, day: int, present: Array[String] = []) -> void:
	GameClock.elapsed_days = float(day - 1)
	gs.update_quests(present)


## The look after a command: nothing is offered.
func _after(gs: Node, present: Array[String] = []) -> void:
	gs.update_quests(present, false)


## A cell that holds a reference block on this farm.
func _block_cell(gs: Node) -> Vector2i:
	var none: Dictionary[Vector2i, int] = {}
	for x: int in range(-40, 40):
		for z: int in range(-40, 40):
			var cell := Vector2i(x, z)
			if Terrain.dig_problem(cell, none) == "" and not ReferenceBlock.at(gs.world_seed, cell).is_empty():
				return cell
	return Vector2i.ZERO


func _find_block(gs: Node) -> bool:
	var cell: Vector2i = _block_cell(gs)
	gs.dig(Vector3i(cell.x, 0, cell.y))
	return gs.found_blocks.size() == 1


## `player` tills `count` cells of the plot that are not tilled yet.
func _till(gs: Node, player: String, count: int) -> void:
	var plot: Rect2i = gs.PLOT
	for x: int in range(plot.position.x, plot.end.x):
		for z: int in range(plot.position.y, plot.end.y):
			if count > 0 and gs.till(Vector3i(x, 0, z), player):
				count -= 1


## `player` does all of what `ask` asks for, as the game's own actions.
func _do(gs: Node, ask: String, player: String = HOST) -> void:
	match ask:
		LIN:
			for i: int in 3:
				gs.harvest_bin.append({ "crop_id": "biscuit_reed", "in_spec": true, "out_of_band_days": 0, "advance": 0 })
			gs.sell_harvest_to_lin(player)
		BRAM:
			var mined: int = 0
			for fissure: StringName in gs.FISSURES:
				if mined < 2 and gs.mine_fissure(fissure, player):
					mined += 1
		ODALYS:
			gs.check_with_block(gs.STEERING_ID, player)
		ORIN:
			_till(gs, player, 6)


# --- The data ---------------------------------------------------------------------

func test_the_four_asks_are_shipped() -> String:
	var problems: PackedStringArray = []
	for id: String in ASKS:
		var quest: Dictionary = _shipped(id)
		if quest.is_empty() or QuestEngine.data_problem(quest) != "":
			problems.append("%s: %s" % [id, QuestEngine.data_problem(quest) if not quest.is_empty() else "not shipped."])
			continue
		var rewards: Dictionary = quest.get("rewards", {})
		if not QuestEngine.is_daily(quest) or str(quest.get("scope", "")) != QuestEngine.SCOPE_PLAYER or int((quest.get("gates", {}) as Dictionary).get("lab_level", 0)) != 3:
			problems.append("%s is a daily ask of a player's own, from lab level 3." % id)
		if int(rewards.get("credits", 0)) < 30 or int(rewards.get("credits", 0)) > 60 or int(rewards.get("xp_certificate", 0)) != CERTIFICATE or rewards.has("quest_points"):
			problems.append("%s pays 30 to 60 CR, a small certificate and no quest points: %s" % [id, rewards])
		for path: String in [str(quest.get("offer_line", "")), str(rewards.get("phone", ""))]:
			if path == "" or QuestEngine.phone_line(path) == path:
				problems.append("%s: '%s' is a path with no text at it." % [id, path])
	if QuestEngine.daily_quests().size() != ASKS.size():
		problems.append("There are four daily asks: %d." % QuestEngine.daily_quests().size())
	# The engine holds a daily ask to its rules.
	var on_farm: Dictionary = _shipped(ORIN).duplicate(true)
	on_farm["scope"] = "farm"
	var pointed: Dictionary = _shipped(ORIN).duplicate(true)
	pointed["rewards"]["quest_points"] = 1
	if QuestEngine.data_problem(on_farm) == "" or QuestEngine.data_problem(pointed) == "":
		problems.append("A daily ask of the whole farm, or one that pays quest points, must be refused.")
	for id: Variant in QuestEngine.player_quests():
		if QuestEngine.is_daily_id(str(id)) or str(id) in ASKS:
			problems.append("%s is a daily ask among the quests that travel." % id)
	if SessionScript.PROTOCOL != 47:
		problems.append("Daily asks change nothing in what is sent: the protocol stays 18.")
	return "\n".join(problems)


# --- Given ------------------------------------------------------------------------

func test_no_ask_below_lab_level_3() -> String:
	return _run(func(gs: GameStateScript) -> String:
		gs.lab_xp = gs.xp_for_level(3) - 1
		_morning(gs, 1)
		_morning(gs, 2)
		if gs.lab_level() != 2 or not gs.player_quest_state.is_empty() or _lines(gs, ASK) != 0:
			return "No ask at lab level %d: %s" % [gs.lab_level(), gs.player_quest_state]
		# Reached in the day: the ask comes with the next morning, not after a command.
		gs.lab_xp = gs.xp_for_level(3)
		_after(gs)
		if not gs.player_quest_state.is_empty():
			return "An ask is given in the morning, not after a command."
		_morning(gs, 3)
		if _held(gs).size() != 1 or _lines(gs, ASK) != 1 or int(_entry(gs, _held(gs)[0])["accepted"]) != 3:
			return "At lab level 3 the morning brings one ask: %s %s" % [gs.player_quest_state, gs.phone_log]
		return "")


func test_one_ask_a_day_and_its_line_is_the_giver_s() -> String:
	return _run(func(gs: GameStateScript) -> String:
		_morning(gs, 1)
		var held: Array[String] = _held(gs)
		if held.size() != 1:
			return "One ask: %s" % [gs.player_quest_state]
		var quest: Dictionary = _shipped(held[0])
		var line: String = "%s: %s %s %s" % [str(quest["giver"]).to_upper(), QuestEngine.phone_line(str(quest["offer_line"])), ASK, quest["steps"][0]["text"]]
		if not gs.phone_log.has(line) or _lines(gs, "New quest") != 0:
			return "The ask is the giver's line and what counts, '%s': %s" % [line, gs.phone_log]
		if QuestEngine.daily_ask(gs, HOST) != quest or QuestEngine.daily_done(gs, HOST):
			return "daily_ask() is today's ask, not done yet."
		# Looked at again and again, opened again, done or not: still the one.
		for i: int in 3:
			gs.update_quests()
			_after(gs)
		_do(gs, held[0])
		_find_block(gs)
		_after(gs)
		gs.update_quests()
		if _held(gs) != held or _lines(gs, ASK) != 1 or not QuestEngine.daily_done(gs, HOST):
			return "No second ask the same day, done or not: %s" % [gs.player_quest_state]
		return "")


func test_the_pick_is_the_seed_s_the_day_s_and_the_player_s() -> String:
	return _run(func(gs: GameStateScript) -> String:
		if not _find_block(gs):
			return "The test needs a block."
		var dailies: Array[Dictionary] = QuestEngine.daily_quests()
		var other: GameStateScript = _farm()
		_find_block(other)
		var seen: Dictionary = {}
		var apart: int = 0
		for day: int in range(1, 41):
			var pick: Dictionary = QuestEngine.pick_daily(gs, dailies, HOST, day)
			if pick.is_empty() or pick != QuestEngine.pick_daily(gs, dailies, HOST, day) or pick != QuestEngine.pick_daily(other, dailies, HOST, day):
				return "Day %d: the same seed, day and player must give the same ask." % day
			if pick != dailies[QuestEngine.daily_roll(SEED, day, HOST) % dailies.size()]:
				return "Day %d: the pick is the roll among the open asks." % day
			seen[pick["id"]] = true
			if pick != QuestEngine.pick_daily(gs, dailies, "player_2", day):
				apart += 1
		if seen.size() != ASKS.size() or apart == 0:
			return "Over 40 days every ask comes up, and two players' asks differ some days: %s, %d" % [seen.keys(), apart]
		if QuestEngine.daily_roll(SEED, 5, HOST) == QuestEngine.daily_roll(SEED + 1, 5, HOST) and QuestEngine.daily_roll(SEED, 6, HOST) == QuestEngine.daily_roll(SEED + 1, 6, HOST):
			return "Another farm's seed rolls another way."
		# And the morning gives that pick.
		_morning(gs, 4)
		if _held(gs) != [str(QuestEngine.pick_daily(gs, dailies, HOST, 4)["id"])]:
			return "The morning's ask is the pick."
		return "")


func test_an_ask_that_can_t_be_done_is_not_picked() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var dailies: Array[Dictionary] = QuestEngine.daily_quests()
		var picks: Callable = func(farm: Node) -> Dictionary:
			var seen: Dictionary = {}
			for day: int in range(1, 81):
				seen[QuestEngine.pick_daily(farm, dailies, HOST, day)["id"]] = true
			return seen
		var without: Dictionary = picks.call(gs)
		if without.has(ODALYS) or without.size() != 3:
			return "With no block the block ask is never picked, and another is: %s" % [without.keys()]
		if not gs.check_with_block(gs.STEERING_ID, HOST).get("refused", false) or gs.action_count(gs.BLOCK_CHECK_COUNT + gs.STEERING_ID, HOST) != 0:
			return "A refused check is not counted."
		if not _find_block(gs) or not (picks.call(gs) as Dictionary).has(ODALYS):
			return "With a block the block ask comes up."
		# A plot with under a row left to till: Orin does not ask.
		_till(gs, HOST, gs.PLOT.get_area() - 5)
		var tilled: Dictionary = picks.call(gs)
		if gs.untilled_cells() != 5 or tilled.has(ORIN) or tilled.size() != 3:
			return "With %d cells left the row is not asked for: %s" % [gs.untilled_cells(), tilled.keys()]
		return "")


# --- Done and paid ----------------------------------------------------------------

func test_each_ask_is_done_and_paid_once() -> String:
	var problems: PackedStringArray = []
	for ask: String in ASKS:
		var problem: String = _run(_check_paid_once.bind(ask), _only([ask] as Array[String]))
		if problem != "":
			problems.append("%s: %s" % [ask, problem])
	return "\n".join(problems)


func _check_paid_once(gs: GameStateScript, ask: String) -> String:
	if ask == ODALYS and not _find_block(gs):
		return "The test needs a block."
	_morning(gs, 1)
	if _held(gs) != [ask]:
		return "The ask was not given: %s" % [gs.player_quest_state]
	var quest: Dictionary = _shipped(ask)
	var points: int = QuestEngine.points_of(gs, HOST)
	_do(gs, ask)
	var credits: int = gs.credits
	_after(gs)
	var pay: int = int(quest["rewards"]["credits"])
	if gs.credits != credits + pay or not QuestEngine.daily_done(gs, HOST) or _lines(gs, DONE) != 1:
		return "Done, it pays %d CR: %d, %s" % [pay, gs.credits - credits, gs.phone_log]
	if _lines(gs, QuestEngine.phone_line(str(quest["rewards"]["phone"]))) != 1:
		return "The giver says so: %s" % [gs.phone_log]
	var held: Dictionary = gs.held_xp_certificates(HOST)
	if held.size() != 1 or int(held.values()[0]) != CERTIFICATE or gs.xp_certificate_source(str(held.keys()[0])) != ask:
		return "It gives one %d XP certificate: %s" % [CERTIFICATE, held]
	if QuestEngine.points_of(gs, HOST) != points or not gs.quest_points.is_empty():
		return "A daily ask pays no quest points."
	# More of the same, more looks, a reopened farm: nothing more that day.
	if ask != BRAM:
		_do(gs, ask)
	credits = gs.credits
	_after(gs)
	gs.update_quests()
	if gs.credits != credits or _lines(gs, DONE) != 1 or gs.held_xp_certificates(HOST).size() != 1:
		return "It pays once."
	return gs.farm_dict_problem(gs.farm_to_dict())


func test_counting_starts_when_the_ask_is_given() -> String:
	return _run(func(gs: GameStateScript) -> String:
		# Mined and tilled before there was an ask: none of it counts.
		gs.lab_xp = 0
		_morning(gs, 1)
		gs.mine_fissure(gs.FISSURES[0], HOST)
		gs.mine_fissure(gs.FISSURES[1], HOST)
		gs.lab_xp = gs.xp_for_level(3)
		_morning(gs, 2)
		if _held(gs) != [BRAM] or QuestEngine.daily_done(gs, HOST):
			return "The ask is given on day 2, not done: %s" % [gs.player_quest_state]
		_after(gs)
		gs.mine_fissure(gs.FISSURES[2], HOST)
		_after(gs)
		if QuestEngine.daily_done(gs, HOST) or _lines(gs, "1 of 2") != 1:
			return "One ore since the ask is 1 of 2: %s" % [gs.phone_log]
		gs.mine_fissure(gs.FISSURES[3], HOST)
		_after(gs)
		return "" if QuestEngine.daily_done(gs, HOST) else "Two ore since the ask does it.",
		_only([BRAM] as Array[String]))


# --- The next morning -------------------------------------------------------------

func test_a_missed_ask_is_gone_with_no_penalty_and_a_new_one_given() -> String:
	return _run(func(gs: GameStateScript) -> String:
		_morning(gs, 1)
		var first: Array[String] = _held(gs)
		gs.mine_fissure(gs.FISSURES[0], HOST)
		_till(gs, HOST, 2)
		_after(gs)
		var credits: int = gs.credits
		var credibility: int = gs.credibility
		var log_size: int = gs.phone_log.size()
		_morning(gs, 2)
		var now: Array[String] = _held(gs)
		if now.size() != 1 or int(_entry(gs, now[0])["accepted"]) != 2 or QuestEngine.daily_done(gs, HOST):
			return "The morning takes the missed ask (%s) and gives a new one: %s" % [first, gs.player_quest_state]
		if not (_entry(gs, now[0])["steps_done"] as Array).is_empty() or not (_entry(gs, now[0])["shown"] as Dictionary).values().all(func(count: int) -> bool: return count == 0):
			return "The new ask starts from nothing: %s" % [_entry(gs, now[0])]
		if gs.credits != credits or gs.credibility != credibility or not gs.held_xp_certificates(HOST).is_empty():
			return "A missed ask costs nothing and pays nothing."
		# All the morning says of asks is the new one.
		if _lines(gs, ASK) != 2 or _lines(gs, DONE) != 0 or gs.phone_log.size() != log_size + 1:
			return "Nothing is said of the missed ask: %s" % [gs.phone_log.slice(log_size)]
		# A day with nobody looking in between: the old ask still goes.
		_morning(gs, 5)
		if _held(gs).size() != 1 or int(_entry(gs, _held(gs)[0])["accepted"]) != 5:
			return "An ask of any earlier day goes: %s" % [gs.player_quest_state]
		return gs.farm_dict_problem(gs.farm_to_dict()))


func test_an_ask_can_come_again_and_pay_again() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var credits: int = gs.credits
		for day: int in range(1, 4):
			_morning(gs, day)
			if _held(gs) != [ORIN] or QuestEngine.daily_done(gs, HOST):
				return "Day %d: the ask comes again, not done: %s" % [day, gs.player_quest_state]
			_do(gs, ORIN)
			_after(gs)
			if not QuestEngine.daily_done(gs, HOST) or gs.credits != credits + 30 * day or gs.held_xp_certificates(HOST).size() != day:
				return "Day %d: done again it pays again, with its certificate: %d CR, %s" % [day, gs.credits - credits, gs.held_xp_certificates(HOST)]
			if gs.farm_dict_problem(gs.farm_to_dict()) != "":
				return gs.farm_dict_problem(gs.farm_to_dict())
		# Spent, such a certificate is not "spent for good": the next still comes.
		var skill: String = "calibration"
		var before: int = gs.skill_xp(skill, HOST)
		if gs.spend_xp_certificate(str(gs.held_xp_certificates(HOST).keys()[0]), skill, HOST) != "" or gs.skill_xp(skill, HOST) != before + CERTIFICATE:
			return "The certificate is spent as any other."
		if not gs.xp_certificates_spent.is_empty() or gs.held_xp_certificates(HOST).size() != 2:
			return "A daily ask's certificate is not kept as spent: %s" % [gs.xp_certificates_spent]
		_morning(gs, 4)
		_do(gs, ORIN)
		_after(gs)
		return "" if gs.held_xp_certificates(HOST).size() == 3 else "After one is spent the next day's still comes.",
		_only([ORIN] as Array[String]))


# --- Saved ------------------------------------------------------------------------

func test_an_ask_is_saved_and_loaded_mid_day() -> String:
	return _run(func(gs: GameStateScript) -> String:
		_morning(gs, 3)
		gs.mine_fissure(gs.FISSURES[0], HOST)
		_after(gs)
		var saved: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		var back: GameStateScript = _farm(1)
		if back.farm_dict_problem(saved) != "" or back.farm_from_dict(saved) != "":
			return "A farm with an ask under way must load: %s" % back.farm_dict_problem(saved)
		var log_size: int = back.phone_log.size()
		# The look when a farm is opened: the ask is the one it was, where it was.
		back.update_quests()
		if back.player_quest_state != gs.player_quest_state or _held(back) != [BRAM] or back.phone_log.size() != log_size:
			return "The loaded farm holds the same ask, said once: %s" % [back.player_quest_state]
		var credits: int = back.credits
		back.mine_fissure(back.FISSURES[1], HOST)
		_after(back)
		if not QuestEngine.daily_done(back, HOST) or back.credits != credits + 40:
			return "The loaded ask goes on from 1 of 2 and pays."
		# Done and saved, it is not paid again on a load, nor asked again that day.
		var done: Dictionary = str_to_var(var_to_str(back.farm_to_dict()))
		var again: GameStateScript = _farm(1)
		if again.farm_from_dict(done) != "":
			return "A farm with a done ask must load."
		again.update_quests()
		if again.credits != back.credits or again.held_xp_certificates(HOST).size() != 1 or again.player_quest_state != back.player_quest_state:
			return "A done ask is not paid or given again on a load."
		# Loaded on a later day, the ask is of another day: gone, and a new one.
		GameClock.elapsed_days = 6.0
		var later: GameStateScript = _farm(1)
		later.farm_from_dict(saved)
		later.update_quests()
		if _held(later) != [BRAM] or int(_entry(later, BRAM)["accepted"]) != 7 or not (_entry(later, BRAM)["steps_done"] as Array).is_empty() or later.credits != gs.credits:
			return "Loaded on a later day the old ask goes and a new one is given: %s" % [later.player_quest_state]
		return "",
		_only([BRAM] as Array[String]))


func test_the_pick_is_the_same_after_a_load() -> String:
	return _run(func(gs: GameStateScript) -> String:
		_find_block(gs)
		# Saved before the morning's look, loaded twice: both farms are asked the same.
		GameClock.elapsed_days = 8.0
		var saved: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		var picks: Array = []
		for i: int in 2:
			var back: GameStateScript = _farm(1)
			if back.farm_from_dict(saved) != "":
				return "The farm must load."
			back.update_quests()
			picks.append(_held(back))
		gs.update_quests()
		return "" if picks[0].size() == 1 and picks[0] == picks[1] and picks[0] == _held(gs) else "A reload must agree on the ask: %s" % [picks])


func test_an_old_save_loads_and_is_asked() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var old: Dictionary = gs.farm_to_dict()
		for field: String in ["player_quest_state", "quest_state", "quest_points", "xp_certificates", "xp_certificates_given", "xp_certificates_spent", "action_counts"]:
			old.erase(field)
		var back: GameStateScript = _farm(1)
		if back.farm_dict_problem(old) != "" or back.farm_from_dict(old) != "":
			return "A save from before quests must load: %s" % back.farm_dict_problem(old)
		back.update_quests()
		if back.lab_level() != 3 or _held(back).size() != 1:
			return "An old farm at lab level 3 is asked when it is opened: %s" % [back.player_quest_state]
		# A save from before this build that counted no block checks, and one that did.
		if not _find_block(gs):
			return "The test needs a block."
		gs.check_with_block(gs.STEERING_ID, HOST)
		gs.check_with_block(gs.STEERING_ID, gs.MANAGER_ID)
		var counted: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		if gs.action_count(gs.BLOCK_CHECK_COUNT + gs.STEERING_ID, HOST) != 1 or gs.action_counts.has(gs.MANAGER_ID) or gs.farm_dict_problem(counted) != "":
			return "A check is counted for a player, never the manager, and is saved: %s" % gs.farm_dict_problem(counted)
		var with: GameStateScript = _farm(1)
		if with.farm_from_dict(counted) != "" or with.action_count(gs.BLOCK_CHECK_COUNT + gs.STEERING_ID, HOST) != 1:
			return "The count of checks must come back."
		# A save with an ask this build does not have, of some earlier day: left alone.
		var odd: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		odd["player_quest_state"] = { HOST: { "daily_gone": { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [HOST], "done": -1, "carried": {} } } }
		var kept: GameStateScript = _farm(1)
		if kept.farm_dict_problem(odd) != "" or kept.farm_from_dict(odd) != "":
			return "A save with an ask of another build must load: %s" % kept.farm_dict_problem(odd)
		kept.update_quests()
		return "" if _held(kept).size() == 1 else "And its player is asked as any other.")


# --- Co-op ------------------------------------------------------------------------

func _both(id: String) -> Array[String]:
	return [HOST, id]


func test_two_players_have_their_own_asks() -> String:
	return _run(func(host: GameStateScript) -> String:
		host.update_quests([HOST] as Array[String])
		# A friend who drops in is asked at once, not the next morning.
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "" or _held(host) != [ORIN] or _held(host, id) != [ORIN] or _lines(host, ASK) != 2:
			return "Each player has an ask of their own: %s" % [host.player_quest_state]
		host.update_quests(_both(id))
		if _lines(host, ASK) != 2:
			return "Nobody is asked twice."
		# The plot is the farm's: a row tilled by either is a row for Orin, and each
		# player's own ask is paid once, into the shared wallet.
		_till(host, id, 3)
		_after(host, _both(id))
		if QuestEngine.daily_done(host, id) or QuestEngine.daily_done(host, HOST):
			return "Three cells is not a row."
		_till(host, HOST, 3)
		var credits: int = host.credits
		_after(host, _both(id))
		if not QuestEngine.daily_done(host, id) or not QuestEngine.daily_done(host, HOST) or host.credits != credits + 60 or _lines(host, DONE) != 2:
			return "Six cells between them does both asks, each paid once: %s" % [host.player_quest_state]
		if host.held_xp_certificates(id).size() != 1 or host.held_xp_certificates(HOST).size() != 1:
			return "Each has their own certificate."
		_till(host, id, 6)
		_after(host, _both(id))
		if host.credits != credits + 60 or host.held_xp_certificates(id).size() != 1:
			return "More tilling pays nothing more."
		# The guest's view: the farm as it reaches them says the same.
		var guest: GameStateScript = _farm(1)
		guest.local_player_id = id
		FarmCommands.guest = true
		var problem: String = FarmSync.join(FarmSync.capture(host), guest)
		if problem != "" or var_to_bytes(guest.player_quest_state) != var_to_bytes(host.player_quest_state):
			return "The guest's copy holds both asks as the host does. %s" % problem
		if str(QuestEngine.daily_ask(guest, id).get("id", "")) != ORIN or not QuestEngine.daily_done(guest, id) or guest.held_xp_certificates().size() != 1:
			return "The guest sees their ask done and their certificate."
		# A guest decides nothing: their look changes nothing.
		GameClock.elapsed_days = 3.0
		guest.update_quests()
		if var_to_bytes(guest.player_quest_state) != var_to_bytes(host.player_quest_state):
			return "A guest's copy is the host's."
		FarmCommands.guest = false
		# The next morning both are asked again, each their own.
		GameClock.elapsed_days = 0.0
		_morning(host, 2, _both(id))
		if _held(host) != [ORIN] or _held(host, id) != [ORIN] or int(_entry(host, ORIN, id)["accepted"]) != 2 or QuestEngine.daily_done(host, id):
			return "Day 2 asks both again: %s" % [host.player_quest_state]
		# A guest who is away keeps yesterday's until they are back; then it goes.
		_morning(host, 3, [HOST] as Array[String])
		if int(_entry(host, ORIN, id)["accepted"]) != 2 or host.farm_dict_problem(host.farm_to_dict()) != "":
			return "An away guest's ask waits, and saves."
		if host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record()) != id or int(_entry(host, ORIN, id)["accepted"]) != 3:
			return "Back on day 3 the guest gets day 3's ask: %s" % [host.player_quest_state.get(id)]
		return "",
		_only([ORIN] as Array[String]))


func test_two_players_asks_are_picked_apart() -> String:
	return _run(func(host: GameStateScript) -> String:
		_find_block(host)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		var dailies: Array[Dictionary] = QuestEngine.daily_quests()
		var apart: int = 0
		for day: int in range(1, 13):
			_morning(host, day, _both(id))
			for player: String in _both(id):
				if _held(host, player) != [str(QuestEngine.pick_daily(host, dailies, player, day)["id"])]:
					return "Day %d: %s holds the pick of their own roll: %s" % [day, player, host.player_quest_state]
			if _held(host) != _held(host, id):
				apart += 1
		return "" if apart > 0 else "Over 12 days two players' asks differ some day.")


func test_an_ask_and_its_certificate_stay_on_the_farm() -> String:
	return _run(func(host: GameStateScript) -> String:
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		_till(host, id, 6)
		_after(host, _both(id))
		if not QuestEngine.daily_done(host, id) or host.held_xp_certificates(id).size() != 1:
			return "The test needs the guest's ask done."
		if not QuestEngine.travelling(host, id).is_empty():
			return "A daily ask is not in what travels: %s" % [QuestEngine.travelling(host, id)]
		# The guest's own file keeps none of it.
		var view: GameStateScript = _farm(1)
		view.farm_from_dict(host.farm_to_dict())
		view.local_player_id = id
		var session: Node = Away.new()
		var profile: Node = ProfileScript.new()
		_nodes.append(session)
		_nodes.append(profile)
		profile.path = FILE
		profile.session = session
		profile.farm = view
		profile.keep()
		var kept: Dictionary = profile.record()
		if not (kept["quests"] as Dictionary).is_empty() or not (kept["xp_certificates"] as Dictionary).is_empty() or not (kept["xp_certificates_spent"] as Array).is_empty():
			return "The guest's file holds no daily ask and no certificate of one: %s" % [kept]
		# A file that claims one done and a certificate held: another farm gives nothing for it.
		var claim: Dictionary = ProfileScript.no_record().merged({
			"quests": { ORIN: { "done": true, "steps": ["till"], "counts": { "till": 6 } } },
			"xp_certificates": { ORIN: CERTIFICATE }, "xp_certificates_spent": [ORIN], "quest_points": { ORIN: 1 } }, true)
		var other: GameStateScript = _farm()
		var credits: int = other.credits
		var there: String = other.let_in_guest(KEY, {}, [HOST] as Array[String], claim)
		if other.credits != credits or not other.held_xp_certificates(there).is_empty() or not other.xp_certificates_spent.is_empty() or not other.quest_points.is_empty():
			return "A record's daily ask pays nothing on another farm."
		if _held(other, there) != [ORIN] or QuestEngine.daily_done(other, there):
			return "There the guest is asked afresh: %s" % [other.player_quest_state]
		# Back on the first farm, the certificate is where it was left.
		if host.let_in_guest(KEY, {}, [HOST] as Array[String], kept) != "" and host.held_xp_certificates(id).size() != 1:
			return "The farm keeps the guest's certificate."
		return "",
		_only([ORIN] as Array[String]))


func test_a_guest_s_block_check_is_theirs() -> String:
	if FarmCommands._player_index(&"check_with_block") != 1 or FarmCommands.problem(&"check_with_block", [GameState.STEERING_ID]) != "":
		return "The host must be told who checked: check_with_block takes the player after the instrument."
	return _run(func(host: GameStateScript) -> String:
		if not _find_block(host):
			return "The test needs a block."
		host.update_quests([HOST] as Array[String])
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		# The other instrument is not the one asked for.
		host.check_with_block("relay_dish_azimuth", id)
		_after(host, _both(id))
		if QuestEngine.daily_done(host, id):
			return "Only the steering encoder counts."
		host.check_with_block(host.STEERING_ID, id)
		_after(host, _both(id))
		if not QuestEngine.daily_done(host, id) or QuestEngine.daily_done(host, HOST):
			return "The guest's check does the guest's ask alone: %s" % [host.player_quest_state]
		if host.action_xp(host.BLOCK_CHECK_COUNT + host.STEERING_ID, id) != 0 or host.skill_xp("calibration", id) != 0:
			return "A check gives no XP."
		return "",
		_only([ODALYS] as Array[String]))


# --- After review -----------------------------------------------------------------

## The plot and the fissures are shared: what another player does to them moves
## an ask on, and never puts it out of reach.
func test_a_shared_ask_is_never_put_out_of_reach() -> String:
	var problems: PackedStringArray = []
	# Exactly a row left: the other player tills all of it. The asker's ask is done.
	problems.append(_run(func(host: GameStateScript) -> String:
		_till(host, HOST, host.PLOT.get_area() - 6)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		# Left the day before, so each is there to be asked this morning.
		_morning(host, 2, _both(id))
		if host.untilled_cells() != 6 or _held(host) != [ORIN] or _held(host, id) != [ORIN]:
			return "With six cells left both are asked for the row: %s" % [host.player_quest_state]
		_till(host, id, 6)
		_after(host, _both(id))
		if host.untilled_cells() != 0 or not QuestEngine.daily_done(host, HOST) or not QuestEngine.daily_done(host, id):
			return "The guest tilling the last row does the host's ask too: %s" % [host.player_quest_state]
		# With no row left, the next morning Orin does not ask.
		_morning(host, 3, _both(id))
		return "" if _held(host).is_empty() and _held(host, id).is_empty() else "A fully tilled plot is not asked for a row.",
		_only([ORIN] as Array[String])))
	# Bram: the other player mines; and with under two fissures open he does not ask.
	problems.append(_run(func(host: GameStateScript) -> String:
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		_morning(host, 1, _both(id))
		if _held(host) != [BRAM] or _held(host, id) != [BRAM]:
			return "Both are asked for ore: %s" % [host.player_quest_state]
		for fissure: StringName in host.FISSURES:
			host.mine_fissure(fissure, id)
		var credits: int = host.credits
		_after(host, _both(id))
		if host.open_fissures() != 0 or not QuestEngine.daily_done(host, HOST) or not QuestEngine.daily_done(host, id) or host.credits != credits + 80:
			return "The guest mining every fissure does the host's ask too, each paid once: %s" % [host.player_quest_state]
		# A farm whose fissures are mined out when the ask would be given: no ask.
		var late: GameStateScript = _farm()
		for i: int in host.FISSURES.size() - 1:
			late.mine_fissure(late.FISSURES[i], HOST)
		late.update_quests()
		if late.open_fissures() != 1 or not _held(late).is_empty():
			return "With one fissure open Bram does not ask for two: %s" % [late.player_quest_state]
		late.mine_fissure(late.FISSURES[0], HOST)
		GameClock.elapsed_days = 1.0
		late.update_quests()
		return "" if late.open_fissures() == 8 and _held(late) == [BRAM] else "Regrown, he asks.",
		_only([BRAM] as Array[String])))
	# Odalys's is the player's own: a check is not a thing that runs out.
	if str(_shipped(ODALYS)["steps"][0].get("whose", "")) != "" or str(_shipped(ORIN)["steps"][0].get("whose", "")) != QuestEngine.WHOSE_FARM or str(_shipped(BRAM)["steps"][0].get("whose", "")) != QuestEngine.WHOSE_FARM:
		problems.append("The row and the ore count the farm's doing; the block check the player's own.")
	return "\n".join(problems).strip_edges()


## The day turns at 06:00 and nowhere else: an ask worked on at 05:50 and done
## before 06:00 pays; work across 06:00 does not carry.
func test_the_day_of_an_ask_turns_at_six() -> String:
	return _run(func(gs: GameStateScript) -> String:
		_morning(gs, 1)
		# 05:50 the next calendar morning is still day 1.
		GameClock.elapsed_days = (23.0 + 50.0 / 60.0) / 24.0
		if GameClock.get_day_index() != 1 or absf(GameClock.get_hour() - (5.0 + 50.0 / 60.0)) > 0.01:
			return "The test's clock is not 05:50 of day 1: %f" % GameClock.get_hour()
		_till(gs, HOST, 3)
		_after(gs)
		GameClock.elapsed_days = (23.0 + 59.0 / 60.0) / 24.0
		_till(gs, HOST, 3)
		var credits: int = gs.credits
		_after(gs)
		if not QuestEngine.daily_done(gs, HOST) or gs.credits != credits + 30 or int(_entry(gs, ORIN)["accepted"]) != 1:
			return "An ask done at 05:59 is day 1's and pays: %s" % [gs.player_quest_state]
		# Day 2: three cells at 05:50, three after 06:00. The three do not carry.
		_morning(gs, 2)
		GameClock.elapsed_days = 1.0 + (23.0 + 50.0 / 60.0) / 24.0
		_till(gs, HOST, 3)
		_after(gs)
		if QuestEngine.daily_done(gs, HOST) or int((_entry(gs, ORIN)["shown"] as Dictionary).get("till", 0)) != 3:
			return "Three of six at 05:50: %s" % [_entry(gs, ORIN)]
		credits = gs.credits
		var certificates: int = gs.held_xp_certificates(HOST).size()
		_morning(gs, 3)
		var entry: Dictionary = _entry(gs, ORIN)
		if int(entry["accepted"]) != 3 or not (entry["steps_done"] as Array).is_empty() or int((entry["shown"] as Dictionary).get("till", 0)) != 0:
			return "At 06:00 the old ask is taken out and a new one given from nothing: %s" % [entry]
		_till(gs, HOST, 3)
		_after(gs)
		if QuestEngine.daily_done(gs, HOST) or gs.credits != credits or gs.held_xp_certificates(HOST).size() != certificates:
			return "Three before 06:00 and three after is not a row for either day."
		_till(gs, HOST, 3)
		_after(gs)
		return "" if QuestEngine.daily_done(gs, HOST) and gs.credits == credits + 30 else "Six since 06:00 does day 3's.",
		_only([ORIN] as Array[String]))


## A guest's record that names a daily ask (a forged file) is not taken.
func test_a_record_naming_a_daily_ask_is_ignored() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var forged: Dictionary = {}
		for ask: String in ASKS:
			var quest: Dictionary = _shipped(ask)
			forged[ask] = { "done": true, "steps": [str(quest["steps"][0]["id"])], "counts": { str(quest["steps"][0]["counter"]): 99 } }
		# Before any ask is held, and while one is.
		var credits: int = gs.credits
		if QuestEngine.take_brought(gs, HOST, forged) or not gs.player_quest_state.is_empty():
			return "take_brought must not take a daily ask: %s" % [gs.player_quest_state]
		_morning(gs, 1)
		var before: PackedByteArray = var_to_bytes(gs.player_quest_state)
		var partly: Dictionary = forged.duplicate(true)
		for ask: String in ASKS:
			partly[ask]["done"] = false
		if QuestEngine.take_brought(gs, HOST, forged) or QuestEngine.take_brought(gs, HOST, partly) or var_to_bytes(gs.player_quest_state) != before:
			return "A held ask is not moved by a record either."
		_after(gs)
		if QuestEngine.daily_done(gs, HOST) or gs.credits != credits or not gs.held_xp_certificates(HOST).is_empty():
			return "A forged record pays nothing."
		return "")


## An ask once given is the day's, though what is open changes after.
func test_a_held_ask_is_not_picked_again_when_the_pool_changes() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var dailies: Array[Dictionary] = QuestEngine.daily_quests()
		var with_block: GameStateScript = _farm()
		if not _find_block(with_block):
			return "The test needs a block."
		# A day on which a block in the pool would change the pick.
		var day: int = 0
		for d: int in range(1, 60):
			if QuestEngine.pick_daily(gs, dailies, HOST, d) != QuestEngine.pick_daily(with_block, dailies, HOST, d):
				day = d
				break
		if day == 0:
			return "The test needs a day on which the block changes the pick."
		_morning(gs, day)
		var held: Array[String] = _held(gs)
		var given: Dictionary = _entry(gs, held[0]).duplicate(true)
		if held != [str(QuestEngine.pick_daily(with_block, dailies, HOST, day)["id"])] and not _find_block(gs):
			return "The test needs a block."
		if str(QuestEngine.pick_daily(gs, dailies, HOST, day)["id"]) == held[0]:
			return "The pool did not change the pick; the test shows nothing."
		# Looks of every kind, and a save and a load: the ask held is the one given.
		gs.update_quests()
		_after(gs)
		var back: GameStateScript = _farm(1)
		if back.farm_from_dict(str_to_var(var_to_str(gs.farm_to_dict()))) != "":
			return "The farm must load."
		back.update_quests()
		for farm: GameStateScript in [gs, back]:
			if _held(farm) != held or _entry(farm, held[0]) != given or str(QuestEngine.daily_ask(farm, HOST)["id"]) != held[0]:
				return "The ask given in the morning stays: %s, was %s" % [farm.player_quest_state, held]
		return "" if _lines(gs, ASK) == 1 else "And nothing new is asked.")
