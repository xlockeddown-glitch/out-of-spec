extends "res://tests/coop_net.gd"
## Fast travel (docs/design/zones.md section 8.1, build step 7): the dome console
## sends a player to a zone's field rover and the farm's rover stays home; the way
## home is the dome; a rover lent through the real entrance still works as it did.

const RoversScript: GDScript = preload("res://scripts/autoload/CoopRovers.gd")
const SyncScript: GDScript = preload("res://scripts/autoload/FarmSync.gd")

const ZONE: String = "lava_tubes"
const HOME: Vector3 = Vector3(3.0, 0.0, 3.0)


## Stands in for CoopBeds where a test only needs to know who was put to bed.
class _NoBeds:
	extends RefCounted
	var put_to_bed: Array[String] = []

	func recall_to_bed(player_id: String) -> void:
		put_to_bed.append(player_id)


## A rover controller that says where its rover is, as the real one does.
class _LiveRover:
	extends Node
	var rover_id: String = "rover_tunnel"
	var at: Vector3 = Vector3.ZERO
	var asked: int = 0

	func live_transform() -> Variant:
		asked += 1
		return Transform3D(Basis.IDENTITY, at)


## Rovers where a guest is on the farm.
class _TogetherRovers:
	extends "res://scripts/autoload/CoopRovers.gd"

	func together() -> bool:
		return true


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, HOME)
	gs.zones_unlocked.append(ZONE)  # it has been there by the mouth
	return gs


## In the dome, the console's place.
func _in_dome(gs: GameStateScript, player_id: String = "") -> String:
	var who: String = player_id if player_id != "" else gs.local_player_id
	gs.player_places[who] = [ZonePresence.DOME, 0]
	return who


## Runs `body` with the global clock at hour `hour` of day 1 and restores it.
func _at(hour: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, hour)
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else ""


func _home_unmoved(gs: GameStateScript) -> bool:
	return gs.parked_rover_transform(gs.ROVER).origin == HOME


# --- The save -------------------------------------------------------------------

func test_the_lent_flag_survives_a_save_and_old_saves_read_it_from_the_zone() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZONE
	var field: Dictionary = gs.farm_to_dict()
	gs.rover_in_tunnels = true
	var lent: Dictionary = gs.farm_to_dict()
	if field.get("rover_lent") != false or lent.get("rover_lent") != true:
		gs.free()
		return "The save must say rover_lent: field %s, lent %s" % [field.get("rover_lent"), lent.get("rover_lent")]
	var old: Dictionary = lent.duplicate(true)
	old.erase("rover_lent")
	var old_home: Dictionary = field.duplicate(true)
	old_home.erase("rover_lent")
	old_home["rover_zone"] = ""
	var back: GameStateScript = _state()
	var problems: Array[String] = []
	if back.farm_from_dict(bytes_to_var(var_to_bytes(field))) != "" or back.rover_lent or back.rover_zone != ZONE:
		problems.append("A field rover loaded as lent or lost: lent %s zone %s" % [back.rover_lent, back.rover_zone])
	if back.farm_from_dict(bytes_to_var(var_to_bytes(old))) != "" or not back.rover_lent:
		problems.append("A save from before fast travel with the rover in a zone was the farm's, lent")
	if back.farm_from_dict(bytes_to_var(var_to_bytes(old_home))) != "" or back.rover_lent:
		problems.append("A save from before fast travel with the rover home is not lent")
	var bad: Dictionary = old_home.duplicate(true)
	bad["rover_lent"] = true
	if back.farm_dict_problem(bad) == "":
		problems.append("A lent rover on the farm must be refused")
	bad["rover_lent"] = 1
	if back.farm_dict_problem(bad) == "":
		problems.append("A lent flag that is not a yes or no must be refused")
	back.free()
	gs.free()
	return "\n".join(problems)


func test_the_protocol_and_the_commands_and_the_sync_know_fast_travel() -> String:
	var problems: Array[String] = []
	if SessionScript.PROTOCOL != 25:
		problems.append("Fast travel changes what is sent: protocol 25, got %d" % SessionScript.PROTOCOL)
	for action: StringName in [&"fast_travel", &"leave_zone"]:
		if not action in FarmCommands.ACTIONS:
			problems.append("%s is not a farm command" % action)
	if not "rover_lent" in SyncScript.SHOWN_BY[&"rover_place_changed"]:
		problems.append("A guest must be shown rover_lent with the rover's place")
	return "\n".join(problems)


# --- Going --------------------------------------------------------------------------

func test_the_first_traveller_starts_a_field_rover_and_the_farm_rover_stays_home() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.crystal_ore = 5
	var epoch: int = gs.rover_epoch
	var problem: String = ""
	_at(12.0, func() -> String:
		problem = gs.fast_travel(ZONE, me)
		return "")
	var problems: Array[String] = []
	if problem != "":
		problems.append("Refused: " + problem)
	if gs.rover_zone != ZONE or gs.rover_lent or gs.rover_depth != 0:
		problems.append("Field rover not live at the hub: zone %s lent %s depth %d" % [gs.rover_zone, gs.rover_lent, gs.rover_depth])
	if gs.parked_rover_transform(gs.TUNNEL_ROVER).origin != gs.TUNNEL_START.origin:
		problems.append("The field rover starts at the zone's start")
	if not _home_unmoved(gs) or gs.rover_is_away(gs.ROVER) or gs.rover_is_away(gs.TUNNEL_ROVER):
		problems.append("The farm rover must stay home and neither rover is away")
	if gs.rover_epoch != epoch + 1:
		problems.append("A new field rover is a new epoch (epoch %d)" % gs.rover_epoch)
	if gs.place_of(me) != ZONE:
		problems.append("The player is in the zone")
	gs.free()
	return "\n".join(problems)


