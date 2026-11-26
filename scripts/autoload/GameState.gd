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
signal rover_lights_changed
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

enum MoltStage { ACTIVE, PRE_MOLT, MOLTED }

const STEERING_ID: String = "rover_steering_encoder"
## What a check against a block is counted under in action_counts, before the
## instrument's id ("check_with_block:rover_steering_encoder"). Kept in saves.
const BLOCK_CHECK_COUNT: String = "check_with_block:"
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
const CATCHABLE: Array[StringName] = [&"cobalt_sentinel"]
const SENTINEL: StringName = &"cobalt_sentinel"
## Where the wild one sits, off the sump's edge. How near it notices the rover, how
## fast is calm, how close is on top of it, and how far the cup reaches. [PLACEHOLDER]
const SENTINEL_AT := Vector3(-19.0, 0.0, -24.0)
const SENTINEL_SEES_M: float = 8.0
const SENTINEL_CALM_MPS: float = 3.5
const SENTINEL_CROWDED_M: float = 1.8
const SENTINEL_REACH_M: float = 4.0
## Told once when it is first in sight; the numbers are the ones above.
const SENTINEL_HINT: String = "SENTINEL: Lights low (L), creep, stop short."
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
## The wild Cobalt Sentinel: out by the sump today, and the mornings since it was
## last scared off.
var sentinel_out: bool = false
var sentinel_days_unseen: int = 0
## The rules were told for this sighting (host only, not saved).
var sentinel_sighted: bool = false
## Past this the chance is certain anyway.
const SENTINEL_DAYS_MAX: int = 10
var rover_lights: bool = true
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
## The one rover is on the farm or in the tunnels, and has an id in each, so
## neither scene's place is taken for the other's. Change it with move_rover().
var rover_in_tunnels: bool = false
const ROVER: String = "rover_1"
const TUNNEL_ROVER: String = "rover_1_tunnels"
## The middles of the pads that lead in and out, and how near the rover must be
## on the host, who hears of a friend's late [PLACEHOLDER].
const TUNNEL_PAD := Vector3(20.5, 0.0, -15.5)
const TUNNEL_EXIT := Vector3(-1.5, 0.0, 27.4)
const TUNNEL_PAD_REACH_M: float = 6.0
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
	_set_up_farm(_new_seed())
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
	"boulder_hits", "found_blocks", "found_pockets", "rover_in_tunnels", "enclosures", "stone", "stone_pieces",
	"sentinel_out", "sentinel_days_unseen", "rover_lights", "cistern_liters", "pit_seep", "new_pockets", "pocket_pending",
	"skill_effect_floor", "skill_curve", "action_counts", "lab_xp", "lab_areas_paid", "dug_paid",
	"quest_state", "quest_points", "xp_certificates", "xp_certificates_given", "crops_sold_in_spec",
	"player_quest_state", "xp_certificates_spent", "wheel_meters", "lab_gates_kept"]
