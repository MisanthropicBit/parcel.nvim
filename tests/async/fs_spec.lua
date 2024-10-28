local async = require("neotest-busted.async")
local async_fs = require("parcel.async").fs

-- NOTE: We only test parcel's custom async.fs functions
describe("async.fs", function()
    it("iter_dir", async(function()
        for entry in async_fs.iter_dir("/Users/alexb/projects/vim/parcel.nvim/tests/") do
            vim.print(entry.name)
        end
    end))
end)
