class_name BandMeter
extends Control
## Horizontal tolerance meter, drawn as a vernier scale: red beyond ±MPE, amber
## guard-band shoulders between the acceptance limit and ±MPE, teal in the
## acceptance zone, ticks along the scale, a longer one at nominal, and a needle
## with a diamond at each end at the current error. A new reading settles in
## (a short Tween), so the needle swings to it.

# Darkened versions of the palette so the needle reads on top [PLACEHOLDER].
const COLOR_RED := Color("#FF5A5F") * Color(0.55, 0.55, 0.55, 1.0)
const COLOR_AMBER := Color("#F5A623") * Color(0.75, 0.75, 0.75, 1.0)
const COLOR_GREEN := Color("#38E1C6") * Color(0.5, 0.5, 0.5, 1.0)
const COLOR_NEEDLE := Color(1, 1, 1)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.8)
const COLOR_TRACK := Color("#151921")
## Minor ticks per half scale, and every this many is a major one.
const TICKS_PER_HALF: int = 10
const MAJOR_EVERY: int = 5
## How long the needle takes to settle on a new reading, in seconds.
const SETTLE_SECONDS: float = 0.3

## Half-width of the scale, in multiples of MPE.
@export var span_mpe: float = 1.5

var mpe: float = 1.0:
	set(v):
		mpe = maxf(v, 0.0001)
		queue_redraw()
var acceptance_ratio: float = 0.8:
	set(v):
		acceptance_ratio = v
		queue_redraw()
## The reading. The needle drawn follows it over SETTLE_SECONDS.
var value: float = 0.0:
	set(v):
		value = v
		_settle()
## Hide the needle (e.g. As-Left before calibrating).
var show_needle: bool = true:
	set(v):
		if v and not show_needle:
			# A needle that comes back swings in from the nominal.
			_shown = 0.0
		show_needle = v
		_settle()
		queue_redraw()

## The value the needle is drawn at, on its way to `value`.
var _shown: float = 0.0:
	set(v):
		_shown = v
		queue_redraw()
var _tween: Tween


func _settle() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if not show_needle or not is_inside_tree() or not is_visible_in_tree():
		_shown = value
		return
	_tween = create_tween()
	_tween.tween_property(self, "_shown", value, SETTLE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var bar_h: float = size.y * 0.42
	var y0: float = (size.y - bar_h) * 0.5
	draw_rect(Rect2(-3, y0 - 3, size.x + 6, bar_h + 6), COLOR_TRACK)
	draw_rect(Rect2(0, y0, size.x, bar_h), COLOR_RED)
	_draw_zone(1.0, COLOR_AMBER, y0, bar_h)
	_draw_zone(acceptance_ratio, COLOR_GREEN, y0, bar_h)
	_draw_ticks(y0, bar_h)
	for edge: float in [-1.0, 1.0]:
		var x: float = _x(edge * mpe)
		draw_line(Vector2(x, y0 - 5), Vector2(x, y0 + bar_h + 5), COLOR_TICK, 2.0)
	if show_needle:
		var nx: float = _x(_shown)
		draw_line(Vector2(nx, 4), Vector2(nx, size.y - 4), COLOR_NEEDLE, 3.0)
		var d: float = 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(nx, 0), Vector2(nx + d, d), Vector2(nx, 2 * d), Vector2(nx - d, d)]), COLOR_NEEDLE)
		draw_colored_polygon(PackedVector2Array([Vector2(nx, size.y), Vector2(nx + d, size.y - d), Vector2(nx, size.y - 2 * d), Vector2(nx - d, size.y - d)]), COLOR_NEEDLE)


## The scale's ticks across the whole bar: small ones, a taller one every
## MAJOR_EVERY, the tallest at nominal.
func _draw_ticks(y0: float, bar_h: float) -> void:
	var each: float = mpe * span_mpe / float(TICKS_PER_HALF)
	for i: int in range(-TICKS_PER_HALF, TICKS_PER_HALF + 1):
		var x: float = _x(float(i) * each)
		var major: bool = i % MAJOR_EVERY == 0
		var reach: float = bar_h * (0.5 if i == 0 else 0.34 if major else 0.18)
		draw_line(Vector2(x, y0 + bar_h), Vector2(x, y0 + bar_h - reach), COLOR_TICK, 2.0 if major else 1.0)
		draw_line(Vector2(x, y0), Vector2(x, y0 + reach * 0.6), COLOR_TICK, 1.0)


func _draw_zone(ratio: float, color: Color, y0: float, bar_h: float) -> void:
	var x0: float = _x(-ratio * mpe)
	var x1: float = _x(ratio * mpe)
	draw_rect(Rect2(x0, y0, x1 - x0, bar_h), color)


func _x(v: float) -> float:
	var t: float = clampf(v / (mpe * span_mpe), -1.0, 1.0)
	return (t * 0.5 + 0.5) * size.x
