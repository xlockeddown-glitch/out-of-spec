extends RefCounted
## Milestone 3b: the Tier 3 gate, the Rb-2D's relay lock, and the WD-1 on the
## bench against the HB-700.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const RB: String = "rubidium_reference"
const HB700: String = "pressure_controller"
const WD1: String = "reference_gauge"
const TW6: String = "torque_standard"
const TIMEBASE: String = "relay_timebase"


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
	var problem: String = body.call(gs)
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func _give_rb(gs: GameStateScript) -> DriftingSensor:
	var rb: DriftingSensor = gs.get_sensor(RB)
	gs.owned_standards[RB] = 7
	rb.cal_interval_days = rb.initial_interval_days
	rb.cal_due_day = 7 + rb.initial_interval_days
	gs._issue_certificate(RB, 7, null, 0.0, false, "Qureshi & Hale", "QH")
	return rb


func test_sign_off_takes_two_clean_audits_in_a_row() -> String:
	return _run(_check_sign_off)


func _check_sign_off(gs: GameStateScript) -> String:
	for passed: bool in [true, false, true]:
		gs._update_clean_audit_gate({ "passed": passed })
	if gs.traceable_lab:
		return "A failed audit must break the run."
	gs._update_clean_audit_gate({ "passed": true })
	gs._update_clean_audit_gate({ "passed": false })
	return "" if gs.traceable_lab else "Two clean audits in a row sign the lab off for good."


func test_tier3_gate() -> String:
	return _run(_check_gate)


func _check_gate(gs: GameStateScript) -> String:
	if not gs.tier_problem(HB700).contains("OIRM account"):
		return "Tier 3 needs the OIRM account too."
	gs.buy_standard("field_meter_dc")
	gs.send_to_oirm("field_meter_dc")
	if not gs.tier_problem(HB700).contains("sign-off"):
		return "Tier 3 needs the sign-off."
	gs.traceable_lab = true
	if not gs.tier_problem(HB700).contains("Tier 2 standard"):
		return "Tier 3 needs a Tier 2 standard."
	gs.buy_standard(TW6)
	if not gs.tier_problem(HB700).contains("Tier 2 standard"):
		return "A maker's certificate is not OIRM's."
	gs.oirm_calibrate(TW6, 7)
	if gs.tier_problem(HB700) != "":
		return "An OIRM-certified Tier 2 standard must open Tier 3: " + gs.tier_problem(HB700)
	gs.get_sensor(TW6).cal_due_day = 6
	if gs.tier_problem(HB700) == "":
		return "An overdue Tier 2 standard must not count."
	if gs.standard_purchase_problem(RB) != "Bram doesn't stock that.":
		return "Bram must not sell the Rb-2D."
	gs.traceable_lab = false
	gs.contract_state = "complete"
	if gs.tier_problem(HB700) != "" or not HB700 in gs.bram_catalog():
		return "The contract HB-700 skips the gate."
	return ""


func test_rb_lock_and_holdover() -> String:
	return _run(_check_lock)


func _check_lock(gs: GameStateScript) -> String:
	var rb: DriftingSensor = _give_rb(gs)
	gs.set_rover_uplink("rover_1", true)
	GameClock.elapsed_days = 16.0
	gs._on_time_advanced(10.0)
	if rb.error != 0.0 or rb.cal_due_day != 17 + rb.cal_interval_days or gs.certificates[RB]["due_day"] != rb.cal_due_day:
		return "Locked, it must not drift and must stay in date."
	if gs.calibration_budget(TIMEBASE).get("tur", 0.0) < 4.0 or not gs.calibrate(TIMEBASE).get("traceable", false):
		return "A locked Rb-2D must calibrate the timebase traceably."
	if not str(gs.traceability_chain(RB)["text"]).contains("relay lock"):
		return "The chain must run through the relay: %s" % gs.traceability_chain(RB)
	if gs.send_to_oirm(RB)["ok"]:
		return "It must not go to OIRM."
	gs.set_rover_uplink("rover_1", false)
	gs.set_rover_uplink("rover_2", true)
	if not gs.is_relay_locked(RB):
		return "One rover in sight is enough."
	gs.set_rover_uplink("rover_2", false)
	GameClock.elapsed_days = 19.0
	gs._on_time_advanced(3.0)
	if rb.error == 0.0 or not str(gs.traceability_chain(RB)["text"]).contains("holdover"):
		return "In holdover it must drift, still in date on its last day."
	GameClock.elapsed_days = 20.0
	gs._note_holdover_lapses(21)
	if gs.standard_problem(RB) != "overdue" or gs.traceability_chain(RB)["traceable"] or gs.calibrate(TIMEBASE)["traceable"]:
		return "Too long in holdover must lapse the certificate."
	if not "\n".join(gs.phone_log).contains("out of lock too long"):
		return "The phone must say so."
	gs.set_rover_uplink("rover_1", true)
	if rb.error != 0.0 or gs.standard_problem(RB) != "" or not str(gs.phone_log[-1]).contains("locked"):
		return "Locking again must restore it."
	return ""


func test_wd1_on_the_bench() -> String:
	return _run(_check_wd1)


func _check_wd1(gs: GameStateScript) -> String:
	gs.buy_standard(WD1)
	if gs.has_bench_reference(WD1):
		return "The WD-1 needs the HB-700 on the colony."
	gs.owned_standards[HB700] = 7
	gs.oirm_calibrate(HB700, 7)
	if gs.calibration_budget(WD1)["tur"] < 4.0 or not str(gs.calibrate(WD1).get("certificate", "")).begins_with("IH-"):
		return "The HB-700 must certify the WD-1 on the bench."
	return ""
