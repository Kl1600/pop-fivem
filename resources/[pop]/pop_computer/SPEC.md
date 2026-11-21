# POP Computer

A configurable workstation using an original arrangement of stock GTA props. An allowed player approaches a workstation and opens a compact status terminal. An optional pop_duiengine surface displays the workstation status in the world. The stock model and terminal still work without it.

## Files

`fxmanifest.lua`, `config.lua`, `README.md`, `client/main.lua`, `server/main.lua`, `web/index.html`, `web/style.css`, `web/script.js`, `web/screen.html`, `web/screen.js`, `web/screen.css` and all ten locale files. Shared template files and web kit stay byte-identical.

## API

| Entry point | Input and output |
|---|---|
| `pop_computer:open` callback | Terminal integer index → `ok, reason, data?`. Data contains character name, job label if available, and server UTC timestamp. |
| `pop_computer:open` NUI message | `{ action, terminalId, name, job, time }`. |
| `pop_computer:close` NUI message | Hides the terminal. |
| `close` NUI callback | Handled via the Bridge's shared close callback. |
| `pop_computer:screen` DUI message | `{ action, title, status, rtl, accent }`, both values localized. |

## Configuration

Template defaults plus `Config.Terminals` containing terminal entries with position, heading, model, optional job whitelist, optional duty requirement, and optional ACE, and optional routing bucket. One example entry is included. Optional `screen` defines position and normal vectors plus world width and height. `Config.InteractionDistance = 2.5`, `Config.StreamDistance = 35.0`.

## Validation and performance

The server verifies terminal index, connected identity, living state, proximity, job, duty and ACE. There are no economy or storage operations. Callback rate limiting uses the template. The client registers one interaction per terminal through the Bridge, creates stock models locally only in streaming range, and deletes them, any optional DUI surfaces, targets and UI focus on stop. The panel also closes when the player leaves its range or dies. No continuous frame loop in this resource.
