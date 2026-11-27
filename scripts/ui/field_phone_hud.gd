class_name FieldPhoneHUD
extends Control
## Right-side handheld field phone. Presentation only: renders state handed to
## it and emits intent signals. No gameplay rules live here.

signal zero_steering_pressed
signal slot_spool_pressed
signal enter_dome_pressed
signal trade_pressed
signal wheel_service_pressed
## A Tier 1 standard's buy button (milestone 3a).
signal buy_standard_pressed(standard_id: String)
## An ACCEPT button on the job board (paid calibration jobs).
signal accept_job_pressed(index: int)

## How big the phone is, as a fraction of its original size. Fonts, fixed
## sizes, margins and the width all follow this one number.
const PHONE_SCALE: float = 0.8 # [PLACEHOLDER] Ryan: 20 % smaller
## The phone's width on the screen before PHONE_SCALE (0.32 of the screen).
const BASE_WIDTH_FRACTION: float = 0.32
## Where the phone starts, as a fraction of the screen width. The world view
## and the panels beside the phone end here.
const LEFT_ANCHOR: float = 1.0 - BASE_WIDTH_FRACTION * PHONE_SCALE
const MAX_LOG_LINES: int = 8
## Tallest the job list grows before it scrolls, px.
const JOBS_MAX_HEIGHT: float = 130.0 # before PHONE_SCALE; [PLACEHOLDER] room for three offers
## The dispatch log always keeps room for this many lines, px (before PHONE_SCALE).
const LOG_MIN_HEIGHT: float = 80.0
const COLOR_BAR_ON := DriftingSensor.COLOR_IN_BAND
const COLOR_BAR_OFF := Color(0.14, 0.22, 0.2)
const COLOR_OK := DriftingSensor.COLOR_IN_BAND
const COLOR_WARN := DriftingSensor.COLOR_GUARDBAND
const COLOR_FAIL := DriftingSensor.COLOR_OUT_OF_TOLERANCE

var _log_lines: PackedStringArray = []
## Bram's Tier 1 buttons, built in code under the trade button.
var _standards_box: VBoxContainer
var _wheels_button: Button
## Lab credibility band, a row under the clock, built in code.
var _credibility_label: Label
## The molt, once Husbandry shows it on the phone; hidden until then.
var _molt_label: Label
## "LIGHTS: LOW" or "LIGHTS: ON" in the tunnels; hidden elsewhere.
var _lights_label: Label
## "GAUGE SET n/81" once a reference block is found; hidden until then.
var _gauge_label: Label
## Accepted jobs and today's offers, under the credibility row.
var _jobs_box: VBoxContainer
## Holds _jobs_box; scrolls when the jobs are taller than JOBS_MAX_HEIGHT.
var _jobs_scroll: ScrollContainer

@onready var _bars: Array[ColorRect] = [%Bar1, %Bar2, %Bar3, %Bar4]
@onready var _relay_label: Label = %RelayLabel
@onready var _link_label: Label = %LinkLabel
@onready var _lag_label: Label = %LagLabel
@onready var _drift_value: Label = %DriftValue
@onready var _tolerance_label: Label = %ToleranceLabel
@onready var _status_label: Label = %StatusLabel
@onready var _zero_button: Button = %ZeroButton
@onready var _log_label: Label = %LogLabel
@onready var _relay_status_label: Label = %RelayStatusLabel
@onready var _spool_label: Label = %SpoolLabel
@onready var _slot_spool_button: Button = %SlotSpoolButton
@onready var _dome_button: Button = %DomeButton
@onready var _clock_label: Label = %ClockLabel
@onready var _credits_label: Label = %CreditsLabel
@onready var _ore_label: Label = %OreLabel
@onready var _bram_panel: Control = %BramPanel
@onready var _bram_label: Label = %BramLabel
@onready var _trade_button: Button = %TradeButton


## A size in px at the phone's scale.
static func scaled(base: float) -> float:
	return roundf(base * PHONE_SCALE)


## The key or button in each button's brackets follows the device in use.
## Only the key text changes, never a button's size: Controls.short_prompt is
## never longer than a button can hold.
var _keys_pad: bool = false
var _keys_known: bool = false
## What Bram's buttons were last told, so a device switch can redraw their text.
var _trade_cost: int = 0
var _trade_owned: bool = false
var _trade_told: bool = false
var _wheels_text: String = ""
var _wheels_due: bool = false


