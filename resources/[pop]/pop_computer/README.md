# POP Computer

Configurable roleplay workstations with a compact status terminal. A stock GTA monitor is included in the example setup.

## Installation

1. Enable OneSync and start your framework first if you use one.
2. Configure stations in `Config.Terminals`. Each station has a position, heading and optional stock model. Move the example station to suit your MLO. Set `model = false` to use an existing prop.
3. Add `ensure pop_computer`. Interact using ox_target, qb-target, or the native prompt. Use Escape or the close button to leave the panel.

A workstation can restrict access by job, minimum grade, active duty, ACE, or routing bucket. For a standalone server, use ACE or leave the workstation open to everyone.

A station can optionally define a `screen` plane to display terminal status in the world. Start `pop_duiengine` before this resource and tune the plane position, normal, width and height for the physical screen. Each surface is created and destroyed locally as players move in and out of streaming range.
