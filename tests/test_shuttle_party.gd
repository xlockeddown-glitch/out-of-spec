extends "res://tests/coop_net.gd"
## Shuttle parties (docs/design/zones.md section 8.2, step 16): one booking flies the
## booker and everyone else on the farm at the terminal, each fare is paid from the
## shared wallet, each passenger has their own trip and goes home alone, and a guest's
## screen follows a booking someone else made. Every node is freed; the clock, the
## session's players and the walkers are put back.

const HOST: String = "player_1"
const GUEST: String = "player_2"
const THIRD: String = "player_3"
const HOUR: float = 1.0 / 24.0
const AT_PAD := Vector3(Shuttle.TERMINAL_AT.x, 0.0, Shuttle.TERMINAL_AT.y)

var _held_players: Array[String] = []


func _state(credits: int = 500, here: Array[String] = [HOST, GUEST]) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(515151)
	gs.local_player_id = HOST
	gs.credits = credits
	gs.shuttle_licensed = true
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 3.0 * HOUR  # 09:00 of day 1: Phobos' first window is open
	_held_players = CoopSession.players.duplicate()
	CoopSession.players.assign(here)
	for id: String in here:
		CoopWalkers.stand(id, AT_PAD)
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	CoopSession.players.assign(_held_players)
	for id: String in [HOST, GUEST, THIRD, "player_4", "player_5"]:
		CoopWalkers.out.erase(id)
	gs.free()


func _reached(gs: GameStateScript, id: String) -> int:
	var counts: Dictionary = gs.action_counts.get(id, {})
	return int((counts.get(GameStateScript.REACHED_PREFIX + Shuttle.PHOBOS, {}) as Dictionary).get("count", 0))


func test_two_at_the_terminal_fly_on_one_booking_and_pay_two_fares() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var heard: Array[int] = [0]
	gs.shuttle_trips_changed.connect(func() -> void: heard[0] += 1)
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, 2)
	if told != "":
		problems.append("A party of two is refused: '%s'" % told)
	if gs.credits != 500 - 2 * Shuttle.fare():
		problems.append("Two fares: %d CR left, fare %d." % [gs.credits, Shuttle.fare()])
	for id: String in [HOST, GUEST]:
		var trip: Dictionary = gs.shuttle_trips.get(id, {})
		if trip.get("moon", "") != Shuttle.PHOBOS or not is_equal_approx(float(trip.get("ends_at", 0.0)), Shuttle.trip_end(GameClock.elapsed_days)):
			problems.append("%s has no proper trip: %s" % [id, trip])
		if gs.place_of(id) != Shuttle.PHOBOS or CoopWalkers.is_out(id):
			problems.append("%s is not at the moon off the farm's ground: %s" % [id, gs.place_of(id)])
		if _reached(gs, id) != 1:
			problems.append("%s has %d reached counts." % [id, _reached(gs, id)])
	if heard[0] != 1 or gs.phone_log.filter(func(line: String) -> bool: return line.contains("2 going")).size() != 1:
		problems.append("One change told and one phone line: %d, %s" % [heard[0], gs.phone_log])
	if gs.action_counts.has(GameStateScript.MANAGER_ID):
		problems.append("The Manager must not be counted.")
	_done(gs)
	return "\n".join(problems)


