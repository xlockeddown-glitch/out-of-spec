extends RefCounted
## The Flooded Aquifer's pressure drop (open seal / shut_valve) and wet pack
## (wading spoils one camp ration once a day): pure rules, host checks, save/load,
## FarmCommands/FarmSync wiring, and primitive valve look. Every number is [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "flooded_aquifer"


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	return gs


func _at(elapsed: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


func _rover_at(gs: GameStateScript, depth: int, at: Vector3, who: String = HOST) -> void:
	gs.rover_zone = ZONE
	gs.rover_lent = true
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[who] = [ZONE, depth]


func _free_node(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if _has_collision(child):
			return true
	return false


## Finds a day where room 0 (behind p1) or room 1 (behind p2) has a shallow pool:
## [day, pool_id, room_index, seal_id_today, room_finds (Array of Dict), landing_find (Dict)].
func _shallow_room_day() -> Array:
	for day: int in range(1, 200):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		var seal_today: String = str((data["seals"][0] as Dictionary)["id"])
		var landing_find: Dictionary = {}
		for find: Dictionary in data["finds"]:
			if int(find["room"]) == -1:
				landing_find = find
				break
		for pair: Array in [["p1", 0], ["p2", 1]]:
			var pool: Dictionary = AquiferDepth.pool_in(data, str(pair[0]))
			if AquiferDepth.is_shallow(pool):
				var in_room: Array = []
				for find: Dictionary in data["finds"]:
					if int(find["room"]) == int(pair[1]):
						in_room.append(find)
				if in_room.size() >= 2 and not landing_find.is_empty():
					return [day, str(pair[0]), int(pair[1]), seal_today, in_room, landing_find]
	return []


# --- Seal layout from the hash -----------------------------------------------------

func test_the_seal_is_fixed_per_seed_and_day_and_lies_in_a_rooms_doorway() -> String:
	var a: Dictionary = AquiferDepth.layout(SEED, 1, 7)
	var b: Dictionary = AquiferDepth.layout(SEED, 1, 7)
	if var_to_str(a["seals"]) != var_to_str(b["seals"]):
		return "The same seed and day produced different seals."
	var seen_rooms: Dictionary = {}
	var day_changes: int = 0
	for day: int in range(1, 60):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		var seals: Array = data["seals"]
		if seals.size() != AquiferDepth.SEALS_PER_DAY:
			return "Day %d has %d seals, not %d." % [day, seals.size(), AquiferDepth.SEALS_PER_DAY]
		var seal: Dictionary = seals[0]
		var room: int = int(seal["room"])
		var cell: Vector2i = seal["cell"]
		if room < 0 or room >= AquiferDepth.ROOMS.size():
			return "Day %d: seal room %d is out of range." % [day, room]
		if str(seal["id"]) != AquiferDepth.SEAL_IDS[room]:
			return "Day %d: seal id '%s' does not match room %d." % [day, seal["id"], room]
		var rect: Rect2i = AquiferDepth.ROOMS[room]
		if not rect.has_point(cell):
			return "Day %d: seal cell %s is outside room %d (%s)." % [day, cell, room, rect]
		var on_edge: bool = cell.x == rect.position.x or cell.x == rect.end.x - 1 \
				or cell.y == rect.position.y or cell.y == rect.end.y - 1
		if not on_edge:
			return "Day %d: seal cell %s is not on the doorway edge of room %d." % [day, cell, room]
		if data["grid"][cell.y][cell.x] != ".":
			return "Day %d: seal cell %s is not floor." % [day, cell]
		for find: Dictionary in data["finds"]:
			if find["cell"] == cell:
				return "Day %d: find %s was placed on the valve cell %s." % [day, find["id"], cell]
		seen_rooms[room] = true
		var next: Dictionary = AquiferDepth.layout(SEED, 1, day + 1)
		if var_to_str(next["seals"]) != var_to_str(seals):
			day_changes += 1
	if seen_rooms.size() != AquiferDepth.ROOMS.size():
		return "Not all three side rooms received an open seal across 59 days: %s." % [seen_rooms.keys()]
	if day_changes == 0:
		return "The seal never moved to another room across 59 days."
	var other_seeds: bool = false
	for extra: int in range(1, 12):
		if var_to_str(AquiferDepth.layout(SEED + extra, 1, 7)["seals"]) != var_to_str(a["seals"]):
			other_seeds = true
			break
	return "" if other_seeds else "Changing the world seed never changed the seal."


# --- Open seal refuses finds (reach checked first); shutting allows them -----------

func test_an_open_seal_refuses_its_rooms_finds_after_reach_and_shutting_allows_them() -> String:
	var chosen_day: int = -1
	for day: int in range(1, 60):
		var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
		if int((data["seals"][0] as Dictionary)["room"]) in [0, 1]:
			chosen_day = day
			break
	if chosen_day < 0:
		return "No day in 59 put an open seal in room 0 or 1."
	var problems: Array[String] = []
	var run: String = _at(float(chosen_day - 1), func() -> String:
		var gs: GameStateScript = _state()
		# Drain pools so only reach and the open seal govern the room's finds.
		for pid: String in AquiferDepth.POOL_IDS:
			gs.pools_drained = ZoneDepth.with_taken(gs.pools_drained, ZONE, chosen_day, pid)
		var data: Dictionary = AquiferDepth.layout(SEED, 1, chosen_day, AquiferDepth.POOL_IDS)
		var seal: Dictionary = data["seals"][0]
		var seal_id: String = str(seal["id"])
		var blocked_find: Dictionary = {}
		var free_find: Dictionary = {}
		for find: Dictionary in data["finds"]:
			if int(find["room"]) == int(seal["room"]) and blocked_find.is_empty():
				blocked_find = find
			elif int(find["room"]) != int(seal["room"]) and free_find.is_empty():
				free_find = find
		var find_pos: Vector3 = TunnelRock.at_in(data["grid"], blocked_find["cell"])
		# Reach rule checked first: far from the find refuses for distance, not the seal.
		_rover_at(gs, 1, find_pos + Vector3(30.0, 0.0, 0.0))
		var far_refusal: String = gs.take_find(str(blocked_find["id"]), chosen_day, HOST)
		if not far_refusal.contains("too far"):
			problems.append("Far rover should fail reach before the seal check: '%s'." % far_refusal)
		# In reach while the seal is open: refused for the hissing seal.
		_rover_at(gs, 1, find_pos)
		var open_refusal: String = gs.take_find(str(blocked_find["id"]), chosen_day, HOST)
		if open_refusal != AquiferDepth.SEAL_REFUSAL:
			problems.append("Open seal did not refuse with SEAL_REFUSAL: '%s'." % open_refusal)
		if not ZoneDepth.taken_today(gs.finds_taken, ZONE, chosen_day).is_empty():
			problems.append("Refused find in open-seal room was recorded as taken.")
		# Another room's / landing's find is unaffected by this room's open seal.
		_rover_at(gs, 1, TunnelRock.at_in(data["grid"], free_find["cell"]))
		if gs.take_find(str(free_find["id"]), chosen_day, HOST) != "":
			problems.append("A find outside the open-seal room was refused.")
		# Shut the valve, then take the find in that room.
		_rover_at(gs, 1, AquiferDepth.seal_position(seal))
		if gs.shut_valve(seal_id, chosen_day, HOST) != "":
			problems.append("Shutting the valve at the doorway was refused.")
		_rover_at(gs, 1, find_pos)
		var after_shut: String = gs.take_find(str(blocked_find["id"]), chosen_day, HOST)
		if after_shut != "":
			problems.append("Shut seal still refused its room's find: '%s'." % after_shut)
		if not str(blocked_find["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, chosen_day):
			problems.append("Find was not recorded after shutting the valve.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Every shut_valve refusal ------------------------------------------------------

func test_shut_valve_refuses_wrong_place_far_unknown_already_shut_stale_day_and_guest() -> String:
	var day: int = 6
	var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
	var seal: Dictionary = data["seals"][0]
	var seal_id: String = str(seal["id"])
	var valve_pos: Vector3 = AquiferDepth.seal_position(seal)
	var other_id: String = "s1" if seal_id == "s0" else "s0"
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var run: String = _at(float(day - 1), func() -> String:
		# 1. Wrong place: on the farm, in the dome, in another zone, at hub depth 0, or player at depth 0.
		var on_farm: GameStateScript = _state()
		if on_farm.shut_valve(seal_id, day, HOST) == "":
			problems.append("shut_valve succeeded on the farm.")
		on_farm.free()

		var in_dome: GameStateScript = _state()
		_rover_at(in_dome, 1, valve_pos)
		in_dome.player_places[HOST] = [ZonePresence.DOME, 0]
		if in_dome.shut_valve(seal_id, day, HOST) == "":
			problems.append("shut_valve succeeded from the dome.")
		in_dome.free()

		var in_mine: GameStateScript = _state()
		in_mine.rover_zone = MineDepth.ZONE
		in_mine.rover_lent = true
		in_mine.rover_depth = 1
		in_mine.rover_transforms[in_mine.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, valve_pos)
		in_mine.player_places[HOST] = [MineDepth.ZONE, 1]
		if in_mine.shut_valve(seal_id, day, HOST) == "":
			problems.append("shut_valve succeeded in the Colony Mine.")
		in_mine.free()

		var at_hub: GameStateScript = _state()
		_rover_at(at_hub, 0, valve_pos)
		if at_hub.shut_valve(seal_id, day, HOST) == "":
			problems.append("shut_valve succeeded at depth 0 (the hub).")
		at_hub.free()

		var player_up: GameStateScript = _state()
		_rover_at(player_up, 1, valve_pos)
		player_up.player_places[HOST] = [ZONE, 0]
		if player_up.shut_valve(seal_id, day, HOST) == "":
			problems.append("shut_valve succeeded while player was at depth 0.")
		player_up.free()

		# 2. Far from the valve (beyond VALVE_REACH_M + HOST_REACH_SLACK_M).
		var far: GameStateScript = _state()
		var edge_dist: float = AquiferDepth.VALVE_REACH_M + ZoneDepth.HOST_REACH_SLACK_M + 0.4
		_rover_at(far, 1, valve_pos + Vector3(edge_dist, 0.0, 0.0))
		var far_why: String = far.shut_valve(seal_id, day, HOST)
		if far_why == "" or not far_why.contains("too far"):
			problems.append("shut_valve from %.1f m away said '%s'." % [edge_dist, far_why])
		far.free()

		# 3. Unknown seal (non-existent id and another room's id that is not open today).
		var gs: GameStateScript = _state()
		gs.credits = 123
		gs.crystal_ore = 7
		_rover_at(gs, 1, valve_pos)
		if gs.shut_valve("s9", day, HOST) == "" or gs.shut_valve(other_id, day, HOST) == "":
			problems.append("shut_valve accepted a seal that does not exist today.")

		# 4. Stale layout_day.
		var stale: String = gs.shut_valve(seal_id, day - 1, HOST)
		if stale == "" or not stale.contains("yesterday"):
			problems.append("shut_valve with stale layout_day said '%s'." % stale)

		# 5. Guest calling the host path directly.
		FarmCommands.guest = true
		var guest_call: String = gs.shut_valve(seal_id, day, HOST)
		FarmCommands.guest = false
		if guest_call == "" or not gs.valves_shut.is_empty():
			problems.append("Guest calling host shut_valve was allowed: '%s'." % guest_call)

		# 6. Valid shut_valve: costs nothing, emits pump_changed, records seal_id.
		var heard: Array[int] = [0]
		gs.pump_changed.connect(func() -> void: heard[0] += 1)
		var ok: String = gs.shut_valve(seal_id, day, HOST)
		if ok != "":
			problems.append("Valid shut_valve was refused: '%s'." % ok)
		if gs.credits != 123 or gs.crystal_ore != 7:
			problems.append("shut_valve must cost nothing (credits %d, ore %d)." % [gs.credits, gs.crystal_ore])
		if AquiferDepth.shut_today(gs.valves_shut, day) != [seal_id] or heard[0] != 1:
			problems.append("shut_valve did not record %s or emit once: %s, told %d." % [seal_id, gs.valves_shut, heard[0]])

		# 7. Already shut.
		var twice: String = gs.shut_valve(seal_id, day, HOST)
		if twice == "" or not twice.contains("already") or heard[0] != 1:
			problems.append("Shutting an already-shut valve said '%s' (told %d)." % [twice, heard[0]])
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


# --- valves_shut pruning, save/load, validation, sync, and scene props -------------

func test_valves_shut_is_pruned_saved_validated_and_synced() -> String:
	var day: int = 5
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		gs.valves_shut = ZoneDepth.with_taken(gs.valves_shut, ZONE, day, "s0")
		if AquiferDepth.shut_today(gs.valves_shut, day) != ["s0"] or not AquiferDepth.shut_today(gs.valves_shut, day + 1).is_empty():
			problems.append("shut_today must filter by day.")

		# Save and load round-trip on the same day.
		var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var back: GameStateScript = _state()
		if back.farm_from_dict(data) != "" or AquiferDepth.shut_today(back.valves_shut, day) != ["s0"]:
			problems.append("valves_shut did not round-trip save and load.")
		back.free()

		# Pruned on save when the day has turned.
		GameClock.elapsed_days = float(day)
		var tomorrow_dict: Dictionary = gs.farm_to_dict()
		GameClock.elapsed_days = float(day - 1)
		if not (tomorrow_dict["valves_shut"] as Dictionary).is_empty():
			problems.append("A past day's valves_shut was kept on save: %s." % [tomorrow_dict["valves_shut"]])

		# Pruned on load when the saved record is from an earlier day.
		var stale_save: Dictionary = bytes_to_var(var_to_bytes(data))
		(stale_save["valves_shut"][ZONE] as Dictionary)["day"] = day - 1
		var loaded_stale: GameStateScript = _state()
		if loaded_stale.farm_from_dict(stale_save) != "" or not loaded_stale.valves_shut.is_empty():
			problems.append("A past day's valves_shut was kept on load: %s." % [loaded_stale.valves_shut])
		loaded_stale.free()

		# Old save without valves_shut loads empty.
		var old: Dictionary = gs.farm_to_dict()
		old.erase("valves_shut")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or not fresh.valves_shut.is_empty():
			problems.append("An old save without valves_shut did not load empty.")
		fresh.free()

		# Bad shapes are refused.
		for bad: Variant in [
			3,
			{ "lava_tubes": { "day": day, "ids": ["s0"] } },
			{ ZONE: { "day": day, "ids": ["s0", "s0"] } },
			{ ZONE: { "day": day, "ids": ["s7"] } },
			{ ZONE: { "day": -1, "ids": [] } },
			{ ZONE: { "ids": [] } },
			{ ZONE: { "day": day, "ids": "s0" } },
		]:
			var junk: Dictionary = gs.farm_to_dict()
			junk["valves_shut"] = bad
			if gs.farm_dict_problem(junk) == "":
				problems.append("Bad valves_shut was accepted: %s." % [bad])

		# Late joiner and playing guest receive valves_shut through FarmSync.
		var guest: GameStateScript = _state()
		guest.local_player_id = GUEST
		FarmCommands.guest = true
		if FarmSync.join(FarmSync.capture(gs), guest) != "" or AquiferDepth.shut_today(guest.valves_shut, day) != ["s0"]:
			problems.append("A late-joining guest did not get valves_shut.")
		FarmCommands.guest = false
		gs.valves_shut = ZoneDepth.with_taken(gs.valves_shut, ZONE, day, "s1")
		var heard: Array[int] = [0]
		guest.pump_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var upd: String = FarmSync.update(FarmSync.capture(gs), guest)
		FarmCommands.guest = false
		if upd != "" or AquiferDepth.shut_today(guest.valves_shut, day).size() != 2 or heard[0] < 1:
			problems.append("Playing guest did not sync valves_shut (told %d): '%s'." % [heard[0], upd])
		guest.free()
		gs.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


func test_command_wiring_prefer_seal_and_open_seal_drawing() -> String:
	if not &"shut_valve" in FarmCommands.ACTIONS or not &"shut_valve" in FarmCommands.BELOW_ONLY:
		return "shut_valve must be in FarmCommands.ACTIONS and BELOW_ONLY."
	if not "valves_shut" in (FarmSync.SHOWN_BY.get(&"pump_changed", []) as Array):
		return "valves_shut must be shown by FarmSync."
	if CoopSession.PROTOCOL != 54:
		return "CoopSession.PROTOCOL is %d, not 54." % CoopSession.PROTOCOL

	var day: int = 5
	var layout_open: Dictionary = AquiferDepth.layout(SEED, 1, day)
	var seal: Dictionary = layout_open["seals"][0]
	var seal_id: String = str(seal["id"])
	var room_find_id: String = ""
	for find: Dictionary in layout_open["finds"]:
		if int(find["room"]) == int(seal["room"]):
			room_find_id = str(find["id"])
			break
	if not AquiferDepth.prefer_seal(layout_open, room_find_id, true) or AquiferDepth.prefer_seal(layout_open, room_find_id, false):
		return "prefer_seal should yield to the open seal only when it is in reach."
	var layout_shut: Dictionary = AquiferDepth.layout(SEED, 1, day, [], [seal_id])
	if AquiferDepth.prefer_seal(layout_shut, room_find_id, true):
		return "prefer_seal should not hide a find once the seal is shut."

	# Commander executes shut_valve and rejects bad argument types.
	var cmd_problem: String = ""
	_at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		_rover_at(gs, 1, AquiferDepth.seal_position(seal))
		var commands: Node = CommandsScript.new()
		commands.state = gs
		var wrong: Variant = commands.execute(HOST, &"shut_valve", [3, "bad"])
		var ran: Variant = commands.execute(HOST, &"shut_valve", [seal_id, day])
		if wrong == "" or ran != "" or AquiferDepth.shut_today(gs.valves_shut, day) != [seal_id]:
			cmd_problem = "Commander shut_valve failed: wrong='%s', ran='%s'." % [wrong, ran]
		commands.free()
		gs.free()
		return "")
	if cmd_problem != "":
		return cmd_problem

	# Scene prop check: open seal draws primitive meshes with no colliders, disappears when shut.
	var held_zone: String = ZoneDepth.local_zone
	var held_depth: int = ZoneDepth.local_depth
	var held_layout: Dictionary = ZoneDepth.local_layout
	var held_shut: Dictionary = GameState.valves_shut.duplicate(true)
	ZoneDepth.local_zone = ZONE
	ZoneDepth.local_depth = 1
	ZoneDepth.local_layout = AquiferDepth.layout(SEED, 1, day)
	GameState.valves_shut = {}
	var aq := FloodedAquifer.new()
	aq._built_day = day
	aq._seals = Node3D.new()
	aq._seals.name = "Seals"
	aq.add_child(aq._seals)
	aq._rebuild_seals()
	var open_count: int = aq._seals.get_child_count()
	var collided: bool = _has_collision(aq._seals)
	var has_wheel: bool = aq._seals.find_child("ValveWheel", true, false) != null
	var has_jet: bool = aq._seals.find_child("WaterJet", true, false) != null
	var has_sheet: bool = aq._seals.find_child("SealSheet_" + seal_id, true, false) != null
	GameState.valves_shut = ZoneDepth.with_taken({}, ZONE, day, seal_id)
	aq._rebuild_seals()
	var shut_count: int = aq._seals.get_child_count()
	_free_node(aq)
	GameState.valves_shut = held_shut
	ZoneDepth.local_zone = held_zone
	ZoneDepth.local_depth = held_depth
	ZoneDepth.local_layout = held_layout
	if open_count != 1 or not has_wheel or not has_jet or not has_sheet:
		return "Open seal did not draw wheel, jet and floor sheet (count=%d)." % open_count
	if collided:
		return "Seal props must not add colliders."
	if shut_count != 0:
		return "Shut seal still drew %d node(s)." % shut_count
	return ""


# --- Wet pack and wades_to ---------------------------------------------------------

func test_wades_to_is_true_across_a_shallow_pool_and_false_across_a_drained_one() -> String:
	var spot: Array = _shallow_room_day()
	if spot.is_empty():
		return "No day in 199 had a shallow side-passage pool."
	var day: int = spot[0]
	var pool_id: String = spot[1]
	var room_find: Dictionary = (spot[4] as Array)[0]
	var landing_find: Dictionary = spot[5]

	var full: Dictionary = AquiferDepth.layout(SEED, 1, day)
	var drained: Dictionary = AquiferDepth.layout(SEED, 1, day, [pool_id])
	if not AquiferDepth.wades_to(full, ZoneDepth.START_CELL, room_find["cell"]):
		return "wades_to must be true across undrained shallow pool %s." % pool_id
	if AquiferDepth.wades_to(drained, ZoneDepth.START_CELL, room_find["cell"]):
		return "wades_to must be false once shallow pool %s is drained." % pool_id
	if AquiferDepth.wades_to(full, ZoneDepth.START_CELL, landing_find["cell"]):
		return "wades_to must be false on the dry landing."
	# Deep pool p0 blocks reach altogether, so wades_to is false until drained (and false when drained).
	for find: Dictionary in full["finds"]:
		if int(find["room"]) == 2:
			if AquiferDepth.wades_to(full, ZoneDepth.START_CELL, find["cell"]):
				return "wades_to must be false when deep water blocks the room."
			var p0_dry: Dictionary = AquiferDepth.layout(SEED, 1, day, ["p0"])
			if AquiferDepth.wades_to(p0_dry, ZoneDepth.START_CELL, find["cell"]):
				return "wades_to must be false across drained deep pool p0."
			break
	return ""


func test_a_wading_take_spoils_one_ration_once_per_day_and_none_when_drained_or_empty() -> String:
	var spot: Array = _shallow_room_day()
	if spot.is_empty():
		return "No shallow pool day found."
	var day: int = spot[0]
	var pool_id: String = spot[1]
	var seal_id: String = spot[3]
	var room_finds: Array = spot[4]
	var f0: Dictionary = room_finds[0]
	var f1: Dictionary = room_finds[1]
	var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
	var problems: Array[String] = []

	var run: String = _at(float(day - 1), func() -> String:
		# Case 1: camp rations held -> first wet take spoils one, second wet take spoils nothing.
		var gs: GameStateScript = _state()
		gs.camp_supplies = 2
		gs.valves_shut = ZoneDepth.with_taken(gs.valves_shut, ZONE, day, seal_id)
		var camps_heard: Array[int] = [0]
		gs.camps_changed.connect(func() -> void: camps_heard[0] += 1)
		_rover_at(gs, 1, TunnelRock.at_in(data["grid"], f0["cell"]))
		var first_reply: String = gs.take_find(str(f0["id"]), day, HOST)
		if first_reply != AquiferDepth.WET_PACK_SPOILED_TEXT:
			problems.append("First wading take with rations said '%s'." % first_reply)
		if gs.camp_supplies != 1 or camps_heard[0] != 1 or int(gs.packs_wet.get(HOST, -1)) != day:
			problems.append("Expected 1 ration left and packs_wet[%s]=%d: got %d rations, %s." % [HOST, day, gs.camp_supplies, gs.packs_wet])
		if not str(f0["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day):
			problems.append("Wading find f0 was not recorded as taken.")

		_rover_at(gs, 1, TunnelRock.at_in(data["grid"], f1["cell"]))
		var second_reply: String = gs.take_find(str(f1["id"]), day, HOST)
		if second_reply != "" or gs.camp_supplies != 1 or camps_heard[0] != 1:
			problems.append("Second wading take on same day spoiled again or spoke: '%s', rations=%d." % [second_reply, gs.camp_supplies])
		gs.free()

		# Case 2: no rations held -> says pack got wet, spoils nothing, and marks pack wet for today.
		var empty: GameStateScript = _state()
		empty.camp_supplies = 0
		empty.valves_shut = ZoneDepth.with_taken(empty.valves_shut, ZONE, day, seal_id)
		_rover_at(empty, 1, TunnelRock.at_in(data["grid"], f0["cell"]))
		var dry_wallet_reply: String = empty.take_find(str(f0["id"]), day, HOST)
		if dry_wallet_reply != AquiferDepth.WET_PACK_TEXT or empty.camp_supplies != 0:
			problems.append("Wading take with 0 rations said '%s' (rations=%d)." % [dry_wallet_reply, empty.camp_supplies])
		empty.camp_supplies = 2
		_rover_at(empty, 1, TunnelRock.at_in(data["grid"], f1["cell"]))
		var after_buy: String = empty.take_find(str(f1["id"]), day, HOST)
		if after_buy != "" or empty.camp_supplies != 2:
			problems.append("Already-wet player spoiled a ration bought later the same day: '%s', rations=%d." % [after_buy, empty.camp_supplies])
		empty.free()

		# Case 3: a second player has their own pack and can spoil one ration on their first wet take.
		var coop: GameStateScript = _state()
		coop.camp_supplies = 2
		coop.valves_shut = ZoneDepth.with_taken(coop.valves_shut, ZONE, day, seal_id)
		_rover_at(coop, 1, TunnelRock.at_in(data["grid"], f0["cell"]), HOST)
		coop.take_find(str(f0["id"]), day, HOST)
		_rover_at(coop, 1, TunnelRock.at_in(data["grid"], f1["cell"]), GUEST)
		var guest_reply: String = coop.take_find(str(f1["id"]), day, GUEST)
		if guest_reply != AquiferDepth.WET_PACK_SPOILED_TEXT or coop.camp_supplies != 0:
			problems.append("Guest's first wet take did not spoil one ration: '%s', rations=%d." % [guest_reply, coop.camp_supplies])
		coop.free()

		# Case 4: draining the shallow pool with the pump prevents wading and spoils nothing.
		var pumped: GameStateScript = _state()
		pumped.camp_supplies = 2
		pumped.valves_shut = ZoneDepth.with_taken(pumped.valves_shut, ZONE, day, seal_id)
		pumped.pools_drained = ZoneDepth.with_taken(pumped.pools_drained, ZONE, day, pool_id)
		_rover_at(pumped, 1, TunnelRock.at_in(data["grid"], f0["cell"]))
		var pumped_reply: String = pumped.take_find(str(f0["id"]), day, HOST)
		if pumped_reply != "" or pumped.camp_supplies != 2 or not pumped.packs_wet.is_empty():
			problems.append("Drained pool still wet the pack: '%s', rations=%d, packs_wet=%s." % [pumped_reply, pumped.camp_supplies, pumped.packs_wet])
		pumped.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_packs_wet_round_trips_save_and_load_prunes_and_refuses_bad_shapes() -> String:
	var spot: Array = _shallow_room_day()
	if spot.is_empty():
		return "No shallow pool day found."
	var day: int = spot[0]
	var seal_id: String = spot[3]
	var room_finds: Array = spot[4]
	var f0: Dictionary = room_finds[0]
	var f1: Dictionary = room_finds[1]
	var data: Dictionary = AquiferDepth.layout(SEED, 1, day)
	var problems: Array[String] = []

	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		gs.camp_supplies = 3
		gs.valves_shut = ZoneDepth.with_taken(gs.valves_shut, ZONE, day, seal_id)
		_rover_at(gs, 1, TunnelRock.at_in(data["grid"], f0["cell"]))
		if gs.take_find(str(f0["id"]), day, HOST) != AquiferDepth.WET_PACK_SPOILED_TEXT or gs.camp_supplies != 2:
			problems.append("Initial wet take did not spoil one ration.")

		# Save and reload on the same day: a second wet take must NOT spoil again.
		var saved: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var reloaded: GameStateScript = _state()
		if reloaded.farm_from_dict(saved) != "" or reloaded.packs_wet != { HOST: day }:
			problems.append("packs_wet did not round-trip save and load: %s." % [reloaded.packs_wet])
		_rover_at(reloaded, 1, TunnelRock.at_in(data["grid"], f1["cell"]))
		var post_load: String = reloaded.take_find(str(f1["id"]), day, HOST)
		if post_load != "" or reloaded.camp_supplies != 2:
			problems.append("Reloading on the same day spoiled a second ration: '%s', rations=%d." % [post_load, reloaded.camp_supplies])
		reloaded.free()

		# Pruned on save and on load when the day advances.
		GameClock.elapsed_days = float(day)
		var next_day_save: Dictionary = gs.farm_to_dict()
		if not (next_day_save["packs_wet"] as Dictionary).is_empty():
			problems.append("packs_wet was not pruned on tomorrow's save: %s." % [next_day_save["packs_wet"]])
		var stale_load: GameStateScript = _state()
		if stale_load.farm_from_dict(saved) != "" or not stale_load.packs_wet.is_empty():
			problems.append("packs_wet was not pruned on tomorrow's load: %s." % [stale_load.packs_wet])
		stale_load.free()
		GameClock.elapsed_days = float(day - 1)

		# Old save without packs_wet loads empty.
		var old: Dictionary = gs.farm_to_dict()
		old.erase("packs_wet")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or not fresh.packs_wet.is_empty():
			problems.append("An old save without packs_wet did not load empty.")
		fresh.free()

		# Bad shapes are refused.
		for bad: Variant in [3, { "": day }, { HOST: -1 }, { HOST: "today" }, { 7: day }]:
			var junk: Dictionary = gs.farm_to_dict()
			junk["packs_wet"] = bad
			if gs.farm_dict_problem(junk) == "":
				problems.append("Bad packs_wet was accepted: %s." % [bad])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)
