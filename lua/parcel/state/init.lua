local state = {}

local async = require("parcel.async")
local config = require("parcel.config")
local Path = require("parcel.path")
local sources = require("parcel.sources")
local Task = require("parcel.tasks")

---@type table<parcel.SourceType, table<string, parcel.Parcel>>
local parcels = {}

---@async
---@param specs any
---@return table<parcel.SourceType, parcel.Parcel[]>
function state.get_installed_parcels(specs)
    local installed = {}

    for source, _ in pairs(sources.Source) do
        installed[source] = {}
    end

    for source_name, _ in pairs(sources.Source) do
        if source_name == sources.Source.dev then
            -- TODO: Instead use the specs to check if the local dir exists?
            goto continue
        end

        local source_path = Path:new(config.dir, "parcel", source_name)
        local dir_stream = async.fs.opendir(source_path:absolute())

        if not dir_stream then
            local abs_path = source_path:absolute()

            async.fs.mkdirs(abs_path, "p", 438)
            dir_stream = async.fs.opendir(abs_path)

            -- TODO: Handle failure gracefully
            if not dir_stream then
                error(("Failed to open directory stream: %s"):format(dir_stream))
            end
        end

        ----@type uv.aliases.fs_readdir_entries
        local entries, err = async.fs.readdir(dir_stream)

        if not entries then
            goto continue
        end

        while #entries > 0 do
            for _, entry in ipairs(entries) do
                if entry.type == "directory" then
                    installed[source_name][entry.name] = true
                end
            end

            entries, err = async.fs.readdir(dir_stream)

            if entries == nil then
                async.fs.closedir(dir_stream)
                break
            end
        end

        :: continue ::
    end

    return installed
end

---@param parcel parcel.Parcel
function state.add_parcel(parcel)
    local source_name = parcel:source()

    if not parcels[source_name] then
        parcels[source_name] = {}
    end

    parcels[source_name][parcel:name()] = parcel
end

---@param parcel parcel.Parcel
function state.remove_parcel(parcel)
    local name = parcel:name()
    local source_name = parcel:source()

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

function state.read()
    local path = Path.join(vim.fn.stdpath("data"), "parcel.state.json")

    local fd = async.fs.open(path, "r", 438)
    local stat = async.fs.fstat(fd)
    local data = async.fs.read(fd, stat.size, 0)
    local json = vim.json.decode(data, {
        object = true,
        array = true,
    })

    async.fs.close(fd)

    return data
end

-- TODO: Lockfile format depends on source type
-- function state.write(parcels)
--     local parcel_state = vim.tbl_map(function(parcel)
--         return {
--             state = parcel:state(),
--         }
--     end, parcels)

--     local json = vim.json.encode(parcel_state)
--     local path = Path.join(stdpath("data"), "parcel-state.json")
--     local fd = assert(vim.loop.fs_open(path, "w", 438))
--     local ok = vim.loop.fs_write(fd, json)

--     if not ok then
--         log.error("Failed to write state")
--     end

--     assert(vim.loop.fs_close(fd))
-- end

-- function state.update(parcels)
--     local _state = vim.tbl_map(function(parcel)
--         return {
--             state = parcel:state(),
--         }
--     end, parcels)

--     local existing_state = state.read()
--     local updated_state = vim.tbl_deep_extend("force", existing_state, _state)

--     local json = vim.json.encode(_state)
--     local path = Path.join(stdpath("data"), "parcel-state.json")
--     local fd = assert(vim.loop.fs_open(path, "w", 438))
--     local ok = vim.loop.fs_write(fd, json)

--     if not ok then
--         log.error("Failed to write state")
--     end

--     assert(vim.loop.fs_close(fd))
-- end

return state
