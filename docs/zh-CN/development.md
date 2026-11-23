# 开发

[中文](development.md) | [English](../development.md)

本页面向修改插件的人：说明钩子的工作方式、代码的位置、需要运行的检查，以及发布流程。

## 插件的工作方式

vfox 会调用 `hooks/` 中的钩子：

| 钩子 | 文件 | 作用 |
| --- | --- | --- |
| `Available` | `hooks/available.lua` | 为 `vfox search` 返回版本列表：`assets/versions.txt`；设置了 `USE_PREBUILT_OTP` 时，返回 Bob 为所选 Ubuntu 发行版列出的构建（读取本机架构的 `builds.txt` 索引），或 macOS 预编译列表。`versions.txt` 与 macOS 列表通过 jsDelivr 读取。 |
| `PreInstall` | `hooks/pre_install.lua` | 检查是否给出了版本号；除分支名（`master`、`maint`、`maint-<数字>`，以及在 macOS 上设置了 `USE_PREBUILT_OTP` 时的 `-latest` 分支名，如 `master-latest`）外，还检查版本列表中是否有该版本。然后返回下载地址；对于 Linux 预编译构建，还返回 `builds.txt` 为它列出的 SHA-256（如果有）。Windows 使用官方安装器。设置了 `USE_PREBUILT_OTP` 时，Linux 使用 Bob 的包，macOS 使用 erlef/otp_builds 的包。其他版本使用 GitHub 源码压缩包：正式版本取标签 `OTP-<版本号>`，`master`、`maint` 和 `maint-<数字>` 取对应的分支。 |
| `PostInstall` | `hooks/post_install.lua` | 处理下载的内容。Windows 运行安装器；Linux 预编译包运行 OTP 自带的 `Install` 脚本；macOS 预编译包的文件被移入 `release/`；源码压缩包会先检查安装路径：路径中含有空格、制表符、换行符、单引号、双引号、美元符号或反引号时拒绝安装。否则依次配置、构建、安装，并构建、安装文档块。 |
| `EnvKeys` | `hooks/env_keys.lua` | 把 `PATH` 设为 `release/bin`、`bin` 和 `lib/erlang/bin` 中第一个包含 `erl`（Windows 上为 `erl.exe`）的目录。目录是通过查找可执行文件找到的，所以源码构建、预编译安装和链接的安装都能工作。 |
| `PreUse` | `hooks/pre_use.lua` | 检查要使用的版本已经安装，并返回该版本。否则报错，并提示使用 `vfox install` 或 `vfox link --detect`。 |
| `Detect` | `hooks/detect.lua` | 扫描 [链接已安装的 Erlang/OTP](link.md) 中列出的位置，为 `vfox link --detect` 找出已有的安装。扫描代码在 `lib/detect_erlang.lua` 中。 |

## 文件结构

```
hooks/           vfox 钩子，每个钩子一个文件
lib/             共享的 Lua 辅助代码：erlang_utils.lua 和 detect_erlang.lua
tests/           离线 Lua 测试（tests/*_test.lua）和 Go 端到端套件（tests/e2e）
assets/          版本列表、hello.erl、get_all_otp_versions.py、图标和图片
website/         中英双语文档网站及其构建脚本
docs/            本文档；docs/zh-CN/ 存放中文页面
metadata.lua     插件名、版本、最低 vfox 版本（minRuntimeVersion）和 manifest 地址
Injection.lua    vfox 注入对象（如 RUNTIME）的类型提示，仅供编辑器使用，不要修改
.luarc.json      LuaLS 设置：Lua 5.1，以及全局变量 PLUGIN 和 RUNTIME
.licenserc.yaml  许可证头规则，许可证头文本定义在这里
stylua.toml      Lua 格式：120 列、4 个空格、LF 换行、优先使用双引号
ruff.toml        Python 检查和格式设置
```

## 检查

推送之前，先运行 CI 会运行的检查。除非命令中写了 `cd`，否则都在仓库根目录执行。

