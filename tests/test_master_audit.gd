extends RefCounted
## Slice 34: the OIRM master audit (lab 52, Accredited) and the intrinsic silk
## standard (lab 56, needs master_audit_passed).
## Tests gates, guest anti-spoofing, two-morning audit pass/fail/cooldown,
## Jig-3 self-quarantine beat, co-op auditor names (1/2/4 players), intrinsic
## silk quest and traceability chain root, certificate wall, save/load
## (including old saves and bad-type rejection), guest sync, and late joiners.
## Every GameState is freed and every global is restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const BENCH_SCENE: PackedScene = preload("res://ui/cal_bench_ui.tscn")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const THIRD: String = "player_3"
const FOURTH: String = "player_4"
const SILK_SPINNER: StringName = &"orbital_silk_spinner"
const CRYSTAL_WEAVER: StringName = &"crystal_weaver"


func _run(body: Callable) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var saved_guest: bool = FarmCommands.guest
	var saved_state: Node = FarmCommands.state
	GameClock.elapsed_days = 9.0
	CoopSession.players.clear()
	FarmCommands.guest = false
	var gs: GameStateScript = _clean_farm()
	FarmCommands.state = gs
	var out: Variant = body.call(gs)
	FarmCommands.state = saved_state
	FarmCommands.guest = saved_guest
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	gs.free()
	return out if out is String else "The test stopped early or did not return a String."


func _clean_farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(34)
	gs.reset_credibility()
	gs.credits = 5000
	gs.credibility = 80
	gs.lab_xp = gs.xp_for_level(52)
	# Ensure every in-service unit and standard is traceable, in date, and in tolerance.
	var today: int = GameClock.get_day_index()
	for id: String in gs.standard_ids():
		var std: DriftingSensor = gs.get_sensor(id)
		std.error = 0.0
		std.cal_due_day = today + 30
		if gs.certificates.has(id):
			gs.certificates[id]["due_day"] = today + 30
	for id: String in gs.unit_ids():
		var unit: DriftingSensor = gs.get_sensor(id)
		unit.error = 0.0
		unit.cal_due_day = today + 30
		gs.cal_log.append(_cal_row(id, today))
	return gs


