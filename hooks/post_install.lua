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

--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code
--- Currently can be left unimplemented!
function PLUGIN:PostInstall(ctx)
    --- ctx.rootPath SDK installation directory
    local sdkInfo = ctx.sdkInfo["erlang"]
    local path = sdkInfo.path

    local PRE_BUILT_OS_RELEASE = erlangUtils.get_config_from_env("USE_PREBUILT_OTP")

    if RUNTIME.osType == "windows" then
        local installer
        if RUNTIME.archType == "amd64" then
            installer = path .. "\\otp_win64_" .. sdkInfo.version .. ".exe"
        else
            installer = path .. "\\otp_win32_" .. sdkInfo.version .. ".exe"
        end

        -- The OTP installer is an NSIS program: /S installs silently, and /D= must be the last
        -- argument and is not quoted. The installer path is quoted because the user profile
        -- may contain spaces. os.execute waits for the installer to finish.
        local install_cmd = '"' .. installer .. '" /S /D=' .. path .. "\\release"
        print("install cmd: " .. install_cmd)
        local status = os.execute(install_cmd)
        if status ~= 0 then
            error("Erlang/OTP install failed, please check the stdout for details.")
        end
    elseif PRE_BUILT_OS_RELEASE then
        print("Erlang/OTP install from prebuilt release: " .. PRE_BUILT_OS_RELEASE)
        local install_path = erlangUtils.shell_quote(sdkInfo.path)

        if RUNTIME.osType == "darwin" then
            -- For MacOS prebuilts from @erlef/otp_builds, the tarball contains a ready-to-use installation
            -- We need to move the contents to a 'release' subdirectory to match expected structure
            local setup_cmd = "cd "
                .. install_path
                .. ' && mkdir -p release && for item in *; do if [ "$item" != "release" ]; then mv "$item" release/; fi; done 2>/dev/null || true'
            local status = os.execute(setup_cmd)
            if status ~= 0 then
                error("Erlang/OTP install failed during file organization, please check the stdout for details.")
            end
        else
            -- Linux installation using the Install script
            local install_cmd = "cd " .. install_path .. " && ./Install -cross -sasl"
            local status = os.execute(install_cmd)
            if status ~= 0 then
                error(
                    "Erlang/OTP install failed, please check the stdout for details. Make sure you have the required utilties: https://www.erlang.org/doc/installation_guide/install#required-utilities"
                )
            end
        end
    else
        -- use ENV OTP_CONFIGURE_ARGS to control configure behavior, e.g. "--enable-jit"
        local configure_args = os.getenv("OTP_CONFIGURE_ARGS") or ""
        print("Erlang/OTP compile configure args: " .. configure_args)

        -- use ENV DOC_TARGETS to choose the documentation chunks, default is chunks
        local docs_target = os.getenv("DOC_TARGETS") or "chunks"

        print(
            "If you enable some Erlang/OTP features, maybe you can reference this guide: https://github.com/erlang/otp/blob/master/HOWTO/INSTALL.md#configuring-1"
        )
        local source_dir = erlangUtils.shell_quote(path)
        local prefix = erlangUtils.shell_quote(path .. "/release")
        local configure_cmd = "cd " .. source_dir .. " && ./configure --prefix=" .. prefix .. " " .. configure_args

        local install_erlang_cmd = "cd " .. source_dir .. " && make && make install"
        -- install with docs chunk for IDE/REPL docs hits & type hits
        local install_erlang_docs_cmd = "cd "
            .. source_dir
            .. " && make docs DOC_TARGETS="
            .. docs_target
            .. " && make install-docs DOC_TARGETS="
            .. docs_target

        local status = os.execute(configure_cmd .. " && " .. install_erlang_cmd .. " && " .. install_erlang_docs_cmd)
        if status ~= 0 then
            error(
                "Erlang/OTP install failed, please check the stdout for details. Make sure you have the required utilties: https://www.erlang.org/doc/installation_guide/install#required-utilities"
            )
        end
    end
end
