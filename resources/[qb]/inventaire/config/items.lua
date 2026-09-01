-- === Liste de tous les items du serveur ===
-- Chaque ligne = un item.
-- name       = le nom technique (doit être identique à celui utilisé dans qb-core/shared/items.lua)
-- label      = le nom affiché en jeu (peut être différent du nom technique)
-- weight     = le poids en grammes (1000 = 1 kg)
-- image      = le nom du fichier image dans inventaire/html/images/
-- useable     = true si on peut double-cliquer dessus pour l'utiliser (sinon, absent ou false)
-- useMessage  = le message affiché quand on l'utilise
-- useAnim     = l'animation jouée : dict (le "dossier" d'animations), anim (son nom), duration (en ms)
-- description = le texte affiché dans l'infobulle au survol (optionnel : sans ça,
--               on retombe sur la description anglaise par défaut de QBCore)

Config = Config or {}

Config.Items = {
    ['water_bottle'] = {
        label = 'Eau',
        weight = 500,
        image = 'eau.png',
        description = 'Une bouteille d\'eau fraîche.',
        useable = true,
        useMessage = 'Vous buvez de l\'eau.',
        useAnim = { dict = 'mp_player_intdrink', anim = 'loop_bottle', duration = 3000 }
    },
    ['sandwich'] = {
        label = 'Sandwich',
        weight = 200,
        image = 'sandwich.png',
        description = 'Un bon sandwich, ça cale.',
        useable = true,
        useMessage = 'Vous mangez un sandwich.',
        useAnim = { dict = 'mp_player_inteat@burger', anim = 'mp_player_int_eat_burger', duration = 3000 }
    },
}