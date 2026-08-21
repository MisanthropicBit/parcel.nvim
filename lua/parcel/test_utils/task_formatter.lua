local Task = require("parcel.tasks.task")

local function task_formatter(task)
    if not Task.is_task(task) then
        return nil
    end

    local result = {}

    table.insert(result, ("  failed    = %s,"):format(tostring(task:failed())))
    table.insert(result, ("  cancelled = %s,"):format(tostring(task:cancelled())))
    table.insert(result, ("  started   = %s,"):format(tostring(task:started())))
    table.insert(result, ("  completed = %s,"):format(tostring(task:completed())))
    table.insert(result, ("  running   = %s,"):format(tostring(task:running())))

    return ("Task(\n%s\n)"):format(table.concat(result, "\n"))
end

return task_formatter
