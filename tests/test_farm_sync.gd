extends RefCounted
## The host's farm reaches a guest whole, and the guest only shows it.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const PATH: String = "user://test_farm_sync.save"
## Saved variables no signal shows: bookkeeping, or shown only when asked.
const NO_SIGNAL: Array[String] = [
	"clean_audit_streak", "_next_certificate_number",
	"offence_counts", "_drop_pod_departure_at", "audit_grace_used", "_cal_index_at_last_audit",
	"_dispatch_deck", "rover_transforms", "_next_job_number", "_board_band", "_board_taken",
	"seed_crop_id", "planting_offset_steps", "rover_uplinks", "next_player_number", "guest_ids",
]
## Saved variables _show_changes() or _show_news() shows.
const NEWS: Array[String] = ["cal_log", "phone_log", "phone_count", "audit_log", "tilled_cells", "player_skill_xp", "farm_skill_xp"]


func _make_state(seed_value: int = 424242) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	gs.credits = 100000
	gs.crystal_ore = 50
	gs.tier1_unlocked = true
	gs.reset_credibility()
	gs.credibility = 60
	return gs


## Plays mornings so every kind of state has something in it.
func _play(gs: GameStateScript, from_day: int, days: int) -> void:
	for day: int in range(from_day, from_day + days):
		GameClock.elapsed_days = float(day)
		gs._on_time_advanced(1.0)
		gs._on_day_started(GameClock.get_day_index())
		gs._on_day_started_regrow()
		gs._tick_molt(0.001)
		gs.calibrate(gs.unit_ids()[day % gs.unit_ids().size()])
		gs.add_tire_usage(1000.0 / 3.0)
		var cell := Vector3i(day, 0, -day)
		if gs.till(cell):
			gs.plant_crop(cell)
		if not gs.job_board.is_empty():
			gs.accept_job(0)


func _worn() -> GameStateScript:
	var gs: GameStateScript = _make_state()
	gs.buy_standard("reference_gauge")
	gs.park_rover("rover_1", Transform3D(Basis(Vector3.UP, 0.1 + 0.2), Vector3(1.1, 2.2, 3.3)))
	gs.mined_fissures[&"FissureA"] = 2
	gs.dig(Vector3i(20, 0, 20))
	gs._spool_species.append(&"curlyhair")
	gs._spool_damaged.append(true)
	gs.slotted_spool_damaged = true
	gs.optical_silk_spools = 1
	_play(gs, 1, 6)
	return gs


func _differs(a: Dictionary, b: Dictionary, when: String) -> String:
	for key: Variant in a:
		if var_to_bytes(a[key]) != var_to_bytes(b.get(key)):
			return "'%s' differs %s: %s vs %s" % [key, when, a[key], b.get(key)]
	return ""


## Runs `body` as a guest and puts the clock, the guest flag and the save back.
func _as_guest(body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var host: GameStateScript = _worn()
	var guest: GameStateScript = _make_state(7)
	var bytes: PackedByteArray = FarmSync.capture(host)
	FarmCommands.guest = true
	var problem: String = body.call(host, guest, bytes)
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	host.free()
	guest.free()
	return problem


## Counts what `gs` emits, by signal name. Its sensors' are not counted.
func _count(gs: GameStateScript) -> Dictionary:
	var counts: Dictionary = {}
	for sig: Dictionary in GameStateScript.get_script_signal_list():
		var name: String = sig["name"]
		var add: Callable = func() -> void: counts[name] = counts.get(name, 0) + 1
		gs.connect(name, add.unbind(sig["args"].size()) if sig["args"].size() > 0 else add)
	return counts


func test_every_saved_variable_has_a_signal_or_is_named_as_without() -> String:
	var shown: Array = NO_SIGNAL + NEWS
	for fields: Array in FarmSync.SHOWN_BY.values():
		shown += fields
	var gs: GameStateScript = GameStateScript.new()
	var saved: Array[String] = gs.SAVED_FIELDS + gs.SAVED_LATER
	gs.free()
	for field: String in saved:
		if shown.count(field) != 1:
			return "'%s' must be in exactly one of SHOWN_BY, NEWS and NO_SIGNAL." % field
	return "" if shown.size() == saved.size() else "A listed variable is not saved."


func test_guest_has_the_hosts_farm_after_join_and_update() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		var id: String = guest.local_player_id
		guest.local_player_id = "guest_2"
		var problem: String = FarmSync.join(bytes, guest)
		problem += _differs(host.farm_to_dict(), guest.farm_to_dict(), "after joining")
		FarmCommands.guest = false
		_play(host, 7, 5)
		bytes = FarmSync.capture(host)
		FarmCommands.guest = true
		problem += FarmSync.update(bytes, guest)
		problem += _differs(host.farm_to_dict(), guest.farm_to_dict(), "after an update")
		if problem == "" and (host.certificates != guest.certificates or host.last_cal_records != guest.last_cal_records):
			problem = "Certificates and last records must match the host's."
		if problem == "" and not is_equal_approx(GameClock.elapsed_days, 11.0):
			problem = "The guest must be on the host's day."
		if problem == "" and (guest.local_player_id != "guest_2" or id == "guest_2"):
			problem = "The guest's own player id must stay."
		return problem)


