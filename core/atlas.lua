
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

--------------------------------------------------
-- Atlas validation and image loading
--------------------------------------------------

function Atlas.validate_mod(mod)

    if not mod.pending_registry then
        return false, "Mod registry is not initialized."
    end

    for atlas_id, atlas in pairs(mod.pending_registry.Atlases) do

        -- Check if file exists
        local info = love.filesystem.getInfo(atlas.path)

        if not info or info.type ~= "file" then
            return false,
                "Atlas image not found: " .. atlas.path
        end

        -- Load image safely
        local success, image = pcall(
            love.graphics.newImage,
            atlas.path
        )

        if not success then
            return false,
                "Could not load Atlas " .. atlas_id ..
                ": " .. tostring(image)
        end

        -- Get image dimensions
        local width, height = image:getDimensions()

        -- Validate sprite dimensions
        if width < atlas.px or height < atlas.py then
            return false,
                "Atlas image is smaller than its sprite dimensions: " ..
                atlas_id
        end

        if width % atlas.px ~= 0 or height % atlas.py ~= 0 then
            return false,
                "Atlas dimensions are not divisible by px/py: " ..
                atlas_id
        end

        -- Store loaded image
        atlas.image = image
        atlas.width = width
        atlas.height = height

        NSMDS.log(
            "Loaded Atlas: " .. atlas_id ..
            " (" .. width .. "x" .. height .. ")"
        )
    end

    return true
end
--------------------------------------------------
-- Atlas injection
--------------------------------------------------

function Atlas.inject(game, atlases, NSMDS)

    -- Balatro stores asset atlases in the global G table
    local asset_atlas = G and G.ASSET_ATLAS

    if type(asset_atlas) ~= "table" then
        NSMDS.log_error(
            "Atlas",
            "Balatro's G.ASSET_ATLAS table was not found."
        )

        return false
    end

    local atlas_ids = {}

    for id in pairs(atlases) do
        table.insert(atlas_ids, id)
    end

    table.sort(atlas_ids)

    local injected = 0

    for _, id in ipairs(atlas_ids) do

        local atlas = atlases[id]

        if asset_atlas[id] then

            NSMDS.log_error(
                "Atlas",
                "Atlas already exists: " .. id
            )

        elseif not atlas.image then

            NSMDS.log_error(
                "Atlas",
                "Atlas image is not loaded: " .. id
            )

        else

            asset_atlas[id] = {
                name = id,

                image = atlas.image,

                px = atlas.px,
                py = atlas.py,

                columns = atlas.width / atlas.px,
                rows = atlas.height / atlas.py,

                atlas_table = "ASSET_ATLAS"
            }

            injected = injected + 1

            NSMDS.log(
                "Injected Atlas: " .. id
            )
        end
    end

    NSMDS.log(
        "Atlas injection finished. Injected: " .. injected
    )

    return true
end
return Atlas
