class_name ThreadTheSpool
extends Control
## Mini-game 5, Thread the Spool (docs/design/quests_levels_story.md section
## 7.1). A silk spool hangs from the player's hand and sways while it lowers to
## the relay's slot. The player moves the hand left and right to keep the spool
## over the slot. The score is how centered it was as it seated: its mean
## distance from the slot's middle over the last SEAT_S of the lowering.
##
## Two keys play it (Left and Right, or the two buttons). Esc or the gamepad's
## cancel skips it, and so does SKIP. Nothing moves until the first press, and
## no push is longer than MAX_HOLD_S: the game lets go of a longer one.
## Positions are in scale units: the view runs from -1 to 1 and the slot is at
## 0. The scoring and the sway are in the static functions, and advance() and
## steer() play it with no frames.

## The score, 0 to 100, or MinigameScore.SKIPPED.
signal finished(score: int)

enum Stage { IDLE, READY, LOWER, RESULT }

const GAME_NAME: String = "Seat"
## The lowering, in real seconds, on every setting (section 7.1: 6 to 10 s).
## All the numbers below are [PLACEHOLDER].
const RUN_S: float = 8.0
## The end of the lowering, as the spool goes into the slot: the score is read
## over this much of it.
const SEAT_S: float = 1.5
## The sway: a sum of slow waves, each a share of AMPLITUDE and so many turns a
## second of the sway's own clock. The rates are chosen so no wave is back where
## it began as the lowering ends: a spool nobody steers has swung away.
const AMPLITUDE: float = 0.6
const WAVE_HZ: Array[float] = [0.19, 0.31, 0.44]
const WAVE_SHARE: Array[float] = [0.5, 0.3, 0.2]
## Section 7.3: at Husbandry 99 the sway's clock runs this much slower (half
## speed) [ASSUMPTION: the design gives no size; Uncertainty's in Hold the
## Reading].
const SKILL_SLOWING: float = 0.5
## Half the slot's width on Standard. Relaxed and Sharp scale it
## (MinigameSettings.sweet_factor); no skill does.
const BASE_SLOT: float = 0.04
## Inside the slot the score runs from 100 at the middle down to this at its edge.
const SLOT_SCORE: int = 95
## A seat this many slot half-widths from the middle scores 0.
const MISS_AT: float = 8.0
## The hand: pushed while a key is held and slowed by drag, so it tops out near
## PUSH / DRAG a second. It reaches no farther than ±REACH.
const PUSH: float = 9.0
const DRAG: float = 6.0
const REACH: float = 1.0
## Section 7.5 allows no hold longer than 3 s. This game lets go sooner.
const MAX_HOLD_S: float = 2.5
const HOLD_CAP_HINT: String = "The push ran out. Press again to move."
## At the result a press sooner than this is not taken.
const RESULT_ARM_S: float = 0.4
const RESULT_S: float = 1.6
## The most one frame may move the game on, and the fixed step it is played in:
## the same presses at the same times give the same score at any frame rate.
const MAX_STEP_S: float = 0.1
const STEP_S: float = 1.0 / 60.0
## Rounding slack, so 0.05 s is three steps and not two and a carry.
const STEP_SLACK_S: float = 0.000001
## Shown under the view: what SKIP does at the relay.
const SKIP_HINT: String = "Esc/Skip seats the spool without the game."

const COLOR_BAR := Color(0.03, 0.06, 0.04)
const COLOR_EDGE := Color(0.3, 0.45, 0.33)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.5)
const COLOR_SLOT := Color(0.1, 0.55, 0.45, 0.55)
const COLOR_MARK := Color(0.55, 1.0, 0.6)
const COLOR_OUT := Color(1.0, 0.75, 0.3)
const COLOR_SPOOL := Color(1, 1, 1)

var _stage: Stage = Stage.IDLE
## Seconds in this stage.
var _time: float = 0.0
## The sway's own clock, and how fast it runs against the real one.
var _sway_s: float = 0.0
var _sway_speed: float = 1.0
var _phases: Array[float] = []
var _slot: float = BASE_SLOT
var _sway: float = 0.0
var _hand: float = 0.0
var _hand_speed: float = 0.0
## -1 while Left is held, 1 while Right is, 0 with neither or both.
var _steer: int = 0
var _left: bool = false
var _right: bool = false
var _hold_s: float = 0.0
## The spool's distance from the slot's middle, summed over the seat's steps.
var _seat_off: float = 0.0
var _seat_steps: int = 0
## How far the sway has moved in this run, in scale units.
var _travel: float = 0.0
var _score: int = MinigameScore.SKIPPED
## Time given to advance() and not yet stepped.
var _carry_s: float = 0.0
## The real clock at the last frame, in microseconds.
var _last_usec: int = 0

