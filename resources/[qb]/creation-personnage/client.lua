-- Dès que la session réseau est prête, on demande au serveur de nous
-- connecter automatiquement (créer ou recharger notre personnage unique).

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    Wait(1000) -- petite marge de sécurité

    TriggerServerEvent('creationperso:server:login')
end)
