class_name FieldPhoneHUD
extends Control
## Right-side handheld field phone. Presentation only: renders state handed to
## it and emits intent signals. No gameplay rules live here.

signal zero_steering_pressed
signal slot_spool_pressed
signal enter_dome_pressed
signal trade_pressed
## A Tier 1 standard's buy button (milestone 3a).
signal buy_standard_pressed(standard_id: String)
## An ACCEPT button on the job board (paid calibration jobs).
signal accept_job_pressed(index: int)

const MAX_LOG_LINES: int = 8
## Tallest the job list grows before it scrolls, px.
const JOBS_MAX_HEIGHT: float = 86.0
## Tallest Bram's stock grows before it scrolls, px.
const STANDARDS_MAX_HEIGHT: float = 120.0
## The phone buzzes for messages from these, not for its own notes.
const PEOPLE: Array[String] = ["BRAM", "LIN", "VANCE", "AUD-1T", "KESTREL", "MANAGER", "DISPATCH"]
## A farm's old messages come in on load; they neither buzz nor flash.
const QUIET_MS: int = 600
## The dispatch log always keeps room for this much, px.
const LOG_MIN_HEIGHT: float = 80.0
const COLOR_BAR_ON := DriftingSensor.COLOR_IN_BAND
const COLOR_BAR_OFF := Color(0.14, 0.22, 0.2)
const COLOR_OK := DriftingSensor.COLOR_IN_BAND
const COLOR_WARN := DriftingSensor.COLOR_GUARDBAND
const COLOR_FAIL := DriftingSensor.COLOR_OUT_OF_TOLERANCE
const COLOR_TEXT := Color(0.85, 0.95, 0.88)
const COLOR_DIM := Color(0.56, 0.68, 0.66)
const COLOR_CARD := Color("#14242a")

var _quiet_until: int = 0
var _key_down: bool = false
var _buzz: Tween
var _blink: Tween
## Bram's Tier 1 buttons, built in code under the trade button.
var _standards_box: VBoxContainer
## Holds _standards_box; scrolls when his stock is taller than STANDARDS_MAX_HEIGHT.
var _standards_scroll: ScrollContainer
## Lab credibility band, a row under the clock, built in code.
var _credibility_label: Label
## The molt, once Husbandry shows it on the phone; hidden until then.
var _molt_label: Label
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
@onready var _content: Control = %Content
@onready var _log_scroll: ScrollContainer = %LogScroll
@onready var _log_box: VBoxContainer = %LogBox
@onready var _body: PhoneBody = %Body
@onready var _gauge: PhoneGauge = %Gauge
@onready var _glass: ShaderMaterial = %Glass.material
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


func _ready() -> void:
	theme = _make_theme()
	_quiet_until = Time.get_ticks_msec() + QUIET_MS
	_zero_button.pressed.connect(func() -> void: zero_steering_pressed.emit())
	_slot_spool_button.pressed.connect(func() -> void: slot_spool_pressed.emit())
	_dome_button.pressed.connect(func() -> void: enter_dome_pressed.emit())
	_trade_button.pressed.connect(func() -> void: trade_pressed.emit())
	_standards_box = VBoxContainer.new()
	_standards_box.name = "StandardsBox"
	_standards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_standards_scroll = ScrollContainer.new()
	_standards_scroll.name = "StandardsScroll"
	_standards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_standards_scroll.add_child(_standards_box)
	_bram_panel.add_child(_standards_scroll)
	_standards_box.minimum_size_changed.connect(_fit_standards_scroll)
	_log_scroll.custom_minimum_size.y = LOG_MIN_HEIGHT
	_credibility_label = Label.new()
	_credibility_label.name = "CredibilityLabel"
	_credibility_label.add_theme_font_size_override("font_size", 16)
	_credibility_label.add_theme_color_override("font_color", COLOR_OK)
	# A long contract line wraps rather than widening the phone off the screen.
	_credibility_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var below: int = _credits_label.get_parent().get_index() + 1
	_content.add_child(_credibility_label)
	_content.move_child(_credibility_label, below)
	_molt_label = _credibility_label.duplicate()
	_molt_label.name = "MoltLabel"
	_molt_label.hide()
	_credibility_label.add_sibling(_molt_label)
	_jobs_box = VBoxContainer.new()
	_jobs_box.name = "JobsBox"
	_jobs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jobs_scroll = ScrollContainer.new()
	_jobs_scroll.name = "JobsScroll"
	_jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_jobs_scroll.add_child(_jobs_box)
	_content.add_child(_jobs_scroll)
	_content.move_child(_jobs_scroll, _molt_label.get_index() + 1)
	_jobs_box.minimum_size_changed.connect(_fit_jobs_scroll)


## The key goes down with its keyboard key too.
func _process(_delta: float) -> void:
	var down: bool = Input.is_action_pressed(&"rover_zero_steering")
	if down == _key_down:
		return
	_key_down = down
	if down:
		_zero_button.add_theme_stylebox_override(&"normal", _zero_button.get_theme_stylebox(&"pressed"))
	else:
		_zero_button.remove_theme_stylebox_override(&"normal")


