extends RefCounted
## Quest-issued jobs and S3 "Certified in Three Fonts" (build order step 13 of
## docs/design/quests_levels_story.md): Chet's envelope, a job a quest hands out
## into active_jobs and never onto the board, `any_gate`, and the flat cut.
## GameClock.elapsed_days is saved and restored; every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const S3: String = "certified_in_three_fonts"
const ENVELOPE: String = "chet_envelope"
const GAUGE: String = "reference_gauge"
const OFFER: String = "CHET: New quest, Certified in Three Fonts."
const YOURS: String = "is yours, not the board's"
const RAN_OUT: String = "ran out"


## Runs `body` on a new farm. `fixtures` replace the shipped quests if given.
func _run(body: Callable, fixtures: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	if not fixtures.is_empty():
		var mine: Dictionary = {}
		for quest: Dictionary in fixtures:
			mine[StringName(str(quest["id"]))] = quest
		table["quests"] = mine
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = _farm()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	gs.free()
	FarmCommands.guest = false
	table["quests"] = shipped
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.lab_gates_kept = gs.all_lab_gate_ids()  # these tests are not about the lab-level gates
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	return gs


func _shipped(id: String) -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest["id"]) == id:
			return quest
	return {}


## S3 alone, as shipped, so no other quest pays in the test.
func _only_s3() -> Array:
	return [_shipped(S3).duplicate(true)]


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _line_index(gs: GameStateScript, part: String) -> int:
	for i: int in range(gs.phone_log.size() - 1, -1, -1):
		if gs.phone_log[i].contains(part):
			return i
	return -1


func _said(path: String) -> String:
	return "CHET: %s" % QuestEngine.phone_line("npcs/chet/quests/%s" % path)


## The lab owns the WD-1 as bought from Bram: certificate, in date.
func _own_gauge(gs: GameStateScript) -> void:
	gs.owned_standards[GAUGE] = 0
	gs.get_sensor(GAUGE).cal_due_day = 1000
	gs._issue_certificate(GAUGE, GameClock.get_day_index(), null, 0.0, false, "the maker", "MKR")


## Every unit in tolerance and in date, so a morning's audit finds nothing.
func _all_in_date(gs: GameStateScript) -> void:
	for id: String in gs.unit_ids() + gs.standard_ids():
		gs.get_sensor(id).error = 0.0
		gs.get_sensor(id).cal_due_day = 1000


## The morning of `day`, as the game runs it.
func _morning(gs: GameStateScript, day: int) -> void:
	_all_in_date(gs)
	GameClock.elapsed_days = float(day - 1)
	gs._on_day_started(day)


## Offers S3 on a farm at credibility 20 and returns its job, or {}.
func _offer(gs: GameStateScript) -> Dictionary:
	gs.credibility = 20
	gs.update_quests()
	return gs.quest_job(S3)


func _quest_jobs(gs: GameStateScript) -> int:
	var count: int = 0
	for job: Dictionary in gs.active_jobs:
		if str(job.get("quest", "")) == S3:
			count += 1
	return count


func _on_board(gs: GameStateScript) -> bool:
	for job: Dictionary in gs.job_board:
		if str(job.get("id", "")) == ENVELOPE or job.has("quest"):
			return true
	return false


# --- The data -------------------------------------------------------------------

func test_s3_ships_as_the_design_has_it() -> String:
	var quest: Dictionary = _shipped(S3)
	if quest.is_empty() or QuestEngine.data_problem(quest) != "":
		return "S3 is shipped and has no problem: %s" % QuestEngine.data_problem(quest)
	if quest["giver"] != "chet" or quest["kind"] != "story" or quest["scope"] != "farm":
		return "S3 is Chet's story quest for the farm."
	var gates: Array = quest["any_gate"]
	if gates.size() != 2 or int(gates[0]["credibility"]) != 20 or int(gates[1]["lab_level"]) != 6:
		return "S3's gate is credibility 20 or lab level 6: %s" % [gates]
	var ids: Array = []
	for step: Dictionary in quest["steps"]:
		ids.append(step["id"])
	if ids != ["envelope", "hand_back"]:
		return "S3's step ids are kept in saves and must not change: %s" % [ids]
	var job: Dictionary = quest["job"]
	if int(job["pay"]) != 200 or int(job["flat_cut_pct"]) != 50 or job["discipline"] != "pressure" or job["id"] != ENVELOPE:
		return "The envelope is 200 CR, half when late or untraceable, for a pressure gauge: %s" % [job]
	var rewards: Dictionary = quest["rewards"]
	if int(rewards.get("quest_points", 0)) != 1 or rewards.has("credits"):
		return "S3 pays 1 quest point; the money is the job's."
	for path: String in ["offer", "again", "clean", "sour"]:
		var full: String = "npcs/chet/quests/certified_in_three_fonts_%s" % path
		var line: String = QuestEngine.phone_line(full)
		if line == "" or line == full:
			return "Chet has no line for '%s'." % path
	if not QuestEngine.phone_line("npcs/chet/quests/certified_in_three_fonts_clean").contains("I owe you one"):
		return "On a clean job Chet owes you one."
	return ""


