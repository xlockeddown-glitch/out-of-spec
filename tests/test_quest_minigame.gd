extends RefCounted
## A quest step that carries a mini-game (docs/design/quests_levels_story.md
## sections 7.2 and 7.4, build step 11 part 2): quest S1's calibration step
## opens Set the Zero at the bench, on an old farm too, a skip or a poor try
## does the step exactly as a plain calibration does, and a score that earned a
## grade is kept with the step and paid when the quest is.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const S1: String = "thirsty_probe"
const GAME: String = "set_the_zero"
const PROBE: String = "soil_probe"
const BENCH: StringName = &"calibrate_at_bench"
const BONUS_LINE: String = "QUEST BONUS"
const DONE_LINE: String = "QUEST DONE: The Thirsty Probe. Reward: 150 CR, 1 quest point, an XP certificate (200 XP)."
const LIN_DONE: String = "LIN: Your probe is lying to you. Was. Better."
const LIN_REFERENCE: String = "LIN: I checked your zero against my own scale."


## Runs `body` with the host's commands on a new farm. `fixtures` replace the
## shipped quests if given.
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
	var commands: Node = CommandsScript.new()
	commands.state = _farm()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(commands)
	commands.state.free()
	commands.free()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	return gs


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


## The morning of day 2: S1 is offered and accepted, its kit step done.
func _accept(gs: GameStateScript) -> Dictionary:
	GameClock.elapsed_days = 1.0
	gs.update_quests()
	return gs.quest_state.get(S1, {})


## Sells Lin one crate of in-spec dust turnip and lets the quests look. Returns
## what the farm gained over the sale itself.
func _sell(gs: GameStateScript) -> int:
	var before: int = gs.credits
	gs.harvest_bin.append({ "crop_id": "dust_turnip", "in_spec": true })
	var sale: int = gs.sell_harvest_to_lin(HOST)
	gs.update_quests()
	return gs.credits - before - sale


## S1 from its offer to its pay, the soil probe calibrated at the bench with
## `tail` after the command's own argument (nothing: a skip). Returns the
## quest's entry, what it paid over the sale, and the phone's lines.
func _play_s1(commands: Node, tail: Array) -> Dictionary:
	var gs: GameStateScript = commands.state
	var entry: Dictionary = _accept(gs)
	var answer: Variant = commands.execute(HOST, BENCH, [PROBE] + tail)
	var after_cal: Dictionary = entry.duplicate(true)
	var paid: int = _sell(gs)
	return { "answer": answer, "after_cal": after_cal, "entry": entry.duplicate(true), "paid": paid,
		"credits": gs.credits, "log": gs.phone_log.duplicate(),
		"bonus_lines": _lines(gs, BONUS_LINE), "done_lines": _lines(gs, DONE_LINE),
		"lin_done": _lines(gs, LIN_DONE), "lin_reference": _lines(gs, LIN_REFERENCE) }


# --- The step opens the game ----------------------------------------------------

func test_the_open_step_is_a_key_moment_on_an_old_farm() -> String:
	return _run(_check_old_farm)


