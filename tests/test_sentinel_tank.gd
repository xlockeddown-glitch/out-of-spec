extends RefCounted
## The Cobalt Sentinel's own tank: caught once, molts apart, and gives better silk.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const SENTINEL: String = "cobalt_sentinel"


func _run(body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	GameClock.elapsed_days = 0.0
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.hygrometer.max_error = INF
	gs.hygrometer.error = 0.0
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped before it finished."
	gs.free()
	GameClock.elapsed_days = elapsed
	return problem


func test_it_is_caught_once_and_only_by_the_host() -> String:
	return _run(func(gs: GameStateScript) -> String:
		if gs.is_caught(SENTINEL) or gs.enclosure_text(SENTINEL) != "" or gs.collect_enclosure_spool(SENTINEL):
			return "The tank must start empty."
		FarmCommands.guest = true
		var as_guest: bool = gs.catch_species(SENTINEL)
		FarmCommands.guest = false
		if as_guest or gs.catch_species(String(gs.dome_species_id)) or gs.catch_species("") or not gs.enclosures.is_empty():
			return "A guest, or a species that can't be caught, must not fill it."
		if not gs.catch_species(SENTINEL) or not gs.is_caught(SENTINEL):
			return "The host must be able to catch it."
		gs._tick_molt(0.1)
		var before: float = gs.enclosures[SENTINEL]["molt_progress"]
		if before <= 0.0 or gs.catch_species(SENTINEL) or gs.enclosures[SENTINEL]["molt_progress"] != before:
			return "A second catch must change nothing."
		if FarmCommands.problem(&"catch_species", [SENTINEL]) == "":
			return "No one may ask for a catch."
		return "")


func test_it_molts_apart_and_the_curlyhair_is_as_before() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var alone: GameStateScript = GameStateScript.new()
		alone.build_registry()
		alone.hygrometer.error = 0.0
		gs.catch_species(SENTINEL)
		for state: GameStateScript in [gs, alone]:
			state._tick_molt(state.molt_days() * 0.9)
		var same: bool = gs.molt_progress == alone.molt_progress and gs.molt_stage == alone.molt_stage and gs.molt_text() == alone.molt_text()
		alone.free()
		if not same:
			return "The Curlyhair must molt as it does alone."
		if gs.enclosures[SENTINEL]["molt_stage"] != gs.MoltStage.PRE_MOLT or gs.enclosure_text(SENTINEL) != "PRE-MOLT  90 %":
			return "Got %s" % gs.enclosure_text(SENTINEL)
		gs._tick_molt(gs.molt_days() * 0.2)
		if not gs.is_spool_ready() or not gs.is_enclosure_spool_ready(SENTINEL):
			return "Both must have molted."
		if not gs.collect_enclosure_spool(SENTINEL, "player_1") or gs.collect_enclosure_spool(SENTINEL):
			return "A molt gives one spool."
		if not gs.is_spool_ready() or gs.optical_silk_spools != 1 or gs._spool_species[0] != &"cobalt_sentinel":
			return "The spool must be the Sentinel's, and the Curlyhair's stay."
		if not gs.is_enclosure_exuvia_visible(SENTINEL):
			return "The exuvia must linger."
		gs._tick_molt(gs.molt_days() * 0.5)
		if not is_equal_approx(gs.enclosures[SENTINEL]["molt_progress"], 0.5):
			return "It must molt on while the Curlyhair's spool waits."
		return "")


func test_humidity_holds_it_back_but_never_kills_it() -> String:
	return _run(func(gs: GameStateScript) -> String:
		gs.catch_species(SENTINEL)
		gs.hygrometer.error = gs.hygrometer.mpe * 4.0
		gs._tick_molt(100.0)
		if gs.enclosures[SENTINEL]["molt_progress"] != 0.0 or gs.enclosure_text(SENTINEL) != "MOLT PAUSED: humidity out of range":
			return "Got %s" % gs.enclosure_text(SENTINEL)
		gs.hygrometer.error = 0.0
		gs._tick_molt(gs.molt_days())
		if not gs.is_enclosure_spool_ready(SENTINEL):
			return "It must pick up again."
		# Its own tolerance counts, not the hygrometer's tighter limit.
		gs.hygrometer.error = 8.0
		var within: String = gs.enclosure_pause_reason(SENTINEL)
		gs.hygrometer.error = -8.1
		if within != "" or not gs.is_molt_paused() or gs.enclosure_pause_reason(SENTINEL) != "humidity out of range":
			return "The tank must be within 8 % of its ideal."
		gs.hygrometer.error = 0.0
		var thermometer: DriftingSensor = gs.get_sensor(gs.THERMOMETER_ID)
		thermometer.max_error = INF
		thermometer.error = 3.1
		if gs.enclosure_pause_reason(SENTINEL) != "":
			return "Temperature must not count before the thermometer is in service."
		gs.owned_standards[thermometer.calibrated_by] = true
		var out: String = gs.enclosure_pause_reason(SENTINEL)
		thermometer.error = 3.0
		if out != "temperature out of range" or gs.enclosure_pause_reason(SENTINEL) != "":
			return "The tank must be within 3 degrees of its ideal."
		return "")


