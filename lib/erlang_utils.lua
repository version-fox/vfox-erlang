-- Copyright 2026 vfox-erlang contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local http = require("http")

local erlang_utils = {}

function erlang_utils.peek_lua_table(o, indent)
    indent = indent or 0

    local function handle_table(t, currentIndent)
        local result = {}
        for k, v in pairs(t) do
            local key = type(k) ~= "number" and ("[" .. erlang_utils.peek_lua_table(k, currentIndent + 1) .. "]") or ""
            local value = type(v) == "table" and handle_table(v, currentIndent + 1)
                or erlang_utils.peek_lua_table(v, currentIndent + 1)
            table.insert(result, key .. (key ~= "" and " = " or "") .. value)
        end
        return "{\n" .. table.concat(result, ",\n") .. "\n" .. string.rep("  ", currentIndent) .. "}"
    end

    if type(o) == "table" then
        return handle_table(o, indent)
    else
        return tostring(o)
    end
end

--- Returns text without leading and trailing whitespace.
function erlang_utils.trim(value)
    return (string.gsub(string.gsub(value, "^%s+", ""), "%s+$", ""))
end

function erlang_utils.array_contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

-- Loads a setting from an environment variable. An empty value counts as unset, so that
-- USE_PREBUILT_OTP= turns prebuilt mode off.
function erlang_utils.get_config_from_env(env_name, default_value)
    local value = os.getenv(env_name)
    if value == nil or value == "" then
        return default_value
    end
    return value
end

--- Ubuntu releases that have prebuilt Erlang/OTP builds on builds.hex.pm (Bob).
erlang_utils.PREBUILT_OS_RELEASES = {
    "ubuntu-14.04",
    "ubuntu-16.04",
    "ubuntu-18.04",
    "ubuntu-20.04",
    "ubuntu-22.04",
    "ubuntu-24.04",
    "ubuntu-26.04",
}

--- Returns the USE_PREBUILT_OTP value when it names a supported Ubuntu release. Any other value
--- is an error that lists the supported values.
function erlang_utils.check_prebuilt_release(release)
    if not erlang_utils.array_contains(erlang_utils.PREBUILT_OS_RELEASES, release) then
        error(
            "USE_PREBUILT_OTP must be one of: "
                .. table.concat(erlang_utils.PREBUILT_OS_RELEASES, ", ")
                .. ". Got: "
                .. release
        )
    end
    return release
end

--- The other spelling of a release name: 29.1.2 for OTP-29.1.2, and OTP-29.1.2 for 29.1.2. Other
--- names, such as branches, have none and give nil.
function erlang_utils.other_release_spelling(version)
    if type(version) ~= "string" then
        return nil
    end
    if string.match(version, "^OTP%-%d") then
        return string.sub(version, 5)
    end
    if string.match(version, "^%d") then
        return "OTP-" .. version
    end
    return nil
end

--- The name a release has in the Linux prebuilt list: the OTP- prefix dropped, as the other lists
--- show it. Branch names keep their names.
function erlang_utils.bare_release_name(name)
    return string.match(name, "^OTP%-(%d.*)$") or name
end

--- Returns the URL of the builds.hex.pm index that lists the builds of one Ubuntu release for the
--- architecture vfox runs on. The install downloads from the same host and architecture.
function erlang_utils.prebuilt_index_url(release)
    return "https://builds.hex.pm/builds/otp/" .. RUNTIME.archType .. "/" .. release .. "/builds.txt"
end

--- Returns true when vfox runs the plugin on Windows.
function erlang_utils.is_windows()
    return RUNTIME ~= nil and RUNTIME.osType == "windows"
end

--- Returns the path separator of the platform vfox runs on.
function erlang_utils.path_sep()
    if erlang_utils.is_windows() then
        return "\\"
    end
    return "/"
end

--- Joins a directory and one path segment with the platform separator.
function erlang_utils.join(left, right)
    local last = string.sub(left, -1)
    if last == "/" or last == "\\" then
        return left .. right
    end
    return left .. erlang_utils.path_sep() .. right
end

