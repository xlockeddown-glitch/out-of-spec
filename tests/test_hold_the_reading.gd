extends RefCounted
## Hold the Reading (docs/design/quests_levels_story.md section 7, mini-game 3):
## the wander, the bracket, the score, which calibrations get it, what a score
## is worth (the operator's term of the stated uncertainty and nothing else),
## and the host's cut of a guest's score.

const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const GAME_SCENE: String = "res://ui/minigames/hold_the_reading.tscn"
const GAME: String = "hold_the_reading"
const HOST: String = "player_1"
const GUEST: String = "player_2"
const BENCH: StringName = &"calibrate_at_bench"
const SETTINGS_PATH: String = "user://test_hold_settings.cfg"
const STEP: float = 1.0 / 60.0
const SEED: int = 811

var _scores: Array[int] = []


func _make() -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = GameStateScript.new()
	commands.state.build_registry()
	return commands


func _free(commands: Node) -> void:
	commands.state.free()
	commands.free()


## One bench calibration of the hygrometer (a Hold the Reading unit) by a guest
## on a fresh farm, with `tail` after the command's own argument. The unit, its
## standard and the clock start the same every time, so two answers differ only
## by what the score did. `earlier` plain calibrations come first; with
## `skilled` the guest has the level that opens CAREFUL. Returns the answer, the
## farm's own record as "logged", the whole farm as "farm", and the standard's
## certificate uncertainty as "standard_u".
func _bench(tail: Array, earlier: int = 0, skilled: bool = false) -> Dictionary:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	gs.set_world_seed(77)
	var id: String = gs.HYGROMETER_ID
	if skilled:
		gs.player_skill_xp[GUEST] = { MinigameScore.SKILL: gs.xp_for_level(5) }
	for i: int in earlier:
		commands.execute(GUEST, BENCH, [id])
		GameClock.elapsed_days = saved
	var sensor: DriftingSensor = gs.get_sensor(id)
	var standard: DriftingSensor = gs.get_sensor(sensor.calibrated_by)
	sensor._rng.seed = SEED
	sensor.error = sensor.mpe * 0.25
	standard.error = 0.0
	var plain: Dictionary = gs.calibration_budget(id, GUEST)
	var answer: Variant = commands.execute(GUEST, BENCH, [id] + tail)
	var out: Dictionary = (answer as Dictionary).duplicate() if answer is Dictionary else {}
	out["logged"] = gs.cal_log[-1].duplicate() if not gs.cal_log.is_empty() else {}
	out["armed"] = [sensor.next_residual_scale, sensor.next_operator_scale]
	out["budget"] = plain
	out["scaled"] = CalUncertainty.budget(sensor, standard, float(plain["u_op"]) * MinigameScore.operator_factor(
		int(out.get(MinigameScore.RECORD_KEY, MinigameScore.SKIPPED))), float(plain["u_robot"]))
	out["standard_u"] = [standard.certificate_uncertainty, standard.certificate_k, standard.mpe]
	out["farm"] = gs.farm_to_dict()
	GameClock.elapsed_days = saved
	_free(commands)
	return out


