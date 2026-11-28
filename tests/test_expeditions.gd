extends "res://tests/coop_net.gd"
## Expeditions (docs/design/zones.md section 8.3, build step 18): the permit, the second
## camp in the Deimos hub, booking a multi-day trip at the pad terminal (refusals, the
## price shown and charged once), nights away (no 02:00 rescue for a camp sleeper, the
## chosen rule for an awake traveller, all-in-bed still ends the day), going home early,
## Vance's Deimos Survey, and the save. Every GameState is freed and the clock put back.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")

const HOST: String = "player_1"
const GUEST: String = "player_2"
const QUEST: String = "deimos_survey"
const HOUR: float = 1.0 / 24.0


func _state(credits: int = 1000, level: int = 30) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(616161)
	gs.local_player_id = HOST
	gs.credits = credits
	gs.shuttle_licensed = true
	gs.lab_xp = gs.xp_for_level(level)
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	return gs


func _done(gs: GameStateScript) -> void:
	CoopWalkers.out.clear()  # a returned traveller stands on foot at the pad
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


## The first morning where an expedition booked in the day fits inside Deimos's open spell.
func _fitting_day() -> float:
	for day: int in 40:
		var at: float = float(day) + 0.1
		if Shuttle.is_open(Shuttle.DEIMOS, at) and Shuttle.closes_at(Shuttle.DEIMOS, at) >= Shuttle.expedition_end(at) - Shuttle.EPSILON_H / 24.0:
			return at
	return -1.0


## A day with the window open that shuts before an expedition could be home.
func _short_day() -> float:
	for day: int in 40:
		var at: float = float(day) + 0.1
		if Shuttle.is_open(Shuttle.DEIMOS, at) and Shuttle.closes_at(Shuttle.DEIMOS, at) < Shuttle.expedition_end(at) - Shuttle.EPSILON_H / 24.0:
			return at
	return -1.0


## The farm takes the quest (the permit is open at lab level 30).
func _take(gs: GameStateScript, who: Array[String]) -> void:
	QuestEngine.update(gs, who)


func _count(gs: GameStateScript, who: String, key: String) -> int:
	return int(((gs.action_counts.get(who, {}) as Dictionary).get(key, {}) as Dictionary).get("count", 0))


## A booked party of `ids` (the host books; the rest stand at the terminal).
func _book(gs: GameStateScript, ids: Array[String], at: float) -> String:
	var held: Array[String] = CoopSession.players.duplicate()
	CoopSession.players.assign(ids)
	for other: String in ids:
		if other != HOST:
			CoopWalkers.stand(other, Vector3(Shuttle.TERMINAL_AT.x, 0.0, Shuttle.TERMINAL_AT.y))
	GameClock.elapsed_days = at
	var party: Array = []
	party.assign(gs.shuttle_party(HOST))
	var total: int = int(gs.expedition_cost(party.size())["total"])
	var problem: String = gs.book_expedition(Shuttle.DEIMOS, party, total)
	for other: String in ids:
		CoopWalkers.out.erase(other)
	CoopSession.players.assign(held)
	return problem


## Runs `body(gs, beds, clock)` on a farm with real beds, plus a joined guest when `with_guest`.
func _bed_farm(with_guest: bool, body: Callable) -> String:
	var host: Node = _host()
	if with_guest:
		_guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = 0.5
	var gs: GameStateScript = _state()
	gs.recall_beds = beds
	var out: Variant = body.call(gs, beds, clock)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	var saved: float = float(gs.get_meta(&"saved_clock"))
	CoopWalkers.out.clear()
	GameClock.elapsed_days = saved
	gs.free()
	beds.free()
	clock.free()
	return _finish(problem)


## `who` are on Deimos on an expedition that ends at `ends_at`, the camp open.
func _away(gs: GameStateScript, who: Array[String], ends_at: float, supplies: int) -> void:
	for id: String in who:
		gs.player_places[id] = [Shuttle.DEIMOS, 0]
		gs.shuttle_trips[id] = { "moon": Shuttle.DEIMOS, "ends_at": ends_at, "expedition": true }
	gs.camps_open.append(Shuttle.DEIMOS)
	gs.camp_supplies = supplies


# --- The permit and the camp ---------------------------------------------------------------

func test_the_permit_is_built_at_lab_level_30_and_read_like_other_gates() -> String:
	var gs: GameStateScript = _state(500, 29)
	var shut: bool = not gs.lab_gate_open("expedition_permit")
	gs.lab_xp = gs.xp_for_level(30)
	var open: bool = gs.lab_gate_open("expedition_permit")
	var level: int = gs.lab_gate_level("expedition_permit")
	_done(gs)
	if level != 30 or not shut or not open:
		return "The permit gate: level %d, shut at 29: %s, open at 30: %s" % [level, shut, open]
	return ""


