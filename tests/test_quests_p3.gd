extends RefCounted
## Quest P3, The Missing Blocks (build order step 15 of
## docs/design/quests_levels_story.md): offered at Earthworks 5 or with two
## blocks found, three more blocks, a check against a block, a stack wrung to
## the length Orin names, and the pay, once: Earthworks XP, a quest point and a
## keepsake that gives no power. GameClock, the session's players and the guest
## flag are put back; every node is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const P3: String = "missing_blocks"
const CASE: String = "felt_lined_case"
const SKILL: String = "earthworks"
const BUILD: StringName = &"build_block_stack"
const CHECK: StringName = &"check_with_block"
const XP: int = 150
const SEED: int = 77
const OFFER: String = "Those blocks you keep turning up"
const DONE: String = "QUEST DONE: The Missing Blocks. Reward: 150 Earthworks XP, 1 quest point, a keepsake (Felt-lined case)."
const ORIN_DONE: String = "That is a length, and it holds."
const ORIN_REFERENCE: String = "You wrung that like someone"
const BONUS: String = "QUEST BONUS"

var _nodes: Array[Node] = []


## Runs `body` with the host's commands on a new farm that has P3 as its only
## quest (or `fixtures`).
func _run(body: Callable, fixtures: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	var mine: Dictionary = {}
	for quest: Dictionary in (fixtures if not fixtures.is_empty() else [_shipped().duplicate(true)]):
		mine[StringName(str(quest["id"]))] = quest
	table["quests"] = mine
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	var commands: Node = CommandsScript.new()
	commands.state = _farm()
	_nodes.append(commands)
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(commands)
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.reset_credibility()
	_nodes.append(gs)
	return gs


func _shipped() -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest["id"]) == P3:
			return quest
	return {}


