# Windows

[中文](zh-CN/windows.md) | [English](windows.md)

On Windows the plugin does not compile Erlang/OTP. It downloads the official installer from the [Erlang/OTP releases](https://github.com/erlang/otp/releases) page and runs it silently into the directory vfox manages for the version.

## What the install does

- On an x86-64 (`amd64`) machine, `erlang@25.3.2.12` downloads `https://github.com/erlang/otp/releases/download/OTP-25.3.2.12/otp_win64_25.3.2.12.exe`.
- On other architectures the 32-bit installer, `otp_win32_<version>.exe`, is used.
- The installer runs with `/S` (silent) and `/D=<sdk>\release`, so Erlang/OTP is installed in `<sdk>\release`.
- The plugin adds `<sdk>\release\bin` to `PATH`.

## Install and activate in PowerShell

```pwsh
vfox install erlang@25.3.2.12
Invoke-Expression "$(vfox activate pwsh)"
vfox use -g erlang@25.3.2.12

# Check the installation
& erl.exe -eval 'erlang:display({otp_release, erlang:system_info(otp_release)}), halt().' -noshell
```

`Invoke-Expression "$(vfox activate pwsh)"` has to run in each PowerShell session. To run it in every session, add it to your profile:

```pwsh
if (-not (Test-Path -Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }; Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'
```

To check the documentation chunks as well:

```pwsh
& erl.exe -eval 'erlang:display(shell_docs:get_doc(lists)), halt().' -noshell
```

## Versions

Use the version as it is published on the releases page, for example `25.3.2.12`. The name must match an installer `otp_win64_<version>.exe` (or `otp_win32_<version>.exe`) under the tag `OTP-<version>`.

Branch names such as `master` and `maint-27` are not available on Windows.

## Existing installations

If Erlang/OTP was installed with the official installer outside vfox, `vfox link --detect erlang` can use that installation instead of a second copy. See [link.md](link.md).

## When it fails

If the installer step fails, see [troubleshooting.md](troubleshooting.md).
