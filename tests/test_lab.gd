extends RefCounted
## Upgradeable lab (Ryan, 2026-11-22): the lab has spaces for its size, each
## given to a discipline; a discipline's spaces are how many of its jobs fit
## at once, and the biggest jobs need a large area. Growing costs credits and
## crystal ore and takes days; clearing a space costs and has downtime.
## Numbers come from data/economy.json ([PLACEHOLDER]); the tests read them.
## Each test starts the clock at the first morning and puts it back after.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.credibility = 30
	gs.credits = 0
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


func _template(gs: GameStateScript, id: String) -> Dictionary:
	for template: Dictionary in gs._job_templates():
		if template["id"] == id:
			return template.duplicate(true)
	return {}


## Pays for and finishes the next size, with just enough credits and ore.
func _grow(gs: GameStateScript) -> String:
	var next: Dictionary = gs.lab_next_size()
	gs.credits = int(next.get("credits", 0))
	gs.crystal_ore = int(next.get("ore", 0))
	var problem: String = gs.start_lab_grow()
	if problem == "":
		gs._finish_lab_build(int(gs.lab_build["done_day"]))
	return problem


func test_lab_starts_small_with_the_founding_disciplines() -> String:
	var gs: GameStateScript = _make_state()
	var size: int = gs.lab_size
	var areas: Dictionary = gs.lab_areas.duplicate()
	var free_spaces: int = gs.lab_free_spaces()
	var spaces: int = gs.lab_spaces()
	_done(gs)
	if size != 0:
		return "The lab must start at the smallest size, got %d." % size
	for discipline: String in ["angle", "humidity", "soil moisture"]:
		if int(areas.get(discipline, 0)) != 1:
			return "The founding %s standard needs a space to start, areas %s." % [discipline, areas]
	if areas.size() != 3 or free_spaces != spaces - 3:
		return "Only the founding disciplines get a space, areas %s, %d free." % [areas, free_spaces]
	return ""


func test_a_job_needs_an_area_of_its_discipline() -> String:
	var gs: GameStateScript = _make_state()
	var tire: Dictionary = _template(gs, "kestrel_tire_gauge")
	var without: String = gs.job_area_problem(tire)
	gs.lab_areas["pressure"] = 1
	var with_area: String = gs.job_area_problem(tire)
	_done(gs)
	if without.find("Needs a pressure area") < 0:
		return "A pressure job needs a pressure area, got '%s'." % without
	if with_area != "":
		return "A pressure area must take a pressure job, got '%s'." % with_area
	return ""


func test_spaces_are_how_many_jobs_fit_at_once() -> String:
	var gs: GameStateScript = _make_state()
	var probe: Dictionary = _template(gs, "lin_soil_probe")
	gs.active_jobs.append(probe.duplicate())
	var full: String = gs.job_area_problem(probe)
	var other: String = gs.job_area_problem(_template(gs, "dome4_hygrometer"))
	gs.lab_areas["soil moisture"] = 2
	var room: String = gs.job_area_problem(probe)
	gs.active_jobs.clear()
	_done(gs)
	if full.find("area is full") < 0:
		return "A one-space area with a job in progress must be full, got '%s'." % full
	if other != "":
		return "Another discipline's area must still take jobs, got '%s'." % other
	if room != "":
		return "A second space must take a second job, got '%s'." % room
	return ""


func test_accepting_a_job_checks_the_area() -> String:
	var gs: GameStateScript = _make_state()
	gs.job_board.append(_template(gs, "lin_soil_probe"))
	gs.job_board.append(_template(gs, "lin_soil_probe"))
	var first: String = gs.accept_job(0)
	var second: String = gs.accept_job(0)
	_done(gs)
	if first != "":
		return "The founding soil moisture area must take a job, got '%s'." % first
	if second.find("area is full") < 0:
		return "A second soil job needs a second space, got '%s'." % second
	return ""


