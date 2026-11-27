extends RefCounted
## Torque to Spec (docs/design/quests_levels_story.md section 7, mini-game 4):
## the click lines and climbs the seed sets, the sweet spot Calibration widens,
## the scoring, the game played with no frames, and what the host does with a
## score at Bram's wheel service: only an open quest step lets it count, and it
## changes the service's XP and the quest's grade and nothing else.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const GAME_SCENE: String = "res://ui/minigames/torque_to_spec.tscn"
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const QUEST: String = "to_the_click"
const SERVICE: StringName = &"service_wheels"
const SOURCE: String = "service_wheels"
const LAB_SOURCE: String = "lab_wheels"
const SKILL: String = "robotics"
const GAME: String = MinigameScore.TORQUE_TO_SPEC
const SEED: int = 811
const FARM_SEED: int = 77
const STEP: float = 1.0 / 60.0
const STANDARD: int = MinigameSettings.Mode.STANDARD
const RELAXED: int = MinigameSettings.Mode.RELAXED
const SHARP: int = MinigameSettings.Mode.SHARP
const BONUS: String = "QUEST BONUS"
const DONE: String = "QUEST DONE: To the Click."
const BRAM_REFERENCE: String = "Every one of them right on the click."
## The careful bot lets go this far under the line: about half a step's climb.
const BOT_LEAD: float = 0.008
## A hand that lets go well early: outside the sweet spot at any Calibration.
const SLOPPY_LEAD: float = 0.1
## The saved farm fields a graded score may change: the XP, the quest's pay and
## kept score, and the phone's lines about them.
const SCORE_MOVES: Array[String] = ["action_counts", "credits", "lab_xp", "phone_count", "phone_log", "player_skill_xp", "quest_state"]

var _scores: Array[int] = []
var _nodes: Array[Node] = []


func _on_finished(score: int) -> void:
	_scores.append(score)