func test_relay_renewed_certificate_matches_the_hosts() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, _bytes: PackedByteArray) -> String:
		for id: String in host.all_standard_ids():
			if not host.sensors[id].relay_disciplined:
				continue
			host.owned_standards[id] = 1
			host.certificate_log.append({ "id": "OIRM-0099", "standard_id": id, "day": 0, "due_day": 1, "as_found": null,
				"as_found_in_tolerance": true, "expanded_uncertainty": 0.1, "k": 2.0 })
			host.sensors[id].cal_due_day = 9
			host.certificates[id] = host.certificate_log[-1].duplicate()
			host.certificates[id]["due_day"] = 9
			var renewed: PackedByteArray = FarmSync.capture(host)
			var problem: String = FarmSync.join(renewed, guest)
			if problem == "" and guest.certificates != host.certificates:
				problem = "A renewed certificate must reach a guest who joins."
			problem += FarmSync.update(renewed, guest)
			if problem == "" and guest.certificates != host.certificates:
				problem = "A renewed certificate must reach a guest who plays."
			return problem
		return "The data must have a relay-locked standard.")


func test_update_shows_only_what_changed_and_news_once() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		FarmSync.join(bytes, guest)
		var counts: Dictionary = _count(guest)
		var problem: String = FarmSync.update(bytes, guest)
		if not counts.is_empty():
			return "The same farm must show nothing, not %s." % counts
		host.credits += 5
		host.post_phone("HELLO")
		host.tilled_cells[Vector3i(99, 0, 99)] = true
		host.audit_log.append({ "passed": true })
		bytes = FarmSync.capture(host)
		problem += FarmSync.update(bytes, guest)
		problem += FarmSync.update(bytes, guest)
		var want: Dictionary = { "credits_changed": 1, "phone_message": 1, "soil_tilled": 1, "audit_completed": 1 }
		if problem == "" and counts != want:
			problem = "Expected %s, got %s." % [want, counts]
		return problem)


## An open bench redraws the selected job's standard on oirm_changed.
func test_lost_traceability_is_shown() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		FarmSync.join(bytes, guest)
		host._untraceable_since_cal["working_standard"] = true
		var counts: Dictionary = _count(guest)
		var problem: String = FarmSync.update(FarmSync.capture(host), guest)
		if problem != "" or counts != { "oirm_changed": 1 }:
			return "Expected one oirm_changed, got %s %s" % [problem, counts]
		return "")


func test_news_keeps_the_hosts_order_and_repeats() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, _bytes: PackedByteArray) -> String:
		for i: int in host.PHONE_LOG_MAX:
			host.post_phone("SAME")
		var problem: String = FarmSync.join(FarmSync.capture(host), guest)
		var shown: Array = []
		guest.phone_message.connect(func(line: String) -> void: shown.append(line))
		guest.audit_completed.connect(func(_report: Dictionary) -> void: shown.append("AUDIT"))
		host.post_phone("SAME")
		host.audit_log.append({ "phone_count": host.phone_count })
		host.post_phone("CANCELLED")
		problem += FarmSync.update(FarmSync.capture(host), guest)
		if problem == "" and shown != ["SAME", "AUDIT", "CANCELLED"]:
			return "Got %s." % [shown]
		for i: int in host.PHONE_LOG_MAX + 5:
			host.post_phone("MANY")
		shown.clear()
		problem += FarmSync.update(FarmSync.capture(host), guest)
		return problem if problem != "" or shown.size() == host.PHONE_LOG_MAX else "Only the kept lines can be shown, got %d." % shown.size())


