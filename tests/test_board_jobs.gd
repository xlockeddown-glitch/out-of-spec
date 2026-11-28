extends RefCounted
## The 4th and 5th job on the board (feat/board-jobs): the board holds the base
## size, plus one at lab level 28 and one more at 65 [PLACEHOLDER], through
## lab_gate_open (so a kept row counts), capped by the eligible templates, the
## same pick for the same day, new slots at the next refresh only, and a phone
## that lists five without clipping. Every GameState and node is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HudScene: PackedScene = preload("res://ui/field_phone_hud.tscn")


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.reset_credibility()
	gs.credibility = 9999
	gs.lab_gates_kept.clear()
	# A large lab with an area for every discipline: the lab's own limits stay out.
	gs.lab_size = gs.lab_sizes().size() - 1
	for discipline: Variant in gs.job_disciplines():
		gs.lab_areas[str(discipline)] = gs.lab_area_spaces_needed("large")
	return gs


func _at(gs: GameStateScript, level: int) -> void:
	gs.lab_xp = gs.xp_for_level(level)


func _ids(gs: GameStateScript) -> Array:
	var ids: Array = []
	for job: Dictionary in gs.job_board:
		ids.append(job["id"])
	return ids


func test_board_size_is_3_4_5_at_levels_27_28_65() -> String:
	var gs: GameStateScript = _state()
	var base: int = int(gs._jobs_number("board_size", 3.0))
	var problem: String = ""
	var l4: int = gs.lab_gate_level("board_4_jobs")
	var l5: int = gs.lab_gate_level("board_5_jobs")
	if l4 != 28 or l5 != 65:
		problem = "The rows are at levels 28 and 65, not %d and %d." % [l4, l5]
	for pair: Array in [[27, 0], [28, 1], [64, 1], [65, 2]]:
		_at(gs, int(pair[0]))
		gs.refresh_job_board(3)
		if problem == "" and (gs.job_board_size() != base + int(pair[1]) or gs.job_board.size() != base + int(pair[1])):
			problem = "Level %d: board %d (size %d), want %d." % [pair[0], gs.job_board.size(), gs.job_board_size(), base + int(pair[1])]
	gs.free()
	return problem


func test_the_board_is_capped_by_the_eligible_templates() -> String:
	var gs: GameStateScript = _state()
	_at(gs, 70)
	gs.refresh_job_board(1)
	var full: int = gs.job_board.size()
	# Take all but two templates off the board: only two are eligible.
	var problem: String = ""
	var all: Array[Dictionary] = gs._job_templates()
	gs._board_day = 1
	gs._board_taken.clear()
	for i: int in range(2, all.size()):
		gs._board_taken.append(str(all[i]["id"]))
	gs.refresh_job_board(1)
	if full != 5:
		problem = "Lab level 70 should fill five places, got %d." % full
	elif gs.job_board.size() != 2:
		problem = "Fewer eligible templates than places: the board holds %d." % gs.job_board.size()
	gs.free()
	return problem


func test_a_kept_row_counts() -> String:
	var gs: GameStateScript = _state()
	_at(gs, 1)
	gs.lab_gates_kept.append("board_4_jobs")
	var size: int = gs.job_board_size()
	var base: int = int(gs._jobs_number("board_size", 3.0))
	gs.free()
	return "" if size == base + 1 else "A kept 4th-job row opens the slot at level 1: size %d." % size


func test_the_same_day_is_the_same_board() -> String:
	var a: GameStateScript = _state()
	var b: GameStateScript = _state()
	_at(a, 70)
	_at(b, 70)
	a.refresh_job_board(9)
	b.refresh_job_board(9)
	var first: Array = _ids(a)
	a.refresh_job_board(9)
	var problem: String = ""
	if _ids(a) != first or _ids(b) != first or first.size() != 5:
		problem = "Day 9 gave %s then %s, other farm %s." % [first, _ids(a), _ids(b)]
	a.free()
	b.free()
	return problem


func test_a_new_slot_waits_for_the_next_refresh() -> String:
	var gs: GameStateScript = _state()
	_at(gs, 27)
	gs.refresh_job_board(4)
	var before: int = gs.job_board.size()
	gs.give_lab_xp(gs.xp_for_level(28) - gs.lab_xp)
	var now: int = gs.job_board.size()
	gs.refresh_job_board(5)
	var after: int = gs.job_board.size()
	gs.free()
	if before != 3 or now != 3 or after != 4:
		return "Level 28 mid-day: board %d -> %d, next refresh %d (want 3, 3, 4)." % [before, now, after]
	return ""


func test_the_note_says_when_the_next_slot_opens() -> String:
	var gs: GameStateScript = _state()
	var problem: String = ""
	_at(gs, 27)
	if gs.job_board_slot_note() != "A fourth job at lab level 28.":
		problem = "Level 27 note: '%s'" % gs.job_board_slot_note()
	_at(gs, 28)
	if problem == "" and gs.job_board_slot_note() != "A fifth job at lab level 65.":
		problem = "Level 28 note: '%s'" % gs.job_board_slot_note()
	_at(gs, 65)
	if problem == "" and gs.job_board_slot_note() != "":
		problem = "Both slots open, no note: '%s'" % gs.job_board_slot_note()
	_at(gs, 1)
	if problem == "" and gs.job_board_slot_note() != "":
		problem = "A shut board has no slot note: '%s'" % gs.job_board_slot_note()
	# Lab level 20 with Provisional credibility: the band shuts the board.
	_at(gs, 20)
	gs.credibility = 0
	if problem == "" and (gs.job_board_note() == "" or gs.job_board_slot_note() != ""):
		problem = "A board shut by credibility has no slot note: '%s'" % gs.job_board_slot_note()
	gs.credibility = 9999
	if problem == "" and gs.job_board_slot_note() != "A fourth job at lab level 28.":
		problem = "Open by band at level 20 names the 4th job: '%s'" % gs.job_board_slot_note()
	gs.free()
	return problem


