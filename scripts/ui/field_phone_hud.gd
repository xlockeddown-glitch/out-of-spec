class_name FieldPhoneHUD
extends Control
## Right-side handheld field phone. Presentation only: renders state handed to
## it and emits intent signals. No gameplay rules live here.

signal zero_steering_pressed

const MAX_LOG_LINES: int = 8
const COLOR_BAR_ON := Color(0.55, 1.0, 0.6)
const COLOR_BAR_OFF := Color(0.14, 0.22, 0.16)
const COLOR_OK := Color(0.55, 1.0, 0.6)
const COLOR_WARN := Color(1.0, 0.85, 0.3)
const COLOR_FAIL := Color(1.0, 0.38, 0.32)

var _log_lines: PackedStringArray = []

@onready var _bars: Array[ColorRect] = [%Bar1, %Bar2, %Bar3, %Bar4]
@onready var _relay_label: Label = %RelayLabel
@onready var _link_label: Label = %LinkLabel
@onready var _lag_label: Label = %LagLabel
@onready var _drift_value: Label = %DriftValue
@onready var _tolerance_label: Label = %ToleranceLabel
@onready var _status_label: Label = %StatusLabel
@onready var _zero_button: Button = %ZeroButton
@onready var _log_label: Label = %LogLabel


func _ready() -> void:
	_zero_button.pressed.connect(func() -> void: zero_steering_pressed.emit())
	_log_label.text = ""


func configure(relay_name: String, mpe_deg: float, acceptance_ratio: float) -> void:
	_relay_label.text = relay_name
	_tolerance_label.text = "MPE ±%.2f°   ACCEPT ±%.2f° (%d%%)" % [
		mpe_deg, mpe_deg * acceptance_ratio, roundi(acceptance_ratio * 100.0)]


func set_uplink(has_los: bool, quality: float, lag_s: float) -> void:
	var lit: int = ceili(clampf(quality, 0.0, 1.0) * _bars.size())
	for i: int in _bars.size():
		_bars[i].color = COLOR_BAR_ON if i < lit else COLOR_BAR_OFF
	_link_label.text = "LOS CLEAR" if has_los else "LOS BLOCKED"
	_link_label.add_theme_color_override("font_color", COLOR_OK if has_los else COLOR_FAIL)
	_lag_label.text = "UPLINK LAG  %d ms" % roundi(lag_s * 1000.0)


## status is a DriftModel.Status value.
func set_drift(drift_deg: float, status: int) -> void:
	_drift_value.text = "%+.2f°" % drift_deg
	match status:
		DriftModel.Status.IN_TOLERANCE:
			_set_status("IN TOLERANCE", COLOR_OK)
		DriftModel.Status.GUARD_BAND:
			_set_status("IN GUARD BAND", COLOR_WARN)
		_:
			_set_status("OUT OF SPEC", COLOR_FAIL)


func push_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	_log_label.text = "\n".join(_log_lines)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_drift_value.add_theme_color_override("font_color", color)
