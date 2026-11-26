class_name HoldTheReading
extends Control
## Mini-game 3, Hold the Reading (docs/design/quests_levels_story.md section
## 7.1). The reading wanders while the standard settles, and the wander calms as
## the run goes on. The player's bracket is as tall as the tolerance band:
## holding the button lifts it, letting go lets it drop. The score is the share
## of the run the reading spent inside the bracket.
##
## One button plays it (Space, Enter, the mouse button, or the gamepad's
## accept). Esc or the gamepad's cancel skips it, and so does SKIP. Nothing
## moves until the first press, and no hold is longer than MAX_HOLD_S: the game
## lets go of a longer one. Positions are in scale units: the chart runs from -1
## to 1. The scoring and the wander are in the static functions, and advance()
## and hold() play it with no frames.

## The score, 0 to 100, or MinigameScore.SKIPPED.
signal finished(score: int)

enum Stage { IDLE, READY, HOLD, RESULT }

## The run, in real seconds, on every setting (section 7.1: 10 to 15 s). All
## the numbers below are [PLACEHOLDER].
const RUN_S: float = 12.0
## The wander: a sum of slow waves, each a share of AMPLITUDE and so many turns a
## second of the wander's own clock.
const AMPLITUDE: float = 0.8
const WAVE_HZ: Array[float] = [0.11, 0.19, 0.31]
const WAVE_SHARE: Array[float] = [0.5, 0.3, 0.2]
## The standard settles: the wander's size falls in a straight line to this share
## of itself by the end of the run.
const CALM_TO: float = 0.35
## Section 7.3: at Uncertainty 99 the wander's clock runs this much slower (half
## speed).
const SKILL_SLOWING: float = 0.5
## Half the bracket's height on Standard. Relaxed and Sharp scale it
## (MinigameSettings.sweet_factor); no skill does.
const BASE_BAND: float = 0.18
## The bracket: pushed up while the button is held, pulled down while it is not,
## and slowed by drag, so it tops out near LIFT / DRAG a second.
const LIFT: float = 5.0
const FALL: float = 5.0
const DRAG: float = 4.0
## Section 7.5: no hold longer than 3 s. The game lets go of a longer one.
const MAX_HOLD_S: float = 2.5
const HOLD_CAP_HINT: String = "The hold ran out. Press again to lift."
## At the result a press sooner than this is not taken.
const RESULT_ARM_S: float = 0.4
const RESULT_S: float = 1.6
## The most one frame may move the game on, and the fixed step it is played in:
## the same presses at the same times give the same score at any frame rate.
const MAX_STEP_S: float = 0.1
const STEP_S: float = 1.0 / 60.0
## Shown under the chart: what SKIP does at the bench.
const SKIP_HINT: String = "Esc/Skip calibrates without the game."
## How much of the run the chart's trace shows, in seconds.
const TRACE_S: float = 4.0

const COLOR_BAR := Color(0.03, 0.06, 0.04)
const COLOR_EDGE := Color(0.3, 0.45, 0.33)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.5)
const COLOR_BAND := Color(0.1, 0.55, 0.45, 0.55)
const COLOR_MARK := Color(0.55, 1.0, 0.6)
const COLOR_OUT := Color(1.0, 0.75, 0.3)
const COLOR_TRACE := Color(1, 1, 1)

var _stage: Stage = Stage.IDLE
## Seconds in this stage.
var _time: float = 0.0
## The wander's own clock, and how fast it runs against the real one.
var _wander_s: float = 0.0
var _wander_speed: float = 1.0
var _phases: Array[float] = []
var _band: float = BASE_BAND
var _reading: float = 0.0
var _bracket: float = 0.0
var _bracket_speed: float = 0.0
var _held: bool = false
var _hold_s: float = 0.0
var _inside_s: float = 0.0
## How far the reading has moved in this run, in scale units.
var _travel: float = 0.0
var _trace: PackedFloat32Array = PackedFloat32Array()
var _score: int = MinigameScore.SKIPPED
## The real clock at the last frame, in microseconds.
var _last_usec: int = 0

@onready var _subject_label: Label = %SubjectLabel
@onready var _stage_label: Label = %StageLabel
@onready var _chart: Control = %Chart
@onready var _hint_label: Label = %HintLabel
@onready var _hold_button: Button = %HoldButton
@onready var _skip_button: Button = %SkipButton


## How fast the wander's clock runs for a player with `share` (0 to 1) of the
## Uncertainty skill's slowing: 1 with none, half speed with all of it.
static func wander_factor(share: float) -> float:
	return 1.0 - SKILL_SLOWING * clampf(share, 0.0, 1.0)


## How big the wander still is `progress` (0 to 1) of the way through the run.
static func calm_at(progress: float) -> float:
	return lerpf(1.0, CALM_TO, clampf(progress, 0.0, 1.0))


