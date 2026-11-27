extends "res://tests/coop_net.gd"
## The Phobos hub (docs/design/zones.md section 13, step 17, first half): booking the
## shuttle to Phobos (fare once, trip recorded, place phobos), every refusal charging
## nothing, Deimos still without a hub, the way home (console and the clock) being free,
## the farm's night never charging a traveller, the trip in the save and shown to a guest,
## a guest dropping, and the hub scene itself. Every node is freed; the clock and the
## walkers are put back.

const SyncScript: GDScript = preload("res://scripts/autoload/CoopSync.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const HOUR: float = 1.0 / 24.0

var _syncs: Array[Node] = []


func _state(credits: int = 500) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(515151)
	gs.local_player_id = HOST
	gs.credits = credits
	gs.shuttle_licensed = true
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 3.0 * HOUR  # 09:00 of day 1: Phobos' first window is open
	_park_at_terminal(gs)
	return gs


func _park_at_terminal(gs: GameStateScript) -> void:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(Shuttle.TERMINAL_AT.x, 0.5, Shuttle.TERMINAL_AT.y))


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	CoopWalkers.out.erase(HOST)
	CoopWalkers.out.erase(GUEST)
	gs.free()


func _lines(gs: GameStateScript, part: String) -> int:
	return gs.phone_log.filter(func(line: String) -> bool: return line.contains(part)).size()


func _commands(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


## The host is on Phobos with a trip that runs until `ends_at`.
func _away(gs: GameStateScript, ends_at: float, who: String = HOST) -> void:
	gs.shuttle_trips[who] = { "moon": Shuttle.PHOBOS, "ends_at": ends_at }
	gs.player_places[who] = [Shuttle.PHOBOS, 0]


# --- Booking ------------------------------------------------------------------------

func test_booking_phobos_takes_the_fare_once_records_the_trip_and_lands_on_the_moon() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	var heard: Array[int] = [0]
	gs.shuttle_trips_changed.connect(func() -> void: heard[0] += 1)
	var answer: String = gs.book_shuttle(Shuttle.PHOBOS, 1)
	if answer != "":
		problems.append("A licensed booking in the window is refused: '%s'" % answer)
	if gs.credits != 500 - Shuttle.fare():
		problems.append("The fare is taken once: %d CR left of 500, fare %d." % [gs.credits, Shuttle.fare()])
	var trip: Dictionary = gs.shuttle_trips.get(HOST, {})
	if trip.get("moon", "") != Shuttle.PHOBOS or not is_equal_approx(float(trip.get("ends_at", 0.0)), Shuttle.trip_end(GameClock.elapsed_days)):
		problems.append("The trip is not recorded with its end: %s" % [gs.shuttle_trips])
	if gs.place_of(HOST) != Shuttle.PHOBOS or not ZonePresence.is_place(gs.place_of(HOST)):
		problems.append("The traveller's place is not Phobos: %s" % gs.place_of(HOST))
	if heard[0] != 1 or _lines(gs, "Day trip to Phobos") != 1:
		problems.append("The trip is told once, to the screens and the phone: %d, %d lines." % [heard[0], _lines(gs, "Day trip to Phobos")])
	var again: String = gs.book_shuttle(Shuttle.PHOBOS, 1)
	if again == "" or gs.credits != 500 - Shuttle.fare():
		problems.append("A second booking from Phobos is refused and charges nothing: '%s', %d CR" % [again, gs.credits])
	_done(gs)
	return "\n".join(problems)


func test_booking_from_the_rover_leaves_the_rover_parked_on_the_farm() -> String:
	var gs: GameStateScript = _state(500)
	var before: Transform3D = gs.rover_transforms[gs.ROVER]
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, 1) != "":
		problems.append("Booking from the rover failed.")
	if gs.rover_transforms[gs.ROVER] != before or gs.rover_is_away(gs.ROVER):
		problems.append("The farm rover must stay where it is.")
	if CoopWalkers.is_out(HOST):
		problems.append("A traveller on Phobos is not among the farm's walkers.")
	_done(gs)
	return "\n".join(problems)


