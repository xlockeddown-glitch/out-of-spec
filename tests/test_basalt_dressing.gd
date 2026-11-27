extends RefCounted
## Basalt Ridge dressing (docs/design/biomes.md section 6, step 10): darker ground,
## a few steam vents, and lamps on the way from the pad to the tunnel mouth. Scene
## dressing only: no height changes, so the land hashes (test_hills, test_land_240)
## stay as they are.

## The Basalt ground, after the shader, is at most this share of the Badlands' and
## of the farm hub's brightness [PLACEHOLDER].
const DARK_VS_BADLANDS: float = 0.66
const DARK_VS_HUB: float = 0.56

var _nodes: Array[Node] = []


func _cleanup() -> void:
	for node: Node in _nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()


func _dressed() -> BasaltDressing:
	var dressing := BasaltDressing.new()
	var none: Dictionary[Vector2i, int] = {}
	dressing.build(none)
	_nodes.append(dressing)
	return dressing


func _lamps() -> RoadLamps:
	var lamps := RoadLamps.new()
	var none: Dictionary[Vector2i, int] = {}
	lamps.build(none)
	_nodes.append(lamps)
	return lamps


func _on_screen(id: StringName) -> Color:
	return Color.WHITE.lerp(BiomeData.ground_tint(id), TerrainGround.BIOME_STRENGTH) * Color(0.42, 0.5, 0.3)


func test_every_listed_vent_passes_and_lies_in_the_ridge() -> String:
	if BasaltDressing.spots().size() != BasaltDressing.VENTS.size():
		return "%d of %d listed vents passed the rules" % [BasaltDressing.spots().size(), BasaltDressing.VENTS.size()]
	if BasaltDressing.spots().size() < 4:
		return "Too few vents"
	for at: Vector2 in BasaltDressing.spots():
		if BiomeData.biome_at(at) != &"basalt_ridge":
			return "The vent at %s is not in the Basalt Ridge" % at
	return ""


func test_no_vent_stands_where_it_must_not() -> String:
	var whole: Array[Vector4] = BiomeData.spots()
	for at: Vector2 in BasaltDressing.spots():
		var cell := Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))
		if BiomeData.on_road(at) or BiomeData.is_road_cell(cell):
			return "The vent at %s is on a road" % at
		if BiomeMarkers.is_blocked_cell(cell):
			return "The vent at %s is on a pad or sign" % at
		if absf(at.x) < BiomeData.PLOT_HALF_M and absf(at.y) < BiomeData.PLOT_HALF_M:
			return "The vent at %s is on the plot" % at
		for box: Vector4 in whole:
			if absf(at.x - box.x) < box.z + BasaltDressing.VENT_HALF_M and absf(at.y - box.y) < box.w + BasaltDressing.VENT_HALF_M:
				return "The vent at %s is on the thing at %s (rock, fissure or built)" % [at, box]
		for id: StringName in BiomeData.ids():
			for zone: StringName in BiomeData.zones(id):
				var way: Variant = BiomeData.entrance_at(id, zone)
				if way is Vector2 and at.distance_to(way as Vector2) < 4.0:
					return "The vent at %s is within 4 m of the way in at %s" % [at, way]
		for lamp: Vector2 in RoadLamps.spots(&"basalt_ridge"):
			if at.distance_to(lamp) < 1.0:
				return "The vent at %s is on a lamp" % at
	return ""


func test_the_rules_refuse_a_bad_spot() -> String:
	var bad: Array[Vector2] = [
		Vector2.ZERO,                       # the plot
		BiomeData.marker(&"basalt_ridge"),  # the pad
		Vector2(20.5, -19.0),               # the tunnel mouth
		Vector2(50.0, -24.0),               # the Colony Mine way in
		Vector2(-17.0, -10.0),              # a rock, and not in the ridge
		Vector2(50.0, 20.0),                # not in the ridge
		Vector2(52.0, 14.0),                # a fissure
		Vector2(500.0, 0.0),                # off the land
	]
	for at: Vector2 in bad:
		if BasaltDressing.clear(at):
			return "A vent was allowed at %s" % at
	return ""


