extends RefCounted
## Income milestone (Ryan, 2026-11-22): crops auto-irrigated to a set point as
## the soil probe reads it, graded by whether the soil stayed in its moisture
## band, and sold to Lin. Prices and bands come from data/crops.json and
## data/economy.json ([PLACEHOLDER]); the tests read them.
## Each test starts the clock at the first morning and puts it back after;
## every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CELL: Vector3i = Vector3i(1, 0, 2)


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.credits = 1000
	gs.tilled_cells[CELL] = true
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 0.0
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	return gs


## Puts the clock back and frees the state.
func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


## Runs `days` mornings: the clock moves to the next whole day, then crops grow.
func _grow(gs: GameStateScript, days: int) -> void:
	for i: int in days:
		GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
		gs._grow_crops()


func test_plant_needs_tilled_empty_cell_and_charges_seed() -> String:
	var gs: GameStateScript = _make_state()
	var seed: String = gs.current_seed()
	var cost: int = gs.seed_cost(seed)
	var problem: String = ""
	if gs.plant_crop(Vector3i(9, 0, 9)) == "":
		problem = "Planting on untilled soil must fail."
	elif gs.plant_crop(CELL) != "":
		problem = "Planting on tilled soil must work."
	elif gs.credits != 1000 - cost:
		problem = "The seed must cost %d CR, credits are %d." % [cost, gs.credits]
	elif gs.plant_crop(CELL) == "":
		problem = "Planting twice on one cell must fail."
	elif cost <= 0:
		problem = "Seeds should cost something."
	_done(gs)
	return problem


func test_seed_cycles_through_every_crop() -> String:
	var gs: GameStateScript = _make_state()
	var ids: Array[String] = gs.crop_ids()
	var seen: Dictionary = {}
	for i: int in ids.size():
		seen[gs.cycle_seed()] = true
	var back: String = gs.current_seed()
	_done(gs)
	if seen.size() != ids.size() or back != ids[0]:
		return "C must cycle through all %d crops and wrap, saw %d." % [ids.size(), seen.size()]
	return ""


func test_crop_ready_after_growth_days_and_sells_in_spec() -> String:
	var gs: GameStateScript = _make_state()
	var seed: String = gs.current_seed()
	var days: int = int(gs.crop(seed).get("growth_days", 1))
	gs.plant_crop(CELL)
	_grow(gs, days - 1)
	var early: bool = gs.is_crop_ready(CELL) or not gs.harvest_crop(CELL).is_empty()
	_grow(gs, 1)
	var entry: Dictionary = gs.harvest_crop(CELL)
	var before: int = gs.credits
	var paid: int = gs.sell_harvest_to_lin()
	var problem: String = ""
	if early:
		problem = "A crop must not be ready before its growth days."
	elif entry.is_empty() or not entry["in_spec"]:
		problem = "A crop grown with a true probe must harvest in spec, got %s." % entry
	elif paid != int(gs.crop(seed)["base_sell_credits"]) or gs.credits != before + paid:
		problem = "Lin must pay the base price in spec, paid %d." % paid
	elif not gs.harvest_bin.is_empty() or gs.plantings.has(CELL):
		problem = "Selling must empty the bin and harvesting must clear the cell."
	_done(gs)
	return problem


## A probe reading high makes irrigation hold the soil too dry: off spec once
## its error passes the crop's tolerance band.
func test_drifted_probe_makes_crop_off_spec() -> String:
	var gs: GameStateScript = _make_state()
	var seed: String = "lensberry"
	gs.seed_crop_id = seed
	var spec: Dictionary = gs.crop(seed)
	var band_pct: float = float(spec["tolerance_band"]) * 100.0
	gs.get_sensor(gs.SOIL_PROBE_ID).error = band_pct + 1.0
	gs.plant_crop(CELL)
	var in_band: bool = gs.is_soil_in_band(CELL)
	_grow(gs, int(spec["growth_days"]))
	var entry: Dictionary = gs.harvest_crop(CELL)
	var price: int = gs.crop_sale_price(entry)
	var expected: int = roundi(int(spec["base_sell_credits"]) * (1.0 - float(spec["out_of_spec_penalty_pct"]) / 100.0))
	_done(gs)
	if in_band:
		return "Soil must be out of band with the probe %s %% high." % (band_pct + 1.0)
	if entry.is_empty() or entry["in_spec"] or price != expected:
		return "A crop grown out of band must sell off spec at %d CR, got %s at %d." % [expected, entry, price]
	return ""


