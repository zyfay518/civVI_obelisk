# Civilization VI Mod Package

This folder contains the first real Civilization VI in-game UI prototype.

## Package

```text
civ6-mod/Obelisk/
  Obelisk.modinfo
  UI/Obelisk.xml
  UI/Obelisk.lua
```

## Manual Game Test

Copy `civ6-mod/Obelisk` into your Civilization VI Mods folder, then enable
`Obelisk` in Additional Content.

Typical macOS folder:

```text
~/Library/Application Support/Sid Meier's Civilization VI/Mods/
```

Expected result in a single-player game:

- A top-center localized `Ask Obelisk...` / `询问 Obelisk...` control appears in-game.
- Clicking it expands a small answer panel.
- The answer panel shows a local snapshot: turn, science, culture, gold, and
  city count.
- Clicking `X` collapses the panel.
- The panel auto-collapses after about 8 seconds.

This version does not call AI yet. It validates that the in-game UI context can
load, respond to clicks, localize text, and read simple game-state values.
