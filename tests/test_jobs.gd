extends RefCounted
## Paid calibration jobs (Ryan, 2026-11-22): a phone job board opens at
## Trusted, Accredited adds tighter-tolerance jobs, a job needs an owned
## standard of its discipline, and late or untraceable work pays less and
## costs credibility. Numbers come from data/economy.json ([PLACEHOLDER]);
## the tests read them. Each test starts the clock at the first morning and
## puts it back after; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state(points: int = 30) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.reset_credibility()
	gs.credibility = points
	gs.credits = 0
	# A large lab with a large area for every discipline, so the lab's own
	# limits (tests/test_lab.gd) stay out of these tests.
	gs.lab_size = gs.lab_sizes().size() - 1
	for discipline: Variant in gs.job_disciplines():
		gs.lab_areas[str(discipline)] = gs.lab_area_spaces_needed("large")
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


func _template(gs: GameStateScript, id: String) -> Dictionary:
	for template: Dictionary in gs._job_templates():
		if template["id"] == id:
			return template.duplicate(true)
	return {}


func _cfg(gs: GameStateScript, key: String) -> int:
	return int(gs._jobs_number(key, 0.0))


## Puts one job on the board and accepts it; returns its job id or "".
func _take(gs: GameStateScript, id: String) -> String:
	gs.job_board.clear()
	gs.job_board.append(_template(gs, id))
	if gs.accept_job(0) != "":
		return ""
	return str(gs.active_jobs[-1]["job_id"])


func test_board_closed_until_trusted() -> String:
	var gs: GameStateScript = _make_state(10)
	gs.refresh_job_board(1)
	var empty: bool = gs.job_board.is_empty()
	var note: String = gs.job_board_note()
	gs.credibility = 30
	gs.refresh_job_board(1)
	var size: int = gs.job_board.size()
	var expected: int = _cfg(gs, "board_size")
	_done(gs)
	if not empty or note != "JOB BOARD opens at TRUSTED.":
		return "A Provisional lab must see no jobs, note was '%s'." % note
	if size != expected:
		return "A Trusted lab must see %d jobs, saw %d." % [expected, size]
	return ""


func test_accredited_adds_better_paying_jobs() -> String:
	var gs: GameStateScript = _make_state(30)
	var trusted_best: int = 0
	var accredited_best: int = 0
	for day: int in range(1, 13):
		gs.credibility = 30
		gs.refresh_job_board(day)
		for job: Dictionary in gs.job_board:
			if job["min_band"] != "Trusted":
				_done(gs)
				return "A Trusted lab was offered a %s job." % job["min_band"]
			trusted_best = maxi(trusted_best, int(job["pay"]))
		gs.credibility = 60
		gs.refresh_job_board(day)
		for job: Dictionary in gs.job_board:
			if job["min_band"] == "Accredited":
				accredited_best = maxi(accredited_best, int(job["pay"]))
	_done(gs)
	if accredited_best <= trusted_best:
		return "Accredited jobs must pay more than Trusted ones (%d vs %d)." % [accredited_best, trusted_best]
	return ""


func test_job_needs_a_standard_of_its_discipline() -> String:
	var gs: GameStateScript = _make_state()
	gs.owned_standards.erase("reference_gauge")
	gs.job_board.append(_template(gs, "kestrel_tire_gauge"))
	var refused: String = gs.accept_job(0)
	gs.owned_standards["reference_gauge"] = 0
	# As bought from Bram: with the maker's certificate, in date.
	gs.get_sensor("reference_gauge").cal_due_day = GameClock.get_day_index() + 5
	gs._issue_certificate("reference_gauge", GameClock.get_day_index(), null, 0.0, false, "the maker", "MKR")
	var accepted: String = gs.accept_job(0)
	gs.credibility = 60
	var tight: Dictionary = _template(gs, "dome1_cabin_transducer")
	var tight_problem: String = gs.job_accept_problem(tight)
	_done(gs)
	if refused == "":
		return "A pressure job must be refused without a pressure standard."
	if accepted != "":
		return "With the WD-1 owned the job must be accepted, got '%s'." % accepted
	if tight_problem.find("Tier 3") < 0:
		return "The tight pressure job must ask for a Tier 3 standard, got '%s'." % tight_problem
	return ""


