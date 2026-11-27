extends RefCounted
## The shuttle's rules (docs/design/zones.md section 8.2, build step 16, the rules
## half): launch windows as a pure function of the clock, the fare, the license
## and the reasons a day trip can't go; the license in the save and shown to a
## guest; and book_shuttle refusing for now. Every GameState is freed and the
## clock is put back.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const HOUR: float = 1.0 / 24.0


func _state(credits: int = 500) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(515151)
	gs.local_player_id = HOST
	gs.credits = credits
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


## Elapsed days for a count of game hours since 06:00 of day 1.
func _h(hours: float) -> float:
	return hours * HOUR


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _exam() -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest["id"]) == "shuttle_exam":
			return quest
	return {}


# --- Windows ---------------------------------------------------------------------------

func test_phobos_has_about_two_windows_a_day_each_the_set_length_and_drifting() -> String:
	var problems: Array[String] = []
	var period: float = Shuttle.cycle(Shuttle.PHOBOS)[0]
	var length: float = Shuttle.cycle(Shuttle.PHOBOS)[1]
	var starts: Array[float] = []
	var t: float = -0.001
	for i: int in 24:
		var window: Dictionary = Shuttle.next_window(Shuttle.PHOBOS, t)
		starts.append(float(window["start"]))
		if not is_equal_approx((float(window["end"]) - float(window["start"])) * 24.0, length):
			problems.append("Window %d is not %s h long." % [i, length])
		t = float(window["start"])
	var spread: float = (starts[23] - starts[0]) * 24.0
	if not is_equal_approx(spread, period * 23.0):
		problems.append("The windows are not a period apart: %s h over 23 gaps." % spread)
	var per_day: float = 24.0 / period
	if per_day < 2.0 or per_day > 2.5:
		problems.append("About two a day, got %s." % per_day)
	# Drifting: the clock time of a window is not the same day after day.
	var seen: Dictionary = {}
	for start: float in starts.slice(0, 6):
		seen[Shuttle.clock_text(start)] = true
	if seen.size() < 5:
		problems.append("The windows do not drift through the day: %s" % [seen.keys()])
	return "\n".join(problems)


func test_deimos_is_up_two_and_a_half_days_then_down_two_and_a_half() -> String:
	var problems: Array[String] = []
	for case: Array in [[0.5, true], [30.0, true], [59.5, true], [60.5, false], [90.0, false], [119.5, false], [120.5, true], [179.5, true], [180.5, false]]:
		if Shuttle.is_open(Shuttle.DEIMOS, _h(float(case[0]))) != bool(case[1]):
			problems.append("Deimos at hour %s should be %s." % [case[0], "up" if bool(case[1]) else "down"])
	var c: Array[float] = Shuttle.cycle(Shuttle.DEIMOS)
	if not is_equal_approx(c[1], 60.0) or not is_equal_approx(c[0], 120.0):
		problems.append("Deimos is up 60 h of a 120 h cycle: %s" % [c])
	return "\n".join(problems)


func test_next_window_is_ahead_and_is_open_agrees_with_it() -> String:
	var problems: Array[String] = []
	var tiny: float = _h(0.01)
	for moon: String in Shuttle.MOONS:
		for hours: float in [0.0, 2.5, 3.0, 3.5, 13.0, 36.0, 59.9, 60.0, 61.0, 119.0, 250.0, 500.7]:
			var t: float = _h(hours)
			var window: Dictionary = Shuttle.next_window(moon, t)
			var start: float = float(window["start"])
			var end: float = float(window["end"])
			if start <= t or end <= start:
				problems.append("%s at %s h: the next window is not ahead (%s to %s)." % [moon, hours, start, end])
				continue
			if not Shuttle.is_open(moon, start):
				problems.append("%s at %s h: it is not open at its start." % [moon, hours])
			if not Shuttle.is_open(moon, end - tiny):
				problems.append("%s at %s h: it is not open just before its end." % [moon, hours])
			if Shuttle.is_open(moon, end + tiny):
				problems.append("%s at %s h: it is open after its end." % [moon, hours])
			if Shuttle.is_open(moon, start - tiny):
				problems.append("%s at %s h: it is open just before its start." % [moon, hours])
	if not Shuttle.next_window("luna", 0.0).is_empty() or Shuttle.is_open("luna", 0.0):
		problems.append("A name that is no moon has a window.")
	return "\n".join(problems)


