# Out of Spec canon

The one place that says which design source wins. When a design doc in `docs/design/` disagrees with this file, this file wins. Change it only on Ryan's call, and log the call in `docs/decisions.md`.

Two art bibles exist and were merged per area on 2026-11-21:

- **World Expansion** (`docs/design/out_of_spec_world_expansion_art_bible.html`), called "WE" below
- **Worldbuilding** (`docs/design/out_of_spec_worldbuilding_art_bible.html`), called "WB" below

## Tarantulas

**Real species (early game):** Curlyhair (*Tliltocatl albopilosus*), Mexican Redknee (*Brachypelma hamorii*), Brazilian Black (*Grammostola pulchra*). Data: `data/tarantula_species.json`, `tier: "real"`.

**Alien morphs (unlocks): from WB.** Climate tolerances come from WB; ideal set points are not defined yet (`null`).

| Morph | Substrate | Tolerance | Output | Unlock |
|---|---|---|---|---|
| Cobalt Sentinel | Damp frontier moss & slate | ±3.0 °C / ±8% RH | Standard optical silk | Day 1 tractor lag cut (WB says 25%) |
| Terracotta Knee | Dry rust sand & shale | ±2.5 °C / ±6% RH | Anti-static dust filaments | Slower steering-encoder drift in dust |
| Crystal Weaver | Bioluminescent gravel | ±1.5 °C / ±4% RH | Resonant emerald fibers | Drills don't shatter mid-tier crystals |
| Orbital Silk-Spinner | Chilled dark basalt | ±0.8 °C / ±2% RH | Zero-expansion reticle silk | Multi-rover autopilot on flare days |
| Basalt Thermal-Vent | Heated volcanic slag | ±0.4 °C / ±1.5% RH | Mag-shielded thermal resin | Rovers work in the magnetic dead zone |

The Week 2 dome starter is Curlyhair. One optical silk spool cuts rover uplink lag 60% (`data/items.json`), and the spinning species' `lag_reduction_pct` stacks on top, multiplicatively: lag × (1 − 0.60) × (1 − species %). Curlyhair (5%): × 0.38, so 0.45 s occluded becomes 0.17 s. Cobalt Sentinel (25%): × 0.30.

## Mining biomes: from WE

1. **Terracotta Plateau**: open sky, clean LOS except behind surface boulders. Starter crops, shallow cyan quartz, forgiving steering drift.
2. **Basalt Thermal Tunnels**: rock arches break direct uplink, so relay beacons are needed at tunnel mouths. Magma vents cook unshielded sensors out of spec.
3. **Bioluminescent Depths**: total orbital blackout without optical relays. Crystals shatter unless the drill is calibrated within sub-percent tolerance.

## Colony cast: WB, plus AUD-1T from WE

| Neighbor | Role | Hook |
|---|---|---|
| Bram | Scrapyard rover mechanic | Treads, batteries, signal boosters for canyon scrap |
| Dr. Lin | Botanist & substrate dealer | Buys crops; sells mosses that unlock higher-tier morphs; spider-phobic at first |
| Inspector Vance | MegaCorp compliance auditor | Arrives by drop-pod every 5th morning; fines crooked stickers; softened by clean traceability logs |
| AUD-1T | Vance's compliance drone | Hovering scanner; does the petty sticker and tire-pressure checks |
| Kestrel | Hooded orbital trader | Solar-flare nights only; rare slings, gray-market reference standards |
| Chet | Rival calibration contractor | Neon vest, "eyeballs" everything, fake ISO certs; secretly hires you to fix his jobs |
| Old Orin | Retired canyon geologist | Teaches underground relay beacons for calibrated thermal probes |

Cut: Ollie (radio astronomer, WE). WE's "Vance the rival contractor" is replaced by Chet; Vance is now the auditor.

## Status palette

In band `#38E1C6`, guard band `#F5A623`, out of tolerance `#FF5A5F` (`DriftingSensor`).
