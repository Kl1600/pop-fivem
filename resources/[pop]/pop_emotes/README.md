# POP Emotes

Press **F3** or use `/popemotes` to browse built-in GTA animations. Star the animations you use most to save them on this client. Press **X**, use `/popemotes_cancel`, or use the menu to stop an animation.

A shared handshake sends a request to the closest eligible player. The recipient opens the emote menu to accept or decline. The server checks distance, routing bucket and player state again before starting the shared action. FiveM key bindings can be remapped by players.

Start the framework first if present, then `ensure pop_emotes`. `config.lua` holds the animation catalogue and invitation settings. Animation assets already ship with GTA V. There is no SQL setup.

Client exports are `GetCurrentEmoteName()`, `Play(id)` for solo animations, and `Stop()`.
