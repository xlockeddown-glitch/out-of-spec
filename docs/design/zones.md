# Zones: level-banded areas away from the farm (design proposal)

Status: **design, 2026-11-26; Ryan answered the open questions too (§14.1). Ryan answered twelve questions the same day (§1); they are decisions for this feature and are logged in `docs/decisions.md`.** This PR changes no code and no data table. Every number and name below is a [PLACEHOLDER] or an [ASSUMPTION] until Ryan sets it.

Ryan's idea, in his words: stage areas to be almost level specific. Underground, for lab levels about 5 to 20, you deal with things that suit the quests of those levels. From about 21 to 50 you are somewhere else, such as Phobos or Deimos, searching for rare tarantulas and getting past obstacles, and you still come home to tend the lab. In co-op, one player can stay and the other go, like mining in Stardew. There can be several areas that cover the same or overlapping levels. "Not one way to do it."

Markers used throughout:

- **[ASSUMPTION]**: a design guess that Ryan should confirm or replace.
- **[PLACEHOLDER]**: a number or name with no source. It only shows the shape of a table.
- **NEW**: a feature the game does not have today.

Four rules run through the whole doc:

- **A zone is somewhere to go, never somewhere you must go.** A farm that stays home still plays. No zone holds the only copy of anything the story needs [ASSUMPTION].
- **The metrology stays honest.** A hazard can knock an instrument out of tolerance. It never changes a reading after the fact. You find out at the bench, as found, like everything else.
- **No death.** A bad day away costs time, items and wear (§5).
- **Small PRs.** The first slice is a rule and a hub, not a planet (§13).

## 0. What exists today

Written against main at `c094966`, from the code.

### 0.1 Underground and digging

- **One away-scene exists: the basalt tunnels** (`scenes/basalt_tunnels.tscn`, `scripts/basalt_tunnels.gd`, `scripts/world/tunnel_rock.gd`). The map is a hand-written grid of characters: rock, floor, arches, crystals, magma and deep water. A parking pad at the mouth (`ExitPad`) takes the rover in and out. The scene holds no rules of its own.
- **You need the rover.** On foot a player only walks, looks, clicks props, opens panels and goes to bed. The farm, the dome and the tunnels need the rover (`docs/decisions.md`, co-op). **The rover is in one place:** in the tunnels it is gone from the farm, and the host keeps and saves where it is.
- **The tunnels hold:** the wild Cobalt Sentinel at a fixed spot (`GameState.SENTINEL_AT`, 10 % daily chance out [PLACEHOLDER]; a player creeps up with the lights low and catches it with the cup), crystal ore, magma and a pool of deep water. The story names the tunnels as Act II's unlock ("Terracotta Knee opens the Tunnels", `story.md`).
- **On the farm:** ore fissures on the Terracotta Plateau (mined from the rover, regrow on a later morning); buried ore pockets from the farm's seed (`OrePocket`, 6 at a time, regrow after 3 days); buried gauge blocks, each one piece of the 81-piece inch set, size and grade from the seed (`GaugeSet`, `ReferenceBlock`); digging in 0.5 m steps (`Terrain.DIG_STEP_M`); stone pieces; **pit water** (`PitWater`): a pit 3 steps deep or more seeps to the water table, 0.5 m at three steps and 1 m at four, a rover wades shallow water and stops at deep water.
- **Everything buried comes from the farm's seed**, so every PC agrees. The save keeps only what changed: the cells found, `new_pockets` and `pocket_pending` for ore, and `pit_seep` for the ground water. §12 reuses that pattern.
- **The game runs one current scene** (`SceneSwitcher`): farm, dome or tunnels. The rover's place is one saved flag (`rover_in_tunnels`).
- **There is no hazard system.** Nothing in the rover or the tunnels costs time, items or wear except steering drift and the uplink (line of sight and lag). No heat, no cold, no air.

### 0.2 Day, night and sleep

- A game day is 720 s of real time (`GameClock.DEFAULT_SECONDS_PER_DAY`); the clock runs 24 hours, a day starts at 06:00, and **the day goes over at 06:00 on its own.** Dawn 04:30, dusk 19:30 (`data/day_night.json`).
- Bed is on the farm only. `CoopBeds.scene_refusal` says "Go to bed from the farm, not the dome, the tunnels or a menu." Alone, going to bed ends the day at once. With friends the day ends when everyone is in bed, and the clock waits one game second short of 06:00 for whoever is up (`CoopBeds`, `GameClock.morning_waits`).
- **There is no rescue and no passing out.** A player in the tunnels at 06:00 simply sees the day turn over there. This doc adds the rescue (§6).

### 0.3 The lab, OIRM, Bram and the cast

- Instruments drift with the clock; an out-of-tolerance as-found starts a recall. Plants need water. The auditor comes every 5th morning. Robots exist (`data/robots.json`: collect spool, calibrate, trellis cards today; the WATER card is designed, not built, `equipment_skills_robots.md`).
- **No sprinkler or hired helper exists.** The Pavonis irrigation model is a prop only.
- **OIRM:** `GameState.at_oirm`, `oirm_trips`, `certificates`, the drop pod on audit mornings. A trip takes days.
- **Cast:** Lin (greenhouse, buys crops), Bram (garage, sells standards, ore), Old Orin (surveyor, beacons), Odalys Brandt (dispatcher), Kestrel (the contractor before you, sells slings off-world), Chet (rival, later an errand runner), Vance (inspector). Lines come from `data/dialogue_dispatches.json`.
- **Species** (`data/tarantula_species.json`): Curlyhair, Mexican Redknee, Brazilian Black, Cobalt Sentinel, Terracotta Knee, Crystal Weaver, Orbital Silk-Spinner, Basalt Thermal-Vent. Only the three real ones and the Cobalt Sentinel carry temperature and humidity numbers: 23 to 25 °C and 54 to 68 % relative humidity for the real ones, 25 °C and 80 % relative humidity for the Sentinel. Terracotta Knee, Crystal Weaver, Orbital Silk-Spinner and Basalt Thermal-Vent have none yet (null). The story already puts a Phobos site (the Larder) at the end.
- **Quests:** the engine, the one-use rewards (`one_use_rewards` in `data/quests.json`: id, name, holder player or farm, a percent, lines), the lab-level gates (`lab_gates` in `data/skills.json`) and the 99-level curve are built. Lab quests and the lab level are shared; personal quests belong to a player (`quests_levels_story.md`).
- **Co-op:** host-authoritative. The host saves; a guest's personal skills live in the guest's own file. Players can already be in different scenes (farm, dome, tunnels): the host refuses a command that needs the rover in a scene where the rover is not. I have not traced how a guest's tunnels scene is fed beyond that, so §12 treats "several areas at once" as new work.

## 1. Ryan's decisions (2026-11-26)

