# Python Consul

Python Consul is the analysis service for The Silent Consul.

Initial responsibilities:

- Receive a player question and game-state snapshot.
- Load the active assistant profile.
- Compute deterministic derived metrics.
- Build the AI prompt for the selected mode.
- Return a structured answer for Overlay UI.

The first prototype can use mock snapshots before Lua Beacon is connected.
