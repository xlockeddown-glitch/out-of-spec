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
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, [HOST, GUEST])
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
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, [gs.local_player_id])
	if told != "" or gs.shuttle_trips.has(GUEST) or gs.credits != 500 - Shuttle.fare() or gs.place_of(GUEST) != ZonePresence.FARM:
		problems.append("A solo booking leaves the rest alone: '%s', %d CR" % [told, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_a_count_that_does_not_match_the_party_is_refused_and_charges_nothing() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, [gs.local_player_id])
	if told != Shuttle.text("party_changed_text") or gs.credits != 500 or not gs.shuttle_trips.is_empty():
		problems.append("A count of 1 with two at the pad: '%s', %d CR, %s" % [told, gs.credits, gs.shuttle_trips])
	CoopWalkers.stand(GUEST, Vector3(0.0, 0.0, 30.0))
	told = gs.book_shuttle(Shuttle.PHOBOS, [HOST, GUEST])
	if told != Shuttle.text("party_changed_text") or gs.credits != 500 or not gs.shuttle_trips.is_empty():
		problems.append("A count of 2 after the guest walked off: '%s', %d CR" % [told, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_a_wallet_for_one_fare_refuses_two_and_a_party_over_the_most_refuses() -> String:
	var problems: Array[String] = []
	var poor: GameStateScript = _state(Shuttle.fare() * 2 - 1)
	var told: String = poor.book_shuttle(Shuttle.PHOBOS, [HOST, GUEST])
	var short: String = Shuttle.text("short_text") % [Shuttle.moon_name(Shuttle.PHOBOS), SP811.integer(Shuttle.fare() * 2), SP811.integer(Shuttle.fare()), SP811.integer(2), SP811.integer(poor.credits)]
	if told != short or poor.credits != Shuttle.fare() * 2 - 1 or not poor.shuttle_trips.is_empty():
		problems.append("One fare of two: '%s', %d CR" % [told, poor.credits])
	_done(poor)
	var many: Array[String] = []
	for index: int in Shuttle.party_most() + 1:
		many.append("player_%d" % (index + 1))
	var crowd: GameStateScript = _state(5000, many)
	var over: String = crowd.book_shuttle(Shuttle.PHOBOS, many)
	if over != Shuttle.text("bad_party_text") % SP811.integer(Shuttle.party_most()) or crowd.credits != 5000 or not crowd.shuttle_trips.is_empty():
		problems.append("A party of %d: '%s', %d CR" % [many.size(), over, crowd.credits])
	_done(crowd)
	return "\n".join(problems)


func test_each_passenger_goes_home_alone_and_the_other_stays() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, [HOST, GUEST]) != "":
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
	var booked: Variant = commands.execute(HOST, &"book_shuttle", [Shuttle.PHOBOS, [HOST, GUEST]])
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
	_done(gs)
	return "\n".join(problems)


func test_a_solo_booking_works_as_before() -> String:
	var gs: GameStateScript = _state(500, [HOST])
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, [gs.local_player_id]) != "" or gs.credits != 500 - Shuttle.fare() or gs.place_of(HOST) != Shuttle.PHOBOS:
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


# --- review round: booking by ids, who counts, beds, the rover, the screens --------

func test_a_swapped_party_is_refused_though_the_count_matches() -> String:
	var gs: GameStateScript = _state(500, [HOST, GUEST, THIRD])
	var problems: Array[String] = []
	CoopWalkers.stand(GUEST, Vector3(0.0, 0.0, 30.0))  # the panel drew [HOST, GUEST]; GUEST walked off, THIRD is here
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, [HOST, GUEST])
	if told != Shuttle.text("party_changed_text") or gs.credits != 500 or not gs.shuttle_trips.is_empty():
		problems.append("A swapped party of the same size: '%s', %d CR, %s" % [told, gs.credits, gs.shuttle_trips])
	if gs.book_shuttle(Shuttle.PHOBOS, [HOST, THIRD, GUEST]) != Shuttle.text("party_changed_text"):
		problems.append("A set with someone extra is refused.")
	if gs.book_shuttle(Shuttle.PHOBOS, [THIRD, HOST]) != Shuttle.text("party_changed_text"):
		problems.append("The booker must be first.")
	if gs.book_shuttle(Shuttle.PHOBOS, [HOST, THIRD]) != "" or gs.shuttle_trips.has(GUEST) or not gs.shuttle_trips.has(THIRD):
		problems.append("The right set flies: %s" % [gs.shuttle_trips])
	_done(gs)
	return "\n".join(problems)


func test_a_booking_with_a_bad_argument_shape_is_a_refusal_not_an_error() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	var commands: Node = CommandsScript.new()
	commands.state = gs
	for bad: Array in [[], [1, 2], [HOST, 5], [null], ["", ""]]:
		var told: String = gs.book_shuttle(Shuttle.PHOBOS, bad)
		if told == "" or gs.credits != 500 or not gs.shuttle_trips.is_empty():
			problems.append("%s must be refused: '%s'" % [bad, told])
	if commands.problem(&"book_shuttle", [Shuttle.PHOBOS, "two"]) == "":
		problems.append("A string for the party must fail the command's shape.")
	commands.free()
	_done(gs)
	return "\n".join(problems)