1. **Getting there: both.** A real entrance the first visit (walk or drive to it), then fast travel from a terminal afterwards.
2. **Night away:** you are rescued with a small cost, like passing out in Stardew. Certain quest lines can have camp-out spots where staying the night makes sense.
3. **Co-op split: anyone, anywhere.** Any player, host or guest, may be in any zone. No "host stays home" rule.
4. **Danger: no death.** Hazards cost time, items and instrument wear.
5. **Layout:** fixed hubs (hand-made entry areas with NPCs and landmarks) and changing depths (generated or shuffled deeper parts).
6. **Going early:** a soft gate. You can enter with a warning. Some deep parts, and the shuttle license, need a lab level.
7. **Finds: all of** rare tarantulas, ore and minerals, lost gear and gauge blocks (toward the 81-piece set) and robot parts, and samples and data for OIRM.
8. **Underground areas: all four.** Lava tubes, a flooded aquifer, an abandoned colony mine and polar ice caves. Bands overlap.
9. **Moon tarantula hook** (they cannot live wild on a moon): all three, in different areas. Escaped stock from an abandoned research station adapted in warm service tunnels; smuggler caches; terraform test pods.
10. **Shuttle: both.** Day trips for a fee normally (Phobos orbits Mars about three times a day, so launch windows can matter), and longer multi-day expeditions for certain quest lines.
11. **The lab while away:** it drifts as it does now. Robots, sprinklers or a friend at home cover it. **Plus** a quest reward, or paying an NPC to tend the lab for a day.
12. **Lab levels 50 to 99:** far Mars sites (Valles Marineris, Olympus Mons caves, the polar caps), the asteroid belt and the outer moons (Europa and Ganymede style ice). All three, sketched lightly (§11).

## 2. The zones and their level bands

Bands overlap on purpose. Ryan's anchors: underground about 5 to 20, the moons about 21 to 50. Within them the numbers are mine [PLACEHOLDER]. The band is the lab level the content is *tuned for*; the gate is separate (§7).

| Zone | Lab level band | Theme | Main hazards | Signature finds | Tarantula hook | Entrance (first visit) |
|---|---|---|---|---|---|---|
| **Lava Tubes** (the basalt tunnels, grown) | 5 to 20 | Real Mars lava tubes: long dark tubes with skylight pits (Pavonis Mons has them, and the station is named for it) | Heat near vents, loose basalt, dark | Crystal ore, basalt glass, vent samples for OIRM | Thermal-vent morph near the warm vents [ASSUMPTION] | The tunnel mouth the rover already drives into |
| **Flooded Aquifer** | 8 to 24 | Ice-cemented caverns where ground water seeps, a cousin of `PitWater` | Water depth, pressure drops, slow wading | Water and brine samples, drowned gear, sealed gauge-block cases | None (too wet), or a damp-moss morph [PLACEHOLDER] | A sinkhole south of the plateau, reached by rover |
| **Abandoned Colony Mine** | 12 to 30 | The first colonists' ore mine, shored up with kit that was never inspected | Collapses, bad air pockets, old charges | Ore, lost gear, robot parts, gauge blocks | None | A sealed gate on the plateau road, opened by a key quest |
| **Polar Ice Caves** | 18 to 35 | Layered water-ice and CO₂ ice under the cap, with climate records in the layers | Cold, slick ice, white-out dust | Ice cores (OIRM samples), minerals, frozen probes | **Terraform test pods**: a sealed, heated trial pod left under the ice, still warm and wet inside [ASSUMPTION] | A long drive north, then a ramp |
| **Phobos** | 21 to 40 | Dark, crumbly moon; Stickney crater; an abandoned research station | Very low gravity, dust, the launch window | Station data, robot parts, **escaped station stock** | Escaped stock adapted in warm service tunnels | Shuttle from the pad (§8) |
| **Deimos** | 26 to 50 | Smaller, smoother, quieter; a back-of-beyond hideout | Low gravity, dust, long days between windows | Smuggled crates, lost standards, **smuggler caches** | Cached tarantulas in warm crates | Shuttle from the pad (§8) |
| Far Mars, belt and outer moons | 50 to 99 | Sketched in §11 | | | | |

[PLACEHOLDER] Phobos and Deimos as distinct places:

| | Phobos | Deimos |
|---|---|---|
| Real fact | Orbits in about 7 h 39 min, faster than Mars turns, so from the ground it crosses the sky about every 11 h (about twice a sol); surface gravity about 1/1700 of Earth's | Orbits in about 30 h, slower than Mars turns, so it is up for about 2.5 sols, then down for about 2.5 (a cycle of about 5.4 sols); smaller, smoother surface |
| Feel | Busy, loud, ruined: a research station that someone left in a hurry | Quiet, tidy, odd: a place that was hidden on purpose |
| Giver [ASSUMPTION] | Odalys, who knows the station from her orbital desk | Kestrel, who sells slings off-world and knows who else does |
| Tarantula hook | Station stock, escaped and breeding where the service tunnels are warm | Smuggler caches in warm crates |
| Launch windows | About every 11 game hours [PLACEHOLDER] (§8.2) | Open for about 2.5 days, shut for about 2.5 (§8.2) |
| Obstacle shape | Low gravity jumps and dust; getting back before the window shuts | Locked crates, wrong labels, people who do not want visitors |

