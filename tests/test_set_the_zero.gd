extends RefCounted
## Set the Zero (docs/design/quests_levels_story.md section 7): the scoring, the
## sweet spot, what a score is worth, and the host's cut of a guest's score.

const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const GAME_SCENE: String = "res://ui/minigames/set_the_zero.tscn"
const GUEST: String = "player_2"
const SETTINGS_PATH: String = "user://test_minigame_settings.cfg"

var _scores: Array[int] = []


func _make() -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = GameStateScript.new()
	commands.state.build_registry()
	return commands


func _free(commands: Node) -> void:
	commands.state.free()
	commands.free()


## One bench calibration of the rover's steering encoder (a Set the Zero unit) by a guest on a fresh farm, with
## `tail` after the command's own argument. The unit, its standard and the clock
## start the same every time, so two answers differ only by what the score did.
## `earlier` plain calibrations come first; with `skilled` the guest has the
## level that opens CAREFUL. Returns the answer, and the farm's own record as "logged".
func _bench(tail: Array, earlier: int = 0, skilled: bool = false) -> Dictionary:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var id: String = gs.STEERING_ID
	if skilled:
		gs.player_skill_xp[GUEST] = { MinigameScore.SKILL: gs.xp_for_level(5) }
	for i: int in earlier:
		commands.execute(GUEST, &"calibrate_at_bench", [id])
		GameClock.elapsed_days = saved
	var sensor: DriftingSensor = gs.get_sensor(id)
	var standard: DriftingSensor = gs.get_sensor(sensor.calibrated_by)
	sensor._rng.seed = 811
	sensor.error = sensor.mpe * 0.25
	if standard != null:
		standard.error = 0.0
	var answer: Variant = commands.execute(GUEST, &"calibrate_at_bench", [id] + tail)
	var out: Dictionary = (answer as Dictionary).duplicate() if answer is Dictionary else {}
	out["logged"] = gs.cal_log[-1].duplicate() if not gs.cal_log.is_empty() else {}
	out["armed"] = sensor.next_residual_scale
	GameClock.elapsed_days = saved
	_free(commands)
	return out


func _same(a: Dictionary, b: Dictionary) -> bool:
	var left: Dictionary = a.duplicate()
	var right: Dictionary = b.duplicate()
	left.erase(MinigameScore.RECORD_KEY)
	right.erase(MinigameScore.RECORD_KEY)
	return left == right


func test_the_score_is_how_close_the_fine_stop_is() -> String:
	var sweet: float = 0.03
	if SetTheZero.score(0.3, 0.0, sweet) != 100 or SetTheZero.score(0.3, sweet, sweet) != 95:
		return "Dead on zero is 100 and the sweet spot's edge 95, got %d and %d." % [
			SetTheZero.score(0.3, 0.0, sweet), SetTheZero.score(0.3, sweet, sweet)]
	var last: int = 100
	for i: int in 61:
		var stop: float = 0.005 * i
		var now: int = SetTheZero.score(0.3, stop, sweet)
		if now > last or now < 0 or now != SetTheZero.score(0.3, -stop, sweet) or now != SetTheZero.score(-0.3, stop, sweet):
			return "The score must fall with distance, the same on both sides: %d after %d at %s." % [now, last, stop]
		if stop > sweet + 0.0001 and now >= 95:
			return "Outside the sweet spot the score is under 95: %d at %s." % [now, stop]
		last = now
	if SetTheZero.score(0.3, sweet * SetTheZero.MISS_AT, sweet) != 0 or SetTheZero.score(0.5, 0.5, sweet) != 0:
		return "A stop far from zero scores 0."
	# The fine stop can't be outside the fine scale, whatever is passed.
	if SetTheZero.score(0.1, 5.0, 0.1) != SetTheZero.score(0.1, SetTheZero.FINE_MIN, 0.1):
		return "A fine stop is held to the fine scale."
	if SetTheZero.fine_amplitude(0.0) != SetTheZero.FINE_MIN or SetTheZero.fine_amplitude(-0.9) != SetTheZero.FINE_MAX \
			or not is_equal_approx(SetTheZero.fine_amplitude(-0.3), 0.3):
		return "The fine scale is as wide as the coarse stop was off, within its limits."
	# A wider sweet spot is kinder to the same stop.
	if SetTheZero.score(0.3, 0.05, 0.06) <= SetTheZero.score(0.3, 0.05, 0.03):
		return "The same stop must score more with a wider sweet spot."
	return ""