func test_the_deimos_camp_is_clear_of_every_hub_spot_and_has_its_own_place() -> String:
	var at: Vector3 = Camp.position(Shuttle.DEIMOS)
	if not Camp.has_camp(Shuttle.DEIMOS) or at == Vector3.ZERO or Camp.open_problem([Shuttle.DEIMOS]) != "":
		return "Deimos has a camp with a place"
	for spot: String in DeimosHub.DEIMOS_SPOTS:
		var other: Vector3 = DeimosHub.DEIMOS_SPOTS[spot]
		if Vector2(at.x - other.x, at.z - other.z).length() < 5.0:
			return "The camp is %s m from the hub's %s." % [Vector2(at.x - other.x, at.z - other.z).length(), spot]
	var away: Vector3 = Vector3(at.x + 40.0, 0.0, at.z)
	if not Camp.near(Shuttle.DEIMOS, at) or Camp.near(Shuttle.DEIMOS, away):
		return "The camp has a reach"
	return ""


func test_a_night_at_the_deimos_camp_needs_an_expedition_an_open_camp_and_a_supply() -> String:
	var shut: String = Camp.moon_sleep_problem(Shuttle.DEIMOS, false, true, 5)
	var no_trip: String = Camp.moon_sleep_problem(Shuttle.DEIMOS, true, false, 5)
	var none: String = Camp.moon_sleep_problem(Shuttle.DEIMOS, true, true, 0)
	var fine: String = Camp.moon_sleep_problem(Shuttle.DEIMOS, true, true, 1)
	if shut == "" or no_trip == "" or none == "" or fine != "":
		return "'%s' / '%s' / '%s' / '%s'" % [shut, no_trip, none, fine]
	return ""


# --- Booking ---------------------------------------------------------------------------------

func test_without_the_permit_or_the_quest_an_expedition_is_refused_and_nothing_is_charged() -> String:
	var day: float = _fitting_day()
	if day < 0.0:
		return "No Deimos day fits an expedition"
	var problems: Array[String] = []
	# No permit: the lab is level 10.
	var low: GameStateScript = _state(1000, 10)
	var a: String = _book(low, [HOST] as Array[String], day)
	if a == "" or not a.contains("permit") or low.credits != 1000 or not low.shuttle_trips.is_empty() or low.camp_supplies != 0:
		problems.append("No permit: '%s', %d CR, trips %s" % [a, low.credits, low.shuttle_trips])
	_done(low)
	# The permit but no quest.
	var bare: GameStateScript = _state(1000, 30)
	var b: String = _book(bare, [HOST] as Array[String], day)
	if b == "" or not b.contains("Survey") or bare.credits != 1000 or not bare.shuttle_trips.is_empty() or bare.camp_supplies != 0:
		problems.append("No quest: '%s', %d CR, trips %s" % [b, bare.credits, bare.shuttle_trips])
	_done(bare)
	return "\n".join(problems)


func test_a_window_that_shuts_before_the_return_refuses() -> String:
	var day: float = _short_day()
	if day < 0.0:
		return "No short Deimos day found"
	var gs: GameStateScript = _state()
	_take(gs, [HOST] as Array[String])
	var why: String = _book(gs, [HOST] as Array[String], day)
	var problem: String = ""
	if why == "" or not why.contains("window") or gs.credits != 1000 or not gs.shuttle_trips.is_empty():
		problem = "A window that shuts first: '%s', %d CR" % [why, gs.credits]
	_done(gs)
	return problem