func _cal_row(instrument_id: String, day: int, overrides: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {
		"instrument_id": instrument_id,
		"unit": "degrees",
		"mpe": 0.45,
		"as_found": 0.05,
		"as_found_band": "PASS",
		"as_found_in_tolerance": true,
		"as_left": 0.0,
		"as_left_band": "PASS",
		"day": day,
		"performed_by": HOST,
		"programmed_by": "",
		"on_time": true,
		"days_in_service": 5,
		"interval_evidence": true,
		"previous_interval_days": 5,
		"interval_days": 15,
		"due_day": day + 15,
		"standard_id": "rotary_table",
		"standard_uncertainty": 0.02,
		"tur": 22.5,
		"plain_tur": 22.5,
		"acceptance_limit": 0.43,
		"result": CalUncertainty.PASS,
		"traceable": true,
		"bench_minutes": 30,
		"standard_overdue": false,
		"standard_problem": "",
		"standard_certificate": "FND-0001",
		"suspect": false,
	}
	row.merge(overrides, true)
	return row


func _advance_morning(gs: GameStateScript, day: int) -> void:
	GameClock.elapsed_days = float(day - 1)
	gs._on_day_started(day)


func _has_line(gs: GameStateScript, part: String) -> bool:
	for line: String in gs.phone_log:
		if line.contains(part):
			return true
	return false


func _add_released_robot(gs: GameStateScript, robot_id: String = "R-01") -> String:
	var today: int = GameClock.get_day_index()
	gs.robots[robot_id] = {
		"id": robot_id,
		"name": "Jig-3",
		"frame": "trellis",
		"state": "released",
		"ready_day": today - 2,
		"cards": [],
		"holding": false,
		"override": false,
		"override_logged": false,
	}
	gs._sync_robot_sensors(gs.robots)
	var first_sensor: String = ""
	for sid: String in gs.robot_sensor_ids(robot_id):
		if first_sensor == "":
			first_sensor = sid
		var s: DriftingSensor = gs.get_sensor(sid)
		s.error = 0.0
		s.cal_due_day = today + 30
		gs.cal_log.append(_cal_row(sid, today - 1))
	return first_sensor


func test_protocol_gates_and_guest_spoof_refused() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	if CoopSession.PROTOCOL != 54:
		return "Expected CoopSession.PROTOCOL == 54, got %d." % CoopSession.PROTOCOL
	if not (&"ask_master_audit" in FarmCommands.ACTIONS):
		return "ask_master_audit must be registered in FarmCommands.ACTIONS."
	if gs.lab_gate_level("master_audit") != 52:
		return "master_audit lab gate must be built at level 52, got %d." % gs.lab_gate_level("master_audit")
	if gs.lab_gate_level("intrinsic_silk_contract") != 56:
		return "intrinsic_silk_contract lab gate must be built at level 56, got %d." % gs.lab_gate_level("intrinsic_silk_contract")
	# Below lab 52 -> refused via lab_gate_problem.
	gs.lab_xp = gs.xp_for_level(51)
	var below_lvl: String = gs.ask_master_audit(HOST)
	if not below_lvl.contains("lab level 52"):
		return "Below lab 52 must be refused with lab level 52: '%s'" % below_lvl
	# At lab 52, below Accredited -> refused.
	gs.lab_xp = gs.xp_for_level(52)
	gs.credibility = 40
	var below_band: String = gs.ask_master_audit(HOST)
	if not below_band.contains("Accredited"):
		return "Below Accredited must be refused: '%s'" % below_band
	# Guest spoofing another player id via command payload -> refused by FarmCommands.
	gs.credibility = 80
	var spoof_problem: String = FarmCommands.problem(&"ask_master_audit", [HOST])
	if spoof_problem == "":
		return "FarmCommands must refuse extra player_id argument (spoof attempt)."
	var spoof_res: Variant = FarmCommands.execute(GUEST, &"ask_master_audit", [HOST])
	if str(spoof_res) == "" or not gs.master_audit.is_empty():
		return "Spoofed execute must refuse and leave master_audit untouched: '%s'" % str(spoof_res)
	# Valid request via FarmCommands books for next morning (day 11).
	var ok_res: Variant = FarmCommands.execute(HOST, &"ask_master_audit", [])
	if str(ok_res) != "":
		return "Valid ask_master_audit must succeed, got '%s'" % str(ok_res)
	if str(gs.master_audit.get("status", "")) != "booked" or int(gs.master_audit.get("start_day", 0)) != 11:
		return "Must book for day 11: %s" % [gs.master_audit]
	# Refused while booked.
	var while_booked: String = gs.ask_master_audit(HOST)
	if while_booked == "":
		return "Must refuse a second ask while booked."
	# Advance to day 11 (morning 1 clean -> status running), refused while running.
	_advance_morning(gs, 11)
	if str(gs.master_audit.get("status", "")) != "running":
		return "Expected status 'running' after morning 1, got %s" % [gs.master_audit]
	var while_running: String = gs.ask_master_audit(HOST)
	if while_running == "":
		return "Must refuse ask while running."
	return ""


func test_two_clean_mornings_pass_pay_once_and_certificate_wall() -> String:
	return _run(_check_clean_pass)


func _check_clean_pass(gs: GameStateScript) -> String:
	var credits_before: int = gs.credits
	var xp_before: int = gs.lab_xp
	gs.update_quests()
	if not gs.quest_state.has("master_audit"):
		return "master_audit quest must be offered at lab 52 + Accredited."
	var err: String = gs.ask_master_audit(HOST)
	if err != "":
		return "ask_master_audit failed: %s" % err
	_advance_morning(gs, 11)
	if gs.master_audit_passed:
		return "Must not pass after only 1 morning."
	_advance_morning(gs, 12)
	if not gs.master_audit_passed:
		return "Must pass after 2 clean mornings."
	if gs.credits != credits_before + GameStateScript.MASTER_AUDIT_CREDITS:
		return "Expected +%d CR, got delta %d." % [GameStateScript.MASTER_AUDIT_CREDITS, gs.credits - credits_before]
	if gs.lab_xp != xp_before + GameStateScript.MASTER_AUDIT_LAB_XP:
		return "Expected +%d lab XP, got delta %d." % [GameStateScript.MASTER_AUDIT_LAB_XP, gs.lab_xp - xp_before]
	if not QuestEngine.is_done(gs, "master_audit"):
		return "master_audit lab quest must complete once master_audit_passed is true."
	# Certificate entry on the wall (no gold border at lab 52).
	var certs: Array[Dictionary] = CertificateWall.earned_from(gs)
	var found_cert: Dictionary = {}
	for c: Dictionary in certs:
		if str(c.get("id", "")) in ["quest_master_audit", "master_audit"]:
			found_cert = c
			break
	if found_cert.is_empty():
		return "CertificateWall must include the master audit certificate: %s" % [certs]
	if bool(found_cert.get("gold_border", false)):
		return "Certificate at lab 52 must not have gold_border."
	# Asking again or advancing another morning must never pay twice.
	if gs.ask_master_audit(HOST) == "":
		return "Must refuse ask after already passed."
	var credits_after: int = gs.credits
	var xp_after: int = gs.lab_xp
	_advance_morning(gs, 13)
	if gs.credits != credits_after or gs.lab_xp != xp_after:
		return "Passing must pay only once."
	return ""


func test_finding_fails_with_report_and_cooldown_then_reask() -> String:
	return _run(_check_fail_and_cooldown)


func _check_fail_and_cooldown(gs: GameStateScript) -> String:
	# Fail on morning 1 due to conservatory climate out of band (hygrometer OOT).
	gs.hygrometer.error = gs.hygrometer.mpe * 2.0
	if gs.ask_master_audit(HOST) != "":
		return "Booking failed."
	_advance_morning(gs, 11)
	if gs.master_audit_passed:
		return "Must not pass when conservatory climate is out of band."
	if str(gs.master_audit.get("status", "")) != "cooldown":
		return "Expected cooldown status after fail, got %s" % [gs.master_audit]
	if not _has_line(gs, "Conservatory climate out of band"):
		return "Report must name conservatory climate finding: %s" % [gs.phone_log]
	# Refused during 7-day cooldown (day 11 + 7 = day 18).
	GameClock.elapsed_days = 16.0
	if not gs.ask_master_audit(HOST).contains("cooldown"):
		return "Must refuse during cooldown on day 17."
	# Fix climate, wait until day 18, re-ask, and test failing on morning 2 via interlock override.
	gs.hygrometer.error = 0.0
	for id: String in gs.unit_ids() + gs.standard_ids():
		gs.get_sensor(id).cal_due_day = 50
		if gs.certificates.has(id):
			gs.certificates[id]["due_day"] = 50
	GameClock.elapsed_days = 17.0
	if gs.ask_master_audit(HOST) != "":
		return "Re-ask on day 18 after cooldown must succeed: %s" % gs.ask_master_audit(HOST)
	_advance_morning(gs, 19)
	if str(gs.master_audit.get("status", "")) != "running":
		return "Morning 19 should be clean and running: %s" % [gs.master_audit]
	# Interlock override on day 19 -> morning 20 must fail!
	gs.last_interlock_override_day = 19
	_advance_morning(gs, 20)
	if gs.master_audit_passed or str(gs.master_audit.get("status", "")) != "cooldown":
		return "Morning 20 must fail on recent interlock override: %s" % [gs.master_audit]
	if not _has_line(gs, "interlock overridden"):
		return "Report must mention interlock override finding: %s" % [gs.phone_log]
	return ""


func test_overdue_robot_fails_but_jig3_oot_self_quarantines_and_passes() -> String:
	return _run(_check_jig3_beat)


func _check_jig3_beat(gs: GameStateScript) -> String:
	var sensor_id: String = _add_released_robot(gs, "R-01")
	if sensor_id == "":
		return "Setup: robot must have at least one sensor."
	# Robot performed a traceable calibration after its sensor's last good check.
	gs.cal_log.append(_cal_row(gs.STEERING_ID, 10, {
		"performed_by": "R-01",
		"programmed_by": HOST,
	}))
	# Put the robot sensor OUT OF TOLERANCE (but NOT overdue).
	var rs: DriftingSensor = gs.get_sensor(sensor_id)
	rs.error = rs.mpe * 2.0
	if gs.ask_master_audit(HOST) != "":
		return "Booking failed."
	_advance_morning(gs, 11)
	if str(gs.master_audit.get("status", "")) != "running":
		return "Jig-3 OOT sensor must NOT fail morning 1: %s / %s" % [gs.master_audit, gs.phone_log]
	if not _has_line(gs, "JIG-3 SELF-QUARANTINE") or not _has_line(gs, "Steering"):
		return "Report must list Jig-3 self-quarantine and suspect Steering calibration: %s" % [gs.phone_log]
	_advance_morning(gs, 12)
	if not gs.master_audit_passed:
		return "Audit must still pass with Jig-3 self-quarantine credited."
	# Also verify an OVERDUE robot calibration DOES fail a fresh master audit.
	GameClock.elapsed_days = 9.0
	var gs2: GameStateScript = _clean_farm()
	var s2_id: String = _add_released_robot(gs2, "R-01")
	gs2.get_sensor(s2_id).cal_due_day = 5
	gs2.ask_master_audit(HOST)
	_advance_morning(gs2, 11)
	var overdue_failed: bool = not gs2.master_audit_passed and str(gs2.master_audit.get("status", "")) == "cooldown" \
			and _has_line(gs2, "calibration overdue")
	gs2.free()
	if not overdue_failed:
		return "Overdue robot calibration must fail the master audit."
	return ""


func test_auditor_names_for_1_2_and_4_players() -> String:
	return _run(_check_auditor_names)


func _check_auditor_names(gs: GameStateScript) -> String:
	var one: String = gs.master_audit_auditors_text([HOST])
	if one != "CLADEUS (PLAYER 1), GEMINID (PLAYER 1), CHATTERLY-PT (PLAYER 1), SPACEFLUX-SI (PLAYER 1)":
		return "1-player auditor line wrong: '%s'" % one
	var two: String = gs.master_audit_auditors_text([HOST, GUEST])
	if two != "CLADEUS (PLAYER 1), GEMINID (PLAYER 2), CHATTERLY-PT (PLAYER 1), SPACEFLUX-SI (PLAYER 2)":
		return "2-player auditor line wrong: '%s'" % two
	var four: String = gs.master_audit_auditors_text([HOST, GUEST, THIRD, FOURTH])
	if four != "CLADEUS (PLAYER 1), GEMINID (PLAYER 2), CHATTERLY-PT (PLAYER 3), SPACEFLUX-SI (PLAYER 4)":
		return "4-player auditor line wrong: '%s'" % four
	return ""


func test_intrinsic_silk_quest_and_traceability_chain() -> String:
	return _run(_check_intrinsic_silk)


func _check_intrinsic_silk(gs: GameStateScript) -> String:
	# Before master_audit_passed, even at lab 56, intrinsic_silk is NOT offered.
	gs.lab_xp = gs.xp_for_level(56)
	gs.update_quests()
	if gs.quest_state.has("intrinsic_silk"):
		return "intrinsic_silk must not be offered before master_audit_passed."
	# Before intrinsic_standard, traceability_chain ends at OIRM.
	var before_chain: Dictionary = gs.traceability_chain(gs.STEERING_ID)
	if not before_chain["traceable"] or not str(before_chain["text"]).ends_with("← OIRM"):
		return "Before intrinsic_standard, chain must end at OIRM: '%s'" % str(before_chain["text"])
	# With master_audit_passed at lab 55 -> still not offered.
	gs.master_audit_passed = true
	gs.lab_xp = gs.xp_for_level(55)
	gs.update_quests()
	if gs.quest_state.has("intrinsic_silk"):
		return "intrinsic_silk must not be offered below lab 56."
	# At lab 56 + master_audit_passed -> offered in the morning.
	gs.lab_xp = gs.xp_for_level(56)
	gs.update_quests()
	if not gs.quest_state.has("intrinsic_silk") or QuestEngine.is_done(gs, "intrinsic_silk"):
		return "intrinsic_silk must be offered at lab 56 after master_audit_passed."
	var credits_before: int = gs.credits
	var xp_before: int = gs.lab_xp
	# Step (a): seat a whole Orbital Silk-Spinner spool in relay dish.
	gs.relay_slotted = true
	gs.slotted_spool_species = SILK_SPINNER
	gs.slotted_spool_damaged = false
	# Step (b): damaged Crystal Weaver spools do NOT count; need 3 whole ones.
	gs._add_spool(CRYSTAL_WEAVER, true)
	gs._add_spool(CRYSTAL_WEAVER, false)
	gs._add_spool(CRYSTAL_WEAVER, false)
	var none: Array[String] = []
	gs.update_quests(none, false)
	if gs.whole_spools_of(CRYSTAL_WEAVER) != 2 or QuestEngine.is_done(gs, "intrinsic_silk"):
		return "2 whole + 1 damaged Crystal Weaver spools must not finish step (b)."
	gs._add_spool(CRYSTAL_WEAVER, false)
	# Step (c): 5 traceable on-time calibrations by player's own hand after quest opens.
	for i: int in 4:
		gs.cal_log.append(_cal_row(gs.STEERING_ID, 10))
	gs.update_quests(none, false)
	if QuestEngine.is_done(gs, "intrinsic_silk") or gs.intrinsic_standard:
		return "4 calibrations must not complete intrinsic_silk."
	# Manager or robot calibration must NOT count for step (c).
	gs.cal_log.append(_cal_row(gs.STEERING_ID, 10, { "performed_by": GameStateScript.MANAGER_ID }))
	gs.cal_log.append(_cal_row(gs.STEERING_ID, 10, { "performed_by": "R-01", "programmed_by": HOST }))
	gs.update_quests(none, false)
	if QuestEngine.is_done(gs, "intrinsic_silk"):
		return "Manager or robot calibrations must not count for intrinsic_silk."
	# 5th valid calibration finishes the quest and pays once.
	gs.cal_log.append(_cal_row(gs.STEERING_ID, 10))
	gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, "intrinsic_silk") or not gs.intrinsic_standard:
		return "5th valid calibration must complete intrinsic_silk and set intrinsic_standard."
	if gs.credits != credits_before + 800 or gs.lab_xp != xp_before + 2000:
		return "Expected +800 CR and +2000 lab XP, got +%d CR / +%d XP." % [gs.credits - credits_before, gs.lab_xp - xp_before]
	# Second update must not pay twice.
	gs.update_quests(none, false)
	if gs.credits != credits_before + 800 or gs.lab_xp != xp_before + 2000:
		return "intrinsic_silk must pay only once."
	# Traceability chain now ends at the conservatory.
	var after_unit: Dictionary = gs.traceability_chain(gs.STEERING_ID)
	var after_std: Dictionary = gs.traceability_chain("rotary_table")
	if not str(after_unit["text"]).ends_with("← " + GameStateScript.INTRINSIC_CHAIN_ROOT):
		return "Unit chain must end at conservatory: '%s'" % str(after_unit["text"])
	if not str(after_std["text"]).ends_with("← " + GameStateScript.INTRINSIC_CHAIN_ROOT):
		return "Standard chain must end at conservatory: '%s'" % str(after_std["text"])
	return ""


