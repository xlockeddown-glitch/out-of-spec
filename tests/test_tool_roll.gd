extends RefCounted
## The Tool Roll (feat/inventory): a read-only view of what GameState holds. Counts match
## the state (zero and gauge-set progress included), I and Esc open and close it, it does
## not open over another panel, icons are used where one exists and a chip where not.
## Local UI only: no save, no protocol.

const SEED: int = 424242


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _pad_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _snapshot() -> Dictionary:
	return {
		"found_blocks": GameState.found_blocks.duplicate(),
		"world_seed": GameState.world_seed,
		"harvest_bin": GameState.harvest_bin.duplicate(true),
		"credits": GameState.credits,
		"stone": GameState.stone,
		"crystal_ore": GameState.crystal_ore,
		"optical_silk_spools": GameState.optical_silk_spools,
		"has_wide_treads": GameState.has_wide_treads,
		"blocked": RoverController.input_blocked,
	}


func _restore(snap: Dictionary) -> void:
	GameState.found_blocks = snap["found_blocks"]
	GameState.world_seed = snap["world_seed"]
	GameState.harvest_bin = snap["harvest_bin"]
	GameState.credits = snap["credits"]
	GameState.stone = snap["stone"]
	GameState.crystal_ore = snap["crystal_ore"]
	GameState.optical_silk_spools = snap["optical_silk_spools"]
	GameState.has_wide_treads = snap["has_wide_treads"]
	RoverController.input_blocked = snap["blocked"]


func _roll() -> ToolRollUI:
	var roll := ToolRollUI.new()
	_root().add_child(roll)
	return roll


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


## The first `count` cells that hold a buried block for the seed.
func _block_cells(count: int) -> Array[Vector2i]:
	var none: Dictionary[Vector2i, int] = {}
	var out: Array[Vector2i] = []
	for x: int in range(-60, 60):
		for z: int in range(-60, 60):
			var cell := Vector2i(x, z)
			if Terrain.dig_problem(cell, none) == "" and not ReferenceBlock.at(SEED, cell).is_empty():
				out.append(cell)
				if out.size() >= count:
					return out
	return out


func _slot(tab: StringName, id: String) -> Dictionary:
	for item: Dictionary in ToolRollUI.slots(tab):
		if item["id"] == id:
			return item
	return {}


func test_blocks_tab_is_empty_with_no_blocks() -> String:
	var snap: Dictionary = _snapshot()
	GameState.world_seed = SEED
	GameState.found_blocks = {}
	var items: Array[Dictionary] = ToolRollUI.slots(ToolRollUI.TAB_BLOCKS)
	var roll: ToolRollUI = _roll()
	roll._select(ToolRollUI.TAB_BLOCKS)
	var said: String = roll._empty.text
	var shown: bool = roll._empty.visible
	var cards: int = roll._grid.get_child_count()
	_free(roll)
	_restore(snap)
	if not items.is_empty() or cards != 0:
		return "No blocks must give no slots."
	return "" if shown and said == ToolRollUI.EMPTY_TEXT[ToolRollUI.TAB_BLOCKS] else "An empty tab must say so, not '%s'." % said


func test_gauge_set_progress_matches_the_state() -> String:
	var snap: Dictionary = _snapshot()
	GameState.world_seed = SEED
	var cells: Array[Vector2i] = _block_cells(3)
	GameState.found_blocks = {}
	for cell: Vector2i in cells:
		GameState.found_blocks[cell] = true
	var pieces: Dictionary = GameState.gauge_pieces()
	var set_slot: Dictionary = _slot(ToolRollUI.TAB_BLOCKS, "gauge_set")
	var found_slot: Dictionary = _slot(ToolRollUI.TAB_BLOCKS, "blocks_found")
	var roll: ToolRollUI = _roll()
	roll._select(ToolRollUI.TAB_BLOCKS)
	var texts: PackedStringArray = []
	for slot: Node in roll._grid.get_children():
		var count: Label = slot.find_child("Count", true, false) as Label
		if count != null:
			texts.append(count.text)
	_free(roll)
	_restore(snap)
	var want: String = "Set %d / %d" % [pieces.size(), GaugeSet.size_count()]
	if cells.size() != 3 or pieces.is_empty():
		return "The test needs three buried blocks."
	if set_slot.get("count", "") != want:
		return "The set slot says '%s', not '%s'." % [set_slot.get("count", ""), want]
	if found_slot.get("count", "") != "3":
		return "Blocks dug up must be 3, not '%s'." % found_slot.get("count", "")
	return "" if want in texts and "3" in texts else "The slots on screen must show the counts (%s)." % ", ".join(texts)


