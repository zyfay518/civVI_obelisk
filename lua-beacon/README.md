# Lua Beacon

Lua Beacon is the Civilization VI mod-side data collection layer.

Initial responsibilities:

- Collect observable player and city state.
- Normalize snapshots into a stable payload schema.
- Send or export snapshots to Python Consul.

Planned snapshot areas:

- Turn and era
- Player yields
- City population and production
- Districts and buildings
- Technologies and civics
- Policies and governments
- Known visible map context

Implementation should stay within supported Civ VI mod APIs and avoid memory
inspection or automation.
