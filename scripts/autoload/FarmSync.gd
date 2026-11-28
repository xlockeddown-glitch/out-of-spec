class_name FarmSync
extends RefCounted
## The host's farm as bytes, and a guest's copy of it. Nothing here sends them.
##
## The bytes are a save's: the same data, checks, version and hash. A guest only
## shows its copy: FarmCommands.guest must be true, so its clock and rover leave
## the copy alone and it is never written to a save file.

## A bigger farm is neither sent nor read [ASSUMPTION].
const MAX_BYTES: int = 4 * 1024 * 1024
## A guest's choices: the host's start them, and later ones don't replace them.
const OWN: Array[String] = ["seed_crop_id", "planting_offset_steps"]
const SENDER: String = "The host's farm"

## Each signal is emitted when one of these variables changed.
const SHOWN_BY: Dictionary = {
	&"lab_xp_changed": ["lab_xp"],
	&"quests_changed": ["quest_state", "quest_points", "player_quest_state"],
	&"xp_certificates_changed": ["xp_certificates", "xp_certificates_spent"],
	&"one_use_changed": ["one_use_held"],
	&"molt_changed": ["dome_species_id", "molt_progress", "molt_stage", "exuvia_until_day"],
	&"enclosures_changed": ["enclosures", "enclosure_origins"],
	&"strays_changed": ["strays_caught"],
	&"deimos_cache_changed": ["deimos_cache"],
	&"silk_changed": ["optical_silk_spools", "_spool_species", "_spool_damaged"],
	&"relay_changed": ["relay_slotted", "slotted_spool_species", "slotted_spool_damaged"],
	&"credits_changed": ["credits"],
	&"drop_pod_changed": ["drop_pod_present"],
	&"ore_changed": ["crystal_ore"],
	&"fissures_changed": ["mined_fissures"],
	&"upgrades_changed": ["has_wide_treads", "has_ice_studs", "owned_standards", "tier1_unlocked", "traceable_lab"],
	&"oirm_changed": ["at_oirm", "oirm_trips", "certificate_log", "suspect_units", "_untraceable_since_cal"],
	&"credibility_changed": ["credibility", "_best_band", "contract_state", "contract_run"],
	&"crops_changed": ["plantings", "harvest_bin"],
	&"jobs_changed": ["job_board", "active_jobs", "job_log", "_board_day"],
	&"lab_changed": ["lab_size", "lab_areas", "lab_areas_paid", "lab_build", "lab_layout"],
	&"robots_changed": ["robots"],
	&"terrain_changed": ["dug"],
	&"pit_seep_changed": ["pit_seep"],
	&"boulders_changed": ["boulder_hits"],
	&"blocks_changed": ["found_blocks"],
	&"pockets_changed": ["found_pockets", "new_pockets", "pocket_pending"],
	&"stone_changed": ["stone", "stone_pieces"],
	&"rover_place_changed": ["rover_zone", "rover_depth", "rover_epoch", "rover_lent", "zones_unlocked"],
	&"sentinel_changed": ["sentinel_out", "sentinel_days_unseen"],
	&"rover_lights_changed": ["rover_lights"],
	&"beacons_changed": ["beacons_placed"],
	&"finds_changed": ["finds_taken"],
	&"pump_changed": ["pump_owned", "pools_drained", "valves_shut"],
	&"mine_changed": ["mine_gate_open", "mine_props", "rooms_shored"],
	&"ice_changed": ["cold_since"],
	&"camps_changed": ["camps_open", "camp_supplies"],
	&"lifts_changed": ["lifts_repaired", "deepest_depth"],
	&"lab_sitter_changed": ["lab_sitter"],
	&"shuttle_license_changed": ["shuttle_licensed"],
	&"shuttle_trips_changed": ["shuttle_trips"],
	&"wheels_changed": ["wheel_meters"],
	&"loadouts_changed": ["player_loadouts"],
}
## These also show the day.
const SHOW_THE_DAY: Array[StringName] = [&"molt_changed", &"enclosures_changed", &"fissures_changed", &"jobs_changed"]
## The variables some of them carry.
const CARRIES: Dictionary = {
	&"molt_changed": ["molt_progress", "molt_stage"], &"silk_changed": ["optical_silk_spools"],
	&"relay_changed": ["relay_slotted"], &"credits_changed": ["credits"],
	&"drop_pod_changed": ["drop_pod_present"], &"ore_changed": ["crystal_ore"],
	&"credibility_changed": ["credibility"],
}


## On the host: the farm for a guest. Empty means only that it is over MAX_BYTES,
## which the caller must say: the farm still saves, but can't be shared. Not from
## inside a GameState or GameClock signal, where a change may be half made.
static func capture(farm: Node = GameState) -> PackedByteArray:
	SaveGame.saving.emit()  # rovers say where they are
	var bytes: PackedByteArray = SaveGame.to_bytes({ "clock": clock(farm), "farm": farm.farm_to_dict() })
	if bytes.size() > MAX_BYTES:
		return PackedByteArray()
	return bytes


