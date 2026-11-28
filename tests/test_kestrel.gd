extends RefCounted
## Milestone 3b: Kestrel on solar flare nights, and standards with no
## certificate.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HM3: String = "multi_source_calibrator"
const HB700: String = "pressure_controller"
const FM3: String = "field_meter_dc"
const GAUGE: String = "dome_pressure"


func _run(body: Callable) -> String:
	var saved: float = GameClock.elapsed_days
	GameClock.elapsed_days = _flare_time()
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
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


func _flare_day() -> int:
	return int(DataManager.get_number(&"sensor_drift_config", "flares/first_day", 0.0))


## One hour into the first flare.
func _flare_time() -> float:
	return GameClock.elapsed_at_hour(_flare_day(), DataManager.get_number(&"sensor_drift_config", "flares/start_hour", 0.0) + 1.0)


## The FM-3 bought and sent to OIRM opens Tier 2.
func _open_tier2(gs: GameStateScript) -> void:
	gs.buy_standard(FM3)
	gs.oirm_calibrate(FM3, GameClock.get_day_index())
	gs.send_to_oirm(FM3)
	gs.at_oirm.clear()


func test_only_on_flare_nights() -> String:
	return _run(_check_nights)


func _check_nights(gs: GameStateScript) -> String:
	if not gs.kestrel_present():
		return "Kestrel must come on a flare night."
	_open_tier2(gs)
	var start: float = _flare_time() - 1.0 / 24.0
	var hours: float = DataManager.get_number(&"sensor_drift_config", "flares/duration_hours", 0.0)
	var period: float = DataManager.get_number(&"sensor_drift_config", "flares/period_days", 0.0)
	for wrong: float in [start - 0.01, start + hours / 24.0 + 0.01, _flare_time() + 1.0, _flare_time() - period]:
		GameClock.elapsed_days = wrong
		if gs.kestrel_present() or gs.buy_from_kestrel(HM3) == "":
			return "Kestrel must not trade at %s." % GameClock.format_now()
	GameClock.elapsed_days = _flare_time() + period
	if not gs.kestrel_present():
		return "The flares must come again."
	if floorf(start) != floorf(start + hours / 24.0 - 0.0001):
		return "A flare has to end before the next 06:00."
	return ""


func test_flare_notice_comes_once() -> String:
	return _run(_check_notice)


func _check_notice(gs: GameStateScript) -> String:
	var before: int = gs.phone_log.size()
	gs._on_time_advanced(2.0 / 24.0)
	if gs.phone_log.size() != before + 1 or not str(gs.phone_log[-1]).contains("Kestrel"):
		return "The phone must say the flare started."
	gs._on_time_advanced(0.5 / 24.0)
	return "" if gs.phone_log.size() == before + 1 else "It must say so once."


func test_gates_and_sellers() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	if not gs.buy_from_kestrel(HM3).contains("OIRM account"):
		return "The Tier 2 gate must hold for Kestrel."
	_open_tier2(gs)
	if gs.buy_from_kestrel(FM3) == "" or gs.buy_standard(HM3) != "Bram doesn't stock that.":
		return "Each seller sells only their own stock."
	if not gs.buy_from_kestrel(HB700).contains("sign-off"):
		return "The Tier 3 gate must hold for Kestrel."
	gs.contract_state = "complete"
	if HB700 in gs.kestrel_catalog() or not HB700 in gs.bram_catalog():
		return "A contract HB-700 is Bram's to sell."
	gs.credits = 0
	return "" if gs.buy_from_kestrel(HM3).begins_with("Costs") else "It must be paid for."


func test_no_certificate_until_oirm() -> String:
	return _run(_check_untraceable)


func _check_untraceable(gs: GameStateScript) -> String:
	_open_tier2(gs)
	var credits: int = gs.credits
	if gs.buy_from_kestrel(HM3) != "" or gs.credits >= credits or gs.certificates.has(HM3):
		return "The HM-3 must be sold for credits, with no certificate."
	var day: int = GameClock.get_day_index()
	if gs.standard_problem(HM3) != "without a certificate" or gs.traceability_chain(HM3)["traceable"]:
		return "It must not be traceable."
	if gs.get_sensor(HM3).is_overdue(day) or not gs.get_sensor(HM3).is_overdue(day + 1):
		return "It must be overdue from tomorrow."
	var before: Dictionary = gs.calibrate(FM3)
	if before.get("traceable", true) or gs.traceability_chain(FM3)["traceable"]:
		return "Work done with it must not be traceable: %s" % before
	gs.oirm_calibrate(HM3, day)
	if gs.standard_problem(HM3) != "" or before["traceable"] or gs.traceability_chain(FM3)["traceable"]:
		return "The certificate must not reach back to earlier work."
	if not gs.calibrate(FM3)["traceable"] or not gs.traceability_chain(FM3)["traceable"]:
		return "Work after the certificate must be traceable."
	return ""


