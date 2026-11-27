extends "res://tests/coop_net.gd"
## The 02:00 rescue for guests (docs/design/zones.md sections 6.1 and 12.4): the host warns
## and carries out each guest it has below, once a day per player; the bill, the ore, the
## rover and the all-in-bed rule with several players; and the guest's own screen leaving
## the zone.

const BedsScript: GDScript = preload("res://scripts/autoload/CoopBeds.gd")
const ClockScript: GDScript = preload("res://scripts/autoload/GameClock.gd")
const ScenesScript: GDScript = preload("res://scripts/autoload/CoopScenes.gd")
const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")

const ZONE: String = "lava_tubes"
const HOME: Vector3 = Vector3(3.0, 0.0, 3.0)


## Stands in for CoopBeds where a test only needs to know who was put to bed.
class _NoBeds:
	extends RefCounted
	var put_to_bed: Array[String] = []

	func recall_to_bed(player_id: String) -> void:
		put_to_bed.append(player_id)

	func get_up(player_id: String) -> void:
		put_to_bed.erase(player_id)


## Beds that say what the farm looked like when each player was put in bed.
class _SpyBeds:
	extends RefCounted
	var farm: Object = null
	var seen: Array = []  # [player, credits, players still below] at each call

	func recall_to_bed(player_id: String) -> void:
		var below: int = 0
		for who: Variant in farm.player_places:
			below += 0 if farm.place_of(str(who)) in [ZonePresence.FARM, ZonePresence.DOME] else 1
		seen.append([player_id, farm.credits, below])

	func get_up(_player_id: String) -> void:
		pass


## Stands in for the session on a guest's screen.
class _Session:
	extends Node
	signal player_left(player_id: String)
	signal recalled(step: String)


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, HOME)
	gs.zones_unlocked.append(ZONE)
	return gs


## Runs `body` with the global clock at hour `hour` of day 1 and restores it.
func _at(hour: float, body: Callable) -> void:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, hour)
	body.call()
	GameClock.elapsed_days = held


## `driver` takes the farm rover in by the mouth at noon (ore baseline `ore`), and `others`
## are below too. Returns the log of what the host told whom: [player, step] each.
func _trip(gs: GameStateScript, driver: String, others: Array, ore: int) -> Array:
	var told: Array = []
	gs.recall_told = func(player_id: String, step: String) -> void: told.append([player_id, step])
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	gs.crystal_ore = ore
	_at(12.0, func() -> void: gs.move_rover(true, driver))
	gs.player_places[driver] = [ZONE, 0]
	for who: String in others:
		gs.player_places[who] = [ZONE, 0]
		gs._trip_players[who] = true
	return told


func _tick(gs: GameStateScript, hour: float) -> void:
	_at(hour, func() -> void: gs._tick_recall())


func _count(told: Array, player_id: String, step: String) -> int:
	return told.filter(func(entry: Array) -> bool: return entry[0] == player_id and entry[1] == step).size()


func _recall_lines(gs: GameStateScript) -> int:
	return gs.phone_log.filter(func(line: String) -> bool: return line.contains("Recall in")).size()


# --- The host's side -------------------------------------------------------------------

func test_a_guest_below_is_warned_once_on_their_own_phone() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", [], 0)
	gs.recall_in_tunnels = func() -> bool: return false  # the host is on the farm
	_tick(gs, 23.5)
	var early: int = told.size()
	_tick(gs, 0.5)
	_tick(gs, 0.6)
	var problems: Array[String] = []
	if early != 0:
		problems.append("Nothing is said before 00:00: %s" % [told])
	if _count(told, "player_2", TunnelRecall.WARN) != 1 or told.size() != 1:
		problems.append("One warning for the guest: %s" % [told])
	if _recall_lines(gs) != 0:
		problems.append("A guest's warning must not go in the shared phone log")
	gs.free()
	return "\n".join(problems)


func test_the_host_below_is_still_warned_in_the_shared_phone_log() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_1", [], 0)
	gs.recall_in_tunnels = func() -> bool: return true
	_tick(gs, 0.5)
	var problem: String = "" if _recall_lines(gs) == 1 and told.is_empty() else "The host's own warning is as before: %d lines, told %s" % [_recall_lines(gs), told]
	gs.free()
	return problem