func _process(_delta: float) -> void:
	if not _keys_known or Controls.using_pad() != _keys_pad:
		_refresh_keys()


func _refresh_keys() -> void:
	_keys_known = true
	_keys_pad = Controls.using_pad()
	_zero_button.text = "ZERO STEERING  [%s]" % Controls.short_prompt(&"rover_zero_steering")
	_dome_button.text = "ENTER DOME  [%s]" % Controls.short_prompt(&"swap_scene")
	if _trade_told:
		_draw_trade()
	if _wheels_button != null:
		_draw_wheels()


## A font size at the phone's scale.
static func scaled_font(base: int) -> int:
	return roundi(base * PHONE_SCALE)


func _ready() -> void:
	anchor_left = LEFT_ANCHOR
	_refresh_keys()
	_scale_scene_nodes(self)
	_zero_button.pressed.connect(func() -> void: zero_steering_pressed.emit())
	_slot_spool_button.pressed.connect(func() -> void: slot_spool_pressed.emit())
	_dome_button.pressed.connect(func() -> void: enter_dome_pressed.emit())
	_trade_button.pressed.connect(func() -> void: trade_pressed.emit())
	_wheels_button = Button.new()
	_wheels_button.name = "WheelServiceButton"
	_wheels_button.focus_mode = Control.FOCUS_NONE
	_wheels_button.custom_minimum_size = Vector2(0, scaled(40.0))
	_wheels_button.add_theme_font_size_override("font_size", scaled_font(15))
	_wheels_button.pressed.connect(func() -> void: wheel_service_pressed.emit())
	_bram_panel.add_child(_wheels_button)
	_standards_box = VBoxContainer.new()
	_standards_box.name = "StandardsBox"
	_bram_panel.add_child(_standards_box)
	_log_label.text = ""
	_log_label.custom_minimum_size.y = scaled(LOG_MIN_HEIGHT)
	_credibility_label = Label.new()
	_credibility_label.name = "CredibilityLabel"
	_credibility_label.add_theme_font_size_override("font_size", scaled_font(16))
	_credibility_label.add_theme_color_override("font_color", COLOR_OK)
	# A long contract line wraps rather than widening the phone off the screen.
	_credibility_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var clock_row: Node = _credits_label.get_parent()
	clock_row.get_parent().add_child(_credibility_label)
	clock_row.get_parent().move_child(_credibility_label, clock_row.get_index() + 1)
	_molt_label = _credibility_label.duplicate()
	_molt_label.name = "MoltLabel"
	_molt_label.hide()
	_credibility_label.add_sibling(_molt_label)
	_lights_label = _credibility_label.duplicate()
	_lights_label.name = "LightsLabel"
	_lights_label.hide()
	_credibility_label.add_sibling(_lights_label)
	_gauge_label = _credibility_label.duplicate()
	_gauge_label.name = "GaugeSetLabel"
	_gauge_label.hide()
	_molt_label.add_sibling(_gauge_label)
	_jobs_box = VBoxContainer.new()
	_jobs_box.name = "JobsBox"
	_jobs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jobs_scroll = ScrollContainer.new()
	_jobs_scroll.name = "JobsScroll"
	_jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_jobs_scroll.add_child(_jobs_box)
	clock_row.get_parent().add_child(_jobs_scroll)
	clock_row.get_parent().move_child(_jobs_scroll, _gauge_label.get_index() + 1)
	_jobs_box.minimum_size_changed.connect(_fit_jobs_scroll)


## Scales what the scene file sets by hand (written at the original size):
## fonts, fixed sizes, gaps, the bezel inset and the case margins.
func _scale_scene_nodes(node: Node) -> void:
	if node is Control:
		var control: Control = node
		if control.has_theme_font_size_override("font_size"):
			control.add_theme_font_size_override("font_size", scaled_font(control.get_theme_font_size("font_size")))
		control.custom_minimum_size = Vector2(scaled(control.custom_minimum_size.x), scaled(control.custom_minimum_size.y))
		if control.name == &"Bezel":
			control.offset_left = scaled(control.offset_left)
			control.offset_top = scaled(control.offset_top)
			control.offset_right = -scaled(-control.offset_right)
			control.offset_bottom = -scaled(-control.offset_bottom)
		if control.has_theme_constant_override("separation"):
			control.add_theme_constant_override("separation", roundi(scaled(control.get_theme_constant("separation"))))
		if control.has_theme_stylebox_override("panel"):
			# Copied first: the scene's style is shared by every phone.
			var box: StyleBox = control.get_theme_stylebox("panel").duplicate()
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				box.set_content_margin(side, scaled(box.get_content_margin(side)))
			control.add_theme_stylebox_override("panel", box)
	for child: Node in node.get_children():
		_scale_scene_nodes(child)