func test_going_is_refused_where_it_must_be() -> String:
	var gs: GameStateScript = _state()
	var me: String = gs.local_player_id
	var results: Dictionary = {}
	gs.player_places[me] = [ZonePresence.FARM, 0]
	_at(12.0, func() -> String:
		results["farm"] = gs.fast_travel(ZONE, me)
		return "")
	_in_dome(gs)
	_at(12.0, func() -> String:
		results["unknown"] = gs.fast_travel("nowhere", me)
		return "")
	_at(3.0, func() -> String:
		results["shut"] = gs.fast_travel(ZONE, me)
		return "")
	var problems: Array[String] = []
	if results["farm"] == "":
		problems.append("The console is in the dome, not on the farm")
	if results["unknown"] == "":
		problems.append("A zone with no scene is refused")
	if results["shut"] == "":
		problems.append("Shut between the rescue hour and 06:00, like the mouth")
	if gs.rover_zone != "":
		problems.append("A refusal changes nothing")
	gs.free()
	return "\n".join(problems)


func test_a_second_traveller_joins_the_rover_where_it_is() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	var friend: String = _in_dome(gs, "player_2")
	var results: Dictionary = {}
	var pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.05, 20.0))
	_at(12.0, func() -> String:
		results["first"] = gs.fast_travel(ZONE, me)
		return "")
	gs.rover_transforms[gs.TUNNEL_ROVER] = pose
	var epoch: int = gs.rover_epoch
	_at(12.0, func() -> String:
		results["second"] = gs.fast_travel(ZONE, friend)
		return "")
	var problems: Array[String] = []
	if results["first"] != "" or results["second"] != "":
		problems.append("Refused: '%s' '%s'" % [results["first"], results["second"]])
	if gs.parked_rover_transform(gs.TUNNEL_ROVER) != pose or gs.rover_epoch != epoch:
		problems.append("Joining leaves the rover where it is, and no new epoch")
	if gs.place_of(friend) != ZONE:
		problems.append("The friend is in the zone")
	gs.free()
	return "\n".join(problems)


func test_a_rover_left_below_with_nobody_below_starts_again_at_the_hub() -> String:
	var problems: Array[String] = []
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.rover_zone = ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, -20.0, 0.0))
	var epoch: int = gs.rover_epoch
	var problem: String = ""
	_at(12.0, func() -> String:
		problem = gs.fast_travel(ZONE, me)
		return "")
	if problem != "" or gs.rover_depth != 0 or gs.parked_rover_transform(gs.TUNNEL_ROVER).origin != gs.TUNNEL_START.origin:
		problems.append("Nobody below: the rover starts at the hub (%s, depth %d)" % [problem, gs.rover_depth])
	if gs.rover_epoch != epoch + 1:
		problems.append("A re-park is a new epoch")
	# Someone below: join at the depth, no re-park.
	var other: GameStateScript = _state()
	var you: String = _in_dome(other)
	other.rover_zone = ZONE
	other.rover_depth = 1
	other.rover_transforms[other.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, -20.0, 0.0))
	other.player_places["player_2"] = [ZONE, 0]  # in the hub, maybe on the way down
	var before: int = other.rover_epoch
	var joined: String = ""
	_at(12.0, func() -> String:
		joined = other.fast_travel(ZONE, you)
		return "")
	if joined != "" or other.rover_depth != 1 or other.rover_epoch != before or other.place_of(you) != ZONE:
		problems.append("Someone in the zone: join at depth 1 without a re-park (%s)" % joined)
	other.free()
	gs.free()
	return "\n".join(problems)


func test_the_arrival_plan() -> String:
	if FastTravel.arrival_plan(true, 1, []) != FastTravel.RE_PARK:
		return "Live, below, nobody below: re-park"
	if FastTravel.arrival_plan(true, 1, [[ZONE, 0]]) != FastTravel.JOIN:
		return "Someone in the hub may be on the way down: join"
	if FastTravel.arrival_plan(true, 1, [[ZONE, 1]]) != FastTravel.JOIN or FastTravel.arrival_plan(true, 0, []) != FastTravel.JOIN:
		return "Someone below, or the rover at the hub: join"
	if FastTravel.arrival_plan(false, 0, []) != FastTravel.START:
		return "None live: start one"
	return ""


func test_the_console_offers_the_zones_that_have_a_scene() -> String:
	var rows: Array = FastTravel.destinations(1, [ZONE])
	var ids: Array = []
	for row: Dictionary in rows:
		ids.append(str(row["id"]))
		if str(row["name"]) == "":
			return "A row without a name: %s" % [row]
	if not ZONE in ids:
		return "The Lava Tubes are on the console: %s" % [ids]
	if not FastTravel.destinations(1, []).is_empty():
		return "A zone the farm has not been to is not on the console"
	return ""


# --- Coming home ------------------------------------------------------------------------

func test_the_last_one_out_lets_the_field_rover_go_and_the_farm_rover_is_untouched() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	var friend: String = _in_dome(gs, "player_2")
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		gs.fast_travel(ZONE, friend)
		return "")
	var problems: Array[String] = []
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.05, 10.0))
	if gs.leave_zone(me) == "":
		problems.append("The rover is not on the pad: the host refuses")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	if gs.leave_zone(me) != "" or gs.place_of(me) != ZonePresence.DOME:
		problems.append("The first leaves for the dome")
	if gs.rover_zone != ZONE or not gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("The rover stays while a friend is there")
	var epoch: int = gs.rover_epoch
	if gs.leave_zone(friend) != "":
		problems.append("The second leaves too")
	if gs.rover_zone != "" or gs.rover_transforms.has(gs.TUNNEL_ROVER) or gs.rover_epoch != epoch + 1:
		problems.append("The last out lets the field rover go (zone '%s')" % gs.rover_zone)
	if not _home_unmoved(gs) or gs.rover_in_tunnels or gs.rover_lent:
		problems.append("The farm rover did not move")
	if gs.leave_zone(friend) == "":
		problems.append("Someone in the dome has no zone to leave")
	gs.free()
	return "\n".join(problems)