func _check_old_farm(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	# Day 1, before S1: the lab calibrates its soil probe by hand, with no game.
	var first: Variant = commands.execute(HOST, BENCH, [PROBE])
	if not first is Dictionary or not first.has("as_left"):
		return "The test's first calibration did not happen: %s" % [first]
	if MinigameScore.is_due(gs, PROBE, HOST, false) or MinigameScore.may_count(gs, PROBE, HOST) \
			or QuestEngine.has_minigame_step(gs, GAME, PROBE, HOST):
		return "With no quest, a kind the lab has calibrated before is no key moment."
	var entry: Dictionary = _accept(gs)
	if entry.is_empty() or entry["steps_done"] != ["kit"]:
		return "S1 is accepted on day 2 with its calibration step open: %s" % [entry]
	if not QuestEngine.has_minigame_step(gs, GAME, PROBE, HOST) or not QuestEngine.has_minigame_step(gs, GAME, PROBE, GUEST):
		return "S1's open calibration step carries the game for the soil probe, for every player."
	if QuestEngine.has_minigame_step(gs, GAME, gs.HYGROMETER_ID, HOST) or QuestEngine.has_minigame_step(gs, "no_such_game", PROBE, HOST) \
			or QuestEngine.has_minigame_step(gs, GAME, "", HOST):
		return "The step is for its own game and its own instrument only."
	if not MinigameScore.is_due(gs, PROBE, HOST, false) or not MinigameScore.may_count(gs, PROBE, GUEST):
		return "The open step makes the calibration a key moment on an old farm: the game opens and its score may count."
	# A guest has the host's quest state and no more: the same answer there.
	var guest: GameStateScript = _farm()
	var problem: String = guest.farm_from_dict(gs.farm_to_dict())
	FarmCommands.guest = true
	var on_guest: bool = problem == "" and MinigameScore.is_due(guest, PROBE, GUEST, false)
	FarmCommands.guest = false
	guest.free()
	if not on_guest:
		return "A guest's copy of the farm opens the game for the step too: %s" % problem
	# The score is counted, and kept with the step.
	var answer: Variant = commands.execute(GUEST, BENCH, [PROBE, 97])
	if not answer is Dictionary or int(answer.get(MinigameScore.RECORD_KEY, -1)) != 97:
		return "The host counts the score of the step's calibration: %s" % [answer]
	if entry["steps_done"] != ["kit", "cal"] or entry.get(QuestEngine.SCORES) != { "cal": 97 }:
		return "The calibration does the step and its score is kept: %s" % [entry]
	if QuestEngine.has_minigame_step(gs, GAME, PROBE, HOST) or MinigameScore.is_due(gs, PROBE, HOST, false):
		return "Once the step is done the soil probe is no key moment again."
	# The host's snapshot carries the kept score, and the guest reads the same.
	var late: GameStateScript = _farm()
	var bytes: PackedByteArray = FarmSync.capture(gs)
	FarmCommands.guest = true
	var join_problem: String = FarmSync.join(bytes, late)
	FarmCommands.guest = false
	var late_entry: Dictionary = late.quest_state.get(S1, {})
	var same: bool = join_problem == "" and late_entry.get(QuestEngine.SCORES) == { "cal": 97 } \
		and not QuestEngine.has_minigame_step(late, GAME, PROBE, GUEST) and not MinigameScore.is_due(late, PROBE, GUEST, false)
	late.free()
	if not same:
		return "A guest takes a snapshot with a kept score, and the game is no longer due there: %s %s" % [join_problem, late_entry]
	if SessionScript.PROTOCOL != 26:
		return "An entry may now have `scores`, which a build before refuses: the protocol is 18."
	var stale: Variant = commands.execute(HOST, BENCH, [PROBE, 100])
	if not stale is Dictionary or int(stale.get(MinigameScore.RECORD_KEY, 0)) != MinigameScore.SKIPPED or entry[QuestEngine.SCORES] != { "cal": 97 }:
		return "A later calibration's score counts for nothing and changes no kept score: %s" % [stale]
	return ""


func test_only_the_open_step_of_an_accepted_quest_counts() -> String:
	return _run(_check_open_only, [_fixture("farm"), _fixture("player", "own")])


## A quest with a plain step and then a mini-game step for the steering encoder (a Set the Zero unit).
func _fixture(scope: String, id: String = "two") -> Dictionary:
	return { "id": id, "kind": "story", "giver": "lin", "title": "Test " + id, "scope": scope, "gates": {},
		"steps": [
			{ "id": "pay", "text": "Have 100 CR.", "check": "stat_at_least", "stat": "credits", "at_least": 100 },
			{ "id": "cal", "text": "Calibrate the steering encoder.", "check": "count", "log": "cal_log",
				"where": { "instrument_id": "rover_steering_encoder" }, "minigame": GAME }],
		"rewards": { "credits": 100 } }


func _entry(steps_done: Array, done: int = -1) -> Dictionary:
	return { "accepted": 1, "steps_done": steps_done, "base": {}, "shown": {}, "players": [HOST], "done": done }


func _check_open_only(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	var unit: String = gs.STEERING_ID
	if unit != "rover_steering_encoder":
		return "The test's fixture names the steering encoder by another id than the farm's."
	if QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "A quest not accepted opens nothing."
	gs.quest_state["two"] = _entry([])
	if QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "In a quest done in order, a step behind an open one is not open yet."
	gs.quest_state["two"] = _entry(["pay"])
	if not QuestEngine.has_minigame_step(gs, GAME, unit, HOST) or not QuestEngine.has_minigame_step(gs, GAME, unit, GUEST):
		return "The farm's open step counts for every player."
	gs.quest_state["two"] = _entry(["pay", "cal"])
	if QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "A step that is done opens nothing."
	gs.quest_state["two"] = _entry(["pay"], 3)
	if QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "A quest that is done opens nothing."
	# A player's own quest counts for that player alone.
	gs.quest_state.clear()
	var own: Dictionary = _entry(["pay"])
	own["carried"] = {}
	gs.player_quest_state = { GUEST: { "own": own } }
	if not QuestEngine.has_minigame_step(gs, GAME, unit, GUEST) or QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "A player's own open step counts for that player alone."
	# And keeps only its owner's score.
	var step: Dictionary = _fixture("player", "own")["steps"][1]
	var kept: Dictionary = _entry(["pay", "cal"])
	var mine: Dictionary = { "instrument_id": unit, "traceable": true, "performed_by": GUEST, "programmed_by": "" }
	gs.cal_log.append(mine)
	QuestEngine._keep_score(gs, kept, step, QuestEngine.played_game(GAME, unit, HOST, 100), GUEST)
	QuestEngine._keep_score(gs, kept, step, QuestEngine.played_game(GAME, "soil_probe", GUEST, 100), GUEST)
	QuestEngine._keep_score(gs, kept, step, QuestEngine.played_game("no_such_game", unit, GUEST, 100), GUEST)
	QuestEngine._keep_score(gs, kept, step, QuestEngine.played_game(GAME, unit, GUEST, 59), GUEST)
	QuestEngine._keep_score(gs, kept, step, {}, GUEST)
	if kept.has(QuestEngine.SCORES):
		return "Another player's score, another instrument's, another game's or a poor try keeps nothing: %s" % [kept]
	# The newest row must be the scored calibration: not a robot's, the
	# manager's, another player's, another instrument's or one not traceable.
	for change: Dictionary in [{ "programmed_by": GUEST, "performed_by": "TR-1" }, { "performed_by": MinigameScore.MANAGER },
			{ "performed_by": HOST }, { "instrument_id": "soil_probe" }, { "traceable": false }]:
		gs.cal_log.append(mine.merged(change, true))
		var played: Dictionary = QuestEngine.played_game(GAME, unit, GUEST, 100)
		QuestEngine._keep_score(gs, kept, step, played, GUEST)
		if kept.has(QuestEngine.SCORES) or played.is_empty():
			return "A newest row changed by %s is not the scored calibration: %s" % [change, kept]
	gs.cal_log.clear()
	QuestEngine._keep_score(gs, kept, step, QuestEngine.played_game(GAME, unit, GUEST, 100), GUEST)
	if kept.has(QuestEngine.SCORES):
		return "With no calibration on the log nothing is kept."
	gs.cal_log.append(mine)
	var once: Dictionary = QuestEngine.played_game(GAME, unit, GUEST, 250)
	QuestEngine._keep_score(gs, kept, step, once, GUEST)
	if kept.get(QuestEngine.SCORES) != { "cal": 100 } or not once.is_empty():
		return "The owner's own score is kept, held to 100, and is then used up: %s" % [kept]
	return ""


# --- Any order, a standard, two quests, a player's own ------------------------------

## A quest of one mini-game step for the steering encoder, done as it is calibrated.
func _one_step(id: String, scope: String = "farm") -> Dictionary:
	var quest: Dictionary = _fixture(scope, id)
	(quest["steps"] as Array).remove_at(0)
	return quest


func test_in_any_order_a_step_behind_an_open_one_is_open() -> String:
	var loose: Dictionary = _fixture("farm", "loose")
	loose["any_order"] = true
	return _run(_check_any_order, [loose])


func _check_any_order(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	var unit: String = gs.STEERING_ID
	gs.credits = 0
	GameClock.elapsed_days = 1.0
	gs.update_quests()
	var entry: Dictionary = gs.quest_state.get("loose", {})
	if entry.is_empty() or not entry["steps_done"].is_empty():
		return "The test's quest is accepted with both steps open: %s" % [entry]
	if not QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "In a quest done in any order the mini-game step is open while the first is."
	commands.execute(HOST, BENCH, [unit, 85])
	if entry["steps_done"] != ["cal"] or entry.get(QuestEngine.SCORES) != { "cal": 85 } or int(entry["done"]) >= 0:
		return "The step is done out of order and its score kept: %s" % [entry]
	if QuestEngine.has_minigame_step(gs, GAME, unit, HOST):
		return "Done, it opens nothing, with the other step still open."
	return ""


func test_a_step_for_a_standard_still_needs_careful() -> String:
	return _run(_check_standard, [_one_step("std")])


func _check_standard(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	var standard: String = gs.standard_ids()[0]
	var quest: Dictionary = DataManager.get_record(&"quests", "std", "quests")
	quest["steps"][0]["where"] = { "instrument_id": standard }
	if QuestEngine.data_problem(quest) != "":
		return "The test's quest is right: %s" % QuestEngine.data_problem(quest)
	gs.quest_state["std"] = _entry([])
	if not QuestEngine.has_minigame_step(gs, GAME, standard, HOST):
		return "The test's step is open for the standard."
	if MinigameScore.is_due(gs, standard, HOST, true) or MinigameScore.may_count(gs, standard, HOST):
		return "A quest step does not open the game for a standard without the CAREFUL level."
	return ""


func test_one_calibration_grades_one_quest() -> String:
	return _run(_check_one_quest, [_one_step("first"), _one_step("second")])


func _check_one_quest(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	GameClock.elapsed_days = 1.0
	gs.update_quests()
	if not gs.quest_state.has("first") or not gs.quest_state.has("second"):
		return "The test's two quests are accepted: %s" % [gs.quest_state.keys()]
	var before: int = gs.credits
	commands.execute(HOST, BENCH, [gs.STEERING_ID, 100])
	var first: Dictionary = gs.quest_state["first"]
	var second: Dictionary = gs.quest_state["second"]
	if int(first["done"]) < 0 or int(second["done"]) < 0:
		return "One calibration does the step of both quests: %s %s" % [first, second]
	if first.get(QuestEngine.SCORES) != { "cal": 100 } or second.has(QuestEngine.SCORES):
		return "The score is kept in the first quest only: %s %s" % [first, second]
	if gs.credits != before + 120 + 100 or _lines(gs, BONUS_LINE) != 1:
		return "Two quests of 100 CR pay one bonus of 20 CR, got %d: %s" % [gs.credits - before, gs.phone_log]
	return ""


func test_a_players_own_quest_keeps_its_owners_score() -> String:
	return _run(_check_own_quest, [_one_step("own", "player")])


func _check_own_quest(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	var unit: String = gs.STEERING_ID
	CoopSession.players.assign([HOST, GUEST])
	GameClock.elapsed_days = 1.0
	gs.update_quests()
	var hosts: Dictionary = (gs.player_quest_state.get(HOST, {}) as Dictionary).get("own", {})
	var guests: Dictionary = (gs.player_quest_state.get(GUEST, {}) as Dictionary).get("own", {})
	if hosts.is_empty() or guests.is_empty() or not gs.quest_state.is_empty():
		return "Each player has the quest as their own: %s" % [gs.player_quest_state]
	if not QuestEngine.has_minigame_step(gs, GAME, unit, GUEST) or not MinigameScore.may_count(gs, unit, GUEST):
		return "The guest's own open step is a key moment for the guest."
	var before: int = gs.credits
	var answer: Variant = commands.execute(GUEST, BENCH, [unit, 90])
	if not answer is Dictionary or int(answer.get(MinigameScore.RECORD_KEY, -1)) != 90:
		return "The host counts the guest's score: %s" % [answer]
	if int(guests["done"]) < 0 or guests.get(QuestEngine.SCORES) != { "cal": 90 }:
		return "The guest's own step is done and keeps the guest's score: %s" % [guests]
	# The log is the farm's, so the host's own step is done by it too, as a
	# plain calibration would: with no score and no bonus.
	if hosts.has(QuestEngine.SCORES) or hosts.keys() != QuestEngine.PLAYER_ENTRY_KEYS:
		return "The host's own entry is given nothing of the guest's score: %s" % [hosts]
	if _lines(gs, BONUS_LINE) != 1 or gs.credits != before + 100 + 110:
		return "Only the guest's quest pays the Fine bonus, got %d CR: %s" % [gs.credits - before, gs.phone_log]
	return ""


func test_a_calibration_that_is_not_traceable_leaves_the_step_open() -> String:
	return _run(_check_untraceable)


func _check_untraceable(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	var entry: Dictionary = _accept(gs)
	var kit: DriftingSensor = gs.get_sensor(gs.get_sensor(PROBE).calibrated_by)
	if kit == null:
		return "The test's soil probe has no standard."
	# The kit is overdue: the zero happens and is no link in the chain.
	var due: int = kit.cal_due_day
	kit.cal_due_day = GameClock.get_day_index() - 1
	var answer: Variant = commands.execute(HOST, BENCH, [PROBE, 100])
	if not answer is Dictionary or not answer.has("as_left") or answer.get("traceable", true):
		return "The test's calibration with an overdue kit is not an untraceable one: %s" % [answer]
	if int(answer.get(MinigameScore.RECORD_KEY, -1)) != 100:
		return "The game was due, so the host counted the score for the zero itself: %s" % [answer]
	if entry["steps_done"] != ["kit"] or entry.has(QuestEngine.SCORES):
		return "A calibration that is not traceable does no step and keeps no score: %s" % [entry]
	if not QuestEngine.has_minigame_step(gs, GAME, PROBE, HOST) or not MinigameScore.is_due(gs, PROBE, HOST, false):
		return "The step is still open, so the game is due again."
	# With the kit away at OIRM nothing is calibrated at all.
	kit.cal_due_day = due
	gs.at_oirm[kit.instrument_id] = GameClock.get_day_index() + 3
	var refused: Variant = commands.execute(HOST, BENCH, [PROBE, 100])
	if not refused is Dictionary or refused.has("as_left") or entry["steps_done"] != ["kit"] or entry.has(QuestEngine.SCORES):
		return "With the kit at OIRM nothing is calibrated and nothing kept: %s" % [refused]
	gs.at_oirm.clear()
	# In date again, the next try does the step and is the one graded.
	commands.execute(HOST, BENCH, [PROBE, 82])
	if entry["steps_done"] != ["kit", "cal"] or entry.get(QuestEngine.SCORES) != { "cal": 82 }:
		return "The traceable try does the step and keeps its own score: %s" % [entry]
	return ""


# --- A skip or a poor try is today's result ---------------------------------------

func test_a_skip_or_a_poor_try_does_the_step_as_today() -> String:
	var plain: Dictionary = {}
	for tail: Array in [[], [0], [59]]:
		var got: Dictionary = {}
		var problem: String = _run(func(commands: Node) -> String:
			got.merge(_play_s1(commands, tail))
			return "")
		if problem != "":
			return problem
		var entry: Dictionary = got["entry"]
		if entry.keys() != QuestEngine.ENTRY_KEYS or entry["steps_done"] != ["kit", "cal", "sell"] or int(entry["done"]) < 0:
			return "With %s the quest is done and its entry has no key more: %s" % [tail, entry]
		if got["after_cal"]["steps_done"] != ["kit", "cal"]:
			return "With %s the calibration does the step: %s" % [tail, got["after_cal"]]
		if got["paid"] != 150 or got["bonus_lines"] != 0 or got["lin_reference"] != 0 or got["done_lines"] != 1 or got["lin_done"] != 1:
			return "With %s S1 pays 150 CR and says what it always said: %d, %s" % [tail, got["paid"], got["log"]]
		if plain.is_empty():
			plain = got
		elif got["entry"] != plain["entry"] or got["credits"] != plain["credits"] or got["log"] != plain["log"]:
			return "A poor try (%s) must leave the farm as a skip does: %s" % [tail, got["log"]]
	return ""


func test_a_calibration_that_does_not_do_the_step_keeps_no_score() -> String:
	return _run(_check_no_step)


func _check_no_step(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	var entry: Dictionary = _accept(gs)
	# Another instrument's score, at its own key moment, is not the step's.
	var other: Variant = commands.execute(HOST, BENCH, [gs.HYGROMETER_ID, 100])
	if not other is Dictionary or not other.has("as_left"):
		return "The test's hygrometer calibration did not happen: %s" % [other]
	if entry["steps_done"] != ["kit"] or entry.has(QuestEngine.SCORES):
		return "Another instrument's calibration does no step and keeps no score: %s" % [entry]
	if not MinigameScore.is_due(gs, PROBE, HOST, false):
		return "The step is still open, so the game is still due."
	return ""


# --- The quest grade (section 7.2) -------------------------------------------------

func test_the_quest_pays_a_bonus_from_fine_up() -> String:
	# score -> CR over the quest's 150, and whether Lin has her line for it.
	var table: Array = [[60, 0, 0], [79, 0, 0], [80, 15, 0], [94, 15, 0], [95, 30, 1], [100, 30, 1]]
	for row: Array in table:
		var got: Dictionary = {}
		var problem: String = _run(func(commands: Node) -> String:
			got.merge(_play_s1(commands, [row[0]]))
			return "")
		if problem != "":
			return problem
		var entry: Dictionary = got["entry"]
		if entry.get(QuestEngine.SCORES) != { "cal": row[0] } or int(entry["done"]) < 0:
			return "A score of %d is kept with the step: %s" % [row[0], entry]
		if got["paid"] != 150 + row[1] or got["bonus_lines"] != (1 if row[1] > 0 else 0):
			return "A score of %d pays %d CR over the quest's 150, got %d: %s" % [row[0], row[1], got["paid"] - 150, got["log"]]
		if got["lin_reference"] != row[2] or got["done_lines"] != 1 or got["lin_done"] != 1:
			return "A score of %d: the quest's own lines once, Lin's extra line only at Reference: %s" % [row[0], got["log"]]
	var fine: Dictionary = {}
	var fine_problem: String = _run(func(commands: Node) -> String:
		fine.merge(_play_s1(commands, [80]))
		return "")
	if fine_problem != "" or not "QUEST BONUS: The Thirsty Probe, played to FINE. 15 CR more." in fine["log"]:
		return "The phone says what the bonus is for: %s" % [fine.get("log")]
	return ""


func test_the_grade_numbers_are_the_design_table() -> String:
	for row: Array in [[-1, 0.0, false, false], [59, 0.0, false, false], [60, 0.0, false, true], [79, 0.0, false, true],
			[80, 0.1, false, true], [94, 0.1, false, true], [95, 0.2, true, true], [100, 0.2, true, true]]:
		if not is_equal_approx(MinigameScore.quest_bonus(row[0]), row[1]) or MinigameScore.earns_line(row[0]) != row[2] \
				or MinigameScore.is_graded(row[0]) != row[3]:
			return "A score of %d: bonus %s, line %s, graded %s." % [row[0], MinigameScore.quest_bonus(row[0]),
				MinigameScore.earns_line(row[0]), MinigameScore.is_graded(row[0])]
	# A quest with two such steps is graded by the lower; one skipped is a skip.
	var quest: Dictionary = { "steps": [{ "id": "a", "minigame": GAME }, { "id": "b" }, { "id": "c", "minigame": GAME }] }
	if QuestEngine.quest_score(quest, { "scores": { "a": 96, "c": 81 } }) != 81 or QuestEngine.quest_score(quest, { "scores": { "a": 96 } }) != MinigameScore.SKIPPED \
			or QuestEngine.quest_score(quest, {}) != MinigameScore.SKIPPED or QuestEngine.quest_score({ "steps": [{ "id": "b" }] }, {}) != MinigameScore.SKIPPED:
		return "A quest's score is the lowest of its mini-game steps, and a skip if one has none."
	return ""


# --- Saved and sent -----------------------------------------------------------------

func test_a_kept_score_is_saved_and_pays_after_a_load() -> String:
	return _run(_check_saved)


func _check_saved(commands: Node) -> String:
	var gs: GameStateScript = commands.state
	_accept(gs)
	commands.execute(HOST, BENCH, [PROBE, 100])
	var data: Dictionary = gs.farm_to_dict()
	if gs.farm_dict_problem(data) != "":
		return "A farm with a kept score is a farm that loads: %s" % gs.farm_dict_problem(data)
	var loaded: GameStateScript = _farm()
	var problem: String = loaded.farm_from_dict(data)
	var kept: Variant = (loaded.quest_state.get(S1, {}) as Dictionary).get(QuestEngine.SCORES)
	var paid: int = _sell(loaded) if problem == "" else 0
	var lin: int = _lines(loaded, LIN_REFERENCE)
	loaded.free()
	if problem != "" or kept != { "cal": 100 }:
		return "The score is there after a save and a load: %s %s" % [problem, kept]
	if paid != 180 or lin != 1:
		return "After a load the quest still pays its Reference bonus and Lin's line: %d CR, %d." % [paid, lin]
	# What is no score is refused, in the farm's quests and in a player's own.
	for bad: Variant in [{ "cal": 59 }, { "cal": 101 }, { "cal": -1 }, { "cal": "95" }, { "cal": 95.0 }, { "": 95 }, { 3: 95 }, [95], 95, null]:
		var wrong: Dictionary = data.duplicate(true)
		wrong["quest_state"][S1][QuestEngine.SCORES] = bad
		if gs.farm_dict_problem(wrong) == "":
			return "A farm whose kept score is %s must be refused." % [bad]
		var own: Dictionary = data.duplicate(true)
		var entry: Dictionary = (data["quest_state"][S1] as Dictionary).duplicate(true)
		entry["carried"] = {}
		own["player_quest_state"] = { GUEST: { "own": entry } }
		if gs.farm_dict_problem(own) != "":
			return "The test's player entry does not load as it is: %s" % gs.farm_dict_problem(own)
		own["player_quest_state"][GUEST]["own"][QuestEngine.SCORES] = bad
		if gs.farm_dict_problem(own) == "":
			return "A farm whose player's kept score is %s must be refused." % [bad]
	var extra: Dictionary = data.duplicate(true)
	extra["quest_state"][S1]["extra"] = 1
	if gs.farm_dict_problem(extra) == "":
		return "An entry with a key that is not a quest's is still refused, with a kept score too."
	return ""


# --- The data ------------------------------------------------------------------------

func test_a_mini_game_step_must_be_one_instruments_calibration() -> String:
	var good: Dictionary = _fixture("farm")
	if QuestEngine.data_problem(good) != "":
		return "The test's quest is right: %s" % QuestEngine.data_problem(good)
	var changes: Array = [
		{ "minigame": "no_such_game" }, { "minigame": 3 }, { "minigame": "" },
		{ "check": "stat_at_least", "stat": "credits", "at_least": 1 }, { "log": "work_orders" },
		{ "where": {} }, { "where": { "instrument_id": "" } }, { "where": { "instrument_id": 3 } }, { "where": "rover_steering_encoder" },
		{ "minigame_line": 3 }, { "minigame_line": "" }]
	for change: Dictionary in changes:
		var quest: Dictionary = good.duplicate(true)
		(quest["steps"][1] as Dictionary).merge(change, true)
		if QuestEngine.data_problem(quest) == "":
			return "A mini-game step changed by %s must be refused." % [change]
	var lone: Dictionary = good.duplicate(true)
	lone["steps"][0]["minigame_line"] = "Well played."
	if not QuestEngine.data_problem(lone).contains("a mini-game line and no mini-game"):
		return "A mini-game line on a step with no mini-game must be refused, and said so: %s" % QuestEngine.data_problem(lone)
	var said: Dictionary = good.duplicate(true)
	said["steps"][1]["minigame_line"] = "Well played."
	return "" if QuestEngine.data_problem(said) == "" else "A mini-game line in the giver's own words is right: %s" % QuestEngine.data_problem(said)


func test_the_shipped_mini_game_steps_can_be_played() -> String:
	var gs: GameStateScript = _farm()
	var found: Array[String] = []
	var problem: String = ""
	for quest: Dictionary in QuestEngine.quests():
		for step: Dictionary in quest["steps"]:
			if not step.has("minigame"):
				continue
			found.append("%s/%s" % [quest["id"], step["id"]])
			var unit: String = QuestEngine.step_instrument(step)
			var line: String = str(step.get(QuestEngine.MINIGAME_LINE, ""))
			# Wring the Blocks and Thread the Spool are for no instrument: their
			# step counts built stacks or seated spools.
			var stack: bool = QuestEngine.is_bare_step(step, str(step["minigame"]))
			if not str(step["minigame"]) in QuestEngine.MINIGAMES or (gs.get_sensor(unit) == null and not stack):
				problem = "%s has a mini-game step for no game or no instrument of the farm's." % quest["id"]
			elif line.contains("/") and QuestEngine.phone_line(line) == line:
				problem = "%s's mini-game line is a path with no text at it." % quest["id"]
	gs.free()
	if problem != "":
		return problem
	return "" if "%s/cal" % S1 in found else "S1's calibration step must carry Set the Zero: %s" % [found]
