class_name SetTheZero
extends Control
## Mini-game 1, Set the Zero (docs/design/quests_levels_story.md section 7.1). A
## needle sweeps a scale with a green sweet spot at zero. The first press stops
## it: the coarse adjust. It then sweeps again, slower, over a narrower scale
## that is as wide as the coarse stop was off. The second press is the fine
## adjust, and the score is how close that stop is to zero.
##
## One button plays it (Space, Enter, a click, or the gamepad's accept). Esc or
## the gamepad's cancel skips it, and so does SKIP. Positions are in scale units:
## the coarse scale runs from -1 to 1. The scoring is in the static functions,
## and advance() and press() play it with no frames.

## The score, 0 to 100, or MinigameScore.SKIPPED.
signal finished(score: int)

enum Stage { IDLE, COARSE, SETTLE, FINE, RESULT }

## One sweep there and back, at Standard. All [PLACEHOLDER].
const COARSE_PERIOD_S: float = 1.6
const FINE_PERIOD_S: float = 2.6
## The fine scale's half-width: as far off as the coarse stop was, within these.
const FINE_MIN: float = 0.15
const FINE_MAX: float = 0.5
## Half the sweet spot's width at Calibration 1 on Standard [PLACEHOLDER].
const BASE_SWEET: float = 0.03
## Section 7.3: the Calibration skill widens the sweet spot by up to this much more.
const SKILL_WIDENING: float = 1.0
## A stop this many sweet-spot half-widths from zero scores 0 [PLACEHOLDER].
const MISS_AT: float = 8.0
## Inside the sweet spot the score runs from 100 at zero down to this at its edge.
const SWEET_SCORE: int = 95
## A press sooner than this after a sweep starts is not taken: no double press.
const ARM_S: float = 0.25
## At the result a press sooner than this is not taken, so a double click on the
## fine stop can't close the result unread.
const RESULT_ARM_S: float = 0.4
## The most one frame may move the game on: a hitch must not jump the needle or
## run a timer out.
const MAX_STEP_S: float = 0.1
## Shown under the sweeps: what SKIP does at the bench.
const SKIP_HINT: String = "Esc/Skip calibrates without the game."
const SETTLE_S: float = 0.5
const RESULT_S: float = 1.4

const COLOR_BAR := Color(0.03, 0.06, 0.04)
const COLOR_EDGE := Color(0.3, 0.45, 0.33)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.8)
const COLOR_SWEET := Color(0.1, 0.55, 0.45)
const COLOR_MARK := Color(0.55, 1.0, 0.6)
const COLOR_NEEDLE := Color(1, 1, 1)
const COLOR_FINE_RANGE := Color(0.85, 0.95, 0.88, 0.12)

var _stage: Stage = Stage.IDLE
## Seconds in this stage.
var _time: float = 0.0
var _speed: float = 1.0
var _sweet: float = BASE_SWEET
var _phase: float = 0.0
var _fine_phase: float = 0.0
var _needle: float = 0.0
var _coarse_stop: float = 0.0
var _fine_stop: float = 0.0
var _score: int = MinigameScore.SKIPPED
## The real clock at the last frame, in microseconds.
var _last_usec: int = 0

@onready var _subject_label: Label = %SubjectLabel
@onready var _stage_label: Label = %StageLabel
@onready var _scale: Control = %Scale
@onready var _hint_label: Label = %HintLabel
@onready var _stop_button: Button = %StopButton
@onready var _skip_button: Button = %SkipButton


## Where a needle is `seconds` into a sweep: a steady run from one end of
## ±`amplitude` to the other and back each `period_s`. `phase` (0 to 1) is where
## in the sweep it starts.
static func needle_at(seconds: float, amplitude: float, period_s: float, phase: float = 0.0) -> float:
	var turn: float = fposmod(seconds / maxf(period_s, 0.001) + phase, 1.0)
	return amplitude * (4.0 * absf(turn - 0.5) - 1.0)


## Half the width of the fine scale after a coarse stop at `coarse_stop`.
static func fine_amplitude(coarse_stop: float) -> float:
	return clampf(absf(coarse_stop), FINE_MIN, FINE_MAX)


