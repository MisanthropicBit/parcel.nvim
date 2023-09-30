---@class parcel.Path
---@field _parts string[]
local Path = {}

---@return parcel.Path
function Path:new(...)
    local path = {
        _parts = { ... }
    }
    self.__index = self

    return setmetatable(path, self)
end

local function sep()
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
Path.sep = sep()

local function newline()
    if jit then
        local os = string.lower(jit.os)

        if os == "linux" or os == "osx" or os == "bsd" then
            return "\n"
        else
            return "\r\n"
        end
    else
        -- TODO
        return package.config:sub(1, 1)
    end
end

---@type string
Path.newline = newline()

function Path.join(...)
    return table.concat({ ... }, Path.sep)
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
    return vim.fs.normalize(Path.join(unpack(self._parts)))
end

return Path
