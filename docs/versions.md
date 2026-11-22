# Versions

[中文](zh-CN/versions.md) | [English](versions.md)

This page covers version names, searching, installing, switching between versions and branch versions. For how each platform installs, see [source-build.md](source-build.md), [prebuilt.md](prebuilt.md) and [windows.md](windows.md).

## Version names

A version name is the Erlang/OTP version without the `OTP-` prefix. When it downloads, the plugin adds the prefix to the GitHub tag: `erlang@26.2.3` is the tag `OTP-26.2.3`.

| Kind | Example | Where it installs |
| --- | --- | --- |
| Release | `26.2.3` | Linux and macOS (source or prebuilt), Windows |
| Windows release | `25.3.2.12` | Windows, the four-part numbers of the Windows installers |
| Branch or maintenance | `master`, `maint-27` | Linux and macOS (source or prebuilt), not Windows |

- On Linux, the prebuilt list shows releases without the prefix, as `26.2.3`, like the other lists. Both spellings download the same build and are installed as `26.2.3`. A release installed as `OTP-26.2.3` with 1.2.0 or earlier keeps that name: `vfox use` finds it under either spelling, but `vfox install` does not recognise it, so it installs the release again.
- Prebuilt branch names on macOS end in `-latest`: `master-latest`, `maint-latest` and `maint-27-latest`.
- On Windows, a release installs from the installer that is published under its `OTP-<version>` tag on the [Erlang/OTP releases](https://github.com/erlang/otp/releases) page.

## Search

```shell
vfox search erlang
```

The list depends on the mode:

- Without `USE_PREBUILT_OTP`, the list is the release list in `assets/versions.txt`, which the plugin reads through jsDelivr.
- With `USE_PREBUILT_OTP` set, the list is the prebuilt list for the platform: the list of the Ubuntu release it names on Linux, and the macOS list on macOS. See [prebuilt.md](prebuilt.md).

`vfox install erlang@latest` installs the first name in the list. With `USE_PREBUILT_OTP` set, that is the newest final release, then the release candidates, then the branches.

vfox caches search results for 12 hours by default. If the list looks outdated, see [troubleshooting.md](troubleshooting.md).

## Install

```shell
vfox install erlang@26.2.3
vfox install erlang@25.3.2.12     # Windows
vfox install erlang@master        # branch, source build on Linux or macOS
```

Branch names can also be installed as prebuilt builds, with `USE_PREBUILT_OTP` set (see the branch section below).

How the install happens depends on the platform and on `USE_PREBUILT_OTP`. See [source-build.md](source-build.md), [prebuilt.md](prebuilt.md) and [windows.md](windows.md).

## Switch versions

```shell
eval "$(vfox activate bash)"
vfox use erlang@26.2.3          # the current shell session
vfox use -g erlang@26.2.3       # global, for new shells
vfox use -p erlang@26.2.3       # the current project
```

| Scope | Flag | Effect |
| --- | --- | --- |
| Session | `-s` (default) | The current shell only |
| Global | `-g` | Every shell, unless a narrower scope overrides it |
| Project | `-p` | The current project directory |

A project scope writes the version to `.vfox.toml`, under `[tools]`, as `erlang = "26.2.3"`. vfox also creates a `.vfox/` directory there, and adds `.vfox/` to `.gitignore` if that file exists.

Check what is active:

```shell
vfox current erlang
erl -version
```

## Installed versions

```shell
vfox list erlang
vfox uninstall erlang@26.2.3
```

A linked version, see [link.md](link.md), is removed from the list by `vfox uninstall`, but the Erlang/OTP that it points to stays on the machine.

## Branch and maintenance versions

A branch name such as `master` or `maint-27` installs what the branch contains at install time, so two installs with the same name can get different builds.

- A source build (Linux and macOS, the default) downloads the branch from the Erlang/OTP repository. The accepted names are `master`, `maint` and `maint-<number>`, such as `maint-27`.
- A prebuilt build downloads the package from the prebuilt server. On Linux a release gets the `OTP-` prefix, which the plugin adds, and a branch name is used as typed. On macOS the name ends in `-latest`.

```shell
# Source build on Linux or macOS
vfox install erlang@master
vfox install erlang@maint-27

# Prebuilt on Linux
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@maint-27

# Prebuilt on macOS
USE_PREBUILT_OTP=true vfox install erlang@maint-27-latest
```

Branches are not available on Windows. For the cache setting that prebuilt searches need, see [prebuilt.md](prebuilt.md).
