# E2E 测试

[中文](e2e.md) | [English](../e2e.md)

端到端（E2E）测试用插件安装真实的 Erlang/OTP 版本，并检查它能否运行。安装测试是最慢的检查，因为源码构建需要很长时间。它们在 `-short` 模式下会被跳过。

## 套件

| 套件 | 定义位置 | 运行环境 | 覆盖内容 |
| --- | --- | --- | --- |
| Linux 源码构建 | `tests/e2e/linux` 中的 `TestLinuxSourceInstall` | `ubuntu-22.04`、`ubuntu-24.04` | 用 `MAKEFLAGS` 设为使用全部 CPU，从源码构建 `E2E_ERLANG_VERSION`，运行 `erl`，用 `erlc` 编译并运行 `assets/hello.erl`，并检查文档块 |
| Linux 预编译 | `tests/e2e/linux` 中的 `TestLinuxPrebuiltInstall` | `ubuntu-22.04`、`ubuntu-24.04` | 用 `USE_PREBUILT_OTP` 安装对应 Ubuntu 版本的 Bob 包，使用数字版本以覆盖 `OTP-` 前缀，并检查版本 |
| Linux 系统 SDK | `tests/e2e/linux` 中的 `TestLinuxSystemDetect` | `ubuntu-22.04`、`ubuntu-24.04` | 用 `vfox link --detect` 链接 `erlang-base` 软件包安装在 `/usr/lib/erlang` 中的 Erlang/OTP，运行它，并检查卸载链接后系统安装仍然保留 |
| Windows 安装器 | `tests/e2e/windows` 中的 `TestWindowsOfficialInstaller` | `windows-2022`、`windows-2025` | 通过插件安装 25.3.2.12（插件会运行官方安装器），然后检查 `erl.exe`、`erlc.exe` 和文档块 |
| Windows 系统 SDK | `tests/e2e/windows` 中的 `TestWindowsSystemDetect` | `windows-2022`、`windows-2025` | 把 26.2.3 的官方安装器安装到 `%ProgramFiles%`，用 `vfox link --detect` 链接它，并检查卸载链接后安装目录仍然保留 |
| Darwin 源码构建 | `.github/workflows/e2e_test_darwin.yaml` | `macos-latest` | 在 macOS 上从源码构建，运行 `erlc` 和 `erl`，并显示 `lists` 的文档 |
| Darwin 预编译 | `.github/workflows/e2e_test_darwin_prebuilt.yaml` | `macos-latest` | 用 `USE_PREBUILT_OTP=true` 安装 erlef/otp_builds 的包，然后运行 `erlc` 和 `erl` |
| Darwin mise | `.github/workflows/e2e_test_darwin_mise.yaml` | `macos-latest` | 通过 mise 的 vfox 后端安装，见 [mise](mise.md) |
| Linux mise | `.github/workflows/e2e_test_linux_mise.yaml` | `ubuntu-24.04` | 通过 mise 的 vfox 后端安装，并检查文档块是否存在，见 [mise](mise.md) |

在 `e2e.yml` 中，Linux 任务先运行源码构建和预编译测试，然后安装 `erlang-base`，并以 `E2E_REQUIRE_SYSTEM_ERLANG=1` 运行系统测试。这样，系统安装缺失会让任务失败，而不是跳过测试。Windows 任务运行 `TestWindows`，它包含两个 Windows 测试。

## Go 套件

这些套件是 `tests/e2e` 中的 Go 测试。`common` 包含共享的辅助代码，`linux` 和 `windows` 包含各平台的套件。辅助代码有自己的单元测试。`go test -short ./...` 在不安装 Erlang/OTP 的情况下运行这些测试，Test Plugin 工作流运行的就是它。

## 在 Docker 中运行 Linux 套件

需要 Docker。镜像由 `tests/e2e/linux/Dockerfile` 构建。镜像中有构建工具和 vfox 1.1.0，但没有 Erlang/OTP；运行容器时，仓库以只读方式挂载进去。在仓库根目录执行：

```shell
docker build -t vfox-erlang-e2e:22.04 --build-arg UBUNTU_VERSION=22.04 tests/e2e/linux
docker run --rm -v "$PWD:/src:ro" -e E2E_REQUIRE_SYSTEM_ERLANG=1 vfox-erlang-e2e:22.04 sh -c 'apt-get update && apt-get install -y erlang-base && cd /src/tests/e2e && go test -v -timeout 90m -run TestLinux ./linux'
```

命令会安装 `erlang-base`，让系统测试有一份可以找到的安装。命令结束后容器会被删除。`TestLinux` 也会运行源码构建，这需要很长时间。

要缩短运行时间，用 `-run` 选择单个测试，例如 `-run 'TestLinuxSourceInstall'`。测试名称位于 `tests/e2e/linux` 包中。

Dockerfile 会按 Ubuntu 版本选择 wxWidgets 软件包：22.04 使用 `libwxgtk3.0-*`，24.04 使用 `libwxgtk3.2-*`。构建 24.04 镜像时加上 `--build-arg UBUNTU_VERSION=24.04`，并使用标签 `vfox-erlang-e2e:24.04`；`docker run` 命令相同，只需换成这个标签。

## Windows

Windows 套件只在 CI 的 Windows 运行环境（`windows-2022` 和 `windows-2025`）上运行。Docker 和 WSL2 无法运行 Windows 容器，因此无法在这些环境中复现。在 Windows 机器上，从 `tests/e2e` 运行：

```pwsh
cd tests/e2e
go test -v -timeout 90m -run TestWindows ./windows
```

除非 `VFOX_BIN` 指定了另一个可执行文件，否则 vfox 从 `PATH` 中查找。系统测试会把 Erlang/OTP 安装到 `%ProgramFiles%`。如果那里已经存在 Erlang/OTP 目录，它会拒绝运行，因此不会覆盖已有的安装。

## 环境变量

| 变量 | 默认值 | 含义 |
| --- | --- | --- |
| `E2E_ERLANG_VERSION` | `26.2.3` | Linux 套件安装的版本。Windows 套件使用固定版本 25.3.2.12 和 26.2.3 |
| `E2E_PREBUILT_OS` | `/etc/os-release` 中的 `VERSION_ID`；在 22.04 和 24.04 以外的版本上，测试会被跳过 | 预编译套件使用的 Ubuntu 版本，例如 `ubuntu-22.04` |
| `E2E_REQUIRE_SYSTEM_ERLANG` | 未设置 | 设为 `1` 时，找不到系统 Erlang/OTP 会让 Linux 系统测试失败；否则测试被跳过 |
| `E2E_REPO` | 从当前目录向上查找得到的插件根目录 | 插件根目录，其中包含 `metadata.lua` 和 `hooks/`。CI 和 Docker 镜像会设置它 |
| `VFOX_BIN` | `PATH` 中的 `vfox` | 被测试的 vfox 可执行文件 |
