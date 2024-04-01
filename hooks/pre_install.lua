local erlangUtils = require("erlang_utils")

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    
    erlangUtils.check_platform()

    local erlang_version = ctx.version
    if erlang_version == nil then
        print("You will install the Erlang/OTP version is" .. erlang_version)
        error("You must provide a version number for Erlang/OTP, eg: vfox install erlang@24.1")
    end
    erlangUtils.check_version_existence("https://github.com/erlang/otp/releases/tag/OTP-" .. erlang_version)
    
    local download_url = "https://github.com/erlang/otp/archive/refs/tags/OTP-" .. erlang_version .. ".tar.gz"
    return {
        version = erlang_version,
        url = download_url
    }
end