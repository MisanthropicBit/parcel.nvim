local async = require("parcel.tasks.async")
local config = require("parcel.config")
local notify = require("parcel.notify")
local sources = require("parcel.sources")

---@async
---@param parcel parcel.Parcel
---@return parcel.Task
local function _install(parcel)
    return async.run(function()
        local source = sources.get_source(parcel:source()) ---@cast source -nil

        --- TODO: Notify overview here
        parcel:set_state(parcel.State.updating)

        local task = source.install(parcel)

        if not task:failed() then
            parcel:set_state(parcel.State.installed)
        else
            parcel:set_error(task:error())
        end
    end)
end

---@async
---@param parcels parcel.Parcel[]
return function(parcels, options)
    ---@type parcel.Task[]
    local tasks = vim.tbl_map(_install, parcels)

    -- TODO: Add concurrency limit
    async.run(function()
        local results = async.wait_all(tasks, { concurrency = config.concurrency })

        notify.info("Finished installing %d parcels", #parcels)
    end, options.callback)
end