func test_every_refusal_charges_nothing_and_leaves_no_trip() -> String:
	var problems: Array[String] = []
	var cases: Dictionary = {}
	var closed: GameStateScript = _state(500)
	cases["outside a window"] = closed
	var unlicensed: GameStateScript = _state(500)
	unlicensed.shuttle_licensed = false
	cases["no license"] = unlicensed
	var poor: GameStateScript = _state(Shuttle.fare() - 1)
	cases["short wallet"] = poor
	var far: GameStateScript = _state(500)
	far.rover_transforms[far.ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 20.0))
	cases["far from the terminal"] = far
	for label: String in cases:
		var gs: GameStateScript = cases[label]
		var wallet: int = gs.credits
		GameClock.elapsed_days = 0.0 if label == "outside a window" else 3.0 * HOUR  # 06:00 is before the first window
		var answer: String = gs.book_shuttle(Shuttle.PHOBOS, 1)
		if answer == "" or gs.credits != wallet or not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("%s: '%s', %d CR, trips %s, place %s" % [label, answer, gs.credits, gs.shuttle_trips, gs.place_of(HOST)])
	var crowd: GameStateScript = _state(500)
	var two: String = crowd.book_shuttle(Shuttle.PHOBOS, 2)
	if two == "" or crowd.credits != 500 or not crowd.shuttle_trips.is_empty():
		problems.append("Two people: '%s', %d CR" % [two, crowd.credits])
	# Two present: a party of two gets the one-seat reason, not the crowd one.
	var held: Array[String] = CoopSession.players.duplicate()
	CoopSession.players.assign([HOST, GUEST])
	var party: String = crowd.book_shuttle(Shuttle.PHOBOS, 2)
	CoopSession.players.assign(held)
	if party != Shuttle.text("one_seat_text") or crowd.credits != 500 or not crowd.shuttle_trips.is_empty():
		problems.append("A party of two with both here: '%s', %d CR" % [party, crowd.credits])
	for gs: GameStateScript in cases.values():
		_done(gs)
	_done(crowd)
	return "\n".join(problems)


func test_fast_travel_never_offers_a_moon() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if not ZoneData.is_playable(&"phobos") or not ZoneData.is_playable(&"deimos"):
		problems.append("Both moons are playable.")
	gs.zones_unlocked.append("lava_tubes")
	for row: Dictionary in FastTravel.destinations(99, ["lava_tubes", "phobos", "deimos"]):
		if Shuttle.is_moon(str(row["id"])):
			problems.append("Fast travel offers a moon: %s" % [row])
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	if gs.fast_travel(Shuttle.PHOBOS, HOST) == "" or gs.place_of(HOST) != ZonePresence.DOME:
		problems.append("Fast travel to Phobos must be refused.")
	_done(gs)
	return "\n".join(problems)


# --- The way home --------------------------------------------------------------------

func test_the_console_brings_the_traveller_home_free_and_on_foot_at_the_pad() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, 1) != "":
		problems.append("Booking failed.")
	var wallet: int = gs.credits
	var heard: Array[int] = [0]
	gs.shuttle_trips_changed.connect(func() -> void: heard[0] += 1)
	var answer: Variant = commands.execute(HOST, &"shuttle_home", [])
	if answer != "" or gs.credits != wallet:
		problems.append("The way home is free: '%s', %d CR of %d" % [answer, gs.credits, wallet])
	if not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM or heard[0] != 1:
		problems.append("The trip is over and the screens are told: %s, %s, %d" % [gs.shuttle_trips, gs.place_of(HOST), heard[0]])
	if not CoopWalkers.is_out(HOST) or not Shuttle.terminal_near(CoopWalkers.spot(CoopWalkers.out[HOST]), 0.0):
		problems.append("The traveller stands on foot by the terminal.")
	if _lines(gs, "Phobos") < 2:
		problems.append("The way home is told on the phone.")
	var nobody: Variant = commands.execute(HOST, &"shuttle_home", [])
	if nobody == "" or gs.credits != wallet:
		problems.append("Home again from the farm is refused: '%s'" % nobody)
	commands.free()
	_done(gs)
	return "\n".join(problems)


func test_the_end_of_the_trip_brings_the_traveller_home_free() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, 1) != "":
		problems.append("Booking failed.")
	var wallet: int = gs.credits
	GameClock.elapsed_days += (Shuttle.trip_hours() - 0.5) * HOUR
	gs._end_due_trips()
	if gs.shuttle_trips.is_empty() or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("Half an hour before its end the trip goes on.")
	GameClock.elapsed_days += 0.6 * HOUR
	gs._end_due_trips()
	if not gs.shuttle_trips.is_empty() or gs.place_of(HOST) != ZonePresence.FARM or gs.credits != wallet:
		problems.append("At its end the trip is over, free: %s, %s, %d CR" % [gs.shuttle_trips, gs.place_of(HOST), gs.credits])
	if not CoopWalkers.is_out(HOST):
		problems.append("The traveller is on foot at the pad.")
	_done(gs)
	return "\n".join(problems)


