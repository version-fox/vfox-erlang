// Copyright 2026 vfox-erlang contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package common

import (
	"encoding/base64"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"unicode/utf16"
)

// VfoxWith runs the vfox binary under test with an explicit environment in dir,
// and returns its combined output.
func VfoxWith(t testing.TB, env []string, dir string, args ...string) string {
	t.Helper()
	bin, err := VfoxBinary()
	if err != nil {
		t.Fatalf("%v", err)
		return ""
	}
	return Run(t, env, dir, bin, args...)
}

// Vfox runs vfox in the sandbox, with the sandbox environment and work directory.
func Vfox(t testing.TB, sb Sandbox, args ...string) string {
	t.Helper()
	return VfoxWith(t, sb.Env(), sb.Work, args...)
}

// VfoxOutput runs vfox in the sandbox like Vfox, but returns the output and the
// error instead of failing the test. Use it when a non-zero exit is part of the
// check, for example `vfox list` once no version is left, which exits with 1.
func VfoxOutput(sb Sandbox, args ...string) (string, error) {
	bin, err := VfoxBinary()
	if err != nil {
		return "", err
	}
	return RunOutput(sb.Env(), sb.Work, bin, args...)
}

// AddPlugin installs the plugin zip into the sandbox under name, the same way a
// user runs `vfox add --source <zip> erlang`.
func AddPlugin(t testing.TB, sb Sandbox, zipPath, name string) {
	t.Helper()
	Vfox(t, sb, "add", "--source", zipPath, name)
}

// InstallErlang runs `vfox install erlang@<version>`. extra holds KEY=VALUE
// entries for this one command, such as MAKEFLAGS or USE_PREBUILT_OTP.
func InstallErlang(t testing.TB, sb Sandbox, version string, extra ...string) string {
	t.Helper()
	return VfoxWith(t, sb.Env(extra...), sb.Work, "install", "erlang@"+version)
}

// UseGlobal runs `vfox use -g erlang@<version>` in an activated shell.
//
// vfox use fails on Unix unless a shell hook is active ("vfox requires hook
// support"), so the command runs the way the CI workflows run it: after
// `eval "$(vfox activate bash)"` on Unix, and after
// `Invoke-Expression "$(vfox activate pwsh)"` on Windows.
func UseGlobal(t testing.TB, sb Sandbox, version string) {
	t.Helper()
	bin, err := VfoxBinary()
	if err != nil {
		t.Fatalf("%v", err)
	}
	// The activation script calls vfox by name, so the binary under test has to be
	// first on PATH.
	env := sb.Env("PATH=" + filepath.Dir(bin) + string(os.PathListSeparator) + os.Getenv("PATH"))
	use := "vfox use -g erlang@" + version
	if runtime.GOOS == "windows" {
		// Stop on errors, and exit with vfox's code, so a failed use fails the test.
		script := `$ErrorActionPreference = 'Stop'; Invoke-Expression "$(vfox activate pwsh)"; ` +
			use + `; exit $LASTEXITCODE`
		Run(t, env, sb.Work, powershellExe(),
			"-NoProfile", "-NonInteractive", "-EncodedCommand", encodePowerShell(script))
		return
	}
	Run(t, env, sb.Work, "bash", "-c", `eval "$(vfox activate bash)"; `+use)
}

// powershellExe returns pwsh when it is installed, and Windows PowerShell otherwise.
func powershellExe() string {
	if _, err := exec.LookPath("pwsh"); err == nil {
		return "pwsh"
	}
	return "powershell"
}

// encodePowerShell encodes script for -EncodedCommand: the base64 of its UTF-16LE
// bytes. Quotes and $(...) in the script then never reach command-line parsing.
func encodePowerShell(script string) string {
	units := utf16.Encode([]rune(script))
	buf := make([]byte, 0, 2*len(units))
	for _, u := range units {
		buf = append(buf, byte(u), byte(u>>8))
	}
	return base64.StdEncoding.EncodeToString(buf)
}
