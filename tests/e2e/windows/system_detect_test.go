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
	"path/filepath"
	"strings"
	"testing"

	"github.com/version-fox/vfox-erlang/tests/e2e/common"
)

// systemInstallVersion is installed with the official installer to the default location,
// so vfox has to detect it rather than install it.
const systemInstallVersion = "26.2.3"

// TestWindowsSystemDetect installs Erlang/OTP with the official installer, links it
// with `vfox link --detect`, runs it, and checks that uninstalling the link leaves
// the installed directory in place. The installer writes to %ProgramFiles%, so the
// test is skipped in -short mode, and it also refuses to run when an Erlang/OTP
// directory already exists there, because cleanup would remove it.
func TestWindowsSystemDetect(t *testing.T) {
	if testing.Short() {
		t.Skip("installs Erlang/OTP into Program Files; run without -short")
	}
	version := systemInstallVersion
	sb := common.NewSandbox(t)

	root := programFilesDir()
	before := mustListErlangDirs(t, root)
	if len(before) > 0 {
		t.Skipf("Erlang/OTP directories already exist under %s (%v); refusing to install over them",
			root, sortedKeys(before))
	}
	// Registered before the installer runs, so a failed install is cleaned up too.
	// Cleanups run last-in first-out, so this runs before the sandbox is removed.
	t.Cleanup(func() { uninstallNewDirs(t, root, before) })

	installer := downloadInstaller(t, version)
	silentInstall(t, installer)
	installDir := newInstallDir(t, root, before)
	t.Logf("system Erlang/OTP %s installed in %s", version, installDir)

	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	detected := common.Vfox(t, sb, "link", "--detect", "-y", "erlang")
	if !strings.Contains(detected, version) {
		t.Fatalf("vfox link --detect did not offer %s:\n%s", version, detected)
	}

	common.UseGlobal(t, sb, version)
	common.AssertOTPRelease(t, sb, version)

	common.Vfox(t, sb, "uninstall", "erlang@"+version)
	// vfox removes only its link to a system install, never the install itself.
	if _, err := os.Stat(filepath.Join(installDir, "bin", "erl.exe")); err != nil {
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

// newInstallDir returns the one directory under root that holds bin\erl.exe and
// appeared since the snapshot before was taken.
func newInstallDir(t *testing.T, root string, before map[string]bool) string {
	t.Helper()
	var installs []string
	for _, dir := range newDirs(before, mustListErlangDirs(t, root)) {
		if hasErlExe(dir) {
			installs = append(installs, dir)
		}
	}
	if len(installs) != 1 {
		t.Fatalf("expected the installer to create one Erlang/OTP directory under %s, found %v", root, installs)
	}
	return installs[0]
}
