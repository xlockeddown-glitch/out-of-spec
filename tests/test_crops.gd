extends RefCounted
## Income milestone (Ryan, 2026-11-22): crops auto-irrigated to a set point as
## the soil probe reads it, graded by whether the soil stayed in its moisture
## band, and sold to Lin. Prices and bands come from data/crops.json and
## data/economy.json ([PLACEHOLDER]); the tests read them.
## The tests do not move GameClock; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CELL: Vector3i = Vector3i(1, 0, 2)


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.credits = 1000
	gs.tilled_cells[CELL] = true
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 0.0
	return gs


func _grow(gs: GameStateScript, days: int) -> void:
	for i: int in days:
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
	gs.free()
	return problem


func test_seed_cycles_through_every_crop() -> String:
	var gs: GameStateScript = _make_state()
	var ids: Array[String] = gs.crop_ids()
	var seen: Dictionary = {}
	for i: int in ids.size():
		seen[gs.cycle_seed()] = true
	var back: String = gs.current_seed()
	gs.free()
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
	gs.free()
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
	gs.free()
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
	gs.free()
	if not ok or absf(moisture - target) > 0.0001:
		return "Raising the set point by the probe's error must put the soil on target, got %s." % moisture
	return ""


func test_soil_probe_is_an_audited_unit() -> String:
	var gs: GameStateScript = _make_state()
	var in_service: bool = gs.is_in_service(gs.SOIL_PROBE_ID)
	var listed: bool = gs.unit_ids().has(gs.SOIL_PROBE_ID)
	var text: String = gs.get_sensor(gs.SOIL_PROBE_ID).format_value(2.5)
	gs.free()
	if not in_service or not listed:
		return "The soil probe must be in service against the gravimetric kit from the start."
	if text != "+2.50 %":
		return "The probe's error must read like '+2.50 %%', got '%s'." % text
	return ""
