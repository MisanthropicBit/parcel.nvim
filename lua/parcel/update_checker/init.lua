local update_checker = {}

local Task = require("parcel.tasks")

---@param parcel parcel.Parcel
local function check_updates(parcel)
    -- 1. Perform git tasks to check for updates
    -- 2. If any updates, inform the overview via overview.notify
end

---@async
---@param parcels parcel.Parcel[]
function update_checker.check(parcels)
    local check_tasks = {}

    for _, parcel in ipairs(parcels) do
        table.insert(check_tasks, Task.run(check_updates))
    end

    Task.wait_all(check_tasks, {
        concurrency = 4, -- TODO: config.concurrency
        timeout = 10000 -- TODO: config.timeout
    })
end

return update_checker