func test_a_lent_rover_goes_home_by_the_mouth_not_the_dome() -> String:
	var gs: GameStateScript = _state()
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	var me: String = gs.local_player_id
	var lend: String = gs.move_rover(true)
	gs.player_places[me] = [ZONE, 0]
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	var problems: Array[String] = []
	if lend != "" or not gs.rover_lent or not gs.rover_is_away(gs.ROVER) or gs.rover_is_away(gs.TUNNEL_ROVER):
		problems.append("The mouth lends the farm rover as it always did (%s)" % lend)
	if gs.leave_zone(me) == "" or gs.rover_zone != ZONE:
		problems.append("A lent rover goes home by the mouth, not the dome")
	gs.free()
	return "\n".join(problems)


func test_the_mouth_is_shut_while_a_field_rover_is_there() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	var refused: String = gs.move_rover(true)
	var problems: Array[String] = []
	if refused == "" or gs.rover_lent:
		problems.append("One rover in the zone: the farm's cannot also go in")
	gs.free()
	return "\n".join(problems)


# --- The recall ---------------------------------------------------------------------------

func test_the_host_in_a_zone_by_fast_travel_is_carried_to_bed_at_two() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.credits = 200
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	gs.recall_in_tunnels = func() -> bool: return true
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	_at(2.0, func() -> String:
		gs._tick_recall()
		return "")
	var problems: Array[String] = []
	if beds.put_to_bed != [me]:
		problems.append("The host is put to bed: %s" % [beds.put_to_bed])
	if gs.rover_zone != "" or gs.rover_in_tunnels or gs.rover_transforms.has(gs.TUNNEL_ROVER) or not _home_unmoved(gs):
		problems.append("A host rescued from a zone with nobody else below releases the field rover; the farm rover is where it was")
	gs.free()
	return "\n".join(problems)


func test_a_guest_in_a_zone_is_rescued_at_two_and_a_guests_copy_rescues_nobody() -> String:
	var gs: GameStateScript = _state()
	var guest: String = _in_dome(gs, "player_2")
	gs.credits = 200
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, guest)
		return "")
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.recall_in_tunnels = func() -> bool: return false  # the host is not in the zone
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	_at(2.5, func() -> String:
		gs._tick_recall()
		return "")
	FarmCommands.guest = held
	var problems: Array[String] = []
	if not beds.put_to_bed.is_empty() or gs.credits != 200 or gs.rover_zone != ZONE:
		problems.append("A guest's copy must not rescue (bed %s, %d CR, zone '%s')" % [beds.put_to_bed, gs.credits, gs.rover_zone])
	_at(2.5, func() -> String:
		gs._tick_recall()
		return "")
	if beds.put_to_bed != [guest] or gs.credits != 150 or gs.rover_zone != "" or gs.place_of(guest) != ZonePresence.FARM:
		problems.append("The host rescues a guest below: bed %s, %d CR, zone '%s', at %s" % [beds.put_to_bed, gs.credits, gs.rover_zone, gs.place_of(guest)])
	gs.free()
	return "
".join(problems)


# --- Review round one -----------------------------------------------------------------------

func test_a_zone_the_farm_has_not_been_to_is_not_on_the_console_and_is_refused() -> String:
	var gs: GameStateScript = _state()
	gs.zones_unlocked.clear()
	var me: String = _in_dome(gs)
	var results: Dictionary = {}
	_at(12.0, func() -> String:
		results["locked"] = gs.fast_travel(ZONE, me)
		return "")
	var problems: Array[String] = []
	if results["locked"] == "" or gs.rover_zone != "":
		problems.append("A fresh farm cannot fast-travel before its first visit by the mouth")
	# The first real visit opens it.
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	if gs.move_rover(true) != "" or not gs.zones_unlocked.has(ZONE):
		problems.append("The mouth opens the zone to the console")
	gs.free()
	return "\n".join(problems)


func test_the_unlocked_list_is_saved_sent_grandfathered_and_checked() -> String:
	var gs: GameStateScript = _state()
	var saved: Dictionary = gs.farm_to_dict()
	var problems: Array[String] = []
	if saved.get("zones_unlocked") != [ZONE]:
		problems.append("zones_unlocked is saved")
	var back: GameStateScript = GameStateScript.new()
	back.build_registry()
	if back.farm_from_dict(bytes_to_var(var_to_bytes(saved))) != "" or back.zones_unlocked != [ZONE]:
		problems.append("zones_unlocked is loaded: %s" % [back.zones_unlocked])
	var old: Dictionary = saved.duplicate(true)
	old.erase("zones_unlocked")
	old.erase("rover_lent")
	old["rover_zone"] = ZONE
	var older: GameStateScript = GameStateScript.new()
	older.build_registry()
	if older.farm_from_dict(bytes_to_var(var_to_bytes(old))) != "" or older.zones_unlocked != [ZONE]:
		problems.append("A save whose rover is in the zone grandfathers it: %s" % [older.zones_unlocked])
	var home: Dictionary = saved.duplicate(true)
	home.erase("zones_unlocked")
	var plain: GameStateScript = GameStateScript.new()
	plain.build_registry()
	if plain.farm_from_dict(bytes_to_var(var_to_bytes(home))) != "" or not plain.zones_unlocked.is_empty():
		problems.append("A save with the rover home has no zones yet")
	for wrong: Array in [["nowhere"], [ZONE, ZONE], [5]]:
		var bad: Dictionary = saved.duplicate(true)
		bad["zones_unlocked"] = wrong
		if plain.farm_dict_problem(bad) == "":
			problems.append("%s must be refused" % [wrong])
	if not "zones_unlocked" in SyncScript.SHOWN_BY[&"rover_place_changed"]:
		problems.append("A guest is shown the list")
	plain.free()
	older.free()
	back.free()
	gs.free()
	return "\n".join(problems)


