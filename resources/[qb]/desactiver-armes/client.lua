-- Désactive le menu de sélection d'armes natif de GTA (la molette qui s'ouvre
-- avec le clic molette, et le changement d'arme avec la molette qui tourne),
-- ET la sélection directe d'une arme sur les touches 1 à 5 (qui servent
-- maintenant à la barre rapide de l'inventaire).
--
-- Ça reste bloqué même si un joueur a réassigné ces actions à d'autres
-- touches dans ses propres paramètres : on désactive l'action du jeu
-- elle-même, pas une touche précise.

local DISABLED_CONTROLS = {
    37,  -- INPUT_SELECT_WEAPON          (ouvre le menu armes)
    14,  -- INPUT_SELECT_NEXT_WEAPON     (molette vers le haut)
    15,  -- INPUT_SELECT_PREV_WEAPON     (molette vers le bas)
    16,  -- INPUT_WEAPON_WHEEL_NEXT
    17,  -- INPUT_WEAPON_WHEEL_PREV
    157, -- INPUT_SELECT_WEAPON_UNARMED  (touche 1)
    158, -- INPUT_SELECT_WEAPON_MELEE    (touche 2)
    159, -- INPUT_SELECT_WEAPON_HANDGUN  (touche 3)
    160, -- INPUT_SELECT_WEAPON_SHOTGUN  (touche 4)
    161  -- INPUT_SELECT_WEAPON_SMG      (touche 5)
}

CreateThread(function()
    while true do
        Wait(0)
        for _, control in ipairs(DISABLED_CONTROLS) do
            DisableControlAction(0, control, true)
        end
    end
end)