func test_a_guest_keeps_its_own_planting_choices() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		host.seed_crop_id = "hosts"
		host.planting_offset_steps = 2
		bytes = FarmSync.capture(host)
		var problem: String = FarmSync.join(bytes, guest)
		if problem == "" and (guest.seed_crop_id != "hosts" or guest.planting_offset_steps != 2):
			return "The host's choices must start the guest's."
		guest.seed_crop_id = "mine"
		guest.planting_offset_steps = -3
		problem += FarmSync.update(bytes, guest)
		if problem == "" and (guest.seed_crop_id != "mine" or guest.planting_offset_steps != -3):
			return "A guest's own choices must stay."
		return problem)


func test_bad_bytes_change_nothing() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		var whole: Dictionary = { "clock": FarmSync.clock(), "farm": host.farm_to_dict() }
		var bad: Dictionary = { "nothing": PackedByteArray(), "cut off": bytes.slice(0, bytes.size() - 1) }
		var flipped: PackedByteArray = bytes.duplicate()
		flipped[500] ^= 1
		bad["damaged"] = flipped
		var big := PackedByteArray()
		big.resize(FarmSync.MAX_BYTES + 1)
		bad["too big"] = big
		for field: String in ["credits", "robots", "sensors", "world_seed"]:
			var data: Dictionary = whole.duplicate(true)
			data["farm"][field] = "no"
			bad[field] = SaveGame.to_bytes(data)
		for report: Dictionary in [{ "lines": [{ "violation": true }] }, { "lines": 3 }, { "interlocks": [{}] },
				{ "total_fine": "no" }, { "tire_check": 1 }]:
			var data: Dictionary = whole.duplicate(true)
			data["farm"]["audit_log"].append(report)
			bad[str(report)] = SaveGame.to_bytes(data)
		for plants: Dictionary in [{ Vector3i.ZERO: {} }, { Vector3i.ZERO: 1 }, { "here": { "crop_id": "x", "days_grown": 0, "out_of_band_days": 0, "setpoint": 0.2 } },
				{ Vector3i.ZERO: { "crop_id": "x", "days_grown": "no", "out_of_band_days": 0, "setpoint": 0.2 } }]:
			var data: Dictionary = whole.duplicate(true)
			data["farm"]["plantings"] = plants
			bad[str(plants)] = SaveGame.to_bytes(data)
		for values: Array in [["player_skill_xp", { 2: { "farming": 1 } }], ["player_skill_xp", { "player_2": { 3: 1 } }], ["farm_skill_xp", { 3: 1 }],
				["guest_ids", { 3: "player_2" }], ["guest_ids", { "a": 2 }], ["guest_ids", { "a": "player_1" }], ["guest_ids", { "a": "player_99" }], ["guest_ids", { "a": "me" }],
				["at_oirm", { "x": [] }], ["suspect_units", { "x": [] }], ["mined_fissures", { "x": [] }], ["lab_areas", { "x": [] }],
				["offence_counts", { "x": [] }], ["rover_uplinks", { "x": [] }], ["rover_transforms", { "x": [] }], ["tilled_cells", { "here": true }],
				["lab_build", { "kind": [] }], ["lab_build", { "kind": "grow", "size": [] }], ["lab_build", { "kind": "grow", "done_day": [] }],
				["lab_build", { "kind": "refit", "discipline": [] }], ["owned_standards", { 3: true }], ["_untraceable_since_cal", { 3: true }],
				["dug", { Vector2i(20, 20): 2 }], ["dug", { Vector2i(0, 0): 1 }], ["dug", { Vector2i(20, 20): "1" }], ["dug", { 3: 1 }], ["dug", []]]:
			var data: Dictionary = whole.duplicate(true)
			data["farm"][values[0]] = values[1]
			bad[str(values)] = SaveGame.to_bytes(data)
		var odd_sensor: Dictionary = whole.duplicate(true)
		odd_sensor["farm"]["sensors"][[]] = 1
		bad["sensor key"] = SaveGame.to_bytes(odd_sensor)
		for target: Array in [[GameStateScript.JOB_WATER, []], [GameStateScript.JOB_COLLECT, []], [GameStateScript.JOB_CALIBRATE, []]]:
			var card: Dictionary = { "trigger": GameStateScript.CARD_TRIGGERS[target[0]][0], "job": target[0], "hour": 6, "every_days": 1,
				"last_day": 0, "added_by": "x", "target": "x" }
			if not GameStateScript._is_card(card):
				return "A whole card must load: %s" % card
			card["target"] = target[1]
			if GameStateScript._is_card(card):
				return "A card with a bad target must be refused: %s" % card
		for wrong: Array in [["job_board", {}, ["pay", "min_tier", "due_in_days", "discipline"]],
				["active_jobs", { "job_id": "JOB-0001", "due_day": 1 }, ["pay", "min_tier", "bench_minutes", "item"]],
				["harvest_bin", { "crop_id": "x" }, ["advance"]],
				["certificate_log", { "id": "x", "standard_id": "x", "day": 1, "due_day": 1, "expanded_uncertainty": 1.0, "k": 2.0,
					"as_found": null, "as_found_in_tolerance": true }, ["issuer"]]]:
			var good: Dictionary = whole.duplicate(true)
			good["farm"][wrong[0]].append(wrong[1])
			if host.farm_dict_problem(good["farm"]) != "":
				return "%s without its optional fields must load: %s" % [wrong[0], host.farm_dict_problem(good["farm"])]
			for field: String in wrong[2]:
				var data: Dictionary = good.duplicate(true)
				data["farm"][wrong[0]][-1][field] = []
				bad["%s %s" % [wrong[0], field]] = SaveGame.to_bytes(data)
		for list: String in ["active_jobs", "oirm_trips", "harvest_bin", "cal_log", "certificate_log"]:
			var data: Dictionary = whole.duplicate(true)
			data["farm"][list].append({ "instrument_id": "x", "standard_id": "x" })
			bad[list] = SaveGame.to_bytes(data)
		var record: Dictionary = host.calibrate_at_bench(GameStateScript.HYGROMETER_ID, host.local_player_id)
		for field: String in ["", "as_found_in_tolerance", "result", "day"]:
			var data: Dictionary = whole.duplicate(true)
			data["farm"]["cal_log"].append(record.duplicate())
			data["farm"]["cal_log"][-1].erase(field)
			if field != "":
				bad["cal_log without " + field] = SaveGame.to_bytes(data)
			elif host.farm_dict_problem(data["farm"]) != "":
				return "A whole record must load: %s" % host.farm_dict_problem(data["farm"])
		for clock: Array in [["elapsed_days", NAN], ["elapsed_days", -1.0], ["seconds_per_day", INF], ["paused", 1]]:
			var data: Dictionary = whole.duplicate(true)
			data["clock"][clock[0]] = clock[1]
			bad[str(clock)] = SaveGame.to_bytes(data)
		var before: Dictionary = guest.farm_to_dict()
		var day: float = GameClock.elapsed_days
		SaveGame.farm_open = true
		var counts: Dictionary = _count(guest)
		for what: String in bad:
			for take: Callable in [FarmSync.join, FarmSync.update]:
				if take.call(bad[what], guest) == "":
					return "%s must be refused." % what
		if not counts.is_empty() or GameClock.elapsed_days != day or not SaveGame.farm_open:
			return "A refused farm must change nothing."
		return _differs(before, guest.farm_to_dict(), "after refusals"))


