extends "res://tests/coop_net.gd"
## The Deimos hub (docs/design/zones.md section 13, step 17, second half): booking the
## shuttle to Deimos inside its open spell only (fare once, trip recorded, place deimos),
## a shut spell refused with the reason and nothing charged, the way home (console and
## the clock) being free, the farm's night never touching the traveller, the trip in the
## save, a guest following the host's trip to the Deimos hub, and the hub scene itself.
## Every node is freed; the clock and the walkers are put back.

const HOST: String = "player_1"
const GUEST: String = "player_2"
const HOUR: float = 1.0 / 24.0


func _state(credits: int = 500) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(515151)
	gs.local_player_id = HOST
	gs.credits = credits
	gs.shuttle_licensed = true
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 3.0 * HOUR  # 09:00 of day 1: Deimos' first spell is open
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	CoopWalkers.out.erase(HOST)
	CoopWalkers.out.erase(GUEST)
	gs.free()


func _commands(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


func test_booking_deimos_while_open_lands_at_the_hub_and_the_fare_is_paid_once() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if not Shuttle.is_open(Shuttle.DEIMOS, GameClock.elapsed_days):
		problems.append("Deimos should be up at 09:00 of day 1.")
	var answer: String = gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id])
	if answer != "":
		problems.append("A licensed booking in the spell is refused: '%s'" % answer)
	if gs.credits != 500 - Shuttle.fare():
		problems.append("The fare is taken once: %d CR left of 500, fare %d." % [gs.credits, Shuttle.fare()])
	var trip: Dictionary = gs.shuttle_trips.get(HOST, {})
	if trip.get("moon", "") != Shuttle.DEIMOS or not is_equal_approx(float(trip.get("ends_at", 0.0)), Shuttle.trip_end(GameClock.elapsed_days)):
		problems.append("The trip is not recorded with its end: %s" % [gs.shuttle_trips])
	if gs.place_of(HOST) != Shuttle.DEIMOS or not ZonePresence.is_place(gs.place_of(HOST)):
		problems.append("The traveller's place is not Deimos: %s" % gs.place_of(HOST))
	var again: String = gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id])
	if again == "" or gs.credits != 500 - Shuttle.fare():
		problems.append("A second booking from Deimos is refused and charges nothing: '%s', %d CR" % [again, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_booking_deimos_while_shut_is_refused_with_the_reason_and_charges_nothing() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	GameClock.elapsed_days = 70.0 * HOUR  # past the 60 h spell, inside the 60 h shut time
	if Shuttle.is_open(Shuttle.DEIMOS, GameClock.elapsed_days):
		problems.append("Deimos should be down at 70 h.")
	var answer: String = gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id])
	var reason: String = Shuttle.text("moon_down_text") % Shuttle.window_line(Shuttle.DEIMOS, GameClock.elapsed_days)
	if answer != reason:
		problems.append("A shut Deimos is refused with the window line: '%s'" % answer)
	if gs.credits != 500 or not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM:
		problems.append("A refusal charges nothing: %d CR, %s, %s" % [gs.credits, gs.shuttle_trips, gs.place_of(HOST)])
	_done(gs)
	return "\n".join(problems)


func test_the_console_and_the_trips_end_bring_a_deimos_traveller_home_free() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id]) != "":
		problems.append("Booking failed.")
	var wallet: int = gs.credits
	var home: Variant = commands.execute(HOST, &"shuttle_home", [])
	if home != "" or gs.credits != wallet or not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM:
		problems.append("The console way home is free: '%s', %d CR of %d, %s" % [home, gs.credits, wallet, gs.place_of(HOST)])
	if not CoopWalkers.is_out(HOST) or not Shuttle.terminal_near(CoopWalkers.spot(CoopWalkers.out[HOST]), 0.0):
		problems.append("The traveller stands on foot by the terminal.")
	CoopWalkers.out.erase(HOST)
	if gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id]) != "":
		problems.append("A second booking failed.")
	wallet = gs.credits
	GameClock.elapsed_days += (Shuttle.trip_hours() - 0.5) * HOUR
	gs._end_due_trips()
	if gs.shuttle_trips.is_empty() or gs.place_of(HOST) != Shuttle.DEIMOS:
		problems.append("Half an hour before its end the trip goes on.")
	GameClock.elapsed_days += 0.6 * HOUR
	gs._end_due_trips()
	if not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM or gs.credits != wallet:
		problems.append("At its end the trip is over, free: %s, %s, %d CR" % [gs.shuttle_trips, gs.place_of(HOST), gs.credits])
	commands.free()
	_done(gs)
	return "\n".join(problems)


