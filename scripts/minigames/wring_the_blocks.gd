class_name WringTheBlocks
extends Control
## Mini-game 2, Wring the Blocks (docs/design/quests_levels_story.md section
## 7.1). The player picks blocks from a tray that add up to a named length, then
## wrings each joint of the stack: a slide and a quarter turn.
##
## The slide: holding the button pushes the block on faster, letting go eases
## it off, and an uneven drag pulls at it. The score is how much of the slide was
## done with the speed inside the marked green band. The turn: hold to turn the
## block, and let go at the quarter-turn mark. Picking is not scored: the stack
## must be right to go on.
##
## One button plays it (Space, Enter, a click, or the gamepad's accept), with
## Left and Right to move along the tray; a click on a block picks it too. Esc or
## the gamepad's cancel skips it, and so does SKIP. Nothing moves until the
## button is pressed, and no hold is longer than MAX_HOLD_S. The scoring is in
## the static functions, and advance(), hold() and pick() play it with no frames.

## The score, 0 to 100, or MinigameScore.SKIPPED.
signal finished(score: int)

enum Stage { IDLE, PICK, SETTLE, SLIDE, TURN, RESULT }

## The slide speed runs from 0 to 1. Holding raises it this much a second, and
## letting go lowers it this much, at Standard and an even drag. All [PLACEHOLDER].
const PUSH_PER_S: float = 0.5
const EASE_PER_S: float = 0.35
## The share of the slide a second at full speed.
const TRAVEL_PER_S: float = 0.52
## The uneven drag: the push and the ease are this much stronger or weaker along
## the slide, in this many waves [PLACEHOLDER].
const DRAG_SWING: float = 0.5
const DRAG_WAVES: float = 1.5
## The middle of the green band, and half its width at Earthworks 1 on Standard
## [PLACEHOLDER].
const GREEN_CENTRE: float = 0.55
const BASE_GREEN: float = 0.09
## Section 7.3: the Earthworks skill widens the green by up to this much more.
const SKILL_WIDENING: float = 1.0
## The first of the slide is not scored: the block is brought up to speed there.
const LEAD_IN: float = 0.2
## This share of the scored slide inside the green is a full slide score.
const FULL_SHARE: float = 0.9
## The turn, in degrees a second at Standard: each joint's is between these.
const TURN_MIN_PER_S: float = 70.0
const TURN_MAX_PER_S: float = 100.0
const TURN_MARK: float = 90.0
## The block turns no farther than this: the hold is let go there.
const TURN_END: float = 135.0
## Half the width of the turn's mark at Earthworks 1 on Standard, in degrees.
const BASE_MARK: float = 4.0
## A turn let go this many mark half-widths off scores 0.
const MISS_AT: float = 8.0
## Inside the mark the turn's score runs from 100 at the mark to this at its edge.
const SWEET_SCORE: int = 95
## What a joint's score is made of.
const SLIDE_WEIGHT: float = 0.6
## Section 7.5: no hold longer than 3 s. The game lets go of a longer one.
const MAX_HOLD_S: float = 2.5
## At the result a press sooner than this is not taken.
const RESULT_ARM_S: float = 0.4
## The most one frame may move the game on, and the step it is worked out in.
const MAX_STEP_S: float = 0.1
const STEP_S: float = 1.0 / 60.0
const SETTLE_S: float = 0.6
const RESULT_S: float = 1.6
const SKIP_HINT: String = "Esc/Skip builds the stack without the game."
## Shown when the game ends a hold at MAX_HOLD_S.
const HOLD_CAP_HINT: String = "The hold ran out. Press again to go on."
const GAME_NAME: String = "Wring"

const COLOR_BAR := Color(0.03, 0.06, 0.04)
const COLOR_EDGE := Color(0.3, 0.45, 0.33)
const COLOR_TICK := Color(0.85, 0.95, 0.88, 0.8)
const COLOR_GREEN := Color(0.1, 0.55, 0.45)
const COLOR_MARK := Color(0.55, 1.0, 0.6)
const COLOR_NEEDLE := Color(1, 1, 1)
const COLOR_BLOCK := Color(0.62, 0.66, 0.7)
const COLOR_BLOCK_EDGE := Color(0.9, 0.94, 0.98)
const COLOR_BLOCK_TEXT := Color(0.05, 0.07, 0.06)

