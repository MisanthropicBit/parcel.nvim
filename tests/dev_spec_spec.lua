local Spec = require("parcel.spec")
local sources = require("parcel.sources")

describe("dev spec", function()
    it("creates and validates a spec", function()
        local spec = Spec:new("some/local/path", sources.Source.dev)

        assert.are.same(spec:name(), "some/local/path")
        assert.are.same(spec:source_name(), sources.Source.dev)
        assert.are.same(spec:errors(), {})
        assert.is_false(spec:validated())

        local ok, errors = spec:validate()

        assert.is_true(ok)
        assert.are.same(errors, {})

        assert.is_true(spec:validated())
    end)

    it("handles unknown configuration keys", function()
        local spec = Spec:new({ "some/local/path", unknown_key = true }, sources.Source.dev)

        local ok, errors = spec:validate()

        assert.is_false(ok)
        assert.are.same(errors, {
            {
                message = "Unknown configuration key 'unknown_key' for source 'dev'"
            }
        })

        assert.is_false(spec:validated())
    end)

    it("handles incorrect type for configuration keys", function()
        local spec = Spec:new({ "some/local/path", condition = 12 }, sources.Source.dev)

        local ok, errors = spec:validate()

        assert.is_false(ok)
        assert.are.same(errors, {
            {
                message = "Expected type(s) function for key 'condition' but got type 'number'"
            }
        })

        assert.is_false(spec:validated())
    end)

    it("handles failed validation of configuration keys", function()
        local spec = Spec:new({
            "some/local/path",
            dependencies = { a = 1, b = 2 },
        }, sources.Source.dev)

        local ok, errors = spec:validate()

        assert.is_false(ok)
        assert.are.same(errors, {
            {
                message = "Key 'dependencies' failed validation: Key is not a list"
            }
        })

        assert.is_false(spec:validated())
    end)

    it("handles multiple validation errors", function()
    end)
end)