func _lines(gs: Node, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _entry(gs: Node, player: String = HOST) -> Dictionary:
	return (gs.player_quest_state.get(player, {}) as Dictionary).get(P3, {})


func _steps(gs: Node, player: String = HOST) -> Array:
	return _entry(gs, player).get("steps_done", [])


func _is_done(gs: Node, player: String = HOST) -> bool:
	return int(_entry(gs, player).get("done", -1)) >= 0


## The morning of `day`: quests are offered.
func _morning(gs: Node, day: int = 2) -> void:
	GameClock.elapsed_days = float(day - 1)
	gs.update_quests()


## Digs up `count` more reference blocks as `player`, and lets the quests look.
func _dig_blocks(gs: Node, count: int, player: String = HOST) -> void:
	var none: Dictionary[Vector2i, int] = {}
	var left: int = count
	for x: int in range(-40, 40):
		for z: int in range(-40, 40):
			var cell := Vector2i(x, z)
			if left <= 0 or gs.found_blocks.has(cell):
				continue
			if Terrain.dig_problem(cell, gs.dug) != "" or Terrain.dig_problem(cell, none) != "" or ReferenceBlock.at(gs.world_seed, cell).is_empty():
				continue
			var before: int = gs.found_blocks.size()
			gs.dig(Vector3i(cell.x, 0, cell.y), player)
			if gs.found_blocks.size() > before:
				left -= 1
	gs.update_quests([] as Array[String], false)


## Two blocks found, and the morning that offers P3.
func _accept(gs: Node) -> void:
	_dig_blocks(gs, 2)
	_morning(gs)


## P3 from its offer to its last step, the stack built with `score`. Returns
## what the build answered.
func _play(commands: Node, score: int, player: String = HOST) -> Variant:
	var gs: GameStateScript = commands.state
	if _entry(gs, player).is_empty():
		_accept(gs)
	_dig_blocks(gs, 3, player)
	commands.execute(player, CHECK, [gs.STEERING_ID])
	return _build(commands, player, score)


## Builds today's stack as `player`, having played the length the farm names.
func _build(commands: Node, player: String, score: int) -> Variant:
	var stack: Dictionary = (commands.state as GameStateScript).block_stack_target(player)
	return commands.execute(player, BUILD, [int(stack.get("target", 0)), score])


# --- The data ---------------------------------------------------------------------

func test_the_shipped_quest_is_p3_as_designed() -> String:
	var quest: Dictionary = _shipped()
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "P3 must be in the data and be sound: %s" % QuestEngine.data_problem(quest)
	if quest["giver"] != "orin" or quest["scope"] != "player" or quest["kind"] != "personal":
		return "P3 is Old Orin's, and each player's own."
	if quest["any_gate"] != [{ "skill": { "id": SKILL, "level": 5.0 } }, { "found_blocks": 2.0 }]:
		return "P3 opens at Earthworks 5 or with two blocks found: %s" % [quest["any_gate"]]
	var ids: Array = []
	for step: Dictionary in quest["steps"]:
		ids.append(step["id"])
	if ids != ["find", "check", "stack"] or bool(quest.get("any_order", false)):
		return "P3's steps are find, check and stack, in order: %s" % [ids]
	var last: Dictionary = quest["steps"][2]
	if last.get("minigame") != MinigameScore.WRING_THE_BLOCKS or not QuestEngine.is_stack_step(last):
		return "The last step is built with Wring the Blocks."
	# Earthworks XP, a quest point and the case: no credits, and nothing with power.
	var rewards: Dictionary = quest["rewards"]
	var keys: Array = rewards.keys()
	keys.sort()
	if keys != ["keepsake", "phone", "quest_points", "xp_earthworks"] or int(rewards["quest_points"]) != 1 or rewards["keepsake"] != CASE:
		return "P3 pays Earthworks XP, 1 quest point and a keepsake: %s" % [rewards]
	if QuestEngine.keepsake_name(CASE) != "Felt-lined case" or QuestEngine.keepsake_name("no_such") != "":
		return "The keepsake has a name in the data."
	for line: String in ["offer_line"]:
		if QuestEngine.phone_line(str(quest[line])) == "":
			return "Orin has a line for %s." % line
	if QuestEngine.phone_line(str(rewards["phone"])) == "" or QuestEngine.phone_line(str(last["minigame_line"])) == "":
		return "Orin has a line for the end, and one for a Reference stack."
	return ""


func test_a_keepsake_and_a_wring_step_are_checked() -> String:
	var good: Dictionary = _shipped().duplicate(true)
	var cases: Array = []
	var odd: Dictionary = good.duplicate(true)
	odd["rewards"]["keepsake"] = "no_such_thing"
	cases.append(odd)
	odd = good.duplicate(true)
	odd["rewards"]["keepsake"] = 3
	cases.append(odd)
	# A farm's quest is done once for everyone: its keepsake would be nobody's.
	odd = good.duplicate(true)
	odd["scope"] = "farm"
	cases.append(odd)
	odd = good.duplicate(true)
	odd["closed_when"] = { "quest_done": "other" }
	cases.append(odd)
	# Wring the Blocks is the build itself: on no other kind of step.
	odd = good.duplicate(true)
	odd["steps"][2]["counter"] = "till"
	cases.append(odd)
	odd = good.duplicate(true)
	odd["steps"][1]["minigame"] = MinigameScore.WRING_THE_BLOCKS
	cases.append(odd)
	odd = good.duplicate(true)
	odd["steps"][2]["minigame"] = "no_such_game"
	cases.append(odd)
	for quest: Dictionary in cases:
		if QuestEngine.data_problem(quest) == "":
			return "This quest must be refused: %s" % [quest]
	return ""


# --- The gates --------------------------------------------------------------------

func test_it_is_not_offered_before_either_gate() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_morning(gs)
		_dig_blocks(gs, 1)
		gs.player_skill_xp[HOST] = { SKILL: gs.xp_for_level(5) - 1 }
		_morning(gs, 3)
		if not _entry(gs).is_empty() or _lines(gs, OFFER) != 0:
			return "One block and Earthworks 4 is neither gate: %s" % [gs.player_quest_state]
		return "")


func test_two_blocks_found_open_it() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_dig_blocks(gs, 2)
		if gs.skill_level(SKILL, HOST) >= 5 or not _entry(gs).is_empty():
			return "Two finds are not Earthworks 5, and nothing is offered between mornings."
		_morning(gs)
		if _entry(gs).is_empty() or _lines(gs, OFFER) != 1 or not _steps(gs).is_empty():
			return "With two blocks found the morning brings P3: %s %s" % [gs.player_quest_state, gs.phone_log]
		_morning(gs, 3)
		return "" if _lines(gs, OFFER) == 1 else "It is offered once.")


