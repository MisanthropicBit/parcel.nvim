local lockfile = {}

local async = require("parcel.async")
local constants = require("parcel.constants")
local Path = require("parcel.path")
local notify = require("parcel.notify")

---@return boolean
---@return any
function lockfile.read()
    local path = Path.join(constants.lockfile)

    local fd = async.fs.open(path, "r", 438)
    local stat = async.fs.fstat(fd)
    local data = async.fs.read(fd, stat.size, 0)

    local ok, json = pcall(vim.json.decode, data, {
        object = true,
        array = true,
    })

    if not ok then
        return false, json
    end

    async.fs.close(fd)

    return true, data
end

-- TODO: Lockfile format depends on source type
function lockfile.write(data)
    local json = vim.json.encode(data)
    local path = Path.join(constants.lockfile())
    local fd = async.fsopen(path, "w", 438)
    local ok = async.fs.write(fd, json)

    if not ok then
        notify.log.error("Failed to write lockfile")
        return false
    end

    async.fs.close(fd)
    return true
end

function lockfile.get(data, source, name)
    
end

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

return lockfile
