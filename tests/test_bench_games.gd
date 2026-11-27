extends RefCounted
## The bench's instrument-kind games (Fixed Points for a thermometer, Pump to
## Points for a pressure gauge) and the daily rotation that picks today's game:
## the pick is the day plus the instrument, the same on every machine; the games
## score as Set the Zero does and skip, Relaxed and a poor try behave as it does.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FIXED_SCENE: String = "res://ui/minigames/fixed_points.tscn"
const PUMP_SCENE: String = "res://ui/minigames/pump_to_points.tscn"
const STEP: float = 1.0 / 240.0
const SEED: int = 5811

var _scores: Array[int] = []


func _on_finished(score: int) -> void:
	_scores.append(score)


func _state() -> Node:
	var state: Node = GameStateScript.new()
	state.build_registry()
	return state


func _game(scene: String) -> BenchGame:
	var game: BenchGame = (load(scene) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_scores.clear()
	game.finished.connect(_on_finished)
	return game


## Plays Fixed Points well: each point is read as the reading crosses the middle.
func _read_well(game: FixedPoints) -> int:
	var gone: float = 0.0
	while game.stage() != BenchGame.Stage.RESULT and gone < 60.0:
		if game.stage() == BenchGame.Stage.PLAY and game._time >= BenchGame.ARM_S and absf(game.reading()) <= game.sweet_half() * 0.5:
			game.press()
		game.advance(STEP)
		gone += STEP
	return game._score


## Plays Fixed Points badly: each point is read when the reading is far out.
func _read_badly(game: FixedPoints) -> int:
	var gone: float = 0.0
	while game.stage() != BenchGame.Stage.RESULT and gone < 60.0:
		if game.stage() == BenchGame.Stage.PLAY and game._time >= BenchGame.ARM_S and absf(game.reading()) >= 0.4:
			game.press()
		game.advance(STEP)
		gone += STEP
	return game._score


## Plays Pump to Points well: a stroke whenever the pressure is under the middle.
func _pump_well(game: PumpToPoints) -> int:
	var gone: float = 0.0
	while game.stage() != BenchGame.Stage.RESULT and gone < 120.0:
		if game.stage() == BenchGame.Stage.PLAY and game.pressure() < game.target() - 0.02:
			game.press()
		game.advance(STEP)
		gone += STEP
	return game._score


## Plays it badly: it never pumps, so no point is reached.
func _pump_badly(game: PumpToPoints) -> int:
	var gone: float = 0.0
	while game.stage() != BenchGame.Stage.RESULT and gone < 120.0:
		game.advance(0.05)
		gone += 0.05
	return game._score


# --- The rotation ------------------------------------------------------------------

func test_the_rotation_is_the_same_every_time_for_a_day_and_an_instrument() -> String:
	var state: Node = _state()
	var problem: String = ""
	for id: String in ["terrarium_thermometer", "rover_tire_pressure", "dome_pressure", "hygrometer"]:
		for day: int in range(1, 40):
			var first: String = MinigameScore.bench_game(state, id, day)
			var again: String = MinigameScore.bench_game(state, id, day)
			if first != again:
				problem = "%s on day %d gave %s then %s." % [id, day, first, again]
	if MinigameScore.id_offset("terrarium_thermometer") != MinigameScore.id_offset("terrarium_thermometer"):
		problem = "The id's number must not change between calls."
	state.free()
	return problem


func test_every_listed_game_comes_round() -> String:
	var state: Node = _state()
	var problem: String = ""
	for id: String in ["terrarium_thermometer", "rover_tire_pressure", "dome_pressure"]:
		var listed: Array[String] = MinigameScore.games_for_bench(state, id)
		if listed.size() < 2:
			problem = "%s should have a second game: %s" % [id, listed]
			break
		var seen: Dictionary = {}
		for day: int in range(1, 1 + listed.size()):
			seen[MinigameScore.bench_game(state, id, day)] = true
		if seen.size() != listed.size():
			problem = "%s: %d days did not show every game %s, got %s." % [id, listed.size(), listed, seen.keys()]
			break
		# Over a longer run, no game is dropped and none is a daily habit.
		var days_of: Dictionary = {}
		for day: int in range(1, 61):
			var one: String = MinigameScore.bench_game(state, id, day)
			days_of[one] = int(days_of.get(one, 0)) + 1
		for game: String in listed:
			if int(days_of.get(game, 0)) < 20:
				problem = "%s: %s came on only %d of 60 days." % [id, game, int(days_of.get(game, 0))]
	state.free()
	return problem


func test_an_instrument_with_one_game_never_changes() -> String:
	var state: Node = _state()
	var problem: String = ""
	for id: String in ["hygrometer", "reference_gauge", "rover_steering_encoder", "soil_probe"]:
		if state.get_sensor(id) == null:
			continue
		var only: String = MinigameScore.game_for(state, id)
		for day: int in range(1, 60):
			if MinigameScore.bench_game(state, id, day) != only:
				problem = "%s changed game on day %d." % [id, day]
				break
	state.free()
	return problem


func test_the_rotation_leaves_the_scoring_game_alone() -> String:
	var state: Node = _state()
	var problem: String = ""
	# game_for still names the scoring family: the quests and the host read it.
	if MinigameScore.game_for(state, "terrarium_thermometer") != MinigameScore.SET_THE_ZERO:
		problem = "The thermometer's scoring game is still Set the Zero."
	if problem == "" and MinigameScore.game_for(state, "hygrometer") != MinigameScore.HOLD_THE_READING:
		problem = "The hygrometer's scoring game is still Hold the Reading."
	# A unit that plays Hold the Reading keeps it: the extras are Set the Zero's.
	if problem == "" and MinigameScore.games_for_bench(state, "hygrometer") != [MinigameScore.HOLD_THE_READING]:
		problem = "Hold the Reading has no extras."
	if problem == "" and not MinigameScore.BENCH_GAMES == [MinigameScore.SET_THE_ZERO, MinigameScore.HOLD_THE_READING]:
		problem = "BENCH_GAMES, which the quests read, is unchanged."
	state.free()
	return problem


func test_the_new_games_have_names_and_result_lines() -> String:
	if MinigameScore.game_name(MinigameScore.FIXED_POINTS) != "Fixed Points" or MinigameScore.game_name(MinigameScore.PUMP_TO_POINTS) != "Pump to Points":
		return "The bench names the new games."
	if MinigameScore.game_name(MinigameScore.SET_THE_ZERO) != "Set the Zero":
		return "The bench names the old ones too."
	if not MinigameScore.result_text(97, MinigameScore.FIXED_POINTS).begins_with("Fixed score 97 of 100: REFERENCE, as-left residual 40 % of standard"):
		return "Fixed Points reads as Set the Zero: %s" % MinigameScore.result_text(97, MinigameScore.FIXED_POINTS)
	if MinigameScore.result_text(97) != "Zero score 97 of 100: REFERENCE, as-left residual 40 % of standard.":
		return "The old text is as it was."
	return ""


# --- Fixed Points ---------------------------------------------------------------------

func test_fixed_points_perfect_play_is_a_pass() -> String:
	for motion_seed: int in [1, 7, SEED, 4242]:
		var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
		game.play(0.0, MinigameSettings.Mode.STANDARD, motion_seed, "TT-4")
		var score: int = _read_well(game)
		game.free()
		if score < 95:
			return "Seed %d: reading at the middle scored %d, under Reference." % [motion_seed, score]
	return ""


func test_fixed_points_bad_play_fails() -> String:
	for motion_seed: int in [1, 7, SEED, 4242]:
		var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
		game.play(0.0, MinigameSettings.Mode.STANDARD, motion_seed)
		var score: int = _read_badly(game)
		game.free()
		if score >= MinigameScore.GRADES[-1]["from"]:
			return "Seed %d: reading far out scored %d, a grade." % [motion_seed, score]
	return ""


func test_fixed_points_skip_and_relaxed() -> String:
	var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	var problem: String = ""
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	game.skip()
	if _scores != [MinigameScore.SKIPPED] or game.visible or game.is_playing():
		problem = "A skip ends it with no score: %s" % [_scores]
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var standard: float = game.sweet_half()
	var score: int = _read_well(game)
	game.skip()
	if problem == "" and _scores != [score]:
		problem = "Esc at the result keeps the score: %s vs %d" % [_scores, score]
	game.play(0.0, MinigameSettings.Mode.RELAXED, SEED)
	var relaxed: float = game.sweet_half()
	if problem == "" and relaxed <= standard:
		problem = "Relaxed widens the green: %f vs %f." % [relaxed, standard]
	var relaxed_score: int = _read_well(game)
	if problem == "" and relaxed_score < 95:
		problem = "Perfect play on Relaxed still passes: %d" % relaxed_score
	game.free()
	return problem


func test_fixed_points_the_press_too_soon_is_not_taken() -> String:
	var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	game.press()
	var problem: String = ""
	if game.point_index() != 0 or not game.point_scores().is_empty():
		problem = "A press at once does not read the first point."
	game.free()
	return problem


# --- Pump to Points -----------------------------------------------------------------------

func test_pump_to_points_perfect_play_is_a_pass() -> String:
	for motion_seed: int in [1, 7, SEED, 4242]:
		var game: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
		game.play(0.0, MinigameSettings.Mode.STANDARD, motion_seed, "TP-1")
		var score: int = _pump_well(game)
		game.free()
		if score < 95:
			return "Seed %d: keeping to each point scored %d, under Reference." % [motion_seed, score]
	return ""


func test_pump_to_points_bad_play_fails() -> String:
	var game: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var score: int = _pump_badly(game)
	game.free()
	if score != 0:
		return "Never pumping scored %d, not 0." % score
	# One stroke is a leak away from nothing.
	var careless: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	careless.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	careless.advance(BenchGame.ARM_S)
	careless.press()
	var second: int = _pump_badly(careless)
	careless.free()
	if second >= MinigameScore.GRADES[-1]["from"]:
		return "One stroke scored %d, a grade." % second
	return ""


func test_pump_to_points_skip_and_relaxed() -> String:
	var game: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	var problem: String = ""
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	game.skip()
	if _scores != [MinigameScore.SKIPPED] or game.visible or game.is_playing():
		problem = "A skip ends it with no score: %s" % [_scores]
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var standard: float = game.band()
	game.skip()
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.RELAXED, SEED)
	if problem == "" and game.band() <= standard:
		problem = "Relaxed widens the band: %f vs %f." % [game.band(), standard]
	var score: int = _pump_well(game)
	if problem == "" and score < 95:
		problem = "Perfect play on Relaxed still passes: %d" % score
	game.free()
	return problem


func test_pump_to_points_the_skill_widens_the_band() -> String:
	if PumpToPoints.band_half_width(1.0) <= PumpToPoints.band_half_width(0.0):
		return "A skilled hand has a wider band."
	if not is_equal_approx(PumpToPoints.band_half_width(1.0), 2.0 * PumpToPoints.band_half_width(0.0)):
		return "Calibration 1 doubles it, as for Set the Zero."
	return ""


func test_the_frame_step_is_capped() -> String:
	if BenchGame.frame_step(5.0) != BenchGame.MAX_STEP_S or BenchGame.frame_step(-1.0) != 0.0:
		return "A hitch moves the game on by at most one capped step."
	return ""