func test_joining_and_leaving_keep_another_player_s_lease() -> String:
	var session: Node = _session()
	var gs: GameStateScript = session.commands.state
	gs.zones_unlocked.append(ZONE)
	var rovers: Node = RoversScript.new()
	rovers.start(session, gs)
	var me: String = _in_dome(gs, "player_2")
	var friend: String = _in_dome(gs, "player_3")
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	rovers._drivers[gs.TUNNEL_ROVER] = [me, 1 << 60]
	rovers._drivers[gs.ROVER] = ["player_4", 1 << 60]
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, friend)
		return "")
	var problems: Array[String] = []
	if rovers.driver(gs.TUNNEL_ROVER) != me:
		problems.append("A friend joining must not end the driver's lease")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	gs.leave_zone(friend)
	if rovers.driver(gs.TUNNEL_ROVER) != me:
		problems.append("A friend leaving must not end the driver's lease")
	gs.leave_zone(me)  # the last out: the field rover goes
	if rovers.driver(gs.TUNNEL_ROVER) != "" or rovers.driver(gs.ROVER) != "player_4":
		problems.append("The field rover going clears its own lease and not the farm rover's")
	rovers.free()
	return _finish("\n".join(problems))


func test_nobody_re_parks_the_rover_under_a_descent_in_the_fade() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.rover_zone = ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(0.0, -20.0, 0.0))
	gs.player_places["player_2"] = [ZONE, 0]  # went down; the host records it late
	var epoch: int = gs.rover_epoch
	var problem: String = ""
	_at(12.0, func() -> String:
		problem = gs.fast_travel(ZONE, me)
		return "")
	var bad: bool = problem != "" or gs.rover_depth != 1 or gs.rover_epoch != epoch
	gs.free()
	return "The descent stands (%s)" % problem if bad else ""


func test_leaving_the_zone_is_checked_on_the_host() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	var problems: Array[String] = []
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.05, 10.0))
	if gs.leave_zone(me) == "":
		problems.append("Off the pad: refused")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	gs.player_places[me] = [ZONE, 1]
	if gs.leave_zone(me) == "":
		problems.append("A player below the hub: refused")
	gs.player_places[me] = [ZONE, 0]
	if gs.leave_zone(me) != "":
		problems.append("On the pad in the hub: allowed")
	gs.free()
	return "\n".join(problems)


func test_rescuing_the_host_leaves_the_rover_to_a_guest_on_the_trip_in_the_dome() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	var guest: String = _in_dome(gs, "player_2")
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		gs.fast_travel(ZONE, guest)
		return "")
	gs.player_places[guest] = [ZonePresence.DOME, 0]  # came up to the dome: still on the trip, not below
	gs.recall_in_tunnels = func() -> bool: return true
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	_at(2.0, func() -> String:
		gs._tick_recall()
		return "")
	var problems: Array[String] = []
	if beds.put_to_bed != [me]:
		problems.append("Only the host goes to bed: %s" % [beds.put_to_bed])
	if gs.rover_zone != ZONE or not gs.rover_transforms.has(gs.TUNNEL_ROVER) or gs.place_of(guest) != ZonePresence.DOME:
		problems.append("The guest in the dome keeps the field rover on the trip")
	# And while it is occupied the mouth stays shut.
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	if gs.move_rover(true) == "" or gs.rover_lent:
		problems.append("The farm rover cannot be lent in while a guest is there")
	gs.free()
	return "\n".join(problems)


func test_an_empty_field_rover_does_not_block_the_mouth() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZONE  # left live with nobody
	gs.rover_transforms[gs.TUNNEL_ROVER] = gs.TUNNEL_START
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	var problem: String = gs.move_rover(true)
	var bad: bool = problem != "" or not gs.rover_lent
	gs.free()
	return "The mouth is free (%s)" % problem if bad else ""


func test_a_rescue_takes_no_ore_and_field_driving_does_not_wear_the_farm_wheels() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.crystal_ore = 7
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	gs.crystal_ore = 90  # mined on the farm meanwhile
	var problems: Array[String] = []
	if gs.ore_carried_in() != 0:
		problems.append("A fast-travel rescue takes no ore")
	var before: float = gs.wheel_meters
	gs.add_rover_usage(50.0, me, gs.TUNNEL_ROVER)
	if gs.wheel_meters != before:
		problems.append("A field rover does not wear the farm rover's wheels")
	gs.add_rover_usage(50.0, me, gs.ROVER)
	if gs.wheel_meters != before + 50.0:
		problems.append("The farm rover's own driving still does")
	gs.free()
	return "\n".join(problems)