func test_a_guest_is_booked_and_brought_home_by_the_host_and_stands_at_the_pad() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	gs.player_places[GUEST] = [ZonePresence.FARM, 0]
	CoopWalkers.stand(GUEST, Vector3(Shuttle.TERMINAL_AT.x, 0.0, Shuttle.TERMINAL_AT.y))
	var booked: Variant = commands.execute(GUEST, &"book_shuttle", [Shuttle.PHOBOS, 1])
	if booked != "" or gs.place_of(GUEST) != Shuttle.PHOBOS or not gs.shuttle_trips.has(GUEST) or gs.credits != 500 - Shuttle.fare():
		problems.append("A guest's booking: '%s', %s, %d CR" % [booked, gs.place_of(GUEST), gs.credits])
	if gs.place_of(HOST) != ZonePresence.FARM:
		problems.append("The host stays on the farm.")
	var other: Variant = commands.execute(GUEST, &"till", [Vector3i(0, 0, 0)])
	if other != false:
		problems.append("A guest on Phobos can do nothing on the farm.")
	var wallet: int = gs.credits
	var home: Variant = commands.execute(GUEST, &"shuttle_home", [])
	if home != "" or gs.place_of(GUEST) != ZonePresence.FARM or gs.shuttle_trips.has(GUEST) or gs.credits != wallet:
		problems.append("A guest's way home: '%s', %s, %d CR" % [home, gs.place_of(GUEST), gs.credits])
	if not CoopWalkers.is_out(GUEST):
		problems.append("The guest stands on foot at the pad.")
	commands.free()
	_done(gs)
	return "\n".join(problems)


# --- The farm's night ------------------------------------------------------------------

func test_midnight_and_two_never_charge_or_rescue_a_phobos_traveller() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	# A forced trip that straddles midnight, longer than a booking could make.
	_away(gs, TunnelRecall.at_hour(1, 3.5))
	gs.rover_in_tunnels = true  # the worst case: the farm thinks someone is below
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 0.5)
	gs._end_due_trips()
	gs._tick_recall()
	if gs.credits != 500 or _lines(gs, "Recall in") != 0 or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("Past 00:00 nothing is warned or charged and the trip goes on: %d CR, %d lines, %s" % [gs.credits, _lines(gs, "Recall in"), gs.place_of(HOST)])
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
	gs._end_due_trips()
	gs._tick_recall()
	if gs.credits != 500 or gs.crystal_ore != 0:
		problems.append("At 02:00 nothing is charged: %d CR, %d ore" % [gs.credits, gs.crystal_ore])
	if gs.place_of(HOST) != ZonePresence.FARM or not gs.shuttle_trips.is_empty():
		problems.append("A straggler at 02:00 is sent home by the shuttle: %s, %s" % [gs.place_of(HOST), gs.shuttle_trips])
	if _lines(gs, "rescue") != 0 or _lines(gs, "tunnels") != 0:
		problems.append("Nobody is rescued from the tunnels: %s" % [gs.phone_log])
	_done(gs)
	return "\n".join(problems)


func test_a_guest_on_phobos_is_not_warned_charged_or_carried_out() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	_away(gs, TunnelRecall.at_hour(1, 3.5), GUEST)
	gs.rover_in_tunnels = true
	var told: Array = []
	gs.recall_told = func(player_id: String, step: String) -> void: told.append([player_id, step])
	for hour: float in [0.5, 2.0]:
		GameClock.elapsed_days = TunnelRecall.at_hour(1, hour)
		gs._end_due_trips()
		gs._tick_recall()
	if gs.credits != 500 or not told.is_empty():
		problems.append("A moon's guest is neither warned nor charged: %d CR, %s" % [gs.credits, told])
	if gs.place_of(GUEST) != ZonePresence.FARM or gs.shuttle_trips.has(GUEST):
		problems.append("A guest left at 02:00 is sent home free.")
	_done(gs)
	return "\n".join(problems)


# --- Drops, saves, sync --------------------------------------------------------------------

func test_a_guest_who_drops_on_phobos_ends_the_trip_and_nothing_is_charged() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	_away(gs, GameClock.elapsed_days + 0.2, GUEST)
	gs.forget_place(GUEST)
	if gs.shuttle_trips.has(GUEST) or gs.player_places.has(GUEST) or gs.credits != 500:
		problems.append("A guest who dropped is not on a trip: %s, %d CR" % [gs.shuttle_trips, gs.credits])
	_away(gs, GameClock.elapsed_days + 0.2, GUEST)
	_away(gs, GameClock.elapsed_days + 0.2, HOST)
	gs.clear_other_places()
	if gs.shuttle_trips.has(GUEST) or not gs.shuttle_trips.has(HOST):
		problems.append("Clearing the others keeps only the host's trip: %s" % [gs.shuttle_trips])
	_done(gs)
	return "\n".join(problems)