## Knowing the probe's error, the player can offset the set point to keep the
## soil on target.
func test_setpoint_offset_corrects_known_probe_error() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 8.0
	gs.plant_crop(CELL)
	gs.adjust_setpoint(CELL, 8)
	var ok: bool = gs.is_soil_in_band(CELL)
	var moisture: float = gs.soil_moisture(CELL)
	var target: float = float(gs.crop("lensberry")["soil_moisture_target"])
	_done(gs)
	if not ok or absf(moisture - target) > 0.0001:
		return "Raising the set point by the probe's error must put the soil on target, got %s." % moisture
	return ""


func test_soil_probe_is_an_audited_unit() -> String:
	var gs: GameStateScript = _make_state()
	var in_service: bool = gs.is_in_service(gs.SOIL_PROBE_ID)
	var listed: bool = gs.unit_ids().has(gs.SOIL_PROBE_ID)
	var text: String = gs.get_sensor(gs.SOIL_PROBE_ID).format_value(2.5)
	_done(gs)
	if not in_service or not listed:
		return "The soil probe must be in service against the gravimetric kit from the start."
	if text != "+2.50 %":
		return "The probe's error must read like '+2.50 %%', got '%s'." % text
	return ""


## GPT review 1: soil that leaves its band and comes back before morning
## still costs the crop its in-spec grade.
func test_excursion_between_mornings_makes_crop_off_spec() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	var spec: Dictionary = gs.crop("lensberry")
	var probe: DriftingSensor = gs.get_sensor(gs.SOIL_PROBE_ID)
	gs.plant_crop(CELL)
	probe.error = float(spec["tolerance_band"]) * 100.0 + 1.0
	gs._on_time_advanced(0.0)
	probe.error = 0.0
	var back_in_band: bool = gs.is_soil_in_band(CELL)
	_grow(gs, int(spec["growth_days"]))
	var entry: Dictionary = gs.harvest_crop(CELL)
	var paid: int = gs.sell_harvest_to_lin()
	var expected: int = roundi(int(spec["base_sell_credits"]) * (1.0 - float(spec["out_of_spec_penalty_pct"]) / 100.0))
	_done(gs)
	if not back_in_band:
		return "The probe set back to true must put the soil back in band."
	if entry.is_empty() or entry["in_spec"] or int(entry["out_of_band_days"]) != 1 or paid != expected:
		return "One afternoon out of band must cost the grade: expected %d CR and 1 day, got %s paying %d." % [expected, entry, paid]
	return ""


## GPT reviews 1-2: broke after fines, Lin fronts each seed and takes its cost
## out of that crop's sale.
func test_lin_fronts_a_seed_when_broke() -> String:
	var gs: GameStateScript = _make_state()
	gs.credits = -50
	var seed: String = gs.current_seed()
	var cost: int = gs.seed_cost(seed)
	var other: Vector3i = CELL + Vector3i(1, 0, 0)
	gs.tilled_cells[other] = true
	var first: String = gs.plant_crop(CELL)
	var second: String = gs.plant_crop(other)
	var credits_after_plant: int = gs.credits
	_grow(gs, int(gs.crop(seed)["growth_days"]))
	gs.harvest_crop(CELL)
	gs.harvest_crop(other)
	var paid: int = gs.sell_harvest_to_lin()
	var expected: int = 2 * (int(gs.crop(seed)["base_sell_credits"]) - cost)
	var credits_end: int = gs.credits
	_done(gs)
	if first != "":
		return "Lin must front the first seed when broke, got '%s'." % first
	if second != "":
		return "Lin must front every seed while broke, got '%s'." % second
	if credits_after_plant != -50:
		return "A fronted seed must not charge credits, credits are %d." % credits_after_plant
	if paid != expected or credits_end != -50 + expected:
		return "Lin must pay the base price less the fronted %d CR per crop (%d CR), paid %d." % [cost, expected, paid]
	return ""


