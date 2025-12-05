local update_checker = {}

local config = require("parcel.config")
local Task = require("parcel.tasks.task")
local git = require("parcel.async.git")
local log = require("parcel.log")
local state = require("parcel.state")

-- local logger = log.with_context("update_checker")

---@alias parcel.UpdateCheckListener fun(parcels: parcel.Parcel[])

---@type uv.uv_timer_t?
local timer

---@type number?
local last_check_time = nil

---@type parcel.UpdateCheckListener[]
local update_check_listeners = {}

---@type string[]
local default_fetch_args = { "--quiet", "--tags", "--force", "--recurse-submodules=yes", "origin" }

---@return number
local function elapsed_ms()
    return vim.uv.hrtime() / 1000000
end

---@param parcels parcel.Parcel[]
local function notify_listeners(parcels)
    for _, listener in ipairs(update_check_listeners) do
        listener(parcels)
    end
end

---@param _last_check_time number?
---@return boolean
local function should_check(_last_check_time)
    if #update_check_listeners == 0 then
        return false
    end

    if not _last_check_time then
        return true
    end

    return elapsed_ms() - _last_check_time >= config.update_checker.interval_ms
end

---@async
---@param parcel parcel.Parcel
local function check_updates(parcel)
    return Task.run(function()
        local name = parcel:name()
        local path = parcel:path()
        local fetch_ok, fetch_error = git.fetch(path, { args = default_fetch_args })

        if not fetch_ok then
            log.error("update_checker: Failed to git fetch", name, fetch_error)
            return
        end

        local branch_ok, default_branch_result = git.default_branch(path)

        if not branch_ok then
            log.error("update_checker: Failed to get git default branch", name, default_branch_result)
            return
        end

        local default_branch = default_branch_result.stdout[1]
        local rev_list_ok1, local_head_result = git.sha(path, "HEAD")

        if not rev_list_ok1 then
            log.error("update_checker: Failed to get git local head", name, local_head_result)
            return
        end

        local local_head = local_head_result.stdout[1]
        local rev_list_ok2, remote_head_result = git.sha(path, default_branch)

        if not rev_list_ok2 then
            log.error("update_checker: Failed to get git remote head", name, remote_head_result)
            return
        end

        local remote_head = remote_head_result.stdout[1]

        if local_head_result ~= remote_head_result then
            return parcel
        end
    end)
end

---@param listener parcel.UpdateCheckListener
function update_checker.listen(listener)
    table.insert(update_check_listeners, listener)
end

---@async
---@param parcels parcel.Parcel[]
---@param options { force: boolean }?
function update_checker.check(parcels, options)
    local force = options and options.force or false

    if force ~= true and not should_check(last_check_time) then
        return
    end

    last_check_time = elapsed_ms()

    Task.run(function()
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
            if results == Task.timeout then
                log.warn("update_checker: Timed out when checking one or more parcels", results)
            else
                log.error("update_checker: Failed to check one or more parcels", results)
            end

            return
        end

        ---@type parcel.Parcel[]
        local updateable_parcels = vim.iter(results):filter(function(result)
            return result.result ~= nil
        end):map(function(result)
            return result.result
        end):totable()

        if #updateable_parcels > 0 then
            notify_listeners(updateable_parcels)
        end
    end)
end

function update_checker.start()
    if not timer then
        timer = vim.uv.new_timer()

        if not timer then
            log.error("update_checker: Failed to start timer")
            return
        end
    end

    local initial_delay = 0

    if last_check_time then
        local time_diff = elapsed_ms() - last_check_time

        if time_diff < config.update_checker.interval_ms then
            initial_delay = time_diff
        end
    end

    timer:start(initial_delay, config.update_checker.interval_ms, function()
        -- NOTE: Getting extra info makes calls to git that ultimately performs
        -- a blocking wait which is not allowed in a fast event context
        update_checker.check(state.parcel_list({ info = false }))
    end)
end

function update_checker.stop()
    if not timer then
        return
    end

    timer:stop()
end

return update_checker