func test_a_host_in_bed_at_the_terminal_is_flown_and_gets_up() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	CoopBeds.in_bed.append(HOST)
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, [GUEST, HOST], GUEST)
	var still_in_bed: bool = HOST in CoopBeds.in_bed
	CoopBeds.in_bed.erase(HOST)
	if told != "" or not gs.shuttle_trips.has(HOST):
		problems.append("The guest's booking flies the host: '%s'" % told)
	if still_in_bed:
		problems.append("A flown host must not still count as in bed.")
	_done(gs)
	return "\n".join(problems)


func test_only_those_on_foot_at_the_terminal_or_driving_the_rover_there_are_in_the_party() -> String:
	var gs: GameStateScript = _state(500, [HOST, GUEST, THIRD])
	var problems: Array[String] = []
	# A just-joined guest has no pose at all; a rider in the rover parked at the pad is not driving it.
	CoopWalkers.out.erase(GUEST)
	CoopWalkers.out.erase(THIRD)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(AT_PAD.x, 0.5, AT_PAD.z))
	CoopRovers._drivers.erase(gs.ROVER)
	var none: Array[String] = gs.shuttle_party(HOST)
	if GUEST in none or THIRD in none:
		problems.append("No pose and no driving: not in the party: %s" % [none])
	CoopRovers._drivers[gs.ROVER] = [GUEST, Time.get_ticks_msec() + 60000]
	var with_driver: Array[String] = gs.shuttle_party(HOST)
	CoopRovers._drivers.erase(gs.ROVER)
	if not GUEST in with_driver or THIRD in with_driver:
		problems.append("The rover's driver at the pad is in the party, its rider is not: %s" % [with_driver])
	_done(gs)
	return "\n".join(problems)


func test_the_manager_in_the_party_is_flown_and_never_counted() -> String:
	var gs: GameStateScript = _state(500, [HOST, GameStateScript.MANAGER_ID])
	var problems: Array[String] = []
	CoopWalkers.stand(GameStateScript.MANAGER_ID, AT_PAD)
	var told: String = gs.book_shuttle(Shuttle.PHOBOS, [HOST, GameStateScript.MANAGER_ID])
	CoopWalkers.out.erase(GameStateScript.MANAGER_ID)
	if told != "":
		problems.append("The party with the Manager: '%s'" % told)
	if gs.action_counts.has(GameStateScript.MANAGER_ID):
		problems.append("The Manager must not be counted as having reached the moon.")
	if _reached(gs, HOST) != 1:
		problems.append("The host is counted.")
	_done(gs)
	return "\n".join(problems)


func test_the_hosts_own_screen_follows_a_trip_and_not_after_the_trip_ended() -> String:
	var problems: Array[String] = []
	var held_trips: Dictionary = GameState.shuttle_trips.duplicate()
	var held_guest: bool = FarmCommands.guest
	var calls: Array[String] = []
	SceneSwitcher.swap_hook = func(path: String) -> void: calls.append(path)
	FarmCommands.guest = false
	var me: String = GameState.local_player_id
	GameState.shuttle_trips[me] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
	SceneSwitcher.fake_scene_path = SceneSwitcher.FARM_SCENE
	if SceneSwitcher.reconcile_trip() != SceneSwitcher.PHOBOS_SCENE or calls != [SceneSwitcher.PHOBOS_SCENE]:
		problems.append("The host's farm screen goes to the hub: %s" % [calls])
	SceneSwitcher.fake_scene_path = SceneSwitcher.TITLE_SCENE
	if SceneSwitcher.reconcile_trip() != "":
		problems.append("The title screen is left alone.")
	# A swap in progress: the trip ends while this waits, so nothing is flown to a stale hub.
	calls.clear()
	SceneSwitcher.fake_scene_path = SceneSwitcher.FARM_SCENE
	SceneSwitcher._busy = true
	SceneSwitcher.reconcile_trip()
	GameState.shuttle_trips.erase(me)
	SceneSwitcher._busy = false
	SceneSwitcher.scene_swapped.emit(SceneSwitcher.FARM_SCENE)
	if not calls.is_empty():
		problems.append("The trip ended during the wait: still went to %s" % [calls])
	SceneSwitcher.swap_hook = Callable()
	SceneSwitcher.fake_scene_path = ""
	FarmCommands.guest = held_guest
	GameState.shuttle_trips.assign(held_trips)
	return "\n".join(problems)


func test_a_blocked_swap_is_made_when_the_fast_travel_wait_clears() -> String:
	var problems: Array[String] = []
	var held_trips: Dictionary = GameState.shuttle_trips.duplicate()
	var calls: Array[String] = []
	SceneSwitcher.swap_hook = func(path: String) -> void: calls.append(path)
	GameState.shuttle_trips[GameState.local_player_id] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
	SceneSwitcher.fake_scene_path = SceneSwitcher.DOME_SCENE
	var ui := FastTravelUI.new()
	FastTravel.pending = true
	ui._clear_pending()
	ui.free()
	if FastTravel.pending or calls != [SceneSwitcher.PHOBOS_SCENE]:
		problems.append("Clearing the console wait must follow the trip: pending %s, %s" % [FastTravel.pending, calls])
	SceneSwitcher.swap_hook = Callable()
	SceneSwitcher.fake_scene_path = ""
	GameState.shuttle_trips.assign(held_trips)
	return "\n".join(problems)