## On the host: its clock alone, small enough to send often.
static func clock(farm: Node = GameState) -> Dictionary:
	return {
		"elapsed_days": GameClock.elapsed_days,
		"seconds_per_day": GameClock.seconds_per_day,
		"paused": GameClock.paused,
		"in_bed": Array(CoopBeds.in_bed, TYPE_NIL, &"", null),
		"places": farm.player_places.duplicate(true),
	}


## On a guest: takes the host's clock(). Returns "" or why not.
static func follow_clock(data: Dictionary, farm: Node = GameState) -> String:
	if not FarmCommands.guest:
		return "Only a guest follows the host's clock."
	var problem: String = _clock_problem(data)
	if problem == "" and _follow(data, farm):
		for shown: StringName in SHOW_THE_DAY:
			_emit(farm, shown)
	return problem


## True if the day changed.
static func _follow(data: Dictionary, farm: Node = GameState) -> bool:
	var day: int = GameClock.get_day_index()
	GameClock.follow(data["elapsed_days"], data["seconds_per_day"], data["paused"])
	CoopBeds.in_bed.assign(data["in_bed"])
	_follow_places(data, farm)
	return GameClock.get_day_index() != day


## Where everyone is, as the host has it (an older clock has none).
static func _follow_places(data: Dictionary, farm: Node) -> void:
	farm.player_places = (data["places"] as Dictionary).duplicate(true) if data.has("places") else {}


## On a guest, joining: takes the whole farm, as a load would. Scenes must
## reload afterward. Returns "" or why not; on a problem nothing changes.
static func join(bytes: PackedByteArray, farm: Node = GameState) -> String:
	var got: Dictionary = _read(bytes)
	if got.has("problem"):
		return got["problem"]
	# The farm this machine had open is no longer the one in memory, so it must
	# not be saved over, even after leaving.
	SaveGame.farm_open = false
	GameClock.elapsed_days = got["data"]["clock"]["elapsed_days"]
	_follow(got["data"]["clock"], farm)
	farm.farm_from_dict(got["data"]["farm"])
	# Loading a farm forgets everyone's place; the host's word comes back.
	_follow_places(got["data"]["clock"], farm)
	_renew_relay_certificates(farm)
	return ""


## On a guest, playing: takes the farm's changes and shows only them. Lines and
## results new since the last one are shown once; nothing is run. Returns "" or
## why not; on a problem nothing changes.
static func update(bytes: PackedByteArray, farm: Node = GameState) -> String:
	var got: Dictionary = _read(bytes)
	if got.has("problem"):
		return got["problem"]
	var before: Dictionary = farm.farm_to_dict()
	var levels: Dictionary = _levels(farm)
	# What this player will plant next is their own.
	for field: String in OWN:
		got["data"]["farm"][field] = farm.get(field)
	# The clock first, so listeners see the host's day.
	var new_day: bool = _follow(got["data"]["clock"], farm)
	farm.put_farm(got["data"]["farm"])
	_renew_relay_certificates(farm)
	_show_changes(farm, before, new_day)
	_show_news(farm, before, levels)
	return ""


## { data }, or { problem }. Changes nothing.
static func _read(bytes: PackedByteArray) -> Dictionary:
	if not FarmCommands.guest:
		return { "problem": "Only a guest takes the host's farm." }
	if bytes.size() > MAX_BYTES:
		return { "problem": "%s is too big (%d bytes)." % [SENDER, bytes.size()] }
	var got: Dictionary = SaveGame.from_bytes(bytes, SENDER)
	if got.has("problem"):
		return got
	# The guest converts nothing (GameState.put_farm), so a farm on another skill
	# curve would be read wrongly. The protocol number stops this first.
	if (got["data"]["farm"] as Dictionary).get("skill_curve") != GameState.SKILL_CURVE:
		return { "problem": CoopSession.REASONS["version"] }
	var problem: String = _clock_problem(got["data"]["clock"])
	return got if problem == "" else { "problem": problem }


static func _clock_problem(data: Dictionary) -> String:
	for key: String in ["elapsed_days", "seconds_per_day"]:
		var value: Variant = data.get(key)
		if typeof(value) != TYPE_FLOAT or not is_finite(value) or value < 0.0:
			return "The host's clock has a bad '%s'." % key
	var in_bed: Variant = data.get("in_bed")
	if typeof(in_bed) != TYPE_ARRAY or (in_bed as Array).any(func(id: Variant) -> bool: return typeof(id) != TYPE_STRING):
		return "The host's clock has a bad 'in_bed'."
	if data.has("places") and ZonePresence.table_problem(data["places"]) != "":
		return "The host's clock has bad 'places'."
	return "" if data.get("paused") is bool else "The host's clock has a bad 'paused'."


