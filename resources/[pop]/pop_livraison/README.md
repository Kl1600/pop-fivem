# POP Delivery

Run a parcel route from the depot using a rented van or your own vehicle. The route HUD tracks the current stop and remaining time.

## Installation

1. Use a OneSync server and place `pop_livraison` in your resources directory.
2. Start your framework and optional vehicle-key resource before `ensure pop_livraison`.
3. Configure the depot, vehicle, parcel count, destinations, payouts, job and locale in `config.lua`. Supply at least as many distinct destinations as there are parcels.

The script supports optional `pop_vehiclekeys` and Qbox vehicle keys integrations. A configured job requires its members to be on duty. In standalone mode, use the own-vehicle route or set the van deposit to zero. Routes are playable without framework payouts.

## Server exports

- `exports.pop_livraison:IsOnRun(source)` returns whether the player has a route.
- `exports.pop_livraison:GetRun(source)` returns the current stop, total stops, time left and earnings, or nil.

In game, check both route types, concurrent van rentals, van return and deposit handling, expiry, and cleanup on character unload.
