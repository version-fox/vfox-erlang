# Prebuilt releases

[中文](zh-CN/prebuilt.md) | [English](prebuilt.md)

Prebuilt releases skip compilation. Setting `USE_PREBUILT_OTP` selects the prebuilt package:

| Platform | `USE_PREBUILT_OTP` | Package source |
| --- | --- | --- |
| Linux | An Ubuntu release, such as `ubuntu-22.04` | [builds.hex.pm](https://builds.hex.pm) (Bob) |
| macOS | `true` | [erlef/otp_builds](https://github.com/erlef/otp_builds) |
| Windows | Ignored | The official installer, see [windows.md](windows.md) |

## Before you install

Turn off vfox's search cache before you use prebuilt releases. vfox keeps one search cache per plugin, and the cache does not depend on `USE_PREBUILT_OTP`. A list cached from the release list can hide the prebuilt names.

```shell
vfox config cache.availableHookDuration 0
```

`0` means no caching. When you are done, restore the default with `vfox config cache.availableHookDuration 12h`. You can also delete `~/.vfox/plugin/erlang/.available.cache`.

## Linux (Bob)

```shell
USE_PREBUILT_OTP=ubuntu-22.04 vfox search erlang
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@26.2.3
```

`USE_PREBUILT_OTP` must be one of these values:

- `ubuntu-14.04`
- `ubuntu-16.04`
- `ubuntu-18.04`
- `ubuntu-20.04`
- `ubuntu-22.04`
- `ubuntu-24.04`
- `ubuntu-26.04`

Choose the value that matches your Ubuntu release. Only Ubuntu values are accepted, so other distributions build from source. `vfox search` reads the `builds.txt` index that Bob publishes for the chosen release and for your architecture, so it lists the builds that the install can download.

The download URL has this form:

```
https://builds.hex.pm/builds/otp/<arch>/<USE_PREBUILT_OTP>/<name>.tar.gz
```

- `<arch>` is the architecture that vfox reports. On x86-64 it is `amd64`.
- A release version gets the `OTP-` prefix added. `26.2.3` downloads `OTP-26.2.3.tar.gz`. A name that already has the prefix, such as `OTP-26.2.3`, is used as typed.
- A branch name is used as typed, for example `maint-27` or `master`.

After the archive is unpacked, the plugin runs the `Install` script that comes with OTP (`./Install -cross -sasl`) in the install directory.

Branch versions:

```shell
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@maint-27
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@master
```

## macOS (erlef/otp_builds)

```shell
USE_PREBUILT_OTP=true vfox search erlang
USE_PREBUILT_OTP=true vfox install erlang@26.2.3
```

- On macOS the variable only needs to be set. The documented value is `true`.
- Supported architectures are `amd64` (Intel), `x86_64`, `arm64` (Apple silicon) and `aarch64`. Any other architecture stops the install with an unsupported architecture error. `uname -m` shows the architecture of your Mac.
- macOS has its own version list, so `vfox search` shows different names from the Linux list. Branch names end in `-latest`, see [versions.md](versions.md).
- After the archive is unpacked, its files are moved into `<sdk>/release`, the same place a source build uses.

Check the install:

```shell
eval "$(vfox activate bash)"
vfox use -g erlang@26.2.3
erl -version
```

## When it fails

Download errors, names that are not found and unsupported values are covered in [troubleshooting.md](troubleshooting.md).
