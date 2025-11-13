local state = {}

local constants = require("parcel.constants")
local Parcel = require("parcel.parcel")

-- Sample PackChanged event:
--
-- { "Got event:", {
--     buf = 8,
--     data = {
--       active = true,
--       kind = "update",
--       path = "/Users/hyrule/.local/share/nvim/site/pack/core/opt/vim-bracketed-paste",
--       spec = {
--         name = "vim-bracketed-paste",
--         src = "https://github.com/ConradIrwin/vim-bracketed-paste",
--         version = "77e5220b8ac541f9244e57a252655b748e21c71e"
--       }
--     },
--     event = "PackChanged",
--     file = "/Users/hyrule/.local/share/nvim/site/pack/core/opt/vim-bracketed-paste",
--     group = 81,
--     id = 144,
--     match = "/Users/hyrule/.local/share/nvim/site/pack/core/opt/vim-bracketed-paste"
--   } }

---@class PackEventData
---@field active boolean
---@field kind   "install" | "update" | "delete"
---@field spec   vim.pack.SpecResolved
---@field path   string

---@type table<string, parcel.Parcel>
local parcels = {}

---@alias parcel.StateChangeListener fun(data: PackEventData)

---@type parcel.StateChangeListener[]
local state_change_listeners = {}

---@param data PackEventData
local function notify_listeners(data)
    for _, listener in ipairs(state_change_listeners) do
        listener(data)
    end
end

---@param listener parcel.StateChangeListener
function state.listen(listener)
    table.insert(state_change_listeners, listener)
end

---@param data PackEventData
function state.add_parcel(data)
    parcels[data.spec.name] = Parcel.new({ spec = data })
end

---@param data PackEventData
function state.update_parcel(data)
    -- TODO:
    parcels[data.spec.name]:update({ spec = data.spec })
end

---@param data PackEventData
function state.remove_parcel(data)
    local name = data.spec.name

    if not parcels[name] then
        return
    end

    parcels[name] = nil
end

---@param options { exclude_states: parcel.State[]? }?
---@return table<string, parcel.Parcel>
function state.parcels(options)
    if #parcels == 0 then
        local packinfo = vim.pack.get()

        for _, info in ipairs(packinfo) do
            parcels[info.spec.name] = Parcel.new({ spec = info })
        end
    end

    local filtered_parcels = vim.deepcopy(parcels)

    if options and options.exclude_states and #options.exclude_states > 0 then
        for name, parcel in pairs(parcels) do
            if not vim.list_contains(options.exclude_states, parcel:state()) then
                filtered_parcels[name] = parcel
            end
        end
    end

    return filtered_parcels
end

---@param options { exclude_states: parcel.State[]? }?
function state.parcel_list(options)
    return vim.tbl_values(state.parcels(options))
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

---@return table<parcel.Parcel.State, integer>
function state.stats()
    local stats = {}

    for key, value in pairs(Parcel.State) do
        stats[key] = 0
    end

    for name, parcel in pairs(parcels) do
        stats[parcel:state()] = stats[parcel:state()] + 1
    end

    return stats
end

function state.setup()
    vim.api.nvim_create_autocmd("PackChanged", {
        group = constants.augroup,
        ---@param event { data: PackEventData }
        callback = function(event)
            local data = event.data

            if data.kind == "install" then
                state.add_parcel(data)
            elseif data.kind == "update" then
                state.update_parcel(data)
            elseif data.kind == "delete" then
                state.remove_parcel(data)
            end

            notify_listeners(data)
        end,
    })
end

return state
