-- Objets (3/5) : tazer, nourriture, outils, documents, électronique, cassettes.
-- Config.Items est rempli dans l'ordre par config/items_1.lua à items_5.lua.
Config.Items = Config.Items or {}

local items = {
  tazer = {
    label = 'Tazer',
    weight = 1.0,
    maxStack = 4,
    icon = 'img/tazer.webp',
    equipSlot = 'weapon_tazer',
    tags = { 'weapon', 'police' },
    gradientColor = 'rgba(88, 160, 60, 0.35)',
    weaponHash = 'WEAPON_STUNGUN',
  },
  flipper = {
    label = 'Flipper',
    weight = 0.2,
    maxStack = 2,
    icon = 'img/flipper.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  pcb = {
    label = 'Module pirate',
    weight = 0.2,
    maxStack = 2,
    icon = 'img/pcb.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  hotdog = {
    label = 'Hotdog',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/hotdog.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'hunger', 250000)
        TriggerClientEvent('esx_basicneeds:onEat', source)
        return true
    end,
  },
  jerry = {
    label = "Bidon D'essence",
    weight = 0.2,
    maxStack = 2,
    icon = 'img/jerry.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  soda = {
    label = 'Soda',
    weight = 0.35,
    maxStack = 5,
    icon = 'img/soda.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 200000)
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        return true
    end,
  },
  cola = {
    label = 'Cola',
    weight = 0.35,
    maxStack = 5,
    icon = 'img/cola.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(180, 50, 50, 0.350)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 200000)
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        return true
    end,
  },
  house_key = {
    label = 'Housing Key',
    weight = 0.01,
    maxStack = 1,
    icon = 'img/unknown.webp',
    tags = { 'misc' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  lockpick = {
    label = 'Lockpick',
    weight = 0.8,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'tool' },
    usable = true,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  police_barrier = {
    label = 'Police Barrier',
    weight = 0.3,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'police', 'tool' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  police_stormram = {
    label = 'Police Storm Ram',
    weight = 5.0,
    maxStack = 1,
    icon = 'img/unknown.webp',
    tags = { 'police', 'tool' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  pliers = {
    label = 'Pliers',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  insulating_tape = {
    label = 'Insulating Tape',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  weed = {
    label = 'Weed',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/weed.webp',
    tags = { 'drugs' },
    gradientColor = 'rgba(88, 160, 60, 0.45)',
  },

  pochon = {
    label = 'Pochon Vide',
    weight = 0.01,
    maxStack = 100,
    icon = 'img/pochon.webp',
    tags = { 'misc' },
    gradientColor = 'rgba(200, 200, 200, 0.40)',
  },
  pochonweed = {
    label = 'Pochon de Weed',
    weight = 0.06,
    maxStack = 50,
    icon = 'img/pochonweed.webp',
    tags = { 'drugs' },
    gradientColor = 'rgba(88, 160, 60, 0.55)',
    usable = true,
    onUse = function(source, itemData, itemDef)
        -- Active/désactive le mode "vente de drogue" (clients viennent à toi)
        local ok = pcall(function() exports.pop_dealing:toggleSelling(source) end)
        if not ok then
            Inv.NotifyTyped(source, {
                title = L('selling_title'), message = L('selling_unavailable'), type = 'error',
            })
        end
        return false -- ne pas consommer le pochon
    end,
  },
  plaque = {
    label = 'Plaque en métal',
    weight = 0.5,
    maxStack = 50,
    icon = 'img/plaque.webp',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  cylindre = {
    label = 'Cylindre en acier',
    weight = 0.8,
    maxStack = 20,
    icon = 'img/cylindre.webp',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  ressort = {
    label = 'Ressort en acier',
    weight = 0.1,
    maxStack = 50,
    icon = 'img/ressort.webp',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  newspaper = {
    label = 'Journal',
    weight = 0.2,
    maxStack = 20,
    icon = 'img/unknown.webp',
    weaponHash = 'WEAPON_ACIDPACKAGE',
    tags = { 'weapon' },
    gradientColor = 'rgba(240, 240, 240, 0.40)',
  },
  ciseaux = {
    label = 'Ciseaux',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/ciseaux.webp',
    usable = true,
    tags = { 'tools' },
    gradientColor = 'rgba(180, 180, 180, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useCiseaux', source)
        return false -- Do not consume the item directly
    end,
  },
  printer = {
    label = 'Imprimante',
    weight = 5.0,
    maxStack = 1,
    icon = 'img/printer.webp',
    usable = true,
    tags = { 'tools' },
    gradientColor = 'rgba(180, 180, 180, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('mt_printers:client:usePrinter', source, itemData)
        return false
    end,
  },
  paper = {
    label = 'Rame de papier',
    weight = 0.5,
    maxStack = 10,
    icon = 'img/paper.webp',
        gradientColor = 'rgba(180, 180, 180, 0.4)',
    tags = { 'misc' },
  },
  print_document = {
    label = 'Document imprimé',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/file.webp',
    gradientColor = 'rgba(180, 180, 180, 0.4)',
    usable = true,
    tags = { 'misc' },
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('mt_printers:client:useDocument', source, itemData)
        return false
    end,
  },
  tableau = {
    label = 'Châssis Entoilé',
    weight = 1.0,
    maxStack = 5,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'misc' },
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_boards:client:placement', source)
        return false
    end,
  },
  notepad = {
    label = 'Carnet',
    weight = 0.2,
    maxStack = 10,
    icon = 'img/notepad.webp',
    usable = true,
    tags = { 'misc' },
        gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('lkrp_notepad:note', source)
        TriggerClientEvent('lkrp_notepad:OpenNotepadGui', source, itemData)
        return false
    end,
  },
  pager = {
    label = 'Pager',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/pager.webp',
    equipSlot = Config.EnablePagerSlot and 'pager' or nil,
    tags = { 'communication' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, itemData, itemDef)
      exports['plt_pager']:openPager('usingItem', itemData, { id = source, owner = true }, itemData.id)
      return false
    end,
  },
  retrophone = {
    label = 'Téléphone Rétro',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/retrophone.webp',
    equipSlot = 'phone',
    tags = { 'communication' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, itemData, itemDef)
      exports['plt_retrophone']:openRetrophone('usingItem', itemData, { id = source, owner = true }, itemData.id)
      return false
    end,
  },
  walkman = {
    label = 'Walkman',
    weight = 0.3,
    maxStack = 1,
    icon = 'img/walkman.webp',
    tags = { 'misc' },
    usable = true,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
      exports['plt_walkman']:openWalkman('usingItem', itemData, { id = source, owner = true }, itemData.id)
      return false
    end,
  },
  polaroid_cam = {
    label = 'Polaroid Davis 1992',
    weight = 0.5,
    maxStack = 1,
    icon = 'img/polaroid_cam.webp',
    tags = { 'misc' },
    usable = true,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    clientEvent = 'polaroid:useCamera',
  },
  polaroid_card = {
    label = 'Photo Polaroid',
    weight = 0.01,
    maxStack = 10,
    icon = 'img/polaroid_card.webp',
    tags = { 'misc' },
    usable = true,
    gradientColor = 'rgba(230, 230, 230, 0.40)',
    clientEvent = 'polaroid:viewCard',
  },
  cassette_duz_it = {
    label = 'Cassette - Duz It',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  cassette_tnt = {
    label = 'Cassette - TNT',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  cassette_bad_boys = {
    label = 'Cassette - Bad Boys',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  cassette_smooth_criminal = {
    label = 'Cassette - Smooth Criminal',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  cassette_cant_c_me = {
    label = 'Cassette - Cant C Me',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  cassette_think_about_the_way = {
    label = 'Cassette - Think About The Way',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  cassette_get_a_way = {
    label = 'Cassette - Get A Way',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.webp',
    tags = { 'misc' },
  },
  composant_cassette = {
    label = 'Composant de Cassette',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.webp',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  bande_magnetique = {
    label = 'Bande Magnétique',
    weight = 0.02,
    maxStack = 100,
    icon = 'img/unknown.webp',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  kit_reparation_vegatech = {
    label = 'Kit de Réparation Vega Tech',
    weight = 0.8,
    maxStack = 10,
    icon = 'img/unknown.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },


}

for id, def in pairs(items) do
  Config.Items[id] = def
end
