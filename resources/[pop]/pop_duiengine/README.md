# pop_duiengine

Client-side DUI lifecycle management for other FiveM resources. It provides runtime textures and optional front-facing panels with no framework or database dependency.

## Installation and use

Copy the resource into your resources directory and start it before consumers. Place the display HTML in the consuming resource's manifest `files`. The engine scopes each surface to its caller and checks the caller’s local HTML URL on creation and navigation through the engine. Only load trusted local pages. A consumer controls its own page content, subresources and navigation after the page loads.

```lua
local dui = exports.pop_duiengine
dui:Create('terminal', {
    page = 'nui://' .. GetCurrentResourceName() .. '/web/screen.html',
    width = 512, height = 512,
    position = vec3(100.0, 200.0, 30.0), normal = vec3(1.0, 0.0, 0.0),
    worldWidth = 0.6, worldHeight = 0.4,
})
-- Wait until your display page reports readiness before sending state.
dui:Send('terminal', { action = 'status', ready = true })
local txd, texture = dui:GetTexture('terminal')
dui:Destroy('terminal')
```

Without a transform the surface is texture-only. `SetTransform(id, position, normal, width, height)` updates the plane or removes it with a nil position. `SetUrl(id, page)` changes the local HTML page. `MouseMove(id, u, v)`, `MouseButton(id, button, pressed)` and `MouseWheel(id, delta)` forward input when the browser is available.

Configure render distance, dimensions, browser counts and message size in `config.lua`. The engine frees its browsers when their owning resource stops. Consumers handle UI focus, pointer raycasts, occlusion policy and page readiness.
