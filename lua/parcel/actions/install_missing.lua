local install = require("parcel.actions.install")
local config = require("parcel.config")
local Parcel = require("parcel.parcel")
local log = require("parcel.log")
local state = require("parcel.state")

return function(parcels)
    -- Filter already installed parcels
    local missing_parcels = vim.tbl_filter(function(parcel)
        return parcel:state() == Parcel.State.not_installed
    end, parcels)

    if #missing_parcels > 0 then
        local installed_parcels = state.get_installed_parcels()
        local parcels_to_install = {}

        for _, parcel in ipairs(missing_parcels) do
            if installed_parcels[parcel:source()][parcel:name()] then
                parcel:set_state(Parcel.State.installed)
            else
                table.insert(parcels_to_install, parcel)
            end
        end

        vim.print(vim.inspect(vim.tbl_map(function(p)
            return p:name()
            end, parcels_to_install)))

        local results = {}
        -- local results = install(
        --     parcels_to_install,
        --     { concurrency = config.concurrency }
        -- )

        log.info("Installed %d/%d parcel(s)", #results, #missing_parcels)
    end
end
