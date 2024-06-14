local proxy = {}

local Task = require("parcel.tasks")

---@alias parcel.ProxyCacheEntry function | table

--- Get a cached api function
---@param cache table<string, parcel.ProxyCacheEntry>
---@param api string
---@param key string
---@return parcel.ProxyCacheEntry
local function get_cached(cache, api, key)
    local cached = cache[key]

    if not cached then
        if not vim.startswith(api, "opt") then
            cached = function(...)
                if vim.in_fast_event() then
                    Task.wait_scheduler()
                end

                return vim[api][key](...)
            end
        else
            cached = setmetatable({}, {
                __index = function(_, _key)
                    if vim.in_fast_event() then
                        Task.wait_scheduler()
                    end

                    return vim[api][key][_key]
                end
            })
        end

        cache[key] = cached
    end

    return cached
end

--- Create a proxy for a vim api that is safe to call in async code (code
--- executing in fast event handlers)
---@param api string
---@return table
function proxy.create(api)
    local cache = {}

    return setmetatable({}, {
        __index = function(_, key)
            return get_cached(cache, api, key)
        end
    })
end

return proxy
