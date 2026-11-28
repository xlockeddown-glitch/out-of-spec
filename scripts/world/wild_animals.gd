class_name WildAnimals
extends Node3D
## Cosmetic local farm animals, feeding spots and trust-4+ find markers.
## Positions are local and never synced; trust, feed, gifts and finds live in GameState.

## [PLACEHOLDER] Feeding spot positions by home_kind (outside PLOT [-12..12] and off roads).
const HOME_SPOTS: Dictionary = {
	"scrub": Vector3(-22.0, 0.0, 10.0),
	"plateau_rim": Vector3(-8.0, 0.0, -28.5),
	"gulch": Vector3(7.5, 0.0, -23.5),
}
## [PLACEHOLDER] Offset from each feeding spot to its trust-4+ find pickup.
const FIND_OFFSETS: Dictionary = {
	"scrub": Vector3(-2.4, 0.0, 1.8),
	"plateau_rim": Vector3(2.4, 0.0, 1.2),
	"gulch": Vector3(2.2, 0.0, 1.6),
}

## [PLACEHOLDER] Short interact verbs matching main_farm.gd wording style.
const VERB_FEED: String = "Leave feed"
const VERB_FIND: String = "Pick up find"

## [PLACEHOLDER] Movement and interaction tuning (metres, m/s, seconds).
const INTERACT_REACH_M: float = 3.5
const HOME_RADIUS_M: float = 3.5
const SHY_RADIUS_M: float = 5.0
const FLEE_LIMIT_M: float = 5.5
const FIND_LINGER_RADIUS_M: float = 1.2
const WANDER_SPEED_MPS: float = 0.7
const FLEE_SPEED_MPS: float = 1.8
const PAUSE_MIN_S: float = 2.0
const PAUSE_MAX_S: float = 5.0

var _dawn_hour: float = 4.5
var _dusk_hour: float = 19.5
var _rng := RandomNumberGenerator.new()

## group_id -> { spot_pos, find_pos, feed_mesh, gift_mesh, find_marker, animals: Array[Dictionary] }
var _groups: Dictionary = {}


func _ready() -> void:
	_dawn_hour = DataManager.get_number(&"day_night", "dawn_hour", 4.5)
	_dusk_hour = DataManager.get_number(&"day_night", "dusk_hour", 19.5)
	_rng.randomize()
	_build_groups()
	GameState.animals_changed.connect(refresh_markers)
	GameState.farm_loaded.connect(refresh_markers)
	refresh_markers()


func _build_groups() -> void:
	for group_id: String in GameState.animal_group_ids():
		var spec: Dictionary = GameState.animal_group(group_id)
		var home_kind: String = str(spec.get("home_kind", "scrub"))
		var spot_base: Vector3 = HOME_SPOTS.get(home_kind, HOME_SPOTS["scrub"]) as Vector3
		var find_off: Vector3 = FIND_OFFSETS.get(home_kind, Vector3(2.2, 0.0, 1.5)) as Vector3
		var spot_pos := Vector3(spot_base.x, Terrain.height(Vector2(spot_base.x, spot_base.z), GameState.dug), spot_base.z)
		var find_xz := Vector2(spot_base.x + find_off.x, spot_base.z + find_off.z)
		var find_pos := Vector3(find_xz.x, Terrain.height(find_xz, GameState.dug), find_xz.y)

		var group_root := Node3D.new()
		group_root.name = "Group_" + group_id
		add_child(group_root)

		var spot_parts: Dictionary = _make_feeding_spot(group_id, spot_pos)
		group_root.add_child(spot_parts["root"] as Node3D)

		var find_marker: Node3D = _make_find_marker(group_id, find_pos)
		group_root.add_child(find_marker)

		var animals: Array[Dictionary] = []
		var count: int = maxi(1, int(spec.get("group_size", 3)))
		var model_path: String = str(spec.get("model_path", ""))
		var model_scale: float = float(spec.get("model_scale", 0.1))
		var scene: PackedScene = load(model_path) as PackedScene if ResourceLoader.exists(model_path) else null

		for i: int in count:
			var angle: float = TAU * float(i) / float(count)
			var dist: float = 1.4 + 0.35 * float(i % 2)
			var ax: float = spot_pos.x + cos(angle) * dist
			var az: float = spot_pos.z + sin(angle) * dist
			var ay: float = Terrain.height(Vector2(ax, az), GameState.dug)
			var animal_node := Node3D.new()
			animal_node.name = "%s_%d" % [group_id, i]
			animal_node.position = Vector3(ax, ay, az)
			animal_node.rotation.y = angle
			if scene != null:
				var visual: Node = scene.instantiate()
				if visual is Node3D:
					(visual as Node3D).scale = Vector3.ONE * model_scale
					animal_node.add_child(visual)
				else:
					visual.free()
			group_root.add_child(animal_node)
			animals.append({
				"node": animal_node,
				"target": Vector2(ax, az),
				"pause_s": _rng.randf_range(0.5, PAUSE_MAX_S),
			})

		_groups[group_id] = {
			"spot_pos": spot_pos,
			"find_pos": find_pos,
			"spot_root": spot_parts["root"],
			"feed_mesh": spot_parts["feed"],
			"gift_mesh": spot_parts["gift"],
			"find_marker": find_marker,
			"animals": animals,
		}


