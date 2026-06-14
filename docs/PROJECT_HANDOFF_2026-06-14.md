# Project Obelisk Handoff - 2026-06-14

This document is the current source of truth for resuming Project Obelisk from another computer or another Codex thread.

Working language with the owner is Chinese. Keep user-facing validation checklists concise and in Chinese.

## Quick Resume

Repository:

```text
https://github.com/zyfay518/civVI_obelisk.git
```

Current active branch:

```text
codex/civ6-ingame-ui
```

Current handoff state:

```text
Use the latest commit on codex/civ6-ingame-ui. This handoff document is part of that commit history.
```

Recommended resume command on another computer:

```sh
git clone https://github.com/zyfay518/civVI_obelisk.git
cd civVI_obelisk
git checkout codex/civ6-ingame-ui
```

Read this file first, then inspect:

- `docs/PROJECT_PROGRESS.md`
- `civ6-mod/Obelisk/UI/Obelisk.lua`
- `civ6-mod/Obelisk/UI/Obelisk.xml`
- `civ6-mod/Obelisk/Obelisk.modinfo`
- `docs/architecture.md`
- `schemas/game_state_snapshot.example.json`

## Product Goal

Project Obelisk is a Civilization VI in-game cognitive assistant. It should help the player understand the visible game state without playing the game for them.

Core boundaries:

- Read only player-visible / legal Civ VI Lua API data.
- Do not read process memory.
- Do not inject into the game process.
- Do not automate actions, clicks, moves, purchases, or turn ending.
- Do not expose hidden/fog-of-war information.
- Keep AI/API secrets out of Lua and out of the Civ VI mod.

Product tone:

- Quiet, summoned only when needed.
- Explain evidence and uncertainty.
- Avoid commanding the player.
- Deterministic calculations first, AI explanation second.

## Current Implementation State

The current working prototype is an in-game Civ VI mod UI, not the old browser mock.

Implemented:

- Obelisk top-center in-game panel.
- Chinese UI adaptation.
- Translucent background and smaller text styling.
- Buttons:
  - `当前数据`
  - `规则建议`
  - `回合对比`
  - `记忆状态`
  - `城市总览`
  - `后台状态`
- Current snapshot collection on explicit interaction.
- Compact in-session journal for turn comparison.
- No full-history write to Civ VI player properties.
- Full detailed data is kept only in the current Lua `currentSnapshot`.
- The `后台状态` button now shows a compact health/status summary, not a long data dump.

Important current design decision:

> Do not use the UI panel as the primary data verification surface. Most fields should be collected into backend snapshots for rules/AI, while the UI displays only useful summaries and answers.

## Data Currently Collected

Player / economy:

- turn
- science per turn
- culture per turn
- gold balance
- gold per turn
- faith balance
- faith per turn
- tourism
- score
- military strength

Technology / civics:

- current technology
- turns remaining for current technology
- completed technology count
- current civic
- turns remaining for current civic
- completed civic count
- current era

Government / policy:

- current government name
- policy slot count
- active policy card samples

Cities:

- city count
- all owned city snapshots
- city name
- population
- current production
- production turns remaining
- food
- food surplus
- housing
- amenities
- amenities needed
- city yields: food, production, science, culture, gold
- worked plot count
- worked plot yield samples
- plot attribution samples
- building count
- district count
- wonder count
- first-city loyalty summary

Resources:

- total owned resource type count
- bonus resource count
- luxury resource count
- strategic resource count
- resource samples

Units:

- unit count
- unit type samples
- unit detail samples: position, damage, moves remaining, XP

Religion / great people:

- founded religion name if available
- pantheon if available
- great people point samples

Diplomacy / victory:

- met civilization count
- major contact count
- minor contact count
- war count
- diplomacy samples
- diplomacy modifier samples
- enabled victory count
- victory progress samples
- victory description samples

Trade:

- outgoing trade route count
- outgoing trade route capacity

## Data Not Yet Collected Or Still Shallow

High priority next backend fields:

1. All-city loyalty details, not just first-city summary.
2. Trade route details: origin, destination, yields, turns remaining if safely accessible.
3. Technology/civic candidates: available next choices and Eureka/Inspiration status if safely accessible.
4. City-state details: envoys, suzerain status, quests, city-state type.
5. Deeper victory metrics: scientific victory projects, culture tourists, religion spread, diplomatic victory points.

