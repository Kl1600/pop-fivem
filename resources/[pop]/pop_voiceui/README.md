# POP Voice UI

A compact local microphone activity display for FiveM. Start it with `ensure pop_voiceui` and toggle it with `/popvoice`.

The panel uses FiveM's local speaking detection. A compatible voice resource may supply `LocalPlayer.state.proximity.distance` and `LocalPlayer.state.radioActive` for the range and radio labels. Older pma-voice installations can report radio activity through the local event. The panel works without those fields. It reads speaking state and leaves voice settings to the server's voice stack.

Client exports are `IsTalking()` and `SetVisible(bool)`. Use `Config.ShowRange` to hide the optional range and `Config.HangTime` to set how long the indicator stays visible between speech bursts.