| 检查 | 命令 | 工作流 |
| --- | --- | --- |
| Lua 格式 | `stylua --check .` | Lint |
| Lua 类型 | `lua-language-server --check . --checklevel=Warning`（CI 通过 mise 运行 LuaLS 3.19.1） | Lint |
| 离线 Lua 测试 | 使用 vfox 1.1.0 运行 `vfox plugin test .`。每个 `tests/*_test.lua` 在各自的虚拟机中运行。 | Test Plugin |
| Go 格式 | `cd tests/e2e && gofmt -l .`（无输出表示所有文件格式正确） | Lint |
| Go vet | `cd tests/e2e && go vet ./... && GOOS=windows go vet ./...` | Lint |
| Go 单元测试 | `cd tests/e2e && go test -short ./...` | Test Plugin |
| Python | `ruff check .` 和 `ruff format --check .`（CI 固定 ruff 0.17.6） | Lint |
| 工作流文件 | `actionlint`（CI 固定 actionlint 1.7.12） | Lint |
| 许可证头 | `license-eye header check` | License |

CI 用下面的命令安装工具：`go install github.com/version-fox/vfox@v1.1.0` 和 `go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12`。端到端套件在 E2E 工作流中运行，见 [E2E 测试](e2e.md)。

## 添加文件

源码文件需要 `.licenserc.yaml` 中定义的 Apache 许可证头。Markdown 和 JSON 文件不做检查。安装许可证工具：

```shell
go install github.com/apache/skywalking-eyes/cmd/license-eye@latest
```

然后运行 `license-eye header check` 找出缺少许可证头的文件，或运行 `license-eye header fix` 为它们添加许可证头。

## 在 vfox 中试用改动

`vfox plugin test .` 会针对工作区运行离线测试。要在 vfox 中把某个分支安装为插件，先把分支推送到 GitHub，再用它的压缩包地址添加，E2E 工作流也是这样做的。如果插件已经添加过，先移除：

```shell
vfox remove erlang
vfox add --source https://github.com/version-fox/vfox-erlang/archive/refs/heads/<branch>.zip erlang
```

## 版本列表

`assets/versions.txt`、`assets/macos_prebuilt_versions.txt` 和 `assets/prebuilt_versions.txt` 由 `assets/get_all_otp_versions.py` 生成。脚本从 GitHub API 读取标签，从 erlef/otp_builds 的发布中读取 macOS 列表，并从 Bob 的 ubuntu-20.04 `builds.txt` 生成 `prebuilt_versions.txt`。Linux 预编译搜索不使用生成的列表，而是直接读取 `USE_PREBUILT_OTP` 所指发行版的 `builds.txt` 索引。`prebuilt_versions.txt` 为早于这一改动的插件版本保留。`update_otp_versions` 工作流每周运行一次该脚本，并提交结果。

## 网站

在本地构建文档网站：

```shell
python3 website/build.py --output /tmp/vfox-erlang-site
python3 -m http.server 8080 --directory /tmp/vfox-erlang-site
```

中文页面在 `http://localhost:8080/`，英文页面在 `http://localhost:8080/en/`。构建时从 `metadata.lua` 读取插件版本和最低 vfox 版本。GitHub Pages 工作流会为 Pull Request 构建网站、部署 `main`，并在发布成功后刷新网站。见 [website/README.md](../../website/README.md)。

## 发布

维护者从 Actions 页面发布：

1. 在默认分支上打开 **Actions → Plugin → Run workflow**。
2. 输入不带 `v` 前缀的稳定插件版本号，格式为 `X.Y.Z`。

共享工作流会更新 `metadata.lua`，创建版本提交和标签，并在本仓库中发布 ZIP 和 manifest。不需要本地标签，也不需要额外的发布令牌。

- Pull Request 只运行检查，PR 标题不会触发发布。
- 推送 `v*` 标签同样可以发布，前提是 `metadata.lua` 中的 `PLUGIN.version` 已经与标签一致。
- 发布失败时，重新运行原来失败的任务即可继续。
- 工作流使用 [version-fox/plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action) 的共享 `@v1` 发布工具。更新该工具并不会发布本插件。包的约定和首次上线的要求记录在同一仓库中。

## 其他工作流

| 工作流 | 文件 | 作用 |
| --- | --- | --- |
| E2E | `e2e.yml` | Linux 与 Windows 端到端套件，见 [E2E 测试](e2e.md) |
| E2E（macOS 与 mise） | `e2e_test_darwin.yaml`、`e2e_test_darwin_prebuilt.yaml`、`e2e_test_darwin_mise.yaml`、`e2e_test_linux_mise.yaml` | macOS 与 mise 套件，见 [E2E 测试](e2e.md) |
| Plugin | `publish.yaml` | 发布，见上文 |
| GitHub Pages | `pages.yaml` | 文档网站 |
| update_otp_versions | `update_otp_versions.yaml` | 每周更新版本列表 |
