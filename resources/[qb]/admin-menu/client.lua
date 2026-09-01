local QBCore = exports['qb-core']:GetCoreObject()

local menuOpen = false

-- Sécurité : si la ressource redémarre/s'arrête pendant que le noclip est actif,
-- on remet le personnage visible et solide pour éviter de le laisser bloqué.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
end)

local function OpenAdminMenu()
    if menuOpen then return end
    menuOpen = true
    local ped = PlayerPedId()
    -- Le perso ne doit ni bouger, ni frapper, ni tirer pendant qu'on est dans le menu
    -- (tape le nom d'un PNJ, par exemple) : on le fige et le rend invincible le temps
    -- que le menu est ouvert (voir aussi le thread qui coupe les contrôles plus bas).
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetNuiFocus(true, true)
    -- Laisse le jeu continuer à recevoir les touches (dont celle qui ouvre/ferme le menu)
    -- même quand le NUI a le focus, sinon un 2e appui sur la touche n'est plus détecté.
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'open',
        pedModels = Config.PedModels
    })
end

local function CloseAdminMenu()
    if not menuOpen then return end
    menuOpen = false
    -- Si le noclip est actif, c'est lui qui gère l'état figé/invincible : on n'y touche pas.
    if not noclipEnabled then
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'close'
    })
    ClearPedPreview()
end

-- Coupe tous les contrôles du jeu (déplacement, coups, tir, etc.) tant que le menu
-- est ouvert, en plus du figeage ci-dessus (le figeage seul n'empêche pas de taper
-- un coup de poing en restant sur place). Les touches liées via RegisterKeyMapping
-- (F6, F7...) continuent de fonctionner : ce mécanisme est indépendant des contrôles
-- qu'on désactive ici.
CreateThread(function()
    while true do
        local sleep = 250
        if menuOpen then
            sleep = 0
            DisableAllControlActions(0)
        end
        Wait(sleep)
    end
end)

-- Commande interne liée à la touche (rebindable par le joueur dans les paramètres FiveM)
RegisterCommand(Config.CommandName, function()
    if menuOpen then
        CloseAdminMenu()
    else
        OpenAdminMenu()
    end
end, false)

-- Enregistre la touche par défaut ET l'entrée dans Paramètres > Touches > FiveM
-- Le joueur peut ensuite la changer lui-même, sans toucher au code.
RegisterKeyMapping(Config.CommandName, 'Ouvrir/fermer le menu administration', 'keyboard', Config.DefaultKey)

-- Fermeture depuis le NUI (bouton fermer / touche Echap dans le HTML)
RegisterNUICallback('close', function(_, cb)
    CloseAdminMenu()
    cb('ok')
end)

--------------------------------------------------------------------------
-- MODE ADMIN (case à cocher dans le menu)
--------------------------------------------------------------------------

local adminModeEnabled = false

-- Notifications du menu admin : on passe par ton resource "notifications", avec le
-- type "staff" par défaut (fond violet/bleu foncé) pour bien les différencier des
-- notifs joueur classiques (doré = info, vert = succès, rouge = erreur).
local function Notify(message, type)
    exports['notifications']:Notify(message, type or 'staff')
end

RegisterNUICallback('toggleAdminMode', function(data, cb)
    adminModeEnabled = data.enabled

    -- Sécurité : si on désactive le mode admin pendant que le noclip est actif, on le coupe.
    if not adminModeEnabled and noclipEnabled then
        DisableNoclip()
    end

    cb('ok')
end)

--------------------------------------------------------------------------
-- NOCLIP (personnage invisible, pas juste une caméra qui se détache)
--------------------------------------------------------------------------

noclipEnabled = false
local noclipSpeed = Config.NoclipSpeed

function EnableNoclip()
    local ped = PlayerPedId()
    noclipEnabled = true
    noclipSpeed = Config.NoclipSpeed
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    -- Le personnage est figé : sans ça, sans collision et sans qu'on bouge,
    -- la gravité continue de s'appliquer et on tombe sous la map.
    FreezeEntityPosition(ped, true)
