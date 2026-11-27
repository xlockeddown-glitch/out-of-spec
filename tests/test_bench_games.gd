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
const SETTINGS_PATH: String = "user://test_bench_games_settings.cfg"

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


# --- Review round: the hash, the timing, the bench and the input ---------------------------

## FNV-1a, 32 bit: the values are pinned, so a changed hash (and with it every
## save's rotation, and a mixed-version pair's) is a failure.
func test_the_id_hash_is_pinned() -> String:
	var pinned: Dictionary = {
		"": 2166136261, "a": 3826002220, "terrarium_thermometer": 1405842113,
		"rover_tire_pressure": 4060438016, "dome_pressure": 2105899196,
	}
	for key: String in pinned:
		if MinigameScore.id_offset(key) != int(pinned[key]):
			return "id_offset(\"%s\") is %d, not %d." % [key, MinigameScore.id_offset(key), int(pinned[key])]
	return ""


func test_the_day_defaults_to_the_clock() -> String:
	var state: Node = _state()
	var problem: String = ""
	for id: String in ["terrarium_thermometer", "rover_tire_pressure", "hygrometer"]:
		if MinigameScore.bench_game(state, id) != MinigameScore.bench_game(state, id, GameClock.get_day_index()):
			problem = "%s: no day given is the clock's day." % id
	state.free()
	return problem


## Where the reading crosses the fixed point, after `after` seconds into a point.
func _crossing(game: FixedPoints, after: float) -> float:
	var step: float = 0.0005
	var t: float = after
	var last: float = FixedPoints.reading_at(game.point_index(), t * game._speed, game._phase)
	while t < 5.0:
		t += step
		var now: float = FixedPoints.reading_at(game.point_index(), t * game._speed, game._phase)
		if (last < 0.0) != (now < 0.0):
			return t - step * absf(now) / maxf(absf(now) + absf(last), 0.000001)
		last = now
	return -1.0


## Steps the game with frames of `dt` to just before `at`, then presses as a
## player would at `at`, between two frames.
func _press_between_frames(game: FixedPoints, at: float, dt: float) -> void:
	var frames: int = int(floor(at / dt))
	for i: int in frames:
		game.advance(dt)
	var lag: float = at - game._time
	game._live = true
	game._last_usec = Time.get_ticks_usec() - int(lag * 1000000.0)
	game.press()


func test_a_press_at_the_crossing_reaches_reference_at_any_frame_rate() -> String:
	for mode: int in [MinigameSettings.Mode.STANDARD, MinigameSettings.Mode.SHARP, MinigameSettings.Mode.RELAXED]:
		for dt: float in [1.0 / 30.0, 1.0 / 60.0]:
			for motion_seed: int in range(1, 25):
				var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
				game.play(0.0, mode, motion_seed)
				for point: int in 2:
					var at: float = _crossing(game, BenchGame.ARM_S + 0.05)
					if at < 0.0:
						game.free()
						return "Seed %d point %d: no crossing found." % [motion_seed, point]
					_press_between_frames(game, at, dt)
					if game.point_scores().size() != point + 1 or game.point_scores()[point] < 95:
						var got: Array[int] = game.point_scores().duplicate()
						game.free()
						return "Mode %d, %d fps, seed %d, point %d: a press at the crossing scored %s." % [mode, roundi(1.0 / dt), motion_seed, point, got]
					game.advance(BenchGame.SETTLE_S)
				game.free()
	return ""


## The press is scored where the needle is then, not where the last frame left it.
func test_the_press_is_scored_at_the_press_instant() -> String:
	var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var at: float = _crossing(game, BenchGame.ARM_S + 0.05)
	# The last frame was 0.09 s before the crossing: outside the green.
	game.advance(at - 0.09)
	var stale: float = absf(game.reading())
	var half: float = game.sweet_half()
	game._live = true
	game._last_usec = Time.get_ticks_usec() - 90000
	game.press()
	var scored: int = game.point_scores()[0] if not game.point_scores().is_empty() else -1
	game.free()
	if stale <= half:
		return "The test needs the last frame outside the green."
	if scored < 95:
		return "A press 90 ms after the last frame, at the crossing, scored %d." % scored
	return ""


