class_name ZoneDepthProps
extends Node3D
## The props of the depths (ZoneDepth), drawn from primitive meshes via
## TunnelLook: a way down (hatch under a support-beam arch), the lift stations
## (repaired timber-and-steel frame or broken with rubble), ore-vein / ice-seam
## find markers, and cracked thermal vents. Shows only; no rules.
## Palette and sizes are [PLACEHOLDER].

const ORE: Color = TunnelLook.CRYSTAL
const MINERAL: Color = TunnelLook.BRASS
const SAMPLE: Color = TunnelLook.ICE

## Hatch framing arch dimensions, in metres [PLACEHOLDER].
const HATCH_ARCH_SPAN_M: float = 3.0
const HATCH_ARCH_HEIGHT_M: float = 2.5
## Vent heat emission multiplier [PLACEHOLDER].
const VENT_GLOW_SCALE: float = 3.0

## Find id -> the node that shows it.
var _finds: Dictionary[String, Node3D] = {}
## Vent id -> { "vent": the vent, "glow": the material of its glowing grate }.
var _vents: Dictionary = {}


## A way down: a stepped steel & basalt hatch with cross-ribs, brass lugs, teal
## rim ring, and a support-beam arch over the mouth. `depth` is the one it is at
## (0, the hub; or 1 or 2 below, by the trunk).
func build_hatch(depth: int = 0) -> void:
	var hatch := Node3D.new()
	hatch.name = "Hatch"
	hatch.position = ZoneDepth.descent_position(depth)
	add_child(hatch)
	hatch.add_child(TunnelLook.part(TunnelLook.cylinder(1.42, 0.08), Vector3(0.0, 0.04, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
	hatch.add_child(TunnelLook.part(TunnelLook.cylinder(1.28, 0.06), Vector3(0.0, 0.07, 0.0), TunnelLook.flat_mat(TunnelLook.STEEL)))
	hatch.add_child(TunnelLook.part(TunnelLook.cylinder(1.14, 0.04), Vector3(0.0, 0.09, 0.0), TunnelLook.glow_mat(TunnelLook.CRYSTAL, 0.5)))
	hatch.add_child(TunnelLook.part(TunnelLook.cylinder(0.98, 0.08), Vector3(0.0, 0.09, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
	# Cross-ribbed hatch cover and brass latch lugs [PLACEHOLDER].
	hatch.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.55, 0.05, 0.14)), Vector3(0.0, 0.14, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_MID)))
	hatch.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.14, 0.05, 1.55)), Vector3(0.0, 0.14, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_MID)))
	for x: float in [-0.95, 0.95]:
		hatch.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.18, 0.10, 0.24)), Vector3(x, 0.11, 0.0), TunnelLook.flat_mat(TunnelLook.BRASS)))
	TunnelLook.add_support_arch(hatch, Vector3(0.0, 0.0, -1.25), HATCH_ARCH_SPAN_M, HATCH_ARCH_HEIGHT_M)
	hatch.add_child(TunnelLook.label("WAY DOWN", Vector3(0.0, 1.5, 0.0)))


