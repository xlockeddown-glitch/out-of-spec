class_name PhoneGauge
extends Control
## Dial of an error against its limits: teal inside the acceptance limits,
## amber in the guard band, red beyond ±MPE, and a needle that swings to the
## value it is given. Past the end of the scale the needle rests on the stop.

const SPAN_MPE: float = 1.5
## Half the dial's sweep, radians.
const SWEEP: float = 1.15
const FACE := Color("#0B1417")
const INK := Color(0.85, 0.95, 0.88)
## How fast the needle swings, rad/s.
const SWING: float = 9.0

var mpe: float = 1.0
var acceptance_ratio: float = 0.8
var value: float = 0.0
var _shown: float = 0.0
var _speed: float = 0.0


func set_limits(new_mpe: float, ratio: float) -> void:
	mpe = maxf(new_mpe, 0.0001)
	acceptance_ratio = ratio
	queue_redraw()


## Where on the dial, in radians from straight up.
func angle_of(error: float) -> float:
	return clampf(error / (mpe * SPAN_MPE), -1.0, 1.0) * SWEEP


func _process(delta: float) -> void:
	var target: float = angle_of(value)
	if _shown == target and _speed == 0.0:
		return
	# A damped spring: it overshoots a touch, as a real needle does.
	var step: float = minf(delta, 0.03)
	_speed += ((target - _shown) * SWING * SWING - _speed * SWING * 1.3) * step
	_shown = clampf(_shown + _speed * step, -SWEEP - 0.04, SWEEP + 0.04)
	if absf(target - _shown) < 0.0005 and absf(_speed) < 0.005:
		_shown = target
		_speed = 0.0
	queue_redraw()


func _draw() -> void:
	var pivot := Vector2(size.x * 0.5, size.y - 14.0)
	var radius: float = minf(size.y - 24.0, size.x * 0.5 / sin(SWEEP) - 8.0)
	var style := StyleBoxFlat.new()
	style.bg_color = FACE
	style.set_corner_radius_all(12)
	style.border_color = Color(0, 0, 0, 0.6)
	style.set_border_width_all(2)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	_band(pivot, radius, SPAN_MPE, DriftingSensor.COLOR_OUT_OF_TOLERANCE)
	_band(pivot, radius, 1.0, DriftingSensor.COLOR_GUARDBAND)
	_band(pivot, radius, acceptance_ratio, DriftingSensor.COLOR_IN_BAND)
	for i: int in 13:
		var at: Vector2 = _toward(lerpf(-SWEEP, SWEEP, i / 12.0))
		var is_long: bool = i in [2, 6, 10]
		draw_line(pivot + at * (radius - (22.0 if is_long else 16.0)), pivot + at * (radius - 11.0),
				Color(INK, 0.9 if is_long else 0.45), 2.0, true)
	var font: Font = get_theme_default_font()
	var marks: Dictionary = { -1.0: "−MPE", 1.0: "+MPE" }
	for mark: float in marks:
		var text: String = marks[mark]
		var place: Vector2 = pivot + _toward(angle_of(mark * mpe)) * (radius - 35.0)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, place + Vector2(-width * 0.5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, 0.7))
	var tip: Vector2 = pivot + _toward(_shown) * (radius - 4.0)
	draw_line(pivot + Vector2(2, 3), tip + Vector2(2, 3), Color(0, 0, 0, 0.5), 4.0, true)
	draw_line(pivot, tip, INK, 3.0, true)
	draw_circle(pivot, 9, Color("#39414B"))
	draw_circle(pivot, 4, Color("#14181C"))


func _band(pivot: Vector2, radius: float, of_mpe: float, color: Color) -> void:
	var half: float = angle_of(of_mpe * mpe)
	draw_arc(pivot, radius - 5.0, -half - PI / 2.0, half - PI / 2.0, 40, color, 9.0, true)


func _toward(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))
