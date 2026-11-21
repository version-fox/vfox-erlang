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
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestVfoxBinaryPrefersVfoxBinEnv(t *testing.T) {
	bin := filepath.Join(t.TempDir(), ExecutableName("vfox"))
	writeExecutable(t, bin)
	t.Setenv("VFOX_BIN", bin)
	got, err := VfoxBinary()
	if err != nil {
		t.Fatalf("VfoxBinary() error: %v", err)
	}
	if got != bin {
		t.Fatalf("VfoxBinary() = %q, want VFOX_BIN %q", got, bin)
	}
}

func TestVfoxBinaryRejectsMissingVfoxBin(t *testing.T) {
	t.Setenv("VFOX_BIN", filepath.Join(t.TempDir(), "missing"))
	if got, err := VfoxBinary(); err == nil {
		t.Fatalf("VfoxBinary() = %q, want an error for a missing VFOX_BIN", got)
	}
}

func TestVfoxBinaryFallsBackToPath(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, ExecutableName("vfox"))
	writeExecutable(t, bin)
	t.Setenv("VFOX_BIN", "")
	t.Setenv("PATH", dir)
	got, err := VfoxBinary()
	if err != nil {
		t.Fatalf("VfoxBinary() error: %v", err)
	}
	if got != bin {
		t.Fatalf("VfoxBinary() = %q, want %q found on PATH", got, bin)
	}
}

func TestVfoxBinaryFailsWhenNotOnPath(t *testing.T) {
	t.Setenv("VFOX_BIN", "")
	t.Setenv("PATH", t.TempDir())
	if got, err := VfoxBinary(); err == nil {
		t.Fatalf("VfoxBinary() = %q, want an error when vfox is not on PATH", got)
	}
}

func TestExecutableNameAddsExeOnWindowsOnly(t *testing.T) {
	want := "erl"
	if runtime.GOOS == "windows" {
		want = "erl.exe"
	}
	if got := ExecutableName("erl"); got != want {
		t.Fatalf("ExecutableName(erl) = %q, want %q", got, want)
	}
}

// writeExecutable creates a file that LookPath accepts as an executable.
func writeExecutable(t *testing.T, path string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
}