func test_the_trip_is_saved_an_old_save_has_none_and_a_past_end_comes_home() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	if gs.book_shuttle(Shuttle.PHOBOS, 1) != "":
		problems.append("Booking failed.")
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if not data.has("shuttle_trips") or not (data["shuttle_trips"] as Dictionary).has(HOST):
		problems.append("The save did not hold the trip.")
	var back: GameStateScript = _state(0)
	if back.farm_from_dict(data) != "" or not back.shuttle_trips.has(HOST) or back.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("A load before the end continues on Phobos: %s, %s" % [back.shuttle_trips, back.place_of(HOST)])
	var late: GameStateScript = _state(0)
	GameClock.elapsed_days = float(data["shuttle_trips"][HOST]["ends_at"]) + 0.01
	if late.farm_from_dict(data) != "" or not late.shuttle_trips.is_empty() or late.place_of(HOST) == Shuttle.PHOBOS:
		problems.append("A load past the end comes home: %s, %s" % [late.shuttle_trips, late.place_of(HOST)])
	data.erase("shuttle_trips")
	var old: GameStateScript = _state(0)
	old.shuttle_trips[HOST] = { "moon": Shuttle.PHOBOS, "ends_at": 9.0 }
	if old.farm_from_dict(data) != "" or not old.shuttle_trips.is_empty():
		problems.append("An old save loads with no trip.")
	var junk: Dictionary = gs.farm_to_dict()
	junk["shuttle_trips"] = { HOST: { "moon": "mercury", "ends_at": 9.0 } }
	if gs.farm_dict_problem(junk) == "":
		problems.append("A trip to a moon with no hub was accepted.")
	junk["shuttle_trips"] = { HOST: { "moon": Shuttle.DEIMOS, "ends_at": 9.0 } }
	if gs.farm_dict_problem(junk) != "":
		problems.append("A trip to Deimos is a trip now: %s" % gs.farm_dict_problem(junk))
	junk["shuttle_trips"] = { HOST: "phobos" }
	if gs.farm_dict_problem(junk) == "":
		problems.append("A trip that is no dictionary was accepted.")
	back.free()
	late.free()
	old.free()
	_done(gs)
	return "\n".join(problems)


func test_a_guest_sees_the_trip_and_its_end() -> String:
	var elapsed: float = GameClock.elapsed_days
	var open: bool = SaveGame.farm_open
	GameClock.elapsed_days = 3.0 * HOUR
	var host: Node = _host()
	var host_sync: Node = _sync(host)
	var state: GameStateScript = host.commands.state
	state.set_world_seed(99)
	state.shuttle_licensed = true
	state.credits = 500
	_park_at_terminal(state)
	FarmCommands.guest = true
	var guest: Node = _session()
	var guest_sync: Node = _sync(guest)
	var ready: Array[bool] = [false]
	guest_sync.farm_ready.connect(func() -> void: ready[0] = true)
	guest.join(LOCAL, host.port())
	var problem: String = "The farm must reach the guest."
	if _until(func() -> bool: return ready[0]):
		problem = ""
		FarmCommands.guest = false
		var answer: String = state.book_shuttle(Shuttle.PHOBOS, 1)
		FarmCommands.guest = true
		var told: Array[int] = [0]
		guest.commands.state.shuttle_trips_changed.connect(func() -> void: told[0] += 1)
		host_sync.tick(1000000)
		host_sync.tick(1000000 + SyncScript.FARM_MS)
		if answer != "" or not _until(func() -> bool: return guest.commands.state.shuttle_trips.has(state.local_player_id)):
			problem = "A guest sees the host's trip: '%s'" % answer
		elif told[0] < 1:
			problem = "The guest's screens are told of the trip."
		else:
			FarmCommands.guest = false
			state.shuttle_home(state.local_player_id)
			FarmCommands.guest = true
			host_sync.tick(2000000 + SyncScript.FARM_MS)
			if not _until(func() -> bool: return guest.commands.state.shuttle_trips.is_empty()):
				problem = "A guest sees the trip end."
	FarmCommands.guest = false
	CoopWalkers.out.erase(HOST)
	problem = _finish(problem)
	for sync: Node in _syncs:
		sync.free()
	_syncs.clear()
	GameClock.elapsed_days = elapsed
	SaveGame.farm_open = open
	return problem


func _sync(session: Node) -> Node:
	var sync: Node = SyncScript.new()
	sync.start(session, session.commands.state)
	_syncs.append(sync)
	return sync


# --- The commands and the protocol ---------------------------------------------------------