func test_a_player_away_from_the_terminal_on_a_trip_or_in_a_zone_is_not_in_the_party() -> String:
	var gs: GameStateScript = _state(500, [HOST, GUEST, THIRD, "player_4"])
	var problems: Array[String] = []
	CoopWalkers.stand(GUEST, Vector3(0.0, 0.0, 30.0))
	gs.shuttle_trips[THIRD] = { "moon": Shuttle.DEIMOS, "ends_at": 1.0e9 }
	gs.player_places["player_4"] = ["lava_tubes", 0]
	var party: Array[String] = gs.shuttle_party(HOST)
	if party.size() != 1 or party[0] != HOST:
		problems.append("Only the booker is at the pad on the farm: %s" % [party])
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, 1)
	if told != "" or gs.shuttle_trips.has(GUEST) or gs.credits != 500 - Shuttle.fare() or gs.place_of(GUEST) != ZonePresence.FARM:
		problems.append("A solo booking leaves the rest alone: '%s', %d CR" % [told, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_a_count_that_does_not_match_the_party_is_refused_and_charges_nothing() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, 1)
	if told != Shuttle.text("party_changed_text") or gs.credits != 500 or not gs.shuttle_trips.is_empty():
		problems.append("A count of 1 with two at the pad: '%s', %d CR, %s" % [told, gs.credits, gs.shuttle_trips])
	CoopWalkers.stand(GUEST, Vector3(0.0, 0.0, 30.0))
	told = gs.book_shuttle(Shuttle.PHOBOS, 2)
	if told != Shuttle.text("party_changed_text") or gs.credits != 500 or not gs.shuttle_trips.is_empty():
		problems.append("A count of 2 after the guest walked off: '%s', %d CR" % [told, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_a_wallet_for_one_fare_refuses_two_and_a_party_over_the_most_refuses() -> String:
	var problems: Array[String] = []
	var poor: GameStateScript = _state(Shuttle.fare() * 2 - 1)
	var told: String = poor.book_shuttle(Shuttle.PHOBOS, 2)
	if told == "" or poor.credits != Shuttle.fare() * 2 - 1 or not poor.shuttle_trips.is_empty():
		problems.append("One fare of two: '%s', %d CR" % [told, poor.credits])
	_done(poor)
	var many: Array[String] = []
	for index: int in Shuttle.party_most() + 1:
		many.append("player_%d" % (index + 1))
	var crowd: GameStateScript = _state(5000, many)
	var over: String = crowd.book_shuttle(Shuttle.PHOBOS, many.size())
	if over != Shuttle.text("bad_party_text") % SP811.integer(Shuttle.party_most()) or crowd.credits != 5000 or not crowd.shuttle_trips.is_empty():
		problems.append("A party of %d: '%s', %d CR" % [many.size(), over, crowd.credits])
	_done(crowd)
	return "\n".join(problems)


func test_each_passenger_goes_home_alone_and_the_other_stays() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, 2) != "":
		problems.append("The booking was refused.")
	var wallet: int = gs.credits
	if gs.shuttle_home(GUEST) != "" or gs.place_of(GUEST) != ZonePresence.FARM or gs.shuttle_trips.has(GUEST):
		problems.append("The guest did not come home.")
	if not gs.shuttle_trips.has(HOST) or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("The host must stay on the moon.")
	if gs.credits != wallet:
		problems.append("The way home is free.")
	# The trip's end brings the rest.
	GameClock.elapsed_days = float(gs.shuttle_trips[HOST]["ends_at"]) + 0.001
	gs._end_due_trips()
	if not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM:
		problems.append("The trip's end must bring the host home.")
	_done(gs)
	return "\n".join(problems)


func test_a_guest_is_flown_by_the_hosts_booking_and_its_screen_goes_to_the_hub() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var booked: Variant = commands.execute(HOST, &"book_shuttle", [Shuttle.PHOBOS, 2])
	commands.free()
	if booked != "":
		problems.append("The host's booking: '%s'" % booked)
	# The guest's screen reads its own synced trip, which the host's booking wrote.
	var trip: Variant = gs.shuttle_trips.get(GUEST)
	for path: String in [SceneSwitcher.FARM_SCENE, SceneSwitcher.DOME_SCENE]:
		if Shuttle.hub_to_join(trip, path) != SceneSwitcher.PHOBOS_SCENE:
			problems.append("The guest's screen at %s must go to the hub." % path)
	if not GameState.shuttle_trips_changed.is_connected(SceneSwitcher.reconcile_trip):
		problems.append("The screens follow trip changes through reconcile_trip.")
	# The host's own screen follows too, not only a guest's: with no scene it sets out for none.
	if SceneSwitcher.reconcile_trip() != "":
		problems.append("With no scene running nothing is reconciled.")
	_done(gs)
	return "\n".join(problems)


func test_a_solo_booking_works_as_before() -> String:
	var gs: GameStateScript = _state(500, [HOST])
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, 1) != "" or gs.credits != 500 - Shuttle.fare() or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("A solo booking: %d CR, %s" % [gs.credits, gs.place_of(HOST)])
	if gs.shuttle_trips.size() != 1 or _reached(gs, HOST) != 1:
		problems.append("One trip and one count: %s" % [gs.shuttle_trips])
	_done(gs)
	return "\n".join(problems)


func test_the_panel_shows_who_flies_and_the_total_fare() -> String:
	var problems: Array[String] = []
	var alone: String = "\n".join(ShuttleUI.lines(0.5, true))
	if not alone.contains(Shuttle.text("terminal_party_alone")) or not alone.contains(Shuttle.text("terminal_total") % SP811.integer(Shuttle.fare())):
		problems.append("Alone: %s" % alone)
	var names: Array[String] = ["PLAYER 2"]
	var two: String = "\n".join(ShuttleUI.lines(0.5, true, names))
	if not two.contains("Party: 2 (you and PLAYER 2)") or not two.contains(Shuttle.text("terminal_total") % SP811.integer(Shuttle.fare() * 2)):
		problems.append("Two: %s" % two)
	return "\n".join(problems)