func test_save_load_old_save_validation_and_coop_sync() -> String:
	return _run(_check_save_and_sync)


func _check_save_and_sync(gs: GameStateScript) -> String:
	gs.master_audit_passed = true
	gs.intrinsic_standard = true
	gs.last_interlock_override_day = 9
	gs.master_audit = { "status": "passed", "start_day": 11, "days_done": 2, "cooldown_until": 0, "passed_day": 12 }
	var saved: Dictionary = gs.farm_to_dict()
	# Round-trip save/load.
	var loaded: GameStateScript = _clean_farm()
	var err: String = loaded.farm_from_dict(saved)
	if err != "":
		loaded.free()
		return "Save round-trip failed: %s" % err
	if not loaded.master_audit_passed or not loaded.intrinsic_standard \
			or loaded.last_interlock_override_day != 9 or int(loaded.master_audit.get("passed_day", -1)) != 12:
		loaded.free()
		return "Loaded state did not preserve master audit / intrinsic fields."
	# Old-save case: erase the 4 new SAVED_LATER keys -> loads with defaults.
	var old: Dictionary = saved.duplicate(true)
	for k: String in ["master_audit_passed", "master_audit", "last_interlock_override_day", "intrinsic_standard"]:
		old.erase(k)
	var old_loaded: GameStateScript = _clean_farm()
	var old_err: String = old_loaded.farm_from_dict(old)
	var old_ok: bool = old_err == "" and not old_loaded.master_audit_passed and not old_loaded.intrinsic_standard \
			and old_loaded.last_interlock_override_day == -1 and old_loaded.master_audit.is_empty()
	old_loaded.free()
	if not old_ok:
		loaded.free()
		return "Old save without new keys failed to load defaults: '%s'" % old_err
	# Validator refuses wrong types.
	var bad_cases: Array = [
		["master_audit_passed", "yes"],
		["intrinsic_standard", 1],
		["last_interlock_override_day", -5],
		["master_audit", { "status": "bogus" }],
		["master_audit", { "status": "booked", "days_done": 99 }],
	]
	for pair: Array in bad_cases:
		var bad: Dictionary = saved.duplicate(true)
		bad[pair[0]] = pair[1]
		if loaded.farm_dict_problem(bad) == "":
			loaded.free()
			return "Validator must refuse bad %s = %s." % [pair[0], str(pair[1])]
	loaded.free()
	# Guest sync (FarmSync.update) and late joiner (FarmSync.join).
	var bytes: PackedByteArray = FarmSync.capture(gs)
	if bytes.is_empty():
		return "FarmSync.capture returned empty bytes."
	var guest: GameStateScript = _clean_farm()
	var late: GameStateScript = _clean_farm()
	FarmCommands.guest = true
	var upd_err: String = FarmSync.update(bytes, guest)
	var join_err: String = FarmSync.join(bytes, late)
	FarmCommands.guest = false
	var sync_ok: bool = upd_err == "" and join_err == "" \
			and guest.master_audit_passed and guest.intrinsic_standard \
			and late.master_audit_passed and late.intrinsic_standard \
			and str(guest.traceability_chain(guest.STEERING_ID)["text"]).ends_with(GameStateScript.INTRINSIC_CHAIN_ROOT) \
			and str(late.traceability_chain(late.STEERING_ID)["text"]).ends_with(GameStateScript.INTRINSIC_CHAIN_ROOT)
	guest.free()
	late.free()
	if not sync_ok:
		return "Guest sync or late joiner failed: upd='%s' join='%s'" % [upd_err, join_err]
	return ""


