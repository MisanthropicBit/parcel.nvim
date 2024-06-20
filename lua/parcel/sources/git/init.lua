---@type parcel.Source
local git_source = {}

local async = require("parcel.async")
local config = require("parcel.config")
local git = require("parcel.tasks.git")
local log = require("parcel.log")
local Path = require("parcel.path")

local github_url_format = "https://www.github.com/%s.git"

---@param parcel parcel.Parcel
local function url_from_parcel(parcel)
    return github_url_format:format(parcel:name())
end

---@param parcel parcel.Parcel
---@return string
local function get_git_directory(parcel)
    return Path.join(config.path, parcel:source_name(), parcel:name())
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

function git_source.write_section(parcel, section)
    local section_bullet = config.ui.icons.section_bullet

    if parcel:version() then
        section
            :add(
                "Version         ",
                "Keyword", -- ParcelSectionVersion",
                { sep = section_bullet }
            )
            :add(parcel:version())
            :newline()
    end

    if parcel:license() ~= nil and #parcel:license() > 0 then
        section:add(
                "License         ",
                "Keyword", -- "ParcelSectionLicense",
                { sep = section_bullet }
            )
            :add(parcel:license())
            :newline()
    end

    section
        :add(
            "Issues          ",
            "Keyword", -- "ParcelSectionIssues",
            { sep = section_bullet }
        )
        :add(parcel.issues_url)
        :newline()
        :add(
            "Pull requests   ",
            "Keyword", -- "ParcelSectionPulls",
            { sep = section_bullet }
        )
        :add(parcel.pulls_url)
        :newline()
end

function git_source.install(parcel)
    local url = url_from_parcel(parcel)
    local spec = parcel:spec()
    local dir = get_git_directory(parcel)
    local options = {
        branch = spec:get("branch"),
        tag = spec:get("tag"),
        commit = spec:get("commit"),
        dir = dir,
    }

    local ok, result = git.clone(url, options)

    if not ok then
        local args = { "Failed to clone repository", { url = url, err = result } }
        parcel:push_error(unpack(args))
        log.error(unpack(args))
        return
    end

    async.opt.runtimepath:append(dir)
end

function git_source.update(parcel, context)
    local dir = get_git_directory(parcel)

    -- TODO: Check that directory exists

    local spec_diff = context.spec_diff

    -- TODO: Handle different diff states
    local options = {
        branch = spec_diff.branch or nil,
        commit = spec_diff.commit or nil,
        tag = spec_diff.tag or nil,
    }

    local ok, result = git.checkout(dir, options)

    if not ok then
        local args = { "Failed to update git parcel", { err = result } }
        parcel:push_error(unpack(args))
        log.error(unpack(args))
    end
end

function git_source.uninstall()
end

return git_source
