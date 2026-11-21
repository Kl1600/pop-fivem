# POP Chat

Use `/me` followed by an action to show a short roleplay message above your character and in a nearby activity panel. It uses the standard FiveM command system through F8 or a compatible chat input. The optional command suggestion is registered when FiveM's chat starts.

Start your framework first if you use one, then `ensure pop_chat`. Set `Config.Command` if another resource already uses `/me`. The server chooses recipients using nearby player positions and routing buckets. `config.lua` controls distance, cooldown, display time, and the maximum number of Unicode characters. No database or third-party chat package is required.
