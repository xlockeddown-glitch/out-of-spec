class_name QuestBoardMarker
extends Node3D
## In-world marker hovering over the farm notice board while the local player has
## any unseen open quest (QuestSeen, matching QuestsUI's NEW tags). Pure local UI:
## never saved to the farm and never sent over the network.
## Every number below is a [PLACEHOLDER].

## Height of the marker pivot above the notice board origin, in metres [PLACEHOLDER].
const BASE_Y_M: float = 2.9
## Vertical bob amplitude, in metres [PLACEHOLDER].
const BOB_AMPLITUDE_M: float = 0.14
## Vertical bob angular speed, in radians per second [PLACEHOLDER].
const BOB_SPEED_RAD_S: float = 3.2
## Emblem spin speed around Y, in radians per second [PLACEHOLDER].
const SPIN_RAD_S: float = 1.2
## Emblem backing slab size, in metres [PLACEHOLDER].
const BACKING_SIZE := Vector3(0.46, 0.84, 0.12)
## Exclamation stem size, in metres [PLACEHOLDER].
const STEM_SIZE := Vector3(0.22, 0.42, 0.16)
## Exclamation stem vertical offset from pivot, in metres [PLACEHOLDER].
const STEM_Y_M: float = 0.14
## Exclamation dot size, in metres [PLACEHOLDER].
const DOT_SIZE := Vector3(0.22, 0.18, 0.16)
## Exclamation dot vertical offset from pivot, in metres [PLACEHOLDER].
const DOT_Y_M: float = -0.24
## Matte roughness for the dark backing slab [PLACEHOLDER].
const BACKING_ROUGHNESS: float = 0.9
## Amber emission energy, kept low so Filmic tonemap keeps the amber hue [PLACEHOLDER].
const EMIT_ENERGY: float = 0.5
## Zero specular on emissive amber parts so scene lights do not shift the hue [PLACEHOLDER].
const EMIT_SPECULAR: float = 0.0
## Label vertical offset above the pivot, in metres [PLACEHOLDER].
const LABEL_Y_M: float = 0.66
## Label font size in pixels [PLACEHOLDER].
const LABEL_FONT_SIZE: int = 44
## Label outline size in pixels [PLACEHOLDER].
const LABEL_OUTLINE_SIZE: int = 10
## Label pixel size in metres [PLACEHOLDER].
const LABEL_PIXEL_SIZE: float = 0.008

var _pivot: Node3D
var _emblem: Node3D
var _elapsed_s: float = 0.0


func _init() -> void:
	name = &"QuestBoardMarker"


func _ready() -> void:
	_build_visual()
	GameState.quests_changed.connect(refresh)
	GameState.farm_loaded.connect(refresh)
	GameClock.day_started.connect(_on_day_started)
	QuestSeen.add_listener(refresh)
	refresh()


func _exit_tree() -> void:
	QuestSeen.remove_listener(refresh)


func _process(delta: float) -> void:
	if not visible or _pivot == null:
		return
	_elapsed_s += delta
	_pivot.position.y = BASE_Y_M + sin(_elapsed_s * BOB_SPEED_RAD_S) * BOB_AMPLITUDE_M
	if _emblem != null:
		_emblem.rotation.y = fmod(_elapsed_s * SPIN_RAD_S, TAU)


## True if any currently open quest for the local player is unseen in QuestSeen.
func has_unseen() -> bool:
	var lists: Dictionary = QuestLog.of(GameState, GameState.local_player_id)
	var open_rows: Array = lists.get(QuestLog.OPEN, [])
	return QuestSeen.has_unseen(open_rows)


## Updates marker visibility from current open quests and QuestSeen state.
func refresh() -> void:
	visible = has_unseen()


func _on_day_started(_day: int) -> void:
	refresh()


func _build_visual() -> void:
	if _pivot != null:
		return
	_pivot = Node3D.new()
	_pivot.name = &"Pivot"
	_pivot.position = Vector3(0.0, BASE_Y_M, 0.0)
	add_child(_pivot)

	_emblem = Node3D.new()
	_emblem.name = &"Emblem"
	_pivot.add_child(_emblem)

	var backing_mat := StandardMaterial3D.new()
	backing_mat.albedo_color = ScopeTheme.SHADOW
	backing_mat.roughness = BACKING_ROUGHNESS
	_emblem.add_child(_box(&"Backing", BACKING_SIZE, Vector3.ZERO, backing_mat))

	var amber_mat := StandardMaterial3D.new()
	amber_mat.albedo_color = ScopeTheme.AMBER
	amber_mat.emission_enabled = true
	amber_mat.emission = ScopeTheme.AMBER
	amber_mat.emission_energy_multiplier = EMIT_ENERGY
	amber_mat.metallic_specular = EMIT_SPECULAR
	_emblem.add_child(_box(&"Stem", STEM_SIZE, Vector3(0.0, STEM_Y_M, 0.0), amber_mat))
	_emblem.add_child(_box(&"Dot", DOT_SIZE, Vector3(0.0, DOT_Y_M, 0.0), amber_mat))

	var label := Label3D.new()
	label.name = &"NewLabel"
	label.text = QuestsUI.NEW_TAG
	label.position = Vector3(0.0, LABEL_Y_M, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = LABEL_FONT_SIZE
	label.outline_size = LABEL_OUTLINE_SIZE
	label.pixel_size = LABEL_PIXEL_SIZE
	label.modulate = ScopeTheme.AMBER
	label.outline_modulate = ScopeTheme.SHADOW
	_pivot.add_child(label)


static func _box(part_name: StringName, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	return node
