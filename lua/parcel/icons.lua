local icons = {}

local has_nvim_web_devicons, nvim_web_devicons = pcall(require, 'nvim-web-devicons')

function icons.get()
    if has_nvim_web_devicons then
        return nvim_web_devicons
    end
end

function icons.get_animation_frame(icon, idx)
    if type(icon) == "string" then
        return icon
    else
        return icon[((idx - 1) % #icon) + 1]
    end
end

return icons
