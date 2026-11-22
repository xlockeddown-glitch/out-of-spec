extends RefCounted
## Milestone 2: OIRM certificates, the drop-pod courier, traceability chains,
## recall with impact threshold and cascade, and the Tier 1 clean-audit gate.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const DRIFT: StringName = &"sensor_drift_config"


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.credits = 10000
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	return gs


func _set_day(day: int) -> void:
	GameClock.elapsed_days = float(day - 1)


func _cadence() -> int:
	return int(DataManager.get_number(DRIFT, "audit_schedule/cadence_days", 5.0))


## Zeroes every instrument so an audit has nothing to find.
func _all_in_band(gs: GameStateScript) -> void:
	for id: String in gs.sensors:
		var sensor: DriftingSensor = gs.get_sensor(id)
		sensor.error = 0.0
		sensor.reference_offset = 0.0


func test_standards_start_with_founding_certificates() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	for id: String in gs.standard_ids():
		var cert: Dictionary = gs.certificates.get(id, {})
		if cert.is_empty() or not cert["founding"] or cert["day"] != 0:
			problem = "%s needs a day-0 founding certificate, got %s." % [id, cert]
		elif cert["due_day"] != gs.get_sensor(id).cal_due_day:
			problem = "%s certificate due day %s must match the sensor's %s." % [id, cert["due_day"], gs.get_sensor(id).cal_due_day]
	if problem == "" and gs.certificate_log.size() != gs.standard_ids().size():
		problem = "One founding certificate per standard, got %d." % gs.certificate_log.size()
	gs.free()
	return problem


func test_oirm_courier_round_trip() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var table: DriftingSensor = gs.get_sensor(gs.steering.calibrated_by)
	var cadence: int = _cadence()
	var problem: String = ""
	_set_day(cadence - 1)
	if gs.send_to_oirm(table.instrument_id)["ok"]:
		problem = "Sending must need the drop pod on the pad."
	_set_day(cadence)
	_all_in_band(gs)
	gs._run_audit(cadence)
	var credits_before: int = gs.credits
	var sent: Dictionary = gs.send_to_oirm(table.instrument_id)
	if problem == "" and not sent["ok"]:
		problem = "Send with the pod present must work: %s" % sent["reason"]
	elif problem == "" and gs.credits != credits_before - gs.oirm_fee():
		problem = "The OIRM fee must be charged."
	elif problem == "" and sent["return_day"] != cadence * 2:
		problem = "The standard must return on the next audit day, got %s." % sent["return_day"]
	elif problem == "" and gs.send_to_oirm(table.instrument_id)["ok"]:
		problem = "A standard already at OIRM can't be sent twice."
	elif problem == "" and not gs.calibrate(gs.STEERING_ID).get("refused", false):
		problem = "The bench must refuse while its standard is at OIRM."
	table.error = table.mpe * 0.5
	_set_day(cadence * 2)
	gs._run_audit(cadence * 2)
	var cert: Dictionary = gs.certificates[table.instrument_id]
	if problem == "" and gs.at_oirm.has(table.instrument_id):
		problem = "The standard must be back after the next audit."
	elif problem == "" and (cert["founding"] or cert["day"] != cadence * 2):
		problem = "A new OIRM certificate must be issued on return: %s" % cert
	elif problem == "" and absf(cert["as_found"] - table.mpe * 0.5) > 1.0e-6:
		problem = "The certificate must record the true as-found, got %s." % cert["as_found"]
	elif problem == "" and table.cal_due_day != cadence * 2 + table.cal_interval_days:
		problem = "The return must restart the standard's interval."
	elif problem == "" and not gs.suspect_units.is_empty():
		problem = "An in-tolerance as-found must not recall anything."
	GameClock.elapsed_days = saved
	gs.free()
	return problem


func test_audit_checks_standards_except_at_oirm() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = _cadence()
	var problem: String = ""
	_set_day(cadence)
	_all_in_band(gs)
	gs._run_audit(cadence)
	var away: String = gs.standard_ids()[0]
	gs.send_to_oirm(away)
	for id: String in gs.standard_ids():
		gs.get_sensor(id).error = gs.get_sensor(id).mpe * 2.0
	_set_day(cadence * 2 - 1)
	gs.at_oirm[away] = cadence * 3  # delayed: still away at the next audit
	_set_day(cadence * 2)
	gs._run_audit(cadence * 2)
	var audited: Array[String] = []
	for line: Dictionary in gs.audit_log[-1]["lines"]:
		audited.append(line["instrument_id"])
	for id: String in gs.standard_ids():
		if id == away and audited.has(id):
			problem = "%s is at OIRM and can't be audited." % id
		elif id != away and not audited.has(id):
			problem = "%s must be audited." % id
	if problem == "" and gs.audit_log[-1]["passed"]:
		problem = "An out-of-tolerance standard must fail the audit."
	GameClock.elapsed_days = saved
	gs.free()
	return problem


