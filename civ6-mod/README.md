# Civilization VI Mod Package

This folder contains the first real Civilization VI in-game UI prototype.

## Package

```text
civ6-mod/TheSilentConsul/
  TheSilentConsul.modinfo
  UI/SilentConsul.xml
  UI/SilentConsul.lua
```

## Manual Game Test

Copy `civ6-mod/TheSilentConsul` into your Civilization VI Mods folder, then
enable `The Silent Consul` in Additional Content.

Typical macOS folder:

```text
~/Library/Application Support/Sid Meier's Civilization VI/Mods/
```

Expected result in a single-player game:

- A top-center `Ask anything...` control appears in-game.
- Clicking it expands a small answer panel.
- Clicking `X` collapses the panel.
- The panel auto-collapses after about 8 seconds.

This version does not call AI yet. It only validates that the in-game UI context
loads and can respond to clicks.
