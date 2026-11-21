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

-- test.load may run only once per file: the platform and environment are swapped in around
-- each call. os.execute is replaced too, so every command the hook runs is recorded instead
-- of executed.
local plugin = test.load({ os = "linux", arch = "amd64", env = {} })

local commands = {}
local original_execute = os.execute
local original_getenv = os.getenv
local function run_post_install(os_name, arch, env, ctx)
    commands = {}
    os.execute = function(command)
        table.insert(commands, command)
        return 0
    end
    os.getenv = function(name)
        return env[name]
    end
    local saved_os, saved_arch = RUNTIME.osType, RUNTIME.archType
    RUNTIME.osType, RUNTIME.archType = os_name, arch
    local ok, err = pcall(plugin.PostInstall, plugin, ctx)
    RUNTIME.osType, RUNTIME.archType = saved_os, saved_arch
    os.execute = original_execute
    os.getenv = original_getenv
    if not ok then
        error(err, 0)
    end
end

-- The count lives in a table: vfox's Lua VM (gopher-lua) can show a stale value for a
-- local captured by a closure after a pcall, which made the printed count wrong.
local counter = { checks = 0 }
local function check(condition, message)
    assert(condition, message)
    counter.checks = counter.checks + 1
end

-- Windows: the installer path is quoted, /D= comes last, and no PowerShell-only flags are passed.
run_post_install("windows", "amd64", {}, {
    sdkInfo = { erlang = { path = "C:\\Users\\Jane Doe\\.vfox\\erlang", version = "25.3.2.12" } },
})
check(#commands == 1, "one installer command")
check(
    commands[1]
        == '"C:\\Users\\Jane Doe\\.vfox\\erlang\\otp_win64_25.3.2.12.exe" /S /D=C:\\Users\\Jane Doe\\.vfox\\erlang\\release',
    "windows installer command: " .. commands[1]
)
check(string.find(commands[1], "-Wait", 1, true) == nil, "no PowerShell-only flags")

-- Linux source build: paths are quoted, OTP_CONFIGURE_ARGS is passed to configure, and the
-- docs chunks are built and installed.
run_post_install("linux", "amd64", { OTP_CONFIGURE_ARGS = "--enable-jit" }, {
    sdkInfo = { erlang = { path = "/home/jane/.vfox/erlang/v-26.2.3", version = "26.2.3" } },
})
check(#commands == 1, "one build command")
local build = commands[1]
check(
    string.find(
        build,
        "cd '/home/jane/.vfox/erlang/v-26.2.3' && ./configure --prefix='/home/jane/.vfox/erlang/v-26.2.3/release' --enable-jit",
        1,
        true
    ) ~= nil,
    "configure command: " .. build
)
check(string.find(build, "make && make install", 1, true) ~= nil, "make command: " .. build)
check(string.find(build, "make docs DOC_TARGETS=chunks", 1, true) ~= nil, "docs chunks: " .. build)
check(string.find(build, "sleep", 1, true) == nil, "no sleep before the build")

-- Linux prebuilt: the tarball's Install script runs in the quoted install path.
run_post_install("linux", "amd64", { USE_PREBUILT_OTP = "ubuntu-22.04" }, {
    sdkInfo = { erlang = { path = "/home/jane/.vfox/erlang/v-26.2.3", version = "26.2.3" } },
})
check(
    commands[1] == "cd '/home/jane/.vfox/erlang/v-26.2.3' && ./Install -cross -sasl",
    "prebuilt install command: " .. commands[1]
)

print("post_install_test: " .. counter.checks .. " checks passed")
