---@class parcel.Path
---@field _parts string[]
---@field _extensions string[]
local Path = {}

Path.__index = Path

---@return string
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

---@return string
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
function Path.new(...)
    return setmetatable({
        _parts = { ... },
        _extensions = {},
    }, { __index = Path })
end

---@param ... (string | parcel.Path)
function Path.join(...)
    return table.concat({ ... }, Path.separator)
end

---@param path string | parcel.Path
---@return parcel.Path
function Path:add(path)
    table.insert(self._parts, path)

    return self
end

---@param self parcel.Path
---@param path string | parcel.Path
---@return parcel.Path
function Path.__div(self, path)
    return self:add(path)
end

---@return string
function Path:__tostring()
    return self:absolute()
end

---@return string
function Path:tostring()
    return self:absolute()
end

---@return string
function Path:dirname()
    return Path.join(unpack(vim.list_slice(self._parts, 1, #self._parts - 1)))
end

---@return string
function Path:basename()
    return self._parts[#self._parts]
end

---@return parcel.Path?
function Path:parent()
    if #self._parts == 1 then
        return nil
    end

    return Path.new(unpack(vim.list_slice(self._parts, 1, #self._parts - 1)))
end

---@return string
function Path:absolute()
    if #self._parts == 0 then
        return ""
    end

    local norm_path = vim.fs.normalize(Path.join(unpack(self._parts)))

    return vim.fs.abspath(norm_path .. table.concat(vim.tbl_map(ensure_dot_extension, self._extensions), ""))
end

---@param ext string
---@return parcel.Path
function Path:add_extension(ext)
    table.insert(self._extensions, ensure_dot_extension(ext))

    return self
end

---@return parcel.Path
function Path:remove_extension()
    self._extensions = {}

    return self
end

---@param ext string
---@return parcel.Path
function Path:change_extension(ext)
    self._extensions = { ensure_dot_extension(ext) }

    return self
end

---@return string[]
function Path:extensions()
    return self._extensions
end

return Path
