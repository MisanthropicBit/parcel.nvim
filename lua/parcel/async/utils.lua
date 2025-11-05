local async_utils = {}

---@generic F: fun()
---@param ms number
---@param func F
---@return F
function async_utils.throttle(ms, func)
    local timer = vim.loop.new_timer()

    -- FIX: How to handle this error?
    if not timer then
        return func
    end

    local running = false
    local first = true

    return function(...)
        local args = { ... }
        local wrapped = function()
            func(unpack(args))
        end

        if not running then
            if first then
                wrapped()
                first = false
            end

            timer:start(ms, 0, function()
                running = false
                vim.schedule(wrapped)
            end)

            running = true
        end
    end
end

return async_utils
