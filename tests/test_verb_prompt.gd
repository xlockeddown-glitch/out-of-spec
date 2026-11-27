extends RefCounted
## The "[E] verb" prompt over the thing in reach: the right key and verb, hidden when
## nothing is in reach or a panel holds the screen, the glyph following the device.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _reset() -> void:
	Controls.last_device = Controls.Device.KEY
	Controls.pad_present_override = false


func _prompt() -> VerbPrompt:
	var prompt := VerbPrompt.new()
	_root().add_child(prompt)
	return prompt


func test_shows_key_and_verb_for_a_target_in_reach() -> String:
	_reset()
	var pad := ParkingPad.new()
	pad.verb = "Calibrate"
	var prompt: VerbPrompt = _prompt()
	var shown: bool = prompt.point_at(Vector2(400.0, 300.0), VerbPrompt.verb_of(pad))
	var text: String = prompt.text
	var visible_now: bool = prompt.visible
	prompt.free()
	pad.free()
	if not shown or not visible_now:
		return "The prompt should show for a target in reach"
	return "" if text == "[E] Calibrate" else "Expected \"[E] Calibrate\", got \"%s\"" % text


func test_clear_hides_it() -> String:
	var prompt: VerbPrompt = _prompt()
	prompt.point_at(Vector2(100.0, 100.0), "Open")
	prompt.clear()
	var hidden: bool = not prompt.visible
	prompt.free()
	return "" if hidden else "clear() should hide the prompt"


func test_hidden_while_a_panel_holds_the_screen() -> String:
	var prompt: VerbPrompt = _prompt()
	var panel := Control.new()
	panel.add_to_group(QuestsUI.MODAL_GROUP)
	_root().add_child(panel)
	var shown: bool = prompt.point_at(Vector2(100.0, 100.0), "Open")
	var hidden: bool = not prompt.visible
	panel.free()
	var back: bool = prompt.point_at(Vector2(100.0, 100.0), "Open")
	prompt.free()
	if shown or not hidden:
		return "An open panel should hide the prompt"
	return "" if back else "The prompt should come back when the panel closes"


func test_glyph_follows_the_device() -> String:
	_reset()
	var prompt: VerbPrompt = _prompt()
	prompt.point_at(Vector2(200.0, 200.0), "Open")
	var on_keys: String = prompt.text
	Controls.pad_present_override = true
	Controls.last_device = Controls.Device.PAD
	prompt.point_at(Vector2(200.0, 200.0), "Open")
	var on_pad: String = prompt.text
	_reset()
	prompt.free()
	if on_keys != "[E] Open":
		return "Keyboard: expected \"[E] Open\", got \"%s\"" % on_keys
	return "" if on_pad == "[A] Open" else "Pad: expected \"[A] Open\", got \"%s\"" % on_pad


func test_other_actions_use_their_own_key() -> String:
	_reset()
	var text: String = VerbPrompt.text_for("Get in rover", &"get_out_in")
	var want: String = "[%s] Get in rover" % Controls.key_label(&"get_out_in")
	return "" if text == want else "Expected \"%s\", got \"%s\"" % [want, text]


func test_fallback_verb_when_the_target_names_none() -> String:
	_reset()
	var click := Clickable.new()
	var pad := ParkingPad.new()
	var plain := Node.new()
	var bad: PackedStringArray = []
	for target: Object in [click, pad, plain, null]:
		if VerbPrompt.verb_of(target) != VerbPrompt.FALLBACK_VERB:
			bad.append(str(target))
	var text: String = VerbPrompt.text_for("")
	click.free()
	pad.free()
	plain.free()
	if not bad.is_empty():
		return "Fallback missing for: %s" % ", ".join(bad)
	return "" if text == "[E] Use" else "Expected \"[E] Use\", got \"%s\"" % text


func test_clickable_verb_is_used() -> String:
	var click := Clickable.new()
	click.verb = "Board shuttle"
	var verb: String = VerbPrompt.verb_of(click)
	click.free()
	return "" if verb == "Board shuttle" else "Got \"%s\"" % verb


func test_prompt_stays_inside_its_limit() -> String:
	var prompt: VerbPrompt = _prompt()
	prompt.limit = Vector2(800.0, 600.0)
	prompt.point_at(Vector2(5000.0, -300.0), "Open")
	var inside: bool = prompt.position.x + prompt.size.x <= 800.0 and prompt.position.y >= 0.0
	prompt.free()
	return "" if inside else "The prompt should be clamped to the limit"
