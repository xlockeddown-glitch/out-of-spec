extends RefCounted
## The molt runs on game time, not real seconds (co-op groundwork).
## Clocks and GameStates made here are private and freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const GameClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")


## Sensors dead on and not drifting, so only the molt moves.
func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	for id: String in gs.sensors:
		var sensor: DriftingSensor = gs.get_sensor(id)
		sensor.error = 0.0
		sensor.max_error = 0.0
	return gs


func test_molt_pace_is_unchanged() -> String:
	if not is_equal_approx(GameStateScript.PLAYTEST_MOLT_DAYS * GameClock.seconds_per_day, 20.0):
		return "At the default pace a molt must still take 20 s, got %s s." % (
			GameStateScript.PLAYTEST_MOLT_DAYS * GameClock.seconds_per_day)
	return ""


func test_molt_follows_the_running_clock() -> String:
	var gs: GameStateScript = _make_state()
	var clock: GameClockScript = GameClockScript.new()
	clock.time_advanced.connect(gs._on_time_advanced)
	clock.clock_ran.connect(gs._tick_molt)
	clock._process(10.0)
	var half: float = gs.molt_progress
	clock.paused = true
	clock._process(10.0)
	clock.paused = false
	clock.skip_to_next_morning()
	var after_jump: float = gs.molt_progress
	gs.hygrometer.max_error = INF
	gs.hygrometer.error = gs.hygrometer.mpe * 2.0
	clock._process(10.0)
	var out_of_spec: float = gs.molt_progress
	gs.hygrometer.error = 0.0
	gs.hygrometer.max_error = 0.0
	clock._process(7.0)
	var pre_molt: bool = gs.molt_stage == gs.MoltStage.PRE_MOLT
	clock._process(10.0)
	var done: bool = gs.is_spool_ready() and gs.molt_progress == 1.0
	clock.free()
	gs.free()
	if not is_equal_approx(half, 0.5):
		return "10 s at the default pace must give half the molt, got %s." % half
	if after_jump != half:
		return "A pause or a time jump must not advance the molt, got %s." % after_jump
	if out_of_spec != half:
		return "A hygrometer past MPE must hold the molt, got %s." % out_of_spec
	if not pre_molt or not done:
		return "The molt must pass through pre-molt and finish: %s, %s" % [pre_molt, done]
	return ""


func test_live_molt_is_wired_to_the_clock() -> String:
	if not GameClock.clock_ran.is_connected(GameState._tick_molt):
		return "GameState must tick the molt from GameClock.clock_ran."
	if GameState.is_processing():
		return "GameState must not run on real seconds in _process."
	return ""