func configure(relay_name: String, mpe_deg: float, acceptance_ratio: float) -> void:
	_relay_label.text = relay_name
	_gauge.set_limits(mpe_deg, acceptance_ratio)
	_tolerance_label.text = "MPE ±%s°   ACCEPT ±%s° (%d %%)" % [
		SP811.number(mpe_deg, 2), SP811.number(mpe_deg * acceptance_ratio, 2), roundi(acceptance_ratio * 100.0)]


func set_uplink(has_los: bool, quality: float, lag_s: float) -> void:
	var lit: int = ceili(clampf(quality, 0.0, 1.0) * _bars.size())
	for i: int in _bars.size():
		_bars[i].color = COLOR_BAR_ON if i < lit else COLOR_BAR_OFF
	_link_label.text = "LOS CLEAR" if has_los else "LOS BLOCKED"
	_link_label.add_theme_color_override("font_color", COLOR_OK if has_los else COLOR_WARN)
	_glass.set_shader_parameter(&"snow", 0.0 if has_los else 1.0 - clampf(quality, 0.0, 1.0))
	_lag_label.text = "UPLINK LAG  %d ms" % roundi(lag_s * 1000.0)


## band is a DriftingSensor.Band value.
func set_drift(drift_deg: float, band: int) -> void:
	_drift_value.text = SP811.signed(drift_deg) + "°"
	_gauge.value = drift_deg
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
		"font_color", COLOR_DIM if not slotted else COLOR_WARN if damaged else Color(0.45, 0.9, 1))
	_spool_label.text = "SILK SPOOLS %s" % spools
	_slot_spool_button.disabled = not can_slot


func set_clock(text: String) -> void:
	_clock_label.text = text


func set_credits(credits: int) -> void:
	_credits_label.text = "%s CR" % SP811.integer(credits)
	_credits_label.add_theme_color_override("font_color", COLOR_FAIL if credits < 0 else COLOR_WARN)


## e.g. "TRUSTED, 40 % to ACCREDITED" from GameState.credibility_text(), and
## the open contract objective (GameState.contract_text()) on a second line.
func set_credibility(text: String, contract: String = "") -> void:
	_credibility_label.text = "CRED: %s" % text + ("" if contract == "" else "\n" + contract)


## The enclosure's molt, "" to hide the row.
func set_molt(text: String) -> void:
	_molt_label.visible = text != ""
	_molt_label.text = text


func set_ore(ore: int) -> void:
	_ore_label.text = "ORE %d   " % ore


## Bram's panel while the rover is parked in his bay.
func show_bram(line: String, cost: int, ore: int, owned: bool) -> void:
	_bram_panel.visible = true
	# The job list steps aside for his shop so the dispatch log stays on screen.
	_jobs_scroll.visible = false
	# His stock needs the room; the log gives way as it did before jobs.
	_log_scroll.custom_minimum_size.y = 0.0
	_bram_label.text = "BRAM: " + line
	if owned:
		_trade_button.text = "WIDE TREADS FITTED"
		_trade_button.disabled = true
	else:
		_trade_button.text = "TRADE %d ORE: WIDE TREADS  [E]" % cost
		_trade_button.disabled = ore < cost


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
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", COLOR_DIM)
			_standards_box.add_child(label)
		return
	for offer: Dictionary in offers:
		var button := Button.new()
		button.text = str(offer["text"])
		button.disabled = bool(offer["disabled"])
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 15)
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
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", COLOR_OK)
		_jobs_box.add_child(label)
	for i: int in offers.size():
		var button := Button.new()
		button.text = "ACCEPT " + str(offers[i]["text"])
		button.disabled = bool(offers[i]["disabled"])
		button.tooltip_text = str(offers[i].get("tooltip", ""))
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		var index: int = i
		button.pressed.connect(func() -> void: accept_job_pressed.emit(index))
		_jobs_box.add_child(button)


## As tall as the job list, up to JOBS_MAX_HEIGHT; it scrolls beyond that.
func _fit_jobs_scroll() -> void:
	_jobs_scroll.custom_minimum_size.y = minf(_jobs_box.get_combined_minimum_size().y, JOBS_MAX_HEIGHT)


func _fit_standards_scroll() -> void:
	_standards_scroll.custom_minimum_size.y = minf(_standards_box.get_combined_minimum_size().y, STANDARDS_MAX_HEIGHT)


func hide_bram() -> void:
	_bram_panel.visible = false
	_jobs_scroll.visible = true
	_log_scroll.custom_minimum_size.y = LOG_MIN_HEIGHT


func push_log(line: String) -> void:
	var parts: PackedStringArray = message_parts(line)
	var card: PanelContainer = _message_card(parts[0], parts[1], parts[2])
	_log_box.add_child(card)
	# Newest first, like a phone's notification list: long wrapped lines
	# would otherwise push the latest message (e.g. an audit) out of view.
	_log_box.move_child(card, 0)
	while _log_box.get_child_count() > MAX_LOG_LINES:
		var oldest: Node = _log_box.get_child(-1)
		_log_box.remove_child(oldest)
		oldest.queue_free()
	_log_scroll.scroll_vertical = 0
	if Time.get_ticks_msec() < _quiet_until:
		return
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.45)
	if _blink != null:
		_blink.kill()
	_body.light = 1.0
	_blink = create_tween()
	_blink.tween_property(_body, "light", 0.0, 2.5).set_ease(Tween.EASE_IN)
	if parts[0] in PEOPLE:
		_do_buzz()


