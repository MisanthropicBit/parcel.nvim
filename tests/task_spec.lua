local async = require("neotest.async").tests
local Task = require("parcel.tasks.task")

describe("task #task", function()
    it("creates a new task", function()
        local task = Task.new(function() end)

        assert.is_false(task:started())
        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_false(task:done())
        assert.is_false(task:running())
        assert.are.same(task:elapsed_ms(), -1)
    end)

    async.it("runs and waits for a task", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        assert.is_true(task:started())
        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_false(task:done())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())
        assert.is_true(task:elapsed_ms() >= 100)
    end)

    async.it("runs a task and waits for it to finish", function()
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
    end)

    async.it("creates and starts a task and waits for it to finish", function()
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
    end)

    async.it("gets result if waiting on a finished task", function()
        local task = Task.run(function()
            Task.sleep(500)

            return "done"
        end)

        local ok1, result1 = task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())

        local ok2, result2 = task:wait()

        assert.are.same(ok1, ok2)
        assert.are.same(result1, result2)
    end)

    async.it("gets error if waiting on a failed task", function()
        local task = Task.run(function()
            Task.sleep(500)

            error("Oh no")
        end)

        local ok1, result1 = task:wait()

        assert.is_true(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())

        local ok2, result2 = task:wait()

        assert.are.same(ok1, ok2)
        assert.are.same(result1, result2)
    end)

    async.it("gets nil if waiting on a cancelled task", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        task:cancel()

        local ok1, result1 = task:wait()

        assert.is_false(task:failed())
        assert.is_true(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:done())
        assert.is_false(task:running())

        local ok2, result2 = task:wait()

        assert.are.same(ok1, ok2)
        assert.are.same(result1, result2)
    end)

    async.it("does not run a task that is already running", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        assert.has_error(function()
            Task.run(task)
        end, "Cannot run task that is already running")
    end)

    async.it("does not start a task that is already running", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        assert.has_error(function()
            task:start()
        end, "Cannot run task that is already running")
    end)

    async.it("does not run a task that has failed", function()
        local task = Task.run(function()
            error("Oh no")
        end, function() end)

        task:wait()

        assert.has_error(function()
            Task.run(task)
        end, "Cannot run task that has failed")
    end)

    async.it("does not run a task that is already done", function()
        local task = Task.run(function()
            Task.sleep(10)
        end)

        task:wait()

        assert.has_error(function()
            Task.run(task)
        end, "Cannot run task that is already done")
    end)

    async.it("does not run a task that has been cancelled", function()
        local task = Task.run(function()
            Task.sleep(100)
            Task.sleep(100)
        end)

        task:cancel()
        local ok, result = task:wait()

        assert.are.same(ok, false)
        assert.are.same(result, Task.cancelled)

        assert.has_error(function()
            Task.run(task)
        end, "Cannot run task that has been cancelled")
    end)

    async.it("fails to cancel a task that has already been cancelled", function()
        local task = Task.new(function()
            Task.sleep(500)
        end)

        task:cancel()

        assert.has_error(function()
            task:cancel()
        end, "Attempt to cancel task that was already cancelled")
    end)

    async.it("runs a task that fails", function()
        local task = Task.run(function()
            error("Oh no")
        end, function() end)

        local ok, result = task:wait()

        assert.are.same(ok, false)
        assert.matches("^Task failed: .+:%d+: Oh no\nstack traceback:", result)

        assert.is_true(task:started())
        assert.is_true(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:done())
        assert.is_false(task:running())
    end)

    async.it("runs a task, without a callback, that fails", function()
        error("Nope")
        local task = Task.new(function()
            error("Oh no")
        end)

        assert.has_error(function()
            task:start()
        end)

        local ok, result = task:wait()

        assert.are.same(ok, false)
        assert.matches("^Task failed without callback", result)

        assert.is_true(task:started())
        assert.is_true(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:done())
        assert.is_false(task:running())
    end)

    async.it("runs a task that times out", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        local ok, result = task:wait(10)

        assert.are.same(ok, false)
        assert.are.same(result, Task.timeout)
    end)

    pending("does not wait for a task that has not been started", function()
        local task = Task.new(function() end)

        assert.has_error(function()
            task:wait()
        end, "Cannot wait for task that has not been started")
    end)

    it("cannot call async-only function in non-async context", function()
        local task = Task.new(function() end)

        assert.has_error(function()
            task:wait()
        end, "Cannot call async-only function in non-async context")
    end)

    describe("wait_all", function()
        async.it("runs multiple tasks and waits for them to finish", function()
            local tasks = vim.iter({ 25, 50, 75 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, results = Task.wait_all(tasks)

            assert.are.same(ok, true)
            assert.are.same(results, {
                { ok = true, result = 25 },
                { ok = true, result = 50 },
                { ok = true, result = 75 },
            })

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_false(tasks[idx]:cancelled())
                assert.is_true(tasks[idx]:done())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs multiple tasks and waits for them to finish with #tasks < concurrency", function()
            local tasks = vim.iter({ 25, 50, 75 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, results = Task.wait_all(tasks, { concurrency = 4 })

            assert.are.same(ok, true)
            assert.are.same(results, {
                { ok = true, result = 25 },
                { ok = true, result = 50 },
                { ok = true, result = 75 },
            })

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_false(tasks[idx]:cancelled())
                assert.is_true(tasks[idx]:done())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs multiple tasks and waits for them to finish with #tasks > concurrency", function()
            local tasks = vim.iter({ 25, 50, 75 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, results = Task.wait_all(tasks, { concurrency = 2 })

            assert.are.same(ok, true)
            assert.are.same(results, {
                { ok = true, result = 25 },
                { ok = true, result = 50 },
                { ok = true, result = 75 },
            })

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_false(tasks[idx]:cancelled())
                assert.is_true(tasks[idx]:done())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs multiple tasks and waits for them to finish but times out", function()
            local tasks = vim.iter({ 5000, 5000, 5000 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, results = Task.wait_all(tasks, { timeout = 10 })

            assert.are.same(ok, false)
            assert.are.same(results, Task.timeout)

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_true(tasks[idx]:cancelled())
                assert.is_false(tasks[idx]:done())
                assert.is_false(tasks[idx]:running())
            end
        end)
    end)

    describe("first", function()
        async.it("runs multiple tasks and gets the result of the first one to finish", function()
            local tasks = vim.iter({ 25, 5000, 5000 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, result = Task.first(tasks)

            assert.are.same(ok, true)
            assert.are.same(result, 25)

            assert.is_true(tasks[1]:started())
            assert.is_false(tasks[1]:failed())
            assert.is_false(tasks[1]:cancelled())
            assert.is_true(tasks[1]:done())
            assert.is_false(tasks[1]:running())

            assert.is_true(tasks[2]:started())
            assert.is_false(tasks[2]:failed())
            assert.is_true(tasks[2]:cancelled())
            assert.is_false(tasks[2]:done())
            assert.is_false(tasks[2]:running())

            assert.is_true(tasks[3]:started())
            assert.is_false(tasks[3]:failed())
            assert.is_true(tasks[3]:cancelled())
            assert.is_false(tasks[3]:done())
            assert.is_false(tasks[3]:running())
        end)

        async.it("runs multiple tasks, getting the result of the first to finish but times out", function() end)
    end)
end)
