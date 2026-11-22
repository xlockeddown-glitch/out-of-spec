extends RefCounted
## Co-op groundwork (2026-11-22): every random draw the simulation makes comes
## from the farm's world seed, so a joining player sent the seed sees the same
## game. Same seed: same drift directions, as-left residuals and dispatch order.
## Different seeds: something differs.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state(p_seed: int) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	gs.set_world_seed(p_seed)
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


## Everything random a fresh farm draws: each sensor's sign, then each
## sensor's as-left residual after two zeroings, then the dispatch deck order.
func _fingerprint(p_seed: int) -> Array:
	var gs: GameStateScript = _make_state(p_seed)
	var out: Array = []
	var ids: Array = gs.sensors.keys()
	ids.sort()
	for id: Variant in ids:
		out.append([str(id), (gs.sensors[id] as DriftingSensor)._sign])
	for id: Variant in ids:
		var sensor: DriftingSensor = gs.sensors[id]
		for _i: int in 2:
			out.append(snappedf(float(sensor.zero().get("as_left", 0.0)), 0.000001))
		out.append(sensor._sign)
	gs._post_morning_dispatch(1)
	for entry: Variant in gs._dispatch_deck:
		out.append(str((entry as Dictionary).get("text", "")))
	_done(gs)
	return out


func test_same_seed_same_world() -> String:
	var a: Array = _fingerprint(12345)
	var b: Array = _fingerprint(12345)
	if a.is_empty():
		return "nothing random was drawn"
	if a != b:
		return "same seed gave different draws"
	return ""


func test_different_seeds_can_differ() -> String:
	var a: Array = _fingerprint(12345)
	for other: int in [1, 2, 3, 99999]:
		if _fingerprint(other) != a:
			return ""
	return "different seeds always gave the same draws"


func test_reseeding_restarts_the_draws() -> String:
	var gs: GameStateScript = _make_state(777)
	var first: Array = []
	for _i: int in 5:
		first.append(gs.rng.randi())
	gs.set_world_seed(777)
	for i: int in 5:
		if gs.rng.randi() != first[i]:
			_done(gs)
			return "set_world_seed did not restart the generator"
	if gs.world_seed != 777:
		_done(gs)
		return "world_seed not stored"
	_done(gs)
	return ""


func test_shuffle_keeps_every_item() -> String:
	var gs: GameStateScript = _make_state(42)
	var list: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	gs._shuffle(list)
	var sorted: Array = list.duplicate()
	sorted.sort()
	var picked: Variant = gs._pick([])
	_done(gs)
	if sorted != [1, 2, 3, 4, 5, 6, 7, 8]:
		return "shuffle lost or duplicated items: %s" % [list]
	if picked != null:
		return "picking from an empty list should give null"
	return ""
