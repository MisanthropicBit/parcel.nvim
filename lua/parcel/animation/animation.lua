local Easing = require("parcel.animation.easing")
local utils = require("parcel.utils")

---@class parcel.Animation
---@field _timer     uv.uv_timer_t?
---@field _value     number
---@field _loop      boolean
---@field _delay     number
---@field _delta     number
---@field _duration  number
---@field _easing    parcel.Easing
---@field _callback  fun(value: number): boolean?
---@field _on_finish fun(completed: boolean)?
local Animation = {}

Animation.__index = Animation

---@class parcel.AnimationOptionsNoCallback
---@field loop      boolean?
---@field delay     number?
---@field delta     number?
---@field duration  number?
---@field easing    parcel.Easing?
---@field on_finish fun()?

---@class parcel.AnimationOptions: parcel.AnimationOptionsNoCallback
---@field callback fun(value: number)

local default_options = {
    loop = false,
    delay = 0,
    delta = 200,
    duration = 1000,
    easing = Easing.linear,
}

---@param options parcel.AnimationOptions
---@return parcel.Animation
function Animation.new(options)
    vim.validate("options.loop", options.loop, "boolean", true)
    vim.validate("options.delay", options.delay, "number", true)
    vim.validate("options.delta", options.delta, "number", true)
    vim.validate("options.duration", options.duration, "number", true)
    vim.validate("options.easing", options.easing, "function", true)
    vim.validate("options.callback", options.callback, "function")
    vim.validate("options.on_finish", options.on_finish, "function", true)

    return setmetatable(utils.privatise_options(vim.tbl_extend("force", default_options, options)), Animation)
end

function Animation:start()
    if not self._timer then
        self._timer = vim.uv.new_timer()
    end

    self._value = 0
    self._start_time = vim.uv.hrtime()

    self._timer:start(
        self._delay,
        self._delta,
        vim.schedule_wrap(function()
            self:on_tick()
        end)
    )
end

---@return number
function Animation:elapsed()
    if not self._start_time then
        return 0
    end

    return (vim.uv.hrtime() - self._start_time) / 1000000
end

---@private
function Animation:on_tick()
    local elapsed = self:elapsed()
    vim.print({ "tick", elapsed / self._duration })
    self._value = elapsed / self._duration

    if self._callback(self._easing(self._value)) == true then
        self:stop()
        return
    end

    if self._value >= 1.0 then
        if self._loop then
            self._value = 0
        end
    end

    if elapsed >= self._duration then
        self:stop()
    end
end

function Animation:stop()
    if not self._start_time then
        error("Animation was never started")
    end

    if self._timer then
        self._timer:stop()
    end

    if self._on_finish then
        self._on_finish(self:elapsed() >= self._duration)
    end
end

-- TODO: Either we have a TextAnimation directly in the grid or we
-- have a decoupled animation that changes a cell in the grid

---@param frames string[]
---@param callback fun(frame: string)
---@param options parcel.AnimationOptionsNoCallback
---@return parcel.Animation
function Animation.text(frames, callback, options)
    local frame_idx = 1

    local _options = vim.tbl_extend(
        "force",
        {
            delay = 0,
            easing = Easing.linear,
        },
        options,
        {
            callback = function(value)
                -- local frame_idx = (math.floor(value * #frames + 0.5) % #frames) + 1
                local frame = frames[frame_idx]
                -- vim.print(vim.inspect({ "frames", frames }))
                -- vim.print(vim.inspect({ "idx", frame_idx }))

                callback(frame)
                frame_idx = (frame_idx + 1) % #frames + 1
            end,
        }
    )

    return Animation.new(_options)
end

---@class parcel.Color
---@field red integer
---@field green integer
---@field blue integer

---@param colors { from: parcel.Color, to: parcel.Color }
---@param callback fun(color: parcel.Color)
---@param options parcel.AnimationOptionsNoCallback
---@return parcel.Animation
function Animation.color(colors, callback, options)
    local _options = vim.tbl_extend(
        "force",
        {
            delay = 0,
            easing = Easing.linear,
        },
        options,
        {
            callback = function(value)
                local color = colors.from -- TODO: Color.lerp(colors.from, colors.to, value)

                callback(color)
            end,
        }
    )

    return Animation.new(_options)
end

return Animation