func test_clean_job_pays_in_full_with_a_bonus() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "lin_soil_probe")
	var result: Dictionary = gs.complete_job(job_id)
	var pay: int = int(_template(gs, "lin_soil_probe")["pay"])
	var bonus: int = _cfg(gs, "clean_job_points")
	var points: int = gs.credibility
	var credits: int = gs.credits
	var left: int = gs.active_jobs.size()
	_done(gs)
	if not result.get("ok", false) or not result["on_time"] or not result["traceable"]:
		return "An on-time job with an in-date standard must be clean, got %s." % result
	if credits != pay or points != 30 + bonus:
		return "A clean job must pay %d CR and add %d credibility, got %d CR and %d." % [pay, bonus, credits, points - 30]
	if left != 0:
		return "A finished job must leave the active list."
	return ""


func test_late_is_judged_when_the_bench_work_ends() -> String:
	var gs: GameStateScript = _make_state()
	# Accepted on day 2, so the late case's morning is not an audit day.
	GameClock.elapsed_days = 1.0
	var job_id: String = _take(gs, "lin_soil_probe")
	var due: int = int(gs.active_job(job_id)["due_day"])
	# Midday on the due day: on time.
	GameClock.elapsed_days = float(due - 1) + 0.5
	var midday: Dictionary = gs.complete_job(job_id)
	# Started 10 min before 06:00 at the end of the due day, it ends late.
	var late_id: String = _take(gs, "lin_soil_probe")
	gs.active_job(late_id)["due_day"] = due
	GameClock.elapsed_days = float(due) - 10.0 / 1440.0
	var credits_before: int = gs.credits
	var points_before: int = gs.credibility
	var late: Dictionary = gs.complete_job(late_id)
	var paid: int = gs.credits - credits_before
	var moved: int = gs.credibility - points_before
	var pay: int = int(_template(gs, "lin_soil_probe")["pay"])
	var cut: int = _cfg(gs, "late_pay_cut_pct")
	var points: int = _cfg(gs, "late_job_points")
	_done(gs)
	if not midday.get("on_time", false):
		return "A job finished on its due day must be on time, got %s." % midday
	if late.get("on_time", true) or int(late["day"]) != due + 1:
		return "Work that ends after the due day must be late, got %s." % late
	if paid != roundi(pay * (100 - cut) / 100.0) or int(late["pay"]) != paid:
		return "A late job must pay %d %% less, paid %d of %d CR." % [cut, paid, pay]
	if moved != points:
		return "A late job must cost %d credibility, moved %d." % [points, moved]
	return ""


func test_late_and_untraceable_cuts_multiply() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "relay_inclinometer")
	var due: int = int(gs.active_job(job_id)["due_day"])
	GameClock.elapsed_days = float(due) + 0.25
	gs.get_sensor("rotary_table").cal_due_day = GameClock.get_day_index() - 1
	var result: Dictionary = gs.complete_job(job_id)
	var pay: float = float(_template(gs, "relay_inclinometer")["pay"])
	var keep: float = (100 - _cfg(gs, "late_pay_cut_pct")) / 100.0 * (100 - _cfg(gs, "untraceable_pay_cut_pct")) / 100.0
	var points: int = _cfg(gs, "late_job_points") + _cfg(gs, "untraceable_job_points")
	var credits: int = gs.credits
	var credibility: int = gs.credibility
	var text: String = gs.job_result_text(result)
	_done(gs)
	if credits != roundi(pay * keep) or credibility != 30 + points:
		return "Late and untraceable must pay %d CR and cost %d, got %d CR, %d." % [
			roundi(pay * keep), points, credits, credibility - 30]
	if text.find("LATE and NOT TRACEABLE") < 0:
		return "The phone line must name both problems, got '%s'." % text
	return ""