func test_two_guests_are_each_warned_and_each_rescued_once() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", ["player_3"], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 0.5)
	_tick(gs, 2.0)
	_tick(gs, 2.1)
	var problems: Array[String] = []
	if _count(told, "player_2", TunnelRecall.WARN) != 1 or _count(told, "player_3", TunnelRecall.WARN) != 1:
		problems.append("Each guest is warned once: %s" % [told])
	if _count(told, "player_2", TunnelRecall.RESCUE) != 1 or _count(told, "player_3", TunnelRecall.RESCUE) != 1 or beds.put_to_bed != ["player_2", "player_3"]:
		problems.append("Each guest is carried out once: %s, bed %s" % [told, beds.put_to_bed])
	if gs.credits != 400:
		problems.append("Each guest pays the fee: %d CR left of 500" % gs.credits)
	if gs.place_of("player_2") != ZonePresence.FARM or gs.place_of("player_3") != ZonePresence.FARM:
		problems.append("Both are on the farm in the host's table")
	gs.free()
	return "\n".join(problems)


func test_the_host_and_a_guest_below_are_both_carried_out() -> String:
	var gs: GameStateScript = _state()
	_trip(gs, "player_1", ["player_2"], 0)
	gs.recall_in_tunnels = func() -> bool: return true
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 2.0)
	var problems: Array[String] = []
	if beds.put_to_bed != ["player_1", "player_2"]:
		problems.append("The host and the guest are both carried out: %s" % [beds.put_to_bed])
	if gs.credits != 400:
		problems.append("Each pays once: %d CR left of 500" % gs.credits)
	if gs._recall_rescued_day != 1 or int(gs._guest_rescued_day.get("player_2", 0)) != 1:
		problems.append("Each has their own mark: %d, %s" % [gs._recall_rescued_day, gs._guest_rescued_day])
	if gs.rover_in_tunnels:
		problems.append("Nobody is left: the rover is home")
	gs.free()
	return "\n".join(problems)


func test_the_host_on_the_farm_does_not_stop_a_guest_below_being_carried_out() -> String:
	var gs: GameStateScript = _state()
	_trip(gs, "player_2", [], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 2.0)
	var problems: Array[String] = []
	if beds.put_to_bed != ["player_2"] or gs.credits != 450:
		problems.append("The guest is carried out and pays: %s, %d CR" % [beds.put_to_bed, gs.credits])
	if gs.rover_in_tunnels or gs.rover_zone != "":
		problems.append("The last on the trip is out: the rover is home")
	gs.free()
	return "\n".join(problems)


func test_ore_is_taken_once_for_a_trip_however_many_are_rescued() -> String:
	var gs: GameStateScript = _state()
	_trip(gs, "player_2", ["player_3"], 0)
	gs.crystal_ore = 9  # nine gained in the tunnels
	gs.credits = 500
	var first: Dictionary = gs.rescue_from_tunnels("player_2")
	var after_first: int = gs.crystal_ore
	var second: Dictionary = gs.rescue_from_tunnels("player_3")
	var problems: Array[String] = []
	if first["ore"] != 3 or after_first != 6:
		problems.append("The first takes a third of 9: %s, %d left" % [first, after_first])
	if second["ore"] != 0 or gs.crystal_ore != 6:
		problems.append("The same ore is not taken again: %s, %d left" % [second, gs.crystal_ore])
	if gs.credits != 400:
		problems.append("Both pay the fee: %d" % gs.credits)
	gs.free()
	return "\n".join(problems)


func test_ore_gained_after_a_rescue_is_charged_to_the_next_one() -> String:
	var gs: GameStateScript = _state()
	_trip(gs, "player_2", ["player_3"], 0)
	gs.crystal_ore = 9
	gs.rescue_from_tunnels("player_2")  # 6 left, the baseline moves to 6
	gs.crystal_ore += 6  # the one still below mines 6 more
	var second: Dictionary = gs.rescue_from_tunnels("player_3")
	var problem: String = "" if second["ore"] == 2 and gs.crystal_ore == 10 else "A third of the 6 gained since: %s, %d" % [second, gs.crystal_ore]
	gs.free()
	return problem


