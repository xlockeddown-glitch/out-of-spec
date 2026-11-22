# Test equipment, player skills and utility robots (design proposal)

Status: **proposal, 2026-11-22.** Nothing here is canon until Ryan approves it and the call is logged in `docs/decisions.md`. This PR changes no code and no data table.

Ryan asked for three systems today:

1. In-game test equipment, based on seven real instruments.
2. Player skills that level up.
3. Late-game humanoid utility robots that the player builds, calibrates and programs.

Markers used throughout:

- **[ASSUMPTION]**: a design guess of mine that Ryan should confirm or replace.
- **[PLACEHOLDER]**: a number with no source. It exists only so the shape of a table is clear. Ryan supplies or tunes it.
- **[CITED]**: a value from the maker's published material, with the source in §7. Each one still needs checking against the maker's current official data sheet before it ships; several come from resellers or from marketing summaries, and §7 says which.

## 0. What the game has today

This is the base the proposal builds on (main at `79750b5`).

- `DriftingSensor` (`scripts/metrology/drifting_sensor.gd`): an error that grows with time (`daily_drift_rate`) and with use (`usage_drift_rate`) in one direction. `zero()` logs the as-found error, leaves a random as-left residual up to `as_left_residual`, and re-rolls the direction. The band is |error| / MPE: up to 0.8 in band, up to 1.0 guard band, above 1.0 out of tolerance.
- `GameState.calibrate(instrument_id, performed_by)`: zeroes the sensor, adjusts the interval (out of tolerance as found: shorter; on-time pass: longer; late pass: same), and appends a record to `cal_log`. `performed_by` is already `"You"` or `"Manager"`.
- Instruments in `data/sensor_drift_config.json`: `hygrometer` (relative humidity, MPE 5.0 %), `rover_steering_encoder` (degrees, MPE 4.0°, drifts per meter driven), `relay_dish_azimuth` (degrees, MPE 0.45°; in the table but not built by `GameState` yet).
- Audits: Inspector Vance and AUD-1T every 5th morning, one-time grace, then fines (`AuditEngine`).
- Calibration today needs **no reference standard.** Zeroing at the bench is assumed to be correct. That is the gap the equipment system fills.
- Canon hooks this proposal leans on (`docs/canon.md`): AUD-1T does "sticker and tire-pressure checks"; drills in the Bioluminescent Depths need "sub-percent" calibration; Kestrel sells "gray-market reference standards"; Old Orin teaches relay beacons for "calibrated thermal probes"; Bram sells signal boosters and treads.
- Unplaced voxel props that fit: `steering_encoder_jig`, `soil_moisture_probe`, `field_survey_tripod`.

## 1. Test equipment

### 1.1 The honest gap: none of the seven measures angle or humidity

Every drifting sensor in the game today is an angle (steering, dish) or a relative humidity (hygrometer). None of Ryan's seven instruments is an angle or humidity reference:

| Quantity in game today | What a real lab would use | On Ryan's list? |
|---|---|---|
| Relative humidity (hygrometer) | Humidity generator, or saturated salt solutions, with a chilled-mirror reference | No |
| Steering angle (encoder) | Angle fixture or rotary table (the `steering_encoder_jig` prop) | No |
| Dish azimuth | Angle fixture, or a survey sighting (the `field_survey_tripod` prop) | No |

So most of the new equipment needs **new drifting sensors** to be useful. §1.3 proposes them, each tied to something canon already mentions. Open question Q1 asks how the existing three should be referenced.

**[ASSUMPTION]** My proposal for the existing three: the steering encoder and dish azimuth are calibrated against the jig and the tripod, which become "Tier 0" standards with their own drift. The hygrometer gets a "salt-cell kit" Tier 0 standard. All three Tier 0 standards are additions to Ryan's list and need his OK.

### 1.2 Names (shortlist for Ryan)

The seven real products are trademarked names (Fluke, Mensor, Crystal / Ametek, CDI / Snap-on, and the model numbers). **The game should not ship them.** Ryan asked for name ideas from other models; this shortlist came from Claude Fable (2026-11-22). The doc uses the bold entry in each row as a working name until Ryan picks (Q2). No trademark search has been run on any of them; the collision notes are the model's own recall.

