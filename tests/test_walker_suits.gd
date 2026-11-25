extends RefCounted
## Each walking character's suit color, and its arms.


func _roster(ids: Array) -> Array[String]:
	var roster: Array[String] = []
	roster.assign(ids)
	return roster


func _lightness(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


func test_host_and_solo_stay_orange() -> String:
	var roster: Array[String] = _roster(["player_1", "player_2"])
	if WalkerModel.suit_for("player_1", roster) != WalkerModel.SUIT:
		return "the host is not orange"
	if WalkerModel.suit_for("player_1", _roster([])) != WalkerModel.SUIT:
		return "solo is not orange"
	var model := WalkerModel.new()
	var orange: bool = model.suit() == WalkerModel.SUIT
	model.free()
	if not orange:
		return "a new model is not orange"
	if WalkerModel.suit_for("player_2", roster) == WalkerModel.SUIT:
		return "a guest is orange"
	return ""


func test_everyone_differs() -> String:
	var roster: Array[String] = _roster(["player_1", "player_2", "player_3", "player_4"])
	var seen: Array[Color] = []
	for id: String in roster:
		var color: Color = WalkerModel.suit_for(id, roster)
		if color in seen:
			return "%s has a color already taken" % id
		seen.append(color)
	# Ids that all prefer the same color, as happens after guests come and go.
	roster = _roster(["player_1", "player_2", "player_6", "player_10"])
	seen.clear()
	for id: String in roster:
		var color: Color = WalkerModel.suit_for(id, roster)
		if color in seen:
			return "%s shares a color" % id
		seen.append(color)
	return ""


func test_a_full_roster_and_more_still_answers() -> String:
	var roster: Array[String] = _roster(["player_1", "player_2", "player_3", "player_4", "player_5", "player_6", "player_7"])
	for id: String in roster.slice(1):
		if not WalkerModel.suit_for(id, roster) in WalkerModel.GUEST_SUITS:
			return "%s has no guest suit" % id
	return ""


func test_leaving_gives_back_a_shared_preference() -> String:
	var after: Array[String] = _roster(["player_1", "player_6"])
	if WalkerModel.suit_for("player_6", _roster(["player_1", "player_2", "player_6"])) == WalkerModel.suit_for("player_6", after):
		return "player_6 had no need to give way"
	return "" if WalkerModel.suit_for("player_6", after) == WalkerModel.GUEST_SUITS[0] else "player_6 did not get its own suit back"


func test_leaving_recolors_nobody() -> String:
	var before: Array[String] = _roster(["player_1", "player_2", "player_3", "player_4"])
	var after: Array[String] = _roster(["player_1", "player_3", "player_4"])
	for id: String in after:
		if WalkerModel.suit_for(id, before) != WalkerModel.suit_for(id, after):
			return "%s changed color when player_2 left" % id
	return ""


func test_colors_are_safe() -> String:
	var banned: Array[Color] = [Color("#38e1c6"), Color("#f5a623"), Color("#ff5a5f")]
	var all: Array[Color] = [WalkerModel.SUIT]
	all.append_array(WalkerModel.GUEST_SUITS)
	# The host's orange is fixed by the brief; guests must keep clear of the HUD colors.
	for color: Color in WalkerModel.GUEST_SUITS:
		for ban: Color in banned:
			var gap: float = absf(color.r - ban.r) + absf(color.g - ban.g) + absf(color.b - ban.b)
			if gap < 0.5:
				return "%s is too near a HUD color" % color.to_html(false)
	# Lightness apart, for color-blind players.
	for i: int in all.size():
		for j: int in range(i + 1, all.size()):
			if absf(_lightness(all[i]) - _lightness(all[j])) < 0.08:
				return "suits %d and %d are alike in lightness" % [i, j]
	return ""


func test_set_suit_recolors_the_suit_only() -> String:
	var model := WalkerModel.new()
	model.set_suit(Color("#2b4fb0"))
	var suits: int = 0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var color: Color = (mesh.mesh as BoxMesh).material.albedo_color
		if color == Color("#2b4fb0"):
			suits += 1
		if color == WalkerModel.SUIT:
			return "an orange part is left"
	# Two legs, two arms, torso, head, and the shoulder pads are darker.
	if suits != 6:
		return "%d suit parts, expected 6" % suits
	var visor: bool = false
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		visor = visor or (mesh.mesh as BoxMesh).material.albedo_color == WalkerModel.VISOR
	model.free()
	return "" if visor else "the visor changed"


func test_arms_swing_against_legs() -> String:
	var model := WalkerModel.new()
	model.step(1.0)
	var legs: Array[MeshInstance3D] = model._legs
	var arms: Array[Node3D] = model._arms
	var problem: String = ""
	# Leg 0 forward is toward -z; its arm goes back, so its hand is at +z.
	if legs[0].position.z >= 0.0 or not (arms[0].transform * Vector3(0.0, -0.4, 0.0)).z > 0.0:
		problem = "arm 0 is not against leg 0"
	if (arms[1].transform * Vector3(0.0, -0.4, 0.0)).z >= 0.0:
		problem = "arm 1 is not against leg 1"
	model.step(0.0)
	if arms[0].rotation.x != 0.0 or arms[1].rotation.x != 0.0:
		problem = "arms do not rest when standing"
	model.free()
	return problem


func test_height_unchanged() -> String:
	var model := WalkerModel.new()
	var top: float = 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: BoxMesh = mesh.mesh as BoxMesh
		var at: float = mesh.position.y
		if mesh.get_parent() != model:
			at += (mesh.get_parent() as Node3D).position.y
		top = maxf(top, at + box.size.y / 2.0)
	model.free()
	if absf(top - 1.6) > 0.001:
		return "top is %f m, expected 1.6" % top
	return ""


func test_players_getting_out_together_try_different_spots() -> String:
	var firsts: Array[Vector3] = []
	for place: int in FarmWalkers.SPOTS.size():
		var spots: Array[Vector3] = FarmWalkers.spots_for(place)
		if spots[0] in firsts:
			return "two players try %s first" % spots[0]
		firsts.append(spots[0])
		for spot: Vector3 in FarmWalkers.SPOTS:
			if not spot in spots:
				return "player %d never tries %s" % [place, spot]
	if FarmWalkers.spots_for(-1) != FarmWalkers.SPOTS:
		return "solo tries them as before"
	var out: Dictionary = CoopWalkers.out.duplicate()
	CoopWalkers.out.clear()
	CoopWalkers.out["someone_else"] = [5.0, 0.0, 5.0, 0.0, 0.0]
	var problem: String = ""
	if not FarmWalkers._is_taken(Vector3(5, 0, 5)):
		problem = "a spot someone stands on is taken"
	elif FarmWalkers._is_taken(Vector3(7, 0, 5)):
		problem = "a spot 2 m from them is not"
	CoopWalkers.out.clear()
	CoopWalkers.out[GameState.local_player_id] = [5.0, 0.0, 5.0, 0.0, 0.0]
	if problem == "" and FarmWalkers._is_taken(Vector3(5, 0, 5)):
		problem = "one's own place is not taken"
	CoopWalkers.out.clear()
	CoopWalkers.out.merge(out)
	return problem
