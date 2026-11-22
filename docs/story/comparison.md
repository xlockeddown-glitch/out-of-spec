# Story draft comparison

Four models wrote a story arc from the same brief (`source_ideas.md` plus a drafting prompt), without seeing each other's drafts. This page compares them so Ryan can pick a path, one fork at a time. Nothing here is canon until Ryan chooses it; the choices are logged in `docs/decisions.md` and merged into `story.md`.

| Draft | Model | Title | Words |
|---|---|---|---|
| `drafts/claude-opus.md` | Claude Opus 5.5 | The Traceable Harvest | 3733 |
| `drafts/claude-sonnet.md` | Claude Sonnet 5.5 | Within Tolerance | 3307 |
| `drafts/fable.md` | Claude Fable 5.2 | The Second Root | 4126 |
| `drafts/gemini-hydrogen.md` | Gemini 4 Hydrogen (high) | Zero-Point Harvest | 4375 |

**Model swap.** The task named GPT (Codex gpt-6.2-sol). It was skipped because of a usage limit that runs to 2026-11-24 (Claude models only; Gemini only as Neon or Hydrogen). Gemini Hydrogen gave the outside voice instead, and Fable was added.

## 1. What all four agree on

These beats show up in every draft, so they are safe defaults.

- **The corporation wants the sticker, not the number.** Its charter or insurance needs OIRM traceability to sell anything off Mars, so it hires one cheap contractor.
- **OIRM's hidden motive.** OIRM wants a Mars lab good enough to hold an intrinsic standard, so chains can end off Earth. Your credibility rating is secretly an audition.
- **The manager is a voice from orbit.** A tired, cheerful dispatcher who grants the one-time grace and turns into an ally.
- **No moustache villain.** The real antagonist is drift and the temptation to fake it. A corporate executive gives it a face.
- **Four acts on the credibility bands.** PROVISIONAL (small lab, manual), TRUSTED (medium lab, human in the loop, first contract, robot), ACCREDITED (large lab, remote link, OIRM audit team), then intrinsic standard and off-planet harvest.
- **Set pieces in the same places.** The thirsty-probe harvest (the thesis), the grace audit on day 5, the first flare night with Kestrel, Orin's tunnels, the four-auditor audit, the intrinsic standard, the first launch.
- **Kestrel is a dismissed or blacklisted OIRM-side metrologist** whose standards are honest but unsigned; the intrinsic standard can clear her name.
- **The robot never calibrates itself.** Its big beat is asking to be checked.
- **Chet ends up redeemed**, more or less, after his shortcuts blow up.
- **Lin's spider fear has a real cause** and ends with her holding silk.
- **Rogue glitches** include swapped steering, off-shape crops, a lying phone, and spiders meddling with the coffee maker.
- **Endings:** a main traceable ending, a specialist ending, and a rogue ending played for laughs.

## 2. Where they fork

