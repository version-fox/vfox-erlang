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

// TestLinuxDetectSkipsErlThatCannotRun lays out a mise-style install whose bin/erl is not executable.
// `vfox link --detect` must not offer it, because vfox cannot link an installation whose erl cannot run.
// Once erl has the execute bit, the same install is offered and linked.
func TestLinuxDetectSkipsErlThatCannotRun(t *testing.T) {
	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	root := filepath.Join(sb.Home, ".local", "share", "mise", "installs", "erlang", "29.1.2")
	erl := writeMiseOTP(t, root, 0o644)

	out, err := common.VfoxOutput(sb, "link", "--detect", "-y", "erlang")
	if strings.Contains(out, root) {
		t.Fatalf("vfox link --detect offered an install whose erl cannot run (exit %v):\n%s", err, out)
	}

	if err := os.Chmod(erl, 0o755); err != nil {
		t.Fatalf("chmod %s: %v", erl, err)
	}
	detected := common.Vfox(t, sb, "link", "--detect", "-y", "erlang")
	if !strings.Contains(detected, root) {
		t.Fatalf("vfox link --detect did not offer the install once erl can run:\n%s", detected)
	}
	listed := common.Vfox(t, sb, "list", "erlang")
	if !hasLinkedLine(listed, "29") {
		t.Fatalf("vfox list erlang does not show 29 as linked:\n%s", listed)
	}
}

// writeMiseOTP writes an install in the layout the detector reads: bin/erl, a shell script with the
// given mode, and releases/29/OTP_VERSION. It returns the path of erl.
func writeMiseOTP(t *testing.T, root string, mode os.FileMode) string {
	t.Helper()
	bin := filepath.Join(root, "bin")
	release := filepath.Join(root, "releases", "29")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatalf("create %s: %v", bin, err)
	}
	if err := os.MkdirAll(release, 0o755); err != nil {
		t.Fatalf("create %s: %v", release, err)
	}
	erl := filepath.Join(bin, "erl")
	if err := os.WriteFile(erl, []byte("#!/bin/sh\necho 29\n"), mode); err != nil {
		t.Fatalf("write %s: %v", erl, err)
	}
	// The umask can clear bits from the mode that WriteFile sets, so the mode is set again.
	if err := os.Chmod(erl, mode); err != nil {
		t.Fatalf("chmod %s: %v", erl, err)
	}
	if err := os.WriteFile(filepath.Join(release, "OTP_VERSION"), []byte("29\n"), 0o644); err != nil {
		t.Fatalf("write OTP_VERSION: %v", err)
	}
	return erl
}
