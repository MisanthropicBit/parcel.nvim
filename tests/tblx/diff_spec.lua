local tblx = require("parcel.tblx")

describe("tblx.diff", function()
    it("finds all types of differences", function()
        local table1 = {
            a = 1,
            b = 2,
            c = 3,
        }
        local table2 = {
            a = 1,
            c = 52,
            d = 4,
        }

        local diff = tblx.diff(table1, table2)

        assert.are.same(diff, {
            b = { tblx.TableDiffState.Removed, 2 },
            c = { tblx.TableDiffState.Changed, 3, 52 },
            d = { tblx.TableDiffState.Added, 4 },
        })
    end)

    it("finds differences where first table is empty", function()
        local table2 = {
            a = 1,
            b = 2,
            c = 3,
        }

        assert.are.same(tblx.diff({}, table2), {
            a = { tblx.TableDiffState.Added, 1 },
            b = { tblx.TableDiffState.Added, 2 },
            c = { tblx.TableDiffState.Added, 3 },
        })
    end)

    it("finds differences where second table is empty", function()
        local table1 = {
            a = 1,
            b = 2,
            c = 3,
        }

        assert.are.same(tblx.diff(table1, {}), {
            a = { tblx.TableDiffState.Removed, 1 },
            b = { tblx.TableDiffState.Removed, 2 },
            c = { tblx.TableDiffState.Removed, 3 },
        })
    end)

    it("finds no differences between empty tables", function()
        assert.are.same(tblx.diff({}, {}), {})
    end)
end)