func test_the_rover_comes_home_only_when_nobody_is_left_on_the_trip() -> String:
	var gs: GameStateScript = _state()
	_trip(gs, "player_2", ["player_3"], 0)
	var problems: Array[String] = []
	gs.rescue_from_tunnels("player_2")
	if not gs.rover_in_tunnels or gs._trip_players.has("player_2") or not gs._trip_players.has("player_3"):
		problems.append("A guest is still below: the rover stays (in tunnels %s, trip %s)" % [gs.rover_in_tunnels, gs._trip_players])
	gs.rescue_from_tunnels("player_3")
	if gs.rover_in_tunnels or not gs._trip_players.is_empty():
		problems.append("The last one carried out brings it home")
	gs.free()
	return "\n".join(problems)


func test_a_guest_in_the_dome_is_left_alone_and_keeps_the_trip_open() -> String:
	var gs: GameStateScript = _state()
	_trip(gs, "player_2", ["player_3"], 0)
	gs.player_places["player_3"] = [ZonePresence.DOME, 0]
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 2.0)
	var problems: Array[String] = []
	if beds.put_to_bed != ["player_2"] or gs.credits != 450:
		problems.append("Only the guest below is carried out: %s, %d CR" % [beds.put_to_bed, gs.credits])
	if not gs.rover_in_tunnels:
		problems.append("The guest in the dome is still on the trip: the rover stays")
	gs.free()
	return "\n".join(problems)


func test_a_guest_who_leaves_the_zone_before_two_is_not_charged() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", [], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 0.5)
	gs.player_places["player_2"] = [ZonePresence.FARM, 0]  # walked out
	gs._trip_players.erase("player_2")
	_tick(gs, 2.0)
	var problems: Array[String] = []
	if gs.credits != 500 or not beds.put_to_bed.is_empty() or told != [["player_2", TunnelRecall.WARN]]:
		problems.append("Not charged, not carried, nothing more said: %d CR, %s, %s" % [gs.credits, beds.put_to_bed, told])
	gs.free()
	return "\n".join(problems)


func test_a_guest_who_leaves_in_the_moment_before_the_carry_out_is_not_charged() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", [], 0)
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	gs.player_places["player_2"] = [ZonePresence.DOME, 0]  # between the hour and the deferred carry-out
	var one: Array[String] = ["player_2"]
	gs._carry_out(one)
	var problem: String = "" if gs.credits == 500 and beds.put_to_bed.is_empty() and told.is_empty() else "The carry-out looks again: %d CR, %s, %s" % [gs.credits, beds.put_to_bed, told]
	gs.free()
	return problem


func test_a_repeated_rescue_does_not_charge_twice() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", ["player_3"], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 2.0)
	_tick(gs, 2.0)
	var dupes: Array[String] = ["player_2", "player_3"]
	gs._carry_out(dupes)  # duplicates that were already queued
	var problems: Array[String] = []
	if gs.credits != 400 or beds.put_to_bed != ["player_2", "player_3"]:
		problems.append("Two guests, each once: %d CR, bed %s" % [gs.credits, beds.put_to_bed])
	if _count(told, "player_2", TunnelRecall.RESCUE) != 1 or _count(told, "player_3", TunnelRecall.RESCUE) != 1:
		problems.append("Each told once: %s" % [told])
	gs.free()
	return "\n".join(problems)


func test_a_guest_the_host_hears_of_late_is_warned_then_rescued_once() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_1", [], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	gs.player_places["player_1"] = [ZonePresence.FARM, 0]  # the host is home
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	_tick(gs, 0.2)  # the guest is still fading in: the host has heard nothing
	var quiet: bool = told.is_empty()
	gs.player_places["player_2"] = [ZONE, 0]  # the report arrives
	_tick(gs, 0.3)
	var warned: int = _count(told, "player_2", TunnelRecall.WARN)
	_tick(gs, 2.0)
	_tick(gs, 2.0)
	var rescued: int = _count(told, "player_2", TunnelRecall.RESCUE)
	gs.free()
	if not quiet or warned != 1 or rescued != 1 or beds.put_to_bed != ["player_2"]:
		return "Late arrival: quiet %s, warned %d, rescued %d, bed %s" % [quiet, warned, rescued, beds.put_to_bed]
	return ""


func test_a_guest_who_drops_is_not_charged_and_the_rover_comes_home() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", [], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.credits = 500
	_tick(gs, 0.5)
	gs.forget_place("player_2")
	_tick(gs, 2.0)
	var problems: Array[String] = []
	if gs.credits != 500 or not beds.put_to_bed.is_empty() or told != [["player_2", TunnelRecall.WARN]]:
		problems.append("A guest who dropped is not charged or carried: %d CR, %s, %s" % [gs.credits, beds.put_to_bed, told])
	if gs.rover_in_tunnels or gs.rover_zone != "":
		problems.append("The last one on the trip dropped: the rover is home")
	gs.free()
	return "\n".join(problems)