func test_the_window_line_is_short_and_says_when() -> String:
	var problems: Array[String] = []
	var phobos: String = Shuttle.window_line(Shuttle.PHOBOS, 0.0)
	if phobos != "Phobos: next window 08:30, in 2 h 30 min.":
		problems.append("Phobos before its first window: '%s'" % phobos)
	if not Shuttle.window_line(Shuttle.PHOBOS, _h(3.0)).begins_with("Phobos: window open"):
		problems.append("Phobos in its window: '%s'" % Shuttle.window_line(Shuttle.PHOBOS, _h(3.0)))
	var up: String = Shuttle.window_line(Shuttle.DEIMOS, _h(36.0))
	if up != "Deimos: up, closes in 1 day.":
		problems.append("Deimos up with a day to run: '%s'" % up)
	var down: String = Shuttle.window_line(Shuttle.DEIMOS, _h(70.0))
	if not down.begins_with("Deimos: down, up again in 2 days"):
		problems.append("Deimos down: '%s'" % down)
	if Shuttle.span_text(0.2) != "12 min" or Shuttle.span_text(3.0 + 10.0 / 60.0) != "3 h 10 min":
		problems.append("A span of hours reads in hours and minutes.")
	return "\n".join(problems)


# --- Trips -----------------------------------------------------------------------------

func test_trip_problem_names_each_reason_in_turn() -> String:
	var problems: Array[String] = []
	var open: float = _h(3.0)
	var fare: int = Shuttle.fare()
	var early: String = Shuttle.trip_problem(Shuttle.PHOBOS, 5, false, 500, 1, open, true)
	if not early.contains("lab level 5") or not early.contains("20"):
		problems.append("Below the exam's level, the reason names both levels: '%s'" % early)
	var exam: String = Shuttle.trip_problem(Shuttle.PHOBOS, 20, false, 500, 1, open, true)
	if exam != Shuttle.text("exam_first_text") or exam == early:
		problems.append("At the exam's level, the reason is the exam: '%s'" % exam)
	if Shuttle.license_problem(5, true) != "" or Shuttle.license_problem(1, false) == "":
		problems.append("The license is what counts, not the level, once it is held.")
	var down: String = Shuttle.trip_problem(Shuttle.PHOBOS, 20, true, 500, 1, _h(6.0), true)
	if not down.contains("Phobos is down"):
		problems.append("Phobos shut: '%s'" % down)
	var short: String = Shuttle.trip_problem(Shuttle.PHOBOS, 20, true, fare * 2 - 1, 2, open, true)
	if not short.contains("%d CR" % fare) or not short.contains("Phobos"):
		problems.append("The wallet, short for two: '%s'" % short)
	if Shuttle.trip_problem(Shuttle.PHOBOS, 20, true, fare * 2, 2, open, false).contains("CR a person"):
		problems.append("Exactly two fares is enough.")
	# Hour 46.6 of the game is day 2, past its 02:00 recall at hour 44.
	var late: String = Shuttle.trip_problem(Shuttle.PHOBOS, 20, true, 500, 1, _h(46.6), true)
	if not late.contains("recall") or not late.contains("02:00"):
		problems.append("A window after the recall: '%s'" % late)
	var deimos_late: String = Shuttle.trip_problem(Shuttle.DEIMOS, 20, true, 500, 1, _h(40.0), true)
	if not deimos_late.contains("recall"):
		problems.append("Deimos up, with the recall less than a trip away: '%s'" % deimos_late)
	var no_hub: String = Shuttle.trip_problem(Shuttle.DEIMOS, 20, true, 500, 1, _h(10.0), false)
	if no_hub != Shuttle.text("no_hub_text") % "Deimos":
		problems.append("The last reason is the missing hub: '%s'" % no_hub)
	if Shuttle.trip_problem(Shuttle.DEIMOS, 20, true, 500, 1, _h(10.0), true) != "":
		problems.append("A trip with every reason met was refused.")
	for bad: Array in [["luna", 1], [Shuttle.PHOBOS, 0], [Shuttle.PHOBOS, Shuttle.party_most() + 1]]:
		if Shuttle.trip_problem(str(bad[0]), 20, true, 5000, int(bad[1]), open, true) == "":
			problems.append("A bad moon or party was allowed: %s" % [bad])
	return "\n".join(problems)