@onready var _subject_label: Label = %SubjectLabel
@onready var _stage_label: Label = %StageLabel
@onready var _view: Control = %View
@onready var _hint_label: Label = %HintLabel
@onready var _left_button: Button = %LeftButton
@onready var _right_button: Button = %RightButton
@onready var _skip_button: Button = %SkipButton


## How fast the sway's clock runs for a player with `share` (0 to 1) of the
## Husbandry skill's slowing: 1 with none, half speed with all of it.
static func sway_factor(share: float) -> float:
	return 1.0 - SKILL_SLOWING * clampf(share, 0.0, 1.0)


## How far the spool hangs to one side of the hand at `sway_s` on the sway's
## clock. `phases` (one per wave, 0 to 1) come from the seed.
static func sway_at(sway_s: float, phases: Array[float]) -> float:
	var sum: float = 0.0
	for i: int in WAVE_HZ.size():
		var phase: float = phases[i] if i < phases.size() else 0.0
		sum += WAVE_SHARE[i] * sin(TAU * (WAVE_HZ[i] * sway_s + phase))
	return AMPLITUDE * sum


## Half the slot's width. `sweet_factor` is the difficulty's.
static func slot_half(sweet_factor: float = 1.0) -> float:
	return BASE_SLOT * maxf(sweet_factor, 0.0)


## The score, 0 to 100, of a spool that seated `off` from the slot's middle
## (its mean distance over the seat) with a slot of ±`slot_half_width`. Inside
## the slot it is 95 to 100; outside it falls in a straight line to 0 at
## MISS_AT half-widths.
static func score(off: float, slot_half_width: float = BASE_SLOT) -> int:
	var widths: float = absf(off) / maxf(slot_half_width, 0.000001)
	if widths <= 1.0:
		return roundi(MinigameScore.MAX_SCORE - (MinigameScore.MAX_SCORE - SLOT_SCORE) * widths)
	return clampi(floori(SLOT_SCORE - (widths - 1.0) * SLOT_SCORE / (MISS_AT - 1.0)), 0, SLOT_SCORE - 1)


## What one frame of `real_seconds` moves the game on by.
static func frame_step(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_STEP_S)


func _ready() -> void:
	hide()
	set_process(false)
	_view.draw.connect(_draw_view)
	_left_button.button_down.connect(push.bind(true, true))
	_left_button.button_up.connect(push.bind(true, false))
	_right_button.button_down.connect(push.bind(false, true))
	_right_button.button_up.connect(push.bind(false, false))
	_skip_button.pressed.connect(skip)


## Starts a game. `share` is the player's part of the skill's slowing (0 to 1),
## `mode` a MinigameSettings.Mode, and `motion_seed` sets the sway.
func play(share: float, mode: int, motion_seed: int, subject: String = "") -> void:
	if is_playing():
		skip()
	_slot = slot_half(MinigameSettings.sweet_factor(mode))
	_sway_speed = MinigameSettings.speed_factor(mode) * sway_factor(share)
	var rng := RandomNumberGenerator.new()
	rng.seed = motion_seed
	_phases = []
	for i: int in WAVE_HZ.size():
		_phases.append(rng.randf())
	_score = MinigameScore.SKIPPED
	_sway_s = 0.0
	_seat_off = 0.0
	_seat_steps = 0
	_travel = 0.0
	_sway = sway_at(0.0, _phases)
	# The spool starts over the slot: the first press is never a chase.
	_hand = clampf(-_sway, -REACH, REACH)
	_hand_speed = 0.0
	_subject_label.text = subject
	_left_button.disabled = false
	_right_button.disabled = false
	_begin(Stage.READY)
	show()
	_carry_s = 0.0
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func is_playing() -> bool:
	return _stage != Stage.IDLE


func stage() -> Stage:
	return _stage


## Where the spool is: 0 is the slot's middle.
func offset() -> float:
	return _hand + _sway


