extends RefCounted
## Calibration records name the player by id (co-op groundwork); the screen
## shows "You" only for the local player.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	return gs


func test_records_hold_player_ids() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	gs.local_player_id = "player_2"
	var by_default: Dictionary = gs.calibrate(gs.STEERING_ID, "", false)
	var by_other: Dictionary = gs.calibrate(gs.STEERING_ID, "player_1", false)
	var at_bench: Dictionary = gs.calibrate_at_bench(gs.HYGROMETER_ID)
	var at_bench_other: Dictionary = gs.calibrate_at_bench(gs.HYGROMETER_ID, "player_1")
	GameClock.elapsed_days = saved
	gs.free()
	if by_default.get("performed_by", "") != "player_2" or at_bench.get("performed_by", "") != "player_2":
		return "With no player named, the local player's id must be recorded: %s, %s" % [by_default, at_bench]
	if by_other.get("performed_by", "") != "player_1" or at_bench_other.get("performed_by", "") != "player_1":
		return "A named player's id must be recorded: %s, %s" % [by_other, at_bench_other]
	return ""


func test_performer_names() -> String:
	var gs: GameStateScript = _make_state()
	gs.local_player_id = "player_2"
	var names: Array[String] = []
	for id: String in ["player_2", "player_1", gs.MANAGER_ID, "You", ""]:
		names.append(gs.performer_name(id))
	gs.free()
	if names != ["You", "player_1", "Manager", "You", "You"]:
		return "Only the local player and old records read 'You', got %s" % [names]
	return ""
