class_name UplinkBeam
extends MeshInstance3D
## Short telemetry beam from the rover antenna toward the satellite relay:
## cyan while the link is clear, red when line of sight is blocked. Readable
## at a glance from the isometric camera.

const COLOR_CLEAR := Color(0.3, 0.85, 1.0, 0.55)
const COLOR_BLOCKED := Color(1.0, 0.35, 0.37, 0.35)

@export var rover: RoverController
@export var length_m: float = 7.0

var _material := StandardMaterial3D.new()


func _ready() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.06
	cyl.height = length_m
	mesh = cyl
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if rover == null or rover.satellite_relay == null:
		visible = false
		return
	var from: Vector3 = get_parent_node_3d().global_position
	var to: Vector3 = rover.satellite_relay.get_uplink_point()
	var dir: Vector3 = (to - from).normalized()
	# Cylinder axis is +Y: build a basis whose Y points along the beam.
	var y: Vector3 = dir
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y)
	global_transform = Transform3D(Basis(x, y, z), from + dir * (length_m * 0.5))
	var c: Color = COLOR_CLEAR if rover.has_line_of_sight else COLOR_BLOCKED
	_material.albedo_color = c
	_material.emission = Color(c.r, c.g, c.b)
	visible = true
