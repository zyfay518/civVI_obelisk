# Overlay UI

Overlay UI is the quiet player-facing layer.

Design rules:

- Top-center placement.
- Idle state shows only one translucent input.
- Expanded state grows downward after the player asks a question.
- Maximum height should stay below roughly 35% of the screen.
- Answers auto-collapse after a short delay.
- The UI should feel like Civilization VI glass, not a second dashboard.

The first prototype should prioritize interaction feel before visual detail.

## Static Mock

Open `index.html` in a browser to test the first interaction prototype.

Current behavior:

- Idle top-center input.
- Submit with Enter or the round submit button.
- Expand answer panel using a mock Consul response.
- Switch response mode, length, and advice level at runtime.
- Auto-collapse after the configured delay.
