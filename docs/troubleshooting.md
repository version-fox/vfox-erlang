# Troubleshooting

[中文](zh-CN/troubleshooting.md) | [English](troubleshooting.md)

Each entry gives the symptom, the commands that check it and the fix. Run the commands in the shell where the problem happens.

## Source build fails in configure, make or the documentation step

Symptom: `vfox install` stops with an error from `./configure`, `make` or `make docs`, for example a missing curses or OpenSSL library.

Check:

```shell
# Keep the full output and find the first error
vfox install erlang@26.2.3 2>&1 | tee /tmp/otp-build.log
grep -n -i "error" /tmp/otp-build.log | head -n 20

# Linux: the tools and headers the build needs
command -v gcc make autoconf m4 xsltproc
ls /usr/include/ncurses.h /usr/include/openssl/ssl.h

# macOS: the Homebrew packages
brew list --versions autoconf libxslt fop wxwidgets openssl@3
```

Fix:

- Install the packages listed in [source-build.md](source-build.md), then run the install again. If vfox still lists the version, uninstall it first with `vfox uninstall erlang@26.2.3`.
- On macOS, if `configure` cannot find OpenSSL, point it at the Homebrew copy: `export OTP_CONFIGURE_ARGS="--with-ssl=$(brew --prefix openssl@3)"`.
- If `OTP_CONFIGURE_ARGS` may be the cause, run `./configure --help` in the source directory, which is `<sdk>`. `vfox info erlang@26.2.3` shows the path.

## The source build stops before configure, naming a character in the install path

Symptom: `vfox install` stops before the download starts, with `The Erlang/OTP install path ... contains an apostrophe, which OTP's configure cannot take.` A space, a tab, a newline, a double quote, a dollar sign or a backtick is reported in the same way. No Lua stack traceback follows the message.

Check:

```shell
echo "$VFOX_HOME"                      # the install path is under VFOX_HOME when it is set
ls -d ~/.version-fox ~/.vfox 2>/dev/null   # when VFOX_HOME is unset, ~/.version-fox is used if it exists, else ~/.vfox
```

Fix:

- Set `VFOX_HOME` to a directory whose path has none of these characters, then install again, for example `export VFOX_HOME=/opt/vfox`. The directory must be writable.
- The check applies to source builds only. The Windows installer and the prebuilt packages do not run `configure`.

## Prebuilt install fails with 404, or the version is not found

Symptom: the download fails with HTTP 404, or the version you typed is not in `vfox search`.

Check:

```shell
# Linux: does the package exist? amd64 is the architecture name vfox uses on x86-64
curl -sI https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/OTP-26.2.3.tar.gz | head -n 1

# Linux: which versions does Bob have for this Ubuntu release? On arm64, use arm64 in place of amd64
curl -s https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/builds.txt | grep 26.2.3

# Which names does the plugin list?
USE_PREBUILT_OTP=ubuntu-22.04 vfox search erlang | grep 26.2.3
```

A package that exists returns a 200 status.

Fix:

