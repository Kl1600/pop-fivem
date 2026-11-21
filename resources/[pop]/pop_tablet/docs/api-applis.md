# pop_tablet : API d'applis

Contrat pour les autres ressources qui ajoutent une appli à la tablette, envoient une notification ou ouvrent une appli.
Ressource : `pop_tablet`. Les exports serveur sont appelés par `exports.pop_tablet:<Nom>(...)`. Une ressource qui s'arrête voit ses applis retirées (`onResourceStop`) : les tablettes ouvertes reçoivent `pop_tablet:client:apps`.

## 1. Enregistrer une appli : `RegisterApp` (serveur)

```lua
exports.pop_tablet:RegisterApp({
    id        = 'police_mdt',          -- obligatoire : [a-z0-9_]{3,32}, unique ; préfixer par la ressource
    nameKey   = 'mdt_name',            -- clé de locale de la ressource appelante ; sinon `name` (texte brut, évité)
    name      = nil,
    icon      = 'icon.svg',            -- fichier SVG/PNG de la ressource (nui://<ressource>/<chemin>) ou nom d'icône du jeu d'icônes POP
    color     = '#0a84ff',             -- fond de l'icône (facultatif)
    page      = 'nui://pop_police/web/mdt.html', -- page affichée dans un cadre de la tablette
    jobs      = { 'police', sheriff = 2 },       -- facultatif ; même format que Bridge.HasJob ; absent = tous
    store     = true,                  -- visible dans la Boutique (défaut true) ; false = installée d'office
    category  = 'work',                -- libre, Boutique
    onCall    = function(src, serial, action, data) return { ok = true } end, -- facultatif, voir section 4
})
-- retour : true, ou false, 'raison' (id invalide, doublon, page hors ressource appelante...)
```

Règles vérifiées par POP :
- `id` unique ; un doublon d'une autre ressource est refusé.
- `page` doit commencer par `nui://<ressource appelante>/` (`GetInvokingResource()`), ou `https://` listé dans `Config.Browser.AllowedHosts`. La page doit être déclarée dans les `files` du `fxmanifest` de la ressource appelante.
- `jobs` est contrôlé **côté serveur** à l'installation, à l'ouverture et à chaque `onCall` (`Bridge.HasJob`), jamais côté client seulement.
- Aucune boucle côté POP : l'appli n'existe que dans un tableau en mémoire.

Retirer : `exports.pop_tablet:UnregisterApp(id)` (aussi automatique à l'arrêt de la ressource).

## 2. Notification : `Notify` (serveur)

```lua
exports.pop_tablet:Notify(target, {
    app     = 'police_mdt',        -- appli d'origine (icône, ouverture au toucher) ; ou une appli native ('messages')
    titleKey = 'mdt_alert_title',  -- clé de locale de la ressource appelante, ou title (texte brut)
    bodyKey  = 'mdt_alert_body',
    args     = { 'Mission Row' },  -- arguments de formatage (<= 4, chaînes/nombres)
    sound    = true,               -- facultatif
})
```

- `target` : un `source` (joueur) **ou** un `serial` de tablette (`'PT-...'`). Un source est notifié seulement s'il porte une tablette (la première) ; un serial seulement si son porteur est en ligne.
- Retour : `true` si une tablette a été notifiée, `false` sinon.
- Les textes sont des clés : la **tablette** les traduit dans sa langue. Les clés doivent exister dans `Locales[<langue>]` de la ressource appelante ; l'appelante envoie aussi ses textes via `texts = { en = '...', fr = '...' }` si elle n'a pas de locales partagées avec la tablette (repli : `title`/`body` en texte brut).
- Limites : titre <= 60 car., corps <= 200 car. ; 5 notifications par seconde et par ressource ; au-delà, rejet silencieux (journal en `Config.Debug`).

## 3. Ouvrir une appli : `OpenApp`

Serveur : `exports.pop_tablet:OpenApp(src, appId, data?)` : le serveur vérifie que le joueur porte une tablette et que l'appli est installée/autorisée, puis envoie `pop_tablet:client:open`. Si la tablette est verrouillée, elle s'ouvre sur l'écran de code puis sur l'appli. `data` : table <= 2 Ko transmise à l'appli (`data.open`).
Client : `exports.pop_tablet:OpenApp(appId, data?)` : demande au serveur (même contrôles) ; ne contourne jamais le code.

Autres exports :
- serveur `GetSerial(src)` : serial de la tablette utilisée par `src` (session) ou `nil`.
- serveur `RegisterSite({ domain, title, page })` : site du Navigateur (`pop://<domain>`), mêmes règles que `page`.
- serveur `MarketShock(symbol, pct)` : choc sur un cours de la Bourse (`|pct| <= 25`).
- client `IsOpen()`, `Close()`.

## 4. Appel de l'appli vers sa ressource : `onCall`

La page de l'appli appelle la ressource par la tablette :

```js
// dans la page de l'appli (nui://...), via la bibliothèque injectée par la tablette
window.parent.postMessage({ type: 'pop-app:call', appId: 'police_mdt', action: 'search', data: { q: 'x' }, id: 12 }, '*')
// réponse : { type: 'pop-app:result', id: 12, ok: true, data: ... }
```

La tablette relaie vers `pop_tablet:app:call` (7.2 de SPEC) puis exécute `onCall(src, serial, action, data)` côté serveur. Contrôles faits par POP avant `onCall` : objet porté, session déverrouillée, appli installée, job, taille <= 4 Ko, anti-spam. **`onCall` doit revérifier ses propres règles** (permissions métier, distance). `onCall` retourne une table <= 16 Ko, sinon rejet.
La page peut aussi recevoir : `{ type: 'pop-app:event', name, data }` (push de la ressource via `exports.pop_tablet:AppEvent(src, appId, name, data)`, <= 2 Ko, seulement si l'appli est ouverte).

## 5. Contexte donné à la page de l'appli

Au chargement, la page reçoit `{ type: 'pop-app:init', layout: 'regular' | 'compact', dark: bool, accent, locale, rtl, data }` : elle applique le thème et la langue de **la tablette**. La mise en page `compact` sert au futur téléphone.

## 6. Sécurité et performance de l'API

- Une appli API tourne dans un cadre isolé (`iframe sandbox="allow-scripts"` sans accès au DOM parent) : elle ne lit pas les autres applis.
- Aucune donnée de la tablette (code, notes, messages) n'est exposée aux applis API ; elles reçoivent seulement `serial`, le job et leurs propres données.
- Aucune requête, minuterie ni boucle de POP pour une appli API au repos : 0,00 ms.
- L'appli n'a aucune permission supplémentaire : pas de caméra, pas de micro, pas d'accès aux photos.

## 7. Versionnage

`exports.pop_tablet:GetApiVersion()` renvoie `1`. Ajouts compatibles = même version ; changement cassant = version + 1 et période de dépréciation écrite dans ce fichier.
