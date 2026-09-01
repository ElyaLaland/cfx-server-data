-- === Inventaire maison — Étape 6 : stockage externe (relié au sol pour l'instant) ===
-- En plus de l'inventaire du joueur, on gère maintenant un deuxième "conteneur"
-- d'objets. Pour l'instant il est toujours relié au sol (une zone autour du
-- joueur), mais le système est fait pour qu'on puisse plus tard le relier à
-- un coffre précis à la place, sans rien changer côté affichage.
--
-- NOTE : le contenu du sol n'est PAS sauvegardé en base de données pour
-- l'instant (il vit seulement en mémoire pendant que le serveur tourne).
-- On pourra ajouter la sauvegarde plus tard si besoin.

local QBCore = exports['qb-core']:GetCoreObject()

local MAX_WEIGHT = 50    -- kg, pour l'inventaire du joueur (cases + barre rapide)
local TOTAL_SLOTS = 20   -- nombre de cases de l'inventaire du joueur
local GROUND_SLOTS = 20  -- nombre de cases du stockage au sol
local HOTBAR_SLOTS = 5   -- nombre de cases de la barre rapide

local GroundStashes = {}      -- [cellId] = { [slot] = item, ... }
local GroundStashProps = {}   -- [cellId] = id réseau de l'objet "carton" affiché en jeu
local GroundStashLastTouch = {} -- [cellId] = timestamp de la dernière fois qu'on y a touché
local playerGroundCell = {}   -- [source] = cellId (zone de sol sur laquelle le joueur se trouve)

-- Un tas au sol qu'on n'a pas touché depuis ce délai disparaît tout seul.
-- Ça évite d'accumuler indéfiniment des objets oubliés partout sur la carte
-- si le serveur tourne longtemps sans redémarrer.
local GROUND_STASH_EXPIRY = 2 * 60 * 60 -- 2 heures, en secondes

-- Découpe le monde en cases de 2 mètres : tous les joueurs dans la même case
-- voient et partagent le même stockage au sol.
local function getCellId(coords)
    local gx = math.floor(coords.x / 2.0)
    local gy = math.floor(coords.y / 2.0)
    local gz = math.floor(coords.z / 2.0)
    return gx .. '_' .. gy .. '_' .. gz
end

-- Retrouve les coordonnées du centre d'une case à partir de son identifiant
-- (utile pour savoir où poser le carton).
local function cellCenterCoords(cellId)
    local gx, gy, gz = string.match(cellId, '^(-?%d+)_(-?%d+)_(-?%d+)$')
    if not gx then return nil end
    return vector3(tonumber(gx) * 2.0 + 1.0, tonumber(gy) * 2.0 + 1.0, tonumber(gz) * 2.0 + 1.0)
end

-- Un objet "unique" (comme une arme, un téléphone...) ne doit jamais se
-- retrouver empilé en x2 dans une seule case, contrairement à un sandwich.
-- C'est QBCore lui-même qui décide de ça pour chaque objet (dans
-- qb-core/shared/items.lua), on ne fait que le respecter partout où on
-- pourrait empiler des objets.
local function isUniqueItem(itemName)
    local itemData = QBCore.Shared.Items[itemName]
    return itemData and itemData.unique or false
end

local function isStashEmpty(stash)
    if not stash then return true end
    for _, item in pairs(stash) do
        if item then return false end
    end
    return true
end

