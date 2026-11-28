class_name OlympusLook
extends RefCounted
## The Olympus Mons caves' look: named lava-tube palette constants, a deterministic coordinate
## hash, and primitive-mesh builders for a shaft of skylight, huge breakdown blocks, a basalt
## pillar and the notice board's trim. Primitives only, no art files; never mutates TunnelLook's
## cached materials. Every colour, size and hash choice is a [PLACEHOLDER].

const BASALT_BLACK := Color(0.12, 0.11, 0.12)
const BASALT_GREY := Color(0.30, 0.29, 0.30)
const CRUST_BROWN := Color(0.36, 0.26, 0.20)
const EMBER_ORANGE := Color(0.92, 0.46, 0.16)
const EMBER_PALE := Color(0.98, 0.78, 0.56)
const SKY_LIGHT := Color(0.96, 0.92, 0.80)
const SULFUR_YELLOW := Color(0.82, 0.72, 0.28)
const FLOOR_ASH := Color(0.22, 0.20, 0.20)
const BLOCK_TONES: Array[Color] = [BASALT_BLACK, BASALT_GREY, CRUST_BROWN]
const ROCK_ROUGHNESS: float = 0.95
## The shaft's height and radius, in metres: a hole in a roof high above the hall.
const SHAFT_HEIGHT_M: float = 16.0
const SHAFT_RADIUS_M: float = 2.6
const SHAFT_ALPHA: float = 0.16
const SHAFT_LIGHT_ENERGY: float = 3.0
const SHAFT_LIGHT_RANGE_M: float = 22.0


## Deterministic integer hash from coordinates and salt (no global RNG) [PLACEHOLDER].
static func hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## A fresh (uncached) matte rock material.
static func rock_mat(color: Color, roughness: float = ROCK_ROUGHNESS) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## A shaft of light standing on the floor at `at`: a pale, see-through cylinder from the floor to the
## hole in the roof, a warm light at its foot and a pool of light on the floor. Visual only.
static func add_skylight(parent: Node3D, at: Vector3) -> Node3D:
	var shaft := Node3D.new()
	shaft.name = "Skylight"
	shaft.position = at
	parent.add_child(shaft)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(SKY_LIGHT, SHAFT_ALPHA)
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft.add_child(TunnelLook.part(
		TunnelLook.cylinder(SHAFT_RADIUS_M, SHAFT_HEIGHT_M),
		Vector3(0.0, SHAFT_HEIGHT_M * 0.5, 0.0),
		beam_mat
	))
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(SKY_LIGHT, 0.5)
	pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft.add_child(TunnelLook.part(TunnelLook.cylinder(SHAFT_RADIUS_M * 0.9, 0.04), Vector3(0.0, 0.03, 0.0), pool_mat))
	var light := OmniLight3D.new()
	light.name = "SkylightLamp"
	light.light_color = SKY_LIGHT
	light.light_energy = SHAFT_LIGHT_ENERGY
	light.omni_range = SHAFT_LIGHT_RANGE_M
	light.position = Vector3(0.0, 4.0, 0.0)
	shaft.add_child(light)
	return shaft


## A huge breakdown block: a big slab and a smaller one leaning on it, `size` wide, deep and tall
## (visual only, no collision; the open middle of the hall stays clear).
static func add_breakdown_block(parent: Node3D, at: Vector3, size: Vector3, salt: int = 0) -> Node3D:
	var block := Node3D.new()
	block.name = "BreakdownBlock"
	block.position = at
	parent.add_child(block)
	var h: int = hash_int(roundi(at.x * 2.0), roundi(at.z * 2.0), 71 + salt)
	block.add_child(TunnelLook.part(
		TunnelLook.box(size),
		Vector3(0.0, size.y * 0.5, 0.0),
		rock_mat(BLOCK_TONES[h % BLOCK_TONES.size()]),
		Vector3(0.0, float(h % 90), 0.0)
	))
	var lean: Vector3 = size * 0.55
	block.add_child(TunnelLook.part(
		TunnelLook.box(lean),
		Vector3(size.x * 0.45, lean.y * 0.5, size.z * 0.3),
		rock_mat(BLOCK_TONES[(h / 3) % BLOCK_TONES.size()]),
		Vector3(float((h / 7) % 14), float((h / 5) % 90), float((h / 11) % 12))
	))
	return block


## A basalt pillar `height` tall, with an ember-lit band near its top (visual only).
static func add_pillar(parent: Node3D, at: Vector3, height: float) -> Node3D:
	var post := Node3D.new()
	post.name = "BasaltPillar"
	post.position = at
	parent.add_child(post)
	post.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.7, height, 0.7)), Vector3(0.0, height * 0.5, 0.0), rock_mat(BASALT_GREY)))
	post.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.76, 0.2, 0.76)), Vector3(0.0, height - 0.5, 0.0), rock_mat(EMBER_ORANGE, 0.6)))
	return post


## Adds a cap and footplates to NoticeSign without altering its base structure, position or label.
static func add_sign_trim(board: Node3D) -> void:
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.14, 0.07, 0.26)), Vector3(0.0, 1.75, 0.0), rock_mat(EMBER_ORANGE, 0.7)))
	for x: float in [-0.82, 0.82]:
		board.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 0.05, 0.36)), Vector3(x, 0.025, 0.0), rock_mat(CRUST_BROWN, 0.8)))
