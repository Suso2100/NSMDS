
--[[
    NSMDS - Not SteamModed
    Core / Loader
    Version: 0.4.0
]]

local ModManager = require("core.mod_manager")
local GameHook = require("core.game_hook")
local UIHook = require("core.ui_hook")
local json = require("core.json")

NSMDS = NSMDS or {}

NSMDS.VERSION = "0.2.0"
NSMDS.MOD_DIR = "mods"

-- Mod management
NSMDS.Mods = {}
NSMDS.Loaded = {}
NSMDS.Failed = {}

-- Internal registry
NSMDS.Registry = {
    Mods = {},
    Jokers = {}
}

NSMDS.CurrentMod = nil

--------------------------------------------------
-- Logging
--------------------------------------------------

function NSMDS.log(message)
    print("[NSMDS] " .. tostring(message))
end

function NSMDS.log_error(mod_name, message)
    print("[NSMDS] [ERROR] " ..
        tostring(mod_name) .. ": " .. tostring(message))
end

--------------------------------------------------
-- Mod declaration API
--------------------------------------------------

function NSMDS.Mod(metadata)

    if not NSMDS.CurrentMod then
        error("NSMDS.Mod() can only be called inside a mod's init.lua.")
    end

    local mod = NSMDS.CurrentMod

    if type(metadata) ~= "table" then
        error("Mod metadata must be a table.")
    end

    -- Metadata is now loaded from mod.json.
    -- This keeps compatibility with older init.lua files.
    if mod.metadata then

        if metadata.id ~= mod.metadata.id then
            error("Mod ID does not match mod.json.")
        end

        if metadata.name ~= mod.metadata.name then
            error("Mod name does not match mod.json.")
        end

        return mod.metadata
    end

    error("Mod metadata must be declared in mod.json.")
end

--------------------------------------------------
-- Joker API
--------------------------------------------------

function NSMDS.Joker(data)

    if not NSMDS.CurrentMod then
        error("NSMDS.Joker() can only be called inside a mod's init.lua.")
    end

    if type(data) ~= "table" then
        error("Joker data must be a table.")
    end

    if type(data.key) ~= "string" or data.key == "" then
        error("Joker requires a valid key.")
    end

    if data.calculate ~= nil and type(data.calculate) ~= "function" then
        error("Joker calculate must be a function.")
    end

    local mod = NSMDS.CurrentMod
    local joker_id = mod.metadata.id .. "_" .. data.key

    if NSMDS.Registry.Jokers[joker_id] then
        error("Duplicate Joker key: " .. joker_id)
    end

    local joker = {
        key = data.key,
        id = joker_id,
        mod_id = mod.metadata.id,

        name = data.name or data.key,

        rarity = data.rarity or 1,
        cost = data.cost or 4,

        blueprint_compat = data.blueprint_compat ~= false,
        eternal_compat = data.eternal_compat ~= false,
        perishable_compat = data.perishable_compat ~= false,

        calculate = data.calculate,

        description = data.description or {}
    }

    NSMDS.Registry.Jokers[joker_id] = joker

    NSMDS.log(
        "Registered Joker: " .. joker.name ..
        " (" .. joker_id .. ")"
    )

    return joker
end

--------------------------------------------------
-- Joker Registry API
--------------------------------------------------

function NSMDS.get_registered_jokers()

    local jokers = {}

    for id, joker in pairs(NSMDS.Registry.Jokers) do
        jokers[id] = joker
    end

    return jokers
end

function NSMDS.get_joker_count()

    local count = 0

    for _ in pairs(NSMDS.Registry.Jokers) do
        count = count + 1
    end

    return count
end


--------------------------------------------------
-- Directory initialization
--------------------------------------------------

function NSMDS.initialize_directory()

    local path = NSMDS.MOD_DIR
    local info = love.filesystem.getInfo(path)

    if not info then

        local success = love.filesystem.createDirectory(path)

        if not success then
            NSMDS.log_error(
                "Loader",
                "Could not create mods directory: " .. path
            )

            return false
        end

        NSMDS.log("Created mods directory: " .. path)

    elseif info.type ~= "directory" then

        NSMDS.log_error(
            "Loader",
            "Mods path exists but is not a directory."
        )

        return false
    end

    return true
end

--------------------------------------------------
-- Metadata loading
--------------------------------------------------

