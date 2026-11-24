//go:build windows

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

package windows

import (
	"os"
	"runtime"
	"strings"
	"testing"

	"github.com/version-fox/vfox-erlang/tests/e2e/common"
)

// arm64Version is installed by TestArm64OfficialInstaller. Erlang/OTP 28.5.0.8 publishes
// otp_win32_28.5.0.8.exe, which the plugin installs on arm64.
const arm64Version = "28.5.0.8"

// arm64RefusedVersion is refused on arm64. Erlang/OTP 29.x publishes only the 64-bit installer.
const arm64RefusedVersion = "29.1.2"

// wordsizeExpr prints the word size of the emulator: 4 for a 32-bit build, 8 for a 64-bit one.
// It has no double quotes, so it reaches erl intact through Windows command-line quoting.
const wordsizeExpr = "io:put_chars(integer_to_list(erlang:system_info(wordsize))), io:nl()."

// requireArm64 stops the test unless it runs on a Windows arm64 host. The CI job sets
// E2E_REQUIRE_ARM64=1, so a host of another architecture fails there instead of skipping.
func requireArm64(t *testing.T) {
	t.Helper()
	if runtime.GOARCH == "arm64" {
		return
	}
	msg := "the Windows arm64 tests need a Windows arm64 host, this one is " + runtime.GOARCH
	if os.Getenv("E2E_REQUIRE_ARM64") == "1" {
		t.Fatal(msg)
	}
	t.Skip(msg)
}

// firstNonBlank returns the first line of out that is not blank, with surrounding space removed.
func firstNonBlank(out string) string {
	for _, line := range strings.Split(out, "\n") {
		if line = strings.TrimSpace(line); line != "" {
			return line
		}
	}
	return ""
}

// TestArm64OfficialInstaller installs Erlang/OTP 28.5.0.8 through the plugin on a Windows arm64 host. The plugin
// downloads the 32-bit installer there, so the test checks that this installer was downloaded and that erl runs as
// the 32-bit build. Then it runs the checks of TestWindowsOfficialInstaller.
func TestArm64OfficialInstaller(t *testing.T) {
	requireArm64(t)
	if testing.Short() {
		t.Skip("the installer download is large; run without -short")
	}
	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	out := common.InstallErlang(t, sb, arm64Version)
	if want := "otp_win32_" + arm64Version + ".exe"; !strings.Contains(out, want) {
		t.Fatalf("the plugin did not download %s on arm64\noutput:\n%s", want, out)
	}
	common.UseGlobal(t, sb, arm64Version)

	// A 32-bit build reports a word size of 4. A 64-bit build would report 8.
	word := common.ErlangTool(t, sb, sb.Work, arm64Version, "erl",
		"-noshell", "-eval", wordsizeExpr, "-s", "init", "stop")
	if got := firstNonBlank(word); got != "4" {
		t.Fatalf("erl reports word size %q, want 4 for the 32-bit build\noutput:\n%s", got, word)
	}

	common.AssertOTPRelease(t, sb, arm64Version)
	common.CompileAndRunHello(t, sb, arm64Version)
	common.AssertDocChunks(t, sb, arm64Version)
}

// TestArm64RefusesReleaseWithoutInstaller asks for a release that publishes no 32-bit installer. On arm64 the plugin
// must refuse it before the download, with a message that says Erlang/OTP has no build for the platform.
func TestArm64RefusesReleaseWithoutInstaller(t *testing.T) {
	requireArm64(t)
	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	out, err := common.VfoxOutput(sb, "install", "erlang@"+arm64RefusedVersion)
	if err == nil {
		t.Fatalf("vfox install erlang@%s succeeded on arm64, want a refusal\noutput:\n%s", arm64RefusedVersion, out)
	}
	want := "Erlang/OTP " + arm64RefusedVersion + " has no build for Windows arm64"
	if !strings.Contains(out, want) {
		t.Fatalf("the refusal does not say %q\noutput:\n%s", want, out)
	}
	if strings.Contains(out, "Download Erlang/OTP from") {
		t.Fatalf("the install reached the download step before the refusal\noutput:\n%s", out)
	}
}
