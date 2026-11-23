extends RefCounted
## Co-op groundwork (Ryan, 2026-11-22: co-op groundwork overnight): every
## DriftingSensor saves its live state as plain data and restores it exactly,
## including where its random rolls continue. Every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state(seed_value: int) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	return gs


## Drift, use and zero every sensor so its state is far from fresh.
func _wear(gs: GameStateScript) -> void:
	for id: String in gs.sensors:
		var sensor: DriftingSensor = gs.get_sensor(id)
		sensor.advance_days(2.5)
		sensor.add_usage(40.0)
		sensor.zero(sensor.mpe * 0.1)
		sensor.advance_days(1.0)
		sensor.cal_interval_days = 7
		sensor.cal_due_day = 11
		sensor.last_cal_day = 4
		sensor.error += 0.123456789012345678 * sensor.mpe
	# What purchases change on a sensor: take-over standard and wide treads.
	gs.get_sensor("dome_pressure").calibrated_by = "reference_gauge_test"
	gs.steering.usage_drift_rate *= 0.5


## Floats may lose their last few bits through Godot's JSON even at full
## precision, so saved values compare to 1 part in 1e14. Results computed from
## them add rounding, so `slack` allows for it.
## The rest compares exactly.
func _same(a: Variant, b: Variant, slack: float = 0.0) -> bool:
	if typeof(a) != typeof(b):
		return false
	if typeof(a) == TYPE_FLOAT:
		return absf(a - b) <= slack + 1e-14 * maxf(absf(a), absf(b))
	return a == b


func test_round_trip_through_json_matches_every_sensor() -> String:
	var source: GameStateScript = _make_state(424242)
	_wear(source)
	# Full precision, as to_dict() asks (the default keeps fewer digits).
	var text: String = JSON.stringify(source.sensors_to_dict(), "", true, true)
	var parsed: Variant = JSON.parse_string(text)
	var target: GameStateScript = _make_state(7)
	var problem: String = ""
	if typeof(parsed) != TYPE_DICTIONARY:
		problem = "sensors_to_dict() must survive JSON."
	else:
		target.sensors_from_dict(parsed)
	for id: String in source.sensors:
		if problem != "":
			break
		var a: DriftingSensor = source.get_sensor(id)
		var b: DriftingSensor = target.get_sensor(id)
		var da: Dictionary = a.to_dict()
		var db: Dictionary = b.to_dict()
		for key: Variant in da:
			if problem == "" and not _same(da[key], db.get(key)):
				problem = "%s.%s did not restore: %s (%d) vs %s (%d)" % [id, key, var_to_str(da[key]),
					typeof(da[key]), var_to_str(db.get(key)), typeof(db.get(key))]
		if problem == "" and not _same(a.observed_error, b.observed_error, 1e-12):
			problem = "%s observed error differs after restore." % id
		# The restored generator must continue where the saved one left off.
		a.advance_days(1.0)
		b.advance_days(1.0)
		var za: Dictionary = a.zero(0.0)
		var zb: Dictionary = b.zero(0.0)
		if problem == "" and not (_same(a.error, b.error, 1e-12) and _same(za["as_found"], zb["as_found"], 1e-12)
				and _same(za["as_left"], zb["as_left"], 1e-12)):
			problem = "%s rolls differently after restore: %s vs %s" % [id, za, zb]
	source.free()
	target.free()
	return problem


func test_rejects_state_for_another_instrument() -> String:
	var gs: GameStateScript = _make_state(1)
	var steering: DriftingSensor = gs.get_sensor(gs.STEERING_ID)
	var hygro: DriftingSensor = gs.get_sensor(gs.HYGROMETER_ID)
	var before: Dictionary = hygro.to_dict()
	steering.error = steering.mpe * 0.5
	var accepted: bool = hygro.apply_dict(steering.to_dict())
	var after: Dictionary = hygro.to_dict()
	# Bad values refuse the whole dictionary, before anything changes.
	var bad: Array[Dictionary] = [{"error": 1.0, "cal_due_day": null}, {"error": 1.0, "rng_state": "abc"},
		{"error": 1.0, "calibrated_by": 3.0}]
	var bad_accepted: bool = false
	for data: Dictionary in bad:
		bad_accepted = hygro.apply_dict(data) or bad_accepted
	gs.sensors_from_dict({"no_such_sensor": {"error": 1.0}, gs.HYGROMETER_ID: 5})
	var after_bad: Dictionary = hygro.to_dict()
	gs.free()
	if bad_accepted or after_bad != before:
		return "A sensor must refuse bad values and stay unchanged."
	if accepted or before != after:
		return "A sensor must refuse another instrument's state and stay unchanged."
	return ""


func test_restoring_only_the_offset_signals() -> String:
	var gs: GameStateScript = _make_state(1)
	var hygro: DriftingSensor = gs.get_sensor(gs.HYGROMETER_ID)
	var seen: Array[float] = []
	var listen: Callable = func(_error: float, _band: int) -> void: seen.append(hygro.observed_error)
	hygro.error_changed.connect(listen)
	var data: Dictionary = hygro.to_dict()
	data["reference_offset"] = hygro.reference_offset + hygro.mpe * 0.5
	hygro.apply_dict(data)
	hygro.error_changed.disconnect(listen)
	var observed: float = hygro.observed_error
	gs.free()
	return "" if seen == [observed] else "A restored offset alone must signal once with the new reading: %s vs %s" % [seen, observed]
