
--[[
    NSMDS - Mod Menu
    Main mod management screen
]]

local ModMenu = {}

local ModManager = require("core.mod_manager")

ModMenu.selected_mod_id = nil

--------------------------------------------------
-- Text helper
--------------------------------------------------

local function create_text(text, scale, colour)

    return {
        n = G.UIT.T,
        config = {
            text = tostring(text or ""),
            scale = scale or 0.45,
            colour = colour or G.C.UI.TEXT_LIGHT
        }
    }

end

--------------------------------------------------
-- Mod icon loader
--------------------------------------------------

local function load_mod_icon(mod)

    if not mod then
        return nil
    end

    -- Avoid loading the same icon multiple times
    if mod.icon_loaded then
        return mod.icon
    end

    mod.icon_loaded = true

    if not mod.path then
        return nil
    end

    local icon_path = mod.path .. "/icon.png"

    -- Check whether the icon exists
    local info = love.filesystem.getInfo(icon_path)

    if not info or info.type ~= "file" then

        NSMDS.log("No icon found for " .. mod.name)

        return nil
    end

    -- Load image
    local success, result = pcall(
        love.graphics.newImage,
        icon_path
    )

    if not success then

        NSMDS.log_error(
            "ModMenu",
            "Could not load icon for " .. mod.name .. ": " .. tostring(result)
        )

        return nil
    end

    mod.icon = result

    NSMDS.log("Loaded icon for " .. mod.name)

    return mod.icon

end

--------------------------------------------------
-- Create mod icon sprite
--------------------------------------------------

local function create_mod_icon(mod)

    if not mod or not mod.icon then
        return create_text("ICON", 0.3)
    end

    local image = mod.icon

    local image_width = image:getWidth()
    local image_height = image:getHeight()

    -- Fit image inside a 1.1 x 1.1 area
    local size = 1.1
    local aspect = image_width / image_height

    local width = size
    local height = size

    if aspect > 1 then
        height = size / aspect
    else
        width = size * aspect
    end

    local success, sprite = pcall(function()

        return Sprite(
            0,
            0,
            width,
            height,
            {
                image = image,
                px = image_width,
                py = image_height
            },
            {
                x = 0,
                y = 0
            }
        )

    end)

    if not success then

        NSMDS.log_error(
            "ModMenu",
            "Could not create icon sprite: " .. tostring(sprite)
        )

        return create_text("ICON", 0.3)
    end

    return {
        n = G.UIT.O,
        config = {
            object = sprite
        }
    }

end

--------------------------------------------------
-- Find selected mod
--------------------------------------------------

local function get_selected_mod()

    local mods = NSMDS.Mods or {}

    -- Try to preserve the previous selection
    if ModMenu.selected_mod_id then

        for _, mod in ipairs(mods) do

            if mod.metadata and
                mod.metadata.id == ModMenu.selected_mod_id then

                return mod
            end

        end

    end

    -- Select first mod by default
    local mod = mods[1]

    if mod and mod.metadata then
        ModMenu.selected_mod_id = mod.metadata.id
    end

    return mod
end

--------------------------------------------------
-- Mod selection
--------------------------------------------------

function ModMenu.select_mod(mod)

    if not mod or not mod.metadata then
        return
    end

    ModMenu.selected_mod_id = mod.metadata.id

    G.FUNCS.overlay_menu({
        definition = ModMenu.create()
    })

end

--------------------------------------------------
-- Toggle mod state
--------------------------------------------------

function ModMenu.toggle_mod(mod)

    if not mod then
        return
    end

    local enabled = ModManager.is_enabled(mod)

    local success, err = ModManager.set_enabled(
        mod,
        not enabled
    )

    if not success then

        NSMDS.log_error("ModMenu", err)

        return
    end

    NSMDS.log(
        (not enabled and "Enabled: " or "Disabled: ") ..
        mod.name
    )

    -- Refresh the interface
    G.FUNCS.overlay_menu({
        definition = ModMenu.create()
    })

end

--------------------------------------------------
-- Mod list entry
--------------------------------------------------

local function create_mod_list_entry(mod)

    local metadata = mod.metadata or {}

    local name = metadata.name or mod.name or "Unknown"
    local enabled = ModManager.is_enabled(mod)

    local selected = ModMenu.selected_mod_id ==
        metadata.id

    local colour = selected and G.C.BLUE or G.C.BLACK

    return {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.04
        },
        nodes = {
            UIBox_button({
                label = {name},
                button = "nsmds_select_mod",
                ref_table = mod,
                colour = colour,
                minw = 3.5,
                minh = 0.65,
                scale = 0.4
            })
        }
    }

end

--------------------------------------------------
-- Mod information panel
--------------------------------------------------