| Instrument | Mars-geography style | Maker-surname style | Plain industrial style |
|---|---|---|---|
| Handheld meter | **Arsia Fieldworks FM-3** | Vostrikov & Daly VD-24 | Habitat Electric HE-40 |
| Multi-product calibrator | Pavonis Sourceworks MPC-12 | **Halvorsen-Mbeki HM-3** | Unified Source Works USW-3 |
| Reference meter | Chryse Precision CP-85 | Okafor & Lindqvist Model 8R | **Longscale Instruments LS-8.5** |
| Rubidium standard | Noctis Timeworks NT-1 Relay-Lock (consumer brands use "Noctis") | **Qureshi & Hale Rb-87D** | Colony Time & Frequency CTF-10 |
| Torque standard | Jezero Torque Works JT-250 | Stenmark & Adeyemi SA-4 | **Turnwright TW-6** |
| Pressure controller | **Hellas Basin Controls HB-700** (Greek firms use "Hellas") | Ferreira & Holt FH-2 | Regulated Atmosphere Co. RAC-16 |
| Pressure gauge | Isidis Gauge Works IG-30 | **Wren & Dufour WD-1** | Colony Gauge & Valve CGV-7 |

Model numbers avoid well-known real ones (87, 5522, 5730, 3458, 8588, 6270, CPC6050). Names deliberately avoided: Olympus (a real instrument brand), Kasei, Elysium, Utopia, Arcadia, and anything close to "Bureau of Weights and Measures". My first draft used Elysium, so it is dropped.

Institute shortlist (§1.7):

| Full name | Acronym | Where it sits | Collision note |
|---|---|---|---|
| **Orbital Institute of Reference Measures** | **OIRM** | A free-flying lab in high Earth orbit, the hand-off point for standards bound for Mars | None known |
| Terran Primary Standards Office | TPSO | On Earth; certificates lag by months | None known |
| Relay Station Standards Directorate | RSSD | Aboard the Mars orbital relay; holds transfer standards traceable to Earth | ESA once used the abbreviation |

### 1.3 Proposed new drifting sensors

All rates, MPEs and intervals are **[PLACEHOLDER]** and would go in `sensor_drift_config.json` as `null` until Ryan sets them, the same way the alien morphs carry `null`.

| Proposed id | Quantity, unit | What it is in the world | Canon or existing hook |
|---|---|---|---|
| `rover_tire_pressure` | pressure, kPa | Tire gauge on the rover | AUD-1T checks tire pressure |
| `dome_pressure` | pressure, kPa | Dome atmosphere gauge | The dome and airlock exist |
| `terrarium_thermometer` | temperature, °C | Terrarium probe | Species have `ideal_temp_c` and `temp_tolerance_c` |
| `soil_moisture_probe` | soil moisture, fraction | Hand probe for crops | Crops have `soil_moisture_target` and `tolerance_band`; the prop exists |
| `drill_torque` | torque, N·m | Rover drill clutch | Depths drills need sub-percent calibration |
| `relay_timebase` | fractional frequency, dimensionless | Relay mast oscillator | The relay and uplink lag exist |
| `field_meter_dc` | DC voltage, V | The player's own handheld meter (it is itself a unit under test) | Traceability chain, §1.7 |

### 1.4 The seven instruments

**Decided by Ryan (2026-11-22):** the fictional instruments carry real-life accuracies. Each spec line below is what the real product's maker publishes, with the source in §7. Where no maker sheet could be read, the value stays **[PLACEHOLDER]**.

#### 1. Handheld digital multimeter (Fluke 87V class)

- **In-game name:** Arsia Fieldworks FM-3 Field Meter **[ASSUMPTION]**
- **Role:** First tool. Checks the electrical side: the soil moisture probe output, the terrarium thermometer readout chain, and rover battery voltage. It is not a primary reference for anything; it is the workhorse that later gets calibrated by the multi-product calibrator.
- **Tier / unlock:** Tier 1. Bram sells it for crystal ore and credits after the first audit (price **[PLACEHOLDER]**).
- **Spec [CITED]:** DC voltage ±(0.05 % of reading + 1 count), 18 °C to 28 °C, per the maker's product page and spec sheet. Resolution 10 µV on the lowest range.
- **TUR:** At 0.05 % it can check any reading chain whose MPE is about 0.2 % or wider at 4:1. As the unit under test, it needs a standard about 4 times better (about 0.012 %), which the multi-product calibrator gives with a wide margin.

#### 2. Multi-product calibrator (Fluke 5560A class)

