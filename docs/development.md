# Development

[中文](zh-CN/development.md) | [English](development.md)

This page is for people who change the plugin: how the hooks work, where the code lives, which checks to run, and how a release is published.

## How the plugin works

vfox calls the hooks in `hooks/`:

| Hook | File | What it does |
| --- | --- | --- |
| `Available` | `hooks/available.lua` | Returns the versions for `vfox search`: the list in `assets/versions.txt`, or, when `USE_PREBUILT_OTP` is set, the builds that Bob lists for the Ubuntu release it names, read from the `builds.txt` index for the architecture vfox runs on, or the macOS list. The `versions.txt` and macOS lists are read through jsDelivr. When the version list cannot be read, or `USE_PREBUILT_OTP` names no supported release, the reason is printed and nil is returned. |
| `PreInstall` | `hooks/pre_install.lua` | Checks that a version was given and, unless it is a branch name (`master`, `maint`, `maint-<number>`, or, with `USE_PREBUILT_OTP` set on macOS, a `-latest` branch name such as `master-latest`), that the version list shows it. Then returns the download URL and, for a Linux prebuilt build, the SHA-256 that `builds.txt` lists for it, if any. Windows uses the official installer: on arm64, the 32-bit one when the release publishes it, checked with a HEAD request before the download. With `USE_PREBUILT_OTP` set, Linux uses the Bob package and macOS the erlef/otp_builds package. Other versions use the GitHub source archive: the tag `OTP-<version>` for a release, or the branch for `master`, `maint` and `maint-<number>`. |
| `PostInstall` | `hooks/post_install.lua` | Installs what was downloaded. Windows runs the installer. A Linux prebuilt package runs OTP's `Install` script. A macOS prebuilt package is moved into `release/`. A source build is refused first if its install path holds a space, a tab, a newline, an apostrophe, a double quote, a dollar sign or a backtick. PreInstall refuses that path before the download, so this is a second check. Otherwise it is configured, built and installed, and its documentation chunks are built and installed. |
| `EnvKeys` | `hooks/env_keys.lua` | Sets `PATH` to the first of `release/bin`, `bin` and `lib/erlang/bin` that contains `erl` (`erl.exe` on Windows). The directory is found by looking for the executable, so source builds, prebuilt installs and linked installs all work. |
| `PreUse` | `hooks/pre_use.lua` | Checks that the version being used is installed, and returns it. Otherwise it fails and suggests `vfox install` or `vfox link --detect`. |
| `Detect` | `hooks/detect.lua` | Scans the locations listed in [link.md](link.md) for existing Erlang/OTP installations, for `vfox link --detect`. The scanning code is in `lib/detect_erlang.lua`. |

A refusal, such as a version name that the version list does not show, or a source install path that OTP's `configure` cannot take, is printed by PreInstall, which then returns nil. vfox stops the install with "no installable runtime provided" and prints no traceback. `Available` does the same when the version list cannot be read or `USE_PREBUILT_OTP` names no supported release; `vfox search` then reports "plugin [Available] method error: no available version provided". An error that a hook raises is followed by a Lua stack traceback, so a refusal is printed and returned as nil instead. PostInstall still raises its path refusal, because vfox records an install whose PostInstall returns normally.

## File layout

```
hooks/           vfox hooks, one file per hook
lib/             shared Lua helpers: erlang_utils.lua and detect_erlang.lua
tests/           offline Lua tests (tests/*_test.lua) and the Go end-to-end suites (tests/e2e)
assets/          version lists, hello.erl, get_all_otp_versions.py, logo and images
website/         the bilingual documentation site and its build script
docs/            this documentation; docs/zh-CN/ holds the Chinese pages
metadata.lua     plugin name, version, minimum vfox version (minRuntimeVersion) and manifest URL
Injection.lua    type hints for the objects vfox injects, such as RUNTIME; for editors only, do not change it
.luarc.json      LuaLS settings: Lua 5.1, and the globals PLUGIN and RUNTIME
.licenserc.yaml  license header rule; the header text is defined here
stylua.toml      Lua formatting: 120 columns, 4 spaces, LF line endings, double quotes preferred
ruff.toml        Python lint and format settings
```

## Checks

Run the checks that CI runs before you push. The commands run from the repository root unless a `cd` is shown.

