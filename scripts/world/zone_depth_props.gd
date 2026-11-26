class_name ZoneDepthProps
extends Node3D
## The props of the first depth (ZoneDepth), drawn from primitive meshes like
## LavaHubProps': the hatch down in the hub, and below, one marker for each find
## still there. Shows only; no rules. The look is plain [PLACEHOLDER].

const ORE := Color(0.2196, 0.8824, 0.7765)
const MINERAL := Color(0.96, 0.65, 0.14)
const SAMPLE := Color(0.72, 0.72, 0.78)

## Find id -> the node that shows it.
var _finds: Dictionary[String, Node3D] = {}


## The hatch in the hub: a dark plate with a lit rim and a sign.
func build_hatch() -> void:
	var hatch := Node3D.new()
	hatch.name = "Hatch"
	hatch.position = ZoneDepth.descent_position()
	add_child(hatch)
	hatch.add_child(LavaHubProps._part(LavaHubProps._cylinder(1.3, 0.06), Vector3(0.0, 0.03, 0.0), LavaHubProps._flat(LavaHubProps.STEEL)))
	hatch.add_child(LavaHubProps._part(LavaHubProps._cylinder(1.0, 0.08), Vector3(0.0, 0.04, 0.0), LavaHubProps._flat(LavaHubProps.DARK)))
	hatch.add_child(LavaHubProps._part(LavaHubProps._cylinder(1.15, 0.03), Vector3(0.0, 0.015, 0.0), LavaHubProps._glow(LavaHubProps.CYAN, 0.5)))
	hatch.add_child(LavaHubProps._label("WAY DOWN", Vector3(0.0, 1.5, 0.0)))


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


func find_node(find_id: String) -> Node3D:
	return _finds.get(find_id)


func _draw_find(node: Node3D, kind: String) -> void:
	match kind:
		"ore":
			node.add_child(LavaHubProps._part(LavaHubProps._cylinder(0.18, 0.9), Vector3(0.0, 0.45, 0.0), LavaHubProps._glow(ORE, 1.4)))
			node.add_child(LavaHubProps._part(LavaHubProps._cylinder(0.12, 0.6), Vector3(0.35, 0.3, 0.1), LavaHubProps._glow(ORE, 1.0)))
		"mineral":
			node.add_child(LavaHubProps._part(LavaHubProps._box(Vector3(0.6, 0.45, 0.5)), Vector3(0.0, 0.22, 0.0), LavaHubProps._glow(MINERAL, 0.9)))
		_:
			node.add_child(LavaHubProps._part(LavaHubProps._sphere(0.3), Vector3(0.0, 0.3, 0.0), LavaHubProps._flat(SAMPLE)))
	node.add_child(LavaHubProps._label(ZoneDepth.NAMES.get(kind, kind), Vector3(0.0, 1.5, 0.0)))
