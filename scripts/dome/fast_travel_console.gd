class_name FastTravelConsole
extends Node3D
## The console in the dome that opens the fast-travel panel (zones doc section
## 8.1). Built in code: a desk, a screen and a clickable box.

signal clicked

const HINT: String = "Fast-travel console: go to a place by its field rover"

var click: Clickable


func _ready() -> void:
	var desk := CSGBox3D.new()
	desk.size = Vector3(1.2, 0.9, 0.6)
	desk.position = Vector3(0, 0.45, 0)
	add_child(desk)
	var screen := CSGBox3D.new()
	screen.size = Vector3(1.0, 0.6, 0.06)
	screen.position = Vector3(0, 1.2, -0.15)
	screen.rotation_degrees = Vector3(-12, 0, 0)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.1, 0.4, 0.38)
	glow.emission_enabled = true
	glow.emission = Color(0.22, 0.88, 0.78)
	glow.emission_energy_multiplier = 0.6
	screen.material = glow
	add_child(screen)
	var title := Label3D.new()
	title.text = "FAST TRAVEL"
	title.pixel_size = 0.004
	title.font_size = 48
	title.modulate = Color(0.22, 0.88, 0.78)
	title.position = Vector3(0, 1.2, -0.1)
	add_child(title)
	click = Clickable.new()
	click.collision_layer = 8
	click.collision_mask = 0
	click.hint = HINT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.6, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	click.add_child(shape)
	add_child(click)
	click.clicked.connect(clicked.emit)