## The lift station at `depth` (0, the hub's, or the depth that has one): stepped
## steel deck, steel-and-timber gantry with brass gussets (or leaning broken
## frame with rubble and a red strip). Drawn again when the farm's repair changes.
func build_lift(depth: int, repaired: bool) -> void:
	var old: Node = get_node_or_null("Lift")
	if old != null:
		remove_child(old)
		old.queue_free()
	var lift := Node3D.new()
	lift.name = "Lift"
	lift.position = ZoneDepth.lift_position(depth)
	add_child(lift)
	lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.55, 0.10, 2.55)), Vector3(0.0, 0.05, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
	lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.35, 0.08, 2.35)), Vector3(0.0, 0.10, 0.0), TunnelLook.flat_mat(TunnelLook.STEEL)))
	var post_mat: Material = TunnelLook.flat_mat(TunnelLook.STEEL if repaired else TunnelLook.BASALT_DARK)
	var wood_mat: Material = TunnelLook.flat_mat(TunnelLook.TIMBER if repaired else TunnelLook.BASALT_MID)
	lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 0.14, 0.36)), Vector3(-1.0, 0.16, -1.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
	lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.22, 2.6, 0.22)), Vector3(-1.0, 1.4, -1.0), post_mat))
	var second: MeshInstance3D = TunnelLook.part(TunnelLook.box(Vector3(0.22, 2.6, 0.22)), Vector3(1.0, 1.4, -1.0), post_mat)
	lift.add_child(second)
	var beam: MeshInstance3D = TunnelLook.part(TunnelLook.box(Vector3(2.55, 0.26, 0.26)), Vector3(0.0, 2.75, -1.0), wood_mat)
	lift.add_child(beam)
	if repaired:
		for side: int in [-1, 1]:
			lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.28, 0.22, 0.30)), Vector3(1.0 * side, 2.60, -1.0), TunnelLook.flat_mat(TunnelLook.BRASS)))
			lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.22, 0.22, 0.22)), Vector3(0.76 * side, 2.38, -1.0), wood_mat))
		lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.0, 0.04, 2.0)), Vector3(0.0, 0.16, 0.0), TunnelLook.glow_mat(TunnelLook.CRYSTAL, 0.8)))
		lift.add_child(TunnelLook.label("LIFT", Vector3(0.0, 3.3, -1.0)))
	else:
		# One post down, beam sagging, and cave-in rubble at the corner [PLACEHOLDER].
		second.rotation_degrees = Vector3(0.0, 0.0, 28.0)
		second.position = Vector3(1.5, 1.0, -1.0)
		beam.rotation_degrees = Vector3(0.0, 0.0, -14.0)
		beam.position = Vector3(0.0, 2.4, -1.0)
		TunnelLook.add_rubble_pile(lift, Vector3(0.95, 0.12, -0.75), 0.72)
		lift.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.4, 0.04, 1.4)), Vector3(0.0, 0.16, 0.0), TunnelLook.glow_mat(TunnelLook.BROKEN_RED, 0.6)))
		lift.add_child(TunnelLook.label("LIFT: BROKEN", Vector3(0.0, 3.3, -1.0)))


## Below: a marker for each of the layout's finds not in `taken`.
func build_finds(layout_data: Dictionary, taken: Array) -> void:
	for find: Dictionary in layout_data.get("finds", []):
		var node := Node3D.new()
		node.name = "Find_" + str(find["id"])
		node.position = TunnelRock.at(find["cell"])
		add_child(node)
		_finds[str(find["id"])] = node
		_draw_find(node, str(find["kind"]))
	show_taken(taken)


## Only the finds not taken are seen.
func show_taken(taken: Array) -> void:
	for find_id: String in _finds:
		_finds[find_id].visible = not find_id in taken


## Below: a vent prop for each of the day's vents (ZoneHazards): a cracked basalt
## & scorched regolith rim around a slatted grate that glows by its cycle
## (show_heat). A look only: a vent never blocks.
func build_vents(vents: Array) -> void:
	for vent: Dictionary in vents:
		var node := Node3D.new()
		node.name = "Vent_" + str(vent["id"])
		node.position = TunnelRock.at(vent["cell"])
		add_child(node)
		# Stepped dark basalt rim + scorched regolith crust chunks around the lip [PLACEHOLDER].
		node.add_child(TunnelLook.part(TunnelLook.cylinder(1.22, 0.06), Vector3(0.0, 0.03, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
		node.add_child(TunnelLook.part(TunnelLook.cylinder(1.06, 0.08), Vector3(0.0, 0.05, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_MID)))
		for i: int in 6:
			var rad: float = TAU * float(i) / 6.0
			var mat: Material = TunnelLook.flat_mat(TunnelLook.REGOLITH_DARK if i % 2 == 0 else TunnelLook.BASALT_DARK)
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.32, 0.14, 0.24)), Vector3(cos(rad) * 1.04, 0.09, sin(rad) * 1.04), mat, Vector3(0.0, -rad * 57.2958, 0.0)))
		var grate: StandardMaterial3D = TunnelLook.glow_mat(TunnelLook.vent_hot_color(), 0.0, false)
		node.add_child(TunnelLook.part(TunnelLook.cylinder(0.82, 0.06), Vector3(0.0, 0.06, 0.0), grate))
		# Dark iron grate slats over the warm glowing fissure [PLACEHOLDER].
		for z_off: float in [-0.36, 0.0, 0.36]:
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.42, 0.04, 0.10)), Vector3(0.0, 0.10, z_off), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
		node.add_child(TunnelLook.label("VENT", Vector3(0.0, 1.5, 0.0)))
		_vents[str(vent["id"])] = { "vent": vent, "glow": grate }


