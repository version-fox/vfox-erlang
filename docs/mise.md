# mise

[中文](zh-CN/mise.md) | [English](mise.md)

[mise](https://mise.jdx.dev/) can install tools through vfox plugins, using its `vfox` backend. This plugin works with that backend, so mise can install and select Erlang/OTP for you.

## Install and select a version

```shell
mise use -g vfox:version-fox/vfox-erlang@26.2.3
```

Run commands with the selected version:

```shell
mise exec -- erl -version
mise exec -- erl -noshell -eval 'erlang:display({otp_release, erlang:system_info(otp_release)}), halt().'
```

To compile and run the sample module from this repository, copy `assets/hello.erl` into your working directory and run:

```shell
mise exec -- erlc hello.erl
mise exec -- erl -noshell -s hello hello_world -s init stop
```

## Build options

The plugin reads the build variables when it installs a version, so set them in the shell that runs `mise use`:

```shell
export MAKEFLAGS=-j4
mise use -g vfox:version-fox/vfox-erlang@26.2.3
```

The variables are described in [source-build.md](source-build.md).

## Notes

- The mise tests in this repository's CI install from source, without `USE_PREBUILT_OTP`.
- For how mise runs vfox plugins, see the [mise documentation for the vfox backend](https://mise.jdx.dev/dev-tools/backends/vfox.html).
