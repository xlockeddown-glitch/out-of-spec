# Playtest

Two parts: a solo new-player playtest report (24 Nov 2026, `origin/main` at 85c0932, Godot 4.7.2, 1920 × 1080), then the first-playtest checklist.

## Report: solo, new player

**How it was played.** A script pressed real keys and clicked real buttons in the running game; nothing was called directly except the skips below. Screenshots are named `play_NN_*.png` (not in the repo; paths are in the hand-off).

Played: title → NEW FARM → drive → till → plant two crops → dome → bench calibration → day 2 → hill and digging → ore survey (V) → ore pocket → reference block and block check (Q) → tunnels → lights (L) → Sentinel approach four times, catch cup twice → Sentinel in its dome tank → job board → accept a job → Bram, Lin, robots panel (T) → close window → CONTINUE (six times).

**Skips (state changes, not play):** F9 to reach day 2; `sentinel_out` forced on four times (it is a 10 % morning roll); credibility raised to Trusted to see the job board; peeked at where the ore pocket and reference block were buried.

## Issues, ranked

| # | Kind | Issue | Evidence | Smallest fix |
|---|------|-------|----------|--------------|
| 1 | balance | **Solo can't end the day.** A day is 12 real minutes and only F9 (debug builds) skips it. Reed takes 3 days, the first audit is day 5, Trusted needs two clean audits (day 10): about 2 hours of waiting before the job board opens. | `CoopBeds.go_to_bed` returns "There is no one to wait for." unless hosting with company; GO TO BED is hidden solo. | Let a solo player use the bed (the all-in-bed rule with one player). |
| 2 | confusing | **Sentinel rules are told only after it bolts**, and one mistake ends the sighting. Lights low, under 3.5 m/s, stop 1.8 m to 4.0 m away, with 450 ms lag and no speed readout. A script that knew the rules bolted it 3 times in 4 approaches (lights once, too fast twice). | `play_33`, `play_51`; Sentinel block in `GameState.gd` (sees 8 m). | One line when it is first sighted: "Lights low (L), creep, stop short." Show speed on the phone in the tunnels. |
| 3 | confusing | **Hidden keys.** V, Q, G/H, K, F7, T, L, C, [ ] and E (tunnel mouth, cup) are missing from the README table; V, Q, G/H, T have no in-game hint until you stumble on them. L is lights in the tunnels and Lin's stall on the farm. | README key table; logs in `play_21`, `play_44`, `play_59`. | Add the keys to the README; one KEYS line on the title screen or a help key. |
| 4 | bug (look) | **Phone overflows the screen once Trusted.** The credibility, contract and job lines push the panel past the top and bottom at 1080 high; the log is cut to 3 lines. | `play_53` against `play_37` (same place, before Trusted). | Shrink the log or the job list when the panel is taller than the viewport. No restyle needed. |
| 5 | confusing | **Job list shows 2 of 3 offers.** The third sits below a small scroll area with a thin bar; a disabled offer takes one of the two rows. | `play_56`, `play_53`. | Sort offers you can accept first; raise `JOBS_MAX_HEIGHT` if issue 4 leaves room. **FIXED (fix/playtest-ui): offers you can accept sort first; job list holds about 3 rows.** |
| 6 | confusing | **No pause, no menu, no "saved" cue.** Esc does nothing on the farm. The game saves each morning and on window close only; a crash loses up to a day. Nothing tells the player either fact. | `play_07`; continue worked after every close. | Esc opens a small panel: RESUME, SAVE AND QUIT. Log "Saved." each morning. **FIXED (fix/playtest-ui): Esc opens PAUSED with RESUME and SAVE AND QUIT; "Saved." is logged each morning.** |
| 7 | text | **Humidity error is printed as "%".** "+5.25 %", "MPE ±5.00 %", "U ±0.823 %" are differences in percent relative humidity; as written they read as 5 % of the reading. The config already says `percentage_points_rh`. `tools/check_sp811.py` reports 0 problems, so the checker misses it. | `play_16`, `play_62`. | Print errors as "percentage points" (or "% RH" throughout). |
| 8 | text | **"CAL OVERDUE (due day 0)"** on the dome and cup, "OVERDUE since day 1" on the bench. Day 0 never exists for the player. | `play_12`, `play_35`; `cal_bench_ui.gd` lines 314, 496. | Use the bench wording everywhere. |
| 9 | confusing | **Cup failure doesn't point at the hygrometer.** With the as-delivered error the line is "The cup was too dry." while the panel read 80 %. The red "OUT OF TOLERANCE · CAL OVERDUE" line is there but easy to miss. | `play_35`, `play_36`. | When the reading was in band and the true value was not, add "The hygrometer read 80 %. Was it right?" |
| 10 | confusing | **Digging is silent.** A dig that finds nothing posts no line; a refusal says "This rock can't be dug." without saying where digging works. | `play_23`, `play_37`. | Log "Dug. Nothing here." and "Dig on the hills outside." **FIXED (fix/playtest-ui): "Dug. H fills it again." on a dig; the rock refusal adds "Dig on the hills outside."** |
| 11 | balance | **Steering leaves MPE after about 130 m** (0.03° per metre): one round trip to the hill. The red OUT OF TOLERANCE is on screen most of the time and R clears it free, so it becomes noise. | `play_44` (+5.70°), `play_53`. | Halve the drift rate, or make R cost a few seconds. |
| 12 | look | **Robots panel overlaps the phone**; phone text shows at its right edge. | `play_60`. | Centre the panel in the area left of the phone. **FIXED (fix/playtest-ui): the panel is centered in the area left of the phone.** |
| 13 | look | Lights "on" and "low" look nearly the same and the phone doesn't show which is set; the state persists in the save. | `play_31`, `play_32`. | Add "LIGHTS: LOW" to the tunnel block on the phone. **FIXED (fix/playtest-ui): phone shows LIGHTS: ON or LOW in the tunnels.** |
| 14 | confusing | After midnight the phone still says DAY 2 (days run 06:00 to 06:00). "MOLTED: optical silk spool ready" shows with SILK SPOOLS 0 and no word on how to collect it. | `play_55`. | Add "click the tank" to the molt line. |

