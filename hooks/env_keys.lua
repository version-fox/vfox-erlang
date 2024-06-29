local erlangUtils = require("erlang_utils")

--- Each SDK may have different environment variable configurations.
--- This allows plugins to define custom environment variables (including PATH settings)
--- Note: Be sure to distinguish between environment variable settings for different platforms!
--- @param ctx table Context information
--- @field ctx.path string SDK installation directory
function PLUGIN:EnvKeys(ctx)
    --- this variable is same as ctx.sdkInfo['plugin-name'].path
    local mainPath
    if RUNTIME.osType == "windows" then
        mainPath = ctx.path .. "\\release\\bin"
    else
        if not erlangUtils.directory_exists(ctx.path .. "/bin") then
            -- install erlang by compilation
            mainPath = ctx.path .. "/release/bin"
        end
        -- install erlang from Bob prebuilt release
        mainPath = ctx.path .. "/bin"
    end

    return {
        {
            key = "PATH",
            value = mainPath
        },
    }
end