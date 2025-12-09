local async = require("neotest.async").tests
local Task = require("parcel.tasks.task")

describe("task #task", function()
    it("creates a new task", function()
        local task = Task.new(function() end)

        assert.is_false(task:started())
        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_false(task:completed())
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
        assert.is_false(task:completed())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:completed())
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
        assert.is_false(task:completed())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:completed())
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
        assert.is_false(task:completed())
        assert.is_true(task:running())

        task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:completed())
        assert.is_false(task:running())
        assert.is_true(task:elapsed_ms() >= 100)
    end)

    async.it("gets result if waiting on a finished task", function()
        local task = Task.run(function()
            Task.sleep(500)

            return "completed"
        end)

        local ok1, result1 = task:wait()

        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:started())
        assert.is_true(task:completed())
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
        assert.is_false(task:completed())
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
        assert.is_false(task:completed())
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

    async.it("does not run a task that has already completed", function()
        local task = Task.run(function()
            Task.sleep(10)
        end)

        task:wait()

        assert.is_true(task:started())
        assert.is_false(task:failed())
        assert.is_false(task:cancelled())
        assert.is_true(task:completed())
        assert.is_false(task:running())

        assert.has_error(function()
            Task.run(task)
        end, "Cannot run task that has already completed")
    end)

    async.it("does not run a task that has been cancelled", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        task:cancel()
        local ok, result = task:wait()

        assert.are.same(ok, false)
        assert.are.same(result, "cancelled")

        assert.is_true(task:started())
        assert.is_false(task:failed())
        assert.is_true(task:cancelled())
        assert.is_false(task:completed())
        assert.is_false(task:running())

        assert.has_error(function()
            Task.run(task)
        end, "Cannot run task that has been cancelled")
    end)

    async.it("fails to cancel a task that has already been cancelled", function()
        local task = Task.new(function()
            Task.sleep(500)
        end)

        task:cancel()

        assert.is_false(task:started())
        assert.is_false(task:failed())
        assert.is_true(task:cancelled())
        assert.is_false(task:completed())
        assert.is_false(task:running())

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
        assert.is_false(task:completed())
        assert.is_false(task:running())
    end)

    async.it("runs a task, without a callback, that fails", function()
        local task = Task.new(function()
            error("Oh no")
        end)

        local p_ok, p_result = pcall(task.start, task)
        ---@cast p_result -parcel.Task, +string

        assert.is_false(p_ok)
        assert.matches("Task failed without callback: Task failed: .+:%d+: Oh no\nstack traceback:", p_result)

        local ok, result = task:wait()

        assert.are.same(ok, false)
        assert.matches("^Task failed: .+:%d+: Oh no\nstack traceback:", result)

        assert.is_true(task:started())
        assert.is_true(task:failed())
        assert.is_false(task:cancelled())
        assert.is_false(task:completed())
        assert.is_false(task:running())
    end)

    async.it("runs a task, without a callback, that fails via Task.run", function()
        local task

        local p_ok, p_result = pcall(Task.run, function()
            error("Oh no")
        end)
        ---@cast p_result -parcel.Task, +string

        assert.is_false(p_ok)
        assert.matches("Task failed without callback: Task failed: .+:%d+: Oh no\nstack traceback:", p_result)
    end)

    async.it("runs a task that times out", function()
        local task = Task.run(function()
            Task.sleep(500)
        end)

        local ok, result = task:wait(10)

        assert.is_true(task:started())
        assert.is_false(task:failed())
        assert.is_true(task:cancelled())
        assert.is_false(task:completed())
        assert.is_false(task:running())

        assert.are.same(ok, false)
        assert.are.same(result, Task.timeout)
    end)

    -- FIX:
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
        async.it("runs and waits for multiple tasks to finish", function()
            local tasks = vim.iter({ 400, 500, 250 })
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
                { ok = true, result = 400 },
                { ok = true, result = 500 },
                { ok = true, result = 250 },
            })

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_false(tasks[idx]:cancelled())
                assert.is_true(tasks[idx]:completed())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs and waits for multiple tasks to finish with #tasks < concurrency", function()
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
                assert.is_true(tasks[idx]:completed())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs and waits for multiple tasks to finish with #tasks > concurrency", function()
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
                assert.is_true(tasks[idx]:completed())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs and waits for multiple tasks to finish but times out", function()
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
                assert.is_false(tasks[idx]:completed())
                assert.is_false(tasks[idx]:running())
            end
        end)

        async.it("runs and waits for multiple tasks with one task failing", function()
            local tasks = vim.iter(ipairs({ 500, 500, 500 }))
                :map(function(idx, sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        if idx == 2 then
                            error("Oh no")
                        end

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, results = Task.wait_all(tasks)

            assert.are.same(ok, false)

            assert.are.same(results[1], { ok = true, result = 500 })
            assert.are.same(results[3], { ok = true, result = 500 })

            assert.are.same(results[2].ok, false)
            assert.matches("^Task failed: .+:%d+: Oh no\nstack traceback:", results[2].result)

            assert.is_true(tasks[2]:started())
            assert.is_true(tasks[2]:failed())
            assert.is_false(tasks[2]:cancelled())
            assert.is_false(tasks[2]:completed())
            assert.is_false(tasks[2]:running())

            for idx = 1, #tasks do
                if idx ~= 2 then
                    assert.is_true(tasks[idx]:started())
                    assert.is_false(tasks[idx]:failed())
                    assert.is_false(tasks[idx]:cancelled())
                    assert.is_true(tasks[idx]:completed())
                    assert.is_false(tasks[idx]:running())
                end
            end
        end)

        async.it("runs and waits for multiple tasks with one task cancelled", function()
            local tasks = vim.iter({ 500, 500, 500 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            tasks[2]:cancel()

            local ok, results = Task.wait_all(tasks)

            assert.are.same(ok, false)
            assert.are.same(results, {
                { ok = true, result = 500 },
                { ok = false, result = "cancelled" },
                { ok = true, result = 500 },
            })

            assert.is_false(tasks[2]:started())
            assert.is_false(tasks[2]:failed())
            assert.is_true(tasks[2]:cancelled())
            assert.is_false(tasks[2]:completed())
            assert.is_false(tasks[2]:running())

            for idx = 1, #tasks do
                if idx ~= 2 then
                    assert.is_true(tasks[idx]:started())
                    assert.is_false(tasks[idx]:failed())
                    assert.is_false(tasks[idx]:cancelled())
                    assert.is_true(tasks[idx]:completed())
                    assert.is_false(tasks[idx]:running())
                end
            end
        end)

        -- FIX:
        pending("handles no tasks", function()
            assert.has_error(function()
                vim.print(vim.inspect(Task.wait_all({})))
            end, "Empty task list given to Task.wait_all")
        end)

        async.it("handles completed, failed, cancelled, and non-running tasks", function()
            local task1 = Task.run(function() end)
            task1:wait()

            assert.is_true(task1:started())
            assert.is_false(task1:failed())
            assert.is_false(task1:cancelled())
            assert.is_true(task1:completed())
            assert.is_false(task1:running())

            local task2 = Task.run(function()
                error("Oh no")
            end, function() end)

            assert.is_true(task2:started())
            assert.is_true(task2:failed())
            assert.is_false(task2:cancelled())
            assert.is_false(task2:completed())
            assert.is_false(task2:running())

            local task3 = Task.new(function() end)
            task3:cancel()

            assert.is_false(task3:started())
            assert.is_false(task3:failed())
            assert.is_true(task3:cancelled())
            assert.is_false(task3:completed())
            assert.is_false(task3:running())

            local task4 = Task.new(function() end)

            assert.is_false(task4:started())
            assert.is_false(task4:failed())
            assert.is_false(task4:cancelled())
            assert.is_false(task4:completed())
            assert.is_false(task4:running())

            local ok, results = Task.wait_all({ task1, task2, task3, task4 })

            assert.is_false(ok)

            assert.is_true(results[1].ok)
            assert.is_nil(results[1].result)

            assert.is_false(results[2].ok)
            assert.matches("^Task failed: .+:%d+: Oh no\nstack traceback:", results[2].result)

            assert.is_false(results[3].ok)
            assert.are.same(results[3].result, "cancelled")

            assert.is_true(results[4].ok)
            assert.is_nil(results[4].result)
        end)

        async.it("actually runs concurrently and interleaves output", function()
            math.randomseed(vim.uv.hrtime())

            local tasks = vim.iter({ 1, 2, 3 })
                :map(function(task_idx)
                    return Task.new(function()
                        for idx = 1, 3 do
                            Task.sleep(math.random(50, 400))
                            vim.print(("Hello from task %d"):format(task_idx))
                        end
                    end)
                end)
                :totable()

            local ok, results = Task.wait_all(tasks)

            assert.are.same(ok, true)
            assert.are.same(results, {
                { ok = true, result = nil },
                { ok = true, result = nil },
                { ok = true, result = nil },
            })

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_false(tasks[idx]:cancelled())
                assert.is_true(tasks[idx]:completed())
                assert.is_false(tasks[idx]:running())
            end
        end)
    end)

    describe("first", function()
        async.it("runs multiple tasks and gets the result of the first task to finish", function()
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
            assert.is_true(tasks[1]:completed())
            assert.is_false(tasks[1]:running())

            assert.is_true(tasks[2]:started())
            assert.is_false(tasks[2]:failed())
            assert.is_true(tasks[2]:cancelled())
            assert.is_false(tasks[2]:completed())
            assert.is_false(tasks[2]:running())

            assert.is_true(tasks[3]:started())
            assert.is_false(tasks[3]:failed())
            assert.is_true(tasks[3]:cancelled())
            assert.is_false(tasks[3]:completed())
            assert.is_false(tasks[3]:running())
        end)

        async.it("runs multiple tasks but times out", function()
            local tasks = vim.iter({ 2500, 5000, 5000 })
                :map(function(sleep_time)
                    return Task.new(function()
                        Task.sleep(sleep_time)

                        return sleep_time
                    end)
                end)
                :totable()

            local ok, result = Task.first(tasks, { timeout = 10 })

            assert.is_false(ok)
            assert.are.same(result, Task.timeout)

            for idx = 1, #tasks do
                assert.is_true(tasks[idx]:started())
                assert.is_false(tasks[idx]:failed())
                assert.is_true(tasks[idx]:cancelled())
                assert.is_false(tasks[idx]:completed())
                assert.is_false(tasks[idx]:running())
            end
        end)
    end)
end)
