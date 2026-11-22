class_name LabFloor
extends Node3D
## The lab's spaces along the dome's back wall (upgradeable lab, Ryan,
## 2026-11-22). One cabinet per space a discipline has, grouped into its area
## and labelled once; free spaces are bare floor pads; a space being cleared,
## and the spaces a growing lab is adding, show amber. The dome grows as the
## lab does: only the spaces the lab has (or is building) are drawn.

const TEAL: Color = Color("38E1C6")
const AMBER: Color = Color("F5A623")
const SPACE_WIDTH: float = 1.15
const SPACE_STEP: float = 1.25
## Spaces sit either side of the airlock, outermost first, left to right.
const FIRST_X: float = -1.95
const BACK_Z: float = -3.25

var _body_material: StandardMaterial3D
var _pad_material: StandardMaterial3D
var _teal_material: StandardMaterial3D
var _amber_material: StandardMaterial3D


func _ready() -> void:
	_body_material = _material(Color(0.36, 0.34, 0.33))
	_pad_material = _material(Color(0.3, 0.32, 0.31))
	_teal_material = _material(TEAL, 1.6)
	_amber_material = _material(AMBER, 1.2)
	GameState.lab_changed.connect(rebuild)
	rebuild()


## X of space `index` (0 is the leftmost of `count` spaces drawn). Spaces
## fill outward from the airlock on each side, so a small lab sits centred.
static func space_x(index: int, count: int) -> float:
	var left: int = ceili(count / 2.0)
	if index < left:
		return FIRST_X - SPACE_STEP * float(left - 1 - index)
	return -FIRST_X + SPACE_STEP * float(index - left)


func rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	# What each space shows, in order: areas (a space being cleared beside its own), free
	# spaces, then the spaces a growing lab is adding.
	# The space being cleared stays where it was, beside its old area.
	var slots: Array[Dictionary] = []
	var refit: String = str(GameState.lab_build.get("discipline", "")) if GameState.lab_build.get("kind", "") == "refit" else ""
	for discipline: Variant in GameState.job_disciplines():
		var spaces: int = GameState.lab_space(str(discipline))
		for i: int in spaces:
			slots.append({ "kind": "area", "discipline": str(discipline), "first": i == 0, "spaces": spaces })
		if refit != "" and str(discipline) == refit:
			slots.append({ "kind": "refit" })
	for i: int in GameState.lab_free_spaces():
		slots.append({ "kind": "free" })
	if GameState.lab_build.get("kind", "") == "grow":
		var target: Dictionary = GameState.lab_size_record(int(GameState.lab_build.get("size", 0)))
		for i: int in maxi(int(target.get("areas", 0)) - GameState.lab_spaces(), 0):
			slots.append({ "kind": "building" })
	for i: int in slots.size():
		_add_space(slots[i], Vector3(space_x(i, slots.size()), 0.0, BACK_Z))


func _add_space(slot: Dictionary, at: Vector3) -> void:
	var kind: String = slot["kind"]
	if kind == "area":
		_box(at + Vector3(0, 0.45, 0), Vector3(SPACE_WIDTH, 0.9, 0.7), _body_material)
		_box(at + Vector3(0, 0.92, 0.2), Vector3(SPACE_WIDTH - 0.1, 0.04, 0.2), _teal_material)
		if slot["first"]:
			var size: String = GameState.lab_area_size(int(slot["spaces"])).to_upper()
			_label(at + Vector3(0, 1.75, 0.2), "%s\n%s AREA" % [str(slot["discipline"]).to_upper(), size], TEAL)
		return
	var material: StandardMaterial3D = _pad_material if kind == "free" else _amber_material
	# Free spaces are bare pads; work under way is a low amber frame.
	var height: float = 0.04 if kind == "free" else 0.3
	_box(at + Vector3(0, height / 2.0, 0), Vector3(SPACE_WIDTH, height, 0.7), material)
	var text: String = { "free": "FREE", "refit": "CLEARING", "building": "BUILDING" }[kind]
	_label(at + Vector3(0, 1.0, 0.2), text, Color(0.75, 0.78, 0.76) if kind == "free" else AMBER)


func _box(at: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.position = at
	box.material = material
	add_child(box)


func _label(at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = 0.004
	label.font_size = 36
	# Drawn over the benches and terrarium in front, so every area reads.
	label.no_depth_test = true
	label.render_priority = 1
	label.outline_render_priority = 0
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 1)
	add_child(label)


static func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
