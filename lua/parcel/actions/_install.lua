local config = require("parcel.config")
local notify = require("parcel.notify")
local sources = require("parcel.sources")
local Task = require("parcel.tasks")

---@async
---@param parcel parcel.Parcel
---@return parcel.Task
local function install_parcel(parcel)
    return Task.new(function()
        local source = sources.get_source(parcel:source())
        ---@cast source -nil

        --- TODO: Notify overview here
        parcel:set_state(parcel.State.Updating)

        local result = source.install(parcel)

        if parcel:state() == parcel.State.Updating then
            parcel:set_state(parcel.State.Installed)
        end

        -- vim.print(result)
        -- local state = result and parcel.State.Installed or parcel.State.Failed

        -- --- TODO: Notify overview here
        -- parcel:set_state(state)
        -- if not task:failed() then
        --     parcel:set_state(parcel.State.installed)
        -- else
        --     parcel:push_error(task:error())
        -- end
    end)
end

---@async
---@param parcels parcel.Parcel[]
---@return parcel.Task
return function(parcels)
    return Task.run(function()
        ---@type parcel.Task[]
        local tasks = vim.tbl_map(install_parcel, parcels)
        local results = Task.wait_all(tasks, { concurrency = config.concurrency })

        -- notify.log.info("Finished installing %d parcels", #parcels)

        return results
    end)
end
