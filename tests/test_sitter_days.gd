extends RefCounted
## The lab sitter booked for several days in a row (feat/sitter-days): one charge
## at booking, a host-run cancel of the days not yet started, the free reward day,
## old saves and guests. Every GameState is freed and the clock is put back.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const REPORT: String = "kept the lab in good order"


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


## Time moves to the 06:00 that starts `day`.
func _morning(gs: GameStateScript, day: int) -> void:
	GameClock.elapsed_days = float(day - 1)
	gs._on_day_started(day)


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func test_one_two_and_three_days_charge_once_and_the_right_total() -> String:
	var problems: Array[String] = []
	for days: int in [1, 2, 3]:
		var gs: GameStateScript = _state(500)
		if gs.book_lab_sitter(4, days) != "":
			problems.append("%d days were refused." % days)
		var want: Dictionary = { "day": 4, "days": days, "paid": 40, "watered": 0, "spools": 0 }
		if gs.credits != 500 - 40 * days or gs.lab_sitter != want:
			problems.append("%d days: credits %d, booking %s" % [days, gs.credits, gs.lab_sitter])
		if gs.book_lab_sitter(4, days) == "" or gs.credits != 500 - 40 * days:
			problems.append("A second booking was allowed or charged again.")
		_done(gs)
	return "\n".join(problems)


func test_booking_is_refused_short_over_the_most_and_away_from_the_dome() -> String:
	var gs: GameStateScript = _state(119)
	var problems: Array[String] = []
	var reason: String = gs.book_lab_sitter(4, 3)
	if reason == "" or not gs.lab_sitter.is_empty() or gs.credits != 119 or not reason.contains("120 CR"):
		problems.append("119 CR must not book 3 days and the reason names 120 CR: '%s'" % reason)
	if gs.book_lab_sitter(4, 2) != "" or gs.credits != 39:
		problems.append("119 CR books 2 days.")
	gs.lab_sitter = {}
	gs.credits = 500
	for bad: int in [0, -1, LabSitter.max_days() + 1]:
		if gs.book_lab_sitter(4, bad) == "" or gs.credits != 500 or not gs.lab_sitter.is_empty():
			problems.append("%d days must be refused with nothing charged." % bad)
	gs.player_places[HOST] = [ZonePresence.FARM, 0]
	if gs.book_lab_sitter(4, 2) != LabSitter.text("console_in_dome") or gs.credits != 500:
		problems.append("Away from the dome nothing is booked.")
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	if gs.book_lab_sitter(5, 2) != LabSitter.text("new_day") or gs.credits != 500:
		problems.append("The wrong day is refused.")
	_done(gs)
	return "\n".join(problems)


func test_she_works_each_booked_morning_and_not_after() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	gs.book_lab_sitter(4, 2)
	var tended: Array[int] = [0]
	gs.lab_sitter_changed.connect(func() -> void: tended[0] += 1)
	_morning(gs, 4)
	var after_first: int = tended[0]
	_morning(gs, 5)
	var after_second: int = tended[0]
	if after_first < 1 or after_second <= after_first:
		problems.append("She tended on both booked mornings: %d, %d" % [after_first, after_second])
	if gs.lab_sitter.is_empty():
		problems.append("She is still booked on her last day.")
	if _lines(gs, REPORT) != 0:
		problems.append("The report came before her days ended.")
	_morning(gs, 6)
	if not gs.lab_sitter.is_empty():
		problems.append("The booking was not pruned at 06:00 after her last day.")
	if _lines(gs, REPORT) != 1 or _lines(gs, "days 4-5") < 1:
		problems.append("One report naming days 4-5 was expected: %d" % _lines(gs, REPORT))
	var heard_after: int = tended[0]
	_morning(gs, 7)
	if _lines(gs, REPORT) != 1 or tended[0] != heard_after:
		problems.append("A later day worked or reported again.")
	_done(gs)
	return "\n".join(problems)


func test_a_booking_slept_past_is_pruned() -> String:
	var gs: GameStateScript = _state(500)
	gs.book_lab_sitter(4, 3)
	_morning(gs, 5)
	var kept: bool = not gs.lab_sitter.is_empty()
	_morning(gs, 20)
	var gone: bool = gs.lab_sitter.is_empty()
	_done(gs)
	return "" if kept and gone else "Booked days are pruned once past (%s, %s)." % [kept, gone]


