extends RefCounted
## The lab sitter (docs/design/zones.md section 9, build step 11): a new hire the
## farm books for one day from the dome's console. She waters and collects spools
## by the code robots and players use, never calibrates, and a free day is a
## one-use reward. Every GameState is freed and the clock is put back.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const CELL: Vector3i = Vector3i(0, 0, 0)
const OTHER: Vector3i = Vector3i(1, 0, 0)
const SPECIES: String = "cobalt_sentinel"


func _state(credits: int = 500) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.local_player_id = HOST
	gs.credits = credits
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 2.0  # day 3
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	gs.player_places[GUEST] = [ZonePresence.DOME, 0]
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


## A plot planted with its set point `steps` above the crop's target.
func _plant(gs: GameStateScript, cell: Vector3i, steps: int) -> void:
	gs.till(cell)
	gs.plant_crop(cell, "", steps)


func _target(gs: GameStateScript, cell: Vector3i) -> float:
	return float(gs.crop(gs.plantings[cell]["crop_id"]).get("soil_moisture_target", 0.0))


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


## What the sitter must never move: every sensor's error and due day, the
## calibration log and the certificates.
func _bench_state(gs: GameStateScript) -> Array:
	var out: Array = [gs.cal_log.size(), gs.certificate_log.size()]
	for id: Variant in gs.sensors:
		var sensor: DriftingSensor = gs.sensors[id]
		out.append([id, sensor.error, sensor.cal_due_day])
	return out


# --- The rules -----------------------------------------------------------------------

func test_the_sitter_is_data_with_a_plain_name_and_a_fee() -> String:
	if LabSitter.sitter_name() == "" or LabSitter.fee() != 40:
		return "The data gives her a name and 40 CR: %s, %d" % [LabSitter.sitter_name(), LabSitter.fee()]
	for key: String in ["booked_text", "report_text", "already", "short", "console_in_dome", "fee_text", "free_text"]:
		if LabSitter.text(key) == "":
			return "The data has no '%s' text." % key
	return ""


func test_a_booking_is_always_the_next_day_with_nothing_done() -> String:
	if LabSitter.booked_day(3) != 4 or LabSitter.new_booking(4) != { "day": 4, "days": 1, "paid": 0, "watered": 0, "spools": 0 }:
		return "Booked on day 3 she works day 4, with nothing done."
	return ""


func test_the_trim_runs_to_the_target_as_far_as_the_set_point_goes() -> String:
	if LabSitter.trim_steps(0.40, 45.0, 0.45, 0.01) != -5:
		return "45 percent to a target of 0.40 is 5 steps down, got %d." % LabSitter.trim_steps(0.40, 45.0, 0.45, 0.01)
	if LabSitter.trim_steps(0.40, 40.0, 0.40, 0.01) != 0:
		return "A plot on target needs no trim."
	if LabSitter.trim_steps(0.40, 30.0, 0.30, 0.01) != 10:
		return "30 percent to 0.40 is 10 steps up."
	if LabSitter.trim_steps(0.90, 10.0, 0.97, 0.01) != 3:
		return "The set point stops at 1: %d." % LabSitter.trim_steps(0.90, 10.0, 0.97, 0.01)
	if LabSitter.trim_steps(0.10, 90.0, 0.04, 0.01) != -4:
		return "The set point stops at 0: %d." % LabSitter.trim_steps(0.10, 90.0, 0.04, 0.01)
	return ""


func test_a_saved_booking_is_checked() -> String:
	if LabSitter.booking_problem({}) != "" or LabSitter.booking_problem(LabSitter.new_booking(4)) != "":
		return "No booking and a good booking must load."
	for bad: Variant in [3, [], { "day": 4 }, { "day": 4, "watered": 0, "spools": "0" }, { "day": 0, "watered": 0, "spools": 0 },
			{ "day": 4, "watered": -1, "spools": 0 }, { "day": 4, "watered": 0, "spools": 5000 },
			{ "day": 4, "days": 1, "paid": 0, "watered": 0, "spools": 0, "extra": 1 }, { "day": 4.0, "watered": 0, "spools": 0 }]:
		if LabSitter.booking_problem(bad) == "":
			return "A bad booking was accepted: %s" % [bad]
	return ""


