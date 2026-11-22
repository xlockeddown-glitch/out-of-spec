# Story source ideas

Every story, lore and world idea in the repo, gathered on 2026-11-22 as the shared brief for the story drafts in `drafts/`. It keeps three kinds of source apart:

- **Ryan's words.** The "Ryan said" and "Ryan chose" parts of `docs/decisions.md`, and the decisions credited to him in `docs/design/equipment_skills_robots.md` §6.
- **Canon Ryan adopted.** The art bibles and the concept blueprint in `docs/design/` were drafted by AI tools for Ryan. Where `docs/canon.md` keeps a piece of them, it is canon on Ryan's call; the rest is inspiration only.
- **Agent additions.** "Agent's notes", [ASSUMPTION] items and proposals. They are not Ryan's ideas and the story may drop them.

Sources: `docs/decisions.md` (main, plus the idea entries on the `feat/income` branch, PR 48), `docs/canon.md`, `docs/design/*.html`, `docs/design/equipment_skills_robots.md`.

## 1. Ryan's words

### The world and the work

- Online co-op: 2 to 4 players share one farm and dome and split the work (field, bench, comms). One player hosts; no dedicated servers. One shared farm wallet ("Vance fines the farm, OIRM bills the farm"). One shared rover to start; the farm buys more. The day ends only when every player is in bed. Skills are both personal (per player) and shared by the farm.
- A national-metrology-institute-like body ("an organization like NIST"). Ryan approved the name **OIRM** (Orbital Institute of Reference Measures).
- The OIRM master auditors are a **robot audit team** of SI-powered agents "from Claude, Gemini, SpaceXSI and ChatGPT". Ryan chose **fictional nods**: original names that wink at the real ones, not the real product names.
- One-time grace: the first audit that would fine you is a warning instead, and **your manager** recalibrates the violating instruments before Vance gets in.
- Tier 0 standards are issued at the start with OIRM certificates. Ryan named them the **Pavonis Indexworks PX-1** rotary table and the **Meridiani Dewpoint MD-2P** humidity generator. Fictional makers for all equipment; real accuracies where a maker sheet supports them, else [PLACEHOLDER].
- Utility robots: rust-orange scrap hull; the eye costs one optical silk spool. Vance audits robot sensors and fines an overridden safety interlock.

### Credibility, contracts and the long arc

- A lab that passes audits and keeps instruments from going overdue, "or at least from being used overdue", runs better and earns more. That builds **credibility**.
- Credibility leads to **contracts** that offer discounted high-end or even **intrinsic** calibration standards to use as primary standards.
- With those standards and new skills, the player can eventually harvest crops **off planet**, using remote-controlled AI rockets and robots.
- Roadmap: credibility first; rockets, off-planet harvest and the OIRM audit team later.
- The first contract: at the first threshold OIRM offers a lower-uncertainty standard at a discount for a run of on-time calibrations. The phone shows a named rating band.
- Income: crop sales first, then paid calibration jobs unlocked at TRUSTED.

### Lin

- **Lin buys crops.** Ryan picked Lin, the botanist and substrate dealer, as the crop buyer for the income milestone.
- Crops grow on soil held by auto-irrigation that trusts a drifting soil-moisture probe; a drifted probe means off-spec crops.

### The calibration robot helper

- A robot helper is taught calibrations and improves over time (levels, maybe tied to a skill), until it does harder calibrations and assists in the lab, freeing the player as they master calibrations.
- Different robot types do different jobs at first. As build and skill technology unlocks, more human-like robots arrive that automate a wider range of skills.

### The automation path

- Most things go manual first, then automation with a **human in the loop**, then automation run **remotely** from a control panel through "a system like Starlink or SI".

### The rogue lab

- A lab can **"go rogue"** and skip calibrations. That makes the game wonky: weird things happen, things go right when you press left, the wrong things happen.
- "It shouldn't just be miserable; it should be funny and goofy, with some misery."

### Specialization

- You don't need to calibrate every parameter to succeed. A single route (for example only pressure and torque, or only electrical) is harder than being a jack of all trades, but it works.
- You still keep your own site's instruments going, but worry much less about all the standards.
- "You have to make money in many ways, or be really good at what you do."

### The lab building

