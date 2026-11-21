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

result = pre_install({ USE_PREBUILT_OTP = "ubuntu-24.04" }, "maint-27", "linux", "amd64")
check(
    result.url == "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/maint-27.tar.gz",
    "prebuilt maint branch: " .. result.url
)

local ok, err = pcall(pre_install, { USE_PREBUILT_OTP = "ubuntu-99.04" }, "26.2.3", "linux", "amd64")
check(
    not ok and string.find(err, "USE_PREBUILT_OTP must be one of", 1, true) ~= nil,
    "unknown release: " .. tostring(err)
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

-- Windows installers.
result = pre_install({}, "25.3.2.12", "windows", "amd64")
check(
    result.url == "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe",
    "windows amd64 installer: " .. result.url
)
result = pre_install({}, "25.3.2.12", "windows", "arm64")
check(
    result.url == "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win32_25.3.2.12.exe",
    "windows non-amd64 uses the win32 installer: " .. result.url
)

-- macOS prebuilt binaries from erlef/otp_builds.
result = pre_install({ USE_PREBUILT_OTP = "true" }, "26.2.3", "darwin", "arm64")
check(
    result.url == "https://github.com/erlef/otp_builds/releases/download/OTP-26.2.3/OTP-26.2.3-macos-arm64.tar.gz",
    "macOS arm64 prebuilt: " .. result.url
)

-- A missing version fails with a message that says what to type.
ok, err = pcall(pre_install, {}, nil, "linux", "amd64")
check(
    not ok and string.find(err, "You must provide a version number", 1, true) ~= nil,
    "missing version: " .. tostring(err)
)

print("pre_install_test: " .. counter.checks .. " checks passed")