func test_a_guests_own_copy_tells_and_carries_nobody() -> String:
	var gs: GameStateScript = _state()
	var told: Array = _trip(gs, "player_2", [], 0)
	gs.recall_in_tunnels = func() -> bool: return false
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	_tick(gs, 0.5)
	_tick(gs, 2.0)
	FarmCommands.guest = held
	var problem: String = "" if told.is_empty() and beds.put_to_bed.is_empty() else "A guest's copy tells and carries nobody: %s, %s" % [told, beds.put_to_bed]
	gs.free()
	return problem


# --- The all-in-bed day -------------------------------------------------------------------

## A host with a guest in, real beds, and a farm with the guest below.
func _beds_farm(host_below: bool, body: Callable) -> String:
	var host: Node = _host()
	_guest(host)
	var clock: Node = ClockScript.new()
	var beds: Node = BedsScript.new()
	beds.start(host, clock)
	clock.elapsed_days = 0.5
	var gs: GameStateScript = _state()
	gs.recall_beds = beds
	gs.recall_in_tunnels = func() -> bool: return host_below
	gs.credits = 500
	_trip(gs, "player_1" if host_below else "player_2", ["player_2"] if host_below else [], 0)
	var out: Variant = body.call(gs, beds, clock)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	beds.free()
	clock.free()
	return _finish(problem)


func test_the_host_asleep_and_the_guest_rescued_end_the_day() -> String:
	return _beds_farm(false, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		if beds.go_to_bed("player_1") != "" or clock.elapsed_days != 0.5:
			return "The host in bed with a guest below: the day waits"
		_tick(gs, 2.0)
		var problems: Array[String] = []
		if clock.get_day_index() != 2 or clock.elapsed_days != 1.0:
			problems.append("The rescued guest was the last up: the day ends (%s)" % clock.format_now())
		if gs.credits != 450:
			problems.append("The guest was charged once: %d" % gs.credits)
		return "\n".join(problems))


func test_a_rescued_guest_alone_in_bed_does_not_end_the_day_while_the_host_is_up() -> String:
	return _beds_farm(false, func(gs: GameStateScript, beds: Node, clock: Node) -> String:
		_tick(gs, 2.0)
		var problems: Array[String] = []
		if beds.in_bed != ["player_2"] or beds.still_up() != ["player_1"]:
			problems.append("The guest is in bed, the host is up: %s, %s" % [beds.in_bed, beds.still_up()])
		if clock.get_day_index() != 1 or clock.elapsed_days != 0.5:
			problems.append("The day waits for the host")
		return "\n".join(problems))


func test_the_host_and_the_guest_both_carried_out_end_the_day() -> String:
	return _beds_farm(true, func(gs: GameStateScript, _beds: Node, clock: Node) -> String:
		_tick(gs, 2.0)
		var problems: Array[String] = []
		if clock.get_day_index() != 2 or clock.elapsed_days != 1.0:
			problems.append("Both in bed ends the day: %s" % clock.format_now())
		if gs.credits != 400 or gs.rover_in_tunnels:
			problems.append("Both charged, rover home: %d CR, in tunnels %s" % [gs.credits, gs.rover_in_tunnels])
		return "\n".join(problems))


# --- The wire and the guest's own screen -----------------------------------------------------

func test_the_host_tells_one_guest_and_the_guest_hears_it() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var heard: Array[String] = []
	guest.recalled.connect(func(step: String) -> void: heard.append(step))
	var sent: bool = host.tell_recall("player_2", TunnelRecall.WARN)
	var sent_rescue: bool = host.tell_recall("player_2", TunnelRecall.RESCUE)
	_until(func() -> bool: return heard.size() >= 2)
	var problems: Array[String] = []
	if not sent or not sent_rescue or heard != [TunnelRecall.WARN, TunnelRecall.RESCUE]:
		problems.append("The guest hears warn then rescue: %s (sent %s %s)" % [heard, sent, sent_rescue])
	if host.tell_recall("player_2", "dance") or host.tell_recall("nobody", TunnelRecall.WARN) or host.tell_recall("", TunnelRecall.WARN):
		problems.append("Only a known step to a known guest is sent")
	if guest.tell_recall("player_1", TunnelRecall.WARN):
		problems.append("A guest never tells")
	return _finish("\n".join(problems))


