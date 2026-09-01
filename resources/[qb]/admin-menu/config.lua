Config = {}

-- Touche par défaut pour ouvrir le menu administration.
-- Le joueur pourra la changer lui-même dans :
-- Échap -> Paramètres -> Touches -> onglet "FiveM" -> chercher "Menu administration"
Config.DefaultKey = 'F6'

-- Commande utilisée en interne pour ouvrir/fermer le menu (liée à la touche ci-dessus)
Config.CommandName = 'adminmenu'

-- Groupes autorisés à ouvrir le menu (groupes QBCore : 'admin', 'god', ...)
Config.AllowedGroups = {
    ['admin'] = true,
    ['god'] = true,
}

-- Touche pour activer/désactiver le noclip (rebindable dans Paramètres > Touches > FiveM,
-- comme la touche du menu). Ne fonctionne que si le "mode admin" est coché dans le menu.
Config.NoclipKey = 'F7'
Config.NoclipCommand = 'togglenoclip'

-- Vitesse de déplacement en noclip (ajustable à la molette de la souris en jeu)
Config.NoclipSpeed = 8.0      -- vitesse de départ (nettement plus rapide que la marche)
Config.NoclipSpeedMin = 2.0   -- vitesse minimum
Config.NoclipSpeedMax = 60.0  -- vitesse maximum
Config.NoclipSpeedStep = 2.0  -- incrément à chaque cran de molette
Config.NoclipSpeedBoost = 2.0 -- multiplicateur en maintenant Shift (en plus de la vitesse réglée à la molette)

