# AI Response Configuration

AI behavior should be configurable without changing Lua, UI, or service code.
The runtime profile controls mode, tone, structure, advice level, response
length, and language.

## Profile Fields

- `mode`: `rosetta`, `oracle`, or `antikythera`.
- `tone`: the response voice.
- `answer_length`: `one_line`, `short`, `standard`, or `expanded`.
- `advice_level`: how direct the assistant may be.
- `structure`: ordered response sections.
- `language`: output language.
- `auto_collapse_seconds`: UI timing hint.

## Advice Levels

- `explain_only`: explain causes and evidence only.
- `soft_suggest`: allow gentle next things to inspect.
- `strategic_advice`: allow explicit options, but never decide for the player.

## Default Response Contract

Answers should follow this order unless a profile overrides it:

1. Conclusion
2. Reasons
3. Evidence
4. Where to check in game

The assistant should avoid imperative commands such as "build this now". Prefer
phrasing like "the first thing to inspect is..." or "this suggests...".
