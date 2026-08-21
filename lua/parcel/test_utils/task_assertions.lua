local Task = require("parcel.tasks.task")
local say = require("say")

local task_states = { "failed", "cancelled", "running", "started", "completed" }

local completed_spec = {
    failed = false,
    cancelled = false,
    running = false,
    started = true,
    completed = true,
}

local function create_task_asserter(state_spec)
    return function(state, arguments)
        if #arguments ~= 1 or not Task.is_task(arguments[1]) then
            return false
        end

        local task = arguments[1]

        for task_state, expected_value in pairs(state_spec) do
            if not task[task_state](task) then
                return false
            end
        end

        return true
    end
end

for _, task_state in ipairs(task_states) do
    local assertion_name = ("is_%s_task"):format(task_state)

    say:set("assertion.is_%s_task.positive", "Expected task to be %s: %%s")
    say:set("assertion.is_%s_task.negative", "Expected task to not be %s: %%s")

    assert:register(
        "assertion",
        assertion_name,
        create_task_asserter(completed_spec),
        "assertion.is_completed_task.positive",
        "assertion.is_completed_task.negative"
    )
end
