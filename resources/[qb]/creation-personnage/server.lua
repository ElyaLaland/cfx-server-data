-- === Création automatique d'UN SEUL personnage par compte ===
-- Pas d'écran de sélection : soit on retrouve un personnage déjà existant
-- pour ce joueur, soit on lui en crée un tout simple automatiquement.

local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('creationperso:server:login', function()
    local src = source
    local license = QBCore.Functions.GetIdentifier(src, 'license')

    if not license then
        print('>>> creation-personnage : impossible de trouver la license du joueur ' .. src .. ' <<<')
        return
    end

    -- On regarde si ce joueur a déjà un personnage en base de données
    local result = MySQL.query.await('SELECT citizenid FROM players WHERE license = ? LIMIT 1', { license })

    if result and result[1] then
        -- Personnage existant → on le recharge.
        -- IMPORTANT : on ne fait surtout PAS de Save() juste après un rechargement.
        -- Le temps que les vraies données (objets, argent...) soient chargées depuis
        -- la base, un Save() immédiat les écraserait par un inventaire vide.
        -- C'est ce qui causait la perte des objets à chaque reconnexion.
        QBCore.Player.Login(src, result[1].citizenid)
        print('>>> creation-personnage : personnage existant chargé pour ' .. license .. ' <<<')
    else
        -- Aucun personnage → on en crée un simple, sans écran de création.
        -- Là, un Save() est nécessaire pour que ce tout nouveau personnage
        -- soit bien enregistré en base pour la première fois.
        local newData = {
            cid = 1,
            charinfo = {
                firstname = 'Joueur',
                lastname = 'Anonyme',
                birthdate = '1990-01-01',
                gender = 0,
                nationality = 'Inconnue',
            }
        }
        QBCore.Player.Login(src, false, newData)
        print('>>> creation-personnage : nouveau personnage créé pour ' .. license .. ' <<<')

        local NewPlayer = QBCore.Functions.GetPlayer(src)
        if NewPlayer then
            NewPlayer.Functions.Save()
        end
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
    end
end)