func test_the_set_slot_uses_its_icon() -> String:
	var snap: Dictionary = _snapshot()
	GameState.world_seed = SEED
	GameState.found_blocks = {}
	for cell: Vector2i in _block_cells(1):
		GameState.found_blocks[cell] = true
	var roll: ToolRollUI = _roll()
	roll._select(ToolRollUI.TAB_BLOCKS)
	var first: Node = roll._grid.get_child(0)
	var with_icon: bool = first.find_child("Icon", true, false) != null and first.find_child("IconChip", true, false) == null
	var other: Node = roll._grid.get_child(1)
	var with_chip: bool = other.find_child("IconChip", true, false) != null and other.find_child("Icon", true, false) == null
	var initials: String = ToolRollUI.initials("Blocks dug up")
	_free(roll)
	_restore(snap)
	if not with_icon:
		return "The gauge set has an icon, so it must show it."
	if not with_chip:
		return "An item with no icon must show a placeholder chip."
	return "" if initials == "BD" else "The chip must carry the initials, not '%s'." % initials


func test_supplies_match_the_state_and_zero_is_left_out() -> String:
	var snap: Dictionary = _snapshot()
	GameState.credits = 0
	GameState.stone = 0
	GameState.crystal_ore = 0
	GameState.optical_silk_spools = 0
	var none: int = ToolRollUI.slots(ToolRollUI.TAB_SUPPLIES).size()
	GameState.credits = 1250
	GameState.stone = 7
	GameState.crystal_ore = 3
	GameState.optical_silk_spools = 2
	var credits: Dictionary = _slot(ToolRollUI.TAB_SUPPLIES, "credits")
	var stone: Dictionary = _slot(ToolRollUI.TAB_SUPPLIES, "stone")
	var ore: Dictionary = _slot(ToolRollUI.TAB_SUPPLIES, "crystal_ore")
	var silk: Dictionary = _slot(ToolRollUI.TAB_SUPPLIES, "silk")
	_restore(snap)
	if none != 0:
		return "Zero supplies must show no slots, not %d." % none
	if credits.get("count", "") != SP811.integer(1250) or stone.get("count", "") != "7" or ore.get("count", "") != "3":
		return "Supplies must match GameState: %s, %s, %s." % [credits.get("count", ""), stone.get("count", ""), ore.get("count", "")]
	if silk.get("count", "") != "2" or silk.get("icon", "") != "silk_spool":
		return "Silk spools must show 2 with the spool icon."
	return ""


func test_crops_count_the_bin_and_name_the_seed() -> String:
	var snap: Dictionary = _snapshot()
	GameState.harvest_bin = []
	var ids: Array[String] = GameState.crop_ids()
	var crop: String = ids[0]
	var crops_none: int = ToolRollUI.slots(ToolRollUI.TAB_CROPS).size()
	GameState.harvest_bin = [
		{ "crop_id": crop, "in_spec": true, "out_of_band_days": 0, "advance": 0 },
		{ "crop_id": crop, "in_spec": false, "out_of_band_days": 1, "advance": 0 },
		{ "crop_id": crop, "in_spec": true, "out_of_band_days": 0, "advance": 0 },
	]
	var held: Dictionary = _slot(ToolRollUI.TAB_CROPS, "crop:" + crop)
	var seed_slot: Dictionary = _slot(ToolRollUI.TAB_CROPS, "seed")
	_restore(snap)
	if crops_none != 1:
		return "An empty bin must show only the seed slot, not %d." % crops_none
	if held.get("count", "") != "3" or not str(held.get("detail", "")).begins_with("2 in spec"):
		return "The bin has 3 of %s (2 in spec), the slot says %s / %s." % [crop, held.get("count", ""), held.get("detail", "")]
	if seed_slot.get("icon", "") != "seed_packet":
		return "The seed slot must use the seed packet icon."
	return "" if crop == "biscuit_reed" and held.get("icon", "") == "biscuit_reed" or crop != "biscuit_reed" else "A crop with an icon must show it."


