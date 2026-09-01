local QBCore = exports['qb-core']:GetCoreObject()

--------------------------------------------------------------------------
-- ⚠️ IMPORTANT : pour que le menu (ajout/suppression de PNJ) fonctionne,
-- il faut donner la permission ACE "admin" à ton compte (et celui de ton
-- co-fondateur) dans le server.cfg. Sans ça, IsAdmin() ci-dessous renvoie
-- toujours false et tout est silencieusement refusé (c'était le bug de
-- "Placer ici" qui ne faisait rien).
--
-- 1. Connecte-toi une fois sur le serveur, ouvre la console F8 en jeu et
--    tape "identifiers" (ou regarde ton profil dans txAdmin > joueurs
--    connectés) pour trouver un identifiant du type license:xxxxxxxx.
-- 2. Ajoute ces deux lignes dans server.cfg (une paire par personne),
--    puis fais un vrai redémarrage complet du serveur via txAdmin :
--
--    add_principal identifier.license:TON_IDENTIFIANT_ICI group.admin
--    add_ace group.admin admin allow
--
-- (la 2e ligne ne doit être ajoutée qu'une seule fois, la 1ère une fois
-- par personne à ajouter au groupe admin)
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Vérification admin côté serveur (la seule qui compte vraiment : le client
-- peut être modifié par un joueur malveillant, jamais lui faire confiance).
--------------------------------------------------------------------------
local function IsAdmin(src)
    -- Permission ACE ("admin"), le système standard FiveM configuré dans server.cfg
    -- via add_ace / add_principal (voir la note en bas de fichier).
    if IsPlayerAceAllowed(src, 'admin') then return true end

    -- Repli : si un jour un groupe QBCore ('admin'/'god') est posé sur le joueur
    -- (ex. colonne "group" en base), ça marche aussi sans rien reconfigurer.
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Config.AllowedGroups[Player.PlayerData.group] then return true end

    return false
end

--------------------------------------------------------------------------
-- Table SQL "static_peds" (voir sql/static_peds.sql fourni à part,
-- à exécuter une fois dans phpMyAdmin comme les autres tables du projet).
--------------------------------------------------------------------------

-- Envoie la liste actuelle des PNJ à un joueur qui vient de se connecter,
-- pour qu'ils apparaissent chez lui sans avoir besoin d'un redémarrage.
local function SendAllPedsTo(src)
    MySQL.Async.fetchAll('SELECT * FROM static_peds', {}, function(rows)
        TriggerClientEvent('adminmenu:client:syncPeds', src, rows or {})
    end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    SendAllPedsTo(src)

    -- Diagnostic temporaire : affiche dans la console serveur (fenêtre txAdmin)
    -- les identifiants du joueur et si la permission admin est détectée, pour
    -- comprendre pourquoi "admin" est refusé. À retirer une fois le souci réglé.
    print(('[admin-menu][diagnostic] Connexion de %s (source %s)'):format(GetPlayerName(src) or '?', src))
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        print(('[admin-menu][diagnostic]   identifiant : %s'):format(id))
    end
    print(('[admin-menu][diagnostic]   IsPlayerAceAllowed(src, "admin") = %s'):format(tostring(IsPlayerAceAllowed(src, 'admin'))))
end)

--------------------------------------------------------------------------
-- Callback : récupérer la liste des PNJ (utilisé à l'ouverture de l'onglet)
--------------------------------------------------------------------------
QBCore.Functions.CreateCallback('adminmenu:server:getPeds', function(source, cb)
    if not IsAdmin(source) then
        cb({})
        return
    end
    MySQL.Async.fetchAll('SELECT * FROM static_peds', {}, function(rows)
        cb(rows or {})
    end)
end)

--------------------------------------------------------------------------
-- Ajouter un PNJ à la position du joueur
--------------------------------------------------------------------------
RegisterNetEvent('adminmenu:server:addPed', function(model, name, coords, heading)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "Tu n'as pas la permission admin (voir server.cfg)", 'error')
        return
    end

    if type(model) ~= 'string' or model == '' then return end
    name = tostring(name or '')
    if name == '' then name = 'PNJ sans nom' end
    -- Sécurité basique : longueur raisonnable pour éviter d'abîmer l'affichage/la base
    if #name > 50 then name = string.sub(name, 1, 50) end

    MySQL.Async.insert('INSERT INTO static_peds (name, model, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)', {
        name, model, coords.x, coords.y, coords.z, heading
    }, function(insertId)
        if not insertId then
            TriggerClientEvent('QBCore:Notify', src, "Erreur lors de l'enregistrement du PNJ", 'error')
            return
        end

        local pedRow = {
            id = insertId,
            name = name,
            model = model,
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = heading
        }

        -- Fait apparaître le PNJ chez tout le monde immédiatement (pas besoin de redémarrer)
        TriggerClientEvent('adminmenu:client:spawnPed', -1, pedRow)
        -- Renvoie la liste à jour à celui qui vient de l'ajouter (pour rafraîchir son menu)
        SendAllPedsTo(src)
    end)
end)

--------------------------------------------------------------------------
-- Supprimer un PNJ
--------------------------------------------------------------------------
RegisterNetEvent('adminmenu:server:deletePed', function(id)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "Tu n'as pas la permission admin (voir server.cfg)", 'error')
        return
    end
    id = tonumber(id)
    if not id then return end

    MySQL.Async.execute('DELETE FROM static_peds WHERE id = ?', { id }, function(rowsChanged)
        if rowsChanged and rowsChanged > 0 then
            TriggerClientEvent('adminmenu:client:removePed', -1, id)
        end
        SendAllPedsTo(src)
    end)
end)