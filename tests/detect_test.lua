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

-- test.load may run only once per file, so the platform and environment are swapped in around
-- each call. The file system is faked: files maps a path to its content and dirs maps a
-- directory to its children. detect_erlang reads everything through these fields, so
-- nothing real is scanned.
local plugin = test.load({ os = "linux", arch = "amd64", env = {} })
local detect = require("detect_erlang")

-- The real list_children and is_runnable, kept before the fakes below replace them, so that the
-- Windows and Unix command paths and the execute bit can be checked directly.
local real_list_children = detect.list_children
local real_is_runnable = detect.is_runnable

local files = {}
local dirs = {}
-- runnable holds the erl paths that have the execute bit. The fake is_runnable reads it.
local runnable = {}
detect.file_exists = function(path)
    return files[path] ~= nil
end
detect.read_file = function(path)
    return files[path]
end
detect.list_children = function(dir)
    return dirs[dir] or {}
end
detect.is_runnable = function(path)
    return runnable[path] == true
end

-- Writes a minimal OTP install under root: an executable bin/<exe>, plus releases/<rel>/OTP_VERSION.
local function install(root, exe, version, rel, sep)
    local function join(...)
        return table.concat({ ... }, sep)
    end
    files[join(root, "bin", exe)] = ""
    runnable[join(root, "bin", exe)] = true
    files[join(root, "releases", rel, "OTP_VERSION")] = version .. "\n"
    dirs[join(root, "releases")] = { join(root, "releases", rel), join(root, "releases", "start_erl.data") }
end

local function reset()
    files = {}
    dirs = {}
    runnable = {}
end