function NSMDS.load_metadata(mod_path)

    local metadata_path = mod_path .. "/mod.json"

    local info = love.filesystem.getInfo(metadata_path)

    if not info or info.type ~= "file" then
        return nil, "Missing mod.json."
    end

    local contents, read_error = love.filesystem.read(metadata_path)

    if not contents then
        return nil, read_error or "Could not read mod.json."
    end

    local success, metadata = pcall(json.decode, contents)

    if not success then
        return nil, "Invalid mod.json: " .. tostring(metadata)
    end

    if type(metadata) ~= "table" then
        return nil, "mod.json must contain a JSON object."
    end

    if type(metadata.id) ~= "string" or metadata.id == "" then
        return nil, "mod.json requires a valid 'id'."
    end

    if type(metadata.name) ~= "string" or metadata.name == "" then
        return nil, "mod.json requires a valid 'name'."
    end

    -- Create an independent metadata table
    local info_table = {
        id = metadata.id,
        name = metadata.name,
        author = metadata.author or "Unknown",
        version = metadata.version or "1.0.0",
        description = metadata.description or ""
    }

    return info_table
end

--------------------------------------------------
-- Mod discovery
--------------------------------------------------

function NSMDS.discover_mods()

    NSMDS.Mods = {}

    local items = love.filesystem.getDirectoryItems(
        NSMDS.MOD_DIR
    )

    table.sort(items)

    for _, folder in ipairs(items) do

        local mod_path = NSMDS.MOD_DIR .. "/" .. folder
        local info = love.filesystem.getInfo(mod_path)

        if info and info.type == "directory" then

            local entry_path = mod_path .. "/init.lua"
            local entry_info = love.filesystem.getInfo(entry_path)

            if entry_info and entry_info.type == "file" then

                local metadata, metadata_error =
                    NSMDS.load_metadata(mod_path)

                local mod = {
                    folder = folder,
                    name = metadata and metadata.name or folder,
                    path = mod_path,
                    entry = entry_path,
                    status = "discovered",
                    metadata = metadata,
                    error = nil
                }

                if metadata_error then
                    mod.metadata_error = metadata_error
                end

                table.insert(NSMDS.Mods, mod)

                NSMDS.log("Found mod: " .. mod.name)
            end
        end
    end

    NSMDS.log(
        "Discovered " .. #NSMDS.Mods .. " mod(s)."
    )

    return NSMDS.Mods
end



--------------------------------------------------
-- Individual mod loading
--------------------------------------------------

function NSMDS.load_mod(mod)

    -- Check metadata
    if mod.metadata_error then

        mod.status = "failed"
        mod.error = mod.metadata_error

        table.insert(NSMDS.Failed, mod)

        NSMDS.log_error(mod.name, mod.error)

        return false
    end

    -- Check duplicate IDs
    if NSMDS.Registry.Mods[mod.metadata.id] then

        mod.status = "failed"
        mod.error = "Duplicate mod ID: " .. mod.metadata.id

        table.insert(NSMDS.Failed, mod)

        NSMDS.log_error(mod.name, mod.error)

        return false
    end

    -- Check if mod is disabled
    if not ModManager.is_enabled(mod) then

        mod.status = "disabled"

        NSMDS.log("Skipping disabled mod: " .. mod.name)

        return false
    end

    NSMDS.log("Loading mod: " .. mod.name)

    local chunk, load_error = love.filesystem.load(
        mod.entry
    )

    if not chunk then

        mod.status = "failed"
        mod.error = load_error

        table.insert(NSMDS.Failed, mod)

        NSMDS.log_error(mod.name, load_error)

        return false
    end

    -- Set current mod context
    NSMDS.CurrentMod = mod

    local success, result = xpcall(
        function()
            return chunk(NSMDS)
        end,

        function(err)
            return debug.traceback(tostring(err), 2)
        end
    )

    -- Clear current mod context
    NSMDS.CurrentMod = nil

    if not success then

        mod.status = "failed"
        mod.error = result

        table.insert(NSMDS.Failed, mod)

        NSMDS.log_error(mod.name, result)

        return false
    end

    -- Register successfully loaded mod
    NSMDS.Registry.Mods[mod.metadata.id] = mod

    mod.status = "loaded"
    mod.result = result

    table.insert(NSMDS.Loaded, mod)

    NSMDS.log(
        "Successfully loaded: " .. mod.metadata.name ..
        " v" .. mod.metadata.version
    )

    return true
end

--------------------------------------------------
-- Main loader
--------------------------------------------------

function NSMDS.load_mods()

    NSMDS.log("Initializing loader...")
    NSMDS.log("Version: " .. NSMDS.VERSION)

    NSMDS.Loaded = {}
    NSMDS.Failed = {}

    NSMDS.Registry.Mods = {}

    if not NSMDS.initialize_directory() then
        return false
    end
    

    NSMDS.discover_mods()

    for _, mod in ipairs(NSMDS.Mods) do
        NSMDS.load_mod(mod)
    end

    NSMDS.log("Mod loading finished.")
    NSMDS.log("Loaded: " .. #NSMDS.Loaded)
    NSMDS.log("Failed: " .. #NSMDS.Failed)

    -- Install NSMDS UI hooks
    UIHook.install()
    GameHook.install()

    return true
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

NSMDS.log("Loader initialized.")