func test_the_biggest_jobs_need_a_large_area() -> String:
	var gs: GameStateScript = _make_state()
	var big: Dictionary = _template(gs, "dome1_cabin_transducer")
	var need: int = gs.lab_area_spaces_needed(str(big.get("area", "")))
	var none: String = gs.job_area_problem(big)
	gs.lab_areas["pressure"] = need - 1
	var small: String = gs.job_area_problem(big)
	gs.lab_areas["pressure"] = need
	var large: String = gs.job_area_problem(big)
	var size_name: String = gs.lab_area_size(need)
	_done(gs)
	if big.get("area", "") != "large" or need < 2:
		return "The cabin transducer job must need a large area, got '%s' (%d spaces)." % [big.get("area", ""), need]
	if none.find("Needs a LARGE pressure area") < 0 or none.find("in the large lab") < 0:
		return "With no pressure area, the job must say it needs a large one in the large lab, got '%s'." % none
	if small.find("Needs a LARGE pressure area") < 0:
		return "%d pressure spaces must be too small, got '%s'." % [need - 1, small]
	if large != "" or size_name != "large":
		return "%d pressure spaces must be a large area, got '%s' (%s)." % [need, large, size_name]
	return ""


func test_only_the_largest_lab_fits_a_large_area() -> String:
	var gs: GameStateScript = _make_state()
	var need: int = gs.lab_area_spaces_needed("large")
	var limits: Array[int] = []
	for i: int in gs.lab_sizes().size():
		gs.lab_size = i
		limits.append(gs.lab_max_area_spaces())
	# A medium lab with its areas cleared away still stops short of large.
	gs.lab_size = 1
	gs.lab_areas = { "angle": limits[1] }
	var capped: String = gs.lab_fit_problem("angle")
	var other: String = gs.lab_fit_problem("pressure")
	_done(gs)
	for i: int in limits.size():
		if (limits[i] >= need) != (i == limits.size() - 1):
			return "A large area must fit only in the largest lab; size %d holds %d spaces." % [i, limits[i]]
	if capped.find("grow the lab") < 0 or other != "":
		return "Clearing must not skip a lab size, got '%s' / '%s'." % [capped, other]
	return ""


func test_clearing_keeps_room_for_a_big_job_in_progress() -> String:
	var gs: GameStateScript = _make_state()
	gs.lab_size = gs.lab_sizes().size() - 1
	var big: Dictionary = _template(gs, "dome1_cabin_transducer")
	var gs_need: int = gs.lab_area_spaces_needed("large")
	gs.lab_areas["pressure"] = gs_need
	gs.active_jobs.append(big)
	var refit: Vector2i = gs._lab_refit_cost()
	gs.credits = refit.x
	gs.crystal_ore = refit.y
	var problem: String = gs.clear_lab_area("pressure")
	var kept: int = gs.lab_space("pressure")
	gs.active_jobs.clear()
	_done(gs)
	if problem.find("needs this area") < 0 or kept != gs_need:
		return "A large job in progress must keep its large area, got '%s', %d spaces." % [problem, kept]
	return ""


func test_growing_costs_credits_and_ore_and_takes_days() -> String:
	var gs: GameStateScript = _make_state()
	var next: Dictionary = gs.lab_next_size()
	var cost: int = int(next.get("credits", 0))
	var ore: int = int(next.get("ore", 0))
	var days: int = int(next.get("build_days", 0))
	gs.credits = cost + 5
	gs.crystal_ore = ore + 1
	var problem: String = gs.start_lab_grow()
	var credits_left: int = gs.credits
	var ore_left: int = gs.crystal_ore
	var done_day: int = int(gs.lab_build.get("done_day", 0))
	var again: String = gs.start_lab_grow()
	gs._finish_lab_build(done_day - 1)
	var early_size: int = gs.lab_size
	gs._finish_lab_build(done_day)
	var size: int = gs.lab_size
	var free_spaces: int = gs.lab_free_spaces()
	var spaces: int = gs.lab_spaces()
	var busy: bool = not gs.lab_build.is_empty()
	_done(gs)
	if problem != "" or credits_left != 5 or ore_left != 1:
		return "Growing must cost %d CR and %d ore, got '%s', left %d CR %d ore." % [cost, ore, problem, credits_left, ore_left]
	if cost <= 0 or ore <= 0 or days < 1 or done_day != 1 + days:
		return "Growing must cost credits and ore and take days, done day %d." % done_day
	if again.find("being built") < 0:
		return "Only one build at a time, got '%s'." % again
	if early_size != 0 or size != 1 or busy:
		return "The new size must be ready the morning of its done day, %d then %d." % [early_size, size]
	if free_spaces != spaces - 3:
		return "The new spaces must be free to fit out, %d of %d free." % [free_spaces, spaces]
	return ""