func test_vents_sit_on_the_ground_and_follow_digging() -> String:
	var dressing: BasaltDressing = _dressed()
	if dressing.vent_count() != BasaltDressing.spots().size():
		_cleanup()
		return "The scene has %d vents, not %d" % [dressing.vent_count(), BasaltDressing.spots().size()]
	var none: Dictionary[Vector2i, int] = {}
	for vent: Node in dressing.get_children():
		var at: Vector2 = Vector2((vent as Node3D).position.x, (vent as Node3D).position.z)
		if absf((vent as Node3D).position.y - Terrain.height(at, none)) > 0.5:
			_cleanup()
			return "A vent at %s is off the ground" % at
	# Dig the cell under the first vent: it follows.
	var first: Vector2 = BasaltDressing.spots()[0]
	var cell := Vector2i(floori(first.x / Terrain.CELL_M), floori(first.y / Terrain.CELL_M))
	var dug: Dictionary[Vector2i, int] = {cell: 2}
	dressing.settle(dug)
	var moved: float = (dressing.get_child(0) as Node3D).position.y
	var want: float = BasaltDressing.ground_y(first, dug)
	_cleanup()
	if absf(moved - want) > 0.001:
		return "The vent did not follow the digging"
	return ""


func test_a_vent_is_dressing_only() -> String:
	var dressing: BasaltDressing = _dressed()
	var problem: String = ""
	for vent: Node in dressing.get_children():
		var ring: MeshInstance3D = vent.get_node("Ring") as MeshInstance3D
		var puff: CPUParticles3D = vent.get_node("Puff") as CPUParticles3D
		if ring == null or puff == null:
			problem = "A vent lacks its ring or puff"
		elif puff.amount > 12:
			problem = "A puff has %d particles" % puff.amount
		else:
			for node: Node in [vent, ring, puff]:
				if node is CollisionObject3D or node is Light3D or node is Clickable:
					problem = "A vent has collision, a light or a click"
			if not vent.find_children("*", "CollisionObject3D", true, false).is_empty() or not vent.find_children("*", "Light3D", true, false).is_empty():
				problem = "A vent has collision or a light"
	_cleanup()
	return problem


func test_the_tunnel_mouth_lamps_stand_on_the_way_and_are_clear() -> String:
	var spots: Array[Vector2] = RoadLamps.spots(&"basalt_ridge")
	if spots.size() != 4 + RoadLamps.BASALT_WAY_SPOTS.size():
		return "The ridge has %d lamps, want the four corners and %d on the way" % [spots.size(), RoadLamps.BASALT_WAY_SPOTS.size()]
	var pad: Vector2 = BiomeData.marker(&"basalt_ridge")
	var mouth := Vector2(20.5, -19.0)
	for at: Vector2 in RoadLamps.BASALT_WAY_SPOTS:
		if not spots.has(at):
			return "The way lamp at %s was dropped" % at
		if at.x < mouth.x or at.x > pad.x or absf(at.y - mouth.y) > 6.0:
			return "The lamp at %s is not between the pad and the tunnel mouth" % at
		if absf(at.x - pad.x) < BiomeData.PAD_HALF_M and absf(at.y - pad.y) < BiomeData.PAD_HALF_M:
			return "The lamp at %s is on the pad" % at
		if absf(at.x - mouth.x) < 4.0 and absf(at.y - mouth.y) < 3.0:
			return "The lamp at %s is on the tunnel mouth" % at
	return ""


func test_the_tunnel_mouth_lamps_are_dark_closed_and_lit_open() -> String:
	var xp: int = GameState.lab_xp
	var kept: Array[Dictionary] = GameState.audit_log.duplicate()
	var problem: String = ""
	for level: int in [4, 5]:
		GameState.lab_xp = GameState.xp_for_level(level)
		var lamps: RoadLamps = _lamps()
		var dark: Material = (lamps.get_node("Lamp_basalt_ridge_0/Head") as MeshInstance3D).material_override
		var count: int = lamps.lamp_count(&"basalt_ridge")
		for i: int in range(count - RoadLamps.BASALT_WAY_SPOTS.size(), count):
			var head: MeshInstance3D = lamps.get_node("Lamp_basalt_ridge_%d/Head" % i) as MeshInstance3D
			var lit: bool = (head.material_override as StandardMaterial3D).emission_enabled
			if lit != (level >= 5) or lit != lamps.is_lit(&"basalt_ridge"):
				problem = "The way lamp %d is %s at lab %d" % [i, "lit" if lit else "dark", level]
		if dark == null:
			problem = "A lamp has no material"
		_cleanup()
	GameState.lab_xp = xp
	GameState.audit_log.assign(kept)
	return problem


func test_basalt_ground_reads_apart_from_the_badlands_and_the_hub() -> String:
	var basalt: float = _on_screen(&"basalt_ridge").get_luminance()
	var badlands: float = _on_screen(&"badlands").get_luminance()
	var hub: float = _on_screen(&"farm").get_luminance()
	if basalt > badlands * DARK_VS_BADLANDS:
		return "Basalt (%.3f) is not clearly darker than the Badlands (%.3f)" % [basalt, badlands]
	if basalt > hub * DARK_VS_HUB:
		return "Basalt (%.3f) is not clearly darker than the hub (%.3f)" % [basalt, hub]
	return ""
