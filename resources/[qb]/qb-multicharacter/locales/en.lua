local Translations = {
    notifications = {
        ["char_deleted"] = "Personnage supprimé !",
        ["deleted_other_char"] = "Vous avez supprimé avec succès le personnage ayant le citizen id %{citizenid}.",
        ["forgot_citizenid"] = "Vous avez oublié de saisir un citizen id !",
    },

    commands = {
        -- /deletechar
        ["deletechar_description"] = "Supprime le personnage d'un autre joueur",
        ["citizenid"] = "Citizen ID",
        ["citizenid_help"] = "Le Citizen ID du personnage à supprimer",

        -- /logout
        ["logout_description"] = "Déconnexion du personnage (Admin uniquement)",

        -- /closeNUI
        ["closeNUI_description"] = "Fermer l'interface Multi-personnages"
    },

    misc = {
        ["droppedplayer"] = "Vous avez été déconnecté de QBCore"
    },

    ui = {
        -- Main
        characters_header = "Mes personnages",
        emptyslot = "Emplacement vide",
        play_button = "Jouer",
        create_button = "Créer le personnage",
        delete_button = "Supprimer le personnage",

        -- Character Information
        charinfo_header = "Informations du personnage",
        charinfo_description = "Sélectionne un emplacement pour voir toutes les informations de ton personnage.",
        name = "Nom",
        male = "Homme",
        female = "Femme",
        firstname = "Prénom",
        lastname = "Nom",
        nationality = "Nationalité",
        gender = "Genre",
        birthdate = "Date de naissance",
        job = "Métier",
        jobgrade = "Grade",
        cash = "Espèces",
        bank = "Banque",
        phonenumber = "Numéro de téléphone",
        accountnumber = "Numéro de compte",

        chardel_header = "Création de personnage",

        -- Delete character
        deletechar_header = "Supprimer le personnage",
        deletechar_description = "Es-tu sûr(e) de vouloir supprimer ton personnage ?",

        -- Buttons
        cancel = "Annuler",
        confirm = "Confirmer",

        -- Loading Text
        retrieving_playerdata = "Récupération des données du joueur",
        validating_playerdata = "Validation des données du joueur",
        retrieving_characters = "Récupération des personnages",
        validating_characters = "Validation des personnages",

        -- Notifications
        ran_into_issue = "Un problème est survenu",
        profanity = "Il semblerait que tu essaies d'utiliser un mot inapproprié dans ton nom ou ta nationalité !",
        forgotten_field = "Il semblerait que tu aies oublié de remplir un ou plusieurs champs !"
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})