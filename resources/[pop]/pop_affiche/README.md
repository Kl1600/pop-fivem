# pop_affiche

Place persistent image posters on walls. Authorized players can edit or remove their posters nearby. Players can view posters as they approach.

## Installation

1. Install `oxmysql` and start it before `pop_affiche`.
2. Copy the resource into your resources directory and add `ensure pop_affiche` to `server.cfg`. The SQL table is created on startup.
3. Grant placement access with `add_ace group.vip pop.affiche.write allow`. Bridge administrators already have access.

Works with ESX Legacy and older ESX, QBCore, Qbox and standalone. The common Bridge provides ox_target, qb-target and a built-in prompt. The interface supports ten languages including right-to-left Arabic.

## Usage

Aim at a nearby wall and run `/pop_affiche`, or bind **Place a poster** in FiveM key settings. Enter a direct HTTPS link to a PNG, JPEG or WebP hosted on an approved hostname and confirm. Approach a poster to edit it or remove it. Removal requires a second confirmation.

`Config.Hosts` lists exact image hostnames. Only add hosts you trust to serve images and handle visitor requests. Each viewing client fetches the image from its host. Signed links may expire. Configure poster dimensions, draw distance, visible count and per-character limits in `config.lua`.

Poster positions and links are stored in `pop_affiche_surfaces`. This is a new table. Existing `tab_affiche` rows are not imported automatically.

Image hosts must serve HTTPS responses with a raster content type and allow CORS from the DUI page. Links must resolve directly without redirects. The viewer caps images at 5 MiB and sends no cookies or referrer.
