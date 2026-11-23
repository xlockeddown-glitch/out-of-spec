extends RefCounted
## The molt runs on game time, not real seconds (co-op groundwork).
## GameClock's own fields are saved and restored; nothing listens to the
## GameState made here, so its _on_time_advanced is called directly.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


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


func test_molt_follows_game_time() -> String:
	var gs: GameStateScript = _make_state()
	var full: float = gs.PLAYTEST_MOLT_DAYS
	gs._on_time_advanced(full * 0.5)
	var half: float = gs.molt_progress
	gs._on_time_advanced(full * 0.35)
	var pre_molt: bool = gs.molt_stage == gs.MoltStage.PRE_MOLT
	gs._on_time_advanced(1.0)
	var done: bool = gs.is_spool_ready() and gs.molt_progress == 1.0
	var polls: bool = gs.has_method("_process")
	gs.free()
	if not is_equal_approx(half, 0.5):
		return "Half the molt time must give half the progress, got %s." % half
	if not pre_molt or not done:
		return "The molt must pass through pre-molt and finish on a time jump: %s, %s" % [pre_molt, done]
	if polls:
		return "GameState must not run the molt on real seconds in _process."
	return ""