## Half the sweet spot's width. `share` (0 to 1) is how much of the skill's
## widening the player has: twice as wide at 1. `sweet_factor` is the difficulty's.
static func sweet_half_width(share: float, sweet_factor: float = 1.0) -> float:
	return BASE_SWEET * (1.0 + SKILL_WIDENING * clampf(share, 0.0, 1.0)) * maxf(sweet_factor, 0.0)


## The score, 0 to 100, of a fine stop at `fine_stop` with a sweet spot of
## ±`sweet_half`. The coarse stop only bounds where the fine stop can be. Inside
## the sweet spot it is 95 to 100; outside it falls in a straight line to 0 at
## MISS_AT half-widths.
static func score(coarse_stop: float, fine_stop: float, sweet_half: float) -> int:
	var reach: float = fine_amplitude(coarse_stop)
	var off: float = absf(clampf(fine_stop, -reach, reach)) / maxf(sweet_half, 0.000001)
	if off <= 1.0:
		return roundi(MinigameScore.MAX_SCORE - (MinigameScore.MAX_SCORE - SWEET_SCORE) * off)
	return clampi(floori(SWEET_SCORE - (off - 1.0) * SWEET_SCORE / (MISS_AT - 1.0)), 0, SWEET_SCORE - 1)


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	hide()
	set_process(false)
	_scale.draw.connect(_draw_scale)
	_stop_button.pressed.connect(press)
	_skip_button.pressed.connect(skip)


## Starts a game. `share` is the player's part of the skill's widening (0 to 1),
## `mode` a MinigameSettings.Mode, and `motion_seed` sets where the sweeps start.
func play(share: float, mode: int, motion_seed: int, subject: String = "") -> void:
	if is_playing():
		skip()
	_sweet = sweet_half_width(share, MinigameSettings.sweet_factor(mode))
	_speed = MinigameSettings.speed_factor(mode)
	var rng := RandomNumberGenerator.new()
	rng.seed = motion_seed
	_phase = rng.randf()
	_fine_phase = rng.randf()
	_score = MinigameScore.SKIPPED
	_coarse_stop = 0.0
	_fine_stop = 0.0
	_subject_label.text = subject
	_stop_button.disabled = false
	_begin(Stage.COARSE)
	show()
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func is_playing() -> bool:
	return _stage != Stage.IDLE


func stage() -> Stage:
	return _stage


func needle() -> float:
	return _needle


func sweet_half() -> float:
	return _sweet


## Real seconds, not the farm's: a faster or stopped farm clock (Engine.time_scale)
## must not move the needle.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	advance(frame_step((now - _last_usec) / 1000000.0))
	_last_usec = now


## What one frame of `real_seconds` moves the game on by.
static func frame_step(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_STEP_S)


## Moves the game on by `seconds`. Tests call it in place of frames.
func advance(seconds: float) -> void:
	if _stage == Stage.IDLE:
		return
	_time += seconds
	match _stage:
		Stage.COARSE:
			_needle = needle_at(_time, 1.0, COARSE_PERIOD_S / _speed, _phase)
		Stage.SETTLE:
			if _time >= SETTLE_S:
				_begin(Stage.FINE)
		Stage.FINE:
			_needle = needle_at(_time, fine_amplitude(_coarse_stop), FINE_PERIOD_S / _speed, _fine_phase)
		Stage.RESULT:
			if _time >= RESULT_S:
				_finish(_score)
	_scale.queue_redraw()


## The one button: stops the needle, and at the result goes on.
func press() -> void:
	match _stage:
		Stage.COARSE:
			if _time >= ARM_S:
				_coarse_stop = _needle
				_begin(Stage.SETTLE)
		Stage.FINE:
			if _time >= ARM_S:
				_fine_stop = _needle
				_score = score(_coarse_stop, _fine_stop, _sweet)
				_begin(Stage.RESULT)
		Stage.RESULT:
			if _time >= RESULT_ARM_S:
				_finish(_score)


## Ends the game with no score. At the result the score stands.
func skip() -> void:
	if _stage != Stage.IDLE:
		_finish(_score if _stage == Stage.RESULT else MinigameScore.SKIPPED)


