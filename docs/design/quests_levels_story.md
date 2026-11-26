# Quests, levels, story episodes and bench mini-games (design proposal)

Status: **proposal, 2026-11-26; Ryan answered all eleven open questions (§10).** Those answers are design decisions for this feature; they still need logging in `docs/decisions.md` when the first slice lands. This PR changes no code and no data table. Every number is still a [PLACEHOLDER] or an [ASSUMPTION] until Ryan sets it.

Ryan asked for four things:

1. Levels that go to 99, long but rewarding.
2. A lab level for the shared lab, next to each player's own skills.
3. Quests of four kinds.
4. Short mini-games for repairs and key calibrations (added the same day).

The story (`docs/story/story.md`, "The Silk Standard") stays a loose spine. This doc hangs short episodes off it.

Markers used throughout:

- **[ASSUMPTION]**: a design guess of mine that Ryan should confirm or replace.
- **[PLACEHOLDER]**: a number with no source. It only shows the shape of a table. Ryan supplies or tunes it.
- **NEW**: a feature the game does not have today. Everything not marked NEW is built from what exists.

Three rules run through the whole doc:

- **The lab level opens doors. Personal skills make you better at what is behind them.** A friend who plays one evening a month still walks into every room the farm has opened.
- **Nothing is a wall.** Every gate has a second way through or is reached by normal play. No quest can be failed for good.
- **The metrology stays honest.** A quest or a mini-game never changes an as-found reading, a tolerance or an audit finding. It changes how well the *adjustment* goes and how well the work is paid.

## 0. What the game has today

Written against main at `3b9fe96`.

- **Skills** (`data/skills.json`, `GameState`): six skills, top level 10. Total XP to reach level n is 50 × (n − 1) × n / 2. Scope `player`: Calibration, Uncertainty, Field Ops. Scope `farm`: Instrumentation, Robotics, Husbandry. XP comes through `GameState._award_xp(source_id, player_id)`. K opens the SKILLS view (`scripts/ui/skills_ui.gd`).
- **Known gaps in skills** (`docs/decisions.md`): Instrumentation has no per-level effect and its tier gates were never built, because the XP for them could not be reached. Paid jobs, crops and OIRM trips give no XP.
- **Credibility** (`data/economy.json`): points 0 to 100, start at 10. Bands: Provisional 0, Trusted 30, Accredited 60. It can go down.
- **Gates that exist**: Tier 1 needs one clean audit (`tier1_unlocked`). Tier 2 needs an OIRM account (`has_oirm_account()`). Tier 3 needs a traceable lab (`traceable_lab`, two clean audits in a row) and a certified Tier 2 standard. All in `GameState.tier_problem()`.
- **Job board**: `GameState.refresh_job_board(day)` posts 3 jobs each morning from nine templates. Six need Trusted, three need Accredited and a bigger lab. Results go to `job_log`.
- **First OIRM contract**: `contract_state` ("" / "active" / "complete" / "fulfilled") and `contract_run`. Five on-time traceable calibrations in a row earn 50 % off the pressure controller. The phone already prints "OIRM CONTRACT: n of 5".
- **Logs a quest can read**: `cal_log` (instrument, who did it, on time, traceable, as found in tolerance, TUR), `job_log`, `audit_log`, `certificates`, `oirm_trips`.
- **Plain state a quest can read**: `credits`, `crystal_ore`, `stone`, `optical_silk_spools`, `owned_standards`, `lab_size`, `lab_areas`, `robots`, `plantings`, `found_blocks`, `relay_slotted`, `clean_audit_streak`, `audit_grace_used`.
- **Signals**: `calibration_recorded`, `audit_completed`, `credibility_changed`, `jobs_changed`, `lab_changed`, `robots_changed`, `silk_changed`, `crops_changed`, `oirm_changed`, `skill_leveled`, `phone_message`.
- **No log today** for crop sales, spool collections or Kestrel purchases. `sell_harvest_to_lin()` only posts a phone line.
- **Phone**: `post_phone(text)` and the phone HUD (`scripts/ui/field_phone_hud.gd`) with credibility, jobs, standards and log sections. Cast lines already come from `data/dialogue_dispatches.json` (for example `GameState.bram_line()`).
- **Bench**: `scripts/ui/cal_bench_ui.gd`. One button, ZERO / CALIBRATE. The as-found is frozen on opening. The as-left residual and the operator's uncertainty shrink with the Calibration and Uncertainty skills.
- **Co-op** (`docs/decisions.md`, `scripts/autoload/CoopProfile.gd`): the host runs the farm and saves it. A guest's personal skill XP lives on the guest's PC in `user://coop_player.json`, capped at 16 skills and 1 000 000 000 XP per skill.
- **Time**: one game day is 720 s of real time (`GameClock.DEFAULT_SECONDS_PER_DAY`). Audits come every 5th morning.

### 0.1 Ryan's decisions this doc builds on (2026-11-26)

- 99 levels per skill. Each level costs about 10 % more than the last. Level 92 is about half of 99. Something unlocks every few levels.
- The lab has a lab level, earned by everything done in it. Each player also has personal skills and a total level.
- Four kinds of quest: story, lab, personal, daily.
- The story is a loose spine. No fixed act order. A player can ignore it and farm.
- Co-op: lab quests and the lab level are shared. Personal quests and levels belong to each player and travel with a guest.
- Mini-games: short, skill-based, and "the closer you get the better the calibration ends up being".
- His answers to this doc's eleven questions are in §10.

### 0.2 A name clash to settle

`data/dialogue_dispatches.json` has `"megacorp_name": "OmniSpec Orbital Compliance"`, senders such as "Orbital Compliance" and "Audit Division", and a dispatch (`disp_04`) that says "OmniSpec". The story's corporation is **BNH** (Brightwell-Nonesuch Habitats, "Every Sticker Counts"), and the dispatches there are signed "Warmly, Dispatch" by Odalys Brandt. A third string is in Bram's greetings (`npcs.bram.greetings`: "If OmniSpec asks, this whole garage is 'temporarily uncalibrated.'"). No script reads `megacorp_name`, so the fix is text only. **Decided (§10, 6): BNH sends the dispatches and Odalys signs them "Warmly, Dispatch". OmniSpec is dropped from the dispatch file.** That text fix is its own small PR (§9, step 17); this PR does not touch the data file.

The fix covers every OmniSpec string: `megacorp_name`, `disp_04`, and Bram's greeting. A search for "OmniSpec" over `data/` must come back empty afterward.

Sender names under BNH [ASSUMPTION]: the department names stay, as BNH departments ("Calibration Desk", "Audit Division", "Metrology Governance", "HR & Morale", "Supply Chain", "Telemetry Ops", "Bio-Security Bot", "Drop-Pod Dispatch"). "Orbital Compliance" becomes "BNH Compliance". Odalys relays all of them, so each message closes with "Warmly, Dispatch". `megacorp_name` becomes "Brightwell-Nonesuch Habitats".

## 1. The spine and how episodes hang off it

**The spine in one paragraph.** BNH sent you to Pavonis Shelf Station to keep a small lab in tolerance. Your instruments drift, the auditor comes every 5th morning, and a dispatcher who signs "Warmly, Dispatch" seems to know your bench better than a dispatcher should. As the lab earns trust it gets better standards, an account at OIRM, and bigger rooms. The spiders in the domes turn out to spin silk regular enough to measure with. OIRM wants a second root for its standards, and your lab could be the one that makes it. Whether you chase that, sell calibrations to the neighbors, or grow turnips is up to you.

**An episode** is one short story quest: a cast member, one to four steps, one reward, about 10 to 30 min of play [PLACEHOLDER].

How episodes hang off the spine:

- Each episode has a **giver** and a **gate**. The gate is a lab level, a credibility band, a skill level, quest points, or nothing.
- Episodes do not point at each other in a chain. Any episode whose gate is open can start. That keeps "no fixed act order".
- A few episodes are **spine beats** (the first clean audit, the first contract, the first OIRM certificate). They read state the game already tracks, so they finish even for a player who never opened the quest log.
- An episode may bring a small new feature. Those are marked NEW and can ship after the episode's plain version.
- Ignoring every episode costs nothing but the rewards. No farm system waits on a story quest. [ASSUMPTION]

Episodes sorted by the story's acts, as a pool to draw from (not an order):

| Band the story puts it in | Episodes (from `story.md`) |
|---|---|
| Provisional | The Thirsty Probe, the grace audit, Chet's envelope, the first flare night, Lin fronts seed money (built) |
| Trusted | The first contract, Greenhouse Four, the Terracotta Knee, AUD-1T's own uncalibrated gauge |
| Accredited | The Gossamer link, the master audit, Project Sunsetting |
| After | The intrinsic silk standard, the Larder, the first export |

## 2. The XP curve

### 2.1 Formula

One curve for every skill and for the lab level.

