-- Script temporaire pour le développement : appuie sur F6 pour te ressusciter
-- et te remettre en pleine santé instantanément, sans avoir besoin de chat.

RegisterKeyMapping('revive', 'Se ressusciter (debug)', 'keyboard', 'F6')

RegisterCommand('revive', function()
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true)

    print('^2[revive-debug]^7 Personnage ressuscité et soigné.')
end, false)