## A message's sender ("" if it has none), its heading and its text.
static func message_parts(line: String) -> PackedStringArray:
	if line.begins_with("> "):
		return ["YOU", "SENT", line.trim_prefix("> ")]
	var open: int = line.find("[")
	var close: int = line.find("] ")
	if line.begins_with("DAY ") and open > 0 and close > open:
		return ["DISPATCH", "%s  %s" % [line.substr(open + 1, close - open - 1), line.left(open).strip_edges()], line.substr(close + 2)]
	var colon: int = line.find(": ")
	if colon > 0 and PhoneIcon.SENDERS.has(line.left(colon)):
		return [line.left(colon), line.left(colon), line.substr(colon + 2)]
	if line.begins_with("AUDIT "):
		return ["AUDIT", "", line]
	return ["", "", line]


func _message_card(sender: String, heading: String, text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PhoneMessage" if sender in PEOPLE else &"PhoneNote"
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	card.add_child(row)
	row.add_child(PhoneIcon.new(sender))
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", -1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	if heading != "":
		column.add_child(_message_label(heading, 13, COLOR_OK))
	column.add_child(_message_label(text, 16, COLOR_TEXT))
	return card


func _message_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## A short shake, and the screen lights up.
func _do_buzz() -> void:
	if _buzz != null:
		_buzz.kill()
	_body.pivot_offset = _body.size * 0.5
	_buzz = create_tween()
	for i: int in 6:
		_buzz.tween_property(_body, "rotation", 0.004 if i % 2 == 0 else -0.004, 0.035)
	_buzz.tween_property(_body, "rotation", 0.0, 0.035)
	_buzz.tween_method(_set_flash, 1.0, 0.0, 0.3)
	_set_flash(1.0)


func _set_flash(amount: float) -> void:
	_glass.set_shader_parameter(&"flash", amount)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_drift_value.add_theme_color_override("font_color", color)


## The phone's own look; the rest of the HUD keeps the game's theme.
static func _make_theme() -> Theme:
	var made := Theme.new()
	# Touch buttons on the screen.
	made.set_stylebox(&"normal", &"Button", _touch(Color("#1D3A40"), COLOR_OK.darkened(0.45)))
	made.set_stylebox(&"hover", &"Button", _touch(Color("#25505a"), COLOR_OK))
	made.set_stylebox(&"pressed", &"Button", _touch(Color("#2C6B70"), COLOR_OK))
	made.set_stylebox(&"disabled", &"Button", _touch(Color("#131F24"), Color("#22333a")))
	made.set_color(&"font_color", &"Button", COLOR_TEXT)
	made.set_color(&"font_disabled_color", &"Button", COLOR_DIM.darkened(0.2))
	# The keys on the body, with a side that goes when they are down.
	_add_key(made, &"PhoneMainKey", Color("#B85A2B"), Color("#FFF4E4"))
	_add_key(made, &"PhoneKey", Color("#56616D"), COLOR_TEXT)
	_add_card(made, &"PhoneCard", COLOR_CARD, 0)
	_add_card(made, &"PhoneMessage", Color("#1B3238"), 3)
	_add_card(made, &"PhoneNote", Color("#111D22"), 0)
	return made


static func _add_key(to: Theme, kind: StringName, color: Color, text: Color) -> void:
	to.set_type_variation(kind, &"Button")
	to.set_stylebox(&"normal", kind, _key(color, false))
	to.set_stylebox(&"hover", kind, _key(color.lightened(0.1), false))
	to.set_stylebox(&"pressed", kind, _key(color.darkened(0.12), true))
	to.set_stylebox(&"disabled", kind, _key(color.darkened(0.35), false))
	to.set_color(&"font_color", kind, text)
	to.set_color(&"font_hover_color", kind, Color.WHITE)
	to.set_color(&"font_pressed_color", kind, text)
	to.set_color(&"font_disabled_color", kind, Color(COLOR_TEXT, 0.4))


static func _add_card(to: Theme, kind: StringName, color: Color, edge: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.border_color = COLOR_OK
	style.border_width_left = edge
	style.set_content_margin_all(8)
	style.content_margin_left = 10
	to.set_type_variation(kind, &"PanelContainer")
	to.set_stylebox(&"panel", kind, style)


static func _touch(color: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(6)
	return style


static func _key(color: Color, down: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.45)
	style.border_width_bottom = 3 if down else 9
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 2 if down else 5
	style.shadow_offset = Vector2(0, 2)
	# The whole key sinks.
	style.expand_margin_top = -5.0 if down else 0.0
	style.content_margin_top = 9 if down else 3
	style.content_margin_bottom = 5 if down else 11
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style