func _make_feeding_spot(group_id: String, at: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.name = "FeedSpot_" + group_id
	root.position = at

	# Flat stone / low feeding slab (cosmetic only, no physics body).
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.52, 0.46, 0.40)
	stone_mat.roughness = 0.9
	var stone := MeshInstance3D.new()
	stone.name = "Stone"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.65
	cyl.bottom_radius = 0.72
	cyl.height = 0.12
	cyl.radial_segments = 12
	stone.mesh = cyl
	stone.material_override = stone_mat
	stone.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(stone)

	# Feed pile shown when fed today.
	var feed_mat := StandardMaterial3D.new()
	feed_mat.albedo_color = Color(0.76, 0.64, 0.32)
	feed_mat.roughness = 0.95
	var feed_mesh := MeshInstance3D.new()
	feed_mesh.name = "FeedPile"
	var pile := CylinderMesh.new()
	pile.top_radius = 0.22
	pile.bottom_radius = 0.42
	pile.height = 0.14
	pile.radial_segments = 10
	feed_mesh.mesh = pile
	feed_mesh.material_override = feed_mat
	feed_mesh.position = Vector3(0.0, 0.16, 0.0)
	feed_mesh.visible = false
	root.add_child(feed_mesh)

	# Gift indicator shown when dawn gifts are waiting.
	var gift_mat := StandardMaterial3D.new()
	gift_mat.albedo_color = Color(0.95, 0.90, 0.78)
	gift_mat.emission_enabled = true
	gift_mat.emission = Color(0.92, 0.78, 0.42)
	gift_mat.emission_energy_multiplier = 0.8
	var gift_mesh := MeshInstance3D.new()
	gift_mesh.name = "GiftBundle"
	var gift_box := SphereMesh.new()
	gift_box.radius = 0.22
	gift_box.height = 0.34
	gift_mesh.mesh = gift_box
	gift_mesh.material_override = gift_mat
	gift_mesh.position = Vector3(0.28, 0.24, 0.0)
	gift_mesh.visible = false
	root.add_child(gift_mesh)

	return { "root": root, "feed": feed_mesh, "gift": gift_mesh }


func _make_find_marker(group_id: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "FindMarker_" + group_id
	root.position = at
	root.visible = false

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.88, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.22, 0.88, 0.78)
	mat.emission_energy_multiplier = 1.4
	var crystal := MeshInstance3D.new()
	crystal.name = "Crystal"
	var prism := CylinderMesh.new()
	prism.top_radius = 0.04
	prism.bottom_radius = 0.24
	prism.height = 0.65
	prism.radial_segments = 6
	crystal.mesh = prism
	crystal.material_override = mat
	crystal.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(crystal)
	return root


func refresh_markers() -> void:
	for group_id: String in _groups:
		var g: Dictionary = _groups[group_id]
		(g["feed_mesh"] as Node3D).visible = GameState.animal_fed_today(group_id)
		(g["gift_mesh"] as Node3D).visible = GameState.animal_gifts_waiting(group_id) > 0
		(g["find_marker"] as Node3D).visible = GameState.animal_find_pending(group_id)


func keep_above_ground() -> void:
	for group_id: String in _groups:
		var g: Dictionary = _groups[group_id]
		var spot: Vector3 = g["spot_pos"]
		spot.y = Terrain.height(Vector2(spot.x, spot.z), GameState.dug)
		g["spot_pos"] = spot
		(g["spot_root"] as Node3D).position = spot
		var fpos: Vector3 = g["find_pos"]
		fpos.y = Terrain.height(Vector2(fpos.x, fpos.z), GameState.dug)
		g["find_pos"] = fpos
		(g["find_marker"] as Node3D).position = fpos
		for entry: Dictionary in g["animals"]:
			var node := entry["node"] as Node3D
			node.position.y = Terrain.height(Vector2(node.position.x, node.position.z), GameState.dug)


func _collect_verb(group_id: String) -> String:
	var spec: Dictionary = GameState.animal_group(group_id)
	var gift_label: String = str(spec.get("gift_plural", spec.get("gift_name", "gifts"))).to_lower()
	return "Collect " + gift_label


func _weigh_verb(group_id: String) -> String:
	var spec: Dictionary = GameState.animal_group(group_id)
	var singular: String = str(spec.get("singular", spec.get("name", group_id))).to_lower()
	return "Weigh " + singular


