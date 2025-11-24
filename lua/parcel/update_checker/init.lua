local update_checker = {}

local config = require("parcel.config")
local Task = require("parcel.tasks.task")
local git = require("parcel.async.git")
local log = require("parcel.log")

-- local logger = log.with_context("update_checker")

---@type uv.uv_timer_t?
local timer

local default_fetch_args = { "--quiet", "--tags", "--force", "--recurse-submodules=yes", "origin" }

---@async
---@param parcel parcel.Parcel
local function check_updates(parcel)
    return Task.run(function()
        local path = parcel:path()
        local fetch_ok, _ = git.fetch(path, { args = default_fetch_args })

        if not fetch_ok then
            log.error("update_checker: Failed to git fetch", path)
            return
        end

        local branch_ok, default_branch = git.default_branch(path)

        if not branch_ok then
            log.error("update_checker: Failed to get git default branch", path)
            return
        end

        local rev_list_ok1, local_head = git.sha(path, "HEAD")

        if not rev_list_ok1 then
            log.error("update_checker: Failed to get git local head", path)
            return
        end

        local rev_list_ok2, remote_head = git.sha(path, "origin/" .. default_branch)

        if not rev_list_ok2 then
            log.error("update_checker: Failed to get git remote head", path)
            return
        end

        if local_head ~= remote_head then
            return parcel
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

    local concurrency = config.update_checker.concurrency or config.concurrency

    local ok, results = Task.wait_all(check_tasks, {
        concurrency = concurrency,
        timeout = config.update_checker.timeout_ms,
    })

    if not ok then
        log.error("update_checker: Failed to check one or more parcels", results)
        return
    end

    ---@type parcel.Parcel[]
    local updateable_parcels = vim.tbl_filter(function(result)
        return result.result ~= nil
    end, results)

    if #updateable_parcels > 0 then
        require("parcel.ui.overview").main():notify_change({
            type = "update_available",
            parcels = updateable_parcels,
        })
    end
end

function update_checker.start()
    if not timer then
        timer = vim.uv.new_timer()

        if not timer then
            log.error("update_checker: Failed to start timer")
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
