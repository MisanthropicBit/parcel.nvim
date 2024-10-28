local state = {}

local async = require("parcel.async")
local config = require("parcel.config")
local constants = require("parcel.constants")
local Path = require("parcel.path")
local sources = require("parcel.sources")
local Task = require("parcel.tasks")

---@type table<parcel.SourceType, table<string, parcel.Parcel>>
local parcels = {}

--- Check that the directory for a development source exists
---@param parcel parcel.Parcel
local function check_dev_source_dir(parcel)
    local local_path = Path:new(parcel:name())

    return async.fs.dir_exists(local_path:absolute())
end

---@async
---@param path parcel.Path
---@return any
---@return uv_fs_t?
local function open_or_create_directory(path)
    local abspath = path:absolute()
    local err, dir_stream = async.fs.opendir(abspath)

    if err then
        async.fs.mkdirs(abspath, "p", 438)
        return async.fs.opendir(abspath)
    end

    return err, dir_stream
end

---@async
---@param specs any
---@return table<parcel.SourceType, parcel.Parcel[]>
function state.get_installed_parcels2(specs)
    local installed = {}

    for source, _ in pairs(sources.Source) do
        if source == sources.Source.dev then
            installed[sources.Source.dev] = vim.tbl_values(parcels[sources.Source.dev] or {})
        else
            installed[source] = {}
        end
    end

    ----@param entry uv.aliases.fs_readdir_entries
    local function is_directory(entry)
        return entry.type == "directory"
    end

    for source_name, _ in pairs(sources.Source) do
        if source_name == sources.Source.dev then
            goto continue
        end

        local source_path = Path:new(config.dir, "parcel", source_name)
        async.fs.mkdirs(source_path:absolute())

        -- TODO: Read directory entries for at most depth 2 for git only
        for depth, entry in async.fs.iter_dir(source_path, { depth = 2, filter = is_directory }) do
            if depth == 2 then
                installed[source_name][entry.relpath] = true
            end
        end

        :: continue ::
    end

    return installed
end

---@async
---@param specs any
---@return table<parcel.SourceType, parcel.Parcel[]>
function state.get_installed_parcels(specs)
    local installed = {}

    for source, _ in pairs(sources.Source) do
        if source == sources.Source.dev then
            -- If we are re-sourcing, then add all the already installed parcels
            installed[sources.Source.dev] = vim.tbl_values(parcels[sources.Source.dev] or {})
        else
            installed[source] = {}
        end
    end

    -- Check if dev sources are installed by seeing if the local directory exists
    for _, spec in ipairs(specs[sources.Source.dev]) do
        if installed[sources.Source.dev][spec[1]] ~= true then
            if async.fs.dir_exists(spec[1]) then
                installed[sources.Source.dev][spec[1]] = true
            end
        end
    end

    for source_name, _ in pairs(sources.Source) do
        if source_name == sources.Source.dev then
            goto continue
        end

        local source_path = Path:new(config.dir, "parcel", source_name)
        local dir_err, dir_stream = open_or_create_directory(source_path)

        if dir_err then
            -- TODO: Handle failure gracefully
            error(("Failed to open directory stream: %s"):format(dir_stream))
        end

        local read_err, entries = async.fs.readdir(dir_stream)

        if not entries then
            goto continue
        end

        ----@cast entries uv.aliases.fs_readdir_entries

        local directory_entries = {}

        while #entries > 0 do
            for _, entry in ipairs(entries) do
                if entry.type == "directory" then
                    table.insert(directory_entries, entry)
                    -- installed[source_name][entry.name] = true
                end
            end

            read_err, entries = async.fs.readdir(dir_stream)

            if read_err or entries == nil then
                -- async.fs.closedir(dir_stream)
                break
            end
        end

        async.fs.closedir(dir_stream)

        for _, directory_entry in ipairs(directory_entries) do
            local err1, dir_stream1 = async.fs.opendir(Path.join(source_path:absolute(), directory_entry.name))
            local read_err1, entries1 = async.fs.readdir(dir_stream1)

            while #entries1 > 0 do
                for _, entry in ipairs(entries1) do
                    if entry.type == "directory" then
                        local path = Path.join(directory_entry.name, entry.name)
                        installed[source_name][path] = true
                    end
                end

                read_err1, entries1 = async.fs.readdir(dir_stream1)

                if read_err1 or entries1 == nil then
                    async.fs.closedir(dir_stream1)
                    break
                end
            end
        end

        :: continue ::
    end

    return installed
end

---@param parcel parcel.Parcel
function state.add_parcel(parcel)
    local source_name = parcel:source_name()

    if not parcels[source_name] then
        parcels[source_name] = {}
    end

    parcels[source_name][parcel:name()] = parcel
end

---@param parcel parcel.Parcel
function state.remove_parcel(parcel)
    local name = parcel:name()
    local source_name = parcel:source_name()

    if not parcels[source_name] or not parcels[source_name][name] then
        return
    end

    parcels[source_name][name] = nil
end

---@return parcel.Parcel[]
function state.parcels()
    local _parcels = {}

    for source_name, entries in pairs(parcels) do
        vim.list_extend(_parcels, vim.tbl_values(entries))
    end

    return _parcels
end

---@param source_name string
---@param name string
---@return parcel.Parcel?
function state.get_parcel(source_name, name)
    return parcels[source_name] and parcels[source_name][name]
end

---@param source_name string
---@param name string
---@return boolean
function state.has_parcel(source_name, name)
    return state.get_parcel(source_name, name) ~= nil
end

return state
