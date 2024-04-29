local Lines = require("parcel.ui.lines")

local Section = {}

function Section:new()
    local section = {
        rows = {}
    }
    self.__index = Lines

    return setmetatable(section, self)
end

return Section
