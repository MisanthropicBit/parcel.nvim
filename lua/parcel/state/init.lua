local state = {}

local Parcel = require("parcel.parcel")

---@class PackEventData
---@field active boolean
---@field kind   "install" | "update" | "delete"
---@field spec   vim.pack.SpecResolved
---@field path   string

---@type table<string, parcel.Parcel>
local parcels = {}

---@param event
function state.add_parcel(event)
    parcels[event.spec.name] = event.spec
end

---@param event
function state.remove_parcel(event)
    local name = event.spec.name

    if not parcels[name] then
        return
    end

    parcels[name] = nil
end

---@param exclude_states parcel.State[]?
---@return table<string, parcel.Parcel>
function state.parcels(exclude_states)
    if #parcels == 0 then
        ---@type vim.pack.PlugData[]
        local packinfo = {
            {
                active = true,
                branches = { "master" },
                path = "some/path",
                rev = "e395bb6",
                spec = {
                    src = "https://github.com/MisanthropicBit/winmove.nvim",
                    name = "winmove.nvim",
                    version = "v1.0.1",
                }
            },
            {
                active = false,
                branches = { "main" },
                path = "some/path",
                rev = "a95b3b6",
                spec = {
                    src = "https://github.com/MisanthropicBit/decipher.nvim",
                    name = "decipher.nvim",
                    version = "v2.2.4",
                }
            }
        }

        for _, info in ipairs(packinfo) do
            table.insert(parcels, Parcel:new({ spec = info }))
            -- parcels[info.spec.name] = Parcel:new({ spec = info })
        end
    end

    if exclude_states and #exclude_states > 0 then
        local filtered_parcels = {}

        for name, parcel in pairs(parcels) do
            if not vim.list_contains(exclude_states, parcel:state()) then
                filtered_parcels[name] = parcel
            end
        end

        return filtered_parcels
    end

    return parcels
end

---@param name string
---@return parcel.Parcel?
function state.get_parcel(name)
    return parcels[name]
end

---@param name string
---@return boolean
function state.has_parcel(name)
    return state.get_parcel(name) ~= nil
end

return state
