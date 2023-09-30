local Task = {}

local async = require("parcel.tasks.async")
-- local predefined = require("parcel.tasks.predefined")

-- A task is a light wrapper around a function that will be run asynchronously
---@class parcel.Task

function Task.new(func)
    local task = setmetatable({}, { __index = Task })

    task._func = func
    task._start_time = nil
    task._end_time = nil
    task._cancelled = false

    return task
end

function Task:start(callback)
    self._start_time = vim.loop.hrtime()

    async.run(self._func, function(success, results)
        self._end_time = vim.loop.hrtime()

        if callback then
            callback(success, results)
        end
    end)
end

function Task:cancel()
    self._cancelled = true
end

function Task:done()
    return self._end_time ~= nil
end

--- Return a pre-defined task for a given source
---@param source parcel.Source
---@return parcel.Task
-- function Task.predefined(source)
--     return predefined[source]
-- end

function Task.install(parcel)
end

function Task.tagged(tagged_tasks)
    return Task.new(function()
        local tasks = {}

        for _, tagged_task in ipairs(tagged_tasks) do
            local parts = vim.fn.split(tagged_task.tag, [[\.]])
            local path = { "parcel", "tasks", parts[1] }
            local task = require(table.concat(path, "."))

            task[parts[#parts]](unpack(tagged_task.args))
        end
    end)
end

-- for source in ipairs({ "git", "luarocks" }) do
--     Task[source] = require("parcel.tasks." .. source)
-- end

return Task