var _stage: Stage = Stage.IDLE
## Which way the left stick leans (-1, 0, 1): in past 0.5, out below 0.3, so a lean counts once.
var _stick_x: int = 0
## Seconds in this stage.
var _time: float = 0.0
var _speed: float = 1.0
var _green: float = BASE_GREEN
var _mark: float = BASE_MARK
var _rng := RandomNumberGenerator.new()
## The length to build, in ten-thousandths of an inch, and the tray (size indexes).
var _target: int = 0
var _tray: Array[int] = []
## Places in the tray, in the order picked.
var _picked: Array[int] = []
var _cursor: int = 0
## The joint being wrung, from 0, and each wrung joint's score.
var _joint: int = 0
var _joint_scores: Array[int] = []
## The slide: the speed (0 to 1), how far on (0 to 1), and how much of the scored
## part was in the green.
var _rate: float = 0.0
var _travel: float = 0.0
var _scored: float = 0.0
var _in_green: float = 0.0
var _drag_phase: float = 0.0
var _slide_score: int = 0
## The turn: degrees, degrees a second, and whether a press has started it.
var _angle: float = 0.0
var _turn_per_s: float = TURN_MIN_PER_S
var _turning: bool = false
## The button: down now, and how long, in real seconds.
var _held: bool = false
var _hold_s: float = 0.0
var _score: int = MinigameScore.SKIPPED
var _last_usec: int = 0

@onready var _subject_label: Label = %SubjectLabel
@onready var _stage_label: Label = %StageLabel
@onready var _bench: Control = %Bench
@onready var _hint_label: Label = %HintLabel
@onready var _hold_button: Button = %HoldButton
@onready var _skip_button: Button = %SkipButton


## Half the width of the slide's green band. `share` (0 to 1) is how much of the
## skill's widening the player has: twice as wide at 1. `sweet_factor` is the
## difficulty's.
static func green_half_width(share: float, sweet_factor: float = 1.0) -> float:
	return BASE_GREEN * (1.0 + SKILL_WIDENING * clampf(share, 0.0, 1.0)) * maxf(sweet_factor, 0.0)


## Half the width of the turn's mark, in degrees: widened as the green is.
static func mark_half_width(share: float, sweet_factor: float = 1.0) -> float:
	return BASE_MARK * (1.0 + SKILL_WIDENING * clampf(share, 0.0, 1.0)) * maxf(sweet_factor, 0.0)


## How strong the drag is `travel` (0 to 1) along a slide: 1 is even. `phase`
## (0 to 1) is the joint's own.
static func drag_at(travel: float, phase: float) -> float:
	return 1.0 + DRAG_SWING * sin(TAU * (travel * DRAG_WAVES + phase))


## True for a slide speed inside a green band of ±`green_half`.
static func is_in_green(rate: float, green_half: float) -> bool:
	return absf(rate - GREEN_CENTRE) <= green_half


## A slide's score, 0 to 100: `green_share` is the part of the scored slide done
## inside the green. FULL_SHARE and over is 100.
static func slide_score(green_share: float) -> int:
	return clampi(roundi(MinigameScore.MAX_SCORE * green_share / FULL_SHARE), 0, MinigameScore.MAX_SCORE)


## A turn's score, 0 to 100, let go at `angle` degrees with a mark of
## ±`mark_half`: 95 to 100 inside the mark, then a straight line to 0 at MISS_AT
## half-widths.
static func turn_score(angle: float, mark_half: float) -> int:
	var off: float = absf(angle - TURN_MARK) / maxf(mark_half, 0.000001)
	if off <= 1.0:
		return roundi(MinigameScore.MAX_SCORE - (MinigameScore.MAX_SCORE - SWEET_SCORE) * off)
	return clampi(floori(SWEET_SCORE - (off - 1.0) * SWEET_SCORE / (MISS_AT - 1.0)), 0, SWEET_SCORE - 1)


static func joint_score(slide: int, turn: int) -> int:
	return clampi(roundi(SLIDE_WEIGHT * slide + (1.0 - SLIDE_WEIGHT) * turn), 0, MinigameScore.MAX_SCORE)


## The stack's score: the mean of its joints'. SKIPPED with none.
static func stack_score(joints: Array) -> int:
	if joints.is_empty():
		return MinigameScore.SKIPPED
	var sum: int = 0
	for one: int in joints:
		sum += one
	return clampi(roundi(float(sum) / joints.size()), 0, MinigameScore.MAX_SCORE)


## What one frame of `real_seconds` moves the game on by.
static func frame_step(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_STEP_S)


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	hide()
	set_process(false)
	_bench.draw.connect(_draw_bench)
	_hold_button.button_down.connect(hold.bind(true))
	_hold_button.button_up.connect(hold.bind(false))
	_skip_button.pressed.connect(skip)