func test_earthworks_5_opens_it() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		gs.player_skill_xp[HOST] = { SKILL: gs.xp_for_level(5) }
		_morning(gs)
		if not gs.found_blocks.is_empty() or _entry(gs).is_empty() or _lines(gs, OFFER) != 1:
			return "At Earthworks 5 the morning brings P3 with no block found: %s" % [gs.player_quest_state]
		return "")


# --- The steps --------------------------------------------------------------------

func test_three_more_blocks_do_the_first_step() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_accept(gs)
		# The two that opened it are not "more".
		gs.update_quests([] as Array[String], false)
		if not _steps(gs).is_empty():
			return "The blocks found before Orin asked don't count: %s" % [_entry(gs)]
		_dig_blocks(gs, 2)
		if not _steps(gs).is_empty() or _lines(gs, "QUEST The Missing Blocks: 2 of 3.") != 1:
			return "Two more is two of three: %s" % [gs.phone_log]
		# A check now is not the next step's: that step is not open yet.
		commands.execute(HOST, CHECK, [gs.STEERING_ID])
		_dig_blocks(gs, 1)
		if _steps(gs) != ["find"] or gs.found_blocks.size() != 5:
			return "The third does the step, and only it: %s" % [_entry(gs)]
		return "")


func test_a_check_of_any_instrument_does_the_second_step() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_accept(gs)
		_dig_blocks(gs, 3)
		# A build now is not the last step's.
		_build(commands, HOST, 100)
		if _steps(gs) != ["find"]:
			return "A stack built early does no step: %s" % [_entry(gs)]
		var readings: String = var_to_str(gs.farm_to_dict()["sensors"]) if gs.farm_to_dict().has("sensors") else ""
		var answer: Variant = commands.execute(HOST, CHECK, [gs.STEERING_ID])
		if not answer is Dictionary or answer.get("refused", false) or _steps(gs) != ["find", "check"]:
			return "A check of an instrument against a block does the step: %s %s" % [answer, _entry(gs)]
		if gs.farm_to_dict().has("sensors") and var_to_str(gs.farm_to_dict()["sensors"]) != readings:
			return "A check changes no instrument."
		if _is_done(gs):
			return "The stack is still to build."
		return "")


func test_the_named_length_is_built_from_blocks_held() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		if not gs.block_stack_target(HOST).is_empty():
			return "With no blocks there is no length."
		var refused: Variant = _build(commands, HOST, 100)
		if not refused is Dictionary or not refused.get("refused", false) or gs.action_count(gs.BLOCK_STACK_COUNT, HOST) != 0:
			return "A stack takes two blocks: %s" % [refused]
		_dig_blocks(gs, 5)
		var held: Dictionary = gs.gauge_pieces()
		if held.size() < 2:
			return "The test's farm needs two pieces of the set: %s" % [held]
		var stack: Dictionary = gs.block_stack_target(HOST)
		var sum: int = 0
		for index: int in stack["sizes"]:
			if not held.has(index):
				return "Orin names a length made of pieces the farm holds: %s of %s" % [stack, held.keys()]
			sum += GaugeSet.SIZES_TEN_THOUSANDTHS[index]
		if sum != int(stack["target"]) or (stack["sizes"] as Array).size() < 2:
			return "The length is the sum of its pieces: %s" % [stack]
		# The same for the day, and the guest's screen gets the host's answer.
		if gs.block_stack_target(HOST) != stack:
			return "The length is the day's."
		var guest: GameStateScript = _farm()
		guest.local_player_id = "player_2"
		FarmCommands.guest = true
		var problem: String = FarmSync.join(FarmSync.capture(gs), guest)
		var same: bool = guest.block_stack_target(HOST) == stack and guest.block_stack_target("player_2") == gs.block_stack_target("player_2")
		FarmCommands.guest = false
		if problem != "" or not same:
			return "A guest's copy of the farm names the same length. %s" % problem
		# No ask of Orin's is open here, so the host takes no score with the build.
		var answer: Variant = _build(commands, HOST, 250)
		if not answer is Dictionary or int(answer.get("target", 0)) != sum or answer.get("sizes") != stack["sizes"] or int(answer.get("score", 0)) != MinigameScore.SKIPPED or answer.has("changed"):
			return "The build answers with the length and its pieces, and no score outside a quest: %s" % [answer]
		if int(gs.build_block_stack(sum, 250, HOST).get("score", 0)) != 100:
			return "The farm cuts a score to 100 at most."
		# The manager is no player: nothing is counted for it.
		gs.build_block_stack(sum, 90, gs.MANAGER_ID)
		return "" if gs.action_count(gs.BLOCK_STACK_COUNT, HOST) == 2 and not gs.action_counts.has(gs.MANAGER_ID) else "A build is counted for the player who did it.")


