local erlangUtils = require("erlang_utils")

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local erlang_version = ctx.version
    print("You will install the Erlang/OTP version is: " .. erlang_version)
    if erlang_version == nil then
        error("You must provide a version number for Erlang/OTP, eg: vfox install erlang@24.1")
    end
    -- erlangUtils.check_version_existence("https://github.com/erlang/otp/releases/tag/OTP-" .. erlang_version)

    local download_url
    local PRE_BUILT_OS_RELEASE = erlangUtils.get_config_from_env("USE_PREBUILT_OTP")
    if RUNTIME.osType == "windows" then
        if RUNTIME.archType == "amd64" then
            download_url = "https://github.com/erlang/otp/releases/download/OTP-" ..
                erlang_version .. "/otp_win64_" .. erlang_version .. ".exe"
        else
            download_url = "https://github.com/erlang/otp/releases/download/OTP-" ..
                erlang_version .. "/otp_win32_" .. erlang_version .. ".exe"
        end
    elseif RUNTIME.osType == "linux" and PRE_BUILT_OS_RELEASE then
        local SUPPORT_OS_RELEASE = { "ubuntu-14.04", "ubuntu-16.04", "ubuntu-18.04", "ubuntu-20.04", "ubuntu-22.04", "ubuntu-24.04" }
        if not erlangUtils.array_contains(SUPPORT_OS_RELEASE, PRE_BUILT_OS_RELEASE) then
            error(
                "Make sure the USE_PREBUILT environment variable is set to one of the following values: ubuntu-20.04, ubuntu-22.04, ubuntu-24.04")
        end
        download_url = "https://builds.hex.pm/builds/otp/" .. RUNTIME.archType .. "/" .. PRE_BUILT_OS_RELEASE .. "/" .. erlang_version .. ".tar.gz"
    else
        download_url = "https://github.com/erlang/otp/archive/refs/tags/OTP-" .. erlang_version .. ".tar.gz"
    end

    print("Download Erlang/OTP from " .. download_url)

    return {
        version = erlang_version,
        url = download_url
    }
end