## Variables not in SAVED_FIELDS: saved on their own (seed, generator, sensors),
## rebuilt from the logs, per machine, or only used within one call.
const NOT_SAVED: Array[String] = [
	"_seep_days", "_seep_full", "world_seed", "rng", "sensors", "steering", "hygrometer", "last_cal_records",
	"certificates", "local_player_id", "_morning", "_morning_notes", "sentinel_sighted",
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
	if data.get("sentinel_days_unseen", 0) < 0 or data.get("sentinel_days_unseen", 0) > SENTINEL_DAYS_MAX:
		return "'sentinel_days_unseen' is out of range."
	if data.get("sentinel_out", false) and data.get("enclosures", {}).has(String(SENTINEL)):
		return "'sentinel_out' is set for a caught Sentinel."
	var tanks: Dictionary = data.get("enclosures", {})
	for id: Variant in tanks:
		if not id is String or not StringName(id) in CATCHABLE or not _is_tank(tanks[id]):
			return "'enclosures' has an entry that is not a caught tarantula."
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
	if quest_problem != "":
		return quest_problem
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
	sentinel_sighted = false
	farm_loaded.emit()
	lab_xp_changed.emit()
	quests_changed.emit()
	xp_certificates_changed.emit()
	molt_changed.emit(molt_progress, molt_stage)
	enclosures_changed.emit()
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
	# Where the local player stands is theirs to check; a guest's is checked on their screen.
	if id == local_player_id:
		var why: String = CoopBeds.here_refusal()
		if why != "":
			return why
	return CoopBeds.go_to_bed(id)


func get_up(player_id: String = "") -> String:
	CoopBeds.get_up(_player(player_id))
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


func _on_day_started(day: int) -> void:
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
	_grow_crops(watered)
	_run_robot_cards()
	var cadence: int = int(_schedule("cadence_days", 5.0))
	if cadence > 0 and day % cadence == 0:
		_run_audit(day)
	_morning = false
	# After the audit, so the board matches the band the lab ends the morning in.
	refresh_job_board(day)
	update_quests()
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
func add_rover_usage(meters: float, player_id: String = "") -> void:
	if FarmCommands.guest:
		return  # the host's rover wears the sensors
	if not is_finite(meters) or meters < 0.0:
		return
	steering.add_usage(meters * skill_factor("steering_usage", player_id))
	add_tire_usage(meters)
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
	if rover_in_tunnels:
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


## The id the rover goes by where it is now.
func rover_here() -> String:
	return TUNNEL_ROVER if rover_in_tunnels else ROVER


## True if this is the rover's id in the place it is not in.
func rover_is_away(rover_id: String) -> bool:
	return rover_id == (ROVER if rover_in_tunnels else TUNNEL_ROVER)


## Takes the rover into the tunnels or out, from the pad there. Returns "" or why
## not. It comes in at the mouth and comes out where it went in.
func move_rover(into_tunnels: bool, player_id: String = "") -> String:
	if into_tunnels == rover_in_tunnels:
		return "The rover is already there."
	if not CoopRovers.driver(rover_here()) in ["", player_id]:
		return "Someone else is driving the rover."
	SaveGame.saving.emit()  # it says where it is
	var pad: Vector3 = TUNNEL_PAD if into_tunnels else TUNNEL_EXIT
	if not rover_transforms.has(rover_here()) or parked_rover_transform(rover_here()).origin.distance_to(pad) > TUNNEL_PAD_REACH_M:
		return "The rover is not on the pad."
	if into_tunnels:
		park_rover(TUNNEL_ROVER, TUNNEL_START)
	rover_in_tunnels = into_tunnels
	rover_place_changed.emit()
	return ""


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
func standard_price_credits(standard_id: String) -> int:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null:
		return 0
	if _is_contract_stock(standard_id):
		return _discounted(sensor.price_credits)
	return sensor.price_credits


func _discounted(price: int) -> int:
	return price * (100 - contract_discount_pct()) / 100


## "250 CR + 2 crystal ore" for a standard's price.
func standard_price_text(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null:
		return ""
	return "%s CR + %d crystal ore" % [SP811.integer(standard_price_credits(standard_id)), sensor.price_ore]


## Why Bram can't sell this standard right now, or "" if he can.
func standard_purchase_problem(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if sensor == null or sensor.role != "standard" or not _is_bram_stock(standard_id):
		return "Bram doesn't stock that."
	return _purchase_problem(standard_id)


func _purchase_problem(standard_id: String) -> String:
	var sensor: DriftingSensor = get_sensor(standard_id)
	if owned_standards.has(standard_id):
		return "The %s is already on the colony." % sensor.short_name
	var gate: String = tier_problem(standard_id)
	if gate != "":
		return gate
	if credits < standard_price_credits(standard_id) or crystal_ore < sensor.price_ore:
		return "Costs %s; you have %s CR and %d crystal ore." % [
			standard_price_text(standard_id), SP811.integer(credits), crystal_ore]
	return ""


## Buys a standard from Bram (section 1.7). Returns "" on success, or
## the reason it can't happen. It arrives with a maker's certificate traceable
## to OIRM, valid for its first interval, and puts the units it calibrates in
## service (due one interval from today, with no calibration on record yet).
func buy_standard(standard_id: String, player_id: String = "") -> String:
	var problem: String = standard_purchase_problem(standard_id)
	if problem != "":
		return problem
	var sensor: DriftingSensor = get_sensor(standard_id)
	var today: int = GameClock.get_day_index()
	# New from the maker: adjusted against their own OIRM-traceable reference.
	var zeroed: Dictionary = _take_standard(standard_id)
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
func _take_standard(standard_id: String) -> Dictionary:
	var sensor: DriftingSensor = get_sensor(standard_id)
	add_credits(-standard_price_credits(standard_id))
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
	if not CoopRovers.driver(rover_here()) in ["", player_id]:
		return "Someone else is driving the rover."
	if on == rover_lights:
		return ""
	rover_lights = on
	rover_lights_changed.emit()
	SaveGame.saving.emit()  # it says where it is
	watch_sentinel(TUNNEL_ROVER, parked_rover_transform(TUNNEL_ROVER).origin, 0.0)
	return ""


## The rover's place and speed, from whoever drives it. Lit, fast or on top of it,
## it scares the Sentinel.
func watch_sentinel(rover_id: String, at: Vector3, speed_mps: float) -> void:
	if FarmCommands.guest or not sentinel_out or rover_id != TUNNEL_ROVER or not rover_in_tunnels:
		return
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
	if not CoopRovers.driver(rover_here()) in ["", player_id]:
		return "Someone else is driving the rover."
	SaveGame.saving.emit()  # it says where it is
	watch_sentinel(TUNNEL_ROVER, parked_rover_transform(TUNNEL_ROVER).origin, 0.0)
	if is_caught(SENTINEL) or not rover_transforms.has(TUNNEL_ROVER) or not sentinel_in_reach(parked_rover_transform(TUNNEL_ROVER).origin):
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
	return is_caught(species_id) and enclosures[species_id]["molt_stage"] == MoltStage.MOLTED


func is_enclosure_exuvia_visible(species_id: String) -> bool:
	return is_enclosure_spool_ready(species_id) or (is_caught(species_id)
		and GameClock.get_day_index() < enclosures[species_id]["exuvia_until_day"])


## As molt_text(), or "" before the catch.
func enclosure_text(species_id: String) -> String:
	if not is_caught(species_id):
		return ""
	return _molt_line(enclosures[species_id]["molt_progress"], enclosures[species_id]["molt_stage"],
		enclosure_pause_reason(species_id))


func _tick_enclosures(delta_days: float) -> void:
	for id: String in enclosures:
		var tank: Dictionary = enclosures[id]
		if tank["molt_stage"] == MoltStage.MOLTED or enclosure_pause_reason(id) != "":
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
				needed, instrument_name(standard), standard_price_text(standard), contract_discount_pct()])
			upgrades_changed.emit()
		else:
			post_phone("OIRM CONTRACT: %d of %d on-time calibrations in a row." % [contract_run, needed])
		credibility_changed.emit(credibility)
	elif contract_run > 0:
		contract_run = 0
		post_phone("OIRM CONTRACT: run restarted (%s). 0 of %d." % [
			"late calibration" if not record.get("on_time", false) else "not traceable", needed])
		credibility_changed.emit(credibility)


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
	var count: int = mini(maxi(int(_jobs_number("board_size", 3.0)), 0), eligible.size())
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


func _lab_refit_cost() -> Vector2i:
	return Vector2i(maxi(int(_lab_number("refit_credits", 0.0)), 0), maxi(int(_lab_number("refit_ore", 0.0)), 0))


func _lab_refit_days() -> int:
	return maxi(int(_lab_number("refit_days", 1.0)), 1)


## "200 CR + 1 crystal ore, 1 day"
func lab_refit_text() -> String:
	var cost: Vector2i = _lab_refit_cost()
	var days: int = _lab_refit_days()
	return "%s, %s day%s" % [lab_cost_text(cost.x, cost.y), SP811.integer(days), "" if days == 1 else "s"]


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
	_lab_pay(cost.x, cost.y)
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


## Digs a cell of Terrain (y = 0) one step deeper. Returns "" or why not. It costs
## nothing [ASSUMPTION]. A block or an ore pocket there comes up once. The digger
## gets Earthworks XP for a step deeper than the cell has been, and for a block.
func dig(cell: Vector3i, player_id: String = "") -> String:
	var at := Vector2i(cell.x, cell.z)
	var problem: String = Terrain.dig_problem(at, dug) if cell.y == 0 else "This ground can't be dug."
	if stone_pieces.has(at):
		problem = STONE_IN_THE_WAY
	if problem == "" and cell.y == 0:
		problem = StonePieces.dig_beside_pad_problem(at, dug)
	if problem == "":
		dug[at] = dug.get(at, 0) + 1
		if dug[at] > dug_paid.get(at, 0):
			dug_paid[at] = dug[at]
			_award_xp("dig", player_id)
		_set_seep(PitWater.seep(pit_seep, dug, 0.0), true)
		# The digging may have changed where the water ends, so look at it next step.
		_seep_full = false
		terrain_changed.emit()
		if not found_blocks.has(at) and not ReferenceBlock.at(world_seed, at).is_empty():
			found_blocks[at] = true
			_award_xp("find_block", player_id)
			blocks_changed.emit()
		if not found_pockets.has(at) and (at in OrePocket.cells(world_seed) or at in new_pockets):
			found_pockets[at] = true
			pocket_pending[at] = GameClock.get_day_index() + OrePocket.REGROW_DAYS
			crystal_ore += OrePocket.ORE
			pockets_changed.emit()
			ore_changed.emit(crystal_ore)
	return problem


const STONE_IN_THE_WAY: String = "Stone is built here. Take it up first."


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
		if not rover_is_away(id):
			rovers.append(rover_transforms[id])
	if rover_in_tunnels:
		rovers.clear()  # its place is in there
	var walkers: Array[Vector2] = []
	if not rover_in_tunnels:
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
		var pose: Transform3D = rover_transforms[id]
		var ground_m: float = Terrain.height(Vector2(pose.origin.x, pose.origin.z), dug)
		if pose.origin.y < ground_m:
			pose.origin.y = ground_m
			rover_transforms[id] = pose
	if rover_in_tunnels:
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
func _grow_crops(water: bool = true) -> void:
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
	# Soil out of band at 06:00 also counts against the new day, even if it
	# drifts back in before anything checks again.
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
