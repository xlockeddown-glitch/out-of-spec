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

const MAX_LOG_LINES: int = 8
const COLOR_BAR_ON := DriftingSensor.COLOR_IN_BAND
const COLOR_BAR_OFF := Color(0.14, 0.22, 0.2)
const COLOR_OK := DriftingSensor.COLOR_IN_BAND
const COLOR_WARN := DriftingSensor.COLOR_GUARDBAND
const COLOR_FAIL := DriftingSensor.COLOR_OUT_OF_TOLERANCE

var _log_lines: PackedStringArray = []
## Bram's Tier 1 buttons, built in code under the trade button.
var _standards_box: VBoxContainer
## Lab credibility band, a row under the clock, built in code.
var _credibility_label: Label

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


func _ready() -> void:
	_zero_button.pressed.connect(func() -> void: zero_steering_pressed.emit())
	_slot_spool_button.pressed.connect(func() -> void: slot_spool_pressed.emit())
	_dome_button.pressed.connect(func() -> void: enter_dome_pressed.emit())
	_trade_button.pressed.connect(func() -> void: trade_pressed.emit())
	_standards_box = VBoxContainer.new()
	_standards_box.name = "StandardsBox"
	_bram_panel.add_child(_standards_box)
	_log_label.text = ""
	_credibility_label = Label.new()
	_credibility_label.name = "CredibilityLabel"
	_credibility_label.add_theme_font_size_override("font_size", 16)
	_credibility_label.add_theme_color_override("font_color", COLOR_OK)
	var clock_row: Node = _credits_label.get_parent()
	clock_row.get_parent().add_child(_credibility_label)
	clock_row.get_parent().move_child(_credibility_label, clock_row.get_index() + 1)


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


func set_relay(slotted: bool, spools: int, can_slot: bool) -> void:
	_relay_status_label.text = "RELAY: OPTICAL SILK" if slotted else "RELAY: STOCK TRANSCEIVER"
	_relay_status_label.add_theme_color_override(
		"font_color", Color(0.45, 0.9, 1) if slotted else Color(0.4, 0.7, 0.45))
	_spool_label.text = "SILK SPOOLS %d" % spools
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


func set_ore(ore: int) -> void:
	_ore_label.text = "ORE %d   " % ore


## Bram's panel while the rover is parked in his bay.
func show_bram(line: String, cost: int, ore: int, owned: bool) -> void:
	_bram_panel.visible = true
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
			label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.45))
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


func hide_bram() -> void:
	_bram_panel.visible = false


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
