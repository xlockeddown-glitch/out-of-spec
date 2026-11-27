class_name ZonePresence
extends RefCounted
## Where a player is (docs/design/zones.md section 12.2, build step 4): a place,
## which is "farm", "dome" or a zone id from data/zones.json, and a depth, 0 at
## the hub or entrance. Pure rules and words; the host's table of them lives in
## GameState (`player_places`). Nothing here is saved or sent.

const FARM: String = "farm"
const DOME: String = "dome"
## The deepest a report may say [PLACEHOLDER]: the deepest ZoneDepth generates.
const MAX_DEPTH: int = ZoneDepth.MAX_DEPTH
## The place of someone the host has not heard from: everyone starts on the farm.
const DEFAULT_PLACE: String = FARM
const NOT_YOURS: String = "A place is reported by the player who is there."


## True if `place` is the farm, the dome or a zone a player can be in (one with a
## scene, ZoneData.is_playable).
static func is_place(place: String) -> bool:
	return place == FARM or place == DOME or (place != "" and ZoneData.is_playable(StringName(place)))


## Why [place, depth] cannot be: the one rule for the host's command and for a
## guest checking the host's table. "" if it can.
static func place_problem(place: String, depth: int) -> String:
	if not is_place(place):
		return "'%s' is not a place." % place
	if depth < 0 or depth > MAX_DEPTH:
		return "Depth %d is out of range." % depth
	if depth > 0 and (place == FARM or place == DOME):
		return "The %s has no depth." % place
	return ""


## Why this report can't be taken, or "". `about` is whose place it says,
## `sender` who sent it (the connection's player, never the message's own word),
## `players` who is in the farm. The farm and the dome have no depth.
static func problem(place: String, depth: int, about: String, sender: String, players: Array[String]) -> String:
	if sender == "" or not sender in players:
		return "That player is not on this farm."
	if about != sender:
		return NOT_YOURS
	return place_problem(place, depth)


## [place, depth] for a scene, or an empty array for a scene that is no place
## (the title menu). The tunnels scene is the hub of whichever zone owns it.
static func for_scene(path: String) -> Array:
	if path == SceneSwitcher.FARM_SCENE:
		return [FARM, 0]
	if path == SceneSwitcher.DOME_SCENE:
		return [DOME, 0]
	for id: StringName in ZoneData.ids():
		if path != "" and ZoneData.hub_scene(id) == path:
			return [String(id), ZoneDepth.local_depth if String(id) == ZoneDepth.ZONE else 0]
	return []


## True if the scene `path` is a zone (not the farm, the dome, a moon's hub or a
## menu): where the 02:00 recall carries a player out of. A moon has its own way home
## (the shuttle: GameState.shuttle_home), free of charge.
static func in_zone(path: String) -> bool:
	var at: Array = for_scene(path)
	return not at.is_empty() and not at[0] in [FARM, DOME] and not Shuttle.is_moon(str(at[0]))


## What to send next: `latest` if it is not what the host last acknowledged, else
## nothing. Only the newest place is ever sent, so an older trip can never land
## after a newer one.
static func next_to_send(acknowledged: Array, latest: Array) -> Array:
	return latest if latest != acknowledged else []


const NO_ANSWER: String = "The host gave no answer."
const NOT_CONNECTED: String = "Not connected to the host."

static var _latest: Array = []
static var _acknowledged: Array = []
static var _sending: bool = false
## Bumped when a session starts or ends: a sender from before stops at its next
## step, so it never writes into the next session or the solo farm.
static var _session: int = 0
## Counts every scene report, so a repeat of the same place is still news.
static var _reports: int = 0


## A session started or ended: forget what the host took and what was waiting,
## and stop any sender still running.
static func forget_acknowledged() -> void:
	_acknowledged = []
	_latest = []
	_sending = false
	_session += 1


## Forgets what was said (tests).
static func reset_reports() -> void:
	_latest = []
	_acknowledged = []
	_sending = false
	_session += 1


## What the sender knows the host holds after one try of `sent`: the place when the
## host answered (taken or refused), else nothing, so the next place is always
## sent. Pure, for tests.
static func acknowledged_after(sent: Array, answer: Variant) -> Array:
	return [] if answer == NO_ANSWER else sent


## Says where this screen's player is, as the scene `path` gives it (nothing for a
## menu). Alone or as the host it is set at once; a guest asks the host. One
## sender runs at a time on its own wait flag (never the gameplay command's), and
## it keeps going until the newest place is acknowledged; a swap while it waits
## only replaces what it will send next. `tries` and `wait_s` bound the retries
## of one place the host did not answer; each new report starts its own count. A place
## counts as taken only when the host answered, so after a lost answer the next
## place is sent whatever it is. The sender stops when the session changes.
static func report_scene(path: String, tree: SceneTree, tries: int, wait_s: float) -> void:
	var at: Array = for_scene(path)
	if at.is_empty():
		return
	_latest = at
	_reports += 1
	if _sending:
		return
	_sending = true
	var session: int = _session
	var failed: int = 0
	var counted: int = -1
	while session == _session:
		var now: Array = next_to_send(_acknowledged, _latest)
		if now.is_empty():
			break
		if _reports != counted:
			# A new report since the last try (even the same place again, after a
			# trip there and back, or one made during a retry wait): fresh tries.
			counted = _reports
			failed = 0
		var answer: Variant = await FarmCommands.request(&"report_place", now)
		if session != _session or answer == NOT_CONNECTED:
			break
		_acknowledged = acknowledged_after(now, answer)
		if answer != NO_ANSWER:
			continue
		if _reports != counted:
			continue  # a new report came while this one waited: send it now
		if failed >= tries:
			# Given up on this place; the next swap sends again.
			_latest = []
			break
		failed += 1
		await tree.create_timer(wait_s).timeout
	# A sender from an ended session leaves the flag to the new session's sender.
	if session == _session:
		_sending = false


## A table of places the host sent, or "": a dictionary of player -> [place, depth].
## Only the shape is judged; who is real is the host's word.
static func table_problem(table: Variant) -> String:
	if not table is Dictionary:
		return "is not a dictionary"
	for player: Variant in table:
		var entry: Variant = table[player]
		if not player is String or not entry is Array or (entry as Array).size() != 2 \
				or not entry[0] is String or not entry[1] is int \
				or place_problem(entry[0], entry[1]) != "":
			return "has an entry that is not a place"
	return ""


## Plain words for a place: "Farm", "Dome", the zone's name, with ", depth N"
## below the hub.
static func label(place: String, depth: int = 0) -> String:
	var words: String = place.capitalize()
	if place != FARM and place != DOME and ZoneData.has_zone(StringName(place)):
		words = str(ZoneData.zone(StringName(place)).get("name", words))
	return words if depth <= 0 else "%s, depth %d" % [words, depth]