func test_an_old_save_keeps_its_board_of_three() -> String:
	var gs: GameStateScript = _state()
	_at(gs, 20)
	gs.refresh_job_board(2)
	var data: Dictionary = gs.farm_to_dict()
	data.erase("lab_gates_kept")
	var loaded: GameStateScript = _state()
	var read: String = loaded.farm_from_dict(data)
	var problem: String = ""
	if read != "":
		problem = "An old save loads: %s" % read
	elif loaded.job_board.size() != 3 or loaded.job_board_size() != 3:
		problem = "The old board stays 3 until a refresh: %d, size %d." % [loaded.job_board.size(), loaded.job_board_size()]
	elif "board_4_jobs" in loaded.lab_gates_kept:
		problem = "A save from before the row does not keep it."
	gs.free()
	loaded.free()
	return problem


func test_an_old_save_at_level_28_grows_at_the_next_refresh() -> String:
	var gs: GameStateScript = _state()
	_at(gs, 40)
	gs.refresh_job_board(2)
	gs.job_board.resize(3)
	var data: Dictionary = gs.farm_to_dict()
	data.erase("lab_gates_kept")
	var loaded: GameStateScript = _state()
	var problem: String = ""
	if loaded.farm_from_dict(data) != "":
		problem = "An old save loads."
	elif loaded.job_board.size() != 3:
		problem = "The saved 3 offers stay 3 on load: %d." % loaded.job_board.size()
	elif "board_5_jobs" in loaded.lab_gates_kept or "board_4_jobs" in loaded.lab_gates_kept:
		problem = "Neither new row is kept: %s" % [loaded.lab_gates_kept]
	else:
		loaded.refresh_job_board(3)
		if loaded.job_board.size() != 4:
			problem = "Level 40 grows to 4 at the next refresh: %d." % loaded.job_board.size()
	gs.free()
	loaded.free()
	return problem


func test_the_rotation_at_size_5_is_steady_and_moves_by_day() -> String:
	var gs: GameStateScript = _state()
	_at(gs, 70)
	var seen: Dictionary = {}
	var problem: String = ""
	for day: int in range(1, 7):
		gs.refresh_job_board(day)
		var first: Array = _ids(gs)
		gs.refresh_job_board(day)
		if _ids(gs) != first or first.size() != 5:
			problem = "Day %d is not steady or not five: %s then %s." % [day, first, _ids(gs)]
		seen[str(first)] = true
	if problem == "" and seen.size() < 2:
		problem = "The board never changes across six days."
	gs.free()
	return problem


func test_the_phone_lists_five_offers_and_scrolls() -> String:
	var hud: FieldPhoneHUD = HudScene.instantiate() as FieldPhoneHUD
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var offers: Array[Dictionary] = []
	for i: int in 5:
		offers.append({ "text": "Kestrel: a long tire pressure gauge job number %d (pressure), 150 CR, 2 days" % i, "disabled": false })
	hud.show_jobs(PackedStringArray(["JOB-0001 Lin: a soil probe, due day 7, 100 CR"]), offers, "", "")
	hud._fit_jobs_scroll()
	var buttons: int = 0
	for child: Node in hud._jobs_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			buttons += 1
			if (child as Button).autowrap_mode == TextServer.AUTOWRAP_OFF:
				buttons = -100
	var scroll: ScrollContainer = hud._jobs_scroll
	var problem: String = ""
	if buttons != 5:
		problem = "Five offers, five buttons wrapped: %d." % buttons
	elif scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		problem = "Offers wrap, never scroll sideways."
	elif scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		problem = "Five offers need the list to scroll up and down."
	elif hud._jobs_box.get_combined_minimum_size().y <= hud.scaled(hud.JOBS_MAX_HEIGHT):
		problem = "Five wrapped offers must be taller than the box (%f)." % hud._jobs_box.get_combined_minimum_size().y
	elif absf(scroll.custom_minimum_size.y - hud.scaled(hud.JOBS_MAX_HEIGHT)) > 0.01:
		problem = "The box stops at its cap, %f." % scroll.custom_minimum_size.y
	for old: Node in hud._jobs_box.get_children():
		hud._jobs_box.remove_child(old)
		old.free()
	hud.show_jobs(PackedStringArray(), offers, "", "A fourth job at lab level 28.")
	var last: Node = null
	for child: Node in hud._jobs_box.get_children():
		if not child.is_queued_for_deletion():
			last = child
	if problem == "" and (not last is Label or (last as Label).text != "A fourth job at lab level 28." \
			or (last as Label).get_theme_color("font_color") != ScopeTheme.INK_MUTED):
		problem = "The slot note is a muted caption under the offers."
	for old: Node in hud._jobs_box.get_children():
		hud._jobs_box.remove_child(old)
		old.free()
	(Engine.get_main_loop() as SceneTree).root.remove_child(hud)
	hud.free()
	return problem