| Check | Command | Workflow |
| --- | --- | --- |
| Lua format | `stylua --check .` | Lint |
| Lua types | `lua-language-server --check . --checklevel=Warning` (CI runs LuaLS 3.19.1 through mise) | Lint |
| Offline Lua tests | `vfox plugin test .` with vfox 1.1.0. Each `tests/*_test.lua` runs in its own VM. | Test Plugin |
| Go format | `cd tests/e2e && gofmt -l .` (no output means every file is formatted) | Lint |
| Go vet | `cd tests/e2e && go vet ./... && GOOS=windows go vet ./...` | Lint |
| Go unit tests | `cd tests/e2e && go test -short ./...` | Test Plugin |
| Python | `ruff check .` and `ruff format --check .` (CI pins ruff 0.17.6) | Lint |
| Workflow files | `actionlint` (CI pins actionlint 1.7.12) | Lint |
| License headers | `license-eye header check` | License |

CI installs the tools with `go install github.com/version-fox/vfox@v1.1.0` and `go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12`. The end-to-end suites run in the E2E workflow, see [e2e.md](e2e.md).

## Adding files

Source files need the Apache license header that `.licenserc.yaml` defines. Markdown and JSON files are not checked. Install the license tool with:

```shell
go install github.com/apache/skywalking-eyes/cmd/license-eye@latest
```

Then run `license-eye header check` to find files without a header, or `license-eye header fix` to add the header to them.

## Trying a change in vfox

`vfox plugin test .` runs the offline tests against the working tree. To install a branch as the plugin in vfox, push the branch and add its archive, the same way the E2E workflows do. Remove the plugin first if it is already added:

```shell
vfox remove erlang
vfox add --source https://github.com/version-fox/vfox-erlang/archive/refs/heads/<branch>.zip erlang
```

## Version lists

`assets/versions.txt`, `assets/macos_prebuilt_versions.txt` and `assets/prebuilt_versions.txt` are generated by `assets/get_all_otp_versions.py`. The script reads release tags from the GitHub API, the macOS list from the releases of erlef/otp_builds, and `prebuilt_versions.txt` from the ubuntu-20.04 `builds.txt` of Bob. Linux prebuilt searches use no generated list: they read the `builds.txt` index of the release that `USE_PREBUILT_OTP` names. `prebuilt_versions.txt` stays for plugin copies that predate that change. The `update_otp_versions` workflow runs the script every week and commits the result.

## Website

Build the documentation site locally:

```shell
python3 website/build.py --output /tmp/vfox-erlang-site
python3 -m http.server 8080 --directory /tmp/vfox-erlang-site
```

The Chinese pages are at `http://localhost:8080/` and the English pages at `http://localhost:8080/en/`. The build reads the plugin version and the minimum vfox version from `metadata.lua`. The GitHub Pages workflow builds pull requests, deploys `main`, and refreshes the site after a successful release. See [website/README.md](../website/README.md).

## Releasing

Maintainers publish a release from the Actions tab:

1. Open **Actions → Plugin → Run workflow** on the default branch.
2. Enter a stable plugin version without the `v` prefix, in the form `X.Y.Z`.

The shared workflow updates `metadata.lua`, creates the version commit and the tag, and publishes the ZIP and the manifest in this repository. No local tag or extra release token is needed.

- Pull requests run checks only. The title of a pull request does not trigger a release.
- Pushing a `v*` tag also publishes, as long as `PLUGIN.version` in `metadata.lua` already matches the tag.
- If publication fails, re-run the failed job of the original run to resume it.
- The workflow follows the shared `@v1` release tool of [version-fox/plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action). Updating that tool does not release this plugin. The package contract and the first-rollout requirements are documented in the same repository.

## Other workflows

| Workflow | File | Purpose |
| --- | --- | --- |
| E2E | `e2e.yml` | End-to-end suites for Linux, Windows and Windows arm64, see [e2e.md](e2e.md) |
| E2E (macOS and mise) | `e2e_test_darwin.yaml`, `e2e_test_darwin_prebuilt.yaml`, `e2e_test_darwin_mise.yaml`, `e2e_test_linux_mise.yaml` | macOS and mise suites, see [e2e.md](e2e.md) |
| Plugin | `publish.yaml` | Releases, see above |
| GitHub Pages | `pages.yaml` | The documentation site |
| update_otp_versions | `update_otp_versions.yaml` | The weekly update of the version lists |
