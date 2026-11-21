# Windows

[中文](windows.md) | [English](../windows.md)

在 Windows 上，插件不会编译 Erlang/OTP。它会从 [Erlang/OTP releases](https://github.com/erlang/otp/releases) 页面下载官方安装器，并以静默方式把它安装到 vfox 为该版本管理的目录中。

## 安装过程

- 在 x86-64（`amd64`）机器上，`erlang@25.3.2.12` 会下载 `https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe`。
- 其他架构使用 32 位安装器 `otp_win32_<版本号>.exe`。
- 安装器以 `/S`（静默）和 `/D=<sdk>\release` 运行，因此 Erlang/OTP 被安装到 `<sdk>\release`。
- 插件把 `<sdk>\release\bin` 加入 `PATH`。

## 在 PowerShell 中安装和激活

```pwsh
vfox install erlang@25.3.2.12
Invoke-Expression "$(vfox activate pwsh)"
vfox use -g erlang@25.3.2.12

# 检查安装结果
& erl.exe -eval 'erlang:display({otp_release, erlang:system_info(otp_release)}), halt().' -noshell
```

`Invoke-Expression "$(vfox activate pwsh)"` 需要在每个 PowerShell 会话中执行。要让每个会话都生效，把它写入 profile：

```pwsh
if (-not (Test-Path -Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }; Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'
```

同时检查文档块：

```pwsh
& erl.exe -eval 'erlang:display(shell_docs:get_doc(lists)), halt().' -noshell
```

## 版本

版本号使用发布页面上的写法，例如 `25.3.2.12`。这个名字必须对应 `OTP-<版本号>` 标签下的安装器 `otp_win64_<版本号>.exe`（或 `otp_win32_<版本号>.exe`）。

Windows 不提供 `master`、`maint-27` 这样的分支名。

## 已有的安装

如果 Erlang/OTP 是在 vfox 之外用官方安装器装的，`vfox link --detect erlang` 可以直接使用那份安装，而不用再装一份。见 [链接已安装的 Erlang/OTP](link.md)。

## 出错时

如果安装器这一步失败，见 [问题排查](troubleshooting.md)。
