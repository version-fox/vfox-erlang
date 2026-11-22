# Linking installed Erlang/OTP

[中文](zh-CN/link.md) | [English](link.md)

If Erlang/OTP is already on the machine, vfox can use it instead of downloading or building another copy. Making an existing installation available this way is called linking. The plugin's `Detect` hook finds the installations, and `vfox link` records them.

Linking needs vfox 1.1.0 or later. Check your version with `vfox --version`.

## Find and link installations

```shell
vfox link --detect erlang      # list what is found and choose which to link
vfox link --detect -y erlang   # link everything that is found
```

After linking, use a version the same way as an installed one:

```shell
eval "$(vfox activate bash)"
vfox use erlang@26.2.3
vfox list erlang               # linked versions are marked and show their path
```

- A location counts as an installation when it contains `bin/erl` (`bin\erl.exe` on Windows) and a `releases/<release>/OTP_VERSION` file. The check looks in the location itself and in its `lib/erlang` subdirectory. On Linux and macOS, `bin/erl` must also have the execute bit: a file that cannot run is not listed.
- The version name comes from the `OTP_VERSION` file, for example `26.2.3`. No prefix is added.
- When several installations report the same version, only one is offered: the first one in sorted order of version and path.
- Versions that vfox has already installed or linked are skipped.
- Paths that contain a `.vfox` directory are not scanned, because vfox manages those itself.

## Where it looks

On Linux and macOS:

| Location | Notes |
| --- | --- |
| `/usr/lib/erlang` | the `erlang-base` package on Debian and Ubuntu |
| `/usr/local/lib/erlang` | the default prefix of `make install` from source |
| `/opt/erlang/*` | each subdirectory |
| `/opt/homebrew/opt/erlang`, `/usr/local/opt/erlang`, `/home/linuxbrew/.linuxbrew/opt/erlang` | Homebrew links; the OTP root is `lib/erlang` below them |
| `/opt/homebrew/Cellar/erlang/*`, `/usr/local/Cellar/erlang/*`, `/home/linuxbrew/.linuxbrew/Cellar/erlang/*` | each Homebrew version directory |
| `~/.asdf/installs/erlang/*` | asdf |
| `~/.local/share/mise/installs/erlang/*` | mise |

On Windows:

| Location | Notes |
| --- | --- |
| `%ProgramFiles%` and `%ProgramFiles(x86)%` | directories whose names start with `Erlang OTP` (with the space) or `erl`, case-insensitive |
| `%USERPROFILE%\.local\share\mise\installs\erlang\*` | mise |

An installation outside these locations is not found. Link it by hand, as described below.

## Link an installation by hand

```shell
vfox link erlang@26.2.3 /usr/lib/erlang
```

The path must be one of these:

- the Erlang/OTP root, a directory that contains `bin` and `releases`, or
- a prefix directory that contains `lib/erlang`, such as `/usr/local`.

The name after `erlang@` is yours to choose. Naming it after the OTP version, as above, lets `vfox use erlang@26.2.3` work as usual.

## Remove a link

```shell
vfox uninstall erlang@26.2.3
```

For a linked version, this removes only the link. The Erlang/OTP on the machine is not deleted.

If nothing is found, or the command is not recognized, see [troubleshooting.md](troubleshooting.md).
