# pop_notify

Notifications POP. Aucun framework requis.

## Utilisation
| Appel | Côté | Rôle |
|---|---|---|
| `exports.pop_notify:ShowNotify({ title, message, image, logo, icon, duration })` | client | affiche une notification |
| `TriggerClientEvent('notification:client:ShowNotify', src, data)` | serveur | idem depuis le serveur |
| `TriggerEvent('notification:client:checklist', { type = 'show'\|'reset'\|'step', ... })` | client | checklist persistante (livraisons) |
| `TriggerEvent('notification:client:setRaised', state, bottom)` | client | décale la pile vers le haut |

Les scripts au gabarit POP passent par `Bridge.Notify(...)`, qui appelle `ShowNotify` automatiquement.

Fichiers : `client.lua` (export et évènements), `html/` (affichage). Relancer : `restart pop_notify`.

---

# Custom Notifications Integration / Intégration des Notifications Custom

- 🇫🇷 [Version Française](#version-française)
- 🌍 [English Version](#english-version)

---

## Version Française

Ce guide vous explique comment remplacer définitivement les anciens systèmes de notification natifs (ESX, QBCore, ox_lib) par ce script de `notification`. Ainsi, tous les scripts de votre serveur utiliseront automatiquement ce nouveau design sans que vous ayez à les modifier un par un.

### 1. Remplacer les notifications ESX (`es_extended`)

Dans ESX, les notifications s'affichent soit par l'appel à la fonction interne, soit par un événement réseau.

#### Modifer la fonction `ESX.ShowNotification`
📍 **Chemin du fichier :** `es_extended/client/functions.lua` (ou la ressource qui gère votre core ESX)

Cherchez la fonction `ESX.ShowNotification` (souvent vers le bas du fichier) et remplacez l'intérieur :

```lua
ESX.ShowNotification = function(message)
    exports['pop_notify']:ShowNotify({
        message = message,
        duration = 5000,
        icon = "fas fa-info" -- Optionnel: icône par défaut
    })
end
```

#### Modifer l'événement réseau `esx:showNotification`
📍 **Chemin du fichier :** `es_extended/client/main.lua` ou `events.lua`

Trouvez l'événement `esx:showNotification` et remplacez le code à l'intérieur :

```lua
RegisterNetEvent('esx:showNotification')
AddEventHandler('esx:showNotification', function(message)
    exports['pop_notify']:ShowNotify({
        message = message,
        duration = 5000
    })
end)
```

*(Pensez à faire la même chose pour `esx:showAdvancedNotification` si vous souhaitez utiliser l'affichage des alertes complexes)*.

---

### 2. Remplacer les notifications QBCore (`qb-core`)

Dans QBCore, les notifications sont gérées par une fonction centrale.

📍 **Chemin du fichier :** `qb-core/client/functions.lua`

Cherchez la fonction `QBCore.Functions.Notify` et remplacez-la entièrement par ceci :

```lua
function QBCore.Functions.Notify(text, textype, length)
    local icon = "fas fa-info"
    
    -- Change l'icône selon le type envoyé par QBCore
    if textype == "error" then
        icon = "fas fa-circle-exclamation"
    elseif textype == "success" then
        icon = "fas fa-check"
    elseif textype == "primary" then
        icon = "fas fa-info"
    end
    
    exports['pop_notify']:ShowNotify({
        message = text,
        duration = length or 5000,
        icon = icon
    })
end
```

---

### 3. Remplacer les notifications Overextended (`ox_lib`)

Beaucoup de scripts modernes utilisent `lib.notify` d'`ox_lib`. Pour rediriger ces appels vers votre script :

📍 **Chemin du fichier :** `[ox]/ox_lib/imports/notify/client.lua` (ou l'endroit où la logique client de notify est gérée dans ox_lib)

Cherchez la fonction d'export `lib.notify` ou l'event associé et remplacez son comportement par :

```lua
function lib.notify(data)
    -- Détermine l'icône par rapport au type ox_lib
    local defaultIcon = "fas fa-info"
    if data.type == "error" then 
        defaultIcon = "fas fa-circle-exclamation"
    elseif data.type == "success" then 
        defaultIcon = "fas fa-check" 
    elseif data.type == "warning" then 
        defaultIcon = "fas fa-info" 
    end

    -- Si ox_lib envoie une icône custom, on essaye de l'utiliser
    if data.icon then 
        defaultIcon = "fas fa-" .. data.icon 
    end

    exports['pop_notify']:ShowNotify({
        title = data.title,
        message = data.description or data.message or "Notification",
        duration = data.duration or 5000,
        icon = defaultIcon
    })
end
```

### 💡 Note Importante (FR)
Si vous apportez ces modifications, **assurez-vous toujours que la ressource `notification` démarre avant** (soit au-dessus dans le `server.cfg`) les frameworks (`es_extended`, `qb-core`, `ox_lib`) ou juste après si vous ne pouvez pas faire autrement, pour que l'export soit bien reconnu dès le lancement.

---

### 4. Créer des Notifications Spéciales (Client-Side)

Vous pouvez utiliser tout le potentiel du design en passant d'autres paramètres pour créer des notifications complexes ou personnalisées directement depuis n'importe quel script client.

**Exemple de Notification Avancée :**
```lua
exports['pop_notify']:ShowNotify({
    title = "Braquage en cours",       -- Titre de la notification
    message = "Showroom Benefactor",   -- Message principal
    icon = "fas fa-shield-halved",     -- Icône FontAwesome associée
    badge = "NIVEAU 2",                -- Texte du badge en haut à droite
    badgeColor = "#e74c3c",            -- Couleur du badge
    sideText = "3.2km",                -- Texte additionnel discret
    duration = 8000                    -- Durée en millisecondes
})
```

**Exemple avec Logo :**
```lua
exports['pop_notify']:ShowNotify({
    logo = "LIEN_VERS_IMAGE.jpg",      -- URL de l'image (logo complet)
    title = "Banque",
    message = "Votre salaire a été déposé.",
    duration = 7000
})
```

**Exemple avec Grande Image (Concessionnaire) :**
```lua
exports['pop_notify']:ShowNotify({
    title = "CONCESSIONNAIRE",
    message = "La nouvelle voiture est disponible !",
    image = "LIEN_VERS_IMAGE.png",     -- URL d'une grande image
    duration = 7000
})
```

### 5. Envoyer une Notification depuis le Serveur (Server-Side)

Pour afficher une notification sur le client depuis un script serveur, utilisez l'événement pré-enregistré `notification:client:ShowNotify` :

```lua
-- Envoyer à un joueur spécifique (remplacez 'source' par l'ID du joueur)
TriggerClientEvent('notification:client:ShowNotify', source, {
    message = "Ceci est une notification serveur !",
    duration = 5000,
    icon = "fas fa-server"
})

-- Envoyer à tous les joueurs
TriggerClientEvent('notification:client:ShowNotify', -1, {
    title = "Annonce Serveur",
    message = "Redémarrage dans 10 minutes.",
    icon = "fas fa-triangle-exclamation",
    duration = 10000
})
```

---
---

## English Version

This guide explains how to permanently replace the old native notification systems (ESX, QBCore, ox_lib) with this `notification` script. Thus, all scripts on your server will automatically use this new design without you having to modify them one by one.

### 1. Replace ESX notifications (`es_extended`)

In ESX, notifications are displayed either by calling the internal function or by a network event.

#### Modify the `ESX.ShowNotification` function
📍 **File Path:** `es_extended/client/functions.lua` (or the resource that manages your ESX core)

Find the `ESX.ShowNotification` function (often near the bottom of the file) and replace what's inside:

```lua
ESX.ShowNotification = function(message)
    exports['pop_notify']:ShowNotify({
        message = message,
        duration = 5000,
        icon = "fas fa-info" -- Optional: default icon
    })
end
```

#### Modify the `esx:showNotification` network event
📍 **File Path:** `es_extended/client/main.lua` or `events.lua`

Find the `esx:showNotification` event and replace the code inside:

```lua
RegisterNetEvent('esx:showNotification')
AddEventHandler('esx:showNotification', function(message)
    exports['pop_notify']:ShowNotify({
        message = message,
        duration = 5000
    })
end)
```

*(Remember to do the same for `esx:showAdvancedNotification` if you want to use the display of complex alerts).*

---

### 2. Replace QBCore notifications (`qb-core`)

In QBCore, notifications are managed by a central function.

📍 **File Path:** `qb-core/client/functions.lua`

Find the `QBCore.Functions.Notify` function and replace it entirely with this:

```lua
function QBCore.Functions.Notify(text, textype, length)
    local icon = "fas fa-info"
    
    -- Change the icon depending on the type sent by QBCore
    if textype == "error" then
        icon = "fas fa-circle-exclamation"
    elseif textype == "success" then
        icon = "fas fa-check"
    elseif textype == "primary" then
        icon = "fas fa-info"
    end
    
    exports['pop_notify']:ShowNotify({
        message = text,
        duration = length or 5000,
        icon = icon
    })
end
```

---

### 3. Replace Overextended notifications (`ox_lib`)

Many modern scripts use `lib.notify` from `ox_lib`. To redirect these calls to your script:

📍 **File Path:** `[ox]/ox_lib/imports/notify/client.lua` (or wherever the notify client logic is handled in ox_lib)

Find the `lib.notify` export function or associated event and replace its behavior with:

```lua
function lib.notify(data)
    -- Determine the icon based on the ox_lib type
    local defaultIcon = "fas fa-info"
    if data.type == "error" then 
        defaultIcon = "fas fa-circle-exclamation"
    elseif data.type == "success" then 
        defaultIcon = "fas fa-check" 
    elseif data.type == "warning" then 
        defaultIcon = "fas fa-info" 
    end

    -- If ox_lib sends a custom icon, we try to use it
    if data.icon then 
        defaultIcon = "fas fa-" .. data.icon 
    end

    exports['pop_notify']:ShowNotify({
        title = data.title,
        message = data.description or data.message or "Notification",
        duration = data.duration or 5000,
        icon = defaultIcon
    })
end
```

### 💡 Important Note (EN)
If you make these changes, **always make sure that the `notification` resource starts before** (i.e. above in the `server.cfg`) the frameworks (`es_extended`, `qb-core`, `ox_lib`), or right after if you can't do otherwise, so that the export is correctly recognized upon startup.

---

### 4. Create Special Notifications (Client-Side)

You can use the full potential of the design by passing additional parameters to create complex or custom notifications directly from any client script.

**Example of an Advanced Notification:**
```lua
exports['pop_notify']:ShowNotify({
    title = "Robbery in Progress",     -- Notification Title
    message = "Benefactor Showroom",   -- Main Message
    icon = "fas fa-shield-halved",     -- Associated FontAwesome icon
    badge = "LEVEL 2",                 -- Badge text on the top right
    badgeColor = "#e74c3c",            -- Badge background color
    sideText = "3.2km",                -- Additional discrete text
    duration = 8000                    -- Duration in milliseconds
})
```

**Example with a Logo:**
```lua
exports['pop_notify']:ShowNotify({
    logo = "LINK_TO_IMAGE.jpg",        -- URL of the image (replaces icon)
    title = "Bank",
    message = "Your salary has been deposited.",
    duration = 7000
})
```

**Example with a Big Image (Dealership):**
```lua
exports['pop_notify']:ShowNotify({
    title = "DEALERSHIP",
    message = "The new car is available!",
    image = "LINK_TO_IMAGE.png",       -- URL of a large image
    duration = 7000
})
```

### 5. Send a Notification from the Server (Server-Side)

To display a notification on the client from a server script, use the pre-registered event `notification:client:ShowNotify`:

```lua
-- Send to a specific player (replace 'source' with the player's ID)
TriggerClientEvent('notification:client:ShowNotify', source, {
    message = "This is a server notification!",
    duration = 5000,
    icon = "fas fa-server"
})

-- Send to all players
TriggerClientEvent('notification:client:ShowNotify', -1, {
    title = "Server Announcement",
    message = "Restart in 10 minutes.",
    icon = "fas fa-triangle-exclamation",
    duration = 10000
})
```
