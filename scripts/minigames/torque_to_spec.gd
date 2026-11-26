class_name TorqueToSpec
extends Control
## Mini-game 4, Torque to Spec (docs/design/quests_levels_story.md section
## 7.1). Five wheel nuts, tightened in star order; the game shows which is next.
## For each, the player holds the button while the torque climbs and lets go at
## the click line. A nut's closeness is how near the torque was to the line as
## the button came up, and the score is the mean of the five.
##
## One button plays it (Space, Enter, the mouse button, or the gamepad's
## accept). Esc or the gamepad's cancel skips it, and so does SKIP. Nothing
## moves until a press: each nut waits for its own, with no clock on the wait.
## No hold is longer than MAX_HOLD_S: the game lets go of a longer one, and a
## nut the game let go of is a miss. Torque is in shares of the bar: 0 is slack and 1 is the
## bar's end. The scoring and the climb are in the static functions, and
## advance() and hold() play it with no frames.

## The score, 0 to 100, or MinigameScore.SKIPPED.
signal finished(score: int)

## READY waits for the press on the next nut, CLIMB is the hold, SET shows what
## that nut got.
enum Stage { IDLE, READY, CLIMB, SET, RESULT }

const GAME_NAME: String = "Torque"
## All the numbers below are [PLACEHOLDER].
const NUTS: int = 5
## Star order: the place round the wheel (0 at the top, clockwise) of the
## first nut tightened, the second, and so on. Each is two places on.
const STAR_ORDER: Array[int] = [0, 2, 4, 1, 3]
## Where a nut's click line may be, in shares of the bar. The seed picks.
const LINE_MIN: float = 0.6
const LINE_MAX: float = 0.85
## How long a steady climb takes to reach the line on Standard, in seconds.
## The seed picks for each nut; Relaxed and Sharp scale the climb's speed
## (MinigameSettings.speed_factor).
const CLIMB_MIN_S: float = 0.9
const CLIMB_MAX_S: float = 1.5
## The climb is not steady: its speed swells and eases by this share, so many
## times a second, from a start the seed picks. It never stops or runs back.
const SURGE: float = 0.3
const SURGE_HZ: float = 1.2
## Half the sweet spot's width at Calibration 1 on Standard, in shares of the bar.
const BASE_SWEET: float = 0.04
## Section 7.3: the Calibration skill widens the sweet spot by up to this much more.
const SKILL_WIDENING: float = 1.0
## Inside the sweet spot a nut's closeness runs from 100 at the line down to
## this at its edge. This far from the line, in shares of the bar, it is 0:
## a fixed distance, so Calibration and the difficulty widen only the sweet
## spot and never move where a miss begins.
const SWEET_SCORE: int = 95
const MISS_DISTANCE: float = 0.32
## Section 7.5 allows no hold longer than 3 s. This game lets go sooner, at
## 2.5 s: the slowest climb on Relaxed is past its line by then. A nut the
## game let go of (at the cap or at the bar's end) scores MISSED: the player
## never let go, so holding every nut to the top earns nothing.
const MAX_HOLD_S: float = 2.5
const MISSED: int = 0
const HOLD_CAP_HINT: String = "You never let go: this nut is a miss."
## How long a nut's own result shows before the next nut waits.
const SET_S: float = 0.6
## At the result a press sooner than this is not taken.
const RESULT_ARM_S: float = 0.4
const RESULT_S: float = 1.6
## The most one frame may move the game on, and the fixed step it is played in:
## the same presses at the same times give the same score at any frame rate.
const MAX_STEP_S: float = 0.1
const STEP_S: float = 1.0 / 60.0
## Rounding slack, so 0.05 s is three steps and not two and a carry.
const STEP_SLACK_S: float = 0.000001
## Shown under the view: what SKIP does in Bram's bay.
const SKIP_HINT: String = "Esc/Skip has Bram do the nuts without the game."

const COLOR_BAR := Color(0.03, 0.06, 0.04)
const COLOR_EDGE := Color(0.3, 0.45, 0.33)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.5)
const COLOR_SWEET := Color(0.1, 0.55, 0.45, 0.55)
const COLOR_MARK := Color(0.55, 1.0, 0.6)
const COLOR_OUT := Color(1.0, 0.75, 0.3)
const COLOR_FILL := Color(1, 1, 1)

var _stage: Stage = Stage.IDLE
## Seconds in this stage.
var _time: float = 0.0
## The nut being tightened, or waiting to be: its turn, counted from 0.
var _nut: int = 0
## Each nut's click line, seconds of steady climb to it, and surge start.
var _lines: Array[float] = []
var _climb_s: Array[float] = []
var _phases: Array[float] = []
## The difficulty's speed on the climb.
var _speed: float = 1.0
var _sweet: float = BASE_SWEET
var _torque: float = 0.0
var _held: bool = false
var _hold_s: float = 0.0
## Each done nut's closeness, in the order tightened.
var _closeness: Array[int] = []
var _score: int = MinigameScore.SKIPPED
var _carry_s: float = 0.0
var _last_usec: int = 0