func test_book_shuttle_refuses_with_the_reason_and_charges_nothing() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	GameClock.elapsed_days = _h(3.0)
	var unlicensed: String = gs.book_shuttle(Shuttle.PHOBOS, 1)
	if unlicensed == "" or gs.credits != 500:
		problems.append("An unlicensed booking: '%s', %d CR" % [unlicensed, gs.credits])
	gs.shuttle_licensed = true
	var no_hub: String = gs.book_shuttle(Shuttle.PHOBOS, 2)
	if no_hub != Shuttle.text("no_hub_text") % "Phobos" or gs.credits != 500:
		problems.append("Every booking ends at the missing hub with no fare taken: '%s', %d CR" % [no_hub, gs.credits])
	if _lines(gs, "booked") != 0:
		problems.append("A refused booking must not be told as a booking.")
	_done(gs)
	return "\n".join(problems)


func test_book_shuttle_from_a_guest_is_refused_with_the_reason() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var problems: Array[String] = []
	if not &"book_shuttle" in CommandsScript.ACTIONS or commands.problem(&"book_shuttle", [Shuttle.PHOBOS, 1]) != "":
		problems.append("book_shuttle must be a farm command that takes a moon and a party.")
	if commands.problem(&"book_shuttle", []) == "" or commands.problem(&"book_shuttle", [3, 1]) == "":
		problems.append("A booking with no moon, or a number for the moon, must be refused.")
	GameClock.elapsed_days = _h(3.0)
	var guest: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.PHOBOS, 1])
	if not guest is String or guest == "" or gs.credits != 500:
		problems.append("A guest's unlicensed booking: '%s', %d CR" % [guest, gs.credits])
	gs.shuttle_licensed = true
	var licensed: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.PHOBOS, 1])
	if licensed != Shuttle.text("no_hub_text") % "Phobos" or gs.credits != 500:
		problems.append("A licensed guest is refused for the hub and pays nothing: '%s', %d CR" % [licensed, gs.credits])
	var host: Variant = commands.execute(HOST, &"book_shuttle", [Shuttle.DEIMOS])
	if host == "" or gs.credits != 500:
		problems.append("The host's booking, with the party left out, is refused too: '%s'" % host)
	commands.free()
	_done(gs)
	return "\n".join(problems)


# --- The license -----------------------------------------------------------------------

func test_the_license_is_not_held_by_default() -> String:
	var gs: GameStateScript = _state()
	var held: bool = gs.shuttle_licensed
	_done(gs)
	return "" if not held else "A new farm holds the shuttle license."


func test_the_license_is_saved_and_an_old_save_loads_unlicensed() -> String:
	var gs: GameStateScript = _state()
	gs.grant_shuttle_license()
	gs.grant_shuttle_license()
	var problems: Array[String] = []
	if _lines(gs, "shuttle license") != 1:
		problems.append("The license is said once: %d lines." % _lines(gs, "shuttle license"))
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if data.get("shuttle_licensed", false) != true:
		problems.append("The save did not hold the license.")
	var back: GameStateScript = _state()
	var heard: Array[int] = [0]
	back.shuttle_license_changed.connect(func() -> void: heard[0] += 1)
	if back.farm_from_dict(data) != "" or not back.shuttle_licensed or heard[0] < 1:
		problems.append("The license was not loaded and told to the screens.")
	data.erase("shuttle_licensed")
	var old: GameStateScript = _state()
	old.shuttle_licensed = true
	if old.farm_from_dict(data) != "" or old.shuttle_licensed:
		problems.append("An old save was refused or came licensed.")
	var junk: Dictionary = gs.farm_to_dict()
	junk["shuttle_licensed"] = 1
	if gs.farm_dict_problem(junk) == "":
		problems.append("A license that is no bool was accepted.")
	if CoopSession.PROTOCOL != 31:
		problems.append("The protocol is %d, not 31." % CoopSession.PROTOCOL)
	back.free()
	old.free()
	_done(gs)
	return "\n".join(problems)