func test_bench_master_audit_button_shows_gate_note() -> String:
	var saved_xp: int = GameState.lab_xp
	var saved_cred: int = GameState.credibility
	var saved_passed: bool = GameState.master_audit_passed
	var saved_ma: Dictionary = GameState.master_audit.duplicate(true)
	var saved_kept: Array[String] = GameState.lab_gates_kept.duplicate()
	GameState.lab_gates_kept.clear()
	GameState.master_audit_passed = false
	GameState.master_audit = {}
	GameState.lab_xp = GameState.xp_for_level(10)
	GameState.credibility = 80
	var bench: CalBenchUI = BENCH_SCENE.instantiate() as CalBenchUI
	(Engine.get_main_loop() as SceneTree).root.add_child(bench)
	bench.open(GameState.STEERING_ID)
	var problem: String = ""
	if not bench._master_audit_button.visible or not bench._master_audit_button.disabled \
			or not bench._master_audit_button.text.contains("needs lab level 52"):
		problem = "Shut master audit button must show gate note: visible=%s disabled=%s text='%s'" % [
			bench._master_audit_button.visible, bench._master_audit_button.disabled, bench._master_audit_button.text]
	GameState.lab_xp = GameState.xp_for_level(52)
	bench._show_master_audit()
	if problem == "" and (not bench._master_audit_button.visible or bench._master_audit_button.disabled):
		problem = "At lab 52 + Accredited, master audit button must be enabled: text='%s'" % bench._master_audit_button.text
	bench.get_parent().remove_child(bench)
	bench.free()
	GameState.lab_xp = saved_xp
	GameState.credibility = saved_cred
	GameState.master_audit_passed = saved_passed
	GameState.master_audit = saved_ma
	GameState.lab_gates_kept.assign(saved_kept)
	return problem