func test_the_needle_sweeps_end_to_end() -> String:
	if not is_equal_approx(SetTheZero.needle_at(0.0, 1.0, 2.0), 1.0) or not is_zero_approx(SetTheZero.needle_at(0.5, 1.0, 2.0)) \
			or not is_equal_approx(SetTheZero.needle_at(1.0, 1.0, 2.0), -1.0) \
			or not is_equal_approx(SetTheZero.needle_at(2.5, 1.0, 2.0), SetTheZero.needle_at(0.5, 1.0, 2.0)):
		return "The needle runs from one end to the other and back each period."
	for i: int in 200:
		if absf(SetTheZero.needle_at(i * 0.037, 0.4, 2.6, 0.31)) > 0.4 + 0.000001:
			return "The needle left its scale."
	return ""


func test_calibration_widens_the_sweet_spot_up_to_twice() -> String:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	var base: float = SetTheZero.sweet_half_width(0.0)
	var problem: String = ""
	if not is_equal_approx(base, SetTheZero.BASE_SWEET) or not is_equal_approx(SetTheZero.sweet_half_width(1.0), 2.0 * base) \
			or not is_equal_approx(SetTheZero.sweet_half_width(7.0), 2.0 * base):
		problem = "The sweet spot is the base at no share and twice it at a full one, never more."
	var last: float = 0.0
	for level: int in range(1, 100):
		gs.player_skill_xp[GUEST] = { MinigameScore.SKILL: gs.xp_for_level(level) }
		var half: float = SetTheZero.sweet_half_width(MinigameScore.sweet_share(gs, GUEST))
		if half < last - 0.0000001:
			problem = "A higher Calibration level must not narrow the sweet spot (level %d)." % level
		last = half
		if level == 1 and not is_equal_approx(half, base):
			problem = "At Calibration 1 the sweet spot is the base, got %s." % half
	if problem == "" and not is_equal_approx(last, 2.0 * base):
		problem = "At Calibration 99 the sweet spot is twice as wide, got %s of %s." % [last, base]
	# Another player's level is not this player's.
	if problem == "" and not is_zero_approx(MinigameScore.sweet_share(gs, "player_3")):
		problem = "The widening is each player's own."
	gs.free()
	if problem != "":
		return problem
	var relaxed: float = SetTheZero.sweet_half_width(0.0, MinigameSettings.sweet_factor(MinigameSettings.Mode.RELAXED))
	var sharp: float = SetTheZero.sweet_half_width(0.0, MinigameSettings.sweet_factor(MinigameSettings.Mode.SHARP))
	if not is_equal_approx(relaxed, 1.5 * base) or sharp >= base \
			or not is_equal_approx(MinigameSettings.speed_factor(MinigameSettings.Mode.RELAXED), 0.7) \
			or MinigameSettings.speed_factor(MinigameSettings.Mode.SHARP) <= 1.0:
		return "Relaxed is half again as wide and 30 % slower; Sharp is narrower and faster."
	return ""


func test_the_grades_are_the_design_table() -> String:
	var want: Dictionary = { -1: 1.0, 0: 1.0, 59: 1.0, 60: 0.8, 79: 0.8, 80: 0.6, 94: 0.6, 95: 0.4, 100: 0.4 }
	for score: int in want:
		if not is_equal_approx(MinigameScore.residual_factor(score), want[score]):
			return "Score %d leaves ×%s of the residual, not ×%s." % [score, MinigameScore.residual_factor(score), want[score]]
	if MinigameScore.grade_name(59) != "Standard" or MinigameScore.grade_name(60) != "Good" \
			or MinigameScore.grade_name(80) != "Fine" or MinigameScore.grade_name(95) != "Reference":
		return "The grades are Standard, Good, Fine and Reference."
	if MinigameScore.result_text(MinigameScore.SKIPPED) != "" or not MinigameScore.result_text(97).contains("REFERENCE") \
			or not MinigameScore.result_text(30).contains("standard result"):
		return "The result names the grade, and a skip says nothing: %s" % MinigameScore.result_text(97)
	return ""