## GPT review 1: a crop planted just before morning doesn't count that morning,
## so growth takes at least growth_days - 0.5 days.
func test_growth_counts_days_since_planting() -> String:
	var problem: String = ""
	for planted_at: float in [0.99, 0.01]:
		var gs: GameStateScript = _make_state()
		var days: int = int(gs.crop(gs.current_seed())["growth_days"])
		GameClock.elapsed_days = planted_at
		gs.plant_crop(CELL)
		_grow(gs, days)
		var ready_on_time: bool = gs.is_crop_ready(CELL)
		_grow(gs, 1)
		var ready_late: bool = gs.is_crop_ready(CELL)
		_done(gs)
		var late_planting: bool = planted_at > 0.5
		if late_planting and (ready_on_time or not ready_late):
			problem = "Planted just before morning, the crop must be ready one morning later."
		elif not late_planting and not ready_on_time:
			problem = "Planted just after morning, the crop must be ready after its growth days."
	return problem


## GPT review 1: soil exactly on a band edge is in band; just past it is not.
func test_band_edges_are_inclusive() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	var band_pct: float = float(gs.crop("lensberry")["tolerance_band"]) * 100.0
	gs.plant_crop(CELL)
	var probe: DriftingSensor = gs.get_sensor(gs.SOIL_PROBE_ID)
	var results: Array[bool] = []
	for error: float in [band_pct, -band_pct, band_pct + 0.01, -band_pct - 0.01]:
		probe.error = error
		results.append(gs.is_soil_in_band(CELL))
	_done(gs)
	if results != [true, true, false, false]:
		return "Edges at +/-%s %% must be in band and just past them out, got %s." % [band_pct, results]
	return ""


## GPT review 1: the seed chosen when Space was sent is what gets planted,
## even if C changed the selection while the command was in flight.
func test_plant_uses_the_seed_sent_with_the_command() -> String:
	var gs: GameStateScript = _make_state()
	var ids: Array[String] = gs.crop_ids()
	gs.seed_crop_id = ids[0]
	gs.plant_crop(CELL, ids[1])
	var planted: String = str(gs.plantings.get(CELL, {}).get("crop_id", ""))
	var credits: int = gs.credits
	var cost: int = gs.seed_cost(ids[1])
	_done(gs)
	if planted != ids[1] or credits != 1000 - cost:
		return "Planting must use and charge for the sent seed %s, planted '%s'." % [ids[1], planted]
	return ""


## GPT review 1: when credits change for a seed, the cell already shows the planting.
func test_planting_is_recorded_before_the_seed_charge() -> String:
	var gs: GameStateScript = _make_state()
	var seen: Array[bool] = []
	gs.credits_changed.connect(func(_credits: int) -> void: seen.append(gs.plantings.has(CELL)))
	gs.plant_crop(CELL)
	_done(gs)
	if seen != [true]:
		return "credits_changed must fire once, after the planting is recorded, saw %s." % [seen]
	return ""


