
--[[
    NSMDS - Not SteamModed
    Core / Loader
    Version: 0.6.0
]]

local ModManager = require("core.mod_manager")
local GameHook = require("core.game_hook")
local UIHook = require("core.ui_hook")
local json = require("core.json")
local Atlas = require("core.atlas")

NSMDS = NSMDS or {}

NSMDS.VERSION = "0.6.0"
NSMDS.MOD_DIR = "mods"

-- Mod management
NSMDS.Mods = {}
NSMDS.Loaded = {}
NSMDS.Failed = {}

-- Internal registry
NSMDS.Registry = {
    Mods = {},
    Jokers = {},
    Atlases = {}
}

NSMDS.CurrentMod = nil
Atlas.initialize(NSMDS)
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
-- Registry helpers
--------------------------------------------------

local function create_pending_registry()
    return {
        Jokers = {},
        Atlases = {}
    }
end

local function commit_mod_registry(mod)

    local pending = mod.pending_registry

    if not pending then
        return
    end

    -- Commit Jokers
    for id, joker in pairs(pending.Jokers) do
        NSMDS.Registry.Jokers[id] = joker
    end

    -- Commit Atlases
    for id, atlas in pairs(pending.Atlases) do
        NSMDS.Registry.Atlases[id] = atlas
    end

    mod.pending_registry = nil
end

local function discard_mod_registry(mod)

    mod.pending_registry = nil
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

    if data.atlas ~= nil and
       (type(data.atlas) ~= "string" or data.atlas == "") then
        error("Joker atlas must be a valid string.")
    end

    if data.pos ~= nil then

        if type(data.pos) ~= "table" then
            error("Joker pos must be a table.")
        end

        if type(data.pos.x) ~= "number" or
           type(data.pos.y) ~= "number" or
           data.pos.x < 0 or data.pos.y < 0 or
           data.pos.x % 1 ~= 0 or data.pos.y % 1 ~= 0 then

            error("Joker pos requires non-negative integer x and y.")
        end
    end

    local mod = NSMDS.CurrentMod

    if not mod.pending_registry then
        error("Mod registry is not initialized.")
    end

    local joker_id = mod.metadata.id .. "_" .. data.key

    if NSMDS.Registry.Jokers[joker_id]
        or mod.pending_registry.Jokers[joker_id] then

        error("Duplicate Joker key: " .. joker_id)
    end

    local atlas_id = nil

    if data.atlas then

        atlas_id = mod.metadata.id .. "_" .. data.atlas

        if not mod.pending_registry.Atlases[atlas_id]
            and not NSMDS.Registry.Atlases[atlas_id] then

            error("Atlas not registered: " .. atlas_id)
        end
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

        description = data.description or {},

        atlas = atlas_id,

        pos = data.pos and {
            x = data.pos.x,
            y = data.pos.y
        } or {
            x = 0,
            y = 0
        }
    }

    mod.pending_registry.Jokers[joker_id] = joker

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

    -- Copy globally registered Jokers
    for id, joker in pairs(NSMDS.Registry.Jokers) do
        jokers[id] = joker
    end

    -- Include current mod's pending Jokers
    if NSMDS.CurrentMod and NSMDS.CurrentMod.pending_registry then

        for id, joker in pairs(NSMDS.CurrentMod.pending_registry.Jokers) do
            jokers[id] = joker
        end

    end

    return jokers
end

function NSMDS.get_joker_count()

    local count = 0

    for _ in pairs(NSMDS.get_registered_jokers()) do
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

    -- Create temporary registry
    mod.pending_registry = create_pending_registry()

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

        -- Discard all temporary registrations
        discard_mod_registry(mod)

        mod.status = "failed"
        mod.error = result

        table.insert(NSMDS.Failed, mod)

        NSMDS.log_error(mod.name, result)

        return false
    end


    -- Validate and load registered Atlases
    local atlas_success, atlas_error = Atlas.validate_mod(mod)

    if not atlas_success then

        -- Discard all temporary registrations
        discard_mod_registry(mod)

        mod.status = "failed"
        mod.error = atlas_error

        table.insert(NSMDS.Failed, mod)

        NSMDS.log_error(mod.name, atlas_error)

        return false
    end

    -- Commit temporary registrations
    commit_mod_registry(mod)


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
