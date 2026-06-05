# Architecture

The Silent Consul uses a three-layer architecture.

## 1. Lua Beacon

Lua Beacon lives inside the Civilization VI mod boundary. Its job is to expose
observable, non-invasive game state in a structured form.

Responsibilities:

- Read game-state values available through supported Civ VI Lua APIs.
- Normalize city, player, yield, district, technology, civic, and turn data.
- Emit snapshots for analysis.

Non-goals:

- Do not read or write process memory.
- Do not automate player actions.
- Do not expose hidden information in multiplayer contexts.

## 2. Python Consul

Python Consul is the analysis and orchestration service.

Responsibilities:

- Accept structured game-state snapshots and player questions.
- Run deterministic checks where possible.
- Compose an AI prompt from the selected assistant profile.
- Return concise, evidence-backed explanations.

The recommended split is:

- Deterministic code computes facts and derived metrics.
- AI explains the meaning, tradeoffs, and reasoning in player-friendly language.

## 3. Overlay UI

Overlay UI is the player-facing surface.

Responsibilities:

- Stay top-center and quiet by default.
- Accept natural-language questions.
- Display answers without blocking core Civ VI panels.
- Auto-collapse after the answer has been read.

## Data Flow

```text
Civ VI Lua APIs
  -> Lua Beacon snapshot
  -> Python Consul analysis
  -> AI response
  -> Overlay UI
```

## Boundary

The project helps players understand Civilization VI. It must not become a
bot, automation tool, or hidden-information advantage.
