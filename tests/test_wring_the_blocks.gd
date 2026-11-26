extends RefCounted
## Wring the Blocks (docs/design/quests_levels_story.md section 7, mini-game 2):
## the length asked for, the scoring, the green band Earthworks widens, the
## grades, and the game played with no frames.

const GAME_SCENE: String = "res://ui/minigames/wring_the_blocks.tscn"
const SEED: int = 811
const STEP: float = 1.0 / 60.0
## A stack of the three smallest pieces from a tray of six.
const HELD: Array[int] = [0, 1, 2, 3, 4, 5]

var _scores: Array[int] = []


func _on_finished(score: int) -> void:
	_scores.append(score)


func _game() -> WringTheBlocks:
	var game: WringTheBlocks = (load(GAME_SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_scores.clear()
	game.finished.connect(_on_finished)
	return game


func _stack() -> Dictionary:
	return GaugeStack.target(HELD, SEED)


## Picks the pieces the length was made from.
func _pick(game: WringTheBlocks, stack: Dictionary) -> void:
	for size: int in stack["sizes"]:
		game.pick(game.tray().find(size))


## Plays every joint and returns the score the game ended with. `slack` is how
## far from the middle of the green the bot lets the speed run before it acts,
## and `late` how many degrees past the mark it lets go of the turn. With
## `lean` it never lets go of anything.
func _play(game: WringTheBlocks, slack: float = 0.0, late: float = 0.0, lean: bool = false) -> int:
	var guard: int = 0
	while game.is_playing() and guard < 60 * 120:
		guard += 1
		match game.stage():
			WringTheBlocks.Stage.SLIDE:
				if lean or game.rate() < WringTheBlocks.GREEN_CENTRE - slack:
					game.hold(true)
				elif game.rate() > WringTheBlocks.GREEN_CENTRE + slack:
					game.hold(false)
			WringTheBlocks.Stage.TURN:
				if lean or game.angle() < WringTheBlocks.TURN_MARK + late:
					game.hold(true)
				else:
					game.hold(false)
			WringTheBlocks.Stage.RESULT:
				game.hold(false)
		game.advance(STEP)
	return _scores[-1] if not _scores.is_empty() else -99


func _round(share: float, mode: int, motion_seed: int, slack: float = 0.0, late: float = 0.0, lean: bool = false) -> int:
	var game: WringTheBlocks = _game()
	var stack: Dictionary = _stack()
	game.play(share, mode, motion_seed, stack)
	_pick(game, stack)
	var score: int = _play(game, slack, late, lean)
	game.free()
	return score


# --- The length -------------------------------------------------------------------

func test_the_length_is_the_sum_of_pieces_held() -> String:
	var held: Array[int] = [3, 17, 40, 41, 60, 72, 80]
	for pick_seed: int in 40:
		var stack: Dictionary = GaugeStack.target(held, pick_seed)
		var sizes: Array = stack["sizes"]
		if sizes.size() != GaugeStack.STACK_BLOCKS or (stack["tray"] as Array).size() != GaugeStack.TRAY_BLOCKS:
			return "A length is made of %d pieces from a tray of %d: %s" % [GaugeStack.STACK_BLOCKS, GaugeStack.TRAY_BLOCKS, stack]
		var sum: int = 0
		for index: int in sizes:
			if not index in held or not index in stack["tray"]:
				return "Every piece of the length is one the farm holds, and is on the tray: %s" % [stack]
			sum += GaugeSet.SIZES_TEN_THOUSANDTHS[index]
		for index: int in stack["tray"]:
			if not index in held:
				return "The tray holds only pieces the farm holds: %s" % [stack]
		if int(stack["target"]) != sum or not GaugeStack.is_made_by(sum, sizes):
			return "The length is the exact sum of its pieces: %s" % [stack]
		if GaugeStack.target(held, pick_seed) != stack:
			return "The same pieces and seed give the same length."
	var seen: Dictionary = {}
	for pick_seed: int in 40:
		seen[GaugeStack.target(held, pick_seed)["target"]] = true
	return "" if seen.size() > 3 else "Other seeds ask for other lengths: %s" % [seen.keys()]


func test_a_stack_takes_two_pieces() -> String:
	if not GaugeStack.target([], 1).is_empty() or not GaugeStack.target([4], 1).is_empty():
		return "With fewer than two pieces there is no length to build."
	# Pieces that are no size of the set, or there twice, are not counted.
	if not GaugeStack.target([4, 4, -1, 999, "5"], 1).is_empty():
		return "Only real pieces count, each once."
	var two: Dictionary = GaugeStack.target([4, 9], 1)
	if two.get("sizes") != [4, 9] or int(two["target"]) != GaugeSet.SIZES_TEN_THOUSANDTHS[4] + GaugeSet.SIZES_TEN_THOUSANDTHS[9]:
		return "Two pieces make a stack of two: %s" % [two]
	if GaugeStack.is_made_by(GaugeSet.SIZES_TEN_THOUSANDTHS[4], [4]):
		return "One block is not a stack: there is no joint to wring."
	if GaugeStack.total([4, 4]) != -1 or GaugeStack.total([999]) != -1:
		return "A set holds one of each size."
	if GaugeStack.stack_seed(7, 3, "player_1") == GaugeStack.stack_seed(7, 4, "player_1") or GaugeStack.stack_seed(7, 3, "player_1") == GaugeStack.stack_seed(7, 3, "player_2"):
		return "The length is the day's and the player's."
	return "" if GaugeStack.length_text(3511) == "0.3511 in" else "A length is written as inches to four places: %s" % GaugeStack.length_text(3511)


# --- The scoring ------------------------------------------------------------------

func test_the_scores_run_from_0_to_100() -> String:
	if WringTheBlocks.slide_score(0.0) != 0 or WringTheBlocks.slide_score(WringTheBlocks.FULL_SHARE) != 100 or WringTheBlocks.slide_score(1.0) != 100:
		return "A slide all in the green is 100 and one never in it is 0."
	if WringTheBlocks.slide_score(0.45) != 50:
		return "Half of a full share is half the slide's score."
	var mark: float = WringTheBlocks.BASE_MARK
	if WringTheBlocks.turn_score(90.0, mark) != 100 or WringTheBlocks.turn_score(90.0 + mark, mark) != WringTheBlocks.SWEET_SCORE:
		return "A turn let go at the mark is 100, and at the mark's edge 95."
	if WringTheBlocks.turn_score(90.0 - mark * 1.01, mark) >= WringTheBlocks.SWEET_SCORE:
		return "Outside the mark a turn is under 95."
	if WringTheBlocks.turn_score(0.0, mark) != 0 or WringTheBlocks.turn_score(WringTheBlocks.TURN_END, mark) != 0:
		return "A turn not made, or run to its end, is 0."
	var last: int = 100
	for tenth: int in range(0, 400):
		var score: int = WringTheBlocks.turn_score(90.0 + tenth / 10.0, mark)
		if score > last or score < 0:
			return "A turn scores less the farther from the mark it is let go."
		last = score
	if WringTheBlocks.joint_score(100, 100) != 100 or WringTheBlocks.joint_score(0, 0) != 0 or WringTheBlocks.joint_score(100, 0) != 60:
		return "A joint is 60 % slide and 40 % turn."
	if WringTheBlocks.stack_score([100, 50]) != 75 or WringTheBlocks.stack_score([]) != MinigameScore.SKIPPED:
		return "A stack's score is the mean of its joints', and none with no joint."
	return ""


func test_the_grades_are_set_the_zero_s() -> String:
	for pair: Array in [[100, "Reference"], [95, "Reference"], [94, "Fine"], [80, "Fine"], [79, "Good"], [60, "Good"]]:
		if MinigameScore.grade_name(pair[0]) != pair[1] or not MinigameScore.is_graded(pair[0]):
			return "%d is %s." % pair
	# Section 7.2: a poor try is worth what a skip is.
	for score: int in [59, 30, 0, MinigameScore.SKIPPED]:
		if MinigameScore.is_graded(score) or MinigameScore.quest_bonus(score) != 0.0 or MinigameScore.earns_line(score):
			return "A score of %d earns nothing, as a skip does." % score
	if MinigameScore.quest_bonus(80) != 0.1 or MinigameScore.quest_bonus(95) != 0.2 or MinigameScore.quest_bonus(60) != 0.0:
		return "Fine adds 10 %, Reference 20 % and Good nothing."
	if MinigameScore.grade_text(WringTheBlocks.GAME_NAME, 97) != "Wring score 97 of 100: REFERENCE." or MinigameScore.grade_text(WringTheBlocks.GAME_NAME, -1) != "":
		return "The result names the grade: %s" % MinigameScore.grade_text(WringTheBlocks.GAME_NAME, 97)
	return ""


func test_earthworks_widens_the_green() -> String:
	var narrow: float = WringTheBlocks.green_half_width(0.0)
	if not is_equal_approx(narrow, WringTheBlocks.BASE_GREEN) or not is_equal_approx(WringTheBlocks.green_half_width(1.0), narrow * (1.0 + WringTheBlocks.SKILL_WIDENING)):
		return "The green is its base at no skill and widened in full at all of it."
	if WringTheBlocks.green_half_width(0.5) <= narrow or WringTheBlocks.green_half_width(0.5) >= WringTheBlocks.green_half_width(1.0):
		return "More skill is a wider green."
	if WringTheBlocks.green_half_width(7.0) != WringTheBlocks.green_half_width(1.0) or WringTheBlocks.green_half_width(-1.0) != narrow:
		return "The share is held to 0 to 1."
	if not is_equal_approx(WringTheBlocks.mark_half_width(1.0), WringTheBlocks.BASE_MARK * (1.0 + WringTheBlocks.SKILL_WIDENING)):
		return "The turn's mark is widened as the green is."
	if not WringTheBlocks.is_in_green(WringTheBlocks.GREEN_CENTRE + narrow * 1.5, WringTheBlocks.green_half_width(1.0)) or WringTheBlocks.is_in_green(WringTheBlocks.GREEN_CENTRE + narrow * 1.5, narrow):
		return "A speed outside the narrow green is inside the wide one."
	# The share is the player's Earthworks, as Set the Zero's is their Calibration.
	var gs: Node = (load("res://scripts/autoload/GameState.gd") as GDScript).new()
	gs.build_registry()
	var low: float = MinigameScore.sweet_share(gs, "player_2", MinigameScore.WRING_SKILL)
	gs.player_skill_xp["player_2"] = { MinigameScore.WRING_SKILL: gs.xp_for_level(40) }
	var high: float = MinigameScore.sweet_share(gs, "player_2", MinigameScore.WRING_SKILL)
	var other: float = MinigameScore.sweet_share(gs, "player_2")
	gs.free()
	if MinigameScore.WRING_SKILL != "earthworks" or high <= low or other != low:
		return "The green widens with the player's own Earthworks, and no other skill: %s, %s, %s." % [low, high, other]
	# The same rough hands score more with the wider green.
	var worse: int = 0
	var better: int = 0
	for motion_seed: int in 6:
		worse += _round(0.0, MinigameSettings.Mode.STANDARD, motion_seed, 0.14, 7.0)
		better += _round(1.0, MinigameSettings.Mode.STANDARD, motion_seed, 0.14, 7.0)
	return "" if better > worse else "The same play must score more at full Earthworks: %d against %d." % [better, worse]


func test_the_difficulty_sets_the_green_and_the_speed() -> String:
	var standard: float = WringTheBlocks.green_half_width(0.0, MinigameSettings.sweet_factor(MinigameSettings.Mode.STANDARD))
	if WringTheBlocks.green_half_width(0.0, MinigameSettings.sweet_factor(MinigameSettings.Mode.RELAXED)) <= standard:
		return "Relaxed has a wider green."
	if WringTheBlocks.green_half_width(0.0, MinigameSettings.sweet_factor(MinigameSettings.Mode.SHARP)) >= standard:
		return "Sharp has a narrower green."
	var game: WringTheBlocks = _game()
	game.play(0.0, MinigameSettings.Mode.RELAXED, 1, _stack())
	var relaxed: float = game.green_half()
	game.play(0.0, MinigameSettings.Mode.SHARP, 1, _stack())
	var sharp: float = game.green_half()
	game.free()
	return "" if relaxed > standard and sharp < standard else "The game takes the difficulty's green."


# --- The game ---------------------------------------------------------------------

func test_a_careful_player_reaches_reference() -> String:
	for motion_seed: int in 8:
		var score: int = _round(0.0, MinigameSettings.Mode.STANDARD, motion_seed)
		if score < 95:
			return "Careful play at Earthworks 1 on Standard must reach Reference: %d with seed %d." % [score, motion_seed]
	return ""


func test_a_careless_player_scores_poorly() -> String:
	for motion_seed: int in 8:
		var score: int = _round(1.0, MinigameSettings.Mode.RELAXED, motion_seed, 0.0, 0.0, true)
		if score < 0 or MinigameScore.is_graded(score):
			return "Leaning on the button must earn no grade, even with the widest green: %d." % score
	return ""


func test_the_motion_is_the_seed_s() -> String:
	var first: int = _round(0.3, MinigameSettings.Mode.STANDARD, 42, 0.12, 5.0)
	if _round(0.3, MinigameSettings.Mode.STANDARD, 42, 0.12, 5.0) != first:
		return "The same seed and the same play give the same score."
	var seen: Dictionary = {}
	for motion_seed: int in 12:
		seen[_round(0.3, MinigameSettings.Mode.STANDARD, motion_seed, 0.12, 5.0)] = true
	return "" if seen.size() > 1 else "Another seed is another drag and another turn."


func test_picking_takes_any_blocks_that_add_up() -> String:
	var game: WringTheBlocks = _game()
	var stack: Dictionary = _stack()
	game.play(0.0, MinigameSettings.Mode.STANDARD, 1, stack)
	var problem: String = ""
	if game.stage() != WringTheBlocks.Stage.PICK or not game.visible or game.tray().size() != 6:
		problem = "The game opens on the tray."
	var wrong: int = -1
	for place: int in game.tray().size():
		if not game.tray()[place] in stack["sizes"]:
			wrong = place
	game.pick(wrong)
	game.pick((game.tray() as Array).find(stack["sizes"][0]))
	if problem == "" and (game.stage() != WringTheBlocks.Stage.PICK or game.picked_sizes().size() != 2):
		problem = "Blocks that don't add up are no stack yet."
	# Put back, and the right ones taken.
	game.pick(wrong)
	game.pick(-1)
	game.pick(99)
	if problem == "" and game.picked_sizes() != [stack["sizes"][0]]:
		problem = "Picking a block again puts it back: %s" % [game.picked_sizes()]
	game.pick((game.tray() as Array).find(stack["sizes"][1]))
	game.pick((game.tray() as Array).find(stack["sizes"][2]))
	if problem == "" and (game.stage() != WringTheBlocks.Stage.SETTLE or game.joints() != 2):
		problem = "The right blocks go on to be wrung, a joint fewer than the blocks."
	game.free()
	if problem != "":
		return problem
	# Two other pieces that make the same length are as good: 0.1010 + 0.1040 is 0.1020 + 0.1030.
	game = _game()
	var sizes := GaugeSet.SIZES_TEN_THOUSANDTHS
	var a: int = sizes.find(1010)
	var b: int = sizes.find(1040)
	var c: int = sizes.find(1020)
	var d: int = sizes.find(1030)
	if a < 0 or b < 0 or c < 0 or d < 0:
		game.free()
		return "The test needs the set's 0.101 to 0.104 in pieces."
	game.play(0.0, MinigameSettings.Mode.STANDARD, 1, { "target": 2050, "sizes": [a, b], "tray": [a, b, c, d] })
	game.pick(game.tray().find(c))
	game.pick(game.tray().find(d))
	if game.stage() != WringTheBlocks.Stage.SETTLE:
		problem = "Any pieces that add up to the length are taken."
	game.free()
	return problem


func test_the_button_and_the_cursor_pick() -> String:
	var game: WringTheBlocks = _game()
	var stack: Dictionary = _stack()
	game.play(0.0, MinigameSettings.Mode.STANDARD, 1, stack)
	var problem: String = ""
	# The cursor wraps, and the button takes what it is on.
	game.move_cursor(-1)
	game.hold(true)
	game.hold(false)
	if game.picked_sizes() != [game.tray()[-1]]:
		problem = "Left from the first block is the last, and the button takes it: %s" % [game.picked_sizes()]
	game.hold(true)
	game.hold(false)
	game.move_cursor(1)
	if problem == "" and not game.picked_sizes().is_empty():
		problem = "The button puts a taken block back."
	game.free()
	return problem


func test_nothing_moves_until_the_button_is_pressed() -> String:
	var game: WringTheBlocks = _game()
	var stack: Dictionary = _stack()
	game.play(0.0, MinigameSettings.Mode.STANDARD, 3, stack)
	var problem: String = ""
	game.advance(30.0)
	if game.stage() != WringTheBlocks.Stage.PICK:
		problem = "The tray waits for the player."
	_pick(game, stack)
	game.advance(WringTheBlocks.SETTLE_S + 0.1)
	game.advance(30.0)
	if problem == "" and (game.stage() != WringTheBlocks.Stage.SLIDE or game.travel() != 0.0 or game.rate() != 0.0):
		problem = "The slide waits for the first press."
	# A hold is let go by the game before 3 s (section 7.5).
	game.hold(true)
	game.advance(WringTheBlocks.MAX_HOLD_S + 0.1)
	var top: float = game.rate()
	game.advance(0.5)
	if problem == "" and (WringTheBlocks.MAX_HOLD_S >= 3.0 or game.rate() >= top):
		problem = "No hold is longer than 3 s: the game lets go."
	var guard: int = 0
	while game.stage() == WringTheBlocks.Stage.SLIDE and guard < 6000:
		guard += 1
		game.hold(game.rate() < WringTheBlocks.GREEN_CENTRE)
		game.advance(STEP)
	game.advance(30.0)
	if problem == "" and (game.stage() != WringTheBlocks.Stage.TURN or game.angle() != 0.0):
		problem = "The turn waits for a press of its own: a hold from the slide does not start it."
	game.hold(true)
	game.advance(3.0)
	if problem == "" and (game.joint_scores().size() != 1 or game.stage() != WringTheBlocks.Stage.SLIDE or game.travel() != 0.0):
		problem = "A turn held to its end is let go there, and the joint is scored."
	if problem == "" and not _scores.is_empty():
		problem = "Nothing ends the game but its last joint or a skip."
	game.free()
	return problem


func test_a_skip_and_a_stack_that_can_t_be_built_end_with_no_score() -> String:
	var game: WringTheBlocks = _game()
	var stack: Dictionary = _stack()
	var problem: String = ""
	game.skip()
	if not _scores.is_empty():
		problem = "A skip with no game open does nothing."
	game.play(0.0, MinigameSettings.Mode.STANDARD, 3, stack)
	game.skip()
	if problem == "" and (_scores != [MinigameScore.SKIPPED] or game.is_playing() or game.visible):
		problem = "A skip at the tray ends the game with no score: %s" % [_scores]
	game.play(0.0, MinigameSettings.Mode.STANDARD, 3, stack)
	_pick(game, stack)
	game.advance(WringTheBlocks.SETTLE_S + 0.1)
	game.hold(true)
	game.advance(0.5)
	game.skip()
	if problem == "" and _scores != [MinigameScore.SKIPPED, MinigameScore.SKIPPED]:
		problem = "A skip mid-slide ends the game with no score: %s" % [_scores]
	game.play(0.0, MinigameSettings.Mode.STANDARD, 3, {})
	game.play(0.0, MinigameSettings.Mode.STANDARD, 3, { "target": 1000, "tray": [0] })
	if problem == "" and (_scores.slice(2) != [MinigameScore.SKIPPED, MinigameScore.SKIPPED] or game.is_playing() or game.visible):
		problem = "With no stack to build the game ends at once, skipped: %s" % [_scores]
	# A played game ends once, with its score; a skip at the result keeps it.
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.STANDARD, 3, stack)
	_pick(game, stack)
	var guard: int = 0
	while game.stage() != WringTheBlocks.Stage.RESULT and guard < 60 * 120:
		guard += 1
		if game.stage() == WringTheBlocks.Stage.SLIDE:
			game.hold(game.rate() < WringTheBlocks.GREEN_CENTRE)
		elif game.stage() == WringTheBlocks.Stage.TURN:
			game.hold(game.angle() < WringTheBlocks.TURN_MARK)
		game.advance(STEP)
	if problem == "" and (game.stage() != WringTheBlocks.Stage.RESULT or not _scores.is_empty() or game.joint_scores().size() != 2):
		problem = "The last joint shows the result before the game ends."
	game.skip()
	if problem == "" and (_scores.size() != 1 or _scores[0] < 95 or game.is_playing()):
		problem = "A skip at the result keeps the score: %s" % [_scores]
	game.free()
	return problem