func _game() -> TorqueToSpec:
	var game: TorqueToSpec = (load(GAME_SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_scores.clear()
	game.finished.connect(_on_finished)
	return game


## Plays a started game to its end. A careful hand lets go `lead` under each
## click line; a careless one lets go at once.
func _play(game: TorqueToSpec, lead: float = BOT_LEAD, careful: bool = true) -> int:
	var guard: int = 0
	while game.is_playing() and guard < 5000:
		guard += 1
		match game.stage():
			TorqueToSpec.Stage.READY:
				game.hold(true)
				if not careful:
					game.advance(STEP)
					game.hold(false)
			TorqueToSpec.Stage.CLIMB:
				if game.torque() >= game.line() - lead:
					game.hold(false)
				else:
					game.advance(STEP)
			TorqueToSpec.Stage.SET:
				game.advance(STEP)
			TorqueToSpec.Stage.RESULT:
				game.advance(TorqueToSpec.RESULT_ARM_S + STEP)
				game.hold(true)
	return _scores[-1] if not _scores.is_empty() else -99


func _round(share: float, mode: int, motion_seed: int, lead: float = BOT_LEAD, careful: bool = true) -> int:
	var game: TorqueToSpec = _game()
	game.play(share, mode, motion_seed)
	var score: int = _play(game, lead, careful)
	game.free()
	return score


## A careful hand on all five nuts, and no further: the result is showing.
func _to_result(game: TorqueToSpec) -> void:
	var guard: int = 0
	while game.stage() != TorqueToSpec.Stage.RESULT and game.is_playing() and guard < 5000:
		guard += 1
		match game.stage():
			TorqueToSpec.Stage.READY:
				game.hold(true)
			TorqueToSpec.Stage.CLIMB:
				if game.torque() >= game.line() - BOT_LEAD:
					game.hold(false)
				else:
					game.advance(STEP)
			_:
				game.advance(STEP)


## Each nut's torque at every step of a half-second hold, and then its click line.
func _trace(motion_seed: int, mode: int = STANDARD) -> Array[float]:
	var game: TorqueToSpec = _game()
	game.play(0.0, mode, motion_seed)
	var out: Array[float] = []
	for nut: int in TorqueToSpec.NUTS:
		game.hold(true)
		for i: int in 30:
			game.advance(STEP)
			out.append(game.torque())
		out.append(game.line())
		game.hold(false)
		game.advance(TorqueToSpec.SET_S + 0.1)
	game.free()
	return out


# --- The nuts ---------------------------------------------------------------------

func test_the_lines_and_climbs_are_the_seed_s() -> String:
	var first: Array[float] = _trace(SEED)
	if first.size() != TorqueToSpec.NUTS * 31 or first != _trace(SEED):
		return "The same seed gives the same lines and climbs, step for step: %d values." % first.size()
	if first == _trace(SEED + 1):
		return "Another seed gives other lines and climbs."
	for nut: int in TorqueToSpec.NUTS:
		var line: float = first[nut * 31 + 30]
		if line < TorqueToSpec.LINE_MIN or line > TorqueToSpec.LINE_MAX:
			return "Every click line is between LINE_MIN and LINE_MAX: %f." % line
		var last: float = 0.0
		for i: int in 30:
			if first[nut * 31 + i] <= last:
				return "The torque only climbs while the button is held."
			last = first[nut * 31 + i]
	if _round(0.3, STANDARD, SEED) != _round(0.3, STANDARD, SEED) or _round(0.0, STANDARD, SEED, SLOPPY_LEAD) != _round(0.0, STANDARD, SEED, SLOPPY_LEAD):
		return "The same seed and the same presses give the same score."
	for i: int in 400:
		if TorqueToSpec.climb_rate(i * 0.01, 0.6, 1.5, 0.37) <= 0.0:
			return "The climb never stops or runs back."
	return ""


func test_nothing_moves_before_a_press() -> String:
	var game: TorqueToSpec = _game()
	if game.is_playing() or game.visible:
		game.free()
		return "The game is shut until play()."
	game.play(0.0, STANDARD, SEED)
	game.advance(30.0)
	var waited: bool = game.stage() == TorqueToSpec.Stage.READY and game.torque() == 0.0 and game.nuts_done() == 0 and _scores.is_empty()
	# Letting go of nothing is nothing.
	game.hold(false)
	var still: bool = game.stage() == TorqueToSpec.Stage.READY
	game.hold(true)
	game.advance(0.3)
	var climbing: bool = game.stage() == TorqueToSpec.Stage.CLIMB and game.torque() > 0.0 and game.is_held()
	game.hold(false)
	game.advance(TorqueToSpec.SET_S + 0.1)
	# The next nut waits for a press of its own, with no clock on the wait.
	game.advance(30.0)
	var next_waits: bool = game.stage() == TorqueToSpec.Stage.READY and game.torque() == 0.0 and game.nuts_done() == 1 and not game.is_held()
	game.free()
	if not waited or not still or not climbing or not next_waits:
		return "Nothing moves until a press, for the first nut and for each after: %s" % [[waited, still, climbing, next_waits]]
	return ""


func test_the_nuts_go_in_star_order() -> String:
	var order: Array[int] = TorqueToSpec.STAR_ORDER
	var seen: Dictionary = {}
	for turn: int in TorqueToSpec.NUTS:
		seen[order[turn]] = true
		if order[turn] != (turn * 2) % TorqueToSpec.NUTS:
			return "Star order: each nut is two places on from the last: %s" % [order]
	if order.size() != TorqueToSpec.NUTS or seen.size() != TorqueToSpec.NUTS:
		return "Every nut is tightened once."
	var game: TorqueToSpec = _game()
	game.play(0.0, STANDARD, SEED)
	var shown: Array[int] = []
	for turn: int in TorqueToSpec.NUTS:
		shown.append(game.next_place())
		game.hold(true)
		game.advance(0.3)
		# While it is tightened the mark stays on it.
		if game.next_place() != shown[-1]:
			shown.append(-99)
		game.hold(false)
		game.advance(TorqueToSpec.SET_S + 0.1)
	var after: int = game.next_place()
	var result: bool = game.stage() == TorqueToSpec.Stage.RESULT and game.nuts_done() == TorqueToSpec.NUTS
	game.free()
	if shown != order or after != -1 or not result:
		return "The game shows which nut is next, in star order, and none after the fifth: %s then %d" % [shown, after]
	return ""


func test_calibration_widens_the_sweet_spot() -> String:
	if not is_equal_approx(TorqueToSpec.sweet_half_width(0.0), TorqueToSpec.BASE_SWEET) or not is_equal_approx(TorqueToSpec.sweet_half_width(1.0), 2.0 * TorqueToSpec.BASE_SWEET):
		return "No Calibration is the base sweet spot, all of it is twice as wide."
	if TorqueToSpec.sweet_half_width(7.0) != TorqueToSpec.sweet_half_width(1.0) or TorqueToSpec.sweet_half_width(-3.0) != TorqueToSpec.BASE_SWEET:
		return "The share is held to 0 to 1."
	var last_width: float = 0.0
	var last_score: int = -1
	var scores: Array[int] = []
	for share: float in [0.0, 0.25, 0.5, 1.0]:
		var game: TorqueToSpec = _game()
		game.play(share, STANDARD, SEED)
		var width: float = game.sweet_half()
		var score: int = _play(game, SLOPPY_LEAD)
		game.free()
		scores.append(score)
		if width <= last_width or score < last_score:
			return "More Calibration is a wider sweet spot, and the same hand scores no worse: %s" % [scores]
		last_width = width
		last_score = score
	if scores[-1] <= scores[0]:
		return "The same early hand scores more with all of Calibration than with none: %s" % [scores]
	# Front-loaded like every skill effect: the share is MinigameScore.sweet_share.
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	var none: float = MinigameScore.sweet_share(gs, HOST)
	gs.free()
	if none < 0.0 or none > 0.2:
		return "A new player has little or none of the widening: %f." % none
	return ""


func test_the_difficulty_sets_the_sweet_spot_and_the_climb() -> String:
	var widths: Dictionary = {}
	var climbed: Dictionary = {}
	for mode: int in [RELAXED, STANDARD, SHARP]:
		var game: TorqueToSpec = _game()
		game.play(0.0, mode, SEED)
		widths[mode] = game.sweet_half()
		game.hold(true)
		game.advance(0.5)
		climbed[mode] = game.torque()
		game.free()
	if not (widths[RELAXED] > widths[STANDARD] and widths[STANDARD] > widths[SHARP]):
		return "Relaxed has the widest sweet spot and Sharp the narrowest: %s" % [widths]
	if not is_equal_approx(widths[STANDARD], TorqueToSpec.BASE_SWEET):
		return "Standard is the base sweet spot."
	if not (climbed[RELAXED] < climbed[STANDARD] and climbed[STANDARD] < climbed[SHARP]):
		return "Relaxed climbs slowest and Sharp fastest: %s" % [climbed]
	for mode: int in [RELAXED, STANDARD, SHARP]:
		if _round(0.0, mode, SEED) < 95:
			return "A careful hand reaches Reference on every difficulty: %d on %d." % [_round(0.0, mode, SEED), mode]
	return ""


# --- The score --------------------------------------------------------------------

func test_a_nut_s_closeness_is_0_to_100() -> String:
	var sweet: float = TorqueToSpec.BASE_SWEET
	if TorqueToSpec.closeness(0.7, 0.7) != 100 or TorqueToSpec.closeness(0.7 + sweet * 0.999, 0.7) != TorqueToSpec.SWEET_SCORE:
		return "On the line is 100, and the sweet spot's edge is SWEET_SCORE."
	if TorqueToSpec.closeness(0.7 - TorqueToSpec.MISS_DISTANCE, 0.7) != 0 or TorqueToSpec.closeness(0.0, 0.85) != 0 or TorqueToSpec.closeness(1.0, 0.6, sweet * 0.5) != 0:
		return "MISS_DISTANCE away, and anything farther, is 0."
	# The widest sweet spot there is does not move where a miss begins.
	var widest: float = TorqueToSpec.sweet_half_width(1.0, MinigameSettings.sweet_factor(RELAXED))
	if widest >= TorqueToSpec.MISS_DISTANCE * 0.5 or TorqueToSpec.closeness(0.7 - TorqueToSpec.MISS_DISTANCE, 0.7, widest) != 0 or TorqueToSpec.closeness(0.7 + TorqueToSpec.MISS_DISTANCE, 0.7, widest) != 0:
		return "Calibration and the difficulty widen the sweet spot only: a miss begins at the same distance."
	var last: int = 100
	for i: int in 200:
		var off: float = i * 0.004
		var over: int = TorqueToSpec.closeness(0.7 + off, 0.7)
		var under: int = TorqueToSpec.closeness(0.7 - off, 0.7)
		if over != under or over > last or over < 0 or over > MinigameScore.MAX_SCORE:
			return "Closeness falls with the distance, the same under and over, inside 0 to 100: %d and %d at %f." % [over, under, off]
		if off > sweet + 0.000001 and over >= TorqueToSpec.SWEET_SCORE:
			return "Outside the sweet spot a nut is under SWEET_SCORE."
		if TorqueToSpec.closeness(0.7 + off, 0.7, 2.0 * sweet) < over:
			return "A wider sweet spot never scores the same torque lower."
		last = over
	return ""


func test_the_score_is_the_mean_of_the_five() -> String:
	if TorqueToSpec.score([100, 100, 100, 100, 100] as Array[int]) != 100 or TorqueToSpec.score([] as Array[int]) != 0:
		return "Five nuts on the line is 100, and none is 0."
	if TorqueToSpec.score([100, 90, 80, 70, 60] as Array[int]) != 80 or TorqueToSpec.score([100, 100] as Array[int]) != 40:
		return "The score is the mean closeness, and a nut not done counts as 0."
	if TorqueToSpec.score([900, 900, 900, 900, 900] as Array[int]) != 100 or TorqueToSpec.score([-50, -50, -50, -50, -50] as Array[int]) != 0:
		return "The score is held to 0 to 100."
	for motion_seed: int in 12:
		for lead: float in [BOT_LEAD, SLOPPY_LEAD, 0.4, -0.2]:
			var score: int = _round(0.0, STANDARD, motion_seed, lead)
			if score < 0 or score > MinigameScore.MAX_SCORE:
				return "A played score is 0 to 100: %d." % score
	if _round(0.0, STANDARD, SEED) < 95:
		return "Letting go on every click is a Reference score: %d." % _round(0.0, STANDARD, SEED)
	if _round(0.0, STANDARD, SEED, BOT_LEAD, false) >= 60:
		return "Letting go at once is a poor try: %d." % _round(0.0, STANDARD, SEED, BOT_LEAD, false)
	return ""


func test_the_game_can_be_skipped_at_any_time() -> String:
	var game: TorqueToSpec = _game()
	game.play(0.0, STANDARD, SEED)
	game.skip()
	var first: bool = not game.is_playing() and _scores == ([MinigameScore.SKIPPED] as Array[int])
	game.play(0.0, STANDARD, SEED)
	game.hold(true)
	game.advance(0.4)
	game.skip()
	game.play(0.0, STANDARD, SEED)
	game.hold(true)
	game.advance(0.4)
	game.hold(false)
	game.advance(0.2)
	game.skip()
	if not first or _scores != ([MinigameScore.SKIPPED, MinigameScore.SKIPPED, MinigameScore.SKIPPED] as Array[int]):
		game.free()
		return "Skip before a press, in a hold and between nuts ends the game with no score: %s" % [_scores]
	# At the result the score stands, on Skip and when the result times out.
	game.play(0.0, STANDARD, SEED)
	_to_result(game)
	# A press too soon is not taken.
	game.hold(true)
	var held: bool = game.is_playing() and game.stage() == TorqueToSpec.Stage.RESULT
	game.skip()
	var stood: bool = _scores.size() == 4 and _scores[-1] >= 95 and _scores[-1] <= MinigameScore.MAX_SCORE
	game.play(0.0, STANDARD, SEED)
	_to_result(game)
	game.advance(TorqueToSpec.RESULT_S + 0.1)
	var closed: bool = not game.is_playing() and _scores.size() == 5 and _scores[4] == _scores[3]
	game.free()
	if not held or not stood or not closed:
		return "At the result the score stands, on Skip and when the result times out: %s" % [_scores]
	return ""


func test_the_frame_rate_does_not_change_a_score() -> String:
	var scores: Array[int] = []
	var runs: Array = []
	for chunk: float in [STEP, 0.05, 0.1]:
		var game: TorqueToSpec = _game()
		game.play(0.0, STANDARD, SEED)
		var torques: Array[float] = []
		for nut: int in TorqueToSpec.NUTS:
			game.hold(true)
			# Holds of 0.5 to 0.9 s, then the nut's result and a little more.
			for i: int in roundi((0.5 + 0.1 * nut) / chunk):
				game.advance(chunk)
			torques.append(game.torque())
			game.hold(false)
			for i: int in roundi(0.7 / chunk):
				game.advance(chunk)
		runs.append(torques)
		game.skip()
		scores.append(_scores[-1] if not _scores.is_empty() else -99)
		game.free()
	if scores[0] < 0 or scores[1] != scores[0] or scores[2] != scores[0]:
		return "The same presses at the same times score the same at 60, 20 and 10 frames a second: %s" % [scores]
	for nut: int in TorqueToSpec.NUTS:
		if runs[0][nut] <= 0.0 or not is_equal_approx(runs[1][nut], runs[0][nut]) or not is_equal_approx(runs[2][nut], runs[0][nut]):
			return "Each nut is left at the same torque at any frame rate: %s" % [runs]
	if not is_equal_approx(TorqueToSpec.frame_step(5.0), TorqueToSpec.MAX_STEP_S) or TorqueToSpec.frame_step(-1.0) != 0.0:
		return "One frame moves the game by no more than MAX_STEP_S."
	return ""


func test_a_long_hold_is_let_go() -> String:
	if TorqueToSpec.MAX_HOLD_S > 3.0:
		return "Section 7.5: no hold over 3 s."
	for mode: int in [RELAXED, STANDARD, SHARP]:
		var game: TorqueToSpec = _game()
		game.play(0.0, mode, SEED)
		game.hold(true)
		game.advance(0.3)
		var holding: bool = game.stage() == TorqueToSpec.Stage.CLIMB and game.is_held()
		# The key stays down.
		game.advance(TorqueToSpec.MAX_HOLD_S)
		var let_go: bool = game.stage() != TorqueToSpec.Stage.CLIMB and not game.is_held() and game.nuts_done() == 1
		var over: bool = game.closenesses()[0] == TorqueToSpec.MISSED if let_go else false
		# The key comes up at last: nothing. Only a new press starts the next nut.
		game.hold(false)
		game.advance(TorqueToSpec.SET_S + 0.1)
		var waits: bool = game.stage() == TorqueToSpec.Stage.READY and game.nuts_done() == 1
		game.hold(true)
		var again: bool = game.stage() == TorqueToSpec.Stage.CLIMB and game.is_held()
		game.free()
		if not holding or not let_go or not over or not waits or not again:
			return "A hold longer than MAX_HOLD_S is let go and that nut is a miss, and a new press starts the next: %s on %d" % [[holding, let_go, over, waits, again], mode]
	# The cap's own comment: the slowest climb, on the slowest difficulty, is
	# past its line before the game lets go.
	for mode: int in [RELAXED, STANDARD, SHARP]:
		if TorqueToSpec.CLIMB_MAX_S / MinigameSettings.speed_factor(mode) >= TorqueToSpec.MAX_HOLD_S:
			return "The slowest climb reaches its line before the hold cap on %d: %f s of %f." % [mode, TorqueToSpec.CLIMB_MAX_S / MinigameSettings.speed_factor(mode), TorqueToSpec.MAX_HOLD_S]
	return ""


## Plays a started game to its end, letting go of each nut only at `top` of
## the bar. A `top` over 1 never lets go: the game does.
func _play_to_top(game: TorqueToSpec, top: float) -> int:
	var guard: int = 0
	while game.is_playing() and guard < 5000:
		guard += 1
		match game.stage():
			TorqueToSpec.Stage.READY:
				game.hold(false)
				game.hold(true)
			TorqueToSpec.Stage.CLIMB:
				if game.torque() >= top:
					game.hold(false)
				else:
					game.advance(STEP)
			TorqueToSpec.Stage.SET:
				game.advance(STEP)
			TorqueToSpec.Stage.RESULT:
				game.advance(TorqueToSpec.RESULT_ARM_S + STEP)
				game.hold(false)
				game.hold(true)
	return _scores[-1] if not _scores.is_empty() else -99


func test_holding_every_nut_to_the_top_is_a_poor_try() -> String:
	# Relaxed with all of Calibration is the widest sweet spot there is.
	for mode: int in [RELAXED, STANDARD, SHARP]:
		for motion_seed: int in 100:
			var game: TorqueToSpec = _game()
			game.play(1.0, mode, motion_seed)
			var score: int = _play_to_top(game, 2.0)
			var missed: bool = game.closenesses().count(TorqueToSpec.MISSED) == TorqueToSpec.NUTS
			game.free()
			if score != 0 or not missed:
				return "Never letting go misses every nut and scores 0, on seed %d and difficulty %d: %d." % [motion_seed, mode, score]
	# Nor does letting go just under the bar's end earn a grade over many lines.
	var sum: int = 0
	for motion_seed: int in 100:
		var game: TorqueToSpec = _game()
		game.play(1.0, RELAXED, motion_seed)
		sum += _play_to_top(game, 0.97)
		game.free()
	if sum / 100.0 >= 60.0 or sum <= 0:
		return "Letting go at the top of the bar every time is a poor try over many seeds: %f." % (sum / 100.0)
	return ""


# --- Bram's bay -------------------------------------------------------------------

func _run(body: Callable, with_quest: bool = true) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var saved_out: Dictionary = CoopWalkers.out.duplicate(true)
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	var mine: Dictionary = {}
	if with_quest:
		mine[StringName(QUEST)] = (shipped[StringName(QUEST)] as Dictionary).duplicate(true)
	table["quests"] = mine
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	CoopWalkers.out.clear()
	FarmCommands.guest = false
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call()
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopWalkers.out.clear()
	CoopWalkers.out.merge(saved_out)
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


## A farm whose rover has, with `due`, driven far enough for its wheel nuts to
## be due and, with `offered`, a morning gone by, so Bram has asked. The
## commands node acts on it.
func _farm(offered: bool = true, due: bool = true) -> Node:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(FARM_SEED)
	gs.reset_credibility()
	_nodes.append(gs)
	if due:
		gs.add_rover_usage(gs.wheel_service_due_m(), HOST)
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


## What the service is, as text: nothing a score may change.
func _bay(gs: Node) -> String:
	return var_to_str([gs.wheel_meters, gs.wheels_due(), gs.wheel_service_due_m(), gs.wheel_service_text(),
		gs.action_count(SOURCE, HOST), gs.rover_in_tunnels, gs.crystal_ore])


## Services the wheels on a new farm with this score sent ([] for none) and returns the farm.
func _serviced(arguments: Array, offered: bool = true) -> Node:
	var commands: Node = _farm(offered)
	var done: Variant = commands.execute(HOST, SERVICE, arguments)
	return commands.state if done is String and done == "" else null


## The names of the farm's saved fields that differ between two farms.
func _differing(one: Node, other: Node) -> Array[String]:
	var a: Dictionary = one.farm_to_dict()
	var b: Dictionary = other.farm_to_dict()
	var out: Array[String] = []
	for key: Variant in a:
		if not b.has(key) or var_to_str(a[key]) != var_to_str(b[key]):
			out.append(str(key))
	for key: Variant in b:
		if not a.has(key):
			out.append(str(key))
	out.sort()
	return out


func test_the_quest_data_loads() -> String:
	var quest: Dictionary = {}
	for shipped: Dictionary in QuestEngine.quests():
		if str(shipped.get("id", "")) == QUEST:
			quest = shipped
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "To the Click loads: %s" % (QuestEngine.data_problem(quest) if not quest.is_empty() else "it is not in the data")
	var step: Dictionary = quest["steps"][0]
	if step.get("minigame") != GAME or not QuestEngine.is_service_step(step) or not GAME in QuestEngine.MINIGAMES:
		return "Its step carries Torque to Spec and counts wheel services."
	if str(quest.get("giver", "")) != "bram" or not QuestEngine.is_bare_step(step, GAME) or QuestEngine.is_bare_step(step, MinigameScore.THREAD_THE_SPOOL):
		return "It is Bram's, and its step is for no instrument and no other game."
	var bad: Dictionary = quest.duplicate(true)
	bad["steps"][0]["counter"] = "till"
	if not QuestEngine.data_problem(bad).contains("Torque to Spec"):
		return "Torque to Spec on a step that does not count wheel services does not load: '%s'" % QuestEngine.data_problem(bad)
	var stat: Dictionary = quest.duplicate(true)
	stat["steps"][0]["check"] = "wheels_due"
	stat["steps"][0].erase("counter")
	if QuestEngine.data_problem(stat) == "":
		return "Torque to Spec on a step that is not a counter does not load."
	var other: Dictionary = quest.duplicate(true)
	other["steps"][0]["minigame"] = MinigameScore.THREAD_THE_SPOOL
	if QuestEngine.data_problem(other) == "":
		return "Another game on a step that counts wheel services does not load."
	for path: String in ["npcs/bram/quests/to_the_click_offer", "npcs/bram/quests/to_the_click_done", "npcs/bram/quests/to_the_click_reference"]:
		if str(DataManager.get_value(&"dialogue_dispatches", path, "")) == "":
			return "Bram has the line %s." % path
	return ""


func test_the_quest_is_offered_with_the_nuts_due() -> String:
	return _run(func() -> String:
		var fresh: Node = _farm(true, false).state
		if fresh.quest_state.has(QUEST) or QuestEngine.has_minigame_step(fresh, GAME, "", HOST):
			return "A farm whose nuts are not due is not asked: %s" % [fresh.quest_state]
		if QuestEngine.check_value(fresh, { "check": "wheels_due" }, [HOST] as Array[String]) != 0:
			return "wheels_due reads 0 with the nuts not due."
		var gs: Node = _farm().state
		if QuestEngine.check_value(gs, { "check": "wheels_due" }, [HOST] as Array[String]) != 1:
			return "wheels_due reads 1 with the nuts due."
		if not gs.quest_state.has(QUEST) or not QuestEngine.has_minigame_step(gs, GAME, "", HOST):
			return "With the nuts due the morning brings the ask, and its step carries the game: %s" % [gs.quest_state]
		for game: String in QuestEngine.MINIGAMES:
			if game != GAME and QuestEngine.has_minigame_step(gs, game, "", HOST):
				return "The step carries no other game: %s." % game
		if _lines(gs, "star order") != 1:
			return "Bram says so: %s" % [gs.phone_log]
		return "")


func test_a_poor_try_gives_what_a_skip_gives() -> String:
	return _run(func() -> String:
		var skip: Node = _serviced([])
		if skip == null or skip.wheels_due() or _lines(skip, DONE) != 1 or _lines(skip, BONUS) != 0:
			return "A service with no game does the step and the quest is paid plainly."
		var plain: String = var_to_str(skip.farm_to_dict())
		for score: int in [0, 1, 59, -40]:
			var poor: Node = _serviced([score])
			if poor == null or var_to_str(poor.farm_to_dict()) != plain or poor.phone_log != skip.phone_log:
				return "A try of %d leaves the farm a skip leaves, to the last field." % score
		return "")


func test_a_score_changes_only_the_xp_and_the_quest_grade() -> String:
	return _run(func() -> String:
		var skip: Node = _serviced([])
		if skip == null:
			return "Due nuts are serviced."
		var base_xp: int = skip.action_xp(SOURCE, HOST)
		var source: float = skip._lab_source_xp(LAB_SOURCE)
		if base_xp <= 0 or source <= 0.0 or skip.credits <= 0:
			return "The plain service gives Robotics XP and lab XP, and the quest pays credits."
		# score: [XP factor, share of the quest's credits more, bonus lines, Bram's line]
		var want: Dictionary = { 60: [1.15, 0.0, 0, 0], 79: [1.15, 0.0, 0, 0], 80: [1.3, 0.1, 1, 0], 95: [1.5, 0.2, 1, 1], 100: [1.5, 0.2, 1, 1] }
		var pay: int = int(QuestEngine.quests()[0]["rewards"]["credits"])
		for score: int in want:
			var gs: Node = _serviced([score])
			if gs == null:
				return "The nuts are serviced at any score."
			if _bay(gs) != _bay(skip):
				return "A score of %d is the same service, with the same distance to the next: %s, not %s" % [score, _bay(gs), _bay(skip)]
			var factor: float = want[score][0]
			if gs.action_xp(SOURCE, HOST) != roundi(base_xp * factor) or gs.skill_xp(SKILL, HOST) - skip.skill_xp(SKILL, HOST) != roundi(base_xp * factor) - base_xp:
				return "At %d the service's Robotics XP is times %f: %d of %d." % [score, factor, gs.action_xp(SOURCE, HOST), base_xp]
			var more_lab: int = roundi(source * factor * gs.lab_xp_scale()) - roundi(source * skip.lab_xp_scale())
			if gs.lab_xp - skip.lab_xp != more_lab or more_lab <= 0:
				return "At %d the service's lab XP is times %f: %d more, not %d." % [score, factor, gs.lab_xp - skip.lab_xp, more_lab]
			if gs.credits - skip.credits != roundi(pay * float(want[score][1])):
				return "At %d the quest pays %d CR more, not %d." % [score, roundi(pay * float(want[score][1])), gs.credits - skip.credits]
			if _lines(gs, DONE) != 1 or _lines(gs, BONUS) != want[score][2] or _lines(gs, BRAM_REFERENCE) != want[score][3]:
				return "At %d the quest is done once, with %d bonus lines and Bram's line %d times: %s" % [score, want[score][2], want[score][3], gs.phone_log]
			# Every other skill is the skip's.
			for skill: String in skip.player_skill_xp.get(HOST, {}):
				if skill != SKILL and gs.skill_xp(skill, HOST) != skip.skill_xp(skill, HOST):
					return "A score moved %s XP." % skill
			# And of all the farm saves, only the XP and the quest's pay differ.
			for field: String in _differing(gs, skip):
				if not field in SCORE_MOVES:
					return "A score of %d changed the farm's %s: only %s may differ (%s did)." % [score, field, SCORE_MOVES, _differing(gs, skip)]
		return "")


func test_a_score_is_held_to_0_to_100() -> String:
	return _run(func() -> String:
		var top: Node = _serviced([100])
		var over: Node = _serviced([5000000])
		if top == null or over == null or var_to_str(over.farm_to_dict()) != var_to_str(top.farm_to_dict()):
			return "A score over 100 is 100."
		var commands: Node = _farm()
		if commands.problem(SERVICE, ["100"]) == "" or commands.problem(SERVICE, [1.5]) == "" or commands.problem(SERVICE, [90, 90]) == "":
			return "A score that is not one whole number is not well formed."
		for bad: Array in [["100"], [1.5], [90, 90]]:
			var done: Variant = commands.execute(HOST, SERVICE, bad)
			if done is String and done == "":
				return "A score that is not one whole number is refused: %s" % [bad]
		if not commands.state.wheels_due() or commands.state.action_count(SOURCE, HOST) != 0:
			return "A refused service services nothing."
		return "")


func test_a_score_with_no_open_step_is_a_skip() -> String:
	var no_quest: String = _run(func() -> String:
		# No such quest at all: the host's and a guest's 100 are both skips.
		var plain: Node = _serviced([], false)
		var sent: Node = _serviced([100], false)
		if plain == null or sent == null or var_to_str(sent.farm_to_dict()) != var_to_str(plain.farm_to_dict()):
			return "With no open step a score of 100 leaves the farm a plain service leaves."
		var commands: Node = _farm(false)
		var host: Node = commands.state
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		if MinigameScore.service_allowed(host, id, 100) != MinigameScore.SKIPPED or commands.execute(id, SERVICE, [100]) != "":
			return "A guest's score with no open step is a skip, and the nuts are serviced all the same."
		if host.action_xp(SOURCE, id) != plain.action_xp(SOURCE, HOST) or host.wheels_due():
			return "The guest's service gives the plain XP: %d, not %d." % [host.action_xp(SOURCE, id), plain.action_xp(SOURCE, HOST)]
		return "", false)
	if no_quest != "":
		return no_quest
	return _run(func() -> String:
		# Not yet offered: the quest is in the data, and no morning has brought it.
		var early: Node = _serviced([100], false)
		var plain: Node = _serviced([], false)
		if early == null or plain == null or early.skill_xp(SKILL, HOST) != plain.skill_xp(SKILL, HOST) or early.lab_xp != plain.lab_xp:
			return "Before the ask is made a score counts for nothing."
		# Once the step is done, the next service's score is a skip.
		var commands: Node = _farm()
		var gs: Node = commands.state
		if MinigameScore.service_allowed(gs, HOST, 100) != 100 or commands.execute(HOST, SERVICE, [100]) != "" or _lines(gs, DONE) != 1:
			return "The first service is graded and the quest is done: %s" % [gs.phone_log]
		var xp: int = gs.action_xp(SOURCE, HOST)
		var lab: int = gs.lab_xp
		var credits: int = gs.credits
		gs.add_rover_usage(gs.wheel_service_due_m(), HOST)
		if MinigameScore.service_allowed(gs, HOST, 100) != MinigameScore.SKIPPED or commands.execute(HOST, SERVICE, [100]) != "":
			return "With the step done the next service's score is a skip, and the nuts are still done."
		if gs.action_xp(SOURCE, HOST) - xp != plain.action_xp(SOURCE, HOST) or gs.lab_xp - lab != roundi(gs._lab_source_xp(LAB_SOURCE) * gs.lab_xp_scale()) or gs.credits != credits:
			return "That service gives the plain XP and nothing more: %d Robotics XP." % (gs.action_xp(SOURCE, HOST) - xp)
		if _lines(gs, BONUS) != 1 or gs.wheels_due() or gs.action_count(SOURCE, HOST) != 2:
			return "The quest is paid once, and both services are counted."
		return "")


func test_a_guest_s_service_is_graded_like_the_host_s() -> String:
	return _run(func() -> String:
		var commands: Node = _farm()
		var host: Node = commands.state
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.update_quests()
		# The rover is the farm's, and so is the ask: the guest's service does it.
		if MinigameScore.service_allowed(host, id, 97) != 97:
			return "The farm's open step lets a guest's score count."
		# What a guest's PC asks first: the same arguments are well formed there.
		if commands.problem(SERVICE, [97]) != "" or commands.problem(SERVICE, []) != "":
			return "A service is asked for with a score or with none: %s" % commands.problem(SERVICE, [97])
		if commands.execute(id, SERVICE, [97]) != "" or _lines(host, DONE) != 1 or _lines(host, BRAM_REFERENCE) != 1:
			return "A guest's Reference service does the farm's quest with Bram's line: %s" % [host.phone_log]
		if host.action_xp(SOURCE, id) != roundi(25 * 1.5) or host.action_xp(SOURCE, HOST) != 0:
			return "The XP is the guest's own: %d." % host.action_xp(SOURCE, id)
		return "")


func test_a_refused_service_takes_no_score() -> String:
	return _run(func() -> String:
		# The nuts are not due: Bram refuses, and a score sent with it is nothing.
		var commands: Node = _farm(true, false)
		var gs: Node = commands.state
		var before: String = var_to_str(gs.farm_to_dict())
		var refused: Variant = commands.execute(HOST, SERVICE, [100])
		if not refused is String or refused == "" or var_to_str(gs.farm_to_dict()) != before:
			return "A service that is not due is refused in words and changes nothing, whatever the score: %s" % [refused]
		return "")


func test_no_save_or_message_changed() -> String:
	if SessionScript.PROTOCOL != 29:
		return "The score rides as a scored action's last argument: the protocol is still 18."
	if SaveGame.VERSION != 1:
		return "Nothing new is saved: the save version is still 1."
	if not SERVICE in CommandsScript.SCORED:
		return "The wheel service is a scored action."
	return ""
