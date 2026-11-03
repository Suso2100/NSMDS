
--[[
    NSMDS - UI Hook
    Runtime UI modifications
]]

local ModMenu = require("core.mod_menu")
local UIHook = {}

UIHook.installed = false

function UIHook.install()

    if UIHook.installed then
        return true
    end

    local original = create_UIBox_main_menu_buttons

    if type(original) ~= "function" then
        print("[NSMDS] [UI] Could not find main menu function.")
        return false
    end

    -- Register Mods button action
    G.FUNCS.nsmds_open_mods = function(e)
        ModMenu.open()
    end

    create_UIBox_main_menu_buttons = function(...)

        -- Call original Balatro function
        local result = original(...)

        print("[NSMDS] [UI] Main menu function intercepted.")

        -- Locate the Options / Quit container
        local buttons_container = result.nodes[1].nodes[1].nodes[2]

        if buttons_container then

            local mods_button = UIBox_button({
                label = {"Mods"},
                button = "nsmds_open_mods",
                colour = G.C.BLACK,
                minw = 2.7,
                minh = 0.9,
                scale = 0.5
            })

            -- Replace the original empty slot
            buttons_container.nodes[2] = mods_button

            print("[NSMDS] [UI] Mods button inserted.")

        else
            print("[NSMDS] [UI] Could not find button container.")
        end

        return result
    end

    UIHook.installed = true

    print("[NSMDS] [UI] Main menu hook installed.")

    return true
end

return UIHook