end

function DisableNoclip()
    local ped = PlayerPedId()
    noclipEnabled = false
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
end

RegisterCommand(Config.NoclipCommand, function()
    if not adminModeEnabled then
        Notify("Noclip impossible : active d'abord le mode admin")
        return
    end

    if noclipEnabled then
        DisableNoclip()
    else
        EnableNoclip()
    end
end, false)

RegisterKeyMapping(Config.NoclipCommand, 'Activer/désactiver le noclip', 'keyboard', Config.NoclipKey)

-- Déplacement en noclip, basé sur la direction de la caméra (comme un vrai noclip, pas une simple téléportation)
CreateThread(function()
    while true do
        local sleep = 500

        if noclipEnabled then
            sleep = 0
            local ped = PlayerPedId()

            -- Molette de la souris : ajuste la vitesse de déplacement à la volée.
            -- On désactive ces contrôles (sinon la molette change aussi l'arme équipée)
            -- et on lit la version "disabled" pour être sûr de capter le scroll.
            DisableControlAction(0, 14, true) -- INPUT_WEAPON_WHEEL_NEXT
            DisableControlAction(0, 15, true) -- INPUT_WEAPON_WHEEL_PREV

            if IsDisabledControlJustPressed(0, 14) then -- molette vers le bas
                noclipSpeed = math.max(Config.NoclipSpeedMin, noclipSpeed - Config.NoclipSpeedStep)
            elseif IsDisabledControlJustPressed(0, 15) then -- molette vers le haut
                noclipSpeed = math.min(Config.NoclipSpeedMax, noclipSpeed + Config.NoclipSpeedStep)
            end

            local speed = noclipSpeed
            if IsControlPressed(0, 21) then -- Shift : boost temporaire en plus
                speed = speed * Config.NoclipSpeedBoost
            end

            local camRot = GetGameplayCamRot(2)
            local rotZ = math.rad(camRot.z)
            local rotX = math.rad(camRot.x)

            local forward = vector3(-math.sin(rotZ) * math.cos(rotX), math.cos(rotZ) * math.cos(rotX), math.sin(rotX))
            local right = vector3(math.cos(rotZ), math.sin(rotZ), 0.0)

            local coords = GetEntityCoords(ped)
            local move = vector3(0.0, 0.0, 0.0)

            if IsControlPressed(0, 32) then move = move + forward end       -- W : avancer
            if IsControlPressed(0, 33) then move = move - forward end       -- S : reculer
            if IsControlPressed(0, 34) then move = move - right end         -- A : gauche
            if IsControlPressed(0, 35) then move = move + right end         -- D : droite
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end -- Espace : monter
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end -- Ctrl : descendre

            if move ~= vector3(0.0, 0.0, 0.0) then
                local newCoords = coords + (move * speed * 0.016)
                SetEntityCoordsNoOffset(ped, newCoords.x, newCoords.y, newCoords.z, true, true, true)
            end
        end

        Wait(sleep)
    end
end)

--------------------------------------------------------------------------
-- ONGLET "PNJ" : PNJ statiques (magasins, etc.) placés depuis le menu et
-- enregistrés en base de données par le serveur — persistent au redémarrage.
--------------------------------------------------------------------------

-- Table locale des PNJ persistants actuellement affichés chez ce joueur : [id] = { data = {...}, handle = ped }
local spawnedPeds = {}

-- Le PNJ "aperçu" temporaire affiché devant l'admin pendant qu'il choisit un modèle
local previewPedHandle = nil

local function SafeTeleport(coords, heading)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 0.2, false, false, false)
    if heading then SetEntityHeading(ped, heading) end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end