func test_a_short_wallet_and_the_shut_night_hours_refuse_and_a_changed_price_is_not_booked() -> String:
	var day: float = _fitting_day()
	var problems: Array[String] = []
	var poor: GameStateScript = _state(Shuttle.fare())
	_take(poor, [HOST] as Array[String])
	var why: String = _book(poor, [HOST] as Array[String], day)
	if why == "" or poor.credits != Shuttle.fare() or not poor.shuttle_trips.is_empty():
		problems.append("A short wallet: '%s', %d CR" % [why, poor.credits])
	_done(poor)
	var gs: GameStateScript = _state()
	_take(gs, [HOST] as Array[String])
	GameClock.elapsed_days = day
	var shown: int = int(gs.expedition_cost(1)["total"])
	var moved: String = gs.book_expedition(Shuttle.DEIMOS, [HOST], shown + 1)
	if moved == "" or gs.credits != 1000 or not gs.shuttle_trips.is_empty():
		problems.append("A price that is not the one shown: '%s', %d CR" % [moved, gs.credits])
	GameClock.elapsed_days = TunnelRecall.at_hour(int(floorf(day)) + 1, 3.0)  # 03:00 ending that day
	var shut: String = gs.book_expedition(Shuttle.DEIMOS, [HOST], shown)
	if shut == "" or gs.credits != 1000 or not gs.shuttle_trips.is_empty():
		problems.append("Booking at 03:00 is refused: '%s', %d CR" % [shut, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_a_booked_expedition_runs_n_nights_not_to_the_days_end_and_charges_once() -> String:
	var day: float = _fitting_day()
	var gs: GameStateScript = _state()
	var who: Array[String] = [HOST, GUEST]
	_take(gs, [HOST] as Array[String])
	var cost: Dictionary = Shuttle.expedition_cost(2, 0)
	var why: String = _book(gs, who, day)
	var problems: Array[String] = []
	var ends: float = Shuttle.expedition_end(day)
	if why != "":
		problems.append("The booking: '%s'" % why)
	if gs.credits != 1000 - int(cost["total"]):
		problems.append("The total is charged once: %d CR, total %d" % [gs.credits, int(cost["total"])])
	if gs.camp_supplies != 2 * Shuttle.expedition_nights():
		problems.append("The supplies are bought at booking: %d" % gs.camp_supplies)
	for id: String in who:
		var trip: Dictionary = gs.shuttle_trips.get(id, {})
		if not Shuttle.is_expedition(trip) or not is_equal_approx(float(trip.get("ends_at", -1.0)), ends) or gs.place_of(id) != Shuttle.DEIMOS:
			problems.append("%s has the expedition row: %s, place %s" % [id, trip, gs.place_of(id)])
	if _count(gs, HOST, "expedition_booked") != 1:
		problems.append("The booking is counted for the quest")
	# The day ends and the farm's night comes: nobody is sent home.
	GameClock.elapsed_days = TunnelRecall.at_hour(int(floorf(day)) + 1, 3.0)
	gs._end_due_trips()
	if gs.shuttle_trips.size() != 2:
		problems.append("The night at 03:00 does not send an expedition home: %s" % [gs.shuttle_trips])
	GameClock.elapsed_days = ends - 0.01
	gs._end_due_trips()
	if gs.shuttle_trips.size() != 2:
		problems.append("Just before the end the trip runs on")
	var wallet: int = gs.credits
	GameClock.elapsed_days = ends
	gs._end_due_trips()
	if not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM or gs.place_of(GUEST) != ZonePresence.FARM:
		problems.append("At its planned end both are home: %s" % [gs.shuttle_trips])
	if gs.credits != wallet:
		problems.append("Home is free: %d vs %d CR" % [gs.credits, wallet])
	_done(gs)
	return "\n".join(problems)


func test_supplies_already_held_are_not_bought_again() -> String:
	var gs: GameStateScript = _state()
	gs.camp_supplies = 2
	var cost: Dictionary = gs.expedition_cost(1)
	var all: Dictionary = Shuttle.expedition_cost(1, 0)
	var enough: Dictionary = Shuttle.expedition_cost(1, 99)
	_done(gs)
	if int(cost["buy"]) != maxi(Shuttle.expedition_nights() - 2, 0) or int(all["buy"]) != Shuttle.expedition_nights() or int(enough["buy"]) != 0:
		return "Only the shortfall is bought: %s, %s, %s" % [cost, all, enough]
	if int(enough["total"]) != Shuttle.fare():
		return "With enough held it is just the fare: %s" % [enough]
	return ""


# --- Nights away ------------------------------------------------------------------------------

func test_two_oclock_leaves_a_camp_sleeper_be_and_puts_an_awake_traveller_to_bed_at_the_camp() -> String:
	return _bed_farm(true, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		_away(gs, [HOST, GUEST] as Array[String], 99.0, 2)
		var problems: Array[String] = []
		var why: String = gs.go_to_bed(GUEST)
		if why != "" or not gs.is_camping(GUEST) or gs.camp_supplies != 1:
			problems.append("The guest turns in at the camp: '%s', %d supplies" % [why, gs.camp_supplies])
		var wallet: int = gs.credits
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
		gs._tick_expeditions()
		if not gs.shuttle_trips.has(GUEST) or gs.place_of(GUEST) != Shuttle.DEIMOS:
			problems.append("02:00 leaves the sleeper at the camp: %s" % [gs.shuttle_trips])
		if not gs.shuttle_trips.has(HOST) or gs.place_of(HOST) != Shuttle.DEIMOS:
			problems.append("The awake traveller is put to bed at the camp: %s, %s" % [gs.place_of(HOST), gs.shuttle_trips])
		if gs.camp_supplies != 0 or gs.credits != wallet:
			problems.append("One supply, no fee: %d supplies, %d vs %d CR" % [gs.camp_supplies, gs.credits, wallet])
		if _count(gs, HOST, Camp.EXPEDITION_NIGHT_COUNT) != 1:
			problems.append("The night counts as a camp night")
		if clock.get_day_index() != 2:
			problems.append("Both in bed ends the day (%s)" % clock.format_now())
		return "\n".join(problems))


func test_at_two_oclock_with_no_supply_the_awake_traveller_is_flown_home_for_the_rescue_fee() -> String:
	return _bed_farm(false, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		_away(gs, [HOST] as Array[String], 99.0, 0)
		var fee: int = int(TunnelRecall.cost(gs.credits, 0)["credits"])
		var wallet: int = gs.credits
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
		gs._tick_expeditions()
		var problems: Array[String] = []
		if gs.shuttle_trips.has(HOST) or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("Flown home: %s, %s" % [gs.shuttle_trips, gs.place_of(HOST)])
		if fee <= 0 or gs.credits != wallet - fee:
			problems.append("The normal rescue fee: %d CR from %d, fee %d" % [gs.credits, wallet, fee])
		if _count(gs, HOST, "expedition_done") != 0:
			problems.append("A flight home does not complete the trip")
		return "\n".join(problems))


func test_at_midnight_an_awake_traveller_is_told_and_a_sleeper_is_not() -> String:
	return _bed_farm(true, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		_away(gs, [HOST, GUEST] as Array[String], 99.0, 2)
		gs.go_to_bed(GUEST)
		var before: int = gs.phone_log.size()
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 0.5)
		gs._tick_expeditions()
		var warned: int = 0
		for i: int in range(before, gs.phone_log.size()):
			if str(gs.phone_log[i]).contains("RECALL"):
				warned += 1
		if warned != 1:
			return "One warning for the awake traveller: %d" % warned
		gs._tick_expeditions()
		var again: int = 0
		for line: String in gs.phone_log:
			if line.contains("RECALL"):
				again += 1
		return "" if again == warned else "The warning is once a day")


func test_at_midnight_with_only_a_sleeper_away_nobody_is_told() -> String:
	return _bed_farm(true, func(gs: GameStateScript, _beds: Node, _clock: Node) -> String:
		_away(gs, [GUEST] as Array[String], 99.0, 2)
		gs.go_to_bed(GUEST)
		var before: int = gs.phone_log.size()
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 0.5)
		gs._tick_expeditions()
		for i: int in range(before, gs.phone_log.size()):
			if str(gs.phone_log[i]).contains("RECALL"):
				return "A sleeper at the camp is not warned"
		if gs._expedition_warned_day.has(GUEST):
			return "A warning not given is not marked"
		return "")


