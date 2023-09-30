local Spec = {
    name = '',
    pinned = false,
    disabled = false,
    dev = false,
}

---@enum parcel.Source
local Source = {
    git = 0,
    luarocks = 1,
}

local github_url_format = "https://www.github.com/%s.git"

--- A user specification of a parcel as passed to the setup function
---@class parcel.Spec
---@field name string
---@field source string
---@field branch? string
---@field version? string
---@field tag? string
---@field pinned? boolean
---@field disabled? boolean
---@field dev? boolean
---@field as? string
---@field url? string

---@return parcel.Spec
function Spec:new(raw_spec, source)
    Spec.validate(raw_spec, source)

    local spec_name = type(raw_spec) == "string" and raw_spec or raw_spec[1]
    local spec = { name = spec_name, source = source }

    self.__index = self
    setmetatable(spec, self)

    return spec
end

function Spec.validate(spec, source)
    -- if source(spec[1]) ~= "string" then
    --     error("Expected parcel name as first table element", 2)
    -- end

    if Source[source] == nil then
        error(("Source '%s' is not supported"):format(source))
    end

    if source == Source.git then
        local url_format = spec.url or github_url_format

        spec.url = url_format:format(spec.name)
    elseif source == Source.luarocks then
        -- TODO
    end
end

return Spec