func test_shuttle_home_is_a_host_command_allowed_on_foot_in_phobos_only() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	if not &"shuttle_home" in CommandsScript.ACTIONS or not &"shuttle_home" in CoopWalkers.ON_FOOT:
		problems.append("shuttle_home is a farm command allowed on foot.")
	if commands.problem(&"shuttle_home", []) != "" or commands.problem(&"shuttle_home", [1]) == "":
		problems.append("shuttle_home takes no arguments.")
	_away(gs, GameClock.elapsed_days + 0.2)
	var till: Variant = commands.execute(HOST, &"till", [Vector3i(1, 0, 1)])
	if till != false:
		problems.append("A traveller on Phobos cannot till the farm.")
	if CoopSession.PROTOCOL != 35:
		problems.append("The protocol is %d, not 35." % CoopSession.PROTOCOL)
	if not FarmSync.SHOWN_BY.has(&"shuttle_trips_changed"):
		problems.append("The trips are shown to a guest.")
	commands.free()
	_done(gs)
	return "\n".join(problems)


func test_a_report_cannot_put_a_player_on_a_moon_or_bring_them_home_early() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	var stranded: String = gs.report_place(Shuttle.PHOBOS, 0, GUEST)
	if stranded == "" or gs.player_places.has(GUEST):
		problems.append("A report of Phobos without a trip is refused: '%s'" % stranded)
	_away(gs, GameClock.elapsed_days + 0.2)
	var early: String = gs.report_place(ZonePresence.FARM, 0, HOST)
	if early == "" or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("A report of the farm from Phobos is refused: '%s'" % early)
	_done(gs)
	return "\n".join(problems)


# --- The scene ------------------------------------------------------------------------------

func test_the_hub_scene_loads_headless_with_its_console_board_sign_and_hatch() -> String:
	var scene: PackedScene = load(SceneSwitcher.PHOBOS_SCENE) as PackedScene
	if scene == null:
		return "The Phobos hub scene does not load."
	var hub: PhobosHub = scene.instantiate() as PhobosHub
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	var problems: Array[String] = []
	for part: String in ["console_click", "board_click", "hatch_click", "hook_click"]:
		if hub.get(part) == null:
			problems.append("The hub has no %s." % part)
	if hub.walker == null or hub.camera == null:
		problems.append("The hub has a walker and a camera.")
	if problems.is_empty():
		if hub.hook_click.hint == "" or Inspectable.inspect_text(hub.hook_click.prop_id) == hub.hook_click.hint:
			problems.append("The hook sign has a hover line and an inspect line.")
		if hub.hatch_click.hint == "" or hub.console_click.hint == "" or hub.board_click.hint == "":
			problems.append("The console, board and hatch say what they are on hover.")
		if not Shuttle.text("hub_hatch_text").contains("sealed") or not Shuttle.text("hub_board_log").contains("tunnel"):
			problems.append("The hatch is sealed and the board's log mentions the tunnels.")
		if hub._seen_trip:
			problems.append("No trip is seen on a fresh hub.")
	(Engine.get_main_loop() as SceneTree).root.remove_child(hub)
	hub.free()
	return "\n".join(problems)


# --- The client side: a screen follows the host's word on its trip -----------------------------

const TRIP_FAR: float = 1.0e9


func _hub() -> PhobosHub:
	var hub: PhobosHub = (load(SceneSwitcher.PHOBOS_SCENE) as PackedScene).instantiate() as PhobosHub
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	return hub


func _drop_hub(hub: PhobosHub) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(hub)
	hub.free()


## The scenes the hub was told to open, in order (the real swap is not made).
func _goes(hub: PhobosHub) -> Array[String]:
	var seen: Array[String] = []
	hub.change_scene = func(path: String) -> void: seen.append(path)
	return seen


func _my_trip(on: bool) -> void:
	if on:
		GameState.shuttle_trips[GameState.local_player_id] = { "moon": Shuttle.PHOBOS, "ends_at": TRIP_FAR }
	else:
		GameState.shuttle_trips.erase(GameState.local_player_id)


## The host answers a guest's asks with `answer`; `asked` collects what was asked.
func _host_says(answer: String, asked: Array) -> void:
	FarmCommands.guest = true
	FarmCommands.remote = func(action: StringName, arguments: Array) -> Variant:
		asked.append([action, arguments])
		return answer


func _guest_off() -> void:
	FarmCommands.guest = false
	FarmCommands.remote = Callable()


