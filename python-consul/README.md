# Python Consul

Python Consul is the analysis service for The Silent Consul.

Initial responsibilities:

- Receive a player question and game-state snapshot.
- Load the active assistant profile.
- Compute deterministic derived metrics.
- Run local knowledge matching before any AI prompt is built.
- Return a structured answer for Overlay UI.

The first prototype can use mock snapshots before Lua Beacon is connected.

## Local Knowledge MVP

The first knowledge system is intentionally lightweight:

- JSON knowledge files in `../knowledge`.
- Standard-library Python dataclasses.
- Local rule/meta matcher.
- Simple scoring system.
- No vector database.
- No large model dependency.

Run tests from the repository root:

```powershell
$env:PYTHONPATH='python-consul'
py -m unittest discover python-consul/tests
```

Example CLI:

```powershell
$env:PYTHONPATH='python-consul'
py -m obelisk_knowledge.cli --knowledge-root knowledge --state knowledge/mock_states/early_horse_state.json --question "我现在适合玩小马流吗？"
```

The output is structured JSON and can later be passed to an AI response layer.