func test_the_envelope_is_not_one_of_the_boards_jobs() -> String:
	return _run(_check_not_a_template)


func _check_not_a_template(gs: GameStateScript) -> String:
	for template: Dictionary in gs._job_templates():
		if str(template.get("id", "")) == ENVELOPE:
			return "The envelope must not be a board template."
	if not (gs.job_disciplines() as Dictionary).has(str(_shipped(S3)["job"]["discipline"])):
		return "The envelope's discipline is one the lab has."
	return ""


# --- The gate -------------------------------------------------------------------

func test_s3_is_offered_at_credibility_20() -> String:
	return _run(_check_gate_credibility)


func _check_gate_credibility(gs: GameStateScript) -> String:
	gs.credibility = 19
	gs.update_quests()
	if gs.quest_state.has(S3) or gs.lab_level() >= 6 or _quest_jobs(gs) != 0 or _lines(gs, OFFER) != 0:
		return "S3 waits at credibility 19 and lab level %d." % gs.lab_level()
	gs.credibility = 20
	# A look after a command offers nothing.
	gs.update_quests([], false)
	if gs.quest_state.has(S3):
		return "S3 is offered in the morning or when the farm opens, not after a command."
	gs.update_quests()
	if not gs.quest_state.has(S3) or _lines(gs, OFFER) != 1:
		return "S3 is offered at credibility 20: %s" % [gs.phone_log]
	return ""


func test_s3_is_offered_at_lab_level_6() -> String:
	return _run(_check_gate_level)


func _check_gate_level(gs: GameStateScript) -> String:
	gs.credibility = 5
	gs.give_lab_xp(gs.xp_for_level(5))
	gs.update_quests()
	if gs.quest_state.has(S3) or gs.lab_level() != 5:
		return "S3 waits at lab level 5 and credibility 5."
	gs.give_lab_xp(gs.xp_for_level(6) - gs.xp_for_level(5))
	gs.update_quests()
	if gs.lab_level() != 6 or not gs.quest_state.has(S3) or _quest_jobs(gs) != 1:
		return "S3 is offered at lab level 6 whatever the credibility: level %d." % gs.lab_level()
	return ""


func test_any_gate_needs_one_and_gates_need_all() -> String:
	return _run(_check_any_gate)


func _check_any_gate(gs: GameStateScript) -> String:
	var present: Array[String] = [HOST]
	var quest: Dictionary = { "gates": { "credibility": 5 }, "any_gate": [{ "credibility": 50 }, { "lab_level": 1, "credibility": 12 }] }
	gs.credibility = 11
	if QuestEngine.is_offered(gs, quest, present):
		return "No entry of any_gate holds at credibility 11."
	gs.credibility = 12
	if not QuestEngine.is_offered(gs, quest, present):
		return "The second entry holds at credibility 12 and lab level 1."
	quest["gates"] = { "credibility": 13 }
	if QuestEngine.is_offered(gs, quest, present):
		return "The quest's own gates must hold too."
	quest["gates"] = {}
	quest["any_gate"] = [{ "no_such_gate": 1 }]
	if QuestEngine.is_offered(gs, quest, present):
		return "A gate this build cannot read is shut."
	return ""


# --- The job --------------------------------------------------------------------

func test_the_envelope_goes_to_active_jobs_and_never_the_board() -> String:
	return _run(_check_issued)


func _check_issued(gs: GameStateScript) -> String:
	var numbered: int = gs._next_job_number
	var job: Dictionary = _offer(gs)
	if job.is_empty() or _quest_jobs(gs) != 1 or gs.active_jobs.size() != 1:
		return "The quest hands its job into active_jobs: %s" % [gs.active_jobs]
	var today: int = GameClock.get_day_index()
	if job["job_id"] != "JOB-%04d" % numbered or gs._next_job_number != numbered + 1 or int(job["accepted_day"]) != today or int(job["due_day"]) != today + 3:
		return "The job is numbered and dated as a board job is: %s" % [job]
	for key: String in ["id", "customer", "item", "discipline", "pay", "min_tier", "bench_minutes", "due_in_days"]:
		if not job.has(key):
			return "The job has the shape of a board job, and has no %s." % key
	if job["quest"] != S3 or gs.active_job(str(job["job_id"])) != job or not gs.has_quest_job(S3):
		return "The job says which quest it is from."
	if gs.owned_standards.has(GAUGE):
		return "The test needs a lab with no pressure standard yet."
	if _on_board(gs):
		return "The envelope is not on the board."
	if gs.quest_state[S3]["steps_done"] != ["envelope"] or QuestEngine.is_done(gs, S3):
		return "Taking the envelope is the first step: %s" % [gs.quest_state[S3]]
	if _lines(gs, OFFER) != 1 or _lines(gs, YOURS) != 1 or _line_index(gs, YOURS) < _line_index(gs, OFFER):
		return "Chet's offer, then what the job is: %s" % [gs.phone_log]
	if not gs.phone_log[_line_index(gs, YOURS)].contains("200 CR") or not gs.phone_log[_line_index(gs, YOURS)].contains(str(job["job_id"])):
		return "The job's line names it and its pay: %s" % gs.phone_log[_line_index(gs, YOURS)]
	# Another look hands out nothing more.
	var lines: int = gs.phone_log.size()
	gs.update_quests()
	if _quest_jobs(gs) != 1 or gs.phone_log.size() != lines:
		return "A second look must not hand out a second envelope."
	# The board is filled around it, on any day and in any band, and keeps it.
	for band: int in [30, 60]:
		gs.credibility = band
		for day: int in range(1, 13):
			gs.refresh_job_board(day)
			if _on_board(gs) or _quest_jobs(gs) != 1:
				return "The board must not show or lose the envelope (day %d)." % day
			if gs.job_board.size() != gs.job_board_size():
				return "The envelope must not take a place on the board (day %d)." % day
	return ""


