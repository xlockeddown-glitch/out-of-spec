class_name CertificateWall
extends Node3D
## A wall display in the dome where the farm's earned certificates hang once the
## lab reaches the `certificate_wall` lab gate (level 8, data/skills.json).
##
## What earns a certificate [PLACEHOLDER]:
##   - Each clean passed audit in `audit_log` (`passed` true, not `warning`).
##   - Each completed farm-wide `lab` quest in `quest_state` (excluding quests
##     closed with nothing paid via `QuestLog.is_closed`).
## Personal quests are excluded (they have keepsakes on KeepsakeShelf).
##
## Read-only: no new save fields, commands, or protocol changes. Guests see the
## same wall from the synced `audit_log`, `quest_state`, and `lab_xp`.
## Click or hover a frame to read its name and the day it was earned.

signal inspected(text: String)

const GATE_ID: String = "certificate_wall"
const HALFWAY_GATE_ID: String = Cosmetics.GATE_HALFWAY_PLAQUE
const HALFWAY_TITLE: String = "HALFWAY THERE"
const HALFWAY_HINT: String = "HALFWAY THERE — Lab level 92"
## [PLACEHOLDER] Grid dimensions and cap: 4 columns by 3 rows (12 frames).
const COLS: int = 4
const ROWS: int = 3
const MAX_SHOWN: int = COLS * ROWS

## [PLACEHOLDER] Primitive mesh dimensions (meters).
const BOARD_SIZE: Vector3 = Vector3(1.80, 1.15, 0.04)
const PLAQUE_SIZE: Vector3 = Vector3(0.95, 0.26, 0.04)
const HALFWAY_PLAQUE_SIZE: Vector3 = Vector3(0.88, 0.20, 0.035)
const FRAME_SIZE: Vector3 = Vector3(0.32, 0.24, 0.03)
const PAPER_SIZE: Vector3 = Vector3(0.26, 0.18, 0.02)
const SEAL_SIZE: Vector3 = Vector3(0.05, 0.05, 0.015)
const COL_STEP: float = 0.40
const ROW_STEP: float = 0.32

const GROUP_BOARD: StringName = &"certificate_board"
const GROUP_PLAQUE: StringName = &"certificate_plaque"
const GROUP_ITEM: StringName = &"certificate_item"

## Optional injected farm state for tests; defaults to the GameState autoload.
var _farm: Node = null
var _built_once: bool = false
var _was_unlocked: bool = false
var _was_halfway: bool = false
var _shown: Array[Dictionary] = []
var _total_earned: int = 0

var _mat_board: StandardMaterial3D
var _mat_plaque: StandardMaterial3D
var _mat_halfway: StandardMaterial3D
var _mat_frame: StandardMaterial3D
var _mat_gold_frame: StandardMaterial3D
var _mat_paper: StandardMaterial3D
var _mat_audit_seal: StandardMaterial3D
var _mat_quest_seal: StandardMaterial3D


func _ready() -> void:
	_ensure_materials()
	var farm: Node = _state()
	farm.quests_changed.connect(refresh)
	farm.farm_loaded.connect(refresh)
	farm.lab_xp_changed.connect(refresh)
	farm.audit_completed.connect(_on_audit_completed)
	refresh()


func set_farm(farm: Node) -> void:
	_farm = farm


func _state() -> Node:
	return _farm if _farm != null else GameState


func _on_audit_completed(_report: Dictionary) -> void:
	refresh()


## True when the farm has opened the `certificate_wall` lab gate.
func is_unlocked() -> bool:
	return _state().lab_gate_open(GATE_ID)


