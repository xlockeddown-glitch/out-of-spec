class_name XpCertificateUI
extends Control
## The XP certificate picker (docs/design/quests_levels_story.md section 4.4):
## the certificates the player holds and, for the one picked, each skill of their
## own with the level it is at and the level the certificate would take it to.
## One click spends it. The skills view (K) opens it; it has no key of its own.

const TEAL: Color = Color("38E1C6")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const DIM: Color = Color(0.6, 0.68, 0.63)

var _rows: VBoxContainer
var _note: Label
var _close_button: Button
## The certificate whose skills are listed; "" picks the first held.
var _picked: String = ""


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
	var source: String = certificate_id.get_slice("#", 0)
	var title: String = str(DataManager.get_record(QuestEngine.TABLE, source, QuestEngine.SECTION).get("title", source))
	return "%s (%s XP)" % [title, SP811.integer(xp)]


## "Calibration: level 1, to level 4" for one row of choices().
static func choice_text(row: Dictionary) -> String:
	if row["problem"] != "":
		return "%s: level %s, top level" % [row["name"], SP811.integer(int(row["level"]))]
	return "%s: level %s, to level %s" % [row["name"], SP811.integer(int(row["level"])), SP811.integer(int(row["level_after"]))]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label("XP CERTIFICATES", TEAL, 30))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	column.add_child(_rows)
	_note = PlanBoardUI._label("", DIM, 16)
	column.add_child(_note)
	_close_button = PlanBoardUI._button("BACK  (Esc)")
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	column.add_child(_close_button)
	GameState.xp_certificates_changed.connect(_on_changed)
	hide()


func open() -> void:
	_picked = ""
	_note.text = ""
	_refresh()
	show()
	_close_button.grab_focus()


func _on_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var held: Dictionary = GameState.held_xp_certificates()
	if held.is_empty():
		_rows.add_child(PlanBoardUI._label("You hold no XP certificate.", TEXT, 20))
		return
	if not held.has(_picked):
		_picked = str(held.keys()[0])
	# More than one held: pick which to spend.
	if held.size() > 1:
		for id: String in held:
			var pick: Button = PlanBoardUI._button(("> " if id == _picked else "") + certificate_text(id, int(held[id])))
			pick.pressed.connect(_pick.bind(id))
			_rows.add_child(pick)
	_rows.add_child(PlanBoardUI._label("Spend %s on one skill:" % certificate_text(_picked, int(held[_picked])), TEXT, 20))
	for row: Dictionary in choices(GameState, _picked):
		var spend: Button = PlanBoardUI._button(choice_text(row))
		spend.disabled = row["problem"] != ""
		spend.pressed.connect(_spend.bind(_picked, str(row["skill"])))
		_rows.add_child(spend)


func _pick(certificate_id: String) -> void:
	_picked = certificate_id
	_refresh()


func _spend(certificate_id: String, skill_id: String) -> void:
	var problem: Variant = await FarmCommands.request(&"spend_xp_certificate", [certificate_id, skill_id])
	_note.text = str(problem)
	_refresh()
	_close_button.grab_focus()
