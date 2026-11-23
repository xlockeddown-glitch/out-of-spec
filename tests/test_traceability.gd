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
	_set_day(cadence)
	_all_in_band(gs)
	gs._run_audit(cadence)
	var credits_before: int = gs.credits
	var sent: Dictionary = gs.send_to_oirm(table.instrument_id)
	if not sent["ok"] or sent["courier"]:
		problem = "Send with the pod present must ride the pod: %s" % sent
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


## Off audit day a standard goes by courier: fee plus surcharge, back a fixed
## number of days later, interval restarting from the return (Ryan, 2026-11-22).
func test_oirm_courier_off_day() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var table: DriftingSensor = gs.get_sensor(gs.steering.calibrated_by)
	var send_day: int = 2
	var back: int = send_day + gs.oirm_courier_days()
	var problem: String = ""
	_set_day(send_day)
	gs.drop_pod_present = false
	var credits_before: int = gs.credits
	var sent: Dictionary = gs.send_to_oirm(table.instrument_id)
	if not sent["ok"] or not sent["courier"]:
		problem = "Without the pod a standard must go by courier: %s" % sent
	elif gs.credits != credits_before - gs.oirm_fee() - gs.oirm_courier_surcharge():
		problem = "The courier must charge the fee plus the surcharge."
	elif gs.oirm_fee() + gs.oirm_courier_surcharge() != 300:
		problem = "Fee plus surcharge must total 300 CR, got %d." % (gs.oirm_fee() + gs.oirm_courier_surcharge())
	elif sent["return_day"] != back:
		problem = "Courier must return on day %d, got %s." % [back, sent["return_day"]]
	elif gs.send_to_oirm(table.instrument_id)["ok"]:
		problem = "A standard already away can't be sent again."
	elif not gs.calibrate(gs.STEERING_ID).get("refused", false):
		problem = "The bench must refuse while its standard is with the courier."
	_set_day(back - 1)
	gs._receive_oirm_returns(back - 1)
	if problem == "" and not gs.at_oirm.has(table.instrument_id):
		problem = "The standard must not be back early."
	_set_day(back)
	gs._on_day_started(back)
	var cert: Dictionary = gs.certificates[table.instrument_id]
	if problem == "" and (gs.at_oirm.has(table.instrument_id) or cert["day"] != back):
		problem = "The courier must bring it back certified on day %d: %s" % [back, cert]
	elif problem == "" and table.cal_due_day != back + table.cal_interval_days:
		problem = "The interval must restart from the return day."
	elif problem == "" and gs.calibrate(gs.STEERING_ID).get("refused", false):
		problem = "The bench must work again once the standard is back."
	GameClock.elapsed_days = saved
	gs.free()
	return problem


## A courier return that lands on an audit day is certified before Vance
## inspects, so the standard is audited with its new certificate.
func test_courier_return_on_audit_day() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = _cadence()
	var audit_day: int = cadence * 2
	var send_day: int = audit_day - gs.oirm_courier_days()
	var table_id: String = gs.steering.calibrated_by
	var problem: String = ""
	_all_in_band(gs)
	for id: String in gs.unit_ids():
		gs.get_sensor(id).cal_due_day = audit_day * 4
	_set_day(send_day)
	gs.drop_pod_present = false
	var sent: Dictionary = gs.send_to_oirm(table_id)
	if not sent["ok"] or sent["return_day"] != audit_day:
		problem = "Setup: courier must return on the audit day: %s" % sent
	_set_day(audit_day)
	gs._on_day_started(audit_day)
	var lines: Dictionary = _lines_by_id(gs.audit_log[-1])
	if problem == "" and gs.certificates[table_id]["day"] != audit_day:
		problem = "The standard must be certified the morning it returns."
	elif problem == "" and not lines.has(table_id):
		problem = "A standard back that morning must be audited."
	elif problem == "" and lines[table_id]["violation"]:
		problem = "A freshly certified standard must pass: %s" % lines[table_id]
	GameClock.elapsed_days = saved
	gs.free()
	return problem


## Each standard drifts from zero to its MPE in about 60 days (Ryan,
## 2026-11-22; the rates are placeholders).
func test_standard_drift_reaches_mpe_in_about_60_days() -> String:
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	for id: String in gs.standard_ids():
		var sensor: DriftingSensor = gs.get_sensor(id)
		var days: float = sensor.mpe / sensor.daily_drift_rate
		if days < 55.0 or days > 65.0:
			problem = "%s reaches its MPE in %.1f days, want about 60." % [id, days]
	gs.free()
	return problem


