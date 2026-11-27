extends RefCounted
## Frost Flats dressing (docs/design/biomes.md section 6, step 11): a few pale rocks
## round the pad. Scene dressing only: no height changes (so the land hashes stay as
## they are), no collision, and the ground tint is as it was.

## A road must show against the Frost ground by at least this, after the shader.
const MIN_ROAD_CONTRAST: float = 0.08
const SHADER_BASE := Color(0.42, 0.5, 0.3)

var _nodes: Array[Node] = []


func _cleanup() -> void:
	for node: Node in _nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()


func _dressed() -> FrostDressing:
	var dressing := FrostDressing.new()
	var none: Dictionary[Vector2i, int] = {}
	dressing.build(none)
	_nodes.append(dressing)
	return dressing


func _nine_around(at: Vector2) -> Dictionary[Vector2i, int]:
	var centre: Vector2i = Terrain.cell_at(at)
	var dug: Dictionary[Vector2i, int] = {}
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			dug[centre + Vector2i(x, z)] = 1
	return dug


func test_every_listed_rock_passes_and_lies_in_the_flats() -> String:
	if FrostDressing.spots().size() != FrostDressing.ROCKS.size():
		var refused: Array[Vector4] = []
		for rock: Vector4 in FrostDressing.ROCKS:
			if not FrostDressing.clear(rock):
				refused.append(rock)
		return "%d of %d rocks passed the rules; refused: %s" % [FrostDressing.spots().size(), FrostDressing.ROCKS.size(), refused]
	if FrostDressing.spots().size() < 5 or FrostDressing.spots().size() > 8:
		return "The set has %d rocks, want 5 to 8" % FrostDressing.spots().size()
	for rock: Vector4 in FrostDressing.spots():
		var at := Vector2(rock.x, rock.y)
		if BiomeData.biome_at(at) != &"frost_flats" or at.distance_to(BiomeData.marker(&"frost_flats")) > BiomeData.reach(&"frost_flats"):
			return "The rock at %s is not inside the Frost Flats" % at
	return ""


func test_no_rock_stands_where_it_must_not() -> String:
	var rocks: Array[Vector4] = FrostDressing.spots()
	var pad: Vector2 = BiomeData.marker(&"frost_flats")
	for i: int in rocks.size():
		var rock: Vector4 = rocks[i]
		var at := Vector2(rock.x, rock.y)
		var half: float = rock.z
		for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), Vector2.ZERO]:
			var cell: Vector2i = Terrain.cell_at(at + corner * half)
			if BiomeData.is_road_cell(cell):
				return "The rock at %s is on a road cell" % at
			if BiomeMarkers.is_blocked_cell(cell):
				return "The rock at %s is on the pad or sign" % at
		if BiomeData.road_gap(at) <= BiomeData.ROAD_HALF_M + half:
			return "The rock at %s is on the road" % at
		if absf(at.x) < BiomeData.PLOT_HALF_M and absf(at.y) < BiomeData.PLOT_HALF_M:
			return "The rock at %s is on the plot" % at
		if absf(at.x - pad.x) < BiomeData.PAD_HALF_M + half and absf(at.y - pad.y) < BiomeData.PAD_HALF_M + half:
			return "The rock at %s is on the pad" % at
		for box: Vector4 in BiomeData.spots():
			if absf(at.x - box.x) < box.z + half and absf(at.y - box.y) < box.w + half:
				return "The rock at %s is on the thing at %s" % [at, box]
		for lamp: Vector2 in RoadLamps.spots(&"frost_flats"):
			if at.distance_to(lamp) < half:
				return "The rock at %s is on a lamp" % at
		for plant: HillDressing.Placed in HillDressing.plants():
			if absf(at.x - plant.at.x) < plant.half_m() + half and absf(at.y - plant.at.z) < plant.half_m() + half:
				return "The rock at %s is on a plant" % at
		for j: int in range(i + 1, rocks.size()):
			if at.distance_to(Vector2(rocks[j].x, rocks[j].y)) < half + rocks[j].z:
				return "Rocks %d and %d overlap" % [i, j]
	return ""


func test_the_pads_approach_is_open() -> String:
	var pad: Vector2 = BiomeData.marker(&"frost_flats")
	for rock: Vector4 in FrostDressing.spots():
		if absf(rock.x - pad.x) < FrostDressing.APPROACH_HALF_M and rock.y > pad.y - BiomeData.PAD_HALF_M:
			return "The rock at (%s, %s) is in front of the pad" % [rock.x, rock.y]
	return ""


