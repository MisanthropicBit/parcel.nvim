local parcel = {}

local actions = require("parcel.actions")
local config = require("parcel.config")
local log = require("parcel.log")
local Parcel = require("parcel.parcel")
local Spec = require("parcel.spec")

---@class parcel.UserSpec
---@field git? parcel.Spec[]
---@field luarocks? parcel.Spec[]

---@class parcel.Definition
---@field options table
---@field parcels parcel.UserSpec

---@param definition parcel.Definition
function parcel.setup(definition)
    if not definition then
        error("Invalid argument passed to parcel.setup")
    end

    config.setup(definition.options)

    for source, specs in pairs(definition.parcels) do
        log.info("Validating specs for '%s'", source)

        for _, spec in ipairs(specs) do
            table.insert(
                config._parcels,
                Parcel:new({ spec = Spec:new(spec, source) })
            )
        end
    end

    if config.autoinstall == true then
        log.info("Autoinstalling parcels")

        actions.install.run(config._parcels, {
            callback = function(results)
                log.info("Installed %s parcels", #results)
            end,
        })
    end
end

return parcel