# --- Booking -------------------------------------------------------------------------

func test_booking_takes_the_fee_once_and_books_the_next_day() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if gs.book_lab_sitter(4) != "":
		problems.append("A booking with enough credits was refused.")
	if gs.credits != 460 or gs.lab_sitter != { "day": 4, "days": 1, "paid": 40, "watered": 0, "spools": 0 }:
		problems.append("40 CR taken and day 4 booked: %d, %s" % [gs.credits, gs.lab_sitter])
	if gs.book_lab_sitter(4) == "" or gs.credits != 460:
		problems.append("A second booking was allowed or took credits again: %d" % gs.credits)
	if _lines(gs, LabSitter.sitter_name()) != 1:
		problems.append("The phone must say the booking once.")
	_done(gs)
	return "\n".join(problems)


func test_booking_is_refused_short_of_credits_and_away_from_the_dome() -> String:
	var gs: GameStateScript = _state(39)
	var problems: Array[String] = []
	var reason: String = gs.book_lab_sitter(4)
	if reason == "" or not gs.lab_sitter.is_empty() or gs.credits != 39 or not reason.contains("40 CR"):
		problems.append("39 CR must not book her, and the reason names the fee: '%s'" % reason)
	gs.credits = 500
	gs.player_places[HOST] = [ZonePresence.FARM, 0]
	if gs.book_lab_sitter(4) != LabSitter.text("console_in_dome") or not gs.lab_sitter.is_empty() or gs.credits != 500:
		problems.append("Away from the dome's console nothing is booked or paid.")
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	gs.credits = 40
	if gs.book_lab_sitter(4) != "" or gs.credits != 0:
		problems.append("Exactly 40 CR must book her.")
	_done(gs)
	return "\n".join(problems)


func test_the_reward_books_her_free_and_is_spent_once() -> String:
	var gs: GameStateScript = _state(10)
	var problems: Array[String] = []
	if gs.one_use_count(GameStateScript.ONE_USE_SITTER) != 0 or not gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER):
		problems.append("The farm could not be given the reward.")
	if gs.give_one_use(GameStateScript.ONE_USE_SITTER, HOST):
		problems.append("A player was given the farm's reward.")
	if gs.book_lab_sitter(4) != "":
		problems.append("The reward did not book her with 10 CR in the wallet.")
	if gs.credits != 10 or gs.one_use_count(GameStateScript.ONE_USE_SITTER) != 0 or gs.lab_sitter.is_empty():
		problems.append("Free means no credits taken and the reward spent: %d, %d" % [gs.credits, gs.one_use_count(GameStateScript.ONE_USE_SITTER)])
	if _lines(gs, QuestEngine.one_use_used_line(GameStateScript.ONE_USE_SITTER)) != 1:
		problems.append("The phone must say the reward was used.")
	_done(gs)
	return "\n".join(problems)


func test_a_refused_booking_keeps_the_reward() -> String:
	var gs: GameStateScript = _state(500)
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	gs.player_places[HOST] = [ZonePresence.FARM, 0]
	var refused: String = gs.book_lab_sitter(4)
	var kept: int = gs.one_use_count(GameStateScript.ONE_USE_SITTER)
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	gs.book_lab_sitter(4)
	var again: String = gs.book_lab_sitter(4)
	var left: int = gs.one_use_count(GameStateScript.ONE_USE_SITTER)
	_done(gs)
	if refused == "" or kept != 2:
		return "A booking refused away from the dome must keep the reward."
	if again == "" or left != 1:
		return "A second booking must be refused and must not spend a reward."
	return ""


