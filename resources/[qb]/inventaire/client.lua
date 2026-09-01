-- === Inventaire maison — Étape 2 : connecté à QBCore ===

local QBCore = exports['qb-core']:GetCoreObject()

local invOpen = false

-- Certaines situations RP doivent empêcher d'ouvrir l'inventaire : menotté,
-- mort, ou à terre (KO). Ces informations viennent des métadonnées standard
-- de QBCore (mises à jour par les scripts de menottage/mort déjà présents
-- dans QBCore, on n'a rien à faire de plus pour qu'elles soient à jour).
local function canOpenInventory()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.metadata then return true end

    if PlayerData.metadata.ishandcuffed then
        exports['notifications']:Notify('Vous ne pouvez pas faire ça les mains menottées.', 'error')
        return false
    end

    if PlayerData.metadata.isdead or PlayerData.metadata.inlaststand then
        exports['notifications']:Notify('Vous ne pouvez pas faire ça dans cet état.', 'error')
        return false
    end

    return true
end

RegisterCommand('inventaire', function()
    if not invOpen and not canOpenInventory() then
        return
    end

    invOpen = not invOpen
    SetNuiFocus(invOpen, invOpen)

    if invOpen then
        -- On demande au serveur les vraies données (objets + argent). Le
        -- serveur détermine lui-même notre position (voir server.lua) : on ne
        -- lui envoie plus nos coordonnées, pour éviter qu'un client triché
        -- puisse mentir dessus.
        TriggerServerEvent('inventaire:getData')
    else
        SendNUIMessage({ action = 'close' })
    end
end, false)

-- Si le joueur se fait menotter ou tomber KO pendant que l'inventaire est
-- déjà ouvert, on le referme de force : sinon il pourrait continuer à s'en
-- servir malgré son état.
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if not invOpen then return end
    if not val or not val.metadata then return end

    if val.metadata.ishandcuffed or val.metadata.isdead or val.metadata.inlaststand then
        invOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end)

RegisterKeyMapping('inventaire', 'Ouvrir/Fermer l\'inventaire', 'keyboard', 'TAB')

-- === Barre rapide (touches 1 à 5) ===
-- Ce sont maintenant de vraies cases (comme le sol) : glisser un objet dessus
-- le RETIRE de l'inventaire du joueur. Pour l'en ressortir, il suffit de le
-- reglisser dans l'inventaire, exactement comme avec le sol.
for i = 1, 5 do
    RegisterCommand('hotbar' .. i, function()
        if not canOpenInventory() then return end
        TriggerServerEvent('inventaire:server:useHotbar', i)
    end, false)

    RegisterKeyMapping('hotbar' .. i, 'Utiliser l\'objet ' .. i .. ' de la barre rapide', 'keyboard', tostring(i))
end
-- Le blocage de la sélection d'arme sur les touches 1 à 5 (pour éviter le
-- conflit avec cette barre rapide) vit maintenant dans sa propre resource :
-- desactiver-armes.

RegisterNetEvent('inventaire:receiveData', function(items, totalWeight, maxWeight, totalSlots, groundItems, groundTotalSlots, hotbarItems)
    -- On n'affiche que si le menu est toujours censé être ouvert
    -- (évite d'afficher une réponse tardive après une fermeture rapide).
    if not invOpen then return end

    SendNUIMessage({
        action = 'open',
        items = items,
        totalWeight = totalWeight,
        maxWeight = maxWeight,
        totalSlots = totalSlots,
        groundItems = groundItems,
        groundTotalSlots = groundTotalSlots,
        hotbarItems = hotbarItems
    })
end)

RegisterNUICallback('closeInventaire', function(data, cb)
    invOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

-- Petite animation jouée quand on pose quelque chose au sol. Purement visuelle
-- (le serveur ne l'attend pas pour valider le déplacement), donc aucun risque
-- de bloquer ou désynchroniser l'inventaire si elle rate pour une raison ou une autre.
local function playDeposeAnim()
    local ped = PlayerPedId()
    local dict = 'pickup_object'

    RequestAnimDict(dict)
    local tries = 0
    while not HasAnimDictLoaded(dict) and tries < 100 do
        Wait(10)
        tries = tries + 1
    end

    if not HasAnimDictLoaded(dict) then return end

    TaskPlayAnim(ped, dict, 'pickup_low', 8.0, -8.0, 1500, 0, 0, false, false, false)
    RemoveAnimDict(dict)
end

-- Le JS nous demande de déplacer un objet de la case "from" vers la case "to".
-- On transmet au serveur, qui est seul autorisé à valider et sauvegarder le déplacement.
RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('inventaire:server:moveItem', data.fromContainer, data.fromSlot, data.toContainer, data.toSlot, data.quantity)

    -- Même animation dans les deux sens : poser un objet au sol, ou le ramasser.
    local touchesGround = data.toContainer == 'ground' or data.fromContainer == 'ground'
    local staysOnGround = data.toContainer == 'ground' and data.fromContainer == 'ground'

    if touchesGround and not staysOnGround then
        playDeposeAnim()
    end

    cb('ok')
end)

-- Le JS nous demande de jeter un objet au sol (menu clic droit -> "Jeter").
RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('inventaire:server:dropItem', data.slot, data.quantity)
    playDeposeAnim()
    cb('ok')
end)

-- Le JS nous demande d'utiliser un objet (double-clic dessus). Le serveur
-- valide et retire l'exemplaire ; c'est lui qui nous renvoie ensuite l'effet
-- à jouer via 'inventaire:client:useItemEffect'.
RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('inventaire:server:useItem', data.slot)
    cb('ok')
end)