## Every place two farms differ, as paths.
func _differences(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if a is Dictionary and b is Dictionary:
		var keys: Dictionary = {}
		for key: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			keys[key] = true
		for key: Variant in keys:
			if not a.has(key) or not b.has(key):
				out.append("%s/%s" % [path, key])
			else:
				_differences(a[key], b[key], "%s/%s" % [path, key], out)
	elif a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i: int in (a as Array).size():
			_differences(a[i], b[i], "%s/%d" % [path, i], out)
	elif typeof(a) != typeof(b) or a != b:
		out.append(path)


func _on_finished(score: int) -> void:
	_scores.append(score)


func _game() -> HoldTheReading:
	var game: HoldTheReading = (load(GAME_SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_scores.clear()
	game.finished.connect(_on_finished)
	return game


## Plays a whole run: the button is held whenever the reading is over the
## bracket's middle by `slack` or more. With `careless` the first press is the
## only one. Returns the score the game showed.
func _play(game: HoldTheReading, slack: float = 0.0, careless: bool = false) -> int:
	game.hold(true)
	if careless:
		game.hold(false)
	var gone: float = 0.0
	while game.stage() == HoldTheReading.Stage.HOLD and gone < HoldTheReading.RUN_S + 1.0:
		if not careless:
			game.hold(game.reading() > game.bracket() + slack)
		game.advance(STEP)
		gone += STEP
	game.hold(false)
	return game._score


func _round(share: float, mode: int, motion_seed: int, slack: float = 0.0, careless: bool = false) -> int:
	var game: HoldTheReading = _game()
	game.play(share, mode, motion_seed)
	var score: int = _play(game, slack, careless)
	game.free()
	return score


# --- The score and the grades ----------------------------------------------------

func test_the_score_is_the_share_of_time_inside() -> String:
	var run: float = HoldTheReading.RUN_S
	if HoldTheReading.score(0.0) != 0 or HoldTheReading.score(run) != 100 or HoldTheReading.score(run * 0.5) != 50 \
			or HoldTheReading.score(run * 2.0) != 100 or HoldTheReading.score(-1.0) != 0 or HoldTheReading.score(3.0, 4.0) != 75:
		return "The score is 100 times the share of the run spent inside, 0 to 100."
	if run < 10.0 or run > 15.0:
		return "The run is 10 to 15 s (section 7.1), got %s." % run
	return ""


func test_the_grades_are_the_design_table() -> String:
	var table: Dictionary = { -1: 1.0, 0: 1.0, 59: 1.0, 60: 0.8, 79: 0.8, 80: 0.6, 94: 0.6, 95: 0.4, 100: 0.4 }
	for score: int in table:
		if not is_equal_approx(MinigameScore.operator_factor(score), table[score]) \
				or MinigameScore.operator_factor(score) != MinigameScore.residual_factor(score):
			return "Score %d leaves ×%s of the operator's term, got ×%s." % [score, table[score], MinigameScore.operator_factor(score)]
	if MinigameScore.grade_name(96) != "Reference" or MinigameScore.grade_name(85) != "Fine" \
			or MinigameScore.grade_name(60) != "Good" or MinigameScore.grade_name(10) != "Standard":
		return "The grades are Set the Zero's."
	var said: String = MinigameScore.result_text(97, GAME)
	if said != "Hold score 97 of 100: REFERENCE, operator uncertainty 40 % of standard.":
		return "The result line: '%s'" % said
	if MinigameScore.result_text(40, GAME) != "Hold score 40 of 100: STANDARD, standard result." \
			or MinigameScore.result_text(MinigameScore.SKIPPED, GAME) != "":
		return "A poor try is told as the standard result, and a skip says nothing."
	if MinigameScore.result_text(97) != "Zero score 97 of 100: REFERENCE, as-left residual 40 % of standard.":
		return "Set the Zero's line is as it was: '%s'" % MinigameScore.result_text(97)
	return ""


# --- The wander ------------------------------------------------------------------

func test_the_wander_stays_on_the_chart_and_calms() -> String:
	var phases: Array[float] = [0.1, 0.6, 0.35]
	var share_sum: float = 0.0
	for share: float in HoldTheReading.WAVE_SHARE:
		share_sum += share
	if not is_equal_approx(share_sum, 1.0) or HoldTheReading.WAVE_SHARE.size() != HoldTheReading.WAVE_HZ.size():
		return "The waves' shares add up to the whole wander."
	var early: float = 0.0
	var late: float = 0.0
	for i: int in 2000:
		var at: float = i * 0.05
		early = maxf(early, absf(HoldTheReading.reading_at(at, 0.0, phases)))
		late = maxf(late, absf(HoldTheReading.reading_at(at, 1.0, phases)))
		if absf(HoldTheReading.reading_at(at, 0.0, phases)) > HoldTheReading.AMPLITUDE + 0.0001:
			return "The reading left its range at %s." % at
	if HoldTheReading.AMPLITUDE > 1.0:
		return "The bracket stops at the chart's edge, so the reading must stay on the chart to be reachable."
	if not is_equal_approx(HoldTheReading.calm_at(0.0), 1.0) or not is_equal_approx(HoldTheReading.calm_at(1.0), HoldTheReading.CALM_TO) \
			or HoldTheReading.calm_at(0.5) >= 1.0 or HoldTheReading.calm_at(0.5) <= HoldTheReading.CALM_TO \
			or HoldTheReading.calm_at(7.0) != HoldTheReading.CALM_TO or HoldTheReading.CALM_TO >= 1.0:
		return "The wander calms in a straight line as the run goes on."
	if late >= early or not is_equal_approx(late, early * HoldTheReading.CALM_TO):
		return "At the end of the run the wander is %s of what it was: %s then %s." % [HoldTheReading.CALM_TO, early, late]
	return ""


func test_uncertainty_slows_the_wander_to_half() -> String:
	if not is_equal_approx(HoldTheReading.wander_factor(0.0), 1.0) or not is_equal_approx(HoldTheReading.wander_factor(1.0), 0.5) \
			or HoldTheReading.wander_factor(5.0) != HoldTheReading.wander_factor(1.0) \
			or HoldTheReading.wander_factor(-1.0) != HoldTheReading.wander_factor(0.0):
		return "The wander runs at full speed with no skill and half speed with all of it (section 7.3)."
	var last: float = 2.0
	for i: int in 11:
		var now: float = HoldTheReading.wander_factor(i * 0.1)
		if now >= last:
			return "More of the skill must slow the wander more."
		last = now
	# The skill is Uncertainty, front-loaded as section 2.4 has it, each player's own.
	var commands: Node = _make()
	var gs: Node = commands.state
	var problem: String = ""
	var shares: Array[float] = []
	for level: int in [1, 25, 50, 99]:
		gs.player_skill_xp[GUEST] = { MinigameScore.HOLD_SKILL: gs.xp_for_level(level) }
		shares.append(MinigameScore.sweet_share(gs, GUEST, MinigameScore.HOLD_SKILL))
	if MinigameScore.HOLD_SKILL != "uncertainty" or not is_equal_approx(shares[3], 1.0) or shares[0] >= shares[1] \
			or shares[1] >= shares[2] or shares[2] >= shares[3] or shares[1] - shares[0] <= shares[3] - shares[2]:
		problem = "Uncertainty's share runs to 1 at 99, most of it early: %s" % [shares]
	gs.player_skill_xp[GUEST] = { MinigameScore.SKILL: gs.xp_for_level(99) }
	if problem == "" and MinigameScore.sweet_share(gs, GUEST, MinigameScore.HOLD_SKILL) > shares[0] + 0.0001:
		problem = "Calibration is not the skill that slows the wander."
	gs.player_skill_xp[GUEST] = { MinigameScore.HOLD_SKILL: gs.xp_for_level(99) }
	if problem == "" and MinigameScore.sweet_share(gs, HOST, MinigameScore.HOLD_SKILL) > shares[0] + 0.0001:
		problem = "One player's Uncertainty does not slow another's wander."
	_free(commands)
	if problem != "":
		return problem
	# In the game: the same seed, and the reading travels half as far.
	var travel: Array[float] = []
	for share: float in [0.0, 1.0]:
		var game: HoldTheReading = _game()
		game.play(share, MinigameSettings.Mode.STANDARD, SEED)
		_play(game)
		travel.append(game.travel())
		game.free()
	if travel[1] >= travel[0] * 0.75 or travel[1] <= travel[0] * 0.25:
		return "At Uncertainty 99 the reading moves about half as far in a run: %s" % [travel]
	return ""


func test_the_difficulty_sets_the_bracket_and_the_wander() -> String:
	var mode := MinigameSettings.Mode
	var bands: Dictionary = {}
	var travels: Dictionary = {}
	for of_mode: int in [mode.STANDARD, mode.RELAXED, mode.SHARP]:
		var game: HoldTheReading = _game()
		game.play(0.0, of_mode, SEED)
		bands[of_mode] = game.band()
		_play(game)
		travels[of_mode] = game.travel()
		game.free()
	if not is_equal_approx(bands[mode.STANDARD], HoldTheReading.BASE_BAND) \
			or not is_equal_approx(bands[mode.RELAXED], HoldTheReading.BASE_BAND * 1.5) \
			or not is_equal_approx(bands[mode.SHARP], HoldTheReading.BASE_BAND * MinigameSettings.sweet_factor(mode.SHARP)):
		return "Relaxed has a bracket 50 % taller and Sharp a shorter one: %s" % [bands]
	if travels[mode.RELAXED] >= travels[mode.STANDARD] or travels[mode.SHARP] <= travels[mode.STANDARD]:
		return "Relaxed wanders slower and Sharp faster: %s" % [travels]
	# No skill changes the bracket: it is the tolerance band.
	if HoldTheReading.band_half(1.0) != HoldTheReading.BASE_BAND or HoldTheReading.band_half(-1.0) != 0.0:
		return "The bracket's height is the difficulty's alone."
	return ""


# --- The game, played with no frames ---------------------------------------------

func test_nothing_moves_until_the_button_is_pressed() -> String:
	var game: HoldTheReading = _game()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED, "MD-2P")
	var problem: String = ""
	if not game.visible or game.stage() != HoldTheReading.Stage.READY or (game.get_node("%SubjectLabel") as Label).text != "MD-2P":
		problem = "The game opens on its instrument, waiting."
	var reading: float = game.reading()
	var bracket: float = game.bracket()
	game.advance(30.0)
	if problem == "" and (game.stage() != HoldTheReading.Stage.READY or game.reading() != reading or game.bracket() != bracket \
			or not _scores.is_empty()):
		problem = "No time limit before the first press: nothing moves."
	if problem == "" and not game.is_inside():
		problem = "The bracket starts on the reading."
	game.hold(true)
	if problem == "" and (game.stage() != HoldTheReading.Stage.HOLD or not game.is_held()):
		problem = "The first press starts the run, held."
	game.advance(0.5)
	if problem == "" and game.bracket() <= bracket:
		problem = "Holding lifts the bracket."
	var high: float = game.bracket()
	game.hold(false)
	game.advance(1.0)
	if problem == "" and game.bracket() >= high:
		problem = "Letting go lets it drop."
	game.advance(60.0)
	if problem == "" and (absf(game.bracket()) > 1.0 - game.band() + 0.0001 or _scores.size() != 1):
		problem = "The bracket stays on the chart, and the run ends by itself: %s" % [_scores]
	game.free()
	return problem


func test_a_careful_player_reaches_reference() -> String:
	for motion_seed: int in [1, 7, SEED, 4242, 99999]:
		var score: int = _round(0.0, MinigameSettings.Mode.STANDARD, motion_seed)
		if score < 95:
			return "Seed %d: following the reading closely scored %d, under Reference." % [motion_seed, score]
	return ""


func test_a_careless_player_scores_poorly() -> String:
	for motion_seed: int in [1, 7, SEED, 4242, 99999]:
		var careless: int = _round(0.0, MinigameSettings.Mode.STANDARD, motion_seed, 0.0, true)
		if careless >= 60:
			return "Seed %d: one press and no more scored %d, a grade." % [motion_seed, careless]
		var slack: int = _round(0.0, MinigameSettings.Mode.STANDARD, motion_seed, 0.3)
		var careful: int = _round(0.0, MinigameSettings.Mode.STANDARD, motion_seed)
		if slack >= careful:
			return "Seed %d: a late hand (%d) must score under a close one (%d)." % [motion_seed, slack, careful]
	return ""


func test_the_motion_is_the_seed_s() -> String:
	var runs: Array = []
	for motion_seed: int in [SEED, SEED, SEED + 1]:
		var game: HoldTheReading = _game()
		game.play(0.0, MinigameSettings.Mode.STANDARD, motion_seed)
		var trace: Array[float] = [game.reading()]
		game.hold(true)
		for i: int in 300:
			game.hold(i % 40 < 22)
			game.advance(STEP)
			trace.append(game.reading())
			trace.append(game.bracket())
		game.advance(HoldTheReading.RUN_S)
		trace.append(float(game._score))
		runs.append(trace)
		game.free()
	if runs[0] != runs[1]:
		return "The same seed and the same presses must give the same run and score."
	if runs[0] == runs[2]:
		return "Another seed must give another wander."
	# The frame rate does not change it: one long step is the same as many short ones.
	var scores: Array[int] = []
	for chunk: float in [STEP, 0.05, 0.1]:
		var game: HoldTheReading = _game()
		game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
		game.hold(true)
		game.hold(false)
		var gone: float = 0.0
		while game.stage() == HoldTheReading.Stage.HOLD and gone < 20.0:
			game.advance(chunk)
			gone += chunk
		scores.append(game._score)
		game.free()
	if scores[0] != scores[1] or scores[0] != scores[2]:
		return "The score must not depend on the frame rate: %s" % [scores]
	return ""


func test_no_hold_is_over_the_cap() -> String:
	if HoldTheReading.MAX_HOLD_S > 3.0:
		return "No hold longer than 3 s (section 7.5)."
	var game: HoldTheReading = _game()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var hint: Label = game.get_node("%HintLabel")
	var problem: String = ""
	game.hold(true)
	game.advance(HoldTheReading.MAX_HOLD_S - 0.2)
	if not game.is_held() or hint.text.contains(HoldTheReading.HOLD_CAP_HINT):
		problem = "Under the cap the hold stands, and nothing is said."
	game.advance(0.4)
	if problem == "" and (game.is_held() or not hint.text.begins_with(HoldTheReading.HOLD_CAP_HINT)):
		problem = "The game lets go of a hold at the cap, and says so: '%s'" % hint.text
	var top: float = game.bracket()
	game.advance(0.5)
	if problem == "" and game.bracket() >= top:
		problem = "After the cap the bracket drops though the button is still down."
	# Still down: a held key's repeats and the same button state lift nothing.
	game.advance(1.0)
	if problem == "" and game.is_held():
		problem = "Only a new press lifts again."
	game.hold(true)
	if problem == "" and (not game.is_held() or hint.text.contains(HoldTheReading.HOLD_CAP_HINT)):
		problem = "A new press lifts again, and the cue is gone: '%s'" % hint.text
	# A whole run with the button never let go: no single hold over the cap.
	var longest: float = 0.0
	var held: float = 0.0
	while game.stage() == HoldTheReading.Stage.HOLD:
		game.hold(true)
		game.advance(STEP)
		held = held + STEP if game.is_held() else 0.0
		longest = maxf(longest, held)
	if problem == "" and longest > HoldTheReading.MAX_HOLD_S + 2.0 * STEP:
		problem = "A hold ran %s s." % longest
	game.free()
	return problem


func test_skip_ends_it_with_no_score() -> String:
	var game: HoldTheReading = _game()
	var problem: String = ""
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	game.skip()
	if _scores != [MinigameScore.SKIPPED] or game.visible or game.is_playing():
		problem = "A skip before the first press ends with no score: %s" % [_scores]
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	game.hold(true)
	game.advance(3.0)
	game.skip()
	if problem == "" and _scores != [MinigameScore.SKIPPED]:
		problem = "A skip in the run ends with no score: %s" % [_scores]
	# At the result the score stands, by a skip, a press or by itself.
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	var score: int = _play(game)
	if problem == "" and (game.stage() != HoldTheReading.Stage.RESULT or not _scores.is_empty() \
			or not (game.get_node("%HintLabel") as Label).text.begins_with("Hold score %d of 100" % score)):
		problem = "The result is shown before the game closes."
	game.hold(true)
	if problem == "" and not _scores.is_empty():
		problem = "A press too soon after the run does not close the result unread."
	game.hold(false)
	game.advance(HoldTheReading.RESULT_ARM_S + 0.05)
	game.hold(true)
	if problem == "" and _scores != [score]:
		problem = "A press at the result goes on with the score: %s" % [_scores]
	_scores.clear()
	game.play(0.0, MinigameSettings.Mode.STANDARD, SEED)
	_play(game)
	game.skip()
	if problem == "" and _scores != [score]:
		problem = "Esc at the result keeps the score: %s" % [_scores]
	game.free()
	return problem


func test_a_hitch_or_a_fast_farm_clock_does_not_jump_the_run() -> String:
	if HoldTheReading.frame_step(5.0) != HoldTheReading.MAX_STEP_S or HoldTheReading.frame_step(-1.0) != 0.0 \
			or not is_equal_approx(HoldTheReading.frame_step(0.016), 0.016):
		return "One frame moves the game by its real time, 0.1 s at most."
	var game: HoldTheReading = _game()
	var kept: float = Engine.time_scale
	Engine.time_scale = 50.0
	game.play(0.0, MinigameSettings.Mode.STANDARD, 42)
	game.hold(true)
	# One frame, however long the farm's clock says it was.
	game._process(HoldTheReading.RUN_S * 50.0)
	Engine.time_scale = kept
	var problem: String = ""
	if game.stage() != HoldTheReading.Stage.HOLD:
		problem = "The farm's clock must not run the game's timer."
	game.free()
	return problem


# --- Which calibrations get it ---------------------------------------------------

func test_a_unit_on_a_settling_standard_gets_the_game() -> String:
	var commands: Node = _make()
	var gs: Node = commands.state
	var problem: String = ""
	if MinigameScore.SETTLING_STANDARDS != ["humidity_generator", "pressure_controller"]:
		problem = "The standards that settle are the humidity generator and the pressure controller."
	if problem == "" and MinigameScore.game_for(gs, gs.HYGROMETER_ID) != GAME:
		problem = "The hygrometer is calibrated against the humidity generator: Hold the Reading."
	for id: String in [gs.THERMOMETER_ID, gs.SOIL_PROBE_ID, gs.STEERING_ID, gs.TIRE_ID, "dome_pressure", "no_such_instrument", ""]:
		if problem == "" and MinigameScore.game_for(gs, id) != MinigameScore.SET_THE_ZERO:
			problem = "%s keeps Set the Zero." % id
	# Once the pressure controller takes the dome gauge over, the dome gauge gets it.
	gs.get_sensor("dome_pressure").calibrated_by = "pressure_controller"
	if problem == "" and MinigameScore.game_for(gs, "dome_pressure") != GAME:
		problem = "A unit on the pressure controller gets Hold the Reading."
	# A standard never does: its U goes on its own certificate.
	for id: String in gs.standard_ids():
		if problem == "" and MinigameScore.game_for(gs, id) != MinigameScore.SET_THE_ZERO:
			problem = "A standard's own calibration keeps Set the Zero: %s." % id
	var gauge: DriftingSensor = gs.get_sensor("reference_gauge")
	if problem == "" and (gauge == null or gauge.role != "standard" or gauge.calibrated_by != "pressure_controller"):
		problem = "The test wants the WD-1, a standard calibrated against the pressure controller."
	_free(commands)
	return problem


func test_the_bench_opens_it_for_the_hygrometer() -> String:
	var kept_path: String = MinigameSettings.path
	MinigameSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings._file = null
	var kept_log: Array[Dictionary] = GameState.cal_log
	var none: Array[Dictionary] = []
	GameState.cal_log = none
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var bench: CalBenchUI = (load("res://ui/cal_bench_ui.tscn") as PackedScene).instantiate()
	root.add_child(bench)
	bench.open(GameState.HYGROMETER_ID)
	var game: HoldTheReading = bench.get_node("%HoldGame")
	var zero: SetTheZero = bench.get_node("%ZeroGame")
	var problem: String = ""
	if game.visible or zero.visible:
		problem = "No game is open before ZERO / CALIBRATE."
	MinigameSettings.set_mode(MinigameSettings.Mode.OFF)
	if problem == "" and bench._zero_game_due(GameState.HYGROMETER_ID):
		problem = "With the games off, none is due."
	MinigameSettings.set_mode(MinigameSettings.Mode.STANDARD)
	if problem == "" and not bench._zero_game_due(GameState.HYGROMETER_ID):
		problem = "The lab's first hygrometer calibration is a key moment."
	bench._on_calibrate_pressed()
	if problem == "" and (not game.is_playing() or not game.visible or zero.is_playing() or not GameState.cal_log.is_empty()):
		problem = "ZERO / CALIBRATE opens Hold the Reading first, and nothing is calibrated yet."
	bench.close()
	if problem == "" and (game.is_playing() or not GameState.cal_log.is_empty()):
		problem = "Closing the bench with the game open calibrates nothing."
	# A Set the Zero unit still opens Set the Zero.
	bench.open(GameState.STEERING_ID)
	bench._on_calibrate_pressed()
	if problem == "" and (not zero.is_playing() or game.is_playing() or not GameState.cal_log.is_empty()):
		problem = "The steering encoder still opens Set the Zero."
	bench.close()
	root.remove_child(bench)
	bench.free()
	GameState.cal_log = kept_log
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings.path = kept_path
	MinigameSettings._file = null
	return problem


# --- What a score is worth -------------------------------------------------------

func test_a_skip_and_a_poor_try_leave_the_same_farm() -> String:
	var skip: Dictionary = _bench([])
	for poor: int in [0, 1, 30, 59]:
		var tried: Dictionary = _bench([poor])
		if tried.get(MinigameScore.RECORD_KEY) != poor:
			return "The host counts a poor score as what it is: %s" % [tried.get(MinigameScore.RECORD_KEY)]
		var differences := PackedStringArray()
		_differences(skip["farm"], tried["farm"], "farm", differences)
		if not differences.is_empty():
			return "A try of %d and a skip must leave exactly the same farm: %s" % [poor, differences]
		tried.erase(MinigameScore.RECORD_KEY)
		skip.erase(MinigameScore.RECORD_KEY)
		differences.clear()
		_differences(skip, tried, "answer", differences)
		if not differences.is_empty():
			return "A try of %d and a skip must get the same answer: %s" % [poor, differences]
	if skip["logged"].is_empty() or skip["logged"]["standard_id"] != "humidity_generator":
		return "The test's calibration did not happen."
	return ""


func test_a_better_score_scales_the_operators_term_and_nothing_else() -> String:
	var plain: Dictionary = _bench([])
	var budget: Dictionary = plain["budget"]
	if float(budget["u_op"]) <= 0.0 or not is_equal_approx(plain["logged"]["standard_uncertainty"], budget["expanded_uncertainty"]) \
			or not is_equal_approx(plain["logged"]["tur"], budget["tur"]):
		return "A plain calibration states the plain budget, with an operator's term in it."
	var last_u: float = float(budget["expanded_uncertainty"])
	var last_factor: float = 1.0
	for score: int in [60, 80, 95, 100]:
		var scored: Dictionary = _bench([score])
		var logged: Dictionary = scored["logged"]
		var want: Dictionary = scored["scaled"]
		if scored.get(MinigameScore.RECORD_KEY) != score:
			return "The host counts a first calibration's score: %s" % [scored.get(MinigameScore.RECORD_KEY)]
		# The stated U is the budget with the operator's term at the factor: the
		# standard's terms, the resolution and k are as they were.
		for term: String in ["u_spec", "u_cert", "u_res", "u_robot", "k"]:
			if want[term] != budget[term]:
				return "The test's scaled budget changed %s." % term
		if not is_equal_approx(want["u_op"], float(budget["u_op"]) * MinigameScore.operator_factor(score)):
			return "The test's scaled budget has the wrong operator's term."
		if not is_equal_approx(logged["standard_uncertainty"], want["expanded_uncertainty"]) \
				or not is_equal_approx(logged["tur"], want["tur"]):
			return "Score %d must state U %s and TUR %s, got %s and %s." % [score, want["expanded_uncertainty"], want["tur"],
				logged["standard_uncertainty"], logged["tur"]]
		if logged["standard_uncertainty"] >= last_u and MinigameScore.operator_factor(score) < last_factor:
			return "A better grade must state a smaller U."
		last_factor = MinigameScore.operator_factor(score)
		if logged["standard_uncertainty"] >= budget["expanded_uncertainty"] or logged["tur"] <= budget["tur"]:
			return "A graded score lifts the TUR a little by a smaller U."
		last_u = logged["standard_uncertainty"]
		# Never the as-found reading, the as-left, the verdict, the limit, the
		# interval, or the standard itself.
		for key: String in ["as_found", "as_left", "result", "mpe", "acceptance_limit", "due_day", "on_time",
				"interval_evidence", "traceable", "standard_id", "day", "performed_by"]:
			if logged.get(key) != plain["logged"].get(key):
				return "Score %d changed the record's %s: %s, was %s." % [score, key, logged.get(key), plain["logged"].get(key)]
		if scored["standard_u"] != plain["standard_u"]:
			return "A score never changes a standard's own uncertainty."
		if scored["armed"] != [1.0, 1.0]:
			return "The factor is used up by its calibration: %s" % [scored["armed"]]
		# Across the whole farm: only the stated U and TUR of that record, and
		# what a cleaner TUR earns in Uncertainty XP.
		var differences := PackedStringArray()
		_differences(plain["farm"], scored["farm"], "farm", differences)
		for path: String in differences:
			if not (path.ends_with("/standard_uncertainty") or path.ends_with("/tur") or path.contains("skill_xp") \
					or path.contains("lab_xp") or path.contains("lab_level")):
				return "Score %d changed the farm at %s." % [score, path]
		if differences.is_empty():
			return "Score %d changed nothing." % score
	return ""


func test_a_score_never_passes_a_refused_calibration() -> String:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var id: String = gs.HYGROMETER_ID
	var sensor: DriftingSensor = gs.get_sensor(id)
	var standard: DriftingSensor = gs.get_sensor(sensor.calibrated_by)
	# A standard so poor the plain TUR is under the floor.
	standard.certificate_uncertainty = sensor.mpe
	var problem: String = ""
	if not gs.calibration_budget(id, GUEST).get("refused", false):
		problem = "The test wants a budget under the TUR floor."
	var answer: Variant = commands.execute(GUEST, BENCH, [id, 100])
	if problem == "" and (not answer is Dictionary or not answer.get("refused", false) or not gs.cal_log.is_empty()):
		problem = "A score must not lift a refused calibration over the floor: %s" % [answer]
	if problem == "" and (sensor.next_operator_scale != 1.0 or sensor.next_residual_scale != 1.0):
		problem = "A refused calibration must leave no factor for the next one."
	GameClock.elapsed_days = saved
	_free(commands)
	return problem


func test_set_the_zero_units_take_no_operator_factor() -> String:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var problem: String = ""
	var id: String = gs.STEERING_ID
	var budget: Dictionary = gs.calibration_budget(id, GUEST)
	var answer: Variant = commands.execute(GUEST, BENCH, [id, 100])
	if not answer is Dictionary or answer.get(MinigameScore.RECORD_KEY) != 100:
		problem = "The test's steering encoder calibration was not scored: %s" % [answer]
	elif not is_equal_approx(answer["standard_uncertainty"], budget["expanded_uncertainty"]) or not is_equal_approx(answer["tur"], budget["tur"]):
		problem = "Set the Zero's score must not change the stated U or TUR."
	# And Hold the Reading leaves the as-left residual alone (in the test above);
	# arming sets one factor, never both.
	MinigameScore.arm(gs, id, 100)
	var zero: DriftingSensor = gs.get_sensor(id)
	if problem == "" and (not is_equal_approx(zero.next_residual_scale, 0.4) or zero.next_operator_scale != 1.0):
		problem = "A Set the Zero unit is armed on its residual only."
	MinigameScore.arm(gs, gs.HYGROMETER_ID, 100)
	var hold: DriftingSensor = gs.get_sensor(gs.HYGROMETER_ID)
	if problem == "" and (not is_equal_approx(hold.next_operator_scale, 0.4) or hold.next_residual_scale != 1.0):
		problem = "A Hold the Reading unit is armed on the operator's term only."
	MinigameScore.disarm(gs, id)
	MinigameScore.disarm(gs, gs.HYGROMETER_ID)
	if problem == "" and (zero.next_residual_scale != 1.0 or hold.next_operator_scale != 1.0):
		problem = "Disarming takes both factors back."
	# A calibration that is not the bench's (a robot's, the manager's, a remote
	# zero) never has a factor waiting.
	hold.next_operator_scale = 0.4
	gs.calibrate(gs.HYGROMETER_ID, GUEST, false)
	if problem == "" and hold.next_operator_scale != 1.0:
		problem = "Any calibration uses the factor up."
	GameClock.elapsed_days = saved
	_free(commands)
	return problem


# --- Co-op: the host's cut -------------------------------------------------------

func test_the_host_cuts_a_guests_score_to_its_range() -> String:
	var plain: Dictionary = _bench([])
	var top: Dictionary = _bench([100])
	var over: Dictionary = _bench([1000])
	if over.get(MinigameScore.RECORD_KEY) != MinigameScore.MAX_SCORE or over["logged"] != top["logged"]:
		return "A score over 100 counts as 100, no more: %s" % over.get(MinigameScore.RECORD_KEY)
	for under: int in [-1, -50, -1000000]:
		var cut: Dictionary = _bench([under])
		if cut.get(MinigameScore.RECORD_KEY) != 0 or cut["logged"] != plain["logged"]:
			return "A score under 0 counts as 0, the plain result."
	var commands: Node = _make()
	var id: String = commands.state.HYGROMETER_ID
	var bad: PackedStringArray = []
	for arguments: Array in [[id, 99.5], [id, "100"], [id, true], [id, 50, 50], [id, [100]], [id, NAN], [id, 100, "hold_the_reading"]]:
		if commands.problem(BENCH, arguments) == "":
			bad.append(str(arguments))
	var refused: Dictionary = commands.execute(GUEST, BENCH, [id, 99.5])
	if refused.get("ok", true) or not commands.state.cal_log.is_empty():
		bad.append("a refused score still calibrated")
	_free(commands)
	return "" if bad.is_empty() else "Taken, but must be refused: " + ", ".join(bad)


func test_the_host_counts_a_guests_score_only_at_a_key_moment() -> String:
	# The second calibration of its kind is routine: one click, whatever comes with it.
	var routine: Dictionary = _bench([], 1)
	var claimed: Dictionary = _bench([100], 1)
	if claimed.get(MinigameScore.RECORD_KEY) != MinigameScore.SKIPPED or claimed["logged"] != routine["logged"]:
		return "A score with a routine calibration must count for nothing."
	var differences := PackedStringArray()
	_differences(routine["farm"], claimed["farm"], "farm", differences)
	if not differences.is_empty():
		return "A score the host does not count must leave the farm as a plain calibration does: %s" % [differences]
	# With the level that opens CAREFUL any bench calibration can be played.
	var careful: Dictionary = _bench([100], 1, true)
	var careful_plain: Dictionary = _bench([], 1, true)
	if careful.get(MinigameScore.RECORD_KEY) != 100 or careful["logged"]["tur"] <= careful_plain["logged"]["tur"] \
			or careful["logged"]["as_left"] != careful_plain["logged"]["as_left"]:
		return "At the CAREFUL level a later calibration's score counts, on the operator's term."
	# A standard, a robot and nothing at all take no score.
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var problem: String = ""
	var standard: String = "humidity_generator"
	for id: String in [standard, "TR-1", "robot_joint_encoder@TR-99", "no_such_instrument"]:
		if MinigameScore.allowed(gs, id, GUEST, 100) != MinigameScore.SKIPPED:
			problem = "A score for %s must be cut to none." % id
		var answer: Variant = commands.execute(GUEST, BENCH, [id, 100])
		if problem == "" and answer is Dictionary and answer.get(MinigameScore.RECORD_KEY, MinigameScore.SKIPPED) != MinigameScore.SKIPPED:
			problem = "The host counted a score for %s." % id
	var sensor: DriftingSensor = gs.get_sensor(standard)
	if problem == "" and (sensor.next_operator_scale != 1.0 or sensor.next_residual_scale != 1.0):
		problem = "A standard's next calibration must take no factor."
	GameClock.elapsed_days = saved
	_free(commands)
	return problem


# --- A quest step ----------------------------------------------------------------

func test_a_quest_step_may_carry_it() -> String:
	var quest: Dictionary = {
		"id": "hold_fixture", "kind": "lab", "giver": "lin", "title": "Hold Fixture", "scope": "farm",
		"steps": [{ "id": "cal", "check": "count", "log": "cal_log", "where": { "instrument_id": "hygrometer" }, "count": 1,
			"minigame": GAME }],
		"rewards": { "credits": 10 },
	}
	var problem: String = QuestEngine.data_problem(quest)
	if problem != "":
		return "A count of one instrument's calibrations may carry Hold the Reading: %s" % problem
	if not GAME in QuestEngine.MINIGAMES or MinigameScore.HOLD_THE_READING != GAME:
		return "The quest data knows the game by its id."
	var bad: Dictionary = quest.duplicate(true)
	bad["steps"][0].erase("where")
	if QuestEngine.data_problem(bad) == "":
		return "A Hold the Reading step with no instrument must not load."
	# A step is graded by the bench game its instrument plays, whichever of the
	# two bench games it names. Wring the Blocks is its own.
	if not MinigameScore.grades_step(GAME, GAME) or not MinigameScore.grades_step("set_the_zero", GAME) \
			or not MinigameScore.grades_step(GAME, "set_the_zero") or MinigameScore.grades_step("wring_the_blocks", GAME) \
			or MinigameScore.grades_step(GAME, "wring_the_blocks") or MinigameScore.grades_step("", GAME) \
			or MinigameScore.grades_step("", ""):
		return "A bench step is graded by either bench game, and by no other."
	return ""


# --- Saves -----------------------------------------------------------------------

func test_the_stated_uncertainty_saves_and_the_factor_does_not() -> String:
	if SaveGame.VERSION != 1:
		return "The save version stays 1."
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var id: String = gs.HYGROMETER_ID
	var plain: Dictionary = gs.calibration_budget(id, GUEST)
	var answer: Variant = commands.execute(GUEST, BENCH, [id, 100])
	var problem: String = ""
	if not answer is Dictionary or answer.get(MinigameScore.RECORD_KEY) != 100 or answer["tur"] <= plain["tur"]:
		problem = "The test's calibration was not scored: %s" % [answer]
	# A factor left waiting is not in the save.
	gs.get_sensor(id).next_operator_scale = 0.4
	var data: Dictionary = gs.farm_to_dict()
	var text: String = var_to_str(data)
	if problem == "" and (text.contains("next_operator_scale") or text.contains("operator_scale") or text.contains(MinigameScore.RECORD_KEY)):
		problem = "Neither the factor nor the score is a saved field."
	if problem == "" and gs.farm_dict_problem(data) != "":
		problem = "The farm must save: %s" % gs.farm_dict_problem(data)
	var loaded: Node = GameStateScript.new()
	loaded.build_registry()
	var load_problem: String = loaded.farm_from_dict(data.duplicate(true))
	if problem == "" and load_problem != "":
		problem = "The farm must load: %s" % load_problem
	if problem == "" and (loaded.cal_log.is_empty() or not is_equal_approx(loaded.cal_log[-1]["tur"], answer["tur"]) \
			or not is_equal_approx(loaded.cal_log[-1]["standard_uncertainty"], answer["standard_uncertainty"])):
		problem = "The record's stated U and TUR come back as they were saved: %s" % [loaded.cal_log]
	if problem == "" and loaded.get_sensor(id).next_operator_scale != 1.0:
		problem = "A loaded farm has no factor waiting."
	if problem == "":
		var differences := PackedStringArray()
		_differences(data, loaded.farm_to_dict(), "farm", differences)
		if not differences.is_empty():
			problem = "Saved and loaded farms differ: %s" % [differences]
	loaded.free()
	GameClock.elapsed_days = saved
	_free(commands)
	return problem
