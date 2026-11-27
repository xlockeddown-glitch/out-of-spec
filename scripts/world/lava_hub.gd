class_name LavaHub
extends RefCounted
## The Lava Tubes hub (docs/design/zones.md section 13, build step 5): Orin's
## beacon rack by the tunnel mouth, the notice board, and the beacon spots deeper
## in the tunnels. Pure rules and words; the props are in LavaHubProps and the
## placed beacons are GameState's (`beacons_placed`, saved). Every number and
## name here is a [PLACEHOLDER].

## The zone these belong to (data/zones.json).
const ZONE: String = "lava_tubes"
## Floor cells of TunnelRock.MAP, by spot id. The ids are kept in saves and must
## never be renamed. Each is a floor cell, and none is on the way in.
const SPOTS: Dictionary[String, Vector2i] = {
	"spot_west": Vector2i(8, 11),
	"spot_east": Vector2i(17, 9),
	"spot_north": Vector2i(5, 4),
}
## Cells the rack and the board stand in, near the tunnel mouth.
const RACK_CELL := Vector2i(13, 18)
const BOARD_CELL := Vector2i(8, 18)
## How near the rover must be to use one [PLACEHOLDER]. A cell is 3 m wide.
const REACH_M: float = 4.0
## Extra metres the host allows on top of REACH_M [PLACEHOLDER]: the reliable place
## command can arrive before the guest's latest (unreliable) rover position does.
const HOST_REACH_SLACK_M: float = 1.5
## The quest that hands out the beacons (data/quests.json).
const QUEST: String = "beacon_run"
## What `nearest` calls what it found.
const RACK: String = "rack"
const BOARD: String = "board"
const SPOT: String = "spot"


static func spot_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(SPOTS.keys())
	return ids


static func spot_position(spot_id: String) -> Vector3:
	return TunnelRock.at(SPOTS[spot_id])


static func rack_position() -> Vector3:
	return TunnelRock.at(RACK_CELL)


static func board_position() -> Vector3:
	return TunnelRock.at(BOARD_CELL)


## Why `spot_id` can't take a beacon from a player in `place`, or "". `placed`
## is the spots that have one. The one rule for the host's command and a saved
## farm; nearness is the player's own screen's to see.
static func place_problem(spot_id: String, placed: Array, place: String) -> String:
	if place != ZONE:
		return "Beacons go down in the Lava Tubes."
	if not SPOTS.has(spot_id):
		return "'%s' is not a beacon spot." % spot_id
	if spot_id in placed:
		return "There is a beacon at that spot already."
	return ""


## Why a beacon can't go down from where the farm's rover is, or "". `zone` is
## GameState.rover_zone, `known` whether the host has the tunnel rover's place, and
## `at` that place. The host's copy of the rover decides, not the player's word.
static func reach_problem(spot_id: String, zone: String, known: bool, at: Vector3) -> String:
	if zone != ZONE or not known:
		return "The rover is not in the Lava Tubes."
	var there: Vector3 = spot_position(spot_id)
	if Vector2(there.x - at.x, there.z - at.z).length() > REACH_M + HOST_REACH_SLACK_M:
		return "The rover is too far from that spot."
	return ""


## Why Orin's beacons can't be set down yet, or "": the farm has not taken Beacon
## Run, or it is done. `quest_state` is GameState.quest_state.
static func job_problem(quest_state: Dictionary) -> String:
	var entry: Variant = quest_state.get(QUEST)
	if not entry is Dictionary or not entry.get("steps_done") is Array:
		return "Take the job from the notice board first."
	if int(entry.get("done", -1)) >= 0:
		return "Orin has all the beacons he needs."
	return ""


## Why a saved farm's quest steps can't stand beside its beacons, or "": a quest
## step that checks `beacons_placed` marked done with fewer beacons than it needs.
static func steps_problem(quests: Array, quest_state: Variant, placed: int) -> String:
	if not quest_state is Dictionary:
		return ""
	for quest: Variant in quests:
		if not quest is Dictionary or not quest.get("steps") is Array:
			continue
		var entry: Variant = quest_state.get(str(quest.get("id", "")))
		if not entry is Dictionary:
			continue
		# A finished Beacon Run needs all its beacons down: with fewer, the spots
		# could never be filled again (job_problem refuses a done run).
		# A `done` that is not a number is the quest validator's to report.
		var done: Variant = entry.get("done", -1)
		if str(quest.get("id", "")) == QUEST and (done is int or done is float) \
				and int(done) >= 0 and placed < SPOTS.size():
			return "'%s' is done and its beacons are not all placed." % QUEST
		if not entry.get("steps_done") is Array:
			continue
		for step: Variant in quest["steps"]:
			if step is Dictionary and str(step.get("check", "")) == "beacons_placed" \
					and str(step.get("id", "")) in entry["steps_done"] and placed < QuestEngine.step_need(step):
				return "'%s' says its beacons are placed and they are not." % str(quest.get("id", ""))
	return ""


## Why a farm's `placed` list can't be: a spot that is not one, or twice. "" if fine.
static func placed_problem(placed: Array) -> String:
	var seen: Array[String] = []
	for entry: Variant in placed:
		if not entry is String or not SPOTS.has(entry):
			return "'beacons_placed' has a spot that is not one."
		if entry in seen:
			return "'beacons_placed' has a spot twice."
		seen.append(entry)
	return ""


## What a rover at `at` can use: { "kind": RACK, BOARD or SPOT, "id": spot id or
## "" } for the nearest one within REACH_M, or {}. A spot that has a beacon is
## nothing to use.
## `only_spots` leaves the rack and the board out (a holder of a beacon asking
## whether an empty spot is in reach).
static func nearest(at: Vector3, placed: Array, only_spots: bool = false) -> Dictionary:
	var found: Dictionary = {}
	var best: float = REACH_M
	var options: Array[Dictionary] = []
	if not only_spots:
		options.append({ "kind": RACK, "id": "", "at": rack_position() })
		options.append({ "kind": BOARD, "id": "", "at": board_position() })
	for spot_id: String in SPOTS:
		if not spot_id in placed:
			options.append({ "kind": SPOT, "id": spot_id, "at": spot_position(spot_id) })
	for option: Dictionary in options:
		var there: Vector3 = option["at"]
		var away: float = Vector2(there.x - at.x, there.z - at.z).length()
		if away <= best:
			best = away
			found = { "kind": option["kind"], "id": option["id"] }
	return found


## The board's lines: each quest of this zone (data/quests.json `zone`) as not
## offered yet, accepted with its next step, or done. Quests are accepted when
## they are offered, so the board has no separate "offered". Reading only:
## nothing here accepts anything. `placed` is how many beacons are down.
static func board_lines(quests: Array, farm_state: Dictionary, own_state: Dictionary, placed: int) -> Array[String]:
	return NoticeBoard.lines(quests, farm_state, own_state, "zone", ZONE, placed)