| Fork | Opus | Sonnet | Fable | Gemini |
|---|---|---|---|---|
| Corporation | Halcyon Regolith Consolidated (HRC), "Compliance Is Our Atmosphere" | Brightwell-Nonesuch Habitats (BNH), "Every Sticker Counts" | Amalgamated Upside (AmUp) | Cradle-to-Crater Corp (C2C) |
| Why you came | Answered a job ad ("Spiders provided") | Last employer collapsed in an audit; in debt | Previous contractor quit; you replace her; return berth is "billable" | Fine print turned you into a 5-year indentured contractor |
| Manager | Dana Pell; ran a lab that went rogue | Marguerite Okonkwo-Tiff; sticker-obsessed, changes most | Odalys Brandt; ex-bench metrologist, rides down in secret for the grace | Maren Solis; fights the liquidation desk, burns a one-time override token |
| Executive face | EVP Corwin Sallow, "Velocity Initiative" | Director Halloran-Voss, "rapid certification" | Chief Confidence Officer Tad Brill, "predictive compliance" | "Project Sunsetting" (replace colony with drones) |
| Rival rogue lab | Yes: the Fastline Annex, run by Chet | No; Chet just fakes certs | Yes: Certainty Plus (AmUp buys Chet), whole colony goes wonky in one week | No; only your own lab |
| Big crisis | A recall from the Annex's bad standard | The Great Audit | The Wonky Week: colony-wide outage on audit day | Project Sunsetting deadline plus master audit |
| Lin's spider fear | She ran an orbital greenhouse; a corporate predator spider ate it | Lab spiders escaped in her postdoc; a night on a counter | Locked in Greenhouse Four; a bad hygrometer drew 40 Curlyhairs in. Arc: it was the hygrometer | Spiders wrecked her moss research on Earth |
| Kestrel | Reported bought certificates; dismissed | Found the Earth-to-Mars chain was never closed | **Was your predecessor**; refused to sign Greenhouse Four, took the blame | Whistleblower framed by C2C |
| Robot | Trellis TR-1 to Trellis-H (humanoid) | Trell | TR-1 to TR-4 "Espalier"; one goes to the off-planet site | Jig-1 to Sora-7 |
| Remote link | The Skein | The Sky Net | The Gossamer link (needs Silk-Spinner silk); control room "the Loom" | HaloMesh |
| Auditors | CLARION, TWAIN, G.P. TOLEMY, XELSIOR | CLADEUS, GEMINID, CHATTERLY-PT, SPACEFLUX-SI | Clement, Castor-and-Pollux, Chatwick, Exa | Clovis-9, TwinStar, SmallTalk-PT, Starhopper-SI |
| Off-planet target | Verdance Ring: Lin's abandoned orbital greenhouse with the original seed lines | Seed stock and crystal from a nearby moon | The Larder: a robot greenhouse on Phobos to feed settlers | Beltway Seed Vault, crops shipped out |
| Intrinsic standard | Matched to your discipline [PLACEHOLDER] | Unspecified | Needs one flawless Depths crystal | Grown from Depths crystals and silk optics |
| Orin | Late partner Ama, nearly killed by an uncalibrated probe | Was a metrologist's apprentice | Signed the colony survey with an overdue instrument; colony is in the wrong place | Shows you the crystal veins |
| Vance's secret | None; clean logs move him | Fined stickers for 6 years for lack of a reason | Was a real inspector; refuses his employer by following the rule exactly | AUD-1T snitches to HQ if he skips a fine |
| Fourth band | REFERENCE | None | None (Annex commissioned) | SOVEREIGN NODE |
| Rogue way back | The Long Recal, "Returned to Spec" stamp | A calibration day | The recall: tell each affected customer in person | Lin's seed sack, climb back |
| Co-op idea | One auditor per player | Roles; Manager's goodnight call waits | "One contractor, plural": one badge; rating is the weakest auditor's | Roles; 23:30 bedtime standoff |
| Extra endings | Returned to Spec | (none beyond three) | The Corner Shop (stay TRUSTED on purpose) | Metric-Exempt Wilderness |

## 3. Tone of each

- **Opus, "The Traceable Harvest".** Closest to the canon blueprint: dry corporate jokes, a warm core and a slow ache. Strongest on a single emotional throughline (seeds lost to drift, recovered by trust). Busiest draft; the most new names.
- **Sonnet, "Within Tolerance".** The gentlest. "Every consequence is first absurd, then a little sad, never cruel." Lighter on structure, with no rival lab and the fewest set pieces. Adds a kid (Pip), which may not fit.
- **Fable, "The Second Root".** The most grounded and the tightest plotting: one past incident (Greenhouse Four) ties Lin, Kestrel and the medium lab together, and the mug-ring grace is the best small moment in any draft. The recall is played as people you have to face. Quiet, dry and humane.
- **Gemini Hydrogen, "Zero-Point Harvest".** The loudest and most sitcom-like, with long sentences and lots of capitals. Good gags (robot stickering rocks, bedtime standoff, chime buffer), but the premise is darker (indentured labour, foreclosure) and it adds a fourth credibility band and a whistleblower bounty. Needs the most cleanup for SP 811 and for things it marked new that are already canon (crop names).

## 4. Notes for merging

- Fable's Greenhouse Four and Opus's Verdance Ring are the two strongest backbones. They can combine: the incident happened on the Ring, or Greenhouse Four is on the surface and the Ring is the off-planet target.
- The auditor names need one set. Opus's and Fable's are the most readable; Gemini's are the most game-like.
- Rival rogue lab (Opus, Fable) versus only your own (Sonnet, Gemini) is the biggest structural fork.
- Every draft keeps specs as [PLACEHOLDER] or as obvious fiction. The sample lines need an SP 811 pass before any reach game text: Gemini's lines use "Sols" and some long numeric jokes; all four use `CR`, `d`, `h`, `min` and the space before units correctly.
