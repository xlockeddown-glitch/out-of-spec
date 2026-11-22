extends RefCounted
## Milestone 3a: the five new sensors and the two Tier 1 standards Bram sells
## (FM-3 field meter, WD-1 reference gauge). Ownership filters, the purchase
## gate and maker certificate, standard_sensitivity through the budget, the
## calibration and recall, and the new display formats.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FM3: String = "field_meter_dc"
const WD1: String = "reference_gauge"
const THERMO: String = "terrarium_thermometer"
const NEW_UNITS: Array[String] = ["rover_tire_pressure", "dome_pressure", THERMO, "relay_timebase"]


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 10000
	gs.crystal_ore = 10
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	return gs


func _set_day(day: int) -> void:
	GameClock.elapsed_days = float(day - 1)


func test_tier1_starts_off_the_colony() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	for id: String in [FM3, WD1]:
		if gs.standard_ids().has(id) or not gs.all_standard_ids().has(id) or gs.is_in_service(id):
			problem = "%s must exist but not be owned at the start." % id
		elif gs.certificates.has(id):
			problem = "%s must have no certificate before it is bought." % id
	for id: String in NEW_UNITS:
		if problem == "" and (gs.unit_ids().has(id) or not gs.all_unit_ids().has(id)):
			problem = "%s must exist but not be in service at the start." % id
	if problem == "" and not gs.calibrate(THERMO).get("refused", false):
		problem = "The bench must refuse a unit whose standard is not on the colony."
	gs.free()
	return problem


func test_buy_standard_gate_cost_and_certificate() -> String:
	var saved: float = GameClock.elapsed_days
	_set_day(7)
	var gs: GameStateScript = _make_state()
	var fm: DriftingSensor = gs.get_sensor(FM3)
	var problem: String = ""
	if gs.buy_standard(FM3) == "":
		problem = "Bram must not sell Tier 1 before a clean audit."
	gs.tier1_unlocked = true
	gs.credits = fm.price_credits - 1
	if problem == "" and gs.buy_standard(FM3) == "":
		problem = "Bram must not sell without enough credits."
	gs.credits = 1000
	gs.crystal_ore = fm.price_ore - 1
	if problem == "" and gs.buy_standard(FM3) == "":
		problem = "Bram must not sell without enough crystal ore."
	gs.crystal_ore = fm.price_ore
	var reason: String = gs.buy_standard(FM3) if problem == "" else ""
	var cert: Dictionary = gs.certificates.get(FM3, {})
	if problem == "" and reason != "":
		problem = "The purchase must succeed, got: %s" % reason
	elif problem == "" and (gs.credits != 1000 - fm.price_credits or gs.crystal_ore != 0):
		problem = "Price not charged: %d CR, %d ore left." % [gs.credits, gs.crystal_ore]
	elif problem == "" and not str(cert.get("id", "")).begins_with("AF-"):
		problem = "Certificate must carry the maker's prefix, got %s." % cert
	elif problem == "" and (cert["issuer"] != "Arsia Fieldworks" or cert["founding"] or cert["as_found"] != null):
		problem = "Maker certificate fields wrong: %s" % cert
	elif problem == "" and (fm.cal_due_day != 7 + fm.initial_interval_days or cert["due_day"] != fm.cal_due_day):
		problem = "FM-3 must be due one interval after purchase, got day %d." % fm.cal_due_day
	elif problem == "" and (not gs.standard_ids().has(FM3) or not gs.unit_ids().has(THERMO)):
		problem = "Buying the FM-3 must put it and the thermometer in service."
	elif problem == "" and gs.get_sensor(THERMO).cal_due_day != 7 + gs.get_sensor(THERMO).cal_interval_days:
		problem = "The thermometer must fall due one interval after the FM-3 arrives."
	elif problem == "" and gs.buy_standard(FM3) == "":
		problem = "The same standard can't be bought twice."
	elif problem == "" and gs.unit_ids().has("relay_timebase"):
		problem = "The relay timebase has no standard until M3b."
	var chain: Dictionary = gs.traceability_chain(FM3)
	if problem == "" and (not chain["traceable"] or not str(chain["text"]).contains("Arsia Fieldworks")):
		problem = "FM-3 must trace through its maker to OIRM: %s" % chain
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_out_of_service_units_do_not_drift() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	gs._on_time_advanced(10.0)
	for id: String in NEW_UNITS + [FM3, WD1]:
		if gs.get_sensor(id).error != 0.0:
			problem = "%s drifted while off the colony or out of service." % id
	if problem == "" and gs.steering.error == 0.0:
		problem = "Instruments in service must still drift."
	gs.add_tire_usage(1000.0)
	if problem == "" and gs.get_sensor("rover_tire_pressure").error != 0.0:
		problem = "The tire gauge must not wear before the WD-1 arrives."
	gs.tier1_unlocked = true
	gs.buy_standard(WD1)
	gs.add_tire_usage(1000.0)
	if problem == "" and gs.get_sensor("rover_tire_pressure").error == 0.0:
		problem = "The tire gauge must wear with distance once in service."
	var dome: DriftingSensor = gs.get_sensor("dome_pressure")
	dome.error = 0.0
	gs._on_time_advanced(1.0)
	if problem == "" and absf(absf(dome.error) - dome.daily_drift_rate) > 1.0e-9:
		problem = "The dome gauge must drift once the WD-1 is on the colony, got %s." % dome.error
	if problem == "" and gs.get_sensor("relay_timebase").error != 0.0:
		problem = "The relay timebase stays out of service until M3b."
	gs.free()
	return problem