## A unit that falls due while its standard is at OIRM is excused at the first
## audit where it is overdue, not a violation and not blocking Tier 1. If it
## is not calibrated by the next audit it is an ordinary overdue there.
func test_unit_due_while_standard_away_is_excused_once() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = _cadence()
	var table_id: String = gs.steering.calibrated_by
	var problem: String = ""
	_all_in_band(gs)
	for id: String in gs.unit_ids():
		gs.get_sensor(id).cal_due_day = cadence * 10
	_set_day(1)
	gs.drop_pod_present = false
	gs.send_to_oirm(table_id)
	gs.steering.cal_due_day = 2  # falls due while the table is away
	_set_day(cadence)
	gs._run_audit(cadence)
	var line: Dictionary = _lines_by_id(gs.audit_log[-1])[gs.STEERING_ID]
	if not (line["overdue"] and line["excused"]) or line["violation"] or line["fine"] != 0:
		problem = "An excused unit must be no violation and no fine: %s" % line
	elif not gs.audit_log[-1]["passed"] or not gs.tier1_unlocked:
		problem = "An excused unit must not block a clean audit or Tier 1."
	_set_day(1 + gs.oirm_courier_days())
	gs._on_day_started(1 + gs.oirm_courier_days())  # the table comes back
	# Another unit due while its own standard is home is not excused.
	gs.hygrometer.cal_due_day = cadence + 1
	_set_day(cadence * 2)
	gs._run_audit(cadence * 2)
	var lines: Dictionary = _lines_by_id(gs.audit_log[-1])
	if problem == "" and (lines[gs.STEERING_ID]["excused"] or not lines[gs.STEERING_ID]["violation"]):
		problem = "Not calibrated by the next audit, it must be an ordinary overdue: %s" % lines[gs.STEERING_ID]
	elif problem == "" and (lines[gs.HYGROMETER_ID]["excused"] or not lines[gs.HYGROMETER_ID]["violation"]):
		problem = "A unit whose standard is home must not be excused: %s" % lines[gs.HYGROMETER_ID]
	GameClock.elapsed_days = saved
	gs.free()
	return problem


## A courier trip outlasts the audit cadence: a unit stays excused while its
## standard is away and at the audit the morning it comes back, then has until
## the next audit.
func test_excused_while_courier_outlasts_cadence() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var cadence: int = _cadence()
	var table_id: String = gs.steering.calibrated_by
	var send_day: int = cadence * 3 - 2
	var back: int = send_day + gs.oirm_courier_days()
	var problem: String = ""
	_all_in_band(gs)
	for id: String in gs.unit_ids():
		gs.get_sensor(id).cal_due_day = cadence * 20
	_set_day(send_day)
	gs.drop_pod_present = false
	gs.send_to_oirm(table_id)
	gs.steering.cal_due_day = send_day + 1
	var first_audit: int = gs.next_audit_day(send_day)
	var excused_through: int = gs.next_audit_day(back - 1)
	for day: int in range(send_day + 1, excused_through + cadence + 1):
		_set_day(day)
		gs._on_day_started(day)
		if day % cadence != 0 or problem != "":
			continue
		var line: Dictionary = _lines_by_id(gs.audit_log[-1])[gs.STEERING_ID]
		if day <= excused_through and not line["excused"]:
			problem = "Day %d audit: still excused while away or back only that morning (back day %d): %s" % [day, back, line]
		elif day > excused_through and (line["excused"] or not line["violation"]):
			problem = "Day %d audit: past the grace it is an ordinary overdue: %s" % [day, line]
	if problem == "" and excused_through <= first_audit:
		problem = "Setup: the trip must span more than one audit."
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
	var lines: Dictionary = _lines_by_id(gs.audit_log[-1])
	for id: String in gs.standard_ids():
		if id == away and lines.has(id):
			problem = "%s is at OIRM and can't be audited." % id
		elif id != away and not lines.has(id):
			problem = "%s must be audited." % id
		elif id != away and lines[id]["violation"]:
			problem = "Vance can't see a standard's error, only its certificate: %s" % lines[id]
	# A lapsed certificate is a violation.
	var home: String = gs.standard_ids()[1]
	gs.get_sensor(home).cal_due_day = cadence * 2
	_set_day(cadence * 3)
	gs._run_audit(cadence * 3)
	lines = _lines_by_id(gs.audit_log[-1])
	if problem == "" and not (lines.has(home) and lines[home]["violation"] and lines[home]["overdue"]):
		problem = "An overdue standard must be a violation: %s" % lines.get(home, {})
	GameClock.elapsed_days = saved
	gs.free()
	return problem


