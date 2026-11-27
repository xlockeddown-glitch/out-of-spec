class_name BenchGame
extends Control
## What the instrument-kind bench games share (Fixed Points, Pump to Points).
## Like Set the Zero they are the as-left game: the same score from 0 to 100,
## the same skip, the same Relaxed and Sharp, the same Calibration skill, and a
## score under the first grade changes nothing. A game is a row of test points
## (point_count()); its score is the mean of the points' scores. The look is the
## Scope one (ScopeTheme); the panel is built here so a game is one script and a
## bare scene.
##
## One button plays it (Space, Enter, a click, or the gamepad's accept). Esc or
## the gamepad's cancel skips it, and so does SKIP. advance() and press() play it
## with no frames.

## The score, 0 to 100, or MinigameScore.SKIPPED.
signal finished(score: int)

enum Stage { IDLE, PLAY, SETTLE, RESULT }

## A press sooner than this after a point starts is not taken: no double press.
const ARM_S: float = 0.25
## At the result a press sooner than this is not taken.
const RESULT_ARM_S: float = 0.4
const SETTLE_S: float = 0.5
const RESULT_S: float = 1.4
## The most one frame may move the game on.
const MAX_STEP_S: float = 0.1
## Half the sweet spot's width at Calibration 1 on Standard [PLACEHOLDER].
const BASE_SWEET: float = 0.03
## Section 7.3: the Calibration skill widens the sweet spot by up to this much more.
const SKILL_WIDENING: float = 1.0
const SKIP_HINT: String = "%s/Skip calibrates without the game."

var _stage: Stage = Stage.IDLE
## Seconds in this stage.
var _time: float = 0.0
var _speed: float = 1.0
var _sweet: float = BASE_SWEET
var _point: int = 0
var _point_scores: Array[int] = []
var _score: int = MinigameScore.SKIPPED
var _rng := RandomNumberGenerator.new()
## The real clock at the last frame, in microseconds.
var _last_usec: int = 0

var _subject_label: Label
var _stage_label: Label
var _scale: Control
var _hint_label: Label
var _action_button: Button
var _skip_button: Button


## The game's name, for the panel's title and the bench.
func game_name() -> String:
	return ""


## The MinigameScore id of the game.
func game_id() -> String:
	return ""


func point_count() -> int:
	return 1


## What the action button says before its key: "READ", "PUMP".
func action_word() -> String:
	return "PRESS"


## A subclass sets up point `index` (stage PLAY, time 0).
func _start_point(_index: int) -> void:
	pass


## A subclass moves point play on by `seconds`.
func _step(_seconds: float) -> void:
	pass


## The one button during play.
func _press_play() -> void:
	pass


## A subclass draws its scale on `_scale`.
func _draw_scale() -> void:
	pass


## A subclass's hint for the point shown now.
func _point_hint() -> String:
	return ""


## Half the sweet spot's width. `share` (0 to 1) is the skill's part of the
## widening: twice as wide at 1. `sweet_factor` is the difficulty's.
static func sweet_half_width(share: float, sweet_factor: float = 1.0) -> float:
	return BASE_SWEET * (1.0 + SKILL_WIDENING * clampf(share, 0.0, 1.0)) * maxf(sweet_factor, 0.0)


## What one frame of `real_seconds` moves the game on by.
static func frame_step(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_STEP_S)


## The score of a row of points: their mean, whole, 0 to 100.
static func mean_score(scores: Array[int]) -> int:
	if scores.is_empty():
		return 0
	var sum: int = 0
	for one: int in scores:
		sum += one
	return clampi(roundi(float(sum) / scores.size()), 0, MinigameScore.MAX_SCORE)


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	theme = ScopeTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()
	set_process(false)
	_scale.draw.connect(_draw_scale)
	_action_button.pressed.connect(_on_accept)
	_skip_button.pressed.connect(skip)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = ScopeTheme.GLASS
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(860, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 14)
	panel.add_child(content)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_row)
	var title := Label.new()
	title.theme_type_variation = ScopeTheme.TITLE
	title.add_theme_font_size_override(&"font_size", 28)
	title.text = game_name().to_upper()
	title_row.add_child(title)
	_subject_label = Label.new()
	_subject_label.theme_type_variation = ScopeTheme.CAPTION
	_subject_label.add_theme_font_size_override(&"font_size", 20)
	_subject_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subject_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_subject_label.clip_text = true
	title_row.add_child(_subject_label)
	_stage_label = Label.new()
	_stage_label.add_theme_font_size_override(&"font_size", 22)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_stage_label)
	_scale = Control.new()
	_scale.custom_minimum_size = Vector2(0, 130)
	_scale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_scale)
	_hint_label = Label.new()
	_hint_label.theme_type_variation = ScopeTheme.CAPTION
	_hint_label.custom_minimum_size = Vector2(0, 56)
	_hint_label.add_theme_font_size_override(&"font_size", 18)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 16)
	content.add_child(row)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(0, 60)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.focus_mode = Control.FOCUS_NONE
	_action_button.add_theme_font_size_override(&"font_size", 24)
	row.add_child(_action_button)
	_skip_button = Button.new()
	_skip_button.custom_minimum_size = Vector2(240, 60)
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.add_theme_font_size_override(&"font_size", 24)
	row.add_child(_skip_button)
	_refresh_prompts()


