# Project Obelisk Knowledge Base

This directory stores structured Civilization VI knowledge for Project Obelisk.

The knowledge base is split into:

- `published/rules`: stable game-rule facts and mechanics.
- `published/explanations`: reusable interpretation templates.
- `published/tips`: player strategy tips that passed rule checks.
- `review`: collected claims that still need validation.
- `inbox`: raw source metadata and extraction notes.
- `sources`: normalized source records.

Data files use JSON arrays so Python Consul can load them without extra dependencies.

Rules for adding data:

1. Do not store full forum posts, full articles, full subtitles, or full transcripts.
2. Store structured summaries, source metadata, short verification notes, and tags.
3. Player tips must pass rule checks before moving into `published/tips`.
4. If a claim conflicts with base rules, keep it in `review` or reject it.
5. Prefer many small single-claim entries over long mixed strategy essays.

Current baseline rule coverage:

- City systems: population, food, housing, amenities, loyalty.
- Districts and buildings: specialization, adjacency, buildings, wonders.
- Research and civics: science, culture, boosts.
- Governments and governors: policy slots, policy timing, governor roles.
- Diplomacy and city-states: relations, visibility, envoys, quests.
- Religion and faith: faith economy, religious spread, pantheon/beliefs.
- Victory conditions: science, culture, domination, religion, diplomacy.
- Warfare and units: tech timing, siege, maintenance.
- Economy, trade, resources: gold, trade routes, luxury/strategic resources.
- Map and improvements: visibility boundary, settlement, builders, chops.
- Espionage: spy missions and counterspy roles.
- Eras, world congress, climate: era score, congress, power/climate.

Current first-pass baseline contains 47 structured rule entries across 12 rule files. This baseline is intended for rule-checking community tips. It is not a full dump of every XML/SQL modifier, civilization ability, leader ability, unit row, building row, or numeric database value. Those should be added later as specialized data tables if a question or tip requires them.