func test_host_and_solo_take_no_farm() -> String:
	return _as_guest(func(_host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		FarmCommands.guest = false
		var before: Dictionary = guest.farm_to_dict()
		for take: Callable in [FarmSync.join, FarmSync.update]:
			if take.call(bytes, guest) == "":
				return "Only a guest may take a farm."
		if FarmSync.follow_clock(FarmSync.clock()) == "":
			return "Only a guest may follow a clock."
		return _differs(before, guest.farm_to_dict(), "on a host"))


func test_guest_never_writes_a_save() -> String:
	var write_first: String = SaveGame._write_data({ "mine": 1 }, PATH)
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var default_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveGame.DEFAULT_PATH) if FileAccess.file_exists(SaveGame.DEFAULT_PATH) else PackedByteArray()
	var problem: String = _as_guest(func(_host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		SaveGame.farm_open = true
		var got: String = FarmSync.join(bytes, guest) + FarmSync.update(bytes, guest)
		if SaveGame.farm_open:
			return "Joining must close the guest's own farm."
		SaveGame.farm_open = true
		SaveGame._autosave()
		return got if SaveGame.write(PATH) != "" else "A guest must not save.")
	if problem == "" and (write_first != "" or FileAccess.get_file_as_bytes(PATH) != file_before):
		problem = "The save file must not change."
	var default_after: PackedByteArray = FileAccess.get_file_as_bytes(SaveGame.DEFAULT_PATH) if FileAccess.file_exists(SaveGame.DEFAULT_PATH) else PackedByteArray()
	if problem == "" and default_after != default_before:
		problem = "The player's save must not change."
	DirAccess.remove_absolute(PATH)
	return problem


func test_guest_clock_shows_time_and_runs_nothing() -> String:
	return _as_guest(func(_host: GameStateScript, _guest: GameStateScript, _bytes: PackedByteArray) -> String:
		var ran: Array = []
		var note: Callable = func(_value: float) -> void: ran.append("time")
		var note_day: Callable = func(_day: int) -> void: ran.append("day")
		GameClock.time_advanced.connect(note)
		GameClock.clock_ran.connect(note)
		GameClock.day_started.connect(note_day)
		var problem: String = _clock_story()
		GameClock.time_advanced.disconnect(note)
		GameClock.clock_ran.disconnect(note)
		GameClock.day_started.disconnect(note_day)
		return problem if problem != "" or ran.is_empty() else "A guest's clock must emit nothing.")


func _clock_story() -> String:
	GameClock.elapsed_days = 3.5
	GameClock.follow(3.5, 720.0, false)
	GameClock.paused = true  # the guest's own pause does not stop the host
	GameClock._process(1.0)
	if not is_equal_approx(GameClock.elapsed_days, 3.5 + 1.0 / 720.0):
		return "Time must run between updates."
	var shown: float = GameClock.elapsed_days
	GameClock.follow(3.5005, 720.0, false)
	GameClock._process(0.1)
	if GameClock.elapsed_days != shown:
		return "A guest a little ahead must wait, not go back."
	GameClock._process(2.0)
	if GameClock.elapsed_days <= shown:
		return "It must go on once the host has caught up."
	GameClock._process(600.0)
	if GameClock.elapsed_days > 3.5005 + GameClock.MAX_AHEAD_DAYS + 0.000001:
		return "It must stop when the host goes quiet."
	GameClock.follow(3.999, 720.0, false)
	GameClock._process(600.0)
	if GameClock.get_day_index() != 4:
		return "Only the host starts a day."
	GameClock.follow(4.0, 720.0, true)
	GameClock._process(60.0)
	if GameClock.elapsed_days != 4.0:
		return "A paused host's clock must stand still."
	GameClock.follow(4.25, 720.0, false)
	GameClock._process(2.0)
	GameClock.follow(4.25, 720.0, true)
	if GameClock.elapsed_days != 4.25:
		return "A paused host's time is exact."
	GameClock.follow(1.0, 720.0, true)
	GameClock.follow(4.0, 720.0, true)
	GameClock.advance(1.0)
	GameClock.skip_to_next_morning()
	if GameClock.elapsed_days != 4.0:
		return "A guest can't move time."
	GameClock.follow(1.25, 720.0, false)
	return "" if GameClock.elapsed_days == 1.25 else "A host far behind must be followed back."


func test_guests_rover_changes_nothing() -> String:
	return _as_guest(func(_host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		var problem: String = FarmSync.join(bytes, guest)
		var before: Dictionary = guest.farm_to_dict()
		guest.add_rover_usage(500.0)
		guest.set_rover_uplink("rover_1", false)
		guest.set_rover_uplink("rover_1", true)
		guest.park_rover("rover_1", Transform3D.IDENTITY)
		return problem + _differs(before, guest.farm_to_dict(), "after the guest's rover drove"))


func test_a_guest_sees_digging_and_old_farms_load_without_it() -> String:
	return _as_guest(func(host: GameStateScript, guest: GameStateScript, bytes: PackedByteArray) -> String:
		if FarmSync.join(bytes, guest) != "" or guest.dug != host.dug or guest.dug.size() != 1:
			return "A guest must have the host's digging."
		var counts: Dictionary = _count(guest)
		host.dig(Vector3i(21, 0, 20))
		host.dig(Vector3i(-30, 0, 5))
		host.fill(Vector3i(20, 0, 20))
		if FarmSync.update(FarmSync.capture(host), guest) != "" or guest.dug != host.dug or guest.dug.size() != 2:
			return "A guest must get what was dug since."
		if counts.get("terrain_changed", 0) != 1:
			return "A guest must be told once that the ground changed."
		guest.dug[Vector2i(25, 25)] = 1
		if host.dug.has(Vector2i(25, 25)):
			return "The copies must not be shared."
		var old: Dictionary = host.farm_to_dict()
		old.erase("dug")
		if guest.farm_from_dict(old) != "" or not guest.dug.is_empty() or counts["terrain_changed"] != 2:
			return "A farm from before digging must load with none, and be shown."
		# A dictionary of no type, as another build may have saved it.
		old["dug"] = { Vector2i(20, 20): 1 }
		if guest.farm_from_dict(old) != "" or guest.dug.get(Vector2i(20, 20), 0) != 1:
			return "Digging must load whatever its dictionary's type."
		return "")
