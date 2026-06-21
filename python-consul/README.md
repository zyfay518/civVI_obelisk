# Python Consul

Python Consul is the analysis service for The Silent Consul.

Initial responsibilities:

- Receive a player question and game-state snapshot.
- Load the active assistant profile.
- Compute deterministic derived metrics.
- Run local knowledge matching before any AI prompt is built.
- Return a structured answer for Overlay UI.

The first prototype supports both mock standard states and mapped Obelisk Lua Beacon snapshots.

## Local Knowledge MVP

The first knowledge system is intentionally lightweight:

- JSON knowledge files in `../knowledge`.
- Standard-library Python dataclasses.
- Local rule/meta matcher.
- Simple scoring system.
- Obelisk snapshot mapper for current Lua field names.
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

Obelisk snapshot CLI:

```powershell
$env:PYTHONPATH='python-consul'
py -m obelisk_knowledge.cli --knowledge-root knowledge --state path\to\obelisk_snapshot.json --state-format obelisk --question "我现在适合玩小马流吗？"
```

Current mapping is deterministic and local. Horse/iron detection from `resourceSamples` is heuristic until Lua Beacon emits normalized resource counts.

The output is structured JSON and can later be passed to an AI response layer.