## Light each vent by the clock (days, GameClock.elapsed_days): bright while hot,
## half just before, a dull glow while cool. Zero per-frame allocation.
func show_heat(elapsed_days: float) -> void:
	for id: String in _vents:
		var entry: Dictionary = _vents[id]
		var material: StandardMaterial3D = entry["glow"]
		material.emission_energy_multiplier = ZoneHazards.glow(entry["vent"], elapsed_days) * VENT_GLOW_SCALE


func find_node(find_id: String) -> Node3D:
	return _finds.get(find_id)


func _draw_find(node: Node3D, kind: String) -> void:
	match kind:
		"ore":
			# Basalt matrix with stepped quartz-teal & crystal ore-vein clusters + brass flecks [PLACEHOLDER].
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.92, 0.22, 0.84)), Vector3(0.0, 0.11, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.56, 0.26, 0.48)), Vector3(-0.14, 0.22, 0.08), TunnelLook.flat_mat(TunnelLook.BASALT_MID)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.28, 0.34, 0.28)), Vector3(0.0, 0.28, 0.0), TunnelLook.flat_mat(TunnelLook.quartz_base_color())))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.20, 0.62, 0.20)), Vector3(0.0, 0.56, 0.0), TunnelLook.glow_mat(ORE, 1.3), Vector3(4.0, 18.0, -5.0)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.16, 0.44, 0.16)), Vector3(0.28, 0.36, 0.10), TunnelLook.glow_mat(ORE, 1.0), Vector3(-6.0, -22.0, 14.0)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.10, 0.10, 0.10)), Vector3(-0.26, 0.32, -0.14), TunnelLook.flat_mat(TunnelLook.BRASS)))
		"mineral":
			# Basalt slab split by a pale ice-seam ribbon and amber mineral nodule [PLACEHOLDER].
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.88, 0.24, 0.78)), Vector3(0.0, 0.12, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_MID)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.92, 0.12, 0.22)), Vector3(0.0, 0.24, 0.0), TunnelLook.flat_mat(TunnelLook.ICE)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.36, 0.34, 0.34)), Vector3(0.06, 0.34, 0.02), TunnelLook.glow_mat(MINERAL, 0.85), Vector3(0.0, 24.0, 0.0)))
		_:
			# Compact basalt & ice-chip plinth with cream/brass sample canister [PLACEHOLDER].
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.76, 0.16, 0.76)), Vector3(0.0, 0.08, 0.0), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
			node.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.30, 0.12, 0.24)), Vector3(-0.22, 0.16, 0.18), TunnelLook.flat_mat(TunnelLook.ICE)))
			node.add_child(TunnelLook.part(TunnelLook.cylinder(0.20, 0.42), Vector3(0.04, 0.34, -0.02), TunnelLook.flat_mat(TunnelLook.CREAM)))
			node.add_child(TunnelLook.part(TunnelLook.cylinder(0.22, 0.08), Vector3(0.04, 0.56, -0.02), TunnelLook.flat_mat(TunnelLook.BRASS)))
	node.add_child(TunnelLook.label(ZoneDepth.NAMES.get(kind, kind), Vector3(0.0, 1.5, 0.0)))