## Starts a game. `share` is the player's part of the skill's widening (0 to 1),
## `mode` a MinigameSettings.Mode, and `motion_seed` sets where the motion starts.
func play(share: float, mode: int, motion_seed: int, subject: String = "") -> void:
	if is_playing():
		skip()
	_sweet = sweet_half_width(share, MinigameSettings.sweet_factor(mode))
	_speed = MinigameSettings.speed_factor(mode)
	_rng.seed = motion_seed
	_score = MinigameScore.SKIPPED
	_point = 0
	_point_scores.clear()
	_subject_label.text = subject
	_action_button.disabled = false
	_refresh_prompts()
	_begin_point(0)
	show()
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func is_playing() -> bool:
	return _stage != Stage.IDLE


func stage() -> Stage:
	return _stage


func point_index() -> int:
	return _point


func point_scores() -> Array[int]:
	return _point_scores


func sweet_half() -> float:
	return _sweet


## Real seconds, not the farm's: a faster or stopped farm clock must not move the game.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	advance(frame_step((now - _last_usec) / 1000000.0))
	_last_usec = now
	_refresh_prompts()


## Moves the game on by `seconds`. Tests call it in place of frames.
func advance(seconds: float) -> void:
	if _stage == Stage.IDLE:
		return
	_time += seconds
	match _stage:
		Stage.PLAY:
			_step(seconds)
		Stage.SETTLE:
			if _time >= SETTLE_S:
				_begin_point(_point + 1)
		Stage.RESULT:
			if _time >= RESULT_S:
				_finish(_score)
	_scale.queue_redraw()


## The one button: plays, and at the result goes on.
func press() -> void:
	_on_accept()


func _on_accept() -> void:
	match _stage:
		Stage.PLAY:
			_press_play()
		Stage.RESULT:
			if _time >= RESULT_ARM_S:
				_finish(_score)
	_scale.queue_redraw()


## Ends the game with no score. At the result the score stands.
func skip() -> void:
	if _stage != Stage.IDLE:
		_finish(_score if _stage == Stage.RESULT else MinigameScore.SKIPPED)


## A subclass calls this with the point's score: on to the next point, or the result.
func _point_done(point_score: int) -> void:
	_point_scores.append(clampi(point_score, 0, MinigameScore.MAX_SCORE))
	if _point + 1 < point_count():
		_stage = Stage.SETTLE
		_time = 0.0
		_stage_label.text = "POINT %d TAKEN" % (_point + 1)
		_hint_label.text = "Now the next point."
	else:
		_stage = Stage.RESULT
		_time = 0.0
		_score = mean_score(_point_scores)
		_stage_label.text = "%s DONE" % game_name().to_upper()
		_hint_label.text = MinigameScore.result_text(_score, game_id())
		_action_button.disabled = true


func _begin_point(index: int) -> void:
	_point = index
	_stage = Stage.PLAY
	_time = 0.0
	_stage_label.text = "POINT %d OF %d" % [index + 1, point_count()]
	_start_point(index)
	_hint_label.text = _point_hint() + "\n" + SKIP_HINT % Controls.short_prompt(&"ui_cancel")
	_scale.queue_redraw()


func _finish(with_score: int) -> void:
	_stage = Stage.IDLE
	set_process(false)
	hide()
	finished.emit(with_score)


## The buttons name the key (or the pad button) the player uses now.
func _refresh_prompts() -> void:
	if _action_button == null:
		return
	var accept: String = "%s  [%s]" % [action_word(), Controls.short_prompt(&"ui_accept")]
	if _action_button.text != accept:
		_action_button.text = accept
	var cancel: String = "SKIP  [%s]" % Controls.short_prompt(&"ui_cancel")
	if _skip_button.text != cancel:
		_skip_button.text = cancel


func _input(event: InputEvent) -> void:
	if _stage == Stage.IDLE or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_on_accept()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


## A click anywhere off the two buttons is the one button too.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_on_accept()


## A bar the length of the scale, with its edge, for a subclass to draw on.
func _draw_bar(top: float, bar_h: float) -> void:
	_scale.draw_rect(Rect2(0, top, _scale.size.x, bar_h), ScopeTheme.GLASS_DEEP)
	_scale.draw_rect(Rect2(0, top, _scale.size.x, bar_h), ScopeTheme.GLASS_LINE, false, 2.0)