- Use a name from `vfox search` with the same `USE_PREBUILT_OTP` value. Write release versions without `OTP-`; the plugin adds the prefix for the download.
- If `builds.txt` has no entry for the version, Bob has no build of it for that Ubuntu release. Use another version, or unset `USE_PREBUILT_OTP` to build from source.
- On macOS, branch names end in `-latest`, for example `maint-27-latest`.
- If the name is listed but the download still fails, the search list may be stale. See [The search list is outdated](#the-search-list-is-outdated).

## The archive fails its checksum

Symptom: the install prints `Verifying checksum <sha256>...`, then a checksum error, and it stops before the archive is unpacked.

Check:

```shell
# Linux: the SHA-256 that Bob publishes for the build, in the fourth column
curl -s https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt | grep '^OTP-29.1.2 '

# The hash of the archive itself, which must be the same value. This is a large download.
curl -s https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-29.1.2.tar.gz | sha256sum
```

Fix:

- For a release, `OTP-<version>`, the published value does not change. A mismatch then means the download was damaged or changed on the way. Install again. If it fails again, report it with the output.
- For a branch, such as `master` or `maint-27`, the archive was probably rebuilt after the index was read, or the index is stale. Wait a few minutes, then install again.

## The version name is not in the version list

Symptom: `vfox install` stops before the download with `Erlang/OTP 28 is not in the version list, so it cannot be installed.`

Check:

```shell
vfox search erlang              # the names this plugin can install from source
USE_PREBUILT_OTP=ubuntu-24.04 vfox search erlang   # the names it can install prebuilt, with USE_PREBUILT_OTP set on Linux or macOS
```

Fix:

- The message names the command to run. With `USE_PREBUILT_OTP` set on Linux or macOS, it names `USE_PREBUILT_OTP=<value> vfox search erlang`, because the prebuilt list is the one the install checks. Run that command, not the plain one.
- Use a full name from the list that the command shows, such as `26.2.3`. A partial name such as `28` is not in the list, so it is refused. Branch names such as `master` and `maint-27` are not checked against the list, so they are installed as before.
- The release and macOS lists are generated once a week. A release that came out after the last refresh is refused until the list includes it.
- The Linux prebuilt list is read from Bob's index when you search, so the weekly refresh does not affect it. See [prebuilt.md](prebuilt.md).

## USE_PREBUILT_OTP has an unsupported value

Symptom: on Linux, the install, or `vfox search erlang`, stops with `USE_PREBUILT_OTP must be one of: ubuntu-14.04, ubuntu-16.04, ubuntu-18.04, ubuntu-20.04, ubuntu-22.04, ubuntu-24.04, ubuntu-26.04. Got: ...`.

Check:

```shell
echo "$USE_PREBUILT_OTP"
uname -m     # on macOS, x86_64 (Intel) and arm64 (Apple silicon) are both supported
```

Fix:

- Linux: use one of `ubuntu-14.04`, `ubuntu-16.04`, `ubuntu-18.04`, `ubuntu-20.04`, `ubuntu-22.04`, `ubuntu-24.04` or `ubuntu-26.04`. `true` is not valid on Linux.
- macOS: set `USE_PREBUILT_OTP=true`. If the install reports an unsupported architecture, the Mac is not `amd64`, `x86_64`, `arm64` or `aarch64`.
- Windows ignores the variable.

## Windows installer fails

Symptom: after the download, `vfox install` reports that the Erlang/OTP install failed.

Check (PowerShell):

```pwsh
# Where vfox keeps the installer: use the path that vfox info prints
vfox info erlang@25.3.2.12
Get-ChildItem -Path "<sdk>" -Filter "otp_win*.exe"

# Can the installer be downloaded at all?
Invoke-WebRequest -Method Head -UseBasicParsing -Uri "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe" | Select-Object StatusCode
```

Replace `<sdk>` with the path that `vfox info` printed.

Fix:

- Double-click the same `.exe` to see the installer's own messages. The silent run hides them.
- If the status code is not 200, the download is blocked or the release has no installer. Check the network, see [Downloads fail or time out](#downloads-fail-or-time-out), or choose a version that has an installer on the releases page.
- If `vfox list erlang` still shows the failed version, remove it with `vfox uninstall erlang@25.3.2.12` before you retry.

## Windows arm64: the version has no build

Symptom: `vfox install` stops before the download with `Erlang/OTP <version> has no build for Windows arm64`.

Cause: on arm64 the plugin uses the 32-bit installer, `otp_win32_<version>.exe`. The release of that version does not publish it. Erlang/OTP 29.x publishes only the 64-bit installer.

Check the installers of a release:

```sh
gh api repos/erlang/otp/releases/tags/OTP-<version> --jq '.assets[].name'
```

Fix:

- Choose a version whose release lists `otp_win32_<version>.exe`, such as 28.5.0.8, which lists both installers.
- CI checks the 32-bit installer on Windows arm64 with Erlang/OTP 28.5.0.8 only. After you install such a version, check that `erl.exe` runs, as in [windows.md](windows.md).

## link --detect finds nothing, or the command is not recognized

Symptom: `vfox link --detect erlang` lists nothing, or vfox does not know the `--detect` flag.

Check:

```shell
vfox --version                                  # must be 1.1.0 or later
ls /usr/lib/erlang/releases/*/OTP_VERSION       # the location used by the Debian and Ubuntu package
vfox list erlang                                # installed and linked versions are skipped
```

Fix:

- Upgrade vfox to 1.1.0 or later with `vfox upgrade`. The [vfox quick start](https://vfox.dev/guides/quick-start.html) lists the other ways to install it.
- If the installation is somewhere the scan does not look, link it by hand: `vfox link erlang@26.2.3 /path/to/otp`. See [link.md](link.md).
- A path that contains a `.vfox` directory is never scanned.
- If `bin/erl` is not executable, the installation is not listed. Set the execute bit with `chmod +x <installation>/bin/erl`, then run the command again.
- If the `OTP_VERSION` check prints nothing, that directory is not an Erlang/OTP installation.

## The search list is outdated

Symptom: `vfox search erlang` does not show a release that exists, or it still shows the list from before you changed `USE_PREBUILT_OTP`.

Check:

```shell
vfox config cache.availableHookDuration     # the cache time; the default is 12h
ls -l ~/.version-fox/plugin/erlang/.available.cache ~/.vfox/plugin/erlang/.available.cache 2>/dev/null   # with VFOX_HOME set, look in $VFOX_HOME/plugin/erlang instead
```

Fix:

```shell
vfox config cache.availableHookDuration 0   # no caching while you work
rm -f ~/.version-fox/plugin/erlang/.available.cache ~/.vfox/plugin/erlang/.available.cache   # or $VFOX_HOME/plugin/erlang/.available.cache when VFOX_HOME is set
vfox search erlang
```

- When you are done, restore the cache with `vfox config cache.availableHookDuration 12h`.
- The release and macOS lists are updated once a week by a workflow and served through jsDelivr, which keeps its own cache. A release published very recently can be missing until the next update. The Linux prebuilt list is read from Bob's `builds.txt` index directly, so only vfox's own search cache can hold it back.

## Downloads fail or time out

Symptom: `vfox install` or `vfox search` cannot reach github.com, builds.hex.pm or jsDelivr.

Check:

```shell
curl -sI https://github.com | head -n 1
curl -sI https://builds.hex.pm | head -n 1
curl -sI https://fastly.jsdelivr.net | head -n 1
```

Fix: if your network needs a proxy, set it in vfox:

```shell
vfox config proxy.enable true
vfox config proxy.url http://host:port
```

Replace `host:port` with your proxy. The [vfox configuration guide](https://vfox.dev/guides/configuration.html) describes the format.

## vfox use says the version is not installed

Symptom: with vfox activated, `vfox use erlang@26.2.3` stops with `Erlang/OTP 26.2.3 is not installed.`

Check:

```shell
vfox list erlang
```

Fix:

- Install the version with `vfox install erlang@26.2.3`, or link an installation that is already on the machine with `vfox link --detect erlang`. See [link.md](link.md).

## The same release is installed twice

Symptom: `vfox list erlang` shows two entries for one release, such as `OTP-29.1.2` and `29.1.2`. Or `vfox install erlang@29.1.2` downloads the build again after you installed `erlang@OTP-29.1.2`.

Cause: vfox recognises an install by the name the plugin records for it, and it does not know that two names are the same release. The recorded name depends on the platform and the install method:

- On Linux with `USE_PREBUILT_OTP`, from 1.2.1 on, and on Windows, from 1.2.6 on, both spellings are recorded as `29.1.2`, so installing the other spelling reports `already installed`. On Linux, a release installed as `OTP-29.1.2` with 1.2.0 or earlier keeps that name, and `vfox install erlang@29.1.2` installs it again.
- Source builds and macOS record the name as you typed it, so `OTP-29.1.2` and `29.1.2` are two installs.

Fix:

- Keep the copy you use. `vfox use` finds the release under either name.
- To remove the other copy, run `vfox uninstall erlang@OTP-29.1.2` (or `erlang@29.1.2`). If you remove the current version, vfox switches to the other copy.
- Install with the name that `vfox search erlang` shows, such as `29.1.2`, so that each release has one name.

## erl is missing, or another erl runs

Symptom: `erl` is not found after `vfox use`, or it runs a different Erlang/OTP.

Check:

```shell
vfox current erlang
command -v erl
vfox doctor erlang
```

Fix:

- First confirm that `vfox activate` has run in this shell. Without it, `vfox use` fails with `vfox requires hook support`, and `erl` is not on `PATH`.
- Make sure vfox is hooked into your shell: `eval "$(vfox activate bash)"` in `~/.bashrc`, or the matching line for zsh in `~/.zshrc`. See the [vfox quick start](https://vfox.dev/guides/quick-start.html).
- If `command -v erl` shows a path outside vfox, another installation comes earlier in `PATH`. `vfox doctor erlang` reports problems of this kind, and the [vfox configuration guide](https://vfox.dev/guides/configuration.html) describes the `path` settings.

## The build works, but h(lists). shows no documentation

Symptom: `erl` runs, but `h(lists).` or `shell_docs:get_doc(lists)` shows nothing.

Check:

```shell
erl -noshell -eval 'erlang:display(shell_docs:get_doc(lists)), halt().' | grep "functions for list processing"
```

No output means the documentation chunks are missing.

Fix: install again with the default `DOC_TARGETS`:

```shell
unset DOC_TARGETS
vfox uninstall erlang@26.2.3
vfox install erlang@26.2.3
```

See [source-build.md](source-build.md) for what `DOC_TARGETS` controls.