func test_the_airlock_does_not_lead_to_a_zone_in_the_closed_hours() -> String:
	var gs: GameStateScript = _state()
	var held_outside: String = SceneSwitcher.outside
	SceneSwitcher.outside = SceneSwitcher.TUNNELS_SCENE
	var held_zone: String = GameState.rover_zone
	GameState.rover_zone = ZONE
	var held_clock: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 3.0)
	var shut: String = SceneSwitcher.exit_path()
	SceneSwitcher.outside = SceneSwitcher.TUNNELS_SCENE
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 12.0)
	var open: String = SceneSwitcher.exit_path()
	GameClock.elapsed_days = held_clock
	GameState.rover_zone = held_zone
	SceneSwitcher.outside = held_outside
	gs.free()
	var problems: Array[String] = []
	if shut != SceneSwitcher.FARM_SCENE:
		problems.append("Shut at 03:00 the airlock leads to the farm")
	if open != SceneSwitcher.TUNNELS_SCENE:
		problems.append("Open by day it leads to the zone")
	return "\n".join(problems)


func test_the_airlock_waits_while_a_trip_is_pending() -> String:
	FastTravel.pending = false
	return "" if not FastTravel.pending else "No request is out by default"


# --- Review round two -----------------------------------------------------------------------

func _old_save(gs: GameStateScript) -> Dictionary:
	var old: Dictionary = gs.farm_to_dict()
	old.erase("zones_unlocked")
	return old


func _unlocked_after_loading(data: Dictionary) -> Array:
	var loaded: GameStateScript = GameStateScript.new()
	loaded.build_registry()
	var problem: String = loaded.farm_from_dict(bytes_to_var(var_to_bytes(data)))
	var got: Array = loaded.zones_unlocked.duplicate()
	loaded.free()
	return got if problem == "" else ["problem: " + problem]


func test_an_older_save_that_came_home_from_the_tubes_keeps_its_unlock() -> String:
	var gs: GameStateScript = _state()
	var problems: Array[String] = []
	if not _unlocked_after_loading(_old_save(gs)).is_empty():
		problems.append("A farm that never went has nothing unlocked")
	var with_pose: Dictionary = _old_save(gs)
	(with_pose["rover_transforms"] as Dictionary)[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)  # the old way home kept it
	if _unlocked_after_loading(with_pose) != [ZONE]:
		problems.append("A kept tunnel-rover pose is a visit: %s" % [_unlocked_after_loading(with_pose)])
	var found: Dictionary = _old_save(gs)
	found["finds_taken"] = ZoneDepth.with_taken({}, ZONE, 1, ZoneDepth.find_id(0))
	if _unlocked_after_loading(found) != [ZONE]:
		problems.append("A find taken there is a visit: %s" % [_unlocked_after_loading(found)])
	gs.free()
	return "\n".join(problems)


func test_a_guest_clears_only_the_rover_that_changed() -> String:
	var gs: GameStateScript = _state()
	var scopes: Array[String] = []
	var listener: Callable = func() -> void: scopes.append(gs.rover_place_scope)
	gs.rover_place_changed.connect(listener)
	var before: Dictionary = gs.farm_to_dict()
	gs.rover_zone = ZONE
	gs.rover_epoch += 1
	FarmSync._show_changes(gs, before, false)
	before = gs.farm_to_dict()
	gs.zones_unlocked.clear()
	FarmSync._show_changes(gs, before, false)
	before = gs.farm_to_dict()
	gs.rover_in_tunnels = true  # the farm's own rover goes out
	FarmSync._show_changes(gs, before, false)
	gs.rover_place_changed.disconnect(listener)
	var problems: Array[String] = []
	if scopes != [gs.TUNNEL_ROVER, "unlock", ""]:
		problems.append("A field rover starting touches its own; an unlock touches none; the farm rover going touches all: %s" % [scopes])
	if gs.rover_place_scope != "":
		problems.append("The scope is not left set")
	gs.free()
	return "\n".join(problems)


func test_another_rover_s_change_does_not_reset_a_controller() -> String:
	var source: String = FileAccess.get_file_as_string("res://scripts/rover/rover_controller.gd")
	return "" if "only != rover_id" in source else "A rover's controller ignores another rover's scoped change"


func test_leaving_the_zone_reads_the_rover_where_it_is_now() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	# Continued from a save made off the pad: the parked pose is old, the rover's is live.
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.05, 10.0))
	var live := _LiveRover.new()
	live.rover_id = gs.TUNNEL_ROVER
	live.at = gs.TUNNEL_EXIT  # driven onto the pad
	(Engine.get_main_loop() as SceneTree).root.add_child(live)
	live.add_to_group(GameStateScript.LIVE_ROVER_GROUP)
	var saved: Array[int] = [0]
	var count: Callable = func() -> void: saved[0] += 1
	SaveGame.saving.connect(count)
	var problem: String = gs.leave_zone(me)
	SaveGame.saving.disconnect(count)
	live.get_parent().remove_child(live)
	live.free()
	var bad: bool = problem != "" or gs.place_of(me) != ZonePresence.DOME
	gs.free()
	if bad:
		return "Driven onto the pad, E leaves (%s)" % problem
	if saved[0] != 0:
		return "The check reads the pose and saves nothing"
	return ""


