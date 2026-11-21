class_name BandMeter
extends Control
## Horizontal tolerance meter: red beyond ±MPE, amber guard band, green
## acceptance zone, centre line at nominal, white needle at the current error.

# Darkened versions of the neon band palette so the white needle reads on top.
const COLOR_RED := Color("#FF5A5F") * Color(0.55, 0.55, 0.55)
const COLOR_AMBER := Color("#F5A623") * Color(0.6, 0.6, 0.6)
const COLOR_GREEN := Color("#38E1C6") * Color(0.5, 0.5, 0.5)
const COLOR_NEEDLE := Color(1, 1, 1)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.8)

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
var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()
## Hide the needle (e.g. As-Left before calibrating).
var show_needle: bool = true:
	set(v):
		show_needle = v
		queue_redraw()


func _draw() -> void:
	var bar_h: float = size.y * 0.5
	var y0: float = (size.y - bar_h) * 0.5
	draw_rect(Rect2(0, y0, size.x, bar_h), COLOR_RED)
	_draw_zone(1.0, COLOR_AMBER, y0, bar_h)
	_draw_zone(acceptance_ratio, COLOR_GREEN, y0, bar_h)
	for edge: float in [-1.0, 1.0]:
		var x: float = _x(edge * mpe)
		draw_line(Vector2(x, y0 - 4), Vector2(x, y0 + bar_h + 4), COLOR_TICK, 2.0)
	var cx: float = _x(0.0)
	draw_line(Vector2(cx, y0), Vector2(cx, y0 + bar_h), COLOR_TICK, 1.0)
	if show_needle:
		var nx: float = _x(value)
		draw_line(Vector2(nx, 0), Vector2(nx, size.y), COLOR_NEEDLE, 3.0)


func _draw_zone(ratio: float, color: Color, y0: float, bar_h: float) -> void:
	var x0: float = _x(-ratio * mpe)
	var x1: float = _x(ratio * mpe)
	draw_rect(Rect2(x0, y0, x1 - x0, bar_h), color)


func _x(v: float) -> float:
	var t: float = clampf(v / (mpe * span_mpe), -1.0, 1.0)
	return (t * 0.5 + 0.5) * size.x
