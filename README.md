<div align="center">

![logo](./assets/vfox-erlang-logo.png)

[![E2E tests on Linux](https://github.com/version-fox/vfox-erlang/actions/workflows/e2e_test_linux.yaml/badge.svg)](https://github.com/version-fox/vfox-erlang/actions/workflows/e2e_test_linux.yaml) [![E2E tests on Darwin MacOS](https://github.com/version-fox/vfox-erlang/actions/workflows/e2e_test_darwin.yaml/badge.svg)](https://github.com/version-fox/vfox-erlang/actions/workflows/e2e_test_darwin.yaml) [![E2E tests on Windows](https://github.com/version-fox/vfox-erlang/actions/workflows/e2e_test_windows.yaml/badge.svg)](https://github.com/version-fox/vfox-erlang/actions/workflows/e2e_test_windows.yaml)

</div>

# vfox-erlang plugin

Erlang/OTP [vfox](https://github.com/version-fox) plugin. Use the vfox to manage multiple [Erlang/OTP](https://www.erlang.org/) versions in Linux/Darwin MacOS/Windows. all platform~

## Usage

```shell
# install plugin
vfox add --source https://github.com/version-fox/vfox-erlang/archive/refs/heads/main.zip erlang

# install an available version
vfox search erlang
# or specific version 
vfox install erlang@25.3.2.10
```

## Before install Erlang/OTP in Linux/Darwin MacOS

vfox-erlang plugin would install Erlang/OTP through the [Erlang/OTP](https://www.erlang.org/doc/installation_guide/install#how-to-build-and-install-erlang-otp) source code compilation. So you must have the utilities mentioned in the document -> [Building and Installing Erlang/OTP](https://www.erlang.org/doc/installation_guide/install#how-to-build-and-install-erlang-otp). 

Here are examples of installing on Ubuntu 20.04 and MacOS 13.

### install in Linux (Ubuntu 20.04/22.04)

```shell
# install utilities
sudo apt-get -y install build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk
```

You can reference the E2E test in Ubuntu 20.04: [.github/workflows/e2e_test_linux.yaml](.github/workflows/e2e_test_linux.yaml)

### install in Darwin (MacOS 13)

```shell
# install utilities
brew install autoconf libxslt fop wxwidgets openssl
```

You can reference the E2E test in MacOS 13: [.github/workflows/e2e_test_darwin.yaml](.github/workflows/e2e_test_darwin.yaml)

### Note

By default, vfox-erlang plugin will Build [EEP-48 documentation chunks](https://www.erlang.org/doc/apps/kernel/eep48_chapter) for get doc in REPL (eg: h(list).) and [lsp docs hint](https://github.com/elixir-lsp/vscode-elixir-ls/issues/284).

![erl get docs](./assets/get_docs_in_repl.png)

You cal also use the `OTP_CONFIGURE_ARGS` environment variable to control install behavior. reference this documentation [https://github.com/erlang/otp/blob/master/HOWTO/INSTALL.md#configuring-1](https://github.com/erlang/otp/blob/master/HOWTO/INSTALL.md#configuring-1) for more configuration. eg:

```shell
# example
export OTP_CONFIGURE_ARGS="--enable-jit --enable-kernel-poll"
vfox install erlang@25.3.2.10
```

Building Erlang/OTP on a relatively fast computer takes approximately 5 minutes. To speed it up, you can utilize [parallel make](https://github.com/erlang/otp/blob/master/HOWTO/INSTALL.md#building-3) with the `-j<num_jobs>` option. for example:

```shell
export MAKEFLAGS=-j8
vfox install erlang@25.3.2.10
```

## install Erlang/OTP in Windows platform

In windows, the vfox-erlang plugin downloads the Erlang/OTP version of the exe installer from the [Erlang/OTP releases](https://github.com/erlang/otp/releases) and executes it for you.

This is an installation example in PowerShell:

```pwsh
vfox install erlang@25.3.2.12
vfox use erlang@25.3.2.12
Invoke-Expression "$(vfox activate pwsh)"
# Test the installation results
& erl.exe -eval 'erlang:display({otp_release, erlang:system_info(otp_release)}), halt().' -noshell
```

You can reference the E2E test in in windows-2022: [.github/workflows/e2e_test_windows.yaml](.github/workflows/e2e_test_windows.yaml)

## Install a Prebuilt Erlang/OTP Version

After vfox-erlang v1.1.0, you can install prebuilt Erlang/OTP versions, which can be significantly faster than compiling from source.

**Before installing, you might need to disable the vfox search cache if you encounter issues finding prebuilt versions.** Reference: [https://vfox.lhan.me/guides/configuration.html#cache-settings](https://vfox.lhan.me/guides/configuration.html#cache-settings)

To use a prebuilt binary, set the `USE_PREBUILT_OTP` environment variable before running `vfox install` or `vfox search`.

### For Linux (Ubuntu)

Prebuilt binaries for Ubuntu are sourced from `https://builds.hex.pm/builds/otp/`.

Example:
```shell
# Search for available prebuilt versions for Ubuntu 20.04
USE_PREBUILT_OTP="ubuntu-20.04" vfox search erlang

# Install a specific version
USE_PREBUILT_OTP="ubuntu-20.04" vfox install erlang@26.2.2
```
Supported `USE_PREBUILT_OTP` values for Linux include: "ubuntu-14.04", "ubuntu-16.04", "ubuntu-18.04", "ubuntu-20.04", "ubuntu-22.04", "ubuntu-24.04". Ensure the Erlang version you wish to install is available for your chosen Ubuntu release at `https://builds.hex.pm/builds/otp/`.

### For macOS (Darwin)

Prebuilt binaries for macOS (x86_64 and Apple Silicon/aarch64) are sourced from `https://github.com/erlef/otp_builds`.

Set `USE_PREBUILT_OTP` to your target architecture:
- For Intel (x86_64): `export USE_PREBUILT_OTP="x86_64-apple-darwin"`
- For Apple Silicon (aarch64): `export USE_PREBUILT_OTP="aarch64-apple-darwin"`

Example:
```shell
# Install on Apple Silicon
export USE_PREBUILT_OTP="aarch64-apple-darwin"
vfox install erlang@OTP-27.0.1 

# Install on Intel Mac
export USE_PREBUILT_OTP="x86_64-apple-darwin"
vfox install erlang@OTP-27.0.1
```
**Note:** Ensure the Erlang/OTP version (e.g., `OTP-27.0.1`) you specify with `vfox install erlang@<version>` is available as a prebuilt release at `https://github.com/erlef/otp_builds/releases`. The version format for these prebuilt binaries typically includes "OTP-", like `OTP-27.0.1`, which might differ from the source release tags (e.g., `27.0.1`). You can check the available tags on the `erlef/otp_builds` releases page.