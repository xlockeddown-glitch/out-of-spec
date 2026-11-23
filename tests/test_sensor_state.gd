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


## Floats may lose their last bit through Godot's JSON even at full
## precision (about 1e-17), so they compare approximately; the rest exactly.
func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if typeof(a) == TYPE_FLOAT:
		return is_equal_approx(a, b)
	return a == b


func test_round_trip_through_json_matches_every_sensor() -> String:
	var source: GameStateScript = _make_state(424242)
	_wear(source)
	# Full precision: the default 14 digits would round the errors.
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
		if problem == "" and not is_equal_approx(a.observed_error, b.observed_error):
			problem = "%s observed error differs after restore." % id
		# The restored generator must continue where the saved one left off.
		a.advance_days(1.0)
		b.advance_days(1.0)
		var za: Dictionary = a.zero(0.0)
		var zb: Dictionary = b.zero(0.0)
		if problem == "" and not (_same(a.error, b.error) and _same(za["as_found"], zb["as_found"])
				and _same(za["as_left"], zb["as_left"])):
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
	gs.sensors_from_dict({"no_such_sensor": {"error": 1.0}})
	gs.free()
	if accepted or before != after:
		return "A sensor must refuse another instrument's state and stay unchanged."
	return ""