func _lines_by_id(report: Dictionary) -> Dictionary:
	var lines: Dictionary = {}
	for line: Dictionary in report["lines"]:
		lines[line["instrument_id"]] = line
	return lines


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
	elif _lines_by_id(gs.audit_log[-1])[gs.STEERING_ID]["suspect"]:
		problem = "The audit that announces a recall must not fine it yet."
	else:
		_set_day(cadence * 3)
		gs._run_audit(cadence * 3)
		var line: Dictionary = _lines_by_id(gs.audit_log[-1])[gs.STEERING_ID]
		if not line["suspect"] or line["fine"] < int(DataManager.get_number(DRIFT, "compliance_fine/suspect_cal_credits", 75.0)):
			problem = "Vance must fine a suspect unit not redone by the next audit: %s" % line
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
	# (no such pair in the data yet), then a unit calibrated against it, in log order.
	gs.cal_log.append({ "instrument_id": second_id, "standard_id": standard_id, "day": 3, "traceable": true,
		"as_found": 0.38, "mpe": 0.5, "acceptance_limit": 0.4, "result": CalUncertainty.PASS, "suspect": false })
	gs.cal_log.append({ "instrument_id": unit_id, "standard_id": second_id, "day": 2, "traceable": true,
		"as_found": 0.08, "mpe": 5.0, "acceptance_limit": 0.1, "result": CalUncertainty.PASS, "suspect": false })
	gs.cal_log.append({ "instrument_id": unit_id, "standard_id": second_id, "day": 4, "traceable": true,
		"as_found": 0.08, "mpe": 5.0, "acceptance_limit": 0.1, "result": CalUncertainty.PASS, "suspect": false })
	var flagged: Array[Dictionary] = gs.recall(standard_id, 0.06, 0)
	var problem: String = ""
	if flagged.size() != 2:
		problem = "The cascade must flag the standard's record and the unit's later one, got %d." % flagged.size()
	elif gs.cal_log[-2]["suspect"]:
		problem = "A unit calibration made before the suspect standard calibration must not cascade."
	elif not gs.suspect_units.has(unit_id) or gs.suspect_units.has(second_id):
		problem = "Only units go on the suspect list: %s" % gs.suspect_units
	gs.free()
	return problem


## An older suspect calibration that a later good one superseded leaves the
## unit's current calibration standing.
func test_superseded_record_does_not_make_unit_suspect() -> String:
	var gs: GameStateScript = _make_state()
	var standard_id: String = gs.standard_ids()[0]
	var unit_id: String = gs.HYGROMETER_ID
	gs.cal_log.append({ "instrument_id": unit_id, "standard_id": standard_id, "day": 2, "traceable": true,
		"as_found": 0.08, "mpe": 5.0, "acceptance_limit": 0.1, "result": CalUncertainty.PASS, "suspect": false })
	gs.cal_log.append({ "instrument_id": unit_id, "standard_id": standard_id, "day": 4, "traceable": true,
		"as_found": 0.0, "mpe": 5.0, "acceptance_limit": 0.1, "result": CalUncertainty.PASS, "suspect": false })
	var flagged: Array[Dictionary] = gs.recall(standard_id, 0.06, 0)
	var problem: String = ""
	if flagged.size() != 1 or not gs.cal_log[-2]["suspect"]:
		problem = "Only the older record changes result and must be flagged, got %d." % flagged.size()
	elif gs.suspect_units.has(unit_id):
		problem = "A superseded record must not make the unit suspect."
	gs.free()
	return problem


## A remote zero after a traceable calibration breaks the chain until the
## next traceable calibration.
func test_untraceable_adjustment_breaks_chain() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	_set_day(2)
	_all_in_band(gs)
	gs.calibrate(gs.STEERING_ID)
	var problem: String = ""
	if not gs.traceability_chain(gs.STEERING_ID)["traceable"]:
		problem = "Setup: a fresh bench calibration must be traceable."
	gs.calibrate(gs.STEERING_ID, gs.local_player_id, false)
	if problem == "" and gs.traceability_chain(gs.STEERING_ID)["traceable"]:
		problem = "A remote zero after the last traceable calibration must break the chain."
	gs.calibrate(gs.STEERING_ID)
	if problem == "" and not gs.traceability_chain(gs.STEERING_ID)["traceable"]:
		problem = "A traceable calibration must mend the chain."
	GameClock.elapsed_days = saved
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
## swaps the calibrate button for SEND (pod or courier) and shows its certificate.
func test_bench_lists_standards_with_send_button() -> String:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var bench: CalBenchUI = (load("res://ui/cal_bench_ui.tscn") as PackedScene).instantiate()
	root.add_child(bench)
	var problem: String = ""
	var standard_id: String = GameState.standard_ids()[0]
	bench.open(standard_id)
	var button: Button = bench.get_node("%CalibrateButton")
	var standard_label: Label = bench.get_node("%StandardLabel")
	var want: String = "SEND TO OIRM" if GameState.drop_pod_present else "SEND BY COURIER"
	if not button.text.begins_with(want):
		problem = "A standard must offer %s, got %s." % [want, button.text]
	elif not standard_label.text.contains("OIRM-"):
		problem = "A standard must show its certificate: %s" % standard_label.text
	elif button.disabled != GameState.at_oirm.has(standard_id):
		problem = "SEND must be enabled unless the standard is already away."
	bench.open(GameState.STEERING_ID)
	if problem == "" and (button.text != CalBenchUI.CALIBRATE_TEXT or not standard_label.text.contains("Chain")):
		problem = "A unit must show the calibrate button and its chain: %s / %s" % [button.text, standard_label.text]
	var table_id: String = GameState.steering.calibrated_by
	var was_away: bool = GameState.at_oirm.has(table_id)
	GameState.at_oirm[table_id] = 99
	bench.open(GameState.STEERING_ID)
	var result: Label = bench.get_node("%ResultLabel")
	if problem == "" and (not button.disabled or not result.text.contains("at OIRM")):
		problem = "With its standard at OIRM a unit can't be calibrated: %s" % result.text
	if not was_away:
		GameState.at_oirm.erase(table_id)
	root.remove_child(bench)
	bench.free()
	return problem