func test_the_hub_goes_home_when_its_trip_goes_and_not_before_or_twice() -> String:
	var held: Dictionary = GameState.shuttle_trips.duplicate(true)
	_my_trip(true)
	var hub: PhobosHub = _hub()
	var seen: Array[String] = _goes(hub)
	var problems: Array[String] = []
	if not hub._seen_trip:
		problems.append("A hub opened on a trip has seen it.")
	hub._on_trips_changed()
	hub._process(10.0)
	if not seen.is_empty():
		problems.append("The hub stays while the trip is on: %s" % [seen])
	_my_trip(false)
	hub._on_trips_changed()
	hub._on_trips_changed()
	hub._process(10.0)
	if seen != [SceneSwitcher.FARM_SCENE]:
		problems.append("The hub goes home once when the trip ends: %s" % [seen])
	_drop_hub(hub)
	GameState.shuttle_trips = held
	return "\n".join(problems)


func test_the_hub_gives_a_late_trip_its_grace_and_the_host_leaves_after_it() -> String:
	var held: Dictionary = GameState.shuttle_trips.duplicate(true)
	_my_trip(false)
	var hub: PhobosHub = _hub()
	var seen: Array[String] = _goes(hub)
	var problems: Array[String] = []
	hub._process(PhobosHub.GRACE_S - 1.0)
	if not seen.is_empty():
		problems.append("No trip yet, inside the grace: the hub waits.")
	_my_trip(true)
	hub._on_trips_changed()
	hub._process(PhobosHub.GRACE_S * 4.0)
	if not seen.is_empty():
		problems.append("A trip that came inside the grace keeps the hub open: %s" % [seen])
	_drop_hub(hub)
	_my_trip(false)
	var empty: PhobosHub = _hub()
	var left: Array[String] = _goes(empty)
	empty._process(PhobosHub.GRACE_S + 0.5)
	if left != [SceneSwitcher.FARM_SCENE]:
		problems.append("On the host a hub with no trip after the grace goes home: %s" % [left])
	_drop_hub(empty)
	GameState.shuttle_trips = held
	return "\n".join(problems)


## Review A, scenario 2: the guest's hub is open but the farm send that carries the trip
## is later than the grace. The hub asks the host, and stays.
func test_a_guests_hub_asks_the_host_after_the_grace_and_stays_while_the_host_has_them_away() -> String:
	var held: Dictionary = GameState.shuttle_trips.duplicate(true)
	_my_trip(false)
	var asked: Array = []
	_host_says("", asked)
	var hub: PhobosHub = _hub()
	var seen: Array[String] = _goes(hub)
	var problems: Array[String] = []
	hub._process(PhobosHub.GRACE_S + 0.5)
	if asked != [[&"report_place", [Shuttle.PHOBOS, 0]]]:
		problems.append("The guest's hub asks the host where it is: %s" % [asked])
	if not seen.is_empty():
		problems.append("The host has them away: the guest stays on the moon, not %s" % [seen])
	_my_trip(true)
	hub._on_trips_changed()
	hub._process(PhobosHub.GRACE_S * 4.0)
	if not seen.is_empty() or asked.size() != 1:
		problems.append("The late trip arrives: the hub stays and asks no more: %s, %d asks" % [seen, asked.size()])
	_drop_hub(hub)
	_guest_off()
	GameState.shuttle_trips = held
	return "\n".join(problems)


func test_a_guests_hub_goes_home_when_the_host_says_they_are_not_away_but_not_for_no_answer() -> String:
	var held: Dictionary = GameState.shuttle_trips.duplicate(true)
	_my_trip(false)
	var problems: Array[String] = []
	var asked: Array = []
	_host_says(Shuttle.text("not_away_text"), asked)
	var hub: PhobosHub = _hub()
	var seen: Array[String] = _goes(hub)
	hub._process(PhobosHub.GRACE_S + 0.5)
	if seen != [SceneSwitcher.FARM_SCENE]:
		problems.append("The host says not away: home, got %s" % [seen])
	_drop_hub(hub)
	_guest_off()  # no host to ask: "Not connected to the host."
	FarmCommands.guest = true
	var silent: PhobosHub = _hub()
	var stayed: Array[String] = _goes(silent)
	silent._process(PhobosHub.GRACE_S + 0.5)
	if not stayed.is_empty():
		problems.append("No answer from the host is not 'not away': the guest stays, got %s" % [stayed])
	_drop_hub(silent)
	_guest_off()
	GameState.shuttle_trips = held
	return "\n".join(problems)