- **In-game name:** Halvorsen-Mbeki HM-3 Multi-Source Calibrator **[ASSUMPTION]**
- **Role:** Sources voltage, current and resistance, and simulates temperature sensors, so it calibrates the field meter and the terrarium thermometer's readout. The maker's specification table confirms temperature simulation: 17 thermocouple types and 10 RTD types, best case 0.09 °C (thermocouple) and 0.002 °C (RTD) **[CITED]**.
- **Tier / unlock:** Tier 2. Kestrel sells it on a solar-flare night, gated on the Instrumentation skill (§2).
- **Spec [CITED]:** DC voltage 6 µV/V best case over 0 V to ±1020 V, 1 year, 95 % confidence, ±5 °C, from the "Best Performance" row of the maker's specification table. That row does not say which range gives the best case or what the floor term is; the full by-range table is in the maker's specification PDF, which could not be read as text (§7). Until it is, per-range values are **[PLACEHOLDER]**.
- **TUR:** The maker's own table says it supports a 6.5-digit class bench meter at 4:1. Against the field meter's 0.05 % (500 µV/V), the ratio is about 80:1.

#### 3. Reference multimeter (Fluke 8588A class)

- **In-game name:** Longscale LS-8.5 Reference Meter **[ASSUMPTION]**
- **Role:** Top of the electrical chain. It calibrates the multi-product calibrator; nothing in the field needs it directly. It exists so the player can stop sending the calibrator to OIRM.
- **Tier / unlock:** Tier 3. Kestrel, late game. Its own calibration goes to OIRM (§1.7).
- **Spec [CITED]:** 1-year DC voltage relative accuracy 2.7 µV/V at 95 % confidence and 3.5 µV/V at 99 % confidence; 24-hour stability 0.5 µV/V (95 %); 8.5 digits. "Relative" means the uncertainty of the lab standards it was calibrated against is added on top.
- **TUR:** Against the calibrator's 6 µV/V, the ratio is only about 2:1. That is realistic (top-level standards rarely get 4:1) and a good teaching moment: the game should let a ratio under 4:1 through only with a guard band (§1.5).

#### 4. Rubidium frequency standard (Fluke 910R class)

- **In-game name:** Qureshi & Hale Rb-87D Rubidium Reference **[ASSUMPTION]**
- **Role:** Calibrates the relay mast timebase. The real one is disciplined by GPS. In game it locks to the orbital satellite **while the relay has line of sight**, and in holdover (LOS blocked) it drifts at its aging rate. That ties a standard's drift to the existing LOS mechanic.
- **Tier / unlock:** Tier 3. Old Orin teaches it alongside relay beacons for the Basalt Thermal Tunnels.
- **Spec [CITED]:** Holdover aging under 2 × 10⁻¹² per day (typical) and under 5 × 10⁻¹¹ per month; under 3 × 10⁻¹⁰ over 0 °C to 50 °C. From a reseller's copy of the spec; the maker lists the product as discontinued.
- **TUR:** Huge against any plausible relay timebase MPE (a crystal oscillator is usually specified around 10⁻⁶ to 10⁻⁸). The game value of this instrument is that it never rides the drop pod as long as it keeps line of sight (§1.7).

#### 5. Torque standard (CDI 5000 class)

- **In-game name:** Turnwright TW-6 Torque Standard **[ASSUMPTION]**
- **Role:** Calibrates the drill clutch (`drill_torque`), Bram's torque wrench, and the robots' grip torque (§3).
- **Tier / unlock:** Tier 2. Bram, once Instrumentation reaches the gate level. Required before the first robot can be commissioned.
- **Spec [PLACEHOLDER]:** Sources disagree. Two retailer listings give ±0.25 % of indicated value from 10 % to 100 % of full scale; a manual excerpt gives ±0.5 % for a transducer. The range on one listing is very small (in·ozf) up to 2000 ft·lbf, about 2700 N·m. Ryan picks, or the maker's own sheet settles it (Q4).
- **TUR:** At 0.25 %, it calibrates anything with an MPE of 1 % or wider at 4:1. Canon says Depths drills need **sub-percent** tolerance. If the drill MPE is, say, 0.5 %, the ratio is 2:1, so drills in the Depths would push the player to a better torque standard or a guard band. Good tension if Ryan wants it.

#### 6. Pressure controller (Mensor CPC8000 class)

