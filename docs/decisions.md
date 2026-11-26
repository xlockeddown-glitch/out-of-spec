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
- Walking, first slice. F gets out of the stopped rover on the farm and back in
  within 6 m, as near as the tunnel pad wants the rover. All of this is
  [ASSUMPTION]:
  - On foot the player only walks, looks, clicks props, opens the skills and
    co-op panels, goes to bed and gets up. Farm work, stations, Bram, the dome
    and the tunnels need the rover: the host refuses everything else from
    someone on foot, and the screen says "On foot. Get in the rover first."
  - The rover stays where it was left and anyone may drive it, as before. If it
    goes into the tunnels, everyone on foot is back in it.
  - WASD goes by the camera: W is up the screen. The rover's keys are throttle
    and steering, which would not suit a walker.
  - Rocks, boulders, stone walls and deep water stop a walker. Shallow water
    slows it as it slows the rover. The host takes no guest into deep water.
  - Walkers pass through each other, and the rover pushes its own player's
    walker aside on that player's screen. Nobody is hurt.
  - Nothing about walking is saved. Loading, joining again or losing the
    connection puts the player in the rover.
  - Guests send where they walk and the host sends everyone's, as rover poses
    are sent: plain numbers that may be lost. The host takes a guest's if it is
    out, on the land, near the ground and no faster than it could walk.
  - [PLACEHOLDER]: walks 4 m/s, climbs 50°, 1.6 m tall; poses each 50 ms moving
    and 1 s still; a guest may go 12 m at once and 5 m/s after, is put back
    beyond 10 m, and is in the rover again after 5 s of silence; 5 m off the
    ground is too far; its own F holds for 1.5 s against older word.
  - The model is original voxels in code: orange suit, dark boots and pack,
    teal visor. Protocol 13.

