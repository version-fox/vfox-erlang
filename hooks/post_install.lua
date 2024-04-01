--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code
--- Currently can be left unimplemented!
function PLUGIN:PostInstall(ctx)
    --- ctx.rootPath SDK installation directory
    -- use ENV OTP_COMPILE_ARGS to control compile behavior
    local compile_args = os.getenv("OTP_COMPILE_ARGS") or ""
    print("Erlang/OTP compile with: %s", compile_args)

    -- use ENV OTP_BUILD_DOCS to control bytecode with docs chunks
    local with_docs_chunks = os.getenv("OTP_BUILD_DOCS") or ""

    print("If you enable some Erlang/OTP features, maybe you can reference this guide: https://github.com/asdf-vm/asdf-erlang?tab=readme-ov-file#before-asdf-install")
    os.execute("sleep " .. tonumber(3))

    local sdkInfo = ctx.sdkInfo['erlang']
    local path = sdkInfo.path

    local install_erlang_cmd = "cd " .. path .. " && ./configure --prefix=" .. path .. "/release " .. compile_args .. "&& make && make install"
    -- install for IDE docs hits & type hits
    local install_erlang_docs_cmd = "cd " .. path .. " && make docs DOC_TARGETS=chunks && make release_docs DOC_TARGETS=chunks"

    local status = os.execute(install_erlang_cmd .. " && " ..install_erlang_docs_cmd)

    -- local status = os.execute("cd " .. path .. " && ./configure --prefix=" .. path .. "/release " .. compile_args .. "&& make && make install")
    -- status = os.execute("cd " .. path .. " && make docs DOC_TARGETS=chunks && make release_docs DOC_TARGETS=chunks")
    if status ~= 0 then
        error("Erlang/OTP install failed, please check the stdout for details. Make sure you have the required utilties: https://www.erlang.org/doc/installation_guide/install#required-utilities")
    end
end