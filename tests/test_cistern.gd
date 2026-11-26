extends RefCounted
## The farm's water cistern: it runs down as growing plots are irrigated and
## refills at each morning. A dry day grows no crops.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state(plots: int = 4) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.credits = 100000
	for i: int in plots:
		var cell := Vector3i(i, 0, 0)
		gs.till(cell)
		gs.plant_crop(cell)
	return gs


func _ripen(gs: GameStateScript, cell: Vector3i) -> void:
	gs.plantings[cell]["days_grown"] = 1000


func test_a_new_farm_has_a_full_cistern() -> String:
	var gs: GameStateScript = GameStateScript.new()
	var level: float = gs.cistern_liters
	gs.free()
	return "" if level == GameStateScript.CISTERN_CAPACITY_L else "A new cistern must be full."


func test_growing_plots_draw_by_the_hour() -> String:
	var gs: GameStateScript = _make_state(4)
	gs._draw_cistern(1.0 / 24.0)
	var drawn: float = GameStateScript.CISTERN_CAPACITY_L - gs.cistern_liters
	var want: float = 4.0 * GameStateScript.CISTERN_DRAW_L_PER_PLOT_HOUR
	gs.free()
	return "" if is_equal_approx(drawn, want) else "4 plots for an hour must draw %s L, got %s." % [want, drawn]


func test_the_draw_does_not_depend_on_the_step() -> String:
	var one: GameStateScript = _make_state(6)
	var many: GameStateScript = _make_state(6)
	one._on_time_advanced(0.4)
	for i: int in 2000:
		many._on_time_advanced(0.4 / 2000.0)
	var problem: String = ""
	if absf(one.cistern_liters - many.cistern_liters) > 0.001:
		problem = "One step gave %s L, many gave %s L." % [one.cistern_liters, many.cistern_liters]
	if problem == "" and one.cistern_liters >= GameStateScript.CISTERN_CAPACITY_L:
		problem = "Time passing must draw water."
	one.free()
	many.free()
	return problem


func test_only_growing_plots_draw() -> String:
	var gs: GameStateScript = _make_state(4)
	_ripen(gs, Vector3i(0, 0, 0))
	_ripen(gs, Vector3i(1, 0, 0))
	gs._draw_cistern(1.0 / 24.0)
	var drawn: float = GameStateScript.CISTERN_CAPACITY_L - gs.cistern_liters
	var problem: String = ""
	if gs.growing_plots() != 2 or not is_equal_approx(drawn, 2.0 * GameStateScript.CISTERN_DRAW_L_PER_PLOT_HOUR):
		problem = "Ripe crops must not draw: %d growing, %s L." % [gs.growing_plots(), drawn]
	gs.free()
	return problem


func test_an_empty_farm_draws_nothing() -> String:
	var gs: GameStateScript = _make_state(0)
	gs._draw_cistern(5.0)
	var level: float = gs.cistern_liters
	gs.free()
	return "" if level == GameStateScript.CISTERN_CAPACITY_L else "No plots, no draw."


func test_it_never_goes_below_empty() -> String:
	var gs: GameStateScript = _make_state(20)
	gs.cistern_liters = 1.0
	gs._draw_cistern(3.0)
	var level: float = gs.cistern_liters
	gs.free()
	return "" if level == 0.0 else "The level must stop at 0, got %s." % level


func test_a_normal_farm_does_not_empty_it_and_a_full_plot_nearly_does() -> String:
	var per_day: float = GameStateScript.CISTERN_DRAW_L_PER_PLOT_HOUR * GameClock.HOURS_PER_DAY
	var capacity: float = GameStateScript.CISTERN_CAPACITY_L
	if 36.0 * per_day > capacity * 0.5:
		return "A normal farm (36 plots) should use well under the tank in a day."
	if 144.0 * per_day >= capacity or 144.0 * per_day < capacity * 0.8:
		return "A full plot (144 plants) should nearly, not quite, empty it in a day."
	return ""


func test_the_morning_refills_once_per_day_through_the_clock() -> String:
	var held: Dictionary = SaveGame.snapshot()
	GameClock.elapsed_days = 1.5
	GameState.credits = 100000
	for i: int in 6:
		GameState.till(Vector3i(i, 0, 5))
		GameState.plant_crop(Vector3i(i, 0, 5))
	GameState.cistern_liters = 100.0
	var problem: String = ""
	# Short of the morning it only runs down.
	GameClock.advance(0.25)
	if GameState.cistern_liters >= 100.0:
		problem = "Before the morning the cistern must keep running down."
	# Across two mornings, then 0.1 day into the third: refilled, then 0.1 day of draw.
	GameClock.advance(0.25 + 1.0 + 0.1)
	var want: float = GameStateScript.CISTERN_CAPACITY_L - 6.0 * GameStateScript.CISTERN_DRAW_L_PER_PLOT_HOUR * 24.0 * 0.1
	if problem == "" and absf(GameState.cistern_liters - want) > 0.01:
		problem = "After the morning it must have refilled once and run to %s L, got %s." % [want, GameState.cistern_liters]
	GameClock.skip_to_next_morning()
	if problem == "" and GameState.cistern_liters != GameStateScript.CISTERN_CAPACITY_L:
		problem = "Skipping to the morning must leave it full."
	var back: String = SaveGame.restore(held)
	return problem if problem != "" else back


