# Design decisions

Short log of calls that shape code and data. Newest first.

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
- Only the semantic colours glow; red only where something is out of tolerance. State LEDs stay game-driven.
- Glowing parts are separate MagicaVoxel objects named `emit_*`.
- Tractor hull `#C85A2A` (pending Ryan's confirmation).

