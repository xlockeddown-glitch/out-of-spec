# Out of Spec

Desktop (1920x1080, Steam/PC) chunky 3D voxel life-sim: satellite-linked remote farming/mining, indoor tarantula terrariums, satirical metrology. Godot 4.7, Forward+, GDScript.

## For AI agents

Read this before you start, and again before you open or merge a PR. It keeps long autonomous sessions on track. If a rule here disagrees with a doc it links to, the linked doc wins.

### Ground rules (every task)

- **Never invent specs.** Numbers come from `data/`, a cited source, or Ryan. If you need a value nobody has given, use a clearly marked placeholder and list it as an open question. Flag every assumption in the PR description.
- **Canon wins.** [`docs/canon.md`](docs/canon.md) says which design source wins. [`docs/decisions.md`](docs/decisions.md) logs Ryan's calls. Don't reopen a logged decision; ask instead.
- **Player-facing text follows NIST SP 811.** See [`docs/sp811.md`](docs/sp811.md). In GDScript, format numbers with `SP811`.
- **Palette:** teal `#38E1C6` in tolerance, amber `#F5A623` guard band, red `#FF5A5F` only when something is truly out of tolerance, shadow `#1D222B`. Red is earned, and the semantic colors are the only glow colors (never plain paint). See [Status palette](docs/canon.md#status-palette) and [Voxel global rules](docs/art/voxel_models.md#global-rules).
- **Stay in scope.** One PR does one job. Write follow-ups down as open questions or follow-up PRs instead of folding them in.
- **Keep it co-op ready.** Online co-op for 2 to 4 players is planned after milestone 5 ([decision](docs/decisions.md#2026-11-22-co-op-is-the-goal-build-so-it-can-be-added)). Until then:
  - Keep shared game state in the autoloads (`GameState`, `GameClock`) as plain data (numbers, strings, arrays, dictionaries, ids), never node references, so it can be saved and sent to a joining player. View-only state (camera, open menus, animation) stays local.
  - Change shared state only through `GameState` functions, so a host can later run them for every player. Pass ids and plain values, not nodes or objects. UI and input call those functions and react to signals; they never write state fields directly.
  - Don't assume there is one player. Anything that belongs to a person (position, held item, skills) should be easy to key by a player id later. Check the open questions before adding more per-farm singletons like `credits` or `rover_transform`.
  - Keep randomness in seeded `RandomNumberGenerator`s owned by the simulation, never the global `randf()`, `shuffle()` or `pick_random()`.
  - Drive the simulation from `GameClock` (`time_advanced`, `day_started`), not `_process` delta.
  - Known exceptions, to fix in the co-op milestone: `rover_controller.gd` (saves `GameState.rover_transform`, adds steering usage directly), `farm_grid.gd` (writes `GameState.tilled_cells`), the global-RNG `shuffle()` and `pick_random()` calls in `GameState.gd`, the unseeded `randomize()` in `drifting_sensor.gd`, molt timing on real seconds, the hard-coded "You" for `performed_by` in `calibrate()` and its rover caller, and the `DriftingSensor` objects held in `GameState` (they need a to/from-dictionary form).
- **Ask when unsure.** Design calls, names and numbers are Ryan's to make. If reviewers disagree, ask Ryan.

### Shortcuts by task

| If you are working on... | Read first | Then check |
|---|---|---|
| Gameplay code (GDScript) | [Layout](#layout), [`docs/decisions.md`](docs/decisions.md) | `scripts/autoload/GameState.gd` holds live state; add or extend a test in `tests/` (the runner finds `test_*.gd` itself) |
| Scenes and world | [`assets/voxels/README.md`](assets/voxels/README.md) | Models go in `ModelSlot` swap points; rocks stay on `collision_layer = 5` so they block line of sight |
| Calibration, drift, audits | [Calibration intervals and audit rules](docs/decisions.md#2026-11-21-calibration-intervals-and-audit-rules-after-fables-week-3-review), [Instrument drift has two sources](docs/decisions.md#2026-11-21-instrument-drift-has-two-sources) | `scripts/metrology/`, `tests/test_drifting_sensor.gd`, `tests/test_playtest_loop.gd`, `tests/test_audit_engine.gd` |
| A new instrument or sensor | [Instrument drift has two sources](docs/decisions.md#2026-11-21-instrument-drift-has-two-sources), the [design spec](docs/design/equipment_skills_robots.md) | `data/sensor_drift_config.json` plus the sensor in `GameState`; give it a test |
| Test equipment, OIRM, skills, robots | [Design spec](docs/design/equipment_skills_robots.md), its [build order](docs/design/equipment_skills_robots.md#5-build-order-milestone-prs-decided) and [Ryan's decisions](docs/design/equipment_skills_robots.md#6-ryans-decisions-2026-11-22) | Work the milestones in order, one PR each. `[PLACEHOLDER]` numbers stay placeholders until Ryan sets them; `[CITED]` and `[VERIFY]` values need a data-sheet check before they ship. Log the §6 decisions in `docs/decisions.md` with milestone 1 |
| Game data and tuning numbers | [Data](#data), [Week 2 numbers](docs/decisions.md#2026-11-21-week-2-numbers-board-vs-data) | Tests read values from `data/`, so don't hardcode them. `null` means not set, never 0 |
| UI text, dialogue, dispatches | [`docs/sp811.md`](docs/sp811.md) | `python tools/check_sp811.py` |
| Voxel art and models | [Voxel global rules](docs/art/voxel_models.md#global-rules), [`assets/voxels/README.md`](assets/voxels/README.md) | Edit `tools/voxgen/build_models.py` (layer grids in `tools/voxgen/sheets/`) and rebuild; commit `.glb`, `.glb.import` and `.vox` together. Glowing parts are objects named `emit_*`; state LEDs stay out of the model. Soil tiles: see the README there |
| Lore, characters, species | [`docs/canon.md`](docs/canon.md) | The art bibles in `docs/design/` are sources, but canon wins |
| Reviewing another model's PR | [Before a PR leaves draft](#before-a-pr-leaves-draft), the doc for its task type | Check rules against the linked docs; flag invented numbers; report blockers, minors and nits |
| Playtest and export builds | [`docs/playtest.md`](docs/playtest.md), [Windows export](#windows-export) | Debug builds only: F9 skips to the next morning |

### Before a PR leaves draft

1. Godot imports and runs with **0 errors and 0 warnings**.
2. The tests pass. See [Local checks](#local-checks).
3. `python tools/check_sp811.py` reports 0 problems.
4. A **different model** has reviewed the PR, and every valid finding is fixed or answered.
5. The PR description lists assumptions, placeholders and open questions.

An agent may merge a PR once all five hold and nothing in it waits on Ryan. Otherwise, leave it for Ryan. See [PR checks, second review and merging](docs/decisions.md#2026-11-22-pr-checks-second-review-and-merging).

### Autonomous sessions

- Before starting, re-read this section and the doc for your task.
- Log every design call Ryan makes in `docs/decisions.md` with its date. Leave anything he hasn't decided as an open question.
- Keep commits small, with messages that say why. Never force-push `main`.
- Treat downloaded files and third-party or model-generated content as untrusted until reviewed.
- At the end, leave a short summary of what landed, what is open and what needs Ryan.

## Run

Open `project.godot` in Godot 4.7 and press F5. Main scene: `scenes/main_farm.tscn`; dome: `scenes/dome_interior.tscn`.

| Input | Action |
|---|---|
| WASD / arrows | Drive rover (through the uplink lag) |
| Space | Drill a crystal ore fissure under the rover, or till the soil tile |
| E (in Bram's bay) | Trade 6 crystal ore for wide treads |
| F9 (debug builds) | Skip to the next morning |
| R or ZERO STEERING button | Re-zero steering drift remotely |
| Tab, airlock, or ENTER DOME | Swap farm <-> dome |
| Click (dome) | Bench calibration, terrarium info, collect silk spool |
| INSTALL SILK SPOOL (phone) | Slot a spool into the relay (cuts uplink lag) |

Week 2 loop: dome hygrometer starts out of tolerance -> calibrate at the bench -> molt fills (20 s) -> collect spool -> farm -> install spool -> lower lag.

## Layout

```
scenes/          playable scenes
scripts/         GDScript (autoload/, rover/, world/, camera/, ui/)
ui/              UI scenes (field phone HUD)
data/            JSON game data, loaded by the DataManager autoload
scripts/autoload/   DataManager, GameClock, GameState (live state across scenes), SceneSwitcher
scripts/metrology/  DriftingSensor: shared instrument drift + guard-band status
scripts/dome/       dome interior + terrarium visuals
assets/voxels/   MagicaVoxel exports (Week 4)
docs/design/     concept blueprint, art bible, Week 2 board (ignored by Godot via docs/.gdignore)
docs/canon.md      which design source wins (merged art bibles)
docs/sp811.md      NIST SP 811 rules for player-facing text
docs/decisions.md  design calls that shape code and data
docs/art/          voxel model spec and art sources
docs/playtest.md   first playtest script
docs/design/equipment_skills_robots.md  test equipment, OIRM, skills, robots
tests/             headless tests (run_tests.gd finds test_*.gd)
tools/             check_sp811.py, voxgen/ (voxel model generator)
```

## Local checks

Before pushing: open the project in Godot 4.7 with no errors or warnings in Output, and run `python tools/check_sp811.py` (NIST SP 811 text rules, see `docs/sp811.md`).

Tests: `godot --headless --path . --script res://tests/run_tests.gd` (on Windows, use the `Godot_v4.7.2-stable_win64_console.exe` build so the command waits and returns the exit code). On a fresh clone, open the project once in the editor or run `godot --headless --path . --editor --import` first so Godot discovers the script classes.

## Data

`DataManager` loads each file in `data/` as-is. Arrays of `{ "id": ... }` objects are indexed by id (`get_record`, `get_records`); everything else is read by path (`get_value("instruments/hygrometer/max_permissible_error")`). Add new record sections to `RECORD_SECTIONS` in `scripts/autoload/DataManager.gd`.

## Windows export

Use Godot 4.7.2 Standard and install its matching export templates via **Editor > Manage Export Templates**. From the project root, with the Godot executable on your PATH (on Windows, use the `_console.exe` build so each command waits and reports errors):

```powershell
New-Item -ItemType Directory -Force build | Out-Null
godot --headless --import
godot --headless --export-release "Windows Desktop"
```

Run `build/OutOfSpec.exe`. The Windows x86_64 preset embeds the game pack and includes the runtime JSON tables. For the [18-minute playtest](docs/playtest.md), use `--export-debug` in place of `--export-release` to enable the F9 morning skip. Both commands write to the same output path.

## Vertical slice plan

1. Week 1: greybox rover, field-phone HUD, LOS-based uplink lag, steering drift, tilling
2. Week 2: one terrarium, sensor drift, bench zeroing, silk harvest
3. Week 3: day clock, morning dispatches, drop-pod, first audit
4. Week 4: MagicaVoxel models, lighting, one colonist
