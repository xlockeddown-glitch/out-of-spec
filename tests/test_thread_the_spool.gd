extends RefCounted
## Thread the Spool (docs/design/quests_levels_story.md section 7, mini-game 5):
## the sway the seed sets and Husbandry slows, the scoring, the game played
## with no frames, and what the host does with a score at the relay: only an
## open quest step lets it count, and it changes the seat's XP and the quest's
## grade and nothing else.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const GAME_SCENE: String = "res://ui/minigames/thread_the_spool.tscn"
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const QUEST: String = "a_clean_line"
const SEAT: StringName = &"slot_spool_into_relay"
const SKILL: String = "husbandry"
const SEED: int = 811
const FARM_SEED: int = 77
const STEP: float = 1.0 / 60.0
const STANDARD: int = MinigameSettings.Mode.STANDARD
const BONUS: String = "QUEST BONUS"
const DONE: String = "QUEST DONE: A Clean Line."
const ODALYS_REFERENCE: String = "That went in dead center."
## The bot: it pushes against where the spool will be this many seconds on,
## and lets go inside the dead band.
const BOT_LEAD_S: float = 0.12
const BOT_DEAD: float = 0.004
const CARELESS_ROUNDS: int = 40

var _scores: Array[int] = []
var _nodes: Array[Node] = []


func _on_finished(score: int) -> void:
	_scores.append(score)


