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
  - the colony is **Pavonis Shelf Station** (Fable).
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

## 2026-11-22: Ryan's answers after the credibility milestone (PR #47)

### Ryan chose

- **Income: "Both".** Crop sales first, then paid calibration jobs unlocked at TRUSTED.
- **Next milestone: "Income loop".** Build the income so the OIRM contract can be redeemed.
- **Moisture: "New soil probe".** A soil-moisture probe that drifts and needs calibration like the other units; a drifted probe means off-spec crops. Its specs are [PLACEHOLDER].
- **Buyer: "Lin".** Lin, the botanist and substrate dealer, appears in this milestone and buys crops.
- **Watering: "Auto-irrigation".** Set a target moisture per plot, and irrigation holds it using the probe's reading.

### Agent's notes on the crop build (flagged for Ryan, not his words)

- The soil probe's numbers are [PLACEHOLDER]: drift 0.15 %/day (percentage points of volumetric water content), MPE 3.0 %, as-left residual 0.2 %, 40 minutes on the bench.
- It is calibrated against a "Gravimetric Soil Reference Kit" (weigh, oven-dry, reweigh), a Tier 0 standard owned from the start. The kit is the agent's proposal, since the probe needed a standard; its numbers are [PLACEHOLDER] too.
- How the probe drives the crop: irrigation holds the probe's *reading* at the set point, so the soil really sits at set point minus the probe's error. The player can calibrate the probe, or offset a plot's set point by the known error ([ and ] keys, 1 % steps).
- A harvest is off spec if the soil left the crop's tolerance band on any growing day. Lin then pays the base price less the crop's out-of-spec penalty (from data/crops.json). The any-day rule is the agent's choice; a share-of-days rule would be gentler.
- Seeds cost 25 % of the crop's base price ([PLACEHOLDER], data/economy.json). C changes the seed; using the rover on tilled soil plants, reports, or harvests.
- Lin buys the whole harvest bin at Bram's bay (L key) until she has a place of her own.
- Crops show as the existing crop_stage voxel models: stages 0 to 2 while growing, stage 3 when ready, and the wilted model once the soil has left its band. That wilting is a visible clue that the probe has drifted; hiding it would make the drift harder to spot.
- After GPT's first review: the off-spec check now catches soil that leaves the band at any time between mornings (when the probe drifts or is calibrated, or a set point changes), not only at the morning check. Soil exactly on a band edge counts as in band.
- Growth counts time since planting: a morning counts once at least half a day has passed, so a crop planted just before 06:00 waits for the next morning. That half-day rule is the agent's choice.
- If fines leave the player without enough credits for a seed, Lin fronts it and takes its cost out of that crop's sale. That keeps fines from locking the player out of farming. The rule is the agent's choice.
- Open balance question for Ryan (from GPT's second review): a player deep in debt with every standard overdue pays fines faster than crops can earn, and OIRM wants credits up front. The paid calibration jobs in the next PR add income; a fine cap or an OIRM payment plan could also help.
- A clock jump across 06:00 (such as a bench calibration) now splits at the morning, so growth and drift are judged as they stood at 06:00.
- With no crop under the rover, `[` and `]` set an offset that new plantings start with, so a player who knows the probe's error can correct for it before planting (GPT's third review). The offset is the agent's choice.
- Soil out of band at 06:00 counts against the new day as well as the old one.
- The seed chosen when Space is sent is the one planted, even if C changes it while the command is on its way up the link.
- Biscuit Reed (±18 %), Dust Turnip (±12 %) and Bubble Pods (±10 %) tolerate even the probe's worst drift (capped at ±9 %), so a probe left alone only spoils Suncatch Squash (±8 %) and Lensberry (±5 %). The agent kept that on purpose: the starter crops are forgiving, and the drift starts to matter as the player moves to pricier crops. Ryan may want the bands tightened instead.
- Paid calibration jobs at TRUSTED come in the next PR.

## 2026-11-22: Ryan's idea, a calibration robot helper

### Ryan said

- A robot helper that gets taught calibrations and improves over time (levels, maybe tied to a skill), until it can do harder calibrations and assist in the lab. That frees the player for other things as they master calibrations.
- Different types of robots do different jobs at first. As build and skill technology unlocks, more human-like robots arrive that automate a wider range of skills.

### Agent's notes (flagged for Ryan, not his words)

- Not scheduled yet; to be offered as a roadmap option after the income milestone. docs/design/equipment_skills_robots.md already sketches robots and skills, and the bench already records calibrations by "the Manager", which don't count toward OIRM contracts; the helper would need the same rule decided.

## 2026-11-22: Ryan's ideas, an automation path and a rogue lab

### Ryan said

- An automation path for most things: manual control at first, then automation with a human in the loop, then automation run remotely from a control panel through a system like Starlink or SI.
- Let a lab "go rogue" and skip calibrations. That makes the game wonky: weird things happen, things go right when you press left, the wrong things happen. It shouldn't just be miserable; it should be funny and goofy, with some misery.

### Agent's notes (flagged for Ryan, not his words)

- Not scheduled yet; both go on the roadmap options after the income milestone, next to the robot helper (the automation path fits it: manual, then a taught helper, then remote).
- The rogue lab fits the drift already in the game: overdue instruments could cause comic glitches scaled by how far out of tolerance they are (swapped controls, odd phone messages), on top of the credibility cost. Which glitches, and how strong, are Ryan's call.

## 2026-11-22: Ryan's idea, specializing instead of calibrating everything

### Ryan said

- You don't need to calibrate every parameter to succeed. A single route is a harder path than being a jack of all trades, but it works: for example, serving customers only for pressure and torque, or electrical only.
- You still manage what you use to keep your own site going, but you worry much less about all the standards and everything else.
- You have to make money in many ways, or be really good at what you do.

### Agent's notes (flagged for Ryan, not his words)

- Not scheduled yet; it shapes the paid calibration jobs coming at TRUSTED. Jobs could be grouped by discipline (pressure, torque, electrical, ...), so a lab that owns only some disciplines' standards can still earn, at higher stakes per job.
- Open questions for Ryan: how a specialist is rewarded (better pay, steadier customers, faster credibility in that discipline), and how the site's own instruments outside the specialty get looked after (an outside cal service, Bram, a robot helper).

## 2026-11-22: Ryan's idea, an upgradeable lab building

### Ryan said

- The lab building is upgradeable, to allow bigger sections or dedicated calibration areas.
- Start with a small lab with one or a few sections. Upgrade to a medium lab, where areas can be made bigger or more separate areas added. Then a large lab, with one really big area or many separate areas, depending on how you specialize.

### Agent's notes (flagged for Ryan, not his words)

