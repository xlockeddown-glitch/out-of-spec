extends RefCounted
## Milestone 3b: the Tier 2 standards (HM-3, TW-6), the OIRM account gate, and
## calibrating a standard on the bench against another one.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FM3: String = "field_meter_dc"
const HM3: String = "multi_source_calibrator"
const TW6: String = "torque_standard"
const THERMO: String = "terrarium_thermometer"


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 100000
	gs.crystal_ore = 100
	gs.tier1_unlocked = true
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = saved
	return problem


## The FM-3 from Bram and an HM-3 with an OIRM certificate.
func _give_both(gs: GameStateScript) -> void:
	gs.buy_standard(FM3)
	gs.owned_standards[HM3] = 7
	gs.oirm_calibrate(HM3, 7)


func test_tier2_needs_an_oirm_account() -> String:
	return _run(_check_gate)


func _check_gate(gs: GameStateScript) -> String:
	if TW6 in gs.bram_catalog() or not gs.standard_purchase_problem(TW6).contains("OIRM account"):
		return "The TW-6 must wait for an OIRM account."
	gs.send_to_oirm("rotary_table")
	if gs.has_oirm_account():
		return "A founding standard's trip must not open the account."
	gs.buy_standard(FM3)
	if gs.has_oirm_account():
		return "Buying alone must not open the account."
	gs.send_to_oirm(FM3)
	if not gs.has_oirm_account() or not TW6 in gs.bram_catalog():
		return "Sending a bought standard must open the account and Tier 2."
	gs.oirm_calibrate(FM3, 10)
	if not gs.has_oirm_account():
		return "The account must stay open after the standard is back."
	if HM3 in gs.bram_catalog() or gs.standard_purchase_problem(HM3) != "Bram doesn't stock that.":
		return "Bram must not sell the HM-3."
	var reason: String = gs.buy_standard(TW6)
	if reason != "" or not str(gs.certificates[TW6]["id"]).begins_with("TW-"):
		return "The TW-6 must be sold with its maker's certificate: " + reason
	if gs.calibrate(TW6).get("refused", false) != true:
		return "The bench has nothing to calibrate the TW-6 against."
	return ""


func test_bench_refuses_without_the_reference() -> String:
	return _run(_check_refusals)


func _check_refusals(gs: GameStateScript) -> String:
	if not gs.calibrate(FM3).get("refused", false):
		return "A standard not on the colony can't be calibrated."
	gs.buy_standard(FM3)
	if not gs.calibrate(FM3).get("refused", false) or gs.has_bench_reference(FM3):
		return "The FM-3 needs the HM-3 on the colony."
	_give_both(gs)
	gs.at_oirm[HM3] = 10
	if not gs.calibrate(FM3).get("refused", false):
		return "The FM-3 needs the HM-3 here, not at OIRM."
	gs.at_oirm = { FM3: 10 }
	if not gs.calibrate(FM3).get("refused", false):
		return "An FM-3 at OIRM can't be on the bench."
	return ""


func test_bench_calibration_issues_a_certificate() -> String:
	return _run(_check_certificate)


func _check_certificate(gs: GameStateScript) -> String:
	_give_both(gs)
	var fm3: DriftingSensor = gs.get_sensor(FM3)
	var budget: Dictionary = gs.calibration_budget(FM3)
	if budget["tur"] < 4.0:
		return "The HM-3 must be clearly better than the FM-3, TUR %s." % budget["tur"]
	gs.get_sensor(HM3).error = 0.00002
	fm3.error = fm3.mpe * 0.1 + 0.00002
	var interval: int = fm3.cal_interval_days
	gs.contract_state = "active"
	var run: int = gs.contract_run
	GameClock.elapsed_days = 6.0 + interval - 1.0  # on time, with service behind it
	var record: Dictionary = gs.calibrate(FM3)
	var cert: Dictionary = gs.certificates[FM3]
	if not record.get("traceable", false) or absf(record["as_found"] - fm3.mpe * 0.1) > 1e-9:
		return "The as-found is read against the HM-3: %s" % record
	if cert["id"] != record.get("certificate") or not str(cert["id"]).begins_with("IH-") \
			or cert["due_day"] != GameClock.get_day_index() + interval:
		return "An in-house certificate must be issued for one interval: %s" % cert
	if fm3.cal_interval_days != interval or gs.contract_run != run:
		return "A standard keeps its interval and is not part of the contract run."
	if absf(fm3.error - 0.00002) > 1e-9:
		return "The HM-3's error must carry into the FM-3."
	var chain: Dictionary = gs.traceability_chain(FM3)
	for part: String in [cert["id"], "HM-3", gs.certificates[HM3]["id"], "← OIRM"]:
		if not chain["traceable"] or not str(chain["text"]).contains(part):
			return "The chain must run through the HM-3: %s" % chain
	return ""


