extends RefCounted
## Lab credibility and the first OIRM contract (Ryan, 2026-11-22): audits and
## overdue instruments move the score, the phone shows a rating band, and at
## TRUSTED OIRM offers the HB-700 at a discount for a run of on-time
## calibrations. Points and thresholds come from data/economy.json
## ([PLACEHOLDER] values); the tests read them rather than hard-coding them.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const UNIT: String = "hygrometer"
const UNIT_STANDARD: String = "humidity_generator"
const WD1: String = "reference_gauge"
const HB700: String = "pressure_controller"
const DOME: String = "dome_pressure"
const DAY: int = 20


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.reset_credibility()
	gs.credits = 10000
	gs.crystal_ore = 10
	gs.tier1_unlocked = true
	for id: String in gs.sensors:
		gs.get_sensor(id).max_error = INF
	GameClock.elapsed_days = float(DAY - 1)
	# Everything in date, so only what a test changes is overdue.
	for id: String in gs.sensors:
		gs.get_sensor(id).cal_due_day = DAY + 10
	return gs


func _points(gs: GameStateScript, key: String) -> int:
	return int(gs._cred_number(key, 0.0))


func _phone_has(gs: GameStateScript, prefix: String) -> bool:
	for line: String in gs.phone_log:
		if line.begins_with(prefix):
			return true
	return false


## Calibrates UNIT as if it had run a full interval since its last
## calibration, so the result counts as interval evidence.
func _calibrate_after_interval(gs: GameStateScript, performed_by: String = "") -> Dictionary:
	var unit: DriftingSensor = gs.get_sensor(UNIT)
	unit.last_cal_day = DAY - unit.cal_interval_days
	if performed_by == "":
		return gs.calibrate(UNIT)
	return gs.calibrate(UNIT, performed_by)


## Raises credibility to the contract's offer band, which offers the contract.
func _reach_offer(gs: GameStateScript) -> void:
	var bands: Array[Dictionary] = gs._cred_bands()
	var need: int = int(bands[gs._contract_offer_band_index()]["min_points"])
	gs.change_credibility(need - gs.credibility)


func test_the_managers_favor_costs_no_credibility() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	for id: String in gs.standard_ids():
		gs.get_sensor(id).cal_due_day = DAY - 1
	var before: int = gs.credibility
	var record: Dictionary = gs.calibrate(UNIT, gs.MANAGER_ID)
	var after: int = gs.credibility
	gs.free()
	GameClock.elapsed_days = saved
	if not record.get("standard_overdue", false):
		return "The test needs an overdue standard, got %s" % record
	return "" if after == before else "The manager's use of an overdue standard cost %d points." % (before - after)


func test_audit_points_and_clamp() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var start: int = gs.credibility
	gs._credibility_after_audit({ "passed": true, "warning": false })
	if gs.credibility != start + _points(gs, "clean_audit_points"):
		problem = "A clean audit must add clean_audit_points, got %d from %d." % [gs.credibility, start]
	var before: int = gs.credibility
	gs._credibility_after_audit({ "passed": true, "warning": true })
	if problem == "" and gs.credibility != before + _points(gs, "warning_audit_points"):
		problem = "A grace warning must add warning_audit_points, got %d from %d." % [gs.credibility, before]
	before = gs.credibility
	gs._credibility_after_audit({ "passed": false, "warning": false })
	if problem == "" and gs.credibility != maxi(before + _points(gs, "failed_audit_points"), 0):
		problem = "A failed audit must add failed_audit_points, got %d from %d." % [gs.credibility, before]
	gs.change_credibility(-100000)
	if problem == "" and gs.credibility != 0:
		problem = "Credibility must not go below 0, got %d." % gs.credibility
	gs.change_credibility(100000)
	if problem == "" and gs.credibility != _points(gs, "max_points"):
		problem = "Credibility must stop at max_points, got %d." % gs.credibility
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_run_audit_moves_credibility() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var before: int = gs.credibility
	gs._run_audit(DAY)
	var report: Dictionary = gs.audit_log[-1]
	var expected: int = before + _points(gs, "clean_audit_points")
	if report.get("warning", false):
		expected = before + _points(gs, "warning_audit_points")
	elif not report["passed"]:
		expected = before + _points(gs, "failed_audit_points")
	var got: int = gs.credibility
	gs.free()
	GameClock.elapsed_days = saved
	if got != clampi(expected, 0, 100000):
		return "_run_audit must apply the audit's points: expected %d, got %d." % [expected, got]
	return ""


