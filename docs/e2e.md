# End-to-end tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

The end-to-end (E2E) tests install real Erlang/OTP versions with the plugin and check that they run. The install tests are the slowest checks, because a source build takes a long time. They are skipped in `-short` mode.

## Suites

| Suite | Defined in | Runners | What it covers |
| --- | --- | --- | --- |
| Linux source build | `TestLinuxSourceInstall` in `tests/e2e/linux` | `ubuntu-22.04`, `ubuntu-24.04` | Builds `E2E_ERLANG_VERSION` from source with `MAKEFLAGS` set to all CPUs, runs `erl`, compiles and runs `assets/hello.erl` with `erlc`, and checks the documentation chunks |
| Linux prebuilt | `TestLinuxPrebuiltInstall` in `tests/e2e/linux` | `ubuntu-22.04`, `ubuntu-24.04` | Installs the Bob package for the Ubuntu release with `USE_PREBUILT_OTP`, using a numeric version so the `OTP-` prefix is covered, and checks the release |
| Linux system SDK | `TestLinuxSystemDetect` in `tests/e2e/linux` | `ubuntu-22.04`, `ubuntu-24.04` | Links the Erlang/OTP that the `erlang-base` package puts in `/usr/lib/erlang` with `vfox link --detect`, runs it, and checks that uninstalling the link keeps the system install |
| Linux link detection | `TestLinuxDetectSkipsErlThatCannotRun` in `tests/e2e/linux` | `ubuntu-latest`, in the Test Plugin workflow with `go test -short` | Lays out a mise-style install whose `bin/erl` is not executable, checks that `vfox link --detect` does not offer it, then sets the execute bit and checks that it is linked |
| Windows installer | `TestWindowsOfficialInstaller` in `tests/e2e/windows` | `windows-2022`, `windows-2025` | Installs 25.3.2.12 through the plugin, which runs the official installer, then checks `erl.exe`, `erlc.exe` and the documentation chunks |
| Windows system SDK | `TestWindowsSystemDetect` in `tests/e2e/windows` | `windows-2022`, `windows-2025` | Runs the official installer for 26.2.3 into `%ProgramFiles%`, links it with `vfox link --detect`, and checks that uninstalling the link keeps the installed directory |
| Darwin source build | `.github/workflows/e2e_test_darwin.yaml` | `macos-latest` | Builds from source on macOS, runs `erlc` and `erl`, and shows the documentation for `lists` |
| Darwin prebuilt | `.github/workflows/e2e_test_darwin_prebuilt.yaml` | `macos-latest` | Installs the erlef/otp_builds package with `USE_PREBUILT_OTP=true`, then runs `erlc` and `erl` |
| Darwin mise | `.github/workflows/e2e_test_darwin_mise.yaml` | `macos-latest` | Installs through the vfox backend of mise, see [mise.md](mise.md) |
| Linux mise | `.github/workflows/e2e_test_linux_mise.yaml` | `ubuntu-24.04` | Installs through the vfox backend of mise, and checks that the documentation chunks are present, see [mise.md](mise.md) |

In `e2e.yml`, the Linux job runs the source and prebuilt tests first. It then installs `erlang-base` and runs the system test with `E2E_REQUIRE_SYSTEM_ERLANG=1`, so a missing system install fails the job instead of skipping the test. The Windows job runs `TestWindows`, which covers both Windows tests.

## Go suites

The suites are Go tests in `tests/e2e`. `common` holds the shared helpers, and `linux` and `windows` hold the platform suites. The helpers have unit tests of their own. `go test -short ./...` runs those tests without installing Erlang/OTP, and it is what the Test Plugin workflow runs.

## Run the Linux suite in Docker

Docker is required. The image is built from `tests/e2e/linux/Dockerfile`. It holds the build tools and vfox 1.1.0, but no Erlang/OTP, and the repository is mounted read-only when the container runs. Run these commands from the repository root:

```shell
docker build -t vfox-erlang-e2e:22.04 --build-arg UBUNTU_VERSION=22.04 tests/e2e/linux
docker run --rm -v "$PWD:/src:ro" -e E2E_REQUIRE_SYSTEM_ERLANG=1 vfox-erlang-e2e:22.04 sh -c 'apt-get update && apt-get install -y erlang-base && cd /src/tests/e2e && go test -v -timeout 90m -run TestLinux ./linux'
```

The command installs `erlang-base`, so that the system test has an installation to find. The container is removed when the command ends. `TestLinux` also runs the source build, which takes a long time.

For a shorter run, select one test with `-run`, for example `-run 'TestLinuxSourceInstall'`. The test names are in the `tests/e2e/linux` package.

The Dockerfile picks the wxWidgets packages for the Ubuntu release: `libwxgtk3.0-*` on 22.04 and `libwxgtk3.2-*` on 24.04. To build the 24.04 image, pass `--build-arg UBUNTU_VERSION=24.04` and tag it `vfox-erlang-e2e:24.04`. The `docker run` command is the same, with that tag.

## Windows

The Windows suite runs only on the Windows runners in CI (`windows-2022` and `windows-2025`). Docker and WSL2 cannot run Windows containers, so the suite cannot be reproduced there. On a Windows machine, run it from `tests/e2e`:

```pwsh
cd tests/e2e
go test -v -timeout 90m -run TestWindows ./windows
```

vfox is found on `PATH` unless `VFOX_BIN` names another binary. The system test installs Erlang/OTP into `%ProgramFiles%`. The test is skipped when Erlang/OTP directories already exist there, so it never installs over an existing installation.

## Environment variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `E2E_ERLANG_VERSION` | `26.2.3` | The version the Linux suites install. The Windows suites use fixed versions, 25.3.2.12 and 26.2.3 |
| `E2E_PREBUILT_OS` | The `VERSION_ID` from `/etc/os-release`; the test is skipped on releases other than 22.04, 24.04 and 26.04 | The Ubuntu release for the prebuilt suite, such as `ubuntu-22.04` |
| `E2E_REQUIRE_SYSTEM_ERLANG` | unset | Set to `1` to fail the Linux system test when no system Erlang/OTP is found. Otherwise the test is skipped |
| `E2E_REPO` | The plugin root, found by walking up from the current directory | The plugin root, which holds `metadata.lua` and `hooks/`. CI and the Docker image set it |
| `VFOX_BIN` | `vfox` on `PATH` | The vfox binary under test |
