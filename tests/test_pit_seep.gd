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
	if end_m > low_m + PitWater.SEEP_M_PER_DAY and absf(_level(seeped) - one_day) > PitWater.SEEP_SHOWN_M:
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
	# The first step is still dry to the eye, so it need not say so.
	var risen: bool = gs.pit_seep.has(FLAT) and told[0] <= 1
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	var before: Dictionary[Vector2i, float] = gs.pit_seep.duplicate()
	gs._on_time_advanced(1000.0)
	FarmCommands.guest = held
	var unchanged: bool = gs.pit_seep == before
	gs.free()
	if not risen:
		return "The host's seep did not rise."
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


func test_a_seep_value_that_is_not_a_finite_number_is_refused() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var cell: Vector2i = FLAT
	for bad: Variant in ["deep", INF, NAN, 3]:
		# A save read back from disk is untyped, so it can hold anything.
		var seep: Dictionary = {}
		seep[cell] = bad
		data["pit_seep"] = seep
		if gs.farm_dict_problem(data) == "":
			gs.free()
			return "A seep of %s was accepted." % str(bad)
	gs.free()
	return ""


func test_a_full_pit_is_not_worked_out_again_until_the_digging_changes() -> String:
	var gs: GameStateScript = _state()
	gs._on_time_advanced(1000.0)
	gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS)
	var settled: bool = gs._seep_full
	var told: Array[int] = [0]
	gs.pit_seep_changed.connect(func() -> void: told[0] += 1)
	gs._on_time_advanced(10.0)
	var quiet: bool = told[0] == 0
	gs.dig(Vector3i(20, 0, 20))
	var woke: bool = not gs._seep_full
	gs.free()
	if not settled:
		return "A pit at its end level was not marked full."
	if not quiet:
		return "A full pit said it changed."
	return "" if woke else "Digging must wake the seep."


func test_a_rising_pit_says_so_only_each_centimeter() -> String:
	var gs: GameStateScript = _state()
	var told: Array[int] = [0]
	gs.pit_seep_changed.connect(func() -> void: told[0] += 1)
	# One step is 1.25 mm at the seep rate, so eight steps are a centimeter.
	for i: int in 8:
		gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS)
	gs.free()
	return "" if told[0] <= 2 else "Eight steps said %d times." % told[0]


func test_the_view_follows_a_seep_change() -> String:
	var gs: GameStateScript = _state()
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	GameState.dug.clear()
	GameState.dug.merge(_pit())
	GameState.pit_seep.clear()
	var view := PitWaterView.new()
	view._ready()
	var dry: bool = view.worked_count == 1 and PitWater.levels().is_empty()
	GameState.pit_seep.assign(PitWater.seep({}, GameState.dug, 1000.0))
	GameState.pit_seep_changed.emit()
	view._refresh()
	var wet: bool = view.worked_count == 2 and PitWater.levels().has(FLAT)
	GameState.dug.clear()
	GameState.dug.merge(saved)
	GameState.pit_seep.clear()
	view.free()
	gs.free()
	if not dry:
		return "A new pit must start dry in the view."
	return "" if wet else "The view did not follow the seep."


func test_a_guest_gets_the_seep_on_join_and_update() -> String:
	var host: GameStateScript = _state()
	host._on_time_advanced(0.1)
	var guest: GameStateScript = GameStateScript.new()
	guest.build_registry()
	var held: bool = FarmCommands.guest
	var bytes: PackedByteArray = FarmSync.capture(host)
	FarmCommands.guest = true
	var problem: String = FarmSync.join(bytes, guest)
	var joined: bool = guest.pit_seep == host.pit_seep and not host.pit_seep.is_empty()
	FarmCommands.guest = false
	host._on_time_advanced(0.1)
	bytes = FarmSync.capture(host)
	FarmCommands.guest = true
	var told: Array[int] = [0]
	guest.pit_seep_changed.connect(func() -> void: told[0] += 1)
	problem += FarmSync.update(bytes, guest)
	var updated: bool = guest.pit_seep == host.pit_seep and told[0] == 1
	FarmCommands.guest = held
	host.free()
	guest.free()
	if problem != "":
		return problem
	if not joined:
		return "A joining guest lacks the ground water."
	return "" if updated else "An update must carry the ground water and say so."


func _full() -> Dictionary[Vector2i, float]:
	return PitWater.seep({}, _pit(), 1000.0)


func _lowered(by_m: float) -> Dictionary[Vector2i, float]:
	var out: Dictionary[Vector2i, float] = {}
	var full: Dictionary[Vector2i, float] = _full()
	for cell: Vector2i in full:
		out[cell] = full[cell] - by_m
	return out