func test_overdue_charge_per_instrument_day() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var per: int = _points(gs, "overdue_points_per_instrument_day")
	gs.change_credibility(50)
	var before: int = gs.credibility
	gs._charge_overdue_credibility(DAY)
	if gs.credibility != before:
		problem = "Nothing overdue must cost nothing, got %d from %d." % [gs.credibility, before]
	gs.get_sensor(UNIT).cal_due_day = DAY - 1
	gs.get_sensor(UNIT_STANDARD).cal_due_day = DAY - 3
	before = gs.credibility
	gs._charge_overdue_credibility(DAY)
	if problem == "" and gs.credibility != before + 2 * per:
		problem = "Two overdue instruments must cost 2 × per day, got %d from %d." % [gs.credibility, before]
	# A standard away at OIRM is not charged.
	gs.at_oirm[UNIT_STANDARD] = DAY + 5
	before = gs.credibility
	gs._charge_overdue_credibility(DAY)
	if problem == "" and gs.credibility != before + per:
		problem = "A standard at OIRM must not be charged, got %d from %d." % [gs.credibility, before]
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_overdue_standard_used_costs_more() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	gs.change_credibility(50)
	gs.get_sensor(UNIT_STANDARD).cal_due_day = DAY - 1
	var before: int = gs.credibility
	var record: Dictionary = gs.calibrate(UNIT)
	var got: int = gs.credibility
	var expected: int = before + _points(gs, "overdue_standard_used_points")
	gs.free()
	GameClock.elapsed_days = saved
	if not record.get("standard_overdue", false):
		return "The test needs a calibration against an overdue standard: %s" % record
	if got != expected:
		return "Using an overdue standard must cost overdue_standard_used_points: expected %d, got %d." % [expected, got]
	return ""


func test_band_text() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var bands: Array[Dictionary] = gs._cred_bands()
	var problem: String = ""
	if bands.size() >= 2:
		var low: int = int(bands[0]["min_points"])
		var high: int = int(bands[1]["min_points"])
		gs.credibility = low + (high - low) / 2
		var pct: int = floori(100.0 * (gs.credibility - low) / (high - low))
		var want: String = "%s, %d %% to %s" % [str(bands[0]["name"]).to_upper(), pct, str(bands[1]["name"]).to_upper()]
		if gs.credibility_text() != want:
			problem = "Expected '%s', got '%s'." % [want, gs.credibility_text()]
	gs.credibility = _points(gs, "max_points")
	if problem == "" and gs.credibility_text() != str(bands[-1]["name"]).to_upper():
		problem = "The top band shows its name alone, got '%s'." % gs.credibility_text()
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_contract_offer_run_and_reset() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var needed: int = gs.contract_run_needed()
	_reach_offer(gs)
	if gs.contract_state != "active":
		problem = "Reaching the offer band must offer the contract, state '%s'." % gs.contract_state
	if problem == "" and not _phone_has(gs, "OIRM: Lab credibility raised to"):
		problem = "Reaching a new band must be announced on the phone."
	if problem == "" and not _phone_has(gs, "OIRM CONTRACT offered"):
		problem = "The offer must be posted on the phone."
	_calibrate_after_interval(gs)
	_calibrate_after_interval(gs)
	if problem == "" and gs.contract_run != 2:
		problem = "Two on-time traceable calibrations must count 2, got %d." % gs.contract_run
	var hb: DriftingSensor = gs.get_sensor(HB700)
	var price: String = "%s CR + %d crystal ore" % [
		SP811.integer(hb.price_credits * (100 - gs.contract_discount_pct()) / 100), hb.price_ore]
	var shown: String = gs.contract_text()
	if problem == "" and not (shown.begins_with("OIRM CONTRACT: 2 of %d in a row, on time, traceable" % needed)
			and shown.contains("half its interval") and shown.contains("HB-700 for " + price)):
		problem = "The phone must show the run, the interval rule and the price, got '%s'." % shown
	# Calibrating again within the same interval neither counts nor breaks the run.
	gs.calibrate(UNIT)
	if problem == "" and gs.contract_run != 2:
		problem = "A repeat within the interval must not count, got %d." % gs.contract_run
	_calibrate_after_interval(gs, gs.MANAGER_ID)
	if problem == "" and gs.contract_run != 2:
		problem = "The Manager's calibration must not count toward the run, got %d." % gs.contract_run
	gs.get_sensor(UNIT).cal_due_day = DAY - 1
	_calibrate_after_interval(gs)
	if problem == "" and (gs.contract_run != 0 or not _phone_has(gs, "OIRM CONTRACT: run restarted (late calibration)")):
		problem = "A late calibration must restart the run, got %d." % gs.contract_run
	for i: int in needed:
		_calibrate_after_interval(gs)
	if problem == "" and gs.contract_state != "complete":
		problem = "%d on-time calibrations in a row must complete the contract, state '%s'." % [needed, gs.contract_state]
	if problem == "" and not gs.bram_catalog().has(HB700):
		problem = "Once complete, Bram must list the contract standard."
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_contract_standard_discount_and_takeover() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	if gs.bram_catalog().has(HB700):
		problem = "Bram must not list the HB-700 before the contract is complete."
	if problem == "" and gs.buy_standard(WD1) != "":
		problem = "Could not buy the WD-1 for the test."
	var dome: DriftingSensor = gs.get_sensor(DOME)
	dome.cal_due_day = DAY + 4
	gs.contract_state = "complete"
	gs.lab_gates_kept.append(gs.KEPT_CONTRACT_SALE)  # a farm that had earned it: the discount alone opens no tier
	var hb: DriftingSensor = gs.get_sensor(HB700)
	var price: int = hb.price_credits * (100 - gs.contract_discount_pct()) / 100
	if problem == "" and gs.standard_price_credits(HB700) != price:
		problem = "The discounted price must be %d, got %d." % [price, gs.standard_price_credits(HB700)]
	var want_text: String = "%s CR + %d crystal ore" % [SP811.integer(price), hb.price_ore]
	if problem == "" and gs.standard_price_text(HB700) != want_text:
		problem = "Price text must be '%s', got '%s'." % [want_text, gs.standard_price_text(HB700)]
	var credits_before: int = gs.credits
	if problem == "" and gs.buy_standard(HB700) != "":
		problem = "Could not buy the HB-700: %s" % gs.standard_purchase_problem(HB700)
	if problem == "" and credits_before - gs.credits != price:
		problem = "Buying must charge the discounted %d, charged %d." % [price, credits_before - gs.credits]
	if problem == "" and gs.contract_state != "fulfilled":
		problem = "Buying the contract standard must fulfil the contract, state '%s'." % gs.contract_state
	if problem == "" and (dome.calibrated_by != HB700 or not gs.is_in_service(DOME)):
		problem = "The dome gauge must move to the HB-700 and stay in service, calibrated_by '%s'." % dome.calibrated_by
	if problem == "" and dome.cal_due_day != DAY + 4:
		problem = "The takeover must keep the dome gauge's due day %d, got %d." % [DAY + 4, dome.cal_due_day]
	var tur: float = float(gs.calibration_budget(DOME).get("tur", 0.0))
	if problem == "" and tur < 4.0:
		problem = "Against the HB-700 the dome gauge's TUR must reach 4:1, got %s." % tur
	gs.free()
	GameClock.elapsed_days = saved
	return problem