## Review A, scenario 1: the booking answer never reached the guest, so its screen is
## still the farm. Its synced trip (the host's word) takes it to the hub.
func test_a_guest_still_on_the_farm_with_a_trip_goes_to_the_moons_hub() -> String:
	var trip: Dictionary = { "moon": Shuttle.PHOBOS, "ends_at": TRIP_FAR }
	var problems: Array[String] = []
	for path: String in [SceneSwitcher.FARM_SCENE, SceneSwitcher.DOME_SCENE]:
		if Shuttle.hub_to_join(trip, path) != SceneSwitcher.PHOBOS_SCENE:
			problems.append("A trip and the screen at %s: the hub." % path)
	for case: Array in [[trip, SceneSwitcher.PHOBOS_SCENE], [null, SceneSwitcher.FARM_SCENE], [trip, SceneSwitcher.TITLE_SCENE],
			[trip, SceneSwitcher.TUNNELS_SCENE], ["junk", SceneSwitcher.FARM_SCENE], [{ "moon": "mercury" }, SceneSwitcher.FARM_SCENE]]:
		if Shuttle.hub_to_join(case[0], str(case[1])) != "":
			problems.append("%s must stay where it is." % [case])
	if not GameState.shuttle_trips_changed.is_connected(SceneSwitcher.reconcile_trip) or SceneSwitcher.scene_swapped.get_connections().is_empty():
		problems.append("The reconciler runs on a trip change and on a scene swap.")
	if SceneSwitcher.reconcile_trip() != "":
		problems.append("Only a guest's screen is reconciled; the host's own trip is its own.")
	return "\n".join(problems)


# --- The booking panel -------------------------------------------------------------------------------

func test_a_booking_that_goes_through_opens_the_moons_hub_and_a_refusal_or_a_gone_panel_does_not() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var problems: Array[String] = []
	var asked: Array = []
	for case: Array in [["", [SceneSwitcher.PHOBOS_SCENE]], ["No seat.", []], ["gone", []]]:
		var ui := ShuttleUI.new()
		tree.root.add_child(ui)
		ui.open()
		var seen: Array[String] = []
		ui.change_scene = func(path: String) -> void: seen.append(path)
		FarmCommands.guest = true
		var answer: String = "" if case[0] == "gone" else str(case[0])
		var leaves: bool = case[0] == "gone"
		FarmCommands.remote = func(action: StringName, arguments: Array) -> Variant:
			asked.append([action, arguments])
			if leaves:
				tree.root.remove_child(ui)  # the panel left the tree during the ask
			return answer
		await ui._on_book(Shuttle.PHOBOS)
		if seen != case[1]:
			problems.append("Answer '%s': the screen goes to %s, not %s" % [case[0], case[1], seen])
		if ui.get_parent() != null:
			tree.root.remove_child(ui)
		ui.free()
	_guest_off()
	if ZoneData.hub_scene(&"phobos") != SceneSwitcher.PHOBOS_SCENE:
		problems.append("The booking uses the moon's hub scene from the zone data.")
	if asked.size() != 3 or asked[0] != [&"book_shuttle", [Shuttle.PHOBOS, ShuttleUI.PARTY]]:
		problems.append("The panel asks the host to book: %s" % [asked])
	return "\n".join(problems)


# --- Load and save --------------------------------------------------------------------------------------

func test_a_restored_farm_opens_the_hub_for_the_hosts_own_running_trip_only() -> String:
	var me: String = GameState.local_player_id
	var held: Dictionary = bytes_to_var(var_to_bytes(SaveGame.snapshot()))
	var held_open: bool = SaveGame.farm_open
	var problems: Array[String] = []
	GameState.shuttle_trips = { me: { "moon": Shuttle.PHOBOS, "ends_at": GameClock.elapsed_days + 0.1 } }
	GameState.player_places[me] = [Shuttle.PHOBOS, 0]
	var data: Dictionary = bytes_to_var(var_to_bytes(SaveGame.snapshot()))
	data["farm"]["shuttle_trips"][GUEST] = { "moon": Shuttle.PHOBOS, "ends_at": GameClock.elapsed_days + 0.1 }
	var problem: String = SaveGame.restore(data)
	if problem != "" or SaveGame.open_scene != SceneSwitcher.PHOBOS_SCENE:
		problems.append("A save with the host away opens the hub: '%s', %s" % [problem, SaveGame.open_scene])
	if not GameState.shuttle_trips.has(me) or GameState.shuttle_trips.has(GUEST):
		problems.append("The host's trip stays and a guest's is dropped: %s" % [GameState.shuttle_trips.keys()])
	data["farm"]["shuttle_trips"][me]["ends_at"] = float(data["clock"]["elapsed_days"]) - 0.01
	problem = SaveGame.restore(data)
	if problem != "" or SaveGame.open_scene != SceneSwitcher.FARM_SCENE or not GameState.shuttle_trips.is_empty():
		problems.append("A save past the trip's end opens the farm: '%s', %s" % [problem, SaveGame.open_scene])
	SaveGame.restore(held)
	SaveGame.farm_open = held_open
	return "\n".join(problems)


