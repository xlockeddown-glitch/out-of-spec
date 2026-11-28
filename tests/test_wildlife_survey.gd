extends RefCounted
## Colony wildlife survey quest (slice 33, docs/design/farm_animals.md section 4):
## field_hanging_scale drift/calibration/audit gating, weigh_animal rules,
## deterministic weights, guest->host co-op, save round-trip & old save,
## quest offer/completion/rewards, and world prompt/scale prop.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FarmCommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")


func _make_state(seed_value: int = 2026) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	gs.reset_credibility()
	gs.credits = 1000
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


func _calibrate_scale_clean(gs: GameStateScript) -> void:
	var scale: DriftingSensor = gs.get_sensor(gs.HANGING_SCALE_ID)
	scale.error = 0.0
	scale.cal_due_day = GameClock.get_day_index() + 5


func test_weighing_refused_below_trust_one() -> String:
	var gs: GameStateScript = _make_state()
	_calibrate_scale_clean(gs)
	gs.animal_groups["dome_hen"] = { "trust": 0, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
	var xp_before: int = gs.skill_xp("agronomy", gs.local_player_id)
	var res: Dictionary = gs.weigh_animal("dome_hen", gs.local_player_id)
	var problem: String = ""
	if res.get("ok", false) or res.get("accepted", false):
		problem = "Weighing below trust 1 must be refused, got %s." % [res]
	elif int(gs.survey_weighings.get("dome_hen", 0)) != 0:
		problem = "Refused weighing must not increment survey_weighings."
	elif gs.skill_xp("agronomy", gs.local_player_id) != xp_before:
		problem = "Refused weighing must not award XP."
	elif gs.animal_weighed_today():
		problem = "Refused weighing must not use up today's weighing."
	_done(gs)
	return problem


func test_accepted_weighing_counter_xp_and_one_per_day() -> String:
	var gs: GameStateScript = _make_state()
	_calibrate_scale_clean(gs)
	gs.animal_groups["dome_hen"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
	gs.animal_groups["dome_goat"] = { "trust": 2, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
	var xp_before: int = gs.skill_xp("agronomy", gs.local_player_id)
	var first: Dictionary = gs.weigh_animal("dome_hen", gs.local_player_id)
	var second_same_day: Dictionary = gs.weigh_animal("dome_goat", gs.local_player_id)
	var xp_after: int = gs.skill_xp("agronomy", gs.local_player_id)
	var problem: String = ""
	if not first.get("ok", false) or not first.get("accepted", false):
		problem = "First weighing with calibrated scale must be accepted, got %s." % [first]
	elif int(gs.survey_weighings.get("dome_hen", 0)) != 1:
		problem = "Expected survey_weighings['dome_hen'] == 1, got %s." % [gs.survey_weighings]
	elif xp_after != xp_before + 5:
		problem = "Expected +5 Agronomy XP on accepted weighing, got +%d." % (xp_after - xp_before)
	elif not gs.animal_weighed_today():
		problem = "Accepted weighing must mark animal_weighed_today()."
	elif second_same_day.get("ok", false) or second_same_day.get("accepted", false):
		problem = "Second weighing on the same day must be refused, got %s." % [second_same_day]
	else:
		# Next day allows weighing again.
		GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
		var next_day: Dictionary = gs.weigh_animal("dome_goat", gs.local_player_id)
		if not next_day.get("accepted", false) or int(gs.survey_weighings.get("dome_goat", 0)) != 1:
			problem = "Weighing on the next day should be accepted, got %s." % [next_day]
	_done(gs)
	return problem


func test_drifted_scale_rejected_then_accepted_after_calibration() -> String:
	var gs: GameStateScript = _make_state()
	gs.animal_groups["dome_rabbit"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
	var scale: DriftingSensor = gs.get_sensor(gs.HANGING_SCALE_ID)
	scale.error = scale.mpe * 1.5
	scale.cal_due_day = GameClock.get_day_index() + 5
	var xp_before: int = gs.skill_xp("agronomy", gs.local_player_id)
	var rejected: Dictionary = gs.weigh_animal("dome_rabbit", gs.local_player_id)
	var problem: String = ""
	if rejected.get("ok", false) or rejected.get("accepted", false):
		problem = "Drifted scale weighing must be rejected, got %s." % [rejected]
	elif str(rejected.get("reason", "")) != "Scale out of tolerance. Calibrate it first.":
		problem = "Unexpected rejection reason: '%s'." % str(rejected.get("reason", ""))
	elif int(gs.survey_weighings.get("dome_rabbit", 0)) != 0:
		problem = "Rejected weighing must not increment survey_weighings."
	elif gs.skill_xp("agronomy", gs.local_player_id) != xp_before:
		problem = "Rejected weighing must not award XP."
	elif gs.animal_weighed_today():
		problem = "Rejected weighing must NOT consume today's weighing."
	elif absf(float(rejected.get("reading_kg", 0.0)) - (float(rejected.get("true_kg", 0.0)) + scale.error)) > 1e-4:
		problem = "Reading must include scale error: %s." % [rejected]
	else:
		# Calibrate at bench against gravimetric_kit, then retry same day.
		var cal_rec: Dictionary = gs.calibrate_at_bench(gs.HANGING_SCALE_ID, gs.local_player_id)
		if cal_rec.get("refused", false):
			problem = "Bench calibration of field_hanging_scale was refused: %s." % [cal_rec]
		else:
			var accepted: Dictionary = gs.weigh_animal("dome_rabbit", gs.local_player_id)
			if not accepted.get("accepted", false) or int(gs.survey_weighings.get("dome_rabbit", 0)) != 1:
				problem = "Weighing after calibration on the same day must be accepted, got %s." % [accepted]
	_done(gs)
	return problem


func test_weight_deterministic_and_within_ten_percent() -> String:
	var gs: GameStateScript = _make_state(777)
	var expected_bases: Dictionary = { "dome_hen": 1.8, "dome_goat": 35.0, "dome_rabbit": 2.4 }
	var problem: String = ""
	for group_id: String in expected_bases:
		var base_kg: float = float(gs.animal_group(group_id).get("weight_kg", 0.0))
		if absf(base_kg - float(expected_bases[group_id])) > 1e-4:
			problem = "Unexpected base weight for %s: %s." % [group_id, base_kg]
			break
		for day: int in range(1, 25):
			var w1: float = GameStateScript.animal_true_weight_kg(777, group_id, day, base_kg, 0.1)
			var w2: float = GameStateScript.animal_true_weight_kg(777, group_id, day, base_kg, 0.1)
			if absf(w1 - w2) > 1e-9:
				problem = "Weight not deterministic for %s day %d." % [group_id, day]
				break
			if w1 < base_kg * 0.9 - 1e-6 or w1 > base_kg * 1.1 + 1e-6:
				problem = "Weight %f for %s day %d outside ±10 %% of %f." % [w1, group_id, day, base_kg]
				break
		if problem != "":
			break
	_done(gs)
	return problem


func test_guest_weigh_request_goes_through_host_and_syncs() -> String:
	var host: GameStateScript = _make_state(42)
	var guest_state: GameStateScript = _make_state(42)
	_calibrate_scale_clean(host)
	host.animal_groups["dome_hen"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }

	var host_cmd: FarmCommandsScript = FarmCommandsScript.new()
	host_cmd.state = host
	var guest_cmd: FarmCommandsScript = FarmCommandsScript.new()
	guest_cmd.state = guest_state
	guest_cmd.guest = true
	var routed: Array[StringName] = []
	guest_cmd.remote = func(action: StringName, arguments: Array) -> Variant:
		routed.append(action)
		return host_cmd.execute("player_2", action, arguments)

	var problem: String = ""
	var res1: Variant = await guest_cmd.request(&"weigh_animal", ["dome_hen"])
	var res2: Variant = await guest_cmd.request(&"weigh_animal", ["dome_hen"])
	if routed.size() != 2 or routed[0] != &"weigh_animal":
		problem = "Guest weigh_animal must route through host remote, got %s." % [routed]
	elif not (res1 is Dictionary and (res1 as Dictionary).get("accepted", false)):
		problem = "Host should accept guest's first weighing, got %s." % [res1]
	elif res2 is Dictionary and (res2 as Dictionary).get("accepted", false):
		problem = "Host must refuse guest's second weighing on the same day."
	elif host.skill_xp("agronomy", "player_2") != 5:
		problem = "Weighing guest must receive +5 Agronomy XP on host, got %d." % host.skill_xp("agronomy", "player_2")
	else:
		var was_guest: bool = FarmCommands.guest
		FarmCommands.guest = false
		var bytes: PackedByteArray = FarmSync.capture(host)
		FarmCommands.guest = true
		var emitted: Array[bool] = [false]
		guest_state.animals_changed.connect(func() -> void: emitted[0] = true)
		var sync_err: String = FarmSync.update(bytes, guest_state)
		FarmCommands.guest = was_guest
		if sync_err != "":
			problem = "FarmSync.update failed: %s" % sync_err
		elif not emitted[0]:
			problem = "FarmSync.update should emit animals_changed on guest."
		elif int(guest_state.survey_weighings.get("dome_hen", 0)) != 1 or not guest_state.animal_weighed_today():
			problem = "Guest state did not sync survey_weighings/animal_weighed_day."

	guest_cmd.free()
	host_cmd.free()
	guest_state.free()
	_done(host)
	return problem


func test_save_round_trip_and_old_save_compatibility() -> String:
	var gs: GameStateScript = _make_state(99)
	_calibrate_scale_clean(gs)
	gs.animal_groups["dome_hen"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
	gs.weigh_animal("dome_hen", gs.local_player_id)
	var saved: Dictionary = gs.farm_to_dict()

	var loaded: GameStateScript = _make_state(1)
	var dict_err: String = loaded.farm_dict_problem(saved)
	var err: String = loaded.farm_from_dict(saved)
	var problem: String = ""
	if dict_err != "":
		problem = "farm_dict_problem rejected valid save: %s" % dict_err
	elif err != "":
		problem = "Save round-trip failed: %s" % err
	elif int(loaded.survey_weighings.get("dome_hen", 0)) != 1 or loaded.animal_weighed_day != GameClock.get_day_index():
		problem = "survey_weighings or animal_weighed_day did not round-trip: %s / %d." % [loaded.survey_weighings, loaded.animal_weighed_day]

	if problem == "":
		var old_save: Dictionary = saved.duplicate(true)
		old_save.erase("survey_weighings")
		old_save.erase("animal_weighed_day")
		var old_err: String = loaded.farm_from_dict(old_save)
		if old_err != "":
			problem = "Old save without survey fields failed to load: %s" % old_err
		elif not loaded.survey_weighings.is_empty() or loaded.animal_weighed_day != -1:
			problem = "Old save must reset survey_weighings and animal_weighed_day to empty/-1."

	loaded.free()
	_done(gs)
	return problem


func test_quest_offered_at_trust_one_and_completes_paying_once() -> String:
	var gs: GameStateScript = _make_state(55)
	_calibrate_scale_clean(gs)
	gs.update_quests()
	var problem: String = ""
	if gs.quest_state.has(gs.WILDLIFE_SURVEY_QUEST):
		problem = "Survey quest must not be offered before any group reaches trust 1."

	if problem == "":
		gs.animal_groups["dome_hen"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs.animal_groups["dome_goat"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs.animal_groups["dome_rabbit"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs.update_quests()
		if not gs.wildlife_survey_active():
			problem = "Survey quest must be offered once any group reaches trust 1."

	if problem == "":
		var credits_before: int = gs.credits
		var lab_xp_before: int = gs.lab_xp
		# Weigh each species on consecutive days (in non-listed order to verify any_order).
		var groups: Array[String] = ["dome_goat", "dome_hen", "dome_rabbit"]
		for i: int in groups.size():
			if i > 0:
				GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
				_calibrate_scale_clean(gs)
			var r: Dictionary = gs.weigh_animal(groups[i], gs.local_player_id)
			if not r.get("accepted", false):
				problem = "Weighing %s failed: %s" % [groups[i], r]
				break
			gs.update_quests()
		if problem == "":
			if not QuestEngine.is_done(gs, gs.WILDLIFE_SURVEY_QUEST):
				problem = "Survey quest must be done after weighing all three groups."
			elif gs.credits != credits_before + 120:
				problem = "Expected +120 CR quest reward, got +%d." % (gs.credits - credits_before)
			elif gs.lab_xp != lab_xp_before + 150:
				problem = "Expected +150 lab XP quest reward, got +%d." % (gs.lab_xp - lab_xp_before)
			else:
				# Running update_quests again must not pay rewards twice.
				gs.update_quests()
				if gs.credits != credits_before + 120 or gs.lab_xp != lab_xp_before + 150:
					problem = "Quest rewards must only be paid once."
	_done(gs)
	return problem


func test_scale_instrument_lists_budget_drift_and_audit_gating() -> String:
	var gs: GameStateScript = _make_state(88)
	var scale: DriftingSensor = gs.get_sensor(gs.HANGING_SCALE_ID)
	var problem: String = ""
	if scale == null:
		problem = "field_hanging_scale must be registered in GameState.sensors."
	elif scale.error_unit != "kg":
		problem = "Expected field_hanging_scale unit 'kg', got '%s'." % scale.error_unit
	elif not gs.bench_unit_ids().has(gs.HANGING_SCALE_ID):
		problem = "field_hanging_scale must appear in bench_unit_ids()."
	elif gs.unit_ids().has(gs.HANGING_SCALE_ID):
		problem = "field_hanging_scale must stay out of unit_ids() (audits) before quest is offered."
	else:
		var budget: Dictionary = gs.calibration_budget(gs.HANGING_SCALE_ID, gs.local_player_id)
		if budget.is_empty() or budget.get("refused", true):
			problem = "field_hanging_scale calibration budget must not be refused: %s." % [budget]

	# Audit before quest is offered must NOT fine for an out-of-tolerance / overdue scale.
	if problem == "":
		# Put all other audited units and standards in spec & in date.
		var audit_day: int = 5
		GameClock.elapsed_days = float(audit_day - 1)
		for id: String in gs.unit_ids():
			var s: DriftingSensor = gs.get_sensor(id)
			s.error = 0.0
			s.cal_due_day = audit_day + 5
		for id: String in gs.standard_ids():
			gs.get_sensor(id).cal_due_day = audit_day + 30
		# Make the scale severely out of tolerance and overdue.
		scale.error = scale.mpe * 3.0
		scale.cal_due_day = 0
		gs.audit_grace_used = true
		var credits_before: int = gs.credits
		gs._run_audit(audit_day)
		if gs.credits != credits_before:
			problem = "Audit before survey quest is offered must not fine for field_hanging_scale (credits %d -> %d)." % [credits_before, gs.credits]

	# Once the survey quest IS offered, the scale enters unit_ids() and is audited.
	if problem == "":
		gs.animal_groups["dome_hen"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs.update_quests()
		if not gs.quest_state.has(gs.WILDLIFE_SURVEY_QUEST):
			problem = "Survey quest must be offered at trust 1."
		elif gs.unit_ids().has(gs.HANGING_SCALE_ID):
			problem = "field_hanging_scale must stay out of audits at the offer, until its first calibration."

	# Positive control: once offered AND calibrated once, a drifted, overdue scale is fined.
	if problem == "":
		var audit_day: int = 6
		GameClock.elapsed_days = float(audit_day - 1)
		scale.last_cal_day = 1
		if not gs.unit_ids().has(gs.HANGING_SCALE_ID):
			problem = "field_hanging_scale must enter unit_ids() once offered and calibrated."
		else:
			for id: String in gs.unit_ids():
				if id != gs.HANGING_SCALE_ID:
					gs.get_sensor(id).error = 0.0
					gs.get_sensor(id).cal_due_day = audit_day + 5
			scale.error = scale.mpe * 3.0
			scale.cal_due_day = 0
			var credits_before_fine: int = gs.credits
			gs._run_audit(audit_day)
			if gs.credits >= credits_before_fine:
				problem = "Audit must fine for a drifted, overdue field_hanging_scale once it is in service (credits %d -> %d)." % [credits_before_fine, gs.credits]

	_done(gs)
	return problem


func test_world_weigh_prompt_and_scale_prop() -> String:
	var saved_groups: Dictionary = GameState.animal_groups.duplicate(true)
	var saved_quests: Dictionary = GameState.quest_state.duplicate(true)
	var saved_weighed_day: int = GameState.animal_weighed_day
	var wa := WildAnimals.new()
	wa._build_groups()
	var hen_spot: Vector3 = wa._groups["dome_hen"]["spot_pos"]
	var problem: String = ""

	if Inspectable.display_name("field_hanging_scale") != "Hanging Field Scale":
		problem = "Unexpected scale display_name: %s." % Inspectable.display_name("field_hanging_scale")
	elif Inspectable.inspect_text("field_hanging_scale") == "Hanging Field Scale":
		problem = "field_hanging_scale must have a description in data/props.json."

	# Quest not active -> no weigh prompt even at trust 1.
	if problem == "":
		GameState.quest_state.erase(GameState.WILDLIFE_SURVEY_QUEST)
		GameState.animal_weighed_day = -1
		GameState.animal_groups["dome_hen"] = { "trust": 1, "fed_today": false, "unfed_streak": 0, "gifts": 2, "find_pending": false }
		if not wa.weigh_target(hen_spot).is_empty():
			problem = "weigh_target must be empty when survey quest is not active."

	# Quest active + trust 1 -> weigh prompt coexists with collect prompt without stealing it.
	if problem == "":
		GameState.quest_state[GameState.WILDLIFE_SURVEY_QUEST] = { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }
		var t_interact: Dictionary = wa.interact_target(hen_spot)
		var t_weigh: Dictionary = wa.weigh_target(hen_spot)
		if t_interact.get("kind", "") != "collect":
			problem = "Weigh prompt must not steal the collect interact target, got %s." % [t_interact]
		elif t_weigh.get("kind", "") != "weigh" or t_weigh.get("verb", "") != "Weigh hen":
			problem = "Expected 'Weigh hen' target, got %s." % [t_weigh]

	# Quest done -> weighing still allowed (designer's decision), so the V path keeps a target.
	if problem == "":
		GameState.quest_state[GameState.WILDLIFE_SURVEY_QUEST]["done"] = 3
		if wa.weigh_target(hen_spot).get("kind", "") != "weigh":
			problem = "weigh_target must stay available after the survey quest is done."
		elif GameState.wildlife_survey_active():
			problem = "A done survey quest must not count as active (prompt hides)."

	wa.free()
	GameState.animal_groups = saved_groups
	GameState.quest_state = saved_quests
	GameState.animal_weighed_day = saved_weighed_day
	return problem