func test_contract_untraceable_restarts_run() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	_reach_offer(gs)
	_calibrate_after_interval(gs)
	gs.get_sensor(UNIT_STANDARD).cal_due_day = DAY - 1  # on time, but against an overdue standard
	_calibrate_after_interval(gs)
	var run: int = gs.contract_run
	var restarted: bool = _phone_has(gs, "OIRM CONTRACT: run restarted (not traceable)")
	# The next traceable calibration, half an interval or more after the last
	# one, counts even though an untraceable adjustment came in between.
	gs.get_sensor(UNIT_STANDARD).cal_due_day = DAY + 100
	_calibrate_after_interval(gs)
	var run_after: int = gs.contract_run
	gs.free()
	GameClock.elapsed_days = saved
	if run != 0 or not restarted:
		return "An on-time calibration that is not traceable must restart the run, got %d." % run
	if run_after != 1:
		return "A traceable calibration after an untraceable one must count once half the interval has passed, got %d." % run_after
	return ""


## A unit that fell due while its standard was at OIRM is not charged until
## the audit after the standard came back has passed (Vance's grace).
func test_overdue_excused_through_oirm_grace() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var per: int = _points(gs, "overdue_points_per_instrument_day")
	gs.change_credibility(50)
	# GPT's case (cadence 5): away days 6 to 13, unit due day 11. The day-15
	# audit excuses it until the day-20 audit, so no charge before day 21.
	var sent: int = 6
	var back: int = 13
	var unit: DriftingSensor = gs.get_sensor(UNIT)
	unit.cal_due_day = 11
	gs.oirm_trips.append({ "standard_id": UNIT_STANDARD, "sent_day": sent, "return_day": back, "courier": true })
	# The latest deadline Vance grants at any audit.
	var deadline: int = -1
	for audit: int in range(1, 60):
		if audit % maxi(int(gs._schedule("cadence_days", 5.0)), 1) == 0:
			deadline = maxi(deadline, int(gs._excused_units(audit).get(UNIT, -1)))
	if deadline <= gs.next_audit_day(back):
		problem = "The test needs a grace that runs past the first audit after the return, got %d." % deadline
	var before: int = gs.credibility
	for day: int in range(back + 1, deadline + 1):
		gs._charge_overdue_credibility(day)
	if gs.credibility != before:
		problem = "No charge through the audit after the standard came back (day %d), got %d from %d." % [deadline, gs.credibility, before]
	before = gs.credibility
	gs._charge_overdue_credibility(deadline + 1)
	if problem == "" and gs.credibility != before + per:
		problem = "The morning after that audit the unit must be charged, got %d from %d." % [gs.credibility, before]
	# A unit that fell due before the trip is not excused.
	unit.cal_due_day = sent - 1
	before = gs.credibility
	gs._charge_overdue_credibility(DAY)
	if problem == "" and gs.credibility != before + per:
		problem = "A unit due before the trip must be charged, got %d from %d." % [gs.credibility, before]
	gs.free()
	GameClock.elapsed_days = saved
	return problem


