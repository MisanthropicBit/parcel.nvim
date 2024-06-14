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

            local task = install(parcels_to_install)
            local results = task:wait()
            -- log.info("Installed %d/%d parcel(s)", #results, #missing_parcels)

            for _, parcel in ipairs(parcels_to_install) do
                if #parcel:errors() > 0 then
                    goto continue
                end

                local config_func = parcel:spec():get("config")

                if config_func then
                    if type(config_func) == "string" then
                        local module = config_func

                        config_func = function()
                            require(module)
                        end
                    end

                    local ok, err = pcall(config_func)

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
