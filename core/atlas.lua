
--[[
    NSMDS - Not SteamModed
    Core / Atlas
]]

local Atlas = {}

--------------------------------------------------
-- Validation helpers
--------------------------------------------------

local function is_positive_integer(value)
    return type(value) == "number"
        and value > 0
        and value % 1 == 0
end

local function is_relative_path(path)

    if path:sub(1, 1) == "/" then
        return false
    end

    if path:find("\\", 1, true) then
        return false
    end

    for segment in path:gmatch("[^/]+") do
        if segment == ".." then
            return false
        end
    end

    return true
end

--------------------------------------------------
-- Atlas registration API
--------------------------------------------------

function Atlas.initialize(NSMDS)

    function NSMDS.Atlas(data)

        -- Check mod context
        if not NSMDS.CurrentMod then
            error("NSMDS.Atlas() can only be called inside a mod's init.lua.")
        end

        -- Validate input
        if type(data) ~= "table" then
            error("Atlas data must be a table.")
        end

        if type(data.key) ~= "string" or data.key == "" then
            error("Atlas requires a valid key.")
        end

        if type(data.path) ~= "string" or data.path == "" then
            error("Atlas requires a valid image path.")
        end

        if not is_relative_path(data.path) then
            error("Atlas path must be relative to the mod directory.")
        end

        if not is_positive_integer(data.px) then
            error("Atlas px must be a positive integer.")
        end

        if not is_positive_integer(data.py) then
            error("Atlas py must be a positive integer.")
        end

        local mod = NSMDS.CurrentMod

        if not mod.metadata or not mod.metadata.id then
            error("Current mod has no valid ID.")
        end

        if not mod.pending_registry then
            error("Mod registry is not initialized.")
        end

        -- Generate namespaced ID
        local atlas_id = mod.metadata.id .. "_" .. data.key

        -- Check duplicate keys
        if NSMDS.Registry.Atlases[atlas_id]
            or mod.pending_registry.Atlases[atlas_id] then

            error("Duplicate Atlas key: " .. atlas_id)
        end

        -- Create atlas definition
        local atlas = {
            key = data.key,
            id = atlas_id,
            mod_id = mod.metadata.id,

            path = mod.path .. "/" .. data.path,
            relative_path = data.path,

            px = data.px,
            py = data.py,

            type = "asset"
        }

        -- Store in temporary registry
        mod.pending_registry.Atlases[atlas_id] = atlas

        NSMDS.log(
            "Registered Atlas: " ..
            atlas_id
        )

        return atlas
    end
end

return Atlas