**On the moons the hook is one rule:** a tarantula needs warmth and humidity, so a wild one on a moon is never in the open. It is in a sealed, warm place that someone built or left (station tunnels, a smuggler's crate, a terraform pod, which sits in the Ice Caves). On Mars it is different: the Cobalt Sentinel is already wild in the natural tunnels. The three real species and the Sentinel already carry the needed temperature and humidity; a find from a moon is a habitat problem the player solves back in the dome (§10).

## 3. Hubs and depths

Ryan chose fixed hubs with changing depths (decision 5).

### 3.1 A hub

A hub is a hand-made scene, like the farm and the dome are. Every zone has one.

| A hub has | Why |
|---|---|
| A **landing** (parking pad or shuttle dock) and the **terminal** for fast travel (§8) | Where you arrive, and the way home |
| One **named NPC** with landmark props (Orin's beacon rack, a station desk, a smuggler's stall) | The zone's quest giver and its voice |
| A **notice board** with the zone's quests (§10) | Quests are given here, so they are found |
| A **warning sign** when the player is under the band (§7) | The soft gate |
| The **elevator** or lift to the depths | §3.2 |
| A safe **camp spot** (only where a quest line gives one, §6) | Staying the night |
| A small **shop or crate** (spare cells, a heater cartridge, rope) [ASSUMPTION] | The cost of a trip is paid in supplies |

The existing basalt tunnels scene is the natural first hub. It already has the pad, the rock and the Sentinel; it grows by a lift and a terminal, not by a rewrite (§13).

### 3.2 Depths

Each zone has a stack of depths below its hub. Depths are numbered 1, 2, 3 and so on; the depth count a zone has is a [PLACEHOLDER] (about 6 to 10).

- **How they change: reseeded every game day** [ASSUMPTION; Ryan's own words were "generated or shuffled"]. The layout, the finds and the hazards come from the farm's seed, the zone, the depth and the day, the way `OrePocket` and the daily asks already work. Two reasons: every player in a co-op farm sees the same depth that day (so "find the cache at depth 3" works for a team), and nothing needs saving but what was found and taken.
- **Not per visit.** A per-visit reroll would let a player re-roll a bad depth by leaving and returning, and would make two friends see two different depths.
- **A depth is built from hand-made rooms** (pieces like "a vent room", "a collapsed shaft", "a cache alcove") stitched by the seed. Hand-made pieces keep it looking designed; the seed keeps it fresh. [ASSUMPTION]
- **The hub never changes.** Quest NPCs and fast travel live there.

### 3.3 Checkpoints (so progress is kept)

- Every third depth has a **lift station**. Reaching it unlocks it **for the farm** (shared, like the mines in Stardew), and the lift runs hub to station both ways.
- Taking the lift down starts you at that depth's entrance. Taking it up needs no fee.
- A lift station needs a one-time **repair**: a few parts and credits [PLACEHOLDER 100 CR, 2 ore]. That is the money sink and the "I did this" mark.
- Finds are kept the moment you pick them up, **except** that a rescue can cost some (§6).
- The deepest depth reached is shown on the QUESTS view and the phone (NEW).

## 4. What is in a zone (finds)

Ryan chose all of these (decision 7).

| Find | What it is | Where it goes | Notes |
|---|---|---|---|
| **Rare tarantulas** | A caught animal (the catch cup, as the Cobalt Sentinel today) | A dome habitat (§10) | Real habitat limits apply |
| **Ore and minerals** | Crystal ore, basalt glass, brine and ice | The shared wallet and stock (`crystal_ore` today) | Zone ore is richer than farm fissures [ASSUMPTION] |
| **Lost gear and gauge blocks** | Dropped kit, sealed cases, a colonist's gauge set | Blocks to `found_blocks` toward the 81-piece set | See §10 for the one open code question |
| **Robot parts** | Sensors, joints, an optical eye | Robot builds (`equipment_skills_robots.md`) | Cheaper builds or a card |
| **Samples and data for OIRM** | Ice cores, vent gas, rock, a station logbook | A trip to OIRM with the pod (`oirm_trips`) | Paid in credits and lab XP when a certificate comes back [ASSUMPTION] |

Finds are placed by the seed per depth and day, so a daily layout holds a handful of each [PLACEHOLDER].

## 5. Hazards and costs (no death)

Ryan chose: no death; hazards cost time, items and instrument wear (decision 4). The rule for every hazard is **a small, visible cost you can see coming, and always a way out.**

| Cost | What it means in play |
|---|---|
| **Time** | You are slowed, locked in a short wait (waiting for a vent to cool, for a pump), or must go round. Game minutes pass; the lab keeps drifting (§9). |
| **Items** | A stack of ore, a find or a supply is dropped or spoiled. It is lost, or lying where you dropped it (then it can be fetched, risk again). Never the quest items or the gauge blocks you hold: those are exempt [ASSUMPTION], so a hazard can't undo a long search. |
| **Instrument wear** | The instruments in your pack (a field meter, a gauge) take extra **drift** or a knock. You find out at the bench, as found, and the lab's calibration rules decide what it means. The rover takes steering wear. |

Examples per area [PLACEHOLDER numbers]:

| Zone | Hazard | What happens | Cost | The way out |
|---|---|---|---|---|
| Lava Tubes | **Heat** near a vent | Your field meter reads high; pass the vent in the pause window or take the long way | 20 game min, pack instruments drift ×2 for the trip | Wait for the cool half of the vent's cycle |
| Lava Tubes | **Loose basalt** | A short rockfall blocks the way you came | The rover's steering takes a knock (wear) | Another passage, or clear it with the drill (ore spent) |
| Aquifer | **Water depth** | Deep water stops a rover (as `PitWater` does today); wading slows a walker | Time; a wet pack spoils a ration | Pump or ford; the hub sells a pump |
| Aquifer | **Pressure drop** when a seal opens | A hiss, a short flood in a low room | One find drifts to the floor | Shut the valve (a short action) |
| Colony Mine | **Collapse** where old props gave way | A rockfall blocks a side room | The room's finds are lost for the day | Shore it with the hub's props (ore spent) |
| Colony Mine | **Bad air** pocket | Your lamp dims, you must step back | 15 game min | Fan, or another route |
| Ice Caves | **Cold** | Your batteries sag, instruments read slow | Cells lose charge; pack instruments drift | Heater cartridge, or warm up at the lift |
| Ice Caves | **Slick ice** | The rover slides; you skid | A bump (wear) or a lost minute | Studs from Bram |
| Phobos | **Low gravity** | Walks are bouncy; a jump carries you past your mark | Time to come back; a dropped item floats off a step [ASSUMPTION] | Tether; short, deliberate steps |
| Phobos | **Dust** | The lens and the encoder clog (a real dust problem, like the tunnels' anti-static filament) | Instruments read worse until wiped | A wipe stop in each depth |
| Phobos | **The window** | The shuttle only leaves when Phobos is overhead | A long wait or a rescue (§6) | Plan for it (§8) |
| Deimos | **Dust and low gravity** | As Phobos, slower | As Phobos | As Phobos |
| Deimos | **Locked crates** and wrong labels | You can't open a cache without a key or a proof | A wasted trip | The quest gives the key |

**Instrument wear is the metrology hook.** A zone is a rough place to carry a calibrated instrument. The game already says what to do with an instrument that may have drifted: check it against a standard, record the as-found, recalibrate. A zone trip makes that routine real, without a new system. [ASSUMPTION] The extra drift is a multiplier on the existing drift while the instrument is in a zone, not a new mechanism.

## 6. Night away and rescue

Today there is no rescue (§0.2). Ryan chose a small cost, like Stardew passing out, plus camp-outs for certain quest lines (decision 2).

### 6.1 The recall

| Moment | What happens |
|---|---|
| 00:00 [PLACEHOLDER] | A phone warning: "Recall in 2 hours. Get to a lift or the landing." (Dispatch voice: Odalys.) |
| 02:00 | **You are rescued.** A recovery crew carries you out. You wake in your bed at 06:00. |
| Cost [PLACEHOLDER] | A rescue fee of 50 CR from the shared wallet, plus part of the **ore** in your pack (about a third [PLACEHOLDER]) left at the spot. Finds (a tarantula, a block, a part, a sample) are kept. No extra drift hit. |
| Quests | Quest progress is kept. A "be back by" step simply fails for the day and offers again. |

- The crew **brings the rover home** to the farm pad, so a rescue never strands it in a zone. [ASSUMPTION; ties to "the rover is in one place", §8.1]
- Rescue is **not shame**, it is a small bill. It must never leave the player worse off than a day lost.
- **Co-op:** the rescued player counts as "in bed" for the day's end, so the all-in-bed rule still holds (§12.4).

### 6.2 Camp-outs

Certain quest lines can put a **camp spot** in a zone. Staying the night there:

- ends the day for that player with **no rescue fee**, as if they had gone to bed;
- needs **camp supplies** from the hub shop (a heater cartridge, a ration) [PLACEHOLDER 30 CR];
- shows as a bed to the day's end rule, so a friend on the farm in a real bed and a player at a camp can finish the day together;
- is for the lines where it makes sense: a multi-day dig, a survey of a shaft that takes two sunsets, a stay on a moon where the window is the next morning.

**Rule:** the camp is a quest feature, not a general way to avoid the recall. The lab drifts at home either way (§9).

## 7. Soft gates

Ryan chose: you can enter early with a warning; some deep parts and the shuttle license need a lab level (decision 6).

### 7.1 The warning

At a hub's terminal or lift, a player whose **lab level is under the band's start** sees:

> "Recommended lab level 12. You are level 6. The mine is rough below depth 2. Go anyway?" [PLACEHOLDER words]

Yes goes in. It is not a wall, it is information. The warning shows what is rough: "Deeper levels need a lab level of 18" (a hard gate), or "The hazards here are harder than you are used to" (a soft one).

### 7.2 What needs a lab level

Table in the style of `quests_levels_story.md` §3.4. "Also needs" is a condition that exists or is a quest step; a thing opens when the level is reached **and** that holds.

| Lab level | Opens | Also needs | Status |
|---:|---|---|---|
| 5 | Lava Tubes hub (warning below 5), depth 1 to 3 | the rover | partly exists (the tunnels) |
| 8 | Aquifer hub (warning below 8) | | NEW |
| 10 | Lava Tubes depth 4 and below | a lift repaired at depth 3 | NEW |
| 12 | Colony Mine hub (warning below 12) | the gate-key quest | NEW |
| 14 | Aquifer depth 4 and below | a pump | NEW |
| 18 | Ice Caves hub (warning below 18) | | NEW |
| 20 | **Shuttle license**: day trips to Phobos | OIRM account | NEW |
| 24 | Mine depth 5 and below | lift repaired at depth 4 | NEW |
| 26 | Deimos hub (warning below 26) | the shuttle license | NEW |
| 30 | **Expedition permit** (multi-day trips, §8.3) | | NEW |
| 35 | Ice Caves deep cores | | NEW |
| 40 | Phobos deep station | | NEW |
| 45 | Deimos deep stores | | NEW |

- **A second way through each gate** (rule from the main design): a gated part may have a quest version that opens it early, like the provisional way through a lab-level gate (`quests_levels_story.md` §3.2.1). [ASSUMPTION]
- **No story beat sits above lab level 60** (a rule from the same doc). Zones past 60 (§11) are for repeatable work, prestige and cosmetics. [ASSUMPTION]
- **Hubs are never hard-gated by level.** Below a band's start a hub shows the §7.1 warning and lets you in. Only the deep parts and the shuttle license are hard gates. Two named exceptions, neither a level wall: the **moons** need the shuttle license (Deimos below level 26 is a warning, but still behind the license), and the **Colony Mine's entrance** needs the gate-key quest (the level 12 there is a warning).
- Every number in this table is a [PLACEHOLDER] except the band starts Ryan gave (5 and 21), and "a lift every third depth" is too.
- **Bands against the hour budget.** Lab level 20 is about 5 hours of play and 40 about 20 hours (`quests_levels_story.md`). So most zone play happens while the lab level is still low, and trips feed the traveller's **personal** skills and quest points more than shared lab XP (§9.5).

## 8. Travel

Ryan chose both: a real entrance the first visit, then fast travel from a terminal (decision 1), and for the moons, day trips with a fee plus longer expeditions (decision 10).

### 8.1 Entrance, then fast travel

| Visit | How |
|---|---|
| **First time** | A real entrance: drive the rover to it, or walk where the zone allows it. Reaching the hub's pad unlocks the zone for the farm (shared). |
| **After that** | A **terminal** at the dome pad (or the farm's parking pad) opens a list of unlocked hubs. Pick one; a short fade. You arrive **on foot**, and each zone has its own **field rover** at its pad [ASSUMPTION; Open question 7]. |

**Why not "the farm rover goes with the fast-traveller":** the rover is one saved place today (`rover_in_tunnels`). If it travels, the friend who stays home is stranded without it, which breaks decisions 3 (anyone, anywhere) and 11 (a friend covers the lab). A field rover per zone costs one more vehicle and no new rule about who owns it. §12.3 names the save and protocol change.

An unlocked list is per farm. A guest who joins sees what the farm has opened; a guest does **not** get a free skip of the first visit for a zone the farm has not opened.

### 8.2 The shuttle (day trips)

- **Shuttle license** at lab level 20 (§7.2). A real quest step gives it (a short exam at the bench with Vance) [PLACEHOLDER].
- **The fee:** a fare per person for a day trip, about 40 CR [PLACEHOLDER].
- **Launch windows** (real science, lightly): Phobos orbits Mars in 7 h 39 min, faster than Mars turns, so it crosses the sky about every 11 hours, about twice a sol. Deimos is slow: it stays up for about 2.5 sols, then is down for about 2.5, a cycle of about 5.4 sols. A shuttle can only leave and land with its moon up. [ASSUMPTION] The terminal shows the next window.
  - **Phobos**: a window about every 11 game hours, so about two a day, at times that drift [PLACEHOLDER].
  - **Deimos**: open for about 2.5 days, then shut for about 2.5. A trip must be planned inside the open spell. [PLACEHOLDER]
  - Ryan's decision text stays as he said it (day trips with a fee, plus expeditions); this is the in-game reading of it.
- **Missing a window** means waiting for the next one (a Deimos miss may mean days: plan, or camp, §6.2): more time away, not a penalty, and at night the recall (§6) fetches you from the surface if you are inside it.
- A day trip cannot run past the recall (02:00). A trip that does should be an expedition.

### 8.3 Expeditions (multi-day)

- For certain quest lines (a long search, a site survey, a transport job for OIRM), an **expedition permit** (lab level 30 [PLACEHOLDER]) opens a trip of 2 to 3 days [PLACEHOLDER] with a camp spot (§6.2).
- The quest sets the length and the supplies. The lab keeps drifting at home (§9) so the trip must be planned.
- **Never by accident.** The player always sees the length and the cost, and the quest can be abandoned at the camp.

## 9. The lab while you're away

Ryan chose: the lab drifts as it does now; robots, sprinklers or a friend at home cover it; plus a quest reward or paying an NPC to tend it for a day (decision 11).

### 9.1 What drifts

The same things as today: instrument drift (the clock runs), plants needing water, the 5-day audit, recalls. **Nothing about the lab pauses for a trip.** That keeps the metrology honest and gives the trip a cost. A zone day of 12 game hours means a few instruments will come due. [ASSUMPTION]

### 9.2 What covers it

| Cover | Does | Does not |
|---|---|---|
| **A friend at home** (co-op) | Anything a player does | |
| **Robots** | Water, collect spool, calibrate, per their cards (`data/robots.json`, `equipment_skills_robots.md`) | Anything they have no card for; they never calibrate themselves |
| **Sprinklers** [ASSUMPTION, NEW] | Water the plot on a timer, so the plants live while you are away | Anything else; a cost per day in water |
| **The helper (§9.3)** | Waters, feeds the spiders, keeps the dome neat | Calibrate: a helper's bench check is **not traceable** [ASSUMPTION] |

### 9.3 Hire a helper

- **Who:** Lin, who already runs the greenhouse and is learning the dome. [ASSUMPTION; Chet, once he is an errand runner, is a second choice]
- **Cost:** about 40 CR a day [PLACEHOLDER], paid from the shared wallet, from the terminal's "tend the lab" line or from Lin.
- **What she does** for one game day: waters the plants, feeds the spiders, collects the day's spools and logs "kept in good order". **She does not calibrate**: a traceable calibration needs a person at the bench, and the as-found must be honest.
- **She is not a robot.** She says something; you get a phone line at the end of the day (Dispatch voice).
- **Tie to quests:** several lines can give a **free helper day** as a reward (next).

### 9.4 A quest reward version

The one-use rewards system already holds the shape: `one_use_rewards` in `data/quests.json` (id, name, holder, a percent, lines). A new reward **`lab_sitter`**, holder **farm**, text "Lin minds the lab for one day, free", used when the helper is booked [PLACEHOLDER]. It needs no percent. This is a data change plus one more kind of use, which the data check (`one_use`) would learn. [ASSUMPTION] It is a good prize for the first deep quest of a zone, since it is the thing a first trip most needs.

### 9.5 Co-op at home and away

- One friend stays and tends the lab; the other goes (Ryan's "like mining in Stardew"). Nothing in the lab depends on who is where.
- Lab XP (shared) is fed by the home player's bench work; a zone trip feeds the **traveller's** personal skills (Earthworks for digging, Husbandry for a tarantula, Field Ops for driving) and **quest points**.
- Credits are shared (shared wallet) so the traveller's finds pay for the home player's work. This matches the existing rule.

## 10. Rewards and quest tie-ins

### 10.1 Coming home

| Find | Where it goes at home |
|---|---|
| **Rare tarantulas** | A **dome habitat**: a terrarium sized for the species, with temperature and humidity set to its needs (`ideal_temp_c`, `ideal_humidity_pct`). A moon-adapted tarantula may have a *wider* band [PLACEHOLDER] since it adapted in service tunnels. |
| **Gauge blocks** | Toward the 81-piece set. Today `found_blocks` lists farm cells and each piece's size and grade come from the farm's seed. **Open code question (not decided here):** a zone-found block needs a way to be a piece of the same set. The simplest [ASSUMPTION] is that a zone's cache holds blocks the farm has *not yet found*, so each one fills a gap in the set. |
| **Robot parts** | The robot builder (`build_robot`). Parts are a discount, or a card. |
| **OIRM samples** | A pod trip to OIRM; a certificate when it comes back (`certificates`). |
| **Ore and minerals** | The shared stock. |

### 10.2 Quest kinds and zones

Using the four kinds (story, lab, personal, daily) from `quests_levels_story.md` §5. The new checks a zone needs (`zone_visited`, `depth_reached`, `find_in_zone`) are NEW; a zone adds them to the engine's list (§5.3 there).

| Kind | What a zone gives it |
|---|---|
| **Story** | The tunnels already open Act II. A story beat may *start* in a zone but should have a version open without it [ASSUMPTION]. **Exceptions to say out loud:** the story puts the Larder on Phobos, and `quests_levels_story.md` §3.4 puts it at lab level 60, above the Phobos band (21 to 40) and level with the late-game zones. Either the Larder gets a non-Phobos way in, or it is an exception (Open question 10). The Station's Last Log and The Test Pod below are the same: each needs a non-zone version, or is an exception. |
| **Lab** | A job for the lab: bring back a sample, run a field calibration at depth. Shared lab XP and credits. |
| **Personal** | A favor or a challenge for one player: catch a tarantula, reach a depth, find a block. Personal XP, quest points, keepsakes. |
| **Daily** | A small ask per zone per day: "bring back 3 vent samples" [PLACEHOLDER]. |

### 10.3 Example quests per band [PLACEHOLDER names and numbers]

| Band | Kind | Example | Giver | Reward |
|---|---|---|---|---|
| Lava Tubes (5 to 20) | Story | **Beacon Run.** Place three beacons in the tubes so the rover can hold line of sight (Orin's penance) | Orin | Quest point, XP certificate |
| | Personal | **Cool Hand.** Pass a vent twice without losing instrument drift | Orin | Field Ops XP |
| | Daily | Three vent samples | Orin | Credits |
| Aquifer (8 to 24) | Lab | **The Sump Sample.** Bring brine for OIRM and take it there | Vance | Lab XP, a certificate |
| | Personal | **Dry Boots.** Cross the flooded depth with the pump | Vance | Earthworks XP |
| Mine (12 to 30) | Lab | **Old Props.** Shore the first depth, repair the lift | Bram | Lab XP, a **helper day** |
| | Personal | **The Colonist's Set.** Find three blocks the farm has not found | Bram | Earthworks XP, a keepsake |
| Ice Caves (18 to 35) | Lab | **A Core to Certify.** Bring a layered ice core to OIRM | Vance | Lab XP, certificate |
| | Personal | **Cold Calibration.** Check a probe at depth, then at the lift | Odalys | Calibration XP |
| Phobos (21 to 40) | Story | **The Station's Last Log.** Reach the old research desk (zone-only: an exception, see §10.2) | Odalys | Quest point, XP certificate |
| | Personal | **Strays.** Catch one escaped station tarantula in a warm service tunnel | Odalys | Husbandry XP, a new species |
| | Lab | **Window Dressing.** Bring back a field-calibrated gauge before the window | Vance | Lab XP |
| Deimos (26 to 50) | Personal | **A Quiet Crate.** Open a smuggler's cache with Kestrel's proof | Kestrel | Husbandry XP, a new species |
| | Story | **The Test Pod.** Find the terraform pod whose air is still warm and wet (zone-only: an exception, see §10.2) | Kestrel | Quest point |
| Camp-out line (any) | Personal | **Two Sunsets.** Survey the shaft over a night at the camp | Orin | XP certificate |

Each quest names a giver already in the cast. The one with no easy home (Phobos escapee and the pod) is the part Ryan most wants to tune.

## 11. Late game: lab levels 50 to 99

Ryan chose all three: far Mars sites, the asteroid belt and the outer moons (decision 12). Sketched lightly. **No story beat sits above 60**; these are for repeatable work, prestige and cosmetics.

| Area | Lab level band | One-line idea | Hazard flavor | Find flavor |
|---|---|---|---|---|
| **Valles Marineris** | 50 to 62 | A canyon system; layered rock on both walls | Wind, long drives, thin air | Old sediment samples, layered rock |
| **Olympus Mons caves** | 55 to 70 | Lava tubes at a larger scale, a cousin of the Lava Tubes | Heat, scale, getting lost | Mineral veins, big skylights |
| **Polar caps** | 60 to 72 | The cap itself: spiral troughs, layered ice | Cold, white-out | Ice cores of old climate |
| **Asteroid belt** | 70 to 85 | A mining outpost between rocks; a different calibration problem (almost no gravity) | Drift in the real sense, vacuum, debris | Metal samples, a spider farm in a tin can [ASSUMPTION] |
| **Outer moons** (Europa/Ganymede-style ice) | 85 to 99 | Ice shells over oceans, radiation, a long way from home | Radiation, cold, a long trip home | A prestige tarantula and a prestige standard [PLACEHOLDER] |

- Real science, lightly: belt rocks are very far apart and gravity there is almost none. Europa and Ganymede are real ice-covered worlds. Jupiter is about 35 to 55 light-minutes from Mars, so radio delay is minutes, not days; **travel time** is a separate thing and is long, so these trips are multi-day by nature (expeditions, §8.3). Shallow liquid groundwater on Mars is speculative; the Aquifer is fiction in that sense.
- Everything here is **optional** and reuses the zone frame: a hub, depths by seed, hazards as time/items/wear, soft gates, fast travel after the first visit.
- The doc does not design these yet. §13 ends with them on purpose.

## 12. Technical approach and co-op

Ryan chose: anyone, anywhere (decision 3). That means **the host must simulate several areas at once**, with players in different zones.

### 12.1 The hard point

Today a co-op farm keeps one farm scene running on the host. Guests in other scenes (the dome, the tunnels) are supported by simple rules (§0.3), but nothing runs two *worlds* with their own rules (hazards, finds, depths) side by side.

### 12.2 Proposed approach [ASSUMPTION]

- **Plainly:** the game runs **one current scene** per PC (`SceneSwitcher`). Several live 3D zones on one PC would need separate `World3D`s or `SubViewport`s, which nothing here does. So the host does **not** run zone worlds. It runs **pure zone rules** (is the zone open, does the find exist, is it taken, what does the hazard cost), like the Sentinel catch is guarded in `GameState`, plus **seed functions** for layout. The 3D scene for a zone exists only on the PC of whoever is standing in it.
- **A zone is its own scene** (a hub) plus generated depths, loaded **only on the PC of a player who is in it.** The host's rules know every player's zone and depth; its 3D scene is only its own player's.
- **Everything is derived from the seed**, as `OrePocket`, `PitWater` and the daily asks already do: the layout, the finds and the hazards come from (farm seed, zone, depth, day). Every PC computes the same zone from the same inputs. The host does not need to send a world.
- **Commands go to the host**, like `dig` and `till` do today: a guest in a zone sends "take find 7 at depth 3" and the host checks it (the zone is open, the find exists, the player is there, the find is not taken) and answers. This is the existing farm-command pattern, with a zone and a depth added to the address.
- **Layout uses the project's own integer hash, not Godot's RNG**, so every PC builds the same depth.
- **What the host saves:** which finds were taken (per zone, per day), the lifts repaired, the camps used, what is unlocked, who is where. Nothing else.
- **Hazard state, one by one:**

| State | Kind |
|---|---|
| A dropped item lying in a depth | **Synced** while the depth is occupied; **daily-reset** (gone at 06:00) |
| A collapsed room, a flooded low room | **Daily-reset**, from the seed; no save |
| A cleared rockfall, a shored room, a shut valve | **Synced** to others in the depth; **daily-reset** |
| A taken find | **Saved** (per zone per day) |
| A repaired lift, an unlock, a used camp | **Saved** (permanent for the farm) |
| A vent cycle | Pure function of the clock; not stored |

- **A cap:** at most a few zones occupied at once [ASSUMPTION], because a farm has a few players.
- **Presence:** the host tracks each player's place (`farm`, `dome`, `zone_id` plus depth). **This model comes before the first depth** (§13).

### 12.3 Technical risk (marked clearly)

| Risk | Why | Mitigation |
|---|---|---|
| **Host load** with players in 2 or 3 zones | Rules and seed work per zone; no extra 3D world on the host | Pure host-side rules; the 3D scene only on the occupant's PC; a cap on occupied zones |
| **Consistency** between PCs | Procedural depths can drift if any input differs | Seed only; no float chance in the layout; the same rule as `PitWater` ("no chance in it") |
| **A guest drops mid-trip** | They are in a zone that is not theirs | The host forgets their place; the guest's finds were kept at pickup |
| **Join late** | A guest joins while a friend is in a zone | The farm sends the zone's taken-finds list at join, as it sends the farm's |
| **The rover is in one place** | Today one saved flag, `rover_in_tunnels`, says where it is | A **field rover per zone** at its pad, or on foot [ASSUMPTION]. This means **generalizing `rover_in_tunnels` to a zone id**: a **save change and a protocol change** (it is a synced and saved field). "The farm rover goes with the fast-traveller" would strand the home player (§8.1). **Open question 7** |
| **Save size** | Taken finds per zone per day grow | Keep only today's list and the permanent unlocks |

### 12.4 The day's end with players in different places

The all-in-bed rule stands (`CoopBeds`): the day ends when everyone is in bed, and waits just short of 06:00 for whoever is up.

- A player **in a zone at 02:00** is rescued (§6) and counted in bed.
- A player **at a camp** is in bed when they choose to sleep (§6.2).
- A player **on the farm** goes to bed as now.
- `CoopBeds.scene_refusal` must learn two things: a camp is a bed, and a zone's recall is an auto-bed. This is the one change to the existing rule. [ASSUMPTION]
- Alone, going to bed in a zone is refused except at a camp; the recall does the rest.

## 13. Build order (small PRs, one job each, smallest first)

Each PR logs its decisions in `docs/decisions.md` and names its placeholders.

1. **The recall.** The 02:00 rescue (50 CR plus some carried ore, finds kept, rover brought home) and a 00:00 warning, working in the **existing tunnels**. A phone line; the player wakes in bed. Tests for the cost and the day's end. No new area. (The whole first rule of Ryan's decision 2; it works today.)

   *Built 2026-11-26 (feat/tunnel-rescue):* `TunnelRecall` plus `GameState` hooks and `CoopBeds.recall_to_bed`; numbers in `economy.json` `tunnel_recall` [PLACEHOLDER]. Host and solo only at first; guests are now rescued too (see the guest rescue note below). See decisions.md, 2026-11-26.
2. **Zone data.** `data/zones.json`: id, name, band, hazards, finds, hub scene, entrance. A data check. No scene. The tunnels get a row.

   *Built 2026-11-26 (feat/zone-data):* `data/zones.json` (11 rows: the six zones of §2 and the five far sites of §11, bands as in the doc) read by `ZoneData` (`scripts/world/zone_data.gd`: `ids`, `zone`, `band`, `zones_for_level`, `hub_scene`, and a `problems` check); `tests/test_zones.gd` runs the check. The tunnels row is `lava_tubes`, hub `res://scenes/basalt_tunnels.tscn`; the other hub scenes are empty. Ids, hazard and find words and the far-site entrances are [PLACEHOLDER]. See decisions.md, 2026-11-26.
3. **Soft-gate warning.** The terminal and lift line from §7.1, and the lab-level rows of §7.2 in `lab_gates`. Works on the tunnels.

   *Built 2026-11-26 (feat/zone-soft-gate):* `ZoneData.warning_text(zone_id, lab_level)` (pure; `warning_for(row, level, deep_level)` underneath) gives the section 7.1 line or "". At the tunnel mouth the first E under lab level 5 shows it on the phone log and a second E (or leaving the pad) answers; a guest is asked on its own screen before the command is sent, so no protocol change. The 13 section 7.2 rows are in `lab_gates`, all `built:false`. Words in `data/zones.json` `warning` [PLACEHOLDER]. See decisions.md, 2026-11-26.
4. **Zone address and presence model.** The host tracks each player's place (`farm`, `dome`, `zone_id`, depth); the phone shows it; `rover_in_tunnels` becomes a zone id (a save and protocol change). Pure rules, no new scene. **Needs a second reviewer.** Everything below depends on it.

   *Built 2026-11-26 (feat/zone-presence):* `GameState.rover_zone` ("" = farm, else a `data/zones.json` id) is saved and synced; `rover_in_tunnels` stays as a computed yes/no over it (not saved). `ZonePresence` (`scripts/world/zone_presence.gd`) holds the pure rules: `problem(place, depth, about, sender, players)`, `for_scene`, `label`. A player reports its place with the `report_place` command when its scene changes; the host keeps `GameState.player_places` (not saved), forgets a player who leaves, and sends the table to guests inside the clock. The F7 co-op page says where each player is. `CoopSession.PROTOCOL` 16 to 17. The recall still rescues host and solo only; presence now makes a guest rescue possible (next PR). See decisions.md, 2026-11-26.
5. **Lava Tubes hub.** The tunnel mouth stays the entrance. Orin's beacon rack, a notice board and the quest Beacon Run. No generated depth yet.
   *Built 2026-11-26 (feat/lava-tubes-hub):* In the existing tunnels scene, no new scene. `LavaHub` (`scripts/world/lava_hub.gd`, pure) holds the rack, board and three beacon spots (cells of `TunnelRock`) and the one `place_problem` rule; `LavaHubProps` draws them from primitive meshes. `GameState.beacons_placed` is saved (SAVED_LATER, so old saves load with none) and shown to guests through `FarmSync.SHOWN_BY`; the host-run `place_beacon` command checks the spot and that the player is in `lava_tubes`. Beacon Run (`data/quests.json`, story, Orin, farm scope, lab level 5) uses the new `beacons_placed` check; the board only reads the quest, since quests accept themselves. `CoopSession.PROTOCOL` 17 to 18; the host also checks Beacon Run is taken and the rover is in reach. The rover's uplink and line-of-sight rules are not touched. All numbers and Orin's lines are [PLACEHOLDER]. See decisions.md, 2026-11-26.
6. **First depth generator.** Depth 1 from the integer hash (farm seed, zone, depth, day); taken finds saved per day. This is the first full PR a player sees.

   *Built 2026-11-26 (feat/lava-depth-one):* `ZoneDepth` (`scripts/world/zone_depth.gd`, pure) makes depth 1 of `lava_tubes` from a 32-bit integer mix of (farm seed, zone, depth, day), never Godot's random numbers: three room slots, each a hand-made 7x5 piece picked and maybe mirrored by the hash, a landing by the way in, and a trunk with two side passages whose height the hash moves, so a new day is a new map. Two finds in each room and one on the landing (ore, minerals and samples only), always on floor, reachable and never on the start. The way down is a hatch in the hub (cell 8,16); the way up is the existing exit pad, now "WAY UP" below. The depth reuses the tunnels scene built from `TunnelRock.grid()`, so no new scene and no new art (`ZoneDepthProps`, primitive meshes). `take_find(find_id)` is a host-run command (zone and depth by `place_of`/`depth_of`, the find is there today and not taken, the shared rover is in reach with 1.5 m of slack); the reward goes to the shared stock. `GameState.finds_taken` (`{zone: {day, ids}}`) is a SAVED_LATER field, pruned to today, shown to guests on `finds_changed`. `CoopSession.PROTOCOL` 18 to 19; `ZonePresence.MAX_DEPTH` 0 to 1. See decisions.md, 2026-11-26 (Zones step 6). Not yet: hazards, lifts, depths 2 and 3, fast travel, rescuing a guest left below.
7. **Fast-travel terminal.** The list of unlocked hubs, after a first visit. **Depends on Open question 7** (field rover per zone, or on foot); no rover answer is built before Ryan picks.
   - **Built (step 7).** The terminal is the dome console (`FastTravelConsole`, a `FastTravelUI` overlay like the quest board). Fast travel uses a field rover (`TUNNEL_ROVER`) and leaves the farm rover home; the way home is the dome (`leave_zone`). The first real-entrance visit still lends the farm rover (`rover_lent`); that is an open question for Ryan. A player who quits in a zone continues in the zone. Guests in a zone at 02:00 are not yet rescued (the next change). Arrival choices (re-park when nobody is below, the soft-gate warning) are [PLACEHOLDER]. Protocol 21.
8. **Hazard system.** Time, items, wear; heat in the Lava Tubes (vent cycle, instrument drift multiplier). One hazard.

   - **Built (step 8).** `ZoneHazards` (`scripts/world/zone_hazards.gd`, pure): one or two vents on depth 1 of `lava_tubes`, on floor in the trunk's two-wide stretch (cells x 11 to 12, y 7 to 12), from the same integer hash as the depth (tags 300 and up), never on the start, the way up or a find, never in neighbouring rows, and only where a BFS with the vents shut still reaches every floor cell. A vent never blocks: the rover can drive through it. Its cycle is a pure function of `GameClock.elapsed_days` (hot 40 game min, cool 60, a per-vent phase from the hash), so nothing of it is stored or sent. A primitive vent prop glows by the cycle (full while hot, half in the last 10 min before it heats) and the phone says "hot, cools in N min" as the rover nears. Entering a hot vent sends the host-run `enter_vent(vent_id, layout_day)`: the host checks `place_of`, `depth_of`, `rover_depth`, the vent is one of today's and hot at the host's clock, and its copy of the tunnel rover is in the vent's cell (1.5 m of slack). It sets `GameState.zone_heat_trip` (host-only, not saved) and the phone says so once. While it is on, `add_rover_usage` feeds the steering encoder and the tire gauge twice the metres: only the wear that is already there is multiplied, no reading is changed and there is no new instrument. The wheel nuts' count is not wear and is not multiplied. The trip flag clears whenever `rover_zone` changes (the mouth out, `bring_rover_home`, the last one out by `leave_zone`, a released field rover, the rescue, a new trip) and on a load. A leave or rescue while another player stays below leaves the rover where it is, so the flag stays: it is per rover trip. `CoopSession.PROTOCOL` 21 to 22 (a new command). **Not built (follow-up): the 20 game minute time cost of section 5.** Advancing the shared clock mid-trip meets the 02:00 recall, `waits_within` and the other players' clocks; only the drift half is built. Every number is a [PLACEHOLDER]; see decisions.md, 2026-11-26 (Zones step 8).
9. **Depths 2 and 3, the lift and the checkpoint.** The repair, the daily reseed, the lift (once, not repeated elsewhere).
   - **Built (step 9).** `lava_tubes` has depths 1 to 3 (`ZoneDepth.MAX_DEPTH`, `ZonePresence.MAX_DEPTH`). `ZoneDepth.layout` is data-driven (`PLANS`: room slots, carved passages and cross passages per depth) from the same integer hash of (farm seed, zone, depth, day); depth 1 is byte for byte what it was (pinned in `tests/test_zone_depths.gd`) and depths 2 and 3 are different floors on the same day. Finds are `d<depth>_f<n>`, so `finds_taken` needed no migration. Each depth but the last has a hatch (cell 11,13) and every depth a WAY UP pad that goes up one depth (depth 1's to the hub); `change_depth` is host-run, one step at a time, the rover goes with you. Depth 3 is the lift depth (every third, `LIFT_EVERY`): a primitive lift prop at its entrance and at the hub, broken until `repair_lift` (host-run, one time, 100 CR and 2 ore from the shared wallet and stock, refused if short or if the player is not at depth 3 by the lift). `lifts_repaired` (zone -> depths) is saved (SAVED_LATER), shown by FarmSync (`lifts_changed`) and permanent. Repaired, `use_lift` takes the rover from the hub straight to depth 3's entrance and from depth 3 up to the hub, free, with the same host checks as `change_depth`. `deepest_depth` (zone -> depth) is saved and synced and shows as one line on the phone's contract row. Depths 2 and 3 reseed at 06:00 like depth 1 (the settle and the scene resync were already depth-generic) and the 02:00 rescue works from them. Vents stay on depth 1 only. `CoopSession.PROTOCOL` 22 to 23. Every number is a [PLACEHOLDER]; see decisions.md, 2026-11-26 (Zones step 9).
10. **Co-op hardening.** Two-PC test of players in different zones, late join, a guest dropping mid-trip. **Highest-risk PR; second reviewer and a two-PC test.**
   - **Built (step 10).** The host-run zone commands were audited for players in different places, a late joiner and a guest who drops. Fixed: a guest who drops while the last one in a zone sends the rover home (`forget_place` calls `bring_rover_home`: the lent rover to the pad, a console field rover released, its heat trip and lease gone), where before the rover stayed out with nobody on the farm able to reach it; and `take_find` and `place_beacon` now read the rover from `_rover_pose_now` like the vents and the lift, not from a save of the host's own rover. Tests in `tests/test_zone_coop.gd` (real loopback sessions): different depths at once, a late guest told the finds, lifts, deepest depth, beacons, rover and places, and a guest dropping with the lease, the place, the rover and the beds. `docs/playtest.md` has a two-PC checklist. Review round 1 added: the rover also comes home when the last one on the trip drops from the dome or the host stops hosting, guest `move_rover`, `catch_sentinel` and `set_rover_lights` are held to the sender's place, a rover pose with an old epoch is dropped, and the day waits for the rover to be home. No protocol change (stays 23). **Not covered:** the real two-PC run, which is still to do.
   - **Built (guest rescue).** At 00:00 and 02:00 the host also handles every guest its `player_places` table has in a zone: a warning on that guest's own phone (the new `RECALL` message), and at 02:00 `rescue_from_tunnels(guest)` plus `CoopBeds.recall_to_bed(guest)`, then the guest's screen leaves the zone for the farm. Once a day per player; 50 CR per rescued player [PLACEHOLDER]; ore taken once per trip (the baseline moves after a take) [ASSUMPTION]; the rover comes home only when nobody is left on the trip, and a guest in the dome on the trip also keeps the mouth shut. A guest who left the zone since the warning, or dropped, is not charged. `CoopSession.PROTOCOL` 23 to 24. Tests in `tests/test_guest_rescue.gd`. See decisions.md, 2026-11-26 (the 02:00 rescue for guests).
11. **Helper and the reward.** Lin tends the lab; the `lab_sitter` one-use reward.
12. **Camp-outs.** The camp spot, supplies, and `CoopBeds` learning that a camp is a bed.
13. **Flooded Aquifer.** One PR: hub, depth 1, pump, water hazard.
14. **Abandoned Colony Mine.** One PR: hub, gate key quest, collapse hazard.
15. **Polar Ice Caves.** One PR: hub, cold hazard.
16. **Shuttle and license.** The pad, the fee, launch windows, the exam.
17. **Phobos hub,** with the station and the escapee hook. Then **Deimos hub,** with the cache and test-pod hooks.
18. **Expeditions.** A multi-day quest line with a camp.
19. **Late game zones** (§11), one per PR.

## 14. Open questions for Ryan

Each has a recommended option first.

1. **How often do depths change?**
   - (a) Every game day, the same for everyone (recommended: co-op friends see the same depth, and nothing but the finds needs saving).
   - (b) Every visit.
   - (c) Every few days.
2. **Who tends the lab for hire?**
   - (a) Lin (recommended: she already runs the greenhouse).
   - (b) Chet, once he is an errand runner.
   - (c) A new hire.
3. **What does the rescue cost?**
   - (a) 50 CR plus some carried ore [PLACEHOLDER], finds kept, no extra drift hit, the crew brings the rover home (recommended: small, as you asked; the same as §6.1).
   - (b) 50 CR only.
   - (c) A bigger fee and one random item.
4. **Can a helper calibrate?**
   - (a) No: only a person at the bench makes a traceable calibration (recommended: keeps the metrology honest).
   - (b) A non-traceable "bench check" only.
   - (c) Yes, at a cost.
5. **Are lift stations shared across the farm, or per player?**
   - (a) Per farm (recommended: like Stardew's mines; a friend starts where the team reached).
   - (b) Per player.
6. **Which area first after the Lava Tubes?**
   - (a) The Flooded Aquifer (recommended: it builds on `PitWater`, which exists).
   - (b) The Colony Mine.
   - (c) The Polar Ice Caves.
7. **How does the rover work in zones?**
   - (a) Each zone has its own field rover at its pad (or you go on foot), so friends can be in several zones at once (recommended: keeps decisions 3 and 11; needs `rover_in_tunnels` generalized to a zone id).
   - (b) On foot, no rover, in the hubs.
   - (c) The farm rover goes with whoever fast-travels. Not recommended: it strands the home player and breaks decisions 3 and 11.
8. **Do the moons' escaped tarantulas get their own species?**
   - (a) New moon-adapted forms with a wider climate band (recommended: the hook is "they adapted", so they should be different).
   - (b) The existing alien species, found in a new place.
   - (c) Both.
9. **How much does a shuttle day trip cost?**
   - (a) About 40 CR a person (recommended: noticeable, not a wall).
   - (b) A flat fee per trip.
   - (c) A season pass bought once a game year (a cheap way to stop paying each trip).
10. **Should the zone hubs gate the story at all?**
    - (a) No: every story beat has a version open without a zone (recommended; matches "nothing is a wall"). This means the Larder needs a non-Phobos way in, or it is an exception; level 60 sits above the Phobos band (21 to 40).
    - (b) Phobos is required for the Larder only (an exception).
    - (c) Some beats are zone-only (the Station's Last Log and the Test Pod are today).
11. **Which gauge-block pieces does a zone cache hold?**
    - (a) Only pieces the farm has not found, so each fills a gap in the 81-piece set (recommended).
    - (b) Random pieces; duplicates become credits.
    - (c) A separate zone set.

### 14.1 Ryan's answers (2026-11-26)

Ryan answered all eleven the same day. They are decisions and override the text above where they differ.

1. Depths change **every game day**, the same for everyone.
2. The lab sitter is **a new hire**, a new character (name and look [PLACEHOLDER]); not Lin or Chet.
3. Rescue costs **50 CR plus some carried ore** [PLACEHOLDER numbers]; finds kept, no extra drift, the crew brings the rover home.
4. The sitter **cannot calibrate**: only a person at the bench makes a traceable calibration.
5. Lift stations are **per farm**.
6. The second area is the **Flooded Aquifer**.
7. **A field rover per zone** (or on foot); the farm rover stays home.
8. The moons' escaped tarantulas are **new moon-adapted forms** with a wider climate band.
9. A shuttle day trip costs **about 40 CR a person** [PLACEHOLDER].
10. **The Larder on Phobos is the only story exception.** Every other story beat has a way without a zone, so the Station's Last Log and the Test Pod (§10.3) need a non-zone version, or move to lab/personal quests, when they are built.
11. A zone cache holds **only pieces the farm has not found**, each filling a gap in the 81-piece set. Ryan added: **on other planets and moons you can find exotic-material blocks** whose low coefficient of thermal expansion means they **need calibration less often**. (Real gauge blocks come in steel, ceramic and carbide with different expansion; a low-expansion exotic grade is a game idea. How much longer the interval runs is [PLACEHOLDER].)

## 15. Assumptions in one place

All of these are [ASSUMPTION]s unless noted.

- Underground 5 to 20 and moons 21 to 50 are Ryan's. Every other band, level, fee, cost and time is a [PLACEHOLDER].
- Depths reseed every game day and are the same for everyone that day (§3.2).
- Lift stations are shared by the farm and need a one-time repair (§3.3).
- Quest items and gauge blocks are exempt from item loss (§5).
- Extra drift in a zone is a multiplier on the existing drift, not a new mechanism (§5).
- The rescue is at 02:00, with a 00:00 warning, and costs 50 CR and some carried ore; finds are kept; no drift hit (§6).
- The crew brings the rover home after a rescue (§6.1). Each zone has a field rover, or you go on foot, until Ryan answers Open question 7 (§8.1).
- A camp counts as a bed and is a quest feature (§6.2).
- Phobos launch windows come about every 11 hours (about two a day); Deimos is open about 2.5 days, then shut about 2.5 (§8.2).
- Hubs are never hard-gated by level; the moons need the license and the Mine hub needs the gate-key quest (§7.2).
- Every number in §7.2 and "a lift every third depth" are [PLACEHOLDER]s.
- The shuttle license needs lab level 20 and an OIRM account; an expedition permit needs 30 (§7.2).
- Lin tends the lab for about 40 CR a day, cannot calibrate, and a free helper day is a `lab_sitter` one-use reward (§9).
- Sprinklers are a future item (§9.2).
- Cast placement: Orin in the Lava Tubes, Vance in the Aquifer and Ice Caves, Bram in the Mine, Odalys on Phobos, Kestrel on Deimos (§2, §10.3).
- Real tarantulas only live in sealed warm places; the thermal-vent morph near the warm vents and a damp-moss or cold morph are guesses (§2).
- A zone's gauge-block cache holds blocks the farm has not found yet (§10.1).
- The host runs pure zone rules and seed functions, not zone worlds; the 3D scene lives only on the occupant's PC (§12.2).
- `CoopBeds.scene_refusal` learns two exceptions: a camp and the recall (§12.4).
- No story beat sits above lab level 60 (§7.2, §11).
- Zone content is optional: no zone holds the only copy of anything the story needs.

Facts used lightly and checked against the usual references: Phobos orbits Mars in about 7 h 39 min (it crosses the sky about every 11 h) and Deimos in about 30 h (up about 2.5 sols, down about 2.5); both have a surface gravity far below 1/1000 of Earth's (Phobos about 1/1700); Mars has real lava tubes (skylights near Pavonis Mons); Europa and Ganymede are real ice-covered moons; a real tarantula needs warmth and humidity.
