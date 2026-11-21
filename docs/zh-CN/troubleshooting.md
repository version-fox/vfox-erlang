# 问题排查

[中文](troubleshooting.md) | [English](../troubleshooting.md)

每一条都给出症状、用来检查的命令和修复方法。请在出问题的那个 Shell 中执行这些命令。

## 源码构建在 configure、make 或文档步骤失败

症状：`vfox install` 在 `./configure`、`make` 或 `make docs` 处停止，并报错，例如缺少 curses 或 OpenSSL 库。

检查：

```shell
# 保存完整输出，找到第一个错误
vfox install erlang@26.2.3 2>&1 | tee /tmp/otp-build.log
grep -n -i "error" /tmp/otp-build.log | head -n 20

# Linux：构建需要的工具和头文件
command -v gcc make autoconf m4 xsltproc
ls /usr/include/ncurses.h /usr/include/openssl/ssl.h

# macOS：Homebrew 软件包
brew list --versions autoconf libxslt fop wxwidgets openssl@3
```

修复：

- 安装 [源码构建](source-build.md) 中列出的软件包，然后重新安装。如果 vfox 仍然列出该版本，先用 `vfox uninstall erlang@26.2.3` 卸载它。
- 在 macOS 上，如果 `configure` 找不到 OpenSSL，把它指向 Homebrew 中的版本：`export OTP_CONFIGURE_ARGS="--with-ssl=$(brew --prefix openssl@3)"`。
- 如果怀疑是 `OTP_CONFIGURE_ARGS` 的问题，在源码目录（即 `<sdk>`）中执行 `./configure --help`。`vfox info erlang@26.2.3` 会显示该路径。

## 预编译安装返回 404，或找不到版本

症状：下载返回 HTTP 404，或者你输入的版本不在 `vfox search` 的列表中。

检查：

```shell
# Linux：安装包是否存在？amd64 是 vfox 对 x86-64 使用的架构名
curl -sI https://builds.hex.pm/builds/otp/amd64/ubuntu-22.04/OTP-26.2.3.tar.gz | head -n 1

# Linux：Bob 为这个 Ubuntu 版本提供了哪些版本？
curl -s https://builds.hex.pm/builds/otp/ubuntu-22.04/builds.txt | grep 26.2.3

# 插件列出的是哪些名字？
USE_PREBUILT_OTP=ubuntu-22.04 vfox search erlang | grep 26.2.3
```

安装包存在时，返回的状态码是 200。

修复：

