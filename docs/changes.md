# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. For published versions, the release notes on [GitHub Releases](https://github.com/version-fox/vfox-erlang/releases) are the reference. The date after each version is the date of its GitHub Release, in UTC.

## Unreleased

### Fixed

- When a version name is not in the version list, the refusal now names `USE_PREBUILT_OTP=<value> vfox search erlang` if `USE_PREBUILT_OTP` is set on Linux or macOS. That is the command that lists the prebuilt names. Before, it always named `vfox search erlang`, which lists the source releases. The source list holds names that the prebuilt install refuses, such as `17.0` on Ubuntu 24.04.

## 1.2.4 (2026-11-22)

### Fixed

- A name that ends in `latest` is refused before the download when the version list does not show it, as other names are. Only the macOS prebuilt branch names `master-latest`, `maint-latest` and `maint-<number>-latest` skip the list check, and only with `USE_PREBUILT_OTP` set on macOS. Before, `erlang@master-latest` and `erlang@maint-<number>-latest` also skipped the check on Linux and in a macOS source build, and then failed in the download.
- A source build also refuses an install path that contains a tab or a newline, before `configure` starts. As with a space, the unquoted `cd ${PWD}` that `configure` runs splits the path at a tab or a newline. Before, a tab in the path made `configure` fail with `cannot find sources`. Set `VFOX_HOME` to a path without tabs or newlines.

## 1.2.3 (2026-11-22)

### Fixed

- `vfox install` with an unsupported `USE_PREBUILT_OTP` value on Linux, such as `ubuntu-99.04`, reports the value only. It used to report "Could not read the version list" first, then the same message again from `PreInstall`.
- A name that ends in `latest` is refused before the download when the version list does not show it, as other names are. Only the macOS branch names `master-latest`, `maint-latest` and `maint-<number>-latest` skip the list check. Before, `erlang@foo-latest` downloaded from GitHub and then failed.
- A source build refuses an install path that contains a space, before `configure` starts. OTP's `configure` runs `cd ${PWD}` without quotes, so a space makes its timestamp check fail. The note under 1.2.1 that a path with spaces works is true for prebuilt installs only. Set `VFOX_HOME` to a path without spaces.
- The messages of a failed install say "required utilities", not "required utilties".

### Changed

- With a warm search cache, `vfox search` shows the cached list for any `USE_PREBUILT_OTP` value. vfox does not call the plugin while its cache is fresh, so the plugin cannot check the value then. `vfox install` still checks it on Linux. See [prebuilt.md](prebuilt.md).

## 1.2.2 (2026-11-22)

### Fixed

- `vfox install` refuses a version name that the version list does not show, such as `erlang@28` or `erlang@OTP-99.9`, before anything is downloaded. The message points to `vfox search erlang`. Branches (`master`, `maint-27`, and the names ending in `-latest`) are not in the lists and are not checked. When the list cannot be read, the install goes on without the check. The release list and the macOS list are refreshed weekly, so a release published since the last refresh is refused until the list includes it.
- `vfox link --detect erlang` lists only an installation whose `bin/erl` can run. An installation whose `erl` is not executable was listed, and then it failed to link.
- A source build stops before `configure` when the install path contains an apostrophe, a double quote, a dollar sign or a backtick. OTP's `configure` cannot take these characters. An apostrophe made the build fail about half a minute in. Set `VFOX_HOME` to another path.

## 1.2.1 (2026-11-22)

### Added

- A bilingual documentation website, built from `website/` and published with GitHub Pages. See [website/README.md](../website/README.md).
- End-to-end workflows for mise users on Linux and macOS, which install through the vfox backend of mise. See [mise.md](mise.md).
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

