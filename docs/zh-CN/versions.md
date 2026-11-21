# 版本

[中文](versions.md) | [English](../versions.md)

本页介绍版本名、搜索、安装、切换版本和分支版本。各平台的安装方式见 [源码构建](source-build.md)、[预编译](prebuilt.md) 和 [Windows](windows.md)。

## 版本名

版本名就是去掉 `OTP-` 前缀的 Erlang/OTP 版本号。下载时插件会给 GitHub 标签加上这个前缀：`erlang@26.2.3` 对应的标签是 `OTP-26.2.3`。

| 类型 | 示例 | 安装方式 |
| --- | --- | --- |
| 正式版本 | `26.2.3` | Linux 和 macOS（源码构建或预编译）、Windows |
| Windows 正式版本 | `25.3.2.12` | Windows，使用 Windows 安装器的四段版本号 |
| 分支或维护版本 | `master`、`maint-27` | Linux 和 macOS（源码构建或预编译），不支持 Windows |

- Linux 预编译列表中，正式版本也会以 `OTP-26.2.3` 的形式出现。两种写法在 `vfox install` 中都可以使用。
- macOS 预编译的分支名以 `-latest` 结尾：`master-latest`、`maint-latest` 和 `maint-27-latest`。
- Windows 上，正式版本从 [Erlang/OTP releases](https://github.com/erlang/otp/releases) 页面上 `OTP-<版本号>` 标签下发布的安装器安装。

## 搜索

```shell
vfox search erlang
```

列表取决于当前模式：

- 未设置 `USE_PREBUILT_OTP` 时，列表是插件自带的正式版本列表。
- 设置了 `USE_PREBUILT_OTP` 时，列表是该平台的预编译列表：Linux 上是所选 Ubuntu 发行版的列表，macOS 上是 macOS 预编译列表。见 [预编译](prebuilt.md)。

vfox 默认缓存搜索结果 12 小时。如果列表看起来过旧，见 [问题排查](troubleshooting.md)。

## 安装

```shell
vfox install erlang@26.2.3
vfox install erlang@25.3.2.12     # Windows
vfox install erlang@master        # 分支，在 Linux 或 macOS 上源码构建
```

设置了 `USE_PREBUILT_OTP` 时，分支名也可以作为预编译版本安装（见下文的分支和维护版本一节）。

安装过程取决于平台和 `USE_PREBUILT_OTP`。见 [源码构建](source-build.md)、[预编译](prebuilt.md) 和 [Windows](windows.md)。

## 切换版本

```shell
eval "$(vfox activate bash)"
vfox use erlang@26.2.3          # 当前 Shell 会话
vfox use -g erlang@26.2.3       # 全局，对之后新开的 Shell 生效
vfox use -p erlang@26.2.3       # 当前项目
```

| 作用域 | 参数 | 效果 |
| --- | --- | --- |
| 会话 | `-s`（Linux 和 macOS 的默认值） | 仅当前 Shell |
| 全局 | `-g`（Windows 的默认值） | 所有 Shell，除非被更小的作用域覆盖 |
| 项目 | `-p` | 当前项目目录 |

项目作用域会把版本写入 `.vfox.toml` 的 `[tools]` 表，形如 `erlang = "26.2.3"`。vfox 还会在该目录下创建 `.vfox/` 目录；如果 `.gitignore` 存在，会在其中加入 `.vfox/`。

查看当前生效的版本：

```shell
vfox current erlang
erl -version
```

## 已安装的版本

```shell
vfox list erlang
vfox uninstall erlang@26.2.3
```

对链接的版本（见 [链接已安装的 Erlang/OTP](link.md)）执行 `vfox uninstall`，只会从列表中移除链接，链接指向的 Erlang/OTP 仍保留在机器上。

## 分支和维护版本

`master`、`maint-27` 这样的分支名，安装时得到的是该分支当时的内容。因此同一个名字在不同时间安装，得到的构建可能不同。

- 源码构建（Linux 和 macOS 的默认方式）从 Erlang/OTP 仓库下载该分支。可用的名字是 `master`、`maint` 和 `maint-<数字>`，例如 `maint-27`。
- 预编译使用预编译服务器列出的名字。Linux 上就是同一个名字；macOS 上以 `-latest` 结尾。

```shell
# Linux 或 macOS 上的源码构建
vfox install erlang@master
vfox install erlang@maint-27

# Linux 预编译
USE_PREBUILT_OTP=ubuntu-22.04 vfox install erlang@maint-27

# macOS 预编译
USE_PREBUILT_OTP=true vfox install erlang@maint-27-latest
```

Windows 不提供分支名。预编译搜索需要的缓存设置见 [预编译](prebuilt.md)。