## The green stays under the needle for about as long as Set the Zero's fine stop.
func test_the_boil_swing_stays_in_the_band_long_enough() -> String:
	for mode: int in [MinigameSettings.Mode.STANDARD, MinigameSettings.Mode.SHARP]:
		var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
		var shortest: float = 1000.0
		for motion_seed: int in range(1, 40):
			game.play(0.0, mode, motion_seed)
			game._point = 1
			game._phase = float(motion_seed) / 40.0
			var at: float = _crossing(game, 0.3)
			if at < 0.0:
				continue
			var inside: float = 0.0
			var t: float = at - 0.3
			while t < at + 0.3:
				if absf(FixedPoints.reading_at(1, t * game._speed, game._phase)) <= game.sweet_half():
					inside += 0.0005
				t += 0.0005
			shortest = minf(shortest, inside)
		game.free()
		if shortest < 0.055:
			return "Mode %d: the boil point is in the green for only %.0f ms." % [mode, shortest * 1000.0]
	return ""


func test_fixed_points_sharp_is_narrower_and_still_passable() -> String:
	var standard: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	standard.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var sharp: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	sharp.play(0.0, MinigameSettings.Mode.SHARP, SEED)
	var narrower: bool = sharp.sweet_half() < standard.sweet_half()
	var score: int = _read_well(sharp)
	standard.free()
	sharp.free()
	if not narrower:
		return "Sharp narrows the green."
	if score < 95:
		return "Perfect play on Sharp scored %d." % score
	return ""


func test_pump_to_points_sharp_is_narrower_and_still_passable() -> String:
	var standard: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	standard.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var sharp: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	sharp.play(0.0, MinigameSettings.Mode.SHARP, SEED)
	var narrower: bool = sharp.band() < standard.band()
	var score: int = _pump_well(sharp)
	standard.free()
	sharp.free()
	if not narrower:
		return "Sharp narrows the band."
	if score < MinigameScore.GRADES[-1]["from"]:
		return "Careful pumping on Sharp scored %d, under Good." % score
	return ""


func test_read_score_and_mean_score_edges() -> String:
	var half: float = 0.045
	if FixedPoints.read_score(0.0, half) != 100 or FixedPoints.read_score(half, half) != SetTheZero.SWEET_SCORE:
		return "The middle is 100 and the edge of the green is 95."
	if FixedPoints.read_score(-half, half) != SetTheZero.SWEET_SCORE:
		return "The score does not depend on the side."
	if FixedPoints.read_score(half * SetTheZero.MISS_AT, half) != 0 or FixedPoints.read_score(10.0, half) != 0:
		return "Far out scores 0."
	if FixedPoints.read_score(0.0, 0.0) != 100 or FixedPoints.read_score(0.5, 0.0) != 0:
		return "A band of nothing does not divide by zero."
	var last: int = 101
	for i: int in range(0, 40):
		var one: int = FixedPoints.read_score(half * float(i) * 0.25, half)
		if one > last:
			return "A worse reading never scores more."
		last = one
	var none: Array[int] = []
	var two: Array[int] = [95, 96]
	var high: Array[int] = [150, 150]
	var low: Array[int] = [-20]
	if BenchGame.mean_score(none) != 0 or BenchGame.mean_score(two) != 96 or BenchGame.mean_score(high) != 100 or BenchGame.mean_score(low) != 0:
		return "mean_score: empty 0, rounded, and held to 0 to 100."
	return ""


func test_pump_overshoot_scores_nothing() -> String:
	var game: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var gone: float = 0.0
	var gap: float = PumpToPoints.STROKE_GAP_S + 0.01
	while game.stage() != BenchGame.Stage.RESULT and gone < 120.0:
		if game.stage() == BenchGame.Stage.PLAY:
			game.press()
		game.advance(gap)
		gone += gap
	var score: int = game._score
	game.free()
	if score >= MinigameScore.GRADES[-1]["from"]:
		return "Pumping without stopping scored %d, a grade." % score
	return ""