-- Le JS nous demande d'utiliser l'objet posé sur une case de la barre rapide
-- (double-clic ou menu clic droit dessus, dans l'inventaire).
RegisterNUICallback('useHotbar', function(data, cb)
    TriggerServerEvent('inventaire:server:useHotbar', data.hotbarSlot)
    cb('ok')
end)

-- Joue l'animation et affiche le message définis dans config/items.lua pour
-- l'objet qu'on vient d'utiliser.
RegisterNetEvent('inventaire:client:useItemEffect', function(infos)
    local ped = PlayerPedId()

    if infos.useAnim then
        local dict = infos.useAnim.dict

        RequestAnimDict(dict)
        local tries = 0
        while not HasAnimDictLoaded(dict) and tries < 100 do
            Wait(10)
            tries = tries + 1
        end

        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, infos.useAnim.anim, 8.0, -8.0, infos.useAnim.duration or 2000, 49, 0, false, false, false)
        end
    end

    if infos.useMessage then
        exports['notifications']:Notify(infos.useMessage)
    end
end)

-- Commande de test pour se donner des objets (tapée dans le F8, en jeu).
-- Comme il n'y a pas de tchat installé, c'est le client qui doit transmettre
-- la demande au serveur : le F8 ne peut pas le faire tout seul.
RegisterCommand('additem', function(source, args)
    TriggerServerEvent('inventaire:server:additem', args[1], args[2])
end, false)

-- Commande de diagnostic : tape "dumpinv" dans le F8 pour voir le contenu
-- exact de ton inventaire dans la console serveur/txAdmin.
RegisterCommand('dumpinv', function(source, args)
    TriggerServerEvent('inventaire:server:dumpinv')
end, false)

-- Commande de secours : tape /fixsouris dans le chat (ou fixsouris en console F8)
-- si jamais tu restes bloquée avec la souris, peu importe la cause.
RegisterCommand('fixsouris', function()
    invOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    print('Souris/clavier libérés de force.')
end, false)

-- === Carton posé au sol ===
-- Le serveur nous demande de faire apparaître le carton quand on vient de
-- poser quelque chose. On charge le modèle nous-mêmes (sinon le jeu affiche
-- un gros cube générique à la place), et on cale l'objet pile sur le sol réel
-- avec GetGroundZFor_3dCoord (le sol n'est jamais parfaitement plat).
RegisterNetEvent('inventaire:client:createGroundProp', function(cellId, coords)
    local model = `prop_cs_package_01` -- petit paquet/colis (plus petit que le carton)

    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 200 do
        Wait(10)
        tries = tries + 1
    end

    if not HasModelLoaded(model) then
        print('>>> Inventaire : impossible de charger le modèle du carton <<<')
        return
    end

    local groundZ = coords.z
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if found then groundZ = z end

    local obj = CreateObjectNoOffset(model, coords.x, coords.y, groundZ, true, true, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    -- Purement décoratif : on ne veut pas qu'une voiture qui le percute
    -- déclenche un accident, ni que les joueurs restent bloqués dessus.
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(model)

    local netId = NetworkGetNetworkIdFromEntity(obj)
    TriggerServerEvent('inventaire:server:groundPropCreated', cellId, netId)
end)

RegisterNetEvent('inventaire:client:removeGroundProp', function(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end

    local obj = NetworkGetEntityFromNetworkId(netId)
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
end)