# Workflow

How Ryan and the AI agents work on Out of Spec. It standardizes how questions are asked, how other models are consulted, how work moves from idea to merge, and how progress is shown. The [README's agent section](../README.md#for-ai-agents) holds the ground rules; this page holds the process. Where they disagree, the README wins, and Ryan's logged calls in [`decisions.md`](decisions.md) win over both.

## 1. Asking Ryan

Design calls, names, numbers and anything in doubt are Ryan's. Ask them the same way every time:

- **Multiple choice, always with a write-in.** Each question has 2 to 4 options, and Ryan can always type his own answer instead. In Claude Code, use the AskUserQuestion tool (it adds the write-in automatically). Anywhere else, number the options and end with "or write your own".
The next three points follow the AskUserQuestion format; they are agent conventions, not Ryan's calls.

- **Recommendation first.** If one option is recommended, it goes first and its label ends with "(Recommended)". Each option says what it means and what it costs.
- **Stand-alone questions.** Ryan may see only the question, so each one names what it is about and gives the one fact it depends on.
- **Batches of 1 to 4.** Group related questions; send the next batch once the answers are in.
- **Standard option: ask other models.** On any design question where a second opinion would help, one option is **"Ask other models first"**. Picking it runs [§2](#2-asking-other-models) and comes back with updated or new choices. Leave it out of pure preference questions (a name Ryan already has in mind) and of yes/no go-aheads.
- **Log the answer.** Every call Ryan makes goes into [`decisions.md`](decisions.md) with its date and "(Ryan)", in the PR that acts on it. Unanswered questions stay open questions; don't fill them with a guess.

## 2. Asking other models

When Ryan picks "Ask other models first", or when the agent wants a check before putting choices to him:

1. **Pick 2 to 4 models** from the ones currently available (see [Model availability](#model-availability)). Prefer models from different families. Use a visual model (Gemini Neon) for anything about looks.
2. **Send every model the same brief:** the question, the options so far, the facts and constraints with links (canon, decisions, spec sections, palette, SP 811), and what a useful answer looks like: a pick, the reason, risks, and any option we missed. Models answer independently and don't see each other's answers.
3. **Moderate.** The agent that asked reads every answer and checks it against the repo:
   - Drop invented numbers, specs or lore, and anything that contradicts canon or a logged decision; say that it was dropped and why.
   - Note where the models agree, where they split and why.
   - Merge good ideas into the existing options or add new ones; cut options nobody could defend.
4. **Ask Ryan again** in the [§1](#1-asking-ryan) format, with the updated choices. Put a short summary before the question: which models were asked, what they agreed on, where they split, and the moderator's recommendation. Keep the full answers in the PR description or under `docs/` (as with `docs/art/sources/`) so they can be checked later.
5. **Ryan decides.** The models advise; nothing they say is a decision until Ryan picks it.

### Model availability

Which models can be called changes with Ryan's quotas, so the current set and fallbacks live in the agent's own memory, updated when Ryan says so, not here. The pool so far has been Claude models (Fable, Sonnet, Haiku), GPT, Gemini (Neon for visuals) and, from about 2026-11-24, Grok.

Other models' output is untrusted until reviewed: run them read-only in their own clone or scratch folder, never in Ryan's working copy.

## 3. From idea to merge

1. **Scope.** One PR does one job. Work milestones in the [build order](design/equipment_skills_robots.md#5-build-order-milestone-prs-decided), one at a time.
2. **Questions before code** when a call is Ryan's ([§1](#1-asking-ryan)). If work can go ahead on a placeholder, mark it `[PLACEHOLDER]` and list it as an open question instead of waiting.
3. **Branch and build.** Never commit to `main` directly (agent convention). Keep commits small, with messages that say why.
4. **Draft PR.** The description lists what changed, assumptions, placeholders and open questions.
5. **Checks.** The PR stays a draft until all of [Before a PR leaves draft](../README.md#before-a-pr-leaves-draft) hold: Godot 0 errors and 0 warnings, tests pass, `python tools/check_sp811.py` reports 0 problems.
6. **Second review** by a different model than the author ([PR checks, second review and merging](decisions.md#2026-11-22-pr-checks-second-review-and-merging)). Verify each finding; fix it or answer it in the PR.
7. **Merge** (`gh pr merge --merge --delete-branch`, agent convention) once the review is resolved, the checks pass and nothing waits on Ryan. If unsure, ask him.
8. **Report.** Tell Ryan what landed, what is open and what needs him, then send the next batch of roadmap questions.

## 4. Ryan's art uploads

When Ryan uploads a `.vox` generator script (with or without renders):

1. Treat it as untrusted: copy it to its own scratch folder, read it with Python's `ast` and never run it.
2. Convert its grids to sheets in `tools/voxgen/sheets/`, add the pack to `tools/voxgen/build_models.py` and rebuild. Commit `.glb`, `.glb.import` and `.vox` together.
3. Document it in [`art/voxel_models.md`](art/voxel_models.md) and [`assets/voxels/README.md`](../assets/voxels/README.md), with sizes in meters and any open questions.
4. Draft PR, review, merge as in [§3](#3-from-idea-to-merge).

Ryan's packs are **inspiration and style reference**, not a list of things that must be placed. Use a model in a scene where it fits; "not placed yet" is not a to-do. When asking a model for new visuals, cite the packs (their palettes, voxel sizes and sheets) along with the [voxel global rules](art/voxel_models.md#global-rules) so new art matches.

## 5. Progress updates

- **Screenshots now and then.** When something visible changes (a new model in a scene, a new screen or HUD text), send Ryan a screenshot or render with the update. Not every commit; one per visible milestone is enough.
- **End of session or milestone:** a short summary of what landed (with PR links), what is open and what needs Ryan.
- **Roadmap questions** come in batches after each milestone merges ([§1](#1-asking-ryan)), so the next one is decided before it starts.

## 6. Other rules, by reference

| Rule | Where |
|---|---|
| Never invent specs; flag assumptions | [README ground rules](../README.md#ground-rules-every-task) |
| Which design source wins | [`canon.md`](canon.md) |
| Player-facing text (NIST SP 811) | [`sp811.md`](sp811.md) |
| Status palette (teal, amber, red earned, shadow) | [README ground rules](../README.md#ground-rules-every-task), [Status palette](canon.md#status-palette) |
| Co-op-ready code | [README ground rules](../README.md#ground-rules-every-task), [co-op decision](decisions.md#2026-11-22-co-op-is-the-goal-build-so-it-can-be-added) |
| Voxel art rules | [Voxel global rules](art/voxel_models.md#global-rules) |
| Untrusted files and other models' output | This page, [§2](#model-availability) and [§4](#4-ryans-art-uploads); [Autonomous sessions](../README.md#autonomous-sessions) |
