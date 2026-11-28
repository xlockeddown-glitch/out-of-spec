extends Node
## Live simulation state that must survive scene swaps. Autoloaded as `GameState`.
##
## Scenes read from and write to this; they never own sensor/molt/inventory
## state themselves. Ticks on GameClock, so the dome keeps simulating while
## you're on the farm and vice versa.

signal molt_changed(progress: float, stage: int)
signal silk_changed(spools: int)
## A tarantula was caught, or one in a tank of its own molted or gave its spool.
signal enclosures_changed
## The Cobalt Sentinel came out in the tunnels, or is gone.
signal sentinel_changed
signal strays_changed  # a Phobos service-tunnel stray was caught today
signal deimos_cache_changed  # the Deimos smuggler cache was opened today
signal rover_lights_changed
## A beacon was set down in the Lava Tubes.
signal beacons_changed
## A find was taken below the Lava Tubes.
signal finds_changed
signal pump_changed  # the farm's pump was bought, or a pool was pumped dry
signal ice_changed  # the Ice Caves' cold stamps changed (someone came in, left, or bought a heater)
signal mine_changed  # the Colony Mine's gate opened, shoring props were bought, or a room was shored
signal camps_changed  # a camp was opened for the farm, or its supplies were bought or used
## A lift was repaired, or the deepest depth reached in a zone grew.
signal lifts_changed
signal lab_sitter_changed
## The farm was given the shuttle license.
signal shuttle_license_changed
signal shuttle_trips_changed
signal relay_changed(slotted: bool)
signal calibration_recorded(record: Dictionary)
signal phone_message(text: String)
signal credits_changed(credits: int)
signal audit_completed(report: Dictionary)
signal drop_pod_changed(present: bool)
signal ore_changed(ore: int)
## A load replaced the farm. Rovers move to where it parked them.
signal farm_loaded
signal fissures_changed
signal upgrades_changed
## The rover's wheel nuts came due, or Bram re-torqued them. A guest also hears
## it as the meters driven change.
signal wheels_changed
## A standard left on, or came back from, the OIRM drop pod (milestone 2).
signal oirm_changed
signal credibility_changed(points: int)
## A crop was planted, grew, or was harvested (income milestone).
signal crops_changed
## A soil cell was tilled.
signal soil_tilled(cell: Vector3i)
## Ground was dug or filled.
signal terrain_changed
## Ground water rose in a pit (or a pit stopped holding it).
signal pit_seep_changed
## A reference block was dug up.
signal blocks_changed
## The ore pockets dug up changed.
signal pockets_changed
## The stone stock or a piece built from it changed.
signal stone_changed
## A boulder was hit or broken.
signal boulders_changed
## The rover went into the tunnels or came out.
signal rover_place_changed
## The job board or the accepted jobs changed (paid calibration jobs).
signal jobs_changed
## The lab grew, a build started or finished, or an area changed.
signal lab_changed
## A robot was ordered, assembled or released.
signal robots_changed
## A skill gained XP. `player_id` is "" for a farm skill.
signal skill_xp_changed(player_id: String, skill_id: String)
## A skill reached a new level. `player_id` is "" for a farm skill.
signal skill_leveled(player_id: String, skill_id: String, level: int)
## The lab's XP changed (lab_xp).
signal lab_xp_changed
## A quest was offered, moved on or finished (quest_state, quest_points).
signal quests_changed
## A player was given an XP certificate or spent one (xp_certificates).
signal xp_certificates_changed
## A one-use reward was given or spent (one_use_held).
signal one_use_changed
## A player's character name or loadout changed (player_loadouts).
signal loadouts_changed

enum MoltStage { ACTIVE, PRE_MOLT, MOLTED }

const STEERING_ID: String = "rover_steering_encoder"
## What a check against a block is counted under in action_counts, before the
## instrument's id ("check_with_block:rover_steering_encoder"). Kept in saves.
const BLOCK_CHECK_COUNT: String = "check_with_block:"
## What a read of the soil probe is counted under in action_counts (read_probe).
## Kept in saves.
const READ_PROBE_COUNT: String = "read_probe"
## The phone line of a new farm's first morning, pointing at the farm notice board.
const FARM_BOARD_LINE: String = "Notices are up on the farm board."
## What a built stack of gauge blocks is counted under in action_counts
## (build_block_stack). Kept in saves.
const BLOCK_STACK_COUNT: String = "build_block_stack"
const HYGROMETER_ID: String = "hygrometer"
const TIRE_ID: String = "rover_tire_pressure"
const THERMOMETER_ID: String = "terrarium_thermometer"
const SPECIES_TABLE: StringName = &"tarantula_species"
const ITEMS_TABLE: StringName = &"items"
const ECONOMY_TABLE: StringName = &"economy"
const DRIFT_TABLE: StringName = &"sensor_drift_config"
const DISPATCH_TABLE: StringName = &"dialogue_dispatches"
const CROPS_TABLE: StringName = &"crops"
const SKILLS_TABLE: StringName = &"skills"
## What a save's skills are counted on (docs/design/quests_levels_story.md).
## 2 is the 99-level geometric curve (section 2). 3 is that curve with the lab
## level (section 3): Instrumentation is gone and the lab has its XP. 4 is that
## with every skill a player's own (section 9, step 4): Robotics and Husbandry
## are no longer the farm's, and crop XP is Agronomy's.
const SKILL_CURVE: int = 4
## The curves a save may say. An earlier one is brought up to SKILL_CURVE as it
## loads, one stage after another.
const KNOWN_CURVES: Array[int] = [2, 3, 4]
## The skill crop work feeds, and the one it fed before there was Agronomy.
const CROP_SKILL: String = "agronomy"
const OLD_CROP_SKILL: String = "field_ops"
## The farm skill that became the lab level.
const OLD_LAB_SKILL: String = "instrumentation"
## The most XP a converted skill holds: CoopProfile.MOST_XP.
const MOST_SKILL_XP: int = 1000000000
const SOIL_PROBE_ID: String = "soil_probe"
## Who did a calibration when it wasn't a player: the manager's grace cal.
## Player ids must never be this or LEGACY_LOCAL_PERFORMER.
const MANAGER_ID: String = "Manager"
## Issuer on a certificate from the colony's own bench.
const IN_HOUSE: String = "in-house"
## What calibration records said before players had ids.
const LEGACY_LOCAL_PERFORMER: String = "You"
## Set-point step for [ and ], as a volumetric fraction (1 %).
const SETPOINT_STEP: float = 0.01
## Moisture exactly on a band edge counts as in band despite float rounding.
const BAND_EPSILON: float = 1e-9
## A morning counts as growth day k once k - 0.5 days have passed since planting.
const GROWTH_DAY_MIN: float = 0.5
const PHONE_LOG_MAX: int = 40

# --- Playtest tuning (Week 2 board: keep the loop under two minutes) ---------
## Game days for a full molt while the terrarium sensors stay within MPE:
## 40 game minutes, which is 20 s at the default 720 s per day.
## Replace with the species' molt_days once Week 3 lands.
const PLAYTEST_MOLT_DAYS: float = 40.0 / 1440.0
## Pre-molt visual state starts at this progress.
const PRE_MOLT_AT: float = 0.8
## In-game days the shed exuvia stays in the enclosure after the spool is
## taken (Ryan's call: 1, gone the next morning). The spider stays in its
## burrow (hidden) until then, since the two can't share the tank floor.
const EXUVIA_LINGER_DAYS: int = 1
## Tarantulas that can be caught. Each has a tank waiting in the dome.
const CATCHABLE: Array[StringName] = [&"cobalt_sentinel", &"banded_regolith_runner", &"brass_glint_reticle", &"low_g_titan_carapace"]
## The Banded Regolith Runner: station stock that got loose in Phobos's warm service
## tunnels, caught there (catch_stray). Its tank record stays the three-field molt
## record every tank has (_is_tank), so the marker that it is station stock is kept
## beside it, in enclosure_origins.
const RUNNER: StringName = &"banded_regolith_runner"
const STATION_ORIGIN: String = "phobos_station"
## Deimos smuggler-cache stock: warm-crate species from data/tarantula_species.json
## (found_in == "deimos"), opened with Kestrel's proof (open_cache), picked in listed order.
const DEIMOS_CACHE_SPECIES: Array[StringName] = [&"low_g_titan_carapace", &"brass_glint_reticle"]
const CACHE_ORIGIN: String = "deimos_cache"
const CACHE_LINE: String = "Smuggled stock, found in a warm crate on Deimos"
const CACHE_QUEST: String = "a_quiet_crate"
const CACHE_COUNT: String = "open_cache"
const DEIMOS_CACHE_LOCKED_LINE: String = "Locked. Kestrel would know who has the proof."
const DEIMOS_CACHE_FALLBACK_CREDITS: int = 30
const DEIMOS_CACHE_EMPTY_LINE: String = "Empty but for straw and a forged manifest."
const DEIMOS_CACHE_WRONG_LABEL_MOD: int = 3
const DEIMOS_CACHE_LABEL_TAG: int = 701
## Species caught with a tank record but no dome tank yet: they sit out the molt and the
## lab sitter's round until the tank exists (nothing could show or collect them).
const NO_DOME_TANK: Array[StringName] = [&"banded_regolith_runner", &"brass_glint_reticle", &"low_g_titan_carapace"]
const STATION_LINE: String = "Station stock, caught in a Phobos service tunnel"
## What a catch is counted under in action_counts (the Strays quest reads it), and the
## prefix of a count of arriving on a moon ("reached_phobos"): both with no XP.
const STRAY_COUNT: String = "catch_stray"
const REACHED_PREFIX: String = "reached_"
## The expedition's counters (action_counts) and quest id (zones step 18): a booking, and
## a trip that ran to its planned end (never one cut short at the console).
const EXPEDITION_BOOKED: String = "expedition_booked"
const EXPEDITION_DONE: String = "expedition_done"
const EXPEDITION_QUEST: String = "deimos_survey"
## What shoring a rockfall and opening a colonist's case in the Colony Mine count under
## in action_counts (Old Props and The Colonist's Set read them, with no XP).
const SHORE_COUNT: String = MineDepth.SHORE_COUNT
const CASE_COUNT: String = MineDepth.CASE_COUNT
const SENTINEL: StringName = &"cobalt_sentinel"
## Where the wild one sits, off the sump's edge. How near it notices the rover, how
## fast is calm, how close is on top of it, and how far the cup reaches. [PLACEHOLDER]
const SENTINEL_AT := Vector3(-19.0, 0.0, -24.0)
const SENTINEL_SEES_M: float = 8.0
const SENTINEL_CALM_MPS: float = 3.5
const SENTINEL_CROWDED_M: float = 1.8
const SENTINEL_REACH_M: float = 4.0
## Told once when it is first in sight; the numbers are the ones above.
const SENTINEL_HINT: String = "SENTINEL: Lights low, creep, stop short."
## The chance on its first morning, and again for each morning it isn't met. [PLACEHOLDER]
const SENTINEL_CHANCE: float = 0.10
## How far the cup's relative humidity may really be from its ideal. [PLACEHOLDER]
const CUP_TOLERANCE_PCT: float = 5.0
## The dome hygrometer starts out of tolerance ("gold sticker expired at 03:00")
## so the first dome visit has something to calibrate. |error| = MPE * this.
const HYGROMETER_START_ERROR_RATIO: float = 1.12
## Clamp on |error| as a multiple of MPE.
const MAX_ERROR_MPE_MULTIPLE: float = 3.0

## Id of the player on this machine, used wherever something belongs to a
## person. Co-op will assign one per player.
var local_player_id: String = "player_1"

## Every instrument in sensor_drift_config/instruments, units and standards,
## in data order: instrument_id -> DriftingSensor. Built by build_registry().
var sensors: Dictionary = {}
## Shortcuts into `sensors` for the scenes that read these two directly.
var steering: DriftingSensor
var hygrometer: DriftingSensor

var dome_species_id: StringName = &"curlyhair"
var molt_progress: float = 0.0
var molt_stage: MoltStage = MoltStage.ACTIVE
## Day index on whose morning the exuvia from the last spool pickup is gone
## (0 = no exuvia lingering).
var exuvia_until_day: int = 0
## The caught tarantulas, each in a tank of its own beside the main terrarium.
## Species id (String) -> { molt_progress, molt_stage, exuvia_until_day }.
var enclosures: Dictionary = {}
## Where a caught tarantula came from, when it is not the wild: species id -> an origin
## (STATION_ORIGIN). Kept beside `enclosures` because a tank is exactly three fields.
## Saved, shown to guests; a save without it has none.
var enclosure_origins: Dictionary = {}
## The Phobos service-tunnel strays caught today: { "day": int, "ids": Array of the
## stray spot indices (PhobosServiceTunnel) }. Only today's count; another day's
## record is dropped. Host-run, saved, shown to guests.
var strays_caught: Dictionary = {}
## Today's Deimos smuggler cache state: { "day": int, "opened": true }, or {} when not
## opened today. Pruned to today on save and load. Host-run, saved, shown to guests.
var deimos_cache: Dictionary = {}
## The wild Cobalt Sentinel: out by the sump today, and the mornings since it was
## last scared off.
var sentinel_out: bool = false
var sentinel_days_unseen: int = 0
## The rules were told for this sighting (host only, not saved).
var sentinel_sighted: bool = false
## Past this the chance is certain anyway.
const SENTINEL_DAYS_MAX: int = 10
var rover_lights: bool = true
## The Lava Tubes beacon spots (LavaHub.SPOTS) that have one, in the order they
## were placed. Shared by the farm.
var beacons_placed: Array[String] = []
## The finds taken below the Lava Tubes: zone id -> { "day", "ids" } (ZoneDepth).
## Only today's count; a record of a past day is dropped. Shared by the farm.
var finds_taken: Dictionary = {}
## The farm owns the Flooded Aquifer's pump (bought at the hub crate, shared wallet), saved.
var pump_owned: bool = false
## The zones whose camp the farm has opened (Camp, zones doc 6.2), saved. A quest opens one.
var camps_open: Array[String] = []
## Nights of camp supplies the farm holds, bought at a camp hub and used up by a night there, saved.
var camp_supplies: int = 0
## Host only: the players put to bed at a camp tonight (the day clears it). Not saved: a night is not.
var _campers: Dictionary = {}
## The Aquifer's pools drained today: zone id -> { "day": int, "ids": [pool ids] }, like finds_taken.
var pools_drained: Dictionary = {}
## The Aquifer's open seals shut today: zone id -> { "day": int, "ids": [seal ids] }, like pools_drained.
var valves_shut: Dictionary = {}
## Host-side record of whose pack got wet wading today: player id -> day, saved so a reload does not spoil twice.
var packs_wet: Dictionary = {}
## The Colony Mine's gate on the plateau road is open (Bram's key quest opens it), saved.
var mine_gate_open: bool = false
## Shoring props the farm holds, bought at the Mine hub's crate (shared stock), saved.
var mine_props: int = 0
## The Mine's rooms shored today: zone id -> { "day": int, "ids": [rockfall ids] }, like pools_drained.
var rooms_shored: Dictionary = {}
## The Ice Caves' cold, per player: player id -> the GameClock.elapsed_days stamp the cold counts from
## (when they came in, or last bought a heater; shifted on a return within the grace so the cold
## resumes where it paused). Host-run, saved, synced; IceDepth.cold reads it.
var cold_since: Dictionary = {}
## Host only, not saved or synced: the cold of players who left the caves, kept for the grace
## (IceDepth.COLD_GRACE_HOURS): player id -> [their cold_since stamp, the elapsed_days they left].
var _cold_kept: Dictionary = {}
## The lift stations repaired, for good: zone id -> Array of the depths (ZoneDepth).
## Never reset, never expires. Shared by the farm.
var lifts_repaired: Dictionary = {}
## The lab sitter's booking (LabSitter): {} for none, else { "day", "watered",
## "spools" }: the day she works and what she has done so far. Shared by the farm.
var lab_sitter: Dictionary = {}
## Whether the farm holds the shuttle license (Shuttle): Vance's exam grants it,
## and it is never lost. Shared by the farm.
var shuttle_licensed: bool = false
## The day trips under way (Shuttle, zones doc section 8.2): player id -> { "moon",
## "ends_at" } with the end in GameClock elapsed days. One trip a player. The host ends
## each when its time is up or from the hub's console (shuttle_home). Shared by the farm.
var shuttle_trips: Dictionary = {}
## The deepest depth the farm's rover has reached in each zone: zone id -> depth.
## Only ever grows. Shown on the phone. Shared by the farm.
var deepest_depth: Dictionary = {}
var optical_silk_spools: int = 0
var relay_slotted: bool = false
## Species that spun the spool now in the relay (its lag_reduction_pct stacks).
var slotted_spool_species: StringName = &""
## Species of each spool in inventory, oldest first (parallel to optical_silk_spools).
var _spool_species: Array[StringName] = []
## Whether each of those spools is damaged (a shorter list means the rest aren't).
var _spool_damaged: Array[bool] = []
## Whether the spool now in the relay is damaged.
var slotted_spool_damaged: bool = false
## Every calibration event, oldest first. Week 3 audits read this, so a
## FAIL can't be erased by calibrating again.
var cal_log: Array[Dictionary] = []
## Instrument id -> most recent record (convenience view of cal_log).
var last_cal_records: Dictionary = {}
## Instrument id -> true when an untraceable zero was logged since its last
## traceable calibration. The next bench pass then can't lengthen the interval,
## so a remote zero can't hide a FAIL from the interval logic.
var _untraceable_since_cal: Dictionary = {}

# --- OIRM and traceability (milestone 2) ---
## standard_id -> its current OIRM certificate (see _issue_certificate).
var certificates: Dictionary = {}
## Every certificate issued, oldest first, founding stock included.
var certificate_log: Array[Dictionary] = []
## standard_id -> the day it comes back (next audit pod, or courier).
var at_oirm: Dictionary = {}
## Every trip to OIRM: { standard_id, sent_day, return_day, courier }. Used to
## excuse units that fell due while their standard was away.
var oirm_trips: Array[Dictionary] = []
## Unit id -> day a recall made its calibration suspect. A traceable
## recalibration clears it; Vance fines what is left at the audit.
var suspect_units: Dictionary = {}
## Audits in a row with no violations (a grace warning breaks the streak).
var clean_audit_streak: int = 0
## Tier 1 equipment gate: the first audit with zero violations (Q19).
var tier1_unlocked: bool = false
## Tier 3 equipment gate: Vance's "traceable lab" sign-off, for good.
var traceable_lab: bool = false
## Rover id -> whether it last had line of sight to the relay.
var rover_uplinks: Dictionary = {}
var _next_certificate_number: int = 1
## Standards on the colony: id -> day acquired. Tier 0 from day 0; Tier 1+
## once bought from Bram (milestone 3a).
var owned_standards: Dictionary = {}

## Credits (MegaCorp scrip). Fines come out of this; can go negative.
var credits: int = 0
## Phone messages that should survive scene swaps (dispatches, audits).
var phone_log: Array[String] = []
## Lines ever posted, so a guest knows which of the kept ones are new.
var phone_count: int = 0
## One report per audit (see AuditEngine.evaluate).
var audit_log: Array[Dictionary] = []
## instrument_id -> number of audits that fined it (repeat surcharge).
var offence_counts: Dictionary = {}
## True from an audit morning until the pod's scheduled departure.
var drop_pod_present: bool = false
var _drop_pod_departure_at: float = 0.0
## Crystal ore carried by the rover, and fissure id -> day it was mined.
var crystal_ore: int = 0
var mined_fissures: Dictionary = {}
var has_wide_treads: bool = false

## One-time grace: the first audit that would fine you becomes a warning,
## because your manager recalibrated the offenders before Vance got in.
var audit_grace_used: bool = false

var _cal_index_at_last_audit: int = 0
var _dispatch_deck: Array[Dictionary] = []

## The farm's one seed (co-op: the host's, sent to joining players). All
## simulation randomness comes from it: `rng` here, and each sensor's own
## generator, reseeded from it per instrument.
var world_seed: int = 0
var rng := RandomNumberGenerator.new()

## Farm persistence across swaps.
## rover id -> Transform3D where it was parked. Rovers belong to the farm, not
## to a player. Change it with park_rover().
var rover_transforms: Dictionary = {}
## Where the one rover is: "" on the farm, else a zone id (data/zones.json;
## only "lava_tubes", the tunnels, has a scene yet). It has an id in each place,
## so neither scene's place is taken for the other's. Change it with move_rover().
var rover_zone: String = "":
	set(value):
		var old: String = rover_zone
		rover_zone = value
		# Depth is only below the Lava Tubes: it goes when the rover really leaves them
		# (setting the same zone again, as a load does, keeps it).
		if value != old and value != TUNNELS_ZONE and value != AquiferDepth.ZONE and value != MineDepth.ZONE and value != IceDepth.ZONE:
			rover_depth = 0
		if value != old:
			zone_heat_trip = false  # a heat trip is one rover trip: every way the rover leaves or arrives ends it
		if value == "":
			rover_lent = false  # a rover that is not in a zone is not lent to one
## Host only, not saved: a vent's heat has struck the rover this trip (enter_vent), so
## the instruments that ride it drift ZoneHazards.DRIFT_MULTIPLIER times as fast until
## the trip ends. Cleared whenever rover_zone changes (leave_zone, move_rover(false),
## bring_rover_home, a released field rover, a rescue, a new trip) and by farm_from_dict.
## Only ever multiplies the wear add_rover_usage already adds: it never changes a
## reading after the fact (docs/design/zones.md section 5).
var zone_heat_trip: bool = false
## True while the farm's own rover is lent to a zone: driven in through the real
## entrance (move_rover), so the farm is without it. False when a zone's field rover
## (the TUNNEL_ROVER slot) is there for people who fast-travelled (fast_travel),
## and the farm rover stays home. Saved with rover_zone; a save from before it
## says lent for any rover in a zone, as it was then. Never true on the farm.
## The zones the farm has been to by the real entrance: the fast-travel console
## lists only these (zones doc section 8.1). Farm-wide, saved, sent with the
## rover's place. A save whose rover is lent grandfathers its zone.
var zones_unlocked: Array[String] = []

## Only the host sets it, for the one emit of rover_place_changed that is one
## rover's alone (so the others' leases stay): that rover's id, else "".
var rover_place_scope: String = ""

var rover_lent: bool = false:
	set(value):
		rover_lent = value and rover_zone != ""
## How far below the hub the one rover is: 0 is the hub, 1 the first depth
## (ZoneDepth). The rover has one depth, so every screen in the tunnels shows it:
## nobody is at another depth than the rover. Saved, and sent to guests with
## rover_zone. Change it with change_depth().
var rover_depth: int = 0
## Counts every change of where the rover is put by the host (change_depth, a
## re-park). Sent with rover_depth; a guest stamps its poses with it and the host
## drops a pose from an older one, so a pose that was in flight when the rover was
## moved cannot undo the move.
var rover_epoch: int = 0
## Host: a re-park was due while someone drove the rover; CoopRovers asks again.
var settle_due: bool = false
## The same word as a yes or no: in the tunnels. Computed from rover_zone, not
## saved; setting it true means "lava_tubes" and false means the farm.
var rover_in_tunnels: bool:
	get:
		return rover_zone != ""
	set(value):
		rover_zone = TUNNELS_ZONE if value else ""
		rover_lent = value
const TUNNELS_ZONE: String = "lava_tubes"
## Where the farm's rover goes into the Flooded Aquifer: a sinkhole south of the plateau
## [PLACEHOLDER]. Within TUNNEL_PAD_REACH_M of it the rover is on the pad.
const AQUIFER_PAD: Vector3 = Vector3(-24.0, 0.0, -22.0)
## Where the farm's rover goes into the Colony Mine: a sealed gate on the plateau road
## [PLACEHOLDER]. Within TUNNEL_PAD_REACH_M of it the rover is on the pad.
const MINE_PAD: Vector3 = Vector3(12.0, 0.0, -34.0)
## The gate's trigger box sits in front of the gate, wholly within TUNNEL_PAD_REACH_M of MINE_PAD, so
## a rover that is told to go in is never refused for distance [PLACEHOLDER].
const MINE_TRIGGER_OFFSET: Vector3 = Vector3(0.0, 0.0, 1.5)
const MINE_TRIGGER_SIZE: Vector3 = Vector3(5.0, 3.0, 3.0)
## Where the farm's rover goes into the Ice Caves: a ramp at the map's north edge [PLACEHOLDER]. Within
## TUNNEL_PAD_REACH_M of it the rover is on the pad; the trigger box sits in front of the ramp, as the Mine's.
const ICE_PAD: Vector3 = Vector3(-12.0, 0.0, -76.0)
const ICE_TRIGGER_OFFSET: Vector3 = Vector3(0.0, 0.0, 1.5)
const ICE_TRIGGER_SIZE: Vector3 = Vector3(5.0, 3.0, 3.0)
## Host: where each player is, as player id -> [place, depth] (ZonePresence). A
## player not in it is on the farm. Not saved: a loaded farm has everyone on the
## farm. A guest holds the host's copy, from the clock (FarmSync).
var player_places: Dictionary = {}
const ROVER: String = "rover_1"
const TUNNEL_ROVER: String = "rover_1_tunnels"
## The middles of the pads that lead in and out, and how near the rover must be
## on the host, who hears of a friend's late [PLACEHOLDER].
const TUNNEL_PAD := Vector3(20.5, 0.0, -15.5)
const TUNNEL_EXIT := Vector3(-1.5, 0.0, 27.4)
const TUNNEL_PAD_REACH_M: float = 6.0
## Rover controllers that can say where their rover is now (live_transform).
const LIVE_ROVER_GROUP: StringName = &"live_rovers"
## Just inside the tunnels' mouth [PLACEHOLDER].
const TUNNEL_START := Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.05, 22.5))
## Vector3i -> true for every tilled soil cell.
var tilled_cells: Dictionary = {}
## How deep each dug cell of Terrain is, in steps.
var dug: Dictionary[Vector2i, int] = {}
## The deepest each cell has been dug that a player has had Earthworks XP for
## (dig). A cell filled and dug again gives none.
var dug_paid: Dictionary[Vector2i, int] = {}
## How often each boulder was hit; BOULDER_HITS is broken. None is 0.
var boulder_hits: Dictionary[StringName, int] = {}
## The cells whose reference block was dug up, for good: filling and digging
## again gives nothing. Which cells hold one is ReferenceBlock.at(). The count
## is the farm's blocks, and they are kept, not used up [ASSUMPTION].
var found_blocks: Dictionary[Vector2i, bool] = {}
## The cells whose ore pocket was dug up.
var found_pockets: Dictionary[Vector2i, bool] = {}
## Pockets that grew after the first ones, drawn by the host (OrePocket.replacement).
var new_pockets: Array[Vector2i] = []
## Dug pocket -> the day its replacement is due.
var pocket_pending: Dictionary[Vector2i, int] = {}
## Stone from broken boulders, spent on pieces (StonePieces), shared by the farm.
var stone: int = 0
## The pieces built, cell of Terrain -> StonePieces kind.
var stone_pieces: Dictionary[Vector2i, int] = {}

## Lab credibility (Ryan, 2026-11-22): audits and overdue instruments move it;
## the phone shows its band. See data/economy.json "credibility".
var credibility: int = 0
## Highest band index reached so far, so a band is announced once.
var _best_band: int = 0
## First OIRM contract: "" (not offered), "active" (counting the run),
## "complete" (its standard is for sale) or "fulfilled" (bought).
var contract_state: String = ""
var contract_run: int = 0

## Paid calibration jobs (Ryan, 2026-11-22). Offers on today's board, and
## accepted jobs (an offer plus job_id, accepted_day, due_day).
var job_board: Array[Dictionary] = []
var active_jobs: Array[Dictionary] = []
## One result per finished job (see complete_job).
var job_log: Array[Dictionary] = []
var _next_job_number: int = 1
## The day today's board was built, the band it was built for, and the
## templates accepted off it that day (not offered again until tomorrow).
var _board_day: int = -1
var _board_band: int = -1
var _board_taken: Array[String] = []

## Upgradeable lab (Ryan, 2026-11-22): an index into economy lab/sizes, the
## spaces given to each discipline (its area), and the build under way:
## {} or { kind "grow" (size) or "refit" (discipline), done_day }.
var lab_size: int = 0
var lab_areas: Dictionary = {}
var lab_build: Dictionary = {}
## Where each space sits along the dome wall: a discipline, "" (free) or
## LAB_REFIT_SLOT. Only the dome floor reads it; lab_areas holds the counts.
var lab_layout: Array[String] = []
const LAB_REFIT_SLOT: String = "#refit"
## True while the morning runs, so credibility changes then don't rebuild the
## board before the audit is in.
var _morning: bool = false
## Phone lines from the morning's job cancellations, posted after the audit.
var _morning_notes: Array[String] = []

## Income milestone (Ryan, 2026-11-22): crops on tilled cells, auto-irrigated
## to a set point as the soil probe reads it, sold to Lin.
## Vector3i -> { crop_id, planted_day, days_grown, setpoint, out_of_band_days }
var plantings: Dictionary = {}
## Harvested crops waiting for Lin: { crop_id, in_spec, out_of_band_days }.
var harvest_bin: Array[Dictionary] = []
## The crop the next planting uses ("" = the first in data/crops.json).
var seed_crop_id: String = ""
## Irrigation offset (in SETPOINT_STEP steps) that new plantings start with,
## so a player who knows the probe's error can correct for it before planting.
var planting_offset_steps: int = 0
## Player id -> { skill id: XP }, for the skills each player has of their own.
var player_skill_xp: Dictionary = {}
## The next guest is this player. Kept with the farm, so a newcomer never takes
## the skills or records of someone who played before.
var next_player_number: int = 2
## A guest's key, hashed (each guest gets the whole farm) -> player id, so a
## friend who comes back is the same player.
var guest_ids: Dictionary = {}
## Skill id -> XP, for the skills the whole farm shares. No skill is the farm's
## now (data/skills.json), so only a save from before holds any, until it loads.
var farm_skill_xp: Dictionary = {}
## Owner ("" for the farm, else a player id) -> { skill id: share, 0 to 1 }: how
## much of its effects' full cut a skill had in a save from the 10-level curve.
## An effect uses the larger of this and its level's share. Only converting an
## older save writes it, so a new farm has none and it never rises in play. A
## save whose crop XP moved out of Field Ops keeps here the share Field Ops had.
var skill_effect_floor: Dictionary = {}
## Player id -> { XP source id (data/skills.json): { "count": times, "xp": XP } }:
## what each player has done that earned XP, and how much it gave, farm skills
## included. _award_xp is the only writer. It is how the XP crops gave Field
## Ops moved to Agronomy when that skill arrived (crop_xp), and what a quest
## will count (docs/design/quests_levels_story.md section 5.3).
var action_counts: Dictionary = {}
## The curve the XP above is counted on. A save without it is from the 10-level
## curve, and is converted as it loads (_convert_old_skills). One that says 2 is
## from before the lab level, and is given it as it loads (_credit_lab_from_logs).
## One that says 3 or less is from before every skill was a player's own
## (_make_skills_personal).
var skill_curve: int = SKILL_CURVE
## The lab's XP, on the skills' curve: the whole farm's, earned by work done in
## the lab (lab_xp_sources in data/skills.json). It never goes down.
## _award_lab_xp is the only writer in play.
var lab_xp: int = 0
## Ids of the lab-level gates (lab_gates in data/skills.json) this farm keeps
## open whatever its lab level: what a save from before the gates had open
## (docs/design/quests_levels_story.md section 10, 5). Nothing in play adds one.
var lab_gates_kept: Array[String] = []
## Discipline -> the most spaces its lab area has had that the lab has its XP
## for (lab_area). A space cleared and fitted again gives none.
var lab_areas_paid: Dictionary = {}
## The farm's quests (data/quests.json): quest id -> what QuestEngine keeps for
## it (the day accepted, the steps done, counts, who took part, the day done).
## Only update_quests() writes it, on the host.
var quest_state: Dictionary = {}
## Player id -> quest id -> a player's own quests (scope "player"), as
## quest_state keeps the farm's, with what they brought from other farms
## ("carried"). Only QuestEngine writes it, on the host.
var player_quest_state: Dictionary = {}
## Player id -> quest id -> the quest points that quest paid them. Kept here for
## every player, guests too; a guest's own file has theirs as well (CoopProfile),
## and the two meet in let_in_guest().
var quest_points: Dictionary = {}
## Player id -> { certificate id: XP }: the XP certificates each player holds and
## has not spent (docs/design/quests_levels_story.md section 4.4). A quest gives
## one to each player who took part; its id is the quest's and a number
## ("thirsty_probe#3"). Kept here for every player, guests too.
## give_xp_certificate() and spend_xp_certificate() write it.
var xp_certificates: Dictionary = {}
## How many certificates this farm has ever given. The next one's number is one
## more, so an id is never used again, not after a spend either.
var xp_certificates_given: int = 0
## Player id -> the sources (quest ids) of the certificates they have spent, here
## or on another farm. A quest never gives a player its certificate twice.
var xp_certificates_spent: Dictionary = {}
## One-use rewards held and not yet used (section 9, item 10): holder -> reward
## id (data/quests.json one_use_rewards) -> how many. The holder is a player id
## for a reward of a player (Bram's discount) or FARM_HOLDER for the farm's (the
## free refit). give_one_use() writes it; the action it is for spends it, on the
## host only (buy_standard, clear_lab_area). It stays on the farm that gave it.
var one_use_held: Dictionary = {}
## Player id -> { "name": the character's name, "parts": slot -> part id } (Loadout).
## A player with no entry has the defaults and no name. set_loadout() is the only
## writer, for the player who asks; the host keeps it and syncs it to every guest.
var player_loadouts: Dictionary = {}
## Crop id -> how many of that crop Lin has bought in spec, from the whole farm.
## sell_harvest_to_lin() is the only writer; a quest counts it.
var crops_sold_in_spec: Dictionary = {}
## Meters the rover has driven since its wheel nuts were last torqued in Bram's
## bay. add_rover_usage() and service_wheels() are the only writers. Nothing
## reads it but the service itself: a rover drives the same with nuts overdue.
var wheel_meters: float = 0.0
## Robot id ("TR-1") -> { frame, name, state (ROBOT_STATES), done_day,
## ordered_by }. Assembled robots' sensors are in `sensors` as "sensor@robot".
var robots: Dictionary = {}
## The farm's water cistern. It runs down as growing plots are irrigated and is
## refilled at each morning. One that is empty at the morning means the crops
## went dry, so that morning's growth is skipped (see _grow_crops); they carry
## on the next morning, after the refill. With the current numbers it cannot run
## dry in normal play (Ryan knew when he decided). Both numbers are
## [PLACEHOLDER]: 36 growing plots use about 140 L a day, all 144 about 550 L
## (worst day 553 L of 600 L).
const CISTERN_CAPACITY_L: float = 600.0
const CISTERN_DRAW_L_PER_PLOT_HOUR: float = 0.16
var cistern_liters: float = CISTERN_CAPACITY_L
## How high the ground water has risen in each dug pit, by cell (PitWater.seep). Only
## the host moves it; a guest is told. A pit never holds more than it would in the end.
var pit_seep: Dictionary[Vector2i, float] = {}
## In-game days of seep not yet worked out: the pits are looked at every 0.005 day
## (about 3.6 s of play) [PLACEHOLDER], not every frame.
const SEEP_STEP_DAYS: float = 0.005
var _seep_days: float = 0.0
## Every pit is at the level it will end at, so there is nothing to work out until
## the digging changes.
var _seep_full: bool = false
const CISTERN_DRY_HINT: String = "Crops lose today's growth. It refills in the morning."
## Passed as plant_crop's offset to mean "use planting_offset_steps now".
const OFFSET_CURRENT: int = -2147483648


func _ready() -> void:
	# Watches the input, for the on-screen key names (Controls). The root is still
	# busy setting up autoloads, so the node is added a moment later.
	Controls.install_observer.call_deferred(get_tree())
	_set_up_farm(_new_seed())
	for changed: Signal in [terrain_changed, stone_changed, pockets_changed, farm_loaded]:
		changed.connect(_forget_pad_problems)
	GameClock.time_advanced.connect(_on_time_advanced)
	GameClock.clock_ran.connect(_tick_molt)
	GameClock.day_started.connect(_on_day_started)
	GameClock.day_started.connect(_on_day_started_regrow.unbind(1))


## Replaces this farm with a new one. Set GameClock to 0 days first.
func new_farm() -> void:
	var fresh: Node = (get_script() as GDScript).new()
	fresh._set_up_farm(_new_seed())
	var problem: String = farm_from_dict(fresh.farm_to_dict())
	fresh.free()
	if problem != "":
		push_error("GameState: the new farm did not load: " + problem)


## A new farm gets a new seed once; everything random follows from it.
static func _new_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()


## A farm's first morning, on a GameState that holds nothing yet.
func _set_up_farm(p_seed: int) -> void:
	set_world_seed(p_seed)
	build_registry()
	# The hygrometer's sticker already expired (due day 0), so it is overdue
	# and out of tolerance until calibrated; everything else starts in date.
	hygrometer.error = hygrometer.mpe * HYGROMETER_START_ERROR_RATIO
	hygrometer.cal_due_day = 0
	credits = int(DataManager.get_number(ECONOMY_TABLE, "starting_credits", 0.0))
	reset_credibility()
	_post_morning_dispatch(1)  # day 1 is already under way at boot
	# Only a new farm is told, once: it is in the phone log from then on, and a
	# farm loaded from a save never comes through here.
	post_phone(FARM_BOARD_LINE)


func _unhandled_input(event: InputEvent) -> void:
	# Debug builds only: F9 skips to the next 06:00 (sensors drift for the skipped time).
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.physical_keycode == KEY_F9:
		GameClock.skip_to_next_morning()


# --- Instruments --------------------------------------------------------------

## (Re)builds `sensors` from sensor_drift_config/instruments. Each sensor
## starts in date with its own initial interval (standards) or the global one.
## Called from _ready(); tests call it on a GameState that is not in the tree.
func build_registry() -> void:
	sensors.clear()
	var table: Variant = DataManager.get_value(DRIFT_TABLE, "instruments", {})
	if typeof(table) != TYPE_DICTIONARY:
		push_error("GameState: %s/instruments is not an object." % DRIFT_TABLE)
		return
	var initial_interval: int = int(_interval_cfg("initial_days", 5.0))
	owned_standards.clear()
	for key: Variant in table:
		var id: String = str(key)
		if id.begins_with("_"):
			continue
		var sensor: DriftingSensor = DriftingSensor.from_config(id)
		sensor.max_error = sensor.mpe * MAX_ERROR_MPE_MULTIPLE
		sensor.cal_interval_days = sensor.initial_interval_days if sensor.initial_interval_days > 0 else initial_interval
		sensor.cal_due_day = sensor.cal_interval_days
		sensors[id] = sensor
		if sensor.role == "standard" and sensor.tier <= 0:
			owned_standards[id] = 0
	_sync_robot_sensors(robots)
	_seed_sensors()
	steering = sensors.get(STEERING_ID)
	hygrometer = sensors.get(HYGROMETER_ID)
	_issue_founding_certificates()
	reset_lab()
	if steering == null or hygrometer == null:
		push_error("GameState: %s needs %s and %s." % [DRIFT_TABLE, STEERING_ID, HYGROMETER_ID])


## Sets the farm's seed: the shared generator and every sensor restart from it.
func set_world_seed(p_seed: int) -> void:
	world_seed = p_seed
	rng.seed = p_seed
	_seed_sensors()


## Each sensor gets its own stable seed from the world seed and its id, so
## adding an instrument doesn't change the others' rolls.
func _seed_sensors() -> void:
	for id: Variant in sensors:
		(sensors[id] as DriftingSensor).reseed(hash("%d:%s" % [world_seed, str(id)]))


## Shuffles `list` in place with the farm's generator (Fisher–Yates).
func _shuffle(list: Array) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Variant = list[i]
		list[i] = list[j]
		list[j] = held


## A random entry of `list` from the farm's generator (null if empty).
func _pick(list: Array) -> Variant:
	if list.is_empty():
		return null
	return list[rng.randi_range(0, list.size() - 1)]


## Every sensor's live state, keyed by id (see DriftingSensor.to_dict()).
func sensors_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in sensors:
		out[str(id)] = (sensors[id] as DriftingSensor).to_dict()
	return out


## Restores sensors_to_dict() onto the registry. Ids no longer in the data are
## skipped with a warning; sensors missing from `data` keep their state. Call
## set_world_seed() before this, never after: it reseeds every sensor.
func sensors_from_dict(data: Dictionary) -> void:
	for key: Variant in data:
		var sensor: DriftingSensor = sensors.get(str(key))
		if sensor == null:
			push_warning("GameState: saved sensor '%s' is not in %s; skipped." % [key, DRIFT_TABLE])
			continue
		if typeof(data[key]) != TYPE_DICTIONARY:
			push_warning("GameState: saved sensor '%s' is not a dictionary; skipped." % key)
			continue
		sensor.apply_dict(data[key])


# --- Save state ---------------------------------------------------------------

## Every farm variable a save holds, besides the seed, the generator's state and
## the sensors. A new shared variable goes here or in SAVED_LATER, or it is lost
## on load (tests/test_save_state.gd fails until it is listed).
const SAVED_FIELDS: Array[String] = [
	"dome_species_id", "molt_progress", "molt_stage", "exuvia_until_day",
	"optical_silk_spools", "relay_slotted", "slotted_spool_species", "_spool_species",
	"cal_log", "_untraceable_since_cal", "certificate_log", "at_oirm", "oirm_trips",
	"suspect_units", "clean_audit_streak", "tier1_unlocked", "_next_certificate_number",
	"owned_standards", "credits", "phone_log", "audit_log", "offence_counts",
	"drop_pod_present", "_drop_pod_departure_at", "crystal_ore", "mined_fissures",
	"has_wide_treads", "audit_grace_used", "_cal_index_at_last_audit", "_dispatch_deck",
	"rover_transforms", "tilled_cells", "credibility", "_best_band", "contract_state",
	"contract_run", "job_board", "active_jobs", "job_log", "_next_job_number",
	"_board_day", "_board_band", "_board_taken", "lab_size", "lab_areas", "lab_build",
	"lab_layout", "plantings", "harvest_bin", "seed_crop_id", "planting_offset_steps",
]
## Guests a farm remembers [PLACEHOLDER].
const MAX_KNOWN_GUESTS: int = 64
## The most gates a save may keep open: far more than the table has rows.
const MAX_KEPT_GATES: int = 64
## In lab_gates_kept of a save that had earned the contract's standard before
## the gates: Bram still sells it with no tier gate, as he did then.
const KEPT_CONTRACT_SALE: String = "contract_stock"
## Variables added after save version 1. A save without one loads its declared
## default instead of being refused.
const SAVED_LATER: Array[String] = ["traceable_lab", "rover_uplinks", "player_skill_xp", "farm_skill_xp", "robots",
	"_spool_damaged", "slotted_spool_damaged", "phone_count", "next_player_number", "guest_ids", "dug",
	"boulder_hits", "found_blocks", "found_pockets", "rover_zone", "enclosures", "stone", "stone_pieces",
	"sentinel_out", "sentinel_days_unseen", "rover_lights", "cistern_liters", "pit_seep", "new_pockets", "pocket_pending",
	"skill_effect_floor", "skill_curve", "action_counts", "lab_xp", "lab_areas_paid", "dug_paid",
	"quest_state", "quest_points", "xp_certificates", "xp_certificates_given", "crops_sold_in_spec",
	"player_quest_state", "xp_certificates_spent", "wheel_meters", "lab_gates_kept", "one_use_held", "beacons_placed", "finds_taken", "rover_depth", "rover_epoch", "rover_lent", "zones_unlocked",
	"lifts_repaired", "deepest_depth", "lab_sitter", "shuttle_licensed", "shuttle_trips", "player_loadouts", "pump_owned", "pools_drained", "valves_shut", "packs_wet", "camps_open", "camp_supplies", "mine_gate_open", "mine_props", "rooms_shored", "cold_since", "enclosure_origins", "strays_caught", "deimos_cache"]
## Variables not in SAVED_FIELDS: saved on their own (seed, generator, sensors),
## rebuilt from the logs, per machine, or only used within one call.
const NOT_SAVED: Array[String] = [
	"_pad_problems",
	"_seep_days", "_seep_full", "world_seed", "rng", "sensors", "steering", "hygrometer", "last_cal_records",
	"certificates", "local_player_id", "_morning", "_morning_notes", "sentinel_sighted",
	"rover_place_scope", "rovers_node", "_recall_warned_day", "_recall_rescued_day", "_expedition_warned_day", "_expedition_rescued_day", "_guest_warned_day", "_guest_rescued_day", "recall_told", "_rescue_notes", "recall_in_tunnels", "recall_beds", "_ore_at_entry", "_console_arrivals", "_trip_players", "_campers", "_cold_kept",
	"rover_in_tunnels", "player_places", "settle_due", "zone_heat_trip",
]


## The whole farm as plain data (numbers, strings, arrays, dictionaries,
## Vector3i, Transform3D). It is a copy: later play doesn't change it.
func farm_to_dict() -> Dictionary:
	var out: Dictionary = {
		"world_seed": world_seed,
		"rng_state": rng.state,
		"sensors": sensors_to_dict(),
	}
	for field: String in SAVED_FIELDS + SAVED_LATER:
		var value: Variant = get(field)
		out[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	# A find taken on a past day is gone: it is not kept.
	out["finds_taken"] = ZoneDepth.prune(finds_taken, GameClock.get_day_index())
	out["pools_drained"] = ZoneDepth.prune(pools_drained, GameClock.get_day_index())
	out["valves_shut"] = ZoneDepth.prune(valves_shut, GameClock.get_day_index())
	out["packs_wet"] = AquiferDepth.prune_packs_wet(packs_wet, GameClock.get_day_index())
	out["rooms_shored"] = ZoneDepth.prune(rooms_shored, GameClock.get_day_index())
	out["strays_caught"] = _strays_today()
	out["deimos_cache"] = _deimos_cache_today()
	out["cold_since"] = _cold_in_caves()  # the stamps of whoever is in the caves: the rest are stale
	return out


## Why `data` can't load, or "" if it can. Changes nothing.
func farm_dict_problem(data: Dictionary) -> String:
	for key: String in ["world_seed", "rng_state"]:
		if typeof(data.get(key)) != TYPE_INT:
			return "'%s' is missing or not an integer." % key
	if typeof(data.get("sensors")) != TYPE_DICTIONARY:
		return "'sensors' is missing or not a dictionary."
	for field: String in SAVED_FIELDS + SAVED_LATER:
		if not data.has(field):
			if field in SAVED_LATER:
				continue
			return "'%s' is missing." % field
		var mine: Variant = get(field)
		var value: Variant = data[field]
		if typeof(value) != typeof(mine):
			return "'%s' has the wrong type." % field
		if typeof(value) == TYPE_FLOAT and not is_finite(value):
			return "'%s' is not a finite number." % field
		if _has_nan(value):
			return "'%s' holds a value that is not a number." % field
		if mine is Array:
			for entry: Variant in value:
				if typeof(entry) != (mine as Array).get_typed_builtin():
					return "'%s' has an entry of the wrong type." % field
	if data.has("beacons_placed") and LavaHub.placed_problem(data["beacons_placed"]) != "":
		return LavaHub.placed_problem(data["beacons_placed"])
	if data.has("finds_taken") and ZoneDepth.taken_problem(data["finds_taken"]) != "":
		return ZoneDepth.taken_problem(data["finds_taken"])
	if data.has("pools_drained") and AquiferDepth.drained_problem(data["pools_drained"]) != "":
		return AquiferDepth.drained_problem(data["pools_drained"])
	if data.has("valves_shut") and AquiferDepth.shut_problem(data["valves_shut"]) != "":
		return AquiferDepth.shut_problem(data["valves_shut"])
	if data.has("packs_wet") and AquiferDepth.packs_wet_problem(data["packs_wet"]) != "":
		return AquiferDepth.packs_wet_problem(data["packs_wet"])
	if data.has("rooms_shored") and MineDepth.shored_problem(data["rooms_shored"]) != "":
		return MineDepth.shored_problem(data["rooms_shored"])
	if data.has("mine_props") and MineDepth.props_problem(data["mine_props"]) != "":
		return MineDepth.props_problem(data["mine_props"])
	if data.has("cold_since") and IceDepth.cold_problem(data["cold_since"]) != "":
		return IceDepth.cold_problem(data["cold_since"])
	if data.has("mine_gate_open") and not data["mine_gate_open"] is bool:
		return "'mine_gate_open' is not a yes or no."
	if data.has("pump_owned") and not data["pump_owned"] is bool:
		return "'pump_owned' is not a yes or no."
	if data.has("camps_open") and Camp.open_problem(data["camps_open"]) != "":
		return Camp.open_problem(data["camps_open"])
	if data.has("camp_supplies") and Camp.supplies_problem(data["camp_supplies"]) != "":
		return Camp.supplies_problem(data["camp_supplies"])
	if data.has("lifts_repaired") and ZoneDepth.lifts_problem(data["lifts_repaired"]) != "":
		return ZoneDepth.lifts_problem(data["lifts_repaired"])
	if data.has("lab_sitter") and LabSitter.booking_problem(data["lab_sitter"]) != "":
		return LabSitter.booking_problem(data["lab_sitter"])
	if data.has("deepest_depth") and ZoneDepth.deepest_problem(data["deepest_depth"]) != "":
		return ZoneDepth.deepest_problem(data["deepest_depth"])
	var beacon_steps: String = LavaHub.steps_problem(QuestEngine.quests(), data.get("quest_state", {}), (data.get("beacons_placed", []) as Array).size())
	if beacon_steps != "":
		return beacon_steps
	if data.has("_spool_damaged") and data["_spool_damaged"].size() > data["_spool_species"].size():
		return "'_spool_damaged' has more entries than there are spools."
	for needs: Array in [["at_oirm", TYPE_INT], ["suspect_units", TYPE_INT], ["mined_fissures", TYPE_INT], ["lab_areas", TYPE_INT], ["lab_areas_paid", TYPE_INT],
			["offence_counts", TYPE_INT], ["rover_uplinks", TYPE_BOOL], ["rover_transforms", TYPE_TRANSFORM3D]]:
		var values: Dictionary = data.get(needs[0], {})
		for key: Variant in values:
			if not (key is String or key is StringName) or not _fits(values[key], needs[1]):
				return "'%s' has an entry of the wrong type." % needs[0]
	for field: String in ["owned_standards", "_untraceable_since_cal"]:
		for key: Variant in data[field]:
			if not (key is String or key is StringName):
				return "'%s' has a key that is not text." % field
	for cell: Variant in data["tilled_cells"]:
		if not cell is Vector3i:
			return "'tilled_cells' has an entry that is not a cell."
	var dug_problem: String = Terrain.dug_problem(data.get("dug", {}))
	if dug_problem != "":
		return "'dug' %s" % dug_problem
	if not data.get("dug_paid", {}) is Dictionary:
		return "'dug_paid' is not a dictionary."
	for cell: Variant in data.get("dug_paid", {}):
		var paid: Variant = data["dug_paid"][cell]
		if not cell is Vector2i or not paid is int or not Terrain.can_dig(cell) or paid < 1 or paid > Terrain.MAX_DIG_STEPS:
			return "'dug_paid' has a cell that can't be dug like that."
	for cell: Variant in data.get("found_blocks", {}):
		if not cell is Vector2i or not data["found_blocks"][cell] is bool or not data["found_blocks"][cell] \
				or ReferenceBlock.at(data["world_seed"], cell).is_empty():
			return "'found_blocks' has a cell that holds no block."
	for cell: Variant in data.get("found_pockets", {}):
		if not cell is Vector2i or not data["found_pockets"][cell] is bool or not data["found_pockets"][cell] \
				or not Terrain.can_dig(cell):
			return "'found_pockets' has a cell that can't be dug."
	var regrow: String = OrePocket.regrow_problem(data.get("new_pockets", []), data.get("pocket_pending", {}), data.get("found_pockets", {}), data.get("world_seed", 0))
	if regrow != "":
		return regrow
	if data.get("stone", 0) < 0 or data.get("stone", 0) > StonePieces.MAX_STONE:
		return "'stone' is not a stock that can be held."
	var pieces_problem: String = StonePieces.pieces_problem(data.get("stone_pieces", {}))
	if pieces_problem != "":
		return "'stone_pieces' %s" % pieces_problem
	var hits: Dictionary = data.get("boulder_hits", {})
	for boulder: Variant in hits:
		if not (boulder is String or boulder is StringName) or not StringName(boulder) in BOULDERS \
				or not hits[boulder] is int or hits[boulder] < 1 or hits[boulder] > BOULDER_HITS:
			return "'boulder_hits' has a boulder that can't be hit like that."
	for cell: Variant in data.get("pit_seep", {}):
		var level: Variant = data["pit_seep"][cell]
		if not cell is Vector2i or not Terrain.can_dig(cell) or not level is float or not is_finite(level):
			return "'pit_seep' has a cell that can't hold water."
	var liters: Variant = data.get("cistern_liters", CISTERN_CAPACITY_L)
	if not liters is float or liters < 0.0 or liters > CISTERN_CAPACITY_L:
		return "'cistern_liters' is out of range."
	var zone: Variant = data.get("rover_zone", "")
	if zone is String and zone != "" and (not ZoneData.is_playable(StringName(zone)) or Shuttle.is_moon(zone)):
		return "'rover_zone' is not a zone with a scene."
	if data.has("rover_epoch") and data["rover_epoch"] is int and data["rover_epoch"] < 0:
		return "'rover_epoch' is out of range."
	var depth: Variant = data.get("rover_depth", 0)
	if depth is int and (depth < 0 or depth > ZoneDepth.max_depth_of(str(data.get("rover_zone", TUNNELS_ZONE)))):
		return "'rover_depth' is out of range."
	if depth is int and depth > 0 and not data.get("rover_zone", "") in [TUNNELS_ZONE, AquiferDepth.ZONE, MineDepth.ZONE, IceDepth.ZONE]:
		return "'rover_depth' is set for a rover that is not in a zone with depths."
	if data.has("rover_lent") and not data["rover_lent"] is bool:
		return "'rover_lent' is not a yes or no."
	if data.get("rover_lent", false) and data.get("rover_zone", "") == "":
		return "'rover_lent' is set for a rover that is on the farm."
	var trips: Variant = data.get("shuttle_trips", {})
	if trips is Dictionary:
		for who: Variant in trips:
			if not who is String or who == "" or Shuttle.trip_shape_problem(trips[who]) != "":
				return "'shuttle_trips' has a trip that is not one."
	var seen_zones: Array[String] = []
	for zone_id: Variant in data.get("zones_unlocked", []):
		if not zone_id is String or not ZoneData.is_playable(StringName(zone_id)) or Shuttle.is_moon(zone_id):
			return "'zones_unlocked' holds a zone that does not exist."
		if seen_zones.has(zone_id):
			return "'zones_unlocked' holds a zone twice."
		seen_zones.append(zone_id)
	# Saves before zones say it as a yes or no.
	if not data.get("rover_in_tunnels", false) is bool:
		return "'rover_in_tunnels' is not a yes or no."
	if data.get("sentinel_days_unseen", 0) < 0 or data.get("sentinel_days_unseen", 0) > SENTINEL_DAYS_MAX:
		return "'sentinel_days_unseen' is out of range."
	if data.get("sentinel_out", false) and data.get("enclosures", {}).has(String(SENTINEL)):
		return "'sentinel_out' is set for a caught Sentinel."
	var tanks: Dictionary = data.get("enclosures", {})
	for id: Variant in tanks:
		if not id is String or not StringName(id) in CATCHABLE or not _is_tank(tanks[id]):
			return "'enclosures' has an entry that is not a caught tarantula."
	var stray_problem: String = _stray_problem(data.get("strays_caught", {}), data.get("enclosure_origins", {}), tanks)
	if stray_problem != "":
		return stray_problem
	var cache_problem: String = _deimos_cache_problem(data.get("deimos_cache", {}))
	if cache_problem != "":
		return cache_problem
	if not _optional_fields(data["lab_build"], ["kind", "discipline"], ["size", "done_day"]):
		return "'lab_build' has a field of the wrong type."
	for list: String in ["job_board", "active_jobs"]:
		for job: Dictionary in data[list]:
			if not _optional_fields(job, ["id", "customer", "item", "discipline", "area", "min_band", QUEST_JOB],
					["pay", "min_tier", "bench_minutes", "due_in_days", "accepted_day", "flat_cut_pct"]):
				return "'%s' has a field of the wrong type." % list
	# Only a job a quest handed out has these two, and such a job is never on
	# the board. A quest has one job out at a time.
	for offer: Dictionary in data["job_board"]:
		if offer.has(QUEST_JOB) or offer.has("flat_cut_pct"):
			return "'job_board' has a quest's job."
	var quests_with_a_job: Array[String] = []
	for job: Dictionary in data["active_jobs"]:
		var from_quest: String = str(job.get(QUEST_JOB, ""))
		if from_quest == "":
			continue
		if from_quest in quests_with_a_job:
			return "'active_jobs' has two jobs from one quest."
		quests_with_a_job.append(from_quest)
	for entry: Dictionary in data["harvest_bin"]:
		if not _optional_fields(entry, [], ["advance"]):
			return "'harvest_bin' has a field of the wrong type."
	for cell: Variant in data["plantings"]:
		if not cell is Vector3i or not _has_fields(data["plantings"][cell], ["crop_id"], ["days_grown", "out_of_band_days", "setpoint"]) or not _optional_fields(data["plantings"][cell], [], ["advance", "planted_day", "planted_at"]):
			return "'plantings' has an entry that is not a planted cell."
	for needs: Array in [["active_jobs", ["job_id"], ["due_day"]], ["oirm_trips", ["standard_id"], ["sent_day", "return_day"]],
			["harvest_bin", ["crop_id"], []],
			["cal_log", ["instrument_id", "standard_id", "result"], ["day", "as_found", "as_left", "mpe", "acceptance_limit", "due_day"]],
			["certificate_log", ["id", "standard_id"], ["day", "due_day", "expanded_uncertainty", "k"]]]:
		for entry: Dictionary in data[needs[0]]:
			if not _has_fields(entry, needs[1], needs[2]):
				return "'%s' has an entry with a field missing." % needs[0]
	for record: Dictionary in data["cal_log"]:
		if not record.get("as_found_in_tolerance") is bool or not record.get("traceable", true) is bool or not record.get("performed_by", "") is String or not record.get("standard_problem", "") is String:
			return "'cal_log' has an entry with a field missing."
	for cert: Dictionary in data["certificate_log"]:
		if not _optional_fields(cert, ["issuer"], []):
			return "'certificate_log' has a field of the wrong type."
		# A maker's certificate has no as-found; an in-house one names its reference.
		if not cert.has("as_found") or not (cert["as_found"] == null or cert["as_found"] is float or cert["as_found"] is int) or not cert.get("as_found_in_tolerance") is bool or (cert.has("reference_id") and not _has_fields(cert, ["reference_id", "reference_certificate"], [])):
			return "'certificate_log' has an entry with a field missing."
	for report: Dictionary in data["audit_log"]:
		var report_problem: String = _audit_problem(report)
		if report_problem != "":
			return "'audit_log' has an entry with a bad %s." % report_problem
	for player: Variant in data.get("player_skill_xp", {}):
		var own: Variant = data["player_skill_xp"][player]
		if not player is String or typeof(own) != TYPE_DICTIONARY or not _holds_only_ints(own):
			return "'player_skill_xp' has a player whose XP is not whole numbers."
	if data.get("next_player_number", 2) < 2:
		return "'next_player_number' is below 2."
	var guests: Dictionary = data.get("guest_ids", {})
	for key: Variant in guests:
		if not key is String or not guests[key] is String or guests.values().count(guests[key]) > 1:
			return "'guest_ids' has an entry that is not a player."
		var number: int = (guests[key] as String).trim_prefix("player_").to_int()
		if guests[key] != "player_%d" % number or number < 2 or number >= data.get("next_player_number", 2):
			return "'guest_ids' has an entry that is not a player."
	if not _holds_only_ints(data.get("farm_skill_xp", {})):
		return "'farm_skill_xp' has XP that is not a whole number."
	if not data.get("skill_curve", SKILL_CURVE) in KNOWN_CURVES:
		return "'skill_curve' is not a curve this game knows."
	if data.get("lab_xp", 0) < 0 or data.get("lab_xp", 0) > MOST_SKILL_XP:
		return "'lab_xp' is not XP a lab can have."
	var floors: Dictionary = data.get("skill_effect_floor", {})
	for owner_id: Variant in floors:
		if not owner_id is String or typeof(floors[owner_id]) != TYPE_DICTIONARY:
			return "'skill_effect_floor' has an entry that is not a player's or the farm's."
		for skill: Variant in floors[owner_id]:
			var share: Variant = floors[owner_id][skill]
			if not skill is String or not share is float or share < 0.0 or share > 1.0:
				return "'skill_effect_floor' has a share that is not from 0 to 1."
	var counts: Dictionary = data.get("action_counts", {})
	for player: Variant in counts:
		if not player is String or typeof(counts[player]) != TYPE_DICTIONARY:
			return "'action_counts' has an entry that is not a player's."
		for source: Variant in counts[player]:
			var done: Variant = counts[player][source]
			if not source is String or typeof(done) != TYPE_DICTIONARY or done.size() != 2 \
					or not done.get("count") is int or not done.get("xp") is int or done["count"] < 0 or done["xp"] < 0:
				return "'action_counts' has a count that is not whole numbers."
	var quest_problem: String = QuestEngine.state_problem(data.get("quest_state", {}))
	if quest_problem == "":
		quest_problem = QuestEngine.points_problem(data.get("quest_points", {}))
	if quest_problem == "":
		quest_problem = xp_certificates_problem(data.get("xp_certificates", {}), data.get("xp_certificates_given", 0))
	if quest_problem == "" and not QuestEngine._text_to_counts(data.get("crops_sold_in_spec", {})):
		quest_problem = "'crops_sold_in_spec' has a count that is not a whole number."
	if quest_problem == "":
		quest_problem = QuestEngine.player_state_problem(data.get("player_quest_state", {}))
	if quest_problem == "":
		quest_problem = xp_certificates_spent_problem(data.get("xp_certificates_spent", {}))
	if quest_problem == "":
		quest_problem = one_use_problem(data.get("one_use_held", {}))
	if quest_problem != "":
		return quest_problem
	var loadouts: Variant = data.get("player_loadouts", {})
	if (loadouts as Dictionary).size() > MAX_KNOWN_GUESTS + 1:
		return "'player_loadouts' has too many players."
	for who: Variant in loadouts:
		var loadout_problem: String = Loadout.entry_problem(loadouts[who]) if who is String else "a player that is not text"
		if loadout_problem != "":
			return "'player_loadouts' has %s." % loadout_problem
	if data.get("wheel_meters", 0.0) < 0.0:
		return "'wheel_meters' is not a distance driven."
	var kept: Array = data.get("lab_gates_kept", [])
	if kept.size() > MAX_KEPT_GATES:
		return "'lab_gates_kept' has too many entries."
	for gate: String in kept:
		if gate == "" or kept.count(gate) != 1:
			return "'lab_gates_kept' has an entry that is not one gate."
	var robot_problem: String = _robots_dict_problem(data.get("robots", {}))
	if robot_problem != "":
		return robot_problem
	var robot_sensors: Array[String] = _robot_sensor_ids(data.get("robots", {}))
	for id: Variant in data["sensors"]:
		if not (id is String or id is StringName):
			return "'sensors' has a key that is not text."
		var state: Variant = data["sensors"][id]
		if typeof(state) != TYPE_DICTIONARY:
			return "Sensor '%s' is not a dictionary." % id
		for key: Variant in state:
			if typeof(state[key]) == TYPE_FLOAT and not is_finite(state[key]):
				return "Sensor '%s' has a '%s' that is not a finite number." % [id, key]
		# Instruments no longer in the data are skipped on load, not refused.
		if (sensors.has(str(id)) or str(id) in robot_sensors) and not DriftingSensor.from_config(str(id)).apply_dict(state):
			return "Sensor '%s' can't load." % id
	return ""


## Whether a saved record has these texts and numbers.
static func _has_fields(record: Variant, texts: Array, numbers: Array) -> bool:
	return record is Dictionary and texts.all(func(key: String) -> bool: return record.get(key) is String) and numbers.all(
		func(key: String) -> bool: return record.get(key) is int or record.get(key) is float)


## What a screen would read from this audit and couldn't, or "".
static func _audit_problem(report: Dictionary) -> String:
	for key: String in ["day", "total_fine", "phone_count"]:
		if not (report.get(key, 0) is int or report.get(key, 0) is float):
			return key
	for pair: Array in [["lines", "instrument_id"], ["interlocks", "robot_id"]]:
		var entries: Variant = report.get(pair[0], [])
		if not entries is Array:
			return pair[0]
		for entry: Variant in entries:
			if not entry is Dictionary or typeof(entry.get(pair[1])) != TYPE_STRING:
				return pair[0]
	return "" if report.get("tire_check", {}) is Dictionary else "tire_check"


static func _holds_only_ints(values: Dictionary) -> bool:
	return values.keys().all(func(key: Variant) -> bool: return key is String or key is StringName) and values.values().all(
		func(value: Variant) -> bool: return value is int)


## Whether a value has this type. A number may be whole or not.
static func _fits(value: Variant, type: int) -> bool:
	return typeof(value) == type or (type == TYPE_INT and value is float)


## Whether those of these texts and numbers a record has are such. Missing ones are read as their defaults.
static func _optional_fields(record: Dictionary, texts: Array, numbers: Array) -> bool:
	return texts.all(func(key: String) -> bool: return _fits(record.get(key, ""), TYPE_STRING)) and numbers.all(
		func(key: String) -> bool: return _fits(record.get(key, 0), TYPE_INT))


static func _has_nan(value: Variant) -> bool:
	if value is float:
		return is_nan(value)
	if value is Dictionary:
		return (value as Dictionary).values().any(_has_nan)
	if value is Array:
		return (value as Array).any(_has_nan)
	return false


## Why a save's strays_caught and enclosure_origins can't load, or "".
static func _stray_problem(strays: Variant, origins: Variant, tanks: Dictionary) -> String:
	if not strays is Dictionary or not origins is Dictionary:
		return "'strays_caught' and 'enclosure_origins' must be dictionaries."
	if not (strays as Dictionary).is_empty():
		var day: Variant = (strays as Dictionary).get("day")
		var ids: Variant = (strays as Dictionary).get("ids")
		if (strays as Dictionary).size() != 2 or not day is int or day < 0 or not ids is Array:
			return "'strays_caught' is not a day and its caught strays."
		for stray: Variant in ids:
			if not stray is int or stray < 0 or stray >= PhobosServiceTunnel.STRAY_SPOTS.size() or (ids as Array).count(stray) != 1:
				return "'strays_caught' holds a stray that is not one."
	for id: Variant in origins:
		var ok_station: bool = id is String and id == String(RUNNER) and origins[id] is String and origins[id] == STATION_ORIGIN
		var ok_cache: bool = id is String and StringName(id) in DEIMOS_CACHE_SPECIES and origins[id] is String and origins[id] == CACHE_ORIGIN
		if not (ok_station or ok_cache) or not tanks.has(id):
			return "'enclosure_origins' has an entry that is not a caught tarantula's origin."
	return ""


## Why a save's deimos_cache can't load, or "".
static func _deimos_cache_problem(cache: Variant) -> String:
	if not cache is Dictionary:
		return "'deimos_cache' must be a dictionary."
	var dict: Dictionary = cache as Dictionary
	for key: Variant in dict:
		if not key in ["day", "opened", "fallback_paid"]:
			return "'deimos_cache' has an unknown field."
	var has_day: bool = dict.has("day")
	var has_opened: bool = dict.has("opened")
	if has_day != has_opened:
		return "'deimos_cache' is not a day and its opened state."
	if has_day:
		var day: Variant = dict.get("day")
		var opened: Variant = dict.get("opened")
		if not day is int or day < 0 or not opened is bool:
			return "'deimos_cache' is not a day and its opened state."
	if dict.has("fallback_paid") and not dict.get("fallback_paid") is bool:
		return "'deimos_cache' fallback_paid must be a bool."
	return ""


## An entry of `enclosures`: a molt, at the stage its progress gives.
static func _is_tank(tank: Variant) -> bool:
	if not tank is Dictionary or tank.size() != 3 or not tank.has_all(["molt_progress", "molt_stage", "exuvia_until_day"]):
		return false
	var progress: Variant = tank["molt_progress"]
	return progress is float and progress >= 0.0 and progress <= 1.0 \
		and tank["molt_stage"] is int and tank["molt_stage"] == _molt_stage_at(progress) \
		and tank["exuvia_until_day"] is int and tank["exuvia_until_day"] >= 0


## Replaces the farm with one farm_to_dict() made. Checks all of it first: bad
## data is refused whole and the reason returned ("" on success). An instrument
## the save doesn't know starts new. Set GameClock first, and reload the scenes
## afterward (SaveGame.restore() does the first).
func farm_from_dict(data: Dictionary) -> String:
	var problem: String = farm_dict_problem(data)
	if problem != "":
		return problem
	put_farm(data)
	_hold_deep_rover()
	finds_taken = ZoneDepth.prune(finds_taken, GameClock.get_day_index())
	pools_drained = ZoneDepth.prune(pools_drained, GameClock.get_day_index())
	valves_shut = ZoneDepth.prune(valves_shut, GameClock.get_day_index())
	packs_wet = AquiferDepth.prune_packs_wet(packs_wet, GameClock.get_day_index())
	rooms_shored = ZoneDepth.prune(rooms_shored, GameClock.get_day_index())
	settle_rover_depth(false)
	sentinel_sighted = false
	player_places.clear()
	_prune_cold()
	_cold_kept.clear()
	strays_caught = _strays_today()
	deimos_cache = _deimos_cache_today()
	_settle_trips_on_load()
	_recall_warned_day = 0
	_recall_rescued_day = 0
	_guest_warned_day.clear()
	_guest_rescued_day.clear()
	_expedition_warned_day.clear()
	_expedition_rescued_day.clear()
	_console_arrivals.clear()
	_trip_players.clear()
	_campers.clear()
	_rescue_notes.clear()
	_ore_at_entry = -1
	zone_heat_trip = false
	farm_loaded.emit()
	lab_xp_changed.emit()
	quests_changed.emit()
	xp_certificates_changed.emit()
	one_use_changed.emit()
	loadouts_changed.emit()
	molt_changed.emit(molt_progress, molt_stage)
	enclosures_changed.emit()
	deimos_cache_changed.emit()
	silk_changed.emit(optical_silk_spools)
	relay_changed.emit(relay_slotted)
	credits_changed.emit(credits)
	drop_pod_changed.emit(drop_pod_present)
	ore_changed.emit(crystal_ore)
	fissures_changed.emit()
	upgrades_changed.emit()
	oirm_changed.emit()
	credibility_changed.emit(credibility)
	crops_changed.emit()
	jobs_changed.emit()
	lab_changed.emit()
	robots_changed.emit()
	terrain_changed.emit()
	pit_seep_changed.emit()
	boulders_changed.emit()
	blocks_changed.emit()
	pockets_changed.emit()
	stone_changed.emit()
	rover_place_changed.emit()
	sentinel_changed.emit()
	rover_lights_changed.emit()
	lifts_changed.emit()
	lab_sitter_changed.emit()
	shuttle_license_changed.emit()
	shuttle_trips_changed.emit()
	return ""


## farm_from_dict() without its check, and with no signal but the sensors' own:
## `data` must have passed farm_dict_problem(). FarmSync says what changed.
func put_farm(data: Dictionary) -> void:
	var fresh: Node = (get_script() as GDScript).new()
	fresh.build_registry()
	fresh._sync_robot_sensors(data.get("robots", {}))
	_sync_robot_sensors(data.get("robots", {}))
	fresh.set_world_seed(data["world_seed"])
	set_world_seed(data["world_seed"])
	rng.state = data["rng_state"]
	# Listeners hold these sensors, so they are restored in place.
	var states: Dictionary = fresh.sensors_to_dict()
	for id: Variant in data["sensors"]:
		if states.has(id):
			var rate: float = states[id]["usage_drift_rate"]
			(states[id] as Dictionary).merge(data["sensors"][id], true)
			# Nothing changes a robot's wear rate, and early saves hold 0.
			if str(id).contains("@"):
				states[id]["usage_drift_rate"] = rate
		else:
			push_warning("GameState: saved sensor '%s' is not in %s; skipped." % [id, DRIFT_TABLE])
	sensors_from_dict(states)
	for field: String in SAVED_FIELDS + SAVED_LATER:
		var value: Variant = data.get(field, fresh.get(field))
		if value is Array:
			(get(field) as Array).assign((value as Array).duplicate(true))
		elif value is Dictionary and (get(field) as Dictionary).is_typed():
			(get(field) as Dictionary).assign(value)
		elif value is Dictionary:
			set(field, (value as Dictionary).duplicate(true))
		else:
			set(field, value)
	fresh.free()
	if not data.has("rover_zone") and data.get("rover_in_tunnels", false):
		# A save from before zones: the bool said the tunnels.
		rover_zone = TUNNELS_ZONE
	if not data.has("rover_lent"):
		# A save from before fast travel: a rover in a zone was the farm's, lent.
		rover_lent = rover_zone != ""
	if not data.has("zones_unlocked") and _has_been_to_tunnels(data) and not zones_unlocked.has(TUNNELS_ZONE):
		zones_unlocked.append(TUNNELS_ZONE)  # it has been in there
	if not data.has("deepest_depth") and rover_zone != "" and rover_depth > 0:
		# A save from before the record: where the rover is counts, but never past a shut gate.
		var held: bool = ZoneDepth.is_deep(rover_depth) and deep_problem(rover_zone) != ""
		deepest_depth[rover_zone] = ZoneDepth.FIRST_DEEP - 1 if held else rover_depth
	_level_pads()
	if not data.has("stone"):
		# From before stone, so its broken boulders gave none.
		for boulder: StringName in BOULDERS:
			if is_boulder_broken(boulder):
				stone += StonePieces.PER_BOULDER
	if not data.has("pit_seep"):
		# From before the seep: its pits were full.
		pit_seep.assign(PitWater.work_out(dug, stone_pieces)["levels"])
	if not data.has("pocket_pending"):
		# From before new pockets: every dug pocket grows its replacement.
		pocket_pending.clear()
		for cell: Vector2i in found_pockets:
			pocket_pending[cell] = GameClock.get_day_index() + OrePocket.REGROW_DAYS
	# A guest's copy is the host's farm as it is: only the host converts skills.
	if not data.has("skill_curve") and not FarmCommands.guest:
		# From the 10-level curve.
		_convert_old_skills()
	if not data.has("lab_areas_paid"):
		# From before areas were marked: the spaces it has are not paid for again.
		lab_areas_paid = lab_areas.duplicate()
	if not data.has("dug_paid"):
		# From before digging gave XP: the holes it has are not paid for.
		dug_paid.assign(dug)
	# 1 is the 10-level curve, which no save says.
	var from_curve: int = int(data["skill_curve"]) if data.has("skill_curve") else 1
	if from_curve < 3 and not FarmCommands.guest:
		# From before the lab level.
		_credit_lab_from_logs()
	if from_curve < 4 and not FarmCommands.guest:
		# From when Robotics and Husbandry were the farm's and crops fed Field Ops.
		_make_skills_personal()
	skill_curve = SKILL_CURVE
	_seep_days = 0.0
	_seep_full = false
	_morning = false
	_morning_notes.clear()
	# These hold the logs' own entries (a recall marks a record suspect in both).
	last_cal_records.clear()
	for record: Dictionary in cal_log:
		last_cal_records[record["instrument_id"]] = record
	certificates.clear()
	for cert: Dictionary in certificate_log:
		certificates[cert["standard_id"]] = cert
	# Last: the tiers' conditions read the rebuilt certificates and logs.
	if not data.has("lab_gates_kept") and not FarmCommands.guest:
		# From before the lab-level gates: what it had open stays open.
		_keep_open_gates()


func get_sensor(instrument_id: String) -> DriftingSensor:
	return sensors.get(instrument_id)


## Ids of the instruments Vance audits and the bench calibrates, in data order:
## the units in service, whose standard is on the colony. An unreleased robot's
## sensors are not among them (see bench_unit_ids).
func unit_ids() -> Array[String]:
	return bench_unit_ids().filter(func(id: String) -> bool: return not is_commissioning(id))


## unit_ids() and the sensors of robots not released yet, in data order.
func bench_unit_ids() -> Array[String]:
	return all_unit_ids().filter(is_in_service)


## Ids of the reference standards on the colony, in data order.
func standard_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_standard_ids():
		if owned_standards.has(id):
			ids.append(id)
	return ids


## Every unit in the data, in service or not.
func all_unit_ids() -> Array[String]:
	return _ids_with_role("unit")


## Every standard in the data, owned or not (Bram's catalog included).
func all_standard_ids() -> Array[String]:
	return _ids_with_role("standard")


## A unit is in service once the standard it is calibrated against is on the
## colony; a standard once it is owned. Out-of-service instruments don't drift.
func is_in_service(instrument_id: String) -> bool:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return false
	if sensor.role == "standard":
		return owned_standards.has(instrument_id)
	return sensor.calibrated_by != "" and owned_standards.has(sensor.calibrated_by)


## Instruments the farm's field calibration pad calibrates, in order: the tire
## gauge against the WD-1, then the steering encoder on the encoder jig against
## the PX-1 rotary table (Ryan, 2026-11-22: "both").
const FIELD_CAL_IDS: Array[String] = [TIRE_ID, STEERING_ID]


## FIELD_CAL_IDS whose standard is on the colony.
func field_cal_ready() -> Array[String]:
	var offered: Array[String] = []
	for id: String in FIELD_CAL_IDS:
		if is_in_service(id):
			offered.append(id)
	return offered


func _ids_with_role(role: String) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in sensors:
		if (sensors[id] as DriftingSensor).role == role:
			ids.append(str(id))
	return ids


## Short name for phone lines ("Steering"), or the full bench name.
func instrument_name(instrument_id: String, full: bool = false) -> String:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return instrument_id
	return sensor.display_name if full else sensor.short_name


## Name to show for a calibration record's `performed_by`: "You" for the local
## player (and for records made before ids), otherwise the id itself.
## Other players' display names come with co-op.
func performer_name(performed_by: String) -> String:
	if performed_by == "" or performed_by == local_player_id or performed_by == LEGACY_LOCAL_PERFORMER:
		return LEGACY_LOCAL_PERFORMER
	return performed_by


## Uncertainty budget for calibrating `instrument_id` against its standard
## right now (see CalUncertainty.budget). Empty if it has no standard.
## `player_id` is the operator; "" means the local player. With `by_robot` a
## robot does the work to that player's program, which adds u_robot.
func calibration_budget(instrument_id: String, player_id: String = "", by_robot: bool = false) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null or sensor.calibrated_by == "":
		return {}
	var standard: DriftingSensor = get_sensor(sensor.calibrated_by)
	if standard == null:
		push_warning("GameState: %s names unknown standard '%s'." % [instrument_id, sensor.calibrated_by])
		return {}
	var u_op: float = (sensor.mpe * DataManager.get_number(DRIFT_TABLE, "calibration_uncertainty/operator_fraction_of_mpe", 0.0)
		* skill_factor("operator_uncertainty", player_id))
	# In tolerance, a robot is off by up to this share of the unit's MPE, with no
	# stated confidence.
	var u_robot: float = CalUncertainty.spec_to_standard(sensor.mpe * robot_fraction_of_mpe(), 0.0) if by_robot else 0.0
	return CalUncertainty.budget(sensor, standard, u_op, u_robot)


## True for a standard whose own reference is on the colony, so the bench can
## calibrate it as well as OIRM.
func has_bench_reference(standard_id: String) -> bool:
	var sensor: DriftingSensor = get_sensor(standard_id)
	return (sensor != null and sensor.role == "standard" and owned_standards.has(standard_id)
		and owned_standards.has(sensor.calibrated_by))


## Why the bench can't calibrate this instrument at all, or "".
func _bench_problem(instrument_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	var title: String = instrument_name(instrument_id, true)
	if sensor.role == "standard":
		if not instrument_id in standard_ids():
			return "The %s is not on the colony yet." % title
		if sensor.calibrated_by == "":
			return "The %s is calibrated only at OIRM." % title
		if at_oirm.has(instrument_id):
			return "%s is at OIRM until day %d." % [title, at_oirm[instrument_id]]
		if not sensor.calibrated_by in standard_ids():
			return "The %s is not on the colony yet." % instrument_name(sensor.calibrated_by, true)
	elif not is_in_service(instrument_id):
		return ("%s has no standard on the colony yet." % title if sensor.calibrated_by == ""
			else "The %s is not on the colony yet." % instrument_name(sensor.calibrated_by, true))
	return ""


## Why a calibration made with this standard is not traceable right now, or "".
func standard_problem(standard_id: String) -> String:
	if not certificates.has(standard_id):
		return "without a certificate"
	if suspect_units.has(standard_id):
		return "suspect"
	if _untraceable_since_cal.has(standard_id):
		return "adjusted untraceably"
	if get_sensor(standard_id).is_overdue(GameClock.get_day_index()):
		return "overdue"
	return ""


## Zeroes the rover's steering from afar. No standard, so it is untraceable and
## judged against the MPE only. A player may ask for this, but not for calibrate().
func zero_steering(player_id: String = "") -> Dictionary:
	return calibrate(STEERING_ID, player_id, false)


## Zeroes an instrument and stores the record. Same path for the bench, the
## manager's grace calibration and the phone's remote ZERO STEERING, so every
## calibration lands in the log.
##
## With `use_standard` the unit is compared against its standard: the record
## gets the standard, U, TUR, acceptance limit and a pass / indeterminate /
## fail result, and the standard's hidden error is carried into the unit. A
## TUR under the floor refuses the calibration: nothing changes and the
## returned dictionary has "refused": true and a "reason". Without a standard
## (the remote zero) the result is plain pass / fail against the MPE, and the
## zero is untraceable: it adjusts the unit but is not a calibration, so the
## interval, due day and last calibration day stay as they were.
## `bench_minutes` is copied onto the record (0 off the bench).
## `performed_by` is a player id or MANAGER_ID; "" means the local player. With
## `robot_id` that robot does it to the player's program: u_robot is added, the
## robot's own error goes into the unit, and the record is the robot's.
func calibrate(instrument_id: String, performed_by: String = "", use_standard: bool = true,
		bench_minutes: float = 0.0, robot_id: String = "") -> Dictionary:
	if performed_by == "":
		performed_by = local_player_id
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		push_warning("GameState.calibrate: unknown instrument '%s'." % instrument_id)
		return {}
	# Hold the Reading's score, for this calibration only (a refusal uses it up
	# too). Never for a standard's own calibration (its U goes on its
	# certificate) and never for a robot's (no one held anything): the factor is
	# taken back and not used, whoever set it.
	var operator_scale: float = clampf(sensor.next_operator_scale, 0.0, 1.0)
	sensor.next_operator_scale = 1.0
	if sensor.role == "standard" or robot_id != "":
		operator_scale = 1.0
	var missing: String = _bench_problem(instrument_id) if use_standard else ""
	if missing != "":
		return {
			"instrument_id": instrument_id,
			"refused": true,
			"standard_id": sensor.calibrated_by,
			"tur": 0.0,
			"reason": missing,
		}
	var budget: Dictionary = calibration_budget(instrument_id, performed_by, robot_id != "") if use_standard else {}
	if budget.get("refused", false):
		return {
			"instrument_id": instrument_id,
			"refused": true,
			"standard_id": budget["standard_id"],
			"tur": budget["tur"],
			"reason": "TUR %s:1 is under the %s:1 floor. The standard is not good enough for this instrument." % [
				SP811.number(budget["tur"], 1), SP811.number(CalUncertainty.tur_floor(), 0)],
		}
	if not budget.is_empty() and at_oirm.has(budget["standard_id"]):
		return {
			"instrument_id": instrument_id,
			"refused": true,
			"standard_id": budget["standard_id"],
			"tur": budget["tur"],
			"reason": "%s is at OIRM until day %d." % [
				instrument_name(budget["standard_id"], true), at_oirm[budget["standard_id"]]],
		}
	var standard: DriftingSensor = get_sensor(budget["standard_id"]) if not budget.is_empty() else null
	# What the record states as U and TUR: the budget with the operator's term
	# times a played Hold the Reading's factor (quests_levels_story.md section
	# 7.2). The standard's own terms, the resolution and a robot's term are as
	# they were. The refusal above, the acceptance limit, the verdict and the
	# clean-TUR XP ("plain_tur" in the record) are the plain budget's, so a score
	# never changes them [ASSUMPTION].
	var stated: Dictionary = budget
	if standard != null and operator_scale < 1.0:
		stated = CalUncertainty.budget(sensor, standard, float(budget["u_op"]) * operator_scale, float(budget["u_robot"]))
	var today: int = GameClock.get_day_index()
	var on_time: bool = not sensor.is_overdue(today)
	# Without a standard the unit is zeroed against its own idea of zero, which
	# still carries the offset from its last bench calibration: the as-found is
	# the observed error and a bad standard stays hidden (Ryan, 2026-11-22).
	# A standard of another quantity carries its error through the chain's
	# sensitivity (FM-3 volts into thermometer degrees Celsius, section 1.5).
	# The Calibration skill needs a standard to work against.
	var zeroed: Dictionary = (sensor.zero(standard.error * sensor.standard_sensitivity + _robot_cal_error(robot_id, sensor.mpe),
			skill_factor("as_left_residual", performed_by))
		if standard else sensor.zero(sensor.reference_offset))
	var as_found: float = zeroed["as_found"]
	var as_left: float = zeroed["as_left"]
	var as_found_ok: bool = absf(as_found) <= sensor.mpe
	var limit: float = budget.get("acceptance_limit", sensor.mpe)
	var result: String = CalUncertainty.classify(as_found, sensor.mpe, limit)
	# Interval adjustment: a failed as-found brings the next calibration
	# sooner; an on-time pass earns a longer interval; a late pass keeps it.
	# An indeterminate result counts as an on-time pass that does not lengthen.
	# A pass only counts as interval evidence if the instrument has run at
	# least half its interval since the last calibration, so re-calibrating
	# the same day can't farm longer intervals or erase a shortened one.
	# A link in the chain needs a standard that was in date that day (section 1.7);
	# with an overdue standard (or one recalled, or without a certificate) the zero
	# adjusts the unit but is not a calibration.
	var standard_fault: String = standard_problem(standard.instrument_id) if standard else ""
	var standard_overdue: bool = standard.is_overdue(today) if standard else false
	var traceable: bool = standard != null and standard_fault == ""
	var previous_interval: int = sensor.cal_interval_days
	var days_in_service: int = today - sensor.last_cal_day if sensor.last_cal_day >= 0 else previous_interval
	var enough_service: bool = days_in_service >= ceili(previous_interval / 2.0)
	if not traceable:
		_untraceable_since_cal[instrument_id] = true
	elif _untraceable_since_cal.has(instrument_id):
		enough_service = false
		_untraceable_since_cal.erase(instrument_id)
	if traceable:
		suspect_units.erase(instrument_id)  # redone after a recall
		# A standard's interval stays as it is, as at OIRM [ASSUMPTION].
		if sensor.role == "standard":
			pass
		elif result == CalUncertainty.FAIL:
			sensor.cal_interval_days = maxi(int(_interval_cfg("min_days", 2.0)),
				previous_interval - int(_interval_cfg("shorten_days", 2.0)))
		elif result == CalUncertainty.PASS and on_time and enough_service:
			sensor.cal_interval_days = mini(int(_interval_cfg("max_days", 15.0)),
				previous_interval + int(_interval_cfg("lengthen_days", 2.0)))
		sensor.cal_due_day = today + sensor.cal_interval_days
		sensor.last_cal_day = today
	var record: Dictionary = {
		"instrument_id": instrument_id,
		"unit": sensor.error_unit,
		"mpe": sensor.mpe,
		"as_found": as_found,
		"as_found_band": sensor.band_for(as_found),
		"as_found_in_tolerance": as_found_ok,
		"as_left": as_left,
		"as_left_band": sensor.band_for(as_left),
		"day": today,
		"performed_by": performed_by if robot_id == "" else robot_id,
		# The player whose job card a robot worked to; "" if no robot did this.
		"programmed_by": "" if robot_id == "" else performed_by,
		"on_time": on_time,
		"days_in_service": days_in_service,
		"interval_evidence": enough_service,
		"previous_interval_days": previous_interval,
		"interval_days": sensor.cal_interval_days,
		"due_day": sensor.cal_due_day,
		# "" and null when no standard was used (the remote zero).
		"standard_id": budget.get("standard_id", ""),
		"standard_uncertainty": stated.get("expanded_uncertainty"),
		"tur": stated.get("tur"),
		# The TUR with no mini-game score: what the clean-TUR XP and the bench's
		# "marginal" note are judged on. Over it, "tur" is the steady-hold figure.
		"plain_tur": budget.get("tur"),
		"acceptance_limit": limit,
		"result": result,
		"traceable": traceable,
		"bench_minutes": bench_minutes,
		"standard_overdue": standard_overdue,
		# "" unless the standard is why this is not traceable.
		"standard_problem": standard_fault,
		"standard_certificate": certificates.get(standard.instrument_id, {}).get("id", "") if standard else "",
		# Set by recall() if the standard is later found out of tolerance and
		# correcting for its error changes this result.
		"suspect": false,
	}
	cal_log.append(record)
	last_cal_records[instrument_id] = record
	if sensor.role == "standard" and traceable:
		_certify_on_bench(record)
	_recall_after_robot_failure(record)
	calibration_recorded.emit(record)
	_note_soil_excursions()
	_credibility_after_calibration(record)
	_xp_after_calibration(record)
	return record


## A traceable bench calibration of a standard: it gets an in-house certificate,
## and an out-of-tolerance as-found starts a recall, as at OIRM.
func _certify_on_bench(record: Dictionary) -> void:
	var id: String = record["instrument_id"]
	var previous: Dictionary = certificates.get(id, {})
	var cert: Dictionary = _issue_certificate(id, record["day"], record["as_found"], record["as_left"], false, IN_HOUSE, "IH")
	cert["expanded_uncertainty"] = record["standard_uncertainty"]
	cert["k"] = CalUncertainty.coverage_factor()
	cert["reference_id"] = record["standard_id"]
	cert["reference_certificate"] = record["standard_certificate"]
	record["certificate"] = cert["id"]
	if not cert["as_found_in_tolerance"]:
		_recall_and_post(id, record["as_found"], int(previous.get("day", 0)))
	oirm_changed.emit()


## With friends in, bench work can't run past 06:00, where the day waits.
const NO_TIME_TONIGHT: String = "This would run past 06:00, and the day waits until everyone is in bed."


## With friends in: "" or why not. See CoopBeds.
func go_to_bed(player_id: String = "") -> String:
	var id: String = _player(player_id)
	# On a moon: only an expedition's camp is a bed (zones step 18).
	var on_moon: String = _moon_place_of(id)
	if on_moon != "":
		return _go_to_moon_camp_bed(id, on_moon)
	# Somewhere in a zone: only an open camp's hub is a bed (zones doc 6.2 and 12.4).
	var camp_zone: String = _zone_place_of(id)
	if camp_zone != "":
		return _go_to_camp_bed(id, camp_zone)
	# The host's screen is in a zone's hub but their place says otherwise: not a plain bed.
	if id == local_player_id and _scene_zone_here() != "":
		return "Your place and this scene disagree. Try again in a moment."
	# Where the local player stands is theirs to check; a guest's is checked on their screen.
	if id == local_player_id:
		var why: String = CoopBeds.here_refusal()
		if why != "":
			return why
	return CoopBeds.go_to_bed(id)


func get_up(player_id: String = "") -> String:
	_beds().get_up(_player(player_id))
	return ""


## The moon the player is on, or "".
func _moon_place_of(player_id: String) -> String:
	if not player_places.has(player_id):
		return ""
	var place: String = place_of(player_id)
	return place if Shuttle.is_moon(place) else ""


## The zone the player is in (not the farm, the dome or a moon), or "".
func _zone_place_of(player_id: String) -> String:
	if not player_places.has(player_id):
		return ""
	var place: String = place_of(player_id)
	return "" if place in [ZonePresence.FARM, ZonePresence.DOME] or Shuttle.is_moon(place) else place


## The zone whose hub scene is on screen, or "" (the farm, the dome, a menu, a moon).
func _scene_zone_here() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return ""
	var at: Array = ZonePresence.for_scene(scene.scene_file_path)
	if at.is_empty() or str(at[0]) in [ZonePresence.FARM, ZonePresence.DOME] or Shuttle.is_moon(str(at[0])):
		return ""
	return str(at[0])


## The beds the day waits on: CoopBeds, or the test's stand-in.
func _beds() -> Object:
	return recall_beds if recall_beds != null else CoopBeds


## Host: why `player_id` can't sleep at the camp in `zone` tonight, or "" (Camp.sleep_problem).
func camp_problem(player_id: String, zone: String, paid: bool = false) -> String:
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var near: bool = at != null and Camp.near(zone, at, Camp.HOST_REACH_SLACK_M)
	return Camp.sleep_problem(zone, camps_open.has(zone), depth_of(player_id), rover_zone == zone and rover_depth == 0, near, maxi(camp_supplies, 1 if paid else 0))


## Host: the player goes to bed at the open camp of `zone`. Uses one night's supplies and
## counts the night for the quests. Alone the day ends where they stand (no rescue, no fee,
## not moved); with friends in they count as in bed, and the recall leaves them be.
func _go_to_camp_bed(player_id: String, zone: String) -> String:
	if FarmCommands.guest:
		return "Only the host's farm can end the day."
	if GameClock.paused:
		return "The clock is paused."
	# Paid for tonight already (kept until the day starts): waking and lying down again
	# at the camp costs no second supply and counts no second night.
	var paid: bool = _campers.has(player_id)
	if paid and player_id in _beds().in_bed:
		return ""
	var why: String = camp_problem(player_id, zone, paid)
	if why != "":
		return why
	return _camp_night(player_id, Camp.NIGHT_COUNT, paid)


## Host: one night at a camp for `player_id`: uses a night's supplies (not again if they
## paid for tonight already), counts it under `count_key` for the quests, and puts them to
## bed. A refusal from the beds takes the night back. `forced` is the 02:00 recall's
## auto-bed: the caller puts them to bed, so no bed is asked for here.
func _camp_night(player_id: String, count_key: String, paid: bool, forced: bool = false) -> String:
	if player_id in _beds().in_bed:
		return "You are in bed already."
	var counted: bool = player_id != MANAGER_ID and not paid
	if not paid:
		camp_supplies -= 1
		_campers[player_id] = true
	if counted:
		var done: Dictionary = (action_counts.get_or_add(player_id, {}) as Dictionary).get_or_add(count_key, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	camps_changed.emit()
	if forced:
		return ""
	var refused: String = _beds().go_to_bed(player_id)
	if refused != "":
		if not paid:
			camp_supplies += 1  # the night did not happen
			_campers.erase(player_id)
		if counted:
			var undone: Dictionary = (action_counts[player_id] as Dictionary)[count_key]
			undone["count"] = int(undone["count"]) - 1
		camps_changed.emit()
	return refused


## Host: the traveller on `moon` goes to bed at its camp: the same night as the Lava
## Tubes camp (one shared supply, counted for the quests as EXPEDITION_NIGHT_COUNT, no
## fee), but only on an expedition and at an open camp. The host cannot know where a
## moon walker stands, so the reach to the camp is checked by the hub on the walker's own
## screen, as the console's is (DeimosHub).
func _go_to_moon_camp_bed(player_id: String, moon: String) -> String:
	if FarmCommands.guest:
		return "Only the host's farm can end the day."
	if GameClock.paused:
		return "The clock is paused."
	var paid: bool = _campers.has(player_id)
	if paid and player_id in _beds().in_bed:
		return ""
	var why: String = Camp.moon_sleep_problem(moon, camps_open.has(moon), Shuttle.is_expedition(shuttle_trips.get(player_id, {})), maxi(camp_supplies, 1 if paid else 0))
	if why != "":
		return why
	if player_id in _beds().in_bed:
		return "You are in bed already."
	if not paid and player_id != MANAGER_ID:
		# The job's next step is open before the night is counted (a count is kept from
		# the step opening).
		update_quests([], false)
	return _camp_night(player_id, Camp.EXPEDITION_NIGHT_COUNT, paid)


## `scene_path` is the hub, at its first depth, of a zone whose camp the farm has opened:
## the one scene where a bed is not on the farm (CoopBeds.scene_refusal).
func camp_scene_open(scene_path: String) -> bool:
	var at: Array = ZonePresence.for_scene(scene_path)
	return not at.is_empty() and int(at[1]) == 0 and camps_open.has(str(at[0]))


## The player is asleep at a camp tonight: the recall does not warn or carry them out.
func is_camping(player_id: String) -> bool:
	return _campers.has(player_id) and player_id in _beds().in_bed


## Host: the farm opens the camp of `zone` (a quest does, Camp). Returns "" or why not.
func open_camp(zone: String) -> String:
	if FarmCommands.guest:
		return "Only the host's farm opens a camp."
	if not Camp.has_camp(zone):
		return "That zone has no camp."
	if not camps_open.has(zone):
		camps_open.append(zone)
		camps_open.sort()
		camps_changed.emit()
	return ""


## Host: the farm buys a night's supplies at the camp, for the player there (`player_id`
## is filled in by FarmCommands). Returns "" or why not (Camp.buy_problem). Paid once from
## the shared wallet.
func buy_camp_supplies(player_id: String = "") -> String:
	var zone: String = _zone_place_of(player_id)
	if zone == "":
		return Camp.buy_problem("", false, "", 0, camp_supplies, credits, false)
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var near: bool = rover_zone == zone and rover_depth == 0 and at != null and Camp.near(zone, at, Camp.HOST_REACH_SLACK_M)
	var reason: String = Camp.buy_problem(zone, camps_open.has(zone), zone, depth_of(player_id), camp_supplies, credits, near)
	if reason != "":
		return reason
	add_credits(-Camp.SUPPLY_COST_CREDITS)
	camp_supplies += 1
	camps_changed.emit()
	return ""


## "" or why not. See CoopWalkers.
func get_out_of_rover(x: float, z: float, player_id: String = "") -> String:
	SaveGame.saving.emit()  # the rover says where it is
	return CoopWalkers.get_out(_player(player_id), x, z)


func get_into_rover(player_id: String = "") -> String:
	SaveGame.saving.emit()
	return CoopWalkers.get_in(_player(player_id))


func _player(player_id: String) -> String:
	return player_id if player_id != "" else local_player_id


## The player's bench calibration: calibrate() against the standard, then the
## bench time passes on the game clock (instruments keep drifting meanwhile).
## The record gains "bench_minutes". `performed_by` is as in calibrate(). A
## refused calibration takes no time.
func calibrate_at_bench(instrument_id: String, performed_by: String = "") -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return {}
	var minutes: float = sensor.bench_minutes * skill_factor("bench_time", performed_by)
	if GameClock.waits_within(minutes / 1440.0):
		return { "ok": false, "refused": true, "reason": NO_TIME_TONIGHT }
	var record: Dictionary = calibrate(instrument_id, performed_by, true, minutes)
	if record.is_empty() or record.get("refused", false):
		return record
	if minutes > 0.0:
		GameClock.advance(minutes / 1440.0)
	return record


## Lets the ground water rise in the pits as time passes: the host's clock only, in
## steps of SEEP_STEP_DAYS, so a long sleep fills them at once.
func _seep_pits(delta_days: float) -> void:
	if FarmCommands.guest or dug.is_empty() or _seep_full:
		return
	_seep_days += delta_days
	if _seep_days >= SEEP_STEP_DAYS:
		_set_seep(PitWater.seep(pit_seep, dug, _seep_days))
		_seep_days = 0.0


## Takes this as the ground water. A step of time says so only when the water shows
## a change (each centimeter, or a pit reaching its end level); with `any_change`, as
## after digging, any change in the numbers is said, and no change is not.
func _set_seep(next: Dictionary[Vector2i, float], any_change: bool = false) -> void:
	var shows: bool = next != pit_seep if any_change else PitWater.shown(next, dug) != PitWater.shown(pit_seep, dug)
	_seep_full = next == pit_seep
	pit_seep = next
	if shows:
		pit_seep_changed.emit()


func _on_time_advanced(delta_days: float) -> void:
	_hold_relay_lock()
	for id: Variant in sensors:
		if is_in_service(str(id)) and not is_relay_locked(str(id)):
			(sensors[id] as DriftingSensor).advance_days(delta_days)
	_draw_cistern(delta_days)
	_seep_pits(delta_days)
	_note_soil_excursions()
	# At 06:00 the cards wait for _on_day_started, so what they change counts
	# toward the new day.
	if fmod(GameClock.elapsed_days, 1.0) != 0.0:
		_run_robot_cards()
	_note_flare_start(delta_days)
	if drop_pod_present and GameClock.elapsed_days >= _drop_pod_departure_at:
		drop_pod_present = false
		drop_pod_changed.emit(false)
		post_phone("AUD-1T: Departing. Please remain compliant in our absence.")
	_end_due_trips()
	_tick_expeditions()
	_tick_recall()


# --- Kestrel (section 1.7) ----------------------------------------------------

func _flare_number(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "flares/" + key, fallback)


## True if a solar flare comes on this day's night. The schedule follows the
## clock alone, so it needs no saving.
func is_flare_day(day: int) -> bool:
	var since: int = day - int(_flare_number("first_day", 10.0))
	return since >= 0 and since % maxi(int(_flare_number("period_days", 7.0)), 1) == 0


## When this day's flare starts, in elapsed days.
func _flare_start(day: int) -> float:
	return GameClock.elapsed_at_hour(day, _flare_number("start_hour", 20.0))


## Kestrel is at the dome only while a flare lasts.
func kestrel_present() -> bool:
	var day: int = GameClock.get_day_index()
	if not is_flare_day(day):
		return false
	var since: float = GameClock.elapsed_days - _flare_start(day)
	return since >= 0.0 and since < _flare_number("duration_hours", 6.0) / GameClock.HOURS_PER_DAY


func _note_flare_start(delta_days: float) -> void:
	if kestrel_present() and GameClock.elapsed_days - delta_days < _flare_start(GameClock.get_day_index()):
		post_phone("Solar flare tonight. Kestrel is at the dome airlock.")


## Standards Kestrel sells, in data order (owned ones included). A standard
## earned by the OIRM contract is Bram's to sell.
func kestrel_catalog() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_standard_ids():
		if (sensors[id] as DriftingSensor).seller == "kestrel" and not _is_contract_stock(id):
			ids.append(id)
	return ids


## Why Kestrel can't sell this standard right now, or "" if it's for sale.
func kestrel_purchase_problem(standard_id: String) -> String:
	if not kestrel_present():
		return "Kestrel only comes on solar flare nights."
	if not standard_id in kestrel_catalog():
		return "Kestrel doesn't have that."
	return _purchase_problem(standard_id)


## Buys a standard from Kestrel. Returns "" on success, or the reason it can't
## happen. It comes with no certificate, so it is due at OIRM at once, and work
## done with it is not traceable until OIRM has certified it.
func buy_from_kestrel(standard_id: String, player_id: String = "") -> String:
	var problem: String = kestrel_purchase_problem(standard_id)
	if problem != "":
		return problem
	var sensor: DriftingSensor = get_sensor(standard_id)
	_take_standard(standard_id)
	sensor.cal_due_day = GameClock.get_day_index()
	post_phone("KESTREL: One %s. No certificate. Just a number you can poke.%s" % [
		sensor.short_name, _put_units_in_service(standard_id)[1]])
	if standard_id == contract_standard_id() and contract_state == "active":
		contract_state = "fulfilled"
		credibility_changed.emit(credibility)
		post_phone("OIRM CONTRACT closed: the %s is already on the colony." % instrument_name(standard_id))
	_award_lab_xp("buy_standard", player_id, calibration_xp_scale(standard_id))
	upgrades_changed.emit()
	oirm_changed.emit()
	return ""


# --- Skills (section 2) -------------------------------------------------------

func skill_ids() -> Array[String]:
	var out: Array[String] = []
	for skill: Dictionary in DataManager.get_records(SKILLS_TABLE, "skills"):
		out.append(str(skill["id"]))
	return out


## True for a skill the whole farm shares; false for one each player has.
func is_farm_skill(skill_id: String) -> bool:
	return DataManager.get_record(SKILLS_TABLE, skill_id, "skills").get("scope", "") == "farm"


## `player_id` "" means the local player; it makes no difference to a farm skill.
func skill_xp(skill_id: String, player_id: String = "") -> int:
	if is_farm_skill(skill_id):
		return int(farm_skill_xp.get(skill_id, 0))
	var own: Dictionary = player_skill_xp.get(local_player_id if player_id == "" else player_id, {})
	return int(own.get(skill_id, 0))


func skill_level(skill_id: String, player_id: String = "") -> int:
	return _level_for_xp(skill_xp(skill_id, player_id))


## What is left of a base amount at the player's level: 1.0 at level 1, less
## the level's share of the effect's `full` cut, never under `floor`
## (data/skills.json). A converted save's floor share counts if it is larger.
func skill_factor(effect_id: String, player_id: String = "") -> float:
	var effect: Dictionary = DataManager.get_record(SKILLS_TABLE, effect_id, "effects")
	if effect.is_empty():
		return 1.0
	var skill: String = str(effect["skill"])
	var share: float = maxf(effect_share(skill_level(skill, player_id)), effect_floor(skill, player_id))
	return maxf(float(effect.get("floor", 0.0)), 1.0 - float(effect["full"]) * share)


## The smallest skill_factor() of any player the farm knows, for what belongs to
## the whole farm and no one player does.
func best_skill_factor(effect_id: String) -> float:
	var best: float = skill_factor(effect_id)
	for player: String in _known_players():
		best = minf(best, skill_factor(effect_id, player))
	return best


## Every player this farm holds anything for: the local one, and whoever has XP,
## a floor, a count or a guest's place here.
func _known_players() -> Array[String]:
	var out: Array[String] = [local_player_id]
	for id: Variant in player_skill_xp.keys() + guest_ids.values() + action_counts.keys() + skill_effect_floor.keys():
		if id is String and id != "" and not id in out:
			out.append(id)
	return out


## The share (0 to 1) of an effect's full cut that `level` has: straight lines
## between the rows of level_curve/effect_share, which start at level 1.
func effect_share(level: int) -> float:
	var rows: Variant = DataManager.get_value(SKILLS_TABLE, "level_curve/effect_share", [])
	if not rows is Array:
		return 0.0
	var last_level: float = 1.0
	var last_share: float = 0.0
	for row: Dictionary in rows:
		var at: float = float(row["level"])
		var share: float = float(row["share"])
		if level <= at:
			return share if at <= last_level else lerpf(last_share, share, (level - last_level) / (at - last_level))
		last_level = at
		last_share = share
	return last_share


## The share a save from the 10-level curve keeps for this skill, or 0.
func effect_floor(skill_id: String, player_id: String = "") -> float:
	var owner_id: String = "" if is_farm_skill(skill_id) else (local_player_id if player_id == "" else player_id)
	var own: Dictionary = skill_effect_floor.get(owner_id, {})
	return clampf(float(own.get(skill_id, 0.0)), 0.0, 1.0)


func has_skill_unlock(unlock_id: String, player_id: String = "") -> bool:
	var unlock: Dictionary = DataManager.get_record(SKILLS_TABLE, unlock_id, "unlocks")
	return not unlock.is_empty() and skill_level(str(unlock["skill"]), player_id) >= int(unlock["level"])


## Line for the skills view: "Calibration  level 2  (60 XP, 150 for level 3)".
func skill_text(skill_id: String, player_id: String = "") -> String:
	var level: int = skill_level(skill_id, player_id)
	var xp: int = skill_xp(skill_id, player_id)
	var progress: String = ("%s XP, top level" % SP811.integer(xp) if level >= max_skill_level()
		else "%s XP, %s for level %s" % [SP811.integer(xp), SP811.integer(xp_for_level(level + 1)), SP811.integer(level + 1)])
	return "%s  level %s  (%s)%s" % [
		DataManager.get_record(SKILLS_TABLE, skill_id, "skills").get("display_name", skill_id),
		SP811.integer(level), progress, "  farm" if is_farm_skill(skill_id) else ""]


## What the skill does at this level, and what it unlocks, for the skills view.
func skill_effects_text(skill_id: String, player_id: String = "") -> String:
	var parts: PackedStringArray = []
	for effect: Dictionary in DataManager.get_records(SKILLS_TABLE, "effects"):
		if effect["skill"] == skill_id:
			parts.append("%s %s %% of base" % [effect["display_name"],
				SP811.number(skill_factor(str(effect["id"]), player_id) * 100.0, 1)])
	for unlock: Dictionary in DataManager.get_records(SKILLS_TABLE, "unlocks"):
		if unlock["skill"] == skill_id:
			parts.append(str(unlock["display_name"]) if has_skill_unlock(str(unlock["id"]), player_id)
				else "Level %s: %s" % [SP811.integer(int(unlock["level"])), unlock["display_name"]])
	return "; ".join(parts) if not parts.is_empty() else "No effect yet"


func max_skill_level() -> int:
	return int(DataManager.get_number(SKILLS_TABLE, "level_curve/max_level", 99.0))


## Host: the player this guest is, new or back again, or "" if already in. Each
## own skill is the better of what the farm has and what the guest brings, up to
## the top level [ASSUMPTION]. `record` is the rest of the guest's own file
## (CoopProfile.record()): see _take_guest_record().
func let_in_guest(key: String, brought: Dictionary, players: Array[String], record: Dictionary = {}) -> String:
	var hashed: String = key.sha256_text()
	var player_id: String = guest_ids.get(hashed, "")
	if player_id in players:
		return ""
	if player_id == "":
		while player_id == "" or player_id in players:
			player_id = "player_%d" % next_player_number
			next_player_number += 1
		if guest_ids.size() >= MAX_KNOWN_GUESTS:
			_forget_a_guest(players)
		guest_ids[hashed] = player_id
	if not player_skill_xp.has(player_id):
		player_skill_xp[player_id] = {}
	for skill: String in skill_ids():
		var xp: int = mini(brought.get(skill, 0), xp_for_level(max_skill_level()))
		if not is_farm_skill(skill) and xp > skill_xp(skill, player_id):
			player_skill_xp[player_id][skill] = xp
			skill_xp_changed.emit(player_id, skill)
	_take_guest_record(player_id, record)
	# Today's ask, if they hold none: a friend who drops in need not wait for the
	# morning (docs/design/quests_levels_story.md section 6, D2).
	if QuestEngine.update_daily_of(self, player_id):
		quests_changed.emit()
	return player_id


## Host: a guest's own record meets this farm's copy of it. This farm is the
## authority for what happens here; the file is the guest's record of everywhere
## else. Nothing is added, so coming again, or by way of another farm, never
## pays twice:
## - Quest points: by quest, the higher of the two, and no more than the quest
##   pays here.
## - XP certificates: one for each quest, on every farm together. One spent
##   anywhere is spent here; one held anywhere is held here, worth no more than
##   the quest gives here.
## - Their own quests: QuestEngine.take_brought().
## Only what this build's quests pay is taken, so a file can't fill the farm,
## and the file is read as CoopProfile.is_record() checked it.
func _take_guest_record(player_id: String, record: Dictionary) -> void:
	var rewards: Dictionary = {}
	for quest: Dictionary in QuestEngine.quests():
		# A daily ask and its certificate stay on their farm: a record names none.
		if QuestEngine.data_problem(quest) == "" and not QuestEngine.is_daily(quest):
			rewards[str(quest["id"])] = quest.get("rewards", {})
	var quests_moved: bool = false
	var certificates_moved: bool = false
	var spent: Variant = record.get("xp_certificates_spent", [])
	for source: Variant in (spent if spent is Array else []):
		if not source is String or int((rewards.get(source, {}) as Dictionary).get(QuestEngine.XP_CERTIFICATE, 0)) <= 0:
			continue
		var gone: Array = xp_certificates_spent.get_or_add(player_id, [])
		if not source in gone:
			gone.append(source)
			certificates_moved = true
		var mine: Dictionary = xp_certificates.get(player_id, {})
		for id: String in mine.keys():
			if xp_certificate_source(id) == source:
				mine.erase(id)
				certificates_moved = true
		if mine.is_empty():
			xp_certificates.erase(player_id)
	var held: Variant = record.get("xp_certificates", {})
	for source: Variant in (held if held is Dictionary else {}):
		var worth: int = int((rewards.get(source, {}) as Dictionary).get(QuestEngine.XP_CERTIFICATE, 0)) if source is String else 0
		if worth <= 0 or not held[source] is int or has_had_xp_certificate(source, player_id):
			continue
		give_xp_certificate(player_id, source, mini(held[source], worth))
	var points: Variant = record.get("quest_points", {})
	for quest_id: Variant in (points if points is Dictionary else {}):
		var pays: int = int((rewards.get(quest_id, {}) as Dictionary).get("quest_points", 0)) if quest_id is String else 0
		if pays <= 0 or not points[quest_id] is int:
			continue
		var here: Dictionary = quest_points.get(player_id, {})
		if mini(points[quest_id], pays) > int(here.get(quest_id, 0)):
			here[quest_id] = mini(points[quest_id], pays)
			quest_points[player_id] = here
			quests_moved = true
	var own: Variant = record.get("quests", {})
	if own is Dictionary and QuestEngine.take_brought(self, player_id, own):
		quests_moved = true
	if quests_moved:
		quests_changed.emit()
	if certificates_moved:
		xp_certificates_changed.emit()


## So strangers can't fill the farm: the first guest who isn't in, and the skills
## they had here.
func _forget_a_guest(players: Array[String]) -> void:
	for hashed: String in guest_ids:
		var player_id: String = guest_ids[hashed]
		if not player_id in players:
			guest_ids.erase(hashed)
			player_skill_xp.erase(player_id)
			skill_effect_floor.erase(player_id)
			action_counts.erase(player_id)
			quest_points.erase(player_id)
			player_quest_state.erase(player_id)
			xp_certificates.erase(player_id)
			xp_certificates_spent.erase(player_id)
			one_use_held.erase(player_id)
			player_loadouts.erase(player_id)
			packs_wet.erase(player_id)
			_cold_kept.erase(player_id)
			for entry: Variant in quest_state.values():
				if entry is Dictionary and entry.get("players") is Array:
					(entry["players"] as Array).erase(player_id)
			return


## Total XP that reaches `level`. Going from level n to n + 1 costs
## base × growth^(n − 1), so the total is base × (growth^(level − 1) − 1) / (growth − 1).
func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var base: float = DataManager.get_number(SKILLS_TABLE, "level_curve/base_xp", 50.0)
	var growth: float = DataManager.get_number(SKILLS_TABLE, "level_curve/growth", 1.1)
	if growth <= 1.0:
		return roundi(base * (level - 1))
	return roundi(base * (pow(growth, level - 1) - 1.0) / (growth - 1.0))


func _level_for_xp(xp: int) -> int:
	var top: int = max_skill_level()
	var base: float = DataManager.get_number(SKILLS_TABLE, "level_curve/base_xp", 50.0)
	var growth: float = DataManager.get_number(SKILLS_TABLE, "level_curve/growth", 1.1)
	var level: int = 1
	if xp > 0 and base > 0.0 and growth > 1.0:
		# The curve turned round; the two loops settle the rounding.
		level = clampi(int(log(xp * (growth - 1.0) / base + 1.0) / log(growth)) + 1, 1, top)
	while level < top and xp >= xp_for_level(level + 1):
		level += 1
	while level > 1 and xp < xp_for_level(level):
		level -= 1
	return level


## A save from the 10-level curve (docs/design/quests_levels_story.md section
## 2.5): XP is multiplied by old_curve/xp_factor, which never lowers a level, and
## each skill keeps the share of its effects it had, so nobody can do less.
func _convert_old_skills() -> void:
	skill_effect_floor.clear()
	_convert_old_xp(farm_skill_xp, "")
	for player: Variant in player_skill_xp:
		_convert_old_xp(player_skill_xp[player], str(player))


func _convert_old_xp(xp_by_skill: Dictionary, owner_id: String) -> void:
	var factor: float = DataManager.get_number(SKILLS_TABLE, "old_curve/xp_factor", 5.0)
	for skill: Variant in xp_by_skill.keys():
		var old_xp: int = clampi(int(xp_by_skill[skill]), 0, MOST_SKILL_XP)
		xp_by_skill[skill] = mini(roundi(old_xp * factor), MOST_SKILL_XP)
		var share: float = _old_effect_share(str(skill), _old_level(old_xp))
		if share > 0.0:
			var own: Dictionary = skill_effect_floor.get_or_add(owner_id, {})
			own[str(skill)] = share


## The level `xp` was on the 10-level curve: base × (level − 1) × level / 2.
func _old_level(xp: int) -> int:
	var top: int = int(DataManager.get_number(SKILLS_TABLE, "old_curve/max_level", 10.0))
	var base: float = DataManager.get_number(SKILLS_TABLE, "old_curve/base_xp", 50.0)
	var level: int = 1
	while level < top and xp >= roundi(base * level * (level + 1) / 2.0):
		level += 1
	return level


## The largest share of its full cut that any effect of `skill_id` had at
## `old_level`, when each old level cut `old_per_level` down to the floor.
func _old_effect_share(skill_id: String, old_level: int) -> float:
	var best: float = 0.0
	for effect: Dictionary in DataManager.get_records(SKILLS_TABLE, "effects"):
		if effect["skill"] != skill_id:
			continue
		var room: float = 1.0 - float(effect.get("floor", 0.0))
		var full: float = minf(room, float(effect["full"]))
		if full > 0.0:
			best = maxf(best, minf(room, float(effect.get("old_per_level", 0.0)) * (old_level - 1)) / full)
	return minf(best, 1.0)


# --- The lab level (docs/design/quests_levels_story.md section 3) ---------------

## 1 to the top level, on the skills' curve. It gates the rows of lab_gates.
func lab_level() -> int:
	return _level_for_xp(lab_xp)


# --- Lab-level gates (section 3.4) ----------------------------------------------
# A row of lab_gates in data/skills.json opens when the lab level is reached AND
# the condition the game already had holds (section 10, 4). The condition stays
# where it was; these only add the level. The host decides: a guest's copy has
# the same lab_xp and lab_gates_kept, so its screens say the same.

## The lab level a gate asks for. 0 if the table has no such row, or the row is
## not built: such a gate is open.
func lab_gate_level(gate_id: String) -> int:
	var row: Dictionary = DataManager.get_record(SKILLS_TABLE, StringName(gate_id), "lab_gates")
	return int(row.get("level", 0)) if row.get("built", true) else 0


## Every row id of lab_gates, built or not.
func all_lab_gate_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in DataManager.get_records(SKILLS_TABLE, "lab_gates"):
		ids.append(str(row["id"]))
	return ids


## True if the lab level lets this row open: it is reached, or the farm kept the
## row from before the gates.
func lab_gate_open(gate_id: String) -> bool:
	return lab_level() >= lab_gate_level(gate_id) or gate_id in lab_gates_kept


## "" if the gate is open, or the reason in plain words:
## "Tier 2 equipment needs lab level 18 (the lab is level 9)."
func lab_gate_problem(gate_id: String, what: String = "") -> String:
	if lab_gate_open(gate_id):
		return ""
	return "%s lab level %s (the lab is level %s)." % ["Needs" if what == "" else what + " needs",
		SP811.integer(lab_gate_level(gate_id)), SP811.integer(lab_level())]


## Short form for a button or a list: "needs lab level 18", or "".
func lab_gate_note(gate_id: String) -> String:
	return "" if lab_gate_open(gate_id) else "needs lab level %s" % SP811.integer(lab_gate_level(gate_id))


## The built rows that open from level `after` + 1 to `upto`, as one phone line:
## "Tier 2 standards (also needs: an OIRM account); Medium lab". "" if none.
func lab_gates_opened_text(after: int, upto: int) -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in DataManager.get_records(SKILLS_TABLE, "lab_gates"):
		var level: int = int(row.get("level", 0))
		if not row.get("built", true) or level <= after or level > upto or str(row["id"]) in lab_gates_kept:
			continue
		var needs: String = str(row.get("needs", ""))
		parts.append(str(row.get("opens", row["id"])) + ("" if needs == "" else " (also needs: %s)" % needs))
	return "; ".join(parts)


## The gate of the next robot: robot_1 for the first, up to the last row there is.
func robot_gate_id() -> String:
	var number: int = robots.size() + 1
	while number > 1 and not DataManager.has_record(SKILLS_TABLE, StringName("robot_%d" % number), "lab_gates"):
		number -= 1
	return "robot_%d" % number


## The lab XP a quest pays on top of its own when it is the provisional way
## through a gate (section 3.2.1): a share of what the lab is short of the level
## of the row that names the quest. 0 if the level is reached, the farm kept the
## row, or no row names it.
func provisional_lab_xp(quest_id: String) -> int:
	var share: float = clampf(DataManager.get_number(SKILLS_TABLE, "lab_level/provisional_gap_share", 0.0), 0.0, 1.0)
	var most: int = 0
	for row: Dictionary in DataManager.get_records(SKILLS_TABLE, "lab_gates"):
		if str(row.get("quest", "")) == quest_id and row.get("built", true) and not str(row["id"]) in lab_gates_kept:
			most = maxi(most, roundi((xp_for_level(int(row.get("level", 0))) - lab_xp) * share))
	return most


## A save from before the gates (section 10, 5): every row it had open, by the
## conditions of that time, is kept open. What it owns stays whatever this says:
## a gate is only asked when something is bought, built, sent or offered.
func _keep_open_gates() -> void:
	lab_gates_kept.clear()
	var had: Dictionary = {
		"tier1": tier1_unlocked,
		"oirm_account": has_oirm_account(),
		"first_contract": contract_state != "",
		"job_board": _best_band >= _band_index_named(jobs_open_band()),
		"accredited_jobs": _best_band >= _gated_jobs_band_index(),
		"collect_spool_card": _had_robot_job(JOB_COLLECT),
		"calibrate_card": _had_robot_job(JOB_CALIBRATE),
	}
	for id: String in all_standard_ids():
		var tier: int = (sensors[id] as DriftingSensor).tier
		if tier >= 2 and (owned_standards.has(id) or (not _is_contract_stock(id) and _tier_condition_problem(id) == "")):
			had["tier%d" % tier] = true
	var building: int = int(lab_build.get("size", 0)) if lab_build.get("kind", "") == "grow" else 0
	# The next size too: it asked for credits and ore and nothing else.
	var top: int = mini(maxi(lab_size, building) + 1, lab_sizes().size() - 1)
	for size: int in range(1, top + 1):
		had["%s_lab" % lab_size_record(size).get("id", "")] = true
	# The first trip to OIRM was open to any bought standard of tier 1 or more.
	for id: String in owned_standards:
		if (sensors[id] as DriftingSensor).tier >= 1:
			had["oirm_account"] = true
	for number: int in range(1, robots.size() + 1):
		had["robot_%d" % number] = true
	# The next one too, if a player could have ordered it.
	for frame: Dictionary in DataManager.get_records(ROBOTS_TABLE, "frames"):
		for player: String in _known_players():
			if owned_standards.has(str(frame.get("required_standard", ""))) and _robot_skill_problem(frame, player) == "":
				had[robot_gate_id()] = true
	for gate: String in had:
		if had[gate] and DataManager.has_record(SKILLS_TABLE, StringName(gate), "lab_gates"):
			lab_gates_kept.append(gate)
	# Not a row of the table: Bram sold the contract's standard with no tier
	# gate once it was earned, and a farm that had earned it keeps that sale.
	if contract_state in ["active", "complete", "fulfilled"]:
		lab_gates_kept.append(KEPT_CONTRACT_SALE)


## True if a robot holds a card of this job, or a player with a robot could
## have added one.
func _had_robot_job(job: String) -> bool:
	for id: Variant in robots:
		for card: Variant in robots[id].get("cards", []):
			if card is Dictionary and card.get("job", "") == job:
				return true
	if robots.is_empty():
		return false
	for player: String in _known_players():
		if _robot_job_skill_gate(job, player) == "":
			return true
	return false



## What every lab XP source is multiplied by: the entry of lab_level/size_xp for
## the lab's size (section 3.2.1). 1 if there is none.
func lab_xp_scale() -> float:
	var scales: Variant = DataManager.get_value(SKILLS_TABLE, "lab_level/size_xp", {})
	if not scales is Dictionary:
		return 1.0
	var scale: Variant = (scales as Dictionary).get(str(lab_size_record().get("id", "")), 1.0)
	return float(scale) if (scale is float or scale is int) and scale > 0.0 else 1.0


## What one lab XP source gives (lab_xp_sources in data/skills.json), times
## `scale`, before the lab's size.
func _lab_source_xp(source_id: String, scale: float = 1.0) -> float:
	return maxf(float(DataManager.get_record(SKILLS_TABLE, source_id, "lab_xp_sources").get("xp", 0)) * scale, 0.0)


## Gives the lab the XP of one of its sources, times `scale` and the lab's size,
## rounded to a whole XP. Anyone's work counts, the manager's and a robot's too.
## It is counted for `player_id` (action_counts) when `counted`: who did it, or
## for a robot's work who programmed or ordered it. Never for the manager, and
## not for what no one player did: an audit, a certificate that comes back, the
## lab grown.
func _award_lab_xp(source_id: String, player_id: String = "", scale: float = 1.0, counted: bool = true) -> void:
	var gained: int = roundi(_lab_source_xp(source_id, scale) * lab_xp_scale())
	if gained <= 0:
		return
	if player_id == "":
		player_id = local_player_id
	if counted and player_id != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(player_id, {}) as Dictionary).get_or_add(source_id, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
		done["xp"] = int(done["xp"]) + gained
	give_lab_xp(gained)


## Lab XP as it is written, with no multiplier: a quest's lump (section 3.2.1),
## and the end of _award_lab_xp.
func give_lab_xp(amount: int) -> void:
	if amount <= 0:
		return
	var before: int = lab_level()
	lab_xp = mini(lab_xp + amount, MOST_SKILL_XP)
	lab_xp_changed.emit()
	if lab_level() > before:
		var opened: String = lab_gates_opened_text(before, lab_level())
		post_phone("LAB LEVEL UP: %s.%s" % [lab_phone_text(), "" if opened == "" else " Open at this level: %s." % opened])
		# The jobs on offer change now, not next morning, as with a new band.
		for gate: String in ["job_board", "accredited_jobs"]:
			var level: int = lab_gate_level(gate)
			if level > before and level <= lab_level() and not gate in lab_gates_kept and not _morning and _board_day >= 0:
				refresh_job_board(GameClock.get_day_index())
				break


## Line for the skills view: "Lab level 2  (60 XP, 105 for level 3)  farm".
func lab_text() -> String:
	var level: int = lab_level()
	var progress: String = ("%s XP, top level" % SP811.integer(lab_xp) if level >= max_skill_level()
		else "%s XP, %s for level %s" % [SP811.integer(lab_xp), SP811.integer(xp_for_level(level + 1)), SP811.integer(level + 1)])
	return "Lab level %s  (%s)  farm" % [SP811.integer(level), progress]


## Under it on the skills view: what feeds the level, and the lab's size.
func lab_effects_text() -> String:
	return "Earned by work done in the lab, by anyone. %s: lab XP × %s" % [lab_size_name(), SP811.number(lab_xp_scale(), 1)]


## For the phone's row: "level 2".
func lab_phone_text() -> String:
	return "level %s" % SP811.integer(lab_level())


## A save from before the lab level (section 9, step 3). The lab is credited for
## what its logs show: each traceable calibration that was not too soon, each
## paid job and each clean audit, at today's source values, the standard's tier
## counted and the lab's size not (the logs do not say how big the lab was). The
## farm's Instrumentation XP is added one for one, and that skill is dropped.
func _credit_lab_from_logs() -> void:
	var credited: float = float(clampi(int(farm_skill_xp.get(OLD_LAB_SKILL, 0)), 0, MOST_SKILL_XP))
	for record: Dictionary in cal_log:
		if not record.get("traceable", str(record.get("standard_id", "")) != "") \
				or int(record.get("days_in_service", 0)) < ceili(int(record.get("previous_interval_days", 0)) / 2.0):
			continue
		var by_robot: bool = str(record.get("programmed_by", "")) != ""
		credited += roundi(_lab_source_xp("lab_robot_calibration" if by_robot else "lab_calibration",
			calibration_xp_scale(str(record.get("standard_id", "")))))
	for result: Dictionary in job_log:
		var paid: Variant = result.get("pay", 0)
		if (paid is int or paid is float) and is_finite(paid):
			credited += roundi(_lab_source_xp("lab_job", maxf(float(paid), 0.0)))
	for report: Dictionary in audit_log:
		# An audit from before reports were marked clean was clean if it passed.
		var clean: Variant = report.get("clean", report.get("passed", false))
		if clean is bool and clean:
			credited += roundi(_lab_source_xp("lab_clean_audit"))
	lab_xp = int(clampf(lab_xp + credited, 0.0, MOST_SKILL_XP))
	farm_skill_xp.erase(OLD_LAB_SKILL)
	if skill_effect_floor.has(""):
		(skill_effect_floor[""] as Dictionary).erase(OLD_LAB_SKILL)
		if (skill_effect_floor[""] as Dictionary).is_empty():
			skill_effect_floor.erase("")


## A save from before every skill was a player's own (section 9, step 4), once.
## Each player the save knows gets the farm's Robotics and Husbandry XP, and the
## share of their effects the farm kept, so nobody loses a level or an effect.
## Then each player's crop XP so far leaves Field Ops for Agronomy, by the
## counter (crop_xp). Field Ops keeps the share of its effects it had, and stays
## at any level that opened something. A player who comes later starts at 1.
func _make_skills_personal() -> void:
	var players: Array[String] = _known_players()
	var farm_floor: Dictionary = skill_effect_floor.get("", {})
	for skill: String in skill_ids():
		if is_farm_skill(skill) or not farm_skill_xp.has(skill):
			continue
		var xp: int = clampi(int(farm_skill_xp[skill]), 0, MOST_SKILL_XP)
		var share: float = clampf(float(farm_floor.get(skill, 0.0)), 0.0, 1.0)
		for player: String in players:
			var own: Dictionary = player_skill_xp.get_or_add(player, {})
			own[skill] = maxi(int(own.get(skill, 0)), xp)
			if share > effect_floor(skill, player):
				(skill_effect_floor.get_or_add(player, {}) as Dictionary)[skill] = share
		farm_skill_xp.erase(skill)
		farm_floor.erase(skill)
	if farm_floor.is_empty():
		skill_effect_floor.erase("")
	if is_farm_skill(CROP_SKILL) or is_farm_skill(OLD_CROP_SKILL) or not CROP_SKILL in skill_ids():
		return
	for player: String in players:
		var own: Dictionary = player_skill_xp.get(player, {})
		var had: int = int(own.get(OLD_CROP_SKILL, 0))
		var moved: int = mini(crop_xp(player), had)
		if moved <= 0:
			continue
		var level: int = _level_for_xp(had)
		var share: float = maxf(effect_share(level), effect_floor(OLD_CROP_SKILL, player))
		var left: int = had - mini(moved, had - xp_for_level(_gate_reached(OLD_CROP_SKILL, level)))
		own[OLD_CROP_SKILL] = left
		own[CROP_SKILL] = mini(int(own.get(CROP_SKILL, 0)) + moved, MOST_SKILL_XP)
		if _has_effect(OLD_CROP_SKILL) and share > effect_share(_level_for_xp(left)) and share > effect_floor(OLD_CROP_SKILL, player):
			(skill_effect_floor.get_or_add(player, {}) as Dictionary)[OLD_CROP_SKILL] = share


## The highest level, up to `level`, at which `skill_id` opens something: an
## unlock of data/skills.json or a robot job's card (data/robots.json). 1 if none.
func _gate_reached(skill_id: String, level: int) -> int:
	var reached: int = 1
	for unlock: Dictionary in DataManager.get_records(SKILLS_TABLE, "unlocks"):
		if unlock["skill"] == skill_id and int(unlock["level"]) <= level:
			reached = maxi(reached, int(unlock["level"]))
	for job: Dictionary in DataManager.get_records(ROBOTS_TABLE, "jobs"):
		var gate: Dictionary = job.get("skill_gate", {})
		if gate.has(skill_id) and int(gate[skill_id]) <= level:
			reached = maxi(reached, int(gate[skill_id]))
	return reached


func _has_effect(skill_id: String) -> bool:
	for effect: Dictionary in DataManager.get_records(SKILLS_TABLE, "effects"):
		if effect["skill"] == skill_id:
			return true
	return false


## Gives the XP of one source in data/skills.json, times `scale`, to the acting
## player, or to the farm for a farm skill, and counts it for that player
## (action_counts). The manager earns none.
func _award_xp(source_id: String, player_id: String = "", scale: float = 1.0) -> void:
	if player_id == MANAGER_ID:
		return
	if player_id == "":
		player_id = local_player_id
	var source: Dictionary = DataManager.get_record(SKILLS_TABLE, source_id, "xp_sources")
	var skill: String = str(source.get("skill", ""))
	var gained: int = roundi(float(source.get("xp", 0)) * scale)
	if gained <= 0 or DataManager.get_record(SKILLS_TABLE, skill, "skills").is_empty():
		return
	var done: Dictionary = (action_counts.get_or_add(player_id, {}) as Dictionary).get_or_add(source_id, { "count": 0, "xp": 0 })
	done["count"] = int(done["count"]) + 1
	done["xp"] = int(done["xp"]) + gained
	give_skill_xp(skill, gained, player_id)


## XP in one skill for one player, counted for no source: a quest's lump, and
## the end of _award_xp.
func give_skill_xp(skill: String, gained: int, player_id: String) -> void:
	if gained <= 0 or player_id == MANAGER_ID or DataManager.get_record(SKILLS_TABLE, skill, "skills").is_empty():
		return
	var farm: bool = is_farm_skill(skill)
	var before: int = skill_xp(skill, player_id)
	if farm:
		farm_skill_xp[skill] = before + gained
	else:
		if not player_skill_xp.has(player_id):
			player_skill_xp[player_id] = {}
		player_skill_xp[player_id][skill] = before + gained
	var owner_id: String = "" if farm else player_id
	skill_xp_changed.emit(owner_id, skill)
	var level: int = _level_for_xp(before + gained)
	if level > _level_for_xp(before):
		skill_leveled.emit(owner_id, skill, level)


# --- Quests (docs/design/quests_levels_story.md section 5) ----------------------

## Looks at the farm's quests: ticks the steps that now hold and pays a finished
## quest, once. With `offers` it also offers those whose gates hold: each morning
## and when a farm is started or opened (SaveGame), not after a command
## (FarmCommands.execute), so an offer never lands on what the command said. On
## the host only: a guest's copy is the host's. `present` is who is on the farm;
## left empty, the session says.
## `played` is the mini-game the command before this look was played with
## (QuestEngine.played_game), or nothing.
func update_quests(present: Array[String] = [], offers: bool = true, played: Dictionary = {}) -> void:
	if FarmCommands.guest:
		return
	if QuestEngine.update(self, players_present() if present.is_empty() else present, offers, played):
		quests_changed.emit()


## Who is on the farm now: the session's players, or the local one alone.
func players_present() -> Array[String]:
	var out: Array[String] = CoopSession.players.duplicate()
	if not local_player_id in out:
		out.append(local_player_id)
	return out


# --- XP certificates (docs/design/quests_levels_story.md section 4.4) ------------

## Gives `player_id` an unspent certificate worth `xp` in any one skill they
## pick. `source` names it (the quest's id). Its id is the source and the farm's
## next certificate number, "source#3", which no other certificate of this farm
## has or will have. Returns the id, or "" if nothing was given. On the host
## only: the quest engine calls it.
func give_xp_certificate(player_id: String, source: String, xp: int) -> String:
	if player_id == "" or player_id == MANAGER_ID or source == "" or xp <= 0:
		return ""
	var held: Dictionary = xp_certificates.get_or_add(player_id, {})
	xp_certificates_given += 1
	var id: String = "%s#%d" % [source, xp_certificates_given]
	held[id] = mini(xp, MOST_SKILL_XP)
	xp_certificates_changed.emit()
	return id


## The certificates `player_id` ("" = the local player) holds: id -> XP. A copy.
func held_xp_certificates(player_id: String = "") -> Dictionary:
	return (xp_certificates.get(_player(player_id), {}) as Dictionary).duplicate()


## The level `skill_id` would reach if `player_id` ("" = the local player) spent
## `xp` on it. The same XP lifts a low level a lot and a high level a little:
## each level costs 10 % more than the one before (data/skills.json).
func level_with_xp(skill_id: String, xp: int, player_id: String = "") -> int:
	return _level_for_xp(skill_xp(skill_id, player_id) + maxi(xp, 0))


## Why `player_id` can't spend this certificate on this skill, or "".
func xp_certificate_problem(certificate_id: String, skill_id: String, player_id: String = "") -> String:
	if not (xp_certificates.get(_player(player_id), {}) as Dictionary).has(certificate_id):
		return "You hold no such XP certificate."
	if not skill_id in skill_ids() or is_farm_skill(skill_id):
		return "That is not a skill of your own."
	if skill_level(skill_id, player_id) >= max_skill_level():
		return "%s is at the top level." % DataManager.get_record(SKILLS_TABLE, skill_id, "skills").get("display_name", skill_id)
	return ""


## Spends one of `player_id`'s certificates on one of their own skills: all its
## XP goes there and the certificate is gone. Returns "" or why not. Counted for
## no source, as a quest's lump is.
func spend_xp_certificate(certificate_id: String, skill_id: String, player_id: String = "") -> String:
	player_id = _player(player_id)
	var problem: String = xp_certificate_problem(certificate_id, skill_id, player_id)
	if problem != "":
		return problem
	var held: Dictionary = xp_certificates[player_id]
	var xp: int = int(held[certificate_id])
	# Gone before it pays, so nothing the XP sets off can spend it again.
	held.erase(certificate_id)
	if held.is_empty():
		xp_certificates.erase(player_id)
	# A daily ask gives its certificate each time it is done, so that one is
	# never written down as spent for good.
	var source: String = xp_certificate_source(certificate_id)
	if not QuestEngine.is_daily_id(source):
		var gone: Array = xp_certificates_spent.get_or_add(player_id, [])
		if not source in gone:
			gone.append(source)
	give_skill_xp(skill_id, xp, player_id)
	xp_certificates_changed.emit()
	return ""


## "" or why saved xp_certificates can't be loaded: player id -> id -> XP, with
## `given`, the farm's count of certificates ever given. Each id ends in its
## number, from 1 to `given`, and no two have the same.
static func xp_certificates_problem(held: Dictionary, given: Variant = 0) -> String:
	if not given is int or given < 0:
		return "'xp_certificates_given' is not a count."
	var numbers: Array[int] = []
	for player: Variant in held:
		var own: Variant = held[player]
		if not player is String or player == "" or typeof(own) != TYPE_DICTIONARY:
			return "'xp_certificates' has an entry that is not a player's certificates."
		for id: Variant in own:
			if not id is String or not own[id] is int or own[id] < 1 or own[id] > MOST_SKILL_XP:
				return "'xp_certificates' has a certificate that is not worth whole XP."
			var number: int = xp_certificate_number(id)
			if number < 1 or number > given or number in numbers:
				return "'xp_certificates' has a certificate with no number of its own."
			numbers.append(number)
	return ""


## Whether `player_id` ("" = the local player) holds a certificate from `source`
## (a quest's id) or has spent one, on this farm or on one they came from.
func has_had_xp_certificate(source: String, player_id: String = "") -> bool:
	player_id = _player(player_id)
	if source in (xp_certificates_spent.get(player_id, []) as Array):
		return true
	for id: String in (xp_certificates.get(player_id, {}) as Dictionary):
		if xp_certificate_source(id) == source:
			return true
	return false


## "" or why saved xp_certificates_spent can't be loaded: player id -> the
## sources spent, each once.
static func xp_certificates_spent_problem(spent: Dictionary) -> String:
	for player: Variant in spent:
		if not player is String or player == "" or not QuestEngine._all_text(spent[player]):
			return "'xp_certificates_spent' has an entry that is not a player's sources."
	return ""


# --- One-use rewards (docs/design/quests_levels_story.md section 9, item 10) -----

## The holder of a reward of the farm's: not a player id.
const FARM_HOLDER: String = "_farm"
## The most of one reward a holder may keep [ASSUMPTION].
const MOST_ONE_USE: int = 9
## Bram's discount on the next standard he sells (P1's reward).
const ONE_USE_DISCOUNT: String = "bram_discount_10"
## The next lab space cleared costs nothing (L4's reward).
const ONE_USE_REFIT: String = "free_lab_refit"
## One day of the lab sitter, free.
const ONE_USE_SITTER: String = "lab_sitter"


## Who holds reward `reward_id` for `player_id` ("" = the local player): the
## farm for a reward of the farm's, else the player.
func _one_use_holder(reward_id: String, player_id: String = "") -> String:
	return FARM_HOLDER if QuestEngine.one_use_of_farm(reward_id) else _player(player_id)


## Gives `holder` (a player id, or FARM_HOLDER) one of reward `reward_id`.
## Returns false when the data has no such reward, the holder is not right for
## it, or they already hold the most. On the host only: the quest engine calls it.
func give_one_use(reward_id: String, holder: String) -> bool:
	if not QuestEngine.has_one_use(reward_id) or holder == "" or holder == MANAGER_ID:
		return false
	if (holder == FARM_HOLDER) != QuestEngine.one_use_of_farm(reward_id):
		return false
	var held: Dictionary = one_use_held.get_or_add(holder, {})
	if int(held.get(reward_id, 0)) >= MOST_ONE_USE:
		return false
	held[reward_id] = int(held.get(reward_id, 0)) + 1
	one_use_changed.emit()
	return true


## How many of `reward_id` `player_id` ("" = the local player) can use: the
## farm's if it is a reward of the farm's.
func one_use_count(reward_id: String, player_id: String = "") -> int:
	return int((one_use_held.get(_one_use_holder(reward_id, player_id), {}) as Dictionary).get(reward_id, 0))


## Uses one. True if there was one to use. The action it is for calls this
## after it has gone through, never before.
func _spend_one_use(reward_id: String, player_id: String = "") -> bool:
	var holder: String = _one_use_holder(reward_id, player_id)
	var held: Dictionary = one_use_held.get(holder, {})
	if int(held.get(reward_id, 0)) < 1:
		return false
	held[reward_id] = int(held[reward_id]) - 1
	if int(held[reward_id]) <= 0:
		held.erase(reward_id)
	if held.is_empty():
		one_use_held.erase(holder)
	one_use_changed.emit()
	return true


## The character's name and parts of `player_id` (the local player's when empty), as
## Loadout makes them: every slot filled, an unknown part the default.
func loadout_of(player_id: String = "") -> Dictionary:
	var kept: Variant = player_loadouts.get(_player(player_id), {})
	var name_text: Variant = (kept as Dictionary).get("name", "") if kept is Dictionary else ""
	return { "name": Loadout.clean_name(name_text), "parts": Loadout.clean((kept as Dictionary).get("parts", {}) if kept is Dictionary else {}) }


## Sets the character's name and parts for `player_id` only (a request carries no
## other player). `choice` is Loadout.encode()'s text: one part index per slot. Returns
## "" or why not; nothing changes when it refuses. A name over Loadout.MAX_NAME is
## refused, not cut. Allowed anywhere: it is paperwork, not farm work.
func set_loadout(character_name: String, choice: String, player_id: String = "") -> String:
	player_id = _player(player_id)
	if character_name.strip_edges().length() > Loadout.MAX_NAME:
		return "A name is %d characters at most." % Loadout.MAX_NAME
	var parts: Dictionary = Loadout.decode(choice)
	if parts.is_empty():
		return "That is not a loadout."
	if not player_loadouts.has(player_id) and player_loadouts.size() > MAX_KNOWN_GUESTS:
		return "The farm knows too many players."
	var entry: Dictionary = { "name": Loadout.clean_name(character_name), "parts": parts }
	if player_loadouts.get(player_id, {}) == entry:
		return ""
	player_loadouts[player_id] = entry
	loadouts_changed.emit()
	return ""


## "" or why saved one_use_held can't be loaded: holder -> reward id -> a count
## from 1 to MOST_ONE_USE, of a reward the data has.
static func one_use_problem(held: Dictionary) -> String:
	for holder: Variant in held:
		var own: Variant = held[holder]
		if not holder is String or holder == "" or typeof(own) != TYPE_DICTIONARY:
			return "'one_use_held' has an entry that is not a holder's rewards."
		for id: Variant in own:
			if not id is String or not own[id] is int or own[id] < 1 or own[id] > MOST_ONE_USE:
				return "'one_use_held' has a reward that is not a count of 1 to %d." % MOST_ONE_USE
			if not QuestEngine.has_one_use(id):
				return "'one_use_held' has a reward the data does not have."
			if (holder == FARM_HOLDER) != QuestEngine.one_use_of_farm(id):
				return "'one_use_held' has a reward held by the wrong kind of holder."
	return ""


## The number at the end of a certificate's id ("thirsty_probe#3" is 3), or 0.
static func xp_certificate_number(certificate_id: String) -> int:
	var at: int = certificate_id.rfind("#")
	var number: String = certificate_id.substr(at + 1)
	return maxi(int(number), 0) if at > 0 and number.is_valid_int() and str(int(number)) == number else 0


## The source a certificate's id names ("thirsty_probe#3" is "thirsty_probe").
static func xp_certificate_source(certificate_id: String) -> String:
	var at: int = certificate_id.rfind("#")
	return certificate_id.substr(0, at) if at > 0 else certificate_id


## A player's quest points on this farm ("" = the local player).
func quest_point_total(player_id: String = "") -> int:
	return QuestEngine.points_of(self, _player(player_id))


## How many times `player_id` ("" = the local player) earned XP from a source.
func action_count(source_id: String, player_id: String = "") -> int:
	return int(_action(source_id, player_id).get("count", 0))


## The XP those times gave, to the player or to the farm.
func action_xp(source_id: String, player_id: String = "") -> int:
	return int(_action(source_id, player_id).get("xp", 0))


func _action(source_id: String, player_id: String) -> Dictionary:
	var own: Dictionary = action_counts.get(local_player_id if player_id == "" else player_id, {})
	return own.get(source_id, {})


## The XP a player has had from the crop sources (those marked "crop" in
## data/skills.json). It is Agronomy's. What a save from before Agronomy had
## given Field Ops moved as the save loaded (_make_skills_personal).
func crop_xp(player_id: String = "") -> int:
	var total: int = 0
	for source: Dictionary in DataManager.get_records(SKILLS_TABLE, "xp_sources"):
		if source.get("crop", false):
			total += action_xp(str(source["id"]), player_id)
	return total


## XP for a finished job (docs/design/quests_levels_story.md section 2.3), by
## the credits it paid after any cut: job_done for each, and job_clean too
## when it was on time and traceable.
func _xp_after_job(result: Dictionary, player_id: String) -> void:
	var paid: float = float(result["pay"])
	_award_lab_xp("lab_job", player_id, paid)
	_award_xp("job_done", player_id, paid)
	if result["on_time"] and result["traceable"]:
		_award_xp("job_clean", player_id, paid)


## XP for a calibration (section 2.2), times the standard's tier scale. An untraceable one, or one made before
## the instrument has run half its interval, gives none, so it can't be repeated
## for XP.
func _xp_after_calibration(record: Dictionary) -> void:
	if not record["traceable"] or int(record["days_in_service"]) < ceili(int(record["previous_interval_days"]) / 2.0):
		return
	var player: String = record["performed_by"]
	var scale: float = calibration_xp_scale(str(record.get("standard_id", "")))
	var by_robot: bool = record.get("programmed_by", "") != ""
	_award_lab_xp("lab_robot_calibration" if by_robot else "lab_calibration", record["programmed_by"] if by_robot else player, scale)
	if not by_robot and get_sensor(record["instrument_id"]).role == "standard":
		_award_lab_xp("calibrate_standard", player, scale)
	if by_robot:
		# A robot's work trains no one's hands: only Robotics XP [ASSUMPTION].
		if robot_of(record["instrument_id"]) != "":
			_award_xp("calibrate_robot", record["programmed_by"], scale)
		return
	if robot_of(record["instrument_id"]) != "":
		_award_xp("calibrate_robot", player, scale)
		_award_xp("calibrate_robot_player", player, scale)
	else:
		_award_xp("calibrate_player", player, scale)
	if not record["as_found_in_tolerance"]:
		_award_xp("calibrate_found_oot", player, scale)
	if record["on_time"]:
		_award_xp("calibrate_on_time", player, scale)
	# Judged on the plain TUR: a Hold the Reading score earns no XP a skip would not.
	if float(record.get("plain_tur", record["tur"])) >= CalUncertainty.tur_clean():
		_award_xp("calibrate_clean_tur", player, scale)


## What a calibration's XP is multiplied by: the entry of calibration_tier_xp
## for the tier of the standard used. 1 if there is no such standard or entry.
func calibration_xp_scale(standard_id: String) -> float:
	var standard: DriftingSensor = get_sensor(standard_id)
	var scales: Variant = DataManager.get_value(SKILLS_TABLE, "calibration_tier_xp", [])
	if standard == null or not scales is Array or (scales as Array).is_empty():
		return 1.0
	var scale: Variant = scales[clampi(standard.tier, 0, (scales as Array).size() - 1)]
	return float(scale) if scale is float or scale is int else 1.0


## A clean audit is everyone's: each player on the farm gets its XP [ASSUMPTION].
func _award_clean_audit_xp() -> void:
	var players: Array = player_skill_xp.keys()
	if not local_player_id in players:
		players.append(local_player_id)
	for player: Variant in players:
		_award_xp("clean_audit", str(player))
	_award_lab_xp("lab_clean_audit", "", 1.0, false)


# --- Robots (docs/design/equipment_skills_robots.md section 3) ------------------

const ROBOTS_TABLE: StringName = &"robots"
const ROBOT_STATES: Array[String] = ["assembling", "commissioning", "released"]
## A new sensor's error is up to this share of its MPE [PLACEHOLDER].
const ROBOT_START_ERROR_RATIO: float = 0.5


func robot_frame(frame_id: String) -> Dictionary:
	return DataManager.get_record(ROBOTS_TABLE, frame_id, "frames")


## The robot a sensor is on ("TR-1"), or "" for any other instrument.
static func robot_of(instrument_id: String) -> String:
	return instrument_id.get_slice("@", 1) if "@" in instrument_id else ""


## True for a sensor of a robot that isn't released: the bench calibrates it,
## but it is not audited and can't cost credibility for falling overdue.
func is_commissioning(instrument_id: String) -> bool:
	var robot: String = robot_of(instrument_id)
	return robot != "" and robots.get(robot, {}).get("state", "") != "released"


## A robot's sensor ids, in data order. None until it is assembled.
func robot_sensor_ids(robot_id: String) -> Array[String]:
	return _robot_sensor_ids({ robot_id: robots[robot_id] }) if robots.has(robot_id) else [] as Array[String]


func _robot_sensor_ids(of_robots: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for robot_id: Variant in of_robots:
		var robot: Dictionary = of_robots[robot_id]
		if robot["state"] == "assembling":
			continue
		for model: Variant in robot_frame(robot["frame"]).get("sensors", []):
			ids.append("%s@%s" % [model, robot_id])
	return ids


## Gives `sensors` exactly the sensors of `of_robots`, keeping those it has.
func _sync_robot_sensors(of_robots: Dictionary) -> void:
	var wanted: Array[String] = _robot_sensor_ids(of_robots)
	for id: Variant in sensors.keys():
		if robot_of(str(id)) != "" and not str(id) in wanted:
			sensors.erase(id)
	for id: String in wanted:
		if sensors.has(id):
			continue
		var sensor: DriftingSensor = DriftingSensor.from_config(id)
		var robot_id: String = robot_of(id)
		sensor.display_name = "%s %s" % [robot_id, sensor.display_name]
		sensor.short_name = "%s %s" % [robot_id, sensor.short_name]
		sensor.max_error = sensor.mpe * MAX_ERROR_MPE_MULTIPLE
		sensor.cal_interval_days = int(_interval_cfg("initial_days", 5.0))
		sensor.reseed(hash("%d:%s" % [world_seed, id]))
		sensor.start_uncalibrated(ROBOT_START_ERROR_RATIO)
		sensors[id] = sensor


## Why a save's robots can't load, or "".
func _robots_dict_problem(saved: Dictionary) -> String:
	for id: Variant in saved:
		var robot: Variant = saved[id]
		if typeof(id) != TYPE_STRING or id == "" or "@" in id:
			return "'robots' has a bad robot id."
		if typeof(robot) != TYPE_DICTIONARY:
			return "Robot '%s' is not a dictionary." % id
		for key: String in ["frame", "name", "state", "ordered_by"]:
			if typeof(robot.get(key)) != TYPE_STRING:
				return "Robot '%s' has no %s." % [id, key]
		if robot_frame(robot["frame"]).is_empty():
			return "Robot '%s' has an unknown frame." % id
		if not robot["state"] in ROBOT_STATES or typeof(robot.get("done_day")) != TYPE_INT:
			return "Robot '%s' has a bad state or done_day." % id
		var cards: Variant = robot.get("cards", [])
		if typeof(cards) != TYPE_ARRAY or not (cards as Array).all(_is_card):
			return "Robot '%s' has a bad job card." % id
		for key: String in ["holding", "override", "override_logged"]:
			if typeof(robot.get(key, false)) != TYPE_BOOL:
				return "Robot '%s' has a bad %s." % [id, key]
		if typeof(robot.get("override_by", "")) != TYPE_STRING:
			return "Robot '%s' has a bad override_by." % id
	return ""


func robot_cost_text(frame_id: String) -> String:
	var frame: Dictionary = robot_frame(frame_id)
	var spools: int = int(frame.get("cost_spools", 0))
	return "%s + %s silk spool%s" % [
		lab_cost_text(int(frame.get("cost_credits", 0)), int(frame.get("cost_ore", 0))),
		SP811.integer(spools), "" if spools == 1 else "s"]


## Why `player_id` can't order this robot now, or "". One build at a time
## [ASSUMPTION].
func robot_build_problem(frame_id: String, player_id: String = "") -> String:
	var frame: Dictionary = robot_frame(frame_id)
	if frame.is_empty():
		return "There is no such robot."
	for id: Variant in robots:
		if robots[id]["state"] == "assembling":
			return "%s is still being assembled." % robots[id]["name"]
	var ordinals: Array[String] = ["The first", "A second", "A third", "A fourth"]
	var gate: String = lab_gate_problem(robot_gate_id(), "%s robot" % (ordinals[robots.size()] if robots.size() < ordinals.size() else "Another"))
	if gate != "":
		return gate
	var skill_problem: String = _robot_skill_problem(frame, player_id)
	if skill_problem != "":
		return skill_problem
	var standard: String = str(frame.get("required_standard", ""))
	if standard != "":
		var title: String = instrument_name(standard, true)
		if not owned_standards.has(standard):
			return "Needs the %s: its sensors are calibrated against it." % title
		if at_oirm.has(standard):
			return "The %s is at OIRM until day %s." % [title, SP811.integer(int(at_oirm[standard]))]
		var fault: String = standard_problem(standard)
		if fault != "":
			return "The %s is %s." % [title, fault]
	# Without all of them the robot could never be released.
	for model: Variant in frame.get("sensors", []):
		var by: String = str(DataManager.get_value(DRIFT_TABLE, "robot_sensors/%s/calibrated_by" % model, ""))
		if not owned_standards.has(by):
			return "Needs the %s: its %s is calibrated against it." % [instrument_name(by, true),
				str(DataManager.get_value(DRIFT_TABLE, "robot_sensors/%s/short_name" % model, model))]
	if credits < int(frame.get("cost_credits", 0)) or crystal_ore < int(frame.get("cost_ore", 0)) \
			or optical_silk_spools < int(frame.get("cost_spools", 0)):
		return "Costs %s; you have %s CR, %s crystal ore and %s silk." % [robot_cost_text(frame_id),
			SP811.integer(credits), SP811.integer(crystal_ore), spool_count_text()]
	return ""


## Orders a robot: pays, and assembly finishes some mornings later. Returns ""
## or why not.
func build_robot(frame_id: String, player_id: String = "") -> String:
	if player_id == "":
		player_id = local_player_id
	var problem: String = robot_build_problem(frame_id, player_id)
	if problem != "":
		return problem
	var frame: Dictionary = robot_frame(frame_id)
	_lab_pay(int(frame.get("cost_credits", 0)), int(frame.get("cost_ore", 0)))
	for i: int in int(frame.get("cost_spools", 0)):
		_take_spool(true)
	silk_changed.emit(optical_silk_spools)
	var number: int = robots.size() + 1
	while robots.has("%s-%d" % [frame.get("id_prefix", "R"), number]):
		number += 1
	var id: String = "%s-%d" % [frame.get("id_prefix", "R"), number]
	robots[id] = {
		"frame": frame_id,
		"name": "%s %s" % [frame.get("display_name", frame_id), id],
		"state": "assembling",
		"done_day": GameClock.get_day_index() + maxi(int(frame.get("assembly_days", 1)), 1),
		"ordered_by": player_id,
	}
	post_phone("ROBOT: %s is being assembled, ready the morning of day %s." % [
		robots[id]["name"], SP811.integer(robots[id]["done_day"])])
	robots_changed.emit()
	return ""


## Each morning: assembled robots come to the bench, uncalibrated.
func _finish_robot_builds(day: int) -> void:
	for id: Variant in robots:
		var robot: Dictionary = robots[id]
		if robot["state"] != "assembling" or day < int(robot["done_day"]):
			continue
		robot["state"] = "commissioning"
		_sync_robot_sensors(robots)
		_award_xp("build_robot", robot["ordered_by"])
		_award_lab_xp("lab_robot", robot["ordered_by"])
		post_phone("ROBOT: %s is assembled. Calibrate its %s sensors at the bench, then release it at Bram's bay." % [
			robot["name"], SP811.integer(robot_sensor_ids(str(id)).size())])
		robots_changed.emit()


## What a robot's sensor still needs before release, or "".
func robot_sensor_problem(instrument_id: String) -> String:
	var record: Dictionary = last_cal_records.get(instrument_id, {})
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if record.is_empty() or sensor == null:
		return "not calibrated"
	if not record.get("traceable", false):
		return "last calibration not traceable"
	if record.get("suspect", false) or suspect_units.has(instrument_id):
		return "suspect, recalled"
	if record.get("result", "") != CalUncertainty.PASS:
		return "last result %s: calibrate it again" % record.get("result", "?")
	return "overdue" if sensor.is_overdue(GameClock.get_day_index()) else ""


## Why a robot can't be released to work, or "".
func robot_release_problem(robot_id: String) -> String:
	if not robots.has(robot_id):
		return "There is no such robot."
	var robot: Dictionary = robots[robot_id]
	if robot["state"] == "assembling":
		return "%s is still being assembled." % robot["name"]
	if robot["state"] == "released":
		return "%s is already released." % robot["name"]
	var ids: Array[String] = robot_sensor_ids(robot_id)
	if ids.is_empty():
		return "%s has no sensors to calibrate." % robot["name"]
	var left: PackedStringArray = []
	for id: String in ids:
		var problem: String = robot_sensor_problem(id)
		if problem != "":
			left.append("%s (%s)" % [instrument_name(id), problem])
	return "" if left.is_empty() else "Not ready: %s." % ", ".join(left)


## Commissions a robot: every sensor's last calibration must be a traceable,
## in-date pass. From now on its sensors are audited. Returns "" or why not.
func release_robot(robot_id: String, player_id: String = "") -> String:
	var problem: String = robot_release_problem(robot_id)
	if problem != "":
		return problem
	robots[robot_id]["state"] = "released"
	_award_xp("commission_robot", player_id)
	_award_lab_xp("lab_robot", player_id)
	post_phone("ROBOT: %s is commissioned and released. Its sensors are on the audit list." % robots[robot_id]["name"])
	robots_changed.emit()
	return ""


# --- Robot job cards (docs/design/equipment_skills_robots.md section 3.3) ------

const JOB_WATER: String = "water"
const JOB_CALIBRATE: String = "calibrate"
const JOB_COLLECT: String = "collect_spool"
## What can start each job's card: a clock time, soil that reads off target, an
## instrument coming due, or a silk spool that is ready.
const CARD_TRIGGERS: Dictionary[String, Array] = { JOB_WATER: ["clock", "soil"], JOB_CALIBRATE: ["clock", "due"],
	JOB_COLLECT: ["spool"] }
## The robot sensors each job wears, by one use a job.
const JOB_WEARS: Dictionary[String, Array] = {
	JOB_WATER: ["robot_joint_encoder", "robot_tank_pressure", "robot_soil_probe"],
	JOB_CALIBRATE: ["robot_joint_encoder"],
	JOB_COLLECT: ["robot_joint_encoder", "robot_grip_torque"],
}
## A "due" card starts this many days before its instrument is due [PLACEHOLDER].
const DUE_CARD_LEAD_DAYS: int = 1
## A soil card starts once the robot's probe reads this share of a crop's
## tolerance band away from its target [PLACEHOLDER].
const SOIL_CARD_BAND_RATIO: float = 0.25
## How far off a trim is with the tank gauge at its MPE [PLACEHOLDER].
const TANK_DOSE_ERROR_AT_MPE: float = 0.1


## Job cards a robot can hold: one per Robotics level up to the table's end.
func robot_card_slots(player_id: String = "") -> int:
	var slots: Variant = DataManager.get_value(ROBOTS_TABLE, "job_slots_by_level", [1])
	if typeof(slots) != TYPE_ARRAY or (slots as Array).is_empty():
		return 0
	return int(slots[clampi(skill_level("robotics", player_id), 1, (slots as Array).size()) - 1])


func robot_cards(robot_id: String) -> Array:
	return robots.get(robot_id, {}).get("cards", [])


func _robot_program_problem(robot_id: String) -> String:
	if not robots.has(robot_id):
		return "There is no such robot."
	if robots[robot_id]["state"] != "released":
		return "%s is not released." % robots[robot_id]["name"]
	if not relay_has_los():
		return "No line of sight to the relay. %s keeps its last program." % robots[robot_id]["name"]
	return ""


## Adds a WATER card: the robot trims the irrigation set points of growing
## crops by its own soil probe. "clock" runs at `hour` every `every_days` days,
## first at the next such time; "soil" runs when the soil reads off target.
## Returns "" or why not.
func add_robot_card(robot_id: String, trigger: String, hour: int = 6, every_days: int = 1, player_id: String = "") -> String:
	if player_id == "":
		player_id = local_player_id
	var problem: String = _robot_program_problem(robot_id)
	if problem != "":
		return problem
	var card: Dictionary = { "trigger": trigger, "job": JOB_WATER, "hour": hour, "every_days": every_days,
		"last_day": _latest_day_at(hour) + 1 - every_days, "added_by": player_id }
	if not _is_card(card):
		return "There is no such job card."
	if robot_cards(robot_id).size() >= robot_card_slots(player_id):
		return "%s has no free job slot." % robots[robot_id]["name"]
	robots[robot_id]["cards"] = robot_cards(robot_id) + [card]
	robots_changed.emit()
	return ""


## Adds a CALIBRATE card for `target`, a unit the bench calibrates, against the
## standard it always uses. "due" runs as the target comes due, "clock" as in
## add_robot_card. Returns "" or why not.
func add_robot_calibrate_card(robot_id: String, target: String, trigger: String = "due", hour: int = 6,
		every_days: int = 1, player_id: String = "") -> String:
	if player_id == "":
		player_id = local_player_id
	var problem: String = _robot_program_problem(robot_id)
	if problem == "":
		problem = robot_job_gate(JOB_CALIBRATE, player_id)
	if problem == "":
		problem = _robot_target_problem(robot_id, target, player_id)
	if problem != "":
		return problem
	# A due card may run at once; a clock card waits for its next time.
	var last_day: int = _latest_day_at(hour) + (-1 if trigger == "due" else 1 - every_days)
	var card: Dictionary = { "trigger": trigger, "job": JOB_CALIBRATE, "hour": hour, "every_days": every_days,
		"last_day": last_day, "added_by": player_id, "target": target }
	if not _is_card(card):
		return "There is no such job card."
	if robot_cards(robot_id).size() >= robot_card_slots(player_id):
		return "%s has no free job slot." % robots[robot_id]["name"]
	robots[robot_id]["cards"] = robot_cards(robot_id) + [card]
	robots_changed.emit()
	return ""


## Adds a COLLECT SPOOL card: the robot picks up the dome's silk spool once it is
## ready. Returns "" or why not.
func add_robot_collect_card(robot_id: String, player_id: String = "") -> String:
	if player_id == "":
		player_id = local_player_id
	var problem: String = _robot_program_problem(robot_id)
	if problem == "":
		problem = robot_job_gate(JOB_COLLECT, player_id)
	if problem == "":
		problem = robot_collect_problem(robot_id)
	if problem != "":
		return problem
	if robot_cards(robot_id).size() >= robot_card_slots(player_id):
		return "%s has no free job slot." % robots[robot_id]["name"]
	robots[robot_id]["cards"] = robot_cards(robot_id) + [{ "trigger": "spool", "job": JOB_COLLECT, "hour": 6, "every_days": 1,
		"last_day": _latest_day_at(6), "added_by": player_id }]
	robots_changed.emit()
	return ""


## What this robot's grip still needs before it is given a COLLECT SPOOL card, or
## "". Only the calibration record counts: the true error is hidden.
func robot_collect_problem(robot_id: String) -> String:
	var grip: String = "robot_grip_torque@" + robot_id
	var problem: String = robot_sensor_problem(grip)
	return "" if problem == "" else "COLLECT SPOOL cards need a calibrated grip. %s: %s." % [instrument_name(grip, true), problem]


## The Robotics a player needs to order the next robot of this frame, or "".
func _robot_skill_problem(frame: Dictionary, player_id: String = "") -> String:
	var needs: int = int(frame.get("robotics_level", 1)) + robots.size() * int(frame.get("extra_robot_levels", 0))
	return "" if skill_level("robotics", player_id) >= needs else "Needs Robotics level %s." % SP811.integer(needs)


## What a job's card still needs, or "": the lab level of its row (lab_gate in
## data/robots.json, section 3.4), then the player's skill levels.
func robot_job_gate(job: String, player_id: String = "") -> String:
	var row: String = str(DataManager.get_record(ROBOTS_TABLE, job, "jobs").get("lab_gate", ""))
	var gate: String = "" if row == "" else lab_gate_problem(row, "%s cards" % job.replace("_", " ").to_upper())
	return gate if gate != "" else _robot_job_skill_gate(job, player_id)


## The skill levels a job's card still needs, or "".
func _robot_job_skill_gate(job: String, player_id: String = "") -> String:
	var gate: Dictionary = DataManager.get_record(ROBOTS_TABLE, job, "jobs").get("skill_gate", {})
	var missing: PackedStringArray = []
	for skill: Variant in gate:
		if skill_level(str(skill), player_id) < int(gate[skill]):
			missing.append("%s level %s" % [DataManager.get_record(SKILLS_TABLE, str(skill), "skills").get("display_name", skill),
				SP811.integer(int(gate[skill]))])
	return "" if missing.is_empty() else "%s cards need %s." % [
		job.replace("_", " ").to_upper(), " and ".join(missing)]


## The units a robot can be given a CALIBRATE card for.
func robot_calibrate_targets(robot_id: String, player_id: String = "") -> Array[String]:
	return bench_unit_ids().filter(func(id: String) -> bool:
		return _robot_target_problem(robot_id, id, player_id) == "")


## The units in service it can't have a CALIBRATE card for: each reason -> their ids.
func robot_calibrate_gaps(robot_id: String, player_id: String = "") -> Dictionary:
	var gaps: Dictionary = {}
	for id: String in bench_unit_ids():
		var problem: String = _robot_target_problem(robot_id, id, player_id)
		if problem != "":
			gaps.get_or_add(problem, []).append(id)
	return gaps


## Why a robot's CALIBRATE card can't be for this instrument, or "". A robot
## never calibrates itself, and it leaves the standards to people [ASSUMPTION].
func _robot_target_problem(robot_id: String, target: String, player_id: String) -> String:
	if not target in bench_unit_ids():
		return "The bench calibrates no such unit."
	if robot_of(target) == robot_id:
		return "A robot never calibrates itself."
	var budget: Dictionary = calibration_budget(target, player_id, true)
	if not budget["clean"]:
		return "With %s doing it, TUR %s:1 is under %s:1." % [robots[robot_id]["name"], SP811.number(budget["tur"], 1),
			SP811.number(CalUncertainty.tur_clean(), 0)]
	return ""


func remove_robot_card(robot_id: String, index: int) -> String:
	var problem: String = _robot_program_problem(robot_id)
	if problem != "":
		return problem
	var cards: Array = robot_cards(robot_id).duplicate()
	if index < 0 or index >= cards.size():
		return "There is no such job card."
	cards.remove_at(index)
	robots[robot_id]["cards"] = cards
	robots_changed.emit()
	return ""


func robot_card_text(card: Dictionary) -> String:
	var job: String = "WATER all plots"
	if card["job"] == JOB_CALIBRATE:
		job = "CALIBRATE %s" % instrument_name(card["target"], true)
	elif card["job"] == JOB_COLLECT:
		job = "COLLECT SPOOL"
	match card["trigger"]:
		"spool":
			return job + " when it is ready"
		"soil":
			return job + " when the soil reads off target"
		"due":
			return job + " as it comes due"
	return job + " at %02d:00 %s" % [card["hour"],
		"every day" if card["every_days"] == 1 else "every %s days" % SP811.integer(card["every_days"])]


static func _is_card(card: Variant) -> bool:
	if typeof(card) != TYPE_DICTIONARY:
		return false
	for key: String in ["hour", "every_days", "last_day"]:
		if typeof(card.get(key)) != TYPE_INT:
			return false
	for key: String in ["trigger", "job", "added_by"]:
		if typeof(card.get(key)) != TYPE_STRING:
			return false
	if typeof(card.get("target", "")) != TYPE_STRING or (card["job"] == JOB_CALIBRATE and not card.has("target")):
		return false
	return card["trigger"] in CARD_TRIGGERS.get(card["job"], []) \
			and card["hour"] >= 0 and card["hour"] < 24 and card["every_days"] >= 1


## The last game day whose `hour` has come (0 before the first).
func _latest_day_at(hour: int) -> int:
	var day: int = GameClock.get_day_index()
	return day if GameClock.elapsed_at_hour(day, float(hour)) <= GameClock.elapsed_days + BAND_EPSILON else day - 1


## Each released robot runs the first card whose trigger holds. It needs no
## line of sight for that.
func _run_robot_cards() -> void:
	for id: Variant in robots:
		if robots[id]["state"] != "released":
			continue
		_update_interlock(str(id))
		if is_robot_holding(str(id)):
			continue
		for card: Dictionary in robot_cards(str(id)):
			if not _card_is_due(str(id), card):
				continue
			card["last_day"] = _latest_day_at(card["hour"])
			match card["job"]:
				JOB_CALIBRATE:
					_robot_calibrate(str(id), card)
				JOB_COLLECT:
					_robot_collect(str(id), card["added_by"])
				_:
					_robot_water(str(id), card["added_by"])
			_update_interlock(str(id))
			break


func _card_is_due(robot_id: String, card: Dictionary) -> bool:
	if card["trigger"] == "clock":
		return _latest_day_at(card["hour"]) - int(card["last_day"]) >= int(card["every_days"])
	if card["trigger"] == "spool":
		return is_spool_ready()
	if card["trigger"] == "due":
		# Tried once a day, so one that can't be done isn't reported every tick.
		var target: DriftingSensor = get_sensor(card["target"])
		return target != null and _latest_day_at(card["hour"]) > int(card["last_day"]) \
				and target.cal_due_day - GameClock.get_day_index() <= DUE_CARD_LEAD_DAYS
	# Off by a plot it can't bring the soil it reads on target, so it tries once
	# a day [PLACEHOLDER] instead of every tick.
	if _robot_plot_offset(robot_id) != 0 and _latest_day_at(card["hour"]) <= int(card["last_day"]):
		return false
	for cell: Vector3i in plantings:
		var limit: float = float(crop(plantings[cell]["crop_id"]).get("tolerance_band", 0.0)) * SOIL_CARD_BAND_RATIO
		if absf(_robot_soil_gap(robot_id, cell)) > limit and _robot_trim_steps(robot_id, cell) != 0:
			return true
	return false


## The crop's target less what the robot's own probe reads (fractions). 0.0 for
## a crop that is ready, whose soil no longer counts.
func _robot_soil_gap(robot_id: String, cell: Vector3i) -> float:
	var probe: DriftingSensor = get_sensor("robot_soil_probe@" + robot_id)
	if probe == null or is_crop_ready(cell):
		return 0.0
	var reading: float = soil_moisture(cell) * 100.0 + probe.error
	if probe.resolution > 0.0:
		reading = snappedf(reading, probe.resolution)
	return float(crop(plantings[cell]["crop_id"]).get("soil_moisture_target", 0.0)) - reading / 100.0


## Set point steps that bring the robot's reading to the target, as far as the
## set point can still move.
func _robot_trim_steps(robot_id: String, cell: Vector3i) -> int:
	var setpoint: float = plantings[cell]["setpoint"]
	var steps: int = roundi(_robot_soil_gap(robot_id, cell) / SETPOINT_STEP)
	return clampi(steps, -roundi(setpoint / SETPOINT_STEP), roundi((1.0 - setpoint) / SETPOINT_STEP))


## WATER: trims every growing crop's set point, as well as its joints and tank
## let it. A job that changes nothing earns no XP and isn't reported.
func _robot_water(robot_id: String, player_id: String) -> void:
	# Every plot is read before any is trimmed: a trim can land on the next one.
	var steps_for: Dictionary = {}
	for cell: Vector3i in plantings:
		var steps: int = roundi(_robot_trim_steps(robot_id, cell) * _robot_dose(robot_id))
		if steps != 0:
			steps_for[cell] = steps
	if steps_for.is_empty():
		return
	var trimmed: int = 0
	for cell: Vector3i in steps_for:
		var lands: Vector3i = cell + Vector3i(_robot_plot_offset(robot_id), 0, 0)
		if not plantings.has(lands):
			continue
		var before: float = plantings[lands]["setpoint"]
		if adjust_setpoint(lands, steps_for[cell]) != before:
			trimmed += 1
	_wear_robot(robot_id, JOB_WATER)
	if trimmed > 0:
		_award_xp("robot_job", player_id)
		post_phone("ROBOT: %s trimmed the irrigation set point of %s plot%s by its own soil probe." % [
			robots[robot_id]["name"], SP811.integer(trimmed), "" if trimmed == 1 else "s"])


## CALIBRATE: the robot calibrates the card's unit against its standard, taking
## no bench time [ASSUMPTION]. It won't use a standard that isn't traceable.
func _robot_calibrate(robot_id: String, card: Dictionary) -> void:
	var player: String = card["added_by"]
	var target: String = card["target"]
	var record: Dictionary = {}
	var problem: String = _robot_target_problem(robot_id, target, player)
	if problem == "":
		var standard_id: String = get_sensor(target).calibrated_by
		var fault: String = standard_problem(standard_id)
		if fault != "":
			problem = "The %s is %s." % [instrument_name(standard_id, true), fault]
	if problem == "":
		record = calibrate(target, player, true, 0.0, robot_id)
		problem = record.get("reason", "")
	if problem != "":
		post_phone("ROBOT: %s did not calibrate the %s. %s" % [robots[robot_id]["name"], instrument_name(target, true), problem])
		return
	_wear_robot(robot_id, JOB_CALIBRATE)
	# As for a player's calibration: no XP before half the interval has run.
	if int(record["days_in_service"]) >= ceili(int(record["previous_interval_days"]) / 2.0):
		_award_xp("robot_job", player)
	post_phone("ROBOT: %s calibrated the %s: %s, TUR %s:1." % [robots[robot_id]["name"], instrument_name(target, true),
		record["result"], SP811.number(record["tur"], 1)])


## COLLECT SPOOL: the robot picks up the ready spool for the farm. Not reported:
## there can be many a day. A grip that is out of tolerance, which works only with
## the interlock overridden, may damage it (section 3.4).
func _robot_collect(robot_id: String, player_id: String) -> void:
	if not is_spool_ready():
		return
	var grip: DriftingSensor = get_sensor("robot_grip_torque@" + robot_id)
	var damaged: bool = grip != null and grip.get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE \
			and rng.randf() < DataManager.get_number(ITEMS_TABLE, "optical_silk_spool/bad_grip_damage_chance", 0.0)
	collect_spool(player_id, true, damaged)
	_wear_robot(robot_id, JOB_COLLECT)


func _wear_robot(robot_id: String, job: String) -> void:
	for model: String in JOB_WEARS[job]:
		var sensor: DriftingSensor = get_sensor("%s@%s" % [model, robot_id])
		if sensor != null:
			sensor.add_usage(1.0)


## How far off a robot's work is, as a share of the unit's MPE, when its worst
## sensor is at its own MPE.
func robot_fraction_of_mpe() -> float:
	return DataManager.get_number(DRIFT_TABLE, "calibration_uncertainty/robot_fraction_of_mpe", 0.0)


## The hidden error a robot puts into a calibration of a unit with this MPE: that
## of its worst sensor, scaled [ASSUMPTION]. 0.0 for no robot.
func _robot_cal_error(robot_id: String, mpe: float) -> float:
	var worst: float = 0.0
	for id: String in robot_sensor_ids(robot_id):
		var sensor: DriftingSensor = get_sensor(id)
		if absf(sensor.error / sensor.mpe) > absf(worst):
			worst = sensor.error / sensor.mpe
	return worst * robot_fraction_of_mpe() * mpe


## How many plots along x its water lands from where it was sent: 0, or one
## plot toward the joint encoder's error once that is out of tolerance.
func _robot_plot_offset(robot_id: String) -> int:
	var encoder: DriftingSensor = get_sensor("robot_joint_encoder@" + robot_id)
	if encoder == null or encoder.get_band() != DriftingSensor.Band.OUT_OF_TOLERANCE:
		return 0
	return 1 if encoder.error > 0.0 else -1


## The share of a trim it delivers. A tank gauge that reads high doses low.
func _robot_dose(robot_id: String) -> float:
	var gauge: DriftingSensor = get_sensor("robot_tank_pressure@" + robot_id)
	return 1.0 if gauge == null else 1.0 - TANK_DOSE_ERROR_AT_MPE * gauge.error / gauge.mpe


# --- Robot interlock (section 3.3) ---------------------------------------------

## The robot's sensors that are out of tolerance, in data order.
func robot_out_of_tolerance(robot_id: String) -> Array[String]:
	return robot_sensor_ids(robot_id).filter(func(id: String) -> bool:
		return get_sensor(id).get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE)


## True while the interlock keeps a released robot from working.
func is_robot_holding(robot_id: String) -> bool:
	return robots.has(robot_id) and robots[robot_id]["state"] == "released" \
			and not is_interlock_overridden(robot_id) and not robot_out_of_tolerance(robot_id).is_empty()


func is_interlock_overridden(robot_id: String) -> bool:
	return robots.get(robot_id, {}).get("override", false)


## The names of the sensors out of tolerance, without the robot's: "grip torque".
func robot_bad_sensor_names(robot_id: String) -> String:
	var names: PackedStringArray = []
	for id: String in robot_out_of_tolerance(robot_id):
		names.append(get_sensor(id).short_name.trim_prefix(robot_id + " "))
	return " and ".join(names)


## Says when a robot starts to hold. With every sensor back in tolerance the
## interlock arms itself again.
func _update_interlock(robot_id: String) -> void:
	var robot: Dictionary = robots[robot_id]
	var was_stopped: bool = robot.get("holding", false) or robot.get("override", false)
	if robot_out_of_tolerance(robot_id).is_empty():
		if was_stopped:
			robot["holding"] = false
			robot["override"] = false
			post_phone("ROBOT: %s: all sensors in tolerance. Interlock armed." % robot["name"])
			robots_changed.emit()
	elif not was_stopped:
		robot["holding"] = true
		post_phone("ROBOT: %s: %s out of tolerance. Holding." % [robot["name"], robot_bad_sensor_names(robot_id)])
		robots_changed.emit()


## Lets a holding robot work with bad sensors, or arms its interlock again. Its
## log keeps the override, and who did it last, until an audit clears it.
## Returns "" or why not.
func set_interlock_override(robot_id: String, on: bool, player_id: String = "") -> String:
	var problem: String = _robot_program_problem(robot_id)
	if problem != "":
		return problem
	var robot: Dictionary = robots[robot_id]
	if on and not is_robot_holding(robot_id):
		return "%s is not holding." % robot["name"]
	if not on and not is_interlock_overridden(robot_id):
		return "%s's interlock is armed." % robot["name"]
	robot["override"] = on
	robot["holding"] = not on and not robot_out_of_tolerance(robot_id).is_empty()
	if on:
		robot["override_logged"] = true
		robot["override_by"] = local_player_id if player_id == "" else player_id
	post_phone("ROBOT: %s: interlock %s." % [robot["name"], "OVERRIDDEN" if on else "armed"])
	robots_changed.emit()
	return ""


## Vance's finding for each robot whose interlock was overridden since the last
## audit. Reading the log clears it, unless the override is still on.
func _interlock_findings() -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for id: Variant in robots:
		var robot: Dictionary = robots[id]
		if robot.get("override_logged", false):
			findings.append({ "robot_id": str(id), "fine": AuditEngine.interlock_fine() })
			robot["override_logged"] = is_interlock_overridden(str(id))
			if not robot["override_logged"]:
				robot.erase("override_by")
	return findings


# --- Relay lock (section 1.4 #4, section 1.7) ---------------------------------

## A rover reports its line of sight to the relay here.
func set_rover_uplink(rover_id: String, has_los: bool) -> void:
	if FarmCommands.guest:
		return  # the host's rover says
	if rover_id == TUNNEL_ROVER:
		return  # it sees a beacon, not the relay
	if rover_uplinks.has(rover_id) and (rover_uplinks[rover_id] == true) == has_los:
		return
	rover_uplinks[rover_id] = has_los
	_hold_relay_lock()


## True while the orbital relay passes OIRM time: some rover sees it, or no
## rover has reported yet [ASSUMPTION].
func relay_has_los() -> bool:
	return rover_uplinks.is_empty() or true in rover_uplinks.values()


func is_relay_disciplined(standard_id: String) -> bool:
	var sensor: DriftingSensor = get_sensor(standard_id)
	return sensor != null and sensor.relay_disciplined


## True for an owned relay-disciplined standard that is locked right now. It
## does not drift; without the lock it is in holdover and drifts by aging.
func is_relay_locked(standard_id: String) -> bool:
	return is_relay_disciplined(standard_id) and owned_standards.has(standard_id) and relay_has_los()


## A locked standard is held to OIRM time and its certificate stays in date. In
## holdover nothing renews the certificate, so it lapses after the interval.
func _hold_relay_lock() -> void:
	if not relay_has_los():
		return
	var today: int = GameClock.get_day_index()
	for id: String in standard_ids():
		var sensor: DriftingSensor = sensors[id]
		if not sensor.relay_disciplined or not certificates.has(id):
			continue
		var lapsed: bool = sensor.is_overdue(today)
		sensor.error = 0.0
		sensor.cal_due_day = today + sensor.cal_interval_days
		if certificates[id]["due_day"] != sensor.cal_due_day:
			# A copy: the certificate log keeps the one that was issued.
			certificates[id] = certificates[id].duplicate()
			certificates[id]["due_day"] = sensor.cal_due_day
		if lapsed:
			post_phone("OIRM: %s locked to the relay again. Its certificate is valid." % instrument_name(id, true))
			oirm_changed.emit()


func _note_holdover_lapses(day: int) -> void:
	for id: String in standard_ids():
		var sensor: DriftingSensor = sensors[id]
		if sensor.relay_disciplined and day == sensor.cal_due_day + 1:
			post_phone("OIRM: %s out of lock too long. Its certificate has lapsed until it locks to the relay again." % instrument_name(id, true))
			oirm_changed.emit()


# --- Phone, dispatches, audits ------------------------------------------------

func post_phone(text: String) -> void:
	phone_log.append(text)
	phone_count += 1
	while phone_log.size() > PHONE_LOG_MAX:
		phone_log.remove_at(0)
	phone_message.emit(text)


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)


## Grows the pocket that replaces each dug one whose day has come: the host's
## clock only, and a guest is told. Oldest first; a draw that finds no room waits.
func _grow_pockets(day: int) -> void:
	if FarmCommands.guest or pocket_pending.is_empty() or new_pockets.size() >= OrePocket.MAX_NEW:
		return
	var due: Array[Vector2i] = []
	for cell: Vector2i in pocket_pending:
		if pocket_pending[cell] <= day:
			due.append(cell)
	due.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return [pocket_pending[a], a.x, a.y] < [pocket_pending[b], b.x, b.y])
	var changed: bool = false
	for cell: Vector2i in due:
		if new_pockets.size() >= OrePocket.MAX_NEW:
			break  # the farm's cap: the rest stay pending
		var grown: Vector2i = OrePocket.replacement(world_seed, cell, dug, found_pockets, new_pockets, stone_pieces)
		if grown != OrePocket.NONE:
			new_pockets.append(grown)
			pocket_pending.erase(cell)
			changed = true
	if changed:
		pockets_changed.emit()


## Books the lab sitter for `for_day`, which must be the next day as the screen
## showed it (so a booking that crosses the 06:00 rollover is refused, not moved a
## day). Returns "" when booked, else why not. She is booked from the console in
## the dome, one day at a time, and costs LabSitter.fee() CR from the shared
## wallet, or one lab_sitter reward.
func book_lab_sitter(for_day: int, player_id: String = "") -> String:
	if place_of(_player(player_id)) != ZonePresence.DOME:
		return LabSitter.text("console_in_dome")
	var day: int = LabSitter.booked_day(GameClock.get_day_index())
	if for_day != day:
		return LabSitter.text("new_day")
	if LabSitter.is_booked(lab_sitter):
		return LabSitter.text("already")
	var fee: int = LabSitter.fee()
	var free: bool = fee > 0 and one_use_count(ONE_USE_SITTER) > 0
	if not free and credits < fee:
		return LabSitter.text("short") % [SP811.integer(fee), SP811.integer(credits)]
	# Booked before the money moves, so a screen that hears the charge sees her.
	lab_sitter = LabSitter.new_booking(day)
	if free:
		_spend_one_use(ONE_USE_SITTER)
		post_phone(QuestEngine.one_use_used_line(ONE_USE_SITTER))
	else:
		add_credits(-fee)
	lab_sitter_changed.emit()
	post_phone(LabSitter.text("booked_text") % [LabSitter.sitter_name(), SP811.integer(day),
		LabSitter.text("free_text") if free else LabSitter.text("fee_text") % SP811.integer(fee)])
	return ""


## The farm passes Vance's shuttle exam: the license is the farm's, kept for good.
## Said once; a second grant changes nothing.
func grant_shuttle_license() -> void:
	if shuttle_licensed:
		return
	shuttle_licensed = true
	shuttle_license_changed.emit()
	post_phone(Shuttle.text("granted_text") % SP811.integer(Shuttle.fare()))


## Who would fly if `player_id` booked now: the booker, then every other player here
## who is on the farm, not on a trip, and at the terminal: on foot within reach of it
## (with the host's slack), or the farm rover's driver with the rover there. A player with
## no pose yet, or a rider who is not driving, is left out. The host books with it; the
## terminal's panel shows it (a guest's copy has the synced places, trips, poses and
## driver). Booker first, the rest in session order.
func shuttle_party(player_id: String = "") -> Array[String]:
	var id: String = _player(player_id)
	var party: Array[String] = [id]
	for other: String in players_present():
		if other == id or shuttle_trips.has(other) or place_of(other) != ZonePresence.FARM:
			continue
		if _at_terminal_for_party(other):
			party.append(other)
	return party


func _at_terminal_for_party(player_id: String) -> bool:
	if CoopWalkers.is_out(player_id):
		return Shuttle.terminal_near(CoopWalkers.spot(CoopWalkers.out[player_id]), Shuttle.HOST_SLACK_M)
	var rovers: Node = rovers_node if rovers_node != null else CoopRovers
	if rovers.driver(ROVER) == player_id and not rover_is_away(ROVER):
		return Shuttle.terminal_near(_rover_pose_now(ROVER), Shuttle.HOST_SLACK_M)
	return false


## Books a day trip to `moon` for `people` from the pad's terminal. Runs on the
## host's clock. Before anything else it checks the sender stands at the terminal
## (on foot there, or in the rover there) and that `people` are all here to go
## (players_present()); then that `party_ids` (player ids, the sender first: what the
## terminal showed) is exactly the party the host works out (shuttle_party: the sender
## and everyone else on the farm at the terminal and not on a trip), so nobody is flown
## who did not expect to be, and a swap is caught as well as a count; then Shuttle.trip_problem's
## reasons, with the wallet checked against the whole party's fare. A refusal takes no
## fare. Phobos and Deimos have a hub (a moon with none is refused). Booked means the
## fare for each person paid from the shared wallet, and for every passenger: a trip
## recorded (shuttle_trips, one end time), a count of reaching the moon (the Manager
## has none), their place the moon's, and no longer on foot on the farm or driving its
## rover. The farm rover stays where it is: a passenger who was in it is out of it (the
## lease is let go), and walks home to the pad on the way back. Each screen goes to the
## hub (the sender's when the answer comes, ShuttleUI; the others' on the synced trip,
## SceneSwitcher.reconcile_trip). One phone line names the party and the fare. Each
## passenger comes home alone (shuttle_home) or when the trip ends. A player in bed who
## books is woken by the act (FarmCommands). With friends in, the day cannot end until
## the travellers are home: the trip ends by its clock or the 02:00 recall at the
## latest, so the wait is bounded. Returns "" when booked, else why not.
func book_shuttle(moon: String, party_ids: Array, player_id: String = "") -> String:
	var id: String = _player(player_id)
	var problem: String = _booking_problem(id, party_ids)
	if problem != "":
		return problem
	var party: Array[String] = shuttle_party(id)
	var hub_ready: bool = Shuttle.is_moon(moon) and ZoneData.is_playable(StringName(moon))
	var reason: String = Shuttle.trip_problem(moon, lab_level(), shuttle_licensed, credits, party.size(), GameClock.elapsed_days, hub_ready)
	if reason != "":
		return reason
	var total: int = Shuttle.fare() * party.size()
	add_credits(-total)
	var ends_at: float = Shuttle.trip_end(GameClock.elapsed_days)
	_fly_party(party, moon, ends_at, false)
	post_phone(Shuttle.text("booked_text") % [Shuttle.moon_name(moon), Shuttle.clock_text(GameClock.elapsed_days),
		SP811.integer(party.size()), SP811.integer(total), Shuttle.clock_text(ends_at)])
	return ""


## Host: "" or why the sender `id` and the `party_ids` they named can't book at the terminal
## (the checks the day trip and the expedition share, in their order): the sender at the
## terminal, a list of ids, a party of the right size, everyone here, and the list is the
## party shuttle_party works out.
func _booking_problem(id: String, party_ids: Array) -> String:
	var at: Variant = standing_at(id)
	if place_of(id) != ZonePresence.FARM or not Shuttle.terminal_near(at, Shuttle.HOST_SLACK_M):
		return Shuttle.text("far_text")
	for named: Variant in party_ids:
		if typeof(named) != TYPE_STRING:
			return Shuttle.text("party_changed_text")
	if party_ids.size() < 1 or party_ids.size() > Shuttle.party_most():
		return Shuttle.text("bad_party_text") % SP811.integer(Shuttle.party_most())
	if party_ids.size() > players_present().size():
		return Shuttle.text("crowd_text") % SP811.integer(players_present().size())
	var party: Array[String] = shuttle_party(id)
	if party_ids.size() != party.size() or party_ids[0] != id:
		return Shuttle.text("party_changed_text")
	for flyer: String in party:
		if not flyer in party_ids:
			return Shuttle.text("party_changed_text")
	return ""


## Host: writes a trip for each of `party` (one end time, `expedition` set for an
## expedition), counts the reach (the Manager has none), makes the moon their place and
## takes them off the farm's ground: out of the rover (it stays parked where it is), not
## among the walkers, out of bed.
func _fly_party(party: Array[String], moon: String, ends_at: float, expedition: bool) -> void:
	var rovers: Node = rovers_node if rovers_node != null else CoopRovers
	for flyer: String in party:
		var trip: Dictionary = { "moon": moon, "ends_at": ends_at }
		if expedition:
			trip["expedition"] = true
		shuttle_trips[flyer] = trip
		if flyer != MANAGER_ID:
			var counts: Dictionary = action_counts.get_or_add(flyer, {}) as Dictionary
			var reached: Dictionary = counts.get_or_add(REACHED_PREFIX + moon, { "count": 0, "xp": 0 })
			reached["count"] = int(reached["count"]) + 1
			if expedition:
				var booked: Dictionary = counts.get_or_add(EXPEDITION_BOOKED, { "count": 0, "xp": 0 })
				booked["count"] = int(booked["count"]) + 1
		_set_place(flyer, moon, 0)
		_trip_players.erase(flyer)
		CoopWalkers.out.erase(flyer)
		rovers.release(flyer)
		_beds().get_up(flyer)
		_campers.erase(flyer)
	shuttle_trips_changed.emit()


## Whether `player_id` has taken the expedition quest (it is in their own list, done or not:
## a repeat trip stays open once the job is done) [PLACEHOLDER].
func expedition_quest_taken(player_id: String) -> bool:
	var own: Variant = player_quest_state.get(player_id, {})
	return own is Dictionary and (own as Dictionary).has(EXPEDITION_QUEST)


## What an expedition would cost the party at the terminal now ({ fare, needed, buy,
## supplies, total }, Shuttle.expedition_cost): the host books with it, and the terminal's
## panel shows it (a guest's copy has the synced camp supplies).
func expedition_cost(people: int) -> Dictionary:
	return Shuttle.expedition_cost(people, camp_supplies)


## Books an expedition to `moon` (Deimos) for the party at the pad's terminal. Runs on
## the host's clock. It has the day trip's party rules (_booking_problem), then
## Shuttle.expedition_problem's reasons in their order (no permit, quest not taken, the
## window shutting before the return, the wallet short). `shown_total` is the total the
## terminal showed: if the host works out another (the party, the supplies held or
## the price moved) nothing is booked, so the price is never a surprise. Booked means
## the fare for each person plus the supplies short of a night each (bought now, and
## added to the shared camp supplies) paid once from the shared wallet, and a trip for
## each passenger that ends at 06:00 after the last night (Shuttle.expedition_end), not
## at the day's end. A refusal charges nothing. Returns "" when booked, else why not.
func book_expedition(moon: String, party_ids: Array, shown_total: int, player_id: String = "") -> String:
	var id: String = _player(player_id)
	var problem: String = _booking_problem(id, party_ids)
	if problem != "":
		return problem
	var party: Array[String] = shuttle_party(id)
	var hub_ready: bool = Shuttle.is_moon(moon) and ZoneData.is_playable(StringName(moon))
	var permit: String = "expedition_permit"
	# The camp is open whenever the quest is held, a brought, finished one too (the update
	# that opens it has not necessarily run since it was taken): never a booking to a shut camp.
	if expedition_quest_taken(id):
		open_camp(moon)
	var reason: String = Shuttle.expedition_problem(moon, lab_level(), shuttle_licensed, credits, party.size(), GameClock.elapsed_days,
		hub_ready, lab_gate_level(permit), lab_gate_open(permit), expedition_quest_taken(id), camp_supplies)
	if reason != "":
		return reason
	var cost: Dictionary = expedition_cost(party.size())
	if shown_total != int(cost["total"]):
		return Shuttle.text("expedition_changed_text") % SP811.integer(int(cost["total"]))
	add_credits(-int(cost["total"]))
	camp_supplies += int(cost["buy"])
	var ends_at: float = Shuttle.expedition_end(GameClock.elapsed_days)
	_fly_party(party, moon, ends_at, true)
	camps_changed.emit()
	post_phone(Shuttle.text("expedition_booked_text") % [Shuttle.moon_name(moon), Shuttle.clock_text(GameClock.elapsed_days),
		SP811.integer(party.size()), SP811.integer(Shuttle.expedition_nights()), SP811.integer(int(cost["total"])),
		SP811.integer(floori(ends_at) + 1), Shuttle.clock_text(ends_at)])
	# The quest's next step opens now, so a night's count is never behind it.
	update_quests([], false)
	return ""


## Host: the player takes the return shuttle from the moon's hub console, at any time
## (the way home ignores the windows, and costs nothing) [PLACEHOLDER]. `player_id` is
## filled in from the connection. Returns "" or why not. See _return_traveller.
func shuttle_home(player_id: String = "") -> String:
	var id: String = _player(player_id)
	if not shuttle_trips.has(id) or not Shuttle.is_moon(place_of(id)):
		return Shuttle.text("not_away_text")
	var left_early: bool = Shuttle.is_expedition(shuttle_trips[id])
	_return_traveller(id, Shuttle.text("expedition_abandoned_text" if left_early else "home_text"))
	return ""


## Host: ends every trip whose time is up, or that is still under way at the recall
## hour (a straggler: trip_problem keeps a booking from running past it, so only a
## clock jump or a forced trip gets here). The farm's night never charges or rescues
## a moon's traveller: the way home is the shuttle's, free (_return_traveller).
func _end_due_trips() -> void:
	if FarmCommands.guest or shuttle_trips.is_empty():
		return
	var closed: bool = TunnelRecall.closed(GameClock.elapsed_days)
	for id: String in shuttle_trips.keys():
		if Shuttle.is_expedition(shuttle_trips[id]):
			# An expedition is not sent home at the day's end or the recall hour: it
			# runs to its planned morning, and ends there free (zones step 18).
			if GameClock.elapsed_days >= float(shuttle_trips[id]["ends_at"]) - Shuttle.EPSILON_H / 24.0:
				_return_traveller(id, Shuttle.text("expedition_over_text"), true)
		elif closed or GameClock.elapsed_days >= float(shuttle_trips[id]["ends_at"]):
			_return_traveller(id, Shuttle.text("trip_over_text"))


## Host: a traveller comes home. Their trip is over (nothing is charged), their place is
## the farm and they stand on foot beside the pad's terminal, a phone line says so, and
## their screen goes back to the farm (the hub sees its trip end: PhobosHub, which DeimosHub extends). A
## guest is told by the farm they have.
func _return_traveller(player_id: String, line: String, completed: bool = false) -> void:
	var moon: String = str(shuttle_trips.get(player_id, {}).get("moon", ""))
	# An expedition run to its planned end counts for the quest (the Manager has none);
	# coming home early, or by the 02:00 flight, does not.
	if completed and player_id != MANAGER_ID and Shuttle.is_expedition(shuttle_trips.get(player_id, {})):
		var done: Dictionary = (action_counts.get_or_add(player_id, {}) as Dictionary).get_or_add(EXPEDITION_DONE, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	shuttle_trips.erase(player_id)
	_beds().get_up(player_id)  # up from the camp's bed, if they slept there
	_campers.erase(player_id)
	_set_place(player_id, ZonePresence.FARM, 0)
	_stand_at_pad(player_id)
	shuttle_trips_changed.emit()
	var named: String = Shuttle.moon_name(moon) if moon != "" else "the moon"
	post_phone(line % named if "%s" in line else line)


## Host: puts a returned traveller on foot at the landing pad. With the farm rover away
## (a field trip has it) there is nothing to be on foot beside, so they are put among
## the players there with no walker: a walker with no rover could never get in, and the
## rover coming home would only fold them into it. The spot is the pad's return spot, or
## the nearest dry one if that was dug under or flooded; a player's own building is not
## checked (there is no cheap query for it) [ASSUMPTION]. The silence clock does not
## start here but at their first farm report or pose (CoopWalkers.heard), as their
## screen has the host's next send, a fade and a load to get through first.
func _stand_at_pad(player_id: String) -> void:
	if rover_is_away(ROVER):
		CoopWalkers.out.erase(player_id)
		return
	CoopWalkers.stand(player_id, _pad_spot(), Time.get_ticks_msec() + CoopWalkers.ARRIVAL_MS)


func _pad_spot() -> Vector3:
	var base := Vector2(Shuttle.RETURN_AT.x, Shuttle.RETURN_AT.y)
	for ring: int in 7:
		for step: int in (1 if ring == 0 else 8):
			var angle: float = TAU * float(step) / 8.0
			var at: Vector2 = base + Vector2(cos(angle), sin(angle)) * 1.5 * float(ring)
			if maxf(absf(at.x), absf(at.y)) <= Terrain.HALF_M and not Terrain.is_deep(at):
				return Vector3(at.x, Terrain.height(at, dug), at.y)
	return Vector3(base.x, Terrain.height(base, dug), base.y)


## A farm opens (a load, or a guest joining): the host's own trip goes on if it is still
## on (and the farm opens at the hub, SaveGame.restore), one past its end brings them
## home, and nobody else's is kept: a guest who is not here is not on a trip. A
## guest's copy is the host's word (FarmSync), never settled here.
func _settle_trips_on_load() -> void:
	if FarmCommands.guest:
		return
	for id: String in shuttle_trips.keys():
		if id != local_player_id:
			shuttle_trips.erase(id)
		elif (not Shuttle.is_expedition(shuttle_trips[id]) and TunnelRecall.closed(GameClock.elapsed_days)) 				or GameClock.elapsed_days >= float(shuttle_trips[id]["ends_at"]) - Shuttle.EPSILON_H / 24.0:
			var moon: String = str(shuttle_trips[id]["moon"])
			var planned: bool = Shuttle.is_expedition(shuttle_trips[id])
			shuttle_trips.erase(id)
			# No walker is stood: farm_loaded (below, in farm_from_dict) has CoopWalkers
			# forget everyone, so the host opens at the farm in the rover, as on any load.
			post_phone(Shuttle.text("expedition_over_text" if planned else "trip_over_text") % Shuttle.moon_name(moon))
		else:
			_set_place(id, str(shuttle_trips[id]["moon"]), 0)


## Where a player stands on the farm: their walking pose if they are out, else the
## farm rover's if it is here (they are in it), else null.
func standing_at(player_id: String) -> Variant:
	if CoopWalkers.is_out(player_id):
		return CoopWalkers.spot(CoopWalkers.out[player_id])
	if rover_is_away(ROVER):
		return null
	return _rover_pose_now(ROVER)


## 06:00 of her day: she does the morning's work, after the robots' cards.
func _open_lab_sitter(day: int) -> void:
	if LabSitter.is_booked(lab_sitter) and int(lab_sitter["day"]) == day:
		_sitter_tend()


## 06:00 after her day: the last of the work (anything that came up during the
## day), then the Dispatch line, and she is done. Run after the robots' cards.
func _close_lab_sitter(day: int) -> void:
	if not LabSitter.is_booked(lab_sitter) or day <= int(lab_sitter["day"]):
		return
	_sitter_tend()
	post_phone(LabSitter.report_text(lab_sitter))
	lab_sitter = {}
	lab_sitter_changed.emit()


## One round of her work, by the code the players and robots use: she trims
## each growing plot's set point by the lab's soil probe and collects the spools
## that are ready, as the Manager (no skill XP). She never calibrates and
## never touches a sensor's drift or a reading. The lab's shared XP for a spool
## is still given. The spiders are not fed: the game has no feeding.
func _sitter_tend() -> void:
	var watered: int = 0
	var spools: int = 0
	for cell: Vector3i in plantings.keys():
		if is_crop_ready(cell):
			continue
		var setpoint: float = plantings[cell]["setpoint"]
		var target: float = float(crop(plantings[cell]["crop_id"]).get("soil_moisture_target", 0.0))
		var steps: int = LabSitter.trim_steps(target, soil_probe_reading(cell), setpoint, SETPOINT_STEP)
		if steps != 0 and adjust_setpoint(cell, steps) != setpoint:
			watered += 1
	if collect_spool(MANAGER_ID):
		spools += 1
	for species_id: Variant in enclosures.keys():
		if collect_enclosure_spool(str(species_id), MANAGER_ID):
			spools += 1
	lab_sitter["watered"] = int(lab_sitter["watered"]) + watered
	lab_sitter["spools"] = int(lab_sitter["spools"]) + spools
	lab_sitter_changed.emit()


func _on_day_started(day: int) -> void:
	_campers.clear()  # the night at a camp is over: they wake there, and the recall is theirs again
	_cold_kept.clear()  # yesterday's cold never comes back, whatever the grace
	# A rover below stands on the new day's floor.
	settle_rover_depth()
	zone_heat_trip = false  # a heat trip is one day's trip
	# Judged before the refill: the level only falls during the day, so empty
	# now means it ran dry and the crops had no water.
	var watered: bool = cistern_liters > 0.0
	cistern_liters = CISTERN_CAPACITY_L
	_post_morning_dispatch(day)
	# Courier returns land in the morning, before an audit that day.
	_receive_oirm_returns(day)
	_grow_pockets(day)
	_finish_lab_build(day)
	_finish_robot_builds(day)
	_hold_relay_lock()
	_note_holdover_lapses(day)
	_morning = true
	_charge_overdue_credibility(day)
	_expire_jobs(day)
	# The day that ended is tallied and grown first. Then the robots, then the
	# sitter (on her booked day and the one after), so her trims count for the
	# new day and crops that finish at dawn are ready. Dawn's soil check is last.
	_grow_crops(watered, false)
	_run_robot_cards()
	_close_lab_sitter(day)
	_open_lab_sitter(day)
	_note_dawn_soil()
	var cadence: int = int(_schedule("cadence_days", 5.0))
	if cadence > 0 and day % cadence == 0:
		_run_audit(day)
	_morning = false
	# After the audit, so the board matches the band the lab ends the morning in.
	refresh_job_board(day)
	update_quests()
	for note: String in _rescue_notes:
		post_phone(note)
	_rescue_notes.clear()
	# The morning's cancellations go last, as one line, so neither the audit's
	# lines nor the board's are newer and one cancellation can't hide another.
	if not _morning_notes.is_empty():
		post_phone(" ".join(_morning_notes))
		_morning_notes.clear()
	_roll_sentinel()


## One morning dispatch per day, no repeats until the whole deck is used.
func _post_morning_dispatch(day: int) -> void:
	if _dispatch_deck.is_empty():
		_dispatch_deck = DataManager.get_records(DISPATCH_TABLE, "morning_dispatches")
		_shuffle(_dispatch_deck)
	if _dispatch_deck.is_empty():
		return
	var entry: Dictionary = _dispatch_deck.pop_back()
	post_phone("DAY %d  [%s] %s" % [day, entry.get("sender", "?"), entry.get("text", "")])


func _run_audit(day: int) -> void:
	var since: Array[Dictionary] = []
	since.assign(cal_log.slice(_cal_index_at_last_audit))
	_cal_index_at_last_audit = cal_log.size()
	# Standards on this pod come back (and are certified) before Vance inspects.
	# _on_day_started already did this in play; keep it for direct calls (tests).
	_receive_oirm_returns(day)
	# Units and standards; a standard away at OIRM is not here to inspect.
	var audited: Dictionary = {}
	for id: String in unit_ids() + standard_ids():
		if not at_oirm.has(id):
			audited[id] = sensors[id]
	# A recall found on this pod gives the player until the next audit to redo it.
	var fineable_suspects: Dictionary = {}
	for id: Variant in suspect_units:
		if int(suspect_units[id]) < day and not is_commissioning(str(id)):
			fineable_suspects[id] = suspect_units[id]
	var excused: Dictionary = _excused_units(day)
	var report: Dictionary = AuditEngine.evaluate(day, audited, offence_counts, since, fineable_suspects, excused)
	# AUD-1T measures the rover tires once the WD-1 has the tire gauge in service.
	if is_in_service(TIRE_ID):
		var tire: Dictionary = AuditEngine.tire_check(get_sensor(TIRE_ID).error)
		report["tire_check"] = tire
		if tire["violation"]:
			report["passed"] = false
			report["total_fine"] = int(report["total_fine"]) + int(tire["fine"])

	# Vance reads the robots' interlock logs (section 6 item 10).
	report["interlocks"] = _interlock_findings()
	for finding: Dictionary in report["interlocks"]:
		report["passed"] = false
		report["total_fine"] = int(report["total_fine"]) + int(finding["fine"])

	if not report["passed"] and not audit_grace_used:
		_apply_audit_grace(report)
		# Vance reads the manager's records at this audit, not the next.
		for record: Dictionary in cal_log.slice(_cal_index_at_last_audit):
			report["cal_records"] += 1
			if not record.get("as_found_in_tolerance", true):
				report["cal_fails_found"] += 1
		_cal_index_at_last_audit = cal_log.size()

	var departure_hour: float = _schedule("drop_pod_departs_hour", 18.0)
	_drop_pod_departure_at = GameClock.elapsed_at_hour(day, departure_hour)
	# A 06:00 departure means the end of the audit day, not the moment it starts.
	if _drop_pod_departure_at - float(day - 1) < 1.0e-6:
		_drop_pod_departure_at += 1.0
	post_phone("AUDIT DAY %d: Inspector Vance and AUD-1T have landed." % day)
	# A time skip can run the audit after its departure deadline has passed.
	if GameClock.elapsed_days < _drop_pod_departure_at:
		drop_pod_present = true
		drop_pod_changed.emit(true)
	else:
		post_phone("AUD-1T: Departing. Please remain compliant in our absence.")
	for line: Dictionary in report["lines"]:
		var sensor: DriftingSensor = get_sensor(line["instrument_id"])
		# Three decimals so 1.004 x MPE doesn't read as "1.00 ... OUT OF TOLERANCE".
		var label: String = ("%s certificate %s" % [instrument_name(line["instrument_id"]),
				certificates.get(line["instrument_id"], {}).get("id", "missing")]
			if line.get("standard", false)
			else "%s %s (%s × MPE) %s" % [
				instrument_name(line["instrument_id"]),
				sensor.format_value(line["as_found"]), SP811.number(line["ratio"], 3), DriftingSensor.band_label(line["band"])])
		if line["overdue"]:
			label += ", " + DriftingSensor.overdue_text(int(line["due_day"]))
		if line.get("excused", false):
			label += ", EXCUSED (its standard was at OIRM when it fell due; calibrate before the day %d audit)" % excused[line["instrument_id"]]
		if line.get("suspect", false):
			label += ", SUSPECT CAL (recalled, not redone)"
		if line.get("waived", false):
			label += ": WAIVED (one-time warning)"
		elif line["violation"]:
			offence_counts[line["instrument_id"]] = int(offence_counts.get(line["instrument_id"], 0)) + 1
			label += ": FINE %s CR" % SP811.integer(line["fine"])
		post_phone(label)
	post_phone("Traceability: %d calibration record(s) since last audit, %d found out of tolerance." % [
		report["cal_records"], report["cal_fails_found"]])
	for id: String in unit_ids():
		var chain: Dictionary = traceability_chain(id)
		post_phone(("Chain: %s" if chain["traceable"] else "Chain BROKEN: %s") % chain["text"])
	for finding: Dictionary in report["interlocks"]:
		post_phone("VANCE: %s interlock overridden: %s" % [robots[finding["robot_id"]]["name"],
			"WAIVED (one-time warning)" if finding.get("waived", false) else "FINE %s CR" % SP811.integer(finding["fine"])])
	# Last before the verdict, so the HUD's short log still shows it.
	if report.has("tire_check"):
		post_phone(_tire_check_line(report["tire_check"]))
	if report.get("warning", false):
		post_phone("MANAGER: Caught it before Vance got in: %s. One-time favor. Don't make it a habit." % report["waived_names"])
		post_phone("VANCE: Warning issued. Next time it's a fine.")
	elif report["passed"]:
		# A fully clean audit wipes the repeat-offence history.
		offence_counts.clear()
		post_phone("VANCE: Compliant. Repeat-offence record cleared. Disappointing, frankly.")
	else:
		add_credits(-int(report["total_fine"]))
		var fines: Array[Dictionary] = DataManager.get_records(DISPATCH_TABLE, "audit_fines")
		var footer: String = (_pick(fines) as Dictionary).get("snarky_footer", "") if not fines.is_empty() else ""
		post_phone("TOTAL FINE %s CR. Balance %s CR. %s" % [SP811.integer(report["total_fine"]), SP811.integer(credits), footer])
	_update_clean_audit_gate(report)
	_credibility_after_audit(report)
	# Where it came among the phone's lines, so a guest sees the same order.
	report["phone_count"] = phone_count
	audit_log.append(report)
	audit_completed.emit(report)


## "AUD-1T: Rover tires 7.2 kPa below set point (limit 6.9 kPa). PETTY FINE 20 CR"
func _tire_check_line(tire: Dictionary) -> String:
	var offset: float = tire["offset_kpa"]
	var where: String = ("at set point" if is_zero_approx(offset)
		else "%s kPa %s set point" % [SP811.number(absf(offset), 1), "below" if offset < 0.0 else "above"])
	var text: String = "AUD-1T: Rover tires %s (limit %s kPa)" % [where, SP811.number(tire["limit_kpa"], 1)]
	if tire.get("waived", false):
		return text + ". WAIVED (one-time warning)"
	if tire["violation"]:
		return text + ". PETTY FINE %s CR" % SP811.integer(tire["fine"])
	return text + ". Compliant."


## Tier 1 needs one audit with zero violations; a grace warning is not clean
## (Q19). The streak is kept for the Tier 3 gate (milestone 3).
func _update_clean_audit_gate(report: Dictionary) -> void:
	if not report["passed"]:
		clean_audit_streak = 0
		return
	clean_audit_streak += 1
	report["clean"] = true
	_award_clean_audit_xp()
	if not tier1_unlocked:
		tier1_unlocked = true
		post_phone("VANCE: First clean audit on file. Tier 1 equipment is cleared for purchase.")
	if not traceable_lab and clean_audit_streak >= 2:
		traceable_lab = true
		post_phone("VANCE: Two clean audits in a row. Signed off as a traceable lab.")


## Turns this audit's fines into a one-time warning. The manager calibrates
## each violating instrument (logged as theirs) before Vance inspects. Not a
## clean audit, so repeat-offence counts are neither raised nor cleared.
func _apply_audit_grace(report: Dictionary) -> void:
	audit_grace_used = true
	var names: PackedStringArray = []
	var excused: PackedStringArray = []
	for line: Dictionary in report["lines"]:
		if line["violation"]:
			# The manager uses the bench standard; if the TUR refuses, they zero it
			# without one (untraceable) rather than claim a calibration that didn't happen.
			# Standards are waived as they are.
			if get_sensor(line["instrument_id"]).role != "standard" \
					and calibrate(line["instrument_id"], MANAGER_ID).get("refused", false):
				calibrate(line["instrument_id"], MANAGER_ID, false)
			line["fine"] = 0
			line["waived"] = true
			if get_sensor(line["instrument_id"]).role == "standard":
				excused.append(_mid_sentence(instrument_name(line["instrument_id"])))
			else:
				names.append(_mid_sentence(instrument_name(line["instrument_id"])))
	var tire: Dictionary = report.get("tire_check", {})
	var tires_topped: bool = tire.get("violation", false)
	if tires_topped:
		tire["fine"] = 0
		tire["waived"] = true
	report["total_fine"] = 0
	report["warning"] = true
	# "recalibrated the steering encoder and talked Vance out of the lapsed certificate on the PX-1 rotary table"
	var done: PackedStringArray = []
	if not names.is_empty():
		done.append("recalibrated the " + " and the ".join(names))
	if not excused.is_empty():
		done.append("talked Vance out of the lapsed certificate on the " + " and the ".join(excused))
	if tires_topped:
		done.append("reset the rover tires")
	for finding: Dictionary in report.get("interlocks", []):
		finding["fine"] = 0
		finding["waived"] = true
		# The manager has calibrated whatever the robot was holding for.
		var robot: Dictionary = robots[finding["robot_id"]]
		for key: String in ["holding", "override", "override_logged"]:
			robot[key] = false
		robot.erase("override_by")
		done.append("armed %s's interlock" % robot["name"])
	report["waived_names"] = " and ".join(done)


## A short name for use mid-sentence: "Steering" -> "steering", but a model
## designator such as "PX-1 rotary table" keeps its capitals.
static func _mid_sentence(name: String) -> String:
	var first: String = name.get_slice(" ", 0)
	if first.length() > 1 and first.substr(1) == first.substr(1).to_lower() 			and first.substr(1).to_upper() != first.substr(1).to_lower():
		return first.to_lower() + name.substr(first.length())
	return name

# --- OIRM, certificates, recall (milestone 2) -------------------------------------

## Tier 0 standards start with a certificate from the colony's founding stock
## (section 1.7 [ASSUMPTION]): issued day 0, due at the end of the first interval.
func _issue_founding_certificates() -> void:
	certificates.clear()
	certificate_log.clear()
	at_oirm.clear()
	oirm_trips.clear()
	suspect_units.clear()
	_next_certificate_number = 1
	for id: String in standard_ids():
		sensors[id].last_cal_day = 0
		_issue_certificate(id, 0, null, null, true)


## Records a new certificate for `standard_id` from its current due day: OIRM's,
## or with `issuer` / `prefix` a maker's certificate traceable to OIRM.
## as_found / as_left are null when no measurement is on file (founding stock,
## or the as-found of a new instrument).
func _issue_certificate(standard_id: String, day: int, as_found: Variant, as_left: Variant, founding: bool,
		issuer: String = "OIRM", prefix: String = "OIRM") -> Dictionary:
	var sensor: DriftingSensor = sensors[standard_id]
	var cert: Dictionary = {
		"id": "%s-%04d" % [prefix, _next_certificate_number],
		"standard_id": standard_id,
		"issuer": issuer,
		"day": day,
		"due_day": sensor.cal_due_day,
		"as_found": as_found,
		"as_left": as_left,
		"as_found_in_tolerance": as_found == null or absf(float(as_found)) <= sensor.mpe,
		"expanded_uncertainty": sensor.certificate_uncertainty,
		"k": sensor.certificate_k,
		"founding": founding,
	}
	_next_certificate_number += 1
	certificates[standard_id] = cert
	certificate_log.append(cert)
	return cert


## The next audit day after `day` (when the drop pod is back).
func next_audit_day(day: int) -> int:
	var cadence: int = maxi(int(_schedule("cadence_days", 5.0)), 1)
	return (day / cadence + 1) * cadence


func oirm_fee() -> int:
	return int(DataManager.get_number(DRIFT_TABLE, "oirm/fee_credits", 150.0))


func oirm_courier_surcharge() -> int:
	return int(DataManager.get_number(DRIFT_TABLE, "oirm/courier_surcharge_credits", 150.0))


func oirm_courier_days() -> int:
	return maxi(int(DataManager.get_number(DRIFT_TABLE, "oirm/courier_return_days", 7.0)), 1)


## Units overdue at this audit only because the standard they need was at OIRM
## when they fell due (Ryan, 2026-11-22). Excused at the first audit where they
## are overdue, and at any audit while the standard is still away or only came
## back that morning (a courier trip is longer than the audit cadence). After
## that they need a traceable calibration by the next audit.
## Returns instrument_id -> the audit day by which it must be calibrated.
func _excused_units(day: int) -> Dictionary:
	var excused: Dictionary = {}
	var cadence: int = maxi(int(_schedule("cadence_days", 5.0)), 1)
	for id: String in unit_ids():
		var sensor: DriftingSensor = sensors[id]
		var due: int = sensor.cal_due_day
		if not sensor.is_overdue(day):
			continue
		for i: int in oirm_trips.size():
			var trip: Dictionary = oirm_trips[i]
			var back: int = _trip_back(i, day)
			# Due after it left (the player could calibrate on the send day) and before it came back.
			if trip["standard_id"] == sensor.calibrated_by and int(trip["sent_day"]) < due and due < back \
					and (due >= day - cadence or back >= day):
				excused[id] = next_audit_day(maxi(day, back))
				break
	return excused


## The day trip `index` brought its standard back; for the trip still open
## (the standard's latest, while it is away) at least `day`, as it is late.
func _trip_back(index: int, day: int) -> int:
	var trip: Dictionary = oirm_trips[index]
	var back: int = int(trip["return_day"])
	if _trip_is_open(index):
		back = maxi(back, day)
	return back


func _trip_is_open(index: int) -> bool:
	var standard_id: String = oirm_trips[index]["standard_id"]
	if not at_oirm.has(standard_id):
		return false
	for later: int in range(index + 1, oirm_trips.size()):
		if oirm_trips[later]["standard_id"] == standard_id:
			return false
	return true


## Sends a standard to OIRM. With the drop pod on the pad it rides the pod
## for the fee and comes back on the next audit pod. On any other day it goes
## by courier for the fee plus a surcharge and comes back a fixed number of
## days later. Returns { "ok", "reason", "return_day", "courier", "fee" }.
func send_to_oirm(standard_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null or sensor.role != "standard":
		return { "ok": false, "reason": "Only reference standards go to OIRM." }
	if sensor.relay_disciplined:
		return { "ok": false, "reason": "The %s gets OIRM time over the relay; it never goes to OIRM." % instrument_name(standard_id, true) }
	if not owned_standards.has(standard_id):
		return { "ok": false, "reason": "The %s is not on the colony." % instrument_name(standard_id, true) }
	if at_oirm.has(standard_id):
		return { "ok": false, "reason": "Already at OIRM until day %d." % at_oirm[standard_id] }
	# The trip that would open the account (has_oirm_account) waits for its row.
	if sensor.tier >= 1 and not has_oirm_account() and not lab_gate_open("oirm_account"):
		return { "ok": false, "reason": lab_gate_problem("oirm_account", "An OIRM account") }
	# No pod on the pad: it goes by courier for a surcharge (Ryan, 2026-11-22).
	var courier: bool = not drop_pod_present
	var fee: int = oirm_fee() + (oirm_courier_surcharge() if courier else 0)
	if credits < fee:
		return { "ok": false, "reason": "OIRM charges %s CR; balance %s CR." % [SP811.integer(fee), SP811.integer(credits)] }
	add_credits(-fee)
	var today: int = GameClock.get_day_index()
	var return_day: int = today + oirm_courier_days() if courier else next_audit_day(today)
	at_oirm[standard_id] = return_day
	oirm_trips.append({ "standard_id": standard_id, "sent_day": today, "return_day": return_day, "courier": courier })
	if courier:
		post_phone("OIRM: %s collected by courier. Fee %s CR (%s CR + %s CR courier). Back on day %d; nothing can be calibrated against it until then." % [
			instrument_name(standard_id, true), SP811.integer(fee), SP811.integer(oirm_fee()),
			SP811.integer(oirm_courier_surcharge()), return_day])
	else:
		post_phone("OIRM: %s loaded on the drop pod. Fee %s CR. Back on the day %d pod; nothing can be calibrated against it until then." % [
			instrument_name(standard_id, true), SP811.integer(fee), return_day])
	oirm_changed.emit()
	return { "ok": true, "reason": "", "return_day": return_day, "courier": courier, "fee": fee }


func _receive_oirm_returns(day: int) -> void:
	for id: Variant in at_oirm.keys():
		if int(at_oirm[id]) <= day:
			oirm_calibrate(str(id), day)


## OIRM's calibration of a returned standard: measured against a perfect
## reference, adjusted, and certified. Its interval is unchanged
## [ASSUMPTION]. An out-of-tolerance as-found starts a recall.
func oirm_calibrate(standard_id: String, day: int) -> Dictionary:
	var sensor: DriftingSensor = sensors[standard_id]
	at_oirm.erase(standard_id)
	var previous: Dictionary = certificates.get(standard_id, {})
	var zeroed: Dictionary = sensor.zero(0.0)
	sensor.cal_due_day = day + sensor.cal_interval_days
	sensor.last_cal_day = day
	# Close the trip on the day it actually came back, in case it was late.
	for i: int in range(oirm_trips.size() - 1, -1, -1):
		if oirm_trips[i]["standard_id"] == standard_id:
			oirm_trips[i]["return_day"] = day
			break
	var cert: Dictionary = _issue_certificate(standard_id, day, zeroed["as_found"], zeroed["as_left"], false)
	_award_lab_xp("lab_certificate", "", 1.0, false)
	post_phone("OIRM: %s returned with certificate %s. As-found %s (%s). Due day %d." % [
		instrument_name(standard_id, true), cert["id"], sensor.format_value(zeroed["as_found"], 3),
		"in tolerance" if cert["as_found_in_tolerance"] else "OUT OF TOLERANCE", cert["due_day"]])
	# OIRM's own certificate clears whatever was wrong with the last one.
	suspect_units.erase(standard_id)
	_untraceable_since_cal.erase(standard_id)
	if not cert["as_found_in_tolerance"]:
		_recall_and_post(standard_id, zeroed["as_found"], int(previous.get("day", 0)))
	oirm_changed.emit()
	return cert


func _recall_and_post(standard_id: String, standard_error: float, since_day: int) -> void:
	var flagged: Array[Dictionary] = recall(standard_id, standard_error, since_day)
	var names: PackedStringArray = []
	for record: Dictionary in flagged:
		names.append("%s (day %d)" % [instrument_name(record["instrument_id"]), record["day"]])
	post_phone("RECALL: %d calibration(s) made with the %s are suspect%s. Redo them before the next audit." % [
		flagged.size(), instrument_name(standard_id, true), (": " + ", ".join(names)) if not names.is_empty() else ""])


## A robot sensor found out of tolerance, by a traceable calibration, makes every
## traceable calibration its robot did since that sensor's last good one suspect
## (section 3.4), whether or not its result would change.
func _recall_after_robot_failure(record: Dictionary) -> void:
	var sensor_id: String = record["instrument_id"]
	var robot_id: String = robot_of(sensor_id)
	if robot_id == "" or not record["traceable"] or record["result"] != CalUncertainty.FAIL:
		return
	var names: PackedStringArray = []
	# Newest first, from before this record back to the sensor's last good one.
	for i: int in range(cal_log.size() - 2, -1, -1):
		var done: Dictionary = cal_log[i]
		if done.get("suspect", false) or not done.get("traceable", false):
			continue
		if done["instrument_id"] == sensor_id:
			break
		if done.get("programmed_by", "") == "" or done.get("performed_by", "") != robot_id:
			continue
		done["suspect"] = true
		done["recalled_by"] = sensor_id
		if is_same(_last_traceable_record(done["instrument_id"]), done):
			suspect_units[done["instrument_id"]] = record["day"]
		names.append("%s (day %s)" % [instrument_name(done["instrument_id"]), SP811.integer(done["day"])])
	if names.is_empty():
		return
	post_phone("RECALL: %d calibration(s) %s did since the last good one of its %s are suspect: %s. Redo them before the next audit." % [
		names.size(), robots[robot_id]["name"], get_sensor(sensor_id).short_name.trim_prefix(robot_id + " "), ", ".join(names)])
	robots_changed.emit()


## Reverse traceability (section 1.6). `standard_error` is the standard's as-found
## error. Every traceable calibration made with it from `since_day` on is
## re-judged with its as-found corrected by that error; it becomes suspect
## only if the result changes (impact threshold). A suspect calibration of
## another standard cascades to that standard's own calibrations. Returns
## the records flagged, cascade included.
## `certificate` limits it to work done while the standard was on that
## certificate ("" = any); the cascade uses it.
func recall(standard_id: String, standard_error: float, since_day: int, certificate: String = "") -> Array[Dictionary]:
	var flagged: Array[Dictionary] = []
	var today: int = GameClock.get_day_index()
	for record: Dictionary in cal_log:
		if record.get("standard_id", "") != standard_id or record.get("suspect", false):
			continue
		if int(record["day"]) < since_day or not record.get("traceable", false):
			continue
		if certificate != "" and record.get("standard_certificate", "") != certificate:
			continue
		# The standard's error in the unit's own quantity (section 1.5).
		var instrument: DriftingSensor = get_sensor(record["instrument_id"])
		var carried: float = standard_error * (instrument.standard_sensitivity if instrument else 1.0)
		var corrected: float = float(record["as_found"]) + carried
		var rejudged: String = CalUncertainty.classify(corrected, record["mpe"], record["acceptance_limit"])
		if rejudged == record["result"]:
			# A standard still passing can carry an error that a unit with a
			# large sensitivity downstream cannot absorb: keep cascading.
			if instrument and instrument.role == "standard":
				flagged.append_array(recall(record["instrument_id"], carried, int(record["day"]), record.get("certificate", "")))
			continue
		record["suspect"] = true
		record["suspect_result"] = rejudged
		record["recalled_by"] = standard_id
		flagged.append(record)
		if instrument and instrument.role == "standard":
			flagged.append_array(recall(record["instrument_id"], carried, int(record["day"]), record.get("certificate", "")))
			# Suspect itself only while that certificate is its latest.
			if record.get("certificate", "") != "" and record["certificate"] == certificates.get(record["instrument_id"], {}).get("id", ""):
				suspect_units[record["instrument_id"]] = today
		elif is_same(_last_traceable_record(record["instrument_id"]), record):
			# A later good calibration already superseded an older suspect one.
			suspect_units[record["instrument_id"]] = today
	return flagged


## Traceability of an instrument's readings right now (section 1.7), for the
## bench and the audit. { "traceable": bool, "text": String }; text reads like
## "Steering <- PX-1 rotary table (OIRM-0001, day 3) <- OIRM" or says where it breaks.
func traceability_chain(instrument_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(instrument_id)
	if sensor == null:
		return { "traceable": false, "text": "%s: unknown instrument" % instrument_id }
	var today: int = GameClock.get_day_index()
	var name: String = instrument_name(instrument_id)
	if sensor.role == "standard":
		if at_oirm.has(instrument_id):
			return { "traceable": false, "text": "%s: at OIRM until day %d" % [name, at_oirm[instrument_id]] }
		var cert: Dictionary = certificates.get(instrument_id, {})
		if cert.is_empty():
			return { "traceable": false, "text": "%s: no certificate" % name }
		if sensor.relay_disciplined and standard_problem(instrument_id) == "":
			return { "traceable": true, "text": "%s ← %s ← OIRM time" % [name, "relay lock" if is_relay_locked(instrument_id)
				else "holdover (good to day %d)" % sensor.cal_due_day] }
		if sensor.is_overdue(today):
			return { "traceable": false, "text": "%s ← %s %s" % [name, cert["id"], DriftingSensor.overdue_text(sensor.cal_due_day)] }
		if suspect_units.has(instrument_id):
			return { "traceable": false, "text": "%s ← %s: SUSPECT, recalled day %d" % [name, cert["id"], suspect_units[instrument_id]] }
		if _untraceable_since_cal.has(instrument_id):
			return { "traceable": false, "text": "%s ← %s: adjusted since without a traceable standard" % [name, cert["id"]] }
		if cert.has("reference_id"):
			return { "traceable": true, "text": "%s ← %s (due day %d) ← %s (%s) ← OIRM" % [name, cert["id"], cert["due_day"],
				instrument_name(cert["reference_id"]), cert["reference_certificate"]] }
		# A maker's certificate traces through the maker's own lab to OIRM.
		var via: String = "" if str(cert.get("issuer", "OIRM")) == "OIRM" else " ← " + str(cert["issuer"])
		return { "traceable": true, "text": "%s ← %s (due day %d)%s ← OIRM" % [name, cert["id"], cert["due_day"], via] }
	var record: Dictionary = _last_traceable_record(instrument_id)
	if record.is_empty():
		return { "traceable": false, "text": "%s: no traceable calibration on record" % name }
	var standard_name: String = instrument_name(record["standard_id"])
	var link: String = "%s ← %s (%s, day %d)" % [name, standard_name, record.get("standard_certificate", "?"), record["day"]]
	if suspect_units.has(instrument_id):
		return { "traceable": false, "text": "%s: SUSPECT, recalled day %d" % [link, suspect_units[instrument_id]] }
	if _untraceable_since_cal.has(instrument_id):
		return { "traceable": false, "text": "%s: adjusted since without a traceable standard" % link }
	if sensor.is_overdue(today):
		return { "traceable": false, "text": "%s: %s" % [link, DriftingSensor.overdue_text(sensor.cal_due_day)] }
	return { "traceable": true, "text": link + " ← OIRM" }


func _last_traceable_record(instrument_id: String) -> Dictionary:
	for i: int in range(cal_log.size() - 1, -1, -1):
		var record: Dictionary = cal_log[i]
		if record["instrument_id"] == instrument_id and record.get("traceable", false):
			return record
	return {}


# --- Ore and Bram ----------------------------------------------------------------

## The fissures in scenes/main_farm.tscn. Any other name would be ore for nothing.
const FISSURES: Array[StringName] = [&"FissureA", &"FissureB", &"FissureC", &"FissureD",
	&"FissureE", &"FissureF", &"FissureG", &"FissureH"]


## A mined fissure regrows `fissure_regrow_days` mornings later.
func is_fissure_available(fissure_id: StringName) -> bool:
	if not mined_fissures.has(fissure_id):
		return true
	var regrow: int = int(DataManager.get_number(ITEMS_TABLE, "crystal_ore/fissure_regrow_days", 1.0))
	return GameClock.get_day_index() >= int(mined_fissures[fissure_id]) + regrow


## How many fissures can be mined now.
func open_fissures() -> int:
	var open: int = 0
	for fissure: StringName in FISSURES:
		if is_fissure_available(fissure):
			open += 1
	return open


func mine_fissure(fissure_id: StringName, player_id: String = "") -> bool:
	if not fissure_id in FISSURES or not is_fissure_available(fissure_id):
		return false
	mined_fissures[fissure_id] = GameClock.get_day_index()
	crystal_ore += 1
	_award_xp("mine_fissure", player_id)
	ore_changed.emit(crystal_ore)
	fissures_changed.emit()
	return true


## The boulders in scenes/main_farm.tscn.
const BOULDERS: Array[StringName] = [&"RockA", &"RockB", &"RockC", &"RockD"]
## Hits that break a boulder [PLACEHOLDER].
const BOULDER_HITS: int = 5


func is_boulder_broken(boulder_id: StringName) -> bool:
	return boulder_hits.get(boulder_id, 0) >= BOULDER_HITS


## Returns how often it has now been hit, or 0 if it can't be. A broken one stays
## broken. It costs nothing, and the hit that breaks it gives stone.
@warning_ignore("unused_parameter")
func hit_boulder(boulder_id: StringName, player_id: String = "") -> int:
	if not boulder_id in BOULDERS or is_boulder_broken(boulder_id):
		return 0
	boulder_hits[boulder_id] = boulder_hits.get(boulder_id, 0) + 1
	boulders_changed.emit()
	if is_boulder_broken(boulder_id):
		stone = mini(stone + StonePieces.PER_BOULDER, StonePieces.MAX_STONE)
		stone_changed.emit()
	return boulder_hits[boulder_id]


func treads_ore_cost() -> int:
	return int(DataManager.get_number(ITEMS_TABLE, "wide_treads/ore_cost", 6.0))


## Bram's trade. Returns "" on success, or the reason it can't happen.
func buy_wide_treads() -> String:
	if has_wide_treads:
		return "Already running wide treads."
	var cost: int = treads_ore_cost()
	if crystal_ore < cost:
		return "Needs %d crystal ore; carrying %d." % [cost, crystal_ore]
	crystal_ore -= cost
	has_wide_treads = true
	var mult: float = DataManager.get_number(ITEMS_TABLE, "wide_treads/usage_drift_multiplier", 0.5)
	steering.usage_drift_rate *= mult
	ore_changed.emit(crystal_ore)
	upgrades_changed.emit()
	post_phone("BRAM: Treads are on. Steering drift per meter is down %d %%. Don't till any boulders." % roundi((1.0 - mult) * 100.0))
	return ""


## Meters driven also wear the tire gauge, once it is in service.
func add_tire_usage(meters: float) -> void:
	if is_in_service(TIRE_ID):
		get_sensor(TIRE_ID).add_usage(meters)


## Distance a rover drove this tick: wears the steering encoder and the tire
## gauge. There is one of each, whichever rover drove. The driver's Field Ops
## skill spares the encoder.
func add_rover_usage(meters: float, player_id: String = "", rover_id: String = "") -> void:
	if FarmCommands.guest:
		return  # the host's rover wears the sensors
	if not is_finite(meters) or meters < 0.0:
		return
	# A vent's heat (zone_heat_trip) multiplies the wear that is already there, on the
	# instruments that ride the rover; the wheel nuts' count below is not wear.
	# Only the rover that is in the zone feels it: the field rover, or the farm rover while
	# lent. The farm rover on the farm never does.
	var hot_rover: bool = rover_id == TUNNEL_ROVER or (rover_lent and rover_id == ROVER)
	var heat: float = ZoneHazards.DRIFT_MULTIPLIER if zone_heat_trip and hot_rover else 1.0
	# The Ice Caves' cold multiplies it the same way, for the driver, once the pack is past the threshold.
	if hot_rover and rover_zone == IceDepth.ZONE:
		heat *= IceDepth.drift_multiplier(cold_of(player_id if player_id != "" else local_player_id))
	steering.add_usage(meters * heat * skill_factor("steering_usage", player_id))
	add_tire_usage(meters * heat)
	# The wheels that wear are the farm rover's: a field rover's metres are not
	# counted unless it is the farm rover lent to the zone.
	if rover_id == TUNNEL_ROVER and not rover_lent:
		return
	var were_due: bool = wheels_due()
	wheel_meters += meters
	if wheels_due() and not were_due:
		post_phone("BRAM: Your wheel nuts are due a re-torque. Bring the rover by my bay when you pass.")
		wheels_changed.emit()


## Meters between two wheel services [PLACEHOLDER].
func wheel_service_due_m() -> float:
	return DataManager.get_number(ITEMS_TABLE, "wheel_service/due_m", 1500.0)


## True once the rover has driven that far since its nuts were last torqued. It
## is a reason to visit Bram and nothing more: no wear, drift, speed or price
## reads it, and a rover never stops for it.
func wheels_due() -> bool:
	return wheel_meters >= wheel_service_due_m()


## The service button's words in Bram's bay.
func wheel_service_text() -> String:
	if wheels_due():
		return "RE-TORQUE WHEEL NUTS"
	return "WHEEL NUTS OK: %s m OF %s m" % [SP811.integer(floori(wheel_meters)), SP811.integer(roundi(wheel_service_due_m()))]


## Bram re-torques the rover's five wheel nuts, in star order. Returns "" or why
## not. It costs nothing and changes nothing but the meters counted, the
## player's Robotics XP and the lab's XP; a quest step may count it (the
## `service_wheels` source). Where the rover stands is the screen's to check, as
## for his treads.
## `score` is Torque to Spec's (docs/design/quests_levels_story.md section 7.1;
## MinigameScore.SKIPPED with no game). It is read in one place: the service's
## own XP and the lab's XP for it are times MinigameScore.xp_factor(score),
## which is 1.0 for a skip and a poor try. The meters, when the nuts are next
## due and the rover do not see it.
func service_wheels(player_id: String = "", score: int = MinigameScore.SKIPPED) -> String:
	if rover_lent:
		return "The rover is in the tunnels. Bram's bay is up on the farm."
	if not wheels_due():
		return "The wheel nuts are not due: %s m driven of %s m." % [
			SP811.integer(floori(wheel_meters)), SP811.integer(roundi(wheel_service_due_m()))]
	wheel_meters = 0.0
	var xp_scale: float = MinigameScore.xp_factor(score)
	_award_xp("service_wheels", player_id, xp_scale)
	_award_lab_xp("lab_wheels", player_id, xp_scale)
	wheels_changed.emit()
	return ""


# --- Presence (zones doc section 12.2) ----------------------------------------

## Host: a player says where they are. `player_id` is filled in from the
## connection (FarmCommands), never from the message. Returns "" or why not.
func report_place(place: String, depth: int, player_id: String = "") -> String:
	var here: Array[String] = []
	here.assign(CoopSession.players if not CoopSession.players.is_empty() else [local_player_id])
	var reason: String = ZonePresence.problem(place, depth, player_id, player_id, here)
	if reason != "":
		return reason
	# A moon has no depth: no tunnel, no dig.
	if Shuttle.is_moon(place) and depth != 0:
		return Shuttle.text("not_away_text")
	# A moon is reached by booking the shuttle, never by a report.
	if Shuttle.is_moon(place) and str((shuttle_trips.get(player_id, {}) as Dictionary).get("moon", "")) != place:
		return Shuttle.text("not_away_text")
	if not Shuttle.is_moon(place) and shuttle_trips.has(player_id) and Shuttle.is_moon(place_of(player_id)):
		return Shuttle.text("home_by_console_text")
	var on_trip: bool = rover_zone != "" and (_trip_players.has(player_id) or (player_places.has(player_id) and place_of(player_id) == rover_zone))
	_set_place(player_id, place, depth)
	if place == ZonePresence.FARM:
		CoopWalkers.heard(player_id)  # a traveller back on foot has spoken: the silence clock starts
		_trip_players.erase(player_id)  # back on the farm: not on the trip
		# The last one off the trip (a guest in the dome after the rescue hour walks to the
		# farm): nobody is left to bring the rover back, so it goes home as for a drop.
		if on_trip and not FarmCommands.guest and _nobody_on_the_trip():
			bring_rover_home()
	else:
		# Down in a zone is not in bed: whoever goes below leaves it, as for any act.
		if place != ZonePresence.DOME:
			(recall_beds if recall_beds != null else CoopBeds).get_up(player_id)
			# A report after the hour (the clock parked at 05:59:59) is carried out now, not
			# at a tick that never comes.
			_tick_recall()
	return ""


## Host: puts a player at [place, depth], and starts or ends their cold with it.
func _set_place(player_id: String, place: String, depth: int) -> void:
	var was_cold: bool = player_places.has(player_id) and place_of(player_id) == IceDepth.ZONE
	player_places[player_id] = [place, depth]
	_track_cold(player_id, was_cold)


## Host: a player's cold stamp follows where they are. Coming into the caves stamps now (and
## replaces any stale stamp), unless they left within the grace: then the cold picks up where
## it was when they left (it pauses outside; Ryan, 2026-11-27), so the stamp moves on by the
## time they were away. Anywhere else has no stamp; leaving keeps it aside for the grace.
## Tells the guests when it changed.
func _track_cold(player_id: String, was_in_caves: bool) -> void:
	if FarmCommands.guest:
		return
	var now: float = GameClock.elapsed_days
	var in_caves: bool = player_places.has(player_id) and place_of(player_id) == IceDepth.ZONE
	if in_caves and (not was_in_caves or not cold_since.has(player_id)):
		var kept: Variant = _cold_kept.get(player_id)
		_cold_kept.erase(player_id)
		var back: bool = kept is Array and IceDepth.within_grace(float(kept[1]), now)
		cold_since[player_id] = now - maxf(float(kept[1]) - float(kept[0]), 0.0) if back else now
		ice_changed.emit()
	elif not in_caves and cold_since.has(player_id):
		_cold_kept[player_id] = [float(cold_since[player_id]), now]
		cold_since.erase(player_id)
		ice_changed.emit()


## Host: drops the stamps of everyone who is not in the caves.
func _prune_cold() -> void:
	if FarmCommands.guest:
		return
	var kept: Dictionary = _cold_in_caves()
	if kept.size() != cold_since.size():
		cold_since = kept
		ice_changed.emit()


## The cold stamps of the players the host has in the caves.
func _cold_in_caves() -> Dictionary:
	if FarmCommands.guest:
		return cold_since.duplicate()
	var kept: Dictionary = {}
	for who: Variant in cold_since:
		if place_of(str(who)) == IceDepth.ZONE:
			kept[who] = cold_since[who]
	return kept


## A player's cold in the Ice Caves, 0 to 100 %: 0 for anyone not in them. The host knows who is
## in the caves; a guest reads the stamp the host sent (it has one only while in them).
func cold_of(player_id: String = "") -> float:
	var who: String = player_id if player_id != "" else local_player_id
	if not cold_since.has(who) or (not FarmCommands.guest and place_of(who) != IceDepth.ZONE):
		return 0.0
	return IceDepth.cold(float(cold_since[who]), GameClock.elapsed_days)


## Where a player is; the farm for one the host has not heard from.
func place_of(player_id: String) -> String:
	return str(player_places.get(player_id, [ZonePresence.DEFAULT_PLACE, 0])[0])


func depth_of(player_id: String) -> int:
	return int(player_places.get(player_id, [ZonePresence.DEFAULT_PLACE, 0])[1])


## The players, in the order of `among`, who are in `place`.
func players_in(place: String, among: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for player_id: String in among:
		if place_of(player_id) == place:
			found.append(player_id)
	return found


## Host: a player left, or dropped.
func forget_place(player_id: String) -> void:
	var was: String = place_of(player_id) if player_places.has(player_id) else ""
	var on_trip: bool = _trip_players.has(player_id)
	player_places.erase(player_id)
	_track_cold(player_id, was == IceDepth.ZONE)
	_campers.erase(player_id)  # a camper who drops is out of bed (CoopBeds drops them too)
	_console_arrivals.erase(player_id)
	_trip_players.erase(player_id)
	# Gone mid-trip: the day trip is over with them, and nothing is charged. The shuttle
	# is not the farm's rover, so nothing is sent home.
	if not FarmCommands.guest and shuttle_trips.has(player_id):
		shuttle_trips.erase(player_id)
		shuttle_trips_changed.emit()
	if FarmCommands.guest or rover_zone == "" or not (was == rover_zone or on_trip):
		return
	# The last one on the trip dropped (a quit, a lost link, in the zone or in the dome
	# on the way): nobody is left to bring the rover back, and the host on the farm
	# cannot reach it. It goes home as it does for a rescue, so it is neither stranded
	# nor left with a stale heat trip (zones doc section 12.4) [PLACEHOLDER: home free
	# of charge].
	if _nobody_on_the_trip():
		bring_rover_home()


## A session starting or ending: only this screen's own player is known. A host whose
## session ends with the last one on the trip gone sends the rover home.
func clear_other_places() -> void:
	var mine: Variant = player_places.get(local_player_id)
	var others: bool = false
	for who: Variant in player_places:
		others = others or (who != local_player_id and str(player_places[who][0]) == rover_zone)
	for who: Variant in _trip_players:
		others = others or who != local_player_id
	player_places.clear()
	if not FarmCommands.guest:
		var staying: Dictionary = {}
		for who: Variant in shuttle_trips:
			if who == local_player_id:
				staying[who] = shuttle_trips[who]
		if staying.size() != shuttle_trips.size():
			shuttle_trips = staying  # a trip of someone who is gone is over
			shuttle_trips_changed.emit()
	if mine != null:
		player_places[local_player_id] = mine
	_prune_cold()
	var kept: bool = _trip_players.has(local_player_id)
	_trip_players.clear()
	if kept:
		_trip_players[local_player_id] = true
	if others and not FarmCommands.guest and _nobody_on_the_trip():
		bring_rover_home()


## The rover is below, and nobody is in its zone or on its trip.
func _nobody_on_the_trip() -> bool:
	return rover_zone != "" and _places_in(rover_zone).is_empty() and _trip_players.is_empty()


## Host: the rover below is on today's floor. A save loaded on another day, or the
## morning, has the layout change under it: a rover whose body is not on floor
## (every corner of its footprint, not just its middle) starts the depth again; one
## that is stays where it is. Never one that someone drives: that is left to the
## next check (`settle_due`, asked again by CoopRovers). A re-park is a new epoch.
## `refresh` asks the screen's rover where it is first (not on a load). Returns true
## if it was moved.
func settle_rover_depth(refresh: bool = true) -> bool:
	if FarmCommands.guest or rover_depth <= 0:
		settle_due = false
		return false
	if refresh:
		SaveGame.saving.emit()
	if CoopRovers.driver(TUNNEL_ROVER) != "":
		settle_due = true
		return false
	settle_due = false
	var map: PackedStringArray = ZoneDepth.grid_for(rover_depth, world_seed, GameClock.get_day_index(), rover_zone)
	if rover_transforms.has(TUNNEL_ROVER) and TunnelRock.holds_body_in(map, parked_rover_transform(TUNNEL_ROVER)):
		return false
	rover_transforms[TUNNEL_ROVER] = ZoneDepth.start_transform()
	rover_epoch += 1
	_emit_field_rover_changed()  # the field rover moved: a lease on the farm rover stays
	return true


## Host: the rover goes down a hatch (to the next depth) or up the way up (to the one
## above), for the player who drives it, or for the host or solo player when nobody
## does. `player_id` is filled in from the connection (FarmCommands). Returns "" or why
## not. The rover is in the Lava Tubes and, going down, within reach of the hatch (the
## hub's at depth 0, the trunk's at depths 1 and 2) or, going up, of the way up below
## (today's layout); the depth is one that exists and one step away (depth 3 has no way
## down). The rover then starts at the new depth (down: the start cell; up: beside the
## hatch it comes up by), and every screen rebuilds the tunnels from rover_depth.
func change_depth(target_depth: int, player_id: String = "") -> String:
	var reason: String = _rover_trip_problem(player_id)
	if reason != "":
		return reason
	var aquifer: bool = rover_zone == AquiferDepth.ZONE
	var mine: bool = rover_zone == MineDepth.ZONE
	var ice: bool = rover_zone == IceDepth.ZONE
	if target_depth < 0 or target_depth > ZoneDepth.max_depth_of(rover_zone) or absi(target_depth - rover_depth) != 1:
		return "There is no way there from here."
	var going_down: bool = target_depth > rover_depth
	if ZoneDepth.is_deep(target_depth):  # down into the deep depths or between them, in either zone
		reason = deep_problem(rover_zone)
		if reason != "":
			return reason
	var hub_hatch: Vector3 = AquiferDepth.hatch_position() if aquifer else (MineDepth.hatch_position() if mine else (IceDepth.hatch_position() if ice else ZoneDepth.descent_position(0)))
	var down_at: Vector3 = hub_hatch if rover_depth == 0 else ZoneDepth.descent_position(rover_depth)
	var there: Vector3 = down_at if going_down else ZoneDepth.ascent_position()
	reason = _rover_reach_problem(there, rover_zone)
	if reason != "":
		return reason
	var pose: Transform3D = ZoneDepth.arrival_pose(target_depth, going_down, false)
	if (aquifer or mine or ice) and not going_down and target_depth == 0:
		pose = Transform3D(Basis.IDENTITY, hub_hatch + Vector3(0.0, 0.05, TunnelRock.CELL_M))  # beside the Aquifer's or Mine's hatch
	_move_rover_to(target_depth, pose)
	return ""


## A loaded farm whose rover is below depth 3 of the Lava Tubes, the Flooded Aquifer or the
## Colony Mine while the way there is shut (an old or edited save: the lab level is low, the
## pump is gone, or the lift at depth 3 is broken) has it back up at depth 3's start: it loads, but the deep
## floors stay out of reach until the gate is met [PLACEHOLDER].
func _hold_deep_rover() -> void:
	if not ZoneDepth.is_deep(rover_depth) or deep_problem(rover_zone) == "":
		return
	rover_depth = ZoneDepth.FIRST_DEEP - 1
	rover_transforms[TUNNEL_ROVER] = ZoneDepth.start_transform()  # always a valid pose, even under a live drive lease
	rover_epoch += 1


## "" if the farm may go below depth 3 of `zone`, or what is missing in plain words (a zone
## with no deep depths has no gate).
func deep_problem(zone: String) -> String:
	if zone == TUNNELS_ZONE:
		return lava_deep_problem()
	if zone == AquiferDepth.ZONE:
		return aquifer_deep_problem()
	if zone == MineDepth.ZONE:
		return mine_deep_problem()
	return ""


## "" if the farm may go below depth 3 of the Flooded Aquifer, or what is missing in plain
## words: the lab level of the gate row AquiferDepth.DEEP_GATE, the farm's pump, and the lift
## at depth 3 repaired. Nothing is charged by asking.
func aquifer_deep_problem() -> String:
	var missing: PackedStringArray = []
	var level: String = lab_gate_problem(AquiferDepth.DEEP_GATE, "Depth 4 and below")
	if level != "":
		missing.append(level)
	if not pump_owned:
		missing.append("The farm has no pump.")
	if not is_lift_repaired(AquiferDepth.ZONE, ZoneDepth.LIFT_EVERY):
		missing.append("The lift at depth %d is not repaired." % ZoneDepth.LIFT_EVERY)
	if missing.is_empty():
		return ""
	return "The way below depth %d is shut. %s" % [ZoneDepth.FIRST_DEEP - 1, " ".join(missing)]


## "" if the farm may go below depth 3 of the Colony Mine, or what is missing in plain words:
## the lab level of the gate row MineDepth.DEEP_GATE and the lift at depth 3 repaired.
## Nothing is charged by asking.
func mine_deep_problem() -> String:
	var missing: PackedStringArray = []
	var level: String = lab_gate_problem(MineDepth.DEEP_GATE, "Depth 4 and below")
	if level != "":
		missing.append(level)
	if not is_lift_repaired(MineDepth.ZONE, ZoneDepth.LIFT_EVERY):
		missing.append("The lift at depth %d is not repaired." % ZoneDepth.LIFT_EVERY)
	if missing.is_empty():
		return ""
	return "The way below depth %d is shut. %s" % [ZoneDepth.FIRST_DEEP - 1, " ".join(missing)]


## "" if the farm may go below depth 3 of the Lava Tubes, or what is missing in plain
## words: the lab level of the gate row ZoneDepth.DEEP_GATE and the lift at depth 3 repaired.
func lava_deep_problem() -> String:
	var missing: PackedStringArray = []
	var level: String = lab_gate_problem(ZoneDepth.DEEP_GATE, "Depth 4 and below")
	if level != "":
		missing.append(level)
	if not is_lift_repaired(TUNNELS_ZONE, ZoneDepth.LIFT_EVERY):
		missing.append("The lift at depth %d is not repaired." % ZoneDepth.LIFT_EVERY)
	if missing.is_empty():
		return ""
	return "The way below depth %d is shut. %s" % [ZoneDepth.FIRST_DEEP - 1, " ".join(missing)]


## Host: the checks every move of the rover between depths has to pass: it is in the
## Lava Tubes, and `player_id` may take it. Nobody holds the lease (it ends half a
## second after the rover stops): the host and solo player, or a player who is in the
## tunnels at the rover's depth; or, while someone drives, that player. Returns "" or why.
func _rover_trip_problem(player_id: String) -> String:
	if not rover_zone in [TUNNELS_ZONE, AquiferDepth.ZONE, MineDepth.ZONE, IceDepth.ZONE]:
		return "The rover is not in a zone."
	var driver: String = CoopRovers.driver(TUNNEL_ROVER)
	if driver == "":
		var here: bool = place_of(player_id) == rover_zone and depth_of(player_id) == rover_depth
		if not player_id in ["", local_player_id] and not here:
			return "Only someone with the rover can take it up or down."
	elif driver != player_id:
		return "Someone else is driving the rover."
	return ""


## Host: why the tunnel rover is not within reach of `there` (where the rover is now:
## what a guest's driver told, this screen's own live rover, or the kept pose), or "".
## No SaveGame.saving here: it would make a screen whose rover has not caught up yet
## overwrite the pose a guest has driven to.
## `want` is the zone the move is for; only change_depth passes the Aquifer.
func _rover_reach_problem(there: Vector3, want: String = TUNNELS_ZONE) -> String:
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	return ZoneDepth.reach_problem(there, rover_zone, at != null, at if at != null else Vector3.ZERO, want)


## Host: puts the rover at `target_depth` at `pose` and tells everyone.
func _move_rover_to(target_depth: int, pose: Transform3D) -> void:
	rover_depth = target_depth
	rover_transforms[TUNNEL_ROVER] = pose
	rover_epoch += 1
	_note_depth(rover_zone, target_depth)
	_emit_field_rover_changed()


## The deepest depth reached in `zone` grows to `depth` if it is deeper than before.
func _note_depth(zone: String, depth: int) -> void:
	if zone == "" or depth <= int(deepest_depth.get(zone, 0)):
		return
	deepest_depth[zone] = depth
	lifts_changed.emit()


## True if the lift at `depth` of `zone` has been repaired.
func is_lift_repaired(zone: String, depth: int) -> bool:
	var depths: Variant = lifts_repaired.get(zone, [])
	return depths is Array and depth in (depths as Array)


## The deepest repaired lift of `zone` (the one the hub's lift goes to), or 0 if none.
func repaired_lift_depth(zone: String) -> int:
	var best: int = 0
	for depth: int in ZoneDepth.lift_depths():
		if is_lift_repaired(zone, depth):
			best = maxi(best, depth)
	return best


## Host: the farm's players fix the broken lift where the rover is: one time, for the
## whole farm, for good. `player_id` is filled in from the connection. Returns "" or why
## not. The player is in the Lava Tubes at a depth with a lift, the rover is there and
## within reach of the lift, the lift is not repaired yet, and the shared wallet and
## stock hold the cost (ZoneDepth.lift_cost: more at the deep lift, taken once).
func repair_lift(player_id: String = "") -> String:
	var depth: int = depth_of(player_id) if player_id != "" else rover_depth
	var zone: String = rover_zone if rover_zone in [TUNNELS_ZONE, AquiferDepth.ZONE, MineDepth.ZONE] else TUNNELS_ZONE
	if player_id != "" and place_of(player_id) != zone:
		if zone == MineDepth.ZONE:
			return "The lift is below the Colony Mine."
		return "The lift is below the Lava Tubes." if zone == TUNNELS_ZONE else "The lift is below the Flooded Aquifer."
	if not ZoneDepth.is_lift_depth(depth) or rover_zone != zone or rover_depth != depth:
		return "There is no lift to repair here."
	if is_lift_repaired(zone, depth):
		return "The lift is repaired already."
	var reason: String = deep_problem(zone) if ZoneDepth.is_deep(depth) else ""
	if reason != "":
		return reason
	reason = _rover_reach_problem(ZoneDepth.lift_position(depth), zone)
	if reason != "":
		return reason
	var cost: Vector2i = ZoneDepth.lift_cost(depth)
	if credits < cost.x or crystal_ore < cost.y:
		return ZoneDepth.repair_cost_text(depth) + " The farm does not have it yet."
	add_credits(-cost.x)
	crystal_ore -= cost.y
	ore_changed.emit(crystal_ore)
	var depths: Array = (lifts_repaired.get(zone, []) as Array).duplicate()
	depths.append(depth)
	lifts_repaired[zone] = depths
	lifts_changed.emit()
	post_phone("LIFT: repaired for good (depth %d). The hub's lift now comes here." % depth)
	return ""


## Host: the rover (and whoever is in the tunnels) takes the lift: from the hub down
## to the deepest repaired lift's entrance, or from a depth with a repaired lift up
## to the hub. Free once repaired. Same checks as change_depth (`_rover_trip_problem`),
## then the rover is within reach of the lift it takes. `target_depth` is where the
## screen means to go: a request that was raced by another move (the lift would take the
## rover somewhere else now) is refused rather than undone. Returns "" or why not.
func use_lift(target_depth: int, player_id: String = "") -> String:
	var reason: String = _rover_trip_problem(player_id)
	if reason != "":
		return reason
	if not rover_zone in [TUNNELS_ZONE, AquiferDepth.ZONE, MineDepth.ZONE]:
		return "There is no lift here."
	var target: int = 0
	if rover_depth == 0:
		target = repaired_lift_depth(rover_zone)
		if target == 0:
			return "The lift is broken. Repair it from its far end first."
	elif not ZoneDepth.is_lift_depth(rover_depth):
		return "There is no lift here."
	elif not is_lift_repaired(rover_zone, rover_depth):
		return "The lift is broken."
	if target != target_depth:
		return "The rover has moved: look again."
	if ZoneDepth.is_deep(target):
		reason = deep_problem(rover_zone)
		if reason != "":
			return reason
	reason = _rover_reach_problem(ZoneDepth.lift_position(rover_depth), rover_zone)
	if reason != "":
		return reason
	_move_rover_to(target, ZoneDepth.arrival_pose(target, target > 0, true))
	return ""


## The id of the rover the farm's real entrance deals with: the farm's own rover,
## or, while it is lent to a zone, the one it is in there. (A field rover that
## someone fast-travelled to is TUNNEL_ROVER, and the farm does not deal with it.)
func rover_here() -> String:
	return TUNNEL_ROVER if rover_lent else ROVER


## An older save (no unlock list) that shows any sign of the Lava Tubes having been
## visited: the rover is out, a field rover's pose was kept (the old way home kept
## it), something was found or a beacon placed there.
func _has_been_to_tunnels(data: Dictionary) -> bool:
	if rover_lent or rover_zone != "":
		return true
	var poses: Variant = data.get("rover_transforms", {})
	if poses is Dictionary and (poses as Dictionary).has(TUNNEL_ROVER):
		return true
	var taken: Variant = data.get("finds_taken", {})
	if taken is Dictionary and (taken as Dictionary).has(ZoneDepth.ZONE):
		return true
	var beacons: Variant = data.get("beacons_placed", [])
	if beacons is Array and not (beacons as Array).is_empty():
		return true
	# A trip that ended in a rescue left its phone lines (the rover pose was erased).
	var log: Variant = data.get("phone_log", [])
	if log is Array:
		var marks: Array[String] = []
		for key: String in ["rescue_text", "cost_text", "cost_none_text"]:
			marks.append(TunnelRecall.text(key).split("%s")[0])
		for line: Variant in log:
			for mark: String in marks:
				if line is String and mark != "" and (line as String).begins_with(mark):
					return true
	return false


## True if this is the rover's id in the place it is not in: the farm's own rover
## while it is lent, a zone's field rover while no zone is live.
func rover_is_away(rover_id: String) -> bool:
	if rover_id == ROVER:
		return rover_lent
	return rover_id == TUNNEL_ROVER and rover_zone == ""


## Takes the farm's rover into the tunnels or out, from the pad there (the real
## entrance, which lends it: `rover_lent`). Returns "" or why not. It comes in at
## the mouth and comes out where it went in. While a field rover is live in the
## tunnels (fast_travel) the farm rover cannot go in: there is one rover there.
func move_rover(into_tunnels: bool, player_id: String = "") -> String:
	return _move_rover(TUNNELS_ZONE if into_tunnels or rover_zone == "" else rover_zone, into_tunnels, player_id)


## Host: the same for the Flooded Aquifer's sinkhole (a pad south of the plateau):
## `into` takes the farm's rover down, false brings it home from the Aquifer's hub.
func move_rover_aquifer(into: bool, player_id: String = "") -> String:
	return _move_rover(AquiferDepth.ZONE, into, player_id)


## Host: the same for the Colony Mine's gate (on the plateau road). The gate has to be open
## (Bram's key quest); until then nothing goes in and nothing else happens.
func move_rover_mine(into: bool, player_id: String = "") -> String:
	if into and not mine_gate_open:
		return MineDepth.GATE_SEALED_TEXT
	return _move_rover(MineDepth.ZONE, into, player_id)


## Host: the same for the Ice Caves' ramp at the north edge. No key: below the zone band's first level (zones.json)
## the entrance only warns (main_farm); the rover goes in all the same.
func move_rover_ice(into: bool, player_id: String = "") -> String:
	return _move_rover(IceDepth.ZONE, into, player_id)


## Where a zone's mouth is on the farm.
func _mouth_of(zone: String) -> Vector3:
	if zone == IceDepth.ZONE:
		return ICE_PAD
	if zone == AquiferDepth.ZONE:
		return AQUIFER_PAD
	if zone == MineDepth.ZONE:
		return MINE_PAD
	return TUNNEL_PAD


## The one trip in or out for a zone with a mouth on the farm (the Lava Tubes' and the
## Aquifer's sinkhole): `zone` is the one the rover goes into, or comes out of.
func _move_rover(zone: String, into_tunnels: bool, player_id: String) -> String:
	if into_tunnels == rover_lent:
		return "The rover is already there."
	if not into_tunnels and rover_zone != zone:
		return "The rover is in another zone."
	if into_tunnels and TunnelRecall.closed(GameClock.elapsed_days):
		return TunnelRecall.text("closed_text")
	# Players in there on it, or still on the trip (a guest up in the dome): the mouth stays shut.
	if into_tunnels and rover_zone != "" and not (_places_in(rover_zone).is_empty() and _trip_players.is_empty()):
		return FastTravel.text("field_rover_out")
	if not CoopRovers.driver(rover_here()) in ["", player_id]:
		return "Someone else is driving the rover."
	var who: String = _player(player_id)
	if who != local_player_id:
		# A guest asks from where it is: in at the farm's mouth, out from the hub.
		if into_tunnels and place_of(who) != ZonePresence.FARM:
			return "The rover goes in from the farm."
		if not into_tunnels and (place_of(who) != zone or depth_of(who) != 0):
			return "The way out is from the hub."
	var pad: Vector3 = _mouth_of(zone) if into_tunnels else TUNNEL_EXIT
	var at: Variant = _rover_pose_now(rover_here())  # honours the told pose: no save of this screen's rover over it
	if at == null or (at as Vector3).distance_to(pad) > TUNNEL_PAD_REACH_M:
		return "The rover is not on the pad."
	if not into_tunnels and rover_depth > 0:
		return "The rover must come up first."
	if into_tunnels:
		_console_arrivals.clear()  # a mouth entry starts a trip: the baseline is the mouth's
		if rover_zone != "":
			# Every refusal is behind us. Nobody is with the field rover: it goes, and the mouth is free.
			_release_field_rover()
			_emit_field_rover_changed()
		park_rover(TUNNEL_ROVER, TUNNEL_START)
		rover_epoch += 1  # a new pose: poses in flight from the last trip are old news
		_ore_at_entry = crystal_ore
		if not zones_unlocked.has(zone):
			zones_unlocked.append(zone)  # the first real visit opens it to the console
	rover_zone = zone if into_tunnels else ""
	rover_lent = into_tunnels
	if into_tunnels:
		# Said now, not when its screen reports: a drop in the fade still counts as below.
		_set_place(who, zone, 0)
		_trip_players[who] = true
	else:
		_set_place(who, ZonePresence.FARM, 0)
		_console_arrivals.clear()  # the trip is over
		_trip_players.clear()
		_ore_at_entry = -1  # no trip: a late rescue has nothing to take ore for
	rover_place_changed.emit()
	return ""


# --- Fast travel (zones doc section 8.1, build step 7) ---------------------------

## Host: the player goes from the dome's console to a zone's field rover, in the
## zone. `zone_id` is a zone with a scene; `player_id` is filled in from the
## connection. Returns "" or why not (the screen then changes scene). The farm
## rover stays home. If no zone rover is live, a field rover is put at the zone's
## start; if one is, the player joins it where it is, unless it is left below with
## nobody below (FastTravel.arrival_plan): then it starts again at the hub, as a
## new epoch. Shut after the rescue hour, like the mouth.
func fast_travel(zone_id: String, player_id: String = "") -> String:
	if Shuttle.is_moon(zone_id):
		return Shuttle.text("by_shuttle_text")  # a moon is reached by the shuttle alone
	if not ZoneData.is_playable(StringName(zone_id)) or not zones_unlocked.has(zone_id):
		return FastTravel.text("no_zone")
	if place_of(player_id) != ZonePresence.DOME:
		return FastTravel.text("console_in_dome")
	if TunnelRecall.closed(GameClock.elapsed_days):
		return TunnelRecall.text("closed_text")
	if rover_zone != "" and rover_zone != zone_id:
		return FastTravel.text("field_rover_out")
	var plan: String = FastTravel.arrival_plan(rover_zone != "", rover_depth, _places_in(zone_id, player_id))
	if plan == FastTravel.START:
		SaveGame.saving.emit()
		rover_transforms[TUNNEL_ROVER] = TUNNEL_START
		rover_zone = zone_id  # the farm rover stays where it is, home
		zone_heat_trip = false  # a new trip, even into the zone the rover already stood in
		_ore_at_entry = -1  # a fast-travel rescue takes credits only [PLACEHOLDER]: the farm's ore is not the zone's
		rover_epoch += 1
	elif plan == FastTravel.RE_PARK:
		if CoopRovers.driver(TUNNEL_ROVER) != "":
			return FastTravel.text("someone_driving")
		rover_depth = 0
		zone_heat_trip = false  # a new trip from the hub
		rover_transforms[TUNNEL_ROVER] = TUNNEL_START
		rover_epoch += 1
	_set_place(player_id, zone_id, rover_depth)
	_trip_players[player_id] = true
	_console_arrivals[player_id] = true
	if plan != FastTravel.JOIN:
		_emit_field_rover_changed()  # a rover moved; joining moves none, so nobody's lease is lost
	return ""


## Host: the player goes from a zone to the dome, where the console is. The last
## one out of a zone whose field rover is its own (not the farm's, lent) lets it
## go: the next arrival starts one again. `player_id` is filled in from the
## connection. Returns "" or why not.
func leave_zone(player_id: String = "") -> String:
	var zone: String = place_of(player_id)
	if zone == ZonePresence.FARM or zone == ZonePresence.DOME:
		return "You are not in a zone."
	if Shuttle.is_moon(zone):
		return Shuttle.text("home_by_console_text")  # the way home is the hub's return shuttle
	if rover_lent:
		return FastTravel.text("use_the_mouth")  # the farm's rover is out: it comes home by the mouth
	if depth_of(player_id) != 0 or rover_depth != 0:
		return "The way home is from the hub."
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	if at == null or (at as Vector3).distance_to(TUNNEL_EXIT) > TUNNEL_PAD_REACH_M:
		return "The rover is not on the pad."
	_set_place(player_id, ZonePresence.DOME, 0)
	_console_arrivals.erase(player_id)
	_trip_players.erase(player_id)
	if _nobody_on_the_trip():
		_release_field_rover()
		_emit_field_rover_changed()
	return ""


## The leases and poses the pad check reads; the CoopRovers autoload unless a test
## puts its own here.
var rovers_node: Node = null


## Where a rover is now, as a position, or null if it has none. Read without a
## side effect (nothing is parked). Someone else's drive wins: with a teammate on the
## farm, the pose the host last accepted or heard (CoopRovers) is the newest word,
## and the host's own controller, which may not have run yet, must not overwrite it.
## Only a rover this player drives (alone, or the host with nobody else driving) is
## asked of its controller, which knows better than the last parking.
func _rover_pose_now(rover_id: String) -> Variant:
	var rovers: Node = rovers_node if rovers_node != null else CoopRovers
	if rovers.together():
		var heard: Variant = rovers.told_pose(rover_id)
		if heard != null:
			return (heard as Transform3D).origin
	if rovers.driver(rover_id) in ["", local_player_id]:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		for node: Node in tree.get_nodes_in_group(LIVE_ROVER_GROUP) if tree != null else []:
			if node.get("rover_id") == rover_id:
				var live: Variant = node.call("live_transform")
				if live != null:
					return (live as Transform3D).origin
	if not rover_transforms.has(rover_id):
		return null
	return parked_rover_transform(rover_id).origin


## The [place, depth] of everyone the host knows to be in `zone_id`.
func _places_in(zone_id: String, except_player: String = "") -> Array:
	var found: Array = []
	for who: Variant in player_places:
		if who != except_player and str(player_places[who][0]) == zone_id:
			found.append(player_places[who])
	return found


## rover_place_changed for the field rover alone: leases of other rovers stay.
func _emit_field_rover_changed() -> void:
	rover_place_scope = TUNNEL_ROVER
	rover_place_changed.emit()
	rover_place_scope = ""


## Host: a field rover (not the farm's) goes away: the zone has none live. Nothing
## of the farm's moves.
func _release_field_rover() -> void:
	rover_transforms.erase(TUNNEL_ROVER)
	rover_zone = ""
	_ore_at_entry = -1
	_console_arrivals.clear()  # the trip is over
	_trip_players.clear()
	rover_epoch += 1


# --- The recall (zones doc section 6.1) ---------------------------------------

## The day the warning, and the rescue, were last given for. Not saved: a farm
## that loads in the tunnels late in the night is warned, or rescued, once more.
var _recall_warned_day: int = 0
## The day each expedition traveller (player -> day) was last warned, and last put to bed or
## flown home, marked only when it happened to them. Not saved, like the tunnels' days.
var _expedition_warned_day: Dictionary = {}
var _expedition_rescued_day: Dictionary = {}
var _recall_rescued_day: int = 0
## The same for each guest (player -> day), for the guests the host sees below.
var _guest_warned_day: Dictionary = {}
var _guest_rescued_day: Dictionary = {}
## What the last rescues cost, said on the phone in the morning.
var _rescue_notes: Array[String] = []
## The crystal ore the farm held when the rover went into the tunnels (-1: not
## known, e.g. a farm that loaded in them). Ore gained since is what a rescue
## can take; the rest of the pile is the farm's and is never touched [ASSUMPTION].
var _ore_at_entry: int = -1
## Host: the players who came to the zone by the console on this trip. Their rescue
## takes credits only [PLACEHOLDER]: the ore baseline is the mouth entrant's. Not saved.
var _console_arrivals: Dictionary = {}
## Host: the players on this trip of the rover below: who took it in by the mouth or the
## console, until they leave the zone or the trip ends. A guest who steps into the dome
## from the tunnels is still on it. Not saved.
var _trip_players: Dictionary = {}
## Only tests set it: where the local player is (true: in the tunnels).
var recall_in_tunnels: Callable = Callable()
## Only tests set it: stands in for CoopBeds, and makes the rescue run at once.
var recall_beds: Object = null
## Only tests set it: stands in for CoopSession.tell_recall(player_id, step).
var recall_told: Callable = Callable()


## The local player stands in the basalt tunnels. A guest's scene is the guest's own:
## the host knows where a guest is only from the place the guest reported
## (`player_places`, see _guests_below).
func _local_in_tunnels() -> bool:
	if recall_in_tunnels.is_valid():
		return bool(recall_in_tunnels.call())
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	return scene != null and SceneSwitcher.is_zone_scene(scene.scene_file_path)


## Host: the guests the host has below, in a zone and not on the farm or in the dome
## (the same rule as for the host itself), in a fixed order.
func _guests_below() -> Array[String]:
	var found: Array[String] = []
	for who: Variant in player_places:
		if str(who) != local_player_id and not place_of(str(who)) in [ZonePresence.DOME, ZonePresence.FARM] 				and not Shuttle.is_moon(place_of(str(who))):
			found.append(str(who))
	found.sort()
	return found


## Host: warns each player in the tunnels at the warning hour and has them
## carried out at the rescue hour, once each a day (the host's own, and each guest's
## own, so one rescue never uses up another's). Guests never run this.
## Host: the recall for an expedition's travellers (zones step 18), once a day like the
## tunnels' [PLACEHOLDER]. Asleep at the camp, nothing: not warned, not rescued, not sent
## home. Awake, at 00:00 they are told to go to the camp; at 02:00 they are put to bed
## there with a night's supplies if the camp is open and one is held, else flown home
## with the normal rescue fee (TunnelRecall.cost, credits only) and put to bed on the farm.
func _tick_expeditions() -> void:
	if FarmCommands.guest or shuttle_trips.is_empty():
		return
	var day: int = GameClock.get_day_index()
	var warned: bool = false
	var due: Array[String] = []
	var ids: Array = shuttle_trips.keys()
	ids.sort()
	for id: String in ids:
		if not Shuttle.is_expedition(shuttle_trips[id]) or not Shuttle.is_moon(place_of(id)) or is_camping(id):
			continue  # not away on one, or asleep at the camp: nothing for them
		match TunnelRecall.phase(GameClock.elapsed_days, int(_expedition_warned_day.get(id, 0)), int(_expedition_rescued_day.get(id, 0))):
			TunnelRecall.WARN:
				_expedition_warned_day[id] = day
				warned = true
			TunnelRecall.RESCUE:
				due.append(id)  # their day is used up in _expedition_recall, when it happens to them
	if warned:
		post_phone(Shuttle.text("expedition_warn_text"))  # one shared line, as the phone is shared
	if due.is_empty():
		return
	if recall_beds != null:
		_expedition_recall(due)
	else:
		_expedition_recall.call_deferred(due)  # not inside the clock's own signal


## Host: the 02:00 step for the awake expedition travellers `ids` (see _tick_expeditions).
## All the bookkeeping first, then every bed, so the last into bed ends the day with the
## others already counted (as _carry_out does). One who turned in at the camp earlier tonight
## and got up (a paid night, `_campers`) is put back to bed free: no second supply, no second
## night counted, no fee. A traveller's day is used up only when they are put to bed or flown
## home, so one who slept through the hour is recalled if they get up after it.
func _expedition_recall(ids: Array[String]) -> void:
	var to_bed: Array[String] = []
	for id: String in ids:
		var trip: Variant = shuttle_trips.get(id)
		if not Shuttle.is_expedition(trip) or is_camping(id) or id in _beds().in_bed:
			continue  # home, asleep or in bed in the moment since the hour
		var moon: String = str((trip as Dictionary)["moon"])
		_expedition_warned_day[id] = GameClock.get_day_index()
		_expedition_rescued_day[id] = GameClock.get_day_index()
		if _campers.has(id):
			post_phone(Shuttle.text("expedition_bedded_text"))  # tonight is paid already
		elif camps_open.has(moon) and camp_supplies >= 1 and Camp.is_moon_camp(moon):
			update_quests([], false)  # the job's next step opens before the night is counted
			_camp_night(id, Camp.EXPEDITION_NIGHT_COUNT, false, true)
			post_phone(Shuttle.text("expedition_camped_text"))
		else:
			var fee: int = int(TunnelRecall.cost(credits, 0)["credits"])
			if fee > 0:
				add_credits(-fee)
			_return_traveller(id, Shuttle.text("expedition_flown_text") % [Shuttle.moon_name(moon), SP811.integer(fee)])
		to_bed.append(id)
	for id: String in to_bed:
		_beds().recall_to_bed(id)


func _tick_recall() -> void:
	# Rover not in the tunnels: the player walks out with E as today [ASSUMPTION].
	if FarmCommands.guest or not rover_in_tunnels:
		return
	var day: int = GameClock.get_day_index()
	var host_warned: bool = false
	var out: Array[String] = []
	if _host_below() and not is_camping(local_player_id):
		match TunnelRecall.phase(GameClock.elapsed_days, _recall_warned_day, _recall_rescued_day):
			TunnelRecall.WARN:
				_recall_warned_day = day
				host_warned = true
				post_phone(TunnelRecall.text("warn_text"))
			TunnelRecall.RESCUE:
				out.append(local_player_id)
	for guest_id: String in _guests_below():
		if is_camping(guest_id):
			continue  # asleep at a camp: no warning, no rescue (zones doc 6.2)
		match TunnelRecall.phase(GameClock.elapsed_days, int(_guest_warned_day.get(guest_id, 0)), int(_guest_rescued_day.get(guest_id, 0))):
			TunnelRecall.WARN:
				_guest_warned_day[guest_id] = day
				# On their own phone: the shared log is everyone's. The host's own line
				# already reaches a guest through that log, so it is not told twice.
				if not host_warned:
					_tell_guest(guest_id, TunnelRecall.WARN)
			TunnelRecall.RESCUE:
				out.append(guest_id)
	if not out.is_empty():
		_start_carry_out(out)


## The host is in the tunnels (out through the pad but still fading out of the tunnels
## scene: already home).
func _host_below() -> bool:
	return _local_in_tunnels() and not (player_places.has(local_player_id) and place_of(local_player_id) in [ZonePresence.DOME, ZonePresence.FARM])


## Not inside the clock's own signal: the day may end and the scene change.
func _start_carry_out(players: Array[String]) -> void:
	if recall_beds != null:
		_carry_out(players)
	else:
		_carry_out.call_deferred(players)


## Host: says one guest the recall's step (CoopSession.tell_recall).
func _tell_guest(player_id: String, step: String) -> void:
	if recall_told.is_valid():
		recall_told.call(player_id, step)
	else:
		CoopSession.tell_recall(player_id, step)


## Still below, at the moment of the carrying: the rover is in the tunnels and the
## player is there (a guest in a zone, the host in the tunnels scene).
func _carry_out_due(player_id: String) -> bool:
	if not rover_in_tunnels or is_camping(player_id):
		return false
	if player_id == local_player_id:
		return _host_below()
	return player_places.has(player_id) and not place_of(player_id) in [ZonePresence.DOME, ZonePresence.FARM] 		and not Shuttle.is_moon(place_of(player_id))


## The crew carries these players out of the tunnels, all of them as one act: each
## bill is paid and the rover comes home when nobody is left on the trip BEFORE any is
## put in bed (the last into bed ends the day, and a player still below then would be
## left under it). The farm is sent to the guests, then each is in bed (so the
## all-in-bed rule counts them), a guest is told to open the farm and the local
## player's farm scene opens. One who left the zone in the moment since the hour is not
## carried out or charged, and the day it would have been is not used up.
func _carry_out(players: Array[String]) -> void:
	var day: int = GameClock.get_day_index()
	var carried: Array[String] = []
	for player_id: String in players:
		if not _carry_out_due(player_id):
			continue
		if player_id == local_player_id:
			_recall_warned_day = day
			_recall_rescued_day = day
		else:
			_guest_warned_day[player_id] = day
			_guest_rescued_day[player_id] = day
		rescue_from_tunnels(player_id)
		carried.append(player_id)
	if carried.is_empty():
		return
	if not FarmCommands.guest:
		CoopSync.send_farm()  # the guests see the bill and the rover before the words
	var beds: Object = recall_beds if recall_beds != null else CoopBeds
	for player_id: String in carried:
		beds.recall_to_bed(player_id)
	for player_id: String in carried:
		if player_id != local_player_id:
			_tell_guest(player_id, TunnelRecall.RESCUE)
		elif is_inside_tree():
			SceneSwitcher.go_to(SceneSwitcher.FARM_SCENE)


## Host: pays for a rescue and brings the rover home. Returns the cost
## ({ credits, ore, waived }, see TunnelRecall.cost). The wallet and the ore are
## the farm's, shared (there is no pack of one's own yet) [ASSUMPTION]. What a
## player found (tarantulas, blocks, parts, samples) is not touched, and nothing
## drifts for it. The morning's phone line says what it cost.
func rescue_from_tunnels(player_id: String = "") -> Dictionary:
	if FarmCommands.guest:
		return TunnelRecall.cost(0, 0)  # the host decides and applies it
	var who: String = performer_name(_player(player_id))
	var leaving: String = player_id if player_id != "" else local_player_id
	if player_places.has(leaving) or rover_zone != "":
		_set_place(leaving, ZonePresence.FARM, 0)  # carried out, to bed
	_cold_kept.erase(leaving)  # a rescue ends the cold: no grace
	var ore: int = 0 if _console_arrivals.has(leaving) else ore_carried_in()
	_console_arrivals.erase(leaving)
	_trip_players.erase(leaving)  # carried out: off the trip
	# A drive lease of theirs on the rover below ends with the trip.
	if CoopRovers.driver(TUNNEL_ROVER) == leaving:
		CoopRovers.release(leaving)
	var bill: Dictionary = TunnelRecall.cost(credits, ore)
	if bill["credits"] > 0:
		add_credits(-int(bill["credits"]))
	if bill["ore"] > 0:
		crystal_ore -= int(bill["ore"])
		ore_changed.emit(crystal_ore)
		# That ore is taken: the next one carried out of this trip is not charged for it
		# again, only for ore gained since [PLACEHOLDER].
		_ore_at_entry = crystal_ore
	# With nobody else recorded below, the rover goes: the farm's lent one comes home, a
	# field one is released (else the farm keeps rover_in_tunnels, and a save would send
	# Continue and a second rescue back down). While someone is still recorded there it stays.
	# [KNOWN LIMIT] a guest still fading in is not recorded yet: the unacknowledged
	# airlock race (a follow-up needs host-acknowledged arrivals).
	if _nobody_on_the_trip():
		bring_rover_home()  # lent: home; field: released with its scoped emit
	post_phone(TunnelRecall.text("rescue_text") % who.to_lower())
	var line: String
	if bill["credits"] == 0 and bill["ore"] == 0:
		line = TunnelRecall.text("cost_none_text") % who
	else:
		line = TunnelRecall.text("cost_text") % [
			who, SP811.integer(int(bill["credits"])), SP811.integer(int(bill["ore"]))]
	if bill["waived"] > 0 and bill["credits"] > 0:
		line += " " + TunnelRecall.text("cost_waived_text") % SP811.integer(int(bill["credits"]))
	_rescue_notes.append(line)
	return bill


## The ore gained since the rover went into the tunnels: all a rescue can take.
func ore_carried_in() -> int:
	return maxi(crystal_ore - _ore_at_entry, 0) if _ore_at_entry >= 0 else 0


## The rover is on the farm pad where it went in, whatever it was doing in the
## tunnels (a rescue never strands it). A rover that is not in the tunnels (a
## guest drove it out) is left where it is.
func bring_rover_home() -> void:
	if FarmCommands.guest or not rover_in_tunnels:
		return
	if not rover_lent:
		# A field rover, not the farm's: it goes, and the farm rover is where it was.
		_release_field_rover()
		_emit_field_rover_changed()
		return
	var mouth: Vector3 = _mouth_of(rover_zone)  # the way it came in
	var home: Transform3D = parked_rover_transform(ROVER, Transform3D(Basis.IDENTITY, mouth))
	if home.origin.distance_to(mouth) > TUNNEL_PAD_REACH_M:
		home = Transform3D(Basis.IDENTITY, mouth)
	rover_transforms[ROVER] = home
	rover_transforms.erase(TUNNEL_ROVER)
	rover_in_tunnels = false
	_ore_at_entry = -1
	_console_arrivals.clear()  # the trip is over
	_trip_players.clear()
	rover_epoch += 1
	rover_place_changed.emit()


## Remembers where a rover is parked, so it is still there when the farm scene
## loads again.
func park_rover(rover_id: String, at: Transform3D) -> void:
	if FarmCommands.guest:
		return  # it is where the host parked it
	if at.is_finite():
		rover_transforms[rover_id] = at


## Where `rover_id` was parked; `fallback` if it has not been parked yet.
func parked_rover_transform(rover_id: String, fallback: Transform3D = Transform3D.IDENTITY) -> Transform3D:
	return rover_transforms.get(rover_id, fallback)


## The OIRM account (section 1.7): opened by sending OIRM a standard that was
## bought, for its first calibration there.
func has_oirm_account() -> bool:
	for trip: Dictionary in oirm_trips:
		var sensor: DriftingSensor = get_sensor(trip["standard_id"])
		if sensor != null and sensor.tier >= 1:
			return true
	return false


## Why this standard's tier is not open yet, or "": the condition the tier has
## always had, then its lab level (section 3.4). The contract's discount opens
## nothing early: the standard it is for waits for its tier like any other.
func tier_problem(standard_id: String) -> String:
	if _is_contract_stock(standard_id) and KEPT_CONTRACT_SALE in lab_gates_kept:
		return ""
	var problem: String = _tier_condition_problem(standard_id)
	if problem != "":
		return problem
	var tier: int = get_sensor(standard_id).tier
	return lab_gate_problem("tier%d" % tier, "Tier %d equipment" % tier)


## "needs lab level 18" if the lab level is all that keeps this standard's tier
## shut, for the seller's list. "" if it is open or waits for something else.
func tier_lab_note(standard_id: String) -> String:
	if _tier_condition_problem(standard_id) != "" or tier_problem(standard_id) == "":
		return ""
	return lab_gate_note("tier%d" % get_sensor(standard_id).tier)


## The conditions a tier had before the lab level, which stay (section 10, 4).
func _tier_condition_problem(standard_id: String) -> String:
	if not tier1_unlocked:
		return "Tier 1 equipment needs a clean audit on file first."
	var tier: int = get_sensor(standard_id).tier
	if tier < 2:
		return ""
	if not has_oirm_account():
		return "Tier %d equipment needs an OIRM account: send a standard you bought for its first OIRM calibration." % tier
	if tier >= 3 and not traceable_lab:
		return "Tier 3 equipment needs Vance's traceable lab sign-off: two clean audits in a row."
	if tier >= 3 and not _has_oirm_certified_tier2():
		return "Tier 3 equipment needs a Tier 2 standard with a current OIRM certificate."
	return ""


func _has_oirm_certified_tier2() -> bool:
	for id: String in standard_ids():
		if (sensors[id] as DriftingSensor).tier == 2 and not at_oirm.has(id) and standard_problem(id) == "" \
				and certificates[id].get("issuer", "") == "OIRM":
			return true
	return false


func _is_bram_stock(standard_id: String) -> bool:
	return (sensors[standard_id] as DriftingSensor).seller == "bram" or _is_contract_stock(standard_id)


## Standards Bram stocks, in data order (owned ones included). Tier 2 and up
## show once their old condition holds, with the lab level they still need
## (tier_lab_note); the contract's standard shows from the day it is earned.
func bram_catalog() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_standard_ids():
		if _is_bram_stock(id) and ((sensors[id] as DriftingSensor).tier < 2 or owned_standards.has(id)
				or _is_contract_stock(id) or _tier_condition_problem(id) == ""):
			ids.append(id)
	return ids


## The contract standard Bram can sell once the contract is complete (and
## keeps listing as on the colony after it is bought).
func _is_contract_stock(standard_id: String) -> bool:
	return standard_id == contract_standard_id() and contract_state in ["complete", "fulfilled"]


## Bram's price in credits, after the contract discount once it applies.
## After Bram's one-use discount too, if `player_id` ("" = the local player)
## holds one and the standard is Bram's.
func standard_price_credits(standard_id: String, player_id: String = "") -> int:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null:
		return 0
	var price: int = sensor.price_credits
	if _is_contract_stock(standard_id):
		price = _discounted(price)
	return price * (100 - standard_discount_pct(standard_id, player_id)) / 100


## The percent off Bram's one-use discount takes from this standard for
## `player_id` now: 0 for a standard that is not Bram's (Kestrel's has none) or
## when none is held. It lowers the price only: the gates still apply.
func standard_discount_pct(standard_id: String, player_id: String = "") -> int:
	if get_sensor(standard_id) == null or not _is_bram_stock(standard_id) or one_use_count(ONE_USE_DISCOUNT, player_id) < 1:
		return 0
	return clampi(QuestEngine.one_use_pct(ONE_USE_DISCOUNT), 0, 100)


func _discounted(price: int) -> int:
	return price * (100 - contract_discount_pct()) / 100


## "250 CR + 2 crystal ore" for a standard's price.
func standard_price_text(standard_id: String, player_id: String = "") -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null:
		return ""
	var off: int = standard_discount_pct(standard_id, player_id)
	return "%s CR + %d crystal ore%s" % [SP811.integer(standard_price_credits(standard_id, player_id)), sensor.price_ore,
		"" if off == 0 else " (%d %% off, one use)" % off]


## Why Bram can't sell this standard right now, or "" if he can.
func standard_purchase_problem(standard_id: String, player_id: String = "") -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null or sensor.role != "standard" or not _is_bram_stock(standard_id):
		return "Bram doesn't stock that."
	return _purchase_problem(standard_id, player_id)


func _purchase_problem(standard_id: String, player_id: String = "") -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if owned_standards.has(standard_id):
		return "The %s is already on the colony." % sensor.short_name
	var gate: String = tier_problem(standard_id)
	if gate != "":
		return gate
	if credits < standard_price_credits(standard_id, player_id) or crystal_ore < sensor.price_ore:
		return "Costs %s; you have %s CR and %d crystal ore." % [
			standard_price_text(standard_id, player_id), SP811.integer(credits), crystal_ore]
	return ""


## Buys a standard from Bram (section 1.7). Returns "" on success, or
## the reason it can't happen. It arrives with a maker's certificate traceable
## to OIRM, valid for its first interval, and puts the units it calibrates in
## service (due one interval from today, with no calibration on record yet).
func buy_standard(standard_id: String, player_id: String = "") -> String:
	player_id = _player(player_id)
	var problem: String = standard_purchase_problem(standard_id, player_id)
	if problem != "":
		return problem
	var sensor: DriftingSensor = get_sensor(standard_id)
	var today: int = GameClock.get_day_index()
	# Bram's one-use discount comes off this price and is used up with it.
	var off: int = standard_discount_pct(standard_id, player_id)
	# New from the maker: adjusted against their own OIRM-traceable reference.
	var zeroed: Dictionary = _take_standard(standard_id, player_id)
	if off > 0 and _spend_one_use(ONE_USE_DISCOUNT, player_id):
		post_phone(QuestEngine.one_use_used_line(ONE_USE_DISCOUNT))
	sensor.cal_due_day = today + sensor.cal_interval_days
	var prefix: String = sensor.certificate_prefix if sensor.certificate_prefix != "" else "MKR"
	var issuer: String = sensor.maker if sensor.maker != "" else "the maker"
	var cert: Dictionary = _issue_certificate(standard_id, today, null, zeroed["as_left"], false, issuer, prefix)
	var service: Array = _put_units_in_service(standard_id)
	var text: String = "BRAM: One %s, still in the crate. Certificate %s from %s, good to day %d." % [
		sensor.short_name, cert["id"], issuer, cert["due_day"]]
	if service[0] != "":
		text += " Calibrate the %s against it before Vance's next visit." % service[0]
	post_phone(text + service[1])
	if standard_id == contract_standard_id() and contract_state == "complete":
		contract_state = "fulfilled"
		credibility_changed.emit(credibility)
	_award_lab_xp("buy_standard", player_id, calibration_xp_scale(standard_id))
	upgrades_changed.emit()
	oirm_changed.emit()
	return ""


## Pays for a standard and puts it on the colony, reading true. Returns the
## zeroing.
func _take_standard(standard_id: String, player_id: String = "") -> Dictionary:
	var sensor: DriftingSensor = get_sensor(standard_id)
	add_credits(-standard_price_credits(standard_id, player_id))
	crystal_ore -= sensor.price_ore
	ore_changed.emit(crystal_ore)
	owned_standards[standard_id] = GameClock.get_day_index()
	sensor.cal_interval_days = sensor.initial_interval_days if sensor.initial_interval_days > 0 \
		else int(_interval_cfg("initial_days", 5.0))
	var zeroed: Dictionary = sensor.zero(0.0)
	sensor.last_cal_day = GameClock.get_day_index()
	return zeroed


## Puts the units a bought standard calibrates in service (due one interval
## from today). Returns their names, and a line about the units it takes over
## from another standard.
func _put_units_in_service(standard_id: String) -> Array:
	var today: int = GameClock.get_day_index()
	var units: PackedStringArray = []
	# A unit this standard takes over was already in service: it moves to the
	# new standard but keeps its due day.
	var taken: Array[String] = []
	var takes_over: Variant = DataManager.get_value(DRIFT_TABLE, "instruments/%s/takes_over" % standard_id, [])
	if typeof(takes_over) == TYPE_ARRAY:
		for unit_id: Variant in takes_over:
			var unit: DriftingSensor = get_sensor(str(unit_id))
			if unit != null and unit.role == "unit" and unit.calibrated_by != standard_id:
				var was_in_service: bool = is_in_service(str(unit_id))
				unit.calibrated_by = standard_id
				if was_in_service:
					taken.append(str(unit_id))
	for id: String in all_unit_ids():
		var unit: DriftingSensor = sensors[id]
		if unit.calibrated_by != standard_id or id in taken or robot_of(id) != "":
			continue
		unit.cal_due_day = today + unit.cal_interval_days
		# Put in service today: the first calibration is not interval evidence.
		unit.last_cal_day = today
		units.append(_mid_sentence(unit.short_name))
	var taken_text: String = ""
	if not taken.is_empty():
		var taken_names: PackedStringArray = []
		for id: String in taken:
			taken_names.append(_mid_sentence(instrument_name(id)))
		taken_text = " The %s now calibrates against it." % " and the ".join(taken_names)
	return [" and the ".join(units), taken_text]


func bram_line(section: String) -> String:
	var lines: Variant = DataManager.get_value(DISPATCH_TABLE, "npcs/bram/" + section)
	if typeof(lines) != TYPE_ARRAY or (lines as Array).is_empty():
		return ""
	# Only words: a guest's copy of the generator is the host's to draw from.
	return str((lines as Array).pick_random() if FarmCommands.guest else _pick(lines as Array))


func _on_day_started_regrow() -> void:
	fissures_changed.emit()


func _interval_cfg(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "calibration_interval/" + key, fallback)


func _schedule(key: String, fallback: float) -> float:
	return DataManager.get_number(DRIFT_TABLE, "audit_schedule/" + key, fallback)


# --- Molt & silk ----------------------------------------------------------------

## Molt only advances while the hygrometer is within MPE (green or amber),
## and, once the FM-3 puts it in service, the terrarium thermometer too
## (Ryan, 2026-11-22: "Like humidity"). Both use the true error, not the display.
func is_molt_paused() -> bool:
	return not molt_pause_causes().is_empty()


## The quantities holding the molt back, in display order: "temperature",
## "relative humidity". Empty while the molt can advance.
func molt_pause_causes() -> PackedStringArray:
	var causes: PackedStringArray = []
	if is_in_service(THERMOMETER_ID) \
			and get_sensor(THERMOMETER_ID).get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE:
		causes.append("temperature")
	if hygrometer.get_band() == DriftingSensor.Band.OUT_OF_TOLERANCE:
		causes.append("humidity")
	return causes


## "temperature and humidity out of range", or "" while the molt can advance.
func molt_pause_reason() -> String:
	var causes: PackedStringArray = molt_pause_causes()
	return "" if causes.is_empty() else " and ".join(causes) + " out of range"


func is_spool_ready() -> bool:
	return molt_stage == MoltStage.MOLTED


## The exuvia shows while molted and for EXUVIA_LINGER_DAYS after the spool is
## taken (it goes at the start of the day after that).
func is_exuvia_visible() -> bool:
	return molt_stage == MoltStage.MOLTED or GameClock.get_day_index() < exuvia_until_day


## One molt's length. The spiders are the farm's, so the best Husbandry of any
## player the farm knows shortens it [ASSUMPTION], on the host and a guest alike.
func molt_days() -> float:
	return PLAYTEST_MOLT_DAYS * best_skill_factor("molt_time")


## "MOLT  40 %", what pauses it, or that the spool is ready.
func molt_text() -> String:
	return _molt_line(molt_progress, molt_stage, molt_pause_reason())


static func _molt_line(progress: float, at: MoltStage, pause_reason: String) -> String:
	if at == MoltStage.MOLTED:
		return "MOLTED: optical silk spool ready"
	var stage: String = "PRE-MOLT" if at == MoltStage.PRE_MOLT else "MOLT"
	return (stage + " PAUSED: " + pause_reason if pause_reason != ""
		else "%s  %s %%" % [stage, SP811.number(progress * 100.0, 0)])


static func _molt_stage_at(progress: float) -> MoltStage:
	if progress >= 1.0:
		return MoltStage.MOLTED
	return MoltStage.PRE_MOLT if progress >= PRE_MOLT_AT else MoltStage.ACTIVE


func _tick_molt(delta_days: float) -> void:
	_tick_enclosures(delta_days)
	if molt_stage == MoltStage.MOLTED or is_molt_paused():
		return
	molt_progress = minf(1.0, molt_progress + delta_days / molt_days())
	molt_stage = _molt_stage_at(molt_progress)
	molt_changed.emit(molt_progress, molt_stage)


## Picks up the spool from a molted enclosure and starts the next molt cycle.
## With `by_robot` a robot does it to that player's program, which trains no
## one's hands: only Robotics XP [ASSUMPTION].
func collect_spool(player_id: String = "", by_robot: bool = false, damaged: bool = false) -> bool:
	if not is_spool_ready():
		return false
	_add_spool(dome_species_id, damaged)
	exuvia_until_day = GameClock.get_day_index() + EXUVIA_LINGER_DAYS
	molt_progress = 0.0
	molt_stage = MoltStage.ACTIVE
	_award_xp("robot_job" if by_robot else "collect_spool", player_id)
	_award_lab_xp("lab_spool", player_id)
	silk_changed.emit(optical_silk_spools)
	molt_changed.emit(molt_progress, molt_stage)
	return true


func _add_spool(species_id: StringName, damaged: bool = false) -> void:
	optical_silk_spools += 1
	_spool_species.append(species_id)
	_spool_damaged.resize(_spool_species.size())
	_spool_damaged[-1] = damaged


func _is_spool_damaged(index: int) -> bool:
	return index < _spool_damaged.size() and _spool_damaged[index]


func damaged_spools() -> int:
	return _spool_damaged.count(true)


## "3", or "3 (1 DAMAGED)".
func spool_count_text() -> String:
	if damaged_spools() == 0:
		return SP811.integer(optical_silk_spools)
	return "%s (%s DAMAGED)" % [SP811.integer(optical_silk_spools), SP811.integer(damaged_spools())]


## Takes a spool out of stock [ASSUMPTION]: a damaged one before a whole one and the
## least lag cut first, or whole and the most. Of those alike, the oldest.
## Returns its species and whether it is damaged.
func _take_spool(damaged_first: bool) -> Array:
	optical_silk_spools -= 1
	if _spool_species.is_empty():
		return [dome_species_id, false]
	var index: int = -1
	for i: int in _spool_species.size():
		if _is_spool_damaged(i) == damaged_first and (index < 0 or _is_taken_before(i, index, damaged_first)):
			index = i
	if index < 0:
		# Spools with no species listed are whole.
		if not damaged_first and _spool_species.size() <= optical_silk_spools:
			return [dome_species_id, false]
		index = 0
		for i: int in _spool_species.size():
			if _is_taken_before(i, index, damaged_first):
				index = i
	var taken: Array = [_spool_species[index], _is_spool_damaged(index)]
	_spool_species.remove_at(index)
	if index < _spool_damaged.size():
		_spool_damaged.remove_at(index)
	return taken


func _is_taken_before(index: int, other: int, least_first: bool) -> bool:
	var cut: float = _species_lag_pct(_spool_species[index])
	var other_cut: float = _species_lag_pct(_spool_species[other])
	return cut < other_cut if least_first else cut > other_cut


# --- Caught tarantulas ----------------------------------------------------------

## The one way a tarantula joins the dome: caught once, and kept for good. Not a
## farm command: only the host's own game decides a catch. False if it can't be caught.
func catch_species(species_id: String) -> bool:
	if FarmCommands.guest or not StringName(species_id) in CATCHABLE or is_caught(species_id):
		return false
	enclosures[species_id] = { "molt_progress": 0.0, "molt_stage": int(MoltStage.ACTIVE), "exuvia_until_day": 0 }
	enclosures_changed.emit()
	return true


## Today's caught strays as { "day", "ids" }, or {} when the record is another day's.
func _strays_today() -> Dictionary:
	if strays_caught.is_empty() or int(strays_caught.get("day", -1)) != GameClock.get_day_index():
		return {}
	return strays_caught.duplicate(true)


## The indices of the service-tunnel strays caught today.
func strays_caught_today() -> Array[int]:
	var out: Array[int] = []
	out.assign(_strays_today().get("ids", []))
	return out


## Host: the player catches one of today's strays in Phobos's service tunnel. `player_id` is
## filled in from the connection (FarmCommands). `stray_index` is the stray's spot
## (PhobosServiceTunnel.stray_indices_for_day) and `layout_day` the day the player's screen drew
## it from, so a screen still on yesterday's strays is refused. Returns "" or why not. The
## player must be away on Phobos (nothing tracks hub versus tunnel, and the tunnel is the only
## part of Phobos with strays [PLACEHOLDER]). One catch per stray per day, and the stray is
## gone for everyone. The first Runner caught goes to a tank of its own in the dome, marked as
## station stock; later catches find the tank already there (one tank a species, as for any
## find), so they are let go on the spot but still count, so every player's Strays quest can
## finish. A catch is counted for who made it (action_counts, STRAY_COUNT, with no XP).
func catch_stray(stray_index: int, layout_day: int, player_id: String = "") -> String:
	if FarmCommands.guest:
		return "Only the host decides a catch."
	var who: String = _player(player_id)
	var day: int = GameClock.get_day_index()
	if place_of(who) != Shuttle.PHOBOS:
		return "Strays are in the Phobos service tunnel."
	if layout_day != day:
		return "That was yesterday's tunnel. Look again."
	if not stray_index in PhobosServiceTunnel.stray_indices_for_day(day):
		return "There is no stray there."
	if stray_index in strays_caught_today():
		return "That one is already caught."
	var ids: Array = _strays_today().get("ids", [])
	ids.append(stray_index)
	strays_caught = { "day": day, "ids": ids }
	if catch_species(String(RUNNER)):
		enclosure_origins[String(RUNNER)] = STATION_ORIGIN
		post_phone("A Banded Regolith Runner. %s. It is kept for the dome." % STATION_LINE)
	if who != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(who, {}) as Dictionary).get_or_add(STRAY_COUNT, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	strays_changed.emit()
	return ""


# --- Deimos smuggler cache (zones.md §2, §5, §10.3) -----------------------------

## Deterministic 32-bit integer mix for Deimos cache rules (no floats, no randf).
static func _deimos_cache_hash(seed_value: int, day: int, tag: int) -> int:
	var h: int = (seed_value ^ (day * 0x9e3779b1) ^ (tag * 0x85ebca6b)) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	return (h ^ (h >> 16)) & 0x7fffffff


## True on days when the Deimos cache's exterior label is wrong [PLACEHOLDER: 1 day in 3].
## Pure function of seed and day, so host, guests and reloads agree.
static func deimos_cache_wrong_label(seed_value: int, day: int) -> bool:
	return _deimos_cache_hash(seed_value, day, DEIMOS_CACHE_LABEL_TAG) % DEIMOS_CACHE_WRONG_LABEL_MOD == 0


## Whether today's (or `day`'s) Deimos cache has a wrong exterior label.
func is_deimos_cache_mislabeled(day: int = -1) -> bool:
	return deimos_cache_wrong_label(world_seed, GameClock.get_day_index() if day < 0 else day)


## Whether `player_id` holds Kestrel's proof for the Deimos smuggler cache.
## Accepting Kestrel's personal quest `a_quiet_crate` grants the proof (reusing
## player_quest_state, done or not, so future days stay open once earned).
func has_kestrel_proof(player_id: String = "") -> bool:
	var who: String = _player(player_id)
	var own: Variant = player_quest_state.get(who, {})
	return own is Dictionary and (own as Dictionary).has(CACHE_QUEST)


## Today's Deimos cache state (pruned to today's opened state while keeping farm-wide
## fallback_paid if set), or {} when unopened today and fallback not yet paid.
func _deimos_cache_today() -> Dictionary:
	var out: Dictionary = {}
	if not deimos_cache.is_empty() and int(deimos_cache.get("day", -1)) == GameClock.get_day_index() and bool(deimos_cache.get("opened", false)):
		out["day"] = int(deimos_cache["day"])
		out["opened"] = true
	if bool(deimos_cache.get("fallback_paid", false)):
		out["fallback_paid"] = true
	return out


## Whether today's Deimos smuggler cache has already been opened by the farm.
func deimos_cache_opened_today() -> bool:
	return bool(_deimos_cache_today().get("opened", false))


## Whether the one-time all-held credit fallback has already been paid for this farm.
func deimos_cache_fallback_paid() -> bool:
	return bool(deimos_cache.get("fallback_paid", false))


## Picks the first unheld species from DEIMOS_CACHE_SPECIES in its listed order,
## keeping the picker and the save check's allowed-id list in lockstep.
## Returns "" when every eligible species is already held.
static func pick_deimos_cache_species(_seed_value: int, held: Dictionary) -> String:
	for species: StringName in DEIMOS_CACHE_SPECIES:
		var id: String = String(species)
		if species in CATCHABLE and not held.has(id):
			return id
	return ""


## Host: the player opens today's Deimos smuggler cache. `player_id` comes from the
## connection (FarmCommands). Must be away on Deimos, must hold Kestrel's proof, and
## today's cache must not be opened yet (one cache a day for the farm [PLACEHOLDER]).
## Grants one unheld Deimos species through catch_species with origin `deimos_cache`,
## or a one-time credit sum [PLACEHOLDER] on the first all-held opening, then a short
## empty-crate line on later all-held openings. Counts `open_cache` per player (no XP).
## Returns "" on species catch, a reply string on fallback/empty, or the refusal reason.
func open_cache(player_id: String = "") -> String:
	if FarmCommands.guest:
		return "Only the host opens a cache."
	var who: String = _player(player_id)
	if place_of(who) != Shuttle.DEIMOS:
		return "The smuggler cache is on Deimos."
	if not has_kestrel_proof(who):
		return DEIMOS_CACHE_LOCKED_LINE
	var day: int = GameClock.get_day_index()
	if deimos_cache_opened_today():
		return "Today's cache is already opened."
	var paid: bool = deimos_cache_fallback_paid()
	deimos_cache = { "day": day, "opened": true }
	if paid:
		deimos_cache["fallback_paid"] = true
	var reply: String = ""
	var species_id: String = pick_deimos_cache_species(world_seed, enclosures)
	if species_id != "" and catch_species(species_id):
		enclosure_origins[species_id] = CACHE_ORIGIN
		var display_name: String = str(DataManager.get_record(SPECIES_TABLE, StringName(species_id)).get("common_name", species_id))
		var prefix: String = "Wrong label on the crate, warm inside. " if is_deimos_cache_mislabeled(day) else ""
		post_phone(prefix + "A %s. %s. It is kept for the dome." % [display_name, CACHE_LINE])
	elif not paid:
		deimos_cache["fallback_paid"] = true
		add_credits(DEIMOS_CACHE_FALLBACK_CREDITS)
		reply = "The warm crate held no new species: every Deimos morph is already in the dome. Found %s CR in smuggled spares." % SP811.integer(DEIMOS_CACHE_FALLBACK_CREDITS)
	else:
		reply = DEIMOS_CACHE_EMPTY_LINE
	if who != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(who, {}) as Dictionary).get_or_add(CACHE_COUNT, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	deimos_cache_changed.emit()
	return reply


func is_caught(species_id: String) -> bool:
	return enclosures.has(species_id)


## The tank's true relative humidity in percent: the species' ideal, off by the
## dome's one hygrometer's error [ASSUMPTION]. NAN while the ideal isn't set.
func enclosure_humidity(species_id: String) -> float:
	return _species_number(species_id, "ideal_humidity_pct") + hygrometer.error


## Each morning, once: is the Cobalt Sentinel out by the sump? Likelier each day it
## isn't met. From the saved generator, so a loaded farm gets the same mornings.
func _roll_sentinel() -> void:
	if FarmCommands.guest or is_caught(SENTINEL):
		return
	sentinel_out = rng.randf() < sentinel_chance()
	sentinel_sighted = false
	sentinel_days_unseen = mini(sentinel_days_unseen + 1, SENTINEL_DAYS_MAX)
	sentinel_changed.emit()


func sentinel_chance() -> float:
	return minf(1.0, SENTINEL_CHANCE * (1 + sentinel_days_unseen))


func set_rover_lights(on: bool, player_id: String = "") -> String:
	if not rover_in_tunnels:
		return "The rover is not in the tunnels."
	if not CoopRovers.driver(TUNNEL_ROVER) in ["", player_id]:
		return "Someone else is driving the rover."
	if _not_with_rover(player_id):
		return "The rover is not where you are."
	if on == rover_lights:
		return ""
	rover_lights = on
	rover_lights_changed.emit()
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)  # honours the told pose
	if at != null:
		watch_sentinel(TUNNEL_ROVER, at, 0.0)
	return ""


## Host: a guest asks from another place or depth than the rover's (the host's own screen is
## its own to check).
func _not_with_rover(player_id: String) -> bool:
	var who: String = _player(player_id)
	return who != local_player_id and (place_of(who) != rover_zone or depth_of(who) != rover_depth)


## Host: a beacon goes down at one of the Lava Tubes spots, for the player in the
## tunnels. `player_id` is filled in from the connection (FarmCommands). Returns ""
## or why not. The player is in the tunnels, Beacon Run is taken and not done, and
## the farm's tunnel rover is within reach of the spot. The host does not check that
## the player took a beacon from the rack [PLACEHOLDER]: that is the player's own
## screen's prompt.
func place_beacon(spot_id: String, player_id: String = "") -> String:
	var reason: String = LavaHub.place_problem(spot_id, beacons_placed, place_of(player_id))
	if reason == "" and (rover_depth != 0 or depth_of(player_id) != 0):
		reason = "Beacons go down in the hub, not below it."
	if reason == "":
		reason = LavaHub.job_problem(quest_state)
	if reason == "":
		var at: Variant = _rover_pose_now(TUNNEL_ROVER)  # honours the told pose and the drive lease
		reason = LavaHub.reach_problem(spot_id, rover_zone, at != null, at if at != null else Vector3.ZERO)
	if reason != "":
		return reason
	beacons_placed.append(spot_id)
	beacons_changed.emit()
	return ""


## Host: a find is taken below the Lava Tubes (ZoneDepth, depth 1), for the player
## there. `player_id` is filled in from the connection (FarmCommands). Returns ""
## or why not. The player is at that depth, the find is one of today's and not
## taken, and the farm's tunnel rover, which is at that depth, is within reach of it.
## `layout_day` is the day the player's screen drew its finds from: after 06:00 a
## screen still on yesterday's layout has an id that is another find today, so a
## day that is not today is refused. It pays into the shared stock [PLACEHOLDER
## amounts].
func take_find(find_id: String, layout_day: int, player_id: String = "") -> String:
	var day: int = GameClock.get_day_index()
	if layout_day != day:
		return "That was yesterday's floor. Look again."
	var zone: String = rover_zone if rover_zone in [AquiferDepth.ZONE, MineDepth.ZONE, IceDepth.ZONE] else ZoneDepth.ZONE
	var aquifer: bool = zone == AquiferDepth.ZONE
	var mine: bool = zone == MineDepth.ZONE
	var ice: bool = zone == IceDepth.ZONE
	finds_taken = ZoneDepth.prune(finds_taken, day)
	pools_drained = ZoneDepth.prune(pools_drained, day)
	valves_shut = ZoneDepth.prune(valves_shut, day)
	packs_wet = AquiferDepth.prune_packs_wet(packs_wet, day)
	rooms_shored = ZoneDepth.prune(rooms_shored, day)
	var today: Dictionary = {}
	if aquifer:
		today = AquiferDepth.layout(world_seed, rover_depth, day, AquiferDepth.drained_today(pools_drained, day), AquiferDepth.shut_today(valves_shut, day))
	elif mine:
		today = MineDepth.layout(world_seed, rover_depth, day, MineDepth.shored_today(rooms_shored, day, rover_depth))
	elif ice:
		today = IceDepth.layout(world_seed, rover_depth, day)
	else:
		today = ZoneDepth.layout(world_seed, ZoneDepth.ZONE, rover_depth, day)
	var taken: Array = ZoneDepth.taken_today(finds_taken, zone, day)
	var reason: String = ""
	if rover_depth < ZoneDepth.DEPTH or rover_depth > ZoneDepth.max_depth_of(zone):
		reason = "The rover is not down there."
	if reason == "" and depth_of(player_id) != rover_depth:
		reason = "Finds lie where the rover is."
	if reason == "" and (zone == ZoneDepth.ZONE or aquifer or mine) and ZoneDepth.is_deep(rover_depth):
		reason = deep_problem(zone)  # the deep floors pay only once the way there is open
	if reason == "":
		reason = ZoneDepth.take_problem(find_id, today.get("finds", []), taken, place_of(player_id), depth_of(player_id), zone)
	if reason == "" and mine:
		reason = MineDepth.blocked_problem(today, find_id)  # a rockfall buries its room until it is shored
	var rover_at: Variant = null
	if reason == "":
		var find: Dictionary = ZoneDepth.find_in(today, find_id)
		rover_at = _rover_pose_now(TUNNEL_ROVER)  # honours the told pose and the drive lease
		reason = ZoneDepth.reach_problem(TunnelRock.at_in(today["grid"], find["cell"]), rover_zone, rover_at != null, rover_at if rover_at != null else Vector3.ZERO, zone)
		if reason == "" and aquifer:
			# Deep water is in the way as it is for the rover: a find past it waits for the pump.
			reason = AquiferDepth.water_problem(today["grid"], AquiferDepth.cell_in(today["grid"], rover_at), find["cell"])
		if reason == "" and aquifer:
			reason = AquiferDepth.seal_problem(today, find_id)
	if reason != "":
		return reason
	var taken_find: Dictionary = ZoneDepth.find_in(today, find_id)
	var kind: String = str(taken_find["kind"])
	var pay: Dictionary = AquiferDepth.reward(kind, rover_depth) if aquifer else (MineDepth.reward(kind, rover_depth) if mine else (IceDepth.reward(kind) if ice else ZoneDepth.reward(kind, rover_depth)))
	finds_taken = ZoneDepth.with_taken(finds_taken, zone, day, find_id)
	if pay.has("crystal_ore"):
		crystal_ore += int(pay["crystal_ore"])
		ore_changed.emit(crystal_ore)
	if pay.has("credits"):
		add_credits(int(pay["credits"]))
	var reply: String = ""
	if mine and kind == MineDepth.CASE:
		var who_case: String = _player(player_id)
		var next_cell: Variant = MineDepth.next_block_cell(world_seed, found_blocks)
		if not (next_cell is Vector2i and _find_block_at(next_cell, who_case)):
			add_credits(MineDepth.CASE_FALLBACK_CREDITS)
			reply = MineDepth.case_fallback_reply()
		if who_case != MANAGER_ID:
			var opened: Dictionary = (action_counts.get_or_add(who_case, {}) as Dictionary).get_or_add(CASE_COUNT, { "count": 0, "xp": 0 })
			opened["count"] = int(opened["count"]) + 1
	if aquifer:
		var find_cell: Vector2i = taken_find["cell"]
		var rover_cell: Vector2i = AquiferDepth.cell_in(today["grid"], rover_at)
		if AquiferDepth.wades_to(today, today.get("start", ZoneDepth.START_CELL), find_cell) \
				or AquiferDepth.wades_to(today, rover_cell, find_cell):
			var who: String = _player(player_id)
			if int(packs_wet.get(who, -1)) != day:
				packs_wet[who] = day
				var spoiled: bool = camp_supplies > 0
				if spoiled:
					camp_supplies = maxi(camp_supplies - AquiferDepth.RATIONS_SPOILED, 0)
					camps_changed.emit()
				reply = AquiferDepth.wet_pack_reply(spoiled)
	finds_changed.emit()
	return reply


## Host: Bram's key quest (or a test) opens the Colony Mine's gate for the farm. Only the
## host's farm does; opening it twice changes nothing. Returns "" or why not.
func open_mine_gate() -> String:
	if FarmCommands.guest:
		return "Only the host's farm opens the Mine's gate."
	if not mine_gate_open:
		mine_gate_open = true
		mine_changed.emit()
	return ""


## Host: the player buys a heater cartridge at the Ice Caves hub's crate: IceDepth.HEATER_COST_CREDITS
## from the farm's wallet [PLACEHOLDER], charged once, and their cold starts again from now.
## Returns "" or why not (IceDepth.heater_problem).
func buy_heater(player_id: String = "") -> String:
	var who: String = _player(player_id)
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var near: bool = rover_zone == IceDepth.ZONE and rover_depth == 0 and at != null and IceDepth.near_crate(at)
	var here: String = place_of(who) if rover_zone == IceDepth.ZONE else ""
	var reason: String = IceDepth.heater_problem(here, depth_of(who), credits, near, cold_of(who))
	if reason != "":
		return reason
	add_credits(-IceDepth.HEATER_COST_CREDITS)
	cold_since[who] = GameClock.elapsed_days
	ice_changed.emit()
	return ""


## Host: the farm buys shoring props at the Mine hub's crate, for the player there. Props
## cost crystal ore from the shared stock [PLACEHOLDER], as a lift repair does. Returns ""
## or why not (MineDepth.buy_problem).
func buy_mine_props(player_id: String = "") -> String:
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var near: bool = rover_zone == MineDepth.ZONE and rover_depth == 0 and at != null and MineDepth.near_crate(at)
	var here: String = place_of(player_id) if rover_zone == MineDepth.ZONE else ""
	var reason: String = MineDepth.buy_problem(here, depth_of(player_id), crystal_ore, near, mine_props)
	if reason != "":
		return reason
	crystal_ore -= MineDepth.PROP_COST_ORE
	ore_changed.emit(crystal_ore)
	mine_props += MineDepth.PROPS_PER_BUY
	mine_changed.emit()
	return ""


## Host: the rover shores `rockfall_id` for today, spending a prop, for the player at
## depth. Returns "" or why not (the deep gate at depths 4 to 6, then MineDepth.shore_problem). `layout_day` is the day the
## player's screen drew the rockfalls for.
func shore_room(rockfall_id: String, layout_day: int, player_id: String = "") -> String:
	var day: int = GameClock.get_day_index()
	if layout_day != day:
		return "That was yesterday's floor. Look again."
	if rover_zone != MineDepth.ZONE or rover_depth < 1 or depth_of(player_id) != rover_depth or place_of(player_id) != MineDepth.ZONE:
		return "Rockfalls are below the Colony Mine's hub, where the rover is."
	if ZoneDepth.is_deep(rover_depth):  # the deep floors work only once the way there is open
		var shut_reason: String = mine_deep_problem()
		if shut_reason != "":
			return shut_reason
	rooms_shored = ZoneDepth.prune(rooms_shored, day)
	var shored: Array = MineDepth.shored_today(rooms_shored, day, rover_depth)
	var today: Dictionary = MineDepth.layout(world_seed, rover_depth, day, shored)
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var reason: String = MineDepth.shore_problem(today, rockfall_id, shored, mine_props, at if at != null else Vector3(1.0e6, 0.0, 1.0e6))
	if reason != "":
		return reason
	mine_props -= MineDepth.PROPS_PER_ROOM
	rooms_shored = ZoneDepth.with_taken(rooms_shored, MineDepth.ZONE, day, MineDepth.storage_id(rover_depth, rockfall_id))
	var who: String = _player(player_id)
	if who != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(who, {}) as Dictionary).get_or_add(SHORE_COUNT, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	mine_changed.emit()
	return ""


## Host: the farm buys the Flooded Aquifer's pump at the hub's crate, for the player
## there (`player_id` is filled in by FarmCommands). Returns "" or why not (AquiferDepth.
## buy_problem). One pump for the whole farm, paid once from the shared wallet.
func buy_pump(player_id: String = "") -> String:
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var near: bool = rover_zone == AquiferDepth.ZONE and rover_depth == 0 and at != null and AquiferDepth.near_crate(at)
	var here: String = place_of(player_id) if rover_zone == AquiferDepth.ZONE else ""
	var reason: String = AquiferDepth.buy_problem(here, depth_of(player_id), pump_owned, credits, near)
	if reason != "":
		return reason
	add_credits(-AquiferDepth.PUMP_COST_CREDITS)
	pump_owned = true
	pump_changed.emit()
	return ""


## Host: the pump drains `pool_id` for today, for the player at depth 1. Returns "" or
## why not (AquiferDepth.pump_problem). `layout_day` is the day the player's screen drew
## the pools for.
func use_pump(pool_id: String, layout_day: int, player_id: String = "") -> String:
	var day: int = GameClock.get_day_index()
	if layout_day != day:
		return "That was yesterday's floor. Look again."
	if rover_zone != AquiferDepth.ZONE or rover_depth < 1 or depth_of(player_id) != rover_depth or place_of(player_id) != AquiferDepth.ZONE:
		return "Pools are below the Flooded Aquifer's hub, where the rover is."
	if ZoneDepth.is_deep(rover_depth):  # the deep floors work only once the way there is open
		var shut_reason: String = aquifer_deep_problem()
		if shut_reason != "":
			return shut_reason
	pools_drained = ZoneDepth.prune(pools_drained, day)
	valves_shut = ZoneDepth.prune(valves_shut, day)
	var today: Dictionary = AquiferDepth.layout(world_seed, rover_depth, day, AquiferDepth.drained_today(pools_drained, day), AquiferDepth.shut_today(valves_shut, day))
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var reason: String = AquiferDepth.pump_problem(today, pool_id, AquiferDepth.drained_today(pools_drained, day), pump_owned, at if at != null else Vector3(1.0e6, 0.0, 1.0e6))
	if reason != "":
		return reason
	pools_drained = ZoneDepth.with_taken(pools_drained, AquiferDepth.ZONE, day, AquiferDepth.storage_id(rover_depth, pool_id))
	pump_changed.emit()
	return ""


## Host: shuts `seal_id`'s valve for today, for the player at depth 1 of the Aquifer. Costs
## nothing; returns "" or why not (AquiferDepth.valve_problem). `layout_day` is the day the
## player's screen drew the seal for.
func shut_valve(seal_id: String, layout_day: int, player_id: String = "") -> String:
	if FarmCommands.guest:
		return "Only the host shuts a valve."
	var who: String = _player(player_id)
	var day: int = GameClock.get_day_index()
	if layout_day != day:
		return "That was yesterday's floor. Look again."
	if rover_zone != AquiferDepth.ZONE or rover_depth < 1 or depth_of(who) != rover_depth or place_of(who) != AquiferDepth.ZONE:
		return "Valves are below the Flooded Aquifer's hub, where the rover is."
	if ZoneDepth.is_deep(rover_depth):  # the deep floors work only once the way there is open
		var shut_reason: String = aquifer_deep_problem()
		if shut_reason != "":
			return shut_reason
	valves_shut = ZoneDepth.prune(valves_shut, day)
	var shut: Array = AquiferDepth.shut_today(valves_shut, day)
	var today: Dictionary = AquiferDepth.layout(world_seed, rover_depth, day, AquiferDepth.drained_today(pools_drained, day), shut)
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)
	var reason: String = AquiferDepth.valve_problem(today, seal_id, shut, at if at != null else Vector3(1.0e6, 0.0, 1.0e6))
	if reason != "":
		return reason
	valves_shut = ZoneDepth.with_taken(valves_shut, AquiferDepth.ZONE, day, AquiferDepth.storage_id(rover_depth, seal_id))
	pump_changed.emit()
	return ""


## Host: the rover is in a vent's cell (Lava Tubes, depth 1), for the player there.
## `player_id` is filled in from the connection (FarmCommands). Returns "" or why not.
## The host decides from its own state: the player is at that depth, the vent is one
## of today's and is hot at the HOST's clock (a guest's clock can differ by a few game
## minutes: a cool vent is refused, a harmless miss), and the host's copy of the tunnel
## rover is within reach of it. If it is, zone_heat_trip is set for the trip (once: a
## second blast in the same trip says nothing more) and the phone says so. The 20 game
## minutes of docs/design/zones.md section 5 are not built (follow-up): advancing the
## shared clock mid-trip meets the 02:00 recall and the other players' clocks.
func enter_vent(vent_id: String, layout_day: int, player_id: String = "") -> String:
	var day: int = GameClock.get_day_index()
	if layout_day != day:
		return "That was yesterday's floor. Look again."
	var vents: Array = ZoneHazards.vents_for(world_seed, ZoneDepth.ZONE, ZoneDepth.DEPTH, day)
	var reason: String = ZoneHazards.entry_problem(vent_id, vents, GameClock.elapsed_days, place_of(player_id), depth_of(player_id), rover_depth)
	if reason == "":
		var today: Dictionary = ZoneDepth.layout(world_seed, ZoneDepth.ZONE, ZoneDepth.DEPTH, day)
		var vent: Dictionary = ZoneHazards.vent_in(vents, vent_id)
		var at: Variant = _rover_pose_now(TUNNEL_ROVER)  # honours the told pose and the drive lease
		reason = ZoneHazards.reach_problem(TunnelRock.at_in(today["grid"], vent["cell"]), rover_zone, at != null, at if at != null else Vector3.ZERO)
	if reason != "":
		return reason
	if not zone_heat_trip:
		zone_heat_trip = true
		post_phone(ZoneHazards.WORDS["struck"])
	return ""


## The rover's place and speed, from whoever drives it. Lit, fast or on top of it,
## it scares the Sentinel.
func watch_sentinel(rover_id: String, at: Vector3, speed_mps: float) -> void:
	if FarmCommands.guest or not sentinel_out or rover_id != TUNNEL_ROVER or rover_zone != TUNNELS_ZONE or rover_depth != 0:
		return  # the Sentinel is in the hub; below, its coordinates mean nothing
	var away: float = at.distance_to(SENTINEL_AT)
	if away > SENTINEL_SEES_M:
		return
	if not sentinel_sighted:
		# Once per sighting, before it can bolt, so the rules come first.
		sentinel_sighted = true
		post_phone(SENTINEL_HINT)
	if rover_lights:
		_scare_sentinel("The rover's lights were on.")
	elif absf(speed_mps) > SENTINEL_CALM_MPS:
		_scare_sentinel("The rover came too fast.")
	elif away < SENTINEL_CROWDED_M:
		_scare_sentinel("The rover came too close.")


func _scare_sentinel(why: String, extra: String = "") -> void:
	sentinel_out = false
	sentinel_sighted = false
	sentinel_days_unseen = 0
	sentinel_changed.emit()
	post_phone("SENTINEL: %s It bolted, and hides until another day.%s" % [why, " " + extra if extra != "" else ""])


## True if the cup reaches it from the rover's place.
func sentinel_in_reach(at: Vector3) -> bool:
	return sentinel_out and at.distance_to(SENTINEL_AT) <= SENTINEL_REACH_M


## Closes the cup with its relative humidity at `reading_pct` as the hygrometer
## shows it. What the air really is decides. Returns "" or why nothing was tried.
func catch_sentinel(reading_pct: float, player_id: String = "") -> String:
	if not is_finite(reading_pct) or reading_pct < 0.0 or reading_pct > 100.0:
		return "The cup can't hold that."
	if not rover_in_tunnels:
		return "The rover is not in the tunnels."
	if not CoopRovers.driver(TUNNEL_ROVER) in ["", player_id]:
		return "Someone else is driving the rover."
	if _not_with_rover(player_id) or rover_depth != 0:
		return "Nothing is in the cup's reach."
	var at: Variant = _rover_pose_now(TUNNEL_ROVER)  # honours the told pose: no save of this screen's rover over it
	if at != null:
		watch_sentinel(TUNNEL_ROVER, at, 0.0)
	if is_caught(SENTINEL) or at == null or not sentinel_in_reach(at as Vector3):
		return "Nothing is in the cup's reach."
	var off: float = reading_pct - hygrometer.error - _species_number(SENTINEL, "ideal_humidity_pct")
	if absf(off) <= CUP_TOLERANCE_PCT:
		sentinel_out = false
		sentinel_sighted = false
		catch_species(SENTINEL)
		sentinel_changed.emit()
		post_phone("SENTINEL: caught. It goes to its tank in the dome.")
	else:
		# The display was in the band: say where the fault is.
		var hint: String = ""
		if absf(reading_pct - _species_number(SENTINEL, "ideal_humidity_pct")) <= CUP_TOLERANCE_PCT:
			hint = "The hygrometer read %s %%. Was it right?" % SP811.number(reading_pct, 0)
		_scare_sentinel("The cup was too %s." % ("damp" if off > 0.0 else "dry"), hint)
	return ""


## enclosure_humidity() as the hygrometer shows it.
func enclosure_humidity_reading(species_id: String) -> float:
	return _species_number(species_id, "ideal_humidity_pct") + hygrometer.observed_error


## What holds this tank's molt back, or "". The true values must be within the species'
## own tolerance, temperature too once the thermometer is in service [ASSUMPTION]. A
## value the data leaves unset holds it. Held back it only gives no silk: it never dies.
func enclosure_pause_reason(species_id: String) -> String:
	var causes: PackedStringArray = []
	if is_in_service(THERMOMETER_ID):
		if is_nan(_species_number(species_id, "ideal_temp_c")):
			return "temperature not set"
		if not _tolerates(species_id, "temp_tolerance_c", get_sensor(THERMOMETER_ID).error):
			causes.append("temperature")
	if is_nan(enclosure_humidity(species_id)):
		return "humidity not set"
	if not _tolerates(species_id, "humidity_tolerance_pct", hygrometer.error):
		causes.append("humidity")
	return "" if causes.is_empty() else " and ".join(causes) + " out of range"


## False too if the tolerance isn't set.
func _tolerates(species_id: String, field: String, error: float) -> bool:
	return absf(error) <= _species_number(species_id, field)


## A number in the species' record, or NAN if it isn't set there.
func _species_number(species_id: String, field: String) -> float:
	var raw: Variant = DataManager.get_record(SPECIES_TABLE, StringName(species_id)).get(field)
	return float(raw) if raw is float or raw is int else NAN


func is_enclosure_spool_ready(species_id: String) -> bool:
	return is_caught(species_id) and not StringName(species_id) in NO_DOME_TANK and enclosures[species_id]["molt_stage"] == MoltStage.MOLTED


func is_enclosure_exuvia_visible(species_id: String) -> bool:
	return is_enclosure_spool_ready(species_id) or (is_caught(species_id)
		and GameClock.get_day_index() < enclosures[species_id]["exuvia_until_day"])


## As molt_text(), or "" before the catch.
func enclosure_text(species_id: String) -> String:
	if not is_caught(species_id):
		return ""
	var line: String = _molt_line(enclosures[species_id]["molt_progress"], enclosures[species_id]["molt_stage"],
		enclosure_pause_reason(species_id))
	# One plain line says where it came from (no full stop: the caller ends the sentence).
	var origin: String = str(enclosure_origins.get(species_id, ""))
	if origin == STATION_ORIGIN:
		return line + ". " + STATION_LINE
	if origin == CACHE_ORIGIN:
		return line + ". " + CACHE_LINE
	return line


func _tick_enclosures(delta_days: float) -> void:
	for id: String in enclosures:
		var tank: Dictionary = enclosures[id]
		if StringName(id) in NO_DOME_TANK or tank["molt_stage"] == MoltStage.MOLTED or enclosure_pause_reason(id) != "":
			continue
		tank["molt_progress"] = minf(1.0, tank["molt_progress"] + delta_days / molt_days())
		tank["molt_stage"] = int(_molt_stage_at(tank["molt_progress"]))
		enclosures_changed.emit()


## collect_spool() for a caught tarantula's tank.
func collect_enclosure_spool(species_id: String, player_id: String = "") -> bool:
	if not is_enclosure_spool_ready(species_id):
		return false
	_add_spool(StringName(species_id))
	enclosures[species_id] = { "molt_progress": 0.0, "molt_stage": int(MoltStage.ACTIVE),
		"exuvia_until_day": GameClock.get_day_index() + EXUVIA_LINGER_DAYS }
	_award_xp("collect_spool", player_id)
	_award_lab_xp("lab_spool", player_id)
	silk_changed.emit(optical_silk_spools)
	enclosures_changed.emit()
	return true


# --- Relay ----------------------------------------------------------------------

## A whole spool may take the place of a damaged one, which is thrown away, or of a
## whole one that cuts the lag less, which goes back into stock [ASSUMPTION].
func can_slot_spool() -> bool:
	if not relay_slotted:
		return optical_silk_spools > 0
	if slotted_spool_damaged:
		return optical_silk_spools > damaged_spools()
	for i: int in _spool_species.size():
		if not _is_spool_damaged(i) and _species_lag_pct(_spool_species[i]) > _species_lag_pct(slotted_spool_species):
			return true
	return false


## `score` is Thread the Spool's (MinigameScore.SKIPPED with no game). It is
## read in one place: the seat's own XP and the lab's XP for it are times
## MinigameScore.xp_factor(score), which is 1.0 for a skip and a poor try. Which
## spool is taken, the lag and the relay do not see it.
func slot_spool_into_relay(player_id: String = "", score: int = MinigameScore.SKIPPED) -> bool:
	if not can_slot_spool():
		return false
	var taken: Array = _take_spool(false)
	if relay_slotted and not slotted_spool_damaged:
		_add_spool(slotted_spool_species)
	slotted_spool_species = taken[0]
	slotted_spool_damaged = taken[1]
	relay_slotted = true
	var xp_scale: float = MinigameScore.xp_factor(score)
	_award_xp("slot_spool", player_id, xp_scale)
	_award_lab_xp("lab_spool", player_id, xp_scale)
	silk_changed.emit(optical_silk_spools)
	relay_changed.emit(relay_slotted)
	return true


## Multiplier applied to rover uplink lag (1.0 = no upgrade). The spool's base
## cut and the spinning species' lag_reduction_pct stack multiplicatively:
## (1 - spool%) * (1 - species%). Curlyhair: 0.40 * 0.95 = 0.38. A damaged spool
## gives only part of the base cut.
func get_relay_lag_multiplier() -> float:
	if not relay_slotted:
		return 1.0
	var spool_pct: float = DataManager.get_number(ITEMS_TABLE, "optical_silk_spool/relay_lag_reduction_pct", 0.0)
	if slotted_spool_damaged:
		spool_pct *= DataManager.get_number(ITEMS_TABLE, "optical_silk_spool/damaged_reduction_share", 1.0)
	var species_pct: float = _species_lag_pct(slotted_spool_species)
	return clampf((1.0 - spool_pct / 100.0) * (1.0 - species_pct / 100.0), 0.0, 1.0)


## The species' own cut. One not set (an undesigned morph) cuts nothing.
func _species_lag_pct(species_id: StringName) -> float:
	var pct: float = _species_number(species_id, "lag_reduction_pct")
	return 0.0 if is_nan(pct) else pct


func get_dome_species() -> Dictionary:
	return DataManager.get_record(SPECIES_TABLE, dome_species_id)


# --- Credibility and contracts (Ryan, 2026-11-22) -------------------------------

func _cred_number(key: String, fallback: float) -> float:
	return DataManager.get_number(ECONOMY_TABLE, "credibility/" + key, fallback)


func _cred_bands() -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	var raw: Variant = DataManager.get_value(ECONOMY_TABLE, "credibility/bands", [])
	if typeof(raw) == TYPE_ARRAY:
		for band: Variant in raw:
			if typeof(band) == TYPE_DICTIONARY:
				bands.append(band)
	if bands.is_empty():
		bands.append({ "name": "Provisional", "min_points": 0 })
	return bands


## Starting credibility, with no contract.
func reset_credibility() -> void:
	credibility = int(_cred_number("start_points", 10.0))
	_best_band = credibility_band_index()
	contract_state = ""
	contract_run = 0
	job_board.clear()
	active_jobs.clear()
	_board_day = -1
	_board_band = -1
	_board_taken.clear()


func credibility_band_index(points: int = -1) -> int:
	if points < 0:
		points = credibility
	var bands: Array[Dictionary] = _cred_bands()
	var index: int = 0
	for i: int in bands.size():
		if points >= int(bands[i].get("min_points", 0)):
			index = i
	return index


func credibility_band() -> String:
	return str(_cred_bands()[credibility_band_index()].get("name", ""))


## "TRUSTED, 40 % to ACCREDITED", or just the band at the top.
func credibility_text() -> String:
	var bands: Array[Dictionary] = _cred_bands()
	var index: int = credibility_band_index()
	var text: String = str(bands[index].get("name", "")).to_upper()
	if index + 1 < bands.size():
		var low: int = int(bands[index].get("min_points", 0))
		var high: int = int(bands[index + 1].get("min_points", 0))
		var pct: int = clampi(floori(100.0 * (credibility - low) / maxf(high - low, 1.0)), 0, 99)
		text += ", %d %% to %s" % [pct, str(bands[index + 1].get("name", "")).to_upper()]
	return text


## Moves credibility by `points` (kept between 0 and the maximum), announces a
## new best band, and offers the first contract once its band is reached.
func change_credibility(points: int) -> void:
	if points == 0:
		return
	credibility = clampi(credibility + points, 0, int(_cred_number("max_points", 100.0)))
	credibility_changed.emit(credibility)
	var index: int = credibility_band_index()
	if index > _best_band:
		_best_band = index
		post_phone("OIRM: Lab credibility raised to %s." % credibility_band().to_upper())
	# A band change (up or down) changes the jobs on offer now, not next
	# morning; the morning builds its board after the audit.
	if index != _board_band and not _morning and _board_day >= 0:
		refresh_job_board(GameClock.get_day_index())
	if contract_state == "" and index >= _contract_offer_band_index():
		_offer_first_contract()


func _credibility_after_audit(report: Dictionary) -> void:
	if report.get("warning", false):
		change_credibility(int(_cred_number("warning_audit_points", -5.0)))
	elif report["passed"]:
		change_credibility(int(_cred_number("clean_audit_points", 10.0)))
	else:
		change_credibility(int(_cred_number("failed_audit_points", -10.0)))


## Each morning, every instrument on the colony that is overdue costs a
## little: units in service and standards here (not at OIRM), except units
## excused because their standard was away when they fell due.
func _charge_overdue_credibility(day: int) -> void:
	var count: int = 0
	for id: String in unit_ids() + standard_ids():
		if at_oirm.has(id) or _excused_until_audit(id, day):
			continue
		if (sensors[id] as DriftingSensor).is_overdue(day):
			count += 1
	change_credibility(count * int(_cred_number("overdue_points_per_instrument_day", -1.0)))


## True while a unit that fell due with its standard away at OIRM is still
## within the grace Vance gives at audit (_excused_units): until the latest
## deadline any audit would grant it, so the daily charge starts only after
## the audit that would fail it.
func _excused_until_audit(unit_id: String, day: int) -> bool:
	var sensor: DriftingSensor = sensors[unit_id]
	if sensor.role != "unit":
		return false
	var due: int = sensor.cal_due_day
	var cadence: int = maxi(int(_schedule("cadence_days", 5.0)), 1)
	for i: int in oirm_trips.size():
		var trip: Dictionary = oirm_trips[i]
		if trip["standard_id"] != sensor.calibrated_by:
			continue
		if int(trip["sent_day"]) >= due:
			continue
		if _trip_is_open(i):
			return true  # still away, so Vance still excuses it
		var back: int = int(trip["return_day"])
		if due >= back:
			continue
		# Every audit after it fell due that excuses it, as _excused_units does.
		var deadline: int = -1
		var audit: int = next_audit_day(due)
		while audit <= maxi(due + cadence, back):
			deadline = maxi(deadline, next_audit_day(maxi(audit, back)))
			audit += cadence
		if day <= deadline:
			return true
	return false


## Using an overdue standard costs more. The contract counts a run of on-time,
## traceable calibrations by the player; a late or untraceable one restarts it.
## The manager's one-time favor counts for nothing either way.
func _credibility_after_calibration(record: Dictionary) -> void:
	if record.get("performed_by", "") == MANAGER_ID:
		return
	if record.get("standard_overdue", false):
		change_credibility(int(_cred_number("overdue_standard_used_points", -5.0)))
	if is_commissioning(record["instrument_id"]):
		return  # not the colony's unit until its robot is released
	if contract_state != "active":
		return
	if record.get("programmed_by", "") != "":
		return  # a robot's work neither counts nor breaks the player's run
	if get_sensor(record["instrument_id"]).role == "standard":
		return  # the run counts the colony's units
	var needed: int = contract_run_needed()
	var good: bool = record.get("on_time", false) and record.get("traceable", false)
	# A repeat before the unit has run half its interval since its last
	# traceable calibration neither counts nor breaks the run. (Unlike
	# interval_evidence, an untraceable adjustment in between doesn't block it.)
	var interval: int = int(record.get("previous_interval_days", 0))
	if good and int(record.get("days_in_service", 0)) < ceili(interval / 2.0):
		return
	if good:
		contract_run += 1
		if contract_run >= needed:
			contract_state = "complete"
			var standard: String = contract_standard_id()
			post_phone("OIRM CONTRACT complete: %d on-time calibrations in a row. Bram can sell you the %s for %s (%d %% off)." % [
				needed, instrument_name(standard), standard_price_text(standard, MANAGER_ID), contract_discount_pct()])
			upgrades_changed.emit()
		else:
			post_phone("OIRM CONTRACT: %d of %d on-time calibrations in a row." % [contract_run, needed])
		credibility_changed.emit(credibility)
	elif contract_run > 0:
		contract_run = 0
		post_phone("OIRM CONTRACT: run restarted (%s). 0 of %d." % [
			"late calibration" if not record.get("on_time", false) else "not traceable", needed])
		credibility_changed.emit(credibility)


## The phone's contract row with the deepest depth reached under it (a line of its own
## once the rover has been below, ZoneDepth.deepest_text).
func contract_phone_text() -> String:
	var deepest: String = ZoneDepth.deepest_lines(deepest_depth)
	var contract: String = contract_text()
	return contract if deepest == "" else (deepest if contract == "" else contract + "
" + deepest)


## The open contract objective for the phone, "" when there is none.
func contract_text() -> String:
	match contract_state:
		"active":
			var standard: String = contract_standard_id()
			return "OIRM CONTRACT: %d of %d in a row, on time, traceable\nA unit counts again once half its interval has passed\nReward: %s for %s" % [
				contract_run, contract_run_needed(),
				_model_name(standard), _contract_price_text(standard)]
		"complete":
			return "OIRM CONTRACT DONE: %s at Bram's" % _model_name(contract_standard_id())
	return ""


## The model part of a short name, e.g. "HB-700" from "HB-700 pressure controller".
func _model_name(instrument_id: String) -> String:
	return get_sensor(instrument_id).short_name.get_slice(" ", 0)


## The contract price, e.g. "800 CR + 4 crystal ore", even before it is earned.
func _contract_price_text(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	return "%s CR + %d crystal ore" % [SP811.integer(_discounted(sensor.price_credits)), sensor.price_ore]


func contract_standard_id() -> String:
	return str(DataManager.get_value(ECONOMY_TABLE, "credibility/first_contract/standard_id", ""))


func contract_run_needed() -> int:
	return maxi(int(_cred_number("first_contract/on_time_calibrations", 5.0)), 1)


func contract_discount_pct() -> int:
	return clampi(int(_cred_number("first_contract/discount_pct", 50.0)), 0, 100)


func _contract_offer_band_index() -> int:
	return _band_index_named(str(DataManager.get_value(ECONOMY_TABLE, "credibility/first_contract/offer_band", "")))


## Index of the band called `band_name`; past the last band if unknown.
func _band_index_named(band_name: String) -> int:
	var bands: Array[Dictionary] = _cred_bands()
	for i: int in bands.size():
		if str(bands[i].get("name", "")) == band_name:
			return i
	return bands.size()


func _offer_first_contract() -> void:
	var standard: String = contract_standard_id()
	var sensor: DriftingSensor = get_sensor(standard)
	if sensor == null or owned_standards.has(standard):
		return
	contract_state = "active"
	contract_run = 0
	credibility_changed.emit(credibility)
	# Short of the row's lab level, it is the provisional way through (section
	# 3.2.1): offered all the same, and its quest pays lab XP toward the level.
	var provisional: bool = not lab_gate_open("first_contract")
	post_phone("OIRM CONTRACT offered%s: make %d calibrations in a row on time and traceable, and Bram will sell you the %s for %s CR + %d crystal ore (%d %% off)%s. Calibrating a unit again before it has run half its interval doesn't count." % [
		" (provisional: OIRM asks for lab level %s and the lab is level %s, so finishing it also lifts the lab level)" % [
			SP811.integer(lab_gate_level("first_contract")), SP811.integer(lab_level())] if provisional else "",
		contract_run_needed(), instrument_name(standard), SP811.integer(_discounted(sensor.price_credits)),
		sensor.price_ore, contract_discount_pct(),
		" once Tier %d is open to the lab" % sensor.tier if tier_problem(standard) != "" else ""])


# --- Paid calibration jobs (Ryan, 2026-11-22) -------------------------------------

func _jobs_number(key: String, fallback: float) -> float:
	return DataManager.get_number(ECONOMY_TABLE, "jobs/" + key, fallback)


## Discipline -> ids of the standards that can do its jobs.
func job_disciplines() -> Dictionary:
	var raw: Variant = DataManager.get_value(ECONOMY_TABLE, "jobs/disciplines", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _job_templates() -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	var raw: Variant = DataManager.get_value(ECONOMY_TABLE, "jobs/templates", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry: Variant in raw:
			if typeof(entry) == TYPE_DICTIONARY:
				templates.append(entry)
	return templates


## The lowest band any job opens at, e.g. "Trusted".
func jobs_open_band() -> String:
	var lowest: int = _cred_bands().size()
	for template: Dictionary in _job_templates():
		lowest = mini(lowest, _band_index_named(str(template.get("min_band", ""))))
	return str(_cred_bands()[lowest].get("name", "")) if lowest < _cred_bands().size() else ""


## Owned standards that can do `job` (its discipline, at its tier or better),
## best first: those that give a traceable result, then the higher tier.
func job_standards(job: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var listed: Variant = job_disciplines().get(str(job.get("discipline", "")), [])
	if typeof(listed) != TYPE_ARRAY:
		return ids
	for raw_id: Variant in listed:
		var id: String = str(raw_id)
		var sensor: DriftingSensor = get_sensor(id)
		if sensor != null and owned_standards.has(id) and sensor.tier >= int(job.get("min_tier", 0)):
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var a_good: bool = standard_problem(a) == ""
		if a_good != (standard_problem(b) == ""):
			return a_good
		return get_sensor(a).tier > get_sensor(b).tier)
	return ids


## The lab-level gate a job of this band waits for: the board's, or the one for
## the band of the row accredited_jobs and above.
func job_gate_id(band_name: String) -> String:
	return "accredited_jobs" if _band_index_named(band_name) >= _gated_jobs_band_index() else "job_board"


## The band whose jobs wait for the row accredited_jobs ("band" in lab_gates).
## Past every band if the row names none.
func _gated_jobs_band_index() -> int:
	return _band_index_named(str(DataManager.get_record(SKILLS_TABLE, &"accredited_jobs", "lab_gates").get("band", "")))


## Why `job` can't be accepted now, or "".
func job_accept_problem(job: Dictionary) -> String:
	var band_name: String = str(job.get("min_band", ""))
	if _band_index_named(band_name) > credibility_band_index():
		return "Needs %s credibility." % band_name.to_upper()
	var gate: String = lab_gate_problem("job_board", "The job board")
	if gate == "":
		gate = lab_gate_problem(job_gate_id(band_name), "%s jobs" % band_name)
	if gate != "":
		return gate
	var area_problem: String = job_area_problem(job)
	if area_problem != "":
		return area_problem
	if job_standards(job).is_empty():
		var tier: int = int(job.get("min_tier", 0))
		return "Needs your own %s standard%s." % [job.get("discipline", "?"),
			" (Tier %s or better)" % SP811.integer(tier) if tier > 0 else ""]
	var standard: String = job_bench_standard(job)
	if standard == "":
		return job_bench_problem(job)
	# The customer wants a traceable result: the standard must be in date now.
	var chain: Dictionary = traceability_chain(standard)
	if not chain.get("traceable", false):
		return "Needs a traceable %s standard: %s." % [job.get("discipline", "?"), chain.get("text", "?")]
	return ""


## Takes offer `index` off the board. Returns "" or why it can't be taken.
func accept_job(index: int) -> String:
	if index < 0 or index >= job_board.size():
		return "That job is gone."
	var offer: Dictionary = job_board[index]
	var problem: String = job_accept_problem(offer)
	if problem != "":
		return problem
	job_board.remove_at(index)
	_board_taken.append(str(offer.get("id", "")))
	var today: int = GameClock.get_day_index()
	var job: Dictionary = offer.duplicate(true)
	job["job_id"] = "JOB-%04d" % _next_job_number
	_next_job_number += 1
	job["accepted_day"] = today
	job["due_day"] = today + maxi(int(offer.get("due_in_days", 2)), 0)
	active_jobs.append(job)
	post_phone("%s accepted: %s for %s. Calibrate it at the bench by day %s with a traceable standard for %s CR." % [
		job["job_id"], job.get("item", "?"), job.get("customer", "?"),
		SP811.integer(job["due_day"]), SP811.integer(int(job.get("pay", 0)))])
	jobs_changed.emit()
	return ""


func active_job(job_id: String) -> Dictionary:
	for job: Dictionary in active_jobs:
		if job["job_id"] == job_id:
			return job
	return {}


# --- A job handed out by a quest (quests_levels_story.md section 6, S3) -----------

## The mark on a job a quest handed out: the quest's id, on the job in
## active_jobs and on its row in job_log. A board job has none. Such a job is
## never on the board: the board is filled from data/economy.json's templates
## only, and this job comes from the quest (data/quests.json, `job`).
const QUEST_JOB: String = "quest"


## The accepted job `quest_id` handed out, or {}.
func quest_job(quest_id: String) -> Dictionary:
	for job: Dictionary in active_jobs:
		if quest_id != "" and str(job.get(QUEST_JOB, "")) == quest_id:
			return job
	return {}


## True once `quest_id` has handed out its job: it is in active_jobs, or it was
## done and has its row in job_log.
func has_quest_job(quest_id: String) -> bool:
	if quest_id == "":
		return false
	if not quest_job(quest_id).is_empty():
		return true
	for row: Dictionary in job_log:
		if str(row.get(QUEST_JOB, "")) == quest_id:
			return true
	return false


## Host, from the quests' look (QuestEngine): puts the job of `quest_id` in
## active_jobs, as accept_job does a board offer, unless this quest's job is
## there already or was done. Returns the job, or {} when none was handed out.
## Nothing is asked of the lab first (job_accept_problem): the envelope is under
## the airlock whether or not the lab can do it yet, and the bench says what is
## missing. It says nothing on the phone; the caller does (quest_job_text).
func issue_quest_job(quest_id: String, template: Dictionary) -> Dictionary:
	if quest_id == "" or has_quest_job(quest_id):
		return {}
	var today: int = GameClock.get_day_index()
	var job: Dictionary = template.duplicate(true)
	job[QUEST_JOB] = quest_id
	job["job_id"] = "JOB-%04d" % _next_job_number
	_next_job_number += 1
	job["accepted_day"] = today
	job["due_day"] = today + maxi(int(template.get("due_in_days", 2)), 0)
	active_jobs.append(job)
	jobs_changed.emit()
	return job


## "JOB-0004 is yours, not the board's: a gauge for Chet's customer. Calibrate
## it at the bench by day 9 with a traceable standard for 200 CR."
func quest_job_text(job: Dictionary) -> String:
	return "%s is yours, not the board's: %s for %s. Calibrate it at the bench by day %s with a traceable standard for %s CR." % [
		job.get("job_id", "?"), job.get("item", "?"), job.get("customer", "?"),
		SP811.integer(int(job.get("due_day", 0))), SP811.integer(int(job.get("pay", 0)))]


## The standard complete_job would use for `job` today: the best one not at
## OIRM, or "" if there is none.
func job_bench_standard(job: Dictionary) -> String:
	for id: String in job_standards(job):
		if not at_oirm.has(id):
			return id
	return ""


## Why `job` can't be done at the bench now, or "".
func job_bench_problem(job: Dictionary, player_id: String = "") -> String:
	if job_bench_standard(job) != "":
		var cutoff: int = int(job.get("due_day", 0)) + maxi(int(_jobs_number("late_grace_days", 3.0)), 0)
		if job_finish_day(job, player_id) > cutoff:
			return "Not enough time: %s cancels at 06:00 on day %s." % [job.get("customer", "?"), SP811.integer(cutoff + 1)]
		return ""
	var owned: Array[String] = job_standards(job)
	if owned.is_empty():
		return "You no longer own a standard for this job."
	return "The %s is at OIRM until day %s." % [instrument_name(owned[0], true), SP811.integer(int(at_oirm[owned[0]]))]


## Bench time of `job` for this player, after their Calibration skill.
func job_minutes(job: Dictionary, player_id: String = "") -> float:
	return float(job.get("bench_minutes", 0.0)) * skill_factor("bench_time", player_id)


## The day the bench work on `job` would end if the player started now.
func job_finish_day(job: Dictionary, player_id: String = "") -> int:
	return floori(GameClock.elapsed_days + job_minutes(job, player_id) / 1440.0) + 1


## Calibrates the customer's item at the bench against the best standard for
## the job. The bench time passes first; the job is late if the work ends
## after due_day, and not traceable if the standard was overdue when the work
## began. Each cuts the pay and costs credibility; a clean, on-time job earns
## a little. Returns { ok, reason } on failure, else the result written to
## job_log.
func complete_job(job_id: String, player_id: String = "") -> Dictionary:
	var job: Dictionary = active_job(job_id)
	if job.is_empty():
		return { "ok": false, "reason": "No such job." }
	var problem: String = job_bench_problem(job, player_id)
	if problem != "":
		return { "ok": false, "reason": problem }
	var standard_id: String = job_bench_standard(job)
	var fault: String = standard_problem(standard_id)
	var traceable: bool = fault == ""
	# The work takes its time. The job stays active, marked at the bench, so a
	# morning during it neither cancels it nor offers it again.
	var minutes: float = job_minutes(job, player_id)
	if GameClock.waits_within(minutes / 1440.0):
		return { "ok": false, "reason": NO_TIME_TONIGHT }
	job["at_bench"] = true
	if minutes > 0.0:
		GameClock.advance(minutes / 1440.0)
	active_jobs.erase(job)
	# Taken today: a promotion from this payout must not offer it again. A
	# quest's job was never the board's to offer.
	if str(job.get(QUEST_JOB, "")) == "":
		_board_taken.append(str(job.get("id", "")))
	var today: int = GameClock.get_day_index()
	var on_time: bool = today <= int(job["due_day"])
	var offered: int = int(job.get("pay", 0))
	var pay: float = float(offered)
	var points: int = 0
	# A job that says flat_cut_pct (a quest's) is cut once by that much for late,
	# untraceable or both, in place of the board's two cuts.
	var flat: bool = job.has("flat_cut_pct")
	if flat and not (on_time and traceable):
		pay *= (100.0 - clampf(float(job["flat_cut_pct"]), 0.0, 100.0)) / 100.0
	if not on_time:
		if not flat:
			pay *= (100.0 - clampf(_jobs_number("late_pay_cut_pct", 50.0), 0.0, 100.0)) / 100.0
		points += int(_jobs_number("late_job_points", -3.0))
	if not traceable:
		if not flat:
			pay *= (100.0 - clampf(_jobs_number("untraceable_pay_cut_pct", 75.0), 0.0, 100.0)) / 100.0
		points += int(_jobs_number("untraceable_job_points", -5.0))
	if on_time and traceable:
		points = int(_jobs_number("clean_job_points", 2.0))
	var result: Dictionary = {
		"ok": true,
		"job_id": job_id,
		"customer": job.get("customer", ""),
		"item": job.get("item", ""),
		"standard_id": standard_id,
		"day": today,
		"on_time": on_time,
		"traceable": traceable,
		"standard_problem": fault,
		"offered": offered,
		"pay": roundi(pay),
		"points": points,
		"bench_minutes": minutes,
	}
	# A quest's job says so on its row, and only such a row has the key.
	if str(job.get(QUEST_JOB, "")) != "":
		result[QUEST_JOB] = str(job[QUEST_JOB])
	job_log.append(result)
	add_credits(result["pay"])
	_xp_after_job(result, player_id)
	# Report the change the score actually made (it stops at 0 and the maximum).
	var before: int = credibility
	change_credibility(points)
	result["points"] = credibility - before
	post_phone(job_result_text(result))
	jobs_changed.emit()
	return result


## "JOB-0003 done for Lin: 100 CR, on time and traceable, credibility +2."
func job_result_text(result: Dictionary) -> String:
	var problems: PackedStringArray = []
	if not result["on_time"]:
		problems.append("LATE")
	if not result["traceable"]:
		problems.append("NOT TRACEABLE (%s %s)" % [_model_name(result["standard_id"]), result.get("standard_problem", "overdue")])
	var points: int = result["points"]
	return "%s done for %s: %s CR%s, credibility %s%s." % [
		result["job_id"], result["customer"], SP811.integer(result["pay"]),
		", on time and traceable" if problems.is_empty()
			else " of %s, %s" % [SP811.integer(result["offered"]), " and ".join(problems)],
		"+" if points > 0 else "", SP811.integer(points)]


## Each morning: jobs left past their grace days are cancelled and cost
## credibility.
func _expire_jobs(day: int) -> void:
	var grace: int = maxi(int(_jobs_number("late_grace_days", 3.0)), 0)
	for job: Dictionary in active_jobs.duplicate():
		if not job.get("at_bench", false) and day > int(job["due_day"]) + grace:
			active_jobs.erase(job)
			# A quest's job costs nothing when it runs out: the quest hands it out
			# again at its next look, this same morning. Said now, so the line is
			# before the one that brings it back: _morning_notes are posted after
			# that look, which would put "ran out" after the new job's line.
			if str(job.get(QUEST_JOB, "")) != "":
				post_phone("%s ran out: %s went back to %s." % [job["job_id"], job.get("item", "?"), job.get("customer", "?")])
				jobs_changed.emit()
				continue
			change_credibility(int(_jobs_number("abandoned_job_points", -5.0)))
			var note: String = "%s cancelled: %s took %s elsewhere." % [job["job_id"], job.get("customer", "?"), job.get("item", "?")]
			if _morning:
				_morning_notes.append(note)
			else:
				post_phone(note)
			jobs_changed.emit()


## Rows of lab_gates that each add one job to the board's base size, in order.
const BOARD_SLOT_GATES: Array[String] = ["board_4_jobs", "board_5_jobs"]
const BOARD_SLOT_WORDS: Array[String] = ["A fourth job", "A fifth job"]


## True if this extra-slot row is in the table, built, and open (a kept row counts).
func _board_slot_open(gate_id: String) -> bool:
	var row: Dictionary = DataManager.get_record(SKILLS_TABLE, StringName(gate_id), "lab_gates")
	return not row.is_empty() and row.get("built", true) and lab_gate_open(gate_id)


## How many jobs a board holds: economy `board_size`, plus one for each open
## extra-slot row (4th job at lab level 28, 5th at 65 [PLACEHOLDER]). Taken at
## the board refresh, so a slot that opens mid-day shows at the next one.
func job_board_size() -> int:
	var size: int = maxi(int(_jobs_number("board_size", 3.0)), 0)
	for gate: String in BOARD_SLOT_GATES:
		if _board_slot_open(gate):
			size += 1
	return size


## When the next slot opens, in the board note's words: "A fourth job at lab
## level 28." "" when the board is shut or every slot is open.
func job_board_slot_note() -> String:
	var open_band: String = jobs_open_band()
	if open_band == "" or credibility_band_index() < _band_index_named(open_band) or not lab_gate_open("job_board"):
		return ""
	for i: int in BOARD_SLOT_GATES.size():
		var row: Dictionary = DataManager.get_record(SKILLS_TABLE, StringName(BOARD_SLOT_GATES[i]), "lab_gates")
		if row.is_empty() or not row.get("built", true) or lab_gate_open(BOARD_SLOT_GATES[i]):
			continue
		return "%s at lab level %s." % [BOARD_SLOT_WORDS[i], SP811.integer(lab_gate_level(BOARD_SLOT_GATES[i]))]
	return ""


## Replaces today's offers with jobs the lab's band allows, rotating through
## them by day, skipping any already accepted.
func refresh_job_board(day: int) -> void:
	job_board.clear()
	if day != _board_day:
		_board_day = day
		_board_taken.clear()
	var band: int = credibility_band_index()
	_board_band = band
	var eligible: Array[Dictionary] = []
	for template: Dictionary in _job_templates():
		var min_band: String = str(template.get("min_band", ""))
		if _band_index_named(min_band) > band or not lab_gate_open("job_board") or not lab_gate_open(job_gate_id(min_band)):
			continue
		var taken: bool = str(template.get("id", "")) in _board_taken
		for job: Dictionary in active_jobs:
			taken = taken or job.get("id", "") == template.get("id", "")
		if not taken:
			eligible.append(template)
	var count: int = mini(job_board_size(), eligible.size())
	if count > 0:
		var start: int = posmod(day * count, eligible.size())
		for i: int in count:
			job_board.append(eligible[(start + i) % eligible.size()].duplicate(true))
		post_phone("JOB BOARD: %s new calibration jobs from the domes and rover crews. Accept one on the phone." % SP811.integer(count))
	jobs_changed.emit()


## "Rover crew Kestrel: a tire pressure gauge (pressure), 150 CR, 2 days"
func job_offer_text(job: Dictionary) -> String:
	return "%s: %s (%s), %s CR, %s days" % [job.get("customer", "?"), job.get("item", "?"),
		job.get("discipline", "?"), SP811.integer(int(job.get("pay", 0))), SP811.integer(int(job.get("due_in_days", 0)))]


## "JOB-0003 Lin: a soil probe, due day 7, 100 CR"
func active_job_text(job: Dictionary) -> String:
	var late: bool = GameClock.get_day_index() > int(job["due_day"])
	return "%s %s: %s, %s day %s, %s CR" % [job["job_id"], job.get("customer", "?"), job.get("item", "?"),
		"LATE since" if late else "due", SP811.integer(int(job["due_day"]) + (1 if late else 0)),
		SP811.integer(int(job.get("pay", 0)))]


## One line when the board shows no offers.
func job_board_note() -> String:
	var open_band: String = jobs_open_band()
	if open_band == "":
		return ""
	if credibility_band_index() < _band_index_named(open_band):
		return "JOB BOARD opens at %s." % open_band.to_upper()
	if not lab_gate_open("job_board"):
		return "JOB BOARD %s." % lab_gate_problem("job_board").trim_suffix(".").to_lower()
	return "JOB BOARD: no new jobs today."


# --- Upgradeable lab (Ryan, 2026-11-22) --------------------------------------

func _lab_number(key: String, fallback: float) -> float:
	return DataManager.get_number(ECONOMY_TABLE, "lab/" + key, fallback)


func _lab_list(key: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var raw: Variant = DataManager.get_value(ECONOMY_TABLE, "lab/" + key, [])
	if typeof(raw) == TYPE_ARRAY:
		for entry: Variant in raw:
			if typeof(entry) == TYPE_DICTIONARY:
				list.append(entry)
	return list


## Lab sizes, smallest first.
func lab_sizes() -> Array[Dictionary]:
	return _lab_list("sizes")


## The record of size `index` (the lab's own size by default).
func lab_size_record(index: int = -1) -> Dictionary:
	var sizes: Array[Dictionary] = lab_sizes()
	if sizes.is_empty():
		return {}
	return sizes[clampi(lab_size if index < 0 else index, 0, sizes.size() - 1)]


func lab_size_name(index: int = -1) -> String:
	return str(lab_size_record(index).get("name", "Lab"))


## The next size up, or {} at the largest.
func lab_next_size() -> Dictionary:
	var sizes: Array[Dictionary] = lab_sizes()
	return sizes[lab_size + 1] if lab_size + 1 < sizes.size() else {}


## Spaces the lab has at its size.
func lab_spaces() -> int:
	return maxi(int(lab_size_record().get("areas", 0)), 0)


## Spaces given to disciplines, plus one being cleared.
func lab_used_spaces() -> int:
	var used: int = 0
	for discipline: Variant in lab_areas:
		used += int(lab_areas[discipline])
	if lab_build.get("kind", "") == "refit":
		used += 1
	return used


func lab_free_spaces() -> int:
	return maxi(lab_spaces() - lab_used_spaces(), 0)


## Spaces given to `discipline`: its area, and how many of its jobs fit at once.
func lab_space(discipline: String) -> int:
	return int(lab_areas.get(discipline, 0))


## The biggest area size ("small", "medium", "large") `spaces` reach, or "".
func lab_area_size(spaces: int) -> String:
	var best: String = ""
	var best_need: int = 0
	for entry: Dictionary in _lab_list("area_sizes"):
		var need: int = int(entry.get("spaces", 0))
		if spaces >= need and need >= best_need:
			best = str(entry.get("id", ""))
			best_need = need
	return best


## Spaces an area of size `size_id` needs (1 if it isn't listed).
func lab_area_spaces_needed(size_id: String) -> int:
	for entry: Dictionary in _lab_list("area_sizes"):
		if str(entry.get("id", "")) == size_id:
			return maxi(int(entry.get("spaces", 1)), 1)
	return 1


## The most spaces one area may have at the lab's size: the lab's largest
## area size reaches up to just below the next area size. Growing the lab is
## what opens the bigger areas, so clearing other areas can't skip a size.
func lab_max_area_spaces(index: int = -1) -> int:
	var record: Dictionary = lab_size_record(index)
	var largest: String = str(record.get("largest_area", ""))
	var limit: int = maxi(int(record.get("areas", 0)), 0)
	if largest == "":
		return limit
	var need: int = lab_area_spaces_needed(largest)
	for entry: Dictionary in _lab_list("area_sizes"):
		var spaces: int = int(entry.get("spaces", 0))
		if spaces > need:
			limit = mini(limit, spaces - 1)
	return maxi(limit, 1)


## ", in the large lab" when the lab is too small for an area of `need`
## spaces, naming the smallest lab size that holds one; else "".
func _lab_size_for_area_text(need: int) -> String:
	if lab_max_area_spaces() >= need:
		return ""
	for i: int in lab_sizes().size():
		if lab_max_area_spaces(i) >= need:
			return ", in the %s" % lab_size_name(i).to_lower()
	return ""


## The most spaces any one job of `discipline` in progress needs its area to keep.
func _lab_spaces_in_use(discipline: String) -> int:
	var keep: int = 0
	for job: Dictionary in active_jobs:
		if str(job.get("discipline", "")) != discipline or str(job.get(QUEST_JOB, "")) != "":
			continue
		var size_id: String = str(job.get("area", ""))
		keep = maxi(keep, lab_area_spaces_needed(size_id) if size_id != "" else 1)
	return keep


## Accepted board jobs of `discipline` (at the bench or waiting): the jobs that
## hold a space of its area. A quest's job holds none. It is handed out without
## asking the lab for room and complete_job asks for none, so it must not fill
## an area or keep one from being cleared while it cannot be done yet.
func jobs_in_progress(discipline: String) -> int:
	var count: int = 0
	for job: Dictionary in active_jobs:
		if str(job.get("discipline", "")) == discipline and str(job.get(QUEST_JOB, "")) == "":
			count += 1
	return count


## Why the lab has no room for `job` now, or "".
func job_area_problem(job: Dictionary) -> String:
	var discipline: String = str(job.get("discipline", ""))
	var spaces: int = lab_space(discipline)
	var size_id: String = str(job.get("area", ""))
	var need: int = lab_area_spaces_needed(size_id) if size_id != "" else 1
	if spaces <= 0 and need <= 1:
		return "Needs a %s area in the lab: plan one at the dome plan board." % discipline
	if spaces < need:
		return "Needs a %s %s area (%s spaces%s); yours has %s." % [size_id.to_upper(), discipline,
			SP811.integer(need), _lab_size_for_area_text(need), SP811.integer(spaces)]
	var busy: int = jobs_in_progress(discipline)
	if busy >= spaces:
		return "Your %s area is full: %s job%s in progress." % [discipline, SP811.integer(busy), "" if busy == 1 else "s"]
	return ""


## "600 CR + 4 crystal ore"
func lab_cost_text(cost_credits: int, cost_ore: int) -> String:
	var text: String = "%s CR" % SP811.integer(cost_credits)
	if cost_ore > 0:
		text += " + %s crystal ore" % SP811.integer(cost_ore)
	return text


func _lab_afford_problem(cost_credits: int, cost_ore: int) -> String:
	if credits < cost_credits or crystal_ore < cost_ore:
		return "Costs %s; you have %s CR and %s crystal ore." % [lab_cost_text(cost_credits, cost_ore),
			SP811.integer(credits), SP811.integer(crystal_ore)]
	return ""


func _lab_pay(cost_credits: int, cost_ore: int) -> void:
	add_credits(-cost_credits)
	crystal_ore -= cost_ore
	ore_changed.emit(crystal_ore)


## The build under way, e.g. "The medium lab is being built: ready the
## morning of day 9.", or "".
func lab_build_text() -> String:
	if lab_build.is_empty():
		return ""
	var ready_day: String = SP811.integer(int(lab_build.get("done_day", 0)))
	if lab_build.get("kind", "") == "grow":
		return "The %s is being built: ready the morning of day %s." % [
			lab_size_name(int(lab_build.get("size", 0))).to_lower(), ready_day]
	return "A %s space is being cleared: free the morning of day %s." % [lab_build.get("discipline", "?"), ready_day]


## Why the lab can't grow to the next size now, or "".
func lab_grow_problem() -> String:
	if not lab_build.is_empty():
		return lab_build_text()
	var next: Dictionary = lab_next_size()
	if next.is_empty():
		return "The lab is already at its largest."
	var gate: String = lab_gate_problem(lab_size_gate_id(next), "The %s" % str(next.get("name", "next size")).to_lower())
	if gate != "":
		return gate
	return _lab_afford_problem(int(next.get("credits", 0)), int(next.get("ore", 0)))


## The lab-level gate of a lab size: "medium_lab" for the size "medium".
func lab_size_gate_id(size: Dictionary) -> String:
	return "%s_lab" % size.get("id", "")


## Pays for the next size and starts building it. The new spaces are ready
## the morning build_days later; the lab's areas keep working meanwhile.
## Returns "" or why it can't start.
func start_lab_grow() -> String:
	var problem: String = lab_grow_problem()
	if problem != "":
		return problem
	var next: Dictionary = lab_next_size()
	_lab_pay(int(next.get("credits", 0)), int(next.get("ore", 0)))
	var days: int = maxi(int(next.get("build_days", 1)), 1)
	lab_build = { "kind": "grow", "size": lab_size + 1, "done_day": GameClock.get_day_index() + days }
	post_phone("LAB: %s Your areas keep working meanwhile." % lab_build_text())
	lab_changed.emit()
	return ""


## Why a free space can't be fitted out for `discipline` now, or "".
func lab_fit_problem(discipline: String) -> String:
	if not job_disciplines().has(discipline):
		return "No jobs come in for %s." % discipline
	if lab_free_spaces() <= 0:
		return "No free space: grow the lab or clear a space first."
	var limit: int = lab_max_area_spaces()
	if lab_space(discipline) >= limit:
		return "The %s holds areas of up to %s space%s: grow the lab for a bigger %s area." % [
			lab_size_name().to_lower(), SP811.integer(limit), "" if limit == 1 else "s", discipline]
	return ""


## Gives a free space to `discipline` (free of charge). Returns "" or why not.
func fit_lab_area(discipline: String, player_id: String = "") -> String:
	var problem: String = lab_fit_problem(discipline)
	if problem != "":
		return problem
	_sync_lab_layout()
	lab_areas[discipline] = lab_space(discipline) + 1
	_sync_lab_layout()
	var spaces: int = lab_space(discipline)
	var plural: String = "" if spaces == 1 else "s"
	post_phone("LAB: the %s area has %s space%s (%s): up to %s job%s at once." % [discipline,
		SP811.integer(spaces), plural, lab_area_size(spaces).to_upper(), SP811.integer(spaces), plural])
	if spaces > int(lab_areas_paid.get(discipline, 0)):
		# Only a space this area never had: clearing and fitting again gives none.
		lab_areas_paid[discipline] = spaces
		_award_lab_xp("lab_area", player_id)
	lab_changed.emit()
	return ""


## The refit's credits and ore from the lab numbers, before any one-use token.
func _lab_refit_base_cost() -> Vector2i:
	return Vector2i(maxi(int(_lab_number("refit_credits", 0.0)), 0), maxi(int(_lab_number("refit_ore", 0.0)), 0))


## True when the farm holds a free refit and the refit would cost something.
func _lab_refit_is_free() -> bool:
	return one_use_count(ONE_USE_REFIT) > 0 and _lab_refit_base_cost() != Vector2i.ZERO


## Nothing while the farm holds a free refit (one_use_held) to use up.
func _lab_refit_cost() -> Vector2i:
	return Vector2i.ZERO if _lab_refit_is_free() else _lab_refit_base_cost()


func _lab_refit_days() -> int:
	return maxi(int(_lab_number("refit_days", 1.0)), 1)


## "200 CR + 1 crystal ore, 1 day"
func lab_refit_text() -> String:
	var cost: Vector2i = _lab_refit_cost()
	var days: int = _lab_refit_days()
	return "%s, %s day%s%s" % [lab_cost_text(cost.x, cost.y), SP811.integer(days), "" if days == 1 else "s",
		" (one-use free refit)" if _lab_refit_is_free() else ""]


## Why a space of `discipline` can't be cleared now, or "".
func lab_clear_problem(discipline: String) -> String:
	if not lab_build.is_empty():
		return lab_build_text()
	var spaces: int = lab_space(discipline)
	if spaces <= 0:
		return "The lab has no %s area." % discipline
	if jobs_in_progress(discipline) >= spaces:
		return "Every %s space has a job in progress: finish one first." % discipline
	if _lab_spaces_in_use(discipline) >= spaces:
		return "A %s job in progress needs this area at its size: finish it first." % discipline
	var cost: Vector2i = _lab_refit_cost()
	return _lab_afford_problem(cost.x, cost.y)


## Takes one space from `discipline` to fit out for another later. It costs
## refit credits and ore and is down for refit_days. Returns "" or why not.
func clear_lab_area(discipline: String) -> String:
	var problem: String = lab_clear_problem(discipline)
	if problem != "":
		return problem
	var cost: Vector2i = _lab_refit_cost()
	var free: bool = _lab_refit_is_free()
	_lab_pay(cost.x, cost.y)
	if free and _spend_one_use(ONE_USE_REFIT):
		post_phone(QuestEngine.one_use_used_line(ONE_USE_REFIT))
	_sync_lab_layout()
	var at: int = lab_layout.rfind(discipline)
	if at >= 0:
		lab_layout[at] = LAB_REFIT_SLOT
	if lab_space(discipline) <= 1:
		lab_areas.erase(discipline)
	else:
		lab_areas[discipline] = lab_space(discipline) - 1
	lab_build = { "kind": "refit", "discipline": discipline, "done_day": GameClock.get_day_index() + _lab_refit_days() }
	post_phone("LAB: %s" % lab_build_text())
	lab_changed.emit()
	return ""


## Each morning: a build that is due finishes.
func _finish_lab_build(day: int) -> void:
	if lab_build.is_empty() or day < int(lab_build.get("done_day", 0)):
		return
	var build: Dictionary = lab_build
	lab_build = {}
	if build.get("kind", "") == "grow":
		lab_size = clampi(int(build.get("size", 0)), 0, maxi(lab_sizes().size() - 1, 0))
		var free_spaces: int = lab_free_spaces()
		post_phone("LAB: the %s is ready. %s free space%s to fit out at the dome plan board." % [
			lab_size_name().to_lower(), SP811.integer(free_spaces), "" if free_spaces == 1 else "s"])
		_award_lab_xp("lab_grown", "", 1.0, false)
	else:
		post_phone("LAB: the %s space is cleared. Fit it out at the dome plan board." % build.get("discipline", "?"))
	_sync_lab_layout()
	lab_changed.emit()


## The lab starts small, with a space for each discipline the founding
## standards cover (Agent's proposal, flagged for Ryan: nothing is taken away).
func reset_lab() -> void:
	lab_size = 0
	lab_build = {}
	lab_areas = {}
	lab_layout = []
	var disciplines: Dictionary = job_disciplines()
	for discipline: Variant in disciplines:
		var listed: Variant = disciplines[discipline]
		if typeof(listed) != TYPE_ARRAY:
			continue
		for id: Variant in listed:
			if owned_standards.has(str(id)):
				lab_areas[str(discipline)] = 1
				break
	lab_areas_paid = lab_areas.duplicate()
	_sync_lab_layout()
	lab_changed.emit()


## The lab's spaces in wall order (see lab_layout), kept in step with
## lab_areas: each space keeps its place, a cleared space frees where it
## stood, and a new space goes beside its area if it can.
func lab_layout_slots() -> Array[String]:
	# Looking changes nothing: in co-op only the host changes the farm.
	var kept: Array[String] = lab_layout
	lab_layout = lab_layout.duplicate()
	_sync_lab_layout()
	var slots: Array[String] = lab_layout
	lab_layout = kept
	return slots


func _sync_lab_layout() -> void:
	var spaces: int = lab_spaces()
	if lab_layout.size() > spaces:
		lab_layout.resize(spaces)
	while lab_layout.size() < spaces:
		lab_layout.append("")
	var refitting: bool = lab_build.get("kind", "") == "refit"
	var have_refit: bool = false
	var counts: Dictionary = {}
	for i: int in lab_layout.size():
		var slot: String = lab_layout[i]
		if slot == LAB_REFIT_SLOT:
			if refitting and not have_refit:
				have_refit = true
			else:
				lab_layout[i] = ""
		elif slot != "":
			var have: int = int(counts.get(slot, 0))
			if have >= lab_space(slot):
				lab_layout[i] = ""
			else:
				counts[slot] = have + 1
	if refitting and not have_refit:
		var spot: int = lab_layout.find("")
		if spot >= 0:
			lab_layout[spot] = LAB_REFIT_SLOT
	for discipline: Variant in job_disciplines():
		var area_id: String = str(discipline)
		for i: int in maxi(lab_space(area_id) - int(counts.get(area_id, 0)), 0):
			var spot: int = _lab_free_slot_beside(area_id)
			if spot < 0:
				break
			lab_layout[spot] = area_id


## A free slot next to `discipline`'s area, else the first free slot, or −1.
func _lab_free_slot_beside(discipline: String) -> int:
	for i: int in lab_layout.size():
		if lab_layout[i] != "":
			continue
		if (i > 0 and lab_layout[i - 1] == discipline) or (i + 1 < lab_layout.size() and lab_layout[i + 1] == discipline):
			return i
	return lab_layout.find("")


# --- Crops and Lin (income milestone) ----------------------------------------

## Crop ids in data order.
func crop_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: StringName in DataManager.get_ids(CROPS_TABLE):
		ids.append(str(id))
	return ids


func crop(crop_id: String) -> Dictionary:
	return DataManager.get_record(CROPS_TABLE, StringName(crop_id))


func current_seed() -> String:
	var ids: Array[String] = crop_ids()
	if ids.is_empty():
		return ""
	return seed_crop_id if ids.has(seed_crop_id) else ids[0]


## Switches the next planting to the following crop; returns its id.
func cycle_seed() -> String:
	var ids: Array[String] = crop_ids()
	if ids.is_empty():
		return ""
	seed_crop_id = ids[(ids.find(current_seed()) + 1) % ids.size()]
	return seed_crop_id


func seed_cost(crop_id: String) -> int:
	var pct: float = DataManager.get_number(ECONOMY_TABLE, "crops/seed_cost_pct", 0.0)
	return roundi(float(crop(crop_id).get("base_sell_credits", 0)) * pct / 100.0)


func crop_name(crop_id: String) -> String:
	return str(crop(crop_id).get("name", crop_id))


## The soil plot, in cells. FarmGrid draws it.
const PLOT: Rect2i = Rect2i(-6, -6, 12, 12)


## How many cells of the plot are still to till.
func untilled_cells() -> int:
	var tilled: int = 0
	for cell: Variant in tilled_cells:
		if cell is Vector3i and cell.y == 0 and PLOT.has_point(Vector2i(cell.x, cell.z)):
			tilled += 1
	return PLOT.get_area() - tilled


## Records a cell as tilled, so it stays tilled across scene swaps. Returns
## false if it already was, or is off the plot.
func till(cell: Vector3i, player_id: String = "") -> bool:
	if tilled_cells.has(cell) or cell.y != 0 or not PLOT.has_point(Vector2i(cell.x, cell.z)):
		return false
	tilled_cells[cell] = true
	_award_xp("till", player_id)
	soil_tilled.emit(cell)
	return true


## Whether an ore pocket not yet dug lies at this cell.
func is_live_pocket(at: Vector2i) -> bool:
	return not found_pockets.has(at) and (at in OrePocket.cells(world_seed) or at in new_pockets)


## Digs a cell of Terrain (y = 0) one step deeper. Returns "" or why not. It costs
## nothing [ASSUMPTION]. A block or an ore pocket there comes up once. The digger
## gets Earthworks XP for a step deeper than the cell has been, and for a block.
func dig(cell: Vector3i, player_id: String = "") -> String:
	var at := Vector2i(cell.x, cell.z)
	var problem: String = dig_problem(at) if cell.y == 0 else "This ground can't be dug."
	if problem == "":
		dug[at] = dug.get(at, 0) + 1
		if dug[at] > dug_paid.get(at, 0):
			dug_paid[at] = dug[at]
			_award_xp("dig", player_id)
		_set_seep(PitWater.seep(pit_seep, dug, 0.0), true)
		# The digging may have changed where the water ends, so look at it next step.
		_seep_full = false
		terrain_changed.emit()
		_find_block_at(at, player_id)
		if not found_pockets.has(at) and (at in OrePocket.cells(world_seed) or at in new_pockets):
			found_pockets[at] = true
			pocket_pending[at] = GameClock.get_day_index() + OrePocket.REGROW_DAYS
			crystal_ore += OrePocket.ORE
			pockets_changed.emit()
			ore_changed.emit(crystal_ore)
	return problem


## Records the buried reference block at `at` as found by `player_id` when one lies
## there and is not yet in `found_blocks`. Shared by digging and the Mine's cases.
func _find_block_at(at: Vector2i, player_id: String = "") -> bool:
	if found_blocks.has(at) or ReferenceBlock.at(world_seed, at).is_empty():
		return false
	found_blocks[at] = true
	_award_xp("find_block", player_id)
	blocks_changed.emit()
	return true


const STONE_IN_THE_WAY: String = "Stone is built here. Take it up first."


## Why a cell can't be dug one step deeper now, or "". The one rule: dig() answers
## with it and the dig outline lights the cell by it, so the outline is teal exactly
## when the dig would work.
## `cached` (the outline, every frame) reuses the beside-the-pad answer, which
## copies the dug cells, until the ground, the stone or the pockets change.
func dig_problem(at: Vector2i, cached: bool = false) -> String:
	if stone_pieces.has(at):
		return STONE_IN_THE_WAY
	var pocket: bool = not found_pockets.has(at) and (at in OrePocket.cells(world_seed) or at in new_pockets)
	var problem: String = Terrain.dig_problem(at, dug, pocket)
	if problem != "":
		return problem
	if not cached:
		return StonePieces.dig_beside_pad_problem(at, dug)
	if not _pad_problems.has(at):
		_pad_problems[at] = StonePieces.dig_beside_pad_problem(at, dug)
	return _pad_problems[at]


var _pad_problems: Dictionary[Vector2i, String] = {}


func _forget_pad_problems() -> void:
	_pad_problems.clear()


## Builds a piece of `kind` (StonePieces) on a cell of Terrain (y = 0), or with
## TAKE_UP takes up the one there for all its stone back. Returns "" or why not. The host works out where the rovers stand.
@warning_ignore("unused_parameter")
func place_stone(cell: Vector3i, kind: int, player_id: String = "") -> String:
	var at := Vector2i(cell.x, cell.z)
	if cell.y != 0:
		return "Nothing can be built here."
	if kind == StonePieces.TAKE_UP:
		if not stone_pieces.has(at):
			return "Nothing is built here."
		stone = mini(stone + StonePieces.cost(stone_pieces[at]), StonePieces.MAX_STONE)
		stone_pieces.erase(at)
		_level_pads(true)
		stone_changed.emit()
		return ""
	SaveGame.saving.emit()  # rovers say where they are
	var rovers: Array[Transform3D] = []
	for id: String in rover_transforms:
		if id != TUNNEL_ROVER and not rover_is_away(id):  # a field rover's place is not here
			rovers.append(rover_transforms[id])
	var walkers: Array[Vector2] = []
	if not rover_lent:
		for pose: Array in CoopWalkers.out.values():
			walkers.append(Vector2(pose[0], pose[2]))
	var problem: String = StonePieces.problem(at, kind, stone_pieces, rovers, dug, walkers)
	if problem != "":
		return problem
	if stone < StonePieces.cost(kind):
		return "Needs %d stone; carrying %d." % [StonePieces.cost(kind), stone]
	stone -= StonePieces.cost(kind)
	stone_pieces[at] = kind
	_level_pads(kind == StonePieces.PAD)
	stone_changed.emit()
	return ""


## Levels the ground under the pads (Terrain.use_pads), in the autoload only: the
## ground is one for the whole game, a copy of a farm made for a check leaves it
## alone. `host` is true when this farm built or took up a pad: if the ground then
## changed, whoever is standing on it is lifted, the pit water works itself out
## again and everything is told. A guest is told by FarmSync.
func _level_pads(host: bool = false) -> void:
	if not is_inside_tree():
		return
	var before: Dictionary[Vector2i, float] = Terrain.level_points
	Terrain.use_pads(StonePieces.pad_cells(stone_pieces), dug)
	if not host or Terrain.level_points == before:
		return
	_lift_to_ground()
	_set_seep(PitWater.seep(pit_seep, dug, 0.0), true)
	_seep_full = false
	terrain_changed.emit()


## The rovers parked on the farm and the players on foot, as the host knows them,
## are no lower than the ground. A rover or a player on this screen lifts itself
## too, when it hears of the ground (the scene's _show_dug).
func _lift_to_ground() -> void:
	for id: Variant in rover_transforms:
		if rover_is_away(id):
			continue  # a pose in the tunnels is not on the farm
		if id == TUNNEL_ROVER:
			continue  # never lifted by the farm's ground, wherever it is
		var pose: Transform3D = rover_transforms[id]
		var ground_m: float = Terrain.height(Vector2(pose.origin.x, pose.origin.z), dug)
		if pose.origin.y < ground_m:
			pose.origin.y = ground_m
			rover_transforms[id] = pose
	if rover_lent:
		return  # the players are in there too
	for pose: Array in CoopWalkers.out.values():
		pose[1] = maxf(pose[1], Terrain.height(Vector2(pose[0], pose[2]), dug))


## The cells that hold a channel, for water to run in.
func channel_cells() -> Array[Vector2i]:
	return StonePieces.channel_cells(stone_pieces)


## The gauge set the found blocks make (GaugeSet.pieces): size index -> best grade.
## Worked out from found_blocks, so it is the host's and nothing more is saved.
func gauge_pieces() -> Dictionary:
	return GaugeSet.pieces(world_seed, found_blocks.keys())


## The block a check uses: the last one found. {} with none.
func block_in_hand() -> Dictionary:
	var cells: Array[Vector2i] = found_blocks.keys()
	return ReferenceBlock.at(world_seed, cells.back()) if not cells.is_empty() else {}


## Puts an instrument against a block the farm has dug up, as ReferenceBlock.check()
## says, or { refused, reason }. A check, not a calibration: the instrument, its
## drift and the log stay as they were, and the block is kept. A check that gave
## a result is counted for who did it (action_counts, as BLOCK_CHECK_COUNT and
## the instrument, with no XP): a quest can count it, and nothing else reads it.
func check_with_block(instrument_id: String, player_id: String = "") -> Dictionary:
	var block: Dictionary = block_in_hand()
	if block.is_empty():
		return { "refused": true, "reason": "No reference block yet. Dig for one." }
	var result: Dictionary = ReferenceBlock.check(get_sensor(instrument_id), block)
	if not result.get("refused", false) and _player(player_id) != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(_player(player_id), {}) as Dictionary).get_or_add(BLOCK_CHECK_COUNT + instrument_id, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	return result


## A player reading the farm notice board (interact, with the rover by it). It is
## refused unless the player is on the farm, the farm's rover is not away and it
## is within NoticeBoard.REACH_M of the board: the answer is then the reason, which
## never starts with "BOARD:". Otherwise the host takes up the starter jobs offered
## and not yet taken (no other quest is offered by a command) and answers with the
## board's lines, one to a line and with no key names in them (the player's own
## screen adds those). On the host only: the quests are the host's.
func read_farm_board(player_id: String = "") -> String:
	var who: String = _player(player_id)
	if place_of(who) != ZonePresence.FARM:
		return "The farm notice board is on the farm."
	if rover_is_away(ROVER):
		return "The rover is away. Bring it back to the farm notice board."
	var pose: Variant = _rover_pose_now(ROVER)
	if not pose is Vector3 or not NoticeBoard.farm_near(pose):
		return "Drive the rover up to the farm notice board."
	if QuestEngine.offer_board(self, players_present()):
		quests_changed.emit()
	update_quests([], false)
	var own: Variant = player_quest_state.get(who, {})
	return "\n".join(NoticeBoard.farm_lines(QuestEngine.quests(), quest_state, own if own is Dictionary else {}))


## A player's read of the soil probe (a click on it in the plot, on foot or in the
## rover). Counted for who did it (action_counts, as READ_PROBE_COUNT, with no
## XP): the Read the Probe starter job counts it, and nothing else reads it.
## Returns "" or why not (the player must be on the farm).
func read_probe(player_id: String = "") -> String:
	var who: String = _player(player_id)
	if place_of(who) != ZonePresence.FARM:
		return "The soil probe is on the farm."
	if who != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(who, {}) as Dictionary).get_or_add(READ_PROBE_COUNT, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	return ""


## The length a player ("" = the local player) is asked to build from the gauge
## set today (GaugeStack.target), or {} with fewer than two pieces. Worked out
## from the farm's seed, the day, the player and the pieces held, so a guest's
## screen gets the host's answer and nothing is saved.
func block_stack_target(player_id: String = "") -> Dictionary:
	return GaugeStack.target(gauge_pieces().keys(),
		GaugeStack.stack_seed(world_seed, GameClock.get_day_index(), _player(player_id)))


## Builds today's length from the gauge set: { target, sizes, score }, or
## { refused, reason }. `score` is Wring the Blocks' (0 to 100), or
## MinigameScore.SKIPPED with no game: FarmCommands hands a graded one to the
## quests, and nothing here reads it. `target` is the length the player's screen
## showed. The day may have turned at 06:00, or a find reached the farm, while
## they played: then the length built is today's, the answer has `changed`, and
## the score is a skip's, as it was earned on another length. The blocks picked
## on the screen are not sent and not checked: picking is the game's own, and
## the host builds the length from the pieces it holds. A build is counted for who did it
## (action_counts, as BLOCK_STACK_COUNT, with no XP), and that count is all it
## changes: the blocks, every instrument and every log stay as they were, so a
## poor try and a skip leave the same farm.
func build_block_stack(target: int, score: int, player_id: String = "") -> Dictionary:
	var stack: Dictionary = block_stack_target(player_id)
	if stack.is_empty():
		return { "refused": true, "reason": "A stack takes two gauge blocks. Dig for more." }
	if _player(player_id) != MANAGER_ID:
		var done: Dictionary = (action_counts.get_or_add(_player(player_id), {}) as Dictionary).get_or_add(BLOCK_STACK_COUNT, { "count": 0, "xp": 0 })
		done["count"] = int(done["count"]) + 1
	var built: Dictionary = { "target": int(stack["target"]), "sizes": stack["sizes"],
		"score": clampi(score, MinigameScore.SKIPPED, MinigameScore.MAX_SCORE) }
	if target != int(stack["target"]):
		built["score"] = MinigameScore.SKIPPED
		built["changed"] = true
	return built


## Surveys for ore from where the rover is, as OrePocket.survey() says, or
## { refused, reason }. It changes nothing, and takes no word from a guest on where
## the rover is.
func survey_ore() -> Dictionary:
	if rover_is_away(ROVER):
		return { "refused": true, "reason": "The rover is in the tunnels." }
	SaveGame.saving.emit()  # it says where it is
	if not rover_transforms.has(ROVER):
		return { "refused": true, "reason": "The rover's place is not known." }
	var at: Vector3 = parked_rover_transform(ROVER).origin
	return OrePocket.survey(get_sensor(STEERING_ID), world_seed, found_pockets, Vector2(at.x, at.z), new_pockets)


## Fills a dug cell one step. Returns "" or why not.
@warning_ignore("unused_parameter")
func fill(cell: Vector3i, player_id: String = "") -> String:
	var at := Vector2i(cell.x, cell.z)
	var problem: String = Terrain.fill_problem(at, dug) if cell.y == 0 else "There is nothing to fill here."
	if stone_pieces.has(at):
		problem = STONE_IN_THE_WAY
	if problem == "":
		dug[at] -= 1
		if dug[at] == 0:
			dug.erase(at)
		_set_seep(PitWater.seep(pit_seep, dug, 0.0), true)
		# The digging may have changed where the water ends, so look at it next step.
		_seep_full = false
		terrain_changed.emit()
	return problem


## Plants `crop_id` (default: the current seed) on a tilled, empty cell.
## Returns "" or the reason not. With too few credits for the seed, Lin
## fronts it and takes its cost out of that crop's sale, so fines can't lock
## the player out of farming.
func plant_crop(cell: Vector3i, crop_id: String = "", offset_steps: int = OFFSET_CURRENT, player_id: String = "") -> String:
	if crop_id == "":
		crop_id = current_seed()
	if crop_id == "" or crop(crop_id).is_empty():
		return "No crops in the data."
	if not tilled_cells.has(cell):
		return "Till the soil first."
	if plantings.has(cell):
		return "Something is already growing here."
	var cost: int = seed_cost(crop_id)
	var advance: int = 0
	if credits < cost:
		advance = cost
	# Write the planting before any signal, so listeners see the cell occupied.
	plantings[cell] = {
		"crop_id": crop_id,
		"planted_day": GameClock.get_day_index(),
		"planted_at": GameClock.elapsed_days,
		"days_grown": 0,
		"setpoint": clampf(float(crop(crop_id).get("soil_moisture_target", 0.0)) + (planting_offset_steps if offset_steps == OFFSET_CURRENT else offset_steps) * SETPOINT_STEP, 0.0, 1.0),
		"out_of_band_days": 0,
		"out_today": false,
		"advance": advance,
	}
	_note_soil_excursions(false)
	if advance > 0:
		post_phone("LIN: I'll front you the %s seed and take the %s CR out of what I pay for that crop." % [
			crop_name(crop_id), SP811.integer(advance)])
	else:
		add_credits(-cost)
	_award_xp("plant_crop", player_id)
	crops_changed.emit()
	return ""


func is_crop_ready(cell: Vector3i) -> bool:
	if not plantings.has(cell):
		return false
	var planting: Dictionary = plantings[cell]
	return int(planting["days_grown"]) >= int(crop(planting["crop_id"]).get("growth_days", 1))


## The soil's true volumetric water content (fraction): irrigation holds the
## probe's reading at the set point, so the soil sits at set point minus the
## probe's error.
func soil_moisture(cell: Vector3i) -> float:
	var planting: Dictionary = plantings.get(cell, {})
	if planting.is_empty():
		return 0.0
	var probe: DriftingSensor = get_sensor(SOIL_PROBE_ID)
	var error_fraction: float = probe.error / 100.0 if probe != null else 0.0
	return clampf(float(planting["setpoint"]) - error_fraction, 0.0, 1.0)


## What the plot's soil probe reads at a cell, in percent water by volume:
## the true moisture plus the probe's error, to its resolution. Irrigation
## holds this at the set point (when the set point less the error stays within
## 0 % to 100 %), so a drifted probe still reads on target.
func soil_probe_reading(cell: Vector3i) -> float:
	var probe: DriftingSensor = get_sensor(SOIL_PROBE_ID)
	if probe == null:
		return soil_moisture(cell) * 100.0
	var reading: float = soil_moisture(cell) * 100.0 + probe.error
	return snappedf(reading, probe.resolution) if probe.resolution > 0.0 else reading


## Planted cells the soil probe's readout lists before "N more".
const SOIL_PROBE_TEXT_CELLS: int = 4


## The soil probe's readout for its inspect text: each planted cell's reading
## (the first few, then a count of the rest), then its drift and band and its
## calibration due day.
## "Reads beans (1, 2) 32.0 %. Drift +1.30 %, IN TOLERANCE. Cal due day 9."
func soil_probe_text() -> String:
	var readings: PackedStringArray = []
	for cell: Vector3i in plantings:
		if readings.size() == SOIL_PROBE_TEXT_CELLS:
			readings.append("%s more" % SP811.integer(plantings.size() - SOIL_PROBE_TEXT_CELLS))
			break
		readings.append("%s (%s, %s) %s %%" % [
			crop_name(plantings[cell]["crop_id"]).to_lower(), SP811.integer(cell.x), SP811.integer(cell.z),
			SP811.number(soil_probe_reading(cell), 1)])
	var text: String = ("Nothing planted to read." if readings.is_empty()
		else "Reads %s." % ", ".join(readings))
	var probe: DriftingSensor = get_sensor(SOIL_PROBE_ID)
	if probe != null:
		# Like the dome's displays: the drift as the last reference saw it.
		text += " Drift %s, %s." % [probe.format_value(probe.observed_error),
			DriftingSensor.band_label(probe.get_observed_band())]
		text += (" CAL %s." % DriftingSensor.overdue_text(probe.cal_due_day) if probe.is_overdue(GameClock.get_day_index())
			else " Cal due day %d." % probe.cal_due_day)
	return text


func is_soil_in_band(cell: Vector3i) -> bool:
	var planting: Dictionary = plantings.get(cell, {})
	if planting.is_empty():
		return false
	var spec: Dictionary = crop(planting["crop_id"])
	var target: float = float(spec.get("soil_moisture_target", 0.0))
	return absf(soil_moisture(cell) - target) <= float(spec.get("tolerance_band", 0.0)) + BAND_EPSILON


## Marks each growing crop whose soil is out of its band right now. Runs
## whenever the probe drifts or is calibrated and when a set point changes, so
## an excursion between mornings still counts against that day. Signals
## crops_changed when it marks a crop, unless `notify` is false.
func _note_soil_excursions(notify: bool = true) -> void:
	var changed: bool = false
	for cell: Variant in plantings:
		var planting: Dictionary = plantings[cell]
		if not planting.get("out_today", false) and not is_crop_ready(cell) and not is_soil_in_band(cell):
			planting["out_today"] = true
			changed = true
	if changed and notify:
		crops_changed.emit()


## Each morning: a growing crop counts a day out of band if its soil left the
## band at any time since the last morning, then grows a day once at least
## GROWTH_DAY_MIN of that day has passed since planting. A crop is ready within
## half a day of its stated growth time, however late in the day it went in.
## With no `water` (the cistern ran dry) that day's growth is skipped, so
## each crop grows again from the next morning, with nothing else lost.
func _grow_crops(water: bool = true, dawn: bool = true) -> void:
	if plantings.is_empty():
		return
	_note_soil_excursions()
	for cell: Variant in plantings:
		if is_crop_ready(cell):
			continue
		var planting: Dictionary = plantings[cell]
		if planting.get("out_today", false):
			planting["out_of_band_days"] = int(planting["out_of_band_days"]) + 1
			planting["out_today"] = false
		var morning: float = floorf(GameClock.elapsed_days)
		var age: float = morning - float(planting.get("planted_at", morning))
		if water and age >= float(planting["days_grown"]) + 1.0 - GROWTH_DAY_MIN:
			planting["days_grown"] = int(planting["days_grown"]) + 1
	if dawn:
		_note_dawn_soil()


## Soil out of band at 06:00 also counts against the new day, even if it
## drifts back in before anything checks again. The morning runs this last,
## after the robots and the lab sitter have trimmed, so their work counts.
func _note_dawn_soil() -> void:
	if plantings.is_empty():
		return
	_note_soil_excursions(false)
	crops_changed.emit()


## Plots that are still growing, which is what the irrigation waters.
func growing_plots() -> int:
	var count: int = 0
	for cell: Variant in plantings:
		if not is_crop_ready(cell):
			count += 1
	return count


## The cistern gives water for `delta_days` of irrigation. It never goes below
## empty; an empty one at the morning skips that day's growth. Time-based, so frame rate does not matter.
func _draw_cistern(delta_days: float) -> void:
	if cistern_liters <= 0.0:
		return
	var draw: float = float(growing_plots()) * CISTERN_DRAW_L_PER_PLOT_HOUR * delta_days * GameClock.HOURS_PER_DAY
	cistern_liters = maxf(cistern_liters - draw, 0.0)


## "Cistern: 420 L of 600 L."
func cistern_text() -> String:
	# Rounded up, so only an empty one reads 0 L.
	var text: String = "Cistern: %s L of %s L." % [SP811.integer(ceili(cistern_liters)), SP811.integer(roundi(CISTERN_CAPACITY_L))]
	return text + " Empty. " + CISTERN_DRY_HINT if cistern_liters <= 0.0 else text


## Moves the irrigation offset new plantings start with by `steps` × 1 %.
## Returns the new offset in percent.
func adjust_planting_offset(steps: int) -> int:
	planting_offset_steps = clampi(planting_offset_steps + steps, -100, 100)
	return planting_offset_steps


## One line on the offset new plantings start with, for the phone.
func planting_offset_text() -> String:
	var sign: String = "+" if planting_offset_steps > 0 else ""
	return "New plantings start at their target moisture %s%s %%." % [
		sign, SP811.number(float(planting_offset_steps) * SETPOINT_STEP * 100.0, 0)]


## Moves a cell's irrigation set point by `steps` × 1 %. Returns the new set
## point, or -1.0 with nothing planted.
func adjust_setpoint(cell: Vector3i, steps: int) -> float:
	if not plantings.has(cell):
		return -1.0
	var planting: Dictionary = plantings[cell]
	planting["setpoint"] = clampf(snappedf(float(planting["setpoint"]) + steps * SETPOINT_STEP, SETPOINT_STEP), 0.0, 1.0)
	_note_soil_excursions()
	crops_changed.emit()
	return planting["setpoint"]


## Harvests a ready crop into the bin. Returns the bin entry, or {} if not ready.
## One in spec gives XP by what Lin pays for it.
func harvest_crop(cell: Vector3i, player_id: String = "") -> Dictionary:
	if not is_crop_ready(cell):
		return {}
	var planting: Dictionary = plantings[cell]
	var entry: Dictionary = {
		"crop_id": planting["crop_id"],
		"in_spec": int(planting["out_of_band_days"]) == 0 and not planting.get("out_today", false),
		"out_of_band_days": int(planting["out_of_band_days"]) + (1 if planting.get("out_today", false) else 0),
		"advance": int(planting.get("advance", 0)),
	}
	plantings.erase(cell)
	harvest_bin.append(entry)
	if entry["in_spec"]:
		_award_xp("harvest_in_spec", player_id, crop_sale_price(entry))
	crops_changed.emit()
	return entry


## What Lin pays for one bin entry: base price in spec, less the crop's
## out-of-spec penalty if its soil left the band on any growing day.
func crop_sale_price(entry: Dictionary) -> int:
	var spec: Dictionary = crop(entry.get("crop_id", ""))
	var base: int = int(spec.get("base_sell_credits", 0))
	if entry.get("in_spec", false):
		return base
	return roundi(base * (1.0 - float(spec.get("out_of_spec_penalty_pct", 0)) / 100.0))


## What Lin pays `player_id` ("" = the local player) for one bin entry: its
## price, and more with the seller's Agronomy (the lin_price effect).
func lin_pays(entry: Dictionary, player_id: String = "") -> int:
	return roundi(crop_sale_price(entry) * skill_factor("lin_price", player_id))


## What the bin brings if `player_id` ("" = the local player) sells it.
func harvest_bin_value(player_id: String = "") -> int:
	var total: int = 0
	for entry: Dictionary in harvest_bin:
		total += maxi(0, lin_pays(entry, player_id) - int(entry.get("advance", 0)))
	return total


## Lin buys the whole bin. Returns the credits paid (0 if the bin was empty).
## The seller gets XP by the crops' price, before any fronted seed comes out
## and without what their Agronomy adds.
func sell_harvest_to_lin(player_id: String = "") -> int:
	if harvest_bin.is_empty():
		return 0
	var total: int = harvest_bin_value(player_id)
	var count: int = harvest_bin.size()
	var off_spec: int = 0
	var advanced: int = 0
	var priced: int = 0
	for entry: Dictionary in harvest_bin:
		priced += crop_sale_price(entry)
		if not entry.get("in_spec", false):
			off_spec += 1
		else:
			var crop_id: String = str(entry.get("crop_id", ""))
			crops_sold_in_spec[crop_id] = int(crops_sold_in_spec.get(crop_id, 0)) + 1
		advanced += mini(int(entry.get("advance", 0)), lin_pays(entry, player_id))
	harvest_bin.clear()
	add_credits(total)
	_award_xp("sell_crop", player_id, priced)
	crops_changed.emit()
	var note: String = ("" if off_spec == 0
		else " %s off spec, paid at the reduced price." % SP811.integer(off_spec))
	if advanced > 0:
		note += " That's after taking out the %s CR of seed I fronted you." % SP811.integer(advanced)
	post_phone("LIN: Bought %s crops for %s CR.%s" % [SP811.integer(count), SP811.integer(total), note])
	return total


## One line on the crop in `cell`, for the phone.
func crop_status_text(cell: Vector3i) -> String:
	var planting: Dictionary = plantings.get(cell, {})
	if planting.is_empty():
		return ""
	var spec: Dictionary = crop(planting["crop_id"])
	var stage: String = ("ready to harvest" if is_crop_ready(cell)
		else "day %s of %s" % [SP811.integer(int(planting["days_grown"])), SP811.integer(int(spec.get("growth_days", 1)))])
	if cistern_liters <= 0.0 and not is_crop_ready(cell):
		stage += ", not growing: the cistern is empty"
	return "%s, %s. Irrigation set point %s %%, target %s %%" % [
		crop_name(planting["crop_id"]), stage,
		SP811.number(float(planting["setpoint"]) * 100.0, 0),
		SP811.number(float(spec.get("soil_moisture_target", 0.0)) * 100.0, 0)]