- Ready for Steam, with no Steam in it (steps 1 to 3 of
  [steam-plan.md](steam-plan.md)) [ASSUMPTION]:
  - A session runs over any Godot `MultiplayerPeer`. Two functions make the
    ENet one. A fake in-memory peer in the tests stands in for others.
  - host() and join() take a transport: "enet" unless told otherwise. "steam"
    gets "Steam unavailable." and any other is refused; nothing opens. The
    screens don't offer a choice. Protocol unchanged.

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
- Hills: seven placed by hand, three of them 6 m high, over land that rolls a little. No slope is over 15°, so a dug side on a hill (27°, or at worst 44.3° at a pit's corner) is under the rover's 45° limit. All sizes and places are [PLACEHOLDER]. The level land is now 33 m around the farm, as rim rocks reach 32.6 m, with a level road 10 m wide to the relay [PLACEHOLDER]. Three hills' feet reach that edge, where the ground rises up to 0.23 m in its first meter. A rover loaded within a wheelbase of the land's edge comes back that far in.
- The whole farm and the road see the relay. Three places behind the 6 m hills don't, about 2.5 % of the land [ASSUMPTION].
- High ground is a little warmer and valleys a little cooler in color; level ground is unchanged [PLACEHOLDER].
- The land rises 1.5 m toward its edge [PLACEHOLDER], but the rover can still drive off, as before. A rover parked inside a hill by an older save, or off the land, comes back on the ground [ASSUMPTION].
- Open with Ryan: what should stop the rover at the land's edge.
- Hill plants and rocks are the same on every PC and in no save. Rocks stop rovers and the uplink, as boulders do, but can't be broken; plants stop nothing [ASSUMPTION]. None is on level ground or hides the relay from it. Numbers, sizes and places are [PLACEHOLDER].
- Ground within 0.5 m of a rock can't be dug [PLACEHOLDER; ASSUMPTION]; an older save's digging there loads, and the rock sits lower. A plant is gone while ground under it is dug and back when it is filled [ASSUMPTION]. A rover an older save left inside a rock comes back beside it [ASSUMPTION].
- The gulch's west end has a bend, to look at only [ASSUMPTION].
- Basalt tunnels, first slice: the mouth is at the farm's northeast, its pad at (20.5, -15.5) m [PLACEHOLDER]. Park on the pad and press E, as at the other pads. Entry is open from the start, and nothing in there is unlocked, earned or spent [ASSUMPTION].
- The rover has one parked place on the farm and one in the tunnels, so neither scene's place is taken for the other's. It comes in at the mouth, and comes out where it went in [ASSUMPTION]. The dome's airlock leads back to the tunnels if they were left for it.
- TUNNEL BEACON 01 inside the mouth stands in for the relay, with the same lag, and a silk spool in the relay shortens it as outdoors [ASSUMPTION]. Arches and walls block it, walls drawn low too. A rover in there says nothing of the relay: the farm rover's last word holds, as from the dome [ASSUMPTION]. The mouth's rock on the farm doesn't block the relay [ASSUMPTION].
- Walls on the camera's side are drawn low and an arch near the rover is see-through, so the rover is always seen. Map, sizes, colors and light are [PLACEHOLDER]. The rock takes the gray of Ryan's underground models, lit warm [ASSUMPTION], and a 3 m alcove off the mouth chamber is left open for one.
- The rock there is not tilled, dug or filled [ASSUMPTION].
- In co-op each player goes in and out alone, as with the dome. The rover is in one place, as decided below.
- Open with Ryan: vents that heat sensors, Old Orin, beacons the player places, what is unlocked, earned or spent in the tunnels, and when they open.
- Ryan, on co-op: the rover is in one place. A rover in the tunnels is gone from the farm, and one on the farm is not in the tunnels. The host keeps the place, and it is saved; an older save has the rover on the farm. Protocol 6.
- Whoever drives the rover, or anyone if nobody does, takes it in or out with E from the pad. The host checks that it is within 6 m of the pad's middle, as it hears of a friend's rover late [PLACEHOLDER]. A player in the other scene sees no rover, "NO ROVER HERE" on the phone, and where the rover is. E from anywhere there goes to the rover's scene without one [ASSUMPTION]. If nobody drives it, whoever is there may, so a friend who leaves while inside doesn't keep it.
- The host takes no word from a guest on the rover in the scene it is not in, or in the rock. One loaded in the rock is back at the mouth [ASSUMPTION].
- Ryan: Continue after quitting in the tunnels opens the tunnels, with the rover where it was parked. Anything else opens the farm, as before, also quitting in the dome. If the rover was left inside by then, it is out on the farm where it went in [ASSUMPTION]. A hosted farm is saved by the host, so it opens by where the host was [ASSUMPTION]. A friend who joins starts on the farm, as before.
- Cobalt Sentinel: Ryan approved the plan. A rare morning chance near the sump, a slow and dim approach, and a catch cup whose humidity is matched with a calibrated hygrometer. It gets a tank of its own in the dome, is caught once and kept, and never dies: unhappy, it only gives no silk. Its spool cuts the relay lag to × 0.30. The Mars export will need it later.
- First slice: the tank and the silk. Finding and catching it are below. Only the host's game can record a catch.
- Its ideal is 22 °C and 80 % relative humidity [PLACEHOLDER]. The art bible gives only the tolerances, ±3 °C and ±8 %. A value not set holds the molt; it is never read as 0.
- The dome has one hygrometer and nothing to set humidity with, so the tank's humidity is its ideal plus the hygrometer's error, and is read on the same hygrometer [ASSUMPTION]. Its molt pauses outside its own tolerance, which is wider than the limit that pauses the Curlyhair [ASSUMPTION]. Temperature counts only once the thermometer is in service. Its light is red when paused, else as in band.
- It molts as fast as the Curlyhair, one spool a molt, each on its own [ASSUMPTION]. Collecting gives the same XP [ASSUMPTION].
- Installing takes the whole spool with the biggest cut. A better whole spool may replace a whole one, which goes back into stock. Building a robot uses damaged spools first, then the plainest [ASSUMPTION, all]. With only Curlyhair silk nothing changes but the log's words, "the old one taken out".
- COLLECT SPOOL cards stay with the Curlyhair's spool [ASSUMPTION].
- The tank stands at the dome's left front [PLACEHOLDER]. Protocol 7; the shared-rover work takes 6.
- Open with Ryan: the Sentinel's ideals, molt length and silk grade, whether its tank should have a hygrometer and mister of its own, and whether robots may collect its silk.
- Finding it: each morning, until caught, it is out on the sump's east shore at (-19, -24) m with a 10 % chance, plus 10 % for each morning since it was last scared [PLACEHOLDER]. The host rolls it once a day from the saved generator. Unmet, it is gone or not by the next morning's roll; scared, its chance starts over [ASSUMPTION].
- Within 8 m it bolts from the rover's lights, from more than 3.5 m/s, or from a rover closer than 1.8 m [PLACEHOLDER; the last is an ASSUMPTION]. L turns the rover's lights low or on, in the tunnels only; they are on until turned low, and saved [ASSUMPTION]. Two beams in the model's amber #F5A623: energy 3.0, range 11 m, 28 degrees [PLACEHOLDER].
- The catch cup, with E from a stopped, dim rover within 4 m: it starts at 55 %, MIST adds 5 %, VENT takes 2 %, and closing it is the one try. The cup is read on the dome's hygrometer, the only one there is [ASSUMPTION]. The true humidity must be within ±5 % of its ideal [PLACEHOLDER], so a new farm's hygrometer, out of tolerance, loses it unless allowed for. The panel shows only the reading and the last calibration's state; after a miss the phone says too damp or too dry. It never dies: it hides until another day.
- Only the rover's driver, or anyone if nobody drives, uses the cup and the lights. A friend may catch it, and the host decides. Protocol 11.
- The tank's heat lamp is dimmed from 0.8 to 0.3, as the crib model is brighter inside [PLACEHOLDER].
- Its model is Ryan's body and legs, on our own rig, with the legs set to meet the body and the floor. The wild one is four times the size of his, to be seen [PLACEHOLDER]. Its tank is Ryan's crib with see-through top and front glass; the spider built into the crib's grid is left out, as ours moves. Its size in there is three quarters of his, to fit [PLACEHOLDER].
- Ryan's underground models stand in the tunnels, to look at only: the grotto in the alcove off the mouth chamber, the sump in the northwest chamber's corner, the seam wall and the pillar vault in two dead ends at the magma [PLACEHOLDER]. Each stops the rover and, but for the low sump, the signal, and none hides floor from the camera. The rover parks beside the vault; its passages are too narrow. Their crystal cubes are unlit, as the only small crystal model is the ore fissure, which would look mineable [ASSUMPTION]. The shale tunnel is too narrow for the rover and not placed; there is no stair model.
- The sump's pool: the rover drives the shelf, 0.48 m down, and deep water, 0.96 m down, stops it but not the signal [PLACEHOLDER; ASSUMPTION]. Water does nothing to the rover [ASSUMPTION]. A rover an older save left in the deep or in a model is back at the mouth [ASSUMPTION].
- Water (`VoxelWater`): columns tinted from #2c5e6b to #244858 by their known depth, no glow, a lighter edge and a ripple in steps. It takes an area, a level and a function for the ground, so a pit, a cistern or a ford can use it. It is opaque [ASSUMPTION]; sizes, steps and pace are [PLACEHOLDER].
- No height change, and only the arch's box changes: the ground uses smooth vertex normals, which removes the sawtooth shading along slopes, and a ground shader (assets/shaders/ground.gdshader) draws steep faces, over about 20 degrees [PLACEHOLDER], as strata in Ryan's reds (P1 #a8422b, P2 #8e3522, P3 #6e2617, D1 #c26b4a), a band every 0.25 m [PLACEHOLDER] with a wobble so the layers are not level [ASSUMPTION]. The strata cover 0.8 of the ground color, with a dark seam (0.85 over 0.18 of a band) and a wobble of 0.3 at 1.7 and 2.3 per m [PLACEHOLDER].
- Magma gets an orange glow, the one exception to the no-glow rule that Ryan approved: dark crust plates of about 0.9 m with cracks 0.12 m wide, in 0.125 m steps, drifting every 0.5 s by 0.35 of 0.25 m, crust (0.17, 0.05, 0.03), crack (1.0, 0.45, 0.07), hot (1.0, 0.8, 0.25) [PLACEHOLDER all]. Only the top face glows. No new light spill [ASSUMPTION]; the old amber lights stay.
- Shrubs vary by a position hash, so the random stream and the placement are unchanged: 6 muted green and ochre tints, width 0.8 to 1.0 and height 0.85 to 1.25 of the model [PLACEHOLDER], and 40 % use the looser mesa scrub bush from the pack instead of the bitterberry model [ASSUMPTION].
- The arch is drawn 1.25 times larger, box included [PLACEHOLDER]. Turning it to face the camera was tried at all four diagonals and read worse (a dark slab, or an edge), so it keeps its quarter turn [ASSUMPTION]. The bigger box moved the plants' hash, since shrubs keep clear of rocks.
- Buried reference blocks, the first digging reward (Ryan approved). A gauge block is a length standard and no sensor here measures length, so the blocks are angle blocks: they check the two instruments in degrees, the rover's steering encoder and the relay dish azimuth, and nothing else. Other quantities are refused with the reason [ASSUMPTION].
- The seed and the cell alone say which 2 m cells hold a block, 1 in 30 [PLACEHOLDER], so a reload or another PC rolls nothing. A cell gives its block the first time it is dug and never again, even filled and dug anew. The save lists the cells found and is refused if one holds no block. An older save loads with none, and its already dug cells give theirs on their next dig [ASSUMPTION]. Protocol 8.
- A block is certified at 15, 30 or 45 degrees [PLACEHOLDER], with U = 0.02 degrees at k = 2 [PLACEHOLDER]. Its true value is off the certificate by a hidden amount within that. Blocks belong to the farm and are kept and reusable, not used up [ASSUMPTION]. Nothing is spent or earned.
- Q checks a sensor with a block while the rover stands (an existing key, no input-map entry): the relay dish within 8 m of the mast [PLACEHOLDER], else the rover's steering encoder. A guest's check goes to the host as `check_with_block`. The log line gives the block, what the sensor reads, the error with its uncertainty, and the verdict against the MPE: within only if error plus U is inside it, outside only if error less U is outside, else unclear. U covers the block and the sensor's digit (GUM). The reading is the true angle plus the sensor's true error, so a check can show an error that zeroing against an off standard hid. It changes nothing: not the sensor's error, drift or the calibration log.
- A check uses the last block found [ASSUMPTION]. Finding one posts a log line with the hint, only to a player on the farm at the time [ASSUMPTION]; Q works for everyone. No new HUD and no model: no gauge block exists among the assets.
- Open with Ryan: kept or used up, a length sensor so real gauge blocks fit, and other finds (a temperature fixed point) for the other quantities.
- The ford, the first surface water (Ryan approved the gulch ford and a shallow wash under the arch). Where: a pool 12 m by 7.4 m at (63, 8.0), directly south of the mesa arch. The arch's own solid box covers z 1.75 to 4.25 and the hill it stands on has no room to cut a wash through it, so the pool sits beside it at its foot, not under it [ASSUMPTION]. The gulch on the farm is level ground and in use, so it was left alone. It is a short drive from the farm and clear of the plot, pad, spawn, gate, relay, calibration pad and tunnel mouth (a test checks each).
- A carve [ASSUMPTION]: the pool is cut into the land, by height, with one rule in Terrain. Away from it the land is unchanged (a hash test covers every point outside the cut). The numbers are [PLACEHOLDER]: water at 1.7 m; shallow floor 0.4 m below it, deep floor 1.0 m below it; lip 0.3 m above; deep ellipse (63, 7.9) radii (4.2, 1.2); cut reaches 1.6 widths out; fades in over 3.4 m north of z 4.3. The north bank by the arch is steep, about 37 degrees, so the 15 degree land test skips the cut and a ford test holds banks to 40 degrees.
- The cut moved the land hash (test_hills) and the plants hash (test_hill_dressing): plants and rocks keep out of the cut's reach, so no shrub, block or boulder stands in water. Reference blocks are unchanged: a wet cell cannot be dug, so no block there can be reached. Ore pockets keep out of those cells.
- The rover drives the shallows, at 0.7 of its speed and with no damage [PLACEHOLDER]. Water 0.6 m deep or more stops it with invisible boxes on the world layer, like the sump's, covering the deep cells but for slivers 5 cm wide no rover can reach, and 3.0 m over the water, so the rover cannot drive on from the high north bank [PLACEHOLDER]. The uplink does not see them. A rover put back on land goes south until its whole footprint is clear of the deep; one over it by a corner only is left to the physics [ASSUMPTION]. Row z 9.8 is the ford line: wet in the middle and drivable its whole width, tested and checked live. No swimming, flow or rain.
- Digging is refused in the water and within 1 m of it [PLACEHOLDER], with "Too near the water to dig.", and the dig outline is hidden there. An older save with dug cells there keeps loading and driving: the bed ignores them, so the water holds, and deep digging right beside the zone can leave a side of about 2 m per 1 m, and filling beside it can be refused, since a save with a steep side is refused [ASSUMPTION]. Nothing is added to co-op sync: the pool is constants, so host and guests agree on ground.
- Ore pockets, the second digging reward (Ryan approved: hinted by a survey reading, so a drifted sensor points to the wrong spot). 6 cells on a farm, 2 crystal ore each [PLACEHOLDER], picked by the seed alone from cells that can be dug and hold no reference block. A fissure gives 1 and the 8 fissures come back daily, so all the pockets are a day and a half of fissures, once. A pocket comes up on the cell's first dig, once only, with the same record and older-save rule as the blocks, and gives no XP [ASSUMPTION]. Protocol 10.
- V surveys while the rover stands on the farm. Its coil turns with the steering until the ground answers strongest, and the steering encoder reads the angle [ASSUMPTION]. The bearing is clockwise from north (-Z, up and to the right on the farm view), to the nearest pocket not dug up within 40 m [PLACEHOLDER], plus the encoder's true error. At 40 m the MPE of 4 degrees is 1.4 cells off, the 12 degrees the encoder can drift is 4 cells. The rover's own heading is taken as true [ASSUMPTION].
- The log gives the bearing and says it is good to the MPE if the encoder is within it; the distance, the true spot and the true error are never told. No usable encoder gives a reason and no reading. A survey costs no time or credits and changes nothing [ASSUMPTION].
- A teal line 40 m long shows the reading on the ground for 20 s [PLACEHOLDER], on that screen only. In co-op the host works the survey out with its own encoder and the place it has for the rover. Only the asking screen checks that the rover stands, as for digging [ASSUMPTION]. The line is 0.16 m wide, 0.16 m above the ground, in 0.5 m steps [PLACEHOLDER].
- Changing hills, rocks or the block odds moves the pockets. A save keeps the cells it found, so it still loads, and pockets that moved can be found again [ASSUMPTION].
- Open with Ryan: whether pockets ever come back, ore in each, survey cost, and an icon or sound for a find.
- Stone from boulders, the third digging reward (Ryan approved): the hit that breaks a boulder gives the farm 6 stone [PLACEHOLDER], so the four boulders give 24, once each. The stock is the farm's, like credits: shared in co-op, saved (an older save gets it for each boulder already broken [ASSUMPTION]), checked on load (a whole number from 0 to 100000 [PLACEHOLDER]) and shown to guests by FarmSync. The log says "STONE +6 (total)"; a guest sees no total. No new HUD, and the phone is unchanged. Protocol 12.
- B builds the chosen piece on the 2 m cell in front of the stopped rover (the cell dug and filled), or takes up the piece there for all its stone; N cycles wall, pad, channel and says which in the log [ASSUMPTION: B and N were free]. Costs 2, 1 and 1 stone [PLACEHOLDER]. A guest's press goes to the host as `place_stone`, which also works out where the rovers stand. A press asks to build or to take up, and the host refuses it if the cell is no longer as the screen showed. Taking up never loses stone (below the 100000 cap), and building and taking up on a cell again and again leaves the stock as it was.
- Refused with the reason: no stone; ground that can't be dug (the plot, pads, gates, props, the relay, the spawn, the land's edge) or is by a rock; a piece already there; off the ground. A wall is also refused where a rover stands (a footprint of 1.6 by 2.4 m) and where it would shut a rover in on all four sides [PLACEHOLDER; ASSUMPTION]. A pad or a channel may go under a rover, as it drives over them. A rover in the other place is not counted. A cell with a piece can't be dug or filled; take the piece up first.
- Wall: stone boxes in the boulders' palette (#807a73, #6b665f), 1.1 m over the cell's middle and down to its lowest corner, 95 % of the cell wide [PLACEHOLDER], so a slope hides none of it and nothing floats. It is a StaticBody3D on layer 1, as the rover collides with, and not on layer 3, which the uplink's rays use, so it blocks the signal only as far as the signal's own mask does (it doesn't) [ASSUMPTION].
- Pad: four slabs of 1 m, 0.16 m thick, each tilted to the ground under it, in two greys. The ground's height is unchanged, so the rover may sink about 0.1 m into one [ASSUMPTION]. Channel: dark basalt slabs (#232832) with lips (#495261) 0.3 m high on the sides that don't meet another channel, a groove to drive in. It does nothing else: `GameState.channel_cells()` lists them for the water to come. No water is made.
- Open with Ryan: how much stone, what each costs, whether a pad should level the ground (and so be a place for a pump or a pad), and what runs in a channel.
- Water in dug pits (Ryan approved: pits hold water, a stepped column tint, the rover drives shallow water and deep water blocks it, dug ground stays). It is worked out from the dug steps, the stone pieces and the land alone: nothing is saved, sent or random, so every PC finds the same water. Drawn with `VoxelWater`, in #2c5e6b to #244858, no glow.
- What triggers a recompute: only a change to the dug steps (`GameState.dug`) or to the cells holding a channel piece. The view checks this when `terrain_changed` or `stone_changed` fires, by comparing copies of both with what it last worked from (a plain equality, no hash). A boulder, a wall or a pad changes neither, so it costs nothing, and neither does the second signal of a load. Any number of changes in a frame make one look, put off with `call_deferred` to the end of the frame. `_ready` looks at once, so the water and its blocks exist before the first physics step of a loaded farm [ASSUMPTION]. Nothing runs per frame.
- The ground seeps [ASSUMPTION]. Dug cells joined side to side or corner to corner, each 3 steps or more down (SEEP_STEPS 3 [PLACEHOLDER]), are one pool. Its water level is 1.0 m under the lowest natural ground in it (TABLE_M 1.0 [PLACEHOLDER]), but never above the lowest ground round it, so water lies level, never floats and never spills over a rim; the border between a wet and a dry cell follows the lower of the two, and the test samples it along its length. A pool the level does not rise 2 cm above its floor (MIN_DEPTH_M 0.02 [PLACEHOLDER]) is dry. Changed from 2 steps and 0.5 m after review: a wet 3 step floor was deep, so the rover could not reach the middle to dig the 4th step. Now 2 steps is dry, 3 is shallow (0.5 m) and 4 is deep (1.0 m), and a test digs a 4 step cell on flat wet ground with every 3 step cell round it not blocking.
- Depth follows: a 3 step pit is 0.5 m of water, shallow, and only 4 steps is deep (0.6 m or more, as the ford) [ASSUMPTION]. Shallow water slows the rover to 0.7 as the ford does, from 0.1 m of depth (WADE_MIN_M [PLACEHOLDER]). Deep water stops it, and a walker, with invisible 0.5 m boxes merged along x on the ford's layer, from 1.0 m under to 3.0 m over the water, and `Terrain.is_deep` also counts pit water, so the ford's own rules for a rover that ends up in deep water still apply. The box's depth is worked out once per 0.25 m lattice point, not per box.
- Getting out when a dig turns the ground under someone deep [ASSUMPTION]. Rover: the nearest spot in any direction (24 directions, 0.25 m steps, up to 16 m, 0.1 m clear) where its whole 1.6 by 2.4 m box, nose included, is clear of pit water and ford blocks (an oriented-box test), then rechecked against rocks and stone walls; the ford's `clear_of_deep` and its behaviour are unchanged. Walker: the nearest spot where its 0.3 m capsule is clear (same search), moved at once, speed zeroed, and `CoopWalkers.moved` called so a guest's reset watch does not pull it back. Both run when the deep blocks change, and tests stand a rover and a walker where it turns deep, and dig from all four sides at 1 to 3 m.
- A stretch's water draws only its own cells (the level is -INF elsewhere), so separate water in the same box is not drawn twice or stale. Channels [ASSUMPTION]: a channel in or touching a wet pool carries a film 0.08 m over its floor along its whole run (FILM_M [PLACEHOLDER]), whatever the rims; it rides the ground, so it is not level, and is too shallow to slow a rover. Dimples of exactly 1 step touching a fed channel, lower than it, fill to their own rim; a 2 step cell does not. An unfed channel carries nothing, and taking a stone away stops its film at once.
- Digging and filling stay possible in wet pits, so nobody is trapped: filling a pit down to 2 steps dries it. No new saved state, so no protocol change.
- Cost, measured on 287 dug cells with six pits (work out, blocks, and the view's redraw of its VoxelWater, in the editor's headless run, one machine). Before the review: working out 10.5 ms, blocks 107 ms, full view build 284 ms, one-cell change 147 ms, no change 122 ms. Now, same fixture and old constants: 1.3 ms, 5.6 ms, 74 ms, 21 ms, about 10 ms by one measurement; with the new constants (45 wet cells, 9 blocks, not comparable) 0.7 ms, 1.0 ms, 30 to 87 ms for a full build on load, 7 ms for a one-cell change. The later probe showed a no-change look costs microseconds, as the test proves nothing is recomputed. So a dig is well under 50 ms; the first build on load is 30 to 90 ms, mostly VoxelWater drawing, once. Timings are told by the test, never asserted, as a busy machine says nothing about the code.
- Doubt, not settled: a guest's walker is teleported out of a pit locally. The host judges its next move against the burst budget (12 m) and its land and height checks; a short move is accepted, and one that is refused is tried again each time the host puts the walker back. Only a pit more than 12 m from its shore could still hold a guest.
- Open with Ryan: whether a wet pit should seep slowly after a dig, whether channels should need a downhill run to carry water, and whether deep water should ever be swum.
- Playtest text fixes. Humidity differences (sensor error, MPE, U) print as "percentage points", since SP 811 does not allow "% RH" and a difference of two relative humidities is not a share of the reading [ASSUMPTION]. Soil moisture keeps "%", and the phone HUD is unchanged. tools/check_sp811.py is not taught a rule: it cannot tell an RH difference from an absolute RH by text alone.
- One overdue wording everywhere: "OVERDUE since day N", N being the day after the due day, so never "day 0" [ASSUMPTION]. `DriftingSensor.overdue_text` makes it.
- The Sentinel's rules ("Lights low (L), creep, stop short.") go to the phone log once per sighting, the first time the rover is within its 8 m, before any scare line; no speed readout. A bolt or a catch starts a new sighting. The told flag is not saved [ASSUMPTION]. A failed catch with a reading inside the 5 % cup band adds "The hygrometer read N %. Was it right?" to the host's phone line, so guests get it with the phone log and the protocol is unchanged [ASSUMPTION].
- Terrace models (models only, not placed; Ryan's terrace pack as layer grids in `tools/voxgen/sheets/`): ramp, mid deck, upper bluff, endcap and switchback are built voxel for voxel from his scripts; letters map to the repo's colors (P1..P4 the boulders', D1, K1, F1/F2, EC the teal, S shadow) and O1 is his `#C97A3B`. [ASSUMPTION] The rim overhang shelf had only a summary: its Z=2 cells under the S recess (X=3..6, Y=2..3) are P1, so the recess does not float, and X=0 and X=9 are empty at Y=2..3 as written. Its other layers, Z=0's two rows and the empty cell at Z=1, Y=1, X=9 included, are the summary's. [ASSUMPTION] The upper bluff was built too, as it belongs to the pack. [ASSUMPTION] The switchback follows `build_terrace_switchback_vox.py`, the later of his two scripts by file time (4 s) and the one with EC in it as his summary has (8 voxels; the other has 2). It does not match his summary on every row (Z=0, 1, 3, 6, 7 and 11 differ); the other script matches those rows but not the EC, so neither fits. Open with Ryan: which is final? Ramp: his summary and his grid disagree (the summary's steps rise toward +Y at Y=9-z; the grid's shadow is at Y=z-1 with the mass toward -Y); the grid was built. Open with Ryan. [ASSUMPTION] Part `rock`, EC as `emit_crystal`; the border pass puts S around EC (8 voxels each, under the 9-voxel cutoff). Doubtful: the ramp does not read as a ramp, and the S cracks and recess read near black.
- Cistern. The farm's water cistern holds `GameState.cistern_liters` (saved, so old saves load full; a new farm starts full). It runs down with time and fills again at every 06:00, once per day, by every path that starts a day (they all go through `GameClock.advance`). Time-based, so frame rate and step size do not matter. All [PLACEHOLDER]: capacity 600 L; a draw of 0.16 L per growing plot per hour. 36 growing plots use about 140 L a day, a full plot of 144 about 550 L (92 % of the tank), so with these numbers it cannot run dry in play. [ASSUMPTION] The draw runs around the clock, not only in daylight. [ASSUMPTION] Only plots still growing draw; a ripe crop is not irrigated. [ASSUMPTION] The refill is the whole tank at 06:00, as Ryan said it refills overnight.
- Cistern, what is shown. Inspecting it adds "Cistern: 420 L of 600 L." (with " Empty." at 0) to its line, in SP 811 units. A sight glass on the tank (`CisternGauge`: a steel frame, a dark slot, water in #2c5e6b going to #244858 as it falls, 20 steps [PLACEHOLDER], no glow, the water drawn unshaded so it reads in the tank's shade, and dimmed with the farm's ambient light so it does not glow at night) shows the level. Guests see the host's level through the whole-farm sync that already carries the saved variables, so the protocol is unchanged [ASSUMPTION]. The phone HUD is untouched.
- Open with Ryan: what an empty cistern does to the crops. Nothing does yet: moisture, growth, crops and money ignore the level, and the level stops at 0. Whether crops dry out, irrigation stops, or the player must haul water is his to choose.
- Suit colors in co-op. Each walking character has its own suit, the same on every screen, with no protocol change: the color comes from the roster every screen already has (`CoopSession.players`, the host first, then guests in join order) and the number in a guest's id. The host and solo stay orange #d9772b [ASSUMPTION]. Guests have 4 [PLACEHOLDER] suits: blue #2b4fb0, light lilac #d9b8f2, green #2f7a3a, off-white #e8e6df, apart in lightness as well as hue and none teal, amber or red. A guest prefers the suit for its id number (player_2 the first); if an earlier player in the roster has it, it takes the next free one. So someone leaving recolors no one unless two had shared a preference, and no two present players share a suit, as MAX_PLAYERS leaves at most 3 guests [ASSUMPTION]. A rejoining guest keeps its id and so the color it prefers. Boots, pack and visor are unchanged; shoulder pads are the suit 25 % darker.
- Walker model: the arms hang from the shoulder and swing against the legs, up to 0.45 rad [PLACEHOLDER]; two side tanks and a mast on the pack; the mast stays under the head's top, so the model is still 1.6 m tall. Visual only, no change to the collision.
- Terrace rows on the hills. Ryan's `terrace_mid_deck`, `terrace_upper_bluff`, `rim_overhang_shelf` and `retaining_wall_endcap` stand as 11 rocks in four rows [PLACEHOLDER] (`HillDressing.ROCKS`), seated, solid and undiggable as the other rocks are. In a row they touch, so nothing is caught in a gap; each row's back is to its hill and its front faces downhill toward the camera [ASSUMPTION]. They block the uplink on the hills as the other rocks do; no level ground loses the relay (tested). The plateau's rim has none: it is under 2 m, the least height for rocks [ASSUMPTION]. The ramp and switchback wait for Ryan.
- Plants and hidden ore pockets near the rows moved, as with earlier rocks; a save keeps the pockets it found. A save with a stone piece where a rock now stands loads and the piece can be taken up, but nothing new is built there [ASSUMPTION].
- A reference block whose cell is now under or beside a terrace piece can't be dug up, as beside the other rocks. A rover moved out of a rock now ends clear of every rock, not only the last one.
- Players getting out of the rover each try a side of their own first, by their place in the roster (left, right, behind, in front), so two who press F at once don't stand on one spot unless a side is blocked: the next one tried may be the other's own. A spot someone stands on is used only if no other is clear.
- The edge of the land stops a driving rover, one wheelbase in, where a load already put it. Before, it could drive off and fall, and beyond 500 m down the host's word of it ended every guest's session. The 500 m limit stays.

- Pit seep (Ryan, Nov 25): a pit no longer fills at once. Ground water rises 0.25 m a day [PLACEHOLDER] from the pit floor and stops at the level the pit would reach in the end. The host works it out on its clock (every 0.005 day; a long sleep fills at once) and saves it as `pit_seep`; guests are told. An old save starts with full pits. Review: the water shows in whole centimeters rounded down, never above its end level, and exactly at it once reached; a seep change is sent only when that shown water moves, and a dig sends one only if the numbers changed.

## Cobalt Sentinel: real care numbers (2026-11-25)
- Ryan: the Sentinel (real species Cyriopagopus lividus, formerly Haplopelma lividum) uses real cobalt blue tarantula care figures instead of invented ones. Sources and URLs are in `_source` in `data/tarantula_species.json`.
- Temperature: four sources read 20-26 °C (The Tarantula Collective), 23.9-27.8 °C (Exotics Source, 75-82 °F), 23.3-27.8 °C (The Defiant Forest, 74-82 °F) and 25-30 °C (Bantam Earth). All four overlap at 25-26 °C. The game has one ideal, so it is 25 °C, the low end of that overlap and the midpoint of the 24-26 °C overlap of the first three (was 22 [PLACEHOLDER]).
- Humidity: 75 to 85 % in two sources (The Tarantula Collective's figure is from its breeding section; its general care text gives none), and a third says 70 to 80 %. Ideal is the midpoint, 80 %, unchanged but now sourced.
- Tolerances (±3 °C, ±8 %) and lag_reduction_pct (25) are still the art bible's and are [PLACEHOLDER]; no source gives them.
- Molt: only one source gives an interval, 1 to 7 months, stored as `molt_interval_real_days_range` [30, 210] (real-world days), and it is not used by the game yet. No source gives days by life stage or a premolt length, so `molt_days` and `premolt_days` stay unset [PLACEHOLDER]. The tank still molts on the playtest pace (`GameState.PLAYTEST_MOLT_DAYS`).
- Left for GameState.gd (another PR touches it): the comment on `PLAYTEST_MOLT_DAYS` says to use the species' molt_days; it stays correct until a sourced value exists.
- Ore elsewhere (Ryan, 2026-11-25): a dug ore pocket stays empty for good, and the farm grows a new one somewhere else a few days later (`OrePocket.REGROW_DAYS` = 3 [PLACEHOLDER]), so the live count never passes the original 6. The host draws the cell on the morning it is due, from the seed, the dug pocket's cell and the count of pockets grown so far (`OrePocket.replacement`): at least 10 cells away, diggable, dry, no reference block or stone piece, and never a dug cell, a found pocket or a live one. Growth stops at `OrePocket.MAX_NEW` grown pockets so the save stays loadable. A save from before this change gives each dug pocket a due day three days after it loads. The result is saved (`new_pockets`, `pocket_pending`) and reaches guests with the rest of the farm, so a reload or a guest never re-draws. Survey counts the new pockets like the first.


## Gauge block set (Ryan: found blocks are kept and reusable; "like 81 pieces of different sizes to make a grade 00, 0, or 1 set")
- Every buried reference block is also one piece of the standard 81-piece inch gauge block set, so the angle check (Q) and the collection use the same find. Composition: 9 of 0.1001-0.1009 in, 49 of 0.101-0.149 in, 19 of 0.050-0.950 in, 4 of 1, 2, 3 and 4 in = 81 distinct sizes. Sources: https://www.zoro.com/starrett-gage-block-set-01001-4000-in-81-pcs-rs81b/i/G2756442/ and https://littlemachineshop.com/products/gage-block-set-rectangular-81-pieces (also Fowler's 81-piece set). Code: `scripts/metrology/gauge_set.gd`.
- A block's size and grade come from the farm seed and its cell, drawn after the angle so the angles and true values are unchanged. Grade is 00, 0 or 1 at 15 %, 35 % and 50 % [PLACEHOLDER]. That naming is the game's own (Ryan's choice); ASME B89.1.9 names its grades K, 00, 0, AS-1 and AS-2.
- The size draw is kind, so a full set is reachable [ASSUMPTION]. A plain uniform draw needed about 400 blocks on average to hold all 81 sizes, and on some farms never would. Now each block's drawn size is only a first choice: `GaugeSet.pieces` places the found cells best grade first, then by x, then by y (a fixed order, not the order found). A block whose drawn size is already held takes the next free size up, wrapping round. The first 81 placed blocks, which are the best 81 found, make 81 different sizes; any block after them keeps its drawn size and, being no better than a placed one, adds nothing. It depends only on the seed and the set of cells, so host, guest and a reload agree, and nothing new is saved.
- Why best grade first: with a position-only order a newly dug block could displace others and make a full set's grade worse. With the grade sort, adding a block never lowers the number of sizes held and never lowers a full set's grade (the set is always the best 81 found). Which size a particular block fills can still shift when another is found, so only the grades of the set are guaranteed, not each size's. A find is NEW if the set gains a size, BETTER if the sizes held are the same but the grades are better (more pieces of the best grade where they first differ), else DUPLICATE. The phone log names the size the block actually took.
- So a full set needs 81 blocks, and a grade 00 set still needs luck: every placed piece must be grade 00, so it takes about 81 grade 00 blocks, roughly 540 blocks at 15 % grade 00 (or fewer if the spares are dug on purpose).
- Every block is kept (found_blocks keeps every block). Once the set is full, a further block only helps if it is better than the worst of the best 81, which it then pushes out; this is how a full set's grade improves [ASSUMPTION]. A farm that arrives all at once (a load or a join) logs one summary line, not a line per block.
- The set's grade is that of its worst piece [ASSUMPTION]: one grade 1 block makes a grade 1 set. Only a full 81 has a set grade; short of that the phone shows the count and the worst piece so far.
- Nothing new is saved: the set is worked out from `found_blocks`, which is already in SAVED_LATER and which `farm_dict_problem` already refuses unless every cell holds a block. So an old save loads with an empty set, a made-up piece cannot be loaded, and the host owns it. A guest is told through the farm it is sent, and no guest command names a piece; its dig goes to the host.
- Shown on the phone as one line under the molt row, "GAUGE SET n/81 ..." (hidden until a block is found), and a second log line on each find says the size, grade and whether it is new, better or a duplicate. No restyle.

## 2026-11-25: Four looks fixes (Ryan)
- **Suits:** unchanged. Each player already has a distinct suit by roster place (host orange, guests blue, lilac, green, off-white), the same on every screen through `WalkerModel.suit_for`. A test now pins the host and first guest apart. **Boots** are `BOOT` #6b7686 (were the dark gear #1d222b) [PLACEHOLDER]; gloves and pack stay dark.
- **Basalt:** `TunnelRock.BASALT` and the copy in `stone_pieces_view.gd` go from #232832 to #353c49 [PLACEHOLDER], still darker than the floor (#495261). No basalt color is in `terrain.gd` or `hill_dressing.gd` (the farm's basalt columns are Ryan's models).
- **Tunnel arch:** the flat 2-slab lintel is now two stepped courses (0.7 m in per course, `ARCH_STEP_M`) under a capstone, so the opening reads as an arch. Pillars and the signal box are unchanged, so the rover and walkers pass where they did; nothing is drawn or solid below `ARCH_LOW_M` (2.3 m) between the pillars. The whole lintel still fades when the rover is near [PLACEHOLDER].
- **Cistern glass:** slot 0.5 x 1.2 m (was 0.3 x 1.0) in a 0.62 x 1.32 m frame, and the gauge sits 0.1 m lower on the tank (y 0.2) so it stays under the lid [PLACEHOLDER].

## 2026-11-25: Stone pads level the ground, walls follow the slope (Ryan)
- **Pads:** a group of pads (touching, corners too) is levelled only if the whole group can be: every point of it within 0.75 m of the natural ground (`PAD_SHIFT_M` [PLACEHOLDER]) and no pad on a dug cell or by the water. A group that qualifies is one flat top at the mean of its natural ground, rounded to 1/256 m, so it is worked out again from the saved pieces alone and host, guest and save agree (`Terrain.pad_levels`, set by `GameState` as `Terrain.level_points`); the ground a meter past the edge ramps to the land as it was. A group that does not qualify follows the natural slope: it is never refused on load and never reshaped, so an old save with a long strip up a hill or a pad on a dug cell loads as it was. Steepness is checked per group when a pad is placed ("Too steep to level."), so one steep group never stops a pad elsewhere; a pad next to a group that cannot be levelled is refused. Taking a pad up may leave a group unlevelled, or levelled differently; the ground follows at once and what stands on it is lifted (rovers and players that are in the tunnels are left alone). A pad is refused where a rover, a player on foot or (not checked) a robot stands on any cell of the group, and where its edge would be too steep for the rover to climb (`PAD_STEP_M` 0.9 m, the rover's 45 degree floor [PLACEHOLDER]); digging beside a pad is refused the same way. The edge rule is checked only when placing a pad and when digging beside one, not on take-up or load, so an old save or a take-up can leave a steeper edge. Joining pads that would move an existing pad's top by more than 0.75 m is refused; in practice a guard, since hills rarely reach it. Guests are told through `terrain_changed` when pad levels change (no new saved variable). The ground under a pad still cannot be dug, filled or tilled. Pit water is settled again by the host when a pad moves.
- **Walls:** a wall already stood on the ground cell by cell (base at the lowest of its 9 points, top 1.1 m over its middle, solid box to match), and no rule refused it for slope: what refused a wall straight ahead of the rover was level ground, where nothing is built (the farm's 33 m, the relay and the road), not the hills. Kept: stepped tops, one per cell, so what is drawn is what blocks. New refusals for walls and pads: by the water, and for a wall where the ground rises or falls over 1.5 m across its cell (`WALL_RANGE_M` [PLACEHOLDER]; hills alone come to 0.5 m, so only a dug side or a pad's edge can reach it). **Open with Ryan:** whether pieces may go on the level farm ground itself.

## 2026-11-25: The host checks what a guest says about where it is
- A guest's walker or rover pose, or a command at a cell, is judged by the host before it is taken. No wire change, so the protocol stays 13 [ASSUMPTION]. A pose that is the wrong shape (not 5 or 6 numbers, a number that is not a float) still drops its sender; a well-formed one that is not real (NaN, infinite, beyond 500 m), off the land (a rover on the farm more than 2 m [PLACEHOLDER] past the 80 m edge; a walker off land or in deep water), above a speed (walker 5 m/s, rover 7.5 m/s) or farther than the distance allowed since the last one is only refused: the host keeps the last good place and never drops the guest for one packet. A refused rover pose ends that drive and the guest is told where the rover is. A refused walker pose is held: everyone else sees the walker at its last good place, and the guest's own screen only snaps back once it is more than 17 m (SNAP_M) from it. A refusal is logged at most once every 5 s [PLACEHOLDER] for each guest.
- The jump allowed at once is now 18 m for both a walker and a rover (was 12 and 15) [PLACEHOLDER], because the dig that floods a spot sends either up to 16 m (`PIT_SEARCH_M`) and the host used to refuse that. Other jumps need nothing: getting out is placed by the host, and the rover entering or leaving the tunnels, a join or a loaded farm all clear what the host remembers, so the next pose starts from the new place. The walker snap distance is 17 m, still under the jump.
- A guest's command at a cell (`dig`, `fill`, `till`, `plant_crop`, `harvest_crop`, `place_stone`, `adjust_setpoint`) is refused with "Too far from the rover." if the cell's middle is more than 6 m [PLACEHOLDER] from where the host has the farm's rover (the rover digs 2 m ahead, a cell is 2 m, and the host's word lags a little). A guest on foot can do none of these already. Not judged: the host's own commands, the rover in the tunnels, a rover whose place is not known. Commands that carry no cell (survey, check, collect) already use the host's place for the rover.

## 2026-11-25: Skills go to level 99 (build order step 1 of quests_levels_story.md)
### Ryan chose
- Levels go to 99 on a geometric curve, about 150 hours to 99 in one skill; an old save loses nothing (docs/design/quests_levels_story.md §10, decisions 3 and 5).

### Agent's notes (flagged for Ryan, not his words)
- **The curve** (`data/skills.json` `level_curve`): going from level n to n + 1 costs 50 × 1.10^(n − 1) [PLACEHOLDER], top level 99. Totals: level 2 is 50 XP, 10 is 679, 25 is 4 425, 50 is 52 859, 75 is 577 634, 92 is 2 921 662, 99 is 5 693 968. All three numbers are data; the code reads them.
- **XP sources are today's × 5** [PLACEHOLDER], the table in §2.3: `calibrate_player` 50, `calibrate_found_oot` / `calibrate_on_time` / `calibrate_clean_tur` 25, `clean_audit` 100, `buy_standard` 75, `calibrate_standard` 100, `collect_spool` 50, `slot_spool` 25, `mine_fissure` 10, `till` 5, `build_robot` 250, `commission_robot` 125, `robot_job` 5, `calibrate_robot` / `calibrate_robot_player` 25.
- **Tier multiplier** (`calibration_tier_xp`): every XP source of a calibration is multiplied by 1, 1.5, 2.5 or 4 for a Tier 0, 1, 2 or 3 standard [PLACEHOLDER], rounded to a whole XP. The tier is that of the standard the work was checked against, so a standard on the bench is scaled by the standard above it. Built now because it is a rule about sources that exist and no later step owns it.
- **Open: the hour budget is not met.** §2.3 says so itself: × 5 fits levels 1 to 25 only. Paid jobs, crops and quests give no XP until steps 2 and 5, and the spreadsheet pass has not been done. Until then the high levels are far out of reach by play. That is a gap, not a choice.
- **Effects** (`level_curve/effect_share`): a level has 25 % of an effect's full cut at 10, 50 % at 30, 75 % at 60, 100 % at 99, straight lines between, 0 at level 1 [PLACEHOLDER]. `full` is what old level 10 had: bench time 72 %, as-left residual 45 % (floor 0.5 kept), molt time and steering wear 27 %. Operator uncertainty's `full` is 70 %, not the 90 % that nine old levels of 10 % add up to: its floor of 0.3 was reached at old level 8, so 70 % is what an old level 10 really had, and the floor is reached exactly at 99. The SKILLS view shows effects to 0.1 % because early levels move them by less than 1 %.
- **Unlocks keep their level numbers** (§2.4): `molt_on_phone` at Husbandry 3 (105 XP, was 150) and `budget_view` at Uncertainty 5 (232 XP, was 500). With sources × 5 they open much sooner than before [ASSUMPTION that this is wanted; they are early teaching tools].
- **Robot gates moved, so they cost about what they did** [PLACEHOLDER] (`data/robots.json`). Left alone, building one robot (250 XP, level 5) would have opened the second robot and the CALIBRATE card at once. A second robot needs Robotics 10 (679 XP; was level 3, 150 XP × 5 = 750), each further robot 9 more levels (was 2). The CALIBRATE card needs Robotics 15 and Calibration 10 (was 4 and 3). COLLECT SPOOL stays at Robotics 2 and the second card slot at 2: one built robot opened both before and still does. Known gap: the levels are linear and the curve is not, so a fourth robot (Robotics 28, 6 055 XP) costs a little more than before (old level 7, 5 250 XP after × 5). The design moves robots to the lab level in step 9 anyway.
- **Old saves** (§2.5). `SaveGame.VERSION` stays 1: raising it would refuse every old save. The farm saves a new field, `skill_curve` (2). A save without it is from the 10-level curve and is converted as it loads, farm skills included: XP × `old_curve/xp_factor` (5 [PLACEHOLDER]), which never lowers a level (old level 10, 2 250 XP, becomes 11 250 XP, level 34). A save with any other `skill_curve` is refused.
- **Effect floor.** Conversion also stores `skill_effect_floor`: per owner (a player id, or the farm) and skill, the share of the full effect the save had, 0 to 1. Where a skill has two effects the larger share is kept [ASSUMPTION], which can give the other effect slightly more than it had, never less. An effect uses the larger of the floor and its level's share. Nothing else writes the floor, so it never rises and a new farm has none. A converted save, saved again, is a new save and is not converted twice.
- **A guest's own file** (`user://coop_player.json`) now says `"curve": 2`. A file without it has its XP × 5 when read. **Open:** the effect floor is the host farm's, so a returning guest keeps their floor on a farm that knew them, but a guest's file carries XP only; on a farm that never knew them they get the level's share. A host on this build and a guest on an older one is not handled (the co-op protocol number is unchanged) [ASSUMPTION: everyone updates together].
- **Not built, as told:** no lab level, no quests, Instrumentation stays a farm skill with its XP, jobs and crops give no XP yet.
- Design doc nits folded in: the conversion factor is a placeholder to be set again with the sources; "a second way through every gate" now names the lab-level gate only; the lab-size multiplier does not apply to quest lumps; quest gates apply from step 5, the unlock table's from step 9.

## 2026-11-25: Jobs and crops give XP, and each player's work is counted (build order step 2 of quests_levels_story.md)
### Ryan chose
- A paid job gives the player who finishes it pay ÷ 2 as Calibration XP, plus pay ÷ 4 as Uncertainty XP when it is on time and traceable; the job's discipline is not used. Crops give XP, to Field Ops until Agronomy exists (docs/design/quests_levels_story.md §2.3 and §9 step 2).

### Agent's notes (flagged for Ryan, not his words)
- **Job sources** (`data/skills.json` `xp_sources`, all [PLACEHOLDER]): `job_done`, Calibration, 0.5 XP per credit; `job_clean`, Uncertainty, 0.25 XP per credit, only when the job was on time and traceable. A source with `per` is a rate: the code multiplies it by the credits and rounds to a whole XP.
- **"Pay" is the credits the job paid, after any cut** [ASSUMPTION]. A late job (50 % cut) or an untraceable one (75 % cut) still gives Calibration XP, on the smaller pay, and no Uncertainty XP. A Trusted job (100 to 150 CR) done clean gives 50 to 75 Calibration XP and 25 to 38 Uncertainty XP; an Accredited one (320 to 400 CR) 160 to 200 and 80 to 100. The other reading, XP on the pay offered, would make a botched job worth as much Calibration XP as a clean one.
- **A job the hired manager finishes gives no one XP**, as with every other source.
- **Crop sources**, all to Field Ops and all [PLACEHOLDER]: `plant_crop` 5 XP for a planting that works (the same as `till`); `harvest_in_spec` 0.25 XP per credit of the crop's price, for a harvest in spec only; `sell_crop` 0.25 XP per credit of what Lin pays for the bin, off-spec crops at their lower price, before fronted seed is taken out (a fronted seed is a loan, not a worse crop). A biscuit reed (24 CR) is 5 + 6 + 6 = 17 XP from seed to sale; a 69 CR crop is 5 + 17 + 17 = 39. §4.1 lists these three as Agronomy's ways to earn; the numbers are mine.
- **Who earns:** the player who plants, the player who harvests, the player who sells. The bin is shared, so the seller gets the sale XP for crops someone else harvested [ASSUMPTION]. To name the player on the host, `plant_crop`, `harvest_crop` and `sell_harvest_to_lin` gained a last `player_id` argument, which `FarmCommands` fills in as it does for `till`. Robots do not plant or harvest, so there is no robot case.
- **The counter** (§5.3) is `GameState.action_counts`: player id → source id → `{ "count", "xp" }`, whole numbers. `_award_xp` is its only writer, so every source is counted, old ones too, from this build on; nothing is counted backward from old logs. It counts the acting player for a farm skill's source as well (who bought the standard), with the XP the farm got. It is counted only when XP is given: an off-spec harvest, a job that paid 0 or the manager's work are not in it. Read with `action_count`, `action_xp` and `crop_xp` (the total from sources marked `"crop": true`). `sell_crop` counts sales (bins), not crops, so a quest that needs crops sold must not read it. Sale XP is rounded once per bin and harvest XP once per crop, so at very low prices the two can differ by batching.
- **`till` is not marked as a crop source** [ASSUMPTION]. Step 4 says "`till`, `dig` and the rest move to their new skills from here on", so XP from tilling before step 4 stays Field Ops, and only planting, harvesting and selling move to Agronomy. Tilling is still in the counter by its own id, so this can be changed at step 4 with no loss, for tilling done from this build on.
- **Saved and synced.** `action_counts` is a farm field added after version 1 (`SAVED_LATER`): a save without it loads with nothing counted and keeps its XP, and `SaveGame.VERSION` stays 1. A save whose counter is the wrong shape is refused. The host's farm snapshot carries it to guests like every saved field, so the co-op wire and protocol number are unchanged. A guest the farm forgets (`_forget_a_guest`) loses their count with their XP.
- **Open: the counter is the farm's, not the guest's.** A guest's own file (`user://coop_player.json`) carries XP only, as before. So at step 4 the move to Agronomy can be exact on the farm where the crops were grown, but a guest's file will still hold that XP as Field Ops. Step 4 needs a rule for it (carry the crop XP in the guest's file, or convert only on the farm). Not decided here.
- **Not built, as told:** no lab level, no Agronomy, no quests, no `crops_sold_in_spec` or purchase counters (§5.3 gives those to the quests). XP for buying from Kestrel is not in step 2 either.
- **The hour budget** is still not set: these rates are the design's rule and my first guesses, and wait for the spreadsheet pass with the rest.

## 2026-11-25: The lab has a level (build order step 3 of quests_levels_story.md)

### Ryan chose

- The design (`docs/design/quests_levels_story.md` §3 and §9 step 3): one lab level for the whole farm on the skills' curve, its feeds, the ×1 / ×3 / ×8 multiplier by lab size, shown on the SKILLS view and the phone, no gates yet, and the save conversion that ends Instrumentation.

### Agent's notes (flagged for Ryan, not his words)

- **The feeds** are `lab_xp_sources` in `data/skills.json`, every value a [PLACEHOLDER] from §3.2: a traceable calibration by a player 25 and by a robot 10; a standard bought 75; a standard calibrated on the bench 100; a finished paid job 0.5 per credit paid; a clean audit 250; a certificate back from OIRM 200; a spool collected or slotted 25; a robot built 250, and 250 again when it is commissioned; a lab area fitted 150; the lab grown 500. They are a list of their own, not `xp_sources`, because they name no skill.
- **The multiplier** is `lab_level/size_xp` (small 1, medium 3, large 8) [PLACEHOLDER], read by the lab's size at the moment the XP is given, and applied to every source. Quest lumps are to skip it (§3.2.1); there are no quests yet, so nothing skips it. The XP for growing the lab is given after the lab has grown, so it is multiplied by the new size [ASSUMPTION].
- **Tier counts too** [ASSUMPTION]. The three calibration sources and the standard bought are also multiplied by `calibration_tier_xp`, as the skills' calibration XP is and as Instrumentation's two sources were: by the standard used, or by the standard bought. A player who calibrates a standard gets both the calibration's 25 and the standard's 100.
- **Too soon gives none** [ASSUMPTION]. Lab XP for a calibration follows the skills' rule: traceable, and not within half the interval of the last one. Without that, calibrating one probe over and over would level the lab.
- **Whose work.** Anyone's: a guest's, the manager's and a robot's work all feed the lab. It is counted in `action_counts` for the player who did it (a robot's for who programmed it), never for the manager, and not for what no one player did: a clean audit, a certificate coming back, the lab grown.
- **The conversion** is marked by `skill_curve`, now 3. A save with no marker (10-level curve) gets stage 1 and then stage 2; a save that says 2 gets stage 2; a save that says 3 gets nothing, so re-saving cannot credit twice, and a new farm starts at lab level 1 with 0 XP. `SaveGame.VERSION` stays 1.
- **What stage 2 credits**: each `cal_log` record that is traceable and was not too soon (a robot's at the robot's rate, with the standard's tier), each `job_log` result by its pay, and each `audit_log` report marked clean, all at today's values; then the farm's Instrumentation XP one for one (after its ×5 on a 10-level save). The lab's size is not counted, because the logs do not say how big the lab was when the work was done [ASSUMPTION]. Certificates, spools, robots, areas and growth are not credited backward: step 3 names three logs. So an old large lab starts lower than the same work would earn it now. **Question for Ryan:** credit old logs at the lab's size on the day of loading instead? A log record from before `traceable` was written counts as traceable if it names a standard, and an audit from before reports were marked clean counts as clean if it passed.
- **A robot built or commissioned** [ASSUMPTION]. §3.2 says "A robot built or commissioned, 250". This build gives 250 when the robot is built and 250 again when it is commissioned, 500 for one robot. **Question for Ryan:** did the line mean one event, 250 once?
- **A lab area pays once.** `lab_areas_paid` keeps, for each discipline, the most spaces its area has had; `lab_area` XP is given only for a space past that, so clearing a space and fitting it again gives none. It is saved and synced with the lab's other fields; a save without it marks the spaces it has as paid, and so does a new farm's starting areas. The XP is counted for the player who fitted the space.
- **Instrumentation is gone**: from the skills list, its two sources (`buy_standard`, `calibrate_standard` keep their ids and feed the lab), its saved XP and effect floor, and the robot build check. `data/robots.json` asked for Instrumentation level 1, which every farm met, so no robot is harder or easier to build. The lab level takes that gate over at step 9.
- **Guests' files.** A guest's file (`CoopProfile`) that lists `instrumentation` loads without it, and its curve marker stays 2, since no player's XP changed. A guest running an older build can still bring their file to a newer host. The farm snapshot's `skill_curve` is now 3, so an older build refuses a newer host's farm with "'skill_curve' is not a curve this game knows", and a newer guest converts an older host's snapshot on its own copy only. Both players on one build is the rule anyway.
- **Synced.** `lab_xp` is a saved farm field added after version 1 (`SAVED_LATER`), carried by the host's farm snapshot; guests hear `lab_xp_changed`. The wire and protocol number are unchanged.
- **On screen.** SKILLS (K): a first row "Lab level N (X XP, Y for level N+1) farm", with the size's multiplier under it. Phone: a `LAB: level N` line under `CRED`, in the same label and style; the phone's look is not changed, but that label is one line taller, so the rows under it sit about 20 px lower. A level gained posts "LAB LEVEL UP".
- **Not built, as told:** no gates from the lab level (step 9), no move of Robotics or Husbandry, no Agronomy, no quests or quest lumps.
- **The hour budget** is not set for the lab: the values are §3.2's first numbers. With ×8 in a large lab one 130 CR job is 520 lab XP, which is several early levels at once; that waits for the spreadsheet pass.

## 2026-11-26: Every skill is a player's own; Agronomy and Earthworks (build order step 4 of quests_levels_story.md)

### Ryan chose

- Robotics and Husbandry become personal skills, and Agronomy and Earthworks are added (`docs/design/quests_levels_story.md` §10, 1 and 2, and §9 step 4). Each player gets the farm's old Robotics and Husbandry XP once. Crop XP earned as Field Ops moves to Agronomy by the counter. `till`, `dig` and the rest go to their new skills from here on.

### Agent's notes (flagged for Ryan, not his words)

- **Seven skills, all `scope: player`** in `data/skills.json`: Calibration, Uncertainty, Robotics, Husbandry, Field Ops, Agronomy, Earthworks. No skill is the farm's now. `farm_skill_xp` stays in the save's shape so an older save still loads, and is empty after it does.
- **Whose Robotics a gate reads: the acting player's.** A robot's build check, a job card's gate (`data/robots.json` `skill_gate`) and the card slots read the level of the player who builds or programs. On the host that is the guest `FarmCommands` names. The robots stay shared: a card a level 15 player set keeps running for everyone. So the best builder on the farm does the building, as in the design's "something a person gets good at". Robot XP goes to who ordered, commissioned or programmed, as it was counted before.
- **Molt time reads the best Husbandry on the farm** [ASSUMPTION]. The spiders are shared and nobody "does" a molt, so `molt_days()` uses the best `molt_time` factor of any player the farm knows, present or not. The other readings: the host's only (a guest's Husbandry would do nothing), or whoever last handled the enclosure (hard to see why it changed). **Question for Ryan:** is "best on the farm" right, and should it count only players who are in the session?
- **"Molt progress on the field phone" (Husbandry 3) is each player's own** now, like the budget view.
- **The conversion** is stage 3, marked by `skill_curve`, now 4. A save with no marker runs stage 1 (×5), 2 (lab level) and 3; one that says 2 runs 2 and 3; one that says 3 runs 3; one that says 4 runs nothing, so saving again gives nothing twice. `SaveGame.VERSION` stays 1.
- **Who gets the farm's XP:** every player the save knows: the host (`player_1`), and anyone with XP, a counter, an effect floor or a guest's place in it. Each gets the larger of the farm's XP and their own. They also get the share of the Husbandry effect the farm had kept from the 10-level curve (`skill_effect_floor`), so no molt gets longer. A guest who first joins after the conversion starts Robotics and Husbandry at level 1, or at what their own file brings [ASSUMPTION]. **Question for Ryan:** should a new guest on an old farm be given the farm's old levels too? That would need the old farm XP kept in the save for good.
- **The crop move.** For each player, `crop_xp` (the counter's total for `plant_crop`, `harvest_in_spec` and `sell_crop`) leaves Field Ops and is added to Agronomy, never more than Field Ops holds. The counter itself is not changed. Field Ops keeps the share of its effect (steering drift) it had at its old level, as an `effect_floor`, so driving does not get worse. It would also stay at any level that opens something (an unlock in `data/skills.json` or a robot card gate); nothing is gated on Field Ops today, so that rule does nothing yet.
- **Old `till` XP stays in Field Ops**, as step 2 logged. `till` gives Agronomy XP from this build on. `mine_fissure` stays Field Ops.
- **Earthworks sources** [PLACEHOLDER]: `dig` 5 XP, `find_block` 25 XP. `dig` pays only for a step deeper than that cell has ever been (`GameState.dug_paid`), so digging and filling one cell cannot be looped for XP. A hole in an older save counts as paid. `fill`, `place_stone` and `check_with_block` give none yet: fill and place/take up can be repeated for free, and a block check can be repeated on one unit. **Question for Ryan:** should those three give XP, and with what limit (once per cell, once per unit per day)?
- **Effects** (§4.1, only ones that map to something that exists): Agronomy has `lin_price`: Lin pays the seller up to 10 % more at level 99 [PLACEHOLDER], on the usual spread (2.5 % at 10, 5 % at 30, 7.5 % at 60). It reads the Agronomy of the player who sells; the money goes to the shared wallet. Harvest and sale XP stay by the price without it. An effect with `full` below 0 is a gain. Earthworks has no effect yet: "faster digging" and "more stone per dig" have nothing to scale (a dig is instant and gives no stone), and better odds of a block would change where the seed puts blocks. No new unlock rows: every Agronomy and Earthworks unlock in §4.2 is marked NEW.
- **The wider in-spec band and the soil probe reading** (§4.1, Agronomy) are not built: the band is the crop's own, read by the plot label, the phone and the harvest alike, so a per-player band needs a decision on whose band a shared plot shows.
- **Guests' files** (`CoopProfile`). The file now says curve 3 and holds any of the seven skills; Robotics and Husbandry travel with the guest like the rest. A file that says 2 is still read, as it is. A file with no curve is still ×5. Any other curve is refused, and so is one that is not a whole number.
- **A guest file's crop XP: nothing is moved in the file.** The counter is the farm's, so the file cannot say how much of its Field Ops came from crops. The rule: the move happens only on the farm where the crops were grown. On joining, each skill is still the larger of the farm's and the file's. So a guest who grew crops on a farm before this build has that XP as Agronomy on that farm, and may still hold the same XP as Field Ops in their file, which wins the "larger of" for Field Ops when they join again: their crop XP then counts in both skills. Nobody loses XP; a few players keep some twice. **Question for Ryan:** accept that, or carry the crop counter in the guest's file from now on so a later move can be exact?
- **Crop XP can count twice for a guest: accepted for now.** It can be Field Ops in the guest's file and Agronomy on the farm (the note above). It is small, and nobody loses XP.
- **A guest who first joins after the conversion gets none of the farm's earlier Robotics and Husbandry XP.** Only players the save already knew are given it. Say this in the patch notes.
- **Older builds.** `CoopSession.PROTOCOL` is 14 (was 13), so a host and a guest on different sides of this build refuse each other at the hello with "The host has another version of the game." An older build does not read a guest file that says curve 3, so a player who goes back to one brings nothing from the file. Both players on one build is the rule anyway.
- **A guest's copy converts nothing.** The save conversions for skills (the 10-level curve, the lab level, this one) run only on the host or in a solo game: `GameState.put_farm` skips them when `FarmCommands.guest` is true. A guest also refuses a host's farm whose `skill_curve` is not this build's (`FarmSync`), with the same "another version" message, so a snapshot from an older host cannot run the conversion on the guest's copy and raise the skills the guest takes home.
- **Saved and synced.** `dug_paid` is a farm field added after version 1 (`SAVED_LATER`), checked on load like `dug`, and has no signal of its own (`test_farm_sync` `NO_SIGNAL`): nothing shows it. The wire is unchanged; only the protocol number is raised.
- **On screen.** SKILLS (K) lists the seven skills, each the local player's own; the word "farm" is only on the lab's row. The field phone is not changed.
- **Not built, as told:** no quests, no lab-level gates, no new mechanics for Earthworks, no XP for old digging.
- **The hour budget** is not set for the new sources or for `lin_price`; they wait for the spreadsheet pass.

## 2026-11-26: The quest engine; L1 and L3 (build order step 5 of quests_levels_story.md)

### Ryan chose

- Build step 5 of `docs/design/quests_levels_story.md` §9: `data/quests.json`, `quest_state` in the save, the checks of §5.3, and the plain rewards (credits, skill XP, lab XP, quest points, a phone line). Quest points are kept per player in the host's save, guests included. L1 and L3 ship. Progress goes to the phone as plain lines. A quest's own gates apply. The unlock-table gates (§3.4) wait for step 9.

### Agent's notes (flagged for Ryan, not his words)

- **The engine only watches.** `scripts/quests/quest_engine.gd` (`QuestEngine`) reads what `GameState` already keeps and changes nothing but `quest_state`, `quest_points` and the rewards. With no quests in the data file the game is the same.
- **`data/quests.json` is a list of quests with ids**, not the design's keyed sketch, so it loads like every other table (`DataManager` records) and keeps its order. Every number in it is a [PLACEHOLDER].
- **No accept or turn-in yet** [ASSUMPTION]. There is no quest log until step 7, so an offered quest is accepted at once and is paid the moment its last step holds. Step 7 can add the two commands; the state already keeps the day accepted and the day done apart.
- **When the quests are looked at:** on the host, after every command a player gives (`FarmCommands.execute`) and each morning after the audit and the job board. Never on a guest, and never inside the load itself (`farm_from_dict`), so a farm saved and loaded is the same farm.
- **A new quest is offered only in the morning, or when a farm is started or opened** (`SaveGame.start_new` and `continue_farm`, host only). A command's look ticks steps and pays a finished quest, but offers nothing, so an offer never lands on top of the command's own phone line (review of PR 172). A quest opened by finishing another is therefore offered the next morning. Step and DONE lines still follow the command that earned them.
- **A save from before quests** loads with no quest state. When it is opened L1 is offered. If that save already has a clean audit, or a finished contract, the quest is marked done and its lab XP is paid once, with the DONE line and no offer line [ASSUMPTION]. **Question for Ryan:** pay old saves the lump, or only mark the quest done?
- **L1, Every Sticker Counts** (giver Vance, 250 lab XP): its one step reads `tier1_unlocked`, the flag the first clean audit sets. That is the same fact as "a clean row in `audit_log`", and it is also right for an old save whose audit rows have no `clean` field. The `count` check on a log is built and tested, but no shipped quest uses it yet.
- **L3, The First Contract** (giver OIRM, 400 lab XP): offered when the contract is (`contract_state` active or later), done when the run is finished (complete or fulfilled). It ships with no gates of its own: lab level 15 and Trusted in the design's table are §3.4 (step 9), and the contract already waits for its band. The contract posts its own "n of 5" lines, so the quest adds none. The optional second step (buy the standard) is not built.
- **L3 when the standard was bought first** (review of PR 172). Kestrel sells the contract's standard at full price outside the contract. A lab that buys it before it is Trusted is never offered the contract (`_offer_first_contract` stops when the standard is owned), so L3 could never be offered. Chosen: L3 is then marked done with nothing paid and nothing said, by a new quest field `closed_when` (a step check; here `owns_standard`). It applies only to a quest that was never offered, on an offering look. The other choice, paying L3 for owning the standard, would pay 400 lab XP for a contract that was never run. **Question for Ryan:** all right, or should that lab still get a contract of some kind?
- **Phone lines** (the phone's look is not changed): `VANCE: New quest, <title>. <step>`, `QUEST <title>: 2 of 5. <step>` (only for a counting step that needs more than one), `QUEST <title>: step done. Next: <step>`, `QUEST DONE: <title>. Reward: 250 lab XP.`, then the giver's line from `data/dialogue_dispatches.json` (`npcs/vance/quests/...`, `npcs/oirm/quests/...`). The two givers' lines are first drafts. **Question for Ryan:** are the lines and the wording all right?
- **Took part** [ASSUMPTION]: a player who was on the farm when any step of the quest was ticked (the session's players, or the one player alone). Each of them gets the quest's points once and its skill XP lump. Credits and lab XP are the farm's, and so is the XP of a farm-scope skill: it is paid once for the quest, not once for each player (no shipped skill is farm-scope now). A player who joins after the last step gets nothing.
- **Quest points** are kept as player → quest → points in `quest_points`, so one quest can never pay one player twice, and step 8 can merge a guest's file by quest. Lab and daily quests pay none (a test holds the shipped data to that).
- **A guest the farm forgets loses their points here.** The farm keeps skills for a limited number of guests (`_forget_a_guest`); the points go with them until step 8 puts them in the guest's own file. **Question for Ryan:** all right until step 8? The guest is also taken off every quest's list of who took part, and a quest finished later pays only players the farm still knows.
- **A count never goes back.** A forgotten guest's action counts leave the farm, so a `counter` step could have read less than before. Each counting step keeps the highest count it has reached (in `shown`). What the forgotten guest added still stands; the players left must pass it with their own counts.
- **Quest data is checked.** `QuestEngine.data_problem` names a quest with no steps, a step that is not a dictionary, a step with no id or two steps with one id. The engine leaves such a quest alone, and a test holds the shipped file to it. A quest id and a step id are kept in saves and must never be renamed (said in the file's `_note`).
- **Gates on a player's own level or points, for a farm's quest:** the best among the players on the farm counts (§5.6's [ASSUMPTION]). A gate this build cannot read keeps the quest shut. A player-scope quest is skipped until step 8.
- **Checks built:** `stat_at_least`, `flag`, `band_at_least`, `owns_standard`, `lab_size`, `count`, `state_is` (new: reads `contract_state`), `level` (a skill, `lab` or `total`), `counter`. `count` and `counter` count from the day the quest was accepted unless the step says `ever`. `counter` adds up every player's count for a farm's quest and takes no `where` yet. `minigame` is not built: its step waits.
- **Rewards built:** `credits`, `lab_xp`, `xp_<skill id>`, `quest_points`, `phone`. `xp_certificate` is ignored until step 6; items wait for step 10.
- **A quest's lab XP is not multiplied by the lab's size** (§3.2.1). `GameState.give_lab_xp` and `give_skill_xp` are the plain ends of the two award functions; a quest's lump is not counted as an action.
- **Saved and synced.** `quest_state` and `quest_points` are farm fields added after version 1 (`SAVED_LATER`); `SaveGame.VERSION` stays 1. Both are checked on load. A quest id the data does not have is kept untouched, not refused and not dropped, so its "done" is still there if the quest comes back. A new signal, `quests_changed`, shows both (`FarmSync.SHOWN_BY`).
- **`CoopSession.PROTOCOL` stays 14.** The two fields ride in the farm snapshot that already travels, no message changed, and a guest never runs the engine. A guest on the build before this one ignores the two fields it does not know and still gets the phone lines.
- **One older test changed:** `test_save_state`'s new-farm check now expects the first offer line, since a new farm is offered L1 before its first save. `test_playtest_hints` is as it was.

## 2026-11-26: The XP certificate, its picker, and S1 (build order step 6 of quests_levels_story.md)

### Ryan chose

- Build step 6 of `docs/design/quests_levels_story.md` §9: the XP certificate (§4.4), a pick-a-skill reward with a small picker. S1, The Thirsty Probe, ships here without its mini-game. The field phone's look and layout are not changed.

### Agent's notes (flagged for Ryan, not his words)

- **What a certificate is worth** [PLACEHOLDER]: a fixed lump of XP written on the quest (`"xp_certificate": 200`), the same for every player. Nothing scales it by the holder's level. The curve does that by itself: each level costs 10 % more than the one before, so 200 XP takes a skill from level 1 to level 4 and is less than one level at level 50. This is the simplest reading of §4.4 ("sized to the quest, not the player"), and it needs no second table. **Question for Ryan:** is a plain XP lump right, or should a certificate be worth a share of the next level?
- **Who gets one:** each player who took part in the quest (the same rule as quest points), one each. It is held, not spent, until its player picks a skill. Held certificates are kept as player → certificate → XP in `xp_certificates` on the farm, in the host's save, for guests too. A certificate's id is its quest's id and a number, `thirsty_probe#3`. The number comes from a count the farm keeps of every certificate it has given (`xp_certificates_given`, saved and checked), so an id is never used again, not after a spend either.
- **Spending** is a host-side command, `spend_xp_certificate(certificate_id, skill_id)`, in `FarmCommands.ACTIONS`. The host checks that the asking player holds that certificate and that the skill is one of their own (not a farm-scope skill, not an unknown id). The certificate is removed before the XP is paid through `give_skill_xp`, so it can't be spent twice. The XP is not counted as an action, as a quest's lump is not. A player in bed who spends one stays in bed (`FarmCommands.NO_WAKE`).
- **A skill at the top level takes no certificate** [ASSUMPTION]: the spend is refused and the certificate is kept for another skill. Past that, a certificate may go to any skill, a high one too (the XP is simply worth less there).
- **On foot** [ASSUMPTION]: a player walking outside the rover may still spend one (`CoopWalkers.ON_FOOT`). It is paperwork, not a job at a cell.
- **A guest the farm forgets loses their held certificates**, with their skills and points (`_forget_a_guest`). **Question for Ryan:** all right until step 8 moves a guest's things to their own file?
- **The picker** is a small panel over the SKILLS view, in the same style. While you hold a certificate, SKILLS (K) shows a button, `SPEND AN XP CERTIFICATE (1 held)`. It lists each of your skills as `Calibration: level 1, to level 4`. The first click on a skill asks `Spend on Calibration?  CONFIRM`, and a second click on that row spends it (added after review: a spend can't be undone). Esc, K or BACK takes the question back, then closes the picker. While the picker is open the SKILLS buttons under it take no focus. On a guest, a spent certificate leaves the list at once and does not wait for the host's farm to arrive. No new key. When a quest pays one, the phone says `XP CERTIFICATE: 200 XP in a skill of your choice, for each player who took part. Open SKILLS (K) to spend it.`
- **S1, The Thirsty Probe** (giver Lin, story): no gates, offered the morning of day 2. Reward 150 CR, 1 quest point, an XP certificate of 200 XP [PLACEHOLDER], and Lin's line. Lin's offer line and done line are the design's own words (`npcs/lin/quests/...` in `data/dialogue_dispatches.json`). A quest may now carry `offer_line`, said inside the "New quest" phone line.
- **S1 follows the §5 prose, not the §5.1 sketch**: no gate, and 150 CR, 1 quest point and a certificate. The sketch is there to show the shape of a quest in the file (it gates on a skill level and pays lab XP), and the prose is the newer and fuller word on what S1 is.
- **S1's steps**, in order: own the gravimetric kit (`owns_standard`); calibrate the soil probe against it (`count` on `cal_log`, `instrument_id: soil_probe`, `traceable: true`); sell Lin a crate of in-spec dust turnip.
- **The kit is founding stock**, so the first step is done the moment the quest is accepted and the offer line goes straight to the calibration. It is kept as a step because the design lists it, and it will matter if the kit is ever bought. **Question for Ryan:** keep the step or drop it?
- **The calibration must be done after the quest is accepted.** A soil probe calibrated on day 1 does not count (the design's sketch has no `ever`, and step 11's mini-game will hang on this calibration).
- **A later step counts from when it opened.** In a quest done in order, a `count` or `counter` step now takes its base when the step before it is done, not on the day the quest was accepted (a step marked `ever`, and a quest with `any_order`, are as they were). So in S1 a turnip sold before the probe is calibrated is not the crate. L1 and L3 read the same as before.
- **"A crate" is one in-spec dust turnip sold to Lin** [PLACEHOLDER], counted after the calibration step is done. The game had no record of what was sold, so the farm now keeps `crops_sold_in_spec` (crop → count; `sell_harvest_to_lin` adds to it). The `counter` check reads it when its `counter` is `crops_sold_in_spec`, with `where: { crop_id }` or for every crop. No new check kind. Sales from before this build are not counted. **Question for Ryan:** how many turnips make a crate?
- **The mini-game hook:** S1's calibration step carries `"minigame": "set_the_zero"`, as the design's sketch does. Nothing reads it yet, and the step is done by its check alone. Step 11 can read that field.
- **Saved and synced.** `xp_certificates`, `xp_certificates_given` and `crops_sold_in_spec` are farm fields added after version 1 (`SAVED_LATER`); `SaveGame.VERSION` stays 1. All are checked on load (a wrong shape, an id with no number of its own or a number the farm has not reached, XP that is not a whole number from 1 to the skill XP cap, a count below 0). An old save loads with none held. A new signal, `xp_certificates_changed`, shows the certificates (`FarmSync.SHOWN_BY`); the sold count is bookkeeping with no signal.
- **`CoopSession.PROTOCOL` stays 14.** A guest sees held certificates because they ride in the farm snapshot that already travels. The one new message is a guest asking `spend_xp_certificate`, and a guest only asks when it holds a certificate, which only a host on this build gives. A guest on the build before this one ignores the field, can't spend, and its certificate stays held in the host's save. A new guest on an old host is never given one.
- **Older tests changed:** `test_quests`' reward line now names the certificate; `test_farm_sync` lists the sold count and the count of certificates given under no signal; `test_quests`' shipped-data check now holds `offer_line` paths to the same rule as `rewards.phone`; `test_performed_by` lists the three read-only certificate functions among those that read for the player at this screen.

## 2026-11-26: Dispatch names (build order step 17 of quests_levels_story.md)

- **BNH sends the dispatches, and OmniSpec is gone from `data/dialogue_dispatches.json`** (Ryan's decision 6). Text only: `megacorp_name` is "Brightwell-Nonesuch Habitats", the sender "Orbital Compliance" is "BNH Compliance", `disp_04` and Bram's greeting say BNH, and each of the 22 morning dispatches closes with "Warmly, Dispatch." because Odalys relays them all. The other department names stay, as BNH departments [ASSUMPTION, section 0.2]. No id, key or script changed; `tests/test_dispatch_names.gd` holds the file to this. **Left alone:** the bench's title, "BENCH CALIBRATION // OMNISPEC FORM 88-C" (`ui/cal_bench_ui.tscn`), which is not a dispatch. **Question for Ryan:** should that form be a BNH form too?

## 2026-11-26: Mini-game 1, Set the Zero, part 1 (build order step 11 of quests_levels_story.md)

Part 1 is the game, its scoring, the bench hookup and the co-op path. The S1 quest-step hookup is part 2 and is not built; what it needs is the last note here.

### Agent's notes (flagged for Ryan, not his words)

- **The game** is its own scene and script (`ui/minigames/set_the_zero.tscn`, `scripts/minigames/set_the_zero.gd`). A needle sweeps a scale with a green sweet spot at zero. The first stop is the coarse adjust; the needle then sweeps again, slower, over a scale as wide as the coarse stop was off (held between 15 % and 50 % of the first scale), and the second stop is the fine adjust. Space, Enter, a gamepad's accept button, a click anywhere or the STOP button stops it; Esc, a gamepad's cancel button or the SKIP button skips. It runs 5 to 8 s with the result shown.
- **The score is a pure function**, `SetTheZero.score(coarse_stop, fine_stop, sweet_half)`: 100 dead on zero, 95 at the sweet spot's edge, falling to 0 at 8 half-widths out. The coarse stop only sets how wide the fine scale is. No frames, clock or random number are in it; the sweep's start is seeded from the instrument and the size of the cal log. All of its numbers are [PLACEHOLDER]: sweep periods 1.6 s and 2.6 s, sweet spot half-width 3 % of the scale, the 8 half-widths.
- **Calibration widens the sweet spot**, up to twice at level 99, by the same share the skill's other effects use (and never under the player's kept `effect_floor`).
- **Score to residual is the table of section 7.2**, in steps: 0 to 59 Standard ×1.0, 60 to 79 Good ×0.8, 80 to 94 Fine ×0.6, 95 to 100 Reference ×0.4. So a poor try (under 60) and a skip give exactly today's result: the same random draw, the same record. The factor multiplies the as-left residual and nothing else. **Question for Ryan:** steps as in the table, or a smooth line from 60 to 100?
- **Not built from 7.2: the XP multipliers (×1.15, ×1.3, ×1.5), the quest grade and the job bonus.** They need `GameState.gd` or the quest engine, which this PR may not touch. For now a good score only leaves a smaller residual.
- **When it opens.** At the bench's ZERO / CALIBRATE for a unit, when it is the lab's first calibration by hand of that kind of instrument, or when the player's CAREFUL switch is on. "Kind" is the instrument id before any `@` (so every robot's joint encoder is one kind) [ASSUMPTION]. "First" is read from `cal_log`: no bench record of that kind by a player. Robots' and the manager's calibrations and remote zeros don't count. An old farm has done every kind already, so only CAREFUL shows the game there. Standards are played only with CAREFUL on (section 7.4). Paid jobs have no game yet: they don't go through `calibrate_at_bench`.
- **CAREFUL opens at Calibration 5**, as a new unlock in `data/skills.json` (`careful_bench`), per section 7.4. Until then the switch is shown locked with its level.
- **CAREFUL and the difficulty are local player settings**, kept in `user://player_settings.cfg` on each machine, not in the farm and not sent. Difficulty: Standard; Relaxed (sweet spot half again as wide, 30 % slower, as section 7.5); Sharp (three quarters as wide, 20 % faster) [PLACEHOLDER, not in the design]; Off (no game ever opens). Rewards are the same on every setting. **Question for Ryan:** keep Sharp, or only Standard, Relaxed and Off?
- **Skip and close.** SKIP or Esc in the game calibrates with the Standard result. Closing the bench while the game is open calibrates nothing.
- **Co-op: the score rides in the calibrate command.** `calibrate_at_bench` may carry one more argument, a whole number, after the instrument (`FarmCommands.SCORED`). The host refuses anything that is not a whole number, cuts it to 0 to 100, and counts it only where a game could have been played: the lab's first of the kind, or the sender has the level that opens CAREFUL. Otherwise it counts for nothing and the result is the plain one. The command with no score is unchanged, so one click still works everywhere. The answer to a scored command gains `zero_score` (what the host counted, or -1) for the sender's screen; the farm's own record does not.
- **What the host can't check.** It can't see a guest's CAREFUL switch, only the level that opens it, and it can't see whether the guest played: a changed guest could send 100. Section 7.6 asks for the 0 to 100 cut only; the worst case is a Reference result on that guest's own calibrations. **Question for Ryan:** is that enough, or should the host replay the stops (the guest would send its two stop times and the host would score them)?
- **Nothing new is saved or synced.** No farm field, `SaveGame.VERSION` stays 1, `CoopSession.PROTOCOL` is untouched. The one runtime field is `DriftingSensor.next_residual_scale`, set by the host for one zero and reset; it is not in the sensor's saved state. So the grade is not on the cal record or certificate yet: that would be a saved field, and it waits for Ryan's word. **Question for Ryan:** should the certificate show the grade?
- **A host on an older build refuses a scored command** ("takes 1 arguments, not 2") and nothing is calibrated; the guest sees the refusal and can SKIP or set GAME: OFF. No retry is built, since both players are meant to be on one build.
- **After the second-model review (same day):** a press in the first 0.4 s of the result is not taken, so a double click can't close it unread. The game runs on the real clock, 0.1 s a frame at most, so a faster farm clock or a hitch can't jump the needle. Opening the bench ends a game left open, with nothing calibrated. When a score was sent and the host counted none (another player calibrated the kind first), the bench says "Score not counted (not a key moment)." The clock is mixed into the sweep's seed, so opening the bench again is not the same sweep. The hint under the sweeps says "Esc/Skip calibrates without the game." **Question for Ryan:** Esc in the game skips and calibrates (section 7.5); should it back out with nothing calibrated instead?
- **A guest has what the bench needs to decide.** `cal_log` and each player's skill XP ride in the farm snapshot (`FarmSync`), so a guest's bench reads the same first-of-a-kind and CAREFUL level as the host, a moment late at worst; that late case is the "not counted" line.
- **Not built from section 7:** the practice swing (7.5), other players watching or helping (7.6), a robot's flat score of 60 (7.4).
- **Tests:** `tests/test_set_the_zero.gd` (the scoring, the widening to twice at 99, the table, skip and poor try equal to the plain result, the host's cut and its key-moment check, the game driven with no frames, the settings file, the bench opening the game). No older test changed.
- **What the S1 hookup (part 2) needs.** (1) From the quest engine: whether an accepted step that is not yet done carries `"minigame": "set_the_zero"` for this instrument, readable on the host and, through the synced quest state, on a guest. (2) That answer OR'd into `MinigameScore.is_due` (the bench opens the game) and `MinigameScore.may_count` (the host counts the score). (3) The engine told the score the host counted when the calibration lands, for the quest grade and bonus of 7.2; either passed at command time or kept on the cal record, which would be a saved field. (4) A rule for S1 on an old farm where the hygrometer was calibrated long ago: the step's own flag should open the game even though the kind is no longer new.

## 2026-11-26: Co-op for quests (build order step 8 of quests_levels_story.md)

### Ryan chose

- Build step 8 of `docs/design/quests_levels_story.md` §9: a guest's personal quest state, quest points and held XP certificates also go into the guest's own file so they travel; lab quests join the farm sync. Nothing the player sees on the phone changes, and no new screen.

### Agent's notes (flagged for Ryan, not his words)

- **Who is right about what.** The host is the authority for its own farm. The guest's file (`user://coop_player.json`) is the guest's record of every farm they have been on. They meet when the guest joins (`GameState.let_in_guest` → `_take_guest_record`) and each time the farm reaches the guest afterwards (`CoopProfile.keep`). Both sides only ever take the higher value or the union. Nothing is added together, so joining a second host, or coming back to the first, changes nothing that was already counted.
- **Quest points** are kept by quest (`quest id → points`), in the file as on the farm. On a join the host takes, for each quest, the higher of its own number and the file's, and never more than that quest pays in the host's own data. So a quest done on farm A and again on farm B is one lot of points, not two, and a hand-edited file can't claim more than a quest gives. A quest the host's build does not have is not taken (it stays in the file).
- **XP certificates: one for each quest, on every farm together.** The file keeps the certificates held (`quest id → XP`) and the quests whose certificate is spent. The farm keeps a new list, `xp_certificates_spent` (player → quest ids), filled when a certificate is spent. On a join: a certificate spent anywhere is taken away here and marked spent; one held anywhere is held here (worth no more than the quest gives here), unless this farm already has it held or spent. A quest that finishes does not give a certificate to a player who already holds or has spent that quest's one. So a certificate held on A and brought to B is one certificate; spent on B, it is gone on A at the next visit; an older copy of the file can't bring it back to a farm that has seen it spent.
- **What still can be doubled, and why I left it** [ASSUMPTION]: a host only knows a certificate is spent once the guest has come by with a file that says so. A player who copies the file before spending, spends on B, then takes the old copy to a farm C that never saw them, holds it again there. The file is the player's to edit (the same trust as the skills in it), so this is cheating by hand, not an accident of play. Closing it needs the hosts to talk to each other or a signed file. **Question for Ryan:** is trusting the file, as skills do, enough here?
- **A guest gets one certificate for a quest, however many farms they finish it on.** **Question for Ryan:** is that what you want? The other reading (one per farm) is what made joining two hosts a way to farm certificates.
- **Personal quests now run** (scope `player` in `data/quests.json`; none ships yet). Each player has their own entry in a new farm field, `player_quest_state` (player → quest → entry). It is offered to each player by their own level and points, a `counter` step counts their own actions, and rewards go to them alone. Checks that read the farm as a whole (credits, flags, logs, standards owned) read the same for everyone. **Question for Ryan:** a `count` step (rows of the calibration or job log) of a personal quest counts the whole farm's rows, since the logs do not say who to credit in a form the engine reads. Good enough until a personal quest needs it?
- **How a personal quest travels.** The file keeps, for each one, whether it is done, the steps done, and the count shown for each counting step. On a join: done anywhere is done here; a step done anywhere is done here; a count is the higher of here and there. What was brought is kept apart on the farm (`carried` in the entry) and added to what is done here from then on, so 2 tilled on A and 1 on B is 3, and coming back with the same file adds nothing.
- **A personal quest done on another farm pays nothing here** [ASSUMPTION]: no credits, no lab XP, no line from the giver. The points and the certificate come with the guest's file. §8 of the design says a returning guest's finished quest "gives no second point" and "they get the other rewards"; I read "the other rewards" as what the first farm paid. **Question for Ryan:** should the second farm pay its credits and lab XP for a personal quest the guest finished elsewhere?
- **A personal quest under way comes in whatever the host's gates say** [ASSUMPTION]: if the guest brings real progress in a quest the host's build has, it is taken up there even if that farm would not have offered it yet. One only offered (nothing done) is not brought.
- **Home and away are still two players**, as with skills: a player's own farm keeps their points and quests in its save, and their file keeps what they did as a guest. Nothing carries between the two, so "no second point" holds between friends' farms but not between a friend's farm and home. **Question for Ryan:** should a player's own farm read their file too?
- **The phone.** Nothing changed in how it looks. A personal quest's lines ("New quest", "Quest done") go to the one shared phone log, once for each player who has it, so with two players a personal quest would be offered twice in the log. No personal quest ships, so nobody sees this yet. **Question for Ryan:** when step 7 builds the quest log, should personal lines be shown only to their player?
- **The wire.** The hello gets a fifth part, the record, so `CoopSession.PROTOCOL` is 15: a guest and host on different builds are refused with the usual message. A hello may be up to `MAX_HELLO_BYTES` = 65536 [PLACEHOLDER]; every later guest message keeps the old 2048 limit. A record is never sent or written bigger than `CoopProfile.MAX_RECORD_BYTES` = 49152 [PLACEHOLDER], so it always fits (see "After review" below for what gives way). The host checks the record's whole shape (`CoopProfile.is_record`: exact keys, names up to 64 bytes, whole numbers in range, at most `MOST_QUESTS` = 128 quests in each of points, certificates held and certificates spent, and progress in at most `MOST_PROGRESS` = 64 of the player's own quests with `MOST_STEPS` = 12 steps each [PLACEHOLDER]) and drops the connection otherwise.
- **The file.** `CoopProfile.CURVE` stays 3: the four new keys (`quest_points`, `xp_certificates`, `xp_certificates_spent`, `quests`) are additions, no XP changed, and a file from before loads with an empty record and keeps its key and skills. A file whose record is malformed is set aside whole, like any other bad file. The file may now be up to 131072 bytes [PLACEHOLDER]. The build before this one would read a new file and write it back without the record, so going back a build loses the record but not the skills.
- **Saved and synced.** `player_quest_state` and `xp_certificates_spent` are farm fields added after version 1 (`SAVED_LATER`); `SaveGame.VERSION` stays 1. Both are checked on load. `quests_changed` now also shows `player_quest_state`, and `xp_certificates_changed` shows `xp_certificates_spent` (`FarmSync.SHOWN_BY`). I checked that `quest_state`, `quest_points`, the certificates and the offer lines already reached guests in the farm snapshot; the gap was only that the guest's file did not follow them, and it now keeps on both signals.
- **A guest the farm forgets** (more than 64 known guests) now gets their points, held certificates and own quests back from their file at the next visit. This answers step 6's question about forgotten guests.
- **Between the host's welcome and the first farm snapshot** the guest's `GameState` is still their own farm under the host-given id. `CoopProfile.keep` now does nothing until the host's farm has come (`CoopSync.has_farm()`), for skills as well as the record, so the home farm is never read as a guest's.
- **Older tests changed:** raw hellos in `coop_net`, `test_coop_any_peer` and `test_coop_session` carry the record, and `test_coop_session` tries bad records; three tests that compare a parsed guest file whole now expect the empty record with it; `test_performed_by` lists `has_had_xp_certificate` among the read-only functions.

### After review (2026-11-26, agent's notes, not Ryan's words)

- **A record can't say "not done" and be paid.** A record that brings every step of a personal quest (by step id, or by a count that is full) is taken as done and unpaid, whatever its `done` says. Before, such a record made the host pay the quest on a farm that saw none of it. A count is taken as no more than its step needs (`at_least`). A record that brings some steps still goes on from there, and the farm where the last step is really done pays. That part still trusts the file, as skills do.
- **Spent certificates are never crowded out.** Points, certificates held and certificates spent each have their own room in the file (`MOST_QUESTS` = 128 quest ids each [PLACEHOLDER]), apart from quest progress (`MOST_PROGRESS` = 64). Before, all four shared one cap of 64, and the 65th spent certificate was forgotten and could be handed out again. A test checks that `data/quests.json` has no more quests than the cap, so the cap is only met by data that is not this game's; then a warning is logged.
- **Too big means less quest progress, never fewer points or certificates.** A record over `MAX_RECORD_BYTES` gives up, in order: the steps and counts of quests that are done (nothing reads them), then quests under way, the biggest first (`CoopProfile.fitted`). The same fitted record goes in the hello and in the file, so one that fits the file fits the hello. Points, held and spent certificates at their caps, with 64 quests marked done, are under 40000 bytes, so they always fit. Before, a file too big was silently not written, and a hello too big went with an empty record, which dropped the spent list. Both now log a warning (`push_warning`). Names are counted in bytes (64), so the sizes hold for any text.
- **A hello refused for its version can be said again on the same link** and is then judged like a first one; each try costs a rate token, and a hello from a guest already in is dropped. A test covers it.
- **The file-trust case, spelled out:** a guest who spends a certificate and loses the connection before the host's next snapshot reaches them has a file that still says "held". That host has it as spent and takes it away again at the next visit; a farm that never saw them would take the file's word and let them hold it. The same goes for an old copy of the file put back by hand. It is the trust already flagged above for Ryan.
- **A personal quest's shared rewards are paid once for each player who finishes it** [ASSUMPTION]: its credits go to the shared wallet and its lab XP to the lab each time, and so would XP in a farm-wide skill if there were one again (today every skill is the player's own). That follows from "each player has their own quest" and is how a host and two guests each doing the same personal quest are all paid. **Question for Ryan:** is that right, or should a personal quest pay the wallet and the lab only the first time on a farm?

## 2026-11-26: Set the Zero in quest S1 (build order step 11, part 2, of quests_levels_story.md)

### Ryan chose

- Build the second half of step 11 of `docs/design/quests_levels_story.md` §9: quest S1 (The Thirsty Probe) opens Set the Zero for its calibration step, and the score gives the quest grade of §7.2. A skip or a poor try completes the step exactly as before (Ryan: a poor try gives the same as a skip). Nothing changes in how the phone looks.

### Agent's notes (flagged for Ryan, not his words)

- **The step opens the game.** A quest step may carry `"minigame": "set_the_zero"` (S1's `cal` step already did). While that step is the open step of an accepted quest that is not done, the bench opens the game for the step's instrument (`QuestEngine.has_minigame_step`, OR'd into `MinigameScore.is_due`, so `may_count` has it too and the host counts the score). This holds on an old farm that calibrated its soil probe long ago: the step's own flag is enough. Once the step is done the soil probe is an ordinary calibration again (first of a kind, or CAREFUL).
- **Which instrument.** The game is for the instrument the step counts: a mini-game step must be a `count` of `cal_log` rows whose `where` names one `instrument_id`. `QuestEngine.data_problem` refuses a mini-game step of any other shape, a game this build does not have, and a `minigame_line` on a step with no game. So no new field says which instrument; the step's own check does.
- **A guest sees the same.** The answer reads only `quest_state` and `player_quest_state`, which a guest has as the host's copy (`FarmSync.SHOWN_BY`, `quests_changed`). A farm quest's open step counts for every player; a player's own quest for that player alone.
- **The step is still done by its check alone.** A skip, a poor try (under 60), a calibration by the manager or a robot, and a bench with GAME: OFF all do the step as before. For those the quest's entry, its pay and every phone line are the same as before this change; a test compares a skip, a 0 and a 59 whole.
- **The score kept.** `FarmCommands.execute` tells the quests' look after a scored calibration which game was played, on what, by whom, and the score the host counted (`QuestEngine.played_game`). If that look does a step carrying that game for that instrument, and the score is 60 or more, the entry gets `scores` (`step id -> score`). Only then: `scores` is the one key of an entry that is not always there, so an entry with no graded game is byte for byte what it was. A calibration that does not do the step (not traceable, another instrument) keeps nothing, and the game is due again. A player's own quest keeps only its owner's score.
- **The quest grade (§7.2).** When the quest is paid: Good (60 to 79) is "Done" and pays as written; Fine (80 to 94) adds a bonus; Reference (95 to 100) adds a bonus and a line from the giver. A quest with several mini-game steps is graded by its lowest, and one of them skipped makes it a skip.
- **The size of the quest bonus** [ASSUMPTION]: the design says "a bonus" and gives no number. I took the same shares §7.2 gives a paid job: 10 % of the quest's credits at Fine, 20 % at Reference (`quest_bonus` in `MinigameScore.GRADES`). For S1 that is 15 CR or 30 CR on 150 CR. The quest's own line is unchanged; the bonus is one more phone line: "QUEST BONUS: The Thirsty Probe, played to FINE. 15 CR more." **Question for Ryan:** is 10 % and 20 % of the quest's credits right, or should the bonus be something else (XP, a bigger certificate, a fixed sum)? A quest that pays no credits has no bonus today.
- **Lin's line at Reference** [PLACEHOLDER]: the step's `minigame_line` (`npcs/lin/quests/thirsty_probe_reference` in `data/dialogue_dispatches.json`): "I checked your zero against my own scale. Twice. I found nothing to complain about. I did look." It comes after her usual line. **Question for Ryan:** the words are mine; change them as you like.
- **Co-op: whose score.** S1 is the farm's quest, so the score kept is that of whoever did the calibration that did the step, and the bonus goes to the shared wallet. **Question for Ryan:** fine, or should each player get a try and the best count?
- **Saved and synced.** No new farm field: `scores` lives inside a quest's entry in `quest_state` / `player_quest_state`, which are already saved and already shown by `quests_changed`. `SaveGame.VERSION` stays 1. `QuestEngine.state_problem` (read by `farm_dict_problem`) allows the key, holds each score to a whole number from 60 to 100 under a step id, and still refuses any other extra key. Because a build before this one refuses an entry with `scores`, `CoopSession.PROTOCOL` is 16 (was 15): a host and a guest on different builds are refused at the hello as usual. A farm saved with a kept score does not load on an older build, the same as any later field.
- **Not in a guest's own file** [ASSUMPTION]: `CoopProfile` does not carry `scores`. A guest's own quest whose game step was done on another farm is graded as a skip where it is finished. No personal quest with a mini-game ships, so nobody sees this yet.
- **Still not built from §7.2:** the XP multiplier by grade (×1.0, ×1.15, ×1.3, ×1.5 on the calibration's skill XP) and the paid-job bonus (+10 %, +20 %). **Question for Ryan:** should those come next, and should the grade then be written on the cal record (a saved field, asked in part 1 too)?
- **What the host can't check** is unchanged from part 1: a changed guest could send 100 for the step's calibration and S1 would pay its 30 CR bonus to the shared wallet.
- **The phone and the bench** have no change in how they look: no file under `ui/field_phone_hud*` or the bench UI is touched. The bench already asks `MinigameScore.is_due`.
- **Tests:** `tests/test_quest_minigame.gd` (the open step is a key moment on an old farm, for the host and on a guest's copy; only the open step of an accepted quest counts; a skip, a 0 and a 59 leave the farm the same and pay 150 CR; another instrument's score is not kept; the bonus and Lin's line by grade; the score through a save and a load; bad `scores` refused; the data rule for a mini-game step; the shipped steps name a real instrument). One older test changed: `test_coop_quests` no longer says the protocol is exactly 15.

### After review (2026-11-26, agent's notes, not Ryan's words)

- **The game opens on every try while the step is open**, not only the first: a calibration that does not do the step (the kit overdue, so not traceable) leaves the step open and the game due again. §7.4 says "the first time"; here that means until the step is done.
- **A mini-game step for a standard still needs CAREFUL.** The step's flag opens the game for a unit only. A standard's own calibration opens it with the CAREFUL level and switch, as before, and the host counts a score for it only then.
- **The score kept is the scored calibration's own.** It is kept only if the newest `cal_log` row is that calibration: traceable, by that player's own hand, and a row the step counts. A robot's or the manager's row that does the step is never given a player's grade.
- **One calibration grades one quest** [ASSUMPTION]: if two open quests have a mini-game step for the same instrument, one scored calibration does both steps and its score is kept in the first quest only (the order of `data/quests.json`; the farm's quests before a player's own). The other is done as by a skip.
- **A `minigame_line` on a step with no mini-game** is refused with its own words.
- **Tests added:** a player's own mini-game quest through `FarmCommands.execute` (the guest's entry keeps the score, the host's gets none of it); S1 with the kit overdue and with the kit at OIRM; a guest's snapshot (`FarmSync`) carrying `scores`; a quest done in any order; a standard's step; two quests and one calibration. `CoopSession.PROTOCOL` is pinned at 16 in `test_quest_minigame`, and at 16 or more in `test_coop_quests`.

## 2026-11-26: Quests S2 and L2 (build order step 12, part 1, of quests_levels_story.md)

### Ryan chose

- The first half of step 12: S2 "Warmly, Dispatch" with the mug ring prop, and L2 "Paperwork From Orbit", as section 6 of the design has them. Only reward kinds the engine has. The lab level gate uses the lab level of step 3; step 9's gates for benches stay off. Nothing on the phone HUD changes and there is no quest log.

### Agent's notes (flagged for Ryan, not his words)

- **Endings are new in the engine, and are words only.** A quest may have `endings`: a list of `{ id, when, the check's fields, phone }`. When the quest is paid, the first ending whose check holds gives the giver's closing line; if none holds, the reward's own `phone` is used. The ending is picked before the reward is paid, so the quest's own credits or lab XP are not in what its check reads. An ending's `when` must be `always`, `day_at_least` or a step check the engine knows (`QuestEngine.when_known`), or the quest is refused. Every ending pays the same. Which ending it was is **not kept** [ASSUMPTION]: the line is on the phone and nothing reads it later, so there is no new farm field, no change to the save or the wire, and `CoopSession.PROTOCOL` stays 16. If a later quest must know which ending S2 had, it can ask the farm the same question (`audit_grace_used`).
- **S2 is one step and two endings.** The step is "Have your first audit on file" (`audit_log` has a row, counted from the farm's start). The warning is looked at first [ASSUMPTION], because the design calls it the better story: a farm that used the warning and later had a clean audit gets ending B. A new farm cannot have both on its first audit.
- **S2's lab XP is 100** [PLACEHOLDER]. The design says "lab XP" with no number. L1 pays 250 and L2 300; S2 asks for less.
- **S2 is offered when the farm starts.** The first morning dispatch is posted then, so `"offer": "always"` is "with the first morning dispatch". A farm from before this quest with audits on file is done and paid at once, with the ending it has, as L1 and L3 are.
- **The mug ring is kept small.** One voxel model (`mug_ring()` in `tools/voxgen/build_models.py`, 15 voxels, no downloaded asset) on the calibration bench in `scenes/dome_interior.tscn`, with an `Inspectable` (`mug_ring` in `data/props.json`). It is hidden and not clickable until `audit_grace_used` is true, then it stays [ASSUMPTION]. That value is saved and sent to guests already, so a guest sees the host's ring. Inspecting it shows the prop's text and does nothing else; it is not a quest step. "The bench is warm" is in Odalys's note only: there is no heat effect on the bench.
- **L2's account and trip count from the farm's start; the certificate must come after the trip step is done.** The trip step has `"ever": true`; the certificate step does not, so in this in-order quest it counts only certificates issued after the look that did the trip step. Sending a bought standard opens the account and is the trip, so the first two steps are done in one look. A farm that opened its account before lab level 12 and already has a certificate back has the first two steps done when the quest is offered and is **not** paid then: it needs one more OIRM trip to come back.
- **L2's certificate step is narrower than the design's check, and still loose.** The design says "`certificates` has one row", which every farm has from its founding stock. The step counts rows of `certificate_log` with issuer OIRM that are not founding, so a maker's certificate from Bram does not count. A founding standard's OIRM trip that came back before the bought one was sent no longer does this step (every OIRM return is issued with `founding: false`, so with `ever` it paid L2 the moment the bought standard was sent). Still loose [ASSUMPTION]: the step does not check that the certificate is for the standard that was sent, so a founding standard that comes back from OIRM while the bought one is still away does it. Tying it to "its" certificate would need a new kind of check.
- **`oirm_trips` is a log `count` can read**, beside `cal_log`, `job_log`, `audit_log` and `certificates`.
- **Step 10 was not needed.** Neither quest's reward is a one-use reward or a keepsake, so no reward was left out. L2's "100 CR toward the next trip" is paid as 100 CR.
- **Words are placeholders** [PLACEHOLDER]: Odalys's offer and her two closing notes, OIRM's two lines, and the mug ring's inspect text. The closing notes end " Warmly, Dispatch."; the offer does not, because the phone puts the step's text after it. The warning note and the ring's text say only that someone sat up with the paperwork and left a mug: the one-time warning can come from a tire or an interlock alone, so they do not say the bench was used overnight.
- **Two older tests now run on L1 and L3 only** (`test_quests.gd`: the offer of L1, and an old save). They counted every "New quest" line, and S2 is now offered on a new farm.
- **Tests added** (`tests/test_quests_s2_l2.gd`): the two quests' data; Odalys's sign-off; S2's offer; each ending through a real audit morning; paid once and through a save; an old farm; the first ending that holds, and bad endings refused; L2's gate, steps, pay and which certificates count; a founding standard's earlier return not paying L2; an old account needing a new trip; an ending picked before the pay; an unknown or non-text `when` and an empty `phone` refused; every shipped quest mid-quest through the farm's save; the mug ring's text, model, and that it shows only after the warning.
- **Still to come in step 12:** L4, P1, P2.

## 2026-11-26: Quest-issued jobs and S3 (build order step 13 of quests_levels_story.md)

### Ryan chose

- Step 13: a job handed out by a quest and not by the board (Chet's envelope), then S3 "Certified in Three Fonts" as section 6 has it. Gate: credibility 20 or lab level 6. 1 quest point for any finish; on time and traceable pays the full envelope (200 CR) and Chet owes you one; late or untraceable pays half and gets a sour line. An envelope that is dropped or runs out is back the next morning, as often as it takes. The honest-or-quiet as-found choice is not in this slice.

### Agent's notes (flagged for Ryan, not his words)

- **The job is the quest's own data.** A farm's quest may have `job`: a template as `data/economy.json` has them (id, customer, item, discipline, min_tier, pay, due_in_days, bench_minutes), without `min_band` or `area`. `GameState.issue_quest_job` copies it into `active_jobs` with a job number, the day and a due day, as `accept_job` does, and adds `quest` (the quest's id). The row `complete_job` writes to `job_log` carries `quest` too; a board job and its row have no such key. The board is filled from the economy templates only, so the envelope is never on it, never takes one of its places and is not touched by its refresh.
- **No new farm field.** Whether the envelope is out, done or gone is read from `active_jobs` and `job_log`, which are saved and sent to guests already. `SaveGame.VERSION` stays 1 and `CoopSession.PROTOCOL` stays 16 (pinned in `test_quests_s3`). The save check now reads `quest` as text and `flat_cut_pct` as a number on a job when they are there. An older build ignores the two extra keys on a job.
- **It is taken for you** [ASSUMPTION]. There is no quest log or accept button yet (build step 7's log shows quests; accept and turn-in are not built), so the envelope goes into `active_jobs` in the same look that offers S3, and the step "Take the envelope job" is done at once. The lab is not asked whether it can do the job first: the envelope arrives with no pressure standard owned, and the bench refuses it until there is one.
- **Two steps, not the design's three rows.** Rows two and three of the table are one check (a `job_log` row for the job), so the quest has `envelope` and `hand_back`. The ids are in saves from now on.
- **The money is the job's pay, not a quest reward.** The job pays 200 CR through `complete_job`. A job that says `flat_cut_pct` (50 here) is cut once by that much when it is late, untraceable or both, in place of the board's two cuts (50 % late, then 75 % untraceable), so the worst case is 100 CR as the design says, not 25. The quest's own reward is the quest point. The endings stay words only: `clean` when the envelope's row is on time and traceable, else `sour`.
- **The envelope is otherwise a normal job** [ASSUMPTION]: it earns or costs credibility as a board job does (clean +2, late -3, untraceable -5), gives the job XP, and counts for any quest that counts `job_log` rows. Tell me if Chet's work should stay off the lab's record.
- **Running out costs nothing** [ASSUMPTION]. A board job past its grace days costs 5 credibility. The envelope does not: the quest cannot be lost, so it should not be a way to bleed credibility either. The phone says it ran out, then Chet says it is back, then the new job's line, in that order, all in the same morning (the morning that removes it also hands out the next one). The new envelope has a new job number and three more days.
- **"Dropped"** has no command in the game today: a job cannot be given back. The rule is written for any way the job leaves `active_jobs` without a `job_log` row, so a drop command built later needs nothing more here.
- **It comes back on an offering look**, which is every morning and also when a farm is opened. So a save made with the envelope gone has it again when loaded, without waiting for the morning.
- **`any_gate`** is how "or" is said: a list of gates dictionaries beside `gates`, and at least one must hold (all of that one's keys). `gates` must still all hold. S3 has `[{ "credibility": 20 }, { "lab_level": 6 }]`. `credibility` is a new gate key (the farm's points). A new farm starts at 10 and the first clean audit adds 10, so S3 usually arrives the morning after the first clean audit.
- **`quest_job`** is a new check: 1 once the named quest's job is accepted or has its row.
- **The gauge is a pressure gauge** [PLACEHOLDER], Tier 1, so the lab needs the WD-1 (400 CR from Bram, after the first clean audit opens Tier 1). That matches the gate. A lab that reaches S3 by lab level 6 without Tier 1 open cannot do the envelope yet, and it keeps coming back until it can.
- **Not modelled:** the as-found being out of tolerance "by design". A job has no as-found reading today; that and the honest-or-quiet choice wait for the later slice.
- **Chet owes you one is a line only.** Nothing is recorded for it. A later quest can ask the same question of the `job_log` row (`quest`, `on_time`, `traceable`).
- **Words and numbers are placeholders** [PLACEHOLDER]: Chet's four lines (`npcs/chet` in `data/dialogue_dispatches.json`), "Chet's customer", the job's line on the phone, 200 CR, the half, three days, 40 bench minutes.
- **Two older tests changed** (`test_quests.gd`): the list of known checks has `quest_job`, and the L3-closed test runs on L1 and L3 only, because it raises credibility past 20 and S3 now speaks there.
- **Tests added** (`tests/test_quests_s3.gd`, 21): S3's data and Chet's lines; the envelope not being a board template; the offer at credibility 20, at lab level 6, and not after a command; `any_gate`; the job in `active_jobs` with a board job's shape and never on the board through 12 days of refreshes in both bands; refused at the bench with no standard; clean, late, untraceable and both; a board job still cut twice; running out three times and then done clean; dropped three times; a save mid-quest, a finished save, a save with the envelope gone, an old save, a save with a bad mark; a guest's copy and a guest at the bench; bad `job` and `any_gate` data refused.

### After review (2026-11-26, agent's notes, not Ryan's words)

- **The envelope holds no space in the lab** [ASSUMPTION]. It was counted as a pressure job in progress. A lab at lab level 6 with one pressure space and no WD-1 could not do the envelope, had every pressure board job refused as "area is full", and could not clear the space either, while the envelope kept coming back. Now `jobs_in_progress` and `_lab_spaces_in_use` leave out a job with a `quest` mark, so the plan board, `job_area_problem` and `lab_clear_problem` count board jobs only. This matches `complete_job`, which never asked the envelope for an area, and `issue_quest_job`, which never asked the lab for room. So the envelope can be done beside a board job in a one-space area, and with no pressure area at all. Tell me if a quest's job should need an area like any other.
- **The save check is tighter.** A `job_board` entry with `quest` or `flat_cut_pct` is refused (a quest's job is never on the board), and so is a save with two `active_jobs` from one quest.
- **A finished envelope is not put in `_board_taken`.** That list holds the board's jobs off today's board; the envelope was never the board's.
- **The "ran out" line stays where it was.** The board's cancellations go through `_morning_notes`, which are posted after the morning's quest look. Sent that way, "ran out" would land after Chet's line and the new job's line. It is posted at once so the order stays ran out, Chet, new job.
- **Work that would end past the grace days cannot start.** `job_bench_problem` refuses it ("Not enough time") for the envelope as for a board job, so an envelope at the bench never crosses the 06:00 that would take it away. Work that crosses the 06:00 after the due day is late: 100 CR, and the morning in the middle of it hands out no second envelope.
- **Tests added** (3, and two made stricter; 24 in the file): the envelope out in a one-space pressure area (the space can be cleared, a board job is accepted, a second board job is not); bench work across dawn coming out late with 100 CR and no new envelope; work that would end past the grace days refused, then run out and handed out again at no cost; the save check refusing the marks on the board and two jobs from one quest; running out leaving credibility exactly as it was.

## 2026-11-26: Daily asks (build order step 14 of `docs/design/quests_levels_story.md`)

### Ryan chose

- Step 14: D2 as section 6 has it. One small ask a day for each player from lab level 3, picked by the day's seed. Lin: "Three Biscuit Reeds, in spec." Bram: "Two ore, if you are out that way." Odalys: "Check the rover's steering encoder against a block for me." Orin: "Till me a row by the beacon." 30 to 60 CR and a small XP certificate. A missed ask is gone the next morning with no penalty. Daily asks pay no quest points. The phone's look does not change and the quest log is not built here.

### Agent's notes (flagged for Ryan, not his words)

- **A daily ask is a quest of kind `daily`**, a player's own (`scope` player), in `data/quests.json`: `daily_lin_reeds`, `daily_bram_ore`, `daily_odalys_block`, `daily_orin_row`. The ids are in saves from now on. The engine refuses a daily that is not a player's own or that pays quest points.
- **No new farm field.** Today's ask is an entry in `player_quest_state` like any player's own quest, and its `accepted` (the day index) says which day it is of. `SaveGame.VERSION` stays 1 and `CoopSession.PROTOCOL` stays 16 (pinned in `test_quests_d2`). A guest sees their ask through `player_quest_state`, which is sent already; `QuestEngine.daily_ask` and `daily_done` read that alone, for a quest log later.
- **The pick** is `daily_roll(world_seed, day, player)`, the first 28 bits of a SHA-256 of the three, modulo the number of asks that are open to that player now. It draws nothing from the farm's generator, so asking changes nothing else, and the host and a reload agree. Because it is taken among the asks open at that moment, a farm that digs up its first block later in the day would roll differently, but by then the ask is held and is not picked again.
- **When it is given**: on an offering look, which is every morning and when a farm is opened, and for a guest when they come in (so a friend who drops in at noon has an ask). Reaching lab level 3 in the middle of a day gives nothing until the next morning or opening. A player who is away is not asked; their old ask is taken out when they are next present.
- **Missed or done, it goes the next morning.** An entry of an earlier day is erased on the next look. Nothing is said about it, nothing is paid and no credibility moves. The same ask can come again another day, and two players can be asked the same thing on the same day.
- **Counting starts when the ask is given**, as for any quest (the counters' base is taken at the offer).
- **Lin's ask counts the farm's sales** [ASSUMPTION]. `crops_sold_in_spec` is kept for the farm as a whole (Lin buys from the shared bin), so in co-op any player's sale of three in-spec Biscuit Reeds does it for whoever holds the ask. Odalys's counts the player's own checks. Bram's and Orin's were the player's own at first and count the farm's now: see "After review" below.
- **Lin's ask is not held back when no reeds are near ready.** It can come on a day it cannot be done. It costs nothing to miss. Tell me if it should wait for a planted reed.
- **Odalys's ask needs a block**: it is open only when `found_blocks` is not empty (a new check, `found_blocks`). Without one the roll is taken among the others. Blocks are the farm's, so one player's find opens it for all.
- **A check with a block is now counted** (the smallest record there was room for). `GameState.check_with_block(instrument_id, player_id)` adds one to `action_counts[player]["check_with_block:<instrument>"]` with 0 XP when the check gave a result; a refused check and the manager's are not counted. `FarmCommands` passes the player as it does for other actions. The check still changes no sensor, no drift, no log and no block; the older test "the check changes nothing" now leaves `action_counts` out of its comparison and asserts the count instead. An older build ignores the extra key.
- **"By the beacon" is loose** [ASSUMPTION]: Orin's row is six cells of the plot tilled by the player, anywhere. A cell's place is not recorded by `till`, and the plot is beside the beacon already. It is open only while six cells are left to till (a new check, `plot_untilled`), so a fully tilled plot is not asked for a row. If it should mean cells within some distance of the beacon, `till` would need to count those apart.
- **Paid once a day**: the credits (60 Lin, 40 Bram, 30 Odalys, 30 Orin) and one 25 XP certificate, all [PLACEHOLDER]. The certificate's rule "once per quest per player" is lifted for a daily: each day's ask gives its own. Spending one is not written to `xp_certificates_spent` (that list is what stops a second one, and would also grow for ever).
- **Daily asks stay on their farm.** They are left out of what travels in a guest's file (`travelling`, `player_quests`, the profile's held certificates), and a record that names one gives nothing on another farm. Otherwise a certificate earned on one farm could be claimed again on each farm visited. The certificate itself stays in that farm's save for the guest, as any held certificate does.
- **The line on the phone** is the giver's line and then what counts: `LIN: Three Biscuit Reeds, in spec. Today's ask: Sell Lin three in-spec Biscuit Reeds.` A normal quest says "New quest, <title>." there. In co-op the phone is shared and the line does not say which player it is for [ASSUMPTION]; the quest log (step 7) is where that belongs. Progress and "QUEST DONE" lines are the engine's usual ones.
- **Orin is new as a giver**: `npcs/orin` ("Old Orin") in `data/dialogue_dispatches.json`, with two lines. Bram gained a `quests` section. All eight lines are [PLACEHOLDER].
- **Three older tests changed**: `test_quests.gd` (the list of known checks has `found_blocks` and `plot_untilled`), `test_reference_blocks.gd` (above), and `test_quests_s2_l2.gd` (the rule that Odalys's lines end "Warmly, Dispatch." now applies to her S2 notes, not to every line she has; her daily lines are short).
- **Tests added** (`tests/test_quests_d2.gd`, 16): the data; no ask below lab level 3 and none after a command; one ask a day and its line; the pick being the same for the same seed, day and player, covering all four over 40 days, differing between players; the block ask never picked without a block and the row never with under six cells left; each of the four done and paid once with one certificate and no quest points; counting from when given; a missed ask gone with nothing lost and a new one given, also after days with nobody present; the same ask done on three days paying three times; a save mid-ask, a done save, a save loaded on a later day; the pick after a reload; an old save and a save with an unknown daily id; two players with their own asks, the guest's view through `FarmSync`, an away guest; picks apart over 12 days; the guest's file holding none of it and a claiming record paying nothing; a guest's block check.

### After review (2026-11-26, agent's notes, not Ryan's words)

- **An ask about something shared can no longer be put out of reach** [ASSUMPTION]. Orin's row was open while six cells were untilled but needed six of the asker's own tills, so a second player tilling could leave it impossible; Bram's ore had the same hole with the fissures. Now a counter step may say `whose: farm`, and then every player's doing counts, in a player's own quest too. Orin's and Bram's steps say so, as Lin's sale already did in effect. Bram's ask also has an offer: at least two fissures open (`fissures_open`, a new check; `GameState.open_fissures`). So the pool that the offer looks at can only shrink by doing what the ask counts. Each player who holds the ask is still paid once, their own: two players asked for the same row are both paid when six cells are tilled between them. Odalys's check stays the player's own; a check does not run out. Question for Ryan: is "anyone's tilling or mining counts for whoever was asked" right, or should a player have to do their own (and then an ask may sometimes be impossible, at no cost)?
- **Lin's ask is still the one that can be impossible on its day** (no reeds ready). Nothing is lost by it; question 3 in the PR stands.
- **The day of an ask turns at 06:00 only.** `GameClock.get_day_index` changes when `day_started` fires, so an ask worked on at 05:50 and finished before 06:00 pays, and at 06:00 the entry is erased and a new ask given; progress does not carry across. No code change, one test.
- **Certificates build up** [intended, for Ryan to confirm]. A daily certificate is held until its player spends it, so a player who does every ask and spends none holds one more each day (25 XP each, placeholder). Nothing caps the pile; it is in the farm's save under `xp_certificates`. If that should be capped, or the certificate should lapse with its day, say so.
- **The pick depends on what is open when it is made.** A player who comes in later in the day may roll among other asks than one there in the morning (a block dug up since, a row tilled since). An ask once given is held for its day and never picked again, through any look, save or load. Said in a code comment on `pick_daily` and tested.
- **Tests** (`tests/test_quests_d2.gd`, 20 now): four added (a shared ask never out of reach, for the row and the ore, and no ask with under two fissures open; the 06:00 turn; a forged record naming daily asks ignored by `take_brought`, held or not; a held ask kept when the pool changes, through a save and a load). The two-player test now has the row done between the two and both paid once. `test_the_four_asks_are_shipped` checks directly that no id in `player_quests()` is a daily. `test_reference_blocks.gd` now takes only the `check_with_block:` keys out of its comparison, not all of `action_counts`.

## 2026-11-26: Wring the Blocks and P3 (build order step 15 of `docs/design/quests_levels_story.md`)

### Ryan chose

- Step 15 as sections 7 and 5 have it: mini-game 2, Wring the Blocks (slide and turn, hold the slide's speed in the green; Earthworks widens the green), then P3, The Missing Blocks, from Old Orin: Earthworks 5 or two blocks found; find three more gauge blocks, check an instrument with a block, build a length Orin names; Earthworks XP, 1 quest point and a felt-lined case that is for show only. A poor try gives what a skip gives. The phone's look does not change and the quest log is not built here.

### Agent's notes (flagged for Ryan, not his words)

- **The game** (`scripts/minigames/wring_the_blocks.gd`, `ui/minigames/wring_the_blocks.tscn`) follows Set the Zero: one button (Space, E, Enter, a click or a pad's A), Esc skips, `finished(score)` with 0 to 100 or `MinigameScore.SKIPPED`, the motion from a seeded generator, `advance(seconds)` for tests. Three parts: pick the blocks, then for each joint a slide and a quarter turn.
- **The length** (`scripts/metrology/gauge_stack.gd`) is the sum of three pieces the farm holds (two if it holds two) [PLACEHOLDER], shown with a tray of up to six [PLACEHOLDER]. It is worked out from the farm's seed, the day, the player and the pieces held: one length a day for each player [ASSUMPTION], the same on the host and on a guest's screen, and nothing is saved. Any blocks that add up to it are taken, not only the ones it was made from. It is only ever a length; no instrument is named.
- **The slide.** Holding pushes the speed up and letting go eases it down; a drag that changes along the slide (its phase from the seed) makes the same hold push more or less. The score is the share of the slide, after a short lead-in, spent with the speed in the green; 90 % in the green is full marks. **The turn.** Holding turns the block at a speed from the seed (70 to 100 degrees a second); letting go at 90 degrees is 100, at the mark's edge 95, and it falls in a straight line to 0 at eight times the mark's half-width from 90 degrees (`MISS_AT = 8`). A joint is 60 % slide and 40 % turn; the stack's score is the mean of its joints. Every one of these numbers is [PLACEHOLDER].
- **Earthworks widens the green and the turn's mark**, from the base at level 1 to twice as wide at the top [PLACEHOLDER], by the same share Set the Zero takes from Calibration (`MinigameScore.sweet_share`, now with the skill as an argument). The design says "the green"; widening the mark too is mine [ASSUMPTION].
- **Section 7.5 holds here too**: Relaxed (wider, slower), Sharp (narrower), Off (no game; the build goes through as a skip); no hold over 2.5 s (the game lets go); nothing moves until the button is pressed, in the slide and again in the turn. There is no practice swing as Set the Zero has [ASSUMPTION].
- **How it is opened**: J from the stopped rover, with two gauge pieces or more, at any time [ASSUMPTION]. `build_block_stack` is a new host action (a guest asks the host, as for every action; no new message, `CoopSession.PROTOCOL` stays 16). Only P3's last step uses the score. A build outside the quest does nothing but count.
- **A score changes nothing but the quest's bonus.** `GameState.build_block_stack` raises `action_counts[player]["build_block_stack"]` (0 XP) and nothing else: no reading, as-found, verdict, tolerance, audit, log or block. So a skip and a poor try leave the very same farm (tested by comparing the whole saved farm). The manager's build is not counted.
- **P3 is `missing_blocks`**, with steps `find`, `check` and `stack`, in order. The ids are in saves from now on. Gate: `any_gate` of Earthworks 5 or `found_blocks` 2 (the farm's blocks, so in co-op one player's finds open it for all).
- **"Three more" counts the farm's finds after Orin asks** [ASSUMPTION]: a new counter `blocks_found` (the size of `found_blocks`), so any player's dig counts for whoever holds the quest, as blocks are shared. The check and the stack are the player's own. A counter may now end in `*` to add up every count that starts so: `check_with_block:*` is a check of any instrument.
- **The pay**: 150 Earthworks XP [PLACEHOLDER], 1 quest point, the case. P3 pays no credits, and the quest bonus (section 7.2) was a share of credits, so it would have been nothing. Now the same share is added to a quest's skill XP too: Fine 15 XP more, Reference 30 XP more [ASSUMPTION]. S1 pays no skill XP, so it is unchanged. Reference also has a line from Orin.
- **Keepsakes** are a new section `keepsakes` in `data/quests.json` (a name and a text). A quest's `rewards.keepsake` names one. A player holds the keepsakes of their own quests that are done (`QuestEngine.keepsakes_of`), so there is no new farm field (`SaveGame.VERSION` 1), it can't be held twice, it comes with the done quest in a guest's file, and it does nothing. The engine refuses a keepsake on a farm's quest, a daily ask or a quest with `closed_when`. Nothing shows keepsakes yet but the "QUEST DONE" line; a place to look at them belongs to step 10 or the quest log.
- **One older test changed**: `test_quest_minigame.gd` (a shipped mini-game step needed an instrument; a Wring the Blocks step has none).
- **Tests added**: `tests/test_wring_the_blocks.gd` (13) and `tests/test_quests_p3.gd` (16).

### After review (2026-11-26, agent's notes, not Ryan's words)

- **A score counts only where a step is open.** `build_block_stack` is not one of FarmCommands' `SCORED` actions (the host cannot replay the game), so the host now takes the sender's score only when that player has an open step that carries Wring the Blocks (`QuestEngine.has_minigame_step`, which now knows the stack step). Anywhere else the build is a skip, whatever was sent. On the player's own screen a game played with no ask open is shown with its grade and "Practice: nothing is kept."
- **The length played is sent with the score.** `build_block_stack(target, score)`: the host compares the length the screen showed with today's. If they differ (the day turned at 06:00 mid-game, or a find reached the farm), today's length is built, the answer has `changed`, the score is a skip's, and the phone says "the length asked for changed while you worked ... the try is not graded." No new message; `CoopSession.PROTOCOL` stays 16 (the action's arguments changed inside this same unmerged PR).
- **The blocks picked on the screen are not checked by the host.** Picking is part of the game on the player's PC, and is not sent. The host builds the length from the pieces it holds. A changed client could skip the picking; all it could gain is the score, which is bounded as above and pays at most the grade's bonus XP [ASSUMPTION that this is acceptable for co-op with friends].
- **The bonus is the player's who played.** `missing_blocks` is `scope: player`; a guest who finishes at Reference gets the 150 XP and the 30 more, and the host gets nothing (tested).
- **Nits.** The note above on the turn's score was wrong and is corrected (the code was right and is unchanged: 0 at eight times the mark's half-width, `MISS_AT = 8` [PLACEHOLDER]). `GaugeStack.stack_seed` is now a SHA-256 of text, as `QuestEngine.daily_roll` is, so every PC and build gets the same length; a day's length is therefore another than before this commit. A guest's `gauge_pieces()` is tested to equal the host's, order and all (no fix was needed). When the game ends a hold at 2.5 s the screen says "The hold ran out. Press again to go on." A Relaxed turn is tested to reach the mark within one hold (the slowest is 70 x 0.7 x 2.5 = 122.5 degrees).

### Questions for Ryan

1. P3 pays no credits. Is "the grade's bonus goes on the skill XP too" right (Fine +10 %, Reference +20 %), or should P3 pay some credits and keep the bonus there?
2. "Find three more": should any player's find count for whoever holds P3 (as built, since blocks are shared), or only the player's own digs?
3. One length a day for each player, and only a length. Should Orin name a new length on every try, or name an instrument to check with the stack?
4. J from the stopped rover opens the game whenever two blocks are held. Should it be at the lab or bench instead, or only while P3's step is open?
5. Any blocks that add up are accepted; a tray of six, a stack of three. Right sizes?
6. The turn's mark widens with Earthworks as the green does. Keep, or only the green?
7. No practice swing in this game. Add one?
8. The tuning numbers and the 150 XP are placeholders: say if any feels wrong when played.
9. Where should the felt-lined case show before the collection (step 10) exists? Today it is only named on the phone.
10. Orin's three lines are placeholders.
11. The host does not check which blocks were picked on the screen, and takes the player's own score (only where a Wring the Blocks step is open, and only for today's length). Is that enough for co-op with friends, or should the picks be sent and checked?

## 2026-11-26: Hold the Reading (build order step 16 of `docs/design/quests_levels_story.md`, mini-game 3)

### Ryan chose

- Step 16 as section 7 has it: mini-game 3, Hold the Reading (the reading wanders as the standard settles; hold to lift the bracket, let go to drop it; the score is the share of time inside; 10 to 15 s). Its score scales the operator's uncertainty term by Set the Zero's factors and never the standard's own uncertainty. Uncertainty slows the wander, to half speed at 99.

### Agent's notes (flagged for Ryan, not his words)

- **The game** (`scripts/minigames/hold_the_reading.gd`, `ui/minigames/hold_the_reading.tscn`) follows the other two: one button (Space, E, Enter, a click or a pad's A), Esc skips, `finished(score)` with 0 to 100 or `MinigameScore.SKIPPED`, the motion from a seeded generator, `advance(seconds)` for tests, fixed 1/60 s steps so the frame rate does not change a score, and the farm's clock speed does not run it.
- **The wander** is three slow sine waves (0.11, 0.19 and 0.31 Hz, shares 0.5, 0.3, 0.2, phases from the seed) on a chart of -1 to 1, at 0.8 of the chart, calming in a straight line to 35 % by the end of the run [PLACEHOLDER, all of them]. The run is 12 s [PLACEHOLDER], inside the design's 10 to 15 s. The bracket is 0.18 of the chart each side of its middle [PLACEHOLDER]; holding lifts it and letting go drops it, with a little drag. The chart shows the trace of the last 4 s, the bracket, the word IN or OUT (so it does not rest on colour), and a bar of the time left.
- **Uncertainty slows the wander**: the waves run at full speed at level 1 and at half speed at 99, by the same front-loaded share the other games take from their skills (`MinigameScore.sweet_share` with `uncertainty`). It is each player's own skill. It does not change the bracket's height: that is the tolerance band, and only the difficulty sets it.
- **Section 7.5 holds**: Relaxed (bracket 50 % taller, slower wander), Sharp (shorter bracket, faster), Off (no game; one click as before); no hold over 2.5 s [PLACEHOLDER] (the game lets go, says "The hold ran out. Press again to lift.", and only a new press lifts again); nothing moves until the first press. There is no practice swing [ASSUMPTION].
- **Which calibrations get it** [ASSUMPTION]: a unit (not a standard) whose standard today is the humidity generator or the pressure controller (`MinigameScore.SETTLING_STANDARDS`, `MinigameScore.game_for`). Today that is the hygrometer, and the dome pressure sensor once the pressure controller is bought and takes it over from the WD-1 gauge (`takes_over`); until then the dome pressure sensor plays Set the Zero. The WD-1 gauge is calibrated against the pressure controller too, and it is a standard. Every other calibration keeps Set the Zero. A standard's own calibration keeps Set the Zero because the U of that calibration goes on the standard's in-house certificate, and a score must never change a standard's uncertainty.
- **When it appears** is as Set the Zero: the lab's first calibration of a kind, an open quest step that carries a bench game for the instrument, or CAREFUL. The hygrometer is in service on every new farm, so its first calibration opens Hold the Reading, and that may be the first mini-game a new player meets.
- **What a score is worth.** Good, Fine and Reference leave 0.8, 0.6 and 0.4 of the operator's term (`u_op`) in the uncertainty the record states (`MinigameScore.operator_factor`, the same table as the residual's). The factor waits on `DriftingSensor.next_operator_scale` (not saved), is used by the next `GameState.calibrate` of that instrument and is 1.0 again after it, refused or not. The record's `standard_uncertainty` and `tur` come from the budget with that one term scaled. The standard's own terms, the resolution, a robot's term and k are untouched.
- **What it never changes** [ASSUMPTION]: the TUR refusal, the acceptance limit and the pass/fail verdict are worked from the plain budget, so a score cannot pass a calibration a skip would fail or refuse. The as-found and as-left readings, the interval, the due day, audits and the standard's certificate are as a skip leaves them. A Hold the Reading unit takes no smaller as-left residual, and a Set the Zero unit no smaller operator's term: one factor each, never both.
- **No XP from a score** (changed after review): the clean-TUR XP is judged on the plain TUR, which every record now keeps as `plain_tur`. Tests compare the whole farm with and without a score and allow only the record's stated U and TUR to differ.
- **A skip and a poor try** (under 60) leave exactly the same farm, compared whole (`farm_to_dict`) in the tests.
- **Co-op**: the host picks the game from the instrument, so a guest never says which game it played and `calibrate_at_bench` is unchanged (`CoopSession.PROTOCOL` stays 16). The host counts a guest's score only where a game could have been due (`MinigameScore.allowed`) and holds it to 0 to 100. No new farm field; `SaveGame.VERSION` stays 1.
- **Quests**: `hold_the_reading` is a mini-game a step may carry (a count of one instrument's `cal_log` rows, as for Set the Zero). A step that names either bench game is graded by the game its instrument plays (`MinigameScore.grades_step`), so a step on the hygrometer that names `set_the_zero` would be played and graded as Hold the Reading. S1's step is on the soil probe (gravimetric kit) and stays Set the Zero. No quest was added or changed.
- **The bench** shows "Hold score N of 100: GRADE, your share of the uncertainty X % smaller." and the budget view shows the terms with the operator's term at the score's factor. The phone's look is unchanged.
- **One older test changed**: `tests/test_set_the_zero.gd` used the hygrometer; it now uses the rover's steering encoder, a Set the Zero unit that is in service on a new farm.
- **Tests added**: `tests/test_hold_the_reading.gd` (22; 26 after review).

### After review (2026-11-26, agent's notes, not Ryan's words)

A second model (Sonnet) reviewed the PR. What changed:

- **A score earns no XP.** The clean-TUR XP (Uncertainty XP and lab XP) read the record's lifted TUR, so a Reference score could earn XP a skip would not, and that skill feeds back into later operator terms. It is now judged on the plain budget's TUR. Every calibration record keeps that as `plain_tur` beside `tur` (a key in the record, not a farm field; a record without it reads as plain; `SaveGame.VERSION` stays 1). The whole-farm test now allows only the record's `standard_uncertainty` and `tur` to differ, and a new test puts the hygrometer's plain TUR just under the clean line: a Reference score lifts the stated TUR over it and earns nothing more.
- **The frame rate cannot change a score.** `advance()` keeps what is left of a frame and moves only in whole 1/60 s steps. Tests give frames of 1/60, 1/30, 1/144, 0.05 and 0.1 s and uneven mixes: the same run and score.
- **A standard and a robot take no factor**, even if one is left waiting: `GameState.calibrate()` takes the factor back and does not use it when the instrument is a standard or a robot does the calibration.
- **Co-op trust, said plainly** [ASSUMPTION]: the host checks that a game could have been due and holds the score to 0 to 100. It cannot know the game was played, or how well; the score is the sender's word, as for Set the Zero. Among friends that is accepted. A made-up score can gain the record's stated U and TUR (or the smaller as-left residual of Set the Zero) and a quest's bonus, never a verdict, an audit or XP.
- **The bench names the figures.** After a counted score the standard line reads "TUR 4.6:1 (U and TUR with your steady hold)". If the plain TUR is under the clean line it reads "(U and TUR with your steady hold; without it TUR 3.9:1, marginal, under 4:1)". The verdict and the limit are on the plain basis. The phone shows no TUR from a bench calibration, and its look is unchanged.
- **Quest data is checked**: a step must name a bench game its instrument plays by the data (`MinigameScore.games_in_data`), or the quest does not load: `hold_the_reading` on the soil probe or on a standard is refused, and so is `set_the_zero` on the hygrometer. The dome pressure sensor may name either, since buying the pressure controller changes its game; for that one case a step is still graded by the game played (`MinigameScore.grades_step`). S1 loads as before. The fixtures of `tests/test_quest_minigame.gd` named the hygrometer with Set the Zero and now name the steering encoder.
- **Small things**: the hold cap's comment says 2.5 s; the result line is in plain words; the grade test checks the exact factors 0.8, 0.6, 0.4, 0.4; the helper's note in `tests/test_set_the_zero.gd` names the steering encoder. No assertion was lost in that switch (it was a change of id), and the hygrometer's budget is checked in `tests/test_hold_the_reading.gd`.

### Questions for Ryan

1. Which calibrations should get Hold the Reading? As built: units calibrated against the MD-2P humidity generator or the HB-700 pressure controller, so the hygrometer, and the dome pressure sensor once the pressure controller takes it over. Standards keep Set the Zero.
2. The hygrometer is in service on a new farm, so its first calibration opens the 12 s Hold the Reading, and that may be the first mini-game a player meets, before Set the Zero (S1's soil probe step is still Set the Zero). Is that all right, or should the first game always be Set the Zero?
3. The record states the smaller U and the higher TUR, while the acceptance limit, the verdict and the TUR refusal stay on the plain budget. Keep that, or should the limit follow the smaller U (then a score could change a verdict)?
4. The clean-TUR XP is judged on the plain TUR, so a score earns no XP (changed after review). Right, or should a steady hold that lifts the TUR over the clean line earn it?
5. The numbers are placeholders: a 12 s run, a bracket of 0.18, three waves, calming to 35 %, a 2.5 s hold cap. Say if any feels wrong when played.
6. A quest step must name a game its instrument plays, or the quest does not load. The dome pressure sensor may name either bench game and is graded by the one played, because buying the pressure controller changes its game. Right?
7. No practice swing here either. Add one?
8. In co-op the host cannot know a guest played the game; it checks only that a game could have been due and holds the score to 0 to 100 (the same as Set the Zero). Accepted among friends, or should the host replay the guest's presses to check a score (a larger change, and a new protocol)?

## 2026-11-26: Thread the Spool (build order step 16 of `docs/design/quests_levels_story.md`, mini-game 5)

Built from section 7 of the design (7.1 row 5, 7.2 to 7.6). Every number is a placeholder and is a named constant in `scripts/minigames/thread_the_spool.gd` or a row of `MinigameScore.GRADES`.

- **The game**: the spool hangs from the player's hand and sways. The sway is a sum of three slow waves whose starting points come from a seed, so the same seed gives the same sway in a test or a replay. Left and Right push the hand; the first press starts an 8 s lowering. Nothing moves before that press. The game moves in whole steps of 1/60 s, so the frame rate does not change a score.
- **The score**: 0 to 100 from the spool's mean distance from the slot over the last 1.5 s of the lowering. Inside the slot is 95 to 100; it falls in a line to 0 at eight slot half-widths. [ASSUMPTION: the design says "centering at the moment of seating"; one instant would make the score a matter of one frame, so the last 1.5 s is read.]
- **Husbandry** (section 7.3): slows the sway's clock, to half speed at level 99, by `MinigameScore.sweet_share`, the same front-loaded curve the other games use. [ASSUMPTION: the design gives no size.] The difficulty setting widens or narrows the slot and speeds the sway as it does the other games' marks.
- **When it plays** (section 7.4): only while this player has an open quest step that carries `thread_the_spool`. Such a step must be a counter of `slot_spool`, or the quest does not load. The farm screen's relay button opens the game then; Skip, the game switched off, and a farm with no such step all seat the spool as before.
- **The quest**: no quest counted seated spools, so one small quest was added to make the game reachable: `a_clean_line` (Odalys, kind lab, farm-wide), offered on a morning with a spool in stock; one step, seat a spool; 60 CR and 100 lab XP. Its words and pay are placeholders.
- **What a score does**: the host hands its cut of the score to `GameState.slot_spool_into_relay(player_id, score)`, which reads it in one place: the seat's Husbandry XP and lab XP are times 1.15 (Good), 1.3 (Fine) or 1.5 (Reference), as section 7.2's table says. The score is also kept with the quest step, so the quest pays its Fine or Reference bonus and Odalys has a Reference line. Which spool is taken, whether it is damaged, the lag multiplier, the stock and the relay are the same at every score. There is no wear mechanic.
- **Skip and a poor try**: a score under 60 leaves the farm exactly as a skip leaves it. A test compares the whole saved farm.
- **The host's cut**: the score rides as the last argument of `slot_spool_into_relay`, as it does for `calibrate_at_bench`, so the protocol is still 16 and the save version still 1. No farm field was added. With no open step for the sender the score becomes SKIPPED; otherwise it is held to 0 to 100.
- **Not built**: the practice swing (section 7.5). The tunnels' relay button seats a spool with one click and does not open the game.

### Questions for Ryan

1. Should a good seat last longer, once spools wear? Spools do not wear today and no wear was added; the design's "seated spool takes less wear" is waiting on that.
2. This is the first score that is worth XP: times 1.15, 1.3 or 1.5 on one seat's 25 Husbandry XP and its lab XP, and only while the quest step is open. Hold the Reading's review took XP away from a score, because in co-op the score is the sender's word. Keep the multiplier here (at most 13 more Husbandry XP per quest), and should the other games get it?
3. The new quest "A Clean Line": is Odalys the right giver, and are 60 CR, 100 lab XP and her three lines all right? Should it repeat, so the game comes back?
4. The score reads the last 1.5 s of the lowering, not the last instant. Right?
5. The numbers: an 8 s lowering, half-speed sway at Husbandry 99, a slot 4 % of the reach wide each side, a 2.5 s hold cap. A spool nobody steers earned no more than Fine in testing and usually no grade. Say if any feels wrong when played.
6. Three edges: on a farm whose best spool is already seated, the step waits for a better or a replacement spool; a spool collected and seated on the same day never sees the ask; the tunnels' relay button does not open the game. Change any of these?
7. No practice swing here either. Add one?

## 2026-11-26: Bram's wheel service (build order step 16 of `docs/design/quests_levels_story.md`, the repair action for mini-game 4)

Torque to Spec (section 7.1 row 4) needs a rover repair action to plug into, and there was none. This is the smallest one. The game is not built.

- **The action**: Bram re-torques the rover's five wheel nuts, in star order. In his bay, press Y or the new button under his trade. One press does it.
- **When it is due**: after the rover has driven 1500 m since the last service [PLACEHOLDER, `wheel_service/due_m` in `data/items.json`]. The meters are counted where the steering encoder's are, in `GameState.add_rover_usage`, so in co-op the host counts everyone's driving. When they come due Bram posts one line to the phone, and the bay says so on the way in.
- **No penalty**: nothing reads the meters but the service. An overdue rover drives, steers, wears and sells the same. A test compares the whole saved farm with and without overdue nuts.
- **Why a plain odometer and not the tire gauge or the steering encoder**: those are calibrated sensors with due dates and drift. Tying the nuts to one of them would give a bay service a metrology consequence, which is a penalty by another name.
- **What a service gives**: 25 Robotics XP to the player who asked (source `service_wheels`, sized like `slot_spool`) and 10 lab XP to the farm (source `lab_wheels`) [PLACEHOLDER, `data/skills.json`]. It is free. Because it is an XP source it is counted, so a quest step may be a counter of `service_wheels`.
- **Refusals**: on foot (the usual line), the rover in the tunnels, and not due (with the meters driven and the distance). The host does not check that the rover stands in Bram's bay; the screen does, as it does for his wide treads.
- **The score**: `service_wheels(player_id, score)` has the trailing score argument the other scored actions have. Nothing reads it, and `service_wheels` is not in `FarmCommands.SCORED`, so a guest cannot send one. What a good score is worth is left to the game's PR.
- **Co-op and saves**: the action rides the command path, so the protocol is still 16. One farm field was added, `wheel_meters`, as a later field: the save version is still 1 and a save without it loads with nothing driven. A new signal, `wheels_changed`, tells a guest's screen.
- **The phone**: the button is built in code inside Bram's panel. No scene and no look was changed.

### Questions for Ryan

1. Is 1500 m between services about right? It is a guess; say how often a visit to Bram should come up.
2. Section 3.2 says driving does not feed the lab level, and the lab's source list is fixed by a test. A bay service is not driving, so it gives 10 lab XP and the list has one more row. Keep it, or should a service give Robotics XP only?
3. Is 25 Robotics XP right (the same as seating a spool or calibrating a robot)?
4. Should overdue nuts ever matter? Today they never do. Your call if a mild cost is wanted later.
5. The service is free. Should Bram charge credits or ore?
6. The host does not check the rover is in the bay, the same as for wide treads. Tighten both, or leave both?
7. When Torque to Spec is built, what should a good score be worth: more XP on the service (as the spool does), a longer distance to the next one, or only a quest grade?
8. The key is Y and Bram's words are placeholders. Change any?

## 2026-11-26: Torque to Spec (build order step 16 of `docs/design/quests_levels_story.md`, mini-game 4)

Built from section 7 of the design (7.1 row 4, 7.2 to 7.6), on Bram's wheel service. It follows Thread the Spool's pattern throughout. Every number is a placeholder and is a named constant in `scripts/minigames/torque_to_spec.gd` or a row of `MinigameScore.GRADES`.

- **The game**: five wheel nuts, tightened in star order (top, then two places on each time). The wheel shows which nut is next by a ring, a pointer and its number, not by colour alone. For each nut the player presses and holds one button while the torque climbs a bar, and lets go at the click line. The game moves in whole steps of 1/60 s with the remainder carried, so the frame rate does not change a score.
- **Seeded**: the seed sets each nut's click line (60 to 85 % of the bar), how long a steady climb takes to reach it (0.9 to 1.5 s on Standard) and where the climb's surge starts. The climb swells and eases by 30 % but never stops or runs back. The same seed and the same presses give the same score.
- **Nothing moves before a press**: each nut waits for a press of its own, with no clock on the wait. [ASSUMPTION: the design says nothing moves before the first press; waiting before every nut is kinder and costs nothing.]
- **The hold cap**: no hold runs over 2.5 s (section 7.5 allows 3 s). At the cap, or at the bar's end, the game lets go and that nut is a miss (0): by then it is over the line on every difficulty, and the player never let go. (Changed after review: holding every nut to the top used to earn a grade at high Calibration.) A key still held down does not start the next nut.
- **The score**: a nut's closeness is 100 on the line, 95 at the sweet spot's edge, and falls in a line to 0 at a fixed 32 % of the bar from the line [PLACEHOLDER], so Calibration and the difficulty widen only the sweet spot and never move where a miss begins (changed after review); under and over count the same. The score is the mean of the five, 0 to 100.
- **Calibration** (section 7.3): widens the sweet spot, to twice as wide at level 99, by `MinigameScore.sweet_share`, the same front-loaded curve the other games use. The base sweet spot is 4 % of the bar each side. Relaxed is 50 % wider with a climb at 0.7 speed; Sharp is 25 % narrower at 1.2 speed; Off opens no game.
- **When it plays** (section 7.4): only while this player has an open quest step that carries `torque_to_spec`, the nuts are due, the rover is in Bram's bay and stopped, and the player is in it. Such a step must be a counter of `service_wheels`, or the quest does not load. Skip, the game switched off, and a farm with no such step all service the wheels as before.
- **The quest**: `to_the_click` (Bram, kind lab, farm-wide), offered on a morning with the nuts due; one step, a wheel service; 60 CR and 100 lab XP. Kind lab and farm-wide because the rover is the farm's, as the relay is for `a_clean_line`. The offer uses one new check, `wheels_due`, which reads `GameState.wheels_due()`. Its words and pay are placeholders.
- **What a score does**: the host hands its cut of the score to `GameState.service_wheels(player_id, score)`, which reads it in one place: that service's Robotics XP and lab XP are times 1.15 (Good), 1.3 (Fine) or 1.5 (Reference). The score is also kept with the quest step, so the quest pays its Fine or Reference bonus and Bram has a Reference line. The meters reset, the distance to the next service and everything else are the same at every score. A test lists the saved farm fields that may differ (XP, credits, the quest's state, the phone) and fails on any other.
- **Not built, on purpose**: section 7.2 says a repair's score "scales how long the repair lasts". Here the next service is due after the same 1500 m at any score, and no wear or penalty was added.
- **Skip and a poor try**: a score under 60 leaves the farm exactly as a skip leaves it. A test compares the whole saved farm and the phone log.
- **The host's cut**: `service_wheels` is now in `FarmCommands.SCORED`, so the score rides as the command's last argument: the protocol is still 16 and the save version still 1. No farm field was added. With no open step for the sender the score becomes SKIPPED; otherwise it is held to 0 to 100. A refused service (not due, on foot, in the tunnels) takes no score.
- **The phone**: no look was changed. The game is its own overlay scene, copied from Hold the Reading's.
- **Not built**: the practice swing (section 7.5).

### Questions for Ryan

1. Should a good torque make the service last longer (section 7.2)? Today the score changes only XP and the quest's grade; the next service is always 1500 m on. This also answers question 7 of the wheel service: for now, more XP and a quest grade.
2. "To the Click" is offered once, so the game is played once per farm, as with "A Clean Line". Should it come back at every service (a repeating ask from Bram), or play at every service with no quest at all?
3. Quests are offered in the morning. If the nuts come due and are serviced the same day, Bram never asks that time; he asks on the next morning they are due. All right?
4. Each nut waits for its own press, so the player can rest between nuts. Or should the five run on one clock after the first press?
5. Over the line counts the same as under. Should an over-torqued nut score worse (it is the worse fault on a real wheel)?
6. The numbers: click lines at 60 to 85 % of the bar, climbs of 0.9 to 1.5 s, a 30 % surge, a sweet spot of 4 % each side (8 % at Calibration 99), a 2.5 s hold cap. Say if any feels wrong when played.
7. Bram's three lines, 60 CR and 100 lab XP are placeholders. Change any?
8. No practice swing here either. Add one?

## 2026-11-26: Lab-level gates (build order step 9 of `docs/design/quests_levels_story.md`)

Ryan decided to turn on the section 3.4 table with its numbers as they are (all [PLACEHOLDER], to tune after play).

- **The table** is `lab_gates` in `data/skills.json`. A thing opens when the lab level is reached and its old condition holds. Built and gated: daily asks 3 (still in `data/quests.json`, checked equal by a test), Tier 1 at 5, job board 10, OIRM account 12, first contract 15 (offered by its old rule, provisional below the level), Tier 2 at 18, medium lab 20, robot 1 at 25, COLLECT SPOOL cards 30, robot 2 at 35, Tier 3 at 40, CALIBRATE cards 42, large lab and Accredited jobs 45, robot 3 at 65, robot 4 at 75.
- **Not built, so not gated** (rows kept with `built: false`): certificate wall 8, 4th job 28, second contract 35, relay dish 48, master audit 52, intrinsic silk contract 56, the Larder 60, 5th job 65, robot paint 85, plaque 92, gold border 99.
- **Existing saves** keep what they had open: `lab_gates_kept` (new saved field, `SAVED_LATER`, no version bump, no protocol bump, not shown by a signal because it only changes on load) is made once on a load with no such key. A farm that had finished the first contract also keeps Bram's sale of its standard with no tier gate.
- **The contract discount does not bypass the Tier 3 gate** [decided, section 3.4]. The old code did skip the OIRM, sign-off and Tier 2 conditions for the contract's standard; that is changed for new farms. Bram still lists it ("needs lab level 40") and the discount is held.
- **Where it shows**: the reason is in plain words ("Tier 2 equipment needs lab level 18 (the lab is level 9)."), on Bram's and the Kestrel's buttons ("needs lab level 18"), the Plan board's grow button, the job board note, the robot build and job card reasons, and the level-up phone line names what opens. The host enforces; a guest's copy has the same lab XP and kept rows.
- **[ASSUMPTION] The provisional way through**: the first contract's quest pays 75 % of the lab XP still missing to level 15 on top of its 400 (`lab_level/provisional_gap_share`); none if the row is kept. The OIRM account has no quest of its own to be provisional with, so it just waits for its level.
- **Hours** (test prints them; budget 20 at 5 h, 40 at 20 h, 60 at 50 h, log-linear between): level 5 at 2.2 h, 10 at 3.4 h, 12 at 3.8 h, 15 at 4.3 h, 18 at 4.7 h, 20 at 5.0 h, 25 at 9.0 h, 30 at 12.7 h, 35 at 16.4 h, 40 at 20 h, 42 at 23 h, 45 at 27.6 h, 60 at 50 h, 65 at 57 h, 75 at 72 h, 99 at 108 h. The lab XP an hour this asks is 512 (levels 1-20), 1 168 (20-40) and 3 928 (40-60), about 20, 10 and 5 traceable calibrations an hour. Every story beat is at or below 60.

### Ryan decided 2026-11-26

1. The contract's HB-700 may wait for Tier 3 (lab level 40) on a new farm.
2. The first contract is still offered below level 15 by its old Trusted rule (the provisional way through). This settles review finding 4.
3. Robot 2 and COLLECT SPOOL keep both the lab level and Robotics.

### Review follow-up (Opus, 2026-11-26)

- **Seeding order**: `_keep_open_gates()` now runs at the end of `put_farm`, after the calibration records and certificates are rebuilt from their logs, so a boot load or a second load reads the loaded save and nothing else.
- **Seeding keeps every gate the old rule had open at load**: also the next lab size (it needed credits and ore only), `oirm_account` for a save that owns a bought Tier 1 or higher standard, and the contract sale for a contract that is active, complete or fulfilled.
- **The level-up refreshes**: Bram's list, the Kestrel screen and the Plan board redraw on `lab_xp_changed`, so a "needs lab level" button changes at once.
- **Decision line (hours model, unchanged)**: the hours model is self-referential (the budget anchors 20/40/60 at 5/20/50 h and the printed hours come from that same budget, with a +50 offset in the test's curve); it shows the shape of the table, not a measured play time. Left as is.

## 2026-11-26: Quest log on the phone (build order step 7 of `docs/design/quests_levels_story.md`)

Built from Ryan's decision of 2026-11-26: a QUESTS view opened by a key, the same way the SKILLS view opens, in the phone's current look.

- **The key is O, not Q**: Ryan asked for Q, but on the farm Q is already the check with a block (`main_farm.gd`). O was free everywhere (so were I, M, P, U, X and Z). [ASSUMPTION: a free key is better than moving the block check.] It is one constant, `QuestsUI.KEY`.
- **The look**: `QuestsUI` copies `SkillsUI`: the same panel, label and button helpers, and the same three colours, read from `SkillsUI`. No colour, font or frame was added. Like the SKILLS view it is added on the farm, in the dome and in the tunnels, closes with its key or Esc, and lets no key through while open. It does not open over the SKILLS view.
- **What it lists**: the open quests of the player at the keyboard: the farm's (`quest_state`) and their own (`player_quest_state`), with today's daily ask. Each has a line "GIVER: Title  (kind)" and under it the first step not done, in the words `data/quests.json` already had. No word was added to the data. A daily ask says "(today)". Then DONE and the done quests, grey.
- **One list, ordered by kind**: story, lab, personal, daily, then the file's order. Section 5.5 asks for four headed lists; with thirteen quests one list reads well enough. [ASSUMPTION]
- **Counts**: a step that counts to more than one says "2 of 3". The count is the one the host last wrote in the quest's entry (`shown`), the same number the phone line said. The OIRM contract's step shows the farm's `contract_run`. Other steps show no count.
- **Guests**: the list is the pure function `QuestLog.build`, which reads the quests' data, the two quest dictionaries and the contract's run, and no check. A guest has all of those from the host (`quests_changed`, `credibility_changed`), so a guest sees their own list and never runs the quest engine. A test joins a guest, empties what a check would read on the guest's copy, and compares the lists.
- **Closed quests are left out**: a farm quest the engine closed with nothing paid (`closed_when`) was never told to the player, so it is in neither list. [ASSUMPTION] A player's quest that was done on another farm is listed as done.
- **A daily ask of another day** is not listed, done or not.
- **Words** [PLACEHOLDER]: "QUESTS", "DONE", "No open quests. A new one comes with the morning.", "(today)", "2 of 3".
- **Not built**: the pin, the reward in the DONE list, a scroll bar for a long list, and any accepting or handing in from the view. No gates, no reward changes.
- **No save or protocol change**: the save version is still 1 and the protocol still 16.

### Questions for Ryan

1. Q was taken by the block check, so the view is on O. Keep O, or move the block check to another key and give Q to quests?
2. One list ordered by kind, or the four headed lists of section 5.5 (STORY, LAB, PERSONAL, TODAY)?
3. Should the DONE list say what each quest gave (section 5.5)?
4. Do you want the pin (one quest's next step kept on the phone, section 5.5) as its own small job?
5. A quest the game closed without pay (its offer went stale) is hidden. Or should it show as closed?
6. The DONE list will grow. Scroll it, or show only the last few?


## 2026-11-26: One-use rewards and keepsakes (build order step 10 of `docs/design/quests_levels_story.md`)

Ryan's answers: a one-use reward is spent on its own on the next action it is for, with a phone line saying so; the two are Bram's 10 % discount on the next standard (P1) and a free refit of one lab area (L4); a keepsake shelf in the dome shows the keepsakes held, and the QUESTS page lists them.

- **How it is given.** `"one_use": "<id>"` in a quest's `rewards`, an id in `one_use_rewards` of `data/quests.json`. `QuestEngine._finish` gives it with `GameState.give_one_use` (host only) and posts the reward's `held_line`. The data check refuses an unknown id, a daily ask's, a player's reward on a farm quest and a farm's on a player quest.
- **Where it is held.** `one_use_held` (holder -> reward -> count), a saved farm field: in `SAVED_LATER`, checked in `farm_dict_problem` (counts 1 to 9, rewards the data has, the right kind of holder), shown to guests by `FarmSync.SHOWN_BY` (`one_use_changed`). A player's reward is held under their id, the farm's under `_farm`. [ASSUMPTION] The most of one reward a holder keeps is 9.
- **Bram's discount.** [PLACEHOLDER] 10 %. It takes the percent off after the contract's discount, for Bram's stock only; the catalog (`standard_price_text` / `standard_price_credits`) shows the discounted price and "(10 % off, one use)" while one is held. `buy_standard` spends it only after the purchase has gone through, so a refusal (a gate, too little money) keeps it, and the lab-level and old gates are checked first as before. The discount is the buying player's own.
- **The free refit.** [ASSUMPTION] The smallest fitting thing: clearing a lab area (`clear_lab_area`, the "refit") costs nothing while the farm holds one. The day it takes stays and fitting the space out again is as it was. The next clear is paid for.
- **Keepsake shelf.** `scripts/dome/keepsake_shelf.gd` on the dome's back wall: a plank and one object for each keepsake the local player holds (`QuestEngine.keepsakes_of`), rebuilt when quests change or a farm loads; click to read the name and text through the dome's toast, as the mug ring does. [PLACEHOLDER] The objects are a small box (a cylinder for the watch) in the greybox look: there is no voxel model for them yet. `pocket_watch` is a keepsake in the data with a [PLACEHOLDER] text. The QUESTS page gets a short KEEPSAKES list in the present phone style (no new colors, fonts or frames).
- **Co-op.** The host spends rewards; guests see the result with the farm snapshot. A held reward stays on the farm that gave it: it is not in a guest's own file (the file keeps only what travels: quest points and certificates). A keepsake follows section 10 Q7 and what `keepsakes_of` already does.
- **No change** to `SaveGame.VERSION` (1) or `CoopSession.PROTOCOL` (16): a save from before has no `one_use_held` and holds none.

### Questions for Ryan

- Is 10 % right for the discount, and is "the next lab space cleared costs nothing" the right reading of a free refit?
- Should a held reward travel in a guest's own file, so the discount a guest earned goes with them to another farm?

## 2026-11-26: Quests L4, P1 and P2 (build order step 12, part 2, of quests_levels_story.md)

### Ryan chose

- The second half of step 12: L4 "Greenhouse Four" (Bram, lab level 20), P1 "Bram's Ore Run" (Bram, lab level 5) and P2 "On the Dot" (a skill challenge, Uncertainty 5), as section 6 of the design has them, with the smallest stand-in wherever the game lacks the exact check. No new systems.

### Agent's notes (flagged for Ryan, not his words)

- **No favor system exists, so P1 is just Bram's quest.** The design says P1 "introduces favors"; nothing in the game gives or owes a favor. P1 is Bram's own quest for each player: mine five fissures yourself. The first real favor is left for when favors are built.
- **L4 has three steps, in any order** (review fix, same day). Money is no step: the grow takes the 600 CR and 4 ore when it starts, and a player who started it before Bram asked (the medium lab opens at lab level 20 but quests are offered at the next morning) would otherwise be asked for the money again. The steps: `grow` (the `lab_size` check with `with_grow`: a grow under way, or a medium lab already, counts), `move_in` (`lab_size >= 1`, ready two days after the grow starts) and `fit` (the `lab_area` counter). Any order, so the fit counts from the offer and a fit done while the grow runs is not lost to a baseline reset at move-in. A small lab has no free space during a grow, so in practice the fit follows the move-in.
- **"Fit one new area" is the `lab_area` counter.** It counts only a space the area never had before (`lab_areas_paid`), from the offer, so a space cleared and fitted again does not count. Only a player's fit counts; a farm quest sums every known player. [ASSUMPTION] An old save already medium or large with every space fitted has no never-had space: the step text says so, and the way is to clear one space (paid; the free refit is L4's reward, so it is not held yet) and fit it into another area, which is new for that area. Tested.
- **Lab-gate check (review item 4):** the `lab_gates` row for level 20 ("Medium lab") in `data/skills.json` has no `quest` key; only `first_contract` does. So L4 is not circular, and the lab's provisional XP is not involved. No offering `update_quests` was added to `give_lab_xp` (quest rewards call it, so it would re-enter); the three steps make it unnecessary.
- **P1 is gated on lab level 5** [PLACEHOLDER], so a new player is not asked to mine five fissures before the lab has any level; an old save whose `mine_fissure` count is already past 5 does not complete it at once (the count runs from the offer). A guest bringing a done P1 (or 4 of 5) keeps it and gets no second discount (the discount is paid when the quest is paid, not when it is taken in). Tested through the real `FarmCommands` path for the guest's mining: the guest, not the host, gets the Field Ops XP and the discount.
- **L4 pays 500 lab XP** (the design's figure) and the farm's `free_lab_refit` one-use reward, held by the farm. No credits, no quest points (a lab quest).
- **P1 counts the player's own `mine_fissure` counter, from the offer.** A fissure mined before Bram asks, or by a friend, does not count. The ore goes to the shared wallet as always. P1 pays Field Ops XP 100 [PLACEHOLDER], 1 quest point and the player's own `bram_discount_10`.
- **P2's giver is Vance** [ASSUMPTION]. The design does not name one; Vance is the inspector who follows OIRM rules exactly, and the skill is Uncertainty. P2 is the player's own, gated on Uncertainty level 5.
- **P2's step is the `calibrate_on_time` counter, a little stricter than the design's "cal_log rows by you, on_time true".** The counter is the one that pays Uncertainty XP: the calibration must also be traceable, not too soon (half the interval at least), and not by a robot. A late one just does not add; nothing resets. Five count from the offer.
- **P2 pays an XP certificate of 100 XP** [PLACEHOLDER] and the keepsake `pocket_watch` (the data entry already existed). No quest points, as the design has it.
- **Words are placeholders** [PLACEHOLDER]: Bram's offer and done lines for L4 and P1, Vance's offer and done lines for P2.
- **No save or protocol change.** `SaveGame.VERSION` stays 1 and `CoopSession.PROTOCOL` stays 16; no new farm field.
- **Tests added** (`tests/test_quests_l4_p1_p2.gd`): the three quests' data and the wrong holder of a one-use reward refused; each quest offered when its gate holds and not before; L4's steps through a real grow, move-in and fit, paid once with the refit held by the farm; a grow bought before the offer; an already medium lab with every space fitted; old counters past 5 not completing P1 or P2 at once; a guest bringing a done or 4-of-5 P1 getting no second discount; P1's own fissures only, paid once with the discount held by the player alone, and each player's own P1 through a co-op guest; P2's on-time calibrations (a late one and a friend's do not add), the certificate and the watch paid once; and a guest running none of them.

### Questions for Ryan

- Is Vance right as P2's giver?
- Is the grow step (a grow under way counts) fine, is P1's lab level 5 gate right, and is the stricter on-time count (traceable, not too soon) fine?
- Are the numbers right: Field Ops 100 XP for P1, a 100 XP certificate for P2, 500 lab XP for L4?
- Should a real favor system come later, and what should P1's first favor be?