## Starts a game. `share` is the player's part of the skill's widening (0 to 1),
## `mode` a MinigameSettings.Mode, `motion_seed` sets the drag and the turns, and
## `stack` is GaugeStack.target()'s answer: the length and the tray. With no
## stack to build it ends at once, skipped.
func play(share: float, mode: int, motion_seed: int, stack: Dictionary, subject: String = "") -> void:
	if is_playing():
		skip()
	_stick_x = 0
	_target = int(stack.get("target", 0))
	_tray.assign(GaugeStack.pieces_of(stack.get("tray", [])))
	_tray.sort_custom(func(a: int, b: int) -> bool:
		return GaugeSet.SIZES_TEN_THOUSANDTHS[a] < GaugeSet.SIZES_TEN_THOUSANDTHS[b])
	if _target <= 0 or _tray.size() < GaugeStack.MIN_BLOCKS:
		finished.emit(MinigameScore.SKIPPED)
		return
	_green = green_half_width(share, MinigameSettings.sweet_factor(mode))
	_mark = mark_half_width(share, MinigameSettings.sweet_factor(mode))
	_speed = MinigameSettings.speed_factor(mode)
	_rng.seed = motion_seed
	_picked.clear()
	_joint_scores.clear()
	_cursor = 0
	_joint = 0
	_held = false
	_score = MinigameScore.SKIPPED
	_subject_label.text = subject
	_hold_button.disabled = false
	_begin(Stage.PICK)
	show()
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func is_playing() -> bool:
	return _stage != Stage.IDLE


func stage() -> Stage:
	return _stage


## The slide's speed (0 to 1) and how far on it is (0 to 1).
func rate() -> float:
	return _rate


func travel() -> float:
	return _travel


## The turn so far, in degrees.
func angle() -> float:
	return _angle


func green_half() -> float:
	return _green


func mark_half() -> float:
	return _mark


## The joints this stack has, and the scores of those wrung so far.
func joints() -> int:
	return maxi(_picked.size() - 1, 0)


func joint_scores() -> Array[int]:
	return _joint_scores.duplicate()


## The tray, as size indexes, smallest first.
func tray() -> Array[int]:
	return _tray.duplicate()


## The size indexes picked so far, in the order picked.
func picked_sizes() -> Array[int]:
	var out: Array[int] = []
	for place: int in _picked:
		out.append(_tray[place])
	return out


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
		_bench.queue_redraw()


func _step(seconds: float) -> void:
	_time += seconds
	if _held:
		_hold_s += seconds
		if _hold_s >= MAX_HOLD_S and _stage in [Stage.SLIDE, Stage.TURN]:
			_let_go()
			# Said over whatever the stage now shows: a turn that was cut is taken
			# where it stood, and the next stage's own line follows.
			if not _hint_label.text.begins_with(HOLD_CAP_HINT):
				_hint_label.text = HOLD_CAP_HINT + "\n" + _hint_label.text
	var moved: float = seconds * _speed
	match _stage:
		Stage.SETTLE:
			if _time >= SETTLE_S:
				_begin(Stage.SLIDE)
		Stage.SLIDE:
			_slide(moved)
		Stage.TURN:
			if _turning and _held:
				_angle = minf(_angle + _turn_per_s * moved, TURN_END)
				if _angle >= TURN_END:
					_let_go()
		Stage.RESULT:
			if _time >= RESULT_S:
				_finish(_score)


func _slide(seconds: float) -> void:
	var drag: float = drag_at(_travel, _drag_phase)
	if _held:
		_rate = minf(_rate + PUSH_PER_S / drag * seconds, 1.0)
	else:
		_rate = maxf(_rate - EASE_PER_S * drag * seconds, 0.0)
	var moved: float = minf(_rate * TRAVEL_PER_S * seconds, 1.0 - _travel)
	if _travel >= LEAD_IN:
		_scored += moved
		if is_in_green(_rate, _green):
			_in_green += moved
	_travel += moved
	if _travel >= 1.0:
		_slide_score = slide_score(_in_green / maxf(_scored, 0.000001))
		_begin(Stage.TURN)


## The one button, down or up. Picking and the result take the press; the slide
## and the turn take the hold.
func hold(down: bool) -> void:
	if down == _held:
		return
	if not down:
		_let_go()
		return
	match _stage:
		Stage.PICK:
			pick(_cursor)
		Stage.SLIDE:
			_held = true
			_hold_s = 0.0
		Stage.TURN:
			_held = true
			_hold_s = 0.0
			_turning = true
		Stage.RESULT:
			if _time >= RESULT_ARM_S:
				_finish(_score)