func test_a_guest_s_newer_pose_beats_the_host_controller_s_older_one() -> String:
	var session: Node = _session()
	var gs: GameStateScript = session.commands.state
	gs.zones_unlocked.append(ZONE)
	var rovers: Node = _TogetherRovers.new()
	rovers.start(session, gs)
	gs.rovers_node = rovers
	var me: String = _in_dome(gs, "player_2")
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	# The host has just loaded: its controller is on the pad, not yet following anyone.
	var live := _LiveRover.new()
	live.rover_id = gs.TUNNEL_ROVER
	live.at = gs.TUNNEL_EXIT
	(Engine.get_main_loop() as SceneTree).root.add_child(live)
	live.add_to_group(GameStateScript.LIVE_ROVER_GROUP)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	# The guest drove off the pad; the host accepted that pose.
	rovers._drivers[gs.TUNNEL_ROVER] = [me, 1 << 60]
	rovers._poses[gs.TUNNEL_ROVER] = [[-1.5, 0.05, 10.0, 0.0, 0.0, true], 0]
	var refused: String = gs.leave_zone(me)
	var asked: int = live.asked
	live.get_parent().remove_child(live)
	live.free()
	var problems: Array[String] = []
	if refused == "" or gs.place_of(me) == ZonePresence.DOME:
		problems.append("The guest's off-pad pose wins over the host's older on-pad one")
	if asked != 0:
		problems.append("The host's controller is not asked while a teammate drives")
	rovers.free()
	return _finish("
".join(problems))


func test_a_depth_change_and_a_re_park_keep_the_farm_rover_s_lease() -> String:
	var session: Node = _session()
	var gs: GameStateScript = session.commands.state
	var rovers: Node = RoversScript.new()
	rovers.start(session, gs)
	gs.rover_zone = gs.TUNNELS_ZONE
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, ZoneDepth.descent_position())
	var problems: Array[String] = []
	rovers._drivers[gs.ROVER] = ["player_4", 1 << 60]
	rovers._drivers[gs.TUNNEL_ROVER] = ["player_5", 1 << 60]
	var refused: String = gs.change_depth(1)
	if refused != "":
		problems.append("The test's descent was refused: %s" % refused)
	if rovers.driver(gs.ROVER) != "player_4" or rovers.driver(gs.TUNNEL_ROVER) != "":
		problems.append("A field rover going down clears its own lease and not the farm rover's")
	rovers._drivers[gs.ROVER] = ["player_4", 1 << 60]
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(900.0, 0.0, 900.0))  # in the rock
	if not gs.settle_rover_depth(false):
		problems.append("The test's rover was not re-parked")
	if rovers.driver(gs.ROVER) != "player_4":
		problems.append("A morning re-park keeps the farm rover's lease")
	if gs.rover_place_scope != "":
		problems.append("The scope is not left set")
	rovers.free()
	return _finish("
".join(problems))


func test_the_airlock_records_the_player_in_the_zone_at_the_commit() -> String:
	var me: String = GameState.local_player_id
	var held: Variant = GameState.player_places.get(me)
	var guest_held: bool = FarmCommands.guest
	FarmCommands.guest = false
	GameState.player_places[me] = [ZonePresence.DOME, 0]
	SceneSwitcher.note_arrival(SceneSwitcher.DOME_SCENE)
	var problems: Array[String] = []
	if GameState.place_of(me) != ZonePresence.DOME:
		problems.append("Only a zone is recorded early")
	SceneSwitcher.note_arrival(SceneSwitcher.TUNNELS_SCENE)
	if GameState.place_of(me) != ZONE:
		problems.append("The host is in the zone as the swap is committed")
	FarmCommands.guest = guest_held
	if held == null:
		GameState.player_places.erase(me)
	else:
		GameState.player_places[me] = held
	var source: String = FileAccess.get_file_as_string("res://scripts/autoload/SceneSwitcher.gd")
	if not "CoopScenes.report_scene(path)" in source:
		problems.append("A guest tells the host at swap start")
	if not "note_arrival(path)" in source.split("func swap_to")[1].split("await")[0]:
		problems.append("It is recorded before the fade")
	return "
".join(problems)


func test_a_console_arrival_does_not_re_park_a_rover_a_host_is_arriving_at() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs, "player_2")
	gs.rover_zone = ZONE
	gs.rover_depth = 0
	var parked: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.05, 15.0))
	gs.rover_transforms[gs.TUNNEL_ROVER] = parked
	gs.player_places[gs.local_player_id] = [ZONE, 0]  # the host, in the fade into the zone
	var epoch: int = gs.rover_epoch
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	var kept: bool = gs.parked_rover_transform(gs.TUNNEL_ROVER).origin == parked.origin and gs.rover_epoch == epoch
	gs.free()
	return "" if kept else "The host's arrival counts: the rover stays where it is"


func test_a_rebuild_puts_the_rover_where_it_is_when_that_is_in_the_rock() -> String:
	var problems: Array[String] = []
	var seed_value: int = 424242
	var day: int = 1
	var hub: Transform3D = ZoneDepth.pose_for_depth(0)
	var inside: Transform3D = Transform3D(Basis.IDENTITY, ZoneDepth.start_transform().origin)
	if ZoneDepth.rebuild_pose(inside, 1, seed_value, day).origin != inside.origin:
		problems.append("A parked pose inside the depth's rock is kept")
	if ZoneDepth.rebuild_pose(Transform3D(Basis.IDENTITY, Vector3(900.0, 0.0, 900.0)), 1, seed_value, day).origin != ZoneDepth.pose_for_depth(1).origin:
		problems.append("A pose in the rock is the depth's start")
	if ZoneDepth.rebuild_pose(null, 0, seed_value, day).origin != hub.origin:
		problems.append("No pose is the depth's start")
	var source: String = FileAccess.get_file_as_string("res://scripts/basalt_tunnels.gd")
	if not "parked_rover_transform(GameState.TUNNEL_ROVER)" in source:
		problems.append("The host's rebuild asks for its parked pose")
	return "
".join(problems)


func test_nothing_leaves_the_dome_while_a_trip_is_pending() -> String:
	var problems: Array[String] = []
	FastTravel.pending = true
	if not SceneSwitcher.trip_holds_dome(SceneSwitcher.DOME_SCENE):
		problems.append("Tab, the airlock and every swap out of the dome wait")
	if SceneSwitcher.trip_holds_dome(SceneSwitcher.FARM_SCENE):
		problems.append("Only the dome is held")
	FastTravel.pending = false
	if SceneSwitcher.trip_holds_dome(SceneSwitcher.DOME_SCENE):
		problems.append("Free once answered")
	return "\n".join(problems)