func test_a_value_not_set_is_not_zero() -> String:
	return _run(func(gs: GameStateScript) -> String:
		gs.catch_species(SENTINEL)
		if not is_equal_approx(gs.enclosure_humidity(SENTINEL), 80.0):
			return "The tank must sit at its ideal."
		# A species with no ideals yet, as if it were caught.
		gs.enclosures = { "terracotta_knee": gs.enclosures[SENTINEL] }
		gs._tick_molt(1.0)
		if gs.enclosures["terracotta_knee"]["molt_progress"] != 0.0 or gs.enclosure_text("terracotta_knee") != "MOLT PAUSED: humidity not set":
			return "Got %s" % gs.enclosure_text("terracotta_knee")
		if not is_nan(gs.enclosure_humidity_reading("terracotta_knee")):
			return "An ideal not set has no reading."
		return "")


func test_its_silk_cuts_the_lag_to_030_and_may_replace_the_curlyhairs() -> String:
	return _run(func(gs: GameStateScript) -> String:
		var curlyhair: StringName = gs.dome_species_id
		gs._add_spool(curlyhair)
		gs.slot_spool_into_relay()
		gs._add_spool(curlyhair)
		if not is_equal_approx(gs.get_relay_lag_multiplier(), 0.38) or gs.can_slot_spool():
			return "One Curlyhair spool must not replace another."
		gs.catch_species(SENTINEL)
		gs._tick_molt(gs.molt_days() * 1.1)
		gs.collect_enclosure_spool(SENTINEL)
		if not gs.slot_spool_into_relay() or not is_equal_approx(gs.get_relay_lag_multiplier(), 0.30):
			return "Expected 0.30, got %s" % gs.get_relay_lag_multiplier()
		if gs.optical_silk_spools != 2 or gs._spool_species.count(curlyhair) != 2 or gs.can_slot_spool():
			return "The whole Curlyhair spool must go back into stock, and stay there."
		# A robot is built from the plainest spool.
		gs._spool_species.push_front(&"cobalt_sentinel")
		gs._spool_damaged.push_front(false)
		gs.optical_silk_spools += 1
		if gs._take_spool(true)[0] != curlyhair:
			return "The Sentinel's spool must be kept back."
		return "")


func test_the_sentinel_uses_real_cobalt_blue_care_figures() -> String:
	return _run(func(_gs: GameStateScript) -> String:
		var species: Dictionary = DataManager.get_record(GameStateScript.SPECIES_TABLE, StringName(SENTINEL))
		if species.is_empty():
			return "The Sentinel must be in the species data."
		if absf(float(species.get("ideal_temp_c", NAN)) - 25.0) > 0.001 or absf(float(species.get("ideal_humidity_pct", NAN)) - 80.0) > 0.001:
			return "Ideal should be 25 C and 80 % (midpoints of the cited care ranges)."
		if str(species.get("scientific_name", "")) != "Cyriopagopus lividus" or not str(species.get("_source", "")).contains("https://"):
			return "The species must name Cyriopagopus lividus and cite its sources."
		var interval: Array = species.get("molt_interval_real_days_range", [])
		if interval.size() != 2 or float(interval[0]) != 30.0 or float(interval[1]) != 210.0:
			return "The real-world molt interval must be 30 to 210 days (one to seven months)."
		if species.get("molt_days") != null:
			return "No source gives the game's molt days, so it stays unset."
		if species.get("premolt_days") != null:
			return "No source gives a premolt length, so it stays unset."
		return "")