func test_a_build_changes_nothing_but_its_count() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_dig_blocks(gs, 5)
		var before: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		var log: int = gs.phone_log.size()
		_build(commands, HOST, 100)
		var after: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		for key: Variant in after:
			if str(key) != "action_counts" and var_to_str(after[key]) != var_to_str(before.get(key)):
				return "A stack, however well wrung, changes no reading, log, block or pay: %s changed." % key
		if gs.phone_log.size() != log or gs.skill_xp(SKILL, HOST) != int((before["player_skill_xp"] as Dictionary).get(HOST, {}).get(SKILL, 0)):
			return "A build with no quest step gives no XP and says nothing."
		return gs.farm_dict_problem(after))


# --- The pay ----------------------------------------------------------------------

func test_the_stack_ends_the_quest_and_pays_once() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_accept(gs)
		_dig_blocks(gs, 3)
		commands.execute(HOST, CHECK, [gs.STEERING_ID])
		var xp: int = gs.skill_xp(SKILL, HOST)
		var credits: int = gs.credits
		if not QuestEngine.keepsakes_of(gs, HOST).is_empty() or gs.quest_point_total(HOST) != 0:
			return "Nothing is paid before the last step."
		var answer: Variant = _build(commands, HOST, 70)
		if not answer is Dictionary or answer.get("refused", false) or not _is_done(gs):
			return "The stack is the last step: %s %s" % [answer, _entry(gs)]
		if gs.skill_xp(SKILL, HOST) != xp + XP or gs.quest_point_total(HOST) != 1 or gs.credits != credits:
			return "P3 pays %d Earthworks XP and 1 quest point, and no credits: %d XP, %d points." % [XP, gs.skill_xp(SKILL, HOST) - xp, gs.quest_point_total(HOST)]
		if QuestEngine.keepsakes_of(gs, HOST) != [CASE]:
			return "The felt-lined case is the player's: %s" % [QuestEngine.keepsakes_of(gs, HOST)]
		if _lines(gs, DONE) != 1 or _lines(gs, ORIN_DONE) != 1 or _lines(gs, BONUS) != 0 or _lines(gs, ORIN_REFERENCE) != 0:
			return "The phone says it is done and what it paid, and Orin has his word: %s" % [gs.phone_log]
		# Good (60 to 79) is done with no bonus; and nothing is paid twice.
		_build(commands, HOST, 100)
		commands.execute(HOST, CHECK, [gs.STEERING_ID])
		_dig_blocks(gs, 1)
		_morning(gs, 3)
		_morning(gs, 4)
		if gs.skill_xp(SKILL, HOST) - xp - XP != 5 + 25 or gs.quest_point_total(HOST) != 1 or _lines(gs, DONE) != 1 or _lines(gs, OFFER) != 1 or _lines(gs, BONUS) != 0:
			return "A done quest is not paid or offered again: %d XP, %s" % [gs.skill_xp(SKILL, HOST) - xp, gs.phone_log]
		return "" if QuestEngine.keepsakes_of(gs, HOST) == [CASE] else "The case is held once.")