func test_cancel_refunds_only_future_paid_days_once() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if gs.cancel_lab_sitter(GameClock.get_day_index()) != LabSitter.text("cancel_nothing"):
		problems.append("Cancelling nothing must say so.")
	gs.book_lab_sitter(4, 3)
	if gs.credits != 380 or gs.cancel_lab_sitter(GameClock.get_day_index()) != "" or gs.credits != 500 or not gs.lab_sitter.is_empty():
		problems.append("Cancelling before she starts refunds all 3 days: %d, %s" % [gs.credits, gs.lab_sitter])
	if gs.cancel_lab_sitter(GameClock.get_day_index()) == "" or gs.credits != 500:
		problems.append("A second cancel must refund nothing.")
	gs.book_lab_sitter(4, 3)
	_morning(gs, 4)
	if gs.cancel_lab_sitter(3) != LabSitter.text("new_day") or gs.credits != 380:
		problems.append("A cancel for the wrong day is refused and refunds nothing: %d" % gs.credits)
	if gs.cancel_lab_sitter(GameClock.get_day_index()) != "" or gs.credits != 460:
		problems.append("After day 4 started, days 5 and 6 are refunded: %d" % gs.credits)
	if _lines(gs, "cancelled for days 5-6") != 1:
		problems.append("The cancel line names only the cancelled days 5-6: %s" % [gs.phone_log])
	if gs.lab_sitter.get("days", 0) != 1 or gs.lab_sitter.get("day", 0) != 4:
		problems.append("The booking is cut to the day worked: %s" % [gs.lab_sitter])
	if gs.cancel_lab_sitter(GameClock.get_day_index()) == "" or gs.credits != 460:
		problems.append("The day already started is never refunded.")
	_morning(gs, 5)
	if not gs.lab_sitter.is_empty() or _lines(gs, REPORT) != 1 or _lines(gs, "on day 4.") != 1:
		problems.append("The cut booking closes after day 4 and the report names day 4 alone: %s" % [gs.phone_log])
	gs.player_places[HOST] = [ZonePresence.FARM, 0]
	gs.lab_sitter = LabSitter.new_booking(9, 2, 40)
	if gs.cancel_lab_sitter(GameClock.get_day_index()) != LabSitter.text("console_in_dome") or gs.credits != 460:
		problems.append("Cancel is from the console in the dome.")
	_done(gs)
	return "\n".join(problems)


func test_cancel_on_the_last_day_is_refused() -> String:
	var gs: GameStateScript = _state(500)
	gs.book_lab_sitter(4, 2)
	_morning(gs, 5)
	var reason: String = gs.cancel_lab_sitter(GameClock.get_day_index())
	var ok: bool = reason == LabSitter.text("cancel_started") and gs.credits == 420 and not gs.lab_sitter.is_empty()
	_done(gs)
	return "" if ok else "Her last day is under way, nothing to cancel: '%s'" % reason


func test_the_reward_day_is_free_never_refunded_and_never_stacks() -> String:
	var gs: GameStateScript = _state(10)
	var problems: Array[String] = []
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	if gs.book_lab_sitter(4, 1) != "" or gs.credits != 10 or gs.lab_sitter.get("paid", -1) != 0:
		problems.append("The reward books one free day: %d, %s" % [gs.credits, gs.lab_sitter])
	gs.give_one_use(GameStateScript.ONE_USE_SITTER, GameStateScript.FARM_HOLDER)
	if gs.book_lab_sitter(4, 1) == "" or gs.one_use_count(GameStateScript.ONE_USE_SITTER) != 1:
		problems.append("A reward must not stack onto a booked day.")
	if gs.cancel_lab_sitter(GameClock.get_day_index()) != "" or gs.credits != 10 or not gs.lab_sitter.is_empty():
		problems.append("Cancelling a free day refunds no credits: %d" % gs.credits)
	gs.credits = 500
	if gs.book_lab_sitter(4, 2) != "" or gs.credits != 420 or gs.one_use_count(GameStateScript.ONE_USE_SITTER) != 1:
		problems.append("Two days are paid for in credits and the reward is kept: %d" % gs.credits)
	_done(gs)
	return "\n".join(problems)


func test_an_old_save_with_one_day_loads_as_a_one_day_booking() -> String:
	var gs: GameStateScript = _state(500)
	gs.book_lab_sitter(4, 3)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var problems: Array[String] = []
	if (data.get("lab_sitter", {}) as Dictionary).get("days", 0) != 3:
		problems.append("The save holds the days: %s" % [data.get("lab_sitter")])
	var back: GameStateScript = _state()
	if back.farm_from_dict(data) != "" or back.lab_sitter != gs.lab_sitter:
		problems.append("The booking did not load: %s" % [back.lab_sitter])
	data["lab_sitter"] = { "day": 4, "watered": 1, "spools": 2 }
	var old: GameStateScript = _state()
	if old.farm_from_dict(data) != "":
		problems.append("An old one-day booking was refused.")
	elif LabSitter.day_count(old.lab_sitter) != 1 or LabSitter.last_day(old.lab_sitter) != 4:
		problems.append("An old booking means one day.")
	for bad: Variant in [{ "day": 4, "days": 0, "paid": 0, "watered": 0, "spools": 0 },
			{ "day": 4, "days": 31, "paid": 0, "watered": 0, "spools": 0 },
			{ "day": 4, "days": 1, "paid": -5, "watered": 0, "spools": 0 },
			{ "day": 4, "days": 1, "watered": 0, "spools": 0 }]:
		if LabSitter.booking_problem(bad) == "":
			problems.append("A bad booking was accepted: %s" % [bad])
	back.free()
	old.free()
	_done(gs)
	return "\n".join(problems)