func test_a_load_drops_another_players_trip_and_keeps_the_hosts() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	_away(gs, GameClock.elapsed_days + 0.2, HOST)
	_away(gs, GameClock.elapsed_days + 0.2, GUEST)
	gs._settle_trips_on_load()
	if not gs.shuttle_trips.has(HOST) or gs.shuttle_trips.has(GUEST):
		problems.append("The host's trip goes on, the guest's is dropped: %s" % [gs.shuttle_trips.keys()])
	if gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("The host is still on the moon.")
	_done(gs)
	return "\n".join(problems)


# --- Returns, spots and the walker's silence --------------------------------------------------------------

## Review B, scenario 1: the guest's screen needs longer than SILENT_MS to learn of the end
## and load the farm; the host must not take it for gone.
func test_a_returned_traveller_is_not_put_back_in_the_rover_before_it_has_spoken() -> String:
	var gs: GameStateScript = _state(500)
	var held_players: Array[String] = CoopSession.players.duplicate()
	CoopSession.players = [HOST, GUEST]
	var problems: Array[String] = []
	_away(gs, GameClock.elapsed_days + 0.2, GUEST)
	var then: int = Time.get_ticks_msec()
	if gs.shuttle_home(GUEST) != "" or not CoopWalkers.is_out(GUEST):
		problems.append("The guest stands at the pad.")
	CoopWalkers.tick(then + CoopWalkers.SILENT_MS * 4)
	if not CoopWalkers.is_out(GUEST):
		problems.append("Twenty seconds on, with the guest still loading: it is still on foot.")
	var said: String = gs.report_place(ZonePresence.FARM, 0, GUEST)
	if said != "" or CoopWalkers._heard_at[GUEST] > Time.get_ticks_msec():
		problems.append("The guest's first farm report starts the silence clock: '%s'" % said)
	CoopWalkers.tick(Time.get_ticks_msec() + CoopWalkers.SILENT_MS + 1000)
	if CoopWalkers.is_out(GUEST):
		problems.append("A guest silent after its report is back in the rover.")
	CoopSession.players = held_players
	_done(gs)
	return "\n".join(problems)


## Review B, scenario 2, decided: with the field rover away there is nothing to stand
## beside, so the traveller is put on the farm with no walker.
func test_a_traveller_back_while_the_rover_is_away_is_at_the_farm_but_not_on_foot() -> String:
	var gs: GameStateScript = _state(500)
	var problems: Array[String] = []
	_away(gs, GameClock.elapsed_days + 0.2, GUEST)
	gs.rover_zone = "tunnels"
	gs.rover_lent = true
	if gs.shuttle_home(GUEST) != "":
		problems.append("The way home is open.")
	if gs.place_of(GUEST) != ZonePresence.FARM or gs.shuttle_trips.has(GUEST):
		problems.append("The guest is at the farm with no trip.")
	if CoopWalkers.is_out(GUEST):
		problems.append("No walker is stood beside a rover that is away.")
	gs.rover_lent = false
	gs.rover_zone = ""
	_done(gs)
	return "\n".join(problems)


func test_the_return_spot_is_the_pads_when_dry_and_never_in_deep_water() -> String:
	var gs: GameStateScript = _state(500)
	var spot: Vector3 = gs._pad_spot()
	var problems: Array[String] = []
	if Vector2(spot.x - Shuttle.RETURN_AT.x, spot.z - Shuttle.RETURN_AT.y).length() > 0.01 and not Terrain.is_deep(Shuttle.RETURN_AT):
		problems.append("A dry return spot is used as it is: %s" % spot)
	if Terrain.is_deep(Vector2(spot.x, spot.z)):
		problems.append("The walker is never stood in deep water.")
	_done(gs)
	return "\n".join(problems)


func test_a_report_of_a_moon_with_a_depth_is_refused_and_a_traveller_cannot_go_to_bed() -> String:
	var gs: GameStateScript = _state(500)
	var commands: Node = _commands(gs)
	var problems: Array[String] = []
	_away(gs, GameClock.elapsed_days + 0.2)
	var deep: String = gs.report_place(Shuttle.PHOBOS, 3, HOST)
	if deep == "" or gs.depth_of(HOST) != 0 or gs.place_of(HOST) != Shuttle.PHOBOS:
		problems.append("A moon has no depth: '%s', %d" % [deep, gs.depth_of(HOST)])
	var bed: Variant = commands.execute(HOST, &"go_to_bed", [])
	if bed != FarmCommands.MOON_REFUSAL:
		problems.append("A traveller on a moon cannot go to bed: '%s'" % bed)
	commands.free()
	_done(gs)
	return "\n".join(problems)