func test_fine_and_reference_add_to_the_xp() -> String:
	var paid: Dictionary = {}
	for score: int in [MinigameScore.SKIPPED, 59, 60, 79, 80, 94, 95, 100]:
		var problem: String = _run(func(commands: Node) -> String:
			var gs: GameStateScript = commands.state
			_accept(gs)
			_dig_blocks(gs, 3)
			commands.execute(HOST, CHECK, [gs.STEERING_ID])
			var xp: int = gs.skill_xp(SKILL, HOST)
			_build(commands, HOST, score)
			if not _is_done(gs):
				return "A stack scored %d does the step." % score
			paid[score] = [gs.skill_xp(SKILL, HOST) - xp, _lines(gs, BONUS), _lines(gs, ORIN_REFERENCE), _lines(gs, ORIN_DONE),
				_entry(gs).get("scores", {}), gs.quest_point_total(HOST), QuestEngine.keepsakes_of(gs, HOST)]
			return "")
		if problem != "":
			return problem
	var plain: Array = [XP, 0, 0, 1, {}, 1, [CASE]]
	if paid[MinigameScore.SKIPPED] != plain or paid[59] != plain:
		return "A skip and a poor try are paid as written, with no score kept: %s, %s" % [paid[MinigameScore.SKIPPED], paid[59]]
	for score: int in [60, 79]:
		if paid[score] != [XP, 0, 0, 1, { "stack": score }, 1, [CASE]]:
			return "Good is done, with no bonus: %s" % [paid[score]]
	for score: int in [80, 94]:
		if paid[score] != [XP + 15, 1, 0, 1, { "stack": score }, 1, [CASE]]:
			return "Fine adds 10 %% to the XP: %s" % [paid[score]]
	for score: int in [95, 100]:
		if paid[score] != [XP + 30, 1, 1, 1, { "stack": score }, 1, [CASE]]:
			return "Reference adds 20 %% and Orin's line: %s" % [paid[score]]
	return ""


func test_the_bonus_line_names_the_xp() -> String:
	return _run(func(commands: Node) -> String:
		_play(commands, 96)
		var gs: GameStateScript = commands.state
		return "" if _lines(gs, "QUEST BONUS: The Missing Blocks, played to REFERENCE. 30 Earthworks XP more.") == 1 else "The bonus is said: %s" % [gs.phone_log])


func test_a_poor_try_is_exactly_a_skip() -> String:
	var farms: Array = []
	for score: int in [MinigameScore.SKIPPED, 0, 59]:
		var problem: String = _run(func(commands: Node) -> String:
			var gs: GameStateScript = commands.state
			var answer: Variant = _play(commands, score)
			if not answer is Dictionary or not _is_done(gs):
				return "A stack scored %d ends the quest." % score
			farms.append(var_to_str(gs.farm_to_dict()))
			return "")
		if problem != "":
			return problem
	return "" if farms[0] == farms[1] and farms[0] == farms[2] else "A poor try must leave the very farm a skip does."


# --- Saves ------------------------------------------------------------------------

func test_it_is_saved_under_way_and_done() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_accept(gs)
		_dig_blocks(gs, 3)
		commands.execute(HOST, CHECK, [gs.STEERING_ID])
		var saved: Dictionary = str_to_var(var_to_str(gs.farm_to_dict()))
		var back: GameStateScript = _farm()
		if back.farm_dict_problem(saved) != "" or back.farm_from_dict(saved) != "":
			return "A farm with P3 under way must load: %s" % back.farm_dict_problem(saved)
		if var_to_str(back.player_quest_state) != var_to_str(gs.player_quest_state) or back.block_stack_target(HOST) != gs.block_stack_target(HOST):
			return "The loaded farm holds P3 where it stood, and names the same length."
		var log: int = back.phone_log.size()
		back.update_quests()
		if _steps(back) != ["find", "check"] or back.phone_log.size() != log:
			return "A load does no step and says nothing again: %s" % [_entry(back)]
		# It goes on from the file, the stack's score with it.
		commands.state = back
		var xp: int = back.skill_xp(SKILL, HOST)
		_build(commands, HOST, 85)
		if not _is_done(back) or back.skill_xp(SKILL, HOST) != xp + XP + 15:
			return "The loaded quest is finished and paid with its bonus: %s" % [_entry(back)]
		var done: Dictionary = str_to_var(var_to_str(back.farm_to_dict()))
		var again: GameStateScript = _farm()
		if again.farm_dict_problem(done) != "" or again.farm_from_dict(done) != "":
			return "A farm with P3 done must load: %s" % again.farm_dict_problem(done)
		again.update_quests()
		commands.state = again
		_build(commands, HOST, 100)
		if again.skill_xp(SKILL, HOST) != xp + XP + 15 or again.quest_point_total(HOST) != 1 or QuestEngine.keepsakes_of(again, HOST) != [CASE]:
			return "After a load the quest is done, paid once, and the case is held."
		# Nothing new is saved for the case or the build: the quest and a count.
		if done.keys() != str_to_var(var_to_str(_farm().farm_to_dict())).keys():
			return "P3 adds no field to the farm's file."
		return "")


