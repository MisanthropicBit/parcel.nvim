local update_checker = {}

local Task = require("parcel.tasks.task")
local git = require("parcel.async.git")
local Overview = require("parcel.ui.overview")

---@type uv.uv_timer_t?
local timer

local default_fetch_args = { "--quiet", "--tags", "--force", "--recurse-submodules=yes", "origin" }

---@param parcel parcel.Parcel
local function check_updates(parcel)
    return Task.run(function()
        local path = parcel:path()

        -- TODO: Do tasks return like pcall?
        local fetch_ok, result = git.fetch(path, { args = default_fetch_args })

        if not fetch_ok then
            -- TODO: Log and return
            return
        end

        local branch_ok, default_branch = git.default_branch(path)
        local rev_list_ok1, local_head = git.sha(path, "HEAD")
        local rev_list_ok2, remote_head = git.sha(path, "origin/" .. default_branch)

        if local_head ~= remote_head then
            Overview.main():notify_change({
                type = "update_available",
                parcel = parcel,
            })
        end
    end)
end

---@async
---@param parcels parcel.Parcel[]
function update_checker.check(parcels)
    local check_tasks = {}

    for _, parcel in ipairs(parcels) do
        table.insert(check_tasks, check_updates(parcel))
    end

    Task.wait_all(check_tasks, {
        concurrency = 4, -- TODO: config.concurrency
        timeout = 10000 -- TODO: config.timeout
    })
end

function update_checker.start()
    if not timer then
        timer = vim.uv.new_timer()

        if not timer then
            -- TODO: Log and return
            return
        end
    end

    timer:start(0, 5 * 60 * 1000, update_checker.check)
end

function update_checker.stop()
    if not timer then
        return
    end

    timer:stop()
end

return update_checker
