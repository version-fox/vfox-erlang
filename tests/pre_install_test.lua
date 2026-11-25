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

-- test.load may run only once per file, so environment variables and the platform are
-- swapped in around each call instead.
local plugin = test.load({ os = "linux", arch = "amd64", env = {} })
local erlang_utils = require("erlang_utils")

-- The version list is read over the network, so the checks use a fixed list. list_state counts the reads,
-- and failure makes a read fail, as on a machine without a network: the read returns nil and the reason. It is a
-- table for the same reason as the counter below.
local list_state = { reads = 0, failure = nil }
erlang_utils.get_erlang_release_versions = function()
    list_state.reads = list_state.reads + 1
    if list_state.failure ~= nil then
        return nil, list_state.failure
    end
    return {
        { version = "29.1.2" },
        { version = "29.0-rc3" },
        { version = "26.2.3" },
        { version = "25.3.2.12" },
    }
end

-- Each arm64 Windows install asks for its installer with a HEAD request. probe_state records the URLs that are
-- asked, and answer is what the stub returns: true or false, or nil with reason when the request fails.
local probe_state = { urls = {}, answer = true, reason = nil }
erlang_utils.url_exists = function(url)
    table.insert(probe_state.urls, url)
    if probe_state.answer == nil then
        return nil, probe_state.reason
    end
    return probe_state.answer
end

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

local function with_runtime(os_name, arch, fn)
    local saved_os, saved_arch = RUNTIME.osType, RUNTIME.archType
    RUNTIME.osType, RUNTIME.archType = os_name, arch
    local ok, result = pcall(fn)
    RUNTIME.osType, RUNTIME.archType = saved_os, saved_arch
    if not ok then
        error(result, 0)
    end
    return result
end

local function pre_install(env, version, os_name, arch)
    return with_env(env, function()
        return with_runtime(os_name, arch, function()
            return plugin:PreInstall({ version = version })
        end)
    end)
end

-- A refusal prints its message and returns nil. pre_install_printed returns the result and the printed lines. The
-- hook must not raise: an error would fail the test, because vfox prints a traceback below an error.
local function pre_install_printed(env, version, os_name, arch)
    local printed = {}
    local original_print = print
    print = function(...)
        table.insert(printed, table.concat({ ... }, "\t"))
    end
    local ok, result = pcall(pre_install, env, version, os_name, arch)
    print = original_print
    if not ok then
        error(result, 0)
    end
    return result, printed
end

local function printed_has(printed, text)
    for _, line in ipairs(printed) do
        if string.find(line, text, 1, true) ~= nil then
            return true
        end
    end
    return false
end

-- The count lives in a table: vfox's Lua VM (gopher-lua) can show a stale value for a
-- local captured by a closure after a pcall, which made the printed count wrong.
local counter = { checks = 0 }
local function check(condition, message)
    assert(condition, message)
    counter.checks = counter.checks + 1
end

-- Linux prebuilt: numeric versions are published with the OTP- prefix (builds.hex.pm).
local result = pre_install({ USE_PREBUILT_OTP = "ubuntu-22.04" }, "26.2.3", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/OTP-26.2.3.tar.gz",
    "prebuilt numeric version: " .. result.url
)
check(result.version == "26.2.3", "prebuilt keeps the requested version")

result = pre_install({ USE_PREBUILT_OTP = "ubuntu-22.04" }, "OTP-26.2.3", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/OTP-26.2.3.tar.gz",
    "prebuilt OTP- name is not prefixed twice: " .. result.url
)
check(result.version == "26.2.3", "an OTP- name is installed as the bare version")

result = pre_install({ USE_PREBUILT_OTP = "ubuntu-24.04" }, "maint-27", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/maint-27.tar.gz",
    "prebuilt maint branch: " .. result.url
)
check(result.version == "maint-27", "a branch keeps its name")

result = pre_install({ USE_PREBUILT_OTP = "ubuntu-24.04" }, "OTP-29.0-rc3", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-29.0-rc3.tar.gz",
    "prebuilt release candidate: " .. result.url
)
check(result.version == "29.0-rc3", "a release candidate is installed as the bare version")

-- Ubuntu 26.04 is published by Bob for amd64 and arm64.
result = pre_install({ USE_PREBUILT_OTP = "ubuntu-26.04" }, "26.2.3", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-26.04/OTP-26.2.3.tar.gz",
    "prebuilt ubuntu-26.04: " .. result.url
)

local unknown, unknown_printed = pre_install_printed({ USE_PREBUILT_OTP = "ubuntu-99.04" }, "26.2.3", "linux", "amd64")
check(
    unknown == nil and printed_has(unknown_printed, "USE_PREBUILT_OTP must be one of"),
    "unknown release is refused with a message: " .. table.concat(unknown_printed, " | ")
)

