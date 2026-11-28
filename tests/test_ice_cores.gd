extends RefCounted
## Ice core samples and Vance's "A Core to Certify" (docs/design/zones.md, feat/ice-cores):
## taking a core stores it up to the cold-box cap, sending it to OIRM via host-run
## send_ice_core, certified returns (credits, lab XP, counter, idempotency across reload),
## standard/quest isolation on oirm_trips, Vance's quest A Core to Certify, old-save load,
## and guest sync.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "ice_caves"


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	return gs


## Runs `body` with the global clock at `elapsed` days and restores it.
func _at(elapsed: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


## Drives the farm rover into the Ice Caves hub from the ramp.
func _enter_ice(gs: GameStateScript, who: String = HOST) -> String:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.ICE_PAD)
	return gs.move_rover_ice(true, who)


## Finds the first Ice Caves depth-1 find of `wanted_kind` on `day`, or {}.
func _find_of_kind(day: int, wanted_kind: String) -> Dictionary:
	var data: Dictionary = IceDepth.layout(SEED, 1, day)
	for find: Variant in data.get("finds", []):
		if find is Dictionary and str(find.get("kind", "")) == wanted_kind:
			return { "layout": data, "find": find }
	return {}


## Places the rover and `who` at `find` on Ice Caves depth 1 and calls take_find.
func _take_ice_find(gs: GameStateScript, day: int, wanted_kind: String, who: String = HOST) -> Dictionary:
	var found: Dictionary = _find_of_kind(day, wanted_kind)
	if found.is_empty():
		return {}
	var data: Dictionary = found["layout"]
	var find: Dictionary = found["find"]
	gs.rover_zone = ZONE
	gs.rover_depth = 1
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(data["grid"], find["cell"]))
	gs.player_places[who] = [ZONE, 1]
	var reply: String = gs.take_find(str(find["id"]), day, who)
	return { "reply": reply, "find": find }


## Picks a day >= `start_day` that has at least one find of `wanted_kind`.
func _day_with(wanted_kind: String, start_day: int = 2) -> int:
	for d: int in range(start_day, start_day + 30):
		if not _find_of_kind(d, wanted_kind).is_empty():
			return d
	return -1


## Opens the OIRM account gate on `gs` by granting enough lab XP for oirm_account.
func _open_oirm_gate(gs: GameStateScript) -> void:
	gs.give_lab_xp(50000)


# --- Taking cores, cap, and minerals -------------------------------------------------

