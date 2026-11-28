class_name ScopeTheme
extends RefCounted
## The "Meridiani Scope" look (Ryan's pick, playtest Nov 27, 2026): each lab
## panel is a putty and terracotta instrument shell around recessed dark glass.
## One Theme, built in code once (no .tres, so every colour and number below is
## one const), and handed to a panel's root with `theme = ScopeTheme.theme()`.
## Godot's default font only: sizes and outlines, no font files.
##
## Colours: teal in tolerance and good, amber a guard band, an indeterminate or a
## warning, red only for truly out of tolerance (DriftingSensor.band_color).
## Every colour and number is a [PLACEHOLDER].

const TEAL: Color = Color("#38E1C6")
const AMBER: Color = Color("#F5A623")
## Gold border for certificates printed after lab level 99 [PLACEHOLDER].
const GOLD: Color = Color("#D9A83B")
const RED: Color = Color("#FF5A5F")
const SHADOW: Color = Color("#1D222B")
const GLASS_DEEP: Color = Color("#151921")
const GLASS_CARD: Color = Color("#181D26")
const GLASS_LINE: Color = Color("#2E3846")
const ENAMEL_TOP: Color = Color("#EAE0CC")
const ENAMEL: Color = Color("#DCD0B8")
const ENAMEL_INSET: Color = Color("#C9BA9E")
const ENAMEL_LIP: Color = Color("#B6A68B")
const TERRA: Color = Color("#C66240")
const TERRA_DARK: Color = Color("#9C4728")
const INK: Color = Color("#EEF6F4")
const INK_MUTED: Color = Color("#98AAB9")
const INK_DIM: Color = Color("#6A7C8C")
## Dark ink for text on the cream phone cards (the light INK would vanish there),
## and a deep red for a negative figure on cream.
const CARD_INK: Color = Color("#1D222B")
const CARD_INK_MUTED: Color = Color("#4A4336")
const CARD_ALERT: Color = Color("#9B1C23")

## Theme type variations a panel names with `theme_type_variation`.
const SHELL: StringName = &"ScopeShell"
const HEADER: StringName = &"ScopeHeader"
const GLASS: StringName = &"ScopeGlass"
const CARD: StringName = &"ScopeCard"
const CAPTION: StringName = &"ScopeCaption"
const TITLE: StringName = &"ScopeTitle"
## The field phone's own variations (its case, its glass, its small keys, its top band).
const PHONE_CASE: StringName = &"ScopePhoneCase"
const PHONE_GLASS: StringName = &"ScopePhoneGlass"
const PHONE_KEY: StringName = &"ScopePhoneKey"
const PHONE_BAND: StringName = &"ScopePhoneBand"
## A cream card on the phone's dark glass, and its outlined key.
const PHONE_CARD: StringName = &"ScopePhoneCard"
const PHONE_KEY_OUTLINE: StringName = &"ScopePhoneKeyOutline"

## The focus ring: thick, teal, with a soft glow [PLACEHOLDER].
const FOCUS_BORDER: int = 5
const FOCUS_GLOW: int = 12
## Opening a panel [PLACEHOLDER]: at most 150 ms.
const OPEN_SECONDS: float = 0.12

static var _theme: Theme


## The shared theme, built on first use.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## The colour of a bench verdict: teal in band (pass), amber in the guard band
## (indeterminate), red out of tolerance (fail).
static func band_color(band: int) -> Color:
	return DriftingSensor.band_color(band)


