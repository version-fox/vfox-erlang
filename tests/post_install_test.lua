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

-- The recorded commands live in a table field, not in a local that the closures assign: after an error
-- unwinds through pcall, gopher-lua can show a stale value for such a local.
local recorded = { commands = {} }
local original_execute = os.execute
local original_getenv = os.getenv
-- exit_status is what each command returns; 0 unless a test makes a command fail.
local function run_post_install(os_name, arch, env, ctx, exit_status)
    recorded.commands = {}
    os.execute = function(command)
        table.insert(recorded.commands, command)
        return exit_status or 0
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
check(#recorded.commands == 1, "one installer command")
check(
    recorded.commands[1]
        == '"C:\\Users\\Jane Doe\\.vfox\\erlang\\otp_win64_25.3.2.12.exe" /S /D=C:\\Users\\Jane Doe\\.vfox\\erlang\\release',
    "windows installer command: " .. recorded.commands[1]
)
check(string.find(recorded.commands[1], "-Wait", 1, true) == nil, "no PowerShell-only flags")

-- Linux source build: paths are quoted, OTP_CONFIGURE_ARGS is passed to configure, and the
-- docs chunks are built and installed.
run_post_install("linux", "amd64", { OTP_CONFIGURE_ARGS = "--enable-jit" }, {
    sdkInfo = { erlang = { path = "/home/jane/.vfox/erlang/v-26.2.3", version = "26.2.3" } },
})
check(#recorded.commands == 1, "one build command")
local build = recorded.commands[1]
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
    recorded.commands[1] == "cd '/home/jane/.vfox/erlang/v-26.2.3' && ./Install -cross -sasl",
    "prebuilt install command: " .. recorded.commands[1]
)

-- An empty USE_PREBUILT_OTP is unset: the source build runs.
run_post_install("linux", "amd64", { USE_PREBUILT_OTP = "" }, {
    sdkInfo = { erlang = { path = "/home/jane/.vfox/erlang/v-26.2.3", version = "26.2.3" } },
})
check(
    string.find(recorded.commands[1], "./configure", 1, true) ~= nil,
    "empty USE_PREBUILT_OTP builds: " .. recorded.commands[1]
)

-- A source build refuses an install path with a character that OTP's configure cannot take, before configure
-- runs, so nothing is executed. The error names the character.
for _, case in ipairs({
    { "/home/jane's/.vfox/cache/erlang/v-26.2.3", "an apostrophe" },
    { '/home/jane"x/.vfox/cache/erlang/v-26.2.3', "a double quote" },
    { "/home/$USER/.vfox/cache/erlang/v-26.2.3", "a dollar sign" },
    { "/home/jane`x`/.vfox/cache/erlang/v-26.2.3", "a backtick" },
    { "/home/jane doe/.vfox/cache/erlang/v-26.2.3", "a space" },
}) do
    local refused, reason = pcall(run_post_install, "linux", "amd64", {}, {
        sdkInfo = { erlang = { path = case[1], version = "26.2.3" } },
    })
    check(
        not refused and string.find(tostring(reason), case[2], 1, true) ~= nil and #recorded.commands == 0,
        "install path refused for " .. case[2] .. ": " .. tostring(reason)
    )
end

-- A prebuilt install runs its Install script in a path with a space, and that works. Only source builds refuse one.
run_post_install("linux", "amd64", { USE_PREBUILT_OTP = "ubuntu-22.04" }, {
    sdkInfo = { erlang = { path = "/home/jane doe/.vfox/cache/erlang/v-26.2.3", version = "26.2.3" } },
})
check(
    recorded.commands[1] == "cd '/home/jane doe/.vfox/cache/erlang/v-26.2.3' && ./Install -cross -sasl",
    "prebuilt install with a space: " .. tostring(recorded.commands[1])
)

-- A failed install names the required utilities, spelled as in OTP's documentation, for a prebuilt install and
-- for a source build.
local utilities_hint = "Make sure you have the required utilities: "
    .. "https://www.erlang.org/doc/installation_guide/install#required-utilities"
for _, env in ipairs({ { USE_PREBUILT_OTP = "ubuntu-22.04" }, {} }) do
    local failed, reason = pcall(run_post_install, "linux", "amd64", env, {
        sdkInfo = { erlang = { path = "/home/jane/.vfox/erlang/v-26.2.3", version = "26.2.3" } },
    }, 1)
    check(
        not failed and string.find(tostring(reason), utilities_hint, 1, true) ~= nil,
        "a failed install names the utilities: " .. tostring(reason)
    )
end

print("post_install_test: " .. counter.checks .. " checks passed")
