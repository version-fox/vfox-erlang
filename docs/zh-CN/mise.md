# mise

[中文](mise.md) | [English](../mise.md)

[mise](https://mise.jdx.dev/) 可以通过 vfox 插件安装工具，使用它的 `vfox` 后端。本插件支持这个后端，因此可以用 mise 安装并选择 Erlang/OTP。

## 安装并选择版本

```shell
mise use -g vfox:version-fox/vfox-erlang@26.2.3
```

用选定的版本运行命令：

```shell
mise exec -- erl -version
mise exec -- erl -noshell -eval 'erlang:display({otp_release, erlang:system_info(otp_release)}), halt().'
```

要编译并运行本仓库中的示例模块，把 `assets/hello.erl` 复制到工作目录，然后执行：

```shell
mise exec -- erlc hello.erl
mise exec -- erl -noshell -s hello hello_world -s init stop
```

## 构建参数

插件在安装版本时读取构建相关的环境变量，所以要在执行 `mise use` 的同一个 Shell 中设置它们：

```shell
export MAKEFLAGS=-j4
mise use -g vfox:version-fox/vfox-erlang@26.2.3
```

各个变量的含义见 [源码构建](source-build.md)。

## 说明

- 本仓库 CI 中的 mise 测试使用源码构建，没有设置 `USE_PREBUILT_OTP`。
- mise 如何运行 vfox 插件，见 [mise 的 vfox 后端文档](https://mise.jdx.dev/dev-tools/backends/vfox.html)。
