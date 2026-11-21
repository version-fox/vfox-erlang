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
	"slices"
	"strconv"
	"strings"
	"testing"
)

func TestNewSandboxCreatesDirectoriesUnderTheTempRoot(t *testing.T) {
	sb := NewSandbox(t)
	dirs := []string{
		sb.Home,
		sb.VfoxHome,
		filepath.Join(sb.VfoxHome, "plugin"),
		filepath.Join(sb.VfoxHome, "sdks"),
		filepath.Join(sb.VfoxHome, "cache"),
		sb.Work,
	}
	for _, dir := range dirs {
		info, err := os.Stat(dir)
		if err != nil || !info.IsDir() {
			t.Errorf("sandbox directory %s missing: %v", dir, err)
		}
		if !strings.HasPrefix(dir, sb.Root+string(filepath.Separator)) {
			t.Errorf("sandbox directory %s is outside the sandbox root %s", dir, sb.Root)
		}
	}
}

func TestSandboxEnvPointsVfoxIntoTheSandbox(t *testing.T) {
	t.Setenv("VFOX_HOME", "/somewhere/else")
	t.Setenv("HOME", "/somewhere/else")
	t.Setenv("USERPROFILE", "/somewhere/else")
	t.Setenv("__VFOX_SHELL", "1")
	t.Setenv("__VFOX_PID", "42")
	t.Setenv("USE_PREBUILT_OTP", "ubuntu-22.04")
	t.Setenv("MAKEFLAGS", "-j1")
	sb := NewSandbox(t)

	env := sb.Env("MAKEFLAGS=-j3", "E2E_EXTRA=1")

	assertValues(t, env, "VFOX_HOME", []string{sb.VfoxHome})
	assertValues(t, env, "HOME", []string{sb.Home})
	assertValues(t, env, "USERPROFILE", []string{sb.Home})
	assertValues(t, env, "MAKEFLAGS", []string{"-j3"})
	assertValues(t, env, "E2E_EXTRA", []string{"1"})
	assertValues(t, env, "USE_PREBUILT_OTP", nil)
	for _, kv := range env {
		if key, _, _ := strings.Cut(kv, "="); strings.HasPrefix(key, "__VFOX_") {
			t.Errorf("vfox shell state %q leaked into the sandbox environment", key)
		}
	}
}

func TestSandboxEnvKeepsInheritedVariables(t *testing.T) {
	t.Setenv("E2E_SENTINEL", "kept")
	sb := NewSandbox(t)
	assertValues(t, sb.Env(), "E2E_SENTINEL", []string{"kept"})
}

func TestMakeFlagsUsesEveryCPU(t *testing.T) {
	want := "-j" + strconv.Itoa(runtime.NumCPU())
	if got := MakeFlags(); got != want {
		t.Fatalf("MakeFlags() = %q, want %q", got, want)
	}
}

// assertValues checks the values of every entry named key in env.
func assertValues(t *testing.T, env []string, key string, want []string) {
	t.Helper()
	var got []string
	for _, kv := range env {
		if k, v, ok := strings.Cut(kv, "="); ok && k == key {
			got = append(got, v)
		}
	}
	if !slices.Equal(got, want) {
		t.Errorf("%s values = %q, want %q", key, got, want)
	}
}