func test_a_guest_saying_a_recall_to_the_host_is_dropped() -> String:
	var host: Node = _host()
	var stranger: ENetMultiplayerPeer = _stranger(host, true)
	var count: int = host.players.size()
	stranger.put_packet(var_to_bytes([SessionScript.RECALL, TunnelRecall.RESCUE]))
	var dropped: bool = _until(func() -> bool: return host.players.size() < count)
	return _finish("" if dropped else "A recall is the host's to say: a guest saying it is dropped")


func test_the_guest_screen_leaves_the_zone_only_if_it_is_in_one() -> String:
	var session: _Session = _Session.new()
	var gs: GameStateScript = _state()
	var scenes: Node = ScenesScript.new()
	scenes.start(session, gs)
	var here: Array[String] = [SceneSwitcher.TUNNELS_SCENE]
	scenes.scene_at = func() -> String: return here[0]
	var opened: Array[int] = []
	scenes.go_to_farm = func() -> void: opened.append(1)
	var phone: Array[String] = []
	gs.phone_message.connect(func(text: String) -> void: phone.append(text))
	session.recalled.emit(TunnelRecall.WARN)
	session.recalled.emit(TunnelRecall.RESCUE)
	var in_zone: bool = phone == [TunnelRecall.text("warn_text")] and opened.size() == 1
	for path: String in [SceneSwitcher.FARM_SCENE, SceneSwitcher.DOME_SCENE, ""]:
		here[0] = path
		session.recalled.emit(TunnelRecall.WARN)
		session.recalled.emit(TunnelRecall.RESCUE)
	var elsewhere: bool = phone.size() == 1 and opened.size() == 1
	scenes.free()
	session.free()
	gs.free()
	if not in_zone or not elsewhere:
		return "In the tunnels: warned and sent home (%s); on the farm, in the dome, at a menu: left alone (%s, %d lines, %d moves)" % [in_zone, elsewhere, phone.size(), opened.size()]
	return ""


func test_the_zone_scenes_are_told_from_the_rest() -> String:
	var problems: Array[String] = []
	if not ZonePresence.in_zone(SceneSwitcher.TUNNELS_SCENE):
		problems.append("The tunnels are a zone")
	for path: String in [SceneSwitcher.FARM_SCENE, SceneSwitcher.DOME_SCENE, SceneSwitcher.TITLE_SCENE, ""]:
		if ZonePresence.in_zone(path):
			problems.append("'%s' is not a zone" % path)
	return "\n".join(problems)


# --- Review round 1 -------------------------------------------------------------------------

func test_the_last_one_off_the_trip_reporting_the_farm_brings_the_rover_home() -> String:
	var gs: GameStateScript = _state()
	var me: String = gs.local_player_id
	_trip(gs, me, [], 0)
	gs.player_places[me] = [ZonePresence.DOME, 0]  # in the dome, still on the trip
	var reason: String = gs.report_place(ZonePresence.FARM, 0, me)
	var problems: Array[String] = []
	if reason != "":
		problems.append("The report is taken: %s" % reason)
	if gs.rover_in_tunnels or gs.rover_lent:
		problems.append("The last one off the trip is on the farm: the rover is home")
	gs.free()
	return "\n".join(problems)


func test_going_below_gets_a_player_out_of_bed() -> String:
	var gs: GameStateScript = _state()
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	beds.put_to_bed.append(gs.local_player_id)
	gs.report_place(ZONE, 0, gs.local_player_id)
	var up: bool = beds.put_to_bed.is_empty()
	gs.free()
	return "" if up else "A player who goes below is not in bed any more"


func test_every_bill_is_paid_before_anyone_is_put_in_bed() -> String:
	var gs: GameStateScript = _state()
	var spy: _SpyBeds = _SpyBeds.new()
	spy.farm = gs
	gs.recall_beds = spy
	gs.recall_in_tunnels = func() -> bool: return false
	gs.credits = 500
	_trip(gs, "player_2", ["player_3"], 0)
	_tick(gs, 2.0)
	var problems: Array[String] = []
	if spy.seen.size() != 2:
		problems.append("Both are put in bed: %s" % [spy.seen])
	elif spy.seen[0][1] != 400 or spy.seen[0][2] != 0:
		problems.append("At the first bed both are billed and out: %s" % [spy.seen[0]])
	gs.free()
	return "\n".join(problems)