## Where the reading is at `wander_s` on the wander's clock, `progress` of the
## way through the run. `phases` (one per wave, 0 to 1) come from the seed.
static func reading_at(wander_s: float, progress: float, phases: Array[float]) -> float:
	var sum: float = 0.0
	for i: int in WAVE_HZ.size():
		var phase: float = phases[i] if i < phases.size() else 0.0
		sum += WAVE_SHARE[i] * sin(TAU * (WAVE_HZ[i] * wander_s + phase))
	return AMPLITUDE * calm_at(progress) * sum


## Half the bracket's height. `sweet_factor` is the difficulty's.
static func band_half(sweet_factor: float = 1.0) -> float:
	return BASE_BAND * maxf(sweet_factor, 0.0)


## The score, 0 to 100: the share of the run the reading was inside the bracket.
static func score(inside_s: float, run_s: float = RUN_S) -> int:
	return clampi(roundi(MinigameScore.MAX_SCORE * inside_s / maxf(run_s, 0.001)), 0, MinigameScore.MAX_SCORE)


## What one frame of `real_seconds` moves the game on by.
static func frame_step(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_STEP_S)


func _ready() -> void:
	hide()
	set_process(false)
	_chart.draw.connect(_draw_chart)
	_hold_button.button_down.connect(hold.bind(true))
	_hold_button.button_up.connect(hold.bind(false))
	_skip_button.pressed.connect(skip)


## Starts a game. `share` is the player's part of the skill's slowing (0 to 1),
## `mode` a MinigameSettings.Mode, and `motion_seed` sets the wander.
func play(share: float, mode: int, motion_seed: int, subject: String = "") -> void:
	if is_playing():
		skip()
	_band = band_half(MinigameSettings.sweet_factor(mode))
	_wander_speed = MinigameSettings.speed_factor(mode) * wander_factor(share)
	var rng := RandomNumberGenerator.new()
	rng.seed = motion_seed
	_phases = []
	for i: int in WAVE_HZ.size():
		_phases.append(rng.randf())
	_score = MinigameScore.SKIPPED
	_wander_s = 0.0
	_inside_s = 0.0
	_travel = 0.0
	_held = false
	_hold_s = 0.0
	_reading = reading_at(0.0, 0.0, _phases)
	# The bracket starts on the reading: the first press is never a chase.
	_bracket = clampf(_reading, -1.0 + _band, 1.0 - _band)
	_bracket_speed = 0.0
	_trace = PackedFloat32Array()
	_subject_label.text = subject
	_hold_button.disabled = false
	_begin(Stage.READY)
	show()
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func is_playing() -> bool:
	return _stage != Stage.IDLE


func stage() -> Stage:
	return _stage


func reading() -> float:
	return _reading


func bracket() -> float:
	return _bracket


func band() -> float:
	return _band


func is_held() -> bool:
	return _held


func is_inside() -> bool:
	return absf(_reading - _bracket) <= _band


## How far the reading has moved in this run so far.
func travel() -> float:
	return _travel


## Real seconds, not the farm's: a faster or stopped farm clock (Engine.time_scale)
## must not move the game.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	advance(frame_step((now - _last_usec) / 1000000.0))
	_last_usec = now


## Moves the game on by `seconds`. Tests call it in place of frames.
func advance(seconds: float) -> void:
	var left: float = maxf(seconds, 0.0)
	while left > 0.0 and _stage != Stage.IDLE:
		var step: float = minf(left, STEP_S)
		left -= step
		_step(step)
	if _stage != Stage.IDLE:
		_chart.queue_redraw()


func _step(seconds: float) -> void:
	_time += seconds
	match _stage:
		Stage.HOLD:
			_run(seconds)
		Stage.RESULT:
			if _time >= RESULT_S:
				_finish(_score)


func _run(seconds: float) -> void:
	if _held:
		_hold_s += seconds
		if _hold_s >= MAX_HOLD_S:
			_held = false
			if not _hint_label.text.begins_with(HOLD_CAP_HINT):
				_hint_label.text = HOLD_CAP_HINT + "\n" + _hint_label.text
	_bracket_speed += ((LIFT if _held else -FALL) - DRAG * _bracket_speed) * seconds
	_bracket += _bracket_speed * seconds
	var top: float = 1.0 - _band
	if absf(_bracket) >= top:
		_bracket = clampf(_bracket, -top, top)
		_bracket_speed = 0.0
	_wander_s += seconds * _wander_speed
	var before: float = _reading
	_reading = reading_at(_wander_s, _time / RUN_S, _phases)
	_travel += absf(_reading - before)
	if is_inside():
		_inside_s += seconds
	_trace.append(_reading)
	var kept: int = ceili(TRACE_S / STEP_S)
	if _trace.size() > kept:
		_trace = _trace.slice(_trace.size() - kept)
	if _time >= RUN_S:
		_score = score(_inside_s)
		_begin(Stage.RESULT)