## The relay renews these without a new certificate, so the log a guest rebuilds
## them from has the old date. The sensor has the new one.
static func _renew_relay_certificates(farm: Node) -> void:
	for id: String in farm.standard_ids():
		var sensor: DriftingSensor = farm.sensors[id]
		if sensor.relay_disciplined and farm.certificates.has(id):
			# A copy: the certificate log keeps the one that was issued.
			farm.certificates[id] = farm.certificates[id].duplicate()
			farm.certificates[id]["due_day"] = sensor.cal_due_day


static func _show_changes(farm: Node, before: Dictionary, new_day: bool) -> void:
	for cell: Variant in farm.tilled_cells:
		if cell is Vector3i and not before["tilled_cells"].has(cell):
			farm.soil_tilled.emit(cell)
	var levels_moved: bool = _levels_moved(farm, before)
	for shown: StringName in SHOWN_BY:
		var changed: bool = (new_day and shown in SHOW_THE_DAY) or (levels_moved and shown == &"terrain_changed")
		for field: String in SHOWN_BY[shown]:
			changed = changed or farm.get(field) != before[field]
		if changed:
			if shown == &"rover_place_changed":
				farm.rover_place_scope = _place_scope(farm, before)  # as the host's own emit says it
				_emit(farm, shown)
				farm.rover_place_scope = ""
			else:
				_emit(farm, shown)


## Which rover a rover_place_changed is about, worked out from what moved: the farm
## rover going out or coming home touches every rover (""); a zone's field rover
## starting, going or changing depth touches the zone's alone; only a new unlock
## touches none (a name no rover has).
static func _place_scope(farm: Node, before: Dictionary) -> String:
	if farm.rover_lent != before["rover_lent"]:
		return ""
	for field: String in ["rover_zone", "rover_depth", "rover_epoch"]:
		if farm.get(field) != before[field]:
			return farm.TUNNEL_ROVER
	return "unlock"


## True if the pads level the ground differently than they did: the ground is not
## a saved variable, it is worked out from the pieces and the digging, so a guest
## is told "the terrain changed" when a pad came or went.
static func _levels_moved(farm: Node, before: Dictionary) -> bool:
	if farm.stone_pieces == before["stone_pieces"] and farm.dug == before["dug"]:
		return false
	return _pad_levels(farm.stone_pieces, farm.dug) != _pad_levels(before["stone_pieces"], before["dug"])


static func _pad_levels(pieces: Dictionary, dug: Dictionary) -> Dictionary[Vector2i, float]:
	var typed_pieces: Dictionary[Vector2i, int] = {}
	typed_pieces.assign(pieces)
	var typed_dug: Dictionary[Vector2i, int] = {}
	typed_dug.assign(dug)
	return Terrain.pad_levels(StonePieces.pad_cells(typed_pieces), typed_dug)


static func _emit(farm: Node, shown: StringName) -> void:
	var carried: Array = CARRIES.get(shown, []).map(func(field: String) -> Variant: return farm.get(field))
	farm.callv(&"emit_signal", [shown] + carried)


static func _show_news(farm: Node, before: Dictionary, levels: Dictionary) -> void:
	for record: Dictionary in farm.cal_log.slice(before["cal_log"].size()):
		farm.calibration_recorded.emit(record)
	# In the host's order: a line posted after an audit is shown after it. The
	# phone keeps only its last lines.
	var number: int = farm.phone_count - mini(farm.phone_log.size(), maxi(farm.phone_count - before["phone_count"], 0))
	var reports: Array = farm.audit_log.slice(before["audit_log"].size())
	while number < farm.phone_count or not reports.is_empty():
		if not reports.is_empty() and reports[0].get("phone_count", 0) <= number:
			farm.audit_completed.emit(reports.pop_front())
		elif number < farm.phone_count:
			farm.phone_message.emit(farm.phone_log[number - farm.phone_count])
			number += 1
		else:
			farm.audit_completed.emit(reports.pop_front())
	var now: Dictionary = _levels(farm)
	for owned: Array in now:
		var was: Array = levels.get(owned, [0, 1])
		if now[owned][0] != was[0]:
			farm.skill_xp_changed.emit(owned[0], owned[1])
		if now[owned][1] > was[1]:
			farm.skill_leveled.emit(owned[0], owned[1], now[owned][1])


## [player id, or "" for the farm, skill id] -> [XP, level].
static func _levels(farm: Node) -> Dictionary:
	var out: Dictionary = {}
	for skill: String in farm.skill_ids():
		var owners: Array = [""] if farm.is_farm_skill(skill) else farm.player_skill_xp.keys()
		for player: String in owners:
			out[[player, skill]] = [farm.skill_xp(skill, player), farm.skill_level(skill, player)]
	return out