func test_a_skip_and_a_poor_try_are_the_plain_result() -> String:
	var plain: Dictionary = _bench([])
	if not plain.has("as_left") or is_zero_approx(plain["as_left"]):
		return "The plain calibration must leave a residual to compare: %s" % plain
	if plain.has(MinigameScore.RECORD_KEY) or plain["as_left"] != plain["logged"]["as_left"]:
		return "With no score sent the answer is the farm's record and no more."
	for poor: int in [0, 1, 30, 59]:
		var tried: Dictionary = _bench([poor])
		if tried.get(MinigameScore.RECORD_KEY, -9) != poor:
			return "A poor try's score is still told: %s" % tried.get(MinigameScore.RECORD_KEY)
		if not _same(tried, plain):
			return "A try at %d must give exactly the skip's result." % poor
	if plain["logged"].has(MinigameScore.RECORD_KEY) or _bench([100])["logged"].has(MinigameScore.RECORD_KEY):
		return "The farm's own record gains no field."
	return ""


func test_a_better_score_leaves_a_smaller_residual() -> String:
	var plain: Dictionary = _bench([])
	for score: int in [60, 80, 95, 100]:
		var played: Dictionary = _bench([score])
		var factor: float = MinigameScore.residual_factor(score)
		if not is_equal_approx(played["as_left"], plain["as_left"] * factor) \
				or not is_equal_approx(played["logged"]["as_left"], plain["as_left"] * factor):
			return "Score %d must leave ×%s of %s, got %s." % [score, factor, plain["as_left"], played["as_left"]]
		# What a score never touches.
		for key: String in ["as_found", "result", "as_found_in_tolerance", "interval_days", "due_day", "bench_minutes", "acceptance_limit"]:
			if played[key] != plain[key]:
				return "A score must not change %s." % key
		if played["armed"] != 1.0:
			return "The factor is for one zero only."
	return ""


func test_the_host_cuts_a_guests_score_to_its_range() -> String:
	var plain: Dictionary = _bench([])
	var over: Dictionary = _bench([1000])
	if over.get(MinigameScore.RECORD_KEY) != MinigameScore.MAX_SCORE \
			or not is_equal_approx(over["as_left"], plain["as_left"] * MinigameScore.residual_factor(MinigameScore.MAX_SCORE)):
		return "A score over 100 counts as 100, no more: %s" % over.get(MinigameScore.RECORD_KEY)
	for under: int in [-1, -50, -1000000]:
		var cut: Dictionary = _bench([under])
		if cut.get(MinigameScore.RECORD_KEY) != 0 or not _same(cut, plain):
			return "A score under 0 counts as 0, the plain result."
	var commands: Node = _make()
	var id: String = commands.state.STEERING_ID
	var bad: PackedStringArray = []
	for arguments: Array in [[id, 99.5], [id, "100"], [id, true], [id, 50, 50], [id, [100]], [id, NAN]]:
		if commands.problem(&"calibrate_at_bench", arguments) == "":
			bad.append(str(arguments))
	# Only the scored action takes one.
	if commands.problem(&"send_to_oirm", [id, 100]) == "":
		bad.append("send_to_oirm with a score")
	var log_size: int = commands.state.cal_log.size()
	var refused: Dictionary = commands.execute(GUEST, &"calibrate_at_bench", [id, 99.5])
	if refused.get("ok", true) or commands.state.cal_log.size() != log_size:
		bad.append("a refused score still calibrated")
	_free(commands)
	return "" if bad.is_empty() else "Taken, but must be refused: " + ", ".join(bad)