Deferred / higher-risk:

- Governors: assignment, titles, promotions. Only add in a small isolated patch after finding safe official UI usage.
- Spies: count, missions, city, turns. Same rule: isolated patch only.
- Full map strategic scoring. Needs careful performance and UI boundary control.

## Stability History

The project had a crash regression on 2026-06-13 when a broad audit tried to read too much data too early.

Important bad pattern:

- Do not collect broad snapshots during UI initialization.
- Do not automatically collect full snapshots on turn begin unless the panel is already expanded and the scope is known safe.
- Do not write full nested snapshots into Civ VI player properties.
- Do not reintroduce risky broad probes for governors/spies/loyalty/trade without isolating them.

Stable direction now:

- Lua UI is thin.
- Snapshot reads happen on explicit user interaction.
- Full data lives only in the current snapshot.
- History is compact session summaries.
- Durable storage and AI context should later move to Python Consul.

Known stable commits after crash repair:

- `14e804b Stabilize Obelisk UI startup`
- `407bd70 Use current snapshot with compact summaries`
- `f33010b Add safe audit details`
- `2b191ab Add city makeup audit counts`
- `1459ea5 Add resource and religion audit details`
- `ccfd1fc Add great people audit samples`
- `ea52482 Add trade route audit summary`
- `fffd78e Add loyalty audit summary`
- `51cf3ad Show compact backend data status`

## Current Owner-Verified Status

The owner has confirmed in real Civ VI:

- Obelisk appears in-game.
- The panel is named Obelisk, not Silent Consul.
- Chinese UI adaptation works.
- Basic current data reads are acceptable.
- Rule advice can reference current data.
- Turn comparison works.
- Multi-city, policy, resource, religion, great people, trade route count, and loyalty additions did not crash in the tested save.
- The owner does not want long raw data dumps in the UI; backend data should feed rules/AI.

Recent verification passed:

- Trade route summary worked.
- First-city loyalty summary worked.
- `后台状态` compact display was implemented and installed after that decision.

## Owner Workflow Preference

The owner validates in the real game. Do not ask for browser-only validation for Civ VI mod behavior.

For every iteration, provide a focused checklist in Chinese. Include only newly changed behavior. Do not repeat previously passed items unless there is a regression risk.

Checklist style:

```text
验证版本：
验证目标：

本轮必测项：

[ ] 1. 操作：
    预期：
    实际：

[ ] 2. 操作：
    预期：
    实际：

额外发现：
-
```

The owner wants progress in phases:

1. Data correctness/completeness.
2. Rule mechanism validation.
3. Product UI/interaction refinement.
4. AI API integration and answer quality refinement.

Current phase:

```text
Phase 1: Backend data completeness, with UI kept compact.
```

## Local Install Path Used On The First Mac

The first Mac used this installed mod path:

```text
/Users/zhangjunjie/Library/Application Support/Sid Meier's Civilization VI/Sid Meier's Civilization VI/Mods/Obelisk
```

Steam game path on that Mac:

```text
/Users/zhangjunjie/Library/Application Support/Steam/steamapps/common/Sid Meier's Civilization VI
```

On another computer, Civ VI's mod path may differ. Do not assume the path; ask the owner or inspect the local Civ VI user folder.

## Suggested Next Step

Next coding step should be:

```text
Add backend-only all-city loyalty fields.
```

Implementation notes:

- Use `city:GetCulturalIdentity()` only.
- Do not use a separate `city:GetLoyalty()` component unless official UI code proves it safe.
- Store per-city fields in `citySnapshot`:
  - `loyalty`
  - `loyaltyMax`
  - `loyaltyPerTurn`
  - `loyaltyLevel`
- Do not add a long UI display for each city.
- Optionally update `后台状态` text to say all-city loyalty has been collected after implementation.

Validation checklist for that next step should be only:

1. Enter/load game and wait 10-20 seconds: no crash.
2. Open Obelisk and click `后台状态`: no crash and compact status appears.
3. Click `城市总览`: no unexpected raw loyalty dump appears.

## Git / Cloud State

This handoff document should be committed and pushed to `codex/civ6-ingame-ui` before switching computers.

If resuming and this file is present in GitHub, trust it over older chat history.