--- Quotes a value for the shell that runs os.execute: cmd.exe on Windows, sh elsewhere.
function erlang_utils.shell_quote(value)
    if erlang_utils.is_windows() then
        return '"' .. string.gsub(value, '"', '""') .. '"'
    end
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

--- Returns true when the path can be opened for reading.
function erlang_utils.file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

function erlang_utils.directory_exists(path)
    return erlang_utils.file_exists(path)
end

--- Returns the name builds.hex.pm uses for a version. Numeric releases such as 26.2.3 are
--- published as OTP-26.2.3; maint-27, master and names that already start with OTP- are
--- used unchanged.
function erlang_utils.bob_build_name(version)
    if string.match(version, "^%d") then
        return "OTP-" .. version
    end
    return version
end

--- Returns the bin directory of an Erlang/OTP root. Source builds of this plugin keep bin
--- under release/, prebuilt and linked installs keep it at the root, and some prefixes keep
--- the root under lib/erlang.
function erlang_utils.find_bin_dir(root)
    local exe = erlang_utils.is_windows() and "erl.exe" or "erl"
    local candidates = { { "release", "bin" }, { "bin" }, { "lib", "erlang", "bin" } }
    for _, parts in ipairs(candidates) do
        local dir = root
        for _, part in ipairs(parts) do
            dir = erlang_utils.join(dir, part)
        end
        if erlang_utils.file_exists(erlang_utils.join(dir, exe)) then
            return dir
        end
    end
    return erlang_utils.join(erlang_utils.join(root, "release"), "bin")
end

--- Splits a release name such as OTP-29.1.2, 29.1.2 or OTP-29.0-rc3 into its numbers. A release
--- candidate also gives its number. Branch names such as master or maint-28 give nil.
local function release_of(name)
    local bare = string.gsub(name, "^OTP%-", "")
    local base, candidate = string.match(bare, "^([%d%.]+)%-rc(%d+)$")
    if base == nil then
        base = string.match(bare, "^[%d%.]+$")
        if base == nil then
            return nil
        end
    end
    local numbers = {}
    for number in string.gmatch(base, "%d+") do
        table.insert(numbers, tonumber(number))
    end
    return { numbers = numbers, candidate = candidate and tonumber(candidate) }
end

