# Obelisk Civilization VI Mod Package

This folder contains the first real Civilization VI in-game UI prototype for
Obelisk.

## Iteration Track

```text
0.1 In-game UI bridge
    Status: passed
    Goal: load an Obelisk UI context inside Civilization VI.

0.2 Basic data snapshot
    Status: passed
    Goal: read turn, yields, gold, cities, first city, production, research,
    and civic data, then show fixed data-grounded advice.

0.3 Session journal
    Status: passed
    Goal: keep a short in-session snapshot journal and compare the current
    turn against the previous recorded turn.

0.4 Save-backed memory probe
    Status: current
    Goal: persist the latest short journal through Civilization VI player
    properties and verify whether records survive save/load.

0.5 Wider data coverage
    Status: next
    Goal: add units, military state, visible resources, city yield details,
    and active objectives.

0.6 Structured local bridge
    Status: planned
    Goal: expose structured snapshots to a local Python Consul service.

0.7 AI response adapter
    Status: planned
    Goal: replace fixed rule advice with configurable AI-backed responses.
```

## Package

```text
civ6-mod/Obelisk/
  Obelisk.modinfo
  UI/Obelisk.xml
  UI/Obelisk.lua
```

## Manual Game Test

Copy `civ6-mod/Obelisk` into your Civilization VI Mods folder, then enable
`Obelisk` in Additional Content.

Typical macOS folder:

```text
~/Library/Application Support/Sid Meier's Civilization VI/Mods/
```

Expected result in a single-player game:

- A top-center localized `Ask Obelisk...` / `询问 Obelisk...` control appears in-game.
- Clicking it expands a small answer panel.
- The answer panel shows local snapshot, fixed rule advice, turn comparison,
  and memory status controls.
- Clicking `X` collapses the panel.
- The panel auto-collapses after about 20 seconds.

This version does not call AI yet. It validates that the in-game UI context can
load, respond to clicks, localize text, read simple game-state values, maintain
a short journal, and probe save-backed memory.
