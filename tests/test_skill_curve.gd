extends RefCounted
## The 99-level curve (docs/design/quests_levels_story.md section 2): its totals,
## how effects spread over it, and what a save from the 10-level curve keeps.
## Every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const EPS: float = 1.0e-9
## Level -> total XP, from the design's table and its four bands.
const TOTALS: Dictionary = { 1: 0, 2: 50, 10: 679, 25: 4425, 50: 52859, 75: 577634, 92: 2921662, 99: 5693968 }
## Level -> share of an effect's full cut.
const SHARES: Dictionary = { 1: 0.0, 10: 0.25, 20: 0.375, 30: 0.5, 45: 0.625, 60: 0.75, 99: 1.0 }
## The 10-level curve: total XP at old level n was 25 × n × (n − 1).
const OLD_TOP_XP: int = 2250


func _run(body: Callable) -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	return problem


func _old_xp(old_level: int) -> int:
	return 25 * old_level * (old_level - 1)


## The farm as a save from before the 99-level curve wrote it.
func _old_save(gs: GameStateScript) -> Dictionary:
	var data: Dictionary = gs.farm_to_dict()
	data.erase("skill_curve")
	data.erase("skill_effect_floor")
	return data


func test_totals() -> String:
	return _run(_check_totals)


func _check_totals(gs: GameStateScript) -> String:
	if gs.max_skill_level() != 99:
		return "The top level is 99: %d" % gs.max_skill_level()
	for level: int in TOTALS:
		if gs.xp_for_level(level) != TOTALS[level]:
			return "Level %d needs %d XP: %d" % [level, TOTALS[level], gs.xp_for_level(level)]
	for level: int in range(1, 99):
		var step: int = gs.xp_for_level(level + 1) - gs.xp_for_level(level)
		if absf(step - 50.0 * pow(1.1, level - 1)) > 1.0:
			return "Level %d to %d costs %d." % [level, level + 1, step]
	return "" if gs.xp_for_level(0) == 0 and gs.xp_for_level(-3) == 0 else "No level is under 1."


func test_level_from_xp() -> String:
	return _run(_check_levels)


func _check_levels(gs: GameStateScript) -> String:
	for level: int in range(2, 100):
		var needed: int = gs.xp_for_level(level)
		if gs._level_for_xp(needed - 1) != level - 1 or gs._level_for_xp(needed) != level:
			return "%d XP is where level %d starts: %d, %d" % [needed, level, gs._level_for_xp(needed - 1), gs._level_for_xp(needed)]
	for xp: int in [-5, 0, 49]:
		if gs._level_for_xp(xp) != 1:
			return "%d XP is level 1." % xp
	for xp: int in [TOTALS[99], TOTALS[99] + 1, TOTALS[99] * 10, GameStateScript.MOST_SKILL_XP]:
		if gs._level_for_xp(xp) != 99:
			return "%d XP is level 99, the top." % xp
	gs.player_skill_xp["player_1"] = { "husbandry": TOTALS[99] * 3 }
	return "" if gs.skill_level("husbandry") == 99 and gs.skill_text("husbandry").contains("top level") else "The top level must hold."


func test_effect_spread() -> String:
	return _run(_check_spread)


func _check_spread(gs: GameStateScript) -> String:
	for level: int in SHARES:
		if absf(gs.effect_share(level) - SHARES[level]) > EPS:
			return "Level %d has %s of the effect: %s" % [level, SHARES[level], gs.effect_share(level)]
	for level: int in range(1, 99):
		if gs.effect_share(level + 1) <= gs.effect_share(level):
			return "Level %d must give more than level %d." % [level + 1, level]
	if gs.effect_share(0) != 0.0 or gs.effect_share(500) != 1.0:
		return "The share stays from 0 to 1."
	# Front-loaded: the first ten levels give as much as the last 39.
	if gs.effect_share(10) - gs.effect_share(1) < gs.effect_share(99) - gs.effect_share(60) - EPS:
		return "The early levels must give the most."
	for effect: Dictionary in DataManager.get_records(&"skills", "effects"):
		var low: float = float(effect.get("floor", 0.0))
		for level: int in SHARES:
			gs.player_skill_xp["player_1"] = { effect["skill"]: gs.xp_for_level(level) }
			var wanted: float = maxf(low, 1.0 - float(effect["full"]) * SHARES[level])
			if absf(gs.skill_factor(effect["id"]) - wanted) > EPS:
				return "%s at level %d: %s, not %s" % [effect["id"], level, gs.skill_factor(effect["id"]), wanted]
		# Level 99 has what level 10 had on the old curve, if there was one then.
		if not effect.has("old_per_level"):
			continue
		var old_top: float = maxf(low, 1.0 - float(effect["old_per_level"]) * 9)
		if absf(gs.skill_factor(effect["id"]) - old_top) > EPS:
			return "%s at 99 must be the old level 10's %s: %s" % [effect["id"], old_top, gs.skill_factor(effect["id"])]
	return ""


