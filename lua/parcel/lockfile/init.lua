local lockfile = {}

local constants = require("parcel.constants")
local json = require("parcel.json")

---@return boolean, any
function lockfile.read()
    return json.read_file(constants.lockfile)
end

function lockfile.find(name)
    local ok, lockdata = lockfile.read()

    if not ok then
        return nil
    end

    for _, entry in ipairs(lockdata) do
        if entry.name == name then
            return entry
        end
    end

    return nil
end

return lockfile
