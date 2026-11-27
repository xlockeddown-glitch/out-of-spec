class_name FixedPoints
extends BenchGame
## Bench game: Fixed Points, for a thermometer. Read the ice point, then the
## boil point. Each bath's reading wanders about its fixed point (the green band
## at the middle of the scale); the one press reads it, and the point's score is
## how close the reading was. The ice bath wanders slowly; the boiling one is
## quicker and less regular. The game's score is the mean of the two.

## Each point: its name, the value the scale calls zero, how long one swing takes
## and how far the swing reaches (scale units, the scale runs -1 to 1), and the
## share of a second, faster wave added to it. All [PLACEHOLDER].
const POINTS: Array[Dictionary] = [
	{ "name": "ICE POINT", "value": "0.00 °C", "period_s": 3.4, "reach": 0.55, "extra": 0.0 },
	{ "name": "BOIL POINT", "value": "100.00 °C", "period_s": 2.4, "reach": 0.7, "extra": 0.3 },
]
## How many times faster the second wave runs than the first.
const EXTRA_RATIO: float = 2.3

var _phase: float = 0.0
var _reading: float = 0.0


## Where the reading is, in scale units from the fixed point, `seconds` into a
## point. `phase` (0 to 1) is where in the swing it starts.
static func reading_at(point: int, seconds: float, phase: float = 0.0) -> float:
	var spec: Dictionary = POINTS[clampi(point, 0, POINTS.size() - 1)]
	var turns: float = seconds / maxf(float(spec["period_s"]), 0.001) + phase
	var extra: float = float(spec["extra"])
	return float(spec["reach"]) * ((1.0 - extra) * sin(TAU * turns) + extra * sin(TAU * (turns * EXTRA_RATIO + phase)))


## The score of one read at `off` scale units from the fixed point, with a green
## band of plus or minus `sweet_half_width`: 95 to 100 inside it, falling in a
## straight line to 0 at MISS_AT half-widths (Set the Zero's own curve).
static func read_score(off: float, band_half: float) -> int:
	var far: float = absf(off) / maxf(band_half, 0.000001)
	if far <= 1.0:
		return roundi(MinigameScore.MAX_SCORE - (MinigameScore.MAX_SCORE - SetTheZero.SWEET_SCORE) * far)
	return clampi(floori(SetTheZero.SWEET_SCORE - (far - 1.0) * SetTheZero.SWEET_SCORE / (SetTheZero.MISS_AT - 1.0)),
		0, SetTheZero.SWEET_SCORE - 1)


func game_name() -> String:
	return "Fixed Points"


func game_id() -> String:
	return MinigameScore.FIXED_POINTS


func point_count() -> int:
	return POINTS.size()


func action_word() -> String:
	return "READ"


func reading() -> float:
	return _reading


func _start_point(index: int) -> void:
	_phase = _rng.randf()
	_reading = reading_at(index, 0.0, _phase)
	_stage_label.text = "POINT %d OF %d: %s" % [index + 1, POINTS.size(), POINTS[index]["name"]]


func _point_hint() -> String:
	return "The bath's reading swings about %s. Read it as it crosses the green band." % POINTS[_point]["value"]


func _step(_seconds: float) -> void:
	_reading = reading_at(_point, _time * _speed, _phase)


func _press_play() -> void:
	if _time < ARM_S:
		return
	_point_done(read_score(_reading, _sweet))


func _draw_scale() -> void:
	var w: float = _scale.size.x
	var h: float = _scale.size.y
	var top: float = h * 0.3
	var bar_h: float = h * 0.4
	var mid: float = w * 0.5
	var per_unit: float = w * 0.5 - 6.0
	_draw_bar(top, bar_h)
	var sweet_px: float = maxf(_sweet * per_unit, 2.0)
	_scale.draw_rect(Rect2(mid - sweet_px, top, 2.0 * sweet_px, bar_h), Color(ScopeTheme.TEAL, 0.45))
	for side: float in [-1.0, 1.0]:
		var edge_x: float = mid + side * sweet_px
		_scale.draw_line(Vector2(edge_x, top - 10.0), Vector2(edge_x, top + bar_h + 10.0), ScopeTheme.TEAL, 2.0)
	for i: int in range(-10, 11):
		var tick_x: float = mid + i * 0.1 * per_unit
		var is_long: bool = i % 5 == 0
		_scale.draw_line(Vector2(tick_x, top + bar_h), Vector2(tick_x, top + bar_h - (14.0 if is_long else 7.0)),
			ScopeTheme.INK_MUTED, 2.0 if is_long else 1.0)
	if _stage != Stage.IDLE:
		var value: String = POINTS[clampi(_point, 0, POINTS.size() - 1)]["value"]
		_scale.draw_string(get_theme_default_font(), Vector2(mid - 80.0, h - 2.0), value,
			HORIZONTAL_ALIGNMENT_CENTER, 160.0, 20, ScopeTheme.TEAL)
	var needle_x: float = mid + clampf(_reading, -1.0, 1.0) * per_unit
	_scale.draw_line(Vector2(needle_x, top - 16.0), Vector2(needle_x, top + bar_h + 4.0), ScopeTheme.INK, 4.0)
	_scale.draw_colored_polygon(PackedVector2Array([
		Vector2(needle_x - 9.0, top - 24.0), Vector2(needle_x + 9.0, top - 24.0), Vector2(needle_x, top - 8.0)]), ScopeTheme.INK)
