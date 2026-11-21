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

local SUPPORT_OS_RELEASE = {
    "ubuntu-14.04",
    "ubuntu-16.04",
    "ubuntu-18.04",
    "ubuntu-20.04",
    "ubuntu-22.04",
    "ubuntu-24.04",
}

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- ctx.version is the version the user typed.
--- @param ctx table
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local erlang_version = ctx.version
    if erlang_version == nil or erlang_version == "" then
        error("You must provide a version number for Erlang/OTP, eg: vfox install erlang@26.2.3")
    end
    print("You will install the Erlang/OTP version is: " .. erlang_version)
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
            download_url = "https://github.com/erlang/otp/releases/download/"
                .. win_tag
                .. "/otp_win64_"
                .. erlang_version
                .. ".exe"
        else
            download_url = "https://github.com/erlang/otp/releases/download/"
                .. win_tag
                .. "/otp_win32_"
                .. erlang_version
                .. ".exe"
        end
    elseif RUNTIME.osType == "linux" and PRE_BUILT_OS_RELEASE then
        if not erlangUtils.array_contains(SUPPORT_OS_RELEASE, PRE_BUILT_OS_RELEASE) then
            error(
                "USE_PREBUILT_OTP must be one of: "
                    .. table.concat(SUPPORT_OS_RELEASE, ", ")
                    .. ". Got: "
                    .. PRE_BUILT_OS_RELEASE
            )
        end
        -- builds.hex.pm names numeric releases with the OTP- prefix, e.g. OTP-26.2.3.tar.gz
        download_url = "https://builds.hex.pm/builds/otp/"
            .. RUNTIME.archType
            .. "/"
            .. PRE_BUILT_OS_RELEASE
            .. "/"
            .. erlangUtils.bob_build_name(erlang_version)
            .. ".tar.gz"
    elseif RUNTIME.osType == "darwin" and PRE_BUILT_OS_RELEASE then
        -- Use @erlef/otp_builds for MacOS prebuilt binaries
        local arch_mapping = {
            amd64 = "amd64",
            x86_64 = "x86_64",
            arm64 = "arm64",
            aarch64 = "aarch64",
        }

        local mapped_arch = arch_mapping[RUNTIME.archType]
        if not mapped_arch then
            error(
                "Unsupported architecture for prebuilt MacOS binaries: "
                    .. RUNTIME.archType
                    .. ". Supported architectures: amd64, x86_64, arm64, aarch64"
            )
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
            download_url = "https://github.com/erlef/otp_builds/releases/download/"
                .. tag_name
                .. "/otp-aarch64-apple-darwin.tar.gz"
        elseif mapped_arch == "arm64" then
            if string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-") then
                -- For latest versions: use aarch64 naming for arm64
                download_url = "https://github.com/erlef/otp_builds/releases/download/"
                    .. tag_name
                    .. "/otp-aarch64-apple-darwin.tar.gz"
            else
                -- For regular versions: https://github.com/erlef/otp_builds/releases/download/OTP-28.0.1/OTP-28.0.1-macos-arm64.tar.gz
                download_url = "https://github.com/erlef/otp_builds/releases/download/"
                    .. tag_name
                    .. "/"
                    .. file_prefix
                    .. "-macos-arm64.tar.gz"
            end
        elseif mapped_arch == "amd64" then
            if string.match(erlang_version, "latest$") or string.match(erlang_version, "^maint%-") then
                -- For latest versions: use x86_64 naming for amd64
                download_url = "https://github.com/erlef/otp_builds/releases/download/"
                    .. tag_name
                    .. "/otp-x86_64-apple-darwin.tar.gz"
            else
                -- For regular versions: https://github.com/erlef/otp_builds/releases/download/OTP-28.0.1/OTP-28.0.1-macos-amd64.tar.gz
                download_url = "https://github.com/erlef/otp_builds/releases/download/"
                    .. tag_name
                    .. "/"
                    .. file_prefix
                    .. "-macos-amd64.tar.gz"
            end
        elseif mapped_arch == "x86_64" then
            -- For x86_64, always use the same naming pattern as aarch64
            download_url = "https://github.com/erlef/otp_builds/releases/download/"
                .. tag_name
                .. "/otp-x86_64-apple-darwin.tar.gz"
        end
    else
        -- Source archives: release versions are tags named OTP-<version>, while master and the
        -- maint branches are branches of the repository and must be fetched from refs/heads.
        local archive_ref
        if erlang_version == "master" or erlang_version == "maint" or string.match(erlang_version, "^maint%-%d+$") then
            archive_ref = "refs/heads/" .. erlang_version
        elseif string.sub(erlang_version, 1, 4) == "OTP-" then
            archive_ref = "refs/tags/" .. erlang_version
        else
            archive_ref = "refs/tags/OTP-" .. erlang_version
        end
        download_url = "https://github.com/erlang/otp/archive/" .. archive_ref .. ".tar.gz"
    end

    print("Download Erlang/OTP from " .. download_url)

    return {
        version = erlang_version,
        url = download_url,
    }
end
