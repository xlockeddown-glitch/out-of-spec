class_name KeepsakeShelf
extends Node3D
## A shelf in the dome with one small object for each keepsake the local player
## holds (docs/design/quests_levels_story.md section 9, item 10). Click one to
## read its text. [PLACEHOLDER] The objects are a small box or cylinder in the
## existing greybox look until a voxel model is dropped in assets/voxels/.
## A guest sees the keepsakes of their own quests, as the QUESTS page does.

signal inspected(text: String)

const SPACING: float = 0.3
## The plank holds this many objects; the rest are a "+N" note.
const MAX_SHOWN: int = 5
const PLANK_SIZE: Vector3 = Vector3(1.6, 0.05, 0.3)
const ITEM_SIZE: Vector3 = Vector3(0.2, 0.14, 0.14)
## Placeholder shapes by keepsake: "cylinder" for the watch, a box otherwise.
const CYLINDER_IDS: Array[String] = ["pocket_watch"]

var _shown: Array[String] = []


func _ready() -> void:
	_add_plank()
	GameState.quests_changed.connect(refresh)
	GameState.farm_loaded.connect(refresh)
	refresh()


## Rebuilds the objects when the keepsakes held are not the ones shown.
func refresh() -> void:
	var held: Array[String] = QuestEngine.keepsakes_of(GameState, GameState.local_player_id)
	if held == _shown:
		return
	_shown = held
	_clear_items()
	var visible_count: int = mini(held.size(), MAX_SHOWN)
	var x: float = -SPACING * (visible_count - 1) / 2.0
	for i: int in visible_count:
		_add_item(held[i], x)
		x += SPACING
	if held.size() > MAX_SHOWN:
		_add_more_note(held.size() - MAX_SHOWN)


## How many are held but not on the plank (0 when they all fit).
func hidden_count() -> int:
	return maxi(_shown.size() - MAX_SHOWN, 0)


## Takes the objects off the plank. Hover is a static: drop it before its
## Clickable goes, so nothing reads a freed one.
func _clear_items() -> void:
	if Clickable.hovered != null and (not is_instance_valid(Clickable.hovered) or is_ancestor_of(Clickable.hovered)):
		Clickable.hovered = null
	for child: Node in get_children():
		if child.is_in_group(&"keepsake_item"):
			remove_child(child)
			child.queue_free()


func shown_ids() -> Array[String]:
	return _shown


func _add_plank() -> void:
	var plank := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PLANK_SIZE
	plank.mesh = box
	plank.position = Vector3(0, -ITEM_SIZE.y / 2.0 - PLANK_SIZE.y / 2.0, 0)
	add_child(plank)


func _add_item(id: String, x: float) -> void:
	var item := Node3D.new()
	item.name = "Keepsake_" + id
	item.position = Vector3(x, 0, 0)
	item.add_to_group(&"keepsake_item")
	var mesh := MeshInstance3D.new()
	if id in CYLINDER_IDS:
		var cyl := CylinderMesh.new()
		cyl.top_radius = ITEM_SIZE.y / 2.0
		cyl.bottom_radius = ITEM_SIZE.y / 2.0
		cyl.height = 0.04
		mesh.mesh = cyl
		mesh.rotation = Vector3(PI / 2.0, 0, 0)
	else:
		var box := BoxMesh.new()
		box.size = ITEM_SIZE
		mesh.mesh = box
	item.add_child(mesh)
	var click := Clickable.new()
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = QuestEngine.keepsake_name(id)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = ITEM_SIZE
	shape.shape = hit
	click.add_child(shape)
	click.clicked.connect(func() -> void: inspected.emit(_text_of(id)))
	item.add_child(click)
	add_child(item)


func _add_more_note(extra: int) -> void:
	var note := Label3D.new()
	note.name = "More"
	note.text = "+%d" % extra
	note.pixel_size = 0.004
	note.font_size = 48
	note.position = Vector3(PLANK_SIZE.x / 2.0 + 0.1, 0, 0)
	note.add_to_group(&"keepsake_item")
	add_child(note)


static func _text_of(id: String) -> String:
	var text: String = QuestEngine.keepsake_text(id)
	var title: String = QuestEngine.keepsake_name(id)
	return title if text == "" else "%s: %s" % [title, text]
