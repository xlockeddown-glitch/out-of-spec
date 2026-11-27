class_name VerbPrompt
extends Label
## One label over the thing the interact key would use: "[E] Calibrate" on the
## keyboard, "[A] Calibrate" on a pad (Controls, at the moment it is shown). A scene
## owns one, points it at a screen position each frame, or clears it. Local only:
## nothing here is saved or sent.

## [PLACEHOLDER] The verb when the target does not name one.
const FALLBACK_VERB: String = "Use"
## [PLACEHOLDER] Pixels the label sits above the point it marks.
const LIFT_PX: float = 56.0
const FONT_SIZE: int = 28
const OUTLINE_PX: int = 8
## [PLACEHOLDER] The label is never closer than this to the screen edge.
const EDGE_PX: float = 24.0

## The area the label stays inside (the world view, not the phone beside it);
## zero keeps it inside its parent.
var limit: Vector2 = Vector2.ZERO
## [PLACEHOLDER] The bottom edge the label keeps clear of (the hint line stands below it), px.
var floor_px: float = 0.0

var _shown_verb: String = ""
var _shown_action: StringName = &""
var _shown_pad: bool = false
var _has_text: bool = false


func _init() -> void:
	name = "VerbPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_color_override(&"font_color", ScopeTheme.INK)
	add_theme_color_override(&"font_outline_color", ScopeTheme.SHADOW)
	add_theme_constant_override(&"outline_size", OUTLINE_PX)
	add_theme_font_size_override(&"font_size", FONT_SIZE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Hides itself the moment a panel opens or the game pauses: the scene that points
## it stops running while paused, so it cannot be relied on to clear it.
func _process(_delta: float) -> void:
	if visible and screen_held(get_tree()):
		clear()


## "[E] Calibrate": the key or button now in use and the verb ("Use" when it has none).
static func text_for(verb: String, action: StringName = &"interact") -> String:
	return "[%s] %s" % [Controls.prompt(action), verb if verb != "" else FALLBACK_VERB]


## The verb a target names: its `verb` property, or the fallback.
static func verb_of(target: Object) -> String:
	if target != null and "verb" in target:
		var named: String = str(target.get("verb"))
		if named != "":
			return named
	return FALLBACK_VERB


## True while a menu, panel or mini-game holds the screen, or the game is paused:
## no prompt then.
static func screen_held(tree: SceneTree) -> bool:
	return tree == null or tree.paused or QuestsUI.other_panel_open(tree)


## Marks `screen` (pixels, in this label's parent) with the prompt. Hidden while
## the screen is held. Returns whether it is showing.
func point_at(screen: Vector2, verb: String, action: StringName = &"interact") -> bool:
	if not is_inside_tree() or screen_held(get_tree()):
		clear()
		return false
	var pad: bool = Controls.shown_pad()
	if not _has_text or verb != _shown_verb or action != _shown_action or pad != _shown_pad:
		_shown_verb = verb
		_shown_action = action
		_shown_pad = pad
		_has_text = true
		text = text_for(verb, action)
		# The size follows the text.
		reset_size()
	visible = true
	var bounds: Vector2 = limit if limit != Vector2.ZERO else get_parent_area_size()
	var at: Vector2 = screen - Vector2(size.x * 0.5, size.y + LIFT_PX)
	if bounds != Vector2.ZERO:
		at.x = clampf(at.x, EDGE_PX, maxf(EDGE_PX, bounds.x - size.x - EDGE_PX))
		var low: float = bounds.y - floor_px - size.y - EDGE_PX
		at.y = clampf(at.y, EDGE_PX, maxf(EDGE_PX, low))
	position = at
	return true


func clear() -> void:
	visible = false