func test_a_console_join_keeps_the_lender_s_baseline_and_a_new_field_rover_clears_it() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.crystal_ore = 7
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	gs.move_rover(true, "player_2")  # a guest lends the farm rover in
	gs.player_places["player_2"] = [ZONE, 0]
	gs.crystal_ore = 90
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)  # the host joins it by the console
		return "")
	var problems: Array[String] = []
	if gs.ore_carried_in() != 83:
		problems.append("A join does not erase the entrant's baseline (%d)" % gs.ore_carried_in())
	var fresh: GameStateScript = _state()
	var you: String = _in_dome(fresh)
	fresh.crystal_ore = 50
	fresh._ore_at_entry = 10  # left over from an earlier trip
	_at(12.0, func() -> String:
		fresh.fast_travel(ZONE, you)
		return "")
	if fresh.ore_carried_in() != 0:
		problems.append("A new field rover by the console takes no ore (%d)" % fresh.ore_carried_in())
	fresh.free()
	gs.free()
	return "
".join(problems)


func test_a_refused_mouth_entry_leaves_the_field_rover_and_a_good_one_says_it_went() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZONE  # live, nobody with it
	gs.rover_transforms[gs.TUNNEL_ROVER] = gs.TUNNEL_START
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	var epoch: int = gs.rover_epoch
	var refused: Array[String] = []
	_at(3.0, func() -> String:
		refused.append(gs.move_rover(true))
		return "")
	var problems: Array[String] = []
	if refused[0] == "" or gs.rover_zone != ZONE or gs.rover_epoch != epoch or not gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("At 03:00 the refusal changes nothing")
	var scopes: Array[String] = []
	var listener: Callable = func() -> void: scopes.append(gs.rover_place_scope)
	gs.rover_place_changed.connect(listener)
	_at(12.0, func() -> String:
		gs.move_rover(true)
		return "")
	gs.rover_place_changed.disconnect(listener)
	if scopes.size() < 2 or scopes[0] != gs.TUNNEL_ROVER:
		problems.append("Freeing the field rover says so, scoped: %s" % [scopes])
	gs.free()
	return "\n".join(problems)


func test_the_host_s_told_pose_is_what_a_rebuilt_scene_uses() -> String:
	var session: Node = _session()
	var gs: GameStateScript = session.commands.state
	var rovers: Node = RoversScript.new()
	rovers.start(session, gs)
	var problems: Array[String] = []
	if rovers.told_pose(gs.TUNNEL_ROVER) != null:
		problems.append("Nothing told yet")
	rovers._poses[gs.TUNNEL_ROVER] = [[1.0, 0.05, 2.0, 0.0, 0.0, true], 0]
	var told: Variant = rovers.told_pose(gs.TUNNEL_ROVER)
	if not told is Transform3D or (told as Transform3D).origin.x != 1.0:
		problems.append("The pose is given")
	rovers._forget()
	if rovers.told_pose(gs.TUNNEL_ROVER) != null:
		problems.append("A change of place forgets it")
	var source: String = FileAccess.get_file_as_string("res://scripts/basalt_tunnels.gd")
	if not "_rover_pose_for_rebuild()" in source or not "told_pose" in source:
		problems.append("The rebuild asks for it")
	rovers.free()
	return _finish("\n".join(problems))


func test_an_open_console_lists_a_zone_unlocked_while_it_is_open() -> String:
	var held: Array[String] = GameState.zones_unlocked.duplicate()
	GameState.zones_unlocked.clear()
	var ui := FastTravelUI.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.open()
	GameState.zones_unlocked.append(ZONE)
	GameState.rover_place_changed.emit()
	var rows: int = 0
	for row: Node in ui._rows.get_children():
		if row is HBoxContainer and not row.is_queued_for_deletion():
			rows += 1
	ui.get_parent().remove_child(ui)
	ui.free()
	GameState.zones_unlocked.assign(held)
	return "" if rows == 1 else "The unlock appears without reopening (%d rows)" % rows


func test_an_open_console_keeps_its_focus_unless_the_list_changed() -> String:
	var held: Array[String] = GameState.zones_unlocked.duplicate()
	GameState.zones_unlocked.assign([ZONE])
	var ui := FastTravelUI.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.open()
	var go: Button = ui._rows.get_child(0).get_child(1)
	go.grab_focus()
	var problems: Array[String] = []
	GameState.rover_place_changed.emit()  # a teammate's depth change
	if ui._rows.get_child(0).get_child(1) != go or not go.has_focus():
		problems.append("A rover update with the same list leaves the rows and the focus")
	GameState.zones_unlocked.clear()
	GameState.rover_place_changed.emit()
	if ui._rows.get_child_count() == 0 or ui._shown.size() != 0:
		problems.append("A changed list is rebuilt")
	ui.get_parent().remove_child(ui)
	ui.free()
	GameState.zones_unlocked.assign(held)
	return "
".join(problems)


func test_the_recall_charges_a_console_joiner_credits_only() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	gs.credits = 500
	gs.crystal_ore = 7
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	gs.move_rover(true, "player_2")  # a guest lends the farm rover in: their baseline is 7
	gs.player_places["player_2"] = [ZONE, 0]
	gs.crystal_ore = 90
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)  # the host joins by the console
		return "")
	var host_bill: Dictionary = gs.rescue_from_tunnels(me)
	var problems: Array[String] = []
	if int(host_bill["ore"]) != 0 or gs.crystal_ore != 90:
		problems.append("The console joiner pays no ore (%s, ore %d)" % [host_bill, gs.crystal_ore])
	var guest_bill: Dictionary = gs.rescue_from_tunnels("player_2")
	if int(guest_bill["ore"]) == 0:
		problems.append("The mouth entrant still pays by their baseline")
	gs.free()
	return "