func test_a_booking_for_the_wrong_day_is_refused_and_costs_nothing() -> String:
	var gs: GameStateScript = _state(500)
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	var problems: Array[String] = []
	for wrong: int in [3, 5]:
		if gs.book_lab_sitter(wrong) != LabSitter.text("new_day") or not gs.lab_sitter.is_empty():
			problems.append("A booking for day %d, with day 4 next, was not refused." % wrong)
	if gs.credits != 500 or gs.one_use_count(GameStateScript.ONE_USE_SITTER) != 1:
		problems.append("A refused booking took the reward or credits.")
	# The screen showed day 4; the clock crossed 06:00 before the host ran it.
	GameClock.elapsed_days = 3.0
	if gs.book_lab_sitter(4) == "" or not gs.lab_sitter.is_empty():
		problems.append("A booking sent for day 4 on day 4 must not book day 5.")
	if gs.book_lab_sitter(5) != "" or int(gs.lab_sitter.get("day", 0)) != 5:
		problems.append("The new tomorrow, day 5, can be booked: %s" % [gs.lab_sitter])
	_done(gs)
	return "
".join(problems)


func test_a_booking_is_in_place_before_the_money_and_reward_move() -> String:
	var gs: GameStateScript = _state(500)
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	var seen: Array = []
	gs.one_use_changed.connect(func() -> void: seen.append(gs.lab_sitter.duplicate()))
	gs.credits_changed.connect(func(_c: int) -> void: seen.append(gs.lab_sitter.duplicate()))
	gs.book_lab_sitter(4)
	gs.lab_sitter = {}
	gs.book_lab_sitter(4)
	var problems: Array[String] = []
	if seen.size() != 2 or seen[0].is_empty() or seen[1].is_empty():
		problems.append("A screen hearing the reward or the charge must already see her booked: %s" % [seen])
	if gs.credits != 460:
		problems.append("The second booking, with no reward left, took 40 CR: %d" % gs.credits)
	_done(gs)
	return "
".join(problems)


func test_a_free_fee_does_not_spend_a_reward() -> String:
	var gs: GameStateScript = _state(500)
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	var table: Dictionary = DataManager._raw[&"economy"]
	var shipped: Dictionary = table["lab_sitter"]
	var cheap: Dictionary = shipped.duplicate()
	cheap["fee_credits"] = 0
	table["lab_sitter"] = cheap
	var booked: String = gs.book_lab_sitter(4)
	table["lab_sitter"] = shipped
	var kept: int = gs.one_use_count(GameStateScript.ONE_USE_SITTER)
	_done(gs)
	if booked != "" or kept != 1:
		return "A day that costs nothing must keep the reward: '%s', %d left." % [booked, kept]
	return ""


func test_the_booking_command_runs_for_the_host_and_a_guest() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var problems: Array[String] = []
	if not &"book_lab_sitter" in CommandsScript.ACTIONS or commands.problem(&"book_lab_sitter", [4, 1]) != "":
		problems.append("book_lab_sitter must be a farm command that takes the day.")
	if commands.problem(&"book_lab_sitter", [4]) == "" or commands.problem(&"book_lab_sitter", []) == "" or commands.problem(&"book_lab_sitter", ["x"]) == "":
		problems.append("A booking with no day, or a word for the day, must be refused.")
	gs.player_places[GUEST] = [ZonePresence.FARM, 0]
	if commands.execute(GUEST, &"book_lab_sitter", [4, 1]) == "" or not gs.lab_sitter.is_empty():
		problems.append("A guest away from the dome booked her.")
	gs.player_places[GUEST] = [ZonePresence.DOME, 0]
	if commands.execute(GUEST, &"book_lab_sitter", [4, 1]) != "" or gs.lab_sitter.is_empty() or gs.credits != 460:
		problems.append("A guest in the dome could not book her from the shared wallet: %d" % gs.credits)
	if commands.execute(HOST, &"book_lab_sitter", [4, 1]) == "" or gs.credits != 460:
		problems.append("The host booked her a second time.")
	commands.free()
	_done(gs)
	return "\n".join(problems)


