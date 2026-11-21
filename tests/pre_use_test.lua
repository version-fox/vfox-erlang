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

-- The count lives in a table: vfox's Lua VM (gopher-lua) can show a stale value for a
-- local captured by a closure after a pcall, which made the printed count wrong.
local counter = { checks = 0 }
local function check(condition, message)
    assert(condition, message)
    counter.checks = counter.checks + 1
end

local installed = {
    ["26.2.3"] = { path = "/sdk/erlang/26.2.3", name = "erlang", version = "26.2.3" },
}
local result = plugin:PreUse({ version = "26.2.3", installedSdks = installed })
check(result.version == "26.2.3", "installed version is returned")

local ok, err = pcall(plugin.PreUse, plugin, { version = "24.1", installedSdks = installed })
check(not ok and string.find(err, "is not installed", 1, true) ~= nil, "missing version: " .. tostring(err))

ok, err = pcall(plugin.PreUse, plugin, { version = "24.1" })
check(not ok and string.find(err, "vfox install erlang@24.1", 1, true) ~= nil, "no installedSdks: " .. tostring(err))

print("pre_use_test: " .. counter.checks .. " checks passed")