# --- Co-op ------------------------------------------------------------------------

func test_a_guest_has_their_own_p3() -> String:
	return _run(func(commands: Node) -> String:
		var host: GameStateScript = commands.state
		_dig_blocks(host, 2)
		_morning(host)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		# The blocks are the farm's: found by the host, they open it for the guest too.
		if _entry(host, id).is_empty() or _entry(host).is_empty() or _lines(host, OFFER) != 2:
			return "Each player is offered their own P3: %s" % [host.player_quest_state]
		# Three more, whoever digs them, are three more for both.
		_dig_blocks(host, 2, id)
		_dig_blocks(host, 1, HOST)
		if _steps(host, id) != ["find"] or _steps(host) != ["find"]:
			return "The farm's finds do the first step for both: %s" % [host.player_quest_state]
		# The check and the stack are a player's own.
		commands.execute(id, CHECK, [host.STEERING_ID])
		if _steps(host, id) != ["find", "check"] or _steps(host) != ["find"]:
			return "The guest's check is the guest's step: %s" % [host.player_quest_state]
		_build(commands, HOST, 100)
		if _is_done(host, id) or _is_done(host) or not (_entry(host, id).get("scores", {}) as Dictionary).is_empty():
			return "The host's stack does not do the guest's step, or give it a score."
		if host.block_stack_target(id) == host.block_stack_target(HOST) and host.gauge_pieces().size() > 3:
			return "Each player is named a length of their own."
		var host_xp: int = host.skill_xp(SKILL, HOST)
		var guest_xp: int = host.skill_xp(SKILL, id)
		var answer: Variant = _build(commands, id, 97)
		if not answer is Dictionary or answer.get("refused", false) or not _is_done(host, id) or _is_done(host):
			return "The guest's stack ends the guest's quest alone: %s %s" % [answer, host.player_quest_state]
		if host.skill_xp(SKILL, id) != guest_xp + XP + 30 or host.skill_xp(SKILL, HOST) != host_xp:
			return "The guest is paid, with the bonus, and the host is not."
		if host.quest_point_total(id) != 1 or host.quest_point_total(HOST) != 0 or QuestEngine.keepsakes_of(host, id) != [CASE] or not QuestEngine.keepsakes_of(host, HOST).is_empty():
			return "The point and the case are the guest's."
		if _lines(host, DONE) != 1 or _lines(host, ORIN_REFERENCE) != 1:
			return "It is said once: %s" % [host.phone_log]
		# The guest's screen: the farm as it reaches them says the same.
		var guest: GameStateScript = _farm()
		guest.local_player_id = id
		FarmCommands.guest = true
		var problem: String = FarmSync.join(FarmSync.capture(host), guest)
		var seen: bool = QuestEngine.keepsakes_of(guest, id) == [CASE] and var_to_str(guest.player_quest_state) == var_to_str(host.player_quest_state)
		FarmCommands.guest = false
		if problem != "" or not seen:
			return "The guest's copy holds their done quest and their case. %s" % problem
		# The host's own goes on, and is saved with the guest's.
		commands.execute(HOST, CHECK, [host.STEERING_ID])
		_build(commands, HOST, 10)
		if not _is_done(host) or host.skill_xp(SKILL, HOST) != host_xp + XP or host.skill_xp(SKILL, id) != guest_xp + XP + 30:
			return "The host's own P3 is paid to the host, as written."
		var saved: Dictionary = str_to_var(var_to_str(host.farm_to_dict()))
		var back: GameStateScript = _farm()
		if back.farm_dict_problem(saved) != "" or back.farm_from_dict(saved) != "":
			return "A farm with a guest's P3 must load: %s" % back.farm_dict_problem(saved)
		return "" if QuestEngine.keepsakes_of(back, id) == [CASE] and QuestEngine.keepsakes_of(back, HOST) == [CASE] else "Both hold a case after a load.")


