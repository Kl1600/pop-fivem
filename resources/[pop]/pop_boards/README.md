# pop_boards

Place persistent drawing boards on walls and paint them in a compact editor. Nearby players can see the saved drawing. Each owner can redraw, clear or remove their own boards, and Bridge administrators can manage all boards.

## Installation

1. Start `oxmysql` before `pop_boards`.
2. Copy the resource into your resources directory and add `ensure pop_boards` to `server.cfg`. The SQL table is created on startup.
3. Leave `Config.WriteAce = false` to allow all players to draw. Set it to `'pop.boards.write'` and grant the corresponding ACE to restrict editing and placement.

Works with ESX Legacy and older ESX, QBCore, Qbox and standalone. The Bridge supports ox_target, qb-target and a built-in prompt. The interface includes ten languages and Arabic RTL.

## Usage

Aim at a nearby wall and run `/pop_boards`, or bind **Place a drawing board** in FiveM key settings. Choose a color and brush width, draw on the canvas, and confirm. Use the nearby target to edit an existing board. Clear the drawing and confirm to save an empty board. Removal asks for a second confirmation.

Board size, draw distance, quotas, stroke count and point count are configurable. The resource stores validated brush strokes in `pop_boards_surfaces`. Legacy snapshots in `tab_boards` require separate conversion. Arbitrary image uploads and corner warping are outside the drawing workflow.