func hand() -> float:
	return _hand


func slot() -> float:
	return _slot


func steering() -> int:
	return _steer


func is_over_slot() -> bool:
	return absf(offset()) <= _slot


## How far down the spool is, 0 to 1.
func lowered() -> float:
	match _stage:
		Stage.LOWER:
			return clampf(_time / RUN_S, 0.0, 1.0)
		Stage.RESULT:
			return 1.0
	return 0.0


## How far the sway has moved in this run so far.
func travel() -> float:
	return _travel


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
		Stage.LOWER:
			_run(seconds)
		Stage.RESULT:
			if _time >= RESULT_S:
				_finish(_score)


func _run(seconds: float) -> void:
	if _steer != 0:
		_hold_s += seconds
		if _hold_s >= MAX_HOLD_S:
			_let_go()
			if not _hint_label.text.begins_with(HOLD_CAP_HINT):
				_hint_label.text = HOLD_CAP_HINT + "\n" + _hint_label.text
	_hand_speed += (PUSH * _steer - DRAG * _hand_speed) * seconds
	_hand += _hand_speed * seconds
	if absf(_hand) >= REACH:
		_hand = clampf(_hand, -REACH, REACH)
		_hand_speed = 0.0
	_sway_s += seconds * _sway_speed
	var before: float = _sway
	_sway = sway_at(_sway_s, _phases)
	_travel += absf(_sway - before)
	if _time >= RUN_S - SEAT_S - STEP_SLACK_S:
		_seat_off += absf(offset())
		_seat_steps += 1
	if _time >= RUN_S - STEP_SLACK_S:
		_score = score(_seat_off / maxi(_seat_steps, 1), _slot)
		_begin(Stage.RESULT)


## Left or Right, down or up. Both down is neither.
func push(left: bool, down: bool) -> void:
	if left:
		_left = down
	else:
		_right = down
	steer(int(_right) - int(_left))


## Which way the hand is pushed: -1 left, 1 right, 0 neither. The first push
## starts the lowering; at the result a push goes on.
func steer(direction: int) -> void:
	direction = clampi(direction, -1, 1)
	match _stage:
		Stage.READY:
			if direction != 0:
				_begin(Stage.LOWER)
				# The key that started it is still down.
				_left = direction < 0
				_right = direction > 0
				_set_steer(direction)
		Stage.LOWER:
			_set_steer(direction)
		Stage.RESULT:
			if direction != 0 and _time >= RESULT_ARM_S:
				_finish(_score)


## The accept button: it starts the lowering with no push, and closes the result.
func press() -> void:
	match _stage:
		Stage.READY:
			_begin(Stage.LOWER)
		Stage.RESULT:
			if _time >= RESULT_ARM_S:
				_finish(_score)


func _set_steer(direction: int) -> void:
	if direction == _steer:
		return
	_steer = direction
	_hold_s = 0.0
	if direction != 0 and _hint_label.text.begins_with(HOLD_CAP_HINT):
		_hint_label.text = _hint_label.text.trim_prefix(HOLD_CAP_HINT + "\n")


func _let_go() -> void:
	_steer = 0
	_left = false
	_right = false
	_hold_s = 0.0


## Ends the game with no score. At the result the score stands.
func skip() -> void:
	if _stage != Stage.IDLE:
		_finish(_score if _stage == Stage.RESULT else MinigameScore.SKIPPED)


func _begin(next: Stage) -> void:
	_stage = next
	_time = 0.0
	# A push never carries into a stage: each takes a press of its own.
	_let_go()
	match next:
		Stage.READY:
			_stage_label.text = "THE SPOOL IS SWAYING"
			_hint_label.text = "Left and Right move your hand. Keep the spool over the slot as it lowers. Press either to start.\n" + SKIP_HINT
		Stage.LOWER:
			_stage_label.text = "THREAD THE SPOOL"
			_hint_label.text = "Left and Right move your hand. It counts as the spool goes into the slot.\n" + SKIP_HINT
		Stage.RESULT:
			_stage_label.text = "SPOOL SEATED"
			_hint_label.text = MinigameScore.seat_text(_score)
			_left_button.disabled = true
			_right_button.disabled = true
	_view.queue_redraw()


func _finish(with_score: int) -> void:
	_stage = Stage.IDLE
	_let_go()
	set_process(false)
	hide()
	finished.emit(with_score)


