local git = {}

local config = require("parcel.config")
local log = require("parcel.log")
local Task = require("parcel.tasks")

-- Return a single task, that when run, will asynchronously install a parcel
-- using git
---@param spec parcel.Spec
---@return parcel.Task
function git.install(spec)
    local tagged_tasks = {
        "git.clone", Task.new(function() Task.git.clone(spec, { dir = config.path }) end),
    }

    return Task.new(function()
        Task.git.clone(spec, { dir = config.path })
    end, function(success, result)
        if success then
            log.debug("Task for spec %s succeeded", spec)
        else
            log.debug("Task for spec %s failed", spec)
        end

        table.insert(config._parcels, result)

        -- TODO: Run overview render autocmd
    end)
end

return git