--------------------------------------------------------------------------
-- ONGLET "PNJ" : catalogue de modèles proposés dans le menu déroulant.
-- Cette liste ne sert qu'à peupler le menu déroulant (le "catalogue" de
-- PNJ disponibles) — les PNJ que vous placez en jeu, eux, sont enregistrés
-- en base de données et n'ont besoin d'aucune modification de fichier.
-- Pour ajouter un modèle au catalogue plus tard, il suffit d'ajouter une
-- ligne ici (label = nom affiché, model = nom technique GTA du ped).
--------------------------------------------------------------------------
Config.PedModels = {

    -------------------------------------------------------------
    -- Commerces / métiers de service (les plus utiles pour des magasins)
    -------------------------------------------------------------
    { label = "Vendeur (boutique générique)",           model = "mp_m_shopkeep_01" },
    { label = "Employé Ammu-Nation (homme)",            model = "s_m_y_ammucity_01" },
    { label = "Employée Ammu-Nation (femme)",           model = "s_f_y_ammucity_01" },
    { label = "Vendeur boutique de vêtements",          model = "s_m_y_shop_mask" },
    { label = "Vendeuse boutique chic",                 model = "s_f_y_shop_low" },
    { label = "Vendeur ambulant / stand de rue",        model = "s_m_y_strvend_01" },
    { label = "Barman",                                 model = "s_m_y_barman_01" },
    { label = "Serveur (restaurant)",                   model = "s_m_y_waiter_01" },
    { label = "Chef cuisinier",                         model = "s_m_y_chef_01" },
    { label = "Cuisinier (fast-food)",                  model = "s_m_m_linecook" },
    { label = "Coiffeur",                               model = "s_m_y_hairdresser_01" },
    { label = "Coiffeuse",                              model = "s_f_y_hairdresser_01" },
    { label = "Voiturier (valet)",                      model = "s_m_y_valet_01" },
    { label = "Employé de banque",                      model = "ig_bankman" },
    { label = "Employé bureau FIB / assurance (homme)", model = "s_m_m_fiboffice_01" },
    { label = "Employée bureau FIB / assurance (femme)",model = "s_f_m_fiboffice_01" },
    { label = "Croupier / casino",                      model = "s_m_y_casino_01" },
    { label = "Gérant de bar (mature)",                 model = "s_m_m_cntrybar_01" },
    { label = "Videur / bouncer",                       model = "s_m_m_bouncer_01" },
    { label = "Agent de sécurité",                      model = "s_m_m_security_01" },
    { label = "Agent de sécurité renforcée",            model = "s_m_m_highsec_01" },
    { label = "Femme de ménage (hôtel)",                model = "s_m_y_winclean_01" },
    { label = "Concierge / homme à tout faire",         model = "s_m_m_lathandy_01" },
    { label = "Jardinier",                              model = "s_m_y_gardener_01" },
    { label = "Jardinier (mature)",                     model = "s_m_m_gardener_01" },

    -------------------------------------------------------------
    -- Mécanique / industrie / manutention
    -------------------------------------------------------------
    { label = "Mécanicien (atelier)",                   model = "s_m_y_xmech_01" },
    { label = "Mécanicien (tenue propre)",              model = "s_m_y_xmech_02" },
    { label = "Mécanicien (auto shop, homme)",          model = "s_m_m_autoshop_01" },
    { label = "Mécanicien (auto shop, homme 2)",        model = "s_m_m_autoshop_02" },
    { label = "Ouvrier chantier (jeune)",                model = "s_m_y_construct_01" },
    { label = "Ouvrier chantier (jeune 2)",              model = "s_m_y_construct_02" },
    { label = "Docker / manutention",                    model = "s_m_y_dockwork_01" },
    { label = "Docker / manutention (mature)",           model = "s_m_m_dockwork_01" },
    { label = "Ouvrier d'usine",                         model = "s_m_y_factory_01" },
    { label = "Routier / camionneur",                    model = "s_m_m_trucker_01" },
    { label = "Ouvrier des espaces verts",               model = "s_m_m_gaffer_01" },

    -------------------------------------------------------------
    -- Bureau / affaires (utiles pour réception, accueil, entreprise)
    -------------------------------------------------------------
    { label = "Employé de bureau (homme)",               model = "a_m_m_business_01" },
    { label = "Employé de bureau jeune (homme)",         model = "a_m_y_business_01" },
    { label = "Employé de bureau jeune (homme 2)",       model = "a_m_y_business_02" },
    { label = "Employé de bureau jeune (homme 3)",       model = "a_m_y_business_03" },
    { label = "Employée de bureau jeune (femme)",        model = "a_f_y_business_01" },
    { label = "Employée de bureau jeune (femme 2)",      model = "a_f_y_business_02" },
    { label = "Employée de bureau jeune (femme 3)",      model = "a_f_y_business_03" },
    { label = "Employée de bureau jeune (femme 4)",      model = "a_f_y_business_04" },
    { label = "Cadre chic Beverly Hills (homme)",        model = "a_m_m_bevhills_01" },
    { label = "Cadre chic Beverly Hills (homme 2)",      model = "a_m_m_bevhills_02" },
    { label = "Femme chic Beverly Hills",                model = "a_f_m_bevhills_01" },
    { label = "Femme chic Beverly Hills (2)",            model = "a_f_m_bevhills_02" },

    -------------------------------------------------------------
    -- Passants / ambiance générale (hommes)
    -------------------------------------------------------------
    { label = "Passant décontracté (jeune)",             model = "a_m_y_genstreet_01" },
    { label = "Passant décontracté (jeune 2)",           model = "a_m_y_genstreet_02" },
    { label = "Passant centre-ville (jeune)",            model = "a_m_y_downtown_01" },
    { label = "Passant hipster (1)",                     model = "a_m_y_hipster_01" },
    { label = "Passant hipster (2)",                     model = "a_m_y_hipster_02" },
    { label = "Passant hipster (3)",                     model = "a_m_y_hipster_03" },
    { label = "Passant plage",                           model = "a_m_y_beach_01" },
    { label = "Passant plage (2)",                       model = "a_m_y_beach_02" },
    { label = "Passant Vinewood (1)",                    model = "a_m_y_vinewood_01" },
    { label = "Passant Vinewood (2)",                    model = "a_m_y_vinewood_02" },
    { label = "Passant Vinewood (3)",                    model = "a_m_y_vinewood_03" },
    { label = "Passant golfeur",                         model = "a_m_y_golfer_01" },
    { label = "Passant cycliste",                        model = "a_m_y_cyclist_01" },
    { label = "Passant randonneur",                      model = "a_m_y_hiker_01" },
    { label = "Passant motard motocross",                model = "a_m_y_motox_01" },
    { label = "Passant fermier / rural",                 model = "a_m_m_farmer_01" },
    { label = "Passant campagnard",                      model = "a_m_m_hillbilly_01" },
    { label = "Passant campagnard (2)",                  model = "a_m_m_hillbilly_02" },
    { label = "Passant touriste",                        model = "a_m_m_tourist_01" },
    { label = "Passant tennisman",                       model = "a_m_m_tennis_01" },

    -------------------------------------------------------------
    -- Passantes / ambiance générale (femmes)
    -------------------------------------------------------------
    { label = "Passante décontractée (1)",               model = "a_f_y_genhot_01" },
    { label = "Passante centre-ville",                   model = "a_f_y_downtown_01" },
    { label = "Passante hipster (1)",                    model = "a_f_y_hipster_01" },
    { label = "Passante hipster (2)",                    model = "a_f_y_hipster_02" },
    { label = "Passante hipster (3)",                    model = "a_f_y_hipster_03" },
    { label = "Passante plage",                          model = "a_f_y_beach_01" },
    { label = "Passante Vinewood (1)",                   model = "a_f_y_vinewood_01" },
    { label = "Passante Vinewood (2)",                   model = "a_f_y_vinewood_02" },
    { label = "Passante Vinewood (3)",                   model = "a_f_y_vinewood_03" },
    { label = "Passante golfeuse",                       model = "a_f_y_golfer_01" },
    { label = "Passante yoga",                           model = "a_f_y_yoga_01" },
    { label = "Passante fitness",                        model = "a_f_y_fitness_01" },
    { label = "Passante fitness (2)",                    model = "a_f_y_fitness_02" },
    { label = "Passante touriste",                       model = "a_f_m_tourist_01" },

    -------------------------------------------------------------
    -- Services publics / uniformes (pratique pour poste de police, hôpital, etc.)
    -------------------------------------------------------------
    { label = "Policier",                                model = "s_m_y_cop_01" },
    { label = "Policière",                               model = "s_f_y_cop_01" },
    { label = "Shérif",                                  model = "s_m_y_sheriff_01" },
    { label = "Shérif (femme)",                          model = "s_f_y_sheriff_01" },
    { label = "Médecin",                                 model = "s_m_y_doctor_01" },
    { label = "Médecin (femme)",                         model = "s_f_y_doctor_01" },
    { label = "Ambulancier",                             model = "s_m_y_paramedic_01" },
    { label = "Pompier",                                 model = "s_m_y_fireman_01" },
    { label = "Pilote",                                  model = "s_m_y_pilot_01" },
    { label = "Pilote (femme)",                          model = "s_f_y_pilot_01" },
    { label = "Agent aéroportuaire",                     model = "s_m_y_airworker" },
    { label = "Agente aéroportuaire",                    model = "s_f_y_airworker" },
    { label = "Garde-côte",                              model = "s_m_y_uscg_01" },
    { label = "Maître-nageur",                           model = "s_m_y_baywatch_01" },
    { label = "Maître-nageuse",                          model = "s_f_y_baywatch_01" },

    -------------------------------------------------------------
    -- Personnages uniques / atypiques (pour un côté plus vivant)
    -------------------------------------------------------------
    { label = "Mime",                                    model = "s_m_y_mime" },
    { label = "Clown",                                    model = "s_m_y_clown_01" },
    { label = "Prédicateur de rue",                       model = "s_m_m_strpreach_01" },
    { label = "Musicien de rue",                          model = "s_m_m_strperf_01" },
    { label = "Mariachi",                                 model = "s_m_m_mariachi_01" },
    { label = "Concierge / gardien d'immeuble",           model = "ig_manuel" },
    { label = "Mécanicien Benny (unique)",                model = "ig_benny" },
}

-- Si un modèle de la liste ci-dessus ne s'affiche pas en jeu (le nom technique
-- GTA n'existe pas ou plus), le menu t'affichera une notification d'erreur
-- avec son nom exact — dis-le-moi et je le remplace dans cette liste.