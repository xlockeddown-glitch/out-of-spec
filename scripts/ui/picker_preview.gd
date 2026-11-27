class_name PickerPreview
extends VBoxContainer
## Live 3D turntable and combined drive-stat readout for PickerUI. Shows the
## local player's WalkerModel and tractor with the currently selected Loadout
## parts, updating immediately as slots cycle. Pure local UI; every number and
## word here is a [PLACEHOLDER].

const PREVIEW_CAPTION: String = "PREVIEW"
const STATS_CAPTION: String = "DRIVE SUMMARY"
const BASE_TEXT: String = "Base"
const TRACTOR_PATH: String = "res://assets/voxels/tractor.glb"
const WIDE_TRACTOR_PATH: String = "res://assets/voxels/tractor_wide.glb"
const STAT_TITLES: Dictionary[StringName, String] = {
	&"speed": "Top speed",
	&"accel": "Acceleration",
	&"brake": "Braking",
	&"turn": "Turning",
	&"wade": "Wading",
}

## Preview column width, in pixels [PLACEHOLDER].
const COLUMN_WIDTH: float = 360.0
## Vertical separation between preview cards, in pixels [PLACEHOLDER].
const CARD_SEPARATION: int = 10
## SubViewport size, in pixels [PLACEHOLDER].
const VIEWPORT_SIZE := Vector2i(328, 280)
## Turntable rotation speed, in radians per second [PLACEHOLDER].
const SPIN_RAD_S: float = 0.55
## Initial turntable yaw so both character and tractor face 3/4 toward the camera [PLACEHOLDER].
const START_YAW_RAD: float = 0.55
## Camera position in studio space, in metres [PLACEHOLDER].
const CAMERA_POSITION := Vector3(0.0, 2.6, 5.4)
## Camera look-at target in studio space, in metres [PLACEHOLDER].
const CAMERA_TARGET := Vector3(0.0, 0.85, 0.0)
## Camera vertical field of view, in degrees [PLACEHOLDER].
const CAMERA_FOV_DEG: float = 34.0
## Ambient light energy in the preview studio [PLACEHOLDER].
const AMBIENT_ENERGY: float = 0.7
## Key directional light energy [PLACEHOLDER].
const SUN_ENERGY: float = 1.15
## Key directional light rotation, in degrees [PLACEHOLDER].
const SUN_ROTATION_DEG := Vector3(-42.0, 32.0, 0.0)
## Turntable disc radius, in metres [PLACEHOLDER].
const DISC_RADIUS_M: float = 2.25
## Turntable disc height, in metres [PLACEHOLDER].
const DISC_HEIGHT_M: float = 0.08
## Turntable disc roughness [PLACEHOLDER].
const DISC_ROUGHNESS: float = 0.92
## Character position on the turntable, in metres [PLACEHOLDER].
const WALKER_POSITION := Vector3(-1.15, 0.0, 0.25)
## Tractor position on the turntable, in metres [PLACEHOLDER].
const TRACTOR_POSITION := Vector3(0.55, 0.0, -0.1)
## Tractor voxel scale (0.1 m per voxel, matching main_farm) [PLACEHOLDER].
const TRACTOR_SCALE: float = 0.1
## Caption font size, in pixels [PLACEHOLDER].
const CAPTION_FONT_SIZE: int = 15
## Stat row font size, in pixels [PLACEHOLDER].
const STAT_FONT_SIZE: int = 16
## Stat row vertical separation, in pixels [PLACEHOLDER].
const STAT_SEPARATION: int = 4
## Multiplier-to-percent conversion factor [PLACEHOLDER].
const PERCENT_SCALE: float = 100.0
## Multiplier delta tolerance for treating a stat as baseline [PLACEHOLDER].
const BASE_EPSILON: float = 0.005

var _stage: Node3D
var _turntable: Node3D
var _walker: WalkerModel
var _tractor_slot: ModelSlot
var _tractor_root: Node3D
var _tractor_look: Node3D
var _stat_values: Dictionary[StringName, Label] = {}
var _parts: Dictionary = {}


func _init() -> void:
	name = &"PickerPreview"


func _ready() -> void:
	custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	add_theme_constant_override(&"separation", CARD_SEPARATION)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_viewport_card()
	_build_stats_card()
	show_loadout(Loadout.default_parts())


func _process(delta: float) -> void:
	if is_visible_in_tree() and _turntable != null:
		_turntable.rotation.y = fmod(_turntable.rotation.y + delta * SPIN_RAD_S, TAU)


## Updates the 3D character, 3D tractor, and combined drive-stat summary for `parts`.
func show_loadout(parts: Dictionary) -> void:
	var cleaned: Dictionary = Loadout.clean(parts)
	_parts = cleaned
	if _walker != null:
		_walker.set_suit(WalkerModel.suit_for(GameState.local_player_id, CoopSession.players))
		_walker.set_loadout(cleaned)
	_refresh_tractor_base()
	_set_tractor_look(cleaned)
	_refresh_stats(cleaned)


## The live WalkerModel inside the preview turntable.
func walker_model() -> WalkerModel:
	return _walker


## Number of Loadout look meshes currently mounted on the preview tractor.
func tractor_look_count() -> int:
	return _tractor_look.get_child_count() if _tractor_look != null else 0


## Current formatted text for a drive stat key (Loadout.DRIVE_KEYS).
func stat_text(key: StringName) -> String:
	var label: Label = _stat_values.get(key)
	return label.text if label != null else ""