## All earned certificates on `farm`, ordered oldest first (newest last).
## Each entry has `id`, `kind` ("audit" or "lab_quest"), `title`, and `day`.
static func earned_from(farm: Node) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var audits: Array = farm.audit_log
	for i: int in audits.size():
		var report: Variant = audits[i]
		if not (report is Dictionary):
			continue
		var r: Dictionary = report as Dictionary
		var passed: Variant = r.get("passed")
		var warning: Variant = r.get("warning")
		if passed is bool and passed and not (warning is bool and warning):
			var day: int = int(r.get("day", 0))
			entries.append({
				"id": "audit_%d_%d" % [day, i],
				"kind": "audit",
				"title": "Clean Audit",
				"day": day,
				"gold_border": bool(r.get("gold_border", false)),
				"_order": 0,
				"_index": i,
			})
	var all_quests: Array[Dictionary] = QuestEngine.quests()
	var q_state: Dictionary = farm.quest_state
	for i: int in all_quests.size():
		var quest: Dictionary = all_quests[i]
		if str(quest.get("kind", "")) != "lab":
			continue
		if str(quest.get("scope", QuestEngine.SCOPE_FARM)) != QuestEngine.SCOPE_FARM:
			continue
		if QuestEngine.data_problem(quest) != "":
			continue
		var qid: String = str(quest.get("id", ""))
		var raw_entry: Variant = q_state.get(qid)
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var done_day: int = int(entry.get("done", -1))
		if done_day < 0 or not (entry.get("steps_done") is Array) or QuestLog.is_closed(quest, entry):
			continue
		entries.append({
			"id": "quest_" + qid,
			"kind": "lab_quest",
			"title": str(quest.get("title", qid)),
			"day": done_day,
			"gold_border": bool(entry.get("gold_border", false)),
			"_order": 1,
			"_index": i,
		})
	entries.sort_custom(_sort_oldest_first)
	var out: Array[Dictionary] = []
	for item: Dictionary in entries:
		var row_out: Dictionary = {
			"id": str(item["id"]),
			"kind": str(item["kind"]),
			"title": str(item["title"]),
			"day": int(item["day"]),
		}
		if bool(item.get("gold_border", false)):
			row_out["gold_border"] = true
		out.append(row_out)
	return out


static func _sort_oldest_first(a: Dictionary, b: Dictionary) -> bool:
	var day_a: int = int(a["day"])
	var day_b: int = int(b["day"])
	if day_a != day_b:
		return day_a < day_b
	var order_a: int = int(a["_order"])
	var order_b: int = int(b["_order"])
	if order_a != order_b:
		return order_a < order_b
	return int(a["_index"]) < int(b["_index"])


## Hover and click text for the bare plaque below lab level 8 [PLACEHOLDER].
static func locked_text(farm: Node) -> String:
	return "Certificate wall: lab level %s" % SP811.integer(farm.lab_gate_level(GATE_ID))


## Hover and click text for one certificate frame [PLACEHOLDER].
static func certificate_text(cert: Dictionary, extra: int = 0) -> String:
	var base: String = "%s (Day %s)" % [str(cert.get("title", "")), SP811.integer(int(cert.get("day", 0)))]
	if extra > 0:
		return "%s (+%s more)" % [base, SP811.integer(extra)]
	return base


## Rebuilds the wall when unlock status or the earned certificates change.
func refresh() -> void:
	_ensure_materials()
	var farm: Node = _state()
	var unlocked: bool = farm.lab_gate_open(GATE_ID)
	var halfway: bool = unlocked and farm.lab_gate_open(HALFWAY_GATE_ID)
	var earned: Array[Dictionary] = []
	if unlocked:
		earned = earned_from(farm)
	var extra: int = maxi(earned.size() - MAX_SHOWN, 0)
	var visible_certs: Array[Dictionary] = []
	if extra > 0:
		visible_certs.assign(earned.slice(extra))
	else:
		visible_certs = earned
	if _built_once and unlocked == _was_unlocked and halfway == _was_halfway and _total_earned == earned.size() and visible_certs == _shown:
		return
	_built_once = true
	_was_unlocked = unlocked
	_was_halfway = halfway
	_total_earned = earned.size()
	_shown = visible_certs
	_clear_wall()
	if not unlocked:
		_add_stand(-PLAQUE_SIZE.y / 2.0, PLAQUE_SIZE.x / 2.0 - 0.14, GROUP_PLAQUE)
		_add_plaque(locked_text(farm), "CERTIFICATE WALL")
		return
	_add_board()
	if halfway:
		_add_halfway_plaque()
	if visible_certs.is_empty():
		_add_plaque("Certificate wall: no certificates yet", "CERTIFICATES")
		return
	for i: int in visible_certs.size():
		var col: int = i % COLS
		var row: int = i / COLS
		var x: float = (float(col) - float(COLS - 1) / 2.0) * COL_STEP
		var y: float = (float(ROWS - 1) / 2.0 - float(row)) * ROW_STEP
		_add_certificate(visible_certs[i], Vector3(x, y, BOARD_SIZE.z / 2.0 + FRAME_SIZE.z / 2.0), extra)
	if extra > 0:
		_add_more_note(extra)


