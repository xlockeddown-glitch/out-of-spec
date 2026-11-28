class_name VallesLook
extends RefCounted
## Valles Marineris' look: named canyon-rock palette constants (one per wall band, bottom to
## top, in VallesDepth.BAND_NAMES order), a deterministic coordinate hash, and primitive-mesh
## builders for a layered canyon wall, talus heaps at a wall's foot, a banded post, and the
## notice board's trim. Primitives only, no art files; never mutates TunnelLook's cached
## materials. Every colour, size and hash choice is a [PLACEHOLDER].

## The wall bands, bottom to top: red clay, pale ash, rust shale, grey silt, ochre sand, white salt.
const CLAY_RED := Color(0.62, 0.30, 0.22)
const ASH_PALE := Color(0.80, 0.74, 0.68)
const SHALE_RUST := Color(0.55, 0.28, 0.16)
const SILT_GREY := Color(0.50, 0.48, 0.47)
const SAND_OCHRE := Color(0.78, 0.56, 0.28)
const SALT_WHITE := Color(0.90, 0.88, 0.84)
const BANDS: Array[Color] = [CLAY_RED, ASH_PALE, SHALE_RUST, SILT_GREY, SAND_OCHRE, SALT_WHITE]
const BAND_PALE: Color = ASH_PALE

const TALUS_DARK := Color(0.40, 0.26, 0.20)
const TALUS_LIGHT := Color(0.58, 0.40, 0.30)
const FLOOR_DUST := Color(0.66, 0.46, 0.34)
const ROCK_ROUGHNESS: float = 0.92
const BAND_STEP_M: float = 0.1
const WALL_HEIGHT_M: float = 7.2


## Deterministic integer hash from coordinates and salt (no global RNG) [PLACEHOLDER].
static func hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## The colour of wall band `index` (clamped).
static func band_color(index: int) -> Color:
	return BANDS[clampi(index, 0, BANDS.size() - 1)]


## A fresh (uncached) matte rock material.
static func rock_mat(color: Color, roughness: float = ROCK_ROUGHNESS) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## A canyon wall face: a stack of one box per band, each a little shifted so the layers step
## in and out, `size` wide and deep and `height` tall in all, standing on the floor at `at`.
## Keeps exactly BANDS.size() direct children on "BandWall" (visual only, no collision).
static func add_band_wall(parent: Node3D, at: Vector3, size: Vector2, height: float = WALL_HEIGHT_M) -> Node3D:
	var wall := Node3D.new()
	wall.name = "BandWall"
	wall.position = at
	parent.add_child(wall)
	var band_h: float = height / float(BANDS.size())
	for index: int in BANDS.size():
		var step: float = BAND_STEP_M * float((index * 3) % 4)
		var band: MeshInstance3D = TunnelLook.part(
			TunnelLook.box(Vector3(size.x, band_h, size.y + step)),
			Vector3(0.0, band_h * (float(index) + 0.5), step * 0.5),
			rock_mat(BANDS[index])
		)
		wall.add_child(band)
	return wall


## A talus heap at a wall's foot: a few stacked, tilted rocks of two browns, `width_m` across
## (visual only; the rover's shelter is VallesDepth.sheltered, by the map).
static func add_talus(parent: Node3D, at: Vector3, width_m: float = 4.0, salt: int = 0) -> Node3D:
	var heap := Node3D.new()
	heap.name = "Talus"
	heap.position = at
	parent.add_child(heap)
	var count: int = maxi(4, int(round(width_m / 0.7)))
	for i: int in count:
		var h: int = hash_int(i + roundi(at.x * 2.0), roundi(at.z * 2.0), 31 + salt + i)
		var frac: float = float(h % 100) / 100.0
		var x: float = (float(i) / float(maxi(count - 1, 1)) - 0.5) * width_m
		var z: float = (float((h / 7) % 11) / 10.0 - 0.5) * 0.9
		var size: float = 0.45 + 0.55 * frac
		var color: Color = TALUS_DARK if i % 2 == 0 else TALUS_LIGHT
		heap.add_child(TunnelLook.part(
			TunnelLook.box(Vector3(size * 1.3, size, size)),
			Vector3(x, size * 0.45, z),
			rock_mat(color),
			Vector3(float(h % 30), float(h % 90), float((h / 3) % 20))
		))
	return heap


## A post of the canyon's banded rock, `height` tall: one short column per band.
static func add_banded_post(parent: Node3D, at: Vector3, height: float) -> Node3D:
	var post := Node3D.new()
	post.name = "BandedPost"
	post.position = at
	parent.add_child(post)
	var band_h: float = height / float(BANDS.size())
	for index: int in BANDS.size():
		post.add_child(TunnelLook.part(
			TunnelLook.box(Vector3(0.5, band_h, 0.5)),
			Vector3(0.0, band_h * (float(index) + 0.5), 0.0),
			rock_mat(BANDS[index])
		))
	return post


## A layered core standing on end: one cylinder per band, bottom to top (visual only).
static func add_core(parent: Node3D, at: Vector3) -> Node3D:
	var core := Node3D.new()
	core.name = "CoreSample"
	core.position = at
	parent.add_child(core)
	for index: int in BANDS.size():
		core.add_child(TunnelLook.part(TunnelLook.cylinder(0.12, 0.2), Vector3(0.0, 0.1 + 0.2 * float(index), 0.0), rock_mat(BANDS[index], 0.6)))
	return core


## Adds a salt-white cap and band-coloured footplates to NoticeSign without altering its base
## structure, position or label.
static func add_sign_trim(board: Node3D) -> void:
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.14, 0.07, 0.26)), Vector3(0.0, 1.75, 0.0), rock_mat(SALT_WHITE, 0.7)))
	for x: float in [-0.82, 0.82]:
		board.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 0.05, 0.36)), Vector3(x, 0.025, 0.0), rock_mat(SHALE_RUST, 0.8)))
