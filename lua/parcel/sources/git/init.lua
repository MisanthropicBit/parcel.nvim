---@type parcel.Source
local git_source = {}

local async = require("parcel.async")
local config = require("parcel.config")
local git = require("parcel.tasks.git")
local Path = require("parcel.path")

local github_url_format = "https://www.github.com/%s.git"

---@param parcel parcel.Parcel
local function url_from_parcel(parcel)
    return github_url_format:format(parcel:name())
end

---@param commit_sha string
---@return boolean
---@return string?
local function validate_commit_sha(commit_sha)
    if #commit_sha < 7 or #commit_sha > 40 then
        return false, "git sha must be between 7 and 40 characters"
    end

    local match = vim.fn.match(commit_sha, [[^[a-fA-F0-9]\+$]]) ~= -1

    if not match then
        return false, "not a valid git sha"
    end

    return true
end

function git_source.name()
    return "git"
end

-- TODO: This doesn't encode mutual exclusivity
function git_source.configuration_keys()
    return {
        tag = {
            name = "tag",
            expected_types = { "string" },
        },
        commit = {
            name = "commit",
            expected_types = { "string" },
            validator = validate_commit_sha,
        },
        branch = {
            name = "branch",
            expected_types = { "string" },
        },
        version = {
            name = "version",
            expected_types = { "string" },
            -- TODO: validator = version.validate,
        }
    }
end

function git_source.validate(parcel, keys)
    local count = (keys["branch"] and 1 or 0) + (keys["commit"] and 1 or 0) + (keys["tag"] and 1 or 0)

    if count > 1 then
        parcel:push_error(
            "Configuration keys 'branch', 'commit', and 'tag' are mutually exclusive"
        )
        return false
    end

    return true
end

function git_source.supported()
    if vim.fn.executable("git") == 0 then
        return {
            general = { false, "git is not an executable or is not in path" }
        }
    end

    -- TODO: Get git version and compare

    return {
        general = { true }
    }
end

function git_source.install(parcel)
    local url = url_from_parcel(parcel)
    local spec = parcel:spec()
    local dir = Path.join(config.path, parcel:source(), parcel:name())
    local options = {
        branch = spec.branch,
        tag = spec.tag,
        -- commit = spec.commit,
        dir = dir,
    }

    local ok, result = git.clone(url, options)

    if not ok then
        parcel:push_error("Failed to clone repository", { url = url, err = result })
        return
    end

    async.opt.runtimepath:append(dir)
end

return git_source