func test_bench_with_overdue_standard_is_untraceable() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var table: DriftingSensor = gs.get_sensor(gs.steering.calibrated_by)
	_set_day(table.cal_due_day + 1)
	var due_before: int = gs.steering.cal_due_day
	var record: Dictionary = gs.calibrate(gs.STEERING_ID)
	var chain: Dictionary = gs.traceability_chain(gs.STEERING_ID)
	GameClock.elapsed_days = saved
	gs.free()
	if record.get("traceable", true) or not record.get("standard_overdue", false):
		return "A calibration against an overdue standard must be untraceable: %s" % record
	if record["due_day"] != due_before:
		return "An untraceable calibration must not reschedule the unit."
	if chain["traceable"]:
		return "With no traceable calibration on record the chain must be broken: %s" % chain["text"]
	return ""


func test_chain_names_the_certificate() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	_set_day(2)
	_all_in_band(gs)
	var cert_id: String = gs.certificates[gs.steering.calibrated_by]["id"]
	gs.calibrate(gs.STEERING_ID)
	var chain: Dictionary = gs.traceability_chain(gs.STEERING_ID)
	var standard_chain: Dictionary = gs.traceability_chain(gs.steering.calibrated_by)
	GameClock.elapsed_days = saved
	gs.free()
	if not chain["traceable"] or not chain["text"].contains(cert_id) or not chain["text"].ends_with("OIRM"):
		return "A fresh bench calibration must chain to %s and OIRM: %s" % [cert_id, chain["text"]]
	if not standard_chain["traceable"] or not standard_chain["text"].contains(cert_id):
		return "An in-date standard must chain to its certificate: %s" % standard_chain["text"]
	return ""


## The recall re-judges each calibration with the standard's error taken out
## and flags only those whose result changes.
func test_recall_flags_only_changed_results() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var table: DriftingSensor = gs.get_sensor(gs.steering.calibrated_by)
	var cadence: int = _cadence()
	var problem: String = ""
	_set_day(cadence)
	_all_in_band(gs)
	gs._run_audit(cadence)
	var bad: float = table.mpe * 1.2  # out of tolerance
	table.error = bad
	var limit: float = gs.calibration_budget(gs.STEERING_ID)["acceptance_limit"]
	# Steering reads just inside A through the bad standard, really just outside.
	gs.steering.error = limit + bad * 0.5
	var near: Dictionary = gs.calibrate(gs.STEERING_ID)
	# The dish reads well inside either way.
	gs.get_sensor("relay_dish_azimuth").error = 0.0
	var far: Dictionary = gs.calibrate("relay_dish_azimuth")
	gs.send_to_oirm(table.instrument_id)
	table.error = bad
	_set_day(cadence * 2)
	gs.audit_grace_used = true
	gs._run_audit(cadence * 2)
	if near.get("refused", false) or far.get("refused", false):
		problem = "Setup: the bench refused a calibration."
	elif near["result"] != CalUncertainty.PASS:
		problem = "Setup: the steering record must read as a pass, got %s." % near["result"]
	elif not near["suspect"] or near.get("suspect_result", "") == CalUncertainty.PASS:
		problem = "A result that changes with the standard's error must be suspect: %s" % near
	elif far["suspect"]:
		problem = "A result that doesn't change must not be suspect (impact threshold)."
	elif not gs.suspect_units.has(gs.STEERING_ID) or gs.suspect_units.has("relay_dish_azimuth"):
		problem = "Only the steering encoder must be listed suspect: %s" % gs.suspect_units
	elif gs.traceability_chain(gs.STEERING_ID)["traceable"]:
		problem = "A suspect calibration must break the chain."
	else:
		var line: Dictionary = {}
		for l: Dictionary in gs.audit_log[-1]["lines"]:
			if l["instrument_id"] == gs.STEERING_ID:
				line = l
		if not line.get("suspect", false) or line["fine"] < int(DataManager.get_number(DRIFT, "compliance_fine/suspect_cal_credits", 75.0)):
			problem = "Vance must fine the suspect unit: %s" % line
	if problem == "":
		gs.calibrate(gs.STEERING_ID)
		if gs.suspect_units.has(gs.STEERING_ID):
			problem = "A traceable recalibration must clear the suspect flag."
	GameClock.elapsed_days = saved
	gs.free()
	return problem


