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
    -- Carte (menu pause)
    map_controlled      = 'Contrôlé par %s — %d%%',
    map_disputed        = 'Disputé · %s en tête — %d%%',
    map_uncontrolled    = '%s — territoire non contrôlé',
    map_war_tag         = '  [GUERRE]',

    -- Notifications de crew
    war_title           = 'Guerre de territoire',
    war_defender        = '%s attaque votre territoire %s !',
    war_attacker        = "Vous lancez l'assaut sur %s (tenu par %s).",
    unknown_crew        = '?',
    territory_title     = 'Territoire',
    crew_took_control   = 'Votre crew contrôle désormais %s !',

    -- Commande /territory
    cmd_no_zone         = "Tu n'es dans aucun territoire.",
    cmd_normal_zone     = '%s — zone normale (pas de vente)',
    cmd_deal_zone       = '%s — vente x%.2f — contrôle: %s%s',
    cmd_war_tag         = ' [EN GUERRE]',
    cmd_no_controller   = 'aucun',

    -- Debug (Config.Debug)
    debug_title         = '[DEBUG] Territoire',
    debug_outside       = 'Hors territoire — vente sans zone',
    debug_not_deal_zone = 'Zone %s détectée MAIS dealZone=false',
    debug_no_crew       = "Zone %s OK mais tu n'as PAS de crew !",
    debug_share_saved   = '[DEBUG] Part enregistrée',
    debug_share_cooldown = '[DEBUG] Cooldown (pas de part)',
    debug_share_line    = 'Zone %s | Crew %s | Part: %.0f%% | Contrôle: %s',
    debug_control_yes   = 'OUI ✓',
    debug_control_no    = 'non',
}