No softlock found: Lin fronts seed at 0 CR, H refills a dig, the tunnels always have an exit, a bolted Sentinel comes back.

## Balance and economics (from code and data)

**Catch cup.** Catch if |reading − sensor error − 80| ≤ 5.

| Hygrometer | Error | Player sets the reading to 80 % | Result |
|---|---|---|---|
| As delivered | +5.6 (MPE × 1.12) | true value 74.4 % | always a miss (by 0.6) |
| Calibrated | about ±0.2 | true value about 80 % | always a catch; any reading 76 % to 84 % works |

Played both: miss at 80 % uncalibrated (`play_36`), catch at 80 % after calibration (`play_53`). This is the game's best lesson; it needs issue 9 to land.

**Sentinel sighting.** Chance each morning is 10 % × (1 + days unseen): 10 %, 20 %, 30 %, 40 %. Seen by day 4 in 70 % of games, by day 5 in 85 %. Each day is 12 minutes solo (issue 1).

**Money.** Start 500 CR. Seed costs 25 % of the sale price. Net per cell per day: Biscuit Reed (24 − 6) / 3 = 6 CR; Lensberry (104 − 26) / 8 = 9.75 CR. The plot has 144 cells.

- Days 1 to 3: income zero. Nothing is due either; the first cost is the day-5 audit, and the first failed audit is waived.
- A full plot of reed in spec nets about 864 CR a day. Out-of-spec crops lose 15 % to 40 %.
- Fines run 50 CR to 350 CR every 5 days. Trusted jobs pay 100 CR to 150 CR. The OIRM fee is 150 CR.
- So a day's income covers costs many times over once the plot is planted; fines and job pay barely matter next to crops. The real limits are crystal ore (6 pockets × 2 = 12, plus fissures; lab growth needs 4 then 8, Trellis 5, treads 6) and credibility.
- Smallest change if fines should bite: scale them with crop income, or have a failed audit hold Lin's payment.

**Frame rate.** 60 fps (vsync cap) on the farm, in the dome and in the tunnels; brief dips to 28 to 56 on digs, panel opens and scene swaps. Not measured uncapped.

## What worked