# --- Her day -------------------------------------------------------------------------

func test_she_waters_by_the_set_point_trim_and_only_once_a_round() -> String:
	var gs: GameStateScript = _state()
	_plant(gs, CELL, 5)
	_plant(gs, OTHER, 0)
	gs.book_lab_sitter(4)
	var problems: Array[String] = []
	var over: float = float(gs.plantings[CELL]["setpoint"])
	if not is_equal_approx(over, _target(gs, CELL) + 0.05):
		problems.append("The setup did not leave a plot 5 steps over.")
	gs._open_lab_sitter(3)
	if not is_equal_approx(float(gs.plantings[CELL]["setpoint"]), over) or gs.lab_sitter["watered"] != 0:
		problems.append("She worked the day before her day.")
	gs._open_lab_sitter(4)
	if not is_equal_approx(float(gs.plantings[CELL]["setpoint"]), _target(gs, CELL)):
		problems.append("The plot was not trimmed to its target: %s" % gs.plantings[CELL]["setpoint"])
	if gs.lab_sitter["watered"] != 1:
		problems.append("One plot was trimmed (the other was on target): %s" % [gs.lab_sitter])
	gs._open_lab_sitter(4)
	if gs.lab_sitter["watered"] != 1:
		problems.append("A second round on a settled plot counted again: %s" % [gs.lab_sitter])
	_done(gs)
	return "\n".join(problems)


func test_she_collects_the_domes_spool_and_a_tanks_once() -> String:
	var gs: GameStateScript = _state()
	gs.catch_species(SPECIES)
	gs.molt_stage = GameStateScript.MoltStage.MOLTED
	gs.enclosures[SPECIES]["molt_stage"] = int(GameStateScript.MoltStage.MOLTED)
	var before: int = gs.optical_silk_spools
	var xp_before: Dictionary = gs.player_skill_xp.duplicate(true)
	gs.book_lab_sitter(4)
	gs._open_lab_sitter(4)
	var problems: Array[String] = []
	if gs.optical_silk_spools != before + 2 or gs.lab_sitter["spools"] != 2:
		problems.append("Both spools must be collected: %d, %s" % [gs.optical_silk_spools - before, gs.lab_sitter])
	if gs.is_spool_ready() or gs.is_enclosure_spool_ready(SPECIES):
		problems.append("The tanks were not reset by the collecting.")
	gs._open_lab_sitter(4)
	if gs.optical_silk_spools != before + 2 or gs.lab_sitter["spools"] != 2:
		problems.append("A second round collected again.")
	if gs.player_skill_xp != xp_before:
		problems.append("The Manager's collecting gave a player skill XP.")
	_done(gs)
	return "\n".join(problems)


func test_she_never_calibrates_or_touches_a_reading() -> String:
	var gs: GameStateScript = _state()
	_plant(gs, CELL, 5)
	gs.molt_stage = GameStateScript.MoltStage.MOLTED
	for id: Variant in gs.sensors:
		(gs.sensors[id] as DriftingSensor).advance_days(40.0)
	gs.book_lab_sitter(4)
	var before: Array = _bench_state(gs)
	var drifted: bool = false
	for entry: Variant in before.slice(2):
		drifted = drifted or not is_zero_approx(float((entry as Array)[1]))
	var problems: Array[String] = []
	if not drifted:
		problems.append("The setup left every sensor with no drift, so the test would prove nothing.")
	gs._open_lab_sitter(4)
	gs._close_lab_sitter(5)
	if _bench_state(gs) != before:
		problems.append("She changed a sensor, a calibration or a certificate.")
	if gs.optical_silk_spools != 1 or not gs.lab_sitter.is_empty():
		problems.append("She did her work and her day closed.")
	_done(gs)
	return "\n".join(problems)


