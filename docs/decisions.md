# Design decisions

Short log of calls that shape code and data. Newest first.

## 2026-11-22: Art requests favor what the game will use

- **Ask Gemini Neon for things we know we will use** (Ryan): the test equipment, the companies and the characters, ahead of open-ended props. Logged in [`workflow.md` §4](workflow.md#4-ryans-art-uploads).

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