func test_a_pit_that_reaches_its_end_is_drawn_at_it_and_says_so() -> String:
	var cap: float = _full()[FLAT]
	# A hair under the end shows differently from the end, so the screens redraw.
	if PitWater.shown(_lowered(0.0005), _pit()) == PitWater.shown(_full(), _pit()):
		return "The last bit before the end shows the same as the end."
	if not is_equal_approx(_level(_full()), cap):
		return "A full pit is drawn at %f, not %f." % [_level(_full()), cap]
	return ""


func test_water_is_never_drawn_above_where_it_ends() -> String:
	var cap: float = _full()[FLAT]
	for hair: int in range(1, 100):
		var seeped: Dictionary[Vector2i, float] = _lowered(hair * 0.0001)
		var level: float = _level(seeped)
		if level > cap:
			return "Water shown at %f is above its end %f." % [level, cap]
		if level > seeped[FLAT] + 0.00001:
			return "Water shown at %f is above its seep %f." % [level, seeped[FLAT]]
	return ""


func test_a_dig_far_from_every_pit_sends_no_seep_change() -> String:
	var gs: GameStateScript = _state()
	gs._on_time_advanced(1000.0)
	var told: Array[int] = [0]
	gs.pit_seep_changed.connect(func() -> void: told[0] += 1)
	var problem: String = gs.dig(Vector3i(20, 0, 20))
	gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS)
	gs._on_time_advanced(1.0)
	gs.free()
	if problem != "":
		return "The far dig was refused: " + problem
	return "" if told[0] == 0 else "A far dig sent %d seep changes." % told[0]


func test_digging_a_seeping_pit_deeper_keeps_its_level() -> String:
	var gs: GameStateScript = _state()
	# A pit three steps down, to dig its middle one deeper.
	gs.dug[FLAT] = 3
	gs._on_time_advanced(0.2)
	var before: float = gs.pit_seep[FLAT]
	var problem: String = gs.dig(Vector3i(FLAT.x, 0, FLAT.y))
	var after: float = gs.pit_seep.get(FLAT, -INF)
	gs.free()
	if problem != "":
		return "The dig was refused: %s" % problem
	return "" if is_equal_approx(before, after) else "Digging deeper changed %f to %f." % [before, after]


func test_pits_that_join_take_the_higher_level() -> String:
	var dug: Dictionary[Vector2i, int] = _pit()
	var seeped: Dictionary[Vector2i, float] = {}
	var low: float = _full()[FLAT] - 0.5
	seeped[FLAT] = low
	seeped[FLAT + Vector2i(1, 0)] = low + 0.1
	var next: Dictionary[Vector2i, float] = PitWater.seep(seeped, dug, 0.0)
	if not is_equal_approx(next[FLAT], low + 0.1) or not is_equal_approx(next[FLAT + Vector2i(1, 1)], low + 0.1):
		return "The joined pit did not take the higher level."
	return ""


func test_filling_the_floor_above_the_water_leaves_no_water_below_it() -> String:
	var gs: GameStateScript = _state()
	gs._on_time_advanced(0.1)
	var problem: String = gs.fill(Vector3i(FLAT.x, 0, FLAT.y))
	var worked: Dictionary[Vector2i, float] = PitWater.work_out(gs.dug, {}, gs.pit_seep)["levels"]
	var bad: String = ""
	var floor_m: float = INF
	for cell: Vector2i in gs.pit_seep:
		floor_m = minf(floor_m, Terrain.point_height(Vector2i(cell * 2) + Vector2i.ONE, gs.dug))
	for cell: Vector2i in gs.pit_seep:
		if gs.pit_seep[cell] < floor_m:
			bad = "A kept level is below the pit's floor."
		if worked.has(cell) and worked[cell] < floor_m:
			bad = "Water is drawn below the floor."
	gs.free()
	return problem if problem != "" else bad


func test_host_steps_tell_the_screens_until_the_pit_is_full() -> String:
	var gs: GameStateScript = _state()
	var told: Array[int] = [0]
	gs.pit_seep_changed.connect(func() -> void: told[0] += 1)
	var cap: float = _full()[FLAT]
	var steps: int = 0
	while steps < 100000 and not is_equal_approx(gs.pit_seep.get(FLAT, -INF), cap):
		gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS)
		steps += 1
	var reached: bool = is_equal_approx(gs.pit_seep.get(FLAT, -INF), cap)
	var while_rising: int = told[0]
	gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS)
	gs._on_time_advanced(GameStateScript.SEEP_STEP_DAYS)
	var after_full: int = told[0] - while_rising
	gs.free()
	if not reached:
		return "The pit never reached its end in %d steps." % steps
	if while_rising == 0:
		return "The host's steps filled the pit without telling the screens."
	return "" if after_full == 0 else "A full pit still sent %d changes." % after_full