func test_budget_applies_standard_sensitivity() -> String:
	var gs: GameStateScript = _make_state()
	var unit: DriftingSensor = gs.get_sensor(THERMO)
	var fm: DriftingSensor = gs.get_sensor(FM3)
	var budget: Dictionary = CalUncertainty.budget(unit, fm)
	var expected_spec: float = fm.mpe / sqrt(3.0) * unit.standard_sensitivity
	var problem: String = ""
	if absf(budget["u_spec"] - expected_spec) > 1.0e-9:
		problem = "u_spec must be in degrees Celsius: %s, expected %s." % [budget["u_spec"], expected_spec]
	elif absf(budget["tur"] - 4.803) > 0.01:
		problem = "Thermometer against FM-3 should be 4.80:1, got %s." % budget["tur"]
	var dome: Dictionary = CalUncertainty.budget(gs.get_sensor("dome_pressure"), gs.get_sensor(WD1))
	if problem == "" and (dome["refused"] or dome["clean"] or absf(dome["tur"] - 3.109) > 0.01):
		problem = "Dome against WD-1 must be 3.11:1, under 4:1 on purpose, got %s." % dome["tur"]
	var tire: Dictionary = CalUncertainty.budget(gs.get_sensor("rover_tire_pressure"), gs.get_sensor(WD1))
	if problem == "" and absf(tire["tur"] - 8.242) > 0.01:
		problem = "Tire gauge against WD-1 should be 8.24:1, got %s." % tire["tur"]
	gs.free()
	return problem