func test_oirm_standard_and_excused_overdue_unit_still_pass() -> String:
	return _run(_check_oirm_standard_excused)


func _check_oirm_standard_excused(gs: GameStateScript) -> String:
	# Send rotary_table to OIRM on day 10; steering falls due on day 11 while its standard is away.
	var sent: Dictionary = gs.send_to_oirm("rotary_table")
	if not bool(sent.get("ok", false)):
		return "send_to_oirm failed: %s" % [sent]
	gs.get_sensor(gs.STEERING_ID).cal_due_day = 11
	var err: String = gs.ask_master_audit(HOST)
	if err != "":
		return "ask_master_audit failed: %s" % err
	_advance_morning(gs, 11)
	if str(gs.master_audit.get("status", "")) != "running":
		return "Morning 1 must pass when standard is at OIRM and its overdue unit is excused: %s / %s" % [gs.master_audit, gs.phone_log]
	_advance_morning(gs, 12)
	if not gs.master_audit_passed:
		return "Morning 2 must pass with standard at OIRM and overdue unit excused: %s / %s" % [gs.master_audit, gs.phone_log]
	return ""


func test_lab_99_gold_border_excludes_oirm_quests_keeps_other_lab_quests() -> String:
	return _run(_check_lab_99_gold_border)


func _check_lab_99_gold_border(gs: GameStateScript) -> String:
	gs.lab_xp = gs.xp_for_level(99)
	gs.tier1_unlocked = true
	gs.update_quests()
	var err: String = gs.ask_master_audit(HOST)
	if err != "":
		return "ask_master_audit failed: %s" % err
	_advance_morning(gs, 11)
	_advance_morning(gs, 12)
	if not gs.master_audit_passed:
		return "Master audit must pass at lab 99."
	if not QuestEngine.is_done(gs, "master_audit") or not QuestEngine.is_done(gs, "every_sticker_counts"):
		return "Both master_audit and every_sticker_counts must be done."
	if bool(gs.quest_state["master_audit"].get("gold_border", false)):
		return "OIRM master_audit quest entry must not be stamped with gold_border at lab 99."
	if not bool(gs.quest_state["every_sticker_counts"].get("gold_border", false)):
		return "Non-OIRM farm lab quest (every_sticker_counts) must still get gold_border at lab 99."
	var certs: Array[Dictionary] = CertificateWall.earned_from(gs)
	var master_entry: Dictionary = {}
	var vance_entry: Dictionary = {}
	for c: Dictionary in certs:
		if str(c.get("id", "")) in ["quest_master_audit", "master_audit"]:
			master_entry = c
		elif str(c.get("id", "")) == "quest_every_sticker_counts":
			vance_entry = c
	if master_entry.is_empty() or bool(master_entry.get("gold_border", false)):
		return "Master audit wall entry at lab 99 must exist and have no gold_border: %s" % [master_entry]
	if vance_entry.is_empty() or not bool(vance_entry.get("gold_border", false)):
		return "Non-OIRM lab quest wall entry at lab 99 must have gold_border: %s" % [vance_entry]
	return ""