func test_audit_flags_it() -> String:
	return _run(_check_audit)


func _check_audit(gs: GameStateScript) -> String:
	_open_tier2(gs)
	gs.buy_from_kestrel(HM3)
	GameClock.elapsed_days += 1.0
	gs._run_audit(GameClock.get_day_index())
	for line: String in gs.phone_log:
		if line.contains("HM-3") and line.contains("certificate missing") and line.contains("OVERDUE"):
			return ""
	return "The audit must flag it: %s" % "\n".join(gs.phone_log)


func test_contract_closes_when_bought() -> String:
	return _run(_check_contract)


func _check_contract(gs: GameStateScript) -> String:
	_open_tier2(gs)
	gs.traceable_lab = true
	gs.owned_standards[HM3] = 1
	gs.oirm_calibrate(HM3, GameClock.get_day_index())
	gs.contract_state = "active"
	var reason: String = gs.buy_from_kestrel(HB700)
	if reason != "" or gs.contract_state != "fulfilled" or gs.contract_text() != "":
		return "Buying the HB-700 must close the contract: " + reason
	if gs.get_sensor(GAUGE).calibrated_by != HB700:
		return "It must take over the dome gauge."
	gs.contract_state = ""
	gs._offer_first_contract()
	return "" if gs.contract_state == "fulfilled" else "When the HB-700 is already owned, _offer_first_contract must mark the contract fulfilled."


func test_jobs_prefer_a_certified_standard() -> String:
	return _run(_check_jobs)


func _check_jobs(gs: GameStateScript) -> String:
	gs.buy_standard("reference_gauge")
	gs.owned_standards[HB700] = GameClock.get_day_index()
	gs.get_sensor(HB700).cal_due_day = GameClock.get_day_index()
	var job: Dictionary = { "discipline": "pressure" }
	if gs.job_standards(job) != (["reference_gauge", HB700] as Array[String]):
		return "A certified WD-1 must come before an uncertified HB-700: %s" % [gs.job_standards(job)]
	gs.oirm_calibrate(HB700, GameClock.get_day_index())
	return "" if gs.job_standards(job)[0] == HB700 else "Certified, the higher tier comes first."


func test_an_uncertified_standard_survives_a_save_and_costs_credibility() -> String:
	return _run(_check_uncertified_lasts)


func _check_uncertified_lasts(gs: GameStateScript) -> String:
	_open_tier2(gs)
	gs.buy_from_kestrel(HM3)
	if gs.farm_from_dict(gs.farm_to_dict()) != "" or gs.standard_problem(HM3) != "without a certificate":
		return "A loaded farm's HM-3 must still have no certificate."
	# In date except the HM-3, so only it is charged.
	var day: int = GameClock.get_day_index()
	for id: String in gs.unit_ids() + gs.standard_ids():
		if id != HM3:
			gs.get_sensor(id).cal_due_day = day + 10
	gs.reset_credibility()
	var start: int = gs.credibility
	gs._charge_overdue_credibility(day)
	if gs.credibility != start:
		return "The night it is bought costs nothing."
	gs._charge_overdue_credibility(day + 1)
	var each: int = int(gs._cred_number("overdue_points_per_instrument_day", 0.0))
	return "" if each != 0 and gs.credibility == start + each else "From the next day it counts as one overdue instrument."


func test_kestrel_waits_for_the_lab_level() -> String:
	return _run(_check_lab_level)


func _check_lab_level(gs: GameStateScript) -> String:
	_open_tier2(gs)
	gs.lab_gates_kept.clear()
	var level: int = gs.lab_gate_level("tier2")
	if not gs.buy_from_kestrel(HM3).contains("lab level %d" % level):
		return "Kestrel's Tier 2 waits for its lab level: '%s'" % gs.buy_from_kestrel(HM3)
	gs.lab_xp = gs.xp_for_level(level)
	return "" if gs.buy_from_kestrel(HM3) == "" else gs.buy_from_kestrel(HM3)
