class_name ZonePresence
extends RefCounted
## Where a player is (docs/design/zones.md section 12.2, build step 4): a place,
## which is "farm", "dome" or a zone id from data/zones.json, and a depth, 0 at
## the hub or entrance. Pure rules and words; the host's table of them lives in
## GameState (`player_places`). Nothing here is saved or sent.

const FARM: String = "farm"
const DOME: String = "dome"
## The deepest a report may say [PLACEHOLDER]. Only depth 0 exists today.
const MAX_DEPTH: int = 12
## The place of someone the host has not heard from: everyone starts on the farm.
const DEFAULT_PLACE: String = FARM
const NOT_YOURS: String = "A place is reported by the player who is there."


## True if `place` is the farm, the dome or a zone in data/zones.json.
static func is_place(place: String) -> bool:
	return place == FARM or place == DOME or (place != "" and ZoneData.has_zone(StringName(place)))


## Why this report can't be taken, or "". `about` is whose place it says,
## `sender` who sent it (the connection's player, never the message's own word),
## `players` who is in the farm. The farm and the dome have no depth.
static func problem(place: String, depth: int, about: String, sender: String, players: Array[String]) -> String:
	if sender == "" or not sender in players:
		return "That player is not on this farm."
	if about != sender:
		return NOT_YOURS
	if not is_place(place):
		return "'%s' is not a place." % place
	if depth < 0 or depth > MAX_DEPTH:
		return "Depth %d is out of range." % depth
	if depth > 0 and (place == FARM or place == DOME):
		return "The %s has no depth." % place
	return ""


## [place, depth] for a scene, or an empty array for a scene that is no place
## (the title menu). The tunnels scene is the hub of whichever zone owns it.
static func for_scene(path: String) -> Array:
	if path == SceneSwitcher.FARM_SCENE:
		return [FARM, 0]
	if path == SceneSwitcher.DOME_SCENE:
		return [DOME, 0]
	for id: StringName in ZoneData.ids():
		if path != "" and ZoneData.hub_scene(id) == path:
			return [String(id), 0]
	return []


## Says where this screen's player is, as the scene `path` gives it (nothing for a
## menu). Alone or as the host it is set at once; a guest asks the host, trying
## again while an earlier command of its own is still unanswered.
static func report_scene(path: String, tree: SceneTree, tries: int, wait_s: float) -> void:
	var at: Array = for_scene(path)
	if at.is_empty():
		return
	for _try: int in tries:
		var answer: Variant = await FarmCommands.request(&"report_place", at)
		if answer != "Still waiting for the host.":
			return
		await tree.create_timer(wait_s).timeout


## A table of places the host sent, or "": a dictionary of player -> [place, depth].
## Only the shape is judged; who is real is the host's word.
static func table_problem(table: Variant) -> String:
	if not table is Dictionary:
		return "is not a dictionary"
	for player: Variant in table:
		var entry: Variant = table[player]
		if not player is String or not entry is Array or (entry as Array).size() != 2 \
				or not entry[0] is String or not entry[1] is int \
				or not is_place(entry[0]) or entry[1] < 0 or entry[1] > MAX_DEPTH:
			return "has an entry that is not a place"
	return ""


## Plain words for a place: "Farm", "Dome", the zone's name, with ", depth N"
## below the hub.
static func label(place: String, depth: int = 0) -> String:
	var words: String = place.capitalize()
	if place != FARM and place != DOME and ZoneData.has_zone(StringName(place)):
		words = str(ZoneData.zone(StringName(place)).get("name", words))
	return words if depth <= 0 else "%s, depth %d" % [words, depth]
