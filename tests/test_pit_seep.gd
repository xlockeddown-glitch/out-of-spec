extends RefCounted
## Ground water seeps into a dug pit slowly, up to the level it would reach in the end.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FLAT := Vector2i(-21, 3)

var _none: Dictionary[Vector2i, int] = {}


func _pit() -> Dictionary[Vector2i, int]:
	var dug: Dictionary[Vector2i, int] = {}
	for x: int in range(-3, 4):
		for z: int in range(-3, 4):
			dug[FLAT + Vector2i(x, z)] = 4 - maxi(absi(x), absi(z))
	return dug


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.dug.assign(_pit())
	return gs


func _level(seeped: Dictionary[Vector2i, float]) -> float:
	return PitWater.work_out(_pit(), {}, seeped)["levels"].get(FLAT, -INF)


func test_a_new_pit_is_dry_and_fills_at_the_seep_rate() -> String:
	var dug: Dictionary[Vector2i, int] = _pit()
	var end_m: float = PitWater.work_out(dug, {})["levels"][FLAT]
	var seeped: Dictionary[Vector2i, float] = {}
	if _level(seeped) != -INF:
		return "A pit with no seep must be dry."
	seeped = PitWater.seep(seeped, dug, 1.0)
	var low_m: float = Terrain.point_height(Vector2i(FLAT * 2) + Vector2i.ONE, dug)
	var one_day: float = seeped[FLAT]
	if not is_equal_approx(one_day, minf(end_m, low_m + PitWater.SEEP_M_PER_DAY)):
		return "A day of seep gave %f, not %f." % [one_day, minf(end_m, low_m + PitWater.SEEP_M_PER_DAY)]
	if end_m > low_m + PitWater.SEEP_M_PER_DAY and _level(seeped) != one_day:
		return "The pit must hold what has seeped."
	return ""


func test_seep_stops_at_the_level_the_pit_would_reach() -> String:
	var dug: Dictionary[Vector2i, int] = _pit()
	var end_m: float = PitWater.work_out(dug, {})["levels"][FLAT]
	var seeped: Dictionary[Vector2i, float] = PitWater.seep({}, dug, 1000.0)
	if not is_equal_approx(seeped[FLAT], end_m) or not is_equal_approx(_level(seeped), end_m):
		return "A long wait must end at %f, not %f." % [end_m, seeped[FLAT]]
	return ""


func test_seep_is_slow_and_in_steps_that_add_up() -> String:
	var dug: Dictionary[Vector2i, int] = _pit()
	var once: Dictionary[Vector2i, float] = PitWater.seep({}, dug, 0.1)
	var twice: Dictionary[Vector2i, float] = PitWater.seep(PitWater.seep({}, dug, 0.05), dug, 0.05)
	if not is_equal_approx(once[FLAT], twice[FLAT]):
		return "Two half steps differ from one step."
	if PitWater.work_out(dug, {}, once)["levels"].get(FLAT, -INF) >= PitWater.work_out(dug, {})["levels"][FLAT]:
		return "A tenth of a day must not fill the pit."
	return ""


func test_a_pit_filled_in_is_forgotten() -> String:
	var dug: Dictionary[Vector2i, int] = _pit()
	var seeped: Dictionary[Vector2i, float] = PitWater.seep({}, dug, 1000.0)
	dug.clear()
	dug[FLAT] = 1
	if not PitWater.seep(seeped, dug, 0.0).is_empty():
		return "Cells that hold no water are still kept."
	return ""


func test_the_host_seeps_on_its_clock_and_a_guest_does_not() -> String:
	var gs: GameStateScript = _state()
	var told: Array[int] = [0]
	gs.pit_seep_changed.connect(func() -> void: told[0] += 1)
	gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS / 2.0)
	if not gs.pit_seep.is_empty():
		gs.free()
		return "A half step must wait for the other half."
	gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS / 2.0)
	var risen: bool = gs.pit_seep.has(FLAT) and told[0] == 1
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	var before: Dictionary[Vector2i, float] = gs.pit_seep.duplicate()
	gs._on_time_advanced(1000.0)
	FarmCommands.guest = held
	var unchanged: bool = gs.pit_seep == before
	gs.free()
	if not risen:
		return "The host's seep did not rise and say so."
	return "" if unchanged else "A guest moved the ground water."


func test_a_long_sleep_fills_the_pit_and_digging_keeps_it_tidy() -> String:
	var gs: GameStateScript = _state()
	gs._on_time_advanced(1000.0)
	var end_m: float = PitWater.work_out(gs.dug, {})["levels"][FLAT]
	var full: bool = is_equal_approx(gs.pit_seep[FLAT], end_m)
	gs.dug.clear()
	var dug_it: String = gs.dig(Vector3i(20, 0, 20))
	var tidy: bool = gs.pit_seep.is_empty()
	gs.free()
	if dug_it != "":
		return "The dig was refused: %s" % dug_it
	if not full:
		return "A long sleep did not fill the pit."
	return "" if tidy else "Digging left the old pit's water behind."


func test_ground_water_is_saved_and_an_old_save_has_full_pits() -> String:
	var gs: GameStateScript = _state()
	gs._on_time_advanced(0.2)
	var data: Dictionary = gs.farm_to_dict()
	var back: GameStateScript = GameStateScript.new()
	back.build_registry()
	var problem: String = back.farm_dict_problem(data)
	if problem == "":
		back.put_farm(data)
	var kept: bool = back.pit_seep == gs.pit_seep and not gs.pit_seep.is_empty()
	data.erase("pit_seep")
	var old: GameStateScript = GameStateScript.new()
	old.build_registry()
	var old_problem: String = old.farm_dict_problem(data)
	if old_problem == "":
		old.put_farm(data)
	var end_m: float = PitWater.work_out(gs.dug, {})["levels"][FLAT]
	var full: bool = old.pit_seep.get(FLAT, -INF) == end_m
	gs.free()
	back.free()
	old.free()
	if problem != "" or old_problem != "":
		return "The farm would not load: %s %s" % [problem, old_problem]
	if not kept:
		return "The ground water was not saved."
	return "" if full else "An old save's pits must start full."


func test_a_bad_seep_is_refused() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	(data["pit_seep"] as Dictionary)[Vector2i(0, 0)] = 1.0
	var problem: String = gs.farm_dict_problem(data)
	gs.free()
	return "" if problem != "" else "A seep in a cell that can't be dug was accepted."