func test_a_traveller_who_camped_tonight_and_got_up_is_put_back_to_bed_free_at_two() -> String:
	return _bed_farm(true, func(gs: GameStateScript, beds: Node, _clock: Node) -> String:
		var problems: Array[String] = []
		# One supply held: the night the traveller paid for is the last (the second night's case).
		_away(gs, [HOST] as Array[String], 99.0, 1)
		if gs.go_to_bed(HOST) != "" or gs.camp_supplies != 0 or _count(gs, HOST, Camp.EXPEDITION_NIGHT_COUNT) != 1:
			return "Turned in at the camp: %d supplies" % gs.camp_supplies
		beds.get_up(HOST)
		var wallet: int = gs.credits
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
		gs._tick_expeditions()
		if not gs.shuttle_trips.has(HOST) or gs.place_of(HOST) != Shuttle.DEIMOS:
			problems.append("Not flown home for a night already paid: %s" % [gs.shuttle_trips])
		if gs.credits != wallet or gs.camp_supplies != 0 or _count(gs, HOST, Camp.EXPEDITION_NIGHT_COUNT) != 1:
			problems.append("No fee, no second supply, no second night: %d vs %d CR, %d supplies, %d nights" % [gs.credits, wallet, gs.camp_supplies, _count(gs, HOST, Camp.EXPEDITION_NIGHT_COUNT)])
		if not gs.is_camping(HOST):
			problems.append("They are back in bed at the camp")
		# And with supplies to spare the same night is not charged twice.
		var rich: GameStateScript = _state()
		rich.recall_beds = beds
		_away(rich, [HOST] as Array[String], 99.0, 3)
		beds.in_bed.clear()
		rich.go_to_bed(HOST)
		beds.get_up(HOST)
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
		rich._tick_expeditions()
		if rich.camp_supplies != 2 or _count(rich, HOST, Camp.EXPEDITION_NIGHT_COUNT) != 1:
			problems.append("A paid night costs one supply and counts once: %d supplies, %d nights" % [rich.camp_supplies, _count(rich, HOST, Camp.EXPEDITION_NIGHT_COUNT)])
		rich.free()
		return "\n".join(problems))


func test_the_recall_days_are_each_travellers_own_marked_only_when_it_happened_to_them() -> String:
	return _bed_farm(true, func(gs: GameStateScript, beds: Node, _clock: Node) -> String:
		var problems: Array[String] = []
		_away(gs, [HOST, GUEST] as Array[String], 99.0, 4)
		gs.go_to_bed(GUEST)
		# Midnight: only the awake host is warned; the sleeper's day is not used up.
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 0.5)
		gs._tick_expeditions()
		if not gs._expedition_warned_day.has(HOST) or gs._expedition_warned_day.has(GUEST):
			problems.append("Warned days: %s" % [gs._expedition_warned_day])
		beds.get_up(GUEST)
		var told: int = gs.phone_log.size()
		gs._tick_expeditions()
		var lines: int = 0
		for i: int in range(told, gs.phone_log.size()):
			if str(gs.phone_log[i]).contains("RECALL"):
				lines += 1
		if lines != 1 or not gs._expedition_warned_day.has(GUEST):
			problems.append("The sleeper who gets up is warned then, and the host is not warned twice: %d lines" % lines)
		# Two o'clock: the host is carried to bed, the guest has not been touched yet.
		gs._campers.erase(GUEST)
		gs.go_to_bed(GUEST)
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
		gs._tick_expeditions()
		if not gs._expedition_rescued_day.has(HOST) or gs._expedition_rescued_day.has(GUEST):
			problems.append("Rescued days: %s" % [gs._expedition_rescued_day])
		# The guest gets up after the hour: their own recall is still due.
		beds.get_up(GUEST)
		gs._tick_expeditions()
		if not gs._expedition_rescued_day.has(GUEST) or not gs.is_camping(GUEST):
			problems.append("The late riser is put back to bed: %s" % [gs._expedition_rescued_day])
		# A loaded save forgets them like the other recall days.
		var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var saved: float = GameClock.elapsed_days
		if gs.farm_from_dict(data) != "" or not gs._expedition_warned_day.is_empty() or not gs._expedition_rescued_day.is_empty():
			problems.append("farm_from_dict resets the expedition days: %s" % [gs._expedition_rescued_day])
		GameClock.elapsed_days = saved
		return "\n".join(problems))