func configure(relay_name: String, mpe_deg: float, acceptance_ratio: float) -> void:
	_relay_label.text = relay_name
	_tolerance_label.text = "MPE ±%s°   ACCEPT ±%s° (%d %%)" % [
		SP811.number(mpe_deg, 2), SP811.number(mpe_deg * acceptance_ratio, 2), roundi(acceptance_ratio * 100.0)]


func set_uplink(has_los: bool, quality: float, lag_s: float) -> void:
	var lit: int = ceili(clampf(quality, 0.0, 1.0) * _bars.size())
	for i: int in _bars.size():
		_bars[i].color = COLOR_BAR_ON if i < lit else COLOR_BAR_OFF
	_link_label.text = "LOS CLEAR" if has_los else "LOS BLOCKED"
	_link_label.add_theme_color_override("font_color", COLOR_OK if has_los else COLOR_FAIL)
	_lag_label.text = "UPLINK LAG  %d ms" % roundi(lag_s * 1000.0)


## The rover is in the other scene, so there is no link to show.
func set_rover_away() -> void:
	set_uplink(false, 0.0, 0.0)
	_link_label.text = "NO ROVER HERE"
	_link_label.add_theme_color_override("font_color", COLOR_WARN)
	_lag_label.text = "UPLINK LAG  --"


## band is a DriftingSensor.Band value.
func set_drift(drift_deg: float, band: int) -> void:
	_drift_value.text = SP811.signed(drift_deg) + "°"
	match band:
		DriftingSensor.Band.IN_BAND:
			_set_status("IN TOLERANCE", COLOR_OK)
		DriftingSensor.Band.GUARDBAND:
			_set_status("IN GUARD BAND", COLOR_WARN)
		_:
			_set_status("OUT OF TOLERANCE", COLOR_FAIL)


func set_relay(slotted: bool, damaged: bool, spools: String, can_slot: bool) -> void:
	_relay_status_label.text = "RELAY: STOCK TRANSCEIVER" if not slotted \
			else "RELAY: DAMAGED SILK" if damaged else "RELAY: OPTICAL SILK"
	_relay_status_label.add_theme_color_override(
		"font_color", Color(0.4, 0.7, 0.45) if not slotted else COLOR_WARN if damaged else Color(0.45, 0.9, 1))
	_spool_label.text = "SILK SPOOLS %s" % spools
	_slot_spool_button.disabled = not can_slot


func set_clock(text: String) -> void:
	_clock_label.text = text


func set_credits(credits: int) -> void:
	_credits_label.text = "%s CR" % SP811.integer(credits)
	_credits_label.add_theme_color_override("font_color", COLOR_FAIL if credits < 0 else COLOR_WARN)


## e.g. "TRUSTED, 40 % to ACCREDITED" from GameState.credibility_text(), and
## the open contract objective (GameState.contract_text()) on a second line.
## `lab` is the lab's level (GameState.lab_phone_text()), on a line between them.
func set_credibility(text: String, contract: String = "", lab: String = "") -> void:
	_credibility_label.text = "CRED: %s" % text + ("" if lab == "" else "\nLAB: " + lab) + ("" if contract == "" else "\n" + contract)


## The gauge set's progress (GaugeSet.text), "" to hide the row.
func set_gauge_set(text: String) -> void:
	_gauge_label.visible = text != ""
	_gauge_label.text = text


## The enclosure's molt, "" to hide the row.
func set_molt(text: String) -> void:
	_molt_label.visible = text != ""
	_molt_label.text = text


## The rover's headlights row, shown in the tunnels. ON is amber and LOW green, so they differ.
func set_lights(on: bool, shown: bool = true) -> void:
	_lights_label.visible = shown
	_lights_label.text = "LIGHTS: " + ("ON" if on else "LOW")
	_lights_label.add_theme_color_override("font_color", COLOR_WARN if on else COLOR_OK)


func set_ore(ore: int) -> void:
	_ore_label.text = "ORE %d   " % ore