func test_work_that_would_end_after_the_cutoff_is_refused() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "lin_soil_probe")
	var due: int = int(gs.active_job(job_id)["due_day"])
	var grace: int = _cfg(gs, "late_grace_days")
	GameClock.elapsed_days = float(due + grace) - 10.0 / 1440.0
	var result: Dictionary = gs.complete_job(job_id)
	var still: bool = not gs.active_job(job_id).is_empty()
	_done(gs)
	if result.get("ok", true) or str(result.get("reason", "")).find("Not enough time") < 0:
		return "Work ending after the customer cancels must be refused, got %s." % result
	if not still:
		return "A refused job must stay active."
	return ""


func test_score_cap_is_what_the_result_reports() -> String:
	var gs: GameStateScript = _make_state(99)
	var job_id: String = _take(gs, "lin_soil_probe")
	var result: Dictionary = gs.complete_job(job_id)
	var text: String = gs.job_result_text(result)
	_done(gs)
	if int(result["points"]) != 1 or text.find("credibility +1") < 0:
		return "At 99 points a clean job must report +1, got '%s'." % text
	return ""


func test_overdue_standard_makes_job_untraceable() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "relay_inclinometer")
	gs.get_sensor("rotary_table").cal_due_day = GameClock.get_day_index() - 1
	var result: Dictionary = gs.complete_job(job_id)
	var pay: int = int(_template(gs, "relay_inclinometer")["pay"])
	var cut: int = _cfg(gs, "untraceable_pay_cut_pct")
	var points: int = _cfg(gs, "untraceable_job_points")
	var credibility: int = gs.credibility
	var credits: int = gs.credits
	var text: String = gs.job_result_text(result)
	_done(gs)
	if credits != int(result.get("pay", -1)):
		return "The credits paid must match the result, %d vs %s." % [credits, result.get("pay")]
	if result.get("traceable", true):
		return "A job against an overdue standard must not be traceable."
	if int(result["pay"]) != roundi(pay * (100 - cut) / 100.0) or credibility != 30 + points:
		return "Untraceable work must pay %d %% less and cost %d credibility, got %d CR, %d." % [
			cut, points, result["pay"], credibility]
	if text.find("NOT TRACEABLE") < 0 or text.find("−") < 0:
		return "The phone line must say NOT TRACEABLE with an SP 811 minus sign, got '%s'." % text
	return ""


func test_standard_at_oirm_blocks_the_job() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "relay_inclinometer")
	gs.at_oirm["rotary_table"] = GameClock.get_day_index() + 3
	var result: Dictionary = gs.complete_job(job_id)
	var still: bool = not gs.active_job(job_id).is_empty()
	_done(gs)
	if result.get("ok", true) or str(result.get("reason", "")).find("OIRM") < 0:
		return "A job must wait while its standard is at OIRM, got %s." % result
	if not still:
		return "A refused job must stay active."
	return ""


func test_abandoned_job_is_cancelled_after_grace() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "lin_soil_probe")
	var due: int = int(gs.active_job(job_id)["due_day"])
	var grace: int = _cfg(gs, "late_grace_days")
	gs._expire_jobs(due + grace)
	var kept: bool = not gs.active_job(job_id).is_empty()
	gs._expire_jobs(due + grace + 1)
	var gone: bool = gs.active_job(job_id).is_empty()
	var credibility: int = gs.credibility
	var points: int = _cfg(gs, "abandoned_job_points")
	_done(gs)
	if not kept or not gone:
		return "A job must stay through its grace days and be cancelled after."
	if credibility != 30 + points:
		return "A cancelled job must cost %d credibility, now %d." % [points, credibility]
	return ""


func test_accepted_offer_leaves_the_board_and_caps_active() -> String:
	var gs: GameStateScript = _make_state()
	var max_active: int = gs.lab_space("soil moisture")
	gs.refresh_job_board(1)
	var size: int = gs.job_board.size()
	var first_id: String = str(gs.job_board[0]["id"])
	var problem: String = gs.accept_job(0)
	var left: int = gs.job_board.size()
	var still_offered: bool = false
	for job: Dictionary in gs.job_board:
		still_offered = still_offered or job["id"] == first_id
	gs.active_jobs.clear()
	gs.job_board.clear()
	for i: int in max_active + 1:
		gs.job_board.append(_template(gs, "lin_soil_probe"))
	var refused_early: String = ""
	for i: int in max_active:
		var why: String = gs.accept_job(0)
		if why != "":
			refused_early = why
	var over: String = gs.accept_job(0)
	_done(gs)
	if refused_early != "":
		return "Jobs up to the cap must be accepted, got '%s'." % refused_early
	if problem != "" or left != size - 1 or still_offered:
		return "An accepted offer must leave the board, problem '%s', %d -> %d." % [problem, size, left]
	if over.find("area is full") < 0:
		return "No more than %d jobs may be active, got '%s'." % [max_active, over]
	return ""


