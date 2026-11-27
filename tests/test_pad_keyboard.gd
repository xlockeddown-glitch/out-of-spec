extends RefCounted
## On-screen pad keyboard (feat/pad-keyboard): navigation & wrapping, Shift,
## Backspace, MAX_NAME limit, Done applying the name into PickerUI, and blocking
## picker row cycling / P / Esc while open. Frees every node and restores state.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _snapshot() -> Dictionary:
	return {
		"loadouts": GameState.player_loadouts.duplicate(true),
		"local": GameState.local_player_id,
		"blocked": RoverController.input_blocked,
		"offer": PickerUI.offer_next,
	}


func _restore(snap: Dictionary) -> void:
	GameState.player_loadouts = snap["loadouts"]
	GameState.local_player_id = snap["local"]
	RoverController.input_blocked = snap["blocked"]
	PickerUI.offer_next = snap["offer"]


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func test_move_wrap_shift_backspace_and_max_name() -> String:
	var kb := PadKeyboard.new()
	_root().add_child(kb)
	kb.open("", Loadout.MAX_NAME)
	var problem: String = ""
	# Starts at row 1, col 0 ("q"); moving left wraps to end of row 1 ("p").
	kb.move(0, -1)
	if kb.current_token() != "p":
		problem = "Left from row start should wrap to 'p', got '%s'." % kb.current_token()
	else:
		# Moving up twice from row 1 wraps to bottom row (row 4).
		kb.move(-2, 0)
		if kb.cursor().y != PadKeyboard.KEY_ROWS.size() - 1:
			problem = "Up past top row should wrap to bottom row, got y=%d." % kb.cursor().y
		else:
			# Shift toggles uppercase, punctuation & space work, Backspace removes last char.
			kb.press_key(PadKeyboard.KEY_SHIFT)
			kb.press_key("o")
			kb.press_key(PadKeyboard.KEY_SHIFT)
			kb.press_key("r")
			kb.press_key("-")
			kb.press_key("'")
			kb.press_key(PadKeyboard.KEY_SPACE)
			kb.press_key("9")
			if kb.text() != "Or-' 9":
				problem = "Expected \"Or-' 9\", got '%s'." % kb.text()
			else:
				kb.backspace()
				if kb.text() != "Or-' ":
					problem = "Backspace should drop last character, got '%s'." % kb.text()
				else:
					for i: int in Loadout.MAX_NAME + 5:
						kb.press_key("a")
					if kb.text().length() != Loadout.MAX_NAME:
						problem = "Buffer exceeded MAX_NAME (%d): got %d." % [Loadout.MAX_NAME, kb.text().length()]
	kb.close()
	_free(kb)
	return problem


func test_picker_keyboard_writes_name_and_blocks_rows_while_open() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts.erase(GameState.local_player_id)
	var picker := PickerUI.new()
	_root().add_child(picker)
	picker.open()
	var problem: String = ""
	var before_head: StringName = picker.chosen()[Loadout.HEAD]
	picker.open_keyboard()
	if not picker._keyboard.visible:
		problem = "open_keyboard() must show PadKeyboard."
	else:
		# While keyboard is open, picker row cycling and P / Esc must not act on picker.
		picker.cycle(Loadout.HEAD, 1)
		picker._unhandled_input(_key(KEY_P))
		picker._unhandled_input(_key(KEY_ESCAPE))
		if picker.chosen()[Loadout.HEAD] != before_head:
			problem = "Picker rows must not cycle while PadKeyboard is open."
		elif not picker.visible:
			problem = "Picker must not close from P/Esc while PadKeyboard is open."
		else:
			# Type "Rya" with Shift + A presses, then finish with Done.
			picker._keyboard.press_key(PadKeyboard.KEY_SHIFT)
			picker._keyboard.press_key("r")
			picker._keyboard.press_key(PadKeyboard.KEY_SHIFT)
			picker._keyboard.press_key("y")
			picker._keyboard.press_key("a")
			picker._keyboard.press_key(PadKeyboard.KEY_DONE)
			if picker._keyboard.visible:
				problem = "Done must close PadKeyboard."
			elif picker.chosen_name() != "Rya":
				problem = "Picker name should be 'Rya', got '%s'." % picker.chosen_name()
			else:
				# Once closed, picker rows cycle normally again.
				picker.cycle(Loadout.HEAD, 1)
				if picker.chosen()[Loadout.HEAD] == before_head:
					problem = "Picker rows should cycle again after PadKeyboard closes."
	picker.close()
	_free(picker)
	_restore(snap)
	return problem


func test_pad_b_deletes_then_closes_when_empty() -> String:
	var snap: Dictionary = _snapshot()
	var picker := PickerUI.new()
	_root().add_child(picker)
	picker.open()
	picker.set_chosen_name("A")
	picker.open_keyboard()
	# First B deletes "A"; second B on empty closes keyboard and keeps picker open.
	picker._keyboard._input(_pad(JOY_BUTTON_B))
	var after_first: String = picker.chosen_name()
	var still_open: bool = picker._keyboard.visible
	picker._keyboard._input(_pad(JOY_BUTTON_B))
	var closed_after_second: bool = not picker._keyboard.visible
	var picker_still_open: bool = picker.visible
	picker.close()
	_free(picker)
	_restore(snap)
	if after_first != "" or not still_open:
		return "First B should delete last char while keeping keyboard open: '%s', open=%s" % [after_first, still_open]
	return "" if closed_after_second and picker_still_open else "Second B on empty should close keyboard and keep picker open."
