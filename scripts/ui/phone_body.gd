class_name PhoneBody
extends Container
## The field phone's shell: a molded body with rubber corners, screws, an
## antenna, a speaker, a message light and a worn label, drawn around its two
## children, the screen and the keys.

const SHELL := Color("#39414B")
const RUBBER := Color("#14181C")
## The palette's amber, faded, so it doesn't read as a guard band.
const GRIP := Color("#b9803a")
const LIGHT_OFF := Color("#23343a")
const TOP: float = 74.0
const SIDE: float = 22.0
const BOTTOM: float = 24.0
const GAP: float = 12.0
const ANTENNA: float = 26.0

## 1 when a message comes in, then fades.
var light: float = 0.0:
	set(value):
		light = value
		queue_redraw()


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var screen: Control = get_child(0)
	var keys: Control = get_child(1)
	var keys_h: float = keys.get_combined_minimum_size().y
	var width: float = size.x - SIDE * 2.0
	fit_child_in_rect(screen, Rect2(SIDE, ANTENNA + TOP, width, size.y - ANTENNA - TOP - GAP - keys_h - BOTTOM))
	fit_child_in_rect(keys, Rect2(SIDE, size.y - BOTTOM - keys_h, width, keys_h))
	queue_redraw()


func _draw() -> void:
	var body := Rect2(0, ANTENNA, size.x, size.y - ANTENNA)
	_antenna(Vector2(size.x - 74, 0))
	_side_keys()
	# The edge, the shell, and the light along its top.
	_round(body, RUBBER, 46, Color(0, 0, 0, 0.55), 12)
	_round(body.grow(-5), SHELL.darkened(0.35), 42)
	_round(Rect2(body.position + Vector2(5, 5), body.size - Vector2(10, 14)), SHELL, 42)
	_round(Rect2(body.position + Vector2(9, 9), body.size - Vector2(18, 22)), SHELL.darkened(0.1), 38)
	for corner: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
		_grip(body, corner)
	for corner: Vector2 in [Vector2(0.07, 0.034), Vector2(0.93, 0.034), Vector2(0.07, 0.986), Vector2(0.93, 0.986)]:
		_screw(body.position + body.size * corner, corner.x * 9.0 + corner.y * 5.0)
	_top(body)
	# The recess the screen sits in.
	if get_child_count() > 0:
		var screen: Rect2 = (get_child(0) as Control).get_rect()
		_round(screen.grow(8), SHELL.darkened(0.55), 20)
		_round(Rect2(screen.position - Vector2(6, 4), screen.size + Vector2(12, 12)), SHELL.lightened(0.12), 18)
		_round(screen.grow(5), RUBBER, 18)


func _top(body: Rect2) -> void:
	var y: float = body.position.y + 24
	var font: Font = get_theme_default_font()
	# The speaker.
	var middle: float = body.size.x * 0.5
	_round(Rect2(middle - 66, y - 9, 132, 18), RUBBER, 9)
	for i: int in 13:
		draw_rect(Rect2(middle - 55 + i * 9, y - 4, 3, 8), SHELL.darkened(0.2))
	# The camera.
	draw_circle(Vector2(middle + 92, y), 10, RUBBER)
	draw_circle(Vector2(middle + 92, y), 6, Color("#0E2A33"))
	draw_circle(Vector2(middle + 90, y - 2), 2, Color(1, 1, 1, 0.5))
	# The message light.
	var lamp := Vector2(middle - 92, y)
	if light > 0.0:
		for ring: int in 4:
			draw_circle(lamp, 8.0 + ring * 5.0, Color(DriftingSensor.COLOR_IN_BAND, 0.12 * light))
	draw_circle(lamp, 8, RUBBER)
	draw_circle(lamp, 5, LIGHT_OFF.lerp(DriftingSensor.COLOR_IN_BAND, light))
	draw_circle(lamp - Vector2(1.5, 1.5), 1.5, Color(1, 1, 1, 0.35 + 0.5 * light))
	# Raised lettering, with its shadow.
	var at := Vector2(58, body.position.y + 59)
	_write(font, at + Vector2(0, 1), "FIELD PHONE // UPLINK", 16, RUBBER)
	_write(font, at, "FIELD PHONE // UPLINK", 16, SHELL.lightened(0.45))
	# A worn label.
	draw_set_transform(Vector2(body.size.x - 222, body.position.y + 45), -0.018)
	_round(Rect2(0, 0, 164, 19), Color("#D8D2BC"), 3)
	draw_rect(Rect2(0, 0, 8, 19), GRIP)
	_write(font, Vector2(16, 14), "INDICATION ONLY", 13, Color("#2A2A26"))
	draw_line(Vector2(122, 3), Vector2(144, 15), Color(1, 1, 1, 0.45), 2)
	draw_set_transform(Vector2.ZERO)


func _write(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _antenna(base: Vector2) -> void:
	_round(Rect2(base.x, base.y, 34, 60), SHELL, 14)
	_round(Rect2(base.x + 6, base.y + 5, 5, 40), SHELL.lightened(0.3), 3)
	for i: int in 2:
		draw_rect(Rect2(base.x, base.y + 15 + i * 6, 34, 2), RUBBER)


func _side_keys() -> void:
	for y: float in [190.0, 262.0]:
		_round(Rect2(-6, y, 14, 58), SHELL, 5)
		_round(Rect2(-5, y + 4, 3, 48), SHELL.lightened(0.3), 2)
	_round(Rect2(size.x - 8, 220, 14, 84), GRIP, 5)


## A rubber sleeve on a corner, with ribs.
func _grip(body: Rect2, corner: Vector2) -> void:
	var box := Vector2(50, 78)
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 44 if corner == Vector2.ZERO else 0
	style.corner_radius_top_right = 44 if corner == Vector2(1, 0) else 0
	style.corner_radius_bottom_left = 44 if corner == Vector2(0, 1) else 0
	style.corner_radius_bottom_right = 44 if corner == Vector2.ONE else 0
	style.set_border_width_all(3)
	style.bg_color = GRIP
	style.border_color = GRIP.darkened(0.4)
	var at: Vector2 = body.position + (body.size - box) * corner
	draw_style_box(style, Rect2(at, box))
	# The shell covers all but the edge.
	style.bg_color = SHELL.darkened(0.1)
	style.border_color = SHELL.darkened(0.35)
	var inward := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
	draw_style_box(style, Rect2(at + inward * 12.0, box))
	for i: int in 3:
		var y: float = at.y + 44 + i * 9 if corner.y == 0.0 else at.y + 16 + i * 9
		draw_rect(Rect2(at.x + (3.0 if corner.x == 0.0 else box.x - 10.0), y, 7, 3), GRIP.darkened(0.45))


func _screw(at: Vector2, turn: float) -> void:
	draw_circle(at, 8, SHELL.darkened(0.5))
	draw_circle(at, 6, SHELL.lightened(0.2))
	draw_set_transform(at, turn)
	draw_rect(Rect2(-5, -1, 10, 2), RUBBER)
	draw_rect(Rect2(-1, -5, 2, 10), RUBBER)
	draw_set_transform(Vector2.ZERO)


func _round(rect: Rect2, color: Color, radius: int, shadow: Color = Color.TRANSPARENT, shadow_size: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	draw_style_box(style, rect)