func test_the_rules_refuse_a_bad_rock() -> String:
	var pad: Vector2 = BiomeData.marker(&"frost_flats")
	var bad: Array[Vector4] = [
		Vector4(0.0, 0.0, 0.8, 0.5),                  # the plot
		Vector4(0.0, -50.0, 0.8, 0.5),                # the road
		Vector4(1.4, -60.0, 0.8, 0.5),                # beside the road
		Vector4(pad.x, pad.y, 0.8, 0.5),              # the pad
		Vector4(pad.x + 2.7, pad.y, 0.6, 0.4),        # the pad's sign
		Vector4(0.0, -70.0, 0.8, 0.5),                # the approach, on the road
		Vector4(-3.0, -72.0, 0.6, 0.4),               # the approach, off the road
		Vector4(60.0, 0.0, 0.8, 0.5),                 # not in the flats
		Vector4(0.0, -300.0, 0.8, 0.5),               # off the land
	]
	for rock: Vector4 in bad:
		if FrostDressing.clear(rock):
			return "A rock was allowed at %s" % rock
	for lamp: Vector2 in RoadLamps.spots(&"frost_flats"):
		if FrostDressing.clear(Vector4(lamp.x, lamp.y, 0.6, 0.4)):
			return "A rock was allowed on the lamp at %s" % lamp
	return ""


func test_rocks_sit_on_the_ground_and_stand_the_set_height() -> String:
	var dressing: FrostDressing = _dressed()
	var none: Dictionary[Vector2i, int] = {}
	if dressing.rock_count() != FrostDressing.spots().size():
		_cleanup()
		return "The scene has %d rocks, not %d" % [dressing.rock_count(), FrostDressing.spots().size()]
	var problem: String = ""
	for i: int in dressing.rock_count():
		var rock: Vector4 = FrostDressing.spots()[i]
		var node := dressing.get_child(i) as MeshInstance3D
		var top: float = node.position.y + node.scale.y
		var low: float = FrostDressing.ground_y(rock, none)
		if absf(top - (low + rock.w)) > 0.001:
			problem = "The rock at (%s, %s) tops out at %s, want %s" % [rock.x, rock.y, top, low + rock.w]
		if node.position.y - node.scale.y > low:
			problem = "The rock at (%s, %s) hangs in the air" % [rock.x, rock.y]
	_cleanup()
	return problem


func test_a_live_rock_follows_the_digging_and_comes_back() -> String:
	var dressing := FrostDressing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(dressing)
	var first: Vector4 = FrostDressing.spots()[0]
	var node := dressing.get_child(0) as Node3D
	var saved: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	var before: float = node.position.y
	GameState.dug = _nine_around(Vector2(first.x, first.y))
	GameState.terrain_changed.emit()
	var dropped: float = node.position.y
	GameState.dug = saved
	GameState.terrain_changed.emit()
	var back: float = node.position.y
	dressing.get_parent().remove_child(dressing)
	dressing.free()
	if not dropped < before:
		return "The rock did not drop after the cells under it were dug (%s, %s)" % [before, dropped]
	if not is_equal_approx(back, before):
		return "The rock did not come back after the digging was undone (%s, %s)" % [before, back]
	return ""


func test_a_rock_hides_under_stone_and_shows_again() -> String:
	var dressing := FrostDressing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(dressing)
	var first: Vector4 = FrostDressing.spots()[0]
	var saved: Dictionary[Vector2i, int] = GameState.stone_pieces.duplicate()
	var node := dressing.get_child(0) as Node3D
	var shown_at_first: bool = node.visible
	var piece: Dictionary[Vector2i, int] = {Terrain.cell_at(Vector2(first.x, first.y)): 0}
	GameState.stone_pieces = piece
	GameState.stone_changed.emit()
	var hidden: bool = not node.visible
	var others_shown: bool = dressing.is_shown(dressing.rock_count() - 1)
	GameState.stone_pieces = saved
	GameState.stone_changed.emit()
	var back: bool = node.visible
	dressing.get_parent().remove_child(dressing)
	dressing.free()
	if not shown_at_first:
		return "The rock was not showing to begin with"
	if not hidden:
		return "The rock still shows over a stone piece"
	if not others_shown:
		return "A rock far from the stone was hidden"
	if not back:
		return "The rock did not come back when the stone was taken up"
	return ""


func test_a_rock_is_dressing_only() -> String:
	var dressing: FrostDressing = _dressed()
	var problem: String = ""
	if not dressing.find_children("*", "CollisionObject3D", true, false).is_empty():
		problem = "A rock has collision"
	if not dressing.find_children("*", "Light3D", true, false).is_empty():
		problem = "A rock has a light"
	if not dressing.find_children("*", "Clickable", true, false).is_empty():
		problem = "A rock can be clicked"
	_cleanup()
	return problem


func test_the_road_still_shows_against_the_frost_ground() -> String:
	var ground := TerrainGround.new()
	var tint: Color = Color.WHITE.lerp(BiomeData.ground_tint(&"frost_flats"), TerrainGround.BIOME_STRENGTH)
	var worst: float = INF
	for height: float in [0.0, 1.0, 2.0, 3.0]:
		var plain: Color = ground._tint(height) * tint
		var road: Color = plain.lerp(TerrainGround.ROAD_TINT, TerrainGround.ROAD_STRENGTH)
		var seen: float = absf((plain.r - road.r) * SHADER_BASE.r) + absf((plain.g - road.g) * SHADER_BASE.g) + absf((plain.b - road.b) * SHADER_BASE.b)
		worst = minf(worst, seen)
	ground.free()
	if worst < MIN_ROAD_CONTRAST:
		return "The Frost road differs from its ground by only %.3f after the shader" % worst
	return ""
