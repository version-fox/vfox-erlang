# 链接已安装的 Erlang/OTP

[中文](link.md) | [English](../link.md)

如果 Erlang/OTP 已经装在机器上，vfox 可以直接使用它，而不必再下载或构建一份。这种把已有安装纳入 vfox 的做法称为链接。插件的 `Detect` 钩子负责找到这些安装，`vfox link` 负责记录它们。

链接需要 vfox 1.1.0 或更高版本。用 `vfox --version` 检查版本。

## 查找并链接安装

```shell
vfox link --detect erlang      # 列出找到的安装，并选择要链接的项
vfox link --detect -y erlang   # 链接找到的全部安装
```

链接之后，像使用已安装的版本一样使用它：

```shell
eval "$(vfox activate bash)"
vfox use erlang@26.2.3
vfox list erlang               # 链接的版本会被标记，并显示路径
```

- 某个位置被视为一个安装，需要它包含 `bin/erl`（Windows 上为 `bin\erl.exe`）和 `releases/<release>/OTP_VERSION` 文件。检查的位置包括它本身，以及它下面的 `lib/erlang` 子目录。在 Linux 和 macOS 上，`bin/erl` 还必须有可执行权限：不能运行的文件不会被列出。
- 版本名取自 `OTP_VERSION` 文件，例如 `26.2.3`。不加任何前缀。
- 多个安装报告了同一个版本时，只提供一个：按版本和路径排序后的第一个。
- vfox 已经安装或链接过的版本会被跳过。
- 路径中含有 `.vfox` 目录的不会被扫描，因为这些是 vfox 自己管理的。

## 扫描的位置

Linux 和 macOS：

| 位置 | 说明 |
| --- | --- |
| `/usr/lib/erlang` | Debian 和 Ubuntu 的 `erlang-base` 软件包 |
| `/usr/local/lib/erlang` | 源码 `make install` 的默认前缀 |
| `/opt/erlang/*` | 其中的每个子目录 |
| `/opt/homebrew/opt/erlang`、`/usr/local/opt/erlang`、`/home/linuxbrew/.linuxbrew/opt/erlang` | Homebrew 的链接；OTP 根目录是其下的 `lib/erlang` |
| `/opt/homebrew/Cellar/erlang/*`、`/usr/local/Cellar/erlang/*`、`/home/linuxbrew/.linuxbrew/Cellar/erlang/*` | Homebrew 中每个版本的目录 |
| `~/.asdf/installs/erlang/*` | asdf |
| `~/.local/share/mise/installs/erlang/*` | mise |

Windows：

| 位置 | 说明 |
| --- | --- |
| `%ProgramFiles%` 和 `%ProgramFiles(x86)%` | 名字以 `Erlang OTP`（含空格）或 `erl` 开头的目录，大小写不敏感 |
| `%USERPROFILE%\.local\share\mise\installs\erlang\*` | mise |

不在这些位置的安装不会被找到，需要按下面的方法手动链接。

## 手动链接

```shell
vfox link erlang@26.2.3 /usr/lib/erlang
```

路径必须是以下两种之一：

- Erlang/OTP 根目录，即包含 `bin` 和 `releases` 的目录；
- 包含 `lib/erlang` 的前缀目录，例如 `/usr/local`。

`erlang@` 后面的名字由你自己决定。像上面这样用 OTP 版本号命名，`vfox use erlang@26.2.3` 就能像平常一样工作。

## 移除链接

```shell
vfox uninstall erlang@26.2.3
```

对链接的版本，这条命令只删除链接，机器上的 Erlang/OTP 不会被删除。

如果没有找到任何安装，或命令无法识别，见 [问题排查](troubleshooting.md)。
