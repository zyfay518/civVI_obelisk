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

This repository is at the initial scaffold stage. The first milestone is a
minimal end-to-end prototype:

1. Overlay UI mock accepts a player question.
2. Python Consul returns a structured analysis response.
3. Lua Beacon schema defines the observable game state payload.