## The hold ends: by the player, or by the game at MAX_HOLD_S or the turn's end.
## A turn that was started is taken where it is.
func _let_go() -> void:
	_held = false
	if _stage == Stage.TURN and _turning:
		_joint_scores.append(joint_score(_slide_score, turn_score(_angle, _mark)))
		_joint += 1
		if _joint >= joints():
			_score = stack_score(_joint_scores)
			_begin(Stage.RESULT)
		else:
			_begin(Stage.SETTLE)


## Takes the block at this place in the tray, or puts it back. A stack that adds
## up to the length goes on to be wrung.
func pick(place: int) -> void:
	if _stage != Stage.PICK or place < 0 or place >= _tray.size():
		return
	_cursor = place
	if place in _picked:
		_picked.erase(place)
	else:
		_picked.append(place)
	if GaugeStack.is_made_by(_target, picked_sizes()):
		_begin(Stage.SETTLE)
	else:
		_show_pick()
	_bench.queue_redraw()


## Moves along the tray: -1 or 1.
func move_cursor(by: int) -> void:
	if _stage == Stage.PICK and not _tray.is_empty():
		_cursor = posmod(_cursor + by, _tray.size())
		_bench.queue_redraw()


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
		Stage.PICK:
			_hold_button.text = "TAKE or PUT BACK  [Space]"
			_show_pick()
		Stage.SETTLE:
			_hold_button.text = "HOLD  [Space]"
			if _joint == 0:
				_stage_label.text = "STACK PICKED: %s" % GaugeStack.length_text(_target)
				_hint_label.text = "Now wring each joint: a slide, then a quarter turn."
			else:
				_stage_label.text = "JOINT %d OF %d WRUNG" % [_joint, joints()]
				_hint_label.text = "Now the next block."
		Stage.SLIDE:
			_rate = 0.0
			_travel = 0.0
			_scored = 0.0
			_in_green = 0.0
			_drag_phase = _rng.randf()
			_turn_per_s = _rng.randf_range(TURN_MIN_PER_S, TURN_MAX_PER_S)
			_stage_label.text = "JOINT %d OF %d: SLIDE" % [_joint + 1, joints()]
			_hint_label.text = "Hold to push the block on, let go to ease off. Keep the speed inside the marked band.\n" + SKIP_HINT
		Stage.TURN:
			_angle = 0.0
			_turning = false
			_stage_label.text = "JOINT %d OF %d: TURN" % [_joint + 1, joints()]
			_hint_label.text = "Hold to turn the block, and let go at the quarter-turn mark.\n" + SKIP_HINT
		Stage.RESULT:
			_stage_label.text = "STACK WRUNG: %s" % GaugeStack.length_text(_target)
			_hint_label.text = MinigameScore.grade_text(GAME_NAME, _score)
			_hold_button.disabled = true
	_bench.queue_redraw()


func _show_pick() -> void:
	_stage_label.text = "BUILD %s" % GaugeStack.length_text(_target)
	var sum: int = GaugeStack.total(picked_sizes())
	_hint_label.text = "Pick the blocks that add up to it: Left and Right move, the button takes a block or puts it back. In the stack: %s.\n%s" % [
		GaugeStack.length_text(maxi(sum, 0)), SKIP_HINT]


func _finish(with_score: int) -> void:
	_stage = Stage.IDLE
	_held = false
	set_process(false)
	hide()
	finished.emit(with_score)


func _input(event: InputEvent) -> void:
	if _stage == Stage.IDLE or not is_visible_in_tree() or event.is_echo():
		return
	var motion := event as InputEventJoypadMotion
	if motion != null:
		# The left stick moves the cursor once per push, not once per sample.
		if motion.axis == JOY_AXIS_LEFT_X:
			var lean: float = absf(motion.axis_value)
			var dir: int = 0
			if lean >= 0.5 or (_stick_x != 0 and lean >= 0.3 and (motion.axis_value > 0.0) == (_stick_x > 0)):
				dir = 1 if motion.axis_value > 0.0 else -1
			if dir != _stick_x:
				_stick_x = dir
				if dir != 0:
					move_cursor(dir)
		get_viewport().set_input_as_handled()
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
	elif event.is_action_pressed(&"ui_left"):
		get_viewport().set_input_as_handled()
		move_cursor(-1)
	elif event.is_action_pressed(&"ui_right"):
		get_viewport().set_input_as_handled()
		move_cursor(1)


