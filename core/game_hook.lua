
--[[
    NSMDS - Not SteamModed
    Core / Game Hook
]]

local GameHook = {}

GameHook.installed = false

local function inject_jokers(game)

    local centers = game.P_CENTERS
    local joker_pool = game.P_CENTER_POOLS
        and game.P_CENTER_POOLS["Joker"]

    local rarity_pools = game.P_JOKER_RARITY_POOLS

    if type(centers) ~= "table" or
       type(joker_pool) ~= "table" or
       type(rarity_pools) ~= "table" then

        NSMDS.log_error(
            "GameHook",
            "Could not find Balatro's Joker pools."
        )

        return
    end

    local registered = NSMDS.Registry.Jokers
    local joker_ids = {}

    for id in pairs(registered) do
        table.insert(joker_ids, id)
    end

    table.sort(joker_ids)

    local max_order = 0

    for _, center in ipairs(joker_pool) do
        if type(center.order) == "number" and
           center.order > max_order then

            max_order = center.order
        end
    end

    local injected = 0

    for _, id in ipairs(joker_ids) do

        local joker = registered[id]

        local rarity = tonumber(joker.rarity)
        local cost = tonumber(joker.cost)

        if not rarity or rarity % 1 ~= 0 or
           rarity < 1 or rarity > 4 then

            NSMDS.log_error(
                "GameHook",
                "Invalid rarity for Joker: " .. id
            )

        elseif not cost then

            NSMDS.log_error(
                "GameHook",
                "Invalid cost for Joker: " .. id
            )

        else

            local center_key = "j_nsmds_" .. id

            if centers[center_key] then

                NSMDS.log_error(
                    "GameHook",
                    "Joker center already exists: " .. center_key
                )

            else

                max_order = max_order + 1

                local center = {
                    key = center_key,

                    order = max_order,

                    unlocked = true,
                    discovered = true,

                    blueprint_compat = joker.blueprint_compat,
                    perishable_compat = joker.perishable_compat,
                    eternal_compat = joker.eternal_compat,

                    calculate = joker.calculate,

                    rarity = rarity,
                    cost = cost,

                    name = joker.name,

                    pos = {
                        x = 0,
                        y = 0
                    },

                    set = "Joker",
                    effect = "",

                    cost_mult = 1.0,

                    config = {}
                }

                centers[center_key] = center
                table.insert(joker_pool, center)

                table.insert(
                    rarity_pools[rarity],
                    center
                )

                injected = injected + 1

                NSMDS.log(
                    "Injected Joker: " ..
                    joker.name ..
                    " (" .. center_key .. ")"
                )

            end
        end
    end

    table.sort(joker_pool, function(a, b)
        return a.order < b.order
    end)

    for rarity = 1, 4 do

        local pool = rarity_pools[rarity]

        table.sort(pool, function(a, b)
            return a.order < b.order
        end)

    end

    NSMDS.log(
        "Joker injection finished. Injected: " .. injected
    )
end

function GameHook.install()

    if GameHook.installed then
        return true
    end

    if type(Game) ~= "table" or
       type(Game.init_item_prototypes) ~= "function" then

        NSMDS.log_error(
            "GameHook",
            "Could not find Game.init_item_prototypes()."
        )

        return false
    end

    if type(Card) ~= "table" or
       type(Card.calculate_joker) ~= "function" then

        NSMDS.log_error(
            "GameHook",
            "Could not find Card.calculate_joker()."
        )

        return false
    end

    -- Hook de las habilidades personalizadas
    local original_calculate_joker = Card.calculate_joker

    Card.calculate_joker = function(self, context)

        if self.debuff then
            return nil
        end

        local result = original_calculate_joker(self, context)

        if result ~= nil then
            return result
        end

        local center = self.config and self.config.center

        if type(center) == "table" and
           type(center.calculate) == "function" then

            if context and context.blueprint and
               center.blueprint_compat == false then
                return nil
            end

            return center.calculate(center, self, context)
        end

        return result
    end

    NSMDS.log("Card.calculate_joker() hook installed.")

    -- Hook de inicialización del juego
    local original = Game.init_item_prototypes

    Game.init_item_prototypes = function(self, ...)

        original(self, ...)

        NSMDS.log(
            "Game.init_item_prototypes() intercepted successfully."
        )

        inject_jokers(self)

    end

    GameHook.installed = true

    NSMDS.log("Game initialization hook installed.")

    return true
end

return GameHook
