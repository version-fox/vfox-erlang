//go:build linux

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

package linux

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/version-fox/vfox-erlang/tests/e2e/common"
)

const (
	// systemErlangRoot is where Debian and Ubuntu packages install OTP.
	systemErlangRoot = "/usr/lib/erlang"
	// systemReleaseGlob matches the OTP_VERSION file of each installed release.
	systemReleaseGlob = systemErlangRoot + "/releases/*/OTP_VERSION"
)

// TestLinuxSystemDetect links a system-wide Erlang/OTP (for example from the
// erlang-base package) with `vfox link --detect`, runs it, and checks that
// uninstalling the link leaves the system install in place.
//
// The test skips when no system install is found. Set E2E_REQUIRE_SYSTEM_ERLANG=1
// to fail instead.
func TestLinuxSystemDetect(t *testing.T) {
	release, version, err := systemOTPVersion()
	if err != nil {
		t.Fatalf("look for a system Erlang/OTP: %v", err)
	}
	if version == "" {
		msg := "no system Erlang/OTP under " + systemErlangRoot + "; install it with: sudo apt-get install -y erlang-base"
		if os.Getenv("E2E_REQUIRE_SYSTEM_ERLANG") == "1" {
			t.Fatal(msg)
		}
		t.Skip(msg)
	}
	t.Logf("system Erlang/OTP %s (releases/%s)", version, release)

	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	detected := common.Vfox(t, sb, "link", "--detect", "-y", "erlang")
	if !strings.Contains(detected, version) {
		t.Fatalf("vfox link --detect did not offer %s:\n%s", version, detected)
	}

	listed := common.Vfox(t, sb, "list", "erlang")
	if !hasLinkedLine(listed, version) {
		t.Fatalf("vfox list erlang does not show %s as linked:\n%s", version, listed)
	}

	common.UseGlobal(t, sb, version)
	common.AssertOTPRelease(t, sb, version)

	common.Vfox(t, sb, "uninstall", "erlang@"+version)
	// vfox removes only its link to a system install, never the install itself.
	if _, err := os.Stat(filepath.Join(systemErlangRoot, "bin", "erl")); err != nil {
		t.Fatalf("vfox uninstall removed the system Erlang/OTP: %v", err)
	}
	// With no version left, `vfox list` exits 1, so its error is only logged.
	after, err := common.VfoxOutput(sb, "list", "erlang")
	if strings.Contains(after, version) {
		t.Errorf("vfox list erlang still shows %s after uninstall:\n%s", version, after)
	}
	if err != nil {
		t.Logf("vfox list erlang after uninstall exited with %v:\n%s", err, after)
	}
}

// systemOTPVersion returns the release directory and the OTP version of the first
// system install that records one. Both are "" when there is no system install.
func systemOTPVersion() (string, string, error) {
	matches, err := filepath.Glob(systemReleaseGlob)
	if err != nil {
		return "", "", err
	}
	for _, file := range matches {
		raw, readErr := os.ReadFile(file)
		if readErr != nil {
			continue
		}
		if v := strings.TrimSpace(string(raw)); v != "" {
			return filepath.Base(filepath.Dir(file)), v, nil
		}
	}
	return "", "", nil
}

// hasLinkedLine reports whether one line of `vfox list` output names version and
// marks it as linked. The match on "linked" ignores case.
func hasLinkedLine(listing, version string) bool {
	for _, line := range strings.Split(listing, "\n") {
		if strings.Contains(line, version) && strings.Contains(strings.ToLower(line), "linked") {
			return true
		}
	}
	return false
}
