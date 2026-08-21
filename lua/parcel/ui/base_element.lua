--- Base class for all ui elements
---@class parcel.ui.BaseElement
local BaseElement = {}

--- Find the project root directory given a current directory to work from.
--- Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@param options any
---@return parcel.ui.BaseElement
---@diagnostic disable-next-line: missing-return
function BaseElement.new(options) end

---@return integer
---@diagnostic disable-next-line: missing-return
function BaseElement.size() end

---@return string[]
---@diagnostic disable-next-line: missing-return
function BaseElement.render() end

---@param buffer integer
---@param row integer
---@param col integer
---@return integer # The new row index so the parent ui element knows where to start rendering from
---@diagnostic disable-next-line: missing-return
function BaseElement.set_highlights(buffer, row, col) end