## A suspect calibration of a standard cascades to the calibrations made with it.
func test_recall_cascades_through_a_standard() -> String:
	var gs: GameStateScript = _make_state()
	var standard_id: String = gs.standard_ids()[0]
	var second_id: String = gs.standard_ids()[1]
	var unit_id: String = gs.HYGROMETER_ID
	# Records built by hand: a standard calibrated against another standard
	# (no such pair in the data yet), then a unit calibrated against it.
	gs.cal_log.append({ "instrument_id": second_id, "standard_id": standard_id, "day": 3, "traceable": true,
		"as_found": 0.38, "mpe": 0.5, "acceptance_limit": 0.4, "result": CalUncertainty.PASS, "suspect": false })
	gs.cal_log.append({ "instrument_id": unit_id, "standard_id": second_id, "day": 4, "traceable": true,
		"as_found": 0.08, "mpe": 5.0, "acceptance_limit": 0.1, "result": CalUncertainty.PASS, "suspect": false })
	gs.cal_log.append({ "instrument_id": unit_id, "standard_id": second_id, "day": 2, "traceable": true,
		"as_found": 0.08, "mpe": 5.0, "acceptance_limit": 0.1, "result": CalUncertainty.PASS, "suspect": false })
	var flagged: Array[Dictionary] = gs.recall(standard_id, 0.06, 0)
	var problem: String = ""
	if flagged.size() != 2:
		problem = "The cascade must flag the standard's record and the unit's later one, got %d." % flagged.size()
	elif gs.cal_log[2]["suspect"]:
		problem = "A unit calibration made before the suspect standard calibration must not cascade."
	elif not gs.suspect_units.has(unit_id) or gs.suspect_units.has(second_id):
		problem = "Only units go on the suspect list: %s" % gs.suspect_units
	gs.free()
	return problem


func test_first_clean_audit_unlocks_tier1() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = _cadence()
	var problem: String = ""
	# A grace warning is not clean.
	_set_day(cadence)
	gs.steering.error = gs.steering.mpe * 2.0
	gs._run_audit(cadence)
	if gs.tier1_unlocked or gs.clean_audit_streak != 0:
		problem = "A grace warning must not unlock Tier 1."
	_set_day(cadence * 2)
	_all_in_band(gs)
	for id: String in gs.sensors:
		gs.get_sensor(id).cal_due_day = cadence * 4
	gs._run_audit(cadence * 2)
	if problem == "" and not (gs.tier1_unlocked and gs.clean_audit_streak == 1):
		problem = "The first clean audit must unlock Tier 1: %s" % gs.audit_log[-1]
	gs.steering.error = gs.steering.mpe * 2.0
	_set_day(cadence * 3)
	gs._run_audit(cadence * 3)
	if problem == "" and (gs.clean_audit_streak != 0 or not gs.tier1_unlocked):
		problem = "A failed audit resets the streak but Tier 1 stays unlocked."
	GameClock.elapsed_days = saved
	gs.free()
	return problem


## Smoke test of the bench overlay: standards are listed, and selecting one
## swaps the calibrate button for SEND TO OIRM and shows its certificate.
func test_bench_lists_standards_with_send_button() -> String:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var bench: CalBenchUI = (load("res://ui/cal_bench_ui.tscn") as PackedScene).instantiate()
	root.add_child(bench)
	var problem: String = ""
	var standard_id: String = GameState.standard_ids()[0]
	bench.open(standard_id)
	var button: Button = bench.get_node("%CalibrateButton")
	var standard_label: Label = bench.get_node("%StandardLabel")
	if not button.text.begins_with("SEND TO OIRM"):
		problem = "A standard must offer SEND TO OIRM, got %s." % button.text
	elif not standard_label.text.contains("OIRM-"):
		problem = "A standard must show its certificate: %s" % standard_label.text
	elif button.disabled != not GameState.drop_pod_present:
		problem = "SEND TO OIRM must be enabled only while the drop pod is on the pad."
	bench.open(GameState.STEERING_ID)
	if problem == "" and (button.text != CalBenchUI.CALIBRATE_TEXT or not standard_label.text.contains("Chain")):
		problem = "A unit must show the calibrate button and its chain: %s / %s" % [button.text, standard_label.text]
	root.remove_child(bench)
	bench.free()
	return problem