func test_midnight_and_two_never_charge_or_rescue_a_deimos_traveller() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	gs.shuttle_trips[HOST] = { "moon": Shuttle.DEIMOS, "ends_at": TunnelRecall.at_hour(1, 3.5) }
	gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
	gs.rover_in_tunnels = true
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 0.5)
	gs._end_due_trips()
	gs._tick_recall()
	if gs.credits != 500 or gs.place_of(HOST) != Shuttle.DEIMOS:
		problems.append("Past 00:00 nothing is charged and the trip goes on: %d CR, %s" % [gs.credits, gs.place_of(HOST)])
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	gs._end_due_trips()
	gs._tick_recall()
	if gs.credits != 500 or gs.crystal_ore != 0:
		problems.append("At 02:00 nothing is charged: %d CR, %d ore" % [gs.credits, gs.crystal_ore])
	if gs.place_of(HOST) != ZonePresence.FARM or not gs.shuttle_trips.is_empty():
		problems.append("A straggler at 02:00 is sent home by the shuttle: %s, %s" % [gs.place_of(HOST), gs.shuttle_trips])
	_done(gs)
	return "\n".join(problems)


func test_a_guest_is_booked_and_sent_home_by_the_host_for_deimos() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	gs.player_places[GUEST] = [ZonePresence.FARM, 0]
	CoopWalkers.stand(GUEST, Vector3(Shuttle.TERMINAL_AT.x, 0.0, Shuttle.TERMINAL_AT.y))
	CoopWalkers.stand(HOST, Vector3(0.0, 0.0, 30.0))  # the host is off at the farm, not in the party
	var booked: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.DEIMOS, [GUEST]])
	if booked != "" or gs.place_of(GUEST) != Shuttle.DEIMOS or gs.credits != 500 - Shuttle.fare():
		problems.append("A guest's booking: '%s', %s, %d CR" % [booked, gs.place_of(GUEST), gs.credits])
	if gs.place_of(HOST) != ZonePresence.FARM:
		problems.append("The host stays on the farm.")
	var wallet: int = gs.credits
	var home: Variant = commands.execute(GUEST, &"shuttle_home", [])
	if home != "" or gs.place_of(GUEST) != ZonePresence.FARM or gs.shuttle_trips.has(GUEST) or gs.credits != wallet:
		problems.append("A guest's way home: '%s', %s, %d CR" % [home, gs.place_of(GUEST), gs.credits])
	commands.free()
	_done(gs)
	return "\n".join(problems)


func test_a_deimos_trip_is_saved_and_an_old_save_still_loads() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id]) != "":
		problems.append("Booking failed.")
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if gs.farm_dict_problem(data) != "":
		problems.append("A save with a Deimos trip is sound: %s" % gs.farm_dict_problem(data))
	var back: GameStateScript = _state(0)
	if back.farm_from_dict(data) != "" or not back.shuttle_trips.has(HOST) or back.place_of(HOST) != Shuttle.DEIMOS:
		problems.append("A load before the end continues on Deimos: %s, %s" % [back.shuttle_trips, back.place_of(HOST)])
	data.erase("shuttle_trips")
	var old: GameStateScript = _state(0)
	if old.farm_from_dict(data) != "" or not old.shuttle_trips.is_empty():
		problems.append("An old save with no trips loads.")
	back.free()
	old.free()
	_done(gs)
	return "\n".join(problems)


