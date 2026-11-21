-- Français
Locales['fr'] = {
    -- Kit commun (ne pas supprimer)
    cancel             = 'Annuler',
    confirm            = 'Confirmer',
    close              = 'Fermer',
    interact           = 'Interagir',
    progress_cancelled = 'Action annulée',
    no_permission      = "Vous n'avez pas la permission",
    wrong_job          = "Vous n'avez pas le métier requis",
    too_far            = 'Vous êtes trop loin',
    not_enough_money   = "Pas assez d'argent",
    missing_item       = 'Il vous faut : %s',
    inventory_full     = 'Votre inventaire est plein',
    cooldown           = 'Patientez encore %s s',
    busy               = 'Vous êtes déjà occupé',
    error              = 'Une erreur est survenue',

    -- Textes propres au script :
    -- Mode vente (pop_territories repère « Vente activ » / « repère les clients » : ne pas changer ces mots)
    selling_stopped     = 'Vente arrêtée.',
    selling_no_drug     = "Tu n'as aucune drogue à vendre.",
    selling_started     = 'Vente activée — repère les clients sur la carte et va les voir.',
    selling_out_of_stock = 'Plus de drogue en stock — mode vente coupé.',
    selling_last_sold   = 'Dernier pochon vendu — vente terminée.',

    -- Deal
    customer_busy       = "Ce client discute déjà avec quelqu'un.",
    not_enough_drug     = 'Pas assez de %s (%d/%d).',
    deal_inventory_full = 'Inventaire plein, deal annulé.',
    deal_done_title     = 'Deal conclu',
    deal_done_message   = 'Vendu : <b>%d %s</b> pour <b>$%d</b>',
    bust_title          = 'PIÈGE !',
    bust_message        = 'Ce client était un flic infiltré...',
    bust_badge          = 'BUST',
    alert_title         = 'Signalement',
    alert_badge         = 'POLICE',
    alert_label         = 'Deal de drogue suspect (%s)',
    unknown_place       = '?',

    -- Client (PNJ)
    prompt_key          = 'GLISSER',
    prompt_default      = 'Marchandise',
    blip_default        = 'Client',

    -- Commandes admin
    admin_ingame_only   = '[pop_dealing] à utiliser en jeu',
    admin_spawned       = 'Client spawn #%d : %s x%d (hint $%d/u, max $%d/u)',
    admin_list_line     = '[pop_dealing] #%d zone=%d drug=%s x%d max=$%d/u claimed=%s coords=%.1f,%.1f,%.1f',
    admin_list_empty    = '[pop_dealing] aucun client actif',
    admin_cleared       = 'Tous les clients supprimés.',
}
