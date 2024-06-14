---@class parcel.async.Event
---@field private _callbacks function[]
---@field private _set boolean
local Event = {}

local Task = require("parcel.tasks")

---@return parcel.async.Event
function Event.new()
    local event = setmetatable({}, {
        __self = Event,
    })

    event._callbacks = {}
    event._set = false

    return event
end

function Event:is_set()
    return self._set
end

function Event:set()
    self._set = true

    for _, callback in ipairs(self._callbacks) do
        callback()
    end
end

Event.wait = Task.wrap(function(self, callback)
    if self:is_set() then
        callback()
    else
        table.insert(self._callbacks, callback)
    end
end, 2)

function Event:clear()
    self._set = false
end

return Event
