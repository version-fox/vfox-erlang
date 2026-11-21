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

-- load configuration from environment variables
function erlang_utils.get_config_from_env(env_name, default_value)
    return os.getenv(env_name) or default_value
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

function erlang_utils.check_version_existence(url)
    local resp, err = http.get({
        url = url,
    })
    if err ~= nil or resp.status_code ~= 200 then
        error(
            "Please confirm whether the corresponding Erlang/OTP release version exists! visit: https://github.com/erlang/otp/releases"
        )
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

function erlang_utils.get_erlang_release_versions()
    local search_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/versions.txt"

    -- Use prebuilt versions when USE_PREBUILT_OTP is explicitly set
    local use_prebuilt = erlang_utils.get_config_from_env("USE_PREBUILT_OTP")
    if use_prebuilt then
        -- Choose different prebuilt version lists based on platform
        if RUNTIME.osType == "darwin" then
            -- Use macOS specific prebuilt versions
            search_url =
                "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/macos_prebuilt_versions.txt"
        else
            -- Use Ubuntu prebuilt versions for Linux
            search_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/prebuilt_versions.txt"
        end
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

    local result = {}
    for line in string.gmatch(resp.body, "[^\r\n]+") do
        local version = erlang_utils.trim(line)
        if version ~= "" then
            table.insert(result, {
                version = version,
            })
        end
    end
    return result
end

return erlang_utils