func test_the_host_counts_a_score_only_at_a_key_moment() -> String:
	# The second calibration of its kind is routine: one click, whatever comes with it.
	var routine: Dictionary = _bench([], 1)
	var claimed: Dictionary = _bench([100], 1)
	if claimed.get(MinigameScore.RECORD_KEY) != MinigameScore.SKIPPED or not _same(claimed, routine):
		return "A score with a routine calibration must count for nothing."
	# With the level that opens CAREFUL any bench calibration can be played.
	var careful: Dictionary = _bench([100], 1, true)
	var careful_plain: Dictionary = _bench([], 1, true)
	if careful.get(MinigameScore.RECORD_KEY) != 100 \
			or not is_equal_approx(careful["as_left"], careful_plain["as_left"] * MinigameScore.residual_factor(100)):
		return "At the CAREFUL level a later calibration's score counts."
	var commands: Node = _make()
	var gs: Node = commands.state
	var unit: String = gs.STEERING_ID
	var standard: String = gs.standard_ids()[0]
	var problem: String = ""
	if not MinigameScore.is_due(gs, unit, GUEST, false) or MinigameScore.may_count(gs, standard, GUEST) \
			or MinigameScore.may_count(gs, "no_such_instrument", GUEST):
		problem = "A unit's first calibration is a key moment; a standard's is not without CAREFUL."
	gs.player_skill_xp[GUEST] = { MinigameScore.SKILL: gs.xp_for_level(5) }
	if problem == "" and (not MinigameScore.may_count(gs, standard, GUEST) or MinigameScore.is_due(gs, standard, GUEST, false) \
			or not MinigameScore.is_due(gs, standard, GUEST, true) or MinigameScore.may_count(gs, standard, "player_3")):
		problem = "CAREFUL opens a standard's calibration for the player who has the level and the switch on."
	_free(commands)
	return problem


func test_the_first_of_a_kind_is_the_labs_first_by_hand() -> String:
	var by_robot: Dictionary = { "instrument_id": "laser@TR-1", "standard_id": "s", "performed_by": "TR-1", "programmed_by": "player_1" }
	var by_manager: Dictionary = { "instrument_id": "hygrometer", "standard_id": "s", "performed_by": GameState.MANAGER_ID, "programmed_by": "" }
	var remote_zero: Dictionary = { "instrument_id": "hygrometer", "standard_id": "", "performed_by": "player_1", "programmed_by": "" }
	var by_hand: Dictionary = { "instrument_id": "laser@TR-2", "standard_id": "s", "performed_by": "player_2", "programmed_by": "" }
	if MinigameScore.MANAGER != GameState.MANAGER_ID or MinigameScore.instrument_type("laser@TR-1") != "laser":
		return "The manager's id and a robot sensor's kind must match the farm's."
	if not MinigameScore.is_first_of_type([by_robot, by_manager, remote_zero], "laser@TR-1") \
			or not MinigameScore.is_first_of_type([by_robot, by_manager, remote_zero], "hygrometer"):
		return "A robot's, the manager's and a zero with no standard are not the lab's first by hand."
	if MinigameScore.is_first_of_type([by_hand], "laser@TR-1") or MinigameScore.is_first_of_type([by_hand], "laser") \
			or not MinigameScore.is_first_of_type([by_hand], "hygrometer"):
		return "Once any player has calibrated one of a kind, the kind is no longer new."
	return ""


func _on_finished(score: int) -> void:
	_scores.append(score)