func test_job_taken_today_is_not_reposted_on_promotion() -> String:
	var gs: GameStateScript = _make_state(58)
	var day: int = GameClock.get_day_index()
	gs.refresh_job_board(day)
	var taken_id: String = str(gs.job_board[0]["id"])
	gs.job_board[0]["bench_minutes"] = 0
	gs.accept_job(0)
	var job_id: String = str(gs.active_jobs[-1]["job_id"])
	# Finishing it clean (+2) promotes the lab to Accredited.
	gs.complete_job(job_id)
	var band: String = gs.credibility_band()
	var rebuilt: bool = gs._board_band == gs.credibility_band_index()
	var reposted: bool = false
	for job: Dictionary in gs.job_board:
		reposted = reposted or job["id"] == taken_id
	_done(gs)
	if band != "Accredited":
		return "58 points plus a clean job must reach Accredited, got %s." % band
	if reposted:
		return "A job taken today must not be offered again today."
	if not rebuilt:
		return "A promotion must rebuild the board with the new band's jobs."
	return ""


func test_accept_checks_band_and_a_standard_here() -> String:
	var gs: GameStateScript = _make_state()
	gs.job_board.append(_template(gs, "relay_inclinometer"))
	gs.at_oirm["rotary_table"] = GameClock.get_day_index() + 3
	var away: String = gs.accept_job(0)
	gs.at_oirm.erase("rotary_table")
	gs.change_credibility(-5)
	var dropped: String = gs.accept_job(0)
	_done(gs)
	if away.find("OIRM") < 0:
		return "A job must not be accepted while its only standard is at OIRM, got '%s'." % away
	if dropped.find("TRUSTED") < 0:
		return "A lab that fell to Provisional must not accept a Trusted job, got '%s'." % dropped
	return ""


func test_job_at_the_bench_survives_the_morning() -> String:
	# 58 points: the clean finish (+2) promotes the lab to Accredited.
	var gs: GameStateScript = _make_state(58)
	GameClock.elapsed_days = 1.0
	var job_id: String = _take(gs, "lin_soil_probe")
	var due: int = int(gs.active_job(job_id)["due_day"])
	# Started 10 min before dawn of day 4 (not an audit day), still on time.
	GameClock.elapsed_days = float(due - 2) - 10.0 / 1440.0
	var at_dawn: Dictionary = { "kept": false, "offered": true }
	var on_morning: Callable = func(_day: int) -> void:
		at_dawn["kept"] = not gs.active_job(job_id).is_empty()
		at_dawn["offered"] = false
		for job: Dictionary in gs.job_board:
			at_dawn["offered"] = at_dawn["offered"] or job["id"] == "lin_soil_probe"
	GameClock.day_started.connect(gs._on_day_started)
	GameClock.day_started.connect(on_morning)
	var finished: Dictionary = gs.complete_job(job_id)
	GameClock.day_started.disconnect(on_morning)
	GameClock.day_started.disconnect(gs._on_day_started)
	var band: String = gs.credibility_band()
	# Today's three offers rotate, so also check the job is held off today's
	# board whatever the rotation picks.
	var reposted: bool = "lin_soil_probe" not in gs._board_taken
	for job: Dictionary in gs.job_board:
		reposted = reposted or job["id"] == "lin_soil_probe"
	_done(gs)
	if not finished.get("ok", false) or not finished.get("on_time", false):
		return "Work that ends on time across dawn must be paid in full, got %s." % finished
	if not at_dawn["kept"] or at_dawn["offered"]:
		return "A job at the bench at dawn must stay active and off the board, got %s." % at_dawn
	if band != "Accredited":
		return "58 points plus a clean job must reach Accredited, got %s." % band
	if reposted:
		return "A job finished after dawn must not be offered again on promotion."
	return ""


