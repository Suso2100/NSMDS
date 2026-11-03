
--[[
    NSMDS - Mod Manager
    Persistent mod state management
]]

local ModManager = {}

ModManager.SAVE_DIR = "nsmds"
ModManager.DISABLED_DIR = "nsmds/disabled_mods"

--------------------------------------------------
-- Internal helpers
--------------------------------------------------

local function get_mod_id(mod)

    if not mod or not mod.metadata then
        return nil
    end

    local id = mod.metadata.id

    -- Restrict IDs to safe filename characters
    if type(id) ~= "string" or
        not id:match("^[%w_-]+$") then
        return nil
    end

    return id
end

local function get_disabled_path(mod)

    local id = get_mod_id(mod)

    if not id then
        return nil
    end

    return ModManager.DISABLED_DIR .. "/" .. id
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function ModManager.initialize()

    local success = love.filesystem.createDirectory(
        ModManager.DISABLED_DIR
    )

    if not success and
        love.filesystem.getInfo(ModManager.DISABLED_DIR) == nil then

        return false, "Could not create disabled mods directory."
    end

    return true
end

--------------------------------------------------
-- Mod state
--------------------------------------------------

function ModManager.is_enabled(mod)

    local disabled_path = get_disabled_path(mod)

    if not disabled_path then
        return false
    end

    return love.filesystem.getInfo(disabled_path) == nil
end

--------------------------------------------------
-- Enable / Disable
--------------------------------------------------

function ModManager.set_enabled(mod, enabled)

    local disabled_path = get_disabled_path(mod)

    if not disabled_path then
        return false, "Invalid mod ID."
    end

    if enabled then

        local info = love.filesystem.getInfo(disabled_path)

        if info then
            local success, err = love.filesystem.remove(disabled_path)

            if not success then
                return false, err or "Could not enable mod."
            end
        end

    else

        local success, err = love.filesystem.write(
            disabled_path,
            ""
        )

        if not success then
            return false, err or "Could not disable mod."
        end

    end

    return true
end

return ModManager
