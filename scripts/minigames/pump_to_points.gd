class_name PumpToPoints
extends BenchGame
## Bench game: Pump to Points, for a pressure gauge. Each press is one stroke of
## the hand pump and the pressure leaks away between strokes. Pump up to each
## test point (the green band) and hold it there. A point is taken once the
## pressure has stood in the band for DWELL_S; its score is the share of the time
## since it first reached the band that it stayed in. A point never reached in
## POINT_LIMIT_S scores 0. The game's score is the mean of the points.

## The test points, as shares of the gauge's range [PLACEHOLDER].
const POINTS: Array[float] = [0.25, 0.5, 0.75]
## What one stroke adds, and how much a stroke may differ from it (a share).
const STROKE: float = 0.05
const STROKE_JITTER: float = 0.2
## No stroke sooner than this after the last, so a held key is not a flood.
const STROKE_GAP_S: float = 0.12
## The pressure that leaks away each second on Standard.
const LEAK_PER_S: float = 0.1
## Half the band's width on Standard with no Calibration skill; twice this at
## Calibration 1. Wider than Set the Zero's, as a hand pump is coarser.
const BASE_BAND: float = 0.06
## Time in the band that takes a point, and the time allowed for a point.
const DWELL_S: float = 1.5
## Not scaled by the difficulty's speed [PLACEHOLDER]: Relaxed leaks slower, so it
## only gets easier.
const POINT_LIMIT_S: float = 10.0
## The result takes a press only after this, so the last strokes do not close it.
const RESULT_ARM_PUMP_S: float = 0.9
const MAX_PRESSURE: float = 1.1

var _pressure: float = 0.0
var _since_stroke: float = 0.0
var _entered: bool = false
var _inside_s: float = 0.0
var _outside_s: float = 0.0
var _band: float = BASE_BAND


## Half the band's width. `share` is the Calibration skill's part of the
## widening (twice as wide at 1); `sweet_factor` is the difficulty's.
static func band_half_width(share: float, sweet_factor: float = 1.0) -> float:
	return BASE_BAND * (1.0 + SKILL_WIDENING * clampf(share, 0.0, 1.0)) * maxf(sweet_factor, 0.0)


## The score of a point: the share of the time since the pressure first reached
## the band that it was in, times how much of the dwell it got.
static func point_score(inside_s: float, outside_s: float) -> int:
	var total: float = inside_s + outside_s
	if total <= 0.0:
		return 0
	return clampi(roundi(MinigameScore.MAX_SCORE * inside_s / total * minf(inside_s / DWELL_S, 1.0)), 0, MinigameScore.MAX_SCORE)


func _result_arm() -> float:
	return RESULT_ARM_PUMP_S


func game_name() -> String:
	return "Pump to Points"


func game_id() -> String:
	return MinigameScore.PUMP_TO_POINTS


func point_count() -> int:
	return POINTS.size()


func action_word() -> String:
	return "PUMP"


func pressure() -> float:
	return _pressure


func target() -> float:
	return POINTS[clampi(_point, 0, POINTS.size() - 1)]


func band() -> float:
	return _band


func play(share: float, mode: int, motion_seed: int, subject: String = "") -> void:
	_band = band_half_width(share, MinigameSettings.sweet_factor(mode))
	_pressure = 0.0
	super.play(share, mode, motion_seed, subject)


func _start_point(index: int) -> void:
	_entered = false
	_inside_s = 0.0
	_outside_s = 0.0
	_since_stroke = STROKE_GAP_S
	_stage_label.text = "TEST POINT %d OF %d: %d %% OF RANGE" % [index + 1, POINTS.size(), roundi(POINTS[index] * 100.0)]


func _point_hint() -> String:
	return "Pump up to the green band and keep it there. Strokes leak away: pump a little, often."


func _step(seconds: float) -> void:
	_since_stroke += seconds
	_pressure = maxf(_pressure - LEAK_PER_S * _speed * seconds, 0.0)
	if absf(_pressure - target()) <= _band:
		_entered = true
		_inside_s += seconds
	elif _entered:
		_outside_s += seconds
	if _inside_s >= DWELL_S or _time >= POINT_LIMIT_S:
		_point_done(point_score(_inside_s, _outside_s))


func _press_play() -> void:
	if _since_stroke < STROKE_GAP_S:
		return
	_since_stroke = 0.0
	_pressure = minf(_pressure + STROKE * (1.0 + STROKE_JITTER * (_rng.randf() * 2.0 - 1.0)), MAX_PRESSURE)


func _draw_scale() -> void:
	var w: float = _scale.size.x
	var h: float = _scale.size.y
	var top: float = h * 0.3
	var bar_h: float = h * 0.4
	var per_unit: float = w - 12.0
	var left: float = 6.0
	_draw_bar(top, bar_h)
	for i: int in range(0, 11):
		var tick_x: float = left + i * 0.1 * per_unit
		var is_long: bool = i % 5 == 0
		_scale.draw_line(Vector2(tick_x, top + bar_h), Vector2(tick_x, top + bar_h - (14.0 if is_long else 7.0)),
			ScopeTheme.INK_MUTED, 2.0 if is_long else 1.0)
	if _stage == Stage.IDLE:
		return
	var band_px: float = maxf(_band * per_unit, 2.0)
	var goal_x: float = left + target() * per_unit
	_scale.draw_rect(Rect2(goal_x - band_px, top, 2.0 * band_px, bar_h), Color(ScopeTheme.TEAL, 0.45))
	for side: float in [-1.0, 1.0]:
		var edge_x: float = goal_x + side * band_px
		_scale.draw_line(Vector2(edge_x, top - 10.0), Vector2(edge_x, top + bar_h + 10.0), ScopeTheme.TEAL, 2.0)
	var fill: float = clampf(_pressure, 0.0, 1.0) * per_unit
	_scale.draw_rect(Rect2(left, top + bar_h * 0.35, fill, bar_h * 0.3), Color(ScopeTheme.INK, 0.85))
	_scale.draw_string(get_theme_default_font(), Vector2(goal_x - 40.0, h - 2.0), "%d %%" % roundi(target() * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, 80.0, 20, ScopeTheme.TEAL)
	var needle_x: float = left + clampf(_pressure, 0.0, 1.0) * per_unit
	_scale.draw_line(Vector2(needle_x, top - 16.0), Vector2(needle_x, top + bar_h + 4.0), ScopeTheme.INK, 4.0)