func test_morning_cancels_a_job_past_its_grace_days() -> String:
	var gs: GameStateScript = _make_state()
	GameClock.elapsed_days = 1.0
	var job_id: String = _take(gs, "lin_soil_probe")
	var due: int = int(gs.active_job(job_id)["due_day"])
	var grace: int = _cfg(gs, "late_grace_days")
	# Just before the morning after the last grace day (day 9, not an audit day).
	GameClock.elapsed_days = float(due + grace) - 1.0 / 1440.0
	GameClock.day_started.connect(gs._on_day_started)
	GameClock.advance(2.0 / 1440.0)
	GameClock.day_started.disconnect(gs._on_day_started)
	var day: int = GameClock.get_day_index()
	var gone: bool = gs.active_job(job_id).is_empty()
	_done(gs)
	if day != due + grace + 1:
		return "The test must cross into day %d, got %d." % [due + grace + 1, day]
	if not gone:
		return "The morning after the grace days must cancel the job."
	return ""


func test_audit_morning_cancellation_is_posted_after_the_audit() -> String:
	var gs: GameStateScript = _make_state()
	# Accepted on day 3: due day 6, cancelled the morning of day 10, an audit day.
	GameClock.elapsed_days = 2.0
	var job_id: String = _take(gs, "lin_soil_probe")
	var day: int = int(gs.active_job(job_id)["due_day"]) + _cfg(gs, "late_grace_days") + 1
	GameClock.elapsed_days = float(day - 1)
	var before: int = gs.phone_log.size()
	gs._on_day_started(day)
	var lines: Array[String] = []
	for line: String in gs.phone_log.slice(before):
		lines.append(line)
	var cancel_at: int = -1
	for i: int in lines.size():
		if lines[i].begins_with(job_id + " cancelled"):
			cancel_at = i
	var audited: bool = false
	for line: String in lines:
		audited = audited or line.find("AUD") >= 0 or line.find("udit") >= 0
	_done(gs)
	if day % 5 != 0:
		return "The test must cancel on an audit day, got day %d." % day
	if cancel_at < 0:
		return "The cancellation must be on the phone log."
	if not audited:
		return "The audit must post its lines that morning, got %s." % [lines]
	if cancel_at != lines.size() - 1:
		return "The cancellation must be the newest phone line, got %s." % [lines]
	return ""


func test_two_morning_cancellations_share_one_line() -> String:
	var gs: GameStateScript = _make_state()
	GameClock.elapsed_days = 1.0
	var first: String = _take(gs, "lin_soil_probe")
	# A second copy, due the same day, so both are cancelled the same morning.
	var second: String = _take(gs, "lin_soil_probe")
	var day: int = int(gs.active_job(first)["due_day"]) + _cfg(gs, "late_grace_days") + 1
	GameClock.elapsed_days = float(day - 1)
	var before: int = gs.phone_log.size()
	gs._on_day_started(day)
	var newest: String = gs.phone_log[gs.phone_log.size() - 1] if gs.phone_log.size() > before else ""
	var both_gone: bool = gs.active_job(first).is_empty() and (second == "" or gs.active_job(second).is_empty())
	_done(gs)
	if first == "" or second == "":
		return "The test needs two accepted jobs, got '%s' and '%s'." % [first, second]
	if not both_gone:
		return "Both overdue jobs must be cancelled that morning."
	if newest.find(first + " cancelled") < 0 or newest.find(second + " cancelled") < 0:
		return "Both cancellations must be on the newest phone line, got %s." % newest
	return ""


func test_an_expired_standard_cannot_take_a_job() -> String:
	var gs: GameStateScript = _make_state()
	gs.get_sensor("rotary_table").cal_due_day = GameClock.get_day_index() - 1
	gs.job_board.clear()
	gs.job_board.append(_template(gs, "relay_inclinometer"))
	var problem: String = gs.accept_job(0)
	var taken: int = gs.active_jobs.size()
	_done(gs)
	if taken != 0 or problem.find("traceable") < 0:
		return "A lapsed standard must block the job, got '%s' with %d active." % [problem, taken]
	return ""
