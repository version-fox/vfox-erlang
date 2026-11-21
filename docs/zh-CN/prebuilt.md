# 预编译

[中文](prebuilt.md) | [English](../prebuilt.md)

预编译版本不需要编译。设置 `USE_PREBUILT_OTP` 即可选择预编译包：

| 平台 | `USE_PREBUILT_OTP` | 包的来源 |
| --- | --- | --- |
| Linux | Ubuntu 版本号，例如 `ubuntu-22.04` | [builds.hex.pm](https://builds.hex.pm)（Bob） |
| macOS | `true` | [erlef/otp_builds](https://github.com/erlef/otp_builds) |
| Windows | 忽略 | 官方安装器，见 [Windows](windows.md) |

## 安装之前

使用预编译版本前，先关闭 vfox 的搜索缓存。vfox 每个插件只保存一份搜索缓存，而且这份缓存与 `USE_PREBUILT_OTP` 无关。如果之前缓存了正式版本列表，它会把预编译的名字挡住。

```shell
vfox config cache.availableHookDuration 0
```

`0` 表示不缓存。用完之后可以恢复默认值：`vfox config cache.availableHookDuration 12h`。也可以直接删除 `~/.vfox/plugin/erlang/.available.cache`。

## Linux（Bob）

```shell
USE_PREBUILT_OTP=ubuntu-22.04 vfox search erlang
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@26.2.3
```

`USE_PREBUILT_OTP` 只能取以下值之一：

- `ubuntu-14.04`
- `ubuntu-16.04`
- `ubuntu-18.04`
- `ubuntu-20.04`
- `ubuntu-22.04`
- `ubuntu-24.04`

选择与你的 Ubuntu 版本一致的值。只接受 Ubuntu 的取值，其他发行版请使用源码构建。`vfox search` 会读取 Bob 为所选发行版和本机架构发布的 `builds.txt` 索引，列出安装时可以下载的构建。

下载地址的格式如下：

```
https://builds.hex.pm/builds/otp/<arch>/<USE_PREBUILT_OTP>/<name>.tar.gz
```

- `<arch>` 是 vfox 报告的架构，x86-64 上为 `amd64`。
- 正式版本会自动加上 `OTP-` 前缀：`26.2.3` 下载的是 `OTP-26.2.3.tar.gz`。已经带前缀的名字，例如 `OTP-26.2.3`，按原样使用。
- 分支名按原样使用，例如 `maint-27` 和 `master`。

压缩包解压后，插件会在安装目录中执行 OTP 自带的 `Install` 脚本（`./Install -cross -sasl`）。

分支版本：

```shell
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@maint-27
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@master
```

## macOS（erlef/otp_builds）

```shell
USE_PREBUILT_OTP=true vfox search erlang
USE_PREBUILT_OTP=true vfox install erlang@26.2.3
```

- 在 macOS 上只需要设置这个变量，文档中统一使用 `true`。
- 支持的架构为 `amd64`（Intel）、`x86_64`、`arm64`（Apple 芯片）和 `aarch64`。其他架构会在安装时报不支持该架构的错误。`uname -m` 可以查看你的 Mac 是哪种架构。
- macOS 使用独立的版本列表，所以 `vfox search` 显示的名字与 Linux 不同。分支名以 `-latest` 结尾，见 [版本](versions.md)。
- 压缩包解压后，文件会被移入 `<sdk>/release`，与源码构建的位置相同。

检查安装结果：

```shell
eval "$(vfox activate bash)"
vfox use -g erlang@26.2.3
erl -version
```

## 出错时

下载失败、找不到版本名和取值不合法等问题，见 [问题排查](troubleshooting.md)。
