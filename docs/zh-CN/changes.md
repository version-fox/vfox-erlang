# 变更记录

[中文](changes.md) | [English](../changes.md)

本文件记录 1.2.0 之后的变化。已发布版本的发布说明以 [GitHub Releases](https://github.com/version-fox/vfox-erlang/releases) 为准。

## 未发布

### 新增

- 通过 `Detect` 钩子和 `vfox link --detect` 扫描系统中已安装的 Erlang/OTP，需要 vfox 1.1.0 或更高版本。见 [链接已安装的 Erlang/OTP](link.md)。
- 用 Go 编写的 Ubuntu 与 Windows 端到端套件，以及 Linux 测试容器（`tests/e2e/linux/Dockerfile`）。见 [E2E 测试](e2e.md)。
- Lua 离线单元测试（`tests/*_test.lua`）。
- lint 与格式检查工作流（stylua、LuaLS、gofmt、go vet、ruff、actionlint）、离线测试工作流，以及许可证头检查工作流（SkyWalking Eyes）。
- Dependabot 对 GitHub Actions 版本的自动更新，以及 stylua、ruff、LuaLS 的配置（`stylua.toml`、`ruff.toml`、`.luarc.json`）。
- `docs/` 与 `docs/zh-CN/` 下的双语文档。
- `opencode.jsonc` 中的权限放行。
- `.gitattributes`（统一使用 LF 换行）。
- Linux 的 `USE_PREBUILT_OTP` 接受 `ubuntu-26.04`。Bob 为 amd64 和 arm64 发布了它的 OTP 构建。

### 变更

- Windows 安装器调用去掉了只属于 PowerShell 的 `-Wait -PassThru` 参数。
- README 与文档重写为中英双语。
- `metadata.lua` 插件描述中的拼写错误 `Uinx` 改为 `Unix`。
- 设置 `USE_PREBUILT_OTP` 后，Windows 的版本列表不再变化；Windows 始终使用官方安装器。
- Linux 上设置 `USE_PREBUILT_OTP` 后，`vfox search` 在搜索时读取 Bob 为所选发行版和本机架构发布的 `builds.txt` 索引，不再使用每周生成的列表，因此 arm64 机器看到的是 arm64 的构建。
- Linux 上设置 `USE_PREBUILT_OTP` 后，`vfox search` 像其他列表一样显示不带 `OTP-` 前缀的正式版，例如 `29.1.2`。两种写法安装的是同一个构建。

### 修复

- Linux 预编译安装数字版本（如 `26.2.3`）时，向 builds.hex.pm 请求的地址缺少 `OTP-` 前缀，返回 404。
- `pre_install` 在版本为空时先拼接字符串，报出的错误不友好。
- `post_install` 的 `print` 把 `%s` 原样输出，并去掉了无意义的 `sleep 3`。
- 源码构建与预编译安装会给安装路径加引号，路径含空格时也能正常工作；Windows 安装器路径同样加了引号。
- `pre_use` 对未安装的版本不做检查，直接崩溃，而不是给出提示。
- 下载版本列表失败时没有错误处理。
- Windows 上 `EnvKeys` 总是把 `release\bin` 放进 `PATH`。链接的系统安装把 `bin` 放在根目录，因此找不到 `erl`。
- `update_otp_versions` 工作流的提交作者名拼接错误，`github-actions[bot]` 重复出现。
- `get_all_otp_versions.py` 只检查了最后一次 GitHub API 响应的状态码。
- 源码构建的 `master` 与 `maint-<N>` 之前从 `refs/tags/` 下载归档，返回 404；现在改为 `refs/heads/`。
- 源码构建时若输入已带 `OTP-` 前缀（如 `OTP-26.2.3`），之前会变成 `OTP-OTP-26.2.3` 并返回 404；现在不再重复添加。
- Linux 上设置 `USE_PREBUILT_OTP` 后，`vfox search` 对每个 Ubuntu 版本都列出 ubuntu-20.04 的构建，因此只存在于较新版本的构建（如 ubuntu-24.04 上的 `OTP-29.1.2`）缺失。现在列表来自所选版本的构建。
- `vfox search` 遇到不支持的 `USE_PREBUILT_OTP` 值（如 `ubuntu-99.04`）时仍会列出构建，而不是报错。现在与 `vfox install` 一样，给出支持的取值。
- 空的 `USE_PREBUILT_OTP` 视为未设置，会从源码构建。
- 设置 `USE_PREBUILT_OTP` 后，在 macOS 或 Linux 上 `vfox install erlang@latest` 会安装一个分支（`master`，macOS 上是 `master-latest`），因为分支名排在列表最前。现在最新的正式版排在最前，其次是候选版，最后是分支。
- `vfox use` 接受已安装版本的另一种写法：以 `OTP-29.1.2` 安装的版本可以用 `29.1.2` 使用，反之亦然，不再报告“未安装”。

### 移除

- 根目录的 `DEVELOPMENT.md`，内容已并入 [开发](development.md)。
- `e2e_test_linux.yaml`、`e2e_test_linux_prebuilt.yaml` 和 `e2e_test_windows.yaml`，由 `e2e.yml` 取代。