func test_the_day_closes_with_the_dispatch_line_and_she_is_done() -> String:
	var gs: GameStateScript = _state()
	_plant(gs, CELL, 5)
	gs.molt_stage = GameStateScript.MoltStage.MOLTED
	gs.book_lab_sitter(4)
	GameClock.elapsed_days = 3.0
	gs._on_day_started(4)
	var problems: Array[String] = []
	if gs.lab_sitter.get("watered", 0) != 1 or gs.lab_sitter.get("spools", 0) != 1:
		problems.append("The morning of her day did the work: %s" % [gs.lab_sitter])
	if _lines(gs, "kept the lab in good order") != 0:
		problems.append("The report came before the day ended.")
	GameClock.elapsed_days = 4.0
	gs._on_day_started(5)
	if not gs.lab_sitter.is_empty():
		problems.append("She was still booked after her day.")
	if _lines(gs, "kept the lab in good order") != 1 or _lines(gs, "Spools collected: 1") != 1 or _lines(gs, "Plots trimmed to their target: 1") != 1:
		problems.append("The report must say what was done, once: %s" % [gs.phone_log])
	if _lines(gs, "Nothing was calibrated") != 1:
		problems.append("The report must say nothing was calibrated.")
	GameClock.elapsed_days = 5.0
	gs._on_day_started(6)
	if _lines(gs, "kept the lab in good order") != 1:
		problems.append("A later day reported again.")
	_done(gs)
	return "\n".join(problems)


func test_the_closing_round_does_the_work_that_came_up_during_her_day() -> String:
	var gs: GameStateScript = _state()
	gs.book_lab_sitter(4)
	gs._open_lab_sitter(4)
	if gs.lab_sitter["watered"] != 0 or gs.lab_sitter["spools"] != 0:
		return "The morning had nothing to do: %s" % [gs.lab_sitter]
	# During day 4 a plot is planted off its target and a spool comes ready.
	GameClock.elapsed_days = 3.0
	_plant(gs, CELL, 5)
	gs.molt_stage = GameStateScript.MoltStage.MOLTED
	GameClock.elapsed_days = 4.0
	gs._close_lab_sitter(5)
	var problems: Array[String] = []
	if absf(float(gs.plantings[CELL]["setpoint"]) - _target(gs, CELL)) > 0.0001:
		problems.append("The closing round did not trim the new plot: %s" % [gs.plantings[CELL]["setpoint"]])
	if gs.optical_silk_spools != 1:
		problems.append("The closing round did not collect the spool.")
	if _lines(gs, "Plots trimmed to their target: 1") != 1 or _lines(gs, "Spools collected: 1") != 1:
		problems.append("The report must give the day's totals: %s" % [gs.phone_log])
	_done(gs)
	return "
".join(problems)


func test_her_trim_counts_for_the_booked_day_and_robots_come_first() -> String:
	var gs: GameStateScript = _state()
	gs.till(CELL)
	gs.plant_crop(CELL, "lensberry", 6)
	var cell_plant: Dictionary = gs.plantings[CELL]
	var problems: Array[String] = []
	if str(cell_plant["crop_id"]) != "lensberry":
		return "The setup could not plant a lensberry."
	gs.book_lab_sitter(4)
	# Day 3 ends out of band; day 4's morning she trims; day 4 must stay in band.
	gs._note_soil_excursions(false)
	if not bool(cell_plant.get("out_today", false)):
		problems.append("The setup: a plot 6 steps over must be out of band today.")
	GameClock.elapsed_days = 3.0
	gs._on_day_started(4)
	if absf(float(cell_plant["setpoint"]) - _target(gs, CELL)) > 0.0001:
		problems.append("She did not trim the lensberry in the morning.")
	if bool(cell_plant.get("out_today", false)):
		problems.append("Her morning trim must count for day 4: the plot was marked out of band at dawn.")
	if int(cell_plant["out_of_band_days"]) != 1:
		problems.append("Day 3 counts once: %d" % int(cell_plant["out_of_band_days"]))
	GameClock.elapsed_days = 4.0
	gs._on_day_started(5)
	GameClock.elapsed_days = 5.0
	gs._on_day_started(6)
	if int(cell_plant["out_of_band_days"]) != 1:
		problems.append("Days 4 and 5 were on target but counted: %d" % int(cell_plant["out_of_band_days"]))
	_done(gs)
	return "
