local Spec = require("parcel.spec")
local sources = require("parcel.sources")

describe("spec", function()
    it("handles unsupported spec", function()
        local spec = Spec:new("some/local/path", "nope")

        local ok, errors = spec:validate()

        assert.is_false(ok)
        assert.is_false(spec:validated())
        assert.are.same(errors, {
            {
                message = "Source 'nope' is not supported",
            },
        })
    end)

    it("handles incorrect user spec type", function()
        local spec = Spec:new(12, sources.Source.dev)

        local ok, errors = spec:validate()

        assert.is_false(ok)
        assert.is_false(spec:validated())
        assert.are.same(errors, {
            {
                message = "Expected string or table, got 'number'",
            },
        })
    end)

    it("handles incorrect parcel name", function()
        local spec = Spec:new({ 12 }, sources.Source.dev)

        local ok, errors = spec:validate()

        assert.is_false(ok)
        assert.is_false(spec:validated())
        assert.are.same(errors, {
            {
                message = "Expected parcel name as first table element at index 1",
            },
        })
    end)
end)