## The one button, down or up. The first press starts the run; in it the hold
## lifts the bracket; at the result a press goes on.
func hold(down: bool) -> void:
	if down == _held and _stage == Stage.HOLD:
		return
	if not down:
		_held = false
		return
	match _stage:
		Stage.READY:
			_begin(Stage.HOLD)
			_held = true
			_hold_s = 0.0
		Stage.HOLD:
			_held = true
			_hold_s = 0.0
			if _hint_label.text.begins_with(HOLD_CAP_HINT):
				_hint_label.text = _hint_label.text.trim_prefix(HOLD_CAP_HINT + "\n")
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
	# A hold never carries into a stage: each takes a press of its own.
	_held = false
	match next:
		Stage.READY:
			_stage_label.text = "THE STANDARD IS SETTLING"
			_hint_label.text = "Hold to lift your bracket, let go to let it drop. Keep the reading inside it. Press to start.\n" + SKIP_HINT
		Stage.HOLD:
			_stage_label.text = "HOLD THE READING"
			_hint_label.text = "Hold to lift, let go to drop. The reading calms as the standard settles.\n" + SKIP_HINT
		Stage.RESULT:
			_stage_label.text = "READING TAKEN"
			_hint_label.text = MinigameScore.result_text(_score, MinigameScore.HOLD_THE_READING)
			_hold_button.disabled = true
	_chart.queue_redraw()


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


func _draw_chart() -> void:
	var w: float = _chart.size.x
	var h: float = _chart.size.y
	var time_h: float = 10.0
	var plot_h: float = h - time_h - 6.0
	var mid: float = plot_h * 0.5
	var per_unit: float = (plot_h * 0.5 - 4.0)
	# The reading's place: the trace runs up to it from the left.
	var now_x: float = w - 150.0
	_chart.draw_rect(Rect2(0, 0, w, plot_h), COLOR_BAR)
	_chart.draw_rect(Rect2(0, 0, w, plot_h), COLOR_EDGE, false, 2.0)
	for i: int in range(-2, 3):
		var tick_y: float = mid - i * 0.5 * per_unit
		_chart.draw_line(Vector2(0, tick_y), Vector2(now_x, tick_y), COLOR_TICK, 2.0 if i == 0 else 1.0)
	var inside: bool = is_inside()
	var mark: Color = COLOR_MARK if inside else COLOR_OUT
	# The bracket: a filled band with a square bracket at each side, so colour
	# alone does not tell it.
	var band_top: float = mid - (_bracket + _band) * per_unit
	var band_h: float = 2.0 * _band * per_unit
	var left_x: float = now_x - 26.0
	var right_x: float = now_x + 26.0
	_chart.draw_rect(Rect2(left_x, band_top, right_x - left_x, band_h), COLOR_BAND)
	for side: float in [-1.0, 1.0]:
		var edge_x: float = now_x + side * 26.0
		_chart.draw_line(Vector2(edge_x, band_top), Vector2(edge_x, band_top + band_h), mark, 3.0)
		_chart.draw_line(Vector2(edge_x, band_top), Vector2(edge_x - side * 9.0, band_top), mark, 3.0)
		_chart.draw_line(Vector2(edge_x, band_top + band_h), Vector2(edge_x - side * 9.0, band_top + band_h), mark, 3.0)
	# The trace of the reading, oldest at the left.
	var shown: int = ceili(TRACE_S / STEP_S)
	var per_sample: float = now_x / shown
	if _trace.size() >= 2:
		var points := PackedVector2Array()
		for i: int in _trace.size():
			points.append(Vector2(now_x - (_trace.size() - 1 - i) * per_sample, mid - _trace[i] * per_unit))
		_chart.draw_polyline(points, COLOR_TRACE, 2.0)
	var reading_y: float = mid - _reading * per_unit
	_chart.draw_colored_polygon(PackedVector2Array([
		Vector2(now_x - 7.0, reading_y), Vector2(now_x, reading_y - 7.0),
		Vector2(now_x + 7.0, reading_y), Vector2(now_x, reading_y + 7.0)]), COLOR_TRACE)
	# In words too.
	var font: Font = get_theme_default_font()
	if _stage == Stage.HOLD:
		_chart.draw_string(font, Vector2(right_x + 14.0, mid + 9.0), "IN" if inside else "OUT",
			HORIZONTAL_ALIGNMENT_LEFT, 100.0, 26, mark)
	# How much of the run is left.
	var left: float = 1.0
	if _stage == Stage.HOLD:
		left = 1.0 - clampf(_time / RUN_S, 0.0, 1.0)
	elif _stage == Stage.RESULT:
		left = 0.0
	_chart.draw_rect(Rect2(0, h - time_h, w, time_h), COLOR_BAR)
	_chart.draw_rect(Rect2(0, h - time_h, w * left, time_h), COLOR_EDGE)