".join(problems)


func test_a_booking_that_was_slept_past_still_closes() -> String:
	var gs: GameStateScript = _state()
	gs.book_lab_sitter(4)
	gs._close_lab_sitter(4)
	var still: bool = not gs.lab_sitter.is_empty()
	gs._close_lab_sitter(9)
	var gone: bool = gs.lab_sitter.is_empty()
	_done(gs)
	return "" if still and gone else "She closes after her day, not on it (%s, %s)." % [still, gone]


# --- Saves and guests ----------------------------------------------------------------

func test_the_booking_is_saved_and_an_old_save_has_none() -> String:
	var gs: GameStateScript = _state()
	gs.book_lab_sitter(4)
	gs.lab_sitter["watered"] = 2
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var problems: Array[String] = []
	if data.get("lab_sitter", {}) != { "day": 4, "days": 1, "paid": 40, "watered": 2, "spools": 0 }:
		problems.append("The save did not hold the booking: %s" % [data.get("lab_sitter")])
	var back: GameStateScript = _state()
	var heard: Array[int] = [0]
	back.lab_sitter_changed.connect(func() -> void: heard[0] += 1)
	if back.farm_from_dict(data) != "" or back.lab_sitter != { "day": 4, "days": 1, "paid": 40, "watered": 2, "spools": 0 }:
		problems.append("The booking was not loaded: %s" % [back.lab_sitter])
	if heard[0] < 1:
		problems.append("A load did not tell the screens.")
	data.erase("lab_sitter")
	var old: GameStateScript = _state()
	if old.farm_from_dict(data) != "" or not old.lab_sitter.is_empty():
		problems.append("An old save was refused or came with a booking.")
	for bad: Variant in [3, { "day": 4 }, { "day": 4, "watered": -1, "spools": 0 }]:
		var junk: Dictionary = gs.farm_to_dict()
		junk["lab_sitter"] = bad
		if gs.farm_dict_problem(junk) == "":
			problems.append("A bad lab_sitter was accepted: %s" % [bad])
	if CoopSession.PROTOCOL != 54:
		problems.append("The protocol is %d, not 54." % CoopSession.PROTOCOL)
	back.free()
	old.free()
	_done(gs)
	return "\n".join(problems)


func test_a_guest_is_shown_the_booking() -> String:
	var host: GameStateScript = _state()
	var guest: GameStateScript = _state()
	var problems: Array[String] = []
	FarmCommands.guest = true
	guest.local_player_id = GUEST
	var joined: String = FarmSync.join(FarmSync.capture(host), guest)
	if joined != "" or not guest.lab_sitter.is_empty():
		problems.append("A guest joined a farm with none booked: '%s', %s" % [joined, guest.lab_sitter])
	FarmCommands.guest = false
	host.book_lab_sitter(4)
	FarmCommands.guest = true
	var heard: Array[int] = [0]
	guest.lab_sitter_changed.connect(func() -> void: heard[0] += 1)
	var updated: String = FarmSync.update(FarmSync.capture(host), guest)
	if updated != "" or guest.lab_sitter != host.lab_sitter or heard[0] < 1:
		problems.append("The guest was not shown the booking: '%s', %s, heard %d" % [updated, guest.lab_sitter, heard[0]])
	FarmCommands.guest = false
	guest.free()
	_done(host)
	return "\n".join(problems)