@onready var _subject_label: Label = %SubjectLabel
@onready var _stage_label: Label = %StageLabel
@onready var _view: Control = %View
@onready var _hint_label: Label = %HintLabel
@onready var _hold_button: Button = %HoldButton
@onready var _skip_button: Button = %SkipButton


## Half the sweet spot's width. `share` (0 to 1) is how much of the skill's
## widening the player has: twice as wide at 1. `sweet_factor` is the difficulty's.
static func sweet_half_width(share: float, sweet_factor: float = 1.0) -> float:
	return BASE_SWEET * (1.0 + SKILL_WIDENING * clampf(share, 0.0, 1.0)) * maxf(sweet_factor, 0.0)


## How fast the torque climbs `hold_s` into a hold, in shares of the bar a
## second: `line` reached in `climb_s` if it were steady, swelling and easing
## round that. Always over 0.
static func climb_rate(hold_s: float, line: float, climb_s: float, phase: float, speed: float = 1.0) -> float:
	var steady: float = line / maxf(climb_s, 0.000001) * maxf(speed, 0.0)
	return steady * (1.0 + SURGE * sin(TAU * (SURGE_HZ * hold_s + phase)))


## One nut's closeness, 0 to 100: the torque it was left at against its click
## line, with a sweet spot of ±`sweet_half`. Inside the sweet spot it is 95 to
## 100; outside it falls in a straight line to 0 at MISS_DISTANCE from the
## line, wherever the sweet spot ends. Under the line and over it count the same.
static func closeness(torque: float, line: float, sweet_half: float = BASE_SWEET) -> int:
	# Snapped, so the same distance under and over never lands on two sides of a whole point.
	var off: float = snappedf(absf(torque - line), 0.000001)
	var sweet: float = clampf(sweet_half, 0.000001, MISS_DISTANCE * 0.5)
	if off <= sweet:
		return roundi(MinigameScore.MAX_SCORE - (MinigameScore.MAX_SCORE - SWEET_SCORE) * off / sweet)
	return clampi(floori(SWEET_SCORE * (MISS_DISTANCE - off) / (MISS_DISTANCE - sweet)), 0, SWEET_SCORE - 1)


## The score, 0 to 100: the mean closeness of the five nuts. A nut not done
## counts as 0.
static func score(closenesses: Array[int]) -> int:
	var sum: int = 0
	for one: int in closenesses:
		sum += clampi(one, 0, MinigameScore.MAX_SCORE)
	return clampi(roundi(float(sum) / float(NUTS)), 0, MinigameScore.MAX_SCORE)


## What one frame of `real_seconds` moves the game on by.
static func frame_step(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_STEP_S)


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	hide()
	set_process(false)
	_view.draw.connect(_draw_view)
	_hold_button.button_down.connect(hold.bind(true))
	_hold_button.button_up.connect(hold.bind(false))
	_skip_button.pressed.connect(skip)


## Starts a game. `share` is the player's part of the skill's widening (0 to 1),
## `mode` a MinigameSettings.Mode, and `motion_seed` sets each nut's click line
## and climb.
func play(share: float, mode: int, motion_seed: int, subject: String = "") -> void:
	if is_playing():
		skip()
	_sweet = sweet_half_width(share, MinigameSettings.sweet_factor(mode))
	_speed = MinigameSettings.speed_factor(mode)
	var rng := RandomNumberGenerator.new()
	rng.seed = motion_seed
	_lines = []
	_climb_s = []
	_phases = []
	for i: int in NUTS:
		_lines.append(rng.randf_range(LINE_MIN, LINE_MAX))
		_climb_s.append(rng.randf_range(CLIMB_MIN_S, CLIMB_MAX_S))
		_phases.append(rng.randf())
	_closeness = []
	_score = MinigameScore.SKIPPED
	_nut = 0
	_torque = 0.0
	_subject_label.text = subject
	_hold_button.disabled = false
	_begin(Stage.READY)
	show()
	_carry_s = 0.0
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func is_playing() -> bool:
	return _stage != Stage.IDLE


func stage() -> Stage:
	return _stage


## How many nuts are done, 0 to NUTS.
func nuts_done() -> int:
	return _closeness.size()


## The place round the wheel of the nut that is next (or being tightened): 0 at
## the top, clockwise. -1 when all five are done.
func next_place() -> int:
	return STAR_ORDER[_nut] if _closeness.size() < NUTS and _nut < NUTS else -1


## The torque on the nut being tightened, and its click line.
func torque() -> float:
	return _torque