## Current colour override for a drive stat key (Loadout.DRIVE_KEYS).
func stat_color(key: StringName) -> Color:
	var label: Label = _stat_values.get(key)
	return label.get_theme_color(&"font_color") if label != null else ScopeTheme.INK_MUTED


func _build_viewport_card() -> void:
	var glass := PanelContainer.new()
	glass.name = &"PreviewGlass"
	glass.theme_type_variation = ScopeTheme.GLASS
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", STAT_SEPARATION)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.add_child(box)

	var caption: Label = PlanBoardUI._label(PREVIEW_CAPTION, ScopeTheme.INK_MUTED, CAPTION_FONT_SIZE)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)

	var holder := SubViewportContainer.new()
	holder.name = &"ViewportHolder"
	holder.stretch = true
	holder.custom_minimum_size = Vector2(VIEWPORT_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)

	var viewport := SubViewport.new()
	viewport.name = &"PreviewViewport"
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(viewport)

	_stage = Node3D.new()
	_stage.name = &"Stage"
	viewport.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ScopeTheme.SHADOW
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ScopeTheme.ENAMEL_TOP
	env.ambient_light_energy = AMBIENT_ENERGY
	var world_env := WorldEnvironment.new()
	world_env.name = &"StudioEnv"
	world_env.environment = env
	_stage.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = &"StudioSun"
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.light_energy = SUN_ENERGY
	_stage.add_child(sun)

	var camera := Camera3D.new()
	camera.name = &"StudioCamera"
	camera.fov = CAMERA_FOV_DEG
	camera.position = CAMERA_POSITION
	_stage.add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)

	_turntable = Node3D.new()
	_turntable.name = &"Turntable"
	_turntable.rotation.y = START_YAW_RAD
	_stage.add_child(_turntable)

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = DISC_RADIUS_M
	disc_mesh.bottom_radius = DISC_RADIUS_M
	disc_mesh.height = DISC_HEIGHT_M
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = ScopeTheme.GLASS_LINE
	disc_mat.roughness = DISC_ROUGHNESS
	disc_mesh.material = disc_mat
	var disc := MeshInstance3D.new()
	disc.name = &"Plinth"
	disc.mesh = disc_mesh
	disc.position = Vector3(0.0, -DISC_HEIGHT_M * 0.5, 0.0)
	_turntable.add_child(disc)

	_walker = WalkerModel.new()
	_walker.name = &"PreviewWalker"
	_walker.position = WALKER_POSITION
	_turntable.add_child(_walker)

	_tractor_root = Node3D.new()
	_tractor_root.name = &"PreviewTractor"
	_tractor_root.position = TRACTOR_POSITION
	_turntable.add_child(_tractor_root)

	_tractor_slot = ModelSlot.new()
	_tractor_slot.name = &"TractorModel"
	_tractor_slot.model_scale = TRACTOR_SCALE
	_tractor_slot.model_path = WIDE_TRACTOR_PATH if GameState.has_wide_treads else TRACTOR_PATH
	_tractor_root.add_child(_tractor_slot)


func _build_stats_card() -> void:
	var glass := PanelContainer.new()
	glass.name = &"DriveSummaryGlass"
	glass.theme_type_variation = ScopeTheme.GLASS
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", STAT_SEPARATION)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.add_child(box)

	var caption: Label = PlanBoardUI._label(STATS_CAPTION, ScopeTheme.INK_MUTED, CAPTION_FONT_SIZE)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)

	for key: StringName in Loadout.DRIVE_KEYS:
		var row := HBoxContainer.new()
		row.name = "Stat_%s" % key
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		var name_label: Label = PlanBoardUI._label(String(STAT_TITLES.get(key, String(key))), ScopeTheme.INK, STAT_FONT_SIZE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)
		var value_label: Label = PlanBoardUI._label(BASE_TEXT, ScopeTheme.INK_MUTED, STAT_FONT_SIZE)
		value_label.name = &"Value"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value_label)
		_stat_values[key] = value_label


func _refresh_tractor_base() -> void:
	if _tractor_slot == null:
		return
	var want: String = WIDE_TRACTOR_PATH if GameState.has_wide_treads else TRACTOR_PATH
	if _tractor_slot.model_path != want:
		_tractor_slot.swap_model(want)


func _set_tractor_look(parts: Dictionary) -> void:
	if _tractor_root == null:
		return
	if _tractor_look != null:
		_tractor_look.get_parent().remove_child(_tractor_look)
		_tractor_look.free()
		_tractor_look = null
	_tractor_look = Loadout.build_look(parts)
	if _tractor_look != null:
		_tractor_root.add_child(_tractor_look)


func _refresh_stats(parts: Dictionary) -> void:
	var factors: Dictionary = Loadout.drive(parts)
	for key: StringName in Loadout.DRIVE_KEYS:
		var label: Label = _stat_values.get(key)
		if label == null:
			continue
		var factor: float = float(factors.get(key, 1.0))
		if absf(factor - 1.0) < BASE_EPSILON:
			label.text = BASE_TEXT
			label.add_theme_color_override(&"font_color", ScopeTheme.INK_MUTED)
		else:
			var pct: float = roundf((factor - 1.0) * PERCENT_SCALE)
			label.text = "%s %%" % SP811.signed(pct, 0)
			label.add_theme_color_override(&"font_color", ScopeTheme.TEAL if factor > 1.0 else ScopeTheme.AMBER)
