# Design decisions

Short log of calls that shape code and data. Newest first.

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
- OPEN: Static Mop and Prism Ankles (fictional, from the original JSON) are tagged `alien` for now. Keep, cut, or fold into the art-bible set?

## 2026-11-21: Instrument drift has two sources

- Every instrument drifts with in-game time (`daily_drift_rate`, per day, from `GameClock`).
- Instruments that wear with use also drift per usage unit (`usage_drift_rate`). Rover steering: 0.03 deg per metre driven (placeholder, tune by feel).
- Both push the same direction. Zeroing resets to 0, logs as-found, and re-rolls the direction.
- Status: |error| / MPE <= `guardband.green` ratio (0.80) is in tolerance; <= 1.0 is guard band; > 1.0 is out of spec.
- Implemented once in `scripts/metrology/drift_model.gd` (`DriftModel`) so the rover, hygrometers, and the relay dish share it.