func test_calibration_xp_grows_with_the_tier() -> String:
	return _run(_check_tiers)


func _check_tiers(gs: GameStateScript) -> String:
	var scales: Array = DataManager.get_value(&"skills", "calibration_tier_xp", [])
	if scales != [1.0, 1.5, 2.5, 4.0]:
		return "The tier scales: %s" % [scales]
	var seen: Dictionary = {}
	for id: String in gs.sensors:
		var sensor: DriftingSensor = gs.get_sensor(id)
		if sensor.role == "standard":
			if gs.calibration_xp_scale(id) != scales[sensor.tier]:
				return "%s is Tier %d: %s" % [id, sensor.tier, gs.calibration_xp_scale(id)]
			seen[sensor.tier] = true
	if seen.size() != scales.size():
		return "Every tier has a standard and a scale: %s" % [seen.keys()]
	return "" if gs.calibration_xp_scale("none") == 1.0 and gs.calibration_xp_scale("") == 1.0 else "No standard, no scale."


func test_new_farm_has_no_floor() -> String:
	return _run(_check_new)


func _check_new(gs: GameStateScript) -> String:
	gs.till(Vector3i(1, 0, 1))
	gs.player_skill_xp["player_1"]["husbandry"] = gs.xp_for_level(40)
	var data: Dictionary = gs.farm_to_dict()
	if data.get("skill_curve") != GameStateScript.SKILL_CURVE or data.get("skill_effect_floor") != {}:
		return "A new farm is on the new curve, with no floor: %s" % [data.get("skill_effect_floor")]
	var xp: int = gs.skill_xp("agronomy")
	if xp <= 0 or gs.farm_from_dict(data) != "" or gs.skill_xp("agronomy") != xp or gs.skill_xp("husbandry") != gs.xp_for_level(40):
		return "A new save loads as it was saved."
	return "" if gs.skill_effect_floor.is_empty() and gs.effect_floor("husbandry") == 0.0 else "It must not gain a floor."


func test_old_save_converts() -> String:
	return _run(_check_old)


