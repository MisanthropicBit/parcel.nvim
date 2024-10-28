local Version = require("parcel.version")

describe("version", function()
    it("creates a new Version from values", function()
        local version = Version:new({
            major = 3,
            minor = 2,
            patch = 1,
            prerelease = "rc1",
            build = "build.2",
            prefix = "~",
        })

        assert.are.same(tostring(version), "~3.2.1-rc1+build.2")
    end)

    it("creates a default Version", function()
        local version1 = Version:new({})
        assert.are.same(tostring(version1), "0.0.0")

        local version2 = Version:new()
        assert.are.same(tostring(version2), "0.0.0")
    end)

    it("parses a version from a string", function()
        local version = Version.parse("    ~3.2.1-rc1+build.2  ")

        assert.are.same(tostring(version), "~3.2.1-rc1+build.2")
    end)

    it("compares version less than", function()
        local version1 = Version.parse("1.2.1")
        local version2 = Version.parse("1.2.4")

        assert.is_true(version1 < version2)
    end)
end)