func test_time_past_the_morning_refills_it_even_for_a_short_step() -> String:
	var held: Dictionary = SaveGame.snapshot()
	GameClock.elapsed_days = 1.99
	GameState.cistern_liters = 50.0
	GameClock.advance(0.05)
	var problem: String = ""
	if GameState.cistern_liters < GameStateScript.CISTERN_CAPACITY_L - 1.0:
		problem = "A morning reached by advancing the clock must refill it."
	var back: String = SaveGame.restore(held)
	return problem if problem != "" else back


func test_the_level_is_saved_and_an_old_save_loads_full() -> String:
	var gs: GameStateScript = _make_state(0)
	gs.cistern_liters = 123.5
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var other: GameStateScript = _make_state(0)
	var problem: String = other.farm_from_dict(data)
	if problem == "" and other.cistern_liters != 123.5:
		problem = "The level must come back from the save."
	data.erase("cistern_liters")
	if problem == "":
		problem = other.farm_from_dict(data)
	if problem == "" and other.cistern_liters != GameStateScript.CISTERN_CAPACITY_L:
		problem = "A save without the level must load full."
	gs.free()
	other.free()
	return problem


func test_a_bad_level_is_refused() -> String:
	var gs: GameStateScript = _make_state(0)
	var good: Dictionary = gs.farm_to_dict()
	var problem: String = ""
	for bad: Variant in [-1.0, GameStateScript.CISTERN_CAPACITY_L + 1.0, NAN, INF, "full", null, [1.0]]:
		var data: Dictionary = good.duplicate(true)
		data["cistern_liters"] = bad
		if gs.farm_from_dict(data) == "":
			problem = "A level of %s must be refused." % str(bad)
	gs.free()
	return problem


func test_a_new_farm_is_full() -> String:
	var held: Dictionary = SaveGame.snapshot()
	GameState.cistern_liters = 7.0
	GameState.new_farm()
	var level: float = GameState.cistern_liters
	var back: String = SaveGame.restore(held)
	if level != GameStateScript.CISTERN_CAPACITY_L:
		return "A new farm must start with a full cistern."
	return back


func test_a_guest_gets_the_hosts_level_in_plain_data() -> String:
	var host: GameStateScript = _make_state(3)
	var guest: GameStateScript = _make_state(0)
	host.cistern_liters = 222.0
	var bytes: PackedByteArray = FarmSync.capture(host)
	var held: bool = FarmCommands.guest
	var elapsed: float = GameClock.elapsed_days
	var open: bool = SaveGame.farm_open
	FarmCommands.guest = true
	var problem: String = FarmSync.update(bytes, guest)
	FarmCommands.guest = held
	GameClock.elapsed_days = elapsed
	SaveGame.farm_open = open
	if problem == "" and guest.cistern_liters != 222.0:
		problem = "The guest must see the host's level."
	if problem == "" and not CoopSession.is_plain([host.farm_to_dict()["cistern_liters"], guest.cistern_text()]):
		problem = "The level and its text must be plain data."
	host.free()
	guest.free()
	return problem


func test_an_empty_cistern_changes_nothing_until_the_morning() -> String:
	var full: GameStateScript = _make_state(5)
	var dry: GameStateScript = _make_state(5)
	for gs: GameStateScript in [full, dry]:
		gs._on_time_advanced(0.3)
		if gs == dry:
			gs.cistern_liters = 0.0
		gs._on_time_advanced(0.6)
	var problem: String = ""
	if dry.cistern_liters != 0.0 or full.cistern_liters <= 0.0:
		problem = "The test needs one empty and one not."
	for key: String in ["plantings", "credits", "tilled_cells"]:
		if problem == "" and var_to_bytes(full.get(key)) != var_to_bytes(dry.get(key)):
			problem = "An empty cistern must leave '%s' alone." % key
	for cell: Vector3i in full.plantings:
		if problem == "" and full.soil_moisture(cell) != dry.soil_moisture(cell):
			problem = "An empty cistern must leave soil moisture alone."
	full.free()
	dry.free()
	return problem


