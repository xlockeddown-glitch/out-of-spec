class_name ToolRollUI
extends Control
## The Tool Roll: a read-only view of what the local player's farm holds, in a cream,
## tabbed panel of item slots (Ryan's playtest, Nov 27: "how do I know I have blocks?").
## I opens and closes it on the farm, in the dome and in the tunnels; the pad reaches it
## through the actions menu (Back is the scene swap). It only reads GameState, adds no
## item and saves nothing; it updates as the state changes, and a co-op guest sees what
## the host has synced to them. Every word, size and number here is a [PLACEHOLDER].

const TITLE: String = "TOOL ROLL"
const ACTION: StringName = &"inventory"
## The tabs, in order: id and label.
const TAB_TOOLS: StringName = &"tools"
const TAB_CROPS: StringName = &"crops"
const TAB_BLOCKS: StringName = &"blocks"
const TAB_SUPPLIES: StringName = &"supplies"
const TABS: Array[Dictionary] = [
	{ "id": TAB_TOOLS, "label": "TOOLS" },
	{ "id": TAB_CROPS, "label": "CROPS AND SEEDS" },
	{ "id": TAB_BLOCKS, "label": "BLOCKS" },
	{ "id": TAB_SUPPLIES, "label": "SUPPLIES" },
]
## What an empty tab says.
const EMPTY_TEXT: Dictionary[StringName, String] = {
	TAB_TOOLS: "No tools yet.",
	TAB_CROPS: "No seeds or crops yet.",
	TAB_BLOCKS: "No gauge blocks yet. Dig for them.",
	TAB_SUPPLIES: "Nothing in store.",
}
const ICON_DIR: String = "res://assets/icons/%s.png"
const ICON_SIZE: float = 64.0
const SEED_ICON: String = "seed_packet"
const SET_TEXT: String = "Set %s / %s"
const COLUMNS: int = 2
const SLOT_WIDTH: float = 420.0

## Icons already loaded, by file name: a rebuild frees every slot, so reload would repeat.
static var _textures: Dictionary[String, Texture2D] = {}

var _tab: StringName = TAB_TOOLS
## A rebuild is already queued for the end of this frame.
var _dirty: bool = false
var _tab_buttons: Dictionary[StringName, Button] = {}
var _grid: GridContainer
var _scroll: ScrollContainer
var _empty: Label
var _close_button: Button
var _glyph: Label
## What had the focus when the roll opened: it gets it back.
var _focus_before: Control
## The rover's input block as it was when the roll opened: it goes back to that.
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
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for entry: Dictionary in TABS:
		var button := Button.new()
		button.name = "Tab_%s" % entry["id"]
		button.text = entry["label"]
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override(&"font_size", 20)
		button.pressed.connect(_select.bind(entry["id"]))
		tabs.add_child(button)
		_tab_buttons[entry["id"]] = button
	# The canvas: a cream card the slots sit on.
	var canvas := PanelContainer.new()
	canvas.theme_type_variation = ScopeTheme.PHONE_CARD
	column.add_child(canvas)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 400)
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(inner)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	inner.add_child(_grid)
	_empty = PlanBoardUI._label("", ScopeTheme.CARD_INK_MUTED, 22)
	_empty.name = &"EmptyText"
	inner.add_child(_empty)
	_close_button = Button.new()
	_close_button.text = "CLOSE  (%s or %s)" % [Controls.key_label(ACTION), Controls.key_label(&"ui_cancel")]
	_close_button.add_theme_font_size_override(&"font_size", 22)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	_glyph = ScopeTheme.badge(&"ui_cancel")
	_close_button.add_child(_glyph)
	column.add_child(_close_button)
	# What the roll shows changes with these.
	for changed: Signal in [GameState.crops_changed, GameState.blocks_changed, GameState.stone_changed,
			GameState.upgrades_changed, GameState.farm_loaded, GameState.lab_changed,
			GameState.oirm_changed]:
		changed.connect(_on_changed)
	GameState.ore_changed.connect(_on_changed.unbind(1))
	GameState.credits_changed.connect(_on_changed.unbind(1))
	GameState.silk_changed.connect(_on_changed.unbind(1))
	_tab_buttons[_tab].button_pressed = true
	hide()