--- True when release a is newer than release b. Final releases come before release candidates;
--- between releases of the same kind, the higher numbers come first.
local function newer_release(a, b)
    if (a.candidate == nil) ~= (b.candidate == nil) then
        return a.candidate == nil
    end
    for i = 1, math.max(#a.numbers, #b.numbers) do
        local x, y = a.numbers[i] or 0, b.numbers[i] or 0
        if x ~= y then
            return x > y
        end
    end
    return (a.candidate or 0) > (b.candidate or 0)
end

--- Orders the names of a prebuilt list for `vfox install erlang@latest`, which installs the first
--- name: the newest final release, then the release candidates, then the branches (master,
--- maint-*) in descending string order.
local function sort_prebuilt_names(names)
    local releases = {}
    for _, name in ipairs(names) do
        releases[name] = release_of(name)
    end
    table.sort(names, function(a, b)
        local ra, rb = releases[a], releases[b]
        if ra and rb then
            if newer_release(ra, rb) then
                return true
            end
            if newer_release(rb, ra) then
                return false
            end
        elseif ra or rb then
            return ra ~= nil
        end
        return a > b
    end)
end

function erlang_utils.get_erlang_release_versions()
    local search_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/versions.txt"

    -- USE_PREBUILT_OTP selects the prebuilt list of the platform. Windows always uses the official
    -- installer, so its list does not change.
    local use_prebuilt = erlang_utils.get_config_from_env("USE_PREBUILT_OTP")
    local prebuilt_list = use_prebuilt ~= nil and (RUNTIME.osType == "darwin" or RUNTIME.osType == "linux")
    -- Bob's names carry the OTP- prefix; the Linux list shows release names without it.
    local bob_names = use_prebuilt ~= nil and RUNTIME.osType == "linux"
    if use_prebuilt and RUNTIME.osType == "darwin" then
        search_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/macos_prebuilt_versions.txt"
    elseif use_prebuilt and RUNTIME.osType == "linux" then
        -- Bob lists the builds of each Ubuntu release in its own index. Read that index, so the list
        -- is the one the install downloads from.
        local release = erlang_utils.check_prebuilt_release(use_prebuilt)
        search_url = erlang_utils.prebuilt_index_url(release)
    end

    local resp, err = http.get({
        url = search_url,
    })
    if err ~= nil or resp == nil then
        error("Failed to download the Erlang/OTP version list from " .. search_url .. ": " .. tostring(err))
    end
    if resp.status_code ~= 200 then
        error(
            "Failed to download the Erlang/OTP version list from "
                .. search_url
                .. ", HTTP status "
                .. tostring(resp.status_code)
        )
    end

    -- The first column is the name. The jsDelivr lists hold one name per line; builds.txt adds the
    -- commit and the build time after it.
    local names = {}
    for line in string.gmatch(resp.body, "[^\r\n]+") do
        local name = string.match(erlang_utils.trim(line), "^%S+")
        if name then
            if bob_names then
                name = erlang_utils.bare_release_name(name)
            end
            table.insert(names, name)
        end
    end
    if prebuilt_list then
        sort_prebuilt_names(names)
    else
        -- The generated lists are already in descending string order.
        table.sort(names, function(a, b)
            return a > b
        end)
    end
    local result = {}
    for _, name in ipairs(names) do
        table.insert(result, {
            version = name,
        })
    end
    return result
end

--- Returns true for the names of Erlang/OTP branches: master, maint, maint-<number>, and the names that end
--- in latest, such as master-latest on macOS. The version lists hold releases, so branches are not looked up.
function erlang_utils.is_branch_name(name)
    return name == "master"
        or name == "maint"
        or string.match(name, "^maint%-") ~= nil
        or string.match(name, "latest$") ~= nil
end

--- Returns true when name is one of the versions of a list from get_erlang_release_versions. Both
--- spellings match: OTP-29.1.2 is the release that the list shows as 29.1.2.
function erlang_utils.is_listed(name, versions)
    local bare = erlang_utils.bare_release_name(name)
    for _, item in ipairs(versions) do
        if erlang_utils.bare_release_name(item.version) == bare then
            return true
        end
    end
    return false
end

--- Refuses a version name that the version list does not show, before anything is downloaded. Such a name
--- would fail in the download with a generic message. When the list cannot be read, the check is skipped with
--- a note: the download decides, as it did before the check existed.
function erlang_utils.check_version_listed(name)
    local ok, versions = pcall(erlang_utils.get_erlang_release_versions)
    if not ok then
        print("Could not read the version list, so " .. name .. " is not checked against it: " .. tostring(versions))
        return
    end
    if not erlang_utils.is_listed(name, versions) then
        error(
            "Erlang/OTP "
                .. name
                .. " is not in the version list, so it cannot be installed. Run `vfox search erlang` to see the names"
                .. " that can be installed. A partial name, such as 28, is not one of them."
        )
    end
end

-- The characters that OTP's configure cannot take in the install path, with their names for the error.
-- configure runs the prefix, which is single-quoted, and the source directory, which is double-quoted,
-- through eval. An apostrophe ends the single quotes; a double quote, a dollar sign or a backtick ends or
-- changes the double quotes.
local CONFIGURE_PATH_PROBLEMS = {
    { "'", "an apostrophe" },
    { '"', "a double quote" },
    { "$", "a dollar sign" },
    { "`", "a backtick" },
}

--- Refuses a source build whose install path holds one of the characters above, before configure starts.
--- Without the check the build fails part way through, or it configures a different directory.
function erlang_utils.check_configure_path(path)
    local found = {}
    for _, problem in ipairs(CONFIGURE_PATH_PROBLEMS) do
        if string.find(path, problem[1], 1, true) ~= nil then
            table.insert(found, problem[2])
        end
    end
    if #found > 0 then
        error(
            "The Erlang/OTP install path "
                .. path
                .. " contains "
                .. table.concat(found, " and ")
                .. ", which OTP's configure cannot take. Set VFOX_HOME to a path without apostrophes, double quotes,"
                .. " dollar signs or backticks, then install again."
        )
    end
end

return erlang_utils