- Title → new farm → continue. Save on close restored position, dug cells and the accepted job every time.
- The tilling hint: "Space again plants Biscuit Reed (6 CR seed); C changes the seed…". More hints like this one.
- The bench: as-found and as-left, TUR, the chain to OIRM, the interval cut from 5 days to 3 after a failed as-found. The customer job is added to the INSTRUMENT list (code read; not played).
- Ore survey beam with a stated bearing and uncertainty; the block check "Error (+5.70 ± 0.06)°".
- Tunnels: the look, LOS and lag feedback, "TUNNEL MOUTH: press E".
- The Sentinel in its tank with its own humidity band (`play_55`).

## Not tested

Solo pacing over many real days; the day-5 audit and fines; harvest and sale to Lin; out-of-spec crops; completing the customer job; collecting and installing a silk spool; plan board purchases; building a robot; wide treads; flares; fissures; co-op; walking characters; an export build; uncapped frame rate; other resolutions.

## First-playtest checklist

Allow about 18 min. Use a fresh editor run or a **Windows debug export** so F9 can advance the clock. Keep the game window focused. Mark one box per step.

**Timing:** a game day lasts 12 real minutes. Finish steps 1 to 4 before the phone reads **DAY 2**, or the day-1 calibration in step 4 won't come due before the day-5 audit.

1. **Drive the rover · 2 min** — Press **F5** in the editor or double-click the debug executable. Find the day and uplink lag on the field phone. Hold **W** to drive forward, **S** to reverse, and steer with **A/D** while moving (the arrow keys also work). Expect day 1, a moving rover, and a small delay even under clear sky. ☐ Pass ☐ Fail

2. **Lose the uplink · 2 min** — Use **W/A/S/D** to circle a large boulder until it sits between the rover and the relay mast. Stop when the phone reads **LOS BLOCKED**. Watch lag rise toward 450 ms, then drive back into the open. Expect **LOS CLEAR** and a return toward 50 ms. Remember the boulder for the silk test. ☐ Pass ☐ Fail

3. **Till and drill · 2 min** — Drive onto a fresh brown soil tile and tap **Space** once. Expect a darker tile and a “Tilled cell” entry on the phone. Drive onto a glowing cyan crystal fissure and tap **Space** again. Expect the crystals to disappear and the ore counter to rise by one. ☐ Pass ☐ Fail

4. **Calibrate on day 1 · 2 min** — Press **Tab** to enter the dome. Left-click the bench, select **Terrarium Hygrometer**, then click **ZERO / CALIBRATE**. Expect a failed *as-found* reading, an in-band *as-left* reading, and a shortened interval with day 4 as the due day. Press **Esc** to close the bench. Leave that calibration on record for the audit. ☐ Pass ☐ Fail

5. **Watch the molt and collect silk · 1 min** — Left-click the terrarium to identify the Curlyhair. Watch the molt bar for about 20 s. Once the molt finishes, left-click the spool beside the enclosure. Expect one spool in inventory and the next molt cycle to start. ☐ Pass ☐ Fail

6. **Install the spool · 2 min** — Press **Tab** to return to the farm. On the phone, left-click **INSTALL SILK SPOOL**. Expect the spool count to drop to zero and **RELAY: OPTICAL SILK** on the phone. (The mast’s fiber lights up too, but the mast is far off-screen to the northwest.) Drive behind the same boulder with **W/A/S/D**. With the link blocked, lag should now settle near 171 ms. ☐ Pass ☐ Fail

7. **Meet the auditors · 2 min** — On the farm, park beside the soil plot (the pod lands just south of it) and note your credits. Tap **F9** once per morning until the phone first reads **DAY 5**. Stop there to watch the drop-pod land with AUD-1T. The day-1 hygrometer calibration is overdue. Expect the phone log to show the manager’s intervention and Vance’s one-time warning, with the same credit balance afterward. After a lot of driving the manager may also name the steering encoder; that is expected. ☐ Pass ☐ Fail

8. **Trade at Bram’s bay · 5 min** — Drive with **W/A/S/D** and tap **Space** on fresh cyan fissures until the phone shows **ORE 6**. The fissure from step 3 regrew the following morning. Drive under the scrapyard bay roof until Bram’s offer appears, then press **E** once. Expect **ORE 0**, **WIDE TREADS FITTED**, and Bram’s message that steering drift per meter is down 50 %. ☐ Pass ☐ Fail

