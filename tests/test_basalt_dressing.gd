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
		var refused: Array[Vector2] = []
		for at: Vector2 in BasaltDressing.VENTS:
			if not BasaltDressing.clear(at):
				refused.append(at)
		return "%d of %d listed vents passed the rules; refused: %s" % [BasaltDressing.spots().size(), BasaltDressing.VENTS.size(), refused]
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
		for plant: HillDressing.Placed in HillDressing.plants():
			if absf(at.x - plant.at.x) < plant.half_m() + BasaltDressing.VENT_HALF_M and absf(at.y - plant.at.z) < plant.half_m() + BasaltDressing.VENT_HALF_M:
				return "The vent at %s is on a plant at %s" % [at, plant.at]
	return ""


func test_a_vent_is_refused_on_a_hill_plant() -> String:
	var tried: int = 0
	for plant: HillDressing.Placed in HillDressing.plants():
		var at := Vector2(plant.at.x, plant.at.z)
		if BiomeData.biome_at(at) != &"basalt_ridge":
			continue
		tried += 1
		if BasaltDressing.clear(at):
			return "A vent was allowed on the plant at %s" % at
	if tried == 0:
		return "No hill plant stands in the Basalt Ridge to try"
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
		Vector2(53.0, -41.0),               # a rock, in the ridge
		Vector2(25.2, -19.8),               # a pad-corner lamp, in the ridge
		Vector2(25.2, -22.6),               # a way lamp
		Vector2(30.7, -17.0),               # the pad's sign, in the ridge
		Vector2(20.5, -15.5),               # the tunnel pad
		Vector2(500.0, 0.0),                # off the land
	]
	for at: Vector2 in bad:
		if BasaltDressing.clear(at):
			return "A vent was allowed at %s" % at
	return ""


func test_vents_sit_on_the_ground_with_the_lip_above_every_edge() -> String:
	var dressing: BasaltDressing = _dressed()
	var none: Dictionary[Vector2i, int] = {}
	if dressing.vent_count() != BasaltDressing.spots().size():
		_cleanup()
		return "The scene has %d vents, not %d" % [dressing.vent_count(), BasaltDressing.spots().size()]
	var problem: String = ""
	for vent: Node in dressing.get_children():
		var node := vent as Node3D
		var at := Vector2(node.position.x, node.position.z)
		var top: float = node.position.y + (node.get_node("Puff") as Node3D).position.y
		if absf(node.position.y - Terrain.height(at, none)) > 0.5:
			problem = "A vent at %s is off the ground" % at
		for x: int in range(-1, 2):
			for z: int in range(-1, 2):
				var edge: float = Terrain.height(at + Vector2(x, z) * BasaltDressing.LIP_RADIUS_M, none)
				if top < edge + BasaltDressing.RING_HEIGHT_M - 0.001:
					problem = "The lip of the vent at %s is buried (%s under %s)" % [at, top, edge]
				if node.position.y > Terrain.height(at + Vector2(x, z) * BasaltDressing.FOOT_RADIUS_M, none) + 0.001:
					problem = "The foot of the vent at %s hangs in the air" % at
	_cleanup()
	return problem


func _nine_around(at: Vector2) -> Dictionary[Vector2i, int]:
	var centre: Vector2i = Terrain.cell_at(at)
	var dug: Dictionary[Vector2i, int] = {}
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			dug[centre + Vector2i(x, z)] = 1
	return dug


func test_a_dug_neighbour_does_not_bury_the_lip() -> String:
	var dressing: BasaltDressing = _dressed()
	var first: Vector2 = BasaltDressing.spots()[0]
	var centre: Vector2i = Terrain.cell_at(first)
	var problem: String = ""
	for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var dug: Dictionary[Vector2i, int] = {centre + step: 1}
		dressing.settle(dug)
		var vent := dressing.get_child(0) as Node3D
		var lip: float = vent.position.y + (vent.get_node("Puff") as Node3D).position.y
		if lip < Terrain.height(first, dug) + BasaltDressing.RING_HEIGHT_M - 0.001:
			problem = "The lip is buried by a dug neighbour at %s" % step
	_cleanup()
	return problem


func test_a_live_vent_follows_the_digging_and_comes_back() -> String:
	var dressing := BasaltDressing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(dressing)
	var first: Vector2 = BasaltDressing.spots()[0]
	var vent := dressing.get_child(0) as Node3D
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	var before: float = vent.position.y
	GameState.dug = _nine_around(first)
	GameState.terrain_changed.emit()
	var dropped: float = vent.position.y
	GameState.dug = saved
	GameState.terrain_changed.emit()
	var back: float = vent.position.y
	dressing.get_parent().remove_child(dressing)
	dressing.free()
	if not dropped < before:
		return "The vent did not drop after the cells under it were dug (%s, %s)" % [before, dropped]
	if not is_equal_approx(back, before):
		return "The vent did not come back after the digging was undone (%s, %s)" % [before, back]
	return ""


func test_a_vent_hides_under_stone_and_shows_again() -> String:
	var dressing := BasaltDressing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(dressing)
	var first: Vector2 = BasaltDressing.spots()[0]
	var saved: Dictionary[Vector2i, int] = GameState.stone_pieces.duplicate()
	var vent := dressing.get_child(0) as Node3D
	var puff := vent.get_node("Puff") as CPUParticles3D
	var shown_at_first: bool = vent.visible and puff.emitting
	var piece: Dictionary[Vector2i, int] = {Terrain.cell_at(first): 0}
	GameState.stone_pieces = piece
	GameState.stone_changed.emit()
	var hidden: bool = not vent.visible and not puff.emitting
	var others_shown: bool = dressing.is_shown(1)
	GameState.stone_pieces = saved
	GameState.stone_changed.emit()
	var back: bool = vent.visible and puff.emitting
	dressing.get_parent().remove_child(dressing)
	dressing.free()
	if not shown_at_first:
		return "The vent was not showing to begin with"
	if not hidden:
		return "The vent still shows (or steams) over a stone piece"
	if not others_shown:
		return "A vent far from the stone was hidden"
	if not back:
		return "The vent did not come back when the stone was taken up"
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
	for i: int in spots.size():
		for j: int in range(i + 1, spots.size()):
			if spots[i].distance_to(spots[j]) < RoadLamps.MIN_GAP_M:
				return "Lamps %d and %d stand %.2f m apart" % [i, j, spots[i].distance_to(spots[j])]
	var pad: Vector2 = BiomeData.marker(&"basalt_ridge")
	var mouth: Vector2 = BiomeData.entrance_at(&"basalt_ridge", &"lava_tubes") as Vector2
	var north: int = 0
	var south: int = 0
	for at: Vector2 in RoadLamps.BASALT_WAY_SPOTS:
		if not spots.has(at):
			return "The way lamp at %s was dropped" % at
		if at.x < mouth.x or at.x > pad.x or absf(at.y - mouth.y) > 6.0:
			return "The lamp at %s is not between the pad and the tunnel mouth" % at
		if absf(at.x - pad.x) < BiomeData.PAD_HALF_M and absf(at.y - pad.y) < BiomeData.PAD_HALF_M:
			return "The lamp at %s is on the pad" % at
		# The mouth and the tunnel pad are built things in BiomeData.spots().
		for box: Vector4 in BiomeData.spots():
			if absf(at.x - box.x) < box.z and absf(at.y - box.y) < box.w:
				return "The lamp at %s is on the built thing at %s" % [at, box]
		if at.y < pad.y:
			north += 1
		else:
			south += 1
	if north == 0 or south == 0:
		return "The way lamps should flank the way (%d north, %d south)" % [north, south]
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