func test_all_in_bed_ends_the_day_with_one_in_a_farm_bed_and_one_at_the_camp() -> String:
	return _bed_farm(true, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		_away(gs, [GUEST] as Array[String], 99.0, 2)
		var problems: Array[String] = []
		if beds.go_to_bed(HOST) != "" or clock.elapsed_days != 0.5:
			problems.append("The host in a farm bed alone: the day waits")
		var why: String = gs.go_to_bed(GUEST)
		if why != "" or clock.get_day_index() != 2 or clock.elapsed_days != 1.0:
			problems.append("The traveller at the camp is last in bed: the day ends ('%s', %s)" % [why, clock.format_now()])
		if gs.camp_supplies != 1 or gs.credits != 1000:
			problems.append("One shared supply, no fee: %d supplies, %d CR" % [gs.camp_supplies, gs.credits])
		GameClock.elapsed_days = 1.0
		gs._end_due_trips()
		if not gs.shuttle_trips.has(GUEST) or gs.place_of(GUEST) != Shuttle.DEIMOS:
			problems.append("The new day does not send the camper home")
		if _count(gs, GUEST, Camp.NIGHT_COUNT) != 0 or _count(gs, GUEST, Camp.EXPEDITION_NIGHT_COUNT) != 1:
			problems.append("A moon night is its own count")
		return "\n".join(problems))


func test_a_night_at_the_camp_asks_for_an_expedition_and_a_supply() -> String:
	return _bed_farm(false, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
		var problems: Array[String] = []
		# A day-tripper on Deimos has no bed there.
		gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
		gs.shuttle_trips[HOST] = { "moon": Shuttle.DEIMOS, "ends_at": 99.0 }
		gs.camps_open.append(Shuttle.DEIMOS)
		gs.camp_supplies = 3
		if gs.go_to_bed(HOST) == "" or clock.elapsed_days != 0.5 or gs.camp_supplies != 3:
			problems.append("A day trip has no bed on the moon")
		gs.shuttle_trips[HOST]["expedition"] = true
		gs.camps_open.clear()
		if gs.go_to_bed(HOST) == "" or gs.camp_supplies != 3:
			problems.append("A shut camp is no bed")
		gs.camps_open.append(Shuttle.DEIMOS)
		gs.camp_supplies = 0
		if gs.go_to_bed(HOST) == "" or clock.elapsed_days != 0.5:
			problems.append("No supply, no night")
		return "\n".join(problems))


# --- Going home early and the quest -------------------------------------------------------------

func test_going_home_early_ends_the_trip_and_does_not_complete_the_quest() -> String:
	var day: float = _fitting_day()
	var gs: GameStateScript = _state()
	_take(gs, [HOST] as Array[String])
	var why: String = _book(gs, [HOST] as Array[String], day)
	var wallet: int = gs.credits
	var home: String = gs.shuttle_home(HOST)
	_take(gs, [HOST] as Array[String])
	var problems: Array[String] = []
	if why != "" or home != "":
		problems.append("Booked and home: '%s' / '%s'" % [why, home])
	if gs.shuttle_trips.has(HOST) or gs.place_of(HOST) != ZonePresence.FARM or gs.credits != wallet:
		problems.append("Home free: %s, %s, %d vs %d CR" % [gs.shuttle_trips, gs.place_of(HOST), gs.credits, wallet])
	if _count(gs, HOST, "expedition_done") != 0 or QuestEngine.is_done(gs, QUEST, HOST):
		problems.append("Leaving early is not finishing")
	_done(gs)
	return "\n".join(problems)