## Returns { kind, group_id, at, verb } for the closest trusting animal group
## within INTERACT_REACH_M of `player_pos` while the wildlife survey quest is
## active and today's weighing has not yet been logged, or {} otherwise.
func weigh_target(player_pos: Vector3) -> Dictionary:
	if not GameState.wildlife_survey_active() or GameState.animal_weighed_today():
		return {}
	var approach_min: int = int(GameState.animal_trust_rule("approach_min", 1.0))
	var best: Dictionary = {}
	var best_dist: float = INTERACT_REACH_M
	var p2 := Vector2(player_pos.x, player_pos.z)
	for group_id: String in _groups:
		if GameState.animal_trust(group_id) < approach_min:
			continue
		var g: Dictionary = _groups[group_id]
		var spot: Vector3 = g["spot_pos"]
		var sdist: float = p2.distance_to(Vector2(spot.x, spot.z))
		if sdist <= best_dist:
			best_dist = sdist
			best = { "kind": "weigh", "group_id": group_id, "at": spot, "verb": _weigh_verb(group_id) }
		for entry: Dictionary in g["animals"]:
			var node := entry["node"] as Node3D
			var adist: float = p2.distance_to(Vector2(node.position.x, node.position.z))
			if adist <= best_dist:
				best_dist = adist
				best = { "kind": "weigh", "group_id": group_id, "at": node.position, "verb": _weigh_verb(group_id) }
	return best


## Returns { kind, group_id, at, verb } for the closest actionable feeding spot
## or pending find within INTERACT_REACH_M of `player_pos`, or {} if none is in reach.
func interact_target(player_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INTERACT_REACH_M
	var p2 := Vector2(player_pos.x, player_pos.z)
	for group_id: String in _groups:
		var g: Dictionary = _groups[group_id]
		if GameState.animal_find_pending(group_id):
			var fpos: Vector3 = g["find_pos"]
			var fdist: float = p2.distance_to(Vector2(fpos.x, fpos.z))
			if fdist <= best_dist:
				best_dist = fdist
				best = { "kind": "find", "group_id": group_id, "at": fpos, "verb": VERB_FIND }
		var spot: Vector3 = g["spot_pos"]
		var sdist: float = p2.distance_to(Vector2(spot.x, spot.z))
		if sdist <= best_dist:
			if GameState.animal_gifts_waiting(group_id) > 0:
				best_dist = sdist
				best = {
					"kind": "collect",
					"group_id": group_id,
					"at": spot,
					"verb": _collect_verb(group_id),
				}
			elif not GameState.animal_fed_today(group_id):
				best_dist = sdist
				best = {
					"kind": "feed",
					"group_id": group_id,
					"at": spot,
					"verb": VERB_FEED,
				}
	return best


func is_night() -> bool:
	var hour: float = GameClock.get_hour()
	return hour < _dawn_hour or hour >= _dusk_hour


func _process(delta: float) -> void:
	if is_night():
		return
	var player_pos: Vector3 = GameState.standing_at(GameState.local_player_id)
	var player_xz := Vector2(player_pos.x, player_pos.z)
	var approach_min: int = int(GameState.animal_trust_rule("approach_min", 1.0))

	for group_id: String in _groups:
		var g: Dictionary = _groups[group_id]
		var spot_xz := Vector2((g["spot_pos"] as Vector3).x, (g["spot_pos"] as Vector3).z)
		var find_xz := Vector2((g["find_pos"] as Vector3).x, (g["find_pos"] as Vector3).z)
		var shy: bool = GameState.animal_trust(group_id) < approach_min
		var has_find: bool = GameState.animal_find_pending(group_id)

		for entry: Dictionary in g["animals"]:
			var node := entry["node"] as Node3D
			var pos := Vector2(node.position.x, node.position.z)
			var move := Vector2.ZERO

			if shy and pos.distance_to(player_xz) < SHY_RADIUS_M:
				var away: Vector2 = pos - player_xz
				if away.length_squared() < 0.001:
					away = Vector2.RIGHT
				var step: Vector2 = away.normalized() * FLEE_SPEED_MPS * delta
				var next: Vector2 = pos + step
				var from_home: Vector2 = next - spot_xz
				if from_home.length() > FLEE_LIMIT_M:
					next = spot_xz + from_home.normalized() * FLEE_LIMIT_M
				move = next - pos
				pos = next
			else:
				var anchor: Vector2 = find_xz if has_find else spot_xz
				var radius: float = FIND_LINGER_RADIUS_M if has_find else HOME_RADIUS_M
				var target: Vector2 = entry["target"]
				if target.distance_to(anchor) > radius + 0.25:
					target = _pick_target(anchor, radius)
					entry["target"] = target
				var to_target: Vector2 = target - pos
				if to_target.length() <= 0.15:
					var pause: float = float(entry["pause_s"]) - delta
					if pause <= 0.0:
						entry["target"] = _pick_target(anchor, radius)
						entry["pause_s"] = _rng.randf_range(PAUSE_MIN_S, PAUSE_MAX_S)
					else:
						entry["pause_s"] = pause
				else:
					var step_len: float = minf(to_target.length(), WANDER_SPEED_MPS * delta)
					move = to_target.normalized() * step_len
					pos += move

			if move.length_squared() > 0.00001:
				node.rotation.y = atan2(move.x, move.y)
			node.position = Vector3(pos.x, Terrain.height(pos, GameState.dug), pos.y)


func _pick_target(center: Vector2, radius: float) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	var dist: float = sqrt(_rng.randf()) * radius
	return center + Vector2(cos(angle), sin(angle)) * dist