func test_tools_list_the_standards_held() -> String:
	var snap: Dictionary = _snapshot()
	GameState.has_wide_treads = false
	var base: Array[Dictionary] = ToolRollUI.slots(ToolRollUI.TAB_TOOLS)
	var standards: int = GameState.standard_ids().size()
	var wrench_count: int = 0
	for item: Dictionary in base:
		if item["icon"] == "wrench":
			wrench_count += 1
	GameState.has_wide_treads = true
	var treads: Dictionary = _slot(ToolRollUI.TAB_TOOLS, "wide_treads")
	_restore(snap)
	if wrench_count != standards:
		return "Each standard held is a slot: %d, not %d." % [standards, wrench_count]
	return "" if not treads.is_empty() and treads["icon"] == "" else "Wide treads must show, with a chip."


func test_i_opens_and_closes_and_esc_closes() -> String:
	var snap: Dictionary = _snapshot()
	RoverController.input_blocked = false
	var roll: ToolRollUI = _roll()
	roll._unhandled_input(_key(KEY_I))
	var opened: bool = roll.visible
	var blocked: bool = RoverController.input_blocked
	roll._unhandled_input(_key(KEY_I))
	var closed: bool = not roll.visible
	var unblocked: bool = not RoverController.input_blocked
	roll._unhandled_input(_key(KEY_I))
	roll._unhandled_input(_key(KEY_ESCAPE))
	var esc_closed: bool = not roll.visible
	roll._unhandled_input(_key(KEY_I))
	roll._unhandled_input(_pad_button(JOY_BUTTON_B))
	var b_closed: bool = not roll.visible
	_free(roll)
	_restore(snap)
	if not opened or not blocked:
		return "I must open the roll and hold the rover's controls."
	if not closed or not unblocked:
		return "I must close it and give the controls back."
	if not esc_closed:
		return "Esc must close it."
	return "" if b_closed else "B must close it."


func test_it_does_not_open_over_another_panel() -> String:
	var roll: ToolRollUI = _roll()
	var other := Control.new()
	other.add_to_group(QuestsUI.MODAL_GROUP)
	_root().add_child(other)
	roll._unhandled_input(_key(KEY_I))
	var opened: bool = roll.visible
	_free(other)
	_free(roll)
	return "The roll opened over another panel" if opened else ""


func test_the_roll_takes_keys_while_open() -> String:
	var snap: Dictionary = _snapshot()
	var roll: ToolRollUI = _roll()
	roll.open()
	var event: InputEventKey = _key(KEY_W)
	var viewport: Viewport = roll.get_viewport()
	roll._unhandled_input(event)
	var handled: bool = viewport.is_input_handled()
	viewport.set_input_as_handled()
	roll.close()
	_free(roll)
	_restore(snap)
	return "" if handled else "A key press must not reach the farm while the roll is open."


func test_it_updates_when_the_state_changes() -> String:
	var snap: Dictionary = _snapshot()
	GameState.stone = 0
	GameState.credits = 0
	GameState.crystal_ore = 0
	GameState.optical_silk_spools = 0
	var roll: ToolRollUI = _roll()
	roll.open()
	roll._select(ToolRollUI.TAB_SUPPLIES)
	var before: int = roll._grid.get_child_count()
	GameState.stone = 4
	GameState.stone_changed.emit()
	# The old slots are freed at the end of the frame; what is parented now is what shows.
	var after: int = 0
	for child: Node in roll._grid.get_children():
		if not child.is_queued_for_deletion():
			after += 1
	roll.close()
	_free(roll)
	_restore(snap)
	return "" if before == 0 and after == 1 else "The roll must rebuild on stone_changed (%d, then %d)." % [before, after]


func test_the_key_and_the_menu_are_set_up() -> String:
	if not InputMap.has_action(ToolRollUI.ACTION) or Controls.key_label(ToolRollUI.ACTION) != "I":
		return "The inventory action must be the I key."
	if not ActionsMenuUI.PANEL_ACTIONS.has(ToolRollUI.ACTION) or not ActionsMenuUI.farm_actions().has(ToolRollUI.ACTION):
		return "The pad reaches the roll through the actions menu."
	return "" if ControlsGuideUI.listed_actions().has(ToolRollUI.ACTION) else "The controls guide must list the key."