func test_a_late_report_below_after_the_hour_is_carried_out_at_once() -> String:
	var gs: GameStateScript = _state()
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.recall_in_tunnels = func() -> bool: return true
	gs.credits = 500
	var me: String = gs.local_player_id
	_trip(gs, me, [], 0)
	gs.player_places[me] = [ZonePresence.DOME, 0]
	_at(2.0, func() -> void: gs.report_place(ZONE, 0, me))
	var problems: Array[String] = []
	if gs.credits != 450 or beds.put_to_bed != [me]:
		problems.append("Arriving after 02:00 is carried out now, not at a tick that may never come: %d CR, %s" % [gs.credits, beds.put_to_bed])
	gs.free()
	return "\n".join(problems)


func test_a_carry_out_checks_again_for_the_host_and_the_rover() -> String:
	var gs: GameStateScript = _state()
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.recall_in_tunnels = func() -> bool: return true
	gs.credits = 500
	var host_only: Array[String] = [gs.local_player_id]
	_at(2.0, func() -> void: gs._carry_out(host_only))  # the rover is home
	var problems: Array[String] = []
	if gs.credits != 500 or not beds.put_to_bed.is_empty() or gs._recall_rescued_day != 0:
		problems.append("Nothing is below: no bill, no bed, no used-up day (%d, %s, %d)" % [gs.credits, beds.put_to_bed, gs._recall_rescued_day])
	_trip(gs, gs.local_player_id, [], 0)
	gs.recall_in_tunnels = func() -> bool: return false  # the host left the scene
	_at(2.0, func() -> void: gs._carry_out(host_only))
	if gs.credits != 500 or not beds.put_to_bed.is_empty():
		problems.append("A host who is not below is not carried out")
	gs.free()
	return "\n".join(problems)


func test_a_guest_who_left_in_the_moment_keeps_the_day_unused() -> String:
	var gs: GameStateScript = _state()
	gs.recall_beds = _NoBeds.new()
	_trip(gs, "player_2", [], 0)
	gs.player_places["player_2"] = [ZonePresence.DOME, 0]
	var guest: Array[String] = ["player_2"]
	_at(2.0, func() -> void: gs._carry_out(guest))
	var burned: bool = gs._guest_rescued_day.has("player_2") or gs._guest_warned_day.has("player_2")
	gs.free()
	return "A rescue that did not run uses up no day" if burned else ""


func test_the_way_out_forgets_the_trip_s_ore_baseline() -> String:
	var gs: GameStateScript = _state()
	var me: String = gs.local_player_id
	_trip(gs, me, [], 7)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	var reason: String = gs.move_rover(false, me)
	var problems: Array[String] = []
	if reason != "":
		problems.append("The way out is open: %s" % reason)
	if gs._ore_at_entry != -1:
		problems.append("No trip, no baseline: %d" % gs._ore_at_entry)
	gs.free()
	return "\n".join(problems)


func test_a_stale_tunnel_command_does_not_wake_a_carried_out_player() -> String:
	CoopBeds.in_bed.assign(["player_3"])
	var host: Node = _host()
	host.commands.execute("player_3", &"enter_vent", ["vent", 0])
	var stale: Array[String] = CoopBeds.in_bed.duplicate()
	host.commands.execute("player_3", &"accept_job", [99])
	var farm_job: Array[String] = CoopBeds.in_bed.duplicate()
	CoopBeds.in_bed.clear()
	return _finish("" if stale == ["player_3"] and farm_job.is_empty() else "Got %s then %s" % [stale, farm_job])


func test_the_rescue_is_told_once_after_the_farm_has_changed() -> String:
	var gs: GameStateScript = _state()
	gs.recall_beds = _NoBeds.new()
	gs.recall_in_tunnels = func() -> bool: return false
	var told: Array = _trip(gs, "player_2", [], 0)
	_tick(gs, 2.0)
	var ok: bool = _count(told, "player_2", TunnelRecall.RESCUE) == 1 and gs.place_of("player_2") == ZonePresence.FARM
	gs.free()
	return "" if ok else "The guest is told once, with the farm already changed"


