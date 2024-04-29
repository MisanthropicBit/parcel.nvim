local install = {}

local async = require("parcel.tasks.async")
local config = require("parcel.config")
local Parcel = require("parcel.parcel")
local Path = require("parcel.path")
local Task = require("parcel.tasks.task")

---@param parcel parcel.Parcel
local function _install(parcel)
    local source = require("parcel.sources." .. parcel.spec.source)

    local tagged_tasks = {
        {
            tag = "git.clone",
            args = {
                source.url_from_parcel(parcel),
                {
                    dir = Path.join(config.path, parcel:name()),
                    -- TODO: on_done is maybe a better name?
                    on_exit = function(success, result)
                        if success then
                            parcel:set_state("installed")
                            parcel._installed = true
                        else
                            parcel:set_error(result)
                        end
                    end,
                },
            },
        },
    }

    return Task.tagged(tagged_tasks)
end

---@async
---@param parcels parcel.Parcel[]
function install.run(parcels, options)
    local tasks = {}

    for _, parcel in pairs(parcels) do
        table.insert(tasks, _install(parcel)) -- Task.install(parcel))
    end

    -- TODO: Add concurrency limit
    async.run(function()
        async.wait_all(tasks, function()
            vim.print(config._parcels)
        end)
    end, options.callback)
end

return install