func _check_old(gs: GameStateScript) -> String:
	var factor: int = int(DataManager.get_number(&"skills", "old_curve/xp_factor", 0.0))
	# What each effect was at old level 10, which nothing may fall under.
	var old_top: Dictionary = {}
	for effect: Dictionary in DataManager.get_records(&"skills", "effects"):
		old_top[effect["id"]] = maxf(float(effect.get("floor", 0.0)), 1.0 - float(effect.get("old_per_level", 0.0)) * 9)
	gs.player_skill_xp = {
		"player_1": { "calibration": OLD_TOP_XP, "uncertainty": _old_xp(8), "field_ops": _old_xp(2) - 1 },
		"player_2": { "calibration": _old_xp(4) },
	}
	gs.farm_skill_xp = { "husbandry": OLD_TOP_XP * 4, "robotics": _old_xp(3), "instrumentation": _old_xp(6) }
	var old: Dictionary = _old_save(gs)
	if gs.farm_from_dict(old) != "" or gs.skill_curve != GameStateScript.SKILL_CURVE:
		return "An old save must load: %s" % gs.farm_from_dict(old)
	if gs.skill_xp("calibration") != OLD_TOP_XP * factor or gs.skill_xp("husbandry") != OLD_TOP_XP * 4 * factor \
			or gs.skill_xp("calibration", "player_2") != _old_xp(4) * factor or gs.lab_xp != _old_xp(6) * factor \
			or gs.skill_xp("husbandry", "player_2") != OLD_TOP_XP * 4 * factor or gs.skill_xp("robotics", "player_2") != _old_xp(3) * factor \
			or not gs.farm_skill_xp.is_empty():
		return "Old XP is multiplied by %d, and the farm's is each player's: %s %s" % [factor, gs.player_skill_xp, gs.farm_skill_xp]
	for old_level: int in range(1, 11):
		if gs._old_level(_old_xp(old_level)) != old_level or gs._level_for_xp(_old_xp(old_level) * factor) < old_level:
			return "Old level %d must not turn into a lower one." % old_level
	if gs.skill_level("calibration") >= 99 or gs.skill_level("calibration") < 10:
		return "An old level 10 is past 10 and short of 99: %d" % gs.skill_level("calibration")
	# Old level 10: every effect as it was, though the new level's share is smaller.
	for id: String in ["bench_time", "as_left_residual", "molt_time"]:
		if absf(gs.skill_factor(id) - old_top[id]) > EPS:
			return "%s must stay %s: %s" % [id, old_top[id], gs.skill_factor(id)]
	if absf(gs.effect_floor("calibration") - 1.0) > EPS or absf(gs.effect_floor("husbandry") - 1.0) > EPS \
			or absf(gs.effect_floor("husbandry", "player_2") - 1.0) > EPS or absf(gs.molt_days() - gs.PLAYTEST_MOLT_DAYS * old_top["molt_time"]) > EPS:
		return "An old level 10 keeps the whole effect: %s" % [gs.skill_effect_floor]
	# Old level 8 was on the floor already: 1 - 0.1 x 7 = 0.3.
	if absf(gs.skill_factor("operator_uncertainty") - 0.3) > EPS:
		return "Uncertainty 8 was at its floor and stays there: %s" % gs.skill_factor("operator_uncertainty")
	# Old level 4 cut the bench time by 24 % and the residual by 15 %.
	if absf(gs.skill_factor("bench_time", "player_2") - 0.76) > EPS or gs.skill_factor("as_left_residual", "player_2") > 0.85 + EPS:
		return "Player 2 keeps old level 4: %s, %s" % [gs.skill_factor("bench_time", "player_2"), gs.skill_factor("as_left_residual", "player_2")]
	# Old level 1 had nothing to keep; a skill with no effect has no floor.
	if gs.skill_effect_floor["player_1"].has("field_ops") or gs.skill_effect_floor.has("") \
			or gs.skill_effect_floor["player_1"].has("robotics") or gs.effect_floor("calibration", "player_3") != 0.0:
		return "Only what was held is kept: %s" % [gs.skill_effect_floor]
	if not gs.has_skill_unlock("molt_on_phone") or not gs.has_skill_unlock("budget_view") or gs.has_skill_unlock("budget_view", "player_2"):
		return "An unlock that was open stays open."
	# Saved again it is a new save: nothing is multiplied twice.
	var again: Dictionary = gs.farm_to_dict()
	var floors: Dictionary = gs.skill_effect_floor.duplicate(true)
	if gs.farm_from_dict(again) != "" or gs.skill_xp("calibration") != OLD_TOP_XP * factor or gs.skill_effect_floor != floors:
		return "A converted save must not convert again: %s" % [gs.skill_effect_floor]
	# The floor never falls, and a higher level passes it.
	gs.player_skill_xp["player_2"]["calibration"] = gs.xp_for_level(99)
	if absf(gs.skill_factor("bench_time", "player_2") - old_top["bench_time"]) > EPS:
		return "Level 99 passes an old level 4's floor."
	gs.player_skill_xp["player_1"]["calibration"] = 0
	return "" if absf(gs.skill_factor("bench_time") - old_top["bench_time"]) < EPS else "The floor holds whatever the level."


func test_old_save_with_no_xp() -> String:
	return _run(_check_empty)