func test_the_quest_completes_after_the_nights_and_the_trip_home_only_for_who_did_it() -> String:
	var day: float = _fitting_day()
	return _bed_farm(true, func(gs: GameStateScript, beds: Node, _clock: Node) -> String:
		var who: Array[String] = [HOST, GUEST]
		_take(gs, [HOST] as Array[String])
		var problems: Array[String] = []
		if not (gs.player_quest_state.get(HOST, {}) as Dictionary).has(QUEST) or not gs.camps_open.has(Shuttle.DEIMOS):
			return "The quest is taken and opens the Deimos camp: %s" % [gs.camps_open]
		var why: String = _book(gs, who, day)
		if why != "":
			return "The booking: '%s'" % why
		for night: int in Shuttle.expedition_nights():
			for id: String in who:
				var bed: String = gs.go_to_bed(id)
				if bed != "":
					problems.append("Night %d, %s: '%s'" % [night + 1, id, bed])
			# A new morning: the camp's night is over.
			gs._campers.clear()
			for id: String in who:
				beds.get_up(id)
		# The quest looks again after the nights (the test's farm is not wired to a clock).
		_take(gs, [HOST] as Array[String])
		if QuestEngine.is_done(gs, QUEST, HOST) or "home" in (gs.player_quest_state[HOST][QUEST]["steps_done"] as Array) or not "nights" in (gs.player_quest_state[HOST][QUEST]["steps_done"] as Array):
			problems.append("After the nights the quest waits for the trip home: %s" % [gs.player_quest_state[HOST][QUEST]["steps_done"]])
		if gs.has_had_xp_certificate(QUEST, HOST):
			problems.append("No certificate before the trip home")
		GameClock.elapsed_days = Shuttle.expedition_end(day)
		gs._end_due_trips()
		_take(gs, [HOST] as Array[String])
		if _count(gs, HOST, Camp.EXPEDITION_NIGHT_COUNT) != Shuttle.expedition_nights() or _count(gs, HOST, "expedition_done") != 1:
			problems.append("Counted: %d nights, %d done" % [_count(gs, HOST, Camp.EXPEDITION_NIGHT_COUNT), _count(gs, HOST, "expedition_done")])
		if not QuestEngine.is_done(gs, QUEST, HOST):
			problems.append("The quest completes for the one who took it")
		if QuestEngine.is_done(gs, QUEST, GUEST) or (gs.player_quest_state.get(GUEST, {}) as Dictionary).has(QUEST):
			problems.append("Not for the one who never took it")
		if not gs.has_had_xp_certificate(QUEST, HOST) or gs.has_had_xp_certificate(QUEST, GUEST):
			problems.append("The 40 XP certificate goes to the one who did it, not the other")
		elif not gs.held_xp_certificates(HOST).values().has(40):
			problems.append("The certificate is worth 40: %s" % [gs.held_xp_certificates(HOST)])
		return "\n".join(problems))


func test_the_quest_data_is_clean_and_gated_on_the_permit() -> String:
	var found: bool = false
	for quest: Dictionary in QuestEngine.player_quests().values():
		if str(quest["id"]) != QUEST:
			continue
		found = true
		if QuestEngine.data_problem(quest) != "":
			return QuestEngine.data_problem(quest)
		if str(quest.get("camp", "")) != Shuttle.DEIMOS or (quest.get("gates", {}) as Dictionary).get("lab_gate", "") != "expedition_permit":
			return "The quest opens the Deimos camp and needs the permit"
	return "" if found else "The Deimos Survey quest is not in the table"


func test_the_quest_is_not_offered_below_the_permit() -> String:
	var gs: GameStateScript = _state(500, 10)
	_take(gs, [HOST] as Array[String])
	var taken: bool = (gs.player_quest_state.get(HOST, {}) as Dictionary).has(QUEST)
	_done(gs)
	return "" if not taken else "Below lab level 30 the survey is not offered"


# --- Day trips are as before -----------------------------------------------------------------------

func test_day_trips_to_phobos_and_deimos_are_unchanged() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	GameClock.elapsed_days = 3.0 * HOUR
	var wallet: int = gs.credits
	var deimos: String = gs.book_shuttle(Shuttle.DEIMOS, [HOST])
	var row: Dictionary = gs.shuttle_trips.get(HOST, {})
	if deimos != "" or gs.credits != wallet - Shuttle.fare() or row.size() != 2 or row.has("expedition"):
		problems.append("A Deimos day trip: '%s', %d CR, %s" % [deimos, gs.credits, row])
	if _count(gs, HOST, "expedition_booked") != 0 or gs.camp_supplies != 0:
		problems.append("A day trip buys no supplies and is no expedition")
	gs.shuttle_home(HOST)
	var fly: String = gs.book_expedition(Shuttle.PHOBOS, [HOST], 0)
	if fly == "" or gs.shuttle_trips.has(HOST):
		problems.append("Only Deimos has an expedition: '%s'" % fly)
	_done(gs)
	return "\n".join(problems)


func test_a_day_trip_still_ends_at_the_nights_recall() -> String:
	var gs: GameStateScript = _state()
	GameClock.elapsed_days = 3.0 * HOUR
	gs.book_shuttle(Shuttle.DEIMOS, [HOST])
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 3.0)
	gs._end_due_trips()
	var problem: String = "" if gs.shuttle_trips.is_empty() and gs.place_of(HOST) == ZonePresence.FARM else "The day trip is sent home when the night closes"
	_done(gs)
	return problem


# --- Co-op, the command and the save ----------------------------------------------------------------

func test_book_expedition_is_a_host_run_command_a_moon_traveller_cannot_use() -> String:
	var commands: Node = CommandsScript.new()
	var problems: Array[String] = []
	if not &"book_expedition" in CommandsScript.ACTIONS:
		problems.append("book_expedition is a farm command")
	if commands.problem(&"book_expedition", [Shuttle.DEIMOS, [HOST], 100]) != "":
		problems.append("A moon, a party and a total is a well-formed booking")
	if commands.problem(&"book_expedition", [Shuttle.DEIMOS, [HOST]]) == "" or commands.problem(&"book_expedition", [Shuttle.DEIMOS, [HOST], "100"]) == "":
		problems.append("A missing or textual total is refused")
	if &"book_expedition" in CommandsScript.ON_A_MOON:
		problems.append("A traveller on a moon cannot book another trip")
	if not &"go_to_bed" in CommandsScript.ON_A_MOON or not &"shuttle_home" in CommandsScript.ON_A_MOON:
		problems.append("A traveller can still turn in and come home")
	commands.free()
	return "\n".join(problems)