func test_booking_refused_for_active_and_recent_interlock_override() -> String:
	return _run(_check_interlock_booking_refusal)


func _check_interlock_booking_refusal(gs: GameStateScript) -> String:
	var sensor_id: String = _add_released_robot(gs, "R-01")
	var rs: DriftingSensor = gs.get_sensor(sensor_id)
	rs.error = rs.mpe * 2.0
	gs.robots["R-01"]["holding"] = true
	var oirm_emits: Array[int] = [0]
	gs.oirm_changed.connect(func() -> void: oirm_emits[0] += 1)
	var ov_err: String = gs.set_interlock_override("R-01", true, HOST)
	if ov_err != "":
		return "set_interlock_override(true) failed: %s" % ov_err
	if oirm_emits[0] < 1:
		return "set_interlock_override must emit oirm_changed when last_interlock_override_day changes."
	var while_active: String = gs.ask_master_audit(HOST)
	if while_active == "" or not while_active.to_lower().contains("interlock"):
		return "Must refuse booking while interlock override is active: '%s'" % while_active
	# Arm the interlock; override is no longer active, but day 10 is within the 7 d lookback (until day 17).
	var arm_err: String = gs.set_interlock_override("R-01", false, HOST)
	if arm_err != "":
		return "set_interlock_override(false) failed: %s" % arm_err
	var within_lookback: String = gs.ask_master_audit(HOST)
	var expected: String = "An interlock override was logged on day 10; OIRM will see it until day 17."
	if within_lookback != expected:
		return "Expected '%s', got '%s'" % [expected, within_lookback]
	# Advance to day 17 and let Vance's audit clear override_logged; booking must then succeed.
	rs.error = 0.0
	gs.robots["R-01"]["holding"] = false
	gs._interlock_findings()
	GameClock.elapsed_days = 16.0  # day 17
	var after_window: String = gs.ask_master_audit(HOST)
	if after_window != "":
		return "Booking on day 17 after lookback cleared must succeed, got '%s'" % after_window
	return ""


func test_robot_suspect_skips_already_suspect_and_jig3_requires_released() -> String:
	return _run(_check_robot_suspect_and_jig3_state)


func _check_robot_suspect_and_jig3_state(gs: GameStateScript) -> String:
	var sensor_id: String = _add_released_robot(gs, "R-01")
	# One row already marked suspect (must be skipped) and one fresh traceable row (must be listed).
	gs.cal_log.append(_cal_row(gs.STEERING_ID, 10, {
		"performed_by": "R-01",
		"programmed_by": HOST,
		"suspect": true,
	}))
	gs.cal_log.append(_cal_row(gs.SOIL_PROBE_ID, 10, {
		"performed_by": "R-01",
		"programmed_by": HOST,
		"suspect": false,
	}))
	var listed: PackedStringArray = gs._robot_suspect_cals_since_good("R-01", sensor_id)
	if listed.size() != 1 or not listed[0].contains("Soil") or listed[0].contains("Steering"):
		return "_robot_suspect_cals_since_good must skip already-suspect rows: %s" % [listed]
	# A robot whose state is not "released" must not receive Jig-3 credit.
	var rs: DriftingSensor = gs.get_sensor(sensor_id)
	rs.error = rs.mpe * 2.0
	gs.robots["R-01"]["state"] = "commissioning"
	# Commissioning sensors are excluded from unit_ids(), so check non-released state handling directly
	# by verifying that if state != "released", Jig-3 self-quarantine is not credited.
	gs.ask_master_audit(HOST)
	_advance_morning(gs, 11)
	if _has_line(gs, "JIG-3 SELF-QUARANTINE"):
		return "Non-released robot must not receive Jig-3 self-quarantine credit: %s" % [gs.phone_log]
	return ""


func test_quest_data_validation_refuses_unknown_species() -> String:
	var bad_silk: Dictionary = {
		"id": "bad_silk_q", "kind": "lab", "giver": "oirm", "title": "Bad Silk", "scope": "farm",
		"steps": [{ "id": "s1", "text": "Hold silk.", "check": "silk_stock", "species": "no_such_spider", "at_least": 1 }],
	}
	if QuestEngine.data_problem(bad_silk) == "":
		return "QuestEngine.data_problem must refuse unknown species in silk_stock."
	var bad_relay: Dictionary = {
		"id": "bad_relay_q", "kind": "lab", "giver": "oirm", "title": "Bad Relay", "scope": "farm",
		"steps": [{ "id": "s1", "text": "Seat spool.", "check": "relay_spool", "species": "no_such_spider" }],
	}
	if QuestEngine.data_problem(bad_relay) == "":
		return "QuestEngine.data_problem must refuse unknown species in relay_spool."
	var good_both: Dictionary = {
		"id": "good_silk_q", "kind": "lab", "giver": "oirm", "title": "Good Silk", "scope": "farm",
		"steps": [
			{ "id": "s1", "text": "Hold silk.", "check": "silk_stock", "species": "crystal_weaver", "at_least": 3 },
			{ "id": "s2", "text": "Seat spool.", "check": "relay_spool", "species": "orbital_silk_spinner" },
		],
	}
	var good_err: String = QuestEngine.data_problem(good_both)
	if good_err != "":
		return "QuestEngine.data_problem must accept known species, got '%s'" % good_err
	return ""