- **In-game name:** Hellas Basin Controls HB-700 Pressure Controller **[ASSUMPTION]**
- **Role:** Bench reference that generates and holds pressure. Calibrates the field pressure gauge (instrument 7), the dome pressure gauge, and the robots' water tank gauges. It is a bench unit, so it stays in the dome.
- **Tier / unlock:** Tier 3. Kestrel or Dr. Lin **[ASSUMPTION]**; needs the dome lab bench.
- **Spec [CITED]:** Accuracy down to 0.008 % of IntelliScale (the maker's name for its reading-based spec); precision 0.004 % of full scale; control stability 0.002 % of span; range −1 bar to 400 bar. Accuracy depends on which internal transducer is fitted.
- **TUR:** Against the field gauge's 0.1 % of reading, about 12:1.

#### 7. Digital pressure gauge (Crystal XP2i class)

- **In-game name:** Wren & Dufour WD-1 Reference Gauge **[ASSUMPTION]**
- **Role:** Portable reference. Calibrates the rover tire gauge in the field and spot-checks the dome. This is how the player answers AUD-1T's tire checks.
- **Tier / unlock:** Tier 1. Bram, early.
- **Spec [CITED]:** ±0.1 % of reading from 20 % to 110 % of range, and ±0.02 % of full scale below 20 % of range (one model's data sheet); the gauge must be zeroed for rated accuracy; the 1-year figure includes temperature and stability on the absolute-pressure model.
- **TUR:** Against a rover tire gauge, depends on the tire gauge MPE (**[PLACEHOLDER]**). At ±1 % it is 10:1; at ±0.25 % it falls to 2.5:1.

#### Summary

| # | In-game name [ASSUMPTION] | Class | Tier | From | Calibrates | Its own cal comes from |
|---|---|---|---|---|---|---|
| 1 | Arsia Fieldworks FM-3 Field Meter | Handheld meter | 1 | Bram | Soil probe, readout chains, batteries | #2 |
| 7 | Wren & Dufour WD-1 Reference Gauge | Pressure gauge | 1 | Bram | Tire, dome pressure | #6, or OIRM |
| 5 | Turnwright TW-6 Torque Standard | Torque | 2 | Bram | Drill, wrench, robot grip | OIRM |
| 2 | Halvorsen-Mbeki HM-3 Multi-Source Calibrator | Electrical source | 2 | Kestrel | #1, thermometer chain | #3, or OIRM |
| 6 | Hellas Basin Controls HB-700 Pressure Controller | Pressure | 3 | Kestrel or Dr. Lin | #7, dome gauge, robot tanks | OIRM |
| 3 | Longscale LS-8.5 Reference Meter | Reference meter | 3 | Kestrel | #2 | OIRM |
| 4 | Qureshi & Hale Rb-87D Rubidium Reference | Frequency | 3 | Old Orin | Relay timebase | Relay lock to OIRM time (LOS) |

### 1.5 TUR in the game

Today `as_found_in_tolerance` is just |as-found| ≤ MPE, with no uncertainty. Proposal:

- Every calibration names the **standard** used. The record gains `standard_id`, `standard_uncertainty` (expanded, in the instrument's unit) and `tur`.
- **TUR = MPE of the unit under test / expanded uncertainty of the calibration.** Both are half-widths, so this is the same as the span ratio. **[ASSUMPTION]**: the game treats a maker's accuracy spec as the expanded uncertainty (about 95 % confidence) unless the sheet says otherwise. That is a simplification real labs argue about; Q5.
- The expanded uncertainty of a calibration = the standard's spec, combined (root sum of squares) with the operator's own contribution, which the Uncertainty skill shrinks (§2). Robots add their own term (§3.4).
- **TUR ≥ 4:1:** the result stands as it does today.
- **1:1 ≤ TUR < 4:1:** the calibration is allowed, but the acceptance limit is guard-banded: as found counts as in tolerance only if |as-found| ≤ MPE − U. A reading between MPE − U and MPE is "indeterminate" and logged as such. Vance treats indeterminate as a pass the first time and asks for a better standard after that **[ASSUMPTION]**.
- **TUR < 1:1:** the bench refuses the calibration ("standard not good enough").
- Thresholds (4:1, 1:1) are **[PLACEHOLDER]**, though 4:1 is the common industry rule of thumb.

Terminology to keep straight on screen: the game's existing amber **guard band** (0.8 to 1.0 × MPE) is a warning band on the reading. The TUR guard band above is a different thing (it moves the acceptance limit). The bench UI should call the second one "acceptance limit" to avoid two meanings of one word **[ASSUMPTION]**.

### 1.6 The standards drift too

- Each owned standard is itself a `DriftingSensor` with its own interval, so the same code drives it. Its MPE is its spec.
- A standard can only be calibrated by a better one (TUR rules above), up the chain in the §1.4 summary, and at the top by the institute (§1.7).
- **Reverse traceability (recall):** if a standard is found out of tolerance at its own calibration, every calibration it did since its last good one is flagged `suspect` in the log. Vance fines suspect calibrations that were not redone before the audit (fine **[PLACEHOLDER]**). This is the main hook for robots too (§3.4).

### 1.7 The national metrology institute and traceability

Ryan asked for "an organization like NIST". Working name: **Orbital Institute of Reference Measures (OIRM)** (§1.2 has the alternatives). Real-world model: a national metrology institute realizes the SI units and calibrates other labs' reference standards, issuing certificates that state the value found and its uncertainty.

**In the fiction [ASSUMPTION]:** OIRM is a lab in Earth orbit that holds the colony's primary references. Inspector Vance works for the colony authority, not OIRM, but enforces OIRM traceability in audits. Vance's drop pod is the courier.

**What traceability means in game.** An instrument is *traceable* only if there is an unbroken chain of calibrations from it up to OIRM, where every link:

1. was done with a standard that was itself in date and in tolerance on that day;
2. has a stated expanded uncertainty and a TUR that passed §1.5;
3. is recorded in `cal_log` (the record already has `day` and `performed_by`; §4 adds `standard_id`, `standard_uncertainty`, `tur`).

The game can compute this by walking `standard_id` links in the log back to an OIRM certificate. A link breaks if the standard was overdue, out of tolerance, or later recalled (§1.6). The bench and the audit screen show the chain, for example: tire gauge ← WD-1 gauge ← HB-700 controller ← OIRM certificate.

**Sending a standard to OIRM.**

- Only top-of-chain standards go (the summary table's "own cal comes from" column says OIRM).
- The standard rides Vance's drop pod after an audit and returns on the next one: out of service for one audit cycle (5 d). Fee **[PLACEHOLDER]** credits.
- It comes back with an **OIRM certificate**: an item with the standard's id, as-found and as-left values, the expanded uncertainty and coverage factor, the date and a due date. The certificate uncertainty becomes the bottom of that standard's budget.
- While it is away, nothing can be calibrated against it. Owning a spare, or using a lower standard as a stopgap with a guard-banded acceptance limit, is the planning puzzle.

**Kestrel's gray-market standards (canon hook).** Kestrel's standards come with **no OIRM certificate**: they work on the bench, but anything calibrated with them is untraceable until the standard has been sent to OIRM once. Cheap now, expensive at audit. Chet's fake ISO certs fit the same rule: a forged certificate fails Vance's check **[ASSUMPTION]**.

**How it gates equipment tiers (levels [PLACEHOLDER]).**

| Tier | Needs |
|---|---|
| 0 (jig, tripod, salt cell) | Nothing; issued at start with an OIRM-traceable certificate from the colony's founding stock **[ASSUMPTION]** |
| 1 | Instrumentation 1; first clean audit |
| 2 | Instrumentation 3; an **OIRM account**, opened by sending any Tier 1 standard for its first OIRM calibration |
| 3 | Instrumentation 6; at least one Tier 2 standard with a current OIRM certificate; Vance's sign-off as a "traceable lab" after two clean audits in a row |

The rubidium standard is the exception at the top: while it is locked to the orbital relay, its traceability runs through the relay's link to OIRM's time scale, so it never rides the pod. If line of sight is lost for longer than **[PLACEHOLDER]** days, its certificate lapses until it relocks.

## 2. Player skills

All numbers in this section are **[PLACEHOLDER]**.

### 2.1 Skill list

Ryan named calibration speed, uncertainty reduction, equipment unlocks and robotics. Four core skills cover those; two optional ones cover the farm and dome actions so every part of the loop earns something.

| Skill id | Name | What it improves | Core? |
|---|---|---|---|
| `calibration` | Calibration | Bench speed and as-left residual | Core |
| `uncertainty` | Uncertainty | The operator's term in every calibration, so TUR rises | Core |
| `instrumentation` | Instrumentation | Which standards can be bought and used | Core |
| `robotics` | Robotics | Robot build, job slots and robot count | Core |
| `husbandry` | Husbandry | Molt and spool handling | Optional **[ASSUMPTION]** |
| `field_ops` | Field Ops | Driving, tilling, drilling | Optional **[ASSUMPTION]** |

### 2.2 XP sources, all tied to actions that already exist

| Action (existing call) | Skill | XP [PLACEHOLDER] |
|---|---|---|
| `GameState.calibrate()` by the player | calibration | 10 |
| …and as found was out of tolerance (a real find) | calibration | +5 |
| …on time (not overdue) | uncertainty | 5 |
| …with TUR ≥ 4:1 recorded (after §1.5 lands) | uncertainty | 5 |
| Clean audit (no violations) | uncertainty | 20 |
| Audit with fines | none | 0 (no XP for being fined) |
| Buy a standard | instrumentation | 15 |
| Calibrate one standard against another | instrumentation | 20 |
| `collect_spool()` | husbandry | 10 |
| `slot_spool_into_relay()` | husbandry | 5 |
| `mine_fissure()` | field_ops | 2 |
| Till a cell | field_ops | 1 |
| Build / commission a robot (§3) | robotics | 50 / 25 |
| A robot completes a job | robotics | 1 |
| Calibrate a robot sensor | robotics and calibration | 5 each |

Calibrations by `"Manager"` (the audit grace) give no XP **[ASSUMPTION]**. Same-day repeat calibrations of the same instrument give no XP, matching the existing rule that they don't count as interval evidence.

### 2.3 Level effects

| Skill | Per level [PLACEHOLDER] | Unlocks at level [PLACEHOLDER] |
|---|---|---|
| Calibration | Bench time −8 %; as-left residual −5 % (floor 50 % of base) | L3: calibrate two instruments in one bench visit |
| Uncertainty | Operator term −10 % (floor 30 % of base) | L2: TUR shown on the bench; L5: uncertainty budget view |
| Instrumentation | none directly | L1: Tier 1 standards; L3: Tier 2; L6: Tier 3 |
| Robotics | Robot sensor drift −4 % (floor 60 %) | L1: first robot blueprint; L2: second job slot; L4: CALIBRATE job; one extra robot every 2 levels |
| Husbandry | Molt time −3 % | L3: see molt progress from the farm |
| Field Ops | Usage drift on steering −3 % | L4: drill two fissures per visit |

Two effects need concepts the game doesn't have yet:

- **Bench time.** Calibration is instant today. "Calibration speed" needs a duration on `calibrate()` (Gemini's unmerged drift config had a calibration time field; `docs/decisions.md` lists it as a Week 3 candidate). Q6.
- **Operator term.** Needs §1.5.

### 2.4 Level curve

10 levels per skill. XP to reach level n = 50 × n × (n + 1) / 2 **[PLACEHOLDER]**, so L2 at 50 XP, L5 at 750 XP, L10 at 2750 XP.

## 3. Utility robots

### 3.1 Design (original)

**[ASSUMPTION]** on every visual detail; this is a starting point for a Neon concept sheet, not a spec.

- **Name:** "Trellis" utility frame; the player names each unit (default `TR-1`, `TR-2`…).
- **Silhouette:** a short, broad humanoid, about 1.4 m, built from Bram's canyon scrap. Not sleek: bolted plates, visible actuators at the knees and elbows, three-finger grippers. Deliberately unlike any commercial humanoid.
- **Head:** no face. A short mast with a stub antenna (it takes programs over the uplink, like the rover) and one optical silk "eye" fed by a spool.
- **Chest light:** one status lamp in the band palette, showing the worst band of its own sensors: teal `#38E1C6`, amber `#F5A623`, and red `#FF5A5F` only when a sensor is truly out of tolerance. Outline and shadow `#1D222B`.
- **Back:** a water tank with a gauge (for the watering job).
- Hull color: open (Q9). Voxel size 0.2 m, the character class in `docs/decisions.md`.

### 3.2 Build and commissioning

1. **Blueprint.** Robotics L1. Bram finds a scrap frame in the canyon.
2. **Parts** (costs **[PLACEHOLDER]**): frame (crystal ore and credits, Bram); actuator set; **one optical silk spool** for the eye harness. The spool competes with the relay, which is a deliberate trade-off **[ASSUMPTION]**.
3. **Assembly** in Bram's bay, one day **[PLACEHOLDER]**.
4. **Commissioning calibration.** A new robot's sensors start "never calibrated", which is already overdue under the 2026-11-21 audit rules. Before the robot takes any job, each sensor must pass a calibration with the right standard:
   - joint encoders: the steering encoder jig (angle);
   - grip torque: the torque standard (so the torque standard is required before the first robot);
   - tank pressure gauge: the field pressure gauge or the controller;
   - onboard soil probe: the field meter chain.
5. **Released for service:** a tag in the robot panel; the robot shows in the audit like any instrument.

### 3.3 Job programming

A robot holds an ordered list of **job cards**. The number of slots comes from Robotics level (1 at L1, **[PLACEHOLDER]**).

A card is: **WHEN** trigger **DO** job **AT** target.

| Field | Options |
|---|---|
| Trigger | At a clock time (06:00); every n d; when a condition holds |
| Conditions | Soil moisture below target minus band; spool ready; an instrument reaches the amber guard band; an instrument is due within n d |
| Job | WATER; COLLECT SPOOL; CALIBRATE (Robotics L4) |
| Target | Plot cells; the terrarium; an instrument id plus the standard to use |

Execution: each game tick, the robot checks its cards top to bottom and runs the first one whose trigger holds; one job at a time, no parallel work. If the uplink has no line of sight, the robot keeps running its last program but can't receive a new one **[ASSUMPTION]**, which reuses the LOS mechanic.

Safety interlock: if any of the robot's own sensors goes out of tolerance, it stops after its current job and posts to the phone ("TR-2: grip torque out of tolerance. Holding."). Overriding the interlock is possible and Vance fines it **[ASSUMPTION]**.

### 3.4 How robot drift feeds back into the loop

Each robot sensor is a `DriftingSensor` with usage drift per job action **[PLACEHOLDER]** rates. Effects:

| Sensor drifts… | …so in the world | Loop consequence |
|---|---|---|
| Joint encoder (angle) | Water lands offset; at out of tolerance, on the neighbor cell | Crop moisture leaves its band, so `out_of_spec_penalty_pct` applies at sale |
| Tank pressure gauge | Wrong dose per cell | Same, over- or under-watering |
| Grip torque | Spool handled too hard | Spool damage chance **[PLACEHOLDER]**, so less lag reduction |
| Onboard soil probe | Waters the wrong cells or skips dry ones | Same as encoder |
| Any, during a CALIBRATE job | The robot's own error adds to the calibration's uncertainty; its records say `performed_by: "TR-2"` | Lower TUR; and if the robot is later found out of tolerance, every calibration it did since its last good one is `suspect` (§1.6 recall) and Vance may fine them |

Rules:

- A robot never calibrates itself. Another robot (CALIBRATE card) or the player does it.
- Robot calibrations follow the same adaptive interval rules as every other instrument.
- So the more the player automates, the more instruments there are to keep in tolerance. The robots save time but grow the calibration loop instead of escaping it, which keeps the game about metrology.

### 3.5 Gates

| Feature | Skill gate [PLACEHOLDER] | Equipment gate |
|---|---|---|
| First robot | Robotics 1, Instrumentation 3 | Torque standard owned and in tolerance |
| WATER card | Robotics 1 | Field pressure gauge (for the tank) |
| COLLECT SPOOL card | Robotics 2 | Grip torque calibrated |
| CALIBRATE card | Robotics 4, Calibration 3 | The target's standard, with TUR ≥ 4:1 counting the robot's term |
| Each extra robot | +2 Robotics levels | none |

## 4. Proposed data shapes (not created in this PR)

New files would need entries in `DataManager.RECORD_SECTIONS` where they are arrays of records. `null` means "not set yet", as for the alien morphs.

`data/equipment.json`:

```json
[
  {
    "id": "field_meter",
    "display_name": "Arsia Fieldworks FM-3 Field Meter",
    "class": "handheld_multimeter",
    "tier": 1,
    "seller": "bram",
    "ore_cost": null,
    "credit_cost": null,
    "skill_gate": { "instrumentation": 1 },
    "calibrates": ["soil_moisture_probe", "terrarium_thermometer"],
    "spec": { "basis": "pct_of_reading_plus_counts", "value": null, "confidence": null },
    "own_cal_from": ["multi_source_calibrator", "oirm"],
    "_note": "Spec from the maker's sheet once Ryan approves; see docs/design/equipment_skills_robots.md."
  }
]
```

`data/skills.json`:

```json
{
  "level_curve": { "max_level": 10, "base_xp": null },
  "skills": [
    { "id": "calibration", "display_name": "Calibration",
      "effects": { "bench_time_pct_per_level": null, "as_left_residual_pct_per_level": null } }
  ],
  "xp_sources": [
    { "id": "calibrate_player", "skill": "calibration", "xp": null },
    { "id": "calibrate_found_oot", "skill": "calibration", "xp": null }
  ]
}
```

`data/robots.json`:

```json
{
  "frame": {
    "display_name": "Trellis",
    "sensors": ["robot_joint_encoder", "robot_grip_torque", "robot_tank_pressure", "robot_soil_probe"],
    "build_cost": { "ore": null, "credits": null, "optical_silk_spool": 1 },
    "assembly_days": null
  },
  "jobs": [
    { "id": "water", "skill_gate": { "robotics": 1 } },
    { "id": "collect_spool", "skill_gate": { "robotics": 2 } },
    { "id": "calibrate", "skill_gate": { "robotics": 4, "calibration": 3 } }
  ],
  "job_slots_by_level": null
}
```

New calibration record fields: `standard_id`, `standard_uncertainty`, `tur`, `acceptance_limit`, `result` (`"pass"`, `"fail"`, `"indeterminate"`), `suspect`.

Code impact for later PRs (not done here): `GameState.get_sensor()` is a `match` over two ids; it would become a dictionary of sensors so equipment and robots can register theirs. `INSTRUMENT_NAMES` would move into data. `AuditEngine.evaluate()` already takes a sensors dictionary.

## 5. Suggested order

1. TUR and standards on the existing three instruments (Tier 0 jig, tripod, salt cell), so the record shape is proven.
2. Tier 1 equipment and the two pressure sensors (tire, dome).
3. Skills: calibration, uncertainty, instrumentation.
4. Tier 2 and 3, OIRM calibration and certificates, recall.
5. Robots and the robotics skill.

## 6. Open questions for Ryan

1. **Angle and humidity references.** None of the seven covers the game's current sensors. OK to add Tier 0 standards (encoder jig, survey tripod, salt-cell kit), or should the existing three keep zeroing with no reference?
2. **Names.** Pick from the §1.2 shortlist (instruments and institute), or keep the bold working names. Finalists still need a trademark check before shipping.
3. **Game MPEs vs real accuracies.** Decided: instruments carry real accuracies. But the game's current MPEs (4.0°, 5.0 %) are far wider than real lab tolerances, so almost every TUR would be huge. Should the new sensors (§1.3) get realistic MPEs too, so TUR choices matter?
4. **Torque spec.** The sources disagree (±0.25 % of indicated value vs ±0.5 % for a transducer). Which do you want, or should I find the maker's own sheet?
5. **Spec as uncertainty.** OK to treat a maker's accuracy spec as the expanded uncertainty at about 95 % confidence? (The 8588A states both 95 % and 99 %; the gauge sheets don't state a confidence level.)
6. **Bench time.** Calibration is instant today. Should it take game time, so the Calibration skill has something to speed up?
7. **TUR thresholds.** 4:1 for a clean result and 1:1 as the hard floor, with indeterminate results in between?
8. **New sensors.** Which of the seven proposed sensors (§1.3) do you want? Each one adds audit load.
9. **Robot look.** Hull color, height, and whether the eye really costs a silk spool.
10. **Robots and audits.** Should Vance audit robot sensors like any instrument, and fine an overridden interlock?
11. **Optional skills.** Keep Husbandry and Field Ops, or only the four you named?
12. **OIRM.** OK with the institute in Earth orbit, standards riding Vance's drop pod for one audit cycle, Kestrel's standards arriving uncertified, and the tier gates in §1.7?

## 7. Sources for the [CITED] values

Read on 2026-11-22. All need checking against the maker's current official data sheet before any number ships.

- Handheld meter: Fluke 87V product page, specifications tab, <https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v>; detailed spec sheet hosted by Farnell, <https://www.farnell.com/datasheets/2830418.pdf>.
- Multi-product calibrator: Fluke 5560A product and comparison pages, <https://www.fluke.com/en-us/product/calibration-tools/multifunction-calibrators/55x0a>, <https://www.fluke.com/en-us/product/calibration-tools/multifunction-calibrators/5500x>. Values from the product page's specification table (the "Best Performance" heading, which states 95 % confidence, ±5 °C, 1 year; the DCV row; the Temperature row). The maker's specification PDF linked from that page, <https://media.fluke.com/421591d3-03b5-40c3-ad8c-b2d5016f30e9_original%20file.pdf>, downloaded as compressed data and could not be read as text, so per-range values are not cited yet.
- Reference multimeter: Fluke 8588A product page, <https://fluke.com/en-us/product/calibration-tools/electrical-calibration/bench-multimeters/8588a>.
- Rubidium standard: Fluke 910/910R page (discontinued), <https://www.fluke.com/en-us/product/calibration-tools/electrical-calibration/electrical-standards/910-910r>; numbers from a reseller copy, <https://www.transcat.com/fluke-910r-gps-controlled-rubidium-frequency-standard-used>.
- Torque standard: retailer listings and manual excerpts only (no maker sheet found; cditorque.com refused the connection on 2026-11-22), <https://www.protorquetools.com/cdi-supreme-suretest-torque-calibration-system-5000-2/?m=widget>, <https://zoro.com/cdi-cdi-suretest-calibration-monitor-5000-st/i/G2004941>, <https://manualmachine.com/snapon/5000st/1765604-user-manual>.
- Pressure controller: Mensor / WIKA CPC8000 data sheet CT 28.01, <https://www.mensor.com/media/Data-sheets/Calibration/Pressure-controllers/ds_ct2801_en_um.pdf>.
- Pressure gauge: Crystal XP2i data sheet (reseller copy), <https://www.transcat.com/media/pdf/XP2i.pdf>; maker's accuracy note, <https://www.globaltestsupply.com/content/crystal-pressure-understanding-accuracy-statements>.