func _game() -> ThreadTheSpool:
	var game: ThreadTheSpool = (load(GAME_SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_scores.clear()
	game.finished.connect(_on_finished)
	return game


## Plays to the end and returns the score. With `steers` the bot keeps the
## spool over the slot; without, it starts the lowering and does nothing more.
## `late_s` is how long the bot's hands are behind what it sees.
func _play(game: ThreadTheSpool, steers: bool = true, lead_s: float = BOT_LEAD_S) -> int:
	var before: float = game.offset()
	var guard: int = 0
	game.press()
	while game.is_playing() and guard < 60 * 60:
		guard += 1
		if game.stage() == ThreadTheSpool.Stage.LOWER and steers:
			var speed: float = (game.offset() - before) / STEP
			var ahead: float = game.offset() + speed * lead_s
			game.steer(0 if absf(ahead) <= BOT_DEAD else (-1 if ahead > 0.0 else 1))
		before = game.offset()
		game.advance(STEP)
	return _scores[-1] if not _scores.is_empty() else -99


func _round(share: float, mode: int, motion_seed: int, steers: bool = true, lead_s: float = BOT_LEAD_S) -> int:
	var game: ThreadTheSpool = _game()
	game.play(share, mode, motion_seed)
	var score: int = _play(game, steers, lead_s)
	game.free()
	return score


## The spool's place at each step of a lowering nobody steers.
func _trace(share: float, motion_seed: int) -> Array[float]:
	var game: ThreadTheSpool = _game()
	game.play(share, STANDARD, motion_seed)
	game.press()
	var out: Array[float] = []
	while game.stage() == ThreadTheSpool.Stage.LOWER:
		game.advance(STEP)
		out.append(game.offset())
	game.free()
	return out


# --- The sway ---------------------------------------------------------------------

func test_the_sway_is_the_seed_s() -> String:
	var first: Array[float] = _trace(0.0, SEED)
	if first.size() != roundi(ThreadTheSpool.RUN_S / STEP) or first != _trace(0.0, SEED):
		return "The same seed gives the same sway, step for step: %d steps." % first.size()
	if first == _trace(0.0, SEED + 1):
		return "Another seed gives another sway."
	if _round(0.3, STANDARD, SEED) != _round(0.3, STANDARD, SEED) or _round(0.0, STANDARD, SEED, false) != _round(0.0, STANDARD, SEED, false):
		return "The same seed and the same presses give the same score."
	var phases: Array[float] = [0.1, 0.6, 0.35]
	var peak: float = 0.0
	for i: int in 4000:
		peak = maxf(peak, absf(ThreadTheSpool.sway_at(i * 0.05, phases)))
	if peak > ThreadTheSpool.AMPLITUDE + 0.000001 or peak < ThreadTheSpool.AMPLITUDE * 0.5:
		return "The sway stays inside its amplitude and uses it: %f." % peak
	return ""


func test_husbandry_slows_the_sway() -> String:
	if not is_equal_approx(ThreadTheSpool.sway_factor(0.0), 1.0) or not is_equal_approx(ThreadTheSpool.sway_factor(1.0), 1.0 - ThreadTheSpool.SKILL_SLOWING):
		return "No Husbandry is full speed, all of it is slower by SKILL_SLOWING."
	if ThreadTheSpool.sway_factor(7.0) != ThreadTheSpool.sway_factor(1.0) or ThreadTheSpool.sway_factor(-3.0) != 1.0:
		return "The share is held to 0 to 1."
	var last: float = INF
	for share: float in [0.0, 0.25, 0.5, 1.0]:
		var game: ThreadTheSpool = _game()
		game.play(share, STANDARD, SEED)
		game.press()
		game.advance(ThreadTheSpool.RUN_S - 0.5)
		var moved: float = game.travel()
		game.free()
		if moved >= last or moved <= 0.0:
			return "More Husbandry is less sway to follow: %f at share %f, %f before." % [moved, share, last]
		last = moved
	# Front-loaded like every skill effect: the share is MinigameScore.sweet_share.
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	var none: float = MinigameScore.sweet_share(gs, HOST, MinigameScore.THREAD_SKILL)
	gs.free()
	if MinigameScore.THREAD_SKILL != SKILL or none < 0.0 or none > 0.2:
		return "A new player has little or none of the slowing, and it is Husbandry's: %f." % none
	return ""


func test_the_difficulty_sets_the_slot_and_the_speed() -> String:
	var widths: Dictionary = {}
	for mode: int in [MinigameSettings.Mode.RELAXED, STANDARD, MinigameSettings.Mode.SHARP]:
		var game: ThreadTheSpool = _game()
		game.play(0.0, mode, SEED)
		widths[mode] = game.slot()
		game.free()
	if not (widths[MinigameSettings.Mode.RELAXED] > widths[STANDARD] and widths[STANDARD] > widths[MinigameSettings.Mode.SHARP]):
		return "Relaxed has the widest slot and Sharp the narrowest: %s" % [widths]
	if not is_equal_approx(widths[STANDARD], ThreadTheSpool.BASE_SLOT):
		return "Standard's slot is BASE_SLOT."
	return ""


# --- The score --------------------------------------------------------------------

func test_the_scores_run_from_0_to_100() -> String:
	var slot: float = ThreadTheSpool.BASE_SLOT
	if ThreadTheSpool.score(0.0, slot) != 100 or ThreadTheSpool.score(slot, slot) != ThreadTheSpool.SLOT_SCORE:
		return "Dead centre is 100 and the slot's edge is %d." % ThreadTheSpool.SLOT_SCORE
	if ThreadTheSpool.score(slot * 1.01, slot) >= ThreadTheSpool.SLOT_SCORE:
		return "Outside the slot is under Reference."
	if ThreadTheSpool.score(slot * ThreadTheSpool.MISS_AT, slot) != 0 or ThreadTheSpool.score(50.0, slot) != 0 or ThreadTheSpool.score(1.0, 0.0) != 0:
		return "A wide miss is 0, never less."
	var last: int = 100
	for i: int in 400:
		var off: float = i * 0.005
		for side: float in [1.0, -1.0]:
			var score: int = ThreadTheSpool.score(off * side, slot)
			if score < 0 or score > MinigameScore.MAX_SCORE or score > last:
				return "The score is 0 to 100 and never rises with the distance: %d at %f." % [score, off]
		last = ThreadTheSpool.score(off, slot)
	if ThreadTheSpool.score(0.1, slot) != ThreadTheSpool.score(-0.1, slot):
		return "Left and right of the slot score the same."
	return ""


func test_the_grades_and_the_xp_multiplier() -> String:
	var want: Dictionary = { -1: 1.0, 0: 1.0, 59: 1.0, 60: 1.15, 79: 1.15, 80: 1.3, 94: 1.3, 95: 1.5, 100: 1.5 }
	for score: int in want:
		if not is_equal_approx(MinigameScore.xp_factor(score), want[score]):
			return "Section 7.2's XP multiplier at %d is %f, not %f." % [score, want[score], MinigameScore.xp_factor(score)]
	if MinigameScore.seat_text(MinigameScore.SKIPPED) != "":
		return "A skip has no result line."
	if MinigameScore.seat_text(97) != "Seat score 97 of 100: REFERENCE, 50 % more XP for the seat.":
		return "Reference is said with its XP: %s" % MinigameScore.seat_text(97)
	if MinigameScore.seat_text(40) != "Seat score 40 of 100: STANDARD, standard result.":
		return "A poor try is said as standard: %s" % MinigameScore.seat_text(40)
	return ""


func test_a_careful_player_reaches_reference() -> String:
	for motion_seed: int in [SEED, SEED + 1, SEED + 2, 5]:
		var score: int = _round(0.0, STANDARD, motion_seed)
		if score < 95:
			return "A bot that keeps the spool over the slot scores Reference with no Husbandry: %d on seed %d." % [score, motion_seed]
	return ""


func test_a_careless_player_scores_poorly() -> String:
	# The sway can leave an unsteered spool near the slot by luck, so this is a
	# count over many seeds: seldom a grade, never Reference.
	var graded: int = 0
	var best: int = 0
	for i: int in CARELESS_ROUNDS:
		var score: int = _round(0.0, STANDARD, SEED + i, false)
		if score < 0 or score > MinigameScore.MAX_SCORE:
			return "An unsteered spool still gets a score from 0 to 100: %d." % score
		graded += int(MinigameScore.is_graded(score))
		best = maxi(best, score)
	if graded * 4 > CARELESS_ROUNDS or MinigameScore.grade_name(best) == "Reference":
		return "A player who never steers seldom earns a grade and never Reference: %d of %d graded, best %d." % [graded, CARELESS_ROUNDS, best]
	# Steering the wrong way is no better.
	var game: ThreadTheSpool = _game()
	game.play(0.0, STANDARD, SEED)
	game.steer(1)
	var guard: int = 0
	while game.is_playing() and guard < 3600:
		guard += 1
		if game.stage() == ThreadTheSpool.Stage.LOWER:
			game.steer(1)
		game.advance(STEP)
	game.free()
	if _scores.is_empty() or _scores[-1] != 0:
		return "A hand held against the stop scores 0: %s" % [_scores]
	return ""


# --- The game with no frames ------------------------------------------------------

func test_nothing_moves_until_the_first_press() -> String:
	var game: ThreadTheSpool = _game()
	game.play(0.0, STANDARD, SEED)
	var start: float = game.offset()
	game.advance(30.0)
	var waited: bool = game.stage() == ThreadTheSpool.Stage.READY and game.offset() == start and game.travel() == 0.0 and game.lowered() == 0.0
	var centred: bool = absf(start) < 0.000001
	game.steer(0)
	var still: bool = game.stage() == ThreadTheSpool.Stage.READY
	game.push(true, true)
	var started: bool = game.stage() == ThreadTheSpool.Stage.LOWER and game.steering() == -1
	game.push(false, true)
	var both: bool = game.steering() == 0
	game.push(true, false)
	var right: bool = game.steering() == 1
	game.advance(1.0)
	var moved: bool = game.hand() > 0.0 and game.lowered() > 0.0
	game.free()
	if not waited or not centred:
		return "The game waits for the first press with the spool over the slot."
	if not still or not started or not both or not right or not moved:
		return "Left starts it, both keys are neither, and the hand moves the way pushed: %s" % [[still, started, both, right, moved]]
	return ""


func test_a_skip_ends_with_no_score_and_a_result_stands() -> String:
	var game: ThreadTheSpool = _game()
	game.play(0.0, STANDARD, SEED)
	game.skip()
	if _scores != [MinigameScore.SKIPPED] or game.is_playing() or game.visible:
		return "A skip before the first press ends with no score: %s" % [_scores]
	game.play(0.0, STANDARD, SEED)
	game.press()
	game.advance(3.0)
	game.skip()
	if _scores != [MinigameScore.SKIPPED, MinigameScore.SKIPPED]:
		return "A skip while lowering ends with no score: %s" % [_scores]
	game.play(0.0, STANDARD, SEED)
	game.press()
	game.advance(ThreadTheSpool.RUN_S + STEP)
	if game.stage() != ThreadTheSpool.Stage.RESULT or game.lowered() != 1.0:
		game.free()
		return "The lowering takes RUN_S and then the result is shown."
	# A press too soon is not taken; after a moment it closes the result.
	game.steer(1)
	var held: bool = game.is_playing()
	game.skip()
	var stood: bool = _scores.size() == 3 and _scores[-1] >= 0 and _scores[-1] <= MinigameScore.MAX_SCORE
	game.play(0.0, STANDARD, SEED)
	game.press()
	game.advance(ThreadTheSpool.RUN_S + ThreadTheSpool.RESULT_S + 0.1)
	var closed: bool = not game.is_playing() and _scores.size() == 4 and _scores[3] == _scores[2]
	game.free()
	if not held or not stood or not closed:
		return "At the result the score stands, on Skip and when the result times out: %s" % [_scores]
	if ThreadTheSpool.RUN_S < 6.0 or ThreadTheSpool.RUN_S > 10.0 or ThreadTheSpool.MAX_HOLD_S > 3.0:
		return "Section 7.1: 6 to 10 s. Section 7.5: no hold over 3 s."
	return ""


func test_the_frame_rate_does_not_change_a_score() -> String:
	var scores: Array[int] = []
	var ends: Array[float] = []
	for chunk: float in [STEP, 0.05, 0.1]:
		var game: ThreadTheSpool = _game()
		game.play(0.0, STANDARD, SEED)
		game.press()
		var chunks_in_half: int = roundi(0.5 / chunk)
		# Half a second right, half a second of nothing, half a second left, on.
		for half: int in roundi(ThreadTheSpool.RUN_S / 0.5):
			if game.stage() == ThreadTheSpool.Stage.LOWER:
				game.steer([1, 0, -1, 0][half % 4])
			for i: int in chunks_in_half:
				if game.stage() == ThreadTheSpool.Stage.LOWER:
					game.advance(chunk)
		ends.append(game.offset())
		game.skip()
		scores.append(_scores[-1] if not _scores.is_empty() else -99)
		game.free()
	if scores[0] < 0 or scores[1] != scores[0] or scores[2] != scores[0] or not is_equal_approx(ends[1], ends[0]) or not is_equal_approx(ends[2], ends[0]):
		return "The same presses at the same times score the same at 60, 20 and 10 frames a second: %s %s" % [scores, ends]
	if not is_equal_approx(ThreadTheSpool.frame_step(5.0), ThreadTheSpool.MAX_STEP_S) or ThreadTheSpool.frame_step(-1.0) != 0.0:
		return "One frame moves the game by no more than MAX_STEP_S."
	return ""


func test_a_long_push_is_let_go() -> String:
	var game: ThreadTheSpool = _game()
	game.play(0.0, STANDARD, SEED)
	game.push(false, true)
	game.advance(ThreadTheSpool.MAX_HOLD_S - 0.2)
	var holding: bool = game.steering() == 1
	game.advance(0.4)
	var let_go: bool = game.steering() == 0
	# The key is still down: only a new press pushes again.
	game.push(false, false)
	game.push(false, true)
	var again: bool = game.steering() == 1
	game.free()
	if not holding or not let_go or not again:
		return "A push longer than MAX_HOLD_S is let go, and a new press pushes again: %s" % [[holding, let_go, again]]
	return ""


# --- The relay --------------------------------------------------------------------

func _run(body: Callable, with_quest: bool = true) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	var mine: Dictionary = {}
	if with_quest:
		mine[StringName(QUEST)] = (shipped[StringName(QUEST)] as Dictionary).duplicate(true)
	table["quests"] = mine
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call()
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


## A farm with `spools` whole spools on the shelf and, with `offered`, a morning
## gone by, so Odalys has asked for the seat. The commands node acts on it.
func _farm(offered: bool = true, spools: int = 1) -> Node:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(FARM_SEED)
	gs.reset_credibility()
	_nodes.append(gs)
	for i: int in spools:
		gs._add_spool(gs.dome_species_id)
	if offered:
		GameClock.elapsed_days = 1.0
		gs.update_quests()
	var commands: Node = CommandsScript.new()
	commands.state = gs
	_nodes.append(commands)
	return commands


func _lines(gs: Node, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


## What the relay and the shelf are, as text: nothing a score may change.
func _relay(gs: Node) -> String:
	return var_to_str([gs.relay_slotted, gs.slotted_spool_species, gs.slotted_spool_damaged, gs.optical_silk_spools,
		gs._spool_species, gs._spool_damaged, gs.get_relay_lag_multiplier(), gs.can_slot_spool(), gs.action_count("slot_spool", HOST)])


## Seats a spool on a new farm with this score sent ([] for none) and returns the farm.
func _seated(arguments: Array, offered: bool = true) -> Node:
	var commands: Node = _farm(offered)
	var done: Variant = commands.execute(HOST, SEAT, arguments)
	return commands.state if done is bool and done else null


func test_the_quest_data_loads() -> String:
	var quest: Dictionary = {}
	for shipped: Dictionary in QuestEngine.quests():
		if str(shipped.get("id", "")) == QUEST:
			quest = shipped
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "A Clean Line loads: %s" % (QuestEngine.data_problem(quest) if not quest.is_empty() else "it is not in the data")
	var step: Dictionary = quest["steps"][0]
	if step.get("minigame") != MinigameScore.THREAD_THE_SPOOL or not QuestEngine.is_seat_step(step) or not MinigameScore.THREAD_THE_SPOOL in QuestEngine.MINIGAMES:
		return "Its step carries Thread the Spool and counts seated spools."
	var bad: Dictionary = quest.duplicate(true)
	bad["steps"][0]["counter"] = "till"
	if not QuestEngine.data_problem(bad).contains("Thread the Spool"):
		return "Thread the Spool on a step that does not count seats does not load: '%s'" % QuestEngine.data_problem(bad)
	for path: String in ["npcs/odalys/quests/a_clean_line_offer", "npcs/odalys/quests/a_clean_line_done", "npcs/odalys/quests/a_clean_line_reference"]:
		if str(DataManager.get_value(&"dialogue_dispatches", path, "")) == "":
			return "Odalys has the line %s." % path
	return ""


func test_the_quest_is_offered_with_a_spool_on_the_shelf() -> String:
	return _run(func() -> String:
		var bare: Node = _farm(true, 0).state
		if bare.quest_state.has(QUEST) or QuestEngine.has_minigame_step(bare, MinigameScore.THREAD_THE_SPOOL, "", HOST):
			return "A farm with no spool is not asked for a seat: %s" % [bare.quest_state]
		var gs: Node = _farm().state
		if not gs.quest_state.has(QUEST) or not QuestEngine.has_minigame_step(gs, MinigameScore.THREAD_THE_SPOOL, "", HOST):
			return "With a spool on the shelf the morning brings the ask, and its step carries the game: %s" % [gs.quest_state]
		if QuestEngine.has_minigame_step(gs, MinigameScore.WRING_THE_BLOCKS, "", HOST) or QuestEngine.has_minigame_step(gs, MinigameScore.SET_THE_ZERO, "", HOST):
			return "The step carries no other game."
		if _lines(gs, "Seat it in the relay") != 1:
			return "Odalys says so: %s" % [gs.phone_log]
		return "")


func test_a_poor_try_gives_what_a_skip_gives() -> String:
	return _run(func() -> String:
		var skip: Node = _seated([])
		if skip == null or not skip.relay_slotted or _lines(skip, DONE) != 1 or _lines(skip, BONUS) != 0:
			return "A seat with no game does the step and the quest is paid plainly."
		var plain: String = var_to_str(skip.farm_to_dict())
		for score: int in [0, 1, 59, -40]:
			var poor: Node = _seated([score])
			if poor == null or var_to_str(poor.farm_to_dict()) != plain or poor.phone_log != skip.phone_log:
				return "A try of %d leaves the farm a skip leaves, to the last field." % score
		return "")


func test_a_score_changes_only_the_xp_and_the_quest_grade() -> String:
	return _run(func() -> String:
		var skip: Node = _seated([])
		var base_xp: int = skip.skill_xp(SKILL, HOST)
		var source: float = skip._lab_source_xp("lab_spool")
		if base_xp <= 0 or source <= 0.0 or skip.credits <= 0:
			return "The plain seat gives Husbandry XP and lab XP, and the quest pays credits."
		# score: [XP factor, share of the quest's credits more, bonus lines, Odalys' line]
		var want: Dictionary = { 60: [1.15, 0.0, 0, 0], 79: [1.15, 0.0, 0, 0], 80: [1.3, 0.1, 1, 0], 95: [1.5, 0.2, 1, 1], 100: [1.5, 0.2, 1, 1] }
		var pay: int = int(QuestEngine.quests()[0]["rewards"]["credits"])
		for score: int in want:
			var gs: Node = _seated([score])
			if gs == null:
				return "The spool is seated at any score."
			if _relay(gs) != _relay(skip):
				return "A score of %d seats the same spool with the same lag: %s, not %s" % [score, _relay(gs), _relay(skip)]
			var factor: float = want[score][0]
			if gs.skill_xp(SKILL, HOST) != roundi(base_xp * factor):
				return "At %d the seat's Husbandry XP is times %f: %d of %d." % [score, factor, gs.skill_xp(SKILL, HOST), base_xp]
			var more_lab: int = roundi(source * factor * gs.lab_xp_scale()) - roundi(source * skip.lab_xp_scale())
			if gs.lab_xp - skip.lab_xp != more_lab or more_lab <= 0:
				return "At %d the seat's lab XP is times %f: %d more, not %d." % [score, factor, gs.lab_xp - skip.lab_xp, more_lab]
			if gs.credits - skip.credits != roundi(pay * float(want[score][1])):
				return "At %d the quest pays %d CR more, not %d." % [score, roundi(pay * float(want[score][1])), gs.credits - skip.credits]
			if _lines(gs, DONE) != 1 or _lines(gs, BONUS) != want[score][2] or _lines(gs, ODALYS_REFERENCE) != want[score][3]:
				return "At %d the quest is done once, with %d bonus lines and Odalys' line %d times: %s" % [score, want[score][2], want[score][3], gs.phone_log]
			# Every other skill, and the lab's level, are the skip's.
			for skill: String in skip.player_skill_xp.get(HOST, {}):
				if skill != SKILL and gs.skill_xp(skill, HOST) != skip.skill_xp(skill, HOST):
					return "A score moved %s XP." % skill
		return "")


func test_a_score_is_held_to_0_to_100() -> String:
	return _run(func() -> String:
		var top: Node = _seated([100])
		var over: Node = _seated([5000000])
		if top == null or over == null or var_to_str(over.farm_to_dict()) != var_to_str(top.farm_to_dict()):
			return "A score over 100 is 100."
		var commands: Node = _farm()
		if commands.execute(HOST, SEAT, ["100"]) != false or commands.execute(HOST, SEAT, [1.5]) != false or commands.execute(HOST, SEAT, [90, 90]) != false:
			return "A score that is not one whole number is refused."
		if commands.state.relay_slotted or commands.state.optical_silk_spools != 1:
			return "A refused seat seats nothing."
		return "")


func test_a_score_with_no_open_step_is_a_skip() -> String:
	var no_quest: String = _run(func() -> String:
		# No such quest at all: the host's and a guest's 100 are both skips.
		var plain: Node = _seated([], false)
		var sent: Node = _seated([100], false)
		if plain == null or sent == null or var_to_str(sent.farm_to_dict()) != var_to_str(plain.farm_to_dict()):
			return "With no open step a score of 100 leaves the farm a plain seat leaves."
		var commands: Node = _farm(false)
		var host: Node = commands.state
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		if MinigameScore.seat_allowed(host, id, 100) != MinigameScore.SKIPPED or commands.execute(id, SEAT, [100]) != true:
			return "A guest's score with no open step is a skip, and the spool is seated all the same."
		if host.skill_xp(SKILL, id) != plain.skill_xp(SKILL, HOST):
			return "The guest's seat gives the plain XP: %d, not %d." % [host.skill_xp(SKILL, id), plain.skill_xp(SKILL, HOST)]
		return "", false)
	if no_quest != "":
		return no_quest
	return _run(func() -> String:
		# Not yet offered: the quest is in the data, and no morning has brought it.
		var early: Node = _seated([100], false)
		var plain: Node = _seated([], false)
		if early == null or early.skill_xp(SKILL, HOST) != plain.skill_xp(SKILL, HOST) or early.lab_xp != plain.lab_xp:
			return "Before the ask is made a score counts for nothing."
		# Once the step is done: the first spool is a damaged one, so a whole one can follow.
		var commands: Node = _farm(false, 0)
		var gs: Node = commands.state
		gs._add_spool(gs.dome_species_id, true)
		GameClock.elapsed_days = 1.0
		gs.update_quests()
		if MinigameScore.seat_allowed(gs, HOST, 100) != 100 or commands.execute(HOST, SEAT, [100]) != true or _lines(gs, DONE) != 1:
			return "The first seat is graded and the quest is done: %s" % [gs.phone_log]
		var xp: int = gs.skill_xp(SKILL, HOST)
		var lab: int = gs.lab_xp
		var credits: int = gs.credits
		gs._add_spool(gs.dome_species_id)
		if MinigameScore.seat_allowed(gs, HOST, 100) != MinigameScore.SKIPPED or commands.execute(HOST, SEAT, [100]) != true:
			return "With the step done the next seat's score is a skip, and the spool still goes in."
		if gs.skill_xp(SKILL, HOST) - xp != plain.skill_xp(SKILL, HOST) or gs.lab_xp - lab != roundi(gs._lab_source_xp("lab_spool") * gs.lab_xp_scale()) or gs.credits != credits:
			return "That seat gives the plain XP and nothing more: %d Husbandry XP." % (gs.skill_xp(SKILL, HOST) - xp)
		if _lines(gs, BONUS) != 1 or gs.slotted_spool_damaged:
			return "The quest is paid once, and the whole spool is the one seated."
		return "")


func test_a_guest_s_seat_is_graded_like_the_host_s() -> String:
	return _run(func() -> String:
		var commands: Node = _farm()
		var host: Node = commands.state
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		# The relay is the farm's, and so is the ask: the guest's seat does it.
		if MinigameScore.seat_allowed(host, id, 97) != 97:
			return "The farm's open step lets a guest's score count."
		# What a guest's PC asks first: the same arguments are well formed there.
		if commands.problem(SEAT, [97]) != "" or commands.problem(SEAT, []) != "":
			return "A seat is asked for with a score or with none: %s" % commands.problem(SEAT, [97])
		if commands.execute(id, SEAT, [97]) != true or _lines(host, DONE) != 1 or _lines(host, ODALYS_REFERENCE) != 1:
			return "A guest's Reference seat does the farm's quest with Odalys' line: %s" % [host.phone_log]
		if host.skill_xp(SKILL, id) != roundi(25 * 1.5) or host.skill_xp(SKILL, HOST) != 0:
			return "The XP is the guest's own: %d." % host.skill_xp(SKILL, id)
		return "")


func test_no_save_or_message_changed() -> String:
	if SessionScript.PROTOCOL != 17:
		return "The score rides as a scored action's last argument: the protocol is still 17."
	if SaveGame.VERSION != 1:
		return "Nothing new is saved: the save version is still 1."
	if not SEAT in CommandsScript.SCORED:
		return "The seat is a scored action."
	return ""
