# pop_duiengine — Specification

Client-only DUI lifetime manager for local pages, runtime textures and optional world-space panels. Its core includes owner-scoped surfaces, front-facing rendering, message and mouse forwarding, and cleanup. The legacy engine's entity and bone attachments, global texture replacement and focus automation are outside this API.

## Files and dependencies

`fxmanifest.lua`, `config.lua`, `client/main.lua`, `README.md`, `web/index.html`, unmodified Bridge, callback, locale and web kit, and ten locales with the original template keys (no resource-specific text or user interface). No dependency, database, network events or NUI callbacks of its own. Optional consuming pages run in the owning resource.

## Client exports

| Export | Contract |
|---|---|
| `Create(id, options)` | Returns boolean. Creates a surface owned by the invoking resource and indexed by its local ID. |
| `GetTexture(id)` | Returns runtime TXD and texture name while ready, otherwise nil. |
| `Send(id, data)` | Sends a size-limited JSON object to an available browser. Returns boolean. |
| `Destroy(id)` | Releases the owned browser. Returns boolean. |
| `SetTransform(id, position, normal, worldWidth?, worldHeight?)` | Updates the displayed plane, or disables world rendering with a nil position. |
| `SetUrl(id, page)` | Navigates to an allowed page. |
| `MouseMove(id, u, v)` | Moves pointer to normalized coordinates in 0..1. |
| `MouseButton(id, button, pressed)` | Sends left, middle or right mouse down/up. |
| `MouseWheel(id, delta)` | Scrolls by a bounded integer offset. |

Options: `page` in `nui://<owner>/...` or `https://cfx-nui-<owner>/...`; optional texture `width, height` default 512; optional `position, normal, worldWidth, worldHeight` are required as a set for world rendering. Configuration limits browser resolution, count per resource and total count, idle polling, render range and JSON message bytes.

## Safety and performance

Check the invoking owner for every export. Deny foreign and remote pages, traversal and invalid paths in Create and SetUrl. Consumers are trusted to control links, scripts and subresources within their own HTML. Validate finite coordinates, nonzero normals and bounded dimensions. Reuse runtime texture slots so repeated creation does not produce an unbounded number of texture dictionaries within the resource lifetime. Register one scheduler for all planes: adaptive delay when distant, per-frame drawing only while a plane is visible to the local camera. Destroy surfaces when the owner stops and during engine shutdown.
