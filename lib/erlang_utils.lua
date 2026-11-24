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

--- Refuses a USE_PREBUILT_OTP value that names no supported Linux release, as get_erlang_release_versions does.
--- check_version_listed runs it before it reads the list, so a bad value is reported as such, and not as a list
--- that could not be read.
function erlang_utils.check_prebuilt_config()
    local use_prebuilt = erlang_utils.get_config_from_env("USE_PREBUILT_OTP")
    if use_prebuilt ~= nil and RUNTIME.osType == "linux" then
        erlang_utils.check_prebuilt_release(use_prebuilt)
    end
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

--- Returns the file name of the official Windows installer of a release, given its bare version. amd64 has the
--- 64-bit installer. Every other architecture gets the 32-bit one.
function erlang_utils.windows_installer_name(version, arch)
    if arch == "amd64" then
        return "otp_win64_" .. version .. ".exe"
    end
    return "otp_win32_" .. version .. ".exe"
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

--- Asks the server whether the file at url is there, with a HEAD request, so that nothing is downloaded. Redirects
--- are followed: GitHub's release downloads redirect to the storage of the file. Returns true when the file is there,
--- false when the server answers 404, and nil with the reason when the answer is neither, such as a failed request.
function erlang_utils.url_exists(url)
    local resp, err = http.head({
        url = url,
    })
    if err ~= nil or resp == nil then
        return nil, tostring(err)
    end
    if resp.status_code == 200 then
        return true
    end
    if resp.status_code == 404 then
        return false
    end
    return nil, "HTTP status " .. tostring(resp.status_code)
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

--- The SHA-256 that builds.txt publishes for a build, in lowercase, which is how vfox compares it. A column that is
--- not 64 hexadecimal digits is not a checksum, so the result is nil and vfox skips the check for that build.
local function checksum_of(value)
    if value ~= nil and #value == 64 and string.match(value, "^%x+$") then
        return string.lower(value)
    end
    return nil
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

    -- The first column is the name. The jsDelivr lists hold one name per line. builds.txt adds the commit and
    -- the build time, and for most builds the SHA-256 of the archive, which PreInstall passes to vfox.
    local names = {}
    local checksums = {}
    for line in string.gmatch(resp.body, "[^\r\n]+") do
        local fields = {}
        for field in string.gmatch(line, "%S+") do
            table.insert(fields, field)
        end
        local name = fields[1]
        if name then
            if bob_names then
                name = erlang_utils.bare_release_name(name)
                checksums[name] = checksum_of(fields[4])
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
            sha256 = checksums[name],
        })
    end
    return result
end

--- Returns true for the names of the Erlang/OTP branches master, maint and maint-<number>. A branch is fetched by
--- its name, so it is not looked up in a version list.
function erlang_utils.is_branch_name(name)
    return name == "master" or name == "maint" or string.match(name, "^maint%-%d+$") ~= nil
end

--- Returns true for the macOS prebuilt branches, whose names end in latest: master-latest, maint-latest and
--- maint-<number>-latest. They are branches only when USE_PREBUILT_OTP is set on macOS, where erlef/otp_builds
--- provides them. Elsewhere such a name is a release, and it must be listed.
function erlang_utils.is_macos_prebuilt_branch(name)
    return name == "master-latest" or name == "maint-latest" or string.match(name, "^maint%-%d+%-latest$") ~= nil
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

--- Returns the SHA-256 that builds.txt publishes for the build called name, from a list that
--- get_erlang_release_versions read. Both spellings match, as in is_listed. nil when the index has no value for
--- the build, or when there is no list.
function erlang_utils.published_sha256(versions, name)
    if versions == nil then
        return nil
    end
    local bare = erlang_utils.bare_release_name(name)
    for _, item in ipairs(versions) do
        if item.sha256 ~= nil and erlang_utils.bare_release_name(item.version) == bare then
            return item.sha256
        end
    end
    return nil
end

--- Returns the command that lists the names this plugin can install with the current settings. With
--- USE_PREBUILT_OTP set on Linux or macOS, get_erlang_release_versions reads the prebuilt list, so the command
--- carries the variable. Otherwise it is the plain command: Windows always uses its official installers, so its
--- list does not change with the variable.
function erlang_utils.search_command()
    local use_prebuilt = erlang_utils.get_config_from_env("USE_PREBUILT_OTP")
    if use_prebuilt ~= nil and (RUNTIME.osType == "darwin" or RUNTIME.osType == "linux") then
        local value = use_prebuilt
        if not string.match(value, "^[%w%._%-]+$") then
            value = erlang_utils.shell_quote(value)
        end
        return "USE_PREBUILT_OTP=" .. value .. " vfox search erlang"
    end
    return "vfox search erlang"
end

--- Reads the version list. The value of USE_PREBUILT_OTP is checked first, so a bad value is an error and not a
--- list that could not be read. Returns the list, or nil and the reason when the list cannot be read.
function erlang_utils.read_version_list()
    erlang_utils.check_prebuilt_config()
    local ok, result = pcall(erlang_utils.get_erlang_release_versions)
    if not ok then
        return nil, tostring(result)
    end
    return result, nil
end

--- Refuses a version name that the version list does not show, before anything is downloaded. Such a name
--- would fail in the download with a generic message. When the list cannot be read, the check is skipped with
--- a note: the download decides, as it did before the check existed. Returns the list it checked, or nil.
function erlang_utils.check_version_listed(name)
    local versions, reason = erlang_utils.read_version_list()
    if versions == nil then
        print("Could not read the version list, so " .. name .. " is not checked against it: " .. reason)
        return nil
    end
    if not erlang_utils.is_listed(name, versions) then
        error(
            "Erlang/OTP "
                .. name
                .. " is not in the version list, so it cannot be installed. Run `"
                .. erlang_utils.search_command()
                .. "` to see the names that can be installed. A partial name, such as 28, is not one of them."
        )
    end
    return versions
end

-- The characters that OTP's configure cannot take in the install path, with their names for the error.
-- configure runs the prefix, which is single-quoted, and the source directory, which is double-quoted,
-- through eval. An apostrophe ends the single quotes; a double quote, a dollar sign or a backtick ends or
-- changes the double quotes. configure also runs `cd ${PWD}` without quotes, so the shell splits the path at a
-- space, a tab or a newline there, and the timestamp check fails.
local CONFIGURE_PATH_PROBLEMS = {
    { "'", "an apostrophe" },
    { '"', "a double quote" },
    { "$", "a dollar sign" },
    { "`", "a backtick" },
    { " ", "a space" },
    { "\t", "a tab" },
    { "\n", "a newline" },
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
                .. ", which OTP's configure cannot take. Set VFOX_HOME to a path without spaces, tabs, newlines,"
                .. " apostrophes, double quotes, dollar signs or backticks, then install again."
        )
    end
end

return erlang_utils
