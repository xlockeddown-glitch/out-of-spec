class_name Controls
extends RefCounted
## The names of the keys and pad buttons, read from the InputMap so they never go
## stale, and which device the local player used last. Every on-screen "press E"
## builds its key with prompt(), at the moment it is shown, on that player's PC:
## never store this text in a save or send it over the network.

enum Device { KEY, PAD }

## What the pad buttons are called on an Xbox pad.
const PAD_BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
## Keys whose Godot names are long or not what is printed on the key.
const KEY_NAMES: Dictionary[int, String] = {
	KEY_ESCAPE: "Esc", KEY_SPACE: "Space", KEY_TAB: "Tab", KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter",
	KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_UP: "Up", KEY_DOWN: "Down",
	KEY_LEFT: "Left", KEY_RIGHT: "Right",
}
## A stick must be pushed this far to count as the player using the pad.
const STICK_NOTICE: float = 0.5
## [PLACEHOLDER] words for a verb the pad reaches only through the actions menu.
const MENU_WORDS: String = "LB + RB > %s"
const CONTROLS_ACTION: StringName = &"open_controls"

## The device the local player touched last.
static var last_device: Device = Device.KEY
## Tests set this to act as if a pad were plugged in.
static var pad_present_override: bool = false
## The first-launch line is told once for each run of the game.
static var hint_told: bool = false


## Called with every input event (GameState does). A key or mouse click means
## the keyboard; a pad button, or a stick pushed hard, means the pad.
static func note_event(event: InputEvent) -> void:
	if event is InputEventKey:
		if (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			last_device = Device.KEY
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			last_device = Device.KEY
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			last_device = Device.PAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_NOTICE:
			last_device = Device.PAD


static func pad_connected() -> bool:
	return pad_present_override or not Input.get_connected_joypads().is_empty()


## Whether prompts show the pad: it is the last device used and one is plugged in.
static func using_pad() -> bool:
	return last_device == Device.PAD and pad_connected()


## "E", "Space", "Esc", "[": the first key of the action, "" if it has none.
static func key_label(action: StringName) -> String:
	for event: InputEvent in _events(action):
		if event is InputEventKey:
			return _key_name(event as InputEventKey)
	return ""


## Every key of the action: "W / Up".
static func key_labels(action: StringName) -> String:
	var found: PackedStringArray = []
	for event: InputEvent in _events(action):
		if event is InputEventKey:
			var text: String = _key_name(event as InputEventKey)
			if not text in found:
				found.append(text)
	return " / ".join(found)


## "A", "RB", "D-pad up", "LS up / RT": every pad input of the action, "" if it has none.
static func pad_label(action: StringName) -> String:
	var found: PackedStringArray = []
	for event: InputEvent in _events(action):
		var text: String = ""
		if event is InputEventJoypadButton:
			text = PAD_BUTTONS.get((event as InputEventJoypadButton).button_index, "")
		elif event is InputEventJoypadMotion:
			text = _axis_name(event as InputEventJoypadMotion)
		if text != "" and not text in found:
			found.append(text)
	return " / ".join(found)


## What to tell the player to press for the action, on the device they use:
## the key, or the pad button, or for a verb only the actions menu has, the way there.
static func prompt(action: StringName) -> String:
	if using_pad():
		var pad: String = pad_label(action)
		if pad != "":
			return pad
		return MENU_WORDS % menu_name(action)
	var key: String = key_label(action)
	return key if key != "" else pad_label(action)


## The name the actions menu gives the verb: "ROBOTS", "BUY", "CONTROLS".
static func menu_name(action: StringName) -> String:
	for entry: Dictionary in ActionsMenuUI.ENTRIES:
		if entry["action"] == action:
			return String(entry["label"]).split(" (")[0]
	if ActionsMenuUI.BUY_ACTIONS.has(action):
		return "BUY"
	return "ACTIONS"


## The first-launch line, wording for the device: the pad player sees the pad way.
static func hint_text() -> String:
	var menu: String = MENU_WORDS % menu_name(CONTROLS_ACTION)
	if using_pad():
		return "Press %s for the controls." % menu
	var key: String = key_label(CONTROLS_ACTION)
	if pad_connected():
		return "Press %s (or %s) for the controls." % [key, menu]
	return "Press %s for the controls." % key


## Says the first-launch line once to a phone (anything with push_log).
static func tell_once(hud: Object) -> void:
	if hint_told or hud == null:
		return
	hint_told = true
	hud.call(&"push_log", hint_text())


static func _events(action: StringName) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)


static func _key_name(event: InputEventKey) -> String:
	var code: int = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if KEY_NAMES.has(code):
		return KEY_NAMES[code]
	return OS.get_keycode_string(code)


static func _axis_name(event: InputEventJoypadMotion) -> String:
	var up: bool = event.axis_value < 0.0
	match event.axis:
		JOY_AXIS_LEFT_X:
			return "LS left" if up else "LS right"
		JOY_AXIS_LEFT_Y:
			return "LS up" if up else "LS down"
		JOY_AXIS_RIGHT_X:
			return "RS left" if up else "RS right"
		JOY_AXIS_RIGHT_Y:
			return "RS up" if up else "RS down"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return ""
