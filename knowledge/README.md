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