func line() -> float:
	return _lines[mini(_nut, NUTS - 1)] if not _lines.is_empty() else 0.0


func sweet_half() -> float:
	return _sweet


func is_held() -> bool:
	return _held


func is_in_sweet() -> bool:
	return absf(_torque - line()) <= _sweet


## Each done nut's closeness, in the order tightened.
func closenesses() -> Array[int]:
	return _closeness.duplicate()


## Real seconds, not the farm's: a faster or stopped farm clock (Engine.time_scale)
## must not move the game.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	advance(frame_step((now - _last_usec) / 1000000.0))
	_last_usec = now


## Moves the game on by `seconds`. Tests call it in place of frames. The game
## moves only in whole steps of STEP_S; what is left of `seconds` is carried to
## the next call, so the frame rate and uneven frames cannot change a score.
func advance(seconds: float) -> void:
	_carry_s += maxf(seconds, 0.0)
	while _carry_s >= STEP_S - STEP_SLACK_S and _stage != Stage.IDLE:
		_carry_s = maxf(_carry_s - STEP_S, 0.0)
		_step(STEP_S)
	if _stage == Stage.IDLE:
		_carry_s = 0.0
	if _stage != Stage.IDLE:
		_view.queue_redraw()


func _step(seconds: float) -> void:
	_time += seconds
	match _stage:
		Stage.CLIMB:
			_climb(seconds)
		Stage.SET:
			if _time >= SET_S - STEP_SLACK_S:
				_nut += 1
				_begin(Stage.READY)
		Stage.RESULT:
			if _time >= RESULT_S:
				_finish(_score)


func _climb(seconds: float) -> void:
	_torque = minf(_torque + climb_rate(_hold_s, _lines[_nut], _climb_s[_nut], _phases[_nut], _speed) * seconds, 1.0)
	_hold_s += seconds
	if _hold_s >= MAX_HOLD_S - STEP_SLACK_S or _torque >= 1.0:
		_set_nut(true)


## The one button, down or up. Down on a waiting nut starts its climb; up ends
## it, and where the torque is then is the nut's. At the result a press goes on.
func hold(down: bool) -> void:
	match _stage:
		Stage.READY:
			if down:
				_begin(Stage.CLIMB)
				_held = true
		Stage.CLIMB:
			if not down and _held:
				_set_nut(false)
		Stage.RESULT:
			if down and _time >= RESULT_ARM_S:
				_finish(_score)


## The nut is left at the torque it has. `capped`: the game let go, not the
## player, and the nut is a miss wherever the torque stood.
func _set_nut(capped: bool) -> void:
	_closeness.append(MISSED if capped else closeness(_torque, _lines[_nut], _sweet))
	if _closeness.size() >= NUTS:
		_score = score(_closeness)
		_begin(Stage.RESULT)
		return
	_begin(Stage.SET)
	if capped:
		_hint_label.text = HOLD_CAP_HINT + "\n" + _hint_label.text


## Ends the game with no score. At the result the score stands.
func skip() -> void:
	if _stage != Stage.IDLE:
		_finish(_score if _stage == Stage.RESULT else MinigameScore.SKIPPED)


func _begin(next: Stage) -> void:
	_stage = next
	_time = 0.0
	# A hold never carries into a stage: each nut takes a press of its own.
	_held = false
	_hold_s = 0.0
	match next:
		Stage.READY:
			_torque = 0.0
			_stage_label.text = "NUT %d OF %d: PRESS AND HOLD" % [_nut + 1, NUTS]
			_hint_label.text = "Star order: the marked nut is next. Hold while the torque climbs, let go at the click line.\n" + SKIP_HINT
		Stage.CLIMB:
			_stage_label.text = "NUT %d OF %d: LET GO AT THE CLICK" % [_nut + 1, NUTS]
			_hint_label.text = "Let go at the click line.\n" + SKIP_HINT
		Stage.SET:
			_stage_label.text = "NUT %d OF %d: %s" % [_nut + 1, NUTS, _said()]
			_hint_label.text = "Closeness %d of %d.\n%s" % [_closeness[-1], MinigameScore.MAX_SCORE, SKIP_HINT]
		Stage.RESULT:
			_stage_label.text = "FIVE NUTS TORQUED"
			_hint_label.text = MinigameScore.service_text(_score)
			_hold_button.disabled = true
	_view.queue_redraw()


## Where the torque is against the nut's click line, in words.
func _said() -> String:
	if is_in_sweet():
		return "ON THE CLICK"
	return "UNDER THE CLICK" if _torque < line() else "OVER THE CLICK"


func _finish(with_score: int) -> void:
	_stage = Stage.IDLE
	_held = false
	set_process(false)
	hide()
	finished.emit(with_score)


