-- === Notifications maison ===
-- Remplace QBCore.Functions.Notify pour tout ce qu'on affiche nous-mêmes
-- (l'inventaire, et toute future resource) : même position (juste au-dessus
-- de la mini-carte) et même thème doré que le reste du serveur, au lieu du
-- style par défaut de qb-core.
--
-- Utilisation depuis un autre script (dans son fxmanifest.lua, ajouter
-- dependency 'notifications' pour être sûr qu'elle est bien chargée avant) :
--
--   exports['notifications']:Notify('Vous buvez de l\'eau.')            -- neutre (doré)
--   exports['notifications']:Notify('Action réussie', 'success')        -- vert
--   exports['notifications']:Notify('Vous ne pouvez pas faire ça', 'error') -- rouge

local function notify(message, type)
    SendNUIMessage({
        action = 'notify',
        message = message,
        type = type or 'info'
    })
end

exports('Notify', notify)

-- Pour plus tard, si le SERVEUR doit envoyer une notif directement à un
-- joueur (une sanction, un événement...) sans passer par un script client.
RegisterNetEvent('notifications:client:notify', function(message, type)
    notify(message, type)
end)
