local diagnostics = {}

local ns = vim.api.nvim_create_namespace("parcel.diagnostics")

function diagnostics.setup()
    vim.diagnostic.config({}, ns)
end

---@param ext_id integer
---@param diagnostic vim.Diagnostic
---@return vim.Diagnostic
function diagnostics.create(ext_id, diagnostic)
    return vim.tbl_extend("force", diagnostic, {
        source = "parcel.nvim",
        namespace = ns,
        user_data = { ext_id = ext_id }
    })
end

---@param buffer integer
---@param _diagnostics vim.Diagnostic[]
---@param options vim.diagnostic.Opts?
function diagnostics.set(buffer, _diagnostics, options)
    vim.diagnostic.set(ns, buffer, diagnostics, options)
end

-- TODO: Update diagnostics when parcels are sorted
function diagnostics.update()
end

return diagnostics
