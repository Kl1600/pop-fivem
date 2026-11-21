# POP HUD

A contextual player status and driving display for ESX Legacy and older ESX, QBCore, Qbox and standalone. The interface needs no database or UI library.

Start your framework first, then `ensure pop_hud`. Use `/pophud` to toggle the overlay. The default radar policy leaves the native radar alone. Set `Config.Radar` to `vehicle`, `visible`, or `hidden` to let POP HUD manage it. Configurable blips need a label key in each locale. FiveM handles the map and pause menu.

Health, armor, hunger and thirst appear when relevant. ESX can publish needs through its optional status event; QB and Qbox use player metadata. Servers with a custom needs resource can call `exports.pop_hud:SetNeeds({ hunger = 72, thirst = 64 })` client-side. The companion `SetVisible(bool)` export toggles the overlay and any radar policy that POP HUD owns. The speed display appears only for drivers. Fuel uses the vehicle's percentage state when available, or the native fuel level and tank capacity.