- XP to go from level n to level n + 1: **step(n) = B × G^(n − 1)**
- Total XP to reach level n: **total(n) = round(B × (G^(n − 1) − 1) / (G − 1))**
- B = 50 [PLACEHOLDER] (the first level costs what it costs today). G = 1.10 [PLACEHOLDER] (Ryan's "about 10 % more each level").

This is a plain geometric series, written for this game. It gives the shape Ryan asked for: level 92 sits at 1.1^−7 ≈ 51 % of level 99.

| Level | Total XP to reach it | XP for the next level |
|---:|---:|---:|
| 2 | 50 | 55 |
| 10 | 679 | 118 |
| 25 | 4 425 | 492 |
| 50 | 52 859 | 5 336 |
| 75 | 577 634 | 57 813 |
| 92 | 2 921 662 | 292 216 |
| 99 | 5 693 968 | (top) |

All values follow from B and G, so they are [PLACEHOLDER] with them. `CoopProfile` allows 1 000 000 000 XP per skill, so the curve fits the guest file as it is.

### 2.2 How fast the early levels come

Today one on-time calibration gives 10 Calibration XP. On the new curve that would be five calibrations for level 2, which is days of play. Too slow for a first evening.

Proposal: **multiply today's XP sources by 5** [PLACEHOLDER]. Then:

| Moment | Calibration XP so far | Level |
|---|---:|---:|
| First calibration | 50 | 2 |
| Third calibration (end of first evening) | 150 | 3 |
| About 14 calibrations, or fewer with quests | 679 | 10 |

[ASSUMPTION] A new player should gain a level in something every few minutes in the first hour, and reach level 10 in a favorite skill within the first few sessions.

### 2.3 How the existing sources rescale

| Source id (`data/skills.json`) | Today | Proposed [PLACEHOLDER] |
|---|---:|---:|
| `calibrate_player` | 10 | 50 |
| `calibrate_found_oot`, `calibrate_on_time`, `calibrate_clean_tur` | 5 | 25 |
| `clean_audit` | 20 | 100 |
| `buy_standard` | 15 | 75 |
| `calibrate_standard` | 20 | 100 |
| `collect_spool` | 10 | 50 |
| `slot_spool` | 5 | 25 |
| `mine_fissure` | 2 | 10 |
| `till` | 1 | 5 |
| `build_robot` | 50 | 250 |
| `commission_robot` | 25 | 125 |
| `robot_job` | 1 | 5 |
| `calibrate_robot`, `calibrate_robot_player` | 5 | 25 |

A flat ×5 is not enough for the top. At 50 XP each, level 99 would need about 114 000 calibrations. So XP must grow with the work:

- **Tier multiplier.** Calibrating a unit against a Tier 0 standard gives ×1, Tier 1 ×1.5, Tier 2 ×2.5, Tier 3 ×4 [PLACEHOLDER].
- **Paid jobs give XP** (closes a logged open item). A job's discipline (angle, humidity, electrical, temperature, pressure, soil moisture) is not a skill, so the rule does not use it: the player who finishes the job gets pay ÷ 2 as Calibration XP, plus pay ÷ 4 as Uncertainty XP when the job is on time and traceable [PLACEHOLDER].
- **Crops give XP** (closes a logged open item): see Agronomy in §4.
- **Quests give XP in lumps**, sized to the quest's gate level.
- **Mini-games multiply XP** up to ×1.5 [PLACEHOLDER] (§7).
- The rule that stays: `_xp_after_calibration` gives no XP for an untraceable calibration or one done before half the interval. Spamming the bench earns nothing.

**Decided (§10, 3): about 150 hours of play to level 99 in one skill, for a player who favors that skill.** **The numbers above do not reach it yet.** 5 693 968 XP in 150 hours is about 38 000 XP an hour on average. A top-tier calibration pays 50 × 4 = 200 XP, so that is about 190 top-tier calibrations an hour. One game day is 12 min and intervals run for days, so the bench cannot give that. Calibrations alone will never carry a skill to 99.

So the XP per source must be set from a budget of hours, not from a flat ×5. A first budget [PLACEHOLDER]:

| Levels | XP in the band | Hours | XP per hour needed |
|---|---:|---:|---:|
| 1 to 25 | 4 425 | 3 | about 1 500 |
| 25 to 50 | 48 434 | 12 | about 4 000 |
| 50 to 75 | 524 775 | 35 | about 15 000 |
| 75 to 99 | 5 116 334 | 100 | about 51 000 |

What that means for the sources:

- Late XP has to come mostly from work that grows with the lab: paid jobs (pay grows with band and tier), contracts and quests. Their XP is set per band to meet the table.
- Skills fed by tiny sources need multipliers of their own. At `till` 5 XP, 38 000 XP an hour would be 7 600 tilled cells an hour. `mine_fissure` (10) and spools (50) have the same problem. Each of those skills gets its own source values, set from the hourly budget for that skill, and bigger actions to earn from (a harvest, a sale, a full spool run).
- The ×5 table above is right only for the first band.

This tuning needs a spreadsheet or a small simulation before step 1 of the build order ships numbers.

### 2.4 Level effects spread over 99 levels

Today's effects are per level over 10 levels (`bench_time` 8 % per level, `as_left_residual` 5 % per level with a floor of 0.5, `operator_uncertainty` 10 % per level with a floor of 0.3, `molt_time` and `steering_usage` 3 % per level).

Proposal: **the full effect a level 10 player has today is what a level 99 player has**, and it arrives front-loaded [ASSUMPTION]:

| Level | Share of the full effect [PLACEHOLDER] |
|---:|---:|
| 10 | 25 % |
| 30 | 50 % |
| 60 | 75 % |
| 99 | 100 % |

Straight lines between the rows. A new player feels the skill move early. A level 60 friend is not far behind a level 99 host. The two skill unlocks that exist keep their levels: `molt_on_phone` at Husbandry 3 and `budget_view` at Uncertainty 5.

### 2.5 Existing saves

On first load after the change, XP is multiplied by a conversion factor and the level is read off the new curve. The factor is `old_curve/xp_factor` in `data/skills.json`, 5 for now [PLACEHOLDER]. It matches the first-band table in §2.3 only. When the sources are re-tuned from the hour budget, the factor is set again with them. Whatever it becomes, it must never lower a level. Nobody drops below what they can already do: anything a save has unlocked stays unlocked, and the lab level is credited from the farm's `cal_log`, `job_log` and `audit_log` (decided, §10, 5).

**Effects are kept too.** The level number alone would not keep the promise. A level 10 save today has 2 250 XP. Times 5 is 11 250, which is about level 34 on the new curve, and level 34 gives about 53 % of the full effect (§2.4). Today that save has 100 %. So conversion also stores a floor:

- For each skill, the save records the share of the full effect it had before the change (`effect_floor`, 0 to 1).
- The share in use is max(`effect_floor`, the share for the new level).
- The floor never rises. Once the new level's share passes it, the floor does nothing.
- The two skill unlocks (`molt_on_phone`, `budget_view`) stay unlocked if the save had them.

A new farm has no floor.

## 3. The lab level

### 3.1 What it is

One number, 1 to 99, for the farm. It uses the curve in §2. It lives in the host's save and every player on the farm sees the same number.

It is not credibility. **Credibility is trust, and it can drop. The lab level is experience, and it never drops.** A bad audit costs credibility and a fine. It does not cost a level.

### 3.2 What feeds it

Lab XP is earned by anything done in the lab, by anyone, including robots.

| Action | Where it is seen today | Lab XP [PLACEHOLDER] |
|---|---|---:|
| A traceable calibration by a player | `cal_log` / `calibration_recorded` | 25 × tier multiplier |
| A calibration by a robot (CALIBRATE card) | `cal_log`, `performed_by` a robot | 10 × tier multiplier |
| A standard bought | `buy_standard` (was Instrumentation XP) | 75 × tier multiplier |
| A standard calibrated | `calibrate_standard` (was Instrumentation XP) | 100 × tier multiplier |
| A paid job finished | `job_log` | pay ÷ 2 |
| A clean audit | `audit_log`, `clean_audit_streak` | 250 |
| An OIRM certificate comes back | `certificates` | 200 |
| A spool collected or slotted | `collect_spool`, `slot_spool_into_relay` | 25 |
| A robot built or commissioned | `robots` | 250 |
| A lab area fitted, a lab grown | `lab_areas`, `lab_size` | 150 / 500 |
| A lab quest finished | quest log (§5) | by quest |

Farming, digging and driving do not feed the lab level. They feed personal skills.

### 3.2.1 The honest shortfall, and the rule that fixes it

The amounts in that table are 25 to 500 per action. The curve asks for 137 901 lab XP at level 60, 358 476 at 70, 930 591 at 80 and 2 414 510 at 90. A lab earning a few hundred XP an action would need thousands of actions for each of those. With story beats on those rows, that is a wall, and it breaks the second rule of this doc.

Three changes keep it true:

1. **Lab XP grows with the lab.** Every lab XP amount is multiplied by the lab's size: small ×1, medium ×3, large ×8 [PLACEHOLDER]. A bigger lab does bigger work. This stacks with the tier multiplier, so a Tier 3 calibration in a large lab pays 25 × 4 × 8 = 800 lab XP against 25 for the first one. The size multiplier applies to the feeds in the table above only. It does **not** apply to a quest's lump of lab XP: a quest pays the amount written on it, in any lab.
2. **No story beat sits above lab level 60.** The unlock table (§3.4) is reordered. Levels 61 to 99 hold robots, board size and cosmetics only. A farm that never passes 60 misses no episode.
3. **Lab XP is set from a budget of hours, like skill XP (§2.3).** Target [PLACEHOLDER]: lab level 20 by about 5 hours of farm play, 40 by about 20 hours, 60 by about 50 hours. Lab level 99 is a prestige goal with no deadline. The whole farm, robots included, feeds one bar, so more players reach it sooner.

Even with these, the table's amounts are not proven to hit the target. They need the same spreadsheet pass as §2.3 before the lab-level gates turn on (§9, step 9).

**A provisional way through a lab-level gate.** If a farm meets a row's "also needs" condition and is short of the lab level, the giver of that row's lab quest offers a "provisional" version: the row opens early for that quest only, and finishing the quest pays enough lab XP to close most of the gap [ASSUMPTION]. So a level number alone never holds a story beat shut.

### 3.3 Which skills move to the lab

Decided (§10, 1):

| Skill today | Scope today | Proposal | Why |
|---|---|---|---|
| Instrumentation | farm | **Folds into the lab level.** | It has no effect of its own. Its only job was tier gates, and that is what the lab level does. Its XP sources (`buy_standard`, `calibrate_standard`) become lab XP. |
| Robotics | farm | **Becomes personal.** | Building and programming is something a person gets good at. The robots themselves stay shared. |
| Husbandry | farm | **Becomes personal.** | Same. The spiders stay shared; the steady hands are yours. |
| Calibration, Uncertainty, Field Ops | player | Stay personal. | |

[ASSUMPTION] When Robotics and Husbandry become personal, the host's save gives each player on it the farm's old XP once, so nobody loses a level.

### 3.4 Unlock table

Built mostly from things that exist or are already designed in `docs/design/equipment_skills_robots.md`. "Also needs" is the gate the game has today; it stays: a thing opens when the lab level is reached **and** its existing condition is met (decided, §10, 4). Every level number is a [PLACEHOLDER].

| Lab level | Opens | Also needs | Status |
|---:|---|---|---|
| 1 | The closet lab, Tier 0 standards, the bench | | exists |
| 3 | Daily asks on the phone (§6, D2) | | NEW |
| 5 | Tier 1 standards (FM-3 field meter, WD-1 gauge) | one clean audit | exists |
| 8 | A wall for framed certificates | | NEW, cosmetic |
| 10 | The job board | Trusted | exists |
| 12 | An OIRM account can be opened | | exists |
| 15 | The first OIRM contract is offered | Trusted | exists |
| 18 | Tier 2 standards (TW-6 torque, HM-3 calibrator) | OIRM account | exists |
| 20 | Medium lab, "Greenhouse Four" (5 areas) | 600 CR, 4 ore | exists |
| 25 | First robot and the WATER card | | designed |
| 28 | Job board shows 4 jobs | | NEW |
| 30 | COLLECT SPOOL card | | designed |
| 35 | Second robot; a second OIRM contract | | designed / NEW |
| 40 | Tier 3 standards (HB-700, LS-8.5, Rb-2D) | traceable lab, certified Tier 2 | exists |
| 42 | CALIBRATE card | | designed |
| 45 | Large lab (8 areas); Accredited jobs | 1 500 CR, 8 ore; Accredited | exists |
| 48 | The relay dish azimuth and the Gossamer link | Orbital Silk-Spinner reticle silk (`story.md`) | NEW |
| 52 | The master audit can be asked for | Accredited | NEW |
| 56 | The intrinsic silk standard contract | | NEW |
| 60 | The Larder | | NEW |
| 65 | Third robot; job board shows 5 jobs | | NEW |
| 75 | Fourth robot | | NEW |
| 85 | Robot paint and nameplates | | NEW, cosmetic |
| 92 | A plaque for the wall: "HALFWAY THERE" | | NEW, cosmetic |
| 99 | Gold border on every certificate the lab prints; Odalys sends her mug | | NEW, cosmetic |

Every story beat is at or below 60 (§3.2.1). The game already lets a farm hold more than one accepted job (`active_jobs` is a list), so no row is spent on that.

**The first contract and Tier 3.** The contract is offered at lab level 15, but its prize is 50 % off the HB-700, a Tier 3 standard that opens at lab level 40 with a traceable lab and a certified Tier 2 standard. The rule: **the discount does not bypass the tier gate.** Finishing the five calibrations sets `contract_state` to "complete" and the discount is then held, with no expiry, until Tier 3 opens. The quest's main step is done at "complete". Its optional "fulfilled" step waits for Tier 3. [ASSUMPTION] This is what the code does today; whoever builds the gates checks `buy_standard()` and `bram_catalog()` to confirm.

Between the rows, every level gives a small shared thing so "something unlocks every few levels" holds: a new job template, a bench decoration, a paint for the robots, one more line of phone gossip. [ASSUMPTION] These fillers are cosmetic or flavor, so an empty row never blocks anyone.

## 4. Personal skills

### 4.1 The list

Seven skills, each 1 to 99. The two new ones, Agronomy and Earthworks, are tied to actions that already exist (decided, §10, 2).

| Skill | Earned by (existing actions) | What it improves |
|---|---|---|
| Calibration | `calibrate()` at the bench or pad, finding a unit out of tolerance, paid jobs | Shorter bench time, smaller as-left residual, wider sweet spot in "Set the Zero" (§7) |
| Uncertainty | on-time calibrations, clean TUR, clean audits | Smaller operator uncertainty, the budget view, slower drift in "Hold the Reading" (§7) |
| Field Ops | `mine_fissure`, driving, pad calibrations | Less steering wear, better `survey_ore` |
| Husbandry | `collect_spool`, `collect_enclosure_spool`, `slot_spool_into_relay`, catching | Shorter molts, molt on the phone, calmer spiders in "Thread the Spool" (§7) |
| Robotics | `build_robot`, commissioning, calibrating a robot, programming cards | Cheaper builds, longer robot calibration intervals |
| **Agronomy** (NEW skill) | `till`, `plant_crop`, `harvest_crop` in spec, `sell_harvest_to_lin()` | Wider in-spec band, better price from Lin, reading the soil probe at a glance |
| **Earthworks** (NEW skill) | `dig`, `fill`, `place_stone`, finding gauge blocks, `check_with_block` | Faster digging, more stone per dig, better odds of a block, steadier hands in "Wring the Blocks" (§7) |

`till` moves from Field Ops to Agronomy. Seven skills fits the guest file's cap of 16.

### 4.2 Unlock table

One or two per row so the table stays readable. Levels are [PLACEHOLDER]. Items marked NEW do not exist. The rest exist or scale an effect that exists.

| Level | Calibration | Uncertainty | Field Ops | Husbandry | Robotics | Agronomy | Earthworks |
|---:|---|---|---|---|---|---|---|
| 3 | | | | molt on phone (exists) | | | |
| 5 | CAREFUL mode at the bench (NEW, §7) | budget view (exists) | | | | soil probe reading on the plot label (NEW) | |
| 10 | 25 % of effects | 25 % of effects | 25 % of effects | 25 % of effects | 25 % of effects | 25 % of effects | 25 % of effects |
| 15 | "as found" hint before opening the bench (NEW) | | ore glint seen from the rover (NEW) | handle a second species | | Lin buys one grade up (NEW) | |
| 20 | | guard band shown on the bench (NEW) | | | second card slot per robot (NEW) | | dig two cells deep in one go (NEW) |
| 30 | 50 % of effects | 50 % of effects | 50 % of effects | 50 % of effects | 50 % of effects | 50 % of effects | 50 % of effects |
| 40 | sign a job as "expedited" for more pay (NEW) | | | spools one grade finer (NEW) | | a second harvest from some crops (NEW) | |
| 50 | half-way cape: a lab coat color (NEW, cosmetic) | same | same | same | same | same | same |
| 60 | 75 % of effects | 75 % of effects | 75 % of effects | 75 % of effects | 75 % of effects | 75 % of effects | 75 % of effects |
| 75 | your initials stamped on the units you calibrate (NEW, cosmetic) | | | | | | |
| 99 | 100 % of effects; a title on your certificates (NEW, cosmetic) | same | same | same | same | same | same |

A personal skill never locks a room, a tier or a contract. It makes the player quicker, cleaner or better paid. [ASSUMPTION]

### 4.3 Total level

Total level = the sum of a player's skill levels. Seven skills gives 7 to 693.

- Shown on the SKILLS view and next to the player's name in co-op.
- Milestones give titles and cosmetics only [ASSUMPTION]: 50 "Apprentice", 150 "Technician", 300 "Metrologist", 500 "Principal", 693 "In Spec" [PLACEHOLDER].
- A few personal quests use total level as a gate, so a player who spreads out is not shut out of quests meant for specialists.

### 4.4 Friends who play less

- The lab level opens the same doors for everyone on the farm.
- Quests pay part of their XP as an **XP certificate** (NEW): a lump the player spends on any skill they pick. It is sized to the quest, not to the player, so it lifts a low level a lot and a high level a little.
- Front-loaded effects (§2.4) keep the gap in *results* small even when the gap in levels is large.
- That is all the catch-up there is. No mentor bonus (decided, §10, 8).

## 5. The quest system

### 5.1 The four kinds

| Kind | Who has it | From | Pays | Example |
|---|---|---|---|---|
| Story | the farm's progress, each player's quest points | the cast | quest points, XP certificate, a keepsake | The Thirsty Probe |
| Lab | the farm | OIRM, the auditor, the lab itself | lab XP, credits to the shared wallet | The First Contract |
| Personal | one player | the cast, as favors and challenges | personal XP, quest points, cosmetics | Bram's Ore Run |
| Daily | lab jobs: the farm. Daily asks: one player | the job board, small asks | credits, a little XP | A Dome 4 hygrometer job |

### 5.2 Data shape (sketch; not created in this PR)

`data/quests.json`:

```json
{
  "quests": {
    "thirsty_probe": {
      "kind": "story",
      "giver": "lin",
      "title": "The Thirsty Probe",
      "scope": "farm",
      "gates": { "lab_level": 1 },
      "offer": { "when": "day_at_least", "day": 2 },
      "steps": [
        { "id": "kit", "text": "Get a gravimetric kit from Bram.",
          "check": "owns_standard", "standard_id": "gravimetric_kit" },
        { "id": "cal", "text": "Calibrate the soil probe.",
          "check": "count", "log": "cal_log",
          "where": { "instrument_id": "soil_probe", "traceable": true },
          "at_least": 1, "minigame": "set_the_zero" },
        { "id": "sell", "text": "Sell Lin a crate of in-spec Dust Turnips.",
          "check": "counter", "counter": "crops_sold_in_spec",
          "where": { "crop_id": "dust_turnip" }, "at_least": 1 }
      ],
      "rewards": { "credits": 150, "quest_points": 1,
                   "xp_certificate": 200, "lab_xp": 100,
                   "phone": "npcs/lin/thirsty_probe_done" }
    }
  }
}
```

Every number in the sketch is a [PLACEHOLDER].

Fields:

- `kind`: `story`, `lab`, `personal`, `daily`.
- `giver`: a cast id. Lines come from `data/dialogue_dispatches.json` under `npcs/<id>/…`, as Bram's already do. In the first slice the giver speaks through the phone (`post_phone`). No talk-to-NPC system is assumed.
- `scope`: `farm` (one shared progress, kept in the host's save) or `player` (kept per player; a guest's copy travels with the guest).
- `gates`: any of `lab_level`, `band`, `skill` (id and level), `total_level`, `quest_points`, `quest_done`. All must hold for the quest to be offered.
- `offer`: when it appears. A day, an event, or `always`.
- `steps`: done in order unless the quest says `"any_order": true`.
- `rewards`: credits, quest points, XP (named skill or certificate), lab XP, an item or flag, and a phone line.

### 5.3 What a step can check

A step only reads what `GameState` already tracks. Checks count **from the moment the quest was accepted**, unless marked `"ever": true`.

| Check | Reads | Example |
|---|---|---|
| `stat_at_least` | `credits`, `credibility`, `crystal_ore`, `stone`, `optical_silk_spools`, `clean_audit_streak` | 4 crystal ore in the wallet |
| `flag` | `tier1_unlocked`, `traceable_lab`, `relay_slotted`, `audit_grace_used`, `has_oirm_account()` | An OIRM account is open |
| `band_at_least` | `credibility_band()` | Trusted |
| `owns_standard` | `owned_standards` | The gravimetric kit |
| `lab_size` | `lab_size`, `lab_areas` | Medium lab |
| `count` | rows of `cal_log`, `job_log`, `audit_log`, `certificates` that match `where` | 5 calibrations with `on_time` and `traceable` |
| `state_is` | `contract_state`, `contract_run` | Contract "complete" |
| `level` | a skill level, the lab level, total level | Agronomy 10 |
| `counter` | the per-player action counter below | 5 fissures mined by you |
| `minigame` | the score of a mini-game played for this step (§7) | Set the Zero, any score |

**One NEW counter covers the gaps.** `_award_xp(source_id, player_id)` already runs for every XP-earning action. A small table `action_counts[player_id][source_id]`, bumped there, gives per-player counts for mining, tilling, spools and the rest. Crop sales and Kestrel purchases need a source id of their own (they earn no XP today), which also gives them XP.

The quest code only watches. It never calls `calibrate()` or `complete_job()` itself. If a quest is removed from the data file, the game under it behaves the same.

### 5.4 State and saving

- Farm-scope quest state: a new `GameState.quest_state` dictionary (quest id to accepted day, step index, counts). It must be listed in `SAVED_FIELDS`.
- Player-scope quest state and quest points: per player id on the host while playing, and in the guest's `user://coop_player.json` next to `skills`, so they travel. `CoopProfile` keeps the higher value on a clash, as it does for XP.
- Accept and turn-in are host commands in `FarmCommands`, like every other action.
- Daily picks use the day number as the seed, as the job board does.

### 5.5 The quest log on the phone

A new QUESTS section in the phone HUD, in the phone's current look. No restyle.

- Four short lists: Story, Lab, Personal, Today.
- Each quest shows its title, giver, the current step and a count ("3 of 5").
- One quest can be pinned. Its current step shows as one line under the clock.
- Finished quests move to a DONE list with the reward they paid.
- The lab list and today's lab jobs look the same for everyone on the farm.
- The existing "OIRM CONTRACT: n of 5" line and the jobs section stay. The quest log points at them and does not copy them.

### 5.6 Quest points

- One per story quest, one per larger personal quest [PLACEHOLDER]. Lab and daily quests pay none.
- Personal. They travel with a guest.
- Used as a gate on a few later episodes and for keepsakes from the cast (decided, §10, 11). They buy no power.
- For a farm-scope episode gated on quest points, the highest count among the players on the farm at that moment is the one that counts [ASSUMPTION]. A guest with many points can open an episode for a host with few. A solo host uses their own.
- Shown on the SKILLS view next to total level.

### 5.7 The first contract and the job board as quests

**The first OIRM contract.** The logic stays in `GameState` (`_offer_first_contract()`, `_credibility_after_calibration()`). A lab quest "The First Contract" is a thin wrapper:

- Offered when `contract_state` becomes "active".
- One step: `state_is contract_state complete`, with the count read from `contract_run` (shown as "3 of 5").
- A second, optional step: `state_is contract_state fulfilled` (the HB-700 was bought at the discount). It waits for Tier 3 (§3.4): the discount is held and does not open the tier early.
- Rewards: the discount the contract already gives, plus lab XP. A save that already finished the contract shows the quest as done.

Later contracts are written straight into `data/quests.json` as lab quests, with no new code in `GameState`.

**The job board.** Board logic stays as it is. Each accepted job in `active_jobs` shows under Today in the quest log, with its due day. Finishing it (`complete_job`, a row in `job_log`) ticks it off. Job templates in `data/economy.json` gain nothing but an XP line. Daily asks (§6, D2) fill the days before the board opens at Trusted.

## 6. First slice: twelve quests

Each step names what it checks. Rewards are [PLACEHOLDER]. "NEW" marks what does not exist today.

### Story

**S1. The Thirsty Probe** (giver: Dr. Lin). The Act I opener. Gate: none. Offered the morning of day 2.

Lin weighs one of your turnips on her own scale and texts: "Your irrigation thinks the bed is at 40 %. Your turnip disagrees. I trust the turnip."

| Step | Checks |
|---|---|
| Get a gravimetric kit | `owned_standards` has `gravimetric_kit` (Tier 0, `data/sensor_drift_config.json`) |
| Calibrate the soil probe | `cal_log` row with `instrument_id` `soil_probe`, `traceable` true. Played as "Set the Zero" (§7) |
| Sell Lin a crate of in-spec Dust Turnips | NEW counter on `sell_harvest_to_lin()`; in-spec per `data/crops.json` (`dust_turnip` target and band) |

Reward: 150 CR, 1 quest point, an XP certificate, Lin's line: "Your probe is lying to you. Was. Better." This quest teaches the whole loop: a drifting sensor costs you crops, and a calibration fixes it.

**S2. Warmly, Dispatch** (giver: Odalys Brandt). Introduces Odalys. Gate: none. Offered with the first morning dispatch.

Odalys's note asks you to be ready for the first audit. There are two endings and both finish the quest.

| Step | Checks |
|---|---|
| Have a first audit on file | `audit_log` has one row |
| Ending A, clean | that row is clean (`clean_audit_streak` ≥ 1) |
| Ending B, grace | `audit_grace_used` is true. The manager calibrated overnight (`MANAGER_ID` rows in `cal_log`). In the morning the bench is warm and there is a mug ring on it. NEW: one inspectable prop (`scripts/world/inspectable.gd`) |

Reward: 1 quest point, lab XP, and a different note from Odalys for each ending. Ending B is the better story. Neither is a failure.

**S3. Certified in Three Fonts** (giver: Chet). Introduces Chet. Gate: credibility 20 [PLACEHOLDER], or lab level 6.

Chet's van-rover says CERTIFIED in three fonts. He undercuts you, then slips an envelope under the airlock: one of his customers has a gauge he cannot get to read right.

| Step | Checks |
|---|---|
| Accept the envelope job | NEW: a job handed out by a quest, not by the board. Same shape as a board job, in `active_jobs` |
| Calibrate the gauge for the customer | `job_log` row with that `job_id`. Its as-found is out of tolerance by design |
| Hand it back | any `job_log` row for that `job_id` finishes the quest. `on_time` and `traceable` set the reward |

Reward: 1 quest point for any finish. On time and traceable: the full envelope (200 CR) and Chet owes you one. Late or untraceable: half the envelope and a sour line from Chet. If the job is dropped or runs out, the envelope is back under the airlock the next morning, as often as it takes. The quest cannot be lost. Later (not in this slice): a choice between logging the as-found honestly and keeping it quiet.

### Lab

**L1. Every Sticker Counts** (giver: Inspector Vance). Gate: none.

| Step | Checks |
|---|---|
| Pass an audit with no findings | `audit_log` row, clean; `tier1_unlocked` true |

Reward: lab XP 250. Tier 1 opens as it does today. A save that already has `tier1_unlocked` shows this as done.

**L2. Paperwork From Orbit** (giver: OIRM). Gate: lab level 12.

| Step | Checks |
|---|---|
| Open an OIRM account | `has_oirm_account()` |
| Send a standard to OIRM | `oirm_trips` has one row (`send_to_oirm`) |
| Get its certificate back | `certificates` has one row |

Reward: lab XP 300, 100 CR toward the next trip.

**L3. The First Contract** (giver: OIRM). The wrapper from §5.7. Gate: lab level 15 and Trusted (§3.4). A save whose contract is already active or done shows the quest whatever its lab level (§2.5). Reward: what the contract gives today, plus lab XP 400.

**L4. Greenhouse Four** (giver: Bram). Gate: lab level 20.

| Step | Checks |
|---|---|
| Have 600 CR and 4 crystal ore | `credits`, `crystal_ore` |
| Start the grow | `start_lab_grow()` was accepted |
| Move in | `lab_size` is `medium` |
| Fit one new area | `lab_areas` grew by one (`fit_lab_area`) |

Reward: lab XP 500 and a free refit of one area (NEW: a one-use free refit).

### Personal

**P1. Bram's Ore Run** (giver: Bram). Introduces favors. Gate: none.

| Step | Checks |
|---|---|
| Mine 5 fissures yourself | NEW per-player counter (§5.3), source `mine_fissure` |

Reward: Field Ops XP, 1 quest point, and Bram knocks 10 % off your next standard (NEW: a one-use discount). The ore still goes to the shared wallet, so the farm gains too.

**P2. On the Dot** (skill challenge, Uncertainty). Gate: Uncertainty 5.

| Step | Checks |
|---|---|
| Do 5 on-time calibrations yourself | `cal_log` rows with `performed_by` you and `on_time` true |

Reward: an XP certificate and a pocket watch keepsake (cosmetic). A late one does not reset the count. It just does not add.

**P3. The Missing Blocks** (giver: Old Orin). Gate: Earthworks 5, or two blocks found.

| Step | Checks |
|---|---|
| Find 3 more gauge blocks | `found_blocks` (the 81-piece set) |
| Check an instrument with a block | `check_with_block()` returned a result |
| Build a length Orin names from your blocks | NEW: "Wring the Blocks" (§7) |

Reward: Earthworks XP, 1 quest point, a felt-lined case for the set (cosmetic).

### Daily

**D1. Today's jobs.** The job board, shown in the quest log (§5.7). Exists. The only change is that jobs pay XP.

**D2. Daily asks** (NEW). One small ask a day per player, from lab level 3, picked by the day's seed. Meant for the days before Trusted, and for a friend who drops in for twenty minutes.

| Ask | Checks |
|---|---|
| Lin: "Three Biscuit Reeds, in spec." | sale counter, `biscuit_reed` |
| Bram: "Two ore, if you are out that way." | per-player `mine_fissure` count |
| Odalys: "Check the rover's steering encoder against a block for me." | `check_with_block("rover_steering_encoder")`. A buried block is an angle block (`scripts/metrology/reference_block.gd`), so it can only check an instrument that reads degrees. If the player has no block yet, the day's seed picks another ask |
| Orin: "Till me a row by the beacon." | per-player `till` count |

Reward: 30 to 60 CR and a small XP certificate. A missed ask is gone the next morning with no penalty.

### What is NEW in this slice

1. The quest log, quest points and the per-player action counter.
2. A job handed out by a quest (Chet's envelope).
3. Daily asks.
4. The XP certificate.
5. The mug ring prop.
6. Two mini-games (§7): "Set the Zero" in S1, "Wring the Blocks" in P3.
7. One-use rewards: Bram's 10 % discount on a standard (P1) and a free refit of one lab area (L4).
8. Keepsakes and cosmetics: the pocket watch (P2), the felt-lined case (P3), and a place to see them. They do nothing but exist.

Left for later slices: the first flare night with Kestrel, the Terracotta Knee, AUD-1T's uncalibrated gauge, anything past Trusted.

## 7. Bench mini-games (NEW)

Ryan, 2026-11-26: short games for a repair or a calibration, where you time a click or follow small movements, and "the closer you get the better the calibration ends up being, which can lead to better rewards, more XP".

Everything in this section is NEW. Every number is a [PLACEHOLDER].

### 7.1 The games

Each takes 5 to 20 s and is tied to a real action that is already in the game.

| Game | Feels like | Real action | Where it plugs in | Length |
|---|---|---|---|---:|
| **Set the Zero** | a kick meter | Turning a trim pot until the unit agrees with the standard | ZERO / CALIBRATE in `cal_bench_ui.gd`; the as-left residual in `calibrate()` | 5 to 8 s |
| **Hold the Reading** | reeling in a fish | Waiting for a standard to settle and taking the reading while it is stable | Calibrations against a standard that settles (humidity generator, pressure controller); the operator's term in the uncertainty budget | 10 to 15 s |
| **Wring the Blocks** | a steady slide | Sliding two gauge blocks together until they cling | `check_with_block()`, the 81-piece set, quest P3 | 8 to 12 s |
| **Torque to Spec** | a power bar, five times | Tightening wheel nuts in a star pattern to the click | Rover work in Bram's bay. [ASSUMPTION] There is no rover repair action today, so this one needs it first | 12 to 20 s |
| **Thread the Spool** | a steady hand | Seating a silk spool in the relay without snagging it | `slot_spool_into_relay()` | 6 to 10 s |

How each plays:

- **Set the Zero.** A needle sweeps back and forth across a scale. A green sweet spot sits at zero. Press once to stop the needle for the coarse adjust. It sweeps again, slower and over a narrower scale, for the fine adjust. Press again. The score is how close the second stop is to zero.
- **Hold the Reading.** The reading wanders up and down as the standard settles. A tolerance band is drawn around it. Hold a button to lift your bracket and let go to drop it, and keep the reading inside your bracket. The wander calms over time. The score is the share of time the reading was inside.
- **Wring the Blocks.** Drag one block across the other. A speed gauge must stay in the green: too fast and it skips, too slow and it will not cling. Then a quarter turn at the end, released on the mark. For a stack, pick the blocks that add to the target first (real gauge block practice), then wring each joint. Every found block is both an angle block and a piece of the 81-piece set (`docs/decisions.md`), so the target can be a length or an angle. The score is the average of the joints.
- **Torque to Spec.** Five nuts. For each, hold the button as the torque climbs and let go at the click line. The nuts come in star order, and the game shows which is next. The score is the average closeness.
- **Thread the Spool.** The spool sways. Move left and right to keep it centered on the slot while it lowers. The score is how centered it was when it seats.

The motion in every game comes from the game's seeded RNG, so a replay or a test sees the same sweep.

### 7.2 What the score does

The score is 0 to 100. The game shows it as a grade on the result.

| Score | Grade on the certificate | As-left residual | XP multiplier | Quest grade |
|---:|---|---:|---:|---|
| skipped | Standard | ×1.0 | ×1.0 | Done |
| 0 to 59 | Standard | ×1.0 | ×1.0 | Done |
| 60 to 79 | Good | ×0.8 | ×1.15 | Done |
| 80 to 94 | Fine | ×0.6 | ×1.3 | Done, with a bonus |
| 95 to 100 | Reference | ×0.4 | ×1.5 | Done, with a bonus and a line from the giver |

- **The floor is the one-click result.** A poor try gives exactly what skipping gives. Nobody is punished for trying (decided, §10, 10).
- **A smaller as-left residual is a real reward.** The unit starts its interval closer to zero, so it stays in tolerance longer and is more likely to pass on time next round.
- "Hold the Reading" scales the **operator's uncertainty term** instead of the residual, by the same factors. That can lift the TUR a little. It never changes the standard's own uncertainty.
- A paid job done at Fine or Reference pays a bonus of 10 % or 20 %.
- "Torque to Spec" and "Thread the Spool" scale how long the repair or the seat lasts before the next one.
- **What a score never touches:** the as-found reading, the pass / fail verdict on it, the tolerance, the interval rule, or an audit finding.

### 7.3 Skills make the games kinder

| Skill | Effect in the mini-game |
|---|---|
| Calibration | Widens the sweet spot in "Set the Zero" and "Torque to Spec": up to twice as wide at level 99 |
| Uncertainty | Slows the wander in "Hold the Reading": down to half speed at level 99 |
| Earthworks | Widens the green on the speed gauge in "Wring the Blocks" |
| Husbandry | Slows the sway in "Thread the Spool" |

These follow the same front-loaded shape as §2.4. The existing effects stay and stack: the Calibration skill still shrinks the base residual, and a good score shrinks it again. The two multiply. On a single calibration a perfect score counts for more than levels do: by §2.4 and §7.2, a level 10 player with a Reference score ends closer to zero than a level 40 player with a Good one. Skill pays in two other ways: it makes the high grades easier to hit, and it improves every one-click calibration, where there is no score at all.

### 7.4 Where they appear

Not on every calibration. Routine work stays one click. Decided (§10, 9): a mini-game comes up on a quest step, on the first calibration of each instrument type, and when CAREFUL is on.

| Moment | Mini-game? |
|---|---|
| A routine calibration at the bench or pad | No. One click, as today |
| The same, with **CAREFUL** switched on at the bench | Yes, by choice. Opens at Calibration 5 |
| A quest step marked `"minigame"` | Yes, the first time. Skippable |
| The first calibration of an instrument type the lab has never done | Yes, once per type |
| Calibrating a standard | Only with CAREFUL on |
| A paid job | Only with CAREFUL on, for the bonus |
| The grace-night calibrations by the manager | No |

**Robots** never play. A robot's work counts as a flat score of 60 (Good), less if the robot's own sensors are out of tolerance. A careful player always beats a robot. A robot always beats skipping.

### 7.5 Accessibility for family play

- **Skip is always there**, on the same button every time, and gives the fair default (Standard, ×1.0).
- **Difficulty per player**: Relaxed, Standard, Sharp. Relaxed makes sweet spots half again as wide and the motion 30 % slower. [ASSUMPTION] Rewards are the same on every setting. It is a family game, not a ladder.
- **One button or two keys** for every game. No fast repeated pressing. No hold longer than 3 s.
- **Not color alone.** The sweet spot is marked by position and shape as well as color.
- **No time limit to start.** The game waits for the first press.
- **A "practice" swing** before the first real one in each game type, with no score.
- An option to switch all mini-games off. Then every moment in §7.4 is one click with the default result.

### 7.6 Co-op

- **Who plays:** the player standing at the bench (or pad, relay or rover). Nobody else is asked.
- **The host decides the result.** The guest's client sends the score with the command through `FarmCommands`. The host clamps it to 0 to 100 and applies it. A host among friends does not need more than that. [ASSUMPTION]
- **Watching:** others nearby see a small meter over the bench and the grade when it lands. Later slice.
- **Helping** (later slice): a second player standing at the same bench can hold the standard steady. That widens the sweet spot by 15 %. The helper gets a quarter of the XP.
- **The clock:** bench time passes on the clock as it does today. The mini-game itself adds no game time and does not pause the day for others.
- **XP:** the multiplier applies to the player's personal XP and to the lab XP for that action.

## 8. Co-op summary

| Thing | Belongs to | Saved where |
|---|---|---|
| Lab level, lab XP | the farm | host's save |
| Lab quests, today's jobs | the farm | host's save |
| Story quest progress | the farm (decided, §10, 7) | host's save |
| Quest points | each player | host's save by player id; the guest's own file |
| Personal quests, daily asks | each player | same |
| Personal skills, total level | each player | same (as today) |
| Mini-game difficulty | each player | the player's own settings |

A guest who finishes a story quest on a friend's farm keeps the quest point. They do not get a second point for doing the same quest at home; they get the other rewards.

## 9. Build order (small PRs, one job each)

1. **The curve.** `data/skills.json` gets the geometric curve, top level 99 and source values set from the hour budget (§2.3). Effects respread. **Save conversion, stage 1:** every skill's XP converts, farm skills included, and each skill's `effect_floor` is stored (§2.5). Instrumentation stays a farm skill for now, with its converted XP. No lab level yet. **Built (2026-11-25):** the curve, the ×5 table and the tier multiplier of §2.3, the spread of §2.4 and the floor of §2.5. The hour budget is met for the first band only; the rest waits for jobs, crops and quests to give XP (steps 2 and 5) and for the spreadsheet pass. The robot gates in `data/robots.json` moved to the levels that cost about the same XP as before (`docs/decisions.md`).
2. **XP for jobs and crops.** The logged open item. Adds the per-player action counter. Agronomy does not exist yet, so crop XP goes to Field Ops for now (where `till` is today). The counter records how much came from crop sources. **Built (2026-11-25):** the job rule of §2.3 as two sources, `job_done` (Calibration, 0.5 XP per credit paid) and `job_clean` (Uncertainty, 0.25 per credit, on time and traceable only); three crop sources to Field Ops, `plant_crop` (5), `harvest_in_spec` and `sell_crop` (each 0.25 XP per credit of what Lin pays for the crop), all [PLACEHOLDER]; and the counter of §5.3 as `GameState.action_counts`, saved with the farm, which holds for each player and source how many times and how much XP. `till` is not marked as a crop source (`docs/decisions.md`).
3. **The lab level.** Lab XP, its feeds and the size multiplier, shown on the SKILLS view and phone. No gates yet. **Save conversion, stage 2:** the lab level is credited from `cal_log`, `job_log` and `audit_log`, and the farm's Instrumentation XP is added to lab XP one for one. Then Instrumentation is removed and its two sources feed lab XP. **Built (2026-11-25):** `GameState.lab_xp` on the skills' curve, fed by the eleven `lab_xp_sources` in `data/skills.json` (the values of §3.2, all [PLACEHOLDER]) and multiplied by `lab_level/size_xp` (1, 3, 8). It is the first row of the SKILLS view and a `LAB: level N` line under CRED on the phone, and a level gained is a phone line. A save from before it (`skill_curve` 2 or none) is credited once from its three logs, at the small lab's rate, plus its Instrumentation XP; it is then saved as `skill_curve` 3 and is not credited again. Instrumentation is gone from the data, the robot build check and guests' files. Nothing is gated by the lab level. Decisions and open points are in `docs/decisions.md`.
4. **Robotics and Husbandry go personal; Agronomy and Earthworks arrive.** As decided in §10, 1 and 2. Each player gets the farm's old Robotics and Husbandry XP once. Crop XP earned as Field Ops since step 2 moves to Agronomy, by the counter. `till`, `dig` and the rest move to their new skills from here on. **Built (2026-11-26):** all seven skills are `scope: player`. **Save conversion, stage 3** (`skill_curve` 4): every player the save knows gets the farm's Robotics and Husbandry XP and its kept effect share once; each player's counted crop XP leaves Field Ops for Agronomy, and Field Ops keeps its effect share. Gates on Robotics read the acting player's level; molt time reads the best Husbandry on the farm [ASSUMPTION]. `till` and the three crop sources feed Agronomy; `dig` (5, for a new depth only) and `find_block` (25) feed Earthworks [PLACEHOLDER]. One new effect, `lin_price` (Agronomy, up to 10 % more from Lin [PLACEHOLDER]); Earthworks has none yet. The guest file says curve 3. Notes and questions are in `docs/decisions.md`.
5. **Quest engine.** `data/quests.json`, `quest_state` in the save, the checks in §5.3, and the plain reward kinds: credits, skill XP, lab XP, quest points, a phone line. Quest points are kept per player id in the host's save from this step on, guests included. Two quests ship: L1 and L3. Progress goes to the phone as plain lines. A quest's own `gates` (§5.2) apply from this step: a quest is offered only when they hold. The unlock-table gates (§3.4) are a different thing and wait for step 9. **Built (2026-11-26):** `scripts/quests/quest_engine.gd` and `data/quests.json` (a list of quests with ids). The host looks at the quests after every command and each morning; a guest never does. A new quest is offered only in the morning or when a farm is started or opened, never right after a command. There is no accept or turn-in until step 7: an offered quest is accepted at once and paid when its last step holds. L1 reads the first clean audit; L3 follows the contract and has no gates until step 9; if the contract's standard was bought before the contract was offered, L3 is closed with nothing paid (`closed_when`). `state_is` is a new check. `minigame`, `xp_certificate`, items and player-scope quests wait for their steps. Notes and questions are in `docs/decisions.md`.
6. **The XP certificate.** The pick-a-skill reward and its small picker. S1 ships here, without its mini-game. **Built (2026-11-26):** `xp_certificate` on a quest is a fixed XP lump [PLACEHOLDER]; each player who took part holds one (`xp_certificates` in the host's save, guests too) until they spend it on one skill of their own with the host-side command `spend_xp_certificate`. The 10 % curve makes the same lump lift a low level a lot and a high level a little. The picker opens from a button on the SKILLS view (K) while a certificate is held. S1 ships in `data/quests.json` as `thirsty_probe`: offered the morning of day 2, steps kit, calibration, one in-spec dust turnip sold to Lin (a new farm count, `crops_sold_in_spec`), paying 150 CR, 1 quest point and a 200 XP certificate. Its calibration step carries `"minigame": "set_the_zero"` for step 11, unread until then. Notes and questions are in `docs/decisions.md`.
7. **Quest log on the phone.**
8. **Co-op for quests.** Personal quest state and quest points also go into the guest's own file, so they travel. Until this step a guest's points live only on the host's save. Lab quests join the farm sync. **Built (2026-11-26):** a guest's file (`CoopProfile`, `user://coop_player.json`) now also keeps their quest points by quest, the XP certificates they hold and the ones they have spent, and how far they are in their own quests. It goes to the host in the hello (`CoopSession.PROTOCOL` 15) and meets the host's copy in `GameState.let_in_guest`: the host is the authority for its farm, the file is the guest's record of every farm, and both sides only take the higher value or the union, so joining two hosts or coming back never pays twice. A quest gives one player one certificate on all farms together, and one spent anywhere is spent everywhere (`xp_certificates_spent`). Quests of scope `player` now run: each player has their own entry (`player_quest_state`), offered, counted and paid for them alone; one done on another farm is done here and not paid again. Farm quests, points, certificates and the new fields reach guests in the farm snapshot (`quests_changed`, `xp_certificates_changed`). No shipped quest is of scope `player` yet, and the phone is as it was. Decisions and open questions: `docs/decisions.md`, "Co-op for quests".
9. **Lab-level gates.** Turn on the table in §3.4 and the provisional way through (§3.2.1), once Ryan sets the levels and the lab XP budget has been checked. Existing saves keep what they have.
10. **One-use rewards and keepsakes.** The standard discount, the free refit, and keepsakes with a place to see them.
11. **Mini-game 1: Set the Zero.** With skip, difficulty and the CAREFUL switch. Added to S1. **Built (part 1, 2026-11-26):** the game (`ui/minigames/set_the_zero.tscn`), its pure score, SKIP, the difficulty (Standard, Relaxed, Sharp, Off) and the CAREFUL switch at Calibration 5, both kept on the player's machine. The bench opens it before ZERO / CALIBRATE on the lab's first calibration by hand of a kind of instrument, or with CAREFUL on; the score sets the as-left residual by the table of §7.2, and a skip or a score under 60 is today's result. In co-op the score rides in the calibrate command and the host cuts it to 0 to 100 and to key moments. **Built (part 2, 2026-11-26):** S1's calibration step carries `"minigame": "set_the_zero"`, and while it is the quest's open step the bench opens the game for the soil probe, on an old farm that calibrated one before too, and on a guest's bench. The step is still done by its check, so a skip or a score under 60 does it and pays exactly as before. A score of 60 or more is kept with the step (`scores` in the quest's entry; `CoopSession.PROTOCOL` 16); when the quest is paid, Fine adds 10 % of its credits and Reference 20 % [ASSUMPTION, the paid-job shares of §7.2] and Lin says one more line [PLACEHOLDER]. **Still to come:** the XP multiplier and the paid-job bonus of §7.2. See `docs/decisions.md`.
12. **More of the first slice.** S2 (with the mug ring prop), L2, L4, P1, P2. **Built (part 1, 2026-11-26):** S2 and L2, in `data/quests.json`. S2 is offered at the start with Odalys's note, is done when the first audit is on file, and has two `endings`: the first whose check holds when the quest is paid gives Odalys's closing note (the warning first, then clean). Both pay 1 quest point and 100 lab XP [PLACEHOLDER]. The mug ring (`assets/voxels/mug_ring.glb`, prop `mug_ring`) is on the dome's calibration bench, and can be inspected, once `audit_grace_used` is true; the warm bench is in Odalys's note only. L2 is gated on lab level 12 and follows the account, the trip (`oirm_trips`, a new log for `count`) and a certificate from an OIRM trip that comes back after the trip step is done. Neither needs a one-use reward or a keepsake (step 10), so no reward was left out. Odalys's and OIRM's words are [PLACEHOLDER]. **Still to come:** L4, P1, P2. See `docs/decisions.md`.
13. **Quest-issued jobs.** Chet's envelope, then S3. **Built (2026-11-26):** a farm's quest may carry a `job` (`data/quests.json`): a job shaped as the board's are, handed into `active_jobs` when the quest is offered and never put on the board, with the quest's id on it and on its `job_log` row (`quest`). While the quest is open and no such job is accepted or in `job_log`, the next morning or farm opening hands it out again with a new number and due day, so an envelope that ran out or was dropped comes back as often as it takes; one that runs out costs no credibility [ASSUMPTION]. No new farm field, `SaveGame.VERSION` 1, `CoopSession.PROTOCOL` 16. Also new: `any_gate` (a list of gates of which one must hold) and the gate `credibility`, the check `quest_job`, and a job's `flat_cut_pct`. S3 is gated on credibility 20 or lab level 6, has two steps (`envelope`, `hand_back`) and two endings: on time and traceable pays the whole envelope, 200 CR, and Chet owes you one (a line only); late, untraceable or both pays half, 100 CR, once, with a sour line. Either way 1 quest point. The gauge is a pressure gauge that needs the WD-1 (Tier 1) [PLACEHOLDER]. Its as-found is not made out of tolerance, and the honest-or-quiet choice is not built. Chet's words are [PLACEHOLDER]. See `docs/decisions.md`.
14. **Daily asks.** D2. **Built (2026-11-26):** four quests of kind `daily` in `data/quests.json` (Lin's three in-spec Biscuit Reeds, Bram's two ore, Odalys's check of the rover's steering encoder against a block, Orin's row). Each morning, and when a farm is opened, every player present at lab level 3 or more who holds none of today's is given one, picked by the farm's seed, the day and the player from the asks that can be done (Odalys's only once the farm has dug up a block; Orin's only while the plot has six cells left to till; Bram's only while two fissures are open). It is a player's own quest, held in `player_quest_state` with its day; counting starts when it is given. The row and the ore count any player's tilling and mining (the plot and the fissures are shared, so an ask is never put out of reach by another player) [ASSUMPTION]; the block check counts the player's own. Done, it pays once: 30 to 60 CR and a 25 XP certificate, no quest points [PLACEHOLDER]. The next morning an ask of an earlier day is taken out, done or not, with nothing said and nothing lost, and a new one is given. A guest is given theirs on coming in. An ask and its certificate stay on their farm (they are not in a guest's file). The ask is a phone line from its giver; the phone's look is unchanged and there is no quest log. A check with a block is now counted for who did it (`action_counts`, no XP). "By the beacon" is loose: six plot cells anywhere [ASSUMPTION]. No new farm field, `SaveGame.VERSION` 1, `CoopSession.PROTOCOL` 16. All words are [PLACEHOLDER]. See `docs/decisions.md`.
15. **Mini-game 2: Wring the Blocks,** then P3, which needs it. **Built (2026-11-26):** `ui/minigames/wring_the_blocks.tscn` and `scripts/minigames/wring_the_blocks.gd`, with one button as Set the Zero has. Orin names a length (`GaugeStack.target`): the sum of up to three gauge pieces the farm holds, one length a day for each player, worked out from the farm's seed, the day and the player, so nothing is saved and a guest's screen names the same one. The player picks blocks from a tray of up to six (Left and Right, and the button; any blocks that add up are taken), then wrings each joint: hold to push and let go to ease, keeping the slide's speed in the green against a drag that comes from the seed, then hold through the quarter turn and let go at the mark. A joint is 60 % slide and 40 % turn, the stack's score the mean of its joints, graded by section 7.2's table. Earthworks widens the green and the mark, up to twice as wide; Relaxed, Sharp and Off work as for Set the Zero; no hold is over 2.5 s; nothing moves until the button is pressed; Esc skips. J from the stopped rover opens it with two blocks or more (`build_block_stack`, a new host action; no new message, `CoopSession.PROTOCOL` 16). A build changes only a count of builds for its player: no reading, verdict, tolerance, log or block, and no XP, so a poor try and a skip leave the same farm. P3 is `missing_blocks` in `data/quests.json`, a player's own, gated with `any_gate` on Earthworks 5 or two blocks found (`found_blocks`, the farm's). Steps `find` (three more blocks dug up by anyone on the farm after Orin asks, the new counter `blocks_found`), `check` (the player's own check of any instrument against a block, `check_with_block:*`) and `stack` (the player's own build, with the mini-game). It pays 150 Earthworks XP [PLACEHOLDER], 1 quest point and the keepsake `felt_lined_case`; Fine adds 10 % and Reference 20 % to the XP [ASSUMPTION: the bonus was on credits only, and P3 pays none], and Reference has a line from Orin. A keepsake is a name and a text in the data's `keepsakes`, held by having done its quest (`QuestEngine.keepsakes_of`), so it gives no power, adds no farm field (`SaveGame.VERSION` 1) and travels with the done quest; nothing shows it yet (step 10). All numbers are [PLACEHOLDER] and Orin's words too. See `docs/decisions.md`.
16. **Mini-games 3 to 5,** one PR each. Torque to Spec needs a rover repair action first. **Built (mini-game 3, 2026-11-26):** Hold the Reading (`ui/minigames/hold_the_reading.tscn`, `scripts/minigames/hold_the_reading.gd`), with one button as the other games have. The reading wanders on a chart (three slow waves, phases from the seed) and calms to 35 % by the end of a 12 s run [PLACEHOLDER]; holding lifts the bracket, letting go drops it, and the score is the share of the run with the reading inside. Nothing moves before the first press; no hold runs over 2.5 s (the game lets go and says so); Relaxed has a bracket 50 % taller and a slower wander, Sharp a shorter bracket and a faster one, Off opens no game. Uncertainty slows the wander, to half speed at 99, by the front-loaded share the other games take from their skills. **Which calibrations get it** [ASSUMPTION]: a unit whose standard today is the humidity generator or the pressure controller (`MinigameScore.SETTLING_STANDARDS`, `game_for`) plays it in place of Set the Zero: today that is the hygrometer, and the dome pressure sensor once the pressure controller takes it over. A standard's own calibration keeps Set the Zero, and neither a standard nor a robot's calibration ever takes the factor. **What a score is worth:** Good, Fine and Reference leave 0.8, 0.6 and 0.4 of the operator's term in the uncertainty the record states (`DriftingSensor.next_operator_scale`, used once by `GameState.calibrate`), so the record's U is smaller and its TUR a little higher. The as-found reading, the as-left residual, the verdict, the acceptance limit, the TUR refusal, the clean-TUR XP, the interval and the standard's own uncertainty are worked from the plain budget and never change [ASSUMPTION]; each record keeps the plain TUR as `plain_tur`, and the bench names the smaller figures as "U and TUR with your steady hold". A skip and a score under 60 leave the very same farm. The host picks the game from the instrument, so the command is as it was (`CoopSession.PROTOCOL` 16, `SaveGame.VERSION` 1, no new farm field); it cuts a guest's score to 0 to 100 and counts it only at a key moment, and cannot know the game was played (the score is the sender's word, as for Set the Zero; accepted among friends [ASSUMPTION]). A quest step may name `hold_the_reading`; a step must name a bench game its instrument plays by the data or the quest does not load. No quest carries it yet. **Built (mini-game 5, 2026-11-26):** Thread the Spool (`ui/minigames/thread_the_spool.tscn`, `scripts/minigames/thread_the_spool.gd`). The spool sways on a seeded sum of three slow waves; Left and Right move the hand, and the spool lowers for 8 s. The score is how near the slot it stayed over the last 1.5 s. Husbandry slows the sway, to half speed at 99, through the same front-loaded share as the other games. It plays only while a quest step that counts seated spools carries it (`a_clean_line`, from Odalys, offered on a morning with a spool in stock), on the farm screen's relay button, and it can be skipped. The host counts a score only for a player with that step open. A graded score multiplies that seat's own Husbandry XP and lab XP (1.15, 1.3, 1.5) and grades the quest; the spool taken, the lag and the relay are the same at every score, and there is no wear. No save or protocol change. See `docs/decisions.md` (2026-11-26, Thread the Spool). Mini-game 4 is not built.
17. **Dispatch names.** The text fix from §0.2: every OmniSpec string in `data/dialogue_dispatches.json` becomes BNH, with the sender names settled there. It depends on nothing else here and can go first. **Built (2026-11-26):** `megacorp_name` is "Brightwell-Nonesuch Habitats", "Orbital Compliance" is "BNH Compliance", `disp_04` and Bram's greeting say BNH, and every morning dispatch closes with "Warmly, Dispatch." Text only; no id, key or script changed. The bench's title in `ui/cal_bench_ui.tscn` still says "OMNISPEC FORM 88-C": it is outside the dispatch file, so it waits for Ryan (`docs/decisions.md`).

Each PR logs its decisions in `docs/decisions.md` and names its placeholders.

## 10. Ryan's decisions (2026-11-26)

Ryan answered every open question. He took the recommended option each time. These still need logging in `docs/decisions.md` when the first slice lands.

| # | Question | Decision | Where it lands |
|---:|---|---|---|
| 1 | Which farm skills move into the lab level? | Only Instrumentation folds into the lab level. Robotics and Husbandry become personal skills. | §3.3 |
| 2 | Which new personal skills? | Add Agronomy and Earthworks. | §4.1 |
| 3 | How long to level 99 in one skill? | About 150 hours of play. | §2.3 |
| 4 | Lab level and the existing gates? | Both. A thing opens when the lab level is reached and its existing condition is met. | §3.4 |
| 5 | Saves that exist today? | Everything unlocked stays unlocked. XP converts to the new curve. The lab level is credited from the farm's logs. | §2.5 |
| 6 | OmniSpec or BNH? | BNH sends the dispatches. Odalys signs "Warmly, Dispatch". OmniSpec is dropped from the dispatch file. | §0.2, §9 step 17 |
| 7 | Whose progress is a story quest in co-op? | The farm's. Steps are shared, and every player who took part gets the quest point. | §5.1, §8 |
| 8 | Catch-up for friends who play less? | As proposed: the lab level opens the same doors, and XP certificates lift low levels most. No mentor bonus. | §4.4 |
| 9 | How often do bench mini-games come up? | On quest steps, on the first calibration of each instrument type, and when CAREFUL is on. | §7.4 |
| 10 | A poor mini-game try? | It gives the same as skipping. | §7.2 |
| 11 | What are quest points for? | They gate later episodes and earn keepsakes. No power. | §5.6 |

Still open after these answers:

- Every number. The curve's base and growth, the ×5, the tier multipliers, every level in the unlock tables, every reward and every mini-game figure are [PLACEHOLDER].
- The assumptions in §11.
- Decision 3 sets the total (about 150 hours). The XP numbers do not reach it yet; §2.3 says by how much and what must change. The lab level has the same gap (§3.2.1).
- Sender names under BNH (§0.2), whose quest points count for a farm-scope gate (§5.6), and the provisional way through a lab gate (§3.2.1) are my assumptions.
- Decision 7 says "every player who took part". [ASSUMPTION] A player took part if they were on the farm when any step was done. A point is paid once per player per quest, on any farm (§8).

## 11. Assumptions in one place

- A new player should level up every few minutes in the first hour (§2.2).
- The full skill effect of today's level 10 becomes the level 99 effect, front-loaded (§2.4).
- Filler lab levels give cosmetic or flavor rewards only (§3.4).
- A personal skill never locks a room, tier or contract (§4.2).
- Total-level milestones are cosmetic (§4.3).
- No farm system waits on a story quest (§1).
- Givers speak through the phone in the first slice; there is no talk-to-NPC system (§5.2).
- Rewards are the same on every mini-game difficulty (§7.5).
- The host trusts the guest's mini-game score after clamping it (§7.6).
- There is no rover repair action today (§7.1).
- The contract discount does not bypass the Tier 3 gate in today's code (§3.4). Not confirmed in `buy_standard()`.
- BNH keeps the dispatch department names (§0.2).
- For a farm-scope quest-point gate, the highest count among players present is used (§5.6).
- A farm short of a lab level can open a row early through its lab quest (§3.2.1).
- Names from `story.md` marked "(proposed)" there are still proposed here.
