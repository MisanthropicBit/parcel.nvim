---@type parcel.Source
---@diagnostic disable-next-line: missing-fields
local git_source = {}

local async = require("parcel.async")
local config = require("parcel.config")
local git = require("parcel.tasks.git")
local lockfile = require("parcel.lockfile")
local log = require("parcel.log")
local Path = require("parcel.path")
local tblx = require("parcel.tblx")

local github_url_format = "https://www.github.com/%s.git"

---@param parcel parcel.Parcel
local function url_from_parcel(parcel)
    return github_url_format:format(parcel:name())
end

---@param parcel parcel.Parcel
---@return string
local function get_git_directory(parcel)
    return Path.join(config.path, parcel:source(), parcel:name())
end

---@param commit_sha string
local function validate_commit_sha(commit_sha)
    if #commit_sha < 7 or #commit_sha > 40 then
        error("git sha must be between 7 and 40 characters")
    end

    local match = vim.fn.match(commit_sha, [[^[a-fA-F0-9]\+$]]) ~= -1

    if not match then
        error("not a valid git sha")
    end
end

local function options_from_spec_diff(spec_diff, keys)
    local options = {}

    for _, key in ipairs(keys) do
        local state = spec_diff[key]

        if state then
            local diff_state = state[1]

            if diff_state == tblx.TableDiffState.Added or diff_state == tblx.TableDiffState.Changed then
                options[key] = state[2]
            end
        end
    end

    return options
end

function git_source.name()
    return "git"
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

    section
        :newline()
        :add("Url    ", "Keyword", { sep = section_bullet })
        :add(url_from_parcel(parcel))
        :newline()
        :add("Commit   ", "Keyword", { sep = section_bullet })
        :add(parcel:spec().rev)
        :newline()

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
end

---@param msg string
---@param result any
---@param parcel parcel.Parcel
local function report_source_error(msg, result, parcel)
    local args = { msg, { err = result } }

    parcel:push_error(unpack(args))
    log.error(unpack(args))
    error(args)
end

function git_source.has_update(parcel, context)
end

function git_source.update(parcel, context)
    local dir = get_git_directory(parcel)
    local dir_exists, dir_err = async.fs.dir_exists(parcel:path())

    if not dir_exists then
        report_source_error(dir_err, nil, parcel)
    end

    local url = url_from_parcel(parcel)
    local options = {
        dir = get_git_directory(parcel),
    }

    local ok, result = git.pull(url, options)

    if not ok then
        report_source_error("Failed to clone repository", { url = url, err = result }, parcel)
        return
    end
end

return git_source
