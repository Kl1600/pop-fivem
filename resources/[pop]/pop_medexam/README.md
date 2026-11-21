# POP Medical Exam

Players can obtain a medical fitness certificate through a self-service exam or an examination run by on-duty EMS.

## Installation

1. Place `pop_medexam` in your resources directory and start your framework and inventory first.
2. Register the `medical_certificate` item in your inventory. Enable item metadata if you want the certificate card and expiry tracking.
3. Add `ensure pop_medexam` to `server.cfg`.
4. Set clinic locations, price, duration, validity and locale in `config.lua`.

Use `auto` for self-service, `ems` for EMS appointments, or `mixed` for self-service when no eligible EMS player is on duty. Set the price to zero in standalone mode and use a supported inventory. Inventories without metadata issue a plain item and validate certificates by item ownership.

## Server exports

- `exports.pop_medexam:HasValidCertificate(source)` returns whether the player has a valid certificate.
- `exports.pop_medexam:GiveCertificate(source, doctorName)` issues a certificate and returns whether the item was added.

In game, check self-service payment and failure, patient consent, EMS duty changes during an exam, an inventory full at issuance, expiry and the nearby certificate card.