func test_the_protocol_is_48_for_the_new_command_and_row() -> String:
	return "" if CoopSession.PROTOCOL == 54 else "PROTOCOL is %d, not 54." % CoopSession.PROTOCOL


func test_an_expedition_and_the_open_camp_are_saved_and_an_old_save_loads() -> String:
	var gs: GameStateScript = _state()
	gs.shuttle_trips[HOST] = { "moon": Shuttle.DEIMOS, "ends_at": 6.0, "expedition": true }
	gs.camps_open.append(Shuttle.DEIMOS)
	gs.camp_supplies = 4
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	var problems: Array[String] = []
	var back: GameStateScript = _state()
	GameClock.elapsed_days = 3.0
	if back.farm_from_dict(data) != "" or not Shuttle.is_expedition(back.shuttle_trips.get(HOST)) or not back.camps_open.has(Shuttle.DEIMOS) or back.camp_supplies != 4:
		problems.append("A save keeps the expedition and the open camp: %s, %s" % [back.shuttle_trips, back.camps_open])
	# An old save: a day trip row with its two keys, and no camp.
	var old: Dictionary = data.duplicate(true)
	old["shuttle_trips"] = { HOST: { "moon": Shuttle.DEIMOS, "ends_at": 6.0 } }
	old.erase("camps_open")
	var past: GameStateScript = _state()
	if past.farm_from_dict(old) != "" or past.camps_open.has(Shuttle.DEIMOS):
		problems.append("An old save loads: day trip row, no camp")
	var bad: Dictionary = data.duplicate(true)
	bad["shuttle_trips"] = { HOST: { "moon": Shuttle.DEIMOS, "ends_at": 6.0, "expedition": false } }
	var junk: GameStateScript = _state()
	if junk.farm_from_dict(bad) == "":
		problems.append("A row with the flag false is refused")
	back.free()
	past.free()
	junk.free()
	_done(gs)
	return "\n".join(problems)


func test_a_guest_sees_the_trip_row_and_the_open_camp_through_the_sync() -> String:
	if not FarmSync.SHOWN_BY.get(&"camps_changed", []).has("camps_open"):
		return "The camp reaches a guest"
	if not FarmSync.SHOWN_BY.get(&"shuttle_trips_changed", []).has("shuttle_trips"):
		return "The trips reach a guest"
	# The real round trip: capture on the host, update a playing guest and join a late one,
	# with an expedition row and more nights held than the camp hub's own cap.
	var host: GameStateScript = _state()
	host.shuttle_trips[GUEST] = { "moon": Shuttle.DEIMOS, "ends_at": 6.0, "expedition": true }
	host.camps_open.append(Shuttle.DEIMOS)
	host.camp_supplies = Camp.MAX_SUPPLIES + 5
	var bytes: PackedByteArray = FarmSync.capture(host)
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var elapsed: float = GameClock.elapsed_days
	var open: bool = SaveGame.farm_open
	for late: bool in [false, true]:
		var guest: GameStateScript = _state()
		guest.local_player_id = GUEST
		FarmCommands.guest = true
		var told: String = FarmSync.join(bytes, guest) if late else FarmSync.update(bytes, guest)
		FarmCommands.guest = held_guest
		GameClock.elapsed_days = elapsed
		SaveGame.farm_open = open
		if told != "":
			problems.append("%s: '%s'" % ["join" if late else "update", told])
		elif not Shuttle.is_expedition(guest.shuttle_trips.get(GUEST)) or not guest.camps_open.has(Shuttle.DEIMOS) or guest.camp_supplies != Camp.MAX_SUPPLIES + 5:
			problems.append("The guest sees the row, the camp and the supplies (%s): %s, %s, %d" % ["join" if late else "update", guest.shuttle_trips, guest.camps_open, guest.camp_supplies])
		guest.free()
	# The guest's own booking command is plain, typed list and all, and a well-formed command.
	var party: Array[String] = [GUEST, HOST]
	if not CoopSession.plain_arguments([Shuttle.DEIMOS, party, 120]) or not CoopSession.plain_arguments([Shuttle.DEIMOS, [GUEST], 120]):
		problems.append("A booking's arguments are plain")
	var commands: Node = CommandsScript.new()
	if commands.problem(&"book_expedition", [Shuttle.DEIMOS, party, 120]) != "":
		problems.append("A guest's booking is a well-formed command")
	commands.free()
	host.free()
	return "\n".join(problems)


func test_a_survey_brought_finished_opens_the_camp_before_it_books() -> String:
	var day: float = _fitting_day()
	var gs: GameStateScript = _state()
	# A finished Deimos Survey came with the host from another farm; nothing has run since.
	gs.player_quest_state[HOST] = { QUEST: { "accepted": 1, "steps_done": ["book", "nights", "home"], "base": {}, "shown": {}, "players": [HOST], "done": 1, "carried": {} } }
	var problems: Array[String] = []
	if gs.camps_open.has(Shuttle.DEIMOS):
		problems.append("The camp starts shut")
	var why: String = _book(gs, [HOST] as Array[String], day)
	if why != "" or not gs.camps_open.has(Shuttle.DEIMOS):
		problems.append("A booking is never to a shut camp: '%s', %s" % [why, gs.camps_open])
	_done(gs)
	return "\n".join(problems)