## While the game runs, no key or pad press reaches the farm or the scene swap behind it.
func _unhandled_input(event: InputEvent) -> void:
	if _stage != Stage.IDLE and is_visible_in_tree() and (event is InputEventKey
			or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()


## A click on a block in the tray picks it. Off the tray and the two buttons, the
## mouse button is the one button too.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _stage == Stage.PICK:
		if event.pressed:
			var at: Vector2 = _bench.get_global_transform().affine_inverse() * (get_global_transform() * event.position)
			for place: int in _tray.size():
				if _tray_rect(place).has_point(at):
					pick(place)
					return
	else:
		hold(event.pressed)


## Where a tray block is drawn, in the bench's own space.
func _tray_rect(place: int) -> Rect2:
	var count: int = maxi(_tray.size(), 1)
	var gap: float = 14.0
	var block_w: float = minf((_bench.size.x - gap * (count + 1)) / count, 150.0)
	var left: float = (_bench.size.x - (block_w * count + gap * (count - 1))) * 0.5
	var lift: float = 26.0 if place in _picked else 0.0
	return Rect2(left + place * (block_w + gap), _bench.size.y * 0.42 - lift, block_w, _bench.size.y * 0.34)


func _draw_bench() -> void:
	match _stage:
		Stage.PICK:
			_draw_tray()
		Stage.SLIDE, Stage.SETTLE:
			_draw_stack(_travel if _stage == Stage.SLIDE else 0.0, 0.0)
			if _stage == Stage.SLIDE:
				_draw_speed()
		Stage.TURN, Stage.RESULT:
			_draw_stack(1.0, _angle)
			_draw_dial()


func _draw_block(rect: Rect2, label: String, heavy: bool) -> void:
	var font: Font = get_theme_default_font()
	_bench.draw_rect(rect, COLOR_BLOCK)
	_bench.draw_rect(rect, COLOR_MARK if heavy else COLOR_BLOCK_EDGE, false, 4.0 if heavy else 2.0)
	_bench.draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + 6.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, COLOR_BLOCK_TEXT)


func _draw_tray() -> void:
	var font: Font = get_theme_default_font()
	for place: int in _tray.size():
		var rect: Rect2 = _tray_rect(place)
		var is_in: bool = place in _picked
		_draw_block(rect, GaugeStack.length_text(GaugeSet.SIZES_TEN_THOUSANDTHS[_tray[place]]), is_in)
		if is_in:
			# Lifted, a heavy edge and a word: colour alone does not tell it.
			_bench.draw_string(font, Vector2(rect.position.x, rect.position.y - 8.0), "IN STACK",
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, COLOR_MARK)
		if place == _cursor:
			var under: float = _bench.size.y * 0.76 + 12.0
			_bench.draw_line(Vector2(rect.position.x, under), Vector2(rect.end.x, under), COLOR_NEEDLE, 4.0)
			_bench.draw_colored_polygon(PackedVector2Array([
				Vector2(rect.get_center().x - 9.0, under + 18.0), Vector2(rect.get_center().x + 9.0, under + 18.0),
				Vector2(rect.get_center().x, under + 4.0)]), COLOR_NEEDLE)


## The joint being wrung, on the left: the lower block, and the upper one `on`
## (0 to 1) of the way over it. `turned` degrees shows as the upper block's
## narrowing, as a block seen from the side turning to its end.
func _draw_stack(on: float, turned: float) -> void:
	var w: float = _bench.size.x * 0.34
	var h: float = _bench.size.y * 0.22
	var left: float = _bench.size.x * 0.04
	var mid_y: float = _bench.size.y * 0.5
	var sizes: Array[int] = picked_sizes()
	var lower: String = GaugeStack.length_text(GaugeSet.SIZES_TEN_THOUSANDTHS[sizes[mini(_joint, sizes.size() - 1)]]) if not sizes.is_empty() else ""
	var upper: String = GaugeStack.length_text(GaugeSet.SIZES_TEN_THOUSANDTHS[sizes[mini(_joint + 1, sizes.size() - 1)]]) if not sizes.is_empty() else ""
	_draw_block(Rect2(left, mid_y, w, h), lower, false)
	# Narrowest at the quarter turn, and wider again past it.
	var seen_w: float = w * lerpf(1.0, 0.35, clampf(1.0 - absf(turned / TURN_MARK - 1.0), 0.0, 1.0))
	var upper_left: float = left + (1.0 - clampf(on, 0.0, 1.0)) * w + (w - seen_w) * 0.5
	_draw_block(Rect2(upper_left, mid_y - h, seen_w, h), upper, false)