func test_taking_a_core_stores_it_in_cold_box_and_pays_nothing() -> String:
	var day: int = _day_with("core", 2)
	if day < 0:
		return "Could not find an Ice Caves day with a core."
	var problems: Array[String] = []
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var credits_before: int = gs.credits
		var ore_before: int = gs.crystal_ore
		var res: Dictionary = _take_ice_find(gs, day, "core", HOST)
		if gs.ice_cores_held != 1:
			problems.append("ice_cores_held is %d, expected 1." % gs.ice_cores_held)
		if gs.credits != credits_before or gs.crystal_ore != ore_before:
			problems.append("Taking a core paid on the spot: credits %d -> %d, ore %d -> %d." % [credits_before, gs.credits, ore_before, gs.crystal_ore])
		if str(res.get("reply", "")) != GameStateScript.ICE_CORE_TAKEN_REPLY:
			problems.append("Unexpected core reply: '%s'." % str(res.get("reply", "")))
		if gs.action_count(GameStateScript.ICE_CORE_TAKEN_COUNT, HOST) != 1:
			problems.append("take_ice_core counter was %d, expected 1." % gs.action_count(GameStateScript.ICE_CORE_TAKEN_COUNT, HOST))
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_at_the_cap_a_core_pays_old_credits_and_says_cold_box_is_full() -> String:
	var day: int = _day_with("core", 2)
	if day < 0:
		return "Could not find an Ice Caves day with a core."
	var problems: Array[String] = []
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		gs.ice_cores_held = GameStateScript.ICE_CORES_CAP
		var credits_before: int = gs.credits
		var expected_pay: int = int(IceDepth.reward("core").get("credits", 0))
		var res: Dictionary = _take_ice_find(gs, day, "core", HOST)
		if gs.ice_cores_held != GameStateScript.ICE_CORES_CAP:
			problems.append("ice_cores_held exceeded cap: %d." % gs.ice_cores_held)
		if gs.credits != credits_before + expected_pay:
			problems.append("At cap, expected +%d CR, got +%d CR." % [expected_pay, gs.credits - credits_before])
		if not str(res.get("reply", "")).to_lower().contains("cold box is full"):
			problems.append("Full-cap reply did not say cold box is full: '%s'." % str(res.get("reply", "")))
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_minerals_and_probes_pay_unchanged() -> String:
	var min_day: int = _day_with("mineral", 2)
	var probe_day: int = _day_with("probe", 2)
	if min_day < 0 or probe_day < 0:
		return "Could not find Ice Caves days with mineral and probe."
	var problems: Array[String] = []
	var run1: String = _at(float(min_day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var credits_before: int = gs.credits
		var ore_before: int = gs.crystal_ore
		var pay: Dictionary = IceDepth.reward("mineral")
		var res: Dictionary = _take_ice_find(gs, min_day, "mineral", HOST)
		if str(res.get("reply", "")) != "":
			problems.append("Mineral returned unexpected reply: '%s'." % str(res.get("reply", "")))
		if gs.ice_cores_held != 0:
			problems.append("Mineral incremented ice_cores_held.")
		if gs.credits != credits_before + int(pay.get("credits", 0)) or gs.crystal_ore != ore_before + int(pay.get("crystal_ore", 0)):
			problems.append("Mineral payout changed.")
		gs.free()
		return "")
	if run1 != "":
		return run1
	var run2: String = _at(float(probe_day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var credits_before: int = gs.credits
		var pay: Dictionary = IceDepth.reward("probe")
		var res: Dictionary = _take_ice_find(gs, probe_day, "probe", HOST)
		if str(res.get("reply", "")) != "":
			problems.append("Probe returned unexpected reply: '%s'." % str(res.get("reply", "")))
		if gs.ice_cores_held != 0 or gs.credits != credits_before + int(pay.get("credits", 0)):
			problems.append("Probe payout changed.")
		gs.free()
		return "")
	return run2 if run2 != "" else "\n".join(problems)


# --- Sending to OIRM and refusals ----------------------------------------------------

func test_send_ice_core_refusals_change_nothing_and_reject_payload_player_id() -> String:
	var problems: Array[String] = []
	var held_state: Node = FarmCommands.state
	var run: String = _at(4.0, func() -> String:
		var gs: GameStateScript = _state()
		FarmCommands.state = gs
		gs.drop_pod_present = true
		_open_oirm_gate(gs)
		gs.credits = 500
		# 1. None held
		var none: Dictionary = gs.send_ice_core(HOST)
		if none.get("ok", false) or gs.credits != 500 or not gs.oirm_trips.is_empty():
			problems.append("send_ice_core succeeded with none held: %s." % [none])
		# 2. Without OIRM account / lab gate
		var low: GameStateScript = _state()
		low.drop_pod_present = true
		low.ice_cores_held = 1
		low.credits = 500
		var gated: Dictionary = low.send_ice_core(HOST)
		if gated.get("ok", false) or low.ice_cores_held != 1 or low.credits != 500 or not low.oirm_trips.is_empty():
			problems.append("send_ice_core bypassed OIRM account gate: %s." % [gated])
		low.free()
		# 3. Without credits
		gs.ice_cores_held = 1
		gs.credits = GameStateScript.ICE_CORE_OIRM_FEE - 1
		var poor: Dictionary = gs.send_ice_core(HOST)
		if poor.get("ok", false) or gs.ice_cores_held != 1 or gs.credits != GameStateScript.ICE_CORE_OIRM_FEE - 1 or not gs.oirm_trips.is_empty():
			problems.append("send_ice_core succeeded without credits or mutated state: %s." % [poor])
		# 4. Guest payload player_id is rejected by FarmCommands (send_ice_core takes 0 client args)
		gs.credits = 500
		var bad_prob: String = FarmCommands.problem(&"send_ice_core", [HOST])
		if bad_prob == "":
			problems.append("FarmCommands accepted a payload player_id for send_ice_core.")
		var bad_exec: Variant = FarmCommands.execute(GUEST, &"send_ice_core", [HOST])
		if not (bad_exec is Dictionary) or bool((bad_exec as Dictionary).get("ok", true)):
			problems.append("FarmCommands.execute accepted a guest payload player_id: %s." % [bad_exec])
		if gs.ice_cores_held != 1 or gs.credits != 500 or not gs.oirm_trips.is_empty():
			problems.append("Rejected payload command mutated state.")
		# 5. Connection player_id with 0 payload args succeeds
		var good_exec: Variant = FarmCommands.execute(GUEST, &"send_ice_core", [])
		if not (good_exec is Dictionary) or not bool((good_exec as Dictionary).get("ok", false)):
			problems.append("Valid FarmCommands.execute(GUEST, send_ice_core, []) failed: %s." % [good_exec])
		if gs.ice_cores_held != 0 or gs.credits != 500 - GameStateScript.ICE_CORE_OIRM_FEE or gs.oirm_trips.size() != 1:
			problems.append("Valid send_ice_core did not deduct core/credits or record trip.")
		gs.free()
		return "")
	FarmCommands.state = held_state
	return run if run != "" else "\n".join(problems)


# --- Standard isolation on oirm_trips ------------------------------------------------

func test_sample_trip_is_ignored_by_standard_code_and_paperwork_quest() -> String:
	var problems: Array[String] = []
	var run: String = _at(4.0, func() -> String:
		var gs: GameStateScript = _state()
		gs.drop_pod_present = true
		_open_oirm_gate(gs)
		gs.ice_cores_held = 1
		gs.credits = 500
		var sent: Dictionary = gs.send_ice_core(HOST)
		if not sent.get("ok", false):
			gs.free()
			return "send_ice_core failed: %s" % [sent]
		var trip: Dictionary = gs.oirm_trips[0]
		if not GameStateScript.is_sample_oirm_trip(trip) or str(trip.get("sample_kind", "")) != GameStateScript.ICE_CORE_SAMPLE_KIND:
			problems.append("Trip was not marked as an ice core sample: %s." % [trip])
		if gs.has_oirm_account():
			problems.append("An ice core sample trip opened an OIRM account.")
		if gs._trip_is_open(0):
			problems.append("_trip_is_open treated a sample trip as an open standard trip.")
		if not gs._excused_units(5).is_empty():
			problems.append("_excused_units treated a sample trip as excusing a unit.")
		if not gs.at_oirm.is_empty():
			problems.append("send_ice_core added an entry to at_oirm.")
		# paperwork_from_orbit's `send` step must not count an ice core trip as a standard trip.
		var paperwork_step: Dictionary = { "check": "count", "log": "oirm_trips", "where": { "not_standard_id": "" }, "ever": true }
		if QuestEngine.check_value(gs, paperwork_step, [HOST]) != 0:
			problems.append("paperwork_from_orbit counted an ice core sample trip as a standard trip.")
		# Ensure a real standard trip IS still counted by paperwork_from_orbit.
		gs.oirm_trips.append({ "standard_id": "rotary_table", "sent_day": 5, "return_day": 10, "courier": false })
		if QuestEngine.check_value(gs, paperwork_step, [HOST]) != 1:
			problems.append("paperwork_from_orbit did not count a standard trip alongside a sample trip.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Certified return and idempotency across reload ----------------------------------

func test_core_return_pays_once_bumps_counter_and_is_idempotent_across_reload() -> String:
	var problems: Array[String] = []
	var run: String = _at(4.0, func() -> String:
		var gs: GameStateScript = _state()
		gs.drop_pod_present = true
		_open_oirm_gate(gs)
		gs.ice_cores_held = 1
		gs.credits = 500
		var sent: Dictionary = gs.send_ice_core(HOST)
		if not sent.get("ok", false):
			gs.free()
			return "send_ice_core failed: %s" % [sent]
		var return_day: int = int(sent["return_day"])
		var credits_after_send: int = gs.credits
		var lab_xp_after_send: int = gs.lab_xp
		# Before return_day: nothing happens
		gs._receive_oirm_returns(return_day - 1)
		if gs.credits != credits_after_send or gs.lab_xp != lab_xp_after_send or gs.action_count(GameStateScript.ICE_CORE_CERTIFIED_COUNT, HOST) != 0:
			problems.append("Core certified before its return_day.")
		# On return_day: pays credits, lab XP, phone line, bumps counter
		var phone_before: int = gs.phone_log.size()
		gs._receive_oirm_returns(return_day)
		if gs.credits != credits_after_send + GameStateScript.ICE_CORE_RETURN_CREDITS:
			problems.append("Return credits wrong: got %d, expected %d." % [gs.credits - credits_after_send, GameStateScript.ICE_CORE_RETURN_CREDITS])
		if gs.lab_xp != lab_xp_after_send + GameStateScript.ICE_CORE_RETURN_LAB_XP:
			problems.append("Return lab XP wrong: got %d, expected %d." % [gs.lab_xp - lab_xp_after_send, GameStateScript.ICE_CORE_RETURN_LAB_XP])
		if gs.action_count(GameStateScript.ICE_CORE_CERTIFIED_COUNT, HOST) != 1:
			problems.append("ice_core_certified counter is %d, expected 1." % gs.action_count(GameStateScript.ICE_CORE_CERTIFIED_COUNT, HOST))
		var got_phone: bool = false
		for i: int in range(phone_before, gs.phone_log.size()):
			if gs.phone_log[i].contains("OIRM:") and gs.phone_log[i].to_lower().contains("certified"):
				got_phone = true
		if not got_phone:
			problems.append("No OIRM certification phone line was posted.")
		# Second call on the same day must not pay again
		gs._receive_oirm_returns(return_day)
		if gs.credits != credits_after_send + GameStateScript.ICE_CORE_RETURN_CREDITS or gs.action_count(GameStateScript.ICE_CORE_CERTIFIED_COUNT, HOST) != 1:
			problems.append("Second _receive_oirm_returns paid twice.")
		# Save and reload, then run morning pass again: still idempotent
		var saved: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var back: GameStateScript = _state()
		var load_err: String = back.farm_from_dict(saved)
		if load_err != "":
			problems.append("Reload failed: %s." % load_err)
		else:
			var credits_reloaded: int = back.credits
			var lab_xp_reloaded: int = back.lab_xp
			back._receive_oirm_returns(return_day)
			back._receive_oirm_returns(return_day + 1)
			if back.credits != credits_reloaded or back.lab_xp != lab_xp_reloaded or back.action_count(GameStateScript.ICE_CORE_CERTIFIED_COUNT, HOST) != 1:
				problems.append("Reloaded farm paid the certified core a second time.")
		back.free()
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Vance's quest: A Core to Certify ------------------------------------------------

func test_a_core_to_certify_offered_after_visit_counts_in_order_and_pays_certificate() -> String:
	var day: int = _day_with("core", 2)
	if day < 0:
		return "Could not find an Ice Caves day with a core."
	var problems: Array[String] = []
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		gs.drop_pod_present = true
		_open_oirm_gate(gs)
		gs.credits = 500
		# Not offered before visiting the Ice Caves
		gs.update_quests([HOST], true)
		if gs.quest_state.has("a_core_to_certify"):
			problems.append("a_core_to_certify was offered before visiting the Ice Caves.")
		# Visit the Ice Caves -> offered on morning look
		var entered: String = _enter_ice(gs, HOST)
		if entered != "":
			gs.free()
			return "Could not enter Ice Caves: %s" % entered
		gs.update_quests([HOST], true)
		if not gs.quest_state.has("a_core_to_certify"):
			gs.free()
			return "a_core_to_certify was not offered after visiting the Ice Caves."
		# NoticeBoard for ice_caves now lists A Core to Certify (not "Vance: [later]")
		var lines: Array[String] = NoticeBoard.lines(QuestEngine.quests(), gs.quest_state, {}, "zone", ZONE)
		if lines.is_empty() or not lines[0].contains("A Core to Certify"):
			problems.append("Ice Caves notice board did not list A Core to Certify: %s." % [lines])
		# Certifying a core BEFORE step 1 (take) must NOT complete step 2 (steps are in order)
		gs.ice_cores_held = 1
		var early_sent: Dictionary = gs.send_ice_core(HOST)
		gs._receive_oirm_returns(int(early_sent["return_day"]))
		gs.update_quests([HOST], false)
		var entry: Dictionary = gs.quest_state["a_core_to_certify"]
		if not (entry["steps_done"] as Array).is_empty() or int(entry["done"]) >= 0:
			problems.append("Certifying before taking completed a step out of order: %s." % [entry])
		# Step 1: take an ice core
		_take_ice_find(gs, day, "core", HOST)
		gs.update_quests([HOST], false)
		entry = gs.quest_state["a_core_to_certify"]
		if not ("take" in (entry["steps_done"] as Array)) or ("certify" in (entry["steps_done"] as Array)):
			problems.append("Step 1 (take) did not complete cleanly: %s." % [entry])
		# Step 2: send and certify an ice core -> finishes quest and pays lab XP + XP certificate
		var lab_xp_before: int = gs.lab_xp
		var certs_before: int = gs.held_xp_certificates(HOST).size()
		var sent: Dictionary = gs.send_ice_core(HOST)
		gs._receive_oirm_returns(int(sent["return_day"]))
		gs.update_quests([HOST], false)
		entry = gs.quest_state["a_core_to_certify"]
		if int(entry["done"]) < 0:
			problems.append("a_core_to_certify did not finish after certifying a core: %s." % [entry])
		if gs.lab_xp != lab_xp_before + GameStateScript.ICE_CORE_RETURN_LAB_XP + 300:
			problems.append("Expected +%d lab XP (return + quest), got +%d." % [GameStateScript.ICE_CORE_RETURN_LAB_XP + 300, gs.lab_xp - lab_xp_before])
		var held_certs: Dictionary = gs.held_xp_certificates(HOST)
		if held_certs.size() != certs_before + 1:
			problems.append("Expected 1 new XP certificate, got %s." % [held_certs])
		else:
			var found_50: bool = false
			for cid: Variant in held_certs:
				if str(cid).begins_with("a_core_to_certify#") and int(held_certs[cid]) == 50:
					found_50 = true
			if not found_50:
				problems.append("Did not find 50 XP certificate from a_core_to_certify: %s." % [held_certs])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Old save, validation, and guest sync --------------------------------------------

func test_old_save_loads_and_guest_receives_ice_cores_held() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var run: String = _at(3.0, func() -> String:
		var host: GameStateScript = _state()
		host.ice_cores_held = 3
		# Old save without ice_cores_held loads as 0
		var old: Dictionary = host.farm_to_dict()
		old.erase("ice_cores_held")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or fresh.ice_cores_held != 0:
			problems.append("Old save without ice_cores_held did not load as 0: %d." % fresh.ice_cores_held)
		fresh.free()
		# Invalid ice_cores_held is refused
		for bad: int in [-1, GameStateScript.ICE_CORES_CAP + 1]:
			var junk: Dictionary = host.farm_to_dict()
			junk["ice_cores_held"] = bad
			if host.farm_dict_problem(junk) == "":
				problems.append("Out-of-range ice_cores_held %d was accepted." % bad)
		# Guest join receives ice_cores_held
		var guest: GameStateScript = _state()
		guest.local_player_id = GUEST
		FarmCommands.guest = true
		var joined: String = FarmSync.join(FarmSync.capture(host), guest)
		if joined != "" or guest.ice_cores_held != 3:
			problems.append("Guest join did not receive ice_cores_held=3: '%s', got %d." % [joined, guest.ice_cores_held])
		# Guest update receives changed ice_cores_held and emits oirm_changed
		FarmCommands.guest = false
		host.ice_cores_held = 4
		var heard: Array[int] = [0]
		guest.oirm_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var updated: String = FarmSync.update(FarmSync.capture(host), guest)
		FarmCommands.guest = false
		if updated != "" or guest.ice_cores_held != 4 or heard[0] < 1:
			problems.append("Guest update did not sync ice_cores_held=4: '%s', got %d, heard %d." % [updated, guest.ice_cores_held, heard[0]])
		host.free()
		guest.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


func test_protocol_is_46_and_command_is_registered() -> String:
	if CoopSession.PROTOCOL != 46:
		return "CoopSession.PROTOCOL is %d, expected 46." % CoopSession.PROTOCOL
	if not &"send_ice_core" in FarmCommands.ACTIONS:
		return "send_ice_core is not in FarmCommands.ACTIONS."
	if not "ice_cores_held" in GameStateScript.SAVED_LATER:
		return "ice_cores_held is not in GameState.SAVED_LATER."
	return ""
