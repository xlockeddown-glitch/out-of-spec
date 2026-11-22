class_name ModelSlot
extends Node3D
## Greybox-to-voxel swap point. If `model_path` points at an imported model
## (MagicaVoxel export in assets/voxels/), the greybox is hidden and the model
## is instanced here. Dropping the file in is enough; no scene or code edits.
##
## Greybox: the nodes in `greybox`, or, when that list is empty, this node's own
## geometry children. Lights, markers and state LEDs the game drives stay visible.
##
## Emissive voxels: any mesh in the model whose name starts with "emit_" glows in
## its own palette colors (MagicaVoxel exports drop emission). See
## docs/art/voxel_models.md for the naming rules.

const EMIT_PREFIX := "emit_"
const EMIT_ENERGY := 2.5

@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String = ""
## Uniform scale for the imported model, so one voxel lands at the size given in
## docs/art/voxel_models.md for this slot.
@export var model_scale: float = 1.0
## Greybox nodes to hide when a model loads. Empty = this node's geometry children.
@export var greybox: Array[Node3D] = []

var _model: Node3D = null


func _ready() -> void:
	swap_model(model_path)


## Loads `path` in place of the greybox (or the current model). Returns false and
## leaves things as they are if the file is missing or is not a scene.
func swap_model(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("ModelSlot %s: %s is not a scene." % [name, path])
		return false
	var root: Node = scene.instantiate()
	var instance := root as Node3D
	if instance == null:
		push_warning("ModelSlot %s: %s has no 3D root." % [name, path])
		root.free()
		return false
	if _model:
		_model.queue_free()
	_hide_greybox()
	instance.scale = Vector3.ONE * model_scale
	apply_emission(instance)
	add_child(instance)
	_model = instance
	model_path = path
	return true


func has_model() -> bool:
	return _model != null


## Shows or hides a named part of the loaded model (e.g. "emit_fiber"). Returns
## false if no model is loaded or the part isn't in it.
func set_part_visible(part_name: String, shown: bool) -> bool:
	if _model == null:
		return false
	var part := _model.find_child(part_name, true, false) as Node3D
	if part == null:
		return false
	part.visible = shown
	return true


func _hide_greybox() -> void:
	var targets: Array[Node3D] = greybox.duplicate()
	if targets.is_empty():
		for child: Node in get_children():
			if child is GeometryInstance3D:
				targets.append(child as Node3D)
	for node: Node3D in targets:
		if node:
			node.visible = false


## Makes meshes named emit_* glow in their own colors. Also used by OreFissure.
static func apply_emission(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not String(node.name).to_lower().begins_with(EMIT_PREFIX):
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(i) as BaseMaterial3D
			if source == null:
				continue
			var glow := source.duplicate() as BaseMaterial3D
			glow.emission_enabled = true
			glow.emission_energy_multiplier = EMIT_ENERGY
			if glow.albedo_texture:
				# Palette texture: glow = texture color (MULTIPLY, not the default ADD,
				# which would wash it to white).
				glow.emission = Color.WHITE
				glow.emission_texture = glow.albedo_texture
				glow.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			else:
				glow.emission = glow.albedo_color
			mesh_instance.set_surface_override_material(i, glow)
