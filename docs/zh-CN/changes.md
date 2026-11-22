# 变更记录

[中文](changes.md) | [English](../changes.md)

本文件记录 1.2.3 之后的变化。已发布版本的发布说明以 [GitHub Releases](https://github.com/version-fox/vfox-erlang/releases) 为准。

## 未发布

暂无变更。

## 1.2.3

### 修复

- 在 Linux 上把 `USE_PREBUILT_OTP` 设为不支持的值（例如 `ubuntu-99.04`）时，`vfox install` 只报告该值的错误。之前它先报告「无法读取版本列表」，然后 `PreInstall` 又报告一次相同的错误。
- 名字以 `latest` 结尾、且版本列表中没有的版本，会在下载之前被拒绝，与其他不在列表中的名字相同。只有 macOS 分支名 `master-latest`、`maint-latest` 和 `maint-<number>-latest` 会跳过列表检查。之前 `erlang@foo-latest` 会先从 GitHub 下载，然后才失败。
- 源码构建在安装路径包含空格时，会在 `configure` 启动之前停止。OTP 的 `configure` 会执行一条未加引号的 `cd ${PWD}`，空格会让它的时间戳检查失败。1.2.1 中「路径含空格时也能正常工作」的记录只对预编译安装成立。请把 `VFOX_HOME` 设为不含空格的路径。
- 安装失败时的提示写作「required utilities」，之前拼写为「required utilties」。

### 变更

- 搜索缓存有效时，`vfox search` 会显示缓存的列表，无论 `USE_PREBUILT_OTP` 是什么值。缓存有效期间 vfox 不会调用插件，因此插件无法检查该值。在 Linux 上，`vfox install` 仍会检查它。见 [prebuilt.md](prebuilt.md)。

## 1.2.2

### 修复

- `vfox install` 在下载之前拒绝版本列表中没有的版本名，例如 `erlang@28` 或 `erlang@OTP-99.9`。报错信息会指向 `vfox search erlang`。分支（`master`、`maint-27` 以及以 `-latest` 结尾的名字）不在列表中，不做检查。无法读取列表时，安装会在没有检查的情况下继续。正式版本列表和 macOS 列表每周更新一次，在上次更新之后发布的版本，列表包含它之前会被拒绝。
- `vfox link --detect erlang` 只列出 `bin/erl` 能够运行的安装。之前 `erl` 不可执行的安装会被列出，然后链接失败。
- 源码构建在安装路径包含单引号、双引号、美元符号或反引号时，会在 `configure` 之前停止。OTP 的 `configure` 无法处理这些字符；单引号会让构建在约半分钟后失败。请把 `VFOX_HOME` 设为其他路径。

## 1.2.1

### 新增

- 双语文档网站，源文件位于 `website/`，通过 GitHub Pages 发布。见 [website/README.md](../../website/README.md)。
- 面向 mise 用户的端到端工作流（Linux 和 macOS），通过 mise 的 vfox 后端安装。见 [mise](mise.md)。
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

- 发布使用共享的插件工作流：在默认分支上打开 **Actions → Plugin → Run workflow**，或推送版本号与 `metadata.lua` 一致的 `v*` 标签。Pull Request 的标题不再触发发布。见 [发布](development.md#发布)。
- Windows 安装器调用去掉了只属于 PowerShell 的 `-Wait -PassThru` 参数。
- README 与文档重写为中英双语。
- `metadata.lua` 插件描述中的拼写错误 `Uinx` 改为 `Unix`。
- 设置 `USE_PREBUILT_OTP` 后，Windows 的版本列表不再变化；Windows 始终使用官方安装器。
- Linux 上设置 `USE_PREBUILT_OTP` 后，`vfox search` 在搜索时读取 Bob 为所选发行版和本机架构发布的 `builds.txt` 索引，不再使用每周生成的列表，因此 arm64 机器看到的是 arm64 的构建。
- Linux 上设置 `USE_PREBUILT_OTP` 后，`vfox search` 像其他列表一样显示不带 `OTP-` 前缀的正式版，例如 `29.1.2`。两种写法安装的是同一个构建。
- Linux 上设置 `USE_PREBUILT_OTP` 后，无论输入哪种写法，安装名都是 `29.1.2`，因此安装另一种写法时会提示已安装。以 1.2.0 或更早版本安装的 `OTP-29.1.2` 保留原名；`vfox install` 不认得它，会重新安装同一版本。

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
