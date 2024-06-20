local tblx = {}

---@enum parcel.TableDiffState
tblx.TableDiffState = {
    Added = "Added",
    Changed = "Changed",
    Removed = "Removed",
}

--- Compute the difference between two non-list tables
---@param table1 table
---@param table2 table
---@return table
function tblx.diff(table1, table2)
    -- TODO: Support nested tables
    local diff = {}

    for key1, value1 in pairs(table1) do
        local value2 = table2[key1]

        if value2 == nil then
            diff[key1] = { tblx.TableDiffState.Removed, value1 }
        else
            if value2 ~= value1 then
                diff[key1] = { tblx.TableDiffState.Changed, value1, value2 }
            end
        end
    end

    for key, value in pairs(table2) do
        if table1[key] == nil then
            diff[key] = { tblx.TableDiffState.Added, value }
        end
    end

    return diff
end

return tblx
