# First playtest

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