## A flat box: fill, border, corner radius, content margins.
static func box(fill: Color, border: Color, border_width: int = 0, radius: int = 8, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## The big focus ring, drawn over a control that has the focus: teal border, a glow.
static func focus_box(radius: int = 10) -> StyleBoxFlat:
	var style := box(Color(0, 0, 0, 0), TEAL, FOCUS_BORDER, radius, 0)
	style.shadow_color = Color(TEAL, 0.45)
	style.shadow_size = FOCUS_GLOW
	style.set_expand_margin_all(4)
	return style


## A small tag: fill, border and text colour for the chip's own Label.
static func chip_box(border: Color, fill: Color = GLASS_DEEP) -> StyleBoxFlat:
	var style := box(fill, border, 2, 6, 6)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## The state chip on a cream card: a dark pill with the state colour as text and edge.
static func state_chip_box(state: Color) -> StyleBoxFlat:
	var style := box(GLASS_DEEP, state, 2, 8, 8)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## A card on the glass: the quest board's rows and the bench's result plate. `edge`
## colours the border (a verdict, or the line colour).
static func card_box(edge: Color = GLASS_LINE) -> StyleBoxFlat:
	var style := box(GLASS_CARD, edge, 3, 8, 12)
	style.border_width_left = 8 if edge != GLASS_LINE else 3
	return style


static func _build() -> Theme:
	var t := Theme.new()
	# The shell: thick bevelled putty, a darker bottom edge.
	var shell := box(ENAMEL, ENAMEL_LIP, 4, 18, 16)
	shell.border_width_bottom = 10
	shell.shadow_color = Color(0, 0, 0, 0.5)
	shell.shadow_size = 14
	_variation(t, SHELL, &"PanelContainer", &"panel", shell)
	var header := box(TERRA, TERRA_DARK, 3, 10, 10)
	header.border_width_bottom = 6
	header.content_margin_left = 16
	header.content_margin_right = 16
	_variation(t, HEADER, &"PanelContainer", &"panel", header)
	_variation(t, GLASS, &"PanelContainer", &"panel", box(SHADOW, GLASS_DEEP, 5, 10, 16))
	_variation(t, CARD, &"PanelContainer", &"panel", card_box())
	# The field phone: a rounded putty handheld around dark glass, a terracotta band
	# across its top, smaller keys so two fit side by side [PLACEHOLDER].
	var body := box(ENAMEL, TERRA_DARK, 4, 28, 22)
	body.border_width_bottom = 9
	body.shadow_color = Color(0, 0, 0, 0.5)
	body.shadow_size = 10
	_variation(t, PHONE_CASE, &"PanelContainer", &"panel", body)
	_variation(t, PHONE_GLASS, &"PanelContainer", &"panel", box(SHADOW, GLASS_DEEP, 3, 10, 22))
	var band := box(TERRA, TERRA_DARK, 2, 7, 0)
	band.border_width_bottom = 4
	_variation(t, PHONE_BAND, &"PanelContainer", &"panel", band)
	# A cream card: putty top colour, small radius, thin dark edge [PLACEHOLDER].
	_variation(t, PHONE_CARD, &"PanelContainer", &"panel", box(ENAMEL_TOP, CARD_INK, 2, 6, 8))
	# Labels: ink on the glass; a caption and a title.
	t.set_color(&"font_color", &"Label", INK)
	t.set_type_variation(CAPTION, &"Label")
	t.set_color(&"font_color", CAPTION, INK_MUTED)
	t.set_type_variation(TITLE, &"Label")
	t.set_color(&"font_color", TITLE, ENAMEL_TOP)
	t.set_color(&"font_outline_color", TITLE, TERRA_DARK)
	t.set_constant(&"outline_size", TITLE, 6)
	# Buttons: chunky putty keys, the bottom edge shortens when pressed.
	_button_styles(t, &"Button", ENAMEL_INSET, ENAMEL_LIP, SHADOW, Color(SHADOW, 0.45))
	# Fields on the glass: dark keys.
	for kind: StringName in [&"OptionButton", &"CheckButton"]:
		_button_styles(t, kind, GLASS_CARD, GLASS_LINE, INK, INK_DIM)
	t.set_color(&"font_color", &"CheckButton", INK)
	t.set_type_variation(PHONE_KEY, &"Button")
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var key: StyleBoxFlat = (t.get_stylebox(state, &"Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		key.content_margin_left = 8
		key.content_margin_right = 8
		key.content_margin_top = 6
		key.content_margin_bottom = 6
		# Thin edges to match the small margins [PLACEHOLDER].
		key.border_width_top = 2
		key.border_width_left = 2
		key.border_width_right = 2
		key.border_width_bottom = 2 if state == &"pressed" else 3 if state == &"disabled" else 4
		t.set_stylebox(state, PHONE_KEY, key)
	# The outlined key for a cream card: clear face, putty edge, dark ink.
	t.set_type_variation(PHONE_KEY_OUTLINE, &"Button")
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var key: StyleBoxFlat = (t.get_stylebox(state, PHONE_KEY) as StyleBoxFlat).duplicate() as StyleBoxFlat
		var live: bool = state == &"hover" or state == &"pressed"
		key.bg_color = Color(ENAMEL_INSET, (0.45 if state == &"hover" else 0.8) if live else 0.0)
		key.border_color = CARD_INK_MUTED
		key.set_border_width_all(2)
		key.border_width_bottom = 4 if state == &"hover" or state == &"normal" else 2
		t.set_stylebox(state, PHONE_KEY_OUTLINE, key)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		t.set_color(color_name, PHONE_KEY_OUTLINE, CARD_INK)
	t.set_color(&"font_disabled_color", PHONE_KEY_OUTLINE, Color(CARD_INK, 0.45))
	# Text fields on the glass: dark recessed box, teal focus ring [PLACEHOLDER].
	t.set_stylebox(&"normal", &"LineEdit", box(GLASS_DEEP, GLASS_LINE, 2, 8, 10))
	t.set_stylebox(&"read_only", &"LineEdit", box(GLASS_CARD, GLASS_LINE, 2, 8, 10))
	t.set_stylebox(&"focus", &"LineEdit", focus_box(8))
	t.set_color(&"font_color", &"LineEdit", INK)
	t.set_color(&"font_placeholder_color", &"LineEdit", INK_DIM)
	t.set_color(&"font_uneditable_color", &"LineEdit", INK_MUTED)
	t.set_color(&"caret_color", &"LineEdit", TEAL)
	t.set_color(&"selection_color", &"LineEdit", Color(TEAL, 0.3))
	# The drop-down list.
	t.set_stylebox(&"panel", &"PopupMenu", box(GLASS_DEEP, TEAL, 2, 6, 6))
	t.set_stylebox(&"hover", &"PopupMenu", box(Color(TEAL, 0.25), TEAL, 0, 4, 4))
	t.set_color(&"font_color", &"PopupMenu", INK)
	t.set_color(&"font_hover_color", &"PopupMenu", INK)
	return t


static func _variation(t: Theme, variation: StringName, base: StringName, item: StringName, style: StyleBox) -> void:
	t.set_type_variation(variation, base)
	t.set_stylebox(item, variation, style)


static func _button_styles(t: Theme, kind: StringName, face: Color, edge: Color, text: Color, text_off: Color) -> void:
	var normal := box(face, edge, 3, 10, 12)
	normal.border_width_bottom = 8
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = face.lightened(0.18)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = face.darkened(0.12)
	pressed.border_width_bottom = 3
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = face.darkened(0.08)
	disabled.border_width_bottom = 4
	disabled.border_color = edge.darkened(0.1)
	t.set_stylebox(&"normal", kind, normal)
	t.set_stylebox(&"hover", kind, hover)
	t.set_stylebox(&"pressed", kind, pressed)
	t.set_stylebox(&"disabled", kind, disabled)
	t.set_stylebox(&"focus", kind, focus_box())
	t.set_color(&"font_color", kind, text)
	t.set_color(&"font_hover_color", kind, text)
	t.set_color(&"font_pressed_color", kind, text)
	t.set_color(&"font_focus_color", kind, text)
	t.set_color(&"font_disabled_color", kind, text_off)


## A word-wrapped Label in a ScopeTheme ink colour and font size.
static func label(text: String, color: Color = INK, font_size: int = 18) -> Label:
	var out := Label.new()
	out.text = text
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.add_theme_color_override(&"font_color", color)
	out.add_theme_font_size_override(&"font_size", font_size)
	return out


## A ScopeTheme button with the given label and font size.
static func button(text: String, font_size: int = 20) -> Button:
	var out := Button.new()
	out.text = text
	out.add_theme_font_size_override(&"font_size", font_size)
	return out


## A tag: a bordered chip around one Label. The chip is a PanelContainer.
static func chip(text: String, edge: Color, text_color: Color = INK, font_size: int = 16) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override(&"panel", chip_box(edge))
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", text_color)
	label.add_theme_font_size_override(&"font_size", font_size)
	holder.add_child(label)
	return holder


## The Label inside a chip() made here.
static func chip_text(holder: Control) -> String:
	for child: Node in holder.get_children():
		if child is Label:
			return (child as Label).text
	return ""


## A short pad-button badge ("A", "B") for the corner of a button, shown only
## when the pad is the device in use. Give it `refresh_badge` each frame.
static func badge(of_action: StringName) -> Label:
	var label := Label.new()
	label.name = &"PadGlyph"
	label.set_meta(&"action", of_action)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", TEAL)
	label.add_theme_color_override(&"font_outline_color", SHADOW)
	label.add_theme_constant_override(&"outline_size", 6)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	label.position = Vector2(14, 0)
	label.visible = false
	return label


## Sets the badge's glyph from Controls.prompt and shows it only on a pad.
static func refresh_badge(label: Label) -> void:
	var pad: bool = Controls.shown_pad()
	label.visible = pad and label.get_parent() != null and (label.get_parent() as CanvasItem).is_visible_in_tree()
	if pad:
		var text: String = Controls.prompt(StringName(label.get_meta(&"action", &"ui_accept")))
		if label.text != text:
			label.text = text
		label.size = Vector2.ZERO
		label.position = Vector2(14, (label.get_parent() as Control).size.y * 0.5 - label.size.y * 0.5)
