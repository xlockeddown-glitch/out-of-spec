extends RefCounted
## Milestone 4: what skill levels change.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const EPS: float = 1.0e-9


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 100000
	gs.tier1_unlocked = true
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func _level(gs: GameStateScript, skill: String, level: int, player: String = "player_1") -> void:
	if gs.is_farm_skill(skill):
		gs.farm_skill_xp[skill] = gs.xp_for_level(level)
	else:
		var own: Dictionary = gs.player_skill_xp.get_or_add(player, {})
		own[skill] = gs.xp_for_level(level)


func test_factors_and_unlocks() -> String:
	return _run(_check_factors)


func _check_factors(gs: GameStateScript) -> String:
	for effect: Dictionary in DataManager.get_records(&"skills", "effects"):
		var id: String = effect["id"]
		if not effect["skill"] in gs.skill_ids():
			return "%s names an unknown skill." % id
		if gs.skill_factor(id) != 1.0:
			return "%s must change nothing at level 1." % id
		_level(gs, effect["skill"], 2)
		if absf(gs.skill_factor(id) - (1.0 - float(effect["full"]) * gs.effect_share(2))) > EPS or gs.skill_factor(id) >= 1.0:
			return "%s at level 2: %s" % [id, gs.skill_factor(id)]
		_level(gs, effect["skill"], gs.max_skill_level())
		if gs.skill_factor(id) <= 0.0 or gs.skill_factor(id) < float(effect.get("floor", 0.0)):
			return "%s at the top level: %s" % [id, gs.skill_factor(id)]
		_level(gs, effect["skill"], 1)
	for unlock: Dictionary in DataManager.get_records(&"skills", "unlocks"):
		_level(gs, unlock["skill"], int(unlock["level"]) - 1)
		if gs.has_skill_unlock(unlock["id"]):
			return "%s opens too soon." % unlock["id"]
		_level(gs, unlock["skill"], int(unlock["level"]))
		if not gs.has_skill_unlock(unlock["id"]):
			return "%s must open at its level." % unlock["id"]
	return "" if gs.skill_factor("none") == 1.0 and not gs.has_skill_unlock("none") else "An unknown effect changes nothing."


func test_operator_uncertainty() -> String:
	return _run(_check_operator)


func _check_operator(gs: GameStateScript) -> String:
	var base: Dictionary = gs.calibration_budget(gs.STEERING_ID)
	_level(gs, "uncertainty", 5)
	var skilled: Dictionary = gs.calibration_budget(gs.STEERING_ID)
	if skilled["u_op"] >= base["u_op"] or skilled["tur"] <= base["tur"]:
		return "Uncertainty must shrink u_op and raise the TUR."
	if gs.calibration_budget(gs.STEERING_ID, "player_2")["u_op"] != base["u_op"]:
		return "Only for the player who has the skill."
	if gs.calibrate(gs.STEERING_ID, "player_2")["tur"] != base["tur"]:
		return "The calibration must use the operator's own term."
	return ""


func test_bench_time_and_residual() -> String:
	return _run(_check_bench)


func _check_bench(gs: GameStateScript) -> String:
	_level(gs, "calibration", 4)
	var minutes: float = gs.steering.bench_minutes
	var job: Dictionary = { "bench_minutes": 60.0 }
	if absf(gs.job_minutes(job) - 60.0 * gs.skill_factor("bench_time")) > EPS or gs.job_minutes(job, "player_2") != 60.0:
		return "A job takes the player's own bench time."
	var start: float = GameClock.elapsed_days
	gs.calibrate_at_bench(gs.STEERING_ID)
	var spent: float = (GameClock.elapsed_days - start) * 1440.0
	if absf(spent - minutes * gs.skill_factor("bench_time")) > 1.0e-6:
		return "Bench time spent: %s of %s" % [spent, minutes]
	return ""


func test_residual_scale() -> String:
	return _run(_check_residual)


func _check_residual(gs: GameStateScript) -> String:
	_level(gs, "calibration", 5)
	var sensor: DriftingSensor = gs.steering
	var carried: float = gs.get_sensor(sensor.calibrated_by).error * gs.get_sensor(sensor.calibrated_by).standard_sensitivity
	sensor._rng.seed = 7
	gs.calibrate(gs.STEERING_ID, "player_2")
	var plain: float = sensor.error - carried
	sensor._rng.seed = 7
	gs.calibrate(gs.STEERING_ID)
	if absf(sensor.error - carried - plain * gs.skill_factor("as_left_residual")) > EPS:
		return "The skill must shrink the residual only."
	sensor._rng.seed = 7
	gs.calibrate(gs.STEERING_ID, "player_2", false)
	var remote: float = sensor.error
	sensor._rng.seed = 7
	gs.calibrate(gs.STEERING_ID, "player_1", false)
	return "" if sensor.error == remote else "The remote zero must not change."


func test_steering_and_molt() -> String:
	return _run(_check_steering_and_molt)


func _check_steering_and_molt(gs: GameStateScript) -> String:
	_level(gs, "field_ops", 5)
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	var before: Array[float] = [gs.steering.error, tire.error]
	gs.add_rover_usage(100.0, "player_2")
	var plain: Array[float] = [gs.steering.error - before[0], tire.error - before[1]]
	before = [gs.steering.error, tire.error]
	gs.add_rover_usage(100.0)
	if absf(gs.steering.error - before[0] - plain[0] * gs.skill_factor("steering_usage")) > EPS:
		return "Field Ops must spare the steering encoder."
	if absf(tire.error - before[1] - plain[1]) > EPS:
		return "It must not spare the tire gauge."
	_level(gs, "husbandry", 4)
	if absf(gs.molt_days() - gs.PLAYTEST_MOLT_DAYS * gs.skill_factor("molt_time")) > EPS or gs.molt_days() >= gs.PLAYTEST_MOLT_DAYS:
		return "Husbandry must shorten the molt."
	gs.molt_stage = gs.MoltStage.MOLTED
	return "" if gs.molt_text().begins_with("MOLTED") else gs.molt_text()


func test_skills_view_text() -> String:
	return _run(_check_text)


func _check_text(gs: GameStateScript) -> String:
	for id: String in gs.skill_ids():
		if not gs.skill_text(id).contains("level 1") or gs.skill_effects_text(id) == "":
			return "%s: %s" % [id, gs.skill_text(id)]
		_level(gs, id, gs.max_skill_level())
		if not gs.skill_text(id).contains("top level"):
			return gs.skill_text(id)
	# At the top level every unlock is open, so none says the level it opens at.
	return "" if not gs.skill_effects_text("husbandry").contains("Level 3") else "An open unlock must not say its level."
