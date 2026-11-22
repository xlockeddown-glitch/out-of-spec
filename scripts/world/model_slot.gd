class_name ModelSlot
extends Node3D
## Greybox-to-voxel swap point. Children are the greybox. If `model_path`
## points at an imported model (MagicaVoxel .glb/.gltf in assets/voxels/), the
## greybox children are hidden and the model is instanced in their place.
## Dropping the file in is enough; no scene or code edits. Lights and other
## non-geometry children stay visible.

@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String = ""


func _ready() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var scene := load(model_path) as PackedScene
	if scene == null:
		push_warning("ModelSlot %s: %s is not a scene." % [name, model_path])
		return
	# Hide only greybox geometry (CSG and meshes); lights and markers stay.
	for child: Node in get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visible = false
	add_child(scene.instantiate())
