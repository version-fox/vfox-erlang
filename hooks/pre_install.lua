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

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- ctx.version is the version the user typed.
--- A refusal prints its message and returns nil. vfox prints a stack traceback below an error that a hook raises, but
--- for a nil result it stops the install with "no installable runtime provided" and no traceback.
--- @param ctx table
--- @return table|nil Version information, or nil when the install is refused, after the reason is printed
function PLUGIN:PreInstall(ctx)
    local erlang_version = ctx.version
    if erlang_version == nil or erlang_version == "" then
        print("You must provide a version number for Erlang/OTP, eg: vfox install erlang@26.2.3")
        return nil
    end
    print("You will install the Erlang/OTP version is: " .. erlang_version)
    local PRE_BUILT_OS_RELEASE = erlangUtils.get_config_from_env("USE_PREBUILT_OTP")
    -- A USE_PREBUILT_OTP value that names no supported Ubuntu release is refused before any list is read.
    local config_refusal = erlangUtils.prebuilt_config_refusal()
    if config_refusal ~= nil then
        print(config_refusal)
        return nil
    end
    -- Branches are not looked up in a version list. Any other name must be listed before the download starts: a name
    -- that is not listed would fail in the download, with a generic message.
    local macos_prebuilt_branch = RUNTIME.osType == "darwin"
        and PRE_BUILT_OS_RELEASE ~= nil
        and erlangUtils.is_macos_prebuilt_branch(erlang_version)
    -- The version list, read once. A listed name is checked against it. On Linux, a prebuilt branch is not
    -- checked against it, but the same index publishes its SHA-256, so it is read for that.
    local versions = nil
    if not (erlangUtils.is_branch_name(erlang_version) or macos_prebuilt_branch) then
        local refusal
        versions, refusal = erlangUtils.check_version_listed(erlang_version)
        if refusal ~= nil then
            print(refusal)
            return nil
        end
    elseif RUNTIME.osType == "linux" and PRE_BUILT_OS_RELEASE ~= nil then
        local reason
        versions, reason = erlangUtils.get_erlang_release_versions()
        if versions == nil then
            print(
                "Could not read the version list, so the SHA-256 of " .. erlang_version .. " is not checked: " .. reason
            )
        end
    end

    local download_url
    -- The name the install is recorded under. Linux prebuilt installs use the bare version (below).
    local installed_version = erlang_version
    -- The SHA-256 that builds.txt publishes for a Linux prebuilt build. nil: vfox skips the check and warns.
    local sha256 = nil
    if RUNTIME.osType == "windows" then
        -- The installers are published under the OTP-<version> tag and named by the bare version, so OTP-29.1.2
        -- and 29.1.2 are the same release. Branches are not published on Windows.
        local release = erlangUtils.bare_release_name(erlang_version)
        local win_tag = release
        if not (string.match(release, "latest$") or string.match(release, "^maint%-")) then
            win_tag = "OTP-" .. release
        end
        local installer = erlangUtils.windows_installer_name(release, RUNTIME.archType)
        download_url = "https://github.com/erlang/otp/releases/download/" .. win_tag .. "/" .. installer
        installed_version = release

        -- Erlang/OTP publishes no arm64 installer. arm64 takes the 32-bit one when the release publishes it, so the
        -- release is asked for it with a HEAD request before the download starts. Branches are not asked.
        if RUNTIME.archType == "arm64" and not erlangUtils.is_branch_name(erlang_version) then
            local exists, reason = erlangUtils.url_exists(download_url)
            if exists == false then
                print(
                    "Erlang/OTP "
                        .. release
                        .. " has no build for Windows arm64: its release publishes no "
                        .. installer
                        .. ". The installers of each release are listed at https://github.com/erlang/otp/releases"
                )
                return nil
            elseif exists == nil then
                print("Could not check for " .. installer .. ", so the download decides: " .. tostring(reason))
            end
        end
    elseif RUNTIME.osType == "linux" and PRE_BUILT_OS_RELEASE then
        -- The value was checked above, so it names a supported release.
        local release = PRE_BUILT_OS_RELEASE
        -- builds.hex.pm names numeric releases with the OTP- prefix, e.g. OTP-26.2.3.tar.gz
        download_url = "https://builds.hex.pm/builds/otp/"
            .. RUNTIME.archType
            .. "/"
            .. release
            .. "/"
            .. erlangUtils.bob_build_name(erlang_version)
            .. ".tar.gz"
        -- The install is recorded under the bare version, the name the lists show, whichever spelling was
        -- typed. vfox checks the returned name again before it downloads, so OTP-26.2.3 and 26.2.3 are one install.
        installed_version = erlangUtils.bare_release_name(erlang_version)
        sha256 = erlangUtils.published_sha256(versions, erlang_version)
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
            print(
                "Unsupported architecture for prebuilt MacOS binaries: "
                    .. RUNTIME.archType
                    .. ". Supported architectures: amd64, x86_64, arm64, aarch64"
            )
            return nil
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
        -- A source build runs configure in its install path, so a path that configure cannot take is refused here,
        -- before the download. PostInstall checks the path that vfox gives the install as well.
        if PRE_BUILT_OS_RELEASE == nil then
            local path_refusal = erlangUtils.source_path_refusal(erlang_version)
            if path_refusal ~= nil then
                print(path_refusal)
                return nil
            end
        end
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
        version = installed_version,
        url = download_url,
        sha256 = sha256,
    }
end