- 使用与当前 `USE_PREBUILT_OTP` 取值一致的 `vfox search` 中的名字。正式版本不带 `OTP-`，插件下载时会自动加上。
- 如果 `builds.txt` 中没有该版本，说明 Bob 没有为这个 Ubuntu 版本构建它。换一个版本，或取消设置 `USE_PREBUILT_OTP`，改用源码构建。
- 在 macOS 上，分支名以 `-latest` 结尾，例如 `maint-27-latest`。
- 如果列表中有该名字但仍然下载失败，搜索列表可能已过期，见 [搜索列表过旧](#搜索列表过旧)。

## USE_PREBUILT_OTP 取值不合法

症状：在 Linux 上，安装在报错后停止，错误信息为 `USE_PREBUILT_OTP must be one of: ubuntu-14.04, ubuntu-16.04, ubuntu-18.04, ubuntu-20.04, ubuntu-22.04, ubuntu-24.04. Got: ...`。

检查：

```shell
echo "$USE_PREBUILT_OTP"
uname -m     # macOS 上，x86_64（Intel）和 arm64（Apple 芯片）都受支持
```

修复：

- Linux：使用 `ubuntu-14.04`、`ubuntu-16.04`、`ubuntu-18.04`、`ubuntu-20.04`、`ubuntu-22.04` 或 `ubuntu-24.04` 之一。`true` 在 Linux 上不合法。
- macOS：设置 `USE_PREBUILT_OTP=true`。如果安装报告不支持该架构，说明这台 Mac 的架构不是 `amd64`、`x86_64`、`arm64` 或 `aarch64`。
- Windows 会忽略这个变量。

## Windows 安装器失败

症状：下载完成后，`vfox install` 报告 Erlang/OTP 安装失败。

检查（PowerShell）：

```pwsh
# 查看 vfox 把安装器放在哪里：使用 vfox info 输出的路径
vfox info erlang@25.3.2.12
Get-ChildItem -Path "<sdk>" -Filter "otp_win*.exe"

# 安装器能否下载？
Invoke-WebRequest -Method Head -UseBasicParsing -Uri "https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe" | Select-Object StatusCode
```

把 `<sdk>` 替换为 `vfox info` 输出的路径。

修复：

- 双击同一个 `.exe`，查看安装器自己的提示。静默安装会隐藏这些信息。
- 如果状态码不是 200，说明下载被阻止，或该版本没有安装器。检查网络，见 [下载失败或超时](#下载失败或超时)，或者选择发布页面上有安装器的版本。
- 如果 `vfox list erlang` 仍然显示失败的版本，重试前用 `vfox uninstall erlang@25.3.2.12` 删除它。

## link --detect 找不到安装，或命令无法识别

症状：`vfox link --detect erlang` 没有列出任何安装，或者 vfox 不认识 `--detect` 参数。

检查：

```shell
vfox --version                                  # 必须是 1.1.0 或更高
ls /usr/lib/erlang/releases/*/OTP_VERSION       # Debian 和 Ubuntu 软件包的位置
vfox list erlang                                # 已安装和已链接的版本会被跳过
```

修复：

- 用 `vfox upgrade` 把 vfox 升级到 1.1.0 或更高版本。其他安装方法见 [vfox 快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。
- 如果安装位于扫描范围之外，手动链接：`vfox link erlang@26.2.3 /path/to/otp`。见 [链接已安装的 Erlang/OTP](link.md)。
- 路径中含有 `.vfox` 目录的，永远不会被扫描。
- 如果上面的 `OTP_VERSION` 检查没有输出，说明该目录不是 Erlang/OTP 安装。

## 搜索列表过旧

症状：`vfox search erlang` 没有显示已经发布的版本，或者仍然显示你修改 `USE_PREBUILT_OTP` 之前的列表。

检查：

```shell
vfox config cache.availableHookDuration     # 缓存时间，默认 12h
ls -l ~/.vfox/plugin/erlang/.available.cache
```

修复：

```shell
vfox config cache.availableHookDuration 0   # 工作期间不缓存
rm -f ~/.vfox/plugin/erlang/.available.cache
vfox search erlang
```

- 用完之后，用 `vfox config cache.availableHookDuration 12h` 恢复缓存。
- 版本列表由工作流每周更新，并通过 jsDelivr 提供，jsDelivr 自己也有缓存。刚刚发布的版本可能要等到下一次更新才会出现。

## 下载失败或超时

症状：`vfox install` 或 `vfox search` 无法访问 github.com、builds.hex.pm 或 jsDelivr。

检查：

```shell
curl -sI https://github.com | head -n 1
curl -sI https://builds.hex.pm | head -n 1
curl -sI https://fastly.jsdelivr.net | head -n 1
```

修复：如果你的网络需要代理，在 vfox 中设置：

```shell
vfox config proxy.enable true
vfox config proxy.url http://host:port
```

把 `host:port` 换成你的代理地址。格式说明见 [vfox 配置文档](https://vfox.dev/zh-hans/guides/configuration.html)。

## vfox use 提示版本未安装

症状：vfox 已激活时，`vfox use erlang@26.2.3` 停止并报 `Erlang/OTP 26.2.3 is not installed.`。

检查：

```shell
vfox list erlang
```

修复：

- 用 `vfox install erlang@26.2.3` 安装该版本，或用 `vfox link --detect erlang` 链接机器上已有的安装。见 [链接已安装的 Erlang/OTP](link.md)。

## 找不到 erl，或运行的是另一个 erl

症状：`vfox use` 之后找不到 `erl`，或者运行的是另一套 Erlang/OTP。

检查：

```shell
vfox current erlang
command -v erl
vfox doctor erlang
```

修复：

- 先确认已在当前 Shell 中执行 `vfox activate`。没有激活时，`vfox use` 会失败并报 `vfox requires hook support`，`erl` 也不在 `PATH` 中。
- 确认 vfox 已挂载到 Shell：在 `~/.bashrc` 中写入 `eval "$(vfox activate bash)"`，zsh 则在 `~/.zshrc` 中写入对应的一行。见 [vfox 快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。
- 如果 `command -v erl` 显示的路径不在 vfox 目录下，说明有另一个安装排在 `PATH` 的前面。`vfox doctor erlang` 会报告这类问题，`path` 相关的设置见 [vfox 配置文档](https://vfox.dev/zh-hans/guides/configuration.html)。

## 构建成功，但 h(lists). 没有文档

症状：`erl` 能运行，但 `h(lists).` 或 `shell_docs:get_doc(lists)` 没有任何输出。

检查：

```shell
erl -noshell -eval 'erlang:display(shell_docs:get_doc(lists)), halt().' | grep "List processing functions"
```

没有输出说明文档块缺失。

修复：使用默认的 `DOC_TARGETS` 重新安装：

```shell
unset DOC_TARGETS
vfox uninstall erlang@26.2.3
vfox install erlang@26.2.3
```

`DOC_TARGETS` 控制的内容见 [源码构建](source-build.md)。
