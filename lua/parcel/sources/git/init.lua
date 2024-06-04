---@type parcel.Source
local git_source = {}

local config = require("parcel.config")
local git = require("parcel.tasks.git")
local Path = require("parcel.path")

local github_url_format = "https://www.github.com/%s.git"

---@param parcel parcel.Parcel
local function url_from_parcel(parcel)
    return github_url_format:format(parcel:name())
end

function git_source.name()
    return "git"
end

function git_source.configuration_keys()
    return {
        {
            name = "tag",
            expected_types = { "string" },
        },
        {
            name = "commit",
            expected_types = { "string" },
            validator = function(commit_sha)
                -- TODO: Add commit validation
            end
        },
        {
            name = "branch",
            expected_types = { "string" },
        },
    }
end

function git_source.supported()
    if vim.fn.executable("git") == 0 then
        return {
            general = { false, "git is not an executable" }
        }
    end

    -- TODO: Get git version and compare

    return {
        general = { true }
    }
end

function git_source.install(parcel)
    return

--     local url = url_from_parcel(parcel)
--     local dir = Path.join(config.path, parcel:source(), parcel:name())
--     local result = git.clone(url, { dir = dir })

--     if result.exit_code ~= 0 then
--         return
--     end

--     vim.opt.runtimepath:append(dir)
end

return git_source
