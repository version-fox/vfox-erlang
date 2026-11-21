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

local test = require("vfox.test")

-- Fake http module: the version list is downloaded through it. It must be in place before
-- the plugin (and erlang_utils, which requires http) is loaded.
local responses = {}
package.loaded["http"] = {
    get = function(req)
        local response = responses[req.url]
        if response == nil then
            return nil, "no network in tests"
        end
        return response, nil
    end,
}

local plugin = test.load({ os = "linux", arch = "amd64", env = {} })
local erlang_utils = require("erlang_utils")

-- The count lives in a table: vfox's Lua VM (gopher-lua) can show a stale value for a
-- local captured by a closure after a pcall, which made the printed count wrong.
local counter = { checks = 0 }
local function check(condition, message)
    assert(condition, message)
    counter.checks = counter.checks + 1
end

check(erlang_utils.bob_build_name("26.2.3") == "OTP-26.2.3", "numeric releases take the OTP- prefix")
check(erlang_utils.bob_build_name("OTP-26.2.3") == "OTP-26.2.3", "names with the prefix are kept")
check(erlang_utils.bob_build_name("29.0-rc3") == "OTP-29.0-rc3", "release candidates take the prefix")
check(erlang_utils.bob_build_name("maint-27") == "maint-27", "maint names are kept")
check(erlang_utils.bob_build_name("master") == "master", "master is kept")

check(erlang_utils.trim("  26.2.3\r\n") == "26.2.3", "trim removes surrounding whitespace")
check(erlang_utils.shell_quote("/opt/a b") == "'/opt/a b'", "shell quoting keeps spaces")
check(erlang_utils.shell_quote("it's") == "'it'\\''s'", "shell quoting escapes apostrophes")

RUNTIME.osType = "windows"
check(erlang_utils.join("C:\\sdk", "bin") == "C:\\sdk\\bin", "windows join uses backslashes")
check(erlang_utils.join("C:\\sdk\\", "bin") == "C:\\sdk\\bin", "windows join keeps one separator")
check(erlang_utils.shell_quote('a"b') == '"a""b"', "cmd quoting doubles quotes")
RUNTIME.osType = "linux"
check(erlang_utils.join("/sdk/", "bin") == "/sdk/bin", "unix join keeps one separator")

-- find_bin_dir looks for the erl executable under each supported layout.
local files = {}
erlang_utils.file_exists = function(path)
    return files[path] ~= nil
end

files["/sdk/erlang/release/bin/erl"] = ""
check(erlang_utils.find_bin_dir("/sdk/erlang") == "/sdk/erlang/release/bin", "source builds keep bin under release")
files = {}
files["/sdk/erlang/bin/erl"] = ""
check(erlang_utils.find_bin_dir("/sdk/erlang") == "/sdk/erlang/bin", "prebuilt and linked roots keep bin at the top")
files = {}
files["/usr/lib/erlang/lib/erlang/bin/erl"] = ""
check(
    erlang_utils.find_bin_dir("/usr/lib/erlang") == "/usr/lib/erlang/lib/erlang/bin",
    "prefixes with lib/erlang are found"
)
files = {}
check(erlang_utils.find_bin_dir("/sdk/erlang") == "/sdk/erlang/release/bin", "missing bin falls back to release/bin")

RUNTIME.osType = "windows"
files = {}
files["C:\\vfox\\erlang\\release\\bin\\erl.exe"] = ""
check(erlang_utils.find_bin_dir("C:\\vfox\\erlang") == "C:\\vfox\\erlang\\release\\bin", "windows source installs")
files = {}
files["C:\\Program Files\\Erlang OTP 26\\bin\\erl.exe"] = ""
check(
    erlang_utils.find_bin_dir("C:\\Program Files\\Erlang OTP 26") == "C:\\Program Files\\Erlang OTP 26\\bin",
    "windows linked installs"
)
RUNTIME.osType = "linux"

-- The version list is parsed line by line and HTTP failures are reported.
local list_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/versions.txt"
responses[list_url] = { status_code = 200, body = "26.2.3\r\n25.3.2.12\n\n" }
local list = erlang_utils.get_erlang_release_versions()
check(#list == 2, "blank lines are skipped")
check(list[1].version == "26.2.3" and list[2].version == "25.3.2.12", "versions keep their order")

responses[list_url] = { status_code = 503, body = "" }
local http_ok, http_failure = pcall(erlang_utils.get_erlang_release_versions)
local http_reason = tostring(http_failure)
check(
    not http_ok and string.find(http_reason, "HTTP status 503", 1, true) ~= nil,
    "HTTP errors are reported: " .. http_reason
)

responses[list_url] = nil
local net_ok, net_failure = pcall(erlang_utils.get_erlang_release_versions)
local net_reason = tostring(net_failure)
check(
    not net_ok and string.find(net_reason, "version list", 1, true) ~= nil,
    "download errors name the version list: " .. net_reason
)

-- USE_PREBUILT_OTP only changes the list on macOS and Linux. An empty value is unset, and an
-- unknown Linux release is an error instead of a list of other builds.
local function with_env(env, fn)
    local original = os.getenv
    os.getenv = function(name)
        return env[name]
    end
    local ok, result = pcall(fn)
    os.getenv = original
    if not ok then
        error(result, 0)
    end
    return result
end

local function search_on(os_name, env)
    local saved = RUNTIME.osType
    RUNTIME.osType = os_name
    local ok, result = pcall(with_env, env, erlang_utils.get_erlang_release_versions)
    RUNTIME.osType = saved
    if not ok then
        error(result, 0)
    end
    return result
end

local base_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/"
responses[base_url .. "versions.txt"] = { status_code = 200, body = "26.2.3\n" }
responses[base_url .. "macos_prebuilt_versions.txt"] = { status_code = 200, body = "25.3.2.12\n" }

check(search_on("linux", { USE_PREBUILT_OTP = "" })[1].version == "26.2.3", "an empty USE_PREBUILT_OTP is unset")
check(
    search_on("windows", { USE_PREBUILT_OTP = "ubuntu-22.04" })[1].version == "26.2.3",
    "windows ignores the variable"
)
check(search_on("darwin", { USE_PREBUILT_OTP = "true" })[1].version == "25.3.2.12", "macOS uses its prebuilt list")

-- Linux searches the list of the release that USE_PREBUILT_OTP names.
responses[base_url .. "prebuilt/ubuntu-24.04.txt"] = { status_code = 200, body = "OTP-29.1.2\nOTP-28.4.2\n" }
responses[base_url .. "prebuilt/ubuntu-20.04.txt"] = { status_code = 200, body = "OTP-20.0\n" }
local noble = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" })
check(#noble == 2 and noble[1].version == "OTP-29.1.2", "ubuntu-24.04 lists its own builds")
local focal = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-20.04" })
check(#focal == 1 and focal[1].version == "OTP-20.0", "ubuntu-20.04 lists its own builds")

local search_ok, search_err = pcall(search_on, "linux", { USE_PREBUILT_OTP = "ubuntu-99.04" })
check(
    not search_ok and string.find(tostring(search_err), "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "search rejects an unknown release: " .. tostring(search_err)
)

-- Available is the hook that vfox calls; it returns the same list.
responses[list_url] = { status_code = 200, body = "26.2.3\n" }
local available = plugin:Available({})
check(#available == 1 and available[1].version == "26.2.3", "Available returns the list")

print("erlang_utils_test: " .. counter.checks .. " checks passed")
