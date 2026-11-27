class_name IceLook
extends RefCounted
## The Polar Ice Caves' look (zones step 15): named colours and the plain primitive builders
## for the hub's ice walls, layered bands and heater crate. TunnelLook's part builders do the
## work; this file only names the ice colours. All of it is a [PLACEHOLDER] for the real look.

const ICE_PALE := Color(0.84, 0.92, 0.96)
const ICE_BLUE := Color(0.62, 0.78, 0.88)
const ICE_DEEP := Color(0.38, 0.56, 0.72)
const ICE_DUST := Color(0.72, 0.76, 0.80)
const HEATER_ORANGE := Color(0.90, 0.46, 0.16)
## The layered bands of an ice wall, from the floor up.
const BANDS: Array[Color] = [ICE_DEEP, ICE_BLUE, ICE_PALE, ICE_DUST, ICE_PALE]


## An ice wall: a stack of flat bands, each a little shifted, `size` wide and deep and `height`
## tall in all, standing on the floor at `at` (relative to `parent`).
static func add_ice_wall(parent: Node3D, at: Vector3, size: Vector2, height: float) -> Node3D:
	var wall := Node3D.new()
	wall.name = "IceWall"
	wall.position = at
	parent.add_child(wall)
	var band_h: float = height / float(BANDS.size())
	for index: int in BANDS.size():
		var shift: float = 0.12 * float(index % 2)
		wall.add_child(TunnelLook.part(TunnelLook.box(Vector3(size.x - shift, band_h, size.y - shift)),
				Vector3(shift * 0.5, band_h * (float(index) + 0.5), 0.0), TunnelLook.flat_mat(BANDS[index])))
	return wall


## The heater crate: a steel box with an orange cartridge rack and a label.
static func add_heater_crate(parent: Node3D, at: Vector3) -> Node3D:
	var crate := Node3D.new()
	crate.name = "HeaterCrate"
	crate.position = at
	parent.add_child(crate)
	var steel_mat: Material = TunnelLook.flat_mat(TunnelLook.STEEL)
	var body_mat: Material = TunnelLook.flat_mat(ICE_DUST)
	var heat_mat: Material = TunnelLook.flat_mat(HEATER_ORANGE)
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.3, 0.7, 0.9)), Vector3(0.0, 0.35, 0.0), body_mat))
	for sx: float in [-0.6, 0.6]:
		for sz: float in [-0.4, 0.4]:
			crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.1, 0.78, 0.1)), Vector3(sx, 0.39, sz), steel_mat))
	for i: int in 3:
		crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.12, 0.5), Vector3(-0.35 + 0.35 * float(i), 0.95, 0.0), heat_mat))
	crate.add_child(TunnelLook.label("HEATER CRATE", Vector3(0.0, 1.6, 0.0), TunnelLook.FROST))
	return crate
