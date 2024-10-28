local async = require("neotest-busted.async")
local Task = require("parcel.tasks.task")

describe("task #task", function()
    it("creates a new task", function()
        local task = Task.new(function() end)

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_false(task:started())
        assert.is_false(task:done())
        assert.is_false(task:running())
        assert.are.same(task:elapsed_ms(), -1)
    end)

    it("runs and waits for a task", async(function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_false(task:done())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())
        assert.is_true(task:elapsed_ms() >= 100)
    end))

    it("runs a task and waits for it to finish", async(function()
        local task = Task.new(function()
            Task.sleep(500)
        end)

        Task.run(task)

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_false(task:done())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())
        assert.is_true(task:elapsed_ms() >= 100)
    end))

    it("creates and starts a task and waits for it to finish", async(function()
        local task = Task.new(function()
            Task.sleep(500)
        end)

        task:start()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_false(task:done())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())
        assert.is_true(task:elapsed_ms() >= 100)
    end))

    it("runs a task that fails", function()
    end)

    it("runs a task that is cancelled", function()
    end)

    it("runs a task that times out", function()
    end)

    it("runs multiple tasks and waits for them to finish", function()
    end)

    it("runs multiple tasks and gets the result of the first one to finish", function()
    end)
end)