## A unit that fell due between two trips, with its standard home, gets no
## grace from the later trip still being away.
func test_overdue_between_trips_not_excused() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var per: int = _points(gs, "overdue_points_per_instrument_day")
	gs.change_credibility(50)
	gs.get_sensor(UNIT).cal_due_day = 12
	gs.oirm_trips.append({ "standard_id": UNIT_STANDARD, "sent_day": 5, "return_day": 10, "courier": true })
	gs.oirm_trips.append({ "standard_id": UNIT_STANDARD, "sent_day": 15, "return_day": 20, "courier": true })
	gs.at_oirm[UNIT_STANDARD] = 20
	var before: int = gs.credibility
	gs._charge_overdue_credibility(16)
	var got: int = gs.credibility
	var audit_excused: bool = gs._excused_units(16).has(UNIT)
	gs.free()
	GameClock.elapsed_days = saved
	if got != before + per:
		return "A unit due while its standard was home must be charged, got %d from %d." % [got, before]
	if audit_excused:
		return "Vance must not excuse a unit due between trips."
	return ""


## Buying the HB-700 with no WD-1 puts the dome gauge in service fresh,
## not already overdue.
func test_contract_standard_without_wd1() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var dome: DriftingSensor = gs.get_sensor(DOME)
	dome.cal_due_day = 0
	gs.contract_state = "complete"
	gs.lab_gates_kept.append(gs.KEPT_CONTRACT_SALE)  # a farm that had earned it: the discount alone opens no tier
	if gs.is_in_service(DOME):
		problem = "The test needs the dome gauge out of service before the purchase."
	if problem == "" and gs.buy_standard(HB700) != "":
		problem = "Could not buy the HB-700: %s" % gs.standard_purchase_problem(HB700)
	var today: int = GameClock.get_day_index()
	if problem == "" and (not gs.is_in_service(DOME) or dome.calibrated_by != HB700):
		problem = "The dome gauge must go into service against the HB-700."
	if problem == "" and (dome.cal_due_day <= today or dome.is_overdue(today)):
		problem = "The dome gauge must start in date, due day %d on day %d." % [dome.cal_due_day, today]
	gs.free()
	GameClock.elapsed_days = saved
	return problem


## Owning the HB-700 before reaching the offer band marks the first contract
## fulfilled on offer so the level-35 second contract can still open.
func test_contract_fulfilled_when_standard_owned_first() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	var problem: String = ""
	var emitted: Array[int] = [0]
	gs.credibility_changed.connect(func(_v: int) -> void: emitted[0] += 1)
	gs.owned_standards[HB700] = DAY
	_reach_offer(gs)
	if gs.contract_state != "fulfilled":
		problem = "Owning the HB-700 first must mark the contract fulfilled, got '%s'." % gs.contract_state
	if problem == "" and emitted[0] < 1:
		problem = "Marking the contract fulfilled must emit credibility_changed."
	var expected_line: String = "OIRM CONTRACT closed: the %s is already on the colony." % gs.instrument_name(HB700)
	if problem == "" and not _phone_has(gs, expected_line):
		problem = "Expected phone line '%s', got %s." % [expected_line, gs.phone_log]
	if problem == "" and gs.contract_text() != "":
		problem = "A fulfilled contract must show no open contract text, got '%s'." % gs.contract_text()
	# The second contract's precondition (first contract complete or fulfilled) is now met.
	gs.lab_xp = gs.xp_for_level(gs.lab_gate_level("second_contract"))
	gs.update_quests()
	if problem == "" and (not gs.quest_state.has("second_contract") or QuestEngine.is_done(gs, "second_contract")):
		problem = "Second contract must be offered at level 35 once the first contract is fulfilled."
	gs.free()
	GameClock.elapsed_days = saved
	return problem