func test_a_guest_on_the_farm_follows_the_hosts_deimos_trip_to_the_deimos_hub() -> String:
	var trip: Dictionary = { "moon": Shuttle.DEIMOS, "ends_at": 1.0e9 }
	var problems: Array[String] = []
	for path: String in [SceneSwitcher.FARM_SCENE, SceneSwitcher.DOME_SCENE]:
		if Shuttle.hub_to_join(trip, path) != SceneSwitcher.DEIMOS_SCENE:
			problems.append("A Deimos trip and the screen at %s: the Deimos hub." % path)
	if Shuttle.hub_to_join(trip, SceneSwitcher.DEIMOS_SCENE) != "":
		problems.append("Already at the Deimos hub stays there.")
	if Shuttle.hub_to_join({ "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }, SceneSwitcher.FARM_SCENE) != SceneSwitcher.PHOBOS_SCENE:
		problems.append("A Phobos trip still goes to Phobos.")
	return "\n".join(problems)


func test_the_hub_scene_builds_with_its_console_board_cache_and_pod_signs() -> String:
	var scene: PackedScene = load(SceneSwitcher.DEIMOS_SCENE) as PackedScene
	if scene == null:
		return "The Deimos hub scene does not load."
	var hub: DeimosHub = scene.instantiate() as DeimosHub
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	var problems: Array[String] = []
	for part: String in ["console_click", "board_click", "cache_click", "pod_click"]:
		if hub.get(part) == null:
			problems.append("The hub has no %s." % part)
	if hub.walker == null or hub.camera == null:
		problems.append("The hub has a walker and a camera.")
	if problems.is_empty():
		if hub._moon() != Shuttle.DEIMOS or hub._title() != Shuttle.text("deimos_hub_title"):
			problems.append("The hub is Deimos and says so.")
		for sign_click: Inspectable in [hub.cache_click, hub.pod_click]:
			if not Inspectable.inspect_text(sign_click.prop_id).contains("[later]"):
				problems.append("%s has an inspect line marked [later]." % sign_click.prop_id)
		var board: String = hub._board_text()
		if not board.contains(Shuttle.window_line(Shuttle.DEIMOS, GameClock.elapsed_days)):
			problems.append("The board says where the shuttle window stands: %s" % board)
		if hub.console_click.hint == "" or hub.board_click.hint == "":
			problems.append("The console and board say what they are on hover.")
	(Engine.get_main_loop() as SceneTree).root.remove_child(hub)
	hub.free()
	return "\n".join(problems)


func test_booking_just_inside_the_close_goes_and_at_the_close_is_refused() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	GameClock.elapsed_days = 59.9 * HOUR
	if not Shuttle.is_open(Shuttle.DEIMOS, GameClock.elapsed_days):
		problems.append("Deimos is still up at 59.9 h.")
	# A trip that would pass 02:00 is a different refusal; only the window matters here.
	var inside: String = Shuttle.trip_problem(Shuttle.DEIMOS, 20, true, 500, 1, GameClock.elapsed_days, true)
	if inside.contains(Shuttle.text("moon_down_text").substr(0, 8)) and Shuttle.is_open(Shuttle.DEIMOS, GameClock.elapsed_days):
		problems.append("Just inside the close is not refused for the window: '%s'" % inside)
	GameClock.elapsed_days = 60.0 * HOUR
	var at_close: String = gs.book_shuttle(Shuttle.DEIMOS, [gs.local_player_id])
	if Shuttle.is_open(Shuttle.DEIMOS, GameClock.elapsed_days) or at_close != Shuttle.text("moon_down_text") % Shuttle.window_line(Shuttle.DEIMOS, GameClock.elapsed_days) or gs.credits != 500:
		problems.append("At 60 h the window is shut and the booking refused for it: '%s', %d CR" % [at_close, gs.credits])
	_done(gs)
	return "
".join(problems)


func test_a_forged_report_of_the_wrong_moon_is_ignored() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	gs.shuttle_trips[HOST] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
	gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
	var forged: String = gs.report_place(Shuttle.DEIMOS, 0, HOST)
	if forged == "" or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("A Phobos traveller cannot report Deimos: '%s', %s" % [forged, gs.place_of(HOST)])
	gs.shuttle_trips[HOST] = { "moon": Shuttle.DEIMOS, "ends_at": 1.0e9 }
	var right: String = gs.report_place(Shuttle.DEIMOS, 0, HOST)
	if right != "" or gs.place_of(HOST) != Shuttle.DEIMOS:
		problems.append("A Deimos traveller may report Deimos: '%s', %s" % [right, gs.place_of(HOST)])
	var held: Dictionary = GameState.shuttle_trips.duplicate(true)
	GameState.shuttle_trips = { GameState.local_player_id: { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 } }
	var hub: DeimosHub = (load(SceneSwitcher.DEIMOS_SCENE) as PackedScene).instantiate() as DeimosHub
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	if hub._has_trip():
		problems.append("A Phobos trip is not a trip to Deimos.")
	(Engine.get_main_loop() as SceneTree).root.remove_child(hub)
	hub.free()
	GameState.shuttle_trips = held
	_done(gs)
	return "
".join(problems)


func test_a_saved_deimos_trip_opens_the_deimos_hub_on_restore() -> String:
	var me: String = GameState.local_player_id
	var held: Dictionary = bytes_to_var(var_to_bytes(SaveGame.snapshot()))
	var held_open: bool = SaveGame.farm_open
	var problems: Array[String] = []
	GameState.shuttle_trips = { me: { "moon": Shuttle.DEIMOS, "ends_at": GameClock.elapsed_days + 0.1 } }
	GameState.player_places[me] = [Shuttle.DEIMOS, 0]
	var data: Dictionary = bytes_to_var(var_to_bytes(SaveGame.snapshot()))
	var problem: String = SaveGame.restore(data)
	if problem != "" or SaveGame.open_scene != SceneSwitcher.DEIMOS_SCENE:
		problems.append("A save with the host on Deimos opens its hub: '%s', %s" % [problem, SaveGame.open_scene])
	SaveGame.restore(held)
	SaveGame.farm_open = held_open
	return "
".join(problems)


func test_the_board_is_painted_short_and_the_window_line_is_read_fresh() -> String:
	var hub: DeimosHub = (load(SceneSwitcher.DEIMOS_SCENE) as PackedScene).instantiate() as DeimosHub
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	var problems: Array[String] = []
	var held: float = GameClock.elapsed_days
	if hub._board_painted() != Shuttle.text("deimos_board_notice") or hub._board_painted().length() > 80:
		problems.append("The painted board is the short notice: %s" % hub._board_painted())
	GameClock.elapsed_days = 3.0 * HOUR
	var up: String = hub._board_text()
	GameClock.elapsed_days = 70.0 * HOUR
	var down: String = hub._board_text()
	GameClock.elapsed_days = held
	if up == down or not down.contains(Shuttle.window_line(Shuttle.DEIMOS, 70.0 * HOUR)):
		problems.append("The toast's window line follows the clock.")
	(Engine.get_main_loop() as SceneTree).root.remove_child(hub)
	hub.free()
	return "
".join(problems)
