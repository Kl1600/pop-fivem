-- TAB Doorlock | Doorbuilder edition --

Config = {}

Config.Translate = {									-- Messages | personnalise ici
	['opened_door'] = 'Porte déverrouillée',
	['closed_door'] = 'Porte verrouillée',
	['employes_only'] = 'Réservé au personnel autorisé !',
	['need_key'] = 'Il vous faut la bonne clé.',
	-- Doorbuilder
	['builder_open'] = 'Doorbuilder ouvert.',
	['builder_no_perm'] = 'Vous n\'avez pas la permission.',
	['builder_select'] = 'Mode sélection : visez les portes.',
	['builder_added'] = 'Porte ajoutée à la sélection (%s).',
	['builder_removed'] = 'Porte retirée de la sélection (%s restantes).',
	['builder_already'] = 'Cette porte est déjà sélectionnée.',
	['builder_not_door'] = 'Aucune porte visée.',
	['builder_empty'] = 'Aucune porte sélectionnée.',
	['builder_saved'] = 'Groupe "%s" enregistré (%s porte(s)).',
	['builder_cancel'] = 'Doorbuilder annulé.',
	['builder_deleted'] = 'Groupe "%s" supprimé.',
	['builder_delete_fail'] = 'Suppression impossible (groupe statique ?).',
	['key_received'] = 'Clé reçue pour "%s".',
	['key_regenerated'] = 'Clé régénérée pour "%s" (les anciennes clés ne fonctionnent plus).',
	['key_fail'] = 'Impossible de recevoir la clé.',
	['builder_group_emptied'] = 'Le groupe ne contient plus aucune porte, il a été retiré.',
}

-- =====================================================================
--  DOORBUILDER / ADMIN
--  Le menu s'ouvre depuis pop_admin (onglet "Portes") -> aucune commande.
-- =====================================================================

-- UN SEUL item clé pour toutes les portes (le groupe ouvert est dans meta.doorgroup).
-- Doit correspondre à l'item défini dans pop_inventory/config.lua (Config.Items.cle).
Config.KeyItem = 'cle'

-- Permissions admin (même logique que pop_admin)
Config.AdminGroups = {									-- Groupes ESX autorisés
	['owner']      = true,
	['superadmin'] = true,
	['admin']      = true,
	['mod']        = false,
}
Config.AcePermissions = { 'group.admin' }				-- ACE autorisées
Config.AdminIdentifiers = { }							-- ex: { 'license:xxxxx' } accès forcé

-- Touches du mode builder (index des controls FiveM)
Config.Builder = {
	SelectKey  = 38,									-- E    : sélectionner / désélectionner la porte visée
	ValidateKey = 191,									-- ENTER: valider et ouvrir le menu d'attribution de clé
	CancelKey  = 73,									-- X    : annuler le mode builder
	RayDistance = 12.0,									-- portée du raycast (mètres)
	MarkerColor = { r = 235, g = 235, b = 235 },		-- couleur marqueur porte visée (neutre, comme le thème admin)
	SelectedColor = { r = 120, g = 200, b = 160 },		-- couleur marqueur porte sélectionnée (vert accent admin)
}

Config.ESX_Notify = false								-- If you want to use ESX notify | current true | if false add at bottom whatever notify you have
Config.Custom_Notify = function(Text, Time, Type)
	
end

Config.Doors = {
	--[[
	{
		Doors = {										-- Doors section | if you have more than one door to lock add it here
			{
				Model = 'v_ilev_ph_gendoor004',			-- Door model can be the model name or model hash = 'v_ilev_ph_gendoor004' or 1557126584
				Coords = vector3(449.6, -986.4, 30.6)	-- Door Coords | you can use the script pun_idgun to check door model and coords see https://github.com/Puntherline/pun_idgun
			}
		},
		Locked = true,									-- The door should be locked when script starts?
		Distance = 2,									-- Distance between player and doors to open them should be more than 0

		Jobs = 'police',

		-- Key  = 'grp_xxx'  -- (Doorbuilder) id stable du groupe : la porte exige l'item
		--                       'cle' avec meta.doorgroup == cette valeur. Rempli AUTOMATIQUEMENT
		--                       par le Doorbuilder, ne pas remplir à la main.
		-- Item = false        -- (legacy) item simple vérifié via getItemCount (sans métadonnée).

		--------------------------------
		-- Priorité d'accès : Key (clé à métadonnée) > Item (legacy) > Jobs
		-- Jobs : false = tout le monde | true = personne | 'police' ou { 'police', 'ambulance' }
		-- Les portes créées via le Doorbuilder utilisent toujours Key (un seul item 'cle').
		--------------------------------
	},
	]]--
    --[[
        Police
    ]]--
    -- Entrance

    -- Armory
    {
        Doors = {
            {
                Model = -73517283,
                Coords = vector3(734.7291, -1291.0088, 26.2889)
            }
        },
        Locked = true,
        Distance = 4,

        Jobs = false
    },

        {
        Doors = {
            {
                Model = -73517283,
                Coords = vector3(859.1122, -2367.1028, 32.8112)
            }
        },
        Locked = true,
        Distance = 4,

        Jobs = false -- Tout le monde peut l'utiliser avec le code
    },

    

    -- Nouveau Keypad Warehous
}