func test_booking_between_midnight_and_0600_runs_coming_morning() -> String:
	return _run(_check_after_midnight_booking)


func _check_after_midnight_booking(gs: GameStateScript) -> String:
	# Day 10 at 02:00 (between 00:00 and 06:00): GameClock day index is still 10;
	# the coming 06:00 morning rolls the day index to 11.
	GameClock.elapsed_days = GameClock.elapsed_at_hour(10, 2.0)
	if GameClock.get_day_index() != 10 or absf(GameClock.get_hour() - 2.0) > 0.01:
		return "Setup: expected day 10 at 02:00, got day %d hour %.2f." % [GameClock.get_day_index(), GameClock.get_hour()]
	var err: String = gs.ask_master_audit(HOST)
	if err != "":
		return "ask_master_audit at 02:00 failed: %s" % err
	if int(gs.master_audit.get("start_day", 0)) != 11:
		return "Booking at 02:00 on day 10 must target coming 06:00 morning (day 11), got %s." % [gs.master_audit]
	var cb: Callable = gs._on_day_started
	GameClock.day_started.connect(cb)
	GameClock.advance(4.0 / 24.0)  # 02:00 -> 06:00 (same coming morning)
	GameClock.day_started.disconnect(cb)
	if str(gs.master_audit.get("status", "")) != "running" or int(gs.master_audit.get("days_done", 0)) != 1:
		return "Master audit must run on that same coming 06:00 morning: %s" % [gs.master_audit]
	return ""


func test_master_audit_dict_problem_refuses_inconsistent_states() -> String:
	return _run(_check_inconsistent_master_audit_dicts)


func _check_inconsistent_master_audit_dicts(gs: GameStateScript) -> String:
	var base: Dictionary = gs.farm_to_dict()
	var cases: Array = [
		["status passed with flag false", false, { "status": "passed", "start_day": 11, "days_done": 2, "cooldown_until": 0, "passed_day": 12 }],
		["flag true with empty dict", true, {}],
		["flag true with booked dict", true, { "status": "booked", "start_day": 11, "days_done": 0, "cooldown_until": 0, "passed_day": -1 }],
		["booked without start_day", false, { "status": "booked", "days_done": 0, "cooldown_until": 0, "passed_day": -1 }],
		["running without start_day", false, { "status": "running", "days_done": 1, "cooldown_until": 0, "passed_day": -1 }],
	]
	for item: Array in cases:
		var d: Dictionary = base.duplicate(true)
		d["master_audit_passed"] = item[1]
		d["master_audit"] = item[2]
		if gs.farm_dict_problem(d) == "":
			return "farm_dict_problem must refuse inconsistent state: %s." % str(item[0])
	return ""


func test_guest_path_through_farm_commands() -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var saved_guest: bool = FarmCommands.guest
	var saved_remote: Callable = FarmCommands.remote
	var saved_state: Node = FarmCommands.state
	GameClock.elapsed_days = 9.0
	CoopSession.players.clear()
	FarmCommands.guest = false
	var gs: GameStateScript = _clean_farm()
	FarmCommands.state = gs
	var problem: String = ""
	# 1. Guest calling ask_master_audit directly is refused.
	FarmCommands.guest = true
	var direct_err: String = gs.ask_master_audit(GUEST)
	if direct_err == "" or not gs.master_audit.is_empty():
		problem = "Direct ask_master_audit on guest must be refused: '%s'" % direct_err
	# 2. Guest calling FarmCommands.request routes to remote host callable, not local state.
	if problem == "":
		var routed: Array = []
		FarmCommands.remote = func(action: StringName, arguments: Array) -> Variant:
			routed.append([action, arguments])
			return ""
		var req_res: Variant = await FarmCommands.request(&"ask_master_audit", [])
		if str(req_res) != "" or routed.size() != 1 or routed[0][0] != &"ask_master_audit" or not gs.master_audit.is_empty():
			problem = "Guest FarmCommands.request must route to host without mutating guest state: res='%s' routed=%s" % [str(req_res), str(routed)]
	# 3. Host executing a remote sender's ask_master_audit via FarmCommands.execute books it on host.
	if problem == "":
		FarmCommands.guest = false
		FarmCommands.remote = Callable()
		var host_res: Variant = FarmCommands.execute(GUEST, &"ask_master_audit", [])
		if str(host_res) != "" or str(gs.master_audit.get("status", "")) != "booked":
			problem = "Host FarmCommands.execute(GUEST, ask_master_audit) must book on host: res='%s' ma=%s" % [str(host_res), str(gs.master_audit)]
	FarmCommands.state = saved_state
	FarmCommands.remote = saved_remote
	FarmCommands.guest = saved_guest
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	gs.free()
	return problem


func test_calibrations_before_intrinsic_silk_opens_do_not_count() -> String:
	return _run(_check_prior_cals_ignored)