local function CreateStaticPed(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

-- Fait apparaître un PNJ persistant (magasin, etc.) : figé, invincible, ne réagit à rien.
function SpawnStaticPed(pedData)
    if spawnedPeds[pedData.id] then return end -- déjà présent chez ce joueur

    local hash = CreateStaticPed(pedData.model)
    if not hash then return end

    local ped = CreatePed(4, hash, pedData.x, pedData.y, pedData.z - 1.0, pedData.heading or 0.0, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetEntityCanBeDamaged(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true) -- ignore complètement les combats autour de lui
    TaskSetBlockingOfNonTemporaryEvents(ped, true)

    SetModelAsNoLongerNeeded(hash)

    spawnedPeds[pedData.id] = { data = pedData, handle = ped }
end

local function RemoveStaticPed(id)
    local entry = spawnedPeds[id]
    if not entry then return end
    if DoesEntityExist(entry.handle) then
        DeletePed(entry.handle)
    end
    spawnedPeds[id] = nil
end

-- Synchronisation complète envoyée par le serveur (à la connexion, ou après ajout/suppression)
RegisterNetEvent('adminmenu:client:syncPeds', function(rows)
    -- Retire les PNJ qui ne sont plus en base (supprimés entre-temps)
    local stillThere = {}
    for _, row in ipairs(rows) do
        stillThere[row.id] = true
    end
    for id in pairs(spawnedPeds) do
        if not stillThere[id] then
            RemoveStaticPed(id)
        end
    end

    for _, row in ipairs(rows) do
        SpawnStaticPed(row)
    end
end)

RegisterNetEvent('adminmenu:client:spawnPed', function(pedData)
    SpawnStaticPed(pedData)
end)

RegisterNetEvent('adminmenu:client:removePed', function(id)
    RemoveStaticPed(id)
end)

--------------------------------------------------------------------------
-- Aperçu en jeu : fait apparaître le modèle sélectionné juste devant l'admin
-- pendant qu'il choisit dans le menu déroulant, avant de confirmer l'ajout.
--------------------------------------------------------------------------

function ClearPedPreview()
    if previewPedHandle and DoesEntityExist(previewPedHandle) then
        DeletePed(previewPedHandle)
    end
    previewPedHandle = nil
end

RegisterNUICallback('previewPed', function(data, cb)
    ClearPedPreview()

    if data.model and data.model ~= '' then
        local hash = CreateStaticPed(data.model)
        if not hash then
            Notify(("Modèle \"%s\" introuvable, impossible de l'afficher"):format(data.model), 'error')
        end
        if hash then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local forward = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.2, 0.0)

            previewPedHandle = CreatePed(4, hash, forward.x, forward.y, coords.z, heading + 180.0, false, false)
            SetEntityAsMissionEntity(previewPedHandle, true, true)
            FreezeEntityPosition(previewPedHandle, true)
            SetEntityInvincible(previewPedHandle, true)
            SetPedCanBeTargetted(previewPedHandle, false)
            SetBlockingOfNonTemporaryEvents(previewPedHandle, true)
            SetModelAsNoLongerNeeded(hash)
        end
    end

    cb('ok')
end)

--------------------------------------------------------------------------
-- Placer un PNJ à la position actuelle du joueur
--------------------------------------------------------------------------

RegisterNUICallback('placePed', function(data, cb)
    ClearPedPreview()

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    TriggerServerEvent('adminmenu:server:addPed', data.model, data.name, coords, heading)

    cb('ok')
end)

RegisterNUICallback('deletePed', function(data, cb)
    TriggerServerEvent('adminmenu:server:deletePed', data.id)
    cb('ok')
end)

RegisterNUICallback('teleportToPed', function(data, cb)
    local entry = spawnedPeds[tonumber(data.id)]
    if entry then
        local d = entry.data
        SafeTeleport(vector3(d.x, d.y, d.z), d.heading)
    end
    cb('ok')
end)

-- Demande la liste à jour au serveur à l'ouverture de l'onglet PNJ (utile si un
-- autre admin a ajouté/supprimé un PNJ depuis que la session est ouverte).
RegisterNUICallback('getPedList', function(_, cb)
    QBCore.Functions.TriggerCallback('adminmenu:server:getPeds', function(rows)
        cb(rows)
    end)
end)