func test_a_done_p3_and_its_case_travel() -> String:
	return _run(func(commands: Node) -> String:
		var a: GameStateScript = commands.state
		_play(commands, 100)
		var there: Dictionary = QuestEngine.travelling(a, HOST)
		if there.get(P3, {}).get("done") != true:
			return "A done P3 travels as done: %s" % [there]
		# On a friend's farm it is done, the case with it, and nothing is paid again.
		var b: GameStateScript = _farm()
		_dig_blocks(b, 2)
		var id: String = b.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record().merged({ "quests": there }, true))
		var present: Array[String] = [HOST, id]
		b.update_quests(present)
		if id == "" or not _is_done(b, id) or QuestEngine.keepsakes_of(b, id) != [CASE]:
			return "The friend arrives with P3 done and the case: %s" % [b.player_quest_state]
		if b.skill_xp(SKILL, id) != 0 or b.quest_point_total(id) > 1 or _lines(b, DONE) != 0:
			return "Nothing is paid for it on the second farm: %d XP, %s" % [b.skill_xp(SKILL, id), b.phone_log]
		# One under way comes with its steps, not its score.
		var c: GameStateScript = _farm()
		commands.state = c
		_accept(c)
		_dig_blocks(c, 3)
		commands.execute(HOST, CHECK, [c.STEERING_ID])
		var part: Dictionary = QuestEngine.travelling(c, HOST)
		if part.get(P3, {}).get("done") != false or part[P3]["steps"] != ["find", "check"]:
			return "P3 under way travels with its steps: %s" % [part]
		var d: GameStateScript = _farm()
		var id_d: String = d.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record().merged({ "quests": part }, true))
		d.update_quests([HOST, id_d] as Array[String])
		if _steps(d, id_d) != ["find", "check"] or _is_done(d, id_d) or not QuestEngine.keepsakes_of(d, id_d).is_empty():
			return "It is taken up where it stood, with no case yet: %s" % [d.player_quest_state]
		return "")


# --- What the host takes from the sender ------------------------------------------

func test_a_score_sent_with_no_open_step_is_not_kept() -> String:
	return _run(func(commands: Node) -> String:
		var host: GameStateScript = commands.state
		_dig_blocks(host, 2)
		_morning(host)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		_dig_blocks(host, 3, id)
		if _steps(host, id) != ["find"] or QuestEngine.has_minigame_step(host, MinigameScore.WRING_THE_BLOCKS, "", id):
			return "The test's guest has P3 with its stack step not yet open: %s" % [_entry(host, id)]
		# A guest's PC sends 100 with the step not open: the build is a skip.
		var xp: int = host.skill_xp(SKILL, id)
		var early: Variant = _build(commands, id, 100)
		if not early is Dictionary or early.get("refused", false) or int(early.get("score", 0)) != MinigameScore.SKIPPED:
			return "With no open step the host answers a skip, whatever was sent: %s" % [early]
		if not (_entry(host, id).get("scores", {}) as Dictionary).is_empty() or _steps(host, id) != ["find"] or host.skill_xp(SKILL, id) != xp:
			return "Nothing is kept of a score sent with no open step: %s" % [_entry(host, id)]
		# With the step open the same call is taken; here the guest skips, and
		# nothing of the early 100 is found in the pay.
		commands.execute(id, CHECK, [host.STEERING_ID])
		if not QuestEngine.has_minigame_step(host, MinigameScore.WRING_THE_BLOCKS, "", id) or QuestEngine.has_minigame_step(host, MinigameScore.WRING_THE_BLOCKS, "", HOST):
			return "The stack step is open for the guest alone."
		_build(commands, id, MinigameScore.SKIPPED)
		if not _is_done(host, id) or host.skill_xp(SKILL, id) != xp + XP or _lines(host, BONUS) != 0 or not (_entry(host, id).get("scores", {}) as Dictionary).is_empty():
			return "The early score gives no grade later: %d XP, %s" % [host.skill_xp(SKILL, id) - xp, _entry(host, id)]
		return "")


