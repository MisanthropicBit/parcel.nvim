local Lines = require("parcel.ui.lines")

local Section = {}

Section.__index = Lines

function Section.new()
    local section = {
        rows = {}
    }

    return setmetatable(section, Section)
end

return Section
