# Project Obelisk / The Silent Consul

The Silent Consul is an AI cognition layer for Civilization VI.

It is designed to help players understand the game state without playing the
game for them. The system follows three product rules:

- Silent first: the assistant does not speak unless asked.
- Explain, do not command: answers should explain causes and evidence.
- No cheating boundary: no memory reading, no automation, no PVP advantage.

## Concept

The project is split into three layers:

- `Lua Beacon`: a Civ VI mod-side signal collector for observable game state.
- `Python Consul`: an analysis service that turns structured state into useful
  explanations.
- `Overlay UI`: a lightweight top-center assistant interface above the game.

## Assistant Modes

- `Rosetta`: beginner-friendly explanations.
- `Oracle`: strategic diagnosis and prioritization.
- `Antikythera`: data-heavy reasoning, formulas, and assumptions.

## Repository Layout

```text
config/        Runtime-tunable assistant profile examples
docs/          Product, architecture, and design notes
lua-beacon/    Civ VI mod-side data collection layer
overlay-ui/    Top-center silent overlay interface
prompts/       AI response templates by mode
python-consul/ Analysis service and model orchestration layer
```

## Current Status

The active branch is `codex/civ6-ingame-ui`.

The project now has a working Civilization VI in-game Obelisk UI prototype.
The old browser overlay remains useful as a mock, but current validation happens
inside the real game.

Implemented in the Civ VI mod prototype:

- top-center Obelisk panel;
- Chinese UI adaptation;
- compact current data, rule advice, turn comparison, memory status, city
  overview, and backend status modes;
- explicit-interaction current snapshot collection;
- compact in-session journal;
- backend snapshot fields for player yields, tech/civics, economy, cities,
  units, resources, government/policies, diplomacy, victory, great people,
  trade route count/capacity, and first-city loyalty.

Current phase:

```text
Phase 1: backend data completeness, with UI kept compact.
```

Before continuing development from a new machine or thread, read:

```text
docs/PROJECT_HANDOFF_2026-06-14.md
```