-- An empty USE_PREBUILT_OTP is unset, so the source archive is used.
result = pre_install({ USE_PREBUILT_OTP = "" }, "26.2.3", "linux", "amd64")
check(
    result.url == "https://github.com/erlang/otp/archive/refs/tags/OTP-26.2.3.tar.gz",
    "empty USE_PREBUILT_OTP: " .. result.url
)

-- Source builds: release tags are OTP-<version>; master and maint branches come from refs/heads.
result = pre_install({}, "26.2.3", "linux", "amd64")
check(result.url == "https://github.com/erlang/otp/archive/refs/tags/OTP-26.2.3.tar.gz", "source tag: " .. result.url)
result = pre_install({}, "OTP-26.2.3", "linux", "amd64")
check(
    result.url == "https://github.com/erlang/otp/archive/refs/tags/OTP-26.2.3.tar.gz",
    "source tag not doubled: " .. result.url
)
result = pre_install({}, "master", "linux", "amd64")
check(result.url == "https://github.com/erlang/otp/archive/refs/heads/master.tar.gz", "source master: " .. result.url)
result = pre_install({}, "maint-27", "linux", "amd64")
check(
    result.url == "https://github.com/erlang/otp/archive/refs/heads/maint-27.tar.gz",
    "source maint branch: " .. result.url
)