".join(problems)


func test_the_recall_keeps_a_field_rover_for_those_below_and_brings_a_lent_one_home_only_when_empty() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	gs.player_places["player_2"] = [ZONE, 0]  # a guest is recorded below too
	gs.rescue_from_tunnels(me)
	var problems: Array[String] = []
	if gs.rover_zone != ZONE or not gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("A field rover stays while someone else is recorded below")
	gs.player_places["player_2"] = [ZonePresence.DOME, 0]
	gs.rescue_from_tunnels(me)
	if gs.rover_zone != "" or gs.rover_transforms.has(gs.TUNNEL_ROVER):
		problems.append("A field rover is released when nobody is recorded below")
	var lent: GameStateScript = _state()
	lent.rover_transforms[lent.ROVER] = Transform3D(Basis.IDENTITY, lent.TUNNEL_PAD)
	lent.move_rover(true)
	lent.player_places["player_2"] = [ZONE, 0]
	lent.rescue_from_tunnels()
	if not lent.rover_lent:
		problems.append("A lent rover stays while someone is recorded below")
	lent.player_places.erase("player_2")
	lent.rescue_from_tunnels()
	if lent.rover_lent:
		problems.append("A lent rover comes home when nobody is below")
	lent.free()
	gs.free()
	return "
".join(problems)


func test_a_host_who_has_left_by_the_pad_is_not_recalled_in_the_fade() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	var guest: String = _in_dome(gs, "player_2")
	gs.credits = 200
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		gs.fast_travel(ZONE, guest)
		return "")
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	var left: String = gs.leave_zone(me)
	gs.recall_in_tunnels = func() -> bool: return true  # the scene is still the tunnels
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	_at(2.0, func() -> String:
		gs._tick_recall()
		return "")
	var problems: Array[String] = []
	if left != "":
		problems.append("The exit was refused: %s" % left)
	if beds.put_to_bed != [guest] or gs.credits != 150:
		problems.append("Only the guest below is charged and put to bed, not the host who left (%s, %d CR)" % [beds.put_to_bed, gs.credits])
	gs.free()
	return "
".join(problems)


func test_a_save_whose_trip_ended_in_a_rescue_keeps_its_unlock() -> String:
	var gs: GameStateScript = _state()
	var old: Dictionary = _old_save(gs)
	old["phone_log"] = [TunnelRecall.text("rescue_text") % "ryan"]
	var cost: Dictionary = _old_save(gs)
	cost["phone_log"] = ["hello", TunnelRecall.text("cost_none_text") % "Ryan"]
	var problems: Array[String] = []
	if _unlocked_after_loading(old) != [ZONE]:
		problems.append("A saved rescue message is a visit: %s" % [_unlocked_after_loading(old)])
	if _unlocked_after_loading(cost) != [ZONE]:
		problems.append("A saved recovery fee is a visit")
	gs.free()
	return "
".join(problems)


func test_stale_console_arrivals_do_not_waive_a_later_mouth_trips_ore_charge() -> String:
	var gs: GameStateScript = _state()
	var host: String = gs.local_player_id
	# Trip 1: a guest lends the rover in by the mouth, the host joins by console, they drive out.
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	gs.move_rover(true, "player_2")
	_in_dome(gs, host)
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, host)
		return "")
	var problems: Array[String] = []
	if not gs._console_arrivals.has(host):
		problems.append("The console join is noted")
	gs.player_places.clear()
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	gs.move_rover(false)
	if not gs._console_arrivals.is_empty():
		problems.append("Driving out ends the trip and clears the notes")
	# Trip 2: the guest lends it in again; the host follows from the farm, no console.
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	gs.crystal_ore = 50
	gs.move_rover(true, "player_2")
	gs.player_places["player_2"] = [ZONE, 0]
	gs.player_places[host] = [ZONE, 0]
	gs.crystal_ore = 80
	var bill: Dictionary = gs.rescue_from_tunnels(host)
	if int(bill["ore"]) == 0:
		problems.append("The host's rescue charges ore by the mouth baseline, not a stale console note")
	# Every other end of a trip clears the notes too.
	gs._console_arrivals["x"] = true
	gs._release_field_rover()
	if not gs._console_arrivals.is_empty():
		problems.append("Releasing the field rover clears the notes")
	gs._console_arrivals["x"] = true
	gs.rover_zone = ZONE
	gs.rover_lent = true
	gs.bring_rover_home()
	if not gs._console_arrivals.is_empty():
		problems.append("Bringing the rover home clears the notes")
	gs.free()
	return "
".join(problems)


func test_solo_fast_travel_rescued_at_two_leaves_nothing_for_continue_to_send_back() -> String:
	var gs: GameStateScript = _state()
	var me: String = _in_dome(gs)
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, me)
		return "")
	gs.recall_in_tunnels = func() -> bool: return true
	gs.recall_beds = _NoBeds.new()
	_at(2.0, func() -> String:
		gs._tick_recall()
		return "")
	var problems: Array[String] = []
	if gs.rover_in_tunnels:
		problems.append("After the rescue the rover is not in the tunnels")
	var data: Dictionary = gs.farm_to_dict()
	var back: GameStateScript = _state()
	back.farm_from_dict(data)
	if back.rover_in_tunnels:
		problems.append("A save after the rescue loads with the rover on the farm")
	back.free()
	gs.free()
	return "
".join(problems)
