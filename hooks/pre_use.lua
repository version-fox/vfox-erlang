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

--- When user invoke `use` command, this function will be called to get the
--- valid version information.
--- @param ctx table Context information
function PLUGIN:PreUse(ctx)
    --- user input version
    local input_version = ctx.version
    --- installed sdks, keyed by the name each one was installed with
    local installed = ctx.installedSdks or {}
    local sdkInfo = installed[input_version]
    if sdkInfo == nil then
        -- A release can be installed as 29.1.2 or as OTP-29.1.2, so the other spelling is tried too.
        sdkInfo = installed[erlangUtils.other_release_spelling(input_version)]
    end
    if sdkInfo == nil then
        error(
            "Erlang/OTP "
                .. tostring(input_version)
                .. " is not installed. Run: vfox install erlang@"
                .. tostring(input_version)
                .. " or link it with: vfox link --detect erlang"
        )
    end

    --- return the version information
    return {
        version = sdkInfo.version,
    }
end
