local install = require("parcel.actions.install")
local config = require("parcel.config")
local Parcel = require("parcel.parcel")
local log = require("parcel.log")
local notify = require("parcel.notify")
local state = require("parcel.state")
local Task = require("parcel.tasks")

---@async
---@param parcels parcel.Parcel[]
return function(parcels)
    Task.run(function()
        -- Filter already installed parcels without spec errors
        local missing_parcels = vim.tbl_filter(function(parcel)
            return parcel:state() == Parcel.State.NotInstalled -- and #parcel:spec():errors() == 0
        end, parcels)
        vim.print(vim.inspect({ "missing_parcels", #missing_parcels }))

        if #missing_parcels > 0 then
            local installed_parcels = state.get_installed_parcels()
            local parcels_to_install = {}

            for _, parcel in ipairs(missing_parcels) do
                if installed_parcels[parcel:source()][parcel:name()] then
                    parcel:set_state(Parcel.State.Installed)
                else
                    table.insert(parcels_to_install, parcel)
                end
            end

            vim.print(vim.inspect({ "parcels_to_install", #parcels_to_install }))
            local task = install(parcels_to_install)
            local results = task:wait()
            vim.print(vim.inspect({ "task:wait", results }))
            -- log.info("Installed %d/%d parcel(s)", #results, #missing_parcels)

            vim.print("soijfri")
            for _, parcel in ipairs(parcels_to_install) do
                vim.print("soijfri")
                if #parcel:errors() > 0 then
                    vim.print(vim.inspect(parcel:errors()))
                    goto continue
                end

                local config_func = parcel:spec():get("config")
                vim.print(vim.inspect({ "config_func", config_func }))

                if config_func then
                    if type(config_func) == "string" then
                        local module = config_func

                        config_func = function()
                            require(module)
                        end
                    end

                    local ok, err = pcall(config_func)
                    vim.print(vim.inspect({ "config", ok, err }))

                    if not ok then
                        notify.log.error(
                            "Failed to run configuration for %s source parcel %s",
                            "dev", -- parcel():source():name(),
                            parcel:name()
                        )
                    end
                end

                :: continue ::
            end
        end
    end)
end