- Not scheduled yet. It pairs with the specialization idea: one big area suits a specialist, many small areas suit a jack of all trades.
- The dome interior today is a single room with the calibration bench; sizes, costs and what each area enables (for example, a discipline's jobs need a matching area) are Ryan's call.

## 2026-11-22: Paid calibration jobs, Ryan's answers

### Ryan chose

- Jobs come from a job board on the phone: customers (other domes, rover crews, Lin) post jobs, the player accepts one, calibrates it at the bench and is paid.
- By discipline: a job can only be taken with an owned traceable standard of its discipline.
- Late or untraceable work pays less and costs credibility; a clean, on-time job earns a small bonus.
- TRUSTED gets basic jobs; ACCREDITED adds tighter-tolerance, better-paying ones.

### Agent's notes (flagged for Ryan, not his words)

- Every customer, price, due date, bench time and discipline-to-standard mapping in `data/economy.json` ("jobs") is [PLACEHOLDER]. Temperature jobs use the FM-3 for now because the game has no temperature standard yet.
- Pay cuts multiply: a late and untraceable job pays 50 % of 25 % of the price. Credibility costs add.
- A job not done within 3 days after its due day is cancelled ("took it elsewhere") at a credibility cost, so accepted jobs cannot sit forever. At most 2 jobs active at once.
- Untraceable means the standard used was overdue for calibration. A standard away at OIRM cannot be used at all.
- The board shows 3 offers each morning (built after that morning's audit), rotating through the eligible jobs by day, so the same day always gives the same board (no randomness yet). A job accepted today is not offered again today, even if the lab changes band. A band change during the day rebuilds the board; a lab that drops below a job's band cannot accept it.
- A job can only be accepted while a qualifying standard is here (not away at OIRM) and in date (traceable).
- Lateness is judged when the bench work ends, and the bench refuses work that would end after the customer cancels.
- Calibrating a job takes bench time (30 min to 90 min of game time); there is no as-found reading or adjustment for customer items yet. That could come later if Ryan wants the bench work itself to be played.

## 2026-11-22: Next milestone after paid jobs

### Ryan chose

- Next milestone: the upgradeable lab.
- Automation path: later, after the lab (and robot helper) exist.

### Agent's notes (flagged for Ryan, not his words)

- Paid jobs (PR 49) merged after ten GPT review passes. Lab upgrade sizes, costs and what each area enables still need Ryan's answers before building.

## 2026-11-22: Upgradeable lab, Ryan's answers

### Ryan chose

- An area gives more space. Each new area is the player's choice: more of a discipline the lab already has, or another discipline.
- More space for a discipline the lab already has gives both: more of its jobs in progress at once, and room for bigger items (the biggest, best-paying jobs need a large area).
- The small starting lab covers a few disciplines. Adding more disciplines, or growing one, needs a bigger lab.
- Upgrades cost credits plus crystal ore and take a few days to build.
- Upgrades are chosen and bought at a plan board inside the dome, and the dome visibly changes as it grows.
- The large lab's layout (one big area or many separate areas) can be changed later, at a cost and with some downtime.

### Agent's notes (flagged for Ryan, not his words)

- The automation path stays after this milestone (Ryan, earlier today).
- Every number still to be set (areas per lab size, disciplines in the small lab, costs, build days, rebuild cost and downtime, which jobs count as "big") will be [PLACEHOLDER] in data until Ryan sets it.
- Open question for later: what happens to a discipline whose standard you own but which has no area (today every owned standard can do jobs at the single bench). Proposed: existing saves get the starting lab with areas for the disciplines they already own, so nothing is taken away.

## 2026-11-22: Upgradeable lab, as built

### Agent's notes (flagged for Ryan, not his words)

- Sizes: small lab 3 spaces, medium 5 (600 CR + 4 crystal ore, 2 days), large 8 (1500 CR + 8 crystal ore, 3 days). An area of 1 space is SMALL, 2 MEDIUM, 4 LARGE. All [PLACEHOLDER] in data/economy.json.
- The lab starts small with one space each for angle, humidity and soil moisture (the founding standards), so nothing the player could do before is taken away. Pressure, electrical and temperature jobs now need a space fitted out for them first: grow the lab, or clear a founding space and refit it.
- Each space a discipline has is one of its jobs in progress at once. This replaces the old limit of 2 jobs in progress overall, so the starting lab can run 3 at once (one per discipline).
- Jobs that need a big area: the Dome 1 cabin transducer and the survey theodolite need LARGE; the medbay incubator needs MEDIUM. A large area fits only in the large lab: each lab size caps how big one area can get (small lab 1 space, medium lab 3, large lab no cap), so clearing other areas can't skip a lab size.
- Fitting a free space out is free. Clearing a space (to change the layout) costs 200 CR + 1 crystal ore and the space is down 1 day; it works at any lab size, not just large. A space with a job in progress can't be cleared, and an area can't shrink below the size a job in progress needs.
- One build at a time. The lab's areas keep working while it grows.
- The job board still shows jobs the lab can't take, with the reason, so the player sees what a bigger lab would open up.
- The plan board is on the dome's back wall, right of the airlock. The lab's spaces line the back wall: a cabinet per space, labelled by area; free spaces are bare pads; spaces being built or cleared show amber.

## 2026-11-22: After the lab

### Ryan chose

- Next: groundwork for online co-op.
- Keep every lab rule as built: the starting lab's 3 spaces, free fit-out, clearing at any lab size, pressure, electrical and temperature jobs needing a fitted-out space, and the area cap per lab size.

### Agent's notes (flagged for Ryan, not his words)

- Groundwork goes one PR per README "known exception". First: seeded randomness. The farm has one `world_seed`; morning dispatches, audit footers, Bram's lines and every sensor's drift direction and as-left residual come from it, so a new co-op farm started from the same seed plays out the same. Joining mid-game will also need the generator states and sensor signs, which comes with host save/load. Bram's bay lines draw from the shared generator too; in co-op the host should run them.

## 2026-11-22: Lab pack meter names

### Ryan chose

- Give the two meters "generic ones that fit game theme" instead of real model numbers.

### Agent's notes (flagged for Ryan, not his words)

- The game already names both: the reference meter is the Longscale LS-8.5 Reference Meter (equipment design doc) and the handheld is the Arsia Fieldworks FM-3 Field Meter (the `field_meter_dc` standard). The models are now `ref_meter_ls85` and `field_meter_fm3`; the voxels are unchanged.

## 2026-11-22: Calibration bench and chamber cart in the dome

### Ryan chose

- Where the calibration bench and the environmental chamber cart stand: "your call".

### Agent's notes (flagged for Ryan, not his words)

- The calibration bench replaces the plain table under the cal station (the dome's right bench). The cal station now sits on its ESD mat at 0.9 m, a little left of center, with the silk tray beside it; the bench click area covers the new bench.
- The chamber cart stands on the floor right of the bench, its door toward the camera. It is set dressing only: it does nothing in play yet.
- Both are kept off the back wall, so the lab spaces there are unchanged. The two meters are not placed yet.

## 2026-11-22: Field meter on the calibration bench

### Ryan chose

- Put the field meter on the calibration bench next: "Yes, place it".

### Agent's notes (flagged for Ryan, not his words)

- The FM-3 lies face up on the mat at the bench's rear right, behind the silk tray, turned a little off square. It is at true size (0.15 m × 0.25 m), so it reads as a small yellow shape from the default camera. Set dressing only; the reference meter is not placed yet.

## 2026-11-22: Reference meter on the chamber cart

### Ryan chose

- "Yes, place it" (the LS-8.5 reference meter).

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the offer to put the LS-8.5 reference meter in the dome next.
- The calibration bench has no free room left (cal station, silk tray and field meter), so the reference meter stands on the chamber cart's lid instead, on the free front strip in front of the lid fittings, its front panel toward the camera. It is at true size (0.4 m × 0.35 m × 0.15 m). Set dressing only; it does nothing in play yet.

## 2026-11-22: Crops in the farm

### Ryan chose

- "Crops in the farm"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next.
- The farm already shows the crop models: since the income milestone, `FarmGrid` stands stage 0 to 2 on a growing cell, stage 3 when it is ready, and the wilted model once the soil leaves its band. A render with all five on one row confirms they sit on the soil and read clearly. No scene change was needed, so this only corrects the docs that still called them unplaced.
- Every crop in `data/crops.json` uses the same sun-pod models. Models per crop are still an open question.

## 2026-11-22: Irrigation junction in the farm

### Ryan chose

- "Irrigation junction"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next.
- The junction stands just outside the plot's front edge, at (−9, 0, 13.2) m, turned so its front faces the camera, as the plot's feeder. It is clear of the drop pod, the fissure and the rover's start. It is at true size (1.2 m × 0.8 m × 1.2 m), which is large for a drip-line valve.
- Set dressing only: no collision and no play yet. The Pack 3 entry said its place and size wait for an irrigation milestone; this places it, but its size in play and what it does are still left for that milestone.

## 2026-11-22: Water cistern in the farm

### Ryan chose

- "Water cistern"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next.
- The cistern stands beside the irrigation junction, at (−11.6, 0, 13.2) m, 0.4 m past the plot's front edge by its left corner, with 1.2 m edge to edge between it and the junction, so the two read as the plot's water supply. It is turned so its front outlet points at the junction and its side outlet points at the plot's front edge. Its nearest edge is 2.6 m from fissure C's center.
- It is at true size (1.6 m × 1.6 m × 1.8 m). Set dressing only: no collision, no pipe drawn to the junction, and no capacity; those wait for an irrigation milestone.

## 2026-11-22: Plateau clutter in the farm

### Ryan chose

- "Plateau clutter"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next.
- Two of each piece (scrub bush, cobble cluster, dry stump) stand in the farm under a `Clutter` node, at true size (0.2 m voxels), each turned a different way. They are spread around the plot in the open ground between the boulders, fissures and buildings, each center at least 5 m from theirs, so the plot's surroundings read as plateau without crowding it.
- Set dressing only: no collision, so the rover drives through them. A sparse first pass; a denser scatter further out, and whether any of them should block the rover, are still open.

## 2026-11-22: Harvest crate in the farm

### Ryan chose

- "Harvest crate"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next.
- The crate stands at (3, 0, 13) m, just past the plot's front edge (its near side is 0.6 m out), turned so its front faces the camera, as if a harvest were being packed. The airlock is about 5 m away and the drop pod's spot about 6 m.
- It is at true size (1.0 m × 0.8 m × 0.6 m). Set dressing only: no collision, and harvests do not go into it; no capacity is specified.
- The voxel README also said the survey tripod was not placed in any scene; it is (`FieldCalPad/Tripod`), so that row is fixed too.

## 2026-11-22: Shipping pallet in the farm

### Ryan chose

- "Shipping pallet"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next.
- The pallet stands at (1, 0, 13.3) m, beside the harvest crate with 0.8 m between them, its near side 0.7 m past the plot's front edge, so the two read as a packing spot. It faces the camera like the crate. Its nearest edge is 2.3 m from the edge of the drop pod's spot.
- It is at true size (1.4 m × 1.2 m × 0.3 m). Set dressing only: no collision, nothing stacked on it, and no load rating; the crate stays on the ground beside it.

## 2026-11-22: Dry gulch tiles in the farm

### Ryan chose

- "Dry gulch tiles"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next. The pack has one gulch tile (`dry_gulch_straight`), so this places a run of it.
- Six tiles stand in a row under a `Gulch` node, a 12 m wash along X behind the plot, centered at (0, −25) m (x −6 m to 6 m, z −26 m to −24 m). Every rock, fissure and clutter piece is at least 3 m from the run's edge (fissure E's center is the nearest).
- Each tile is sunk 0.4 m, so the channel floor is level with the ground and the banks stand 0.8 m above it. The farm's ground is a flat box, so sinking deeper would bury the channel; standing on the ground would lift the channel floor 0.4 m. This answers the open question in the art doc for now.
- Open: the run's ends stop at the cut banks, since the pack has no end caps. From the farm's camera distance the run reads more as a low wall than as a wash. Set dressing only: no collision, so the rover drives through it.

## 2026-11-22: Hygrometer on the calibration bench

### Ryan chose

- "Only hygrometer for now"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place from the Environmental Standards pack. Only the chilled-mirror hygrometer is placed; the dry-well calibrator stays unplaced.
- It sits on the front-left corner of the dome's calibration bench mat at (2.25, 0.9, 0.55) m, turned 180° so its front faces the camera. It fills the 0.3 m strip between the front of the calibration station model (z = 0.4 m) and the front edge of the mat (z = 0.7 m), touching both without passing into either.
- It is at true size (0.35 m × 0.3 m × 0.15 m). Set dressing only: it does not read humidity, and the bench's calibration still runs as before.

## 2026-11-22: Plateau rim in the farm

### Ryan chose

- "Plateau"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next. It was asked as "the plateau rim tiles", so this places both rim tiles from the Dry Gulch & Plateau Rim pack.
- Ten tiles stand in a row under a `PlateauRim` node, a 20 m run along X at z = −30 m (x −10 m to 10 m, z −31 m to −29 m). That is 3 m behind the gulch, so the two read as a wash at the foot of a mesa. Apart from the gulch, the nearest thing is fissure E, 8 m in front of the run.
- Eight straight tiles are turned 180° so the cliff faces the camera. The west end has a corner tile turned 180° and the east end one turned −90°, so the steps and dust apron wrap round both ends. The tiles stand on the ground at true size (2.0 m tall); the ground is flat, so the plateau top is only the tiles' 1.2 m back strip and from behind the run reads as a wall.
- The farm's default camera follows the rover, so the rim is in view only when the rover is near the back of the farm. Set dressing only: no collision, so the rover drives through it.

## 2026-11-22: Dry well on the calibration bench

### Ryan chose

- "Dry well"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next. This places the dry-well calibrator, the second model from the Environmental Standards pack.
- It sits in the back-right corner of the dome's calibration bench at (3.8, 0.9, −0.55) m, turned 180° so its keypad faces the camera. Its footprint (x 3.675 m to 3.925 m, z −0.675 m to −0.425 m) is inside the bench top and clear of the field meter in front of it (back edge near z = −0.33 m) and the calibration station model (right end at x = 3.5 m).
- It is at true size (0.25 m × 0.25 m × 0.35 m tall). From the dome's camera it shows behind the field meter. Set dressing only: nothing in the game uses a temperature reference yet, and the bench's calibration still runs as before.

## 2026-11-22: Soil probe in the farm

### Ryan chose

- "Soil probe"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next. This places the hand soil-moisture probe from the field props pack.
- It stands just past the plot's front edge at (−7.8, −0.4, 12.5) m, on the irrigation junction's right with 0.45 m edge to edge between them, turned 180° so its dial faces the camera. The story has auto-irrigation trusting a soil-moisture probe, so it stands with the plot's water supply. Its footprint (x −7.95 m to −7.65 m, z 12.35 m to 12.65 m) is outside the soil tiles, so no crop cell holds it.
- Its two spikes (0.4 m) are pushed into the ground, so the casing sits on the ground and it stands 0.6 m above it. It is at true size (0.3 m × 0.3 m footprint).
- Set dressing only: no collision and no reading. The design doc has the probe as a sensor dropped for now, so it does not drift and needs no calibration; its specs stay [PLACEHOLDER].

## 2026-11-22: Encoder jig beside the field calibration pad

### Ryan chose

- "Encoder jig"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to the question of what to place next. This places the steering encoder jig, the last unplaced voxel model.
- It is a child of the field calibration pad (`FieldCalPad/EncoderJig`) at (10.9, 0, 15) m in the farm, turned 180° so its spirit level faces the camera. Its footprint (x 10.6 m to 11.2 m, z 14.7 m to 15.3 m) is 0.3 m west of the pad's west edge, mirroring the tripod just off the pad's other side. It is clear of the plot (back edge z = 12 m) and fissure H (z from 17.6 m).
- It is at true size (0.6 m × 0.6 m, 0.4 m tall). Set dressing only: no collision and no interaction. The design doc has a rotary table as the Tier 0 angle standard in place of the jig, so the steering calibration still runs as before.

## 2026-11-22: Inspect props on click

### Ryan chose

- "Make it interactive"
- "Inspect on click"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answers were to what to do now that all voxel models are placed, then to which kind of interaction. Hovering a placed prop shows its name; clicking it adds one line, "Name: description", to the phone log in the farm or to the bottom toast in the dome. No new rules: nothing is measured, bought or changed by a click.
- The names and descriptions live in `data/props.json`, so the SP 811 check scans them. The descriptions hold no specs; any spec one needs stays [PLACEHOLDER].
- Props covered: in the farm the survey tripod, encoder jig, irrigation junction, soil probe, water cistern, harvest crate and shipping pallet; in the dome the environmental chamber and the reference multimeter on its lid. The chamber's click box stops 1.5 m up so it does not cover the meter.
- Left out: the field meter, hygrometer and dry well on the dome bench. They sit inside the bench's click box (which opens the calibration bench), and the picking ray stops at the first box it enters, so they cannot be inspected until that box is shrunk.
- The farm gains a hover name in the world view's bottom-left corner, in teal. The dome already showed hover hints.

## 2026-11-22: Inspect the bench instruments

### Ryan chose

- "Bench instruments too"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to what to do after props became inspectable. The FM-3 field meter, chilled-mirror hygrometer and dry-well calibrator on the dome's calibration bench now show their names on hover and add "Name: description" to the dome toast on click, like the other props.
- The bench's single click box covered all three, so it is now three boxes fitted to the bench: the left tower with its screen, the deck under the instruments (0.2 m tall, up to the instruments' bases), and the bench body below. Clicking those still opens the calibration bench. The empty space just above the deck between the instruments no longer does.
- Measured by casting a picking ray every 2 px from the dome camera: the dry well is clickable on 639 of the 639 pixels it covers with the bench box removed, the hygrometer on 680 of 680, and the field meter on 215 of 220.
- The station's thin upright strip behind the instruments is left out of the bench boxes so it does not hide the dry well; clicking that strip does nothing.
- The descriptions say what each instrument is and hold no specs.

## 2026-11-22: Keep prop clicks out of the phone log

### Ryan chose

- "both"

### Agent's notes (flagged for Ryan, not his words)

- Ryan's answer was to whether to keep prop clicks from pushing lines off the phone log or to have the encoder jig run the steering calibration; "both" covers this entry and the next.
- The phone log shows only its last 8 lines, so a few prop clicks could push a dispatch or an audit out of view. In the farm, a clicked prop's "Name: description" now shows in the hover label at the world view's bottom-left instead, for 3 s or 0.04 s per character if longer (the dome toast's timing). Hovering resumes after that.
- The hover label now wraps long text. Nothing changes in the dome, which already used its toast.

## 2026-11-22: The encoder jig runs the steering calibration

### Ryan chose

- "both"

### Agent's notes (flagged for Ryan, not his words)

- This is the second half of "both" (the first is the phone-log entry above). Parking on the farm's field calibration pad and pressing E now calibrates the steering encoder on the encoder jig against the PX-1 rotary table, then the tire gauge against the WD-1 if it is owned. Before, the pad did only the tire gauge and steering was calibrated only at the dome bench, which still works.
- It is the same calibration as at the bench: same standard, uncertainty budget, refusals, result and bench time (30 min for steering [PLACEHOLDER], on the game clock). The rover must be stopped on the pad.
- The PX-1 is a Tier 0 standard the colony starts with, so steering is offered from day 1. Instruments without a standard are skipped, and the entry line says the tire gauge still needs the WD-1.
- The list of pad instruments is `GameState.FIELD_CAL_IDS`, with a test that steering is offered alone before the WD-1 and with the tire gauge after.

## 2026-11-22: Make the bench's clamp stand clickable

### Ryan chose

- "both"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether the soil probe should read the plot or the bench's dead upright strip be fixed. This entry covers the strip; the soil probe gets its own entry and PR.
- The strip is the clamp stand in the calibration station model, holding the hygrometer under test. It now has its own box in the bench click area (0.5 m × 0.6 m × 0.2 m, from the deck up to the stand's crossbar), so clicking it opens the calibration bench like the rest of the station. This reverses the inspectable props entry, which left the strip out so it would not hide the dry well; the new box sits at least 0.37 m from the dry well.
- Measured by casting a picking ray every 2 px from the dome camera: the dry well, chilled-mirror hygrometer and field meter keep the same pixel counts with and without the box (288, 309 and 96 at this step, so they differ from the inspectable props entry's counts), so the new box hides none of them. The box is flush with the crossbar's top and back; it reaches 0.1 m in front of it and past its end, where the hygrometer clamp sits.

## 2026-11-22: Clicking the soil probe reads out the plot

### Ryan chose

- "both"

### Agent's notes (flagged for Ryan, not his words)

- This is the soil probe half of "both" (the clamp stand entry above is the other half). Clicking the soil moisture probe on the farm now adds the probe's reading for each planted cell after its description, for example "Reads biscuit reed (0, 2) 40.0 %", then "Cal due day 5." or "CAL OVERDUE (due day 5)." With nothing planted it says "Nothing planted to read."
- The reading is what the probe shows, true moisture plus its error, to its 0.1 % resolution. Irrigation holds that reading at the set point (unless the set point less the error falls outside 0 % to 100 %, where the soil cannot follow), so a drifted probe still reads on target while the soil is off by the error. That is the point: the probe cannot tell you it has drifted; only calibration can. (Superseded by "The soil probe's readout shows its drift" below: the readout now shows the drift.)
- The hover label lists the first 4 cells, then "N more", so a full plot does not run off the screen.

## 2026-11-22: The soil probe's readout shows its drift

### Ryan chose

- "both"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether the probe should flag drift or the art loop's new renders be reviewed; this entry is the probe half.
- Clicking the soil probe now adds "Drift +2.70 %, GUARD BAND." before the due day, the same way the dome's displays and the rover's steering readout show drift: the error as the last reference saw it, with its band (IN TOLERANCE, GUARD BAND or OUT OF TOLERANCE against the probe's MPE).
- This replaces the previous entry's note that only calibration can show the drift. The soil readings still sit on the set point, so the drift line is what tells the player the soil is off. The drift line is the error as the last reference saw it, so if that reference was itself off, the drift line and the soil readings can disagree by that much.
- The hover label stays one color; tinting it by band (teal, amber, red) is left for later.

## 2026-11-22: Bring the art loop's five models into the build

### Ryan chose

- "All five"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether to bring the Gemini art loop's five new models into the model build. Each now has a sheet in tools/voxgen/sheets/ and builds at 0.1 m voxels: the Mexican redknee and Brazilian black tarantulas (7 x 7 x 3, sized like the Curlyhair), the PX-1 rotary table (6 x 6 x 3), the MD-2P humidity generator (7 x 6 x 12, 1.2 m tall) and the FM-3 in its carry case (6 x 4 x 3).
- Built only: none is placed in a scene yet.
- Palettes are Gemini's, with one change: Gemini made the case's meter orange (#E85D25), but the game's FM-3 is Ryan's yellow from his pack, so the case uses that yellow (#E5B53B).
- Glowing tokens are their own emit_* parts: the PX-1 and MD-2P displays and the case screen in teal, the MD-2P standby LED in amber.
- The FM-3 case skips the dark border pass ("Answer A"). The case is small, and the pass around its 2-voxel screen painted 14 of its 43 voxels dark, including half the meter, so the case read as a black box. Gemini already set the screen on dark foam. This is an exception to Ryan's rule, so it is his call: the skip is one line (BORDER_SKIP in build_models.py) and can come out.
- The Brazilian black is very dark (near-black body, blue-grey hairs); it reads in the dome's light but may need a lift if it sits in shadow.

## 2026-11-22: Place the PX-1 and MD-2P

### Ryan chose

- "Yes"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether to place the new models in the scenes: the tarantulas in the terrarium and the instruments in the dome. This entry places the two instruments that have a clear home.
- The PX-1 rotary table sits on the field calibration pad, 1 m in front of the encoder jig, since steering is calibrated on that jig against the PX-1.
- The MD-2P humidity generator stands on the dome floor, left of the calibration bench, since it is the hygrometer's humidity reference.
- Both can be clicked to inspect. New text in data/props.json: the PX-1 is the "Angle reference" and the MD-2P the "Humidity reference".
- The two tarantulas are not placed. The dome keeps one species (the Curlyhair), and tarantulas can't share a tank, so they need either their own small tanks or a later species choice. Left for Ryan.
- The FM-3 carry case is not placed. A loose FM-3 already sits on the bench, so placing the case would show the meter twice. Swapping the loose meter for the case is left for Ryan.

## 2026-11-22: Give the two new tarantulas their own small tanks

### Ryan chose

- "Own small tanks"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether the Mexican redknee and Brazilian black tarantulas should get their own small tanks or stay unplaced (the dome keeps one species, and tarantulas can't share a tank).
- Each small tank is the dome's terrarium model at half size (0.7 m wide), on the left bench either side of the main terrarium: the redknee on the left, the Brazilian black on the right. Each spider is at half size too, so it sits in its tank as the Curlyhair does in the big one.
- The small tanks are decor you can click to inspect. They have no humidity, molt or silk of their own; the game still tracks only the Curlyhair.
- New text in data/props.json names each species with its scientific name from data/tarantula_species.json.
- The Brazilian black is near-black and hard to see at this size; it may need a lighter palette later.

## 2026-11-22: Swap the loose FM-3 for its carry case

### Ryan chose

- "fm3 can replace"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether the FM-3 carry case should replace the loose FM-3 on the calibration bench or stay unplaced.
- The case takes the loose meter's spot and turn on the bench mat, at the rear right. The node is now FieldMeterCaseModel, and clicking it still reads "FM-3 Field Meter", now "in its open carry case".
- The case is built at 0.05 m voxels, half the art loop's 0.1 m, so it is 0.3 m × 0.2 m × 0.15 m. At 0.1 m it would be 0.6 m wide, out of scale with the 0.25 m loose meter. The size is the agent's choice, so it is Ryan's call.
- The loose meter's model (field_meter_fm3.glb) stays in the build, unplaced.

## 2026-11-22: Keep the FM-3 case at half size

### Ryan chose

- "Keep"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether to keep the FM-3 carry case at half size (0.05 m voxels, 0.3 m wide) or build it at the art loop's full 0.1 m (0.6 m wide). It stays at half size, so the previous entry's size is now his call, not only the agent's.

## 2026-11-22: Lighten the Brazilian black

### Ryan chose

- "Lighten"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether to lighten the Brazilian black tarantula's palette so it shows up in its small tank, or leave it dark.
- Gemini's near-black body (#0E1117) read as a dark hole behind the tank's tinted glass. The body is now slate (#4A5468, with #363E4C for the darker cells), and the steel-blue sheen on the legs and back is lighter (#7C90AE and #AABCD4). The colors are the agent's choice, kept cool and grey so it still reads as a black tarantula, not as a grey one.
- The voxel grid is unchanged; only the colors moved. The sheet keeps Gemini's original colors in its header for the record.

## 2026-11-22: Drop the FM-3 case's screen glow

### Ryan chose

- "Drop"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether the FM-3 carry case's screen should stop glowing teal, to match the other metrology props, or keep the glow.
- Gemini had lit the meter's screen teal as its own glowing part. The screen is now the blank, unlit screen of Ryan's metrology pack (#2E3844), like the loose FM-3, the LS-85 reference meter and the hygrometer. The voxel grid is unchanged.

## 2026-11-22: Keep the loose FM-3 model in the build

### Ryan chose

- "Keep"

### Agent's notes (flagged for Ryan, not his words)

- Ryan answered the agent's question, whether to keep the loose FM-3 model (field_meter_fm3.glb) in the build now that its carry case has replaced it on the calibration bench, or remove it.
- It stays in the build, unplaced, so it is ready if the FM-3 is shown out of its case later, for example in the field.

## 2026-11-22: The molt runs on the game clock

### Ryan chose

- "Co-op groundwork (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- The option was the README's known exceptions, one PR each. This is the last one.
- The molt takes 40 game minutes, the same 20 s at the default pace. `PLAYTEST_MOLT_DAYS` in `GameState` replaces the 20 s constant.
- Time jumps (a bench calibration, the F9 skip) don't advance the molt, as before: the molt follows `GameClock.clock_ran`, not `time_advanced`. The hygrometer's bench job takes 90 min, so counting it would finish a 40 min molt at once. A paused clock now pauses the molt. Open for Ryan: whether jumps should count.

## 2026-11-22: The outdoor and mining sets are placed

### Ryan chose

- "Place Outdoor set (Recommended),Place Mining set"

### Agent's notes (flagged for Ryan, not his words)

- The agent asked which of the new art packs to place. The options were set dressing on the farm with no collision and no readings. The new ore fissure and "Leave them unplaced" were not picked, so the existing fissure stays as it is.
- The spots and the Inspect texts are the agent's. The culvert bridge takes the place of one gulch tile.

## 2026-11-22: The farm saves to one file

### Ryan chose

- "Save and load (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- The host's game writes one farm file, `user://farm.save`. The save before it is kept beside it as `.bak`, and loading falls back to it if the newer file is missing or won't load. A file the game can't read is set aside as `.unreadable` (numbered if there is one already), not deleted.
- The file is Godot's binary form without objects, not JSON, because Godot's JSON rounds numbers and a loaded farm must continue exactly as the saved one would. It carries a format version and a SHA-256 check of its contents.
- One save slot for now. Open for Ryan: more slots.
- This change only adds the save code. Nothing in the game saves or loads yet.

## 2026-11-22: The game opens on a title menu

### Ryan chose

- "Save and load (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- The menu offers Continue (with the saved day), New farm and Quit. The clock is stopped there. Look and wording are the agent's [PLACEHOLDER].
- The farm saves each morning and when the window closes. There is no manual save and no way back to the menu yet. Open for Ryan: both.
- A new farm asks first when there is a saved one, then keeps that one as `farm.save.old` (one only; an earlier one is replaced). Nothing in the game opens it again.

## 2026-11-22: Tier 2 standards, and calibrating a standard on the bench

### Ryan chose

- "Milestone 3b"
- "Placeholder and go (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- The HM-3 and TW-6 are in the data. Tier 2 opens with an OIRM account, which sending a bought standard to OIRM opens. The Instrumentation 3 half of the gate comes with skills.
- The HM-3 is Kestrel's to sell, so it can't be bought until Kestrel trades. The TW-6 is Bram's; nothing it calibrates exists yet.
- The FM-3 can now be calibrated on the bench against the HM-3. It gets an in-house certificate (prefix IH), keeps its interval as at OIRM [ASSUMPTION], and an out-of-tolerance as-found starts a recall. Standards don't count toward OIRM's contract run.
- A standard whose certificate is recalled is suspect, and work done with it is not traceable, until it is calibrated again. The same goes for one adjusted against an untraceable reference.
- [PLACEHOLDER]: HM-3 900 CR + 4 ore, U 0.00003 V, 0.00006 V MPE at a 10 V point; TW-6 700 CR + 3 ore, U 0.1 N·m, 0.25 N·m MPE at a 100 N·m point; 30-day intervals; drift to MPE in about 120 days; 60 bench minutes for the FM-3.

## 2026-11-22: Tier 3 standards and the relay lock

### Ryan chose

- "Milestone 3b"
- "Placeholder and go (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- Tier 3 opens with Vance's traceable lab sign-off (two clean audits in a row, kept for good) and a Tier 2 standard with a current OIRM certificate. The Instrumentation 6 part comes with skills. An HB-700 won by contract still skips the gate.
- The Rb-2D is in the data as Orin's and the HB-700 as Kestrel's [ASSUMPTION]. Neither trades yet, so the Rb-2D can't be had and the timebase stays out of service. Open for Ryan: who sells them.
- The Rb-2D is locked while any rover has line of sight to the relay, by its last report (so also while the farm view is closed) [ASSUMPTION]. Locked: no drift, always in date. In holdover it drifts by aging; after 3 days [PLACEHOLDER] its certificate lapses until it locks again.
- The WD-1 can be calibrated on the bench against the HB-700 (60 min [PLACEHOLDER]).
- Other [PLACEHOLDER]: Rb-2D 2000 CR + 5 ore, U 0.0001 × 10⁻⁶. Its MPE, 0.0003 × 10⁻⁶, is the cited temperature spec.

## 2026-11-22: Kestrel and uncertified standards

### Ryan chose

- "Milestone 3b"
- "Placeholder and go (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- Kestrel trades at the dome airlock on solar flare nights only: from day 10, every 7 days, 20:00 to 02:00 [PLACEHOLDER]. The schedule follows the clock. Flares do nothing else yet, and the story's dropped uplink is left out.
- Kestrel sells the HM-3 and, outside the contract, the HB-700, at list price behind the same tier gates. A contract HB-700 stays Bram's.
- They read true but have no certificate [ASSUMPTION]. They count as overdue from the next day until sent to OIRM, so the audit flags them and they cost credibility daily. Work done before the first OIRM certificate stays untraceable after it.
- Buying the HB-700 from Kestrel while the OIRM contract is open closes the contract.
- Kestrel shows as a placeholder crate by the airlock.

## 2026-11-22: Skills earn XP and levels

### Ryan chose

- "Milestone 4 skills"
- "Placeholder and go (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- The six skills, their XP and the level curve are in `data/skills.json`, from §2 of the design; all numbers [PLACEHOLDER]. Levels do nothing yet.
- Which skill goes where ("both", from the co-op direction): Calibration, Uncertainty and Field Ops are each player's own. Instrumentation, Robotics and Husbandry are the farm's, because what they improve is shared [ASSUMPTION]. A clean audit gives its XP to every player the farm's save knows [ASSUMPTION].
- A calibration that is not traceable (the remote zero included) gives no XP, besides the design's rule for one made too soon [ASSUMPTION]. After an untraceable zero, the next traceable calibration still gives XP.
- The farm's save keeps every player's own XP by player id, so a new farm starts at level 1. A guest's skills travel with them (see co-op).
- Paid jobs, crops and OIRM trips give no XP; the design lists none. Open for Ryan.
- Instrumentation is to gate Tier 2 at level 3 (150 XP), and buying the Tier 1 standards gives 15 each. Whether that can be reached in play is open before the gate goes in.

## 2026-11-22: Skills take effect

### Ryan chose

- "Milestone 4 skills"
- "Placeholder and go (Recommended)"

### Agent's notes (flagged for Ryan, not his words)

- Level effects follow §2.3 of the design: bench time, as-left error, operator uncertainty, molt time and steering drift from driving, in `data/skills.json`. Level 1 is the base; all numbers [PLACEHOLDER]. Husbandry 3 shows the molt on the field phone; Uncertainty 5 shows the uncertainty budget on the bench.
- An unskilled operator adds u_op = 5 % of the unit's MPE [PLACEHOLDER]. At Uncertainty 1 no bench TUR can be over 10:1, so very high TURs drop most (steering encoder 47.6 to 9.8, relay timebase 172.9 to 10.0) and the rest by less (dome pressure 3.1 to 3.0, terrarium thermometer 4.8 to 4.3). No unit crosses the 4:1 or 2:1 lines, against its own standard or one that takes it over. The Uncertainty skill raises them again. OIRM's own calibrations are not affected.
- Bench time also applies to paid jobs. The as-left effect needs a standard, so the remote zero is unchanged.
- Not built, because players already have them: TUR on the bench at Uncertainty 2, two instruments per bench visit at Calibration 3, two fissures per drilling trip at Field Ops 4. Taking them away to give them back is Ryan's call.
- Not built: the Instrumentation tier gates (levels 1, 3 and 6). Level 3 needs 150 XP, and the few standards a farm can buy before Tier 2 give 15 each, so the gate could hold a farm back for a long time. Robotics waits for robots.
- K opens the skills view, on the farm and in the dome [PLACEHOLDER key].


## 2026-11-23: Robots, first slice: build and commissioning

### Ryan chose

- "I am awake however keep pressing forward and show me renders whenever time permits"

### Agent's notes (flagged for Ryan, not his words)

- This is the first part of milestone 5. The job cards, robot audits with the interlock fine, and the 3D robot come in later slices, so a released robot does nothing on the farm yet except sit on the audit list.
- T at Bram's bay opens the robots view [PLACEHOLDER key]. A Trellis costs 600 CR, 5 crystal ore and 1 silk spool and takes 1 day to assemble [PLACEHOLDER]. One build at a time [ASSUMPTION].
- The design (§3.2) gates it on Robotics 1, Instrumentation 3 and an in-tolerance TW-6. Instrumentation is gated at 1 here, because nothing else is gated on Instrumentation yet (open question). A second robot needs Robotics 3, a third 5 [PLACEHOLDER]. "In tolerance" means owned, home, certified, not overdue and not recalled.
- Every standard its sensors need (TW-6, PX-1, WD-1 and FM-3) must also be owned before it can be ordered, or it could never be released [ASSUMPTION].
- Its four sensors start uncalibrated, up to half their MPE off. They are on the bench at once, but are audited, count toward credibility and count for the OIRM contract only after release. Release needs each sensor's last calibration to be a traceable, in-date pass that is not suspect. Calibrating one with an overdue standard still costs credibility, because the lapse is the lab's, and the audit's count of calibration records includes commissioning records.
- Calibrating a robot sensor gives Robotics 5 and Calibration 5; the Calibration 5 is in place of the usual 10 (my reading of the table in §2.2). The bonuses for on time, TUR and found out of tolerance still apply.

## 2026-11-23: Robot job cards: WATER

### Ryan chose

- What WATER does, given the auto-irrigation: "Trim set points (Recommended)". The robot checks the plots with its own probe and adjusts each set point to correct for the plot probe's drift. Auto-irrigation stays. If the robot's probe drifts, it trims wrongly.

### Agent's notes (flagged for Ryan, not his words)

- A released robot holds job cards and runs the first one due, one job per clock tick (§3.3). Robotics 1 gives one slot, 2 and up give two (§2.4). Cards added below the first wait their turn.
- Triggers: a clock time every n days, or soil reading more than a quarter of a crop's tolerance band off target [PLACEHOLDER]; a probe's error stops at 3 MPE (9 percentage points), so half a band would never trigger. The robots view offers daily at 06:00 and the soil card; the order is the order added [PLACEHOLDER].
- "All plots" is the only target, and a crop that is ready is left alone.
- With no line of sight a robot runs what it has but takes no new program.
- A job that trims something earns Robotics 1 for whoever added the card. A check that changes nothing earns nothing.
- Not built: COLLECT SPOOL and CALIBRATE cards, the interlock and audit fine, what drift in the other three sensors does, and drift from use. WATER doesn't use the robot's tank.

## 2026-11-23: Robot interlock and drift effects

### Ryan chose

- "Yes, start M5-3" (drift effects and the interlock). Vance fining an overridden interlock was already in the design as an assumption (§6 item 10).

### Agent's notes (flagged for Ryan, not his words)

- A released robot with any sensor out of tolerance (true error) posts once, for example "TR-1: grip torque out of tolerance. Holding.", and runs no cards. A card that came due meanwhile runs once the robot is free.
- The robots view can override the interlock (two presses, needs line of sight). With every sensor back in tolerance the interlock arms itself again.
- Vance reads the interlock log: 100 CR per robot overridden since the last audit [PLACEHOLDER], even if it was armed again in time, on top of the bad sensor's own fine [ASSUMPTION]. The one-time warning covers it too.
- WATER only trims set points, so drift acts on the trim [ASSUMPTION]. A joint encoder out of tolerance sends each trim to the next plot along x, toward its error; if nothing grows there it is lost. The tank gauge scales the trim, 10 % at its MPE [PLACEHOLDER]; reading high, it doses low. The soil probe trims wrongly as before. Grip torque changes no job until COLLECT SPOOL, but still trips the interlock.
- With the encoder out of tolerance the soil card runs once a day [PLACEHOLDER], or it would push the next plot all the way within a few ticks.
- A WATER job with something to trim wears the encoder (0.005°), the tank gauge (0.01 kPa) and the probe (0.02 percentage points) [PLACEHOLDER], even if the water lands on no crop.
- Not built: the CALIBRATE card, its u_robot term, and the recall of what a bad robot calibrated. Next slice.

## 2026-11-23: Tarantula & Optical Silk pack

### Agent's notes (flagged for Ryan, not his words)

- Ryan sent the pack without instructions. The skein stands in for the silk pickup in the dome, at half the size his generator gives (0.05 m voxels, not 0.1 m): at full size it cut into the Brazilian black's tank. The greybox spool is the fallback.
- The winding spool and the mister kit are set dressing on the terrarium bench. What they do in the game is open for Ryan.

## 2026-11-23: Rover Docking Pad & Air Dryer pack

### Agent's notes (flagged for Ryan, not his words)

- Ryan sent the pack without instructions. The pad lies in Bram's bay as the rover's service spot, sunk 0.18 m and without collision, so driving is unchanged. The dryer stands beside the bay as set dressing.
- What they do in the game (docking, charging, dry air) is open for Ryan.

## 2026-11-23: Robot CALIBRATE card

### Ryan chose

- "Yes, start CALIBRATE" (the card, its u_robot term and the recall of what a bad robot calibrated).

### Agent's notes (flagged for Ryan, not his words)

- A CALIBRATE card names one unit and uses the standard that unit always uses. Robots leave the standards to people, and never calibrate themselves [ASSUMPTION].
- It needs Robotics 4 and Calibration 3 [PLACEHOLDER] and a TUR of at least 4:1 counting u_robot, when the card is added and each time it runs. A soil probe at Uncertainty 1 comes out at 3.8:1, so it needs more Uncertainty skill first.
- u_robot = 0.1 MPE ÷ √3 [PLACEHOLDER]. The robot's worst sensor, as a share of its own MPE, times 0.1 goes hidden into the unit [ASSUMPTION]. The programmer's u_op still counts.
- "As it comes due" runs from one day before [PLACEHOLDER], tried once a day. The clock trigger works too, but the screen offers only the first. The design's amber guard-band trigger is not built: it would give away the hidden error.
- A robot won't use a standard that is not traceable; it posts why to the phone. It takes no bench time and wears only the joint encoder [ASSUMPTION].
- XP is Robotics only (the job, and a robot sensor calibrated), and none before the unit has run half its interval. It neither counts toward nor breaks the contract run. A robot may calibrate another robot's sensors; the recall then follows the robot that did the work. Open for Ryan.
- A robot sensor found out of tolerance recalls *every* traceable calibration its robot did since that sensor's last good one (§3.4), not only those a threshold would change (§1.6). Open for Ryan.
- Not built: a recalled standard's effect on a robot's own work, and the COLLECT SPOOL card.

## 2026-11-23: Fiber-Tuber Root Crop pack

### Agent's notes (flagged for Ryan, not his words)

- Ryan sent the pack without instructions. Dust Turnip, the one root crop, shows it; no crop was renamed or added, and growth and prices are unchanged. Whether the Plateau Fiber-Tuber should be a crop of its own is open for Ryan.
- A crop picks its models with `model` in `data/crops.json`; one without it keeps the sun-pods.

## 2026-11-23: Robot COLLECT SPOOL card

### Ryan chose

- "Yes" to the overnight roadmap of 2026-11-23, which lists this card.

### Agent's notes (flagged for Ryan, not his words)

- The card needs Robotics 2 and a grip torque sensor whose last calibration is a traceable, passing one that is neither overdue nor suspect. Both are checked when the card is added. Later the interlock holds a robot whose grip is out of tolerance.
- It has one trigger, "spool ready", and collects each spool as it is ready. The robot and the player share one way to collect, so the next molt starts the same.
- The gates are not checked again while the card runs, as for WATER. Open for Ryan.
- A job wears the grip (0.02 N·m) and the joint encoder [PLACEHOLDER].
- XP is Robotics only, as for the other cards [ASSUMPTION].
- Pacing, flagged for Ryan: a molt is 40 min [PLACEHOLDER, set for playtests], so a robot can collect about 36 spools a day. That puts its grip and encoder out of tolerance in about 5 days, and earns about 36 Robotics XP a day while idle, which undercuts CALIBRATE's Robotics 4 gate. A longer molt fixes all three.
- Collecting isn't posted to the phone, which it would flood.
- Not built: damage to the spool from a bad grip (§3.4).

## 2026-11-23: Damaged silk spools

### Ryan chose

- "Yes, your call" to damaged spools and their numbers.

### Agent's notes (flagged for Ryan, not his words)

- A robot whose grip torque is out of tolerance, which works only with its interlock overridden, has a 50 % chance [PLACEHOLDER] to damage each spool it collects. A player never does.
- A damaged spool gives half [PLACEHOLDER] the base lag cut: 30 % instead of 60 %. The species' own cut is kept [ASSUMPTION].
- The relay takes the oldest whole spool, and a robot's eye the oldest damaged one, if there is one [ASSUMPTION]. A damaged eye has no effect.
- A whole spool may replace a damaged one in the relay, which is thrown away [ASSUMPTION]. Without that the first spool slotted would be final. Each slotting earns the usual Husbandry XP.
- Balance, flagged for Ryan: robots use damaged spools up at no cost and the relay takes a whole one first, so damage matters only when no whole spool is in stock.
- The screens count damaged spools. Old saves load with every spool whole.

## 2026-11-23: Why a unit has no CALIBRATE card

### Ryan chose

- "Yes" to the overnight roadmap, which has the robot screen say why a unit is missing.

### Agent's notes (flagged for Ryan, not his words)

- Under the CALIBRATE cards, one row per reason (a ratio is its own reason) names the units in service the robot can't have a card for. Units the farm doesn't own aren't listed.

## 2026-11-24: Co-op, first slice

### Ryan chose

- "Yes" to starting co-op now.
- "Agree" to a first slice with the shared rover and screens only, and no walking characters.
- "Direct IP first": friends join by IP address, Steam later.
- "yeah lets do wait for now": at 06:00 with someone still up, the day waits for them.
- Guest skills (2026-11-24): kept "On the guest's PC".
- Seeds and starting set points (2026-11-24): "Pick there own!" Each player picks their own.

### Agent's notes (flagged for Ryan, not his words)

- Order, one PR each: player ids, host commands, host clock, joining, syncing, beds, guest skills.
- Every screen and scene now says which player acts, and a test keeps it so. One player notices no change.
- A robot's log keeps who overrode its interlock last, until the audit that clears it [ASSUMPTION]. No screen shows the name: whether one should is open, with no effect on the fine.
- Open: bench calibration time in co-op, who can pause, whether a rover may be taken from its driver, rejoining mid-day, and how names show.
- Host commands: the dome, bench, lab, Kestrel and robot screens change the farm only through FarmCommands, by action name with plain arguments, and a test keeps the listed actions so. The host says who acts. FIT OUT now says only "one more space", as a guest's count may lag. A bench refusal is amber, as nothing was found out of tolerance, and its button stays. Looking at the lab no longer writes its layout. One player notices no change.
- The farm scene, rover and grid go through FarmCommands too, so every screen does. GameState refuses soil off the plot, unknown fissures, and rover distances or places that are not real numbers. ZERO STEERING is its own action, so a guest can't ask for any calibration without a standard. One player notices no change.
- Distance driven, line of sight and parking are not actions: the host counts them (see Rover).
- The seed and starting set point stay saved with the farm and are sent with each planting. Changing them is not a command yet: a guest changes only its own copy, and each player has their own. A guest's spool and set point lines say only what the host's answer holds, and its Bram greetings are not drawn from the farm's generator.
- Open: GameState doesn't check that a guest's rover is at the soil, fissure, stall or pad.
- To settle with syncing: the farm must reach a guest before the answer that changed it, or a bracket pressed at once after PLANTED sets the next crop's starting set point; REMOVE CARD and accepting a job name a card or job by its place, so another player's change in the same moment could move it.
- From Fable's math check: the manager's one-time favor no longer costs credibility for an overdue standard, its records count at the audit it happens in, and the clock no longer shows some exact minutes one early.
- Joining: `CoopSession` hosts or joins by IP address on UDP port 24711 [ASSUMPTION], which the host must forward. It sends its own plain-data messages and the game has no RPCs. A guest can only say hello and ask for FarmCommands actions; a bad, oversized or too-frequent message drops it, and the player comes from the connection. A cut-off guest stays locked until it leaves. Joining needs its own farm closed, so the host's farm never autosaves over it. Messages aren't encrypted and there is no password yet. Limits [PLACEHOLDER]: 4 spare connections, 2 KiB from a guest and 4 MiB from the host per message, 8 arguments, 64 characters, 32 levels deep, 20 messages at once then 10 a second, 10 s to be let in or answered. Bytes are checked before Godot reads them. `send_state()` is the hook for syncing. Alone, nothing is opened.
- Guests are player_2, player_3 and so on in the order they join, and a friend who comes back is the same player. The farm keeps the next number, so a newcomer never gets an earlier guest's skills or records.
- Host clock: a guest gets the farm as a save's bytes, with a save's checks, refused whole if bad. It shows only what changed, never loads mid-play, and never writes a save file. Joining closes the guest's own farm, so leaving can't save over it. A farm over 4 MiB [ASSUMPTION] still saves but can't be sent. A guest keeps its own next seed and starting set point. The phone counts its lines, so a guest sees repeats and audits in the host's order.
- A guest's clock shows the host's time and runs nothing: no drift, molt, morning, bench time or F9 skip. Between updates it runs up to 10 game minutes ahead [PLACEHOLDER], then waits, and it stops one game second short of 06:00 [ASSUMPTION]. A paused host's time is shown exactly. It never passes 06:00 before the host does, and a guest's pause doesn't stop it.
- Syncing: `CoopSync` sends a guest the whole farm when it joins, before the answer to each of its own commands, and each second, and the clock in between [PLACEHOLDER]. The bytes are compressed: in a test farm 100 days took 12 KB and 300 days 24 KB, and the host spent about 10 ms on 300 days. A big farm is sent less often, 64 KiB a second [PLACEHOLDER], not counting the farm each guest's command brings. A guest that can't read the farm, or is told it is too big, hangs up and says why. A guest sees its own change at once, and others' within a second unless the farm is big. Not synced: the drop pod's flight.
- Host and join screens: F7 on the farm or in the dome hosts the farm, stops hosting, or leaves a friend's. JOIN A FRIEND on the title menu takes an IP address; the port is 24711 for now. A farm run outside the title menu can't be hosted. A guest whose connection ends goes to the title menu, which says why and ends the session, so the copy stays locked until its scene is gone. Stopping hosting sends every guest to their title menu. Players are shown as PLAYER 2 until Ryan picks how names show.
- Beds: with friends in, GO TO BED is in the F7 panel (no one walks, so there is no bed to stand at). When everyone is in bed the day ends at once, whatever the hour. At 06:00 with someone up the host's clock stops one game second short [ASSUMPTION], and nothing drifts, molts or grows until everyone is in bed. Doing anything on the farm gets a player up; driving doesn't [ASSUMPTION]. Whoever leaves is no longer waited for. Alone nothing changes: the day goes over at 06:00 on its own.
- With friends in, bench work that would run past 06:00 is refused [ASSUMPTION], so the stopped clock can't give free bench time. Open with Ryan's bench time question.
- Guest skills: `coop_player.json` in the guest's user folder holds a random key and the XP of their own skills. The player may edit it. Joining shows the host both. A farm keeps the key's hash, so a friend who returns is the same player; a new PC, or a lost file, is a new one. The key isn't encrypted on the way, and a host could use it to join another farm as that friend [ASSUMPTION: friends trust each other].
- A joining guest has the better of the farm's XP and their own in each skill, up to the top level, and their file only ever goes up [ASSUMPTION]. What a player earns on their own farm stays there; the file holds what they earned as a guest [ASSUMPTION]. A farm knows 64 guests, then forgets the first. The key is 16 bytes, and the file is at most 8 KiB, 16 skills and 1 000 000 000 XP each [PLACEHOLDER, all].
- Rover: Ryan asked for it ("Rover next!"). One player drives at a time, whoever pressed first, until it has stood still half a second [ASSUMPTION; PLACEHOLDER time]. Nobody can take it from a driver. Everyone else sees it follow and the co-op line says who drives. Space and R still work for everyone, on the ground under the rover they see [ASSUMPTION].
- The driver's own PC moves the rover and says where it is 20 times a second, so it answers as it does alone, with the driver's own uplink lag, and can be driven while the host is in the dome. The host says who drives, refuses moves beyond 15 m at once and 7.5 m/s after, and places over 500 m out, and parks it. It counts the distance to wear, and the driver's Field Ops counts [ASSUMPTION]. With the host in the dome the driver's PC says whether the rover sees the relay [ASSUMPTION]. A lost connection stops a guest's rover for everyone else within about a second. Walls aren't checked: friends trust each other [ASSUMPTION].
- Poses may be lost or late, so only the newest counts. They have their own limit: 100 at once, then 40 a second. All these numbers are [PLACEHOLDER]. Protocol 4. One player notices no change.

## 2026-11-24: Hills, digging, tunnels

Ryan: "Hills then tunnels for growth if we can do digging and destruction in parallel that would be amazing."

- One shaped ground for all of it: the natural land less what was dug, worked out alike on every PC from a point each meter. Digging is by the soil grid's 2 m cells in 0.5 m steps [PLACEHOLDER]. Points between cells are as deep as the shallowest that meet there, so sides slope.
- A cell may be at most one step deeper than any of its eight neighbors, so sides slope at about 27° along the grid and at most about 35° at corners, no hole has a wall, and no one digs the rover into a trap [ASSUMPTION]. The dig command will hold to it.
- The land stays level within 30 m of the farm's middle and 10 m of the relay [PLACEHOLDER].
- The ground blocks the uplink, hills and pit walls alike [ASSUMPTION].
- Tunnels are a scene of their own: the camera can't see under the ground [ASSUMPTION].
- G digs and H fills the cell 2 m ahead of the rover's middle, a step a press, at most 4 steps deep [PLACEHOLDER]. Both ride the uplink, and the rover must stand [ASSUMPTION]. They cost and give nothing [ASSUMPTION]. Level ground and the land's outermost cells are never dug. A teal line shows the cell.
- In co-op anyone may dig where the rules allow; the host doesn't check where their rover is, as with tilling [ASSUMPTION]. A save whose digging breaks the rules is refused, like other bad data. Protocol 5.
- Space drills a fissure first, then a boulder within 0.7 m of the rover's nose [PLACEHOLDER], then tills [ASSUMPTION]. 5 hits break a boulder for good [PLACEHOLDER]; each hit shrinks it 6 % [PLACEHOLDER]. A broken one blocks nothing and gives nothing [ASSUMPTION].
- Open with Ryan: what digging gives or costs, whether dug ground fills back in, what breaking a boulder gives.
- Hills: seven placed by hand, three of them 6 m high, over land that rolls a little. No slope is over 15°, so a 27° dug side on a hill can still be driven up. All sizes and places are [PLACEHOLDER]. The level land is now 33 m around the farm, as rim rocks reach 32.6 m, with a level road 10 m wide to the relay [PLACEHOLDER]. Three hills' feet reach that edge, where the ground rises up to 0.23 m in its first meter. A rover loaded within a wheelbase of the land's edge comes back that far in.
- The whole farm and the road see the relay. Three places behind the 6 m hills don't, about 2.5 % of the land [ASSUMPTION].
- High ground is a little warmer and valleys a little cooler in color; level ground is unchanged [PLACEHOLDER].
- The land rises 1.5 m toward its edge [PLACEHOLDER], but the rover can still drive off, as before. A rover parked inside a hill by an older save, or off the land, comes back on the ground [ASSUMPTION].
- Open with Ryan: what should stop the rover at the land's edge.
