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

local erlangUtils = require("erlang_utils")

--- Return all available versions provided by this plugin.
--- When the list cannot be read, or USE_PREBUILT_OTP names no supported release, the reason is printed and nil is
--- returned, as PreInstall does for its refusals: vfox then reports the failure without a Lua stack traceback.
--- @param ctx table Empty table used as context, for future extension
--- @return table|nil Descriptions of available versions and accompanying tool descriptions, or nil
function PLUGIN:Available(ctx)
    local versions, reason = erlangUtils.get_erlang_release_versions()
    if versions == nil then
        print(reason)
        return nil
    end
    return versions
end
