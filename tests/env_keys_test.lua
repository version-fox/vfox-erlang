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

local plugin = test.load({ os = "linux", arch = "amd64", env = {} })
local erlang_utils = require("erlang_utils")

local files = {}
erlang_utils.file_exists = function(path)
    return files[path] ~= nil
end

-- The count lives in a table: vfox's Lua VM (gopher-lua) can show a stale value for a
-- local captured by a closure after a pcall, which made the printed count wrong.
local counter = { checks = 0 }
local function check(condition, message)
    assert(condition, message)
    counter.checks = counter.checks + 1
end

local function path_for(root)
    return plugin:EnvKeys({ path = root })[1].value
end

check(plugin:EnvKeys({ path = "/sdk" })[1].key == "PATH", "EnvKeys sets PATH")

files["/sdk/erlang/release/bin/erl"] = ""
check(path_for("/sdk/erlang") == "/sdk/erlang/release/bin", "source install")

files = {}
files["/sdk/erlang/bin/erl"] = ""
check(path_for("/sdk/erlang") == "/sdk/erlang/bin", "prebuilt install")

files = {}
files["/usr/lib/erlang/bin/erl"] = ""
check(path_for("/usr/lib/erlang") == "/usr/lib/erlang/bin", "linked system install")

files = {}
check(path_for("/sdk/erlang") == "/sdk/erlang/release/bin", "nothing found falls back to release/bin")

RUNTIME.osType = "windows"
files = {}
files["C:\\Program Files\\Erlang OTP 26\\bin\\erl.exe"] = ""
check(
    path_for("C:\\Program Files\\Erlang OTP 26") == "C:\\Program Files\\Erlang OTP 26\\bin",
    "windows linked install is not assumed to use release\\bin"
)
RUNTIME.osType = "linux"

print("env_keys_test: " .. counter.checks .. " checks passed")
