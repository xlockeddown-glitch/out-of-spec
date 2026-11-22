# Design decisions

Short log of calls that shape code and data. Newest first.

## 2026-11-22: Story path ("The Silk Standard")

Four models drafted a story arc from the same brief without seeing each other's drafts (Claude Opus, Claude Sonnet, Fable, Gemini Hydrogen; GPT skipped under the usage limit to 2026-11-24). The drafts, the brief and the comparison are in [`story/`](story/). Ryan picked one fork at a time over six rounds. The merged story is [`story/story.md`](story/story.md).

Ryan chose:

- **Title:** *The Silk Standard*.
- **Why you are on Mars:** fine-print indenture. A recruitment drive's small print turned your certification into a five-year colony metrology contract (Gemini draft).
- **Corporation:** Brightwell-Nonesuch Habitats (BNH), "Every Sticker Counts" (Sonnet draft).
- **Manager:** a former bench metrologist promoted to orbital dispatch. She rides down in secret the night before the first failing audit, fixes the bench and leaves a mug ring; she never mentions it (Fable draft).
- **Rival rogue lab:** BNH buys Chet's outfit and runs it as a corporate lab that skips calibrations (Fable and Opus drafts).
- **Act III crisis:** a shutdown deadline. BNH will close the colony unless the lab passes the OIRM master audit (Gemini draft).
- **Lin's spider fear:** the greenhouse incident. A hygrometer read fine while a sealed greenhouse dried out, and the conservatory's Curlyhairs came through the vents looking for moisture. Her arc is learning it was the hygrometer (Fable draft).
- **Kestrel:** the contractor before you. She refused to sign off the greenhouse sensors, was overruled, took the blame and lost her certification (Fable draft). Her arc ends with her selling your slings off-world.
- **Off-planet harvest:** proves Mars can export something real.
- **Robot helper:** Jig-1 to Jig-3, then the humanoid Sora-7 (Gemini draft). When Sora-7 asks for its own OIRM credential, the player chooses; either way it never calibrates itself.
- **OIRM auditors:** CLADEUS, GEMINID, CHATTERLY-PT and SPACEFLUX-SI (Sonnet draft).
- **Old Orin:** signed the colony's site survey with an overdue instrument, so the colony sits in the wrong place; the beacons are his penance (Fable draft).
- **Vance:** once a real inspector, he defies BNH by following OIRM rules exactly (Fable draft).
- **Chet, after his lab collapses:** a humbler errand runner, still guessing by eye (Gemini draft).
- **Way back from rogue:** the Long Recal, a multi-day recalibration and a hard audit with no grace, rewarded with a "Returned to Spec" stamp (Opus draft).
- **No band above ACCREDITED.**
- **More tarantulas, throughout.** Ryan rejected every proposed ending set: "not enough tarantula incorporation in general". He then chose:
  - each act's key unlock needs a new morph's silk;
  - the intrinsic standard is made of silk;
  - spiders go off-planet: the off-planet site needs a spider colony to keep its instruments in tolerance.
- **Endings:**
  - **Main:** silk ships first. The first Mars export that passes OIRM is certified tarantula silk, measured against the silk intrinsic standard, with the crops on the same rocket.
  - **Rogue:** the spiders run the dome.
  - **Ultimate breed:** a morph with every silk trait, bred by crossing all five alien morphs. Its climate band is the tightest in the game, so only a fully calibrated dome can hold it.
  - **Breeder:** you let metrology slide and become Mars's tarantula breeder.
  - Not kept: the specialist ending and a separate "Returned to Spec" ending.

Agent's notes (flagged for Ryan, not his words):