## The certificates currently shown on the wall (newest last).
func shown_certificates() -> Array[Dictionary]:
	return _shown


## How many earned certificates do not fit on the wall (0 when all fit or locked).
func hidden_count() -> int:
	return maxi(_total_earned - MAX_SHOWN, 0)


## Clears dynamic wall nodes. Drops any gamepad selection or mouse hover on our
## children through set_hover(false) so the cursor resets before freeing them.
func _clear_wall() -> void:
	var pad_pointer: DomePadPointer = _find_pad_pointer()
	if pad_pointer != null and pad_pointer.selected != null \
			and (not is_instance_valid(pad_pointer.selected) or is_ancestor_of(pad_pointer.selected)):
		pad_pointer.clear_selection()
	if Clickable.hovered != null:
		if not is_instance_valid(Clickable.hovered):
			Clickable.hovered = null
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		elif is_ancestor_of(Clickable.hovered):
			Clickable.hovered.set_hover(false)
	for child: Node in get_children():
		if child.is_in_group(GROUP_ITEM) or child.is_in_group(GROUP_PLAQUE) or child.is_in_group(GROUP_BOARD):
			remove_child(child)
			child.queue_free()


func _find_pad_pointer() -> DomePadPointer:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var named: DomePadPointer = parent.get_node_or_null("DomePadPointer") as DomePadPointer
	if named != null:
		return named
	for sibling: Node in parent.get_children():
		if sibling is DomePadPointer:
			return sibling as DomePadPointer
	return null


func _ensure_materials() -> void:
	if _mat_board != null:
		return
	_mat_board = _make_material(ScopeTheme.SHADOW, 0.85)
	_mat_plaque = _make_material(ScopeTheme.ENAMEL_INSET, 0.65)
	_mat_halfway = _make_material(ScopeTheme.AMBER, 0.45)
	_mat_frame = _make_material(ScopeTheme.TERRA_DARK, 0.75)
	_mat_gold_frame = _make_material(ScopeTheme.GOLD, 0.35)
	_mat_paper = _make_material(ScopeTheme.ENAMEL_TOP, 0.9)
	_mat_audit_seal = _make_material(ScopeTheme.TEAL, 0.5)
	_mat_quest_seal = _make_material(ScopeTheme.AMBER, 0.5)


static func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add_board() -> void:
	var board := MeshInstance3D.new()
	board.name = "Board"
	var box := BoxMesh.new()
	box.size = BOARD_SIZE
	board.mesh = box
	board.material_override = _mat_board
	board.add_to_group(GROUP_BOARD)
	add_child(board)
	_add_stand(-BOARD_SIZE.y / 2.0, BOARD_SIZE.x / 2.0 - 0.14, GROUP_BOARD)


## Two slim support posts from `top_y` down to the dome floor (world Y = 0).
func _add_stand(top_y: float, half_span_x: float, group: StringName) -> void:
	var post_h: float = maxf(position.y + top_y, 0.2)
	var post_box := BoxMesh.new()
	post_box.size = Vector3(0.06, post_h, 0.06)
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = post_box
		post.material_override = _mat_board
		post.position = Vector3(side * half_span_x, top_y - post_h / 2.0, 0.0)
		post.add_to_group(group)
		add_child(post)


func _add_plaque(text: String, heading: String) -> void:
	var plaque := Node3D.new()
	plaque.name = "Plaque"
	plaque.position = Vector3(0, 0, BOARD_SIZE.z / 2.0 + PLAQUE_SIZE.z / 2.0)
	plaque.add_to_group(GROUP_PLAQUE)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PLAQUE_SIZE
	mesh.mesh = box
	mesh.material_override = _mat_plaque
	plaque.add_child(mesh)
	var label := Label3D.new()
	label.text = heading
	label.pixel_size = 0.003
	label.font_size = 28
	label.modulate = ScopeTheme.CARD_INK
	label.position = Vector3(0, 0, PLAQUE_SIZE.z / 2.0 + 0.005)
	plaque.add_child(label)
	var click := Clickable.new()
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = text
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = PLAQUE_SIZE
	shape.shape = hit
	click.add_child(shape)
	click.clicked.connect(func() -> void: inspected.emit(text))
	plaque.add_child(click)
	add_child(plaque)