- The lab is upgradeable: small (one or a few sections), then medium (bigger areas or more separate areas), then large (one really big area or many separate areas, depending on how you specialize).

## 2. Canon Ryan adopted (`docs/canon.md`)

- **Pitch (blueprint):** "the lone certified metrology contractor on a half-baked corporate colony", farming outdoors through a handheld satellite phone and keeping tarantulas indoors whose silk keeps instruments in tolerance. Tone: Graveyard Keeper's dry corporate comedy meets Stardew Valley's daily rhythm. Target feel: "tactile, slightly absurd, deeply satisfying when every sensor hits green." MegaCorp obsesses over compliance stickers "even while the colony's power grid flickers". The phone sends "cheerful passive-aggressive notifications from orbital dispatch".
- **Two pillars:** the warm indoor dome (tarantula conservatory and calibration bench) and the hazardous outdoor frontier (farm, rover over a laggy orbital link, crystal mining).
- **Tarantulas:** real species early (Curlyhair, Mexican Redknee, Brazilian Black); five alien morphs later (Cobalt Sentinel, Terracotta Knee, Crystal Weaver, Orbital Silk-Spinner, Basalt Thermal-Vent), each with a tighter climate tolerance and a silk or resin that unlocks something outdoors.
- **Biomes, top to bottom:** Terracotta Plateau (open sky), Basalt Thermal Tunnels (arches break the uplink, magma vents cook sensors), Bioluminescent Depths (orbital blackout, crystals shatter unless the drill is within sub-percent tolerance).
- **Cast:**
  - **Bram:** scrapyard rover mechanic; percussive maintenance, no respect for torque specs; treads, batteries, signal boosters.
  - **Dr. Lin:** botanist and substrate dealer; buys crops; sells mosses that unlock higher morphs; spider-phobic at first, fascinated by the silk later.
  - **Inspector Vance:** MegaCorp compliance auditor; drop pod every 5th morning; fines crooked stickers; softened by clean traceability logs.
  - **AUD-1T:** Vance's hovering drone; petty sticker and tire-pressure checks, cheery chime.
  - **Kestrel:** hooded orbital trader; solar-flare nights only; rare slings and gray-market reference standards.
  - **Chet:** rival calibration contractor; neon vest; "eyeballs" everything; fake ISO certificates; secretly hires you to fix his jobs.
  - **Old Orin:** retired canyon geologist; teaches underground relay beacons for calibrated thermal probes.
  - Cut: Ollie (radio astronomer).
- **Status palette:** in band teal, guard band amber, out of tolerance red.

Blueprint ideas not in canon (inspiration only): solar flares and ion storms close signal windows; daily drop-pod dispatches ("Your tractor wheel circumference is 1.4 % non-compliant"); fleet autopilot and multi-dish relay arrays in the late game.

## 3. Agent additions (not Ryan's ideas)

- OIRM is a free-flying lab in high Earth orbit; Vance works for the colony authority, not OIRM, but enforces OIRM traceability; Vance's pod is the courier ([ASSUMPTION], equipment doc §1.7).
- Kestrel's standards have no OIRM certificate; Chet's fake certificates fail Vance's check.
- The utility robot "Trellis" (TR-1, TR-2), built from Bram's scrap; it never calibrates itself; a robot found out of tolerance makes its calibrations suspect. Automation grows the calibration loop instead of escaping it.
- Rating bands PROVISIONAL, TRUSTED, ACCREDITED; the contract standard is the HB-700 pressure controller ([PLACEHOLDER]).
- The rogue lab could scale comic glitches with how far out of tolerance the overdue instruments are (swapped controls, odd phone messages).
- Specialization could group paid jobs by discipline; the lab sizes pair with it (one big area for a specialist, many small ones for a generalist).
- The intrinsic standard could end a traceability chain at the lab instead of at OIRM.
- Lin fronts seed money when fines leave the player broke, and buys the harvest at Bram's bay until she has a place of her own.
- Crop names in data: Biscuit Reed, Dust Turnip, Bubble Pods, Suncatch Squash, Lensberry.

## 4. Gaps the story must fill

No premise for why the player is on Mars, who "the manager" is, what MegaCorp is called, what OIRM wants beyond traceability, why Lin is afraid of spiders, what Kestrel's secret is, how the game ends (if it does), or what the off-planet harvest is for.
