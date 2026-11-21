# Plan : refonte de la base tab → POP

Source : ancienne base `tab-main` (ESX, scripts tab_/vg_/vanguard_). Elle sert de modèle, son code n'est pas copié tel quel.
Chaque script est réécrit en `pop_<nom>` selon nos règles (tous frameworks, 10 langues, sécurité serveur, HUD sobre).
Les scripts achetés (lb-phone, plt_*, kq_lasers, utility_kitchen…) ne sont pas repris : on fera nos propres versions plus tard.

## Vague 0 — Fondation
- `templates/pop_base/` : bridge commun (ESX Legacy/ancien, QBCore, Qbox, standalone ; inventaires pop/ox/qb/qs/framework ; target ox/qb/touche E ; notifications), callbacks internes, système de langues, kit HUD sobre. Chaque script en copie `bridge/`, `shared/` et le kit.
- `server/` : server.cfg d'exemple et ordre de démarrage.

## Vague 1 — Illégal
pop_dealing (tab_dealing), pop_weed (tab_weed), pop_territories (vg_territories), pop_crew (vg_crew), pop_doorlock (tab_doorlock)

## Vague 2 — Inventaire
pop_inventory (tab_inventory, gros chantier) + modules séparés : pop_vehiclekeys, pop_douilles, pop_sabot, pop_paintgun, pop_radio, pop_chargeurs

## Vague 3 — Véhicules
pop_vehiclepersistence, pop_kilometrage, pop_bennys, pop_enterprisegarage, pop_bikerental

## Vague 4 — Métiers et gestion
pop_interim, pop_management, pop_admin, pop_police (tab_police + tab_police80), pop_medexam, pop_bank, pop_exchange, pop_livraison

## Vague 5 — Interface et joueur
pop_hud, pop_chat, pop_emotes, pop_affiche, pop_boards, pop_charcreator, pop_clothes, pop_idcard, pop_passport, pop_computer, pop_duiengine, pop_voiceui

## Statut
| Vague | Statut |
|---|---|
| 0 | terminée |
| 1 | terminée |
| 2 | terminée |
| 3 | terminée |
| 4 | en cours |
| 5 | à faire |
