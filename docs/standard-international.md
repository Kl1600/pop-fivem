# Standard POP : 5 langues et compatibilité tous serveurs (décision du client, 25/11/2026)

Chaque script `pop_*` doit pouvoir s'installer sur n'importe quel serveur, sans modifier le code. Il garde notre DA (sobre, verre sombre, TT Firs Neue, accent `#5d90ec`, pas de rose). Inspiration côté produit : 0Resmon (voir `claude/concurrent-0resmon.md` dans le projet). On s'inspire de leur façon de livrer, jamais de leur code ni de leurs visuels.

## 1. Langues : fr, en, es, de, ar
- `locales/fr.lua`, `en.lua`, `es.lua`, `de.lua`, `ar.lua`. Toutes les langues ont **les mêmes clés**. `en` sert de secours.
- `Config.Locale = 'fr'` par défaut, modifiable par le serveur.
- **Aucun texte en dur** dans le Lua, le JS ou le HTML : tout passe par `L('cle')` côté Lua. La NUI reçoit `GetLocaleTable()` au démarrage, par exemple dans un message `{ action = 'locale', data = ... }`, et remplit ses textes avec `data-i18n="cle"`.
- **Arabe** : `Locales.ar._rtl = true`. La NUI met alors `dir="rtl"` sur `<html>` et utilise une police qui affiche l'arabe en secours (`'TT Firs Neue', 'Segoe UI', Tahoma, sans-serif`). Il faut vérifier que la mise en page ne casse pas en RTL.
- Les noms d'objets, de métiers et de lieux qu'un serveur peut renommer restent dans `config.lua`, pas dans les fichiers de langue.
- Traductions naturelles et courtes, au tutoiement en fr, sans jargon. Mêmes `%s` et `%d`, dans le même ordre.

## 2. Compatibilité : n'importe quel serveur
- **Aucun appel direct** à ESX, QBCore, Qbox, ox_inventory, etc. en dehors de `bridge/`. Tout passe par `Bridge.*` (voir `docs/gabarit-pop.md`).
- `Config.Framework`, `Config.Inventory`, `Config.Target` et `Config.Notify` sont tous en `'auto'` par défaut. Frameworks : esx, qbcore, qbox, standalone. Ciblage : ox_target, qb-target, ou touche E si rien n'est installé.
- **Dépendances POP facultatives** : un script ne plante jamais si un autre `pop_*` est absent. On teste `GetResourceState('pop_x') == 'started'`, et sinon on garde un comportement simple. Le seul `dependency` obligatoire autorisé est `oxmysql`, quand une base de données est utilisée.
- **Base de données** : les tables sont créées au démarrage (`CREATE TABLE IF NOT EXISTS`). On fournit aussi `install/sql.sql`.
- **Objets** : `install/` contient la déclaration des objets pour ox_inventory (`items_ox.lua`), qb (`items_qb.lua`), ESX (`items_esx.sql`) et pop_inventory. Les images des objets sont dans `install/images/`.
- **Performance** : ~0,00 ms au repos. Pas de boucle à `Wait(0)` permanente, et `Wait` adapté à la distance.
- **Sécurité** : le serveur reste seul juge (argent, objets, distances). Chaque callback vérifie la source.

## 3. Livraison, à la manière des grosses boutiques
- `README.md` en **en + fr** : installation en 3 étapes, configuration, exports et événements.
- `config.lua` bien commenté (en anglais, avec le français entre parenthèses si utile), avec `Config.Debug`.
- Version à la fin du `fxmanifest` (`version '1.0.0'`).
- Si une boutique de vente est prévue : le `config.lua`, les `locales/` et le `bridge/` restent toujours ouverts (escrow_ignore).

## 4. Vérification avant de pousser
- `luacheck` sans nouvel avertissement, `luac5.4 -p` sur chaque fichier, `node --check` sur le JS.
- Pas de clé de langue manquante : `lua5.4 tools/check-locales.lua "resources/[pop]/pop_xxx"` doit afficher OK.
- Capture de la NUI en fr **et** en ar (RTL) pour le client.
- Test en jeu par le client sur ESX. Les autres frameworks sont vérifiés par lecture du code du bridge.