func test_calibration_and_recall_carry_sensitivity() -> String:
	var saved: float = GameClock.elapsed_days
	_set_day(3)
	var gs: GameStateScript = _make_state()
	gs.tier1_unlocked = true
	gs.buy_standard(FM3)
	var unit: DriftingSensor = gs.get_sensor(THERMO)
	var fm: DriftingSensor = gs.get_sensor(FM3)
	var problem: String = ""
	fm.error = 0.01
	unit.error = 0.3
	var record: Dictionary = gs.calibrate(THERMO)
	if record.get("refused", false) or absf(record["as_found"] - (0.3 - 0.01 * unit.standard_sensitivity)) > 1.0e-6:
		problem = "As-found must subtract the FM-3 error times 5: %s" % record
	elif not record["traceable"]:
		problem = "A calibration against a new FM-3 must be traceable."
	# A clean zero, then the FM-3 turns out to have been 0.099 V off: 0.495 °C, past the
	# 0.489 °C acceptance limit but inside the 0.5 °C MPE.
	fm.error = 0.0
	unit.error = 0.0
	gs.calibrate(THERMO)
	var flagged: Array[Dictionary] = gs.recall(FM3, 0.099, 3)
	var hit: bool = false
	for r: Dictionary in flagged:
		if r["instrument_id"] == THERMO and r["as_found"] == 0.0:
			hit = r["suspect_result"] == CalUncertainty.INDETERMINATE
	if problem == "" and not hit:
		problem = "Recall must re-judge 0.099 V as 0.495 °C (indeterminate): %s" % [flagged]
	# The sign matters: as-found +0.3 °C with the FM-3 at −0.06 V corrects to
	# 0.0 °C (still a pass); at +0.06 V it corrects to +0.6 °C (a fail).
	_set_day(4)
	fm.error = 0.0
	unit.error = 0.3
	gs.calibrate(THERMO)
	var low: Array[Dictionary] = gs.recall(FM3, -0.06, 4)
	if problem == "" and not low.is_empty():
		problem = "A standard error that cancels the as-found must not flag: %s" % [low]
	var high: Array[Dictionary] = gs.recall(FM3, 0.06, 4)
	if problem == "" and (high.size() != 1 or high[0]["suspect_result"] != CalUncertainty.FAIL):
		problem = "+0.06 V must turn +0.3 °C into a fail: %s" % [high]
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_new_display_formats() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var cases: Dictionary = {
		THERMO: [" °C", "temperature"],
		"relay_timebase": [" × 10⁻⁶", "fractional frequency"],
		"dome_pressure": [" kPa", "pressure"],
		FM3: [" V", "DC voltage"],
	}
	for id: String in cases:
		var sensor: DriftingSensor = gs.get_sensor(id)
		var text: String = sensor.format_value(0.1234)
		if not text.ends_with(cases[id][0]):
			problem = "%s format_value gave '%s', expected it to end with '%s'." % [id, text, cases[id][0]]
		elif sensor.quantity_name() != cases[id][1]:
			problem = "%s quantity is '%s'." % [id, sensor.quantity_name()]
	if problem == "" and gs.get_sensor(FM3).quantity_title() != "DC Voltage":
		problem = "Acronyms must survive the title: '%s'." % gs.get_sensor(FM3).quantity_title()
	if problem == "" and gs.get_sensor("dome_pressure").format_value(0.1) != "+0.10 kPa":
		problem = "Dome readings need two decimals: %s" % gs.get_sensor("dome_pressure").format_value(0.1)
	if problem == "" and gs.get_sensor("rover_tire_pressure").format_value(0.4) != "+0.4 kPa":
		problem = "Tire readings need one decimal: %s" % gs.get_sensor("rover_tire_pressure").format_value(0.4)
	if problem == "" and gs.get_sensor("rover_tire_pressure").format_value(0.4, 3) != "+0.400 kPa":
		problem = "A caller asking for more digits must get them: %s" % gs.get_sensor("rover_tire_pressure").format_value(0.4, 3)
	gs.free()
	return problem


## Ryan, 2026-11-22: Tier 1 standards reach their MPE in about 120 days,
## between Tier 0's 60-day game pace and the real one-to-two-year rates.
func test_tier1_drift_reaches_mpe_in_about_120_days() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	for id: String in [FM3, WD1]:
		var sensor: DriftingSensor = gs.get_sensor(id)
		var days: float = sensor.mpe / sensor.daily_drift_rate
		if days < 110.0 or days > 130.0:
			problem = "%s reaches its MPE in %.1f days, want about 120." % [id, days]
	gs.free()
	return problem
