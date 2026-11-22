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
	gs.build_registry()
	gs.reset_credibility()
	gs.credibility = points
	gs.credits = 0
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
	var accepted: String = gs.accept_job(0)
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


func test_late_job_pays_less_and_costs_credibility() -> String:
	var gs: GameStateScript = _make_state()
	var job_id: String = _take(gs, "lin_soil_probe")
	var due: int = int(gs.active_job(job_id)["due_day"])
	GameClock.elapsed_days = float(due + 1)
	while GameClock.get_day_index() <= due:
		GameClock.elapsed_days += 1.0
	var result: Dictionary = gs.complete_job(job_id)
	var pay: int = int(_template(gs, "lin_soil_probe")["pay"])
	var cut: int = _cfg(gs, "late_pay_cut_pct")
	var points: int = _cfg(gs, "late_job_points")
	var credibility: int = gs.credibility
	_done(gs)
	if result.get("on_time", true):
		return "A job finished after its due day must be late."
	if int(result["pay"]) != roundi(pay * (100 - cut) / 100.0):
		return "A late job must pay %d %% less, got %d of %d CR." % [cut, result["pay"], pay]
	if credibility != 30 + points:
		return "A late job must cost %d credibility, now %d." % [points, credibility]
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
	var text: String = gs.job_result_text(result)
	_done(gs)
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


func test_accepted_job_leaves_the_board_and_caps_active() -> String:
	var gs: GameStateScript = _make_state()
	var max_active: int = _cfg(gs, "max_active")
	for i: int in max_active:
		if _take(gs, "lin_soil_probe") == "":
			_done(gs)
			return "Job %d of %d must be accepted." % [i + 1, max_active]
	gs.job_board.clear()
	gs.job_board.append(_template(gs, "relay_inclinometer"))
	var problem: String = gs.accept_job(0)
	gs.refresh_job_board(1)
	var reposted: bool = false
	for job: Dictionary in gs.job_board:
		reposted = reposted or job["id"] == "lin_soil_probe"
	_done(gs)
	if problem == "":
		return "No more than %d jobs may be active." % max_active
	if reposted:
		return "A job already accepted must not be offered again."
	return ""