func _input(event: InputEvent) -> void:
	if _stage == Stage.IDLE or not is_visible_in_tree() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		hold(true)
	elif event.is_action_released(&"ui_accept"):
		get_viewport().set_input_as_handled()
		hold(false)
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


## Off the two buttons, the mouse button is the one button too.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		hold(event.pressed)


func _draw_view() -> void:
	var w: float = _view.size.x
	var h: float = _view.size.y
	var font: Font = get_theme_default_font()
	_view.draw_rect(Rect2(0, 0, w, h), COLOR_BAR)
	_view.draw_rect(Rect2(0, 0, w, h), COLOR_EDGE, false, 2.0)
	# The wheel, on the left: five nuts round the hub. Each has its turn's number
	# on it; a done nut is filled, and the next one has a ring and a pointer, so
	# which is next is told by shape and number, not by colour alone.
	var hub := Vector2(h * 0.5 + 6.0, h * 0.5)
	var rim: float = h * 0.5 - 10.0
	var ring: float = rim * 0.58
	_view.draw_arc(hub, rim, 0.0, TAU, 48, COLOR_EDGE, 3.0)
	_view.draw_arc(hub, rim * 0.2, 0.0, TAU, 24, COLOR_EDGE, 2.0)
	var next: int = next_place()
	for turn: int in NUTS:
		var place: int = STAR_ORDER[turn]
		var angle: float = TAU * place / NUTS - PI * 0.5
		var out := Vector2(cos(angle), sin(angle))
		var at: Vector2 = hub + out * ring
		var done: bool = turn < _closeness.size()
		if done:
			_view.draw_circle(at, 13.0, COLOR_EDGE)
		_view.draw_arc(at, 13.0, 0.0, TAU, 20, COLOR_TICK, 2.0)
		if place == next and not done:
			_view.draw_arc(at, 19.0, 0.0, TAU, 24, COLOR_MARK, 3.0)
			var side := Vector2(-out.y, out.x) * 7.0
			var tail: Vector2 = hub + out * (rim + 4.0)
			_view.draw_colored_polygon(PackedVector2Array([at + out * 21.0, tail + side, tail - side]), COLOR_MARK)
		_view.draw_string(font, at + Vector2(-13.0, 6.0), str(turn + 1), HORIZONTAL_ALIGNMENT_CENTER, 26.0, 16, COLOR_FILL if done or place == next else COLOR_TICK)
	# The torque bar, on the right: slack at the left end, the click line with
	# its sweet spot, and the torque filling toward it.
	var left: float = h + 30.0
	var bar_w: float = w - left - 24.0
	var bar_y: float = h * 0.5 - 18.0
	var bar_h: float = 36.0
	if bar_w <= 0.0:
		return
	var click: float = line()
	var mark: Color = COLOR_MARK if is_in_sweet() else COLOR_OUT
	_view.draw_rect(Rect2(left, bar_y, bar_w, bar_h), COLOR_BAR)
	_view.draw_rect(Rect2(left + (click - _sweet) * bar_w, bar_y, 2.0 * _sweet * bar_w, bar_h), COLOR_SWEET)
	if _stage in [Stage.CLIMB, Stage.SET, Stage.RESULT]:
		_view.draw_rect(Rect2(left, bar_y + 8.0, clampf(_torque, 0.0, 1.0) * bar_w, bar_h - 16.0), COLOR_FILL if _stage == Stage.CLIMB else mark)
	_view.draw_rect(Rect2(left, bar_y, bar_w, bar_h), COLOR_EDGE, false, 2.0)
	# The click line: a line through the bar with a notch over and under it.
	var click_x: float = left + click * bar_w
	_view.draw_line(Vector2(click_x, bar_y - 14.0), Vector2(click_x, bar_y + bar_h + 14.0), COLOR_TICK, 2.0)
	for notch_y: float in [bar_y - 14.0, bar_y + bar_h + 14.0]:
		_view.draw_line(Vector2(click_x - 8.0, notch_y), Vector2(click_x + 8.0, notch_y), COLOR_TICK, 2.0)
	_view.draw_string(font, Vector2(click_x - 60.0, bar_y - 22.0), "CLICK", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, COLOR_TICK)
	_view.draw_string(font, Vector2(left, bar_y + bar_h + 22.0), "SLACK", HORIZONTAL_ALIGNMENT_LEFT, 120.0, 14, COLOR_TICK)
	# In words too.
	if _stage == Stage.SET or _stage == Stage.RESULT:
		_view.draw_string(font, Vector2(left, h - 14.0), _said(), HORIZONTAL_ALIGNMENT_LEFT, bar_w, 22, mark)
	elif _stage == Stage.READY:
		_view.draw_string(font, Vector2(left, h - 14.0), "NUT %d IS NEXT" % (_nut + 1), HORIZONTAL_ALIGNMENT_LEFT, bar_w, 22, COLOR_MARK)
