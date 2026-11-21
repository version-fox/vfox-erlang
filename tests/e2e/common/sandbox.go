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
	"strconv"
	"strings"
	"testing"
)

// Sandbox is an isolated HOME and VFOX_HOME for one test. Everything lives under
// the directory returned by t.TempDir(), so a test never touches the developer's
// real ~/.vfox.
type Sandbox struct {
	// Root is the t.TempDir() that holds the other directories.
	Root string
	// Home is used as HOME, and as USERPROFILE on Windows.
	Home string
	// VfoxHome is used as VFOX_HOME. Plugins go to plugin/ and SDK installs to cache/.
	VfoxHome string
	// Work is the working directory for vfox commands. It keeps project-level
	// files of the repository out of the way.
	Work string
}

// NewSandbox creates a fresh sandbox under t.TempDir().
func NewSandbox(t testing.TB) Sandbox {
	t.Helper()
	root := t.TempDir()
	sb := Sandbox{
		Root:     root,
		Home:     filepath.Join(root, "home"),
		VfoxHome: filepath.Join(root, "vfox-home"),
		Work:     filepath.Join(root, "work"),
	}
	dirs := []string{
		sb.Home,
		sb.VfoxHome,
		filepath.Join(sb.VfoxHome, "plugin"),
		filepath.Join(sb.VfoxHome, "sdks"),
		filepath.Join(sb.VfoxHome, "cache"),
		sb.Work,
	}
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatalf("create sandbox directory %s: %v", dir, err)
		}
	}
	return sb
}

// Env returns the environment for a child process. It is the current environment
// with VFOX_HOME, HOME and USERPROFILE pointing into the sandbox, followed by the
// KEY=VALUE entries in extra. An entry in extra replaces an inherited variable
// with the same name.
//
// vfox state inherited from an enclosing vfox shell (__VFOX_*) is dropped, so
// that every `vfox activate` in a test starts clean. USE_PREBUILT_OTP is dropped
// too, because a source-build test would otherwise silently become a prebuilt
// one. A test that wants either passes it in extra.
func (sb Sandbox) Env(extra ...string) []string {
	replaced := map[string]bool{
		"VFOX_HOME":        true,
		"HOME":             true,
		"USERPROFILE":      true,
		"USE_PREBUILT_OTP": true,
	}
	for _, kv := range extra {
		replaced[envKey(kv)] = true
	}

	inherited := os.Environ()
	env := make([]string, 0, len(inherited)+len(extra)+3)
	for _, kv := range inherited {
		key := envKey(kv)
		if replaced[key] || strings.HasPrefix(key, "__VFOX_") {
			continue
		}
		env = append(env, kv)
	}
	env = append(env,
		"VFOX_HOME="+sb.VfoxHome,
		"HOME="+sb.Home,
		"USERPROFILE="+sb.Home,
	)
	return append(env, extra...)
}

// envKey returns the name of a KEY=VALUE entry in upper case. Windows compares
// environment names case-insensitively, so the comparison does too.
func envKey(kv string) string {
	key, _, _ := strings.Cut(kv, "=")
	return strings.ToUpper(key)
}

// MakeFlags returns the MAKEFLAGS value for source builds: one job per CPU.
func MakeFlags() string {
	return "-j" + strconv.Itoa(runtime.NumCPU())
}
