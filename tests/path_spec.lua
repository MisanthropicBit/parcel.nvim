local Path = require("parcel.path")

describe("Path", function()
    it("creates an empty Path", function()
        local path = Path:new()
        vim.print(vim.inspect(path))

        assert.are.same(path:absolute(), "")
    end)

    it("joins path components to a string", function()
        local components = { "a", "b", "c" }
        local pathstr = Path.join(unpack(components))

        assert.are.same(pathstr, table.concat(components, Path.separator))
    end)

    it("joins components using the '/' operator", function()
        local path = Path:new()
        path = path / "a" / "b" / "c"

        assert.are.same(path:absolute(), table.concat({ "a", "b", "c" }, Path.separator))
    end)

    it("expands '~' and '..'", function()
    end)

    it("adds extension without dot", function()
        local path = Path:new("a", "b")
        path:add_extension("jpg")

        assert.are.same(path:absolute(), table.concat({ "a", "b" }, Path.separator) .. ".jpg")
    end)

    it("adds extension with dot", function()
        local path = Path:new("a", "b")
        path:add_extension(".jpg")

        assert.are.same(path:absolute(), table.concat({ "a", "b" }, Path.separator) .. ".jpg")
    end)

    it("adds multiple extensions", function()
        local path = Path:new("a", "b")
        path:add_extension("jpg")
        path:add_extension(".lol")

        assert.are.same(path:absolute(), table.concat({ "a", "b" }, Path.separator) .. ".jpg.lol")
    end)
end)