func _check_prior_cals_ignored(gs: GameStateScript) -> String:
	# Perform 5 valid player calibrations BEFORE intrinsic_silk opens.
	for i: int in 5:
		gs.cal_log.append(_cal_row(gs.STEERING_ID, 10))
	gs.master_audit_passed = true
	gs.lab_xp = gs.xp_for_level(56)
	gs.update_quests()
	if not gs.quest_state.has("intrinsic_silk"):
		return "intrinsic_silk must open at lab 56 after master_audit_passed."
	# Finish the two silk steps.
	gs.relay_slotted = true
	gs.slotted_spool_species = SILK_SPINNER
	gs.slotted_spool_damaged = false
	for i: int in 3:
		gs._add_spool(CRYSTAL_WEAVER, false)
	var none: Array[String] = []
	gs.update_quests(none, false)
	if QuestEngine.is_done(gs, "intrinsic_silk"):
		return "Calibrations made before intrinsic_silk opened must not count toward it."
	# 4 new calibrations after open: still not done.
	for i: int in 4:
		gs.cal_log.append(_cal_row(gs.STEERING_ID, 10))
	gs.update_quests(none, false)
	if QuestEngine.is_done(gs, "intrinsic_silk"):
		return "4 calibrations after open must not finish intrinsic_silk."
	# 5th new calibration after open completes it.
	gs.cal_log.append(_cal_row(gs.STEERING_ID, 10))
	gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, "intrinsic_silk") or not gs.intrinsic_standard:
		return "5th calibration after open must complete intrinsic_silk."
	return ""


func test_master_audit_phone_report_reaches_guests() -> String:
	return _run(_check_phone_report_sync)


func _check_phone_report_sync(gs: GameStateScript) -> String:
	var guest: GameStateScript = _clean_farm()
	var received: Array[String] = []
	guest.phone_message.connect(func(line: String) -> void: received.append(line))
	# Initial baseline sync so guest's phone_count matches host before audit.
	var base_bytes: PackedByteArray = FarmSync.capture(gs)
	FarmCommands.guest = true
	var join_err: String = FarmSync.join(base_bytes, guest)
	FarmCommands.guest = false
	if join_err != "":
		guest.free()
		return "Initial guest join failed: %s" % join_err
	received.clear()
	# Host books and runs morning 1, then syncs to guest.
	gs.ask_master_audit(HOST)
	_advance_morning(gs, 11)
	var update_bytes: PackedByteArray = FarmSync.capture(gs)
	FarmCommands.guest = true
	var upd_err: String = FarmSync.update(update_bytes, guest)
	FarmCommands.guest = false
	var saw_report: bool = false
	for line: String in received:
		if line.contains("OIRM MASTER AUDIT"):
			saw_report = true
			break
	var in_log: bool = _has_line(guest, "OIRM MASTER AUDIT")
	guest.free()
	if upd_err != "" or not saw_report or not in_log:
		return "Master audit phone report must reach guests via phone_message and phone_log: upd='%s' received=%s" % [upd_err, str(received)]
	return ""


func test_vance_daily_audit_unchanged_on_master_audit_cadence_day() -> String:
	return _run(_check_vance_audit_on_cadence_day)


func _check_vance_audit_on_cadence_day(gs: GameStateScript) -> String:
	# Book on day 14 so start_day is day 15 (default cadence_days = 5 -> 15 % 5 == 0).
	GameClock.elapsed_days = 13.0  # day 14
	for id: String in gs.unit_ids() + gs.standard_ids():
		gs.get_sensor(id).cal_due_day = 40
		if gs.certificates.has(id):
			gs.certificates[id]["due_day"] = 40
	var err: String = gs.ask_master_audit(HOST)
	if err != "":
		return "Booking on day 14 failed: %s" % err
	_advance_morning(gs, 15)
	if gs.audit_log.size() != 1 or int(gs.audit_log[0].get("day", 0)) != 15 or not gs.drop_pod_present:
		return "Vance's cadence audit must still run unchanged on day 15: log=%s pod=%s" % [gs.audit_log, gs.drop_pod_present]
	if not _has_line(gs, "AUDIT DAY 15") or not _has_line(gs, "OIRM MASTER AUDIT"):
		return "Both Vance's audit and OIRM master audit lines must appear on day 15: %s" % [gs.phone_log]
	if str(gs.master_audit.get("status", "")) != "running" or int(gs.master_audit.get("days_done", 0)) != 1:
		return "Master audit morning 1 must also complete on day 15: %s" % [gs.master_audit]
	return ""


func test_intrinsic_silk_completed_step_persists_after_spools_sold() -> String:
	return _run(_check_silk_step_persists_after_sale)


func _check_silk_step_persists_after_sale(gs: GameStateScript) -> String:
	# QuestEngine records completed step ids in entry["steps_done"] and skips them on
	# subsequent updates; selling/removing spools after crystal_silk completes does not
	# un-complete that step, so finishing the remaining steps still completes the quest.
	gs.master_audit_passed = true
	gs.lab_xp = gs.xp_for_level(56)
	gs.update_quests()
	for i: int in 3:
		gs._add_spool(CRYSTAL_WEAVER, false)
	var none: Array[String] = []
	gs.update_quests(none, false)
	var done_steps: Array = gs.quest_state["intrinsic_silk"]["steps_done"]
	if not ("crystal_silk" in done_steps):
		return "crystal_silk step must be marked done once 3 whole Crystal Weaver spools are held."
	# Remove/sell all 3 spools from stock.
	for i: int in 3:
		gs._take_spool(false)
	if gs.whole_spools_of(CRYSTAL_WEAVER) != 0:
		return "Setup: expected 0 Crystal Weaver spools left after removal."
	# Finish the other two steps and verify the quest still completes consistently.
	gs.relay_slotted = true
	gs.slotted_spool_species = SILK_SPINNER
	gs.slotted_spool_damaged = false
	for i: int in 5:
		gs.cal_log.append(_cal_row(gs.STEERING_ID, 10))
	gs.update_quests(none, false)
	if not QuestEngine.is_done(gs, "intrinsic_silk") or not gs.intrinsic_standard:
		return "intrinsic_silk must still complete after crystal_silk was recorded done and spools were later sold."
	return ""
