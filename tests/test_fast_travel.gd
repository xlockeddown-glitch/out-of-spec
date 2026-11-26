extends RefCounted
## Fast travel (docs/design/zones.md section 8.1, build step 7): the dome console
## sends a player to a zone's field rover and the farm's rover stays home; the way
## home is the dome; a rover lent through the real entrance still works as it did.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const SyncScript: GDScript = preload("res://scripts/autoload/FarmSync.gd")

const ZONE: String = "lava_tubes"
const HOME: Vector3 = Vector3(3.0, 0.0, 3.0)


## Stands in for CoopBeds where a test only needs to know who was put to bed.
class _NoBeds:
	extends RefCounted
	var put_to_bed: Array[String] = []

	func recall_to_bed(player_id: String) -> void:
		put_to_bed.append(player_id)


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, HOME)
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
	if SessionScript.PROTOCOL != 21:
		problems.append("Fast travel changes what is sent: protocol 21, got %d" % SessionScript.PROTOCOL)
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
	gs.player_places["player_2"] = [ZONE, 0]  # in the hub: not below
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
	other.player_places["player_2"] = [ZONE, 1]
	var before: int = other.rover_epoch
	var joined: String = ""
	_at(12.0, func() -> String:
		joined = other.fast_travel(ZONE, you)
		return "")
	if joined != "" or other.rover_depth != 1 or other.rover_epoch != before or other.place_of(you) != ZONE:
		problems.append("Someone below: join at depth 1 without a re-park (%s)" % joined)
	other.free()
	gs.free()
	return "\n".join(problems)


func test_the_arrival_plan() -> String:
	if FastTravel.arrival_plan(true, 1, []) != FastTravel.RE_PARK:
		return "Live, below, nobody below: re-park"
	if FastTravel.arrival_plan(true, 1, [[ZONE, 0]]) != FastTravel.RE_PARK:
		return "Standing in the hub is not below"
	if FastTravel.arrival_plan(true, 1, [[ZONE, 1]]) != FastTravel.JOIN or FastTravel.arrival_plan(true, 0, []) != FastTravel.JOIN:
		return "Someone below, or the rover at the hub: join"
	if FastTravel.arrival_plan(false, 0, []) != FastTravel.START:
		return "None live: start one"
	return ""


func test_the_console_offers_the_zones_that_have_a_scene() -> String:
	var rows: Array = FastTravel.destinations(1)
	var ids: Array = []
	for row: Dictionary in rows:
		ids.append(str(row["id"]))
		if str(row["name"]) == "":
			return "A row without a name: %s" % [row]
	if not ZONE in ids:
		return "The Lava Tubes are on the console: %s" % [ids]
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
	if gs.rover_zone != "" or gs.rover_transforms.has(gs.TUNNEL_ROVER) or not _home_unmoved(gs):
		problems.append("The field rover is let go and the farm rover is where it was")
	gs.free()
	return "\n".join(problems)


func test_a_guest_in_a_zone_is_not_rescued_today() -> String:
	# Pins today's rule: the host's recall looks at the host's own screen only.
	# Rescuing guests is the next change; this test then changes with it.
	var gs: GameStateScript = _state()
	var guest: String = _in_dome(gs, "player_2")
	_at(12.0, func() -> String:
		gs.fast_travel(ZONE, guest)
		return "")
	var beds: _NoBeds = _NoBeds.new()
	gs.recall_beds = beds
	gs.recall_in_tunnels = func() -> bool: return false  # the host is not in the zone
	_at(2.5, func() -> String:
		gs._tick_recall()
		return "")
	var problems: Array[String] = []
	if not beds.put_to_bed.is_empty() or gs.rover_zone != ZONE:
		problems.append("A guest below at 02:00 is left alone (bed %s, zone '%s')" % [beds.put_to_bed, gs.rover_zone])
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	gs.recall_in_tunnels = func() -> bool: return true
	_at(2.5, func() -> String:
		gs._tick_recall()
		return "")
	FarmCommands.guest = held
	if not beds.put_to_bed.is_empty():
		problems.append("A guest's copy must not rescue")
	gs.free()
	return "\n".join(problems)
