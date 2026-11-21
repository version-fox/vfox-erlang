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
responses[list_url] = { status_code = 200, body = "25.3.2.12\r\n26.2.3\n\n" }
local list = erlang_utils.get_erlang_release_versions()
check(#list == 2, "blank lines are skipped")
check(list[1].version == "26.2.3" and list[2].version == "25.3.2.12", "versions are listed in descending order")

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

local function search_on(os_name, env, arch)
    local saved_os, saved_arch = RUNTIME.osType, RUNTIME.archType
    RUNTIME.osType, RUNTIME.archType = os_name, arch or "amd64"
    local ok, result = pcall(with_env, env, erlang_utils.get_erlang_release_versions)
    RUNTIME.osType, RUNTIME.archType = saved_os, saved_arch
    if not ok then
        error(result, 0)
    end
    return result
end

local base_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/"
responses[base_url .. "versions.txt"] = { status_code = 200, body = "26.2.3\n" }
responses[base_url .. "macos_prebuilt_versions.txt"] = {
    status_code = 200,
    body = "master-latest\n25.3.2.12\nmaint-latest\n26.2.3\n",
}

check(search_on("linux", { USE_PREBUILT_OTP = "" })[1].version == "26.2.3", "an empty USE_PREBUILT_OTP is unset")
check(
    search_on("windows", { USE_PREBUILT_OTP = "ubuntu-22.04" })[1].version == "26.2.3",
    "windows ignores the variable"
)
local mac = search_on("darwin", { USE_PREBUILT_OTP = "true" })
check(
    #mac == 4
        and mac[1].version == "26.2.3"
        and mac[2].version == "25.3.2.12"
        and mac[3].version == "master-latest"
        and mac[4].version == "maint-latest",
    "macOS lists the newest release first, then the branches"
)

-- Linux reads the builds.txt index of the release that USE_PREBUILT_OTP names, for the
-- architecture vfox runs on. Each line is a name, then the commit and the build time.
local index_body =
    "OTP-28.4.2 0863bd30 2026-04-26T03:41:09Z\nmaster abc 2026-04-26T03:41:09Z\r\n\nOTP-29.1.2 9d37 2026-04-26T02:55:31Z\n"
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt"] = { status_code = 200, body = index_body }
local noble = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" })
check(
    #noble == 3
        and noble[1].version == "OTP-29.1.2"
        and noble[2].version == "OTP-28.4.2"
        and noble[3].version == "master",
    "ubuntu-24.04 lists the newest release first, then the branches"
)
-- `latest` installs the first name, so the order matters: the newest final release, then the
-- release candidates, then the branches. Numbers compare as numbers: 25.3.2.10 is newer than 25.3.2.9.
local order_body = "maint-28\nOTP-29.0-rc3\nOTP-25.3.2.9\nOTP-25.3.2.10\nOTP-29.1.2\nmaster\nOTP-29.1\n"
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt"] = { status_code = 200, body = order_body }
local ordered = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" })
local ordered_names = {}
for i, entry in ipairs(ordered) do
    ordered_names[i] = entry.version
end
check(
    table.concat(ordered_names, " ") == "OTP-29.1.2 OTP-29.1 OTP-25.3.2.10 OTP-25.3.2.9 OTP-29.0-rc3 master maint-28",
    "release order: " .. table.concat(ordered_names, " ")
)
responses["https://builds.hex.pm/builds/otp/arm64/ubuntu-24.04/builds.txt"] =
    { status_code = 200, body = "OTP-26.2.3 aaa 2026-01-01T00:00:00Z\n" }
local arm = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" }, "arm64")
check(#arm == 1 and arm[1].version == "OTP-26.2.3", "arm64 reads the arm64 index")
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-20.04/builds.txt"] =
    { status_code = 200, body = "OTP-20.0 040bdce6 2020-10-29T08:19:13Z\n" }
local focal = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-20.04" })
check(#focal == 1 and focal[1].version == "OTP-20.0", "ubuntu-20.04 reads its own index")
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-26.04/builds.txt"] =
    { status_code = 200, body = "OTP-26.0 8c0ea6bd 2026-04-24T21:11:44Z\n" }
local resolute = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-26.04" })
check(#resolute == 1 and resolute[1].version == "OTP-26.0", "ubuntu-26.04 reads its own index")

local search_ok, search_err = pcall(search_on, "linux", { USE_PREBUILT_OTP = "ubuntu-99.04" })
check(
    not search_ok and string.find(tostring(search_err), "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "search rejects an unknown release: " .. tostring(search_err)
)
check(string.find(tostring(search_err), "ubuntu-26.04", 1, true) ~= nil, "the error lists ubuntu-26.04")

-- Available is the hook that vfox calls; it returns the same list.
responses[list_url] = { status_code = 200, body = "26.2.3\n" }
local available = plugin:Available({})
check(#available == 1 and available[1].version == "26.2.3", "Available returns the list")

print("erlang_utils_test: " .. counter.checks .. " checks passed")