## Two-PC zones checklist

Needs two PCs on one network, a farm with the Lava Tubes unlocked, and the rover at the farm's tunnel mouth. The host is **PC A** and the guest is **PC B**. Use a debug export so F9 can move the clock. Allow about 30 min. Mark one box per step.

Good to know first. The console in the dome puts a player in the rover that is already below, at the depth it is at. Finds are only at depths 1 to 3. Joining a farm always opens the farm scene, so PC B must travel back in after each join.

1. **Join the farm · 2 min** — On PC A press **Host** and read out the address. On PC B press **Join** and type it. Expect both players on the farm, and PC B to see PC A's farm. ☐ Pass ☐ Fail

2. **Two places at once · 5 min** — On PC A drive the rover into the tunnel mouth and stay in the hub. On PC B stay on the farm. Expect PC B to see the farm's rover gone from the pad. Now press **Tab** on PC B to go to the dome and use the console to travel to the Lava Tubes. Expect PC B to land in the hub, in the same rover as PC A. ☐ Pass ☐ Fail

3. **Different depths · 6 min** — On PC A take the rover down the hatch to depth 1. Expect the rover on PC B to follow it down. Take a find on PC A. Expect it to pay once on both screens. Now take the rover down to depth 2. On PC B try to take a find at depth 1 and to press the hatch for depth 3. Expect a plain refusal each time. ☐ Pass ☐ Fail

4. **Join late · 6 min** — Bring the rover up to depth 1 and take a find on PC A. On PC B quit to the title screen and join again. Expect PC B on the farm, and the same find already taken. Use the dome console to travel back in. Expect PC B at the depth the rover is at now. Expect no second pay for the find. ☐ Pass ☐ Fail

5. **A guest drops in the hub · 5 min** — Bring the rover to the hub on PC A and walk PC A back to the farm, then to the dome. Expect PC B alone below. Pull PC B's network cable. Expect PC A to see PC B go, and the rover to be gone from the tunnels. Expect no heat trip left on the phone. ☐ Pass ☐ Fail

6. **A guest drops from the dome · 3 min** — Rejoin on PC B. On PC B drive the farm's rover into the tunnel mouth, then press **Tab** to the dome. Quit PC B to the title screen. Expect the farm's rover back on the pad on PC A, not left below. ☐ Pass ☐ Fail

7. **The day does not wait · 3 min** — Rejoin on PC B and drive the rover into the tunnel mouth again. Go to bed on PC A. Quit PC B while it is below. Expect PC A's day to end at once, with the rover home when the new day starts. ☐ Pass ☐ Fail

8. **The host stops hosting · 3 min** — On PC B drive the rover in once more and stay in the hub. On PC A press **Stop hosting** at the title screen or in the menu. Expect the rover home on PC A's farm, and PC B to go to the title screen with a note that the host left. ☐ Pass ☐ Fail

9. **The wait for the host · 2 min** — On PC B use the dome console and, while it waits for an answer, press **Esc** and quit to the title screen. Expect the title screen, not a stuck dome. ☐ Pass ☐ Fail

10. **The 02:00 rescue · 8 min** — On PC B drive the rover into the tunnel mouth and stay in the hub. On PC A stay on the farm and wait for 00:00 (or set the clock). Expect PC B's phone to warn of the recall, and PC A's phone not to. At 02:00 expect PC B to be carried out to the farm, the rover home on PC A's pad, and 50 CR gone once. Put PC A to bed. Expect the day to end. ☐ Pass ☐ Fail

11. **Two below · 8 min** — Rejoin PC B. Take the rover in on PC A, bring PC B in by the dome console, and wait for 02:00. Expect both carried out, 100 CR gone in all, and the rover home only after both. Expect the day to end with both in bed. ☐ Pass ☐ Fail

12. **Out before 02:00 · 4 min** — Take PC B down again and, after the warning, walk PC B back to the farm. Expect no charge at 02:00. ☐ Pass ☐ Fail

Not covered: a real two-PC run (these steps have not been run on two PCs yet).