- Names the agent filled in from the drafts to match Ryan's picks, all open to change:
  - the manager is **Odalys Brandt** (Fable's name for the option he chose);
  - the shutdown plan is **Project Sunsetting** (Gemini);
  - Chet's BNH lab is **Certainty Plus** (Fable);
  - the remote link is **the Gossamer link**, whose antenna needs Silk-Spinner silk (Fable, and fits the morph-per-act rule);
  - the off-planet site is a robot-and-spider greenhouse on Phobos, **the Larder** (Fable);
  - the colony is **Pavonis Shelf Station**.
- Which morph unlocks which act, which silk the intrinsic standard uses, and the ultimate breed's name are the agent's proposals in `story.md`, marked (proposed).
- The indenture premise is darker than the canon tone. `story.md` plays it as fine-print comedy, not hardship.
- The specialist path stays as gameplay (Ryan's earlier call); only its separate ending was dropped.

## 2026-11-22: Art requests favor what the game will use

- Art requests to Gemini Neon should be for things we already know the game will use, such as the test equipment and the companies (Ryan). The agent reads this as also covering the canon characters, and as coming before open-ended props. The process is in [`workflow.md` §4](workflow.md#4-ryans-art-uploads).

## 2026-11-22: Milestone 3 plan and Tier 0 names

- **Split milestone 3 in two** (Ryan). M3a: the five new sensors plus Tier 1 (Bram sells the field meter and the reference gauge after the first clean audit). M3b: the Tier 2 and 3 instruments, Kestrel's uncertified standards and their gates.
- **Numbers:** the agent proposes realistic MPEs, drift rates, intervals and prices, each marked `[PLACEHOLDER]` and listed in the PR for Ryan to tune (Ryan: "I propose, you tune"; "realistic" and the tags follow spec §1.3).
- **After M3:** straight on to M4 (skills) and M5 (robots), as in the build order (Ryan).
- **Tier 0 names** (Ryan, after asking Fable, Sonnet and Haiku): the rotary table is the **Pavonis Indexworks PX-1**, the humidity generator chamber the **Meridiani Dewpoint MD-2P**. No trademark search has been run. Dropped in moderation: "Okafor/Okonkwo & Lindqvist" (echoes the shortlist's Okafor & Lindqvist), "Noctis" (consumer brands use it), and generic words likely in use (Dewline, Frostpoint, Truegrade).

## 2026-11-22: Standard workflow

- Questions to Ryan are multiple choice with a write-in (Ryan).
- Design questions offer "Ask other models first": 2 to 4 other models get the same brief, the asking agent moderates their answers and comes back with updated or new choices (Ryan).
- Send a screenshot now and then when something visible changes, and keep the roadmap questions coming (Ryan). Sending them after each milestone merges is the agents' convention.
- Ryan's art packs are inspiration and style reference; use them where they fit and cite them when asking for new visuals (Ryan).
- Agent conventions written down with it (not Ryan's calls): 2 to 4 options per question with the recommendation first, never committing to `main` directly, and merging with `gh pr merge --merge --delete-branch`.
- The process lives in `docs/workflow.md`.

## 2026-11-22: Pack 3 models (spider, wilting, irrigation)

Ryan's calls on the three Pack 3 models:

- **Spider:** `live_tarantula.glb` replaces `curlyhair.glb` in the terrarium. The pre-molt dim and squash carry over.
- **Wilting:** `crop_stage_wilted` means the crop is over-watered. The mechanic (what counts as too wet, and whether it recovers) is not designed yet.
- **Irrigation junction:** art only for now. Where it goes and how big it is are decided when an irrigation milestone is planned.

## 2026-11-22: Co-op is the goal; build so it can be added

Ryan wants players to share the game: co-op at least, and more players later if it works. His calls:

- **Players:** 2 to 4 share one farm and dome, and split the work (field, bench, comms).
- **Connection:** online. One player hosts and friends join; no dedicated servers.
- **Timing:** prepare now, build later. Co-op gets its own milestone after robots (milestone 5). Until then, new code follows the co-op-ready rules in the README's [ground rules](../README.md#ground-rules-every-task).

Ryan's answers to the open questions (2026-11-22):

- **Skills (milestone 4): both.** Each player has their own skills, and the farm has shared ones too. Milestone 4 decides which skill goes where.
- **Credits:** one shared farm wallet. Vance fines the farm, OIRM bills the farm, and everyone spends from the same pot.
- **Rovers:** the farm starts with one shared rover and can buy more as it grows. Each rover's steering sensor is its own instrument to keep calibrated.
- **Save:** the farm lives in the host's save and exists only while the host plays. A guest's personal skills travel with the guest (where and how they are stored is decided in milestone 4).
- **Time:** the day ends only when every player is in bed. Waiting out time (for example at the bench) works only in solo play.

Still open, for the co-op milestone: there is no bed or sleep yet (today `GameClock` rolls the day over at 06:00 on its own), so what happens at 06:00 when someone is still up is not decided; a bench calibration jumps the shared clock today (`calibrate_at_bench`), and how it costs time in co-op is not decided; and who can pause in co-op is not decided.

## 2026-11-22: PR checks, second review and merging

- A PR stays a draft until Godot shows 0 errors and 0 warnings, the headless tests pass, and `python tools/check_sp811.py` reports 0 problems (Ryan).
- Every merge needs a second review from a different model than the one that wrote the work (Ryan).
- An agent may merge without asking Ryan once the PR is second-reviewed, its findings are resolved and the checks pass. If unsure (a design call, an open question for Ryan, reviewers disagreeing), ask Ryan first (Ryan).

## 2026-11-21: Week 4 scope

- Voxel models: Neon concept sheets first, then MagicaVoxel. Meanwhile greybox stays, behind `ModelSlot` swap points (`assets/voxels/README.md` lists file names).
- Bram trades wide treads for 6 crystal ore (art bible / his dialogue). Treads halve usage (per-metre) steering drift, not the daily drift.
- Crystal ore: 8 shallow cyan quartz fissures on the Terracotta Plateau around the plot; Space drills one in reach (else tills). Each regrows the next morning (placeholder).
- Lighting: glow on both scenes; cyan uplink beam from the rover antenna toward the relay (red when LOS is blocked); amber work light in Bram's bay.

## 2026-11-21: NIST SP 811 for all player-facing text

Follow NIST SP 811 in game as much as possible (Ryan). Rules in `docs/sp811.md`, formatter `SP811`, check `tools/check_sp811.py`. First pass fixed `%RH` labels, missing spaces before `%`, `x` for multiplication, hyphen minus signs, and comma digit grouping in dispatch text.

## 2026-11-21: Calibration intervals and audit rules (after Fable's Week 3 review)

- Overdue is a violation: an instrument past its cal due day at audit (including never calibrated) is fined `overdue_credits` (50, placeholder) whatever its reading.
- Interval adjustment on every calibration: as-found out of tolerance shortens the interval (sooner next cal); an on-time pass lengthens it; a late pass keeps it. `calibration_interval` in `sensor_drift_config.json` (initial 5 d, min 2, max 15, ±2 d; placeholders).
- Start state: steering due day 5; the hygrometer's sticker already expired (due day 0).
- Repeat-offence counts reset after a fully clean audit.
- One-time grace (Ryan): the first audit that would fine you is a warning instead. Your manager recalibrates the violating instruments before Vance gets in (calibration records say "Manager"). No fine, no offence counted, offences not cleared.
- The phone's remote ZERO STEERING counts as a calibration (same path as the bench).

## 2026-11-21: Two art bibles merged per area (see `docs/canon.md`)

- Alien morphs: Worldbuilding bible set (Cobalt Sentinel, Terracotta Knee, Crystal Weaver, Orbital Silk-Spinner, Basalt Thermal-Vent) replaces the World Expansion set. Their °C / %RH tolerances come from the bible; ideal set points stay `null`. The Static Mop / Prism Ankles flavor notes went with the old morphs.
- Mining biomes: World Expansion tiers stay (Terracotta Plateau, Basalt Thermal Tunnels, Bioluminescent Depths).
- Cast: Worldbuilding cast (Inspector Vance as MegaCorp auditor every 5th morning, Chet as rival, Old Orin), keeping AUD-1T as Vance's drone. Ollie cut.
- Species lag bonus stacks on the spool (Ryan, 2026-11-21), multiplicatively: (1 − spool%) × (1 − species%). Curlyhair spool = × 0.38; Cobalt Sentinel = × 0.30. Implemented in `GameState.get_relay_lag_multiplier()`.

## 2026-11-21: Neon status palette

From the Gemini planning thread (`ui_color_hex` in its sensor config): in band `#38E1C6`, guard band `#F5A623`, out of tolerance `#FF5A5F`. Defined once in `DriftingSensor` and used by the phone HUD, bench meters, and terrarium LED. Cyan telemetry glow outside, warm amber lamps inside.

Gemini's richer `sensor_drift_config` (thermometer, relay-azimuth lag coupling, jitter, calibration time, yield multipliers, audit severity tiers) is NOT merged; it uses a 70% guard band and different rates. Candidate source for Week 3.

## 2026-11-21: Week 2 numbers (board vs data)

Resolving conflicts between `docs/design/out_of_spec_week_2_dome_calibration_closed_loop_visual_board.html` and the data files:

- Guard band: keep the data file. Green is |error| <= 80% of MPE (board said 70%).
- MPE: use the board. Hygrometer ±5.0 %RH, rover steering ±4.0 deg (data had ±2.0 / ±0.80).
- Dome starter tarantula: Curlyhair (real), not the board's Cobalt Reference.
- Silk spool payoff: one spool cuts rover uplink lag ~60% (`data/items.json`), not the species `lag_reduction_pct`. Species values may stack on top later.
- As-left residual after zeroing: up to ±0.2 in the instrument's unit (board).
- Playtest tuning in `GameState.gd`: molt takes 20 s while the hygrometer is within MPE; hygrometer starts at 1.12 x MPE (out of tolerance) so the first dome visit has something to calibrate.
- Relay spool install is a phone HUD button: the relay sits ~100 m off-screen for low-angle LOS, so it can't be clicked from the farm camera.

## 2026-11-21: Tarantula roster

- Real species are the early game: Curlyhair, Mexican Redknee, Brazilian Black (`tier: "real"`).
- Art-bible morphs are alien unlocks: Cobalt Reference, Ember-Knee, Verdant Trace, Quartz-Spinner, Dune-Ochre (`tier: "alien"`, `source: "art_bible"`).
- Values the art bible doesn't define (humidity tolerance, molt days, silk grade, silk yield, lag reduction) are `null` until designed. Code must treat `null` as "not set", not 0.
- Static Mop and Prism Ankles (fictional, from the original JSON) were cut on 2026-11-21 (Neon's suggestion, Ryan approved). Their flavor folds into Dune-Ochre (ion storms / static) and Quartz-Spinner (optical refraction); their numbers were not carried over. Roster is 3 real + 5 alien, 1:1 with the art bible.

## 2026-11-21: Instrument drift has two sources

- Every instrument drifts with in-game time (`daily_drift_rate`, per day, from `GameClock`).
- Instruments that wear with use also drift per usage unit (`usage_drift_rate`). Rover steering: 0.03 deg per metre driven (placeholder, tune by feel).
- Both push the same direction. Zeroing resets to 0, logs as-found, and re-rolls the direction.
- Status: |error| / MPE <= `guardband.green` ratio (0.80) is in tolerance; <= 1.0 is guard band; > 1.0 is out of spec.
- Implemented once in `scripts/metrology/drifting_sensor.gd` (`DriftingSensor`, renamed from `DriftModel`) so the rover, hygrometers, and the relay dish share it. Instances live in `GameState`.

## Voxel models (Week 4)

- Concept sheets came from two blind model answers (A 8/10, B 6/10), merged in `docs/art/voxel_models.md`.
- Voxel size by class: 0.1 m props and vehicles, 0.2 m characters and set pieces, 0.5 m distant landmark.
- Only the semantic colors glow; red only where something is out of tolerance. State LEDs stay game-driven.
- Glowing parts are separate MagicaVoxel objects named `emit_*`.
- Tractor hull `#C85A2A` (confirmed by Ryan).
- First-pass models are generated by `tools/voxgen/build_models.py` (glb for the game, vox for hand refinement in MagicaVoxel).

## 2026-11-22: Calibration core (equipment milestone 1)

Ryan's answers to the equipment, skills and robots design (`docs/design/equipment_skills_robots.md` §6) are logged there. What milestone 1 put in code and data:

- Instruments live in one registry, `GameState.sensors`, built from `sensor_drift_config/instruments`. Each entry has a `role`: `unit` (audited, calibrated at the bench) or `standard` (a reference).
- Two Tier 0 standards: a rotary table (calibrates steering and the dish azimuth) and a humidity generator chamber (calibrates the hygrometer). Names, specs, drift and intervals are placeholders. (Names superseded by "Milestone 3 plan and Tier 0 names", 2026-11-22.)
- Uncertainty: U = k × √(u_spec² + u_cert² + u_res² + u_op² + u_robot²), k = 2. A spec at 95 % confidence is divided by 2; one with no stated confidence is rectangular (÷ √3). Resolution is half a digit, rectangular. u_op and u_robot are 0 until skills and robots.
- TUR = MPE / U. Under 2:1 the bench refuses; 4:1 is the clean mark. Acceptance limit A = √(MPE² − U²).
- |as-found| ≤ A passes; A < |as-found| ≤ MPE is indeterminate (an on-time pass that does not lengthen the interval); over the MPE fails.
- The standard's own error is hidden and carried: the bench sees e_unit − e_standard, and after adjustment the unit's true error is e_standard + residual.
- Bench calibration takes game time (`bench_minutes` per unit, placeholder); a refused calibration takes none.
- The relay dish azimuth is now a registered unit: drifts, audited, calibrated at the bench.
- (Superseded by the 2026-11-22 answers below.) The remote ZERO STEERING has no standard (untraceable, judged against the MPE, no bench time). It still adjusts the encoder, but it no longer counts as a calibration: the interval, due day and last calibration day stay unchanged, so only the bench clears an overdue steering encoder. This replaces the 2026-11 rule above that the remote zero counts as a calibration. The manager's one-time grace calibration uses the standard but takes no bench time. Standards drift but are not audited until OIRM certificates (milestone 2).

## 2026-11-22: Ryan's answers on the calibration core (PR #28)

- Remote ZERO STEERING stays, untraceable: it adjusts the encoder but is not a calibration. Only the bench clears an overdue encoder.
- The manager's one-time grace calibration stays instant (no bench time).
- The relay dish azimuth stays an audited unit.
- Displays show the observed error, what the bench last measured, not the true error, so a bad standard can fool the player. This covers the field phone HUD, the cab LED, the dome hygrometer reading and band, and the terrarium LED. The farm's "steering exceeds MPE" alert follows the HUD, so it is observed too. The remote ZERO STEERING zeroes the encoder against its own reading, so its as-found is the observed error and it keeps the bench offset; it cannot expose a bad standard. Audits (Vance), the molt pause, the heat lamp and the steering pull keep the true error. The molt-pause text says "humidity out of range" rather than blaming the hygrometer, so it does not contradict the display.

## 2026-11-22: Milestone 2, OIRM and traceability (assumptions to confirm)

Built per §1.6, §1.7 and §5 item 2 of `docs/design/equipment_skills_robots.md`. Everything below that the spec doesn't fix is a placeholder or an assumption.

- **Founding certificates.** Each Tier 0 standard starts with a day-0 "founding stock" OIRM certificate, due at the end of its first interval (day 30). It has no as-found on file.
- **Courier.** (Superseded by Ryan's answers below: a courier now runs on other days too.) A standard can be sent only while the drop pod is on the pad (audit day, until departure). It comes back on the next audit pod, gets certified before Vance inspects, and its interval restarts from that day. OIRM does not change the interval.
- **Fee.** The OIRM fee is 150 CR (placeholder, `oirm/fee_credits`).
- **While a standard is away,** the bench refuses every calibration that needs it. The remote zero still works, untraceable.
- **Overdue standard.** A bench calibration against an overdue standard adjusts the unit but is not traceable. It does not reschedule the unit, so it can't clear an overdue.
- **Standards are audited for a lapsed certificate only,** except while at OIRM. Vance has no reference that could see a standard's hidden error, so an out-of-tolerance standard shows up only when OIRM measures it (§1.6). The manager's one-time grace waives a standard's violation without calibrating it.
- **Recall.** When OIRM finds a standard out of tolerance, each traceable calibration made with it since its previous certificate is re-judged with the standard's as-found error taken out. Only a calibration whose pass / indeterminate / fail result changes becomes suspect (the impact threshold). The as-found error at return stands in for the error on each calibration day; drift between the two is ignored.
- **Cascade.** A suspect calibration of a standard recalls that standard's own later calibrations. No standard is calibrated against another in the data yet, so this path is tested with hand-built records only.
- **Suspect units.** A unit becomes suspect only if the recalled calibration is still its latest traceable one. The recall is announced on the audit pod; that audit does not fine it. From the next audit on, a suspect unit is a violation with a 75 CR fine (placeholder, `compliance_fine/suspect_cal_credits`) until a traceable recalibration clears it.
- **Broken chain after an adjustment.** An untraceable adjustment (the remote zero, or a bench zero against an overdue standard) after the last traceable calibration breaks the unit's chain until the next traceable calibration.
- **Downtime.** (Superseded by Ryan's answers below: such a unit is now excused once.) The standard comes back at the start of the audit, so a unit that falls due while its standard is away is overdue at that audit. Send standards when the units are freshly calibrated.
- **Tuning.** (Superseded by Ryan's answers below: about 60 days now.) At the current drift rates a standard took about 100 days to leave tolerance, so a recall can't happen in normal play yet. The rates are placeholders.
- **Chains.** The bench shows each instrument's chain (unit ← standard (certificate, day) ← OIRM, or where it breaks). The audit posts one chain line per unit on the phone.
- **Tier 1 gate.** The first audit with zero violations unlocks Tier 1 (a grace warning is not clean). Nothing is for sale yet; the flag and the clean-audit streak are stored for milestone 3.

## 2026-11-22: Ryan's answers on milestone 2 (PR #30)

Kept as built:

- The OIRM fee stays 150 CR.
- While a standard is away, the bench refuses calibrations that need it; the remote zero still works, untraceable.
- Against an overdue standard the unit is adjusted, not traceable, and stays overdue.
- A record is suspect only if its pass / indeterminate / fail result flips.
- Suspect fine: none at the audit that announces the recall, then 75 CR from the next audit until a traceable recalibration.
- Standards are audited for a lapsed certificate only.
- The manager's grace can waive a standard's violation without certifying it.
- Tier 1 unlocks at the first audit with zero violations; a grace warning doesn't count.

Changed:

- **Courier on other days.** On audit day, with the drop pod on the pad, a standard still rides the pod for 150 CR and comes back on the next audit pod. On any other day (including audit day after the pod leaves at 18:00) it goes by courier for the fee plus a 150 CR surcharge, 300 CR in all, and comes back 7 days later. Its interval restarts from the return day. The bench refuses calibrations that need it until then. Surcharge and days are placeholders (`oirm/courier_surcharge_credits`, `oirm/courier_return_days`).
- **Drift pace.** Each standard now drifts from zero to its MPE in about 60 days (`daily_drift_rate` 0.00083 for the rotary table, 0.0083 for the humidity generator, in their error units per day). Still placeholder rates.
- **Downtime.** A unit that falls due while the standard it needs is at OIRM is excused at the first audit where it is overdue: no fine and not a violation. It must be traceably calibrated before the following audit, or it is an ordinary overdue there. Out of tolerance is still a violation.
  - Because a courier trip (7 days) is longer than the audit cadence (5 days), the unit also stays excused at any audit while its standard is still away, and at the audit on the morning the standard comes back. After that it has until the next audit.

Choices made in building these (flagged for Ryan):

- **Excused is not a violation,** so it doesn't block a clean audit or Tier 1 and doesn't add to the repeat-offence count (the parent session's suggestion).
- **"Falls due while away"** means the unit's due day is after the send day and before the return day. A unit due on the day the standard leaves is not excused, since the player could calibrate it that morning before sending; otherwise shipping the standard would buy a free audit. A unit due on the return day isn't excused either, since the standard is back that morning. If a return is ever late, the window runs to the day it actually came back.
- **Courier returns land in the morning,** before that day's audit. A courier return on an audit day is certified before Vance inspects, and that audit doesn't excuse units whose standard is already back by their due day.
- **A unit due shortly before the standard returns** is still excused at its first overdue audit, even if the standard came back a few days before that audit. Example: courier sent day 6, back day 13, unit due day 11, excused at the day 15 audit, must be calibrated by day 20. Another example: sent day 13, back day 20, unit due day 14, excused at the day 15 and day 20 audits, must be calibrated by day 25.
- **Sending while already away** is refused ("Already at OIRM until day N").
- **The route is picked by the pod,** not by the player: with the pod on the pad the button is SEND TO OIRM (150 CR); without it, SEND BY COURIER (300 CR). The bench text gives the courier return day and the next pod day so the player can choose to wait.

## 2026-11-22: Ryan's answers after milestone 3a (PR #42)

Ryan chose:

- **Next up: M3a hooks.** The terrarium thermometer feeds the molt, AUD-1T checks tire pressure, and the tire gauge gets a field calibration spot.
- **Keep the dome at 2.84:1 TUR on purpose.**
- **Buying a standard takes two presses.**
- **Numbers:** "Research real specs to start but playtest and tune for feel from there."

Agent's notes (flagged for Ryan, not his words):

- M3b (Rb-2D, HM-3) and the save system were the other options offered; they come after the hooks unless Ryan says otherwise.
- The dome against the WD-1 is allowed by the bench but never counts as a clean 4:1 calibration; the HB-700 (Tier 3) is what fixes that.
- Two presses means the first press (key or button) shows the price and the second buys. It applies to Bram's Tier 1 standards.
- Research covers the [PLACEHOLDER] MPEs, resolutions, drift rates and the thermometer's 15 °C/V scale, with sources cited in the data notes. Credit and ore prices have no real-world source, so they are set from game balance and tuned in playtest.

## 2026-11-22: Ryan's answers on the researched M3a numbers

Ryan chose:

- **Use the researched values** GPT sourced from real instrument classes (Fluke 87V MAX class for the FM-3, WIKA CPG1500 class for the WD-1, an RTD transmitter scaled 0 °C to 50 °C over 0 V to 10 V for the thermometer, so 5 °C/V). TURs: thermometer 4.80:1, dome 3.11:1 (still under 4:1 on purpose), tire 8.24:1. They stay [PLACEHOLDER] until playtest.
- **Tier 1 drift pace "in between":** the FM-3 and WD-1 reach their MPE in about 120 days, between Tier 0's 60 days and the real one-to-two-year rates.

Agent's notes (flagged for Ryan, not his words):

- The pace question covered standards only, so the M3a units keep their game pace (the same days to reach the MPE as before, scaled to the new MPEs: tire about 25 days, dome about 17, thermometer about 25). The data notes say the drift is a game pace and compare it with what each datasheet specifies.
- The tire gauge's 0.69 kPa resolution is a 0.1 psi step; its display still shows one decimal in kPa.

## 2026-11-22: Ryan's answers on the M3a hooks

Ryan chose:

- **Thermometer: "Like humidity".** The molt pauses while the terrarium thermometer's true error is past its MPE (±0.5 °C), the same as the hygrometer. The pause text names the cause: "temperature out of range", "humidity out of range", or both.
- **AUD-1T tires: "AUD-1T's own line".** A petty fine on AUD-1T's own phone line when the tires are out of spec, on top of Vance's line for the gauge.
- **Field calibration spot: "Pad by the airlock".** A pad by the dome airlock. Park the rover on it and press E to calibrate the tire gauge against the WD-1.

Agent's notes (flagged for Ryan, not his words):

- **Thermometer only while in service.** It holds the molt only once the FM-3 is on the colony; before that the player can't calibrate it, so it can't block the molt. The dome panel shows the TEMPERATURE reading and band only while it is in service, and the heat lamp turns harsh for either cause.
- **Tire limit and fine are [PLACEHOLDER], not researched:** 6.9 kPa (1 psi, about 2 × the gauge MPE) and 20 CR, in `compliance_fine/aud1t_tire_*`. With the limit above the MPE, a tire fine always comes with an out-of-tolerance gauge line. No repeat surcharge.
- **Tires follow the gauge's current true error** at audit time: they were filled to what the gauge reads, so they sit off the set point by minus its error. There is no separate fill event or tire state yet.
- **Pad details:** the field survey tripod stands by the pad as set dressing, the rover must be stopped, and AUD-1T's line posts last before the verdict so the phone's short log keeps it. AUD-1T reports the offset to 0.1 kPa and fines on that reported value, with the limit rounded the same way [PLACEHOLDER], so the line never shows a fine at the limit.
- **AUD-1T checks the tires only while the tire gauge is in service** (WD-1 owned). It posts a line every audit, compliant or not.
- **The one-time grace waives the tire fine too;** the manager's line adds "reset the rover tires".
- **The pad uses the same calibration as the bench,** including the 20 min of bench time. The bench in the dome can still calibrate the tire gauge.
- **Two presses to buy** (from the earlier answer): the first press shows "CONFIRM: BUY" and the price; leaving or re-entering the bay, or trading for treads, clears it; another standard's key arms that one instead.

## 2026-11-22: Ryan's ideas on credibility, contracts and the OIRM audit team

Ryan's ideas (his message, lightly condensed):

- The lab runs more efficiently and makes more money when it passes audits and keeps things from going overdue, or at least from being used overdue.
- That builds **credibility**, which leads to **contracts** that offer discounted high-end or even intrinsic calibration standards to use as primary standards.
- With those standards and new skills, the player can eventually harvest crops **off planet**, using remote-controlled AI rockets and robots.
- The master auditors at OIRM are a **robot audit team** of SI-powered agents "from Claude, Gemini, SpaceXSI and ChatGPT".

Ryan chose:

- **Auditor names: "Fictional nods".** The auditors get original names that wink at the real ones instead of the real product names.
- **Roadmap: "Credibility first".** The next milestone after the M3a hooks is a credibility score fed by audits and on-time calibrations, plus a first contract offer. Rockets, off-planet harvest and the OIRM audit team come later.

Agent's notes (flagged for Ryan, not his words):

- "Used overdue" suggests credibility drops more for using an overdue instrument than for merely letting it lapse. Today audit lines record what is overdue at inspection and calibration records flag an overdue standard used for an adjustment; scoring other use of overdue instruments would need new tracking. Weights are [PLACEHOLDER].
- An intrinsic standard takes its value from an inherent, reproducible physical property (VIM 5.10), for example a Josephson voltage standard or a cesium fountain primary frequency standard; it typically undergoes periodic verification. A game-design proposal: an intrinsic standard could end a chain at the lab instead of at OIRM. Which quantities get one is open.
- The shape of a contract and the credibility thresholds need Ryan's answers before the credibility milestone is built. The individual auditor names can wait for the OIRM milestone.

## 2026-11-22: Credibility milestone answers

### Ryan chose

- **Score feeds: "Audits + overdue".** A passed audit raises credibility and a failed one lowers it. Each day an instrument sits overdue costs a little, and using an overdue standard for an adjustment costs more.
- **First contract: "Discounted standard".** At the first threshold, OIRM offers a lower-uncertainty reference standard at a discount, in return for a run of on-time calibrations.
- **Display: "Rating band".** The phone shows a named band, with the next threshold hinted.

### Agent's notes (flagged for Ryan, not his words)

- Band names, point values, thresholds, the discount and the length of the on-time run are all [PLACEHOLDER] until Ryan sets them.
- Starting values (all in `data/economy.json`, all [PLACEHOLDER]): start at 10 of 100 points; bands PROVISIONAL (0), TRUSTED (30), ACCREDITED (60); a clean audit +10, a grace-period warning −5, a failed audit −10; −1 per overdue instrument per day; −5 for a calibration against an overdue standard.
- The contract standard is the HB-700 pressure controller (Tier 3 in design doc section 1.4 #6). It fixes the dome gauge's 3.11:1 TUR against the WD-1. Once bought it takes over the dome gauge, which keeps its due day if it was already in service against the WD-1 (otherwise it goes into service fresh, like any new unit); the tire gauge stays on the WD-1.
- The offer comes at TRUSTED: 5 on-time, traceable calibrations in a row, then Bram sells the HB-700 at 50 % off (credits only; the ore cost stays). A late or untraceable calibration restarts the run. A repeat calibration before half its interval has passed since its last traceable calibration neither counts nor restarts it (an untraceable adjustment in between does not reset that clock). The Manager's calibrations don't count toward it.
- The overdue charge skips standards away at OIRM, and units that fell due while their standard was away, until the first audit after the standard comes back (the same grace Vance gives at audit).
- The phone shows the band under the clock, e.g. "CRED: PROVISIONAL, 33 % to TRUSTED", and the open contract on a second line ("OIRM CONTRACT: 2 of 5 on time", then "OIRM CONTRACT DONE: HB-700 at Bram's").
- **Known economy limit:** the discounted HB-700 costs 800 CR, more than the 500 CR start, and this build has no income (every credit change is a fine, fee or purchase). So the contract can be earned but not yet redeemed in a normal playthrough. It needs the crop/harvest income or an economy decision from Ryan; even Tier 1 standards are tight today.
- There is no save system yet, so credibility and the contract reset with a new game.
