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

-- Fake http module: the version list is downloaded through it, and the installers are asked for with HEAD requests.
-- It must be in place before the plugin (and erlang_utils, which requires http) is loaded.
local responses = {}
local heads = {}
package.loaded["http"] = {
    get = function(req)
        local response = responses[req.url]
        if response == nil then
            return nil, "no network in tests"
        end
        return response, nil
    end,
    head = function(req)
        local response = heads[req.url]
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

-- The official installer is the 64-bit one on amd64 and the 32-bit one on every other architecture.
check(
    erlang_utils.windows_installer_name("29.1.2", "amd64") == "otp_win64_29.1.2.exe",
    "amd64 has the 64-bit installer"
)
check(
    erlang_utils.windows_installer_name("29.1.2", "arm64") == "otp_win32_29.1.2.exe",
    "arm64 has the 32-bit installer"
)

-- url_exists asks with a HEAD request. 200 means the file is there, 404 that it is not. Any other status, and a
-- failed request, give no answer: the second result says why.
local installer_url = "https://github.com/erlang/otp/releases/download/OTP-29.1.2/otp_win32_29.1.2.exe"
heads[installer_url] = { status_code = 200 }
check(erlang_utils.url_exists(installer_url) == true, "a 200 means the file is there")
heads[installer_url] = { status_code = 404 }
check(erlang_utils.url_exists(installer_url) == false, "a 404 means the file is not there")
heads[installer_url] = { status_code = 503 }
local unknown, unknown_reason = erlang_utils.url_exists(installer_url)
check(
    unknown == nil and string.find(tostring(unknown_reason), "HTTP status 503", 1, true) ~= nil,
    "other statuses give no answer: " .. tostring(unknown_reason)
)
heads[installer_url] = nil
local failed, failed_reason = erlang_utils.url_exists(installer_url)
check(
    failed == nil and string.find(tostring(failed_reason), "no network in tests", 1, true) ~= nil,
    "a failed request gives no answer: " .. tostring(failed_reason)
)

-- The version list is parsed line by line and HTTP failures are reported.
local list_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/versions.txt"
responses[list_url] = { status_code = 200, body = "25.3.2.12\r\n26.2.3\n\n" }
local list, list_reason = erlang_utils.get_erlang_release_versions()
assert(list ~= nil, "the version list is read: " .. tostring(list_reason))
check(#list == 2, "blank lines are skipped")
check(list[1].version == "26.2.3" and list[2].version == "25.3.2.12", "versions are listed in descending order")

-- A failed read returns nil and the reason. Nothing is raised, so the caller can print the reason without a traceback.
responses[list_url] = { status_code = 503, body = "" }
local http_list, http_reason = erlang_utils.get_erlang_release_versions()
check(
    http_list == nil and string.find(tostring(http_reason), "HTTP status 503", 1, true) ~= nil,
    "HTTP errors are returned as the reason: " .. tostring(http_reason)
)

responses[list_url] = nil
local net_list, net_reason = erlang_utils.get_erlang_release_versions()
check(
    net_list == nil and string.find(tostring(net_reason), "version list", 1, true) ~= nil,
    "download errors name the version list: " .. tostring(net_reason)
)

-- USE_PREBUILT_OTP only changes the list on macOS and Linux. An empty value is unset, and an
-- unknown Linux release is an error instead of a list of other builds.
-- with_env returns what fn returns: its first value, and its second value when it has one.
local function with_env(env, fn)
    local original = os.getenv
    os.getenv = function(name)
        return env[name]
    end
    local ok, result, extra = pcall(fn)
    os.getenv = original
    if not ok then
        error(result, 0)
    end
    return result, extra
end

-- search_on returns the list, or nil and the reason, as get_erlang_release_versions does.
local function search_on(os_name, env, arch)
    local saved_os, saved_arch = RUNTIME.osType, RUNTIME.archType
    RUNTIME.osType, RUNTIME.archType = os_name, arch or "amd64"
    local ok, result, reason = pcall(with_env, env, erlang_utils.get_erlang_release_versions)
    RUNTIME.osType, RUNTIME.archType = saved_os, saved_arch
    if not ok then
        error(result, 0)
    end
    return result, reason
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
    #noble == 3 and noble[1].version == "29.1.2" and noble[2].version == "28.4.2" and noble[3].version == "master",
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
    table.concat(ordered_names, " ") == "29.1.2 29.1 25.3.2.10 25.3.2.9 29.0-rc3 master maint-28",
    "release order: " .. table.concat(ordered_names, " ")
)

-- OTP- is only a spelling: 29.1.2 and OTP-29.1.2 name the same release, and branches have none.
check(erlang_utils.other_release_spelling("29.1.2") == "OTP-29.1.2", "a bare name gets the prefix")
check(erlang_utils.other_release_spelling("OTP-29.1.2") == "29.1.2", "a prefixed name loses it")
check(erlang_utils.other_release_spelling("29.0-rc3") == "OTP-29.0-rc3", "release candidates too")
check(erlang_utils.other_release_spelling("master") == nil, "branches have no other spelling")
check(erlang_utils.bare_release_name("OTP-29.1.2") == "29.1.2", "the list shows release names bare")
check(erlang_utils.bare_release_name("maint-28") == "maint-28", "branch names are unchanged")

-- Branches are not looked up in a version list, and any other name must be listed. The lists hold release
-- names, so both spellings of a release match, and a partial name matches nothing.
check(erlang_utils.is_branch_name("master"), "master is a branch")
check(erlang_utils.is_branch_name("maint") and erlang_utils.is_branch_name("maint-27"), "maint names are branches")
check(
    not erlang_utils.is_branch_name("29.1.2") and not erlang_utils.is_branch_name("OTP-99.9"),
    "releases are not branches"
)
check(not erlang_utils.is_branch_name("28"), "a partial name is not a branch")
check(not erlang_utils.is_branch_name("master-latest"), "a latest name is not a source branch")
-- The macOS prebuilt branches end in latest. They are branches only with USE_PREBUILT_OTP on macOS, which
-- pre_install_test covers. Any other name that ends in latest is a release, such as foo-latest, and must be listed.
check(
    erlang_utils.is_macos_prebuilt_branch("master-latest")
        and erlang_utils.is_macos_prebuilt_branch("maint-latest")
        and erlang_utils.is_macos_prebuilt_branch("maint-28-latest"),
    "the macOS prebuilt branches end in latest"
)
check(
    not erlang_utils.is_macos_prebuilt_branch("foo-latest")
        and not erlang_utils.is_macos_prebuilt_branch("28-latest")
        and not erlang_utils.is_macos_prebuilt_branch("maint-foo-latest")
        and not erlang_utils.is_macos_prebuilt_branch("master"),
    "other names are not macOS prebuilt branches"
)
check(not erlang_utils.is_branch_name("maint-foo"), "a maint name that is not a number is not a branch")
check(not erlang_utils.is_branch_name("maint-28-foo"), "maint names with a suffix other than latest are not branches")
local known = { { version = "29.1.2" }, { version = "29.0-rc3" } }
check(erlang_utils.is_listed("29.1.2", known), "a listed name matches")
check(erlang_utils.is_listed("OTP-29.1.2", known), "the OTP- spelling of a listed name matches")
check(erlang_utils.is_listed("OTP-29.0-rc3", known), "a release candidate matches with the prefix")
check(not erlang_utils.is_listed("28", known), "a partial name is not listed")
check(not erlang_utils.is_listed("OTP-99.9", known), "an unknown release is not listed")
responses["https://builds.hex.pm/builds/otp/arm64/ubuntu-24.04/builds.txt"] =
    { status_code = 200, body = "OTP-26.2.3 aaa 2026-01-01T00:00:00Z\n" }
local arm = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" }, "arm64")
check(#arm == 1 and arm[1].version == "26.2.3", "arm64 reads the arm64 index")
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-20.04/builds.txt"] =
    { status_code = 200, body = "OTP-20.0 040bdce6 2020-10-29T08:19:13Z\n" }
local focal = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-20.04" })
check(#focal == 1 and focal[1].version == "20.0", "ubuntu-20.04 reads its own index")
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-26.04/builds.txt"] =
    { status_code = 200, body = "OTP-26.0 8c0ea6bd 2026-04-24T21:11:44Z\n" }
local resolute = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-26.04" })
check(#resolute == 1 and resolute[1].version == "26.0", "ubuntu-26.04 reads its own index")

local refused_list, search_err = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-99.04" })
check(
    refused_list == nil and string.find(tostring(search_err), "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "search refuses an unknown release: " .. tostring(search_err)
)
check(string.find(tostring(search_err), "ubuntu-26.04", 1, true) ~= nil, "the refusal lists ubuntu-26.04")

-- builds.txt publishes the SHA-256 of an archive in its fourth column. vfox compares it as lowercase hex, so the
-- value is lowercased here. A column that is not 64 hexadecimal digits is not a checksum.
local sha_release = "2cfca446976fc61962585a1c77e5d11ddb6f5fed83e84668a2c4acfaad60d22e"
local sha_master = "8056bde342fe5792125ffd25c3199789b42a2dd0447a3d6951f70f97a84bdda0"
local index_url = "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt"
responses[index_url] = {
    status_code = 200,
    body = "OTP-29.1.2 d199a49a01a2079afb6f2c5c9ae047cd4555e68d 2026-10-14T14:58:01Z "
        .. string.upper(sha_release)
        .. "\n"
        .. "OTP-28.4.2 0863bd30 2026-04-26T03:41:09Z\n"
        .. "master 3f73c77c 2026-11-22T17:08:17Z "
        .. sha_master
        .. "\n"
        .. "maint-27 abc 2026-04-26T03:41:09Z 1234\n"
        .. "OTP-27.3 def 2026-04-26T03:41:09Z "
        .. string.rep("g", 64)
        .. "\n",
}
local sums = search_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" })
local sum_of = {}
for _, entry in ipairs(sums) do
    sum_of[entry.version] = entry.sha256
end
check(sum_of["29.1.2"] == sha_release, "the published SHA-256 is kept, in lowercase: " .. tostring(sum_of["29.1.2"]))
check(sum_of["28.4.2"] == nil, "a line without a SHA-256 has none")
check(sum_of["master"] == sha_master, "a branch build keeps its published SHA-256")
check(sum_of["maint-27"] == nil, "a value that is not 64 digits is not a checksum")
check(sum_of["27.3"] == nil, "a value that is not hexadecimal is not a checksum")

-- A build is found under either spelling of its name. A name without a value has none, and so does a missing list.
local with_sums = { { version = "29.1.2", sha256 = sha_release }, { version = "maint-27" } }
check(erlang_utils.published_sha256(with_sums, "29.1.2") == sha_release, "a bare name finds its SHA-256")
check(erlang_utils.published_sha256(with_sums, "OTP-29.1.2") == sha_release, "the OTP- spelling finds it too")
check(erlang_utils.published_sha256(with_sums, "maint-27") == nil, "a build without a value has none")
check(erlang_utils.published_sha256(with_sums, "28") == nil, "a name the list does not show has none")
check(erlang_utils.published_sha256(nil, "29.1.2") == nil, "without a list there is no SHA-256")

-- PreInstall hands the SHA-256 to vfox from the index it reads for the list, so there is one request. A Linux branch
-- gets its value from the same index. A build without a value gets none, and vfox then warns.
local function prebuilt_install(version)
    return with_env({ USE_PREBUILT_OTP = "ubuntu-24.04" }, function()
        return plugin:PreInstall({ version = version })
    end)
end
local installed = prebuilt_install("29.1.2")
check(installed.sha256 == sha_release, "PreInstall returns the published SHA-256: " .. tostring(installed.sha256))
check(
    installed.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-29.1.2.tar.gz",
    "the archive is still the OTP- name: " .. installed.url
)
check(installed.version == "29.1.2", "the install is recorded under the bare version")
check(prebuilt_install("OTP-29.1.2").sha256 == sha_release, "the OTP- spelling gets the same SHA-256")
check(prebuilt_install("28.4.2").sha256 == nil, "a build without a published value has no SHA-256")
local branch = prebuilt_install("master")
check(
    branch.sha256 == sha_master and branch.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/master.tar.gz",
    "a Linux branch gets its SHA-256 from the index: " .. branch.url
)

-- When the index cannot be read, a listed name is still installed without a SHA-256, and the install is not refused.
responses[index_url] = nil
local unread = prebuilt_install("29.1.2")
check(
    unread.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-29.1.2.tar.gz" and unread.sha256 == nil,
    "without the index a listed name is installed without a SHA-256"
)
local unread_branch = prebuilt_install("master")
check(
    unread_branch.sha256 == nil and unread_branch.version == "master",
    "without the index a branch is installed without a SHA-256"
)

-- Available is the hook that vfox calls; it returns the same list.
responses[list_url] = { status_code = 200, body = "26.2.3\n" }
local available = plugin:Available({})
check(#available == 1 and available[1].version == "26.2.3", "Available returns the list")

-- When the list cannot be read, or USE_PREBUILT_OTP names no supported release, Available prints the reason once and
-- returns nil. vfox then reports the failure with no traceback, as it does for the PreInstall refusals.
local function printed_by(fn)
    local printed = {}
    local original_print = print
    print = function(...)
        table.insert(printed, table.concat({ ... }, "\t"))
    end
    local ok, result = pcall(fn)
    print = original_print
    if not ok then
        error(result, 0)
    end
    return result, printed
end

responses[list_url] = nil
local no_list, no_list_printed = printed_by(function()
    return plugin:Available({})
end)
check(
    no_list == nil
        and #no_list_printed == 1
        and string.find(no_list_printed[1], "Failed to download the Erlang/OTP version list", 1, true) ~= nil,
    "Available returns nil and prints the reason once: " .. table.concat(no_list_printed, " | ")
)
local bad_value, bad_value_printed = printed_by(function()
    return with_env({ USE_PREBUILT_OTP = "ubuntu-99.04" }, function()
        return plugin:Available({})
    end)
end)
check(
    bad_value == nil
        and #bad_value_printed == 1
        and string.find(bad_value_printed[1], "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "Available refuses a bad USE_PREBUILT_OTP the same way: " .. table.concat(bad_value_printed, " | ")
)

-- check_version_listed refuses an unlisted name and names the command that shows the list. A listed name
-- passes. When the list cannot be read, the check is skipped instead of blocking the install.
responses[list_url] = { status_code = 200, body = "26.2.3\n" }
local listed = erlang_utils.check_version_listed("26.2.3")
check(listed ~= nil and listed[1].version == "26.2.3", "a listed name returns the list it checked")
local unlisted, unlisted_refusal = erlang_utils.check_version_listed("28")
check(
    unlisted == nil and string.find(tostring(unlisted_refusal), "28 is not in the version list", 1, true) ~= nil,
    "an unlisted name is refused: " .. tostring(unlisted_refusal)
)
responses[list_url] = nil
local skipped, skipped_refusal = erlang_utils.check_version_listed("28")
check(skipped == nil and skipped_refusal == nil, "without the list the check is skipped, with no refusal")

-- prebuilt_config_refusal refuses an unsupported Linux release. An unset value, and any value on macOS, have no refusal.
check(with_env({}, erlang_utils.prebuilt_config_refusal) == nil, "an unset USE_PREBUILT_OTP is not checked")
local bad_release = with_env({ USE_PREBUILT_OTP = "ubuntu-99.04" }, erlang_utils.prebuilt_config_refusal)
check(
    bad_release ~= nil and string.find(bad_release, "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "an unsupported Linux release is refused: " .. tostring(bad_release)
)
RUNTIME.osType = "darwin"
check(
    with_env({ USE_PREBUILT_OTP = "ubuntu-99.04" }, erlang_utils.prebuilt_config_refusal) == nil,
    "macOS takes any USE_PREBUILT_OTP value"
)
RUNTIME.osType = "linux"
check(erlang_utils.prebuilt_release_refusal("ubuntu-22.04") == nil, "a supported release has no refusal")

-- The source install path is <root>/cache/erlang/v-<version>/erlang-<version>. The root is VFOX_HOME when it is set,
-- and otherwise the vfox directory of HOME: ~/.version-fox when that exists, and ~/.vfox when it does not. The
-- directories that exist are listed in dirs.
local dirs = {}
local original_directory_exists = erlang_utils.directory_exists
erlang_utils.directory_exists = function(path)
    return dirs[path] == true
end

local function source_path_on(env, version)
    return with_env(env, function()
        return erlang_utils.source_install_path(version)
    end)
end

check(
    source_path_on({ VFOX_HOME = "/opt/vfox home" }, "26.2.3") == "/opt/vfox home/cache/erlang/v-26.2.3/erlang-26.2.3",
    "VFOX_HOME is the root of the source install path"
)
check(
    source_path_on({ VFOX_HOME = "/opt/vfox/" }, "OTP-26.2.3")
        == "/opt/vfox/cache/erlang/v-OTP-26.2.3/erlang-OTP-26.2.3",
    "a trailing slash in VFOX_HOME is not repeated, and an OTP- name keeps its prefix"
)
check(
    source_path_on({ VFOX_HOME = "", HOME = "/home/jane" }, "26.2.3")
        == "/home/jane/.vfox/cache/erlang/v-26.2.3/erlang-26.2.3",
    "an empty VFOX_HOME is unset, so the vfox directory of HOME is the root"
)
dirs["/home/jane doe/.version-fox"] = true
check(
    source_path_on({ HOME = "/home/jane doe/" }, "26.2.3")
        == "/home/jane doe/.version-fox/cache/erlang/v-26.2.3/erlang-26.2.3",
    "an existing ~/.version-fox is the root when VFOX_HOME is unset"
)
dirs["/home/jane doe/.version-fox"] = nil
check(
    source_path_on({ HOME = "/home/jane doe/" }, "26.2.3") == "/home/jane doe/.vfox/cache/erlang/v-26.2.3/erlang-26.2.3",
    "~/.vfox is the root when ~/.version-fox does not exist"
)
check(source_path_on({}, "26.2.3") == nil, "without VFOX_HOME or HOME there is no source path")

-- configure_path_refusal names every character it finds, in the order of the list.
check(erlang_utils.configure_path_refusal("/opt/vfox/cache/erlang/v-26.2.3") == nil, "a clean path has no refusal")
local space_refusal = erlang_utils.configure_path_refusal("/opt/vfox home/erlang")
check(
    space_refusal ~= nil
        and string.find(
                space_refusal,
                "The Erlang/OTP install path /opt/vfox home/erlang contains a space",
                1,
                true
            )
            ~= nil,
    "a space is refused and named: " .. tostring(space_refusal)
)
local two_refusal = erlang_utils.configure_path_refusal("/home/jane's doe/erlang")
check(
    two_refusal ~= nil and string.find(two_refusal, "contains an apostrophe and a space", 1, true) ~= nil,
    "every character found is named: " .. tostring(two_refusal)
)

-- source_path_refusal checks the path that vfox gives the install, and has no refusal when the root is unknown.
local function source_refusal_on(env, version)
    return with_env(env, function()
        return erlang_utils.source_path_refusal(version)
    end)
end

local refused_path = source_refusal_on({ VFOX_HOME = "/opt/vfox home" }, "26.2.3")
local expected_path = "/opt/vfox home/cache/erlang/v-26.2.3/erlang-26.2.3"
check(
    refused_path ~= nil and string.find(refused_path, expected_path, 1, true) ~= nil,
    "the refusal names the path that vfox gives the install: " .. tostring(refused_path)
)
check(source_refusal_on({ VFOX_HOME = "/opt/vfox" }, "26.2.3") == nil, "a clean VFOX_HOME is not refused")
check(source_refusal_on({}, "26.2.3") == nil, "without a root there is no refusal here; PostInstall checks the path")
erlang_utils.directory_exists = original_directory_exists

-- A bad USE_PREBUILT_OTP is refused by check_version_listed, whether or not the list can be read. It is not
-- skipped as a list that could not be read.
local function bad_value_refusal()
    return with_env({ USE_PREBUILT_OTP = "ubuntu-99.04" }, function()
        local _, refusal = erlang_utils.check_version_listed("26.2.3")
        return refusal
    end)
end
responses[list_url] = nil
local unread_refusal = bad_value_refusal()
check(
    unread_refusal ~= nil and string.find(unread_refusal, "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "a bad value is refused when the list cannot be read: " .. tostring(unread_refusal)
)
responses[list_url] = { status_code = 200, body = "26.2.3\n" }
local read_refusal = bad_value_refusal()
check(
    read_refusal ~= nil and string.find(read_refusal, "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "a bad value is refused when the list can be read: " .. tostring(read_refusal)
)
responses[list_url] = nil

-- The refusal names the command that lists the names this install accepts. With USE_PREBUILT_OTP set on Linux or
-- macOS, that list is the prebuilt one, so the command carries the variable. Otherwise it is the plain command.
local function search_command_on(os_name, env)
    local saved_os = RUNTIME.osType
    RUNTIME.osType = os_name
    local ok, result = pcall(with_env, env, erlang_utils.search_command)
    RUNTIME.osType = saved_os
    if not ok then
        error(result, 0)
    end
    return result
end

check(search_command_on("linux", {}) == "vfox search erlang", "unset: the plain command")
check(
    search_command_on("linux", { USE_PREBUILT_OTP = "" }) == "vfox search erlang",
    "an empty value: the plain command"
)
check(
    search_command_on("linux", { USE_PREBUILT_OTP = "ubuntu-24.04" })
        == "USE_PREBUILT_OTP=ubuntu-24.04 vfox search erlang",
    "linux prebuilt: the command carries the variable"
)
check(
    search_command_on("darwin", { USE_PREBUILT_OTP = "true" }) == "USE_PREBUILT_OTP=true vfox search erlang",
    "macOS prebuilt: the command carries the variable"
)
check(
    search_command_on("darwin", { USE_PREBUILT_OTP = "my value" }) == "USE_PREBUILT_OTP='my value' vfox search erlang",
    "a value with a space is quoted for the shell"
)
check(
    search_command_on("windows", { USE_PREBUILT_OTP = "ubuntu-22.04" }) == "vfox search erlang",
    "windows: the plain command, as the list does not change"
)

-- A refused name gets that command in its message. 17.0 is not in the Ubuntu 24.04 prebuilt index.
responses["https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt"] =
    { status_code = 200, body = "OTP-29.1.2 9d37 2026-04-26T02:55:31Z\n" }
local hinted = with_env({ USE_PREBUILT_OTP = "ubuntu-24.04" }, function()
    local _, refusal = erlang_utils.check_version_listed("17.0")
    return refusal
end)
local prebuilt_hint = "Run `USE_PREBUILT_OTP=ubuntu-24.04 vfox search erlang` to see the names that can be installed"
check(
    hinted ~= nil and string.find(hinted, prebuilt_hint, 1, true) ~= nil,
    "the refusal names the prebuilt search command: " .. tostring(hinted)
)

responses[list_url] = { status_code = 200, body = "26.2.3\n" }
local plain = with_env({}, function()
    local _, refusal = erlang_utils.check_version_listed("28")
    return refusal
end)
responses[list_url] = nil
local plain_hint = "Run `vfox search erlang` to see the names that can be installed"
check(
    plain ~= nil and string.find(plain, plain_hint, 1, true) ~= nil,
    "the refusal without USE_PREBUILT_OTP names the plain command: " .. tostring(plain)
)

print("erlang_utils_test: " .. counter.checks .. " checks passed")