- Releases use the shared plugin workflow. Run **Actions → Plugin → Run workflow** on the default branch, or push a `v*` tag whose version matches `metadata.lua`. Pull request titles no longer trigger a release. See [Releasing](development.md#releasing).
- The Windows installer runs without the PowerShell-only `-Wait -PassThru` arguments.
- The README and the documentation are rewritten in English and Chinese.
- The typo `Uinx` in the plugin description in `metadata.lua` is corrected to `Unix`.
- With `USE_PREBUILT_OTP` set, the Windows version list no longer changes. Windows always uses the official installer.
- On Linux, `vfox search` with `USE_PREBUILT_OTP` reads the `builds.txt` index that Bob publishes for the release and for the architecture vfox runs on, when you search. It no longer uses a list generated every week, so arm64 machines see arm64 builds.
- On Linux, `vfox search` with `USE_PREBUILT_OTP` lists releases without the `OTP-` prefix, like the other lists, for example `29.1.2`. Both spellings install the same build.
- On Linux with `USE_PREBUILT_OTP`, an install is recorded as `29.1.2` whichever spelling was typed, so installing the other spelling of an installed release reports it as already installed. A release installed as `OTP-29.1.2` with 1.2.0 or earlier keeps that name; `vfox install` does not recognise it, so it installs the release again.

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
- With `USE_PREBUILT_OTP` set on macOS or Linux, `vfox install erlang@latest` installed a branch (`master`, or `master-latest` on macOS), because branch names came first in the list. The newest final release is first now, then the release candidates, then the branches.
- `vfox use` accepts the other spelling of an installed release. A release installed as `OTP-29.1.2` can be used as `29.1.2`, and the reverse, instead of reporting that it is not installed.

### Removed

- The root `DEVELOPMENT.md`, whose content is now in [development.md](development.md).
- `e2e_test_linux.yaml`, `e2e_test_linux_prebuilt.yaml` and `e2e_test_windows.yaml`, replaced by `e2e.yml`.

## 1.2.0 (2025-07-14)

### Added

- macOS prebuilt installs. With `USE_PREBUILT_OTP` set on macOS, the plugin installs the build that [erlef/otp_builds](https://github.com/erlef/otp_builds) publishes for the Mac's architecture (#13). `vfox search erlang` lists the macOS prebuilt versions. See [prebuilt.md](prebuilt.md).
- The README describes the macOS prebuilt install and shows the CI badges of the prebuilt workflows.

### Removed

- The `.tool-versions` file, which pinned Erlang/OTP 25.3.2.10 for the development of the plugin.

## 1.1.0 (2025-01-26)

### Added

- Linux prebuilt installs. With `USE_PREBUILT_OTP` set to an Ubuntu release, from `ubuntu-14.04` to `ubuntu-24.04`, the plugin downloads the build that [Bob](https://builds.hex.pm) publishes for that release, and runs OTP's `Install` script instead of compiling (#8). `vfox search erlang` lists the prebuilt versions. Before 1.2.1, numeric versions such as `26.2.3` returned 404 from the download server; 1.2.1 fixed it.
- The README has a section on the prebuilt install, and tips for faster source builds such as `MAKEFLAGS=-j8`.

## 1.0.1 (2024-05-14)

### Fixed

- The Erlang/OTP documentation chunks are built and installed, so `h(list).` shows the documentation in the Erlang shell (issue #4).

## 1.0.0 (2024-05-12)

### Added

- Windows installs. `vfox install erlang@25.3.2.12` runs the official Erlang/OTP installer (`otp_win64_<version>.exe` or `otp_win32_<version>.exe`) from the [Erlang/OTP releases](https://github.com/erlang/otp/releases), silently, into the `release` directory of the version (#3).
- The version list includes the four-part Windows versions, such as `25.3.2.12`. `vfox search erlang` lists 438 names in descending order; before, it listed 98.

### Changed

- The README has a logo and the Windows install steps.

## 0.4.1 (2024-04-25)

### Fixed

- `metadata.lua` records version 0.4.1. Version 0.4.0 still recorded 0.3.0.

## 0.4.0 (2024-04-25)

### Added

- `DOC_TARGETS` selects the documentation that is built. It defaults to `chunks`, as before, so the default build does not change.
- The README explains the default documentation build, and how to pass configure options with `OTP_CONFIGURE_ARGS`.

### Changed

- `OTP_COMPILE_ARGS` is renamed to `OTP_CONFIGURE_ARGS`. The old name is no longer read.
- `vfox search erlang` lists 98 names instead of 28.
- The repository moved to the `version-fox` organization (#1). The install command, the version list and the update manifest point to `version-fox/vfox-erlang`.

## 0.3.0 (2024-04-03)

### Changed

- `metadata.lua` records version 0.3.0. Versions 0.1 and 0.2 recorded 0.0.1.
- The update manifest points to this plugin's release manifest, not to the plugin template's.

## 0.2 (2024-04-03)

The plugin code is the same as 0.1. The tag points to the same commit.

## 0.1 (2024-04-01)

### Added

- The first release. On Linux and macOS, the plugin installs Erlang/OTP from the source archive of the `OTP-<version>` tag, with `vfox install erlang@<version>`, and builds the documentation chunks.
- `vfox search erlang` lists the versions in `assets/versions.txt`.
- `OTP_COMPILE_ARGS` passes options to `./configure`.