-- Windows installers. amd64 takes the 64-bit installer and asks for nothing.
probe_state.urls = {}
result = pre_install({}, "25.3.2.12", "windows", "amd64")
check(
    result.url == "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe",
    "windows amd64 installer: " .. result.url
)
check(#probe_state.urls == 0, "windows amd64 is not asked for an installer")
check(result.version == "25.3.2.12", "windows keeps the requested version")

-- Windows arm64 takes the 32-bit installer when the release publishes it, and asks for it first.
probe_state.urls = {}
probe_state.answer = true
result = pre_install({}, "25.3.2.12", "windows", "arm64")
local win32_url = "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win32_25.3.2.12.exe"
check(result.url == win32_url, "windows arm64 uses the 32-bit installer: " .. result.url)
check(#probe_state.urls == 1 and probe_state.urls[1] == win32_url, "windows arm64 asks for that installer once")

-- A release without a 32-bit installer is refused before the download, with a message that names the platform.
probe_state.urls = {}
probe_state.answer = false
local missing, missing_printed = pre_install_printed({}, "29.1.2", "windows", "arm64")
check(
    missing == nil and printed_has(missing_printed, "Erlang/OTP 29.1.2 has no build for Windows arm64"),
    "a release without a 32-bit installer is refused: " .. table.concat(missing_printed, " | ")
)
check(
    #probe_state.urls == 1 and string.find(probe_state.urls[1], "/otp_win32_29.1.2.exe", 1, true) ~= nil,
    "the refusal asks for the 32-bit installer of that release"
)

-- When the request fails, the install goes on and the download decides, as the version list check does.
probe_state.urls = {}
probe_state.answer = nil
probe_state.reason = "HTTP status 503"
result = pre_install({}, "29.1.2", "windows", "arm64")
check(
    result.url == "https://github.com/erlang/otp/releases/download/OTP-29.1.2/otp_win32_29.1.2.exe",
    "without an answer the 32-bit installer is still the download: " .. result.url
)
probe_state.answer = true

-- On Windows an OTP- name is the same release: the tag and the file name use the bare version.
result = pre_install({}, "OTP-29.1.2", "windows", "amd64")
check(
    result.url == "https://github.com/erlang/otp/releases/download/OTP-29.1.2/otp_win64_29.1.2.exe",
    "windows OTP- name is not prefixed twice: " .. result.url
)
check(result.version == "29.1.2", "windows OTP- name is installed as the bare version")

-- macOS prebuilt binaries from erlef/otp_builds.
result = pre_install({ USE_PREBUILT_OTP = "true" }, "26.2.3", "darwin", "arm64")
check(
    result.url == "https://github.com/erlef/otp_builds/releases/download/OTP-26.2.3/OTP-26.2.3-macos-arm64.tar.gz",
    "macOS arm64 prebuilt: " .. result.url
)
-- An architecture without a macOS prebuilt binary is refused, with a message that lists the supported ones.
local mac_arch, mac_arch_printed = pre_install_printed({ USE_PREBUILT_OTP = "true" }, "26.2.3", "darwin", "riscv64")
check(
    mac_arch == nil and printed_has(mac_arch_printed, "Unsupported architecture for prebuilt MacOS binaries: riscv64"),
    "an unsupported macOS architecture is refused: " .. table.concat(mac_arch_printed, " | ")
)

-- A missing version is refused with a message that says what to type.
local no_version, no_version_printed = pre_install_printed({}, nil, "linux", "amd64")
check(
    no_version == nil and printed_has(no_version_printed, "You must provide a version number"),
    "missing version is refused: " .. table.concat(no_version_printed, " | ")
)

-- A name that the list does not show is refused before the download, on every platform, and the refusal says
-- what to run. A partial name, such as 28, is one of them.
local partial, partial_printed = pre_install_printed({}, "28", "linux", "amd64")
check(
    partial == nil and printed_has(partial_printed, "28 is not in the version list"),
    "a partial name is refused: " .. table.concat(partial_printed, " | ")
)
check(printed_has(partial_printed, "vfox search erlang"), "the refusal points to vfox search")
local unknown_name, unknown_printed =
    pre_install_printed({ USE_PREBUILT_OTP = "ubuntu-22.04" }, "OTP-99.9", "linux", "amd64")
check(
    unknown_name == nil and printed_has(unknown_printed, "OTP-99.9 is not in the version list"),
    "an unknown OTP- name is refused: " .. table.concat(unknown_printed, " | ")
)
check(pre_install_printed({}, "28", "windows", "amd64") == nil, "the check applies on Windows")
check(pre_install_printed({ USE_PREBUILT_OTP = "true" }, "28", "darwin", "arm64") == nil, "the check applies on macOS")
-- With USE_PREBUILT_OTP set, the refusal names the prebuilt search command: the list that the install checks.
local prebuilt_refused, prebuilt_printed =
    pre_install_printed({ USE_PREBUILT_OTP = "ubuntu-24.04" }, "17.0", "linux", "amd64")
check(
    prebuilt_refused == nil
        and printed_has(prebuilt_printed, "Run `USE_PREBUILT_OTP=ubuntu-24.04 vfox search erlang` to see"),
    "the PreInstall refusal names the prebuilt search command: " .. table.concat(prebuilt_printed, " | ")
)

-- Only the macOS prebuilt branches end in latest, and only with USE_PREBUILT_OTP on macOS. Any other such name is
-- a release: foo-latest is refused before the download, as a name without latest is.
local latest, latest_printed = pre_install_printed({}, "foo-latest", "linux", "amd64")
check(
    latest == nil and printed_has(latest_printed, "foo-latest is not in the version list"),
    "an unlisted name that ends in latest is refused: " .. table.concat(latest_printed, " | ")
)
-- These names are refused where they are not macOS prebuilt branches: in a Linux source build, in a Linux prebuilt
-- install, and in a macOS source build. Before, they skipped the list and failed in the download.
for _, case in ipairs({
    { {}, "master-latest", "linux", "amd64" },
    { { USE_PREBUILT_OTP = "ubuntu-24.04" }, "maint-27-latest", "linux", "amd64" },
    { {}, "master-latest", "darwin", "arm64" },
}) do
    local refused, printed = pre_install_printed(case[1], case[2], case[3], case[4])
    check(
        refused == nil and printed_has(printed, case[2] .. " is not in the version list"),
        case[2] .. " is refused on " .. case[3] .. ": " .. table.concat(printed, " | ")
    )
end

-- The macOS prebuilt branches come from otp_builds. With USE_PREBUILT_OTP on macOS they are not looked up in the list.
local reads_before_mac = list_state.reads
result = pre_install({ USE_PREBUILT_OTP = "true" }, "master-latest", "darwin", "arm64")
local mac_url = "https://github.com/erlef/otp_builds/releases/download/master-latest/"
check(result.url == mac_url .. "otp-aarch64-apple-darwin.tar.gz", "macOS branch master-latest: " .. result.url)
check(list_state.reads == reads_before_mac, "a macOS branch is not looked up in the list")

-- Branches are not in the lists, so a branch never reaches the list.
local reads_before = list_state.reads
local branch = pre_install({}, "master", "linux", "amd64")
check(branch.url == "https://github.com/erlang/otp/archive/refs/heads/master.tar.gz", "a branch still downloads")
check(list_state.reads == reads_before, "a branch is not looked up in the list")

-- When the list cannot be read, the check is skipped and the download decides, as it did before the check.
list_state.failure = "Failed to download the Erlang/OTP version list: no network"
local offline = pre_install({}, "28", "linux", "amd64")
check(
    offline.url == "https://github.com/erlang/otp/archive/refs/tags/OTP-28.tar.gz",
    "without the list: " .. offline.url
)
list_state.failure = nil

-- An unsupported USE_PREBUILT_OTP is reported as the value, once, even when the version list cannot be read. The
-- value is checked before the list is read, so the failed read is not reported as a skipped check.
list_state.failure = "Failed to download the Erlang/OTP version list: no network"
local value_result, value_printed = pre_install_printed({ USE_PREBUILT_OTP = "ubuntu-99.04" }, "28", "linux", "amd64")
list_state.failure = nil
check(
    value_result == nil
        and printed_has(value_printed, "USE_PREBUILT_OTP must be one of")
        and not printed_has(value_printed, "Could not read the version list"),
    "an unsupported value is reported as the value: " .. table.concat(value_printed, " | ")
)

-- A branch is refused as well when USE_PREBUILT_OTP has a bad value on Linux: the value is checked before any name.
local branch_bad, branch_bad_printed = pre_install_printed({ USE_PREBUILT_OTP = "bogus" }, "master", "linux", "amd64")
check(
    branch_bad == nil and printed_has(branch_bad_printed, "USE_PREBUILT_OTP must be one of"),
    "a bad value is refused for a branch too: " .. table.concat(branch_bad_printed, " | ")
)

-- A source build runs configure in its install path, so PreInstall refuses a path that configure cannot take, before
-- the download. The path is <root>/cache/erlang/v-<version>/erlang-<version>. The root is VFOX_HOME, or the vfox
-- directory of HOME when VFOX_HOME is unset. legacy_dirs lists the directories that exist, for ~/.version-fox.
local legacy_dirs = {}
local original_directory_exists = erlang_utils.directory_exists
erlang_utils.directory_exists = function(path)
    return legacy_dirs[path] == true
end

local refused_path, refused_path_printed =
    pre_install_printed({ VFOX_HOME = "/opt/vfox home" }, "26.2.3", "linux", "amd64")
check(
    refused_path == nil
        and printed_has(
            refused_path_printed,
            "The Erlang/OTP install path /opt/vfox home/cache/erlang/v-26.2.3/erlang-26.2.3 contains a space"
        ),
    "a source build with a space in VFOX_HOME is refused: " .. table.concat(refused_path_printed, " | ")
)
check(not printed_has(refused_path_printed, "Download Erlang/OTP from"), "the refusal comes before the download")

local refused_branch, refused_branch_printed =
    pre_install_printed({ VFOX_HOME = "/opt/vfox home" }, "master", "linux", "amd64")
check(
    refused_branch == nil and printed_has(refused_branch_printed, "contains a space"),
    "a branch build is refused the same way: " .. table.concat(refused_branch_printed, " | ")
)

local refused_home, refused_home_printed =
    pre_install_printed({ VFOX_HOME = "", HOME = "/home/jane's home" }, "26.2.3", "darwin", "arm64")
check(
    refused_home == nil
        and printed_has(
            refused_home_printed,
            "/home/jane's home/.vfox/cache/erlang/v-26.2.3/erlang-26.2.3 contains an apostrophe"
        ),
    "without VFOX_HOME, the vfox directory of HOME is checked: " .. table.concat(refused_home_printed, " | ")
)

legacy_dirs["/home/jane doe/.version-fox"] = true
local legacy_refused, legacy_printed = pre_install_printed({ HOME = "/home/jane doe" }, "26.2.3", "linux", "amd64")
check(
    legacy_refused == nil
        and printed_has(
            legacy_printed,
            "/home/jane doe/.version-fox/cache/erlang/v-26.2.3/erlang-26.2.3 contains a space"
        ),
    "an existing ~/.version-fox is the root that is checked: " .. table.concat(legacy_printed, " | ")
)
legacy_dirs["/home/jane doe/.version-fox"] = nil

-- Paths that configure can take are not refused, and neither are the installs that do not run configure.
result = pre_install({ VFOX_HOME = "/opt/vfox" }, "26.2.3", "linux", "amd64")
check(
    result.url == "https://github.com/erlang/otp/archive/refs/tags/OTP-26.2.3.tar.gz",
    "a clean VFOX_HOME builds from source: " .. result.url
)
result = pre_install({ VFOX_HOME = "/opt/vfox home", USE_PREBUILT_OTP = "ubuntu-22.04" }, "26.2.3", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/OTP-26.2.3.tar.gz",
    "a Linux prebuilt install does not run configure, so a space is not refused: " .. result.url
)
result = pre_install({ VFOX_HOME = "/opt/vfox home", USE_PREBUILT_OTP = "true" }, "26.2.3", "darwin", "arm64")
check(
    result.url == "https://github.com/erlef/otp_builds/releases/download/OTP-26.2.3/OTP-26.2.3-macos-arm64.tar.gz",
    "a macOS prebuilt install is not refused either: " .. result.url
)
result = pre_install({ VFOX_HOME = "/opt/vfox home" }, "25.3.2.12", "windows", "amd64")
check(
    result.url == "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe",
    "Windows runs its installer, so the path is not checked: " .. result.url
)
erlang_utils.directory_exists = original_directory_exists

print("pre_install_test: " .. counter.checks .. " checks passed")