func _process(_delta: float) -> void:
	if visible:
		ScopeTheme.refresh_badge(_glyph)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(ACTION)
	if not visible:
		# Not over another panel (the phone's bench, the quest board, a minigame, ...).
		if toggled and not QuestsUI.other_panel_open(get_tree(), self):
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	# As in SkillsUI: no key or pad press reaches the farm behind the roll.
	elif key != null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func open() -> void:
	# Opening again while open must not save our own block as the old state.
	if not visible:
		_blocked_before = RoverController.input_blocked
		_focus_before = get_viewport().gui_get_focus_owner()
	RoverController.input_blocked = true
	_refresh()
	show()
	_scroll.scroll_vertical = 0
	_tab_buttons[_tab].grab_focus()


## Hides the roll and gives the focus back to what had it before open().
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


## If the roll is torn down while open, the rover gets its controls back.
func _exit_tree() -> void:
	if visible:
		RoverController.input_blocked = _blocked_before


func current_tab() -> StringName:
	return _tab


func _select(tab: StringName) -> void:
	_tab = tab
	_refresh()


func _on_changed() -> void:
	# A farm load fires many of these in a row: one rebuild at the end of the frame.
	if visible and not _dirty:
		_dirty = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_dirty = false
	if visible:
		_refresh()


## The slots on a tab, from what GameState holds now: id, name, count (the text shown),
## detail (a line under the name, may be empty) and icon (a file name in assets/icons,
## "" when none fits). Pure: it reads the state and changes nothing.
static func slots(tab: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match tab:
		TAB_TOOLS:
			if GameState.is_in_service(GameState.SOIL_PROBE_ID):
				out.append(_slot("soil_probe", GameState.instrument_name(GameState.SOIL_PROBE_ID, true), "1", "", "probe"))
			for id: String in GameState.standard_ids():
					var away: String = "Reference standard"
					if GameState.at_oirm.has(id):
						away = "At OIRM until day %s" % SP811.integer(int(GameState.at_oirm[id]))
					out.append(_slot("standard:" + id, GameState.instrument_name(id, true), "1", away, "wrench"))
			if GameState.has_wide_treads:
				out.append(_slot("wide_treads", "Wide treads", "1", "Fitted to the rover", ""))
		TAB_CROPS:
			var seed_id: String = GameState.current_seed()
			if seed_id != "":
				out.append(_slot("seed", "%s seeds" % GameState.crop_name(seed_id), "NEXT",
					"Bought as planted, %s CR each" % SP811.integer(GameState.seed_cost(seed_id)), SEED_ICON))
			var held: Dictionary = {}
			var in_spec: Dictionary = {}
			for entry: Dictionary in GameState.harvest_bin:
				var crop_id: String = str(entry.get("crop_id", ""))
				held[crop_id] = int(held.get(crop_id, 0)) + 1
				if entry.get("in_spec", false):
					in_spec[crop_id] = int(in_spec.get(crop_id, 0)) + 1
			for crop_id: String in GameState.crop_ids():
				if held.has(crop_id):
					out.append(_slot("crop:" + crop_id, GameState.crop_name(crop_id), SP811.integer(held[crop_id]),
						"%s in spec, in the bin" % SP811.integer(int(in_spec.get(crop_id, 0))), crop_id))
		TAB_BLOCKS:
			var pieces: Dictionary = GameState.gauge_pieces()
			if not pieces.is_empty():
				var grades: Array[int] = GaugeSet.grade_counts(pieces)
				var by_grade: PackedStringArray = []
				for g: int in GaugeSet.GRADES.size():
					by_grade.append("grade %s: %s" % [GaugeSet.GRADES[g], SP811.integer(grades[g])])
				out.append(_slot("gauge_set", "Gauge block set", SET_TEXT % [SP811.integer(pieces.size()), SP811.integer(GaugeSet.size_count())],
					", ".join(by_grade), "gauge_block_set"))
				out.append(_slot("blocks_found", "Blocks dug up", SP811.integer(GameState.found_blocks.size()),
					"Each block fills the next free size", ""))
		TAB_SUPPLIES:
			if GameState.credits != 0:
				out.append(_slot("credits", "Credits", SP811.integer(GameState.credits), "CR", ""))
			if GameState.stone > 0:
				out.append(_slot("stone", "Stone", SP811.integer(GameState.stone), "", ""))
			if GameState.crystal_ore > 0:
				out.append(_slot("crystal_ore", "Crystal ore", SP811.integer(GameState.crystal_ore), "", ""))
			if GameState.optical_silk_spools > 0:
				out.append(_slot("silk", "Optical silk spools", GameState.spool_count_text(), "", "silk_spool"))
	return out


static func _slot(id: String, label: String, count: String, detail: String, icon: String) -> Dictionary:
	return { "id": id, "name": label, "count": count, "detail": detail,
		"icon": icon if icon != "" and ResourceLoader.exists(ICON_DIR % icon) else "" }


## The two letters a placeholder chip shows: the initials of the item's name.
static func initials(label: String) -> String:
	var out: String = ""
	for word: String in label.split(" ", false):
		out += word.substr(0, 1).to_upper()
		if out.length() >= 2:
			break
	return out


func _refresh() -> void:
	# A rebuild must not strand a pad: remember which slot had the focus.
	var focused: int = -1
	var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner != null and owner.get_parent() == _grid:
		focused = owner.get_index()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var items: Array[Dictionary] = slots(_tab)
	_empty.text = EMPTY_TEXT[_tab] if items.is_empty() else ""
	_empty.visible = items.is_empty()
	for item: Dictionary in items:
		_grid.add_child(_slot_node(item))
	if focused >= 0 and _grid.get_child_count() > 0:
		(_grid.get_child(mini(focused, _grid.get_child_count() - 1)) as Control).grab_focus()
	elif focused >= 0:
		# The slot that had the focus is gone and none is left: the tab takes it.
		_tab_buttons[_tab].grab_focus()
	# Down from a tab, and up from CLOSE, reach the slots even when the scroll hides them.
	var tab_button: Button = _tab_buttons[_tab]
	if _grid.get_child_count() > 0:
		var first: Control = _grid.get_child(0) as Control
		for button: Button in _tab_buttons.values():
			button.focus_neighbor_bottom = button.get_path_to(first)
		var last: Control = _grid.get_child(_grid.get_child_count() - 1) as Control
		_close_button.focus_neighbor_top = _close_button.get_path_to(last)
		last.focus_neighbor_bottom = last.get_path_to(_close_button)
	else:
		for button: Button in _tab_buttons.values():
			button.focus_neighbor_bottom = button.get_path_to(_close_button)
		_close_button.focus_neighbor_top = _close_button.get_path_to(tab_button)


func _slot_node(item: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "Slot_%s" % str(item["id"]).replace(":", "_")
	slot.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_stylebox_override(&"panel", ScopeTheme.box(ScopeTheme.ENAMEL, ScopeTheme.ENAMEL_LIP, 3, 8, 10))
	slot.focus_mode = Control.FOCUS_ALL
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(row)
	row.add_child(_icon_node(item))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label: Label = PlanBoardUI._label(str(item["name"]), ScopeTheme.CARD_INK, 20)
	name_label.name = &"Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	if str(item["detail"]) != "":
		var detail: Label = PlanBoardUI._label(str(item["detail"]), ScopeTheme.CARD_INK_MUTED, 16)
		detail.name = &"Detail"
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(detail)
	var count: Label = PlanBoardUI._label(str(item["count"]), ScopeTheme.CARD_INK, 26)
	count.name = &"Count"
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	_add_ring(slot)
	return slot


## The item's icon from assets/icons, or a chip with its initials where none fits.
func _icon_node(item: Dictionary) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(item["icon"]) != "":
		var picture := TextureRect.new()
		picture.name = &"Icon"
		var file: String = str(item["icon"])
		if not _textures.has(file):
			_textures[file] = load(ICON_DIR % file) as Texture2D
		picture.texture = _textures[file]
		picture.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
	else:
		var chip: PanelContainer = ScopeTheme.chip(initials(str(item["name"])), ScopeTheme.ENAMEL_LIP, ScopeTheme.INK, 24)
		chip.name = &"IconChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(chip)
	return holder


func _add_ring(holder: PanelContainer) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override(&"panel", ScopeTheme.focus_box())
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.name = &"FocusRing"
	ring.hide()
	holder.add_child(ring)
	holder.focus_entered.connect(ring.show)
	holder.focus_exited.connect(ring.hide)