func test_a_rescued_guest_cannot_go_on_driving_the_rover_below() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var gs: GameStateScript = _state()
	var rovers: Node = RoversScript.new()
	rovers.start(host, gs)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_START.origin)
	gs.rover_zone = ZONE
	gs.rover_in_tunnels = true
	var pose: Array = [gs.TUNNEL_START.origin.x, gs.TUNNEL_START.origin.y, gs.TUNNEL_START.origin.z, 0.0, 0.0, true, gs.rover_epoch]
	gs.player_places["player_2"] = [ZonePresence.FARM, 0]  # carried out
	rovers._on_driven("player_2", gs.TUNNEL_ROVER, pose, 1000)
	var problems: Array[String] = []
	if rovers.driver(gs.TUNNEL_ROVER) != "":
		problems.append("A drive from one who is on the farm is not taken")
	gs.player_places["player_2"] = [ZONE, 0]
	rovers._on_driven("player_2", gs.TUNNEL_ROVER, pose, 1100)
	if rovers.driver(gs.TUNNEL_ROVER) != "player_2":
		problems.append("A drive from one in the zone is")
	rovers.free()
	gs.free()
	return _finish("\n".join(problems))


func test_a_rescue_ends_the_rescued_player_s_drive_lease() -> String:
	var gs: GameStateScript = _state()
	gs.recall_beds = _NoBeds.new()
	_trip(gs, "player_2", [], 0)
	CoopRovers._drivers[gs.TUNNEL_ROVER] = ["player_2", Time.get_ticks_msec() + 100000]
	gs.rescue_from_tunnels("player_2")
	var held: bool = CoopRovers.driver(gs.TUNNEL_ROVER) == "player_2"
	CoopRovers._drivers.erase(gs.TUNNEL_ROVER)
	gs.free()
	return "The rescue ends the lease" if held else ""


func test_loading_a_farm_forgets_who_was_on_the_trip() -> String:
	var gs: GameStateScript = _state()
	gs._trip_players["player_2"] = true
	var reason: String = gs.farm_from_dict(gs.farm_to_dict())
	var left: bool = gs._trip_players.is_empty()
	gs.free()
	return "" if reason == "" and left else "A loaded farm has no trip in it (%s)" % reason


func test_leaving_the_zone_while_a_friend_is_still_on_the_way_keeps_the_field_rover() -> String:
	var gs: GameStateScript = _state()
	var me: String = gs.local_player_id
	gs.rover_zone = ZONE
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	gs.player_places[me] = [ZONE, 0]
	gs._trip_players["player_2"] = true  # up in the dome, on the same trip
	var reason: String = gs.leave_zone(me)
	var kept: bool = gs.rover_zone == ZONE
	gs.free()
	return "" if reason == "" and kept else "The rover stays for one still on the trip (%s)" % reason


func test_a_warning_waits_for_a_swap_in_progress() -> String:
	var session: _Session = _Session.new()
	var gs: GameStateScript = _state()
	var scenes: Node = ScenesScript.new()
	scenes.start(session, gs)
	var here: Array[String] = [SceneSwitcher.FARM_SCENE]
	scenes.scene_at = func() -> String: return here[0]
	var phone: Array[String] = []
	gs.phone_message.connect(func(text: String) -> void: phone.append(text))
	SceneSwitcher._busy = true
	session.recalled.emit(TunnelRecall.WARN)  # the swap is on its way into the zone
	var early: int = phone.size()
	here[0] = SceneSwitcher.TUNNELS_SCENE
	SceneSwitcher._busy = false
	SceneSwitcher.scene_swapped.emit(SceneSwitcher.TUNNELS_SCENE)
	var shown: bool = phone == [TunnelRecall.text("warn_text")]
	scenes.free()
	session.free()
	gs.free()
	return "" if early == 0 and shown else "The warning is shown on the screen that arrives (%d early, %s)" % [early, phone]


func test_a_recall_is_taken_only_from_an_accepted_host_and_only_a_known_step() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var lone: Node = _session()
	var problems: Array[String] = []
	if lone._guest_read(var_to_bytes([SessionScript.RECALL, TunnelRecall.WARN])):
		problems.append("No welcome yet: no recall")
	if guest._guest_read(var_to_bytes([SessionScript.RECALL, "dance"])) or guest._guest_read(var_to_bytes([SessionScript.RECALL, 1])):
		problems.append("An unknown step, or one that is no text, is a bad host")
	if not guest._guest_read(var_to_bytes([SessionScript.RECALL, TunnelRecall.WARN])):
		problems.append("A known step from the host is taken")
	return _finish("\n".join(problems))