local function describe(result)
    local lines = {}
    for _, item in ipairs(result) do
        lines[#lines + 1] = item.version .. " @ " .. item.path .. " (" .. item.note .. ")"
    end
    return table.concat(lines, "; ")
end

local function detect_with(os_name, env)
    local original_getenv = os.getenv
    os.getenv = function(name)
        return env[name]
    end
    local saved_os = RUNTIME.osType
    RUNTIME.osType = os_name
    local ok, result = pcall(plugin.Detect, plugin, {})
    RUNTIME.osType = saved_os
    os.getenv = original_getenv
    if not ok then
        error(result, 0)
    end
    return result
end

-- The count lives in a table: vfox's Lua VM (gopher-lua) can show a stale value for a
-- local captured by a closure after a pcall, which made the printed count wrong.
local counter = { checks = 0 }
local function check(condition, message)
    assert(condition, message)
    counter.checks = counter.checks + 1
end

local unix_env = { HOME = "/home/test" }

-- Debian and Ubuntu package layout: the root is /usr/lib/erlang itself.
reset()
install("/usr/lib/erlang", "erl", "24.2.1", "24", "/")
local result = detect_with("linux", unix_env)
check(#result == 1, "system package found: " .. describe(result))
check(result[1].version == "24.2.1", "system version comes from OTP_VERSION")
check(result[1].path == "/usr/lib/erlang", "system path is the root")
check(result[1].note == "installed by a system package", "system note")

-- Homebrew Cellar: the root is lib/erlang under the version directory.
reset()
dirs["/opt/homebrew/Cellar/erlang"] = { "/opt/homebrew/Cellar/erlang/26.2.3" }
install("/opt/homebrew/Cellar/erlang/26.2.3/lib/erlang", "erl", "26.2.3", "26", "/")
result = detect_with("linux", unix_env)
check(#result == 1, "homebrew found: " .. describe(result))
check(result[1].path == "/opt/homebrew/Cellar/erlang/26.2.3/lib/erlang", "homebrew root is lib/erlang")
check(result[1].note == "installed by Homebrew", "homebrew note")

-- asdf: each child of the installs directory is a root.
reset()
dirs["/home/test/.asdf/installs/erlang"] = { "/home/test/.asdf/installs/erlang/25.3.2.12" }
install("/home/test/.asdf/installs/erlang/25.3.2.12", "erl", "25.3.2.12", "25", "/")
result = detect_with("linux", unix_env)
check(#result == 1 and result[1].version == "25.3.2.12", "asdf version kept as written: " .. describe(result))
check(result[1].note == "installed by asdf", "asdf note")

-- vfox's own installs are never offered, and directories without a valid layout are skipped.
reset()
dirs["/opt/erlang"] = { "/opt/erlang/27.0", "/opt/erlang/.vfox/erlang/25.0", "/opt/erlang/broken" }
install("/opt/erlang/27.0", "erl", "27.0", "27", "/")
install("/opt/erlang/.vfox/erlang/25.0", "erl", "25.0", "25", "/")
files["/opt/erlang/broken/bin/erl"] = ""
result = detect_with("linux", unix_env)
check(#result == 1, "only the valid, unmanaged install: " .. describe(result))
check(result[1].path == "/opt/erlang/27.0", "vfox-managed and broken entries are skipped")

-- One entry per version: the first path in sorted order wins.
reset()
dirs["/opt/homebrew/Cellar/erlang"] = { "/opt/homebrew/Cellar/erlang/24.2.1" }
install("/opt/homebrew/Cellar/erlang/24.2.1/lib/erlang", "erl", "24.2.1", "24", "/")
install("/usr/lib/erlang", "erl", "24.2.1", "24", "/")
result = detect_with("linux", unix_env)
check(#result == 1, "duplicate versions are reported once: " .. describe(result))
check(result[1].path == "/opt/homebrew/Cellar/erlang/24.2.1/lib/erlang", "first sorted path is kept")

-- An erl without the execute bit is not offered, because vfox cannot link an installation whose erl cannot
-- run. The layout is the one of a mise install: bin/erl, and releases/29/OTP_VERSION.
reset()
local mise_root = "/home/test/.local/share/mise/installs/erlang/29.1.2"
dirs["/home/test/.local/share/mise/installs/erlang"] = { mise_root }
install(mise_root, "erl", "29.1.2", "29", "/")
runnable[mise_root .. "/bin/erl"] = nil
result = detect_with("linux", unix_env)
check(#result == 0, "a non-executable erl is not offered: " .. describe(result))
runnable[mise_root .. "/bin/erl"] = true
result = detect_with("linux", unix_env)
check(
    #result == 1 and result[1].note == "installed by mise",
    "the same install is offered once erl can run: " .. describe(result)
)

-- The real is_runnable asks the shell with test -x. Plugin tests cannot run commands, so os.execute is
-- replaced by a stub here: the command must be test -x on the quoted path, and its status decides.
-- The real file check is in the end-to-end tests, which run vfox against a real erl.
local original_execute = os.execute
local asked = nil
os.execute = function(command)
    asked = command
    return 0
end
check(real_is_runnable("/opt/erlang/bin/erl") == true, "a zero status from test -x means the file can run")
check(asked == "test -x '/opt/erlang/bin/erl'", "the check runs test -x on the quoted path: " .. tostring(asked))
os.execute = function()
    return 1
end
check(real_is_runnable("/opt/erlang/bin/erl") == false, "a non-zero status from test -x means it cannot run")
os.execute = original_execute

-- Windows: Program Files children whose names start with "Erlang OTP" or "erl".
reset()
dirs["C:\\Program Files"] = {
    "C:\\Program Files\\Erlang OTP 26",
    "C:\\Program Files\\Git",
    "C:\\Program Files\\erl25.3.2.12",
}
install("C:\\Program Files\\Erlang OTP 26", "erl.exe", "26.2.3", "26", "\\")
install("C:\\Program Files\\erl25.3.2.12", "erl.exe", "25.3.2.12", "25", "\\")
result = detect_with("windows", { ProgramFiles = "C:\\Program Files", USERPROFILE = "C:\\Users\\test" })
check(#result == 2, "windows installs found: " .. describe(result))
check(result[1].version == "25.3.2.12" and result[2].version == "26.2.3", "windows results are sorted")
check(result[2].path == "C:\\Program Files\\Erlang OTP 26", "windows root is the installer directory")
check(result[2].note == "installed in Program Files", "windows note")

-- vfox 1.1.0 replaces io.popen on Windows with a handle that has read, write and close, but no
-- lines method. list_children has to work with that handle, so these checks use a fake handle
-- with only those methods, which returns the output one line at a time as vfox does.
local function fake_popen(output, seen)
    local index = 0
    return function(command, mode)
        seen.command = command
        seen.mode = mode
        return {
            read = function(self, format)
                index = index + 1
                return output[index]
            end,
            close = function(self)
                return true
            end,
        }
    end
end

local saved_popen = io.popen
local saved_os_type = RUNTIME.osType

local seen = {}
io.popen = fake_popen({ "26.2.3", "", "25.3.2.12\r" }, seen)
RUNTIME.osType = "linux"
local listed = real_list_children("/opt/erlang")
check(seen.command == "ls -1 '/opt/erlang' 2>/dev/null", "unix lists with ls: " .. tostring(seen.command))
check(
    #listed == 2 and listed[1] == "/opt/erlang/26.2.3" and listed[2] == "/opt/erlang/25.3.2.12",
    "unix output gives one path per non-blank line, with the carriage return removed"
)

seen = {}
io.popen = fake_popen({ "Erlang OTP 26\r", "", "Git\r" }, seen)
RUNTIME.osType = "windows"
listed = real_list_children("C:\\Program Files")
check(seen.command == 'dir /b /ad "C:\\Program Files" 2>nul', "windows lists with dir: " .. tostring(seen.command))
check(
    #listed == 2 and listed[1] == "C:\\Program Files\\Erlang OTP 26" and listed[2] == "C:\\Program Files\\Git",
    "windows output gives backslash paths, one per non-blank line"
)

io.popen = fake_popen({}, {})
check(#real_list_children("C:\\Missing") == 0, "an empty listing gives no children")

io.popen = function()
    return nil
end
check(#real_list_children("/missing") == 0, "a failed popen gives no children")

io.popen = saved_popen
RUNTIME.osType = saved_os_type

print("detect_test: " .. counter.checks .. " checks passed")
