---@class parcel.Path
---@field _parts string[]
---@field _extensions string[]
local Path = {}

local function separator()
    if jit then
        local os = string.lower(jit.os)

        if os == "linux" or os == "osx" or os == "bsd" then
            return "/"
        else
            return "\\"
        end
    else
        return package.config:sub(1, 1)
    end
end

---@type string
Path.separator = separator()

local function newline()
    if jit then
        local os = string.lower(jit.os)

        if os == "linux" or os == "osx" or os == "bsd" then
            return "\n"
        else
            return "\r\n"
        end
    else
        return package.config:sub(1, 1)
    end
end

---@type string
Path.newline = newline()

---@param ext string
---@return string
local function ensure_dot_extension(ext)
    return vim.startswith(ext, ".") and ext or "." .. ext
end

---@param ... string
---@return parcel.Path
function Path:new(...)
    local path = {
        _parts = { ... },
        _extensions = {},
    }

    return setmetatable(path, { __index = self })
end

function Path.join(...)
    return table.concat({ ... }, Path.separator)
end

---@param self parcel.Path
---@param part string | parcel.Path
---@return parcel.Path
function Path.__div(self, part)
    table.insert(self._parts, part)

    return self
end

---@return string
function Path:__tostring()
    return self:absolute()
end

---@return string
function Path:absolute()
    local norm_path = vim.fs.normalize(Path.join(unpack(self._parts)))

    return norm_path .. table.concat(
        vim.tbl_map(ensure_dot_extension, self._extensions),
        Path.separator
    )
end

---@param ext string
---@return parcel.Path
function Path:add_extension(ext)
    table.insert(self._extensions, ensure_dot_extension(ext))

    return self
end

return Path
