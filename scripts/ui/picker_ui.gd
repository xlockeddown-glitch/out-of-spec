class_name PickerUI
extends Control
## The picker: name your character and choose its six parts (head, upper body, lower
## body, chassis, power unit, wheels). P opens it on the farm, in the dome, in the tunnels
## and on Phobos; the pad reaches it through the actions menu. The arrow buttons (or the
## pad's left and right) cycle a slot; APPLY asks for the change through FarmCommands, so
## the host checks it and syncs it to everyone, and a player only ever changes their own
## loadout. It is offered once when a new farm starts. Every word, size and number here
## is a [PLACEHOLDER].

const TITLE: String = "CHARACTER AND TRACTOR"
const ACTION: StringName = &"open_picker"
const NAME_PROMPT: String = "NAME"
const NAME_HINT: String = "Name your character"
const APPLY_TEXT: String = "APPLY"
const BACK_TEXT: String = "CLOSE"
const NO_TRADE_OFF: String = "A look only. It does not change driving."
const SLOT_WIDTH: float = 190.0
const PART_WIDTH: float = 330.0

## Set when a new farm starts: the next picker opens once on its own, then clears this.
static var offer_next: bool = false

var _parts: Dictionary = {}
var _name_field: LineEdit
var _part_labels: Dictionary[StringName, Label] = {}
var _trade_labels: Dictionary[StringName, Label] = {}
var _prev_buttons: Dictionary[StringName, Button] = {}
var _next_buttons: Dictionary[StringName, Button] = {}
var _note: Label
var _apply_button: Button
var _close_button: Button
var _glyph: Label
## What had the focus when the picker opened: it gets it back.
var _focus_before: Control
## The rover's input block as it was when the picker opened: it goes back to that.
var _blocked_before: bool = false


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	theme = ScopeTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = ScopeTheme.SHELL
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	var header := PanelContainer.new()
	header.theme_type_variation = ScopeTheme.HEADER
	var title := Label.new()
	title.text = TITLE
	title.theme_type_variation = ScopeTheme.TITLE
	title.add_theme_font_size_override(&"font_size", 30)
	header.add_child(title)
	column.add_child(header)
	var card := PanelContainer.new()
	card.theme_type_variation = ScopeTheme.PHONE_CARD
	column.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 10)
	card.add_child(rows)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 12)
	rows.add_child(name_row)
	var name_label: Label = PlanBoardUI._label(NAME_PROMPT, ScopeTheme.CARD_INK, 20)
	name_label.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	name_row.add_child(name_label)
	_name_field = LineEdit.new()
	_name_field.name = &"NameField"
	_name_field.max_length = Loadout.MAX_NAME
	# Enter must not leave a focused field that no longer types (a "p" would close us).
	_name_field.keep_editing_on_text_submit = true
	_name_field.placeholder_text = NAME_HINT
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.add_theme_font_size_override(&"font_size", 22)
	name_row.add_child(_name_field)
	for slot: StringName in Loadout.SLOTS:
		_add_row(rows, slot)
	_note = PlanBoardUI._label("", ScopeTheme.CARD_INK_MUTED, 18)
	_note.name = &"Note"
	rows.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 12)
	column.add_child(buttons)
	_apply_button = Button.new()
	_apply_button.name = &"Apply"
	_apply_button.text = APPLY_TEXT
	_apply_button.add_theme_font_size_override(&"font_size", 22)
	_apply_button.pressed.connect(apply)
	buttons.add_child(_apply_button)
	_close_button = Button.new()
	_close_button.name = &"Close"
	_close_button.text = "%s  (%s)" % [BACK_TEXT, Controls.key_label(&"ui_cancel")]
	_close_button.add_theme_font_size_override(&"font_size", 22)
	_close_button.pressed.connect(close)
	_glyph = ScopeTheme.badge(&"ui_cancel")
	_close_button.add_child(_glyph)
	buttons.add_child(_close_button)
	hide()
	if offer_next:
		offer_next = false
		open.call_deferred()