local function create_mod_info(mod)

    if not mod then

        return {
            n = G.UIT.C,
            config = {
                align = "cm",
                padding = 0.3,
                colour = G.C.BLACK,
                r = 0.1,
                minw = 7.5,
                minh = 5
            },
            nodes = {
                create_text("Select a mod", 0.5)
            }
        }

    end

    local metadata = mod.metadata or {}

    local enabled = ModManager.is_enabled(mod)

    local name = metadata.name or mod.name or "Unknown"
    local id = metadata.id or "Unknown"
    local author = metadata.author or "Unknown"
    local version = metadata.version or "Unknown"
    local description = metadata.description or "No description."

    local status = enabled and "Enabled" or "Disabled"

    local toggle_label = enabled and "Disable Mod" or "Enable Mod"

    return {
        n = G.UIT.C,
        config = {
            align = "cm",
            padding = 0.2,
            colour = G.C.BLACK,
            r = 0.1,
            minw = 7.5,
            minh = 5
        },
        nodes = {

            -- Header and icon
            {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0.15
                },
                nodes = {

                    {
                        n = G.UIT.C,
                        config = {
                            align = "cl",
                            minw = 5
                        },
                        nodes = {
                            create_text(name, 0.65)
                        }
                    },

                    -- Icon
                    {
                        n = G.UIT.C,
                        config = {
                            align = "cm",
                            colour = G.C.UI.BACKGROUND,
                            r = 0.1,
                            minw = 1.3,
                            minh = 1.3
                        },
                        nodes = {
                            create_mod_icon(mod)
                        }
                    }

                }
            },

            {
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.1
                },
                nodes = {
                    create_text("ID: " .. id, 0.35)
                }
            },

            {
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.1
                },
                nodes = {
                    create_text("Author: " .. author, 0.4)
                }
            },

            {
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.1
                },
                nodes = {
                    create_text("Version: " .. version, 0.4)
                }
            },

            {
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.1
                },
                nodes = {
                    create_text("Status: " .. status, 0.4)
                }
            },

            {
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.15
                },
                nodes = {
                    create_text("Description:", 0.4)
                }
            },

            {
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.1
                },
                nodes = {
                    create_text(description, 0.35)
                }
            },

            -- Spacer
            {
                n = G.UIT.R,
                config = {
                    minw = 1,
                    minh = 0.5
                },
                nodes = {}
            },

            -- Enable / Disable button
            {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0.15
                },
                nodes = {
                    UIBox_button({
                        label = {toggle_label},
                        button = "nsmds_toggle_mod",
                        ref_table = mod,
                        colour = enabled and G.C.RED or G.C.GREEN,
                        minw = 3.5,
                        minh = 0.8,
                        scale = 0.45
                    })
                }
            }

        }
    }

end

--------------------------------------------------
-- Main interface
--------------------------------------------------

function ModMenu.create()

    local mods = NSMDS.Mods or {}

    local selected_mod = get_selected_mod()

    if selected_mod then
        load_mod_icon(selected_mod)
    end

    local contents = {}

    -- Title
    table.insert(contents, {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.15
        },
        nodes = {
            create_text("NSMDS - Mod Manager", 0.7)
        }
    })

    -- Main content
    local mod_list = {}

    for _, mod in ipairs(mods) do
        table.insert(
            mod_list,
            create_mod_list_entry(mod)
        )
    end

    if #mods == 0 then

        table.insert(mod_list, {
            n = G.UIT.R,
            config = {
                align = "cm",
                padding = 0.2
            },
            nodes = {
                create_text("No mods found.", 0.4)
            }
        })

    end

    table.insert(contents, {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.15
        },
        nodes = {

            -- Left panel: mod list
            {
                n = G.UIT.C,
                config = {
                    align = "cm",
                    padding = 0.15,
                    colour = G.C.BLACK,
                    r = 0.1,
                    minw = 4
                },
                nodes = {

                    {
                        n = G.UIT.R,
                        config = {
                            align = "cm",
                            padding = 0.15
                        },
                        nodes = {
                            create_text("MODS", 0.5)
                        }
                    },

                    {
                        n = G.UIT.R,
                        config = {
                            align = "cm",
                            padding = 0.1
                        },
                        nodes = mod_list
                    }

                }
            },

            -- Right panel: selected mod information
            create_mod_info(selected_mod)

        }
    })

    return create_UIBox_generic_options({
        back_func = "exit_overlay_menu",
        contents = contents
    })

end

--------------------------------------------------
-- UI callbacks
--------------------------------------------------

local function register_callbacks()

    G.FUNCS.nsmds_select_mod = function(e)

        local mod = e.config.ref_table

        ModMenu.select_mod(mod)

    end

    G.FUNCS.nsmds_toggle_mod = function(e)

        local mod = e.config.ref_table

        ModMenu.toggle_mod(mod)

    end

end

--------------------------------------------------
-- Open menu
--------------------------------------------------

function ModMenu.open()

    register_callbacks()

    G.FUNCS.overlay_menu({
        definition = ModMenu.create()
    })

end

return ModMenu