## GPT review 2: a clock jump across 06:00 (a bench calibration) is split at
## the morning, so growth and drift are judged as at 06:00.
func test_clock_jump_across_morning_is_split() -> String:
	var gs: GameStateScript = _make_state()
	var mornings: Array[float] = []
	var steps: Array[float] = []
	var on_day: Callable = func(_day: int) -> void: mornings.append(GameClock.elapsed_days)
	var on_step: Callable = func(d: float) -> void: steps.append(d)
	GameClock.day_started.connect(on_day)
	GameClock.time_advanced.connect(on_step)
	GameClock.elapsed_days = 0.9
	GameClock.advance(0.3)
	GameClock.day_started.disconnect(on_day)
	GameClock.time_advanced.disconnect(on_step)
	var end: float = GameClock.elapsed_days
	_done(gs)
	if mornings.size() != 1 or absf(mornings[0] - 1.0) > 1e-9:
		return "day_started must fire once with the clock at 06:00, saw %s." % [mornings]
	if steps.size() != 2 or absf(steps[0] - 0.1) > 1e-9 or absf(end - 1.2) > 1e-9:
		return "The jump must split into 0.1 d before the morning and the rest after, saw %s ending at %s." % [steps, end]
	return ""


## GPT review 2: the crop wilts as soon as an excursion costs its grade, not
## the following morning.
func test_excursion_marks_crop_at_once() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	gs.plant_crop(CELL)
	var signals: Array[int] = [0]
	gs.crops_changed.connect(func() -> void: signals[0] += 1)
	gs.get_sensor(gs.SOIL_PROBE_ID).error = float(gs.crop("lensberry")["tolerance_band"]) * 100.0 + 1.0
	gs._on_time_advanced(0.0)
	var marked: bool = gs.plantings[CELL].get("out_today", false)
	_done(gs)
	if not marked or signals[0] != 1:
		return "An excursion must mark the crop and signal once, marked %s, signals %d." % [marked, signals[0]]
	return ""


## GPT review 3: knowing the probe's error, the player sets the starting set
## point before planting, so a drifted probe needn't spoil the crop at once.
func test_planting_offset_corrects_known_error_before_planting() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 6.0
	gs.adjust_planting_offset(6)
	var signals: Array[int] = [0]
	gs.crops_changed.connect(func() -> void: signals[0] += 1)
	gs.plant_crop(CELL)
	var out: bool = gs.plantings[CELL].get("out_today", true)
	var text: String = gs.planting_offset_text()
	_done(gs)
	if out:
		return "A +6 % starting offset must keep Lensberry in band with the probe 6 % high."
	if signals[0] != 1:
		return "Planting must signal crops_changed once, saw %d." % signals[0]
	if text != "New plantings start at their target moisture +6 %.":
		return "Offset text was '%s'." % text
	return ""


## GPT review 3: soil out of band at 06:00 counts against the new day too.
func test_out_at_dawn_counts_against_new_day() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	gs.plant_crop(CELL)
	gs.get_sensor(gs.SOIL_PROBE_ID).error = float(gs.crop("lensberry")["tolerance_band"]) * 100.0 + 1.0
	_grow(gs, 1)
	var carried: bool = gs.plantings[CELL].get("out_today", false)
	var days: int = int(gs.plantings[CELL]["out_of_band_days"])
	_done(gs)
	if days != 1 or not carried:
		return "Out at dawn must count the past day and mark the new one, got %d days, marked %s." % [days, carried]
	return ""


## GPT review 4: the offset sent with a planting command is the one used, even
## if [ or ] changes it while the command is in flight.
func test_plant_uses_the_offset_sent_with_the_command() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "lensberry"
	gs.adjust_planting_offset(4)
	var sent: int = gs.planting_offset_steps
	gs.adjust_planting_offset(-1)
	gs.plant_crop(CELL, "lensberry", sent)
	var setpoint: float = float(gs.plantings[CELL]["setpoint"])
	var expected: float = float(gs.crop("lensberry")["soil_moisture_target"]) + 4.0 * gs.SETPOINT_STEP
	_done(gs)
	if absf(setpoint - expected) > 1e-9:
		return "Set point must use the +4 offset sent with the command, got %s." % setpoint
	return ""