## Bram's panel while the rover is parked in his bay.
func show_bram(line: String, cost: int, ore: int, owned: bool) -> void:
	_bram_panel.visible = true
	# The job list steps aside for his shop so the dispatch log stays on screen.
	_jobs_scroll.visible = false
	# His stock needs the room; the log gives way as it did before jobs.
	_log_label.custom_minimum_size.y = 0.0
	_bram_label.text = "BRAM: " + line
	_trade_cost = cost
	_trade_owned = owned
	_trade_told = true
	_draw_trade()
	_trade_button.disabled = owned or ore < cost


func _draw_trade() -> void:
	if _trade_owned:
		_trade_button.text = "WIDE TREADS FITTED"
	else:
		_trade_button.text = "TRADE %d ORE: WIDE TREADS  [%s]" % [_trade_cost, Controls.short_prompt(&"interact")]


## Bram's wheel service, under his trade: one press when the nuts are due.
func show_wheel_service(text: String, due: bool) -> void:
	_wheels_text = text
	_wheels_due = due
	_draw_wheels()
	_wheels_button.disabled = not due


func _draw_wheels() -> void:
	_wheels_button.text = _wheels_text + ("  [%s]" % Controls.short_prompt(&"wheel_service") if _wheels_due else "")


## Bram's Tier 1 stock. Each offer is { "id", "text", "disabled" }; `note`
## shows instead of buttons when there are none (still locked).
func show_standards(offers: Array[Dictionary], note: String) -> void:
	for child: Node in _standards_box.get_children():
		_standards_box.remove_child(child)
		child.queue_free()
	if offers.is_empty():
		if note != "":
			var label := Label.new()
			label.text = note
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", scaled_font(14))
			label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.45))
			_standards_box.add_child(label)
		return
	for offer: Dictionary in offers:
		var button := Button.new()
		button.text = str(offer["text"])
		button.disabled = bool(offer["disabled"])
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, scaled(40.0))
		button.add_theme_font_size_override("font_size", scaled_font(15))
		var id: String = str(offer["id"])
		button.pressed.connect(func() -> void: buy_standard_pressed.emit(id))
		_standards_box.add_child(button)


## Accepted jobs as lines, today's offers as ACCEPT buttons. Each offer is
## { "text", "disabled" }; `note` shows when there are no offers.
func show_jobs(active: PackedStringArray, offers: Array[Dictionary], note: String) -> void:
	for child: Node in _jobs_box.get_children():
		_jobs_box.remove_child(child)
		child.queue_free()
	var lines: PackedStringArray = active.duplicate()
	if offers.is_empty() and note != "":
		lines.append(note)
	if not lines.is_empty():
		var label := Label.new()
		label.text = "\n".join(lines)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", scaled_font(14))
		label.add_theme_color_override("font_color", COLOR_OK)
		_jobs_box.add_child(label)
	# Offers you can accept come first; `index` stays the board's own.
	var order: Array[int] = []
	for i: int in offers.size():
		if not bool(offers[i]["disabled"]):
			order.append(i)
	for i: int in offers.size():
		if bool(offers[i]["disabled"]):
			order.append(i)
	for i: int in order:
		var button := Button.new()
		button.text = "ACCEPT " + str(offers[i]["text"])
		button.disabled = bool(offers[i]["disabled"])
		button.tooltip_text = str(offers[i].get("tooltip", ""))
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", scaled_font(13))
		var index: int = i
		button.pressed.connect(func() -> void: accept_job_pressed.emit(index))
		_jobs_box.add_child(button)


## As tall as the job list, up to JOBS_MAX_HEIGHT; it scrolls beyond that.
func _fit_jobs_scroll() -> void:
	_jobs_scroll.custom_minimum_size.y = minf(_jobs_box.get_combined_minimum_size().y, scaled(JOBS_MAX_HEIGHT))


func hide_bram() -> void:
	_bram_panel.visible = false
	_jobs_scroll.visible = true
	_log_label.custom_minimum_size.y = scaled(LOG_MIN_HEIGHT)


func push_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	# Newest first, like a phone's notification list: long wrapped lines
	# would otherwise push the latest message (e.g. an audit) out of view.
	var newest_first: PackedStringArray = _log_lines.duplicate()
	newest_first.reverse()
	_log_label.text = "\n".join(newest_first)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_drift_value.add_theme_color_override("font_color", color)
