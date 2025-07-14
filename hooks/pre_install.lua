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
        -- For Windows, always use OTP- prefix for regular versions
        local win_tag = erlang_version
        if not (string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-")) then
            win_tag = "OTP-" .. erlang_version
        end
        
        if RUNTIME.archType == "amd64" then
            download_url = "https://github.com/erlang/otp/releases/download/" ..
                win_tag .. "/otp_win64_" .. erlang_version .. ".exe"
        else
            download_url = "https://github.com/erlang/otp/releases/download/" ..
                win_tag .. "/otp_win32_" .. erlang_version .. ".exe"
        end
    elseif RUNTIME.osType == "linux" and PRE_BUILT_OS_RELEASE then
        local SUPPORT_OS_RELEASE = { "ubuntu-14.04", "ubuntu-16.04", "ubuntu-18.04", "ubuntu-20.04", "ubuntu-22.04",
            "ubuntu-24.04" }
        if not erlangUtils.array_contains(SUPPORT_OS_RELEASE, PRE_BUILT_OS_RELEASE) then
            error(
                "Make sure the USE_PREBUILT environment variable is set to one of the following values: ubuntu-20.04, ubuntu-22.04, ubuntu-24.04")
        end
        download_url = "https://builds.hex.pm/builds/otp/" ..
            RUNTIME.archType .. "/" .. PRE_BUILT_OS_RELEASE .. "/" .. erlang_version .. ".tar.gz"
    elseif RUNTIME.osType == "darwin" and erlangUtils.get_config_from_env("USE_PREBUILT_OTP") then
        -- Use @erlef/otp_builds for MacOS prebuilt binaries
        local arch_mapping = {
            amd64 = "amd64",
            x86_64 = "x86_64",
            arm64 = "arm64",
            aarch64 = "aarch64"
        }

        local mapped_arch = arch_mapping[RUNTIME.archType]
        if not mapped_arch then
            error("Unsupported architecture for prebuilt MacOS binaries: " ..
                RUNTIME.archType .. ". Supported architectures: amd64, x86_64, arm64, aarch64")
        end

        -- Prepare tag name and file prefix for download URL
        -- Special versions like master-latest, maint-latest etc. don't need OTP- prefix
        -- Regular versions like 28.0.1 need OTP- prefix for GitHub tag but not for filename
        local tag_name = erlang_version
        local file_prefix = erlang_version
        
        if not (string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-")) then
            -- Regular version like "28.0.1" -> tag should be "OTP-28.0.1"
            tag_name = "OTP-" .. erlang_version
            file_prefix = "OTP-" .. erlang_version
        end

        -- Use different URL patterns based on architecture
        if mapped_arch == "aarch64" then
            -- https://github.com/erlef/otp_builds/releases/download/maint-25-latest/otp-aarch64-apple-darwin.tar.gz
            download_url = "https://github.com/erlef/otp_builds/releases/download/" ..
                tag_name .. "/otp-aarch64-apple-darwin.tar.gz"
        elseif mapped_arch == "arm64" then
            if string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-") then
                -- For latest versions: use aarch64 naming for arm64
                download_url = "https://github.com/erlef/otp_builds/releases/download/" ..
                    tag_name .. "/otp-aarch64-apple-darwin.tar.gz"
            else
                -- For regular versions: https://github.com/erlef/otp_builds/releases/download/OTP-28.0.1/OTP-28.0.1-macos-arm64.tar.gz
                download_url = "https://github.com/erlef/otp_builds/releases/download/" ..
                    tag_name .. "/" .. file_prefix .. "-macos-arm64.tar.gz"
            end
        elseif mapped_arch == "amd64" then
            if string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-") then
                -- For latest versions: use x86_64 naming for amd64
                download_url = "https://github.com/erlef/otp_builds/releases/download/" ..
                    tag_name .. "/otp-x86_64-apple-darwin.tar.gz"
            else
                -- For regular versions: https://github.com/erlef/otp_builds/releases/download/OTP-28.0.1/OTP-28.0.1-macos-amd64.tar.gz
                download_url = "https://github.com/erlef/otp_builds/releases/download/" ..
                    tag_name .. "/" .. file_prefix .. "-macos-amd64.tar.gz"
            end
        elseif mapped_arch == "x86_64" then
            -- For x86_64, always use the same naming pattern as aarch64
            download_url = "https://github.com/erlef/otp_builds/releases/download/" ..
                tag_name .. "/otp-x86_64-apple-darwin.tar.gz"
        end
    else
        -- For source code download, always use OTP- prefix for regular versions
        local source_tag = erlang_version
        if not (string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-")) then
            source_tag = "OTP-" .. erlang_version
        end
        download_url = "https://github.com/erlang/otp/archive/refs/tags/" .. source_tag .. ".tar.gz"
    end

    print("Download Erlang/OTP from " .. download_url)

    return {
        version = erlang_version,
        url = download_url
    }
end