func _begin(next: Stage) -> void:
	_stage = next
	_time = 0.0
	match next:
		Stage.COARSE:
			_needle = needle_at(0.0, 1.0, COARSE_PERIOD_S / _speed, _phase)
			_stage_label.text = "STEP 1 OF 2: COARSE ADJUST"
			_hint_label.text = "Stop the needle as near zero as you can. Nearer leaves a narrower scale for the fine adjust.\n" + SKIP_HINT
		Stage.SETTLE:
			_stage_label.text = "COARSE STOP TAKEN"
			_hint_label.text = "Now the fine adjust."
		Stage.FINE:
			_needle = needle_at(0.0, fine_amplitude(_coarse_stop), FINE_PERIOD_S / _speed, _fine_phase)
			_stage_label.text = "STEP 2 OF 2: FINE ADJUST"
			_hint_label.text = "Stop the needle inside the marked sweet spot at zero.\n" + SKIP_HINT
		Stage.RESULT:
			_stage_label.text = "ZERO SET"
			_hint_label.text = MinigameScore.result_text(_score)
			_stop_button.disabled = true
	_scale.queue_redraw()


func _finish(with_score: int) -> void:
	_stage = Stage.IDLE
	set_process(false)
	hide()
	finished.emit(with_score)


func _input(event: InputEvent) -> void:
	if _stage == Stage.IDLE or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		press()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


## A click anywhere off the two buttons is the one button too.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		press()


## Half the width of what the scale shows now.
func _view() -> float:
	return fine_amplitude(_coarse_stop) if _stage in [Stage.FINE, Stage.RESULT] else 1.0


func _draw_scale() -> void:
	var view: float = _view()
	var w: float = _scale.size.x
	var h: float = _scale.size.y
	var top: float = h * 0.3
	var bar_h: float = h * 0.4
	var mid: float = w * 0.5
	var per_unit: float = (w * 0.5 - 6.0) / view
	_scale.draw_rect(Rect2(0, top, w, bar_h), COLOR_BAR)
	_scale.draw_rect(Rect2(0, top, w, bar_h), COLOR_EDGE, false, 2.0)
	if _stage in [Stage.COARSE, Stage.SETTLE]:
		# Where a coarse stop leaves the narrowest fine scale.
		_scale.draw_rect(Rect2(mid - FINE_MIN * per_unit, top, 2.0 * FINE_MIN * per_unit, bar_h), COLOR_FINE_RANGE)
	# The sweet spot: filled, and bracketed above and below, so colour alone does not tell it.
	var sweet_px: float = maxf(_sweet * per_unit, 2.0)
	_scale.draw_rect(Rect2(mid - sweet_px, top, 2.0 * sweet_px, bar_h), COLOR_SWEET)
	for side: float in [-1.0, 1.0]:
		var edge_x: float = mid + side * sweet_px
		_scale.draw_line(Vector2(edge_x, top - 10.0), Vector2(edge_x, top + bar_h + 10.0), COLOR_MARK, 2.0)
		_scale.draw_line(Vector2(edge_x, top - 10.0), Vector2(edge_x - side * 6.0, top - 10.0), COLOR_MARK, 2.0)
		_scale.draw_line(Vector2(edge_x, top + bar_h + 10.0), Vector2(edge_x - side * 6.0, top + bar_h + 10.0), COLOR_MARK, 2.0)
	for i: int in range(-10, 11):
		var tick_x: float = mid + i * 0.1 * view * per_unit
		var is_long: bool = i % 5 == 0
		_scale.draw_line(Vector2(tick_x, top + bar_h), Vector2(tick_x, top + bar_h - (14.0 if is_long else 7.0)),
			COLOR_TICK, 2.0 if is_long else 1.0)
	var font: Font = get_theme_default_font()
	_scale.draw_string(font, Vector2(mid - 20.0, h - 2.0), "0", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 20, COLOR_MARK)
	if _stage == Stage.FINE or _stage == Stage.RESULT:
		# Where the coarse stop was: the end of the fine scale it set.
		var coarse_x: float = mid + signf(_coarse_stop) * view * per_unit
		_scale.draw_line(Vector2(coarse_x, top), Vector2(coarse_x, top + bar_h), COLOR_TICK, 3.0)
	var needle_x: float = mid + clampf(_needle, -view, view) * per_unit
	_scale.draw_line(Vector2(needle_x, top - 16.0), Vector2(needle_x, top + bar_h + 4.0), COLOR_NEEDLE, 4.0)
	_scale.draw_colored_polygon(PackedVector2Array([
		Vector2(needle_x - 9.0, top - 24.0), Vector2(needle_x + 9.0, top - 24.0), Vector2(needle_x, top - 8.0)]), COLOR_NEEDLE)