func _add_row(rows: VBoxContainer, slot: StringName) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % slot
	row.add_theme_constant_override(&"separation", 12)
	rows.add_child(row)
	var title: Label = PlanBoardUI._label(String(Loadout.SLOT_TITLES[slot]), ScopeTheme.CARD_INK, 20)
	title.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var prev := Button.new()
	prev.name = "Prev_%s" % slot
	prev.text = "<"
	prev.add_theme_font_size_override(&"font_size", 22)
	prev.pressed.connect(cycle.bind(slot, -1))
	row.add_child(prev)
	var words := VBoxContainer.new()
	words.custom_minimum_size = Vector2(PART_WIDTH, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var part_label: Label = PlanBoardUI._label("", ScopeTheme.CARD_INK, 22)
	part_label.name = &"Part"
	words.add_child(part_label)
	var trade: Label = PlanBoardUI._label("", ScopeTheme.CARD_INK_MUTED, 16)
	trade.name = &"TradeOff"
	words.add_child(trade)
	var next := Button.new()
	next.name = "Next_%s" % slot
	next.text = ">"
	next.add_theme_font_size_override(&"font_size", 22)
	next.pressed.connect(cycle.bind(slot, 1))
	row.add_child(next)
	_part_labels[slot] = part_label
	_trade_labels[slot] = trade
	_prev_buttons[slot] = prev
	_next_buttons[slot] = next


func _process(_delta: float) -> void:
	if visible:
		ScopeTheme.refresh_badge(_glyph)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(ACTION)
	if not visible:
		if toggled and not QuestsUI.other_panel_open(get_tree(), self):
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled and _name_field.has_focus():
		# A letter typed into the name is not the toggle; Esc still closes.
		get_viewport().set_input_as_handled()
	elif toggled or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif key != null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


## Shows the picker with the local player's current loadout.
func open() -> void:
	if not visible:
		_blocked_before = RoverController.input_blocked
		_focus_before = get_viewport().gui_get_focus_owner()
	RoverController.input_blocked = true
	var own: Dictionary = GameState.loadout_of(GameState.local_player_id)
	_parts = (own["parts"] as Dictionary).duplicate()
	_name_field.text = String(own["name"])
	_note.text = ""
	_show_parts()
	show()
	_next_buttons[Loadout.SLOTS[0]].grab_focus()


## Hides the picker and gives the focus back to what had it before open().
func close() -> void:
	if visible:
		RoverController.input_blocked = _blocked_before
	hide()
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_inside_tree() and before.is_visible_in_tree():
		before.grab_focus()
	else:
		var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if owner != null and is_ancestor_of(owner):
			owner.release_focus()


## If the picker is torn down while open, the rover gets its controls back.
func _exit_tree() -> void:
	if visible:
		RoverController.input_blocked = _blocked_before


## Moves a slot to the next part (step 1) or the one before (step -1), wrapping round.
func cycle(slot: StringName, step: int) -> void:
	var count: int = Loadout.parts_of(slot).size()
	var at: int = Loadout.index_of(slot, _parts.get(slot, ""))
	_parts[slot] = Loadout.parts_of(slot)[posmod(at + step, count)]["id"]
	_show_parts()


## The part ids as picked now.
func chosen() -> Dictionary:
	return _parts.duplicate()


func chosen_name() -> String:
	return _name_field.text


func set_chosen_name(text: String) -> void:
	_name_field.text = text


func _show_parts() -> void:
	for slot: StringName in Loadout.SLOTS:
		var entry: Dictionary = Loadout.part(slot, _parts.get(slot, ""))
		_part_labels[slot].text = String(entry["name"])
		var trade: String = String(entry["trade_off"])
		_trade_labels[slot].text = trade if trade != "" else NO_TRADE_OFF


## Asks for the picked loadout and name. Returns the refusal, or "" when it was taken;
## closes the picker once taken.
func apply() -> String:
	var reason: String = ""
	var answer: Variant = await FarmCommands.request(&"set_loadout", [_name_field.text, Loadout.encode(_parts)])
	if answer is String:
		reason = answer
	if reason != "":
		if is_instance_valid(_note):
			_note.text = reason
		return reason
	if is_instance_valid(self) and visible:
		close()
	return ""
