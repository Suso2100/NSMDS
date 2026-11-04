NSMDS.Joker({
    key = "my_first_joker",
    name = "My First Joker",
    rarity = 1,
    cost = 4,

    calculate = function(self, card, context)
        if context.joker_main then
            return {
                chip_mod = 50,
                mult_mod = 10,
                Xmult_mod = 2,
                message = "¡Potenciado!"
            }
        end
    end
})
NSMDS.Joker({
    key = "erers",
    name = "erers",

    rarity = 3,
    cost = 7,

    calculate = function(self, card, context)
        if context.joker_main then
            return {
                mult_mod = 10
            }
        end
    end
})
print("Total Jokers:", NSMDS.get_joker_count())