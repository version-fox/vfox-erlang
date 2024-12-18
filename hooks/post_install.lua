local erlangUtils = require("erlang_utils")

--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code
--- Currently can be left unimplemented!
function PLUGIN:PostInstall(ctx)
    --- ctx.rootPath SDK installation directory
    local sdkInfo = ctx.sdkInfo['erlang']
    local path = sdkInfo.path

    local PRE_BUILT_OS_RELEASE = erlangUtils.get_config_from_env("USE_PREBUILT_OTP")

    if RUNTIME.osType == "windows" then
        local installer
        if RUNTIME.archType == "amd64" then
            installer = path .. "\\otp_win64_" .. sdkInfo.version .. ".exe"
        else
            installer = path .. "\\otp_win32_" .. sdkInfo.version .. ".exe"
        end

        -- local install_cmd = "powershell Start-Process -FilePath " .. installer .. " -ArgumentList \"/S\", \"/D=" .. path .. "\" -Verb RunAs -Wait -PassThru -NoNewWindow"
        local install_cmd = installer .. " -Wait -PassThru" .. " /S /D=" .. path .. "\\release"
        print("install cmd: " .. install_cmd)
        local status = os.execute(install_cmd)
        if status ~= 0 then
            error("Erlang/OTP install failed, please check the stdout for details.")
        end
    elseif PRE_BUILT_OS_RELEASE then
        print("Erlang/OTP install from prebuilt release: " .. PRE_BUILT_OS_RELEASE)
        local install_path = ctx.sdkInfo.erlang.path
        local install_cmd = "cd " .. install_path .. " && ./Install -cross -sasl"

        local status = os.execute(install_cmd)
        if status ~= 0 then
            error(
            "Erlang/OTP install failed, please check the stdout for details. Make sure you have the required utilties: https://www.erlang.org/doc/installation_guide/install#required-utilities")
        end
    else
        -- use ENV OTP_COMPILE_ARGS to control compile behavior
        local configure_args = os.getenv("OTP_CONFIGURE_ARGS") or ""
        print("Erlang/OTP compile configure args: %s", configure_args)

        -- use ENV OTP_BUILD_DOCS to control bytecode with docs chunks
        local docs_target = os.getenv("DOC_TARGETS") or "chunks"

        print(
        "If you enable some Erlang/OTP features, maybe you can reference this guide: https://github.com/erlang/otp/blob/master/HOWTO/INSTALL.md#configuring-1")
        os.execute("sleep " .. tonumber(3))
        local configure_cmd = "cd " .. path .. " && ./configure --prefix=" .. path .. "/release " .. configure_args

        local install_erlang_cmd = "cd " .. path .. "&& make && make install"
        -- install with docs chunk for IDE/REPL docs hits & type hits
        local install_erlang_docs_cmd = "cd " ..
        path .. " && make docs DOC_TARGETS=" .. docs_target .. " && make install-docs DOC_TARGETS=" .. docs_target

        local status = os.execute(configure_cmd .. " && " .. install_erlang_cmd .. " && " .. install_erlang_docs_cmd)
        if status ~= 0 then
            error(
            "Erlang/OTP install failed, please check the stdout for details. Make sure you have the required utilties: https://www.erlang.org/doc/installation_guide/install#required-utilities")
        end
    end
end
