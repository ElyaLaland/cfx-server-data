CreateThread(function()
    while true do
        local sleep = 1000
        if LocalPlayer.state.isLoggedIn then
            sleep = (1000 * 60) * QBCore.Config.UpdateInterval
            TriggerServerEvent('QBCore:UpdatePlayer')
        end
        Wait(sleep)
    end
end)

-- Désactivé à la demande d'Elya : courir longtemps faisait tomber la faim/soif
-- à 0, ce qui déclenchait cette perte de vie automatique (5 à 10 points de vie
-- toutes les 5 secondes) jusqu'à la mort. La faim et la soif continuent de
-- baisser normalement, elles ne font simplement plus perdre de vie une fois à 0.
--
-- CreateThread(function()
--     while true do
--         if LocalPlayer.state.isLoggedIn then
--             if (QBCore.PlayerData.metadata['hunger'] <= 0 or QBCore.PlayerData.metadata['thirst'] <= 0) and not (QBCore.PlayerData.metadata['isdead'] or QBCore.PlayerData.metadata['inlaststand']) then
--                 local ped = PlayerPedId()
--                 local currentHealth = GetEntityHealth(ped)
--                 local decreaseThreshold = math.random(5, 10)
--                 SetEntityHealth(ped, currentHealth - decreaseThreshold)
--             end
--         end
--         Wait(QBCore.Config.StatusInterval)
--     end
-- end)
