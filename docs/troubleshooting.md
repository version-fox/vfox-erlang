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

## Prebuilt install fails with 404, or the version is not found

Symptom: the download fails with HTTP 404, or the version you typed is not in `vfox search`.

Check:

```shell
# Linux: does the package exist? amd64 is the architecture name vfox uses on x86-64
curl -sI https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/OTP-26.2.3.tar.gz | head -n 1

# Linux: which versions does Bob have for this Ubuntu release?
curl -s https://builds.hex.pm/builds/otp/ubuntu-22.04/builds.txt | grep 26.2.3

# Which names does the plugin list?
USE_PREBUILT_OTP=ubuntu-22.04 vfox search erlang | grep 26.2.3
```

A package that exists returns a 200 status.

Fix:

- Use a name from `vfox search` with the same `USE_PREBUILT_OTP` value. Write release versions without `OTP-`; the plugin adds the prefix for the download.
- If `builds.txt` has no entry for the version, Bob has no build of it for that Ubuntu release. Use another version, or unset `USE_PREBUILT_OTP` to build from source.
- On macOS, branch names end in `-latest`, for example `maint-27-latest`.
- If the name is listed but the download still fails, the search list may be stale. See [The search list is outdated](#the-search-list-is-outdated).

## USE_PREBUILT_OTP has an unsupported value

Symptom: on Linux, the install stops with `USE_PREBUILT_OTP must be one of: ubuntu-14.04, ubuntu-16.04, ubuntu-18.04, ubuntu-20.04, ubuntu-22.04, ubuntu-24.04, ubuntu-26.04. Got: ...`.

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
- If the `OTP_VERSION` check prints nothing, that directory is not an Erlang/OTP installation.

## The search list is outdated

Symptom: `vfox search erlang` does not show a release that exists, or it still shows the list from before you changed `USE_PREBUILT_OTP`.

Check:

```shell
vfox config cache.availableHookDuration     # the cache time; the default is 12h
ls -l ~/.vfox/plugin/erlang/.available.cache
```

Fix:

```shell
vfox config cache.availableHookDuration 0   # no caching while you work
rm -f ~/.vfox/plugin/erlang/.available.cache
vfox search erlang
```

- When you are done, restore the cache with `vfox config cache.availableHookDuration 12h`.
- The lists are updated once a week by a workflow and served through jsDelivr, which keeps its own cache. A release published very recently can be missing until the next update.

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

Cause: vfox recognises an install by its exact name. Installs made before the Linux prebuilt list showed bare versions are named `OTP-29.1.2`. With the new plugin, installs are named `29.1.2`. vfox does not know that the two names are the same release, so it installs both.

Fix:

- Keep the copy you use. `vfox use` finds the release under either name.
- To remove the other copy, run `vfox uninstall erlang@OTP-29.1.2` (or `erlang@29.1.2`). If you remove the current version, vfox switches to the other copy.
- With the new plugin, installing the same release under either name later reports `already installed`, so the duplicate only comes from installs made before the change.

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