func test_growing_needs_credits_and_ore() -> String:
	var gs: GameStateScript = _make_state()
	var next: Dictionary = gs.lab_next_size()
	gs.credits = int(next.get("credits", 0))
	gs.crystal_ore = int(next.get("ore", 0)) - 1
	var short_ore: String = gs.start_lab_grow()
	gs.credits -= 1
	gs.crystal_ore += 1
	var short_credits: String = gs.start_lab_grow()
	var building: bool = not gs.lab_build.is_empty()
	_done(gs)
	if short_ore.find("Costs") < 0 or short_credits.find("Costs") < 0 or building:
		return "Growing must need both credits and ore, got '%s' and '%s'." % [short_ore, short_credits]
	return ""


func test_the_largest_lab_cannot_grow() -> String:
	var gs: GameStateScript = _make_state()
	gs.lab_size = gs.lab_sizes().size() - 1
	var problem: String = gs.lab_grow_problem()
	_done(gs)
	if problem.find("largest") < 0:
		return "The largest lab must not grow, got '%s'." % problem
	return ""


func test_fitting_out_uses_free_spaces() -> String:
	var gs: GameStateScript = _make_state()
	var none_free: String = gs.fit_lab_area("pressure")
	var grew: String = _grow(gs)
	var free_spaces: int = gs.lab_free_spaces()
	var fits: Array[String] = []
	for i: int in free_spaces:
		fits.append(gs.fit_lab_area("pressure" if i == 0 else "angle"))
	var over: String = gs.fit_lab_area("pressure")
	var unknown: String = gs.lab_fit_problem("astrology")
	var pressure: int = gs.lab_space("pressure")
	var angle: int = gs.lab_space("angle")
	_done(gs)
	if none_free.find("No free space") < 0 or grew != "":
		return "A full small lab has no space to fit out, got '%s' / '%s'." % [none_free, grew]
	if free_spaces < 2 or fits.count("") != free_spaces:
		return "Each free space must fit out, %d free: %s." % [free_spaces, fits]
	if pressure != 1 or angle != free_spaces:
		return "A free space can start a discipline or grow one, pressure %d angle %d." % [pressure, angle]
	if over.find("No free space") < 0 or unknown.find("No jobs") < 0:
		return "Fitting needs a free space and a job discipline, got '%s' / '%s'." % [over, unknown]
	return ""


func test_clearing_a_space_costs_and_has_downtime() -> String:
	var gs: GameStateScript = _make_state()
	var refit: Vector2i = gs._lab_refit_cost()
	gs.credits = refit.x
	gs.crystal_ore = refit.y
	gs.active_jobs.append(_template(gs, "relay_inclinometer"))
	var in_use: String = gs.clear_lab_area("angle")
	gs.active_jobs.clear()
	var problem: String = gs.clear_lab_area("angle")
	var paid: bool = gs.credits == 0 and gs.crystal_ore == 0
	var angle_gone: bool = gs.lab_space("angle") == 0
	var free_during: int = gs.lab_free_spaces()
	var done_day: int = int(gs.lab_build.get("done_day", 0))
	var refit_fit: String = gs.fit_lab_area("pressure")
	gs._finish_lab_build(done_day)
	var free_after: int = gs.lab_free_spaces()
	var fit_after: String = gs.fit_lab_area("pressure")
	_done(gs)
	if in_use.find("finish one first") < 0:
		return "A space in use must not be cleared, got '%s'." % in_use
	if problem != "" or not paid or not angle_gone:
		return "Clearing must cost %s, got '%s'." % [refit, problem]
	if free_during != 0 or refit_fit.find("No free space") < 0 or done_day < 2:
		return "A cleared space must be down until its done day, %d free." % free_during
	if free_after != 1 or fit_after != "":
		return "After the refit the space must be free to fit out, %d free, '%s'." % [free_after, fit_after]
	return ""


func test_the_morning_finishes_a_build_before_the_board() -> String:
	var gs: GameStateScript = _make_state()
	var next: Dictionary = gs.lab_next_size()
	gs.credits = int(next.get("credits", 0))
	gs.crystal_ore = int(next.get("ore", 0))
	gs.start_lab_grow()
	var done_day: int = int(gs.lab_build["done_day"])
	GameClock.elapsed_days = float(done_day - 1) - 1.0 / 1440.0
	GameClock.day_started.connect(gs._on_day_started)
	GameClock.advance(2.0 / 1440.0)
	GameClock.day_started.disconnect(gs._on_day_started)
	var size: int = gs.lab_size
	var said: bool = false
	for line: String in gs.phone_log:
		said = said or line.find("is ready") >= 0
	_done(gs)
	if size != 1 or not said:
		return "The morning of day %d must finish the build and say so, size %d." % [done_day, size]
	return ""