func test_the_trip_home_does_not_count_an_expedition_done_before_the_quest_was_taken() -> String:
	var gs: GameStateScript = _state()
	var own: Dictionary = gs.action_counts.get_or_add(HOST, {}) as Dictionary
	own["expedition_done"] = { "count": 1, "xp": 0 }
	own[Camp.EXPEDITION_NIGHT_COUNT] = { "count": 5, "xp": 0 }
	_take(gs, [HOST] as Array[String])
	var problems: Array[String] = []
	own["expedition_booked"] = { "count": int(((own.get("expedition_booked", {}) as Dictionary).get("count", 0))) + 1, "xp": 0 }
	_take(gs, [HOST] as Array[String])
	own[Camp.EXPEDITION_NIGHT_COUNT]["count"] = 7
	_take(gs, [HOST] as Array[String])
	var done_steps: Array = gs.player_quest_state[HOST][QUEST]["steps_done"]
	if not "nights" in done_steps or "home" in done_steps or QuestEngine.is_done(gs, QUEST, HOST):
		problems.append("Two new nights do not finish an old trip home: %s" % [done_steps])
	own["expedition_done"]["count"] = 2
	_take(gs, [HOST] as Array[String])
	if not QuestEngine.is_done(gs, QUEST, HOST):
		problems.append("A trip run to its end after the nights does")
	_done(gs)
	return "\n".join(problems)


func test_the_words_say_the_day_the_close_day_and_the_real_supply_numbers() -> String:
	var problems: Array[String] = []
	var short: String = Shuttle.expedition_problem(Shuttle.DEIMOS, 30, true, 0, 2, _fitting_day(), true, 30, true, true, 1)
	var cost: Dictionary = Shuttle.expedition_cost(2, 1)
	var bought: String = "%d bought of the %d needed" % [int(cost["buy"]), int(cost["needed"])]
	if not short.contains(bought) or not short.contains("supplies %d CR" % int(cost["supplies"])):
		problems.append("The short-wallet line gives the real supply numbers (%s): %s" % [bought, short])
	var at: float = _short_day()
	if at >= 0.0:
		var window: String = Shuttle.expedition_problem(Shuttle.DEIMOS, 30, true, 9999, 1, at, true, 30, true, true, 0)
		var back: float = Shuttle.expedition_end(at)
		var shuts: float = Shuttle.closes_at(Shuttle.DEIMOS, at)
		if not window.contains("home day %d at" % (floori(back) + 1)) or not window.contains("closes day %d at" % (floori(shuts) + 1)):
			problems.append("The window line says the days: %s" % window)
	return "\n".join(problems)


func test_an_expedition_row_must_be_to_deimos_and_the_camp_list_has_it() -> String:
	var problems: Array[String] = []
	if Shuttle.trip_shape_problem({ "moon": Shuttle.PHOBOS, "ends_at": 6.0, "expedition": true }) == "":
		problems.append("An expedition to Phobos (no camp) is refused")
	if Shuttle.trip_shape_problem({ "moon": Shuttle.DEIMOS, "ends_at": 6.0, "expedition": true }) != "" or Shuttle.trip_shape_problem({ "moon": Shuttle.PHOBOS, "ends_at": 6.0 }) != "":
		problems.append("A Deimos expedition and a Phobos day trip stay well-formed")
	for zone: String in Camp.zones():
		if not Camp.has_camp(zone):
			problems.append("%s is listed but has no camp" % zone)
	if not Shuttle.DEIMOS in Camp.zones() or not Camp.zones().has("lava_tubes"):
		problems.append("zones() lists both camps: %s" % [Camp.zones()])
	return "\n".join(problems)


func test_the_deimos_bed_needs_the_camp_within_reach_not_the_whole_moon() -> String:
	var near: Node3D = Node3D.new()
	var far: Node3D = Node3D.new()
	var root: Node = Engine.get_main_loop().root  # global_position needs a walker in the tree
	root.add_child(near)
	root.add_child(far)
	near.position = Camp.position(Shuttle.DEIMOS) + Vector3(Camp.MOON_REACH_M - 1.0, 0.0, 0.0)
	far.position = Camp.position(Shuttle.DEIMOS) + Vector3(Camp.MOON_REACH_M + 1.0, 0.0, 0.0)
	var problems: Array[String] = []
	if Camp.moon_reach_refusal(Shuttle.DEIMOS, near) != "":
		problems.append("Near the camp the bed is open")
	if Camp.moon_reach_refusal(Shuttle.DEIMOS, far) == "" or Camp.moon_reach_refusal(Shuttle.DEIMOS, null) == "":
		problems.append("Far from it, or with no walker to say, the bed is refused")
	if Camp.moon_reach_refusal("lava_tubes", far) != "":
		problems.append("A rover camp has its own reach rule, not this one")
	near.free()
	far.free()
	return "\n".join(problems)