func test_overdue_reference_breaks_the_chain_below() -> String:
	return _run(_check_overdue)


func _check_overdue(gs: GameStateScript) -> String:
	_give_both(gs)
	gs.get_sensor(HM3).cal_due_day = 6
	var before: Dictionary = gs.certificates[FM3]
	var record: Dictionary = gs.calibrate(FM3)
	if record["traceable"] or not is_same(gs.certificates[FM3], before) or gs.traceability_chain(FM3)["traceable"]:
		return "Adjusting against an overdue HM-3 must not certify the FM-3."
	var below: Dictionary = gs.calibrate(THERMO)
	if below["traceable"] or below["standard_problem"] != "adjusted untraceably":
		return "Work with that FM-3 must not be traceable: %s" % below
	gs.oirm_calibrate(FM3, 7)
	if not gs.calibrate(THERMO)["traceable"] or not gs.traceability_chain(FM3)["traceable"]:
		return "OIRM's calibration must mend it."
	return ""


func test_failed_bench_calibration_recalls_work() -> String:
	return _run(_check_bench_recall)


func _check_bench_recall(gs: GameStateScript) -> String:
	_give_both(gs)
	var fm3: DriftingSensor = gs.get_sensor(FM3)
	fm3.error = fm3.mpe * 40.0
	var thermo: DriftingSensor = gs.get_sensor(THERMO)
	thermo.error = fm3.error * thermo.standard_sensitivity
	var made: Dictionary = gs.calibrate(THERMO)
	gs.calibrate(FM3)
	if not made["suspect"] or not gs.suspect_units.has(THERMO):
		return "An out-of-tolerance FM-3 must recall the thermometer."
	return ""


func test_recall_of_the_reference_reaches_standard_and_unit() -> String:
	return _run(_check_cascade)


func _check_cascade(gs: GameStateScript) -> String:
	_give_both(gs)
	var fm3: DriftingSensor = gs.get_sensor(FM3)
	var thermo: DriftingSensor = gs.get_sensor(THERMO)
	var before: Dictionary = gs.calibrate(THERMO)
	gs.get_sensor(HM3).error = fm3.mpe * 40.0
	fm3.error = fm3.mpe * 40.0
	var middle: Dictionary = gs.calibrate(FM3)
	thermo.error = fm3.error * thermo.standard_sensitivity
	var after: Dictionary = gs.calibrate(THERMO)
	gs.oirm_calibrate(HM3, 7)
	if not middle["suspect"] or not after["suspect"]:
		return "The recall must reach the FM-3 and the thermometer."
	if before["suspect"]:
		return "Work done before that FM-3 certificate must not be recalled."
	if not gs.suspect_units.has(FM3) or gs.traceability_chain(FM3)["traceable"] or gs.calibrate(THERMO)["traceable"]:
		return "A suspect FM-3 can't give traceable calibrations."
	gs.calibrate(FM3)
	if gs.suspect_units.has(FM3) or not gs.calibrate(THERMO)["traceable"]:
		return "Calibrating the FM-3 again must clear it."
	return ""


func test_old_save_picks_up_the_fm3_reference() -> String:
	return _run(_check_old_save)


func _check_old_save(gs: GameStateScript) -> String:
	var sensor: DriftingSensor = gs.get_sensor(FM3)
	var data: Dictionary = sensor.to_dict()
	data["calibrated_by"] = ""
	sensor.apply_dict(data)
	return "" if sensor.calibrated_by == HM3 else "An old save must not lose the FM-3's reference."