## Pump's last strokes are not the press that closes the result.
func test_the_result_waits_longer_after_pump() -> String:
	var pump: PumpToPoints = _game(PUMP_SCENE) as PumpToPoints
	pump.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	_pump_well(pump)
	var problem: String = ""
	pump.advance(BenchGame.RESULT_ARM_S + 0.1)
	pump.press()
	if pump.stage() != BenchGame.Stage.RESULT or not _scores.is_empty():
		problem = "A stroke 0.5 s after Pump's result closes it."
	pump.advance(PumpToPoints.RESULT_ARM_PUMP_S - BenchGame.RESULT_ARM_S)
	pump.press()
	if problem == "" and _scores.size() != 1:
		problem = "A press after the longer arm closes it."
	pump.free()
	var fixed: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	fixed.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	_read_well(fixed)
	fixed.advance(BenchGame.RESULT_ARM_S + 0.01)
	fixed.press()
	if problem == "" and _scores.size() != 1:
		problem = "Fixed Points' result takes a press after RESULT_ARM_S."
	fixed.free()
	return problem


func _action(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


## The one press of a game: a point read, or a pump stroke.
func _presses(game: BenchGame) -> int:
	if game is PumpToPoints:
		return roundi((game as PumpToPoints).pressure() * 1000.0)
	return game.point_scores().size()


func test_the_games_take_accept_and_cancel_from_key_and_pad() -> String:
	var problem: String = ""
	var viewport: Viewport = (Engine.get_main_loop() as SceneTree).root
	for scene: String in [FIXED_SCENE, PUMP_SCENE]:
		for kind: int in 2:
			var game: BenchGame = _game(scene)
			game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
			game.advance(BenchGame.ARM_S + 0.1)
			var before: int = _presses(game)
			game._input(_action(&"ui_accept") if kind == 0 else _pad(JOY_BUTTON_A))
			if _presses(game) == before:
				problem = "%s: accept event %d was not taken." % [scene, kind]
			if not viewport.is_input_handled():
				problem = "%s: accept event %d was not consumed." % [scene, kind]
			game.free()
		# A held key's echo is not another press.
		var held: BenchGame = _game(scene)
		held.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
		held.advance(BenchGame.ARM_S + 0.1)
		var echo: InputEventKey = InputEventKey.new()
		echo.keycode = KEY_ENTER
		echo.physical_keycode = KEY_ENTER
		echo.pressed = true
		echo.echo = true
		var then: int = _presses(held)
		held._input(echo)
		if _presses(held) != then:
			problem = "%s: a held-key echo was taken as a press." % scene
		held.free()
		for kind: int in 2:
			var game: BenchGame = _game(scene)
			game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
			game._input(_action(&"ui_cancel") if kind == 0 else _pad(JOY_BUTTON_B))
			if _scores != [MinigameScore.SKIPPED] or game.is_playing():
				problem = "%s: cancel event %d did not skip: %s" % [scene, kind, _scores]
			game.free()
	return problem


func test_a_game_not_playing_does_not_take_the_keys() -> String:
	var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	game._input(_action(&"ui_cancel"))
	game._input(_action(&"ui_accept"))
	var problem: String = "" if _scores.is_empty() and game.point_scores().is_empty() else "An idle game took a key."
	game.free()
	return problem


func test_the_skip_line_follows_the_device() -> String:
	var game: FixedPoints = _game(FIXED_SCENE) as FixedPoints
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var shown: String = game._hint_label.text
	game._hint_label.text = "stale"
	game._refresh_prompts()
	var rebuilt: String = game._hint_label.text
	game.free()
	if not shown.contains(BenchGame.SKIP_HINT % Controls.short_prompt(&"ui_cancel")):
		return "The hint names the skip key: %s" % shown
	if rebuilt != shown:
		return "The skip line is rebuilt with the prompts: %s" % rebuilt
	return ""


# --- The bench -------------------------------------------------------------------------------

## A day when `id` gets `game`, from the rotation.
func _day_for(id: String, game: String) -> int:
	for day: int in range(1, 20):
		if MinigameScore.bench_game(GameState, id, day) == game:
			return day
	return -1


## The farm owns the standards the thermometer and the dome gauge are calibrated
## against, so both are on the bench. Returns what was owned, to put back.
func _own_the_standards() -> Dictionary:
	var kept: Dictionary = GameState.owned_standards.duplicate()
	for id: String in [GameState.THERMOMETER_ID, "dome_pressure"]:
		var against: String = GameState.get_sensor(id).calibrated_by
		if against != "":
			GameState.owned_standards[against] = 1
	return kept


func _open_bench(id: String, day: int) -> CalBenchUI:
	GameClock.elapsed_days = float(day - 1) + 0.4
	var bench: CalBenchUI = (load("res://ui/cal_bench_ui.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(bench)
	bench.open(id)
	return bench


func _close_bench(bench: CalBenchUI) -> void:
	bench.close()
	(Engine.get_main_loop() as SceneTree).root.remove_child(bench)
	bench.free()


func test_the_bench_opens_the_instrument_kind_games_and_scores_them() -> String:
	var kept_path: String = MinigameSettings.path
	MinigameSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings._file = null
	var kept_log: Array[Dictionary] = GameState.cal_log
	var kept_days: float = GameClock.elapsed_days
	var kept_owned: Dictionary = _own_the_standards()
	var problem: String = ""
	var cases: Array[Array] = [
		[GameState.THERMOMETER_ID, MinigameScore.FIXED_POINTS, "%FixedGame", "Fixed score 97"],
		["dome_pressure", MinigameScore.PUMP_TO_POINTS, "%PumpGame", "Pump score 97"],
		[GameState.THERMOMETER_ID, MinigameScore.SET_THE_ZERO, "%ZeroGame", "Zero score 97"],
	]
	for one: Array in cases:
		var none: Array[Dictionary] = []
		GameState.cal_log = none
		var id: String = one[0]
		var day: int = _day_for(id, one[1])
		if day < 0:
			problem = "%s never gets %s." % [id, one[1]]
			break
		var bench: CalBenchUI = _open_bench(id, day)
		var game: Control = bench.get_node(one[2])
		if not bench._game_name_label.visible or bench._game_name_label.text != "Today: %s" % MinigameScore.game_name(one[1]):
			problem = "%s: the bench names today's game: %s" % [id, bench._game_name_label.text]
		bench._on_calibrate_pressed()
		if problem == "" and (not game.call("is_playing") or not game.visible):
			problem = "%s on day %d: %s did not open." % [id, day, one[1]]
		# A score from the game goes the same way a Set the Zero score does: the
		# host counts it and the result line names the game played.
		game.call("_finish", 97)
		if problem == "" and not bench._result_label.text.contains(one[3]):
			problem = "%s: the result names the game played: %s" % [id, bench._result_label.text]
		_close_bench(bench)
		if problem != "":
			break
	GameClock.elapsed_days = kept_days
	GameState.owned_standards = kept_owned
	GameState.cal_log = kept_log
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings.path = kept_path
	MinigameSettings._file = null
	return problem


func test_the_games_name_follows_the_day_and_whether_a_game_is_due() -> String:
	var kept_path: String = MinigameSettings.path
	MinigameSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings._file = null
	var kept_log: Array[Dictionary] = GameState.cal_log
	var none: Array[Dictionary] = []
	GameState.cal_log = none
	var kept_days: float = GameClock.elapsed_days
	var kept_owned: Dictionary = _own_the_standards()
	var id: String = GameState.THERMOMETER_ID
	var day: int = _day_for(id, MinigameScore.FIXED_POINTS)
	var bench: CalBenchUI = _open_bench(id, day)
	var problem: String = ""
	if bench._game_name_label.text != "Today: Fixed Points" or not bench._game_name_label.visible:
		problem = "The label names today's game: %s" % bench._game_name_label.text
	# Midnight passes: the label follows the clock, as the game that opens does.
	GameClock.elapsed_days = float(day) + 0.1
	bench._on_time_advanced()
	var next: String = MinigameScore.game_name(MinigameScore.bench_game(GameState, id, day + 1))
	if problem == "" and bench._game_name_label.text != "Today: %s" % next:
		problem = "After midnight the label reads %s, not %s." % [bench._game_name_label.text, next]
	# With the games off, no game is due and none is promised.
	MinigameSettings.set_mode(MinigameSettings.Mode.OFF)
	bench._show_game_name()
	if problem == "" and bench._game_name_label.visible:
		problem = "With the games off, no name is shown."
	MinigameSettings.set_mode(MinigameSettings.Mode.STANDARD)
	bench._show_game_name()
	if problem == "" and not bench._game_name_label.visible:
		problem = "With the games on, it is shown again."
	_close_bench(bench)
	GameClock.elapsed_days = kept_days
	GameState.owned_standards = kept_owned
	GameState.cal_log = kept_log
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings.path = kept_path
	MinigameSettings._file = null
	return problem