## Ryan (2026-11-22): "both". Clicking the soil probe reads out the plot:
## irrigation holds its reading at the set point, even with the probe drifted.
func test_soil_probe_reads_each_planting_at_its_set_point() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var empty: String = gs.soil_probe_text()
	if not empty.begins_with("Nothing planted"):
		problem = "With nothing planted the probe must say so, got '%s'." % empty
	gs.plant_crop(CELL)
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 1.3
	var setpoint: float = float(gs.plantings[CELL]["setpoint"]) * 100.0
	var reading: float = gs.soil_probe_reading(CELL)
	if problem == "" and not is_equal_approx(reading, snappedf(setpoint, 0.1)):
		problem = "The probe must read the set point %s %%, got %s %%." % [setpoint, reading]
	var text: String = gs.soil_probe_text()
	var want: String = "(%d, %d) %s %%" % [CELL.x, CELL.z, SP811.number(reading, 1)]
	if problem == "" and (want not in text or "due day" not in text):
		problem = "The readout must hold '%s' and the due day, got '%s'." % [want, text]
	_done(gs)
	return problem


## The readout lists the first cells, counts the rest, and flags an overdue probe.
func test_soil_probe_text_caps_cells_and_flags_overdue() -> String:
	var gs: GameStateScript = _make_state()
	gs.credits = 100000
	var problem: String = ""
	var count: int = gs.SOIL_PROBE_TEXT_CELLS + 2
	for x: int in count:
		var cell := Vector3i(x, 0, 5)
		gs.tilled_cells[cell] = true
		var refused: String = gs.plant_crop(cell)
		if problem == "" and refused != "":
			problem = "Could not plant %s for the test: %s" % [cell, refused]
	var probe: DriftingSensor = gs.get_sensor(gs.SOIL_PROBE_ID)
	probe.cal_due_day = GameClock.get_day_index() - 1
	var text: String = gs.soil_probe_text()
	var listed: int = text.get_slice(" more.", 0).count(" %,")
	if problem == "" and not text.begins_with("Reads "):
		problem = "The readout must start 'Reads ', got '%s'." % text
	if problem == "" and (listed != gs.SOIL_PROBE_TEXT_CELLS or ", 2 more." not in text):
		problem = "The readout must list %d cells then '2 more', got '%s'." % [gs.SOIL_PROBE_TEXT_CELLS, text]
	if problem == "" and not text.ends_with("CAL " + DriftingSensor.overdue_text(probe.cal_due_day) + "."):
		problem = "An overdue probe must say so, got '%s'." % text
	_done(gs)
	return problem


## Ryan (2026-11-22): "both". The readout flags the probe's drift and band, as
## the dome's displays do, since its soil readings sit on the set point.
func test_soil_probe_text_flags_drift_band() -> String:
	var gs: GameStateScript = _make_state()
	var probe: DriftingSensor = gs.get_sensor(gs.SOIL_PROBE_ID)
	var problem: String = ""
	for ratio: float in [0.5, 0.9, 1.5]:
		probe.error = probe.mpe * ratio
		var want: String = "Drift %s, %s." % [probe.format_value(probe.observed_error),
			DriftingSensor.band_label(probe.get_observed_band())]
		var text: String = gs.soil_probe_text()
		if problem == "" and want not in text:
			problem = "At %s × MPE the readout must hold '%s', got '%s'." % [ratio, want, text]
	if problem == "" and "OUT OF TOLERANCE" not in gs.soil_probe_text():
		problem = "Past MPE the readout must say OUT OF TOLERANCE."
	# A standard that was off at the last zero hides that much drift: the
	# readout shows the observed error, not the true one.
	probe.error = probe.mpe * 1.5
	probe.reference_offset = probe.mpe * 1.0
	if problem == "" and "Drift %s, IN TOLERANCE." % probe.format_value(probe.mpe * 0.5) not in gs.soil_probe_text():
		problem = "The drift line must show the observed error, got '%s'." % gs.soil_probe_text()
	_done(gs)
	return problem