## The slide's speed, on the right: a bar with the green band bracketed and a needle.
func _draw_speed() -> void:
	var font: Font = get_theme_default_font()
	var left: float = _bench.size.x * 0.46
	var w: float = _bench.size.x * 0.5
	var top: float = _bench.size.y * 0.4
	var bar_h: float = _bench.size.y * 0.24
	_bench.draw_string(font, Vector2(left, top - 30.0), "SLIDE SPEED", HORIZONTAL_ALIGNMENT_LEFT, w, 18, COLOR_TICK)
	_bench.draw_rect(Rect2(left, top, w, bar_h), COLOR_BAR)
	_bench.draw_rect(Rect2(left, top, w, bar_h), COLOR_EDGE, false, 2.0)
	var low: float = left + clampf(GREEN_CENTRE - _green, 0.0, 1.0) * w
	var high: float = left + clampf(GREEN_CENTRE + _green, 0.0, 1.0) * w
	_bench.draw_rect(Rect2(low, top, high - low, bar_h), COLOR_GREEN)
	for edge: Array in [[low, 1.0], [high, -1.0]]:
		var edge_x: float = edge[0]
		var inward: float = edge[1]
		_bench.draw_line(Vector2(edge_x, top - 10.0), Vector2(edge_x, top + bar_h + 10.0), COLOR_MARK, 2.0)
		_bench.draw_line(Vector2(edge_x, top - 10.0), Vector2(edge_x + inward * 6.0, top - 10.0), COLOR_MARK, 2.0)
		_bench.draw_line(Vector2(edge_x, top + bar_h + 10.0), Vector2(edge_x + inward * 6.0, top + bar_h + 10.0), COLOR_MARK, 2.0)
	var needle_x: float = left + clampf(_rate, 0.0, 1.0) * w
	_bench.draw_line(Vector2(needle_x, top - 16.0), Vector2(needle_x, top + bar_h + 4.0), COLOR_NEEDLE, 4.0)
	_bench.draw_colored_polygon(PackedVector2Array([
		Vector2(needle_x - 9.0, top - 24.0), Vector2(needle_x + 9.0, top - 24.0), Vector2(needle_x, top - 8.0)]), COLOR_NEEDLE)
	# How far on the slide is, under the bar.
	var done_y: float = top + bar_h + 24.0
	_bench.draw_rect(Rect2(left, done_y, w, 8.0), COLOR_BAR)
	_bench.draw_rect(Rect2(left, done_y, w * clampf(_travel, 0.0, 1.0), 8.0), COLOR_TICK)


## The turn, on the right: a dial from 0° to TURN_END with the mark bracketed.
func _draw_dial() -> void:
	var font: Font = get_theme_default_font()
	var centre := Vector2(_bench.size.x * 0.72, _bench.size.y * 0.86)
	var radius: float = _bench.size.y * 0.66
	_bench.draw_string(font, Vector2(_bench.size.x * 0.46, 22.0), "TURN", HORIZONTAL_ALIGNMENT_LEFT, 200.0, 18, COLOR_TICK)
	_bench.draw_arc(centre, radius, -deg_to_rad(TURN_END), 0.0, 48, COLOR_EDGE, 3.0)
	_bench.draw_arc(centre, radius, -deg_to_rad(TURN_MARK + _mark), -deg_to_rad(TURN_MARK - _mark), 12, COLOR_GREEN, 10.0)
	for side: float in [-1.0, 1.0]:
		var edge: Vector2 = Vector2.RIGHT.rotated(-deg_to_rad(TURN_MARK + side * _mark))
		_bench.draw_line(centre + edge * (radius - 14.0), centre + edge * (radius + 14.0), COLOR_MARK, 2.0)
	var mark: Vector2 = Vector2.RIGHT.rotated(-deg_to_rad(TURN_MARK))
	_bench.draw_line(centre + mark * (radius + 6.0), centre + mark * (radius + 20.0), COLOR_MARK, 3.0)
	var hand: Vector2 = Vector2.RIGHT.rotated(-deg_to_rad(_angle))
	_bench.draw_line(centre, centre + hand * (radius + 4.0), COLOR_NEEDLE, 4.0)
	_bench.draw_circle(centre, 6.0, COLOR_NEEDLE)
