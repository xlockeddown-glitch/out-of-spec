class_name VoxelWater
extends MultiMeshInstance3D
## Still water in voxel columns, wherever the ground is below its level. The tint
## comes from the depth, which is known, and nothing glows. It is only drawn: what
## stops a rover is up to whoever places it.

const COLUMN_M: float = 0.25  # [PLACEHOLDER]
const SHALLOW := Color("#2c5e6b")
const DEEP := Color("#244858")
## Deep from here down, in this many steps on the way [PLACEHOLDER].
const DEEP_M: float = 0.8
const TINT_STEPS: int = 4
## How much lighter a column next to dry ground is [PLACEHOLDER].
const FOAM_LIGHTER: float = 0.3

const RIPPLE: Shader = preload("res://scripts/world/voxel_water.gdshader")

## The columns, for tests: headless, the mesh does not give them back.
var places: Array[Transform3D] = []
var colors: Array[Color] = []


## The color of water this deep.
static func tint(depth_m: float) -> Color:
	var step: int = clampi(int(depth_m / DEEP_M * TINT_STEPS), 0, TINT_STEPS)
	return SHALLOW.lerp(DEEP, float(step) / TINT_STEPS)


## Fills `area` up to `level_m`. `ground_m` gives the ground's height at a Vector2
## of x and z.
func fill(area: Rect2, level_m: float, ground_m: Callable) -> void:
	places.clear()
	colors.clear()
	for x: int in ceili(area.size.x / COLUMN_M):
		for z: int in ceili(area.size.y / COLUMN_M):
			var at: Vector2 = area.position + (Vector2(x, z) + Vector2.ONE * 0.5) * COLUMN_M
			var depth_m: float = level_m - ground_m.call(at)
			if depth_m <= 0.0:
				continue
			var shore: bool = false
			for side: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				shore = shore or ground_m.call(at + side * COLUMN_M) >= level_m
			places.append(Transform3D(Basis.from_scale(Vector3(COLUMN_M, depth_m, COLUMN_M)), Vector3(at.x, level_m - depth_m * 0.5, at.y)))
			var color: Color = tint(depth_m).lightened(FOAM_LIGHTER if shore else 0.0).srgb_to_linear()
			# Tells the shader which columns are foam.
			color.a = 1.0 if shore else 0.0
			colors.append(color)
	var material := ShaderMaterial.new()
	material.shader = RIPPLE
	var mesh := BoxMesh.new()
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = places.size()
	for i: int in places.size():
		multi.set_instance_transform(i, places[i])
		multi.set_instance_color(i, colors[i])
	multimesh = multi
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