func _new_game() -> SetTheZero:
	var game: SetTheZero = (load(GAME_SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_scores.clear()
	game.finished.connect(_on_finished)
	return game


func _end_game(game: SetTheZero) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(game)
	game.free()


## Steps the game until the needle is within `within` of zero, or `limit_s` has gone.
func _run_to_zero(game: SetTheZero, within: float, limit_s: float = 6.0) -> void:
	var gone: float = 0.0
	game.advance(SetTheZero.ARM_S)
	while absf(game.needle()) > within and gone < limit_s:
		game.advance(0.002)
		gone += 0.002


func test_it_plays_with_no_frames() -> String:
	var game: SetTheZero = _new_game()
	var problem: String = ""
	if game.visible or game.is_playing():
		problem = "The game starts hidden."
	game.play(0.0, MinigameSettings.Mode.STANDARD, 42, "Hygrometer")
	var start: float = game.needle()
	game.advance(0.05)
	game.press()
	if problem == "" and (not game.visible or game.stage() != SetTheZero.Stage.COARSE or game.needle() == start):
		problem = "A press right at the start is not taken, and the needle moves."
	_run_to_zero(game, 0.2)
	var coarse: float = game.needle()
	game.press()
	if problem == "" and game.stage() != SetTheZero.Stage.SETTLE:
		problem = "The first press is the coarse stop."
	game.advance(SetTheZero.SETTLE_S)
	if problem == "" and game.stage() != SetTheZero.Stage.FINE:
		problem = "The fine sweep follows by itself."
	_run_to_zero(game, game.sweet_half() * 0.5)
	var fine: float = game.needle()
	if problem == "" and absf(fine) > SetTheZero.fine_amplitude(coarse) + 0.000001:
		problem = "The fine sweep is as narrow as the coarse stop was off."
	game.press()
	var want: int = SetTheZero.score(coarse, fine, game.sweet_half())
	if problem == "" and (game.stage() != SetTheZero.Stage.RESULT or want < SetTheZero.SWEET_SCORE or not _scores.is_empty()):
		problem = "A stop in the sweet spot is 95 or over, shown before it is sent: %d." % want
	game.press()
	game.advance(SetTheZero.RESULT_ARM_S - 0.05)
	game.press()
	if problem == "" and (not _scores.is_empty() or game.stage() != SetTheZero.Stage.RESULT):
		problem = "A second click right after the fine stop must not close the result."
	game.advance(0.05)
	game.press()
	if problem == "" and (_scores != [want] or game.is_playing() or game.visible):
		problem = "The game ends with its score, once: %s, wanted %d." % [_scores, want]
	# The same seed sweeps the same way; another does not.
	game.play(0.0, MinigameSettings.Mode.STANDARD, 42)
	if problem == "" and game.needle() != start:
		problem = "The same seed must start the same sweep."
	game.play(0.0, MinigameSettings.Mode.STANDARD, 43)
	if problem == "" and (game.needle() == start or _scores != [want, MinigameScore.SKIPPED]):
		problem = "A game started over an open one ends that one with no score: %s." % [_scores]
	_end_game(game)
	return problem


func test_skip_ends_it_with_no_score() -> String:
	var game: SetTheZero = _new_game()
	var problem: String = ""
	game.skip()
	if not _scores.is_empty():
		problem = "With no game open, skip does nothing."
	game.play(1.0, MinigameSettings.Mode.RELAXED, 7)
	if problem == "" and not is_equal_approx(game.sweet_half(), SetTheZero.BASE_SWEET * 2.0 * 1.5):
		problem = "The sweet spot takes the skill's share and the difficulty: %s." % game.sweet_half()
	game.advance(1.0)
	game.skip()
	if problem == "" and (_scores != [MinigameScore.SKIPPED] or game.is_playing() or game.visible):
		problem = "A skip ends the game with no score: %s." % [_scores]
	# Left alone at the result, it goes on by itself with the score.
	game.play(0.0, MinigameSettings.Mode.STANDARD, 7)
	game.advance(0.5)
	game.press()
	game.advance(SetTheZero.SETTLE_S)
	game.advance(0.5)
	game.press()
	game.advance(SetTheZero.RESULT_S)
	if problem == "" and (_scores.size() != 2 or _scores[1] < 0 or _scores[1] > MinigameScore.MAX_SCORE or game.is_playing()):
		problem = "A played game ends with a score of 0 to 100: %s." % [_scores]
	_end_game(game)
	return problem


func test_the_choices_are_kept_on_this_machine() -> String:
	var kept_path: String = MinigameSettings.path
	MinigameSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings._file = null
	var problem: String = ""
	if MinigameSettings.careful() or MinigameSettings.mode() != MinigameSettings.Mode.STANDARD:
		problem = "With nothing kept, CAREFUL is off and the game is Standard."
	MinigameSettings.set_careful(true)
	MinigameSettings.set_mode(MinigameSettings.Mode.RELAXED)
	# Read again from the file.
	MinigameSettings._file = null
	if problem == "" and (not MinigameSettings.careful() or MinigameSettings.mode() != MinigameSettings.Mode.RELAXED):
		problem = "The switch and the difficulty must be kept."
	MinigameSettings.set_mode(77)
	if problem == "" and MinigameSettings.mode() != MinigameSettings.Mode.STANDARD:
		problem = "An unknown difficulty is Standard."
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings.path = kept_path
	MinigameSettings._file = null
	return problem


func test_the_bench_opens_the_game_at_a_key_moment() -> String:
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
	bench.open(GameState.STEERING_ID)
	var game: SetTheZero = bench.get_node("%ZeroGame")
	var careful: CheckButton = bench.get_node("%CarefulCheck")
	var problem: String = ""
	if careful.disabled == GameState.has_skill_unlock(MinigameScore.CAREFUL_UNLOCK) or game.visible:
		problem = "CAREFUL is locked until its level, and no game is open."
	MinigameSettings.set_mode(MinigameSettings.Mode.OFF)
	if problem == "" and bench._zero_game_due(GameState.STEERING_ID):
		problem = "With the games off, none is due."
	MinigameSettings.set_mode(MinigameSettings.Mode.STANDARD)
	if problem == "" and not bench._zero_game_due(GameState.STEERING_ID):
		problem = "The lab's first steering encoder calibration is a key moment."
	bench._on_calibrate_pressed()
	if problem == "" and (not game.is_playing() or not game.visible or not GameState.cal_log.is_empty()):
		problem = "ZERO / CALIBRATE opens the game first, and nothing is calibrated yet."
	bench.close()
	if problem == "" and (game.is_playing() or not GameState.cal_log.is_empty()):
		problem = "Closing the bench with the game open calibrates nothing."
	root.remove_child(bench)
	bench.free()
	GameState.cal_log = kept_log
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MinigameSettings.path = kept_path
	MinigameSettings._file = null
	return problem


func test_a_hitch_or_a_fast_farm_clock_does_not_jump_the_needle() -> String:
	if SetTheZero.frame_step(5.0) != SetTheZero.MAX_STEP_S or SetTheZero.frame_step(-1.0) != 0.0 \
			or not is_equal_approx(SetTheZero.frame_step(0.016), 0.016):
		return "One frame moves the game by its real time, 0.1 s at most."
	var game: SetTheZero = _new_game()
	var kept: float = Engine.time_scale
	Engine.time_scale = 50.0
	game.play(0.0, MinigameSettings.Mode.STANDARD, 42)
	game.advance(0.3)
	game.press()
	# One frame, however long the farm's clock says it was.
	game._process(SetTheZero.SETTLE_S * 50.0)
	Engine.time_scale = kept
	var problem: String = ""
	if game.stage() != SetTheZero.Stage.SETTLE:
		problem = "The farm's clock must not run the game's timers."
	_end_game(game)
	return problem


func test_the_factor_is_taken_back_when_nothing_is_calibrated() -> String:
	var saved: float = GameClock.elapsed_days
	var waits: bool = GameClock.morning_waits
	var commands: Node = _make()
	var gs: Node = commands.state
	var id: String = gs.STEERING_ID
	# No time left tonight: the bench refuses.
	GameClock.morning_waits = true
	GameClock.elapsed_days = floorf(saved) + 1.0 - GameClock.BEFORE_MORNING_DAYS
	var refused: Variant = commands.execute(GUEST, &"calibrate_at_bench", [id, 100])
	GameClock.morning_waits = waits
	GameClock.elapsed_days = saved
	var problem: String = ""
	if not refused is Dictionary or not refused.get("refused", false) or refused.has(MinigameScore.RECORD_KEY) \
			or not gs.cal_log.is_empty():
		problem = "The bench must refuse with no time left: %s" % [refused]
	elif gs.get_sensor(id).next_residual_scale != 1.0:
		problem = "A refused calibration must leave no factor for the next zero."
	# So the next plain one is plain.
	var sensor: DriftingSensor = gs.get_sensor(id)
	sensor._rng.seed = 811
	sensor.error = sensor.mpe * 0.25
	gs.get_sensor(sensor.calibrated_by).error = 0.0
	var next: Dictionary = commands.execute(GUEST, &"calibrate_at_bench", [id])
	GameClock.elapsed_days = saved
	_free(commands)
	if problem == "" and not is_equal_approx(next["as_left"], _bench([])["as_left"]):
		problem = "The calibration after a refused one must be the plain result."
	return problem


func test_a_request_carries_the_score() -> String:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var id: String = gs.STEERING_ID
	var bad: PackedStringArray = []
	# As a guest nothing is done here; a bad score is refused before it is sent.
	commands.guest = true
	var refused: Dictionary = await commands.request(&"calibrate_at_bench", [id, 99.5])
	if refused.get("ok", true) or not str(refused.get("reason", "")).contains("bad score"):
		bad.append("a guest's request with 99.5 was not refused: %s" % [refused])
	var unsent: Dictionary = await commands.request(&"calibrate_at_bench", [id, 90])
	if str(unsent.get("reason", "")) != "Not connected to the host.":
		bad.append("a whole score must pass the guest's own check: %s" % [unsent])
	commands.guest = false
	# The host's own request: done here, as the local player.
	var mine: Dictionary = commands.request(&"calibrate_at_bench", [id, 90])
	if mine.get(MinigameScore.RECORD_KEY, -9) != 90 or gs.cal_log.size() != 1 \
			or gs.cal_log[0].get("performed_by", "") != gs.local_player_id:
		bad.append("the host's request with 90 must count 90: %s" % [mine.get(MinigameScore.RECORD_KEY)])
	var again: Dictionary = commands.request(&"calibrate_at_bench", [id, 99.5])
	if again.get("ok", true) or gs.cal_log.size() != 1:
		bad.append("the host's request with 99.5 was not refused")
	GameClock.elapsed_days = saved
	_free(commands)
	return "; ".join(bad)


func test_a_guests_score_for_a_standard_or_a_robot_counts_for_nothing() -> String:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var gs: Node = commands.state
	var standard: String = gs.standard_ids()[0]
	var problem: String = ""
	# A robot is no instrument, and a robot's sensor that is not on the farm is none.
	for id: String in ["TR-1", "robot_joint_encoder@TR-99"]:
		if MinigameScore.allowed(gs, id, GUEST, 100) != MinigameScore.SKIPPED:
			problem = "A score for %s must be cut to none." % id
		var answer: Variant = commands.execute(GUEST, &"calibrate_at_bench", [id, 100])
		if answer is Dictionary and (answer.has(MinigameScore.RECORD_KEY) or answer.has("as_left")):
			problem = "Nothing is calibrated or scored for %s." % id
	if MinigameScore.allowed(gs, standard, GUEST, 100) != MinigameScore.SKIPPED:
		problem = "A score for a standard must be cut to none without the CAREFUL level."
	var sensor: DriftingSensor = gs.get_sensor(standard)
	var answer: Variant = commands.execute(GUEST, &"calibrate_at_bench", [standard, 100])
	if problem == "" and answer is Dictionary and answer.get(MinigameScore.RECORD_KEY, MinigameScore.SKIPPED) != MinigameScore.SKIPPED:
		problem = "The host counted a score for a standard: %s" % [answer.get(MinigameScore.RECORD_KEY)]
	if problem == "" and sensor.next_residual_scale != 1.0:
		problem = "A standard's next zero must take no factor."
	GameClock.elapsed_days = saved
	_free(commands)
	return problem


func test_a_stale_score_is_told_as_not_counted() -> String:
	# The guest played when the kind was new; another player's calibration landed first.
	var routine: Dictionary = _bench([], 1)
	var stale: Dictionary = _bench([97], 1)
	if stale.get(MinigameScore.RECORD_KEY, 0) != MinigameScore.SKIPPED:
		return "A score for a kind no longer new must come back as not counted: %s" % [stale.get(MinigameScore.RECORD_KEY)]
	if not _same(stale, routine) or stale["logged"] != routine["logged"]:
		return "A stale score must leave the result as it would have been."
	if MinigameScore.result_text(MinigameScore.SKIPPED) != "" or MinigameScore.NOT_COUNTED_TEXT == "":
		return "The bench has a line for a score the host did not count."
	return ""