func test_the_envelope_cannot_be_done_without_the_standard() -> String:
	return _run(_check_needs_standard, _only_s3())


func _check_needs_standard(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	var result: Dictionary = gs.complete_job(str(job["job_id"]))
	if result.get("ok", false) or _quest_jobs(gs) != 1:
		return "With no pressure standard the bench refuses and the job stays: %s" % [result]
	return ""


func test_on_time_and_traceable_pays_the_full_envelope() -> String:
	return _run(_check_clean, _only_s3())


func _check_clean(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	var before: int = gs.credits
	var result: Dictionary = gs.complete_job(str(job["job_id"]))
	if not result.get("ok", false) or not result["on_time"] or not result["traceable"] or int(result["pay"]) != 200:
		return "A clean envelope pays 200 CR: %s" % [result]
	if result.get("quest") != S3 or gs.job_log[-1].get("quest") != S3:
		return "The job_log row says which quest the job was from."
	if gs.credibility != 20 + int(gs._jobs_number("clean_job_points", 0.0)):
		return "A clean envelope earns the credibility a clean board job does, got %d." % gs.credibility
	# As after the command (FarmCommands.execute): no offering look.
	gs.update_quests([], false)
	if not QuestEngine.is_done(gs, S3) or gs.credits != before + 200:
		return "The quest is done and the envelope is all the money: %d CR." % (gs.credits - before)
	if QuestEngine.points_of(gs, HOST) != 1:
		return "S3 pays 1 quest point, got %d." % QuestEngine.points_of(gs, HOST)
	if _lines(gs, _said("certified_in_three_fonts_clean")) != 1 or _lines(gs, _said("certified_in_three_fonts_sour")) != 0:
		return "Chet says he owes you one, once: %s" % [gs.phone_log]
	# Done is done: no more envelopes, lines or pay.
	var lines: int = gs.phone_log.size()
	_morning(gs, 2)
	gs.update_quests()
	if _quest_jobs(gs) != 0 or gs.credits != before + 200 or QuestEngine.points_of(gs, HOST) != 1 or _lines(gs, "CHET:") != 2:
		return "A finished S3 hands out nothing more: %s" % [gs.phone_log.slice(lines)]
	return ""


func test_late_pays_half_with_a_sour_line() -> String:
	return _run(_check_late, _only_s3())


func _check_late(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	# The day after it was due, inside the grace days.
	GameClock.elapsed_days = float(int(job["due_day"]))
	return _check_half(gs, job, false, true)


func test_untraceable_pays_half_with_a_sour_line() -> String:
	return _run(_check_untraceable, _only_s3())


func _check_untraceable(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	gs.get_sensor(GAUGE).cal_due_day = 0
	return _check_half(gs, job, true, false)


func test_late_and_untraceable_is_still_half() -> String:
	return _run(_check_both, _only_s3())


func _check_both(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	GameClock.elapsed_days = float(int(job["due_day"]))
	gs.get_sensor(GAUGE).cal_due_day = 0
	return _check_half(gs, job, false, false)


func _check_half(gs: GameStateScript, job: Dictionary, on_time: bool, traceable: bool) -> String:
	var before: int = gs.credits
	var points: int = gs.credibility
	var result: Dictionary = gs.complete_job(str(job["job_id"]))
	if not result.get("ok", false) or result["on_time"] != on_time or result["traceable"] != traceable:
		return "The test needs on_time %s and traceable %s: %s" % [on_time, traceable, result]
	if int(result["pay"]) != 100 or int(result["offered"]) != 200:
		return "Late, untraceable or both is half the envelope, once: %s" % [result]
	var cost: int = 0
	if not on_time:
		cost += int(gs._jobs_number("late_job_points", 0.0))
	if not traceable:
		cost += int(gs._jobs_number("untraceable_job_points", 0.0))
	if gs.credibility != maxi(points + cost, 0):
		return "The credibility cost is a board job's, got %d from %d." % [gs.credibility, points]
	gs.update_quests([], false)
	if not QuestEngine.is_done(gs, S3) or gs.credits != before + 100 or QuestEngine.points_of(gs, HOST) != 1:
		return "Any finish does the quest and pays the point: %d CR, %d points." % [gs.credits - before, QuestEngine.points_of(gs, HOST)]
	if _lines(gs, _said("certified_in_three_fonts_sour")) != 1 or _lines(gs, _said("certified_in_three_fonts_clean")) != 0:
		return "Chet's line is the sour one: %s" % [gs.phone_log]
	return ""


func test_a_board_job_keeps_its_two_cuts() -> String:
	return _run(_check_board_cuts, _only_s3())


func _check_board_cuts(gs: GameStateScript) -> String:
	_own_gauge(gs)
	gs.credibility = 30
	gs.lab_size = gs.lab_sizes().size() - 1
	gs.lab_areas["pressure"] = gs.lab_area_spaces_needed("large")
	for template: Dictionary in gs._job_templates():
		if template["id"] == "kestrel_tire_gauge":
			gs.job_board.clear()
			gs.job_board.append(template.duplicate(true))
	if gs.accept_job(0) != "":
		return "The test needs the tire gauge job."
	var job: Dictionary = gs.active_jobs[-1]
	if job.has("quest") or job.has("flat_cut_pct"):
		return "A board job has no quest mark."
	GameClock.elapsed_days = float(int(job["due_day"]))
	gs.get_sensor(GAUGE).cal_due_day = 0
	var result: Dictionary = gs.complete_job(str(job["job_id"]))
	var late: float = (100.0 - gs._jobs_number("late_pay_cut_pct", 50.0)) / 100.0
	var untraceable: float = (100.0 - gs._jobs_number("untraceable_pay_cut_pct", 75.0)) / 100.0
	if not result.get("ok", false) or int(result["pay"]) != roundi(float(int(job["pay"])) * late * untraceable) or result.has("quest"):
		return "A board job is cut twice as before and its row has no quest: %s" % [result]
	return ""


# --- Running out, and dropped -----------------------------------------------------

func test_bench_work_across_dawn_is_late_and_not_handed_out_again() -> String:
	return _run(_check_across_dawn, _only_s3())


func _check_across_dawn(gs: GameStateScript) -> String:
	# Offered on day 2, due day 5, so the dawn it crosses (day 6) has no audit.
	GameClock.elapsed_days = 1.0
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	_all_in_date(gs)
	var job_id: String = str(job["job_id"])
	var due: int = int(job["due_day"])
	if (due + 1) % int(DataManager.get_number(&"sensor_drift_config", "audit_schedule/cadence_days", 5.0)) == 0:
		return "The test needs a dawn with no audit, got day %d." % (due + 1)
	# Started 10 min before the 06:00 after its due day: 40 min of work.
	GameClock.elapsed_days = float(due) - 10.0 / 1440.0
	var at_dawn: Dictionary = { "seen": false, "kept": false, "jobs": 0 }
	var on_morning: Callable = func(_day: int) -> void:
		at_dawn["seen"] = true
		at_dawn["kept"] = gs.quest_job(S3).get("job_id", "") == job_id
		at_dawn["jobs"] = _quest_jobs(gs)
	var before: int = gs.credits
	var points: int = gs.credibility
	GameClock.day_started.connect(gs._on_day_started)
	GameClock.day_started.connect(on_morning)
	var result: Dictionary = gs.complete_job(job_id)
	GameClock.day_started.disconnect(on_morning)
	GameClock.day_started.disconnect(gs._on_day_started)
	if not at_dawn["seen"] or GameClock.get_day_index() != due + 1:
		return "The test must cross into day %d, got %d." % [due + 1, GameClock.get_day_index()]
	if not at_dawn["kept"] or at_dawn["jobs"] != 1:
		return "The morning during the work keeps the envelope and hands out no other: %s" % [at_dawn]
	if not result.get("ok", false) or result["on_time"] or not result["traceable"]:
		return "Work that ends after the due day is late: %s" % [result]
	if int(result["pay"]) != 100 or gs.credits != before + 100:
		return "Late across dawn is half the envelope: %s" % [result]
	if gs.credibility != maxi(points + int(gs._jobs_number("late_job_points", 0.0)), 0):
		return "Late costs what a late board job costs, got %d from %d." % [gs.credibility, points]
	gs.update_quests()
	if _quest_jobs(gs) != 0 or _lines(gs, YOURS) != 1 or _lines(gs, RAN_OUT) != 0 or _lines(gs, _said("certified_in_three_fonts_again")) != 0:
		return "A finished envelope is not handed out again: %s" % [gs.phone_log]
	if not QuestEngine.is_done(gs, S3) or _lines(gs, _said("certified_in_three_fonts_sour")) != 1:
		return "The quest is done, with the sour line."
	if ENVELOPE in gs._board_taken:
		return "The envelope is not one of the board's taken jobs: %s" % [gs._board_taken]
	return ""


func test_work_that_would_end_past_the_grace_days_is_refused() -> String:
	return _run(_check_past_grace, _only_s3())


func _check_past_grace(gs: GameStateScript) -> String:
	GameClock.elapsed_days = 1.0
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	var job_id: String = str(job["job_id"])
	var cutoff: int = int(job["due_day"]) + int(gs._jobs_number("late_grace_days", 3.0))
	# 10 min before the 06:00 that takes it away: the work would cross it.
	GameClock.elapsed_days = float(cutoff) - 10.0 / 1440.0
	var before: int = gs.credits
	var result: Dictionary = gs.complete_job(job_id)
	if result.get("ok", true) or not str(result.get("reason", "")).contains("Not enough time"):
		return "Work that would end after the envelope runs out is refused: %s" % [result]
	if gs.credits != before or not gs.job_log.is_empty() or gs.quest_job(S3).get("job_id", "") != job_id or GameClock.get_day_index() != cutoff:
		return "A refused envelope is left as it was, and no time passes."
	# The morning then takes it away and brings another, at no cost.
	var day: int = cutoff + 1
	if day % int(DataManager.get_number(&"sensor_drift_config", "audit_schedule/cadence_days", 5.0)) == 0:
		return "The test needs a morning with no audit, got day %d." % day
	var points: int = gs.credibility
	_morning(gs, day)
	var again: Dictionary = gs.quest_job(S3)
	if again.is_empty() or again["job_id"] == job_id or _quest_jobs(gs) != 1 or _lines(gs, RAN_OUT) != 1:
		return "It runs out that morning and is handed out again: %s" % [gs.active_jobs]
	if gs.credibility != points or QuestEngine.is_done(gs, S3):
		return "Running out costs nothing and the quest stays open."
	return ""


# --- The lab's areas ------------------------------------------------------------
func _pressure_offer(gs: GameStateScript) -> Dictionary:
	return { "id": "test_pressure_gauge", "customer": "A customer", "item": "a gauge", "discipline": "pressure", "min_band": gs.credibility_band(),
		"min_tier": 1, "pay": 50, "due_in_days": 2, "bench_minutes": 10 }


func test_the_envelope_takes_no_space_in_the_pressure_area() -> String:
	return _run(_check_area, _only_s3())


func _check_area(gs: GameStateScript) -> String:
	gs.lab_areas["pressure"] = 1
	gs.credits = 100000
	gs.crystal_ore = 1000
	_offer(gs)
	if _quest_jobs(gs) != 1 or gs.quest_job(S3)["discipline"] != "pressure":
		return "The test needs the envelope out, as a pressure job."
	if gs.jobs_in_progress("pressure") != 0 or gs._lab_spaces_in_use("pressure") != 0:
		return "The envelope holds no space: %d in progress." % gs.jobs_in_progress("pressure")
	# With no pressure standard the envelope cannot be done, and the one space
	# can still be cleared for another discipline.
	if gs.lab_clear_problem("pressure") != "":
		return "The envelope must not keep the pressure space from being cleared: %s" % gs.lab_clear_problem("pressure")
	_own_gauge(gs)
	if gs.job_area_problem(_pressure_offer(gs)) != "":
		return "A one-space pressure area still has room with the envelope out: %s" % gs.job_area_problem(_pressure_offer(gs))
	gs.job_board.assign([_pressure_offer(gs), _pressure_offer(gs)])
	var first: String = gs.accept_job(0)
	if first != "" or gs.active_jobs.size() != 2 or _quest_jobs(gs) != 1:
		return "A pressure board job is accepted beside the envelope, got '%s'." % first
	# The board's own job does hold the space.
	var second: String = gs.accept_job(0)
	if second.find("area is full") < 0 or gs.jobs_in_progress("pressure") != 1:
		return "A second board job needs a second space, got '%s'." % second
	if gs.lab_clear_problem("pressure").find("job in progress") < 0:
		return "A board job in progress keeps its space: '%s'" % gs.lab_clear_problem("pressure")
	# And the envelope is done as before, area or no area.
	var result: Dictionary = gs.complete_job(str(gs.quest_job(S3)["job_id"]))
	if not result.get("ok", false) or int(result["pay"]) != 200:
		return "The envelope is still done at the bench: %s" % [result]
	return ""


func test_an_envelope_that_runs_out_is_back_the_same_morning() -> String:
	return _run(_check_runs_out)


func _check_runs_out(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	var seen: Array[String] = [str(job["job_id"])]
	var grace: int = int(gs._jobs_number("late_grace_days", 3.0))
	# The last morning it is still good, then three mornings it has run out.
	_morning(gs, int(job["due_day"]) + grace)
	if gs.quest_job(S3).get("job_id") != seen[0] or _lines(gs, RAN_OUT) != 0:
		return "The envelope stays through its grace days."
	for round: int in range(1, 4):
		var day: int = int(gs.quest_job(S3)["due_day"]) + grace + 1
		# Not an audit morning, so the credibility is the envelope's doing alone.
		if day % int(DataManager.get_number(&"sensor_drift_config", "audit_schedule/cadence_days", 5.0)) == 0:
			day += 1
		var points: int = gs.credibility
		_morning(gs, day)
		var again: Dictionary = gs.quest_job(S3)
		if again.is_empty() or _quest_jobs(gs) != 1 or str(again["job_id"]) in seen:
			return "Round %d: a new envelope is under the airlock: %s" % [round, gs.active_jobs]
		seen.append(str(again["job_id"]))
		if int(again["due_day"]) != day + 3 or int(again["accepted_day"]) != day:
			return "Round %d: the new envelope is dated from that morning: %s" % [round, again]
		if gs.credibility != points or _lines(gs, "cancelled") != 0:
			return "Round %d: an envelope that runs out costs no credibility (%d from %d)." % [round, gs.credibility, points]
		if _lines(gs, RAN_OUT) != round or _lines(gs, _said("certified_in_three_fonts_again")) != round or _lines(gs, YOURS) != round + 1:
			return "Round %d: it is said to have run out and to be back: %s" % [round, gs.phone_log]
		if _line_index(gs, RAN_OUT) > _line_index(gs, _said("certified_in_three_fonts_again")) or _line_index(gs, YOURS) < _line_index(gs, _said("certified_in_three_fonts_again")):
			return "Round %d: ran out, then Chet, then the job: %s" % [round, gs.phone_log]
		if _on_board(gs) or QuestEngine.is_done(gs, S3) or gs.quest_state[S3]["steps_done"] != ["envelope"]:
			return "Round %d: the quest is open and the board has no envelope." % round
	if _lines(gs, OFFER) != 1:
		return "The quest is offered once."
	# And the fourth envelope can still be done clean.
	_own_gauge(gs)
	var before: int = gs.credits
	var result: Dictionary = gs.complete_job(seen[-1])
	gs.update_quests([], false)
	if not result.get("ok", false) or int(result["pay"]) != 200 or gs.credits != before + 200 or not QuestEngine.is_done(gs, S3):
		return "The envelope that came back pays in full: %s" % [result]
	if _lines(gs, _said("certified_in_three_fonts_clean")) != 1:
		return "Chet owes you one after all."
	return ""


func test_a_dropped_envelope_is_back_the_next_morning() -> String:
	return _run(_check_dropped)


func _check_dropped(gs: GameStateScript) -> String:
	for round: int in range(1, 4):
		var job: Dictionary = gs.quest_job(S3) if round > 1 else _offer(gs)
		if job.is_empty():
			return "Round %d: the test needs the envelope." % round
		var old_id: String = str(job["job_id"])
		gs.active_jobs.erase(job)
		# After a command nothing comes back: only a morning or opening the farm.
		gs.update_quests([], false)
		if _quest_jobs(gs) != 0 or gs.has_quest_job(S3):
			return "Round %d: a dropped envelope is not back before the morning." % round
		_morning(gs, round + 1)
		var again: Dictionary = gs.quest_job(S3)
		if again.is_empty() or again["job_id"] == old_id or int(again["due_day"]) != round + 1 + 3:
			return "Round %d: the envelope is back the next morning: %s" % [round, gs.active_jobs]
		if _lines(gs, _said("certified_in_three_fonts_again")) != round or _lines(gs, OFFER) != 1 or QuestEngine.is_done(gs, S3):
			return "Round %d: Chet says it is back, and the quest is still open." % round
	return ""


# --- Saves ----------------------------------------------------------------------

func _reloaded(gs: GameStateScript) -> Variant:
	# As the save file holds it (SaveGame.to_bytes).
	var saved: Variant = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var again: GameStateScript = GameStateScript.new()
	again.build_registry()
	var problem: String = again.farm_from_dict(saved) if saved is Dictionary else "The farm is not a dictionary."
	if problem != "":
		again.free()
		return problem
	return again


func test_s3_mid_quest_goes_through_a_save() -> String:
	return _run(_check_save)


func _check_save(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	if job.is_empty() or SaveGame.VERSION != 1:
		return "The test needs the envelope, and the save's version stays 1."
	var loaded: Variant = _reloaded(gs)
	if loaded is String:
		return "The farm did not load: %s" % loaded
	var again: GameStateScript = loaded
	var out: String = ""
	if again.quest_job(S3) != job or again.quest_state != gs.quest_state or again._next_job_number != gs._next_job_number:
		out = "The envelope and the quest are in the save as they were: %s" % [again.active_jobs]
	else:
		# Opening the farm is an offering look: it must not hand out another.
		var lines: int = again.phone_log.size()
		again.update_quests()
		if again.active_jobs != gs.active_jobs or again.phone_log.size() != lines:
			out = "Opening the saved farm hands out nothing new: %s" % [again.phone_log.slice(lines)]
		else:
			var before: int = again.credits
			var result: Dictionary = again.complete_job(str(job["job_id"]))
			again.update_quests([], false)
			if not result.get("ok", false) or again.credits != before + 200 or not QuestEngine.is_done(again, S3):
				out = "The loaded envelope pays and finishes the quest: %s" % [result]
			else:
				# And a finished S3 through a save stays finished.
				var later: Variant = _reloaded(again)
				if later is String:
					out = "The finished farm did not load: %s" % later
				else:
					(later as GameStateScript).update_quests()
					if not (later as GameStateScript).quest_job(S3).is_empty() or not QuestEngine.is_done(later, S3) \
							or (later as GameStateScript).credits != again.credits or not (later as GameStateScript).has_quest_job(S3):
						out = "A finished S3 is not handed out again after a load."
					(later as GameStateScript).free()
	again.free()
	return out


func test_a_save_with_the_envelope_gone_gets_it_back_when_opened() -> String:
	return _run(_check_save_dropped)


func _check_save_dropped(gs: GameStateScript) -> String:
	gs.active_jobs.erase(_offer(gs))
	var loaded: Variant = _reloaded(gs)
	if loaded is String:
		return "The farm did not load: %s" % loaded
	var again: GameStateScript = loaded
	again.update_quests()
	var out: String = ""
	if again.quest_job(S3).is_empty() or QuestEngine.is_done(again, S3) or again.quest_state[S3]["steps_done"] != ["envelope"]:
		out = "Opening a farm whose envelope is gone puts it back: %s" % [again.active_jobs]
	again.free()
	return out


func test_an_old_save_gets_s3_when_its_gate_holds() -> String:
	return _run(_check_old_save)


func _check_old_save(gs: GameStateScript) -> String:
	# A farm from before S3: Trusted, a board job accepted, no word of the quest.
	_own_gauge(gs)
	gs.credibility = 30
	gs.active_jobs.append({ "id": "lin_soil_probe", "customer": "Lin", "item": "a soil probe", "discipline": "soil moisture",
		"min_band": "Trusted", "min_tier": 0, "pay": 100, "due_in_days": 3, "bench_minutes": 40,
		"job_id": "JOB-0001", "accepted_day": 1, "due_day": 4 })
	gs._next_job_number = 2
	var saved: Dictionary = gs.farm_to_dict()
	if saved["quest_state"].has(S3):
		return "The test needs a farm that never saw S3."
	var again: GameStateScript = GameStateScript.new()
	again.build_registry()
	var problem: String = again.farm_from_dict(bytes_to_var(var_to_bytes(saved)))
	var out: String = ""
	if problem != "":
		out = "The old farm did not load: %s" % problem
	else:
		again.update_quests()
		var job: Dictionary = again.quest_job(S3)
		if job.is_empty() or job["job_id"] != "JOB-0002" or again.active_jobs.size() != 2 or again.active_job("JOB-0001").is_empty():
			out = "The old farm is offered S3 and keeps its own job: %s" % [again.active_jobs]
		elif again.active_job("JOB-0001").has("quest"):
			out = "The old farm's board job has no quest mark."
	again.free()
	return out


func test_a_save_with_a_bad_quest_mark_is_refused() -> String:
	return _run(_check_bad_save)


func _check_bad_save(gs: GameStateScript) -> String:
	_offer(gs)
	if gs.farm_dict_problem(gs.farm_to_dict()) != "":
		return "A farm with the envelope is a good save: %s" % gs.farm_dict_problem(gs.farm_to_dict())
	var bad: Dictionary = gs.farm_to_dict().duplicate(true)
	bad["active_jobs"][0]["quest"] = 5
	if gs.farm_dict_problem(bad) == "":
		return "A job whose quest is not text must be refused."
	bad = gs.farm_to_dict().duplicate(true)
	bad["active_jobs"][0]["flat_cut_pct"] = "half"
	if gs.farm_dict_problem(bad) == "":
		return "A job whose flat cut is not a number must be refused."
	# A quest's job is never on the board.
	var offer: Dictionary = { "id": "test_offer", "customer": "A customer", "item": "a gauge", "discipline": "pressure", "min_band": gs.credibility_band(),
		"min_tier": 1, "pay": 50, "due_in_days": 2, "bench_minutes": 10 }
	bad = gs.farm_to_dict().duplicate(true)
	bad["job_board"].append(offer.duplicate())
	if gs.farm_dict_problem(bad) != "":
		return "The test needs a board offer the save check takes: %s" % gs.farm_dict_problem(bad)
	for mark: Array in [["quest", S3], ["flat_cut_pct", 50]]:
		bad = gs.farm_to_dict().duplicate(true)
		var marked: Dictionary = offer.duplicate()
		marked[mark[0]] = mark[1]
		bad["job_board"].append(marked)
		if gs.farm_dict_problem(bad) == "":
			return "A board offer with '%s' must be refused." % mark[0]
	# One quest has one job out.
	bad = gs.farm_to_dict().duplicate(true)
	var twin: Dictionary = bad["active_jobs"][0].duplicate(true)
	twin["job_id"] = "JOB-9999"
	bad["active_jobs"].append(twin)
	if gs.farm_dict_problem(bad) == "":
		return "Two active jobs from one quest must be refused."
	# Two jobs with no quest are two board jobs, as before.
	bad["active_jobs"][0].erase("quest")
	bad["active_jobs"][1].erase("quest")
	if gs.farm_dict_problem(bad) != "":
		return "Two board jobs are a good save: %s" % gs.farm_dict_problem(bad)
	return ""


# --- Co-op ----------------------------------------------------------------------

func test_a_guest_sees_the_envelope_and_hands_out_none() -> String:
	return _run(_check_guest)


func _check_guest(gs: GameStateScript) -> String:
	var job: Dictionary = _offer(gs)
	_own_gauge(gs)
	if SessionScript.PROTOCOL != 52:
		return "The envelope rides in fields guests already get: CoopSession.PROTOCOL stays 19."
	var guest: GameStateScript = _farm()
	var problem: String = guest.farm_from_dict(gs.farm_to_dict())
	var out: String = ""
	FarmCommands.guest = true
	if problem != "" or guest.quest_job(S3) != job or guest.quest_state != gs.quest_state:
		out = "The guest has the host's envelope and quest: %s" % problem
	else:
		# A guest never runs the quests: an envelope gone there is the host's to put back.
		guest.active_jobs.clear()
		guest.update_quests()
		if not guest.active_jobs.is_empty():
			out = "A guest hands out no envelope."
	FarmCommands.guest = false
	guest.free()
	if out != "":
		return out
	# The guest's bench command runs on the host, and the farm's quest is done by it.
	var result: Dictionary = gs.complete_job(str(job["job_id"]), GUEST)
	gs.update_quests([], false)
	if not result.get("ok", false) or int(result["pay"]) != 200 or not QuestEngine.is_done(gs, S3):
		return "A guest can do the envelope at the bench: %s" % [result]
	var after: GameStateScript = _farm()
	problem = after.farm_from_dict(gs.farm_to_dict())
	var done: bool = problem == "" and QuestEngine.is_done(after, S3) and after.has_quest_job(S3) and after.quest_job(S3).is_empty()
	after.free()
	return "" if done else "The guest sees the finished quest and its job_log row: %s" % problem


# --- Bad data -------------------------------------------------------------------

func _with(key: String, value: Variant) -> Dictionary:
	var quest: Dictionary = _shipped(S3).duplicate(true)
	quest[key] = value
	return quest


func _with_job(key: String, value: Variant) -> Dictionary:
	var quest: Dictionary = _shipped(S3).duplicate(true)
	if value == null:
		(quest["job"] as Dictionary).erase(key)
	else:
		quest["job"][key] = value
	return quest


func test_bad_jobs_and_gates_are_refused() -> String:
	var bad: Array[Dictionary] = [
		_with("any_gate", []), _with("any_gate", { "credibility": 20 }), _with("any_gate", [{}]), _with("any_gate", ["credibility"]),
		_with("job", "chet_envelope"), _with("scope", "player"), _with("job_again_line", ""), _with("job_again_line", 3),
		_with_job("item", null), _with_job("id", ""), _with_job("discipline", 4), _with_job("customer", null),
		_with_job("pay", "200"), _with_job("flat_cut_pct", "half"), _with_job("min_band", "Trusted"), _with_job("area", "large"),
		_with_job("job_id", "JOB-0001"), _with_job("quest", "other"), _with_job("due_day", 3),
	]
	for i: int in bad.size():
		if QuestEngine.data_problem(bad[i]) == "":
			return "Bad quest %d must be refused." % i
	var no_job: Dictionary = _shipped(S3).duplicate(true)
	no_job.erase("job")
	if QuestEngine.data_problem(no_job) == "":
		return "A job_again_line with no job must be refused."
	var no_quest: Dictionary = _shipped(S3).duplicate(true)
	(no_quest["steps"][0] as Dictionary).erase("quest")
	if QuestEngine.data_problem(no_quest) == "":
		return "A quest_job step that names no quest must be refused."
	if not "quest_job" in QuestEngine.CHECKS:
		return "quest_job is a check the engine knows."
	return ""


func test_a_quest_with_a_bad_job_hands_out_nothing() -> String:
	return _run(_check_bad_job_left_alone, [_with_job("item", null)])


func _check_bad_job_left_alone(gs: GameStateScript) -> String:
	gs.credibility = 20
	gs.update_quests()
	if gs.quest_state.has(S3) or not gs.active_jobs.is_empty():
		return "A quest with a problem is left alone."
	return ""