func test_a_guest_is_shown_the_license() -> String:
	var host: GameStateScript = _state()
	var guest: GameStateScript = _state()
	var problems: Array[String] = []
	FarmCommands.guest = true
	guest.local_player_id = GUEST
	var joined: String = FarmSync.join(FarmSync.capture(host), guest)
	if joined != "" or guest.shuttle_licensed:
		problems.append("A guest joined a farm with no license: '%s'" % joined)
	FarmCommands.guest = false
	host.grant_shuttle_license()
	FarmCommands.guest = true
	var heard: Array[int] = [0]
	guest.shuttle_license_changed.connect(func() -> void: heard[0] += 1)
	var updated: String = FarmSync.update(FarmSync.capture(host), guest)
	if updated != "" or not guest.shuttle_licensed or heard[0] < 1:
		problems.append("The guest was not shown the license: '%s', %s, heard %d" % [updated, guest.shuttle_licensed, heard[0]])
	FarmCommands.guest = false
	guest.free()
	_done(host)
	return "\n".join(problems)


func test_the_exam_is_offered_at_level_20_and_a_clean_calibration_grants_the_license() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var exam: Dictionary = _exam()
	if exam.is_empty() or QuestEngine.data_problem(exam) != "" or int(exam.get("gates", {}).get("lab_level", 0)) != Shuttle.license_level():
		_done(gs)
		return "The exam quest is missing or unsound: %s" % QuestEngine.data_problem(exam)
	gs.lab_xp = gs.xp_for_level(Shuttle.license_level() - 1)
	gs.update_quests()
	if gs.quest_state.has("shuttle_exam"):
		problems.append("The exam was offered below its level.")
	gs.lab_xp = gs.xp_for_level(Shuttle.license_level())
	gs.update_quests()
	if not gs.quest_state.has("shuttle_exam") or gs.shuttle_licensed:
		problems.append("The exam is offered at its level and grants nothing yet.")
	# A calibration that is late, untraceable or the Manager's does not pass it.
	var row: Dictionary = { "instrument_id": "exam_probe", "traceable": true, "on_time": true, "performed_by": HOST, "day": 1 }
	for flaw: Array in [["traceable", false], ["on_time", false], ["performed_by", "Manager"]]:
		var bad: Dictionary = row.duplicate()
		bad[flaw[0]] = flaw[1]
		gs.cal_log.append(bad)
	gs.update_quests()
	if gs.shuttle_licensed or QuestEngine.is_done(gs, "shuttle_exam"):
		problems.append("A flawed calibration passed the exam.")
	gs.cal_log.append(row)
	gs.update_quests()
	if not gs.shuttle_licensed or not QuestEngine.is_done(gs, "shuttle_exam"):
		problems.append("A clean calibration did not grant the license.")
	if _lines(gs, "the shuttle license") < 1:
		problems.append("The phone must name the license among the reward.")
	_done(gs)
	return "\n".join(problems)


# --- Data ------------------------------------------------------------------------------

func test_the_shuttle_numbers_exist_and_are_sane() -> String:
	var problems: Array[String] = []
	if Shuttle.data_problem() != "":
		problems.append(Shuttle.data_problem())
	if Shuttle.fare() != 40 or Shuttle.license_level() != 20:
		problems.append("Ryan's numbers: a day trip is 40 CR, the license is lab 20 (%d, %d)." % [Shuttle.fare(), Shuttle.license_level()])
	if Shuttle.party_most() < 1 or Shuttle.trip_hours() <= 0.0 or Shuttle.trip_hours() >= 24.0:
		problems.append("The party and the trip's length are out of range.")
	for key: String in ["not_yet_text", "exam_first_text", "granted_text", "booked_text", "moon_down_text", "short_text", "recall_text", "no_hub_text", "bad_party_text", "no_moon_text", "phobos_open_text", "phobos_next_text", "deimos_open_text", "deimos_next_text"]:
		if Shuttle.text(key) == "":
			problems.append("'%s' has no words." % key)
	for moon: String in Shuttle.MOONS:
		if ZoneData.hub_scene(StringName(moon)) != "":
			problems.append("%s has a hub now: the 'no hub yet' reason should be revisited." % moon)
	return "\n".join(problems)