func test_guests_see_the_days_and_the_commands_run_for_them() -> String:
	var host: GameStateScript = _state()
	var guest: GameStateScript = _state()
	var commands: Node = CommandsScript.new()
	commands.state = host
	var problems: Array[String] = []
	if not &"cancel_lab_sitter" in CommandsScript.ACTIONS or commands.problem(&"cancel_lab_sitter", [3]) != "":
		problems.append("cancel_lab_sitter must be a farm command that takes today.")
	if commands.problem(&"book_lab_sitter", [4, 2]) != "" or commands.problem(&"book_lab_sitter", [4]) == "":
		problems.append("book_lab_sitter takes the day and the number of days.")
	if commands.execute(GUEST, &"book_lab_sitter", [4, 3]) != "" or host.credits != 380:
		problems.append("A guest in the dome books 3 days from the shared wallet: %d" % host.credits)
	FarmCommands.guest = true
	guest.local_player_id = GUEST
	var joined: String = FarmSync.join(FarmSync.capture(host), guest)
	if joined != "" or guest.lab_sitter != host.lab_sitter or LabSitter.day_count(guest.lab_sitter) != 3:
		problems.append("A late joiner is given the booking: '%s', %s" % [joined, guest.lab_sitter])
	FarmCommands.guest = false
	if commands.execute(GUEST, &"cancel_lab_sitter", [3]) != "" or host.credits != 500:
		problems.append("A guest in the dome cancels and the host refunds: %d" % host.credits)
	FarmCommands.guest = true
	var heard: Array[int] = [0]
	guest.lab_sitter_changed.connect(func() -> void: heard[0] += 1)
	var updated: String = FarmSync.update(FarmSync.capture(host), guest)
	if updated != "" or not guest.lab_sitter.is_empty() or heard[0] < 1:
		problems.append("The guest is shown the cancel: '%s', %s, %d" % [updated, guest.lab_sitter, heard[0]])
	FarmCommands.guest = false
	if CoopSession.PROTOCOL != 47:
		problems.append("The protocol is %d, not 47 (cancel is a new command, book takes days)." % CoopSession.PROTOCOL)
	commands.free()
	guest.free()
	_done(host)
	return "\n".join(problems)


func test_the_text_is_plain_and_data_driven() -> String:
	var problems: Array[String] = []
	var booking: Dictionary = LabSitter.new_booking(4, 3, 40)
	if LabSitter.days_text(booking) != "days 4-6" or LabSitter.days_text(LabSitter.new_booking(4)) != "day 4":
		problems.append("Plain days wording: '%s'" % LabSitter.days_text(booking))
	if LabSitter.total_fee(3) != 120 or LabSitter.max_days() != 3:
		problems.append("The data gives 40 CR a day and at most 3 days with no discount.")
	if LabSitter.future_days(booking, 3) != 3 or LabSitter.future_days(booking, 4) != 2 or LabSitter.future_days(booking, 6) != 0:
		problems.append("Future days count the mornings not yet come.")
	for key: String in ["days_one", "days_many", "total_text", "cancel", "cancel_text", "refund_text", "no_refund_text", "bad_days", "cancel_nothing", "cancel_started"]:
		if LabSitter.text(key) == "":
			problems.append("No '%s' text." % key)
	return "\n".join(problems)


func test_saves_are_checked_against_fixed_ceilings_not_the_tunable_most() -> String:
	var problems: Array[String] = []
	var big: Dictionary = LabSitter.new_booking(4, LabSitter.MOST_DAYS, 5000)
	if LabSitter.booking_problem(big) != "":
		problems.append("A long, dear saved booking must load whatever max_days is: %s" % LabSitter.booking_problem(big))
	if LabSitter.booking_problem(LabSitter.new_booking(4, LabSitter.MOST_DAYS + 1)) == "":
		problems.append("A booking past the fixed ceiling must be refused.")
	if LabSitter.booking_problem(LabSitter.new_booking(4, 1, LabSitter.MOST_PAID + 1)) == "":
		problems.append("A payment past the fixed ceiling must be refused.")
	return "
".join(problems)


func test_an_old_booking_cancels_with_a_neutral_line_and_no_refund() -> String:
	var gs: GameStateScript = _state(100)
	gs.lab_sitter = { "day": 4, "watered": 0, "spools": 0 }
	var done: String = gs.cancel_lab_sitter(GameClock.get_day_index())
	var ok: bool = done == "" and gs.credits == 100 and _lines(gs, "from a reward") == 0 and _lines(gs, "nothing is refunded") == 1
	_done(gs)
	return "" if ok else "An old booking cancels with no refund and no claim it was a reward: '%s'" % done
