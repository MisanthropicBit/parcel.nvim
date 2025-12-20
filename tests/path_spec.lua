local Path = require("parcel.path")

describe("Path", function()
    it("creates an empty Path", function()
        local path = Path.new()

        assert.are.same(path:absolute(), "")
    end)

    it("joins path components to a string", function()
        local components = { "a", "b", "c" }
        local pathstr = Path.join(unpack(components))

        assert.are.same(pathstr, table.concat(components, Path.separator))
    end)

    it("joins components using the 'add' method", function()
        local path = Path.new()
        path = path:add("a"):add("b"):add("c")

        assert.is_true(vim.endswith(path:absolute(), table.concat({ "a", "b", "c" }, Path.separator)))
    end)

    it("joins components using the '/' operator", function()
        local path = Path.new()
        path = path / "a" / "b" / "c"

        assert.is_true(vim.endswith(path:absolute(), table.concat({ "a", "b", "c" }, Path.separator)))
    end)

    it("expands '~' and '..'", function() end)

    it("converts a path to a string", function()
        local path = Path.new("a", "b", "c.txt")

        -- assert.are.same(tostring(path), table.concat({ "a", "b", "c.txt" }, Path.separator))
        assert.is_true(vim.endswith(path:tostring(), table.concat({ "a", "b", "c.txt" }, Path.separator)))
    end)

    it("gets directory path of path", function()
        local path = Path.new("a", "b", "c.txt")

        error("hello")

        assert.are.same(path:dirname(), Path.join("a", "b"))
    end)

    it("gets basename of path", function()
        local path = Path.new("a", "b", "c.txt")

        assert.are.same(path:basename(), "c.txt")
    end)

    it("gets parent of path", function()
        local path = Path.new("a", "b", "c.txt")

        assert.is_true(vim.endswith(path:parent():absolute(), "a/b"))
        assert.is_true(vim.endswith(path:parent():parent():absolute(), "a"))
        assert.is_nil(path:parent():parent():parent())
    end)

    it("adds extension without dot", function()
        local path = Path.new("a", "b")
        path:add_extension("jpg")

        assert.is_true(vim.endswith(path:absolute(), table.concat({ "a", "b" }, Path.separator) .. ".jpg"))
    end)

    it("adds extension with dot", function()
        local path = Path.new("a", "b")
        path:add_extension(".jpg")

        assert.is_true(vim.endswith(path:absolute(), table.concat({ "a", "b" }, Path.separator) .. ".jpg"))
    end)

    it("adds multiple extensions", function()
        local path = Path.new("a", "b")
        path:add_extension("jpg")
        path:add_extension(".lol")

        assert.is_true(vim.endswith(path:absolute(), table.concat({ "a", "b" }, Path.separator) .. ".jpg.lol"))
    end)
end)