func _check_empty(gs: GameStateScript) -> String:
	var old: Dictionary = _old_save(gs)
	old.erase("player_skill_xp")
	old.erase("farm_skill_xp")
	if gs.farm_from_dict(old) != "" or not gs.skill_effect_floor.is_empty() or gs.skill_curve != GameStateScript.SKILL_CURVE:
		return "A save older than skills loads with no XP and no floor."
	gs.till(Vector3i(1, 0, 1))
	return "" if gs.skill_xp("agronomy") == int(DataManager.get_record(&"skills", "till", "xp_sources")["xp"]) else "It earns XP at the new values."


func test_bad_floor_is_refused() -> String:
	return _run(_check_bad)


func _check_bad(gs: GameStateScript) -> String:
	var good: Dictionary = gs.farm_to_dict()
	for change: Array in [["skill_curve", 1], ["skill_curve", 5], ["lab_xp", -1], ["lab_xp", 2000000000], ["lab_xp", 1.5], ["skill_curve", "2"], ["skill_effect_floor", []],
			["skill_effect_floor", { "": 1.0 }], ["skill_effect_floor", { 4: {} }], ["skill_effect_floor", { "": { "husbandry": 1.5 } }],
			["skill_effect_floor", { "": { "husbandry": -0.1 } }], ["skill_effect_floor", { "": { "husbandry": NAN } }],
			["skill_effect_floor", { "player_1": { "calibration": "all" } }], ["skill_effect_floor", { "player_1": { 3: 0.5 } }]]:
		var bad: Dictionary = good.duplicate(true)
		bad[change[0]] = change[1]
		if gs.farm_from_dict(bad) == "":
			return "Must be refused: %s" % [change]
	good["skill_effect_floor"] = { "": { "husbandry": 0.5 }, "player_1": { "calibration": 1.0 } }
	return gs.farm_from_dict(good)


func test_a_forgotten_guest_leaves_no_floor() -> String:
	return _run(_check_forgotten)


func _check_forgotten(gs: GameStateScript) -> String:
	var players: Array[String] = ["player_1"]
	var id: String = gs.let_in_guest("a".repeat(32), { "calibration": 10 }, players)
	gs.skill_effect_floor[id] = { "calibration": 0.5 }
	for i: int in GameStateScript.MAX_KNOWN_GUESTS + 1:
		gs.let_in_guest("%032x" % i, {}, players)
	return "" if not gs.player_skill_xp.has(id) and not gs.skill_effect_floor.has(id) else "A forgotten guest's floor must go with their XP."


func test_guest_file_from_the_old_curve() -> String:
	var key: String = "0".repeat(32)
	var factor: int = int(DataManager.get_number(&"skills", "old_curve/xp_factor", 0.0))
	var old: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"calibration":%d,"field_ops":7}}' % [key, OLD_TOP_XP]).to_utf8_buffer())
	if old != { "key": key, "skills": { "calibration": OLD_TOP_XP * factor, "field_ops": 7 * factor } }.merged(ProfileScript.no_record()):
		return "An old guest file is multiplied by %d: %s" % [factor, old]
	var new: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"calibration":%d},"curve":%d}' % [key, OLD_TOP_XP, ProfileScript.CURVE]).to_utf8_buffer())
	if new != { "key": key, "skills": { "calibration": OLD_TOP_XP } }.merged(ProfileScript.no_record()):
		return "A new guest file is read as it is: %s" % [new]
	var before: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"field_ops":900},"curve":2}' % key).to_utf8_buffer())
	if before != { "key": key, "skills": { "field_ops": 900 } }.merged(ProfileScript.no_record()):
		return "A guest file from before Agronomy is read as it is: %s" % [before]
	for curve: String in ["1", "4", "2.5", "\"2\""]:
		var odd: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"calibration":5},"curve":%s}' % [key, curve]).to_utf8_buffer())
		if not odd.is_empty():
			return "A guest file with curve %s is refused: %s" % [curve, odd]
	var most: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"calibration":%d}}' % [key, ProfileScript.MOST_XP]).to_utf8_buffer())
	return "" if most.get("skills") == { "calibration": ProfileScript.MOST_XP } else "Converted XP stays in range: %s" % [most]