func test_the_text() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.cistern_liters = 420.0
	var problem: String = ""
	if gs.cistern_text() != "Cistern: 420 L of 600 L.":
		problem = "Got '%s'." % gs.cistern_text()
	gs.cistern_liters = 0.3
	if problem == "" and gs.cistern_text() != "Cistern: 1 L of 600 L.":
		problem = "A little got '%s'." % gs.cistern_text()
	gs.cistern_liters = 0.0
	if problem == "" and gs.cistern_text() != "Cistern: 0 L of 600 L. Empty. " + GameStateScript.CISTERN_DRY_HINT:
		problem = "Empty got '%s'." % gs.cistern_text()
	gs.free()
	return problem


func test_the_gauge_shows_empty_only_when_empty() -> String:
	var cap: float = GameStateScript.CISTERN_CAPACITY_L
	if CisternGauge.steps_for(0.0, cap) != 0:
		return "Empty must show no water."
	if CisternGauge.steps_for(0.01, cap) != 1:
		return "A little water must show a little."
	if CisternGauge.steps_for(cap, cap) != CisternGauge.STEPS:
		return "Full must fill the glass."
	if CisternGauge.steps_for(cap * 0.5, cap) != roundi(CisternGauge.STEPS * 0.5):
		return "Half must be half."
	return ""


func test_the_farm_scene_has_the_gauge_on_the_cistern() -> String:
	var scene: PackedScene = load("res://scenes/main_farm.tscn")
	var root: Node = scene.instantiate()
	var gauge: Node = root.find_child("Gauge", true, false)
	var ok: bool = gauge is CisternGauge and gauge.get_parent().name == "WaterCisternModel"
	root.free()
	return "" if ok else "The cistern needs its gauge in the farm scene."


func _days_grown(gs: GameStateScript) -> int:
	return int(gs.plantings[Vector3i(0, 0, 0)]["days_grown"])


func test_an_empty_cistern_pauses_growth_and_refilling_resumes_it() -> String:
	var gs: GameStateScript = _make_state(2)
	var problem: String = ""
	GameClock.elapsed_days = 3.0
	gs._on_day_started(4)
	var before: int = _days_grown(gs)
	if before != 1:
		problem = "A watered morning must grow a day, got %d." % before
	# It ran dry during day 4: the morning of day 5 grows nothing, then refills.
	gs.cistern_liters = 0.0
	GameClock.elapsed_days = 4.0
	gs._on_day_started(5)
	if problem == "" and (_days_grown(gs) != before or gs.cistern_liters != GameStateScript.CISTERN_CAPACITY_L):
		problem = "A dry day must not grow crops, and the morning must still refill: %d" % _days_grown(gs)
	# Refilled, so the next morning grows again; nothing was lost.
	GameClock.elapsed_days = 5.0
	gs._on_day_started(6)
	if problem == "" and _days_grown(gs) != before + 1:
		problem = "Growth must resume after the refill, got %d." % _days_grown(gs)
	gs.free()
	return problem


func test_the_dry_day_costs_nothing_else() -> String:
	var gs: GameStateScript = _make_state(1)
	gs.plantings[Vector3i(0, 0, 0)]["days_grown"] = 2
	gs.cistern_liters = 0.0
	GameClock.elapsed_days = 9.0
	gs._on_day_started(10)
	var planting: Dictionary = gs.plantings[Vector3i(0, 0, 0)]
	var problem: String = "" if gs.plantings.has(Vector3i(0, 0, 0)) and int(planting["days_grown"]) == 2 else "The crop must keep its growth."
	gs.free()
	return problem


func test_the_player_is_told_why_nothing_grows() -> String:
	var gs: GameStateScript = _make_state(1)
	var full: String = gs.crop_status_text(Vector3i(0, 0, 0))
	gs.cistern_liters = 0.0
	var dry: String = gs.crop_status_text(Vector3i(0, 0, 0))
	_ripen(gs, Vector3i(0, 0, 0))
	var ripe: String = gs.crop_status_text(Vector3i(0, 0, 0))
	var problem: String = ""
	if "not growing" in full or not "not growing: the cistern is empty" in dry:
		problem = "A growing crop must say the cistern is why it waits: '%s' / '%s'" % [full, dry]
	if problem == "" and "not growing" in ripe:
		problem = "A ripe crop is not waiting for water."
	gs.free()
	return problem


func test_a_full_plot_for_a_day_does_not_empty_it_on_current_numbers() -> String:
	var gs: GameStateScript = _make_state(0)
	gs.credits = 1000000
	for i: int in 144:
		var cell := Vector3i(i % 12 - 6, 0, int(floorf(i / 12.0)) - 6)
		gs.till(cell)
		gs.plant_crop(cell)
	var growing: int = gs.growing_plots()
	if growing != 144:
		gs.free()
		return "All 144 plots must be growing, got %d." % growing
	for hour: int in 24:
		gs._draw_cistern(1.0 / 24.0)
	var level: float = gs.cistern_liters
	gs.free()
	return "" if level > 0.0 else "With the current numbers a full plot must not empty it in a day (revisit the pause if they change)."
