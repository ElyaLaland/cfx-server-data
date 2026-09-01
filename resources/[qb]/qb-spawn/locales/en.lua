local Translations = {
    ui = {
        last_location = "Dernière position",
        confirm = "Confirmer",
        where_would_you_like_to_start = "Où veux-tu commencer ?",
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})