-- Fait apparaître/disparaître le carton au sol selon que la case de stockage
-- contient encore des objets ou non. Le carton est purement visuel : c'est
-- toujours GroundStashes qui fait foi pour le contenu réel.
--
-- On délègue la création au client (celui qui vient de poser l'objet) car
-- côté serveur, un objet créé sans avoir été "chargé" au préalable s'affiche
-- souvent comme un gros cube générique à la place du vrai modèle. Le client
-- sait charger le modèle et caler l'objet pile sur le sol réel avant de le
-- faire apparaître ; une fois créé en "networked", tout le monde le voit.
local function syncGroundProp(cellId, src)
    if not cellId then return end

    local stashEmpty = isStashEmpty(GroundStashes[cellId])
    local existingNetId = GroundStashProps[cellId]

    if stashEmpty then
        if existingNetId then
            TriggerClientEvent('inventaire:client:removeGroundProp', -1, existingNetId)
        end
        GroundStashProps[cellId] = nil
        -- On libère complètement la mémoire de cette case : sans ça, une table
        -- vide resterait indéfiniment en mémoire pour chaque zone où quelqu'un
        -- a un jour posé puis repris un objet (fuite mémoire lente mais réelle
        -- sur un serveur qui tourne longtemps avec beaucoup de joueurs).
        GroundStashes[cellId] = nil
        GroundStashLastTouch[cellId] = nil
    else
        -- On note qu'on vient d'y toucher, pour l'expiration automatique plus bas.
        GroundStashLastTouch[cellId] = os.time()

        if not existingNetId and src then
            local coords = cellCenterCoords(cellId)
            if not coords then return end

            TriggerClientEvent('inventaire:client:createGroundProp', src, cellId, coords)
        end
    end
end

-- Supprime un tas au sol (utilisé par l'expiration automatique ci-dessous ;
-- syncGroundProp ne peut pas s'en charger seul car elle a besoin d'un joueur
-- "src" pour faire apparaître un carton, pas pour le faire disparaître).
local function clearGroundStash(cellId)
    local existingNetId = GroundStashProps[cellId]
    if existingNetId then
        TriggerClientEvent('inventaire:client:removeGroundProp', -1, existingNetId)
    end
    GroundStashes[cellId] = nil
    GroundStashProps[cellId] = nil
    GroundStashLastTouch[cellId] = nil
end

-- Vérifie de temps en temps si des tas au sol sont restés intacts trop
-- longtemps, et les fait disparaître. Toutes les 15 minutes : ça ne coûte
-- rien (une simple boucle sur une petite table), pas besoin de vérifier plus
-- souvent pour un nettoyage qui ne se déclenche qu'au bout de 2 heures.
CreateThread(function()
    while true do
        Wait(15 * 60 * 1000)

        local now = os.time()
        for cellId, lastTouch in pairs(GroundStashLastTouch) do
            if now - lastTouch > GROUND_STASH_EXPIRY then
                clearGroundStash(cellId)
            end
        end
    end
end)

-- Le client nous confirme l'id réseau du carton une fois qu'il l'a créé,
-- pour qu'on sache qu'il existe déjà et pouvoir le supprimer plus tard.
RegisterNetEvent('inventaire:server:groundPropCreated', function(cellId, netId)
    GroundStashProps[cellId] = netId
end)

-- La barre rapide contient de vrais objets (retirés de l'inventaire du joueur
-- quand on les y glisse), pas juste des "raccourcis". On les stocke dans les
-- métadonnées du joueur (comme ishandcuffed, isdead...) : c'est un mécanisme
-- de sauvegarde déjà fourni par QBCore, donc les objets sur la barre rapide
-- sont sauvegardés en base de données exactement comme le reste, sans rien
-- avoir à coder en plus.
local function getHotbarTable(Player)
    Player.PlayerData.metadata.inventaireHotbar = Player.PlayerData.metadata.inventaireHotbar or {}
    return Player.PlayerData.metadata.inventaireHotbar
end

local function saveHotbar(Player)
    Player.Functions.SetPlayerData('metadata', Player.PlayerData.metadata)
    Player.Functions.Save()
end

-- S'assure que l'argent liquide a bien une case attribuée dans l'inventaire
-- du joueur. Si ce n'est pas encore le cas (premier chargement), on lui donne
-- la première case libre, une bonne fois pour toutes.
local function ensureMoneySlot(Player)
    local items = Player.PlayerData.items

    for _, item in pairs(items) do
        if item and item.isMoney then
            return -- déjà en place, rien à faire
        end
    end

    for i = 1, TOTAL_SLOTS do
        if not items[i] then
            items[i] = { name = '__argent__', isMoney = true, amount = 0, weight = 0, slot = i }
            Player.Functions.SetPlayerData('items', items)
            Player.Functions.Save()
            return
        end
    end
end

-- Construit la liste des objets d'un conteneur d'objets bruts (table indexée
-- par case). isPlayerItems permet de gérer le cas particulier de l'argent.
local function buildItemList(rawItems, maxSlots, Player)
    local list = {}

    for rawSlot, item in pairs(rawItems) do
        local slot = tonumber(rawSlot)

        if item and slot and slot >= 1 and slot <= maxSlots then
            if item.isMoney then
                -- Dans l'inventaire du joueur, l'argent affiché est toujours son
                -- vrai solde en direct. Ailleurs (posé au sol...), c'est un montant
                -- figé au moment où il a été posé (voir moveItem).
                local count = Player and (Player.PlayerData.money['cash'] or 0) or (item.amount or 0)
                table.insert(list, {
                    slot = slot,
                    name = 'Argent liquide',
                    count = count,
                    weight = 0,
                    image = 'argent.png',
                    isMoney = true
                })
            else
                local infos = Config.Items[item.name]

                table.insert(list, {
                    slot = slot,
                    itemName = item.name,
                    name = infos and infos.label or item.label or item.name,
                    count = item.amount,
                    weight = (infos and infos.weight or item.weight or 0) / 1000,
                    image = infos and infos.image or 'default.png',
                    useable = infos and infos.useable or false,
                    description = infos and infos.description or item.description or ''
                })
            end
        end
    end

    return list
end

-- Construit et envoie l'inventaire complet d'un joueur (le sien + le sol
-- sur lequel il se trouve + sa barre rapide)
local function sendInventory(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    ensureMoneySlot(Player)

    local list = buildItemList(Player.PlayerData.items, TOTAL_SLOTS, Player)
    local hotbarList = buildItemList(getHotbarTable(Player), HOTBAR_SLOTS, nil)

    -- Les objets sur la barre rapide restent "sur le joueur" (ils n'ont pas
    -- disparu, juste changé de poche) : leur poids compte donc toujours dans
    -- le poids total et la limite de 50 kg.
    local totalWeight = 0
    for _, item in ipairs(list) do
        totalWeight = totalWeight + (item.weight * item.count)
    end
    for _, item in ipairs(hotbarList) do
        totalWeight = totalWeight + (item.weight * item.count)
    end

    local cellId = playerGroundCell[src]
    local groundList = {}
    if cellId and GroundStashes[cellId] then
        groundList = buildItemList(GroundStashes[cellId], GROUND_SLOTS, nil)
    end

    TriggerClientEvent('inventaire:receiveData', src, list, totalWeight, MAX_WEIGHT, TOTAL_SLOTS, groundList, GROUND_SLOTS, hotbarList)
end

-- À chaque ouverture de l'inventaire, on détermine sur quelle case de sol le
-- joueur se trouve. IMPORTANT : on prend sa position directement depuis le
-- serveur (GetEntityCoords sur son ped), on ne fait plus confiance à une
-- position envoyée par le client — un client triché pourrait sinon prétendre
-- se trouver n'importe où sur la carte et piocher dans le stockage au sol
-- de quelqu'un d'autre à distance.
RegisterNetEvent('inventaire:getData', function()
    local src = source
    local ped = GetPlayerPed(src)

    if ped and ped ~= 0 then
        local coords = GetEntityCoords(ped)
        playerGroundCell[src] = getCellId(coords)
    end

    sendInventory(src)
end)

AddEventHandler('playerDropped', function()
    playerGroundCell[source] = nil
end)

-- Ajoute un objet dans l'inventaire d'un joueur (empile sur une pile existante
-- du même objet si possible, sinon prend la première case libre).
-- On l'écrit nous-mêmes car cette version de QBCore ne fournit plus
-- Player.Functions.AddItem (déplacé vers un système d'inventaire séparé).
local function addItemToPlayer(Player, itemName, amount)
    local itemData = QBCore.Shared.Items[itemName]
    if not itemData then return false end

    local items = Player.PlayerData.items
    local unique = isUniqueItem(itemName)

    if not unique then
        for slot, item in pairs(items) do
            if item and item.name == itemName then
                item.amount = item.amount + amount
                items[slot] = item
                Player.Functions.SetPlayerData('items', items)
                Player.Functions.Save()
                return true
            end
        end
    end

    for i = 1, TOTAL_SLOTS do
        if not items[i] then
            items[i] = {
                name = itemData.name,
                amount = amount,
                info = {},
                label = itemData.label,
                description = itemData.description,
                weight = itemData.weight,
                type = itemData.type,
                unique = itemData.unique,
                useable = itemData.useable,
                image = itemData.image,
                slot = i
            }
            Player.Functions.SetPlayerData('items', items)
            Player.Functions.Save()
            return true
        end
    end

    return false -- plus de case libre
end

-- Renvoie la bonne table d'objets bruts + son nombre de cases, selon le nom
-- du conteneur ('player', 'ground' ou 'hotbar'). C'est le seul endroit qui
-- doit changer le jour où on branche un vrai coffre à la place du sol.
local function getContainer(src, Player, containerName)
    if containerName == 'player' then
        return Player.PlayerData.items, TOTAL_SLOTS
    elseif containerName == 'ground' then
        local cellId = playerGroundCell[src]
        if not cellId then return nil end
        GroundStashes[cellId] = GroundStashes[cellId] or {}
        return GroundStashes[cellId], GROUND_SLOTS
    elseif containerName == 'hotbar' then
        return getHotbarTable(Player), HOTBAR_SLOTS
    end
    return nil
end

-- Déplace un objet d'une case vers une autre, entre deux conteneurs (le
-- joueur lui-même et/ou le sol). Échange les deux si la case d'arrivée est
-- déjà occupée.
RegisterNetEvent('inventaire:server:moveItem', function(fromContainer, fromSlot, toContainer, toSlot, quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    quantity = tonumber(quantity)
    if not fromSlot or not toSlot then return end
    if fromContainer == toContainer and fromSlot == toSlot then return end

    local fromTable, fromMax = getContainer(src, Player, fromContainer)
    local toTable, toMax = getContainer(src, Player, toContainer)
    if not fromTable or not toTable then return end

    if fromSlot < 1 or fromSlot > fromMax then return end
    if toSlot < 1 or toSlot > toMax then return end

    local itemFrom = fromTable[fromSlot]
    if not itemFrom then return end

    -- L'argent n'a rien à faire sur la barre rapide (rien à "utiliser").
    if itemFrom.isMoney and toContainer == 'hotbar' then return end

    -- Cas particulier de l'argent liquide : tant qu'elle reste dans la poche
    -- du joueur, elle représente son vrai solde (pas un objet comme un autre).
    -- Dès qu'elle sort de l'inventaire du joueur (posée au sol, donnée à
    -- quelqu'un plus tard...), on la fige en objet transportable classique ;
    -- dès qu'elle y rentre, on la refond dans le solde réel.
    if itemFrom.isMoney then
        if fromContainer == 'player' and toContainer ~= 'player' then
            local available = Player.PlayerData.money['cash'] or 0
            local amount = quantity and math.min(quantity, available) or available
            if amount <= 0 then return end

            local itemTo = toTable[toSlot]

            -- Si la case d'arrivée contient déjà un tas d'argent posé, on empile
            -- dessus au lieu d'exiger une case vide.
            if itemTo and itemTo.isMoney then
                Player.Functions.RemoveMoney('cash', amount, 'inventaire-depot')
                itemTo.amount = (itemTo.amount or 0) + amount
                toTable[toSlot] = itemTo
            elseif not itemTo then
                Player.Functions.RemoveMoney('cash', amount, 'inventaire-depot')
                toTable[toSlot] = { name = '__argent__', isMoney = true, amount = amount, weight = 0, slot = toSlot }
            else
                return -- case occupée par un autre objet : dépôt partiel impossible
            end

            ensureMoneySlot(Player)
            Player.Functions.SetPlayerData('items', Player.PlayerData.items)
            Player.Functions.Save()
            syncGroundProp(playerGroundCell[src], src)
            sendInventory(src)
            return
        elseif toContainer == 'player' and fromContainer ~= 'player' then
            local available = itemFrom.amount or 0
            local amount = quantity and math.min(quantity, available) or available
            if amount <= 0 then return end

            if amount >= available then
                fromTable[fromSlot] = nil
            else
                itemFrom.amount = available - amount
                fromTable[fromSlot] = itemFrom
            end

            Player.Functions.AddMoney('cash', amount, 'inventaire-retrait')
            ensureMoneySlot(Player)

            Player.Functions.SetPlayerData('items', Player.PlayerData.items)
            Player.Functions.Save()
            syncGroundProp(playerGroundCell[src], src)
            sendInventory(src)
            return
        end
        -- Sinon (déplacement à l'intérieur du même inventaire du joueur) :
        -- comportement normal ci-dessous, comme pour n'importe quel objet.
    end

    local itemTo = toTable[toSlot]

    -- Déplacement partiel d'une pile (ex : 3 sandwichs sur les 5 qu'on a).
    -- Un objet unique n'a jamais d'amount > 1, donc cette branche ne le
    -- concerne normalement jamais ; le check ci-dessous est une sécurité.
    if quantity and quantity > 0 and quantity < (itemFrom.amount or 1) then
        if itemTo and (itemTo.name ~= itemFrom.name or isUniqueItem(itemFrom.name)) then
            return -- case d'arrivée occupée, ou objet unique : impossible d'empiler
        end

        itemFrom.amount = itemFrom.amount - quantity

        if itemTo then
            itemTo.amount = (itemTo.amount or 0) + quantity
            toTable[toSlot] = itemTo
        else
            local moved = {}
            for k, v in pairs(itemFrom) do moved[k] = v end
            moved.amount = quantity
            moved.slot = toSlot
            toTable[toSlot] = moved
        end

        fromTable[fromSlot] = itemFrom

        if fromContainer == 'player' or toContainer == 'player' then
            Player.Functions.SetPlayerData('items', Player.PlayerData.items)
            Player.Functions.Save()
        end

        if fromContainer == 'hotbar' or toContainer == 'hotbar' then
            saveHotbar(Player)
        end

        if fromContainer == 'ground' or toContainer == 'ground' then
            syncGroundProp(playerGroundCell[src], src)
        end

        sendInventory(src)
        return
    end

    -- Déplacement complet de la pile (comportement d'origine, avec échange
    -- si la case d'arrivée est déjà occupée par un objet différent, ou par un
    -- objet unique — un objet unique ne s'empile jamais, même sur lui-même).
    if itemTo and itemTo.name == itemFrom.name and not itemFrom.isMoney and not isUniqueItem(itemFrom.name) then
        itemTo.amount = (itemTo.amount or 0) + (itemFrom.amount or 0)
        toTable[toSlot] = itemTo
        fromTable[fromSlot] = nil
    else
        itemFrom.slot = toSlot
        toTable[toSlot] = itemFrom

        if itemTo then
            itemTo.slot = fromSlot
            fromTable[fromSlot] = itemTo
        else
            fromTable[fromSlot] = nil
        end
    end

    if fromContainer == 'player' or toContainer == 'player' then
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        Player.Functions.Save()
    end

    if fromContainer == 'hotbar' or toContainer == 'hotbar' then
        saveHotbar(Player)
    end

    if fromContainer == 'ground' or toContainer == 'ground' then
        syncGroundProp(playerGroundCell[src], src)
    end

    -- On renvoie l'inventaire à jour pour que l'affichage suive la vraie donnée sauvegardée
    sendInventory(src)
end)

-- "Jeter" un objet (menu clic droit) : on le pose directement au sol, sans
-- avoir à le glisser à la souris. On empile sur un tas existant du même objet
-- si possible, sinon on prend la première case libre du stockage au sol.
-- "quantity" est optionnel : absent, on jette toute la pile.
RegisterNetEvent('inventaire:server:dropItem', function(fromSlot, quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot = tonumber(fromSlot)
    quantity = tonumber(quantity)
    if not fromSlot then return end

    local cellId = playerGroundCell[src]
    if not cellId then return end -- pas de zone de sol connue (l'inventaire doit être ouvert)

    local items = Player.PlayerData.items
    local itemFrom = items[fromSlot]
    if not itemFrom then return end

    GroundStashes[cellId] = GroundStashes[cellId] or {}
    local ground = GroundStashes[cellId]

    -- Cas particulier de l'argent : comme dans moveItem, elle n'existe pas
    -- vraiment dans la table tant qu'elle est dans la poche (c'est le solde
    -- réel) ; il faut la retirer du solde et la figer en objet posable.
    if itemFrom.isMoney then
        local available = Player.PlayerData.money['cash'] or 0
        local amount = quantity and math.min(quantity, available) or available
        if amount <= 0 then return end

        local targetSlot = nil
        for slot, gItem in pairs(ground) do
            if gItem and gItem.isMoney then
                targetSlot = slot
                break
            end
        end

        if not targetSlot then
            for i = 1, GROUND_SLOTS do
                if not ground[i] then
                    targetSlot = i
                    break
                end
            end

            if not targetSlot then
                return -- plus de place au sol : on ne touche pas au solde
            end
        end

        Player.Functions.RemoveMoney('cash', amount, 'inventaire-jeter')

        if ground[targetSlot] then
            ground[targetSlot].amount = (ground[targetSlot].amount or 0) + amount
        else
            ground[targetSlot] = { name = '__argent__', isMoney = true, amount = amount, weight = 0, slot = targetSlot }
        end

        ensureMoneySlot(Player)
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        Player.Functions.Save()

        syncGroundProp(cellId, src)
        sendInventory(src)
        return
    end

    local available = itemFrom.amount or 1
    local amount = quantity and math.min(quantity, available) or available
    if amount <= 0 then return end

    local unique = isUniqueItem(itemFrom.name)

    local targetSlot = nil
    if not unique then
        for slot, gItem in pairs(ground) do
            if gItem and gItem.name == itemFrom.name then
                targetSlot = slot
                break
            end
        end
    end

    if targetSlot then
        ground[targetSlot].amount = (ground[targetSlot].amount or 0) + amount
    else
        for i = 1, GROUND_SLOTS do
            if not ground[i] then
                targetSlot = i
                break
            end
        end

        if not targetSlot then
            return -- plus de place au sol à cet endroit
        end

        local dropped = {}
        for k, v in pairs(itemFrom) do dropped[k] = v end
        dropped.amount = amount
        dropped.slot = targetSlot
        ground[targetSlot] = dropped
    end

    if amount >= available then
        items[fromSlot] = nil
    else
        itemFrom.amount = available - amount
        items[fromSlot] = itemFrom
    end

    Player.Functions.SetPlayerData('items', items)
    Player.Functions.Save()

    syncGroundProp(cellId, src)
    sendInventory(src)
end)

-- Utilise l'objet présent dans une case donnée : on retire un exemplaire, et
-- on prévient le client pour jouer l'animation/le message définis dans
-- config/items.lua. "table_" et "save" permettent de réutiliser exactement la
-- même logique pour l'inventaire du joueur et pour la barre rapide, qui sont
-- deux vraies cases mais sauvegardées différemment.
local function performUse(src, Player, table_, slot, save)
    local item = table_[slot]
    if not item or item.isMoney then return end

    local infos = Config.Items[item.name]
    if not infos or not infos.useable then return end

    item.amount = (item.amount or 1) - 1

    if item.amount <= 0 then
        table_[slot] = nil
    else
        table_[slot] = item
    end

    save()

    TriggerClientEvent('inventaire:client:useItemEffect', src, infos)
    sendInventory(src)
end

-- Uniquement depuis son propre inventaire (pas depuis le sol : il faut
-- d'abord ramasser l'objet).
RegisterNetEvent('inventaire:server:useItem', function(slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    slot = tonumber(slot)
    if not slot then return end

    performUse(src, Player, Player.PlayerData.items, slot, function()
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        Player.Functions.Save()
    end)
end)

-- Utilise l'objet posé sur une case de la barre rapide (touche 1 à 5, ou
-- double-clic/menu clic droit dessus dans l'inventaire).
RegisterNetEvent('inventaire:server:useHotbar', function(hotbarSlot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    hotbarSlot = tonumber(hotbarSlot)
    if not hotbarSlot then return end

    performUse(src, Player, getHotbarTable(Player), hotbarSlot, function()
        saveHotbar(Player)
    end)
end)

-- === Commande de test (donner un objet) ===
-- Le client tape "additem nom_objet quantite" dans le F8, et nous transmet
-- la demande via cet event (le F8 seul ne peut pas parler directement au serveur).
RegisterNetEvent('inventaire:server:additem', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = tonumber(amount) or 1

    if not itemName then
        print('Utilisation : additem nom_objet quantite (ex: additem sandwich 2)')
        return
    end

    local success = addItemToPlayer(Player, itemName, amount)

    if success then
        print('>>> ' .. amount .. 'x ' .. itemName .. ' ajouté(s) à l\'inventaire <<<')
        sendInventory(src)
    else
        print('>>> Impossible d\'ajouter "' .. itemName .. '" : objet inconnu dans qb-core/shared/items.lua, ou inventaire plein <<<')
    end
end)

-- === Commande de diagnostic ===
-- Tape "dumpinv" dans le F8 pour voir le contenu exact de ton inventaire
-- dans la console serveur (utile uniquement pour déboguer).
RegisterNetEvent('inventaire:server:dumpinv', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print('>>> dumpinv : joueur introuvable <<<')
        return
    end

    print('>>> === CONTENU BRUT DE L\'INVENTAIRE === <<<')
    print(json.encode(Player.PlayerData.items))

    print('>>> === CE QUI EST ENVOYÉ À L\'INTERFACE (après config/items.lua) === <<<')
    print(json.encode(buildItemList(Player.PlayerData.items, TOTAL_SLOTS, Player)))

    local cellId = playerGroundCell[src]
    print('>>> === SOL (case ' .. tostring(cellId) .. ') === <<<')
    print(json.encode(cellId and GroundStashes[cellId] or {}))

    print('>>> === BARRE RAPIDE === <<<')
    print(json.encode(getHotbarTable(Player)))
    print('>>> === FIN === <<<')
end)