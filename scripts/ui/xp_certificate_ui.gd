class_name XpCertificateUI
extends Control
## The XP certificate picker (docs/design/quests_levels_story.md section 4.4):
## the certificates the player holds and, for the one picked, each skill of their
## own with the level it is at and the level the certificate would take it to.
## A click on a skill asks "Spend on <Skill>?", and a second click on that row
## spends it; Esc or BACK takes the question back. The skills view (K) opens it;
## it has no key of its own.

const TEAL: Color = ScopeTheme.TEAL
const TEXT: Color = ScopeTheme.INK
const DIM: Color = ScopeTheme.INK_MUTED

var _rows: VBoxContainer
var _note: Label
var _close_button: Button
var _glyph: Label
## The certificate whose skills are listed; "" picks the first held.
var _picked: String = ""
## The skill the player has clicked once and not yet confirmed, or "".
var _asked: String = ""
## Certificates this screen has spent that the farm's copy here may still list:
## a guest's copy is the host's, and it comes a moment after the host's answer.
## One is forgotten once the farm no longer lists it, and all are when another
## farm is loaded or joined, where the same id may be a certificate still held.
var _spent: Array[String] = []
## A spend has been asked of the host and its answer has not come.
var _waiting: bool = false


## What the picker lists for one of `player_id`'s certificates ("" = the local
## player): a row for each skill of their own, in the skills' order. A row:
## skill, name, level, level_after, xp, and problem ("" if it can be spent
## there). No rows if the certificate is not held.
static func choices(farm: Node, certificate_id: String, player_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var held: Dictionary = farm.held_xp_certificates(player_id)
	if not held.has(certificate_id):
		return out
	var xp: int = int(held[certificate_id])
	for skill: String in farm.skill_ids():
		if farm.is_farm_skill(skill):
			continue
		out.append({
			"skill": skill,
			"name": str(DataManager.get_record(&"skills", skill, "skills").get("display_name", skill)),
			"level": farm.skill_level(skill, player_id),
			"level_after": farm.level_with_xp(skill, xp, player_id),
			"xp": xp,
			"problem": farm.xp_certificate_problem(certificate_id, skill, player_id),
		})
	return out


## "The Thirsty Probe (200 XP)": a certificate by the quest that gave it.
static func certificate_text(certificate_id: String, xp: int) -> String:
	var source: String = GameState.xp_certificate_source(certificate_id)
	var title: String = str(DataManager.get_record(QuestEngine.TABLE, source, QuestEngine.SECTION).get("title", source))
	return "%s (%s XP)" % [title, SP811.integer(xp)]


## "Spend on Calibration?  CONFIRM": the row the player has clicked once.
static func confirm_text(row: Dictionary) -> String:
	return "Spend on %s?  CONFIRM" % row["name"]


## "Calibration: level 1, to level 4" for one row of choices().
static func choice_text(row: Dictionary) -> String:
	if row["problem"] != "":
		return "%s: level %s, top level" % [row["name"], SP811.integer(int(row["level"]))]
	return "%s: level %s, to level %s" % [row["name"], SP811.integer(int(row["level"])), SP811.integer(int(row["level_after"]))]


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
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	var header := PanelContainer.new()
	header.theme_type_variation = ScopeTheme.HEADER
	var title := Label.new()
	title.text = "XP CERTIFICATES"
	title.theme_type_variation = ScopeTheme.TITLE
	title.add_theme_font_size_override(&"font_size", 30)
	header.add_child(title)
	column.add_child(header)
	var glass := PanelContainer.new()
	glass.theme_type_variation = ScopeTheme.GLASS
	column.add_child(glass)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", 8)
	glass.add_child(inner)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	inner.add_child(_rows)
	_note = ScopeTheme.label("", DIM, 16)
	inner.add_child(_note)
	_close_button = ScopeTheme.button("BACK  (%s)" % Controls.key_label(&"ui_cancel"), 20)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(step_back)
	_glyph = ScopeTheme.badge(&"ui_cancel")
	_close_button.add_child(_glyph)
	column.add_child(_close_button)
	GameState.xp_certificates_changed.connect(_on_changed)
	# A save loaded, or a host joined: another farm, and nothing of it spent here.
	GameState.farm_loaded.connect(_on_farm_loaded)
	hide()


func _process(_delta: float) -> void:
	if visible:
		ScopeTheme.refresh_badge(_glyph)


func open() -> void:
	_picked = ""
	_asked = ""
	_note.text = ""
	_refresh()
	show()
	_close_button.grab_focus()


## Esc and BACK: takes back a spend that waits for its second click, else
## closes the picker.
func step_back() -> void:
	if _asked != "":
		_asked = ""
		_note.text = ""
		_refresh()
		_close_button.grab_focus()
	else:
		hide()


## The local player's certificates that can still be spent here: id -> XP.
func spendable() -> Dictionary:
	var out: Dictionary = GameState.held_xp_certificates()
	# Only what the farm still lists needs hiding.
	for id: String in _spent.duplicate():
		if out.has(id):
			out.erase(id)
		else:
			_spent.erase(id)
	return out


## Bound to this node (not to the array), so it lets go when the picker is freed.
func _on_farm_loaded() -> void:
	_spent.clear()


func _on_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	# The row that has focus is about to be freed: remember which it is.
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var was: String = str(focused.get_meta(&"row", "")) if focused != null and focused.get_parent() == _rows else ""
	_build_rows()
	if was == "" or not visible:
		return
	# Focus goes to the same row if it is still there, else to BACK.
	for child: Node in _rows.get_children():
		if child is Button and str(child.get_meta(&"row", "")) == was and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
	_close_button.grab_focus()


func _build_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var held: Dictionary = spendable()
	if held.is_empty():
		_asked = ""
		_rows.add_child(ScopeTheme.label("You hold no XP certificate.", TEXT, 20))
		return
	if not held.has(_picked):
		_picked = str(held.keys()[0])
		_asked = ""
	# More than one held: pick which to spend.
	if held.size() > 1:
		for id: String in held:
			var pick: Button = ScopeTheme.button(("> " if id == _picked else "") + certificate_text(id, int(held[id])), 20)
			pick.set_meta(&"row", "certificate " + id)
			pick.pressed.connect(_pick.bind(id))
			_rows.add_child(pick)
	_rows.add_child(ScopeTheme.label("Spend %s on one skill:" % certificate_text(_picked, int(held[_picked])), TEXT, 20))
	for row: Dictionary in choices(GameState, _picked):
		var skill: String = str(row["skill"])
		var asked: bool = skill == _asked and row["problem"] == ""
		var spend: Button = ScopeTheme.button(confirm_text(row) if asked else choice_text(row), 20)
		spend.disabled = row["problem"] != ""
		spend.set_meta(&"row", "skill " + skill)
		if asked:
			spend.pressed.connect(_spend.bind(_picked, skill))
		else:
			spend.pressed.connect(_ask.bind(skill))
		_rows.add_child(spend)
		if asked and visible:
			spend.grab_focus()


func _pick(certificate_id: String) -> void:
	_picked = certificate_id
	_asked = ""
	_note.text = ""
	_refresh()


## The first click on a skill: nothing is spent until the second.
func _ask(skill_id: String) -> void:
	_asked = skill_id
	_note.text = "Click again to spend it there. A spent certificate can't be taken back."
	_refresh()


func _spend(certificate_id: String, skill_id: String) -> void:
	if _waiting:
		return
	_waiting = true
	_asked = ""
	var problem: Variant = await FarmCommands.request(&"spend_xp_certificate", [certificate_id, skill_id])
	_waiting = false
	if str(problem) == "":
		# Out of the list now, not when the host's farm next arrives.
		if not certificate_id in _spent:
			_spent.append(certificate_id)
		_note.text = "Spent."
	else:
		_note.text = str(problem)
	_refresh()
	_close_button.grab_focus()
