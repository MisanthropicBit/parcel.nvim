local state = {}

function state.read()
    local path = Path.join(stdpath("data"), "parcel-state.json")
    local fd = assert(vim.loop.fs_open(path, "r", 438))
    local stat = assert(vim.loop.fs_fstat(fd))
    local data = assert(vim.loop.fs_read(fd, stat.size, 0))
    local ok = vim.loop.fs_read(fd, json)

    if not ok then
        log.error("Failed to write state")
    end

    assert(vim.loop.fs_close(fd))

    return data
end

function state.write(parcels)
    local _state = vim.tbl_map(function(parcel)
        return {
            state = parcel:state(),
        }
    end, parcels)

    local json = vim.json.encode(_state)
    local path = Path.join(stdpath("data"), "parcel-state.json")
    local fd = assert(vim.loop.fs_open(path, "w", 438))
    local ok = vim.loop.fs_write(fd, json)

    if not ok then
        log.error("Failed to write state")
    end

    assert(vim.loop.fs_close(fd))
end

function state.update(parcels)
    local _state = vim.tbl_map(function(parcel)
        return {
            state = parcel:state(),
        }
    end, parcels)

    local existing_state = state.read()
    local updated_state = vim.tbl_deep_extend("force", existing_state, _state)

    local json = vim.json.encode(_state)
    local path = Path.join(stdpath("data"), "parcel-state.json")
    local fd = assert(vim.loop.fs_open(path, "w", 438))
    local ok = vim.loop.fs_write(fd, json)

    if not ok then
        log.error("Failed to write state")
    end

    assert(vim.loop.fs_close(fd))
end

return state