func _input(event: InputEvent) -> void:
	if _stage == Stage.IDLE or not is_visible_in_tree() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_released(&"ui_left"):
		get_viewport().set_input_as_handled()
		push(true, event.is_pressed())
	elif event.is_action_pressed(&"ui_right") or event.is_action_released(&"ui_right"):
		get_viewport().set_input_as_handled()
		push(false, event.is_pressed())
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		press()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


func _draw_view() -> void:
	var w: float = _view.size.x
	var h: float = _view.size.y
	var time_h: float = 10.0
	var plot_h: float = h - time_h - 6.0
	var mid: float = w * 0.5
	var per_unit: float = w * 0.5 - 40.0
	var housing_h: float = 26.0
	var floor_y: float = plot_h - housing_h
	_view.draw_rect(Rect2(0, 0, w, plot_h), COLOR_BAR)
	_view.draw_rect(Rect2(0, 0, w, plot_h), COLOR_EDGE, false, 2.0)
	var over: bool = is_over_slot()
	var mark: Color = COLOR_MARK if over else COLOR_OUT
	# The relay's housing with the slot cut into it, and a mark over its middle:
	# the slot is told by its place and its shape, not by colour alone.
	var slot_w: float = maxf(2.0 * _slot * per_unit, 6.0)
	_view.draw_rect(Rect2(0, floor_y, mid - slot_w * 0.5, housing_h), COLOR_EDGE)
	_view.draw_rect(Rect2(mid + slot_w * 0.5, floor_y, w - mid - slot_w * 0.5, housing_h), COLOR_EDGE)
	_view.draw_rect(Rect2(mid - slot_w * 0.5, floor_y, slot_w, housing_h), COLOR_SLOT)
	_view.draw_line(Vector2(mid, 0), Vector2(mid, floor_y), COLOR_TICK, 1.0)
	for side: float in [-1.0, 1.0]:
		var edge_x: float = mid + side * slot_w * 0.5
		_view.draw_line(Vector2(edge_x, floor_y - 12.0), Vector2(edge_x, floor_y), mark, 3.0)
		_view.draw_line(Vector2(edge_x, floor_y - 12.0), Vector2(edge_x + side * 9.0, floor_y - 12.0), mark, 3.0)
	# The hand at the top, the thread, and the spool on its end.
	var spool_h: float = 30.0
	var hand_x: float = mid + clampf(_hand, -REACH, REACH) * per_unit
	var spool_x: float = mid + clampf(offset(), -1.1, 1.1) * per_unit
	var spool_y: float = lerpf(34.0, floor_y - spool_h * 0.5 - 2.0, lowered())
	_view.draw_colored_polygon(PackedVector2Array([
		Vector2(hand_x - 9.0, 4.0), Vector2(hand_x + 9.0, 4.0), Vector2(hand_x, 16.0)]), COLOR_SPOOL)
	_view.draw_line(Vector2(hand_x, 16.0), Vector2(spool_x, spool_y - spool_h * 0.5), COLOR_TICK, 2.0)
	var core_w: float = 12.0
	var flange_w: float = 24.0
	_view.draw_rect(Rect2(spool_x - core_w * 0.5, spool_y - spool_h * 0.5, core_w, spool_h), COLOR_SPOOL)
	_view.draw_rect(Rect2(spool_x - flange_w * 0.5, spool_y - spool_h * 0.5, flange_w, 5.0), mark)
	_view.draw_rect(Rect2(spool_x - flange_w * 0.5, spool_y + spool_h * 0.5 - 5.0, flange_w, 5.0), mark)
	# In words too.
	var font: Font = get_theme_default_font()
	if _stage == Stage.LOWER:
		var said: String = "OVER THE SLOT" if over else ("LEFT OF THE SLOT" if offset() < 0.0 else "RIGHT OF THE SLOT")
		_view.draw_string(font, Vector2(14.0, 30.0), said, HORIZONTAL_ALIGNMENT_LEFT, 320.0, 22, mark)
	# How much of the lowering is left.
	var left: float = 1.0 - lowered()
	_view.draw_rect(Rect2(0, h - time_h, w, time_h), COLOR_BAR)
	_view.draw_rect(Rect2(0, h - time_h, w * left, time_h), COLOR_EDGE)