func _add_certificate(cert: Dictionary, at: Vector3, extra: int) -> void:
	var item := Node3D.new()
	item.name = "Certificate_" + str(cert["id"])
	item.position = at
	item.add_to_group(GROUP_ITEM)

	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var frame_box := BoxMesh.new()
	frame_box.size = FRAME_SIZE
	frame.mesh = frame_box
	frame.material_override = _mat_gold_frame if bool(cert.get("gold_border", false)) else _mat_frame
	item.add_child(frame)

	var paper := MeshInstance3D.new()
	var paper_box := BoxMesh.new()
	paper_box.size = PAPER_SIZE
	paper.mesh = paper_box
	paper.material_override = _mat_paper
	paper.position = Vector3(0, 0, FRAME_SIZE.z / 2.0 - PAPER_SIZE.z / 2.0 + 0.004)
	item.add_child(paper)

	var seal := MeshInstance3D.new()
	var seal_box := BoxMesh.new()
	seal_box.size = SEAL_SIZE
	seal.mesh = seal_box
	seal.material_override = _mat_audit_seal if str(cert.get("kind", "")) == "audit" else _mat_quest_seal
	seal.position = Vector3(PAPER_SIZE.x * 0.28, -PAPER_SIZE.y * 0.24, FRAME_SIZE.z / 2.0 + 0.008)
	item.add_child(seal)

	var text: String = certificate_text(cert, extra)
	var click := Clickable.new()
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = text
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = FRAME_SIZE
	shape.shape = hit
	click.add_child(shape)
	click.clicked.connect(func() -> void: inspected.emit(text))
	item.add_child(click)
	add_child(item)


func _add_more_note(extra: int) -> void:
	var note := Label3D.new()
	note.name = "More"
	note.text = "+%s more" % SP811.integer(extra)
	note.pixel_size = 0.003
	note.font_size = 32
	note.modulate = ScopeTheme.INK_MUTED
	note.position = Vector3(BOARD_SIZE.x / 2.0 - 0.22, -BOARD_SIZE.y / 2.0 - 0.08, BOARD_SIZE.z / 2.0 + 0.01)
	note.add_to_group(GROUP_ITEM)
	add_child(note)


## The lab-92 "HALFWAY THERE" plaque mounted above the board.
func _add_halfway_plaque() -> void:
	var plaque := Node3D.new()
	plaque.name = "HalfwayPlaque"
	plaque.position = Vector3(0.0, BOARD_SIZE.y / 2.0 + HALFWAY_PLAQUE_SIZE.y / 2.0 + 0.04, BOARD_SIZE.z / 2.0 + HALFWAY_PLAQUE_SIZE.z / 2.0)
	plaque.add_to_group(GROUP_PLAQUE)
	var mesh := MeshInstance3D.new()
	mesh.name = "Backing"
	var box := BoxMesh.new()
	box.size = HALFWAY_PLAQUE_SIZE
	mesh.mesh = box
	mesh.material_override = _mat_halfway
	plaque.add_child(mesh)
	var label := Label3D.new()
	label.name = "Label"
	label.text = HALFWAY_TITLE
	label.pixel_size = 0.003
	label.font_size = 28
	label.modulate = ScopeTheme.CARD_INK
	label.position = Vector3(0.0, 0.0, HALFWAY_PLAQUE_SIZE.z / 2.0 + 0.005)
	plaque.add_child(label)
	var click := Clickable.new()
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = HALFWAY_HINT
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = HALFWAY_PLAQUE_SIZE
	shape.shape = hit
	click.add_child(shape)
	click.clicked.connect(func() -> void: inspected.emit(HALFWAY_HINT))
	plaque.add_child(click)
	add_child(plaque)