func test_a_length_played_across_0600_is_a_skip() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_accept(gs)
		_dig_blocks(gs, 3)
		commands.execute(HOST, CHECK, [gs.STEERING_ID])
		# The player opens the game on one day and ends it after 06:00 of another.
		var played: int = int(gs.block_stack_target(HOST)["target"])
		var day: int = GameClock.get_day_index()
		for later: int in range(1, 20):
			GameClock.elapsed_days += 1.0
			if int(gs.block_stack_target(HOST)["target"]) != played:
				break
		var today: int = int(gs.block_stack_target(HOST)["target"])
		if today == played or GameClock.get_day_index() == day:
			return "The test needs a day that names another length."
		var xp: int = gs.skill_xp(SKILL, HOST)
		var answer: Variant = commands.execute(HOST, BUILD, [played, 100])
		if not answer is Dictionary or answer.get("refused", false) or not answer.get("changed", false):
			return "The host says the length changed: %s" % [answer]
		if int(answer["target"]) != today or int(answer["score"]) != MinigameScore.SKIPPED:
			return "Today's length is built, and the score is a skip's: %s" % [answer]
		if not _is_done(gs) or gs.skill_xp(SKILL, HOST) != xp + XP or _lines(gs, BONUS) != 0 or not (_entry(gs).get("scores", {}) as Dictionary).is_empty():
			return "A build of a changed length does the step as a skip does: %d XP, %s" % [gs.skill_xp(SKILL, HOST) - xp, _entry(gs)]
		# The length played and today's the same: the score is taken.
		var same: Dictionary = gs.build_block_stack(today, 88, HOST)
		return "" if int(same.get("score", 0)) == 88 and not same.has("changed") else "The same length is no change: %s" % [same])


func test_a_find_mid_game_changes_the_length_plainly() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		_accept(gs)
		_dig_blocks(gs, 3)
		commands.execute(HOST, CHECK, [gs.STEERING_ID])
		var played: int = int(gs.block_stack_target(HOST)["target"])
		# Blocks dug by another while the game is open, until the length is another.
		for more: int in 12:
			_dig_blocks(gs, 1)
			if int(gs.block_stack_target(HOST)["target"]) != played:
				break
		if int(gs.block_stack_target(HOST)["target"]) == played:
			return ""  # this seed's finds never moved it: nothing to show
		var answer: Variant = commands.execute(HOST, BUILD, [played, 100])
		return "" if answer is Dictionary and answer.get("changed", false) and int(answer["score"]) == MinigameScore.SKIPPED and _lines(gs, BONUS) == 0 else "A find mid-game makes the try a skip: %s" % [answer])


func test_a_guest_who_plays_to_reference_gets_the_bonus() -> String:
	return _run(func(commands: Node) -> String:
		var host: GameStateScript = commands.state
		if str(_shipped().get("scope", "")) != QuestEngine.SCOPE_PLAYER:
			return "P3 is a player's own quest."
		_dig_blocks(host, 2)
		_morning(host)
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		_dig_blocks(host, 3, id)
		commands.execute(id, CHECK, [host.STEERING_ID])
		var host_xp: int = host.skill_xp(SKILL, HOST)
		var guest_xp: int = host.skill_xp(SKILL, id)
		var credits: int = host.credits
		var answer: Variant = _build(commands, id, 100)
		if not answer is Dictionary or int(answer.get("score", 0)) != 100 or not _is_done(host, id) or _is_done(host):
			return "The guest's stack ends the guest's P3: %s" % [answer]
		if host.skill_xp(SKILL, id) != guest_xp + XP + 30:
			return "The guest who played gets the XP and Reference's 20 %% more: %d" % [host.skill_xp(SKILL, id) - guest_xp]
		if host.skill_xp(SKILL, HOST) != host_xp or host.credits != credits or host.quest_point_total(HOST) != 0:
			return "The host gets nothing of the guest's quest: %d XP" % [host.skill_xp(SKILL, HOST) - host_xp]
		if _entry(host, id).get("scores", {}) != { "stack": 100 } or not (_entry(host).get("scores", {}) as Dictionary).is_empty():
			return "The score is kept with the guest's quest alone: %s" % [host.player_quest_state]
		return "" if _lines(host, "QUEST BONUS: The Missing Blocks, played to REFERENCE. 30 Earthworks XP more.") == 1 and _lines(host, ORIN_REFERENCE) == 1 else "The bonus is said once: %s" % [host.phone_log])
