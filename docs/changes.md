# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

Changes after 1.2.0 are recorded here. For published versions, the release notes on [GitHub Releases](https://github.com/version-fox/vfox-erlang/releases) are the reference.

## Unreleased

### Added

- Scanning of Erlang/OTP installations already on the system, through the `Detect` hook and `vfox link --detect`. This needs vfox 1.1.0 or later. See [link.md](link.md).
- End-to-end suites written in Go for Ubuntu and Windows, and a Linux test container (`tests/e2e/linux/Dockerfile`). See [e2e.md](e2e.md).
- Offline Lua unit tests (`tests/*_test.lua`).
- Workflows for lint and formatting (stylua, LuaLS, gofmt, go vet, ruff and actionlint), for the offline tests, and for license headers (SkyWalking Eyes).
- Dependabot updates for the GitHub Actions versions, and settings for stylua, ruff and LuaLS (`stylua.toml`, `ruff.toml`, `.luarc.json`).
- Bilingual documentation in `docs/` and `docs/zh-CN/`.
- Permissions allowed in `opencode.jsonc`.
- `.gitattributes` to keep LF line endings.
- `ubuntu-26.04` is accepted as a `USE_PREBUILT_OTP` value on Linux. Bob publishes its OTP builds for amd64 and arm64.

### Changed

- The Windows installer runs without the PowerShell-only `-Wait -PassThru` arguments.
- The README and the documentation are rewritten in English and Chinese.
- The typo `Uinx` in the plugin description in `metadata.lua` is corrected to `Unix`.
- With `USE_PREBUILT_OTP` set, the Windows version list no longer changes. Windows always uses the official installer.
- On Linux, `vfox search` with `USE_PREBUILT_OTP` reads the `builds.txt` index that Bob publishes for the release and for the architecture vfox runs on, when you search. It no longer uses a list generated every week, so arm64 machines see arm64 builds.

### Fixed

- Linux prebuilt installs of numeric versions, such as `26.2.3`, requested builds.hex.pm without the `OTP-` prefix, which returned 404.
- `pre_install` built a string from an empty version before it checked for one, which gave an unhelpful error.
- `post_install` printed `%s` literally, and a pointless `sleep 3` was removed.
- Source builds and prebuilt installs quote the installation path, so a path with spaces works. The Windows installer path is quoted too.
- `pre_use` crashed for a version that is not installed, instead of reporting it.
- Errors while downloading the version list were not handled.
- On Windows, `EnvKeys` always put `release\bin` on `PATH`. A linked system installation keeps `bin` at its root, so `erl` was not found.
- The `update_otp_versions` workflow built its commit author name incorrectly, repeating `github-actions[bot]`.
- `get_all_otp_versions.py` checked the status code of only the last GitHub API response.
- Source builds of `master` and `maint-<N>` downloaded the archive from `refs/tags/`, which returned 404. They now download from `refs/heads/`.
- A source build of a version that already has the `OTP-` prefix, such as `OTP-26.2.3`, became `OTP-OTP-26.2.3` and returned 404. The prefix is no longer added twice.
- On Linux, `vfox search` with `USE_PREBUILT_OTP` listed the ubuntu-20.04 builds for every Ubuntu release, so builds that exist only for newer releases, such as `OTP-29.1.2` on ubuntu-24.04, were missing. The list now comes from the builds of the release that the variable names.
- `vfox search` with an unsupported `USE_PREBUILT_OTP` value, such as `ubuntu-99.04`, listed builds instead of failing. It now reports the supported values, as `vfox install` does.
- An empty `USE_PREBUILT_OTP` counts as unset, so the source build runs.

### Removed

- The root `DEVELOPMENT.md`, whose content is now in [development.md](development.md).
- `e2e_test_linux.yaml`, `e2e_test_linux_prebuilt.yaml` and `e2e_test_windows.yaml`, replaced by `e2e.yml`.
