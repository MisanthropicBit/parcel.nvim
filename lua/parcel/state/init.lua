local state = {}

local config = require("parcel.config")
local Path = require("parcel.path")
local sources = require("parcel.sources")

---@type parcel.Parcel[]
local parcels = {}

function state.get_installed_parcels()
    local installed = {}

    for source, _ in pairs(sources.Source) do
        installed[source] = {}
    end

    for source, _ in pairs(sources.Source) do
        local source_path = Path:new(config.dir, "parcel", source)
        local dir_stream = vim.loop.fs_opendir(source_path:absolute())

        if not dir_stream then
            -- TODO: Handle failure
            -- TODO: Use async version
            vim.fn.mkdir(source_path:absolute(), "p")
            -- vim.loop.fs_mkdir(source_path:absolute(), 438)
            dir_stream = vim.loop.fs_opendir(source_path:absolute())
        end

        ----@type uv.aliases.fs_readdir_entries
        local entries, err = vim.loop.fs_readdir(dir_stream)

        if not entries then
            goto continue
        end

        while #entries > 0 do
            for _, entry in ipairs(entries) do
                if entry.type == "directory" then
                    installed[source][entry.name] = true
                end
            end

            entries, err = vim.loop.fs_readdir(dir_stream)

            if entries == nil then
                vim.loop.fs_closedir(dir_stream)
                break
            end
        end

        :: continue ::
    end

    return installed
end

function state.add_parcel(parcel)
    table.insert(parcels, parcel)
end

function state.parcels()
    return parcels
end

-- function state.read()
--     local path = Path.join(stdpath("data"), "parcel-state.json")
--     local fd = assert(vim.loop.fs_open(path, "r", 438))
--     local stat = assert(vim.loop.fs_fstat(fd))
--     local data = assert(vim.loop.fs_read(fd, stat.size, 0))
--     local ok = vim.loop.fs_read(fd, json)

--     if not ok then
--         log.error("Failed to write state")
--     end

--     assert(vim.loop.fs_close(fd))

--     return data
-- end

-- function state.write(parcels)
--     local _state = vim.tbl_map(function(parcel)
--         return {
--             state = parcel:state(),
--         }
--     end, parcels)

--     local json = vim.json.encode(_state)
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
